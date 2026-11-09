pragma ComponentBehavior: Bound
import QtQuick
import Sailfish.Silica 1.0
import Marathon.Silica 1.0
import "../NotesStore.js" as Store

Page {
    id: root

    property var store
    property string initialSection: ""

    readonly property bool isWide: width >= Theme.itemSizeLarge * 9
    readonly property NoteEditorPage currentEditor: _editor
    readonly property Page collectionPage: collectionStack.currentPage as Page
    readonly property int currentSection: collectionPage instanceof TasksPage ? 1 : collectionPage instanceof FoldersPage || (collectionPage instanceof NotesPage && (collectionPage as NotesPage).inFolder) ? 2 : 0
    property NoteEditorPage _editor: null
    property Page _emptyDetail: null
    property NotesPage _notesPage: null

    objectName: "notesWorkspace"

    onIsWideChanged: {
        if (isWide)
            return;
        for (let focused = root.Window.activeFocusItem; focused; focused = focused.parent) {
            if (currentEditor && focused === collectionPane) {
                if (editorStack.currentPage === currentEditor)
                    currentEditor.focusEditor();
                else
                    editorStack.currentPage.forceActiveFocus();
                break;
            } else if (!currentEditor && focused === editorPane && collectionPage) {
                collectionPage.forceActiveFocus();
                break;
            }
        }
    }

    function commitEditor() {
        return !currentEditor || currentEditor.commit();
    }

    // Changing notes replaces the editor; resizing keeps its native page
    // container, text selection and pending autosave.
    function openNote(noteId) {
        if (!commitEditor())
            return null;
        if (currentEditor && currentEditor.noteId === noteId) {
            editorStack.pop(currentEditor, PageStackAction.Immediate);
            return currentEditor;
        }
        const properties = {
            store: root.store,
            noteId: noteId
        };
        _editor = editorStack.depth > 1 ? editorStack.replaceAbove(_emptyDetail, Qt.resolvedUrl("NoteEditorPage.qml"), properties, PageStackAction.Immediate) : editorStack.push(Qt.resolvedUrl("NoteEditorPage.qml"), properties);
        return currentEditor;
    }

    function newNote(taskRequested = false) {
        if (!commitEditor())
            return null;
        const properties = {
            store: root.store,
            taskRequested: taskRequested
        };
        _editor = editorStack.depth > 1 ? editorStack.replaceAbove(_emptyDetail, Qt.resolvedUrl("NoteEditorPage.qml"), properties, PageStackAction.Immediate) : editorStack.push(Qt.resolvedUrl("NoteEditorPage.qml"), properties);
        return currentEditor;
    }

    function closeEditor() {
        if (!commitEditor())
            return false;
        if (editorStack.depth > 1)
            editorStack.pop(_emptyDetail, PageStackAction.Immediate);
        return true;
    }

    function removeNote(noteId) {
        try {
            store.save(Store.remove(store.notes, noteId));
        } catch (error) {
            Notices.show(qsTr("The note could not be deleted. Try again."));
            return false;
        }
        if (currentEditor && currentEditor.noteId === noteId) {
            currentEditor.discarded = true;
            closeEditor();
        }
        return true;
    }

    function toggleTask(task) {
        if (!commitEditor())
            return;
        const now = Date.now();
        try {
            store.save(task.kind === "task" ? Store.setTaskCompleted(store.notes, task.noteId, !task.checked, now) : Store.toggleTask(store.notes, task.noteId, task.line, now));
        } catch (error) {
            Notices.show(qsTr("The task could not be changed. Try again."));
            return;
        }
        if (task.kind === "checklist" && currentEditor && currentEditor.noteId === task.noteId)
            currentEditor.refreshBodyFromStore();
    }

    function showNotes() {
        if (!isWide && !closeEditor())
            return;
        collectionStack.pop(_notesPage, PageStackAction.Immediate);
        collectionPage.forceActiveFocus();
    }

    function showTasks() {
        if (!isWide && !closeEditor())
            return;
        if (!(collectionPage instanceof TasksPage)) {
            collectionStack.pop(_notesPage, PageStackAction.Immediate);
            collectionStack.push(Qt.resolvedUrl("TasksPage.qml"), {
                store: root.store,
                workspace: root
            }, PageStackAction.Immediate);
        }
        collectionPage.forceActiveFocus();
    }

    function showFolders() {
        if (!isWide && !closeEditor())
            return;
        if (!(collectionPage instanceof FoldersPage)) {
            collectionStack.pop(_notesPage, PageStackAction.Immediate);
            collectionStack.push(Qt.resolvedUrl("FoldersPage.qml"), {
                store: root.store,
                workspace: root
            }, PageStackAction.Immediate);
        }
        collectionPage.forceActiveFocus();
    }

    function openFolder(tag) {
        if (!isWide && !closeEditor())
            return;
        collectionStack.push(Qt.resolvedUrl("NotesPage.qml"), {
            store: root.store,
            workspace: root,
            folder: tag
        });
    }

    function handleBack() {
        if (editorStack.depth > 1) {
            if (editorStack.currentPage === currentEditor && !commitEditor())
                return true;
            editorStack.pop();
            return true;
        }
        if (collectionStack.depth > 1) {
            collectionStack.pop();
            return true;
        }
        return false;
    }

    function showRecovery() {
        const stack = currentEditor ? editorStack : collectionStack;
        stack.push(Qt.resolvedUrl("NotesRecoveryDialog.qml"), {
            store: root.store,
            workspace: root
        });
    }

    Component.onCompleted: {
        _emptyDetail = editorStack.push(emptyDetailComponent, {}, PageStackAction.Immediate);
        _notesPage = collectionStack.push(Qt.resolvedUrl("NotesPage.qml"), {
            store: root.store,
            workspace: root
        }, PageStackAction.Immediate) as NotesPage;
        if (initialSection === "/tasks")
            showTasks();
        else if (initialSection === "/folders")
            showFolders();
        else
            collectionPage.forceActiveFocus();
    }

    TextMetrics {
        id: notesMetrics

        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeMedium
        text: qsTr("Notes")
    }

    TextMetrics {
        id: tasksMetrics

        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeMedium
        text: qsTr("Tasks")
    }

    TextMetrics {
        id: foldersMetrics

        font.family: Theme.fontFamily
        font.pixelSize: Theme.fontSizeMedium
        text: qsTr("Folders")
    }

    Grid {
        id: navigation

        readonly property real minimumButtonWidth: Math.max(notesMetrics.advanceWidth, tasksMetrics.advanceWidth, foldersMetrics.advanceWidth) + Theme.paddingMedium * 2

        z: 1
        anchors {
            top: parent.top
            left: parent.left
            right: parent.right
            margins: Theme.paddingMedium
        }
        columns: width >= minimumButtonWidth * 3 + spacing * 2 ? 3 : 1
        spacing: Theme.paddingSmall

        Button {
            objectName: "notesTab"
            width: (navigation.width - navigation.spacing * (navigation.columns - 1)) / navigation.columns
            text: qsTr("Notes")
            color: root.currentSection === 0 ? Theme.highlightColor : Theme.primaryColor
            border.color: root.currentSection === 0 ? Theme.highlightColor : Theme.rgba(Theme.primaryColor, 0)
            Accessible.selected: root.currentSection === 0
            Accessible.description: root.currentSection === 0 ? qsTr("Current section") : ""
            onClicked: root.showNotes()
        }
        Button {
            objectName: "tasksTab"
            width: (navigation.width - navigation.spacing * (navigation.columns - 1)) / navigation.columns
            text: qsTr("Tasks")
            color: root.currentSection === 1 ? Theme.highlightColor : Theme.primaryColor
            border.color: root.currentSection === 1 ? Theme.highlightColor : Theme.rgba(Theme.primaryColor, 0)
            Accessible.selected: root.currentSection === 1
            Accessible.description: root.currentSection === 1 ? qsTr("Current section") : ""
            onClicked: root.showTasks()
        }
        Button {
            objectName: "foldersTab"
            width: (navigation.width - navigation.spacing * (navigation.columns - 1)) / navigation.columns
            text: qsTr("Folders")
            color: root.currentSection === 2 ? Theme.highlightColor : Theme.primaryColor
            border.color: root.currentSection === 2 ? Theme.highlightColor : Theme.rgba(Theme.primaryColor, 0)
            Accessible.selected: root.currentSection === 2
            Accessible.description: root.currentSection === 2 ? qsTr("Current section") : ""
            onClicked: root.showFolders()
        }
    }

    ValueButton {
        id: recoveryStatus

        objectName: "recoveryStatus"
        anchors.top: navigation.bottom
        width: parent.width
        height: visible ? contentHeight : 0
        visible: root.store.storageProtected || root.store.storageError !== "" || root.store.pendingShares.length > 0
        label: qsTr("Recovery")
        value: root.store.storageProtected ? qsTr("Original data kept") : root.store.pendingShares.length > 0 ? qsTr("Shared text waiting") : qsTr("Action failed")
        onClicked: root.showRecovery()
    }

    Item {
        id: collectionPane

        anchors {
            top: recoveryStatus.bottom
            topMargin: Theme.paddingMedium
            bottom: parent.bottom
            left: parent.left
        }
        width: root.isWide ? Math.max(Theme.itemSizeLarge * 3, Math.min(root.width * 0.4, Theme.itemSizeLarge * 5)) : root.width
        visible: root.isWide || !root.currentEditor
        clip: true

        PageStack {
            id: collectionStack

            objectName: "collectionStack"
            anchors.fill: parent
        }
    }

    Rectangle {
        anchors {
            top: collectionPane.top
            bottom: collectionPane.bottom
            left: collectionPane.right
        }
        width: Theme.pixelRatio
        color: Theme.rgba(Theme.primaryColor, Theme.opacityFaint)
        visible: root.isWide
    }

    Item {
        id: editorPane

        anchors {
            top: collectionPane.top
            bottom: parent.bottom
            right: parent.right
        }
        width: root.isWide ? root.width - collectionPane.width - Theme.pixelRatio : root.width
        visible: root.isWide || !!root.currentEditor
        clip: true

        PageStack {
            id: editorStack

            objectName: "editorStack"
            anchors.fill: parent
            onCurrentPageChanged: {
                if (currentPage === root._emptyDetail)
                    root._editor = null;
            }
        }
    }

    Component {
        id: emptyDetailComponent

        Page {
            onStatusChanged: {
                if (status === PageStatus.Active && !root.isWide && root.collectionPage)
                    root.collectionPage.forceActiveFocus();
            }

            SilicaFlickable {
                id: emptyView

                anchors.fill: parent

                ViewPlaceholder {
                    flickable: emptyView
                    x: emptyView.originX
                    enabled: true
                    text: root.currentSection === 2 ? qsTr("Browse your folders") : qsTr("Choose a note")
                    hintText: root.currentSection === 2 ? qsTr("Choose a folder to browse its notes") : root.currentSection === 1 ? qsTr("Use a task's menu to open its note, or pull down in the list to create a task") : qsTr("Open a note from the list, or pull down in the list to create one")
                }
            }
        }
    }
}
