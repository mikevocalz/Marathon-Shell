cmake_minimum_required(VERSION 3.21)
# This small project also runs without compiling the compositor. Full builds
# reach exactly the same registrations through tests/CMakeLists.txt.
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    project(MarathonNativeUI LANGUAGES NONE)
    enable_testing()
    set(_native_required_default ON)
else()
    set(_native_required_default OFF)
endif()
option(MARATHON_REQUIRE_NATIVE_UI_TESTS "Require every product app, shared controls and focused shell UI with real Qt/Keel" ${_native_required_default})
set(MARATHON_SOURCE_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../..")
find_package(Python3 COMPONENTS Interpreter QUIET)
set(KEEL_QML "$ENV{KEEL_QML}" CACHE PATH "Real Keel build/install QML directory")
set(QMLTESTRUNNER "$ENV{QMLTESTRUNNER}" CACHE FILEPATH "Qt 6 qmltestrunner")
set(MARATHON_NOTES_WIRE_CLIENT "$ENV{MARATHON_NOTES_WIRE_CLIENT}" CACHE FILEPATH
    "Locked production Notes transport integration client")
find_program(_native_dbus_run dbus-run-session)
if(NOT QMLTESTRUNNER)
    set(_qt_bins)
    if(TARGET Qt6::qmake)
        get_target_property(_qmake Qt6::qmake IMPORTED_LOCATION)
        execute_process(COMMAND "${_qmake}" -query QT_INSTALL_BINS
            OUTPUT_VARIABLE _qt_bins OUTPUT_STRIP_TRAILING_WHITESPACE)
    else()
        find_program(_qtpaths NAMES qtpaths6 qtpaths-qt6)
        if(_qtpaths)
            execute_process(COMMAND "${_qtpaths}" --query QT_INSTALL_BINS
                OUTPUT_VARIABLE _qt_bins OUTPUT_STRIP_TRAILING_WHITESPACE)
        endif()
    endif()
    find_program(_native_runner NAMES qmltestrunner qmltestrunner6 qmltestrunner-qt6
        HINTS "${_qt_bins}" /usr/lib/qt6/bin /usr/lib64/qt6/bin)
    if(_native_runner)
        set(QMLTESTRUNNER "${_native_runner}" CACHE FILEPATH "Qt 6 qmltestrunner" FORCE)
    endif()
endif()
if(NOT KEEL_QML)
    find_path(_native_keel Sailfish/Silica/qmldir
        PATHS /usr/lib/qt6/qml /usr/lib64/qt6/qml NO_DEFAULT_PATH)
    if(_native_keel)
        set(KEEL_QML "${_native_keel}" CACHE PATH "Real Keel build/install QML directory" FORCE)
    endif()
endif()
set(_missing)
if(NOT Python3_Interpreter_FOUND)
    list(APPEND _missing "Python 3")
endif()
if(NOT QMLTESTRUNNER OR NOT EXISTS "${QMLTESTRUNNER}")
    list(APPEND _missing "Qt 6 qmltestrunner")
endif()
if(NOT MARATHON_NOTES_WIRE_CLIENT OR NOT EXISTS "${MARATHON_NOTES_WIRE_CLIENT}")
    list(APPEND _missing "Hub/Notes wire client (build tests/native-ui/notes-wire and set MARATHON_NOTES_WIRE_CLIENT)")
endif()
if(NOT _native_dbus_run)
    list(APPEND _missing "dbus-run-session for the required private Notes wire test")
endif()
foreach(module Keel Keel/Actions Sailfish/Silica Sailfish/Share
    Sailfish/Pickers Sailfish/Gallery Nemo/Configuration Nemo/Ngf
    Nemo/KeepAlive Nemo/Thumbnailer Nemo/Notifications)
    if(NOT KEEL_QML OR NOT EXISTS "${KEEL_QML}/${module}/qmldir")
        list(APPEND _missing "${module}")
    endif()
endforeach()
# Each product app owns its native staging/service fixtures in one runner. Keep
# this inventory literal so the repository's reachability check follows it too.
set(_native_suites
    marathon-silica/tests
    apps/browser/tests apps/calculator/tests apps/calendar/tests apps/camera/tests
    apps/clock/tests apps/email/tests apps/gallery/tests apps/maps/tests
    apps/messages/tests apps/music/tests apps/notes/tests apps/phone/tests
    apps/pilot/tests apps/reef/tests apps/settings/tests apps/terminal/tests)
foreach(suite ${_native_suites})
    if(NOT EXISTS "${MARATHON_SOURCE_ROOT}/${suite}/run.sh")
        list(APPEND _missing "${suite}/run.sh")
    endif()
endforeach()
if(_missing)
    if(MARATHON_REQUIRE_NATIVE_UI_TESTS)
        message(FATAL_ERROR "Required native UI gate cannot run; missing: ${_missing}. Set KEEL_QML and QMLTESTRUNNER to real Qt 6/Keel builds.")
    endif()
    message(STATUS "Complete native UI gate NOT REGISTERED in this optional developer build; missing: ${_missing}. Use MARATHON_REQUIRE_NATIVE_UI_TESTS=ON for required coverage.")
else()
    add_test(NAME NativeUI_Toolkit COMMAND "${Python3_EXECUTABLE}"
        "${MARATHON_SOURCE_ROOT}/scripts/ci/run-qml-suite.py"
        --report "${CMAKE_CURRENT_BINARY_DIR}/reports/toolkit.xml" --
        "${QMLTESTRUNNER}" -import "${KEEL_QML}" -input "${CMAKE_CURRENT_SOURCE_DIR}/tst_toolkit.qml")
    set_tests_properties(NativeUI_Toolkit PROPERTIES
        LABELS "native-ui-required" FIXTURES_SETUP NativeKeel TIMEOUT 60)
    # One complete runner per product app and one shared-control suite. The
    # wrapper requires real Qt test cases and fails on missing reports/skips.
    # Camera keeps its production module staging; Mail loads real WebEngine.
    foreach(suite ${_native_suites})
        string(REPLACE "/" "_" name "Qml_${suite}")
        add_test(NAME ${name} COMMAND "${Python3_EXECUTABLE}"
            "${MARATHON_SOURCE_ROOT}/scripts/ci/run-qml-suite.py"
            --report "${CMAKE_CURRENT_BINARY_DIR}/reports/${name}.xml" --
            sh "${MARATHON_SOURCE_ROOT}/${suite}/run.sh")
        set_tests_properties(${name} PROPERTIES LABELS "native-ui-required"
            FIXTURES_REQUIRED NativeKeel TIMEOUT 300
            ENVIRONMENT "KEEL_QML=${KEEL_QML};QMLTESTRUNNER=${QMLTESTRUNNER}")
    endforeach()
    # Production Rust transport, actual Notes app/schema/actions/store/editor.
    # The conductor owns a private bus and isolated Configuration state; a
    # small Navigation1 admission fixture cannot claim real cgroup thaw.
    add_test(NAME NativeUI_NotesWire COMMAND "${Python3_EXECUTABLE}"
        "${MARATHON_SOURCE_ROOT}/scripts/ci/run-notes-wire.py"
        --client "${MARATHON_NOTES_WIRE_CLIENT}" --runner "${QMLTESTRUNNER}"
        --keel "${KEEL_QML}" --root "${MARATHON_SOURCE_ROOT}"
        --report "${CMAKE_CURRENT_BINARY_DIR}/reports/notes-wire.xml"
        -input "${CMAKE_CURRENT_SOURCE_DIR}/tst_noteswire.qml")
    set_tests_properties(NativeUI_NotesWire PROPERTIES LABELS "native-ui-required"
        FIXTURES_REQUIRED NativeKeel TIMEOUT 180)
    # PageViewHub covers the launcher's accepted/partial/failed uninstall UI.
    # Its real component imports QtWayland.Compositor; this is not a server or
    # task-card rendering test. The existing shell-service doubles stay local.
    add_test(NAME Qml_shell_PageViewHub COMMAND "${Python3_EXECUTABLE}"
        "${MARATHON_SOURCE_ROOT}/scripts/ci/run-qml-suite.py"
        --report "${CMAKE_CURRENT_BINARY_DIR}/reports/pageviewhub.xml" --
        "${QMLTESTRUNNER}" -import "${KEEL_QML}"
        -import "${MARATHON_SOURCE_ROOT}/marathon-silica"
        -import "${MARATHON_SOURCE_ROOT}/tests/ui/stubs"
        -input "${MARATHON_SOURCE_ROOT}/tests/ui/tst_pageviewhub.qml")
    set_tests_properties(Qml_shell_PageViewHub PROPERTIES LABELS "native-ui-required"
        FIXTURES_REQUIRED NativeKeel TIMEOUT 180)
    # Integrated Hub filtering and adaptive overview use the actual shell
    # components with the existing local shell-service fixtures. These do not
    # establish provider read-state sync or live Wayland surface presentation.
    add_test(NAME Qml_shell_Hub COMMAND "${Python3_EXECUTABLE}"
        "${MARATHON_SOURCE_ROOT}/scripts/ci/run-qml-suite.py"
        --report "${CMAKE_CURRENT_BINARY_DIR}/reports/hub.xml" --
        "${QMLTESTRUNNER}" -import "${KEEL_QML}"
        -import "${MARATHON_SOURCE_ROOT}/marathon-silica"
        -import "${MARATHON_SOURCE_ROOT}/tests/ui/stubs"
        -input "${MARATHON_SOURCE_ROOT}/tests/ui/tst_hub.qml")
    set_tests_properties(Qml_shell_Hub PROPERTIES LABELS "native-ui-required"
        FIXTURES_REQUIRED NativeKeel TIMEOUT 180)
    add_test(NAME Qml_shell_OverviewGrid COMMAND "${Python3_EXECUTABLE}"
        "${MARATHON_SOURCE_ROOT}/scripts/ci/run-qml-suite.py"
        --report "${CMAKE_CURRENT_BINARY_DIR}/reports/overviewgrid.xml" --
        "${QMLTESTRUNNER}" -import "${KEEL_QML}"
        -import "${MARATHON_SOURCE_ROOT}/marathon-silica"
        -import "${MARATHON_SOURCE_ROOT}/tests/ui/stubs"
        -input "${MARATHON_SOURCE_ROOT}/tests/ui/tst_overviewgrid.qml")
    set_tests_properties(Qml_shell_OverviewGrid PROPERTIES LABELS "native-ui-required"
        FIXTURES_REQUIRED NativeKeel TIMEOUT 180)
    add_test(NAME Qml_shell_TaskSwitcher COMMAND "${Python3_EXECUTABLE}"
        "${MARATHON_SOURCE_ROOT}/scripts/ci/run-qml-suite.py"
        --report "${CMAKE_CURRENT_BINARY_DIR}/reports/taskswitcher.xml" --
        "${QMLTESTRUNNER}" -import "${KEEL_QML}"
        -import "${MARATHON_SOURCE_ROOT}/marathon-silica"
        -import "${MARATHON_SOURCE_ROOT}/tests/ui/stubs"
        -input "${MARATHON_SOURCE_ROOT}/tests/ui/tst_taskswitcher.qml")
    set_tests_properties(Qml_shell_TaskSwitcher PROPERTIES LABELS "native-ui-required"
        FIXTURES_REQUIRED NativeKeel TIMEOUT 180)
    add_test(NAME Qml_shell_TaskPageIndicator COMMAND "${Python3_EXECUTABLE}"
        "${MARATHON_SOURCE_ROOT}/scripts/ci/run-qml-suite.py"
        --report "${CMAKE_CURRENT_BINARY_DIR}/reports/taskpageindicator.xml" --
        "${QMLTESTRUNNER}" -import "${KEEL_QML}"
        -import "${MARATHON_SOURCE_ROOT}/marathon-silica"
        -import "${MARATHON_SOURCE_ROOT}/tests/ui/stubs"
        -input "${MARATHON_SOURCE_ROOT}/tests/ui/tst_taskpageindicator.qml")
    set_tests_properties(Qml_shell_TaskPageIndicator PROPERTIES LABELS "native-ui-required"
        FIXTURES_REQUIRED NativeKeel TIMEOUT 180)
    add_test(NAME NativeUI_RegistrationContract COMMAND "${Python3_EXECUTABLE}"
        "${MARATHON_SOURCE_ROOT}/tests/lint/test_native_ui_gate.py" NativeRegistrationTests)
    set_tests_properties(NativeUI_RegistrationContract PROPERTIES
        LABELS "native-ui-required" TIMEOUT 60
        ENVIRONMENT "QMLTESTRUNNER=${QMLTESTRUNNER};CMAKE_COMMAND=${CMAKE_COMMAND};KEEL_QML=${KEEL_QML};MARATHON_NOTES_WIRE_CLIENT=${MARATHON_NOTES_WIRE_CLIENT}")
    message(STATUS "Required native UI tests are registered under the native-ui-required CTest label")
endif()

if(Python3_Interpreter_FOUND)
    set(_native_qmllint "$ENV{QMLLINT}")
    if(NOT _native_qmllint AND QMLLINT_EXECUTABLE)
        set(_native_qmllint "${QMLLINT_EXECUTABLE}")
    endif()
    add_test(NAME Lint_QmlValidator COMMAND "${Python3_EXECUTABLE}"
        "${MARATHON_SOURCE_ROOT}/tests/lint/test_validate_qml.py")
    add_test(NAME NativeUI_GateContract COMMAND "${Python3_EXECUTABLE}"
        "${MARATHON_SOURCE_ROOT}/tests/lint/test_native_ui_gate.py")
    set_tests_properties(Lint_QmlValidator NativeUI_GateContract PROPERTIES
        LABELS "native-ui-required" TIMEOUT 120
        ENVIRONMENT "QMLLINT=${_native_qmllint};QMLTESTRUNNER=${QMLTESTRUNNER};CMAKE_COMMAND=${CMAKE_COMMAND}")
endif()
