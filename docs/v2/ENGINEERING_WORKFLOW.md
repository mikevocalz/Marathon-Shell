# Native implementation workflow and skills

Applies to all approved 2.0 work. Scope revision: November 9, 2026. The user explicitly requested native skills, API skills and subagents throughout implementation. This file records how to apply them; it does not claim an installed tool, a completed native build or a supported device.

## Required source and API review

Read `CONTRIBUTING.md`, `CONTEXT.md`, `docs/CODING_RULES.md`, the affected design/service documents and the real source before changing behavior. Current source takes precedence over stale examples. In particular, new app UI uses Keel and `Marathon.Silica`; the old MarathonUI examples in the contribution guide are not a new app API.

For each PR, record the base/source SHA, inspected public types/imports, dependency or provider version, ownership/thread model, failures and tests actually run. Verify a symbol in its generated header, exported module or official API/source before using it. A guessed method name or a plausible WebAuthn/Qt/Nitro interface is not evidence.

| Technology/boundary | Guidance to apply | Evidence required in implementation |
|---|---|---|
| Public action, service or app API | Margelo `api-design`; local action schema and existing consumers | Valid states, inputs/results, required versus preferred capabilities, cleanup, cancellation and 2–3 real call-site journeys |
| C++/Qt ownership, platform bridge, CMake | Margelo `cpp`; coding rules B and F; actual Qt/generated declarations | Owner thread, RAII/lifetime, queued value identity, invalidation, native compile and relevant runtime evidence |
| QML/Keel native UI | Keel migration, UI design system, coding rules C; actual pinned imports | Theme roles, input/accessibility, hidden-work budget, actual component loading and native interaction captures |
| Rust services and CXX-Qt/D-Bus | Native source/type review plus API-design ownership rules; pinned crate source/docs | Fallible typed boundary, cancellation, per-app identity, owned async work and registered crate/bus tests |
| External React Native/Nitro app target | Read `api-design`, `build-nitro-modules` and `cpp` for the affected work; verify the actual Nitro v1 generated API | Matching runtime/generator versions, native linking and lifecycle evidence in the independent client project |
| Security, identity, secure communications | Current protocol/provider/SDK documentation and source; native/API guidance at the boundary | Stated trust/encryption boundary, verified peer/app identity, revocation/recovery and test-provider/device evidence |

### Skills applied to this scope revision

