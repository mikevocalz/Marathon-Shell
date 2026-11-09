//! Serialized publication of complete, immutable app generations. The current
//! name is only a symlink; readers resolve it once, and runners keep that exact
//! generation. An old generation is never collected in the boot that used it.

use std::ffi::CString;
use std::fs::{self, File, OpenOptions};
use std::io;
use std::os::fd::{AsRawFd, FromRawFd};
use std::os::unix::ffi::OsStrExt;
use std::os::unix::fs::{MetadataExt, OpenOptionsExt, PermissionsExt};
use std::path::{Component, Path, PathBuf};

use serde_json::Value;

use crate::paths;

const MAX_GENERATIONS: usize = 8;

pub(crate) fn valid_id(id: &str) -> bool {
    !id.is_empty() && !id.starts_with('.') && !id.contains("..") && !id.contains(['/', '\\', '\0'])
}

fn invalid(message: &str) -> io::Error {
    io::Error::new(io::ErrorKind::InvalidData, message)
}

fn owned(metadata: &fs::Metadata) -> bool {
    // SAFETY: geteuid has no arguments or preconditions.
    metadata.uid() == unsafe { libc::geteuid() }
}

/// Refuse linked directories, including intermediate components. Storage paths
/// are local installer state, never paths supplied by an archive's manifest.
pub(crate) fn directory(path: &Path, create: bool) -> io::Result<()> {
    let mut ancestor = PathBuf::new();
    for part in path.components() {
        if matches!(part, Component::ParentDir) {
            return Err(invalid("parent component in storage path"));
        }
        ancestor.push(part);
        let metadata = match fs::symlink_metadata(&ancestor) {
            Ok(metadata) => metadata,
            Err(error) if create && error.kind() == io::ErrorKind::NotFound => {
                fs::create_dir(&ancestor)?;
                if let Some(parent) = ancestor.parent() {
                    sync_dir(parent)?;
                }
                fs::symlink_metadata(&ancestor)?
            }
            Err(error) => return Err(error),
        };
        if !metadata.is_dir() || metadata.file_type().is_symlink() {
            return Err(invalid("storage directory is a symlink or not a directory"));
        }
    }
    if !owned(&fs::symlink_metadata(path)?) {
        return Err(io::Error::new(
            io::ErrorKind::PermissionDenied,
            "storage is owned by another user",
        ));
    }
    Ok(())
}

pub(crate) fn sync_dir(path: &Path) -> io::Result<()> {
    OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_DIRECTORY | libc::O_NOFOLLOW | libc::O_CLOEXEC)
        .open(path)?
        .sync_all()
}

pub(crate) fn read_json(path: &Path) -> io::Result<Value> {
    let file = OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_NOFOLLOW | libc::O_CLOEXEC)
        .open(path)?;
    if !file.metadata()?.is_file() {
        return Err(invalid("metadata is not a regular file"));
    }
    serde_json::from_reader(file).map_err(io::Error::other)
}

pub(crate) fn write_json(path: &Path, value: &Value) -> io::Result<()> {
    let parent = path
        .parent()
        .ok_or_else(|| invalid("missing metadata parent"))?;
    let mut file = tempfile::NamedTempFile::new_in(parent)?;
    serde_json::to_writer_pretty(&mut file, value)?;
    file.as_file().sync_all()?;
    file.persist(path).map_err(|error| error.error)?;
    sync_dir(parent)
}

pub(crate) fn boot_id() -> io::Result<String> {
    let id = fs::read_to_string("/proc/sys/kernel/random/boot_id")?;
    let id = id.trim();
    if !valid_boot_id(id) {
        return Err(invalid(
            "cannot identify this boot; retaining app generations",
        ));
    }
    Ok(id.to_owned())
}

pub(crate) fn valid_boot_id(id: &str) -> bool {
    id.len() == 36
        && id.bytes().enumerate().all(|(index, byte)| {
            if [8, 13, 18, 23].contains(&index) {
                byte == b'-'
            } else {
                byte.is_ascii_hexdigit()
            }
        })
}

pub(crate) struct LockedApp {
    pub(crate) root: PathBuf,
    pub(crate) id: String,
    pub(crate) boot: String,
    _lock: File,
}

