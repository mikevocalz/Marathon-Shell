pragma ComponentBehavior: Bound
import QtQuick
import Sailfish.Silica 1.0
import Marathon.Silica 1.0
import "../NotesStore.js" as Store

Page {
    id: page

    property var store

    SilicaListView {
        id: view

        objectName: "tasksView"
        anchors.fill: parent
        header: PageHeader {
            title: qsTr("Tasks")
        }
        model: Store.tasks(page.store.notes)

        PullDownMenu {
            MenuItem {
                objectName: "newTaskItem"
                text: qsTr("New task")
                onClicked: pageStack.push(Qt.resolvedUrl("NoteEditorPage.qml"), {
                    store: page.store,
                    taskRequested: true
                })
            }
        }

        ViewPlaceholder {
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
                    onClicked: pageStack.push(Qt.resolvedUrl("NoteEditorPage.qml"), {
                        store: page.store,
                        noteId: item.modelData.noteId
                    })
                }
            }

            TextSwitch {
                id: check

                objectName: "taskSwitch"
                text: item.modelData.text
                description: item.modelData.kind === "task" ? (item.modelData.dueDate ? qsTr("Due %1").arg(item.modelData.dueDate) : qsTr("No due date")) : item.modelData.noteTitle || qsTr("Untitled")
                checked: item.modelData.checked
                automaticCheck: false
                onClicked: page.store.save(item.modelData.kind === "task" ? Store.setTaskCompleted(page.store.notes, item.modelData.noteId, !item.modelData.checked, Date.now()) : Store.toggleTask(page.store.notes, item.modelData.noteId, item.modelData.line, Date.now()))
                onPressAndHold: item.openMenu()
            }
        }

        VerticalScrollDecorator {}
    }
}
