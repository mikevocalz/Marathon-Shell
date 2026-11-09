//! Uninstall publishes its intent before hiding an app. Cleanup is retryable
//! after that name disappears, and never deletes a newly installed app's data.

use std::fs;
use std::path::Path;

use serde::{Deserialize, Serialize};
use serde_json::{json, Value};

use crate::{apps, install, paths, transaction};

#[derive(Clone, Debug, PartialEq, Eq, Serialize, Deserialize)]
#[serde(rename_all = "camelCase", tag = "state", content = "detail")]
pub enum CleanupState {
    Removed,
    Absent,
    Retained,
    Deferred(String),
    Failed(String),
    Unsupported(String),
}

impl CleanupState {
    fn finished(&self) -> bool {
        matches!(self, Self::Removed | Self::Absent | Self::Retained)
    }
}

/// `installation` describes the published app name. `app_files` describes the
/// retained generations separately: hiding an app is not deleting its bytes.
#[derive(Clone, Debug, Serialize, Deserialize)]
#[serde(rename_all = "camelCase")]
pub struct UninstallReport {
    pub app_id: String,
    pub installation: CleanupState,
    pub app_files: CleanupState,
    pub cache: CleanupState,
    pub data: CleanupState,
    pub config: CleanupState,
    pub settings: CleanupState,
    pub secrets: CleanupState,
    pub recovery: Option<String>,
    pub system_app_remains: bool,
}

impl UninstallReport {
    pub fn unpublished(&self) -> bool {
        matches!(
            self.installation,
            CleanupState::Removed | CleanupState::Absent
        )
    }

    pub fn filesystem_complete(&self) -> bool {
        self.recovery.is_none()
            && self.unpublished()
            && [&self.app_files, &self.cache, &self.data, &self.config]
                .iter()
                .all(|state| state.finished())
    }

    pub fn complete(&self) -> bool {
        self.filesystem_complete() && self.settings.finished() && self.secrets.finished()
    }

    /// Consumers must display partial outcomes, and rescan/revoke grants when
    /// unpublished even if cleanup could not finish.
    pub fn summary(&self) -> String {
        let mut notes = Vec::new();
        for (category, state) in [
            ("installation", &self.installation),
            ("app files", &self.app_files),
            ("cache", &self.cache),
            ("data", &self.data),
            ("config", &self.config),
            ("settings", &self.settings),
            ("secrets", &self.secrets),
        ] {
            match state {
                CleanupState::Deferred(detail)
                | CleanupState::Failed(detail)
                | CleanupState::Unsupported(detail) => notes.push(format!("{category}: {detail}")),
                _ => {}
            }
        }
        if self.unpublished() {
            notes.insert(
                0,
                if self.system_app_remains {
                    "Installed update removed; system app remains"
                } else {
                    "App removed from launcher"
                }
                .to_owned(),
            );
        }
        if let Some(recovery) = &self.recovery {
            notes.push(recovery.clone());
        }
        notes.join("; ")
    }
}

fn pending(reason: &str) -> CleanupState {
    CleanupState::Deferred(reason.to_owned())
}

fn remove_owned(path: &Path) -> CleanupState {
    match transaction::remove_directory(path) {
        Ok(()) => CleanupState::Removed,
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => CleanupState::Absent,
        Err(error) => CleanupState::Failed(error.to_string()),
    }
}

fn remove_generations(locked: &transaction::LockedApp) -> CleanupState {
    let generations = locked.generations();
    let check = (|| {
        transaction::directory(&generations, false)?;
        for entry in fs::read_dir(&generations)? {
            let entry = entry?;
            if !entry.file_type()?.is_dir() {
                return Err(std::io::Error::other(
                    "unrecognized retained app files; preserved for recovery",
                ));
            }
            let record = transaction::read_json(&entry.path().join("retention.json"))?;
            if record["id"] != locked.id
                || !record["bootId"]
                    .as_str()
                    .is_some_and(transaction::valid_boot_id)
            {
                return Err(std::io::Error::other(
                    "unrecognized retained generation ownership; preserved for recovery",
                ));
            }
            if record["bootId"].as_str() == Some(&locked.boot) {
                return Ok(false);
            }
        }
        Ok(true)
    })();
    match check {
        Ok(true) => remove_owned(&generations),
        Ok(false) => pending("a generation may still be running; retry after device restart"),
        Err(error)
            if error.kind() == std::io::ErrorKind::NotFound
                && fs::symlink_metadata(&generations)
                    .is_err_and(|probe| probe.kind() == std::io::ErrorKind::NotFound) =>
        {
            CleanupState::Absent
        }
        Err(error) => CleanupState::Failed(format!("Retained app files need recovery: {error}")),
    }
}

