.pragma library

const taskLine = /^(\s*[-*]?\s*\[)([ xX])(\]\s*(.+))$/;

// Legacy stores were a bare array. Version 2 keeps the allocation high-water
// mark in the same saved value, so deleting every note cannot reuse an id.
function decode(json) {
    try {
        const v = JSON.parse(json);
        if (Array.isArray(v))
            return { notes: v, nextId: nextId(v) };
        if (v && v.version === 2 && Array.isArray(v.notes))
            return {
                notes: v.notes,
                nextId: Number.isSafeInteger(v.nextId) && v.nextId >= nextId(v.notes) ? v.nextId : NaN
            };
    } catch (e) {
    }
    // A damaged or newer store must not be overwritten with recycled ids.
    return { notes: [], nextId: NaN };
}

function parse(json) {
    return decode(json).notes;
}

function serialize(notes, minimumId) {
    const id = Math.max(minimumId === undefined ? 1 : minimumId, nextId(notes));
    if (!Number.isSafeInteger(id) || id < 1)
        throw new Error("The saved note identifier sequence is invalid");
    return JSON.stringify({ version: 2, nextId: id, notes: notes });
}

function nextId(notes) {
    return notes.reduce((m, n) => Math.max(m, n.id), 0) + 1;
}

// The first non-blank line names the note.
function titleOf(content) {
    const line = String(content || "").split("\n").find(l => l.trim() !== "");
    return line ? line.trim() : "";
}

// Older notes kept the title apart from the body, and stored "Untitled" for none.
function text(note) {
    const body = String(note.content || "");
    const title = String(note.title || "");
    return title === "" || title === "Untitled" || titleOf(body) === title ? body : title + (body ? "\n" + body : "");
}

// The text after the title line, on one line.
function preview(note) {
    const lines = text(note).split("\n");
    const first = lines.findIndex(l => l.trim() !== "");
    return lines.slice(first + 1).join(" ").replace(/\s+/g, " ").trim();
}

// Today's notes by time; older ones by day and month ("5 Oct"), with the
// year once it is not this one.
function when(timestamp, now) {
    const d = new Date(timestamp);
    if (d.toDateString() === now.toDateString())
        return d.toLocaleTimeString(Qt.locale(), 1); // Locale.ShortFormat; the enum isn't visible here
    return Qt.formatDate(d, d.getFullYear() === now.getFullYear() ? "d MMM" : "d MMM yyyy");
}

function create(notes, content, now, minimumId) {
    const id = Math.max(minimumId === undefined ? 1 : minimumId, nextId(notes));
    if (!Number.isSafeInteger(id) || id < 1 || id > 2147483647)
        throw new Error("No more note identifiers are available");
    const note = { id: id, title: titleOf(content), content: content || "", timestamp: now };
    return [note].concat(notes);
}

function isDueDate(value) {
    if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value))
        return false;
    // Validate the calendar without applying the host's timezone or DST rules.
    const date = new Date(value + "T12:00:00Z");
    return date.getUTCFullYear() === Number(value.slice(0, 4))
        && date.getUTCMonth() + 1 === Number(value.slice(5, 7))
        && date.getUTCDate() === Number(value.slice(8, 10));
}

function createTask(notes, request, now, minimumId) {
    if (request.dueDate !== undefined && !isDueDate(request.dueDate))
        throw new Error("dueDate must be a real date in YYYY-MM-DD form");
    const content = request.title.trim() + (request.body ? "\n" + request.body : "");
    const next = create(notes, content, now, minimumId);
    next[0].task = { completed: false };
    if (request.dueDate !== undefined)
        next[0].task.dueDate = request.dueDate;
    if (request.source !== undefined)
        next[0].source = Object.assign({}, request.source);
    return next;
}

function edit(notes, id, change) {
    if (!notes.some(n => n.id === id))
        return notes;
    return notes.map(n => n.id === id ? Object.assign({}, n, change) : n);
}

function update(notes, id, content, now) {
    return edit(notes, id, { title: titleOf(content), content: content, timestamp: now });
}

function remove(notes, id) {
    return notes.filter(n => n.id !== id);
}

function setPinned(notes, id, pinned) {
    return edit(notes, id, { pinned: pinned });
}

