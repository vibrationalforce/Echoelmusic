#pragma once

#include <JuceHeader.h>
#include <atomic>
#include <array>
#include <chrono>
#include <deque>
#include <functional>
#include <map>
#include <memory>
#include <mutex>
#include <vector>

namespace Echoelmusic {
namespace Bio {

/**
 * BiofeedbackEngine - Bio-Reactive Music System
 *
 * Supported Sensors:
 * - Heart Rate (HR) - BLE heart rate monitors
 * - Heart Rate Variability (HRV) - Stress/relaxation detection
 * - EEG - Brain wave analysis (Muse, OpenBCI, NeuroSky)
 * - GSR/EDA - Galvanic skin response (emotional arousal)
 * - Respiration - Breathing rate sensors
 * - EMG - Muscle tension sensors
 * - Motion/Accelerometer - Movement detection
 *
 * Features:
 * - Real-time biometric data processing
 * - Emotional state detection
 * - Adaptive music parameter mapping
 * - Meditation/focus mode detection
 * - Stress response analysis
 * - Movement-to-MIDI mapping
 * - Breath-synchronized effects
 */

//==============================================================================
// Biometric Data Types
//==============================================================================

enum class SensorType
{
    HeartRate,
    HRV,
    EEG,
    GSR,
    Respiration,
    EMG,
    Accelerometer,
    Gyroscope,
    Temperature,
    BloodOxygen
};

struct SensorReading
{
    SensorType type;
    double timestamp;           // Seconds since session start
    float value;               // Primary value
    std::vector<float> data;   // Additional channels/data
    float quality;             // Signal quality 0-1
};

//==============================================================================
// EEG Band Powers
//==============================================================================

struct EEGBands
{
    float delta = 0.0f;     // 0.5-4 Hz (deep sleep)
    float theta = 0.0f;     // 4-8 Hz (drowsiness, meditation)
    float alpha = 0.0f;     // 8-13 Hz (relaxed awareness)
    float beta = 0.0f;      // 13-30 Hz (active thinking)
    float gamma = 0.0f;     // 30-100 Hz (higher cognition)

    float total() const { return delta + theta + alpha + beta + gamma; }

    void normalize()
    {
        float t = total();
        if (t > 0.0f)
        {
            delta /= t;
            theta /= t;
            alpha /= t;
            beta /= t;
            gamma /= t;
        }
    }
};

//==============================================================================
// Emotional/Mental States
//==============================================================================

enum class EmotionalState
{
    Neutral,
    Relaxed,
    Focused,
    Excited,
    Stressed,
    Meditative,
    Flow,           // Deep focus/zone
    Fatigued
};

struct MentalState
{
    EmotionalState state = EmotionalState::Neutral;
    float arousal = 0.5f;       // Low to high energy (0-1)
    float valence = 0.5f;       // Negative to positive (0-1)
    float focus = 0.5f;         // Distracted to focused (0-1)
    float relaxation = 0.5f;    // Tense to relaxed (0-1)
    float meditation = 0.0f;    // Meditation depth (0-1)
    float confidence = 0.0f;    // State detection confidence

    juce::String getStateName() const
    {
        switch (state)
        {
            case EmotionalState::Relaxed:    return "Relaxed";
            case EmotionalState::Focused:    return "Focused";
            case EmotionalState::Excited:    return "Excited";
            case EmotionalState::Stressed:   return "Stressed";
            case EmotionalState::Meditative: return "Meditative";
            case EmotionalState::Flow:       return "Flow State";
            case EmotionalState::Fatigued:   return "Fatigued";
            default:                         return "Neutral";
        }
    }
};

//==============================================================================
// Heart Rate Analysis
//==============================================================================

class HeartRateAnalyzer
{
public:
    struct HRVMetrics
    {
        float bpm = 70.0f;              // Beats per minute
        float rrInterval = 857.0f;      // R-R interval in ms
        float rmssd = 0.0f;             // Root mean square of successive differences
        float sdnn = 0.0f;              // Standard deviation of NN intervals
        float pnn50 = 0.0f;             // Percentage of NN50
        float lfPower = 0.0f;           // Low frequency power (0.04-0.15 Hz)
        float hfPower = 0.0f;           // High frequency power (0.15-0.4 Hz)
        float lfHfRatio = 0.0f;         // LF/HF ratio (sympathetic/parasympathetic balance)
        float stressIndex = 0.0f;       // Derived stress level (0-1)
        float coherence = 0.0f;         // Heart rhythm coherence (0-1)
    };

