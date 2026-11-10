# Marathon 2.0 visual refresh research

Date: November 9, 2026. Target: `v2`. Status: researched design proposal; native visual implementation and device review remain pending.

## Decision

Give Marathon 2.0 a restrained visual lift through consistent text roles, aligned controls, deliberate spacing, readable surfaces and clear interaction states. Preserve the BB10/Sailfish direction in [the UI specification](UI_SPEC.md), including live covers, the Hub, ambience, the current pill navigation and native gestures.

The brief uses "slight visual lift" to describe the size of the change. The existing plan's light and dark themes remain design targets. The current shell surface palette is dark-only; a light theme requires implementation and review.

Keep Qt/QML, Keel and Marathon.Silica as the system foundation. Nitro Forge remains a separate premium application dependency; NYC-Tron application adapters remain separate from system controls. Work/Personal Spaces, including lightweight organizational views, remain scheduled for 2.1 under [the scope decision in PR #6](https://github.com/mikevocalz/Marathon-Shell/pull/6). This visual brief creates no new 2.0 feature or release dependency.

## Evidence and relationship to earlier research

| Evidence | What it establishes | Status |
| --- | --- | --- |
| [Existing UI specification](UI_SPEC.md) | A restrained BB10/Sailfish visual direction, theme roles, motion, adaptive layouts and native review criteria already exist. | Proposed design contract. |
| [November 7 research](https://github.com/mikevocalz/Marathon-Shell/blob/6ed6212f4a99bcd1ee974b49f5133a612122fb48/docs/v2/UX_RESEARCH_2026-11-07.md) and [PR #2](https://github.com/mikevocalz/Marathon-Shell/pull/2) | Native navigation research and an adaptive live-cover prototype are separate existing work. Its Mobbin candidates require inspection before use. | Prior research and draft implementation slice. |
| Source inspection at [`bc39c23`](https://github.com/mikevocalz/Marathon-Shell/commit/bc39c23cac18221df21e410a45f8cc72d0ae9824) | Theme roles, component ownership and the current dark-only surface palette described below exist in source. | Read-only source verification; no runtime inference. |
| Mobbin screens linked below | The visible arrangements described in the reference table were inspected on November 9. | Current iOS app-pattern references. |
| Native before/after captures and interaction recordings | Needed to assess the proposed changes on Marathon. | Pending implementation review. |

The UI specification records earlier Opera, Google, Reddit and Comet inspiration. Those historical references are separate from the specifically linked screenshots inspected for this addendum. The November 7 research file currently lives in PR #2, so its link above is pinned to an existing commit.

## Inspected Mobbin references

These are iOS application screenshots used for structure only. They do not establish Sailfish/BB10 operating-system behavior, gesture semantics, cover lifecycle, accessibility conformance or performance.

| Reference | Visible evidence | Proposed use in Marathon |
| --- | --- | --- |
| [Brave Browser tab overview](https://mobbin.com/screens/2fd5e32d-9a4f-416b-93f0-b33dd23f5489?utm_source=chatgpt&utm_medium=ai-assistant&utm_source_platform=mcp) | Two preview cards have compact title strips and visible close controls; one card has a colored outline. | Review cover title contrast, banner inset and separation between resume and close targets. Keep Marathon's live cover content and native actions. |
| [Opera tab overview](https://mobbin.com/screens/40a3ec63-e0f3-4a19-873c-cb076d71d5f5?utm_source=chatgpt&utm_medium=ai-assistant&utm_source_platform=mcp) | Each row pairs a thumbnail with a title and a close control; one row has a purple outline. | Compare how a single accent marks an emphasized item. Retain Marathon's cover grid and existing accent roles. |
| [Apple Mail inbox](https://mobbin.com/screens/4a7b840c-5b83-4080-a5dd-829bbcfd05aa?utm_source=chatgpt&utm_medium=ai-assistant&utm_source_platform=mcp) | Rows separate sender, muted preview, trailing time and unread dots. | Review the same information order in `MHubRow`, with source identity and accessible unread state. Keep existing Hub provider and filter behavior. |
| [Jomo settings](https://mobbin.com/screens/ecb928b5-6d8c-4677-9604-9ea5242a3525?utm_source=chatgpt&utm_medium=ai-assistant&utm_source_platform=mcp) | A dark settings sheet uses section labels, aligned leading icons, grouped rows and a distinct group surface. | Compare section spacing and row alignment using native Settings controls. |
| [timespent settings](https://mobbin.com/screens/1d33bc84-8bd7-43c0-a07f-4124ee9d78c5?utm_source=chatgpt&utm_medium=ai-assistant&utm_source_platform=mcp) | A light background separates white row groups; labels align left while values and switches align right. | Review light-theme surface separation and label/value alignment once semantic theme roles support it. |
| [Brilliant settings](https://mobbin.com/screens/81350243-ef4c-4d4c-aab3-fb272d5f5e83?utm_source=chatgpt&utm_medium=ai-assistant&utm_source_platform=mcp) | Flat rows use leading outline icons, trailing chevrons or switches, and thin section separators. | Use as a comparison for keeping Settings compact with restrained container treatment. |

The initial broad tab-overview searches returned weak matches. A focused search for a tab switcher with preview cards produced the inspected Brave Browser and Opera references. The reviewed Mobbin material does not provide direct Sailfish/Jolla OS screenshots. Linked stills support the observations above; they do not demonstrate animation timing or interaction results.

## TAT design influence

Add The Astonishing Tribe as a named historical studio influence alongside the existing BB10 and Sailfish direction. The [design influence roster](DESIGN_INFLUENCES.md) records its BlackBerry provenance and links Scrapbook, Aura, the Cascades demonstrations, Future of Screen Technology and related official BlackBerry samples.

For this slight refresh, the proposed lessons are finger-following manipulation, transitions that retain app identity, visible filtering feedback and continuity during native layout changes. Apply them through the current controls and motion roles. The roster distinguishes concept films, conference demonstrations, later released work and sample code, and records which historical media could not be visually inspected.

## Existing native foundation

All source links in this section are pinned to the inspected `v2` commit.

| Area | Verified ownership and baseline | Refinement rule |
| --- | --- | --- |
| Surfaces | [`MColors.qml`](https://github.com/mikevocalz/Marathon-Shell/blob/bc39c23cac18221df21e410a45f8cc72d0ae9824/shell/qml/theme/MColors.qml) defines dark `elev0` through `elev5`, follows Silica theme roles for several colors and fixes `textOnAccent` to black. | Reconcile dark/light/high-contrast foreground and surface assumptions through existing theme ownership before exposing a light-mode option. |
| Text and spacing | [`MTypography.qml`](https://github.com/mikevocalz/Marathon-Shell/blob/bc39c23cac18221df21e410a45f8cc72d0ae9824/shell/qml/theme/MTypography.qml) scales semantic text roles from `Silica.Theme.fontSizeMedium`; [`MSpacing.qml`](https://github.com/mikevocalz/Marathon-Shell/blob/bc39c23cac18221df21e410a45f8cc72d0ae9824/shell/qml/theme/MSpacing.qml) already has scaled 4/8/16/24/32/40 roles. | Map shell roles to native `Silica.Theme` roles and use them consistently. |
| Shape and icons | [`MRadius.qml`](https://github.com/mikevocalz/Marathon-Shell/blob/bc39c23cac18221df21e410a45f8cc72d0ae9824/shell/qml/theme/MRadius.qml) has restrained 0/2/4/6/8 radii and a 14-unit app-icon squircle; [`GlyphIcon.qml`](https://github.com/mikevocalz/Marathon-Shell/blob/bc39c23cac18221df21e410a45f8cc72d0ae9824/shell/qml/ui/GlyphIcon.qml) selects Phosphor thin/bold glyphs. | Keep the current shape vocabulary and icon baseline. Define state-specific icon weight deliberately. |
| Motion | [`MMotion.qml`](https://github.com/mikevocalz/Marathon-Shell/blob/bc39c23cac18221df21e410a45f8cc72d0ae9824/shell/qml/theme/MMotion.qml) provides duration/easing roles, spring accessors and reduced-motion/blur handling. | Use existing motion roles and interruption behavior. Treat the UI specification's timings as proposals to validate. |
| Settings controls | [`MainPage.qml`](https://github.com/mikevocalz/Marathon-Shell/blob/bc39c23cac18221df21e410a45f8cc72d0ae9824/apps/settings/pages/MainPage.qml) already has search, headers, entry rows and switches. [`PageHeader`](https://github.com/mikevocalz/Marathon-Shell/blob/bc39c23cac18221df21e410a45f8cc72d0ae9824/marathon-silica/Marathon/Silica/PageHeader.qml), [`SectionHeader`](https://github.com/mikevocalz/Marathon-Shell/blob/bc39c23cac18221df21e410a45f8cc72d0ae9824/marathon-silica/Marathon/Silica/SectionHeader.qml) and [`ListItem`](https://github.com/mikevocalz/Marathon-Shell/blob/bc39c23cac18221df21e410a45f8cc72d0ae9824/marathon-silica/Marathon/Silica/ListItem.qml) provide native wrappers and accessibility/focus behavior. | Refine these controls as one family while preserving their behavior. |

## Proposed visual refinements

These are implementation recommendations, not claims that the current screens have been visually tested or that the changes are already built.

| Surface | Concrete adjustment | Review evidence |
| --- | --- | --- |
| Settings | Make title, section heading, row label and supporting value use consistent native text roles. Align icon, label and trailing control columns. Set section gaps from the existing spacing scale. | Before/after captures with long labels, search results, large text, keyboard focus and on/off controls. Compare grouped and flat treatments using Jomo, timespent and Brilliant. |
| Home and App Grid | Review label weight, icon alignment and label contrast over two ambiences. Keep stable app positions and existing navigation. | The same apps and wallpaper in both captures, plus large-text and keyboard-focus states. |
| Live Overview | Refine title-banner inset, caption contrast, emphasized-card treatment and action separation in [`TaskCard.qml`](https://github.com/mikevocalz/Marathon-Shell/blob/bc39c23cac18221df21e410a45f8cc72d0ae9824/shell/qml/components/TaskCard.qml) and [`MarathonTaskSwitcher.qml`](https://github.com/mikevocalz/Marathon-Shell/blob/bc39c23cac18221df21e410a45f8cc72d0ae9824/shell/qml/components/MarathonTaskSwitcher.qml). | Real native covers, readable titles and separate resume/close hit regions. Coordinate geometry with PR #2 and retain [`KeelCoverView`](https://github.com/mikevocalz/Marathon-Shell/blob/bc39c23cac18221df21e410a45f8cc72d0ae9824/shell/qml/components/KeelCoverView.qml) visibility reporting. |
| Hub | Align sender, preview, time/source and unread emphasis within [`MHubRow.qml`](https://github.com/mikevocalz/Marathon-Shell/blob/bc39c23cac18221df21e410a45f8cc72d0ae9824/shell/qml/ui/MHubRow.qml); retain rows that grow with text. | Read/unread, long sender names, multi-line previews, multiple sources and empty/loading/error states. Coordinate filter behavior with [PR #3](https://github.com/mikevocalz/Marathon-Shell/pull/3). |
| Quick Controls | Make label/value alignment and on/off/busy/focus treatment consistent in [`MQSTile.qml`](https://github.com/mikevocalz/Marathon-Shell/blob/bc39c23cac18221df21e410a45f8cc72d0ae9824/shell/qml/ui/MQSTile.qml), native sliders and [`MarathonQuickSettings.qml`](https://github.com/mikevocalz/Marathon-Shell/blob/bc39c23cac18221df21e410a45f8cc72d0ae9824/shell/qml/components/MarathonQuickSettings.qml). | Captures tied to real control state, plus a recording of interruption, keyboard operation and reduced motion. |
| Shared surfaces | Keep text surfaces readable over wallpaper; reserve the accent for meaningful states and actions. Derive light/high-contrast treatments from semantic roles. | Contrast measurements in each theme, with two ambiences and reduced transparency. Review fixed foreground assumptions such as `textOnAccent`. |

Settings is the recommended first native comparison because it combines headings, rows, values, icons and switches in a single existing screen. That is a project sequencing judgment based on the current source structure. Carry the reviewed choices into Hub, cover banners and Quick Controls through shared roles.

## Native review and acceptance

Follow [the UI specification's acceptance contract](UI_SPEC.md#design-acceptance). The existing target is at least 44 logical units for touch hit regions, preferably 48 for primary touch controls, with device-scale calibration. Check ordinary text at 4.5:1 and large text at 3:1 as already specified. These are review targets; this research supplies no measured contrast or device results.

| Review dimension | Required evidence |
| --- | --- |
| Geometry | Compact touch phone, square keyboard phone, landscape tablet, resizable desktop and unobstructed regions on a dual-screen/foldable layout. Device support requires its own qualification. |
| Theme | Dark, proposed light, high contrast, reduced transparency and two wallpaper ambiences. Record unsupported combinations until implemented. |
| Text and controls | Default and large text, long translated labels, visible keyboard focus, accessibility names/roles/order and distinct pressed/disabled/loading states. |
| Motion and continuity | Native recording of app-to-cover/resume, Hub reveal/cancel and Quick Controls dismissal. Verify interruptibility, reduced motion and retained app/focus/scroll state. |
| Content states | Populated, empty, loading, offline, error and permission-denied screens using the same visual roles. |

An implementation review should attach native before/after captures with the source commit, viewport, device scale and theme, followed by an interaction recording. Static reference screens do not qualify the compositor, input, power use or device readiness.

## Delivery

1. This documentation PR adds inspected Mobbin references, the TAT design influence roster, source ownership and a restrained visual brief, with links from the v2 index and UI specification.
2. The first implementation slice should refine the existing Settings screen and shared role mapping, then provide native captures for review.
3. Apply the reviewed role choices to Home, Hub, live covers and Quick Controls in small native changes. Coordinate with PR #2's geometry and PR #3's Hub behavior.
4. Track any light-theme or adaptive-layout prerequisites in their owning work packages. Work/Personal Spaces remain a 2.1 concern.

The result of this PR is a reviewable research and design brief. Visual implementation acceptance requires the native evidence above.
