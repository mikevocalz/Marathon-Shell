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
    // Nested Silica dialogs also resolve this when the editor is a bound component.
    readonly property PageStack pageStack: page.pageContainer as PageStack

    function commit() {
        autosaveTimer.stop();
        if (discarded)
            return;
        const body = bodyArea.text;
        if (noteId < 0) {
            if (body.trim() === "")
                return;
            const now = Date.now();
            const next = Store.create(store.notes, body, now, store.nextNoteId);
            store.save(taskRequested ? Store.makeTask(next, next[0].id, now) : next);
            noteId = store.notes[0].id;
        } else if (note && body !== Store.text(note)) {
            store.save(Store.update(store.notes, noteId, body, Date.now()));
        }
    }

    function deleteNote() {
        remorse.execute(qsTr("Deleted"), function () {
            page.discarded = true;
            page.store.save(Store.remove(page.store.notes, page.noteId));
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
    }

    onStatusChanged: if (status === PageStatus.Deactivating)
        commit()
    // Loaded once: rebinding to the saved note would rewrite the text mid-typing.
    Component.onCompleted: {
        if (note) {
            bodyArea.text = Store.text(note);
            autosaveTimer.stop();
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
                    page.commit();
                    page.store.save(Store.makeTask(page.store.notes, page.noteId, Date.now()));
                }
            }
            MenuItem {
                objectName: "clearDueDateItem"
                text: qsTr("Clear due date")
                visible: !!page.note && !!page.note.task && !!page.note.task.dueDate
                onClicked: {
                    page.commit();
                    page.store.save(Store.setTaskDueDate(page.store.notes, page.noteId, "", Date.now()));
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
                    page.commit();
                    page.store.save(Store.setPinned(page.store.notes, page.noteId, !page.note.pinned));
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
            TextSwitch {
                objectName: "taskCompletedSwitch"
                visible: !!page.note && !!page.note.task
                text: qsTr("Completed")
                checked: page.note && page.note.task ? page.note.task.completed : false
                automaticCheck: false
                onClicked: {
                    page.commit();
                    page.store.save(Store.setTaskCompleted(page.store.notes, page.noteId, !checked, Date.now()));
                }
            }
            ValueButton {
                objectName: "taskDueDateButton"
                visible: !!page.note && !!page.note.task
                label: qsTr("Due date")
                value: page.note && page.note.task && page.note.task.dueDate ? page.note.task.dueDate : qsTr("None")
                onClicked: {
                    page.commit();
                    const picker = page.pageStack.push(datePickerComponent, {
                        date: page.note.task.dueDate ? new Date(page.note.task.dueDate + "T12:00:00") : new Date()
                    });
                    picker.accepted.connect(function () {
                        page.store.save(Store.setTaskDueDate(page.store.notes, page.noteId, Qt.formatDate(picker.date, "yyyy-MM-dd"), Date.now()));
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
                onTextChanged: autosaveTimer.restart()
            }
        }

        VerticalScrollDecorator {}
    }
}
