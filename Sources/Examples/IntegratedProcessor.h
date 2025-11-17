// IntegratedProcessor.h - Complete Integration Example
// Shows how to use all production-ready systems together
#pragma once

#include "../Common/GlobalWarningFixes.h"
#include "../DAW/DAWOptimizer.h"
#include "../Video/VideoSyncEngine.h"
#include "../Lighting/LightController.h"
#include "../Biofeedback/AdvancedBiofeedbackProcessor.h"
#include <JuceHeader.h>

namespace Echoel {

/**
 * COMPLETE INTEGRATION EXAMPLE
 *
 * This shows how to integrate all the new production-ready systems:
 * - Global warning fixes (automatic when including headers)
 * - DAW optimization
 * - Video synchronization
 * - Lighting control
 * - Biofeedback processing
 *
 * Copy this pattern into your PluginProcessor for full functionality!
 */
class IntegratedProcessor : public juce::AudioProcessor,
                            public juce::Timer {
public:
    IntegratedProcessor()
        : AudioProcessor(BusesProperties()
                        .withInput("Input", juce::AudioChannelSet::stereo(), true)
                        .withOutput("Output", juce::AudioChannelSet::stereo(), true)) {

        // Initialize all subsystems
        initializeSubsystems();

        // Start timer for periodic updates (30 Hz for smooth visuals)
        startTimerHz(30);
    }

    ~IntegratedProcessor() override {
        stopTimer();
    }

    //==============================================================================
    void prepareToPlay(double sampleRate, int samplesPerBlock) override {
        currentSampleRate = sampleRate;
        currentBufferSize = samplesPerBlock;

        // Apply DAW-specific optimizations
        if (dawOptimizer) {
            const auto& settings = dawOptimizer->getSettings();

            // Log optimization info
            ECHOEL_TRACE("DAW detected: " << dawOptimizer->getDAWName());
            ECHOEL_TRACE("Optimized buffer size: " << settings.preferredBufferSize);
            ECHOEL_TRACE("MPE enabled: " << settings.enableMPE);

            // You could adjust your processing based on these settings
            if (settings.highPrecisionMode) {
                // Use higher quality processing for Pro Tools
                enableHighQualityMode();
            }
        }

        // Initialize DSP components
        initializeDSP(sampleRate, samplesPerBlock);

        // Set video sync frame rate based on sample rate
        if (videoSync) {
            videoSync->setFrameRate(30.0);  // 30 FPS video
        }
    }

    void releaseResources() override {
        // Clean up resources
    }

    void processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midiMessages) override {
        juce::ScopedNoDenormals noDenormals;
        ECHOEL_UNUSED(midiMessages);  // Using warning-fix macro

        const int totalNumInputChannels = getTotalNumInputChannels();
        const int totalNumOutputChannels = getTotalNumOutputChannels();

        // Clear unused output channels
        for (int i = totalNumInputChannels; i < totalNumOutputChannels; ++i) {
            buffer.clear(i, 0, buffer.getNumSamples());
        }

        // ========== AUDIO ANALYSIS ==========
        AudioAnalysisData analysis = analyzeAudio(buffer);

        // ========== BIOFEEDBACK INTEGRATION ==========
        if (bioProcessor && biofeedbackEnabled) {
            // Get current biometric parameters
            const auto& bioParams = bioProcessor->getParameters();

            // Apply biofeedback to audio processing
            applyBiofeedbackToAudio(buffer, bioParams);

            // Update lighting based on biometric state
            if (lightControl && lightingEnabled) {
                updateLightingFromBiofeedback(bioParams);
            }
        }

        // ========== STANDARD AUDIO PROCESSING ==========
        processAudioEffects(buffer, analysis);

        // ========== STORE ANALYSIS FOR TIMER CALLBACK ==========
        lastAnalysis = analysis;
    }

    //==============================================================================
    // Timer callback for video/lighting updates (30 Hz)
    void timerCallback() override {
        // Update video sync
        if (videoSync && videoSyncEnabled) {
            updateVideoSync(lastAnalysis);
        }

        // Update lighting (if not controlled by biofeedback)
        if (lightControl && lightingEnabled && !biofeedbackEnabled) {
            updateLightingFromAudio(lastAnalysis);
        }

        // Update biofeedback calibration
        if (bioProcessor && bioProcessor->getUserProfile().name != "Default User") {
            // Calibration in progress
            // bioProcessor->updateCalibration(); // Would be called here
        }
    }

    //==============================================================================
    // Public control methods

    void enableVideoSync(bool enable) { videoSyncEnabled = enable; }
    void enableLighting(bool enable) { lightingEnabled = enable; }
    void enableBiofeedback(bool enable) { biofeedbackEnabled = enable; }

