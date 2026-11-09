//! The warm runner pool: spare marathon-app-runners started ahead,
//! libraries loaded and Wayland connected, inside a neutral sandbox,
//! waiting on stdin for the app they become. A spare either sees the media
//! folders or not, and becomes only an app that needs the same.

use std::collections::HashMap;
use std::io::{Error, ErrorKind};
use std::os::fd::{AsFd as _, AsRawFd as _, BorrowedFd};
use std::pin::Pin;
use std::process::{ChildStdin, Command, Stdio};
use std::time::{Duration, Instant};

use cxx_qt::{CxxQtType, Threading};
use cxx_qt_lib::QString;

use super::{Launch, Map, Qt, Tasks};
use crate::{io, log, sandbox};

/// A spare alive this long had finished starting and was warm.
const HEALTHY: Duration = Duration::from_secs(30);
/// A replacement waits for the adopted app to finish starting: a spare
/// spends seconds of CPU loading Qt and Mesa.
const REFILL_DELAY: Duration = Duration::from_secs(8);
const RECENT: usize = 5;

/// An app can start as soon as the newline reaches its runner. Keep the
/// whole message atomic and nonblocking so a fallback cannot launch it twice.
fn write_adoption(stdin: BorrowedFd<'_>, line: &[u8]) -> std::io::Result<()> {
    if line.len() > libc::PIPE_BUF {
        return Err(Error::new(
            ErrorKind::InvalidInput,
            "pool message exceeds PIPE_BUF",
        ));
    }
    let fd = stdin.as_raw_fd();
    // SAFETY: stdin borrows a live pipe descriptor; fcntl does not retain it.
    let flags = unsafe { libc::fcntl(fd, libc::F_GETFL) };
    if flags == -1 {
        return Err(Error::last_os_error());
    }
    // SAFETY: preserve all existing flags on that same live descriptor.
    if unsafe { libc::fcntl(fd, libc::F_SETFL, flags | libc::O_NONBLOCK) } == -1 {
        return Err(Error::last_os_error());
    }

    // This Rust library runs in a C++ process, whose SIGPIPE disposition is
    // not Rust main's. Block only this thread and consume only a signal from
    // this write; changing the process-wide handler would affect other I/O.
    // SAFETY: sigemptyset initializes the set; SIGPIPE is a valid signal.
    let signals = unsafe {
        let mut signals = std::mem::zeroed();
        libc::sigemptyset(&raw mut signals);
        libc::sigaddset(&raw mut signals, libc::SIGPIPE);
        signals
    };
    // SAFETY: sigset_t stores integer bitsets. Initialize all words because
    // a libc output operation may write only the kernel-visible words.
    let (mut previous, mut pending) = unsafe { (std::mem::zeroed(), std::mem::zeroed()) };
    // SAFETY: both pointers name live signal sets, including writable output.
    let blocked =
        unsafe { libc::pthread_sigmask(libc::SIG_BLOCK, &raw const signals, &raw mut previous) };
    if blocked != 0 {
        return Err(Error::from_raw_os_error(blocked));
    }
    // SAFETY: pending points to writable storage for sigpending's output.
    let pending_result = unsafe { libc::sigpending(&raw mut pending) };
    let result = if pending_result == -1 {
        Err(Error::last_os_error())
    } else {
        // SAFETY: sigpending successfully filled the initialized set.
        let was_pending = unsafe { libc::sigismember(&raw const pending, libc::SIGPIPE) == 1 };
        let result = loop {
            // SAFETY: line remains readable for its length and fd is borrowed.
            let written = unsafe { libc::write(fd, line.as_ptr().cast(), line.len()) };
            if usize::try_from(written).ok() == Some(line.len()) {
                break Ok(());
            }
            let error = if written == -1 {
                Error::last_os_error()
            } else {
                Error::new(ErrorKind::WriteZero, "incomplete pool message")
            };
            if error.kind() != ErrorKind::Interrupted {
                break Err(error);
            }
        };
        if !was_pending
            && result
                .as_ref()
                .is_err_and(|error| error.kind() == ErrorKind::BrokenPipe)
        {
            let timeout = libc::timespec {
                tv_sec: 0,
                tv_nsec: 0,
            };
            loop {
                // SAFETY: SIGPIPE is blocked on this thread; a zero timeout
                // consumes a pending signal without waiting for another one.
                let signal = unsafe {
                    libc::sigtimedwait(&raw const signals, std::ptr::null_mut(), &raw const timeout)
                };
                if signal == libc::SIGPIPE {
                    break;
                }
                let error = Error::last_os_error();
                if error.kind() == ErrorKind::WouldBlock {
                    break; // An ignored SIGPIPE is not queued.
                }
                if error.kind() != ErrorKind::Interrupted {
                    log::warn(
                        "tasks",
                        format_args!("cannot consume pool SIGPIPE: {error}"),
                    );
                    std::process::abort();
                }
            }
        }
        result
    };
    // SAFETY: previous is the valid mask returned by pthread_sigmask above.
    let restored = unsafe {
        libc::pthread_sigmask(libc::SIG_SETMASK, &raw const previous, std::ptr::null_mut())
    };
    if restored != 0 {
        // Bytes may already have been admitted: this cannot become a cold
        // retry, nor may the caller inherit a silently altered signal mask.
        log::warn(
            "tasks",
            format_args!(
                "cannot restore pool signal mask: {}",
                Error::from_raw_os_error(restored)
            ),
        );
        std::process::abort();
    }
    result
}

