#include <QGuiApplication>
#include <QInputMethodEvent>
#include <QKeyEvent>
#include <QQmlComponent>
#include <QQmlEngine>
#include <QQuickItem>
#include <QQuickWindow>
#include <QTemporaryDir>
#include <QTest>
#include <qpa/qwindowsysteminterface.h>
#include <memory>

#include "managers/marathoninputmethodengine.h"
#include "marathon-shell-native/src/settings.cxxqt.h"

namespace {
    // An app can receive commits before its new surrounding text reaches the shell.
    class LaggingField : public QQuickItem {
      public:
        explicit LaggingField(QQuickItem *parent)
            : QQuickItem(parent) {
            setFlag(ItemAcceptsInputMethod);
        }

        QString  text;
        QString  reported;
        int      releases = 0;

        QVariant inputMethodQuery(Qt::InputMethodQuery query) const override {
            switch (query) {
                case Qt::ImEnabled: return true;
                case Qt::ImHints: return int(Qt::ImhNone);
                case Qt::ImSurroundingText: return reported;
                case Qt::ImCursorPosition: return int(reported.size());
                default: return QQuickItem::inputMethodQuery(query);
            }
        }

      protected:
        void inputMethodEvent(QInputMethodEvent *event) override {
            text += event->commitString();
            event->accept();
        }

        void keyPressEvent(QKeyEvent *event) override {
            if (event->key() == Qt::Key_Backspace)
                text.chop(1);
            else
                text += event->text();
            event->accept();
        }

        void keyReleaseEvent(QKeyEvent *event) override {
            ++releases;
            event->accept();
        }
    };
}

class TestHardwareCapitalization : public QObject {
    Q_OBJECT

    QTemporaryDir                              m_config;
    QQmlEngine                                 m_qml;
    std::unique_ptr<marathon::Settings>        m_settings;
    std::unique_ptr<MarathonInputMethodEngine> m_input;
    std::unique_ptr<QQuickWindow>              m_window;
    QQuickItem                                *m_field = nullptr;

    void send(QEvent::Type type, int key, const QString &text, quint32 scanCode = 30,
              bool repeat = false, Qt::KeyboardModifiers modifiers = Qt::NoModifier) {
        QWindowSystemInterface::handleExtendedKeyEvent(m_window.get(), type, key, modifiers,
                                                       scanCode, 0, 0, text, repeat);
        QWindowSystemInterface::flushWindowSystemEvents();
    }

    void type(int key, const QString &text, quint32 scanCode = 30) {
        send(QEvent::KeyPress, key, text, scanCode);
        send(QEvent::KeyRelease, key, text, scanCode);
    }

    QString fieldText() const {
        return m_field->property("text").toString();
    }

  private slots:
    void initTestCase() {
        QVERIFY(m_config.isValid());
        qputenv("XDG_CONFIG_HOME", m_config.path().toLocal8Bit());
        m_settings = std::make_unique<marathon::Settings>();
        m_input    = std::make_unique<MarathonInputMethodEngine>(m_settings.get());
    }

    void init() {
        m_settings->setKeyboardAutoCapitalize(true);
        m_window = std::make_unique<QQuickWindow>();
        m_window->resize(400, 200);
        QQmlComponent component(&m_qml);
        component.setData("import QtQuick\nTextEdit { width: 400; height: 200 }", QUrl());
        m_field = qobject_cast<QQuickItem *>(component.create());
        QVERIFY2(m_field, qPrintable(component.errorString()));
        m_field->setParent(m_window->contentItem());
        m_field->setParentItem(m_window->contentItem());
        m_window->show();
        m_window->requestActivate();
        m_field->forceActiveFocus();
        QTRY_COMPARE(QGuiApplication::focusObject(), m_field);
    }

    void cleanup() {
        m_window.reset();
        m_field = nullptr;
    }

    void firstLetterInAnEmptyField() {
        type(Qt::Key_A, QStringLiteral("a"));
        QCOMPARE(fieldText(), QStringLiteral("A"));
        type(Qt::Key_B, QStringLiteral("b"), 48);
        QCOMPARE(fieldText(), QStringLiteral("Ab"));
    }

    void syntheticInputStaysLiteral() {
        QKeyEvent press(QEvent::KeyPress, Qt::Key_A, Qt::NoModifier, QStringLiteral("a"));
        QCoreApplication::sendEvent(m_field, &press);
        QCOMPARE(fieldText(), QStringLiteral("a"));
        type(Qt::Key_B, QStringLiteral("b"), 48);
        QCOMPARE(fieldText(), QStringLiteral("ab"));
    }

