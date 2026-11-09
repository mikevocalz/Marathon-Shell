//! Installing and removing the user's apps: a signed `.marathon` package (or,
//! for development, a directory) becomes `<user_installs>/<id>/files` plus a
//! receipt of the permissions the user approved.

use std::fs;
use std::path::{Path, PathBuf};

use serde_json::{json, Value};

use crate::{apps, archive, paths, permissions, signature, transaction};

/// What a permission means, for the install screen.
#[derive(Debug, Clone, PartialEq, Eq)]
pub struct Disclosure {
    pub id: String,
    pub label: String,
    pub detail: String,
    pub sensitive: bool,
}

/// What installing would do.
#[derive(Debug, Clone, PartialEq, Eq, Default)]
pub struct Plan {
    pub id: String,
    pub name: String,
    pub version: String,
    /// The signing key's id, empty if unsigned.
    pub signer: String,
    pub update: bool,
    pub permissions: Vec<Disclosure>,
    /// Permissions the installed version doesn't have.
    pub added: Vec<String>,
}

#[derive(Debug)]
pub enum Refusal {
    /// An update asks for permissions not in `approved`: install again with
    /// them once the user agrees.
    Held(Box<Plan>),
    Failed(String),
    /// The new generation is visible. Its parent-directory sync failed; retry
    /// recovery rather than reporting that the old app was restored.
    Committed {
        plan: Box<Plan>,
        detail: String,
    },
}

impl From<String> for Refusal {
    fn from(message: String) -> Self {
        Self::Failed(message)
    }
}

/// Security events go to the auth log, as the system's own do.
fn audit(priority: libc::c_int, message: &str) {
    let Ok(text) = std::ffi::CString::new(message) else {
        return;
    };
    // SAFETY: a constant format string and a NUL-terminated argument.
    unsafe { libc::syslog(libc::LOG_AUTH | priority, c"%s".as_ptr(), text.as_ptr()) };
}

/// `MARATHON_ALLOW_UNSIGNED=1`: the developer override for unsigned packages
/// and directory installs. Signatures that are present are still checked.
pub fn unsigned_allowed() -> bool {
    std::env::var("MARATHON_ALLOW_UNSIGNED").is_ok_and(|v| v == "1")
}

fn text<'a>(manifest: &'a Value, key: &str) -> &'a str {
    manifest
        .get(key)
        .and_then(Value::as_str)
        .unwrap_or_default()
}

fn permissions_of(manifest: &Value) -> Vec<String> {
    let mut list: Vec<String> = Vec::new();
    for p in manifest
        .get("permissions")
        .and_then(Value::as_array)
        .into_iter()
        .flatten()
        .filter_map(Value::as_str)
    {
        if !list.iter().any(|x| x == p) {
            list.push(p.to_owned());
        }
    }
    list
}

fn read_json(path: &Path) -> Option<Value> {
    serde_json::from_slice(&fs::read(path).ok()?)
        .ok()
        .filter(Value::is_object)
}

/// The manifest's id and entry point stay inside the app's own directory.
fn check_manifest(manifest: &Value) -> Result<String, Refusal> {
    let id = text(manifest, "id");
    if id.is_empty() || text(manifest, "name").is_empty() || text(manifest, "entryPoint").is_empty()
    {
        return Err("Invalid or missing manifest.json".to_owned().into());
    }
    crate::manifest::check_third_party_background(manifest)
        .map_err(|message| Refusal::Failed(message.to_owned()))?;
    if !transaction::valid_id(id) {
        audit(
            libc::LOG_ALERT,
            &format!("[SECURITY] Path traversal blocked: appId={id}"),
        );
        return Err("Invalid app ID".to_owned().into());
    }
    let entry = text(manifest, "entryPoint");
    if entry.contains("..") || entry.starts_with(['/', '\\']) {
        audit(
            libc::LOG_ALERT,
            &format!("[SECURITY] Path traversal blocked: app={id} entryPoint={entry}"),
        );
        return Err("Invalid entry point".to_owned().into());
    }
    Ok(id.to_owned())
}

