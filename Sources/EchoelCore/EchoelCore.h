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
#define ECHOELCORE_VERSION_MINOR 0
#define ECHOELCORE_VERSION_PATCH 0
#define ECHOELCORE_VERSION_STRING "1.0.0"

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
 */
