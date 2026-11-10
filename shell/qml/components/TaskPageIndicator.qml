pragma ComponentBehavior: Bound

import MarathonOS.Shell 1.0
import QtQuick

Column {
    id: pageIndicator

    required property real gridContentY
    required property real gridContentHeight
    required property real gridHeight
    property color activeColor: MColors.accent
    property color inactiveColor: MColors.onContent(0.4)
    property int pageCount: gridHeight > 0 ? Math.max(1, Math.ceil(gridContentHeight / gridHeight)) : 1
    property int currentPage: {
        if (gridContentY >= gridContentHeight - gridHeight - 1)
            return pageCount - 1;
        var page = Math.round(gridContentY / gridHeight);
        return Math.max(0, Math.min(page, pageCount - 1));
    }

    anchors.right: parent.right
    anchors.rightMargin: Constants.spacingMedium
    anchors.verticalCenter: parent.verticalCenter
    spacing: Constants.spacingSmall
    visible: pageCount > 1
    z: 100
    Accessible.role: Accessible.StaticText
    Accessible.name: qsTr("Page %1 of %2").arg(currentPage + 1).arg(pageCount)

    Repeater {
        model: pageIndicator.pageCount

        Rectangle {
            id: dot

            required property int index
            property bool isActive: index === pageIndicator.currentPage

            width: MRadius.lg
            height: isActive ? MSpacing.md + MSpacing.xs : width
            radius: width / 2
            color: isActive ? pageIndicator.activeColor : pageIndicator.inactiveColor
            layer.enabled: true
            layer.effect: null

            Behavior on height {
                enabled: !MMotion.reduceMotion
                NumberAnimation {
                    duration: MMotion.normal
                    easing.type: Easing.OutCubic
                }
            }

            Behavior on color {
                enabled: !MMotion.reduceMotion
                ColorAnimation {
                    duration: MMotion.normal
                }
            }
        }
    }
}
