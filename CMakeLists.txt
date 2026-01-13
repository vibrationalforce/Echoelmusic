cmake_minimum_required(VERSION 3.22)

project(Echoelmusic VERSION 1.0.0 LANGUAGES CXX)

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
option(ENABLE_JACK "Enable JACK support (Linux)" OFF)  # Disabled for minimal build
option(ENABLE_PULSEAUDIO "Enable PulseAudio (Linux)" OFF)  # Disabled for minimal build

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
# Swift-Only Build Mode (DEFAULT)
# ===========================
# This is the default configuration for iOS/macOS/watchOS/tvOS/visionOS builds
# that use native Apple frameworks and EchoelmusicDSP.h

message(STATUS "")
message(STATUS "╔══════════════════════════════════════════════════════════════════╗")
message(STATUS "║          ECHOELMUSIC - NATIVE SWIFT BUILD MODE                   ║")
message(STATUS "╠══════════════════════════════════════════════════════════════════╣")
message(STATUS "║                                                                   ║")
message(STATUS "║  DSP Engine: EchoelmusicDSP.h (JUCE-free, MIT license)           ║")
message(STATUS "║                                                                   ║")
message(STATUS "║  Native Frameworks:                                              ║")
message(STATUS "║    • AVFoundation (Audio/Video)                                  ║")
message(STATUS "║    • Accelerate (DSP/SIMD)                                       ║")
message(STATUS "║    • CoreML (AI/ML)                                              ║")
message(STATUS "║    • HealthKit (Biometrics)                                      ║")
message(STATUS "║    • Metal (GPU Shaders)                                         ║")
message(STATUS "║    • RealityKit (visionOS)                                       ║")
message(STATUS "║                                                                   ║")
message(STATUS "║  To build:                                                       ║")
message(STATUS "║    swift build      # Build all targets                          ║")
message(STATUS "║    swift test       # Run tests                                  ║")
message(STATUS "║    open Package.swift  # Open in Xcode                           ║")
message(STATUS "║                                                                   ║")
message(STATUS "║  For desktop plugins (VST3/AU/AAX/CLAP):                         ║")
message(STATUS "║    cmake .. -DUSE_IPLUG2=ON                                      ║")
message(STATUS "║    (Clone iPlug2 to ThirdParty/iPlug2 first)                     ║")
message(STATUS "║                                                                   ║")
message(STATUS "╚══════════════════════════════════════════════════════════════════╝")
message(STATUS "")
message(STATUS "Platform: ${CMAKE_SYSTEM_NAME}")
message(STATUS "Processor: ${CMAKE_SYSTEM_PROCESSOR}")
message(STATUS "C++ Standard: ${CMAKE_CXX_STANDARD}")
message(STATUS "Build Type: ${CMAKE_BUILD_TYPE}")
