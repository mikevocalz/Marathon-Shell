pragma Singleton
import QtQuick

// Service fixture only. The controls, pages and shared conversation are production QML.
QtObject {
    property bool connected: true
    property bool busy: false
    property bool offline: false
    property string error: ""
    property var requests: []
    property var confirmations: []
    property var guide: ["hidden"]
    property var openedUrls: []

    signal turnFinished(string json)
    signal nowChanged(string json)
    signal turnProgress(string json)
    signal wiped
    signal clockCancelled(int cookie)
    signal timerExtended(int oldCookie, string json)

    function reset() {
        connected = true;
        busy = false;
        offline = false;
        error = "";
        requests = [];
        confirmations = [];
        openedUrls = [];
        guide = ["hidden"];
    }
    function settings() {
        return JSON.stringify({
            onboarded: true,
            guide: guide
        });
    }
    function setGuide(step, tried) {
        if (tried && guide.indexOf(step) < 0)
            guide = guide.concat([step]);
    }
    function ask(text, spoken) {
        requests = requests.concat([
            {
                text: text,
                spoken: spoken
            }
        ]);
        busy = true;
    }
    function confirm(id, approved) {
        confirmations = confirmations.concat([
            {
                id: id,
                approved: approved
            }
        ]);
        busy = true;
    }
    function refreshNow() {
    }
    function clearConversation() {
    }
    function clearOnScreen() {
    }
    function listen() {
        busy = true;
    }
    function openUrl(url) {
        openedUrls = openedUrls.concat([url]);
    }
    function cancelClock(cookie) {
        clockCancelled(cookie);
    }
    function extendTimer(cookie, seconds) {
    }
    function forget(id) {
        return true;
    }
}
