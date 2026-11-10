pragma ComponentBehavior: Bound
import QtQuick
import Sailfish.Silica 1.0
import Marathon.Silica 1.0
import Marathon.Platform 1.0
import "../Phone.js" as Phone

TabItem {
    id: root

    property var phone
    property real headerOffset
    property string query: ""
    readonly property var people: Phone.peopleRows(phone.contacts, query)

    function newContact() {
        phone.pageStack.push(Qt.resolvedUrl("ContactEditorDialog.qml"), {
            contact: null
        });
    }

    flickable: list

    SilicaListView {
        id: list

        objectName: "people"
        anchors.fill: parent
        model: root.people
        // With a pulley menu the tab spans the tab bar too.
        header: Item {
            width: list.width
            height: root.headerOffset + search.height

            SearchField {
                id: search

                objectName: "searchField"
                y: root.headerOffset
                width: parent.width
                visible: root.phone.contacts.length > 0
                height: visible ? implicitHeight : 0
                placeholderText: qsTr("Search people")
                onTextChanged: root.query = text
                EnterKey.iconSource: "image://theme/icon-m-enter-close"
                EnterKey.onClicked: focus = false
            }
        }

        PullDownMenu {
            MenuItem {
                visible: !root.phone.hasContactsPermission
                text: qsTr("Allow access to contacts")
                onClicked: Permissions.requestPermission(root.phone.appId, "contacts")
            }
            MenuItem {
                objectName: "newContactMenuItem"
                visible: root.phone.hasContactsPermission
                text: qsTr("New contact")
                onClicked: root.newContact()
            }
        }

        section.property: "section"
        section.delegate: SectionHeader {
            required property string section

            text: section === "*" ? qsTr("Favorites") : section
        }

        ViewPlaceholder {
            objectName: "peoplePlaceholder"
            enabled: list.count === 0
            text: !root.phone.hasContactsPermission ? qsTr("Contacts access is off") : root.phone.contacts.length === 0 ? qsTr("No people") : qsTr("No matches")
            hintText: !root.phone.hasContactsPermission ? qsTr("Pull down to let Phone show your contacts and name callers") : root.phone.contacts.length === 0 ? qsTr("Pull down to add someone") : ""
        }

        delegate: SummaryListItem {
            id: item

            required property var modelData

            objectName: "personItem"
            text: modelData.name || Phone.format(modelData.phone) || modelData.email || qsTr("Unnamed contact")
            description: modelData.name ? Phone.format(modelData.phone) || modelData.email || "" : ""
            iconSource: modelData.favorite ? "image://theme/icon-m-favorite-selected" : "image://theme/icon-m-contact"
            Accessible.description: modelData.favorite ? qsTr("Favorite") : ""
            menu: ContextMenu {
                MenuItem {
                    objectName: "callPersonMenuItem"
                    text: qsTr("Call")
                    enabled: (item.modelData.phone || "") !== ""
                    onClicked: root.phone.call(item.modelData.phone)
                }
                MenuItem {
                    objectName: "messagePersonMenuItem"
                    text: qsTr("Send message")
                    enabled: (item.modelData.phone || "") !== ""
                    onClicked: root.phone.sendMessage(item.modelData.phone)
                }
                MenuItem {
                    text: item.modelData.favorite ? qsTr("Remove from favorites") : qsTr("Add to favorites")
                    onClicked: Contacts.updateContact(item.modelData.id, {
                        favorite: !item.modelData.favorite
                    })
                }
            }
            onClicked: root.phone.pageStack.push(Qt.resolvedUrl("ContactPage.qml"), {
                phone: root.phone,
                contactId: modelData.id
            })
        }

        VerticalScrollDecorator {}
    }
}
