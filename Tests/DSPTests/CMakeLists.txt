#================================================================
# Echoelmusic DSP Unit Tests
#================================================================
#
# Test Framework: Catch2 (v2.13.10)
# Coverage: SIMD Performance Benchmarks (JUCE-free)
#
# Build Instructions:
#   mkdir -p Tests/DSPTests/build
#   cd Tests/DSPTests/build
#   cmake ..
#   make
#   ./DSPTests
#
# Note: Uses standalone SIMD benchmarks without JUCE/IPlug2 dependencies
#================================================================

cmake_minimum_required(VERSION 3.22)
project(EchoelmusicDSPTests CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ===========================
# Test Executable (Standalone SIMD Benchmarks)
# ===========================

add_executable(DSPTests
    SIMDBenchmarks.cpp
)

target_include_directories(DSPTests
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
        ${CMAKE_CURRENT_SOURCE_DIR}/../../Sources
)

# No JUCE/IPlug2 dependencies - pure SIMD benchmarks
# Future: Add IPlug2-based tests when ready

# Enable warnings
if(MSVC)
    target_compile_options(DSPTests PRIVATE /W4)
else()
    target_compile_options(DSPTests PRIVATE -Wall -Wextra -Wpedantic)
endif()

# ===========================
# CTest Integration
# ===========================

enable_testing()
add_test(NAME DSPTests COMMAND DSPTests)

# ===========================
# Summary
# ===========================

message(STATUS "")
message(STATUS "================================================================")
message(STATUS "Echoelmusic SIMD Benchmark Suite (JUCE-free)")
message(STATUS "================================================================")
message(STATUS "Test executable: DSPTests")
message(STATUS "Framework: Standalone (no JUCE/IPlug2)")
message(STATUS "C++ Standard: ${CMAKE_CXX_STANDARD}")
message(STATUS "")
message(STATUS "Build commands:")
message(STATUS "  mkdir build && cd build")
message(STATUS "  cmake -DCMAKE_BUILD_TYPE=Release ..")
message(STATUS "  make")
message(STATUS "  ./DSPTests \"[performance][simd]\"")
message(STATUS "================================================================")
message(STATUS "")
