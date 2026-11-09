#include <QGuiApplication>
#include <QQmlComponent>
#include <QQmlContext>
#include <QQmlEngine>
#include <QScreen>
#include <QScopedPointer>
#include <QSignalSpy>
#include <QTest>
#include <QWindow>

#include "managers/screenmetrics.h"

// Constants also reads motion tokens; their values do not affect display metrics.
class MotionTokens : public QObject {
    Q_OBJECT
  public:
    Q_INVOKABLE int durationFor(const QString &) const {
        return 0;
    }
};

class TestScreenMetrics : public QObject {
    Q_OBJECT

  private slots:
    void initTestCase() {
        const QString constants = QFINDTESTDATA("../../shell/qml/core/Constants.qml");
        QVERIFY(!constants.isEmpty());
        qmlRegisterSingletonType(QUrl::fromLocalFile(constants), "MarathonOS.Shell", 1, 0,
                                 "Constants");
    }

    void startsWithPrimaryScreen() {
        const QScreen *screen = QGuiApplication::primaryScreen();
        QVERIFY(screen);
        ScreenMetrics metrics;
        QCOMPARE(metrics.width(), screen->geometry().width());
        QCOMPARE(metrics.height(), screen->geometry().height());
        QCOMPARE(metrics.devicePixelRatio(), screen->devicePixelRatio());
    }

    void tracksWindowViewport() {
        QWindow window;
        window.resize(390, 844);
        ScreenMetrics metrics;
        metrics.attachToWindow(&window);
        QCOMPARE(metrics.width(), 390);
        QCOMPARE(metrics.height(), 844);
        QCOMPARE(metrics.dpi(), ScreenMetrics::computeDpi(window.screen()));
        QCOMPARE(metrics.devicePixelRatio(), window.devicePixelRatio());

        QSignalSpy changes(&metrics, &ScreenMetrics::metricsChanged);
        window.resize(844, 390);
        QTRY_COMPARE(metrics.width(), 844);
        QTRY_COMPARE(metrics.height(), 390);
        QVERIFY(!changes.isEmpty());
    }

    void reattachingDoesNotEmitUnchangedMetrics() {
        QWindow window;
        window.resize(390, 844);
        ScreenMetrics metrics;
        metrics.attachToWindow(&window);
        QSignalSpy changes(&metrics, &ScreenMetrics::metricsChanged);
        metrics.attachToWindow(&window);
        QCOMPARE(changes.size(), 0);
    }

    void switchingWindowsDisconnectsTheOldWindow() {
        QWindow first;
        QWindow second;
        first.resize(390, 844);
        second.resize(720, 720);
        ScreenMetrics metrics;
        metrics.attachToWindow(&first);
        metrics.attachToWindow(&second);
        QCOMPARE(metrics.width(), 720);
        QCOMPARE(metrics.height(), 720);

        QSignalSpy changes(&metrics, &ScreenMetrics::metricsChanged);
        first.resize(1920, 1080);
        QCoreApplication::processEvents();
        QCOMPARE(metrics.width(), 720);
        QCOMPARE(metrics.height(), 720);
        QCOMPARE(changes.size(), 0);

        second.resize(600, 900);
        QTRY_COMPARE(metrics.width(), 600);
        QTRY_COMPARE(metrics.height(), 900);
    }

    void detachingRestoresThePrimaryScreen() {
        const QScreen *screen = QGuiApplication::primaryScreen();
        QVERIFY(screen);
        QWindow window;
        window.resize(390, 844);
        ScreenMetrics metrics;
        metrics.attachToWindow(&window);
        metrics.attachToWindow(nullptr);
        QCOMPARE(metrics.width(), screen->geometry().width());
        QCOMPARE(metrics.height(), screen->geometry().height());
        QCOMPARE(metrics.devicePixelRatio(), screen->devicePixelRatio());

        QSignalSpy changes(&metrics, &ScreenMetrics::metricsChanged);
        window.resize(600, 900);
        QCoreApplication::processEvents();
        QCOMPARE(changes.size(), 0);
    }

