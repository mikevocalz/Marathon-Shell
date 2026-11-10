cmake_minimum_required(VERSION 3.21)
project(BlackBerryApkResearch NONE)
enable_testing()
find_package(Python3 REQUIRED COMPONENTS Interpreter)
add_test(NAME BlackBerry_ApkResearch
    COMMAND ${Python3_EXECUTABLE} ${CMAKE_CURRENT_SOURCE_DIR}/test_apk_lab.py)
set_tests_properties(BlackBerry_ApkResearch PROPERTIES TIMEOUT 60)
