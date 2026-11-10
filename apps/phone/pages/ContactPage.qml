pragma ComponentBehavior: Bound

import QtQuick
import Sailfish.Silica 1.0
import Marathon.Silica 1.0
import Marathon.Platform 1.0
import "../Phone.js" as Phone

Page {
    id: root

    property var phone
    property int contactId: -1
    readonly property var contact: phone.contacts.find(c => c.id === contactId) || null
    readonly property bool favorite: !!(contact && contact.favorite)

    function remove() {
        if (!contact)
            return;
        remorse.execute(qsTr("Deleted %1").arg(contact.name), function () {
            Contacts.deleteContact(root.contactId);
            root.phone.pageStack.pop();
        });
    }

    RemorsePopup {
        id: remorse
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                objectName: "deleteMenuItem"
                visible: root.contact !== null
                text: qsTr("Delete")
                onClicked: root.remove()
            }
            MenuItem {
                objectName: "editMenuItem"
                visible: root.contact !== null
                text: qsTr("Edit")
                onClicked: root.phone.pageStack.push(Qt.resolvedUrl("ContactEditorDialog.qml"), {
                    contact: root.contact
                })
            }
        }

        Column {
            id: column

            width: parent.width

            PageHeader {
                id: header

                title: root.contact ? root.contact.name : ""
                wrapMode: Text.Wrap

                IconButton {
                    objectName: "favoriteButton"
                    visible: root.contact !== null
                    parent: header.extraContent
                    anchors.verticalCenter: parent.verticalCenter
                    icon.source: root.favorite ? "image://theme/icon-m-favorite-selected" : "image://theme/icon-m-favorite"
                    highlighted: down || root.favorite
                    Accessible.role: Accessible.CheckBox
                    Accessible.name: qsTr("Favorite")
                    Accessible.checkable: true
                    Accessible.checked: root.favorite
                    onClicked: Contacts.updateContact(root.contactId, {
                        favorite: !root.favorite
                    })
                }
            }

            Repeater {
                model: Phone.contactEntries(root.contact, "phones", "phone", "mobile").filter(e => e.value !== "")

                ListItem {
                    id: phoneRow

                    required property var modelData

                    objectName: "phoneItem"
                    contentHeight: Math.max(Theme.itemSizeMedium, phoneLabels.height + 2 * Theme.paddingMedium)
                    Accessible.name: qsTr("Call %1").arg(phoneValue.text)
                    onClicked: root.phone.call(modelData.value)

                    Icon {
                        id: phoneIcon

                        x: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        source: "image://theme/icon-m-call"
                        highlighted: phoneRow.highlighted
                    }
                    Column {
                        id: phoneLabels
                        anchors {
                            left: phoneIcon.right
                            leftMargin: Theme.paddingLarge
                            right: messageButton.left
                            rightMargin: Theme.paddingMedium
                            verticalCenter: parent.verticalCenter
                        }

                        Label {
                            id: phoneValue
                            textFormat: Text.PlainText

                            objectName: "phoneValue"
                            width: parent.width
                            text: Phone.format(phoneRow.modelData.value)
                            wrapMode: Text.Wrap
                            color: phoneRow.highlighted ? Theme.highlightColor : Theme.primaryColor
                        }
                        Label {
                            textFormat: Text.PlainText
                            width: parent.width
                            text: Phone.kindName(phoneRow.modelData.type)
                            wrapMode: Text.Wrap
                            font.pixelSize: Theme.fontSizeSmall
                            color: phoneRow.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                        }
                    }
                    IconButton {
                        id: messageButton

                        objectName: "messageButton"
                        anchors {
                            right: parent.right
                            rightMargin: Theme.horizontalPageMargin - Theme.paddingMedium
                            verticalCenter: parent.verticalCenter
                        }
                        icon.source: "image://theme/icon-m-message"
                        Accessible.name: qsTr("Send message")
                        onClicked: root.phone.sendMessage(phoneRow.modelData.value)
                    }
                }
            }

            Repeater {
                model: Phone.contactEntries(root.contact, "emails", "email", "home").filter(e => e.value !== "")

                Item {
                    id: emailRow

                    required property var modelData

                    width: parent.width
                    height: Math.max(Theme.itemSizeMedium, emailLabels.height + 2 * Theme.paddingMedium)

                    Icon {
                        id: emailIcon

                        x: Theme.horizontalPageMargin
                        anchors.verticalCenter: parent.verticalCenter
                        source: "image://theme/icon-m-mail"
                        color: Theme.highlightColor
                    }
                    Column {
                        id: emailLabels
                        anchors {
                            left: emailIcon.right
                            leftMargin: Theme.paddingLarge
                            right: parent.right
                            rightMargin: Theme.horizontalPageMargin
                            verticalCenter: parent.verticalCenter
                        }

                        Label {
                            textFormat: Text.PlainText
                            objectName: "emailValue"
                            width: parent.width
                            text: emailRow.modelData.value
                            wrapMode: Text.Wrap
                            color: Theme.highlightColor
                        }
                        Label {
                            textFormat: Text.PlainText
                            width: parent.width
                            text: Phone.kindName(emailRow.modelData.type)
                            wrapMode: Text.Wrap
                            font.pixelSize: Theme.fontSizeSmall
                            color: Theme.secondaryHighlightColor
                        }
                    }
                }
            }

            SectionHeader {
                visible: noteLabel.visible
                text: qsTr("Notes")
            }
            Label {
                id: noteLabel
                textFormat: Text.PlainText

                objectName: "noteValue"
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: text !== ""
                text: root.contact && root.contact.note || ""
                wrapMode: Text.Wrap
                color: Theme.highlightColor
            }
        }

        ViewPlaceholder {
            objectName: "contactUnavailable"
            enabled: root.contact === null
            text: qsTr("Contact unavailable")
            hintText: qsTr("Go back to People to check contacts access or choose another contact")
        }

        VerticalScrollDecorator {}
    }
}
