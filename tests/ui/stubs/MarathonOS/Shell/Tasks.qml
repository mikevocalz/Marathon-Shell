pragma Singleton
import QtQml.Models

ListModel {
    readonly property int taskCount: count
    property bool androidStarting: false
    property var secureApps: []
    signal appRegistered(string appId)
    signal appUnregistered(string appId)
    signal appCommand(string appId, string command)
    function setCoverVisible(appId, visible) {
    }
    function closeAppWindows(appId) {
        return 0;
    }
    function launchAppWithRoute() {
    }
    function closeApp(appId, skipNativeClose) {
    }
    function registerApp(appId, info) {
    }
    function unregisterApp(appId) {
    }
}
