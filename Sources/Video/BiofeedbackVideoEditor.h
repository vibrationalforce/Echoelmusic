/*
  ==============================================================================
   ECHOELMUSIC - Biofeedback Video Editor
   KI-gestütztes Video-Editing basierend auf Körpersignalen

   Features:
   - Heart Rate → Automatic Beat Cutting
   - Emotion Peaks → Automatic Highlights
   - EEG Waves → Particle Effects
   - GSR (Skin Conductance) → Glitch Intensity
   - Vollautomatisches Schneiden, kein manuelles Editing nötig!

   Wissenschaftliche Basis:
   - Peak Detection Algorithm (Heart Rate Peaks = Emotional Highlights)
   - Spectral Analysis (EEG → Visual Frequency Mapping)
   - Psychophysiological Coherence (HRV Coherence → Cut Timing)
  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include <vector>
#include <memory>

namespace Echoelmusic {
namespace Video {

//==============================================================================
/** Biofeedback Data Sample */
struct BioSample {
    double timestamp;        // Seconds since session start
    float heartRate;         // BPM
    float hrv;              // Heart Rate Variability (ms)
    float coherence;        // HRV Coherence (0-100)
    float eegDelta;         // 0.5-4 Hz
    float eegTheta;         // 4-8 Hz
    float eegAlpha;         // 8-13 Hz
    float eegBeta;          // 13-30 Hz
    float eegGamma;         // 30-100 Hz
    float gsr;              // Galvanic Skin Response (µS)
    float skinTemp;         // Skin temperature (°C)
    float breathing;        // Breaths per minute
};

//==============================================================================
/** Emotion Peak (für Highlight-Detection) */
struct EmotionPeak {
    double timestamp;
    float intensity;        // 0.0 - 1.0
    juce::String emotion;   // "excitement", "calm", "stress", "flow"
    float heartRate;
    float coherence;
};

//==============================================================================
/** Video Cut Point (automatisch generiert) */
struct CutPoint {
    double timestamp;
    juce::String reason;    // "beat", "emotion_peak", "scene_change", "coherence_shift"
    float confidence;       // 0.0 - 1.0
    juce::String transition; // "cut", "fade", "glitch", "zoom"
};

//==============================================================================
/** Video Effect (basierend auf Biofeedback) */
struct BiofeedbackEffect {
    double startTime;
    double endTime;
    juce::String effectType;  // "particles", "glitch", "color_shift", "zoom", "shake"
    float intensity;          // 0.0 - 1.0

    // Particle Effects (EEG-gesteuert)
    struct ParticleParams {
        int count;
        float speed;
        float size;
        juce::Colour color;
        float frequency;  // From EEG band
    } particles;

    // Glitch Effect (GSR-gesteuert)
    struct GlitchParams {
        float displacement;
        float blockSize;
        float rgbSplit;
        float scanlines;
    } glitch;

    // Color Grading (Mood-gesteuert)
    struct ColorParams {
        float hueShift;
        float saturation;
        float temperature;  // Warmth based on heart rate
        float exposure;
    } color;
};

//==============================================================================
/**
 * Biofeedback Video Editor
 *
 * Automatisches Video-Editing basierend auf physiologischen Signalen:
 *
 * 1. Beat Detection: Heart Rate Peaks → Video Cuts
 * 2. Emotion Detection: HRV Coherence Peaks → Highlights
 * 3. EEG Mapping: Brainwave Frequencies → Particle Effects
 * 4. GSR Mapping: Skin Conductance → Glitch Intensity
 * 5. Breathing: Breathing Rate → Zoom/Camera Movement
 */
class BiofeedbackVideoEditor {
public:
    BiofeedbackVideoEditor();
    ~BiofeedbackVideoEditor();

    //==============================================================================
    // Biofeedback Data Input
    void addBioSample(const BioSample& sample);
    void loadBioDataFromFile(const juce::File& file);  // JSON or CSV
    void clearBioData();

