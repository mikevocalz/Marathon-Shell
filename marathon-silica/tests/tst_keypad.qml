import QtQuick
import QtTest
import Sailfish.Silica 1.0
import Marathon.Silica 1.0

TestCase {
    id: testCase

    name: "AdaptiveKeypad"
    when: windowShown
    visible: true
    width: 1024
    height: 1440

    Component {
        id: keypadComponent
        Keypad {}
    }

    SignalSpy {
        id: clicks
        signalName: "clicked"
    }

    function buttons(item) {
        let result = [];
        for (const child of item.children) {
            if (typeof child.key === "number" && typeof child.secondaryText === "string")
                result.push(child);
            result = result.concat(buttons(child));
        }
        return result;
    }

    function verifyBounds(keypad) {
        const keys = buttons(keypad);
        compare(keys.length, 12);
        for (const key of keys) {
            const position = key.mapToItem(keypad, 0, 0);
            verify(position.x >= 0);
            verify(position.x + key.width <= keypad.width);
            verify(position.y >= 0);
            verify(position.y + key.height <= keypad.height);
            verify(key.width >= Theme.itemSizeSmall);
        }
        return keys;
    }

    function test_keysFitAndKeepTheirValues_data() {
        return [
            {
                tag: "phone",
                width: 320
            },
            {
                tag: "square",
                width: 720
            },
            {
                tag: "window",
                width: 1024
            }
        ];
    }

    function test_keysFitAndKeepTheirValues(data) {
        const keypad = createTemporaryObject(keypadComponent, testCase, {
            width: data.width
        });
        verify(keypad);
        waitForPolish(keypad);
        clicks.target = keypad;
        clicks.clear();
        const keys = verifyBounds(keypad);
        for (let i = 0; i < keys.length; ++i) {
            mouseClick(keys[i]);
            compare(clicks.signalArguments[i][0], keys[i].text);
        }
        compare(clicks.count, 12);
        keypad.width = 360;
        waitForPolish(keypad);
        verifyBounds(keypad);
    }
}
