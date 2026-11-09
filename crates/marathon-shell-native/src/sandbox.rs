//! How a marathon-app-runner starts: its environment and the bubblewrap
//! sandbox around it, for an app or for a warm spare that becomes one.
//!
//! The sandbox sees `/usr`, `/etc` and the system apps read-only, the
//! app's own data, cache and config read-write, a runtime dir with only the
//! session bus, PipeWire, PulseAudio, dconf and the app's own Wayland
//! security-context socket, only the GPU's render node, and a tmpfs home.
//! The network goes only to apps with "network", the media folders only to
//! apps with "storage". The runner then confines itself to writing where it
//! was given something writable (`MARATHON_SANDBOX_WRITABLE`).

use std::collections::HashMap;
use std::env;
use std::fs;
use std::path::{Path, PathBuf};
use std::sync::{LazyLock, Mutex};

use cxx_qt_lib::{QMap, QMapPair_QString_QVariant, QString, QStringList, QVariant};

mod policy;
pub(crate) use policy::LaunchPolicy;

#[cxx_qt::bridge]
mod ffi {
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstringlist.h");
        type QStringList = cxx_qt_lib::QStringList;
    }

    #[namespace = "marathon::sandbox"]
    extern "Rust" {
        /// The media folders an app with "storage" sees.
        fn shared_folders() -> QStringList;
    }
}

/// One runner to start. A spare has no app id yet.
#[derive(Clone, Debug, Default)]
pub(crate) struct Runner {
    pub app_id: String,
    pub permissions: Vec<String>,
    /// Generation selected with these permissions; empty for OS bundles.
    pub install_root: PathBuf,
    pub requires_qt: Vec<String>,
    /// A spare that will become an app with "storage".
    pub storage_spare: bool,
    pub wayland_socket: String,
    pub render_node: String,
    /// The GPU stack runs WebGL (ANGLE over GLES).
    pub gpu_webgl: bool,
    pub thumbnails: String,
    pub dpi: f64,
    pub user_scale: f64,
    pub screen_width: i32,
    pub screen_height: i32,
    pub app_width: i32,
    pub app_height: i32,
}

// QtWebEngine's Chromium cannot drive etnaviv's GLES2: software raster, WebGL1 only.
const CHROMIUM_FLAGS: &str =
    "--use-gl=disabled --disable-gpu --ignore-gpu-blocklist --disable-dev-shm-usage \
     --disable-features=Vulkan,UseSkiaRenderer,WebGL2 --num-raster-threads=2 --enable-viewport \
     --main-frame-resizes-are-orientation-changes";
// Stacks whose GL Chromium can drive, so WebGL runs on the GPU.
const GPU_CHROMIUM_FLAGS: &str =
    "--use-gl=angle --use-angle=gles --ignore-gpu-blocklist --disable-dev-shm-usage \
     --num-raster-threads=2 --enable-viewport --main-frame-resizes-are-orientation-changes";

struct App<'a> {
    id: String,
    permissions: Vec<String>,
    runner: &'a Runner,
}

impl App<'_> {
    fn has(&self, permission: &str) -> bool {
        self.permissions.iter().any(|p| p == permission)
    }
}

fn app(runner: &Runner) -> Option<App<'_>> {
    (!runner.app_id.is_empty()).then(|| App {
        id: runner.app_id.clone(),
        permissions: runner.permissions.clone(),
        runner,
    })
}

fn var(name: &str) -> Option<String> {
    env::var(name).ok().filter(|v| !v.is_empty())
}

// Empty environment settings use the same defaults as unset settings.
fn var_or(name: &str, fallback: &str) -> String {
    var(name).unwrap_or_else(|| fallback.to_owned())
}

use marathon_rt::dirs::home;

use marathon_apps::paths::{system_apps, user_installs};

#[derive(Default, Clone)]
struct Manifest {
    requires_qt: Vec<String>,
    chromium_flags: String,
}

