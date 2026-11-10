pragma ComponentBehavior: Bound
import QtQuick
import Sailfish.Silica 1.0
import Marathon.Silica 1.0
import "../NotesStore.js" as Store

Page {
    id: page

    property var store
    property var workspace

    SilicaListView {
        id: view

        objectName: "foldersView"
        anchors.fill: parent
        header: PageHeader {
            title: qsTr("Folders")
        }
        model: Store.folders(page.store.notes)

        ViewPlaceholder {
            x: view.originX
            enabled: page.store.notes.length === 0
            text: qsTr("No folders")
            hintText: qsTr("Add a #tag to a note to file it here")
        }

        delegate: SummaryListItem {
            id: item

            required property var modelData

            text: modelData.tag === "" ? qsTr("Untagged") : "#" + modelData.tag
            description: modelData.count === 1 ? qsTr("1 note") : qsTr("%1 notes").arg(modelData.count)
            iconSource: modelData.tag === "" ? "image://theme/icon-m-note" : "image://theme/icon-m-folder"
            onClicked: {
                if (page.workspace)
                    page.workspace.openFolder(item.modelData.tag);
                else
                    pageStack.push(Qt.resolvedUrl("NotesPage.qml"), {
                        store: page.store,
                        folder: item.modelData.tag
                    });
            }
        }

        VerticalScrollDecorator {}
    }
}
