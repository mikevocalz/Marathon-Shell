#include <QDBusArgument>
#include <QDBusConnection>
#include <QDBusContext>
#include <QDBusError>
#include <QDBusMessage>
#include <QDBusMetaType>
#include <QMetaObject>
#include <QQueue>
#include <QSignalSpy>
#include <QSet>
#include <QTest>
#include <QVariant>

#include <memory>
#include <utility>

#include "marathon-app-native/src/store.cxxqt.h"

struct CleanupItem {
    QString id;
    QString detail;
};
using CleanupItems  = QList<CleanupItem>;
using RemovableApps = QMap<QString, bool>;
Q_DECLARE_METATYPE(CleanupItem)
Q_DECLARE_METATYPE(CleanupItems)
Q_DECLARE_METATYPE(RemovableApps)

QDBusArgument &operator<<(QDBusArgument &argument, const CleanupItem &item) {
    argument.beginStructure();
    argument << item.id << item.detail;
    argument.endStructure();
    return argument;
}

const QDBusArgument &operator>>(const QDBusArgument &argument, CleanupItem &item) {
    argument.beginStructure();
    argument >> item.id >> item.detail;
    argument.endStructure();
    return argument;
}

// The real client crosses the private session bus. Tests decide when a
// provider completes, so stale replies and a responsive Qt owner are observable.
class HeldAppStore : public QObject, protected QDBusContext {
    Q_OBJECT
    Q_CLASSINFO("D-Bus Interface", "org.marathonos.Shell.AppStore1")

  public:
    explicit HeldAppStore(QDBusConnection bus)
        : m_bus(std::move(bus)) {}

    int calls() const {
        return m_calls;
    }

    bool hasPending() const {
        return !m_requests.isEmpty();
    }

    void resetCount() {
        m_calls                 = 0;
        m_legacyCapabilityCalls = 0;
        m_capabilityBatches.clear();
    }

    QList<QStringList> capabilityBatches() const {
        return m_capabilityBatches;
    }

    int legacyCapabilityCalls() const {
        return m_legacyCapabilityCalls;
    }

    bool replyNext(const CleanupItems &items) {
        if (m_requests.isEmpty())
            return false;
        return m_bus.send(
            m_requests.dequeue().createReply(QVariantList{QVariant::fromValue(items)}));
    }

    bool failNext() {
        if (m_requests.isEmpty())
            return false;
        return m_bus.send(m_requests.dequeue().createErrorReply(
            QDBusError::AccessDenied, QStringLiteral("Cleanup state is unavailable")));
    }

    bool replyMalformed() {
        if (m_requests.isEmpty())
            return false;
        return m_bus.send(m_requests.dequeue().createReply(
            QVariantList{QStringLiteral("not an array of (id, detail) pairs")}));
    }

    bool replyCapabilities(const RemovableApps &items) {
        if (m_requests.isEmpty())
            return false;
        return m_bus.send(
            m_requests.dequeue().createReply(QVariantList{QVariant::fromValue(items)}));
    }

  public slots:
    CleanupItems PendingUninstalls() {
        holdRequest();
        return {};
    }

    CleanupItems FlatpakApps() {
        holdRequest();
        return {};
    }

    RemovableApps UninstallCapabilities(const QStringList &appIds) {
        m_capabilityBatches.append(appIds);
        holdRequest();
        return {};
    }

    bool CanUninstall(const QString &) {
        ++m_legacyCapabilityCalls;
        ++m_calls;
        return false;
    }

  private:
    void holdRequest() {
        setDelayedReply(true);
        m_requests.enqueue(message());
        ++m_calls;
    }

    QDBusConnection      m_bus;
    QQueue<QDBusMessage> m_requests;
    QList<QStringList>   m_capabilityBatches;
    int                  m_legacyCapabilityCalls = 0;
    int                  m_calls                 = 0;
};

using marathon::platform::AppInstaller;

class TestAppInstaller : public QObject {
    Q_OBJECT

  private slots:
    void initTestCase() {
        qDBusRegisterMetaType<CleanupItem>();
        qDBusRegisterMetaType<CleanupItems>();
        qDBusRegisterMetaType<RemovableApps>();
        QVERIFY2(m_bus.isConnected(), qPrintable(m_bus.lastError().message()));
        QVERIFY2(m_bus.registerObject(QStringLiteral("/org/marathonos/Shell/AppStore"), &m_store,
                                      QDBusConnection::ExportAllSlots),
                 qPrintable(m_bus.lastError().message()));
        QVERIFY2(m_bus.registerService(QStringLiteral("org.marathonos.Shell")),
                 qPrintable(m_bus.lastError().message()));
    }

