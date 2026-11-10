#!/bin/sh
# Required product apps, shared controls and shell UI with the APK Keel pin.
# Reproduce with the alpine:edge container invocation in .github/workflows/ci.yml.
set -eu

if [ "${1:-}" != --build ]; then
    apk add --no-cache build-base cmake samurai pkgconf git python3 cargo \
        qt6-qtbase-dev qt6-qtbase-private-dev qt6-qtdeclarative-dev \
        qt6-qtdeclarative-private-dev qt6-qtsvg-dev qt6-qtwayland-dev \
        qt6-qtmultimedia-dev qt6-qtpositioning-dev qt6-qt5compat-dev \
        qt6-qtwebengine-dev qt6-qtwebchannel-dev libxkbcommon-dev dbus
    # The base Qt packages provide fontconfig but no fonts. Empty-font fallback
    # has different metrics and cannot qualify the production layouts. Use the
    # image's existing Source Sans files and Sail Sans aliases before running
    # the suites as the unprivileged ci user.
    cmake -S /src/tests/native-ui/fonts -B /tmp/native-ui-fonts -G Ninja \
        -DCMAKE_INSTALL_PREFIX=/usr
    cmake --install /tmp/native-ui-fonts
    fc-cache -f /usr/share/fonts/source-sans-3
    case "$(fc-match -f '%{file}' 'Sail Sans Pro Light')" in
        /usr/share/fonts/source-sans-3/SourceSans3-Light.ttf) ;;
        *) echo "Production Sail Sans font alias is unavailable" >&2; exit 1 ;;
    esac
    adduser -D ci
    cp -a /src /home/ci/src
    chown -R ci:ci /home/ci/src
    exec su ci -c 'cd /home/ci/src && exec sh scripts/ci/native-ui.sh --build'
fi

# Read the exact source identity without sourcing an APKBUILD as shell code.
keel_commit=$(python3 - <<'PY'
from pathlib import Path
import re
text = Path('packaging/packages/keel-silica/APKBUILD').read_text()
match = re.search(r'^_commit=([0-9a-f]{40})$', text, re.M)
if not match:
    raise SystemExit('missing immutable Keel source pin')
print(match[1])
PY
)
git init build-keel-source
git -C build-keel-source remote add origin https://github.com/patrickjquinn/shipwright-open.git
git -C build-keel-source fetch --depth=1 origin "$keel_commit"
git -C build-keel-source checkout --detach FETCH_HEAD
[ "$(git -C build-keel-source rev-parse HEAD)" = "$keel_commit" ]

# Native, unmodified Keel modules required by the product app imports.
# The supported JSON Configuration backend isolates tests;
# compositor/hardware and unrelated platform modules remain separate gates.
cmake -S build-keel-source/keel -B build-keel -G Ninja \
    -DCMAKE_BUILD_TYPE=Debug -DBUILD_TESTING=OFF \
    -DKEEL_BUILD_NEMO_COMPAT=ON -DKEEL_BUILD_ACTIONS=ON \
    -DKEEL_BUILD_SAILFISHAPP=OFF -DKEEL_BUILD_PLATFORM=ON \
    -DKEEL_PLATFORM_PICKERS=ON -DKEEL_PLATFORM_GALLERY=ON \
    -DKEEL_PLATFORM_WEBVIEW=OFF -DKEEL_PLATFORM_SECRETS=OFF \
    -DKEEL_PLATFORM_AMBER_WEB_AUTHORIZATION=OFF -DKEEL_PLATFORM_MPRIS=OFF \
    -DKEEL_PLATFORM_AMBER_MPRIS=OFF -DKEEL_PLATFORM_THUMBNAILER=ON \
    -DKEEL_PLATFORM_MCE=OFF -DKEEL_PLATFORM_ACCOUNTS=OFF \
    -DKEEL_PLATFORM_SAILFISH_ACCOUNTS=OFF -DKEEL_PLATFORM_POLICY=OFF \
    -DKEEL_BUILD_QT5COMPAT=OFF -DKEEL_BUILD_BOOSTER=OFF \
    -DKEEL_REQUIRE_MLITE=OFF -DKEEL_REQUIRE_LIBDCONF=OFF \
    -DKEEL_REQUIRE_IPHB=OFF -DKEEL_REQUIRE_GIO=OFF \
    -DKEEL_QML_DISCARD_SOURCES=OFF -DKEEL_QML_TYPES_ONLY=OFF
cmake --build build-keel --parallel 2 --target \
    keelplugin silicacoreplugin silicaprivateplugin silicaplugin \
    silicascreenplugin silicabackgroundplugin silicashareplugin \
    nemoconfiguration nemongf keepaliveplugin keelactionsplugin \
    sailfishpickersplugin sailfishgalleryplugin nemothumbnailer nemonotifications

# Alpine keeps Qt's tools outside PATH. Use its Qt 6 installation explicitly.
qtpaths=/usr/lib/qt6/bin/qtpaths6
if [ ! -x "$qtpaths" ]; then
    qtpaths=/usr/lib/qt6/bin/qtpaths
fi
if [ ! -x "$qtpaths" ]; then
    echo "Qt 6 qtpaths is missing from /usr/lib/qt6/bin" >&2
    exit 1
fi
qt_bins=$("$qtpaths" --query QT_INSTALL_BINS)
export QMLTESTRUNNER="$qt_bins/qmltestrunner"
export QMLLINT="$qt_bins/qmllint"
for tool in "$QMLTESTRUNNER" "$QMLLINT"; do
    if [ ! -x "$tool" ]; then
        echo "Required Qt 6 tool is not executable: $tool" >&2
        exit 1
    fi
done
export KEEL_QML="$PWD/build-keel/qml"
export QT_QPA_PLATFORM=offscreen

# Generate and install the production Phosphor mappings with the unchanged
# icon-theme CMake project. The toolkit fixture requires a real provider image;
# absent icons must not pass as a merely logged rendering warning.
cmake -S tests/native-ui/icons -B build-native-icons -G Ninja \
    -DCMAKE_INSTALL_PREFIX="$PWD/build-native-icons-root"
cmake --install build-native-icons > build-native-icons-install.log
export KEEL_THEME_PIXEL_RATIO=1
export KEEL_THEME_ICON_DIRS="$PWD/build-native-icons-root/share/themes/sailfish-default/silica/z1.0/icons-monochrome"
# Compile the exact production Rust capture transport with its checked-in
# lock. This small client needs no compositor or platform-native build.
cargo build --manifest-path tests/native-ui/notes-wire/Cargo.toml --locked \
    --target-dir build-native-ui/notes-wire-target
export MARATHON_NOTES_WIRE_CLIENT="$PWD/build-native-ui/notes-wire-target/debug/marathon-notes-wire"
cmake -S tests/native-ui -B build-native-ui -G Ninja \
    -DMARATHON_REQUIRE_NATIVE_UI_TESTS=ON \
    -DKEEL_QML="$KEEL_QML" -DQMLTESTRUNNER="$QMLTESTRUNNER" \
    -DMARATHON_NOTES_WIRE_CLIENT="$MARATHON_NOTES_WIRE_CLIENT"
# Qt Quick tests emit JUnit reports checked for real cases, skips, and failures.
# CTest also fails if the required label ever selects no tests.
dbus-run-session -- ctest --test-dir build-native-ui -L native-ui-required \
    --no-tests=error --output-on-failure
# Keep the successful wrappers' actual case counts visible in the job log.
sed -n '/^\[native-ui\]/p' build-native-ui/Testing/Temporary/LastTest.log
