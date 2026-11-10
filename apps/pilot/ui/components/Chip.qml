// SPDX-FileCopyrightText: 2026 Patrick Quinn
// SPDX-License-Identifier: Apache-2.0

// A pill: a suggestion, a follow-up question or a source. One tap.
// `monogram` puts a site's first letter in a small disc before the text.

import QtQuick
import Sailfish.Silica 1.0
import Marathon.Silica 1.0

BackgroundItem {
    id: chip

    property string text
    property string monogram: ""
    property string iconSource: ""
    property bool secondary: false

    // The chip's natural width from its parts' natural widths (not their
    // laid-out widths, which depend on the chip's).
    readonly property real _lead: (monogram.length > 0 ? Theme.iconSizeExtraSmall + Theme.paddingSmall : 0) + (iconSource.length > 0 ? Theme.iconSizeSmall + Theme.paddingSmall : 0)
    // At most as wide as its parent, when the parent has a width of its
    // own (a Row sized by its chips has none to give).
    readonly property real _natural: _lead + label.implicitWidth + 2 * Theme.paddingLarge
    implicitWidth: _natural
    width: parent && parent.width > 0 ? Math.min(implicitWidth, parent.width) : implicitWidth
    // The touch target is a full row; the pill drawn inside stays slim.
    height: Math.max(Theme.itemSizeSmall, label.implicitHeight + 2 * Theme.paddingMedium)
    Accessible.role: Accessible.Button
    Accessible.name: text
    _backgroundColor: "transparent"
    highlightedColor: "transparent"

    Rectangle {
        anchors.verticalCenter: parent.verticalCenter
        width: parent.width
        height: parent.height - Theme.paddingSmall
        radius: Theme.paddingSmall
        color: chip.down ? Theme.rgba(Theme.highlightBackgroundColor, 0.35) : Theme.rgba(Theme.primaryColor, chip.secondary ? 0.04 : 0.08)
        border.width: 1
        border.color: Theme.rgba(chip.secondary ? Theme.primaryColor : Theme.highlightColor, chip.secondary ? 0.10 : 0.30)
    }

    Row {
        id: row
        anchors.centerIn: parent
        spacing: Theme.paddingSmall

        Rectangle {
            visible: chip.monogram.length > 0
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.iconSizeExtraSmall
            height: width
            radius: width / 2
            color: Theme.rgba(Theme.highlightColor, 0.25)
            Label {
                textFormat: Text.PlainText
                anchors.centerIn: parent
                text: chip.monogram.toUpperCase()
                font.pixelSize: Theme.fontSizeTiny
                font.bold: true
                color: Theme.highlightColor
            }
        }
        Icon {
            visible: chip.iconSource.length > 0
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.iconSizeSmall
            height: width
            source: chip.iconSource
            color: chip.down ? Theme.highlightColor : Theme.primaryColor
        }
        Label {
            id: label
            textFormat: Text.PlainText
            anchors.verticalCenter: parent.verticalCenter
            width: Math.min(implicitWidth, chip.width - 2 * Theme.paddingLarge - chip._lead)
            text: chip.text
            wrapMode: Text.Wrap
            font.pixelSize: Theme.fontSizeSmall
            color: chip.down ? Theme.highlightColor : chip.secondary ? Theme.secondaryColor : Theme.primaryColor
        }
    }
}
