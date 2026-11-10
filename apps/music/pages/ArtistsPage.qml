pragma ComponentBehavior: Bound

import QtQuick
import Sailfish.Silica 1.0
import Marathon.Silica 1.0
import "../Library.js" as Library

Page {
    id: page

    property var music

    SilicaListView {
        id: view

        anchors.fill: parent
        header: PageHeader {
            title: qsTr("Artists")
        }
        model: Library.artists(page.music.tracks)

        delegate: SummaryListItem {
            id: item

            required property var modelData

            width: view.width
            text: modelData.name
            description: (modelData.albumCount === 1 ? qsTr("1 album") : qsTr("%1 albums").arg(modelData.albumCount)) + " · " + (modelData.trackCount === 1 ? qsTr("1 song") : qsTr("%1 songs").arg(modelData.trackCount))
            onClicked: pageStack.push(Qt.resolvedUrl("AlbumsPage.qml"), {
                music: page.music,
                artist: item.modelData.name
            })
        }

        ViewPlaceholder {
            enabled: view.count === 0
            text: qsTr("No artists")
        }

        VerticalScrollDecorator {}
    }
}
