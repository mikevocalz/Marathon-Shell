# Rust architecture and native API audit

Source review: November 9, 2026. The inventory and defect observations below
refer to PR #9 head `8e9e0892f646d3e11fd581367d148d7f063d7dc7`, with the
planning baseline `bc39c23cac18221df21e410a45f8cc72d0ae9824` as a comparison.
Follow-up repairs must carry their own commit and validation evidence. This
document is not a claim that either revision is a qualified phone image.

## Where Rust runs

Rust already implements much of Marathon's platform logic. The shell remains
a native Qt/QML application and Wayland compositor on Linux. Rust is linked
into its Qt objects and app runner, and also runs in independent daemons,
tools and app backends. There is no Rust kernel or implemented QNX port in
this inventory.

The current [`crates/Cargo.toml`](../../crates/Cargo.toml) lists **28 workspace
members**. The pinned planning baseline listed 27; the added workspace crate
is `marathon-gnssd`. There are **333 tracked first-party `.rs` files** at the
audited head, versus 306 at the baseline, excluding `crates/vendor/` and
including build scripts, tests, the separate app workspaces and shared
launcher sources. File counts describe source presence, not build coverage,
quality or how much of the operating system has been migrated.

| Area | Workspace crates | Actual role and boundary |
| --- | --- | --- |
| Shell platform | [`marathon-shell-native`](../../crates/marathon-shell-native/src/lib.rs) | CXX-Qt `QObject`s and models for tasks, lifecycle, launches, permissions, portals, notifications, device services, display, network, audio and other shell state. Linked into the C++/Qt shell. |
| App platform | [`marathon-app-native`](../../crates/marathon-app-native/src/lib.rs) | CXX-Qt clients exposed to app QML as `Marathon.Platform`; runner, lifecycle, settings, mail, calendar, media and other service bridges. Linked into the app runner. |
| App packages and permission vocabulary | [`marathon-apps`](../../crates/marathon-apps/src/lib.rs), [`marathon-permissions`](../../crates/marathon-permissions/src/lib.rs) | Manifests, catalogue, signatures, archives, transactional install/removal, `marathon-dev`, and the shared permission names/disclosures. These are ordinary Rust libraries rather than a second UI toolkit. |
| Shared native support | [`marathon-rt`](../../crates/marathon-rt/src/lib.rs), [`marathon-qt`](../../crates/marathon-qt/src/lib.rs), [`marathon-i18n`](../../crates/marathon-i18n/src/lib.rs), [`marathon-keel`](../../crates/marathon-keel/src/lib.rs) | Owned process I/O executor, buses, logging, daemon storage, D-Bus/`QVariant` conversion, localization, and the Keel host contract/peer bus. |
| User data services | [`marathon-maild`](../../crates/marathon-maild/src/main.rs), [`marathon-davd`](../../crates/marathon-davd/src/main.rs), [`marathon-medialibd`](../../crates/marathon-medialibd/src/main.rs), [`marathon-telephonyd`](../../crates/marathon-telephonyd/src/main.rs) | IMAP/SMTP mail, DAV/contact sync, photo/video library, SMS/MMS/call history. They expose session-bus services and ask the shell's permission gate to admit callers. |
| Audio and weather | [`marathon-audiod`](../../crates/marathon-audiod/src/main.rs), [`marathon-weatherd`](../../crates/marathon-weatherd/src/main.rs) | PipeWire audio control/snapshots; weather retrieval, location and cache. Their D-Bus contracts are independent of QML rendering. |
| Installation and system lifecycle tools | [`marathon-store-handler`](../../crates/marathon-store-handler/src/main.rs), [`marathon-background`](../../crates/marathon-background/src/main.rs), [`marathon-health`](../../crates/marathon-health/src/main.rs) | Store URL/install operations; declared background unit generation, eligibility checks and wake arming; boot health/rollback assessment. |
| Device and developer helpers | [`marathon-gnssd`](../../crates/marathon-gnssd/src/main.rs), [`marathon-touchctl`](../../crates/marathon-touchctl/src/main.rs), [`marathon-websearch`](../../crates/marathon-websearch/src/main.rs) | Device GNSS decoding/positioning and NMEA output; virtual input for device testing; the local web-search HTTP service. Presence of a helper does not establish hardware qualification. |
| Keel app actions | [`keel`](../../crates/keel/src/lib.rs), [`keel-macros`](../../crates/keel-macros/src/lib.rs), [`keel-actions-codegen`](../../crates/keel-actions-codegen/src/lib.rs), [`keel-actions-schema`](../../crates/keel-actions-schema/src/lib.rs), [`keel-mcp`](../../crates/keel-mcp/src/lib.rs) | Rust action/entity declarations, code generation, schema and review validation, native action dispatch, and the MCP bridge to installed Keel app actions. |
| Assistant backend | [`pilotd`](../../crates/pilotd/src/lib.rs) | The existing Pilot daemon: routing, redaction, deterministic handlers, tool loop and egress accounting. |
| Store backend and token format | [`reef-backend`](../../crates/reef-backend/src/lib.rs), [`reef-licence`](../../crates/reef-licence/src/lib.rs) | Reef catalogue/install state/licence hand-off and offline licence-token verification. This does not make an external premium product a shell dependency. |

