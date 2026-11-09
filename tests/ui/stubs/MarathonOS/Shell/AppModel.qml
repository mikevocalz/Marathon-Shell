pragma Singleton
import QtQml

QtObject {
    signal uninstallPartial(string appId, string detail)
    signal uninstallFailed(string appId, string detail)
    property var names: ({})
    property var icons: ({})
    property bool uninstallAccepted: true
    property var uninstallRequests: []
    signal modelReset
    signal dataChanged
    readonly property int count: Object.keys(names).length
    function uninstall(appId) {
        uninstallRequests = uninstallRequests.concat([appId]);
        return uninstallAccepted;
    }
    function findById(appId) {
        return names[appId] ? {
            name: names[appId],
            icon: icons[appId] || ""
        } : ({});
    }
}
