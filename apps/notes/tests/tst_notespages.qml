import QtQuick
import QtTest
import Sailfish.Silica 1.0
import Marathon.Silica 1.0
import ".."

TestCase {
    id: testCase
    name: "NotesPages"
    when: windowShown
    visible: true
    width: 540
    height: 1140

    Component {
        id: valueStub
        QtObject {
            property var value
        }
    }
    Component {
        id: appComponent
        NotesApp {
            width: 540
            height: 1140
        }
    }

    function note(id, extra) {
        return Object.assign({
            id: id,
            title: "Note " + id,
            content: "",
            timestamp: id * 1000
        }, extra || {});
    }

    function makeApp(notes, route) {
        const store = createTemporaryObject(valueStub, testCase, {
            value: JSON.stringify(notes || [])
        });
        const flag = createTemporaryObject(valueStub, testCase, {
            value: true
        });
        const app = createTemporaryObject(appComponent, testCase, {
            store: store,
            imported: flag,
            legacySettings: null,
            route: route || ""
        });
        tryVerify(() => app.workspace !== null && app.workspace.collectionPage !== null && !app.pageStack.busy);
        return app;
    }

    function view(app, name) {
        const v = findChild(app.workspace.collectionPage, name);
        verify(v, name);
        return v;
    }

    function delegateAt(v, index) {
        let item = null;
        tryVerify(() => (item = v.itemAtIndex(index)) !== null);
        return item;
    }

    function tapMenuItem(menu, name) {
        tryVerify(() => menu._open && menu.height > 0);
        wait(300);
        mouseClick(findChild(menu, name));
    }

    // A pull-down from the page's top opens its pulley menu.
    function pulleyIn(item) {
        if (!item)
            return null;
        if (item._isPullDownMenu === true && item.visible)
            return item;
        const children = item.children || [];
        for (let i = 0; i < children.length; ++i) {
            const found = pulleyIn(children[i]);
            if (found)
                return found;
        }
        return null;
    }

    function pullDown(item) {
        const menu = pulleyIn(item);
        verify(menu, "a pull-down menu");
        const x = item.width / 2;
        mousePress(item, x, 300);
        for (let y = 320; y <= 780; y += 40)
            mouseMove(item, x, y, 16);
        verify(menu.active, "pulley open");
        mouseRelease(item, x, 780);
        return menu;
    }

    function test_notesPulleyOpens() {
        const app = makeApp([note(1), note(2)]);
        pullDown(app.workspace.collectionPage);
    }

    function collection(app) {
        const stack = findChild(app.workspace, "collectionStack");
        tryVerify(() => stack.currentPage !== null && !stack.busy);
        return app.workspace.collectionPage;
    }

    function editor(app) {
        const stack = findChild(app.workspace, "editorStack");
        tryVerify(() => app.workspace.currentEditor !== null && !stack.busy);
        return app.workspace.currentEditor;
    }

    function test_listPinnedFirstThenNewest() {
        const app = makeApp([note(1), note(3), note(2, {
                pinned: true
            })]);
        compare(collection(app).shown.map(n => n.id), [2, 3, 1]);
        compare(view(app, "notesView").count, 3);
    }

    function test_emptyPlaceholder() {
        const app = makeApp([]);
        const p = findChild(collection(app), "placeholder");
        verify(p.enabled);
        compare(p.text, "No notes");
    }

    function test_searchFilters() {
        const app = makeApp([note(1, {
                title: "Groceries",
                content: "milk"
            }), note(2, {
                title: "Ideas"
            })]);
        const field = findChild(view(app, "notesView").headerItem, "searchField");
        field.text = "MILK";
        compare(collection(app).shown.map(n => n.id), [1]);
        field.text = "nothing";
        const p = findChild(collection(app), "placeholder");
        verify(p.enabled);
        compare(p.text, "No matching notes");
    }

    function test_searchTakesKeys() {
        const app = makeApp([note(1, {
                title: "Groceries",
                content: "milk"
            }), note(2, {
                title: "Ideas"
            })]);
        const field = findChild(view(app, "notesView").headerItem, "searchField");
        mouseClick(field);
        keyClick(Qt.Key_M);
        keyClick(Qt.Key_I);
        compare(field.text, "mi");
        compare(collection(app).shown.map(n => n.id), [1]);
        verify(field.activeFocus);
    }

    function test_tapOpensEditor() {
        const app = makeApp([note(1), note(2)]);
        mouseClick(delegateAt(view(app, "notesView"), 0));
        const opened = editor(app);
        compare(opened.noteId, 2);
        compare(findChild(opened, "bodyField").text, "Note 2");
    }

    function test_pulleyNewNote() {
        const app = makeApp([]);
        findChild(collection(app), "newNoteItem").clicked(null);
        compare(editor(app).noteId, -1);
    }

    function test_contextMenuPins() {
        const app = makeApp([note(1), note(2)]);
        const menu = delegateAt(view(app, "notesView"), 1).openMenu();
        tapMenuItem(menu, "pinItem");
        tryVerify(() => app.notes.find(n => n.id === 1).pinned === true);
        compare(collection(app).shown[0].id, 1);
    }

    function test_contextMenuRemorseDelete() {
        const app = makeApp([note(1), note(2)]);
        const menu = delegateAt(view(app, "notesView"), 0).openMenu();
        tapMenuItem(menu, "deleteItem");
        compare(app.notes.length, 2);
        tryVerify(() => app.notes.length === 1, 10000);
        compare(app.notes[0].id, 1);
    }

    function test_foldersFromTagsAndHashtags() {
        const app = makeApp([note(1, {
                tag: "work"
            }), note(2, {
                content: "see #home"
            }), note(3)], "/folders");
        const folders = collection(app);
        const v = findChild(folders, "foldersView");
        compare(v.count, 3);
        mouseClick(delegateAt(v, 1));
        const inFolder = collection(app);
        compare(inFolder.folder, "work");
        compare(inFolder.shown.map(n => n.id), [1]);
    }

    function test_tasksToggle() {
        const app = makeApp([note(4, {
                content: "list\n- [ ] milk"
            })], "/tasks");
        const tasks = collection(app);
        const sw = findChild(delegateAt(findChild(tasks, "tasksView"), 0), "taskSwitch");
        verify(!sw.checked);
        mouseClick(sw);
        tryVerify(() => app.notes[0].content === "list\n- [x] milk");
        tryVerify(() => findChild(delegateAt(findChild(tasks, "tasksView"), 0), "taskSwitch").checked);
    }

    function test_taskRowTapToggles() {
        const app = makeApp([note(4, {
                content: "list\n- [ ] milk"
            })], "/tasks");
        const tasks = collection(app);
        mouseClick(delegateAt(findChild(tasks, "tasksView"), 0), 400, 20);
        tryVerify(() => app.notes[0].content === "list\n- [x] milk");
        compare(app.workspace.collectionPage, tasks);
        compare(app.workspace.currentEditor, null);
    }

    function test_taskMenuOpensNote() {
        const app = makeApp([note(4, {
                content: "- [ ] milk"
            })], "/tasks");
        const tasks = collection(app);
        const menu = delegateAt(findChild(tasks, "tasksView"), 0).openMenu();
        tapMenuItem(menu, "openNoteItem");
        compare(editor(app).noteId, 4);
    }

    function test_newTaskPulleyCreatesTaskNote() {
        const app = makeApp([], "/tasks");
        const tasks = collection(app);
        findChild(tasks, "newTaskItem").clicked();
        const opened = editor(app);
        verify(opened.taskRequested);
        findChild(opened, "bodyField").text = "Buy milk";
        opened.commit();
        compare(app.notes.length, 1);
        compare(app.notes[0].task, {
            completed: false
        });
        app.handleBack();
        tryCompare(app.workspace, "currentEditor", null);
        compare(collection(app), tasks);
        compare(findChild(tasks, "tasksView").count, 1);
    }

    function test_taskNoteCompletesWithoutCheckingItsChecklist() {
        const app = makeApp([note(4, {
                title: "Plan trip",
                content: "Plan trip\n- [ ] book ferry",
                task: {
                    completed: false,
                    dueDate: "2026-12-10"
                },
                source: {
                    kind: "message",
                    appId: "org.marathonos.messages",
                    itemId: "m:4",
                    label: "Travel ideas"
                }
            })], "/tasks");
        const tasks = collection(app);
        const list = findChild(tasks, "tasksView");
        compare(list.count, 2);
        const sw = findChild(delegateAt(list, 0), "taskSwitch");
        compare(sw.description, "Due 2026-12-10");
        mouseClick(sw);
        tryVerify(() => app.notes[0].task.completed);
        compare(app.notes[0].content, "Plan trip\n- [ ] book ferry");
        compare(app.notes[0].source.itemId, "m:4");
        mouseClick(findChild(delegateAt(list, 1), "taskSwitch"));
        tryVerify(() => app.notes[0].content === "Plan trip\n- [x] book ferry");
        verify(app.notes[0].task.completed);
    }

    function test_coverNewNote() {
        const app = makeApp([]);
        app.newNote();
        compare(editor(app).noteId, -1);
    }
}
