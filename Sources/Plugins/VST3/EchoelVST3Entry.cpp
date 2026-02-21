/*
 *  EchoelVST3Entry.cpp
 *  Echoelmusic — VST3 Plugin Entry Point
 *
 *  Created: February 2026
 *  Steinberg VST3 SDK wrapper for Echoelmusic plugin suite.
 *
 *  Architecture:
 *    VST3 Host (Cubase, Ableton, Logic, FL Studio, Studio One, ...)
 *        │
 *    IComponent / IAudioProcessor / IEditController
 *        │
 *    EchoelPluginCore.h (C ABI)
 *        │
 *    Echoelmusic DSP Engine
 *
 *  Build: C++17, requires Steinberg VST3 SDK (GPLv3 or commercial license)
 *  When building without VST3 SDK, this file provides the factory skeleton
 *  that compiles against EchoelPluginCore.h standalone.
 */

#include "../PluginCore/EchoelPluginCore.h"

#include <cstring>
#include <cstdint>
#include <cmath>
#include <string>
#include <vector>

/* ═══════════════════════════════════════════════════════════════════════════ */
/* VST3 Type Definitions (minimal — real build uses VST3 SDK headers)         */
/* ═══════════════════════════════════════════════════════════════════════════ */

#ifndef __VST3_SDK__

typedef int32_t  tresult;
typedef uint32_t uint32;
typedef int32_t  int32;
typedef char16_t tchar;
typedef uint8_t  TUID[16];

enum { kResultOk = 0, kResultFalse = 1, kInvalidArgument = 4, kNotImplemented = 5 };
enum { kVstAudioEffectClass = 0 };

#endif /* __VST3_SDK__ */

/* ═══════════════════════════════════════════════════════════════════════════ */
/* VST3 ↔ EchoelPluginCore Bridge                                            */
/* ═══════════════════════════════════════════════════════════════════════════ */

