pragma ComponentBehavior: Bound
import QtQuick
import Sailfish.Silica 1.0
import Marathon.Silica 1.0
import Keel.Actions 1.0
import "../NotesStore.js" as Store

Page {
    id: page

    property var store
    property int noteId: -1
    property bool discarded: false
    property bool taskRequested: false

    readonly property var note: store.notes.find(n => n.id === noteId)
    readonly property string draftText: bodyArea.text
    readonly property bool hasPendingChanges: !discarded && (note ? bodyArea.text !== Store.text(note) : bodyArea.text.trim() !== "")
    property string recordState: "draft"
    // Nested Silica dialogs also resolve this when the editor is a bound component.
    readonly property PageStack pageStack: page.pageContainer as PageStack

    backNavigation: !hasPendingChanges && recordState !== "error"

    Keys.onEscapePressed: function (event) {
        event.accepted = true;
        if (commit())
            pageStack.navigateBack();
    }

    function commit() {
        autosaveTimer.stop();
        if (discarded)
            return true;
        const body = bodyArea.text;
        try {
            if (noteId < 0) {
                if (body.trim() === "")
                    return true;
                const now = Date.now();
                const next = Store.create(store.notes, body, now, store.nextNoteId);
                store.save(taskRequested ? Store.makeTask(next, next[0].id, now) : next);
                noteId = next[0].id;
            } else if (!note) {
                throw new Error("The original note is unavailable; keep the draft open");
            } else if (body !== Store.text(note)) {
                store.save(Store.update(store.notes, noteId, body, Date.now()));
            }
            recordState = "recorded";
            return true;
        } catch (error) {
            recordState = "error";
            return false;
        }
    }

    function recordChange(next) {
        try {
            store.save(next);
            return true;
        } catch (error) {
            Notices.show(qsTr("The change could not be recorded. Try the action again."));
            return false;
        }
    }

    function deleteNote() {
        remorse.execute(qsTr("Deleted"), function () {
            if (!page.recordChange(Store.remove(page.store.notes, page.noteId)))
                return;
            page.discarded = true;
            page.pageStack.pop();
        });
    }

    function focusEditor() {
        bodyArea.forceActiveFocus();
    }

    // A checklist toggle in the adjacent Tasks pane changes one character.
    // Keep the editing position when reflecting that saved change here.
    function refreshBodyFromStore() {
        const cursor = bodyArea.cursorPosition;
        const start = bodyArea.selectionStart;
        const end = bodyArea.selectionEnd;
        const scrollPosition = editorFlickable.contentY;
        bodyArea.text = Store.text(note);
        if (start !== end)
            bodyArea.select(cursor === start ? end : start, cursor === start ? start : end);
        else
            bodyArea.cursorPosition = cursor;
        editorFlickable.contentY = scrollPosition;
        autosaveTimer.stop();
        recordState = "recorded";
    }

    onStatusChanged: if (status === PageStatus.Deactivating)
        commit()
    // Loaded once: rebinding to the saved note would rewrite the text mid-typing.
    Component.onCompleted: {
        if (note) {
            bodyArea.text = Store.text(note);
            autosaveTimer.stop();
            recordState = "recorded";
        } else {
            bodyArea.forceActiveFocus();
        }
    }

    KeelContext {
        purpose: "editing a note"
        text: bodyArea.text
        active: page.status === PageStatus.Active
    }

    Timer {
        id: autosaveTimer

        interval: 800
        onTriggered: page.commit()
    }

    RemorsePopup {
        id: remorse
    }

    Component {
        id: datePickerComponent

        DatePickerDialog {}
    }

    Component {
        id: savingHelpComponent

        Dialog {
            SilicaFlickable {
                anchors.fill: parent
                contentHeight: helpColumn.height

                Column {
                    id: helpColumn
                    width: parent.width
                    spacing: Theme.paddingLarge

                    DialogHeader {
                        title: qsTr("Saving in Notes")
                        acceptText: qsTr("Done")
                        cancelText: qsTr("Back")
                    }
                    Label {
                        textFormat: Text.PlainText
                        objectName: "recordingMeaning"
                        x: Theme.horizontalPageMargin
                        width: parent.width - x * 2
                        wrapMode: Text.Wrap
                        text: qsTr("Changes recorded means Notes has accepted your edits. This status cannot confirm that they have reached device storage.")
                    }
                    Label {
                        textFormat: Text.PlainText
                        x: Theme.horizontalPageMargin
                        width: parent.width - x * 2
                        wrapMode: Text.Wrap
                        text: qsTr("If an edit cannot be recorded, its draft stays open. Try again or copy the text before closing Notes.")
                    }
                }
            }
        }
    }

    SilicaFlickable {
        id: editorFlickable

        objectName: "editorFlickable"
        anchors.fill: parent
        contentHeight: column.height

        PullDownMenu {
            visible: page.note !== undefined
            MenuItem {
                objectName: "makeTaskItem"
                text: qsTr("Make task")
                visible: !!page.note && !page.note.task
                onClicked: {
                    if (!page.commit())
                        return;
                    page.recordChange(Store.makeTask(page.store.notes, page.noteId, Date.now()));
                }
            }
            MenuItem {
                objectName: "clearDueDateItem"
                text: qsTr("Clear due date")
                visible: !!page.note && !!page.note.task && !!page.note.task.dueDate
                onClicked: {
                    if (!page.commit())
                        return;
                    page.recordChange(Store.setTaskDueDate(page.store.notes, page.noteId, "", Date.now()));
                }
            }
            MenuItem {
                objectName: "deleteNoteItem"
                text: qsTr("Delete")
                onClicked: page.deleteNote()
            }
            MenuItem {
                objectName: "pinNoteItem"
                text: page.note && page.note.pinned ? qsTr("Unpin") : qsTr("Pin to top")
                onClicked: {
                    if (!page.commit())
                        return;
                    page.recordChange(Store.setPinned(page.store.notes, page.noteId, !page.note.pinned));
                }
            }
        }

        Column {
            id: column

            width: parent.width

            // The first line is the title, so the header carries the date instead.
            PageHeader {
                objectName: "header"
                title: page.note ? Store.when(page.note.timestamp, new Date()) : page.taskRequested ? qsTr("New task") : qsTr("New note")
            }
            ValueButton {
                objectName: "recordStatus"
                label: qsTr("Status")
                value: page.recordState === "error" ? qsTr("Changes not recorded") : page.recordState === "recorded" ? qsTr("Changes recorded") : qsTr("Draft")
                onClicked: page.pageStack.push(savingHelpComponent)
            }
            Column {
                width: parent.width
                spacing: Theme.paddingSmall
                visible: page.recordState === "error"
                height: visible ? implicitHeight : 0

                Button {
                    objectName: "retryDraftButton"
                    x: Theme.horizontalPageMargin
                    width: parent.width - x * 2
                    text: qsTr("Try again")
                    onClicked: page.commit()
                }
                Button {
                    objectName: "copyDraftButton"
                    x: Theme.horizontalPageMargin
                    width: parent.width - x * 2
                    text: qsTr("Copy draft")
                    onClicked: Clipboard.text = page.draftText
                }
            }
            TextSwitch {
                objectName: "taskCompletedSwitch"
                visible: !!page.note && !!page.note.task
                text: qsTr("Completed")
                checked: page.note && page.note.task ? page.note.task.completed : false
                automaticCheck: false
                onClicked: {
                    if (!page.commit())
                        return;
                    page.recordChange(Store.setTaskCompleted(page.store.notes, page.noteId, !checked, Date.now()));
                }
            }
            ValueButton {
                objectName: "taskDueDateButton"
                visible: !!page.note && !!page.note.task
                label: qsTr("Due date")
                value: page.note && page.note.task && page.note.task.dueDate ? page.note.task.dueDate : qsTr("None")
                onClicked: {
                    if (!page.commit())
                        return;
                    const picker = page.pageStack.push(datePickerComponent, {
                        date: page.note.task.dueDate ? new Date(page.note.task.dueDate + "T12:00:00") : new Date()
                    });
                    picker.accepted.connect(function () {
                        page.recordChange(Store.setTaskDueDate(page.store.notes, page.noteId, Qt.formatDate(picker.date, "yyyy-MM-dd"), Date.now()));
                    });
                }
            }
            DetailItem {
                objectName: "taskSourceLabel"
                visible: !!page.note && !!page.note.source
                label: qsTr("Captured from")
                valueTextFormat: Text.PlainText
                value: page.note && page.note.source ? page.note.source.label : ""
            }
            TextArea {
                id: bodyArea

                objectName: "bodyField"
                width: parent.width
                backgroundStyle: TextEditor.NoBackground
                placeholderText: qsTr("Write a note")
                onTextChanged: {
                    page.recordState = "draft";
                    autosaveTimer.restart();
                }
            }
        }

        VerticalScrollDecorator {}
    }
}
