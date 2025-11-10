/*
 * Echoelmusic CLAP Plugin
 * CLever Audio Plugin format implementation
 *
 * CLAP is the new open-source audio plugin standard
 * Advantages over VST3/AU:
 * - Open source (no licensing fees)
 * - Modern C API
 * - Better parameter automation
 * - Polyphonic expression support
 * - Note expressions (MPE)
 * - Modulation system
 * - GUI API agnostic
 *
 * Specification: https://github.com/free-audio/clap
 */

#pragma once

#include <clap/clap.h>
#include <string>
#include <vector>
#include <memory>
#include <atomic>

// Forward declarations
class EchoelmusicAudioEngine;

// ==============================================================================
// CLAP Plugin Descriptor
// ==============================================================================

extern "C" {

// Plugin entry point
CLAP_EXPORT extern const clap_plugin_entry_t clap_entry;

// Plugin factory
const clap_plugin_factory_t* get_plugin_factory();

}  // extern "C"

// ==============================================================================
// Echoelmusic CLAP Plugin Class
// ==============================================================================

class EchoelmusicClapPlugin {
public:
    EchoelmusicClapPlugin(const clap_host_t* host);
    ~EchoelmusicClapPlugin();

    // CLAP plugin interface
    bool init();
    void destroy();

    bool activate(double sample_rate, uint32_t min_frames_count, uint32_t max_frames_count);
    void deactivate();

    bool start_processing();
    void stop_processing();

    void reset();

    clap_process_status process(const clap_process_t* process);

    // Extension: Audio Ports
    uint32_t audio_ports_count(bool is_input) const;
    bool audio_ports_get(uint32_t index, bool is_input, clap_audio_port_info_t* info) const;

    // Extension: Note Ports (MIDI)
    uint32_t note_ports_count(bool is_input) const;
    bool note_ports_get(uint32_t index, bool is_input, clap_note_port_info_t* info) const;

    // Extension: Parameters
    uint32_t params_count() const;
    bool params_get_info(uint32_t param_index, clap_param_info_t* param_info) const;
    bool params_get_value(clap_id param_id, double* value) const;
    bool params_value_to_text(clap_id param_id, double value, char* display, uint32_t size) const;
    bool params_text_to_value(clap_id param_id, const char* display, double* value) const;
    void params_flush(const clap_input_events_t* in, const clap_output_events_t* out);

    // Extension: State (save/load)
    bool state_save(const clap_ostream_t* stream);
    bool state_load(const clap_istream_t* stream);

    // Extension: GUI (optional)
    bool gui_is_api_supported(const char* api, bool is_floating);
    bool gui_get_preferred_api(const char** api, bool* is_floating);
    bool gui_create(const char* api, bool is_floating);
    void gui_destroy();
    bool gui_set_scale(double scale);
    bool gui_get_size(uint32_t* width, uint32_t* height);
    bool gui_can_resize();
    bool gui_get_resize_hints(clap_gui_resize_hints_t* hints);
    bool gui_adjust_size(uint32_t* width, uint32_t* height);
    bool gui_set_size(uint32_t width, uint32_t height);
    bool gui_set_parent(const clap_window_t* window);
    bool gui_set_transient(const clap_window_t* window);
    void gui_suggest_title(const char* title);
    bool gui_show();
    bool gui_hide();

    // Extension: Voice Info (polyphony)
    bool voice_info_get(clap_voice_info_t* info);

    // Extension: Latency
    uint32_t latency_get() const;

    // Extension: Render (offline rendering)
    bool render_has_hard_realtime_requirement();
    bool render_set(clap_plugin_render_mode mode);

private:
    // Host interface
    const clap_host_t* host_;

    // Audio engine
    std::unique_ptr<EchoelmusicAudioEngine> engine_;

    // Plugin state
    double sample_rate_ = 48000.0;
    uint32_t max_frames_count_ = 512;
    bool activated_ = false;
    bool processing_ = false;

    // Parameters
    struct Parameter {
        clap_id id;
        std::string name;
        std::string module;  // Parameter grouping
        double min_value;
        double max_value;
        double default_value;
        std::atomic<double> current_value;
        uint32_t flags;  // CLAP_PARAM_IS_AUTOMATABLE, etc.

        Parameter(clap_id id, const char* name, const char* module,
                  double min, double max, double default_val, uint32_t flags = 0)
            : id(id), name(name), module(module),
              min_value(min), max_value(max), default_value(default_val),
              current_value(default_val), flags(flags | CLAP_PARAM_IS_AUTOMATABLE) {}
    };

    std::vector<Parameter> parameters_;

    // Parameter IDs
    enum ParamID : clap_id {
        PARAM_MASTER_VOLUME = 0,
        PARAM_MASTER_PAN = 1,
        PARAM_TRACK_1_VOLUME = 100,
        PARAM_TRACK_1_PAN = 101,
        // ... more track parameters
        PARAM_EQ_LOW = 200,
        PARAM_EQ_MID = 201,
        PARAM_EQ_HIGH = 202,
        PARAM_COMPRESSOR_THRESHOLD = 300,
        PARAM_COMPRESSOR_RATIO = 301,
        PARAM_COMPRESSOR_ATTACK = 302,
        PARAM_COMPRESSOR_RELEASE = 303,
        PARAM_REVERB_MIX = 400,
        PARAM_REVERB_SIZE = 401,
        PARAM_REVERB_DAMPING = 402,
    };

    // Initialize parameters
    void init_parameters();

    // Process MIDI events
    void process_note_events(const clap_input_events_t* events);
    void process_param_events(const clap_input_events_t* events);

    // Request host to rescan parameters/ports
    void request_rescan_parameters();
    void request_rescan_audio_ports();
};

// ==============================================================================
// CLAP Extension Implementations
// ==============================================================================

// Audio Ports extension
static const clap_plugin_audio_ports_t s_audio_ports_extension = {
    // count
    [](const clap_plugin_t* plugin, bool is_input) -> uint32_t {
        auto* p = static_cast<EchoelmusicClapPlugin*>(plugin->plugin_data);
        return p->audio_ports_count(is_input);
    },
    // get
    [](const clap_plugin_t* plugin, uint32_t index, bool is_input, clap_audio_port_info_t* info) -> bool {
        auto* p = static_cast<EchoelmusicClapPlugin*>(plugin->plugin_data);
        return p->audio_ports_get(index, is_input, info);
    },
};

// Note Ports extension (MIDI)
static const clap_plugin_note_ports_t s_note_ports_extension = {
    // count
    [](const clap_plugin_t* plugin, bool is_input) -> uint32_t {
        auto* p = static_cast<EchoelmusicClapPlugin*>(plugin->plugin_data);
        return p->note_ports_count(is_input);
    },
    // get
    [](const clap_plugin_t* plugin, uint32_t index, bool is_input, clap_note_port_info_t* info) -> bool {
        auto* p = static_cast<EchoelmusicClapPlugin*>(plugin->plugin_data);
        return p->note_ports_get(index, is_input, info);
    },
};

// Parameters extension
static const clap_plugin_params_t s_params_extension = {
    // count
    [](const clap_plugin_t* plugin) -> uint32_t {
        auto* p = static_cast<EchoelmusicClapPlugin*>(plugin->plugin_data);
        return p->params_count();
    },
    // get_info
    [](const clap_plugin_t* plugin, uint32_t param_index, clap_param_info_t* param_info) -> bool {
        auto* p = static_cast<EchoelmusicClapPlugin*>(plugin->plugin_data);
        return p->params_get_info(param_index, param_info);
    },
    // get_value
    [](const clap_plugin_t* plugin, clap_id param_id, double* value) -> bool {
        auto* p = static_cast<EchoelmusicClapPlugin*>(plugin->plugin_data);
        return p->params_get_value(param_id, value);
    },
    // value_to_text
    [](const clap_plugin_t* plugin, clap_id param_id, double value, char* display, uint32_t size) -> bool {
        auto* p = static_cast<EchoelmusicClapPlugin*>(plugin->plugin_data);
        return p->params_value_to_text(param_id, value, display, size);
    },
    // text_to_value
    [](const clap_plugin_t* plugin, clap_id param_id, const char* display, double* value) -> bool {
        auto* p = static_cast<EchoelmusicClapPlugin*>(plugin->plugin_data);
        return p->params_text_to_value(param_id, display, value);
    },
    // flush
    [](const clap_plugin_t* plugin, const clap_input_events_t* in, const clap_output_events_t* out) {
        auto* p = static_cast<EchoelmusicClapPlugin*>(plugin->plugin_data);
        p->params_flush(in, out);
    },
};

// State extension (save/load)
static const clap_plugin_state_t s_state_extension = {
    // save
    [](const clap_plugin_t* plugin, const clap_ostream_t* stream) -> bool {
        auto* p = static_cast<EchoelmusicClapPlugin*>(plugin->plugin_data);
        return p->state_save(stream);
    },
    // load
    [](const clap_plugin_t* plugin, const clap_istream_t* stream) -> bool {
        auto* p = static_cast<EchoelmusicClapPlugin*>(plugin->plugin_data);
        return p->state_load(stream);
    },
};

// Latency extension
static const clap_plugin_latency_t s_latency_extension = {
    // get
    [](const clap_plugin_t* plugin) -> uint32_t {
        auto* p = static_cast<EchoelmusicClapPlugin*>(plugin->plugin_data);
        return p->latency_get();
    },
};

// Voice Info extension (polyphony)
static const clap_plugin_voice_info_t s_voice_info_extension = {
    // get
    [](const clap_plugin_t* plugin, clap_voice_info_t* info) -> bool {
        auto* p = static_cast<EchoelmusicClapPlugin*>(plugin->plugin_data);
        return p->voice_info_get(info);
    },
};

// Render extension (offline rendering)
static const clap_plugin_render_t s_render_extension = {
    // has_hard_realtime_requirement
    [](const clap_plugin_t* plugin) -> bool {
        auto* p = static_cast<EchoelmusicClapPlugin*>(plugin->plugin_data);
        return p->render_has_hard_realtime_requirement();
    },
    // set
    [](const clap_plugin_t* plugin, clap_plugin_render_mode mode) -> bool {
        auto* p = static_cast<EchoelmusicClapPlugin*>(plugin->plugin_data);
        return p->render_set(mode);
    },
};

// ==============================================================================
// Plugin Descriptor
// ==============================================================================

static const clap_plugin_descriptor_t s_plugin_descriptor = {
    .clap_version = CLAP_VERSION_INIT,
    .id = "com.echoelmusic.echoelmusic",
    .name = "Echoelmusic",
    .vendor = "Echoelmusic Team",
    .url = "https://echoelmusic.com",
    .manual_url = "https://echoelmusic.com/manual",
    .support_url = "https://echoelmusic.com/support",
    .version = "1.0.0",
    .description = "Professional multimedia production software with AI, medical features, and immersive content support",
    .features = (const char*[]) {
        CLAP_PLUGIN_FEATURE_INSTRUMENT,
        CLAP_PLUGIN_FEATURE_AUDIO_EFFECT,
        CLAP_PLUGIN_FEATURE_NOTE_EFFECT,
        CLAP_PLUGIN_FEATURE_ANALYZER,
        CLAP_PLUGIN_FEATURE_STEREO,
        CLAP_PLUGIN_FEATURE_SURROUND,
        CLAP_PLUGIN_FEATURE_AMBISONIC,
        nullptr
    },
};

// ==============================================================================
// CLAP Plugin Implementation Notes
// ==============================================================================

/*
 * CLAP Advantages:
 *
 * 1. Open Source - No licensing fees (unlike VST3)
 * 2. Modern API - Designed for current audio needs
 * 3. Better Threading - Host controls threading model
 * 4. Polyphonic Expression - Native MPE support
 * 5. Note Expressions - Per-note modulation
 * 6. Modulation System - Flexible modulation routing
 * 7. GUI Agnostic - Use any GUI framework
 * 8. Stable ABI - No version hell
 *
 * Host Support:
 * - Bitwig Studio (native CLAP support)
 * - Reaper (via CLAP extension)
 * - FL Studio (planned)
 * - Ableton Live (community bridge)
 *
 * Building:
 *   git clone https://github.com/free-audio/clap.git
 *   cmake -B build -DCMAKE_BUILD_TYPE=Release
 *   cmake --build build
 *
 * Usage:
 *   Copy .clap file to:
 *   - Windows: C:\Program Files\Common Files\CLAP\
 *   - macOS: /Library/Audio/Plug-Ins/CLAP/
 *   - Linux: ~/.clap/ or /usr/lib/clap/
 */
