import QtQuick
import QtTest
import Sailfish.Silica 1.0
import Marathon.Silica 1.0

TestCase {
    id: testCase

    name: "SummaryListItem"
    when: windowShown
    visible: true
    width: 720
    height: 1440

    Component {
        id: rowComponent

        SummaryListItem {
            width: 720
            text: "A contact with a long display name"
            description: "A secondary address or current service status"
            iconSource: "image://theme/icon-m-contact"
        }
    }

    SignalSpy {
        id: clickSpy

        signalName: "clicked"
    }

    function checkTextFits(row) {
        const title = findChild(row, "summaryText");
        const detail = findChild(row, "summaryDescription");
        verify(title.width > 0);
        verify(!title.truncated);
        verify(!detail.truncated);
        const titleTop = title.mapToItem(row, 0, 0).y;
        const detailTop = detail.mapToItem(row, 0, 0).y;
        verify(titleTop >= 0);
        verify(detailTop >= titleTop + title.height);
        verify(detailTop + detail.height <= row.contentHeight);
    }

    function test_growsForLargeTextOnNarrowScreens() {
        const row = createTemporaryObject(rowComponent, testCase);
        const normalHeight = row.contentHeight;
        row.width = 320;
        row.font.pixelSize = Theme.fontSizeHuge;
        row.descriptionFont.pixelSize = Theme.fontSizeLarge;
        tryVerify(() => row.contentHeight > normalHeight);
        checkTextFits(row);
        verify(findChild(row, "summaryText").lineCount > 1);
        verify(findChild(row, "summaryDescription").lineCount > 1);
        const narrowHeight = row.contentHeight;
        row.width = 720;
        tryVerify(() => row.contentHeight < narrowHeight);
        checkTextFits(row);
    }

    function test_plainTextMatchesAccessibleIdentity() {
        const row = createTemporaryObject(rowComponent, testCase, {
            text: "<b>Ada</b>",
            description: "<i>Home network</i>"
        });
        compare(findChild(row, "summaryText").textFormat, Text.PlainText);
        compare(findChild(row, "summaryDescription").textFormat, Text.PlainText);
        compare(row.Accessible.name, "<b>Ada</b>, <i>Home network</i>");
        row.description = "";
        compare(row.Accessible.name, "<b>Ada</b>");
        verify(!findChild(row, "summaryDescription").visible);
    }

    function test_optionalIconReturnsItsSpaceToText() {
        const row = createTemporaryObject(rowComponent, testCase);
        const title = findChild(row, "summaryText");
        const icon = findChild(row, "summaryIcon");
        const withIcon = title.mapToItem(row, 0, 0).x;
        row.iconSource = "";
        verify(!icon.visible);
        tryVerify(() => title.mapToItem(row, 0, 0).x < withIcon);
        compare(title.mapToItem(row, 0, 0).x, Theme.horizontalPageMargin);
    }

    function test_keyboardAndAccessibilityActivateOnce() {
        const row = createTemporaryObject(rowComponent, testCase);
        clickSpy.target = row;
        clickSpy.clear();
        row.forceActiveFocus();
        verify(row.activeFocus);
        verify(findChild(row, "focusFrame").showing);
        keyClick(Qt.Key_Return);
        compare(clickSpy.count, 1);
        keyClick(Qt.Key_Space);
        compare(clickSpy.count, 2);
        row.Accessible.pressAction();
        compare(clickSpy.count, 3);
        row.enabled = false;
        keyClick(Qt.Key_Return);
        compare(clickSpy.count, 3);
    }
}
