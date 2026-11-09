# v2 implementation backlog

All entries are **planned**, not completed. IDs are planning identifiers, not GitHub issue numbers. Each implementation PR should name its ID, dependencies, changed behaviour and validation evidence. Role labels identify needed expertise rather than assigned people; actual human owners remain unassigned. A partial PR does not complete its parent work package.

Scope approved November 9, 2026: V2-001–037 belong to the 2.0 programme. All Work/Personal Spaces, including organization-only views and work profiles, are 2.1 only. Personal multiple accounts and Travel/Bedside/Focus scenes remain in 2.0. Follow the [native/API engineering workflow](ENGINEERING_WORKFLOW.md) for each slice.

| ID | Phase / role | Work package | Depends on | Acceptance evidence |
|---|---|---|---|---|
| V2-001 | P0 / platform | Pin source, toolchain, images and device capabilities; reconcile main/Q25 docs | — | Repeatable reference boot and explicit failure ledger |
| V2-002 | P0 / design + shell | Adaptive safe-region, posture and input contract | 001 | Compact/expanded/hinged geometry fixtures; state survival design |
| V2-003 | P1 / design | Canonical tokens and icon/state specification | 001 | Theme exports agree; contrast, scaling and reduced modes reviewed |
| V2-004 | P1 / shell | Flow/Peek transition and gesture arbitration | 002 | Cancel/reverse/call/lock/rotation tests retain focus and work |
| V2-005 | P1 / design + QML | Home, Covers, Hub and Quick Controls native prototypes | 002,003,004 | Coherent five-form-factor interaction review |
| V2-006 | P1 / accessibility | Controls, screen-reader bridge and keyboard focus | 003 | Actual assistive-technology journey and no gesture-only essential task |
| V2-007 | P2 / services | Conversation/account/provider capability model | 001 | Stable IDs, source/account identity and provider contract tests |
| V2-008 | P2 / services | Email/SMS/calendar/call adapters and sync | 007 | Real supported accounts; notification-only sources labeled |
| V2-009 | P2 / services | Drafts, offline queue and sync recovery | 008 | Restart/reconnect does not blindly replay ambiguous sends; reconciliation and explicit failure retain the draft |
| V2-010 | P2 / shell + SDK | Activity schema and privacy-aware covers | 003,007 | Cover/strip/lock state consistency; immediate privacy redaction |
| V2-011 | P2 / SDK | Typed actions, narrow file grants and result return | 001,006 | Cancel/timeout/permission-revocation/caller-death handling |
| V2-012 | P2 / input | Keyboard shortcuts, local search, IME and trackpad; foundation for V2-036 | 006,011 | Multilingual composition, shortcut collisions and restored focus |
| V2-013 | P2 / apps | Mail/Messages/Calendar/Notes and attachment UI; task/meeting extensions in V2-033/037 | 005,008,009,011 | Complete communication journey on phone/tablet with offline states |
| V2-014 | P3 / runtime | Native RN Marathon host and service capability inventory | 001,002,006 | Actual native window, Fabric/input/lifecycle proof; no Android dependency |
| V2-015 | P3 / UI runtime | NYC-Tron Qt adapter and generated token parity | 003,014 | Native menus, text, focus, accessibility and adaptive panes |
| V2-016 | P3 / app compatibility | Generic native package integration; separate licensed Forge consuming-app validation | 011,015 | Install/import/build selected packages without OS patches; public OS tests use non-premium fixtures; premium validation stays in the authorized Forge/app project |
| V2-017 | P3 / SDK + packaging | Signed RN sample and reproducible developer template | 014,015 | Non-premium sample: clean install, update, permission change, restart and uninstall; no Forge license or package required |
| V2-018 | P4 / compositor | Split-screen, task pairs and window constraints | 002,004,010 | Pair restore and resize retain work without focus stealing |
| V2-019 | P4 / compositor | External displays, mixed DPI, snap and hot-plug | 018 | Unplug recovers all windows onto a reachable display |
| V2-020 | P4 / input + portals | Native drag/drop, pointer and pen capabilities | 011,018 | Scoped file transfers, keyboard equivalents, verified pen properties |
| V2-021 | P2–P5 / apps | Remaining core apps, personal quiet/bedside UI, onboarding and settings; scenes in V2-035 | 003,006,010 | Per-app device/adaptive/accessibility matrix; alarms survive quiet modes; no work-profile UI |
| V2-022 | P3–P5 / Pilot | Selected-context assistance and verified action execution | 011,013 | Explicit outbound confirmation; hostile content cannot grant actions |
| V2-023 | P0–P5 / security | IPC/secret access, sandbox and warm-pool audit/hardening | 001 | Confinement before app execution; revocation and boundary tests |
| V2-024 | P0–P5 / platform | Encryption status, recovery foundations and boot-chain assessment; credentials/data migration in V2-031/032 | 001,023 | Failed enrollment never reports protected; recoverability evidence |
| V2-025 | P0–P5 / device QA | Telephony, suspend, audio, camera, sensors and power | 001 | Per-SKU/carrier reports; wake/recovery and overnight drain measurements |
| V2-026 | P0–P5 / release | Signed OTA, migration and recovery qualification | 001,024 | Bad signature/full disk/power interruption/failed boot outcomes |
| V2-027 | P3–P5 / ecosystem | Reef installs, app trust metadata and Deckard parity | 010,011,023 | Accurate compatibility and real install/update/uninstall, resize and push |
| V2-028 | All / performance QA | Frame, latency, memory and energy regression harness | 001 | Reproducible measurements; no averages hiding missed deadlines |
| V2-029 | P5 / release QA | Device-specific release readiness and docs | All OS release-scoped items, including 030–037 | Published known limits, reproducible image and no critical blockers; excludes commercial-app qualification and V21 packages |
| V2-030 | P3–P5 / native networking + shell | Paired-device trust, transfers and app continuation | 001,006,009,011,023,024 | Pair/revoke, interrupted transfer, deduplicated actions and app-state conflict evidence |
| V2-031 | P3–P5 / identity + native platform | Credentials/passkeys and authenticator lifecycle | 001,006,023,024 | Verified app/origin binding, cancellation, device loss/recovery and truthful authenticator capabilities |
| V2-032 | P3–P5 / data + release | Migration, portable export and complete restore reporting | 007,009,011,024,031 | Preview/dedupe/undo; clean-install restore; explicit exclusion and reauthentication report |
| V2-033 | P2–P5 / apps + storage | Remember-style tasks, attachments and source provenance | 007,009,011,013 | Stable task identity, retained offline edits, due/completion state and unavailable-source handling |
| V2-034 | P2–P5 / secure communications + media | Native encrypted messaging, attachments, voice and video | 001,007,009,010,011,023,024,025,031 | Verified peer/device identity, declared encryption boundaries, reconnect and permission/audio/call-lifecycle evidence |
| V2-035 | P2–P5 / shell + power | Personal Travel/Bedside/Focus scenes | 003,006,010,021,025 | Reversible preferences, alarm exceptions, overlap/manual override and timezone/charging recovery |
| V2-036 | P2–P5 / input + actions | Keyboard Instant Actions and local prediction | 006,011,012 | Existing action dispatch, visible target, safe IME focus, collisions and protected-field exclusion |
| V2-037 | P2–P5 / calendar + apps | Meeting preparation and follow-up | 007,009,011,013,033 | Linked context, correct time zones, explicit outbound confirmation and retained offline meeting state |

