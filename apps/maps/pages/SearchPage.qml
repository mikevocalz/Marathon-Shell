pragma ComponentBehavior: Bound
import QtQuick
import Sailfish.Silica 1.0
import Marathon.Silica 1.0

Page {
    id: root

    property var app
    property string query: ""

    function choose(place) {
        app.selectPlace(place);
        pageStack.replace(Qt.resolvedUrl("PlacePage.qml"), {
            app: root.app
        });
    }

    objectName: "searchPage"
    // A search asked for from outside runs at once.
    Component.onCompleted: {
        if (query.trim() !== "")
            app.search(query.trim());
    }
    onQueryChanged: {
        if (query.trim().length > 2) {
            searchTimer.restart();
            return;
        }
        searchTimer.stop();
        app.search("");
    }

    Timer {
        id: searchTimer

        interval: 500
        onTriggered: root.app.search(root.query.trim())
    }

    SilicaListView {
        id: view

        objectName: "resultsView"
        anchors.fill: parent
        readonly property bool showingRecent: root.query.trim() === ""

        model: showingRecent ? root.app.recentPlaces : root.app.searchResults

        header: Column {
            width: view.width

            Connections {
                target: root
                function onStatusChanged() {
                    if (root.status === PageStatus.Active)
                        searchField.forceActiveFocus();
                }
            }

            PageHeader {
                title: qsTr("Search")
            }
            SearchField {
                id: searchField

                objectName: "searchField"
                width: parent.width
                placeholderText: qsTr("Search places")
                text: root.query
                onTextChanged: root.query = text
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: {
                    searchTimer.stop();
                    root.app.search(root.query.trim());
                    focus = false;
                }
            }
            Item {
                width: parent.width
                height: Math.max(searchBusy.height, searchingLabel.height) + 2 * Theme.paddingMedium
                visible: root.app.searching

                BusyIndicator {
                    id: searchBusy

                    objectName: "searchBusy"
                    x: Theme.horizontalPageMargin
                    anchors.verticalCenter: parent.verticalCenter
                    size: BusyIndicatorSize.Small
                    running: parent.visible && root.status === PageStatus.Active
                }
                Label {
                    id: searchingLabel

                    anchors {
                        left: searchBusy.right
                        leftMargin: Theme.paddingMedium
                        right: parent.right
                        rightMargin: Theme.horizontalPageMargin
                        verticalCenter: parent.verticalCenter
                    }
                    text: view.count > 0 ? qsTr("Searching… Showing the places already loaded.") : qsTr("Searching…")
                    textFormat: Text.PlainText
                    wrapMode: Text.Wrap
                    color: Theme.secondaryHighlightColor
                    font.pixelSize: Theme.fontSizeSmall
                }
            }
            Label {
                objectName: "searchFailureNotice"
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * x
                visible: !view.showingRecent && view.count > 0 && root.app.searchError !== ""
                text: root.app.searchError + "\n" + qsTr("Showing the places already loaded. Pull down to try again.")
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
            }
            SectionHeader {
                objectName: "recentHeader"
                text: qsTr("Recent")
                visible: view.showingRecent && view.count > 0
            }
        }

        PullDownMenu {
            MenuItem {
                objectName: "retryItem"
                visible: root.app.searchError !== ""
                text: qsTr("Try again")
                onClicked: root.app.search(root.app.lastQuery)
            }
            MenuItem {
                text: qsTr("Show my location")
                onClicked: {
                    root.app.locateMe();
                    pageStack.pop();
                }
            }
        }

        ViewPlaceholder {
            objectName: "placeholder"
            enabled: !root.app.searching && view.count === 0
            text: root.app.searchError !== "" ? qsTr("Search didn't work") : root.app.lastQuery !== "" && !view.showingRecent ? qsTr("No places found") : qsTr("Find a place")
            hintText: root.app.searchError !== "" ? root.app.searchError : root.app.lastQuery !== "" && !view.showingRecent ? qsTr("Check the spelling, or try a street, city or postcode") : qsTr("Type an address, a place or a postcode")
        }

        delegate: SummaryListItem {
            id: item

            required property var modelData

            objectName: "placeResult"
            text: modelData.name
            description: modelData.address || ""
            iconSource: view.showingRecent ? "image://theme/icon-m-history" : "image://theme/icon-m-location"
            onClicked: root.choose(item.modelData)
        }

        VerticalScrollDecorator {}
    }
}
