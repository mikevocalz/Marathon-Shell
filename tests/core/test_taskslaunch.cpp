#include <QDir>
#include <QFile>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QTest>
#include <QVariantMap>

#include <memory>

#include "marathon-shell-native/src/tasks.cxxqt.h"

class TestTasksLaunch : public QObject {
    Q_OBJECT

  private:
    QTemporaryDir          m_home;
    std::unique_ptr<Tasks> m_tasks;

    bool                   addDesktopEntry(const QString &appId) const {
        QFile entry(m_home.filePath(QStringLiteral("applications/%1.desktop").arg(appId)));
        const QByteArray contents = "[Desktop Entry]\nType=Application\nName=Launch test\n"
                                    "Exec=/bin/true\nIcon=application-x-executable\n";
        return entry.open(QIODevice::WriteOnly) && entry.write(contents) == contents.size();
    }

    QString requestLaunch(const QString &appId) {
        QSignalSpy requested(m_tasks.get(), &Tasks::spawnRequested);
        if (!m_tasks->launchApp(appId) || requested.size() != 1)
            return {};
        return requested.at(0).at(0).toString();
    }

    void addPlaceholder(const QString &appId) {
        m_tasks->registerApp(appId,
                             {{QStringLiteral("appName"), QStringLiteral("Launch test")},
                              {QStringLiteral("appType"), QStringLiteral("native")},
                              {QStringLiteral("isNative"), true},
                              {QStringLiteral("surfaceId"), -1}});
    }

  private slots:
    void initTestCase() {
        QVERIFY(m_home.isValid());
        QVERIFY(QDir().mkpath(m_home.filePath(QStringLiteral("applications"))));
        qputenv("XDG_DATA_HOME", m_home.path().toUtf8());
        qputenv("XDG_DATA_DIRS", m_home.path().toUtf8());
        m_tasks = std::make_unique<Tasks>();
    }

    void oldExitPreservesPendingReplacement_data() {
        QTest::addColumn<bool>("replacementStarts");
        QTest::newRow("replacement-starts") << true;
        QTest::newRow("replacement-fails") << false;
    }

