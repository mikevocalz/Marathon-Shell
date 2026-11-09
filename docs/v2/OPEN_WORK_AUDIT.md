# Open work and native API audit

Original fork snapshot: **November 9, 2026, 14:55 UTC**; upstream tracker refresh:
**15:15 UTC**. Source baseline:
[PR #9 at `8e9e0892f646d3e11fd581367d148d7f063d7dc7`][baseline].
This inventory covers every open pull request in
[`mikevocalz/Marathon-Shell`][repo], the eight local remediation tickets,
and all 37 approved 2.0 work packages. It is an evidence record, not a release
approval. The dated integration follow-up below records subsequent work;
the original exact-head table remains historical evidence.

## Integration follow-up — November 9, 2026

All eleven PRs now have an integration disposition in the
[overlap table](#integration-and-overlap). The candidate retains the #4–#8
foundation and adds the reviewed #1 RFC, repaired #2 overview, #3 Hub triage,
#10 passive inspection utility and #11 visual research. The overview feature
and tests are integrated, and its [dated UX research](UX_RESEARCH_2026-11-07.md)
is preserved with a historical/current-scope note. Its external references
were not reverified during intake. #1 and #11 remain documentation
contributions; #10 remains inspection-only.

The latest hosted head checked at **15:51 UTC** was
[`1241537cdb17e3beb7523eb94c81ad829d062fe6`][rust-head], containing the Rust/API
repairs but preceding those later feature/document integrations.
[Format](https://github.com/mikevocalz/Marathon-Shell/actions/runs/42646605377)
and commit-subject checks passed. Its
[native UI job](https://github.com/mikevocalz/Marathon-Shell/actions/runs/42646605430/job/129261419895)
passed **7/7 required CTests**. The
[full build/test job](https://github.com/mikevocalz/Marathon-Shell/actions/runs/42646605430/job/129261420304)
was still running at that check, so its private-bus `Core_AppInstaller`
execution was not yet established. This hosted result does not validate the
later combined candidate.

The combined local candidate subsequently passed **10/10 required native UI
CTests in 64.15 seconds**, using Qt 6.11.3 and pinned real Keel. The added
suites cover Hub (31 behavior functions / 33 total results), OverviewGrid
(10 behavior/data rows / 12 total) and TaskSwitcher (10 behavior functions /
12 total). Settings AppPages passed 26 behavior functions / 28 total results, and
PermissionPages passed 5 behavior functions / 7 total results. All had zero
failures and skips. Setup/cleanup results and overlapping runs are not
additional independent behavior checks. The overview helper is registered
both as a shell QML resource and as an imported JavaScript file excluded
from `qmldir` entries. The required gate now registers both overview suites
and Hub alongside its existing coverage.

The delivered runtime slices are concrete source changes:

| Delivered slice | Source and verification boundary | Remaining acceptance |
|---|---|---|
| Warm-runner admission and rollback | [Pool](../../crates/marathon-shell-native/src/tasks/pool.rs) bounds nonblocking pipe admission, preserves the calling thread's SIGPIPE state, retires failed spares and cleans only their exact PID/instance authority and listener. Native pipe/signal and launch regressions passed. | App-specific session-bus mediation, narrower mounts/networking and generation-bound authority remain R03. |
| Pending replacement survives an old process exit | [Launch handling](../../crates/marathon-shell-native/src/tasks/launch.rs) preserves a same-app pending replacement after old PID/listener cleanup. [Real Tasks tests](../../tests/core/test_taskslaunch.cpp) pass three behavior rows, including successful replacement, failed start and an unrelated pending app. | The delayed launcher-exit branch is source-reviewed; actual child/Wayland transport and broader launch readiness remain separate gates. |
| Three cached asynchronous AppInstaller queries and one bulk capability call | [Client/query state](../../crates/marathon-app-native/src/store.rs) and [AppStore1](../../crates/marathon-shell-native/src/tasks/dbus.rs) replace all three synchronous store reads, retain data on errors, coalesce refreshes, discard stale results and use a 15-second client deadline. Capability reads use one authorized request bounded to 1,024 IDs. Real Settings journeys passed; the generated-client [bus test](../../tests/core/test_appinstaller.cpp) compiled/linked and is required in full CI. | Hosted private-bus execution was pending at 15:51; actual service policy, reconnect, mutation correlation and shared secret/settings cleanup remain R02/R03/R08. |
| Explicit asynchronous admission failure | [Runtime I/O](../../crates/marathon-rt/src/io.rs) reports executor-thread creation failure; store queries surface it and uninstall releases its pending admission. | Other platform calls and subscription/reconnect lifetimes still need their own migration and acceptance. |
| Persistent Settings permission intent | [AppInfoPage](../../apps/settings/pages/AppInfoPage.qml) and [PermissionAppsPage](../../apps/settings/pages/PermissionAppsPage.qml) pass the real four-argument API with `remember=true`. Generated declarations, stricter fixtures, both native page suites and the existing backend persistence case were checked. | Complete permission revocation, app-generation identity and live bus/restart journeys remain R02/R03. |
| Background claims released on unregister | [Lifecycle](../../crates/marathon-shell-native/src/tasks/lifecycle.rs) revokes the app's claims at actual unregister, preserves owner/category counting and never reuses a session handle; exhaustion returns `LimitsExceeded`. Five native resource-core cases passed. | A pre-authorized request already queued after exit, generation identity, active-claim/deadline bounds and installed scheduling remain R03/R06. |

These are delivered bounded slices. **R01–R08 and all 37 work packages remain
open until their complete acceptance is met.** The local UI gate uses explicit
shell/platform service fixtures; native begin/end model-reset dispatch, live
Wayland cover content, real providers, production storage and physical devices
retain separate evidence requirements. See [native validation](NATIVE_VALIDATION.md),
the [Rust/API inventory](RUST_API_AUDIT.md) and
[AppInstaller contract](APP_INSTALLER_API.md) for the detailed records.
No PR was merged and neither `main` nor `v2` was changed by this integration.

## Repository state at the original 14:55 UTC snapshot

At the original snapshot, the native GitHub API reported **11 open PRs**. PRs **#1–#9 are drafts**;
**#10 and #11 are non-drafts**. All remain open and unmerged. The repository
reports `has_issues: false`; listing open issues returns the same 11 PR
entries and **zero standalone issues**. No issue-creation attempt was made
during this audit. The earlier HTTP 410 observation remains historical
evidence in [the remediation queue](REMEDIATION_QUEUE.md).

The checked base branch heads were `main` at
`c2c1b2fe32aeaa51edf75a45045cbfbbc08c4ac5` and `v2` at
`bc39c23cac18221df21e410a45f8cc72d0ae9824`. At 14:55, GitHub reported every PR
mergeable with a clean merge state against its own base. Both base branches
report `protected: false`. These observations do not prove that the open
PRs can be merged together safely or that their feature acceptance is met.

All **Work/Personal Spaces remain in 2.1**. Personal multiple accounts and
Travel/Bedside/Focus remain in the 2.0 programme. The implementation target
is the current Qt/Keel/Linux shell; the native-client RFC, a Passport
inspection utility, and visual research do not establish another working
runtime or a supported phone.

## Every open PR and its exact hosted evidence

This table preserves the **original 14:55 UTC snapshot**. The head link in
each row names the full inspected commit. The CI API
returned that exact `head_sha`; the build logs, job results and format
workflow were inspected independently of the PR body. All listed CI and
format runs completed successfully at those inspected heads. CTest totals are registered suites,
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

### What the original green checks establish

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

### Review and description reconciliation at 14:55 UTC

There are no inline review threads, no outstanding requested reviewers,
and no `CHANGES_REQUESTED` review submissions on any of the 11 PRs.
This is absence of recorded requests, not evidence of human approval.

- #2 retains a [formatting bot comment](https://github.com/mikevocalz/Marathon-Shell/pull/2#issuecomment-6738781093)
  from an older run. Its inspected format run above passed.
- #10 has only a [Devin monitoring comment](https://github.com/mikevocalz/Marathon-Shell/pull/10#issuecomment-6738494411).
  Its body still calls the final build pending; the exact-head run above
  completed successfully and includes `Passport_Inspection`.
- #11 has a no-findings Devin comment review and a
  [Codex no-findings summary](https://github.com/mikevocalz/Marathon-Shell/pull/11#issuecomment-6739156426)
  for earlier commit `4ba95c0210df1e7a635e7c4369cf2e7f3c7b66ee`.
  They do not review the inspected head or establish security approval.

## Integration and overlap

The complete Git trees at all 11 heads were compared with #9; none of the
API tree responses was truncated. The inspected tips of #4–#8 diverged from
#9 because later validation fixes were carried on their own branches.
A different commit ID therefore does not prove missing behavior, and
reapplying every branch would duplicate shared fixes.

| PR | Relationship to #9 at the original audited head | November 9 integration disposition and remaining acceptance |
|---|---|---|
| #1 | The RFC was absent; its PR base remains `main`. | [RFC 0013](../rfcs/0013-react-native-client-contract.md) is integrated with a current manifest/runner/security applicability review. It remains documentation; V2-014–017 runtime and client qualification are open. |
| #2 | OverviewGrid, the two overview suites and UX research were absent. | [Adaptive overview](../../shell/qml/components/MarathonTaskSwitcher.qml), [geometry](../../shell/qml/core/OverviewGrid.js), both [native](../../tests/ui/tst_taskswitcher.qml) [suites](../../tests/ui/tst_overviewgrid.qml) and [dated research](UX_RESEARCH_2026-11-07.md) are integrated. Stable task-ID anchoring repairs earlier-card removal, same-count reorder, model replacement and off-screen reveal; original failures and corrected passes were observed. Full native model-reset dispatch, Wayland content, input/accessibility and device acceptance remain open. |
| #3 | Hub and test blobs differed from #9. | [Hub](../../shell/qml/components/MarathonHub.qml) unread/source-filter composition and [its suite](../../tests/ui/tst_hub.qml) are integrated, preserving current roles, peek and backdrop behavior. Hub joins the required native gate. Account/provider triage remains separate. |
| #4 | The upstream intake was already present with later integration changes; no still-existing #4 changed file was absent. | Retained in the candidate without reverting newer lifecycle, launcher, CI or Settings source. Image, migration and device qualification remain open. |
| #5 | Parser/schema/generator/fixture contracts were present; installer/lock/docs had newer integration changes. | Retained declaration contract and unsupported third-party refusal. Installed scheduling, revocation/removal, real Mail actions and power qualification remain R06. |
| #6 | All eight planning documents existed; README/queue already had newer integrated content. | Retained approved scope and acceptance; this follow-up refreshes delivered-slice evidence while keeping every whole package open. |
| #7 | ScreenMetrics source/header, Constants and registered tests matched; shell wiring had later changes. | Retained live shell metrics. Cold/warm/running-app propagation and real display/DPR hotplug remain R07. |
| #8 | All twelve changed Notes implementation/test/action-manifest paths were byte-identical in #9. | Retained durable Notes task slice and native gate. Production storage, downgrade/restore, reminders, capture/grants, Calendar and sync remain unfinished. |
| #9 | Selected reliability baseline for this audit. | The bounded runtime repairs above are delivered; local combined native UI coverage is 10/10. Final combined-head hosted validation, the full R01–R08 contracts and image/device acceptance remain open. |
| #10 | Three inspection-tool files and their registration were absent. | [Passport utility](../../tools/passport/README.md) and CTest registration are integrated, with sanitized malformed parser/tree errors. Twenty-five Python checks and one CTest passed locally. Passive IORegistry/offline ELF inspection establishes no bootloader, Linux port or recovery capability. |
| #11 | Two research documents were absent; README/UI_SPEC differed. | [Visual research](VISUAL_REFRESH_RESEARCH_2026-11-09.md) and [design influences](DESIGN_INFLUENCES.md) are integrated with current-scope links. They are documentation; implemented theme, accessibility and motion acceptance remains V2-003/005/006/028. |

Historical native failures and upstream fixes must keep their original
attribution. In particular, the terminal translation labels, known-skip
manifest, audio fixture cache initialization and Clippy assertion repairs
already had passing evidence at the original snapshot. They are not new failures to fix
again. Do not close or merge overlapping PRs solely from this inventory;
review the resulting combined source and its evidence first.

## Upstream tracker refresh

The five adjacent repositories from the [v1 audit](V1_GAP_AUDIT.md) were
queried again through their native GitHub open-issues endpoints at 15:15
UTC. The rows below supersede that earlier document's issue-state snapshot,
while preserving its source findings and acceptance requirements.

| Repository | Current open items | Disposition for the 2.0 programme |
|---|---|---|
| [patrickjquinn/Marathon-Shell](https://github.com/patrickjquinn/Marathon-Shell) | Issue [#45: Nightshade/Bedside](https://github.com/patrickjquinn/Marathon-Shell/issues/45); PR [#53: Q25 front/rear cameras](https://github.com/patrickjquinn/Marathon-Shell/pull/53) and [#54: Jolla Camera lifecycle](https://github.com/patrickjquinn/Marathon-Shell/pull/54) | Nightshade maps to personal V2-035. Reconcile camera code with the imported upstream source; qualify actual capture/audio/permissions/lifecycle on the selected hardware under R05/V2-025. An open PR is not evidence that its code is wholly absent from the newer intake. |
| [MarathonOS/Marathon-Image](https://github.com/MarathonOS/Marathon-Image) | Issue [#3: mesa-vdpau-gallium dependency](https://github.com/MarathonOS/Marathon-Image/issues/3); PRs [#2: Poco F1 configuration](https://github.com/MarathonOS/Marathon-Image/pull/2), [#4: README](https://github.com/MarathonOS/Marathon-Image/pull/4), [#5: APKBUILD](https://github.com/MarathonOS/Marathon-Image/pull/5), [#6: APKBUILD](https://github.com/MarathonOS/Marathon-Image/pull/6), [#7: README](https://github.com/MarathonOS/Marathon-Image/pull/7) | Repository metadata still reports archived. Preserve these as historical packaging/device evidence; validate applicability against the active image pipeline. They do not establish a current Poco F1 port or a current dependency failure. |
| [MarathonOS/marathon-zinwa-q25](https://github.com/MarathonOS/marathon-zinwa-q25) | Zero open issue/PR entries | Keep current Q25 source/image/device evidence separate from this empty board. |
| [patrickjquinn/Marathon-Deckard](https://github.com/patrickjquinn/Marathon-Deckard) | Zero open issue/PR entries | V2-027 compatibility and lifecycle acceptance still apply. |
| [patrickjquinn/shipwright-open](https://github.com/patrickjquinn/shipwright-open) | Zero open issue/PR entries | Pin and validate the actual toolkit/image dependencies; an empty tracker is not a test result. |

Two previously open upstream Shell issues are now closed with GitHub
state reason `completed`:

- [#50: QEMU Maps WebEngine crash](https://github.com/patrickjquinn/Marathon-Shell/issues/50),
  closed **2026-11-09 10:45:41 UTC**.
- [#44: security hardening](https://github.com/patrickjquinn/Marathon-Shell/issues/44),
  closed **2026-11-09 10:45:53 UTC**.

Those tracker transitions are not new graphics/security validation. Keep
the applicable Maps/rendering and R02–R04 boundary tests, exact source/image
revisions and remaining hardware qualifications. This audit did not close
either issue or submit any upstream change.

## Concrete native API repairs identified in the baseline

These are source findings at `8e9e0892`, independent of hosted success.
The delivered follow-up above supersedes their original repair status; the
pinned defect descriptions and repair contracts below preserve provenance.

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
At the audited baseline, the required gate selected AppPages but not
PermissionPages. The delivered permission repair added PermissionPages to
the required gate; the combined follow-up now selects ten CTests. A fixture with the wrong native arity cannot
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
| R02: truthful removal and owned secrets | Async cleanup state is delivered. Continue shared settings ownership, trusted two-app secret ownership/migration and grant revocation. | Production Secret Service/dconf, active-writer quiescence, restart/retry and backup/downgrade behavior. A label supplied by an app is not ownership. |
| R03: IPC and warm pool | Failed-adoption cleanup, pending-replacement protection and permission intent are delivered. Continue app-specific bus mediation, generation-bound identity and narrowed mounts/network permissions. | Real two-app denial matrix through cold/warm launch, activation, owner replacement, revocation and reconnect. |
| R04: accessible confinement | Select supported AT interfaces; implement a trusted, scoped accessibility broker and real app journey. | Actual assistive-technology interaction, keyboard/focus recovery and negative cross-app text/privacy tests. Labels or an unrestricted bus are insufficient. |
| R05: device/recovery matrix | Prepare reproducible image manifest, journeys, failure ledger and artifact schema. | Selected SKU/carrier communications, wake/power/media/GNSS, encryption, OTA/recovery and input results. No hardware results were produced by this audit. |
| R06: installed background work | Unregister now revokes app claims. Continue authoritative installed scheduling tied to committed packages, bounded execution/cancellation and a real inspected Mail action. | Actual systemd execution, controlled supported accounts, offline/credential recovery and device wake/power behavior. |
| R07: live display contract | Versioned initial snapshot plus ordered subscribed updates, logical/physical scale distinction and owned cleanup for running/cold/warm paths. | Native process propagation and real mixed-DPI/hotplug/focus journey. Desktop resize is not foldable support. |
| R08: truthful native validation | Ten required native CTests and corrected generated-API fixtures are delivered. Obtain final combined-head CI, continue full-source warning cleanup and expand app/provider coverage. | Exact combined-head CI, production backends, compositor interaction and device UX. Missing optional suites must remain visible. |

## All 37 approved packages: next gate

No package is marked complete. This index supplements, and does not reduce,
the acceptance and dependency graph in [BACKLOG.md](BACKLOG.md) and the
[programme tracker](REMEDIATION_QUEUE.md#37-package-programme-tracker).

| Package | Current useful slice or next implementable step | Required later evidence / dependency |
|---|---|---|
| V2-001 | Integrated upstream baseline and required native gate in #9. | Reproducible combined image, selected device matrix; R05/R08. |
| V2-002 | #7 shell metrics; define the full viewport/safe-region contract. | R07 app propagation, input and observed device capabilities. |
| V2-003 | #11 research is integrated; implement semantic token/icon/state parity. | Native theme parity, contrast, large text and reduced modes. |
| V2-004 | Define Flow/Peek gesture ownership and interruption state. | Cancel/reverse/call/lock/rotation preserves focus and drafts. |
| V2-005 | #2 adaptive overview and #3 unread Hub slices are delivered with required native suites. | Adaptive Home/Covers/Hub/Quick Controls interaction and accessibility. |
| V2-006 | R04 AT mediation plus keyboard/focus/control roles. | Real assistive-technology journeys; no essential gesture-only task. |
| V2-007 | Stable conversation/account/source identities and provider capabilities. | Contract tests and explicitly supported providers. |
| V2-008 | Native communication adapters using V2-007 identities. | Controlled accounts plus current cellular matrix; R05. |
| V2-009 | Durable drafts, queues and outcome reconciliation. | Restart/reconnect cannot replay ambiguous sends; R06 lifecycle. |
| V2-010 | Privacy-aware activity/cover schema and bounded ownership. | Consistent lock/cover state, redaction and background budgets. |
| V2-011 | Typed invocation/results and narrow grants with owned cancellation. | Caller/target death, revocation, timeout and actual dispatch. |
| V2-012 | Keyboard/search/IME/trackpad ownership and focus return. | Multilingual composition, shortcut collisions and real inputs. |
| V2-013 | #8 Notes slice; integrate communication app journeys. | Real providers, offline behavior, storage and complete native UI. |
| V2-014 | #1 RFC and current-API applicability review are delivered; implement the native RN host separately. | Actual Fabric/window/input/lifecycle proof; no RFC-only completion. |
| V2-015 | Separate native NYC-Tron adapter and token contract. | Real native controls, focus, input and accessibility parity. |
| V2-016 | Generic native package compatibility fixtures. | Concrete package build/install behavior; licensed Forge app validation stays separate. |
| V2-017 | Signed non-premium sample/template on #9 lifecycle foundation. | Clean install/update/permission change/restart/uninstall on target. |
| V2-018 | Split-screen/task-pair state and constraints after display contract. | Resize/restore keeps work and focus; R07. |
| V2-019 | External-display lifecycle and reachable-window recovery. | Mixed-DPI movement and physical hotplug; R07. |
| V2-020 | Narrow drag/drop grants and pointer/pen capability model. | Keyboard equivalent and actual supported device transfers/input. |
| V2-021 | Settings asynchronous store states and persistent permission intent are delivered; extend other core-app/onboarding journeys. | App/device/accessibility matrix, alarm and quiet-mode behavior. |
| V2-022 | Selected-context Pilot actions with visible targets/results. | Explicit outbound confirmation, permission checks and hostile-input tests. |
| V2-023 | #9 launch policy plus the delivered pool, replacement, query, permission and claim repairs above. | Complete R02/R03/R04 identity, IPC, secret, pool and AT boundaries. |
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

The original source audit used the native GitHub API for repository metadata, all open
PRs, detailed PR state, review submissions/threads, comments, changed-file
lists, complete Git trees, compare metadata, exact-head workflow runs,
jobs and decoded logs. No PR was merged, closed, retargeted or marked
ready, and no review comment or issue was posted.

Source findings were checked against the pinned tree. Documentation
verification checks local links, package/ticket coverage and the diff.
The integration follow-up adds independent native review and local candidate
results. Each hosted checkpoint applies only to its named head; later source
and documentation changes require a new exact-head result. The final combined
head must retain the explicit service-fixture, provider and device limits.

[repo]: https://github.com/mikevocalz/Marathon-Shell
[rust-head]: https://github.com/mikevocalz/Marathon-Shell/commit/1241537cdb17e3beb7523eb94c81ad829d062fe6
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
