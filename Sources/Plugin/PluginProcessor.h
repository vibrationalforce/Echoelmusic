#pragma once

#include <JuceHeader.h>
#include "../DSP/BioReactiveDSP.h"  // ✅ Ported to JUCE 7 (2025-11-12)
// #include "../BioData/HRVProcessor.h"  // TODO: Create HRVProcessor when Bio-Data integration is ready

/**
 * Echoelmusic Audio Processor
 *
 * Main plugin processor with bio-reactive audio processing.
 * Integrates heart rate variability (HRV) and coherence data
 * to modulate audio parameters in real-time.
 *
 * Features:
 * - Real-time bio-data processing
 * - VST3/AU/CLAP plugin support
 * - Sample-accurate parameter automation
 * - MIDI integration (heartbeat sync)
 * - Professional DSP effects
 * - Low-latency (<5ms target)
 */
class EchoelmusicAudioProcessor : public juce::AudioProcessor,
                                   public juce::AudioProcessorValueTreeState::Listener
{
public:
    //==============================================================================
    EchoelmusicAudioProcessor();
    ~EchoelmusicAudioProcessor() override;

    //==============================================================================
    // Audio Processing
    void prepareToPlay (double sampleRate, int samplesPerBlock) override;
    void releaseResources() override;

#ifndef JucePlugin_PreferredChannelConfigurations
    bool isBusesLayoutSupported (const BusesLayout& layouts) const override;
#endif

    void processBlock (juce::AudioBuffer<float>&, juce::MidiBuffer&) override;

    //==============================================================================
    // Plugin Editor
    juce::AudioProcessorEditor* createEditor() override;
    bool hasEditor() const override;

    //==============================================================================
    // Plugin Info
    const juce::String getName() const override;

    bool acceptsMidi() const override;
    bool producesMidi() const override;
    bool isMidiEffect() const override;
    double getTailLengthSeconds() const override;

    //==============================================================================
    // Programs
    int getNumPrograms() override;
    int getCurrentProgram() override;
    void setCurrentProgram (int index) override;
    const juce::String getProgramName (int index) override;
    void changeProgramName (int index, const juce::String& newName) override;

    //==============================================================================
    // State Save/Load
    void getStateInformation (juce::MemoryBlock& destData) override;
    void setStateInformation (const void* data, int sizeInBytes) override;

    //==============================================================================
    // Bio-Data Integration

    /**
     * Update bio-data values from external source (Swift/HealthKit)
     * Thread-safe method to inject bio-data into the audio thread
     */
    void updateBioData(float hrv, float coherence, float heartRate);

    /**
     * Get current bio-data values
     */
    struct BioData {
        float hrv = 0.5f;
        float coherence = 0.5f;
        float heartRate = 70.0f;
        uint64_t timestamp = 0;
    };

    BioData getCurrentBioData() const;

    //==============================================================================
    // Parameter Management

    juce::AudioProcessorValueTreeState& getParameters() { return parameters; }
    juce::AudioProcessorValueTreeState& getAPVTS() { return parameters; }

    /**
     * Get spectrum data for visualization
     * Returns normalized magnitude values (0.0 to 1.0) for frequency bins
     */
    std::vector<float> getSpectrumData() const;

    // Parameter IDs
    static constexpr const char* PARAM_ID_HRV = "hrv";
    static constexpr const char* PARAM_ID_COHERENCE = "coherence";
    static constexpr const char* PARAM_ID_FILTER_CUTOFF = "filterCutoff";
    static constexpr const char* PARAM_ID_RESONANCE = "resonance";
    static constexpr const char* PARAM_ID_REVERB_MIX = "reverbMix";
    static constexpr const char* PARAM_ID_DELAY_TIME = "delayTime";
    static constexpr const char* PARAM_ID_DISTORTION = "distortion";
    static constexpr const char* PARAM_ID_COMPRESSION = "compression";

private:
    //==============================================================================
    // Parameter Value Tree State
    juce::AudioProcessorValueTreeState parameters;

    // Parameter Listeners
    void parameterChanged(const juce::String& parameterID, float newValue) override;

    // Create Parameter Layout
    static juce::AudioProcessorValueTreeState::ParameterLayout createParameterLayout();

    //==============================================================================
    // DSP Modules
    std::unique_ptr<BioReactiveDSP> bioReactiveDSP;  // ✅ Ported to JUCE 7 (2025-11-12)
    // std::unique_ptr<HRVProcessor> hrvProcessor;  // TODO: Enable when HRVProcessor is implemented

    //==============================================================================
    // Bio-Data
    std::atomic<float> currentHRV { 0.5f };
    std::atomic<float> currentCoherence { 0.5f };
    std::atomic<float> currentHeartRate { 70.0f };
    std::atomic<uint64_t> bioDataTimestamp { 0 };

    //==============================================================================
    // MIDI Generation (Heartbeat sync)
    void generateHeartbeatMIDI(juce::MidiBuffer& midiMessages, int numSamples);

    int samplesUntilNextBeat { 0 };
    double currentSampleRate { 44100.0 };

    //==============================================================================
    // Performance Monitoring
    struct PerformanceStats {
        float cpuUsage = 0.0f;
        float averageLatency = 0.0f;
        int bufferUnderruns = 0;
    };

    PerformanceStats performanceStats;

    //==============================================================================
    // Spectrum Analysis (Lock-Free Communication)
    static constexpr int spectrumSize = 64;
    static constexpr int spectrumFifoSize = 4;

    // Lock-free FIFO for audio thread -> UI thread communication
    juce::AbstractFifo spectrumFifo { spectrumFifoSize };
    std::array<std::array<float, spectrumSize>, spectrumFifoSize> spectrumBuffer;
    mutable std::array<float, spectrumSize> spectrumDataForUI;  // Read by UI thread

    void updateSpectrumData(const juce::AudioBuffer<float>& buffer);

    //==============================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (EchoelmusicAudioProcessor)
};
