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
option(MARATHON_REQUIRE_NATIVE_UI_TESTS "Require the real Keel Notes UI gate" ${_native_required_default})
set(MARATHON_SOURCE_ROOT "${CMAKE_CURRENT_SOURCE_DIR}/../..")
find_package(Python3 COMPONENTS Interpreter QUIET)
set(KEEL_QML "$ENV{KEEL_QML}" CACHE PATH "Real Keel build/install QML directory")
set(QMLTESTRUNNER "$ENV{QMLTESTRUNNER}" CACHE FILEPATH "Qt 6 qmltestrunner")
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
foreach(module Keel Keel/Actions Sailfish/Silica Sailfish/Share Nemo/Configuration)
    if(NOT KEEL_QML OR NOT EXISTS "${KEEL_QML}/${module}/qmldir")
        list(APPEND _missing "${module}")
    endif()
endforeach()
if(_missing)
    if(MARATHON_REQUIRE_NATIVE_UI_TESTS)
        message(FATAL_ERROR "Required native UI gate cannot run; missing: ${_missing}. Set KEEL_QML and QMLTESTRUNNER to real Qt 6/Keel builds.")
    endif()
    message(STATUS "Native Notes UI gate NOT REGISTERED in this optional developer build; missing: ${_missing}. Use MARATHON_REQUIRE_NATIVE_UI_TESTS=ON for required coverage.")
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
    message(STATUS "Required native UI scope: toolkit import/instantiation + complete Notes suite; broader app/platform suites remain separate")
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
