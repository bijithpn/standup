# Project-level configuration.
cmake_minimum_required(VERSION 3.14)
project(BreakMate LANGUAGES CXX)

set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# The name of the executable created for the application. Change this to change
# the on-disk name of your application.
set(BINARY_NAME "BreakMateApp")

# Decode FLUTTER_DART_DEFINES (base64-encoded, comma-separated) to extract FLUTTER_FLAVOR
# when passed via --dart-define=FLUTTER_FLAVOR=dev from 'flutter run' or VS Code launch.
if(DEFINED FLUTTER_DART_DEFINES AND NOT FLUTTER_DART_DEFINES STREQUAL "")
  string(REPLACE "," ";" _dart_defines_list "${FLUTTER_DART_DEFINES}")
  foreach(_define IN LISTS _dart_defines_list)
    string(BASE64_DECODE _decoded "${_define}")
    if(_decoded MATCHES "^FLUTTER_FLAVOR=(.+)$")
      set(FLUTTER_FLAVOR "${CMAKE_MATCH_1}")
    endif()
  endforeach()
endif()

if(FLUTTER_FLAVOR STREQUAL "dev")
  set(FLAVOR_APP_NAME "BreakMate Dev")
  configure_file("${CMAKE_CURRENT_SOURCE_DIR}/runner/resources/app_icon_dev.ico" "${CMAKE_CURRENT_SOURCE_DIR}/runner/resources/app_icon.ico" COPYONLY)
else()
  set(FLAVOR_APP_NAME "BreakMate")
  configure_file("${CMAKE_CURRENT_SOURCE_DIR}/runner/resources/app_icon_prod.ico" "${CMAKE_CURRENT_SOURCE_DIR}/runner/resources/app_icon.ico" COPYONLY)
endif()

add_compile_definitions("FLAVOR_APP_NAME=\"${FLAVOR_APP_NAME}\"")

# Explicitly opt in to modern CMake behaviors to avoid warnings with recent
# versions of CMake.
cmake_policy(VERSION 3.14...3.25)

# Define build configuration option.
get_property(IS_MULTICONFIG GLOBAL PROPERTY GENERATOR_IS_MULTI_CONFIG)
if(IS_MULTICONFIG)
  set(CMAKE_CONFIGURATION_TYPES "Debug;Profile;Release"
    CACHE STRING "" FORCE)
else()
  if(NOT CMAKE_BUILD_TYPE AND NOT CMAKE_CONFIGURATION_TYPES)
    set(CMAKE_BUILD_TYPE "Debug" CACHE
      STRING "Flutter build mode" FORCE)
    set_property(CACHE CMAKE_BUILD_TYPE PROPERTY STRINGS
      "Debug" "Profile" "Release")
  endif()
endif()
# Define settings for the Profile build mode.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Use Unicode for all projects.
add_definitions(-DUNICODE -D_UNICODE -D_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS)

# Compilation settings that should be applied to most targets.
#
# Be cautious about adding new options here, as plugins use this function by
# default. In most cases, you should add new options to specific targets instead
# of modifying this function.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100")
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
  target_compile_definitions(${TARGET} PRIVATE "_SILENCE_EXPERIMENTAL_COROUTINE_DEPRECATION_WARNINGS")
endfunction()

# Flutter library and tool build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application build; see runner/CMakeLists.txt.
add_subdirectory("runner")


# Generated plugin build rules, which manage building the plugins and adding
# them to the application.
include(flutter/generated_plugins.cmake)


# === Installation ===
# Support files are copied into place next to the executable, so that it can
# run in place. This is done instead of making a separate bundle (as on Linux)
# so that building and running from within Visual Studio will work.
set(BUILD_BUNDLE_DIR "$<TARGET_FILE_DIR:${BINARY_NAME}>")
set(INSTALL_BUNDLE_DATA_DIR "${BUILD_BUNDLE_DIR}/data")
set(INSTALL_BUNDLE_LIB_DIR "${BUILD_BUNDLE_DIR}")

# Make the "install" step default, as it's required to run.
set(CMAKE_VS_INCLUDE_INSTALL_TO_DEFAULT_BUILD 1)

install(TARGETS ${BINARY_NAME} RUNTIME DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

# Install the tray icon so the app can reference it at runtime
install(FILES "${CMAKE_CURRENT_SOURCE_DIR}/runner/resources/app_icon.ico"
  DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_ICU_DATA_FILE}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime)

install(FILES "${FLUTTER_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime)

if(PLUGIN_BUNDLED_LIBRARIES)
  install(FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime)
endif()

# Copy the native assets provided by the build.dart from all packages.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")
install(DIRECTORY "${NATIVE_ASSETS_DIR}"
   DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
   COMPONENT Runtime)

# Fully re-copy the assets directory on each build to avoid having stale files
# from a previous install.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")
install(CODE "
  file(REMOVE_RECURSE \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\")
  " COMPONENT Runtime)
install(DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}" COMPONENT Runtime)

# Install the AOT library on non-Debug builds only.
install(FILES "${AOT_LIBRARY}" DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime)