    void backspaceRearmsAnEmptyField() {
        type(Qt::Key_A, QStringLiteral("a"));
        QCOMPARE(fieldText(), QStringLiteral("A"));
        type(Qt::Key_Backspace, QString(), 14);
        QCOMPARE(fieldText(), QString());
        type(Qt::Key_B, QStringLiteral("b"), 48);
        QCOMPARE(fieldText(), QStringLiteral("B"));
    }

    void preservesAUserEnteredLowercasePrefix() {
        m_settings->setKeyboardAutoCapitalize(false);
        type(Qt::Key_A, QStringLiteral("a"));
        QCOMPARE(fieldText(), QStringLiteral("a"));
        m_settings->setKeyboardAutoCapitalize(true);
        type(Qt::Key_B, QStringLiteral("b"), 48);
        QCOMPARE(fieldText(), QStringLiteral("ab"));
        type(Qt::Key_Backspace, QString(), 14);
        QCOMPARE(fieldText(), QStringLiteral("a"));
        type(Qt::Key_C, QStringLiteral("c"), 46);
        QCOMPARE(fieldText(), QStringLiteral("ac"));
    }

    void staleEmptyTextDoesNotCapitaliseTwice() {
        auto *lagging = new LaggingField(m_window->contentItem());
        lagging->forceActiveFocus();
        QTRY_COMPARE(QGuiApplication::focusObject(), lagging);
        type(Qt::Key_A, QStringLiteral("a"));
        QCOMPARE(lagging->text, QStringLiteral("A"));
        QVERIFY(lagging->reported.isEmpty());
        type(Qt::Key_B, QStringLiteral("b"), 48);
        QCOMPARE(lagging->text, QStringLiteral("Ab"));
        lagging->reported = lagging->text;
        type(Qt::Key_C, QStringLiteral("c"), 46);
        QCOMPARE(lagging->text, QStringLiteral("Abc"));
    }

    void heldCapitalDoesNotLeakRepeatsOrRelease() {
        auto *lagging = new LaggingField(m_window->contentItem());
        lagging->forceActiveFocus();
        QTRY_COMPARE(QGuiApplication::focusObject(), lagging);
        send(QEvent::KeyPress, Qt::Key_A, QStringLiteral("a"));
        send(QEvent::KeyRelease, Qt::Key_A, QStringLiteral("a"), 30, true);
        send(QEvent::KeyPress, Qt::Key_A, QStringLiteral("a"), 30, true);
        send(QEvent::KeyRelease, Qt::Key_A, QStringLiteral("a"));
        QCOMPARE(lagging->text, QStringLiteral("A"));
        QCOMPARE(lagging->releases, 0);
        type(Qt::Key_B, QStringLiteral("b"), 48);
        QCOMPARE(lagging->text, QStringLiteral("Ab"));
        QCOMPARE(lagging->releases, 1);
    }

    void changingFocusStartsANewCapitalization() {
        type(Qt::Key_A, QStringLiteral("a"));
        QCOMPARE(fieldText(), QStringLiteral("A"));
        auto *second = new LaggingField(m_window->contentItem());
        second->forceActiveFocus();
        QTRY_COMPARE(QGuiApplication::focusObject(), second);
        type(Qt::Key_B, QStringLiteral("b"), 48);
        QCOMPARE(second->text, QStringLiteral("B"));
        QCOMPARE(fieldText(), QStringLiteral("A"));
    }

    void fieldHintsKeepLiteralInput_data() {
        QTest::addColumn<int>("hints");
        QTest::newRow("no-uppercase") << int(Qt::ImhNoAutoUppercase);
        QTest::newRow("no-prediction") << int(Qt::ImhNoPredictiveText);
        QTest::newRow("sensitive") << int(Qt::ImhSensitiveData);
        QTest::newRow("password") << int(Qt::ImhHiddenText);
        QTest::newRow("url") << int(Qt::ImhUrlCharactersOnly);
        QTest::newRow("email") << int(Qt::ImhEmailCharactersOnly);
    }

    void fieldHintsKeepLiteralInput() {
        QFETCH(int, hints);
        m_field->setProperty("inputMethodHints", hints);
        type(Qt::Key_A, QStringLiteral("a"));
        QCOMPARE(fieldText(), QStringLiteral("a"));
    }
};

QTEST_MAIN(TestHardwareCapitalization)
#include "test_hardwarecapitalization.moc"
