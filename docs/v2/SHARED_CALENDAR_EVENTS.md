# Shared account calendars in Calendar and Hub

This change connects the existing DAV daemon's calendar cache to the native
Calendar app and Hub. Account events now share one source and identity across
both views. Local event creation, editing, deletion and reminders retain their
existing implementation.

Source baseline: `094ed581d93e2ca0f8bca61c3a30c011ee601727`, the Hub/Notes
work in PR #16, on top of `v2` at
`bc39c23cac18221df21e410a45f8cc72d0ae9824`. This is a `v2` implementation
slice; it does not implement Work/Personal Spaces.

## User journeys

1. **View an account appointment.** An enabled DAV account discovers its calendar
   collections and completes a sync. Calendar merges the account cache with
   local events; Hub merges the same cache into today's agenda. Calendar shows
   the account label and opens a read-only detail page. Provider text is plain
   text, and long titles/metadata grow the event row. An account appointment
   cannot be edited or deleted through local-event controls.
2. **Lose connectivity or access.** A failed provider pull or cache transaction
   retains the previous complete collection. A native cache-read failure keeps
   already loaded rows and exposes an unavailable state. Reload account calendars
   retries the cache read; account synchronization remains owned by DAV Settings.
   Disabling/removing an account removes its rows from both consumers. Revoking
   the Calendar app's calendar permission clears its remote rows and any open
   remote detail page; local events remain available.
3. **Continue a local workflow.** Create, edit, delete and remind a local event
   through the existing Settings-backed store. Remote events are never written
   into that store. The current Keel action schemas retain numeric local event
   IDs, so `events.list` and `events.create` remain explicitly
   local; they do not silently coerce opaque account event IDs.

## Service contract and identity

| Item | Contract |
| --- | --- |
| Bus owner | Existing `org.marathonos.Dav` daemon |
| Object | `/org/marathonos/Shell/CalendarEvents` |
| Interface | `org.marathonos.Shell.CalendarEvents1` |
| `ListEvents()` | Fallible `av` reply containing event dictionaries; requires the caller's `calendar` permission through the existing shell admission boundary |
| `EventsChanged()` | Invalidation after a sync, collection discovery, account enable/disable or removal; consumers re-read the current snapshot |
| Remote ID | Opaque `dav:` value encoding account ID, collection URL, UID and recurrence ID; callers must not parse it into an integer |
| Resource href | Cache replacement/deletion key, separate from event identity; moving a resource within its collection preserves event identity |
| Remote capabilities | `source: "caldav"`, `readOnly: true`, `reminder: -1`; recurrence previews carry `recurrenceIncomplete: true` |
| Presentation | Title, description, location, account label, local date/time and exclusive end date where applicable |

Calendar and Hub retain their native Qt/QML interfaces. The app bridge uses the
existing `Service`/permission signal helpers; the shell uses a CXX-Qt client of
the same D-Bus interface. Daemon storage work runs through the existing owned
`Shared` worker, and network pulls stay off the GUI thread. Replies cross to
QML as values queued to the owning QObject thread. A generation number rejects
superseded cache replies, including replies in flight when permission is
revoked. The QObject owns the sole lifetime sender for its subscription; drop
closes the channel and releases the watch. There is no user-visible cancellation
claim for a read already in flight.

The shell permission owner also emits its existing revocation event over D-Bus,
matching grant and denial delivery, so the app's revocation subscription has a
producer. Calendar clears remote detail content when that event removes its row.

`syncedState`/the Hub client's `state` describe access to the shared cache:
`loading`, `ready`, `denied` (app only), or `unavailable`. `ready` does not mean
the provider is currently online or that its most recent upstream sync succeeded.
The existing DAV account/status UI owns that information.

## Cache and compatibility

The old `events` table used UID alone as its primary key. It cannot distinguish
equal UIDs in two accounts or collections, or identify a deleted DAV resource.
It remains intact. A new `calendar_events` table is rebuilt from the first
complete collection sync after daemon startup; legacy rows are not guessed into
the new identity model.

Full collection replacement and incremental resource changes use SQLite
transactions. iCalendar structural decode, invalid-date and fetch failures do not
replace the collection or advance its sync token. Unsupported `DURATION` is handled
separately: supported sibling resources and deletions still apply, while the
entire unsupported resource keeps its last cached projection. Full refreshes
also retain those cached rows, but remove unrelated resources missing from the
provider's full listing. A previously unseen unsupported resource has no event
projection to display.

