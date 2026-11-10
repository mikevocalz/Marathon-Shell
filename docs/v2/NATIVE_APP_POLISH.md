# Native app polish

The v2 integration implements a shared native presentation across all 16
product apps, the Hub and shell. It combines the focused shared-row,
communications and Calendar changes with the remaining app work in
[PR #21](https://github.com/mikevocalz/Marathon-Shell/pull/21). The original
feature reviews remain available as [#17](https://github.com/mikevocalz/Marathon-Shell/pull/17),
[#19](https://github.com/mikevocalz/Marathon-Shell/pull/19) and
[#20](https://github.com/mikevocalz/Marathon-Shell/pull/20).

The implementation uses the image's Keel source pin
`0df499bf34e02cec7f571853cbf5a4323dc1609e`, Qt 6 and Marathon.Silica.
The user's Web Designer Pro pack informed the review through the
[native adaptation brief](WEB_DESIGNER_PRO_NATIVE_BRIEF.md). Its private assets
and web components are not runtime dependencies.

## Shared implementation

`Marathon.Silica.SummaryListItem` owns a consistent primary/secondary hierarchy,
an optional icon, content-grown height, plain-text identity and a complete
accessible name. It inherits the existing focus frame, keyboard activation,
context menu and press behavior. Public properties are `text`, `description`,
`iconSource`, `font` and `descriptionFont`. The item owns presentation; the app
continues to own the selected record and service operation.

Page and section headings wrap instead of clipping long names. The native
application window defaults labels to plain text; reviewed rich-content
renderers such as Mail's WebEngine remain explicit. Shared flickables reveal
focused controls when Tab moves beyond the visible area. The adaptive keypad
retains native key values and minimum target size in narrow windows.
Context-menu outside-press protection now ends with the menu's lifetime.

`ContentStyle` owns fixed black/white media contrast and the installed
monospace-font fallback. Camera, media views, Terminal and shell overlays use
these roles where content requires them. Ordinary text and actions still use
the current Silica ambience. Shell spacing, small corners, colors and type
remain in `MSpacing`, `MRadius`, `MColors` and `MTypography`. The four native
busy-indicator sizes now have theme assets from the existing Phosphor Thin
vocabulary.

The `marathon-silica` APK subpackage installs the existing shared QML module
independently of the shell binary. Shell, Pilot and Reef depend on it, and the
image builder stages it with the shell and icon packages. The same controls
are therefore available to both standalone native extensions.

## Implemented app surfaces

| App / surface | Concrete change | Behavior preserved or exercised |
| --- | --- | --- |
| Hub | Visible latest-item action, retained filter/scroll context and exact message/account routing | Open and return to triage; notification attention remains separate from provider read state |
| Mail | Content-grown inbox rows, readable sender/subject/source, literal account/recipient/attachment identity | Exact-message routing, reply account, composer selection and draft retention; actual HTML renderer loads separately |
| Messages | Adaptive conversation/message rows, plain recipient identity, native retry action with delivery status | Failed-send retry by keyboard/touch, retained draft and attachment flow |
| Phone / People | Shared contact hierarchy, duplicate-name disambiguation, readable call identity, scrollable compact call body above persistent primary actions | Exact contact ID, removal/revocation cleanup, Answer/End-call reachability after resize |
| Notes / Tasks | Adaptive collections and note/task rows with consistent descriptions and status | Existing editing, capture, task actions, undo and selection |
| Calendar | Readable event rows, minimum day targets, adaptive year/month layout and explicit read-only shared-event detail | Local editing/reminders, exact shared source, revocation and date selection; narrow year text remains readable |
| Settings | Shared categories/search results, live values and adaptive Ambience grid/captions | Search/focus/navigation and selected ambience through narrow/wide resize |
| Browser | Shared bookmark/history rows with title and URL, literal tab identity | Navigation, query, tab and address state |
| Camera | Shared native wrappers and fixed media roles, accessible keyboard activation for controls | Capture readiness, camera switching and capture flow through the controller fixture |
| Gallery | Content-grown album/media rows, literal filenames and explicit image loading/failure presentation | Exact selected media, navigation, remorse deletion, playback and sharing |
| Music | Adaptive collection/song rows, wrapping track identity, primary transport separated from shuffle/repeat in narrow windows | Playback/queue ownership, library navigation and player controls |
| Maps | Shared result hierarchy, explicit search failure with retained results, readable route/place identities | Destination selection and retry; route progress has a stable parent |
| Clock | Content-grown alarm/world rows, readable numeric displays, keyboard timer entry and adaptive presets | Alarm/timer/stopwatch state; world-time updates stay minute-gated |
| Calculator | Readable minimum keypad geometry with scrolling when the available region is too small | Physical-keyboard/touch operations, expression/history and native focus reveal |
| Terminal | Shared session rows, consistent monospace metrics, explicit exited/failed session state and native Restart action | Exact session, resize/input behavior and keyboard recovery |
| Pilot | Native wrappers, reusable prompt field, adaptive cards/actions and one draft shared between full window and overlay | Busy/disconnected submission retains text/cursor; accepted submission clears it; confirmation uses explicit admission |
| Reef | Adaptive title/summary/publisher/source/state hierarchy, native wrappers and distinct search failure/no-match states | Exact package identity, keyboard selection, refresh and install-state presentation |

These changes do not introduce a new account or operation owner in the UI.
They do not label cached content as newly synchronized or claim a click has
succeeded before its service reports the outcome.

## Evidence and enforcement

The [native review record](NATIVE_UI_REVIEW_2026-11-10.md) identifies actual
runtime results and captures. Complete product-app suites and the shared
control suite are required in `tests/native-ui/CMakeLists.txt`, alongside the
Hub, shell overview and production Notes-wire integration. Tests use real Qt,
Keel, Silica, Actions, Share, Pickers, Gallery, KeepAlive and WebEngine where
needed, with platform-service doubles at the application boundary. Missing
dependencies, missing reports, zero cases and skipped cases fail the gate.

The source consistency guard now has zero inherited allowances. All 134
original findings were resolved by using a shared role/control or moving a
content-specific decision into its narrow owner. No new baseline allowance was
added. The lexical guard complements native layout and interaction tests; it
cannot establish visual quality or provider correctness by itself.

Device touch, assistive technology, hardware capture, audio routing, suspend,
live providers and frame pacing require their respective device/service
qualification. Shared CalDAV events remain read-only and RRULE series previews
do not claim expanded recurrence instances. The local APK workflow in
[PR #18](https://github.com/mikevocalz/Marathon-Shell/pull/18) is ready for
user-supplied APKs; no BlackBerry APK was available in this session.

The 2.0 suite remains native Qt/QML, Keel and Marathon.Silica. Work/Personal
Spaces stay in 2.1. RNQNX, NYC-Tron and Nitro Forge remain independent
installable products.
