# ---------------------------------------------------------------------------
# CMake 4.x compatibility.
#
# FlutterFire bundles the Firebase C++ SDK (e.g. firebase_cpp_sdk_windows
# 12.x) which is extracted into the build directory at configure time. That
# SDK's CMakeLists.txt declares `cmake_minimum_required(VERSION 3.1)`, which
# CMake 4.x no longer accepts ("Compatibility with CMake < 3.5 has been
# removed"). CMAKE_POLICY_VERSION_MINIMUM is Kitware's official mechanism for
# consuming such dependencies WITHOUT modifying them (the extracted SDK is
# generated content and must stay untouched).
#
# This must be set AT THE TOP so it applies to all added subdirectories.
# ---------------------------------------------------------------------------
set(CMAKE_POLICY_VERSION_MINIMUM 3.5)

# Project-level configuration.
cmake_minimum_required(VERSION 3.14)
project(movie_gpt_app_new LANGUAGES CXX)

# Application executable name.
set(BINARY_NAME "movie_gpt_app_new")

# Use modern CMake policies.
cmake_policy(VERSION 3.14...3.25)

# Build configurations.
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

# Profile configuration.
set(CMAKE_EXE_LINKER_FLAGS_PROFILE "${CMAKE_EXE_LINKER_FLAGS_RELEASE}")
set(CMAKE_SHARED_LINKER_FLAGS_PROFILE "${CMAKE_SHARED_LINKER_FLAGS_RELEASE}")
set(CMAKE_C_FLAGS_PROFILE "${CMAKE_C_FLAGS_RELEASE}")
set(CMAKE_CXX_FLAGS_PROFILE "${CMAKE_CXX_FLAGS_RELEASE}")

# Unicode.
add_definitions(-DUNICODE -D_UNICODE)

# Standard compilation settings.
function(APPLY_STANDARD_SETTINGS TARGET)
  target_compile_features(${TARGET} PUBLIC cxx_std_17)
  target_compile_options(${TARGET} PRIVATE /W4 /WX /wd"4100")
  target_compile_options(${TARGET} PRIVATE /EHsc)
  target_compile_definitions(${TARGET} PRIVATE "_HAS_EXCEPTIONS=0")
  target_compile_definitions(${TARGET} PRIVATE "$<$<CONFIG:Debug>:_DEBUG>")
endfunction()

# Flutter build rules.
set(FLUTTER_MANAGED_DIR "${CMAKE_CURRENT_SOURCE_DIR}/flutter")
add_subdirectory(${FLUTTER_MANAGED_DIR})

# Application.
add_subdirectory("runner")

# Flutter plugins.
include(flutter/generated_plugins.cmake)

# ============================================================
# INSTALLATION
# ============================================================

# IMPORTANT:
# Keep the Flutter bundle inside the project's build directory.
# Do NOT install into C:\Program Files.
#
# For example:
# build\windows\x64\runner\Debug\
# build\windows\x64\runner\Profile\
# build\windows\x64\runner\Release\

set(BUILD_BUNDLE_DIR "${CMAKE_CURRENT_BINARY_DIR}/runner/$<CONFIG>")

# Force CMake to use the Flutter build output directory.
set(CMAKE_INSTALL_PREFIX
    "${BUILD_BUNDLE_DIR}"
    CACHE PATH "Flutter Windows bundle output directory"
    FORCE)

set(INSTALL_BUNDLE_DATA_DIR "${CMAKE_INSTALL_PREFIX}/data")
set(INSTALL_BUNDLE_LIB_DIR "${CMAKE_INSTALL_PREFIX}")

# Install application executable.
install(
  TARGETS ${BINARY_NAME}
  RUNTIME DESTINATION "${CMAKE_INSTALL_PREFIX}"
  COMPONENT Runtime
)

# Install ICU data.
install(
  FILES "${FLUTTER_ICU_DATA_FILE}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime
)

# Install Flutter library.
install(
  FILES "${FLUTTER_LIBRARY}"
  DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime
)

# Install bundled plugin libraries.
if(PLUGIN_BUNDLED_LIBRARIES)
  install(
    FILES "${PLUGIN_BUNDLED_LIBRARIES}"
    DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
    COMPONENT Runtime
  )
endif()

# Copy native assets.
set(NATIVE_ASSETS_DIR "${PROJECT_BUILD_DIR}native_assets/windows/")

install(
  DIRECTORY "${NATIVE_ASSETS_DIR}"
  DESTINATION "${INSTALL_BUNDLE_LIB_DIR}"
  COMPONENT Runtime
)

# Flutter assets.
set(FLUTTER_ASSET_DIR_NAME "flutter_assets")

install(
  CODE "
    file(
      REMOVE_RECURSE
      \"${INSTALL_BUNDLE_DATA_DIR}/${FLUTTER_ASSET_DIR_NAME}\"
    )
  "
  COMPONENT Runtime
)

install(
  DIRECTORY "${PROJECT_BUILD_DIR}/${FLUTTER_ASSET_DIR_NAME}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  COMPONENT Runtime
)

# Install AOT library for Profile and Release.
install(
  FILES "${AOT_LIBRARY}"
  DESTINATION "${INSTALL_BUNDLE_DATA_DIR}"
  CONFIGURATIONS Profile;Release
  COMPONENT Runtime
)