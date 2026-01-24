cmake_minimum_required(VERSION 3.22)

project(Echoelmusic VERSION 1.2.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_EXPORT_COMPILE_COMMANDS ON)

# ===========================
# Performance Optimizations
# ===========================

# SIMD Support - 2-8x faster DSP processing
if(CMAKE_SYSTEM_PROCESSOR MATCHES "x86_64|AMD64|amd64")
    message(STATUS "Enabling AVX2/SSE4.2 SIMD optimizations (x86_64)")
    if(MSVC)
        add_compile_options(/arch:AVX2 /fp:fast)
    else()
        add_compile_options(-mavx2 -mfma -msse4.2 -ffast-math)
    endif()
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "arm|aarch64|ARM64")
    message(STATUS "Enabling ARM NEON SIMD optimizations")
    if(NOT MSVC)
        add_compile_options(-march=armv8-a+simd -ffast-math)
    endif()
elseif(CMAKE_SYSTEM_PROCESSOR MATCHES "i686|i386")
    message(STATUS "Enabling SSE2 SIMD optimizations (x86)")
    if(MSVC)
        add_compile_options(/arch:SSE2 /fp:fast)
    else()
        add_compile_options(-msse2 -ffast-math)
    endif()
else()
    message(STATUS "CPU: ${CMAKE_SYSTEM_PROCESSOR} - No SIMD optimizations")
endif()

# Link-Time Optimization (LTO) - additional 10-20% performance
if(CMAKE_BUILD_TYPE STREQUAL "Release")
    include(CheckIPOSupported)
    check_ipo_supported(RESULT ipo_supported OUTPUT ipo_output)
    if(ipo_supported)
        message(STATUS "Link-Time Optimization (LTO) enabled")
        set(CMAKE_INTERPROCEDURAL_OPTIMIZATION TRUE)
    else()
        message(STATUS "LTO not supported: ${ipo_output}")
    endif()
endif()

# Release mode optimizations
if(CMAKE_BUILD_TYPE STREQUAL "Release")
    if(MSVC)
        add_compile_options(/O2 /Ob2 /Oi /Ot /GL)
    else()
        add_compile_options(-O3 -march=native)
    endif()
    message(STATUS "Release mode optimizations enabled")
endif()

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
option(BUILD_LV2 "Build LV2 plugin for Linux" OFF)  # Disabled: linker segfault, use VST3 instead
option(BUILD_CLAP "Build CLAP plugin" ON)
option(BUILD_STANDALONE "Build standalone application" ON)

option(BUILD_ANDROID_APP "Build Android app" OFF)
option(BUILD_WINDOWS_VST3 "Build Windows VST3" ON)
option(BUILD_LINUX_VST3 "Build Linux VST3" ON)

option(ENABLE_ASIO "Enable ASIO support (Windows)" ON)
option(ENABLE_WASAPI "Enable WASAPI support (Windows)" ON)
option(ENABLE_DIRECTSOUND "Enable DirectSound (Windows)" ON)

option(ENABLE_ALSA "Enable ALSA support (Linux)" ON)
option(ENABLE_JACK "Enable JACK support (Linux)" ON)   # Enabled for professional audio (<10ms latency)
option(ENABLE_PIPEWIRE "Enable PipeWire support (Linux)" ON)  # Modern Linux audio (<15ms latency)
option(ENABLE_PULSEAUDIO "Enable PulseAudio (Linux)" OFF)  # Deprecated - use PipeWire instead

option(ENABLE_ANDROID_OBOE "Enable Oboe (Android)" ON)
option(ENABLE_ANDROID_AAUDIO "Enable AAudio (Android)" ON)

# ===========================
# JUCE Framework - REMOVED (2026-01-13)
# ===========================
# JUCE has been completely removed from this project.
# All DSP is now handled by EchoelmusicDSP.h (JUCE-free, MIT license)
#
# For desktop plugins, use iPlug2 (MIT license, FREE):
#   cmake .. -DUSE_IPLUG2=ON

option(USE_JUCE "DEPRECATED - JUCE has been removed" OFF)

