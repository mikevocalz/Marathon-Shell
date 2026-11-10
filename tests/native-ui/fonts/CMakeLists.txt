cmake_minimum_required(VERSION 3.21)
project(MarathonNativeFontRuntime LANGUAGES NONE)
# Install the same font files and Sail Sans aliases as a Marathon image.
add_subdirectory("${CMAKE_CURRENT_SOURCE_DIR}/../../../marathon-fonts" fonts)