/// An update that asks for permissions the installed version doesn't have
/// is held until those are in `approved`.
fn plan(manifest: &Value, signer: &str, approved: &[String]) -> Result<Plan, Refusal> {
    let id = text(manifest, "id").to_owned();
    let wanted = permissions_of(manifest);
    let mut disclosures = Vec::new();
    let mut undisclosed = Vec::new();
    for p in &wanted {
        match permissions::describe(p) {
            Some(d) => disclosures.push(Disclosure {
                id: p.clone(),
                label: d.label.clone(),
                detail: d.description.clone(),
                sensitive: d.sensitive,
            }),
            None => undisclosed.push(p.clone()),
        }
    }
    if !undisclosed.is_empty() {
        let list = undisclosed.join(", ");
        audit(
            libc::LOG_ALERT,
            &format!("[SECURITY] Undisclosed permissions refused: app={id} perms={list}"),
        );
        return Err(format!("Permissions with no description: {list}").into());
    }
    // A copy of an OS app adds to what the OS's copy was allowed.
    let installed = read_json(&paths::receipt(&id))
        .or_else(|| read_json(&paths::system_app(&id).join("manifest.json")));
    let added: Vec<String> = installed.as_ref().map_or_else(Vec::new, |r| {
        let had = permissions_of(r);
        wanted
            .iter()
            .filter(|p| !had.contains(p))
            .cloned()
            .collect()
    });
    let plan = Plan {
        name: text(manifest, "name").to_owned(),
        version: text(manifest, "version").to_owned(),
        signer: signer.to_owned(),
        update: installed.is_some(),
        permissions: disclosures,
        added,
        id,
    };
    if plan.added.iter().all(|p| approved.contains(p)) {
        Ok(plan)
    } else {
        audit(
            libc::LOG_NOTICE,
            &format!(
                "[SECURITY] Update held for consent: app={} new perms={}",
                plan.id,
                plan.added.join(", ")
            ),
        );
        Err(Refusal::Held(Box::new(plan)))
    }
}

/// The receipt is what the user approved: the permissions the plan disclosed
/// and, for an update, consented to. The scanner trusts it, not the manifest.
fn write_receipt(
    root: &Path,
    manifest: &Value,
    signer: &str,
    migrated: bool,
    boot: &str,
) -> std::io::Result<()> {
    let mut receipt = json!({"id": text(manifest, "id"), "version": text(manifest, "version"), "signer": signer, "permissions": permissions_of(manifest), "bootId": boot});
    if migrated {
        receipt["migrated"] = Value::Bool(true);
    }
    transaction::write_json(&root.join("receipt.json"), &receipt)
}

/// Only Marathon's own key may replace an app the OS ships, and only with a
/// newer version than the OS's and the one already installed beside it.
fn may_replace_os_app(id: &str, version: &str, signer: &str) -> Result<(), String> {
    let Some(os) = apps::system(id) else {
        return Ok(());
    };
    if !apps::is_system_signer(signer) {
        return Err("A system app has this id".to_owned());
    }
    if !apps::is_newer(version, &os.version) {
        return Err(format!(
            "The system's {id} {} is not older than {version}",
            os.version
        ));
    }
    let installed = read_json(&paths::receipt(id));
    let installed = installed
        .as_ref()
        .map(|r| text(r, "version"))
        .unwrap_or_default();
    if apps::is_newer(installed, version) {
        return Err(format!(
            "{id} {installed} is installed, newer than {version}"
        ));
    }
    Ok(())
}

