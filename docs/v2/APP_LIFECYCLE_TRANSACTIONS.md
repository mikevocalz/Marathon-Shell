# App lifecycle transaction boundaries

This is the first implementation slice of R01 and R02. It does not close their
device, power-loss, bus-identity or shared-secret acceptance gates.

## Installation and launch

Each installation consists of `.generations/<id>/gen-<token>/files` and its
matching `receipt.json` under the user install root. `<id>` is an installer-owned
relative symlink selecting one complete generation. Readers validate that the
pointer stays in the same app's generation namespace and resolve it once. The
receipt and manifest are then read from that root. Private archive-copy
signature verification, system-signer/version restrictions, permission
disclosure and approval remain in force. Plans are recomputed under the app
lock from the private staged manifest. A missing or non-regular entry point
cannot replace a working installation.

The stage is created on the destination filesystem. Files, receipt and
directories are synced before the current pointer changes by atomic rename.
Both rename parents are synced afterward. An error before publication retains
the prior selection. An error after publication is `Refusal::Committed`: the
new generation is visible and must be retained while durability is recovered.
The CLI and store handler explicitly report that distinction. They do not claim
the old installation was restored. A retry can inspect the selected receipt and
republish the same approved package under the same lock.

Every mutating entry point shares a nonblocking per-app `flock`: package and
directory install, uninstall/retry, legacy migration, and superseded update
removal. The lock's directory is outside the published name and never removed
with app files. Source copying uses no-follow, directory-relative descriptors;
symlinks and special files are rejected. Unexpected pointers, ownership or
metadata are preserved for diagnosis, not followed or recursively erased.

The selected generation root travels with the catalogue's permissions through
the native launcher. It supplies the sandbox bind, runner generation token, Qt
module requirements and Chromium flags. Runner AppRegistry reads that same
generation. Installed updates of bundled apps also use this cold-launch path;
they cannot adopt a warm runner containing a different selection. Immutable
paths keep late QML/import/resource reads on the selected code even after an
update. The runner token is checked against its own app ID and store namespace.
An explicit runner selection never falls back to bundled code if its receipt
or manifest is unavailable. Catalogue scans and lookups for other app IDs keep
their normal bundled fallback. A bundled system app's signed update retains
its existing read-only catalogue/store access when its approved permissions
include `system`. Other installed apps do not receive that shared catalogue/store
bind.

This aligns storage identity and launch-time confinement. Shell D-Bus permission
grants are still keyed by app ID; generation-scoped bus identity, permission
revocation and service mediation remain R03/R06 work. Retaining a generation is
not proof of complete IPC confinement.

## Retention and legacy installs

A durable `retention.json` records the boot when a generation ceased to be the
current selection. It is refreshed before replacing or unpublishing that name.
Installation boot alone is insufficient: an older installation can be running
after a reboot. Current and current-boot generations are retained. Collection
requires a valid different Linux boot ID and a matching app ownership record.
An unavailable or malformed boot ID refuses mutation; it never proves that
runners are gone.

At most eight generation directories are admitted before another install is
refused. The installer never evicts potentially running code to make room. A
subsequent boot permits collection of recognized retired/staged generations.
Unknown state, including a crash between creating a stage and writing its first
ownership marker, is preserved and can require operator recovery. This count
cap is not an archive size or disk-space quota. ENOSPC and sync failures remain
reported transaction outcomes; device storage quotas are still an open gate.

Old `<id>/{files,receipt.json}` installations are copied to a generation and
atomically exchanged with the pointer. Existing bind mounts retain the original
directory. An unconfined old runner may still use the conventional path, so
replacement or uninstall of that migrated installation requires a device
restart. The error is visible to the user. New launches use the copied immutable
generation immediately. Former writable-data installs migrate under the same
lock; their original directory remains app data.

## Uninstall, retries and truthful outcomes

Uninstall writes a durable intent before removing the current pointer. Its
report separates publication from retained app files, cache, data, config,
shared settings and secrets. Removing a launcher entry does not imply those
bytes were deleted. Destructive cleanup waits until a later boot; no PID scan
or assumed runner lease is used as proof. If a crash left the app published
across a reboot, retry refreshes the barrier to the current boot because it
could have been launched again.

The intent records the exact selected generation and keeps the app ID reserved.
Retries after pointer removal remain available. A different installed
generation causes refusal, and reinstall is blocked until the recorded
filesystem work completes. Data paths with symlinked ancestors or roots are
reported as failed without following them. Independent categories still report
their actual outcomes. `appData: keep` retains data/config/shared settings; a
bundled app exposed by removal of its update also retains its shared writable
directories and cache. Media directories are never removed.

Secret Service has no verified per-app ownership inventory here, so secret
deletion is explicitly unsupported. Shared dconf/shell settings deletion is
also reported unsupported rather than launching an unchecked reset command.
Those are unfinished R02 contracts, not successful deletion.

Native uninstall admission and completion are separate. At most eight filesystem
workers are active, with per-app deduplication and request identity checks.
Thread creation failure rejects admission; the GUI does not copy, fsync or
recursively delete app directories. Owner-thread completion refreshes the
catalogue and revokes stored grants whenever publication was removed, even for
partial cleanup. If the shell owner disappears, the filesystem job still runs;
its durable record is available to a later session.

AppStore emits `UninstallComplete`, `UninstallPartial` or `UninstallFailed`.
AppInstaller, Settings and the launcher handle the partial outcome separately.
Settings lists pending filesystem cleanup and offers retry after the app's
launcher entry disappears. The CLI prints the category report as JSON and uses
exit status **0** for complete requested cleanup, **2** for a partial outcome,
and **1** for refusal. Unsupported shared categories remain in the stored report,
CLI output and the final UI notice after filesystem cleanup finishes and the
reinstall block is cleared. The persistent Settings retry list contains only
unfinished filesystem work; that list does not retain completed reports or
provide a settings/secret cleanup action. A failed status query preserves the
last known retry rows and displays an unavailable state.

## Verification and remaining gates

Registered Rust tests use real temporary directories and child processes to
cover generation publication, receipt/manifest/code consistency, stale launch
snapshots, explicit source symlink rejection, missing entry points, update
consent, lock contention, keep/remove behavior, partial retries and reinstall
blocking. Publication tests kill the writer with SIGKILL at each durable
boundary and inject ENOSPC before and after commit. Retirement tests cover an
app installed on one boot and running on the next. They demonstrate process
interruption and recovery behavior, not power-loss durability of device storage.

Native tests cover generation-specific metadata and environment selection.
Settings AppPages tests exercise a removed app's retained cleanup row and retry.
Launcher tests exercise request admission, partial outcome and asynchronous
failure; they require the real QtWayland.Compositor module. Native build/UI
qualification and target-device runs must record their actual dependencies and
results. Boot-ID simulation in filesystem tests does not replace rebooting a
device with a live app, and no real power-cut result is claimed here.