// User generations are immutable; key by the same root the runner binds.
fn manifest(runner: &Runner) -> Manifest {
    static CACHE: LazyLock<Mutex<HashMap<PathBuf, Manifest>>> = LazyLock::new(Mutex::default);
    let root = if runner.install_root.as_os_str().is_empty() {
        system_apps().join(&runner.app_id)
    } else {
        runner.install_root.join("files")
    };
    let mut cache = CACHE.lock().unwrap_or_else(|_| std::process::abort());
    cache
        .entry(root.clone())
        .or_insert_with(|| {
            let json: serde_json::Value = fs::read(root.join("manifest.json"))
                .ok()
                .and_then(|b| serde_json::from_slice(&b).ok())
                .unwrap_or_default();
            Manifest {
                requires_qt: json["requiresQtModules"]
                    .as_array()
                    .map(|a| {
                        a.iter()
                            .filter_map(|v| v.as_str().map(str::to_owned))
                            .collect()
                    })
                    .unwrap_or_default(),
                chromium_flags: json["chromiumFlags"]
                    .as_str()
                    .unwrap_or_default()
                    .trim()
                    .to_owned(),
            }
        })
        .clone()
}

pub(crate) fn uses_webengine(runner: &Runner) -> bool {
    if runner.app_id.is_empty() {
        return false;
    }
    let mut modules = runner.requires_qt.clone();
    if modules.is_empty() {
        modules = manifest(runner).requires_qt;
    }
    modules.iter().any(|m| m == "webengine")
}

/// The app records through libcamera.
pub(crate) fn uses_camera(runner: &Runner) -> bool {
    app(runner).is_some_and(|a| a.has("camera"))
}

/// What libcamera opens: the media graph's nodes, and udmabuf for the
/// software ISP's output.
fn camera_nodes() -> Vec<String> {
    let Ok(entries) = fs::read_dir("/dev") else {
        return Vec::new();
    };
    let mut nodes: Vec<String> = entries
        .filter_map(Result::ok)
        .map(|e| e.file_name().to_string_lossy().into_owned())
        .filter(|n| {
            ["media", "video", "v4l-subdev"]
                .iter()
                .any(|p| n.starts_with(p))
                || n == "udmabuf"
        })
        .map(|n| format!("/dev/{n}"))
        .collect();
    nodes.sort();
    nodes
}

fn chromium_flags(app: &App<'_>) -> String {
    var("QTWEBENGINE_CHROMIUM_FLAGS").unwrap_or_else(|| {
        let flags = manifest(app.runner).chromium_flags;
        if !flags.is_empty() {
            flags
        } else if app.runner.gpu_webgl {
            GPU_CHROMIUM_FLAGS.to_owned()
        } else {
            CHROMIUM_FLAGS.to_owned()
        }
    })
}

