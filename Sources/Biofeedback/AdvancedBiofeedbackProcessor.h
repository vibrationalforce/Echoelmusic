// AdvancedBiofeedbackProcessor.h - Multi-Sensor Biofeedback Integration
// Supports: HRM, EEG, GSR, Breathing, EMG, Body Temperature
#pragma once

#include "../Common/GlobalWarningFixes.h"
#include <JuceHeader.h>
#include <array>
#include <vector>
#include <deque>

namespace Echoel {

// ==================== SENSOR INTERFACES ====================

// Heart Rate Monitor
class HeartRateMonitor {
public:
    struct HRVMetrics {
        float heartRate{60.0f};      // BPM
        float hrv{50.0f};             // Heart Rate Variability (ms)
        float rmssd{30.0f};           // Root Mean Square of Successive Differences
        float sdnn{45.0f};            // Standard Deviation of NN intervals
        float pnn50{15.0f};           // Percentage of successive RR intervals > 50ms
        float lfHf{1.5f};             // LF/HF ratio (stress indicator)
    };

    void update(float newHeartRate) {
        heartRate = newHeartRate;
        rrIntervals.push_back(60000.0f / newHeartRate);  // ms between beats

        // Keep last 60 intervals
        if (rrIntervals.size() > 60) {
            rrIntervals.pop_front();
        }

        calculateHRV();
    }

    const HRVMetrics& getMetrics() const { return metrics; }

private:
    float heartRate{60.0f};
    std::deque<float> rrIntervals;
    HRVMetrics metrics;

    void calculateHRV() {
        if (rrIntervals.size() < 2) return;

        metrics.heartRate = heartRate;

        // Calculate successive differences
        std::vector<float> successiveDiffs;
        for (size_t i = 1; i < rrIntervals.size(); ++i) {
            successiveDiffs.push_back(std::abs(rrIntervals[i] - rrIntervals[i-1]));
        }

        // RMSSD
        float sumSquares = 0.0f;
        for (float diff : successiveDiffs) {
            sumSquares += diff * diff;
        }
        metrics.rmssd = std::sqrt(sumSquares / static_cast<float>(successiveDiffs.size()));

        // SDNN
        float mean = 0.0f;
        for (float interval : rrIntervals) {
            mean += interval;
        }
        mean /= static_cast<float>(rrIntervals.size());

        float variance = 0.0f;
        for (float interval : rrIntervals) {
            float diff = interval - mean;
            variance += diff * diff;
        }
        metrics.sdnn = std::sqrt(variance / static_cast<float>(rrIntervals.size()));

        // pNN50
        int count50 = 0;
        for (float diff : successiveDiffs) {
            if (diff > 50.0f) count50++;
        }
        metrics.pnn50 = (static_cast<float>(count50) / static_cast<float>(successiveDiffs.size())) * 100.0f;

        // Simple HRV value
        metrics.hrv = metrics.rmssd;

        // LF/HF ratio (simplified - real implementation would use FFT)
        metrics.lfHf = (heartRate > 70.0f) ? 2.0f : 1.0f;  // Simplified stress indicator
    }
};

// EEG Device
class EEGDevice {
public:
    enum class Band {
        Delta,  // 0.5-4 Hz (deep sleep)
        Theta,  // 4-8 Hz (meditation, creativity)
        Alpha,  // 8-13 Hz (relaxed, calm)
        Beta,   // 13-30 Hz (focused, alert)
        Gamma   // 30-100 Hz (high cognitive function)
    };

    struct EEGData {
        std::array<float, 5> bands{};  // Delta, Theta, Alpha, Beta, Gamma
        float focusLevel{0.5f};        // 0.0 to 1.0
        float relaxationLevel{0.5f};   // 0.0 to 1.0
        float meditationLevel{0.3f};   // 0.0 to 1.0
        float attention{0.5f};         // 0.0 to 1.0
    };

    void update(float delta, float theta, float alpha, float beta, float gamma) {
        data.bands[0] = delta;
        data.bands[1] = theta;
        data.bands[2] = alpha;
        data.bands[3] = beta;
        data.bands[4] = gamma;

        calculateMetrics();
    }

    const EEGData& getData() const { return data; }

    float getBand(Band band) const {
        return data.bands[static_cast<int>(band)];
    }

private:
    EEGData data;

