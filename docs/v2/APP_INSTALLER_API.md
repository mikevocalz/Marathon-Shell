# AppInstaller: cached state and asynchronous commands

This 2.0 contract follows the pinned API-design and native guidance in
[ENGINEERING_WORKFLOW.md](ENGINEERING_WORKFLOW.md). It changes the actual
Rust/CXX-Qt `Marathon.Platform.AppInstaller` client and its Settings consumers.
The inspected baseline is `8e9e0892f646d3e11fd581367d148d7f063d7dc7`;
CXX-Qt is pinned to 0.10.0 and zbus to 6.1.0 in the Cargo workspace.

## Why the interface changed

`pendingUninstalls`, `flatpakApps` and uncached `canUninstall` previously called
`Service::ask_now`, blocking the QML owner thread until the shell replied.
Flatpak failure also became an empty list, which looked like successful discovery
of no installed apps. These three methods now read local cached state. Explicit
refresh commands perform the service work on Marathon's I/O executor and queue
value results back to the QObject's owner thread.

The client and shell must be updated together: `UninstallCapabilities` is a new
AppStore1 method. An older shell returns a visible service error. There is no
silent fallback to one RPC per app: the AppStore gate admits at most 30 calls per
sender per second, so that pattern failed as the catalogue grew.

## Surface and state

Subscribe before starting the refresh. Each query has one result-change signal,
one refresh command and a cheap snapshot read.

| Observation | Refresh command | Signal | `items` value |
|---|---|---|---|
| `pendingUninstalls()` | `refreshPendingUninstalls()` | `pendingUninstallsChanged()` | `[{id, detail}]` |
| `flatpakAppsState()` | `refreshFlatpakApps()` | `flatpakAppsChanged()` | `[{id, name}]` |
| `uninstallCapabilities()` | `refreshUninstallCapabilities(appIds)` | `uninstallCapabilitiesChanged()` | `{appId: bool}` |

Every snapshot contains `available`, `loading`, `items` and `error`.

- Before the first successful query, `available` is false and `items` is empty.
  An empty successful result has `available: true`.
- `loading` reports the owned refresh. Cached items remain readable while it runs.
- Failure sets a nonempty `error` and makes `available` false. It retains the
  last successful `items`, including cleanup rows that remain retryable after
  their app has disappeared from the launcher.
- Success replaces `items` and clears `error`.
- `flatpakApps()` and `canUninstall(id)` remain cheap cache accessors. Callers
  needing readiness or failure information use the corresponding snapshot.
  A capability is advisory; uninstall still rechecks the actual mutation.

Settings reads retained items in every state, including when a page is reopened
after a service failure. It exposes errors and retry controls. Uninstall menus
require an available capability snapshot; a failed read is not interpreted as a
successful determination that every app is protected.

## Ownership, coalescing and failure

Each observation owns at most one in-flight client request. Further refreshes
coalesce into one successor. A response to an invalidated read is discarded
before publication, whether it succeeds or fails. Capability refreshes retain
the latest requested ID set for that successor. Uninstall signals invalidate
the removed app's cached capability and any in-flight read that could restore it.

Each service read has a 15-second client deadline. A late reply cannot overwrite
a newer snapshot. This bounds client waiting; it does not forcibly interrupt a
filesystem read already executing in the shell.

`marathon_rt::io::try_spawn` reports executor-thread creation failure before the
operation is accepted. Refreshes complete with a visible error in that case;
uninstall releases its pending admission and emits `uninstallFailed`. The older
logging-only `spawn` entry point remains for existing fire-and-forget work.

CXX-Qt's guarded queue does not retain its QObject. Destroying the client prevents
queued delivery to that object; there is no page or engine pointer captured by
these futures. No mutex is held while a QML signal is emitted.

## Bulk capability transport

`org.marathonos.Shell.AppStore1.UninstallCapabilities(as)` returns `a{sb}`.
It requires the existing `system` permission and consumes one AppStore admission.
The client deduplicates IDs. The service rejects more than 1024 submitted IDs with
`LimitsExceeded`, then runs the filesystem checks on the existing blocking-work
executor. Unknown or non-removable IDs return false under the same predicate as
`CanUninstall`. A query grants no authority to remove an app.

## Reviewed user journeys

1. **Open Settings while the shell is slow.** The app list renders immediately;
   cleanup and capability queries report loading. Their results update on the
   owner thread. A catalogue of 64 apps uses one bulk capability RPC.
2. **An uninstall finishes during a pending status read.** The refresh request
   invalidates the old response. Exactly one successor queries current state;
   an obsolete reply cannot restore a removed cleanup row or capability.
3. **The service fails and the page is reopened.** Cached cleanup and Flatpak
   rows remain visible with a specific error and a retry action. Recovery clears
   the error. A successful empty result is distinguishable from the failure.
4. **A client is destroyed or its deadline expires.** Its queued or late reply
   cannot update a replacement QObject. Executor-start failure releases
   admission immediately rather than leaving a permanently busy UI.

## Validation boundary

The Rust cache tests cover empty-versus-unavailable state, retained results,
recovery and coalesced invalidation. Settings AppPages runs with real Qt/Keel
widgets and Platform service fixtures. The registered `Core_AppInstaller` test
uses the actual generated Rust/CXX-Qt client and a controlled D-Bus service to
test held replies, malformed replies, errors, deadlines, replacement, batching
and latest-input coalescing. That controlled service does not qualify a device's
filesystem, sandbox, provider or modem.

This change does not migrate the other `Service::ask_now` consumers or finish
uninstall signal/request correlation, per-generation bus authority, shared
settings/secret cleanup, or reconnect behavior across the platform. Those remain
in [REMEDIATION_QUEUE.md](REMEDIATION_QUEUE.md) and the Rust API audit.
