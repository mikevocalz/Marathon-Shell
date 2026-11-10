# Strict, explicit QML validation after the target's type information exists.
# Qt owns <target>_qmllint; do not shadow it or create a build/lint cycle.
include_guard(GLOBAL)
option(MARATHON_REQUIRE_QMLLINT "Fail configuration without a working Qt 6 qmllint" OFF)
set(_MARATHON_QML_VALIDATOR "${CMAKE_CURRENT_LIST_DIR}/../scripts/validate-qml.py")
find_package(Python3 COMPONENTS Interpreter QUIET)
set(QMLLINT_EXECUTABLE "" CACHE FILEPATH "Qt 6 qmllint (empty selects the build Qt or installed Qt 6 tools)")
set(_qmllint_selection)
if(QMLLINT_EXECUTABLE)
    list(APPEND _qmllint_selection --qmllint "${QMLLINT_EXECUTABLE}")
elseif(TARGET Qt6::qmllint)
    get_target_property(_qt_qmllint Qt6::qmllint IMPORTED_LOCATION)
    if(_qt_qmllint)
        list(APPEND _qmllint_selection --qmllint "${_qt_qmllint}")
    endif()
endif()
set(_qmllint_status 1)
if(Python3_Interpreter_FOUND)
    execute_process(COMMAND "${Python3_EXECUTABLE}" "${_MARATHON_QML_VALIDATOR}"
        ${_qmllint_selection} --print-tool RESULT_VARIABLE _qmllint_status
        OUTPUT_VARIABLE _qmllint_tool OUTPUT_STRIP_TRAILING_WHITESPACE
        ERROR_VARIABLE _qmllint_error)
endif()
if(NOT _qmllint_status EQUAL 0)
    if(MARATHON_REQUIRE_QMLLINT)
        message(FATAL_ERROR "Qt 6 QML validation is required: ${_qmllint_error}. Python 3 and Qt 6 qmllint must be installed.")
    endif()
    message(WARNING "Qt 6 QML validation is unavailable: ${_qmllint_error}. This developer build is not QML validation; the explicit validation target will fail until tooling is installed.")
else()
    set(QMLLINT_EXECUTABLE "${_qmllint_tool}" CACHE FILEPATH "Qt 6 qmllint" FORCE)
    set(_qmllint_selection --qmllint "${_qmllint_tool}")
    message(STATUS "Strict QML validation tool: ${_qmllint_tool}")
endif()
# A missing qmllint must not remove the target or make running it successful.
set(QMLLINT_AVAILABLE TRUE)

function(add_qmllint_target target_name)
    set(qml_files ${ARGN})
    list(FILTER qml_files INCLUDE REGEX "\\.qml$")
    if(NOT qml_files)
        message(FATAL_ERROR "No QML files supplied for ${target_name} validation")
    endif()
    list(LENGTH qml_files qml_count)
    message(STATUS "Strict QML validation scope: ${target_name}, ${qml_count} module files")
    if(NOT TARGET marathon-qml-validation)
        add_custom_target(marathon-qml-validation)
    endif()
    if(NOT Python3_Interpreter_FOUND)
        add_custom_target(${target_name}_validate_qml
            COMMAND "${CMAKE_COMMAND}" -E echo "Python 3 and Qt 6 qmllint are required"
            COMMAND "${CMAKE_COMMAND}" -E false VERBATIM)
    else()
        set(import_args -I "${CMAKE_SOURCE_DIR}")
        if(DEFINED KEEL_QML AND NOT KEEL_QML STREQUAL "")
            list(APPEND import_args -I "${KEEL_QML}")
        endif()
        add_custom_target(${target_name}_validate_qml
            COMMAND "${Python3_EXECUTABLE}" "${_MARATHON_QML_VALIDATOR}"
                ${_qmllint_selection} --build-dir "${CMAKE_BINARY_DIR}"
                ${import_args} ${qml_files}
            WORKING_DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}"
            COMMENT "Strict QML validation for ${target_name}" VERBATIM)
    endif()
    if(TARGET ${target_name})
        add_dependencies(${target_name}_validate_qml ${target_name})
    endif()
    if(TARGET qmllint-types)
        add_dependencies(${target_name}_validate_qml qmllint-types)
    endif()
    add_dependencies(marathon-qml-validation ${target_name}_validate_qml)
endfunction()

function(validate_qml_directory target_name directory_path)
    file(GLOB_RECURSE qml_files CONFIGURE_DEPENDS "${directory_path}/*.qml")
    add_qmllint_target(${target_name} ${qml_files})
endfunction()