    void addBeat(double timestamp)
    {
        if (lastBeatTime > 0)
        {
            double rrMs = (timestamp - lastBeatTime) * 1000.0;

            if (rrMs > 300.0 && rrMs < 2000.0)  // Valid RR interval
            {
                rrIntervals.push_back(static_cast<float>(rrMs));

                if (rrIntervals.size() > maxIntervals)
                    rrIntervals.pop_front();
            }
        }

        lastBeatTime = timestamp;
        beatCount++;
    }

    void addHeartRate(float bpm)
    {
        if (bpm > 30.0f && bpm < 220.0f)
        {
            float rrMs = 60000.0f / bpm;
            rrIntervals.push_back(rrMs);

            if (rrIntervals.size() > maxIntervals)
                rrIntervals.pop_front();
        }
    }

    HRVMetrics analyze() const
    {
        HRVMetrics metrics;

        if (rrIntervals.size() < 5)
            return metrics;

        // Calculate mean RR interval
        float meanRR = 0.0f;
        for (float rr : rrIntervals)
            meanRR += rr;
        meanRR /= rrIntervals.size();

        metrics.rrInterval = meanRR;
        metrics.bpm = 60000.0f / meanRR;

        // Calculate SDNN
        float variance = 0.0f;
        for (float rr : rrIntervals)
        {
            float diff = rr - meanRR;
            variance += diff * diff;
        }
        metrics.sdnn = std::sqrt(variance / rrIntervals.size());

        // Calculate RMSSD and pNN50
        float sumSquaredDiff = 0.0f;
        int nn50Count = 0;

        for (size_t i = 1; i < rrIntervals.size(); ++i)
        {
            float diff = rrIntervals[i] - rrIntervals[i - 1];
            sumSquaredDiff += diff * diff;

            if (std::abs(diff) > 50.0f)
                nn50Count++;
        }

        metrics.rmssd = std::sqrt(sumSquaredDiff / (rrIntervals.size() - 1));
        metrics.pnn50 = static_cast<float>(nn50Count) / (rrIntervals.size() - 1) * 100.0f;

        // Estimate stress index (simplified Baevsky stress index)
        float mode = meanRR;
        float amo = 50.0f / (metrics.sdnn + 1.0f);  // Amplitude of mode
        metrics.stressIndex = amo / (2.0f * mode / 1000.0f);
        metrics.stressIndex = std::min(1.0f, metrics.stressIndex / 500.0f);

        // Estimate coherence (simplified)
        metrics.coherence = std::min(1.0f, metrics.rmssd / 100.0f);

        return metrics;
    }

    void reset()
    {
        rrIntervals.clear();
        lastBeatTime = 0;
        beatCount = 0;
    }

private:
    std::deque<float> rrIntervals;
    double lastBeatTime = 0;
    uint64_t beatCount = 0;
    static constexpr size_t maxIntervals = 300;  // ~5 minutes at 60 BPM
};

//==============================================================================
// EEG Processor
//==============================================================================

class EEGProcessor
{
public:
    EEGProcessor(double sampleRate = 256.0) : fs(sampleRate)
    {
        // Initialize band-pass filter coefficients
        initFilters();
    }

    void process(const float* samples, int numSamples, int channel = 0)
    {
        for (int i = 0; i < numSamples; ++i)
        {
            float sample = samples[i];

            // Apply band-pass filters and accumulate power
            bands.delta += std::pow(applyFilter(sample, deltaFilter), 2);
            bands.theta += std::pow(applyFilter(sample, thetaFilter), 2);
            bands.alpha += std::pow(applyFilter(sample, alphaFilter), 2);
            bands.beta += std::pow(applyFilter(sample, betaFilter), 2);
            bands.gamma += std::pow(applyFilter(sample, gammaFilter), 2);

            sampleCount++;
        }

        // Update powers periodically
        if (sampleCount >= static_cast<int>(fs))  // Every second
        {
            currentBands = bands;
            currentBands.normalize();

            // Reset accumulators
            bands = EEGBands();
            sampleCount = 0;
        }
    }

