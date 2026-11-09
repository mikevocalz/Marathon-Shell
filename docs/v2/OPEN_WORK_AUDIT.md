# Open work and native API audit

Snapshot: **November 9, 2026, 14:55 UTC**. Source baseline:
[PR #9 at `8e9e0892f646d3e11fd581367d148d7f063d7dc7`][baseline].
This inventory covers every open pull request in
[`mikevocalz/Marathon-Shell`][repo], the eight local remediation tickets,
and all 37 approved 2.0 work packages. It is an evidence record, not a release
approval. Later code changes need their own candidate validation.

## Current repository state

The native GitHub API reports **11 open PRs**. PRs **#1–#9 are drafts**;
**#10 and #11 are non-drafts**. All remain open and unmerged. The repository
reports `has_issues: false`; listing open issues returns the same 11 PR
entries and **zero standalone issues**. No issue-creation attempt was made
during this audit. The earlier HTTP 410 observation remains historical
evidence in [the remediation queue](REMEDIATION_QUEUE.md).

The checked branch heads are `main` at
`c2c1b2fe32aeaa51edf75a45045cbfbbc08c4ac5` and `v2` at
`bc39c23cac18221df21e410a45f8cc72d0ae9824`. GitHub reports every PR
mergeable with a clean merge state against its own base. Both base branches
report `protected: false`. These observations do not prove that the open
PRs can be merged together safely or that their feature acceptance is met.

All **Work/Personal Spaces remain in 2.1**. Personal multiple accounts and
Travel/Bedside/Focus remain in the 2.0 programme. The implementation target
is the current Qt/Keel/Linux shell; the native-client RFC, a Passport
inspection utility, and visual research do not establish another working
runtime or a supported phone.

## Every open PR and its exact hosted evidence

The head link in each row names the full inspected commit. The CI API
returned that exact `head_sha`; the build logs, job results and format
workflow were inspected independently of the PR body. All listed CI and
format runs completed successfully. CTest totals are registered suites,
not counts of independent unit assertions.

| PR and contribution | State / base | Inspected head | CI run / passed CTests | Format run |
|---|---|---|---|---|
| [#1: managed native-client contract][pr1] | Draft / `main` | [`209485b7`](https://github.com/mikevocalz/Marathon-Shell/commit/209485b7d23c4468ab67c45348af5c3e7ef7df12) | [42618435451](https://github.com/mikevocalz/Marathon-Shell/actions/runs/42618435451): 43/43 | [42618435438](https://github.com/mikevocalz/Marathon-Shell/actions/runs/42618435438) |
| [#2: adaptive live-cover overview][pr2] | Draft / `v2` | [`58c35d6d`](https://github.com/mikevocalz/Marathon-Shell/commit/58c35d6d3f67779dbce4bae0a76e4e4481372258) | [42618540016](https://github.com/mikevocalz/Marathon-Shell/actions/runs/42618540016): 43/43 | [42618539844](https://github.com/mikevocalz/Marathon-Shell/actions/runs/42618539844) |
| [#3: Hub unread/source triage][pr3] | Draft / `v2` | [`a13f6f97`](https://github.com/mikevocalz/Marathon-Shell/commit/a13f6f973de04a7c629605f5a22a42533e774519) | [42618555389](https://github.com/mikevocalz/Marathon-Shell/actions/runs/42618555389): 43/43 | [42618555433](https://github.com/mikevocalz/Marathon-Shell/actions/runs/42618555433) |
| [#4: upstream intake][pr4] | Draft / `v2` | [`79f879b5`](https://github.com/mikevocalz/Marathon-Shell/commit/79f879b54ad3a4aa918ffda1a5bb0ef97538c763) | [42613358603](https://github.com/mikevocalz/Marathon-Shell/actions/runs/42613358603): 50/50 | [42613358292](https://github.com/mikevocalz/Marathon-Shell/actions/runs/42613358292) |
| [#5: background declarations][pr5] | Draft / `v2` | [`90d24c79`](https://github.com/mikevocalz/Marathon-Shell/commit/90d24c799a59cc2ecc9eac031a73afdbf11037e3) | [42618522454](https://github.com/mikevocalz/Marathon-Shell/actions/runs/42618522454): 43/43 | [42618522368](https://github.com/mikevocalz/Marathon-Shell/actions/runs/42618522368) |
| [#6: approved scope and v1 audit][pr6] | Draft / `v2` | [`77f25467`](https://github.com/mikevocalz/Marathon-Shell/commit/77f25467123367cee0634777165bbddcd48285df) | [42618482063](https://github.com/mikevocalz/Marathon-Shell/actions/runs/42618482063): 43/43 | [42618482092](https://github.com/mikevocalz/Marathon-Shell/actions/runs/42618482092) |
| [#7: live shell metrics][pr7] | Draft / `v2` | [`9cbd119f`](https://github.com/mikevocalz/Marathon-Shell/commit/9cbd119fccd00dfdcc60b75d29a197f15190464e) | [42618527057](https://github.com/mikevocalz/Marathon-Shell/actions/runs/42618527057): 44/44 | [42618527286](https://github.com/mikevocalz/Marathon-Shell/actions/runs/42618527286) |
| [#8: durable Notes task slice][pr8] | Draft / `v2` | [`4f8a70b8`](https://github.com/mikevocalz/Marathon-Shell/commit/4f8a70b8d9b1267c5bc25168c50cdfd1cfad6270) | [42618529464](https://github.com/mikevocalz/Marathon-Shell/actions/runs/42618529464): 43/43 | [42618529336](https://github.com/mikevocalz/Marathon-Shell/actions/runs/42618529336) |
| [#9: integrated reliability][pr9] | Draft / `v2` | [`8e9e0892`][baseline] | [42613072133](https://github.com/mikevocalz/Marathon-Shell/actions/runs/42613072133): 54/54 plus separate 6/6 native UI | [42613071991](https://github.com/mikevocalz/Marathon-Shell/actions/runs/42613071991) |
| [#10: passive Passport inspection][pr10] | Non-draft / `v2` | [`e971e4cc`](https://github.com/mikevocalz/Marathon-Shell/commit/e971e4ccab65c896509d172d54bc6c9ea048a598) | [42618587542](https://github.com/mikevocalz/Marathon-Shell/actions/runs/42618587542): 44/44 | [42618587615](https://github.com/mikevocalz/Marathon-Shell/actions/runs/42618587615) |
| [#11: visual/TAT research][pr11] | Non-draft / `v2` | [`95b78f47`](https://github.com/mikevocalz/Marathon-Shell/commit/95b78f47761a7eb0ef473093b0887ecc925491e2) | [42626410421](https://github.com/mikevocalz/Marathon-Shell/actions/runs/42626410421): 43/43 | [42626410388](https://github.com/mikevocalz/Marathon-Shell/actions/runs/42626410388) |

### What these green checks do and do not establish

Every build job reported **five documented inner Rust/Qt skips** accepted
by the existing skip audit. That audit does not enumerate Python unittest
skips; a passing CTest entry alone cannot establish that every inner test
executed. The recorded OTA evidence still excludes four systemd/sfdisk
cases on the older branches and six systemd-sysupdate cases on #4/#9.
No physical-device or systemd OTA consumer qualification follows from
these Alpine results.

Only #9 emits the separate `native-ui` job. Its
[build job 129146216397](https://github.com/mikevocalz/Marathon-Shell/actions/runs/42613072133/job/129146216397)
passed 54/54 registered CTests and strict workspace Clippy. Its
[native UI job 129146216706](https://github.com/mikevocalz/Marathon-Shell/actions/runs/42613072133/job/129146216706)
passed `NativeUI_Toolkit`, `Qml_apps_notes_tests`,
`Qml_settings_AppPages`, `Qml_shell_PageViewHub`,
`Lint_QmlValidator` and `NativeUI_GateContract`.
The jobs overlap in contract coverage; their totals should not be added
as independent tests.

All ten other build logs explicitly report missing `qmllint` and skipped
QML validation. Their green CI does not execute the complete changed
Keel UI. #9's real pinned-Keel gate uses named platform-service fixtures
and an isolated JSON Configuration backend; it does not qualify
production dconf, external sharing, the full compositor, all shell/app
suites, or full-source QML warnings. See
[native validation](NATIVE_VALIDATION.md).

### Review and description reconciliation

There are no inline review threads, no outstanding requested reviewers,
and no `CHANGES_REQUESTED` review submissions on any of the 11 PRs.
This is absence of recorded requests, not evidence of human approval.

- #2 retains a [formatting bot comment](https://github.com/mikevocalz/Marathon-Shell/pull/2#issuecomment-6738781093)
  from an older run. Its current format run above passes.
- #10 has only a [Devin monitoring comment](https://github.com/mikevocalz/Marathon-Shell/pull/10#issuecomment-6738494411).
  Its body still calls the final build pending; the exact-head run above
  completed successfully and includes `Passport_Inspection`.
- #11 has a no-findings Devin comment review and a
  [Codex no-findings summary](https://github.com/mikevocalz/Marathon-Shell/pull/11#issuecomment-6739156426)
  for earlier commit `4ba95c0210df1e7a635e7c4369cf2e7f3c7b66ee`.
  They do not review the current head or establish security approval.

## Integration and overlap

The complete Git trees at all 11 heads were compared with #9; none of the
API tree responses was truncated. The current tips of #4–#8 diverge from
#9 because later validation fixes were carried on their own branches.
A different commit ID therefore does not prove missing behavior, and
reapplying every branch would duplicate shared fixes.

| PR | Relationship to #9 at the audited head | Work still needed |
|---|---|---|
| #1 | The RFC file is absent from #9; its base remains `main`. | Review the proposed native host/runner contract explicitly under V2-014–017. No runtime is implemented by the RFC or its CI repairs. |
| #2 | `OverviewGrid.js`, its two overview/task-switcher test files and UX research are absent; task-switcher and shell registration files differ. | Integrate the actual geometry/interaction slice, reconcile upstream task roles and run its real native UI suite. Test task insertion/removal, page anchoring, resize and interruptions. |
| #3 | Its `MarathonHub.qml` and `tst_hub.qml` blobs differ from #9. | Integrate unread/source-filter behavior with current Hub state, then add the actual suite to required native coverage. Account-level provider triage remains separate. |
| #4 | The upstream intake is already in #9 with subsequent integration changes; no still-existing #4 changed file is absent. | Review migrations and integrated image/device behavior. Do not revert newer lifecycle, launcher, CI or Settings changes to make blobs equal. |
| #5 | The parser/schema/generator/fixture contract is present; installer/lock/docs differ because #9 extends them. | R06 installed scheduling, revocation/removal, real Mail action and power qualification. Keep unsupported third-party declarations refused. |
| #6 | All eight planning documents exist; README/queue have newer integrated content. | Preserve scope and acceptance, refresh evidence without closing packages from documentation. |
| #7 | ScreenMetrics source/header, Constants and registered native tests match; shell wiring contains later integrated changes. | R07 propagation to cold, warm and already-running apps; real display/DPR hotplug. |
| #8 | All twelve Notes implementation/test/action-manifest paths changed by #8 are byte-identical in #9. | Production storage, downgrade/restore, reminders, capture/grants, Calendar and sync remain unfinished. |
| #9 | Selected source baseline for the next reliability repairs. | Continue R01–R04/R08 boundaries and qualify the combined image. Green checks do not close any whole R ticket. |
| #10 | Its three `tools/passport/` files and test registration are not integrated. | Review/integrate the inspection-only utility independently if selected. Passive IORegistry/ELF evidence is not a Passport bootloader, Linux port or recovery path. |
| #11 | The two research documents are absent; README/UI_SPEC differ. | Reconcile documentation with current tokens and scope. Implemented theme/accessibility/motion work still belongs to V2-003/005/006/028. |

Historical native failures and upstream fixes must keep their original
attribution. In particular, the terminal translation labels, known-skip
manifest, audio fixture cache initialization and Clippy assertion repairs
already have current passing evidence. They are not new failures to fix
again. Do not close or merge overlapping PRs solely from this inventory;
review the resulting combined source and its evidence first.

## Concrete native API repairs identified in the baseline

These are source findings at `8e9e0892`, independent of hosted success.
Implementation and validation are tracked separately; this audit does
not report the following repairs as delivered.

| Boundary | Verified defect / consequence | Smallest useful repair and required regression |
|---|---|---|
| Warm-runner adoption, R03 | [`pool.rs`][pool-source] assigns the sandbox socket, inserts the active launch and calls `register_pid` before writing adoption input. A failed write removes only the active launch. [`register_pid`][launch-source] also records forward/reverse PID identity and gate authority. The unadopted spare's exit path does not undo those records. | Retire the failed spare and remove only its exact registration/authority, preserving a replacement launch. Exercise missing/closed stdin, actual failed write, stale exit after replacement and successful adoption through the native task boundary. Synchronous pipe writes and successful-adoption stdin ownership also deserve a separate bounded-lifetime review. |
| Pending uninstall query, R02/R08 | [`AppInstaller::pending_uninstalls`][store-source] invokes `STORE.ask_now` directly from QML. The Qt owner can wait on D-Bus; the same module also uses synchronous calls for `can_uninstall` and `flatpak_apps`. | Move the pending-cleanup query to owned asynchronous work, bound request concurrency/deadline, retain the last successful snapshot on failure, and reject stale completion. Exercise a stalled provider, repeated refresh, failure/retry, destruction and actual Settings rendering. Changing an async signature alone does not prove responsiveness. |
| Settings permission mutation, R02/R03 | [The native permission invokable][permission-source] requires `app_id, permission, granted, remember`. [AppInfoPage][app-info-source] and [PermissionAppsPage][permission-apps-source] pass three arguments; the test fixture also accepts three and hides the mismatch. The shell persists the decision only when `remember` is true. | Pass explicit persisted intent from the two Settings consumers; make the fixture match the native arity and assert grant/revoke/failure behavior. Preserve Android's separate setter contract. Inspect generated CXX-Qt declarations and run both affected native page suites. |

Relevant registered test seams are the native launch tests in
[`tasks/launch.rs`](../../crates/marathon-shell-native/src/tasks/launch.rs),
the real Settings
[`tst_apppages.qml`](../../apps/settings/tests/tst_apppages.qml) and
[`tst_permissionpages.qml`](../../apps/settings/tests/tst_permissionpages.qml),
and [`tests/native-ui/CMakeLists.txt`](../../tests/native-ui/CMakeLists.txt).
At the audited baseline, the required gate selects AppPages but not
PermissionPages; the latter needs explicit candidate coverage for a
permission-page repair. A fixture with the wrong native arity cannot
establish that the real call succeeds.

The [API-design skill][api-skill] and
[native engineering workflow](ENGINEERING_WORKFLOW.md) apply directly:
review real exported signatures, represent failed/partial/unavailable
outcomes, keep I/O off the Qt owner, and make request and subscription
lifetimes explicit. Existing Qt/Rust interfaces should improve at those
boundaries; a wholesale rewrite or an added React Native dependency is
not required to repair them.

## R01–R08: next work and external evidence

All eight tickets remain open with their full acceptance in
[the remediation queue](REMEDIATION_QUEUE.md). This table distinguishes
code that can advance with native fixtures from evidence that requires
a provider, image or device.

| Ticket | Implementable native work | Closing evidence still outside the current green runs |
|---|---|---|
| R01: atomic replacement | Continue generation retention/recovery review, disk-byte limits and coordinated cleanup; retain existing process-death/fault tests. | Real runner use through update, legacy migration, full-disk and power-interruption/reboot qualification on the selected image/filesystem. |
| R02: truthful removal and owned secrets | Async cleanup state; shared settings ownership; trusted two-app secret ownership/migration and grant revocation. | Production Secret Service/dconf, active-writer quiescence, restart/retry and backup/downgrade behavior. A label supplied by an app is not ownership. |
| R03: IPC and warm pool | Failed-adoption cleanup first; app-specific bus mediation, generation-bound identity and narrowed mounts/network permissions. | Real two-app denial matrix through cold/warm launch, activation, owner replacement, revocation and reconnect. |
| R04: accessible confinement | Select supported AT interfaces; implement a trusted, scoped accessibility broker and real app journey. | Actual assistive-technology interaction, keyboard/focus recovery and negative cross-app text/privacy tests. Labels or an unrestricted bus are insufficient. |
| R05: device/recovery matrix | Prepare reproducible image manifest, journeys, failure ledger and artifact schema. | Selected SKU/carrier communications, wake/power/media/GNSS, encryption, OTA/recovery and input results. No hardware results were produced by this audit. |
| R06: installed background work | One authoritative registration lifecycle tied to committed packages, bounded execution/cancellation and a real inspected Mail action. | Actual systemd execution, controlled supported accounts, offline/credential recovery and device wake/power behavior. |
| R07: live display contract | Versioned initial snapshot plus ordered subscribed updates, logical/physical scale distinction and owned cleanup for running/cold/warm paths. | Native process propagation and real mixed-DPI/hotplug/focus journey. Desktop resize is not foldable support. |
| R08: truthful native validation | Integrate #2/#3 into required real-native coverage; align fixtures with generated APIs; continue warning cleanup and broader app suites. | Exact combined-head CI, production backends, compositor interaction and device UX. Missing optional suites must remain visible. |

## All 37 approved packages: next gate

No package is marked complete. This index supplements, and does not reduce,
the acceptance and dependency graph in [BACKLOG.md](BACKLOG.md) and the
[programme tracker](REMEDIATION_QUEUE.md#37-package-programme-tracker).

| Package | Current useful slice or next implementable step | Required later evidence / dependency |
|---|---|---|
| V2-001 | Integrated upstream baseline and required native gate in #9. | Reproducible combined image, selected device matrix; R05/R08. |
| V2-002 | #7 shell metrics; define the full viewport/safe-region contract. | R07 app propagation, input and observed device capabilities. |
| V2-003 | Reconcile #11 research with actual semantic tokens/icons/states. | Native theme parity, contrast, large text and reduced modes. |
| V2-004 | Define Flow/Peek gesture ownership and interruption state. | Cancel/reverse/call/lock/rotation preserves focus and drafts. |
| V2-005 | Integrate #2/#3 and expand actual native suites. | Adaptive Home/Covers/Hub/Quick Controls interaction and accessibility. |
| V2-006 | R04 AT mediation plus keyboard/focus/control roles. | Real assistive-technology journeys; no essential gesture-only task. |
| V2-007 | Stable conversation/account/source identities and provider capabilities. | Contract tests and explicitly supported providers. |
| V2-008 | Native communication adapters using V2-007 identities. | Controlled accounts plus current cellular matrix; R05. |
| V2-009 | Durable drafts, queues and outcome reconciliation. | Restart/reconnect cannot replay ambiguous sends; R06 lifecycle. |
| V2-010 | Privacy-aware activity/cover schema and bounded ownership. | Consistent lock/cover state, redaction and background budgets. |
| V2-011 | Typed invocation/results and narrow grants with owned cancellation. | Caller/target death, revocation, timeout and actual dispatch. |
| V2-012 | Keyboard/search/IME/trackpad ownership and focus return. | Multilingual composition, shortcut collisions and real inputs. |
| V2-013 | #8 Notes slice; integrate communication app journeys. | Real providers, offline behavior, storage and complete native UI. |
| V2-014 | Review #1 RFC against current APIs; implement native RN host separately. | Actual Fabric/window/input/lifecycle proof; no RFC-only completion. |
| V2-015 | Separate native NYC-Tron adapter and token contract. | Real native controls, focus, input and accessibility parity. |
| V2-016 | Generic native package compatibility fixtures. | Concrete package build/install behavior; licensed Forge app validation stays separate. |
| V2-017 | Signed non-premium sample/template on #9 lifecycle foundation. | Clean install/update/permission change/restart/uninstall on target. |
| V2-018 | Split-screen/task-pair state and constraints after display contract. | Resize/restore keeps work and focus; R07. |
| V2-019 | External-display lifecycle and reachable-window recovery. | Mixed-DPI movement and physical hotplug; R07. |
| V2-020 | Narrow drag/drop grants and pointer/pen capability model. | Keyboard equivalent and actual supported device transfers/input. |
| V2-021 | Core-app/settings/onboarding slices with explicit error states. | App/device/accessibility matrix, alarm and quiet-mode behavior. |
| V2-022 | Selected-context Pilot actions with visible targets/results. | Explicit outbound confirmation, permission checks and hostile-input tests. |
| V2-023 | #9 launch policy plus the three bounded API repairs above. | Complete R02/R03/R04 identity, IPC, secret, pool and AT boundaries. |
| V2-024 | Truthful encryption status and recovery/boot assessment. | Enrollment failure, actual encrypted categories and recoverability. |
| V2-025 | Build device journey harness around actual native services. | Telephony/media/power/sensors and wake results per SKU; R05/R06. |
| V2-026 | #9 atomic app transactions; OS update/recovery qualification. | Signature/full-disk/interruption/failed-boot and migration evidence. |
| V2-027 | #9 install/uninstall and explicit Reef trust/compatibility state. | Complete lifecycle, grants and real resize/push/Deckard behavior. |
| V2-028 | Reproducible latency/frame/memory/energy measurement harness. | Distributions and missed deadlines under defined load on target. |
| V2-029 | Release ledger with source/image/device evidence and known limits. | Every OS-scoped acceptance item; no commercial-app prerequisite. |
| V2-030 | Pair/revoke trust and one narrow, resumable file-transfer slice. | Interrupted transfers, deduplication and conflicts before remote actions. |
| V2-031 | Native authenticator/provider selection plus app/origin identity. | Real passkey/user-verification/cancel/recovery proof; R02/R03. |
| V2-032 | Inventory owned data and implement reversible export/import. | Clean-device restore, reauthentication/exclusions, dedupe/undo. |
| V2-033 | #8 durable task identity/actions; add capture and scoped provenance. | Production storage, downgrade/restore, attachments, Calendar and sync. |
| V2-034 | Select maintained native protocol/SDK and declare encryption scope. | Verified peer/device identity, reconnect and actual voice/video/privacy. |
| V2-035 | Reversible personal Travel/Bedside/Focus preferences. | Alarm exceptions, overlap/manual override, timezone/charging recovery. |
| V2-036 | One deterministic existing-action command flow with visible target. | Real dispatch, IME/focus collisions and protected-field exclusion. |
| V2-037 | Stable meeting/task/note links after V2-033. | Timezones/offline state, conference-handler failure and confirmed outbound actions. |

The 2.1 Work/Personal appendix is unchanged. QNX lifetime, IPC, recovery and
timing material remains an architectural reference through
[QNX_REFERENCE_CROSSWALK.md](QNX_REFERENCE_CROSSWALK.md), not a claim that
Linux/Wayland has QNX execution or real-time guarantees.

## Audit method and limits

This pass used the native GitHub API for repository metadata, all open
PRs, detailed PR state, review submissions/threads, comments, changed-file
lists, complete Git trees, compare metadata, exact-head workflow runs,
jobs and decoded logs. No PR was merged, closed, retargeted or marked
ready, and no review comment or issue was posted.

Source findings were checked against the pinned tree. Documentation
verification checks local links, package/ticket coverage and the diff.
The hosted runs above predate this documentation change and do not test
subsequent code edits. Independent native code review and new candidate
test evidence must accompany the next implementation.

[repo]: https://github.com/mikevocalz/Marathon-Shell
[baseline]: https://github.com/mikevocalz/Marathon-Shell/commit/8e9e0892f646d3e11fd581367d148d7f063d7dc7
[pr1]: https://github.com/mikevocalz/Marathon-Shell/pull/1
[pr2]: https://github.com/mikevocalz/Marathon-Shell/pull/2
[pr3]: https://github.com/mikevocalz/Marathon-Shell/pull/3
[pr4]: https://github.com/mikevocalz/Marathon-Shell/pull/4
[pr5]: https://github.com/mikevocalz/Marathon-Shell/pull/5
[pr6]: https://github.com/mikevocalz/Marathon-Shell/pull/6
[pr7]: https://github.com/mikevocalz/Marathon-Shell/pull/7
[pr8]: https://github.com/mikevocalz/Marathon-Shell/pull/8
[pr9]: https://github.com/mikevocalz/Marathon-Shell/pull/9
[pr10]: https://github.com/mikevocalz/Marathon-Shell/pull/10
[pr11]: https://github.com/mikevocalz/Marathon-Shell/pull/11
[pool-source]: https://github.com/mikevocalz/Marathon-Shell/blob/8e9e0892f646d3e11fd581367d148d7f063d7dc7/crates/marathon-shell-native/src/tasks/pool.rs#L237-L311
[launch-source]: https://github.com/mikevocalz/Marathon-Shell/blob/8e9e0892f646d3e11fd581367d148d7f063d7dc7/crates/marathon-shell-native/src/tasks/launch.rs#L335-L344
[store-source]: https://github.com/mikevocalz/Marathon-Shell/blob/8e9e0892f646d3e11fd581367d148d7f063d7dc7/crates/marathon-app-native/src/store.rs#L117-L170
[permission-source]: https://github.com/mikevocalz/Marathon-Shell/blob/8e9e0892f646d3e11fd581367d148d7f063d7dc7/crates/marathon-app-native/src/permissions.rs#L38-L45
[app-info-source]: https://github.com/mikevocalz/Marathon-Shell/blob/8e9e0892f646d3e11fd581367d148d7f063d7dc7/apps/settings/pages/AppInfoPage.qml#L190
[permission-apps-source]: https://github.com/mikevocalz/Marathon-Shell/blob/8e9e0892f646d3e11fd581367d148d7f063d7dc7/apps/settings/pages/PermissionAppsPage.qml#L47
[api-skill]: https://github.com/margelo/react-native-skills/blob/1e9e17be6f41c838db472d6a4b943fc26355a3be/skills/api-design/SKILL.md
