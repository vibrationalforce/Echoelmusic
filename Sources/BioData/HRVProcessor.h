#pragma once

#include <JuceHeader.h>
#include <vector>
#include <cmath>

//==============================================================================
/**
 * @brief HRV (Heart Rate Variability) Processor
 *
 * Analyzes heart rate data and calculates HRV metrics for bio-reactive audio.
 *
 * Features:
 * - Real-time R-R interval detection
 * - SDNN (Standard Deviation of NN intervals)
 * - RMSSD (Root Mean Square of Successive Differences)
 * - Coherence score (0-1)
 * - Stress index calculation
 * - Frequency domain analysis (LF/HF ratio)
 *
 * Based on standards:
 * - Task Force of ESC/NASPE (1996) - HRV Standards
 * - HeartMath Institute - Coherence measurement
 */
class HRVProcessor
{
public:
    //==============================================================================
    // HRV Metrics Structure

    struct HRVMetrics
    {
        // Time-domain metrics
        float heartRate = 70.0f;           // BPM (beats per minute)
        float hrv = 0.5f;                  // Normalized HRV (0-1)
        float sdnn = 50.0f;                // Standard deviation of NN intervals (ms)
        float rmssd = 42.0f;               // Root mean square of successive differences (ms)

        // Coherence & Stress
        float coherence = 0.5f;            // Coherence score (0-1)
        float stressIndex = 0.5f;          // Stress level (0=calm, 1=stressed)

        // Frequency domain
        float lfPower = 0.0f;              // Low frequency power (0.04-0.15 Hz)
        float hfPower = 0.0f;              // High frequency power (0.15-0.4 Hz)
        float lfhfRatio = 1.0f;            // LF/HF ratio (autonomic balance)

        // State
        bool isValid = false;              // Data quality flag
        int sampleCount = 0;               // Number of R-R intervals processed
    };

    //==============================================================================
    HRVProcessor()
    {
        reset();
    }

    void reset()
    {
        rrIntervals.clear();
        currentMetrics = HRVMetrics();
        lastPeakTime = 0.0;
    }

    //==============================================================================
    /**
     * @brief Process incoming heart rate signal
     *
     * @param signal Raw ECG/PPG signal value (-1 to +1)
     * @param deltaTime Time since last sample (in seconds)
     */
    void processSample(float signal, double deltaTime)
    {
        currentTime += deltaTime;

        // Simple R-peak detection (threshold crossing)
        if (signal > peakThreshold && !inPeak)
        {
            inPeak = true;

            if (lastPeakTime > 0.0)
            {
                // Calculate R-R interval (time between beats)
                double rrInterval = (currentTime - lastPeakTime) * 1000.0;  // Convert to ms

                // Validate interval (30-220 BPM range)
                if (rrInterval >= 272.0 && rrInterval <= 2000.0)
                {
                    addRRInterval(static_cast<float>(rrInterval));
                }
            }

            lastPeakTime = currentTime;
        }
        else if (signal < peakThreshold * 0.5f)
        {
            inPeak = false;
        }

        // Update metrics every second
        if (currentTime - lastUpdateTime >= 1.0)
        {
            calculateMetrics();
            lastUpdateTime = currentTime;
        }
    }

    //==============================================================================
    /**
     * @brief Manually add R-R interval (for external heart rate monitors)
     *
     * @param intervalMs R-R interval in milliseconds
     */
    void addRRInterval(float intervalMs)
    {
        rrIntervals.push_back(intervalMs);

        // Keep last 60 seconds of data (assuming ~60-100 BPM)
        if (rrIntervals.size() > maxRRIntervals)
            rrIntervals.erase(rrIntervals.begin());

        // Calculate running metrics
        if (rrIntervals.size() >= minIntervalsForMetrics)
        {
            calculateMetrics();
        }
    }

    //==============================================================================
    /**
     * @brief Get current HRV metrics
     */
    HRVMetrics getMetrics() const
    {
        return currentMetrics;
    }

