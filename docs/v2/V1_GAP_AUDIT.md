# Marathon v1 gap audit and v2 intake

Snapshot: **November 9, 2026**. This is a source, tracker and community-evidence audit, not a new device test or a claim to have found every latent defect. It inventories every open issue and pull request returned by the repositories below, reconciles the highest-impact findings against current upstream source, and maps follow-up work to the approved [v2 backlog](BACKLOG.md).

The follow-up [remediation queue](REMEDIATION_QUEUE.md) converts these findings into eight ready-to-file tickets and a 37-package tracker, including draft PRs #4–#8. GitHub issue creation returned HTTP 410 because this fork's Issues feature is disabled, so no remediation issue was created. The queue also records the later QML-validator/real-UI CI gap; the earlier tracker counts in this audit remain a dated pre-task snapshot.

## 1. First finding: update the baseline before duplicating fixes

The fork's inherited source is materially behind upstream. The fork's original `main` is `c2c1b2fe32aeaa51edf75a45045cbfbbc08c4ac5`; the inspected v2 planning baseline is `bc39c23cac18221df21e410a45f8cc72d0ae9824`. Current upstream `main` is **`567f1faa8bfdf31611dd401134c293daa160221c`**, with **548 commits ahead and zero behind** the original fork base. This was checked with GitHub compare and locally with `git rev-list --left-right --count`. [Compare the two source revisions][upstream-compare].

Inherited source evidence is pinned separately: [app installer][f-install], [security model][f-security] and [background-work contract][f-background]. The current-upstream links throughout this audit use the newer full SHA. Findings describe those snapshots; later implementation PRs must record their own fix and validation evidence.

Upstream published the Q25 image **26110802** on November 9 at 07:18 UTC, built from `1aa2bc474e3ad735f9df0c382ed8322b2b915115`. It includes a flashable image, checksums and an installation/recovery guide. Its release notes report screen-off current of approximately 67 mA with Wi-Fi and LTE connected, versus approximately 244 mA on 1.0, with CPU idle, GPU/display/USB power, location and Android background changes. These are upstream's measurements, not ours. Calls, SMS and Bluetooth hands-free were **not retested on this build**; outdoor satellite positioning remains untested. [Release and limitations][q25-release].

Consequences for implementation:

1. V2-001 starts with a reviewed upstream intake: source/device/dependency changes, retained fork changes, licensing, images and regression evidence. Do not merge 548 commits into `v2` without that review or recreate fixes already present upstream.
2. Keep three states distinct: inherited fork behavior, current upstream source, and a tested release on a named device. An upstream commit does not demonstrate that the fork includes it or that every device benefits.
3. Use the current source to reconcile open PRs and old reports. An open PR is not proof that its code is absent; the camera is a concrete example below.
4. Preserve the product decision: all Work/Personal Spaces, organization and isolation remain **2.1 only**. Every other approved package stays in the phased 2.0 programme. This audit changes priorities and acceptance evidence, not that scope.

