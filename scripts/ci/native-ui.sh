#!/bin/sh
# Required Notes/Tasks and Settings AppPages UI, using the APK's Keel source pin.
# Reproduce with the alpine:edge container invocation in .github/workflows/ci.yml.
set -eu

if [ "${1:-}" != --build ]; then
    apk add --no-cache build-base cmake samurai pkgconf git python3 cargo \
        qt6-qtbase-dev qt6-qtbase-private-dev qt6-qtdeclarative-dev \
        qt6-qtdeclarative-private-dev qt6-qtsvg-dev libxkbcommon-dev dbus
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

# Native, unmodified Silica, Actions, Share and Configuration plugins. The
# supported JSON Configuration backend isolates tests; device mlite/dconf,
# compositor/hardware, and the broader platform modules are separate gates.
cmake -S build-keel-source/keel -B build-keel -G Ninja \
    -DCMAKE_BUILD_TYPE=Debug -DBUILD_TESTING=OFF \
    -DKEEL_BUILD_NEMO_COMPAT=ON -DKEEL_BUILD_ACTIONS=ON \
    -DKEEL_BUILD_SAILFISHAPP=OFF -DKEEL_BUILD_PLATFORM=OFF \
    -DKEEL_BUILD_QT5COMPAT=OFF -DKEEL_BUILD_BOOSTER=OFF \
    -DKEEL_REQUIRE_MLITE=OFF -DKEEL_REQUIRE_LIBDCONF=OFF \
    -DKEEL_REQUIRE_IPHB=OFF -DKEEL_REQUIRE_GIO=OFF \
    -DKEEL_QML_DISCARD_SOURCES=OFF -DKEEL_QML_TYPES_ONLY=OFF
cmake --build build-keel --parallel 2 --target \
    keelplugin silicacoreplugin silicaprivateplugin silicaplugin \
    silicascreenplugin silicabackgroundplugin silicashareplugin \
    nemoconfiguration keelactionsplugin

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
cmake -S tests/native-ui -B build-native-ui -G Ninja \
    -DMARATHON_REQUIRE_NATIVE_UI_TESTS=ON \
    -DKEEL_QML="$KEEL_QML" -DQMLTESTRUNNER="$QMLTESTRUNNER"
# Qt Quick tests emit JUnit reports checked for real cases, skips, and failures.
# CTest also fails if the required label ever selects no tests.
dbus-run-session -- ctest --test-dir build-native-ui -L native-ui-required \
    --no-tests=error --output-on-failure
