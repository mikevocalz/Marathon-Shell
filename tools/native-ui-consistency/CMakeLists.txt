cmake_minimum_required(VERSION 3.21)
if(CMAKE_SOURCE_DIR STREQUAL CMAKE_CURRENT_SOURCE_DIR)
    project(MarathonUIConsistency LANGUAGES NONE)
    enable_testing()
endif()
find_package(Python3 REQUIRED COMPONENTS Interpreter)
add_test(NAME NativeUI_ConsistencyRules COMMAND "${Python3_EXECUTABLE}"
    "${CMAKE_CURRENT_SOURCE_DIR}/test_check_ui.py")
add_test(NAME NativeUI_ConsistencyInventory COMMAND "${Python3_EXECUTABLE}"
    "${CMAKE_CURRENT_SOURCE_DIR}/check_ui.py")