    void setVideoSyncBPM(double bpm) {
        if (videoSync) {
            videoSync->setBPM(bpm);
        }
    }

    void startBiofeedbackCalibration() {
        if (bioProcessor) {
            bioProcessor->startCalibration();
            ECHOEL_TRACE("Biofeedback calibration started - 60 seconds");
        }
    }

    // Biofeedback sensor updates (call from external sensor readers)
    void updateHeartRate(float bpm) {
        if (bioProcessor) {
            bioProcessor->updateHeartRate(bpm);
        }
    }

    void updateEEG(float delta, float theta, float alpha, float beta, float gamma) {
        if (bioProcessor) {
            bioProcessor->updateEEG(delta, theta, alpha, beta, gamma);
        }
    }

    void updateGSR(float conductance) {
        if (bioProcessor) {
            bioProcessor->updateGSR(conductance);
        }
    }

    void updateBreathing(float amplitude) {
        if (bioProcessor) {
            bioProcessor->updateBreathing(amplitude);
        }
    }

    // Lighting configuration
    void configureHueBridge(const juce::String& ip, const juce::String& username) {
        if (lightControl) {
            auto* hue = lightControl->getHueBridge();
            hue->setIP(ip);
            hue->setUsername(username);
        }
    }

    void addHueLight(int id, const juce::String& name) {
        if (lightControl) {
            lightControl->getHueBridge()->addLight(id, name);
        }
    }

    void configureWLED(const juce::String& ip) {
        if (lightControl) {
            lightControl->getWLED()->setIP(ip);
        }
    }

    // Status reporting
    juce::String getDAWInfo() const {
        return dawOptimizer ? dawOptimizer->getOptimizationReport() : "Not initialized";
    }

    juce::String getVideoSyncInfo() const {
        return videoSync ? videoSync->getConfigurationInfo() : "Not initialized";
    }

    juce::String getBiofeedbackInfo() const {
        return bioProcessor ? bioProcessor->getStatusReport() : "Not initialized";
    }

    juce::String getLightingInfo() const {
        return lightControl ? lightControl->getStatus() : "Not initialized";
    }

    //==============================================================================
    // Standard AudioProcessor methods

    juce::AudioProcessorEditor* createEditor() override { return nullptr; }
    bool hasEditor() const override { return false; }
    const juce::String getName() const override { return "Integrated Processor"; }
    bool acceptsMidi() const override { return true; }
    bool producesMidi() const override { return true; }
    bool isMidiEffect() const override { return false; }
    double getTailLengthSeconds() const override { return 0.0; }
    int getNumPrograms() override { return 1; }
    int getCurrentProgram() override { return 0; }
    void setCurrentProgram(int index) override { ECHOEL_UNUSED(index); }
    const juce::String getProgramName(int index) override { ECHOEL_UNUSED(index); return {}; }
    void changeProgramName(int index, const juce::String& newName) override {
        ECHOEL_UNUSED_PARAMS(index, newName);
    }

    void getStateInformation(juce::MemoryBlock& destData) override {
        // Save state
        ECHOEL_UNUSED(destData);
    }

    void setStateInformation(const void* data, int sizeInBytes) override {
        // Restore state
        ECHOEL_UNUSED_PARAMS(data, sizeInBytes);
    }

private:
    //==============================================================================
    // Subsystem instances
    std::unique_ptr<DAWOptimizer> dawOptimizer;
    std::unique_ptr<VideoSyncEngine> videoSync;
    std::unique_ptr<AdvancedLightController> lightControl;
    std::unique_ptr<AdvancedBiofeedbackProcessor> bioProcessor;

    // State
    double currentSampleRate{44100.0};
    int currentBufferSize{512};
    bool videoSyncEnabled{false};
    bool lightingEnabled{false};
    bool biofeedbackEnabled{false};

    // Audio analysis data structure
    struct AudioAnalysisData {
        float rmsLevel{0.0f};
        float peakLevel{0.0f};
        float dominantFrequency{440.0f};
        juce::Colour dominantColor{juce::Colours::blue};
        float spectralCentroid{1000.0f};
    };

    AudioAnalysisData lastAnalysis;

    //==============================================================================
    void initializeSubsystems() {
        // DAW Optimizer - auto-detects and optimizes
        dawOptimizer = std::make_unique<DAWOptimizer>();
        dawOptimizer->applyOptimizations();

        // Video Sync Engine
        videoSync = std::make_unique<VideoSyncEngine>();

        // Lighting Control
        lightControl = std::make_unique<AdvancedLightController>();

        // Biofeedback Processor
        bioProcessor = std::make_unique<AdvancedBiofeedbackProcessor>();

        ECHOEL_TRACE("All subsystems initialized successfully");
    }

