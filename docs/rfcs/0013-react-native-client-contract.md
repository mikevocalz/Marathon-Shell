# RFC 0013: a managed contract for React Native Wayland clients

## Status and request

**Discussion draft; documentation only.** This RFC requests a reviewed integration path for a separately compiled Linux application using React Native Fabric, Hermes, Yoga and a Qt Quick component backend. It does not implement a runner, extend the package schema, establish device support or claim upstream approval.

The goal is to give such a client Marathon app identity, semantic navigation, lifecycle, keyboard integration, permission mediation and install/update/remove behavior. The client owns its React Native runtime and renders as a normal Wayland client. Marathon retains its existing shell/compositor architecture. The interface should be narrow enough that another native toolkit could use the same lifecycle and permission contract.

Core shell/client-platform validation uses non-premium fixtures. Nitro Forge is a separately sold premium product, with no required dependency, bundled sample, build/test gate or release prerequisite in this RFC. Generic runtime and Nitro v1 discovery, linkage and lifecycle support belong to the client platform; product-specific integration belongs to a separately authorized licensed consuming app. Neither this RFC nor its shell/platform artifacts may redistribute premium source, engines, assets or binaries.

## Inspected source and constraints

This proposal is based on `patrickjquinn/Marathon-Shell` revision `c2c1b2fe32aeaa51edf75a45045cbfbbc08c4ac5`, also the inspected base of this fork:

