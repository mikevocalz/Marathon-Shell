import QtQuick
import QtTest
import Sailfish.Silica 1.0
import Marathon.Silica 1.0
import MarathonOS.Services
import ".."
import "../MailLogic.js" as Logic

TestCase {
    id: tc

    name: "MailRouting"
    when: windowShown
    visible: true
    width: 540
    height: 1140

    readonly property string firstId: "message:0123456789abcdef0123456789abcdef"
    readonly property string secondId: "message:fedcba9876543210fedcba9876543210"

    Component {
        id: valueStub
        QtObject {
            property var value: ""
        }
    }
    Component {
        id: appComponent
        EmailApp {
            width: 540
            height: 1140
        }
    }

    function init() {
        MailService.reset();
        MailService.setAccount("Personal");
        MailService.accountModel.append({
            display: "Work"
        });
        MailService.accountList = MailService.accountList.concat([
            {
                id: "2",
                name: "Work",
                address: "work@example.com",
                folders: []
            }
        ]);
        const bodies = {};
        bodies[firstId] = {
            messageId: firstId,
            accountId: "2",
            accountName: "Work",
            accountAddress: "work@example.com",
            from: "Ada",
            subject: "Original message",
            bodyPlain: "Keep this exact item"
        };
        bodies[secondId] = {
            messageId: secondId,
            accountId: "1",
            accountName: "Personal",
            accountAddress: "me@example.com",
            from: "Ben",
            subject: "Newer message",
            bodyPlain: "A different item"
        };
        MailService.bodies = bodies;
    }

    function makeApp(props) {
        const store = createTemporaryObject(valueStub, tc);
        const app = createTemporaryObject(appComponent, tc, Object.assign({
            draftStore: store
        }, props || {}));
        verify(app);
        app.activate();
        tryVerify(() => app.pageStack.currentPage !== null && !app.pageStack.busy);
        return app;
    }

    function pushed(app, depth) {
        tryCompare(app.pageStack, "depth", depth);
        tryVerify(() => !app.pageStack.busy);
        return app.pageStack.currentPage;
    }

    function route(app, id, account) {
        app.handleRoute("message", {
            messageId: id,
            accountId: account
        });
    }

    function test_coldStartOpensExactOlderMessageInOtherAccount() {
        const app = makeApp({
            route: "message",
            routeParams: JSON.stringify({
                messageId: firstId,
                accountId: "2"
            })
        });
        const page = pushed(app, 2);
        tryCompare(page, "loadState", "ready");
        compare(page.messageId, firstId);
        compare(page.accountId, "2");
        compare(page.subject, "Original message");
        compare(page.msg.accountName, "Work");
        compare(MailService.currentAccountId, "1", "reading preserves the inbox context");
        route(app, firstId, "2");
        compare(app.pageStack.depth, 2, "reopening the selected message is idempotent");
    }

    function test_routePreservesComposeTextCursorAndAccount() {
        const app = makeApp();
        const compose = app.compose({
            draftKey: "new-preserved"
        });
        pushed(app, 2);
        const editor = findChild(compose, "bodyArea");
        editor.text = "Keep my unfinished draft";
        editor.cursorPosition = 7;
        route(app, firstId, "2");
        const page = pushed(app, 3);
        tryCompare(page, "loadState", "ready");
        compare(Logic.parseDrafts(app.draftStore.value)["new-preserved"].body, editor.text);
        compare(Logic.parseDrafts(app.draftStore.value)["new-preserved"].senderAccountId, "1");
        app.pageStack.pop(compose);
        compare(pushed(app, 2), compose);
        compare(editor.text, "Keep my unfinished draft");
        compare(editor.cursorPosition, 7);
        compare(compose.senderAccountId, "1");
    }

    function test_warmRouterSignalTargetsOnlyMail() {
        const app = makeApp();
        const target = {
            messageId: firstId,
            accountId: "2"
        };
        NavigationRouter.deepLinkRequested("calendar", "message", target);
        compare(app.pageStack.depth, 1);
        NavigationRouter.deepLinkRequested("email", "message", target);
        const page = pushed(app, 2);
        tryCompare(page, "loadState", "ready");
        compare(page.messageId, firstId);
        compare(page.accountId, "2");
    }

    function test_invalidOrLegacyNotificationCannotGuessAMessage() {
        const app = makeApp();
        for (const params of [null,
            {},
            [],
            {
                messageId: "7",
                accountId: "1"
            },
            {
                messageId: firstId,
                accountId: 1
            },
            {
                messageId: firstId,
                accountId: ""
            }
        ]) {
            app.handleRoute("message", params);
            compare(app.pageStack.depth, 1);
            compare(app.pendingRoute, null);
        }
        compare(MailService.called("requestMessage").length, 0);
        compare(MailService.called("markAsRead").length, 0);
    }

    function test_missingMessageShowsErrorWithoutReadingADecoy() {
        const app = makeApp();
        const bodies = Object.assign({}, MailService.bodies);
        delete bodies[firstId];
        MailService.bodies = bodies;
        route(app, firstId, "2");
        const page = pushed(app, 2);
        tryCompare(page, "loadState", "error");
        compare(page.loadError, "not-found");
        verify(findChild(page, "messageError").visible);
        verify(!findChild(page, "replyItem").visible);
        compare(MailService.called("markAsRead").length, 0);
        compare(page.bodyPlain, "");
    }

    function test_wrongAccountDoesNotDisplayOrReadTheMessage() {
        const app = makeApp();
        route(app, firstId, "1");
        const page = pushed(app, 2);
        tryCompare(page, "loadState", "error");
        compare(page.msg, {});
        compare(MailService.called("markAsRead").length, 0);
    }

    function test_lateReplyDoesNotReplaceTheCurrentMessage() {
        MailService.holdMessages = true;
        const app = makeApp();
        route(app, firstId, "2");
        const first = pushed(app, 2);
        route(app, secondId, "1");
        const second = pushed(app, 3);
        MailService.completeMessage(first.requestId, firstId, "2");
        compare(first.loadState, "ready");
        compare(second.loadState, "loading");
        compare(MailService.called("markAsRead").length, 0, "hidden message remains unread");
        MailService.completeMessage(second.requestId, secondId, "1");
        compare(second.subject, "Newer message");
    }

    function test_retryIgnoresPreviousRequestCompletion() {
        MailService.holdMessages = true;
        const app = makeApp();
        route(app, firstId, "2");
        const page = pushed(app, 2);
        const old = page.requestId;
        MailService.messageLoadFailed(old, "timeout");
        compare(page.loadState, "error");
        findChild(page, "retryMessageItem").clicked();
        verify(page.requestId !== old);
        MailService.messageLoadFailed(old, "not-found");
        compare(page.loadState, "loading");
        MailService.completeMessage(page.requestId, firstId, "2");
        compare(page.loadState, "ready");
    }

    function test_closedPageCannotReopenOnCompletion() {
        MailService.holdMessages = true;
        const app = makeApp();
        route(app, firstId, "2");
        const request = pushed(app, 2).requestId;
        app.pageStack.pop();
        pushed(app, 1);
        MailService.completeMessage(request, firstId, "2");
        compare(app.pageStack.depth, 1);
        compare(MailService.called("markAsRead").length, 0);
    }

    function test_removedOrReplacedSenderKeepsDraftAndBlocksSending() {
        const app = makeApp();
        const compose = app.compose({
            draftKey: "sender-removed",
            defaultTo: "ada@example.com",
            defaultBody: "Keep this draft"
        });
        pushed(app, 2);
        verify(compose.canAccept);
        MailService.accountList = [
            {
                id: "1",
                name: "Replacement",
                address: "other@example.com",
                folders: []
            }
        ];
        verify(!compose.canAccept);
        compose.persistDraft();
        compare(Logic.parseDrafts(app.draftStore.value)["sender-removed"].senderAccountAddress, "me@example.com");
        compare(MailService.called("send").length, 0);
    }

    function test_replyUsesSourceAccountAfterInboxAccountChanges() {
        const app = makeApp();
        route(app, firstId, "2");
        const page = pushed(app, 2);
        tryCompare(page, "loadState", "ready");
        findChild(page, "replyItem").clicked();
        const reply = pushed(app, 3);
        compare(reply.senderAccountId, "2");
        compare(findChild(reply, "fromItem").value, "Work");
        findChild(reply, "toField").text = "ada@example.com";
        MailService.currentAccountId = "1";
        reply.accept();
        pushed(app, 2);
        compare(MailService.sentAccounts, ["2"]);
    }
}
