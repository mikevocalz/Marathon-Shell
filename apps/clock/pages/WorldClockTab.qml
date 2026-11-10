pragma ComponentBehavior: Bound

import QtQuick
import Sailfish.Silica 1.0
import Marathon.Silica 1.0
import "../ClockLogic.js" as Logic

TabItem {
    id: root

    property var app
    property real topMargin
    property date now: new Date()

    flickable: list

    Timer {
        interval: 60000 - root.now.getSeconds() * 1000 - root.now.getMilliseconds()
        repeat: true
        triggeredOnStart: true
        running: root.isCurrentItem && Application.state === Qt.ApplicationActive
        onTriggered: root.now = new Date()
    }

    SilicaListView {
        id: list

        objectName: "cityList"
        anchors.fill: parent
        model: root.app.cities

        PullDownMenu {
            MenuItem {
                text: qsTr("Add city")
                onClicked: pageStack.push(Qt.resolvedUrl("AddCityPage.qml"), {
                    app: root.app
                })
            }
        }

        header: Column {
            width: list.width
            topPadding: root.topMargin + Theme.paddingLarge * 2
            bottomPadding: Theme.paddingLarge

            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: Format.formatDate(root.now, Formatter.TimeValue)
                font.pixelSize: Theme.fontSizeHuge
                fontSizeMode: Text.HorizontalFit
                minimumPixelSize: Theme.fontSizeLarge
                horizontalAlignment: Text.AlignHCenter
                font.features: ({
                        "tnum": 1
                    })
                color: Theme.highlightColor
            }
            Label {
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 2 * Theme.horizontalPageMargin
                text: Format.formatDate(root.now, Formatter.DateLong)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                color: Theme.secondaryHighlightColor
            }
            Label {
                objectName: "localCity"
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: root.app.localZone !== ""
                text: Logic.zoneCity(root.app.localZone)
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
            }
        }

        ViewPlaceholder {
            enabled: list.count === 0
            text: qsTr("No cities")
            hintText: qsTr("Pull down to add one")
        }

        delegate: ListItem {
            id: item

            required property int index
            required property var modelData
            readonly property var info: root.app.cityTime(modelData, root.now)

            objectName: "cityItem"
            contentHeight: Math.max(Theme.itemSizeMedium, cityLayout.height + 2 * Theme.paddingMedium)
            Accessible.name: [modelData.name, info.time, info.weekday, info.diff].filter(s => s).join(", ")
            menu: ContextMenu {
                MenuItem {
                    visible: item.index > 0
                    text: qsTr("Move up")
                    onClicked: root.app.moveCity(item.index, item.index - 1)
                }
                MenuItem {
                    visible: item.index < list.count - 1
                    text: qsTr("Move down")
                    onClicked: root.app.moveCity(item.index, item.index + 1)
                }
                MenuItem {
                    text: qsTr("Remove")
                    onClicked: {
                        const app = root.app;
                        const name = item.modelData.name;
                        item.remorseDelete(() => app.removeCity(name));
                    }
                }
            }

            TextMetrics {
                id: timeWidth

                text: item.info.time
                font.pixelSize: Theme.fontSizeLarge
                font.family: Theme.fontFamily
            }
            TextMetrics {
                id: weekdayWidth

                text: item.info.weekday
                font.pixelSize: Theme.fontSizeSmall
                font.family: Theme.fontFamily
            }

            Grid {
                id: cityLayout

                readonly property real timeColumnWidth: Math.ceil(Math.max(timeWidth.width, weekdayWidth.width))

                objectName: "cityLayout"
                x: Theme.horizontalPageMargin
                width: item.width - 2 * x
                anchors.verticalCenter: parent.verticalCenter
                columns: width >= timeColumnWidth + Theme.paddingMedium + 10 * Theme.fontSizeMedium ? 2 : 1
                columnSpacing: Theme.paddingMedium
                rowSpacing: Theme.paddingSmall

                Column {
                    width: cityLayout.columns === 1 ? cityLayout.width : cityLayout.width - cityLayout.timeColumnWidth - cityLayout.columnSpacing

                    Label {
                        objectName: "cityName"
                        width: parent.width
                        text: item.modelData.name
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        color: item.highlighted ? Theme.highlightColor : Theme.primaryColor
                    }
                    Label {
                        width: parent.width
                        text: item.info.diff
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        font.pixelSize: Theme.fontSizeSmall
                        color: item.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                    }
                }
                Column {
                    width: cityLayout.columns === 1 ? cityLayout.width : cityLayout.timeColumnWidth

                    Label {
                        objectName: "cityTime"
                        width: parent.width
                        text: item.info.time
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        horizontalAlignment: cityLayout.columns === 1 ? Text.AlignLeft : Text.AlignRight
                        font.pixelSize: Theme.fontSizeLarge
                        font.features: ({
                                "tnum": 1
                            })
                        color: item.highlighted ? Theme.highlightColor : Theme.primaryColor
                    }
                    Label {
                        width: parent.width
                        text: item.info.weekday
                        textFormat: Text.PlainText
                        wrapMode: Text.Wrap
                        horizontalAlignment: cityLayout.columns === 1 ? Text.AlignLeft : Text.AlignRight
                        font.pixelSize: Theme.fontSizeSmall
                        color: item.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                    }
                }
            }
        }

        VerticalScrollDecorator {}
    }
}
