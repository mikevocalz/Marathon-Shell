# Native UI implementation review — 10 November 2026

## Change and evidence identity

This review covers the implemented all-app polish in PR21, including the
shared-row, Hub/Mail and shared-Calendar prerequisites from PR17/19/20.
The original audit/feature base is
`094ed581d93e2ca0f8bca61c3a30c011ee601727`; the PR records its exact published
head and tree. Product scope is 16 native apps plus the Hub, shell and shared
controls. Template and diagnostics remain support entries.

The local runtime is the official Qt **6.11.1** Linux x86_64 SDK and unmodified
Keel **0df499bf34e02cec7f571853cbf5a4323dc1609e**. Native controls, theme,
Actions, Share, Pickers, Gallery, KeepAlive, Notifications and Thumbnailer are
compiled from that pin. Qt Multimedia, Positioning, Core5Compat, WebChannel
and WebEngine are real modules. Offscreen rendering uses the software scene
graph and the generated production Phosphor icon theme. Each suite gets an
isolated JSON Configuration store. Platform-service fixtures remain explicit;
this environment does not impersonate a device or a live account provider.

The [implementation inventory](NATIVE_APP_POLISH.md) states what changed in
each app. The [native contract](NATIVE_UI_CONSISTENCY.md) and the user's
[Web Designer Pro adaptation](WEB_DESIGNER_PRO_NATIVE_BRIEF.md) govern visual
and interaction choices. Fixed media contrast, text source identity, small
corners, native menus and retained task state were kept deliberately.

## Real native suite results

All rows below name executed production QML with real Qt/Keel controls.
“Cases” excludes lifecycle entries; “results” includes them. Platform services
use their existing fixtures. The corresponding full app runners are mandatory
in the dedicated native CI job, not conditional on the compositor build.

| Suite | Cases | Results | Local result |
| --- | ---: | ---: | --- |
| Browser | 77 | 87 | Pass |
| Calculator | 97 | 107 | Pass |
| Calendar | 61 | 69 | Pass |
| Camera | 15 | 19 | Pass |
| Clock | 97 | 111 | Pass |
| Mail | 107 | 119 | Pass |
| Gallery | 56 | 66 | Pass |
| Maps | 61 | 69 | Pass |
| Messages | 67 | 77 | Pass |
| Music | 87 | 103 | Pass |
| Notes / Tasks | 167 | 183 | Pass |
| Phone / People | 81 | 95 | Pass |
| Pilot | 9 | 11 | Pass |
| Reef | 2 | 4 | Pass |
| Settings | 162 | 188 | Pass |
| Terminal | 64 | 76 | Pass |
| Shared Marathon.Silica controls | 151 | 187 | Pass |

The latest per-suite results total **1,361 behavioral rows / 1,571 Qt results**
across the 16 apps and shared controls. This combines the complete runs with
targeted repair reruns. The dedicated gate requires 27 CTest registrations,
including the full product suites, shared controls and integration contracts.

The full suites contain zero skipped cases. Separate shell tests cover Hub,
PageViewHub, overview geometry, task switching, page indicators, keyboard keys
and language selection. Native toolkit checks exercise actual module loading,
WebEngine HTML loading and theme-image readiness. Validator/gate-contract tests
prove that missing tools, reports, empty suites and skipped tests cannot count
as coverage. Source consistency has zero new and zero inherited findings; all
134 original allowances were retired after their source changes.

The production Notes-wire client builds from its locked Rust dependencies.
This host denies private D-Bus socket creation, so its integration run is
recorded as blocked locally and remains a required CI test. Existing focused
PR17, PR19 and PR20 have successful native and complete build/test CI runs.
Current integration CI evidence is recorded on PR21.

## Native visual review

The reproducible native capture harness uses the production Mail, Phone,
Notes and Pilot windows with synthetic fixture data. It checks page readiness,
actual window dimensions and output images and records source/runtime
provenance. The [eight checked-in captures and visual findings](native-review/2026-11-10/README.md)
include a [source/runtime manifest](native-review/2026-11-10/manifest.json).
All fifteen selected source hashes, seven aggregate input fingerprints and eight
image hashes match the integrated source/evidence. The four capture functions
passed twelve Qt results with zero failures or skips.

The final captures use an isolated Fontconfig environment containing only the
repository's production Source Sans 3 fonts and Sail Sans alias configuration.
All four process preflights matched `Sail Sans Pro Light` to
`SourceSans3-Light.ttf`; each image also records Qt's resolved `Source Sans 3`
probe family and `Regular` style at the normal font weight. The manifest
records the actual font path/hash, alias hash and an aggregate digest of all
packaged TTF/configuration inputs. This separates the alias match from Qt's
selection of a weight and prevents host fallback fonts from silently changing
the review. The source snapshot was clean at
`325383a262aa605793f1785e8160d313feeee95b`.

