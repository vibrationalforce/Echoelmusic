#pragma once
/**
 * EchoelCore - Bio-Reactive Audio Framework
 *
 * A lightweight, lock-free audio plugin framework optimized for
 * bio-reactive music applications.
 *
 * Features:
 * - Lock-free communication (SPSC queues, atomics)
 * - Native bio-reactive parameter mapping
 * - CLAP-first plugin architecture
 * - Zero-allocation audio processing
 * - Header-only core
 *
 * Quick Start:
 *   #include <EchoelCore/EchoelCore.h>
 *
 *   class MySynth : public EchoelCore::CLAPPlugin {
 *       void processAudio(const float* const* in, float* const* out, uint32_t n) override {
 *           float filterMod = getModulatedParam(kFilterCutoff);
 *           // ... process audio
 *       }
 *   };
 *
 * MIT License - Echoelmusic 2026
 *
 * Sources & References:
 * - CLAP: https://github.com/free-audio/clap
 * - CLAP Tutorial: https://nakst.gitlab.io/tutorial/clap-part-1.html
 * - Lock-free queues: https://github.com/cameron314/readerwriterqueue
 * - Real-time audio: http://www.rossbencina.com/code/real-time-audio-programming-101-time-waits-for-nothing
 * - HRV Research: https://digitalcommons.dartmouth.edu/masters_theses/205/
 */

#define ECHOELCORE_VERSION_MAJOR 1
#define ECHOELCORE_VERSION_MINOR 1
#define ECHOELCORE_VERSION_PATCH 0
#define ECHOELCORE_VERSION_STRING "1.1.0"

//==============================================================================
// Core Components
//==============================================================================

// Lock-Free Primitives
#include "Lock-Free/SPSCQueue.h"

// Bio-Reactive System
#include "Bio/BioState.h"
#include "Bio/BioMapping.h"

// CLAP Plugin Framework
#include "CLAP/CLAPTypes.h"
#include "CLAP/CLAPPlugin.h"

//==============================================================================
// Advanced Components (v1.1.0)
//==============================================================================

// MCP (Model Context Protocol) - AI Agent Integration
#include "MCP/MCPBioServer.h"

// WebXR/PWA - Browser & Immersive Audio
#include "WebXR/WebXRAudioBridge.h"

// Photonic Interconnect - Future Hardware Abstraction
#include "Photonic/PhotonicInterconnect.h"

// Lambda Loop - Central Orchestrator
#include "Lambda/LambdaLoop.h"

//==============================================================================
// Convenience Namespace
//==============================================================================

namespace EchoelCore {

/**
 * Framework information
 */
struct Version {
    static constexpr int major = ECHOELCORE_VERSION_MAJOR;
    static constexpr int minor = ECHOELCORE_VERSION_MINOR;
    static constexpr int patch = ECHOELCORE_VERSION_PATCH;
    static constexpr const char* string = ECHOELCORE_VERSION_STRING;
};

/**
 * Print framework info
 */
inline void printInfo() {
    // Note: Don't call this from audio thread!
    #ifndef NDEBUG
    // Only in debug builds
    #endif
}

} // namespace EchoelCore

//==============================================================================
// Quick Reference
//==============================================================================

