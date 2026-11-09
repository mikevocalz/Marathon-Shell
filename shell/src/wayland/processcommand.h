#pragma once

#include <QProcess>
#include <QString>
#include <QStringList>

namespace marathon {

    // A runner supplies these fields directly. No quoting, field splitting or
    // shell detection is applied between the sandbox policy and QProcess.
    struct ProcessCommand {
        QString     program;
        QStringList arguments;

        void        start(QProcess &process) const {
            process.setProgram(program);
            process.setArguments(arguments);
            process.start();
        }

        // Existing desktop Exec compatibility is an explicit, separate path.
        static ProcessCommand desktop(const QString     &command,
                                      const QStringList &overrideParts = {}) {
            const QStringList parts =
                overrideParts.isEmpty() ? QProcess::splitCommand(command) : overrideParts;
            const bool needsShell = parts.isEmpty() || command.contains('|') ||
                command.contains('&') || command.contains(';') || command.contains('>') ||
                command.contains('<');
            if (needsShell)
                return {QStringLiteral("/bin/sh"), {QStringLiteral("-c"), command}};
            return {parts.first(), parts.mid(1)};
        }
    };

} // namespace marathon