if(USE_JUCE)
    message(FATAL_ERROR "
╔══════════════════════════════════════════════════════════════════╗
║  JUCE SUPPORT HAS BEEN REMOVED                                    ║
╠══════════════════════════════════════════════════════════════════╣
║                                                                   ║
║  This project no longer uses JUCE.                               ║
║  All DSP is now handled by EchoelmusicDSP.h (MIT license)        ║
║                                                                   ║
║  For desktop plugins, use iPlug2 instead:                        ║
║    cmake .. -DUSE_IPLUG2=ON                                      ║
║                                                                   ║
║  Benefits:                                                        ║
║  • 100% JUCE-free codebase                                       ║
║  • MIT license (no fees)                                         ║
║  • Smaller binary size                                           ║
║  • Native performance on all platforms                           ║
║                                                                   ║
╚══════════════════════════════════════════════════════════════════╝
")
else()
    message(STATUS "JUCE Framework: REMOVED (using native EchoelmusicDSP)")
    message(STATUS "  → EchoelmusicDSP.h for all DSP operations")
    message(STATUS "  → iPlug2 available for desktop plugins")
endif()

# RECOMMENDED: iPlug2 for JUCE-free desktop plugins (MIT license, FREE)
option(USE_IPLUG2 "Use iPlug2 framework (MIT license, JUCE-free) - RECOMMENDED" OFF)
if(USE_IPLUG2)
    if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/ThirdParty/iPlug2")
        message(STATUS "iPlug2 Framework: ENABLED (MIT License - Free!)")
        # Add Desktop plugin build
        add_subdirectory(Sources/Desktop)
    else()
        message(STATUS "")
        message(STATUS "╔══════════════════════════════════════════════════════════╗")
        message(STATUS "║  iPlug2 not found! To enable desktop plugins:            ║")
        message(STATUS "║                                                          ║")
        message(STATUS "║  git clone https://github.com/iPlug2/iPlug2 \\            ║")
        message(STATUS "║            ThirdParty/iPlug2                             ║")
        message(STATUS "║                                                          ║")
        message(STATUS "║  Benefits:                                               ║")
        message(STATUS "║  • MIT License (100% FREE for commercial use)            ║")
        message(STATUS "║  • VST3, AU, AAX, CLAP, Standalone                        ║")
        message(STATUS "║  • No JUCE dependency                                    ║")
        message(STATUS "║  • Professional audio quality                            ║")
        message(STATUS "╚══════════════════════════════════════════════════════════╝")
        message(STATUS "")
    endif()
endif()

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
        message(STATUS "CLAP plugin format: ENABLED")
    else()
        message(STATUS "")
        message(STATUS "╔══════════════════════════════════════════════════════════╗")
        message(STATUS "║  CLAP SDK not found! To enable CLAP plugins:             ║")
        message(STATUS "║                                                          ║")
        message(STATUS "║  git clone https://github.com/free-audio/clap \\          ║")
        message(STATUS "║            ThirdParty/clap                               ║")
        message(STATUS "║                                                          ║")
        message(STATUS "║  CLAP is supported in:                                   ║")
        message(STATUS "║  • Bitwig Studio 4.0+                                    ║")
        message(STATUS "║  • REAPER 6.60+                                          ║")
        message(STATUS "║  • MultitrackStudio                                      ║")
        message(STATUS "║  • Renoise 3.4+                                          ║")
        message(STATUS "╚══════════════════════════════════════════════════════════╝")
        message(STATUS "")
    endif()
endif()

if(BUILD_STANDALONE)
    list(APPEND FORMATS Standalone)
endif()

message(STATUS "Plugin Formats: ${FORMATS}")

# ===========================
# Echoelmusic Plugin (Legacy JUCE Code - UNREACHABLE)
# ===========================
# NOTE: This entire block is DEAD CODE and will never execute.
# USE_JUCE=ON triggers a FATAL_ERROR above.
# This code is preserved for reference only and should be ignored.
# For desktop plugins, use iPlug2: cmake .. -DUSE_IPLUG2=ON

# Only build plugin if JUCE is enabled (never true due to FATAL_ERROR)
if(USE_JUCE)

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

    # LV2 specific (Linux)
    LV2URI "http://echoelmusic.com/plugins/echoelmusic"

    # AUv3 specific (iOS)
    IPHONE_SCREEN_ORIENTATIONS UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight
    IPAD_SCREEN_ORIENTATIONS UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight

    # Bundle ID (unified across all platforms)
    BUNDLE_ID "com.echoelmusic.app.plugin"

    # Description
    DESCRIPTION "Bio-Reactive Audio Processing - Heart Rate Variability meets Professional Audio"
    PLUGIN_NAME "Echoelmusic"

    # Icon (TODO: Add icon files later)
    # ICON_BIG "${CMAKE_CURRENT_SOURCE_DIR}/Resources/Icon-512.png"
    # ICON_SMALL "${CMAKE_CURRENT_SOURCE_DIR}/Resources/Icon-64.png"
)