namespace Echoelmusic {
namespace VST3 {

/*
 * VST3 Plugin Registration Table
 *
 * Each Echoel engine maps to a VST3 class with:
 *   - Unique CID (Component ID / TUID)
 *   - Category (Instrument / Fx / etc.)
 *   - Subcategories string
 *
 * VST3 categories (Steinberg spec):
 *   Fx        — Audio Effect
 *   Instrument — Virtual Instrument
 *   Analyzer  — Analysis
 *   Spatial   — Spatial / Surround
 *   Tools     — Tools
 */

struct VST3PluginInfo {
    EchoelEngineID  engine;
    const char*     name;
    const char*     category;       // "Audio Module Class" or "Component"
    const char*     subcategories;  // pipe-separated VST3 subcategories
    uint8_t         cid[16];        // Component ID (TUID)
    uint8_t         eid[16];        // Edit Controller ID
};

// Each plugin gets a unique 16-byte CID derived from its engine ID
#define ECHOEL_CID(a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p) {a,b,c,d,e,f,g,h,i,j,k,l,m,n,o,p}

static const VST3PluginInfo s_vst3Plugins[] = {
    {ECHOEL_ENGINE_SYNTH, "EchoelSynth", "Audio Module Class",
     "Instrument|Synth",
     ECHOEL_CID(0x5B,0x8E,0x1A,0x2C,0x3D,0x4F,0x5A,0x6B,0x7C,0x8D,0x9E,0x0F,0x1A,0x2B,0x3C,0x4D),
     ECHOEL_CID(0x5B,0x8E,0x1A,0x2C,0x3D,0x4F,0x5A,0x6B,0x7C,0x8D,0x9E,0x0F,0x1A,0x2B,0x3C,0x4E)},

    {ECHOEL_ENGINE_FX, "EchoelFX", "Audio Module Class",
     "Fx|Reverb|Delay|Dynamics",
     ECHOEL_CID(0x6C,0x9F,0x2B,0x3D,0x4E,0x5F,0x6A,0x7B,0x8C,0x9D,0x0E,0x1F,0x2A,0x3B,0x4C,0x5D),
     ECHOEL_CID(0x6C,0x9F,0x2B,0x3D,0x4E,0x5F,0x6A,0x7B,0x8C,0x9D,0x0E,0x1F,0x2A,0x3B,0x4C,0x5E)},

    {ECHOEL_ENGINE_MIX, "EchoelMix", "Audio Module Class",
     "Fx|Mixing|Spatial|Surround",
     ECHOEL_CID(0x7D,0x0A,0x3C,0x4E,0x5F,0x6A,0x7B,0x8C,0x9D,0x0E,0x1F,0x2A,0x3B,0x4C,0x5D,0x6E),
     ECHOEL_CID(0x7D,0x0A,0x3C,0x4E,0x5F,0x6A,0x7B,0x8C,0x9D,0x0E,0x1F,0x2A,0x3B,0x4C,0x5D,0x6F)},

    {ECHOEL_ENGINE_BASS, "EchoelBass", "Audio Module Class",
     "Instrument|Synth",
     ECHOEL_CID(0xF5,0x8C,0x1E,0x2A,0x3B,0x4C,0x5D,0x6E,0x7F,0x80,0x91,0x02,0x13,0x24,0x35,0x46),
     ECHOEL_CID(0xF5,0x8C,0x1E,0x2A,0x3B,0x4C,0x5D,0x6E,0x7F,0x80,0x91,0x02,0x13,0x24,0x35,0x47)},

    {ECHOEL_ENGINE_BEAT, "EchoelBeat", "Audio Module Class",
     "Instrument|Drum",
     ECHOEL_CID(0x06,0x9D,0x2F,0x3B,0x4C,0x5D,0x6E,0x7F,0x80,0x91,0x02,0x13,0x24,0x35,0x46,0x57),
     ECHOEL_CID(0x06,0x9D,0x2F,0x3B,0x4C,0x5D,0x6E,0x7F,0x80,0x91,0x02,0x13,0x24,0x35,0x46,0x58)},

    {ECHOEL_ENGINE_MIND, "EchoelMind", "Audio Module Class",
     "Fx|Restoration",
     ECHOEL_CID(0xE4,0x7B,0x0D,0x1F,0x2A,0x3B,0x4C,0x5D,0x6E,0x7F,0x80,0x91,0x02,0x13,0x24,0x35),
     ECHOEL_CID(0xE4,0x7B,0x0D,0x1F,0x2A,0x3B,0x4C,0x5D,0x6E,0x7F,0x80,0x91,0x02,0x13,0x24,0x36)},

    {ECHOEL_ENGINE_BIO, "EchoelBio", "Audio Module Class",
     "Instrument|Synth|Generator",
     ECHOEL_CID(0xA0,0x3D,0x6F,0x7B,0x8C,0x9D,0x0E,0x1F,0x2A,0x3B,0x4C,0x5D,0x6E,0x7F,0x80,0x91),
     ECHOEL_CID(0xA0,0x3D,0x6F,0x7B,0x8C,0x9D,0x0E,0x1F,0x2A,0x3B,0x4C,0x5D,0x6E,0x7F,0x80,0x92)},

    {ECHOEL_ENGINE_SEQ, "EchoelSeq", "Audio Module Class",
     "Instrument|Sequencer",
     ECHOEL_CID(0x8E,0x1B,0x4D,0x5F,0x6A,0x7B,0x8C,0x9D,0x0E,0x1F,0x2A,0x3B,0x4C,0x5D,0x6E,0x7F),
     ECHOEL_CID(0x8E,0x1B,0x4D,0x5F,0x6A,0x7B,0x8C,0x9D,0x0E,0x1F,0x2A,0x3B,0x4C,0x5D,0x6E,0x80)},

    {ECHOEL_ENGINE_FIELD, "EchoelField", "Audio Module Class",
     "Fx|Analyzer|Visualization",
     ECHOEL_CID(0xB1,0x4E,0x7A,0x8C,0x9D,0x0E,0x1F,0x2A,0x3B,0x4C,0x5D,0x6E,0x7F,0x80,0x91,0x02),
     ECHOEL_CID(0xB1,0x4E,0x7A,0x8C,0x9D,0x0E,0x1F,0x2A,0x3B,0x4C,0x5D,0x6E,0x7F,0x80,0x91,0x03)},
};

static const uint32_t s_vst3PluginCount = sizeof(s_vst3Plugins) / sizeof(s_vst3Plugins[0]);

/*
 * EchoelVST3Processor — IComponent + IAudioProcessor implementation
 *
 * Real VST3 SDK build would inherit from:
 *   Steinberg::Vst::SingleComponentEffect
 *
 * This skeleton provides the interface mapping.
 */
class EchoelVST3Processor {
public:
    EchoelVST3Processor(EchoelEngineID engine)
        : m_engine(engine)
        , m_core(echoel_create(engine))
    {}