impl LockedApp {
    pub(crate) fn acquire(id: &str) -> io::Result<Self> {
        Self::at(paths::user_installs(), id, boot_id()?)
    }

    pub(crate) fn at(root: PathBuf, id: &str, boot: String) -> io::Result<Self> {
        if !valid_id(id) || !valid_boot_id(&boot) {
            return Err(invalid("invalid app ID"));
        }
        directory(&root, true)?;
        let locks = root.join(".locks");
        directory(&locks, true)?;
        let locks = locks.join(id);
        directory(&locks, true)?;
        let lock = OpenOptions::new()
            .read(true)
            .write(true)
            .create(true)
            .truncate(false)
            .mode(0o600)
            .custom_flags(libc::O_NOFOLLOW | libc::O_CLOEXEC)
            .open(locks.join("lock"))?;
        let metadata = lock.metadata()?;
        if !metadata.is_file() || !owned(&metadata) || metadata.nlink() != 1 {
            return Err(invalid("invalid app lock"));
        }
        // SAFETY: the descriptor belongs to lock, which outlives this call and
        // remains open until the transaction drops. Never block the UI thread.
        if unsafe { libc::flock(lock.as_raw_fd(), libc::LOCK_EX | libc::LOCK_NB) } != 0 {
            return Err(io::Error::last_os_error());
        }
        Ok(Self {
            root,
            id: id.to_owned(),
            boot,
            _lock: lock,
        })
    }

    pub(crate) fn current(&self) -> PathBuf {
        self.root.join(&self.id)
    }

    pub(crate) fn generations(&self) -> PathBuf {
        self.root.join(".generations").join(&self.id)
    }

    pub(crate) fn pending(&self) -> io::Result<PathBuf> {
        let dir = self.root.join(".cleanup");
        directory(&dir, true)?;
        Ok(dir.join(format!("{}.json", self.id)))
    }

    pub(crate) fn selected(&self) -> io::Result<Option<PathBuf>> {
        resolve(&self.root, &self.id)
    }

    /// An interrupted stage or replaced generation can still be bound by a
    /// runner. Only a different boot proves that no such process survives.
    pub(crate) fn prepare(&self) -> io::Result<()> {
        let parent = self.root.join(".generations");
        directory(&parent, true)?;
        let generations = self.generations();
        directory(&generations, true)?;
        if fs::metadata(&generations)?.dev() != fs::metadata(&self.root)?.dev() {
            return Err(invalid(
                "generation staging and publication must use the same filesystem",
            ));
        }
        let current = self.selected()?;
        let mut count = 0;
        for entry in fs::read_dir(&generations)? {
            let entry = entry?;
            let path = entry.path();
            let name = entry.file_name();
            let name = name
                .to_str()
                .ok_or_else(|| invalid("invalid generation name"))?;
            // An interrupted legacy exchange can leave its not-yet-published
            // pointer here. Only that exact managed pointer is recoverable.
            if name.starts_with("gen-legacy-gen-") && entry.file_type()?.is_symlink() {
                let target = fs::read_link(&path)?;
                if !valid_pointer(&target, &self.id) || !owned(&fs::symlink_metadata(&path)?) {
                    return Err(invalid(
                        "foreign legacy publication pointer; preserved for recovery",
                    ));
                }
                fs::remove_file(path)?;
                continue;
            }
            if !name.starts_with("gen-") || !entry.file_type()?.is_dir() {
                return Err(invalid(
                    "unrecognized generation state; preserved for recovery",
                ));
            }
            let retention = read_json(&path.join("retention.json"));
            let prior_boot = retention
                .as_ref()
                .ok()
                .and_then(|r| r["bootId"].as_str())
                .filter(|boot| valid_boot_id(boot));
            if current.as_ref() != Some(&path)
                && prior_boot.is_some_and(|boot| boot != self.boot)
                && retention.as_ref().is_ok_and(|r| r["id"] == self.id)
            {
                remove_directory(&path)?;
            } else {
                count += 1;
            }
        }
        sync_dir(&generations)?;
        if count >= MAX_GENERATIONS {
            return Err(io::Error::new(io::ErrorKind::StorageFull,
                "retained generation limit reached; restart and retry, or recover unrecognized interrupted staging"));
        }
        Ok(())
    }

