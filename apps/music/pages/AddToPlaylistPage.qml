pragma ComponentBehavior: Bound

import QtQuick
import Sailfish.Silica 1.0
import Marathon.Silica 1.0
import "../Playlists.js" as Playlists

Page {
    id: page

    property var music
    property var track

    SilicaListView {
        id: view

        objectName: "addToPlaylistView"
        anchors.fill: parent
        header: PageHeader {
            title: qsTr("Add to playlist")
            description: page.track.title
        }
        model: page.music.playlists

        PullDownMenu {
            MenuItem {
                text: qsTr("New playlist")
                onClicked: pageStack.replace(Qt.resolvedUrl("NewPlaylistDialog.qml"), {
                    music: page.music,
                    track: page.track
                })
            }
        }

        delegate: SummaryListItem {
            id: item

            required property var modelData

            width: view.width
            text: modelData.name
            description: qsTr("%n song(s)", "", modelData.paths.length)
            onClicked: {
                page.music.savePlaylists(Playlists.addTrack(page.music.playlists, item.modelData.id, page.track.path));
                Notices.show(qsTr("Added to %1").arg(item.modelData.name));
                pageStack.pop();
            }
        }

        ViewPlaceholder {
            enabled: view.count === 0
            text: qsTr("No playlists")
            hintText: qsTr("Pull down to create one")
        }

        VerticalScrollDecorator {}
    }
}