    EEGBands getBandPowers() const { return currentBands; }

    float getAttentionLevel() const
    {
        // Beta / (Theta + Alpha) - higher = more attention
        float denom = currentBands.theta + currentBands.alpha;
        return (denom > 0.01f) ? std::min(1.0f, currentBands.beta / denom) : 0.5f;
    }

    float getMeditationLevel() const
    {
        // Alpha / Beta - higher = more meditative
        return (currentBands.beta > 0.01f) ?
            std::min(1.0f, currentBands.alpha / currentBands.beta) : 0.5f;
    }

    float getFocusLevel() const
    {
        // (Beta + Gamma) / Total
        return currentBands.beta + currentBands.gamma;
    }

    void reset()
    {
        bands = EEGBands();
        currentBands = EEGBands();
        sampleCount = 0;
    }

private:
    double fs;
    EEGBands bands;
    EEGBands currentBands;
    int sampleCount = 0;

    // Simple IIR filter state
    struct FilterState
    {
        float x1 = 0, x2 = 0;
        float y1 = 0, y2 = 0;
        float b0, b1, b2, a1, a2;
    };

    FilterState deltaFilter, thetaFilter, alphaFilter, betaFilter, gammaFilter;

    void initFilters()
    {
        // Initialize band-pass filters (simplified Butterworth)
        initBandpass(deltaFilter, 0.5f, 4.0f);
        initBandpass(thetaFilter, 4.0f, 8.0f);
        initBandpass(alphaFilter, 8.0f, 13.0f);
        initBandpass(betaFilter, 13.0f, 30.0f);
        initBandpass(gammaFilter, 30.0f, 100.0f);
    }

    void initBandpass(FilterState& f, float lowFreq, float highFreq)
    {
        // Simplified bandpass coefficients
        float centerFreq = (lowFreq + highFreq) / 2.0f;
        float bandwidth = highFreq - lowFreq;

        float w0 = 2.0f * juce::MathConstants<float>::pi * centerFreq / static_cast<float>(fs);
        float alpha = std::sin(w0) * bandwidth / (2.0f * centerFreq);

        float norm = 1.0f + alpha;
        f.b0 = alpha / norm;
        f.b1 = 0.0f;
        f.b2 = -alpha / norm;
        f.a1 = -2.0f * std::cos(w0) / norm;
        f.a2 = (1.0f - alpha) / norm;
    }

    float applyFilter(float x, FilterState& f)
    {
        float y = f.b0 * x + f.b1 * f.x1 + f.b2 * f.x2 - f.a1 * f.y1 - f.a2 * f.y2;
        f.x2 = f.x1;
        f.x1 = x;
        f.y2 = f.y1;
        f.y1 = y;
        return y;
    }
};

//==============================================================================
// GSR (Galvanic Skin Response) Analyzer
//==============================================================================

class GSRAnalyzer
{
public:
    struct GSRMetrics
    {
        float skinConductance = 0.0f;   // Microsiemens
        float tonicLevel = 0.0f;        // Slow-changing baseline
        float phasicLevel = 0.0f;       // Rapid responses (SCR)
        float arousal = 0.0f;           // Derived arousal (0-1)
        int scrCount = 0;               // Skin conductance response count
    };

    void addReading(float conductance)
    {
        readings.push_back(conductance);
        if (readings.size() > maxReadings)
            readings.pop_front();

        // Update tonic level (slow moving average)
        tonicLevel = tonicLevel * 0.99f + conductance * 0.01f;
    }

    GSRMetrics analyze() const
    {
        GSRMetrics metrics;

        if (readings.empty())
            return metrics;

        // Current skin conductance
        metrics.skinConductance = readings.back();
        metrics.tonicLevel = tonicLevel;

        // Phasic component (deviation from tonic)
        metrics.phasicLevel = readings.back() - tonicLevel;

        // Count SCRs (rapid increases)
        int scrCount = 0;
        for (size_t i = 1; i < readings.size(); ++i)
        {
            float diff = readings[i] - readings[i - 1];
            if (diff > 0.05f)  // Threshold for SCR
                scrCount++;
        }
        metrics.scrCount = scrCount;

        // Derive arousal
        float normalizedConductance = std::min(1.0f, metrics.skinConductance / 20.0f);
        float normalizedPhasic = std::min(1.0f, std::abs(metrics.phasicLevel) * 5.0f);
        metrics.arousal = normalizedConductance * 0.5f + normalizedPhasic * 0.5f;

        return metrics;
    }

