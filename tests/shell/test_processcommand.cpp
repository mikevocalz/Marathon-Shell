#include "processcommand.h"

#include <QCoreApplication>
#include <QFile>
#include <QJsonArray>
#include <QJsonDocument>
#include <QSignalSpy>
#include <QTemporaryDir>
#include <QtTest>

#include <cstdio>

class ProcessCommandTest : public QObject {
    Q_OBJECT

  private slots:
    void runnerArgumentsRemainLiteral() {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        const QString program = directory.filePath(QStringLiteral("runner ; & \" ' $ ` > < |"));
        QVERIFY(QFile::link(QCoreApplication::applicationFilePath(), program));
        const QString     marker = directory.filePath(QStringLiteral("must-not-exist"));
        const QStringList values = {QString(),
                                    QStringLiteral("with spaces"),
                                    QStringLiteral("\"quoted\""),
                                    QStringLiteral("'single quotes'"),
                                    QStringLiteral("back\\slash"),
                                    QStringLiteral("; touch ") + marker,
                                    QStringLiteral("$(touch ") + marker + ')',
                                    QStringLiteral("`touch ") + marker + '`',
                                    QStringLiteral("left|right"),
                                    QStringLiteral("<input>output"),
                                    QStringLiteral("left&right"),
                                    QStringLiteral("line\nbreak"),
                                    QStringLiteral("route/naïve?x=1&y=2")};
        QStringList       arguments{QStringLiteral("--echo-arguments")};
        arguments.append(values);
        const marathon::ProcessCommand command{program, arguments};
        QProcess                       process;
        QSignalSpy                     started(&process, &QProcess::started);
        QSignalSpy                     errors(&process, &QProcess::errorOccurred);
        command.start(process);
        QVERIFY2(process.waitForFinished(5000), qPrintable(process.errorString()));
        QCOMPARE(started.count(), 1);
        QCOMPARE(errors.count(), 0);
        QCOMPARE(process.exitStatus(), QProcess::NormalExit);
        QCOMPARE(process.exitCode(), 0);
        const auto received = QJsonDocument::fromJson(process.readAllStandardOutput());
        QVERIFY(received.isArray());
        QCOMPARE(received.array(), QJsonArray::fromStringList(values));
        QVERIFY(!QFile::exists(marker));
    }

    void failedRunnerStartHasNoShellFallback() {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        const QString marker = directory.filePath(QStringLiteral("must-not-exist"));
        const marathon::ProcessCommand command{
            directory.filePath(QStringLiteral("missing ; touch ")) + marker,
            {QStringLiteral("--app-id"), QStringLiteral("org.example.App")}};
        QProcess   process;
        QSignalSpy started(&process, &QProcess::started);
        QSignalSpy errors(&process, &QProcess::errorOccurred);
        QSignalSpy finished(&process, &QProcess::finished);
        command.start(process);
        QVERIFY(!process.waitForStarted(5000));
        QCOMPARE(process.error(), QProcess::FailedToStart);
        QCOMPARE(process.state(), QProcess::NotRunning);
        QCOMPARE(started.count(), 0);
        QCOMPARE(errors.count(), 1);
        QCOMPARE(finished.count(), 0);
        QVERIFY(!process.errorString().isEmpty());
        QVERIFY(!QFile::exists(marker));
    }

    void desktopShellCompatibilityRemainsExplicit() {
        QTemporaryDir directory;
        QVERIFY(directory.isValid());
        const QString output = directory.filePath(QStringLiteral("desktop-output"));
        const auto    command =
            marathon::ProcessCommand::desktop(QStringLiteral("printf legacy > \"%1\"").arg(output));
        QCOMPARE(command.program, QStringLiteral("/bin/sh"));
        QProcess process;
        command.start(process);
        QVERIFY2(process.waitForFinished(5000), qPrintable(process.errorString()));
        QCOMPARE(process.exitCode(), 0);
        QFile file(output);
        QVERIFY(file.open(QIODevice::ReadOnly));
        QCOMPARE(file.readAll(), QByteArray("legacy"));
    }
};

int main(int argc, char **argv) {
    QCoreApplication app(argc, argv);
    if (app.arguments().value(1) == QStringLiteral("--echo-arguments")) {
        const auto bytes = QJsonDocument(QJsonArray::fromStringList(app.arguments().mid(2)))
                               .toJson(QJsonDocument::Compact);
        QFile      output;
        if (!output.open(stdout, QIODevice::WriteOnly) || output.write(bytes) != bytes.size() ||
            !output.flush())
            return 1;
        return 0;
    }
    ProcessCommandTest test;
    return QTest::qExec(&test, argc, argv);
}

#include "test_processcommand.moc"