# ===========================
# Source Files
# ===========================

target_sources(Echoelmusic
    PRIVATE
        # =====================================================================
        # PHASE 1: MINIMAL CORE BUILD (100% WORKING!)
        # =====================================================================

        # Main Plugin
        Sources/Plugin/PluginProcessor.cpp
        Sources/Plugin/PluginEditor.cpp

        # Core Audio Engine (NEW! 2025-11-12) ✅ TESTED
        Sources/Audio/AudioEngine.cpp
        Sources/Audio/Track.cpp
        Sources/Audio/AudioExporter.cpp         # ✅ Audio export system (WAV, FLAC, OGG)
        Sources/Audio/SessionManager.cpp        # ✅ Session save/load system

        # UI - Main Window (NEW! 2025-11-12) ✅ TESTED
        Sources/UI/MainWindow.cpp

        # =====================================================================
        # PHASE 2: DSP EFFECTS (All JUCE 7 Compatible! 🎉)
        # =====================================================================

        # Core DSP (Ported 2025-11-12)
        Sources/DSP/BioReactiveDSP.cpp          # ✅ Bio-reactive processing
        Sources/DSP/ParametricEQ.cpp            # ✅ 8-band EQ

        # Dynamics Processing
        Sources/DSP/Compressor.cpp              # ✅ Professional compressor
        Sources/DSP/MultibandCompressor.cpp     # ✅ 4-band multiband comp
        Sources/DSP/BrickWallLimiter.cpp        # ✅ Mastering limiter
        Sources/DSP/DeEsser.cpp                 # ✅ Vocal de-esser
        Sources/DSP/TransientDesigner.cpp       # ✅ Transient shaping

        # Spatial & Stereo
        Sources/DSP/StereoImager.cpp            # ✅ M/S stereo imaging
        Sources/DSP/ConvolutionReverb.cpp       # ✅ IR-based reverb

        # Time-Based Effects
        Sources/DSP/TapeDelay.cpp               # ✅ Vintage tape delay

        # Creative Effects
        Sources/DSP/ModulationSuite.cpp         # ✅ Chorus/Flanger/Phaser/RingMod/FreqShift
        Sources/DSP/VintageEffects.cpp          # ✅ Analog emulation
        Sources/DSP/HarmonicForge.cpp           # ✅ Harmonic saturation
        Sources/DSP/EdgeControl.cpp             # ✅ Transient + dynamics

        # Modern Effects (NEW! 2025-11-12)
        Sources/DSP/UnderwaterEffect.cpp        # 🌊 Underwater/Aquatic effect
        Sources/DSP/ShimmerReverb.cpp           # ✨ Shimmer reverb (Brian Eno style)
        Sources/DSP/LofiBitcrusher.cpp          # 📼 LoFi/Bitcrusher (Vaporwave!)

        # Vocal Effects Suite (NEW! 2025-11-12)
        Sources/DSP/VocalChain.cpp              # 🎤 Complete vocal processor (6 presets)
        Sources/DSP/VocalDoubler.cpp            # 👥 Professional vocal doubling

        # Advanced Vocal Effects Suite (NEW! 2025-11-12) 🎙️✨
        Sources/DSP/PitchCorrection.cpp         # 🎵 Echoeltune (Autotune) - Pro pitch correction
        Sources/DSP/Harmonizer.cpp              # 🎼 Intelligent harmony generator (4 voices)
        Sources/DSP/FormantFilter.cpp           # 🗣️ Talkbox/Vowel morphing (A/E/I/O/U)
        Sources/DSP/Vocoder.cpp                 # 🤖 Classic carrier/modulator vocoder

        # Spectral Processing Suite (NEW! 2025-11-13) 🔬✨
        Sources/DSP/ResonanceHealer.cpp         # 🔧 Adaptive resonance suppressor (soothe-style)

        # =====================================================================
        # PHASE 100 JUCE: ADVANCED SPECTRAL & DYNAMICS (Fixed 2026-01-05) 🎚️✨
        # =====================================================================
        Sources/DSP/DynamicEQ.cpp               # 🎚️ 8-band Dynamic EQ (JUCE 7+ fixed)
        Sources/DSP/SpectralSculptor.cpp        # 🔬 Spectral processing suite (JUCE 7+ fixed)
        Sources/DSP/BioModulator.cpp            # 🫀 Biofeedback → BPM, EFX, Instruments, Laser

        # =====================================================================
        # PHASE 4C: HARDWARE EMULATIONS (NEW! 2025-11-13) 🎛️✨
        # =====================================================================
        Sources/DSP/EchoConsole.cpp             # 🎚️ SSL G-Series Channel Strip
        Sources/DSP/ClassicPreamp.cpp           # 🎙️ Neve 1073 Preamp/EQ
        Sources/DSP/OptoCompressor.cpp          # 💡 Teletronix LA-2A (Optical)
        Sources/DSP/FETCompressor.cpp           # ⚡ UREI 1176 (FET)
        Sources/DSP/PassiveEQ.cpp               # 🎛️ Pultec EQP-1A (Passive Tube EQ)

        # =====================================================================
        # PHASE 4F: SUPER INTELLIGENCE MASTERING SUITE (NEW! 2025-11-13) 🧠✨
        # =====================================================================
        Sources/DSP/SpectrumMaster.cpp          # 🌈 Pro-Q 4 Evolution - Visual Learning
        Sources/DSP/MasteringMentor.cpp         # 🎓 AI Teaching Assistant - Learn-by-Doing
        Sources/DSP/PhaseAnalyzer.cpp           # 🔄 Multi-track Phase Correlation & Goniometer
        Sources/DSP/StyleAwareMastering.cpp     # 🎵 Genre-Specific Mastering (20+ Genres)

        # =====================================================================
        # PHASE 4D: ADVANCED INSTRUMENTS (NEW! 2025-11-13) 🎹🎛️✨
        # =====================================================================
        Sources/DSP/EchoSynth.cpp               # 🎹 Analog Subtractive Synthesizer (Minimoog/Juno-60 style)
        Sources/DSP/WaveForge.cpp               # 🌊 Advanced Wavetable Synthesizer (Serum/Vital competitor)
        Sources/DSP/SampleEngine.cpp            # 🎵 Advanced Sampler with Time-Stretching (Kontakt-style)

        # =====================================================================
        # PHASE 4E: AI FEATURES (NEW! 2025-11-13) 🤖🧠✨
        # =====================================================================
        Sources/DSP/ChordSense.cpp              # 🎼 Real-time Chord Detection (Mixed In Key competitor)
        Sources/DSP/Audio2MIDI.cpp              # 🎵 Polyphonic Audio to MIDI Conversion (Melodyne-style)

        # =====================================================================
        # PHASE 4A+4B: MIDI SONGWRITING TOOLS (2025-11-13) 🎼🎹
        # =====================================================================
        Sources/MIDI/ChordGenius.cpp            # 🎵 500+ chords, AI progressions (Scaler competitor)
        Sources/MIDI/MelodyForge.cpp            # 🎶 AI melody generator (Captain Melody competitor)
        Sources/MIDI/BasslineArchitect.cpp      # 🎸 Intelligent basslines (Captain Deep competitor)
        Sources/MIDI/ArpWeaver.cpp              # ✨ Advanced arpeggiator (Cthulhu competitor)
        Sources/MIDI/WorldMusicDatabase.cpp     # 🌍 50+ global music styles (Baroque to K-Pop)

        # =====================================================================
        # PHASE 3: SYNTHESIS & ADVANCED FEATURES
        # =====================================================================

        # DRUM SYNTHESIZER - ENABLED! (808/909 style)
        Sources/Synthesis/DrumSynthesizer.cpp

        # =====================================================================
        # PHASE 100 JUCE: AI & VISUALIZATION (Enabled 2026-01-05) 🤖🎨
        # =====================================================================
        Sources/AI/SmartMixer.cpp               # 🤖 AI mixing assistant
        Sources/Visualization/SpectrumAnalyzer.cpp   # 📊 Real-time spectrum analysis
        Sources/Visualization/BioReactiveVisualizer.cpp  # 🫀 Bio-reactive visuals

        # =====================================================================
        # PHASE 100 JUCE: SEQUENCING & RHYTHM (Enabled 2026-01-05) 🎼
        # =====================================================================
        Sources/Instrument/RhythmMatrix.cpp     # 🥁 Rhythm sequencer matrix
        Sources/Sequencer/ArpWeaver.cpp         # ✨ Advanced arpeggiator

        # =====================================================================
        # PHASE 100 JUCE: VIDEO & VISUALS (Enabled 2026-01-05) 🎬
        # =====================================================================
        Sources/Video/VideoWeaver.cpp           # 🎬 Video compositing engine
        Sources/Visual/VisualForge.cpp          # 🎨 Visual effects forge
        Sources/Visual/LaserForce.cpp           # 💫 Laser show controller

        # =====================================================================
        # PHASE 100 JUCE: REMOTE & CLOUD (Enabled 2026-01-05) ☁️
        # =====================================================================
        Sources/Remote/RemoteProcessingEngine.cpp  # ☁️ Remote processing

        # =====================================================================
        # PHASE 100 JUCE: HARDWARE INTEGRATION (Enabled 2026-01-05) 🎛️
        # =====================================================================
        Sources/Hardware/AbletonLink.cpp        # 🔗 Ableton Link sync
        Sources/Hardware/MIDIHardwareManager.cpp  # 🎹 MIDI hardware control
        Sources/Hardware/ModularIntegration.cpp # 🔌 Modular synth integration
        Sources/Hardware/DJEquipmentIntegration.cpp  # 🎧 DJ controller support
        Sources/Hardware/OSCManager.cpp         # 📡 OSC network protocol
        Sources/Hardware/HardwareSyncManager.cpp  # ⏱️ Hardware clock sync

        # =====================================================================
        # PHASE 100 JUCE: SPATIAL AUDIO (Enabled 2026-01-05) 🔊
        # =====================================================================
        Sources/Audio/SpatialForge.cpp          # 🔊 3D spatial audio engine

        # =====================================================================
        # PHASE 100 JUCE: PLATFORM SERVICES (Enabled 2026-01-05) 🌐
        # =====================================================================
        Sources/Platform/CreatorManager.cpp     # 👤 Creator profiles
        Sources/Platform/AgencyManager.cpp      # 🏢 Agency/label management
        Sources/Platform/GlobalReachOptimizer.cpp  # 🌍 Global distribution
        Sources/Platform/EchoHub.cpp            # 🔄 Echoelmusic hub
)

