import QtQuick
import QtTest
import Keel.Actions 1.0
import ".."
import "../NotesStore.js" as Store

TestCase {
    name: "NotesActions"

    QtObject {
        id: store
        property var notes: []
        property double nextNoteId: 1
        property string snapshot: "[]"
        function save(next) {
            snapshot = Store.serialize(next, nextNoteId);
            restart();
        }
        function restart() {
            const state = Store.decode(snapshot);
            notes = state.notes;
            nextNoteId = state.nextId;
        }
    }

    NotesActions {
        store: store
    }

    function init() {
        store.nextNoteId = 1;
        store.notes = [
            {
                id: 1,
                title: "Shopping",
                content: "Shopping\nmilk, bread",
                timestamp: 1000
            },
            {
                id: 2,
                title: "Trip",
                content: "Trip\nbook the ferry",
                timestamp: 3000
            },
            {
                id: 3,
                title: "Old",
                content: "ferry times",
                timestamp: 2000,
                pinned: true
            }
        ];
        store.save(store.notes);
    }

    function test_create() {
        const call = KeelActions.invoke("notes.create", {
            title: "Ideas",
            body: "a\nb"
        });
        verify(call.succeeded, call.errorMessage);
        compare(call.result.id, 4);
        compare(store.notes.length, 4);
        compare(store.notes[0].id, 4);
        compare(store.notes[0].title, "Ideas");
        compare(store.notes[0].content, "Ideas\na\nb");
    }

    function test_createWithoutTitle() {
        const call = KeelActions.invoke("notes.create", {
            body: "Call Ann\nabout Friday"
        });
        verify(call.succeeded, call.errorMessage);
        compare(store.notes[0].title, "Call Ann");
        compare(store.notes[0].content, "Call Ann\nabout Friday");
    }

    function test_createNeedsBody() {
        const call = KeelActions.invoke("notes.create", {
            title: "x"
        });
        compare(call.errorCode, "InvalidArguments");
        compare(store.notes.length, 3);
    }

    function test_search() {
        const call = KeelActions.invoke("notes.search", {
            query: "FERRY"
        });
        verify(call.succeeded, call.errorMessage);
        const found = call.result.result;
        compare(found.map(n => n.id), [3, 2]);
        compare(found[1].title, "Trip");
        compare(found[1].body, "Trip\nbook the ferry");
        compare(found[1].modified, "1970-01-01T00:00:03.000Z");
    }

    function test_searchLimitAndEmptyQuery() {
        const call = KeelActions.invoke("notes.search", {
            query: "",
            limit: 2
        });
        verify(call.succeeded, call.errorMessage);
        compare(call.result.result.map(n => n.id), [3, 2]);
    }

    function test_searchTruncatesLongNotes() {
        store.notes = [
            {
                id: 1,
                title: "x".repeat(300),
                content: "x".repeat(5000),
                timestamp: 0
            }
        ];
        const call = KeelActions.invoke("notes.search", {
            query: "x"
        });
        verify(call.succeeded, call.errorMessage);
        compare(call.result.result[0].title.length, 200);
        compare(call.result.result[0].body.length, 2000);
    }

    function test_createTaskCapturesNotificationSnapshot() {
        const source = {
            kind: "notification",
            appId: "org.marathonos.hub",
            itemId: "notification:42:1730000000",
            label: "Messages notification"
        };
        const call = KeelActions.invoke("tasks.create", {
            title: "Reply later",
            source: source
        });
        verify(call.succeeded, call.errorMessage);
        compare(store.notes[0].source, source);
        const listed = KeelActions.invoke("tasks.list", {});
        verify(listed.succeeded, listed.errorMessage);
        compare(listed.result.result[0].source, source);
    }

    function test_createTaskCapturesOpaqueSourceAndDueDate() {
        const source = {
            kind: "message",
            appId: "org.marathonos.messages",
            itemId: "conversation:12/message:4",
            label: "Dinner on Friday"
        };
        const call = KeelActions.invoke("tasks.create", {
            title: "Reply to Ana",
            body: "Confirm the time",
            dueDate: "2028-02-29",
            source: source
        });
        verify(call.succeeded, call.errorMessage);
        compare(call.result.id, 4);
        compare(store.notes[0].content, "Reply to Ana\nConfirm the time");
        compare(store.notes[0].task, {
            completed: false,
            dueDate: "2028-02-29"
        });
        compare(store.notes[0].source, source);
        const listed = KeelActions.invoke("tasks.list", {});
        verify(listed.succeeded, listed.errorMessage);
        compare(listed.result.result, [
            {
                id: 4,
                title: "Reply to Ana",
                completed: false,
                dueDate: "2028-02-29",
                source: source
            }
        ]);
    }

    function test_createTaskRejectsInvalidData_data() {
        return [
            {
                tag: "missing title",
                args: {}
            },
            {
                tag: "blank title",
                args: {
                    title: " \n "
                }
            },
            {
                tag: "long title",
                args: {
                    title: "x".repeat(201)
                }
            },
            {
                tag: "long body",
                args: {
                    title: "T",
                    body: "x".repeat(20001)
                }
            },
            {
                tag: "impossible day",
                args: {
                    title: "T",
                    dueDate: "2026-02-30"
                }
            },
            {
                tag: "timestamp",
                args: {
                    title: "T",
                    dueDate: "2026-11-09T00:00:00Z"
                }
            },
            {
                tag: "incomplete source",
                args: {
                    title: "T",
                    source: {
                        kind: "file"
                    }
                }
            },
            {
                tag: "unknown kind",
                args: {
                    title: "T",
                    source: {
                        kind: "script",
                        appId: "org.marathonos.files",
                        itemId: "1",
                        label: "File"
                    }
                }
            },
            {
                tag: "invalid app",
                args: {
                    title: "T",
                    source: {
                        kind: "file",
                        appId: "file:///tmp/file",
                        itemId: "1",
                        label: "File"
                    }
                }
            },
            {
                tag: "empty id",
                args: {
                    title: "T",
                    source: {
                        kind: "file",
                        appId: "org.marathonos.files",
                        itemId: "",
                        label: "File"
                    }
                }
            },
            {
                tag: "blank label",
                args: {
                    title: "T",
                    source: {
                        kind: "file",
                        appId: "org.marathonos.files",
                        itemId: "1",
                        label: "  "
                    }
                }
            },
            {
                tag: "extra capability",
                args: {
                    title: "T",
                    source: {
                        kind: "file",
                        appId: "org.marathonos.files",
                        itemId: "1",
                        label: "File",
                        grant: "/etc"
                    }
                }
            }
        ];
    }

    function test_createTaskRejectsInvalidData(data) {
        const call = KeelActions.invoke("tasks.create", data.args);
        compare(call.errorCode, "InvalidArguments");
        compare(store.notes.length, 3);
    }

    function test_taskCompletionByIdIsIdempotent() {
        const created = KeelActions.invoke("tasks.create", {
            title: "Call Ana"
        });
        verify(created.succeeded, created.errorMessage);
        const id = created.result.id;
        const completed = KeelActions.invoke("tasks.set_completed", {
            id: id,
            completed: true
        });
        verify(completed.succeeded, completed.errorMessage);
        verify(store.notes[0].task.completed);
        store.notes = JSON.parse(JSON.stringify(store.notes));
        const changedAt = store.notes[0].timestamp;
        const again = KeelActions.invoke("tasks.set_completed", {
            id: id,
            completed: true
        });
        verify(again.succeeded, again.errorMessage);
        compare(store.notes[0].timestamp, changedAt);
        const reopened = KeelActions.invoke("tasks.set_completed", {
            id: id,
            completed: false
        });
        verify(reopened.succeeded, reopened.errorMessage);
        verify(!store.notes[0].task.completed);
        compare(store.notes[0].id, id);
    }

    function test_completionRejectsMissingOrOrdinaryNote_data() {
        return [
            {
                tag: "ordinary note",
                args: {
                    id: 1,
                    completed: true
                }
            },
            {
                tag: "missing note",
                args: {
                    id: 99,
                    completed: true
                }
            },
            {
                tag: "missing state",
                args: {
                    id: 1
                }
            },
            {
                tag: "not a boolean",
                args: {
                    id: 1,
                    completed: "yes"
                }
            }
        ];
    }

    function test_completionRejectsMissingOrOrdinaryNote(data) {
        const before = JSON.stringify(store.notes);
        const call = KeelActions.invoke("tasks.set_completed", data.args);
        compare(call.errorCode, "InvalidArguments");
        compare(JSON.stringify(store.notes), before);
    }

    function test_listTasksFiltersAndLimits() {
        store.notes[0].task = {
            completed: false
        };
        store.notes[1].task = {
            completed: true
        };
        store.notes[2].task = {
            completed: false
        };
        const all = KeelActions.invoke("tasks.list", {});
        verify(all.succeeded, all.errorMessage);
        compare(all.result.result.map(t => t.id), [3, 2, 1]);
        const active = KeelActions.invoke("tasks.list", {
            includeCompleted: false
        });
        verify(active.succeeded, active.errorMessage);
        compare(active.result.result.map(t => t.id), [3, 1]);
        const limited = KeelActions.invoke("tasks.list", {
            limit: 1
        });
        verify(limited.succeeded, limited.errorMessage);
        compare(limited.result.result.map(t => t.id), [3]);
    }

    function test_listTasksDoesNotInventIdsForMarkdownLines() {
        store.notes[0].content = "- [ ] call\n- [x] mail";
        const call = KeelActions.invoke("tasks.list", {});
        verify(call.succeeded, call.errorMessage);
        compare(call.result.result, []);
    }

    function test_deletedTaskCannotBeCompletedAfterRestartAndRecapture() {
        const first = KeelActions.invoke("tasks.create", {
            title: "First"
        });
        verify(first.succeeded, first.errorMessage);
        const retired = first.result.id;
        store.save(Store.remove(store.notes, retired));
        const second = KeelActions.invoke("tasks.create", {
            title: "Second"
        });
        verify(second.succeeded, second.errorMessage);
        verify(second.result.id > retired);
        store.save([]);
        store.restart();
        const third = KeelActions.invoke("tasks.create", {
            title: "After restart"
        });
        verify(third.succeeded, third.errorMessage);
        verify(third.result.id > second.result.id);
        const stale = KeelActions.invoke("tasks.set_completed", {
            id: retired,
            completed: true
        });
        compare(stale.errorCode, "InvalidArguments");
        verify(!store.notes[0].task.completed);
        const removedAgain = KeelActions.invoke("tasks.set_completed", {
            id: second.result.id,
            completed: true
        });
        compare(removedAgain.errorCode, "InvalidArguments");
    }

    function test_ordinaryNotesShareThePersistentSequence() {
        const first = KeelActions.invoke("tasks.create", {
            title: "First"
        });
        verify(first.succeeded, first.errorMessage);
        store.save([]);
        store.restart();
        const note = KeelActions.invoke("notes.create", {
            body: "A note after the task"
        });
        verify(note.succeeded, note.errorMessage);
        verify(note.result.id > first.result.id);
    }

    function test_exhaustedSequenceFailsWithoutSaving() {
        store.nextNoteId = 2147483648;
        const before = JSON.stringify(store.notes);
        for (const action of ["tasks.create", "notes.create"]) {
            const call = KeelActions.invoke(action, {
                title: "No id",
                body: "body"
            });
            compare(call.errorCode, "Failed");
            compare(JSON.stringify(store.notes), before);
        }
    }

    // keel-actions.json is generated by `keel actions`; it must match the
    // declarations.
    function test_manifestMatchesDeclarations() {
        const xhr = new XMLHttpRequest();
        xhr.open("GET", Qt.resolvedUrl("../keel-actions.json"), false);
        xhr.send();
        const manifest = JSON.parse(xhr.responseText);
        compare(manifest.appId, "org.marathonos.notes");
        compare(manifest.context.uri, "keel://org.marathonos.notes/context");
        const live = KeelActions.describe();
        const prefix = live.appId + "/";
        const tools = live.tools.map(t => Object.assign({}, t, {
                name: "org.marathonos.notes/" + t.name.substring(prefix.length)
            }));
        compare(JSON.stringify(tools), JSON.stringify(manifest.tools));
    }
}
