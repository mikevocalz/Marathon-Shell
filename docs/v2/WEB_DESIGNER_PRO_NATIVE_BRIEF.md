# Web Designer Pro: Marathon native brief

Use this alongside the user's local Web Designer Pro pack when designing or
reviewing Marathon. This repository contains an original native adaptation and
source checks. The private pack, its HTML kits, fonts, images and scripts are
not redistributed here.

## Source consulted

The user supplied `web-designer-pro.zip`, SHA-256
`fdda675250a1517f47e0db4dd3c5f5f74750be1b37818bc06fd73f543702aa1f`.
Read on November 10, 2026: its SKILL.md, README, and app, redesign, critique,
slop, finish, directions, color, type, layout, motion and platforms references.
The pack is designed for websites and web applications. Its browser scripts
are not Qt/QML validators and were not run as evidence for Marathon.

The request supplies the brief: improve consistency across the native
BB10/Sailfish successor, preserve small corners and the current Qt/Keel
foundation, and open focused v2 PRs. Existing decisions need no repeated intake.

## Tailoring the process

| Pack practice | Marathon application |
| --- | --- |
| Establish the user's core task | Use the inventory's daily journey: read/reply, capture/resume, find a person or change a setting |
| Audit before redesigning | Read current QML/service contracts and capture the actual native screen; list behavior and identity that must survive |
| Explore several directions | For a new major interaction, compare native layout alternatives within the agreed Marathon identity. For consistency repairs, keep the existing direction and state the targeted defect. |
| Choose semantic design tokens | Reuse Theme and the shell's existing token owners; propose shared changes in one owner |
| Build a complete set of states | Implement empty, loading, offline, failure, permission, long-content, selection and destructive states applicable to the journey |
| Test multiple widths and input methods | Use the native phone/square/tablet/window matrix, real keyboard/touch behavior, large text and reduced motion |
| Use an independent visual critic | Give a reviewer the native captures, task, keep list and acceptance questions. Review observed results, then fix specific defects. |
| Record why a decision won | Keep a concise design record and tested before/after evidence in the implementation PR |

This is a native evolution. The web pack's poster-scale typography, promotional
imagery, compulsory overlapping layers, large squircle examples, new font
choices per direction and browser shell patterns do not override Marathon's
existing UI specification. Preserve the system font, readable communication
density, small radius family, native menus and functional motion. A camera or
gallery may use real user content; a contact or message list needs no decorative
photography.

## Copy-ready local prompt

```text
Use my local Web Designer Pro pack with the Marathon native adaptation in
docs/v2/NATIVE_UI_CONSISTENCY.md and this brief.

Goal: make the affected native Marathon screen feel like part of the same
BB10/Sailfish successor as Hub, Mail, Settings, People, Notes and Calendar.
Use the existing Qt/QML, Keel and Marathon.Silica stack and actual native APIs.
Keep small corners, existing theme/font ownership, keyboard/touch parity and
task continuity. Apply this brief wherever the web pack assumes HTML/CSS,
a browser layout, a new typeface or decorative marketing composition.

Read CONTRIBUTING.md, CONTEXT.md, docs/CODING_RULES.md,
docs/v2/ENGINEERING_WORKFLOW.md, docs/v2/UI_SPEC.md and the affected source.
Inspect the real runtime before claiming a visual result.

1. State the daily task, exact item/account identity, current behavior and keep
   list. Find existing controls and theme roles before adding anything.
2. Use the same component, spacing, type, focus, menu and status vocabulary
   across apps. Fix a shared primitive when multiple apps need the same change.
3. For a new major layout, compare native alternatives within this identity.
   For a polish repair, retain the agreed direction and make the defect concrete.
4. Implement all relevant states. Keep drafts, selection, scroll and focus on
   back, resume and resize. Error, offline and permission outcomes must be real.
5. Run the native UI consistency CTest project and the relevant real Qt/Keel,
   service and QML tests. Do not substitute a browser mockup for native evidence.
6. Capture representative native sizes, normal/large text and reduced motion;
   include a short recording of the changed interaction. Give a separate critic
   the captures and task, address concrete findings and record remaining limits.
7. Complete docs/v2/DESIGN_REVIEW_TEMPLATE.md for this change and open a focused
   draft PR against v2. List source/dependency SHAs and tests actually run.

Keep Work/Personal Spaces in 2.1. Keep RNQNX/NYC-Tron/Nitro Forge as independent
installable app work. Do not copy the private design pack or BlackBerry assets
into the repository.
```

## Pair it with the APK research

The [local Artcraft workflow in PR #18](https://github.com/mikevocalz/Marathon-Shell/pull/18)
produces observations about a supplied APK. Use those observations as evidence
for a native journey: source identity, filtering, triage, error recovery,
account status, focus and navigation.

Keep three columns in the research handoff: observed BlackBerry behavior,
Marathon's current equivalent, and the proposed native improvement. A manifest
or decompiler output cannot prove a gesture, timing, hidden state or visual
hierarchy. Mark those as runtime questions until the user exercises the APK.

Web Designer Pro helps review composition and coherence. Artcraft helps
structure the local reference investigation. Neither is a new runtime
dependency, nor does this PR claim that an APK has already been dissected.

## First concrete application

[PR #17](https://github.com/mikevocalz/Marathon-Shell/pull/17) introduces a shared
native summary row for Settings and People. Use it as the first component
review: consistent primary/secondary hierarchy, content-grown height, plain
text, distinguishing accessible names and inherited focus/menu behavior.

[PR #19](https://github.com/mikevocalz/Marathon-Shell/pull/19) reviews continuity
and message identity. [PR #20](https://github.com/mikevocalz/Marathon-Shell/pull/20)
reviews shared calendar data and truthful read-only states. These slices make
the standard concrete; they do not certify all native screens. The remaining
app journeys are explicit in the shared inventory.
