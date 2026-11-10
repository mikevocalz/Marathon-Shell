import QtQuick
import QtTest
import Keel 1.0 as Keel
import Sailfish.Silica 1.0
import Marathon.Silica 1.0
import Marathon.Platform 1.0
import ".."
import "../ClockLogic.js" as Logic

TestCase {
    id: testCase

    name: "ClockApp"
    when: windowShown
    visible: true
    width: 540
    height: 1140

    Component {
        id: appComponent
        ClockApp {
            width: 540
            height: 1140
        }
    }

    function initTestCase() {
        Keel.Ambience.applyForwarded("/desktop/sailfish/silica/font_size_multiplier=1");
    }

    function init() {
        Alarms.reset();
        Settings.values = {};
    }

    function cleanup() {
        Keel.Ambience.applyForwarded("/desktop/sailfish/silica/font_size_multiplier=1");
    }

    function cleanupTestCase() {
        Keel.Ambience.applyForwarded("");
    }

    function makeApp() {
        const app = createTemporaryObject(appComponent, testCase);
        tryVerify(() => app.pageStack.currentPage !== null);
        return app;
    }

    function tabsOf(app) {
        const tabs = app.pageStack.currentPage.tabs;
        tryVerify(() => tabs.currentItem !== null && tabs.currentItem.item !== null, 3000);
        return tabs;
    }

    function test_fourTabsAlarmsFirst() {
        const tabs = tabsOf(makeApp());
        compare(tabs.count, 4);
        compare(tabs.model.get(0).title, "Alarms");
        compare(tabs.model.get(1).title, "World");
        compare(tabs.model.get(2).title, "Stopwatch");
        compare(tabs.model.get(3).title, "Timer");
        compare(tabs.currentIndex, 0);
        verify(findChild(tabs, "alarmList") !== null);
    }

    function test_switchTabs() {
        const tabs = tabsOf(makeApp());
        tabs.moveTo(2, PagedView.Immediate);
        tryCompare(tabs, "currentIndex", 2);
        tryVerify(() => findChild(tabs.currentItem, "stopwatchTime") !== null, 3000);
        tabs.moveTo(3, PagedView.Immediate);
        tryCompare(tabs, "currentIndex", 3);
        tryVerify(() => findChild(tabs.currentItem, "timerTime") !== null, 3000);
        tabs.moveTo(1, PagedView.Immediate);
        tryVerify(() => findChild(tabs.currentItem, "cityList") !== null, 3000);
        tryCompare(findChild(tabs.currentItem, "cityList"), "count", 4);
    }

    function test_createAndEditAlarm() {
        const app = makeApp();
        verify(app.saveAlarm("", 6, 45, "", [1, 2]));
        compare(app.alarms.length, 1);
        compare(app.alarms[0].time, "06:45");
        compare(app.alarms[0].label, "Alarm");
        compare(app.alarms[0].repeat, [1, 2]);
        const id = app.alarms[0].id;
        verify(app.saveAlarm(id, 7, 0, "Gym", []));
        compare(app.alarms[0].time, "07:00");
        compare(app.alarms[0].label, "Gym");
    }

    function clearNotices() {
        Notices._queue = [];
        Notices._dismissCurrent();
    }

    function test_savingAnAlarmSaysWhenItRings() {
        const app = makeApp();
        clearNotices();
        verify(app.saveAlarm("", 6, 45, "", []));
        verify(Notices._current !== null);
        verify(Notices._current.text.indexOf("Alarm in ") === 0, Notices._current.text);
        const id = app.alarms[0].id;
        clearNotices();
        app.toggleAlarm(id);
        compare(Notices._current, null);
        app.toggleAlarm(id);
        verify(Notices._current !== null);
        verify(Notices._current.text.indexOf("Alarm in ") === 0);
        clearNotices();
    }

    function test_toggleAndDelete() {
        const app = makeApp();
        app.saveAlarm("", 6, 45, "", []);
        const id = app.alarms[0].id;
        verify(app.toggleAlarm(id));
        verify(!app.alarms[0].enabled);
        verify(app.toggleAlarm(id));
        verify(app.alarms[0].enabled);
        verify(!app.toggleAlarm("missing"));
        app.deleteAlarm(id);
        compare(app.alarms.length, 0);
    }

    function test_longAlarmLabelGrowsWithoutChangingItsIdentity() {
        Keel.Ambience.applyForwarded("/desktop/sailfish/silica/font_size_multiplier=1.5");
        const app = makeApp();
        app.width = 320;
        app.height = 640;
        const label = "<b>Leave early for the appointment across town</b>";
        const id = app.saveAlarm("", 6, 45, label, [1, 2, 3, 4, 5]);
        const tabs = tabsOf(app);
        let row = null;
        tryVerify(() => (row = findChild(tabs.currentItem, "alarmItem")) !== null);
        const summary = findChild(row, "alarmSummary");
        tryVerify(() => summary.lineCount > 1);
        compare(summary.textFormat, Text.PlainText);
        verify(summary.text.indexOf(label) === 0);
        verify(row.contentHeight > Theme.itemSizeLarge);
        verify(summary.mapToItem(row, 0, summary.height).y <= row.contentHeight);
        row.clicked(null);
        compare(app.alarms[0].id, id);
        compare(app.alarms[0].enabled, false);
    }

    function test_backendFailureReported() {
        const app = makeApp();
        Alarms.fail = true;
        verify(!app.saveAlarm("", 6, 45, "", []));
    }

    function test_editAlarmOpensDialog() {
        const app = makeApp();
        app.saveAlarm("", 7, 30, "Gym", [3]);
        app.editAlarm(app.alarms[0]);
        const dialog = app.pageStack.currentPage;
        tryCompare(dialog, "status", PageStatus.Active);
        compare(dialog.alarmId, app.alarms[0].id);
        compare(dialog.hour, 7);
        compare(dialog.minute, 30);
        compare(dialog.label, "Gym");
        compare(dialog.repeat, [3]);
        dialog.hour = 8;
        dialog.accept();
        tryCompare(app.alarms[0], "time", "08:30");
    }

    function test_newAlarmDialogStartsNow() {
        const app = makeApp();
        app.editAlarm(null);
        const dialog = app.pageStack.currentPage;
        compare(dialog.alarmId, "");
        compare(dialog.hour, new Date().getHours());
        compare(dialog.label, "");
    }

    function test_citiesPersist() {
        const app = makeApp();
        compare(app.cities.map(c => c.name), ["New York", "London", "Tokyo", "Sydney"]);
        app.addCity({
            name: "Rome",
            tz: "Europe/Rome",
            offset: 1
        });
        app.addCity({
            name: "Rome",
            tz: "Europe/Rome",
            offset: 1
        });
        compare(app.cities.length, 5);
        app.moveCity(4, 0);
        app.removeCity("London");
        compare(JSON.parse(Settings.get("clock/worldCities", "")).map(c => c.name), ["Rome", "New York", "Tokyo", "Sydney"]);
        compare(createTemporaryObject(appComponent, testCase).cities.length, 4);
    }

    function test_addCityPage() {
        const app = makeApp();
        const page = app.pageStack.push(Qt.resolvedUrl("../pages/AddCityPage.qml"), {
            app: app
        }, PageStackAction.Immediate);
        let list = null;
        tryVerify(() => (list = findChild(page, "addCityList")) !== null);
        const all = list.count;
        verify(all > 20);
        page.query = "ireland";
        verify(list.count >= 1);
        page.query = "dublin";
        compare(list.count, 1);
        compare(findChild(page, "citySearch").text, "dublin");
        let item = null;
        tryVerify(() => (item = findChild(list, "addCityItem")) !== null);
        item.clicked(null);
        compare(app.cities[app.cities.length - 1].name, "Dublin");
        compare(app.cities[app.cities.length - 1].tz, "Europe/Dublin");
        tryVerify(() => app.pageStack.depth === 1);
    }

    function test_longCityNameReflowsWithLargeText() {
        Keel.Ambience.applyForwarded("/desktop/sailfish/silica/font_size_multiplier=1.5");
        const app = makeApp();
        app.width = 320;
        app.height = 640;
        const name = "<b>Long city name shared by a distant family</b>";
        app.cities = [
            {
                name: name,
                tz: "Europe/Dublin"
            }
        ];
        const tabs = tabsOf(app);
        tabs.moveTo(1, PagedView.Immediate);
        let row = null;
        tryVerify(() => (row = findChild(tabs.currentItem, "cityItem")) !== null);
        const title = findChild(row, "cityName");
        const time = findChild(row, "cityTime");
        tryCompare(findChild(row, "cityLayout"), "columns", 1);
        compare(title.text, name);
        compare(title.textFormat, Text.PlainText);
        tryVerify(() => title.lineCount > 1);
        verify(time.mapToItem(row, 0, 0).y >= title.mapToItem(row, 0, title.height).y);
        verify(time.mapToItem(row, 0, time.height).y <= row.contentHeight);
        verify(row.Accessible.name.indexOf(name) === 0);
    }

    function test_addCitySearchTakesKeys() {
        const app = makeApp();
        const page = app.pageStack.push(Qt.resolvedUrl("../pages/AddCityPage.qml"), {
            app: app
        }, PageStackAction.Immediate);
        let field = null;
        tryVerify(() => (field = findChild(page, "citySearch")) !== null && field.visible);
        mouseClick(field);
        keyClick(Qt.Key_R);
        keyClick(Qt.Key_O);
        compare(field.text, "ro");
        verify(field.activeFocus);
    }

    function test_addCitySearchTakesKeysAtOnce() {
        const app = makeApp();
        const page = app.pageStack.push(Qt.resolvedUrl("../pages/AddCityPage.qml"), {
            app: app
        }, PageStackAction.Immediate);
        tryCompare(page, "status", PageStatus.Active);
        keyClick(Qt.Key_R);
        compare(page.query, "r");
    }

    function test_cityTime() {
        const app = makeApp();
        const now = new Date(Date.UTC(2026, 0, 1, 12, 0));
        const local = now.getTimezoneOffset() * 60;
        compare(app.cityTime({
            name: "Dublin",
            tz: "Europe/Dublin"
        }, now).diff, "Local");
        compare(app.cityTime({
            name: "London",
            tz: "Europe/London"
        }, now).diff, Logic.offsetLabel(local));
        const tokyo = app.cityTime({
            name: "Tokyo",
            tz: "Asia/Tokyo"
        }, now);
        compare(tokyo.time, Format.formatDate(new Date(2026, 0, 1, 21, 0), Formatter.TimeValue));
        compare(tokyo.weekday, Qt.locale().dayName(4, Locale.ShortFormat).toUpperCase());
        compare(app.cityTime({
            name: "Gone",
            tz: "Nowhere/Gone"
        }, now).time, "—:—");
        const legacy = app.cityTime({
            name: "Atlantis",
            offset: -3
        }, now);
        compare(legacy.time, Format.formatDate(new Date(2026, 0, 1, 9, 0), Formatter.TimeValue));
        compare(legacy.diff, Logic.offsetLabel(-3 * 3600 + local));
    }

    function test_countdownHoldsBackgroundAndRings() {
        const app = makeApp();
        const held = Lifecycle.held;
        app.countdown.set(1);
        app.countdown.start();
        compare(Lifecycle.held, held + 1);
        tryCompare(Alarms, "triggered", ["Timer"], 3000);
        compare(Lifecycle.held, held);
    }

    function test_runningTimerIsAShellAlarm() {
        const app = makeApp();
        app.setTimer(90);
        app.countdown.start();
        compare(Alarms.hidden.length, 1);
        const alarm = Alarms.hidden[0];
        compare(alarm.label, "Timer");
        verify(alarm.oneShot);
        compare(alarm.at, app.countdown.endsAt);
        verify(alarm.snoozeEnabled === false);
        compare(app.alarms.length, 0);
        compare(Settings.get("clock/timerAlarm", ""), alarm.id);

        app.countdown.pause();
        compare(Alarms.hidden.length, 0);
        app.countdown.start();
        compare(Alarms.hidden.length, 1);
        app.countdown.reset();
        compare(Alarms.hidden.length, 0);
        compare(Settings.get("clock/timerAlarm", "x"), "");
    }

    function test_timerRingsOnceWhenTheShellAlreadyRang() {
        const app = makeApp();
        app.countdown.set(1);
        app.countdown.start();
        Alarms.hidden = [];
        tryVerify(() => !app.countdown.running, 3000);
        compare(Alarms.triggered, []);
    }

    function test_stopwatchAndTimerSurviveRestart() {
        const app = makeApp();
        app.stopwatch.start();
        app.stopwatch.lap();
        app.setTimer(600);
        app.countdown.start();
        const startedAt = app.stopwatch.startedAt;
        const endsAt = app.countdown.endsAt;
        const next = makeApp();
        verify(next.stopwatch.running);
        compare(next.stopwatch.startedAt, startedAt);
        compare(next.stopwatch.laps.length, 1);
        verify(next.countdown.running);
        compare(next.countdown.endsAt, endsAt);
        compare(next.countdown.total, 600);
    }

    function test_timerThatEndedWhileClosedIsReported() {
        clearNotices();
        Settings.set("clock/timer", JSON.stringify({
            endsAt: Date.now() - 60000,
            total: 300,
            remaining: 0
        }));
        const app = makeApp();
        verify(!app.countdown.running);
        compare(app.countdown.remaining, 0);
        verify(Notices._current !== null);
        verify(Notices._current.text.indexOf("Timer finished at ") === 0, Notices._current.text);
        compare(JSON.parse(Settings.get("clock/timer", "")).endsAt, -1);
        clearNotices();
    }

    function test_timerTabControls() {
        const app = makeApp();
        const tabs = tabsOf(app);
        tabs.moveTo(3, PagedView.Immediate);
        let presets = null;
        tryVerify(() => (presets = findChild(tabs.currentItem, "presets")) !== null, 3000);
        const dial = findChild(tabs.currentItem, "timerDial");
        const hint = findChild(tabs.currentItem, "timerHint");
        verify(!dial.enabled);
        compare(hint.text, "Pull down to set a timer");
        presets.itemAt(2).clicked(null);
        verify(app.countdown.running, "a quick timer starts straight away");
        compare(findChild(tabs.currentItem, "timerTime").text, "5:00");
        compare(hint.text, "Tap to pause");
        mouseClick(dial);
        verify(!app.countdown.running);
        compare(hint.text, "Tap to start");
        mouseClick(dial);
        verify(app.countdown.running);
        findChild(tabs.currentItem, "resetTimer").clicked();
        verify(!app.countdown.running);
        compare(app.countdown.remaining, 0);
    }

    function test_timerKeyboardAndNarrowPresets() {
        Keel.Ambience.applyForwarded("/desktop/sailfish/silica/font_size_multiplier=1.5");
        const app = makeApp();
        app.width = 320;
        app.height = 640;
        const tabs = tabsOf(app);
        tabs.moveTo(3, PagedView.Immediate);
        let grid = null;
        tryVerify(() => (grid = findChild(tabs.currentItem, "presetGrid")) !== null);
        tryVerify(() => grid.columns < 3);
        app.setTimer(300);
        const dial = findChild(tabs.currentItem, "timerDial");
        verify(dial.width <= app.width - 2 * Theme.horizontalPageMargin);
        dial.forceActiveFocus();
        keyClick(Qt.Key_Space);
        verify(app.countdown.running);
        compare(Alarms.hidden.length, 1);
        keyClick(Qt.Key_Return);
        verify(!app.countdown.running);
        compare(Alarms.hidden.length, 0);
        compare(app.countdown.total, 300);
    }

    function test_setAnyTimerLength() {
        const app = makeApp();
        const tabs = tabsOf(app);
        tabs.moveTo(3, PagedView.Immediate);
        let item = null;
        tryVerify(() => (item = findChild(tabs.currentItem, "setTimer")) !== null, 3000);
        item.clicked();
        let dialog = null;
        tryVerify(() => (dialog = app.pageStack.currentPage).objectName === "timerDialog", 3000);
        tryCompare(dialog, "status", PageStatus.Active);
        dialog.hour = 1;
        dialog.minute = 30;
        dialog.second = 15;
        compare(dialog.seconds, 5415);
        dialog.accept();
        tryVerify(() => app.pageStack.depth === 1, 3000);
        compare(app.countdown.remaining, 5415);
        compare(app.countdown.total, 5415);
        compare(Settings.get("clock/lastTimer", 0), 5415);
        findChild(tabs.currentItem, "resetTimer").clicked();
        item.clicked();
        tryVerify(() => (dialog = app.pageStack.currentPage).objectName === "timerDialog", 3000);
        compare(dialog.hour, 1);
        compare(dialog.minute, 30);
        compare(dialog.second, 15);
    }

    function test_zeroTimerCannotBeSet() {
        const app = makeApp();
        const dialog = app.pageStack.push(Qt.resolvedUrl("../pages/TimerDialog.qml"), {
            app: app,
            seconds: 0
        }, PageStackAction.Immediate);
        verify(!dialog.canAccept);
        dialog.second = 5;
        verify(dialog.canAccept);
    }

    function test_stopwatchTabControls() {
        const app = makeApp();
        const tabs = tabsOf(app);
        tabs.moveTo(2, PagedView.Immediate);
        let start = null;
        tryVerify(() => (start = findChild(tabs.currentItem, "startLap")) !== null, 3000);
        const pauseReset = findChild(tabs.currentItem, "pauseReset");
        verify(findChild(tabs.currentItem, "stopwatchHint").visible);
        verify(!pauseReset.enabled);
        start.clicked(null);
        verify(app.stopwatch.running);
        verify(!findChild(tabs.currentItem, "stopwatchHint").visible);
        compare(start.Accessible.name, "Lap");
        wait(50);
        start.clicked(null);
        compare(app.stopwatch.laps.length, 1);
        pauseReset.clicked(null);
        verify(!app.stopwatch.running);
        compare(pauseReset.Accessible.name, "Reset");
        pauseReset.clicked(null);
        compare(app.stopwatch.elapsed, 0);
        compare(app.stopwatch.laps.length, 0);
    }

    function test_narrowStopwatchKeepsControlsClearOfElapsedTime() {
        Keel.Ambience.applyForwarded("/desktop/sailfish/silica/font_size_multiplier=1.5");
        const app = makeApp();
        app.width = 320;
        app.height = 640;
        const tabs = tabsOf(app);
        tabs.moveTo(2, PagedView.Immediate);
        let start = null;
        tryVerify(() => (start = findChild(tabs.currentItem, "startLap")) !== null);
        const time = findChild(tabs.currentItem, "stopwatchTime");
        tryVerify(() => start.mapToItem(time, 0, 0).y >= time.height);
        start.clicked(null);
        const started = app.stopwatch.startedAt;
        app.width = 1024;
        app.height = 768;
        verify(app.stopwatch.running);
        compare(app.stopwatch.startedAt, started);
        findChild(tabs.currentItem, "pauseReset").clicked(null);
        verify(!app.stopwatch.running);
    }
}
