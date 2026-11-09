//! Public install/scan/uninstall journeys run in separate processes so XDG and
//! runner generation variables never race the rest of the Rust test suite.

#![allow(
    clippy::unwrap_used,
    clippy::expect_used,
    reason = "fixture and child-process failures are test failures"
)]

use std::fs;
use std::path::Path;
use std::process::Command;

use serde_json::json;

use crate::{apps, archive, cleanup, install, paths, signature, transaction};

const ID: &str = "com.example.lifecycle";
const NEXT_BOOT: &str = "bbbbbbbb-bbbb-bbbb-bbbb-bbbbbbbbbbbb";

fn source(path: &Path, version: &str, keep: bool, permissions: &[&str]) {
    fs::create_dir_all(path).unwrap();
    transaction::write_json(
        &path.join("manifest.json"),
        &json!({
            "id": ID, "name": "Lifecycle", "version": version, "entryPoint": "main.qml",
            "permissions": permissions, "icon": "icon.svg",
            "dataLifecycle": {"appData": if keep { "keep" } else { "remove" }}
        }),
    )
    .unwrap();
    fs::write(path.join("main.qml"), version).unwrap();
    fs::write(path.join("icon.svg"), "<svg/>").unwrap();
}

fn child(mode: &str) -> Command {
    let mut command = Command::new(std::env::current_exe().unwrap());
    command
        .args(["--exact", "lifecycle_tests::journey_worker", "--nocapture"])
        .env("MARATHON_TEST_JOURNEY", mode);
    command
}

fn isolated(mode: &str) {
    let fixture = tempfile::tempdir().unwrap();
    let status = child(mode)
        .env("XDG_DATA_HOME", fixture.path().join("data"))
        .env("XDG_CONFIG_HOME", fixture.path().join("config"))
        .env("XDG_CACHE_HOME", fixture.path().join("cache"))
        .env("MARATHON_APPS_DIR", fixture.path().join("system"))
        .env(
            "MARATHON_SYSTEM_KEYS_DIR",
            fixture.path().join("system-keys"),
        )
        .env("MARATHON_ALLOW_UNSIGNED", "1")
        .env_remove("MARATHON_APP_GENERATION")
        .env_remove("MARATHON_APP_GENERATION_ID")
        .status()
        .unwrap();
    assert!(status.success(), "public journey {mode} failed: {status}");
}

#[test]
fn public_update_and_scanner_share_complete_retained_generations() {
    isolated("update");
}

#[test]
fn public_uninstall_retains_active_files_and_retries_partial_cleanup() {
    isolated("remove");
}

#[test]
fn keep_policy_and_foreign_data_survive_uninstall() {
    isolated("keep");
}

#[test]
fn legacy_conversion_requires_restart_before_replacement_or_removal() {
    isolated("legacy");
}

#[test]
fn interrupted_uninstall_refreshes_boot_barrier_if_app_was_still_published() {
    isolated("interrupted");
}

#[test]
fn signed_updates_keep_system_policy_and_preserve_bundled_app_data() {
    isolated("signed");
}

#[test]
fn newer_generation_retention_also_defers_writable_cleanup() {
    isolated("retained");
}

