# APK collection checklist

## First pass: communications and shared data

Collect each installed app's base APK **and every split** from one consistent installed version. The package names below are verified against BlackBerry's official Play listings. A listing documents an identity; availability and device compatibility still depend on the user's store/device.

| Priority | App / package | What to examine | Marathon destination |
| --- | --- | --- | --- |
| Required together | [Hub+ Inbox](https://play.google.com/store/apps/details?id=com.blackberry.hub) — `com.blackberry.hub` | Unified list, account/source filters, selection, reply, archive, snooze, exact message opening, compose recovery | Shell Hub, Mail, Messages |
| Required together | [Hub+ Services](https://play.google.com/store/apps/details?id=com.blackberry.infrastructure) — `com.blackberry.infrastructure` | Shared account/data ownership, sync adapters, provider authorities, signature permissions, notification integration and cross-app entry points | Existing native mail/DAV/notification owners and shared contracts |
| Next | [Calendar](https://play.google.com/store/apps/details?id=com.blackberry.calendar) — `com.blackberry.calendar` | Invitations, agenda, account colors, recurrence and reminder state | Calendar and Hub event interface |
| Next | [Contacts](https://play.google.com/store/apps/details?id=com.blackberry.contacts) — `com.blackberry.contacts` | Identity rows, account identity, contact linking, recipient choice, call/message/email actions | Shared contacts, People, compose recipients |
| Next | [Notes](https://play.google.com/store/apps/details?id=com.blackberry.notes) — `com.blackberry.notes` | Editor/navigation state, categories, sharing, offline/sync feedback | Notes workspace and storage contract |
| Next | [Tasks](https://play.google.com/store/apps/details?id=com.blackberry.tasks) — `com.blackberry.tasks` | Stable task identity, due/reminder/completion, grouping, account association | Notes tasks and Hub capture |

The service boundary is documented in the [Hub+ Services listing](https://play.google.com/store/apps/details?id=com.blackberry.infrastructure). The [Inbox documentation](https://docs.blackberry.com/en/blackberry-hub-inbox/get-connected-with-the-blackberry-hub-inbox) describes its combined communication views. Use both as research questions and validate behavior against your exact supplied versions.

## Optional reference set

These apps are **not prerequisites for the first Hub analysis**. Inspect them when you have the original package/device variant and want to study the listed interaction. Resolve each actual package identity from `adb shell pm list packages`, `pm path`, and the manifest instead of guessing a package ID from its display name.

| Reference | Research question | Native Marathon target |
| --- | --- | --- |
| Privacy Shade | How is the reveal area moved/resized, how is masking toggled, and how does touch/accessibility work? | A shell-owned privacy overlay |
| Redactor, where present in the supplied version | Is redaction a separate component or part of a share/edit flow? What reaches the exported image? | Native share/screenshot redaction |
| Launcher | Shortcut discoverability, widget reveal, folder handling, notification indicators | Launcher and action discovery |
| Keyboard | Cursor movement, text selection, prediction placement, shortcuts and language switching | Existing native keyboard/input integration |
| Device Search | Search scopes, actions from results, permissions and empty states | Permission-aware native search providers |
| Productivity Tab | Edge access, agenda/tasks/contacts density, focus restoration | Hub/Peek interaction research |
| Notable | Screenshot annotation, recipient/share handoff and recovery | Native capture/annotation flow |
| Password Keeper | Lock/unlock, editing, autofill entry points and recovery presentation | A separately designed native credential experience |
| DTEK | Clear permission explanations, activity presentation and actionable status | Native permission/security surfaces |
| Locker / private capture / Camera, as installed | Protected item visibility, capture feedback, gallery/share boundaries | Camera, Gallery, and file-access contracts |
| Power Center | Whether advice is tied to measured app activity and how settings link back | Battery/settings UX |

Some legacy apps reached end of life; BlackBerry publishes the product list and dates in its [application lifecycle table](https://www.blackberry.com/en/secure-communications/support/smartphones-tablets-applications). Record the exact device/version, and label unavailable features rather than assuming a current store listing or cross-device compatibility. Do not treat an OEM/system app as an installable standalone dependency without evidence.

BBM Enterprise, Work, Access, UEM, Dynamics and other organizational packages are outside this consumer 2.0 research pass. Consumer BBM and BB10 applications are different targets; an Android Hub APK does not establish BB10 internals or interoperability.

## Per-package provenance

For each collection record: acquisition source, collection date, package ID, version code/name, base/split list, APK SHA-256s, signer certificate fingerprints, Android/device version, and which operations were actually exercised. Preserve the same acquisition facts when comparing versions.
