import QtQuick 6.0
import QtTest 1.3
import QtWayland.Compositor
import QtMultimedia as Multimedia
import QtPositioning
import Qt5Compat.GraphicalEffects as Effects
import QtWebEngine as WebEngine
import Sailfish.Silica 1.0
import Keel 1.0
import Keel.Actions 1.0
import Sailfish.Share 1.0
import Sailfish.Gallery 1.0 as Gallery
import Sailfish.Pickers 1.0 as Pickers
import Nemo.Configuration 1.0
import Nemo.KeepAlive 1.2
import Nemo.Thumbnailer 1.0
import Nemo.Notifications 1.0

TestCase {
    name: "NativeToolkit"
    when: windowShown
    width: 360
    height: 640

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

    Component {
        id: iconComponent
        Image {
            source: "image://theme/icon-m-mail"
            asynchronous: true
        }
    }

    Component {
        id: playerComponent
        Multimedia.MediaPlayer {}
    }

    Component {
        id: effectComponent
        Effects.FastBlur {}
    }

    Component {
        id: thumbnailComponent
        Gallery.ThumbnailImage {}
    }

    Component {
        id: pickerComponent
        Pickers.FilePickerPage {}
    }

    Component {
        id: webComponent
        WebEngine.WebEngineView {
            property bool loaded: false
            width: 360
            height: 240
            onLoadingChanged: function (request) {
                if (request.status === WebEngine.WebEngineView.LoadSucceededStatus)
                    loaded = true;
            }
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

    function test_realThemeIcon() {
        const icon = createTemporaryObject(iconComponent, this);
        verify(icon !== null);
        tryCompare(icon, "status", Image.Ready);
        verify(icon.implicitWidth > 0 && icon.implicitHeight > 0);
    }

    function test_realQtModules() {
        verify(createTemporaryObject(playerComponent, this) !== null);
        verify(createTemporaryObject(effectComponent, this) !== null);
        verify(QtPositioning.coordinate(60.17, 24.94).isValid);
    }

    function test_realPickerAndGallery() {
        verify(createTemporaryObject(thumbnailComponent, this) !== null);
        verify(createTemporaryObject(pickerComponent, this) !== null);
    }

    function test_realHtmlRenderer() {
        const view = createTemporaryObject(webComponent, this);
        verify(view !== null);
        view.loadHtml("<!doctype html><title>Native gate</title><p>Native HTML renderer</p>");
        tryCompare(view, "loaded", true, 15000);
        compare(view.title, "Native gate");
    }
}