function sorted(notes) {
    return notes.slice().sort((a, b) => (b.pinned === true) - (a.pinned === true) || b.timestamp - a.timestamp);
}

function search(notes, query) {
    const q = (query || "").trim().toLowerCase();
    if (q === "")
        return notes;
    return notes.filter(n => String(n.title).toLowerCase().includes(q) || String(n.content).toLowerCase().includes(q));
}

// An explicit tag wins; otherwise the first #hashtag in the text.
function tagOf(note) {
    if (note.tag)
        return String(note.tag);
    const m = String(note.content || "").match(/(?:^|\s)#([\w-]+)/);
    return m ? m[1] : "";
}

function folders(notes) {
    const counts = {};
    for (const n of notes) {
        const t = tagOf(n);
        counts[t] = (counts[t] || 0) + 1;
    }
    return Object.keys(counts).sort((a, b) => (a === "") - (b === "") || a.localeCompare(b)).map(t => ({ tag: t, count: counts[t] }));
}

function inFolder(notes, tag) {
    return notes.filter(n => tagOf(n) === tag);
}

function makeTask(notes, id, now) {
    const note = notes.find(n => n.id === id);
    return !note || note.task ? notes : edit(notes, id, {
        task: { completed: false },
        timestamp: now
    });
}

function setTaskCompleted(notes, id, completed, now) {
    const note = notes.find(n => n.id === id);
    return !note || !note.task || note.task.completed === completed ? notes : edit(notes, id, {
        task: Object.assign({}, note.task, { completed: completed }),
        timestamp: now
    });
}

function setTaskDueDate(notes, id, dueDate, now) {
    if (dueDate !== "" && !isDueDate(dueDate))
        throw new Error("dueDate must be a real date in YYYY-MM-DD form");
    const note = notes.find(n => n.id === id);
    if (!note || !note.task || (note.task.dueDate || "") === dueDate)
        return notes;
    const task = Object.assign({}, note.task);
    if (dueDate === "")
        delete task.dueDate;
    else
        task.dueDate = dueDate;
    return edit(notes, id, { task: task, timestamp: now });
}

function tasks(notes) {
    const out = [];
    for (const n of notes) {
        if (n.task)
            out.push({
                kind: "task",
                noteId: n.id,
                noteTitle: n.title || "",
                checked: n.task.completed,
                text: titleOf(text(n)),
                dueDate: n.task.dueDate || ""
            });
        const lines = String(n.content || "").split("\n");
        for (let i = 0; i < lines.length; i++) {
            const m = lines[i].match(taskLine);
            if (m)
                out.push({ kind: "checklist", noteId: n.id, noteTitle: n.title || "", line: i, checked: m[2] !== " ", text: m[4].trim() });
        }
    }
    return out;
}

function toggleTask(notes, id, line, now) {
    const note = notes.find(n => n.id === id);
    if (!note)
        return notes;
    const lines = String(note.content || "").split("\n");
    const m = line >= 0 && line < lines.length ? lines[line].match(taskLine) : null;
    if (!m)
        return notes;
    lines[line] = m[1] + (m[2] === " " ? "x" : " ") + m[3];
    return edit(notes, id, { content: lines.join("\n"), timestamp: now });
}

// Appends notes from the pre-Keel store, renumbering ids that clash.
function merge(current, legacy, minimumId) {
    const out = current.slice();
    const taken = new Set(current.map(n => n.id));
    const floor = minimumId === undefined ? 1 : minimumId;
    for (const old of legacy) {
        if (!old || typeof old !== "object")
            continue;
        const note = Object.assign({}, old, {
            title: old.title || "",
            content: old.content ? String(old.content) : "",
            timestamp: Number(old.timestamp) || 0
        });
        if (typeof note.id !== "number" || taken.has(note.id) || note.id < floor)
            note.id = Math.max(floor, nextId(out));
        taken.add(note.id);
        out.push(note);
    }
    return out;
}

// A share's text (Sailfish.Share resources): a link keeps its title above it.
function sharedText(resources) {
    return (resources || []).map(r => {
        const data = String(r.data || "");
        const name = String(r.name || "");
        return data === "" ? "" : name !== "" && name !== data ? name + "\n" + data : data;
    }).filter(t => t !== "").join("\n\n");
}