fn variables(runner: &Runner) -> Vec<(&'static str, String)> {
    let mut vars = vec![
        ("QT_NO_XDG_DESKTOP_PORTAL", "1".to_owned()),
        ("MARATHON_SHELL_PID", std::process::id().to_string()),
        ("MARATHON_DPI", format!("{:.1}", runner.dpi)),
        ("MARATHON_APP_WIDTH", runner.app_width.to_string()),
        ("MARATHON_APP_HEIGHT", runner.app_height.to_string()),
        ("QT_QPA_PLATFORM", "wayland".to_owned()),
        (
            "WAYLAND_DISPLAY",
            var_or("MARATHON_WL_SOCKET_NAME", "marathon-wayland-0"),
        ),
        ("QT_IM_MODULE", "wayland".to_owned()),
        ("QT_QPA_GENERIC_PLUGINS", "marathontouch".to_owned()),
        (
            "QSG_ANTIALIASING_METHOD",
            var_or("QSG_ANTIALIASING_METHOD", "vertex"),
        ),
        (
            "MARATHON_LAYER_SAMPLES",
            var_or("MARATHON_LAYER_SAMPLES", "0"),
        ),
        ("MARATHON_GPU_HDR", var_or("MARATHON_GPU_HDR", "0")),
        ("LANG", var_or("LANG", "en_US.UTF-8")),
    ];
    if let Some(language) = var("LANGUAGE") {
        vars.push(("LANGUAGE", language));
    }
    if runner.screen_width > 0 {
        vars.push(("MARATHON_SCREEN_WIDTH", runner.screen_width.to_string()));
        vars.push(("MARATHON_SCREEN_HEIGHT", runner.screen_height.to_string()));
    }
    for flag in ["MARATHON_STARTUP_TIMING", "QSG_RENDER_TIMING"] {
        if var(flag).is_some_and(|v| v.parse::<i32>().is_ok_and(|n| n != 0)) {
            vars.push((flag, "1".to_owned()));
        }
    }
    if let Some(driver) = var("MARATHON_APP_MESA_DRIVER") {
        vars.push(("MESA_LOADER_DRIVER_OVERRIDE", driver));
    }
    let Some(app) = app(runner) else { return vars };
    if let Some(token) = runner
        .install_root
        .file_name()
        .and_then(|name| name.to_str())
    {
        vars.push(("MARATHON_APP_GENERATION_ID", app.id.clone()));
        vars.push(("MARATHON_APP_GENERATION", token.to_owned()));
    }
    // A spare learns the scale when it is adopted.
    vars.push(("MARATHON_USER_SCALE", format!("{:.3}", runner.user_scale)));
    for (permission, name) in [
        ("network", "MARATHON_PERM_NETWORK"),
        ("storage", "MARATHON_PERM_STORAGE"),
        ("secret-service", "MARATHON_PERM_SECRET_SERVICE"),
    ] {
        if app.has(permission) {
            vars.push((name, "1".to_owned()));
        }
    }
    if app.has("camera") {
        // FFmpeg's camera is plain V4L2; libcamera's comes through GStreamer.
        vars.push(("QT_MEDIA_BACKEND", "gstreamer".to_owned()));
    }
    if uses_webengine(runner) {
        vars.push(("QT_OPENGL", var_or("QT_OPENGL", "es2")));
        vars.push(("EGL_PLATFORM", "wayland".to_owned()));
        vars.push(("QTWEBENGINE_CHROMIUM_FLAGS", chromium_flags(&app)));
        vars.push((
            "WLR_RENDER_DRM_DEVICE",
            var("WLR_RENDER_DRM_DEVICE").unwrap_or_else(|| runner.render_node.clone()),
        ));
        if let Some(gles) = var("MARATHON_MESA_GLES_OVERRIDE") {
            vars.push(("MESA_GLES_VERSION_OVERRIDE", gles));
        }
    }
    vars
}

pub(crate) fn environment(
    runner: &Runner,
    policy: &LaunchPolicy,
) -> QMap<QMapPair_QString_QVariant> {
    let mut map = QMap::<QMapPair_QString_QVariant>::default();
    let sandboxed = if policy.is_sandboxed() { "1" } else { "0" };
    for (name, value) in variables(runner)
        .into_iter()
        .chain([("MARATHON_SANDBOXED", sandboxed.to_owned())])
    {
        map.insert(QString::from(name), QVariant::from(&QString::from(&value)));
    }
    map
}

fn shared_folders() -> QStringList {
    media_folders()
        .iter()
        .map(|p| QString::from(p.to_string_lossy().as_ref()))
        .collect()
}

/// The media folders an app with "storage" sees, at the same paths.
pub(crate) fn shared_paths() -> Vec<PathBuf> {
    media_folders()
}

fn media_folders() -> Vec<PathBuf> {
    let home = home();
    let user = [
        (dirs::picture_dir(), "Pictures"),
        (dirs::audio_dir(), "Music"),
        (dirs::video_dir(), "Videos"),
        (dirs::document_dir(), "Documents"),
        (dirs::download_dir(), "Downloads"),
    ];
    user.into_iter()
        .map(|(dir, fallback)| dir.unwrap_or_else(|| home.join(fallback)))
        .filter(|d| *d != home)
        .chain([home.join("DCIM")])
        .collect()
}

/// Executable and literal arguments, kept separate through QProcess/Command.
pub(crate) struct RunnerCommand {
    pub program: String,
    pub arguments: Vec<String>,
}

impl RunnerCommand {
    /// Diagnostic text only. It must never be parsed or executed as a command.
    pub(crate) fn description(&self) -> String {
        std::iter::once(&self.program)
            .chain(&self.arguments)
            .map(|argument| format!("{argument:?}"))
            .collect::<Vec<_>>()
            .join(" ")
    }
}