| Profile | State and interaction | Evidence scope |
| --- | --- | --- |
| 320 × 640 | Mail source hierarchy; incoming call; large-text task; Pilot conversation/composer | Actual native windows and existing service fixtures |
| 720 × 720 | Duplicate-name contacts and exact Mail source opened with Return | Square keyboard-device layout and keyboard activation |
| 1024 × 768 | Notes task/editor workspace and Pilot conversation/composer | Wider layout with the same task state |
| Narrow → wide → narrow | Shared rows, headings/keypad; app rows, call controls, drafts and ambience selection | Native geometry, identity and focus regressions |
| Reduced motion / scale changes | Shell task-page indicator and shared native controls | Live token scale 0.75/1/1.5/2 and final geometry |

The compact Notes capture is a native huge-text stress case. It deliberately
shows a long task continuing below the viewport, including long-word wrapping;
it does not represent the default text size. The final visual review confirmed
intact Phone action names, useful Pilot editing space, distinct numbers for
duplicate contact names, complete Mail source/attachment identity and a Notes
workspace without overlap.

## Installed runtime and package propagation

`marathon-silica` ships the common controls independently of the shell and pulls
in its matching icon package. Shell, Pilot and Reef declare that shared runtime.
Release staging, image caches, manual device installs and QML hot deployment now
include the runtime and icons. Keel is built first and retains its separate
package version. Optional browser/test packages are updated only when already
installed by the development-device script.

Fourteen focused checks exercised the actual cache, release-staging and device
installation scripts with temporary artifacts and intercepted external commands.
All passed. Production CMake installation rules staged QML and icons; actual
Qt/Keel loaded shared controls and an icon from that installed tree without
shell/source QML imports (two behavioral rows, four total results, zero failures
or skips). No deployment was performed. Full Alpine APK construction and image
boot were not run locally because this host has no Podman.

## Findings fixed during native verification

- The native CI image lacked Marathon's production font package, so host
  fallback metrics affected Phone and shared-tab geometry checks. The CI font
  setup was corrected. Captures now verify their isolated production font
  environment and were regenerated and visually inspected with that setup.
- Long Calendar year labels exceeded narrow day cells. Adaptive outer spacing
  and content geometry now retain the actual font advance width.
- Phone call content collided with persistent actions in short windows. The
  identity and secondary controls scroll above the primary action region.
  Native capture review also caught a broken Message label; metric-based
  inline/stacked action layout now keeps action names readable.
- Pilot disabled actions needed explicit native button admission, and deferred
  conversation scrolling could target a removed view. Both paths were fixed
  and exercised with real keyboard activation. Capture review found cramped
  compact prompt input; narrow full-window and overlay composers now give
  text its own row above the full-size action targets.
- Camera keyboard controls used a QtQuick import revision predating
  `activeFocusOnTab`. The real module loader exposed it; controls now use the
  current API. The unavailable-camera placeholder has its required native
  flickable parent and is tested for visible, nonzero geometry.
- Native busy graphics were missing from the icon theme. All four sizes now
  resolve to a production asset and have a native readiness regression.
- A context menu could execute a deferred callback after destruction. Its
  outside-press guard now releases through a timer owned by the menu.
- Hub footer clearance depended on the scroll geometry it changed. It now
  depends on item presence, with unchanged clearance across scrolling and a
  binding-loop regression in the retained-context test.
- The shell fixture loaded real scale-token singletons recursively. Module-local
  symlinks keep the actual production implementations and test live scaling;
  the formatter preserves those links and formats their tracked targets.
- Several new geometry checks read before native Column/Row layout finished.
  They now wait for the actual positions while retaining their bounds and
  identity assertions.

## Qualification limits

Native test fixtures establish app presentation and interaction contracts.
They do not establish physical touch latency, screen-reader speech order,
hardware camera output, microphone/audio routing, GPU frame pacing, suspend
wakeups or live IMAP/SMTP/CalDAV/provider behavior. Maps tests retain their
existing renderer fixture. The selected software scene graph does not qualify
glass/blur shaders on device hardware or a complete light theme.

The shared calendar feed is a read-only account preview. Recurrence expansion,
remote editing/invitations and daemon-owned reminders are outside that feature.
Mail's existing optimistic seen/move and synchronous send behavior is not a
new durable operation journal. The local Artcraft APK workflow is implemented;
no supplied BlackBerry APK or APK-runtime observation is claimed here.

No v2 branch merge, deployment or release was performed. Work/Personal Spaces
remain 2.1 and premium/native-extension products remain independently installable.
