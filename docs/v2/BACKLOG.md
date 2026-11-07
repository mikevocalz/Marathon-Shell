# v2 implementation backlog

All entries are **planned**, not completed. IDs are planning identifiers, not GitHub issue numbers. Each implementation PR should name its ID, dependencies, changed behaviour and validation evidence. Role labels identify needed expertise rather than assigned people.

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
| V2-009 | P2 / services | Drafts, offline queue and sync recovery | 008 | Restart/reconnect sends once; failure and retry preserve draft |
| V2-010 | P2 / shell + SDK | Activity schema and privacy-aware covers | 003,007 | Cover/strip/lock state consistency; immediate privacy redaction |
| V2-011 | P2 / SDK | Typed actions, narrow file grants and result return | 001,006 | Cancel/timeout/permission-revocation/caller-death handling |
| V2-012 | P2 / input | Keyboard shortcuts, local search, IME and trackpad | 006,011 | Multilingual composition, shortcut collisions and restored focus |
| V2-013 | P2 / apps | Mail/Messages/Calendar/Notes and attachment UI | 005,008,009,011 | Complete communication journey on phone/tablet with offline states |
| V2-014 | P3 / runtime | Native RN Marathon host and service capability inventory | 001,002,006 | Actual native window, Fabric/input/lifecycle proof; no Android dependency |
| V2-015 | P3 / UI runtime | NYC-Tron Qt adapter and generated token parity | 003,014 | Native menus, text, focus, accessibility and adaptive panes |
| V2-016 | P3 / app compatibility | Generic native package integration; separate licensed Forge consuming-app validation | 011,015 | Install/import/build selected packages without OS patches; public OS tests use non-premium fixtures; premium validation stays in the authorized Forge/app project |
| V2-017 | P3 / SDK + packaging | Signed RN sample and reproducible developer template | 014,015 | Non-premium sample: clean install, update, permission change, restart and uninstall; no Forge license or package required |
| V2-018 | P4 / compositor | Split-screen, task pairs and window constraints | 002,004,010 | Pair restore and resize retain work without focus stealing |
| V2-019 | P4 / compositor | External displays, mixed DPI, snap and hot-plug | 018 | Unplug recovers all windows onto a reachable display |
| V2-020 | P4 / input + portals | Native drag/drop, pointer and pen capabilities | 011,018 | Scoped file transfers, keyboard equivalents, verified pen properties |
| V2-021 | P2–P5 / apps | Remaining core apps, Focus, bedside, onboarding and settings | 003,006,010 | Per-app device/adaptive/accessibility matrix; alarms survive quiet modes |
| V2-022 | P3–P5 / Pilot | Selected-context assistance and verified action execution | 011,013 | Explicit outbound confirmation; hostile content cannot grant actions |
| V2-023 | P0–P5 / security | IPC/secret access, sandbox and warm-pool audit/hardening | 001 | Confinement before app execution; revocation and boundary tests |
| V2-024 | P0–P5 / platform | Encryption status, backup/restore and boot-chain assessment | 001,023 | Failed enrollment never reports protected; recoverability evidence |
| V2-025 | P0–P5 / device QA | Telephony, suspend, audio, camera, sensors and power | 001 | Per-SKU/carrier reports; wake/recovery and overnight drain measurements |
| V2-026 | P0–P5 / release | Signed OTA, migration and recovery qualification | 001,024 | Bad signature/full disk/power interruption/failed boot outcomes |
| V2-027 | P3–P5 / ecosystem | Reef installs, app trust metadata and Deckard parity | 010,011,023 | Accurate compatibility and real install/update/uninstall, resize and push |
| V2-028 | All / performance QA | Frame, latency, memory and energy regression harness | 001 | Reproducible measurements; no averages hiding missed deadlines |
| V2-029 | P5 / release QA | Device-specific release readiness and docs | All release-scoped items | Published known limits, reproducible image and no critical blockers |

## Initial PR sequence

1. `docs(v2): define native successor modernization plan` — these documents only.
2. `docs(v2): record reproducible platform and device baseline` — V2-001, including exact dependency/image revisions and failures.
3. `feat(layout): expose adaptive display regions` — V2-002 contract and fixtures.
4. `feat(theme): add semantic v2 theme roles` — V2-003, preserving existing imports and compatibility.
5. `feat(shell): preserve task state during hub peek` — V2-004 with interruption tests.
6. `feat(shell): introduce adaptive home and cover layouts` — reviewed V2-005 slice.
7. Hub and activity services follow after contracts and privacy tests; RN proof follows after lifecycle interfaces are stable.

Security/accessibility findings that block early work should be fixed alongside these slices. Do not wait until the end to discover the shell cannot safely expose an app activity.

## Integration rules

Create `feat/v2-*` or `fix/v2-*` branches from `v2`; merge via reviewed PRs into `v2`. Upstream contributions, if later authorized, should be separately scoped. Avoid enormous mixed redesign/driver/runtime PRs. Keep default-branch behaviour stable until each feature is ready. Version experimental APIs and document migration/reversion paths.

Each PR records relevant tests actually run and any skipped hardware validation. Use upstream registered CTest suites and current Keel checks; a new test that is never registered does not count. UI PRs include before/after native captures, input method, DPI and accessibility settings. Release gating uses device evidence, not the percentage of checked boxes.

## Unresolved decisions to settle through P0/P1 work

- Reference phone/SKU and carrier after real hardware evidence.
- Which Q25 changes to import and their dependency impact.
- Final gesture thresholds and breakpoints after usability/accessibility testing.
- Provider API availability and background sync constraints.
- Exact native RN/Fabric/Qt render integration and module compatibility matrix.
- Whether profile isolation is in the first qualified release or a later milestone.
- Final product branding and artwork; preserve upstream license/trademark provenance meanwhile.

These decisions do not block establishing the fork, planning branch, theme specification or adaptive contracts.

## Commercial product boundary

Nitro Forge is a separate premium product for sale. V2-016 covers compatibility, not incorporation into Marathon. The OS must build, boot and run all core workflows without Forge. Do not vendor premium source, binaries, assets or license credentials into this repository, system images, bundled apps, examples or public CI. Forge-specific package adapters and commercial validation belong in the separately authorized Forge/consuming-app repositories. Generic SDK tests use non-premium fixtures. OS release readiness does not depend on purchasing Forge; commercial app compatibility is tracked separately.
