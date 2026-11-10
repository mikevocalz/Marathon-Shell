# Native visual review captures

`tools/native-ui-consistency/capture_native.py` captures production app QML with
the real Qt Quick Test runner, pinned Keel controls, Marathon.Silica wrappers and
generated native icons. It supplies synthetic account, contact, note and Pilot
data through the same service fixtures as the native interaction tests. It does
not read live accounts or invoke real phone, mail or assistant services.

The capture tool is a visual review aid. The native interaction gate remains the
behavioral test authority; these eight images do not establish that every state,
translation, accessibility setting or device has been visually reviewed.

The [10 November 2026 review](2026-11-10/README.md) contains the eight final
captures, observed fixes and source/runtime provenance.

## Reproduce the review set

Build the real modules and icon bundle described in
`scripts/ci/native-ui.sh`, then point the tool at those outputs:

```sh
export KEEL_QML=/path/to/keel-build/qml
export QMLTESTRUNNER=/path/to/qt6/bin/qmltestrunner
export KEEL_THEME_ICON_DIRS=/path/to/icons/themes/z1.0/icons-monochrome
python3 tools/native-ui-consistency/capture_native.py --output /tmp/native-review
```

The output contains eight PNGs, a manifest, four native runtime logs and four
JUnit reports. It verifies real Qt 6 test execution, ready pages and exact image
dimensions. Each app runs in a fresh process and temporary configuration store.
Qt device scale and Keel theme pixel ratio are both set to one; the Notes compact
case uses Keel's native `huge` font setting. Locale is `C.UTF-8` and timezone is
UTC. App content, text metrics, colors, controls and behavior remain production
QML. The full ApplicationWindow is captured because its actual background is a
sibling of its content item. No substitute backdrop is painted by the harness.

The tool waits for native page activation and the short native fades, then
requests and captures a real frame. It does not force opacity, disable
animations or replace native components. Pilot's main page uses the same shared
native ApplicationWindow host as its interaction suite; its separate launcher
and system overlay windows are not represented by the two Pilot screenshots.

For a focused iteration, repeat `--app email`, `--app phone`, `--app notes` or
`--app pilot`. A selected run replaces the manifest with that selection; other
previous PNGs may remain in the directory. Run the full command from a clean
source checkout for a final review set. Only images listed in that run's manifest
belong to its evidence.

## What the eight images exercise

| Image | Size | Review focus |
| --- | --- | --- |
| Mail inbox | 320 × 640 | Full sender identity, account context, preview and attachment indicator |
| Mail source message | 720 × 720 | Keyboard activation opens the selected message despite a duplicate sender and subject; full recipient and filename |
| Incoming call | 320 × 640 | Scrollable long caller identity; reachable Message, Decline and Answer actions |
| Phone contacts | 720 × 720 | Distinct numbers for contacts with the same name; native search and sectioning |
| Notes task, large text | 320 × 640 | Native huge font setting; growing task rows and scrollable long text |
| Notes workspace | 1024 × 768 | Task collection beside the original note; full text and task state |
| Pilot conversation | 320 × 640 | Native answer cards and a useful prompt row with full touch targets |
| Pilot conversation | 1024 × 768 | The same conversation and unfinished prompt after resizing |

The manifest records the local source commit and tree, the actual Qt version,
runtime paths, image hashes, and independent source fingerprints. Its aggregate
source digests cover all QML, JavaScript, JSON, qmldir and capture templates in
the selected app directories and shared control module. Selected production
entry points also have individual SHA-256 hashes. These permit comparison with
a published tree whose commit ID differs after integration.

The recorded font family is the theme's requested family. Font installation,
Qt/Keel versions, graphics backends and theme assets can affect rasterization;
these are not portable pixel equality baselines. The captures exclude shell
decorations, the system keyboard, real providers/modem calls and device GPU
behavior. Runtime logs can contain expected host limitations such as an
unavailable session bus; a passing capture is not evidence of those integrations.

For checked-in review evidence, copy the eight PNGs and a small source/runtime
manifest into a dated directory under this one. Keep generated test harnesses,
logs and JUnit reports outside the repository. Record observed visual findings
and fixes in the dated review note without turning these images into an
all-app or all-device qualification claim.