#[test]
fn journey_worker() {
    let Ok(mode) = std::env::var("MARATHON_TEST_JOURNEY") else {
        return;
    };
    if mode == "snapshot" {
        let app = apps::find(ID).unwrap();
        assert_eq!(app.version, "1");
        assert_eq!(app.permissions, Vec::<String>::new());
        assert_eq!(fs::read_to_string(app.path.join("main.qml")).unwrap(), "1");
        return;
    }
    if mode == "signed_snapshot" {
        let app = apps::find(ID).unwrap();
        assert_eq!(app.version, "2");
        assert!(app.is_system);
        assert!(!app.install_root.as_os_str().is_empty());
        return;
    }
    if mode == "invalid_snapshot" || mode == "catalogue_fallback" {
        if mode == "invalid_snapshot" {
            assert!(apps::find(ID).is_none());
        } else {
            let app = apps::find(ID).unwrap();
            assert_eq!(app.version, "1");
            assert!(app.install_root.as_os_str().is_empty());
        }
        let app = apps::scan().into_iter().find(|app| app.id == ID).unwrap();
        assert_eq!(app.version, "1");
        assert!(app.install_root.as_os_str().is_empty());
        return;
    }
    let fixture = tempfile::tempdir().unwrap();
    let package = fixture.path().join("source");
    source(&package, "1", mode == "keep", &[]);
    install::install_directory(&package, &[]).unwrap();
    let first = apps::find(ID).unwrap();
    assert_eq!(apps::scan().len(), 1);
    for path in [
        paths::data_dir(ID),
        paths::cache_dir(ID),
        paths::config_dir(ID),
    ] {
        fs::create_dir_all(&path).unwrap();
        fs::write(path.join("sentinel"), "owned data").unwrap();
    }
    match mode.as_str() {
        "update" => update(&package, &first),
        "legacy" => legacy(&package, &first),
        "remove" | "keep" => remove(&package, &first, mode == "keep"),
        "interrupted" => interrupted(&first),
        "signed" => signed(&package, &first),
        "retained" => retained(&first),
        _ => unreachable!("unknown journey"),
    }
}

fn update(package: &Path, first: &apps::App) {
    source(package, "2", false, &["network"]);
    fs::remove_file(package.join("main.qml")).unwrap();
    assert!(
        matches!(install::install_directory(package, &["network".to_owned()]), Err(install::Refusal::Failed(message)) if message.contains("entryPoint"))
    );
    assert_eq!(apps::find(ID).unwrap().version, "1");
    fs::write(package.join("main.qml"), "2").unwrap();
    assert!(matches!(
        install::install_directory(package, &[]),
        Err(install::Refusal::Held(_))
    ));
    assert_eq!(apps::find(ID).unwrap().version, "1");
    {
        let _locked = transaction::LockedApp::acquire(ID).unwrap();
        assert!(install::install_directory(package, &["network".to_owned()]).is_err());
        assert!(install::uninstall(ID).is_err());
    }
    install::install_directory(package, &["network".to_owned()]).unwrap();
    let second = apps::find(ID).unwrap();
    assert_eq!(second.version, "2");
    assert_eq!(second.permissions, ["network"]);
    assert_ne!(first.install_root, second.install_root);
    assert_eq!(
        fs::read_to_string(first.path.join("main.qml")).unwrap(),
        "1"
    );
    assert_eq!(apps::scan().len(), 1);
    assert!(child("snapshot")
        .env("MARATHON_APP_GENERATION_ID", ID)
        .env(
            "MARATHON_APP_GENERATION",
            first.install_root.file_name().unwrap()
        )
        .status()
        .unwrap()
        .success());
    std::os::unix::fs::symlink(first.path.join("main.qml"), package.join("foreign")).unwrap();
    assert!(install::install_directory(package, &["network".to_owned()]).is_err());
    assert_eq!(apps::find(ID).unwrap().version, "2");
}