struct Spare {
    stdin: Option<ChildStdin>,
    pid: i64,
    instance: String,
    started: Instant,
    policy: sandbox::LaunchPolicy,
}

#[derive(Default)]
pub(super) struct Pool {
    /// Plain, then storage.
    spares: [Option<Spare>; 2],
    /// Whether each of the last few launches the pool could serve needed
    /// storage, oldest first.
    recent: Vec<bool>,
    failures: u32,
    healthy_deaths: u32,
    retry_after: Option<Instant>,
    /// Spares told to leave (EOF on stdin), by pid: their sandbox's socket.
    retired: HashMap<i64, String>,
}

pub(super) fn refill_later(qt: Qt, after: Duration) {
    io::spawn(async move {
        async_io::Timer::after(after).await;
        qt.queue(super::qobject::Tasks::refill_spares).ok();
    });
}

/// The build's runner beside the shell, else the installed one.
pub(super) fn runner_path() -> String {
    let built = std::env::current_exe().ok().and_then(|exe| {
        exe.parent()
            .map(|d| d.join("../tools/marathon-app-runner/marathon-app-runner"))
    });
    built.filter(|p| p.exists()).map_or_else(
        || "marathon-app-runner".to_owned(),
        |p| p.to_string_lossy().into_owned(),
    )
}

fn slot(storage: bool) -> usize {
    usize::from(storage)
}

impl Tasks {
    /// With two spares, one of each shape; with one, the shape most of the
    /// last few launches needed, ties to the latest, storage before any.
    fn wanted_spares(&self) -> Vec<bool> {
        let count = self.device.runner_pool;
        if count <= 0 {
            return Vec::new();
        }
        if count >= 2 {
            return vec![true, false];
        }
        let recent = &self.pool.recent;
        let Some(&last) = recent.last() else {
            return vec![true];
        };
        let storage = recent.iter().filter(|s| **s).count();
        let plain = recent.len() - storage;
        vec![if storage == plain {
            last
        } else {
            storage > plain
        }]
    }

    pub(super) fn refill_spares(mut self: Pin<&mut Self>) {
        if let Some(at) = self.pool.retry_after {
            let wait = at.saturating_duration_since(Instant::now());
            if !wait.is_zero() {
                return refill_later(self.qt_thread(), wait);
            }
        }
        let wanted = self.wanted_spares();
        for (i, storage) in wanted.iter().enumerate() {
            if self.pool.spares[slot(*storage)].is_some() {
                continue;
            }
            // One at a time: a spare spends seconds of CPU warming up.
            if self.as_mut().spawn_spare(*storage) && i + 1 < wanted.len() {
                refill_later(self.qt_thread(), REFILL_DELAY);
            }
            return;
        }
    }

