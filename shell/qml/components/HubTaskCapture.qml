pragma ComponentBehavior: Bound

import QtQuick
import MarathonOS.Shell 1.0
import Sailfish.Silica 1.0 as Silica
import Marathon.Silica 1.0 as Silica

// Only presentation belongs to this recyclable view. The shell-owned native
// singleton retains the draft and operation shared by the home Hub and Peek.
Item {
    id: sheet

    property bool open: false
    readonly property var client: NotesTaskClient
    readonly property bool hasDraft: Object.keys(client.draft).length > 0
    property string wallpaper
    property bool lightAmbience: false
    readonly property string draftTitle: client.draft.title || ""
    readonly property string draftBody: client.draft.body || ""
    readonly property string sourceId: client.draft.sourceId || ""
    readonly property string sourceLabel: client.draft.sourceLabel || ""
    property bool anotherDraftRequested: false
    property bool confirmingDiscard: false
    property bool checkedNotes: false
    property bool notesLaunchRejected: false
    readonly property string state: client.snapshot.state || "idle"
    readonly property bool busy: ["checking", "preparing", "creating", "opening"].indexOf(state) >= 0
    readonly property bool hasTask: Number(client.snapshot.taskId || 0) > 0
    readonly property bool editable: !busy && !hasTask && state !== "unknown"
    readonly property bool validDraft: draftTitle.trim().length > 0 && draftTitle.length <= 200 && draftBody.length <= 20000
    readonly property bool canCreate: validDraft && (state === "ready" || state === "rejected")

    function capture(notificationId, timestamp, title, body, appLabel) {
        if (hasDraft) {
            anotherDraftRequested = sourceId !== "notification:" + notificationId + ":" + timestamp;
            open = true;
            return;
        }
        if (!client.beginCapture({
            title: String(title || qsTr("Follow up")),
            body: String(body || ""),
            sourceId: "notification:" + notificationId + ":" + timestamp,
            // Descriptive display text, never a verified provider identity.
            sourceLabel: qsTr("%1 notification").arg(String(appLabel || qsTr("Hub")).slice(0, 170)).slice(0, 200)
        }))
            return;
        anotherDraftRequested = false;
        confirmingDiscard = false;
        checkedNotes = false;
        notesLaunchRejected = false;
        open = true;
        flick.contentY = 0;
    }

    function back() {
        if (!open)
            return false;
        if (confirmingDiscard) {
            confirmingDiscard = false;
            return true;
        }
        open = false;
        return true;
    }

    function clearDraft(acknowledged) {
        if (!(acknowledged ? client.acknowledgeUnknown() : client.reset()))
            return;
        open = false;
        anotherDraftRequested = false;
        confirmingDiscard = false;
        checkedNotes = false;
    }

    function submit() {
        if (canCreate) {
            finishEditing();
            sheet.forceActiveFocus();
            client.createTask();
        }
    }

    function finishEditing() {
        if (!hasDraft || !editable || (!titleField.activeFocus && !bodyField.activeFocus))
            return;
        // Qt's input-method commit is public. Read the native fields after it,
        // before moving focus, so the final composing text joins the snapshot.
        Qt.inputMethod.commit();
        client.updateDraft({title: titleField.text, body: bodyField.text});
    }

    onOpenChanged: {
        if (!open && hasDraft && editable) {
            finishEditing();
            sheet.forceActiveFocus();
        }
    }

    function statusText() {
        if (state === "checking")
            return qsTr("Checking Notes…");
        if (state === "preparing")
            return qsTr("Preparing to send this task to Notes…");
        if (state === "creating")
            return qsTr("Waiting for Notes. You can close this view; the result will stay with this capture.");
        if (state === "unknown")
            return qsTr("Notes may have created this task, but no usable reply arrived. Check Tasks in Notes before creating another. This capture will not be sent again.");
        if (state === "opening")
            return qsTr("Opening this task in Notes…");
        if (state === "opened")
            return qsTr("Notes opened this task and was asked to come to the front.");
        if (state === "open-failed")
            return qsTr("The task was created, but Notes could not confirm opening it. You can try opening the same task again.");
        if (state === "created")
            return qsTr("Task created in Notes.");
        if (client.snapshot.error === "unsupported")
            return qsTr("Update Notes to use notification task capture and exact task opening. Your draft is kept.");
        if (client.snapshot.error === "invalid-input")
            return qsTr("Use a title of 1–200 characters and a body of at most 20,000 characters.");
        if (state === "unavailable" || state === "rejected")
            return qsTr("Notes could not be reached before this task was sent. Your draft is kept.");
        return qsTr("Review the copied notification and edit it into a task. The original notification stays as it is.");
    }

    onHasDraftChanged: {
        if (!hasDraft) {
            open = false;
            anotherDraftRequested = false;
            confirmingDiscard = false;
            checkedNotes = false;
            notesLaunchRejected = false;
        }
    }

    component CaptureButton: Silica.Button {
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(implicitWidth, parent.width - 2 * Silica.Theme.horizontalPageMargin)
    }

    visible: open
    enabled: open

    KeelAmbienceBackground {
        width: sheet.Window.width
        height: sheet.Window.height
        wallpaper: sheet.wallpaper
        toneOpacity: 0.72
        light: sheet.lightAmbience
    }

    MouseArea {
        anchors.fill: parent
    }

    Silica.SilicaFlickable {
        id: flick
        objectName: "hubTaskCaptureFlick"
        anchors.fill: parent
        contentHeight: content.height
        clip: true

        Column {
            id: content
            width: parent.width
            topPadding: Constants.statusBarHeight
            bottomPadding: Silica.Theme.itemSizeLarge
            spacing: Silica.Theme.paddingMedium

            Silica.PageHeader {
                title: sheet.hasTask ? qsTr("Task in Notes") : qsTr("Create task")
                description: qsTr("From the Hub")
            }

            Silica.Label {
                objectName: "hubTaskCaptureSource"
                x: Silica.Theme.horizontalPageMargin
                width: parent.width - 2 * x
                text: sheet.sourceLabel
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: Silica.Theme.secondaryHighlightColor
                font.pixelSize: Silica.Theme.fontSizeSmall
            }

            Silica.Label {
                x: Silica.Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: sheet.anotherDraftRequested
                text: qsTr("Your current capture is still here. Finish or discard it before starting another.")
                wrapMode: Text.Wrap
                font.pixelSize: Silica.Theme.fontSizeSmall
            }

            Silica.TextField {
                id: titleField
                objectName: "hubTaskCaptureTitle"
                width: parent.width
                label: qsTr("Task title")
                placeholderText: qsTr("What needs doing?")
                readOnly: !sheet.editable
                errorHighlight: text.trim().length === 0 || text.length > 200
                onTextChanged: {
                    if (activeFocus && sheet.open && sheet.editable)
                        sheet.client.updateDraft({title: text, body: sheet.draftBody});
                }
                Binding {
                    target: titleField
                    property: "text"
                    value: sheet.draftTitle
                    when: !titleField.activeFocus
                    restoreMode: Binding.RestoreNone
                }
            }

            Silica.TextArea {
                id: bodyField
                objectName: "hubTaskCaptureBody"
                width: parent.width
                label: qsTr("Details")
                placeholderText: qsTr("Add context or next steps")
                readOnly: !sheet.editable
                errorHighlight: text.length > 20000
                onTextChanged: {
                    if (activeFocus && sheet.open && sheet.editable)
                        sheet.client.updateDraft({title: sheet.draftTitle, body: text});
                }
                Binding {
                    target: bodyField
                    property: "text"
                    value: sheet.draftBody
                    when: !bodyField.activeFocus
                    restoreMode: Binding.RestoreNone
                }
            }

            Silica.Label {
                objectName: "hubTaskCaptureStatus"
                x: Silica.Theme.horizontalPageMargin
                width: parent.width - 2 * x
                text: sheet.statusText()
                wrapMode: Text.Wrap
                textFormat: Text.PlainText
                font.pixelSize: Silica.Theme.fontSizeSmall
                color: Silica.Theme.secondaryHighlightColor
            }

            Silica.Label {
                x: Silica.Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: !sheet.validDraft && sheet.editable
                text: qsTr("The title needs 1–200 characters. Details can contain up to 20,000 characters.")
                wrapMode: Text.Wrap
                font.pixelSize: Silica.Theme.fontSizeSmall
            }

            CaptureButton {
                objectName: "hubTaskCaptureCreate"
                width: Math.min(Silica.Theme.buttonWidthLarge, parent.width - 2 * Silica.Theme.horizontalPageMargin)
                text: qsTr("Create task")
                visible: !sheet.hasTask && sheet.state !== "unknown" && !sheet.confirmingDiscard
                enabled: sheet.canCreate
                onClicked: sheet.submit()
            }

            CaptureButton {
                objectName: "hubTaskCaptureCheck"
                text: qsTr("Check Notes again")
                visible: sheet.state === "unavailable" || sheet.state === "idle"
                onClicked: client.checkAvailable()
            }

            CaptureButton {
                objectName: "hubTaskCaptureCancelPreparation"
                text: qsTr("Stop preparation")
                visible: sheet.state === "checking" || sheet.state === "preparing"
                onClicked: client.cancelPreparation()
            }

            CaptureButton {
                objectName: "hubTaskCaptureOpen"
                text: qsTr("Open task")
                visible: sheet.hasTask
                enabled: !sheet.busy
                onClicked: client.openTask()
            }

            CaptureButton {
                objectName: "hubTaskCaptureInspect"
                text: qsTr("Open Notes to check")
                visible: sheet.state === "unknown"
                onClicked: sheet.notesLaunchRejected = !Tasks.launchApp("notes")
            }

            Silica.Label {
                x: Silica.Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: sheet.notesLaunchRejected
                text: qsTr("Notes could not be launched. Keep this capture and try opening Notes from the app grid.")
                wrapMode: Text.Wrap
                font.pixelSize: Silica.Theme.fontSizeSmall
            }

            Silica.TextSwitch {
                objectName: "hubTaskCaptureCheckedNotes"
                width: parent.width
                visible: sheet.state === "unknown"
                text: qsTr("I checked Notes for this task")
                description: qsTr("Closing this capture does not remove a task that Notes may have created.")
                checked: sheet.checkedNotes
                onCheckedChanged: sheet.checkedNotes = checked
            }

            CaptureButton {
                objectName: "hubTaskCaptureAcknowledge"
                text: qsTr("Close this capture")
                visible: sheet.state === "unknown"
                enabled: sheet.checkedNotes
                onClicked: sheet.clearDraft(true)
            }

            CaptureButton {
                objectName: "hubTaskCaptureKeep"
                text: sheet.busy || sheet.hasTask || sheet.state === "unknown" ? qsTr("Back to Hub") : qsTr("Keep draft")
                onClicked: sheet.open = false
            }

            CaptureButton {
                objectName: "hubTaskCaptureDone"
                text: qsTr("Done")
                visible: sheet.hasTask && !sheet.busy
                onClicked: sheet.clearDraft(false)
            }

            CaptureButton {
                objectName: "hubTaskCaptureDiscard"
                text: sheet.confirmingDiscard ? qsTr("Discard this draft") : qsTr("Discard draft…")
                visible: sheet.editable
                onClicked: {
                    if (sheet.confirmingDiscard)
                        sheet.clearDraft(false);
                    else
                        sheet.confirmingDiscard = true;
                }
            }

            Silica.Label {
                x: Silica.Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: sheet.confirmingDiscard
                text: qsTr("Discard the copied text and your edits? No task has been sent from this draft.")
                wrapMode: Text.Wrap
                font.pixelSize: Silica.Theme.fontSizeSmall
            }
        }
    }
}