    void oldExitPreservesPendingReplacement() {
        QFETCH(bool, replacementStarts);
        const QString appId  = QStringLiteral("org.marathon.Test.%1").arg(QTest::currentDataTag());
        const qint64  oldPid = replacementStarts ? 2'000'001'001 : 2'000'001'003;
        const qint64  newPid = oldPid + 1;
        const int     oldSurface = replacementStarts ? 101 : 103;
        const int     newSurface = oldSurface + 1;
        QVERIFY(addDesktopEntry(appId));
        const QString oldRequest = requestLaunch(appId);
        QVERIFY(!oldRequest.isEmpty());
        m_tasks->appLaunched(oldRequest, oldPid);
        QVERIFY(m_tasks->windowMapped(oldPid, oldPid, appId, QStringLiteral("Old window"), {},
                                      oldSurface, false));

        // The old window disappeared, but its process-exit callback is still
        // queued when the user opens the app again.
        m_tasks->windowDestroyed(oldSurface);
        const QString oldTask =
            m_tasks->getTaskByAppId(appId).value(QStringLiteral("id")).toString();
        QVERIFY(!oldTask.isEmpty());
        m_tasks->closeTask(oldTask);
        const QString newRequest = requestLaunch(appId);
        QVERIFY(!newRequest.isEmpty());
        QVERIFY(newRequest != oldRequest);
        addPlaceholder(appId);
        const int lifecycle = m_tasks->lifecycleState(appId);
        QVERIFY(lifecycle != 0);
        QVERIFY(m_tasks->isAppLaunching(appId));

        QSignalSpy exited(m_tasks.get(), &Tasks::appExited);
        QSignalSpy unregistered(m_tasks.get(), &Tasks::appUnregistered);
        QSignalSpy closed(m_tasks.get(), &Tasks::taskClosed);
        QSignalSpy failed(m_tasks.get(), &Tasks::appLaunchFailed);
        m_tasks->appClosed(oldPid);
        QVERIFY(!m_tasks->getTaskByAppId(appId).isEmpty());
        QCOMPARE(m_tasks->getTaskByAppId(appId).value(QStringLiteral("surfaceId")).toInt(), -1);
        QCOMPARE(m_tasks->lifecycleState(appId), lifecycle);
        QVERIFY(m_tasks->isAppLaunching(appId));
        QVERIFY(m_tasks->appIdForPid(oldPid).isEmpty());
        QCOMPARE(exited.size(), 0);
        QCOMPARE(unregistered.size(), 0);
        QCOMPARE(closed.size(), 0);

        if (replacementStarts) {
            m_tasks->appLaunched(newRequest, newPid);
            QVERIFY(m_tasks->windowMapped(newPid, newPid, appId, QStringLiteral("New window"), {},
                                          newSurface, false));
            m_tasks->appClosed(oldPid);
            m_tasks->appStartFailed(newRequest, QStringLiteral("stale failure"));
            QCOMPARE(m_tasks->pidForAppId(appId), newPid);
            QCOMPARE(m_tasks->getTaskByAppId(appId).value(QStringLiteral("surfaceId")).toInt(),
                     newSurface);
            QVERIFY(!m_tasks->isAppLaunching(appId));
            QCOMPARE(exited.size(), 0);
            QCOMPARE(unregistered.size(), 0);
            QCOMPARE(failed.size(), 0);
            m_tasks->windowDestroyed(newSurface);
            m_tasks->appClosed(newPid);
        } else {
            m_tasks->appStartFailed(newRequest, QStringLiteral("fixture start failure"));
            m_tasks->appClosed(oldPid);
            m_tasks->appStartFailed(newRequest, QStringLiteral("duplicate failure"));
            QCOMPARE(failed.size(), 1);
            QCOMPARE(failed.at(0).at(0).toString(), appId);
            QCOMPARE(failed.at(0).at(2).toString(), QStringLiteral("fixture start failure"));
            QVERIFY(!m_tasks->isAppLaunching(appId));
        }
        QVERIFY(m_tasks->getTaskByAppId(appId).isEmpty());
        QCOMPARE(m_tasks->lifecycleState(appId), 0);
        QCOMPARE(exited.size(), 1);
        QCOMPARE(unregistered.size(), 1);
        QCOMPARE(closed.size(), 1);
    }

    void unrelatedPendingLaunchDoesNotKeepAnExitedApp() {
        const QString oldApp   = QStringLiteral("org.marathon.Test.old");
        const QString otherApp = QStringLiteral("org.marathon.Test.other");
        const qint64  oldPid   = 2'000'001'005;
        QVERIFY(addDesktopEntry(oldApp));
        QVERIFY(addDesktopEntry(otherApp));
        const QString oldRequest = requestLaunch(oldApp);
        QVERIFY(!oldRequest.isEmpty());
        m_tasks->appLaunched(oldRequest, oldPid);
        addPlaceholder(oldApp);
        const QString otherRequest = requestLaunch(otherApp);
        QVERIFY(!otherRequest.isEmpty());
        addPlaceholder(otherApp);

        QSignalSpy exited(m_tasks.get(), &Tasks::appExited);
        QSignalSpy unregistered(m_tasks.get(), &Tasks::appUnregistered);
        m_tasks->appClosed(oldPid);
        QVERIFY(m_tasks->getTaskByAppId(oldApp).isEmpty());
        QCOMPARE(m_tasks->lifecycleState(oldApp), 0);
        QVERIFY(!m_tasks->getTaskByAppId(otherApp).isEmpty());
        QVERIFY(m_tasks->isAppLaunching(otherApp));
        QCOMPARE(exited.size(), 1);
        QCOMPARE(exited.at(0).at(0).toString(), oldApp);
        QCOMPARE(unregistered.size(), 1);
        QCOMPARE(unregistered.at(0).at(0).toString(), oldApp);
        m_tasks->appStartFailed(otherRequest, QStringLiteral("fixture cleanup"));
    }
};

QTEST_GUILESS_MAIN(TestTasksLaunch)
#include "test_taskslaunch.moc"
