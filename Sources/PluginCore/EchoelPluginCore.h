/*
 *  EchoelPluginCore.h
 *  Echoelmusic — Unified Plugin Core
 *
 *  Created: February 2026
 *  UNIVERSAL C ABI INTERFACE — shared by ALL plugin formats
 *
 *  ===========================================================================
 *  This single C API is the bridge between Echoelmusic's DSP engine and every
 *  plugin wrapper (AUv3, AU, VST3, AAX, CLAP, OFX, DCTL, FFX, Standalone).
 *
 *  Architecture:
 *    Host (DAW / NLE / Standalone)
 *        │
 *    Plugin Format Wrapper (VST3/CLAP/AAX/OFX/...)
 *        │
 *    ═══ EchoelPluginCore.h  ←── THIS FILE (C ABI boundary) ═══
 *        │
 *    Echoelmusic DSP Engine (C++17, SIMD, lock-free)
 *
 *  Design Principles:
 *  • Pure C ABI — no C++ in public headers (dlopen-safe)
 *  • Opaque handle pattern — zero ABI breakage across versions
 *  • Real-time safe — no allocations in process(), no locks
 *  • Thread-safe lifecycle — create/destroy on any thread
 *  • SIMD-aligned buffers — 64-byte alignment for AVX-512
 *  ===========================================================================
 */

#ifndef ECHOEL_PLUGIN_CORE_H
#define ECHOEL_PLUGIN_CORE_H

#include <stdint.h>
#include <stdbool.h>

