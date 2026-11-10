pragma ComponentBehavior: Bound

import QtQuick
import QtQuick.Layouts
import Sailfish.Silica 1.0
import Marathon.Silica 1.0
import Marathon.Platform 1.0
import "../MessagesLogic.js" as Logic

Page {
    id: root

    property var app
    property bool archive: false
    property bool searching: false
    property string query: ""
    readonly property var visibleConversations: Logic.visibleConversations(app.conversations, app.pinnedIds, app.archivedIds, archive, query)

    Component {
        id: pageHeader
        PageHeader {
            title: root.archive ? qsTr("Archive") : qsTr("Messages")
        }
    }

    // Outside the view: a list view moves focus to its current item whenever its model changes.
    Column {
        id: searchBar
        width: parent.width
        visible: root.searching

        Loader {
            width: parent.width
            sourceComponent: pageHeader
        }
        SearchField {
            objectName: "searchField"
            width: parent.width
            placeholderText: qsTr("Search")
            onTextChanged: root.query = text.trim()
            onVisibleChanged: if (visible)
                forceActiveFocus()
            else
                text = ""
        }
    }

    SilicaListView {
        id: view
        objectName: "conversationList"
        anchors {
            top: root.searching ? searchBar.bottom : parent.top
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        clip: root.searching
        model: Logic.withSections(root.visibleConversations, root.app.pinnedIds, Date.now())
        section.property: "section"
        section.delegate: SectionHeader {
            required property string section

            // Not by visible: the view shows each section item it reuses.
            height: section === "today" ? 0 : implicitHeight
            text: section === "pinned" ? qsTr("Pinned") : section === "today" ? "" : Format.formatDate(new Date(Number(section)), Formatter.TimepointSectionRelative)
        }

        header: root.searching ? null : pageHeader

        PullDownMenu {
            MenuItem {
                visible: !root.archive
                text: qsTr("Archived")
                onClicked: root.app.pageStack.push(Qt.resolvedUrl("ConversationsPage.qml"), {
                    app: root.app,
                    archive: true
                })
            }
            MenuItem {
                text: root.searching ? qsTr("Hide search") : qsTr("Search")
                onClicked: root.searching = !root.searching
            }
            MenuItem {
                objectName: "newMessageItem"
                visible: !root.archive
                text: qsTr("New message")
                onClicked: root.app.newMessage()
            }
        }

        ViewPlaceholder {
            enabled: view.count === 0
            text: root.query !== "" ? qsTr("No matches") : root.archive ? qsTr("Archive is empty") : qsTr("No messages")
            hintText: root.query !== "" ? qsTr("Try another name, number or phrase") : root.archive ? qsTr("Archived conversations appear here") : qsTr("Pull down to write a new message")
        }

        delegate: ListItem {
            id: item

            required property var modelData
            readonly property int unread: modelData.unreadCount || 0
            readonly property bool pinned: root.app.pinnedIds.indexOf(modelData.id) !== -1
            readonly property bool archived: root.app.archivedIds.indexOf(modelData.id) !== -1
            readonly property string draft: root.app.drafts[modelData.id] || ""

            objectName: "conversation-" + modelData.id
            contentHeight: Math.max(Theme.itemSizeMedium, labels.height + 2 * Theme.paddingMedium)
            Accessible.name: Logic.displayName(modelData) + (modelData.contactName ? ", " + (modelData.displayNumber || Sms.formatNumber(modelData.contactNumber)) : "") + (unread > 0 ? ", " + qsTr("%n unread", "", unread) : "")
            menu: ContextMenu {
                MenuItem {
                    visible: item.unread > 0
                    text: qsTr("Mark as read")
                    onClicked: Sms.markAsRead(item.modelData.id)
                }
                MenuItem {
                    text: item.pinned ? qsTr("Unpin") : qsTr("Pin")
                    onClicked: root.app.setPinned(item.modelData.id, !item.pinned)
                }
                MenuItem {
                    text: item.archived ? qsTr("Move to inbox") : qsTr("Archive")
                    onClicked: root.app.setArchived(item.modelData.id, !item.archived)
                }
                MenuItem {
                    objectName: "deleteItem"
                    text: qsTr("Delete")
                    onClicked: {
                        const app = root.app;
                        const id = item.modelData.id;
                        item.remorseDelete(function () {
                            app.deleteConversation(id);
                        });
                    }
                }
            }
            onClicked: root.app.openConversation(modelData)

            Column {
                id: labels

                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                anchors.verticalCenter: parent.verticalCenter
                spacing: Theme.paddingSmall

                GridLayout {
                    width: parent.width
                    columns: nameRow.implicitWidth + time.implicitWidth + columnSpacing <= width ? 2 : 1
                    columnSpacing: Theme.paddingMedium
                    rowSpacing: Theme.paddingSmall

                    RowLayout {
                        id: nameRow

                        Layout.fillWidth: true
                        spacing: Theme.paddingSmall

                        Icon {
                            visible: item.pinned
                            width: Theme.iconSizeSmall
                            height: width
                            source: "image://theme/icon-s-pin"
                        }
                        Label {
                            id: name

                            objectName: "conversationName"
                            Layout.fillWidth: true
                            text: Logic.displayName(item.modelData)
                            textFormat: Text.PlainText
                            wrapMode: Text.Wrap
                            font.bold: item.unread > 0
                            color: item.highlighted || item.unread > 0 ? Theme.highlightColor : Theme.primaryColor
                        }
                    }
                    Label {
                        id: time

                        Layout.fillWidth: true
                        text: item.modelData.lastTimestamp ? Format.formatDate(new Date(item.modelData.lastTimestamp), isNaN(Number(item.modelData.section)) ? Formatter.TimepointRelative : Formatter.TimeValue) : ""
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeExtraSmall
                        color: item.unread > 0 ? Theme.highlightColor : Theme.secondaryColor
                    }
                }
                Label {
                    objectName: "conversationNumber"
                    width: parent.width
                    visible: !!item.modelData.contactName
                    text: item.modelData.displayNumber || Sms.formatNumber(item.modelData.contactNumber)
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: item.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                }
                RowLayout {
                    width: parent.width
                    spacing: Theme.paddingMedium

                    Label {
                        id: preview

                        objectName: "preview"
                        Layout.fillWidth: true
                        text: item.draft !== "" ? qsTr("Draft: %1").arg(item.draft) : item.modelData.lastMessage
                        textFormat: Text.PlainText
                        font.pixelSize: Theme.fontSizeSmall
                        wrapMode: Text.Wrap
                        elide: Text.ElideRight
                        maximumLineCount: 2
                        color: item.draft !== "" || item.highlighted ? Theme.secondaryHighlightColor : item.unread > 0 ? Theme.primaryColor : Theme.secondaryColor
                    }
                    Rectangle {
                        objectName: "unreadBadge"
                        Layout.alignment: Qt.AlignTop
                        visible: item.unread > 0
                        implicitWidth: Math.max(height, countLabel.implicitWidth + 2 * Theme.paddingSmall)
                        implicitHeight: countLabel.implicitHeight + Theme.paddingSmall / 2
                        radius: height / 2
                        color: Theme.highlightColor

                        Label {
                            id: countLabel

                            anchors.centerIn: parent
                            text: item.unread > 99 ? "99+" : item.unread
                            textFormat: Text.PlainText
                            font.pixelSize: Theme.fontSizeExtraSmall
                            font.bold: true
                            color: Theme.darkPrimaryColor
                        }
                    }
                }
            }
        }

        VerticalScrollDecorator {}
    }
}
