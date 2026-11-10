pragma ComponentBehavior: Bound

import QtQuick
import Sailfish.Silica 1.0
import Marathon.Silica 1.0
import Marathon.Platform 1.0
import "../ClockLogic.js" as Logic

TabItem {
    id: root

    property var app
    property real topMargin
    readonly property var countdown: app.countdown
    readonly property bool idle: !countdown.running && countdown.remaining === 0

    function toggle() {
        if (countdown.running)
            countdown.pause();
        else
            countdown.start();
    }

    flickable: flick

    SilicaFlickable {
        id: flick

        anchors.fill: parent
        contentHeight: column.height

        PullDownMenu {
            MenuItem {
                objectName: "resetTimer"
                visible: root.countdown.total > 0
                text: qsTr("Reset")
                onClicked: root.countdown.reset()
            }
            MenuItem {
                objectName: "setTimer"
                text: qsTr("Set timer")
                enabled: !root.countdown.running
                onClicked: pageStack.push(Qt.resolvedUrl("TimerDialog.qml"), {
                    app: root.app,
                    seconds: Settings.get("clock/lastTimer", 600)
                })
            }
        }

        Column {
            id: column

            width: parent.width
            spacing: Theme.paddingLarge
            topPadding: root.topMargin + Theme.paddingLarge * 2
            bottomPadding: Theme.paddingLarge

            // Tap the dial to start or pause, as Jolla Clock's timers do.
            BackgroundItem {
                id: dial

                objectName: "timerDial"
                anchors.horizontalCenter: parent.horizontalCenter
                width: Math.min(parent.width - 2 * Theme.horizontalPageMargin, Theme.itemSizeHuge * 2)
                height: width
                enabled: root.countdown.remaining > 0
                Accessible.name: root.countdown.running ? qsTr("Pause timer") : qsTr("Start timer")
                onClicked: root.toggle()

                ProgressCircle {
                    anchors.fill: parent
                    value: root.countdown.total > 0 ? root.countdown.remaining / root.countdown.total : 0
                    progressColor: Theme.highlightColor
                    backgroundColor: Theme.rgba(Theme.primaryColor, Theme.opacityFaint)
                }
                Label {
                    objectName: "timerTime"
                    anchors.centerIn: parent
                    width: parent.width - 2 * Theme.paddingLarge
                    text: Logic.formatCountdown(root.countdown.remaining)
                    font.pixelSize: Theme.fontSizeHuge
                    fontSizeMode: Text.HorizontalFit
                    minimumPixelSize: Theme.fontSizeLarge
                    horizontalAlignment: Text.AlignHCenter
                    font.features: ({
                            "tnum": 1
                        })
                    color: dial.pressed || root.countdown.running ? Theme.highlightColor : Theme.primaryColor
                }
            }
            Label {
                objectName: "timerHint"
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                text: root.countdown.running ? qsTr("Tap to pause") : root.countdown.remaining > 0 ? qsTr("Tap to start") : qsTr("Pull down to set a timer")
                color: Theme.secondaryHighlightColor
            }
            SectionHeader {
                visible: root.idle
                text: qsTr("Quick timers")
            }
            Grid {
                id: presets

                objectName: "presetGrid"
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: root.idle
                columns: Math.max(1, Math.min(3, Math.floor((width + spacing) / (presetText.width + 2 * Theme.paddingLarge + spacing))))
                spacing: Theme.paddingMedium

                TextMetrics {
                    id: presetText

                    text: qsTr("%n min", "", 30)
                    font.pixelSize: Theme.fontSizeMedium
                    font.family: Theme.fontFamily
                }

                Repeater {
                    objectName: "presets"
                    model: [1, 3, 5, 10, 15, 30]

                    Button {
                        required property int modelData

                        width: (presets.width - (presets.columns - 1) * presets.spacing) / presets.columns
                        text: qsTr("%n min", "", modelData)
                        onClicked: {
                            root.countdown.set(modelData * 60);
                            root.countdown.start();
                        }
                    }
                }
            }
        }

        VerticalScrollDecorator {}
    }
}