The DAV status `lastError` and daemon log report this partial sync. Its collection
token does **not** advance, so the next scheduled sync or user refresh re-fetches
the resource and a future parser can revisit it. No partial series replaces an
existing resource.
`Dav1.StateChanged` publishes the same state map as `GetState` at sync start and
completion, so an open native Accounts page receives both progress and errors.
Malformed supported fields or a later malformed event still fail the collection,
even if an earlier event used `DURATION`. A failed write rolls back the collection.
Tokens are scoped by both account and collection. The visible query filters out
removed/disabled accounts and collections that no longer belong to an account,
even if their cached rows still exist. Account removal currently hides that
cache; secure data erasure is not introduced by this change.

Existing local data keeps its numeric IDs and storage key. The native calendar
bridge publishes a merged presentation list but persists only local records.
Remote read-only checks exist in the app handlers and native update boundary.

## Date and recurrence limits

| Input | Behavior in this slice |
| --- | --- |
| UTC date-time | Preserves its instant and presents it in the device timezone |
| IANA `TZID` | Uses Jiff's timezone database to resolve its instant |
| Floating date-time | Resolves against the daemon's device timezone at ingestion |
| All-day date | Preserves the calendar date independently of the device timezone; an omitted end means one day |
| Multi-day event | Appears on each covered day; all-day end dates and midnight timed ends are exclusive |
| `RRULE`, `RDATE`, `EXDATE`, `RECURRENCE-ID` | Marks stored entries as **Series preview**; does not expand future occurrences or apply the complete recurrence set |
| Cancelled `VEVENT` | Omitted when replacing its resource |
| `DURATION` | Reports partial sync, keeps the entire resource's previous projection and retries with the same token; valid sibling resources still update |
| Malformed calendar/date, missing UID/start, unknown/custom `TZID` | Explicit decode error; retains the previous collection and token |

Embedded `VTIMEZONE` rules are not evaluated. A recognized IANA name uses the
installed database; provider-specific timezone definitions, recurrence expansion,
exceptions and timezone-change re-interpretation need a fuller calendar engine.
`DURATION` values are not evaluated; the unsupported-feature classification
follows validation of the event's supported UID/start/end fields.
This is an account-calendar preview, not a claim of full RFC 5545 coverage.

Remote edits, invitation responses and service-owned reminders are follow-up
work. Account event detail pages state the read-only/reminder limits. No remote
reminder is synthesized from the app's foreground lifetime.

## Source and validation evidence

The source review checked the pinned CXX-Qt `0.10.0` and zbus `6.1.0` conventions,
the existing `marathon-app-native` service and permission helpers, the existing
DAV account/storage ownership, and Keel commit
`0df499bf34e02cec7f571853cbf5a4323dc1609e`. Keel's `ApplicationWindow` exports
`_defaultLabelFormat`; Calendar uses it to keep provider/account text plain.
The added Jiff dependency resolves to `0.2.38` in the existing workspace lockfile.

Registered evidence:

- Eight calendar store/parser Rust tests cover scoped identity, resource moves,
  collection deletion, atomic rollback, account visibility, legacy preservation,
  timezones, invalid dates and explicit recurrence previews. Together with the
  existing daemon tests, `cargo test -p marathon-davd --bin marathon-davd`
  runs 25 tests after the five collection-sync regressions below.
- Five collection-sync Rust tests cover mixed supported/unsupported resources in
  incremental and full refreshes, retained cached projections, deletions, visible
  partial-sync warnings, token retry/recovery, structural decode failures and
  malformed event fields that must not be hidden by `DURATION`.
- A real-daemon private-bus test checks returned account/capability fields,
  account disable/re-enable/removal, and calendar permission denial. It remains
  part of the workspace's CTest `Rust_Crates` gate with strict bus setup in CI.
- An additional private-bus regression checks DAV's start/completion state signals
  using the native state mirror's exact map body and verifies that the completed
  signal agrees with `GetState`.
- The complete Calendar QML suite is now included in required native UI CI.
  New cases cover read-only detail/actions, loss of an open account event,
  cache failure/reload, the local action ID contract, exclusive date ranges and
  multi-day upcoming events.
  The existing required Hub suite checks merging/invalidation without mutating
  local storage; the shell agenda suite checks exclusive all-day ends.

Local verification completed: 25 daemon unit tests, daemon Clippy with
`--all-targets -- -D warnings`, workspace `cargo fmt --check`, Qt 6.12 formatting
of changed QML, clang-format on the shell registration, Calendar manifest JSON
Schema validation, the icon map, test reachability and `git diff --check`.
The global Silica-import check reports existing Pilot, Reef and Camera imports;
none of its findings is in the changed Calendar or Hub files.

The local execution environment cannot create the private D-Bus listener
(`Operation not permitted`). The five sync regressions execute the real
iCalendar decoder and SQLite cache with supplied resource responses. Private-bus
execution, native bridge compilation and Calendar/Hub interaction are covered by
the registered CI; device/provider behavior still needs target qualification.
Stubbed service QML tests do not establish real permission transport or provider
synchronization.
