import QtQuick
import QtTest
import Sailfish.Silica 1.0
import Marathon.Silica 1.0
import Keel.Actions 1.0
import ".."
import "../NotesStore.js" as Store

TestCase {
    id: testCase

    name: "NotesRecovery"
    when: windowShown
    visible: true
    width: 540
    height: 1140

    // An observable property-assignment failure. ConfigurationValue's real
    // backend does not expose a disk acknowledgment, so this is not a disk test.
    Component {
        id: rejectingValueComponent
        QtObject {
            property string original
            readonly property string value: original
        }
    }
    Component {
        id: appComponent
        NotesApp {
            id: fixture

            property string initialData: "[]"
            property QtObject config: QtObject {
                property var value: fixture.initialData
            }
            property QtObject importFlag: QtObject {
                property var value: true
            }

            store: config
            imported: importFlag
            legacySettings: null
            width: 540
            height: 1140
        }
    }
    Component {
        id: failedOpenComponent
        NotesApp {
            width: 540
            height: 1140
            store: QtObject {
                property var value: "[]"
            }
            imported: QtObject {
                property var value: true
            }
            legacySettings: null
            function openNote(noteId) {
                throw new Error("The native page could not be opened");
            }
        }
    }
    Component {
        id: legacyComponent
        QtObject {
            property int reads: 0
            function get(key, fallback) {
                reads++;
                return '[{"id":1,"title":"Old note","content":"Keep this","timestamp":1}]';
            }
        }
    }
    Component {
        id: permissionsComponent
        QtObject {
            function hasPermission(appId, permission) {
                return appId === "notes" && permission === "storage";
            }
        }
    }

    function notes() {
        return [
            {
                id: 1,
                title: "First",
                content: "First",
                timestamp: 1
            },
            {
                id: 2,
                title: "Second",
                content: "Second",
                timestamp: 2
            }
        ];
    }

    function makeApp(stored) {
        const app = createTemporaryObject(appComponent, testCase, {
            initialData: stored === undefined ? JSON.stringify(notes()) : stored
        });
        verify(app);
        tryVerify(() => app.workspace !== null && app.workspace.collectionPage !== null && !app.pageStack.busy);
        return {
            app: app,
            config: app.config,
            flag: app.importFlag
        };
    }

    function rejectWrites(t) {
        t.app.store = rejectingValueComponent.createObject(t.app, {
            original: t.config.value
        });
    }

    function editor(t, id) {
        t.app.workspace.openNote(id === undefined ? 1 : id);
        const stack = findChild(t.app.workspace, "editorStack");
        tryVerify(() => t.app.workspace.currentEditor !== null && !stack.busy);
        const page = t.app.workspace.currentEditor;
        tryCompare(page, "status", PageStatus.Active);
        return page;
    }

    function draft(t) {
        const page = editor(t);
        rejectWrites(t);
        const field = findChild(page, "bodyField");
        field.forceActiveFocus();
        field.text = "First\nPending words";
        field.cursorPosition = 8;
        return page;
    }

    function retained(t, page) {
        verify(t.app.workspace.currentEditor === page, "The same draft editor is retained");
        compare(page.draftText, "First\nPending words");
        compare(findChild(page, "bodyField").cursorPosition, 8);
        compare(t.app.store.value, t.config.value);
        verify(!page.discarded);
        verify(!page.backNavigation);
    }

    function test_recordStatusExplainsAcceptanceLimit() {
        const t = makeApp();
        const recovery = findChild(t.app.workspace, "recoveryStatus");
        verify(!recovery.visible);
        compare(recovery.height, 0);
        const page = editor(t);
        compare(findChild(page, "recordStatus").value, "Changes recorded");
        const field = findChild(page, "bodyField");
        field.text = "Changed";
        compare(findChild(page, "recordStatus").value, "Draft");
        verify(page.commit());
        compare(findChild(page, "recordStatus").value, "Changes recorded");
        findChild(page, "recordStatus").clicked(null);
        const stack = findChild(t.app.workspace, "editorStack");
        tryVerify(() => stack.currentPage !== page && !stack.busy);
        const explanation = findChild(stack.currentPage, "recordingMeaning").text;
        verify(explanation.indexOf("accepted your edits") >= 0);
        verify(explanation.indexOf("cannot confirm") >= 0);
        verify(t.app.workspace.handleBack());
        tryVerify(() => stack.currentPage === page, 5000, "Dialog Back returns to the same editor");
    }

    function test_failedAutosaveRetainsDraftAndRetryRecordsOnce() {
        const t = makeApp("[]");
        t.app.newNote();
        const stack = findChild(t.app.workspace, "editorStack");
        tryVerify(() => t.app.workspace.currentEditor !== null && !stack.busy);
        const page = t.app.workspace.currentEditor;
        rejectWrites(t);
        findChild(page, "bodyField").text = "New capture";
        tryCompare(page, "recordState", "error");
        compare(page.noteId, -1);
        compare(t.app.notes.length, 0);
        compare(t.app.store.value, "[]");
        compare(findChild(page, "recordStatus").value, "Changes not recorded");
        findChild(page, "copyDraftButton").clicked(null);
        compare(Clipboard.text, "New capture");
        findChild(page, "retryDraftButton").clicked(null);
        compare(page.recordState, "error");
        t.app.store = t.config;
        findChild(page, "retryDraftButton").clicked(null);
        compare(page.recordState, "recorded");
        compare(t.app.notes.length, 1);
        compare(page.noteId, 1);
        compare(t.app.notes[0].content, "New capture");
        verify(page.commit());
        compare(t.app.notes.length, 1);
    }

    function test_failedTransition_data() {
        return [
            {
                tag: "close",
                operation: "close"
            },
            {
                tag: "different note",
                operation: "open"
            },
            {
                tag: "same note",
                operation: "same"
            },
            {
                tag: "new note",
                operation: "new"
            },
            {
                tag: "notes section",
                operation: "notes"
            },
            {
                tag: "tasks section",
                operation: "tasks"
            },
            {
                tag: "folders section",
                operation: "folders"
            },
            {
                tag: "open folder",
                operation: "folder"
            },
            {
                tag: "runner Back",
                operation: "back"
            },
            {
                tag: "cover action",
                operation: "cover"
            },
            {
                tag: "make task",
                operation: "task"
            },
            {
                tag: "pin",
                operation: "pin"
            }
        ];
    }

    function test_failedTransition(data) {
        const t = makeApp();
        const page = draft(t);
        const collection = t.app.workspace.collectionPage;
        switch (data.operation) {
        case "close":
            t.app.workspace.closeEditor();
            break;
        case "open":
            t.app.workspace.openNote(2);
            break;
        case "same":
            t.app.workspace.openNote(1);
            break;
        case "new":
            t.app.workspace.newNote();
            break;
        case "notes":
            t.app.workspace.showNotes();
            break;
        case "tasks":
            t.app.workspace.showTasks();
            break;
        case "folders":
            t.app.workspace.showFolders();
            break;
        case "folder":
            t.app.workspace.openFolder("home");
            break;
        case "back":
            t.app.handleBack();
            break;
        case "cover":
            {
                const cover = createTemporaryObject(t.app.cover, testCase);
                verify(cover);
                findChild(cover, "newNoteAction").triggered();
                break;
            }
        case "task":
            findChild(page, "makeTaskItem").clicked();
            break;
        case "pin":
            findChild(page, "pinNoteItem").clicked();
            break;
        }
        retained(t, page);
        compare(page.recordState, "error");
        compare(t.app.workspace.collectionPage, collection);
        compare(t.app.notes.length, 2);
    }

    function test_nativeBackAndDialogBackKeepFailedDraft() {
        const t = makeApp();
        const page = draft(t);
        const stack = findChild(t.app.workspace, "editorStack");
        page.focusEditor();
        keyClick(Qt.Key_Escape);
        retained(t, page);
        stack.navigateBack(PageStackAction.Immediate);
        retained(t, page);
        mouseDrag(page, 2, Theme.itemSizeSmall / 2, page.width * 0.8, 0);
        retained(t, page);
        t.app.workspace.showRecovery();
        tryVerify(() => stack.currentPage !== page && !stack.busy);
        stack.currentPage.forceActiveFocus();
        keyClick(Qt.Key_Escape);
        tryVerify(() => stack.currentPage === page, 5000, "Dialog Back returns to the same editor");
        retained(t, page);
        t.app.store = t.config;
        page.focusEditor();
        keyClick(Qt.Key_Escape);
        tryCompare(t.app.workspace, "currentEditor", null);
        compare(t.app.notes[0].content, "First\nPending words");
        compare(t.app.pageStack.depth, 1);
    }

    function test_deactivationAndMissingBlankNoteCannotDiscardDraft() {
        const t = makeApp();
        const page = editor(t);
        findChild(page, "bodyField").text = " ";
        t.config.value = "[]";
        verify(!page.commit());
        compare(page.recordState, "error");
        verify(!page.backNavigation);
        t.app.workspace.showRecovery();
        tryCompare(page, "status", PageStatus.Inactive);
        compare(page.draftText, " ");
        verify(t.app.workspace.handleBack());
        tryCompare(page, "status", PageStatus.Active);
        verify(!t.app.workspace.closeEditor());
        verify(t.app.workspace.currentEditor === page, "The same draft editor is retained");
    }

    function test_failedDeleteKeepsUndiscardedEditor() {
        const t = makeApp();
        const page = draft(t);
        page.deleteNote();
        tryVerify(() => t.app.storageError !== "", 10000);
        // Remorse completes later than autosave; exercise the removal boundary
        // itself as well, including the retained editor's discard flag.
        wait(5500);
        retained(t, page);
        compare(t.app.notes.length, 2);
        verify(!t.app.workspace.removeNote(1));
        retained(t, page);
        t.app.store = t.config;
        verify(page.commit());
        compare(t.app.notes[0].content, "First\nPending words");
    }

    function test_metadataWriteFailure_data() {
        return [
            {
                tag: "make task",
                operation: "make"
            },
            {
                tag: "pin",
                operation: "pin"
            },
            {
                tag: "complete",
                operation: "complete"
            },
            {
                tag: "clear date",
                operation: "clear"
            },
            {
                tag: "choose date",
                operation: "date"
            },
            {
                tag: "adjacent task",
                operation: "adjacent"
            }
        ];
    }

    function test_metadataWriteFailure(data) {
        const initial = notes();
        if (data.operation !== "make")
            initial[0].task = {
                completed: false,
                dueDate: "2027-02-15"
            };
        const t = makeApp(JSON.stringify(initial));
        const page = editor(t);
        rejectWrites(t);
        const before = t.app.store.value;
        switch (data.operation) {
        case "make":
            findChild(page, "makeTaskItem").clicked();
            break;
        case "pin":
            findChild(page, "pinNoteItem").clicked();
            break;
        case "complete":
            findChild(page, "taskCompletedSwitch").clicked(null);
            break;
        case "clear":
            findChild(page, "clearDueDateItem").clicked();
            break;
        case "date":
            {
                findChild(page, "taskDueDateButton").clicked(null);
                const stack = findChild(t.app.workspace, "editorStack");
                tryVerify(() => stack.currentPage !== page && !stack.busy);
                stack.currentPage.date = new Date(2027, 3, 15, 12);
                stack.currentPage.accept();
                tryVerify(() => stack.currentPage === page && !stack.busy);
                break;
            }
        case "adjacent":
            t.app.workspace.toggleTask({
                kind: "task",
                noteId: 1,
                checked: false
            });
            break;
        }
        verify(t.app.storageError !== "");
        verify(findChild(t.app.workspace, "recoveryStatus").visible);
        compare(t.app.store.value, before);
        verify(t.app.workspace.currentEditor === page);
        compare(page.draftText, "First");
        verify(!page.discarded);
    }

    function test_failedShareRetainsBothDraftAndIncomingText() {
        const t = makeApp();
        const page = draft(t);
        verify(!t.app.receiveShare([
            {
                data: "Shared first"
            }
        ]));
        verify(!t.app.receiveShare([
            {
                data: "Shared second"
            }
        ]));
        compare(t.app.pendingShares, ["Shared first", "Shared second"]);
        retained(t, page);
        t.app.workspace.showRecovery();
        const stack = findChild(t.app.workspace, "editorStack");
        tryVerify(() => stack.currentPage !== page && !stack.busy);
        const recovery = stack.currentPage;
        findChild(recovery, "copySharedButton").clicked(null);
        compare(Clipboard.text, "Shared first");
        findChild(recovery, "copyRecoveryDraftButton").clicked(null);
        compare(Clipboard.text, "First\nPending words");
        findChild(recovery, "retrySharedButton").clicked(null);
        retained(t, page);
        compare(t.app.pendingShares.length, 2);
        t.app.store = t.config;
        verify(t.app.retryShare());
        compare(t.app.notes.length, 3);
        compare(t.app.pendingShares, ["Shared second"]);
        compare(t.app.workspace.currentEditor.noteId, 3);
        verify(t.app.retryShare());
        compare(t.app.notes.length, 4);
        compare(t.app.pendingShares, []);
        compare(t.app.workspace.currentEditor.noteId, 4);
        verify(t.app.retryShare());
        compare(t.app.notes.length, 4);
        compare(t.app.notes.find(n => n.id === 1).content, "First\nPending words");
    }

    function test_acceptedShareIsNotRecreatedAfterOpenFailure() {
        const app = createTemporaryObject(failedOpenComponent, testCase);
        tryVerify(() => app.workspace !== null && app.workspace.collectionPage !== null && !app.pageStack.busy);
        app.store.value = JSON.stringify(notes());
        verify(!app.receiveShare([
            {
                data: "Accepted shared text"
            }
        ]));
        compare(app.pendingShares, []);
        compare(app.notes.length, 3);
        compare(app.notes[0].id, 3);
        compare(app.notes[0].content, "Accepted shared text");
        verify(app.storageError.indexOf("recorded but could not be opened") >= 0);
        const accepted = app.store.value;
        verify(app.retryShare());
        compare(app.store.value, accepted);
        compare(app.notes.length, 3);
        compare(app.notes[0].id, 3);
    }

    function test_protectedStore_data() {
        return [
            {
                tag: "corrupted",
                original: " {broken data\n"
            },
            {
                tag: "newer format",
                original: '{"version":3,"nextId":9,"notes":[{"id":8,"title":"Future"}]}'
            }
        ];
    }

    function test_protectedStore(data) {
        const t = makeApp(data.original);
        verify(t.app.storageProtected);
        compare(findChild(t.app.workspace.collectionPage, "placeholder").text, "Notes need recovery");
        t.app.legacySettings = createTemporaryObject(legacyComponent, testCase);
        t.app.permissions = createTemporaryObject(permissionsComponent, testCase);
        t.flag.value = false;
        t.app.importLegacy();
        compare(t.app.legacySettings.reads, 0);
        verify(!t.flag.value);
        t.app.newNote();
        const page = t.app.workspace.currentEditor;
        findChild(page, "bodyField").text = "Rescue this draft";
        verify(!page.commit());
        verify(!t.app.workspace.closeEditor());
        verify(!t.app.receiveShare([
            {
                data: "Shared rescue"
            }
        ]));
        for (const action of ["notes.create", "tasks.create", "notes.search", "tasks.list", "notes.open", "tasks.set_completed"]) {
            const args = action === "notes.create" ? {
                body: "New"
            } : action === "tasks.create" ? {
                title: "New"
            } : action === "notes.search" ? {
                query: ""
            } : action === "tasks.set_completed" ? {
                id: 8,
                completed: true
            } : action === "notes.open" ? {
                id: 8
            } : {};
            const call = KeelActions.invoke(action, args);
            compare(call.errorCode, "Failed", action + ": " + call.errorMessage);
        }
        t.app.workspace.showRecovery();
        const stack = findChild(t.app.workspace, "editorStack");
        tryVerify(() => stack.currentPage !== page && !stack.busy);
        findChild(stack.currentPage, "copyOriginalButton").clicked(null);
        compare(Clipboard.text, data.original);
        findChild(stack.currentPage, "retryRecoveryDraftButton").clicked(null);
        findChild(stack.currentPage, "retrySharedButton").clicked(null);
        compare(t.app.store.value, data.original);
        compare(page.draftText, "Rescue this draft");
        compare(t.app.pendingShares, ["Shared rescue"]);
        verify(!t.flag.value);
    }

    function test_failedLegacyImportDoesNotMarkImported() {
        const t = makeApp("[]");
        rejectWrites(t);
        t.app.legacySettings = createTemporaryObject(legacyComponent, testCase);
        t.app.permissions = createTemporaryObject(permissionsComponent, testCase);
        t.flag.value = false;
        t.app.importLegacy();
        verify(!t.flag.value);
        compare(t.app.store.value, "[]");
        verify(t.app.storageError.indexOf("could not be imported") >= 0);
        t.app.store = t.config;
        t.app.importLegacy();
        verify(t.flag.value);
        compare(t.app.notes.length, 1);
    }

    function test_openActionSelectsExactIdAndFlushesSameId() {
        const t = makeApp();
        const page = editor(t);
        findChild(page, "bodyField").text = "First edited";
        const same = KeelActions.invoke("notes.open", {
            id: 1
        });
        verify(same.succeeded, same.errorMessage);
        compare(same.result, {
            id: 1
        });
        verify(t.app.workspace.currentEditor === page, "The same draft editor is retained");
        compare(t.app.notes.find(n => n.id === 1).content, "First edited");
        const opened = KeelActions.invoke("notes.open", {
            id: 2
        });
        verify(opened.succeeded, opened.errorMessage);
        compare(opened.result, {
            id: 2
        });
        compare(t.app.workspace.currentEditor.noteId, 2);
        const before = t.app.store.value;
        verify(KeelActions.invoke("notes.open", {
            id: 2
        }).succeeded);
        compare(t.app.store.value, before);
    }

    function test_openActionFailureNeverChangesSelectedDraft() {
        const t = makeApp();
        const page = draft(t);
        for (const id of [1, 2]) {
            const call = KeelActions.invoke("notes.open", {
                id: id
            });
            compare(call.errorCode, "Failed");
            retained(t, page);
        }
        for (const id of [0, -1, 1.2, 2147483648, "1", 99]) {
            const call = KeelActions.invoke("notes.open", {
                id: id
            });
            compare(call.errorCode, "InvalidArguments");
            retained(t, page);
        }
        compare(KeelActions.invoke("notes.open", {}).errorCode, "InvalidArguments");
        retained(t, page);
    }

    function test_createAndCompleteActionRejectUnacceptedWrite() {
        const t = makeApp(JSON.stringify([
            {
                id: 1,
                title: "Task",
                content: "Task",
                timestamp: 1,
                task: {
                    completed: false
                }
            }
        ]));
        rejectWrites(t);
        const before = t.app.store.value;
        for (const action of ["notes.create", "tasks.create", "tasks.set_completed"]) {
            const args = action === "notes.create" ? {
                body: "New"
            } : action === "tasks.create" ? {
                title: "New"
            } : {
                id: 1,
                completed: true
            };
            compare(KeelActions.invoke(action, args).errorCode, "Failed");
            compare(t.app.store.value, before);
        }
    }
}
