# Design influence roster

Updated: November 9, 2026. Scope: Marathon 2.0's native visual and interaction design.

This roster records public design references. Names identify historical studios, platform traditions or published work; they do not assign project staff or imply affiliation or endorsement. Delivery ownership remains in [the programme](MODERNIZATION_PLAN.md) and the operational workflow proposed in [PR #6](https://github.com/mikevocalz/Marathon-Shell/pull/6).

## Reference roster

| Reference | Place in the design brief | Where to study it |
| --- | --- | --- |
| The Astonishing Tribe (TAT), later part of RIM/BlackBerry | Named studio influence for direct manipulation, meaningful motion, contained ambience and prototypes that connect design to working UI technology. | The selected works and evidence below. |
| BlackBerry 10 platform design | Existing direction for Hub, Peek/Flow, live tasks, communication density and keyboard continuity. | [Marathon's agreed UI specification](UI_SPEC.md) and [earlier native UX research](https://github.com/mikevocalz/Marathon-Shell/blob/6ed6212f4a99bcd1ee974b49f5133a612122fb48/docs/v2/UX_RESEARCH_2026-11-07.md). |
| Sailfish OS / Jolla design | Existing direction for ambience, covers, gesture roles and pulley menus. | [Sailfish UI documentation](https://docs.sailfishos.org/Develop/Apps/UI/) and [Marathon's keep/drop review](../design/2026-10-12-sailfish-ux-keep-drop.md). |
| Marathon / Keel / Marathon.Silica | Current native controls, theme ownership and interaction baseline. | [UI specification](UI_SPEC.md), [icon specification](../design/app-icon-spec.md) and [source ownership in the visual brief](VISUAL_REFRESH_RESEARCH_2026-11-09.md#existing-native-foundation). |
| Selected contemporary application patterns | Supporting references for settings rows, unread information and preview-card structure. | [Visually inspected Mobbin screens](VISUAL_REFRESH_RESEARCH_2026-11-09.md#inspected-mobbin-references), identified individually as iOS apps. |

## TAT and BlackBerry provenance

TAT belongs in Marathon's design-reference roster as a studio with a documented connection to BlackBerry's interface development. RIM's [fiscal 2011 financial statements, note 7](https://www.sec.gov/Archives/edgar/data/1070235/000095012311030229/o66524exv1w2.htm) record the acquisition of a TAT subsidiary, closed December 23, 2010, and the intended use of its design expertise and technology in RIM products.

RIM's [March 24, 2011 announcement](https://www.sec.gov/Archives/edgar/data/1070235/000134100411000761/rim6k.htm), in the second release's Useful Links section, directly identifies the two PlayBook videos below as conceptual TAT applications. This is primary evidence for attribution and concept status. It does not attribute every BlackBerry 10 screen or interaction to TAT.

Mobbin searches for The Astonishing Tribe on iOS and web returned unrelated products. The named TAT references therefore use original publication links, company records and firsthand accounts. All retrieval was checked on November 9, 2026.

## Selected TAT work and related BlackBerry material

| Work | Evidence and classification | Proposed lesson for Marathon |
| --- | --- | --- |
| [Scrapbook for PlayBook, original video](https://www.youtube.com/watch?v=mWJG-sB7H4Y) | RIM's March 2011 release links this as a TAT concept. A [firsthand BlackBerry World interview, May 4, 2011](https://crackberry.com/first-look-how-technology-behind-tats-apps-will-be-implemented-playbook-made-accessible-3rd-party-de), describes Scrapbook as newly released. Record the demonstrated concept and the later app separately. | Review direct manipulation and object identity for cover movement, with deliberate settle/cancel feedback. |
| [Aura weather for PlayBook, original video](https://www.youtube.com/watch?v=uH7NKhNyygw) | The second concept is attributed to TAT by the same RIM release. [Contemporary coverage](https://www.engadget.com/2011-02-17-rim-shows-off-tat-developed-blackberry-playbook-apps.html) identifies Aura as an accelerometer-aware weather concept. | Study atmospheric treatment for relevant weather/ambience content while keeping labels readable and a static reduced-motion state. |
| [Cascades photo-list and email-filter demonstrations](https://qnxauto.blogspot.com/2011/10/) | QNX's October 18, 2011 BBDevCon account describes a TAT picture list with folded-image depth and moving tags, plus a touch-driven email filter. These are conference demonstrations. RIM's [same-day Cascades announcement](https://www.sec.gov/Archives/edgar/data/1070235/000107023511000046/pr101811.htm) separately documents a native framework with custom layouts, animations and reusable UI components. | Use small transitions to explain collection changes and filter results. Keep the existing Hub controls and stable item positions. |
| [Future of Screen Technology](https://www.youtube.com/watch?v=g7_mOdi3O5E) | TATMobileUI's September 1, 2010 publication describes an Open Innovation experience video with stretchable, transparent and e-ink displays. It is a concept film, not a delivered BlackBerry feature or hardware promise. | Study continuity when the available screen area changes. Apply the idea to existing native resize/fold and pane transitions. |
| [Official BlackBerry Cascades samples](https://github.com/blackberry/Cascades-Samples) | Related published SDK examples, attributed to BlackBerry's Cascades team. The README covers a control cookbook, lists, navigation, animation and a touch-drag example. These are code examples, not proof that every concept demo shipped. | Pair interaction proposals with working native controls and explicit state transitions. Use Marathon's current Qt/Keel stack for implementation. |

The historical video frames could not be played or inspected in this session. The original video links are retained because their provenance is established; detailed gesture choreography and timestamps remain unverified. The Future of Screen Technology title, author, date and description were available through its indexed original publication. The Cascades observations above are attributed to QNX's firsthand account. The Mobbin stills in the companion brief were inspected directly.

The original BlackBerry blog articles for Scrapbook and Cascades now redirect to a general blog page, and the TAT site was unavailable during retrieval. The RIM filings and published sample repository preserve readable evidence alongside the original media links.

## How TAT informs the slight visual lift

These are Marathon design proposals drawn from the references, not descriptions of completed implementation:

| Native area | Application of the reference | Review question |
| --- | --- | --- |
| Live covers and resume | Keep the same visible app identity through manipulation and app-to-cover transitions; track the finger and allow cancellation. | Can the user tell which task moved, where it ended and how to reverse the action? |
| Hub filtering | Animate only the change caused by the chosen filter and preserve context. Coordinate with [PR #3](https://github.com/mikevocalz/Marathon-Shell/pull/3). | Do the active filter and resulting list remain understandable with animation disabled? |
| Ambience and state | Let relevant content carry restrained atmosphere while stable text surfaces preserve contrast. | Is the information readable in dark/light targets and with motion/transparency reduced? |
| Adaptive panes | Retain selection, draft, scroll and focus as a viewport or safe region changes. | Does the same task continue after resize/fold without being restarted? |
| Shared control design | Implement the chosen behavior through existing theme and motion roles, then review a native recording. | Do Settings, Hub, covers and Quick Controls use compatible states and feedback? |

Follow the existing [UI specification](UI_SPEC.md). Hardware concepts, cross-device collaboration and elaborate 3D demonstrations remain reference material unless separately scoped. Work/Personal Spaces remain in 2.1. Nitro Forge stays a separately licensed application dependency; this roster does not introduce it into system components.

## Adding future references

Record the creator, named work, publication date, durable link, evidence type, proposed Marathon use and review status. Keep concept films, conference demos, shipped products and sample code distinct. Cite a person's own credited work before adding them individually; the evidence here supports TAT as a studio-level entry.