## Added work packages: source seams and first slices

The inspected baseline is `bc39c23cac18221df21e410a45f8cc72d0ae9824`. Paths below exist there; they identify integration boundaries, not finished implementations. Proposed objects/protocols must be designed and checked against the actual API before implementation. Each owner role works with a different reviewer role; use delegated agents where work can be separated.

### V2-030 — paired-device continuity

**Owner:** native networking + shell. **Independent review:** security + lifecycle. **Dependencies:** 001,006,009,011,023,024.

Source seams: `crates/marathon-shell-native/src/portal.rs` for the existing file chooser and request lifecycle; `crates/marathon-shell-native/src/notifications.rs` for notification state; `crates/keel-actions-schema/src/` for advertised actions; `crates/marathon-shell-native/src/tasks/keel.rs` for app action dispatch. Existing Bluetooth pairing is a transport/device feature, not companion authorization.

1. First slice: specify a versioned pairing/transfer contract with user-visible peer identity, permitted operation, size limits, cancellation, expiry and revocation. Select a supported transport by source/API review. Implement one accepted file or link transfer between two controlled native fixtures; no unrestricted remote command capability.
2. Add resumable transfer with integrity validation, permission-scoped destinations and a durable operation identity. Record retry/reconnect behavior before enabling notification actions.
3. Add explicitly enabled notification actions, then app-advertised continuation. A paired device must not obtain arbitrary app state; validate the destination app/version and resolve concurrent edits.

