# Marathon OS v2 — interface research and first native implementation

_Date: 2026-11-07. Target: v2 branch. Status: V2-005 prototype slice, subject to V2-002/V2-003/V2-004 integration._

## Product direction

Create a modern native successor that carries BlackBerry 10's productivity-first Flow, Hub and Live Frames into Sailfish's responsive, gesture-led world. These are **interaction inspirations**, not permission to copy interface art or code. Preserve Marathon's Qt 6/Wayland compositor, QML surfaces, Keel/Silica app model, and real processes.

**Navigation map:** Lock → Live Overview / Home → App Grid; swipe/peek to Hub; Quick Controls and local Search are system overlays. A committed Hub visit returns to the same application/cover. Core actions always have accessible, keyboard-operated alternatives.

- **Live Overview:** live, interactive covers first; stable task order, never surprise reordering; one tap resumes, a supported cover action acts without launching. Pairing, groups and ongoing activities are later separately verified capabilities.
- **Hub:** communication workspace, not an all-purpose dashboard. Clear account/source identity, unified threads and actionable notifications, with filters (all, unread, follow-up) backed by supported providers.
- **App Grid:** visually calm launcher, legible names, local search and deliberate edit mode. Favor wallpaper ambience rather than ornamental boxed widgets.
- **Quick Controls:** signal, audio route, brightness, Focus/privacy, connection diagnostics and large hit targets. Keep overlays native and interruptible.
- **Settings:** search + focused list/detail adaptation; protections must reflect verified runtime state instead of decorative assurance.
- **All form factors:** square physical-keyboard phone, tall touch phone, tablet, book foldable, dual-screen hinge, resizable desktop; never claim a device is ported without actual hardware evidence.

## Source-grounded references

### Platform references

1. [Sailfish official UI guidance](https://docs.sailfishos.org/Develop/Apps/UI/) — Covers, cover actions, Events view, gesture navigation, pulley menus, and ambience. Preserve direct finger-following interaction with a clear cancellation path.
2. [Sailfish core UI and gesture concepts](https://docs.sailfishos.org/Support/Help_Articles/User_Interface_Basic_Concepts/) — lock, home, events, top menu, app grid. Reference for consistent gesture roles.
3. [Sailfish Lipstick compositor](https://docs.sailfishos.org/Reference/Core_Areas_and_APIs/Apps_and_MW/Lipstick/) — native QML compositor responsibilities, app/window integration and system surfaces.
4. [BlackBerry 10 Active Frames retrospective](https://crackberry.com/10-weeks-blackberry-10-active-frames) — compact, glanceable live tasks. Use as historical design context rather than current hardware capability proof.
5. [Current Marathon Shell architecture](https://github.com/patrickjquinn/Marathon-Shell) — already has a native compositor, Hub, task switcher and Keel integration. Extend existing screens, never layer a second shell.

### Mobbin research (iOS app-pattern references, NOT operating-system screenshots)

Search returned regular application interfaces rather than trustworthy BlackBerry, Sailfish, Jolla, or Marathon OS screens. The following are **candidate references** for validating specific content hierarchies in Mobbin; designers must inspect each screen visually before implementing a borrowed pattern:

- [Upwork inbox candidate](https://mobbin.com/screens/282fcba5-78bd-439e-8c6f-3012aa041c61) — review for communication-list information hierarchy.
- [Reddit activity/inbox candidate](https://mobbin.com/screens/a6367dc5-0f41-4c2f-9c3e-7b4946d48e82) — review for notification scanning and triage.
- [LinkedIn candidate](https://mobbin.com/screens/80d1c0f3-eb69-4b8f-856e-8a509aabeefa) — review for multi-source update labeling.
- [Jomo controls candidate](https://mobbin.com/screens/7ed174d3-40ef-4137-9b8a-830e40682ffc) — review for clearly stated system-control state; not a substitute for actual system controls.

The Mobbin connector indexes iOS/web screens and flows, not a catalog of QML OS reference shells. These links should not be represented as authentic Sailfish/BB10 references. For exact OS affordances, official platform documentation takes priority.

## First code slice: adaptive live-cover overview

**Source:** `shell/qml/components/MarathonTaskSwitcher.qml`, `shell/qml/core/OverviewGrid.js`.

- Retain the current two-column, two-row BB10-like overview on compact and square phone widths.
- Use three or four columns when available width and user interface scale leave adequate space for each card. Keep two rows per page.
- Derive card size, page count, footer padding and reveal-card routing from a single capacity contract. The old fixed `/4` routing cannot address wider pages.
- Track a visible-page anchor while browsing. On geometry changes, remap that anchor to the new page capacity; clamp when tasks close. Do not restart app instances.
- Preserve all existing cover rendering, app lifecycle, input, animations, touch targets, and reduced-motion behavior. This patch does not add a browser renderer, artificial cover content or a second window manager.

### Prototype acceptance matrix

| Test context | Layout goal | Verification still required |
| --- | --- | --- |
| 720 × 720 square keyboard phone | 2 × 2 live covers, no loss of existing back/home keys | Native capture, real device keyboard/focus |
| 390-wide compact viewport | 2 columns, legible title/banner | Actual device scale and large-text capture |
| 1000-wide tablet | 3 columns, stable pagination and tap-to-resume | Qt scenegraph capture and pointer input |
| 1500-wide desktop viewport | 4 columns, card actions remain reachable | Resizable compositor/keyboard QA |
| 1100-wide at scale 1.4 | Reduced to 2 columns to protect content width | Text measurement and assistive tech |
| Mid-session resize | Same app instances, visible index remapped | Native resize / focus / state tests |
| Book foldable or dual screen | All active controls in unobstructed safe regions | **Blocked on V2-002 display-region/hinge contract** |

### Quality / scope boundary

The QML `QtTest` logic is in `tests/ui/tst_overviewgrid.qml`; it is picked up by the existing `tests/ui/run.sh` test directory scan, provided Qt 6/Keel dependencies are installed. A JavaScript geometry unit test does **not** prove the compositor/Qt animation, display occlusion, accessibility, or device behavior. Require actual native captures and runtime test receipts before treating V2-005 as finished.

Keep system-facing components in Qt/Keel/Marathon.Silica. Native React Native/Qt apps may be independently packaged via public OS APIs; Nitro Forge is an optional premium dependency of a consuming app, never part of Marathon's shell source, base image, QA fixtures, or release prerequisites.