pub(crate) fn command(runner: &Runner, runner_path: &str, policy: &LaunchPolicy) -> RunnerCommand {
    let app = app(runner);
    let tail = match &app {
        Some(app) => vec!["--app-id".to_owned(), app.id.clone()],
        None => vec!["--pool".to_owned()],
    };
    match policy {
        LaunchPolicy::Bubblewrap(bwrap) => RunnerCommand {
            program: bwrap.clone(),
            arguments: [
                sandbox(runner, app.as_ref()),
                vec![runner_path.to_owned()],
                tail,
            ]
            .concat(),
        },
        LaunchPolicy::DisabledByOverride => RunnerCommand {
            program: runner_path.to_owned(),
            arguments: tail,
        },
    }
}

#[allow(
    clippy::too_many_lines,
    reason = "the ordered bubblewrap argument list is easier to audit as one policy definition"
)]
fn sandbox(runner: &Runner, app: Option<&App<'_>>) -> Vec<String> {
    let home = home();
    let runtime = var_or("XDG_RUNTIME_DIR", "/run/user/1000");
    let (data_home, cache_home, config_home) = (
        marathon_rt::dirs::data(),
        marathon_rt::dirs::cache(),
        marathon_rt::dirs::config(),
    );
    let own = |base: &Path| {
        app.map_or_else(
            || base.join("marathon-apps"),
            |a| base.join("marathon-apps").join(&a.id),
        )
    };
    let (data, cache, config) = (own(&data_home), own(&cache_home), own(&config_home));
    // Spares only ever become Marathon's own apps, so they share one cache.
    let cache_env = if app.is_some() {
        cache.clone()
    } else {
        cache.join(".spare")
    };
    for dir in [&data, &cache_env, &config] {
        fs::create_dir_all(dir).ok();
    }
    let render = runner.render_node.clone();
    let mut args = Args::default();
    args.flags(&["--die-with-parent", "--new-session"]);
    // The shell's own driver pin sends Mesa to software rendering on a render node.
    args.flags(&[
        "--unsetenv",
        "MESA_LOADER_DRIVER_OVERRIDE",
        "--unsetenv",
        "ETNA_MESA_DEBUG",
    ]);
    // Chromium's own namespace sandbox nests inside these.
    args.flags(&[
        "--unshare-pid",
        "--unshare-uts",
        "--unshare-ipc",
        "--unshare-cgroup-try",
        "--unshare-user-try",
    ]);
    if app.is_some_and(|a| !a.has("network")) {
        args.flags(&["--unshare-net"]);
    }
    for dir in ["/usr", "/etc"] {
        args.bind("--ro-bind", dir);
    }
    for dir in ["/lib", "/lib64", "/bin", "/sbin", "/var/empty"] {
        args.bind("--ro-bind-try", dir);
    }
    args.flags(&["--proc", "/proc", "--dev", "/dev"]);
    // The render node only: card nodes belong to the shell, which is DRM master.
    args.bind("--dev-bind-try", &render);
    if uses_camera(runner) {
        for node in camera_nodes() {
            args.bind("--dev-bind-try", &node);
        }
        // libudev's view of those nodes.
        args.bind("--ro-bind-try", "/run/udev");
        // Qt lists GStreamer's hidden V4L2 devices too, which offers a
        // media-controller capture node as a second, unusable camera.
        let v4l2 = "/usr/lib/gstreamer-1.0/libgstvideo4linux2.so";
        if Path::new(v4l2).exists() {
            args.flags(&["--ro-bind", "/dev/null", v4l2]);
        }
    }
    // Mesa finds its driver through these sysfs links; resolv.conf links into
    // systemd-resolved's state.
    for dir in [
        "/sys",
        "/sys/dev/char",
        "/sys/class/drm",
        "/sys/devices",
        "/run/systemd/resolve",
        "/run/dbus",
        "/var/run/dbus",
    ] {
        args.bind("--ro-bind-try", dir);
    }
    for dir in ["/tmp", "/dev/shm"] {
        args.flags(&["--tmpfs", dir]);
    }
    // A terminal keeps its home between launches, in its own data.
    if app.is_some_and(|a| a.has("terminal")) {
        let kept = data.join("home");
        fs::create_dir_all(&kept).ok();
        args.flags(&["--bind", &kept.to_string_lossy(), &home.to_string_lossy()]);
    } else {
        args.flags(&["--tmpfs", &home.to_string_lossy()]);
    }
    args.bind("--ro-bind", "/usr/share/marathon-apps");
    args.bind("--ro-bind-try", &config.to_string_lossy());
    args.bind("--bind", &data.to_string_lossy());
    args.bind("--bind", &cache.to_string_lossy());
    args.flags(&["--perms", "0700", "--tmpfs", &runtime]);
    for socket in ["bus", "pipewire-0", "pulse/native"] {
        args.bind("--ro-bind-try", &format!("{runtime}/{socket}"));
    }
    if var("MARATHON_STARTUP_TIMING").is_some_and(|v| v.parse::<i32>().is_ok_and(|n| n != 0)) {
        let log = format!("{runtime}/marathon-startup.log");
        fs::OpenOptions::new()
            .create(true)
            .append(true)
            .open(&log)
            .ok();
        args.bind("--bind-try", &log);
    }
    // Nemo.Configuration reads dconf's database and change flag; writes go
    // over D-Bus. Both are shared only if they exist before the launch.
    let dconf = [config_home.join("dconf"), Path::new(&runtime).join("dconf")];
    for dir in &dconf {
        fs::create_dir_all(dir).ok();
    }
    args.bind("--ro-bind-try", &dconf[0].to_string_lossy());
    args.bind("--bind-try", &dconf[1].to_string_lossy());
    // The app's own security-context socket where WAYLAND_DISPLAY points.
    let socket = runner.wayland_socket.clone();
    let display = var_or("MARATHON_WL_SOCKET_NAME", "marathon-wayland-0");
    args.flags(&["--ro-bind", &socket, &format!("{runtime}/{display}")]);
    let bundled = app.is_some_and(|app| {
        marathon_apps::paths::system_app(&app.id)
            .join("manifest.json")
            .is_file()
    });
    let store = Path::new(&runtime).join("marathon-store-state");
    for (kind, path) in install_mounts(runner, bundled, &user_installs(), &store) {
        if path == store {
            fs::create_dir_all(&store).ok();
        }
        args.bind(kind, &path.to_string_lossy());
    }
    // The home is the sandbox's own (a tmpfs, or a terminal's kept one).
    let mut writable = vec![home.clone(), data, cache, runtime.into()];
    writable.extend(["/tmp", "/dev/shm"].map(PathBuf::from));
    if app.map_or(runner.storage_spare, |a| a.has("storage")) {
        for dir in media_folders() {
            if dir == home.join("DCIM") {
                args.bind("--bind-try", &dir.to_string_lossy());
            } else {
                fs::create_dir_all(&dir).ok();
                args.bind("--bind", &dir.to_string_lossy());
            }
            writable.push(dir);
        }
        let thumbnails = runner.thumbnails.clone();
        fs::create_dir_all(&thumbnails).ok();
        args.bind("--ro-bind", &thumbnails);
    }
    // A path with a colon cannot be listed; it stays read-only.
    writable.retain(|p| !p.to_string_lossy().contains(':'));
    let sandbox_vars = [
        ("HOME", home.to_string_lossy().into_owned()),
        ("XDG_DATA_HOME", data_home.to_string_lossy().into_owned()),
        ("XDG_CACHE_HOME", cache_env.to_string_lossy().into_owned()),
        (
            "QML_DISK_CACHE_PATH",
            cache_env.join("qmlcache").to_string_lossy().into_owned(),
        ),
        (
            "XDG_CONFIG_HOME",
            config_home.to_string_lossy().into_owned(),
        ),
        ("MARATHON_SANDBOXED", "1".to_owned()),
        (
            "MARATHON_SANDBOX_WRITABLE",
            env::join_paths(writable)
                .unwrap_or_default()
                .to_string_lossy()
                .into_owned(),
        ),
    ];
    for (name, value) in variables(runner).into_iter().chain(sandbox_vars) {
        args.flags(&["--setenv", name, &value]);
    }
    args.0
}

