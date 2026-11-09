pragma Singleton
import QtQml

QtObject {
    property var uninstalled: []
    // The shell's answer: user installs only.
    property var removable: ["notes", "weather"]
    property var pending: []
    property bool cleanupAvailable: true

    signal uninstallComplete(string appId)
    signal uninstallFailed(string appId, string error)
    signal uninstallPartial(string appId, string detail)

    function reset() {
        uninstalled = [];
        removable = ["notes", "weather"];
        pending = [];
        cleanupAvailable = true;
    }
    function canUninstall(appId) {
        return removable.indexOf(appId) >= 0;
    }
    function uninstallApp(appId) {
        uninstalled = uninstalled.concat([appId]);
    }
    function pendingUninstalls() {
        return cleanupAvailable ? {available: true, items: pending} : {available: false, error: "Cleanup state unavailable"};
    }
    function flatpakApps() {
        return [
            {
                id: "org.kde.kweather",
                name: "KWeather"
            },
            {
                id: "org.gnome.Calculator",
                name: "Calculator"
            }
        ];
    }
}
