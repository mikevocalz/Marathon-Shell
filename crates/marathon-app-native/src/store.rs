//! `AppInstaller`: uninstalls through the shell's `AppStore1`, and lists the
//! installed Flatpaks.

use std::collections::{BTreeSet, HashMap};
use std::pin::Pin;
use std::time::Duration;

use cxx_qt::{CxxQtType, Threading};
use cxx_qt_lib::{QList, QMap, QMapPair_QString_QVariant, QString, QStringList, QVariant};

use crate::shell::{relay, Service};
use marathon_rt::io;

mod query;
use query::Query;

#[cxx_qt::bridge(namespace = "marathon::platform")]
pub mod qobject {
    #[namespace = ""]
    unsafe extern "C++" {
        include!("cxx-qt-lib/qstring.h");
        type QString = cxx_qt_lib::QString;
        include!("cxx-qt-lib/qstringlist.h");
        type QStringList = cxx_qt_lib::QStringList;
        include!("cxx-qt-lib/qlist.h");
        type QList_QVariant = cxx_qt_lib::QList<cxx_qt_lib::QVariant>;
        include!("cxx-qt-lib/qmap.h");
        type QMap_QString_QVariant = cxx_qt_lib::QMap<cxx_qt_lib::QMapPair_QString_QVariant>;
    }

    extern "RustQt" {
        #[qobject]
        type AppInstaller = super::AppInstallerRust;

        #[qsignal]
        #[cxx_name = "uninstallComplete"]
        fn uninstall_complete(self: Pin<&mut Self>, app_id: &QString);
        #[qsignal]
        #[cxx_name = "uninstallFailed"]
        fn uninstall_failed(self: Pin<&mut Self>, app_id: &QString, error: &QString);
        #[qsignal]
        #[cxx_name = "uninstallPartial"]
        fn uninstall_partial(self: Pin<&mut Self>, app_id: &QString, detail: &QString);
        /// Any uninstall, this app's or not.
        #[qsignal]
        #[cxx_name = "appRemoved"]
        fn app_removed(self: Pin<&mut Self>, app_id: &QString);

        #[qsignal]
        #[cxx_name = "pendingUninstallsChanged"]
        fn pending_uninstalls_changed(self: Pin<&mut Self>);
        #[qsignal]
        #[cxx_name = "flatpakAppsChanged"]
        fn flatpak_apps_changed(self: Pin<&mut Self>);
        #[qsignal]
        #[cxx_name = "uninstallCapabilitiesChanged"]
        fn uninstall_capabilities_changed(self: Pin<&mut Self>);

        /// A cached capability; false until a successful capability refresh.
        #[qinvokable]
        #[cxx_name = "canUninstall"]
        fn can_uninstall(self: &AppInstaller, app_id: &QString) -> bool;
        /// Cached {available, loading, items: {appId: bool}, error}.
        #[qinvokable]
        #[cxx_name = "uninstallCapabilities"]
        fn uninstall_capabilities(self: &AppInstaller) -> QMap_QString_QVariant;
        /// Refreshes up to 1024 unique app IDs in one authorized request off
        /// the UI thread. The latest app list replaces a queued refresh's input.
        #[qinvokable]
        #[cxx_name = "refreshUninstallCapabilities"]
        fn refresh_uninstall_capabilities(self: Pin<&mut AppInstaller>, app_ids: &QStringList);
        #[qinvokable]
        #[cxx_name = "uninstallApp"]
        fn uninstall_app(self: Pin<&mut AppInstaller>, app_id: &QString);
        /// Cached [{id, name}]; use flatpakAppsState to distinguish an empty
        /// catalogue from an unavailable service, and refreshFlatpakApps for I/O.
        #[qinvokable]
        #[cxx_name = "flatpakApps"]
        fn flatpak_apps(self: &AppInstaller) -> QList_QVariant;
        /// Cached {available, loading, items: [{id, name}], error}.
        #[qinvokable]
        #[cxx_name = "flatpakAppsState"]
        fn flatpak_apps_state(self: &AppInstaller) -> QMap_QString_QVariant;
        #[qinvokable]
        #[cxx_name = "refreshFlatpakApps"]
        fn refresh_flatpak_apps(self: Pin<&mut AppInstaller>);
        /// Cached {available, loading, items: [{id, detail}], error}; never
        /// performs I/O. Subscribe to pendingUninstallsChanged, then refresh.
        #[qinvokable]
        #[cxx_name = "pendingUninstalls"]
        fn pending_uninstalls(self: &AppInstaller) -> QMap_QString_QVariant;
        /// Refreshes cleanup state off the UI thread. Concurrent requests
        /// coalesce; errors preserve the previous snapshot for retry.
        #[qinvokable]
        #[cxx_name = "refreshPendingUninstalls"]
        fn refresh_pending_uninstalls(self: Pin<&mut AppInstaller>);
    }

