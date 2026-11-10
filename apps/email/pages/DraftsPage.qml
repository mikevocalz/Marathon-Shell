pragma ComponentBehavior: Bound
import QtQuick
import Sailfish.Silica 1.0
import Marathon.Silica 1.0

Page {
    id: page

    property var app

    SilicaListView {
        id: view

        objectName: "draftView"
        anchors.fill: parent
        model: page.app.drafts

        header: PageHeader {
            title: qsTr("Drafts")
        }

        ViewPlaceholder {
            enabled: view.count === 0
            text: qsTr("No drafts")
        }

        delegate: SummaryListItem {
            id: item

            required property var modelData

            objectName: "draft-" + modelData.key
            text: modelData.subject || qsTr("(No subject)")
            description: (modelData.to || qsTr("No recipient")) + (modelData.savedAt > 0 ? " · " + Format.formatDate(new Date(modelData.savedAt), Formatter.TimepointRelative) : "")
            Accessible.name: (modelData.subject || qsTr("(No subject)")) + ", " + (modelData.to || qsTr("No recipient"))
            onClicked: page.app.compose({
                draftKey: modelData.key
            })
            menu: ContextMenu {
                MenuItem {
                    objectName: "deleteItem"
                    text: qsTr("Delete")
                    onClicked: item.remorseDelete(() => page.app.deleteDraft(item.modelData.key))
                }
            }
        }

        VerticalScrollDecorator {}
    }
}
