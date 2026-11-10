import QtQuick
import Sailfish.Silica 1.0
import Marathon.Silica 1.0
import Marathon.Platform 1.0
import "../Phone.js" as Phone

Page {
    id: root

    property var phone
    property bool muted: false
    property bool speaker: false
    property bool keypadOpen: false
    property string tones: ""
    property real now: Date.now()
    property real endedAt: 0

    readonly property bool connected: phone.callState === "active"
    readonly property string callStatus: {
        if (endedAt > 0)
            return Phone.duration((endedAt - phone.callStartedAt) / 1000);
        if (connected && phone.callStartedAt > 0)
            return Phone.duration((now - phone.callStartedAt) / 1000);
        if (phone.callState === "held")
            return qsTr("On hold");
        return qsTr("Calling…");
    }

    function sendTone(digit) {
        Telephony.sendDTMF(digit);
        tones += digit;
    }

    Timer {
        interval: 1000
        repeat: true
        triggeredOnStart: true
        running: root.status === PageStatus.Active && root.connected && Application.state === Qt.ApplicationActive
        onTriggered: root.now = Date.now()
    }

    SilicaFlickable {
        id: callBody

        objectName: "callBody"
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            bottom: endCallButton.top
            bottomMargin: Theme.paddingLarge
        }
        clip: true
        contentHeight: callContent.height + 2 * Theme.paddingLarge

        Column {
            id: callContent

            x: Theme.horizontalPageMargin
            y: Theme.paddingLarge
            width: parent.width - 2 * x
            spacing: Theme.paddingLarge

            Column {
                id: info

                width: parent.width
                spacing: Theme.paddingSmall

                Label {
                    textFormat: Text.PlainText
                    objectName: "nameLabel"
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    text: root.phone.callName || Phone.format(root.phone.callNumber)
                    font.pixelSize: Theme.fontSizeExtraLarge
                    wrapMode: Text.Wrap
                    Accessible.role: Accessible.Heading
                }
                Label {
                    textFormat: Text.PlainText
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    visible: text.length > 0
                    text: root.keypadOpen && root.tones.length > 0 ? root.tones : root.phone.callName ? Phone.format(root.phone.callNumber) : ""
                    color: Theme.secondaryColor
                    wrapMode: Text.Wrap
                }
                Label {
                    textFormat: Text.PlainText
                    objectName: "statusLabel"
                    wrapMode: Text.Wrap
                    width: parent.width
                    topPadding: root.keypadOpen ? 0 : Theme.paddingLarge
                    horizontalAlignment: Text.AlignHCenter
                    text: root.callStatus
                    color: Theme.highlightColor
                    font.pixelSize: Theme.fontSizeHuge
                    font.weight: Font.ExtraLight
                    Accessible.name: root.connected || root.endedAt > 0 ? qsTr("Call duration %1").arg(text) : text
                }
                Label {
                    textFormat: Text.PlainText
                    objectName: "endedLabel"
                    wrapMode: Text.Wrap
                    width: parent.width
                    horizontalAlignment: Text.AlignHCenter
                    visible: root.endedAt > 0
                    text: qsTr("Call ended")
                    color: Theme.highlightColor
                    font.pixelSize: Theme.fontSizeLarge
                }
            }

            Row {
                id: controls

                width: parent.width
                visible: root.endedAt === 0
                spacing: Theme.paddingSmall

                CallToggle {
                    name: "speaker"
                    width: (controls.width - 2 * controls.spacing) / 3
                    checked: root.speaker
                    icon: "image://theme/icon-l-speaker"
                    text: qsTr("Speaker")
                    onToggled: {
                        root.speaker = !root.speaker;
                        Telephony.setSpeakerphone(root.speaker);
                    }
                }
                CallToggle {
                    name: "keypad"
                    width: (controls.width - 2 * controls.spacing) / 3
                    checked: root.keypadOpen
                    icon: "image://theme/icon-l-dialpad"
                    text: qsTr("Keypad")
                    onToggled: root.keypadOpen = !root.keypadOpen
                }
                CallToggle {
                    name: "mute"
                    width: (controls.width - 2 * controls.spacing) / 3
                    checked: root.muted
                    icon: root.muted ? "image://theme/icon-l-mic-mute" : "image://theme/icon-l-mic"
                    text: qsTr("Mute")
                    onToggled: {
                        root.muted = !root.muted;
                        Telephony.setCallMuted(root.muted);
                    }
                }
            }

            Keypad {
                objectName: "dtmfKeypad"
                width: parent.width
                visible: root.keypadOpen
                vanityDialNumbersVisible: false
                onClicked: number => root.sendTone(number)
            }
        }

        VerticalScrollDecorator {}
    }

    Button {
        id: endCallButton

        objectName: "endCallButton"
        anchors {
            horizontalCenter: parent.horizontalCenter
            bottom: parent.bottom
            bottomMargin: 2 * Theme.paddingLarge
        }
        preferredWidth: Math.min(Theme.buttonWidthLarge, parent.width - 2 * Theme.horizontalPageMargin)
        enabled: root.endedAt === 0
        icon.source: "image://theme/icon-m-end-call"
        text: qsTr("End call")
        onClicked: {
            Telephony.hangup();
            root.phone.closeCallPages();
        }
    }

    component CallToggle: Column {
        id: toggle

        property string name
        property bool checked
        property string icon
        property string text

        signal toggled

        width: Theme.itemSizeExtraLarge

        Switch {
            objectName: toggle.name + "Button"
            anchors.horizontalCenter: parent.horizontalCenter
            automaticCheck: false
            checked: toggle.checked
            icon.source: toggle.icon
            Accessible.name: toggle.text
            onClicked: toggle.toggled()
        }
        Label {
            textFormat: Text.PlainText
            objectName: toggle.name + "Label"
            width: parent.width
            horizontalAlignment: Text.AlignHCenter
            text: toggle.text
            color: Theme.secondaryColor
            font.pixelSize: Theme.fontSizeExtraSmall
            wrapMode: Text.Wrap
            Accessible.ignored: true
        }
    }
}
