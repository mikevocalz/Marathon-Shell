import QtQuick
import QtTest
import Sailfish.Silica 1.0
import Marathon.Silica 1.0
import Keel.Actions 1.0
import "../pages"
import "../NotesStore.js" as Store

TestCase {
    id: testCase
    name: "NoteEditorPage"
    when: windowShown
    visible: true
    width: 540
    height: 1140

    Component {
        id: storeStub
        QtObject {
            property var notes: []
            property double nextNoteId: 1
            property int saves: 0
            function save(next) {
                notes = next;
                nextNoteId = Math.max(nextNoteId, Store.nextId(next));
                saves++;
            }
        }
    }
    Component {
        id: pageComponent
        NoteEditorPage {
            width: 540
            height: 1140
        }
    }
    Component {
        id: appComponent
        ApplicationWindow {
            width: 540
            height: 1140
            initialPage: Component {
                Page {}
            }
        }
    }

    function test_typingSavesWithoutLeavingPage() {
        const store = createTemporaryObject(storeStub, this);
        const page = createTemporaryObject(pageComponent, this, {
            store: store,
            noteId: -1
        });
        findChild(page, "bodyField").text = "A";
        tryCompare(store, "saves", 1, 3000);
        compare(store.notes.length, 1);
        compare(page.noteId, store.notes[0].id);

        findChild(page, "bodyField").text = "A\nmore";
        tryCompare(store, "saves", 2, 3000);
        compare(store.notes.length, 1);
        compare(store.notes[0].title, "A");
        compare(store.notes[0].content, "A\nmore");
    }

    function test_emptyNewNoteIsNotSaved() {
        const store = createTemporaryObject(storeStub, this);
        const page = createTemporaryObject(pageComponent, this, {
            store: store,
            noteId: -1
        });
        findChild(page, "bodyField").text = "  \n ";
        page.commit();
        compare(store.saves, 0);
    }

    function test_openingDoesNotSave() {
        const store = createTemporaryObject(storeStub, this, {
            notes: [
                {
                    id: 3,
                    title: "T",
                    content: "B",
                    timestamp: 1
                }
            ]
        });
        const page = createTemporaryObject(pageComponent, this, {
            store: store,
            noteId: 3
        });
        compare(findChild(page, "bodyField").text, "T\nB");
        wait(1000);
        page.commit();
        compare(store.saves, 0);
    }

    function test_savingDoesNotRewriteTheField() {
        const store = createTemporaryObject(storeStub, this);
        const page = createTemporaryObject(pageComponent, this, {
            store: store,
            noteId: -1
        });
        const body = findChild(page, "bodyField");
        body.text = "Hello ";
        page.commit();
        compare(store.notes[0].title, "Hello");
        compare(body.text, "Hello ");
    }

    function test_headerShowsDateNotTitle() {
        const store = createTemporaryObject(storeStub, this, {
            notes: [
                {
                    id: 3,
                    title: "T",
                    content: "T",
                    timestamp: new Date(2025, 8, 7).getTime()
                }
            ]
        });
        const page = createTemporaryObject(pageComponent, this, {
            store: store,
            noteId: 3
        });
        compare(findChild(page, "header").title, "7 Sep 2025");
        verify(!findChild(page, "titleField"));
    }

    function test_editKeepsPin() {
        const store = createTemporaryObject(storeStub, this, {
            notes: [
                {
                    id: 3,
                    title: "T",
                    content: "",
                    timestamp: 1,
                    pinned: true
                }
            ]
        });
        const page = createTemporaryObject(pageComponent, this, {
            store: store,
            noteId: 3
        });
        findChild(page, "bodyField").text = "T\nx";
        page.commit();
        compare(store.notes[0].content, "T\nx");
        verify(store.notes[0].pinned);
    }

    function test_pulleyPinToggles() {
        const store = createTemporaryObject(storeStub, this, {
            notes: [
                {
                    id: 3,
                    title: "T",
                    content: "",
                    timestamp: 1
                }
            ]
        });
        const page = createTemporaryObject(pageComponent, this, {
            store: store,
            noteId: 3
        });
        findChild(page, "pinNoteItem").clicked(null);
        verify(store.notes[0].pinned);
        findChild(page, "pinNoteItem").clicked(null);
        verify(!store.notes[0].pinned);
    }

    function test_makeTaskCommitsTextAndKeepsNoteId() {
        const store = createTemporaryObject(storeStub, this, {
            notes: [
                {
                    id: 3,
                    title: "Call",
                    content: "Call\nAna",
                    timestamp: 1,
                    pinned: true
                }
            ]
        });
        const page = createTemporaryObject(pageComponent, this, {
            store: store,
            noteId: 3
        });
        findChild(page, "bodyField").text = "Call Ana\nAsk about Friday";
        findChild(page, "makeTaskItem").clicked();
        compare(store.notes[0].id, 3);
        compare(store.notes[0].content, "Call Ana\nAsk about Friday");
        verify(store.notes[0].pinned);
        compare(store.notes[0].task, {
            completed: false
        });
        findChild(page, "taskCompletedSwitch").clicked(null);
        verify(store.notes[0].task.completed);
        findChild(page, "taskCompletedSwitch").clicked(null);
        verify(!store.notes[0].task.completed);
    }

    function test_newTaskIsOnlySavedAfterTyping() {
        const store = createTemporaryObject(storeStub, this, {
            nextNoteId: 42
        });
        const page = createTemporaryObject(pageComponent, this, {
            store: store,
            taskRequested: true
        });
        compare(findChild(page, "header").title, "New task");
        page.commit();
        compare(store.saves, 0);
        findChild(page, "bodyField").text = "Buy milk\nOn the way home";
        page.commit();
        compare(store.notes.length, 1);
        compare(store.notes[0].id, 42);
        compare(store.notes[0].content, "Buy milk\nOn the way home");
        compare(store.notes[0].task, {
            completed: false
        });
    }

    function test_taskSourceAndDueDateSurviveEditing() {
        const source = {
            kind: "event",
            appId: "org.marathonos.calendar",
            itemId: "event:3",
            label: "Friday meeting"
        };
        const store = createTemporaryObject(storeStub, this, {
            notes: [
                {
                    id: 3,
                    title: "Call",
                    content: "Call",
                    timestamp: 1,
                    task: {
                        completed: false,
                        dueDate: "2026-12-10"
                    },
                    source: source
                }
            ]
        });
        const page = createTemporaryObject(pageComponent, this, {
            store: store,
            noteId: 3
        });
        compare(findChild(page, "taskSourceLabel").value, "Friday meeting");
        compare(findChild(page, "taskSourceLabel").valueTextFormat, Text.PlainText);
        compare(findChild(page, "taskDueDateButton").value, "2026-12-10");
        findChild(page, "bodyField").text = "Call tomorrow";
        findChild(page, "clearDueDateItem").clicked();
        compare(store.notes[0].content, "Call tomorrow");
        verify(store.notes[0].task.dueDate === undefined);
        compare(store.notes[0].source, source);
        compare(findChild(page, "taskDueDateButton").value, "None");
    }

    function test_taskDueDateUsesNativePicker() {
        const store = createTemporaryObject(storeStub, this, {
            notes: [
                {
                    id: 3,
                    title: "Call",
                    content: "Call",
                    timestamp: 1,
                    task: {
                        completed: false,
                        dueDate: "2026-12-10"
                    }
                }
            ]
        });
        const app = createTemporaryObject(appComponent, testCase);
        tryVerify(() => app.pageStack.currentPage !== null);
        app.pageStack.push(pageComponent, {
            store: store,
            noteId: 3
        }, PageStackAction.Immediate);
        const page = app.pageStack.currentPage;
        tryCompare(page, "status", PageStatus.Active);
        findChild(page, "taskDueDateButton").clicked(null);
        tryCompare(app.pageStack, "depth", 3);
        tryVerify(() => !app.pageStack.busy);
        let picker = app.pageStack.currentPage;
        compare(Qt.formatDate(picker.date, "yyyy-MM-dd"), "2026-12-10");
        picker.date = new Date(2027, 0, 15, 12, 0);
        picker.reject();
        tryCompare(app.pageStack, "depth", 2);
        tryVerify(() => !app.pageStack.busy);
        compare(store.notes[0].task.dueDate, "2026-12-10");
        compare(store.notes[0].content, "Call");
        compare(store.saves, 0);

        findChild(page, "taskDueDateButton").clicked(null);
        tryCompare(app.pageStack, "depth", 3);
        tryVerify(() => !app.pageStack.busy);
        picker = app.pageStack.currentPage;
        picker.date = new Date(2027, 0, 15, 12, 0);
        picker.accept();
        tryCompare(app.pageStack, "depth", 2);
        compare(store.notes[0].task.dueDate, "2027-01-15");
        compare(store.notes[0].content, "Call");
    }

    function test_contextIsTheNoteOnScreen() {
        const store = createTemporaryObject(storeStub, this, {
            notes: [
                {
                    id: 3,
                    title: "T",
                    content: "T\nB",
                    timestamp: 1
                }
            ]
        });
        const app = createTemporaryObject(appComponent, testCase);
        tryVerify(() => app.pageStack.currentPage !== null);
        compare(JSON.stringify(KeelActions.context()), "{}");

        app.pageStack.push(pageComponent, {
            store: store,
            noteId: 3
        }, PageStackAction.Immediate);
        const page = app.pageStack.currentPage;
        tryCompare(page, "status", PageStatus.Active);
        compare(KeelActions.context().purpose, "editing a note");
        compare(KeelActions.context().text, "T\nB");

        findChild(page, "bodyField").text = "T\nB and C";
        compare(KeelActions.context().text, "T\nB and C");

        app.pageStack.push(Qt.createComponent("Sailfish.Silica", "Page"), {}, PageStackAction.Immediate);
        tryCompare(page, "status", PageStatus.Inactive);
        compare(JSON.stringify(KeelActions.context()), "{}");
    }

    function test_deleteWithRemorsePops() {
        const store = createTemporaryObject(storeStub, this, {
            notes: [
                {
                    id: 3,
                    title: "T",
                    content: "",
                    timestamp: 1
                },
                {
                    id: 4,
                    title: "U",
                    content: "",
                    timestamp: 2
                }
            ]
        });
        const app = createTemporaryObject(appComponent, testCase);
        tryVerify(() => app.pageStack.currentPage !== null);
        app.pageStack.push(pageComponent, {
            store: store,
            noteId: 3
        }, PageStackAction.Immediate);
        const page = app.pageStack.currentPage;
        findChild(page, "bodyField").text = "edited";
        page.deleteNote();
        compare(store.notes.length, 2);
        tryCompare(app.pageStack, "depth", 1, 10000);
        compare(store.notes.map(n => n.id), [4]);
    }
}
