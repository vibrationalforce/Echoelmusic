#pragma once
/**
 * EchoelCore - CLAPTypes
 *
 * Minimal CLAP type definitions for standalone compilation.
 * When full CLAP support is needed, define ECHOELCORE_CLAP_INCLUDE
 * and include the official clap.h instead.
 *
 * Based on CLAP specification: https://github.com/free-audio/clap
 *
 * MIT License - Echoelmusic 2026
 */

#include <cstdint>

// Only define types if CLAP headers not included
#ifndef CLAP_VERSION_MAJOR

//==============================================================================
// CLAP Version
//==============================================================================

#define CLAP_VERSION_MAJOR 1
#define CLAP_VERSION_MINOR 2
#define CLAP_VERSION_REVISION 2

typedef struct clap_version {
    uint32_t major;
    uint32_t minor;
    uint32_t revision;
} clap_version_t;

#define CLAP_VERSION ((clap_version_t){CLAP_VERSION_MAJOR, CLAP_VERSION_MINOR, CLAP_VERSION_REVISION})

//==============================================================================
// Core Types
//==============================================================================

typedef uint32_t clap_id;

#define CLAP_INVALID_ID UINT32_MAX

// Plugin descriptor
typedef struct clap_plugin_descriptor {
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

// Host
typedef struct clap_host {
    clap_version_t clap_version;
    void* host_data;
    const char* name;
    const char* vendor;
    const char* url;
    const char* version;

    void (*request_restart)(const struct clap_host* host);
    void (*request_process)(const struct clap_host* host);
    void (*request_callback)(const struct clap_host* host);
} clap_host_t;

// Plugin
typedef struct clap_plugin {
    const clap_plugin_descriptor_t* desc;
    void* plugin_data;

    bool (*init)(const struct clap_plugin* plugin);
    void (*destroy)(const struct clap_plugin* plugin);
    bool (*activate)(const struct clap_plugin* plugin, double sample_rate, uint32_t min_frames, uint32_t max_frames);
    void (*deactivate)(const struct clap_plugin* plugin);
    bool (*start_processing)(const struct clap_plugin* plugin);
    void (*stop_processing)(const struct clap_plugin* plugin);
    void (*reset)(const struct clap_plugin* plugin);
    int32_t (*process)(const struct clap_plugin* plugin, const struct clap_process* process);
    const void* (*get_extension)(const struct clap_plugin* plugin, const char* id);
    void (*on_main_thread)(const struct clap_plugin* plugin);
} clap_plugin_t;

//==============================================================================
// Audio Buffers
//==============================================================================

typedef struct clap_audio_buffer {
    float** data32;
    double** data64;
    uint32_t channel_count;
    uint32_t latency;
    uint64_t constant_mask;
} clap_audio_buffer_t;

//==============================================================================
// Events
//==============================================================================

enum {
    CLAP_EVENT_NOTE_ON = 0,
    CLAP_EVENT_NOTE_OFF = 1,
    CLAP_EVENT_NOTE_CHOKE = 2,
    CLAP_EVENT_NOTE_END = 3,
    CLAP_EVENT_NOTE_EXPRESSION = 4,
    CLAP_EVENT_PARAM_VALUE = 5,
    CLAP_EVENT_PARAM_MOD = 6,
    CLAP_EVENT_PARAM_GESTURE_BEGIN = 7,
    CLAP_EVENT_PARAM_GESTURE_END = 8,
    CLAP_EVENT_TRANSPORT = 9,
    CLAP_EVENT_MIDI = 10,
    CLAP_EVENT_MIDI_SYSEX = 11,
    CLAP_EVENT_MIDI2 = 12
};

typedef struct clap_event_header {
    uint32_t size;
    uint32_t time;
    uint16_t space_id;
    uint16_t type;
    uint32_t flags;
} clap_event_header_t;

typedef struct clap_event_note {
    clap_event_header_t header;
    int32_t note_id;
    int16_t port_index;
    int16_t channel;
    int16_t key;
    double velocity;
} clap_event_note_t;

typedef struct clap_event_param_value {
    clap_event_header_t header;
    clap_id param_id;
    void* cookie;
    int32_t note_id;
    int16_t port_index;
    int16_t channel;
    int16_t key;
    double value;
} clap_event_param_value_t;

typedef struct clap_input_events {
    void* ctx;
    uint32_t (*size)(const struct clap_input_events* list);
    const clap_event_header_t* (*get)(const struct clap_input_events* list, uint32_t index);
} clap_input_events_t;

typedef struct clap_output_events {
    void* ctx;
    bool (*try_push)(const struct clap_output_events* list, const clap_event_header_t* event);
} clap_output_events_t;

//==============================================================================
// Process
//==============================================================================

typedef struct clap_process {
    uint64_t steady_time;
    uint32_t frames_count;
    const struct clap_transport* transport;
    const clap_audio_buffer_t* audio_inputs;
    clap_audio_buffer_t* audio_outputs;
    uint32_t audio_inputs_count;
    uint32_t audio_outputs_count;
    const clap_input_events_t* in_events;
    const clap_output_events_t* out_events;
} clap_process_t;

enum {
    CLAP_PROCESS_ERROR = 0,
    CLAP_PROCESS_CONTINUE = 1,
    CLAP_PROCESS_CONTINUE_IF_NOT_QUIET = 2,
    CLAP_PROCESS_TAIL = 3,
    CLAP_PROCESS_SLEEP = 4
};

//==============================================================================
// Parameters
//==============================================================================

enum {
    CLAP_PARAM_IS_STEPPED = 1 << 0,
    CLAP_PARAM_IS_PERIODIC = 1 << 1,
    CLAP_PARAM_IS_HIDDEN = 1 << 2,
    CLAP_PARAM_IS_READONLY = 1 << 3,
    CLAP_PARAM_IS_BYPASS = 1 << 4,
    CLAP_PARAM_IS_AUTOMATABLE = 1 << 5,
    CLAP_PARAM_IS_AUTOMATABLE_PER_NOTE_ID = 1 << 6,
    CLAP_PARAM_IS_AUTOMATABLE_PER_KEY = 1 << 7,
    CLAP_PARAM_IS_AUTOMATABLE_PER_CHANNEL = 1 << 8,
    CLAP_PARAM_IS_AUTOMATABLE_PER_PORT = 1 << 9,
    CLAP_PARAM_IS_MODULATABLE = 1 << 10,
    CLAP_PARAM_IS_MODULATABLE_PER_NOTE_ID = 1 << 11,
    CLAP_PARAM_IS_MODULATABLE_PER_KEY = 1 << 12,
    CLAP_PARAM_IS_MODULATABLE_PER_CHANNEL = 1 << 13,
    CLAP_PARAM_IS_MODULATABLE_PER_PORT = 1 << 14,
    CLAP_PARAM_REQUIRES_PROCESS = 1 << 15
};

typedef struct clap_param_info {
    clap_id id;
    uint32_t flags;
    void* cookie;
    char name[256];
    char module[1024];
    double min_value;
    double max_value;
    double default_value;
} clap_param_info_t;

//==============================================================================
// Factory
//==============================================================================

#define CLAP_PLUGIN_FACTORY_ID "clap.plugin-factory"

typedef struct clap_plugin_factory {
    uint32_t (*get_plugin_count)(const struct clap_plugin_factory* factory);
    const clap_plugin_descriptor_t* (*get_plugin_descriptor)(const struct clap_plugin_factory* factory, uint32_t index);
    const clap_plugin_t* (*create_plugin)(const struct clap_plugin_factory* factory, const clap_host_t* host, const char* plugin_id);
} clap_plugin_factory_t;

//==============================================================================
// Entry Point
//==============================================================================

typedef struct clap_plugin_entry {
    clap_version_t clap_version;
    bool (*init)(const char* plugin_path);
    void (*deinit)(void);
    const void* (*get_factory)(const char* factory_id);
} clap_plugin_entry_t;

#ifdef _WIN32
    #define CLAP_EXPORT __declspec(dllexport)
#else
    #define CLAP_EXPORT __attribute__((visibility("default")))
#endif

//==============================================================================
// Common Extensions
//==============================================================================

#define CLAP_EXT_LOG "clap.log"
#define CLAP_EXT_PARAMS "clap.params"
#define CLAP_EXT_STATE "clap.state"
#define CLAP_EXT_GUI "clap.gui"
#define CLAP_EXT_AUDIO_PORTS "clap.audio-ports"
#define CLAP_EXT_NOTE_PORTS "clap.note-ports"
#define CLAP_EXT_LATENCY "clap.latency"
#define CLAP_EXT_TAIL "clap.tail"

//==============================================================================
// Plugin Features
//==============================================================================

#define CLAP_PLUGIN_FEATURE_INSTRUMENT "instrument"
#define CLAP_PLUGIN_FEATURE_AUDIO_EFFECT "audio-effect"
#define CLAP_PLUGIN_FEATURE_ANALYZER "analyzer"
#define CLAP_PLUGIN_FEATURE_SYNTHESIZER "synthesizer"
#define CLAP_PLUGIN_FEATURE_SAMPLER "sampler"
#define CLAP_PLUGIN_FEATURE_DRUM "drum"
#define CLAP_PLUGIN_FEATURE_FILTER "filter"
#define CLAP_PLUGIN_FEATURE_REVERB "reverb"
#define CLAP_PLUGIN_FEATURE_DELAY "delay"
#define CLAP_PLUGIN_FEATURE_DISTORTION "distortion"
#define CLAP_PLUGIN_FEATURE_COMPRESSOR "compressor"
#define CLAP_PLUGIN_FEATURE_EQUALIZER "equalizer"
#define CLAP_PLUGIN_FEATURE_STEREO "stereo"
#define CLAP_PLUGIN_FEATURE_MONO "mono"

#endif // CLAP_VERSION_MAJOR
