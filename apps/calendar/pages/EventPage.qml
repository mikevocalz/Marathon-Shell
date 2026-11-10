import QtQuick
import Sailfish.Silica 1.0
import Marathon.Silica 1.0

Page {
    id: page

    property var app
    property var eventId
    readonly property var event: app.eventById(eventId)
    // Kept so the page still reads right while it pops after a delete.
    property var shown: ({})
    property bool accountEventUnavailable: false

    onEventChanged: {
        if (event) {
            shown = event;
            accountEventUnavailable = false;
        } else if (shown.readOnly) {
            // A revoked grant or removed account must clear an open detail page.
            shown = {};
            accountEventUnavailable = true;
        }
    }
    Component.onCompleted: {
        if (event)
            shown = event;
    }

    function remove() {
        const id = eventId;
        remorse.execute(qsTr("Deleted %1").arg(shown.title), function () {
            if (page.app.deleteEvent(id))
                pageStack.pop();
        });
    }

    RemorsePopup {
        id: remorse

        objectName: "remorse"
    }

    SilicaFlickable {
        objectName: "eventView"
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        PullDownMenu {
            MenuItem {
                objectName: "deleteItem"
                text: qsTr("Delete")
                enabled: page.event !== null && !page.event.readOnly
                onClicked: page.remove()
            }
            MenuItem {
                objectName: "editItem"
                text: qsTr("Edit")
                enabled: page.event !== null && !page.event.readOnly
                onClicked: page.app.editEvent(page.event)
            }
        }

        Column {
            id: column

            width: parent.width

            PageHeader {
                objectName: "eventHeader"
                title: page.accountEventUnavailable ? qsTr("Event unavailable") : page.shown.title || qsTr("Untitled event")
                wrapMode: Text.Wrap
            }
            Label {
                objectName: "accountEventUnavailableNotice"
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: page.accountEventUnavailable
                text: qsTr("This account event is no longer available.")
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
            }
            DetailItem {
                objectName: "accountDetail"
                visible: !!page.shown.readOnly
                label: qsTr("Calendar")
                value: page.shown.accountLabel || qsTr("Account calendar")
            }
            Label {
                objectName: "accountCalendarNotice"
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: !!page.shown.readOnly
                text: page.shown.recurrenceIncomplete ? qsTr("Read-only series preview. Additional occurrences and reminders are not available here yet.") : qsTr("Read-only account event. Edit it in your calendar provider; reminders are not available here yet.")
                wrapMode: Text.Wrap
                color: Theme.secondaryColor
                font.pixelSize: Theme.fontSizeSmall
            }
            DetailItem {
                objectName: "dateDetail"
                visible: !page.accountEventUnavailable
                label: qsTr("Date")
                value: page.shown.date ? page.app.dateText(page.shown) : ""
            }
            DetailItem {
                objectName: "timeDetail"
                visible: !page.accountEventUnavailable
                label: qsTr("Time")
                value: page.shown.date ? page.app.timeRangeText(page.shown) : ""
            }
            DetailItem {
                objectName: "locationDetail"
                label: qsTr("Location")
                visible: !!page.shown.location
                value: page.shown.location || ""
            }
            DetailItem {
                objectName: "repeatDetail"
                label: qsTr("Repeats")
                visible: !!page.shown.recurring && page.shown.recurring !== "none"
                value: page.app.repeatText(page.shown.recurring)
            }
            DetailItem {
                objectName: "reminderDetail"
                visible: !page.accountEventUnavailable && !page.shown.readOnly
                label: qsTr("Reminder")
                value: page.app.reminderText(page.shown.reminder === undefined ? 0 : page.shown.reminder)
            }

            SectionHeader {
                visible: descriptionLabel.text !== ""
                text: qsTr("Description")
            }
            Label {
                id: descriptionLabel

                objectName: "description"
                x: Theme.horizontalPageMargin
                width: parent.width - 2 * Theme.horizontalPageMargin
                visible: text !== ""
                text: page.shown.description || ""
                wrapMode: Text.Wrap
                color: Theme.highlightColor
            }
        }

        VerticalScrollDecorator {}
    }
}
