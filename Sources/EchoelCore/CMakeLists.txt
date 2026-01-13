# =============================================================================
# EchoelCore/EchoelDSP - Native Audio Framework
# =============================================================================
# NO JUCE. NO iPlug2. Pure native cross-platform audio.
# =============================================================================

cmake_minimum_required(VERSION 3.20)

project(EchoelCore
    VERSION 1.0.0
    LANGUAGES CXX C
    DESCRIPTION "Native Audio Framework for Echoelmusic"
)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# =============================================================================
# Options
# =============================================================================

option(ECHOELCORE_BUILD_TESTS "Build unit tests" ON)
option(ECHOELCORE_BUILD_VST3 "Build VST3 plugin" ON)
option(ECHOELCORE_BUILD_AU "Build Audio Unit plugin (macOS only)" ON)
option(ECHOELCORE_BUILD_CLAP "Build CLAP plugin" ON)
option(ECHOELCORE_BUILD_WASM "Build WebAssembly module" OFF)
option(ECHOELCORE_USE_SIMD "Enable SIMD optimizations" ON)

# =============================================================================
# Platform Detection
# =============================================================================

if(APPLE)
    set(ECHOELCORE_PLATFORM "apple")
    if(IOS)
        set(ECHOELCORE_TARGET "ios")
    else()
        set(ECHOELCORE_TARGET "macos")
    endif()
elseif(WIN32)
    set(ECHOELCORE_PLATFORM "windows")
    set(ECHOELCORE_TARGET "windows")
elseif(ANDROID)
    set(ECHOELCORE_PLATFORM "android")
    set(ECHOELCORE_TARGET "android")
elseif(UNIX)
    set(ECHOELCORE_PLATFORM "linux")
    set(ECHOELCORE_TARGET "linux")
elseif(EMSCRIPTEN)
    set(ECHOELCORE_PLATFORM "web")
    set(ECHOELCORE_TARGET "wasm")
endif()

message(STATUS "EchoelCore Platform: ${ECHOELCORE_PLATFORM}")
message(STATUS "EchoelCore Target: ${ECHOELCORE_TARGET}")

# =============================================================================
# Source Files
# =============================================================================

set(ECHOELCORE_SOURCES
    EchoelCore.h
    PluginAPI/PluginAPI.h
)

set(ECHOELDSP_SOURCES
    ../EchoelDSP/EchoelDSP.h
)

# Platform-specific backends
if(ANDROID)
    list(APPEND ECHOELCORE_SOURCES
        Backends/AAudioBackend.h
    )
endif()

if(EMSCRIPTEN)
    list(APPEND ECHOELCORE_SOURCES
        Backends/WebAudioBackend.h
    )
endif()

# =============================================================================
# Main Library
# =============================================================================

add_library(EchoelCore INTERFACE)

target_include_directories(EchoelCore INTERFACE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/..
)

# Compiler flags
if(MSVC)
    target_compile_options(EchoelCore INTERFACE /W4 /WX-)
else()
    target_compile_options(EchoelCore INTERFACE -Wall -Wextra -Wpedantic)
endif()

# SIMD flags
if(ECHOELCORE_USE_SIMD)
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|AMD64|i686")
        target_compile_options(EchoelCore INTERFACE -msse4.2 -mavx)
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "arm64|aarch64")
        target_compile_options(EchoelCore INTERFACE -march=armv8-a+simd)
    endif()
endif()

# =============================================================================
# DSP Library
# =============================================================================

add_library(EchoelDSP INTERFACE)

target_include_directories(EchoelDSP INTERFACE
    ${CMAKE_CURRENT_SOURCE_DIR}/../EchoelDSP
)

target_link_libraries(EchoelDSP INTERFACE EchoelCore)

# =============================================================================
# Platform Audio Libraries
# =============================================================================

if(APPLE)
    # Core Audio
    find_library(COREAUDIO_LIBRARY CoreAudio)
    find_library(AUDIOTOOLBOX_LIBRARY AudioToolbox)
    find_library(AVFOUNDATION_LIBRARY AVFoundation)
    find_library(COREMIDI_LIBRARY CoreMIDI)

    add_library(EchoelAudio INTERFACE)
    target_link_libraries(EchoelAudio INTERFACE
        ${COREAUDIO_LIBRARY}
        ${AUDIOTOOLBOX_LIBRARY}
        ${AVFOUNDATION_LIBRARY}
        ${COREMIDI_LIBRARY}
        EchoelCore
    )
elseif(WIN32)
    # WASAPI / ASIO
    add_library(EchoelAudio INTERFACE)
    target_link_libraries(EchoelAudio INTERFACE
        winmm
        ole32
        EchoelCore
    )
elseif(ANDROID)
    # AAudio / Oboe
    find_package(oboe REQUIRED CONFIG)

    add_library(EchoelAudio INTERFACE)
    target_link_libraries(EchoelAudio INTERFACE
        oboe::oboe
        aaudio
        EchoelCore
    )
