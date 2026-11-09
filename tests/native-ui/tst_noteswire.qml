pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import Keel.Actions 1.0
import Sailfish.Silica 1.0
import "../../apps/notes" as Notes

Item {
    id: root

    width: 540
    height: 1140

    // Production app, actions, store, workspace, and editor. Only external
    // Marathon.Platform is the same service fixture used by the Notes suite.
    Notes.NotesApp {
        id: notes

        anchors.fill: parent
        legacySettings: null
        permissions: null
    }

    TestCase {
        name: "NotesWireProvider"
        when: windowShown

        function test_realHubCaptureAndExactOpen() {
            compare(KeelActions.appId, "org.marathonos.notes");
            compare(notes.store.key, "/apps/notes/data");
            compare(notes.notes.length, 0);
            tryVerify(() => notes.workspace !== null, 5000);
            console.log("MARATHON_NOTES_WIRE_READY");

            tryVerify(() => notes.notes.length === 2, 90000, "Two actual wire create calls must reach the real Notes store");
            const capture = notes.notes.find(note => note.id === 1);
            const decoy = notes.notes.find(note => note.id === 2);
            verify(capture !== undefined);
            verify(decoy !== undefined);
            compare(capture.title, "Review <b>contract</b>");
            compare(capture.content, "Review <b>contract</b>\nCaptured notification body 📝\nKeep this text editable.");
            compare(capture.task.completed, false);
            compare(capture.source.kind, "notification");
            compare(capture.source.appId, "org.marathonos.hub");
            compare(capture.source.itemId, "notification:42:1700000000000");
            compare(capture.source.label, "<b>Mail</b> notification");
            compare(decoy.title, "Newer decoy");
            compare(notes.nextNoteId, 3);

            tryVerify(() => !!notes.workspace.currentEditor && notes.workspace.currentEditor.noteId === capture.id, 30000, "The real notes.open handler must select the requested older note");
            tryCompare(notes.workspace.currentEditor, "status", PageStatus.Active, 10000);
            compare(notes.workspace.currentEditor.draftText, capture.content);
            const sourceLabel = findChild(notes.workspace.currentEditor, "taskSourceLabel");
            verify(sourceLabel !== null);
            compare(sourceLabel.valueTextFormat, Text.PlainText);
            compare(sourceLabel.value, "<b>Mail</b> notification");
            console.log("MARATHON_NOTES_WIRE_VERIFIED " + JSON.stringify({
                created_count: notes.notes.length,
                selected_id: notes.workspace.currentEditor.noteId,
                selected_body: notes.workspace.currentEditor.draftText,
                source_kind: capture.source.kind,
                source_app_id: capture.source.appId,
                source_label: sourceLabel.value
            }));
        }
    }
}
