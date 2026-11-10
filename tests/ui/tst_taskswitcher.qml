pragma ComponentBehavior: Bound

import QtQuick
import QtTest
import MarathonOS.Shell
import "../../shell/qml/components"

TestCase {
    id: tc

    name: "TaskSwitcher"
    when: windowShown
    width: 1500
    height: 1140

    property var switcher: null
    property var grid: null

    Component {
        id: switcherComponent

        MarathonTaskSwitcher {
            width: 720
            height: tc.height
        }
    }

    function entry(i) {
        return {
            taskId: "task" + i,
            appId: "app" + i,
            title: "App " + i,
            icon: "",
            type: "marathon",
            surfaceId: -1
        };
    }

    function init() {
        Tasks.clear();
        for (let i = 0; i < 12; ++i)
            Tasks.append(entry(i));
        switcher = createTemporaryObject(switcherComponent, tc);
        verify(switcher !== null);
        grid = findChild(switcher, "taskGrid");
        tryCompare(grid, "count", 12);
        grid.showPage(0);
        waitForPolish(grid);
        tryVerify(() => grid.itemAtIndex(11) !== null);
        waitForRendering(switcher);
    }

    function cleanup() {
        switcher.destroy();
        switcher = null;
        grid = null;
        Tasks.clear();
        waitForRendering(tc);
    }

    function onPage(page) {
        return Math.abs(grid.contentY - grid.originY - page * grid.pageHeight) < 0.5;
    }

    function verifyPage(page) {
        let reconciled = false;
        Qt.callLater(function () {
            reconciled = true;
        });
        tryVerify(() => reconciled);
        waitForPolish(grid);
        tryVerify(() => onPage(page));
    }

    function verifyCoverVisible(appId) {
        tryVerify(() => switcher.cardRect(appId).height > 0);
        const cover = switcher.cardRect(appId);
        verify(cover.y >= 0, "The anchor cover must remain on the visible page");
        verify(cover.y + cover.height <= switcher.height - Constants.bottomBarHeight);
    }

    function test_anchorSurvivesRoundTripResize() {
        grid.showPage(1);
        compare(grid.pageAnchorIndex, 4);
        switcher.width = 1000;
        tryCompare(grid, "columns", 3);
        tryCompare(grid, "contentY", grid.originY);
        compare(grid.pageAnchorIndex, 4);
        switcher.width = 720;
        tryCompare(grid, "columns", 2);
        tryVerify(() => Math.abs(grid.contentY - grid.originY - grid.pageHeight) < 0.5);
        compare(grid.pageAnchorIndex, 4);
    }

    function test_anchorClampsWhenLastPageCloses() {
        grid.showPage(2);
        Tasks.remove(5, 7);
        tryCompare(grid, "count", 5);
        tryVerify(() => Math.abs(grid.contentY - grid.originY - grid.pageHeight) < 0.5);
        verify(grid.pageAnchorIndex < grid.count);
        Tasks.clear();
        tryVerify(() => Math.abs(grid.contentY - grid.originY) < 0.5);
        tryCompare(grid, "pageAnchorIndex", 0);
    }

    function test_navigationReplacesReflowAnchor() {
        grid.showPage(1);
        switcher.width = 1000;
        tryCompare(grid, "columns", 3);
        grid.showPage(1);
        compare(grid.pageAnchorIndex, 6);
        switcher.width = 1500;
        tryCompare(grid, "columns", 4);
        compare(grid.pageAnchorIndex, 6);
        switcher.width = 720;
        tryCompare(grid, "columns", 2);
        tryVerify(() => Math.abs(grid.contentY - grid.originY - grid.pageHeight) < 0.5);
        compare(grid.pageAnchorIndex, 6);
    }

    function test_heightResizeKeepsCurrentPage() {
        grid.showPage(2);
        switcher.height = 720;
        tryVerify(() => Math.abs(grid.contentY - grid.originY - 2 * grid.pageHeight) < 0.5);
        compare(grid.pageAnchorIndex, 8);
        switcher.height = tc.height;
    }

    function test_removingAnEarlierCardKeepsTheViewedCard() {
        grid.showPage(2);
        Tasks.remove(0);
        tryCompare(grid, "count", 11);
        verifyPage(1);
        verifyCoverVisible("app8");
    }

    function test_insertingEarlierCardsKeepsTheViewedCard() {
        grid.showPage(1);
        for (let i = 12; i < 16; ++i)
            Tasks.insert(0, entry(i));
        tryCompare(grid, "count", 16);
        verifyPage(2);
        verifyCoverVisible("app4");
    }

    function test_sameCountReorderKeepsTheViewedCard() {
        grid.showPage(2);
        Tasks.move(8, 0, 1);
        compare(grid.count, 12);
        verifyPage(0);
        verifyCoverVisible("app8");
    }

    function test_modelReplacementKeepsASurvivingAnchor() {
        grid.showPage(2);
        Tasks.clear();
        for (let i = 8; i < 20; ++i)
            Tasks.append(entry(i));
        tryCompare(grid, "count", 12);
        verifyPage(0);
        verifyCoverVisible("app8");
    }

    function test_revealFindsAnUninstantiatedCardAndKeepsItThroughResize() {
        for (let i = 12; i < 40; ++i)
            Tasks.append(entry(i));
        tryCompare(grid, "count", 40);
        tryVerify(() => grid.itemAtIndex(35) === null);
        switcher.revealCard("app35");
        verifyPage(8);
        verifyCoverVisible("app35");
        switcher.width = 1500;
        tryCompare(grid, "columns", 4);
        verifyPage(4);
        verifyCoverVisible("app35");
        switcher.width = 720;
        tryCompare(grid, "columns", 2);
        verifyPage(8);
        verifyCoverVisible("app35");
    }

    function test_columnChangeWithTheSameCellWidthReanchorsThePage() {
        switcher.width = 592 + grid.gap;
        tryCompare(grid, "columns", 2);
        grid.showPage(2);
        const cellWidth = grid.cellWidth;
        switcher.width = 888 + grid.gap;
        tryCompare(grid, "columns", 3);
        compare(grid.cellWidth, cellWidth);
        verifyPage(1);
        verifyCoverVisible("app8");
        switcher.width = 592 + grid.gap;
        tryCompare(grid, "columns", 2);
        verifyPage(2);
        verifyCoverVisible("app8");
    }
}
