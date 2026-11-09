# Native UI and interaction specification

Status: proposed design contract, not implemented visuals. Read alongside [the programme](MODERNIZATION_PLAN.md).

## Character

Sailfish provides ambience, typography and fluid covers; BB10 provides communication density and continuity. The visual result should feel premium and original: strong hierarchy, restrained depth, precise alignment, tactile feedback and confident use of space. Avoid a generic dashboard, decorative neon, excessive blur and rows of interchangeable rounded cards.

Use atmosphere behind content and stable readable surfaces beneath text. A wallpaper should influence accent and ambience without determining contrast. Light, dark, high-contrast and reduced-transparency states are designed together. Maintain compact communication lists while allowing editorial typography where geometry permits.

## One token system

Extend current theme sources; introduce no competing hard-coded palette. Define semantic surface/text/border/accent/status/focus roles; typography and font fallbacks; spacing and radius scales; elevation; touch targets; icon weights; motion and haptic roles. Generate the OS's QML theme from a versioned public schema. Optional NYC-Tron application adapters may consume public theme roles. System controls remain Qt/Keel/Marathon.Silica; Nitro Forge premium components and assets are not part of the system UI or its dependencies.

The November 9 user preference is small rounded corners with Googlebook's modern interaction ideas. Use existing small-radius roles for ordinary bounded surfaces, flat dense lists and restrained larger sheets. Preserve intentional circles, the navigation indicator and current icon assets; keep touch targets independent of visible corner size. App-facing roles belong in the public theme contract and Marathon.Silica, without importing the shell module into sandboxed apps. See [the Googlebook feature reference](GOOGLEBOOK_FEATURE_REFERENCE_2026-11-09.md) for verified behavior, exact current shell tokens, native source gaps and proposed package mapping. This is a design refinement; all Work/Personal Spaces remain in 2.1.

Initial design parameters to validate: a 4-unit spacing rhythm; touch hit regions of at least 44 logical units, preferably 48 for primary touch controls; separate visual icon size from hit area; readable body typography that responds to user scale. Logical units must be calibrated through device scale, not treated as physical pixels. Check text contrast at 4.5:1 for ordinary text and 3:1 for large text, with visible control/focus contrast and actual accessibility testing.

Use the existing icon theme as the migration baseline. Specify consistent outline/selected-filled states where meaningful; animate only informative state changes. Evaluate Rive only for isolated useful animations after runtime, power and accessibility verification. Shell-critical controls remain functional without an optional animation runtime.

## Core screens

| Screen | Design brief | Expanded presentation |
|---|---|---|
| Lock | Clear time/date, privacy-controlled activities, obvious unlock and call handling | Preserve privacy across outputs; no private preview on a second display |
| Home | Personal ambience, stable app access, local search and route to live covers | Balanced app area and optional activity/Hub region |
| Overview | Meaningful existing app covers, legible state, large deliberate actions | Stable grid, app pairs, keyboard selection and window grouping |
| Hub | People/conversations, source/account identity, unread/follow-up filters | Conversation list plus detail; optional context pane |
| Peek | Progressive reveal with reversible exit and retained originating app | Temporary reveal or user-pinned Hub, never competing overlays |
| Quick controls | Reachable connectivity, audio route, brightness, Focus and privacy state | Organized panel near invocation point; no stretched phone sheet |
| Search/commands | Fast local results with type, source and executable action | Keyboard-first launcher with previews where useful |
| App invocation | Focused task, visible caller context, cancel and result delivery | Native transient window/pane with correct modality |
| Share/file picker | Source-aware destinations, permission-scoped files, progress/errors | Native navigation pane and preview where space allows |
| Settings | Clear hierarchy, search, protection status and per-app controls | Navigation/detail; preserve selection across resize |
| Onboarding | Navigation practice, account setup, accessibility and honest device status | Same sequence adapted to touch/keyboard; never promise unverified security |
| Update/recovery | Understandable staging, restart, failure and recovery state | Consistent status across displays; critical actions stay reachable |

## Interaction grammar

- Preserve the visible pill navigation baseline. Prototype Peek from existing Hub affordances and test cancellation; optional BB10 gesture experiments must not conflict with app input or become the only way to act.
- Keep pulley menus for a small stable set of page-wide actions. Use item context menus for item operations; avoid scroll-position-dependent essential commands.
- Use native menus/popovers and focused sheets for context. Document accessible visible alternatives where v2 extends existing gesture-only dialogs; implement through Marathon.Silica wrappers rather than modifying Keel.
- Reversible destructive operations use remorse/undo with accessible feedback. Operations that cannot be undone need clear consequence and deliberate action.
- Selection mode has obvious scope and exit. Drag/drop exposes a target and operation, with keyboard equivalents for essential transfers.
- Every control has hover, pressed, focused, disabled and loading states as applicable. Errors explain what remains saved and how to recover.

## Motion and micro-interactions

Gesture movement tracks the finger; completion/cancellation uses a consistent spring or timing role. App→cover transitions retain visual identity. Hub reveals context without losing the underlying task. Avoid animating unrelated content or rearranging covers under the user's finger.

Provisional timing roles: press feedback 80–120 ms; small state transition 120–180 ms; pane/task completion 180–280 ms. These are design starting ranges, not measured platform guarantees. Interruptible animations, correct focus and frame pacing take precedence over duration. Reduced motion replaces travel with brief fades or direct state changes. Reduce transparency without losing hierarchy. Haptic/sound feedback is optional and respects system preferences.

## Adaptive contract

Use content-derived minimum widths and available safe regions, not fixed device-name branches. Begin with compact, expanded and multi-region presentations; derive exact breakpoints from translated text, minimum pane sizes and accessibility scale during prototype review.

Persist navigation selection, open document, cursor, draft, scroll and focus separately from visual panes. Collapse detail into a navigable page; restore the split when room returns. Avoid restarting app sessions on fold or rotation. Dialogs and menus must remain fully on a safe region. Define keyboard ownership per focused window; pointer presence does not automatically disable touch targets. Pen input requires a verified native input path, palm rejection and explicit pressure/tilt capabilities where hardware provides them.

## First design review deliverable

Produce native Qt prototypes for Home/Covers, Hub, Peek and Quick Controls as one coherent family. Show square keyboard phone, tall phone, landscape tablet, dual screen with hinge, and desktop window sizes. Include light/dark, two ambiences, large text, keyboard focus and reduced motion. Review an actual interaction recording in addition to stills.

Mobbin searches did not yield direct Sailfish/Jolla OS screens. Treat app references only as pattern references, not OS specifications. The inspected Opera ambience, Google tab overview, Reddit inbox and Comet typography are supporting inspiration; preserve Marathon's own identity and provenance.

## Design acceptance

No clipped translated labels or unreachable controls at large text; no content under hinge/cutout; readable wallpaper-derived themes; screen-reader names/roles/order; visible keyboard focus; stable resume position; no duplicate shell navigation; no app state loss during layout changes. Review all empty/loading/offline/error/permission-denied states, not just the populated happy path.