    void reset()
    {
        readings.clear();
        tonicLevel = 0.0f;
    }

private:
    std::deque<float> readings;
    float tonicLevel = 0.0f;
    static constexpr size_t maxReadings = 600;  // 10 seconds at 60 Hz
};

//==============================================================================
// Respiration Analyzer
//==============================================================================

class RespirationAnalyzer
{
public:
    struct BreathMetrics
    {
        float breathRate = 12.0f;       // Breaths per minute
        float breathDepth = 0.5f;       // Relative depth (0-1)
        float breathPhase = 0.0f;       // 0 = inhale start, 0.5 = exhale start
        bool isInhaling = true;
        float coherence = 0.0f;         // Breathing regularity (0-1)
    };

    void addReading(float value, double timestamp)
    {
        readings.push_back({value, timestamp});
        if (readings.size() > maxReadings)
            readings.pop_front();

        // Detect breath transitions
        if (readings.size() > 1)
        {
            float prev = readings[readings.size() - 2].value;
            float curr = value;

            // Zero crossing detection
            if (prev < 0 && curr >= 0)
            {
                // Inhale start
                if (lastExhaleTime > 0)
                {
                    double breathDuration = timestamp - lastExhaleTime;
                    breathPeriods.push_back(static_cast<float>(breathDuration));
                    if (breathPeriods.size() > 10)
                        breathPeriods.pop_front();
                }
                lastInhaleTime = timestamp;
                isInhaling = true;
            }
            else if (prev >= 0 && curr < 0)
            {
                // Exhale start
                lastExhaleTime = timestamp;
                isInhaling = false;
            }
        }
    }

    BreathMetrics analyze() const
    {
        BreathMetrics metrics;
        metrics.isInhaling = isInhaling;

        if (!breathPeriods.empty())
        {
            // Calculate mean breath period
            float meanPeriod = 0.0f;
            for (float p : breathPeriods)
                meanPeriod += p;
            meanPeriod /= breathPeriods.size();

            metrics.breathRate = 60.0f / meanPeriod;

            // Calculate coherence (regularity)
            if (breathPeriods.size() > 1)
            {
                float variance = 0.0f;
                for (float p : breathPeriods)
                {
                    float diff = p - meanPeriod;
                    variance += diff * diff;
                }
                variance /= breathPeriods.size();

                float cv = std::sqrt(variance) / meanPeriod;  // Coefficient of variation
                metrics.coherence = std::max(0.0f, 1.0f - cv * 2.0f);
            }
        }

        // Calculate phase
        if (!readings.empty() && lastInhaleTime > 0)
        {
            double timeSinceInhale = readings.back().timestamp - lastInhaleTime;
            float avgPeriod = (metrics.breathRate > 0) ? (60.0f / metrics.breathRate) : 5.0f;
            metrics.breathPhase = static_cast<float>(std::fmod(timeSinceInhale / avgPeriod, 1.0));
        }

        // Calculate depth from amplitude
        if (readings.size() > 10)
        {
            float minVal = 1e10f, maxVal = -1e10f;
            for (const auto& r : readings)
            {
                minVal = std::min(minVal, r.value);
                maxVal = std::max(maxVal, r.value);
            }
            metrics.breathDepth = std::min(1.0f, (maxVal - minVal) / 2.0f);
        }

        return metrics;
    }

    void reset()
    {
        readings.clear();
        breathPeriods.clear();
        lastInhaleTime = lastExhaleTime = 0;
        isInhaling = true;
    }

private:
    struct TimestampedReading
    {
        float value;
        double timestamp;
    };

