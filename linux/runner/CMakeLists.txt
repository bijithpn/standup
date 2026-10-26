cmake_minimum_required(VERSION 3.13)
project(runner LANGUAGES CXX)

# Define the application target. To change its name, change BINARY_NAME in the
# top-level CMakeLists.txt, not the value here, or `flutter run` will no longer
# work.
#
# Any new source files that you add to the application should be added here.
add_executable(${BINARY_NAME}
  "main.cc"
  "my_application.cc"
  "bridges.cc"
  "enhancements.cc"
  "secondary_windows.cc"
  "system_info.cc"
  "window_channel.cc"
  "${FLUTTER_MANAGED_DIR}/generated_plugin_registrant.cc"
)

# Apply the standard set of build settings. This can be removed for applications
# that need different build settings.
apply_standard_settings(${BINARY_NAME})

# Add preprocessor definitions for the application ID.
add_definitions(-DAPPLICATION_ID="${APPLICATION_ID}")

# Add dependency libraries. Add any application-specific dependencies here.
target_link_libraries(${BINARY_NAME} PRIVATE flutter)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::GTK)

# Active-window and window-list queries talk to the X server directly.
find_package(PkgConfig REQUIRED)
pkg_check_modules(X11 REQUIRED IMPORTED_TARGET x11)
target_link_libraries(${BINARY_NAME} PRIVATE PkgConfig::X11)

# The bridge sources are built without -Werror. They have only been syntax-checked
# against the GTK3 / flutter_linux headers, not built in CI, so a stray warning
# from a different compiler or GTK version should not break the whole build.
# Drop this once they build warning-free on your toolchain.
set_source_files_properties(
  "bridges.cc" "enhancements.cc" "secondary_windows.cc" "system_info.cc" "window_channel.cc"
  PROPERTIES COMPILE_OPTIONS "-Wno-error")

target_include_directories(${BINARY_NAME} PRIVATE "${CMAKE_SOURCE_DIR}")
