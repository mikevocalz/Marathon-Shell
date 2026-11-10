pragma Singleton
import QtQml

QtObject {
    property var events: []
    property string state: "ready"
    function refresh() {
    }
}