    std::deque<TimestampedReading> readings;
    std::deque<float> breathPeriods;
    double lastInhaleTime = 0;
    double lastExhaleTime = 0;
    bool isInhaling = true;
    static constexpr size_t maxReadings = 300;
};

//==============================================================================
// Motion Analyzer
//==============================================================================

class MotionAnalyzer
{
public:
    struct MotionMetrics
    {
        float accelerationMagnitude = 0.0f;
        float rotationMagnitude = 0.0f;
        float activityLevel = 0.0f;     // 0 = still, 1 = very active
        bool isMoving = false;

        // Gesture detection
        bool gestureDetected = false;
        juce::String gestureType;

        // For MIDI mapping
        float pitch = 0.0f;             // -1 to +1 (tilt forward/back)
        float roll = 0.0f;              // -1 to +1 (tilt left/right)
        float yaw = 0.0f;               // -1 to +1 (rotation)
    };

    void addAccelerometer(float x, float y, float z, double timestamp)
    {
        float magnitude = std::sqrt(x * x + y * y + z * z);

        // Remove gravity (assuming ~1g when still)
        float activity = std::abs(magnitude - 1.0f);

        accelHistory.push_back({activity, timestamp});
        if (accelHistory.size() > maxHistory)
            accelHistory.pop_front();

        // Update pitch and roll from accelerometer
        currentPitch = std::atan2(x, std::sqrt(y * y + z * z));
        currentRoll = std::atan2(y, std::sqrt(x * x + z * z));

        lastAccelMagnitude = magnitude;
    }

    void addGyroscope(float x, float y, float z, double timestamp)
    {
        float magnitude = std::sqrt(x * x + y * y + z * z);

        gyroHistory.push_back({magnitude, timestamp});
        if (gyroHistory.size() > maxHistory)
            gyroHistory.pop_front();

        // Integrate yaw
        if (lastGyroTime > 0)
        {
            double dt = timestamp - lastGyroTime;
            currentYaw += z * static_cast<float>(dt);
            currentYaw = std::fmod(currentYaw, 2.0f * juce::MathConstants<float>::pi);
        }

        lastGyroTime = timestamp;
        lastGyroMagnitude = magnitude;
    }

    MotionMetrics analyze() const
    {
        MotionMetrics metrics;

        metrics.accelerationMagnitude = lastAccelMagnitude;
        metrics.rotationMagnitude = lastGyroMagnitude;

        // Calculate activity level
        if (!accelHistory.empty())
        {
            float avgActivity = 0.0f;
            for (const auto& a : accelHistory)
                avgActivity += a.value;
            avgActivity /= accelHistory.size();

            metrics.activityLevel = std::min(1.0f, avgActivity * 5.0f);
            metrics.isMoving = metrics.activityLevel > 0.1f;
        }

        // Normalize orientation for MIDI mapping
        metrics.pitch = std::clamp(currentPitch / (juce::MathConstants<float>::pi / 2.0f), -1.0f, 1.0f);
        metrics.roll = std::clamp(currentRoll / (juce::MathConstants<float>::pi / 2.0f), -1.0f, 1.0f);
        metrics.yaw = std::clamp(currentYaw / juce::MathConstants<float>::pi, -1.0f, 1.0f);

        return metrics;
    }

    void reset()
    {
        accelHistory.clear();
        gyroHistory.clear();
        currentPitch = currentRoll = currentYaw = 0.0f;
        lastGyroTime = 0;
    }

private:
    struct TimestampedValue
    {
        float value;
        double timestamp;
    };

    std::deque<TimestampedValue> accelHistory;
    std::deque<TimestampedValue> gyroHistory;

    float lastAccelMagnitude = 1.0f;
    float lastGyroMagnitude = 0.0f;
    float currentPitch = 0.0f;
    float currentRoll = 0.0f;
    float currentYaw = 0.0f;
    double lastGyroTime = 0;

    static constexpr size_t maxHistory = 100;
};

//==============================================================================
// Bio-Reactive Parameter Mapper
//==============================================================================

struct BioMapping
{
    juce::String parameterName;
    SensorType sourceType;
    juce::String sourceMetric;      // e.g., "bpm", "alpha", "arousal"

    float minInput = 0.0f;
    float maxInput = 1.0f;
    float minOutput = 0.0f;
    float maxOutput = 1.0f;

    float smoothing = 0.1f;         // 0 = instant, 1 = very slow
    bool inverted = false;

