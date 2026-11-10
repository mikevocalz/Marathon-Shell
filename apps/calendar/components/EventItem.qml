import QtQuick
import Sailfish.Silica 1.0
import Marathon.Silica 1.0
import "../CalendarLogic.js" as Logic

ListItem {
    id: item

    required property var modelData
    property var app
    property bool showDate: false

    objectName: "eventItem"
    width: parent ? parent.width : 0
    contentHeight: Math.max(Theme.itemSizeMedium, eventLayout.height + 2 * Theme.paddingMedium)
    readonly property string details: [showDate ? app.dateText(modelData) : modelData.recurring && modelData.recurring !== "none" ? app.repeatText(modelData.recurring) : "", modelData.location || "", modelData.accountLabel || "", modelData.recurrenceIncomplete ? qsTr("Series preview") : ""].filter(s => s !== "").join(" · ")

    Accessible.name: [modelData.title || qsTr("Untitled event"), showDate ? app.dateText(modelData) : "", app.timeRangeText(modelData), modelData.location || "", modelData.accountLabel || "", modelData.recurrenceIncomplete ? qsTr("Series preview") : ""].filter(s => s !== "").join(", ")
    onClicked: app.openEvent(modelData)
    menu: modelData.readOnly ? null : eventMenu

    Component {
        id: eventMenu

        ContextMenu {
            MenuItem {
                objectName: "editItem"
                text: qsTr("Edit")
                onClicked: item.app.editEvent(item.modelData)
            }
            MenuItem {
                objectName: "deleteItem"
                text: qsTr("Delete")
                onClicked: {
                    const id = item.modelData.id;
                    item.remorseDelete(function () {
                        item.app.deleteEvent(id);
                    });
                }
            }
        }
    }

    Grid {
        id: eventLayout

        objectName: "eventLayout"
        x: Theme.horizontalPageMargin
        width: item.width - 2 * x
        anchors.verticalCenter: parent.verticalCenter
        columns: width >= Theme.itemSizeExtraLarge + Theme.paddingMedium + 12 * Theme.fontSizeMedium ? 2 : 1
        columnSpacing: Theme.paddingMedium
        rowSpacing: Theme.paddingSmall

        Column {
            id: timeColumn

            width: eventLayout.columns === 1 ? eventLayout.width : Theme.itemSizeExtraLarge

            Label {
                width: parent.width
                text: item.app.timeText(item.modelData)
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeSmall
                font.features: ({
                        "tnum": 1
                    })
                color: item.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
            }
            Label {
                objectName: "endTimeLabel"
                width: parent.width
                visible: text !== ""
                text: {
                    if (item.modelData.allDay || !item.modelData.endTime)
                        return "";
                    const t = Logic.parseTime(item.modelData.endTime);
                    return Format.formatDate(new Date(2000, 0, 1, t.hour, t.minute), Formatter.TimeValue);
                }
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                font.pixelSize: Theme.fontSizeExtraSmall
                font.features: ({
                        "tnum": 1
                    })
                color: item.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
            }
        }

        Column {
            width: eventLayout.columns === 1 ? eventLayout.width : eventLayout.width - timeColumn.width - eventLayout.columnSpacing

            Label {
                objectName: "eventTitle"
                width: parent.width
                text: item.modelData.title || qsTr("Untitled event")
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: item.highlighted ? Theme.highlightColor : Theme.primaryColor
            }
            Label {
                objectName: "eventDetails"
                width: parent.width
                visible: text !== ""
                text: item.details
                textFormat: Text.PlainText
                font.pixelSize: Theme.fontSizeExtraSmall
                wrapMode: Text.Wrap
                color: item.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
            }
        }
    }
}
