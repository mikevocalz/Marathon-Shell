import QtQuick
import QtTest
import Sailfish.Silica 1.0
import Marathon.Silica 1.0
import Marathon.Platform 1.0
import ".."
import "../Phone.js" as Phone

TestCase {
    id: testCase

    name: "PeopleRows"
    when: windowShown
    visible: true
    width: 720
    height: 1440

    Component {
        id: appComponent

        PhoneApp {
            width: 720
            height: 1440
        }
    }

    function init() {
        Telephony.reset();
        Contacts.reset();
        CallHistory.reset();
        Permissions.reset();
        Navigation.reset();
        Contacts.contacts = [
            {
                id: 1,
                name: "Ada Lovelace",
                phone: "+44 20 7946 0001",
                email: "",
                favorite: true
            },
            {
                id: 2,
                name: "Ada Lovelace",
                phone: "+44 20 7946 0002",
                email: "",
                favorite: false
            },
            {
                id: 3,
                name: "Grace Hopper",
                phone: "",
                email: "grace@example.com",
                favorite: false
            }
        ];
    }

    function makeApp() {
        const app = createTemporaryObject(appComponent, testCase);
        tryVerify(() => app.pageStack.currentPage !== null);
        app.pageStack.currentPage.tabs.moveTo(2);
        tryVerify(() => findChild(app.pageStack.currentPage, "people") !== null);
        const list = findChild(app.pageStack.currentPage, "people");
        tryVerify(() => Math.abs(list.mapToItem(testCase, 0, 0).x) < 1);
        return app;
    }

    function rowAt(app, index) {
        const list = findChild(app.pageStack.currentPage, "people");
        list.currentIndex = index;
        list.positionViewAtIndex(index, ListView.Contain);
        tryVerify(() => list.currentItem !== null);
        return list.currentItem;
    }

    function test_sameNamesHaveDistinctVisibleAndAccessibleNumbers() {
        const app = makeApp();
        const favorite = rowAt(app, 0);
        const other = rowAt(app, 1);
        compare(favorite.text, other.text);
        compare(favorite.description, Phone.format("+44 20 7946 0001"));
        compare(other.description, Phone.format("+44 20 7946 0002"));
        verify(favorite.Accessible.name !== other.Accessible.name);
        compare(favorite.Accessible.description, "Favorite");
        compare(other.Accessible.description, "");
        compare(favorite.iconSource.toString(), "image://theme/icon-m-favorite-selected");
    }

    function test_emailOnlyContactDoesNotOfferCalling() {
        const app = makeApp();
        const row = rowAt(app, 2);
        compare(row.description, "grace@example.com");
        const menu = row.openMenu();
        verify(menu);
        verify(!findChild(menu, "callPersonMenuItem").enabled);
        verify(!findChild(menu, "messagePersonMenuItem").enabled);
        row.closeMenu();
    }

    function test_largeNameFitsAndStillOpensExactContact() {
        Contacts.contacts = [
            {
                id: 41,
                name: "Admiral Grace Murray Hopper",
                phone: "+1 555 123 4567",
                email: "",
                favorite: false
            }
        ];
        const app = makeApp();
        app.width = 320;
        const row = rowAt(app, 0);
        row.font.pixelSize = Theme.fontSizeHuge;
        row.descriptionFont.pixelSize = Theme.fontSizeLarge;
        const title = findChild(row, "summaryText");
        const detail = findChild(row, "summaryDescription");
        tryVerify(() => title.lineCount > 1);
        verify(!title.truncated);
        verify(!detail.truncated);
        tryVerify(() => detail.mapToItem(row, 0, detail.height).y <= row.contentHeight);
        row.forceActiveFocus();
        keyClick(Qt.Key_Return);
        tryVerify(() => app.pageStack.depth === 2);
        compare(app.pageStack.currentPage.contactId, 41);
    }
}
