cmake_minimum_required(VERSION 3.22)

project(Echoelmusic VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# ===========================
# Platform Detection
# ===========================

if(WIN32)
    set(PLATFORM_WINDOWS TRUE)
    message(STATUS "Platform: Windows")
elseif(APPLE)
    set(PLATFORM_MACOS TRUE)
    message(STATUS "Platform: macOS/iOS")
elseif(UNIX AND NOT APPLE)
    set(PLATFORM_LINUX TRUE)
    message(STATUS "Platform: Linux")
elseif(ANDROID)
    set(PLATFORM_ANDROID TRUE)
    message(STATUS "Platform: Android")
endif()

# ===========================
# Build Options
# ===========================

option(BUILD_VST3 "Build VST3 plugin" ON)
option(BUILD_AU "Build Audio Units plugin" ON)
option(BUILD_AAX "Build AAX plugin for Pro Tools" ON)
option(BUILD_AUv3 "Build AUv3 plugin for iOS" ON)
option(BUILD_LV2 "Build LV2 plugin for Linux" ON)
option(BUILD_CLAP "Build CLAP plugin" ON)
option(BUILD_STANDALONE "Build standalone application" ON)

option(BUILD_ANDROID_APP "Build Android app" OFF)
option(BUILD_WINDOWS_VST3 "Build Windows VST3" ON)
option(BUILD_LINUX_VST3 "Build Linux VST3" ON)

option(ENABLE_ASIO "Enable ASIO support (Windows)" ON)
option(ENABLE_WASAPI "Enable WASAPI support (Windows)" ON)
option(ENABLE_DIRECTSOUND "Enable DirectSound (Windows)" ON)

option(ENABLE_ALSA "Enable ALSA support (Linux)" ON)
option(ENABLE_JACK "Enable JACK support (Linux)" ON)
option(ENABLE_PULSEAUDIO "Enable PulseAudio (Linux)" ON)

option(ENABLE_ANDROID_OBOE "Enable Oboe (Android)" ON)
option(ENABLE_ANDROID_AAUDIO "Enable AAudio (Android)" ON)

# ===========================
# JUCE Framework
# ===========================

add_subdirectory(ThirdParty/JUCE)

# ===========================
# Plugin Formats
# ===========================

set(FORMATS)

if(BUILD_VST3)
    list(APPEND FORMATS VST3)
endif()

if(BUILD_AU AND APPLE)
    list(APPEND FORMATS AU)
endif()

if(BUILD_AAX)
    list(APPEND FORMATS AAX)
endif()

if(BUILD_AUv3 AND IOS)
    list(APPEND FORMATS AUv3)
endif()

if(BUILD_LV2 AND UNIX)
    list(APPEND FORMATS LV2)
endif()

if(BUILD_CLAP)
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/ThirdParty/clap")
        list(APPEND FORMATS CLAP)
    endif()
endif()

if(BUILD_STANDALONE)
    list(APPEND FORMATS Standalone)
endif()

message(STATUS "Plugin Formats: ${FORMATS}")

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
    VST3_CATEGORIES "Fx" "Analyzer" "Tools"
    VST3_AUTO_MANIFEST FALSE

    # AU specific
    AU_MAIN_TYPE "kAudioUnitType_Effect"
    AU_SANDBOX_SAFE TRUE

    # AAX specific
    AAX_CATEGORY "AAX_ePlugInCategory_Effect"

    # AUv3 specific (iOS)
    IPHONE_SCREEN_ORIENTATIONS UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight
    IPAD_SCREEN_ORIENTATIONS UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight

    # Bundle ID
    BUNDLE_ID "com.echoelmusic.plugin"

    # Description
    DESCRIPTION "Bio-Reactive Audio Processing - Heart Rate Variability meets Professional Audio"
    PLUGIN_NAME "Echoelmusic"

    # Icon
    ICON_BIG "${CMAKE_CURRENT_SOURCE_DIR}/Resources/Icon-512.png"
    ICON_SMALL "${CMAKE_CURRENT_SOURCE_DIR}/Resources/Icon-64.png"
)

# ===========================
# Source Files
# ===========================

