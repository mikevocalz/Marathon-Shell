import QtQuick
import Sailfish.Silica 1.0
import Marathon.Silica 1.0
import Marathon.Platform 1.0
import "../Phone.js" as Phone

Page {
    id: root

    property var phone

    backNavigation: false

    SilicaFlickable {
        objectName: "callInfo"
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: actions.top
            bottomMargin: Theme.paddingLarge
        }
        clip: true
        contentHeight: callerInfo.height + 2 * Theme.paddingLarge

        Column {
            id: callerInfo
            x: Theme.horizontalPageMargin
            y: Theme.paddingLarge
            width: parent.width - 2 * x
            spacing: Theme.paddingMedium

            Label {
                textFormat: Text.PlainText
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: qsTr("Incoming call")
                wrapMode: Text.Wrap
                color: Theme.highlightColor
            }
            Label {
                textFormat: Text.PlainText
                objectName: "callerLabel"
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                text: root.phone.callName || Phone.format(root.phone.callNumber) || qsTr("Unknown number")
                font.pixelSize: Theme.fontSizeHuge
                font.weight: Font.ExtraLight
                wrapMode: Text.Wrap
                Accessible.role: Accessible.Heading
            }
            Label {
                textFormat: Text.PlainText
                width: parent.width
                horizontalAlignment: Text.AlignHCenter
                visible: root.phone.callName.length > 0
                text: Phone.format(root.phone.callNumber)
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
            }
        }

        VerticalScrollDecorator {}
    }

    Grid {
        id: actions

        width: parent.width - 2 * Theme.horizontalPageMargin
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: answerButton.top
            bottomMargin: Theme.paddingLarge
        }
        columns: root.phone.callNumber.length > 0 && messageAction.minimumColumnWidth + declineAction.minimumColumnWidth + columnSpacing <= width ? 2 : 1
        columnSpacing: Theme.paddingLarge
        rowSpacing: Theme.paddingSmall

        LabelledButton {
            id: messageAction

            name: "message"
            width: actions.columns === 2 ? (actions.width - actions.columnSpacing) / 2 : actions.width
            inlineLabel: actions.columns === 1
            visible: root.phone.callNumber.length > 0
            icon: "image://theme/icon-m-message"
            text: qsTr("Message")
            accessibleName: qsTr("Decline and send a message to %1").arg(root.phone.callName || root.phone.callNumber)
            onClicked: {
                const number = root.phone.callNumber;
                Telephony.hangup();
                root.phone.closeCallPages();
                root.phone.sendMessage(number);
            }
        }
        LabelledButton {
            id: declineAction

            name: "decline"
            width: actions.columns === 2 ? (actions.width - actions.columnSpacing) / 2 : actions.width
            inlineLabel: actions.columns === 1
            icon: "image://theme/icon-m-end-call"
            text: qsTr("Decline")
            accessibleName: qsTr("Decline call from %1").arg(root.phone.callName || root.phone.callNumber)
            onClicked: {
                Telephony.hangup();
                root.phone.closeCallPages();
            }
        }
    }

    Button {
        id: answerButton

        objectName: "answerButton"
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: 2 * Theme.paddingLarge
        }
        preferredWidth: Math.min(Theme.buttonWidthLarge, parent.width - 2 * Theme.horizontalPageMargin)
        icon.source: "image://theme/icon-m-answer"
        text: qsTr("Answer")
        Accessible.name: qsTr("Answer call from %1").arg(root.phone.callName || root.phone.callNumber)
        onClicked: Telephony.answer()
    }

    component LabelledButton: Item {
        id: labelled

        property string name
        property string icon
        property string text
        property string accessibleName
        property bool inlineLabel: false
        readonly property real minimumColumnWidth: Math.max(button.width, labelMetrics.width)

        signal clicked

        width: Theme.itemSizeExtraLarge
        implicitHeight: inlineLabel ? Math.max(button.height, label.height) : button.height + label.height
        height: implicitHeight

        TextMetrics {
            id: labelMetrics

            font: label.font
            text: labelled.text
        }

        IconButton {
            id: button

            objectName: labelled.name + "Button"
            x: labelled.inlineLabel ? 0 : (parent.width - width) / 2
            y: labelled.inlineLabel ? (parent.height - height) / 2 : 0
            icon.source: labelled.icon
            Accessible.name: labelled.accessibleName
            onClicked: labelled.clicked()
        }
        Label {
            id: label

            objectName: labelled.name + "ActionLabel"
            textFormat: Text.PlainText
            x: labelled.inlineLabel ? button.width + Theme.paddingMedium : 0
            y: labelled.inlineLabel ? (parent.height - height) / 2 : button.height
            width: parent.width - x
            horizontalAlignment: labelled.inlineLabel ? Text.AlignLeft : Text.AlignHCenter
            text: labelled.text
            color: button.highlighted ? Theme.highlightColor : Theme.primaryColor
            font.pixelSize: Theme.fontSizeSmall
            wrapMode: Text.Wrap
            Accessible.ignored: true
        }
    }
}