    ~EchoelVST3Processor() {
        if (m_core) echoel_destroy(m_core);
    }

    // IComponent
    bool initialize() { return m_core != nullptr; }
    void terminate() { if (m_core) { echoel_destroy(m_core); m_core = nullptr; } }

    // IAudioProcessor
    bool setupProcessing(double sampleRate, int32 maxBlockSize) {
        return m_core && echoel_activate(m_core, sampleRate, static_cast<uint32_t>(maxBlockSize));
    }

    void setProcessing(bool active) {
        if (!active && m_core) echoel_deactivate(m_core);
    }

    void process(float** inputs, float** outputs, int32 numChannels, int32 numSamples) {
        if (!m_core) return;
        EchoelAudioBuffer inBuf = {inputs, static_cast<uint32_t>(numChannels), static_cast<uint32_t>(numSamples)};
        EchoelAudioBuffer outBuf = {outputs, static_cast<uint32_t>(numChannels), static_cast<uint32_t>(numSamples)};
        echoel_process(m_core, &inBuf, &outBuf, nullptr, nullptr, nullptr);
    }

    // IEditController
    int32 getParameterCount() const {
        return m_core ? static_cast<int32>(echoel_get_parameter_count(m_core)) : 0;
    }

    double getParameter(uint32_t id) const {
        return m_core ? echoel_get_parameter(m_core, id) : 0.0;
    }

    void setParameter(uint32_t id, double value) {
        if (m_core) echoel_set_parameter(m_core, id, value);
    }

    // State
    bool getState(const uint8_t** data, uint32_t* size) {
        return m_core && echoel_get_state(m_core, data, size);
    }

    bool setState(const uint8_t* data, uint32_t size) {
        return m_core && echoel_set_state(m_core, data, size);
    }

    EchoelPluginRef getCore() const { return m_core; }

private:
    EchoelEngineID m_engine;
    EchoelPluginRef m_core;
};

} // namespace VST3
} // namespace Echoelmusic

/* ═══════════════════════════════════════════════════════════════════════════ */
/* VST3 Module Entry Points (exported symbols)                                */
/*                                                                            */
/* Real builds link against vstsdk — these are the standard entry functions:  */
/*   InitModule()       — called when DLL loads                               */
/*   DeinitModule()     — called when DLL unloads                             */
/*   GetPluginFactory() — returns IPluginFactory with class registrations      */
/* ═══════════════════════════════════════════════════════════════════════════ */

#ifdef __cplusplus
extern "C" {
#endif

ECHOEL_EXPORT bool InitModule() {
    return true;
}

ECHOEL_EXPORT bool DeinitModule() {
    return true;
}

/*
 * GetPluginFactory — VST3 host calls this to discover available plugins.
 *
 * In a full VST3 SDK build, this returns an IPluginFactory3* that registers
 * each Echoel engine as a separate AudioEffect class.
 *
 * For now, this returns the plugin count for validation.
 */
ECHOEL_EXPORT void* GetPluginFactory() {
    // Full implementation requires linking against Steinberg VST3 SDK.
    // The EchoelVST3Processor class above provides the complete processing
    // bridge — just needs the IPluginFactory wrapper from the SDK.
    //
    // Build command (with SDK):
    //   cmake -DBUILD_VST3=ON -DVST3_SDK_ROOT=/path/to/vst3sdk ..
    return nullptr;
}

#ifdef __cplusplus
}
#endif
