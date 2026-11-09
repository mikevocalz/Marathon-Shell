# Googlebook feature reference for Marathon 2.0

Reviewed: November 9, 2026. Status: researched interaction reference and proposed native implementation priorities. This document implements no runtime feature.

## Product decision

The user likes Googlebook's modern features and prefers small rounded corners. Carry that preference into Marathon's existing BB10/Sailfish direction: useful communication, continuity, live covers, native gestures, compact information and deliberate motion. Googlebook is a reference for behavior and adaptive organization. Qt/QML, Keel and Marathon.Silica remain the system foundation.

Use restrained rectangular surfaces with small corner radii. Dense lists should rely on alignment, spacing and separators where those already provide grouping. Preserve meaningful circles, the existing navigation indicator and the leaf-shaped application icons. A smaller visible corner does not mean a smaller touch target.

All Work/Personal Spaces remain **2.1**, including organizational-only views, account assignment and profile switching. Ordinary personal accounts and personal task organization remain distinct. The current approved scope and package mapping are recorded in [the integrated programme](https://github.com/mikevocalz/Marathon-Shell/blob/5b0ab10ca746639939572000f0f5e1b414bc4585/docs/v2/MODERNIZATION_PLAN.md). This reference creates no new release dependency. Generated widget execution and virtual desktops are research candidates, not implicit additions to the approved 2.0 release gate.

This document uses the November 9 approved scope at the linked integrated revision. That decision supersedes older local scope wording on this documentation draft's `v2` base, whose programme and backlog predate the complete 37-package revision.

## Shape rules

The inspected [shell radius source](https://github.com/mikevocalz/Marathon-Shell/blob/5b0ab10ca746639939572000f0f5e1b414bc4585/shell/qml/theme/MRadius.qml) already exports the following values, scaled by `Constants.scaleFactor` and rounded. These are logical design values, not a statement about physical pixels on every device.

| Existing role | Base value | Proposed use |
| --- | ---: | --- |
| `none` | 0 | Flat content rows and continuous panes |
| `sm` | 2 | Default for ordinary small bounded shell surfaces |
| `md` | 4 | Small cards, fields or menus when their native control supports this treatment |
| `lg` | 6 | Restrained rounding for larger separated surfaces |
| `xl` | 8 | Selected top-level sheets/panels after visual review |
| `squircle` | 14 | App-icon-specific role; retain the existing icon assets and ownership |

The user's `rounded-sm` preference is a shape decision, not a Tailwind dependency. Do not add a parallel radius scale, apply an unverified `MRadius.pill` property, or change every `radius: width / 2` control. The current file has no `pill` export. Quick Settings circles and avatars have a different purpose from container corners.

`MRadius` belongs to the shell and imports `MarathonOS.Shell`. Sandboxed apps must not gain a shell dependency merely to share styling. Extend the approved public semantic theme contract and native `Marathon.Silica` wrappers deliberately; preserve upstream Keel. Ordinary controls keep their native focus, pressed, disabled and loading behavior. Keep the [UI specification's](UI_SPEC.md) touch, large-text and contrast review targets.

## Verified Googlebook behavior and Marathon interpretation

The Google column paraphrases primary documentation checked on the review date. The Marathon column contains design recommendations, not claims that these features are implemented or that Google's services are available to Marathon.

| Reference behavior | Proposed Marathon experience | Source |
| --- | --- | --- |
| Adaptive apps use available window space, useful adjacent panes and precision input | Notes, Mail, Hub and Settings retain the same selected item while changing between a focused page and list/detail layout. Add a supporting pane only when its content earns the space. | [G1] |
| Window controls provide minimize, maximize, restore/full screen and side-by-side arrangements | Supply discoverable native window controls and shortcuts on desktop/external-display layouts. Retain phone gestures and correct focus/modality. | [G2] |
| Taskbar supports pins, running indicators and groups multiple windows of one app | A compact taskbar can complement live covers on wide layouts. App identity, window identity and document identity stay separate. | [G3] |
| Quick Insert supplies clipboard, contacts, emoji, local images and writing tools at the editor | Share a native insertion surface across Notes, Mail and Messages. Start with deterministic content and correct focus ownership. Arbitrary attachments use a real file picker and scoped grants. | [G4] |
| Files supplies locations, list/grid views, metadata, filters, Open With and archive browsing | Build the personal Files application on native foundations, with previews, explicit locations and recoverable asynchronous operations. | [G5] |
| File collections group related files and can be pinned or removed | Start with explicit personal collections and saved searches. Optional suggestions need a visible reason, source identity and unavailable-file behavior. | [G6] |
| Magic Pointer accepts deliberately selected screen content through visible controls, shortcuts or a configurable gesture | Offer one contextual action surface: Copy, Save to Notes, Create task, supported Translate, or Ask Pilot. Show selected content and available actions; retain the draft when the surface is collapsed. | [G7] |
| Rambler turns speech into structured text and exposes undo/full-transcript choices | Capture a transcript in Notes and offer a separate editable cleanup. Preserve original text on failure and let the user review inferred tasks before creating them. | [G8] |
| Custom widgets have preview, refinement and compact/expanded presentations | Evolve meaningful live covers and typed agenda/task/weather/media summaries. A natural-language configuration proposal can select approved templates; it need not execute generated QML. | [G9] |
| Continue On resumes a relevant phone activity on the receiving device | First preserve state across layouts on one device. Paired-device continuation then needs a trusted, versioned contract for supported records and view state. | [G10], [G11] |

### Boundaries that affect design

Google's current Quick Insert documentation explicitly excludes arbitrary local files; it supports local images. Its writing tools require connectivity. Rambler also requires an internet connection for all of its features. A general description of on-device intelligence does not establish offline operation for every feature. [G4], [G8]

Googlebook continuity depends on compatible Android 17+ phones, shared Google-account state, Wi-Fi/Bluetooth and network requirements. These describe Google's ecosystem. Marathon needs its own pairing, revocation, app capability and conflict behavior. Similar UI does not supply those services. [G11]

File collections require Google's AI for Files setting and have language/data availability conditions. In Marathon, explicit collections can work independently of optional suggestions. A suggestion must not silently move or duplicate a user's files. [G6]

The references establish documented behavior, not performance, accessibility, compatibility or visual measurements on a Marathon device. No Googlebook hardware was operated during this research.

## How the native apps should adapt

These are proposed Marathon layouts. Pane minimums come from content, translations and text scale; avoid device-name checks and stretching one phone column across a large display.

| Native area | Compact presentation | When enough space is available |
| --- | --- | --- |
| Notes | Note list or focused editor, with visible Notes/Tasks/Folders destinations | Navigation/list beside editor; selected note, cursor and unsaved draft survive resizing |
| Hub and Mail | Readable conversation list with focused detail/reply | List beside conversation; optional attachment or task context without losing the reply draft |
| Calendar | Agenda or focused date/event view | Calendar/agenda beside event detail and relevant personal tasks |
| Files | Locations/list followed by focused preview or picker | Navigation, file list and useful preview; operations remain visible and cancellable |
| Settings | Search and hierarchical pages | Navigation and settings detail with retained selection and keyboard focus |

Provide touch, keyboard and pointer paths for core actions. Check context menus, hover, shortcuts, wheel/trackpad direction, text selection, drag/drop and IME composition as real interactions. Pointer availability alone must not shrink touch targets. Foldable safe regions and display unplugging must preserve reachable content and focused work.

## Current native foundations and gaps

Source inspection used integrated PR #9 at [5b0ab10c](https://github.com/mikevocalz/Marathon-Shell/commit/5b0ab10ca746639939572000f0f5e1b414bc4585), not an assumption that every proposed package is complete.

| Foundation | Observed source | Consequence |
| --- | --- | --- |
| Search | [Rust search](https://github.com/mikevocalz/Marathon-Shell/blob/5b0ab10ca746639939572000f0f5e1b414bc4585/crates/marathon-shell-native/src/search.rs) indexes installed apps and their deep links; [the native search surface](https://github.com/mikevocalz/Marathon-Shell/blob/5b0ab10ca746639939572000f0f5e1b414bc4585/shell/qml/components/MarathonSearch.qml) exists | Extend the actual search contract for new sources; do not present it as existing universal content search |
| Clipboard | [Rust clipboard service](https://github.com/mikevocalz/Marathon-Shell/blob/5b0ab10ca746639939572000f0f5e1b414bc4585/crates/marathon-shell-native/src/clipboard.rs) already keeps persisted text history | Reuse its foundation; rich content, protected-field handling and target-owned insertion need their own contracts |
| Files | [File picker](https://github.com/mikevocalz/Marathon-Shell/blob/5b0ab10ca746639939572000f0f5e1b414bc4585/shell/qml/components/FilePickerSheet.qml) and [Rust file model](https://github.com/mikevocalz/Marathon-Shell/blob/5b0ab10ca746639939572000f0f5e1b414bc4585/crates/marathon-shell-native/src/file_model.rs) exist; inspected scans are synchronous | A full Files app needs owned asynchronous listing/search/mutations, progress, cancellation and conflicts |
| Notes capture | [Action schema](https://github.com/mikevocalz/Marathon-Shell/blob/5b0ab10ca746639939572000f0f5e1b414bc4585/apps/notes/keel-actions.json) exports note/task actions | Reuse the existing action transport and validate results; exact returned-ID navigation and durability remain explicit work |
| Pilot | [Pilot README](https://github.com/mikevocalz/Marathon-Shell/blob/5b0ab10ca746639939572000f0f5e1b414bc4585/apps/pilot/README.md) describes native context/actions and local/direct modes | Extend deliberate selected context rather than claim universal screen understanding; Marathon does not build the inherited Shipwright speech executables |
| Display/window foundation | The [programme](https://github.com/mikevocalz/Marathon-Shell/blob/5b0ab10ca746639939572000f0f5e1b414bc4585/docs/v2/MODERNIZATION_PLAN.md) already plans native window policy, external displays and adaptive panes | Screen metrics alone do not establish completed freeform windowing, hinge support or virtual desktops |

## Native/API delivery mapping

These references refine existing packages; they do not mark packages complete or assign invented APIs. The package IDs below refer to the [approved integrated backlog](https://github.com/mikevocalz/Marathon-Shell/blob/5b0ab10ca746639939572000f0f5e1b414bc4585/docs/v2/BACKLOG.md).

| Sequence | Work | Existing packages | Acceptance evidence |
| --- | --- | --- | --- |
| 1 | Small-radius native role policy, adaptive app panes and input | V2-002, 003, 006, 013, 021 | Real native captures and interaction recording; long text, text scaling, resize/fold, retained draft/selection/focus |
| 2 | Window controls, app/window identity, taskbar and live covers | V2-005, 006, 018, 019, 020 | Minimize/close/restore differ correctly; modality, multiple instances, mixed DPI and unplug recovery |
| 3 | Insertion/actions, personal Files and task capture | V2-011, 012, 021, 033, 036 | Correct target after focus changes, IME safety, scoped attachments, cancelled operations, conflict/recovery and stale-reply rejection |
| 4 | Personal-device transfer and continuation | V2-009, 011, 030, 032 | Verified pairing, stable request identity through reconnect, app capability checks, revoke, conflicts and incompatible-state handling |
| 5 | Optional contextual assistance and speech capture | V2-012, 022, 023, 033, 036 | Explicit selected context and microphone state, visible local/remote availability, preserved transcript/draft, reviewed action outcomes |
| Ongoing | Glanceable covers and typed summaries | V2-005, 010, 025, 028 | Meaningful states, unavailable providers, lock privacy and hidden/background work budgets |

Before adding methods, review concrete journeys with the existing native/API guidance:

1. **Insert into Mail:** open the chooser from a particular draft, select a granted image, then change focus before the result arrives. The result must return to the owned request or be rejected; it must not insert into an unrelated window. Cancellation restores the caller, and a revoked grant remains an understandable failure.
2. **Continue a Notes task:** start from a stable record, pair explicitly, interrupt the transfer, reconnect, then encounter an edited or deleted destination record. Keep identity and conflict choices; retry must not silently create a duplicate. Unpairing revokes future access.
3. **Act on selected Hub content:** select a specific item, request a suggested task or reply, then dismiss or change the underlying source. Preserve the draft and reject stale context. A suggestion is not an already-created task or a sent message; outbound/destructive actions remain deliberate.

Expose cheap cached observations synchronously and owned I/O asynchronously. Distinguish unavailable capability, admitted request, completed operation, failure and uncertain outcome. Do not claim that cancelling a local wait reverses a remote action. Reuse supported Keel actions and native grants; avoid a second command bus. See [the native/API workflow](https://github.com/mikevocalz/Marathon-Shell/blob/5b0ab10ca746639939572000f0f5e1b414bc4585/docs/v2/ENGINEERING_WORKFLOW.md).

Local virtual desktops group windows within one personal session; they do not establish separate identities or security boundaries. They are an optional window-management research candidate here. They must not introduce Work/Personal organization into 2.0. Nitro Forge and NYC-Tron remain separate application products, and RN/QNX remains a separate native target. Everyday navigation, search and editing remain usable without AI.

## Primary source register

All links were read on November 9, 2026. Help articles do not consistently expose a publication date; retrieval freshness is not presented as a release date.

- **G1:** [Build adaptive apps for Googlebook](https://developer.android.com/develop/adaptive-apps/guides/googlebook/overview), Android Developers; last updated October 3, 2026.
- **G2:** [Multitask with app windows](https://support.google.com/googlebook/answer/18265149), Googlebook Help.
- **G3:** [Customize your Taskbar](https://support.google.com/googlebook/answer/16976881), Googlebook Help.
- **G4:** [Use Quick Insert](https://support.google.com/googlebook/answer/18322725), Googlebook Help.
- **G5:** [Find, save, and manage files](https://support.google.com/googlebook/answer/16928981), Googlebook Help.
- **G6:** [Use File collections](https://support.google.com/googlebook/answer/17033606), Googlebook Help.
- **G7:** [Get answers and insights with Magic Pointer](https://support.google.com/googlebook/answer/18290162), Googlebook Help.
- **G8:** [Use Rambler](https://support.google.com/googlebook/answer/18429213), Googlebook Help.
- **G9:** [Create and edit custom AI widgets](https://support.google.com/googlebook/answer/18399586), Googlebook Help.
- **G10:** [Support cross-device continuity on Googlebook](https://developer.android.com/develop/adaptive-apps/guides/googlebook/cross-device-continuity), Android Developers; last updated October 8, 2026.
- **G11:** [Use cross-device services](https://support.google.com/googlebook/answer/16945063), Googlebook Help.

## Review record

Applied the existing native/API workflow, pinned Margelo API-design guidance, native theme/source review and independent research/source-review subagents. Google behavior and Marathon proposals remain separated. Documentation validation covers local references, source mappings, scope consistency and `git diff --check`. No native build, runtime feature, screenshot redesign, Googlebook-device test or Marathon-device qualification is claimed by this documentation change.

[G1]: https://developer.android.com/develop/adaptive-apps/guides/googlebook/overview
[G2]: https://support.google.com/googlebook/answer/18265149
[G3]: https://support.google.com/googlebook/answer/16976881
[G4]: https://support.google.com/googlebook/answer/18322725
[G5]: https://support.google.com/googlebook/answer/16928981
[G6]: https://support.google.com/googlebook/answer/17033606
[G7]: https://support.google.com/googlebook/answer/18290162
[G8]: https://support.google.com/googlebook/answer/18429213
[G9]: https://support.google.com/googlebook/answer/18399586
[G10]: https://developer.android.com/develop/adaptive-apps/guides/googlebook/cross-device-continuity
[G11]: https://support.google.com/googlebook/answer/16945063
