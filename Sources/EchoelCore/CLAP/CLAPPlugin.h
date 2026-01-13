#pragma once
/**
 * EchoelCore - CLAPPlugin
 *
 * Base class for CLAP plugins with bio-reactive support.
 * Provides the foundation for building Echoelmusic plugins.
 *
 * Based on CLAP specification: https://github.com/free-audio/clap
 * Tutorial reference: https://nakst.gitlab.io/tutorial/clap-part-1.html
 *
 * MIT License - Echoelmusic 2026
 */

#include "../Lock-Free/SPSCQueue.h"
#include "../Bio/BioState.h"
#include "../Bio/BioMapping.h"

#include <string>
#include <vector>
#include <cstring>

// CLAP headers (include from ThirdParty/clap or system)
#ifdef ECHOELCORE_CLAP_INCLUDE
    #include <clap/clap.h>
#else
    // Minimal CLAP type definitions for standalone compilation
    #include "CLAPTypes.h"
#endif

namespace EchoelCore {

//==============================================================================
// Plugin Descriptor
//==============================================================================

struct PluginDescriptor {
    const char* id;          // Reverse domain notation (com.echoelmusic.synth)
    const char* name;
    const char* vendor;
    const char* version;
    const char* description;
    const char* url;
    const char* manualUrl;
    const char* supportUrl;

    bool isInstrument;
    bool hasAudioInput;
    bool hasAudioOutput;
    bool hasNoteInput;
    bool hasNoteOutput;

    // Features (null-terminated array of strings)
    const char* const* features;
};

//==============================================================================
// Parameter Definition
//==============================================================================

struct ParamInfo {
    uint32_t id;
    const char* name;
    const char* module;      // Optional module path (e.g., "Filter/Cutoff")
    float minValue;
    float maxValue;
    float defaultValue;

    bool isAutomatable;
    bool isModulatable;
    bool isPerNote;          // MPE per-note parameter

    // For stepped parameters
    uint32_t stepCount;      // 0 = continuous
};

//==============================================================================
// Audio Port Configuration
//==============================================================================

struct AudioPortConfig {
    const char* name;
    uint32_t channelCount;
    bool isMain;
    bool isCV;               // Control voltage (modular)
};

//==============================================================================
// CLAPPlugin Base Class
//==============================================================================

class CLAPPlugin {
public:
    CLAPPlugin(const PluginDescriptor& desc) noexcept
        : mDescriptor(desc)
        , mSampleRate(48000.0)
        , mMaxBlockSize(512)
        , mIsActive(false)
    {}

    virtual ~CLAPPlugin() = default;

    //==========================================================================
    // Lifecycle (Override in derived class)
    //==========================================================================

    /**
     * Initialize the plugin. Called once after creation.
     */
    virtual bool init() { return true; }

    /**
     * Activate the plugin for processing.
     * @param sampleRate The host sample rate
     * @param minFrames Minimum frames per process call
     * @param maxFrames Maximum frames per process call
     */
    virtual bool activate(double sampleRate, uint32_t minFrames, uint32_t maxFrames) {
        mSampleRate = sampleRate;
        mMaxBlockSize = maxFrames;
        mIsActive = true;
        return true;
    }

    /**
     * Deactivate the plugin.
     */
    virtual void deactivate() {
        mIsActive = false;
    }

    /**
     * Start processing (called before first process after activate)
     */
    virtual bool startProcessing() { return true; }

    /**
     * Stop processing (called before deactivate)
     */
    virtual void stopProcessing() {}

    /**
     * Reset the plugin state (clear delay lines, etc.)
     */
    virtual void reset() {}

    //==========================================================================
    // Audio Processing (Override in derived class)
    //==========================================================================

    /**
     * Process audio.
     * CRITICAL: This runs on the real-time audio thread!
     * - No memory allocation
     * - No locks/mutexes
     * - No I/O operations
     *
     * @param inputs Array of input audio buffers
     * @param outputs Array of output audio buffers
     * @param numFrames Number of samples to process
     */
    virtual void processAudio(
        const float* const* inputs,
        float* const* outputs,
        uint32_t numFrames
    ) = 0;

    /**
     * Process events (MIDI, parameter changes).
     * Called before processAudio with events for this block.
     */
    virtual void processEvents() {
        // Process parameter changes from UI thread
        ParamChange change;
        while (mParamQueue.pop(change)) {
            onParamChange(change.paramId, change.value);
        }

        // Process bio updates
        BioUpdate bioUpdate;
        while (mBioQueue.pop(bioUpdate)) {
            mBioState.update(
                bioUpdate.hrv,
                bioUpdate.coherence,
                bioUpdate.heartRate,
                bioUpdate.breathPhase
            );
        }
    }

    /**
     * Called when a parameter changes.
     */
    virtual void onParamChange(uint32_t paramId, float value) {}

    //==========================================================================
    // Parameters (Override to customize)
    //==========================================================================

    /**
     * Get parameter count.
     */
    virtual uint32_t getParamCount() const { return 0; }

