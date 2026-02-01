cmake_minimum_required(VERSION 3.22)

project(Echoelmusic VERSION 1.2.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# ===========================
# Performance Optimizations
# ===========================

# SIMD Support - 2-8x faster DSP processing
if(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|AMD64|amd64")
    message(STATUS "Enabling AVX2/SSE4.2 SIMD optimizations (x86_64)")
    if(MSVC)
        add_compile_options(/arch:AVX2 /fp:fast)
    else()
        add_compile_options(-mavx2 -mfma -msse4.2 -ffast-math)
    endif()
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "arm|aarch64|ARM64")
    message(STATUS "Enabling ARM NEON SIMD optimizations")
    if(NOT MSVC)
        add_compile_options(-march=armv8-a+simd -ffast-math)
    endif()
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "i686|i386")
    message(STATUS "Enabling SSE2 SIMD optimizations (x86)")
    if(MSVC)
        add_compile_options(/arch:SSE2 /fp:fast)
    else()
        add_compile_options(-msse2 -ffast-math)
    endif()
else()
    message(STATUS "CPU: ${CMAKE_SYSTEM_PROCESSOR} - No SIMD optimizations")
endif()

# Link-Time Optimization (LTO) - additional 10-20% performance
if(CMAKE_BUILD_TYPE STREQUAL "Release")
    include(CheckIPOSupported)
    check_ipo_supported(RESULT ipo_supported OUTPUT ipo_output)
    if(ipo_supported)
        message(STATUS "Link-Time Optimization (LTO) enabled")
        set(CMAKE_INTERPROCEDURAL_OPTIMIZATION TRUE)
    else()
        message(STATUS "LTO not supported: ${ipo_output}")
    endif()
endif()

# Release mode optimizations
if(CMAKE_BUILD_TYPE STREQUAL "Release")
    if(MSVC)
        add_compile_options(/O2 /Ob2 /Oi /Ot /GL)
    else()
        add_compile_options(-O3 -march=native)
    endif()
    message(STATUS "Release mode optimizations enabled")
endif()

# ===========================
# Platform Detection
# ===========================

if(WIN32)
    set(PLATFORM_WINDOWS TRUE)
    message(STATUS "Platform: Windows")
elseif(APPLE)
    set(PLATFORM_MACOS TRUE)
    message(STATUS "Platform: macOS/iOS")
elseif(UNIX AND NOT APPLE)
    set(PLATFORM_LINUX TRUE)
    message(STATUS "Platform: Linux")
elseif(ANDROID)
    set(PLATFORM_ANDROID TRUE)
    message(STATUS "Platform: Android")
endif()

# ===========================
# Build Options
# ===========================

option(BUILD_VST3 "Build VST3 plugin" ON)
option(BUILD_AU "Build Audio Units plugin" ON)
option(BUILD_AAX "Build AAX plugin for Pro Tools" ON)
option(BUILD_AUv3 "Build AUv3 plugin for iOS" ON)
option(BUILD_LV2 "Build LV2 plugin for Linux" OFF)  # Disabled: linker segfault, use VST3 instead
option(BUILD_CLAP "Build CLAP plugin" ON)
option(BUILD_STANDALONE "Build standalone application" ON)

option(BUILD_ANDROID_APP "Build Android app" OFF)
option(BUILD_WINDOWS_VST3 "Build Windows VST3" ON)
option(BUILD_LINUX_VST3 "Build Linux VST3" ON)

option(ENABLE_ASIO "Enable ASIO support (Windows)" ON)
option(ENABLE_WASAPI "Enable WASAPI support (Windows)" ON)
option(ENABLE_DIRECTSOUND "Enable DirectSound (Windows)" ON)

option(ENABLE_ALSA "Enable ALSA support (Linux)" ON)
option(ENABLE_JACK "Enable JACK support (Linux)" ON)   # Enabled for professional audio (<10ms latency)
option(ENABLE_PIPEWIRE "Enable PipeWire support (Linux)" ON)  # Modern Linux audio (<15ms latency)
option(ENABLE_PULSEAUDIO "Enable PulseAudio (Linux)" OFF)  # Deprecated - use PipeWire instead

option(ENABLE_ANDROID_OBOE "Enable Oboe (Android)" ON)
option(ENABLE_ANDROID_AAUDIO "Enable AAudio (Android)" ON)

# ===========================
# JUCE Framework - REMOVED (2026-01-13)
# ===========================
# JUCE has been completely removed from this project.
# All DSP is now handled by EchoelmusicDSP.h (JUCE-free, MIT license)
#
# For desktop plugins, use iPlug2 (MIT license, FREE):
#   cmake .. -DUSE_IPLUG2=ON

option(USE_JUCE "DEPRECATED - JUCE has been removed" OFF)