    void calculateMetrics() {
        // Focus = High Beta + Low Alpha
        data.focusLevel = (data.bands[3] * 0.7f) + ((1.0f - data.bands[2]) * 0.3f);

        // Relaxation = High Alpha + Low Beta
        data.relaxationLevel = (data.bands[2] * 0.7f) + ((1.0f - data.bands[3]) * 0.3f);

        // Meditation = High Theta + High Alpha
        data.meditationLevel = (data.bands[1] * 0.5f) + (data.bands[2] * 0.5f);

        // Attention = Beta / (Alpha + Theta)
        float denominator = data.bands[2] + data.bands[1];
        data.attention = (denominator > 0.01f) ? (data.bands[3] / denominator) : 0.5f;

        // Clamp all values
        data.focusLevel = juce::jlimit(0.0f, 1.0f, data.focusLevel);
        data.relaxationLevel = juce::jlimit(0.0f, 1.0f, data.relaxationLevel);
        data.meditationLevel = juce::jlimit(0.0f, 1.0f, data.meditationLevel);
        data.attention = juce::jlimit(0.0f, 1.0f, data.attention);
    }
};

// Galvanic Skin Response Sensor
class GSRSensor {
public:
    void update(float conductance) {
        currentGSR = conductance;

        // Track changes for stress detection
        gsrHistory.push_back(conductance);
        if (gsrHistory.size() > 100) {
            gsrHistory.pop_front();
        }

        calculateStress();
    }

    float getGSRLevel() const { return currentGSR; }
    float getStressIndex() const { return stressIndex; }
    float getArousalLevel() const { return arousalLevel; }

private:
    float currentGSR{0.5f};
    float stressIndex{0.0f};
    float arousalLevel{0.0f};
    std::deque<float> gsrHistory;

    void calculateStress() {
        if (gsrHistory.size() < 10) {
            stressIndex = 0.0f;
            return;
        }

        // Calculate variance as stress indicator
        float mean = 0.0f;
        for (float value : gsrHistory) {
            mean += value;
        }
        mean /= static_cast<float>(gsrHistory.size());

        float variance = 0.0f;
        for (float value : gsrHistory) {
            float diff = value - mean;
            variance += diff * diff;
        }
        variance /= static_cast<float>(gsrHistory.size());

        // High variance = high stress
        stressIndex = std::sqrt(variance);

        // High GSR value = high arousal
        arousalLevel = currentGSR;
    }
};

// Breathing Sensor
class BreathingSensor {
public:
    struct BreathingMetrics {
        float breathingRate{12.0f};      // breaths per minute
        float breathingDepth{0.5f};      // 0.0 to 1.0
        float coherenceScore{0.5f};      // HRV-breathing coherence
        bool isInhaling{false};
    };

    void update(float amplitude) {
        breathAmplitude = amplitude;

        // Detect breath cycles
        if (amplitude > 0.5f && !wasInhaling) {
            // Start of inhale
            wasInhaling = true;
            breathCount++;

            // Calculate rate
            auto now = juce::Time::getMillisecondCounterHiRes();
            if (lastBreathTime > 0.0) {
                double interval = (now - lastBreathTime) / 1000.0;  // seconds
                metrics.breathingRate = static_cast<float>(60.0 / interval);
            }
            lastBreathTime = now;
        } else if (amplitude < 0.3f && wasInhaling) {
            wasInhaling = false;
        }

        metrics.breathingDepth = amplitude;
        metrics.isInhaling = wasInhaling;

        // Coherence score (simplified)
        metrics.coherenceScore = (metrics.breathingRate >= 5.0f && metrics.breathingRate <= 7.0f) ? 0.8f : 0.4f;
    }

    const BreathingMetrics& getMetrics() const { return metrics; }

private:
    float breathAmplitude{0.0f};
    bool wasInhaling{false};
    int breathCount{0};
    double lastBreathTime{0.0};
    BreathingMetrics metrics;
};

// ==================== ADVANCED BIOFEEDBACK PROCESSOR ====================

class AdvancedBiofeedbackProcessor {
public:
    struct BiometricState {
        // Cardiac
        float heartRate{60.0f};
        float hrv{50.0f};
        float rmssd{30.0f};
        float pnn50{15.0f};

        // Neural
        std::array<float, 5> eegBands{};  // Delta, Theta, Alpha, Beta, Gamma
        float focusLevel{0.5f};
        float relaxationLevel{0.5f};

        // Stress
        float gsrLevel{0.5f};
        float stressIndex{0.0f};

        // Respiration
        float breathingRate{12.0f};
        float breathingDepth{0.5f};
        float coherenceScore{0.5f};
    };

    struct AudioParameters {
        float filterResonance{0.5f};     // Mapped from HRV
        float reverbSize{0.5f};          // Mapped from EEG Alpha
        float lfoRate{0.5f};             // Mapped from breathing rate
        float distortion{0.0f};          // Mapped from stress/GSR
        float filterCutoff{1000.0f};     // Mapped from focus level
        float masterVolume{0.7f};        // Mapped from coherence
        float delayTime{0.5f};           // Mapped from relaxation
        float chorusDepth{0.3f};         // Mapped from meditation
    };

