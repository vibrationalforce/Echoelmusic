# Echoelmusic Android Native Audio Engine
# Updated: December 2025 - Quantum Ultra Deep Mode
# Uses Oboe 1.9 for ultra-low-latency audio
# C++20 with NDK r27+ features
# SIMD optimizations for ARM NEON and x86 SSE/AVX

cmake_minimum_required(VERSION 3.22.1)
project(echoelmusic VERSION 1.1.0 LANGUAGES CXX)

# C++20 Standard (NDK r27+)
set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# 16KB Page Size Support (Android 15 / API 35)
# Required for arm64 devices with 16KB pages
if(ANDROID_SUPPORT_FLEXIBLE_PAGE_SIZES)
    message(STATUS "16KB page size support enabled")
    add_compile_definitions(ANDROID_16KB_PAGE_SIZE=1)
endif()

# Find Oboe package (provided by prefab)
find_package(oboe REQUIRED CONFIG)

# Source files (with SIMD helper)
set(SOURCES
    EchoelmusicEngine.cpp
    EchoelmusicEngine.h
    TR808Engine.cpp
    TR808Engine.h
    Synth.cpp
    Synth.h
    SIMDHelper.h
    jni_bridge.cpp
)

# Create shared library
add_library(echoelmusic SHARED ${SOURCES})

# Link Oboe and Android libraries
target_link_libraries(echoelmusic
    PRIVATE
    oboe::oboe
    android
    log
    OpenSLES   # Fallback for older devices
)

# Base compiler flags for maximum performance
target_compile_options(echoelmusic PRIVATE
    -O3
    -ffast-math
    -funroll-loops
    -fno-rtti           # Disable RTTI for smaller binary
    -fvisibility=hidden # Hide internal symbols
    -fno-exceptions     # Disable exceptions for real-time audio
    -fomit-frame-pointer
    -Wall
    -Wextra
    -Wno-unused-parameter
)

# Enable SIMD optimizations per architecture
if(ANDROID_ABI STREQUAL "arm64-v8a")
    # ARM64 with NEON + advanced SIMD (FP16, crypto)
    target_compile_options(echoelmusic PRIVATE
        -march=armv8.2-a+simd+fp16
        -ftree-vectorize
        -fvectorize
        -fslp-vectorize
        -ffp-contract=fast
    )
    target_compile_definitions(echoelmusic PRIVATE ECHOELMUSIC_SIMD_NEON=1)
    message(STATUS "ARM64 NEON + FP16 SIMD enabled (armv8.2-a)")

elseif(ANDROID_ABI STREQUAL "armeabi-v7a")
    # ARM32 with NEON VFPv4
    target_compile_options(echoelmusic PRIVATE
        -mfpu=neon-vfpv4
        -mfloat-abi=softfp
        -ftree-vectorize
        -fvectorize
    )
    target_compile_definitions(echoelmusic PRIVATE ECHOELMUSIC_SIMD_NEON=1)
    message(STATUS "ARM32 NEON SIMD enabled (neon-vfpv4)")

elseif(ANDROID_ABI STREQUAL "x86_64")
    # x86_64 with AVX2/FMA for maximum performance
    target_compile_options(echoelmusic PRIVATE
        -march=x86-64-v3        # AVX2 + FMA baseline
        -msse4.2
        -mavx
        -mavx2
        -mfma
        -ftree-vectorize
        -fvectorize
    )
    target_compile_definitions(echoelmusic PRIVATE ECHOELMUSIC_SIMD_AVX=1)
    message(STATUS "x86_64 AVX2/FMA SIMD enabled")

elseif(ANDROID_ABI STREQUAL "x86")
    # x86 with SSE4.1
    target_compile_options(echoelmusic PRIVATE
        -msse4.1
        -ftree-vectorize
    )
    target_compile_definitions(echoelmusic PRIVATE ECHOELMUSIC_SIMD_SSE=1)
    message(STATUS "x86 SSE4.1 SIMD enabled")
endif()

# LTO (Link-Time Optimization) for release builds
if(CMAKE_BUILD_TYPE STREQUAL "Release")
    target_compile_options(echoelmusic PRIVATE -flto=thin)
    target_link_options(echoelmusic PRIVATE -flto=thin -Wl,--gc-sections)
    message(STATUS "LTO enabled for Release build")
endif()

# PGO (Profile-Guided Optimization) support
option(ECHOELMUSIC_PGO_GENERATE "Generate PGO profile data" OFF)
option(ECHOELMUSIC_PGO_USE "Use PGO profile data" OFF)

if(ECHOELMUSIC_PGO_GENERATE)
    target_compile_options(echoelmusic PRIVATE -fprofile-generate)
    target_link_options(echoelmusic PRIVATE -fprofile-generate)
    message(STATUS "PGO profile generation enabled")
elseif(ECHOELMUSIC_PGO_USE)
    target_compile_options(echoelmusic PRIVATE -fprofile-use)
    target_link_options(echoelmusic PRIVATE -fprofile-use)
    message(STATUS "PGO profile usage enabled")
endif()

# Define audio configuration
target_compile_definitions(echoelmusic PRIVATE
    OBOE_ENABLE_LOGGING=0
    ECHOELMUSIC_VERSION="1.1.0"
    ECHOELMUSIC_MAX_VOICES=32
    ECHOELMUSIC_SAMPLE_RATE=48000
    ECHOELMUSIC_QUANTUM_AUDIO=1
)

# Summary
message(STATUS "==================================================")
message(STATUS "Echoelmusic Native Audio Engine - QUANTUM MODE")
message(STATUS "==================================================")
message(STATUS "ABI: ${ANDROID_ABI}")
message(STATUS "C++ Standard: ${CMAKE_CXX_STANDARD}")
message(STATUS "Build Type: ${CMAKE_BUILD_TYPE}")
message(STATUS "==================================================")