if(USE_JUCE)
    message(FATAL_ERROR "
╔══════════════════════════════════════════════════════════════════╗
║  JUCE SUPPORT HAS BEEN REMOVED                                    ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  This project no longer uses JUCE.                               ║
║  All DSP is now handled by EchoelmusicDSP.h (MIT license)        ║
║                                                                   ║
║  For desktop plugins, use iPlug2 instead:                        ║
║    cmake .. -DUSE_IPLUG2=ON                                      ║
║                                                                   ║
║  Benefits:                                                        ║
║  • 100% JUCE-free codebase                                       ║
║  • MIT license (no fees)                                         ║
║  • Smaller binary size                                           ║
║  • Native performance on all platforms                           ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
")
else()
    message(STATUS "JUCE Framework: REMOVED (using native EchoelmusicDSP)")
    message(STATUS "  → EchoelmusicDSP.h for all DSP operations")
    message(STATUS "  → iPlug2 available for desktop plugins")
endif()

# RECOMMENDED: iPlug2 for JUCE-free desktop plugins (MIT license, FREE)
option(USE_IPLUG2 "Use iPlug2 framework (MIT license, JUCE-free) - RECOMMENDED" OFF)
if(USE_IPLUG2)
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/ThirdParty/iPlug2")
        message(STATUS "iPlug2 Framework: ENABLED (MIT License - Free!)")
        # Add Desktop plugin build
        add_subdirectory(Sources/Desktop)
    else()
        message(STATUS "")
        message(STATUS "╔══════════════════════════════════════════════════════════╗")
        message(STATUS "║  iPlug2 not found! To enable desktop plugins:            ║")
        message(STATUS "║                                                          ║")
        message(STATUS "║  git clone https://github.com/iPlug2/iPlug2 \\            ║")
        message(STATUS "║            ThirdParty/iPlug2                             ║")
        message(STATUS "║                                                          ║")
        message(STATUS "║  Benefits:                                               ║")
        message(STATUS "║  • MIT License (100% FREE for commercial use)            ║")
        message(STATUS "║  • VST3, AU, AAX, CLAP, Standalone                        ║")
        message(STATUS "║  • No JUCE dependency                                    ║")
        message(STATUS "║  • Professional audio quality                            ║")
        message(STATUS "╚══════════════════════════════════════════════════════════╝")
        message(STATUS "")
    endif()
endif()

# ===========================
# Plugin Formats
# ===========================

set(FORMATS)

if(BUILD_VST3)
    list(APPEND FORMATS VST3)
endif()

if(BUILD_AU AND APPLE)
    list(APPEND FORMATS AU)
endif()

if(BUILD_AAX)
    list(APPEND FORMATS AAX)
endif()

if(BUILD_AUv3 AND IOS)
    list(APPEND FORMATS AUv3)
endif()

if(BUILD_LV2 AND UNIX)
    list(APPEND FORMATS LV2)
endif()

if(BUILD_CLAP)
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/ThirdParty/clap")
        list(APPEND FORMATS CLAP)
        message(STATUS "CLAP plugin format: ENABLED")
    else()
        message(STATUS "")
        message(STATUS "╔══════════════════════════════════════════════════════════╗")
        message(STATUS "║  CLAP SDK not found! To enable CLAP plugins:             ║")
        message(STATUS "║                                                          ║")
        message(STATUS "║  git clone https://github.com/free-audio/clap \\          ║")
        message(STATUS "║            ThirdParty/clap                               ║")
        message(STATUS "║                                                          ║")
        message(STATUS "║  CLAP is supported in:                                   ║")
        message(STATUS "║  • Bitwig Studio 4.0+                                    ║")
        message(STATUS "║  • REAPER 6.60+                                          ║")
        message(STATUS "║  • MultitrackStudio                                      ║")
        message(STATUS "║  • Renoise 3.4+                                          ║")
        message(STATUS "╚══════════════════════════════════════════════════════════╝")
        message(STATUS "")
    endif()
endif()

if(BUILD_STANDALONE)
    list(APPEND FORMATS Standalone)
endif()

message(STATUS "Plugin Formats: ${FORMATS}")

# ===========================
# Legacy JUCE Code - COMPLETELY REMOVED
# ===========================
# JUCE has been removed from this project as of 2026-01-13.
# All DSP is now handled by EchoelmusicDSP.h (pure C++17, MIT license).
#
# For desktop plugins, use iPlug2 (MIT license, FREE):
#   cmake .. -DUSE_IPLUG2=ON
#
# Benefits of JUCE removal:
# • Zero licensing fees
# • Smaller binary size
# • No proprietary dependencies
# • Native performance on all platforms
# • Full control over DSP implementation
#
# The ~600 lines of legacy JUCE plugin code have been removed.
# See git history for reference if needed.

# ===========================
# Native Audio Engines (JUCE-Free)
# ===========================
# These are standalone audio engines that don't require JUCE
# Used for: Standalone apps, Swift bridge, non-plugin builds

option(BUILD_NATIVE_AUDIO "Build native audio engines (JUCE-free)" ON)

if(BUILD_NATIVE_AUDIO)
    message(STATUS "")
    message(STATUS "==============================================")
    message(STATUS "Echoelmusic Native Audio Engines")
    message(STATUS "==============================================")

    # Header-only library for native audio
    add_library(EchoelmusicNativeAudio INTERFACE)

    target_include_directories(EchoelmusicNativeAudio
        INTERFACE
            ${CMAKE_CURRENT_SOURCE_DIR}/Sources/DSP
            ${CMAKE_CURRENT_SOURCE_DIR}/Sources/Desktop/DSP
    )

    # Platform-specific configurations
    if(WIN32)
        message(STATUS "  Windows: WASAPI + ASIO Bridge")
        target_compile_definitions(EchoelmusicNativeAudio
            INTERFACE
                WIN32_LEAN_AND_MEAN
                NOMINMAX
                _UNICODE
                UNICODE
        )
        # Note: WindowsAudioEngine.hpp is header-only
        # Link requirements for consumers
        target_link_libraries(EchoelmusicNativeAudio
            INTERFACE
                ole32
                uuid
                crypt32
                credui
        )
    elseif(UNIX AND NOT APPLE AND NOT ANDROID)
        message(STATUS "  Linux: ALSA + PipeWire")

        find_package(PkgConfig)
        if(PkgConfig_FOUND)
            # ALSA
            pkg_check_modules(ALSA alsa)
            if(ALSA_FOUND)
                target_include_directories(EchoelmusicNativeAudio INTERFACE ${ALSA_INCLUDE_DIRS})
                target_link_libraries(EchoelmusicNativeAudio INTERFACE ${ALSA_LIBRARIES})
                target_compile_definitions(EchoelmusicNativeAudio INTERFACE ECHOELMUSIC_ALSA=1)
                message(STATUS "    - ALSA: Found")
            endif()

            # PipeWire
            pkg_check_modules(PIPEWIRE libpipewire-0.3)
            if(PIPEWIRE_FOUND)
                target_include_directories(EchoelmusicNativeAudio INTERFACE ${PIPEWIRE_INCLUDE_DIRS})
                target_link_libraries(EchoelmusicNativeAudio INTERFACE ${PIPEWIRE_LIBRARIES})
                target_compile_definitions(EchoelmusicNativeAudio INTERFACE ECHOELMUSIC_PIPEWIRE=1)
                message(STATUS "    - PipeWire: Found")
            endif()

            # OpenSSL for encryption
            find_package(OpenSSL)
            if(OPENSSL_FOUND)
                message(STATUS "    - OpenSSL: Found")
            endif()
        endif()

        target_link_libraries(EchoelmusicNativeAudio INTERFACE pthread)
    endif()

    message(STATUS "==============================================")
    message(STATUS "")
endif()

# ===========================
# WebAssembly Build (Emscripten)
# ===========================

if(EMSCRIPTEN)
    message(STATUS "")
    message(STATUS "==============================================")
    message(STATUS "Echoelmusic WebAssembly Build")
    message(STATUS "==============================================")

    add_executable(echoelcore_wasm
        Sources/Desktop/DSP/EchoelmusicDSP.h
    )

    # Emscripten settings for audio
    set_target_properties(echoelcore_wasm PROPERTIES
        SUFFIX ".js"
        LINK_FLAGS "-s WASM=1 -s EXPORTED_RUNTIME_METHODS=['ccall','cwrap'] -s ALLOW_MEMORY_GROWTH=1 -s AUDIO_WORKLET=1"
    )

    target_compile_definitions(echoelcore_wasm PRIVATE
        ECHOELMUSIC_WASM=1
    )

    message(STATUS "  Target: echoelcore_wasm.js + echoelcore_wasm.wasm")
    message(STATUS "  Build with: emcmake cmake .. && emmake make")
    message(STATUS "==============================================")
endif()

# ===========================
# Summary for Non-JUCE builds
# ===========================

if(NOT USE_JUCE)
    # Non-JUCE build (Swift-only for iOS/macOS)
    message(STATUS "")
    message(STATUS "==============================================")
    message(STATUS "Echoelmusic - Swift-Only Build Mode")
    message(STATUS "==============================================")
    message(STATUS "")
    message(STATUS "JUCE Framework: DISABLED")
    message(STATUS "")
    message(STATUS "This configuration is for iOS/macOS Swift builds")
    message(STATUS "that use native Apple frameworks:")
    message(STATUS "  - AVFoundation (Audio/Video)")
    message(STATUS "  - Accelerate (DSP/SIMD)")
    message(STATUS "  - CoreML (AI/ML)")
    message(STATUS "  - HealthKit (Biometrics)")
    message(STATUS "  - Metal (GPU Shaders)")
    message(STATUS "")
    message(STATUS "To build Swift targets:")
    message(STATUS "  swift build")
    message(STATUS "  swift test")
    message(STATUS "")
    message(STATUS "To enable desktop plugin builds:")
    message(STATUS "  cmake .. -DUSE_JUCE=ON")
    message(STATUS "  (Requires JUCE in ThirdParty/JUCE)")
    message(STATUS "")
    message(STATUS "Or use iPlug2 (MIT license - FREE):")
    message(STATUS "  cmake .. -DUSE_IPLUG2=ON")
    message(STATUS "  (Requires iPlug2 in ThirdParty/iPlug2)")
    message(STATUS "")
    message(STATUS "==============================================")
endif()
