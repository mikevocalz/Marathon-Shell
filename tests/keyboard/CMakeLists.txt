# Keyboard Test Suite

cmake_minimum_required(VERSION 3.21)
enable_testing()

find_package(Qt6 REQUIRED COMPONENTS Test Core)

# Real hardware-key dispatch through the shell's input method engine.
find_package(Qt6 REQUIRED COMPONENTS Gui Qml Quick)
add_executable(test_keyboard_hardwarecapitalization
    cpp/test_hardwarecapitalization.cpp
    ../../shell/src/managers/marathoninputmethodengine.cpp
)
set_target_properties(test_keyboard_hardwarecapitalization PROPERTIES AUTOMOC ON)
target_link_libraries(test_keyboard_hardwarecapitalization
    Qt6::Test Qt6::Gui Qt6::GuiPrivate Qt6::Qml Qt6::Quick marathon_shell_native)
target_include_directories(test_keyboard_hardwarecapitalization PRIVATE
    ${CMAKE_SOURCE_DIR}/shell/src)
add_test(NAME Keyboard_HardwareCapitalization COMMAND test_keyboard_hardwarecapitalization)
set_tests_properties(Keyboard_HardwareCapitalization PROPERTIES ENVIRONMENT
    "QT_QPA_PLATFORM=offscreen;QT_QUICK_BACKEND=software;QT_IM_MODULE=none")

# The real keyboard QML and InputContext typing into a text field; registered
# in tests/CMakeLists.txt, which finds Keel's Silica for the keys.
find_package(Qt6 COMPONENTS QuickTest Quick QUIET)
if(Qt6QuickTest_FOUND)
    add_executable(test_keyboard_qml
        qml/main.cpp
        ../../shell/src/services/inputcontext.cpp
    )
    target_link_libraries(test_keyboard_qml Qt6::QuickTest Qt6::Quick marathon_shell_native)
    target_include_directories(test_keyboard_qml PRIVATE
        ${CMAKE_SOURCE_DIR}/shell
        ${CMAKE_SOURCE_DIR}/shell/src
    )
else()
    message(WARNING "Qt6QuickTest not found, skipping Keyboard QML tests")
endif()

# The real keyboard typing into a Qt app over text-input v2 through Qt's
# compositor, as on a device; registered in tests/CMakeLists.txt.
find_package(Qt6 COMPONENTS WaylandCompositor QUIET)
if(TARGET Qt6::WaylandCompositor)
    add_executable(test_keyboard_textinput
        cpp/test_keyboardtextinput.cpp
        ../../shell/src/services/inputcontext.cpp
    )
    target_link_libraries(test_keyboard_textinput
        Qt6::Test Qt6::Quick Qt6::WaylandCompositor marathon_shell_native)
    target_include_directories(test_keyboard_textinput PRIVATE
        ${CMAKE_SOURCE_DIR}/shell
        ${CMAKE_SOURCE_DIR}/shell/src
    )
    target_compile_definitions(test_keyboard_textinput PRIVATE
        MARATHON_KEYBOARD_QML="${CMAKE_SOURCE_DIR}/shell/qml/keyboard/Core/MarathonKeyboard.qml")
endif()