fn place(
    source: &Path,
    signer: &str,
    approved: &[String],
    migrated: bool,
) -> Result<Plan, Refusal> {
    let original = read_json(&source.join("manifest.json"))
        .ok_or_else(|| "Invalid or missing manifest.json".to_owned())?;
    let id = check_manifest(&original)?;
    let locked = transaction::LockedApp::acquire(&id)
        .map_err(|e| format!("Cannot lock {id} for installation: {e}"))?;
    let pending = locked.pending().map_err(|e| e.to_string())?;
    crate::cleanup::allow_reinstall(&pending, &id).map_err(Refusal::Failed)?;
    if let Some(current) = locked.selected().map_err(|e| e.to_string())? {
        let receipt =
            transaction::read_json(&current.join("receipt.json")).map_err(|e| e.to_string())?;
        if current == locked.current() {
            normalize_legacy(&locked).map_err(Refusal::Failed)?;
            return Err(
                "Legacy installation migrated safely; restart the device before updating it"
                    .to_owned()
                    .into(),
            );
        }
        if receipt["legacyBoot"].as_str() == Some(&locked.boot) {
            return Err(
                "Legacy installation migrated safely; restart the device before updating it"
                    .to_owned()
                    .into(),
            );
        }
    }
    let stage = locked
        .stage()
        .map_err(|e| format!("Cannot stage {id}: {e}"))?;
    transaction::copy_tree(source, &stage.path().join("files"))
        .map_err(|e| format!("Failed to stage app files; installed version retained: {e}"))?;
    // Plan from the private staged copy, not the mutable developer directory.
    let manifest = read_json(&stage.path().join("files/manifest.json"))
        .ok_or_else(|| "Invalid staged manifest.json".to_owned())?;
    if check_manifest(&manifest)? != id {
        return Err("App ID changed while staging".to_owned().into());
    }
    let entry = stage
        .path()
        .join("files")
        .join(text(&manifest, "entryPoint"));
    if !fs::symlink_metadata(&entry).is_ok_and(|metadata| metadata.is_file()) {
        return Err(
            "Staged entryPoint must name an existing regular file; installed version retained"
                .to_owned()
                .into(),
        );
    }
    let plan = plan(&manifest, signer, approved)?;
    may_replace_os_app(&id, text(&manifest, "version"), signer)?;
    write_receipt(stage.path(), &manifest, signer, migrated, &locked.boot)
        .map_err(|e| format!("Failed to record staged installation: {e}"))?;
    // Keep the generation before publication: a post-rename failure must never
    // let TempDir remove the newly visible installation.
    let generation = stage.keep();
    match locked.publish(&generation) {
        Ok(()) => Ok(plan),
        Err(transaction::PublishError::Before(error)) => {
            let cleanup = fs::remove_dir_all(&generation);
            let suffix = cleanup.err().map_or_else(String::new, |e| format!("; staging cleanup failed: {e}"));
            Err(format!("Installation not published; previous version retained: {error}{suffix}").into())
        }
        Err(transaction::PublishError::Committed(error)) => Err(Refusal::Committed {
            plan: Box::new(plan),
            detail: format!("New app generation is visible, but publication durability requires recovery: {error}"),
        }),
    }
}

pub(crate) fn normalize_legacy(locked: &transaction::LockedApp) -> Result<(), String> {
    let current = locked.current();
    let mut receipt =
        transaction::read_json(&current.join("receipt.json")).map_err(|e| e.to_string())?;
    if receipt["id"] != locked.id {
        return Err("Legacy receipt does not match app ID".to_owned());
    }
    let stage = locked.stage().map_err(|e| e.to_string())?;
    transaction::copy_tree(&current.join("files"), &stage.path().join("files"))
        .map_err(|e| e.to_string())?;
    receipt["bootId"] = Value::String(locked.boot.clone());
    receipt["legacyBoot"] = Value::String(locked.boot.clone());
    transaction::write_json(&stage.path().join("receipt.json"), &receipt)
        .map_err(|e| e.to_string())?;
    // The retained legacy directory also needs its ownership/boot record for
    // collection after restart; changing these fields never changes approval.
    transaction::write_json(&current.join("receipt.json"), &receipt).map_err(|e| e.to_string())?;
    let generation = stage.keep();
    match locked.normalize(&generation) {
        Ok(()) => Ok(()),
        Err(transaction::PublishError::Before(e)) => {
            Err(format!("Legacy migration was not published: {e}"))
        }
        Err(transaction::PublishError::Committed(e)) => Err(format!(
            "Legacy migration is visible; durability recovery required: {e}"
        )),
    }
}