- [Manifest schema](https://github.com/patrickjquinn/Marathon-Shell/blob/c2c1b2fe32aeaa51edf75a45045cbfbbc08c4ac5/schemas/marathon-app-manifest-v1.schema.json): version 1 requires a `.qml` entry point, limits `toolkit` to `keel` or `marathonui`, and rejects unknown top-level properties. A native executable is not a valid entry point under this schema.
- [Runner entry](https://github.com/patrickjquinn/Marathon-Shell/blob/c2c1b2fe32aeaa51edf75a45045cbfbbc08c4ac5/tools/marathon-app-runner/main.cpp): the inspected lifecycle section connects `RunnerLifecycle` back/forward requests to the QML root and handles prepare-freeze/thaw for Keel action ownership. This is a useful protocol seam, not an existing RN binding.
- [Native lifecycle](https://github.com/patrickjquinn/Marathon-Shell/blob/c2c1b2fe32aeaa51edf75a45045cbfbbc08c4ac5/docs/NATIVE_APP_LIFECYCLE.md): ordinary native clients use toolkit input/fallback heuristics; repainting alone can make back appear handled. Linux scope ownership and freezing require careful process attribution.
- [Security model](https://github.com/patrickjquinn/Marathon-Shell/blob/c2c1b2fe32aeaa51edf75a45045cbfbbc08c4ac5/docs/SECURITY_MODEL.md): native `.desktop` applications run unconfined. Managed QML apps have bwrap, security-context sockets and shell permission gates, with documented gaps including broad runtime-directory/session-bus access. Do not label those gaps solved by this RFC.
- [Device overlays](https://github.com/patrickjquinn/Marathon-Shell/blob/c2c1b2fe32aeaa51edf75a45045cbfbbc08c4ac5/docs/DEVICE_OVERLAYS.md): hardware facts belong to profiles/probes, not branches in a client renderer.

`CONTRIBUTING.md`, `CONTEXT.md` and `docs/CODING_RULES.md` were read. This documentation change follows conventional commits and the evidence separation in rules F and G11. Future implementation must also follow B2/B3 for queued Qt ownership, B12 for event subscriptions and B13 for restrained scheduling policy.

## Two explicit delivery stages

**Development client:** launch a separately built Linux/Wayland executable from a development `.desktop` entry, with a consistent reverse-DNS desktop identity and `xdg_toplevel.app_id`. Prove rendering, input, scale and basic activation in Marathon. Record this as an unconfined development launch. It is not a signed `.marathon` package or a third-party sandbox guarantee.

**Managed application:** adopt an upstream-reviewed executable entry contract, launcher registration and confinement path. Preserve trusted app identity, per-app storage, permission checks, security-context socket ownership, signature verification and data-lifecycle semantics. Decide with maintainers whether a versioned manifest/runner extension or a Flatpak-first delivery is the supported distribution path. This RFC recommends settling that decision before implementing a new package parser.

Do not bypass the schema with a dummy QML entry point that secretly executes arbitrary binaries. Do not add a `toolkit: "react-native"` value to a manifest until the validator, installer, launcher and security behavior accept and test it together.

## Proposed interface contract

The table is a proposal for semantics, not a statement that every operation already exists for native clients.

| Boundary | Proposed requirement | Failure behavior |
| --- | --- | --- |
| Launch identity | Launcher binds app ID, instance generation and process identity to the sandbox socket | Reject forged or mismatched identity before privileged service access |
| Readiness | Report protocol readiness and first mapped window separately | Bounded startup failure; no indefinite launch spinner |
| Navigation | Back/forward request reaches the active client surface and returns handled/unhandled | Timeout/disconnect follows a documented shell fallback once; no duplicate navigation |
| Suspend/resume | Native producer quiescence, checkpoint opportunity and post-thaw resynchronization | Failed preparation follows explicit policy; no promise of callbacks while frozen |
| Activation | Reuse the correct running instance and route/deep link | Reject invalid input; no duplicate invisible process |
| Window/input | Observe scale, geometry, keyboard composition/insets and focus through supported protocols | Unsupported required input feature is visible in the compatibility result |
| Services | Narrow typed client adapters call existing authorized shell services | Denial, revocation, unavailable service and restart are explicit errors |
| Exit | Release subscriptions, capability claims, sockets and instance records | Old-instance callbacks cannot affect a replacement instance |

Prefer reusing the audited `org.marathonos.AppRunner.Lifecycle1` semantics where their ownership and timing fit. A different transport/version needs a concrete protocol proposal and compatibility tests. Do not perform a blocking cross-thread JavaScript call from the shell or hold locks while invoking application code. If a reply must wait for the client's runtime, return asynchronously within the negotiated deadline and reject stale generation replies.

Two concrete interactions should guide the client API design:

1. The user requests Back while a document dialog is open. The client dismisses the dialog and replies handled. A second Back pops its document route; Back at the root replies unhandled. A running animation must not count as acknowledgement, and a timeout followed by a late reply must not pop twice.
2. A permitted download obtains a background claim, the user backgrounds the app, and its hidden animation stops while the native download continues. Completion releases the claim. If permission is revoked or the instance exits, the native operation and claim are cleaned up; JavaScript cannot grant itself the claim.

## Packaging and security decisions to settle

Before a managed runner patch, specify a manifest version and migration behavior; executable path and argument encoding; supported architecture/libc/Qt ABI; runtime dependencies; signed content coverage; data/cache ownership; and atomic update/rollback. Paths must remain inside the verified application tree after normalization and symlink resolution. Pass an argument vector without shell interpretation. A package cannot select an arbitrary host executable or reuse another application's identity.

Resolve application dependencies through the approved generic package/runtime contract. Do not add Forge-specific launcher, manifest, module-discovery or lifecycle paths. A separately licensed product must use its authorized delivery channel and the same client-platform interfaces as other native dependencies. Any needed generic capability must land and be verified independently with non-premium fixtures before claiming product compatibility.

Review D-Bus access and runtime-directory exposure against the existing security model. Native RN modules can access OS APIs; a JavaScript permission facade is not confinement. Establish the same native enforcement boundary for the managed client as the approved delivery model requires. Do not add unrestricted bus access, privileged globals, root execution or sandbox-disable switches to make a demo pass.

Keep a cold, isolated process path first. A reusable RN runner pool requires separate proof that app code, native state, permissions, credentials and JSI resources cannot survive adoption by another app. No warm-pool optimization is part of the initial support claim.

## Incremental implementation and ownership

| Slice | Proposed owner role and source paths | Independent reviewer |
| --- | --- | --- |
| Development-client receipt | Client integration engineer; external client host and desktop entry | Marathon Wayland maintainer |
| Versioned lifecycle adapter | Runner engineer; `tools/marathon-app-runner`, `crates/marathon-shell-native/src/tasks` | Qt/runtime engineer |
| Manifest/launcher decision | Packaging engineer; `schemas`, `crates/marathon-apps`, launcher paths identified by source audit | Security and installer reviewer |
| Identity/permission enforcement | Security engineer; `sandbox.rs`, `ipc.rs`, `shell/src/wayland` | Independent security reviewer |
| Device and regression evidence | QA engineer; `tests`, non-premium native-client fixture and receipts | Device/platform owner |

All human assignments are **unassigned**. These roles are requested responsibilities, not maintainer participation or endorsement. Each implementing PR should name its actual DRI and a different reviewer.

Implement one slice per draft PR. A proposed `MARATHON_ENABLE_NATIVE_CLIENT_RUNTIME` switch must default OFF and reject unsupported builds. The first code change should prove a versioned lifecycle handshake with a small native fixture; schema and installer changes follow the accepted distribution decision. Companion client workstreams for text, lifecycle, services, device metrics and conformance provide their side of this interface; they must not assume shell acceptance in advance.

## Skills, versions and applied decisions

The source-read design pipeline was Margelo [`api-design`](https://github.com/margelo/react-native-skills/blob/1e9e17be6f41c838db472d6a4b943fc26355a3be/skills/api-design/SKILL.md), [`build-nitro-modules`](https://github.com/margelo/react-native-skills/blob/1e9e17be6f41c838db472d6a4b943fc26355a3be/skills/build-nitro-modules/SKILL.md), then [`cpp`](https://github.com/margelo/react-native-skills/blob/1e9e17be6f41c838db472d6a4b943fc26355a3be/skills/cpp/SKILL.md), all at `1e9e17be6f41c838db472d6a4b943fc26355a3be`. They informed explicit errors/cleanup, typed client boundaries and native owner-thread lifetime. The client must use its audited Nitro v1 class/registration/constructor APIs with matching core, runtime and generator, typed operations and explicit async ownership; generic older skill examples are not an implementation contract. Nitro belongs inside the client; Marathon does not need to link Nitro merely to expose its lifecycle protocol. Generation support for any new client spec still requires verification.

[Callstack `react-native-best-practices`](https://github.com/callstackincubator/agent-skills/blob/59e9d17446a248b21d86f078fcd0bd2d36db1ca4/skills/react-native-best-practices/SKILL.md), read at `59e9d17446a248b21d86f078fcd0bd2d36db1ca4`, informed separate startup/interaction measurements. This records design use of source guidance, not skill CLI installation or execution of a native test. Linux/Qt/Wayland, package and security source audits remain mandatory beyond those skills.

## Acceptance and validation

Require separate evidence for desktop development, managed installation, QEMU and each physical device. The managed gate includes valid and invalid signatures, malformed paths, unsupported ABI, denied/revoked capabilities, forged identity, service restart, app crash, upgrade with data retained, rollback and uninstall according to declared data policy. Existing QML apps must continue to validate, launch and uninstall unchanged.

Run every required gate without premium packages, checkouts, credentials or artifacts, and inspect dependency closure and release contents. An optional premium compatibility report belongs to a separately authorized licensed consuming app: demonstrate install, import, build, run, update and uninstall without platform patches. This is future acceptance, not a claim that a seamless premium installation path is shipped. Historical default-OFF external-checkout experiments remain separately labeled evidence and cannot satisfy managed-package gates or become core release prerequisites.

Exercise semantic Back in a modal, an editor, a root route and an app that continuously repaints. Test freeze preparation racing activation, close while frozen, instance replacement during a pending reply and repeated keyboard composition. Run 100 launch/close cycles with stable resource counts and no cross-instance delivery. Record first mapped/presented frame, cold/warm startup, interaction latency distributions, RSS and hidden wakeups on the actual target. Select device-specific budgets from a baseline; no performance gain is claimed here.

Inspected repository commands for implementation validation include:

```bash
scripts/ci/build-and-test.sh
python3 tests/lint/check-test-reachability.py
python3 tools/devices/devices.py check
```

For direct CTest use, follow `CONTRIBUTING.md` and supply the actual Keel QML path. Register new C++/Rust/QML tests so CTest executes them. Run `./scripts/validate-qml.sh` when QML changes. This RFC change ran no shell build, package installation or device scenario; those results are pending. Do not count an unregistered test or an offscreen screenshot as a physical-device pass.

## Licensing, rollout and rollback

Keep this fork's Apache-2.0 contribution terms and review the client runtime, Qt modules, fonts and non-premium native dependency redistribution at pinned versions. Optional product compatibility requires separate authorization and licensing; keep premium payloads out of shell/platform fixtures, CI caches and release artifacts. Refer to source behavior without bundling proprietary SDKs or private device artifacts.

Roll back by disabling the optional entry mode and returning to existing launch paths; preserve installed user data and existing manifest-v1 readers. Do not ship the new managed mode by default until compatibility, security and physical-device gates pass. This RFC leaves boot images and compositor scheduling policy unchanged. The next step is maintainer review of the delivery model and lifecycle handshake, followed by a narrowly scoped opt-in fixture PR.
