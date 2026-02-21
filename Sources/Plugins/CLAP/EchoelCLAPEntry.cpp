/*
 *  EchoelCLAPEntry.cpp
 *  Echoelmusic — CLAP Plugin Entry Point
 *
 *  Created: February 2026
 *  CLever Audio Plugin (MIT License) — the most modern, open plugin format.
 *  https://cleveraudio.org
 *
 *  Wraps EchoelPluginCore.h for CLAP 1.2+ hosts:
 *  Bitwig Studio, Reaper, MultitrackStudio, u-he, etc.
 *
 *  Build: C++17, link against EchoelPluginCore
 *  CLAP SDK: Header-only, vendored in ThirdParty/clap/
 */

#include "../PluginCore/EchoelPluginCore.h"

#include <cstring>
#include <cstdlib>
#include <vector>

/* ═══════════════════════════════════════════════════════════════════════════ */
/* CLAP Header Stubs (inline — avoids SDK dependency for initial build)       */
/* When building with real CLAP SDK, replace with: #include <clap/clap.h>     */
/* ═══════════════════════════════════════════════════════════════════════════ */

#ifndef CLAP_VERSION_MAJOR
#define CLAP_VERSION_MAJOR 1
#define CLAP_VERSION_MINOR 2
#define CLAP_VERSION_REVISION 2

typedef struct { uint32_t major, minor, revision; } clap_version_t;
#define CLAP_VERSION_INIT {CLAP_VERSION_MAJOR, CLAP_VERSION_MINOR, CLAP_VERSION_REVISION}

typedef struct clap_host clap_host_t;
typedef struct clap_plugin clap_plugin_t;

/* Plugin descriptor */
typedef struct {
    clap_version_t clap_version;
    const char* id;
    const char* name;
    const char* vendor;
    const char* url;
    const char* manual_url;
    const char* support_url;
    const char* version;
    const char* description;
    const char* const* features;
} clap_plugin_descriptor_t;

/* Process status */
enum { CLAP_PROCESS_ERROR = 0, CLAP_PROCESS_CONTINUE = 1, CLAP_PROCESS_SLEEP = 2 };

/* Audio buffer */
typedef struct {
    float** data32;
    double** data64;
    uint32_t channel_count;
    uint32_t latency;
    uint64_t constant_mask;
} clap_audio_buffer_t;

/* Process context */
typedef struct {
    uint64_t steady_time;
    float frames_count;
    const void* transport;
    const clap_audio_buffer_t* audio_inputs;
    clap_audio_buffer_t* audio_outputs;
    uint32_t audio_inputs_count;
    uint32_t audio_outputs_count;
    const void* in_events;
    const void* out_events;
} clap_process_t;

/* Plugin struct */
struct clap_plugin {
    const clap_plugin_descriptor_t* desc;
    void* plugin_data;

    bool (*init)(const clap_plugin_t* plugin);
    void (*destroy)(const clap_plugin_t* plugin);
    bool (*activate)(const clap_plugin_t* plugin, double sr, uint32_t minFrames, uint32_t maxFrames);
    void (*deactivate)(const clap_plugin_t* plugin);
    bool (*start_processing)(const clap_plugin_t* plugin);
    void (*stop_processing)(const clap_plugin_t* plugin);
    void (*reset)(const clap_plugin_t* plugin);
    int32_t (*process)(const clap_plugin_t* plugin, const clap_process_t* process);
    const void* (*get_extension)(const clap_plugin_t* plugin, const char* id);
    void (*on_main_thread)(const clap_plugin_t* plugin);
};

/* Factory */
typedef struct {
    bool (*get_plugin_count)(const void* factory);
    const clap_plugin_descriptor_t* (*get_plugin_descriptor)(const void* factory, uint32_t index);
    const clap_plugin_t* (*create_plugin)(const void* factory, const clap_host_t* host, const char* plugin_id);
} clap_plugin_factory_t;

/* Entry */
typedef struct {
    clap_version_t clap_version;
    bool (*init)(const char* plugin_path);
    void (*deinit)(void);
    const void* (*get_factory)(const char* factory_id);
} clap_plugin_entry_t;