/// Keep the bundled system app's existing catalogue/store visibility when a
/// signed update supplies its code. Ordinary installed apps remain scoped even
/// if their manifest asks for `system`; the selected generation binds last.
fn install_mounts(
    runner: &Runner,
    bundled: bool,
    installs: &Path,
    store: &Path,
) -> Vec<(&'static str, PathBuf)> {
    let installed = !runner.install_root.as_os_str().is_empty();
    let catalogue = runner.app_id.is_empty()
        || (runner
            .permissions
            .iter()
            .any(|permission| permission == "system")
            && (!installed || bundled));
    let mut mounts = Vec::new();
    if catalogue {
        mounts.push(("--ro-bind-try", installs.to_path_buf()));
        mounts.push(("--ro-bind-try", store.to_path_buf()));
    }
    if installed {
        mounts.push(("--ro-bind", runner.install_root.clone()));
    }
    mounts
}

#[derive(Default)]
struct Args(Vec<String>);

impl Args {
    fn flags(&mut self, flags: &[&str]) {
        self.0.extend(flags.iter().map(|f| (*f).to_owned()));
    }

    fn bind(&mut self, kind: &str, dir: &str) {
        self.flags(&[kind, dir, dir]);
    }
}

#[cfg(test)]
mod tests {
    use std::error::Error;
    use std::ffi::OsStr;
    use std::os::unix::fs::PermissionsExt as _;
    use std::process::Command;

