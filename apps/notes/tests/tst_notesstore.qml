import QtQuick
import QtTest
import "../NotesStore.js" as Store

TestCase {
    name: "NotesStore"

    function note(id, extra) {
        return Object.assign({
            id: id,
            title: "N" + id,
            content: "",
            timestamp: id
        }, extra || {});
    }

    function test_sharedTextKeepsALinksTitle() {
        compare(Store.sharedText([
            {
                name: "",
                data: "Buy milk"
            }
        ]), "Buy milk");
        compare(Store.sharedText([
            {
                name: "Marathon",
                data: "https://marathonos.org"
            }
        ]), "Marathon\nhttps://marathonos.org");
        compare(Store.sharedText([
            {
                name: "x",
                data: "x"
            },
            {
                name: "",
                data: "y"
            }
        ]), "x\n\ny");
        compare(Store.sharedText([
            {
                name: "photo.png",
                data: "",
                filePath: "/tmp/photo.png"
            }
        ]), "");
    }

    function test_parseBad() {
        compare(Store.parse(""), []);
        compare(Store.parse(undefined), []);
        compare(Store.parse("{oops"), []);
        compare(Store.parse("{\"a\":1}"), []);
    }

    function test_create() {
        const n = Store.create([], "", 1000);
        compare(n.length, 1);
        compare(n[0].id, 1);
        compare(n[0].title, "");
        const m = Store.create(n, "\n  Shopping \nmilk", 2000);
        compare(m[0].id, 2);
        compare(m[0].title, "Shopping");
        compare(m[0].content, "\n  Shopping \nmilk");
    }

    function test_legacyArrayUpgradesWithoutChangingNotesOrIds() {
        const original = [note(9, {
                content: "keep\n- [ ] task",
                pinned: true
            }), note(4)];
        const legacy = Store.decode(JSON.stringify(original));
        compare(legacy.notes, original);
        compare(legacy.nextId, 10);
        const upgraded = JSON.parse(Store.serialize(legacy.notes, legacy.nextId));
        compare(upgraded.version, 2);
        compare(upgraded.nextId, 10);
        compare(upgraded.notes, original);
        compare(Store.parse(JSON.stringify(upgraded)), original);
    }

    function test_deletedIdsAreNotReusedAfterEmptyStoreRestart() {
        let state = Store.decode(JSON.stringify([note(7)]));
        let notes = Store.createTask(state.notes, {
            title: "First task"
        }, 10, state.nextId);
        const deletedId = notes[0].id;
        compare(deletedId, 8);
        state = Store.decode(Store.serialize(notes, state.nextId));
        state = Store.decode(Store.serialize(Store.remove(state.notes, deletedId), state.nextId));
        notes = Store.createTask(state.notes, {
            title: "Second task"
        }, 20, state.nextId);
        compare(notes[0].id, 9);
        state = Store.decode(Store.serialize(notes, state.nextId));
        const emptySnapshot = Store.serialize([], state.nextId);
        state = Store.decode(emptySnapshot);
        compare(state.notes, []);
        compare(state.nextId, 10);
        notes = Store.createTask(state.notes, {
            title: "After restart"
        }, 30, state.nextId);
        compare(notes[0].id, 10);
        compare(Store.setTaskCompleted(notes, deletedId, true, 40), notes);
        verify(!notes[0].task.completed);
    }

    function test_lateLegacyImportCannotReuseRetiredIds() {
        const state = Store.decode(Store.serialize([], 10));
        const merged = Store.merge(state.notes, [note(2, {
                content: "old text"
            }), note(15)], state.nextId);
        compare(merged.map(n => n.id), [10, 15]);
        compare(merged[0].content, "old text");
        compare(Store.decode(Store.serialize(merged, state.nextId)).nextId, 16);
    }

    function test_damagedHighWaterDoesNotOverwriteStoredNotes() {
        for (const nextId of [0, 2, 3.5, "12", null]) {
            const original = [note(7)];
            const state = Store.decode(JSON.stringify({
                version: 2,
                nextId: nextId,
                notes: original
            }));
            compare(state.notes, original);
            verify(Number.isNaN(state.nextId));
            let rejected = false;
            try {
                Store.serialize(state.notes, state.nextId);
            } catch (error) {
                rejected = true;
            }
            verify(rejected);
        }
        verify(Number.isNaN(Store.decode(JSON.stringify({
            version: 3,
            notes: []
        })).nextId));
    }

    function test_identifierExhaustionDoesNotWrap() {
        const notes = Store.create([], "Last id", 10, 2147483647);
        const state = Store.decode(Store.serialize(notes, 2147483647));
        compare(state.nextId, 2147483648);
        const afterDeletion = Store.decode(Store.serialize([], state.nextId));
        let rejected = false;
        try {
            Store.createTask(afterDeletion.notes, {
                title: "No id left"
            }, 20, afterDeletion.nextId);
        } catch (error) {
            rejected = true;
        }
        verify(rejected);
        compare(afterDeletion.notes, []);
    }

    function test_dueDateIsALocalCalendarDay_data() {
        return [
            {
                tag: "leap day",
                date: "2028-02-29",
                valid: true
            },
            {
                tag: "ordinary day",
                date: "2026-11-09",
                valid: true
            },
            {
                tag: "timezone independent",
                date: "2011-12-30",
                valid: true
            },
            {
                tag: "non-leap day",
                date: "2026-02-29",
                valid: false
            },
            {
                tag: "short month",
                date: "2026-04-31",
                valid: false
            },
            {
                tag: "zero month",
                date: "2026-00-10",
                valid: false
            },
            {
                tag: "zero day",
                date: "2026-11-00",
                valid: false
            },
            {
                tag: "timestamp",
                date: "2026-11-09T12:00:00Z",
                valid: false
            },
            {
                tag: "unpadded",
                date: "2026-1-9",
                valid: false
            },
            {
                tag: "empty",
                date: "",
                valid: false
            },
            {
                tag: "null",
                date: null,
                valid: false
            }
        ];
    }

    function test_dueDateIsALocalCalendarDay(data) {
        compare(Store.isDueDate(data.date), data.valid);
    }

    function test_taskCaptureSurvivesEditsAndRestart() {
        const source = {
            kind: "message",
            appId: "org.marathonos.messages",
            itemId: "conversation/42/message/7",
            label: "Lunch with Ana"
        };
        let notes = Store.createTask([note(5)], {
            title: "Reply to Ana",
            body: "Confirm Friday\n- [ ] Check calendar",
            dueDate: "2028-02-29",
            source: source
        }, 100);
        compare(notes[0].id, 6);
        compare(notes[0].task, {
            completed: false,
            dueDate: "2028-02-29"
        });
        compare(notes[0].source, source);
        source.label = "Changed by caller";
        compare(notes[0].source.label, "Lunch with Ana");

        notes = Store.update(notes, 6, "Call Ana instead\nMove this line\n- [ ] Check calendar", 200);
        notes = Store.setTaskCompleted(notes, 6, true, 300);
        notes = Store.parse(JSON.stringify(notes));
        compare(notes[0].id, 6);
        compare(notes[0].content, "Call Ana instead\nMove this line\n- [ ] Check calendar");
        compare(notes[0].source.itemId, "conversation/42/message/7");
        compare(notes[0].task, {
            completed: true,
            dueDate: "2028-02-29"
        });
        const projected = Store.tasks(notes);
        compare(projected.map(t => t.kind), ["task", "checklist"]);
        compare(projected[0].text, "Call Ana instead");
        verify(projected[0].checked);
        verify(!projected[1].checked);
        compare(projected[1].line, 2);
        compare(notes[1], note(5));
    }

    function test_makeTaskPreservesLegacyNoteAndIsIdempotent() {
        const original = note(7, {
            title: "Shopping",
            content: "buy milk\n- [ ] eggs",
            tag: "home",
            pinned: true
        });
        const notes = Store.makeTask([original], 7, 40);
        compare(notes[0], Object.assign({}, original, {
            task: {
                completed: false
            },
            timestamp: 40
        }));
        compare(Store.text(notes[0]), "Shopping\nbuy milk\n- [ ] eggs");
        compare(Store.makeTask(notes, 7, 50), notes);
        compare(Store.makeTask(notes, 99, 50), notes);
        verify(original.task === undefined);
    }

    function test_taskCompletionDoesNotRewriteTextOrChecklist() {
        const notes = Store.makeTask([note(3, {
                content: "x\n- [ ] milk"
            })], 3, 10);
        const completed = Store.setTaskCompleted(notes, 3, true, 20);
        verify(completed[0].task.completed);
        verify(!notes[0].task.completed);
        compare(completed[0].content, notes[0].content);
        compare(completed[0].timestamp, 20);
        compare(Store.setTaskCompleted(completed, 3, true, 30), completed);
        compare(Store.setTaskCompleted(completed, 99, false, 30), completed);
        compare(Store.setTaskCompleted([note(3)], 3, true, 30), [note(3)]);
        const reopened = Store.setTaskCompleted(completed, 3, false, 40);
        verify(!reopened[0].task.completed);
        compare(reopened[0].timestamp, 40);
    }

    function test_setAndClearDueDateKeepSourceAndCompletion() {
        const notes = Store.createTask([], {
            title: "Read document",
            source: {
                kind: "file",
                appId: "org.marathonos.files",
                itemId: "doc:7",
                label: "Agenda"
            }
        }, 10);
        const dated = Store.setTaskDueDate(notes, 1, "2026-12-10", 20);
        compare(dated[0].task.dueDate, "2026-12-10");
        verify(notes[0].task.dueDate === undefined);
        compare(Store.setTaskDueDate(dated, 1, "2026-12-10", 30), dated);
        const cleared = Store.setTaskDueDate(dated, 1, "", 40);
        compare(cleared[0].task, {
            completed: false
        });
        compare(cleared[0].source, notes[0].source);
        compare(cleared[0].timestamp, 40);
        compare(Store.setTaskDueDate(cleared, 1, "", 50), cleared);
        compare(Store.setTaskDueDate(cleared, 99, "", 50), cleared);
    }

    function test_badDueDatesDoNotMutateNotes() {
        const notes = Store.createTask([], {
            title: "Call"
        }, 10);
        let rejected = false;
        try {
            Store.setTaskDueDate(notes, 1, "2026-02-30", 20);
        } catch (e) {
            rejected = true;
        }
        verify(rejected);
        compare(notes[0].task, {
            completed: false
        });
        compare(notes[0].timestamp, 10);
        rejected = false;
        try {
            Store.createTask(notes, {
                title: "Invalid",
                dueDate: "2026-02-30"
            }, 20);
        } catch (e) {
            rejected = true;
        }
        verify(rejected);
        compare(notes.length, 1);
    }

    function test_legacyImportDoesNotDiscardTaskMetadata() {
        const captured = Store.createTask([], {
            title: "Meeting follow-up",
            source: {
                kind: "event",
                appId: "org.marathonos.calendar",
                itemId: "event:12",
                label: "Friday meeting"
            }
        }, 10);
        const merged = Store.merge(captured, [note(1), note(4)]);
        compare(merged[0], captured[0]);
        compare(merged.map(n => n.id), [1, 2, 4]);
        compare(Store.parse(JSON.stringify(merged)), merged);
    }

    function test_updateKeepsPinAndTag() {
        const n = Store.update([note(1, {
                pinned: true,
                tag: "work"
            })], 1, "x\ny", 5);
        compare(n[0].title, "x");
        compare(n[0].content, "x\ny");
        compare(n[0].timestamp, 5);
        verify(n[0].pinned);
        compare(n[0].tag, "work");
    }

    function test_updateMissingIsNoop() {
        const n = [note(1)];
        compare(Store.update(n, 99, "z", 6), n);
    }

    function test_textJoinsSeparateLegacyTitle() {
        compare(Store.text(note(1, {
            title: "Shop",
            content: "milk"
        })), "Shop\nmilk");
        compare(Store.text(note(1, {
            title: "Shop",
            content: "Shop\nmilk"
        })), "Shop\nmilk");
        compare(Store.text(note(1, {
            title: "Untitled",
            content: "milk"
        })), "milk");
        compare(Store.text(note(1, {
            title: "",
            content: "milk"
        })), "milk");
        compare(Store.text(note(1, {
            title: "Shop",
            content: ""
        })), "Shop");
    }

    function test_previewSkipsTitleLine() {
        compare(Store.preview(note(1, {
            title: "Shop",
            content: "Shop\nmilk\n  eggs"
        })), "milk eggs");
        compare(Store.preview(note(1, {
            title: "Shop",
            content: "milk"
        })), "milk");
        compare(Store.preview(note(1, {
            title: "",
            content: "only"
        })), "");
    }

    function test_whenTodayIsATime() {
        const now = new Date(2026, 9, 12, 18, 0);
        verify(Store.when(new Date(2026, 9, 12, 9, 5).getTime(), now).indexOf("9") >= 0);
        compare(Store.when(new Date(2026, 9, 5, 9, 5).getTime(), now), "5 Oct");
        compare(Store.when(new Date(2025, 8, 7).getTime(), now), "7 Sep 2025");
    }

    function test_remove() {
        compare(Store.remove([note(1), note(2)], 1).map(n => n.id), [2]);
    }

    function test_setPinnedKeepsTimestamp() {
        const n = Store.setPinned([note(1)], 1, true);
        verify(n[0].pinned);
        compare(n[0].timestamp, 1);
        verify(!Store.setPinned(n, 1, false)[0].pinned);
    }

    function test_sortedPinnedFirstThenNewest() {
        const s = Store.sorted([note(1), note(3), note(2, {
                pinned: true
            })]);
        compare(s.map(n => n.id), [2, 3, 1]);
    }

    function test_searchTitleAndContent() {
        const all = [note(1, {
                title: "Groceries"
            }), note(2, {
                content: "buy MILK"
            }), note(3)];
        compare(Store.search(all, "").length, 3);
        compare(Store.search(all, "groc").map(n => n.id), [1]);
        compare(Store.search(all, "milk").map(n => n.id), [2]);
        compare(Store.search(all, "zzz").length, 0);
    }

    function test_tagFromFieldOrHashtag() {
        compare(Store.tagOf(note(1, {
            tag: "work"
        })), "work");
        compare(Store.tagOf(note(1, {
            content: "call bob #home soon #later"
        })), "home");
        compare(Store.tagOf(note(1, {
            content: "issue#12 is not a tag"
        })), "");
        compare(Store.tagOf(note(1)), "");
    }

    function test_foldersUntaggedLast() {
        const f = Store.folders([note(1, {
                tag: "work"
            }), note(2), note(3, {
                content: "#home"
            }), note(4, {
                tag: "work"
            })]);
        compare(f, [
            {
                tag: "home",
                count: 1
            },
            {
                tag: "work",
                count: 2
            },
            {
                tag: "",
                count: 1
            }
        ]);
        compare(Store.inFolder([note(1, {
                tag: "work"
            }), note(2)], "work").map(n => n.id), [1]);
        compare(Store.inFolder([note(1, {
                tag: "work"
            }), note(2)], "").map(n => n.id), [2]);
    }

    function test_tasks() {
        const t = Store.tasks([note(7, {
                content: "intro\n- [ ] milk\n- [x] eggs\n[X] bread"
            })]);
        compare(t.length, 3);
        compare(t[0], {
            kind: "checklist",
            noteId: 7,
            noteTitle: "N7",
            line: 1,
            checked: false,
            text: "milk"
        });
        verify(t[1].checked);
        verify(t[2].checked);
        compare(t[2].line, 3);
    }

    function test_toggleTask() {
        const n = Store.toggleTask([note(7, {
                content: "a\n- [ ] milk"
            })], 7, 1, 9);
        compare(n[0].content, "a\n- [x] milk");
        compare(n[0].timestamp, 9);
        compare(Store.toggleTask(n, 7, 1, 10)[0].content, "a\n- [ ] milk");
        compare(Store.toggleTask(n, 7, 0, 10), n);
        compare(Store.toggleTask(n, 99, 1, 10), n);
    }

    function test_mergeIntoEmptyKeepsIds() {
        const m = Store.merge([], [note(4, {
                pinned: true,
                tag: "x"
            }), note(9)]);
        compare(m.map(n => n.id), [4, 9]);
        verify(m[0].pinned);
        compare(m[0].tag, "x");
    }

    function test_mergeRenumbersClashes() {
        const m = Store.merge([note(1), note(2)], [note(2), note(5)]);
        compare(m.map(n => n.id), [1, 2, 3, 5]);
    }

    function test_mergeNormalisesLegacyNotes() {
        const m = Store.merge([], [
            {
                id: 1,
                title: "",
                content: null,
                timestamp: 3
            },
            "junk",
            {
                title: "no id"
            }
        ]);
        compare(m.length, 2);
        compare(m[0].title, "");
        compare(m[0].content, "");
        compare(m[1].id, 2);
        compare(typeof m[1].timestamp, "number");
    }
}