#define CLAP_PLUGIN_FACTORY_ID "clap.plugin-factory"

/* Feature constants */
#define CLAP_PLUGIN_FEATURE_INSTRUMENT   "instrument"
#define CLAP_PLUGIN_FEATURE_AUDIO_EFFECT "audio-effect"
#define CLAP_PLUGIN_FEATURE_NOTE_EFFECT  "note-effect"
#define CLAP_PLUGIN_FEATURE_ANALYZER     "analyzer"
#define CLAP_PLUGIN_FEATURE_SYNTHESIZER  "synthesizer"
#define CLAP_PLUGIN_FEATURE_MIXING       "mixing"
#define CLAP_PLUGIN_FEATURE_DRUM_MACHINE "drum-machine"

#endif /* CLAP_VERSION_MAJOR */

/* ═══════════════════════════════════════════════════════════════════════════ */
/* CLAP ↔ EchoelPluginCore Bridge                                             */
/* ═══════════════════════════════════════════════════════════════════════════ */

namespace {

struct ClapPluginData {
    EchoelPluginRef core;
    EchoelEngineID engineID;
};

/* ─── Plugin Callbacks ─── */

bool clap_init(const clap_plugin_t* plugin) {
    (void)plugin;
    return true;
}

void clap_destroy(const clap_plugin_t* plugin) {
    auto* data = static_cast<ClapPluginData*>(plugin->plugin_data);
    if (data) {
        if (data->core) echoel_destroy(data->core);
        delete data;
    }
    delete plugin;
}

bool clap_activate(const clap_plugin_t* plugin, double sr, uint32_t, uint32_t maxFrames) {
    auto* data = static_cast<ClapPluginData*>(plugin->plugin_data);
    return data && data->core && echoel_activate(data->core, sr, maxFrames);
}

void clap_deactivate_cb(const clap_plugin_t* plugin) {
    auto* data = static_cast<ClapPluginData*>(plugin->plugin_data);
    if (data && data->core) echoel_deactivate(data->core);
}

bool clap_start_processing(const clap_plugin_t*) { return true; }
void clap_stop_processing(const clap_plugin_t*) { }

void clap_reset_cb(const clap_plugin_t* plugin) {
    auto* data = static_cast<ClapPluginData*>(plugin->plugin_data);
    if (data && data->core) echoel_reset(data->core);
}

int32_t clap_process_cb(const clap_plugin_t* plugin, const clap_process_t* proc) {
    auto* data = static_cast<ClapPluginData*>(plugin->plugin_data);
    if (!data || !data->core || !proc) return CLAP_PROCESS_ERROR;

    uint32_t frames = static_cast<uint32_t>(proc->frames_count);

    // Map CLAP audio buffers → EchoelAudioBuffer
    EchoelAudioBuffer inputBuf = {nullptr, 0, frames};
    EchoelAudioBuffer outputBuf = {nullptr, 0, frames};

    if (proc->audio_inputs_count > 0 && proc->audio_inputs[0].data32) {
        inputBuf.channels = proc->audio_inputs[0].data32;
        inputBuf.channel_count = proc->audio_inputs[0].channel_count;
    }

    if (proc->audio_outputs_count > 0 && proc->audio_outputs[0].data32) {
        outputBuf.channels = proc->audio_outputs[0].data32;
        outputBuf.channel_count = proc->audio_outputs[0].channel_count;
    }

    // TODO: Convert CLAP events → EchoelMIDIEventList

    echoel_process(data->core, &inputBuf, &outputBuf, nullptr, nullptr, nullptr);

    return CLAP_PROCESS_CONTINUE;
}

const void* clap_get_extension(const clap_plugin_t*, const char*) {
    // TODO: Return params, state, note-ports, audio-ports extensions
    return nullptr;
}

void clap_on_main_thread(const clap_plugin_t*) { }

/* ─── Descriptors (one per Echoel engine) ─── */

struct ClapDescriptorEntry {
    clap_plugin_descriptor_t descriptor;
    EchoelEngineID engine;
};

static const char* synthFeats[] = {CLAP_PLUGIN_FEATURE_INSTRUMENT, CLAP_PLUGIN_FEATURE_SYNTHESIZER, nullptr};
static const char* fxFeats[] = {CLAP_PLUGIN_FEATURE_AUDIO_EFFECT, nullptr};
static const char* midiFeats[] = {CLAP_PLUGIN_FEATURE_NOTE_EFFECT, nullptr};
static const char* drumFeats[] = {CLAP_PLUGIN_FEATURE_INSTRUMENT, CLAP_PLUGIN_FEATURE_DRUM_MACHINE, nullptr};
static const char* mixFeats[] = {CLAP_PLUGIN_FEATURE_AUDIO_EFFECT, CLAP_PLUGIN_FEATURE_MIXING, nullptr};
static const char* analyzerFeats[] = {CLAP_PLUGIN_FEATURE_ANALYZER, nullptr};

static const ClapDescriptorEntry s_clapPlugins[] = {
    {{CLAP_VERSION_INIT, "com.echoelmusic.synth", "EchoelSynth",
      ECHOEL_VENDOR_NAME, ECHOEL_VENDOR_URL, "", "", ECHOEL_PLUGIN_VERSION_STRING,
      "Bio-reactive synthesis instrument with DDSP, Modal, Quantum engines", synthFeats},
     ECHOEL_ENGINE_SYNTH},

    {{CLAP_VERSION_INIT, "com.echoelmusic.fx", "EchoelFX",
      ECHOEL_VENDOR_NAME, ECHOEL_VENDOR_URL, "", "", ECHOEL_PLUGIN_VERSION_STRING,
      "Professional effects chain — reverb, delay, compressor, EQ, saturation", fxFeats},
     ECHOEL_ENGINE_FX},

    {{CLAP_VERSION_INIT, "com.echoelmusic.mix", "EchoelMix",
      ECHOEL_VENDOR_NAME, ECHOEL_VENDOR_URL, "", "", ECHOEL_PLUGIN_VERSION_STRING,
      "Console-grade mixer bus processor with spatial audio", mixFeats},
     ECHOEL_ENGINE_MIX},

    {{CLAP_VERSION_INIT, "com.echoelmusic.seq", "EchoelSeq",
      ECHOEL_VENDOR_NAME, ECHOEL_VENDOR_URL, "", "", ECHOEL_PLUGIN_VERSION_STRING,
      "Bio-reactive step sequencer with generative patterns", synthFeats},
     ECHOEL_ENGINE_SEQ},

    {{CLAP_VERSION_INIT, "com.echoelmusic.midi", "EchoelMIDI",
      ECHOEL_VENDOR_NAME, ECHOEL_VENDOR_URL, "", "", ECHOEL_PLUGIN_VERSION_STRING,
      "MIDI 2.0 + MPE processor, arpeggiator, chord generator", midiFeats},
     ECHOEL_ENGINE_MIDI},

    {{CLAP_VERSION_INIT, "com.echoelmusic.bio", "EchoelBio",
      ECHOEL_VENDOR_NAME, ECHOEL_VENDOR_URL, "", "", ECHOEL_PLUGIN_VERSION_STRING,
      "Binaural beat & AI tone generator for meditation and focus", synthFeats},
     ECHOEL_ENGINE_BIO},

    {{CLAP_VERSION_INIT, "com.echoelmusic.field", "EchoelField",
      ECHOEL_VENDOR_NAME, ECHOEL_VENDOR_URL, "", "", ECHOEL_PLUGIN_VERSION_STRING,
      "Audio-reactive visual analyzer with spectrum and waveform display", analyzerFeats},
     ECHOEL_ENGINE_FIELD},

    {{CLAP_VERSION_INIT, "com.echoelmusic.beam", "EchoelBeam",
      ECHOEL_VENDOR_NAME, ECHOEL_VENDOR_URL, "", "", ECHOEL_PLUGIN_VERSION_STRING,
      "Audio-to-lighting DMX bridge for live performance", midiFeats},
     ECHOEL_ENGINE_BEAM},

    {{CLAP_VERSION_INIT, "com.echoelmusic.net", "EchoelNet",
      ECHOEL_VENDOR_NAME, ECHOEL_VENDOR_URL, "", "", ECHOEL_PLUGIN_VERSION_STRING,
      "Network protocol bridge — OSC, MSC, Dante, NDI", midiFeats},
     ECHOEL_ENGINE_NET},

    {{CLAP_VERSION_INIT, "com.echoelmusic.mind", "EchoelMind",
      ECHOEL_VENDOR_NAME, ECHOEL_VENDOR_URL, "", "", ECHOEL_PLUGIN_VERSION_STRING,
      "AI-powered stem separation and audio enhancement", fxFeats},
     ECHOEL_ENGINE_MIND},

    {{CLAP_VERSION_INIT, "com.echoelmusic.bass", "EchoelBass",
      ECHOEL_VENDOR_NAME, ECHOEL_VENDOR_URL, "", "", ECHOEL_PLUGIN_VERSION_STRING,
      "5-engine morphing bass synthesizer — 808, Reese, Moog, Acid, Growl", synthFeats},
     ECHOEL_ENGINE_BASS},

    {{CLAP_VERSION_INIT, "com.echoelmusic.beat", "EchoelBeat",
      ECHOEL_VENDOR_NAME, ECHOEL_VENDOR_URL, "", "", ECHOEL_PLUGIN_VERSION_STRING,
      "Professional drum machine + 808 HiHat synth with roll sequencer", drumFeats},
     ECHOEL_ENGINE_BEAT},
};

static const uint32_t s_clapPluginCount = sizeof(s_clapPlugins) / sizeof(s_clapPlugins[0]);

/* ─── Factory ─── */

bool factory_get_count(const void*) {
    return s_clapPluginCount;
}

const clap_plugin_descriptor_t* factory_get_descriptor(const void*, uint32_t index) {
    if (index >= s_clapPluginCount) return nullptr;
    return &s_clapPlugins[index].descriptor;
}

const clap_plugin_t* factory_create(const void*, const clap_host_t*, const char* pluginID) {
    for (uint32_t i = 0; i < s_clapPluginCount; i++) {
        if (std::strcmp(s_clapPlugins[i].descriptor.id, pluginID) == 0) {
            auto* data = new ClapPluginData();
            data->engineID = s_clapPlugins[i].engine;
            data->core = echoel_create(data->engineID);

            auto* plugin = new clap_plugin_t();
            plugin->desc = &s_clapPlugins[i].descriptor;
            plugin->plugin_data = data;
            plugin->init = clap_init;
            plugin->destroy = clap_destroy;
            plugin->activate = clap_activate;
            plugin->deactivate = clap_deactivate_cb;
            plugin->start_processing = clap_start_processing;
            plugin->stop_processing = clap_stop_processing;
            plugin->reset = clap_reset_cb;
            plugin->process = clap_process_cb;
            plugin->get_extension = clap_get_extension;
            plugin->on_main_thread = clap_on_main_thread;

            return plugin;
        }
    }
    return nullptr;
}

static const clap_plugin_factory_t s_factory = {
    factory_get_count,
    factory_get_descriptor,
    factory_create
};

/* ─── Entry ─── */

bool entry_init(const char*) { return true; }
void entry_deinit(void) { }

const void* entry_get_factory(const char* factoryID) {
    if (std::strcmp(factoryID, CLAP_PLUGIN_FACTORY_ID) == 0)
        return &s_factory;
    return nullptr;
}

} // anonymous namespace

/* ═══════════════════════════════════════════════════════════════════════════ */
/* CLAP Entry Point (exported symbol)                                         */
/* ═══════════════════════════════════════════════════════════════════════════ */

extern "C" {

ECHOEL_EXPORT const clap_plugin_entry_t clap_entry = {
    CLAP_VERSION_INIT,
    entry_init,
    entry_deinit,
    entry_get_factory
};

} /* extern "C" */
