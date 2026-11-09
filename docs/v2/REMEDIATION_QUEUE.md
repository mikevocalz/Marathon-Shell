# V2 remediation queue and programme tracker

Updated November 9, 2026. This file contains ready-to-file engineering tickets, their acceptance criteria and the current state of all 37 approved work packages. The [backlog](BACKLOG.md) remains the feature/dependency specification; the [v1 gap audit](V1_GAP_AUDIT.md) records the source and report evidence behind these repairs.

## Tracking and evidence rules

Creating a GitHub issue in this fork returned HTTP **410**: `Issues has been disabled in this repository.` No remediation issue was created. This versioned queue is the tracking record while the repository's issue board is unavailable. R01–R08 are local ticket identifiers, not GitHub issue numbers. Assign the listed owner and reviewer roles to people when implementation starts; no personal assignment is implied here.

The PR states below were checked through GitHub on November 9. **Every linked PR is a draft and none is merged.** A tested slice is useful evidence for that slice; it does not complete a work package, qualify the integrated image or establish a release date. Record later changes with the exact PR head, tested tree, toolchain, commands, results and remaining device gates.

| Draft PR | Contribution | Evidence and remaining boundary |
|---|---|---|
| [#4: upstream intake][pr4] | 548 newer upstream commits; preserves the original planning files | Source/tree comparison and reachability checks. Full native integration, migration and device qualification remain. |
| [#5: background declaration contract][pr5] | Aligns schema/parser/lint/generator, rejects ambiguous actions/duplicate schedules and unsupported third-party declarations | 69 targeted Rust checks, Clippy, bundled-manifest/CLI checks reported. No third-party scheduling lifecycle, Mail sync action or automatic suspend. R06 follows it. |
| [#6: approved scope and audit][pr6] | 37-package programme, 2.1-only Work/Personal boundary, engineering workflow and current-source audit | Documentation/source review. No runtime package is complete because this PR exists. |
| [#7: live shell metrics][pr7] | Tracks the actual shell window and preserves native `Constants.qml` bindings; keeps the runner fallback | 10 Qt 6.11.3 checks reported, including real `Constants.qml`. Existing/cold/warm app propagation and physical display changes remain under R07. |
| [#8: durable task slice][pr8] | Task notes, completion, optional local due dates, bounded inert source metadata, typed task actions and persistent ID allocation | 43 store checks across Qt/time-zone combinations and 32 real pinned Keel.Actions checks reported. Full editor/page UI, reminder scheduling, Hub capture, source navigation, attachment grants and downgrade qualification remain. |

Earlier [#2: cover layout][pr2] and [#3: Hub triage][pr3] are also draft prototypes awaiting real native UI validation. [#1: managed native client RFC][pr1] is a documentation draft targeting `main`; it establishes no implemented runtime and must be scoped explicitly for any later `v2` integration.

The local integrated candidate `7cfc5479f3c2ba1ec861db5dfdcdc082ae4256fa` combines upstream `567f1faa` and the #4–#8 changes without cherry-pick conflicts. At the recorded checkpoint it passed **73 targeted Rust tests** (35 app-platform, 38 background) and **4/4 registered CTest targets**: screen metrics (10 Qt checks), Notes store (43), real Keel.Actions (32), and test reachability. This is stronger integration evidence for those boundaries, but it is not the full Silica/editor/page suite, a whole-image build or device qualification. Format and commit-subject checks passed for the three code PRs; full Alpine CI was still in progress when recorded.

## Repair order

Review/integrate #4 and qualify the affected source before duplicating upstream fixes. R01–R04 protect installation integrity and app boundaries; R08 makes the native UI gate dependable and should proceed in parallel. R05 supplies reference-device evidence throughout. R06 and R07 extend the bounded foundation slices in #5 and #7. Independent work can run in separate worktrees; integration and boundary review are sequential gates.

The native/API skills, source/version verification, multiagent implementation and independent review requirements in [ENGINEERING_WORKFLOW.md](ENGINEERING_WORKFLOW.md) apply to every ticket. Preserve Qt/Keel; use non-premium fixtures; target `v2`. Pick exact supported APIs from the selected source/SDK before coding.

## R01 — make app replacement atomic and preserve running generations

**Owner:** app platform + storage. **Independent review:** filesystem/recovery + app lifecycle. **Priority:** P0. **Programme:** V2-017/026/027. **Dependencies:** current-source intake (V2-001); coordinate with R02 and the app lifecycle owner.

**Problem/evidence:** current `crates/marathon-apps/src/install.rs::place` removes the existing install before copying the replacement and writing its receipt. A copy/receipt failure can leave no working app. The audit verifies this in both the inherited fork and upstream `567f1faa`. Preserve the existing private-copy signature/archive verification while changing installation. [Pinned source][install-source].

**First implementable slice:** stage a fully verified package and matching approved receipt on the destination filesystem, then replace one inactive installed app under a per-app transaction lock. The lock must live outside the directory being exchanged and coordinate install, uninstall and superseded-generation cleanup. Revalidate app identity, protected/system status, installed version and permission consent while holding it.

**Implementation contract:** commit with an atomic same-filesystem directory exchange on a verified supported platform, or refuse intact before live mutation when that capability is unavailable. Do not fall back to deleting the live app then copying. Specify file/directory synchronization, commit/recovery records and rollback states. A post-exchange synchronization failure must expose the actual recoverable state rather than reporting an unverified rollback. Keep swapped-out generations while a running runner's mount or lazy asset loading still uses them; define a safe retention/release contract and bounded cleanup before extending the slice to active apps.

**Acceptance:**

- Fail staging copy, disk allocation, receipt serialization, exchange and parent-directory synchronization independently. At every boundary, the discoverable installation is the intact old generation or the complete new generation with its matching receipt; never absent or mixed.
- Kill/restart the installer at each durable boundary and reconcile without guessing from a partially written file. Repeated recovery/rollback is idempotent.
- Race install/update/uninstall/cleanup for the same app; serialize them without touching another app. A stale permission approval or replaced package cannot bypass revalidation.
- Keep an old runner alive through update; it can load its remaining resources consistently. New launches use the committed generation. Cleanup failure cannot delete the live destination or a generation still in use.
- Reject unsupported cross-filesystem/atomic-exchange conditions safely. Preserve signed-package validation, archive traversal/symlink rejection and protected-app rules.

**Closing evidence:** real temporary-filesystem installer tests with fault injection and process death, plus a real runner lifecycle test. A successful rename helper test alone does not prove the installation transaction.

## R02 — make uninstall outcomes truthful and secrets app-owned

**Owner:** app platform + identity/storage. **Independent review:** security + data lifecycle. **Priority:** P0. **Programme:** V2-023/027/031/032. **Dependencies:** R01 transaction coordination; R03 mediation for secret ownership.

**Problem/evidence:** uninstall discards some cache/data/config deletion errors. `dataLifecycle.secrets` is documented but not acted on because Secret Service items lack app identity. [Installer][install-source], [manifest contract][manifest-source].

**First implementable slice:** return explicit outcomes for app files, cache, app data, configuration and retained user files. Preserve a durable cleanup/retry record after app code is removed. Distinguish removal, intentional retention, not found, denied and failed outcomes; do not report “data removed” when an I/O error was discarded.

**Implementation contract:** app credentials need ownership enforced by a trusted mediator, not an app-writable label or a guess based on key names. Define migration for legacy unowned secrets; preserve/report them until ownership is established. Use narrow grants and never wipe all Secret Service items. Scheduling registrations from R06 and pending file/action grants must join removal/revocation when those facilities exist.

**Acceptance:**

- Exercise `keep` and `remove`, protected apps, an absent app, repeated uninstall, partial deletion and restart/retry. The UI/CLI reports the same per-category state.
- Inject permission/I/O failures in each directory and credential category; retries finish only the outstanding work. An installed app's files are not confused with its retained data.
- Test foreign paths and symlink/path-substitution attempts. Preserve user-created shared/media files and another app's data and credentials.
- Create credentials for two real app identities; uninstall one removes only its owned credentials when requested. Legacy ambiguous items are reported, never silently claimed deleted.
- Race cleanup with update, an active process and background work under the R01 lock/lifecycle policy; no new work starts after effective revocation. The transaction lock does not stop app writes: define lifecycle quiescence/revocation before final deletion and test an active writer so it cannot recreate supposedly removed data.

**Closing evidence:** filesystem fault tests, two-app secret-boundary tests and actual uninstall/retry UI or CLI output. Document what cannot yet be removed safely.

## R03 — enforce app-specific session-bus and warm-pool boundaries

**Owner:** IPC/security + launcher. **Independent review:** native platform + lifecycle. **Priority:** P0. **Programme:** V2-011/023/031. **Dependencies:** V2-001; coordinate R04 accessibility and R06 background callers.

**Problem/evidence:** upstream already has private runtime tmpfs and inside-runner seccomp/Landlock; retain those improvements. Current documentation still describes an unfiltered session bus and pre-adoption pool spares sharing parent app data/cache directories and networking. [Security model][security-source].

**First implementable slice:** define and enforce an app-identity-based bus allowlist or equivalent mediation for one cold-launched fixture, including Secret Service/dconf access. Test service activation, well-known versus unique names, name-owner changes and reconnect. Preserve required shell, portal and audio operations.

**Implementation contract:** enforce the same identity and permissions before any app code executes in a warm runner. Narrow mounts/networking at safe adoption or redesign pooling; inherited broad permissions must not become the app's effective permissions. Explicitly report missing bwrap, disabled confinement and failed best-effort filters under the selected release policy. The current trust model for native distro packages remains explicit; a Marathon-app proxy is not evidence of confinement for every native process.

**Acceptance:**

- Two real fixtures with different identities cannot read each other's secrets, change unrelated dconf keys, call another app's private service or access sibling data/cache. Allowed operations remain functional.
- Repeat the denial matrix for cold launch, warm adoption, restart, bus activation/reconnect and service owner replacement. Identity cannot be self-asserted by changing an app ID.
- Revoke a permission during an operation and after adoption; subsequent calls fail consistently. A network-denied app cannot inherit the spare's network access.
- Test absence/failure of each enforcement mechanism. The release does not silently advertise a boundary that was not established.
- Define and test the sandbox override for unset, `0`, `1` and malformed values. Current `sandbox.rs` disables bwrap whenever `MARATHON_DISABLE_SANDBOX` is present, including `0`; parsing, diagnostics and reported protection must agree. [Launcher source][sandbox-source].
- Validate the cooperating R04 accessibility path without exposing other apps' text to an ordinary app.

**Closing evidence:** native process/bus/mount/network boundary tests against real service mediation, including negative cases and actual launch paths. Measure pool launch overhead after the boundary is correct.

## R04 — provide an accessible sandbox without exposing other apps

**Owner:** accessibility + native platform. **Independent review:** IPC/security + interaction design. **Priority:** P0. **Programme:** V2-006/011/023. **Dependencies:** R03 identity/mediation design; V2-003 control roles.

**Problem/evidence:** current security documentation explicitly says screen readers cannot see sandboxed Marathon apps because the accessibility bus is withheld. Exposing the unrestricted bus would allow an ordinary app to read other apps' accessible text. [Security model][security-source].

**First implementable slice:** select the actual supported assistive-technology stack, define trusted AT authorization and broker its app-specific accessibility interaction. Implement one real sandboxed app journey with meaningful roles, names, values, focus and state changes. QML accessibility labels alone are insufficient.

**Acceptance:**

- With a real AT client, launch a sandboxed app, navigate/read content, edit text, activate an action, handle a modal prompt and return focus. Verify keyboard-only alternatives for essential gestures.
- Text scaling, reduced motion and orientation/viewport changes preserve an understandable reading and focus order. Password/protected fields remain protected.
- An ordinary hostile app cannot subscribe to or enumerate another app's accessible text; trusted AT can access the user-selected scope. Denial/revocation/restart is explicit and recoverable.
- App death, AT restart, lock/unlock and dialog cancellation do not strand focus or retain stale private content.
- Validate the same contract for cold and warm launches and supported native toolkit integration; label any unavailable lane accurately.

**Closing evidence:** actual AT logs/interaction recording on the native stack plus negative privacy tests. A stub tree or screenshot does not close this ticket.

## R05 — publish a current per-device phone and recovery matrix

**Owner:** device QA + release. **Independent review:** telephony/media + recovery/security. **Priority:** P1, continuous release gate. **Programme:** V2-001/008/021/024/025/026/028/029. **Dependencies:** a reproducible integrated image and selected reference SKU/carrier.

**Problem/evidence:** the newest Q25 release has newer idle-power/image improvements but explicitly lacks fresh calls/SMS/hands-free and outdoor GNSS validation. Device/layout encryption and rollback differ. The modem checklist, source functions and another device's successful run are not a passed matrix. [Audit](V1_GAP_AUDIT.md), [release][release-source].

**First implementable slice:** record one exact image/source SHA, device/SKU, kernel/firmware, carrier/SIM test arrangement, installation method and recovery image, then run a reproducible communications/wake smoke journey. Expand the same record; never combine results from different builds into one unexplained “works” cell.

| Matrix group | Required evidence |
|---|---|
| Calls/messages | Incoming/outgoing calls, screen-off/locked arrival, missed-call state, mute/speaker/earpiece/Bluetooth hands-free, SMS/MMS, data/call transition and registration recovery; arranged emergency-call behavior testing where applicable |
| Power/wake | Doze versus actual suspend distinguished; overnight drain, idle residency, alarm/message/call wake latency, active-call inhibition, repeated wake/refreeze and thermal observations |
| Media | Front/rear still size, focus/exposure, orientation, video audio/frame rate, background recording, camera permission revocation, low storage and lock/call interruption |
| Location/maps | Outdoor cold/warm GNSS acquisition, denied/revoked location, real GPU basemap rendering, search/directions/offline degradation, QEMU exclusions stated separately |
| Data/update/recovery | Actual encrypted categories, failed enrollment state, signed N→N+1→bad N+2, full disk, interrupted update, early boot failure, retained state, fallback kernel/root and documented manual recovery |
| Display/input | Supported panel/keyboard/touch routes, scale, rotation, optional external display and accessible interaction; unsupported capabilities explicitly marked |

**Acceptance:** each cell names pass, reproduced failure, unsupported or not run, with artifact/date and a follow-up ticket. Repeated journeys survive restart and realistic interruptions. Preserve the working data copy before destructive recovery tests. Keep subscriber details and secrets out of public diagnostics. Release claims derive from the matrix; an untested device, carrier or image does not inherit another row's result.

**Closing evidence:** publish the selected release-target matrix and recovery procedure with no unresolved critical journey for that target. Subsequent image changes invalidate affected cells until retested; the matrix remains a continuing release gate.

## R06 — complete installed background-work lifecycle and a real mail action

**Owner:** lifecycle/SDK + mail/sync. **Independent review:** systemd/power + security. **Priority:** P1. **Programme:** V2-009/010/025/028. **Dependencies:** qualify #5, R01/R02 package lifecycle and R03 identity; R05 before privileged wake or automatic suspend promotion.

**Problem/evidence:** #5 fixes the declaration/eligibility contract and safely refuses unsupported third-party scheduling. It does not add installed-app registration, update, revocation/removal, retry scheduling, an actual Mail action or automatic suspend. The documented `mail.sync` name is illustrative, not an API that implementation may assume exists. [Background contract][background-source], [draft #5][pr5].

**First implementable slice:** design one authoritative registration store and a bounded native broker lifecycle, coordinated with installation. Install one fixture's eligible advertised action, observe it run under its real identity, update its declaration, revoke it and uninstall it with no residual work. Select actual systemd/service APIs from the pinned runtime; keep app declarations from granting privileged wake by themselves.

**Mail slice:** add a real app-owned sync action only after inspecting Mail's current service contract. Define empty-argument eligibility or an explicit broker-supported argument contract, account selection, cancellation, offline result, authentication-required result and sync reconciliation. Advertise and generate the actual action schema; do not hardcode an unimplemented action ID. Timer invocation must not blindly replay ambiguous outbound sends.

**Acceptance:**

- Install/update/remove and failed installation leave registration consistent with the committed package/receipt. Restart regenerates only authorized work; removed/revoked apps leave no active units or future timers.
- Bound tasks per app, intervals, execution time, retries, overlap and concurrency. Handle missed slots, clock jumps, time zones, unmet charging/battery/network constraints and repeated failures without an invocation storm.
- Test permission revocation, stale action identity, service/app death, in-flight update/removal and bus reconnect. A revoked task cannot schedule new work after its effective revocation point.
- Exercise the actual advertised Mail action against controlled supported accounts, offline/reconnect and expired credentials; distinguish sync success from content merely appearing in a fixture.
- Measure hardware alarms/calls/messages, wake and thaw/refreeze in R05. Automatic suspend/resuspend is a separate explicit policy decision within this ticket's later work, not a consequence of adding a timer.

**Closing evidence:** real registration/service execution and lifecycle tests plus the selected-device power/wake results. Keep unsupported third-party declarations refused until their complete lifecycle is delivered.

## R07 — propagate one live display contract to cold, warm and running apps

**Owner:** compositor + app lifecycle. **Independent review:** native input/accessibility + adaptive UI. **Priority:** P1. **Programme:** V2-002/018/019. **Dependencies:** qualify #7, current runner/Keel APIs and R03 safe adoption.

**Problem/evidence:** #7 fixes shell-window metrics and native QML bindings. `Tasks::setDevice` still captures launch geometry/DPI, and runners initialize `MARATHON_SCREEN_WIDTH`, `MARATHON_SCREEN_HEIGHT` and `MARATHON_DPI` from their environment. That does not provide a coordinated update to existing apps or warm spares. [Draft #7][pr7], [audit](V1_GAP_AUDIT.md).

**First implementable slice:** define a versioned display/viewport update contract: available region, scale/DPR, orientation, output identity and capability flags, with one source of truth and lifecycle ownership. Distinguish logical coordinates, physical pixels and user scale. Apply it to one existing native app and the cold-launch path without severing QML bindings.

**Acceptance:**

- Resize, rotate and change scale while the shell, a running app, a newly launched app and a warm-adopted app are present. They agree on usable geometry and effective scale; no app receives a stale adoption snapshot.
- Move between mixed-DPI displays and hot-unplug an output. All windows remain reachable, preserve focus/drafts/task identity and receive ordered current state rather than late updates for a destroyed output.
- Large text, keyboard appearance and safe-region changes preserve interaction targets. Native pointer/touch coordinates stay aligned with rendered controls.
- Detach/destroy/rebind a window or restart a runner without dangling subscriptions or another app's metrics. Test Qt/Keel paths actually used by the image.
- Keep hinge/posture support capability-gated with its own device evidence. Passing a desktop resize test is not a foldable port.

**Closing evidence:** registered native contract tests plus a real multi-display/device journey. Retain #7's real `Constants.qml` regression and runner fallback tests; supplement them with actual process propagation and hot-plug.

## R08 — make QML validation reliable and real native UI coverage mandatory

**Owner:** build/CI + Qt/Keel UI. **Independent review:** test infrastructure + affected app owners. **Priority:** P0, parallel foundation. **Programme:** V2-001/005/006/013/021/028/029. **Dependencies:** exact Qt/Keel pins and complete native UI dependencies; integrates all candidate PRs.

**Problem/evidence:** the session's repository-wide `scripts/validate-qml.sh` run reported **405 checked files, 313 warning counts and one error count**. Its unanchored `Error:` match can match the source excerpt `mmscError:` in `apps/settings/pages/MmsDialog.qml`. The script also swallows the `qmllint` status with `|| true`; a missing tool can be misreported as a clean file because its diagnostic does not match that filter. The full Sailfish.Silica, Nemo.Configuration and Sailfish.Share UI stack was unavailable in that validation environment. The result was not a green full-UI run. [Validator][validator-source].

Initial PR checks were observed empty, and runs subsequently appeared for #5, including a successful format check and an in-progress CI run. This does **not** establish why any initial run was absent, that workflows are disabled, or that complete native UI CI has passed. Gate the actual emitted jobs and their coverage.

**First implementable slice:** make the validator preflight its selected `qmllint` binary, version and required import/type-information paths; preserve the tool's actual exit/severity outcome. Use supported structured diagnostics where available, or a parser tied to the pinned version's diagnostic format. Define a deliberate warning policy and distinguish tool/setup failure from QML errors. Do not match arbitrary source excerpts as diagnostics or suppress missing imports to obtain green output.

**Acceptance:**

- A valid file containing `mmscError:` passes; a real syntax/type/property error fails with file/location/severity. Warnings follow an explicit policy and are not declared harmless by default.
- Missing/executable-failing qmllint, missing required Qt/Keel imports, invalid import paths and a crashed tool produce a clear non-green setup result. No `|| true` path converts failure into success.
- Validate all intended shell/app/module roots, not only `apps/`. File paths with spaces and empty/discovered-zero coverage are handled deliberately; report actual checked/skipped counts.
- CI for PRs targeting `v2` emits a required native UI job using the pinned Qt/Keel build and complete Silica/configuration/share dependencies. It runs registered CTest/Qt Quick suites for changed shell controls and app pages, including Notes editor/task creation/completion/date picker and Hub/cover interactions as applicable.
- Keep pure logic, real Keel.Actions and actual UI results separate. A synthetic UI toolkit or parser-only pass cannot substitute for the real affected UI suite. Targeted service stubs must be named and must not replace the component being asserted.
- Detect missing/skipped test registration and unexpected zero-test runs. Preserve test logs, dependency versions and the tested tree; require the selected job result before marking a candidate ready. Branch-protection settings must match real emitted job names and the approved repository policy.
- Run the integrated candidate stack after #4; passing an isolated slice does not establish compatibility with the 548-commit intake. Follow with R05 device interaction for behavior the host cannot validate.

**Closing evidence:** validator failure-mode regressions, a reproducible complete UI environment and successful required native UI jobs on the exact candidate tree. Describe any remaining hardware gate explicitly.

## 37-package programme tracker

**No package is marked complete.** “Draft slice” identifies reviewable work with bounded evidence; “planned” means the package's acceptance is still outstanding. R-tickets supplement the existing [work-package definitions and dependency graph](BACKLOG.md); they do not replace them or silently reduce scope.

| Package | Capability | Current programme state | Next gate / linked work |
|---|---|---|---|
| V2-001 | Reproducible platform/device baseline | Draft intake #4 | Integrate and build exact source; R05/R08 evidence |
| V2-002 | Adaptive display/input contract | Draft shell slice #7 | R07 cold/warm/running propagation and device display changes |
| V2-003 | Semantic theme and controls | Planned | Token/icon/state parity, accessible contrast/scale and native review |
| V2-004 | Flow/Peek and gesture arbitration | Planned | Interruption/cancel/reverse/focus tests across lock/call/rotation |
| V2-005 | Home/Covers/Hub/Quick Controls | Draft prototypes #2/#3 | Real native UI gate R08 plus adaptive/accessibility acceptance |
| V2-006 | Accessibility and keyboard focus | Planned | R04 real AT bridge; complete essential journeys |
| V2-007 | Conversation/account/provider model | Planned | Stable identity and supported provider capability contract |
| V2-008 | Communication adapters and sync | Planned | Controlled real accounts; R05 cellular matrix; truthful provider limits |
| V2-009 | Drafts/offline queue/recovery | Planned; #5 is prerequisite work | Durable reconciliation and ambiguous-send behavior; R06 |
| V2-010 | Semantic activities/private covers | Planned; #5 is prerequisite work | Activity lifecycle/budgets/privacy; R03/R06 |
| V2-011 | Typed invocation and scoped grants | Planned; #8 is an action consumer | Caller/target death, cancel/timeout/revocation/result-return tests |
| V2-012 | Keyboard/search/IME/trackpad | Planned | Multilingual composition, collision ownership and focus return |
| V2-013 | Communication/productivity app UI | Draft Notes slice #8 | R08 actual editor/page suites; complete cross-app/offline journey |
| V2-014 | Native RN host/service inventory | Planned | Actual Fabric/window/input/lifecycle proof; #1 remains only RFC |
| V2-015 | Separate native NYC-Tron adapter | Planned | Generic native controls/token/input/accessibility parity |
| V2-016 | Native package/app compatibility | Planned | Non-premium fixtures; separate authorized commercial-app qualification |
| V2-017 | Signed native SDK sample/template | Planned | R01 safe package lifecycle, clean install/update/restart/uninstall |
| V2-018 | Split screen/task pairs | Planned | R07 plus retained task/focus state and window constraints |
| V2-019 | External displays/mixed DPI | Planned | R07 hot-plug and reachable-window recovery |
| V2-020 | Drag/drop/pointer/pen | Planned | Narrow grants, keyboard alternatives and observed hardware capabilities |
| V2-021 | Core apps/onboarding/settings | Planned | R05/R08 app-device-accessibility matrix and alarm behavior |
| V2-022 | Optional selected-context Pilot | Planned | Permission-bound actions, outbound confirmation and hostile-content tests |
| V2-023 | App/IPC/secret/pool security | Planned | R02/R03/R04 enforcement and revocation evidence |
| V2-024 | Encryption/recovery/boot assessment | Planned | R05 actual image/layout status, enrollment failure and recovery |
| V2-025 | Telephony/media/power/device QA | Planned; #5 is bounded foundation | R05 current-device matrix and R06 lifecycle/power evidence |
| V2-026 | Signed updates/migration/recovery | Planned | R01/R05 installation integrity and per-device rollback |
| V2-027 | Reef/app trust/Deckard parity | Planned | R01/R02; real signed install/update/uninstall and declared compatibility |
| V2-028 | Frame/latency/memory/energy harness | Planned; isolated tests exist | R05/R06/R07/R08 reproducible integrated measurements |
| V2-029 | Device release readiness/docs | Planned | All OS-scoped gates; truthful published limits and recovery; no commercial prerequisite |
| V2-030 | Paired-device continuity | Planned | Peer trust/revocation and one real interrupted transfer before remote actions |
| V2-031 | Credentials/passkeys | Planned | R02/R03 identity foundation; real authenticator/origin/recovery proof |
| V2-032 | Migration/export/restore | Planned | Category coverage, reversible import and clean-device restore; R01/R02 |
| V2-033 | Tasks/attachments/provenance | Draft first slice #8 | Real UI and format/downgrade qualification; capture/grants/Calendar/sync remain |
| V2-034 | Secure messaging/voice/video | Planned | Maintained native protocol/SDK decision, verified identity and actual media/encryption evidence |
| V2-035 | Personal Travel/Bedside/Focus | Planned | Reversible personal preferences, alarm exceptions and time/charging transitions |
| V2-036 | Keyboard Instant Actions/prediction | Planned | Deterministic visible-target dispatch and protected-field/IME rules; #8 alone is not this surface |
| V2-037 | Meeting preparation/follow-up | Planned | Stable task/note links, time zones/offline state and confirmed outbound actions |

## W21 — Work/Personal Spaces: deferred to 2.1

**Status:** deferred by the user's release decision. **Owner roles for 2.1 planning:** product + identity/security. **Canonical packages:** V21-001 (organization/switching) and V21-002 (enforced isolation/management) in the [2.1 appendix](MODERNIZATION_PLAN.md#15-version-21-appendix-workpersonal-spaces).

The deferral includes lightweight work/personal views, account assignment to spaces, work mode, profile switching, managed profiles, separate work storage/credentials and security isolation. No 2.0 package depends on W21. Multiple personal accounts and personal Travel/Bedside/Focus scenes remain 2.0 capabilities; they must not introduce deferred profile behavior indirectly.

When 2.1 planning begins, write identity, storage, app, notification, clipboard/search/share, device-management and cross-space authorization contracts before UI. Acceptance must distinguish organizational labels from enforced separation and include migration, revocation, lock, leakage and recovery. No Work/Personal implementation is authorized by the 2.0 remediation tickets above.

[pr1]: https://github.com/mikevocalz/Marathon-Shell/pull/1
[pr2]: https://github.com/mikevocalz/Marathon-Shell/pull/2
[pr3]: https://github.com/mikevocalz/Marathon-Shell/pull/3
[pr4]: https://github.com/mikevocalz/Marathon-Shell/pull/4
[pr5]: https://github.com/mikevocalz/Marathon-Shell/pull/5
[pr6]: https://github.com/mikevocalz/Marathon-Shell/pull/6
[pr7]: https://github.com/mikevocalz/Marathon-Shell/pull/7
[pr8]: https://github.com/mikevocalz/Marathon-Shell/pull/8
[install-source]: https://github.com/patrickjquinn/Marathon-Shell/blob/567f1faa8bfdf31611dd401134c293daa160221c/crates/marathon-apps/src/install.rs
[manifest-source]: https://github.com/patrickjquinn/Marathon-Shell/blob/567f1faa8bfdf31611dd401134c293daa160221c/docs/APP_MANIFEST_SCHEMA.md
[security-source]: https://github.com/patrickjquinn/Marathon-Shell/blob/567f1faa8bfdf31611dd401134c293daa160221c/docs/SECURITY_MODEL.md
[sandbox-source]: https://github.com/patrickjquinn/Marathon-Shell/blob/567f1faa8bfdf31611dd401134c293daa160221c/crates/marathon-shell-native/src/sandbox.rs
[background-source]: https://github.com/patrickjquinn/Marathon-Shell/blob/567f1faa8bfdf31611dd401134c293daa160221c/docs/BACKGROUND_WORK.md
[validator-source]: https://github.com/mikevocalz/Marathon-Shell/blob/bc39c23cac18221df21e410a45f8cc72d0ae9824/scripts/validate-qml.sh
[release-source]: https://github.com/patrickjquinn/Marathon-Shell/releases/tag/zinwa-q25-26110802