    const std::vector<BioSample>& getBioData() const { return bioData; }

    //==============================================================================
    // Video Analysis
    void analyzeVideo(const juce::File& videoFile);
    void setVideoDuration(double seconds);

    //==============================================================================
    // Automatic Editing
    std::vector<CutPoint> generateAutomaticCuts();
    std::vector<EmotionPeak> detectEmotionPeaks();
    std::vector<BiofeedbackEffect> generateEffects();

    // Configuration
    void setCutSensitivity(float sensitivity);  // 0.0 (few cuts) - 1.0 (many cuts)
    void setMinCutInterval(double seconds);     // Minimum time between cuts
    void setEmotionPeakThreshold(float threshold);  // Coherence threshold for peaks

    //==============================================================================
    // Export
    struct ExportSettings {
        juce::File outputFile;
        int width = 1920;
        int height = 1080;
        int fps = 30;
        int bitrate = 10000000;  // 10 Mbps
        juce::String codec = "h264";  // "h264", "h265", "prores", "av1"
        juce::String format = "mp4";  // "mp4", "mov", "webm"
    };

    void exportEditedVideo(const ExportSettings& settings);
    bool isExporting() const { return exporting; }
    float getExportProgress() const { return exportProgress; }

    //==============================================================================
    // Callbacks
    std::function<void(const std::vector<CutPoint>&)> onCutsGenerated;
    std::function<void(const std::vector<EmotionPeak>&)> onEmotionPeaksDetected;
    std::function<void(float progress)> onExportProgress;
    std::function<void(bool success, const juce::String& message)> onExportComplete;

private:
    //==============================================================================
    // Peak Detection (Heart Rate)
    std::vector<double> detectHeartRatePeaks();

    // Emotion Analysis (HRV Coherence)
    std::vector<EmotionPeak> analyzeEmotionalState();

    // Scene Detection (Video analysis)
    std::vector<double> detectSceneChanges();

    // Effect Generation
    BiofeedbackEffect createParticleEffect(double startTime, double endTime, const BioSample& bio);
    BiofeedbackEffect createGlitchEffect(double startTime, double endTime, const BioSample& bio);
    BiofeedbackEffect createColorEffect(double startTime, double endTime, const BioSample& bio);

    // Helper: Interpolate bio data at specific timestamp
    BioSample interpolateBioData(double timestamp) const;

    //==============================================================================
    // Data
    std::vector<BioSample> bioData;
    double videoDuration = 0.0;

    // Settings
    float cutSensitivity = 0.5f;
    double minCutInterval = 2.0;
    float emotionPeakThreshold = 70.0f;  // Coherence > 70 = peak

    // Export state
    bool exporting = false;
    float exportProgress = 0.0f;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(BiofeedbackVideoEditor)
};

//==============================================================================
/**
 * Heart Rate Peak Detector
 *
 * Algorithmus:
 * 1. Glättung der HRV-Kurve (Moving Average)
 * 2. First Derivative (Geschwindigkeit der Änderung)
 * 3. Peak Detection (Lokale Maxima)
 * 4. Threshold Filtering (Nur signifikante Peaks)
 */
class HeartRatePeakDetector {
public:
    struct Peak {
        double timestamp;
        float value;
        float prominence;  // How significant the peak is
    };