    fn spawn_spare(mut self: Pin<&mut Self>, storage: bool) -> bool {
        if self.pool.spares[slot(storage)].is_some() {
            return false;
        }
        let policy = match sandbox::LaunchPolicy::from_environment() {
            Ok(policy) => policy,
            Err(error) => {
                log::warn("tasks", format_args!("cannot start spare runner: {error}"));
                return false;
            }
        };
        if !policy.is_sandboxed() {
            return false;
        }
        if self.pool.failures >= 3 {
            log::warn("tasks", "runner pool off after repeated spare failures");
            return false;
        }
        let instance = super::launch_uuid();
        let mut runner = self.runner("", &[], storage);
        let Some(socket) = self.as_mut().open_sandbox_socket("", &instance) else {
            return false;
        };
        runner.wayland_socket = socket;
        let command = sandbox::command(&runner, &runner_path(), &policy);
        // Shell-only start-up shortcuts (see WaylandCompositor::launchApp).
        let child = Command::new(&command.program)
            .args(&command.arguments)
            .env_remove("QT_NO_BUILTIN_SELECTORS")
            .env_remove("GST_REGISTRY_UPDATE")
            .stdin(Stdio::piped())
            .stdout(Stdio::null())
            .stderr(Stdio::inherit())
            .spawn();
        let mut child = match child {
            Ok(child) => child,
            Err(e) => {
                log::warn("tasks", format_args!("spare runner: {e}"));
                self.as_mut()
                    .sandbox_socket_closed(&QString::from(&instance));
                return false;
            }
        };
        let pid = i64::from(child.id());
        let stdin = child.stdin.take();
        let qt = self.qt_thread();
        let exited_instance = instance.clone();
        std::thread::spawn(move || {
            let code = child.wait().map_or(-1, |s| s.code().unwrap_or(-1));
            qt.queue(move |obj| obj.spare_exited(storage, pid, &exited_instance, code))
                .ok();
        });
        self.as_mut().rust_mut().pool.spares[slot(storage)] = Some(Spare {
            stdin,
            pid,
            instance,
            started: Instant::now(),
            policy,
        });
        true
    }

    /// Only a spare that never got warm counts against the pool; one taken
    /// later (oomd reaping the idlest process) backs the refill off.
    fn spare_exited(mut self: Pin<&mut Self>, storage: bool, pid: i64, instance: &str, code: i32) {
        let current = self.pool.spares[slot(storage)]
            .as_ref()
            .is_some_and(|s| s.pid == pid && s.instance == instance);
        if current {
            let Some(spare) = self.as_mut().rust_mut().pool.spares[slot(storage)].take() else {
                return;
            };
            let lived = spare.started.elapsed();
            let healthy = lived >= HEALTHY;
            log::warn(
                "tasks",
                format_args!(
                    "spare runner died unadopted, exit {code} after {} ms ({})",
                    lived.as_millis(),
                    if healthy { "healthy" } else { "early" }
                ),
            );
            self.as_mut()
                .sandbox_socket_closed(&QString::from(&spare.instance));
            let mut delay = Duration::from_secs(5);
            let mut rust = self.as_mut().rust_mut();
            if healthy {
                rust.pool.healthy_deaths += 1;
                delay =
                    Duration::from_secs((5u64 << (rust.pool.healthy_deaths - 1).min(5)).min(300));
                rust.pool.retry_after = Some(Instant::now() + delay);
            } else {
                rust.pool.failures += 1;
            }
            refill_later(self.qt_thread(), delay);
        } else if self
            .pool
            .retired
            .get(&pid)
            .is_some_and(|retired| retired == instance)
        {
            self.as_mut().rust_mut().pool.retired.remove(&pid);
            self.as_mut()
                .sandbox_socket_closed(&QString::from(instance));
            refill_later(self.qt_thread(), REFILL_DELAY);
        } else if self
            .active_by_pid
            .get(&pid)
            .is_some_and(|launch| launch.sandbox_instance == instance)
        {
            self.app_closed(pid);
        } else {
            // A PID may have been reused before this queued reap arrived.
            // Its original listener still belongs to this instance alone.
            self.sandbox_socket_closed(&QString::from(instance));
        }
    }

