# Echoelmusic Android Native Audio Engine
# Updated: December 2025
# Uses Oboe 1.9 for ultra-low-latency audio
# C++20 with NDK r27+ features

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

# Source files
set(SOURCES
    EchoelmusicEngine.cpp
    EchoelmusicEngine.h
    TR808Engine.cpp
    TR808Engine.h
    Synth.cpp
    Synth.h
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

# Compiler flags for maximum performance
target_compile_options(echoelmusic PRIVATE
    -O3
    -ffast-math
    -funroll-loops
    -fno-rtti           # Disable RTTI for smaller binary
    -fvisibility=hidden # Hide internal symbols
    -Wall
    -Wextra
)

# Enable SIMD optimizations per architecture
if(ANDROID_ABI STREQUAL "arm64-v8a")
    # ARM64 with NEON (always available on arm64)
    target_compile_options(echoelmusic PRIVATE
        -march=armv8-a+simd
        -ftree-vectorize
    )
    message(STATUS "ARM64 NEON SIMD enabled")
elseif(ANDROID_ABI STREQUAL "armeabi-v7a")
    # ARM32 with NEON
    target_compile_options(echoelmusic PRIVATE
        -mfpu=neon
        -mfloat-abi=softfp
        -ftree-vectorize
    )
    message(STATUS "ARM32 NEON SIMD enabled")
elseif(ANDROID_ABI STREQUAL "x86_64")
    # x86_64 with SSE4.2/AVX
    target_compile_options(echoelmusic PRIVATE
        -msse4.2
        -mavx
        -ftree-vectorize
    )
    message(STATUS "x86_64 SSE4.2/AVX SIMD enabled")
elseif(ANDROID_ABI STREQUAL "x86")
    # x86 with SSE2
    target_compile_options(echoelmusic PRIVATE
        -msse2
        -ftree-vectorize
    )
    message(STATUS "x86 SSE2 SIMD enabled")
endif()

# LTO (Link-Time Optimization) for release builds
if(CMAKE_BUILD_TYPE STREQUAL "Release")
    target_compile_options(echoelmusic PRIVATE -flto=thin)
    target_link_options(echoelmusic PRIVATE -flto=thin)
    message(STATUS "LTO enabled for Release build")
endif()

# Define audio configuration
target_compile_definitions(echoelmusic PRIVATE
    OBOE_ENABLE_LOGGING=0
    ECHOELMUSIC_VERSION="1.1.0"
    ECHOELMUSIC_MAX_VOICES=32
    ECHOELMUSIC_SAMPLE_RATE=48000
)
