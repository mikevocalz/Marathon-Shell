pragma Singleton
import QtQuick

QtObject {
    property string searchText: ""
    property string lastError: ""
    property bool busy: false
    property int refreshes: 0
    readonly property ListModel catalogueModel: ListModel {}

    function refresh() {
        refreshes++;
    }
}