    void cleanupTestCase() {
        m_bus.unregisterObject(QStringLiteral("/org/marathonos/Shell/AppStore"));
        QVERIFY(m_bus.unregisterService(QStringLiteral("org.marathonos.Shell")));
    }

    void init() {
        QVERIFY(!m_store.hasPending());
        m_store.resetCount();
    }

    void initialSnapshotIsLocalAndUnrequested() {
        AppInstaller installer;
        QSignalSpy   changed(&installer, &AppInstaller::pendingUninstallsChanged);
        QVERIFY(changed.isValid());
        const QVariantMap state = installer.pendingUninstalls();
        QCOMPARE(state.value(QStringLiteral("available")).metaType(), QMetaType(QMetaType::Bool));
        QCOMPARE(state.value(QStringLiteral("loading")).metaType(), QMetaType(QMetaType::Bool));
        QCOMPARE(state.value(QStringLiteral("items")).metaType(),
                 QMetaType(QMetaType::QVariantList));
        QCOMPARE(state.value(QStringLiteral("error")).metaType(), QMetaType(QMetaType::QString));
        QVERIFY(!state.value(QStringLiteral("available")).toBool());
        QVERIFY(!state.value(QStringLiteral("loading")).toBool());
        QVERIFY(state.value(QStringLiteral("items")).toList().isEmpty());
        QVERIFY(state.value(QStringLiteral("error")).toString().isEmpty());
        QCOMPARE(installer.pendingUninstalls(), state);
        QVERIFY(installer.flatpakApps().isEmpty());
        QVERIFY(!installer.flatpakAppsState().value(QStringLiteral("available")).toBool());
        QVERIFY(!installer.canUninstall(QStringLiteral("notes")));
        QVERIFY(!installer.uninstallCapabilities().value(QStringLiteral("available")).toBool());
        QCOMPARE(changed.count(), 0);
        QCOMPARE(m_store.calls(), 0);
    }

    void heldProviderDoesNotBlockOwnerAndPublishesActualReply() {
        AppInstaller installer;
        QSignalSpy   changed(&installer, &AppInstaller::pendingUninstallsChanged);
        installer.refreshPendingUninstalls();
        QVERIFY(installer.pendingUninstalls().value(QStringLiteral("loading")).toBool());
        QTRY_COMPARE(m_store.calls(), 1);

        bool ownerEventDelivered = false;
        QVERIFY(QMetaObject::invokeMethod(
            &installer, [&ownerEventDelivered]() { ownerEventDelivered = true; },
            Qt::QueuedConnection));
        QTRY_VERIFY(ownerEventDelivered);
        QVERIFY(m_store.hasPending());
        const QVariantMap loading = installer.pendingUninstalls();
        QVERIFY(!loading.value(QStringLiteral("available")).toBool());
        QVERIFY(loading.value(QStringLiteral("loading")).toBool());
        QVERIFY(loading.value(QStringLiteral("items")).toList().isEmpty());
        QVERIFY(changed.count() >= 1);
        const qsizetype beforeReply = changed.count();

        QVERIFY(m_store.replyNext({{QStringLiteral("notes"), QStringLiteral("cache retained")}}));
        QTRY_VERIFY(installer.pendingUninstalls().value(QStringLiteral("available")).toBool());
        const QVariantMap ready = installer.pendingUninstalls();
        QVERIFY(!ready.value(QStringLiteral("loading")).toBool());
        QVERIFY(ready.value(QStringLiteral("error")).toString().isEmpty());
        QCOMPARE(ready.value(QStringLiteral("items")).toList(),
                 QVariantList(
                     {QVariantMap{{QStringLiteral("id"), QStringLiteral("notes")},
                                  {QStringLiteral("detail"), QStringLiteral("cache retained")}}}));
        QVERIFY(changed.count() > beforeReply);
        QCOMPARE(m_store.calls(), 1);
    }

    void failedRefreshRetainsSnapshotAndCanRecover_data() {
        QTest::addColumn<bool>("malformed");
        QTest::newRow("provider-error") << false;
        QTest::newRow("wrong-wire-signature") << true;
    }