fn remove(package: &Path, first: &apps::App, keep: bool) {
    let report = install::uninstall(ID).unwrap();
    assert!(report.unpublished());
    assert!(!report.complete());
    assert!(!report.filesystem_complete());
    assert!(apps::find(ID).is_none());
    assert!(install::can_uninstall(ID));
    assert!(first.path.join("main.qml").exists());
    assert!(paths::cache_dir(ID).join("sentinel").exists());
    assert!(install::uninstall(ID).unwrap().unpublished());
    assert!(install::install_directory(package, &[]).is_err());
    // A malicious or accidental data-root symlink must retain its target and
    // report only that failed category while completing independent cleanup.
    let foreign = tempfile::tempdir().unwrap();
    fs::write(foreign.path().join("private"), "foreign data").unwrap();
    fs::remove_dir_all(paths::cache_dir(ID)).unwrap();
    std::os::unix::fs::symlink(foreign.path(), paths::cache_dir(ID)).unwrap();
    {
        let locked =
            transaction::LockedApp::at(paths::user_installs(), ID, NEXT_BOOT.to_owned()).unwrap();
        let retried = cleanup::uninstall_locked(&locked).unwrap();
        assert!(matches!(retried.cache, install::CleanupState::Failed(_)));
        assert!(matches!(retried.app_files, install::CleanupState::Removed));
        assert_eq!(paths::data_dir(ID).exists(), keep);
        assert_eq!(paths::config_dir(ID).exists(), keep);
        assert!(!retried.filesystem_complete());
    }
    assert_eq!(
        fs::read_to_string(foreign.path().join("private")).unwrap(),
        "foreign data"
    );
    assert!(install::install_directory(package, &[]).is_err());
    fs::remove_file(paths::cache_dir(ID)).unwrap();
    {
        let locked =
            transaction::LockedApp::at(paths::user_installs(), ID, NEXT_BOOT.to_owned()).unwrap();
        let retried = cleanup::uninstall_locked(&locked).unwrap();
        assert!(retried.filesystem_complete());
        assert!(!retried.complete());
        assert!(matches!(
            retried.secrets,
            install::CleanupState::Unsupported(_)
        ));
        assert!(cleanup::uninstall_locked(&locked)
            .unwrap()
            .filesystem_complete());
    }
    install::install_directory(package, &[]).unwrap();
    assert!(apps::find(ID).is_some());
    assert!(paths::cache_dir(ID).symlink_metadata().is_err());
}

fn legacy(package: &Path, first: &apps::App) {
    fs::remove_file(paths::install_dir(ID)).unwrap();
    transaction::copy_tree(&first.install_root, &paths::install_dir(ID)).unwrap();
    source(package, "2", false, &[]);
    assert!(
        matches!(install::install_directory(package, &[]), Err(install::Refusal::Failed(message)) if message.contains("restart"))
    );
    let migrated = apps::find(ID).unwrap();
    assert_eq!(migrated.version, "1");
    assert!(migrated
        .install_root
        .file_name()
        .unwrap()
        .to_string_lossy()
        .starts_with("gen-"));
    assert!(install::uninstall(ID).unwrap_err().contains("restart"));
    assert!(
        matches!(install::install_directory(package, &[]), Err(install::Refusal::Failed(message)) if message.contains("restart"))
    );
    assert!(apps::find(ID).is_some());
}

fn interrupted(first: &apps::App) {
    let locked =
        transaction::LockedApp::at(paths::user_installs(), ID, NEXT_BOOT.to_owned()).unwrap();
    transaction::write_json(
        &locked.pending().unwrap(),
        &json!({
            "id": ID, "generation": first.install_root.file_name().unwrap().to_string_lossy(),
            "bootId": "aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa", "keep": false
        }),
    )
    .unwrap();
    let report = cleanup::uninstall_locked(&locked).unwrap();
    assert!(report.unpublished());
    assert!(matches!(report.cache, install::CleanupState::Deferred(_)));
    assert!(first.path.join("main.qml").exists());
    assert_eq!(
        transaction::read_json(&locked.pending().unwrap()).unwrap()["bootId"],
        NEXT_BOOT
    );
}