/*
 * ECHOELCORE QUICK REFERENCE
 * ==========================
 *
 * Lock-Free Communication:
 * ------------------------
 *   SPSCQueue<T, Capacity>  - Single producer/consumer queue
 *   ParamQueue              - Pre-defined for parameter changes
 *   BioQueue                - Pre-defined for bio updates
 *   SpectrumQueue           - Pre-defined for visualization data
 *
 * Bio-Reactive State:
 * -------------------
 *   BioState                - Atomic bio state container
 *     .setHRV(float)        - Set HRV (sensor thread)
 *     .setCoherence(float)  - Set coherence (sensor thread)
 *     .setHeartRate(float)  - Set heart rate (sensor thread)
 *     .getHRV()             - Get HRV (audio thread)
 *     .getCoherence()       - Get coherence (audio thread)
 *     .getBreathLFO()       - Get breath as LFO (-1 to +1)
 *
 * Parameter Mapping:
 * ------------------
 *   BioMapping              - Single mapping definition
 *   BioMapper               - Maps bio state to parameters
 *     .addMapping(...)      - Add a bio→param mapping
 *     .computeModulatedValue(paramId, baseValue, bioState)
 *
 *   MapCurve                - Mapping curves
 *     Linear, Exponential, Logarithmic, SCurve, Sine,
 *     InverseLinear, Stepped, Threshold
 *
 *   BioSource               - Bio signal sources
 *     HRV, Coherence, HeartRate, BreathPhase, BreathLFO,
 *     GSR, Temperature, Arousal, Relaxation
 *
 * Plugin Base Class:
 * ------------------
 *   CLAPPlugin              - Base class for CLAP plugins
 *     .processAudio(...)    - Override for audio processing
 *     .processEvents()      - Override for event handling
 *     .getBioState()        - Access bio state
 *     .getModulatedParam()  - Get bio-modulated parameter
 *     .queueParamChange()   - Queue param change (UI thread)
 *     .updateBioState()     - Update bio (sensor thread)
 *
 * Preset Mappings:
 * ----------------
 *   Presets::loadMeditationMappings(mapper)
 *   Presets::loadEnergeticMappings(mapper)
 *   Presets::loadPerformanceMappings(mapper)
 *
 * Thread Safety Rules:
 * --------------------
 *   AUDIO THREAD (real-time):
 *     - Call get*() on BioState
 *     - Call computeModulatedValue() on BioMapper
 *     - Pop from SPSCQueue (consumer)
 *     - NO allocation, NO locks, NO I/O
 *
 *   SENSOR THREAD:
 *     - Call set*() on BioState
 *     - Call updateBioState() on plugin
 *     - Push to BioQueue (producer)
 *
 *   UI THREAD:
 *     - Call queueParamChange() on plugin
 *     - Push to ParamQueue (producer)
 *     - Pop from SpectrumQueue (consumer)
 *
 * Lambda Loop (v1.1.0):
 * ---------------------
 *   LambdaLoop              - Central orchestrator
 *     .initialize()         - Initialize all subsystems
 *     .start()              - Start the 60Hz control loop
 *     .tick()               - Process one loop iteration
 *     .addSubsystem(...)    - Register a subsystem
 *     .getBioState()        - Access shared bio state
 *     .getLambdaScore()     - Get unified coherence score (0-1)
 *     .getState()           - Get current lambda state
 *
 *   LambdaState             - State machine
 *     Dormant, Initializing, Calibrating, Active,
 *     Flowing, Transcendent, Degrading, Shutting_Down
 *
 * MCP Server (v1.1.0):
 * --------------------
 *   MCPBioServer            - AI agent integration via MCP
 *     .handleMessage(json)  - Process JSON-RPC message
 *     .registerResource()   - Add custom resource
 *     .registerTool()       - Add custom tool
 *
 *   Default Resources:
 *     echoelmusic://bio/state       - Full bio state
 *     echoelmusic://bio/hrv         - HRV value
 *     echoelmusic://bio/coherence   - Coherence score
 *     echoelmusic://bio/heartrate   - Heart rate BPM
 *     echoelmusic://bio/breathing   - Breath phase/rate
 *
 *   Default Tools:
 *     setBioHRV, setBioCoherence, setBioHeartRate,
 *     setBioBreathPhase, getBioState, simulateBioSession
 *
 * WebXR Bridge (v1.1.0):
 * ----------------------
 *   WebXRAudioBridge        - Spatial audio for WebXR/PWA
 *     .startSession(type)   - Start XR session
 *     .addSource(...)       - Add spatial audio source
 *     .updateListenerPose() - Update head position
 *     .processAudio(L,R,n)  - Render spatial audio
 *
 *   XRSessionType           - VR/AR/Inline modes
 *   SpatialAudioSource      - 3D positioned audio with bio modulation
 *
 * Photonic Interconnect (v1.1.0):
 * -------------------------------
 *   PhotonicInterconnect    - Future hardware abstraction
 *     .initialize()         - Detect available hardware
 *     .processBioAudio()    - Bio-modulated filtering
 *     .computeSpectrum()    - FFT for visualization
 *     .denseLayer()         - Neural network acceleration
 *
 *   PhotonicTensor<R,C>     - Matrix for optical computation
 *   ElectronicPPU           - Current CPU/GPU simulation
 *   (FutureL SiliconPhotonicPPU - Direct chip integration)
 */
