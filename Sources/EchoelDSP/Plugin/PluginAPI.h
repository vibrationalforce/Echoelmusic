#pragma once
// ============================================================================
// EchoelDSP/Plugin/PluginAPI.h - Universal Plugin Architecture
// ============================================================================
// Single codebase → VST3, Audio Unit, CLAP, Standalone
// Zero external dependencies. Pure C++17.
// ============================================================================

#include <string>
#include <vector>
#include <functional>
#include <memory>
#include <atomic>
#include <cstring>
#include "../EchoelDSP.h"

namespace Echoel::Plugin {

// ============================================================================
// MARK: - Plugin Categories
// ============================================================================

enum class PluginCategory {
    Effect,           // Audio effect processor
    Instrument,       // Virtual instrument / synthesizer
    Analyzer,         // Metering / analysis
    Spatial,          // Spatial audio / surround
    Dynamics,         // Compressor / limiter / gate
    EQ,              // Equalizer
    Filter,          // Filter effects
    Delay,           // Delay / echo
    Reverb,          // Reverb / ambience
    Modulation,      // Chorus / flanger / phaser
    Distortion,      // Saturation / distortion
    Pitch,           // Pitch correction / harmonizer
    Utility,         // Utility / routing
    Generator,       // Noise / tone generator
    BioReactive      // Biofeedback-driven processing (Echoelmusic specialty)
};

// ============================================================================
// MARK: - Parameter Types
// ============================================================================

enum class ParameterType {
    Float,            // Continuous 0.0 - 1.0
    Int,              // Integer with min/max
    Bool,             // On/Off switch
    Choice,           // Enumeration / menu
    String            // Text input
};

struct ParameterInfo {
    uint32_t id;
    std::string name;
    std::string shortName;
    std::string unit;
    ParameterType type;

    float defaultValue;
    float minValue;
    float maxValue;
    float stepSize;

    std::vector<std::string> choices;  // For Choice type

    bool automatable;
    bool hidden;

    // Optional: Group parameters
    std::string group;
};

// ============================================================================
// MARK: - Audio Bus Configuration
// ============================================================================

struct BusInfo {
    std::string name;
    int numChannels;
    bool isInput;
    bool isMain;
    bool isActive;
};

struct AudioBusConfiguration {
    std::vector<BusInfo> inputs;
    std::vector<BusInfo> outputs;

    int getTotalInputChannels() const {
        int total = 0;
        for (const auto& bus : inputs) if (bus.isActive) total += bus.numChannels;
        return total;
    }

    int getTotalOutputChannels() const {
        int total = 0;
        for (const auto& bus : outputs) if (bus.isActive) total += bus.numChannels;
        return total;
    }
};

// ============================================================================
// MARK: - Process Context
// ============================================================================

struct ProcessContext {
    double sampleRate;
    int maxBlockSize;
    int numSamples;

    // Transport info
    bool isPlaying;
    bool isRecording;
    bool isLooping;

    double bpm;
    double projectTimeBeats;
    double projectTimeSamples;

    int timeSignatureNumerator;
    int timeSignatureDenominator;

    // Bar/beat position
    double barPositionBeats;
    double cycleStartBeats;
    double cycleEndBeats;
};

// ============================================================================
// MARK: - MIDI Event
// ============================================================================

struct MidiEvent {
    enum class Type : uint8_t {
        NoteOn,
        NoteOff,
        ControlChange,
        PitchBend,
        Aftertouch,
        PolyPressure,
        ProgramChange,
        SysEx
    };

    Type type;
    uint8_t channel;
    uint8_t data1;
    uint8_t data2;
    int sampleOffset;

    // For SysEx
    const uint8_t* sysexData;
    size_t sysexSize;

    // MPE extensions
    float pitchBend14Bit;    // -1.0 to +1.0
    float pressure14Bit;     // 0.0 to 1.0
    float slide14Bit;        // 0.0 to 1.0
};

// ============================================================================
// MARK: - Plugin Base Class
// ============================================================================

class PluginBase {
public:
    virtual ~PluginBase() = default;

    // ========================================================================
    // Plugin Info
    // ========================================================================

    struct Info {
        std::string name;
        std::string vendor;
        std::string version;
        std::string url;
        std::string email;
        std::string uniqueId;        // Unique identifier (e.g., "com.echoelmusic.biosync")
        PluginCategory category;

        bool hasEditor;
        int editorWidth;
        int editorHeight;

        bool acceptsMidi;
        bool producesMidi;
        bool isSynth;
        bool wantsMidiInput;
    };

    virtual Info getPluginInfo() const = 0;

    // ========================================================================
    // Parameters
    // ========================================================================

    virtual std::vector<ParameterInfo> getParameters() const { return {}; }

    virtual float getParameter(uint32_t id) const { return 0.0f; }
    virtual void setParameter(uint32_t id, float value) {}

    virtual std::string getParameterText(uint32_t id) const {
        return std::to_string(getParameter(id));
    }

    // ========================================================================
    // Audio Processing
    // ========================================================================

