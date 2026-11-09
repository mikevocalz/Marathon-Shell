import QtQuick
import QtQuick.Window
import QtTest
import MarathonOS.Shell
import "../../shell/qml/components"

TestCase {
    name: "PageViewHub"
    when: windowShown

    SignalSpy { id: failed; target: pages; signalName: "uninstallFailed" }
    SignalSpy { id: partial; target: pages; signalName: "uninstallPartial" }
    SignalSpy { id: detailedFailure; target: pages; signalName: "uninstallFailureDetail" }

    function init() {
        failed.clear();
        partial.clear();
        detailedFailure.clear();
        pages.removingApps = ({});
        AppModel.uninstallAccepted = true;
        AppModel.uninstallRequests = [];
    }

    function test_acceptedUninstallWaitsForPartialOutcome() {
        pages.uninstall({id: "notes", name: "Notes"});
        compare(AppModel.uninstallRequests, ["notes"]);
        compare(failed.count, 0);
        compare(partial.count, 0);
        AppModel.uninstallPartial("notes", "Restart before cleanup");
        compare(partial.count, 1);
        compare(partial.signalArguments[0][0], "notes");
        compare(partial.signalArguments[0][1], "Restart before cleanup");
        compare(failed.count, 0);
    }

    function test_finalFailureIsDistinctFromAdmission() {
        pages.uninstall({id: "notes", name: "Notes"});
        compare(detailedFailure.count, 0);
        AppModel.uninstallFailed("notes", "Permission denied");
        compare(detailedFailure.count, 1);
        compare(detailedFailure.signalArguments[0][0], "Notes");
        compare(detailedFailure.signalArguments[0][1], "Permission denied");
        verify(pages.removingApps.notes === undefined);
    }

    function test_refusedAdmissionDoesNotWaitForCompletion() {
        AppModel.uninstallAccepted = false;
        pages.uninstall({id: "notes", name: "Notes"});
        compare(failed.count, 1);
        verify(pages.removingApps.notes === undefined);
    }

    Window {
        width: 720
        height: 720
        visible: true

        MarathonPageView {
            id: pages

            anchors.fill: parent
        }
    }

    function test_leavingTheHubClosesTheWeather() {
        pages.jumpToIndex(0);
        const list = findChild(pages, "weatherFlick");
        tryVerify(() => list !== null);
        const sheet = list.parent;
        sheet.open = true;
        verify(pages.hubOverlayOpen);
        pages.navigateToPage(-1);
        verify(!sheet.open);
        verify(!pages.hubOverlayOpen);
    }
}
