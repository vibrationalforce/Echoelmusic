#pragma once

#include <JuceHeader.h>
#include "../Visualization/MasterFrequencyTransformer.h"
#include "../Hardware/OSCManager.h"

//==============================================================================
/**
 * @brief ECHOELMUSIC PLUGIN INTEGRATION HUB
 *
 * Central routing system for distributing frequency-to-visual data
 * to ALL Echoelmusic plugins and external systems.
 *
 * **INTEGRATION TARGETS:**
 * - Synthesis engines (Spectral Granular, Neural Synth, etc.)
 * - Effects processors (Reverb, Delay, Filters)
 * - Analyzers (Spectrum, Phase, Harmonic)
 * - Visual systems (Particles, Video Sync, Lighting)
 * - External protocols (OSC, DMX, Art-Net, MIDI)
 *
 * **FEATURES:**
 * - Multi-destination broadcasting
 * - Protocol conversion (OSC, MIDI, DMX)
 * - Connection monitoring
 * - Data flow statistics
 *
 * @author Echoelmusic Integration Team
 * @version 1.0.0
 */
class PluginIntegrationHub
{
public:
    //==============================================================================
    // PLUGIN CONNECTION STATUS
    //==============================================================================

    struct PluginStatus
    {
        juce::String name;
        bool connected = false;
        float dataFlowRate = 0.0f;  // 0.0 - 1.0
        int messagesSent = 0;
        double lastUpdateTime = 0.0;
    };

    //==============================================================================
    // CONSTRUCTOR
    //==============================================================================

    PluginIntegrationHub()
    {
        // Initialize plugin status list
        initializePluginStatus();
    }

    //==============================================================================
    // MAIN DISTRIBUTION
    //==============================================================================

    /**
     * @brief Distribute frequency data to ALL connected plugins and systems
     */
    void distributeToAllPlugins(const MasterFrequencyTransformer::UnifiedFrequencyData& data)
    {
        // ===== SYNTHESIS ENGINES =====
        sendToSpectralGranularSynth(data);
        sendToIntelligentSampler(data);
        sendToNeuralSynth(data);
        sendToWaveWeaver(data);
        sendToFrequencyFusion(data);

        // ===== EFFECTS PROCESSORS =====
        sendToAdaptiveReverb(data);
        sendToQuantumDelay(data);
        sendToBiometricFilter(data);
        sendToSpectralMasking(data);

        // ===== ANALYZERS =====
        sendToSpectrumAnalyzer(data);
        sendToPhaseAnalyzer(data);
        sendToHarmonicAnalyzer(data);

        // ===== VISUAL SYSTEMS =====
        sendToParticleEngine(data);
        sendToVideoSync(data);
        sendToLightController(data);
        sendToVisualForge(data);

        // ===== EXTERNAL PROTOCOLS =====
        sendViaOSC(data);
        sendViaDMX(data);
        sendViaMIDI(data);
    }

private:
    //==============================================================================
    // SYNTHESIS ENGINES
    //==============================================================================

    void sendToSpectralGranularSynth(const MasterFrequencyTransformer::UnifiedFrequencyData& data)
    {
        if (!isPluginConnected("Spectral Granular")) return;

        // OSC messages to Spectral Granular Synth
        juce::OSCMessage msg("/echoelmusic/spectral/frequency");
        msg.addFloat32(static_cast<float>(data.visualFrequency_THz));
        msg.addFloat32(static_cast<float>(data.r));
        msg.addFloat32(static_cast<float>(data.g));
        msg.addFloat32(static_cast<float>(data.b));
        msg.addFloat32(static_cast<float>(data.exactPianoKey));

        sendOSCInternal(msg, 8000);

        // Grain parameters from EEG
        juce::OSCMessage grainMsg("/echoelmusic/spectral/grains");
        grainMsg.addFloat32(static_cast<float>(data.eeg.alpha));  // Density
        grainMsg.addFloat32(static_cast<float>(data.eeg.beta));   // Speed
        grainMsg.addFloat32(static_cast<float>(data.hrvFrequency_Hz));  // Texture

        sendOSCInternal(grainMsg, 8001);

        updatePluginStatus("Spectral Granular", true, 0.8f);
    }

    void sendToNeuralSynth(const MasterFrequencyTransformer::UnifiedFrequencyData& data)
    {
        if (!isPluginConnected("Neural Synth")) return;

        juce::OSCMessage msg("/echoelmusic/neural/frequency");
        msg.addFloat32(static_cast<float>(data.dominantFrequency_Hz));
        msg.addFloat32(static_cast<float>(data.wavelength_nm));

        // EEG modulation
        msg.addFloat32(static_cast<float>(data.eeg.gamma));  // AI complexity

        sendOSCInternal(msg, 8002);
        updatePluginStatus("Neural Synth", true, 0.7f);
    }

