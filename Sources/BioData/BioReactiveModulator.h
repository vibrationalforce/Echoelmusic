#pragma once

#include <JuceHeader.h>
#include "HRVProcessor.h"

//==============================================================================
/**
 * @brief Bio-Reactive Modulator
 *
 * Maps bio-data (HRV, coherence, stress) to audio parameters.
 *
 * Modulation Targets:
 * - Filter cutoff (HRV → brightness)
 * - Reverb mix (Coherence → spaciousness)
 * - Compression ratio (Stress → dynamics)
 * - Delay time (Heart rate → rhythm sync)
 * - Distortion (Stress → intensity)
 * - LFO rate (Breathing rate → modulation speed)
 *
 * Inspired by:
 * - HeartMath Inner Balance app
 * - Muse meditation feedback
 * - Empatica E4 bio-feedback
 */
class BioReactiveModulator
{
public:
    //==============================================================================
    // Modulation Parameters

    struct ModulationSettings
    {
        // HRV → Filter
        bool hrvToFilter = true;
        float hrvFilterAmount = 0.7f;          // 0-1
        float hrvFilterRange = 5000.0f;        // Hz

        // Coherence → Reverb
        bool coherenceToReverb = true;
        float coherenceReverbAmount = 0.8f;    // 0-1

        // Stress → Compression
        bool stressToCompression = true;
        float stressCompressionAmount = 0.6f;  // 0-1

        // Heart Rate → Delay
        bool heartRateToDelay = true;
        float heartRateDelayAmount = 0.5f;     // 0-1

        // Stress → Distortion
        bool stressToDistortion = false;
        float stressDistortionAmount = 0.3f;   // 0-1

        // Breathing → LFO
        bool breathingToLFO = true;
        float breathingLFOAmount = 0.4f;       // 0-1
    };

    struct ModulatedParameters
    {
        float filterCutoff = 1000.0f;          // 20-20000 Hz
        float reverbMix = 0.3f;                // 0-1
        float compressionRatio = 2.0f;         // 1-20
        float delayTime = 500.0f;              // 0-2000 ms
        float distortionAmount = 0.0f;         // 0-1
        float lfoRate = 2.0f;                  // 0.1-20 Hz
    };

    //==============================================================================
    BioReactiveModulator()
    {
        reset();
    }

    void reset()
    {
        smoothedHRV = 0.5f;
        smoothedCoherence = 0.5f;
        smoothedStress = 0.5f;
        smoothedHeartRate = 70.0f;
    }

    //==============================================================================
    /**
     * @brief Process bio-data and generate modulated parameters
     *
     * @param bioData Current bio-data sample
     * @return Modulated audio parameters
     */
    ModulatedParameters process(const BioDataInput::BioDataSample& bioData)
    {
        if (!bioData.isValid)
            return currentParameters;

        // Smooth bio-data (slow attack, slow release)
        const float smoothingFactor = 0.95f;  // Very slow smoothing for stability
        smoothedHRV = smoothedHRV * smoothingFactor + bioData.hrv * (1.0f - smoothingFactor);
        smoothedCoherence = smoothedCoherence * smoothingFactor + bioData.coherence * (1.0f - smoothingFactor);
        smoothedStress = smoothedStress * smoothingFactor + bioData.stressIndex * (1.0f - smoothingFactor);
        smoothedHeartRate = smoothedHeartRate * smoothingFactor + bioData.heartRate * (1.0f - smoothingFactor);

        // Generate modulated parameters
        ModulatedParameters params;

        // HRV → Filter Cutoff
        // High HRV = brighter sound (open filter)
        // Low HRV = darker sound (closed filter)
        if (settings.hrvToFilter)
        {
            float baseFreq = 500.0f;
            float modAmount = settings.hrvFilterAmount * smoothedHRV;
            params.filterCutoff = baseFreq + (modAmount * settings.hrvFilterRange);
            params.filterCutoff = juce::jlimit(20.0f, 20000.0f, params.filterCutoff);
        }

        // Coherence → Reverb Mix
        // High coherence = more spacious (more reverb)
        // Low coherence = drier (less reverb)
        if (settings.coherenceToReverb)
        {
            params.reverbMix = smoothedCoherence * settings.coherenceReverbAmount;
            params.reverbMix = juce::jlimit(0.0f, 1.0f, params.reverbMix);
        }

        // Stress → Compression Ratio
        // High stress = more compression (controlled dynamics)
        // Low stress = less compression (natural dynamics)
        if (settings.stressToCompression)
        {
            float minRatio = 1.0f;
            float maxRatio = 10.0f;
            params.compressionRatio = minRatio + (smoothedStress * settings.stressCompressionAmount * (maxRatio - minRatio));
            params.compressionRatio = juce::jlimit(1.0f, 20.0f, params.compressionRatio);
        }

        // Heart Rate → Delay Time
        // Sync delay time to heart rate (rhythm entrainment)
        if (settings.heartRateToDelay)
        {
            // Convert BPM to milliseconds per beat
            float beatDuration = 60000.0f / smoothedHeartRate;  // ms per beat
            params.delayTime = beatDuration * settings.heartRateDelayAmount;
            params.delayTime = juce::jlimit(10.0f, 2000.0f, params.delayTime);
        }

        // Stress → Distortion
        // High stress = more distortion (intensity)
        if (settings.stressToDistortion)
        {
            params.distortionAmount = smoothedStress * settings.stressDistortionAmount;
            params.distortionAmount = juce::jlimit(0.0f, 1.0f, params.distortionAmount);
        }

        // Breathing Rate → LFO
        // Estimate breathing from HRV patterns (~0.25 Hz = 15 breaths/min)
        if (settings.breathingToLFO)
        {
            float breathingRate = 0.25f;  // Hz (would be extracted from HRV in full implementation)
            params.lfoRate = breathingRate * 4.0f * settings.breathingLFOAmount;
            params.lfoRate = juce::jlimit(0.1f, 20.0f, params.lfoRate);
        }

        currentParameters = params;
        return params;
    }