    //==============================================================================
    /**
     * @brief Set sensitivity for peak detection
     *
     * @param threshold Peak detection threshold (0-1)
     */
    void setPeakThreshold(float threshold)
    {
        peakThreshold = juce::jlimit(0.1f, 0.9f, threshold);
    }

private:
    //==============================================================================
    void calculateMetrics()
    {
        if (rrIntervals.empty())
        {
            currentMetrics.isValid = false;
            return;
        }

        currentMetrics.sampleCount = static_cast<int>(rrIntervals.size());

        // Calculate mean R-R interval
        float sum = 0.0f;
        for (float interval : rrIntervals)
            sum += interval;

        float meanRR = sum / rrIntervals.size();

        // Heart rate (BPM)
        currentMetrics.heartRate = 60000.0f / meanRR;  // Convert ms to BPM

        // SDNN (Standard Deviation of NN intervals)
        float variance = 0.0f;
        for (float interval : rrIntervals)
        {
            float diff = interval - meanRR;
            variance += diff * diff;
        }
        currentMetrics.sdnn = std::sqrt(variance / rrIntervals.size());

        // RMSSD (Root Mean Square of Successive Differences)
        if (rrIntervals.size() > 1)
        {
            float sumSquaredDiffs = 0.0f;
            for (size_t i = 1; i < rrIntervals.size(); ++i)
            {
                float diff = rrIntervals[i] - rrIntervals[i - 1];
                sumSquaredDiffs += diff * diff;
            }
            currentMetrics.rmssd = std::sqrt(sumSquaredDiffs / (rrIntervals.size() - 1));
        }

        // Normalized HRV (0-1 range based on SDNN)
        // Typical SDNN ranges: 20-100ms for adults
        currentMetrics.hrv = juce::jlimit(0.0f, 1.0f, currentMetrics.sdnn / 100.0f);

        // Coherence calculation (simplified HeartMath-style)
        // High coherence = smooth, sine-wave-like HRV pattern
        currentMetrics.coherence = calculateCoherence();

        // Stress index (inverse of HRV)
        // High HRV = low stress, Low HRV = high stress
        currentMetrics.stressIndex = 1.0f - currentMetrics.hrv;

        // Frequency domain analysis (simplified)
        calculateFrequencyMetrics();

        currentMetrics.isValid = true;
    }

    //==============================================================================
    float calculateCoherence()
    {
        if (rrIntervals.size() < 10)
            return 0.5f;

        // Calculate smoothness of HRV pattern
        // High coherence = low variability in successive differences
        float avgDiff = 0.0f;
        for (size_t i = 1; i < rrIntervals.size(); ++i)
        {
            avgDiff += std::abs(rrIntervals[i] - rrIntervals[i - 1]);
        }
        avgDiff /= (rrIntervals.size() - 1);

        // Lower avgDiff = higher coherence
        // Typical range: 10-100ms
        float coherence = 1.0f - juce::jlimit(0.0f, 1.0f, avgDiff / 100.0f);

        return coherence;
    }

    //==============================================================================
    void calculateFrequencyMetrics()
    {
        // Simplified frequency domain analysis
        // Full implementation would use FFT on R-R intervals

        if (rrIntervals.size() < 20)
            return;

        // Estimate LF/HF ratio based on variability patterns
        // Low frequency (0.04-0.15 Hz) - sympathetic + parasympathetic
        // High frequency (0.15-0.4 Hz) - parasympathetic (breathing)

        // Calculate variance in different time windows
        float lfVariance = 0.0f;
        float hfVariance = 0.0f;

        // LF: look at slower changes (10-25 beat window)
        if (rrIntervals.size() >= 25)
        {
            for (size_t i = 10; i < rrIntervals.size() - 10; i += 10)
            {
                float mean = 0.0f;
                for (size_t j = i; j < i + 10; ++j)
                    mean += rrIntervals[j];
                mean /= 10.0f;

                for (size_t j = i; j < i + 10; ++j)
                {
                    float diff = rrIntervals[j] - mean;
                    lfVariance += diff * diff;
                }
            }
        }

        // HF: look at faster changes (3-5 beat window, breathing rate)
        for (size_t i = 3; i < rrIntervals.size(); i += 3)
        {
            float mean = 0.0f;
            for (size_t j = i; j < juce::jmin(i + 3, rrIntervals.size()); ++j)
                mean += rrIntervals[j];
            mean /= 3.0f;

            for (size_t j = i; j < juce::jmin(i + 3, rrIntervals.size()); ++j)
            {
                float diff = rrIntervals[j] - mean;
                hfVariance += diff * diff;
            }
        }

        currentMetrics.lfPower = lfVariance;
        currentMetrics.hfPower = hfVariance;

        // LF/HF ratio (autonomic balance)
        if (hfVariance > 0.0001f)
            currentMetrics.lfhfRatio = lfVariance / hfVariance;
        else
            currentMetrics.lfhfRatio = 1.0f;
    }

