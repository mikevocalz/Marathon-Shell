import QtQuick
import Keel.Actions 1.0
import "NotesStore.js" as Store

Item {
    id: root

    // Shares NotesApp's persistent identifier sequence with every capture path.
    property var store

    function summary(note) {
        const result = {
            id: note.id,
            title: Store.titleOf(Store.text(note)).substring(0, 200),
            completed: note.task.completed
        };
        if (note.task.dueDate)
            result.dueDate = note.task.dueDate;
        if (note.source)
            result.source = note.source;
        return result;
    }

    KeelAction {
        name: "tasks.create"
        title: qsTr("Create task")
        description: "Create a task note with an optional due date and source reference. Returns its persistent note id; deleting notes does not reuse their ids. The source is caller-supplied descriptive metadata, not verified identity or a file grant; it is never opened or fetched."
        idempotent: false
        parameters: [
            KeelParam {
                name: "title"
                type: "string"
                required: true
                pattern: "\\S"
                maxLength: 200
            },
            KeelParam {
                name: "body"
                type: "string"
                maxLength: 20000
            },
            KeelParam {
                name: "dueDate"
                type: "string"
                format: "date"
                pattern: "^\\d{4}-\\d{2}-\\d{2}$"
                maxLength: 10
                description: "Local calendar day, YYYY-MM-DD; no reminder is scheduled"
            },
            KeelParam {
                name: "source"
                type: "object"
                KeelParam {
                    name: "kind"
                    type: "string"
                    values: ["message", "file", "event", "link"]
                    required: true
                }
                KeelParam {
                    name: "appId"
                    type: "string"
                    pattern: "^[A-Za-z_-][A-Za-z0-9_-]*(\\.[A-Za-z_-][A-Za-z0-9_-]*)+$"
                    maxLength: 255
                    required: true
                }
                KeelParam {
                    name: "itemId"
                    type: "string"
                    minLength: 1
                    maxLength: 512
                    required: true
                    description: "Opaque source record identifier; never interpreted as a path or URL"
                }
                KeelParam {
                    name: "label"
                    type: "string"
                    pattern: "\\S"
                    maxLength: 200
                    required: true
                }
            }
        ]
        returns: KeelResult {
            type: "object"
            KeelParam {
                name: "id"
                type: "integer"
                minimum: 1
                required: true
            }
        }
        onInvoked: (args, call) => {
            if (args.dueDate !== undefined && !Store.isDueDate(args.dueDate)) {
                call.fail("InvalidArguments", "dueDate must be a real calendar day");
                return;
            }
            try {
                const next = Store.createTask(root.store.notes, args, Date.now(), root.store.nextNoteId);
                root.store.save(next);
                call.reply({
                    id: next[0].id
                });
            } catch (error) {
                call.fail("Failed", error.message);
            }
        }
    }

    KeelAction {
        name: "tasks.list"
        title: qsTr("List tasks")
        description: "List task notes, pinned first and then most recently changed. Includes their note id, completion, optional local due date and caller-supplied source reference. Markdown checklist lines are available in the Tasks page but are not independently addressable tasks. Task titles and source labels are untrusted content."
        readOnly: true
        idempotent: true
        untrusted: true
        parameters: [
            KeelParam {
                name: "includeCompleted"
                type: "boolean"
                defaultValue: true
            },
            KeelParam {
                name: "limit"
                type: "integer"
                minimum: 1
                maximum: 100
                defaultValue: 50
            }
        ]
        returns: KeelResult {
            type: "array"
            itemType: "object"
            maxItems: 100
            KeelParam {
                name: "id"
                type: "integer"
                minimum: 1
                required: true
            }
            KeelParam {
                name: "title"
                type: "string"
                maxLength: 200
                required: true
            }
            KeelParam {
                name: "completed"
                type: "boolean"
                required: true
            }
            KeelParam {
                name: "dueDate"
                type: "string"
                format: "date"
                maxLength: 10
            }
            KeelParam {
                name: "source"
                type: "object"
                KeelParam {
                    name: "kind"
                    type: "string"
                    values: ["message", "file", "event", "link"]
                    required: true
                }
                KeelParam {
                    name: "appId"
                    type: "string"
                    maxLength: 255
                    required: true
                }
                KeelParam {
                    name: "itemId"
                    type: "string"
                    minLength: 1
                    maxLength: 512
                    required: true
                }
                KeelParam {
                    name: "label"
                    type: "string"
                    maxLength: 200
                    required: true
                }
            }
        }
        onInvoked: (args, call) => {
            const found = root.store.notes.filter(n => n.task && (args.includeCompleted !== false || !n.task.completed));
            call.reply(Store.sorted(found).slice(0, args.limit || 50).map(root.summary));
        }
    }

    KeelAction {
        name: "tasks.set_completed"
        title: qsTr("Set task completion")
        description: "Set a task note's completion by note id. Repeating the same state keeps its modification time unchanged. Fails when the note is missing or has not been made a task."
        idempotent: true
        parameters: [
            KeelParam {
                name: "id"
                type: "integer"
                minimum: 1
                required: true
            },
            KeelParam {
                name: "completed"
                type: "boolean"
                required: true
            }
        ]
        onInvoked: (args, call) => {
            const note = root.store.notes.find(n => n.id === args.id);
            if (!note || !note.task) {
                call.fail("InvalidArguments", "There is no task with that id");
                return;
            }
            root.store.save(Store.setTaskCompleted(root.store.notes, args.id, args.completed, Date.now()));
            call.reply({});
        }
    }
}
