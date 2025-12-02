# Echoelmusic Android Native Audio Engine
# Uses Oboe for ultra-low-latency audio

cmake_minimum_required(VERSION 3.22.1)
project(echoelmusic VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

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

# Link Oboe
target_link_libraries(echoelmusic
    PRIVATE
    oboe::oboe
    android
    log
)

# Compiler flags for performance
target_compile_options(echoelmusic PRIVATE
    -O3
    -ffast-math
    -funroll-loops
    -fno-exceptions  # Optional: disable for smaller binary
)

# Enable NEON on ARM
if(ANDROID_ABI MATCHES "arm")
    target_compile_options(echoelmusic PRIVATE -mfpu=neon)
endif()
