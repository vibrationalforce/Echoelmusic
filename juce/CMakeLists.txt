cmake_minimum_required(VERSION 3.22)

project(ECHOELMUSIC VERSION 1.0.0)

# JUCE path (assumes JUCE is installed or submodule)
add_subdirectory(JUCE)

# Plugin formats to build
set(FORMATS
    VST3        # Steinberg VST3
    AU          # Apple Audio Unit (macOS only)
    Standalone  # Standalone application
    AAX         # Avid AAX (Pro Tools)
)

# Add CLAP if available
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/JUCE/modules/juce_audio_processors/format_types/juce_CLAPPluginFormat.h")
    list(APPEND FORMATS CLAP)
    message(STATUS "CLAP format enabled")
endif()

# Create the plugin target
juce_add_plugin(Echoelmusic
    # Plugin info
    COMPANY_NAME "Echoelmusic"
    PLUGIN_MANUFACTURER_CODE Echo
    PLUGIN_CODE Elm1
    FORMATS ${FORMATS}

    # Product name
    PRODUCT_NAME "Echoelmusic"

    # Bundle ID (for macOS/iOS)
    BUNDLE_ID com.echoelmusic.echoelmusic

    # Plugin characteristics
    IS_SYNTH FALSE
    NEEDS_MIDI_INPUT TRUE
    NEEDS_MIDI_OUTPUT TRUE
    IS_MIDI_EFFECT FALSE
    EDITOR_WANTS_KEYBOARD_FOCUS TRUE

    # Copy to plugin folders
    COPY_PLUGIN_AFTER_BUILD TRUE

    # VST3 category
    VST3_CATEGORIES "Fx" "Instrument" "Analyzer"

    # AU category
    AU_MAIN_TYPE "kAudioUnitType_MusicEffect"

    # AAX category
    AAX_CATEGORY "AAX_ePlugInCategory_Effect"
)

# Source files
target_sources(Echoelmusic
    PRIVATE
        Source/EchoelmusicAudioEngine.cpp
        Source/EchoelmusicAudioEngine.h
)

# Compiler definitions
target_compile_definitions(Echoelmusic
    PUBLIC
        JUCE_WEB_BROWSER=0
        JUCE_USE_CURL=0
        JUCE_VST3_CAN_REPLACE_VST2=0

        # Disable analytics
        JUCE_DISPLAY_SPLASH_SCREEN=0
        JUCE_REPORT_APP_USAGE=0

        # Performance optimizations
        JUCE_USE_SIMD=1
        JUCE_USE_SSE_INTRINSICS=1
        JUCE_USE_AVX_INTRINSICS=1
        JUCE_USE_NEON_INTRINSICS=1
)

# Link JUCE modules
target_link_libraries(Echoelmusic
    PRIVATE
        juce::juce_audio_basics
        juce::juce_audio_devices
        juce::juce_audio_formats
        juce::juce_audio_processors
        juce::juce_audio_utils
        juce::juce_core
        juce::juce_data_structures
        juce::juce_dsp
        juce::juce_events
        juce::juce_graphics
        juce::juce_gui_basics
        juce::juce_gui_extra
    PUBLIC
        juce::juce_recommended_config_flags
        juce::juce_recommended_lto_flags
        juce::juce_recommended_warning_flags
)

# Platform-specific settings
if(APPLE)
    # macOS/iOS specific
    target_compile_definitions(Echoelmusic
        PRIVATE
            JUCE_COREAUDIO_ENABLED=1
    )
elseif(WIN32)
    # Windows specific
    target_compile_definitions(Echoelmusic
        PRIVATE
            JUCE_WASAPI=1
            JUCE_ASIO=1  # ASIO support for low latency
    )
elseif(UNIX)
    # Linux specific
    target_compile_definitions(Echoelmusic
        PRIVATE
            JUCE_JACK=1
            JUCE_ALSA=1
    )
endif()

# C++ standard
set_target_properties(Echoelmusic PROPERTIES
    CXX_STANDARD 20
    CXX_STANDARD_REQUIRED ON
)

# Optimization flags
if(CMAKE_BUILD_TYPE MATCHES Release)
    if(MSVC)
        target_compile_options(Echoelmusic PRIVATE /O2 /GL)
    else()
        target_compile_options(Echoelmusic PRIVATE -O3 -march=native)
    endif()
endif()

# Build summary
message(STATUS "")
message(STATUS "╔════════════════════════════════════════╗")
message(STATUS "║   Echoelmusic - JUCE Configuration    ║")
message(STATUS "╚════════════════════════════════════════╝")
message(STATUS "")
message(STATUS "Plugin Formats: ${FORMATS}")
message(STATUS "C++ Standard:   C++20")
message(STATUS "SIMD:           Enabled (SSE/AVX/NEON)")
message(STATUS "Platforms:      Windows, macOS, Linux, iOS, Android")
message(STATUS "Target Latency: <2ms @ 48kHz")
message(STATUS "Target CPU:     <15% @ 128 tracks")
message(STATUS "")
