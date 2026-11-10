import QtQuick
import Sailfish.Silica as S

S.PageHeader {
    id: root

    objectName: "pageHeader"
    wrapMode: Text.Wrap
    descriptionWrapMode: Text.Wrap
    _titleItem.textFormat: Text.PlainText
    Accessible.role: Accessible.Heading
    Accessible.name: title
    Accessible.description: description

    Binding {
        target: root._descriptionLabel
        property: "textFormat"
        value: Text.PlainText
        when: root._descriptionLabel !== null
    }
}
