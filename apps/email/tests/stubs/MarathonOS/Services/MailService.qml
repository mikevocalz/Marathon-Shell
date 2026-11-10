pragma Singleton
import QtQuick

QtObject {
    id: svc

    property ListModel accountModel: ListModel {}
    property ListModel messageModel: ListModel {}
    property var accounts: accountModel
    property var messages: messageModel
    property string currentAccountId: ""
    property string currentAccountName: ""
    property string currentFolderId: ""
    property string currentFolderName: ""
    property int unreadCount: 0
    property int outboxCount: 0
    property bool online: true
    property var oauthProviders: []
    property var accountList: []
    property string syncState: "idle"
    property string lastError: ""
    property bool fail: false
    property var bodies: ({})
    property var calls: []
    property int nextRequest: 0
    property bool holdMessages: false
    property var sentAccounts: []

    signal oauthAuthUrlReady(string url)
    signal oauthLoginSucceeded(string accountId)
    signal oauthLoginFailed(string code, string message)
    signal sendSucceeded
    signal sendFailed(string reason)
    signal accountSetupSucceeded(string accountId)
    signal accountSetupFailed(string reason)
    signal attachmentSaved(string messageId, string location, string path)
    signal attachmentFailed(string messageId, string location)
    signal messageLoaded(string request, var message)
    signal messageLoadFailed(string request, string reason)

    function log(name, args) {
        calls = calls.concat([
            {
                name: name,
                args: args
            }
        ]);
    }

    function called(name) {
        return calls.filter(c => c.name === name);
    }

    function reset() {
        accountModel.clear();
        messageModel.clear();
        accounts = accountModel;
        messages = messageModel;
        currentAccountId = "";
        currentAccountName = "";
        currentFolderId = "";
        currentFolderName = "";
        unreadCount = 0;
        outboxCount = 0;
        online = true;
        oauthProviders = [];
        accountList = [];
        syncState = "idle";
        fail = false;
        bodies = {};
        calls = [];
        nextRequest = 0;
        holdMessages = false;
        sentAccounts = [];
    }

    function setAccount(name) {
        accountModel.append({
            display: name
        });
        accountList = [
            {
                id: "1",
                name: name,
                address: "me@example.com",
                folders: []
            }
        ];
        currentAccountName = name;
        currentFolderId = "10";
        currentFolderName = "Inbox";
        currentAccountId = "1";
    }

    function addMessage(id, from, subject, unread, extra) {
        messageModel.append(Object.assign({
            messageId: id,
            from: from,
            subject: subject,
            snippet: "Preview of " + subject,
            timestamp: "09:30",
            unread: unread,
            hasAttachment: false,
            tint: ""
        }, extra || {}));
        recount();
    }

    function recount() {
        let n = 0;
        for (let i = 0; i < messageModel.count; ++i)
            if (messageModel.get(i).unread)
                ++n;
        unreadCount = n;
    }

    function rowOf(id) {
        for (let i = 0; i < messageModel.count; ++i)
            if (String(messageModel.get(i).messageId) === String(id))
                return i;
        return -1;
    }

    function refresh() {
        log("refresh", []);
        return currentAccountId !== "";
    }

    function markAsRead(id, read) {
        log("markAsRead", [id, read]);
        const row = rowOf(id);
        if (row >= 0)
            messageModel.setProperty(row, "unread", !read);
        recount();
        return row >= 0;
    }

    function move(name, id) {
        log(name, [id]);
        if (fail)
            return false;
        const row = rowOf(id);
        if (row >= 0)
            messageModel.remove(row);
        recount();
        return row >= 0;
    }

    function moveToTrash(id) {
        return move("moveToTrash", id);
    }

    function moveToArchive(id) {
        return move("moveToArchive", id);
    }

    function refreshFolders(id) {
        log("refreshFolders", [id]);
    }

    function send(to, cc, bcc, subject, body, attachments) {
        log("send", [to, cc, bcc, subject, body, attachments]);
        sentAccounts = sentAccounts.concat([currentAccountId]);
        return !fail;
    }

    function saveAttachment(id, location) {
        log("saveAttachment", [id, location]);
        return !fail;
    }

    function openMessage(id) {
        return bodies[id] || {};
    }

    function requestMessage(id, accountId) {
        const request = String(++nextRequest);
        log("requestMessage", [request, id, accountId]);
        if (!holdMessages)
            Qt.callLater(completeMessage, request, id, accountId);
        return request;
    }

    function completeMessage(request, id, accountId) {
        const body = bodies[id];
        if (!body || (body.accountId && body.accountId !== accountId)) {
            messageLoadFailed(request, "not-found");
            return;
        }
        messageLoaded(request, Object.assign({
            messageId: id,
            accountId: accountId,
            accountName: currentAccountName,
            accountAddress: "me@example.com"
        }, body));
    }

    function addImapAccount(name, email, imapHost, imapPort, imapEnc, smtpHost, smtpPort, smtpEnc, username, password) {
        log("addImapAccount", [name, email, imapHost, imapPort, imapEnc, smtpHost, smtpPort, smtpEnc, username, password]);
        return !fail;
    }

    function cancelAccountSetup() {
        log("cancelAccountSetup", []);
    }

    function cancelOAuthLogin() {
        log("cancelOAuthLogin", []);
    }

    function checkOAuthProviders() {
        log("checkOAuthProviders", []);
    }

    function startOAuthLogin(provider) {
        log("startOAuthLogin", [provider]);
        return !fail;
    }
}