Acceptance: reject an unknown/revoked peer; cancel during transfer; handle duplicate/reordered messages, full disk and interrupted writes without replacing a good file; resume once after disconnect; deny an action when its permission changes; unpair while an operation is pending. Measure idle wakeups. Keep peer keys and user content out of logs. A protocol decision or local two-process fixture is not cross-device validation.

### V2-031 — credentials and passkeys

**Owner:** identity + native platform. **Independent review:** security + browser/native-app integration. **Dependencies:** 001,006,023,024.

Source seams: `crates/marathon-maild/src/secrets.rs` and `crates/marathon-davd/src/secrets.rs` use Secret Service for account credentials; `crates/marathon-shell-native/src/security.rs` handles owner verification; `apps/settings/pages/SecurityPage.qml` presents protection settings; `apps/browser/components/BrowserTab.qml` is the browser integration boundary. These do not establish FIDO passkey support. Bluetooth numeric passkeys are unrelated.

1. First slice: inventory the selected browser/Qt build and an external security-key backend using actual versioned APIs. Specify request identity, relying party/origin, user verification, cancellation, supported operations and recovery without exposing key material.
2. Prove register/authenticate with a controlled relying party and supported hardware key. Add a native-app request contract only after app identity and provider ownership are enforced outside application code.
3. Qualify a platform provider/authenticator and any optional synchronization separately. Expose hardware-backed/device-bound/syncable properties as observed capabilities. Specify account deletion and recovery, including an absent/lost authenticator.

Acceptance: wrong origin/app is rejected; a cancelled or timed-out prompt cannot authenticate later; locking, unplugging or revoking an authenticator fails explicitly; a reboot retains only authorized credentials; recovery does not export a device-bound key; denied providers do not appear to succeed. No new mandatory cloud account, custom cryptographic protocol or unsupported hardware-security claim.

### V2-032 — migration, export and restore

**Owner:** data + release. **Independent review:** storage + security. **Dependencies:** 007,009,011,024,031.

Source seams: `crates/marathon-davd/src/contacts.rs`, `accounts.rs` and `sync.rs`; `crates/marathon-app-native/src/calendar.rs`; `apps/notes/NotesStore.js` legacy merge; `crates/marathon-shell-native/src/qsettings.rs`; `apps/settings/pages/AccountsPage.qml`, `StoragePage.qml` and `UpdatesPage.qml`; `docs/ENCRYPTION.md`. Audit actual storage ownership before listing a category as covered.

1. First slice: define the category/schema/credential-exclusion manifest and implement a bounded standard-contact import preview using a vetted parser. Preserve the input; separate preview from commit; present duplicate choices and a reversible transaction.
2. Add calendar, supported note/task and attachment import/export. Preserve stable source identifiers and explain unsupported fields. Do not treat an arbitrary app directory copy as a valid migration.
3. Restore a versioned archive to a clean installation with per-category outcomes. Separate app reinstall, local-data restore, remote account resync and required reauthentication. Add encrypted archive delivery/recovery once the key and deletion contract is reviewed.

