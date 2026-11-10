pragma ComponentBehavior: Bound

import QtQuick
import Sailfish.Silica 1.0
import Marathon.Silica 1.0
import "../Library.js" as Library

Page {
    id: page

    property var music
    // Unset lists every album; set lists that artist's.
    property var artist

    SilicaListView {
        id: view

        anchors.fill: parent
        header: PageHeader {
            title: page.artist !== undefined ? page.artist : qsTr("Albums")
        }
        model: Library.albums(page.music.tracks, page.artist)

        delegate: SummaryListItem {
            id: item

            required property var modelData

            width: view.width
            text: modelData.name
            description: (modelData.artist !== "" ? modelData.artist : qsTr("Various artists")) + " · " + (modelData.trackCount === 1 ? qsTr("1 song") : qsTr("%1 songs").arg(modelData.trackCount))
            onClicked: pageStack.push(Qt.resolvedUrl("SongsPage.qml"), {
                music: page.music,
                title: item.modelData.name,
                tracks: Library.albumTracks(page.music.tracks, item.modelData.name, page.artist)
            })
        }

        ViewPlaceholder {
            enabled: view.count === 0
            text: qsTr("No albums")
        }

        VerticalScrollDecorator {}
    }
}
