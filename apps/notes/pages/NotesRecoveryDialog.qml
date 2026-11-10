pragma ComponentBehavior: Bound
import QtQuick
import Sailfish.Silica 1.0
import Marathon.Silica 1.0

Dialog {
    id: root

    property var store
    property NotesWorkspace workspace
    readonly property PageStack pageStack: root.pageContainer as PageStack

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column

            width: parent.width
            spacing: Theme.paddingMedium

            DialogHeader {
                title: qsTr("Recovery")
                acceptText: qsTr("Done")
                cancelText: qsTr("Back")
            }
            Label {
                textFormat: Text.PlainText
                x: Theme.horizontalPageMargin
                width: parent.width - x * 2
                wrapMode: Text.Wrap
                text: root.store.storageProtected ? qsTr("Notes cannot read the stored collection. It may be damaged or from a newer version. The original data has not been changed. Copy it before recovering it outside Notes.") : root.store.storageError
                visible: text !== ""
            }
            Button {
                objectName: "copyOriginalButton"
                x: Theme.horizontalPageMargin
                width: parent.width - x * 2
                text: qsTr("Copy original data")
                visible: root.store.storageProtected
                onClicked: Clipboard.text = root.store.store.value
            }
            Label {
                textFormat: Text.PlainText
                x: Theme.horizontalPageMargin
                width: parent.width - x * 2
                wrapMode: Text.Wrap
                text: qsTr("The current draft is still open. Copy it before closing Notes; an unrecorded draft does not survive the app closing.")
                visible: !!root.workspace.currentEditor && root.workspace.currentEditor.hasPendingChanges
            }
            Button {
                objectName: "copyRecoveryDraftButton"
                x: Theme.horizontalPageMargin
                width: parent.width - x * 2
                text: qsTr("Copy draft")
                visible: !!root.workspace.currentEditor
                onClicked: Clipboard.text = root.workspace.currentEditor.draftText
            }
            Button {
                objectName: "retryRecoveryDraftButton"
                x: Theme.horizontalPageMargin
                width: parent.width - x * 2
                text: qsTr("Try draft again")
                visible: !!root.workspace.currentEditor && root.workspace.currentEditor.hasPendingChanges
                onClicked: root.workspace.commitEditor()
            }
            Label {
                textFormat: Text.PlainText
                x: Theme.horizontalPageMargin
                width: parent.width - x * 2
                wrapMode: Text.Wrap
                text: qsTr("Shared text is waiting to become a note. Copy or retry the oldest item first. Waiting text is kept only while Notes stays open.")
                visible: root.store.pendingShares.length > 0
            }
            Button {
                objectName: "copySharedButton"
                x: Theme.horizontalPageMargin
                width: parent.width - x * 2
                text: qsTr("Copy shared text")
                visible: root.store.pendingShares.length > 0
                onClicked: Clipboard.text = root.store.pendingShares[0]
            }
            Button {
                objectName: "retrySharedButton"
                x: Theme.horizontalPageMargin
                width: parent.width - x * 2
                text: qsTr("Retry shared text")
                visible: root.store.pendingShares.length > 0
                onClicked: root.store.retryShare()
            }
        }

        VerticalScrollDecorator {}
    }
}