    /// A spare of a shape no longer wanted leaves: EOF on its stdin is its
    /// drain request.
    fn note_launch_shape(mut self: Pin<&mut Self>, storage: bool) {
        let mut rust = self.as_mut().rust_mut();
        rust.pool.recent.push(storage);
        if rust.pool.recent.len() > RECENT {
            rust.pool.recent.remove(0);
        }
        let wanted = self.wanted_spares();
        for shape in [false, true] {
            if wanted.contains(&shape) {
                continue;
            }
            let mut rust = self.as_mut().rust_mut();
            if let Some(spare) = rust.pool.spares[slot(shape)].take() {
                rust.pool.retired.insert(spare.pid, spare.instance);
            }
        }
    }

    /// Hands a warm spare the app: its id, route and grants, as one JSON
    /// line on its stdin. Registered first, so the cgroup and the CPU boost
    /// apply while it adopts.
    pub(super) fn adopt_spare(
        mut self: Pin<&mut Self>,
        storage: bool,
        mut launch: Launch,
        env: &Map,
        policy: &sandbox::LaunchPolicy,
    ) -> bool {
        self.as_mut().note_launch_shape(storage);
        let Some(spare) = self.pool.spares[slot(storage)].as_ref() else {
            return false;
        };
        if !policy.can_adopt(&spare.policy) {
            return false;
        }
        let Some(spare) = self.as_mut().rust_mut().pool.spares[slot(storage)].take() else {
            return false;
        };
        let (pid, instance) = (spare.pid, spare.instance.clone());
        let mut grants = serde_json::Map::new();
        grants.insert(
            "MARATHON_USER_SCALE".into(),
            format!("{:.3}", self.device.user_scale).into(),
        );
        // The language may have changed since the spare started; empty unsets.
        for key in ["LANG", "LANGUAGE"] {
            grants.insert(key.into(), std::env::var(key).unwrap_or_default().into());
        }
        for (key, value) in env {
            let key = key.to_string();
            if key.starts_with("MARATHON_PERM_") {
                grants.insert(
                    key,
                    value
                        .value::<QString>()
                        .map(|v| v.to_string())
                        .unwrap_or_default()
                        .into(),
                );
            }
        }
        let (route, params) = self.pending_route.clone().unwrap_or_default();
        let message = serde_json::json!({ "appId": launch.app_id, "route": route, "routeParams": params, "env": grants });
        launch.pid = pid;
        launch.sandbox_instance.clone_from(&instance);
        let app_id = launch.app_id.clone();
        self.as_mut().rust_mut().active_by_pid.insert(pid, launch);
        self.as_mut().register_pid(pid, &app_id);
        let line = format!("{message}\n");
        let written = spare
            .stdin
            .as_ref()
            .ok_or_else(|| Error::new(ErrorKind::BrokenPipe, "pool stdin is closed"))
            .and_then(|stdin| write_adoption(stdin.as_fd(), line.as_bytes()));
        if let Err(error) = written {
            log::warn(
                "tasks",
                format_args!("pool adopt write failed for {app_id}: {error}"),
            );
            if self
                .active_by_pid
                .get(&pid)
                .is_some_and(|launch| launch.sandbox_instance == instance)
            {
                self.as_mut().rust_mut().active_by_pid.remove(&pid);
                self.as_mut().forget_registered_pid(&app_id, pid);
            }
            self.as_mut()
                .sandbox_socket_closed(&QString::from(&instance));
            refill_later(self.qt_thread(), REFILL_DELAY);
            return false;
        }
        // EOF before a newline drains a spare; after a complete message the
        // receiver removes its stdin notifier. Both paths can close our fd.
        drop(spare);
        self.as_mut()
            .sandbox_app_assigned(&QString::from(&instance), &QString::from(&app_id));
        self.as_mut().rust_mut().pending_route = None;
        refill_later(self.qt_thread(), REFILL_DELAY);
        true
    }
}