    pub(crate) fn stage(&self) -> io::Result<tempfile::TempDir> {
        self.prepare()?;
        let stage = tempfile::Builder::new()
            .prefix("gen-")
            .tempdir_in(self.generations())?;
        self.retain(stage.path())?;
        Ok(stage)
    }

    fn retain(&self, generation: &Path) -> io::Result<()> {
        write_json(
            &generation.join("retention.json"),
            &serde_json::json!({"id": self.id, "bootId": self.boot}),
        )
    }

    /// The generation is already fully synced. Publication changes one name;
    /// once renamed, failures must be reported as committed, never rolled back.
    pub(crate) fn publish(&self, generation: &Path) -> Result<(), PublishError> {
        self.publish_with(generation, |_| Ok(()))
    }

    fn publish_with(
        &self,
        generation: &Path,
        mut checkpoint: impl FnMut(&str) -> io::Result<()>,
    ) -> Result<(), PublishError> {
        let name = generation
            .file_name()
            .ok_or_else(|| PublishError::Before(invalid("missing generation")))?;
        if generation.parent() != Some(self.generations().as_path()) {
            return Err(PublishError::Before(invalid("foreign generation")));
        }
        sync_tree(generation).map_err(PublishError::Before)?;
        sync_dir(&self.generations()).map_err(PublishError::Before)?;
        checkpoint("generation-synced").map_err(PublishError::Before)?;
        let pending = self.root.join(".locks").join(&self.id);
        let pointer = pending.join("next");
        match fs::read_link(&pointer) {
            Ok(target) if valid_pointer(&target, &self.id) => {
                fs::remove_file(&pointer).map_err(PublishError::Before)?;
            }
            Ok(_) => {
                return Err(PublishError::Before(invalid(
                    "foreign pending publication; preserved for recovery",
                )))
            }
            Err(error) if error.kind() == io::ErrorKind::NotFound => {}
            Err(error) => return Err(PublishError::Before(error)),
        }
        let target = Path::new(".generations").join(&self.id).join(name);
        std::os::unix::fs::symlink(target, &pointer).map_err(PublishError::Before)?;
        sync_dir(&pending).map_err(PublishError::Before)?;
        checkpoint("before-publish").map_err(PublishError::Before)?;
        let exists = match fs::symlink_metadata(self.current()) {
            Ok(metadata) if !metadata.file_type().is_symlink() => {
                return Err(PublishError::Before(invalid(
                    "legacy installation requires migration and a device restart",
                )));
            }
            Ok(_) => {
                if let Some(old) = self.selected().map_err(PublishError::Before)? {
                    self.retain(&old).map_err(PublishError::Before)?;
                }
                true
            }
            Err(error) if error.kind() == io::ErrorKind::NotFound => false,
            Err(error) => return Err(PublishError::Before(error)),
        };
        rename_with_flags(
            &pointer,
            &self.current(),
            if exists { 0 } else { libc::RENAME_NOREPLACE },
        )
        .map_err(PublishError::Before)?;
        checkpoint("published").map_err(PublishError::Committed)?;
        sync_dir(&pending).map_err(PublishError::Committed)?;
        sync_dir(&self.root).map_err(PublishError::Committed)?;
        checkpoint("publication-synced").map_err(PublishError::Committed)?;
        Ok(())
    }

    /// Atomically replace a legacy directory with the copied generation. The
    /// directory at the old name remains for existing bind mounts. Unconfined
    /// old runners require the restart barrier recorded in the new receipt.
    pub(crate) fn normalize(&self, generation: &Path) -> Result<(), PublishError> {
        sync_tree(generation).map_err(PublishError::Before)?;
        sync_dir(&self.generations()).map_err(PublishError::Before)?;
        let target = Path::new(".generations").join(&self.id).join(
            generation
                .file_name()
                .ok_or_else(|| PublishError::Before(invalid("missing generation")))?,
        );
        self.retain(&self.current()).map_err(PublishError::Before)?;
        let previous = self.generations().join(format!(
            "gen-legacy-{}",
            generation.file_name().unwrap_or_default().to_string_lossy()
        ));
        std::os::unix::fs::symlink(target, &previous).map_err(PublishError::Before)?;
        if let Err(error) = rename_with_flags(&previous, &self.current(), libc::RENAME_EXCHANGE) {
            fs::remove_file(previous).map_err(PublishError::Before)?;
            return Err(PublishError::Before(error));
        }
        sync_dir(&self.root).map_err(PublishError::Committed)?;
        sync_dir(&self.generations()).map_err(PublishError::Committed)?;
        Ok(())
    }

