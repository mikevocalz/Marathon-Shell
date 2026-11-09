import QtQuick
import QtQuick.Window
import QtTest
import Keel 1.0 as Keel
import MarathonOS.Shell
import Sailfish.Silica 1.0 as Silica
import "../../shell/qml/components"

TestCase {
    id: tc

    name: "Hub"
    when: windowShown

    readonly property var hub: hubLoader.item

    Window {
        id: hubWindow

        width: 540
        height: 1140
        visible: true

        Loader {
            id: hubLoader

            anchors.fill: parent
            active: false
            sourceComponent: MarathonHub {}
        }
    }

    SignalSpy {
        id: closedSpy

        target: tc.hub
        signalName: "closed"
    }

    function initTestCase() {
        // Construct the real ambience before Theme attaches to it, so native
        // text-size changes reach the labels instead of testing fallback sizes.
        Keel.Ambience.applyForwarded("/desktop/sailfish/silica/font_size_multiplier=1");
        hubLoader.active = true;
        tryVerify(() => hub !== null);
    }

    function cleanupTestCase() {
        hubLoader.active = false;
        Keel.Ambience.applyForwarded("");
    }

    function init() {
        hubWindow.width = 540;
        SettingsManagerCpp.timeFormat = "12h";
        SettingsManagerCpp.store = {};
        hub.refreshAgenda();
        Keel.Ambience.applyForwarded("/desktop/sailfish/silica/font_size_multiplier=1");
        NotificationService.clear();
        NotificationService.read = [];
        NotificationService.clicked = [];
        NotificationService.dismissed = [];
        NotificationService.dismissedAll = false;
        NotificationService.triggered = [];
        NotificationService.replies = [];
        NotificationService.sourceNames = {};
        AppModel.names = {};
        NavigationRouter.deepLinks = [];
        closedSpy.clear();
        hub.isInPeekMode = false;
        hub.filterApp = "";
        hub.unreadOnly = false;
        hub.refreshSources();
    }

    // Every role the delegate reads, since a ListView sees only the roles
    // its first row had.
    function addNotification(id, appId, icon) {
        NotificationService.append({
            id: id,
            appId: appId,
            title: "Ada",
            body: "Hi",
            icon: icon || "",
            timestamp: Date.now(),
            isRead: false,
            ongoing: false,
            progress: -1,
            day: isoDay(0)
        });
        hub.refreshSources();
    }

    function isoDay(daysAgo) {
        const d = new Date();
        d.setDate(d.getDate() - daysAgo);
        return Qt.formatDate(d, "yyyy-MM-dd");
    }

    function test_dayLabels() {
        compare(hub.dayLabel(isoDay(0)), "Today");
        compare(hub.dayLabel(isoDay(1)), "Yesterday");
        const three = new Date();
        three.setDate(three.getDate() - 3);
        compare(hub.dayLabel(isoDay(3)), Qt.locale().dayName(three.getDay(), Locale.LongFormat));
        const ten = new Date();
        ten.setDate(ten.getDate() - 10);
        compare(hub.dayLabel(isoDay(10)), Qt.formatDate(ten, "d MMMM"));
    }

    function test_agendaTextRemainsReadable_data() {
        return [
            {
                tag: "12h-phone",
                width: 540,
                format: "12h",
                allDay: false,
                textScale: 1
            },
            {
                tag: "12h-narrow",
                width: 320,
                format: "12h",
                allDay: false,
                textScale: 1
            },
            {
                tag: "12h-wide",
                width: 1000,
                format: "12h",
                allDay: false,
                textScale: 1
            },
            {
                tag: "24h-phone",
                width: 540,
                format: "24h",
                allDay: false,
                textScale: 1
            },
            {
                tag: "24h-narrow",
                width: 320,
                format: "24h",
                allDay: false,
                textScale: 1
            },
            {
                tag: "all-day-phone",
                width: 540,
                format: "12h",
                allDay: true,
                textScale: 1
            },
            {
                tag: "all-day-narrow",
                width: 320,
                format: "24h",
                allDay: true,
                textScale: 1
            },
            {
                tag: "12h-large",
                width: 540,
                format: "12h",
                allDay: false,
                textScale: 1.5
            },
            {
                tag: "24h-narrow-large",
                width: 320,
                format: "24h",
                allDay: false,
                textScale: 1.5
            },
            {
                tag: "all-day-narrow-large",
                width: 320,
                format: "12h",
                allDay: true,
                textScale: 1.5
            }
        ];
    }

    function verifyAgendaReadable(entry) {
        const time = findChild(entry, "hubAgendaTime");
        const title = findChild(entry, "hubAgendaTitle");
        verify(time.visible && title.visible);
        for (const label of [time, title]) {
            verify(label.width > 0 && label.height > 0);
            verify(!label.truncated, "Agenda text must remain readable: " + label.text);
            verify(label.contentWidth <= Math.ceil(label.width), "Agenda text exceeds its label: " + label.text);
            const rect = label.mapToItem(entry, 0, 0, label.width, label.height);
            verify(rect.x >= 0 && rect.y >= 0);
            verify(rect.x + rect.width <= entry.width + 0.5);
            verify(rect.y + rect.height <= entry.height + 0.5);
        }
        const a = time.mapToItem(entry, 0, 0, time.contentWidth, time.contentHeight);
        const b = title.mapToItem(entry, 0, 0, title.contentWidth, title.contentHeight);
        verify(a.x + a.width < b.x || b.x + b.width < a.x || a.y + a.height < b.y || b.y + b.height < a.y, "The agenda time and title need separate readable bounds");
    }

    function test_agendaTextRemainsReadable(data) {
        const normalSize = Silica.Theme.fontSizeMedium;
        hubWindow.width = data.width;
        SettingsManagerCpp.timeFormat = data.format;
        Keel.Ambience.applyForwarded("/desktop/sailfish/silica/font_size_multiplier=" + data.textScale);
        if (data.textScale > 1)
            tryVerify(() => Silica.Theme.fontSizeMedium > normalSize);
        SettingsManagerCpp.set("calendar/events", [
            {
                title: "Coffee with Maya",
                time: "11:30",
                date: isoDay(0),
                allDay: data.allDay
            }
        ]);
        hub.refreshAgenda();
        tryVerify(() => findChild(hub, "hubAgendaEntry") !== null);
        const entry = findChild(hub, "hubAgendaEntry");
        compare(findChild(entry, "hubAgendaTime").text, data.allDay ? "All day" : data.format === "12h" ? "11:30 AM" : "11:30");
        compare(findChild(entry, "hubAgendaTitle").text, "Coffee with Maya");
        waitForPolish(findChild(hub, "hubList"));
        waitForRendering(hub);
        verifyAgendaReadable(entry);
    }

    function test_agendaReflowsWhileVisible() {
        SettingsManagerCpp.set("calendar/events", [
            {
                title: "Coffee with Maya",
                time: "11:30",
                date: isoDay(0),
                allDay: false
            },
            {
                title: "Weekend trip planning",
                time: "18:00",
                date: isoDay(0),
                allDay: false
            }
        ]);
        hub.refreshAgenda();
        const entries = findChild(hub, "hubAgendaEntries");
        tryCompare(entries, "count", 2);
        const first = entries.itemAt(0);
        const second = entries.itemAt(1);
        for (const state of [
            {
                width: 1000,
                format: "24h",
                scale: 1,
                expected: "11:30"
            },
            {
                width: 540,
                format: "12h",
                scale: 1,
                expected: "11:30 AM"
            },
            {
                width: 320,
                format: "12h",
                scale: 1.5,
                expected: "11:30 AM"
            },
            {
                width: 1000,
                format: "24h",
                scale: 1,
                expected: "11:30"
            }
        ]) {
            hubWindow.width = state.width;
            SettingsManagerCpp.timeFormat = state.format;
            Keel.Ambience.applyForwarded("/desktop/sailfish/silica/font_size_multiplier=" + state.scale);
            tryCompare(findChild(first, "hubAgendaTime"), "text", state.expected);
            waitForPolish(findChild(hub, "hubList"));
            waitForRendering(hub);
            verifyAgendaReadable(first);
            verifyAgendaReadable(second);
            const a = first.mapToItem(hub, 0, 0, first.width, first.height);
            const b = second.mapToItem(hub, 0, 0, second.width, second.height);
            verify(a.y + a.height < b.y, "Resized agenda entries must not overlap");
        }
    }

    function test_unreadFilterAvailableWithSingleSource() {
        const filters = findChild(hub, "hubFilters");
        verify(!filters.visible);
        addNotification(1, "mail");
        addNotification(2, "mail");
        verify(filters.visible);
        addNotification(3, "messages");
        compare(hub.sources.map(s => s.app), ["mail", "messages"]);
        compare(hub.sources[0].unread, 2);
    }

    function test_filterNarrowsToOneApp() {
        addNotification(1, "mail");
        addNotification(2, "messages");
        addNotification(3, "mail");
        const list = findChild(hub, "hubList");
        compare(list.count, 3);
        hub.filterApp = "mail";
        tryCompare(list, "count", 2);
        hub.filterApp = "";
        tryCompare(list, "count", 3);
    }

    function test_unreadFilterCombinesWithSource() {
        addNotification(1, "mail");
        addNotification(2, "messages");
        addNotification(3, "mail");
        const list = findChild(hub, "hubList");
        compare(list.count, 3);

        NotificationService.setProperty(0, "isRead", true);
        hub.unreadOnly = true;
        tryCompare(list, "count", 2);
        hub.filterApp = "mail";
        tryCompare(list, "count", 1);
        hub.unreadOnly = false;
        tryCompare(list, "count", 2);
    }

    function test_unreadBadgeUpdatesWhenMarkedRead() {
        addNotification(1, "mail");
        addNotification(2, "mail");
        NotificationService.setProperty(0, "isRead", true);
        tryVerify(() => hub.sources.length === 1 && hub.sources[0].unread === 1);
    }

    function test_unreadFilterTracksReadChangesAndEmptyState() {
        const list = findChild(hub, "hubList");
        const empty = findChild(hub, "hubEmptyState");
        compare(empty.text, "Nothing new");
        addNotification(1, "mail");
        addNotification(2, "messages");
        hub.filterApp = "mail";
        hub.unreadOnly = true;
        tryCompare(list, "count", 1);

        NotificationService.setProperty(0, "isRead", true);
        tryCompare(list, "count", 0);
        tryVerify(() => hub.sources[0].unread === 0);
        compare(hub.filterApp, "mail");
        tryCompare(empty, "visible", true);
        compare(empty.text, "No unread notifications");

        hub.unreadOnly = false;
        tryCompare(list, "count", 1);
        tryCompare(empty, "visible", false);
        hub.unreadOnly = true;
        NotificationService.setProperty(0, "isRead", false);
        tryCompare(list, "count", 1);
        tryVerify(() => hub.sources[0].unread === 1);
        tryCompare(empty, "visible", false);
    }

    function test_sourceRemovalRetainsUnreadFilter() {
        addNotification(1, "mail");
        addNotification(2, "messages");
        hub.filterApp = "messages";
        hub.unreadOnly = true;
        NotificationService.remove(1);
        tryCompare(hub, "filterApp", "");
        compare(hub.unreadOnly, true);
        tryCompare(findChild(hub, "hubList"), "count", 1);
    }

    function test_unreadChipTogglesWithoutChangingSource() {
        addNotification(1, "mail");
        addNotification(2, "messages");
        const unread = findChild(hub, "hubUnreadFilter");
        verify(unread.visible);
        hub.filterApp = "mail";
        waitForPolish(findChild(hub, "hubList").headerItem);
        tryVerify(() => unread.mapToItem(hub, 0, 0).y >= Constants.statusBarHeight);
        mouseClick(unread);
        compare(hub.unreadOnly, true);
        compare(hub.filterApp, "mail");
        mouseClick(unread);
        compare(hub.unreadOnly, false);
        compare(hub.filterApp, "mail");
    }

    function test_filterClearsWhenItsAppIsGone() {
        addNotification(1, "mail");
        addNotification(2, "messages");
        hub.filterApp = "messages";
        NotificationService.remove(1);
        hub.refreshSources();
        compare(hub.filterApp, "");
    }

    readonly property string redPixels: "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAAQAAAAECAYAAACp8Z5+AAAAEklEQVR4nGP4z8DwHxkzkC4AADxAH+HggXe0AAAAAElFTkSuQmCC"

    function row(i) {
        const list = findChild(hub, "hubList");
        list.forceLayout();
        // Header changes also queue a new scroll origin; sample input targets
        // only after the native layout and scene have caught up.
        waitForPolish(list);
        waitForRendering(hub);
        return list.itemAtIndex(i);
    }

    // clickNotification opens the app; the Hub must not too.
    function test_tapClicksTheNotificationOnce() {
        addNotification(42, "messages");
        tryVerify(() => row(0));
        mouseClick(row(0));
        compare(NotificationService.clicked, [42]);
        compare(NotificationService.read, [42]);
        compare(NavigationRouter.deepLinks.length, 0);
    }

    function test_tapInPeekClosesIt() {
        hub.isInPeekMode = true;
        addNotification(-3, "phone");
        tryVerify(() => row(0));
        mouseClick(row(0));
        compare(NotificationService.clicked, [-3]);
        compare(closedSpy.count, 1);
    }

    function test_tapWithoutAppMarksRead() {
        addNotification(7, "");
        tryVerify(() => row(0));
        mouseClick(row(0));
        compare(NotificationService.read, [7]);
        compare(NavigationRouter.deepLinks.length, 0);
    }

    function swipe(item, fraction) {
        const y = item.height / 2;
        mousePress(item, 2, y);
        for (let i = 1; i <= 10; i++)
            mouseMove(item, 2 + item.width * fraction * i / 10, y);
        mouseRelease(item, 2 + item.width * fraction, y);
    }

    // Initials are letters: an emoji, a flag or a ZWJ sequence is skipped
    // whole, never cut into half a surrogate pair.
    function test_monogramSkipsEmoji() {
        compare(hub.monogramFor("Ada Lovelace", "x"), "AL");
        compare(hub.monogramFor("ada", "x"), "AD");
        compare(hub.monogramFor("😀🚀🇮🇪❤️", "x"), "·");
        compare(hub.monogramFor("🇮🇪 Seán Ó Dálaigh", "x"), "SD");
        compare(hub.monogramFor("😀Ann", "x"), "AN");
        compare(hub.monogramFor("Ann 🚀", "x"), "AN");
        compare(hub.monogramFor("👨‍👩‍👧 Family", "x"), "FA");
        compare(hub.monogramFor("❤️ Émile", "x"), "ÉM");
    }

    function test_accountIsTheSendersAppName() {
        AppModel.names = {
            "email": "Mail"
        };
        addNotification(1, "email");
        addNotification(2, "signal");
        tryVerify(() => row(1));
        compare(row(0).account, "Mail");
        compare(row(1).account, "Signal");
    }

    function test_historyUsesReadableNamesWithoutInstalledApps() {
        addNotification(1, "deckard.com.nononsenseapps.feeder");
        addNotification(2, "org.kde.itinerary");
        tryVerify(() => row(1));
        compare(row(0).account, "Feeder");
        compare(row(1).account, "Itinerary");
        compare(hub.sources.map(s => s.label), ["Feeder", "Itinerary"]);
    }

    function test_androidAndDesktopAliasesUseRegistryNames() {
        AppModel.names = {
            "deckard.com.zhiliaoapp.musically": "TikTok",
            "org.gnome.Maps": "Maps"
        };
        compare(hub.sourceLabel("com.zhiliaoapp.musically", ""), "TikTok");
        compare(hub.sourceLabel("waydroid.com.zhiliaoapp.musically", ""), "TikTok");
        compare(hub.sourceLabel("org.gnome.Maps.desktop", ""), "Maps");
    }

    function test_senderDisplayNameSurvivesAppRemoval() {
        NotificationService.sourceNames = {
            "org.example.client": "Pocket Reader"
        };
        addNotification(1, "org.example.client");
        tryVerify(() => row(0));
        compare(row(0).account, "Pocket Reader");
    }

    function test_registryReloadUpdatesNamesWithoutCountChange() {
        AppModel.names = {
            "org.example.other": "Other"
        };
        addNotification(1, "org.example.client");
        tryVerify(() => row(0));
        compare(row(0).account, "Client");
        AppModel.names = {
            "org.example.client": "Reader"
        };
        AppModel.modelReset();
        tryCompare(row(0), "account", "Reader");
        compare(hub.sources[0].label, "Reader");
    }

    function test_swipeRightDismisses() {
        addNotification(5, "messages");
        tryVerify(() => row(0));
        swipe(row(0), 0.6);
        tryCompare(NotificationService, "dismissed", [5]);
        compare(NotificationService.clicked, []);
    }

    function test_shortSwipeSnapsBack() {
        addNotification(6, "messages");
        tryVerify(() => row(0));
        swipe(row(0), 0.15);
        wait(50);
        compare(NotificationService.dismissed, []);
        compare(NotificationService.clicked, []);
    }

    // A picture the sender sent (image-data, image-path) replaces the
    // monogram; an icon name keeps it.
    function test_rowShowsTheNotificationsPicture() {
        addNotification(1, "messages", redPixels);
        addNotification(2, "messages", "bell");
        tryVerify(() => row(1));
        tryVerify(() => findChild(row(0), "hubRowImage").hasImage);
        verify(!findChild(row(1), "hubRowImage").hasImage);
    }

    // A system notice names no sender, so its glyph stands in, as on the
    // lock screen; a message keeps its sender's monogram.
    function test_systemNotificationShowsItsGlyph() {
        NotificationService.append({
            id: 3,
            appId: "Software update",
            title: "Restart to finish updating",
            body: "",
            icon: "arrow-circle-up",
            timestamp: Date.now(),
            isRead: false
        });
        addNotification(4, "messages", "message-circle");
        tryVerify(() => row(1));
        verify(findChild(row(0), "hubRowImage").visible);
        verify(!findChild(row(0), "hubRowMonogram").visible);
        verify(!findChild(row(1), "hubRowImage").visible);
        verify(findChild(row(1), "hubRowMonogram").visible);
    }

    // ListModel can't hold the actions list, so the row gets it directly.
    function test_rowActionButtons() {
        addNotification(5, "messages");
        tryVerify(() => row(0));
        row(0).actions = [
            {
                "key": "default",
                "label": "Open"
            },
            {
                "key": "snooze",
                "label": "Snooze"
            }
        ];
        const actions = findChild(row(0), "hubRowActions");
        compare(actions.buttons.map(b => b.key), ["snooze"]);
        waitForPolish(actions);
        mouseClick(findChild(actions, "notificationAction-snooze"));
        compare(NotificationService.triggered, ["5:snooze"]);
        compare(NotificationService.clicked, []);
        mouseClick(row(0), row(0).width / 2, 10);
        compare(NotificationService.clicked, [5]);
    }

    // A row that arrives with buttons while the Hub is open pushes the rows
    // below it clear of them, also when its app brings the filter chips.
    function test_aNewRowMakesRoomForItsButtons() {
        const list = findChild(hub, "hubList");
        const snooze = [
            {
                "key": "snooze",
                "label": "Snooze"
            }
        ];
        // Yesterday's row: the new ones open a "Today" section above it.
        NotificationService.append({
            id: 1,
            appId: "messages",
            title: "Ada",
            body: "Hi",
            icon: "",
            timestamp: Date.now() - 86400000,
            isRead: false,
            ongoing: false,
            progress: -1,
            day: isoDay(1)
        });
        hub.refreshSources();
        tryVerify(() => row(0));
        row(0).actions = snooze;
        wait(400);
        for (let id = 2; id <= 6; id++) {
            NotificationService.insert(0, {
                id: id,
                appId: id === 2 ? "mail" : "messages",
                title: "Bob" + id,
                body: "Yo",
                icon: "",
                timestamp: Date.now(),
                isRead: false,
                ongoing: false,
                progress: -1,
                day: isoDay(0)
            });
            hub.refreshSources();
            // The real model has the actions when the row is made.
            list.forceLayout();
            list.itemAtIndex(0).actions = snooze;
            wait(50);
        }
        wait(MMotion.moderate + 300);
        // As drawn: no forceLayout, which would hide a stale layout.
        for (let i = 0; i + 1 < list.count; i++) {
            const above = list.itemAtIndex(i);
            const below = list.itemAtIndex(i + 1);
            verify(above.height > Silica.Theme.itemSizeLarge, i + ": " + above.height);
            verify(below.y >= above.y + above.height - 0.5, i + ": " + below.y + " < " + (above.y + above.height));
        }
    }

    // The model hands its actions as a sequence, not a JS array (an Android
    // app's chat through deckardd showed only "Mark read").
    function test_rowRepliesInlineFromAnySequence() {
        addNotification(13, "messages");
        tryVerify(() => row(0));
        row(0).actions = new Set([
            {
                "key": "mark-read",
                "label": "Mark read"
            },
            {
                "key": "inline-reply",
                "label": "Reply"
            }
        ]);
        verify(row(0).canReply);
        compare(findChild(row(0), "hubRowActions").buttons.map(b => b.key), ["inline-reply", "mark-read"]);
    }

    // An inline-reply sender's row offers Reply, as its banner does.
    function test_rowRepliesInline() {
        addNotification(12, "messages");
        tryVerify(() => row(0));
        row(0).actions = [
            {
                "key": "inline-reply",
                "label": "Reply"
            },
            {
                "key": "mark-read",
                "label": "Mark read"
            }
        ];
        const actions = findChild(row(0), "hubRowActions");
        compare(actions.buttons.map(b => b.key), ["inline-reply", "mark-read"]);
        const replied = createTemporaryObject(spyComponent, tc, {
            target: row(0),
            signalName: "replied"
        });
        waitForPolish(actions);
        mouseClick(findChild(actions, "notificationAction-inline-reply"));
        const field = findChild(row(0), "hubRowReplyField");
        tryVerify(() => field.visible);
        verify(!actions.visible);
        field.text = "On my way";
        const send = findChild(row(0), "hubRowReplySend");
        tryVerify(() => send.enabled && send.width > 0 && send.height > 0);
        waitForPolish(send.parent);
        mouseClick(send);
        compare(replied.count, 1);
        compare(replied.signalArguments[0][0], "On my way");
        compare(NotificationService.replies, ["12:On my way"]);
        verify(!field.visible);
        compare(NotificationService.triggered, []);
        compare(NotificationService.clicked, []);
    }

    // The field takes the keys typed after Reply, and a tap on it is the
    // field's, not the row's (which would open the app).
    function test_replyFieldTakesTyping() {
        addNotification(14, "messages");
        tryVerify(() => row(0));
        row(0).actions = [
            {
                "key": "inline-reply",
                "label": "Reply"
            }
        ];
        hub.Window.window.requestActivate();
        tryVerify(() => hub.Window.window.active);
        const actions = findChild(row(0), "hubRowActions");
        const activated = createTemporaryObject(spyComponent, tc, {
            target: row(0),
            signalName: "activated"
        });
        waitForPolish(actions);
        mouseClick(findChild(actions, "notificationAction-inline-reply"));
        const field = findChild(row(0), "hubRowReplyField");
        tryVerify(() => field.activeFocus);
        keyClick("O");
        keyClick("k");
        compare(field.text, "Ok");
        waitForPolish(field.parent);
        mouseClick(field);
        compare(activated.count, 0);
        const fx = field.width / 2, fy = field.height / 2;
        touchEvent(field).press(0, field, fx, fy).commit();
        touchEvent(field).release(0, field, fx, fy).commit();
        compare(activated.count, 0);
        verify(field.activeFocus);
        tryVerify(() => findChild(row(0), "hubRowReplySend").enabled);
    }

    Component {
        id: spyComponent

        SignalSpy {}
    }

    function addProgress(id, progress) {
        NotificationService.append({
            id: id,
            appId: "Software update",
            title: "Downloading Marathon OS 26101801",
            body: "42%",
            icon: "arrow-circle-up",
            timestamp: Date.now(),
            isRead: false,
            ongoing: true,
            progress: progress
        });
    }

    // An ongoing row draws its progress, stays put under a swipe and
    // still opens on a tap.
    function test_ongoingRowShowsProgress() {
        addProgress(9, 0.42);
        tryVerify(() => row(0));
        verify(row(0).ongoing);
        const bar = findChild(row(0), "hubRowProgress");
        verify(bar.visible);
        const fill = findChild(row(0), "hubRowProgressFill");
        tryVerify(() => Math.abs(fill.width - fill.parent.width * 0.42) < 1);

        swipe(row(0), 0.6);
        wait(50);
        compare(NotificationService.dismissed, []);
        mouseClick(row(0));
        compare(NotificationService.clicked, [9]);
    }

    function test_unknownProgressFillsAQuarter() {
        addProgress(10, -1);
        tryVerify(() => row(0));
        const fill = findChild(row(0), "hubRowProgressFill");
        compare(fill.width, fill.parent.width / 4);
    }

    function test_plainRowHasNoProgress() {
        addNotification(11, "messages");
        tryVerify(() => row(0));
        verify(!row(0).ongoing);
        verify(!findChild(row(0), "hubRowProgress").visible);
    }

    function test_clearAll() {
        addNotification(8, "messages");
        const item = findChild(hub, "clearNotifications");
        verify(item);
        item.clicked();
        verify(NotificationService.dismissedAll);
    }
}