The intake is now concrete and reviewable in **[draft fork PR #4][fork-pr-4]**, targeting `v2`. Its initial published review head `6d38029e2216719c96ab2984ce5c17962f82f035` contains the pinned upstream tree plus the original four planning files. This is a proposed integration branch, not a merge into `v2` or a qualified device build; the approved scope and this audit travel in the companion documentation change. Recheck the PR's current head and validations when reviewing later revisions.

## 2. Evidence and coverage

| Label | Meaning |
|---|---|
| Source defect | A specific failure path is visible in inspected code; runtime reproduction is still stated separately. |
| Documented limitation | The project's current documentation explicitly describes the boundary or missing validation. |
| Open report | An issue or PR describes a failure/request; it has not been independently reproduced in this audit. |
| Community report | Dated Reddit feedback; useful for test selection, not proof of current fork behavior. |
| Upstream improvement | Newer source/release addresses an older concern; intake and regression qualification remain. |
| Product expansion | Approved successor work; not an accusation that v1 promised or broke it. |

The GitHub `issues` endpoint also returns pull requests. The counts below separate them; each response contained fewer than the requested 100 records, so these inventories were not truncated by pagination. Counts are a snapshot before new PRs from this work.

| Repository | Open issues | Open PRs | Scope |
|---|---:|---:|---|
| [patrickjquinn/Marathon-Shell][upstream-open] | 3 | 2 | Active upstream shell, apps, services and image packaging |
| [mikevocalz/Marathon-Shell][fork-open] | 0 | 3 | User's fork; all three PRs are drafts |
| [MarathonOS/Marathon-Image][image-open] | 1 | 5 | Archived image repository; historical evidence, not the current build pipeline |
| [MarathonOS/marathon-zinwa-q25][q25-old-open] | 0 | 0 | Older Droidian-based device repository; no open items returned |
| [patrickjquinn/Marathon-Deckard][deckard-open] | 0 | 0 | Android compatibility dependency; bounded public tracker inventory only |
| [patrickjquinn/shipwright-open][shipwright-open] | 0 | 0 | Current Keel source dependency; bounded public tracker inventory only |

Read the complete upstream issue bodies, all three comments on security issue #44, the camera PR descriptions, the archived issue/PR bodies and all three comments on archived PR #2. Inspecting other repositories, private discussions, every closed issue or every possible hardware configuration is outside this snapshot. Search results were also checked for MarathonOS/BB10 discussion on Reddit; direct Reddit page retrieval was unavailable, so the indexed excerpts below are explicitly limited evidence.

Zero open items is only a tracker result, not proof that either dependency has no defects. New PR #4 was opened after the three-draft fork inventory and is linked separately above; later work from this programme must be counted separately from the pre-task snapshot.

## 3. Every open upstream issue

| Item | Actual report | Current interpretation | Owner, work package and closing evidence |
|---|---|---|---|
| [#50: Maps intermittent QEMU SIGSEGV][issue-50] | September 3 report: one crash in four r362 end-to-end runs inside `libQt6WebEngineCore`; later runs clean. QEMU software rendering also failed to initialize WebGL. | Open report. Current Maps still uses QtWebEngine/MapLibre; its logic and UI distinguish a permanent WebGL failure from a recoverable renderer loss. The QEMU interaction harness excludes map/browser rendering. This is a graphics/runtime qualification gap, not evidence that every hardware map launch crashes. [Source and harness][u-maps]. | Graphics + app QA; V2-001/021/025/028. Preserve the failing image/config; obtain a symbolized crash if reproducible; exercise software/virgl and each shipping GPU; keep search/directions useful when the map is unavailable. Publish skips and crash frequency instead of calling the excluded test passed. |
| [#45: Nightshade bedside mode][issue-45] | January 13 feature request for a charging/idle ambient clock with scheduling, dim colors, battery/weather and content movement. | Feature request, not a defect. No Nightshade/bedside implementation was found in current shell/apps/crates/package sources. Existing ambience and DND are useful foundations. | Shell + power + accessibility; V2-021/035. First implement a reversible personal scene, then charging/schedule behavior, alarms, unplug/lock recovery, brightness capability and measured energy. Do not assume a black background is low power on every panel. No work profile. |
| [#44: Security hardening measures][issue-44] | January security umbrella, with discussion of brute-force delays and recovery. | A proposal list, not an independently demonstrated vulnerability list. Some mechanisms have evolved substantially: the obsolete outer Landlock wrapper was removed, and current upstream now confines the app runner after bwrap with seccomp/Landlock. The unresolved boundaries are listed in section 6. [Current security model][u-security]. | Security + platform; V2-023/024/031. Turn each applicable proposal into a threat, selected-device capability, implementation decision and boundary test. Do not adopt every proposed tool blindly or treat a logged best-effort sandbox as guaranteed enforcement. |

For #44, explicitly disposition its remaining proposals: allocator/kernel memory hardening; sysctl/kernel arguments and module policy; composefs/image integrity; USBGuard; privilege elevation/root management and SUID policy; Yama/ptrace and production crash dumps; MAC randomization; PIN layout and lockout/recovery; Bubblejail/fapolicyd/app execution policy. Current packages cap rather than disable crash dumps. The existing shell permission gate, Wayland identity and native-package trust model must inform these decisions. A lockout UI cannot protect a copied disk from offline PIN guessing. [Security][u-security], [encryption][u-encryption], [base package][u-base].

## 4. Open PRs: reconcile code, then qualify it

### Upstream camera PRs

| PR | What the description contributes | Reconciliation at current upstream |
|---|---|---|
| [#53: Q25 front and rear cameras][pr-53] | Draft stacked on #52: sensor/kernel/libcamera integration and hardware measurements. Its original remaining list includes full-size stills, recording audio, rotation, rear focus and overlay removal. | Camera code and libcamera patches exist in current `main`. Do not describe both cameras as absent simply because this PR is open. Later source must supersede individual items in the old remaining list. |
| [#54: Jolla Camera UI][pr-54] | Draft stacked on #53: capture controls, lifecycle, cover, saved-file handling and restart fixes. Original limitations include video orientation, low background recording rate and preview-size photos. | `a4f366ff` is present in main. Later [4a4c19e4][camera-fullsize] adds full-size capture, and [0ef16882][camera-exposure] fixes front size selection and rear exposure with dated Q25 measurements. Preview-size-only photos must not be presented as the current upstream state. |

V2-025 should import/reconcile the complete camera dependency chain, then record a current matrix for front/rear photo size, focus/exposure, orientation, video audio, sustained frame rate, background recording, thermal behavior, first-frame latency and recovery after lock/call/camera revocation. The old PR descriptions are test leads for remaining cases, not proof that every listed defect persists. Preserve the BSD/Apache attribution boundaries described in the camera PR; neither its UI provenance nor an app preview proves the hardware port qualified.

### Fork drafts before this task

| PR | Base | Evidence boundary and next action |
|---|---|---|
| [#1: native client and managed runner contract][fork-pr-1] | `main` | Documentation RFC. No native runtime implementation. Future v2 integration must explicitly target `v2`; do not infer React Native/Fabric/QNX support from the contract. |
| [#2: adaptive native live-cover overview][fork-pr-2] | `v2` | A narrow QML/prototype slice, not a completed semantic activity service, hinge-aware port or qualified five-form-factor UI. Review actual native layout/lifecycle behavior and retain the full V2-002/005/010 acceptance. |
| [#3: Hub unread triage and source filters][fork-pr-3] | `v2` | Notification triage/filtering. It does not create email/social-provider account synchronization, durable conversation identity or offline sending. Continue V2-007/008/009/013. |

## 5. Every open item in archived Marathon-Image

These old PRs are not a current merge queue. Current packaging lives under `Marathon-Shell/packaging/`; port a still-relevant change narrowly after comparison rather than applying an archived diff wholesale.

| Archived item | Current-source reconciliation | Follow-up |
|---|---|---|
| [Issue #3: `mesa-vdpau-gallium` unavailable][image-3] | The unavailable dependency is absent from the inspected current base/UI APKBUILDs; current base uses `mesa-dri-gallium`, `mesa-va-gallium` and related packages. The old failure is not reproduced by this source check. | V2-001/026: a clean selected-image dependency/build run; retain the historical issue as superseded-by-pipeline evidence, not an open current build failure. |
| [PR #6: remove that Mesa dependency][image-6] | Same outcome as issue #3. | No duplicate patch solely to close the historical record. |
| [PR #7: select PipeWire][image-7] | Current base and UI packages explicitly depend on PipeWire, PipeWire Pulse and WirePlumber. Packaging presence does not prove per-device call routing. | V2-025: actual media/ringtone/alarm/call/Bluetooth routing and interruption tests. |
| [PR #5: repair checksums][image-5] | It concerns old APKBUILD inputs; current files and pipeline have changed. There is no evidence here that its exact checksum failure remains. Current base still contains some `SKIP` checksum entries, which need a deliberate reproducibility review. | V2-001/026: verify current local-input checksums and pin/fetch provenance in clean builds; publish image checksums and signed update metadata. Do not label old hashes as a present failure without reproducing it. |
| [PR #4: repository URL and OnePlus fastboot instructions][image-4] | Current README clones Marathon-Shell. Current `scripts/flash/flash-oneplus6.sh` says hold Vol-Up and plug USB and explicitly admits no Marathon hardware validation. **Documentation inconsistency remains:** `docs/PACKAGE_REFERENCE.md` still says Power + Volume Down. [Current script][u-op6-flash], [stale guide][u-package-reference]. | V2-001/029: one authoritative per-device install/recovery guide, reconcile old links/button instructions and test it on the exact port. No flashing was done here. |
| [PR #2: Poco F1 EBBG/Tianma panels][image-2] | Maintainer comments promised integration in December 2025 and requested a rebase in April 2026, but the PR remains open. Current device manifests/overlays contain no Poco/beryllium target. A comment is not evidence of a supported port. | V2-001/025/029: decide whether to sponsor a separate port; if selected, qualify both panels, boot/recovery, modem and power. Do not promote historical intent to supported hardware. |

## 6. Current source gaps with the highest practical impact

The current-upstream links in this section are pinned to `567f1faa`; the inherited-source links resolve in this fork. Findings that existed in both were checked in both. Priority denotes the order for investigation/repair, not an invented security severity or a hardware certification result.

### P0: protect data and enforce trust before broader app integration

| Finding | Evidence and scope | Concrete next slice and acceptance | Owner / packages |
|---|---|---|---|
| App replacement can destroy the old working installation before the new one succeeds | **Source defect, inherited and current.** `install.rs::place` removes the destination, then copies new files/writes the receipt; failure removes the partial destination. [Installer][u-install]. | Stage the complete verified package and approved receipt on the destination filesystem; switch atomically with an explicit recovery/rollback design. Inject full-disk/copy/receipt/interruption failures and demonstrate the old app remains runnable or a recoverable committed state is recorded. | App platform + storage / 017,026,027 |
| Uninstall can report success while data remains; app secrets have no safe deletion ownership | **Source defect/incomplete contract, inherited and current.** Cache/data/config removal errors are discarded. Manifest docs explicitly say `secrets` lifecycle is not implemented because Secret Service items lack app identity. [Installer][u-install], [manifest contract][u-manifest]. | Report per-category outcomes and preserve a retryable cleanup record. Establish mediated per-app secret ownership before deleting credentials. Test denied/locked files, crashes, keep/remove choices and two apps' secrets; never delete another app's credentials. | App platform + security / 023,027,031,032 |
| App-accessible session bus remains too broad for the advertised permission boundaries | **Documented current limitation.** Private runtime tmpfs now hides unrelated sockets, correcting the inherited broad runtime mount. However, there is no D-Bus proxy; current docs say apps can read other Secret Service items or write unrelated dconf keys. Missing bwrap or the explicit sandbox-disable override permits unconfined launch; seccomp/Landlock failure is best effort and logged. [Security model][u-security]. | Introduce a reviewed, per-app bus allowlist/proxy or equivalent mediated services with an explicit identity contract. Prove allowed calls succeed and forbidden secret/settings/other-app calls fail across restart and revocation. Define a truthful release policy for missing/failed confinement; preserve required portal/audio accessibility. | IPC + security / 011,023,031 |
| Warm spares receive data/cache/network access before their app identity is known | **Documented current limitation.** Pool spares bind the parent app directories and share networking; eligibility excludes user-installed, WebEngine, camera and terminal apps, which reduces scope but does not make the remaining boundary per-app. [Security model][u-security]. | Design confinement before any app code executes; narrow mounts/identity at adoption or redesign the pool. Use two bundled fixtures with different permissions and demonstrate no sibling data access or disallowed network use. Measure launch cost after correctness. | Lifecycle + security / 010,023,028 |
| Sandboxing and accessibility currently conflict | **Documented current limitation.** The accessibility bus is withheld; current docs explicitly state screen readers cannot see sandboxed Marathon apps. Blindly binding it would expose other apps' accessible text. [Security model][u-security]. | Design an accessible, permission-aware bridge and real assistive-technology test. Read, navigate, edit, respond to a dialog and recover focus in an actual sandboxed app; verify a hostile app cannot enumerate another app's private text. QML labels alone cannot close this gap. | Accessibility + security / 006,011,023 |
| Data protection differs by image/layout and is not hardware-backed | **Documented current limitation.** A/B Pi/Hackberry and QEMU encrypt their data; Q25 encrypts `/home` but not its root `/var`; single-root Librem/PinePhone/OnePlus/QEMU do not. No hardware keystore is claimed. [Encryption matrix][u-encryption]. | Record the actual image/layout, where each credential/database/log lives and what its protection state means. Test enrollment failure, PIN changes, boot unlock, reset/recovery and app data outside `/home`; never show a generic “protected” state based only on a lock-screen PIN. | Security + device / 024,031,032 |
| Successful update installation is not the same as a qualified recovery path | **Documented current limitation.** Librem5/PinePhone lack rollback; OnePlus is untested; full QEMU A/B validation is listed as unrun. Hackberry has dated positive rollback evidence. Q25's current path exists, but its boot-counter rename behavior still needs on-device validation. [OTA matrix][u-ota]. | Run signed N→N+1→deliberately bad N+2 journeys on each release target; include full disk, lost power, wrong signature, early boot hang and state migration. Record the actual fallback image/kernel and retained data. Do not extrapolate Hackberry's result to a phone. | Release + device / 024,026,029 |

### P1: make daily phone behavior and app delivery dependable

| Finding | Evidence and scope | Concrete next slice and acceptance | Owner / packages |
|---|---|---|---|
| Cellular readiness lacks a current complete device/carrier report | **Validation gap.** The modem field-test file is a checklist, not a passed result; the newest Q25 release excludes retesting calls/SMS/hands-free. [Field plan][u-modem], [release][q25-release]. | Publish SKU/modem firmware/carrier/build results for incoming/outgoing calls, screen-off wake, mute/speaker/BT routes, SMS/MMS, data transitions and registration recovery. Exercise emergency-call routing only through lawful, arranged test procedures. A single dial succeeds is insufficient. | Telephony + device QA / 008,025,029 |
| Power policy and background work need a coherent tested contract | **Documented limitation/contract gap, inherited and current.** Daily sleep is Doze, not automatic system suspend. The background-task generator/documentation and strict manifest schema disagree; system-app generation does not provide a third-party install/remove scheduling lifecycle. [Background contract][u-background]. | Reconcile the declaration schema, action eligibility, time/resource limits and explicit unsupported behavior first. Then qualify timers, alarms, push, thaw/refreeze and any real suspend/resume policy on a modem device. Measure screen-off energy and wake latency. Preserve the upstream Q25 idle improvements. | Lifecycle + power + SDK / 009,010,025,028 |
| Camera still needs a fresh capability/quality matrix | **Qualification gap after upstream improvements.** Old camera PR limitations are partly superseded; current capture size/exposure code has advanced. No complete cross-device media qualification was run here. [Camera changes][camera-fullsize]. | Test current still/video paths and the remaining cases in section 4; publish unsupported controls/capabilities accurately. Include app/camera crashes, low storage and content integrity. | Media + device QA / 021,025,028 |
| GNSS/maps need real rendering and outdoor evidence | **Open report/validation gap.** QEMU rendering exclusions and issue #50 remain; the new Q25 release has no outdoor satellite-positioning result. [Maps][issue-50], [release][q25-release]. | Measure cold/warm position acquisition and denied/revoked location behavior on the target; verify map render/search/route degradation offline and on unsupported graphics. Do not call mocked position or a directions list a working basemap. | Location + graphics / 021,025,028 |
| App ecosystem claims need reconciliation with actual install flows | **Documentation drift plus qualification work.** Current README says Reef cannot install, but current `apps/reef/src/bridge.rs` and `handler.rs` dispatch install/update/uninstall; current OTA docs describe its signed catalogue. [Reef source][u-reef], [OTA][u-ota]. | Correct capability documentation after an end-to-end signed catalogue/install/update/uninstall journey, permissions change, cancellation and failure recovery. Keep non-premium fixtures. Preserve native first-party operation without Deckard. | Ecosystem + app platform / 017,027,029 |
| Android compatibility is useful but not universal | **Documented known gaps.** `ANDROID_APPS.md` still lists microG's secondary sign-in-window focus and a cold Store `android:` link opening an empty page. It does not establish arbitrary banking/DRM/payment/app compatibility. [Android integration][u-android]. | Reproduce or retire both named cases; qualify a small declared app/version matrix for resize, focus, keyboard, permissions, push, audio and process death. Expose unsupported capabilities truthfully instead of promising all Android apps. | Deckard + app QA / 027,029 |
| Hardware support and install guides drift apart | **Documented limitation.** OnePlus6 remains dormant; bare Pi HDMI is unvalidated; a foldable layout target is not a port. Q25 now has a released installation path, but recovery still depends on BROM/mtkclient because U-Boot lacks usable fastboot. [Devices][u-devices], [Q25 guide][u-q25-guide]. | Generate the public support matrix from device manifests plus dated test results; publish current images and precise recovery boundaries. Repair contradictory legacy guides. Choose a small release set and qualify it before widening marketing claims. | Device + release / 001,025,029 |
| OTA distribution has remaining operational limits | **Documented current limitations.** Full images, no staged rollout, non-atomic GitHub asset replacement and pre-userspace hang/watchdog concerns remain. An unblessed Q25 trial needs a manual restart to spend a try; its carried root state is a fixed list. **The older Pi/Hackberry feed overlap is fixed upstream** by a separate `hackberrypi-cm5` image identity. [OTA][u-ota], [image-identity patch][u-hackberry-pipeline]. | Verify the current per-device feed selection, interrupted publication/signature failure and rollback; define deployment/hold criteria and trial-reboot behavior. Document exactly which root state survives and test migration. Then optimize download size and report metered-data/space costs. | Release engineering / 026,029 |
| Shell metrics and app-runner display state need coordinated live updates | **Source integration gap.** The shell captures launch device geometry/DPI for `Tasks::setDevice`; runners receive `MARATHON_SCREEN_WIDTH`, `MARATHON_SCREEN_HEIGHT` and `MARATHON_DPI` at launch. A shell-window resize fix alone cannot establish that warm-adopted and existing apps track the new display. [Shell startup][u-shell-main], [runner startup][u-runner]. | Specify one update path for viewport, scale and available regions. Resize/move/change scale while cold-launching, adopting a warm spare and retaining a running app; all must agree without losing focus, drafts or task identity. Qualify hot-plug separately. | Compositor + lifecycle / 002,018,019 |

### Product completeness, not newly discovered defects

The prior successor plan already covers Hub/Peek, semantic live covers, invocation cards, keyboard/IME, accessible controls, native sharing, offline drafts and adaptive displays. Existing Notes checkbox tasks, ordinary app action declarations, Bluetooth pairing and mail/DAV Secret Service storage are real foundations. They do not complete the additional task/continuity/passkey products.

Use V2-007–013 for account/conversation Hub, supported providers, durable drafts and return-to-caller workflows. Use V2-030–037 for paired-device continuity, passkeys, migration/export/restore, durable tasks/provenance, encrypted messaging/calls, personal scenes, Instant Actions and meeting context. Each package already records source seams, owner roles, dependencies, a first implementable slice and failure acceptance. Do not add duplicates merely because a broad v1 audit rediscovers them. All remain planned until their actual evidence is recorded.

## 7. Reddit: dated feedback converted into tests

| Thread/date | What the indexed material actually says | Interpretation and action |
|---|---|---|
| [Q25 native Linux update][reddit-q25], November 5–6, 2026 | The developer describes a forthcoming image and responds that camera color/focus need work, incoming calls can be slow/spotty, battery life is roughly ten hours and the CPU does not idle properly when locked. | Dated developer report, not our measurement. **Image availability and idle behavior have newer upstream release evidence**; do not repeat the old battery figure as the current state. Retest cellular behavior because the new release explicitly omits that validation; retain camera-quality checks. |
| [BB10 successor launch][reddit-launch], November 11, 2025 | Comments express demand for an integrated Hub and keyboard devices, alongside suggestions for broader ports. | Product demand, not proof that every social service offers a usable API or every old BlackBerry can boot a new OS. Prioritize actual provider capabilities and a supported-device matrix. V2-007/008/012/025/036. |
| [“Anyone else miss the BlackBerry OS?”][reddit-bb10], February 28, 2026 | A commenter values Peek and BB10 prediction, and describes resource pressure on early devices. | Anecdotal preference. Use a low-memory/CPU target, interrupted-compose tests and multilingual keyboard comparison; do not turn nostalgia into unsupported claims of superior performance. V2-004/012/028/036. |

Search also surfaced unrelated fitness products named MarathonOS and reports about other Linux phone distributions. Those are not evidence of Marathon Shell defects. No prevalence estimate or “everyone says” conclusion is warranted from this small sample. Reproduction reports should capture source/image SHA, hardware, relevant app/provider version, steps, expected/actual outcome and sanitized diagnostics.

## 8. Ordered work and what counts as done

1. **Establish the current base (platform + independent release reviewer):** reconcile the 548 upstream commits, device manifests, dependency pins, open PR content and newest release. Produce an explicit kept/imported/deferred ledger and a reproducible native build. V2-001.
2. **Fix data-loss and trust boundaries (storage/security + separate reviewer):** atomic app replacement; honest uninstall; scoped secret/bus access; app identity before pool execution; accessible sandbox contract. Test injected failure and cross-app denial, not only the happy path. V2-006/011/023/027/031.
3. **Close the reference-phone evidence (device QA + telephony/media reviewer):** current-build calls/SMS/MMS/hands-free, wake, camera, outdoor location, overnight power and signed rollback/recovery. Document known failures honestly. V2-024–029.
4. **Deliver small native workflow slices (app teams + API reviewer):** deterministic Notes capture/Instant Action, durable task identity, source-aware attachments, meeting return, paired file transfer, external-key passkey proof and a selected secure-communications protocol. Keep optional service/provider failures explicit. V2-030–037.
5. **Widen adaptivity and ecosystem after contracts hold:** actual screen-reader journeys, low-memory behavior, tablet/foldable/external-display state survival and declared native/Android app matrices. V2-002–006/014–020/027/028.

Use the [engineering workflow](ENGINEERING_WORKFLOW.md): affected native/API skills, exact source/dependency evidence, delegated implementation and independent review, real registered tests, no invented API and no premium OS fixture. Native build, QEMU and hardware results are separate gates. A report, checklist, source function, screenshot or parser test does not substitute for the boundary it is supposed to prove.

### Verification performed for this audit

- Enumerated and separated all open issues/PRs in the six repositories above; read their bodies and available comments.
- Inspected the inherited fork and current upstream checkout at the recorded SHAs; verified the 548-commit difference locally.
- Reconciled current security, installer, encryption, OTA, camera, Maps, background, device, Reef and Android documentation/source rather than relying on a TODO count.
- Checked indexed Reddit evidence and the newer Q25 release so old reports are not silently promoted to current failures.
- Performed documentation/link/scope checks for this change. No device flash, native build, carrier test, camera measurement, penetration test or full image recovery test was performed as part of this documentation audit.
- An independent platform reviewer checked the installer, cleanup, sandbox, power and background-contract findings against the same source snapshots. Subsequent code changes are tracked in their own PRs; this ledger does not declare their larger work packages complete.

[upstream-compare]: https://github.com/patrickjquinn/Marathon-Shell/compare/c2c1b2fe32aeaa51edf75a45045cbfbbc08c4ac5...567f1faa8bfdf31611dd401134c293daa160221c
[f-install]: https://github.com/mikevocalz/Marathon-Shell/blob/bc39c23cac18221df21e410a45f8cc72d0ae9824/crates/marathon-apps/src/install.rs
[f-security]: https://github.com/mikevocalz/Marathon-Shell/blob/bc39c23cac18221df21e410a45f8cc72d0ae9824/docs/SECURITY_MODEL.md
[f-background]: https://github.com/mikevocalz/Marathon-Shell/blob/bc39c23cac18221df21e410a45f8cc72d0ae9824/docs/BACKGROUND_WORK.md
[q25-release]: https://github.com/patrickjquinn/Marathon-Shell/releases/tag/zinwa-q25-26110802
[upstream-open]: https://api.github.com/repos/patrickjquinn/Marathon-Shell/issues?state=open&per_page=100
[fork-open]: https://api.github.com/repos/mikevocalz/Marathon-Shell/issues?state=open&per_page=100
[image-open]: https://api.github.com/repos/MarathonOS/Marathon-Image/issues?state=open&per_page=100
[q25-old-open]: https://api.github.com/repos/MarathonOS/marathon-zinwa-q25/issues?state=open&per_page=100
[deckard-open]: https://api.github.com/repos/patrickjquinn/Marathon-Deckard/issues?state=open&per_page=100
[shipwright-open]: https://api.github.com/repos/patrickjquinn/shipwright-open/issues?state=open&per_page=100
[issue-50]: https://github.com/patrickjquinn/Marathon-Shell/issues/50
[issue-45]: https://github.com/patrickjquinn/Marathon-Shell/issues/45
[issue-44]: https://github.com/patrickjquinn/Marathon-Shell/issues/44
[pr-53]: https://github.com/patrickjquinn/Marathon-Shell/pull/53
[pr-54]: https://github.com/patrickjquinn/Marathon-Shell/pull/54
[camera-fullsize]: https://github.com/patrickjquinn/Marathon-Shell/commit/4a4c19e4
[camera-exposure]: https://github.com/patrickjquinn/Marathon-Shell/commit/0ef168825a5b1f610b7851c00498f3a90819f193
[fork-pr-1]: https://github.com/mikevocalz/Marathon-Shell/pull/1
[fork-pr-2]: https://github.com/mikevocalz/Marathon-Shell/pull/2
[fork-pr-3]: https://github.com/mikevocalz/Marathon-Shell/pull/3
[fork-pr-4]: https://github.com/mikevocalz/Marathon-Shell/pull/4
[image-2]: https://github.com/MarathonOS/Marathon-Image/pull/2
[image-3]: https://github.com/MarathonOS/Marathon-Image/issues/3
[image-4]: https://github.com/MarathonOS/Marathon-Image/pull/4
[image-5]: https://github.com/MarathonOS/Marathon-Image/pull/5
[image-6]: https://github.com/MarathonOS/Marathon-Image/pull/6
[image-7]: https://github.com/MarathonOS/Marathon-Image/pull/7
[u-security]: https://github.com/patrickjquinn/Marathon-Shell/blob/567f1faa8bfdf31611dd401134c293daa160221c/docs/SECURITY_MODEL.md
[u-encryption]: https://github.com/patrickjquinn/Marathon-Shell/blob/567f1faa8bfdf31611dd401134c293daa160221c/docs/ENCRYPTION.md
[u-ota]: https://github.com/patrickjquinn/Marathon-Shell/blob/567f1faa8bfdf31611dd401134c293daa160221c/docs/OTA.md
[u-install]: https://github.com/patrickjquinn/Marathon-Shell/blob/567f1faa8bfdf31611dd401134c293daa160221c/crates/marathon-apps/src/install.rs
[u-manifest]: https://github.com/patrickjquinn/Marathon-Shell/blob/567f1faa8bfdf31611dd401134c293daa160221c/docs/APP_MANIFEST_SCHEMA.md
[u-base]: https://github.com/patrickjquinn/Marathon-Shell/blob/567f1faa8bfdf31611dd401134c293daa160221c/packaging/packages/marathon-base-config/APKBUILD
[u-modem]: https://github.com/patrickjquinn/Marathon-Shell/blob/567f1faa8bfdf31611dd401134c293daa160221c/docs/MODEM_TESTING.md
[u-background]: https://github.com/patrickjquinn/Marathon-Shell/blob/567f1faa8bfdf31611dd401134c293daa160221c/docs/BACKGROUND_WORK.md
[u-maps]: https://github.com/patrickjquinn/Marathon-Shell/blob/567f1faa8bfdf31611dd401134c293daa160221c/scripts/qemu/automation/scenarios/07_app_interaction.py
[u-reef]: https://github.com/patrickjquinn/Marathon-Shell/blob/567f1faa8bfdf31611dd401134c293daa160221c/apps/reef/src/bridge.rs
[u-shell-main]: https://github.com/patrickjquinn/Marathon-Shell/blob/567f1faa8bfdf31611dd401134c293daa160221c/shell/main.cpp
[u-runner]: https://github.com/patrickjquinn/Marathon-Shell/blob/567f1faa8bfdf31611dd401134c293daa160221c/tools/marathon-app-runner/main.cpp
[u-android]: https://github.com/patrickjquinn/Marathon-Shell/blob/567f1faa8bfdf31611dd401134c293daa160221c/docs/ANDROID_APPS.md
[u-devices]: https://github.com/patrickjquinn/Marathon-Shell/blob/567f1faa8bfdf31611dd401134c293daa160221c/docs/DEVICE_SUPPORT.md
[u-q25-guide]: https://github.com/patrickjquinn/Marathon-Shell/blob/567f1faa8bfdf31611dd401134c293daa160221c/docs/install/ZINWA_Q25.md
[u-op6-flash]: https://github.com/patrickjquinn/Marathon-Shell/blob/567f1faa8bfdf31611dd401134c293daa160221c/scripts/flash/flash-oneplus6.sh
[u-package-reference]: https://github.com/patrickjquinn/Marathon-Shell/blob/567f1faa8bfdf31611dd401134c293daa160221c/docs/PACKAGE_REFERENCE.md
[u-hackberry-pipeline]: https://github.com/patrickjquinn/Marathon-Shell/blob/567f1faa8bfdf31611dd401134c293daa160221c/packaging/pipeline-patches/0057-feat-hackberrypi-its-own-image-id-so-its-own-update-.patch
[reddit-q25]: https://www.reddit.com/r/mobilelinux/comments/1xohzdm/marathonos_update_native_linux_now_fully_working/
[reddit-launch]: https://www.reddit.com/r/blackberry/comments/1ou5qbs/
[reddit-bb10]: https://www.reddit.com/r/blackberry/comments/1rgqa7f/anyone_else_miss_the_blackberry_os/
