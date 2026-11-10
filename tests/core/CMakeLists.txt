# Marathon Core Test Suite

cmake_minimum_required(VERSION 3.21)
enable_testing()

find_package(Qt6 REQUIRED COMPONENTS Test Core DBus Gui Network Qml)

# The real Rust/CXX-Qt installer must stay responsive while AppStore1 is stalled.
find_program(DBUS_RUN_SESSION dbus-run-session REQUIRED)
add_executable(test_core_appinstaller test_appinstaller.cpp)
set_target_properties(test_core_appinstaller PROPERTIES AUTOMOC ON)
target_link_libraries(test_core_appinstaller Qt6::Test Qt6::Core Qt6::DBus Qt6::Gui marathon_app_native)
add_test(NAME Core_AppInstaller
    COMMAND ${DBUS_RUN_SESSION} -- $<TARGET_FILE:test_core_appinstaller>)
set_tests_properties(Core_AppInstaller PROPERTIES TIMEOUT 90)

add_executable(test_core_taskslaunch test_taskslaunch.cpp)
set_target_properties(test_core_taskslaunch PROPERTIES AUTOMOC ON)
target_link_libraries(test_core_taskslaunch Qt6::Test marathon_shell_native)
add_test(NAME Core_TasksLaunch COMMAND test_core_taskslaunch)
set_tests_properties(Core_TasksLaunch PROPERTIES TIMEOUT 60)

# Shell bounds and scale follow the window through resize and lifetime changes.
add_executable(test_core_screenmetrics
    test_screenmetrics.cpp
    ../../shell/src/managers/screenmetrics.cpp
)
set_target_properties(test_core_screenmetrics PROPERTIES AUTOMOC ON)
target_link_libraries(test_core_screenmetrics Qt6::Test Qt6::Gui Qt6::Qml)
target_include_directories(test_core_screenmetrics PRIVATE ${CMAKE_SOURCE_DIR}/shell/src)
add_test(NAME Core_ScreenMetrics COMMAND test_core_screenmetrics)
set_tests_properties(Core_ScreenMetrics PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")

# Permissions1 authorisation: self-only, except Settings

# Marathon.Platform: the runner's service clients under their QML names
add_executable(test_core_platformtypes
    test_platformtypes.cpp
    ../../tools/marathon-app-runner/platformtypes.cpp
)
target_link_libraries(test_core_platformtypes Qt6::Test Qt6::Core Qt6::Qml)
target_include_directories(test_core_platformtypes PRIVATE
    ${CMAKE_SOURCE_DIR}/tools/marathon-app-runner
)
add_test(NAME Core_PlatformTypes COMMAND test_core_platformtypes)

# WAKE_ON_KEY: a key wakes a blanked screen without reaching apps
add_executable(test_core_wakeonkeyfilter
    test_wakeonkeyfilter.cpp
    ../../shell/src/services/wakeonkeyfilter.cpp
)
set_target_properties(test_core_wakeonkeyfilter PROPERTIES AUTOMOC ON)
target_link_libraries(test_core_wakeonkeyfilter Qt6::Test Qt6::Gui Qt6::GuiPrivate)
target_include_directories(test_core_wakeonkeyfilter PRIVATE ${CMAKE_SOURCE_DIR}/shell/src)
add_test(NAME Core_WakeOnKeyFilter COMMAND test_core_wakeonkeyfilter)
set_tests_properties(Core_WakeOnKeyFilter PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")

# Sound names format locally, shared by the shell and the app runner


# Wake touch hygiene: no touch for 100 ms after wake, none until a fresh one
add_executable(test_core_waketouchfilter
    test_waketouchfilter.cpp
    ../../shell/src/services/waketouchfilter.cpp
)
set_target_properties(test_core_waketouchfilter PROPERTIES AUTOMOC ON)
target_link_libraries(test_core_waketouchfilter Qt6::Test Qt6::Gui Qt6::Qml Qt6::Quick)
target_include_directories(test_core_waketouchfilter PRIVATE ${CMAKE_SOURCE_DIR}/shell/src)
add_test(NAME Core_WakeTouchFilter COMMAND test_core_waketouchfilter)
set_tests_properties(Core_WakeTouchFilter PROPERTIES ENVIRONMENT "QT_QPA_PLATFORM=offscreen")