    static std::vector<Peak> detectPeaks(
        const std::vector<BioSample>& bioData,
        float threshold = 0.3f,
        int windowSize = 10
    ) {
        std::vector<Peak> peaks;

        if (bioData.size() < windowSize * 2) return peaks;

        // Smooth data (Moving Average)
        std::vector<float> smoothed;
        for (size_t i = 0; i < bioData.size(); ++i) {
            float sum = 0.0f;
            int count = 0;
            for (int j = -windowSize; j <= windowSize; ++j) {
                int idx = (int)i + j;
                if (idx >= 0 && idx < (int)bioData.size()) {
                    sum += bioData[idx].heartRate;
                    count++;
                }
            }
            smoothed.push_back(sum / count);
        }

        // Find local maxima
        for (size_t i = windowSize; i < smoothed.size() - windowSize; ++i) {
            bool isPeak = true;
            float currentValue = smoothed[i];

            // Check if it's a local maximum
            for (int j = 1; j <= windowSize; ++j) {
                if (smoothed[i-j] >= currentValue || smoothed[i+j] >= currentValue) {
                    isPeak = false;
                    break;
                }
            }

            if (isPeak) {
                // Calculate prominence (difference from neighboring valleys)
                float leftValley = *std::min_element(smoothed.begin() + i - windowSize, smoothed.begin() + i);
                float rightValley = *std::min_element(smoothed.begin() + i, smoothed.begin() + i + windowSize);
                float prominence = currentValue - std::max(leftValley, rightValley);

                if (prominence > threshold) {
                    Peak peak;
                    peak.timestamp = bioData[i].timestamp;
                    peak.value = currentValue;
                    peak.prominence = prominence;
                    peaks.push_back(peak);
                }
            }
        }

        return peaks;
    }
};

//==============================================================================
/**
 * EEG to Visual Frequency Mapper
 *
 * Mappt EEG-Frequenzen auf visuelle Effekte:
 *
 * Delta (0.5-4 Hz)   → Langsame, große Partikel (Tiefschlaf)
 * Theta (4-8 Hz)     → Mittelgroße Partikel (Meditation)
 * Alpha (8-13 Hz)    → Schnelle, mittlere Partikel (Entspannung)
 * Beta (13-30 Hz)    → Sehr schnelle, kleine Partikel (Fokus)
 * Gamma (30-100 Hz)  → Explosionen, Hochfrequenz (Peak Performance)
 */
class EEGToVisualMapper {
public:
    struct ParticleConfig {
        int count;
        float speed;
        float size;
        juce::Colour color;
    };

    static ParticleConfig mapEEGToParticles(const BioSample& bio) {
        ParticleConfig config;

        // Find dominant EEG band
        float maxPower = 0.0f;
        int dominantBand = 0;  // 0=delta, 1=theta, 2=alpha, 3=beta, 4=gamma

        float bands[] = { bio.eegDelta, bio.eegTheta, bio.eegAlpha, bio.eegBeta, bio.eegGamma };
        for (int i = 0; i < 5; ++i) {
            if (bands[i] > maxPower) {
                maxPower = bands[i];
                dominantBand = i;
            }
        }

        // Map to particle properties
        switch (dominantBand) {
            case 0:  // Delta (Deep Sleep)
                config.count = 50;
                config.speed = 0.5f;
                config.size = 10.0f;
                config.color = juce::Colour::fromHSV(0.7f, 0.8f, 0.6f, 1.0f);  // Blue
                break;

            case 1:  // Theta (Meditation)
                config.count = 100;
                config.speed = 1.0f;
                config.size = 7.0f;
                config.color = juce::Colour::fromHSV(0.5f, 0.8f, 0.7f, 1.0f);  // Cyan
                break;

            case 2:  // Alpha (Relaxation)
                config.count = 150;
                config.speed = 1.5f;
                config.size = 5.0f;
                config.color = juce::Colour::fromHSV(0.3f, 0.8f, 0.8f, 1.0f);  // Green
                break;

            case 3:  // Beta (Focus)
                config.count = 200;
                config.speed = 2.5f;
                config.size = 3.0f;
                config.color = juce::Colour::fromHSV(0.15f, 0.9f, 0.9f, 1.0f);  // Yellow
                break;

            case 4:  // Gamma (Peak)
                config.count = 300;
                config.speed = 4.0f;
                config.size = 2.0f;
                config.color = juce::Colour::fromHSV(0.0f, 1.0f, 1.0f, 1.0f);  // Red
                break;
        }

        return config;
    }
};

} // namespace Video
} // namespace Echoelmusic