    //==============================================================================
    /**
     * @brief Get current modulation settings
     */
    ModulationSettings& getSettings()
    {
        return settings;
    }

    /**
     * @brief Get current modulated parameters
     */
    ModulatedParameters getCurrentParameters() const
    {
        return currentParameters;
    }

    //==============================================================================
    /**
     * @brief Get normalized modulation amount for visualization (0-1)
     */
    float getModulationAmount() const
    {
        // Average of all active modulations
        float total = 0.0f;
        int count = 0;

        if (settings.hrvToFilter) { total += smoothedHRV; count++; }
        if (settings.coherenceToReverb) { total += smoothedCoherence; count++; }
        if (settings.stressToCompression) { total += (1.0f - smoothedStress); count++; }

        return count > 0 ? (total / count) : 0.5f;
    }

private:
    //==============================================================================
    ModulationSettings settings;
    ModulatedParameters currentParameters;

    // Smoothed bio-data values
    float smoothedHRV = 0.5f;
    float smoothedCoherence = 0.5f;
    float smoothedStress = 0.5f;
    float smoothedHeartRate = 70.0f;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(BioReactiveModulator)
};

//==============================================================================
/**
 * @brief Complete Bio-Feedback System
 *
 * Integrates:
 * - HRV processing
 * - Bio-data input
 * - Parameter modulation
 */
class BioFeedbackSystem
{
public:
    BioFeedbackSystem()
    {
        bioInput.setSource(BioDataInput::SourceType::Simulated);
        bioInput.setSimulationParameters(70.0f, 0.6f, 0.7f);  // 70 BPM, 60% HRV, 70% coherence
    }

    //==============================================================================
    /**
     * @brief Update system (call from audio thread or timer)
     */
    void update()
    {
        // Get current bio-data
        auto sample = bioInput.getCurrentSample();

        // Process through HRV processor
        if (sample.isValid)
        {
            // Update HRV metrics (would use raw signal in full implementation)
            // For now, use simulated data directly
        }

        // Generate modulated parameters
        modulatedParams = modulator.process(sample);
    }

    //==============================================================================
    /**
     * @brief Get modulated audio parameters
     */
    BioReactiveModulator::ModulatedParameters getModulatedParameters() const
    {
        return modulatedParams;
    }

    /**
     * @brief Get current bio-data
     */
    BioDataInput::BioDataSample getCurrentBioData()
    {
        return bioInput.getCurrentSample();
    }

    /**
     * @brief Get HRV processor
     */
    HRVProcessor& getHRVProcessor()
    {
        return hrvProcessor;
    }

    /**
     * @brief Get bio-data input
     */
    BioDataInput& getBioDataInput()
    {
        return bioInput;
    }

    /**
     * @brief Get modulator
     */
    BioReactiveModulator& getModulator()
    {
        return modulator;
    }

    //==============================================================================
    /**
     * @brief Set input source
     */
    void setInputSource(BioDataInput::SourceType type)
    {
        bioInput.setSource(type);
    }

    /**
     * @brief Set simulation parameters (for testing)
     */
    void setSimulationParameters(float heartRate, float hrv, float coherence)
    {
        bioInput.setSimulationParameters(heartRate, hrv, coherence);
    }

private:
    HRVProcessor hrvProcessor;
    BioDataInput bioInput;
    BioReactiveModulator modulator;
    BioReactiveModulator::ModulatedParameters modulatedParams;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(BioFeedbackSystem)
};
