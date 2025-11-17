# PlatformConfig.cmake - Platform-specific configurations for Echoelmusic

# ===========================
# Windows Configuration
# ===========================
if(WIN32)
    message(STATUS "Configuring for Windows...")

    # Windows-specific compiler flags
    if(MSVC)
        # Enable multiprocessor compilation
        add_compile_options(/MP)

        # Disable specific warnings
        add_compile_options(/wd4100)  # Unreferenced parameter
        add_compile_options(/wd4458)  # Declaration hides class member
        add_compile_options(/wd4996)  # Deprecated functions

        # Enable function-level linking
        add_compile_options(/Gy)

        # Runtime library: Multi-threaded DLL
        set(CMAKE_MSVC_RUNTIME_LIBRARY "MultiThreaded$<$<CONFIG:Debug>:Debug>DLL")
    endif()

    # Windows-specific definitions
    add_definitions(
        -D_WINDOWS
        -D_CRT_SECURE_NO_WARNINGS
        -DNOMINMAX
        -DWIN32_LEAN_AND_MEAN
    )

    # Windows audio backends
    set(WINDOWS_AUDIO_BACKENDS "WASAPI;ASIO;DirectSound")
    message(STATUS "Windows Audio Backends: ${WINDOWS_AUDIO_BACKENDS}")

    # Windows installer support
    set(CPACK_GENERATOR "NSIS;ZIP")
    set(CPACK_NSIS_MODIFY_PATH ON)
    set(CPACK_NSIS_DISPLAY_NAME "Echoelmusic")
    set(CPACK_NSIS_PACKAGE_NAME "Echoelmusic")

endif()

# ===========================
# macOS Configuration
# ===========================
if(APPLE)
    message(STATUS "Configuring for macOS/iOS...")

    # Universal Binary (Apple Silicon + Intel)
    if(NOT CMAKE_OSX_ARCHITECTURES)
        set(CMAKE_OSX_ARCHITECTURES "arm64;x86_64" CACHE STRING "" FORCE)
        message(STATUS "Building Universal Binary (arm64 + x86_64)")
    endif()

    # Minimum deployment target
    if(NOT CMAKE_OSX_DEPLOYMENT_TARGET)
        set(CMAKE_OSX_DEPLOYMENT_TARGET "10.13" CACHE STRING "" FORCE)
        message(STATUS "macOS Deployment Target: ${CMAKE_OSX_DEPLOYMENT_TARGET}")
    endif()

    # macOS-specific compiler flags
    add_compile_options(
        -Wno-deprecated-declarations
        -Wno-nullability-completeness
        -Wno-unknown-warning-option
    )

    # macOS frameworks
    find_library(COCOA_LIBRARY Cocoa REQUIRED)
    find_library(COREAUDIO_LIBRARY CoreAudio REQUIRED)
    find_library(COREMIDI_LIBRARY CoreMIDI REQUIRED)
    find_library(AUDIOTOOLBOX_LIBRARY AudioToolbox REQUIRED)
    find_library(ACCELERATE_LIBRARY Accelerate REQUIRED)
    find_library(IOKIT_LIBRARY IOKit REQUIRED)
    find_library(CARBON_LIBRARY Carbon REQUIRED)

    set(MACOS_FRAMEWORKS
        ${COCOA_LIBRARY}
        ${COREAUDIO_LIBRARY}
        ${COREMIDI_LIBRARY}
        ${AUDIOTOOLBOX_LIBRARY}
        ${ACCELERATE_LIBRARY}
        ${IOKIT_LIBRARY}
        ${CARBON_LIBRARY}
    )

    message(STATUS "macOS Frameworks: Found")

    # Code signing (optional)
    set(CMAKE_XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "Developer ID Application" CACHE STRING "" FORCE)
    set(CMAKE_XCODE_ATTRIBUTE_DEVELOPMENT_TEAM "" CACHE STRING "Your Team ID")

    # macOS bundle configuration
    set(MACOSX_BUNDLE_BUNDLE_NAME "Echoelmusic")
    set(MACOSX_BUNDLE_BUNDLE_VERSION "1.0.0")
    set(MACOSX_BUNDLE_SHORT_VERSION_STRING "1.0")
    set(MACOSX_BUNDLE_LONG_VERSION_STRING "1.0.0")
    set(MACOSX_BUNDLE_COPYRIGHT "Copyright © 2025 Echoelmusic")
    set(MACOSX_BUNDLE_GUI_IDENTIFIER "com.echoelmusic.plugin")
    set(MACOSX_BUNDLE_ICON_FILE "Icon.icns")

    # macOS installer
    set(CPACK_GENERATOR "DragNDrop;TGZ")
    set(CPACK_DMG_VOLUME_NAME "Echoelmusic")
    set(CPACK_DMG_FORMAT "UDBZ")

endif()