    pub(crate) fn unpublish(&self) -> io::Result<()> {
        match fs::symlink_metadata(self.current()) {
            Ok(metadata) if metadata.file_type().is_symlink() => {
                if let Some(old) = self.selected()? {
                    self.retain(&old)?;
                }
                fs::remove_file(self.current())?;
                sync_dir(&self.root)
            }
            Err(error) if error.kind() == io::ErrorKind::NotFound => Ok(()),
            Ok(_) => Err(invalid(
                "legacy installation requires migration before removal",
            )),
            Err(error) => Err(error),
        }
    }
}

fn rename_with_flags(from: &Path, to: &Path, flags: libc::c_uint) -> io::Result<()> {
    let from = CString::new(from.as_os_str().as_bytes()).map_err(io::Error::other)?;
    let to = CString::new(to.as_os_str().as_bytes()).map_err(io::Error::other)?;
    // SAFETY: both NUL-terminated paths stay live for the syscall. Linux
    // performs the requested no-replace or exchange atomically; unsupported
    // filesystems fail without a destructive fallback.
    if unsafe {
        libc::renameat2(
            libc::AT_FDCWD,
            from.as_ptr(),
            libc::AT_FDCWD,
            to.as_ptr(),
            flags,
        )
    } != 0
    {
        return Err(io::Error::last_os_error());
    }
    Ok(())
}

#[derive(Debug)]
pub(crate) enum PublishError {
    Before(io::Error),
    Committed(io::Error),
}

/// Only installer-owned relative pointers are followed. A substituted link to
/// another app, an arbitrary directory, or a linked intermediate is rejected.
pub(crate) fn resolve(root: &Path, id: &str) -> io::Result<Option<PathBuf>> {
    if !valid_id(id) {
        return Err(invalid("invalid app ID"));
    }
    let current = root.join(id);
    let metadata = match fs::symlink_metadata(&current) {
        Err(error) if error.kind() == io::ErrorKind::NotFound => return Ok(None),
        other => other?,
    };
    if metadata.is_dir() {
        directory(&current, false)?;
        return Ok(Some(current));
    }
    if !metadata.file_type().is_symlink() || !owned(&metadata) {
        return Err(invalid("invalid current generation pointer"));
    }
    let target = fs::read_link(&current)?;
    if !valid_pointer(&target, id) {
        return Err(invalid("foreign generation pointer"));
    }
    let generation = root.join(target);
    directory(&generation, false)?;
    Ok(Some(generation))
}

fn valid_pointer(target: &Path, id: &str) -> bool {
    let mut parts = target.components();
    parts
        .next()
        .is_some_and(|part| part.as_os_str() == ".generations")
        && parts.next().is_some_and(|part| part.as_os_str() == id)
        && parts.next().is_some_and(|part| {
            part.as_os_str()
                .to_str()
                .is_some_and(|name| name.starts_with("gen-") && valid_id(name))
        })
        && parts.next().is_none()
}

pub(crate) fn sync_tree(root: &Path) -> io::Result<()> {
    for entry in walkdir::WalkDir::new(root).contents_first(true) {
        let entry = entry?;
        if entry.file_type().is_dir() {
            sync_dir(entry.path())?;
        } else if entry.file_type().is_file() {
            OpenOptions::new()
                .read(true)
                .custom_flags(libc::O_NOFOLLOW | libc::O_CLOEXEC)
                .open(entry.path())?
                .sync_all()?;
        } else {
            return Err(invalid("symlinks and special files are not installable"));
        }
    }
    Ok(())
}

