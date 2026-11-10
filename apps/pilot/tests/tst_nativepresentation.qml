import QtQuick
import QtTest
import Sailfish.Silica 1.0
import Marathon.Silica 1.0
import Shipwright.Pilot 1.0
import "../ui"
import "../ui/pages"
import "../ui/components"

TestCase {
    id: testCase

    name: "PilotNativePresentation"
    when: windowShown
    visible: true
    width: 720
    height: 1140

    Component {
        id: appComponent
        ApplicationWindow {
            width: 540
            height: 1140
            initialPage: MainPage {}
        }
    }
    Component {
        id: promptComponent
        PromptField {
            width: 320
        }
    }
    Component {
        id: overlayComponent
        Overlay {
            width: 360
            height: 800
        }
    }
    Component {
        id: suggestionComponent
        SuggestionTile {
            width: 320
            icon: "calendar"
        }
    }
    Component {
        id: answerComponent
        AnswerCard {
            width: 320
        }
    }
    Component {
        id: planComponent
        PlanCard {
            width: 320
        }
    }
    SignalSpy {
        id: clicks
        signalName: "clicked"
    }
    SignalSpy {
        id: answers
        signalName: "answer"
    }

    function init() {
        Pilot.reset();
        Conversation.model.clear();
        Conversation.draft = "";
        Conversation.now = {};
        Conversation.guide = ["hidden"];
        Conversation.listening = false;
        Conversation.transcribing = false;
    }

    function makeApp() {
        const app = createTemporaryObject(appComponent, testCase);
        verify(app);
        tryVerify(() => app.pageStack.currentPage !== null && !app.pageStack.busy);
        return app;
    }

    function test_busyAndDisconnectedSubmissionKeepsDraftSelection() {
        const field = createTemporaryObject(promptComponent, testCase);
        field.text = "Keep this unfinished question";
        field.forceActiveFocus();
        field.select(5, 9);
        const cursor = field.cursorPosition;
        Pilot.busy = true;
        verify(!field.submit());
        compare(field.text, "Keep this unfinished question");
        compare(Conversation.draft, field.text);
        compare(field.selectedText, "this");
        compare(field.cursorPosition, cursor);
        verify(field.activeFocus);
        compare(Pilot.requests.length, 0);
        compare(Conversation.model.count, 0);

        Pilot.busy = false;
        Pilot.connected = false;
        verify(!field.submit());
        compare(field.selectedText, "this");
        compare(field.text, Conversation.draft);
        compare(Pilot.requests.length, 0);
        Pilot.connected = true;
        field.deselect();
        keyClick(Qt.Key_Return);
        compare(Pilot.requests, [
            {
                text: "Keep this unfinished question",
                spoken: false
            }
        ]);
        compare(Conversation.model.count, 1);
        compare(Conversation.model.get(0).text, "Keep this unfinished question");
        compare(field.text, "");
        compare(Conversation.draft, "");
        keyClick(Qt.Key_Return);
        compare(Pilot.requests.length, 1);
    }

    function test_draftFollowsMainAndOverlayWithoutLosingItOnReopen() {
        const app = makeApp();
        const main = findChild(app.pageStack.currentPage, "input");
        main.text = "Draft before opening the overlay";
        const overlay = createTemporaryObject(overlayComponent, testCase);
        const field = findChild(overlay, "overlayInput");
        overlay.show();
        compare(field.text, main.text);
        field.text = "Still unfinished after switching views";
        compare(main.text, field.text);
        overlay.hide();
        overlay.show();
        compare(field.text, "Still unfinished after switching views");
        Pilot.busy = true;
        verify(!overlay.send(field.text));
        compare(field.text, "Still unfinished after switching views");
        compare(main.text, field.text);
        compare(Pilot.requests.length, 0);
        Pilot.busy = false;
        verify(overlay.send("A separate suggested question"));
        compare(field.text, "Still unfinished after switching views");
        compare(main.text, field.text);
        compare(Pilot.requests[0].text, "A separate suggested question");
        overlay.hide();
    }

    function test_acceptedFollowupRevealsItsTurnAfterReadingOlderAnswers() {
        const app = makeApp();
        const main = app.pageStack.currentPage;
        const list = findChild(main, "conversation");
        for (let i = 0; i < 12; ++i)
            Conversation.model.append(Conversation.entry({
                kind: "response",
                text: "Earlier answer " + i + ": " + "A complete paragraph to read. ".repeat(5)
            }));
        tryCompare(list, "count", 12);
        tryVerify(() => list.contentHeight > list.height);
        list.positionViewAtBeginning();
        list.follow = false;
        const previousPosition = list.contentY;
        Conversation.addCards({
            cards: [
                {
                    kind: "response",
                    text: "A background answer arrives"
                }
            ]
        });
        tryCompare(list, "count", 13);
        verify(waitForRendering(list));
        verify(!list.follow);
        compare(list.contentY, previousPosition);
        // AnswerCard's follow-up path uses this shared submission method.
        verify(Conversation.send("Explain the earlier answer"));
        tryVerify(() => list.follow && list.atYEnd);
        compare(Conversation.model.get(13).text, "Explain the earlier answer");
        compare(Pilot.requests.length, 1);
    }

    function test_disconnectedOverlayDoesNotOfferInactiveSuggestions() {
        Conversation.now = {
            on_screen: "Messages"
        };
        Pilot.connected = false;
        const overlay = createTemporaryObject(overlayComponent, testCase);
        overlay.show();
        const suggestions = findChild(overlay, "overlayQuickAsks");
        tryVerify(() => suggestions.children.some(item => item.hasOwnProperty("text")));
        for (const item of suggestions.children) {
            if (item.hasOwnProperty("text"))
                verify(!item.enabled);
        }
        verify(findChild(overlay, "overlayUnavailable").visible);
        overlay.hide();
    }

    function test_longSuggestionIsReadableAndKeyboardActivatesOnce() {
        const text = "<b>What is on my calendar next week, including the conference and follow-up meetings?</b>";
        const tile = createTemporaryObject(suggestionComponent, testCase, {
            text: text
        });
        const label = findChild(tile, "question");
        label.font.pixelSize = Theme.fontSizeHuge;
        tryVerify(() => label.lineCount > 2);
        verify(!label.truncated);
        compare(label.textFormat, Text.PlainText);
        compare(tile.Accessible.name, text);
        tryVerify(() => label.y + label.height <= tile.height);
        clicks.target = tile;
        clicks.clear();
        tile.forceActiveFocus();
        verify(findChild(tile, "focusFrame").showing);
        keyClick(Qt.Key_Return);
        compare(clicks.count, 1);
        tile.enabled = false;
        keyClick(Qt.Key_Return);
        compare(clicks.count, 1);
    }

    function test_answerExplainsSourcesAndCopiesLiteralTextFromKeyboard() {
        const text = "<b>This is literal answer text.</b>\n- Read the complete source before deciding.";
        const card = createTemporaryObject(answerComponent, testCase, {
            text: text,
            via: "phone",
            ms: 45,
            how: [
                {
                    kind: "app",
                    text: "<b>Read the selected calendar collection and its event titles.</b>"
                }
            ]
        });
        const how = findChild(card, "howToggle");
        how.forceActiveFocus();
        keyClick(Qt.Key_Return);
        verify(card.showHow);
        verify(findChild(card, "howSteps").visible);
        const copy = findChild(card, "copyAnswer");
        tryVerify(() => copy.mapToItem(card, 0, copy.height).y <= card.height);
        copy.forceActiveFocus();
        keyClick(Qt.Key_Space);
        compare(Clipboard.text, text);
    }

    function test_confirmationDetailsStayCompleteAndBusyCannotApprove() {
        const details = "<b>Send the complete message to the selected recipient.</b> " + "The recipient, account and proposed content must remain readable before approval. ".repeat(3);
        const card = createTemporaryObject(planComponent, testCase, {
            title: "Send a message",
            detail: details,
            outbound: true
        });
        // Every source label in this card uses plain text; locate the actual long detail.
        function findText(item, text) {
            if (item.text === text)
                return item;
            for (const child of item.children || []) {
                const found = findText(child, text);
                if (found)
                    return found;
            }
            return null;
        }
        const label = findText(card, details);
        verify(label);
        label.font.pixelSize = Theme.fontSizeLarge;
        tryVerify(() => label.lineCount > 3);
        verify(!label.truncated);
        compare(label.textFormat, Text.PlainText);
        const allow = findChild(card, "allowButton");
        const cancel = findChild(card, "cancelButton");
        tryVerify(() => allow.mapToItem(card, 0, allow.height).y <= card.height);
        verify(cancel.mapToItem(card, cancel.width, 0).x <= card.width);
        answers.target = card;
        answers.clear();
        Pilot.busy = true;
        verify(!allow.enabled);
        verify(!cancel.enabled);
        Pilot.busy = false;
        allow.forceActiveFocus();
        keyClick(Qt.Key_Return);
        compare(answers.count, 1);
        compare(answers.signalArguments[0][0], true);
    }
}
