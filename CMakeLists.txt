cmake_minimum_required(VERSION 3.22)

project(Echoelmusic VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

# ===========================
# JUCE Framework
# ===========================

# Add JUCE as subdirectory (will be downloaded via git submodule)
add_subdirectory(ThirdParty/JUCE)

# ===========================
# Plugin Formats
# ===========================

# Enable plugin formats
set(FORMATS
    VST3      # Steinberg VST3 (Open Source!)
    AU        # Apple Audio Units
    Standalone # Standalone App
)

# Add CLAP support if available
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/ThirdParty/clap")
    list(APPEND FORMATS CLAP)
    message(STATUS "CLAP support enabled")
endif()

# ===========================
# Echoelmusic Plugin
# ===========================

juce_add_plugin(Echoelmusic
    COMPANY_NAME "Echoelmusic"
    PLUGIN_MANUFACTURER_CODE Ech0
    PLUGIN_CODE Ech1
    FORMATS ${FORMATS}

    # Product name
    PRODUCT_NAME "Echoelmusic"

    # Plugin characteristics
    IS_SYNTH FALSE
    NEEDS_MIDI_INPUT TRUE
    NEEDS_MIDI_OUTPUT TRUE
    IS_MIDI_EFFECT FALSE
    EDITOR_WANTS_KEYBOARD_FOCUS TRUE

    # Copy plugin after build
    COPY_PLUGIN_AFTER_BUILD TRUE

    # VST3 specific
    VST3_CATEGORIES "Fx" "Analyzer"

    # AU specific
    AU_MAIN_TYPE "kAudioUnitType_Effect"

    # Bundle ID (for macOS/iOS)
    BUNDLE_ID "com.echoelmusic.plugin"

    # Description
    DESCRIPTION "Bio-Reactive Audio Processing with Heart Rate Variability"
    PLUGIN_NAME "Echoelmusic"
)

# ===========================
# Source Files
# ===========================

target_sources(Echoelmusic
    PRIVATE
        # Main Plugin
        Sources/Plugin/PluginProcessor.cpp
        Sources/Plugin/PluginEditor.cpp

        # DSP Core
        Sources/DSP/BioReactiveDSP.cpp
        Sources/DSP/ParametricEQ.cpp
        Sources/DSP/MultibandCompressor.cpp
        Sources/DSP/ConvolutionReverb.cpp
        Sources/DSP/BrickWallLimiter.cpp

        # Bio-Data Integration
        Sources/BioData/BioDataBridge.mm  # Objective-C++ for Swift bridge
        Sources/BioData/HRVProcessor.cpp

        # Synthesis
        Sources/Synthesis/FMSynthesizer.cpp
        Sources/Synthesis/WavetableSynthesizer.cpp
        Sources/Synthesis/PhysicalModeling.cpp

        # Visualization
        Sources/Visualization/SpectrumAnalyzer.cpp
        Sources/Visualization/BioReactiveVisualizer.cpp
)

# ===========================
# Include Directories
# ===========================

target_include_directories(Echoelmusic
    PUBLIC
        Sources/Plugin
        Sources/DSP
        Sources/BioData
        Sources/Synthesis
        Sources/Visualization
)

# ===========================
# JUCE Modules
# ===========================

target_link_libraries(Echoelmusic
    PRIVATE
        # JUCE Core
        juce::juce_core
        juce::juce_data_structures
        juce::juce_events

        # Audio
        juce::juce_audio_basics
        juce::juce_audio_devices
        juce::juce_audio_formats
        juce::juce_audio_plugin_client
        juce::juce_audio_processors
        juce::juce_audio_utils

        # DSP
        juce::juce_dsp

        # GUI
        juce::juce_gui_basics
        juce::juce_gui_extra

        # Graphics
        juce::juce_graphics
        juce::juce_opengl

    PUBLIC
        juce::juce_recommended_config_flags
        juce::juce_recommended_lto_flags
        juce::juce_recommended_warning_flags
)

# ===========================
# Compile Definitions
# ===========================

target_compile_definitions(Echoelmusic
    PUBLIC
        JUCE_WEB_BROWSER=0
        JUCE_USE_CURL=0
        JUCE_VST3_CAN_REPLACE_VST2=0

        # Disable JUCE splash screen for GPL builds
        JUCE_DISPLAY_SPLASH_SCREEN=0

        # Performance
        JUCE_USE_SIMD=1

        # Audio
        JUCE_PLUGINHOST_VST3=1
        JUCE_PLUGINHOST_AU=1
)

# ===========================
# Platform-Specific Settings
# ===========================

if(APPLE)
    target_compile_definitions(Echoelmusic
        PRIVATE
            JUCE_COREAUDIO_ENABLED=1
            JUCE_COREMIDI_ENABLED=1
    )

    # Link macOS/iOS frameworks
    target_link_libraries(Echoelmusic
        PRIVATE
            "-framework CoreAudio"
            "-framework CoreMIDI"
            "-framework AudioToolbox"
            "-framework Accelerate"
    )

    # HealthKit for bio-data
    if(IOS)
        target_link_libraries(Echoelmusic
            PRIVATE
                "-framework HealthKit"
        )
    endif()

elseif(WIN32)
    target_compile_definitions(Echoelmusic
        PRIVATE
            JUCE_WASAPI=1
            JUCE_ASIO=1
    )

elseif(UNIX)
    target_compile_definitions(Echoelmusic
        PRIVATE
            JUCE_ALSA=1
            JUCE_JACK=1
    )

    # Link ALSA and JACK
    target_link_libraries(Echoelmusic
        PRIVATE
            asound
            jack
    )
endif()

# ===========================
# CLAP Plugin Support
# ===========================

if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/ThirdParty/clap")
    # Add CLAP headers
    target_include_directories(Echoelmusic
        PRIVATE
            ThirdParty/clap/include
    )

    # Add CLAP wrapper source
    target_sources(Echoelmusic
        PRIVATE
            Sources/Plugin/CLAPWrapper.cpp
    )

    message(STATUS "Building CLAP plugin")
endif()

# ===========================
# Installation
# ===========================

# Install VST3
if(VST3 IN_LIST FORMATS)
    install(TARGETS Echoelmusic_VST3
        LIBRARY DESTINATION "$ENV{HOME}/Library/Audio/Plug-Ins/VST3"  # macOS
        RUNTIME DESTINATION "C:/Program Files/Common Files/VST3"      # Windows
    )
endif()

# Install AU
if(AU IN_LIST FORMATS AND APPLE)
    install(TARGETS Echoelmusic_AU
        LIBRARY DESTINATION "$ENV{HOME}/Library/Audio/Plug-Ins/Components"
    )
endif()

# Install CLAP
if(CLAP IN_LIST FORMATS)
    install(TARGETS Echoelmusic_CLAP
        LIBRARY DESTINATION "$ENV{HOME}/Library/Audio/Plug-Ins/CLAP"  # macOS
        RUNTIME DESTINATION "$ENV{APPDATA}/CLAP"                      # Windows
    )
endif()

# ===========================
# Documentation
# ===========================

add_custom_target(docs
    COMMAND echo "Building documentation..."
    COMMAND echo "Plugin Formats: ${FORMATS}"
    COMMAND echo "Install locations configured"
)

# ===========================
# Testing
# ===========================

option(BUILD_TESTING "Build tests" ON)

if(BUILD_TESTING)
    enable_testing()
    add_subdirectory(Tests)
endif()

# ===========================
# Summary
# ===========================

message(STATUS "==============================================")
message(STATUS "Echoelmusic Plugin Configuration")
message(STATUS "==============================================")
message(STATUS "Plugin Formats: ${FORMATS}")
message(STATUS "C++ Standard: ${CMAKE_CXX_STANDARD}")
message(STATUS "Build Type: ${CMAKE_BUILD_TYPE}")
message(STATUS "JUCE Version: 7.x")
message(STATUS "VST3: ${VST3}")
message(STATUS "==============================================")