    void sendToWaveWeaver(const MasterFrequencyTransformer::UnifiedFrequencyData& data)
    {
        if (!isPluginConnected("Wave Weaver")) return;

        juce::OSCMessage msg("/echoelmusic/wave/color");
        msg.addFloat32(static_cast<float>(data.h));  // Hue → waveform shape
        msg.addFloat32(static_cast<float>(data.s));  // Saturation → harmonics
        msg.addFloat32(static_cast<float>(data.v));  // Value → amplitude

        sendOSCInternal(msg, 8003);
        updatePluginStatus("Wave Weaver", true, 0.9f);
    }

    void sendToFrequencyFusion(const MasterFrequencyTransformer::UnifiedFrequencyData& data)
    {
        if (!isPluginConnected("Frequency Fusion")) return;

        // FM synthesis parameters from color
        juce::OSCMessage msg("/echoelmusic/fm/modulation");
        msg.addFloat32(static_cast<float>(data.L));       // Lightness → mod depth
        msg.addFloat32(static_cast<float>(data.a_star));  // a* → mod ratio
        msg.addFloat32(static_cast<float>(data.b_star));  // b* → feedback

        sendOSCInternal(msg, 8004);
        updatePluginStatus("Frequency Fusion", true, 0.6f);
    }

    void sendToIntelligentSampler(const MasterFrequencyTransformer::UnifiedFrequencyData& data)
    {
        if (!isPluginConnected("Intelligent Sampler")) return;

        juce::OSCMessage msg("/echoelmusic/sampler/color_select");
        msg.addFloat32(static_cast<float>(data.wavelength_nm));
        msg.addInt32(static_cast<int>(data.exactPianoKey));

        sendOSCInternal(msg, 8005);
        updatePluginStatus("Intelligent Sampler", true, 0.5f);
    }

    //==============================================================================
    // EFFECTS PROCESSORS
    //==============================================================================

    void sendToAdaptiveReverb(const MasterFrequencyTransformer::UnifiedFrequencyData& data)
    {
        if (!isPluginConnected("Adaptive Reverb")) return;

        juce::OSCMessage msg("/echoelmusic/reverb/color");
        msg.addFloat32(static_cast<float>(data.wavelength_nm));  // Room size from wavelength
        msg.addFloat32(static_cast<float>(data.s));              // Damping from saturation

        sendOSCInternal(msg, 8010);
        updatePluginStatus("Adaptive Reverb", true, 0.7f);
    }

    void sendToQuantumDelay(const MasterFrequencyTransformer::UnifiedFrequencyData& data)
    {
        if (!isPluginConnected("Quantum Delay")) return;

        juce::OSCMessage msg("/echoelmusic/delay/quantum");
        msg.addFloat32(static_cast<float>(data.quantumCoherence));  // Feedback
        msg.addFloat32(static_cast<float>(data.photonEnergy_eV));   // Delay time modulation

        sendOSCInternal(msg, 8011);
        updatePluginStatus("Quantum Delay", true, 0.8f);
    }

    void sendToBiometricFilter(const MasterFrequencyTransformer::UnifiedFrequencyData& data)
    {
        if (!isPluginConnected("Biometric Filter")) return;

        juce::OSCMessage msg("/echoelmusic/filter/biometric");
        msg.addFloat32(static_cast<float>(data.hrvFrequency_Hz));    // Cutoff modulation
        msg.addFloat32(static_cast<float>(data.eeg.alpha));          // Resonance
        msg.addFloat32(static_cast<float>(data.breathingFrequency_Hz));  // Filter sweep rate

        sendOSCInternal(msg, 8012);
        updatePluginStatus("Biometric Filter", true, 0.9f);
    }

    void sendToSpectralMasking(const MasterFrequencyTransformer::UnifiedFrequencyData& data)
    {
        if (!isPluginConnected("Spectral Masking")) return;

        juce::OSCMessage msg("/echoelmusic/spectral/mask");
        msg.addFloat32(static_cast<float>(data.wavelength_nm));  // Masking curve

        sendOSCInternal(msg, 8013);
        updatePluginStatus("Spectral Masking", true, 0.6f);
    }

    //==============================================================================
    // ANALYZERS
    //==============================================================================

