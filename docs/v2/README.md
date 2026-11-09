# Marathon v2 — native BB10 × Sailfish successor

Planning baseline: November 7, 2026; approved scope revised November 9, 2026. Status: approved implementation programme, with individual work packages still planned until their evidence is recorded. These documents implement no runtime functionality.

## Product decision

Build a native MarathonOS that feels like BB10 and Sailfish had a baby: communication-first, fluid, personal, tactile and productive. Preserve Marathon's Qt 6/QML compositor, Keel/Silica foundation, ambience system and native app ecosystem. Support phones, tablets, foldables, dual screens and external displays through adaptive native layouts. There is **no browser version of the OS** and no WebView shell. An ordinary browser application remains part of a useful OS.

The product should make it unusually easy to read, reply, capture, search and resume. A beautiful demonstrator is not a qualified daily-driver release.

## Plan index

- [Modernization programme](MODERNIZATION_PLAN.md): features, architecture, dependencies, delivery phases and release gates.
- [UI and interaction specification](UI_SPEC.md): visual language, screen inventory, adaptive rules and motion.
- [Implementation backlog](BACKLOG.md): ordered work packages and acceptance evidence.
- [Engineering workflow and skills](ENGINEERING_WORKFLOW.md): native/API guidance, source versions, agent responsibilities and validation.
- [V1 gap audit and upstream intake](V1_GAP_AUDIT.md): complete open-item inventory, current-versus-inherited source findings, dated Reddit feedback and repair priorities.
- [Remediation queue and programme tracker](REMEDIATION_QUEUE.md): eight ready-to-file repair tickets, detailed acceptance and all 37 packages linked to the current draft PRs; the issue board is disabled.

## Approved 2.0 scope

The November 9 decision keeps every approved successor capability in the **2.0 programme** except Work/Personal Spaces. The original V2-001–029 packages remain planned; V2-030–037 make the additional work explicit. Phases sequence implementation within 2.0; they do not silently move approved capabilities into a later release or establish that they work today.

| Programme | Scope |
|---|---|
| 2.0 | Existing Hub/Peek, live covers, native task invocation, adaptive displays, accessibility, reliable services and installable app ecosystem |
| 2.0 additions | Paired-device continuity; credentials/passkeys; migration/export/restore; Remember-style tasks and attachment provenance; secure messaging, voice and video; personal Travel/Bedside/Focus scenes; keyboard Instant Actions; meeting preparation and follow-up |
| 2.1 only | All Work/Personal Spaces: organizational views, account assignment to spaces, work mode, profile switching, separate work storage/credentials, managed profiles and security isolation |

Ordinary multiple accounts within the user's personal Hub remain in 2.0. Personal scenes change presentation and interruption preferences; they do not create another identity, account partition or security boundary. See the explicit [2.1 appendix](MODERNIZATION_PLAN.md#15-version-21-appendix-workpersonal-spaces) before adding any work-profile interface.

## Repository and branch policy

- Upstream: https://github.com/patrickjquinn/Marathon-Shell
- Fork: `mikevocalz/Marathon-Shell`; development branch: `v2`.
- Historical base: upstream `main`, verified at `c2c1b2fe32aeaa51edf75a45045cbfbbc08c4ac5` on November 7, 2026. On November 9, upstream `main` is `567f1faa8bfdf31611dd401134c293daa160221c`, 548 commits ahead of that base; see the [intake audit](V1_GAP_AUDIT.md).
- Current upstream `main` and `release/q25-v1` are integration sources to evaluate. Review their fixes and dependency changes before importing them; an old open camera PR or Reddit report does not establish current source behavior.
- Preserve upstream history, attribution and existing license notices. Retain `main` as the upstream tracking baseline; submit small feature branches into `v2`.
- Do not force-push shared branches. Record each upstream integration SHA and its regression results.
- The first commit is documentation only. This plan does not bump the package version, publish a release, flash a device, change signing keys or announce upstream endorsement.
- The fork and `v2` branch were verified through GitHub on November 7, 2026. This documentation commit establishes the planning baseline.

## Decisions fixed by this brief

1. Qt/QML stays the native shell; Keel stays the native application foundation.
2. BB10 contributes Peek/Flow, Hub, useful active frames, keyboard productivity and app-to-app continuity.
3. Sailfish contributes ambience, expressive typography, fluid manipulation, pulley menus and live covers.
4. Modernization adds accessibility, discoverability, adaptive panes, coherent motion and reliable native services.
5. Tablet/foldable layout contracts start in the foundation phase. Shipping a particular device still requires a separate hardware port and qualification.
6. Nitro Forge is the owner's separate premium commercial component product. Marathon provides generic native runtime/SDK support so licensed developers can install selected Forge packages in their own apps with minimal setup. Forge components, engines, assets and licensing code are not bundled, vendored or dependencies of the OS, shell or bundled system apps. NYC-Tron application adapters remain separate from system controls. React Native Marathon and QNX are separate platform targets.
7. Retain Deckard as an optional compatibility lane; first-party features and our RN applications must not depend on Android emulation.
8. Normal navigation, messaging, search and settings remain usable without AI.
9. All Work/Personal Spaces are deferred to 2.1, including lightweight organizational views. They are not a 2.0 dependency or release gate.
10. Implementation uses relevant native and API skills, source/version checks, delegated work and independent review. Keep the OS's Qt/Keel architecture and validate its contracts with non-premium fixtures.

## Evidence and limitations

The existing research, *MarathonOS as a modern BB10 successor* (November 6, 2026), supplies the detailed audit and 34-source register. This plan incorporates it, then adds the explicit native-only scope and first-class adaptive UI decision.

Rechecked upstream README, tree, main SHA, contribution guide, Keel migration and Sailfish keep/drop document. No AGENTS.md was present in the returned main tree. No build or hardware run was performed for this planning change. Existing capability descriptions below are source/documentation evidence, not independently reproduced readiness claims.

The November 9 scope review inspected this fork's `v2` at `bc39c23cac18221df21e410a45f8cc72d0ae9824` and the existing app, Rust service, portal and keyboard seams. Detailed source paths and first implementable slices are in the backlog. Existing Notes checkbox tasks, mail/DAV credential storage and Bluetooth pairing must not be relabeled as the complete task, passkey or companion features.

The old CONTRIBUTING guide still refers to MarathonUI; the current README and Keel migration document explicitly supersede that API. Use the Keel imports and Marathon.Silica extension strategy. Any proposed accessible dialog controls or adaptive command surfaces that differ from current Keel interaction guidance need an explicit v2 design decision and regression review, not an undocumented toolkit fork.
