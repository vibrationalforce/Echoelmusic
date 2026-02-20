/*
 *  EchoelAAXEntry.cpp
 *  Echoelmusic — AAX Plugin Entry Point (Pro Tools)
 *
 *  Created: February 2026
 *  Avid AAX SDK wrapper for Pro Tools integration.
 *
 *  Architecture:
 *    Pro Tools Host
 *        │
 *    AAX_CEffectParameters / AAX_CEffectGUI
 *        │
 *    EchoelPluginCore.h (C ABI)
 *        │
 *    Echoelmusic DSP Engine
 *
 *  Build: C++17, requires Avid AAX SDK (NDA + commercial license)
 *  Build flag: -DBUILD_AAX=ON -DAAX_SDK_ROOT=/path/to/aax-sdk
 */

#include "../PluginCore/EchoelPluginCore.h"

#include <cstring>
#include <string>

/* ═══════════════════════════════════════════════════════════════════════════ */
/* AAX Plugin Registration                                                    */
/* ═══════════════════════════════════════════════════════════════════════════ */

namespace Echoelmusic {
namespace AAX {

/*
 * AAX Plugin Table
 *
 * AAX categories (Pro Tools):
 *   AAX_ePlugInCategory_SWGenerators     — Software Instruments
 *   AAX_ePlugInCategory_EQ               — EQ
 *   AAX_ePlugInCategory_Dynamics         — Compressor/Limiter
 *   AAX_ePlugInCategory_Reverb           — Reverb
 *   AAX_ePlugInCategory_Delay            — Delay
 *   AAX_ePlugInCategory_Modulation       — Modulation
 *   AAX_ePlugInCategory_Effect           — General Effect
 *   AAX_ePlugInCategory_NoiseReduction   — Noise Reduction
 *   AAX_ePlugInCategory_SurroundSound    — Surround/Spatial
 */

struct AAXPluginInfo {
    EchoelEngineID engine;
    const char*    name;
    uint32_t       typeID;      // 4-char type code
    uint32_t       category;    // AAX category bitmask
    bool           isInstrument;
};

static const AAXPluginInfo s_aaxPlugins[] = {
    {ECHOEL_ENGINE_SYNTH, "EchoelSynth",  0x45730001, 0x00000001, true},    // SWGenerators
    {ECHOEL_ENGINE_FX,    "EchoelFX",     0x45660001, 0x00000800, false},   // Effect
    {ECHOEL_ENGINE_MIX,   "EchoelMix",    0x456D0001, 0x00000200, false},   // Dynamics
    {ECHOEL_ENGINE_MIND,  "EchoelMind",   0x456D0003, 0x00002000, false},   // NoiseReduction
    {ECHOEL_ENGINE_BASS,  "EchoelBass",   0x45380001, 0x00000001, true},    // SWGenerators
    {ECHOEL_ENGINE_BEAT,  "EchoelBeat",   0x45620003, 0x00000001, true},    // SWGenerators
    {ECHOEL_ENGINE_BIO,   "EchoelBio",    0x45620001, 0x00000001, true},    // SWGenerators
};

static const uint32_t s_aaxPluginCount = sizeof(s_aaxPlugins) / sizeof(s_aaxPlugins[0]);

/*
 * EchoelAAXProcessor
 *
 * In full AAX SDK build, this inherits from AAX_CEffectParameters.
 * Provides the complete bridge from AAX callback model to EchoelPluginCore.
 */
class EchoelAAXProcessor {
public:
    EchoelAAXProcessor(EchoelEngineID engine)
        : m_engine(engine)
        , m_core(echoel_create(engine))
    {}

    ~EchoelAAXProcessor() {
        if (m_core) echoel_destroy(m_core);
    }

    // AAX_CEffectParameters overrides
    bool initialize(double sampleRate, int32_t maxBlockSize) {
        return m_core && echoel_activate(m_core, sampleRate, static_cast<uint32_t>(maxBlockSize));
    }

    void renderAudio(float** inputs, float** outputs, int32_t numChannels, int32_t numSamples) {
        if (!m_core) return;
        EchoelAudioBuffer inBuf = {inputs, static_cast<uint32_t>(numChannels), static_cast<uint32_t>(numSamples)};
        EchoelAudioBuffer outBuf = {outputs, static_cast<uint32_t>(numChannels), static_cast<uint32_t>(numSamples)};
        echoel_process(m_core, &inBuf, &outBuf, nullptr, nullptr, nullptr);
    }

    int32_t getLatency() const { return m_core ? static_cast<int32_t>(echoel_get_latency(m_core)) : 0; }

    EchoelPluginRef getCore() const { return m_core; }

private:
    EchoelEngineID m_engine;
    EchoelPluginRef m_core;
};

} // namespace AAX
} // namespace Echoelmusic

/* ═══════════════════════════════════════════════════════════════════════════ */
/* AAX Entry Point                                                            */
/*                                                                            */
/* Full build with AAX SDK provides:                                          */
/*   AAX_EXPORT int AAXEntryPoint(...)                                        */
/*   Description callback for Pro Tools plugin scanner                        */
/* ═══════════════════════════════════════════════════════════════════════════ */

#ifdef __cplusplus
extern "C" {
#endif

ECHOEL_EXPORT int EchoelAAXGetPluginCount() {
    return static_cast<int>(Echoelmusic::AAX::s_aaxPluginCount);
}

ECHOEL_EXPORT const char* EchoelAAXGetPluginName(int index) {
    if (index < 0 || index >= static_cast<int>(Echoelmusic::AAX::s_aaxPluginCount)) return "";
    return Echoelmusic::AAX::s_aaxPlugins[index].name;
}

#ifdef __cplusplus
}
#endif