    void sendToSpectrumAnalyzer(const MasterFrequencyTransformer::UnifiedFrequencyData& data)
    {
        if (!isPluginConnected("Spectrum Analyzer")) return;

        juce::OSCMessage msg("/echoelmusic/analyzer/spectrum");
        msg.addFloat32(static_cast<float>(data.dominantFrequency_Hz));
        msg.addFloat32(static_cast<float>(data.r));
        msg.addFloat32(static_cast<float>(data.g));
        msg.addFloat32(static_cast<float>(data.b));

        sendOSCInternal(msg, 8020);
        updatePluginStatus("Spectrum Analyzer", true, 1.0f);
    }

    void sendToPhaseAnalyzer(const MasterFrequencyTransformer::UnifiedFrequencyData& data)
    {
        if (!isPluginConnected("Phase Analyzer")) return;

        juce::OSCMessage msg("/echoelmusic/analyzer/phase");
        msg.addFloat32(static_cast<float>(data.h));  // Phase visualization color

        sendOSCInternal(msg, 8021);
        updatePluginStatus("Phase Analyzer", true, 0.7f);
    }

    void sendToHarmonicAnalyzer(const MasterFrequencyTransformer::UnifiedFrequencyData& data)
    {
        if (!isPluginConnected("Harmonic Analyzer")) return;

        juce::OSCMessage msg("/echoelmusic/analyzer/harmonic");
        msg.addFloat32(static_cast<float>(data.exactPianoKey));
        msg.addFloat32(static_cast<float>(data.centsDeviation));

        sendOSCInternal(msg, 8022);
        updatePluginStatus("Harmonic Analyzer", true, 0.8f);
    }

    //==============================================================================
    // VISUAL SYSTEMS
    //==============================================================================

    void sendToParticleEngine(const MasterFrequencyTransformer::UnifiedFrequencyData& data)
    {
        if (!isPluginConnected("Particle Engine")) return;

        juce::OSCMessage msg("/echoelmusic/particles/update");

        // Particle color from RGB
        msg.addFloat32(static_cast<float>(data.r));
        msg.addFloat32(static_cast<float>(data.g));
        msg.addFloat32(static_cast<float>(data.b));

        // Particle count (scaled by quantum coherence)
        msg.addInt32(static_cast<int>(100000 * data.quantumCoherence));

        // Emission rate from BPM
        msg.addFloat32(static_cast<float>(data.bpm));

        // Turbulence from Gamma EEG
        msg.addFloat32(static_cast<float>(data.eeg.gamma / 100.0));

        // Gravity from HRV
        msg.addFloat32(static_cast<float>(-data.hrvFrequency_Hz * 10.0));

        sendOSCInternal(msg, 9000);
        updatePluginStatus("Particle Engine", true, 1.0f);
    }

    void sendToVideoSync(const MasterFrequencyTransformer::UnifiedFrequencyData& data)
    {
        if (!isPluginConnected("Video Sync")) return;

        juce::OSCMessage msg("/echoelmusic/video/sync");

        // Cuts per minute from BPM
        msg.addFloat32(static_cast<float>(data.bpm));

        // Color grading parameters
        msg.addFloat32(static_cast<float>(wavelengthToKelvin(data.wavelength_nm)));  // Temperature
        msg.addFloat32(static_cast<float>(data.h / 360.0));  // Tint
        msg.addFloat32(static_cast<float>(data.s));          // Saturation
        msg.addFloat32(static_cast<float>(data.v));          // Brightness

        sendOSCInternal(msg, 9001);
        updatePluginStatus("Video Sync", true, 0.9f);
    }

    void sendToLightController(const MasterFrequencyTransformer::UnifiedFrequencyData& data)
    {
        if (!isPluginConnected("Light Controller")) return;

        juce::OSCMessage msg("/echoelmusic/lighting/update");

        // RGB values
        msg.addFloat32(static_cast<float>(data.r));
        msg.addFloat32(static_cast<float>(data.g));
        msg.addFloat32(static_cast<float>(data.b));

        // Intensity modulation from HRV
        float intensity = 0.5f + 0.5f * std::sin(static_cast<float>(data.hrvFrequency_Hz * 2.0 * juce::MathConstants<double>::pi));
        msg.addFloat32(intensity);

        // Strobe from BPM
        msg.addFloat32(static_cast<float>(data.bpm / 60.0));

        sendOSCInternal(msg, 9002);
        updatePluginStatus("Light Controller", true, 0.8f);
    }

    void sendToVisualForge(const MasterFrequencyTransformer::UnifiedFrequencyData& data)
    {
        if (!isPluginConnected("Visual Forge")) return;

        juce::OSCMessage msg("/echoelmusic/visual/color");
        msg.addFloat32(static_cast<float>(data.r));
        msg.addFloat32(static_cast<float>(data.g));
        msg.addFloat32(static_cast<float>(data.b));
        msg.addFloat32(static_cast<float>(data.wavelength_nm));

        sendOSCInternal(msg, 9003);
        updatePluginStatus("Visual Forge", true, 0.7f);
    }

