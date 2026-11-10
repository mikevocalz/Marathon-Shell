import QtQuick
import QtTest
import Sailfish.Silica 1.0
import Marathon.Silica 1.0
import Shipwright.Reef 1.0
import "../ui/components"
import "../ui/pages"

TestCase {
    id: testCase

    name: "ReefCataloguePresentation"
    when: windowShown
    visible: true
    width: 540
    height: 1140

    Component {
        id: packageComponent
        PackageDelegate {
            width: 320
            name: "org.example.weather"
            title: "<b>Weather with a long application title</b>"
            summary: "A detailed forecast with long descriptive text"
            categoryLabel: "Weather and travel"
            installState: "update_available"
            installedVersion: "1.0"
            version: "1.1"
            licenceModel: "free"
            licensed: true
            publisher: "An independent publisher"
            iconPath: ""
            isNew: false
            source: "reef"
            jobState: ""
            jobPercent: 0
        }
    }
    Component {
        id: appComponent
        ApplicationWindow {
            width: 320
            height: 640
            initialPage: Component {
                SearchPage {}
            }
        }
    }
    SignalSpy {
        id: clicks
        signalName: "clicked"
    }

    function init() {
        Reef.searchText = "weather";
        Reef.lastError = "";
        Reef.busy = false;
        Reef.refreshes = 0;
        Reef.catalogueModel.clear();
    }

    function test_rowGrowsForLongNamesAndKeepsItsKeyboardIdentity() {
        const row = createTemporaryObject(packageComponent, testCase);
        const title = findChild(row, "packageTitle");
        const state = findChild(row, "packageState");
        title.font.pixelSize = Theme.fontSizeLarge;
        tryVerify(() => title.lineCount > 1);
        compare(title.textFormat, Text.PlainText);
        verify(!title.truncated);
        verify(state.mapToItem(row, 0, state.height).y <= row.contentHeight);
        verify(row.Accessible.name.indexOf(row.title) >= 0);
        verify(row.Accessible.name.indexOf("Update") >= 0);
        clicks.target = row;
        clicks.clear();
        row.forceActiveFocus();
        verify(findChild(row, "focusFrame").showing);
        keyClick(Qt.Key_Return);
        compare(clicks.count, 1);
        compare(row.name, "org.example.weather");
        row.jobState = "failed";
        compare(state.text, "Failed");
        verify(row.Accessible.name.indexOf("Failed") >= 0);
    }

    function test_searchDistinguishesFailureFromNoMatches() {
        const app = createTemporaryObject(appComponent, testCase);
        tryVerify(() => app.pageStack.currentPage !== null && !app.pageStack.busy);
        const page = app.pageStack.currentPage;
        const placeholder = findChild(page, "searchPlaceholder");
        compare(placeholder.text, "No apps match");
        Reef.lastError = "The catalogue is unavailable";
        compare(placeholder.text, "Couldn't load apps");
        verify(placeholder.hintText.indexOf(Reef.lastError) >= 0);
        findChild(page, "refreshSearch").clicked();
        compare(Reef.refreshes, 1);
        compare(findChild(page, "search").text, "weather");
        Reef.busy = true;
        verify(!placeholder.enabled);
        verify(!findChild(page, "refreshSearch").enabled);
    }
}
