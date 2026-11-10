import QtQuick
import QtTest
import Keel 1.0 as Keel
import Sailfish.Silica 1.0
import Marathon.Silica 1.0
import Marathon.Platform 1.0
import "../CalendarLogic.js" as Logic
import ".."

TestCase {
    id: testCase

    name: "CalendarApp"
    when: windowShown
    visible: true
    width: 540
    height: 1140

    Component {
        id: appComponent
        CalendarApp {
            width: 540
            height: 1140
        }
    }

    readonly property string todayKey: Logic.dateKey(new Date())

    function initTestCase() {
        Keel.Ambience.applyForwarded("/desktop/sailfish/silica/font_size_multiplier=1");
    }

    function cleanup() {
        Keel.Ambience.applyForwarded("/desktop/sailfish/silica/font_size_multiplier=1");
    }

    function cleanupTestCase() {
        Keel.Ambience.applyForwarded("");
    }

    function ev(id, extra) {
        return Object.assign({
            id: id,
            title: "Event " + id,
            date: todayKey,
            time: "10:00",
            allDay: false,
            recurring: "none",
            description: ""
        }, extra || {});
    }

    function makeApp(events) {
        Calendar.reset(events);
        const app = createTemporaryObject(appComponent, testCase);
        tryVerify(() => app.pageStack.currentPage !== null && !app.pageStack.busy);
        return app;
    }

    function pushed(app, depth) {
        tryCompare(app.pageStack, "depth", depth);
        tryVerify(() => !app.pageStack.busy);
        return app.pageStack.currentPage;
    }

    function child(item, name) {
        let found = null;
        tryVerify(() => (found = findChild(item, name)) !== null, 3000, name);
        return found;
    }

    function test_accountEventsOpenReadOnlyWithSourceAndSeriesNotice() {
        const remote = ev("dav:account-event", {
            source: "caldav",
            readOnly: true,
            accountLabel: "Personal",
            recurrenceIncomplete: true
        });
        const app = makeApp([ev(1), remote]);
        const detail = app.openEvent(remote);
        tryCompare(detail, "status", PageStatus.Active);
        compare(detail.shown.id, "dav:account-event");
        compare(child(detail, "accountDetail").value, "Personal");
        verify(child(detail, "accountCalendarNotice").text.indexOf("series preview") >= 0);
        verify(!child(detail, "editItem").enabled);
        verify(!child(detail, "deleteItem").enabled);
        verify(!child(detail, "reminderDetail").visible);
        compare(app.editEvent(remote), null);
        verify(!app.saveEvent(remote));
        verify(!app.deleteEvent(remote.id));
        compare(Calendar.events.length, 2);
        compare(app._defaultLabelFormat, Text.PlainText);
    }

    function test_removedAccountEventClearsAnOpenDetailPage() {
        const remote = ev("dav:account-event", {
            source: "caldav",
            readOnly: true,
            title: "Private appointment",
            accountLabel: "Personal",
            description: "Private details"
        });
        const app = makeApp([ev(1), remote]);
        const detail = app.openEvent(remote);
        tryCompare(detail, "status", PageStatus.Active);
        compare(detail.shown.title, "Private appointment");
        Calendar.events = [ev(1)];
        tryCompare(detail, "accountEventUnavailable", true);
        compare(detail.shown, {});
        compare(child(detail, "description").text, "");
        verify(child(detail, "accountEventUnavailableNotice").visible);
        verify(!child(detail, "editItem").enabled);
        verify(!child(detail, "deleteItem").enabled);
        Calendar.events = [ev(1), remote];
        tryCompare(detail, "accountEventUnavailable", false);
        compare(detail.shown.title, "Private appointment");
    }

    function test_accountFailureKeepsLocalEventsAndOffersReload() {
        const app = makeApp([ev(1)]);
        const page = app.pageStack.currentPage;
        Calendar.syncedState = "unavailable";
        verify(child(page, "calendarLoadNotice").visible);
        compare(page.dayEvents.length, 1);
        app.refreshSynced();
        compare(Calendar.refreshCount, 1);
        Calendar.syncedState = "denied";
        verify(child(page, "calendarLoadNotice").text.indexOf("permission") >= 0);
        Calendar.syncedState = "ready";
        verify(!child(page, "calendarLoadNotice").visible);
    }

    function test_monthListsTheDaysEvents() {
        const app = makeApp([ev(1, {
                time: "15:00"
            }), ev(2, {
                allDay: true
            }), ev(3, {
                date: "2001-01-01"
            })]);
        const page = app.pageStack.currentPage;
        compare(page.dayEvents.map(e => e.id), [2, 1]);
        compare(child(page, "dayEvents").count, 2);
        verify(!child(page, "noEvents").visible);
        compare(child(page, "dayHeader").text, "Today");
        compare(child(page, "monthHeader").title, Qt.locale().standaloneMonthName(new Date().getMonth()));
    }

    function test_selectingADay() {
        const app = makeApp([ev(1, {
                date: "2026-03-14"
            })]);
        const page = app.pageStack.currentPage;
        page.showDate(new Date(2026, 2, 14));
        compare(page.dayEvents.length, 1);
        verify(!page.showingToday);
        page.showDate(new Date(2026, 2, 15));
        compare(page.dayEvents.length, 0);
        verify(child(page, "noEvents").visible);
    }

    function test_dayCellsMarkEvents() {
        const app = makeApp([ev(1), ev(2), ev(3), ev(4)]);
        const picker = child(app.pageStack.currentPage, "datePicker");
        let dots = [];
        tryVerify(() => {
            dots = [];
            const walk = item => {
                for (let i = 0; i < item.children.length; ++i) {
                    const c = item.children[i];
                    if (c.objectName === "eventDots" && c.visible)
                        dots.push(c);
                    walk(c);
                }
            };
            walk(picker);
            return dots.length > 0;
        }, 3000);
        const cell = dots[0].parent;
        compare(cell.eventCount, 4);
        compare(dots[0].children.length - 1, 3);
        verify(cell.Accessible.name.indexOf("4 events") !== -1);
    }

    function test_createEvent() {
        const app = makeApp([]);
        const dialog = app.newEvent(new Date(2026, 4, 2));
        tryCompare(dialog, "status", PageStatus.Active);
        verify(!dialog.canAccept);
        dialog.title = "  Dentist ";
        dialog.hour = 9;
        dialog.minute = 15;
        dialog.reminder = 30;
        dialog.recurring = "weekly";
        verify(dialog.canAccept);
        dialog.accept();
        tryCompare(Calendar.events, "length", 1);
        const e = Calendar.events[0];
        compare(e.title, "Dentist");
        compare(e.date, "2026-05-02");
        compare(e.time, "09:15");
        compare(e.reminder, 30);
        compare(e.recurring, "weekly");
        compare(e.allDay, false);
        compare(e.endTime, "10:15");
        compare(e.location, "");
    }

    function test_newEventTitleTakesKeysAtOnce() {
        const app = makeApp([]);
        const dialog = app.newEvent(new Date(2026, 4, 2));
        tryCompare(dialog, "status", PageStatus.Active);
        keyClick(Qt.Key_L);
        compare(dialog.title, "l");
    }

    function test_editedEventTitleIsNotFocused() {
        const app = makeApp([ev(1, {
                title: "Dentist"
            })]);
        const dialog = app.pageStack.push(Qt.resolvedUrl("../pages/EventEditorDialog.qml"), {
            app: app,
            original: ev(1, {
                title: "Dentist"
            }),
            title: "Dentist"
        }, PageStackAction.Immediate);
        tryCompare(dialog, "status", PageStatus.Active);
        verify(!child(dialog, "titleField").activeFocus);
    }

    function test_blockedAcceptFlagsTheTitle() {
        const app = makeApp([]);
        const dialog = app.newEvent(new Date(2026, 4, 2));
        tryCompare(dialog, "status", PageStatus.Active);
        const title = child(dialog, "titleField");
        verify(!title.errorHighlight);
        dialog.acceptBlocked();
        verify(title.errorHighlight);
        dialog.title = "Dentist";
        verify(!title.errorHighlight);
    }

    function test_newEventEndsAnHourLater() {
        const app = makeApp([]);
        const dialog = app.newEvent(new Date(2026, 4, 2));
        tryCompare(dialog, "status", PageStatus.Active);
        compare(Logic.duration(Logic.timeString(dialog.hour, dialog.minute), Logic.timeString(dialog.endHour, dialog.endMinute)), 60);
        verify(child(dialog, "endTimeButton").visible);
        child(dialog, "allDaySwitch").checked = true;
        verify(!child(dialog, "endTimeButton").visible);
    }

    function test_movingStartMovesEnd() {
        const app = makeApp([]);
        const dialog = app.newEvent(new Date(2026, 4, 2));
        tryCompare(dialog, "status", PageStatus.Active);
        dialog.hour = 9;
        dialog.minute = 0;
        dialog.setEnd(10, 30);
        dialog.hour = 14;
        dialog.minute = 15;
        compare(dialog.endHour, 15);
        compare(dialog.endMinute, 45);
        dialog.hour = 23;
        compare(child(dialog, "endTimeButton").value.indexOf("next day") !== -1, true);
    }

    function test_locationAndEndAreSavedAndShown() {
        const app = makeApp([]);
        const dialog = app.newEvent(new Date(2026, 4, 2));
        tryCompare(dialog, "status", PageStatus.Active);
        dialog.title = "Dentist";
        dialog.location = " 12 High St ";
        dialog.hour = 9;
        dialog.minute = 0;
        dialog.setEnd(9, 45);
        dialog.accept();
        tryCompare(Calendar.events, "length", 1);
        const e = Calendar.events[0];
        compare(e.time, "09:00");
        compare(e.endTime, "09:45");
        compare(e.location, "12 High St");
        pushed(app, 1);
        const page = app.openEvent(e);
        pushed(app, 2);
        compare(child(page, "timeDetail").value, app.timeRangeText(e));
        verify(child(page, "timeDetail").value.indexOf(app.timeText(e)) === 0);
        verify(child(page, "locationDetail").visible);
        compare(child(page, "locationDetail").value, "12 High St");
    }

    function test_editEventLoadsEndAndLocation() {
        const app = makeApp([ev(7, {
                time: "07:30",
                endTime: "08:15",
                location: "Gym"
            })]);
        const dialog = app.editEvent(Calendar.events[0]);
        tryCompare(dialog, "status", PageStatus.Active);
        compare(dialog.endHour, 8);
        compare(dialog.endMinute, 15);
        compare(dialog.location, "Gym");
    }

    function test_legacyEventWithoutEndShowsStartOnly() {
        const app = makeApp([ev(4)]);
        compare(app.timeRangeText(Calendar.events[0]), app.timeText(Calendar.events[0]));
        const dialog = app.editEvent(Calendar.events[0]);
        tryCompare(dialog, "status", PageStatus.Active);
        compare(dialog.endHour, 11);
        compare(dialog.endMinute, 0);
    }

    function test_editEventKeepsIdAndFields() {
        const app = makeApp([ev(7, {
                title: "Gym",
                time: "07:30",
                reminder: 15,
                description: "Legs",
                extra: "kept"
            })]);
        const dialog = app.editEvent(Calendar.events[0]);
        tryCompare(dialog, "status", PageStatus.Active);
        compare(dialog.title, "Gym");
        compare(dialog.hour, 7);
        compare(dialog.minute, 30);
        compare(dialog.reminder, 15);
        compare(dialog.description, "Legs");
        compare(child(dialog, "reminderBox").currentIndex, Logic.reminderMinutes.indexOf(15));
        dialog.allDay = true;
        dialog.accept();
        tryCompare(Calendar.events[0], "allDay", true);
        compare(Calendar.events[0].id, 7);
        compare(Calendar.events[0].extra, "kept");
    }

    function test_comboBoxesSetValues() {
        const app = makeApp([]);
        const dialog = app.newEvent(new Date());
        tryCompare(dialog, "status", PageStatus.Active);
        const repeat = child(dialog, "repeatBox");
        compare(repeat.value, "Never");
        repeat.currentIndex = 3;
        compare(dialog.recurring, "monthly");
        compare(repeat.value, "Every month");
        const reminder = child(dialog, "reminderBox");
        compare(reminder.value, "At time of event");
        reminder.currentIndex = 0;
        compare(dialog.reminder, -1);
        verify(child(dialog, "timeButton").visible);
        child(dialog, "allDaySwitch").checked = true;
        verify(!child(dialog, "timeButton").visible);
    }

    function test_saveFailureKeepsEvents() {
        const app = makeApp([ev(1)]);
        Calendar.fail = true;
        verify(!app.saveEvent({
            title: "x",
            date: todayKey
        }));
        verify(!app.saveEvent(ev(1, {
            title: "y"
        })));
        verify(!app.deleteEvent(1));
        compare(Calendar.events.length, 1);
    }

    function test_eventPage() {
        const app = makeApp([ev(4, {
                title: "Review",
                recurring: "daily",
                reminder: 60,
                description: "Bring notes"
            })]);
        const page = app.openEvent(Calendar.events[0]);
        pushed(app, 2);
        compare(child(page, "eventHeader").title, "Review");
        compare(child(page, "timeDetail").value, app.timeRangeText(Calendar.events[0]));
        verify(!child(page, "locationDetail").visible);
        verify(child(page, "repeatDetail").visible);
        compare(child(page, "repeatDetail").value, "Every day");
        compare(child(page, "reminderDetail").value, "1 hour before");
        compare(child(page, "description").text, "Bring notes");
        Calendar.updateEvent(ev(4, {
            title: "Renamed"
        }));
        compare(child(page, "eventHeader").title, "Renamed");
        verify(!child(page, "repeatDetail").visible);
    }

    function test_eventPageDeleteWithRemorse() {
        const app = makeApp([ev(4)]);
        const page = app.openEvent(Calendar.events[0]);
        pushed(app, 2);
        page.remove();
        const remorse = child(page, "remorse");
        verify(remorse.active);
        compare(remorse.text, "Deleted Event 4");
        compare(Calendar.events.length, 1);
        remorse.trigger();
        compare(Calendar.events.length, 0);
        pushed(app, 1);
    }

    function test_eventPageEdit() {
        const app = makeApp([ev(4)]);
        app.openEvent(Calendar.events[0]);
        pushed(app, 2);
        const dialog = app.editEvent(Calendar.events[0]);
        pushed(app, 3);
        dialog.title = "Changed";
        dialog.accept();
        pushed(app, 2);
        compare(child(app.pageStack.currentPage, "eventHeader").title, "Changed");
    }

    function test_yearPagePicksMonth() {
        const app = makeApp([]);
        const month = app.pageStack.currentPage;
        const year = month.openYear();
        pushed(app, 2);
        compare(child(year, "yearHeader").title, String(new Date().getFullYear()));
        compare(child(year, "months").count, 12);
        year.year = 2030;
        year.monthChosen(2030, 6);
        pushed(app, 1);
        compare(month.date.getFullYear(), 2030);
        compare(month.date.getMonth(), 6);
        compare(month.date.getDate(), 1);
    }

    function test_agendaPage() {
        const app = makeApp([ev(1, {
                date: "2026-12-01"
            }), ev(2, {
                date: "2026-01-01"
            }), ev(3, {
                date: "2026-01-01",
                time: "08:00"
            })]);
        const page = app.pageStack.push(Qt.resolvedUrl("../pages/AgendaPage.qml"), {
            app: app
        }, PageStackAction.Immediate);
        compare(page.shown.map(e => e.id), [3, 2, 1]);
        const view = child(page, "agendaView");
        tryCompare(view, "count", 3);
        verify(!child(page, "placeholder").enabled);
        Calendar.reset([]);
        verify(child(page, "placeholder").enabled);
    }

    function test_agendaOpensAtToday() {
        const past = [];
        for (let i = 1; i <= 15; i++)
            past.push(ev(i, {
                date: Logic.dateKey(new Date(2001, 0, i))
            }));
        const app = makeApp(past.concat([ev(99)]));
        const page = app.pageStack.push(Qt.resolvedUrl("../pages/AgendaPage.qml"), {
            app: app
        }, PageStackAction.Immediate);
        const view = child(page, "agendaView");
        tryVerify(() => view.itemAtIndex(15) !== null);
        const today = view.itemAtIndex(15);
        tryVerify(() => view.contentY > view.originY + view.headerItem.height);
        verify(today.y >= view.contentY && today.y + today.height <= view.contentY + view.height);
    }

    function test_monthPulleyHasAtMostFourItems() {
        const app = makeApp([]);
        const page = app.pageStack.currentPage;
        verify(findChild(page, "agendaItem"));
        verify(findChild(page, "yearItem"));
        verify(findChild(page, "todayItem"));
        verify(findChild(page, "newEventItem"));
        verify(!findChild(page, "searchItem"));
    }

    function test_searchFromAllEvents() {
        const app = makeApp([]);
        app.pageStack.push(Qt.resolvedUrl("../pages/AgendaPage.qml"), {
            app: app
        }, PageStackAction.Immediate);
        child(app.pageStack.currentPage, "searchItem").clicked(null);
        compare(pushed(app, 3).objectName, "searchPage");
    }

    function test_searchTakesKeysAtOnce() {
        const app = makeApp([ev(1, {
                title: "Dentist"
            })]);
        const page = app.pageStack.push(Qt.resolvedUrl("../pages/SearchPage.qml"), {
            app: app
        }, PageStackAction.Immediate);
        tryCompare(page, "status", PageStatus.Active);
        keyClick(Qt.Key_D);
        compare(page.query, "d");
    }

    function test_searchPage() {
        const app = makeApp([ev(1, {
                title: "Dentist"
            }), ev(2, {
                title: "Lunch"
            })]);
        const page = app.pageStack.push(Qt.resolvedUrl("../pages/SearchPage.qml"), {
            app: app
        }, PageStackAction.Immediate);
        const view = child(page, "searchView");
        compare(view.count, 0);
        compare(child(page, "placeholder").text, "Search your events");
        page.query = "dent";
        tryCompare(view, "count", 1);
        page.query = "zzz";
        compare(view.count, 0);
        compare(child(page, "placeholder").text, "No matching events");
    }

    function test_eventItemShowsEndAndLocation() {
        const app = makeApp([ev(1, {
                endTime: "11:30",
                location: "Room 4",
                recurring: "weekly"
            })]);
        const item = child(app.pageStack.currentPage, "eventItem");
        compare(item.details, "Every week · Room 4");
        verify(child(item, "endTimeLabel").visible);
        verify(item.Accessible.name.indexOf("Room 4") !== -1);
        verify(item.Accessible.name.indexOf(app.timeRangeText(Calendar.events[0])) !== -1);
    }

    function test_largeTextEventKeepsFullAccountIdentityOnNarrowScreen() {
        Keel.Ambience.applyForwarded("/desktop/sailfish/silica/font_size_multiplier=1.5");
        const remote = ev("dav:long-event", {
            title: "<b>Quarterly planning with the entire research team</b>",
            location: "Conference room on the east side of the building",
            accountLabel: "<i>Shared family calendar</i>",
            readOnly: true,
            endTime: "11:30"
        });
        const app = makeApp([remote]);
        app.width = 320;
        app.height = 640;
        const row = child(app.pageStack.currentPage, "eventItem");
        const layout = child(row, "eventLayout");
        const title = child(row, "eventTitle");
        const details = child(row, "eventDetails");
        tryCompare(layout, "columns", 1);
        tryVerify(() => title.lineCount > 1);
        compare(title.text, remote.title);
        compare(title.textFormat, Text.PlainText);
        compare(details.textFormat, Text.PlainText);
        verify(details.text.indexOf(remote.accountLabel) >= 0);
        verify(details.mapToItem(row, 0, details.height).y <= row.contentHeight);
        compare(row.menu, null);
        app.width = 1024;
        app.height = 768;
        tryCompare(layout, "columns", 2);
        row.clicked(null);
        compare(pushed(app, 2).eventId, remote.id);
    }

    function test_shortMonthScrollsWithoutShrinkingDayTargets() {
        const app = makeApp([]);
        const page = app.pageStack.currentPage;
        page.showDate(new Date(2026, 2, 14));
        app.width = 320;
        app.height = 240;
        const picker = child(page, "datePicker");
        const view = child(page, "monthView");
        tryVerify(() => picker.cellHeight >= Theme.itemSizeSmall);
        verify(picker.cellHeight >= Theme.fontSizeMedium + 2 * Theme.paddingMedium);
        tryVerify(() => view.contentHeight > view.height);
        compare(Logic.dateKey(page.date), "2026-03-14");
        app.width = 1024;
        app.height = 768;
        compare(Logic.dateKey(page.date), "2026-03-14");
    }

    function test_yearReflowsInsteadOfShrinkingLargeText() {
        Keel.Ambience.applyForwarded("/desktop/sailfish/silica/font_size_multiplier=1.5");
        const app = makeApp([]);
        app.width = 320;
        app.height = 640;
        const page = app.pageStack.currentPage.openYear();
        pushed(app, 2);
        const grid = child(page, "yearGrid");
        tryVerify(() => grid.columns < 3);
        const firstMonth = child(page, "months").itemAt(0);
        const days = child(firstMonth, "miniDays").children;
        const day = Array.from(days).find(item => item.text === "28");
        verify(day !== undefined);
        compare(day.font.pixelSize, Theme.fontSizeTiny);
        verify(day.contentWidth <= day.width + 1);
        compare(child(page, "months").count, 12);
    }

    function test_eventItemOpensAndDeletes() {
        const app = makeApp([ev(1)]);
        const item = child(app.pageStack.currentPage, "eventItem");
        item.clicked(null);
        pushed(app, 2);
        compare(app.pageStack.currentPage.eventId, 1);
        app.pageStack.pop(null, PageStackAction.Immediate);
        pushed(app, 1);
    }
}