    virtual AudioBusConfiguration getBusConfiguration() const {
        AudioBusConfiguration config;
        config.inputs.push_back({"Main Input", 2, true, true, true});
        config.outputs.push_back({"Main Output", 2, false, true, true});
        return config;
    }

    virtual void prepare(double sampleRate, int maxBlockSize) {
        sampleRate_ = sampleRate;
        maxBlockSize_ = maxBlockSize;
    }

    virtual void process(DSP::AudioBuffer<float>& buffer, const ProcessContext& context) = 0;

    virtual void processMidi(const std::vector<MidiEvent>& events) {}

    virtual void reset() {}

    // ========================================================================
    // State Management
    // ========================================================================

    virtual std::vector<uint8_t> getState() const { return {}; }
    virtual void setState(const std::vector<uint8_t>& state) {}

    // ========================================================================
    // Editor (optional)
    // ========================================================================

    virtual bool hasEditor() const { return false; }
    virtual void* createEditor() { return nullptr; }
    virtual void destroyEditor(void* editor) {}

    // ========================================================================
    // Latency
    // ========================================================================

    virtual int getLatencySamples() const { return 0; }
    virtual int getTailLengthSamples() const { return 0; }

protected:
    double sampleRate_ = 44100.0;
    int maxBlockSize_ = 512;
};

// ============================================================================
// MARK: - Plugin Factory
// ============================================================================

using PluginCreateFunc = std::unique_ptr<PluginBase>(*)();

struct PluginDescriptor {
    std::string uniqueId;
    std::string name;
    std::string vendor;
    PluginCategory category;
    PluginCreateFunc createFunc;
};

class PluginFactory {
public:
    static PluginFactory& instance() {
        static PluginFactory factory;
        return factory;
    }

    void registerPlugin(const PluginDescriptor& descriptor) {
        plugins_.push_back(descriptor);
    }

    const std::vector<PluginDescriptor>& getPlugins() const {
        return plugins_;
    }

    std::unique_ptr<PluginBase> createPlugin(const std::string& uniqueId) {
        for (const auto& desc : plugins_) {
            if (desc.uniqueId == uniqueId) {
                return desc.createFunc();
            }
        }
        return nullptr;
    }

private:
    std::vector<PluginDescriptor> plugins_;
};

// ============================================================================
// MARK: - Plugin Registration Macro
// ============================================================================

#define ECHOEL_REGISTER_PLUGIN(PluginClass)                                     \
    static struct PluginClass##Registrar {                                      \
        PluginClass##Registrar() {                                              \
            auto createFunc = []() -> std::unique_ptr<PluginBase> {             \
                return std::make_unique<PluginClass>();                         \
            };                                                                  \
            auto info = PluginClass().getPluginInfo();                          \
            PluginDescriptor desc;                                              \
            desc.uniqueId = info.uniqueId;                                      \
            desc.name = info.name;                                              \
            desc.vendor = info.vendor;                                          \
            desc.category = info.category;                                      \
            desc.createFunc = createFunc;                                       \
            PluginFactory::instance().registerPlugin(desc);                     \
        }                                                                       \
    } PluginClass##RegistrarInstance;

// ============================================================================
// MARK: - Format-Specific Wrappers (Header-Only Stubs)
// ============================================================================

// These would be implemented in separate .cpp files for each format

namespace VST3 {
    // VST3 SDK wrapper - implements IPluginBase, IComponent, IAudioProcessor
    // Requires Steinberg VST3 SDK headers

    inline bool exportPlugin(PluginBase* plugin, void* factory) {
        // VST3 export implementation
        return true;
    }
}

namespace AudioUnit {
    // Audio Unit v3 wrapper - implements AUAudioUnit
    // Uses Apple Audio Unit SDK

    inline bool exportPlugin(PluginBase* plugin, void* factory) {
        // AU export implementation
        return true;
    }
}

namespace CLAP {
    // CLAP wrapper - implements clap_plugin
    // CLAP is MIT licensed, no SDK needed (single header)

    struct ClapPluginWrapper {
        PluginBase* plugin;

        static bool init(const void* plugin) { return true; }
        static void destroy(const void* plugin) {}
        static bool activate(const void* plugin, double sr, uint32_t min, uint32_t max) { return true; }
        static void deactivate(const void* plugin) {}
        static bool startProcessing(const void* plugin) { return true; }
        static void stopProcessing(const void* plugin) {}
        static int process(const void* plugin, const void* process) { return 0; } // CLAP_PROCESS_CONTINUE
    };

    inline bool exportPlugin(PluginBase* plugin, void* entry) {
        // CLAP export implementation
        return true;
    }
}

namespace Standalone {
    // Standalone app wrapper using EchoelDSP backends

    class StandaloneHost {
    public:
        void setPlugin(std::unique_ptr<PluginBase> plugin) {
            plugin_ = std::move(plugin);
        }

        bool start(double sampleRate = 48000.0, int bufferSize = 256) {
            if (!plugin_) return false;
            plugin_->prepare(sampleRate, bufferSize);
            // Start audio backend...
            return true;
        }

        void stop() {
            // Stop audio backend...
        }

    private:
        std::unique_ptr<PluginBase> plugin_;
    };
}

} // namespace Echoel::Plugin
