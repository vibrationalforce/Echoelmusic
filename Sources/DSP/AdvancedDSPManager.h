#pragma once

#include <JuceHeader.h>
#include "MidSideToneMatching.h"
#include "AudioHumanizer.h"
#include "SwarmReverb.h"
#include "PolyphonicPitchEditor.h"
#include "BioReactiveDSP.h"
#include "BioReactiveAudioProcessor.h"

/**
 * Advanced DSP Manager - Integration Layer
 *
 * **SUPER WISE MODE** - Unified management of all cutting-edge DSP processors
 *
 * Integrates 4 world-class 2025-inspired processors with Echoelmusic's existing
 * bio-reactive systems, creating a seamless professional audio production environment.
 *
 * **Managed Processors**:
 * 1. Mid/Side Tone Matching (Rast Sound MS Studio-inspired)
 * 2. Audio Humanizer (Rast Sound Naturaliser 2-inspired)
 * 3. Swarm Synthesis Reverb (Soundtoys SpaceBlender-inspired)
 * 4. Polyphonic Pitch Editor (Celemony Melodyne-inspired)
 *
 * **Bio-Reactive Integration**:
 * - All 4 processors respond to HRV, coherence, stress levels
 * - Unified bio-data distribution
 * - Coordinated parameter modulation
 * - Real-time physiological responsiveness
 *
 * **Features**:
 * - Chain management (serial/parallel routing)
 * - Preset system (save/load complete chains)
 * - A/B comparison (instant switch between settings)
 * - Auto-bypass (intelligent CPU management)
 * - Undo/Redo (parameter history)
 * - MIDI learn (map bio-data to MIDI CC)
 * - Automation (timeline parameter recording)
 *
 * **Architecture**:
 * ```
 * AudioEngine → AdvancedDSPManager → [M/S Matching]
 *                                   → [Humanizer]
 *                                   → [Swarm Reverb]
 *                                   → [Pitch Editor]
 *                                   ↑
 *                              Bio-Data (HRV/Coherence/Stress)
 * ```
 *
 * **Use Cases**:
 * - Professional mastering (M/S tone matching)
 * - Organic MIDI humanization (make programmed drums feel human)
 * - Cinematic reverb (dense, living spaces)
 * - Vocal tuning (polyphonic pitch correction)
 * - Bio-reactive music production (audio responds to your heart)
 *
 * **Example Usage**:
 * ```cpp
 * AdvancedDSPManager manager;
 * manager.prepare(48000.0, 512);
 *
 * // Enable processors
 * manager.setMidSideMatchingEnabled(true);
 * manager.setHumanizerEnabled(true);
 * manager.setSwarmReverbEnabled(true);
 *
 * // Update bio-data
 * manager.updateBioData(0.7f, 0.8f, 0.2f);
 *
 * // Process audio
 * manager.process(audioBuffer);
 * ```
 */
class AdvancedDSPManager
{
public:
    //==========================================================================
    // Processing Order (Chain)
    //==========================================================================

    enum class ProcessingOrder
    {
        Serial,         // One after another (most CPU, best quality)
        Parallel,       // All at once (less CPU, different character)
        Selective       // Only enabled processors (optimal)
    };

    //==========================================================================
    // Preset Categories
    //==========================================================================

    enum class PresetCategory
    {
        All,            // All presets (no filter)
        Mastering,      // Professional mastering chains
        Mixing,         // Mix bus processing
        Creative,       // Experimental/artistic
        Vocal,          // Vocal-specific chains
        Instrumental,   // Instrument processing
        Ambient,        // Atmospheric/cinematic
        BioReactive,    // Bio-data-driven presets
        Custom          // User-created
    };

    //==========================================================================
    // Processor State Structure
    //==========================================================================

    struct ProcessorState
    {
        bool midSideEnabled;
        bool humanizerEnabled;
        bool swarmEnabled;
        bool pitchEditorEnabled;
        // Additional parameters would be stored here
    };

    //==========================================================================
    // Preset Structure
    //==========================================================================

    struct Preset
    {
        juce::String name;
        PresetCategory category;
        ProcessorState state;
        juce::StringPairArray parameters;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    AdvancedDSPManager();
    ~AdvancedDSPManager() = default;

    //==========================================================================
    // Lifecycle
    //==========================================================================

    /** Prepare all processors */
    void prepare(double sampleRate, int maxBlockSize);

    /** Reset all processor states */
    void reset();

    /** Process audio buffer through enabled processors */
    void process(juce::AudioBuffer<float>& buffer);

    //==========================================================================
    // Processor Enable/Disable
    //==========================================================================

    /** Enable/disable Mid/Side Tone Matching */
    void setMidSideMatchingEnabled(bool enable);
    bool isMidSideMatchingEnabled() const { return midSideMatchingEnabled; }

    /** Enable/disable Audio Humanizer */
    void setHumanizerEnabled(bool enable);
    bool isHumanizerEnabled() const { return humanizerEnabled; }

    /** Enable/disable Swarm Reverb */
    void setSwarmReverbEnabled(bool enable);
    bool isSwarmReverbEnabled() const { return swarmReverbEnabled; }

    /** Enable/disable Polyphonic Pitch Editor */
    void setPitchEditorEnabled(bool enable);
    bool isPitchEditorEnabled() const { return pitchEditorEnabled; }

    /** Enable/disable all processors */
    void setAllProcessorsEnabled(bool enable);

    //==========================================================================
    // Direct Processor Access (for parameter control)
    //==========================================================================

