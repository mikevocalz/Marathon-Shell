// SPDX-FileCopyrightText: 2026 Patrick Quinn
// SPDX-License-Identifier: Apache-2.0

import QtQuick
import Sailfish.Silica 1.0
import Marathon.Silica 1.0

// The app and overlay edit the same unfinished prompt. Submission admission is
// synchronous; a busy or disconnected service leaves both the text and focus intact.
TextField {
    id: field

    signal submitted

    function submit() {
        if (!Conversation.send(text))
            return false;
        submitted();
        return true;
    }

    text: Conversation.draft
    label: qsTr("Ask Pilot")
    placeholderText: qsTr("Ask Pilot")
    EnterKey.enabled: Conversation.canSend && text.trim().length > 0
    EnterKey.iconSource: "image://theme/icon-m-enter-accept"
    EnterKey.onClicked: submit()
    onTextChanged: if (Conversation.draft !== text)
        Conversation.draft = text

    // Native edits or a caller may replace TextField.text's initial binding.
    // Avoid assigning identical text, which would disturb the active cursor.
    Connections {
        target: Conversation
        function onDraftChanged() {
            if (field.text !== Conversation.draft)
                field.text = Conversation.draft;
        }
    }
}
