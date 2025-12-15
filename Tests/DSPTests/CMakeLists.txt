#================================================================
# Echoelmusic DSP Unit Tests
#================================================================
#
# Test Framework: Catch2 (v2.13.10)
# Coverage: State Variable Filters, Compressors, Bio-Reactive DSP
#
# Build Instructions:
#   mkdir -p Tests/DSPTests/build
#   cd Tests/DSPTests/build
#   cmake ..
#   make
#   ./DSPTests
#
#================================================================

cmake_minimum_required(VERSION 3.22)
project(EchoelmusicDSPTests CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ===========================
# Find JUCE
# ===========================

# JUCE is required for BioReactiveDSP (uses juce::dsp::Reverb, etc.)
# Assumes JUCE is cloned in ThirdParty/JUCE
set(JUCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../ThirdParty/JUCE")

if(NOT EXISTS "${JUCE_DIR}")
    message(FATAL_ERROR
        "JUCE not found at ${JUCE_DIR}\n"
        "Please clone JUCE:\n"
        "  cd ThirdParty\n"
        "  git clone https://github.com/juce-framework/JUCE.git\n"
    )
endif()

add_subdirectory(${JUCE_DIR} ${CMAKE_CURRENT_BINARY_DIR}/JUCE)

# ===========================
# Test Executable
# ===========================

add_executable(DSPTests
    BioReactiveDSPTests.cpp
    CompressorEQTests.cpp
    SIMDBenchmarks.cpp
    ../../Sources/DSP/BioReactiveDSP.cpp
    ../../Sources/DSP/Compressor.cpp
    ../../Sources/DSP/ParametricEQ.cpp
)

target_include_directories(DSPTests
    PRIVATE
        ${CMAKE_CURRENT_SOURCE_DIR}
        ${CMAKE_CURRENT_SOURCE_DIR}/../../Sources
)

target_link_libraries(DSPTests
    PRIVATE
        juce::juce_audio_basics
        juce::juce_audio_processors
        juce::juce_dsp
        juce::juce_core
)

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
message(STATUS "Echoelmusic DSP Test Suite Configuration")
message(STATUS "================================================================")
message(STATUS "Test executable: DSPTests")
message(STATUS "JUCE directory: ${JUCE_DIR}")
message(STATUS "C++ Standard: ${CMAKE_CXX_STANDARD}")
message(STATUS "")
message(STATUS "Build commands:")
message(STATUS "  mkdir build && cd build")
message(STATUS "  cmake ..")
message(STATUS "  make")
message(STATUS "  ./DSPTests")
message(STATUS "================================================================")
message(STATUS "")
