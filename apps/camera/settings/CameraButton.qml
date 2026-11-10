// SPDX-FileCopyrightText: 2016 - 2024 Jolla Ltd.
// SPDX-FileCopyrightText: 2025 Jolla Mobile Ltd
//
// SPDX-License-Identifier: BSD-3-Clause

import QtQuick
import Sailfish.Silica 1.0
import Marathon.Silica 1.0

MouseArea {
    id: root

    property alias icon: image
    property alias background: backgroundCircle
    property real size: Theme.itemSizeSmall
    property int verticalCenterOffset

    width: Theme.itemSizeExtraLarge
    height: Theme.itemSizeExtraLarge
    activeFocusOnTab: enabled && visible
    Accessible.role: Accessible.Button
    Accessible.onPressAction: if (enabled)
        clicked(null)
    Keys.onPressed: function (event) {
        if (enabled && !event.isAutoRepeat && (event.key === Qt.Key_Return || event.key === Qt.Key_Enter || event.key === Qt.Key_Space)) {
            event.accepted = true;
            clicked(null);
        }
    }

    FocusFrame {
        parent: root
    }

    Rectangle {
        id: backgroundCircle

        radius: width / 2
        width: image.width
        height: width

        anchors {
            centerIn: parent
            verticalCenterOffset: parent.verticalCenterOffset
        }
        color: Theme.secondaryHighlightColor
    }

    Image {
        id: image

        anchors {
            centerIn: parent
            verticalCenterOffset: parent.verticalCenterOffset
        }
    }
}
