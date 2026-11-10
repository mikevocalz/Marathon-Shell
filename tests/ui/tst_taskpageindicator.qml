import QtQuick
import QtTest
import Keel 1.0 as Keel
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

    function initTestCase() {
        Keel.Ambience.applyForwarded("/desktop/sailfish/silica/font_size_multiplier=1");
    }

    function cleanup() {
        MMotion.reduceMotion = false;
        Constants.scaleFactor = 1;
    }

    function cleanupTestCase() {
        Keel.Ambience.applyForwarded("");
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

    function test_liveScaleChangesReachTheRealThemeTokens() {
        MMotion.reduceMotion = true;
        const indicator = createTemporaryObject(indicatorComponent, testCase);
        const dots = Array.from(indicator.children).filter(child => typeof child.isActive === "boolean");
        compare(dots.length, 3);
        for (const size of [
            {
                scale: 0.75,
                radius: 5,
                height: 15
            },
            {
                scale: 1.5,
                radius: 9,
                height: 30
            },
            {
                scale: 2,
                radius: 12,
                height: 40
            },
            {
                scale: 1,
                radius: 6,
                height: 20
            }
        ]) {
            Constants.scaleFactor = size.scale;
            compare(MRadius.lg, size.radius);
            compare(MSpacing.md + MSpacing.xs, size.height);
            for (const dot of dots) {
                compare(dot.width, size.radius);
                compare(dot.height, dot.isActive ? size.height : size.radius);
                compare(dot.radius, size.radius / 2);
            }
        }
    }
}
