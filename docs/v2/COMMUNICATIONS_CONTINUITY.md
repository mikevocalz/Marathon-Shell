# Hub and Mail continuity

Implementation source: `094ed581d93e2ca0f8bca61c3a30c011ee601727` (the PR 16 dependency), on top of `v2` at `bc39c23cac18221df21e410a45f8cc72d0ae9824`. This slice keeps the existing native Qt/Keel UI and Marathon.Silica controls.

## User journeys

1. **Return to Hub triage.** Hiding and showing the existing Hub keeps its list position, source filter and unread filter. A **Newest notifications** native button stays reachable in the viewport above the page bar while scrolled down; selecting it returns to the beginning and focuses the first row. Footer clearance keeps the last notification above the button. The existing top-follow behavior still accommodates new notifications while the user is already at the top. This is continuity for the live Hub instance, not persistence across a shell restart. Notification read/dismiss state remains independent of provider message state.
2. **Open the message that actually notified.** A new Mail notification carries route `message` and parameters `{ "messageId": "message:<32 lowercase hex digits>", "accountId": "<decimal account ID>" }`. Both cold-launch environment routing and the existing warm `NavigationRouter.deepLinkRequested` route open the same stored message. Reading another account's message preserves the current inbox selection. A removed message, wrong account or invalid route never substitutes the newest inbox message. An open composer is saved before navigation and remains on the page stack with its text and cursor.
3. **Read, retry and reply safely.** The message page shows native loading/error states. Only the active app's active page marks a successfully loaded message read. A hidden or closed page cannot mark a late result read; retries have distinct request identities. Reply/forward captures the source account. Drafts retain sender ID, name and address; sending is disabled if that ID no longer identifies the same address. The existing send path selects that sender before submitting. A running sync shows a disabled **Syncing…** item; there is no cancellation claim backed by an empty method.

## Identity and storage

`messages.reference` is an independently generated 128-bit value with a unique index. Existing messages receive references without changing their cached content, folder, account, UID or seen state. New inbox delegates use the reference; numeric `messageId` remains in the list contract for existing action consumers. The older `GetMessage` entry point still accepts numeric IDs. Notification routing accepts only the new reference form.

These references are identities, not authorization capabilities. Both `GetMessage` and the new `GetMessageInAccount(message, account)` pass through the existing Mail `admit` permission check. The latter verifies account membership before returning content. A numeric SQLite row ID reused after deletion cannot resolve an old notification. Reads return the canonical message ID, account ID/name/address and folder ID with the body.

Remote message fetch, seen-state and move operations compare the selected folder's IMAP UIDVALIDITY with the stored value before acting on a UID. Sync invalidates cached references when UIDVALIDITY changes. Body caching, seen-state updates and deletions target the persistent reference, so work begun for a removed item cannot update its replacement.

`messages.body_complete` distinguishes a full cached message, including a legitimately empty body, from the headers cached for messages of at least 8 MiB. Legacy rows have an unknown flag: a stored payload remains usable, while an ambiguous empty entry needs one successful fetch. Failure to fetch an uncached body is an error and does not count as a successful read. Successful fetches are cached by reference, preserving offline reading and attachment access without changing seen state.

## Native boundary and ownership

The QML reader calls `MailService.requestMessage(messageId, accountId)`, which returns a request ID immediately, or an empty ID if work cannot be admitted. The native bridge owns copied arguments on Marathon's I/O executor and bounds the D-Bus wait to 30 seconds. It queues owned results through the existing CXX-Qt thread handle. `messageLoaded(request, details)` and `messageLoadFailed(request, reason)` are delivered on the GUI thread. Reasons are `not-found`, `timeout` and `unavailable`, including the pinned zbus version's normalized `FDO(FileNotFound)` error.

The page owns its current request identity and ignores older responses. Destruction disconnects its QML signal handlers. Leaving the page abandons presentation; it does not advertise cancellation of a daemon fetch already in progress. The daemon may finish and cache that read-only fetch. No page read request itself mutates provider seen state. Existing synchronous action/send APIs are retained; this change does not claim to modernize all Mail I/O.

Inspected source contracts include the existing notification hint serialization and launch routing, Mail1 permission boundary, CXX-Qt `qt_thread().queue`, Marathon `io::try_spawn`/`timeout`, and Keel's `PageStack`, `PageStatus` and `ApplicationWindow.applicationActive`. The applicable guidance is Margelo `api-design` and `cpp` at `1e9e17be6f41c838db472d6a4b943fc26355a3be`, plus the repository coding and Keel migration rules. Dependency versions remain CXX-Qt 0.10.0, zbus 6.1.0 and Keel `0df499bf34e02cec7f571853cbf5a4323dc1609e`.

## Evidence and remaining gates

| Check | Local result / scope |
|---|---|
| `cargo test --manifest-path crates/Cargo.toml -p marathon-maild --bin marathon-maild --locked` | Eight unit tests passed, including row reuse, migration, UIDVALIDITY invalidation and complete/partial/legacy body distinctions |
| `cargo clippy --manifest-path crates/Cargo.toml -p marathon-maild --all-targets --locked -- -D warnings` | Passed, including the integration test target |
| `cargo test --manifest-path crates/Cargo.toml -p marathon-maild --test bus --locked --no-run` | Compiled the actual-daemon/private-bus tests |
| Strict private-bus execution | Blocked before daemon launch: this host's `dbus-daemon` cannot create a Unix socket (`Operation not permitted`); no runtime pass claimed |
| Qt 6.12 `qmlformat`, Rust formatting, `git diff --check`, test reachability | Passed for the changed files / registrations |
| Required native QML execution | Registered `NativeUI_Mail_mailrouting` and `NativeUI_Mail_emailapp`, plus the existing Hub suite; awaiting a real Keel/qmltestrunner CI environment |

The private-bus tests run the real mail daemon with a permission fixture and locally seeded complete bodies. They cover exact source/account/folder resolution, wrong-account rejection, stale-reference rejection after numeric ID reuse, independent seen state and permission denial. They are automatically reached by the existing `Rust_Crates` test. CI's `MARATHON_TEST_STRICT=1` keeps a missing bus from passing silently.

The QML tests use real native pages with a Mail service fixture and cover cold/warm navigation, a newer decoy, draft/cursor preservation, sender replacement, unavailable messages, retry, out-of-order completion and page closure. The existing broader Mail suite also waits for asynchronous body loading. These fixtures do not establish CXX-Qt linking, live provider behavior or device touch/accessibility performance. Qt/Keel native compilation and interaction evidence remain CI/device gates; HTML rendering remains in the separate WebEngine suite. The broad Silica-import lint still reports pre-existing Reef/Pilot/Camera omissions outside this slice.

Mail retains its existing optimistic local seen/move behavior and outbox delivery mechanism. A move may remove the local row before the server accepts it; this slice reports remote move/seen errors but does not implement a durable retry/rollback journal. Offline mutation delivery, SMTP success/failure, attachment behavior against real providers, IMAP server UIDVALIDITY changes, shell freeze/thaw and phone interaction captures need provider/device qualification. No Work/Personal Spaces functionality is introduced.