    void initializeDSP(double sampleRate, int samplesPerBlock) {
        ECHOEL_UNUSED_PARAMS(sampleRate, samplesPerBlock);
        // Initialize your DSP components here
        // Example: filters, delays, reverbs, etc.
    }

    void enableHighQualityMode() {
        // Enable higher quality processing for Pro Tools
        ECHOEL_TRACE("High quality mode enabled for Pro Tools");
    }

    //==============================================================================
    // Audio analysis
    AudioAnalysisData analyzeAudio(const juce::AudioBuffer<float>& buffer) {
        AudioAnalysisData analysis;

        if (buffer.getNumSamples() == 0) return analysis;

        // Calculate RMS and peak levels
        float sumSquares = 0.0f;
        float peak = 0.0f;

        for (int channel = 0; channel < buffer.getNumChannels(); ++channel) {
            const float* channelData = buffer.getReadPointer(channel);

            for (int sample = 0; sample < buffer.getNumSamples(); ++sample) {
                float absValue = std::abs(channelData[sample]);
                sumSquares += channelData[sample] * channelData[sample];
                peak = std::max(peak, absValue);
            }
        }

        int totalSamples = buffer.getNumSamples() * buffer.getNumChannels();
        analysis.rmsLevel = std::sqrt(sumSquares / static_cast<float>(totalSamples));
        analysis.peakLevel = peak;

        // Simplified frequency analysis (in real implementation, use FFT)
        analysis.dominantFrequency = 440.0f + (analysis.rmsLevel * 1000.0f);

        // Map frequency to color
        if (lightControl) {
            analysis.dominantColor = lightControl->frequencyToColor(analysis.dominantFrequency);
        }

        // Spectral centroid (simplified)
        analysis.spectralCentroid = 1000.0f + (analysis.rmsLevel * 2000.0f);

        return analysis;
    }

    //==============================================================================
    // Video sync updates
    void updateVideoSync(const AudioAnalysisData& analysis) {
        videoSync->updateFromAudio(analysis.rmsLevel,
                                  analysis.dominantFrequency,
                                  analysis.dominantColor);
        videoSync->syncToAllTargets();
    }

    //==============================================================================
    // Lighting updates
    void updateLightingFromAudio(const AudioAnalysisData& analysis) {
        lightControl->mapFrequencyToLight(analysis.dominantFrequency,
                                         analysis.rmsLevel);
    }

    void updateLightingFromBiofeedback(const AdvancedBiofeedbackProcessor::AudioParameters& bioParams) {
        // Map biofeedback to lighting
        // Example: Use HRV for color, stress for brightness

        const auto& state = bioProcessor->getState();

        // Map HRV to hue (calm = blue, stressed = red)
        float hue = EchoelDSP::map(state.hrv, 40.0f, 100.0f, 0.0f, 0.66f);  // Red to Blue
        float saturation = state.stressIndex;  // Higher stress = more saturated
        float brightness = state.coherenceScore;  // Higher coherence = brighter

        juce::Colour bioColor = juce::Colour::fromHSV(hue, saturation, brightness, 1.0f);

        // Update Philips Hue lights
        auto* hue = lightControl->getHueBridge();
        for (auto& light : hue->getLights()) {
            light.setColorRGB(bioColor.getFloatRed(),
                             bioColor.getFloatGreen(),
                             bioColor.getFloatBlue());
            light.setBrightness(brightness);
        }
        hue->updateAllLights();
    }

    //==============================================================================
    // Biofeedback audio processing
    void applyBiofeedbackToAudio(juce::AudioBuffer<float>& buffer,
                                 const AdvancedBiofeedbackProcessor::AudioParameters& bioParams) {
        // Apply biofeedback parameters to audio

        // Example: Apply master volume from coherence
        float gain = bioParams.masterVolume;

        for (int channel = 0; channel < buffer.getNumChannels(); ++channel) {
            float* channelData = buffer.getWritePointer(channel);

            for (int sample = 0; sample < buffer.getNumSamples(); ++sample) {
                channelData[sample] *= gain;
            }
        }

        // In a real implementation, you would also apply:
        // - Filter cutoff from bioParams.filterCutoff
        // - Reverb size from bioParams.reverbSize
        // - LFO rate from bioParams.lfoRate
        // - Distortion from bioParams.distortion
        // - etc.
    }

    void processAudioEffects(juce::AudioBuffer<float>& buffer,
                            const AudioAnalysisData& analysis) {
        ECHOEL_UNUSED(analysis);

        // Your standard audio processing here
        // Example: filters, delays, reverbs, compressors, etc.

        // This is where you'd integrate your existing DSP effects
        // from Sources/DSP/ directory
    }

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(IntegratedProcessor)
};

} // namespace Echoel