#[cfg(test)]
mod tests {
    use std::error::Error;
    use std::io::{pipe, ErrorKind, Read as _};
    use std::os::fd::{AsFd as _, AsRawFd as _};
    use std::process::Command;

    use super::write_adoption;

    #[test]
    fn complete_adoption_is_followed_by_eof() -> Result<(), Box<dyn Error>> {
        let (mut reader, writer) = pipe()?;
        let prefix = b"{\"appId\":\"notes\",\"routeParams\":\"";
        let suffix = b"\"}\n";
        let mut line = prefix.to_vec();
        line.resize(libc::PIPE_BUF - suffix.len(), b'x');
        line.extend_from_slice(suffix);

        write_adoption(writer.as_fd(), &line)?;
        drop(writer);
        let mut received = Vec::new();
        reader.read_to_end(&mut received)?;
        assert_eq!(received, line);
        let message: serde_json::Value = serde_json::from_slice(&received)?;
        assert_eq!(message["appId"], "notes");
        Ok(())
    }

    #[test]
    fn oversized_adoption_writes_no_partial_message() -> Result<(), Box<dyn Error>> {
        let (mut reader, writer) = pipe()?;
        let line = vec![b'x'; libc::PIPE_BUF + 1];
        let error = write_adoption(writer.as_fd(), &line)
            .err()
            .ok_or("message was admitted")?;
        assert_eq!(error.kind(), ErrorKind::InvalidInput);
        drop(writer);
        let mut received = Vec::new();
        reader.read_to_end(&mut received)?;
        assert_eq!(received, [] as [u8; 0]);
        Ok(())
    }

    #[test]
    fn a_full_pipe_refuses_without_blocking_or_partial_adoption() -> Result<(), Box<dyn Error>> {
        let (mut reader, writer) = pipe()?;
        // SAFETY: writer owns a live pipe; F_GETPIPE_SZ only observes capacity.
        let capacity =
            usize::try_from(unsafe { libc::fcntl(writer.as_raw_fd(), libc::F_GETPIPE_SZ) })?;
        let fill = vec![b'x'; libc::PIPE_BUF];
        assert_eq!(capacity % fill.len(), 0);
        for _ in 0..capacity / fill.len() {
            write_adoption(writer.as_fd(), &fill)?;
        }
        let error = write_adoption(writer.as_fd(), b"{\"appId\":\"notes\"}\n")
            .err()
            .ok_or("full pipe accepted an adoption")?;
        assert_eq!(error.kind(), ErrorKind::WouldBlock);
        drop(writer);
        let mut received = Vec::new();
        reader.read_to_end(&mut received)?;
        assert_eq!(received, vec![b'x'; capacity]);
        Ok(())
    }

    fn sigpipe_state() -> (bool, bool, libc::sighandler_t) {
        // SAFETY: each syscall writes a correctly sized live output value;
        // null input sets only inspect the current thread/process state.
        unsafe {
            let mut blocked = std::mem::zeroed();
            let mut pending = std::mem::zeroed();
            let mut action: libc::sigaction = std::mem::zeroed();
            assert_eq!(
                libc::pthread_sigmask(libc::SIG_SETMASK, std::ptr::null(), &raw mut blocked),
                0
            );
            assert_eq!(libc::sigpending(&raw mut pending), 0);
            assert_eq!(
                libc::sigaction(libc::SIGPIPE, std::ptr::null(), &raw mut action),
                0
            );
            (
                libc::sigismember(&raw const blocked, libc::SIGPIPE) == 1,
                libc::sigismember(&raw const pending, libc::SIGPIPE) == 1,
                action.sa_sigaction,
            )
        }
    }

