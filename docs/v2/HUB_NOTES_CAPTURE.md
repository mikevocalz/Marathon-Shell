# Hub task capture and Notes recovery

This 2.0 slice turns one notification snapshot into an editable task in the native Notes app. It also makes observable Notes write failures recoverable without discarding the current editor. Work/Personal Spaces remain in 2.1.

## User journeys

1. **Create and open.** Choose **Create task** on a Hub notification, review the copied title and details, edit them, then explicitly create the task. A successful reply retains the persistent task ID. **Open task** invokes `notes.open` with that exact ID; opening a newer or unrelated note cannot count as success. Notification read, dismiss, reply, source-filter and provider-action behavior is independent of this operation.
2. **Leave and resume.** Closing the capture view returns to the Hub without clearing its draft or cancelling an admitted create. The capture is owned by the shell, shared by the home Hub and Peek, and survives their view recreation. **Stop preparation** succeeds only before dispatch. Once dispatched, the task may complete even after the view closes.
3. **Handle an uncertain create.** A timeout, lost reply, invalid result or remote failure after dispatch is an unknown outcome. The create action is never retried automatically. The user can open Notes to inspect Tasks, acknowledge that check, and close the capture. Opening an already-created exact ID is independently retryable.
4. **Recover an unrecorded edit.** Notes keeps the same editor, text and cursor when an observable save error blocks Back, switching notes or an incoming share. Retry or explicitly copy the draft. Corrupt/newer collections are protected from overwrite and can be copied as original raw data. Incoming shared text waits in order until accepted, and an accepted share is removed from that queue before navigation so a later open failure cannot duplicate it.

## Native contracts

| Boundary | Contract and source |
| --- | --- |
| Native ownership | An app-parented `NotesTaskClient` singleton owns the draft, single-flight operation and returned ID. QML views own only presentation state. The GUI thread admits work and publishes value snapshots; Marathon's existing I/O actor owns asynchronous bus work. |
| Background start/wake | Every preparation calls `org.marathonos.Shell.Navigation1.StartAppInBackground("notes")` at `/org/marathonos/Shell/Navigation`. A running but frozen Notes process can retain its bus name, so owner discovery alone is insufficient. See `crates/marathon-shell-native/src/tasks/dbus.rs` and `tasks/launch.rs`. |
| Remote actions | Destination `org.marathonos.notes`, path `/org/shipwright/Keel/Actions`, interface `org.shipwright.Keel.Actions`; `Describe() -> s`, `Invoke(s, s, a{sv}) -> s`. The Hub calls this cross-process interface. Notes uses its in-process registry only to request its own built-in `app.show`. |
| Compatibility | Validate the installed manifest's app/action identity, input/result types, notification-source support, create/open idempotence and timeout contract before sending a task. Describe and Invoke target the same unique bus owner; a restarted app cannot receive a capture prepared for its predecessor. |
| Task identity | `tasks.create` returns exactly `{ "id": integer }`, in `1..2147483647`. `notes.open` accepts and returns the same bounded ID, rejects a missing note, and records any pending editor first. It never falls back to the newest note. |
| Input bounds | Nonblank title of at most 200 UTF-16 code units; body at most 20,000; source item ID 1–512; nonblank source label at most 200. Over-limit task text is editable and rejected without silent truncation. |
| Source meaning | `kind: "notification"`, `appId: "org.marathonos.hub"`, and a copied notification ID/timestamp identify a snapshot. The label is plain, untrusted display text. This is not an authenticated provider message identity or a grant to fetch/open a message. |
| Cancellation | An atomic dispatch gate permits cancellation only before Invoke. Request generations reject stale completion callbacks. Closing a view does not drop the shell-owned operation. No remote cancellation protocol or exactly-once delivery guarantee is invented. |

The action schema is generated from Notes declarations using the packaged Keel revision, `0df499bf34e02cec7f571853cbf5a4323dc1609e`. The Rust bridge uses the existing CXX-Qt/CXX-Qt-lib `0.10.0`, zbus `6.1.0` and Marathon I/O runtime. No new shell runtime or external service dependency is introduced.

## What “Changes recorded” means

The configuration API exposes a setter and `sync()` without a disk completion/error result. The pinned Keel fallback also does not expose its underlying file-write result through that API. A successful property assignment/readback therefore establishes application acceptance, not physical durability.

The editor says **Draft**, **Changes recorded**, or **Changes not recorded** and explains that limit. Serialization, protected-store and observable assignment failures retain the draft. Metadata actions report a failure without falsely changing their visible state. Recovery never resets a damaged collection or replaces the only remaining draft.

Drafts, waiting shares and the Hub capture are held in memory. This implementation does not promise recovery after an app/shell restart, device power loss or an unobservable backend disk failure. A durable acknowledgement/journal requires a separate storage API change and migration review.

## Validation boundaries

- The Notes native suite exercises failed autosave, native Back/gesture/dialog transitions, same/different-ID opening, copy/retry, protected data, legacy import, rejected actions and queued shares.
- Hub UI cases exercise independent notification actions, editable immutable capture content, cancellation, unknown-result handling, exact-ID open, narrow/large-text layouts and shared lifetime across view replacement.
- Rust cases cover UTF-16 bounds, strict returned identity, manifest compatibility, single-flight admission and cancel-versus-dispatch behavior.
- `NativeUI_NotesWire` compiles the **production** Rust model/transport by source path and invokes the real Notes QML app, generated manifest, Keel action adaptor, configuration backend and editor on a private bus. A newer decoy task ensures opening the requested older ID is required. Only shell background-start admission is a fixture; its calls are counted on every preparation.
- The wire gate fails if its client, private bus, provider, real Qt report or required assertion is absent, skipped or failing. It does not claim physical cgroup thaw, compositor foregrounding, touch/accessibility or device-storage qualification.

Apply the native/API and ownership guidance in [ENGINEERING_WORKFLOW.md](ENGINEERING_WORKFLOW.md). Keep PR source/tree identities and actual local/hosted results in the PR evidence; implementation alone does not establish a passed build or device release.