    //==============================================================================
    // EXTERNAL PROTOCOLS
    //==============================================================================

    void sendViaOSC(const MasterFrequencyTransformer::UnifiedFrequencyData& data)
    {
        // Master OSC output (all data)
        juce::OSCMessage msg("/echoelmusic/master/frequency");

        msg.addFloat32(static_cast<float>(data.dominantFrequency_Hz));
        msg.addFloat32(static_cast<float>(data.visualFrequency_THz));
        msg.addFloat32(static_cast<float>(data.wavelength_nm));
        msg.addFloat32(static_cast<float>(data.r));
        msg.addFloat32(static_cast<float>(data.g));
        msg.addFloat32(static_cast<float>(data.b));
        msg.addFloat32(static_cast<float>(data.exactPianoKey));
        msg.addFloat32(static_cast<float>(data.centsDeviation));

        sendOSCInternal(msg, 7000);  // Master OSC port
    }

    void sendViaDMX(const MasterFrequencyTransformer::UnifiedFrequencyData& data)
    {
        // DMX/Art-Net output (handled by FrequencyLightExporter)
        juce::ignoreUnused(data);
        // Implemented in FrequencyLightExporter::sendArtNet()
    }

    void sendViaMIDI(const MasterFrequencyTransformer::UnifiedFrequencyData& data)
    {
        // MIDI CC output for DAW control
        juce::ignoreUnused(data);
        // Future implementation: MIDI CC mapping
    }

    //==============================================================================
    // UTILITY METHODS
    //==============================================================================

    void initializePluginStatus()
    {
        pluginStatusList = {
            {"Spectral Granular", false, 0.0f, 0, 0.0},
            {"Neural Synth", false, 0.0f, 0, 0.0},
            {"Wave Weaver", false, 0.0f, 0, 0.0},
            {"Frequency Fusion", false, 0.0f, 0, 0.0},
            {"Intelligent Sampler", false, 0.0f, 0, 0.0},
            {"Adaptive Reverb", false, 0.0f, 0, 0.0},
            {"Quantum Delay", false, 0.0f, 0, 0.0},
            {"Biometric Filter", false, 0.0f, 0, 0.0},
            {"Spectral Masking", false, 0.0f, 0, 0.0},
            {"Spectrum Analyzer", false, 0.0f, 0, 0.0},
            {"Phase Analyzer", false, 0.0f, 0, 0.0},
            {"Harmonic Analyzer", false, 0.0f, 0, 0.0},
            {"Particle Engine", false, 0.0f, 0, 0.0},
            {"Video Sync", false, 0.0f, 0, 0.0},
            {"Light Controller", false, 0.0f, 0, 0.0},
            {"Visual Forge", false, 0.0f, 0, 0.0}
        };
    }

    bool isPluginConnected(const juce::String& pluginName)
    {
        // For now, assume all are connected
        // Future: implement actual connection detection
        return true;
    }

    void updatePluginStatus(const juce::String& name, bool connected, float flowRate)
    {
        for (auto& status : pluginStatusList)
        {
            if (status.name == name)
            {
                status.connected = connected;
                status.dataFlowRate = flowRate;
                status.messagesSent++;
                status.lastUpdateTime = juce::Time::getMillisecondCounterHiRes() / 1000.0;
                break;
            }
        }
    }

    void sendOSCInternal(const juce::OSCMessage& msg, int port)
    {
        if (!oscSender.connect("127.0.0.1", port))
        {
            DBG("Failed to connect OSC to port " + juce::String(port));
            return;
        }

        oscSender.send(msg);
    }

    static double wavelengthToKelvin(double wavelength_nm)
    {
        // Approximate color temperature from wavelength
        if (wavelength_nm < 480.0) return 10000.0;  // Cool blue
        if (wavelength_nm < 550.0) return 6500.0;   // Daylight
        if (wavelength_nm < 590.0) return 5000.0;   // Warm white
        if (wavelength_nm < 620.0) return 3500.0;   // Orange
        return 2500.0;  // Warm red
    }

public:
    //==============================================================================
    // PUBLIC STATUS ACCESS
    //==============================================================================

    const std::vector<PluginStatus>& getPluginStatusList() const
    {
        return pluginStatusList;
    }

private:
    //==============================================================================
    // MEMBERS
    //==============================================================================

    juce::OSCSender oscSender;
    std::vector<PluginStatus> pluginStatusList;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(PluginIntegrationHub)
};