Acceptance: repeated import does not duplicate unchanged items; merge/keep-both and undo preserve expected data; malicious/oversized/truncated input, full disk and interruption leave existing data intact; missing apps/accounts and revoked file grants are reported; tasks retain attachments/provenance where supported. Export must be readable outside Marathon. Record exactly what a backup omits and prove a clean-device restore.

### V2-033 — durable tasks and attachment provenance

**Owner:** apps + storage. **Independent review:** data migration + action API. **Dependencies:** 007,009,011,013.

Source seams: `apps/notes/NotesStore.js` currently derives checkbox tasks from note lines; `apps/notes/pages/TasksPage.qml` displays/toggles them; `apps/notes/NotesActions.qml` and `keel-actions.json` advertise note creation/search; `crates/marathon-app-native/src/calendar.rs` owns Calendar's current event storage. Preserve existing notes and checkbox workflows.

1. First slice: define durable task identity, completion, due date and optional source reference. Migrate a fixture with edited/reordered checkbox lines without losing the original note; expose creation through the existing Keel action mechanism after schema review.
2. Add source-aware capture from Hub and permission-scoped attachment references. Show a useful unavailable-source state when the original message/file disappears. Share task identity with Calendar instead of copying completion flags.
3. Add recurrence, tags/projects and voice-note attachments, then sync/conflict handling. Keep local create/edit/complete working when services are offline.

Acceptance: reorder the source note, restart and complete the intended task; show the same state in Notes and Calendar; preserve concurrent/offline edits; revoke or delete an attachment without losing the task; undo a capture/delete where supported; restore task data through V2-032. Invalid due dates/time zones and unsupported actions fail explicitly.

### V2-034 — secure messaging, voice and video

**Owner:** secure communications + media. **Independent review:** protocol/security + device audio/lifecycle. **Dependencies:** 001,007,009,010,011,023,024,025,031.

Source seams: `apps/messages/MessagesApp.qml` and `MessagesActions.qml`; `crates/marathon-app-native/src/contacts.rs`, `notifications.rs`, `audio.rs`, `permissions.rs`, `lifecycle.rs` and `camera.rs`; `crates/marathon-audiod/` and `crates/marathon-telephonyd/`. SMS/MMS and cellular-call support are not evidence of encrypted messaging or internet calling.

1. First slice: write a current protocol/provider/native-SDK comparison and select a maintained implementation with clear licensing and account/device semantics. Build a two-party text exchange on controlled accounts with verified device identity and documented encryption boundaries. Do not invent an encryption scheme or call a TLS-only channel end-to-end encrypted.
2. Add encrypted attachments, durable outbox/reconciliation, blocking, device revocation and explicit history/key recovery. Then deliver one-to-one voice and video as separate reviewable slices; qualify group behavior after those contracts hold.
3. Integrate Hub/activities, permission mediation, microphone/camera indicators and background claims. Specify signaling/relay behavior, reconnect, network change, audio focus and interruption by a cellular call. Core navigation remains usable when the service is absent.

Acceptance: verify intended peer devices; handle key/device change, duplicate delivery and restart; reject revoked recipients/devices; demonstrate the declared content-encryption boundary including relays; mute/end-call/deny/revoke camera or microphone reliably; recover audio routes and focus; bound background work and memory. Record actual packet/provider/device evidence. Provider selection, stub media or a successful handshake alone do not complete this package.

### V2-035 — personal Travel/Bedside/Focus scenes

**Owner:** shell + power. **Independent review:** accessibility + alarms/notifications. **Dependencies:** 003,006,010,021,025.

Source seams: `shell/qml/core/AmbienceController.qml`, `SystemControlStore.qml`, `crates/marathon-shell-native/src/settings.rs` and `notifications.rs`, `apps/settings/pages/AmbiencePage.qml`, `NotificationsPage.qml`, `DateTimePage.qml`, and `crates/marathon-app-native/src/alarms.rs`/`world_clock.rs`. Existing DND and ambience controls are the foundation, not a complete scene scheduler.

