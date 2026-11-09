pragma ComponentBehavior: Bound
import QtQuick
import Sailfish.Silica 1.0
import Marathon.Silica 1.0
import "../NotesStore.js" as Store

Page {
    id: page

    property var store
    property var workspace
    // The visible checklist uses the editor's current text, so line indices
    // still identify the clicked task when a pending draft is committed.
    readonly property var displayedNotes: {
        const editor = workspace ? workspace.currentEditor : null;
        return editor && editor.note && editor.draftText !== Store.text(editor.note) ? Store.update(store.notes, editor.noteId, editor.draftText, editor.note.timestamp) : store.notes;
    }

    SilicaListView {
        id: view

        objectName: "tasksView"
        anchors.fill: parent
        header: PageHeader {
            title: qsTr("Tasks")
        }
        model: Store.tasks(page.displayedNotes)

        PullDownMenu {
            MenuItem {
                objectName: "newTaskItem"
                text: qsTr("New task")
                onClicked: {
                    if (page.workspace)
                        page.workspace.newNote(true);
                    else
                        pageStack.push(Qt.resolvedUrl("NoteEditorPage.qml"), {
                            store: page.store,
                            taskRequested: true
                        });
                }
            }
        }

        ViewPlaceholder {
            x: view.originX
            enabled: view.count === 0
            text: qsTr("No tasks")
            hintText: qsTr("Pull down to create a task, or write a line like \"- [ ] buy milk\" in a note")
        }

        delegate: ListItem {
            id: item

            required property var modelData

            contentHeight: check.height
            menu: ContextMenu {
                MenuItem {
                    objectName: "openNoteItem"
                    text: qsTr("Open note")
                    onClicked: {
                        if (page.workspace)
                            page.workspace.openNote(item.modelData.noteId);
                        else
                            pageStack.push(Qt.resolvedUrl("NoteEditorPage.qml"), {
                                store: page.store,
                                noteId: item.modelData.noteId
                            });
                    }
                }
            }

            TextSwitch {
                id: check

                objectName: "taskSwitch"
                text: item.modelData.text
                description: item.modelData.kind === "task" ? (item.modelData.dueDate ? qsTr("Due %1").arg(item.modelData.dueDate) : qsTr("No due date")) : item.modelData.noteTitle || qsTr("Untitled")
                checked: item.modelData.checked
                automaticCheck: false
                onClicked: {
                    if (page.workspace)
                        page.workspace.toggleTask(item.modelData);
                    else
                        page.store.save(item.modelData.kind === "task" ? Store.setTaskCompleted(page.store.notes, item.modelData.noteId, !item.modelData.checked, Date.now()) : Store.toggleTask(page.store.notes, item.modelData.noteId, item.modelData.line, Date.now()));
                }
                onPressAndHold: item.openMenu()
            }
        }

        VerticalScrollDecorator {}
    }
}
