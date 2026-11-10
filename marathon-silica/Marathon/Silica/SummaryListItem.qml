import QtQuick
import Sailfish.Silica as S

ListItem {
    id: root

    property string text: ""
    property string description: ""
    property url iconSource: ""
    property alias font: title.font
    property alias descriptionFont: detail.font

    contentHeight: Math.max(description !== "" ? S.Theme.itemSizeMedium : S.Theme.itemSizeSmall,
                            labels.height + S.Theme.paddingMedium * 2,
                            leadingIcon.visible ? leadingIcon.height + S.Theme.paddingMedium * 2 : 0)
    Accessible.name: description !== "" ? text + ", " + description : text

    S.Icon {
        id: leadingIcon

        objectName: "summaryIcon"
        width: S.Theme.iconSizeMedium
        height: width
        anchors {
            left: parent.left
            leftMargin: S.Theme.horizontalPageMargin
            verticalCenter: parent.verticalCenter
        }
        visible: root.iconSource.toString() !== ""
        source: root.iconSource
        color: root.highlighted ? S.Theme.highlightColor : S.Theme.primaryColor
        Accessible.ignored: true
    }

    Column {
        id: labels

        anchors {
            left: leadingIcon.visible ? leadingIcon.right : parent.left
            leftMargin: leadingIcon.visible ? S.Theme.paddingLarge : S.Theme.horizontalPageMargin
            right: parent.right
            rightMargin: S.Theme.horizontalPageMargin
            verticalCenter: parent.verticalCenter
        }
        spacing: S.Theme.paddingSmall

        S.Label {
            id: title

            objectName: "summaryText"
            width: parent.width
            text: root.text
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            color: root.highlighted ? S.Theme.highlightColor : S.Theme.primaryColor
            Accessible.ignored: true
        }

        S.Label {
            id: detail

            objectName: "summaryDescription"
            width: parent.width
            visible: root.description !== ""
            text: root.description
            textFormat: Text.PlainText
            wrapMode: Text.Wrap
            font.pixelSize: S.Theme.fontSizeExtraSmall
            color: root.highlighted ? S.Theme.secondaryHighlightColor : S.Theme.secondaryColor
            Accessible.ignored: true
        }
    }
}