pub(crate) fn open_directory(from: &Path) -> io::Result<File> {
    let mut source = OpenOptions::new()
        .read(true)
        .custom_flags(libc::O_DIRECTORY | libc::O_CLOEXEC)
        .open(if from.is_absolute() {
            Path::new("/")
        } else {
            Path::new(".")
        })?;
    for part in from.components() {
        match part {
            Component::RootDir | Component::CurDir => {}
            Component::Normal(name) => {
                source = open_child(&source, name, libc::O_DIRECTORY)?;
            }
            _ => return Err(invalid("parent components are not installable")),
        }
    }
    Ok(source)
}

/// Anchor every ancestor before deletion. Rust's `remove_dir_all` then walks the
/// subtree relative to that held directory, never a replaceable ancestor path.
pub(crate) fn remove_directory(path: &Path) -> io::Result<()> {
    let parent = path
        .parent()
        .ok_or_else(|| invalid("missing removal parent"))?;
    let name = path
        .file_name()
        .ok_or_else(|| invalid("missing removal name"))?;
    let parent = open_directory(parent)?;
    let target = open_child(&parent, name, libc::O_DIRECTORY)?;
    if !owned(&target.metadata()?) {
        return Err(invalid("directory is owned by another user"));
    }
    let anchored = PathBuf::from(format!("/proc/self/fd/{}", parent.as_raw_fd())).join(name);
    if let Err(error) = fs::remove_dir_all(&anchored) {
        if error.kind() == io::ErrorKind::NotFound {
            match fs::symlink_metadata(&anchored) {
                Ok(_) => {
                    return Err(io::Error::other(
                        "partial deletion; app directory still exists",
                    ))
                }
                Err(probe) if probe.kind() == io::ErrorKind::NotFound => {}
                Err(probe) => return Err(probe),
            }
        }
        return Err(error);
    }
    parent.sync_all()
}

pub(crate) fn copy_tree(from: &Path, to: &Path) -> io::Result<()> {
    copy_directory(&open_directory(from)?, to)
}

fn open_child(parent: &File, name: &std::ffi::OsStr, flags: i32) -> io::Result<File> {
    let name = CString::new(name.as_bytes()).map_err(io::Error::other)?;
    // SAFETY: parent is live; name is a single NUL-terminated component from a
    // directory entry. O_NOFOLLOW prevents replacement by a link at open time.
    let fd = unsafe {
        libc::openat(
            parent.as_raw_fd(),
            name.as_ptr(),
            libc::O_RDONLY | libc::O_NOFOLLOW | libc::O_CLOEXEC | libc::O_NONBLOCK | flags,
        )
    };
    if fd < 0 {
        return Err(io::Error::last_os_error());
    }
    // SAFETY: openat returned a new descriptor, transferred exactly once.
    Ok(unsafe { File::from_raw_fd(fd) })
}

fn copy_directory(source: &File, to: &Path) -> io::Result<()> {
    fs::create_dir(to)?;
    // /proc resolves our already-open directory, never a mutable source path.
    for entry in fs::read_dir(format!("/proc/self/fd/{}", source.as_raw_fd()))? {
        let entry = entry?;
        let mut child = open_child(source, &entry.file_name(), 0)?;
        let metadata = child.metadata()?;
        let target = to.join(entry.file_name());
        if metadata.is_dir() {
            copy_directory(&child, &target)?;
        } else if metadata.is_file() {
            let mut destination = OpenOptions::new()
                .write(true)
                .create_new(true)
                .mode(0o600)
                .open(target)?;
            io::copy(&mut child, &mut destination)?;
            destination.set_permissions(fs::Permissions::from_mode(metadata.mode() & 0o777))?;
            destination.sync_all()?;
        } else {
            return Err(invalid("symlinks and special files are not installable"));
        }
    }
    sync_dir(to)?;
    Ok(())
}

#[cfg(test)]
#[allow(
    clippy::unwrap_used,
    clippy::expect_used,
    reason = "test fixture failures should identify the failed operation"
)]
mod tests {
    use super::*;
    use std::os::unix::process::ExitStatusExt;
    use std::process::Command;

    const A: &str = "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa";
    const B: &str = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb";
    const C: &str = "cccccccc-cccc-cccc-cccc-cccccccccccc";
    const ID: &str = "com.example.notes";