- [Margelo `api-design`](https://github.com/margelo/react-native-skills/blob/1e9e17be6f41c838db472d6a4b943fc26355a3be/skills/api-design/SKILL.md), read at `1e9e17be6f41c838db472d6a4b943fc26355a3be`: explicit lifecycle/cleanup, capability discovery, real error states, current-source checks and call-site review. Its TypeScript-specific syntax is not imposed on the native shell.
- [Margelo `cpp`](https://github.com/margelo/react-native-skills/blob/1e9e17be6f41c838db472d6a4b943fc26355a3be/skills/cpp/SKILL.md), read at the same revision: owned native state, typed variants, small cohesive interfaces and no blocking UI/thread-hop workarounds.
- Repository native guidance: `docs/CODING_RULES.md`, `docs/KEEL_APP_MIGRATION.md` and `CONTEXT.md`. This revision applies design/source guidance only; it changes no C++/Rust/QML implementation.

Do not claim `build-nitro-modules` was applied to this documentation change. Read it when an actual external Nitro client/spec is changed. Nitro is not a dependency to add to Marathon's shell or image merely to satisfy a skills roster.

## Source and version inventory

The scope review inspected `mikevocalz/Marathon-Shell` at `bc39c23cac18221df21e410a45f8cc72d0ae9824`. Recheck these values when implementing; they are observations of that source revision, not a demand to freeze dependencies indefinitely.

| Source | Observed contract/version | Practical consequence |
|---|---|---|
| `CMakeLists.txt` | Qt dependency declarations begin at 6.4 | A minimum does not identify the selected image's Qt version; inspect the actual build before using a newer QML API |
| `packaging/packages/keel-silica/APKBUILD` | Shipwright/Keel commit `0df499bf34e02cec7f571853cbf5a4323dc1609e` | Inspect exported Keel/Silica types at the selected revision; preserve the toolkit |
| `crates/marathon-shell-native/Cargo.toml` | CXX-Qt/CXX-Qt-lib `=0.10.0`, zbus `=6.1.0` | Read those generated bindings/service conventions; do not paste older bridge examples |
| `apps/notes/NotesActions.qml`, `apps/notes/keel-actions.json` | Existing Notes creation/search actions and schema | Use the advertised action path; regenerate declarations when changing it |
| `apps/notes/NotesStore.js`, `apps/notes/pages/TasksPage.qml` | Checkbox tasks derive identity from note and line | Preserve/migrate existing notes before claiming durable cross-app task identity |
| `crates/marathon-maild/src/secrets.rs`, `crates/marathon-davd/src/secrets.rs` | Secret Service account storage | A storage seam is not a FIDO authenticator or a verified credential-provider implementation |
| `crates/marathon-shell-native/src/portal.rs` | Settings and FileChooser portal implementation | Review actual request/identity/grant behavior before adding transfers or continuation |

No secure-messaging provider, companion protocol or FIDO backend is selected by this document. Their first implementation slices must publish actual provider/API versions and source evidence. Do not invent a service API or report a product integration merely because a general-purpose library exists.

## Real call-site review before a new interface

Write the intended user/API flow before adding methods or fields. At minimum, describe success, cancellation and failure/cleanup for the concrete package. For example:

1. A user invokes Notes capture from the command surface. Show the exact title/body, activate the existing advertised action, consume its result and restore focus. If the app is absent, cancelled or fails, retain the entered text and show the actual outcome; do not issue the action twice to overcome a timing bug.
2. A user sends one selected file to a paired device. The operation owns a narrow grant and can be cancelled. A disconnect/retry retains its identity; unpairing revokes future access; a stale response cannot complete a replacement operation.
3. A user authenticates with a security key. The request binds the actual app/origin and relying party, user verification and cancellation. An unplugged/locked/unsupported authenticator is an explicit result; no late callback may approve an expired request.

These are design scenarios, not function signatures. Choose the native types and transport only after inspecting real dependencies. Distinguish a cheap synchronous observation from I/O, negotiation or owned resources. Do not use polling, sleeps or extra event-loop turns to hide an invalid lifecycle.

## Delegation and independent review

For each substantive package, delegate separable source research, native implementation, tests or review to subagents. Give each writer an isolated branch/worktree and disjoint files. Keep one integration owner responsible for the dependency graph and final diff. Delegation does not imply that human maintainers are assigned or have approved the work.

| Role | Responsibility |
|---|---|
| Integration owner | Confirm approved scope, source baseline, branch/base, dependencies and final claims |
| Native/API implementer | Apply relevant skills, inspect real interfaces and deliver one coherent slice |
| Contract/source reviewer | Independently check API availability, identity, ownership, error and compatibility behavior |
| Validation reviewer | Check meaningful tests and runtime evidence, including omitted hardware/provider gates |

The author self-reviews every line before requesting independent review. Reviewers cite concrete source/rule evidence and verify fixes. An agent review is not upstream acceptance, a device certificate or a substitute for required human review. Keep Work/Personal Spaces entirely in the 2.1 appendix; reject accidental 2.0 work-profile scope.

## Validation and evidence

Select meaningful checks for the changed behavior. Register code tests in upstream CTest as described by `CONTRIBUTING.md`; an unreachable test does not count. For relevant native code, use `scripts/ci/build-and-test.sh`, `python3 tests/lint/check-test-reachability.py`, QML/import/icon checks and the applicable crate, bus, QtTest or app suites. Do not add tests that only repeat implementation details or run broad unrelated suites without a concrete risk.

Keep these states separate: **planned**, **implemented**, **CI-verified**, **native-runtime verified**, **device/provider qualified**. Record skipped/unavailable checks and exact blockers. Host geometry/logic tests do not prove touch, screen-reader, modem, camera, encryption or frame pacing on a phone. UI changes require native interaction evidence in addition to still images. No false pass from a stub service or disabled security boundary.

Documentation-only changes use scope consistency, reference/path checks and `git diff --check`. They do not justify a native-build or hardware-readiness claim. Keep all fixtures and core platform release gates free of premium packages/assets/credentials. Licensed Forge compatibility is validated separately in an authorized consuming app.

## Branch, commit and release rules

Create isolated `feat/v2-*`, `fix/v2-*` or `docs/v2-*` branches from `v2`. PRs in this programme target **`v2` only**. Preserve `main` as the upstream baseline; do not infer permission to merge or publish a release from a planning approval. Use atomic conventional commits without generated-by/co-author trailers, preserve upstream attribution and self-review the staged diff.

Describe the concrete problem, actual changed behavior and measured evidence in each PR. List what remains unverified without inflating the work package's status. Retain the current Qt/Keel shell and generic app contracts; React Native QNX, NYC-Tron adapters and Nitro Forge stay independent installable app products. A shell build, test or release must not require a Forge checkout, package or license.