#ifdef __cplusplus
extern "C" {
#endif

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Version & ABI                                                              */
/* ═══════════════════════════════════════════════════════════════════════════ */

#define ECHOEL_PLUGIN_API_VERSION       1
#define ECHOEL_PLUGIN_VERSION_MAJOR     2
#define ECHOEL_PLUGIN_VERSION_MINOR     0
#define ECHOEL_PLUGIN_VERSION_PATCH     0
#define ECHOEL_PLUGIN_VERSION_STRING    "2.0.0"

#define ECHOEL_VENDOR_NAME              "Echoelmusic"
#define ECHOEL_VENDOR_URL               "https://echoelmusic.com"
#define ECHOEL_VENDOR_EMAIL             "dev@echoelmusic.com"

/* Export macros */
#if defined(_WIN32) || defined(__CYGWIN__)
    #define ECHOEL_EXPORT __declspec(dllexport)
    #define ECHOEL_IMPORT __declspec(dllimport)
#elif defined(__GNUC__) || defined(__clang__)
    #define ECHOEL_EXPORT __attribute__((visibility("default")))
    #define ECHOEL_IMPORT
#else
    #define ECHOEL_EXPORT
    #define ECHOEL_IMPORT
#endif

#ifdef ECHOEL_PLUGIN_BUILDING
    #define ECHOEL_API ECHOEL_EXPORT
#else
    #define ECHOEL_API ECHOEL_IMPORT
#endif

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Opaque Handle                                                              */
/* ═══════════════════════════════════════════════════════════════════════════ */

/** Opaque plugin instance — wraps the full Echoelmusic DSP engine */
typedef struct EchoelPlugin* EchoelPluginRef;

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Plugin Types                                                               */
/* ═══════════════════════════════════════════════════════════════════════════ */

/** Plugin categories matching AU/VST3/CLAP/AAX classifications */
typedef enum {
    ECHOEL_PLUGIN_TYPE_INSTRUMENT    = 0,   /* aumu / kVstSynth / CLAP_PLUGIN_FEATURE_INSTRUMENT */
    ECHOEL_PLUGIN_TYPE_EFFECT        = 1,   /* aufx / kVstAudioEffect / CLAP_PLUGIN_FEATURE_AUDIO_EFFECT */
    ECHOEL_PLUGIN_TYPE_MIDI          = 2,   /* aumi / kVstMidiEffect */
    ECHOEL_PLUGIN_TYPE_ANALYZER      = 3,   /* aufx with no output modification */
    ECHOEL_PLUGIN_TYPE_VIDEO_EFFECT  = 4,   /* OFX / DCTL / FFX video processing */
} EchoelPluginType;

/** Which Echoel engine to instantiate */
typedef enum {
    /* Audio Plugins (10 AU types) */
    ECHOEL_ENGINE_SYNTH       = 0,    /* EchoelSynth — bio-reactive synthesis */
    ECHOEL_ENGINE_FX          = 1,    /* EchoelFX — effects chain */
    ECHOEL_ENGINE_MIX         = 2,    /* EchoelMix — mixer / spatial */
    ECHOEL_ENGINE_SEQ         = 3,    /* EchoelSeq — bio-reactive sequencer */
    ECHOEL_ENGINE_MIDI        = 4,    /* EchoelMIDI — MIDI 2.0 + MPE */
    ECHOEL_ENGINE_BIO         = 5,    /* EchoelBio — binaural beats */
    ECHOEL_ENGINE_FIELD       = 6,    /* EchoelField — visual analyzer */
    ECHOEL_ENGINE_BEAM        = 7,    /* EchoelBeam — DMX lighting */
    ECHOEL_ENGINE_NET         = 8,    /* EchoelNet — OSC/MSC/Dante */
    ECHOEL_ENGINE_MIND        = 9,    /* EchoelMind — AI stem separation */

    /* Instruments */
    ECHOEL_ENGINE_BASS        = 10,   /* EchoelBass — 5-engine morphing bass */
    ECHOEL_ENGINE_BEAT        = 11,   /* EchoelBeat — drum machine */
    ECHOEL_ENGINE_DDSP        = 12,   /* EchoelDDSP — differentiable synthesis */
    ECHOEL_ENGINE_MODAL       = 13,   /* EchoelModalBank — modal synthesis */
    ECHOEL_ENGINE_CELLULAR    = 14,   /* EchoelCellular — cellular automata */
    ECHOEL_ENGINE_QUANTUM     = 15,   /* EchoelQuantum — quantum synthesis */
    ECHOEL_ENGINE_SAMPLER     = 16,   /* EchoelSampler — sample player */
    ECHOEL_ENGINE_CHOPPER     = 17,   /* BreakbeatChopper — break slicer */

    /* Video / Visual Plugins */
    ECHOEL_ENGINE_VFX         = 30,   /* EchoelVFX — OFX video effect */
    ECHOEL_ENGINE_COLOR       = 31,   /* EchoelColor — DCTL color grading */
    ECHOEL_ENGINE_COMPUTE     = 32,   /* EchoelCompute — FFX/HLSL compute */

    ECHOEL_ENGINE_COUNT
} EchoelEngineID;

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Parameter Types                                                            */
/* ═══════════════════════════════════════════════════════════════════════════ */

/** Parameter value type */
typedef enum {
    ECHOEL_PARAM_FLOAT   = 0,
    ECHOEL_PARAM_INT     = 1,
    ECHOEL_PARAM_BOOL    = 2,
    ECHOEL_PARAM_ENUM    = 3,
} EchoelParamType;

/** Parameter flags */
typedef enum {
    ECHOEL_PARAM_FLAG_AUTOMATABLE   = 1 << 0,
    ECHOEL_PARAM_FLAG_READONLY      = 1 << 1,
    ECHOEL_PARAM_FLAG_HIDDEN        = 1 << 2,
    ECHOEL_PARAM_FLAG_STEPPED       = 1 << 3,
    ECHOEL_PARAM_FLAG_IS_BYPASS     = 1 << 4,
    ECHOEL_PARAM_FLAG_MODULATABLE   = 1 << 5,
} EchoelParamFlags;

/** Parameter descriptor (static metadata) */
typedef struct {
    uint32_t    id;
    const char* name;           /* UTF-8, null-terminated */
    const char* short_name;     /* max 8 chars for small displays */
    const char* unit_label;     /* "dB", "Hz", "%", "ms", "" */
    const char* group;          /* parameter group path "Osc/Shape" */
    EchoelParamType type;
    uint32_t    flags;
    double      min_value;
    double      max_value;
    double      default_value;
    double      step_size;      /* 0 = continuous */
    uint32_t    enum_count;     /* number of enum entries if type==ENUM */
    const char* const* enum_names;  /* array of enum label strings */
} EchoelParamInfo;

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Audio Buffer                                                               */
/* ═══════════════════════════════════════════════════════════════════════════ */

/** Audio buffer descriptor — non-interleaved, 32-bit float */
typedef struct {
    float**     channels;       /* array of channel pointers */
    uint32_t    channel_count;
    uint32_t    frame_count;
} EchoelAudioBuffer;

/** Audio bus configuration */
typedef struct {
    uint32_t    input_channels;
    uint32_t    output_channels;
    uint32_t    sidechain_channels;
} EchoelBusConfig;

/* ═══════════════════════════════════════════════════════════════════════════ */
/* MIDI Events                                                                */
/* ═══════════════════════════════════════════════════════════════════════════ */

typedef enum {
    ECHOEL_MIDI_NOTE_ON         = 0x90,
    ECHOEL_MIDI_NOTE_OFF        = 0x80,
    ECHOEL_MIDI_CC              = 0xB0,
    ECHOEL_MIDI_PITCH_BEND      = 0xE0,
    ECHOEL_MIDI_AFTERTOUCH      = 0xD0,
    ECHOEL_MIDI_POLY_PRESSURE   = 0xA0,
    ECHOEL_MIDI_PROGRAM_CHANGE  = 0xC0,
    ECHOEL_MIDI_SYSEX           = 0xF0,
} EchoelMIDIStatus;

typedef struct {
    int32_t     sample_offset;  /* sample position within current buffer */
    uint8_t     status;         /* MIDI status byte (type + channel) */
    uint8_t     data1;          /* note number / CC number */
    uint8_t     data2;          /* velocity / CC value */
    uint8_t     channel;        /* 0-15 */
} EchoelMIDIEvent;

/** MIDI event list for batch processing */
typedef struct {
    const EchoelMIDIEvent* events;
    uint32_t               count;
} EchoelMIDIEventList;

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Bio-Reactive Data                                                          */
/* ═══════════════════════════════════════════════════════════════════════════ */

/** Real-time biometric data from HealthKit / wearables / EEG */
typedef struct {
    float   heart_rate;         /* BPM (40-220) */
    float   hrv;                /* Heart rate variability in ms (0-200) */
    float   coherence;          /* Normalized 0-1 (cardiac coherence) */
    float   breath_phase;       /* 0-1 (0=exhale, 1=inhale) */
    float   breath_rate;        /* breaths per minute */
    float   eeg_alpha;          /* Alpha band power (relaxation) 0-1 */
    float   eeg_beta;           /* Beta band power (focus) 0-1 */
    float   eeg_theta;          /* Theta band power (meditation) 0-1 */
    float   gsr;                /* Galvanic skin response 0-1 */
    float   temperature;        /* Skin temperature deviation from baseline */
    bool    is_valid;           /* true if sensors are active */
    double  timestamp;          /* host time in seconds */
} EchoelBioData;

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Video / Image Buffer (OFX / DCTL / FFX)                                    */
/* ═══════════════════════════════════════════════════════════════════════════ */

typedef enum {
    ECHOEL_PIXEL_RGBA_F32   = 0,    /* 4x float32 per pixel */
    ECHOEL_PIXEL_RGBA_F16   = 1,    /* 4x float16 per pixel */
    ECHOEL_PIXEL_RGBA_U8    = 2,    /* 4x uint8 per pixel */
    ECHOEL_PIXEL_RGBA_U16   = 3,    /* 4x uint16 per pixel */
    ECHOEL_PIXEL_YUV_420    = 10,   /* Planar YUV 4:2:0 */
    ECHOEL_PIXEL_NV12       = 11,   /* Semi-planar NV12 */
} EchoelPixelFormat;

typedef struct {
    void*               data;           /* pixel data pointer */
    uint32_t            width;
    uint32_t            height;
    uint32_t            row_bytes;       /* stride in bytes */
    EchoelPixelFormat   pixel_format;
    uint32_t            field;           /* 0=progressive, 1=upper, 2=lower */
} EchoelImageBuffer;

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Process Context (transport, tempo, etc.)                                   */
/* ═══════════════════════════════════════════════════════════════════════════ */

typedef struct {
    double      sample_rate;
    double      tempo;              /* BPM */
    double      bar_position;       /* musical position in bars */
    double      beat_position;      /* musical position in beats */
    int32_t     time_sig_num;       /* time signature numerator */
    int32_t     time_sig_den;       /* time signature denominator */
    int64_t     sample_position;    /* absolute sample position */
    bool        is_playing;
    bool        is_recording;
    bool        is_looping;
    double      loop_start;         /* in beats */
    double      loop_end;           /* in beats */
} EchoelProcessContext;

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Plugin Descriptor (static info per plugin type)                            */
/* ═══════════════════════════════════════════════════════════════════════════ */

typedef struct {
    EchoelEngineID   engine_id;
    EchoelPluginType plugin_type;
    const char*      id;            /* unique string ID "com.echoelmusic.synth" */
    const char*      name;          /* display name "EchoelSynth" */
    const char*      description;
    const char*      version;
    const char*      vendor;
    const char*      url;
    uint32_t         param_count;
    EchoelBusConfig  bus_config;

    /* AU-specific */
    uint32_t         au_type;       /* 'aumu', 'aufx', 'aumi' */
    uint32_t         au_subtype;    /* 'Esyn', 'Eefx', etc. */
    uint32_t         au_manufacturer; /* 'Echo' */

    /* VST3-specific */
    const char*      vst3_class_id; /* 16-byte TUID as hex string */

    /* CLAP-specific */
    const char*      clap_id;       /* "com.echoelmusic.synth" */
    const char* const* clap_features; /* null-terminated feature list */

    /* AAX-specific */
    uint32_t         aax_type_id;

    /* OFX-specific */
    const char*      ofx_id;        /* "com.echoelmusic:EchoelVFX" */
    const char*      ofx_group;     /* "Echoelmusic" */
} EchoelPluginDescriptor;

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Plugin Lifecycle                                                           */
/* ═══════════════════════════════════════════════════════════════════════════ */

/** Get the number of available plugin types */
ECHOEL_API uint32_t echoel_get_plugin_count(void);

/** Get descriptor for plugin at index */
ECHOEL_API const EchoelPluginDescriptor* echoel_get_plugin_descriptor(uint32_t index);

/** Get descriptor by engine ID */
ECHOEL_API const EchoelPluginDescriptor* echoel_get_descriptor_by_engine(EchoelEngineID engine);

/** Create a plugin instance */
ECHOEL_API EchoelPluginRef echoel_create(EchoelEngineID engine);

/** Destroy a plugin instance */
ECHOEL_API void echoel_destroy(EchoelPluginRef plugin);

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Activation / Deactivation                                                  */
/* ═══════════════════════════════════════════════════════════════════════════ */

/** Activate plugin for processing (allocate real-time buffers) */
ECHOEL_API bool echoel_activate(EchoelPluginRef plugin, double sample_rate, uint32_t max_block_size);

/** Deactivate plugin (free real-time buffers) */
ECHOEL_API void echoel_deactivate(EchoelPluginRef plugin);

/** Reset all internal state (clear delay lines, envelopes, etc.) */
ECHOEL_API void echoel_reset(EchoelPluginRef plugin);

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Audio Processing (REAL-TIME SAFE — no allocations, no locks)               */
/* ═══════════════════════════════════════════════════════════════════════════ */

/** Process audio block with MIDI events and transport context.
 *  @param plugin       Plugin handle
 *  @param input        Input audio buffer (may be NULL for instruments)
 *  @param output       Output audio buffer
 *  @param midi_in      Incoming MIDI events (may be NULL)
 *  @param midi_out     Buffer for outgoing MIDI (may be NULL)
 *  @param context      Transport/tempo context (may be NULL)
 */
ECHOEL_API void echoel_process(
    EchoelPluginRef             plugin,
    const EchoelAudioBuffer*    input,
    EchoelAudioBuffer*          output,
    const EchoelMIDIEventList*  midi_in,
    EchoelMIDIEventList*        midi_out,
    const EchoelProcessContext* context
);

/** Process double-precision audio (for mastering / analysis) */
ECHOEL_API void echoel_process_double(
    EchoelPluginRef             plugin,
    const double* const*        input,
    double**                    output,
    uint32_t                    channel_count,
    uint32_t                    frame_count,
    const EchoelProcessContext* context
);

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Video Processing (OFX / DCTL / FFX)                                        */
/* ═══════════════════════════════════════════════════════════════════════════ */

/** Process a video frame (bio-reactive visual effects).
 *  Uses current bio-data and audio analysis to modulate visuals.
 */
ECHOEL_API void echoel_process_image(
    EchoelPluginRef             plugin,
    const EchoelImageBuffer*    input,
    EchoelImageBuffer*          output,
    double                      time,       /* timeline time in seconds */
    double                      frame_rate
);

/** Get the current audio analysis data (RMS, peak, spectrum, onset) */
ECHOEL_API void echoel_get_audio_analysis(
    EchoelPluginRef plugin,
    float*          rms,            /* stereo RMS [2] */
    float*          peak,           /* stereo peak [2] */
    float*          spectrum,       /* FFT magnitude bins [spectrum_size] */
    uint32_t*       spectrum_size
);

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Parameters                                                                 */
/* ═══════════════════════════════════════════════════════════════════════════ */

/** Get parameter count */
ECHOEL_API uint32_t echoel_get_parameter_count(EchoelPluginRef plugin);

/** Get parameter info by index */
ECHOEL_API bool echoel_get_parameter_info(EchoelPluginRef plugin, uint32_t index, EchoelParamInfo* info);

/** Get parameter value (thread-safe, lock-free) */
ECHOEL_API double echoel_get_parameter(EchoelPluginRef plugin, uint32_t id);

/** Set parameter value (thread-safe, lock-free) */
ECHOEL_API void echoel_set_parameter(EchoelPluginRef plugin, uint32_t id, double value);

/** Get parameter value as formatted string */
ECHOEL_API void echoel_format_parameter(EchoelPluginRef plugin, uint32_t id, char* buffer, uint32_t buffer_size);

/** Begin parameter gesture (for host undo grouping) */
ECHOEL_API void echoel_begin_parameter_gesture(EchoelPluginRef plugin, uint32_t id);

/** End parameter gesture */
ECHOEL_API void echoel_end_parameter_gesture(EchoelPluginRef plugin, uint32_t id);

/* ═══════════════════════════════════════════════════════════════════════════ */
/* State / Presets                                                            */
/* ═══════════════════════════════════════════════════════════════════════════ */

/** Get serialized state (caller must free with echoel_free_state) */
ECHOEL_API bool echoel_get_state(EchoelPluginRef plugin, const uint8_t** data, uint32_t* size);

/** Restore state from serialized data */
ECHOEL_API bool echoel_set_state(EchoelPluginRef plugin, const uint8_t* data, uint32_t size);

/** Free state data returned by echoel_get_state */
ECHOEL_API void echoel_free_state(const uint8_t* data);

/** Get number of factory presets */
ECHOEL_API uint32_t echoel_get_preset_count(EchoelPluginRef plugin);

/** Get preset name by index */
ECHOEL_API const char* echoel_get_preset_name(EchoelPluginRef plugin, uint32_t index);

/** Load factory preset by index */
ECHOEL_API bool echoel_load_preset(EchoelPluginRef plugin, uint32_t index);

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Bio-Reactive Integration                                                   */
/* ═══════════════════════════════════════════════════════════════════════════ */

/** Update biometric data (called from sensor thread, lock-free) */
ECHOEL_API void echoel_set_bio_data(EchoelPluginRef plugin, const EchoelBioData* bio);

/** Get current bio-reactive modulation state */
ECHOEL_API void echoel_get_bio_modulation(
    EchoelPluginRef plugin,
    float*          filter_mod,     /* filter cutoff modulation -1..+1 */
    float*          reverb_mod,     /* reverb mix modulation 0..1 */
    float*          tempo_mod,      /* tempo modulation factor 0.5..2.0 */
    float*          intensity_mod   /* overall intensity 0..1 */
);

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Latency & Tail                                                             */
/* ═══════════════════════════════════════════════════════════════════════════ */

/** Get processing latency in samples */
ECHOEL_API uint32_t echoel_get_latency(EchoelPluginRef plugin);

/** Get tail time in seconds (reverb/delay tail after input stops) */
ECHOEL_API double echoel_get_tail_time(EchoelPluginRef plugin);

/* ═══════════════════════════════════════════════════════════════════════════ */
/* GUI (optional — plugins can be headless)                                   */
/* ═══════════════════════════════════════════════════════════════════════════ */

typedef enum {
    ECHOEL_GUI_API_COCOA    = 0,    /* macOS NSView */
    ECHOEL_GUI_API_UIKIT    = 1,    /* iOS UIView */
    ECHOEL_GUI_API_WIN32    = 2,    /* Windows HWND */
    ECHOEL_GUI_API_X11      = 3,    /* Linux X11 Window */
    ECHOEL_GUI_API_WAYLAND  = 4,    /* Linux Wayland */
    ECHOEL_GUI_API_WEB      = 5,    /* WebView / HTML */
} EchoelGUIAPI;

/** Check if GUI is supported */
ECHOEL_API bool echoel_gui_is_supported(EchoelPluginRef plugin, EchoelGUIAPI api);

/** Create GUI and attach to parent window */
ECHOEL_API bool echoel_gui_create(EchoelPluginRef plugin, EchoelGUIAPI api, void* parent);

/** Destroy GUI */
ECHOEL_API void echoel_gui_destroy(EchoelPluginRef plugin);

/** Get preferred GUI size */
ECHOEL_API void echoel_gui_get_size(EchoelPluginRef plugin, uint32_t* width, uint32_t* height);

/** Set GUI size (resizable plugins) */
ECHOEL_API bool echoel_gui_set_size(EchoelPluginRef plugin, uint32_t width, uint32_t height);

/* ═══════════════════════════════════════════════════════════════════════════ */
/* Utility                                                                    */
/* ═══════════════════════════════════════════════════════════════════════════ */

/** Get API version */
ECHOEL_API uint32_t echoel_get_api_version(void);

/** Get human-readable version string */
ECHOEL_API const char* echoel_get_version_string(void);

/** Get build info (compiler, date, SIMD level) */
ECHOEL_API const char* echoel_get_build_info(void);

#ifdef __cplusplus
} /* extern "C" */
#endif

#endif /* ECHOEL_PLUGIN_CORE_H */
