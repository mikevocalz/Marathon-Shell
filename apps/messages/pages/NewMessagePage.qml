pragma ComponentBehavior: Bound

import QtQuick
import Sailfish.Silica 1.0
import Marathon.Silica 1.0
import Marathon.Platform 1.0
import "../MessagesLogic.js" as Logic

Page {
    id: root

    property var app
    property string typed: ""
    // Shared text, the new thread's draft.
    property string sharedText: ""
    property var sharedAttachments: []
    property bool submitted: false
    readonly property bool hasLetters: /[A-Za-z]/.test(typed)
    readonly property bool isNumber: !hasLetters && Logic.isPhoneNumber(typed)
    readonly property var matches: Contacts.contacts.filter(c => Logic.matches(typed, c.name, c.phone, ""))

    function startWithTyped() {
        if (isNumber)
            app.startConversation(Logic.normaliseNumber(typed), "", sharedText, sharedAttachments);
        else
            submitted = true;
    }

    onStatusChanged: if (status === PageStatus.Active && typed === "")
        recipient.forceActiveFocus()

    // Outside the view: a list view moves focus to its current item whenever its model changes.
    Column {
        id: form
        width: parent.width

        PageHeader {
            title: qsTr("New message")
        }
        TextField {
            id: recipient
            objectName: "recipientField"
            width: parent.width
            label: qsTr("To")
            placeholderText: qsTr("Name or phone number")
            inputMethodHints: Qt.ImhNoPredictiveText
            description: root.typed === "" || root.isNumber ? "" : root.hasLetters ? (root.matches.length > 0 ? qsTr("Choose a contact below, or enter a phone number") : qsTr("No contact matches; enter a phone number")) : root.submitted ? qsTr("Enter at least 3 digits") : ""
            EnterKey.enabled: root.typed !== ""
            EnterKey.iconSource: "image://theme/icon-m-enter-next"
            EnterKey.onClicked: root.startWithTyped()
            onActiveFocusChanged: if (!activeFocus && root.typed !== "")
                root.submitted = true
            onTextChanged: {
                root.typed = text.trim();
                root.submitted = false;
            }
        }
        SummaryListItem {
            objectName: "typedNumberItem"
            visible: root.isNumber
            text: qsTr("Send to %1").arg(Sms.formatNumber(Logic.normaliseNumber(root.typed)))
            onClicked: root.startWithTyped()
        }
    }

    SilicaListView {
        id: view
        objectName: "contactList"
        anchors {
            top: form.bottom
            left: parent.left
            right: parent.right
            bottom: parent.bottom
        }
        clip: true
        model: root.matches

        header: SectionHeader {
            visible: view.count > 0
            text: qsTr("Contacts")
        }

        ViewPlaceholder {
            enabled: view.count === 0 && !root.isNumber
            text: root.typed === "" ? qsTr("No contacts") : qsTr("No contacts found")
            hintText: qsTr("Enter a phone number above")
        }

        delegate: SummaryListItem {
            required property var modelData

            objectName: "contact-" + modelData.phone
            text: modelData.name || Sms.formatNumber(modelData.phone)
            description: modelData.name ? Sms.formatNumber(modelData.phone) : ""
            onClicked: root.app.startConversation(modelData.phone, modelData.name, root.sharedText, root.sharedAttachments)
        }

        VerticalScrollDecorator {}
    }
}
