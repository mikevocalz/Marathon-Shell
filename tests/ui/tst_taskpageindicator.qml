import QtQuick
import QtTest
import MarathonOS.Shell
import "../../shell/qml/components"

TestCase {
    id: testCase

    name: "TaskPageIndicator"
    when: windowShown
    visible: true
    width: 720
    height: 720

    Component {
        id: indicatorComponent
        TaskPageIndicator {
            gridContentY: 0
            gridContentHeight: 960
            gridHeight: 320
        }
    }

    function cleanup() {
        MMotion.reduceMotion = false;
    }

    function test_pageIdentityAndReducedMotion() {
        MMotion.reduceMotion = true;
        const indicator = createTemporaryObject(indicatorComponent, testCase);
        verify(indicator);
        compare(indicator.pageCount, 3);
        compare(indicator.Accessible.name, "Page 1 of 3");
        indicator.gridContentY = 640;
        compare(indicator.Accessible.name, "Page 3 of 3");
        for (const child of indicator.children) {
            if (typeof child.isActive === "boolean") {
                compare(child.height, child.isActive ? MSpacing.md + MSpacing.xs : MRadius.lg);
                compare(child.radius, child.width / 2);
            }
        }
        indicator.gridContentHeight = 0;
        compare(indicator.pageCount, 1);
        compare(indicator.currentPage, 0);
        verify(!indicator.visible);
    }
}
