pragma Singleton
import QtQuick

QtObject {
    // Camera and media content need fixed contrast independent of ambience.
    readonly property color mediaBackground: "#000000"
    readonly property color mediaForeground: "#ffffff"
    readonly property color mediaOverlay: Qt.rgba(0, 0, 0, 0.6)

    // Keep covers and width estimates aligned with TerminalRenderer's fallback.
    readonly property string monospaceFamily: {
        const available = Qt.fontFamilies();
        for (const family of ["JetBrains Mono", "Cascadia Code", "Fira Code", "Roboto Mono", "Courier New"]) {
            if (available.indexOf(family) !== -1)
                return family;
        }
        return "Monospace";
    }
}
