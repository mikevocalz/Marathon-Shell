pragma Singleton
import QtQml

QtObject {
    property var uninstalled: []
    // The shell's answer: user installs only.
    property var removable: ["notes", "weather"]
    property var pending: []
    property bool cleanupAvailable: true
    property bool deferCleanup: false
    property bool cleanupLoading: false
    property bool cleanupAgain: false
    property int cleanupRequests: 0
    property var cleanupSnapshot: ({
            available: false,
            items: [],
            error: ""
        })
    property bool deferCapabilities: false
    property bool capabilitiesAvailable: true
    property bool capabilitiesLoading: false
    property var requestedAppIds: []
    property var capabilitySnapshot: ({
            available: false,
            items: {},
            error: ""
        })
    property bool deferFlatpaks: false
    property bool flatpaksAvailable: true
    property bool flatpaksLoading: false
    property var flatpakSnapshot: ({
            available: false,
            items: [],
            error: ""
        })

    signal uninstallComplete(string appId)
    signal uninstallFailed(string appId, string error)
    signal uninstallPartial(string appId, string detail)
    signal pendingUninstallsChanged
    signal uninstallCapabilitiesChanged
    signal flatpakAppsChanged

    function reset() {
        uninstalled = [];
        removable = ["notes", "weather"];
        pending = [];
        cleanupAvailable = true;
        deferCleanup = false;
        cleanupLoading = false;
        cleanupAgain = false;
        cleanupRequests = 0;
        cleanupSnapshot = {
            available: false,
            items: [],
            error: ""
        };
        deferCapabilities = false;
        capabilitiesAvailable = true;
        capabilitiesLoading = false;
        requestedAppIds = [];
        capabilitySnapshot = {
            available: false,
            items: {},
            error: ""
        };
        deferFlatpaks = false;
        flatpaksAvailable = true;
        flatpaksLoading = false;
        flatpakSnapshot = {
            available: false,
            items: [],
            error: ""
        };
    }
    function canUninstall(appId) {
        return capabilitySnapshot.items[appId] === true;
    }
    function uninstallCapabilities() {
        return {
            available: capabilitySnapshot.available,
            loading: capabilitiesLoading,
            items: capabilitySnapshot.items,
            error: capabilitySnapshot.error
        };
    }
    function refreshUninstallCapabilities(ids) {
        requestedAppIds = ids;
        capabilitiesLoading = true;
        uninstallCapabilitiesChanged();
        if (!deferCapabilities)
            completeCapabilities();
    }
    function completeCapabilities() {
        const items = {};
        for (const id of requestedAppIds)
            items[id] = removable.indexOf(id) >= 0;
        capabilitySnapshot = {
            available: capabilitiesAvailable,
            items: capabilitiesAvailable ? items : capabilitySnapshot.items,
            error: capabilitiesAvailable ? "" : "App capabilities unavailable"
        };
        capabilitiesLoading = false;
        uninstallCapabilitiesChanged();
    }
    function uninstallApp(appId) {
        uninstalled = uninstalled.concat([appId]);
    }
    function pendingUninstalls() {
        return {
            available: cleanupSnapshot.available,
            loading: cleanupLoading,
            items: cleanupSnapshot.items,
            error: cleanupSnapshot.error
        };
    }
    function refreshPendingUninstalls() {
        if (cleanupLoading) {
            cleanupAgain = true;
            return;
        }
        cleanupLoading = true;
        cleanupRequests++;
        pendingUninstallsChanged();
        if (!deferCleanup)
            completeCleanup();
    }
    function completeCleanup() {
        cleanupLoading = false;
        if (cleanupAgain) {
            cleanupAgain = false;
            refreshPendingUninstalls();
            return;
        }
        cleanupSnapshot = {
            available: cleanupAvailable,
            items: cleanupAvailable ? pending : cleanupSnapshot.items,
            error: cleanupAvailable ? "" : "Cleanup state unavailable"
        };
        pendingUninstallsChanged();
    }
    function flatpakApps() {
        return flatpakSnapshot.items;
    }
    function flatpakAppsState() {
        return {
            available: flatpakSnapshot.available,
            loading: flatpaksLoading,
            items: flatpakSnapshot.items,
            error: flatpakSnapshot.error
        };
    }
    function refreshFlatpakApps() {
        flatpaksLoading = true;
        flatpakAppsChanged();
        if (!deferFlatpaks)
            completeFlatpaks();
    }
    function completeFlatpaks() {
        const items = [
            {
                id: "org.kde.kweather",
                name: "KWeather"
            },
            {
                id: "org.gnome.Calculator",
                name: "Calculator"
            }
        ];
        flatpakSnapshot = {
            available: flatpaksAvailable,
            items: flatpaksAvailable ? items : flatpakSnapshot.items,
            error: flatpaksAvailable ? "" : "Installed apps unavailable"
        };
        flatpaksLoading = false;
        flatpakAppsChanged();
    }
}