    #[test]
    fn broken_pipe_preserves_native_signal_state() -> Result<(), Box<dyn Error>> {
        const CHILD: &str = "MARATHON_POOL_SIGPIPE_TEST_CHILD";
        if std::env::var_os(CHILD).is_none() {
            let (_, test) = concat!(
                module_path!(),
                "::broken_pipe_preserves_native_signal_state"
            )
            .split_once("::")
            .ok_or("test has no crate module")?;
            let status = Command::new(std::env::current_exe()?)
                .args(["--exact", test, "--test-threads=1"])
                .env(CHILD, "1")
                .status()?;
            assert!(status.success(), "native SIGPIPE child failed: {status}");
            return Ok(());
        }

        // Only this isolated subprocess changes process disposition. Rust's
        // test main ignores SIGPIPE, unlike the C++ shell's entry point.
        // SAFETY: SIG_DFL is a valid disposition; the initialized set contains
        // only SIGPIPE and pthread_sigmask changes this test thread alone.
        let signals = unsafe {
            assert_ne!(libc::signal(libc::SIGPIPE, libc::SIG_DFL), libc::SIG_ERR);
            let mut signals = std::mem::zeroed();
            libc::sigemptyset(&raw mut signals);
            libc::sigaddset(&raw mut signals, libc::SIGPIPE);
            assert_eq!(
                libc::pthread_sigmask(libc::SIG_UNBLOCK, &raw const signals, std::ptr::null_mut()),
                0
            );
            signals
        };
        assert_eq!(sigpipe_state(), (false, false, libc::SIG_DFL));
        let (reader, writer) = pipe()?;
        drop(reader);
        let error = write_adoption(writer.as_fd(), b"{\"appId\":\"notes\"}\n")
            .err()
            .ok_or("closed pipe accepted an adoption")?;
        assert_eq!(error.kind(), ErrorKind::BrokenPipe);
        assert_eq!(sigpipe_state(), (false, false, libc::SIG_DFL));

        // A caller may block SIGPIPE temporarily, then unblock it later.
        // Our write must not leave it a new pending fatal signal.
        // SAFETY: signals is initialized above and affects only this thread.
        unsafe {
            assert_eq!(
                libc::pthread_sigmask(libc::SIG_BLOCK, &raw const signals, std::ptr::null_mut()),
                0
            );
        }
        assert_eq!(sigpipe_state(), (true, false, libc::SIG_DFL));
        let error = write_adoption(writer.as_fd(), b"{}\n")
            .err()
            .ok_or("closed pipe accepted an adoption")?;
        assert_eq!(error.kind(), ErrorKind::BrokenPipe);
        assert_eq!(sigpipe_state(), (true, false, libc::SIG_DFL));

        // An existing pending signal belongs to the caller.
        // SAFETY: raise targets this thread, where SIGPIPE is now blocked.
        unsafe {
            assert_eq!(libc::raise(libc::SIGPIPE), 0);
        }
        assert_eq!(sigpipe_state(), (true, true, libc::SIG_DFL));
        assert!(write_adoption(writer.as_fd(), b"{}\n").is_err());
        assert_eq!(sigpipe_state(), (true, true, libc::SIG_DFL));
        // SAFETY: consume our test signal before restoring an unblocked mask.
        unsafe {
            let timeout = libc::timespec {
                tv_sec: 0,
                tv_nsec: 0,
            };
            assert_eq!(
                libc::sigtimedwait(&raw const signals, std::ptr::null_mut(), &raw const timeout),
                libc::SIGPIPE
            );
            assert_eq!(
                libc::pthread_sigmask(libc::SIG_UNBLOCK, &raw const signals, std::ptr::null_mut()),
                0
            );
        }
        Ok(())
    }
}