elseif(UNIX AND NOT APPLE AND NOT ANDROID)
    # ALSA / PipeWire / JACK
    find_package(ALSA)
    find_package(PkgConfig)

    add_library(EchoelAudio INTERFACE)

    if(ALSA_FOUND)
        target_link_libraries(EchoelAudio INTERFACE ${ALSA_LIBRARIES})
        target_include_directories(EchoelAudio INTERFACE ${ALSA_INCLUDE_DIRS})
    endif()

    if(PkgConfig_FOUND)
        pkg_check_modules(JACK jack)
        if(JACK_FOUND)
            target_link_libraries(EchoelAudio INTERFACE ${JACK_LIBRARIES})
            target_include_directories(EchoelAudio INTERFACE ${JACK_INCLUDE_DIRS})
        endif()

        pkg_check_modules(PIPEWIRE libpipewire-0.3)
        if(PIPEWIRE_FOUND)
            target_link_libraries(EchoelAudio INTERFACE ${PIPEWIRE_LIBRARIES})
            target_include_directories(EchoelAudio INTERFACE ${PIPEWIRE_INCLUDE_DIRS})
        endif()
    endif()

    target_link_libraries(EchoelAudio INTERFACE EchoelCore pthread)
endif()

# =============================================================================
# VST3 Plugin
# =============================================================================

if(ECHOELCORE_BUILD_VST3 AND NOT ANDROID AND NOT EMSCRIPTEN)
    # VST3 SDK would be included here
    # For now, create a stub target
    message(STATUS "VST3 plugin build enabled (requires VST3 SDK)")
endif()

# =============================================================================
# Audio Unit Plugin (macOS/iOS)
# =============================================================================

if(ECHOELCORE_BUILD_AU AND APPLE)
    message(STATUS "Audio Unit plugin build enabled")
endif()

# =============================================================================
# CLAP Plugin
# =============================================================================

if(ECHOELCORE_BUILD_CLAP AND NOT ANDROID AND NOT EMSCRIPTEN)
    message(STATUS "CLAP plugin build enabled")
endif()

# =============================================================================
# WebAssembly
# =============================================================================

if(EMSCRIPTEN OR ECHOELCORE_BUILD_WASM)
    add_executable(EchoelCoreWASM
        Backends/WebAudioBackend.h
    )

    target_link_libraries(EchoelCoreWASM PRIVATE EchoelCore EchoelDSP)

    set_target_properties(EchoelCoreWASM PROPERTIES
        SUFFIX ".js"
        LINK_FLAGS "-s WASM=1 -s MODULARIZE=1 -s EXPORT_NAME='EchoelCore' -s EXPORTED_FUNCTIONS='[\"_initializeAudio\",\"_startAudio\",\"_stopAudio\",\"_processAudio\"]' -s EXPORTED_RUNTIME_METHODS='[\"ccall\",\"cwrap\"]'"
    )

    if(ECHOELCORE_USE_SIMD)
        target_compile_options(EchoelCoreWASM PRIVATE -msimd128)
        set_target_properties(EchoelCoreWASM PROPERTIES
            LINK_FLAGS "${LINK_FLAGS} -msimd128"
        )
    endif()
endif()

# =============================================================================
# Unit Tests
# =============================================================================

if(ECHOELCORE_BUILD_TESTS)
    enable_testing()

    add_executable(EchoelCoreTests
        ${CMAKE_CURRENT_SOURCE_DIR}/../Tests/EchoelDSPTests.cpp
    )

    target_link_libraries(EchoelCoreTests PRIVATE EchoelCore EchoelDSP)

    if(APPLE)
        target_link_libraries(EchoelCoreTests PRIVATE EchoelAudio)
    elseif(UNIX)
        target_link_libraries(EchoelCoreTests PRIVATE EchoelAudio)
    endif()

    add_test(NAME EchoelCoreTests COMMAND EchoelCoreTests)
endif()

# =============================================================================
# Install
# =============================================================================

install(FILES
    EchoelCore.h
    DESTINATION include/EchoelCore
)

install(FILES
    ../EchoelDSP/EchoelDSP.h
    DESTINATION include/EchoelDSP
)

install(DIRECTORY
    PluginAPI/
    DESTINATION include/EchoelCore/PluginAPI
    FILES_MATCHING PATTERN "*.h"
)

install(DIRECTORY
    Backends/
    DESTINATION include/EchoelCore/Backends
    FILES_MATCHING PATTERN "*.h"
)

# =============================================================================
# Summary
# =============================================================================

message(STATUS "")
message(STATUS "=== EchoelCore Configuration ===")
message(STATUS "Version: ${PROJECT_VERSION}")
message(STATUS "Platform: ${ECHOELCORE_PLATFORM}")
message(STATUS "Target: ${ECHOELCORE_TARGET}")
message(STATUS "Build Tests: ${ECHOELCORE_BUILD_TESTS}")
message(STATUS "Build VST3: ${ECHOELCORE_BUILD_VST3}")
message(STATUS "Build AU: ${ECHOELCORE_BUILD_AU}")
message(STATUS "Build CLAP: ${ECHOELCORE_BUILD_CLAP}")
message(STATUS "Build WASM: ${ECHOELCORE_BUILD_WASM}")
message(STATUS "Use SIMD: ${ECHOELCORE_USE_SIMD}")
message(STATUS "")