1. First slice: a personal manual scene with an explicit set of preference overrides, observed effective state and a reversible exit. Keep changes through the existing services and show an unsupported preference before activation.
2. Add schedules and charging triggers with a single precedence rule, timezone/DST handling, manual override and a visible end time. Preserve alarms and explicitly configured urgent-call exceptions.
3. Add user-selected travel itinerary/time-zone context and capability-gated location triggers. Give the user a clear stop control and retain an offline view of selected information.

Acceptance: enter/exit a scene without changing account identity or data ownership; cancel/override it; restart during an active schedule; cross DST/time-zone boundaries; unplug while Bedside is active; receive an alarm/call; recover after a missing service. Work mode, work/personal grouping, enterprise policy and profile switching are explicitly absent until 2.1.

### V2-036 — keyboard Instant Actions and local prediction

**Owner:** input + actions. **Independent review:** native UI/accessibility + action API. **Dependencies:** 006,011,012.

Source seams: `shell/qml/components/MarathonSearch.qml`, `shell/src/wayland/keyrouting.h`, `shell/src/services/remotetextinput.cpp`, `crates/marathon-shell-native/src/text_input.rs`, `shell/qml/keyboard/UI/PredictionBar.qml`, `crates/marathon-shell-native/src/tasks/keel.rs`, and existing `apps/*/keel-actions.json` declarations. A declared action is not automatically safe to run from unreviewed free text.

1. First slice: an explicit command entry recognizes one deterministic Notes capture action, shows the exact target/title/body and dispatches the existing advertised action. Preserve ordinary search and provide keyboard and visible activation. Do not introduce an arbitrary shell-command executor.
2. Add advertised message/event actions, customized shortcuts, a discoverable guide, collision rules and unavailable-action feedback. Show recipients/accounts before outbound work and retain the originating focus/context.
3. Extend existing prediction with verified local engine APIs, language switching, acceptance/correction and reset. Keep protected input out of learning and treat touch-sensitive physical keyboards as a hardware capability, not a default assumption.

Acceptance: command execution has exactly one intended effect; cancelling or losing focus preserves text; stale/unavailable/failed actions show recoverable errors; IME composition/dead keys and app shortcuts retain ownership; collision changes are visible; screen reader and keyboard-only operation work; protected fields never contribute learned text. Run the real QML action dispatch, not just a command-parser test.

### V2-037 — meeting context and follow-up

**Owner:** calendar + apps. **Independent review:** sync/time + action API. **Dependencies:** 007,009,011,013,033.

Source seams: `apps/calendar/CalendarActions.qml`, `CalendarLogic.js` and `pages/`; `crates/marathon-app-native/src/calendar.rs`; `crates/marathon-davd/src/sync.rs`; `apps/email/EmailApp.qml`; existing Notes actions and the Hub provider model. Calendar's current local-time action fields are not proof of provider/time-zone parity.

1. First slice: attach one explicitly selected note/task reference to an event and return to the same event after editing it. Define source identity and an unavailable-reference state before adding cross-app previews.
2. Add relevant user-selected messages/files, event/device time zones, recurring/all-day semantics and an offline preparation view. Use narrow grants rather than indexing unrelated private documents.
3. Add a running-late message draft and supported conference-link dispatch. Show the sending account, exact recipients and content before sending; resolve a changed/cancelled meeting before dispatch. Add follow-up tasks through V2-033.

Acceptance: the note/task remains linked across restart and event edits; missing/revoked content is explained; DST, travel and all-day events retain meaning; offline preparation preserves edits; cancelling a draft sends nothing; reconnect does not duplicate a message; conference handler failure returns to the meeting. No unverified arbitrary-provider join support.

## Initial PR sequence

The [remediation queue and 37-package tracker](REMEDIATION_QUEUE.md) records ready-to-file repairs while GitHub Issues is disabled, plus the bounded evidence and remaining gates for draft PRs #4–#8. None of those drafts is merged or completes a whole work package.

