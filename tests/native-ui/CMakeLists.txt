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
option(MARATHON_REQUIRE_NATIVE_UI_TESTS "Require real Notes, Settings, Hub and overview UI" ${_native_required_default})
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
foreach(module Keel Keel/Actions Sailfish/Silica Sailfish/Share Nemo/Configuration Nemo/Ngf)
    if(NOT KEEL_QML OR NOT EXISTS "${KEEL_QML}/${module}/qmldir")
        list(APPEND _missing "${module}")
    endif()
endforeach()
if(_missing)
    if(MARATHON_REQUIRE_NATIVE_UI_TESTS)
        message(FATAL_ERROR "Required native UI gate cannot run; missing: ${_missing}. Set KEEL_QML and QMLTESTRUNNER to real Qt 6/Keel builds.")
    endif()
    message(STATUS "Focused native UI gate NOT REGISTERED in this optional developer build; missing: ${_missing}. Use MARATHON_REQUIRE_NATIVE_UI_TESTS=ON for required coverage.")
else()
    add_test(NAME NativeUI_Toolkit COMMAND "${Python3_EXECUTABLE}"
        "${MARATHON_SOURCE_ROOT}/scripts/ci/run-qml-suite.py"
        --report "${CMAKE_CURRENT_BINARY_DIR}/reports/toolkit.xml" --
        "${QMLTESTRUNNER}" -import "${KEEL_QML}" -input "${CMAKE_CURRENT_SOURCE_DIR}/tst_toolkit.qml")
    set_tests_properties(NativeUI_Toolkit PROPERTIES
        LABELS "native-ui-required" FIXTURES_SETUP NativeKeel TIMEOUT 60)
    # The unchanged production Notes suite uses real Silica/Actions/Share and
    # Configuration, with its existing platform-service doubles only.
    add_test(NAME Qml_apps_notes_tests COMMAND "${Python3_EXECUTABLE}"
        "${MARATHON_SOURCE_ROOT}/scripts/ci/run-qml-suite.py"
        --report "${CMAKE_CURRENT_BINARY_DIR}/reports/notes.xml" --
        sh "${MARATHON_SOURCE_ROOT}/apps/notes/tests/run.sh")
    set_tests_properties(Qml_apps_notes_tests PROPERTIES LABELS "native-ui-required"
        FIXTURES_REQUIRED NativeKeel TIMEOUT 180
        ENVIRONMENT "KEEL_QML=${KEEL_QML};QMLTESTRUNNER=${QMLTESTRUNNER}")
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
    # The changed uninstall/cleanup UI lives in Settings AppPages. Keep this
    # input explicit: it does not claim the rest of Settings is qualified.
    add_test(NAME Qml_settings_AppPages COMMAND "${Python3_EXECUTABLE}"
        "${MARATHON_SOURCE_ROOT}/scripts/ci/run-qml-suite.py"
        --report "${CMAKE_CURRENT_BINARY_DIR}/reports/settings-apppages.xml" --
        "${QMLTESTRUNNER}" -import "${KEEL_QML}"
        -import "${MARATHON_SOURCE_ROOT}/marathon-silica"
        -import "${MARATHON_SOURCE_ROOT}/apps/settings/tests/stubs"
        -input "${MARATHON_SOURCE_ROOT}/apps/settings/tests/tst_apppages.qml")
    set_tests_properties(Qml_settings_AppPages PROPERTIES LABELS "native-ui-required"
        FIXTURES_REQUIRED NativeKeel TIMEOUT 180 ENVIRONMENT "QML_XHR_ALLOW_FILE_READ=1")
    add_test(NAME Qml_settings_PermissionPages COMMAND "${Python3_EXECUTABLE}"
        "${MARATHON_SOURCE_ROOT}/scripts/ci/run-qml-suite.py"
        --report "${CMAKE_CURRENT_BINARY_DIR}/reports/settings-permissionpages.xml" --
        "${QMLTESTRUNNER}" -import "${KEEL_QML}"
        -import "${MARATHON_SOURCE_ROOT}/marathon-silica"
        -import "${MARATHON_SOURCE_ROOT}/apps/settings/tests/stubs"
        -input "${MARATHON_SOURCE_ROOT}/apps/settings/tests/tst_permissionpages.qml")
    set_tests_properties(Qml_settings_PermissionPages PROPERTIES LABELS "native-ui-required"
        FIXTURES_REQUIRED NativeKeel TIMEOUT 180 ENVIRONMENT "QML_XHR_ALLOW_FILE_READ=1")
    add_test(NAME Qml_silica_SummaryListItem COMMAND "${Python3_EXECUTABLE}"
        "${MARATHON_SOURCE_ROOT}/scripts/ci/run-qml-suite.py"
        --report "${CMAKE_CURRENT_BINARY_DIR}/reports/summary-list-item.xml" --
        "${QMLTESTRUNNER}" -import "${KEEL_QML}"
        -import "${MARATHON_SOURCE_ROOT}/marathon-silica"
        -input "${MARATHON_SOURCE_ROOT}/marathon-silica/tests/tst_summarylistitem.qml")
    set_tests_properties(Qml_silica_SummaryListItem PROPERTIES LABELS "native-ui-required"
        FIXTURES_REQUIRED NativeKeel TIMEOUT 60)
    add_test(NAME Qml_settings_RowPresentation COMMAND "${Python3_EXECUTABLE}"
        "${MARATHON_SOURCE_ROOT}/scripts/ci/run-qml-suite.py"
        --report "${CMAKE_CURRENT_BINARY_DIR}/reports/settings-rows.xml" --
        "${QMLTESTRUNNER}" -import "${KEEL_QML}"
        -import "${MARATHON_SOURCE_ROOT}/marathon-silica"
        -import "${MARATHON_SOURCE_ROOT}/apps/settings/tests/stubs"
        -input "${MARATHON_SOURCE_ROOT}/apps/settings/tests/tst_rowpresentation.qml")
    set_tests_properties(Qml_settings_RowPresentation PROPERTIES LABELS "native-ui-required"
        FIXTURES_REQUIRED NativeKeel TIMEOUT 180 ENVIRONMENT "QML_XHR_ALLOW_FILE_READ=1")
    add_test(NAME Qml_phone_PeopleRows COMMAND "${Python3_EXECUTABLE}"
        "${MARATHON_SOURCE_ROOT}/scripts/ci/run-qml-suite.py"
        --report "${CMAKE_CURRENT_BINARY_DIR}/reports/people-rows.xml" --
        "${QMLTESTRUNNER}" -import "${KEEL_QML}"
        -import "${MARATHON_SOURCE_ROOT}/marathon-silica"
        -import "${MARATHON_SOURCE_ROOT}/apps/phone/tests/stubs"
        -input "${MARATHON_SOURCE_ROOT}/apps/phone/tests/tst_peoplerows.qml")
    set_tests_properties(Qml_phone_PeopleRows PROPERTIES LABELS "native-ui-required"
        FIXTURES_REQUIRED NativeKeel TIMEOUT 180 ENVIRONMENT "QML_XHR_ALLOW_FILE_READ=1")
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
    message(STATUS "Required native UI scope: toolkit + complete Notes + real Hub/Notes wire + Settings AppPages/PermissionPages/rows + Silica summary rows + Phone people rows + PageViewHub + Hub + overview geometry/task switcher; broader suites remain separate")
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
