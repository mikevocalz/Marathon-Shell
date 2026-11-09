pragma Singleton
import QtQml

// Service fixture only. The capture's visual controls are the real Keel ones;
// production transport is exercised separately against a private D-Bus.
QtObject {
    property var snapshot: ({
            state: "idle"
        })
    property var draft: ({})
    property var created: []
    property var opened: []
    property bool autoReady: true
    property bool dispatchWon: false
    property int checks: 0

    function beginCapture(seed) {
        if (Object.keys(draft).length > 0 || snapshot.state !== "idle")
            return false;
        draft = JSON.parse(JSON.stringify(seed));
        checkAvailable();
        return true;
    }
    function updateDraft(edits) {
        if (["checking", "preparing", "creating", "opening", "unknown"].indexOf(snapshot.state) >= 0 || snapshot.taskId)
            return false;
        draft = {
            title: edits.title,
            body: edits.body,
            sourceId: draft.sourceId,
            sourceLabel: draft.sourceLabel
        };
        return true;
    }

    function checkAvailable() {
        checks++;
        snapshot = {
            state: autoReady ? "ready" : "checking"
        };
        return true;
    }
    function createTask() {
        if (snapshot.state !== "ready" && snapshot.state !== "rejected")
            return false;
        created = created.concat([JSON.parse(JSON.stringify(draft))]);
        snapshot = {
            state: "preparing"
        };
        return true;
    }
    function openTask() {
        if (!snapshot.taskId || snapshot.state === "opening")
            return false;
        opened = opened.concat([snapshot.taskId]);
        snapshot = {
            state: "opening",
            taskId: snapshot.taskId
        };
        return true;
    }
    function cancelPreparation() {
        if (dispatchWon || ["checking", "preparing"].indexOf(snapshot.state) < 0)
            return false;
        snapshot = {
            state: "ready"
        };
        return true;
    }
    function reset() {
        if (["checking", "preparing", "creating", "opening", "unknown"].indexOf(snapshot.state) >= 0)
            return false;
        snapshot = {
            state: "idle"
        };
        draft = {};
        return true;
    }
    function acknowledgeUnknown() {
        if (snapshot.state !== "unknown")
            return false;
        snapshot = {
            state: "idle"
        };
        draft = {};
        return true;
    }
    function resetFixture() {
        snapshot = {
            state: "idle"
        };
        draft = {};
        created = [];
        opened = [];
        checks = 0;
        autoReady = true;
        dispatchWon = false;
    }
}