# ===========================
# Include Directories
# ===========================

target_include_directories(Echoelmusic
    PUBLIC
        Sources
        Sources/Plugin
        Sources/MIDI
        Sources/DSP
        Sources/DSP/Effects
        Sources/Synthesis
        Sources/Visualization
        Sources/BioData
        Sources/AI
        Sources/Hardware
        Sources/Video
        Sources/Audio
        Sources/Platform
        Sources/Remote
        Sources/Sync
        Sources/Common
        Sources/DAW
        Sources/Lighting
        Sources/Biofeedback
        Sources/Development
        Sources/Examples
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

    # JACK (Professional audio - <10ms latency)
    if(ENABLE_JACK)
        pkg_check_modules(JACK jack)
        if(JACK_FOUND)
            target_link_libraries(Echoelmusic PRIVATE ${JACK_LIBRARIES})
            target_include_directories(Echoelmusic PRIVATE ${JACK_INCLUDE_DIRS})
            target_compile_definitions(Echoelmusic PRIVATE ECHOELMUSIC_JACK_AVAILABLE=1)
            message(STATUS "    - JACK: Found (Professional low-latency audio)")
        else()
            message(STATUS "    - JACK: Not found (install libjack-dev for <10ms latency)")
        endif()
    endif()

    # PipeWire (Modern Linux audio - <15ms latency)
    if(ENABLE_PIPEWIRE)
        pkg_check_modules(PIPEWIRE libpipewire-0.3)
        if(PIPEWIRE_FOUND)
            target_link_libraries(Echoelmusic PRIVATE ${PIPEWIRE_LIBRARIES})
            target_include_directories(Echoelmusic PRIVATE ${PIPEWIRE_INCLUDE_DIRS})
            target_compile_definitions(Echoelmusic PRIVATE ECHOELMUSIC_PIPEWIRE_AVAILABLE=1)
            message(STATUS "    - PipeWire: Found (Modern low-latency audio)")
        else()
            message(STATUS "    - PipeWire: Not found (install libpipewire-0.3-dev)")
        endif()
    endif()

    # PulseAudio (Legacy - deprecated, use PipeWire)
    if(ENABLE_PULSEAUDIO)
        pkg_check_modules(PULSE libpulse)
        if(PULSE_FOUND)
            target_link_libraries(Echoelmusic PRIVATE ${PULSE_LIBRARIES})
            target_include_directories(Echoelmusic PRIVATE ${PULSE_INCLUDE_DIRS})
            message(WARNING "PulseAudio is deprecated. Consider using PipeWire instead.")
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

endif() # End of USE_JUCE block

# ===========================
# Native Audio Engines (JUCE-Free)
# ===========================
# These are standalone audio engines that don't require JUCE
# Used for: Standalone apps, Swift bridge, non-plugin builds

option(BUILD_NATIVE_AUDIO "Build native audio engines (JUCE-free)" ON)

if(BUILD_NATIVE_AUDIO)
    message(STATUS "")
    message(STATUS "==============================================")
    message(STATUS "Echoelmusic Native Audio Engines")
    message(STATUS "==============================================")

    # Header-only library for native audio
    add_library(EchoelmusicNativeAudio INTERFACE)

    target_include_directories(EchoelmusicNativeAudio
        INTERFACE
            ${CMAKE_CURRENT_SOURCE_DIR}/Sources/DSP
            ${CMAKE_CURRENT_SOURCE_DIR}/Sources/Desktop/DSP
    )

    # Platform-specific configurations
    if(WIN32)
        message(STATUS "  Windows: WASAPI + ASIO Bridge")
        target_compile_definitions(EchoelmusicNativeAudio
            INTERFACE
                WIN32_LEAN_AND_MEAN
                NOMINMAX
                _UNICODE
                UNICODE
        )
        # Note: WindowsAudioEngine.hpp is header-only
        # Link requirements for consumers
        target_link_libraries(EchoelmusicNativeAudio
            INTERFACE
                ole32
                uuid
                crypt32
                credui
        )

        # Echoela Security Library (Windows)
        add_library(EchoelaSecurity STATIC
            Sources/DSP/EchoelaSecurity.cpp
            Sources/DSP/EchoelaSecurity.h
        )
        target_include_directories(EchoelaSecurity PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/Sources/DSP)
        target_link_libraries(EchoelaSecurity PRIVATE crypt32 credui webauthn)
        target_compile_definitions(EchoelaSecurity PRIVATE WIN32_LEAN_AND_MEAN NOMINMAX _UNICODE UNICODE)
        message(STATUS "  - Echoela Security: DPAPI + Credential Manager + Windows Hello")
    elseif(UNIX AND NOT APPLE AND NOT ANDROID)
        message(STATUS "  Linux: ALSA + PipeWire")

        find_package(PkgConfig)
        if(PkgConfig_FOUND)
            # ALSA
            pkg_check_modules(ALSA alsa)
            if(ALSA_FOUND)
                target_include_directories(EchoelmusicNativeAudio INTERFACE ${ALSA_INCLUDE_DIRS})
                target_link_libraries(EchoelmusicNativeAudio INTERFACE ${ALSA_LIBRARIES})
                target_compile_definitions(EchoelmusicNativeAudio INTERFACE ECHOELMUSIC_ALSA=1)
                message(STATUS "    - ALSA: Found")
            endif()

            # PipeWire
            pkg_check_modules(PIPEWIRE libpipewire-0.3)
            if(PIPEWIRE_FOUND)
                target_include_directories(EchoelmusicNativeAudio INTERFACE ${PIPEWIRE_INCLUDE_DIRS})
                target_link_libraries(EchoelmusicNativeAudio INTERFACE ${PIPEWIRE_LIBRARIES})
                target_compile_definitions(EchoelmusicNativeAudio INTERFACE ECHOELMUSIC_PIPEWIRE=1)
                message(STATUS "    - PipeWire: Found")
            endif()

            # OpenSSL for encryption
            find_package(OpenSSL)
            if(OPENSSL_FOUND)
                message(STATUS "    - OpenSSL: Found")
            endif()
        endif()

        target_link_libraries(EchoelmusicNativeAudio INTERFACE pthread)

        # Echoela Security Library (Linux)
        add_library(EchoelaSecurity STATIC
            Sources/DSP/EchoelaSecurity.cpp
            Sources/DSP/EchoelaSecurity.h
        )
        target_include_directories(EchoelaSecurity PUBLIC ${CMAKE_CURRENT_SOURCE_DIR}/Sources/DSP)
        target_link_libraries(EchoelaSecurity PRIVATE pthread OpenSSL::SSL OpenSSL::Crypto)
        message(STATUS "  - Echoela Security: OpenSSL AES-256-GCM + Secure File Storage")
    endif()

    message(STATUS "==============================================")
    message(STATUS "")
endif()

# ===========================
# WebAssembly Build (Emscripten)
# ===========================

if(EMSCRIPTEN)
    message(STATUS "")
    message(STATUS "==============================================")
    message(STATUS "Echoelmusic WebAssembly Build")
    message(STATUS "==============================================")

    add_executable(echoelcore_wasm
        Sources/Desktop/DSP/EchoelmusicDSP.h
    )

    # Emscripten settings for audio
    set_target_properties(echoelcore_wasm PROPERTIES
        SUFFIX ".js"
        LINK_FLAGS "-s WASM=1 -s EXPORTED_RUNTIME_METHODS=['ccall','cwrap'] -s ALLOW_MEMORY_GROWTH=1 -s AUDIO_WORKLET=1"
    )

    target_compile_definitions(echoelcore_wasm PRIVATE
        ECHOELMUSIC_WASM=1
    )

    message(STATUS "  Target: echoelcore_wasm.js + echoelcore_wasm.wasm")
    message(STATUS "  Build with: emcmake cmake .. && emmake make")
    message(STATUS "==============================================")
endif()

# ===========================
# Summary for Non-JUCE builds
# ===========================

if(NOT USE_JUCE)
    # Non-JUCE build (Swift-only for iOS/macOS)
    message(STATUS "")
    message(STATUS "==============================================")
    message(STATUS "Echoelmusic - Swift-Only Build Mode")
    message(STATUS "==============================================")
    message(STATUS "")
    message(STATUS "JUCE Framework: DISABLED")
    message(STATUS "")
    message(STATUS "This configuration is for iOS/macOS Swift builds")
    message(STATUS "that use native Apple frameworks:")
    message(STATUS "  - AVFoundation (Audio/Video)")
    message(STATUS "  - Accelerate (DSP/SIMD)")
    message(STATUS "  - CoreML (AI/ML)")
    message(STATUS "  - HealthKit (Biometrics)")
    message(STATUS "  - Metal (GPU Shaders)")
    message(STATUS "")
    message(STATUS "To build Swift targets:")
    message(STATUS "  swift build")
    message(STATUS "  swift test")
    message(STATUS "")
    message(STATUS "To enable desktop plugin builds:")
    message(STATUS "  cmake .. -DUSE_JUCE=ON")
    message(STATUS "  (Requires JUCE in ThirdParty/JUCE)")
    message(STATUS "")
    message(STATUS "Or use iPlug2 (MIT license - FREE):")
    message(STATUS "  cmake .. -DUSE_IPLUG2=ON")
    message(STATUS "  (Requires iPlug2 in ThirdParty/iPlug2)")
    message(STATUS "")
    message(STATUS "==============================================")
endif()
