pragma ComponentBehavior: Bound
import QtQuick
import Sailfish.Silica 1.0
import Marathon.Silica 1.0

Page {
    id: page

    property var app

    SilicaListView {
        objectName: "sessionList"
        anchors.fill: parent
        model: page.app.sessions

        header: PageHeader {
            title: qsTr("Sessions")
        }

        PullDownMenu {
            MenuItem {
                objectName: "newSessionItem"
                text: qsTr("New session")
                onClicked: {
                    page.app.newSession();
                    pageStack.pop();
                }
            }
        }

        delegate: SummaryListItem {
            id: item

            required property var modelData
            required property int index

            highlighted: down || index === page.app.currentIndex
            menu: page.app.sessions.length > 1 ? closeMenu : null
            text: modelData.title !== "Terminal" ? modelData.title : qsTr("Session %1").arg(index + 1)
            description: modelData.failed ? qsTr("Couldn’t start — open to retry") : modelData.running ? (index === page.app.currentIndex ? qsTr("Current session") : qsTr("Running")) : qsTr("Process exited")

            onClicked: {
                page.app.currentIndex = index;
                pageStack.pop();
            }

            Component {
                id: closeMenu

                ContextMenu {
                    MenuItem {
                        objectName: "closeItem"
                        text: qsTr("Close")
                        onClicked: {
                            const app = page.app;
                            const session = item.modelData;
                            item.remorseAction(qsTr("Closing"), () => app.closeSession(app.sessions.indexOf(session)));
                        }
                    }
                }
            }
        }

        VerticalScrollDecorator {}
    }
}
