cmake_minimum_required(VERSION 3.21)
project(MarathonNativeIconRuntime LANGUAGES NONE)
# Use the production generator and install layout without a compositor build.
add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../../../marathon-icon-theme" icons)