    fn lock(root: &Path, boot: &str) -> LockedApp {
        LockedApp::at(root.to_path_buf(), ID, boot.to_owned()).unwrap()
    }

    fn generation(locked: &LockedApp, version: &str) -> PathBuf {
        let stage = locked.stage().unwrap();
        fs::create_dir(stage.path().join("files")).unwrap();
        write_json(
            &stage.path().join("receipt.json"),
            &serde_json::json!({"id": ID, "version": version, "permissions": [version]}),
        )
        .unwrap();
        write_json(&stage.path().join("files/manifest.json"), &serde_json::json!({"id": ID, "name": "Notes", "entryPoint": "main.qml", "version": version})).unwrap();
        fs::write(stage.path().join("files/main.qml"), version).unwrap();
        stage.keep()
    }

    fn assert_version(root: &Path, version: &str) {
        assert_eq!(
            read_json(&root.join("receipt.json")).unwrap()["version"],
            version
        );
        assert_eq!(
            read_json(&root.join("files/manifest.json")).unwrap()["version"],
            version
        );
        assert_eq!(
            fs::read_to_string(root.join("files/main.qml")).unwrap(),
            version
        );
    }

    #[test]
    fn publishes_one_complete_generation_and_keeps_snapshot_paths() {
        let tmp = tempfile::tempdir().unwrap();
        let locked = lock(tmp.path(), A);
        let old = generation(&locked, "1");
        locked.publish(&old).unwrap();
        let snapshot = locked.selected().unwrap().unwrap();
        let new = generation(&locked, "2");
        locked.publish(&new).unwrap();
        assert_version(&locked.selected().unwrap().unwrap(), "2");
        assert_version(&snapshot, "1");
        locked.prepare().unwrap();
        assert_version(&snapshot, "1");
    }

    #[test]
    fn retirement_boot_protects_apps_installed_on_an_earlier_boot() {
        let tmp = tempfile::tempdir().unwrap();
        let old = {
            let locked = lock(tmp.path(), A);
            let old = generation(&locked, "1");
            locked.publish(&old).unwrap();
            old
        };
        {
            let locked = lock(tmp.path(), B);
            let new = generation(&locked, "2");
            locked.publish(&new).unwrap();
            locked.prepare().unwrap();
            assert_version(&old, "1");
        }
        let locked = lock(tmp.path(), C);
        locked.prepare().unwrap();
        assert!(!old.exists());
        assert_version(&locked.selected().unwrap().unwrap(), "2");
    }

    #[test]
    fn failures_before_publication_keep_old_and_failures_after_are_committed() {
        for checkpoint in [
            "generation-synced",
            "before-publish",
            "published",
            "publication-synced",
        ] {
            let tmp = tempfile::tempdir().unwrap();
            let locked = lock(tmp.path(), A);
            let old = generation(&locked, "1");
            locked.publish(&old).unwrap();
            let new = generation(&locked, "2");
            let result = locked.publish_with(&new, |step| {
                if step == checkpoint {
                    Err(io::Error::from_raw_os_error(libc::ENOSPC))
                } else {
                    Ok(())
                }
            });
            let committed = ["published", "publication-synced"].contains(&checkpoint);
            assert_eq!(matches!(result, Err(PublishError::Committed(_))), committed);
            assert_ne!(matches!(result, Err(PublishError::Before(_))), committed);
            assert_version(
                &locked.selected().unwrap().unwrap(),
                if committed { "2" } else { "1" },
            );
            assert_version(&old, "1");
        }
    }

    #[test]
    fn process_worker() {
        let Some(root) = std::env::var_os("MARATHON_TEST_TRANSACTION_ROOT") else {
            return;
        };
        let root = PathBuf::from(root);
        let mode = std::env::var("MARATHON_TEST_TRANSACTION_MODE").unwrap();
        if mode == "busy" {
            assert!(LockedApp::at(root, ID, A.to_owned())
                .is_err_and(|e| e.kind() == io::ErrorKind::WouldBlock));
            return;
        }
        let locked = lock(&root, A);
        if mode == "lock" {
            return;
        }
        let new = generation(&locked, "2");
        let _result = locked.publish_with(&new, |step| {
            if step == mode {
                // SAFETY: this isolated test process kills only itself. The
                // parent verifies the actual filesystem without Drop cleanup.
                unsafe {
                    libc::kill(libc::getpid(), libc::SIGKILL);
                }
            }
            Ok(())
        });
        unreachable!("the requested crash checkpoint must be reached");
    }

