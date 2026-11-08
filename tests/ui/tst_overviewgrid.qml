import QtQuick
import QtTest
import "../../shell/qml/core/OverviewGrid.js" as OverviewGrid

TestCase {
    name: "OverviewGrid"

    function test_columns_data() {
        return [
            { "tag": "compact-portrait", "width": 390, "scale": 1, "expected": 2 },
            { "tag": "square-phone", "width": 720, "scale": 1, "expected": 2 },
            { "tag": "small-tablet", "width": 1000, "scale": 1, "expected": 3 },
            { "tag": "wide-tablet", "width": 1500, "scale": 1, "expected": 4 },
            { "tag": "large-text", "width": 1100, "scale": 1.4, "expected": 2 },
            { "tag": "scaled-desktop", "width": 1500, "scale": 1.5, "expected": 3 },
            { "tag": "unmeasured", "width": 0, "scale": 1, "expected": 2 }
        ];
    }

    function test_columns(data) {
        compare(OverviewGrid.columns(data.width, data.scale), data.expected);
    }

    function test_pages_and_partFilledLastPage() {
        compare(OverviewGrid.pageCount(0, 2, 2), 1);
        compare(OverviewGrid.pageCount(4, 2, 2), 1);
        compare(OverviewGrid.pageCount(5, 2, 2), 2);
        compare(OverviewGrid.pageCount(7, 3, 2), 2);
        compare(OverviewGrid.pageCount(8, 4, 2), 1);
        compare(OverviewGrid.pageCount(9, 4, 2), 2);
        compare(OverviewGrid.itemsPerPage(3, 2), 6);
    }

    function test_revealCardsOnTheirCurrentPage() {
        compare(OverviewGrid.pageForIndex(0, 2, 2), 0);
        compare(OverviewGrid.pageForIndex(4, 2, 2), 1);
        compare(OverviewGrid.pageForIndex(4, 3, 2), 0);
        compare(OverviewGrid.pageForIndex(6, 3, 2), 1);
        compare(OverviewGrid.pageForIndex(8, 4, 2), 1);
    }

    function test_anchorSurvivesReflowAndRemoval() {
        const previouslyVisibleIndex = 8;
        compare(OverviewGrid.pageForIndex(previouslyVisibleIndex, 2, 2), 2);
        compare(OverviewGrid.pageForIndex(previouslyVisibleIndex, 4, 2), 1);
        compare(OverviewGrid.clampPage(2, 5, 2, 2), 1);
        compare(OverviewGrid.clampPage(1, 0, 2, 2), 0);
    }
}