    void failedRefreshRetainsSnapshotAndCanRecover() {
        QFETCH(bool, malformed);
        AppInstaller installer;
        QSignalSpy   changed(&installer, &AppInstaller::pendingUninstallsChanged);
        installer.refreshPendingUninstalls();
        QTRY_COMPARE(m_store.calls(), 1);
        QVERIFY(m_store.replyNext({{QStringLiteral("notes"), QStringLiteral("retry cleanup")}}));
        QTRY_VERIFY(installer.pendingUninstalls().value(QStringLiteral("available")).toBool());
        const QVariantList saved =
            installer.pendingUninstalls().value(QStringLiteral("items")).toList();

        installer.refreshPendingUninstalls();
        QTRY_COMPARE(m_store.calls(), 2);
        QVERIFY(malformed ? m_store.replyMalformed() : m_store.failNext());
        QTRY_VERIFY(!installer.pendingUninstalls().value(QStringLiteral("loading")).toBool());
        const QVariantMap failed = installer.pendingUninstalls();
        QVERIFY(!failed.value(QStringLiteral("available")).toBool());
        QVERIFY(!failed.value(QStringLiteral("error")).toString().isEmpty());
        QCOMPARE(failed.value(QStringLiteral("items")).toList(), saved);

        const qsizetype beforeRetry = changed.count();
        installer.refreshPendingUninstalls();
        QTRY_COMPARE(m_store.calls(), 3);
        QVERIFY(m_store.replyNext({}));
        QTRY_VERIFY(installer.pendingUninstalls().value(QStringLiteral("available")).toBool());
        const QVariantMap recovered = installer.pendingUninstalls();
        QVERIFY(!recovered.value(QStringLiteral("loading")).toBool());
        QVERIFY(recovered.value(QStringLiteral("error")).toString().isEmpty());
        QVERIFY(recovered.value(QStringLiteral("items")).toList().isEmpty());
        QVERIFY(changed.count() > beforeRetry);
    }

    void refreshDuringReadDiscardsOldResultAndCoalesces_data() {
        QTest::addColumn<bool>("staleFailure");
        QTest::newRow("stale-success") << false;
        QTest::newRow("stale-error") << true;
    }

    void refreshDuringReadDiscardsOldResultAndCoalesces() {
        QFETCH(bool, staleFailure);
        AppInstaller       installer;
        QList<QVariantMap> observations;
        connect(
            &installer, &AppInstaller::pendingUninstallsChanged, &installer,
            [&installer, &observations]() { observations.append(installer.pendingUninstalls()); });
        installer.refreshPendingUninstalls();
        QTRY_COMPARE(m_store.calls(), 1);
        installer.refreshPendingUninstalls();
        installer.refreshPendingUninstalls();
        installer.refreshPendingUninstalls();
        QVERIFY(staleFailure ? m_store.failNext() :
                               m_store.replyNext(
                                   {{QStringLiteral("obsolete"), QStringLiteral("old snapshot")}}));
        QTRY_COMPARE(m_store.calls(), 2);
        const QVariantMap waiting = installer.pendingUninstalls();
        QVERIFY(waiting.value(QStringLiteral("loading")).toBool());
        QVERIFY(!waiting.value(QStringLiteral("available")).toBool());
        QVERIFY(waiting.value(QStringLiteral("items")).toList().isEmpty());
        QVERIFY(waiting.value(QStringLiteral("error")).toString().isEmpty());

        QVERIFY(
            m_store.replyNext({{QStringLiteral("current"), QStringLiteral("current snapshot")}}));
        QTRY_VERIFY(installer.pendingUninstalls().value(QStringLiteral("available")).toBool());
        QCOMPARE(m_store.calls(), 2);
        QVERIFY(!m_store.hasPending());
        const QVariantList finalItems =
            installer.pendingUninstalls().value(QStringLiteral("items")).toList();
        QCOMPARE(finalItems.size(), 1);
        QCOMPARE(finalItems.first().toMap().value(QStringLiteral("id")).toString(),
                 QStringLiteral("current"));
        for (const QVariantMap &state : std::as_const(observations)) {
            QVERIFY(state.value(QStringLiteral("error")).toString().isEmpty());
            for (const QVariant &item : state.value(QStringLiteral("items")).toList())
                QVERIFY(item.toMap().value(QStringLiteral("id")).toString() !=
                        QStringLiteral("obsolete"));
        }
    }

