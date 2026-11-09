pragma ComponentBehavior: Bound
import QtQuick
import Sailfish.Silica 1.0
import Marathon.Silica 1.0
import Marathon.Platform 1.0
import Nemo.Configuration 1.0
import Sailfish.Share 1.0
import "NotesStore.js" as Store
import "pages"
import "cover"

ApplicationWindow {
    id: app

    property var store: ConfigurationValue {
        key: "/apps/notes/data"
        defaultValue: "[]"
    }
    property var imported: ConfigurationValue {
        key: "/apps/notes/legacyImported"
        defaultValue: false
    }
    // The MarathonUI app kept its notes in the shell's settings store.
    property var legacySettings: typeof Settings !== "undefined" ? Settings : null
    property var permissions: typeof Permissions !== "undefined" ? Permissions : null
    readonly property var savedState: Store.decode(store.value)
    readonly property var notes: savedState.notes
    readonly property double nextNoteId: savedState.nextId
    readonly property bool storageProtected: !Number.isSafeInteger(nextNoteId)
    property string storageError: ""
    property var pendingShares: []
    property string route: typeof MARATHON_APP_ROUTE !== "undefined" ? MARATHON_APP_ROUTE : ""
    readonly property NotesWorkspace workspace: pageStack.currentPage as NotesWorkspace

    function save(next) {
        try {
            const value = Store.serialize(next, nextNoteId);
            store.value = value;
            if (store.value !== value)
                throw new Error("Notes did not accept the changed collection");
            storageError = "";
        } catch (error) {
            storageError = qsTr("Changes could not be recorded. Try the action again.");
            throw error;
        }
    }

    function openNote(noteId) {
        const opened = workspace.openNote(noteId);
        if (!opened)
            throw new Error("The current draft could not be recorded");
    }

    // Asking without the storage grant would prompt for it, and without it
    // the old app could not have saved anything.
    function importLegacy() {
        if (storageProtected || imported.value || !legacySettings || !permissions || !permissions.hasPermission(appId, "storage"))
            return;
        try {
            const old = Store.parse(legacySettings.get("notes/data", "[]"));
            if (old.length > 0)
                save(Store.merge(notes, old, nextNoteId));
            imported.value = true;
        } catch (error) {
            storageError = qsTr("Older notes could not be imported. Their original data has been kept.");
        }
    }

    // From the share sheet: a new note, opened.
    function receiveShare(resources) {
        const text = Store.sharedText(resources);
        if (text === "")
            return false;
        pendingShares = pendingShares.concat([text]);
        activate();
        return retryShare();
    }

    function retryShare() {
        if (pendingShares.length === 0)
            return true;
        if (!workspace.commitEditor())
            return false;
        let noteId;
        try {
            const next = Store.create(notes, pendingShares[0], Date.now(), nextNoteId);
            save(next);
            noteId = next[0].id;
            pendingShares = pendingShares.slice(1);
        } catch (error) {
            storageError = qsTr("Shared text could not be recorded. It is available to copy or retry.");
            return false;
        }
        try {
            openNote(noteId);
            return true;
        } catch (error) {
            storageError = qsTr("Shared text was recorded but could not be opened. Choose it from Notes.");
            return false;
        }
    }

    function newNote() {
        workspace.newNote();
    }

    function handleBack() {
        const menu = pageStack.currentPage ? app._openMenu(pageStack.currentPage) : null;
        if (menu) {
            menu.close();
            return true;
        }
        if (workspace && workspace.handleBack())
            return true;
        if (pageStack.depth > 1) {
            pageStack.pop();
            return true;
        }
        minimizeRequested();
        return true;
    }

    appId: "notes"
    onApplicationActiveChanged: {
        if (!applicationActive && workspace)
            workspace.commitEditor();
    }
    Component.onCompleted: {
        importLegacy();
    }

    NotesActions {
        store: app
    }

    ShareProvider {
        method: "text"
        capabilities: ["text/plain", "text/x-url"]
        onTriggered: resources => app.receiveShare(resources)
    }

    cover: Component {
        NotesCover {
            notes: Store.sorted(app.notes)
            onNewNoteRequested: {
                app.activate();
                app.newNote();
            }
        }
    }

    initialPage: Component {
        NotesWorkspace {
            store: app
            initialSection: app.route
        }
    }
}