/// Unpublish now, retain code and writable directories until a subsequent boot
/// proves old runners are gone. A pending record blocks reinstall of the same
/// ID, preventing a retry from deleting a new installation's data.
pub fn uninstall(app_id: &str) -> Result<UninstallReport, String> {
    let locked = transaction::LockedApp::acquire(app_id)
        .map_err(|e| format!("Cannot lock app for removal: {e}"))?;
    uninstall_locked(&locked)
}

/// Retryable removals remain discoverable after their launcher entries vanish.
pub fn pending_uninstalls() -> Result<Vec<(String, String)>, String> {
    let dir = paths::user_installs().join(".cleanup");
    match transaction::directory(&dir, false) {
        Ok(()) => {}
        Err(error) if error.kind() == std::io::ErrorKind::NotFound => return Ok(Vec::new()),
        Err(error) => return Err(format!("Cleanup state unavailable: {error}")),
    }
    let mut pending = Vec::new();
    for entry in fs::read_dir(dir).map_err(|error| error.to_string())? {
        let entry = entry.map_err(|error| error.to_string())?;
        let path = entry.path();
        let Some(id) = path
            .file_stem()
            .and_then(|name| name.to_str())
            .filter(|id| transaction::valid_id(id))
        else {
            continue;
        };
        let job = transaction::read_json(&path)
            .map_err(|error| format!("Cleanup record for {id} needs recovery: {error}"))?;
        if job["id"] != id {
            return Err(format!("Cleanup record identity mismatch for {id}"));
        }
        match serde_json::from_value::<UninstallReport>(job["report"].clone()) {
            Ok(report) if report.app_id != id => {
                return Err(format!("Cleanup report identity mismatch for {id}"))
            }
            Ok(report) if report.filesystem_complete() => {}
            Ok(report) => pending.push((id.to_owned(), report.summary())),
            Err(_error) => pending.push((
                id.to_owned(),
                "Interrupted uninstall; retry cleanup".to_owned(),
            )),
        }
    }
    pending.sort();
    Ok(pending)
}

fn load_job(locked: &transaction::LockedApp, job_path: &Path) -> Result<Value, String> {
    match transaction::read_json(job_path) {
        Ok(job) => Ok(job),
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => {
            if !install::can_uninstall(&locked.id) {
                return Err(if apps::find(&locked.id).is_some() {
                    "Cannot uninstall a protected or system app"
                } else {
                    "App not found"
                }
                .to_owned());
            }
            let mut root = locked
                .selected()
                .map_err(|e| e.to_string())?
                .ok_or_else(|| "App not found".to_owned())?;
            if root == locked.current() {
                install::normalize_legacy(locked)?;
                root = locked
                    .selected()
                    .map_err(|e| e.to_string())?
                    .ok_or_else(|| "Legacy migration did not publish".to_owned())?;
            }
            if transaction::read_json(&root.join("receipt.json")).map_err(|e| e.to_string())?
                ["legacyBoot"]
                .as_str()
                == Some(&locked.boot)
            {
                return Err("Legacy installation migrated safely; restart the device before uninstalling it".to_owned());
            }
            let manifest = transaction::read_json(&root.join("files/manifest.json"))
                .map_err(|e| e.to_string())?;
            let keep = manifest
                .pointer("/dataLifecycle/appData")
                .and_then(Value::as_str)
                == Some("keep");
            let job = json!({"id": locked.id, "generation": root.file_name().unwrap_or_default().to_string_lossy(), "bootId": locked.boot, "keep": keep});
            transaction::write_json(job_path, &job)
                .map_err(|e| format!("Cannot record uninstall intent; app retained: {e}"))?;
            Ok(job)
        }
        Err(e) => Err(format!("Cannot read pending cleanup; app retained: {e}")),
    }
}