    //==============================================================================
    // Parameters
    float peakThreshold = 0.6f;
    static constexpr size_t maxRRIntervals = 100;      // ~60-100 seconds of data
    static constexpr size_t minIntervalsForMetrics = 5;

    // State
    std::vector<float> rrIntervals;
    HRVMetrics currentMetrics;

    double currentTime = 0.0;
    double lastPeakTime = 0.0;
    double lastUpdateTime = 0.0;
    bool inPeak = false;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(HRVProcessor)
};

//==============================================================================
/**
 * @brief Bio-Data Input Manager
 *
 * Handles input from various bio-sensors:
 * - Bluetooth HR monitors (Polar, Wahoo, etc.)
 * - Apple Watch / Fitbit
 * - Muse EEG headband
 * - Empatica E4 wristband
 * - WebSocket/OSC input
 * - Simulated data (for testing)
 */
class BioDataInput
{
public:
    enum class SourceType
    {
        None,
        Simulated,      // Sine wave simulation
        BluetoothHR,    // Bluetooth heart rate monitor
        AppleWatch,     // Apple Watch (HealthKit)
        WebSocket,      // WebSocket server
        OSC,            // OSC (Open Sound Control)
        Serial          // Serial port (Arduino, etc.)
    };

    struct BioDataSample
    {
        float heartRate = 0.0f;
        float hrv = 0.0f;
        float coherence = 0.0f;
        float stressIndex = 0.0f;
        double timestamp = 0.0;
        bool isValid = false;
    };

    //==============================================================================
    BioDataInput()
    {
        setSource(SourceType::Simulated);
    }

    void setSource(SourceType type)
    {
        sourceType = type;

        switch (type)
        {
            case SourceType::Simulated:
                startSimulation();
                break;

            case SourceType::BluetoothHR:
                // TODO: Initialize Bluetooth
                break;

            case SourceType::AppleWatch:
                // TODO: Initialize HealthKit
                break;

            case SourceType::WebSocket:
                // TODO: Start WebSocket server
                break;

            default:
                break;
        }
    }

    SourceType getSource() const
    {
        return sourceType;
    }

    //==============================================================================
    /**
     * @brief Get current bio-data sample
     */
    BioDataSample getCurrentSample()
    {
        if (sourceType == SourceType::Simulated)
            return generateSimulatedData();

        return lastSample;
    }

    //==============================================================================
    /**
     * @brief Update simulation parameters
     */
    void setSimulationParameters(float baseHR, float hrvAmount, float coherenceLevel)
    {
        simulatedHeartRate = juce::jlimit(40.0f, 200.0f, baseHR);
        simulatedHRV = juce::jlimit(0.0f, 1.0f, hrvAmount);
        simulatedCoherence = juce::jlimit(0.0f, 1.0f, coherenceLevel);
    }

private:
    //==============================================================================
    void startSimulation()
    {
        simulationTime = 0.0;
    }

    BioDataSample generateSimulatedData()
    {
        BioDataSample sample;

        // Advance simulation time
        simulationTime += 0.033;  // ~30 Hz update rate

        // Simulate breathing pattern (0.25 Hz = 15 breaths/min)
        float breathingPhase = std::sin(simulationTime * juce::MathConstants<float>::twoPi * 0.25f);

        // Simulate heart rate with breathing modulation
        sample.heartRate = simulatedHeartRate + (breathingPhase * 5.0f * simulatedHRV);

        // HRV modulated by coherence
        sample.hrv = simulatedHRV * (0.7f + 0.3f * simulatedCoherence);

        // Coherence with slow drift
        float coherenceDrift = std::sin(simulationTime * 0.1f) * 0.2f;
        sample.coherence = juce::jlimit(0.0f, 1.0f, simulatedCoherence + coherenceDrift);

        // Stress inverse of HRV
        sample.stressIndex = 1.0f - sample.hrv;

        sample.timestamp = simulationTime;
        sample.isValid = true;

        lastSample = sample;
        return sample;
    }

    //==============================================================================
    SourceType sourceType = SourceType::None;
    BioDataSample lastSample;

    // Simulation parameters
    double simulationTime = 0.0;
    float simulatedHeartRate = 70.0f;
    float simulatedHRV = 0.6f;
    float simulatedCoherence = 0.7f;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(BioDataInput)
};
