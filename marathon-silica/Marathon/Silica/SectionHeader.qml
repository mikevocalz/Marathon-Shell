import QtQuick
import Sailfish.Silica as S

S.SectionHeader {
    objectName: "sectionHeader"
    height: Math.max(S.Theme.itemSizeSmall, implicitHeight)
    textFormat: Text.PlainText
    wrapMode: Text.Wrap
    Accessible.role: Accessible.Heading
    Accessible.name: text
}