/// A copy of `package` (and its signature) checked and unpacked in a private
/// directory, so the archive can't be swapped between the two.
pub fn install_package(package: &Path, approved: &[String]) -> Result<Plan, Refusal> {
    let tmp =
        tempfile::tempdir().map_err(|e| format!("Failed to create a temporary directory: {e}"))?;
    let copy = tmp.path().join("package.marathon");
    fs::copy(package, &copy).map_err(|e| format!("Failed to read package: {e}"))?;
    let sig = signature::signature_path(package);
    if sig.exists() {
        fs::copy(&sig, signature::signature_path(&copy))
            .map_err(|e| format!("Failed to read package: {e}"))?;
    }
    let signer = verify(&copy)?;
    let extracted = tmp.path().join("extracted");
    archive::extract(&copy, &extracted).map_err(|e| {
        audit(
            libc::LOG_ALERT,
            &format!(
                "[SECURITY] Package refused: package={} reason={e}",
                package.display()
            ),
        );
        format!("Failed to extract package: {e}")
    })?;
    place(&extracted, &signer, approved, false)
}

/// Development only (`MARATHON_ALLOW_UNSIGNED=1`): a directory is not signed.
pub fn install_directory(dir: &Path, approved: &[String]) -> Result<Plan, Refusal> {
    if !unsigned_allowed() {
        audit(
            libc::LOG_ALERT,
            &format!(
                "[SECURITY] Unsigned directory install refused: dir={}",
                dir.display()
            ),
        );
        return Err("A directory is not signed: install a signed package, or set MARATHON_ALLOW_UNSIGNED=1 for development".to_owned().into());
    }
    audit(
        libc::LOG_WARNING,
        &format!(
            "[SECURITY] Unsigned directory install allowed by MARATHON_ALLOW_UNSIGNED: dir={}",
            dir.display()
        ),
    );
    place(dir, "", approved, false)
}

/// The signing key's id, empty for an unsigned package the developer
/// override admits.
pub fn verify(package: &Path) -> Result<String, String> {
    use signature::Verdict;
    let dirs = paths::trusted_keys();
    let dirs: Vec<&Path> = dirs.iter().map(PathBuf::as_path).collect();
    let verdict = signature::TrustStore::load(&dirs).map_or_else(
        |e| Verdict::Failed(format!("Failed to load trusted keys: {e}")),
        |store| signature::verify(package, &store),
    );
    let refused = match verdict {
        Verdict::Valid(id) => {
            audit(
                libc::LOG_INFO,
                &format!(
                    "[SECURITY] Package signature verified: package={} key={id}",
                    package.display()
                ),
            );
            return Ok(id);
        }
        Verdict::Unsigned if unsigned_allowed() => {
            audit(
                libc::LOG_WARNING,
                &format!(
                    "[SECURITY] Unsigned package allowed by MARATHON_ALLOW_UNSIGNED: package={}",
                    package.display()
                ),
            );
            return Ok(String::new());
        }
        Verdict::Unsigned => "Package is not signed (no .minisig signature beside it)".to_owned(),
        Verdict::InvalidSignature(detail) => format!("Invalid signature: {detail}"),
        Verdict::UntrustedKey(id) => format!("Package is signed by key {id}, which is not trusted"),
        Verdict::RevokedKey(id) => format!("Package is signed by key {id}, which is revoked"),
        Verdict::Failed(detail) => format!("Signature verification failed: {detail}"),
    };
    audit(
        libc::LOG_ALERT,
        &format!(
            "[SECURITY] Package rejected: package={} reason={refused}",
            package.display()
        ),
    );
    Err(format!("Package verification failed: {refused}"))
}