pub(crate) fn uninstall_locked(locked: &transaction::LockedApp) -> Result<UninstallReport, String> {
    let job_path = locked.pending().map_err(|e| e.to_string())?;
    let mut job = load_job(locked, &job_path)?;
    if job["id"] != locked.id
        || !job["bootId"]
            .as_str()
            .is_some_and(transaction::valid_boot_id)
        || !job["generation"]
            .as_str()
            .is_some_and(|token| token.starts_with("gen-") && transaction::valid_id(token))
        || job["keep"].as_bool().is_none()
    {
        return Err("Invalid cleanup record; retained for recovery".to_owned());
    }
    if let Some(current) = locked.selected().map_err(|e| e.to_string())? {
        if current.file_name().and_then(|s| s.to_str()) != job["generation"].as_str() {
            return Err("Cleanup belongs to another installation; data retained".to_owned());
        }
        // A crash may have left the app published across a reboot. It could
        // have been launched again, so the older intent boot proves nothing.
        if job["bootId"].as_str() != Some(&locked.boot) {
            job["bootId"] = Value::String(locked.boot.clone());
            transaction::write_json(&job_path, &job)
                .map_err(|e| format!("Cannot refresh cleanup barrier; app retained: {e}"))?;
        }
    }
    let mut report = UninstallReport {
        app_id: locked.id.clone(),
        installation: CleanupState::Absent,
        app_files: pending("retained until device restart"),
        cache: pending("retry after device restart"),
        data: pending("retry after device restart"),
        config: pending("retry after device restart"),
        settings: CleanupState::Unsupported(
            "shared settings cleanup is not implemented".to_owned(),
        ),
        secrets: CleanupState::Unsupported(
            "no app-owned secret inventory; secrets retained".to_owned(),
        ),
        recovery: None,
        system_app_remains: apps::system(&locked.id).is_some(),
    };
    let existed = fs::symlink_metadata(locked.current()).is_ok();
    if let Err(error) = locked.unpublish() {
        // Removal can have committed before directory fsync failed. Preserve
        // that distinction so consumers still revoke grants and refresh apps.
        if !fs::symlink_metadata(locked.current())
            .is_err_and(|error| error.kind() == std::io::ErrorKind::NotFound)
        {
            report.installation = CleanupState::Failed(error.to_string());
            return Ok(report);
        }
        report.installation = CleanupState::Absent;
        report.recovery = Some(format!(
            "Unpublished, but directory durability needs recovery: {error}"
        ));
        return Ok(report);
    }
    if existed {
        report.installation = CleanupState::Removed;
    }
    // Removing an installed OS-app update exposes the bundled app again. That
    // app still owns the same writable directories, including its cache.
    let keep = job["keep"].as_bool() == Some(true) || report.system_app_remains;
    if keep {
        report.data = CleanupState::Retained;
        report.config = CleanupState::Retained;
        report.settings = CleanupState::Retained;
    }
    if job["bootId"].as_str() != Some(&locked.boot) {
        report.app_files = remove_generations(locked);
        report.cache = if report.system_app_remains {
            CleanupState::Retained
        } else {
            remove_owned(&paths::cache_dir(&locked.id))
        };
        if !keep {
            report.data = remove_owned(&paths::data_dir(&locked.id));
            report.config = remove_owned(&paths::config_dir(&locked.id));
        }
    }
    job["report"] = serde_json::to_value(&report).map_err(|e| e.to_string())?;
    if let Err(error) = transaction::write_json(&job_path, &job) {
        report.recovery = Some(format!(
            "App unpublished; cannot persist cleanup outcome, retry required: {error}"
        ));
    }
    Ok(report)
}

/// Called under the installation lock. Only completed filesystem cleanup may
/// stop blocking a reinstall; shared stores remain explicitly unsupported.
pub(crate) fn allow_reinstall(path: &Path, app_id: &str) -> Result<(), String> {
    let job = match transaction::read_json(path) {
        Ok(job) => job,
        Err(e) if e.kind() == std::io::ErrorKind::NotFound => return Ok(()),
        Err(e) => return Err(e.to_string()),
    };
    let report: UninstallReport = serde_json::from_value(job["report"].clone()).map_err(|_error| "Uninstall cleanup is pending; restart the device and retry cleanup before reinstalling this app".to_owned())?;
    if job["id"] != app_id
        || report.app_id != app_id
        || !job["bootId"]
            .as_str()
            .is_some_and(transaction::valid_boot_id)
        || !job["generation"]
            .as_str()
            .is_some_and(|token| token.starts_with("gen-") && transaction::valid_id(token))
    {
        return Err(
            "Cleanup record identity does not match this app; retained for recovery".to_owned(),
        );
    }
    if !report.filesystem_complete() {
        return Err("Uninstall cleanup is pending; restart the device and retry cleanup before reinstalling this app".to_owned());
    }
    fs::remove_file(path).map_err(|e| e.to_string())?;
    transaction::sync_dir(
        path.parent()
            .ok_or_else(|| "Missing cleanup directory".to_owned())?,
    )
    .map_err(|e| e.to_string())
}