    impl cxx_qt::Threading for AppInstaller {}
    impl cxx_qt::Initialize for AppInstaller {}
}

use qobject::AppInstaller;

const STORE: Service = Service::shell("AppStore");

#[derive(Default)]
pub struct AppInstallerRust {
    /// Uninstalls this app asked for, which it hears the end of.
    pending: BTreeSet<String>,
    capabilities: Query<HashMap<String, bool>>,
    capability_ids: BTreeSet<String>,
    cleanup: Query<Vec<(String, String)>>,
    flatpaks: Query<Vec<(String, String)>>,
}

impl cxx_qt::Initialize for AppInstaller {
    fn initialize(self: Pin<&mut Self>) {
        let qt = self.qt_thread();
        relay(
            qt.clone(),
            STORE,
            "UninstallComplete",
            |mut obj, (id,): (String,)| {
                obj.as_mut().invalidate_capability(&id);
                let app = QString::from(&id);
                obj.as_mut().app_removed(&app);
                if obj.as_mut().rust_mut().pending.remove(&id) {
                    obj.uninstall_complete(&app);
                }
            },
        );
        relay(
            qt.clone(),
            STORE,
            "UninstallFailed",
            |mut obj, (id, error): (String, String)| {
                if obj.as_mut().rust_mut().pending.remove(&id) {
                    obj.uninstall_failed(&QString::from(&id), &QString::from(&error));
                }
            },
        );
        relay(
            qt,
            STORE,
            "UninstallPartial",
            |mut obj, (id, detail): (String, String)| {
                obj.as_mut().invalidate_capability(&id);
                let app = QString::from(&id);
                obj.as_mut().app_removed(&app);
                if obj.as_mut().rust_mut().pending.remove(&id) {
                    obj.uninstall_partial(&app, &QString::from(&detail));
                }
            },
        );
    }
}

impl AppInstaller {
    fn pending_uninstalls(&self) -> QMap<QMapPair_QString_QVariant> {
        let mut result = status(&self.cleanup);
        let list = records(self.cleanup.value.as_deref().unwrap_or_default(), "detail");
        result.insert(QString::from("items"), QVariant::from(&list));
        result
    }

    fn refresh_pending_uninstalls(mut self: Pin<&mut Self>) {
        if !self.as_mut().rust_mut().cleanup.begin() {
            return;
        }
        let qt = self.qt_thread();
        let task = async move {
            let result =
                match io::timeout(Duration::from_secs(15), STORE.ask("PendingUninstalls", &()))
                    .await
                {
                    Some(result) => result.map_err(|error| crate::shell::message(&error)),
                    None => Err("Cleanup status timed out; try again".into()),
                };
            // The guarded queue does not own the QObject; destroying the
            // client prevents delivery without retaining the page or engine.
            qt.queue(move |obj| obj.finish_cleanup(result)).ok();
        };
        if let Err(error) = io::try_spawn(task) {
            self.finish_cleanup(Err(format!("Cannot load cleanup status: {error}")));
            return;
        }
        self.pending_uninstalls_changed();
    }

    fn finish_cleanup(mut self: Pin<&mut Self>, result: Result<Vec<(String, String)>, String>) {
        if self.as_mut().rust_mut().cleanup.finish(result) {
            self.refresh_pending_uninstalls();
        } else {
            self.pending_uninstalls_changed();
        }
    }

    fn can_uninstall(&self, app_id: &QString) -> bool {
        self.capabilities
            .value
            .as_ref()
            .and_then(|known| known.get(&app_id.to_string()))
            .copied()
            .unwrap_or(false)
    }

    fn flatpak_apps(&self) -> QList<QVariant> {
        records(self.flatpaks.value.as_deref().unwrap_or_default(), "name")
    }

    fn flatpak_apps_state(&self) -> QMap<QMapPair_QString_QVariant> {
        let mut result = status(&self.flatpaks);
        result.insert(QString::from("items"), QVariant::from(&self.flatpak_apps()));
        result
    }

    fn refresh_flatpak_apps(mut self: Pin<&mut Self>) {
        if !self.as_mut().rust_mut().flatpaks.begin() {
            return;
        }
        let qt = self.qt_thread();
        let task = async move {
            let result =
                match io::timeout(Duration::from_secs(15), STORE.ask("FlatpakApps", &())).await {
                    Some(result) => result.map_err(|error| crate::shell::message(&error)),
                    None => Err("Installed Flatpak apps timed out; try again".into()),
                };
            qt.queue(move |obj| obj.finish_flatpaks(result)).ok();
        };
        if let Err(error) = io::try_spawn(task) {
            self.finish_flatpaks(Err(format!("Cannot load installed Flatpak apps: {error}")));
            return;
        }
        self.flatpak_apps_changed();
    }