    fn worker(root: &Path, mode: &str) -> std::process::ExitStatus {
        Command::new(std::env::current_exe().unwrap())
            .args([
                "--exact",
                "transaction::tests::process_worker",
                "--nocapture",
            ])
            .env("MARATHON_TEST_TRANSACTION_ROOT", root)
            .env("MARATHON_TEST_TRANSACTION_MODE", mode)
            .status()
            .unwrap()
    }

    #[test]
    fn process_death_at_each_publication_boundary_is_recoverable() {
        for checkpoint in [
            "generation-synced",
            "before-publish",
            "published",
            "publication-synced",
        ] {
            let tmp = tempfile::tempdir().unwrap();
            {
                let locked = lock(tmp.path(), A);
                let old = generation(&locked, "1");
                locked.publish(&old).unwrap();
            }
            assert_eq!(worker(tmp.path(), checkpoint).signal(), Some(libc::SIGKILL));
            let locked = lock(tmp.path(), B);
            let version = if ["published", "publication-synced"].contains(&checkpoint) {
                "2"
            } else {
                "1"
            };
            assert_version(&locked.selected().unwrap().unwrap(), version);
            locked.prepare().unwrap();
            locked.prepare().unwrap();
            assert_version(&locked.selected().unwrap().unwrap(), version);
            assert_eq!(fs::read_dir(locked.generations()).unwrap().count(), 1);
        }
    }

    #[test]
    fn competing_process_cannot_install_or_remove_locked_app() {
        let tmp = tempfile::tempdir().unwrap();
        let locked = lock(tmp.path(), A);
        assert!(worker(tmp.path(), "busy").success());
        assert!(LockedApp::at(tmp.path().to_path_buf(), "another.app", A.to_owned()).is_ok());
        drop(locked);
        assert!(worker(tmp.path(), "lock").success());
    }

    #[test]
    fn retention_limit_refuses_without_deleting_live_generations() {
        let tmp = tempfile::tempdir().unwrap();
        let locked = lock(tmp.path(), A);
        for index in 0..MAX_GENERATIONS {
            let next = generation(&locked, &index.to_string());
            locked.publish(&next).unwrap();
        }
        assert!(locked.stage().is_err());
        assert_eq!(
            fs::read_dir(locked.generations()).unwrap().count(),
            MAX_GENERATIONS
        );
        assert_version(
            &locked.selected().unwrap().unwrap(),
            &(MAX_GENERATIONS - 1).to_string(),
        );
    }

    #[test]
    fn foreign_links_and_invalid_boot_identity_are_preserved() {
        let tmp = tempfile::tempdir().unwrap();
        let foreign = tempfile::tempdir().unwrap();
        fs::write(foreign.path().join("sentinel"), "private").unwrap();
        std::os::unix::fs::symlink(foreign.path(), tmp.path().join(ID)).unwrap();
        let locked = lock(tmp.path(), A);
        assert!(locked.selected().is_err());
        assert!(locked.unpublish().is_err());
        assert_eq!(
            fs::read_to_string(foreign.path().join("sentinel")).unwrap(),
            "private"
        );
        drop(locked);
        assert!(LockedApp::at(tmp.path().to_path_buf(), ID, String::new()).is_err());
        assert!(!valid_boot_id("aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa"));
    }

    #[test]
    fn directory_copy_never_follows_source_symlinks() {
        let tmp = tempfile::tempdir().unwrap();
        let source = tmp.path().join("source");
        fs::create_dir(&source).unwrap();
        fs::write(tmp.path().join("foreign"), "secret").unwrap();
        std::os::unix::fs::symlink(tmp.path().join("foreign"), source.join("link")).unwrap();
        assert!(copy_tree(&source, &tmp.path().join("destination")).is_err());
        assert!(!tmp.path().join("destination/link").exists());
    }
}