Two more Cargo workspaces live outside `crates/`:
[`apps/pilot`](../../apps/pilot/Cargo.toml) (`shoal-pilot`) and
[`apps/reef`](../../apps/reef/Cargo.toml) (`shipwright-reef`). Each builds a
native CXX-Qt/Keel application with QML UI and links Keel's SailfishApp.
Their manifests explicitly separate that build from the shell workspace.
[`tools/keel-launcher`](../../tools/keel-launcher) contains shared Rust launcher
and build sources; it is not another workspace member.

The October [Rust migration design](../design/2026-10-13-rust-platform-migration.md)
is historical. Its small initial migration inventory and references to
`marathon-core-native`/`tools/marathon-mail-oauth` do not describe the audited
tree. Most Rust usage predates the 2.0 reliability work; it must not be
presented as newly implemented by this programme.

## Native build and API boundaries

[`crates/CMakeLists.txt`](../../crates/CMakeLists.txt) drives locked Cargo
builds, exports generated CXX-Qt headers/initializers, links the native static
libraries and registers `Rust_Crates` as `cargo test --workspace --locked`.
The workspace test does not automatically test both separate app workspaces.
[`tests/CMakeLists.txt`](../../tests/CMakeLists.txt) conditionally registers
`Rust_Reef` when Keel SailfishApp development files are available.

| Boundary | Source contract to inspect before a change | Ownership and failure obligation |
| --- | --- | --- |
| QML to native app objects | [`marathon-app-native/build.rs`](../../crates/marathon-app-native/build.rs), actual `#[qinvokable]` declarations, generated `.cxxqt.h`/QML type metadata, [`platformqmltypes.h`](../../tools/marathon-app-runner/platformqmltypes.h) and production QML call sites | Preserve parameter count/types, expose actual success/failure, and keep GUI-thread work bounded. A permissive service fixture is not proof of native call compatibility. |
| Rust to the shell/daemon bus | [`marathon-app-native/src/shell.rs`](../../crates/marathon-app-native/src/shell.rs), service interfaces and [`marathon-rt/src/daemon.rs`](../../crates/marathon-rt/src/daemon.rs) | Separate a cached observation from a process crossing. Retain operation identity, distinguish unavailable from empty/refused, and own subscriptions until disposal. |
| Native launch to child process | [`tasks/launch.rs`](../../crates/marathon-shell-native/src/tasks/launch.rs), [`tasks/pool.rs`](../../crates/marathon-shell-native/src/tasks/pool.rs), [`gate.rs`](../../crates/marathon-shell-native/src/gate.rs) | A launch owns its PID registration, sandbox assignment/socket, child pipe and eventual exit. Failure/late completion must affect only the matching attempt. |
| App action/schema to execution | [`keel-actions-schema`](../../crates/keel-actions-schema/src/lib.rs), [`keel`](../../crates/keel/src/lib.rs), [`keel-mcp`](../../crates/keel-mcp/src/lib.rs), real app declarations | Validate arguments and outputs at the boundary; distinguish one-shot results from subscriptions and from long-lived background claims. |