    /**
     * Get parameter info.
     */
    virtual bool getParamInfo(uint32_t index, ParamInfo& info) const {
        return false;
    }

    /**
     * Get parameter value.
     */
    virtual float getParamValue(uint32_t paramId) const { return 0.0f; }

    /**
     * Set parameter value (from audio thread).
     */
    virtual void setParamValue(uint32_t paramId, float value) {}

    //==========================================================================
    // State Serialization
    //==========================================================================

    /**
     * Save plugin state to buffer.
     * @param buffer Output buffer (will be resized)
     * @return true on success
     */
    virtual bool saveState(std::vector<uint8_t>& buffer) const {
        return true;
    }

    /**
     * Load plugin state from buffer.
     * @param buffer Input buffer
     * @return true on success
     */
    virtual bool loadState(const std::vector<uint8_t>& buffer) {
        return true;
    }

    //==========================================================================
    // Bio-Reactive Interface (EchoelCore Extension)
    //==========================================================================

    /**
     * Get the bio state (for audio thread).
     */
    const BioState& getBioState() const noexcept {
        return mBioState;
    }

    /**
     * Get the bio mapper (for audio thread).
     */
    BioMapper& getBioMapper() noexcept {
        return mBioMapper;
    }

    /**
     * Update bio state (from sensor thread).
     * Thread-safe, lock-free.
     */
    void updateBioState(float hrv, float coherence, float heartRate, float breathPhase) {
        mBioQueue.push({hrv, coherence, heartRate, breathPhase, 0});
    }

    /**
     * Get modulated parameter value.
     * Applies bio modulation to base value.
     */
    float getModulatedParam(uint32_t paramId) const noexcept {
        float baseValue = getParamValue(paramId);
        return mBioMapper.computeModulatedValue(paramId, baseValue, mBioState);
    }

    //==========================================================================
    // Thread-Safe Parameter Updates (for UI thread)
    //==========================================================================

    /**
     * Queue a parameter change (from UI thread).
     * Will be processed on next audio callback.
     */
    void queueParamChange(uint32_t paramId, float value) {
        mParamQueue.push({paramId, value, 0});
    }

    //==========================================================================
    // Accessors
    //==========================================================================

    const PluginDescriptor& getDescriptor() const noexcept { return mDescriptor; }
    double getSampleRate() const noexcept { return mSampleRate; }
    uint32_t getMaxBlockSize() const noexcept { return mMaxBlockSize; }
    bool isActive() const noexcept { return mIsActive; }

protected:
    // Plugin info
    PluginDescriptor mDescriptor;

    // Processing state
    double mSampleRate;
    uint32_t mMaxBlockSize;
    bool mIsActive;

    // Lock-free communication
    ParamQueue mParamQueue;
    BioQueue mBioQueue;

    // Bio-reactive state
    BioState mBioState;
    BioMapper mBioMapper;
};

//==============================================================================
// CLAP Entry Point Macro
//==============================================================================

#ifdef ECHOELCORE_CLAP_INCLUDE

/**
 * Use this macro in your plugin's main .cpp file to create the CLAP entry point.
 *
 * Example:
 *   class MySynth : public EchoelCore::CLAPPlugin { ... };
 *   ECHOELCORE_CLAP_ENTRY(MySynth, "com.echoelmusic.mysynth")
 */
#define ECHOELCORE_CLAP_ENTRY(PluginClass, PluginID) \
    static const clap_plugin_descriptor_t s_descriptor = { \
        .clap_version = CLAP_VERSION, \
        .id = PluginID, \
        .name = PluginClass::kName, \
        .vendor = "Echoelmusic", \
        .url = "https://echoelmusic.com", \
        .manual_url = "", \
        .support_url = "", \
        .version = "1.0.0", \
        .description = PluginClass::kDescription, \
        .features = PluginClass::kFeatures \
    }; \
    \
    extern "C" CLAP_EXPORT const clap_plugin_entry_t clap_entry = { \
        .clap_version = CLAP_VERSION, \
        .init = [](const char*) { return true; }, \
        .deinit = []() {}, \
        .get_factory = [](const char* id) -> const void* { \
            if (strcmp(id, CLAP_PLUGIN_FACTORY_ID) == 0) { \
                static const clap_plugin_factory_t factory = { \
                    .get_plugin_count = [](const clap_plugin_factory_t*) { return 1u; }, \
                    .get_plugin_descriptor = [](const clap_plugin_factory_t*, uint32_t) { \
                        return &s_descriptor; \
                    }, \
                    .create_plugin = [](const clap_plugin_factory_t*, \
                                       const clap_host_t* host, \
                                       const char* id) -> const clap_plugin_t* { \
                        /* Plugin creation implementation */ \
                        return nullptr; \
                    } \
                }; \
                return &factory; \
            } \
            return nullptr; \
        } \
    };

#endif // ECHOELCORE_CLAP_INCLUDE

} // namespace EchoelCore
