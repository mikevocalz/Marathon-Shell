import QtQuick
import QtQuick.Window
import QtTest
import Sailfish.Silica 1.0
import Marathon.Silica 1.0
import Keel 1.0 as Native
import Keel.Actions 1.0
import ".."

TestCase {
    id: testCase

    name: "NotesWorkspace"
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

        NotesApp {}
    }
    Component {
        id: signalSpy

        SignalSpy {}
    }

    function note(id, content, extra) {
        return Object.assign({
            id: id,
            title: content.split("\n")[0],
            content: content,
            timestamp: id * 1000
        }, extra || {});
    }

    function resizeApp(app, width) {
        testCase.width = width;
        testCase.Window.window.width = width;
        testCase.Window.window.height = testCase.height;
        app.width = width;
        app.height = testCase.height;
        tryCompare(app.workspace, "width", width);
        verify(waitForRendering(app.workspace));
    }

    function makeApp(notes, width, route) {
        const store = createTemporaryObject(valueStub, testCase, {
            value: JSON.stringify(notes || [])
        });
        const imported = createTemporaryObject(valueStub, testCase, {
            value: true
        });
        const app = createTemporaryObject(appComponent, testCase, {
            width: width || 540,
            height: testCase.height,
            store: store,
            imported: imported,
            legacySettings: null,
            route: route || ""
        });
        verify(app);
        tryVerify(() => app.workspace !== null && app.workspace.collectionPage !== null && !app.pageStack.busy);
        resizeApp(app, width || 540);
        collection(app);
        return app;
    }

    function collection(app) {
        const stack = findChild(app.workspace, "collectionStack");
        verify(stack);
        tryVerify(() => stack.currentPage !== null && !stack.busy);
        return app.workspace.collectionPage;
    }

    function editor(app) {
        const stack = findChild(app.workspace, "editorStack");
        verify(stack);
        tryVerify(() => app.workspace.currentEditor !== null && !stack.busy);
        const page = app.workspace.currentEditor;
        tryCompare(page, "status", PageStatus.Active);
        verify(waitForRendering(page));
        return page;
    }

    function delegateAt(view, index) {
        let item = null;
        tryVerify(() => (item = view.itemAtIndex(index)) !== null);
        return item;
    }

    function cleanup() {
        Native.Ambience.applyForwarded("");
    }

    function test_visibleNavigation_data() {
        return [
            {
                tag: "compact",
                width: 540
            },
            {
                tag: "wide",
                width: 1440
            }
        ];
    }

    function test_visibleNavigation(data) {
        const app = makeApp([note(1, "Shopping\n- [ ] milk\n#home")], data.width);
        for (const section of ["notes", "tasks", "folders"]) {
            const button = findChild(app.workspace, section + "Tab");
            verify(button.visible && button.enabled);
            verify(button.width > 0 && button.height > 0);
            compare(button.Accessible.role, Accessible.Button);
            compare(button.Accessible.name, button.text);
        }

        mouseClick(findChild(app.workspace, "tasksTab"));
        compare(findChild(collection(app), "tasksView").count, 1);
        const folders = findChild(app.workspace, "foldersTab");
        folders.forceActiveFocus();
        keyClick(Qt.Key_Return);
        compare(findChild(collection(app), "foldersView").count, 1);
        const notes = findChild(app.workspace, "notesTab");
        notes.forceActiveFocus();
        keyClick(Qt.Key_Space);
        compare(findChild(collection(app), "notesView").count, 1);
        compare(app.workspace.currentEditor, null);
    }

    function test_reflowPreservesDraftCursorSelectionAndFocus() {
        const app = makeApp([note(1, "A note with a draft")]);
        app.workspace.openNote(1);
        const opened = editor(app);
        const body = findChild(opened, "bodyField");
        body.forceActiveFocus();
        body.cursorPosition = body.text.length;
        keyClick(Qt.Key_Space);
        keyClick(Qt.Key_X);
        const draft = "A note with a draft x";
        compare(body.text, draft);
        body.select(2, 6);
        const cursor = body.cursorPosition;
        verify(body.activeFocus);

        for (const width of [1440, 540]) {
            resizeApp(app, width);
            compare(app.workspace.isWide, width === 1440);
            compare(app.workspace.currentEditor, opened);
            compare(findChild(opened, "bodyField"), body);
            compare(opened.noteId, 1);
            compare(body.text, draft);
            compare(body.cursorPosition, cursor);
            compare(body.selectionStart, 2);
            compare(body.selectionEnd, 6);
            compare(body.selectedText, "note");
            verify(body.activeFocus, "resizing keeps the active native editor");
            compare(KeelActions.context().text, draft);
            const listing = app.workspace.collectionPage;
            if (app.workspace.isWide) {
                verify(listing.visible && opened.visible);
                const listOrigin = listing.mapToItem(app.workspace, 0, 0);
                const editorOrigin = opened.mapToItem(app.workspace, 0, 0);
                verify(listOrigin.x + listing.width <= editorOrigin.x);
                verify(editorOrigin.x + opened.width <= app.workspace.width);
                verify(listing.width > 0 && opened.width > 0);
            } else {
                verify(!listing.visible && opened.visible);
                compare(opened.width, app.workspace.width);
            }
        }

        keyClick(Qt.Key_Y);
        compare(body.text, "A y with a draft x");
        tryVerify(() => app.notes[0].content === "A y with a draft x");
        compare(app.notes.length, 1);
    }

    function test_newDraftReflowCreatesOneNote() {
        const app = makeApp([]);
        const writes = createTemporaryObject(signalSpy, testCase, {
            target: app.store,
            signalName: "valueChanged"
        });
        app.newNote();
        const opened = editor(app);
        const body = findChild(opened, "bodyField");
        body.forceActiveFocus();
        for (const key of [Qt.Key_D, Qt.Key_R, Qt.Key_A, Qt.Key_F, Qt.Key_T])
            keyClick(key);
        compare(body.text, "draft");
        resizeApp(app, 1440);
        resizeApp(app, 540);
        compare(app.workspace.currentEditor, opened);
        tryVerify(() => app.notes.length === 1);
        compare(app.notes[0].content, "draft");
        compare(opened.noteId, app.notes[0].id);
        compare(writes.count, 1);
        opened.commit();
        compare(writes.count, 1);
        compare(app.nextNoteId, app.notes[0].id + 1);
        app.handleBack();
        tryCompare(app.workspace, "currentEditor", null);
        tryVerify(() => app.workspace.collectionPage.activeFocus);
        verify(testCase.Window.window.activeFocusItem.visible, "closing the compact editor leaves focus on visible content");
    }

    function test_switchingNotesFlushesPendingAutosaveToItsOwnRecord() {
        const app = makeApp([note(1, "First note"), note(2, "Second note")], 1440);
        app.workspace.openNote(1);
        const first = editor(app);
        findChild(first, "bodyField").text = "First edited before autosave";
        compare(app.notes.find(n => n.id === 1).content, "First note");

        app.workspace.openNote(2);
        const second = editor(app);
        compare(second.noteId, 2);
        compare(app.notes.find(n => n.id === 1).content, "First edited before autosave");
        compare(findChild(second, "bodyField").text, "Second note");
        findChild(second, "bodyField").text = "Second edited afterward";
        tryVerify(() => app.notes.find(n => n.id === 2).content === "Second edited afterward");
        compare(app.notes.find(n => n.id === 1).content, "First edited before autosave");
        compare(app.notes.length, 2);
    }

    function test_sharePreservesPendingCaptureAndOpensSharedNote() {
        const app = makeApp([]);
        app.newNote();
        findChild(editor(app), "bodyField").text = "Unfinished capture";
        app.receiveShare([
            {
                name: "Shared link",
                data: "https://marathonos.org"
            }
        ]);
        const shared = editor(app);
        compare(app.notes.length, 2);
        compare(app.notes.filter(n => n.content === "Unfinished capture").length, 1);
        compare(findChild(shared, "bodyField").text, "Shared link\nhttps://marathonos.org");
        compare(app.notes.find(n => n.id === shared.noteId).content, "Shared link\nhttps://marathonos.org");
        verify(app.notes[0].id !== app.notes[1].id);
        shared.commit();
        compare(app.notes.length, 2);
    }

    function test_coverNewNoteCommitsPreviousDraftOnce() {
        const app = makeApp([]);
        app.newNote();
        findChild(editor(app), "bodyField").text = "First capture";
        app.newNote();
        const next = editor(app);
        compare(app.notes.length, 1);
        compare(app.notes[0].content, "First capture");
        compare(next.noteId, -1);
        compare(findChild(next, "bodyField").text, "");
        findChild(next, "bodyField").text = "Second capture";
        next.commit();
        compare(app.notes.length, 2);
        compare(new Set(app.notes.map(n => n.id)).size, 2);
    }

    function test_searchAndListScrollSurviveEditingAndReflow() {
        const notes = [];
        for (let id = 1; id <= 60; ++id)
            notes.push(note(id, "Project " + id));
        const app = makeApp(notes);
        const page = collection(app);
        const list = findChild(page, "notesView");
        const search = findChild(page, "searchField");
        search.text = "Project";
        list.positionViewAtIndex(15, ListView.Center);
        const selected = delegateAt(list, 15);
        verify(list.contentY > 0);
        const scroll = list.contentY;
        app.workspace.openNote(selected.modelData.id);
        const opened = editor(app);
        resizeApp(app, 1440);
        compare(app.workspace.collectionPage, page);
        compare(app.workspace.currentEditor, opened);
        compare(search.text, "Project");
        fuzzyCompare(list.contentY, scroll, 1);
        resizeApp(app, 540);
        app.handleBack();
        tryCompare(app.workspace, "currentEditor", null);
        compare(collection(app), page);
        compare(search.text, "Project");
        fuzzyCompare(list.contentY, scroll, 1);
    }

    function test_editorScrollSurvivesReflow() {
        const lines = [];
        for (let i = 0; i < 80; ++i)
            lines.push("Line " + i);
        const app = makeApp([note(1, lines.join("\n"))]);
        app.workspace.openNote(1);
        const opened = editor(app);
        const body = findChild(opened, "bodyField");
        const flickable = findChild(opened, "editorFlickable");
        opened.forceActiveFocus();
        body.select(0, 4);
        verify(flickable.contentHeight > flickable.height + 300);
        flickable.contentY = 300;
        for (const width of [1440, 540]) {
            resizeApp(app, width);
            compare(app.workspace.currentEditor, opened);
            compare(body.selectedText, "Line");
            fuzzyCompare(flickable.contentY, 300, 1);
        }
    }

    function test_wideCollectionNavigationKeepsSelectedDraft() {
        const app = makeApp([note(1, "Shopping\n- [ ] milk\n#home")], 1440);
        app.workspace.openNote(1);
        const opened = editor(app);
        const body = findChild(opened, "bodyField");
        body.text += "\nTake a bag";
        const draft = body.text;
        for (const section of ["tasks", "folders", "notes"]) {
            const button = findChild(app.workspace, section + "Tab");
            const clicked = createTemporaryObject(signalSpy, testCase, {
                target: button,
                signalName: "clicked"
            });
            verify(waitForRendering(button));
            mouseClick(button);
            compare(clicked.count, 1, section + " navigation receives the real click");
            const list = findChild(collection(app), section + "View");
            verify(list, section + " collection opens after a real navigation click; current " + app.workspace.collectionPage + ", depth " + findChild(app.workspace, "collectionStack").depth);
            if (section === "folders") {
                mouseClick(delegateAt(list, 0));
                compare(collection(app).folder, "home");
            }
            compare(app.workspace.currentEditor, opened);
            compare(opened.noteId, 1);
            compare(body.text, draft);
        }
        opened.commit();
        compare(app.notes[0].content, draft);
    }

    function test_wideChecklistToggleKeepsPendingEditorText() {
        const app = makeApp([note(4, "Shopping\n- [ ] milk")], 1440);
        app.workspace.openNote(4);
        const opened = editor(app);
        const body = findChild(opened, "bodyField");
        body.text = "Shopping\nTake a bag\n- [ ] milk";
        mouseClick(findChild(app.workspace, "tasksTab"));
        const list = findChild(collection(app), "tasksView");
        mouseClick(findChild(delegateAt(list, 0), "taskSwitch"));
        const expected = "Shopping\nTake a bag\n- [x] milk";
        tryCompare(body, "text", expected);
        opened.commit();
        compare(app.notes[0].content, expected);
        compare(app.notes.length, 1);
        compare(app.workspace.currentEditor, opened);
    }

    function test_collapsingFocusedCollectionRestoresEditorTyping_data() {
        return [
            {
                tag: "tasks",
                section: "tasks"
            },
            {
                tag: "folders",
                section: "folders"
            }
        ];
    }

    function test_collapsingFocusedCollectionRestoresEditorTyping(data) {
        const app = makeApp([note(1, "Shopping\n- [ ] milk\n#home")], 1440);
        app.workspace.openNote(1);
        const opened = editor(app);
        const body = findChild(opened, "bodyField");
        body.forceActiveFocus();
        body.cursorPosition = body.text.length;
        mouseClick(findChild(app.workspace, data.section + "Tab"));
        const listing = collection(app);
        verify(listing.activeFocus);
        resizeApp(app, 540);
        verify(!listing.visible);
        compare(app.workspace.currentEditor, opened);
        verify(body.activeFocus, "focus moves from the hidden collection back to the visible editor");
        keyClick(Qt.Key_X);
        compare(body.text, "Shopping\n- [ ] milk\n#homex");
    }

    function test_dialogReflowAndBackStayInEditorStack_data() {
        return [
            {
                tag: "compact",
                width: 540
            },
            {
                tag: "wide",
                width: 1440
            }
        ];
    }

    function test_dialogReflowAndBackStayInEditorStack(data) {
        const app = makeApp([note(7, "Call tomorrow", {
                task: {
                    completed: false,
                    dueDate: "2026-12-10"
                }
            })], data.width);
        const minimized = createTemporaryObject(signalSpy, testCase, {
            target: app,
            signalName: "minimizeRequested"
        });
        app.workspace.openNote(7);
        const opened = editor(app);
        const stack = findChild(app.workspace, "editorStack");
        compare(opened.pageContainer, stack);
        mouseClick(findChild(opened, "taskDueDateButton"));
        tryCompare(stack, "depth", 3);
        tryVerify(() => !stack.busy);
        const picker = stack.currentPage;
        compare(picker.pageContainer, stack);
        picker.date = new Date(2027, 0, 15, 12, 0);
        resizeApp(app, data.width === 540 ? 1440 : 540);
        compare(stack.currentPage, picker);
        compare(app.workspace.currentEditor, opened);
        app.handleBack();
        tryCompare(stack, "currentPage", opened);
        tryVerify(() => !stack.busy);
        compare(app.notes[0].task.dueDate, "2026-12-10");
        compare(minimized.count, 0);
        app.handleBack();
        tryCompare(app.workspace, "currentEditor", null);
        tryVerify(() => !stack.busy);
        compare(minimized.count, 0);
        if (!app.workspace.isWide) {
            tryVerify(() => app.workspace.collectionPage.activeFocus);
            verify(testCase.Window.window.activeFocusItem.visible);
        }
        app.handleBack();
        compare(minimized.count, 1);
    }

    function test_editorRemorseDeletesAndReturnsToCollection() {
        const app = makeApp([note(1, "Keep"), note(2, "Delete")], 1440);
        app.workspace.openNote(2);
        const opened = editor(app);
        findChild(opened, "bodyField").text = "Delete with pending text";
        opened.deleteNote();
        compare(app.notes.length, 2);
        tryCompare(app.workspace, "currentEditor", null, 10000);
        compare(app.notes.map(n => n.id), [1]);
        compare(findChild(collection(app), "notesView").count, 1);
    }

    function test_listRemorseDismissesSelectedEditorWithoutResurrectingNote() {
        const app = makeApp([note(1, "Keep"), note(2, "Delete")], 1440);
        app.workspace.openNote(2);
        const opened = editor(app);
        findChild(opened, "bodyField").text = "Pending edit of deleted note";
        const list = findChild(collection(app), "notesView");
        const menu = delegateAt(list, 0).openMenu();
        tryVerify(() => menu._open && menu.height > 0 && !menu._displayHeightAnimating);
        verify(waitForRendering(menu));
        mouseClick(findChild(menu, "deleteItem"));
        compare(app.notes.length, 2);
        tryVerify(() => app.notes.length === 1, 10000);
        tryCompare(app.workspace, "currentEditor", null);
        compare(app.notes.map(n => n.id), [1]);
        compare(findChild(collection(app), "notesView").count, 1);
    }

    function test_largeTextNarrowWindowKeepsNavigationAndEditorReachable() {
        const normalSize = Theme.fontSizeMedium;
        Native.Ambience.applyForwarded("/desktop/jolla/theme/font/sizeCategory='huge'\n");
        verify(Theme.fontSizeMedium > normalSize);
        const app = makeApp([note(1, "A long note that wraps inside a narrow editor")], 360);
        const occupied = [];
        for (const section of ["notes", "tasks", "folders"]) {
            const button = findChild(app.workspace, section + "Tab");
            const origin = button.mapToItem(app.workspace, 0, 0);
            verify(origin.x >= 0 && origin.y >= 0);
            verify(origin.x + button.width <= app.workspace.width);
            verify(origin.y + button.height < app.workspace.height);
            for (const previous of occupied)
                verify(origin.x >= previous.right || origin.x + button.width <= previous.x || origin.y >= previous.bottom || origin.y + button.height <= previous.y);
            const label = findChild(button, "label");
            verify(label.implicitWidth <= label.width + 1, section + " label fits at the chosen text size: " + label.implicitWidth + " needed, " + label.width + " available, button " + button.width);
            occupied.push({
                x: origin.x,
                y: origin.y,
                right: origin.x + button.width,
                bottom: origin.y + button.height
            });
            mouseClick(button);
            verify(findChild(collection(app), section + "View"));
        }
        app.workspace.showNotes();
        app.workspace.openNote(1);
        const opened = editor(app);
        const body = findChild(opened, "bodyField");
        verify(body.width <= opened.width && body.textWidth > 0);
        body.forceActiveFocus();
        body.cursorPosition = body.text.length;
        keyClick(Qt.Key_X);
        verify(body.text.endsWith("editorx"));
        app.handleBack();
        tryCompare(app.workspace, "currentEditor", null);
        compare(app.notes[0].content, "A long note that wraps inside a narrow editorx");
    }
}
