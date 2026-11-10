// SPDX-FileCopyrightText: 2026 Patrick Quinn
// SPDX-License-Identifier: Apache-2.0

// Calendar events as a short agenda: the day as the heading, then each
// event's time beside its title and place. Nothing planned reads as a
// calm line, not an error.

import QtQuick
import QtQuick.Layouts
import Sailfish.Silica 1.0
import Marathon.Silica 1.0

Glass {
    id: card

    property string range: "today"     // today, tomorrow, week, next
    property var events: []

    function heading() {
        switch (range) {
        case "tomorrow":
            return qsTr("Tomorrow");
        case "week":
            return qsTr("Next 7 days");
        case "next":
            return qsTr("Coming up");
        default:
            return qsTr("Today");
        }
    }

    RowLayout {
        width: parent.width
        spacing: Theme.paddingMedium
        Icon {
            width: Theme.iconSizeSmallPlus
            height: width
            source: "image://theme/icon-m-date"
            color: Theme.highlightColor
        }
        Label {
            Layout.fillWidth: true
            wrapMode: Text.Wrap
            textFormat: Text.PlainText
            text: card.heading()
            font.pixelSize: Theme.fontSizeMedium
            color: Theme.highlightColor
        }
    }

    Label {
        textFormat: Text.PlainText
        visible: card.events.length === 0
        width: parent.width
        wrapMode: Text.Wrap
        text: card.range === "tomorrow" ? qsTr("Nothing planned for tomorrow.") : card.range === "week" ? qsTr("Nothing planned this week.") : card.range === "next" ? qsTr("Nothing coming up.") : qsTr("Nothing planned for today.")
        font.pixelSize: Theme.fontSizeMedium
        color: Theme.secondaryHighlightColor
    }

    Repeater {
        model: card.events
        delegate: Row {
            id: eventRow
            required property var modelData
            width: parent ? parent.width : 0
            spacing: Theme.paddingLarge
            Label {
                textFormat: Text.PlainText
                width: Theme.itemSizeMedium
                wrapMode: Text.Wrap
                text: eventRow.modelData.all_day ? qsTr("All day") : Format.formatDate(new Date(eventRow.modelData.start * 1000), Formatter.TimeValue)
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.highlightColor
            }
            Column {
                width: parent.width - Theme.itemSizeMedium - Theme.paddingLarge
                Label {
                    textFormat: Text.PlainText
                    width: parent.width
                    text: eventRow.modelData.title
                    wrapMode: Text.Wrap
                    color: Theme.highlightColor
                }
                Label {
                    textFormat: Text.PlainText
                    width: parent.width
                    visible: !!eventRow.modelData.location
                    text: eventRow.modelData.location || ""
                    wrapMode: Text.Wrap
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: Theme.secondaryHighlightColor
                }
            }
        }
    }
}
