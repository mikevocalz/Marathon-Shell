# Native UI consistency

Status: shared implementation and review contract; individual screens still need
native review. Source inspected: `094ed581d93e2ca0f8bca61c3a30c011ee601727`.
Scope: shell, Marathon.Silica, 14 standard apps, Pilot and Reef. The template
is source-checked; the diagnostic app participates in the journey inventory.

This applies the user's Web Designer Pro pack to the existing
[2.0 UI direction](UI_SPEC.md). Read the
[native adaptation brief](WEB_DESIGNER_PRO_NATIVE_BRIEF.md) before using that
pack. This is an evolution of Marathon's BB10/Sailfish character: content,
communication density, ambience, small corners and continuity between tasks.

## One product, shared decisions

A person should recognize the same control, focus treatment, spacing rhythm,
menu behavior and status language in every app. Each app retains a layout
appropriate to its task: a camera viewfinder, a conversation and an app
catalogue should share controls without acquiring the same page structure.

Resolve decisions in this order: the user's approved scope; actual exported
native APIs; the current 2.0 UI specification and this implementation contract;
older design documents; reference-pack defaults. The legacy
`docs/UI_DESIGN_SYSTEM.md` contains historical examples that differ from the
current token source. Inspect the implementation before copying a symbol or
value. Keep Work/Personal Spaces in 2.1.

## Source ownership

| Design decision | Native owner / API in this source | Rule for consumers |
| --- | --- | --- |
| App text, accent and selected states | Keel `Sailfish.Silica.Theme`: `primaryColor`, `secondaryColor`, `highlightColor`, `secondaryHighlightColor` | Inherit the current theme. Account identity has a text label; hue cannot carry identity or state alone. |
| Shell colors | `shell/qml/theme/MColors.qml` | Use semantic aliases. Its text/accent roles already read Silica Theme; do not add a second palette in an app. |
| Type | App `Theme.fontFamily` and `fontSize*`; shell `MTypography.qml` | Shell body size derives from `Theme.fontSizeMedium`. Keep user scaling. Code/emoji font exceptions need an actual content requirement. |
| App spacing | `Theme.padding*`, `horizontalPageMargin`, native control geometry | Use the toolkit's density. A multiple such as two section gaps is deliberate composition, not a new local spacing scale. |
| Shell spacing | `MSpacing.qml`: 4/8/16/24/32/40 base units, scaled in the owner | Consumers select roles; do not repeat these numbers throughout pages. |
| Shell corners | `MRadius.qml`: none/sm/md/lg/xl = 0/2/4/6/8 before scale; squircle = 14 for app icons | Preserve small corners. Circular media/avatars and icon masks are object geometry, with a stated reason. A row does not need a card around it. |
| Native control corners | Keel control plus the Marathon.Silica wrapper | Change a shared control when a shape must change across apps. Do not patch individual buttons into a competing family. |
| Shell motion | `MMotion.durationFor`, `easingFor`, `easingCurveFor`, `gate` | Pick by action role; use the existing reduced-motion path. Native app transitions stay with Keel unless a shared wrapper needs a verified extension. |
| Focus, activation and scrolling | `marathon-silica/Marathon/Silica` wrappers | Preserve keyboard activation, visible FocusFrame, accessible role/name and consistent fling/press behavior. |
| Icons | `image://theme/…` and the repository icon mapping | Use one vocabulary, fixed icon geometry and meaningful selected states. Name icon-only actions for assistive technology. |
| Navigation and menus | Marathon.Silica `ApplicationWindow`, `Page`, `Dialog`, `ContextMenu`, pulley menus | Keep system back/menu dismissal and the existing page stack. Store task state independently of the current layout. |

The installed theme is the runtime authority. Light and high-contrast
presentations in the v2 specification are review targets; this document does
not announce a completed light theme or a new theme-schema generator.

For ordinary app pages, import the wrappers after Silica:

```qml
import Sailfish.Silica 1.0
import Marathon.Silica 1.0
```

A wrapper may deliberately import Silica under an alias to inherit its base
control. A new Qt Quick Controls family requires an explicit design/architecture
decision; a convenient import is not that decision.

## Shared component choices

