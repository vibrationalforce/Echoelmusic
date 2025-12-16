# Echoelmusic Desktop Pro - JUCE Build System
# Full 96-processor professional audio plugin
#
# Supported Formats:
# - VST3 (cross-platform)
# - AU (Audio Units, macOS)
# - Standalone Application
#
# License: JUCE Commercial ($900/year) or GPL v3

cmake_minimum_required(VERSION 3.22)
project(EchoelmusicPro VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# ===========================
# JUCE Framework
# ===========================

set(JUCE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/../../../ThirdParty/JUCE" CACHE PATH "Path to JUCE")

if(NOT EXISTS "${JUCE_DIR}/modules")
    message(FATAL_ERROR "JUCE not found at ${JUCE_DIR}. Please run: git clone https://github.com/juce-framework/JUCE.git ThirdParty/JUCE")
endif()

message(STATUS "✅ JUCE found at: ${JUCE_DIR}")

# Add JUCE
add_subdirectory(${JUCE_DIR} ${CMAKE_BINARY_DIR}/JUCE)

# ===========================
# Plugin Configuration
# ===========================

juce_add_plugin(EchoelmusicPro
    COMPANY_NAME "Echoelmusic"
    PLUGIN_MANUFACTURER_CODE Echo
    PLUGIN_CODE EcPr
    FORMATS VST3 AU Standalone
    PRODUCT_NAME "Echoelmusic Pro"

    # Plugin characteristics
    IS_SYNTH TRUE
    NEEDS_MIDI_INPUT TRUE
    NEEDS_MIDI_OUTPUT FALSE
    IS_MIDI_EFFECT FALSE
    EDITOR_WANTS_KEYBOARD_FOCUS TRUE
    COPY_PLUGIN_AFTER_BUILD FALSE
    PLUGIN_MANUFACTURER_EMAIL "support@echoelmusic.com"
    PLUGIN_MANUFACTURER_WEBSITE "https://echoelmusic.com"

    # Version
    VERSION 1.0.0

    # Bundle ID
    BUNDLE_ID com.echoelmusic.pro

    # Plugin categories
    VST3_CATEGORIES Instrument Synth
    AU_MAIN_TYPE kAudioUnitType_MusicDevice
)

# ===========================
# Source Files
# ===========================

# Plugin entry point
target_sources(EchoelmusicPro PRIVATE
    PluginProcessor.cpp
    PluginProcessor.h
    PluginEditor.cpp
    PluginEditor.h
)

# DSP Processors - Gradual integration (commented out for MVP)
# file(GLOB_RECURSE DSP_SOURCES
#     "${CMAKE_CURRENT_SOURCE_DIR}/../../DSP/*.cpp"
#     "${CMAKE_CURRENT_SOURCE_DIR}/../../DSP/*.h"
# )

# Audio Engine
# file(GLOB_RECURSE AUDIO_SOURCES
#     "${CMAKE_CURRENT_SOURCE_DIR}/../../Audio/*.cpp"
#     "${CMAKE_CURRENT_SOURCE_DIR}/../../Audio/*.h"
# )

# Synthesis
# file(GLOB_RECURSE SYNTH_SOURCES
#     "${CMAKE_CURRENT_SOURCE_DIR}/../../Synthesis/*.cpp"
#     "${CMAKE_CURRENT_SOURCE_DIR}/../../Synthesis/*.h"
# )

# target_sources(EchoelmusicPro PRIVATE
#     ${DSP_SOURCES}
#     ${AUDIO_SOURCES}
#     ${SYNTH_SOURCES}
# )

# MVP: Just the plugin wrapper for now (DSP integration in next phase)

# ===========================
# Include Directories
# ===========================

target_include_directories(EchoelmusicPro PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}
    ${CMAKE_CURRENT_SOURCE_DIR}/../..
    ${CMAKE_CURRENT_SOURCE_DIR}/../../DSP
    ${CMAKE_CURRENT_SOURCE_DIR}/../../Audio
    ${CMAKE_CURRENT_SOURCE_DIR}/../../Synthesis
)

# ===========================
# JUCE Modules
# ===========================

target_link_libraries(EchoelmusicPro
    PRIVATE
        # Core audio
        juce::juce_audio_basics
        juce::juce_audio_devices
        juce::juce_audio_formats
        juce::juce_audio_processors
        juce::juce_audio_utils

        # DSP
        juce::juce_dsp

        # Core utilities
        juce::juce_core
        juce::juce_data_structures
        juce::juce_events

        # GUI
        juce::juce_graphics
        juce::juce_gui_basics
        juce::juce_gui_extra

        # Plugin client
        juce::juce_audio_plugin_client

    PUBLIC
        juce::juce_recommended_config_flags
        juce::juce_recommended_lto_flags
        juce::juce_recommended_warning_flags
)

# ===========================
# Compiler Options
# ===========================

target_compile_definitions(EchoelmusicPro
    PUBLIC
        # JUCE configuration
        JUCE_WEB_BROWSER=0
        JUCE_USE_CURL=0
        JUCE_VST3_CAN_REPLACE_VST2=0

        # Optimization
        JUCE_MODAL_LOOPS_PERMITTED=0
        JUCE_STRICT_REFCOUNTEDPOINTER=1

        # Disable warnings for third-party code
        JUCE_DISPLAY_SPLASH_SCREEN=0
        JUCE_REPORT_APP_USAGE=0
)

# Platform-specific optimizations
if(CMAKE_CXX_COMPILER_ID MATCHES "GNU|Clang")
    target_compile_options(EchoelmusicPro PRIVATE
        -O3                    # Maximum optimization
        -ffast-math            # Fast math operations
        -march=native          # Use native CPU instructions (SIMD)
        -mtune=native
    )
elseif(MSVC)
    target_compile_options(EchoelmusicPro PRIVATE
        /O2                    # Maximum optimization
        /fp:fast               # Fast floating point
        /arch:AVX2             # Use AVX2 instructions
    )
endif()

# ===========================
# Installation
# ===========================

# Install VST3
if(APPLE)
    install(TARGETS EchoelmusicPro_VST3
        LIBRARY DESTINATION ~/Library/Audio/Plug-Ins/VST3
        COMPONENT VST3
    )

    # Install AU
    install(TARGETS EchoelmusicPro_AU
        LIBRARY DESTINATION ~/Library/Audio/Plug-Ins/Components
        COMPONENT AU
    )

    # Install Standalone
    install(TARGETS EchoelmusicPro_Standalone
        BUNDLE DESTINATION /Applications
        COMPONENT Standalone
    )
elseif(WIN32)
    install(TARGETS EchoelmusicPro_VST3
        RUNTIME DESTINATION "C:/Program Files/Common Files/VST3"
        COMPONENT VST3
    )

    install(TARGETS EchoelmusicPro_Standalone
        RUNTIME DESTINATION "C:/Program Files/Echoelmusic"
        COMPONENT Standalone
    )
else() # Linux
    install(TARGETS EchoelmusicPro_VST3
        LIBRARY DESTINATION /usr/lib/vst3
        COMPONENT VST3
    )

    install(TARGETS EchoelmusicPro_Standalone
        RUNTIME DESTINATION /usr/local/bin
        COMPONENT Standalone
    )
endif()

# ===========================
# Summary
# ===========================

message(STATUS "")
message(STATUS "╔══════════════════════════════════════════════════════════╗")
message(STATUS "║        Echoelmusic Pro - JUCE Build Configuration       ║")
message(STATUS "╠══════════════════════════════════════════════════════════╣")
message(STATUS "║  Framework:    JUCE 7.x                                  ║")
message(STATUS "║  License:      Commercial ($900/year) or GPL v3          ║")
message(STATUS "║  Processors:   96 professional DSP processors            ║")
message(STATUS "║  Formats:      VST3, AU, Standalone                      ║")
message(STATUS "║  Platform:     ${CMAKE_SYSTEM_NAME}                      ║")
message(STATUS "║  Compiler:     ${CMAKE_CXX_COMPILER_ID}                  ║")
message(STATUS "║  Build Type:   ${CMAKE_BUILD_TYPE}                       ║")
message(STATUS "╠══════════════════════════════════════════════════════════╣")
message(STATUS "║  Features:                                               ║")
message(STATUS "║    • 11 Synthesis Methods (Vector, Modal, etc.)          ║")
message(STATUS "║    • 202 Professional Presets                            ║")
message(STATUS "║    • Bio-Reactive DSP (HRV, Coherence, Stress)          ║")
message(STATUS "║    • ML-Based Tone Matching                              ║")
message(STATUS "║    • Advanced Spectral Processing                        ║")
message(STATUS "║    • SIMD Optimizations (AVX2/NEON)                      ║")
message(STATUS "╚══════════════════════════════════════════════════════════╝")
message(STATUS "")
message(STATUS "DSP Sources: ${DSP_SOURCES}")
message(STATUS "")
