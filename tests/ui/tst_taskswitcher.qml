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

    MarathonTaskSwitcher {
        id: switcher

        width: 720
        height: parent.height
    }

    readonly property var grid: findChild(switcher, "taskGrid")

    function init() {
        Tasks.clear();
        for (let i = 0; i < 12; ++i)
            Tasks.append({
                taskId: "task" + i,
                appId: "app" + i,
                title: "App " + i,
                icon: "",
                type: "marathon",
                surfaceId: -1
            });
        switcher.width = 720;
        tryCompare(grid, "count", 12);
        grid.showPage(0);
        waitForPolish(grid);
        tryVerify(() => grid.itemAtIndex(11) !== null);
    }

    function cleanup() {
        Tasks.clear();
        tryCompare(grid, "count", 0);
        waitForPolish(grid);
        wait(50);
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
}