    float currentValue = 0.0f;
};

class BioParameterMapper
{
public:
    void addMapping(const BioMapping& mapping)
    {
        mappings[mapping.parameterName] = mapping;
    }

    void removeMapping(const juce::String& parameterName)
    {
        mappings.erase(parameterName);
    }

    void updateInput(SensorType type, const juce::String& metric, float value)
    {
        for (auto& [name, mapping] : mappings)
        {
            if (mapping.sourceType == type && mapping.sourceMetric == metric)
            {
                // Normalize input
                float normalized = (value - mapping.minInput) / (mapping.maxInput - mapping.minInput);
                normalized = std::clamp(normalized, 0.0f, 1.0f);

                if (mapping.inverted)
                    normalized = 1.0f - normalized;

                // Map to output range
                float target = mapping.minOutput + normalized * (mapping.maxOutput - mapping.minOutput);

                // Apply smoothing
                mapping.currentValue = mapping.currentValue * mapping.smoothing +
                                       target * (1.0f - mapping.smoothing);
            }
        }
    }

    float getParameterValue(const juce::String& parameterName) const
    {
        auto it = mappings.find(parameterName);
        return (it != mappings.end()) ? it->second.currentValue : 0.0f;
    }

    const std::map<juce::String, BioMapping>& getMappings() const { return mappings; }

private:
    std::map<juce::String, BioMapping> mappings;
};

//==============================================================================
// Main Biofeedback Engine
//==============================================================================

class BiofeedbackEngine
{
public:
    using SensorCallback = std::function<void(const SensorReading&)>;
    using StateCallback = std::function<void(const MentalState&)>;

    BiofeedbackEngine()
    {
        startTime = std::chrono::steady_clock::now();
    }

    //==========================================================================
    // Sensor Input
    //==========================================================================

    void feedHeartRate(float bpm)
    {
        hrAnalyzer.addHeartRate(bpm);

        SensorReading reading;
        reading.type = SensorType::HeartRate;
        reading.timestamp = getTimestamp();
        reading.value = bpm;
        notifySensorReading(reading);
    }

    void feedHeartBeat(double timestamp)
    {
        hrAnalyzer.addBeat(timestamp);
    }

    void feedEEG(const float* samples, int numSamples, int channel = 0)
    {
        eegProcessor.process(samples, numSamples, channel);
    }

    void feedGSR(float conductance)
    {
        gsrAnalyzer.addReading(conductance);

        SensorReading reading;
        reading.type = SensorType::GSR;
        reading.timestamp = getTimestamp();
        reading.value = conductance;
        notifySensorReading(reading);
    }

    void feedRespiration(float value)
    {
        respirationAnalyzer.addReading(value, getTimestamp());

        SensorReading reading;
        reading.type = SensorType::Respiration;
        reading.timestamp = getTimestamp();
        reading.value = value;
        notifySensorReading(reading);
    }

    void feedAccelerometer(float x, float y, float z)
    {
        motionAnalyzer.addAccelerometer(x, y, z, getTimestamp());
    }

    void feedGyroscope(float x, float y, float z)
    {
        motionAnalyzer.addGyroscope(x, y, z, getTimestamp());
    }

    //==========================================================================
    // Analysis
    //==========================================================================