The [November 9 v1 audit](V1_GAP_AUDIT.md) identifies 548 newer upstream commits and separates fixed upstream behavior from remaining source defects and unrun device gates. Reconcile that intake through V2-001 before duplicating implementation. Its data-loss, app-trust, accessibility and recovery findings are concrete acceptance work within the existing packages below.

1. `docs(v2): define native successor modernization plan` — these documents only.
2. `docs(v2): record reproducible platform and device baseline` — V2-001, including exact dependency/image revisions and failures.
3. `feat(layout): expose adaptive display regions` — V2-002 contract and fixtures.
4. `feat(theme): add semantic v2 theme roles` — V2-003, preserving existing imports and compatibility.
5. `feat(shell): preserve task state during hub peek` — V2-004 with interruption tests.
6. `feat(shell): introduce adaptive home and cover layouts` — reviewed V2-005 slice.
7. Hub and activity services follow after contracts and privacy tests; RN proof follows after lifecycle interfaces are stable.
8. V2-036 may start with a narrow existing-action Notes capture prototype while its complete command/input contract remains planned. Validate the actual dispatch and preserve ordinary search; do not mark V2-012 or V2-036 complete from that slice.
9. In parallel, review V2-031 authenticator/API choices and V2-034 protocol/native-SDK choices, and specify V2-032 data coverage. These are prerequisites to concrete native implementations, not substitutes for them.
10. Build V2-033 durable task identity before V2-037 meeting links, and the V2-030 pairing/revocation contract before remote actions. Deliver V2-035 personal scenes without introducing the deferred work-profile machinery.

Security/accessibility findings that block early work should be fixed alongside these slices. Do not wait until the end to discover the shell cannot safely expose an app activity.

## Integration rules

Create `feat/v2-*`, `fix/v2-*` or `docs/v2-*` branches from `v2`; merge via reviewed PRs into `v2`. Verify the PR base is `v2`, not the repository default branch. Upstream contributions, if later authorized, should be separately scoped. Avoid enormous mixed redesign/driver/runtime PRs. Keep default-branch behaviour stable until each feature is ready. Version experimental APIs and document migration/reversion paths.

Each PR records relevant tests actually run and any skipped hardware validation. Use upstream registered CTest suites and current Keel checks; a new test that is never registered does not count. UI PRs include before/after native captures, input method, DPI and accessibility settings. Release gating uses device evidence, not the percentage of checked boxes.

## Unresolved decisions to settle through P0/P1 work

- Reference phone/SKU and carrier after real hardware evidence.
- Which Q25 changes to import and their dependency impact.
- Final gesture thresholds and breakpoints after usability/accessibility testing.
- Provider API availability and background sync constraints.
- Exact native RN/Fabric/Qt render integration and module compatibility matrix.
- Native protocol/provider and exact encryption guarantees for secure messaging/calling.
- Credential provider, authenticator and browser/native-app support on selected devices.
- Companion transport, pairing identity and app continuation format.
- Versioned import/export/restore coverage and supported source formats.
- Final product branding and artwork; preserve upstream license/trademark provenance meanwhile.

These decisions do not block establishing the fork, planning branch, theme specification or adaptive contracts.

## Decided: Work/Personal Spaces belong to 2.1

The earlier open question about first-release profile isolation is resolved. **Both organization and enforcement are deferred**, not only isolation. Track V21-001 (organization/switching) and V21-002 (isolation/management) in the [2.1 appendix](MODERNIZATION_PLAN.md#15-version-21-appendix-workpersonal-spaces). No V2 package may depend on them. Personal scenes and multiple accounts are not a work-profile workaround.

## Commercial product boundary

Nitro Forge is a separate premium product for sale. V2-016 covers compatibility, not incorporation into Marathon. The OS must build, boot and run all core workflows without Forge. Do not vendor premium source, binaries, assets or license credentials into this repository, system images, bundled apps, examples or public CI. Forge-specific package adapters and commercial validation belong in the separately authorized Forge/consuming-app repositories. Generic SDK tests use non-premium fixtures. OS release readiness does not depend on purchasing Forge; commercial app compatibility is tracked separately.