    void stalledProviderTimesOutAndLateReplyCannotReplaceRetry() {
        AppInstaller installer;
        installer.refreshPendingUninstalls();
        QTRY_COMPARE(m_store.calls(), 1);
        QTRY_VERIFY_WITH_TIMEOUT(
            !installer.pendingUninstalls().value(QStringLiteral("loading")).toBool(), 20000);
        const QVariantMap failed = installer.pendingUninstalls();
        QVERIFY(!failed.value(QStringLiteral("available")).toBool());
        QVERIFY(!failed.value(QStringLiteral("error")).toString().isEmpty());

        installer.refreshPendingUninstalls();
        QTRY_COMPARE(m_store.calls(), 2);
        QVERIFY(m_store.replyNext({{QStringLiteral("expired"), QStringLiteral("late result")}}));
        QVERIFY(m_store.replyNext({{QStringLiteral("retry"), QStringLiteral("current result")}}));
        QTRY_VERIFY(installer.pendingUninstalls().value(QStringLiteral("available")).toBool());
        const QVariantList items =
            installer.pendingUninstalls().value(QStringLiteral("items")).toList();
        QCOMPARE(items.size(), 1);
        QCOMPARE(items.first().toMap().value(QStringLiteral("id")).toString(),
                 QStringLiteral("retry"));
    }

    void destroyingClientDropsItsCompletionAndReplacementStillWorks() {
        auto       installer = std::make_unique<AppInstaller>();
        QSignalSpy destroyed(installer.get(), &QObject::destroyed);
        installer->refreshPendingUninstalls();
        QTRY_COMPARE(m_store.calls(), 1);
        installer.reset();
        QCOMPARE(destroyed.count(), 1);

        AppInstaller replacement;
        QSignalSpy   changed(&replacement, &AppInstaller::pendingUninstallsChanged);
        replacement.refreshPendingUninstalls();
        QTRY_COMPARE(m_store.calls(), 2);
        QVERIFY(m_store.replyNext({{QStringLiteral("destroyed"), QStringLiteral("old client")}}));
        QVERIFY(m_store.replyNext({{QStringLiteral("replacement"), QStringLiteral("new client")}}));
        QTRY_VERIFY(replacement.pendingUninstalls().value(QStringLiteral("available")).toBool());
        const QVariantList items =
            replacement.pendingUninstalls().value(QStringLiteral("items")).toList();
        QCOMPARE(items.size(), 1);
        QCOMPARE(items.first().toMap().value(QStringLiteral("id")).toString(),
                 QStringLiteral("replacement"));
        QVERIFY(changed.count() >= 2);
        QVERIFY(!m_store.hasPending());
    }

    void flatpakCatalogueKeepsItsCacheOnFailureAndAcceptsEmptyRecovery() {
        AppInstaller installer;
        QSignalSpy   changed(&installer, &AppInstaller::flatpakAppsChanged);
        installer.refreshFlatpakApps();
        QTRY_COMPARE(m_store.calls(), 1);
        QVERIFY(installer.flatpakAppsState().value(QStringLiteral("loading")).toBool());
        QVERIFY(installer.flatpakApps().isEmpty());
        QVERIFY(
            m_store.replyNext({{QStringLiteral("org.example.Reader"), QStringLiteral("Reader")}}));
        QTRY_VERIFY(installer.flatpakAppsState().value(QStringLiteral("available")).toBool());
        const QVariantList saved = installer.flatpakApps();
        QCOMPARE(
            saved,
            QVariantList({QVariantMap{{QStringLiteral("id"), QStringLiteral("org.example.Reader")},
                                      {QStringLiteral("name"), QStringLiteral("Reader")}}}));

        installer.refreshFlatpakApps();
        QTRY_COMPARE(m_store.calls(), 2);
        QVERIFY(m_store.failNext());
        QTRY_VERIFY(!installer.flatpakAppsState().value(QStringLiteral("loading")).toBool());
        const QVariantMap failed = installer.flatpakAppsState();
        QVERIFY(!failed.value(QStringLiteral("available")).toBool());
        QVERIFY(!failed.value(QStringLiteral("error")).toString().isEmpty());
        QCOMPARE(failed.value(QStringLiteral("items")).toList(), saved);
        QCOMPARE(installer.flatpakApps(), saved);

        installer.refreshFlatpakApps();
        QTRY_COMPARE(m_store.calls(), 3);
        QVERIFY(m_store.replyNext({}));
        QTRY_VERIFY(installer.flatpakAppsState().value(QStringLiteral("available")).toBool());
        QVERIFY(installer.flatpakApps().isEmpty());
        QVERIFY(installer.flatpakAppsState().value(QStringLiteral("error")).toString().isEmpty());
        QVERIFY(changed.count() >= 6);
    }

