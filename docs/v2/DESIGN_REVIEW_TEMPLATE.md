# Native design review record

Copy this into the implementation PR or a dated review document. Use
`pass`, `fail`, `blocked` or `not applicable (reason)`; an empty cell is
not a pass.

## Change and evidence identity

- App/screens and everyday task:
- Base SHA / proposed head SHA:
- Qt version / pinned Keel revision / target build:
- Shared controls and token owners inspected:
- Existing behavior, data and navigation that must survive:
- Exact item/account/operation identity:
- Design decision and alternatives where useful:

## Native evidence

| Profile / setting | State and interaction | Screenshot / recording / test reference | Result |
| --- | --- | --- | --- |
| Narrow phone | Long content, primary action and menu | | |
| Tall phone | Touch, back and resume | | |
| Square / keyboard | Tab, activation, context menu and dismissal | | |
| Landscape / wide | Narrow → wide → narrow with active task | | |
| Large text / translation | Identity, action labels and scroll reachability | | |
| Reduced motion / supported ambience | Complete state, legibility and focus | | |

## State and service review

| Question | Evidence and result |
| --- | --- |
| Does the same control look and act the same as its sibling apps? | |
| Is the core task obvious without an explanation? | |
| Do labels, values, icons and grouping follow the shared hierarchy? | |
| Are account/source and operation scope visible where relevant? | |
| Are first-run empty and filtered-empty states distinct? | |
| Are loading, offline, cached and failed outcomes truthful? | |
| Does revocation clear restricted content, including open detail views? | |
| Do long text and changed font scale preserve content and actions? | |
| Do back, resume and resize preserve draft, selection, cursor, scroll and focus? | |
| Are focus, accessible names/roles and non-color status meaningful? | |
| Does reduced motion preserve every action and final state? | |
| Does a destructive action have the actual stated recovery behavior? | |

## Critique and validation

- Independent reviewer and artifacts reviewed:
- Most important observed defects:
- Changes made in response:
- Deliberate choices retained, with reason:
- Follow-up captures/tests that verify the fixes:
- Source consistency CTest result, including inherited finding count:
- Relevant native QML/service/bridge test result:
- Device/provider checks and unresolved limits:

Do not invent scores, captures or successful device runs. Source lint proves
only its stated rules. A service fixture does not establish provider behavior.
An unavailable runtime is recorded as blocked, with the native work left draft.

## Result

- Implemented:
- CI-verified:
- Native-runtime verified:
- Device/provider qualified:
- Remaining concrete follow-up:
