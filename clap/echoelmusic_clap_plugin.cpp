/*
 * Echoelmusic CLAP Plugin Implementation
 */

#include "echoelmusic_clap_plugin.h"
#include <cstring>
#include <cstdio>
#include <algorithm>

// ==============================================================================
// Constructor / Destructor
// ==============================================================================

EchoelmusicClapPlugin::EchoelmusicClapPlugin(const clap_host_t* host)
    : host_(host)
{
    printf("🎵 Echoelmusic CLAP Plugin created\n");
}

EchoelmusicClapPlugin::~EchoelmusicClapPlugin()
{
    printf("🎵 Echoelmusic CLAP Plugin destroyed\n");
}

// ==============================================================================
// Initialization
// ==============================================================================

bool EchoelmusicClapPlugin::init()
{
    printf("   Initializing plugin...\n");

    // Initialize parameters
    init_parameters();

    // Initialize audio engine (would link to JUCE engine)
    // engine_ = std::make_unique<EchoelmusicAudioEngine>();

    printf("   ✅ Plugin initialized\n");
    return true;
}

void EchoelmusicClapPlugin::destroy()
{
    printf("   Destroying plugin...\n");
    engine_.reset();
}

// ==============================================================================
// Activation
// ==============================================================================

bool EchoelmusicClapPlugin::activate(
    double sample_rate,
    uint32_t min_frames_count,
    uint32_t max_frames_count)
{
    printf("   Activating:\n");
    printf("      Sample rate: %.0f Hz\n", sample_rate);
    printf("      Min frames: %u\n", min_frames_count);
    printf("      Max frames: %u\n", max_frames_count);

    sample_rate_ = sample_rate;
    max_frames_count_ = max_frames_count;

    // Calculate latency
    double latency_ms = (max_frames_count / sample_rate) * 1000.0;
    printf("      Latency: %.2f ms\n", latency_ms);

    activated_ = true;
    return true;
}

void EchoelmusicClapPlugin::deactivate()
{
    printf("   Deactivating plugin...\n");
    activated_ = false;
}

// ==============================================================================
// Processing
// ==============================================================================

bool EchoelmusicClapPlugin::start_processing()
{
    printf("   Starting processing...\n");
    processing_ = true;
    return true;
}

void EchoelmusicClapPlugin::stop_processing()
{
    printf("   Stopping processing...\n");
    processing_ = false;
}

void EchoelmusicClapPlugin::reset()
{
    printf("   Resetting plugin state...\n");
    // Clear audio buffers, reset DSP state, etc.
}

clap_process_status EchoelmusicClapPlugin::process(const clap_process_t* process)
{
    // Process input events (MIDI notes, parameter changes)
    if (process->in_events) {
        process_note_events(process->in_events);
        process_param_events(process->in_events);
    }

    // Get audio buffers
    const uint32_t frame_count = process->frames_count;
    const uint32_t num_inputs = process->audio_inputs_count;
    const uint32_t num_outputs = process->audio_outputs_count;

    // Process audio
    if (num_outputs > 0) {
        auto& output = process->audio_outputs[0];

        // For now: pass through input to output
        if (num_inputs > 0) {
            auto& input = process->audio_inputs[0];

            // Copy input to output (stereo)
            for (uint32_t ch = 0; ch < std::min(input.channel_count, output.channel_count); ++ch) {
                std::memcpy(
                    output.data32[ch],
                    input.data32[ch],
                    frame_count * sizeof(float)
                );
            }
        } else {
            // No input: generate silence
            for (uint32_t ch = 0; ch < output.channel_count; ++ch) {
                std::memset(output.data32[ch], 0, frame_count * sizeof(float));
            }
        }

        // Apply master volume parameter
        double master_volume = parameters_[PARAM_MASTER_VOLUME].current_value.load();
        if (master_volume != 1.0) {
            for (uint32_t ch = 0; ch < output.channel_count; ++ch) {
                for (uint32_t i = 0; i < frame_count; ++i) {
                    output.data32[ch][i] *= static_cast<float>(master_volume);
                }
            }
        }
    }

    // Output events (e.g., MIDI out, parameter changes)
    // if (process->out_events) { ... }

    return CLAP_PROCESS_CONTINUE;
}

// ==============================================================================
// Audio Ports
// ==============================================================================

uint32_t EchoelmusicClapPlugin::audio_ports_count(bool is_input) const
{
    // 1 stereo input, 1 stereo output
    return 1;
}

bool EchoelmusicClapPlugin::audio_ports_get(
    uint32_t index,
    bool is_input,
    clap_audio_port_info_t* info) const
{
    if (index != 0)
        return false;

    info->id = is_input ? 0 : 1;
    std::snprintf(info->name, sizeof(info->name), "%s", is_input ? "Audio In" : "Audio Out");
    info->flags = CLAP_AUDIO_PORT_IS_MAIN;
    info->channel_count = 2;  // Stereo
    info->port_type = CLAP_PORT_STEREO;
    info->in_place_pair = is_input ? 1 : 0;  // Can process in-place

    return true;
}

// ==============================================================================
// Note Ports (MIDI)
// ==============================================================================

uint32_t EchoelmusicClapPlugin::note_ports_count(bool is_input) const
{
    return 1;  // 1 MIDI input, 1 MIDI output
}

bool EchoelmusicClapPlugin::note_ports_get(
    uint32_t index,
    bool is_input,
    clap_note_port_info_t* info) const
{
    if (index != 0)
        return false;

    info->id = is_input ? 0 : 1;
    std::snprintf(info->name, sizeof(info->name), "%s", is_input ? "MIDI In" : "MIDI Out");
    info->supported_dialects =
        CLAP_NOTE_DIALECT_CLAP |       // Native CLAP notes
        CLAP_NOTE_DIALECT_MIDI |       // MIDI 1.0
        CLAP_NOTE_DIALECT_MIDI_MPE;    // MIDI Polyphonic Expression
    info->preferred_dialect = CLAP_NOTE_DIALECT_CLAP;

    return true;
}

// ==============================================================================
// Parameters
// ==============================================================================

void EchoelmusicClapPlugin::init_parameters()
{
    // Master parameters
    parameters_.emplace_back(PARAM_MASTER_VOLUME, "Master Volume", "Master", 0.0, 2.0, 1.0,
                             CLAP_PARAM_IS_AUTOMATABLE | CLAP_PARAM_IS_MODULATABLE);
    parameters_.emplace_back(PARAM_MASTER_PAN, "Master Pan", "Master", -1.0, 1.0, 0.0,
                             CLAP_PARAM_IS_AUTOMATABLE | CLAP_PARAM_IS_MODULATABLE);

    // Track 1 parameters
    parameters_.emplace_back(PARAM_TRACK_1_VOLUME, "Track 1 Volume", "Track 1", 0.0, 2.0, 1.0,
                             CLAP_PARAM_IS_AUTOMATABLE | CLAP_PARAM_IS_MODULATABLE);
    parameters_.emplace_back(PARAM_TRACK_1_PAN, "Track 1 Pan", "Track 1", -1.0, 1.0, 0.0,
                             CLAP_PARAM_IS_AUTOMATABLE | CLAP_PARAM_IS_MODULATABLE);

    // EQ parameters
    parameters_.emplace_back(PARAM_EQ_LOW, "EQ Low", "EQ", -12.0, 12.0, 0.0,
                             CLAP_PARAM_IS_AUTOMATABLE | CLAP_PARAM_IS_MODULATABLE);
    parameters_.emplace_back(PARAM_EQ_MID, "EQ Mid", "EQ", -12.0, 12.0, 0.0,
                             CLAP_PARAM_IS_AUTOMATABLE | CLAP_PARAM_IS_MODULATABLE);
    parameters_.emplace_back(PARAM_EQ_HIGH, "EQ High", "EQ", -12.0, 12.0, 0.0,
                             CLAP_PARAM_IS_AUTOMATABLE | CLAP_PARAM_IS_MODULATABLE);

    // Compressor parameters
    parameters_.emplace_back(PARAM_COMPRESSOR_THRESHOLD, "Compressor Threshold", "Compressor",
                             -60.0, 0.0, -10.0, CLAP_PARAM_IS_AUTOMATABLE);
    parameters_.emplace_back(PARAM_COMPRESSOR_RATIO, "Compressor Ratio", "Compressor",
                             1.0, 20.0, 4.0, CLAP_PARAM_IS_AUTOMATABLE);
    parameters_.emplace_back(PARAM_COMPRESSOR_ATTACK, "Compressor Attack", "Compressor",
                             0.1, 100.0, 10.0, CLAP_PARAM_IS_AUTOMATABLE);
    parameters_.emplace_back(PARAM_COMPRESSOR_RELEASE, "Compressor Release", "Compressor",
                             10.0, 1000.0, 100.0, CLAP_PARAM_IS_AUTOMATABLE);

    // Reverb parameters
    parameters_.emplace_back(PARAM_REVERB_MIX, "Reverb Mix", "Reverb", 0.0, 1.0, 0.3,
                             CLAP_PARAM_IS_AUTOMATABLE | CLAP_PARAM_IS_MODULATABLE);
    parameters_.emplace_back(PARAM_REVERB_SIZE, "Reverb Size", "Reverb", 0.0, 1.0, 0.5,
                             CLAP_PARAM_IS_AUTOMATABLE | CLAP_PARAM_IS_MODULATABLE);
    parameters_.emplace_back(PARAM_REVERB_DAMPING, "Reverb Damping", "Reverb", 0.0, 1.0, 0.5,
                             CLAP_PARAM_IS_AUTOMATABLE | CLAP_PARAM_IS_MODULATABLE);

    printf("   ✅ Initialized %zu parameters\n", parameters_.size());
}

uint32_t EchoelmusicClapPlugin::params_count() const
{
    return static_cast<uint32_t>(parameters_.size());
}

bool EchoelmusicClapPlugin::params_get_info(
    uint32_t param_index,
    clap_param_info_t* param_info) const
{
    if (param_index >= parameters_.size())
        return false;

    const auto& param = parameters_[param_index];

    param_info->id = param.id;
    std::snprintf(param_info->name, sizeof(param_info->name), "%s", param.name.c_str());
    std::snprintf(param_info->module, sizeof(param_info->module), "%s", param.module.c_str());
    param_info->min_value = param.min_value;
    param_info->max_value = param.max_value;
    param_info->default_value = param.default_value;
    param_info->flags = param.flags;
    param_info->cookie = nullptr;

    return true;
}

bool EchoelmusicClapPlugin::params_get_value(clap_id param_id, double* value) const
{
    for (const auto& param : parameters_) {
        if (param.id == param_id) {
            *value = param.current_value.load();
            return true;
        }
    }
    return false;
}

bool EchoelmusicClapPlugin::params_value_to_text(
    clap_id param_id,
    double value,
    char* display,
    uint32_t size) const
{
    // Format parameter value as text
    std::snprintf(display, size, "%.2f", value);
    return true;
}

bool EchoelmusicClapPlugin::params_text_to_value(
    clap_id param_id,
    const char* display,
    double* value) const
{
    // Parse text to parameter value
    *value = std::atof(display);
    return true;
}

void EchoelmusicClapPlugin::params_flush(
    const clap_input_events_t* in,
    const clap_output_events_t* out)
{
    // Process parameter changes
    process_param_events(in);
}

// ==============================================================================
// Event Processing
// ==============================================================================

void EchoelmusicClapPlugin::process_note_events(const clap_input_events_t* events)
{
    const uint32_t event_count = events->size(events);

    for (uint32_t i = 0; i < event_count; ++i) {
        const clap_event_header_t* header = events->get(events, i);

        if (header->space_id != CLAP_CORE_EVENT_SPACE_ID)
            continue;

        switch (header->type) {
            case CLAP_EVENT_NOTE_ON: {
                auto* note_on = reinterpret_cast<const clap_event_note_t*>(header);
                printf("      MIDI Note On: key=%d velocity=%.2f\n",
                       note_on->key, note_on->velocity);
                // Trigger note in synth engine
                break;
            }

            case CLAP_EVENT_NOTE_OFF: {
                auto* note_off = reinterpret_cast<const clap_event_note_t*>(header);
                printf("      MIDI Note Off: key=%d\n", note_off->key);
                // Release note in synth engine
                break;
            }

            case CLAP_EVENT_NOTE_EXPRESSION: {
                auto* expr = reinterpret_cast<const clap_event_note_expression_t*>(header);
                printf("      Note Expression: key=%d type=%d value=%.2f\n",
                       expr->key, expr->expression_id, expr->value);
                // Apply note expression (MPE, aftertouch, etc.)
                break;
            }
        }
    }
}

void EchoelmusicClapPlugin::process_param_events(const clap_input_events_t* events)
{
    const uint32_t event_count = events->size(events);

    for (uint32_t i = 0; i < event_count; ++i) {
        const clap_event_header_t* header = events->get(events, i);

        if (header->space_id != CLAP_CORE_EVENT_SPACE_ID)
            continue;

        if (header->type == CLAP_EVENT_PARAM_VALUE) {
            auto* param_event = reinterpret_cast<const clap_event_param_value_t*>(header);

            // Update parameter value
            for (auto& param : parameters_) {
                if (param.id == param_event->param_id) {
                    param.current_value.store(param_event->value);
                    break;
                }
            }
        }
    }
}

// ==============================================================================
// State (Save/Load)
// ==============================================================================

bool EchoelmusicClapPlugin::state_save(const clap_ostream_t* stream)
{
    printf("   Saving plugin state...\n");

    // Save all parameter values
    for (const auto& param : parameters_) {
        double value = param.current_value.load();
        int64_t written = stream->write(stream, &value, sizeof(value));
        if (written != sizeof(value))
            return false;
    }

    printf("   ✅ State saved\n");
    return true;
}

bool EchoelmusicClapPlugin::state_load(const clap_istream_t* stream)
{
    printf("   Loading plugin state...\n");

    // Load all parameter values
    for (auto& param : parameters_) {
        double value;
        int64_t read = stream->read(stream, &value, sizeof(value));
        if (read != sizeof(value))
            return false;

        param.current_value.store(value);
    }

    printf("   ✅ State loaded\n");
    return true;
}

// ==============================================================================
// Voice Info (Polyphony)
// ==============================================================================

bool EchoelmusicClapPlugin::voice_info_get(clap_voice_info_t* info)
{
    info->voice_count = 128;  // 128-voice polyphony
    info->voice_capacity = 128;
    info->flags = CLAP_VOICE_INFO_SUPPORTS_OVERLAPPING_NOTES;

    return true;
}

// ==============================================================================
// Latency
// ==============================================================================

uint32_t EchoelmusicClapPlugin::latency_get() const
{
    // Return latency in samples
    // For ultra-low latency: <2ms @ 48kHz = ~96 samples
    return 96;
}

// ==============================================================================
// Render (Offline)
// ==============================================================================

bool EchoelmusicClapPlugin::render_has_hard_realtime_requirement()
{
    return false;  // Can run offline
}

bool EchoelmusicClapPlugin::render_set(clap_plugin_render_mode mode)
{
    printf("   Render mode: %d\n", mode);
    return true;
}

// ==============================================================================
// Plugin Factory
// ==============================================================================

extern "C" {

static const clap_plugin_t* plugin_factory_create_plugin(
    const clap_plugin_factory_t* factory,
    const clap_host_t* host,
    const char* plugin_id)
{
    if (std::strcmp(plugin_id, s_plugin_descriptor.id) != 0)
        return nullptr;

    auto* plugin = new EchoelmusicClapPlugin(host);

    // Create CLAP plugin structure
    auto* clap_plugin = new clap_plugin_t;
    clap_plugin->desc = &s_plugin_descriptor;
    clap_plugin->plugin_data = plugin;

    // Implement CLAP plugin interface
    clap_plugin->init = [](const clap_plugin_t* p) -> bool {
        return static_cast<EchoelmusicClapPlugin*>(p->plugin_data)->init();
    };

    clap_plugin->destroy = [](const clap_plugin_t* p) {
        auto* plugin = static_cast<EchoelmusicClapPlugin*>(p->plugin_data);
        plugin->destroy();
        delete plugin;
        delete p;
    };

    clap_plugin->activate = [](const clap_plugin_t* p, double sr, uint32_t min_fc, uint32_t max_fc) -> bool {
        return static_cast<EchoelmusicClapPlugin*>(p->plugin_data)->activate(sr, min_fc, max_fc);
    };

    clap_plugin->deactivate = [](const clap_plugin_t* p) {
        static_cast<EchoelmusicClapPlugin*>(p->plugin_data)->deactivate();
    };

    clap_plugin->start_processing = [](const clap_plugin_t* p) -> bool {
        return static_cast<EchoelmusicClapPlugin*>(p->plugin_data)->start_processing();
    };

    clap_plugin->stop_processing = [](const clap_plugin_t* p) {
        static_cast<EchoelmusicClapPlugin*>(p->plugin_data)->stop_processing();
    };

    clap_plugin->reset = [](const clap_plugin_t* p) {
        static_cast<EchoelmusicClapPlugin*>(p->plugin_data)->reset();
    };

    clap_plugin->process = [](const clap_plugin_t* p, const clap_process_t* process) -> clap_process_status {
        return static_cast<EchoelmusicClapPlugin*>(p->plugin_data)->process(process);
    };

    clap_plugin->get_extension = [](const clap_plugin_t* p, const char* id) -> const void* {
        if (std::strcmp(id, CLAP_EXT_AUDIO_PORTS) == 0)
            return &s_audio_ports_extension;
        if (std::strcmp(id, CLAP_EXT_NOTE_PORTS) == 0)
            return &s_note_ports_extension;
        if (std::strcmp(id, CLAP_EXT_PARAMS) == 0)
            return &s_params_extension;
        if (std::strcmp(id, CLAP_EXT_STATE) == 0)
            return &s_state_extension;
        if (std::strcmp(id, CLAP_EXT_LATENCY) == 0)
            return &s_latency_extension;
        if (std::strcmp(id, CLAP_EXT_VOICE_INFO) == 0)
            return &s_voice_info_extension;
        if (std::strcmp(id, CLAP_EXT_RENDER) == 0)
            return &s_render_extension;
        return nullptr;
    };

    clap_plugin->on_main_thread = [](const clap_plugin_t* p) {};

    return clap_plugin;
}

static uint32_t plugin_factory_get_plugin_count(const clap_plugin_factory_t* factory)
{
    return 1;  // One plugin
}

static const clap_plugin_descriptor_t* plugin_factory_get_plugin_descriptor(
    const clap_plugin_factory_t* factory,
    uint32_t index)
{
    return (index == 0) ? &s_plugin_descriptor : nullptr;
}

static const clap_plugin_factory_t s_plugin_factory = {
    .get_plugin_count = plugin_factory_get_plugin_count,
    .get_plugin_descriptor = plugin_factory_get_plugin_descriptor,
    .create_plugin = plugin_factory_create_plugin,
};

// Plugin entry point
CLAP_EXPORT const clap_plugin_entry_t clap_entry = {
    .clap_version = CLAP_VERSION_INIT,
    .init = [](const char* plugin_path) -> bool {
        printf("🎵 Echoelmusic CLAP Plugin Entry\n");
        printf("   Path: %s\n", plugin_path);
        return true;
    },
    .deinit = []() {
        printf("🎵 Echoelmusic CLAP Plugin Exit\n");
    },
    .get_factory = [](const char* factory_id) -> const void* {
        if (std::strcmp(factory_id, CLAP_PLUGIN_FACTORY_ID) == 0)
            return &s_plugin_factory;
        return nullptr;
    },
};

}  // extern "C"