    use super::*;

    fn sandbox_marker(runner: &Runner, policy: &LaunchPolicy) -> Option<String> {
        environment(runner, policy)
            .get(&QString::from("MARATHON_SANDBOXED"))?
            .value::<QString>()
            .map(|value| value.to_string())
    }

    #[test]
    fn explicit_override_builds_a_direct_runner_and_reports_it() -> Result<(), Box<dyn Error>> {
        let runner = Runner {
            app_id: "org.marathonos.sandbox-test".into(),
            ..Runner::default()
        };
        let policy = LaunchPolicy::resolve(Some(OsStr::new("1")), None)?;
        let command = command(&runner, "/test/runner", &policy);
        assert_eq!(command.program, "/test/runner");
        assert_eq!(
            command.arguments,
            ["--app-id", "org.marathonos.sandbox-test"]
        );
        assert_eq!(sandbox_marker(&runner, &policy).as_deref(), Some("0"));
        Ok(())
    }

    #[test]
    fn launch_command_and_environment_keep_resolved_policy() -> Result<(), Box<dyn Error>> {
        const CHILD: &str = "MARATHON_SANDBOX_POLICY_TEST_DIRECTORY";
        let Some(directory) = env::var_os(CHILD) else {
            // The real argument builder creates per-app directories. Run it
            // with isolated XDG homes without mutating this test process's
            // environment while other native tests are running.
            let directory = tempfile::tempdir()?;
            let bin = directory.path().join("bin with spaces");
            fs::create_dir(&bin)?;
            let executable = bin.join("bwrap");
            fs::write(&executable, b"command construction fixture, never executed")?;
            fs::set_permissions(executable, fs::Permissions::from_mode(0o755))?;
            let output = Command::new(env::current_exe()?)
                .current_dir(directory.path())
                .args([
                    "--exact",
                    "sandbox::tests::launch_command_and_environment_keep_resolved_policy",
                ])
                .env(CHILD, directory.path())
                .env("XDG_DATA_HOME", directory.path().join("data"))
                .env("XDG_CACHE_HOME", directory.path().join("cache"))
                .env("XDG_CONFIG_HOME", directory.path().join("config"))
                .env("XDG_RUNTIME_DIR", directory.path().join("runtime"))
                .env(
                    "MARATHON_DISABLE_SANDBOX",
                    "malformed-after-policy-resolution",
                )
                .env("PATH", directory.path().join("missing-bin"))
                .output()?;
            assert!(
                output.status.success(),
                "native command construction failed: {}\n{}",
                String::from_utf8_lossy(&output.stdout),
                String::from_utf8_lossy(&output.stderr)
            );
            return Ok(());
        };
        let directory = PathBuf::from(directory);
        let bin = directory.join("bin with spaces");
        assert!(matches!(
            LaunchPolicy::from_environment(),
            Err(policy::PolicyError::InvalidOverride)
        ));
        let policy =
            LaunchPolicy::resolve(Some(OsStr::new("0")), Some(OsStr::new("bin with spaces")))?;
        let runner = Runner {
            app_id: "org.marathonos.sandbox-test".into(),
            wayland_socket: directory.join("wayland").to_string_lossy().into_owned(),
            ..Runner::default()
        };
        let command = command(&runner, "/test/runner", &policy);
        assert_eq!(Some(command.program.as_str()), bin.join("bwrap").to_str());
        assert!(command.arguments.ends_with(&[
            "/test/runner".into(),
            "--app-id".into(),
            runner.app_id.clone()
        ]));
        assert!(command
            .arguments
            .windows(3)
            .any(|args| args == ["--setenv", "MARATHON_SANDBOXED", "1"]));
        assert!(command.arguments.iter().any(|arg| arg == "--unshare-net"));
        assert_eq!(sandbox_marker(&runner, &policy).as_deref(), Some("1"));
        assert!(command
            .description()
            .starts_with(&format!("\"{}\" ", bin.join("bwrap").display())));

        // Pool construction receives the same resolved confinement policy.
        let spare = Runner {
            app_id: String::new(),
            ..runner
        };
        let command = super::command(&spare, "/test/runner", &policy);
        assert_eq!(Some(command.program.as_str()), bin.join("bwrap").to_str());
        assert!(command
            .arguments
            .ends_with(&["/test/runner".into(), "--pool".into()]));
        assert_eq!(sandbox_marker(&spare, &policy).as_deref(), Some("1"));
        Ok(())
    }
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    reason = "fixture creation failures must fail the test"
)]
mod generation_tests {
    use super::*;

