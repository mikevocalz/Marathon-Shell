pragma ComponentBehavior: Bound
import QtQuick
import QtQuick.Layouts
import Sailfish.Silica 1.0
import Marathon.Silica 1.0
import "../NotesStore.js" as Store

Page {
    id: page

    property var store
    property var workspace
    // Set to show one folder; "" is the untagged notes.
    property var folder: undefined
    property string searchText: ""

    readonly property bool inFolder: folder !== undefined
    readonly property var scope: inFolder ? Store.inFolder(store.notes, folder) : store.notes
    readonly property var shown: Store.sorted(Store.search(scope, searchText))

    SilicaListView {
        id: view

        objectName: "notesView"
        anchors.fill: parent
        model: page.shown

        header: Column {
            width: view.width

            PageHeader {
                title: !page.inFolder ? qsTr("Notes") : page.folder === "" ? qsTr("Untagged") : "#" + page.folder
            }
            SearchField {
                objectName: "searchField"
                width: parent.width
                placeholderText: qsTr("Search notes")
                visible: page.scope.length > 0
                onTextChanged: page.searchText = text
                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                EnterKey.onClicked: focus = false
            }
        }

        PullDownMenu {
            MenuItem {
                text: qsTr("Folders")
                visible: !page.inFolder
                onClicked: {
                    if (page.workspace)
                        page.workspace.showFolders();
                    else
                        pageStack.push(Qt.resolvedUrl("FoldersPage.qml"), {
                            store: page.store
                        });
                }
            }
            MenuItem {
                text: qsTr("Tasks")
                visible: !page.inFolder
                onClicked: {
                    if (page.workspace)
                        page.workspace.showTasks();
                    else
                        pageStack.push(Qt.resolvedUrl("TasksPage.qml"), {
                            store: page.store
                        });
                }
            }
            MenuItem {
                objectName: "newNoteItem"
                text: qsTr("New note")
                onClicked: {
                    if (page.workspace)
                        page.workspace.newNote();
                    else
                        pageStack.push(Qt.resolvedUrl("NoteEditorPage.qml"), {
                            store: page.store,
                            noteId: -1
                        });
                }
            }
        }

        ViewPlaceholder {
            objectName: "placeholder"
            x: view.originX
            enabled: page.shown.length === 0
            text: page.store.storageProtected ? qsTr("Notes need recovery") : page.scope.length === 0 ? qsTr("No notes") : qsTr("No matching notes")
            hintText: page.store.storageProtected ? qsTr("Open Recovery to copy the original data") : page.scope.length === 0 ? qsTr("Pull down to add one") : qsTr("Try a different word")
        }

        delegate: ListItem {
            id: item

            required property var modelData

            contentHeight: Math.max(Theme.itemSizeLarge, labels.height + 2 * Theme.paddingMedium)
            Accessible.name: (modelData.pinned ? qsTr("Pinned") + ", " : "") + titleLabel.text
            Accessible.description: Store.preview(modelData)
            Accessible.selected: !!page.workspace && !!page.workspace.currentEditor && page.workspace.currentEditor.noteId === modelData.id
            menu: ContextMenu {
                MenuItem {
                    objectName: "pinItem"
                    text: item.modelData.pinned ? qsTr("Unpin") : qsTr("Pin to top")
                    onClicked: {
                        try {
                            page.store.save(Store.setPinned(page.store.notes, item.modelData.id, !item.modelData.pinned));
                        } catch (error) {
                            Notices.show(qsTr("The note could not be changed. Try again."));
                        }
                    }
                }
                MenuItem {
                    objectName: "deleteItem"
                    text: qsTr("Delete")
                    onClicked: {
                        const noteId = item.modelData.id;
                        const workspace = page.workspace;
                        const store = page.store;
                        item.remorseDelete(function () {
                            if (workspace)
                                workspace.removeNote(noteId);
                            else {
                                try {
                                    store.save(Store.remove(store.notes, noteId));
                                } catch (error) {
                                    Notices.show(qsTr("The note could not be deleted. Try again."));
                                }
                            }
                        });
                    }
                }
            }
            onClicked: {
                if (page.workspace)
                    page.workspace.openNote(item.modelData.id);
                else
                    pageStack.push(Qt.resolvedUrl("NoteEditorPage.qml"), {
                        store: page.store,
                        noteId: item.modelData.id
                    });
            }

            Column {
                id: labels

                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.paddingSmall

                RowLayout {
                    width: parent.width
                    spacing: Theme.paddingSmall

                    Icon {
                        visible: item.modelData.pinned === true
                        source: "image://theme/icon-s-favorite"
                        color: item.highlighted || item.Accessible.selected ? Theme.highlightColor : Theme.primaryColor
                    }
                    Label {
                        id: titleLabel

                        objectName: "noteTitle"
                        Layout.fillWidth: true
                        text: item.modelData.title || qsTr("Untitled")
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        maximumLineCount: 3
                        elide: Text.ElideRight
                        color: item.highlighted || item.Accessible.selected ? Theme.highlightColor : Theme.primaryColor
                    }
                }
                Label {
                    objectName: "notePreview"
                    width: parent.width
                    text: Store.preview(item.modelData)
                    textFormat: Text.PlainText
                    visible: text !== ""
                    font.pixelSize: Theme.fontSizeSmall
                    wrapMode: Text.Wrap
                    maximumLineCount: 2
                    elide: Text.ElideRight
                    color: item.highlighted || item.Accessible.selected ? Theme.secondaryHighlightColor : Theme.secondaryColor
                }
                Label {
                    objectName: "noteDate"
                    width: parent.width
                    text: Store.when(item.modelData.timestamp, new Date())
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: item.highlighted || item.Accessible.selected ? Theme.secondaryHighlightColor : Theme.secondaryColor
                }
            }

            Rectangle {
                anchors {
                    left: parent.left
                    top: parent.top
                    bottom: parent.bottom
                }
                width: Theme.paddingSmall
                color: Theme.highlightColor
                visible: item.Accessible.selected
            }
        }

        VerticalScrollDecorator {}
    }
}
