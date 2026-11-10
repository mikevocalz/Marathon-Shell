import QtQuick
import QtTest
import Sailfish.Silica 1.0
import Marathon.Silica 1.0

TestCase {
    id: testCase

    name: "NativeBusyAssets"
    when: windowShown
    visible: true
    width: 320
    height: 480

    Component {
        id: indicatorComponent
        BusyIndicator {
            running: true
        }
    }

    function test_eachNativeSizeHasAVisibleAsset_data() {
        return [
            {
                tag: "extra-small",
                size: BusyIndicatorSize.ExtraSmall
            },
            {
                tag: "small",
                size: BusyIndicatorSize.Small
            },
            {
                tag: "medium",
                size: BusyIndicatorSize.Medium
            },
            {
                tag: "large",
                size: BusyIndicatorSize.Large
            }
        ];
    }

    function test_eachNativeSizeHasAVisibleAsset(data) {
        const indicator = createTemporaryObject(indicatorComponent, testCase, {
            size: data.size
        });
        verify(indicator);
        tryVerify(() => indicator.implicitWidth > 0 && indicator.implicitHeight > 0);
        tryVerify(() => indicator.opacity > 0);
        compare(indicator.width, indicator.implicitWidth);
        indicator.running = false;
        tryCompare(indicator, "opacity", 0);
    }
}