fn signed(package: &Path, first: &apps::App) {
    source(&paths::system_app(ID), "1", false, &[]);
    source(package, "2", false, &[]);
    assert!(
        matches!(install::install_directory(package, &[]), Err(install::Refusal::Failed(message)) if message.contains("system app"))
    );
    assert_eq!(
        fs::read_to_string(first.path.join("main.qml")).unwrap(),
        "1"
    );
    let fixture = tempfile::tempdir().unwrap();
    let secret = fixture.path().join("system.key");
    fs::create_dir_all(paths::system_keys()).unwrap();
    let signer = signature::keygen(&secret, &paths::system_keys().join("system.pub")).unwrap();
    let archive = fixture.path().join("app.marathon");
    archive::create(package, &archive).unwrap();
    signature::sign(&archive, &secret).unwrap();
    let plan = install::install_package(&archive, &[]).unwrap();
    assert_eq!(plan.signer, signer);
    let second = apps::find(ID).unwrap();
    assert_eq!(second.version, "2");
    let token = second.install_root.file_name().unwrap();
    // A launch snapshot stays on its selected code even if the catalogue's
    // preferred OS version changes before the runner resolves it.
    source(&paths::system_app(ID), "3", false, &[]);
    assert_eq!(apps::find(ID).unwrap().version, "3");
    assert!(child("signed_snapshot")
        .env("MARATHON_APP_GENERATION_ID", ID)
        .env("MARATHON_APP_GENERATION", token)
        .status()
        .unwrap()
        .success());
    source(&paths::system_app(ID), "1", false, &[]);
    for relative in ["receipt.json", "files/manifest.json"] {
        let path = second.install_root.join(relative);
        let saved = path.with_extension("saved");
        fs::rename(&path, &saved).unwrap();
        assert_eq!(apps::find(ID).unwrap().version, "1");
        assert!(child("invalid_snapshot")
            .env("MARATHON_APP_GENERATION_ID", ID)
            .env("MARATHON_APP_GENERATION", token)
            .status()
            .unwrap()
            .success());
        // Another app's explicit token cannot change this catalogue lookup.
        assert!(child("catalogue_fallback")
            .env("MARATHON_APP_GENERATION_ID", "com.example.other")
            .env("MARATHON_APP_GENERATION", token)
            .status()
            .unwrap()
            .success());
        fs::rename(&saved, &path).unwrap();
    }
    fs::write(&archive, "tampered package").unwrap();
    assert!(install::install_package(&archive, &[]).is_err());
    assert_eq!(apps::find(ID).unwrap().version, "2");
    let report = install::uninstall(ID).unwrap();
    assert!(report.unpublished());
    assert!(report.system_app_remains);
    assert_eq!(apps::find(ID).unwrap().version, "1");
    let locked =
        transaction::LockedApp::at(paths::user_installs(), ID, NEXT_BOOT.to_owned()).unwrap();
    let report = cleanup::uninstall_locked(&locked).unwrap();
    assert!(report.filesystem_complete());
    for path in [
        paths::data_dir(ID),
        paths::cache_dir(ID),
        paths::config_dir(ID),
    ] {
        assert_eq!(
            fs::read_to_string(path.join("sentinel")).unwrap(),
            "owned data"
        );
    }
    drop(locked);
    source(package, "3", false, &[]);
    let mut manifest = transaction::read_json(&package.join("manifest.json")).unwrap();
    manifest["protected"] = json!(true);
    transaction::write_json(&package.join("manifest.json"), &manifest).unwrap();
    archive::create(package, &archive).unwrap();
    signature::sign(&archive, &secret).unwrap();
    install::install_package(&archive, &[]).unwrap();
    assert!(apps::find(ID).unwrap().is_protected);
    assert!(!install::can_uninstall(ID));
    assert!(install::uninstall(ID).is_err());
}

fn retained(first: &apps::App) {
    assert!(install::uninstall(ID).unwrap().unpublished());
    {
        let locked =
            transaction::LockedApp::at(paths::user_installs(), ID, NEXT_BOOT.to_owned()).unwrap();
        transaction::write_json(
            &first.install_root.join("retention.json"),
            &json!({"id": ID, "bootId": NEXT_BOOT}),
        )
        .unwrap();
        let report = cleanup::uninstall_locked(&locked).unwrap();
        assert!(matches!(
            report.app_files,
            install::CleanupState::Deferred(_)
        ));
        for state in [&report.data, &report.config, &report.cache] {
            assert!(matches!(state, install::CleanupState::Deferred(_)));
        }
        for path in [
            paths::data_dir(ID),
            paths::cache_dir(ID),
            paths::config_dir(ID),
        ] {
            assert_eq!(
                fs::read_to_string(path.join("sentinel")).unwrap(),
                "owned data"
            );
        }
    }
    let locked = transaction::LockedApp::at(
        paths::user_installs(),
        ID,
        "cccccccc-cccc-cccc-cccc-cccccccccccc".to_owned(),
    )
    .unwrap();
    assert!(cleanup::uninstall_locked(&locked)
        .unwrap()
        .filesystem_complete());
    assert!(!paths::data_dir(ID).exists());
    assert!(!paths::cache_dir(ID).exists());
    assert!(!paths::config_dir(ID).exists());
}
