import QtQuick 6.0
import QtTest 1.3
import Sailfish.Silica 1.0
import Keel 1.0
import Keel.Actions 1.0
import Sailfish.Share 1.0
import Nemo.Configuration 1.0

TestCase {
    name: "NativeToolkit"

    Component {
        id: pageComponent
        Page {}
    }

    Component {
        id: configurationComponent
        ConfigurationGroup {
            path: "/marathon/native-ui-gate"
            property string probe: "real configuration plugin"
        }
    }

    function test_realSilicaPage() {
        const page = createTemporaryObject(pageComponent, this);
        verify(page !== null);
        verify(page.pageContainer !== undefined);
    }

    function test_realConfiguration() {
        const configuration = createTemporaryObject(configurationComponent, this);
        verify(configuration !== null);
        compare(configuration.probe, "real configuration plugin");
    }
}
