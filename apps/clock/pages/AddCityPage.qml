pragma ComponentBehavior: Bound

import QtQuick
import Sailfish.Silica 1.0
import Marathon.Silica 1.0
import "../ClockLogic.js" as Logic

Page {
    id: root

    property var app
    property string query: ""

    SilicaListView {
        id: list

        objectName: "addCityList"
        anchors.fill: parent
        model: Logic.filterCities(Logic.knownCities, root.query)

        header: Column {
            width: list.width

            Connections {
                target: root
                function onStatusChanged() {
                    if (root.status === PageStatus.Active && root.Window.activeFocusItem === root)
                        citySearch.forceActiveFocus();
                }
            }

            PageHeader {
                title: qsTr("Add city")
            }
            SearchField {
                id: citySearch

                objectName: "citySearch"
                width: parent.width
                text: root.query
                placeholderText: qsTr("Search cities")
                onTextChanged: root.query = text
            }
        }

        ViewPlaceholder {
            enabled: list.count === 0
            text: qsTr("No cities found")
            hintText: qsTr("Try the country or a nearby city")
        }

        delegate: SummaryListItem {
            required property var modelData

            objectName: "addCityItem"
            text: modelData.name
            description: modelData.country || ""
            Accessible.name: qsTr("Add %1").arg(modelData.name)
            onClicked: {
                root.app.addCity(modelData);
                pageStack.pop();
            }
        }

        VerticalScrollDecorator {}
    }
}