    MentalState analyzeMentalState()
    {
        MentalState state;

        // Get all metrics
        auto hrv = hrAnalyzer.analyze();
        auto eeg = eegProcessor.getBandPowers();
        auto gsr = gsrAnalyzer.analyze();
        auto breath = respirationAnalyzer.analyze();

        // Calculate arousal (from HR, GSR)
        float hrArousal = std::min(1.0f, (hrv.bpm - 60.0f) / 60.0f);
        state.arousal = hrArousal * 0.5f + gsr.arousal * 0.5f;

        // Calculate relaxation (from HRV, breathing coherence)
        state.relaxation = hrv.coherence * 0.5f + breath.coherence * 0.5f;

        // Calculate focus (from EEG)
        state.focus = eegProcessor.getAttentionLevel();

        // Calculate meditation (from EEG alpha/theta)
        state.meditation = eegProcessor.getMeditationLevel();

        // Determine emotional state
        if (state.meditation > 0.7f && state.relaxation > 0.6f)
        {
            state.state = EmotionalState::Meditative;
        }
        else if (state.focus > 0.7f && state.arousal > 0.4f && state.arousal < 0.7f)
        {
            state.state = EmotionalState::Flow;
        }
        else if (state.focus > 0.6f)
        {
            state.state = EmotionalState::Focused;
        }
        else if (state.arousal > 0.7f && hrv.stressIndex > 0.6f)
        {
            state.state = EmotionalState::Stressed;
        }
        else if (state.arousal > 0.6f)
        {
            state.state = EmotionalState::Excited;
        }
        else if (state.relaxation > 0.6f)
        {
            state.state = EmotionalState::Relaxed;
        }
        else if (state.focus < 0.3f && state.arousal < 0.3f)
        {
            state.state = EmotionalState::Fatigued;
        }

        // Update parameter mapper
        parameterMapper.updateInput(SensorType::HeartRate, "bpm", hrv.bpm);
        parameterMapper.updateInput(SensorType::HeartRate, "stress", hrv.stressIndex);
        parameterMapper.updateInput(SensorType::HeartRate, "coherence", hrv.coherence);
        parameterMapper.updateInput(SensorType::EEG, "alpha", eeg.alpha);
        parameterMapper.updateInput(SensorType::EEG, "beta", eeg.beta);
        parameterMapper.updateInput(SensorType::EEG, "focus", state.focus);
        parameterMapper.updateInput(SensorType::GSR, "arousal", gsr.arousal);
        parameterMapper.updateInput(SensorType::Respiration, "rate", breath.breathRate);
        parameterMapper.updateInput(SensorType::Respiration, "phase", breath.breathPhase);

        currentState = state;

        // Notify callbacks
        if (stateCallback)
            stateCallback(state);

        return state;
    }

    //==========================================================================
    // Parameter Mapping
    //==========================================================================

    void addParameterMapping(const BioMapping& mapping)
    {
        parameterMapper.addMapping(mapping);
    }

    float getMappedParameter(const juce::String& name) const
    {
        return parameterMapper.getParameterValue(name);
    }

    BioParameterMapper& getMapper() { return parameterMapper; }

    //==========================================================================
    // Accessors
    //==========================================================================

    const MentalState& getCurrentState() const { return currentState; }

    HeartRateAnalyzer::HRVMetrics getHRVMetrics() const { return hrAnalyzer.analyze(); }
    EEGBands getEEGBands() const { return eegProcessor.getBandPowers(); }
    GSRAnalyzer::GSRMetrics getGSRMetrics() const { return gsrAnalyzer.analyze(); }
    RespirationAnalyzer::BreathMetrics getBreathMetrics() const { return respirationAnalyzer.analyze(); }
    MotionAnalyzer::MotionMetrics getMotionMetrics() const { return motionAnalyzer.analyze(); }

    //==========================================================================
    // Callbacks
    //==========================================================================

    void setSensorCallback(SensorCallback callback) { sensorCallback = callback; }
    void setStateCallback(StateCallback callback) { stateCallback = callback; }

    //==========================================================================
    // Reset
    //==========================================================================

    void reset()
    {
        hrAnalyzer.reset();
        eegProcessor.reset();
        gsrAnalyzer.reset();
        respirationAnalyzer.reset();
        motionAnalyzer.reset();
        startTime = std::chrono::steady_clock::now();
    }

private:
    HeartRateAnalyzer hrAnalyzer;
    EEGProcessor eegProcessor;
    GSRAnalyzer gsrAnalyzer;
    RespirationAnalyzer respirationAnalyzer;
    MotionAnalyzer motionAnalyzer;

    BioParameterMapper parameterMapper;
    MentalState currentState;

    std::chrono::steady_clock::time_point startTime;

    SensorCallback sensorCallback;
    StateCallback stateCallback;

    double getTimestamp() const
    {
        auto now = std::chrono::steady_clock::now();
        return std::chrono::duration<double>(now - startTime).count();
    }

    void notifySensorReading(const SensorReading& reading)
    {
        if (sensorCallback)
            sensorCallback(reading);
    }

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(BiofeedbackEngine)
};

} // namespace Bio
} // namespace Echoelmusic
