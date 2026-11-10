pragma ComponentBehavior: Bound

import QtQuick
import Sailfish.Silica 1.0
import Marathon.Silica 1.0
import Nemo.Ngf 1.0
import ".."

Page {
    id: page

    property Calculator calc
    property bool scientific: true
    readonly property real functionKeyHeight: Math.max(Theme.itemSizeSmall, Theme.fontSizeMedium + 2 * Theme.paddingSmall)
    readonly property real minimumKeyHeight: Math.max(Theme.itemSizeSmall, Theme.fontSizeExtraLarge + 2 * Theme.paddingSmall)
    readonly property real minimumHistoryHeight: Math.max(Theme.itemSizeMedium, historyPlaceholder.visible ? historyPlaceholder.implicitHeight + 2 * Theme.paddingMedium : Theme.fontSizeSmall + Theme.fontSizeMedium + 2 * Theme.paddingMedium)
    readonly property real keyHeight: Math.max(minimumKeyHeight, Math.min(Theme.itemSizeLarge, (height - 2 * Theme.paddingMedium - displayArea.contentHeight - (scientific ? functionKeys.height : 0) - minimumHistoryHeight) / 5))
    readonly property real minimumContentHeight: minimumHistoryHeight + displayArea.contentHeight + (scientific ? functionKeys.height : 0) + 5 * keyHeight + 2 * Theme.paddingMedium

    TextMetrics {
        id: functionText

        text: "mod"
        font.pixelSize: Theme.fontSizeMedium
        font.family: Theme.fontFamily
    }

    function tap(k) {
        feedback.play();
        page.calc.press(k);
    }

    function keyFor(event) {
        if (event.key >= Qt.Key_0 && event.key <= Qt.Key_9)
            return String(event.key - Qt.Key_0);
        switch (event.key) {
        case Qt.Key_Period:
        case Qt.Key_Comma:
            return ".";
        case Qt.Key_Plus:
            return "+";
        case Qt.Key_Minus:
            return "−";
        case Qt.Key_Asterisk:
        case Qt.Key_multiply:
            return "×";
        case Qt.Key_Slash:
        case Qt.Key_division:
            return "÷";
        case Qt.Key_Percent:
            return "%";
        case Qt.Key_Equal:
        case Qt.Key_Return:
        case Qt.Key_Enter:
            return "=";
        case Qt.Key_Backspace:
            return "⌫";
        case Qt.Key_Escape:
        case Qt.Key_Delete:
            return "C";
        }
        return "";
    }

    // Forwarded first, so Escape clears before Page's own Escape goes back.
    Keys.forwardTo: [typing]

    Item {
        id: typing

        Keys.onPressed: function (event) {
            const k = page.keyFor(event);
            if (k === "" || (k === "C" && page.calc.isClear))
                return;
            event.accepted = true;
            page.tap(k);
        }
    }

    NonGraphicalFeedback {
        id: feedback
        event: "feedback_press"
    }

    SilicaFlickable {
        objectName: "calculatorView"
        anchors.horizontalCenter: parent.horizontalCenter
        width: Math.min(parent.width, 6 * Theme.itemSizeExtraLarge)
        height: parent.height
        // An open display menu pushes the keys down, not the number up.
        // Short windows scroll instead of compressing keys below readable sizes.
        contentHeight: Math.max(height, page.minimumContentHeight) + displayArea.height - displayArea.contentHeight

        PullDownMenu {
            MenuItem {
                objectName: "modeItem"
                text: page.scientific ? qsTr("Basic mode") : qsTr("Scientific mode")
                onClicked: page.scientific = !page.scientific
            }
            MenuItem {
                objectName: "undoItem"
                text: qsTr("Undo")
                enabled: page.calc.canUndo
                onClicked: page.calc.undo()
            }
        }

        SilicaListView {
            id: history

            objectName: "history"
            anchors {
                top: parent.top
                bottom: displayArea.top
                left: parent.left
                right: parent.right
                topMargin: Theme.paddingLarge
            }
            clip: true
            interactive: contentHeight > height
            verticalLayoutDirection: ListView.BottomToTop
            model: page.calc.history

            // Tapping a result uses it in the current calculation, as in Jolla Calculator.
            delegate: BackgroundItem {
                id: entry

                required property var modelData

                objectName: "historyItem"
                width: history.width
                height: entryColumn.height + Theme.paddingSmall
                enabled: entry.modelData.value !== undefined
                Accessible.name: entry.modelData.expression + " " + entry.modelData.result
                onClicked: {
                    feedback.play();
                    page.calc.snapshot();
                    page.calc.recall(entry.modelData.value);
                }

                Column {
                    id: entryColumn

                    x: Theme.horizontalPageMargin
                    width: parent.width - 2 * Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter

                    Label {
                        objectName: "historyExpression"
                        width: parent.width
                        horizontalAlignment: Text.AlignRight
                        wrapMode: Text.Wrap
                        text: entry.modelData.expression
                        textFormat: Text.PlainText
                        font.pixelSize: Theme.fontSizeSmall
                        color: entry.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                    }
                    Label {
                        objectName: "historyResult"
                        width: parent.width
                        horizontalAlignment: Text.AlignRight
                        wrapMode: Text.Wrap
                        text: entry.modelData.result
                        textFormat: Text.PlainText
                        color: entry.highlighted ? Theme.highlightColor : Theme.secondaryHighlightColor
                    }
                }
            }

            VerticalScrollDecorator {}
        }

        InfoLabel {
            id: historyPlaceholder

            objectName: "historyPlaceholder"
            anchors.centerIn: history
            width: history.width - 2 * Theme.horizontalPageMargin
            font.pixelSize: Theme.fontSizeLarge
            visible: page.calc.history.length === 0
            text: qsTr("Calculations appear here")
        }

        ListItem {
            id: displayArea

            objectName: "displayArea"
            anchors.bottom: functionKeys.visible ? functionKeys.top : keypad.top
            contentHeight: display.height + Theme.paddingLarge
            menu: Component {
                ContextMenu {
                    MenuItem {
                        objectName: "copyItem"
                        text: qsTr("Copy")
                        visible: page.calc.errorText === ""
                        onClicked: Clipboard.text = page.calc.displayText.split(page.calc.locale.groupSeparator).join("")
                    }
                    MenuItem {
                        objectName: "pasteItem"
                        text: qsTr("Paste")
                        visible: isFinite(page.calc.parseNumber(Clipboard.text))
                        onClicked: page.calc.paste(Clipboard.text)
                    }
                }
            }

            Column {
                id: display

                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin

                Label {
                    objectName: "expression"
                    width: parent.width
                    horizontalAlignment: Text.AlignRight
                    wrapMode: Text.Wrap
                    visible: text !== ""
                    text: page.calc.expressionText
                    color: Theme.secondaryColor
                }
                Label {
                    objectName: "result"
                    width: parent.width
                    horizontalAlignment: Text.AlignRight
                    wrapMode: Text.Wrap
                    visible: text !== "" && page.calc.currentOperator === ""
                    text: page.calc.lastResult
                    color: Theme.highlightColor
                }
                Label {
                    objectName: "display"
                    width: parent.width
                    height: Math.max(Theme.itemSizeLarge, implicitHeight)
                    horizontalAlignment: Text.AlignRight
                    verticalAlignment: Text.AlignVCenter
                    fontSizeMode: page.calc.errorText !== "" ? Text.FixedSize : Text.HorizontalFit
                    wrapMode: page.calc.errorText !== "" ? Text.Wrap : Text.NoWrap
                    minimumPixelSize: Theme.fontSizeLarge
                    text: page.calc.displayText
                    font.pixelSize: page.calc.errorText !== "" ? Theme.fontSizeExtraLarge : Theme.fontSizeHuge
                    font.family: Theme.fontFamilyHeading
                    color: page.calc.errorText !== "" ? Theme.errorColor : Theme.primaryColor
                    Accessible.role: Accessible.StaticText
                    Accessible.name: text
                }
            }
        }

        Grid {
            id: functionKeys

            objectName: "functionKeys"
            visible: page.scientific
            anchors {
                bottom: keypad.top
                left: parent.left
                right: parent.right
                leftMargin: Theme.paddingMedium
                rightMargin: Theme.paddingMedium
            }
            columns: width >= 6 * (functionText.advanceWidth + 2 * Theme.paddingMedium) ? 6 : width >= 4 * (functionText.advanceWidth + 2 * Theme.paddingMedium) ? 4 : 3

            Repeater {
                model: ["sin", "cos", "tan", "ln", "log", "!", "π", "e", "√", "x²", "mod", "ans"]

                CalcKey {
                    required property string modelData

                    width: functionKeys.width / functionKeys.columns
                    height: page.functionKeyHeight
                    key: modelData
                    kind: "function"
                    onClicked: page.tap(key)
                }
            }
        }

        Grid {
            id: keypad

            anchors {
                bottom: parent.bottom
                left: parent.left
                right: parent.right
                margins: Theme.paddingMedium
            }
            columns: 4

            Repeater {
                model: [
                    {
                        key: "C",
                        kind: "soft"
                    },
                    {
                        key: "⌫",
                        kind: "soft"
                    },
                    {
                        key: "%",
                        kind: "soft"
                    },
                    {
                        key: "÷",
                        kind: "op"
                    },
                    {
                        key: "7",
                        kind: "digit"
                    },
                    {
                        key: "8",
                        kind: "digit"
                    },
                    {
                        key: "9",
                        kind: "digit"
                    },
                    {
                        key: "×",
                        kind: "op"
                    },
                    {
                        key: "4",
                        kind: "digit"
                    },
                    {
                        key: "5",
                        kind: "digit"
                    },
                    {
                        key: "6",
                        kind: "digit"
                    },
                    {
                        key: "−",
                        kind: "op"
                    },
                    {
                        key: "1",
                        kind: "digit"
                    },
                    {
                        key: "2",
                        kind: "digit"
                    },
                    {
                        key: "3",
                        kind: "digit"
                    },
                    {
                        key: "+",
                        kind: "op"
                    },
                    {
                        key: "+/−",
                        kind: "soft"
                    },
                    {
                        key: "0",
                        kind: "digit"
                    },
                    {
                        key: ".",
                        kind: "digit"
                    },
                    {
                        key: "=",
                        kind: "equals"
                    }
                ]

                CalcKey {
                    required property var modelData

                    width: keypad.width / keypad.columns
                    height: page.keyHeight
                    key: modelData.key
                    kind: modelData.kind
                    onClicked: page.tap(key)
                }
            }
        }

        VerticalScrollDecorator {}
    }
}
