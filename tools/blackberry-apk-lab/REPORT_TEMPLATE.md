# BlackBerry reference-app findings

Status: not yet analyzed. Replace placeholders with observed evidence.

## Provenance and completion

| App | Source/version/base + splits | APK SHA-256 / signer reference | Analysis level | Device flow exercised | Blockers |
| --- | --- | --- | --- | --- | --- |
| Hub+ Inbox | | | | | |
| Hub+ Services | | | | | |

Record local tool paths/versions, report directory, device/Android version, capture dimensions/font scale, and collection date. Signature validity and trusted vendor provenance are separate fields. State whether any operation was unavailable, partial, or inferred from static evidence.

## Shared component map

| Producer | Component / authority / action | Consumer | Permission / identity boundary | Operation and data owner | Evidence | Confidence |
| --- | --- | --- | --- | --- | --- | --- |
| | | | | | | Observed / inferred / unverified |

Use a compact Mermaid diagram only when it clarifies the relationships. A matching string or declared package query alone does not prove a runtime dependency.

## Interaction and state

| Journey / step | Starting state | Action | Visible result | Data change / exact identity | Failure / cancellation / retry | Evidence |
| --- | --- | --- | --- | --- | --- | --- |
| Message → Hub → exact message → reply/archive | | | | | | |
| Message → task/event → exact created item | | | | | | |
| Offline/authentication failure → recovery | | | | | | |

Include how unread/viewed/dismissed states differ, who owns background work, how navigation returns, and what survives page replacement versus process restart.

## Visual and input observations

| Surface | Text hierarchy / row sizing | Focus / keyboard / touch | Narrow / wide / large text | Motion and interruption | Evidence / conditions |
| --- | --- | --- | --- | --- | --- |
| | | | | | |

## Marathon implementation mapping

| Finding | Actual Marathon path/capability | Gap | Native implementation slice | Ownership and API boundary | Acceptance journey | Priority |
| --- | --- | --- | --- | --- | --- | --- |
| | | | | | | |

State which behaviors already exist, which need improvement, and which are new proposals. List shared contracts only with real consumers. Keep Work/Personal Spaces in 2.1 and premium app frameworks outside the system dependency graph.

## Validation and remaining questions

| Claim | Static evidence | Runtime/device evidence | Remaining uncertainty | Next observation needed |
| --- | --- | --- | --- | --- |
| | | | | |

Before publishing: review every included file and capture. The shared report should contain original observations and source references, without APKs, extracted implementation/assets, private communications, or credentials.