# ===========================
# Linux Configuration
# ===========================
if(UNIX AND NOT APPLE)
    message(STATUS "Configuring for Linux...")

    # Linux-specific compiler flags
    add_compile_options(
        -Wno-deprecated-declarations
        -Wno-sign-conversion
        -Wno-shadow
        -Wno-switch-enum
    )

    # Find required Linux packages
    find_package(PkgConfig REQUIRED)

    # ALSA (required for audio)
    pkg_check_modules(ALSA REQUIRED alsa)
    if(ALSA_FOUND)
        message(STATUS "ALSA: Found (${ALSA_VERSION})")
        include_directories(${ALSA_INCLUDE_DIRS})
        link_directories(${ALSA_LIBRARY_DIRS})
    endif()

    # FreeType (required for fonts)
    pkg_check_modules(FREETYPE REQUIRED freetype2)
    if(FREETYPE_FOUND)
        message(STATUS "FreeType: Found (${FREETYPE_VERSION})")
        include_directories(${FREETYPE_INCLUDE_DIRS})
        link_directories(${FREETYPE_LIBRARY_DIRS})
    endif()

    # X11 (required for GUI)
    find_package(X11 REQUIRED)
    if(X11_FOUND)
        message(STATUS "X11: Found")
        include_directories(${X11_INCLUDE_DIR})
    endif()

    # OpenGL (required for graphics)
    find_package(OpenGL REQUIRED)
    if(OPENGL_FOUND)
        message(STATUS "OpenGL: Found")
        include_directories(${OPENGL_INCLUDE_DIR})
    endif()

    # Optional: JACK
    if(ENABLE_JACK)
        pkg_check_modules(JACK jack)
        if(JACK_FOUND)
            message(STATUS "JACK: Found (${JACK_VERSION})")
            add_definitions(-DJUCE_JACK=1)
        endif()
    endif()

    # Optional: PulseAudio
    if(ENABLE_PULSEAUDIO)
        pkg_check_modules(PULSEAUDIO libpulse)
        if(PULSEAUDIO_FOUND)
            message(STATUS "PulseAudio: Found (${PULSEAUDIO_VERSION})")
            add_definitions(-DJUCE_USE_PULSEAUDIO=1)
        endif()
    endif()

    # Linux installer
    set(CPACK_GENERATOR "DEB;RPM;TGZ")
    set(CPACK_DEBIAN_PACKAGE_MAINTAINER "Echoelmusic <info@echoelmusic.com>")
    set(CPACK_DEBIAN_PACKAGE_DEPENDS "libasound2, libfreetype6, libx11-6")
    set(CPACK_RPM_PACKAGE_LICENSE "Proprietary")
    set(CPACK_RPM_PACKAGE_REQUIRES "alsa-lib, freetype, libX11")

endif()

# ===========================
# iOS Configuration
# ===========================
if(IOS)
    message(STATUS "Configuring for iOS...")

    set(CMAKE_OSX_SYSROOT "iphoneos")
    set(CMAKE_OSX_ARCHITECTURES "arm64")
    set(CMAKE_XCODE_ATTRIBUTE_ONLY_ACTIVE_ARCH NO)

    # iOS-specific frameworks
    find_library(UIKIT_LIBRARY UIKit REQUIRED)
    find_library(COREAUDIO_LIBRARY CoreAudio REQUIRED)
    find_library(AVFOUNDATION_LIBRARY AVFoundation REQUIRED)

    set(IOS_FRAMEWORKS
        ${UIKIT_LIBRARY}
        ${COREAUDIO_LIBRARY}
        ${AVFOUNDATION_LIBRARY}
    )

    message(STATUS "iOS Frameworks: Found")

endif()

# ===========================
# Android Configuration
# ===========================
if(ANDROID)
    message(STATUS "Configuring for Android...")

    # Android-specific settings
    set(CMAKE_CXX_FLAGS "${CMAKE_CXX_FLAGS} -fexceptions -frtti")

    # Oboe (low-latency audio for Android)
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/ThirdParty/oboe")
        add_subdirectory(ThirdParty/oboe)
        message(STATUS "Oboe: Found (using low-latency audio)")
    endif()

endif()

# ===========================
# Compiler-specific warnings
# ===========================

if(MSVC)
    # MSVC-specific warning suppressions
    add_compile_definitions(
        _SILENCE_CXX17_CODECVT_HEADER_DEPRECATION_WARNING
        _SILENCE_ALL_CXX17_DEPRECATION_WARNINGS
    )
elseif(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    # GCC/Clang warning suppressions
    add_compile_options(
        -Wno-unused-parameter
        -Wno-unused-variable
        -Wno-unused-but-set-variable
    )
endif()

# ===========================
# Universal Settings
# ===========================

# Plugin formats per platform
if(WIN32)
    set(AVAILABLE_FORMATS "VST3;Standalone")
elseif(APPLE AND NOT IOS)
    set(AVAILABLE_FORMATS "VST3;AU;Standalone")
elseif(IOS)
    set(AVAILABLE_FORMATS "AUv3;Standalone")
elseif(UNIX)
    set(AVAILABLE_FORMATS "VST3;Standalone")
endif()

message(STATUS "Available Plugin Formats: ${AVAILABLE_FORMATS}")

# CPack configuration
set(CPACK_PACKAGE_NAME "Echoelmusic")
set(CPACK_PACKAGE_VENDOR "Echoelmusic")
set(CPACK_PACKAGE_DESCRIPTION_SUMMARY "Professional Audio Plugin with Biofeedback")
set(CPACK_PACKAGE_VERSION_MAJOR "1")
set(CPACK_PACKAGE_VERSION_MINOR "0")
set(CPACK_PACKAGE_VERSION_PATCH "0")
set(CPACK_RESOURCE_FILE_LICENSE "${CMAKE_CURRENT_SOURCE_DIR}/LICENSE")
set(CPACK_RESOURCE_FILE_README "${CMAKE_CURRENT_SOURCE_DIR}/README.md")

include(CPack)

message(STATUS "Platform configuration complete")