    struct UserProfile {
        float hrvMin{40.0f};
        float hrvMax{100.0f};
        float alphaBaseline{0.5f};
        float gsrBaseline{0.5f};
        juce::String name{"Default User"};
    };

    AdvancedBiofeedbackProcessor() {
        hrm = std::make_unique<HeartRateMonitor>();
        eeg = std::make_unique<EEGDevice>();
        gsr = std::make_unique<GSRSensor>();
        breath = std::make_unique<BreathingSensor>();
    }

    // Update from sensors
    void updateHeartRate(float bpm) {
        hrm->update(bpm);
        const auto& metrics = hrm->getMetrics();

        state.heartRate = metrics.heartRate;
        state.hrv = metrics.hrv;
        state.rmssd = metrics.rmssd;
        state.pnn50 = metrics.pnn50;

        processAndMap();
    }

    void updateEEG(float delta, float theta, float alpha, float beta, float gamma) {
        eeg->update(delta, theta, alpha, beta, gamma);
        const auto& data = eeg->getData();

        state.eegBands = data.bands;
        state.focusLevel = data.focusLevel;
        state.relaxationLevel = data.relaxationLevel;

        processAndMap();
    }

    void updateGSR(float conductance) {
        gsr->update(conductance);

        state.gsrLevel = gsr->getGSRLevel();
        state.stressIndex = gsr->getStressIndex();

        processAndMap();
    }

    void updateBreathing(float amplitude) {
        breath->update(amplitude);
        const auto& metrics = breath->getMetrics();

        state.breathingRate = metrics.breathingRate;
        state.breathingDepth = metrics.breathingDepth;
        state.coherenceScore = metrics.coherenceScore;

        processAndMap();
    }

    // Map biometric data to audio parameters
    void processAndMap() {
        // HRV → Filter Resonance (higher HRV = more resonance/openness)
        parameters.filterResonance = mapHRV(state.hrv, 0.1f, 0.95f);

        // EEG Alpha → Reverb Size (more alpha = more spacious sound)
        parameters.reverbSize = mapEEG(state.eegBands[2], 0.0f, 1.0f);

        // Breathing Rate → LFO Rate (breathing controls modulation speed)
        parameters.lfoRate = state.breathingRate / 60.0f;  // Convert BPM to Hz

        // GSR/Stress → Distortion (stress adds grit/edge)
        parameters.distortion = mapStress(state.gsrLevel, 0.0f, 0.5f);

        // Focus Level → Filter Cutoff (focus = brightness)
        parameters.filterCutoff = 200.0f + (state.focusLevel * 5000.0f);

        // Coherence Score → Master Volume (coherence = presence)
        parameters.masterVolume = 0.5f + (state.coherenceScore * 0.5f);

        // Relaxation → Delay Time (relaxation = spaciousness)
        parameters.delayTime = 0.1f + (state.relaxationLevel * 0.9f);

        // Breathing Depth → Chorus Depth
        parameters.chorusDepth = state.breathingDepth * 0.5f;
    }

    // Calibration - record baseline for 60 seconds
    void startCalibration() {
        isCalibrating = true;
        calibrationStartTime = juce::Time::currentTimeMillis();
        calibrationData.clear();
    }

    void updateCalibration() {
        if (!isCalibrating) return;

        calibrationData.push_back(state);

        // After 60 seconds, calculate baseline
        auto elapsed = juce::Time::currentTimeMillis() - calibrationStartTime;
        if (elapsed >= 60000) {  // 60 seconds
            finishCalibration();
        }
    }

    void finishCalibration() {
        if (calibrationData.empty()) return;

        // Calculate average values
        float totalHRV = 0.0f;
        float totalAlpha = 0.0f;
        float totalGSR = 0.0f;

        for (const auto& data : calibrationData) {
            totalHRV += data.hrv;
            totalAlpha += data.eegBands[2];
            totalGSR += data.gsrLevel;
        }

        float count = static_cast<float>(calibrationData.size());
        float avgHRV = totalHRV / count;
        float avgAlpha = totalAlpha / count;
        float avgGSR = totalGSR / count;

        // Set user profile ranges
        userProfile.hrvMin = avgHRV * 0.8f;
        userProfile.hrvMax = avgHRV * 1.5f;
        userProfile.alphaBaseline = avgAlpha;
        userProfile.gsrBaseline = avgGSR;

        isCalibrating = false;

        ECHOEL_TRACE("Calibration complete: HRV=" << avgHRV <<
                    ", Alpha=" << avgAlpha << ", GSR=" << avgGSR);
    }