| UI need | Starting point | Acceptance detail |
| --- | --- | --- |
| One item with a primary and secondary line | `SummaryListItem` proposed in [PR #17](https://github.com/mikevocalz/Marathon-Shell/pull/17); otherwise the existing `ListItem` | Long identity/status text grows within the row. The accessible name includes the distinguishing secondary value. Use the new component only after its dependency lands. |
| Primary/secondary action | `Button`, `SecondaryButton`, `IconButton` | Same pressed/focus/disabled behavior; label describes the action. Explain why an important action is unavailable. |
| Search/filter/selection | `SearchField`, `FilterChip`, existing tab controls | Preserve query and selection on back/resume/resize. Distinguish no data from no matches. |
| Data entry | `TextField`, `TextArea`, `ComboBox`, `Slider`, switches | Keep input and cursor on recoverable errors; associate labels and feedback with the field. |
| Empty collection | Native `ViewPlaceholder` and the page's real action | State what will appear and how to make it appear. Permission denial is a separate state. |
| Loading/refresh | Existing native busy/progress control near the affected region | Retain usable content; separate cached data from current sync status. Cancel appears only if the operation can actually cancel. |
| Item operations | Native context menu and visible discoverable alternatives | One clear primary action; secondary actions retain focus and exact item identity. |
| Destruction | Existing remorse/undo or an appropriate native confirmation | State the affected item and scope. Undo must restore the actual operation, not only its visual row. |

Names, subjects, filenames, account labels and provider text are plain text
unless a deliberately reviewed renderer owns rich content. A Mail body renderer
is a distinct content boundary. Do not let a label's automatic rich-text
detection change a sender or event title into markup.

## Every state has a design

Review these states on each changed core journey, recording genuine
not-applicable cases:

| State | Required behavior |
| --- | --- |
| First run / empty | Clear purpose and a reachable next action |
| Filtered empty | Current query/filter remains visible; clearing it is easy |
| Loading / partial | Stable geometry and an honest indication of what is available |
| Offline / stale | Retain usable cached content and distinguish its age/source from live success |
| Recoverable failure | Say what failed, what remains saved, and how to retry |
| Permission denied or revoked | Explain the capability; clear content whose access was revoked, including open detail copies |
| Long content / large text | No clipped identity or inaccessible actions; deliberate elision has a way to reveal the full value |
| Selection / editing | Clear scope, cancellation and preserved input |
| Destructive / completed | Actual outcome and usable undo or recovery |
| Hidden / resumed | Stable query, selection, scroll, draft and focus; no unnecessary hidden animation or refresh loop |

A shared look is insufficient if the same action means something different in
two apps. Hub attention state and provider message read state stay distinct.
Account cache availability and upstream synchronization also stay distinct.

## Native review matrix

Use representative logical content sizes, recording the actual window size,
device scale and text setting for each capture. These are test profiles, not
assertions that every device maps physical pixels identically.

| Profile | Representative content region | What must survive |
| --- | --- | --- |
| Narrow phone | 320 × 640 | Long labels, visible actions, keyboard dismissal and scroll reachability |
| Tall phone | 390 × 844 | Touch navigation, menus, status/chrome safe areas and return position |
| Square keyboard device | 720 × 720 | Short height, hardware keyboard, focus and menus without hover |
| Landscape / tablet | 1024 × 768 | Useful pane composition, unchanged selection/draft and no stretched controls |
| Wide window | 1440 × 900 | Bounded reading measure, sensible panels and keyboard/pointer parity |

Pair the core profile with normal and large text; exercise the same journey
with reduced motion. Test actual supported ambiences, plus contrast and
reduced-transparency targets where implemented. Include translated long strings,
RTL text when supported, duplicate names, a long unbroken address, empty data
and failure. Use synthetic contacts/messages in captures.

For an adaptive transition, move narrow → wide → narrow while editing and while
an item is selected. Verify identity, cursor, scroll and focus after each
transition. Layout changes must not restart a task.

A source check cannot measure contrast, touch latency, frame pacing, screen
reader order or provider correctness. Native screenshots, a short interaction
recording and the relevant automated tests provide different evidence. Record
blocked checks explicitly.

## Across the native app inventory

The machine-readable [inventory](../../tools/native-ui-consistency/policy.json)
contains one concrete review journey for every app directory. Product entries
start at `native-review-needed`; inventory inclusion is not qualification.

| Wave | Areas | Shared improvement to review |
| --- | --- | --- |
| Foundations | Shell, shared controls, template | Theme roles, small corners, focus/activation, menu dismissal, motion and scaling |
| Communication | Hub, Mail, Messages, Phone/People, Calendar, Notes | Exact item/account identity, readable rows, retained drafts/context and truthful status |
| System settings | Settings, permission and account pages | Live values, search context, consistent forms and recoverable operations |
| Media and places | Camera, Gallery, Music, Maps | Content-specific layouts using the same action, menu and status vocabulary |
| Utilities | Clock, Calculator, Terminal, Browser | Long-content handling, keyboard continuity and clear task state |
| Native extensions | Pilot, Reef | Caller/operation context, progress, failure and shared controls in their own native hosts |

Pilot is the assistant. Reef is the app store. Their separate Cargo workspaces
do not exempt their visible native UI from the standard. The diagnostic app
is support-only; its test controls are not an alternate product design.

## Enforcement and evidence

[The source checker](../../tools/native-ui-consistency/README.md) scans the
shell, all app QML and shared native controls. It detects direct local color,
font, positive radius/spacing literals and control-import drift. Its baseline
records existing findings by exact path, rule, expression and count; new or
duplicated findings fail. Removed findings must retire their allowance.

The initial audit found 134 source findings across 430 production QML files.
Some are intentional viewfinder, compositing, font or object geometry choices;
they require review before replacement. The baseline is an explicit inventory
of inherited decisions, not a visual approval.

The check also requires a journey for new app directories, including a nested
`ui/` layout. The workflow runs the checker and its regression tests through
CTest. It complements the existing QML/import/icon tests and real native gate.
Keep the [review record](DESIGN_REVIEW_TEMPLATE.md) with each implementation PR.
A change is called native-runtime verified only after real native evidence,
and device-qualified only after the corresponding device/provider evidence.