    #[test]
    fn bundled_system_updates_keep_catalogue_access_without_broadening_user_apps() {
        let installs = Path::new("/app-store");
        let state = Path::new("/runtime/marathon-store-state");
        let root = installs.join(".generations/settings/gen-selected");
        let mut runner = Runner {
            app_id: "settings".to_owned(),
            permissions: vec!["system".to_owned()],
            install_root: root.clone(),
            ..Runner::default()
        };
        assert_eq!(
            install_mounts(&runner, true, installs, state),
            vec![
                ("--ro-bind-try", installs.to_path_buf()),
                ("--ro-bind-try", state.to_path_buf()),
                ("--ro-bind", root.clone()),
            ]
        );
        assert_eq!(
            install_mounts(&runner, false, installs, state),
            vec![("--ro-bind", root.clone())]
        );
        runner.permissions.clear();
        assert_eq!(
            install_mounts(&runner, true, installs, state),
            vec![("--ro-bind", root)]
        );
        assert_eq!(
            install_mounts(&Runner::default(), false, installs, state),
            vec![
                ("--ro-bind-try", installs.to_path_buf()),
                ("--ro-bind-try", state.to_path_buf()),
            ]
        );
    }

    #[test]
    fn metadata_and_environment_follow_the_selected_generation() {
        let root = tempfile::tempdir().unwrap();
        let first = root.path().join("gen-first");
        let second = root.path().join("gen-second");
        for (generation, modules, flags) in [
            (&first, vec!["webengine"], "--first"),
            (&second, vec![], "--second"),
        ] {
            fs::create_dir_all(generation.join("files")).unwrap();
            fs::write(
                generation.join("files/manifest.json"),
                serde_json::to_vec(
                    &serde_json::json!({"requiresQtModules": modules, "chromiumFlags": flags}),
                )
                .unwrap(),
            )
            .unwrap();
        }
        let mut runner = Runner {
            app_id: "com.example.same".to_owned(),
            install_root: first.clone(),
            ..Runner::default()
        };
        assert!(uses_webengine(&runner));
        assert_eq!(manifest(&runner).chromium_flags, "--first");
        let env = variables(&runner);
        assert!(env.contains(&("MARATHON_APP_GENERATION_ID", "com.example.same".to_owned())));
        assert!(env.contains(&("MARATHON_APP_GENERATION", "gen-first".to_owned())));
        runner.install_root = second;
        assert!(!uses_webengine(&runner));
        assert_eq!(manifest(&runner).chromium_flags, "--second");
        runner.install_root = first;
        assert_eq!(manifest(&runner).chromium_flags, "--first");
    }
}