    // Save/load user profile
    void saveUserProfile(const juce::File& file) {
        juce::XmlElement xml("UserProfile");
        xml.setAttribute("name", userProfile.name);
        xml.setAttribute("hrvMin", userProfile.hrvMin);
        xml.setAttribute("hrvMax", userProfile.hrvMax);
        xml.setAttribute("alphaBaseline", userProfile.alphaBaseline);
        xml.setAttribute("gsrBaseline", userProfile.gsrBaseline);

        xml.writeTo(file);
    }

    void loadUserProfile(const juce::File& file) {
        auto xml = juce::XmlDocument::parse(file);
        if (xml != nullptr) {
            userProfile.name = xml->getStringAttribute("name");
            userProfile.hrvMin = static_cast<float>(xml->getDoubleAttribute("hrvMin"));
            userProfile.hrvMax = static_cast<float>(xml->getDoubleAttribute("hrvMax"));
            userProfile.alphaBaseline = static_cast<float>(xml->getDoubleAttribute("alphaBaseline"));
            userProfile.gsrBaseline = static_cast<float>(xml->getDoubleAttribute("gsrBaseline"));
        }
    }

    // Getters
    const BiometricState& getState() const { return state; }
    const AudioParameters& getParameters() const { return parameters; }
    const UserProfile& getUserProfile() const { return userProfile; }

    // Status report
    juce::String getStatusReport() const {
        juce::String report;
        report << "🧠 Advanced Biofeedback Status\n";
        report << "==============================\n\n";
        report << "❤️  Heart Rate: " << state.heartRate << " BPM\n";
        report << "   HRV: " << state.hrv << " ms\n";
        report << "   RMSSD: " << state.rmssd << " ms\n\n";
        report << "🧠 EEG Bands:\n";
        report << "   Delta: " << state.eegBands[0] << "\n";
        report << "   Theta: " << state.eegBands[1] << "\n";
        report << "   Alpha: " << state.eegBands[2] << "\n";
        report << "   Beta: " << state.eegBands[3] << "\n";
        report << "   Gamma: " << state.eegBands[4] << "\n\n";
        report << "💡 Focus: " << (state.focusLevel * 100.0f) << "%\n";
        report << "🧘 Relaxation: " << (state.relaxationLevel * 100.0f) << "%\n\n";
        report << "😰 Stress Index: " << state.stressIndex << "\n";
        report << "   GSR: " << state.gsrLevel << "\n\n";
        report << "🫁 Breathing: " << state.breathingRate << " breaths/min\n";
        report << "   Coherence: " << (state.coherenceScore * 100.0f) << "%\n\n";
        report << "🎚️  Audio Mapping:\n";
        report << "   Filter Cutoff: " << parameters.filterCutoff << " Hz\n";
        report << "   Reverb Size: " << (parameters.reverbSize * 100.0f) << "%\n";
        report << "   LFO Rate: " << parameters.lfoRate << " Hz\n";
        report << "   Master Volume: " << (parameters.masterVolume * 100.0f) << "%\n";
        return report;
    }

private:
    BiometricState state;
    AudioParameters parameters;
    UserProfile userProfile;

    std::unique_ptr<HeartRateMonitor> hrm;
    std::unique_ptr<EEGDevice> eeg;
    std::unique_ptr<GSRSensor> gsr;
    std::unique_ptr<BreathingSensor> breath;

    bool isCalibrating{false};
    int64_t calibrationStartTime{0};
    std::vector<BiometricState> calibrationData;

    // Mapping functions
    float mapHRV(float hrv, float outMin, float outMax) const {
        float normalized = (hrv - userProfile.hrvMin) / (userProfile.hrvMax - userProfile.hrvMin);
        normalized = juce::jlimit(0.0f, 1.0f, normalized);
        return outMin + normalized * (outMax - outMin);
    }

    float mapEEG(float value, float outMin, float outMax) const {
        // EEG values are typically 0.0 to 1.0
        float deviation = (value - userProfile.alphaBaseline) + 0.5f;
        deviation = juce::jlimit(0.0f, 1.0f, deviation);
        return outMin + deviation * (outMax - outMin);
    }

    float mapStress(float gsr, float outMin, float outMax) const {
        float deviation = (gsr - userProfile.gsrBaseline) * 2.0f;
        deviation = juce::jlimit(0.0f, 1.0f, deviation);
        return outMin + deviation * (outMax - outMin);
    }
};

} // namespace Echoel