target_sources(Echoelmusic
    PRIVATE
        # Main Plugin
        Sources/Plugin/PluginProcessor.cpp
        Sources/Plugin/PluginProcessor.h
        Sources/Plugin/PluginEditor.cpp
        Sources/Plugin/PluginEditor.h

        # DSP Core
        Sources/DSP/BioReactiveDSP.cpp
        Sources/DSP/BioReactiveDSP.h
        Sources/DSP/AdvancedDSP.cpp
        Sources/DSP/AdvancedDSP.h

        # Advanced Effects (ported from Swift)
        Sources/DSP/Effects/ParametricEQ.cpp
        Sources/DSP/Effects/ParametricEQ.h
        Sources/DSP/Effects/MultibandCompressor.cpp
        Sources/DSP/Effects/MultibandCompressor.h
        Sources/DSP/Effects/ConvolutionReverb.cpp
        Sources/DSP/Effects/ConvolutionReverb.h
        Sources/DSP/Effects/BrickWallLimiter.cpp
        Sources/DSP/Effects/BrickWallLimiter.h
        Sources/DSP/Effects/DeEsser.cpp
        Sources/DSP/Effects/DeEsser.h
        Sources/DSP/Effects/TapeDelay.cpp
        Sources/DSP/Effects/TapeDelay.h
        Sources/DSP/Effects/StereoImager.cpp
        Sources/DSP/Effects/StereoImager.h

        # Synthesis
        Sources/Synthesis/FMSynthesizer.cpp
        Sources/Synthesis/FMSynthesizer.h
        Sources/Synthesis/WavetableSynthesizer.cpp
        Sources/Synthesis/WavetableSynthesizer.h
        Sources/Synthesis/PhysicalModeling.cpp
        Sources/Synthesis/PhysicalModeling.h
        Sources/Synthesis/GranularSynthesis.cpp
        Sources/Synthesis/GranularSynthesis.h

        # Visualization
        Sources/Visualization/SpectrumAnalyzer.cpp
        Sources/Visualization/SpectrumAnalyzer.h
        Sources/Visualization/BioReactiveVisualizer.cpp
        Sources/Visualization/BioReactiveVisualizer.h
        Sources/Visualization/WaveformDisplay.cpp
        Sources/Visualization/WaveformDisplay.h

        # Bio-Data Integration
        Sources/BioData/BioDataBridge.mm
        Sources/BioData/BioDataBridge.h
        Sources/BioData/HRVProcessor.cpp
        Sources/BioData/HRVProcessor.h

        # Hardware Integration
        Sources/Hardware/AbletonLink.cpp
        Sources/Hardware/AbletonLink.h
        Sources/Hardware/MIDIHardwareManager.cpp
        Sources/Hardware/MIDIHardwareManager.h
        Sources/Hardware/ModularIntegration.cpp
        Sources/Hardware/ModularIntegration.h
        Sources/Hardware/DJEquipmentIntegration.cpp
        Sources/Hardware/DJEquipmentIntegration.h
        Sources/Hardware/OSCManager.cpp
        Sources/Hardware/OSCManager.h
        Sources/Hardware/HardwareSyncManager.cpp
        Sources/Hardware/HardwareSyncManager.h

        # Video Editing
        Sources/Video/VideoWeaver.cpp
        Sources/Video/VideoWeaver.h

        # Spatial Audio
        Sources/Audio/SpatialForge.cpp
        Sources/Audio/SpatialForge.h

        # Platform/Business Management
        Sources/Platform/CreatorManager.cpp
        Sources/Platform/CreatorManager.h
        Sources/Platform/AgencyManager.cpp
        Sources/Platform/AgencyManager.h
        Sources/Platform/GlobalReachOptimizer.cpp
        Sources/Platform/GlobalReachOptimizer.h
        Sources/Platform/EchoHub.cpp
        Sources/Platform/EchoHub.h

        # Platform-Specific
        $<$<PLATFORM_ID:Windows>:Sources/Platform/Windows/WindowsAudio.cpp>
        $<$<PLATFORM_ID:Linux>:Sources/Platform/Linux/LinuxAudio.cpp>
        $<$<PLATFORM_ID:Android>:Sources/Platform/Android/AndroidAudio.cpp>
)

# ===========================
# Include Directories
# ===========================

target_include_directories(Echoelmusic
    PUBLIC
        Sources
        Sources/Plugin
        Sources/DSP
        Sources/DSP/Effects
        Sources/Synthesis
        Sources/Visualization
        Sources/BioData
        Sources/Hardware
        Sources/Video
        Sources/Audio
        Sources/Platform
)

# ===========================
# JUCE Modules
# ===========================

target_link_libraries(Echoelmusic
    PRIVATE
        # Core
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

        # Video (for VideoWeaver)
        juce::juce_video

        # OSC (for OSCManager)
        juce::juce_osc

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
        JUCE_DISPLAY_SPLASH_SCREEN=0
        JUCE_USE_SIMD=1

        # Plugin Host Support
        JUCE_PLUGINHOST_VST3=1
        JUCE_PLUGINHOST_AU=1
        JUCE_PLUGINHOST_LADSPA=0

        # Modal Loops
        JUCE_MODAL_LOOPS_PERMITTED=0

        # Strict mode
        JUCE_STRICT_REFCOUNTEDPOINTER=1
)

