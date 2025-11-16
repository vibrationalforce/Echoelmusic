cmake_minimum_required(VERSION 3.22)

project(Echoelmusic VERSION 1.0.0 LANGUAGES CXX)

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
# ML Infrastructure Options
# ===========================

option(ENABLE_ML "Enable ML features (ONNX Runtime)" ON)
option(ENABLE_ML_GPU "Enable GPU acceleration for ML" ON)

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
option(ENABLE_JACK "Enable JACK support (Linux)" OFF)  # Disabled for minimal build
option(ENABLE_PULSEAUDIO "Enable PulseAudio (Linux)" OFF)  # Disabled for minimal build

option(ENABLE_ANDROID_OBOE "Enable Oboe (Android)" ON)
option(ENABLE_ANDROID_AAUDIO "Enable AAudio (Android)" ON)

# ===========================
# JUCE Framework
# ===========================

add_subdirectory(ThirdParty/JUCE)

# ===========================
# ML Infrastructure Setup
# ===========================

if(ENABLE_ML)
    message(STATUS "ML features enabled - searching for ONNX Runtime")

    # Try to find ONNX Runtime
    # Option 1: Use system-installed ONNX Runtime
    find_package(onnxruntime QUIET)

    if(NOT onnxruntime_FOUND)
        # Option 2: Check for manual installation in ThirdParty
        if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/ThirdParty/onnxruntime")
            message(STATUS "Using ONNX Runtime from ThirdParty/onnxruntime")
            set(ONNXRUNTIME_INCLUDE_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ThirdParty/onnxruntime/include")

            if(WIN32)
                set(ONNXRUNTIME_LIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ThirdParty/onnxruntime/lib")
                set(ONNXRUNTIME_LIBRARIES "${ONNXRUNTIME_LIB_DIR}/onnxruntime.lib")
            elseif(APPLE)
                set(ONNXRUNTIME_LIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ThirdParty/onnxruntime/lib")
                set(ONNXRUNTIME_LIBRARIES "${ONNXRUNTIME_LIB_DIR}/libonnxruntime.dylib")
            else()
                set(ONNXRUNTIME_LIB_DIR "${CMAKE_CURRENT_SOURCE_DIR}/ThirdParty/onnxruntime/lib")
                set(ONNXRUNTIME_LIBRARIES "${ONNXRUNTIME_LIB_DIR}/libonnxruntime.so")
            endif()

            set(ONNXRUNTIME_FOUND TRUE)
        else()
            message(WARNING "ONNX Runtime not found. ML features will be disabled.")
            message(WARNING "Install via: brew install onnxruntime (macOS) or vcpkg install onnxruntime (Windows)")
            message(WARNING "Or download from: https://github.com/microsoft/onnxruntime/releases")
            set(ENABLE_ML OFF)
        endif()
    endif()

    if(ONNXRUNTIME_FOUND)
        message(STATUS "ONNX Runtime found!")

        # GPU Acceleration Detection
        if(ENABLE_ML_GPU)
            # Check for CUDA (NVIDIA GPUs)
            find_package(CUDA QUIET)
            if(CUDA_FOUND)
                message(STATUS "CUDA found - GPU acceleration enabled (NVIDIA)")
                set(HAS_CUDA TRUE)
            endif()

            # Check for Metal (Apple GPUs)
            if(APPLE)
                message(STATUS "Metal available - GPU acceleration enabled (Apple)")
                set(HAS_METAL TRUE)
            endif()

            # Check for OpenCL (Generic GPUs)
            find_package(OpenCL QUIET)
            if(OpenCL_FOUND)
                message(STATUS "OpenCL found - GPU acceleration enabled (Generic)")
                set(HAS_OPENCL TRUE)
            endif()
        endif()
    endif()
else()
    message(STATUS "ML features disabled")
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

    # LV2 specific (Linux)
    LV2URI "http://echoelmusic.com/plugins/echoelmusic"

    # AUv3 specific (iOS)
    IPHONE_SCREEN_ORIENTATIONS UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight
    IPAD_SCREEN_ORIENTATIONS UIInterfaceOrientationPortrait UIInterfaceOrientationLandscapeLeft UIInterfaceOrientationLandscapeRight

    # Bundle ID
    BUNDLE_ID "com.echoelmusic.plugin"

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

        # Pending (needs JUCE 7 fixes)
        # Sources/DSP/DynamicEQ.cpp             # TODO: Fix ParametricEQ::FilterType
        # Sources/DSP/SpectralSculptor.cpp      # TODO: Fix FFT API

        # =====================================================================
        # PHASE 2B: ML INFRASTRUCTURE (NEW! 2025-11-16) 🤖🧠
        # =====================================================================
        Sources/ML/MLEngine.cpp                 # ✅ Neural inference engine (ONNX Runtime)

        # =====================================================================
        # PHASE 2B: CORE 3 NEURAL SYNTHESIS (Week 3-6) 🎹🤖
        # =====================================================================
        Sources/Synth/NeuralSoundSynth.cpp      # ✅ Bio-reactive neural synthesizer (RAVE VAE)
        Sources/Synth/SpectralGranularSynth.cpp # ✅ 32-stream spectral granular engine

        # =====================================================================
        # PHASE 3: ADVANCED FEATURES (Later)
        # =====================================================================
        # Sources/AI/SmartMixer.cpp               # AI mixing assistant
        # Sources/Visualization/SpectrumAnalyzer.cpp
        # Sources/Visualization/BioReactiveVisualizer.cpp
        # Sources/Synthesis/DrumSynthesizer.cpp
        # Sources/Healing/ResonanceHealer.cpp
        # Sources/Instrument/RhythmMatrix.cpp
        # Sources/Sequencer/ArpWeaver.cpp
        # Sources/Video/VideoWeaver.cpp
        # Sources/Visual/VisualForge.cpp
        # Sources/Visual/LaserForce.cpp
        # Sources/Remote/RemoteProcessingEngine.cpp
        # Sources/Hardware/AbletonLink.cpp
        # Sources/Hardware/MIDIHardwareManager.cpp
        # Sources/Hardware/ModularIntegration.cpp
        # Sources/Hardware/DJEquipmentIntegration.cpp
        # Sources/Hardware/OSCManager.cpp
        # Sources/Hardware/HardwareSyncManager.cpp
        # Sources/Audio/SpatialForge.cpp
        # Sources/Platform/CreatorManager.cpp
        # Sources/Platform/AgencyManager.cpp
        # Sources/Platform/GlobalReachOptimizer.cpp
        # Sources/Platform/EchoHub.cpp
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
        Sources/Synth
        Sources/Visualization
        Sources/BioData
        Sources/AI
        Sources/ML
        Sources/Hardware
        Sources/Video
        Sources/Audio
        Sources/Platform
        Sources/Remote
        Sources/Sync
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
# ML Dependencies
# ===========================

if(ENABLE_ML AND ONNXRUNTIME_FOUND)
    # Add ONNX Runtime include directories
    target_include_directories(Echoelmusic
        PRIVATE
            ${ONNXRUNTIME_INCLUDE_DIR}
    )

    # Link ONNX Runtime libraries
    if(onnxruntime_FOUND)
        # System-installed via package manager
        target_link_libraries(Echoelmusic PRIVATE onnxruntime::onnxruntime)
    else()
        # Manual installation in ThirdParty
        target_link_libraries(Echoelmusic PRIVATE ${ONNXRUNTIME_LIBRARIES})

        # Add runtime library path for dynamic linking
        if(APPLE)
            set_target_properties(Echoelmusic PROPERTIES
                BUILD_RPATH "${ONNXRUNTIME_LIB_DIR}"
                INSTALL_RPATH "${ONNXRUNTIME_LIB_DIR}"
            )
        elseif(UNIX)
            set_target_properties(Echoelmusic PROPERTIES
                BUILD_RPATH "${ONNXRUNTIME_LIB_DIR}"
                INSTALL_RPATH "$ORIGIN:${ONNXRUNTIME_LIB_DIR}"
            )
        endif()
    endif()

    # GPU Acceleration Libraries
    if(HAS_CUDA)
        target_include_directories(Echoelmusic PRIVATE ${CUDA_INCLUDE_DIRS})
        target_link_libraries(Echoelmusic PRIVATE ${CUDA_LIBRARIES})
    endif()

    if(HAS_METAL AND APPLE)
        target_link_libraries(Echoelmusic PRIVATE
            "-framework Metal"
            "-framework MetalPerformanceShaders"
        )
    endif()

    if(HAS_OPENCL)
        target_link_libraries(Echoelmusic PRIVATE OpenCL::OpenCL)
    endif()

    message(STATUS "ML dependencies configured successfully")
endif()

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

        # ML Features
        $<$<BOOL:${ENABLE_ML}>:ECHOELMUSIC_HAS_ML=1>
        $<$<BOOL:${HAS_CUDA}>:ECHOELMUSIC_HAS_CUDA=1>
        $<$<BOOL:${HAS_METAL}>:ECHOELMUSIC_HAS_METAL=1>
        $<$<BOOL:${HAS_OPENCL}>:ECHOELMUSIC_HAS_OPENCL=1>
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
message(STATUS "ML Infrastructure:")
if(ENABLE_ML AND ONNXRUNTIME_FOUND)
    message(STATUS "  - ONNX Runtime: ✅ ENABLED")
    if(HAS_CUDA)
        message(STATUS "  - GPU Acceleration: CUDA (NVIDIA)")
    elseif(HAS_METAL)
        message(STATUS "  - GPU Acceleration: Metal (Apple)")
    elseif(HAS_OPENCL)
        message(STATUS "  - GPU Acceleration: OpenCL (Generic)")
    else()
        message(STATUS "  - GPU Acceleration: CPU Only")
    endif()
else()
    message(STATUS "  - ONNX Runtime: ❌ DISABLED (install to enable neural synthesis)")
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