/// Removes superseded pointers under the same lock as installs and uninstalls.
/// Generations remain available to running apps until a later boot collects them.
pub fn remove_superseded() -> Vec<String> {
    let mut removed = Vec::new();
    for id in apps::superseded() {
        let result = (|| {
            let locked = transaction::LockedApp::acquire(&id).map_err(|e| e.to_string())?;
            if !apps::superseded().contains(&id) {
                return Ok(false);
            }
            if locked.selected().map_err(|e| e.to_string())? == Some(locked.current()) {
                normalize_legacy(&locked)?;
            }
            if read_json(&paths::receipt(&id))
                .is_some_and(|receipt| receipt["legacyBoot"].as_str() == Some(&locked.boot))
            {
                return Err("Legacy installation retained until device restart".to_owned());
            }
            locked.unpublish().map_err(|e| e.to_string())?;
            Ok::<_, String>(true)
        })();
        match result {
            Ok(true) => removed.push(id),
            Ok(false) => {}
            Err(e) => audit(
                libc::LOG_WARNING,
                &format!("Superseded app retained: app={id} reason={e}"),
            ),
        }
    }
    removed
}

pub fn can_uninstall(app_id: &str) -> bool {
    if !transaction::valid_id(app_id) {
        return false;
    }
    if paths::user_installs()
        .join(".cleanup")
        .join(format!("{app_id}.json"))
        .is_file()
    {
        return true;
    }
    let root = paths::selected_install(app_id).ok().flatten();
    apps::find(app_id)
        .is_some_and(|a| !a.is_protected && root.is_some_and(|r| a.path == r.join("files")))
}

pub use crate::cleanup::{pending_uninstalls, uninstall, CleanupState, UninstallReport};

/// Copy former writable installs into the generation store under the app lock.
/// The old directory remains app data. Permission grants from a formerly claimed
/// protected flag are invalidated by the caller.
pub fn migrate_legacy_installs() -> Vec<String> {
    for entry in fs::read_dir(paths::user_installs())
        .into_iter()
        .flatten()
        .flatten()
    {
        let Ok(id) = entry.file_name().into_string() else {
            continue;
        };
        if !transaction::valid_id(&id) || !entry.file_type().is_ok_and(|kind| kind.is_dir()) {
            continue;
        }
        let normalized = transaction::LockedApp::acquire(&id)
            .map_err(|e| e.to_string())
            .and_then(|locked| normalize_legacy(&locked));
        if let Err(error) = normalized {
            audit(
                libc::LOG_WARNING,
                &format!("Legacy app needs recovery before launch: app={id} reason={error}"),
            );
        }
    }
    let legacy = paths::legacy_installs();
    if fs::canonicalize(&legacy).ok() == fs::canonicalize(paths::system_apps()).ok() {
        return Vec::new();
    }
    let mut claimed = Vec::new();
    for entry in fs::read_dir(&legacy).into_iter().flatten().flatten() {
        let Ok(id) = entry.file_name().into_string() else {
            continue;
        };
        if !transaction::valid_id(&id) || !entry.file_type().is_ok_and(|t| t.is_dir()) {
            continue;
        }
        let Some(manifest) = read_json(&entry.path().join("manifest.json")) else {
            continue;
        };
        if text(&manifest, "id") != id
            || paths::install_dir(&id).exists()
            || paths::system_app(&id).join("manifest.json").exists()
        {
            continue;
        }
        match place(&entry.path(), "", &[], true) {
            Ok(_) => {
                if manifest.get("protected").and_then(Value::as_bool) == Some(true) {
                    claimed.push(id);
                }
            }
            Err(e) => audit(
                libc::LOG_WARNING,
                &format!("Legacy install retained: app={id} reason={e:?}"),
            ),
        }
    }
    claimed
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn user_installs_cannot_silently_accept_unsupported_schedules() {
        let mut manifest =
            json!({"id": "com.example.notes", "name": "Notes", "entryPoint": "NotesApp.qml"});
        assert!(check_manifest(&manifest).is_ok());
        manifest["backgroundTasks"] = json!([]);
        assert!(check_manifest(&manifest).is_ok());
        manifest["backgroundTasks"] =
            json!([{ "id": "sync", "action": "notes.sync", "intervalMinutes": 60 }]);
        assert!(
            matches!(check_manifest(&manifest), Err(Refusal::Failed(message)) if message.contains("third-party task registration is not supported"))
        );
        manifest["backgroundTasks"] = json!(true);
        assert!(check_manifest(&manifest).is_err());
    }
}
