# Native app polish

This slice builds on `094ed581d93e2ca0f8bca61c3a30c011ee601727` (the
aggregate Hub/Notes branch) and targets `v2`. It applies the native and API
guidance in [ENGINEERING_WORKFLOW.md](ENGINEERING_WORKFLOW.md),
[KEEL_APP_MIGRATION.md](../KEEL_APP_MIGRATION.md) and
[CODING_RULES.md](../CODING_RULES.md). The selected Keel source is the image's
`0df499bf34e02cec7f571853cbf5a4323dc1609e` pin. Its actual `ListItem`,
`BackgroundItem`, `Label`, `Icon` and native `Theme` declarations were inspected.

## Implemented surface

`Marathon.Silica.SummaryListItem` is a native list item with a primary label,
optional secondary detail and optional theme icon. Both labels wrap and the
row grows with their content. Text is always plain text, including network
names and contact fields. Icon geometry is reserved before image loading.
The item inherits Marathon's focus frame, keyboard activation, context menu
and press behavior from `ListItem`.

The public properties are `text`, `description`, `iconSource`, `font` and
`descriptionFont`. The two font aliases keep the standard QML font API;
defaults come from Silica's theme. The parent owns width; content and theme
minimums determine height. An empty description removes its visual line and
an empty icon returns the leading space to the labels. The accessible name
contains the same primary and secondary text shown on screen. Decorative
labels and icons do not create duplicate accessibility stops.

Two production consumers establish the component's scope:

1. **Settings:** categories and search results use the same row. Live service
   values wrap instead of fading at a fixed row height. Search results show
   both their category and current value. Existing navigation, capability
   gating and service ownership remain with Settings.
2. **Phone / People:** each contact shows its name plus formatted number, or
   its email when no number is available. Favorites have a theme star and an
   accessible Favorite description. Contacts sharing a name can be
   distinguished by their visible and spoken number. Call and message menu
   actions are disabled when the contact has no phone number. Selecting the
   row still opens the existing exact contact ID.

These are presentation changes. The component owns no account, contact,
network or operation state. A failed service operation must continue to be
reported by its owning service and app; a row never assumes success from a
click or invents an account label that the provider does not expose.

## Shared visual roles

Shell tokens and app tokens are separate interfaces. Apps consume Silica
`Theme` and Marathon.Silica components; changing `MColors` alone cannot restyle
every app. Use these semantic correspondences when extending the suite:

| Meaning | Shell | Native app |
| --- | --- | --- |
| Primary content | `MColors.textPrimary` | `Theme.primaryColor`, `Theme.fontSizeMedium` |
| Supporting content | `MColors.textSecondary` | `Theme.secondaryColor`, smaller Theme font role |
| Active path and focus | `MColors.accent` | `Theme.highlightColor`, inherited `FocusFrame` |
| Supporting highlighted content | Theme-derived shell role | `Theme.secondaryHighlightColor` |
| Content gutters | `MSpacing` roles | `Theme.horizontalPageMargin` |
| Related content spacing | `MSpacing` roles | `Theme.paddingSmall/Medium/Large` |
| Row minimum and target size | Shell touch-target roles | `Theme.itemSizeSmall/Medium` plus content growth |
| Corners | `MRadius` small-radius ladder | Existing toolkit control geometry; no per-row card wrapper |
| Navigation and motion | `MMotion` roles | Existing Keel/Marathon.Silica page, menu and press behavior |

This mapping expresses roles, not identical numeric values. Respect app DPI,
font scaling, ambience and inherited layout mirroring. Do not import shell
singletons into every app to force matching numbers. Do not add a second
Theme singleton or modify Keel to implement an app style.

## Validation

The existing full CTest suite discovers new tests in `marathon-silica/tests`,
`apps/settings/tests` and `apps/phone/tests`. The required native UI gate also
registers three focused inputs, so these changes cannot pass CI solely on the
optional availability of Keel in a full compositor build:

| Test | Evidence it exercises |
| --- | --- |
| `Qml_silica_SummaryListItem` | Narrow/large-text geometry; reflow to a wider row; complete plain-text identity; optional icon layout; real keyboard and accessibility activation |
| `Qml_settings_RowPresentation` | Long live network values; category plus live search value; search focus through resize; keyboard navigation and preserved main-page row |
| `Qml_phone_PeopleRows` | Same-name contact disambiguation; favorite semantics; email-only contact capabilities; large text followed by opening the exact contact |

These tests load the real native controls and production app QML with the
existing platform-service doubles. They do not establish modem, contacts
server, screen-reader, physical touch, frame pacing or a shipped image.
Record actual command results and native screenshots in the PR. Source
implementation and test registration alone are not runtime evidence.

## Remaining suite rollout

The following are subsequent implementation and qualification targets, not
features completed by this row slice. Reuse a pattern where the interaction
matches; preserve each app's domain behavior and state owner.

| App or surface | Next polish target | Acceptance journey |
| --- | --- | --- |
| Hub | Stable triage context, person/source hierarchy, exact item routing | Open a message, return to the same filter and item, and distinguish notification viewing from provider read state |
| Mail | Adaptive inbox/message workspace and honest sync/send state | Resize while composing; retain draft, cursor, folder and selection; retry only when the outcome permits it |
| Messages | Shared identity hierarchy and reliable delivery/read state | A hidden conversation does not become read; a failed or uncertain send remains traceable |
| People / Phone | Rich contact detail and adaptive list/detail workspace | Keep selected contact and list anchor across resizing; preserve ongoing call/audio state |
| Calendar | Unified local/synced agenda and reminder ownership | A synced event appears in Calendar and Hub with the same source; reminder behavior is verified through suspend |
| Notes / Tasks | Durable edit acknowledgement and source references | A failed write keeps the draft; restart recovery is claimed only after a storage implementation and qualification |
| Settings | Adaptive category/detail workspace and fallible-control feedback | Resize a detail page without losing navigation; a failed setting change shows the actual retained value |
| Browser | Tab overview, address identity and private-mode clarity | Return from an external link to the intended tab; private state remains distinguishable at narrow and wide sizes |
| Camera | Readiness, capture feedback and Gallery transition | Capture success/failure is unambiguous and a completed capture appears in Gallery once |
| Gallery | Stable thumbnails, selection, deletion recovery and sharing | Select across scrolling/resizing, undo a deletion, and share the exact selected media |
| Music | Player layout and one coherent playback state | App, cover and system controls agree; resizing keeps primary controls reachable and queue position stable |
| Maps | Maneuver readability and resumable navigation | Reopen an active route with the correct next maneuver; map/route panes fit the available width |
| Clock | Next-alarm and ongoing-timer clarity | Timer state survives navigation; suspend/restart/timezone behavior is verified on the target platform |
| Calculator | Numeric alignment and adaptive history | Long expressions and results remain readable; hardware input and touch yield the same expression |
| Terminal | Session state, selection and input parity | Resize while selecting text; a closed or failed session has an explicit state; modifier keys are predictable |
| Pilot | Action previews and accountable outcomes | Review a consequential action, cancel before dispatch, and return to the exact resulting app record |
| Reef | Source/capability identity and install progress | Supported installs expose progress and errors; unavailable catalogue actions stay accurately represented |

The 2.0 suite remains native Qt/QML, Keel and Marathon.Silica. Premium Nitro
Forge/NYC-Tron and React Native QNX products stay independent installable app
targets. Work/Personal Spaces and organizational features remain in 2.1.
