pragma ComponentBehavior: Bound

import QtQuick
import Sailfish.Silica 1.0
import Marathon.Silica 1.0
import Marathon.Platform 1.0

ListItem {
    id: root

    property var message
    readonly property bool outgoing: message.isOutgoing
    readonly property bool canRetry: outgoing && message.status === "failed"
    readonly property real dayHeight: day.visible ? day.implicitHeight : 0
    readonly property real textWidth: width * 0.8 - Theme.horizontalPageMargin

    signal deleteRequested
    signal retryRequested
    signal pictureOpened(string path)

    contentHeight: dayHeight + pictures.height + body.height + (time.visible ? time.height : 0) + (status.visible ? status.height : 0) + Theme.paddingMedium
    Accessible.name: message.text
    Accessible.description: canRetry ? qsTr("Not sent. Activate to try again.") : outgoing && message.status === "sending" ? qsTr("Sending") : outgoing ? qsTr("Sent") : qsTr("Received")
    onClicked: if (canRetry)
        retryRequested()
    menu: ContextMenu {
        MenuItem {
            objectName: "retryItem"
            visible: root.canRetry
            text: qsTr("Try again")
            onClicked: root.retryRequested()
        }
        MenuItem {
            objectName: "copyItem"
            text: qsTr("Copy")
            onClicked: Clipboard.text = root.message.text
        }
        MenuItem {
            objectName: "deleteItem"
            text: qsTr("Delete")
            onClicked: root.remorseDelete(() => root.deleteRequested())
        }
    }

    Label {
        id: day
        textFormat: Text.PlainText
        width: parent.width
        visible: root.message.showDay
        topPadding: Theme.paddingLarge
        bottomPadding: Theme.paddingMedium
        horizontalAlignment: Text.AlignHCenter
        text: Format.formatDate(new Date(root.message.timestamp), Formatter.TimepointSectionRelative)
        font.pixelSize: Theme.fontSizeSmall
        color: Theme.secondaryColor
    }

    // An MMS's attachments: pictures to tap open, other files by name.
    Column {
        id: pictures

        x: root.outgoing ? parent.width - width - Theme.horizontalPageMargin : Theme.horizontalPageMargin
        y: root.dayHeight + Theme.paddingSmall
        width: root.textWidth * 0.75
        spacing: Theme.paddingSmall

        Repeater {
            model: root.message.attachments || []

            delegate: Item {
                id: attachment

                required property var modelData
                readonly property bool isPicture: modelData.contentType.indexOf("image/") === 0
                readonly property string path: Sms.openAttachment(modelData.id, modelData.name)

                width: pictures.width
                height: isPicture ? width * 0.75 : fileName.implicitHeight

                Image {
                    objectName: "bubblePicture-" + attachment.modelData.name
                    anchors.fill: parent
                    visible: attachment.isPicture
                    fillMode: Image.PreserveAspectCrop
                    sourceSize.width: width
                    asynchronous: true
                    source: attachment.isPicture && attachment.path !== "" ? "file://" + attachment.path : ""
                    Accessible.role: Accessible.Graphic
                    Accessible.name: attachment.modelData.name

                    BackgroundItem {
                        objectName: "openPicture-" + attachment.modelData.name
                        anchors.fill: parent
                        enabled: attachment.path !== ""
                        Accessible.name: qsTr("Open %1").arg(attachment.modelData.name)
                        onClicked: root.pictureOpened(attachment.path)
                    }
                }

                Label {
                    id: fileName
                    textFormat: Text.PlainText

                    width: parent.width
                    visible: !attachment.isPicture
                    text: attachment.modelData.name
                    wrapMode: Text.Wrap
                    horizontalAlignment: root.outgoing ? Text.AlignRight : Text.AlignLeft
                    color: Theme.secondaryHighlightColor
                }
            }
        }
    }

    Label {
        id: body
        objectName: "messageText"
        x: root.outgoing ? parent.width - width - Theme.horizontalPageMargin : Theme.horizontalPageMargin
        y: root.dayHeight + pictures.height + (pictures.height > 0 ? Theme.paddingSmall : 0) + Theme.paddingSmall
        height: text !== "" ? implicitHeight : 0
        visible: text !== ""
        width: Math.min(implicitWidth, root.textWidth)
        text: root.message.text
        wrapMode: Text.Wrap
        textFormat: Text.PlainText
        horizontalAlignment: root.outgoing ? Text.AlignRight : Text.AlignLeft
        color: root.outgoing || root.highlighted ? Theme.highlightColor : Theme.primaryColor
    }

    Label {
        id: time
        textFormat: Text.PlainText
        anchors.top: body.bottom
        x: root.outgoing ? parent.width - width - Theme.horizontalPageMargin : Theme.horizontalPageMargin
        visible: root.message.showTime
        text: Format.formatDate(new Date(root.message.timestamp), Formatter.TimeValue)
        font.pixelSize: Theme.fontSizeTiny
        color: root.outgoing || root.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
    }

    // Sending, or not sent with a way to try again.
    Label {
        id: status
        textFormat: Text.PlainText

        objectName: "bubbleStatus"
        anchors.top: time.visible ? time.bottom : body.bottom
        x: parent.width - width - Theme.horizontalPageMargin
        width: root.textWidth
        wrapMode: Text.Wrap
        horizontalAlignment: Text.AlignRight
        visible: root.outgoing && (root.message.status === "sending" || root.message.status === "failed")
        text: root.message.status === "failed" ? qsTr("Not sent · Try again") : qsTr("Sending…")
        font.pixelSize: Theme.fontSizeTiny
        color: root.message.status === "failed" ? Theme.errorColor : Theme.secondaryHighlightColor

        MouseArea {
            anchors.fill: parent
            anchors.margins: -Theme.paddingMedium
            enabled: root.message.status === "failed"
            onClicked: root.retryRequested()
        }
    }
}
