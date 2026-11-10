import QtQuick
import QtTest
import Sailfish.Silica 1.0
import Marathon.Silica 1.0
import Marathon.Platform 1.0
import ".."

TestCase {
    id: testCase

    name: "SettingsRows"
    when: windowShown
    visible: true
    width: 720
    height: 1440

    Component {
        id: appComponent

        SettingsApp {
            width: 540
            height: 1140
        }
    }

    function init() {
        Modem.reset();
        Network.reset();
        Bluetooth.reset();
        Settings.reset();
        Power.reset();
        Audio.reset();
        Navigation.reset();
        Security.reset();
    }

    function makeApp() {
        const app = createTemporaryObject(appComponent, testCase);
        tryVerify(() => app.pageStack.currentPage !== null);
        return app;
    }

    function test_longServiceValueFitsAndUpdates() {
        Network.wifiConnected = true;
        Network.wifiSsid = "<b>Conference room network with a long name</b>";
        const app = makeApp();
        app.width = 320;
        const row = findChild(app.pageStack.currentPage, "entry-wifi");
        verify(row);
        row.descriptionFont.pixelSize = Theme.fontSizeLarge;
        const detail = findChild(row, "summaryDescription");
        tryVerify(() => detail.lineCount > 1);
        verify(!detail.truncated);
        // Text metrics settle before the Column's polish pass grows its row.
        tryVerify(() => detail.mapToItem(row, 0, detail.height).y <= row.contentHeight);
        compare(detail.textFormat, Text.PlainText);
        compare(row.Accessible.name, "Wi-Fi, " + Network.wifiSsid);
        Network.wifiSsid = "Home";
        compare(detail.text, "Home");
        compare(row.Accessible.name, "Wi-Fi, Home");
    }

    function test_searchShowsCategoryAndLiveValue() {
        Network.wifiConnected = true;
        Network.wifiSsid = "Studio";
        const app = makeApp();
        const page = app.pageStack.currentPage;
        const search = findChild(page, "searchField");
        search.text = "wifi";
        const results = findChild(page, "results");
        tryVerify(() => results.count > 0);
        const row = results.itemAt(0);
        compare(row.modelData.page, "wifi");
        compare(row.description, row.modelData.section + " · Studio");
        compare(row.Accessible.name, row.text + ", " + row.description);
        Network.wifiSsid = "Library";
        compare(row.description, row.modelData.section + " · Library");
        search.forceActiveFocus();
        app.width = 320;
        compare(search.text, "wifi");
        verify(search.activeFocus);
    }

    function test_keyboardOpensTheSelectedSetting() {
        const app = makeApp();
        const main = app.pageStack.currentPage;
        const row = findChild(main, "entry-wifi");
        row.forceActiveFocus();
        keyClick(Qt.Key_Return);
        tryVerify(() => app.pageStack.currentPage !== main && app.pageStack.currentPage.status === PageStatus.Active);
        verify(String(app.pageStack.currentPage).indexOf("WiFiPage") === 0);
        app.pageStack.pop(undefined, PageStackAction.Immediate);
        tryVerify(() => app.pageStack.currentPage === main);
        compare(findChild(main, "entry-wifi"), row);
    }
}
