# Native review — 10 November 2026

These eight images are actual Qt 6.11.1 / Keel renders of production pages with
synthetic service fixtures. They were captured from a clean source checkout at
`325383a262aa605793f1785e8160d313feeee95b`. The local commit ID can differ from
the published integration commit; `manifest.json` includes source trees,
individual file SHA-256 hashes and aggregate input digests for comparison.

The images were recaptured with Marathon's production Source Sans 3 fonts.
Each of the four app processes used an isolated Fontconfig configuration that
included only the repository fonts and production Sail Sans aliases. Before
each launch, `Sail Sans Pro Light` matched `SourceSans3-Light.ttf` exactly.
Qt's normal-weight text probe resolved `Source Sans 3`, style `Regular`; both
results and the actual font path/hash are recorded. The seven aggregate input
digests include every packaged TTF and the Fontconfig alias file.

Reproduction instructions and the exact capture boundaries are in the parent
review README. All four native capture functions completed: twelve Qt results,
zero failures and zero skips. These capture results are separate from the full
native interaction gate.

## Findings addressed during the review

The first compact Phone render split “Message” across two lines. Incoming-call
actions now use their native text metrics to switch to stacked icon-and-label
rows when two labels do not fit. The existing Answer, Decline and message actions
remain the same; the complete Phone native suite passed 95 results, with no
failures or skips, after this change.

The first compact Pilot render left only a few characters of editable space
beside its two native actions. The main page and overlay now put the prompt on
its own row at narrow widths and keep full touch targets below it. The overlay
context header also reflows without a negative text width. New native checks
cover useful editing space, control bounds, selection retained through resize
and one accepted keyboard submission. Pilot passed eleven results, with no
failures or skips.

Early Mail and Notes images included native fades still in progress. The final
harness waits for active, visible native pages and panel transitions, then lets
short native fades finish and requests an actual frame. It does not change
opacity or replace any control to obtain the final images.

The production-font recapture was inspected separately from the earlier host
font renders. All eight final images retain readable action names, distinct
contact numbers, full Mail attachment identity and the expected native
scrolling boundaries. The narrow Phone identity and Pilot conversation extend
beyond their viewport while their fixed actions remain visible. The Notes
large-text image remains the explicit stress case described below.

## Captures

| Capture | Viewport | What to inspect |
| --- | --- | --- |
| [Mail inbox](mail-inbox-320x640.png) | 320 × 640 | Sender and account context remain readable; subject and preview use bounded summaries |
| [Mail source message](mail-source-720x720.png) | 720 × 720 | Keyboard activation opens the exact fixture message despite a duplicate sender/subject; recipient and attachment filename are complete |
| [Incoming call](phone-incoming-320x640.png) | 320 × 640 | Native action labels stay intact; the long caller identity scrolls above fixed actions |
| [Phone contacts](phone-contacts-720x720.png) | 720 × 720 | Both contacts with the same name have distinct visible phone numbers |
| [Notes task with huge text](notes-task-large-320x640.png) | 320 × 640 | Large text grows the task row; the native list scrolls to the rest of the long task |
| [Notes workspace](notes-workspace-1024x768.png) | 1024 × 768 | Task list and the same original note share the wide workspace |
| [Pilot compact](pilot-main-320x640.png) | 320 × 640 | Latest-answer provenance/copy actions and the retained prompt remain available in the narrow viewport |
| [Pilot wide](pilot-main-1024x768.png) | 1024 × 768 | The same conversation and unfinished prompt reflow into the wider page |

These are viewport images. The compact Notes image is an explicit huge-text
stress capture: the theme's medium text role is 40 pixels, compared with 32 in
the other images. The compact Notes huge-text case necessarily shows
only part of its long task and wraps long words; the remainder is in the native
scrollable list. The compact Pilot view follows the latest answer, so earlier
lines are above the viewport. The wide screenshots provide complementary
context, not a claim that every long value is visible simultaneously at every
size.

No real mail account, contact, note collection or assistant provider was read.
The images do not represent shell decorations, a system keyboard, modem/provider
integration, a device GPU or every application state. Native host warnings and
full JUnit reports remain in the capture output directory, rather than being
checked into this evidence folder.
