pragma ComponentBehavior: Bound
import QtQuick
import Sailfish.Silica 1.0
import Marathon.Silica 1.0
import Marathon.Platform 1.0
import MarathonOS.Settings 1.0
import "../SettingsLogic.js" as Logic

Page {
    id: page

    // Names by app id, kept for the notice after the app has left the list.
    property var removing: ({})
    // Set by the "appmanager/<appId>" route: that app's page opens over the list.
    property string focusAppId
    property var pendingUninstalls: []
    property string cleanupError
    property bool cleanupLoading
    property var uninstallCapabilities: ({})
    property bool capabilitiesAvailable
    property bool capabilitiesLoading
    property string capabilityError

    function readCleanup() {
        const result = AppInstaller.pendingUninstalls();
        cleanupLoading = result.loading;
        pendingUninstalls = result.items;
        cleanupError = result.error;
    }

    function refreshCleanup() {
        AppInstaller.refreshPendingUninstalls();
        readCleanup();
    }

    function readCapabilities() {
        const result = AppInstaller.uninstallCapabilities();
        uninstallCapabilities = result.items;
        capabilitiesAvailable = result.available;
        capabilitiesLoading = result.loading;
        capabilityError = result.error;
    }

    function refreshCapabilities() {
        AppInstaller.refreshUninstallCapabilities(Apps.getAllAppIds());
        readCapabilities();
    }

    function showApp(appId) {
        pageStack.push(Qt.resolvedUrl("AppInfoPage.qml"), {
            appId: appId
        });
    }

    onStatusChanged: {
        if (status === PageStatus.Active) {
            refreshCleanup();
            refreshCapabilities();
        }
        if (status === PageStatus.Active && focusAppId !== "") {
            const id = focusAppId;
            focusAppId = "";
            showApp(id);
        }
    }

    function uninstall(appId, name) {
        const next = Object.assign({}, removing);
        next[appId] = name;
        removing = next;
        AppInstaller.uninstallApp(appId);
    }

    function uninstallAndroid(pkg, name) {
        const next = Object.assign({}, removing);
        next["deckard." + pkg] = name;
        removing = next;
        AndroidApps.uninstall(pkg);
    }

    Connections {
        target: AndroidApps

        function onDone(pkg, action) {
            if (action === "uninstall" && page.removing["deckard." + pkg] !== undefined)
                Notices.show(qsTr("%1 uninstalled").arg(page.removing["deckard." + pkg]));
        }
        function onFailed(pkg, action, error) {
            if (action === "uninstall" && page.removing["deckard." + pkg] !== undefined)
                Notices.show(qsTr("Couldn't uninstall %1: %2").arg(page.removing["deckard." + pkg]).arg(error));
        }
    }

    Connections {
        target: Apps

        function onCountChanged() {
            if (page.status === PageStatus.Active)
                page.refreshCapabilities();
        }
    }

    Connections {
        target: AppInstaller

        function onPendingUninstallsChanged() {
            page.readCleanup();
        }
        function onUninstallCapabilitiesChanged() {
            page.readCapabilities();
        }

        function onUninstallComplete(appId) {
            page.refreshCleanup();
            Notices.show(qsTr("%1 uninstalled").arg(page.removing[appId] || appId));
        }
        function onUninstallFailed(appId, error) {
            page.refreshCleanup();
            Notices.show(qsTr("Couldn't uninstall %1: %2").arg(page.removing[appId] || appId).arg(error));
        }
        function onUninstallPartial(appId, detail) {
            page.refreshCleanup();
            Notices.show(qsTr("Cleanup incomplete for %1: %2").arg(page.removing[appId] || appId).arg(detail));
        }
    }

    SilicaListView {
        id: view

        objectName: "appList"
        anchors.fill: parent
        model: Apps
        header: Column {
            width: view.width

            PageHeader {
                title: qsTr("Installed apps")
                description: qsTr("%n apps", "", view.count + AndroidApps.apps.length)
            }
            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                text: page.capabilityError
                visible: text !== ""
                wrapMode: Text.Wrap
            }
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Reload app capabilities")
                visible: page.capabilityError !== ""
                enabled: !page.capabilitiesLoading
                onClicked: page.refreshCapabilities()
            }
        }

        delegate: AppRow {
            required property var model

            appId: model.id
            name: model.name
            icon: model.icon || ""
            subtitle: [model.version ? qsTr("Version %1").arg(model.version) : "", model.isProtected ? qsTr("System app") : ""].filter(t => t !== "").join(" · ")
            Accessible.name: model.name + (model.isProtected ? ", " + qsTr("system app") : "")
            canUninstall: page.capabilitiesAvailable && page.uninstallCapabilities[model.id] === true
            onUninstallRequested: page.uninstall(model.id, model.name)
            onClicked: page.showApp(model.id)
        }

        // Android apps follow Marathon's, as rows of the same kind.
        footer: Column {
            width: parent ? parent.width : 0

            Repeater {
                objectName: "androidApps"
                model: AndroidApps.apps

                AppRow {
                    required property var modelData

                    width: parent.width
                    appId: modelData.id
                    name: modelData.name
                    icon: modelData.icon || ""
                    subtitle: [modelData.version ? qsTr("Version %1").arg(modelData.version) : "", qsTr("Android app")].filter(t => t !== "").join(" · ")
                    Accessible.name: modelData.name + ", " + qsTr("Android app")
                    canUninstall: Logic.androidRemovable(modelData.pkg) && !modelData.system
                    onUninstallRequested: page.uninstallAndroid(modelData.pkg, modelData.name)
                    onClicked: page.showApp(modelData.id)
                }
            }

            SectionHeader {
                text: qsTr("Pending cleanup")
                visible: page.pendingUninstalls.length > 0 || page.cleanupError !== ""
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                text: page.cleanupError
                visible: text !== ""
                wrapMode: Text.Wrap
            }
            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Reload cleanup status")
                visible: page.cleanupError !== ""
                enabled: !page.cleanupLoading
                onClicked: page.refreshCleanup()
            }

            BusyIndicator {
                anchors.horizontalCenter: parent.horizontalCenter
                running: page.cleanupLoading && page.status === PageStatus.Active
                visible: running
                size: BusyIndicatorSize.Small
            }

            Repeater {
                objectName: "pendingCleanup"
                model: page.pendingUninstalls

                Column {
                    id: pendingRow
                    required property var modelData
                    width: parent.width
                    spacing: Theme.paddingMedium

                    Label {
                        x: Theme.horizontalPageMargin
                        width: parent.width - 2 * x
                        text: pendingRow.modelData.id + "\n" + pendingRow.modelData.detail
                        wrapMode: Text.Wrap
                    }
                    Button {
                        objectName: "retryCleanup-" + pendingRow.modelData.id
                        anchors.horizontalCenter: parent.horizontalCenter
                        text: qsTr("Retry cleanup")
                        enabled: !page.cleanupLoading
                        onClicked: page.uninstall(pendingRow.modelData.id, pendingRow.modelData.id)
                    }
                }
            }
        }

        VerticalScrollDecorator {}
    }
}