    void capabilitiesUseLatestIdSetAndRecoverFromFailure() {
        AppInstaller  installer;
        QSignalSpy    changed(&installer, &AppInstaller::uninstallCapabilitiesChanged);
        QStringList   latestIds;
        RemovableApps latest;
        for (int i = 0; i < 64; ++i) {
            const QString id = QStringLiteral("app.%1").arg(i, 3, 10, QChar('0'));
            latestIds.append(id);
            latest.insert(id, i % 2 == 0);
        }
        installer.refreshUninstallCapabilities(QStringList{QStringLiteral("notes")});
        QTRY_COMPARE(m_store.calls(), 1);
        QVERIFY(installer.uninstallCapabilities().value(QStringLiteral("loading")).toBool());
        QVERIFY(!installer.canUninstall(QStringLiteral("notes")));
        installer.refreshUninstallCapabilities(QStringList{QStringLiteral("music")});
        installer.refreshUninstallCapabilities(latestIds);
        QVERIFY(m_store.replyCapabilities({{QStringLiteral("notes"), true}}));

        QTRY_COMPARE(m_store.calls(), 2);
        QVERIFY(!installer.canUninstall(QStringLiteral("notes")));
        QVERIFY(!installer.uninstallCapabilities().value(QStringLiteral("available")).toBool());
        const QList<QStringList> batches = m_store.capabilityBatches();
        QCOMPARE(batches.size(), 2);
        QCOMPARE(batches.first(), QStringList{QStringLiteral("notes")});
        QCOMPARE(batches.last().size(), 64);
        QCOMPARE(QSet<QString>(batches.last().cbegin(), batches.last().cend()),
                 QSet<QString>(latestIds.cbegin(), latestIds.cend()));
        QVERIFY(m_store.replyCapabilities(latest));
        QTRY_VERIFY(installer.uninstallCapabilities().value(QStringLiteral("available")).toBool());
        const QVariantMap items =
            installer.uninstallCapabilities().value(QStringLiteral("items")).toMap();
        QCOMPARE(items.size(), 64);
        QVERIFY(!items.contains(QStringLiteral("notes")));
        QVERIFY(!items.contains(QStringLiteral("music")));
        for (auto it = latest.cbegin(); it != latest.cend(); ++it)
            QCOMPARE(installer.canUninstall(it.key()), it.value());
        QCOMPARE(m_store.calls(), 2);
        QCOMPARE(m_store.legacyCapabilityCalls(), 0);

        installer.refreshUninstallCapabilities(QStringList{latestIds.first()});
        QTRY_COMPARE(m_store.calls(), 3);
        QVERIFY(m_store.failNext());
        QTRY_VERIFY(!installer.uninstallCapabilities().value(QStringLiteral("loading")).toBool());
        QVERIFY(!installer.uninstallCapabilities().value(QStringLiteral("available")).toBool());
        QVERIFY(
            !installer.uninstallCapabilities().value(QStringLiteral("error")).toString().isEmpty());
        QCOMPARE(installer.uninstallCapabilities().value(QStringLiteral("items")).toMap(), items);

        installer.refreshUninstallCapabilities(QStringList{});
        QTRY_COMPARE(m_store.calls(), 4);
        QVERIFY(m_store.replyCapabilities({}));
        QTRY_VERIFY(installer.uninstallCapabilities().value(QStringLiteral("available")).toBool());
        QVERIFY(installer.uninstallCapabilities().value(QStringLiteral("items")).toMap().isEmpty());
        QVERIFY(!installer.canUninstall(latestIds.first()));
        QVERIFY(
            installer.uninstallCapabilities().value(QStringLiteral("error")).toString().isEmpty());
        QCOMPARE(m_store.calls(), 4);
        QCOMPARE(m_store.legacyCapabilityCalls(), 0);
        QVERIFY(changed.count() >= 6);
    }

  private:
    QDBusConnection m_bus = QDBusConnection::sessionBus();
    HeldAppStore    m_store{m_bus};
};

QTEST_GUILESS_MAIN(TestAppInstaller)
#include "test_appinstaller.moc"
