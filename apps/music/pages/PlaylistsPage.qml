pragma ComponentBehavior: Bound

import QtQuick
import Sailfish.Silica 1.0
import Marathon.Silica 1.0
import "../Playlists.js" as Playlists

Page {
    id: page

    property var music

    SilicaListView {
        id: view

        objectName: "playlistsView"
        anchors.fill: parent
        header: PageHeader {
            title: qsTr("Playlists")
        }
        model: page.music.playlists

        PullDownMenu {
            MenuItem {
                text: qsTr("New playlist")
                onClicked: pageStack.push(Qt.resolvedUrl("NewPlaylistDialog.qml"), {
                    music: page.music
                })
            }
        }

        delegate: SummaryListItem {
            id: item

            required property var modelData

            width: view.width
            text: modelData.name
            description: modelData.paths.length === 1 ? qsTr("1 song") : qsTr("%1 songs").arg(modelData.paths.length)
            onClicked: pageStack.push(Qt.resolvedUrl("SongsPage.qml"), {
                music: page.music,
                title: item.modelData.name,
                playlistId: item.modelData.id
            })
            menu: ContextMenu {
                MenuItem {
                    text: qsTr("Delete")
                    onClicked: item.remorseDelete(function () {
                        page.music.savePlaylists(Playlists.remove(page.music.playlists, item.modelData.id));
                    })
                }
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