# ===========================
# Platform-Specific Settings
# ===========================

# macOS / iOS
if(APPLE)
    target_compile_definitions(Echoelmusic
        PRIVATE
            JUCE_COREAUDIO_ENABLED=1
            JUCE_COREMIDI_ENABLED=1
    )

    target_link_libraries(Echoelmusic
        PRIVATE
            "-framework CoreAudio"
            "-framework CoreMIDI"
            "-framework AudioToolbox"
            "-framework Accelerate"
            "-framework CoreFoundation"
    )

    if(IOS)
        target_link_libraries(Echoelmusic
            PRIVATE
                "-framework HealthKit"
                "-framework UIKit"
        )
    endif()

    # Universal Binary (Intel + Apple Silicon)
    set_target_properties(Echoelmusic PROPERTIES
        OSX_ARCHITECTURES "arm64;x86_64"
        OSX_DEPLOYMENT_TARGET "12.0"
    )

# Windows
elseif(WIN32)
    target_compile_definitions(Echoelmusic
        PRIVATE
            # Audio backends
            $<$<BOOL:${ENABLE_WASAPI}>:JUCE_WASAPI=1>
            $<$<BOOL:${ENABLE_ASIO}>:JUCE_ASIO=1>
            $<$<BOOL:${ENABLE_DIRECTSOUND}>:JUCE_DIRECTSOUND=1>

            # Windows specific
            _UNICODE
            UNICODE
            NOMINMAX
            WIN32_LEAN_AND_MEAN
    )

    # Link Windows libraries
    target_link_libraries(Echoelmusic
        PRIVATE
            winmm
            ole32
            oleaut32
            uuid
            wsock32
            wininet
            version
            shlwapi
            Dwmapi
    )

    # ASIO SDK (if available)
    if(ENABLE_ASIO AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/ThirdParty/asiosdk")
        target_include_directories(Echoelmusic
            PRIVATE
                ThirdParty/asiosdk/common
        )
    endif()

# Linux
elseif(UNIX AND NOT APPLE)
    target_compile_definitions(Echoelmusic
        PRIVATE
            # Audio backends
            $<$<BOOL:${ENABLE_ALSA}>:JUCE_ALSA=1>
            $<$<BOOL:${ENABLE_JACK}>:JUCE_JACK=1>
            $<$<BOOL:${ENABLE_PULSEAUDIO}>:JUCE_USE_PULSEAUDIO=1>

            # Linux specific
            LINUX=1
    )

    # Find required packages
    find_package(PkgConfig REQUIRED)

    # ALSA
    if(ENABLE_ALSA)
        pkg_check_modules(ALSA REQUIRED alsa)
        target_link_libraries(Echoelmusic PRIVATE ${ALSA_LIBRARIES})
        target_include_directories(Echoelmusic PRIVATE ${ALSA_INCLUDE_DIRS})
    endif()

    # JACK
    if(ENABLE_JACK)
        pkg_check_modules(JACK jack)
        if(JACK_FOUND)
            target_link_libraries(Echoelmusic PRIVATE ${JACK_LIBRARIES})
            target_include_directories(Echoelmusic PRIVATE ${JACK_INCLUDE_DIRS})
        endif()
    endif()

    # PulseAudio
    if(ENABLE_PULSEAUDIO)
        pkg_check_modules(PULSE libpulse)
        if(PULSE_FOUND)
            target_link_libraries(Echoelmusic PRIVATE ${PULSE_LIBRARIES})
            target_include_directories(Echoelmusic PRIVATE ${PULSE_INCLUDE_DIRS})
        endif()
    endif()

    # Standard Linux libraries
    target_link_libraries(Echoelmusic
        PRIVATE
            pthread
            dl
            rt
            X11
            Xext
            freetype
    )

# Android
elseif(ANDROID)
    target_compile_definitions(Echoelmusic
        PRIVATE
            JUCE_ANDROID=1
            $<$<BOOL:${ENABLE_ANDROID_OBOE}>:JUCE_USE_ANDROID_OBOE=1>
            $<$<BOOL:${ENABLE_ANDROID_AAUDIO}>:JUCE_USE_ANDROID_AAUDIO=1>
    )

    # Oboe (Google's low-latency audio library)
    if(ENABLE_ANDROID_OBOE AND EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/ThirdParty/oboe")
        add_subdirectory(ThirdParty/oboe)
        target_link_libraries(Echoelmusic PRIVATE oboe)
    endif()

    target_link_libraries(Echoelmusic
        PRIVATE
            android
            log
            OpenSLES
    )
endif()

# ===========================
# AAX SDK (Pro Tools)
# ===========================

if(BUILD_AAX)
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/ThirdParty/AAX_SDK")
        message(STATUS "AAX SDK found - building AAX plugin")
        target_include_directories(Echoelmusic
            PRIVATE
                ThirdParty/AAX_SDK/Interfaces
                ThirdParty/AAX_SDK/Interfaces/ACF
        )

        # AAX requires code signing on macOS
        if(APPLE)
            set_target_properties(Echoelmusic_AAX PROPERTIES
                XCODE_ATTRIBUTE_CODE_SIGN_IDENTITY "Developer ID Application"
            )
        endif()
    else()
        message(WARNING "AAX SDK not found - AAX plugin disabled")
        list(REMOVE_ITEM FORMATS AAX)
    endif()
endif()

# ===========================
# LV2 Support (Linux)
# ===========================

if(BUILD_LV2 AND UNIX)
    # LV2 is typically built via separate mechanism
    # JUCE doesn't natively support LV2, so we'd need a wrapper
    message(STATUS "LV2 support requires additional wrapper")
endif()

# ===========================
# Installation
# ===========================

# Install paths
if(APPLE)
    set(VST3_INSTALL_DIR "$ENV{HOME}/Library/Audio/Plug-Ins/VST3")
    set(AU_INSTALL_DIR "$ENV{HOME}/Library/Audio/Plug-Ins/Components")
    set(AAX_INSTALL_DIR "$ENV{HOME}/Library/Application Support/Avid/Audio/Plug-Ins")
    set(CLAP_INSTALL_DIR "$ENV{HOME}/Library/Audio/Plug-Ins/CLAP")
elseif(WIN32)
    set(VST3_INSTALL_DIR "C:/Program Files/Common Files/VST3")
    set(AAX_INSTALL_DIR "C:/Program Files/Common Files/Avid/Audio/Plug-Ins")
    set(CLAP_INSTALL_DIR "$ENV{APPDATA}/CLAP")
elseif(UNIX)
    set(VST3_INSTALL_DIR "$ENV{HOME}/.vst3")
    set(LV2_INSTALL_DIR "$ENV{HOME}/.lv2")
    set(CLAP_INSTALL_DIR "$ENV{HOME}/.clap")
endif()

# Install targets
foreach(FORMAT ${FORMATS})
    if(FORMAT STREQUAL "VST3")
        install(TARGETS Echoelmusic_VST3 DESTINATION "${VST3_INSTALL_DIR}")
    elseif(FORMAT STREQUAL "AU" AND APPLE)
        install(TARGETS Echoelmusic_AU DESTINATION "${AU_INSTALL_DIR}")
    elseif(FORMAT STREQUAL "AAX")
        install(TARGETS Echoelmusic_AAX DESTINATION "${AAX_INSTALL_DIR}")
    elseif(FORMAT STREQUAL "CLAP")
        install(TARGETS Echoelmusic_CLAP DESTINATION "${CLAP_INSTALL_DIR}")
    elseif(FORMAT STREQUAL "Standalone")
        install(TARGETS Echoelmusic_Standalone DESTINATION bin)
    endif()
endforeach()

# ===========================
# Summary
# ===========================

message(STATUS "==============================================")
message(STATUS "Echoelmusic - Universal Plugin Build")
message(STATUS "==============================================")
message(STATUS "Platform: ${CMAKE_SYSTEM_NAME}")
message(STATUS "Formats: ${FORMATS}")
message(STATUS "C++ Standard: ${CMAKE_CXX_STANDARD}")
message(STATUS "Build Type: ${CMAKE_BUILD_TYPE}")
if(APPLE)
    message(STATUS "Architectures: arm64, x86_64")
endif()
message(STATUS "==============================================")
message(STATUS "Audio Backends:")
if(APPLE)
    message(STATUS "  - CoreAudio (macOS/iOS)")
endif()
if(WIN32)
    message(STATUS "  - WASAPI: ${ENABLE_WASAPI}")
    message(STATUS "  - ASIO: ${ENABLE_ASIO}")
    message(STATUS "  - DirectSound: ${ENABLE_DIRECTSOUND}")
endif()
if(UNIX AND NOT APPLE)
    message(STATUS "  - ALSA: ${ENABLE_ALSA}")
    message(STATUS "  - JACK: ${ENABLE_JACK}")
    message(STATUS "  - PulseAudio: ${ENABLE_PULSEAUDIO}")
endif()
if(ANDROID)
    message(STATUS "  - Oboe: ${ENABLE_ANDROID_OBOE}")
    message(STATUS "  - AAudio: ${ENABLE_ANDROID_AAUDIO}")
endif()
message(STATUS "==============================================")