    fn finish_flatpaks(mut self: Pin<&mut Self>, result: Result<Vec<(String, String)>, String>) {
        if self.as_mut().rust_mut().flatpaks.finish(result) {
            self.refresh_flatpak_apps();
        } else {
            self.flatpak_apps_changed();
        }
    }

    fn uninstall_capabilities(&self) -> QMap<QMapPair_QString_QVariant> {
        let mut result = status(&self.capabilities);
        let mut items = QMap::<QMapPair_QString_QVariant>::default();
        for (id, removable) in self.capabilities.value.iter().flatten() {
            items.insert(QString::from(id), QVariant::from(removable));
        }
        result.insert(QString::from("items"), QVariant::from(&items));
        result
    }

    fn refresh_uninstall_capabilities(mut self: Pin<&mut Self>, app_ids: &QStringList) {
        self.as_mut().rust_mut().capability_ids = QList::<QString>::from(app_ids)
            .iter()
            .map(ToString::to_string)
            .collect();
        self.refresh_capabilities();
    }

    fn refresh_capabilities(mut self: Pin<&mut Self>) {
        if !self.as_mut().rust_mut().capabilities.begin() {
            return;
        }
        let ids = self.capability_ids.clone();
        let qt = self.qt_thread();
        let task = async move {
            let result = match io::timeout(
                Duration::from_secs(15),
                STORE.ask("UninstallCapabilities", &(ids,)),
            )
            .await
            {
                Some(result) => result.map_err(|error| crate::shell::message(&error)),
                None => Err("App uninstall capabilities timed out; try again".into()),
            };
            qt.queue(move |obj| obj.finish_capabilities(result)).ok();
        };
        if let Err(error) = io::try_spawn(task) {
            self.finish_capabilities(Err(format!("Cannot load uninstall capabilities: {error}")));
            return;
        }
        self.uninstall_capabilities_changed();
    }

    fn finish_capabilities(
        mut self: Pin<&mut Self>,
        result: Result<HashMap<String, bool>, String>,
    ) {
        if self.as_mut().rust_mut().capabilities.finish(result) {
            self.refresh_capabilities();
        } else {
            self.uninstall_capabilities_changed();
        }
    }

    fn invalidate_capability(mut self: Pin<&mut Self>, app_id: &str) {
        let mut state = self.as_mut().rust_mut();
        state.capability_ids.remove(app_id);
        if let Some(known) = state.capabilities.value.as_mut() {
            known.remove(app_id);
        }
        if state.capabilities.loading() {
            state.capabilities.begin();
        }
        self.uninstall_capabilities_changed();
    }

    fn uninstall_app(mut self: Pin<&mut Self>, app_id: &QString) {
        let id = app_id.to_string();
        if self.pending.contains(&id) {
            return;
        }
        if self.pending.len() >= 8 {
            self.uninstall_failed(
                app_id,
                &QString::from("Too many pending uninstall requests; retry shortly"),
            );
            return;
        }
        self.as_mut().rust_mut().pending.insert(id.clone());
        let qt = self.qt_thread();
        let request_id = id.clone();
        let task = async move {
            if let Err(e) = STORE.reply("Uninstall", &(id.clone(),)).await {
                let error = QString::from(&crate::shell::message(&e));
                qt.queue(move |mut obj| {
                    if obj.as_mut().rust_mut().pending.remove(&id) {
                        obj.uninstall_failed(&QString::from(&id), &error);
                    }
                })
                .ok();
            }
        };
        if let Err(error) = io::try_spawn(task) {
            self.as_mut().rust_mut().pending.remove(&request_id);
            self.uninstall_failed(
                app_id,
                &QString::from(&format!("Cannot start uninstall: {error}")),
            );
        }
    }
}

fn status<T>(query: &Query<T>) -> QMap<QMapPair_QString_QVariant> {
    let mut result = QMap::<QMapPair_QString_QVariant>::default();
    result.insert(
        QString::from("available"),
        QVariant::from(&query.available()),
    );
    result.insert(QString::from("loading"), QVariant::from(&query.loading()));
    result.insert(
        QString::from("error"),
        QVariant::from(&QString::from(query.error.as_deref().unwrap_or(""))),
    );
    result
}

fn records(items: &[(String, String)], value_name: &str) -> QList<QVariant> {
    let mut list = QList::<QVariant>::default();
    for (id, value) in items {
        let mut map = QMap::<QMapPair_QString_QVariant>::default();
        map.insert(QString::from("id"), QVariant::from(&QString::from(id)));
        map.insert(
            QString::from(value_name),
            QVariant::from(&QString::from(value)),
        );
        list.append(QVariant::from(&map));
    }
    list
}