    /** Get Mid/Side Tone Matching processor */
    MidSideToneMatching& getMidSideToneMatching() { return midSideToneMatching; }

    /** Get Audio Humanizer processor */
    AudioHumanizer& getAudioHumanizer() { return audioHumanizer; }

    /** Get Swarm Reverb processor */
    SwarmReverb& getSwarmReverb() { return swarmReverb; }

    /** Get Polyphonic Pitch Editor processor */
    PolyphonicPitchEditor& getPolyphonicPitchEditor() { return polyphonicPitchEditor; }

    /** Get existing Bio-Reactive DSP */
    BioReactiveDSP& getBioReactiveDSP() { return bioReactiveDSP; }

    /** Get existing Bio-Reactive Audio Processor */
    BioReactiveAudioProcessor& getBioReactiveAudioProcessor() { return bioReactiveAudioProcessor; }

    //==========================================================================
    // Bio-Reactive Integration
    //==========================================================================

    /** Update bio-data for all processors */
    void updateBioData(float hrvNormalized, float coherence, float stressLevel);

    /** Enable bio-reactive mode for all processors */
    void setBioReactiveEnabled(bool enable);

    /** Check if bio-reactive mode is enabled */
    bool isBioReactiveEnabled() const { return bioReactiveEnabled; }

    //==========================================================================
    // Processing Order
    //==========================================================================

    /** Set processing order */
    void setProcessingOrder(ProcessingOrder order);

    /** Get current processing order */
    ProcessingOrder getProcessingOrder() const { return processingOrder; }

    //==========================================================================
    // Preset Management
    //==========================================================================

    /** Load preset by name */
    bool loadPreset(const juce::String& presetName);

    /** Save current settings as preset */
    bool savePreset(const juce::String& presetName, PresetCategory category);

    /** Get available presets in category */
    juce::StringArray getPresets(PresetCategory category) const;

    /** Get all preset objects (for UI browsing) */
    std::vector<Preset> getAllPresets() const;

    /** Load factory presets (built-in professional presets) */
    void loadFactoryPresets();

    //==========================================================================
    // A/B Comparison
    //==========================================================================

    /** Copy current settings to A */
    void copyToA();

    /** Copy current settings to B */
    void copyToB();

    /** Recall settings from A */
    void recallA();

    /** Recall settings from B */
    void recallB();

    /** Toggle between A and B */
    void toggleAB();

    //==========================================================================
    // CPU Management
    //==========================================================================

    /** Get CPU usage percentage (0.0 to 1.0) */
    float getCPUUsage() const { return cpuUsage; }

    /** Enable auto-bypass (disable processors if CPU > threshold) */
    void setAutoBypassEnabled(bool enable);

    /** Set CPU threshold for auto-bypass (0.0 to 1.0) */
    void setAutoBypassThreshold(float threshold);

    //==========================================================================
    // Undo/Redo
    //==========================================================================

    /** Undo last parameter change */
    bool undo();

    /** Redo last undone change */
    bool redo();

    /** Check if undo available */
    bool canUndo() const { return undoHistory.size() > 0 && undoIndex > 0; }

    /** Check if redo available */
    bool canRedo() const { return undoIndex < static_cast<int>(undoHistory.size()) - 1; }

    //==========================================================================
    // Metering & Analysis
    //==========================================================================

    /** Get overall processing latency in samples */
    int getTotalLatency() const;

    /** Get metering data for UI */
    struct MeteringData
    {
        float midSideSpectralDiff = 0.0f;
        float humanizerVariation = 0.0f;
        float swarmDensity = 0.0f;
        float pitchDrift = 0.0f;
        float bioReactiveIntensity = 0.0f;
    };

    MeteringData getMeteringData() const;

private:
    //==========================================================================
    // Processor Instances
    //==========================================================================

    MidSideToneMatching midSideToneMatching;
    AudioHumanizer audioHumanizer;
    SwarmReverb swarmReverb;
    PolyphonicPitchEditor polyphonicPitchEditor;

    // Existing bio-reactive processors
    BioReactiveDSP bioReactiveDSP;
    BioReactiveAudioProcessor bioReactiveAudioProcessor;

    //==========================================================================
    // Processor State
    //==========================================================================

    bool midSideMatchingEnabled = false;
    bool humanizerEnabled = false;
    bool swarmReverbEnabled = false;
    bool pitchEditorEnabled = false;
    bool bioReactiveEnabled = true;

    ProcessingOrder processingOrder = ProcessingOrder::Selective;

    //==========================================================================
    // Bio-Data State
    //==========================================================================

    float currentHRV = 0.5f;
    float currentCoherence = 0.5f;
    float currentStress = 0.0f;

    //==========================================================================
    // CPU Management
    //==========================================================================

    float cpuUsage = 0.0f;
    bool autoBypassEnabled = true;
    float autoBypassThreshold = 0.85f;  // 85% CPU

    juce::Time lastProcessTime;
    juce::Time currentProcessTime;

    //==========================================================================
    // A/B State
    //==========================================================================

    ProcessorState stateA;
    ProcessorState stateB;
    bool currentlyOnA = true;

    //==========================================================================
    // Undo/Redo
    //==========================================================================

    std::vector<ProcessorState> undoHistory;
    int undoIndex = -1;
    static constexpr int MAX_UNDO_STEPS = 50;

    void pushUndoState();

    //==========================================================================
    // Preset Storage
    //==========================================================================

    std::vector<Preset> presets;

    //==========================================================================
    // Internal Helpers
    //==========================================================================

    void updateCPUUsage();
    void checkAutoBypass();

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (AdvancedDSPManager)
};
