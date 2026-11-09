# Modernization programme

Scope decision: November 9, 2026. All capabilities below are in the approved 2.0 programme unless explicitly listed in the [2.1 appendix](#15-version-21-appendix-workpersonal-spaces). Approval is authorization to implement; it is not implementation or device-validation evidence. Work/Personal Spaces, including organizational-only views, are deferred in full to 2.1.

## 1. Baseline: extend what exists

| Area | Upstream foundation | v2 work |
|---|---|---|
| Shell | Qt 6 Wayland compositor and QML shell | Explicit transition state, adaptive shell regions, desktop window policy |
| Native UI | Keel/Silica, Marathon.Silica, Marathon.Platform | Semantic tokens, adaptive wrappers, accessibility and input parity |
| Hub | Notifications, source filtering, weather/agenda | Durable conversation/account model with supported provider actions |
| Multitasking | Live covers and native app identity | Privacy-aware semantic activities, stable placement, paired tasks |
| Input | Pill navigation, hardware key routing, built-in keyboard | Consistent commands, focus restoration, trackpad/IME completeness |
| Services | Mail, DAV, SMS/MMS, calls, media, permissions | Reliability, consistent action contracts, offline recovery |
| Android | Deckard compatibility runtime | Capability matrix, resize/input/notification validation |
| Assistant | Pilot and action infrastructure | Selected-context assistance using validated permissions and confirmation |
| Store | Store and Reef transition | Actual install/update lifecycle and accurate runtime/device metadata |
| Distribution | postmarketOS/Alpine image pipeline | Reproducibility, protection status, recovery and per-device evidence |

## 2. Flow and Peek

Use one shell state machine for app focus, overview, Hub, shade, lock and keyboard. Maintain the existing pill as the visible starting affordance. Prototype BB10-style progressive Hub reveal without adding conflicting mandatory gesture systems. Preserve Sailfish's direct, finger-following motion.

- A partial reveal can cancel cleanly; a committed transition preserves the originating task.
- Resolve app-versus-shell gesture ownership before either performs an irreversible action.
- Back dismisses the nearest context first; forward is offered only when a client supports it.
- Preserve draft, cursor, selection, scroll and app instance through interruption and resize.
- Provide visible, keyboard and accessibility alternatives for essential gestures.
- Verify lock, incoming call, rotation, keyboard opening, process death and display removal during transitions.

## 3. Hub: communication as the central workspace

Extend notification aggregation with accounts, conversations, messages, attachments and explicit provider capability records. Begin with email, SMS/MMS, calendar and missed calls. Third-party services require supported APIs; notification mirroring must remain visibly distinct from full account integration.

Features: unified and per-account views; unread/follow-up/attachment filters; source badges; local search; supported inline reply; reversible triage; durable drafts; queued operations; clear queued/sent/failed/delivered states. Keep agenda and weather subordinate to communication. Always show the sending account before sending.

The local service must support stable provider IDs, provider-supported idempotency keys, sync cursors, conflict handling, retries with limits and permission-aware indexes. Notification dismissal must not delete a message. After an ambiguous send or restart, reconcile with the provider rather than blindly replaying; if the provider cannot resolve delivery, retain an explicit unknown outcome and let the user decide. Do not claim universal exactly-once delivery from a local outbox alone.

## 4. Live covers, activities and task continuity

Evolve existing covers into semantic summaries shared by overview, ongoing activity surfaces and lock screen. Use app plus instance IDs, privacy class, expiry, update budget and supported actions.

Examples: mail draft state; next event; music playback; timer; download progress; navigation instruction where supported; a separately installed app's saved/unsaved document; Moyo session resume with protected student details. These are integration targets, not claims those applications already run on Marathon.

Keep cover positions stable during selection. Prefer semantic state or cached thumbnails to continuously rendering background video surfaces. Distinguish closing a view from stopping audio/navigation/background work. Redact sensitive content immediately on lock, account unavailability or permission revocation. Work/Personal profile state is outside the 2.0 contract.

## 5. Native adaptive OS

The compositor publishes display regions, scale, occlusion, posture, orientation and input capabilities. Apps independently select presentation within their granted window. Width alone is insufficient. Resizing must not recreate the app's data/session state.

| Context | Shell behaviour | App behaviour |
|---|---|---|
| Square keyboard phone | Compact status/header, efficient covers and shortcuts | Dense readable lists; software keyboard override |
| Tall phone | Reachable gestures and temporary Hub reveal | One primary pane; contextual detail |
| Tablet | Optional persistent Hub, overview, split-screen | List/detail and optional inspector when space permits |
| Book foldable | Seamless compact/expanded posture transition | Reflow without lost draft, scroll or focus |
| Dual screen | Per-panel safe regions and task placement | Hinge-aware independent panes; no hidden controls |
| Desktop/external display | Resizable windows, snapping, overview and optional Hub rail | Keyboard/pointer navigation and native menus |

Add app-pair launch/resume, resize constraints, single-instance/multi-instance policy, drag-and-drop file grants, focus ownership and display hot-plug recovery. On unplug, move all reachable windows to the remaining display and retain work. Handle mixed DPI, rotation and accessibility text scaling.

A Surface Duo layout profile is a design/test target, not a claim of a working Marathon device port. Hardware enablement, sensor signals, GPU drivers and cellular readiness require separate evidence.

## 6. Keyboard, search and text

Build local type-to-search and a command launcher spanning apps, contacts, settings, files and permitted content. Use deterministic actions and visible provenance. Add app action IDs, customizable shortcut assignments, collision handling and a shortcut guide.

Complete trackpad activation/selection where exposed; predictable Tab order; IME composition; multilingual dictionaries; accents/emoji; native selection/clipboard; password-field handling; physical/software keyboard switching and focus restoration. Pilot may extend search but is not required for it.

V2-036 extends this with deterministic **Instant Actions**: type a command, inspect its target/account and activate an existing advertised action. The initial slice uses the declared Notes action rather than a new parallel command bus. Then cover message/event creation, shortcut discovery, collisions, layout changes and local suggestion acceptance. Distinguish focus navigation from text composition: command keys must not consume text while the IME owns it. Never learn from protected fields; offer a local prediction reset. Touch-sensitive hardware keyboard gestures require an exposed capability and are not promised on ordinary keyboards.

## 7. App-to-app invocation

Build on existing Keel actions, sharing and portals. Define versioned typed input/output schemas, MIME support, caller/task identity, permission requirements, deadlines, cancellation and result delivery. Grant narrow file access; do not expose arbitrary paths.

A focused task runs in the target app's isolated process. The compositor presents it and returns its result to the original context. Reference journey: email attachment → independently installed compatible annotation app → edited attachment returned to the same draft. Use a non-premium test fixture for OS validation; a licensed Forge-powered app may participate through the same public APIs. Also support capture-to-note, calendar creation and sharing through advertised capabilities.

## 8. First-party application modernization

Apply the shared UI specification to Phone, Messages, Mail, Contacts, Calendar, Notes, Files/attachment picker, Gallery, Camera, Music, Clock, Calculator, Maps, Settings, Reef and Pilot. Audit whether Files needs a new app or an extension to existing surfaces before adding another service.

Every supported app needs a coherent cover, adaptive layout, text scaling, keyboard operation, useful empty/offline/error states and durable user work. Prioritize Mail/Messages/Calendar/Notes and attachment handling for the first end-to-end experience. Keep camera, telephony and map capabilities tied to actual hardware/provider support.

Add personal Focus/quiet schedules, bedside charging presentation, controlled alarm exceptions and notification privacy. All Work/Personal organization and isolation are deferred to 2.1; no work account partition, work-mode toggle or profile switcher belongs in the 2.0 UI.

### Remember-style tasks and attachment provenance — V2-033

Extend the existing Notes app and its checkbox-task view with durable task identity, due dates, completion, tags, source links and permission-scoped attachments. Define migration from existing note lines before moving task storage. Notes, Hub and Calendar should show the same task state instead of copying it into three independent records. A removed source or revoked grant must leave an understandable unavailable-source state, not a dangling file path or lost task. Keep creation and completion usable offline; add sync only with an explicit conflict and retry contract. Recurrence, voice notes and project organization remain part of the staged 2.0 scope and each needs its own evidence.

### Meeting preparation and follow-up — V2-037

Connect a meeting to explicitly selected messages, files, notes and follow-up tasks. Show event and device time zones and preserve all-day/recurrence meaning through changes. A running-late action prepares a message with recipients and sending account visible; sending remains a deliberate user action. Conference joining advertises only supported link handlers. Offline preparation must retain the event context and explain unavailable remote attachments. Build on Calendar actions, DAV and the Hub/task contracts; no speculative provider API or mandatory AI service.

### Personal scenes — V2-035

Travel, Bedside and Focus are personal presentation/notification presets. Start with a reversible manual scene using existing ambience and quiet-state boundaries, then qualify scheduled and charging triggers. Show the effective settings, which values the scene controls and when it ends. Preserve alarms and declared urgent-call exceptions, handle overlapping schedules deterministically and respect a user's manual override. Travel can collect user-selected itinerary details and local/away times; location-based triggers require an independently granted capability. Scenes do not create work/personal groups, profiles or isolated storage.

### Secure messaging, voice and video — V2-034

Restore the earlier BB10 successor's secure communication goal as a phased native 2.0 workstream. Keep ordinary SMS/MMS distinct from end-to-end encrypted messaging. Select a maintained protocol/provider and native implementation only after checking its current APIs, encryption guarantees, licenses, account lifecycle and device support. Reuse existing contacts, notifications, permissions, audio routing and lifecycle interfaces; encryption and a packet transport are not present merely because those seams exist.

Sequence a two-party encrypted text session and verified device identity first, then attachment delivery and restart recovery, then voice, then video and group behavior. Include recipient/device verification, blocked users, account/device revocation, history/key recovery, call interruption, camera/microphone indicators, audio-route changes, reconnect and background resource ownership. For multi-party media, document exactly which links are encrypted and whether any relay can access content. Never label transport encryption alone as end-to-end encryption. Use a controlled test service and test accounts before real provider qualification; do not make promises of arbitrary third-party chat interoperability.

### Paired-device continuity — V2-030

Give the personal phone and a separately running computer/tablet an explicit pairing, capability and revocation flow. This is distinct from external-monitor windowing. Begin with user-approved file/link delivery, cancellation, integrity checks and interrupted-transfer recovery. Add opt-in notification actions and finally app-advertised continuation of a draft/document/task. Do not expose arbitrary filesystem access or execute remote commands under a generic pairing permission. Prevent duplicate actions on reconnect and stop future access immediately after unpairing. App-specific continuation requires versioned state, permission revalidation and an explicit conflict policy. KDE Connect is a reference to evaluate, not a claimed dependency or existing Marathon integration.

## 9. Native application SDK and optional commercial packages

Keep existing QML apps intact. Prove a native Linux/Wayland React Native host using Hermes/Fabric and Qt Quick integration. Share generic app-facing contracts with the separate QNX target, but implement and test OS adapters independently. Premium Forge engines remain in the separately distributed commercial product.

Required adapters: window/lifecycle, rendering, input/IME, accessibility, menus/popovers, clipboard, file grants, audio, notifications, permissions, secure storage, networking, activities and action results. Audit Expo Modules v2 and Nitro Modules v1 support per module; version labels do not provide platform implementations.

Expose public theme roles that optional NYC-Tron application adapters can consume. Nitro Forge remains a separate premium product for sale: do not copy its source, components, engines, assets or entitlement code into Marathon, its images, bundled apps, public examples or CI artifacts. OS builds, boot, updates and core workflows must succeed with no Forge package, credentials or license present.

The developer experience target is install the selected licensed Forge package, import its components, and build the app through documented native tooling. Provide generic module discovery/autolinking, version/ABI checks, platform service bindings, packaging and actionable diagnostics so developers do not patch Marathon or hand-wire each component. Keep Forge-specific adapters, native binaries, commercial distribution and entitlement policy with Forge or the consuming app. Preserve its existing licensing; this OS plan grants no redistribution rights.

Validate the platform SDK using non-premium fixtures. In the separate authorized Forge project, validate a licensed consuming app on Marathon: package installation, native linkage, rendering, input, accessibility, file access, lifecycle, update and uninstall. Removing Forge or the app must leave the OS fully functional. Seamless support is an acceptance goal, not an existing compatibility claim.

SDK acceptance: a clean sample installs, signs, launches, renders, accepts input, backgrounds, survives restart, publishes a cover, invokes a permitted action, updates and uninstalls on device. Publish capability discovery and honest unsupported-operation errors. CI must test the distributed SDK, not only monorepo internals.

## 10. Pilot, privacy and user control

Extend existing Pilot for selected conversation summaries, local attachment lookup, reminder preparation, reply drafting and approved app actions. Expose sources and exact recipients/accounts/content before outbound actions. Revalidate the target after confirmation; keep a readable action history and cancellation path.

Treat messages, pages and attachments as untrusted content. Enforce permissions outside the model. Show voice capture indicators and a reliable stop action. Measure offline latency, thermal/power costs and language coverage on hardware. Core use remains AI-optional.

## 11. Daily-driver modernization

- Isolation: per-app IPC filtering, secret/file/clipboard/screen access policy, app-specific warm-runner confinement and fail-closed supported configurations.
- Accessibility: controlled assistive-technology bridge, actual screen-reader journeys, scaling, contrast, reduced motion/transparency and keyboard parity.
- Data protection: precise encryption coverage, verified protection status, enrollment failure handling, credential handling, backup/restore and independent verified-boot assessment.
- Telephony: per-device/carrier IMS/VoLTE, SMS/MMS, suspend wake, audio routes, weak-signal recovery and legitimate emergency-call qualification through authorized arrangements.
- Power: background budgets, wakeup audit, alarms, overnight drain and thermal tests under mixed native/Android workloads.
- Updates: signed artifacts, interrupted staging, bad signature/full disk, failed boot, migration compatibility and tested recovery/rollback semantics per device.
- Ecosystem: runtime/dependency/device metadata, verified install/update/uninstall, supported push behaviour and truthful compatibility limits. No universal banking, DRM or payment promise.

### Credentials and passkeys — V2-031

Specify a native credential capability separately from the mail/DAV keyring and Bluetooth pairing codes. Inventory the actual browser engine, platform APIs and target-device authenticators before selecting an implementation. First prove a supported external security-key path and origin/relying-party binding; then implement native app requests and any platform authenticator/provider through a reviewed contract. Include user verification, cancellation, locked/unavailable authenticators, deletion, device loss and recovery. Report hardware-backed, device-bound and syncable properties only when the selected backend proves them. Hardware-bound credentials must not be silently copied into backup archives. Core OS use must not require a new Marathon cloud account.

### Migration, export and restore — V2-032

Make entry to and exit from Marathon a complete user workflow beyond a backup button. Import standard contacts/calendar data and supported notes/files with preview, duplicate/conflict choices, provenance and undo. Keep arbitrary source files as untrusted input; use a bounded native parser off the UI thread. Publish a versioned backup manifest listing each included/excluded category, its schema and restoration result. Separate application reinstall, user-data restore and account reauthentication. Recover attachments and task links where supported and explain unavailable sources. Restore into a clean installation, check incomplete/full-disk/corrupt archives and preserve existing data on failure. Portable export and recovery must work without depending on a Marathon-hosted service.

## 12. Delivery phases

| Phase | Deliverables | Exit evidence |
|---|---|---|
| P0 — baseline | Fork/branch, reproducible reference image, gap ledger, device matrix, adaptive contracts | Known source/image/dependency SHAs; recorded failures; repeatable boot |
| P1 — visual/interaction foundation | Tokens, native screen prototypes, Flow state, accessible controls, compact/expanded/hinged layouts | Home→Peek→Hub→resume across phone and tablet geometry without state loss |
| P2 — communication | Durable Hub providers, offline queue, activities, invocation, task provenance, Instant Actions, meeting workflows; secure-communication protocol decision | Real account journey with deduplicated send/recovery, attachment return and durable linked task |
| P3 — native ecosystem and trust | RN host, public platform adapters, non-premium sample, SDK packaging; credentials, migration manifests, encrypted text proof; separate commercial-app validation | Clean install-to-uninstall lifecycle; verified credential and encrypted-text failure cases |
| P4 — expanded use | Split/window policy, paired apps, drag/drop, keyboard/pen, external display; companion transfer/continuation, personal scenes, secure voice/video | Resize/posture/hot-plug preserves work; pairing/revocation and call lifecycle journeys |
| P5 — release qualification | Security, cellular, power, accessibility, OTA, core app/store completion, full restore/migration and all approved 2.0 capability gates | Published per-device/provider evidence; no critical release blockers; no 2.1 Spaces dependency |

Security, performance, accessibility and adaptive design begin at P0 and continue in every phase. P4 expands windowing depth; it is not the first tablet/foldable design work. Estimates follow baseline reproduction; this plan does not promise calendar dates.

These phases stage the approved 2.0 programme; secure communication, companion continuity and credentials are not postponed to 2.1 by their position in the sequence. A limited demonstration can show completed slices with a truthful capability ledger. It cannot be called completion of the full programme. Optional commercial app qualification stays separate from OS release readiness.

## 13. Release gates

Track proposed, implemented, CI-verified and device-verified separately. Do not infer readiness from code presence or mark a skipped suite as passing.

Provisional core-gesture goal: fewer than 1% missed presentation deadlines in repeatable reference-device tests; calibrate against baseline. Report refresh rate, content freshness, p95/p99 timing, input latency, memory, thermal state and idle drain. At 60 Hz the frame interval is 16.67 ms. Define launch/resume and power budgets from actual P0 measurements before committing to numerical release thresholds.

Required journeys: draft→Peek→reply→return; annotate→return result; offline send→restart→reconnect without duplicate; lock→private previews disappear; fold/unfold and rotate with keyboard open; plug/unplug external display; incoming call during drag; low-memory app termination→restore; revoked permission→safe failure; interrupted update→documented recovery.

Additional 2.0 journeys: message→linked task→meeting follow-up; Instant Action→preview→existing action→return focus; personal scene→manual override→scheduled exit; paired transfer→disconnect→resume once→unpair; credential registration→reboot→authentication→loss/recovery; encrypted text→attachment→voice/video with verified endpoints and denied/revoked media permission; import preview→deduplication→undo; clean-device restore with a category-by-category result. Work/Personal Space journeys belong only to 2.1.

Use upstream CTest registration and relevant QML/import/icon checks for implementation. Keep visual evidence for light/dark/ambience, compact/square/expanded/hinged, text scaling and reduced motion. A documentation-only commit requires document/link/scope checks, not an OS build claim.

## 14. Sources

- [Pinned upstream README](https://github.com/patrickjquinn/Marathon-Shell/blob/c2c1b2fe32aeaa51edf75a45045cbfbbc08c4ac5/README.md)
- [Keel migration](https://github.com/patrickjquinn/Marathon-Shell/blob/c2c1b2fe32aeaa51edf75a45045cbfbbc08c4ac5/docs/KEEL_APP_MIGRATION.md)
- [Sailfish keep/drop rationale](https://github.com/patrickjquinn/Marathon-Shell/blob/c2c1b2fe32aeaa51edf75a45045cbfbbc08c4ac5/docs/design/2026-10-12-sailfish-ux-keep-drop.md)
- [Existing roadmap](https://github.com/patrickjquinn/Marathon-Shell/blob/c2c1b2fe32aeaa51edf75a45045cbfbbc08c4ac5/docs/roadmap/TRACKER.md)
- [Q25 release integration candidate](https://github.com/patrickjquinn/Marathon-Shell/tree/release/q25-v1)
- [Sailfish UI principles](https://docs.sailfishos.org/Develop/Apps/UI/)
- [BlackBerry 10 UI guidelines](https://developer.blackberry.com/devzone/files/design/bb10/UI_Guidelines_BlackBerry_10.pdf)
- [BlackBerry Remember and Calendar user guide](https://www.att.com/support_static_files/manuals/BlackBerry_Q10.pdf)
- [BlackBerry Blend announcement, filed with the SEC](https://www.sec.gov/Archives/edgar/data/1070235/000107023514000126/pr092414.htm)
- [KDE Connect capabilities](https://kdeconnect.kde.org/)
- [FIDO passkey concepts](https://fidoalliance.org/passkeys/)
- [Sailfish contact import](https://docs.sailfishos.org/Support/Help_Articles/Importing_Contacts/)
- [Sailfish backup scope and limitations](https://docs.sailfishos.org/Support/Help_Articles/Backup/Backup_and_Restore/)
- [Applied engineering skills and source inventory](ENGINEERING_WORKFLOW.md)

The earlier research remains supporting evidence, not a live device certification. Update the gap ledger as new upstream changes are imported.

## 15. Version 2.1 appendix: Work/Personal Spaces

The user deferred **all** Work/Personal Spaces to 2.1 on November 9. This supersedes the earlier suggestion to ship organizational work/personal views in 2.0. Do not add a work-mode toggle, profile picker, work account grouping, enterprise enrollment, separate work storage/credentials or profile-based notification rules to a 2.0 slice. Normal multiple accounts and personal Travel/Bedside/Focus scenes remain in 2.0.

| 2.1 ID | Work package | Prerequisites | Acceptance target |
|---|---|---|---|
| V21-001 | Work/Personal organization and switching | Qualified personal Hub, account identity, navigation and credential contracts | Explicit space membership, understandable switching and preserved drafts; no claim that UI grouping isolates data |
| V21-002 | Enforced profile isolation and management | V21-001; reviewed storage, IPC, keys, clipboard/file grants, backup and lock architecture | Denied cross-space access, explicit approved transfer, independent lock/pause/revocation and qualified restore behavior |

Owner roles: product + native shell for V21-001; security + platform for V21-002. Human assignments remain unassigned. Neither package is a dependency of V2-001–037 or a condition of the 2.0 release. Reuse stable public contracts where possible, but do not build speculative profile machinery into the 2.0 implementation.
