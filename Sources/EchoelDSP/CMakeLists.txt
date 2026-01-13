# ============================================================================
# EchoelDSP - Zero-Dependency High-Performance Audio DSP Library
# ============================================================================
# JUCE-FREE | iPlug2-FREE | Pure C++17 | SIMD-Optimized
# ============================================================================

cmake_minimum_required(VERSION 3.20)
project(EchoelDSP VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_POSITION_INDEPENDENT_CODE ON)

# ============================================================================
# Options
# ============================================================================

option(ECHOEL_DSP_BUILD_TESTS "Build unit tests" ON)
option(ECHOEL_DSP_BUILD_EXAMPLES "Build example plugins" ON)
option(ECHOEL_DSP_ENABLE_SIMD "Enable SIMD optimizations" ON)
option(ECHOEL_DSP_BUILD_VST3 "Build VST3 plugins" OFF)
option(ECHOEL_DSP_BUILD_AU "Build Audio Unit plugins" OFF)
option(ECHOEL_DSP_BUILD_CLAP "Build CLAP plugins" ON)

# ============================================================================
# SIMD Flags
# ============================================================================

if(ECHOEL_DSP_ENABLE_SIMD)
    if(CMAKE_SYSTEM_PROCESSOR MATCHES "arm|aarch64|ARM64")
        # ARM NEON is typically enabled by default on ARM64
        message(STATUS "EchoelDSP: ARM NEON SIMD enabled")
    elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|AMD64")
        if(MSVC)
            add_compile_options(/arch:AVX2)
        else()
            add_compile_options(-mavx2 -mfma)
        endif()
        message(STATUS "EchoelDSP: x86 AVX2 + FMA SIMD enabled")
    endif()
endif()

# ============================================================================
# Library Target
# ============================================================================

add_library(EchoelDSP INTERFACE)

target_include_directories(EchoelDSP INTERFACE
    $<BUILD_INTERFACE:${CMAKE_CURRENT_SOURCE_DIR}/..>
    $<INSTALL_INTERFACE:include>
)

target_compile_features(EchoelDSP INTERFACE cxx_std_17)

# ============================================================================
# Platform-Specific Libraries
# ============================================================================

if(APPLE)
    find_library(COREAUDIO_LIBRARY CoreAudio)
    find_library(AUDIOTOOLBOX_LIBRARY AudioToolbox)
    find_library(ACCELERATE_LIBRARY Accelerate)

    target_link_libraries(EchoelDSP INTERFACE
        ${COREAUDIO_LIBRARY}
        ${AUDIOTOOLBOX_LIBRARY}
        ${ACCELERATE_LIBRARY}
    )
    message(STATUS "EchoelDSP: Apple Core Audio backend enabled")
endif()

if(WIN32)
    # WASAPI is part of Windows SDK
    message(STATUS "EchoelDSP: Windows WASAPI backend enabled")
endif()

if(UNIX AND NOT APPLE)
    # Linux: ALSA or PipeWire
    find_package(ALSA)
    if(ALSA_FOUND)
        target_link_libraries(EchoelDSP INTERFACE ${ALSA_LIBRARIES})
        target_include_directories(EchoelDSP INTERFACE ${ALSA_INCLUDE_DIRS})
        message(STATUS "EchoelDSP: Linux ALSA backend enabled")
    endif()
endif()

# ============================================================================
# Tests
# ============================================================================

if(ECHOEL_DSP_BUILD_TESTS)
    enable_testing()

    add_executable(EchoelDSPTests
        Tests/TestMain.cpp
    )

    target_link_libraries(EchoelDSPTests PRIVATE EchoelDSP)

    add_test(NAME EchoelDSPTests COMMAND EchoelDSPTests)
endif()

# ============================================================================
# Examples
# ============================================================================

if(ECHOEL_DSP_BUILD_EXAMPLES)
    add_executable(BioSyncStandalone
        Examples/StandaloneMain.cpp
    )

    target_link_libraries(BioSyncStandalone PRIVATE EchoelDSP)
endif()

# ============================================================================
# Installation
# ============================================================================

install(
    DIRECTORY ${CMAKE_CURRENT_SOURCE_DIR}/
    DESTINATION include/EchoelDSP
    FILES_MATCHING PATTERN "*.h"
)

install(TARGETS EchoelDSP EXPORT EchoelDSPTargets)

install(EXPORT EchoelDSPTargets
    FILE EchoelDSPConfig.cmake
    NAMESPACE Echoel::
    DESTINATION lib/cmake/EchoelDSP
)

# ============================================================================
# Summary
# ============================================================================

message(STATUS "")
message(STATUS "╔══════════════════════════════════════════════════════════════╗")
message(STATUS "║                    EchoelDSP v${PROJECT_VERSION}                        ║")
message(STATUS "╠══════════════════════════════════════════════════════════════╣")
message(STATUS "║  🚀 Zero Dependencies | Pure C++17 | SIMD-Optimized         ║")
message(STATUS "║  📦 JUCE-FREE | iPlug2-FREE | Future-Ready                   ║")
message(STATUS "╠══════════════════════════════════════════════════════════════╣")
message(STATUS "║  SIMD:     ${CMAKE_SYSTEM_PROCESSOR}")
message(STATUS "║  Platform: ${CMAKE_SYSTEM_NAME}")
message(STATUS "║  Compiler: ${CMAKE_CXX_COMPILER_ID} ${CMAKE_CXX_COMPILER_VERSION}")
message(STATUS "╚══════════════════════════════════════════════════════════════╝")
message(STATUS "")