The audited native manifests pin CXX-Qt/CXX-Qt-lib to **0.10.0** and their
direct zbus dependency to **6.1.0**. The workspace lockfile resolves cxx
**1.0.205**, async-io **2.6.0** and async-executor **1.14.0**; it also contains
a transitive zbus **5.19.0**. A dependency declaration or a Qt minimum is not
evidence of the compiler/Qt actually used for a test run. Record the selected
toolchain separately.

## Applying the API-design skill

The reviewed guidance is Margelo
[`api-design`](https://github.com/margelo/react-native-skills/blob/1e9e17be6f41c838db472d6a4b943fc26355a3be/skills/api-design/SKILL.md)
and [`cpp`](https://github.com/margelo/react-native-skills/blob/1e9e17be6f41c838db472d6a4b943fc26355a3be/skills/cpp/SKILL.md),
as required by [the native engineering workflow](ENGINEERING_WORKFLOW.md).
Its useful principles here are real call-site review, coherent states,
explicit errors, owned resources, cancellation and current-source checks.
TypeScript-only syntax and Nitro wrappers are not a reason to change
Marathon's native stack.

Keep cheap local values synchronous. For example,
[`Permissions.describe`](../../crates/marathon-app-native/src/permissions.rs)
reads the compiled permission vocabulary and does not require a new worker.
Bus queries and fallible mutations need an asynchronous operation contract,
with completion that still identifies the request. Use typed Rust values
inside that contract and one deliberate serialized representation at QML or
D-Bus boundaries; a blanket replacement of every `QVariantMap` is unnecessary.

### Journey 1: change an app's permission in Settings

1. The user toggles a permission in
   [`AppInfoPage.qml`](../../apps/settings/pages/AppInfoPage.qml) or
   [`PermissionAppsPage.qml`](../../apps/settings/pages/PermissionAppsPage.qml).
   A Settings choice is intended to survive a session restart.
2. The native setter takes `(appId, permission, granted, remember)` and
   forwards all four to `Permissions1.SetPermission`. The shell's
   [`Core::set`](../../crates/marathon-shell-native/src/permissions.rs) writes
   the decisions when `remember` is true.
3. The audited head supplied only three arguments from both pages. The test
   fixture also accepted only three, so the existing UI checks could not
   expose the bridge mismatch. The actual CXX-Qt 0.10 generated header was
   inspected and declares four required arguments, with no default or
   three-argument overload. The bounded repair supplies `true` explicitly and
   makes grant, revocation and failed-call checks assert that contract.
   PermissionPages is added to the required native UI gate.

This repairs the consumer contract. It does not turn the synchronous setter
into a nonblocking API or demonstrate a real D-Bus/restart journey through
the production permission store. The existing Rust persistence test and the
QML service-fixture tests cover different boundaries.

### Journey 2: reopen Settings after a partial uninstall

1. `AppManagerPage.refreshCleanup()` asks `AppInstaller` for pending cleanup;
   a user can retry cleanup after the app's launcher entry has disappeared.
2. The audited [`store.rs`](../../crates/marathon-app-native/src/store.rs)
   calls `STORE.ask_now` on that QML path. `canUninstall` also blocks on a
   cache miss, while `flatpakApps` turns a failed bus query into an empty list.
3. The repair uses asynchronous refresh with cached observations, explicit
   loading/unavailable/error state and retained last-known data. One active
   read and one coalesced successor serialize completion; a superseded reply
   is discarded before publication. A stale response cannot overwrite a newer refresh;
   a missing service is not an empty catalogue. Read-only refresh can retry
   safely without replaying an uninstall mutation. Runtime repair
   [`46cb5697`](https://github.com/mikevocalz/Marathon-Shell/commit/46cb569722a41c6887fe8a37ca17439596a3f5b3)
   adds `io::try_spawn`, so owned operations can report executor-start failure
   instead of leaving pending state behind after a dropped future.

The repaired `store.rs` contains no `ask_now` calls. Capability refresh uses
the new `AppStore1.UninstallCapabilities` batch method, with one authorization
check, at most 1,024 app IDs and filesystem reads off the executor. Calling
`CanUninstall` separately for every app would exceed the existing 30-call
per-second `AppStore` limit on larger catalogues. The client and shell must be
updated together; an older shell produces an explicit service error. Capability
results are advisory and do not reserve authority for a later uninstall.

The [AppInstaller contract](APP_INSTALLER_API.md) names the cheap snapshots,
refresh commands and result-change signals. Every snapshot carries
`available`, `loading`, `items` and `error`; each client read has a 15-second
deadline. Refresh failure retains the previous items, and an empty successful
result remains distinguishable from unavailability. `try_spawn` failure
releases pending admission and reports failure for refreshes and uninstall.
The actual generated client has a registered `Core_AppInstaller` controlled
D-Bus test, separate from the Settings tests with Platform service fixtures.
Its executed result must be recorded for the integrated candidate.

This is a migration of real Settings call sites. The remaining `ask_now` and
`shell::asks!` uses in mail, telephony, alarms, permissions, lifecycle and
settings need individual caller/result reviews rather than an incompatible
global macro rewrite.

### Journey 3: adopt a warm runner, then exit or retry

1. The shell selects a spare, assigns its sandbox to the app, inserts its
   active launch and registers its PID before sending the adoption message.
2. At the audited head, a write failure removes only `active_by_pid`; the PID
   maps/gate and sandbox assignment have already been changed. Removing that
   active record also prevents later `app_closed` from doing normal cleanup.
3. On success, `mem::forget(spare.stdin)` keeps the pipe open permanently.
   The actual [runner read loop](../../tools/marathon-app-runner/main.cpp)
   stops waiting after a complete newline, so the repair can close the pipe
   immediately after admitting that line. It does not need to leak the
   descriptor or retain it for the whole app lifetime.

The bounded pool repair takes ownership of the spare before assigning it,
admits a nonblocking message no larger than `PIPE_BUF`, handles a broken pipe
without a process-wide signal-policy change, and assigns the one-way Wayland
context only after admission. Refusal revokes that exact attempt's active
record, PID/gate and listener while preserving the route for the cold
fallback. Reaper callbacks retain the instance identity so an old exit cannot
clear refilled/reused-PID state. This is transport admission; it does not prove
that the app parsed the message, loaded QML or presented its first frame.

The existing request UUID, selected immutable app generation and explicit
sandbox policy are useful foundations. They do not supply generation-bound
D-Bus authority or narrower warm-pool mounts by themselves.

A second replacement race was reproduced through the actual generated
`Tasks` object: an old process could exit while the replacement remained in
`pending_launches`, before `appLaunched` moved it to `active_by_pid`. Cleanup
previously protected only active replacements and removed the pending task's
placeholder/lifecycle. Both pending and active attempts now retain ownership
after exact old-PID/listener cleanup. The replacement can then either map its
window or fail and clean up exactly once. The real `Core_TasksLaunch` test
failed both replacement rows before the fix; replacement success, failure and
an unrelated pending-app control all pass afterward. The delayed 30-second
cleanup branch shares the guard but was source-reviewed rather than waited
out in that test.

### Journey 4: an app exits while it holds background work

[`MusicApp.qml`](../../apps/music/MusicApp.qml),
[`ClockApp.qml`](../../apps/clock/ClockApp.qml), Camera and Maps already call
`Lifecycle.beginBackgroundTask`/`endBackgroundTask`. The app client maps
those to `AppLifecycle1`; the shell checks the app's declared capability.

At the audited head, unregistering an app clears its lifecycle state but
leaves numeric claims in the claim table. A later instance can start and end
a new claim of the same category, yet the orphan claim keeps that category
held. The bounded repair revokes the departing app's claims at unregister,
preserves other apps' claims, and never reuses a handle in the same session.
Exhaustion returns a bus error instead of overflowing the counter.

Revocation must not be placed in every PID removal: the launcher can remove
an old PID while a replacement is active, or retire a failed spare before a
cold fallback. Existing `app_closed` replacement guards and delayed
launch/PID checks must remain intact. The five resource-core regressions
exercise revoke/relaunch, other-app isolation, owner checks, refcounting and
handle exhaustion; they do not run the actual Qt unregister or D-Bus path.
A `BeginBackgroundTask` authenticated before exit can still reach the GUI
queue after unregister because authorization is app-ID based.
Process-generation authorization, service disconnects, active-claim bounds,
deadline enforcement and background energy accounting remain separate work.

## Remaining priorities

| Priority | Source-backed gap | Bounded next change and evidence needed |
| --- | --- | --- |
| P0 | [`gate.rs`](../../crates/marathon-shell-native/src/gate.rs) remembers PID-to-app strings and caches descendant resolutions; this is not an immutable app-generation credential | Define the owner identity used by launch, grants and bus mediation together. Verify PID reuse, updates, revocation and late callbacks against the exact generation; keep R03 open until the real boundary is enforced. |
| P1 | [`tasks/launch.rs`](../../crates/marathon-shell-native/src/tasks/launch.rs) keeps a shared `pending_route` and app-keyed launch-hold timers; transport admission is not app readiness | Own route/caller data and timer invalidation by launch request. Test interleaved launches, cancellation and late timeouts; expose the distinction between accepted, process-started and ready before consumers rely on completion. |
| P1 | `Service::ask_now` blocks the app GUI thread; `asks!` converts errors to defaults and `call` logs failures without a caller result | Migrate one real workflow at a time to cached state plus identified async completion. Verify delayed/unavailable services, cancellation/disposal and no UI stall. Keep normal absence distinct from failure. |
| P1 | `relay`/`follow` spawn detached signal loops and discard failed `qt.queue` results | Give each observer an owned cancellation path and stop work when its Qt owner disappears. Verify repeated creation/disposal and service loss/restart, without polling to hide readiness. |
| P1 | Background declarations are not a full installed-app scheduling lifecycle | Keep the existing third-party rejection until registration, update/removal, revocation, cancellation and deadline ownership are implemented and tested. The documented `mail.sync` declaration is illustrative; no bundled app currently declares it. The actual weather timer calls `Weather1.Refresh`. See [BACKGROUND_WORK](../BACKGROUND_WORK.md). |
| P1 | API fixtures can accept shapes that the generated bridge does not | Compare real generated metadata and production call sites during review, and require the affected native UI suite. Use an actual service/bus test where persistence, identity or cancellation is the changed behavior. |
| P1 | Successful app removal still cannot prove app-owned secret/settings deletion | Define ownership at secret/settings creation before implementing deletion. Preserve explicit incomplete outcomes; do not delete shared stores by an inferred app name. See [the transaction contract](APP_LIFECYCLE_TRANSACTIONS.md). |
| P2 | Device/display/service snapshots and subscriptions have different readiness and lifetime boundaries | Carry initial resolved values and subsequent changes consistently through cold/warm/live app paths. Verify actual native component behavior and physical display/service changes; retain R07's device gates. |

The related fixes are bounded reliability slices within R01–R08. They do not
complete the 37 approved 2.0 packages. Work/Personal Spaces stays entirely in
2.1. React Native/QNX targets, NYC-Tron adapters and Nitro Forge remain
independent app products; no premium checkout or licence is required for the
core tests described here.

## Validation record

This audit is based on actual manifests, Rust/Qt/QML consumers, the versioned
build/test registrations and the pinned skill sources. Its comparisons do
not rely on the GitHub language-percentage badge or the historical migration
document. Documentation checks cover link paths and `git diff --check`.

Native build, Rust test, generated-header, QML suite and device results must
be recorded for the actual implementation commits in
[NATIVE_VALIDATION.md](NATIVE_VALIDATION.md) and the
[remediation queue](REMEDIATION_QUEUE.md). An old green PR head is not a test
result for a newer repair, and Platform service fixtures do not verify the
production D-Bus/storage boundary.