    void destroyingTheWindowRestoresThePrimaryScreen() {
        const QScreen *screen = QGuiApplication::primaryScreen();
        QVERIFY(screen);
        ScreenMetrics           metrics;
        QScopedPointer<QWindow> window(new QWindow);
        window->resize(390, 844);
        metrics.attachToWindow(window.data());
        window.reset();
        QCOMPARE(metrics.width(), screen->geometry().width());
        QCOMPARE(metrics.height(), screen->geometry().height());
        QCOMPARE(metrics.dpi(), ScreenMetrics::computeDpi(QGuiApplication::primaryScreen()));
    }

    void legacySizeUpdatesPreserveNativeQmlBindings() {
        QWindow window;
        window.resize(390, 844);
        ScreenMetrics metrics;
        metrics.attachToWindow(&window);
        MotionTokens motion;
        QQmlEngine   engine;
        engine.rootContext()->setContextProperty("ScreenMetricsCpp", &metrics);
        engine.rootContext()->setContextProperty("MMotion", &motion);
        QQmlComponent component(&engine);
        component.setData("import QtQuick\nimport MarathonOS.Shell\n"
                          "QtObject {"
                          " property real w: Constants.screenWidth;"
                          " property real h: Constants.screenHeight;"
                          " property real dpi: Constants.dpi;"
                          " function legacySize() { Constants.updateScreenSize(123, 456, 400); }"
                          "}",
                          QUrl());
        QScopedPointer<QObject> wrapper(component.create());
        QVERIFY2(wrapper, qPrintable(component.errorString()));
        QCOMPARE(wrapper->property("w").toReal(), qreal(390));
        QCOMPARE(wrapper->property("h").toReal(), qreal(844));
        QVERIFY(QMetaObject::invokeMethod(wrapper.data(), "legacySize"));
        QCOMPARE(wrapper->property("dpi").toReal(), metrics.dpi());

        window.resize(720, 720);
        QTRY_COMPARE(wrapper->property("w").toReal(), qreal(720));
        QTRY_COMPARE(wrapper->property("h").toReal(), qreal(720));
    }

    void runnerWithoutNativeMetricsKeepsItsFallback() {
        MotionTokens motion;
        QQmlEngine   engine;
        engine.rootContext()->setContextProperty("MMotion", &motion);
        engine.rootContext()->setContextProperty("MARATHON_SCREEN_WIDTH", 540);
        engine.rootContext()->setContextProperty("MARATHON_SCREEN_HEIGHT", 780);
        engine.rootContext()->setContextProperty("MARATHON_DPI", 190.0);
        QQmlComponent component(&engine);
        component.setData("import QtQuick\nimport MarathonOS.Shell\n"
                          "QtObject {"
                          " property real w: Constants.screenWidth;"
                          " property real h: Constants.screenHeight;"
                          " property real dpi: Constants.dpi;"
                          " function legacySize() { Constants.updateScreenSize(600, 800, 200); }"
                          "}",
                          QUrl());
        QScopedPointer<QObject> wrapper(component.create());
        QVERIFY2(wrapper, qPrintable(component.errorString()));
        QCOMPARE(wrapper->property("w").toReal(), qreal(540));
        QCOMPARE(wrapper->property("h").toReal(), qreal(780));
        QCOMPARE(wrapper->property("dpi").toReal(), qreal(190));
        QVERIFY(QMetaObject::invokeMethod(wrapper.data(), "legacySize"));
        QCOMPARE(wrapper->property("w").toReal(), qreal(600));
        QCOMPARE(wrapper->property("h").toReal(), qreal(800));
        QCOMPARE(wrapper->property("dpi").toReal(), qreal(200));
    }
};

QTEST_MAIN(TestScreenMetrics)
#include "test_screenmetrics.moc"
