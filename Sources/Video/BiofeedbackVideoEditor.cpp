/*
  ==============================================================================
   ECHOELMUSIC - Biofeedback Video Editor Implementation
  ==============================================================================
*/

#include "BiofeedbackVideoEditor.h"

namespace Echoelmusic {
namespace Video {

//==============================================================================
// BiofeedbackVideoEditor Implementation
//==============================================================================

BiofeedbackVideoEditor::BiofeedbackVideoEditor() {
    cutSensitivity = 0.5f;
    minCutInterval = 2.0;
    emotionPeakThreshold = 70.0f;
}

BiofeedbackVideoEditor::~BiofeedbackVideoEditor() {
    // Cleanup
}

//==============================================================================
// Biofeedback Data Input
//==============================================================================

void BiofeedbackVideoEditor::addBioSample(const BioSample& sample) {
    bioData.push_back(sample);
}

void BiofeedbackVideoEditor::loadBioDataFromFile(const juce::File& file) {
    DBG("Loading bio data from: " << file.getFullPathName());

    // TODO: Parse JSON or CSV format
    // For now, generate sample data
    bioData.clear();

    for (int i = 0; i < 100; ++i) {
        BioSample sample;
        sample.timestamp = i * 0.5;  // Every 500ms
        sample.heartRate = 70.0f + std::sin(i * 0.1f) * 10.0f;
        sample.hrv = 50.0f + std::cos(i * 0.15f) * 20.0f;
        sample.coherence = 50.0f + std::sin(i * 0.2f) * 30.0f;
        sample.eegDelta = 0.3f + std::sin(i * 0.05f) * 0.2f;
        sample.eegTheta = 0.4f + std::cos(i * 0.07f) * 0.2f;
        sample.eegAlpha = 0.5f + std::sin(i * 0.09f) * 0.3f;
        sample.eegBeta = 0.6f + std::cos(i * 0.11f) * 0.2f;
        sample.eegGamma = 0.2f + std::sin(i * 0.13f) * 0.1f;
        sample.gsr = 5.0f + std::sin(i * 0.08f) * 2.0f;
        sample.skinTemp = 36.5f;
        sample.breathing = 15.0f + std::sin(i * 0.06f) * 3.0f;

        bioData.push_back(sample);
    }

    DBG("Loaded " << bioData.size() << " bio samples");
}

void BiofeedbackVideoEditor::clearBioData() {
    bioData.clear();
}

//==============================================================================
// Video Analysis
//==============================================================================

void BiofeedbackVideoEditor::analyzeVideo(const juce::File& videoFile) {
    DBG("Analyzing video: " << videoFile.getFullPathName());
    // TODO: Use FFmpeg to analyze video
}

void BiofeedbackVideoEditor::setVideoDuration(double seconds) {
    videoDuration = seconds;
    DBG("Video duration set to: " << seconds << " seconds");
}

//==============================================================================
// Automatic Editing
//==============================================================================

std::vector<CutPoint> BiofeedbackVideoEditor::generateAutomaticCuts() {
    std::vector<CutPoint> cuts;

    if (bioData.empty()) {
        DBG("No bio data available for automatic cuts");
        return cuts;
    }

    // Detect heart rate peaks
    auto peaks = detectHeartRatePeaks();

    // Create cuts at peaks
    for (const auto& peakTime : peaks) {
        CutPoint cut;
        cut.timestamp = peakTime;
        cut.reason = "heart_rate_peak";
        cut.confidence = 0.8f;
        cut.transition = "cut";

        // Check minimum interval
        if (!cuts.empty() && (cut.timestamp - cuts.back().timestamp) < minCutInterval) {
            continue;  // Skip if too close to previous cut
        }

        cuts.push_back(cut);
    }

    DBG("Generated " << cuts.size() << " automatic cut points");

    if (onCutsGenerated)
        onCutsGenerated(cuts);

    return cuts;
}

std::vector<EmotionPeak> BiofeedbackVideoEditor::detectEmotionPeaks() {
    auto peaks = analyzeEmotionalState();

    if (onEmotionPeaksDetected)
        onEmotionPeaksDetected(peaks);

    return peaks;
}

std::vector<BiofeedbackEffect> BiofeedbackVideoEditor::generateEffects() {
    std::vector<BiofeedbackEffect> effects;

    if (bioData.empty()) return effects;

    // Generate effects based on EEG and GSR
    for (size_t i = 0; i < bioData.size() - 1; ++i) {
        const auto& bio = bioData[i];

        // Particle effects based on EEG
        if (bio.eegGamma > 0.5f) {  // High gamma = particle explosion
            auto effect = createParticleEffect(bio.timestamp, bio.timestamp + 2.0, bio);
            effects.push_back(effect);
        }

        // Glitch effects based on GSR
        if (bio.gsr > 7.0f) {  // High GSR = stress = glitch
            auto effect = createGlitchEffect(bio.timestamp, bio.timestamp + 1.0, bio);
            effects.push_back(effect);
        }

        // Color effects based on coherence
        auto colorEffect = createColorEffect(bio.timestamp, bio.timestamp + 0.5, bio);
        effects.push_back(colorEffect);
    }

    DBG("Generated " << effects.size() << " biofeedback effects");
    return effects;
}

void BiofeedbackVideoEditor::setCutSensitivity(float sensitivity) {
    cutSensitivity = juce::jlimit(0.0f, 1.0f, sensitivity);
}

void BiofeedbackVideoEditor::setMinCutInterval(double seconds) {
    minCutInterval = juce::jmax(0.5, seconds);
}

void BiofeedbackVideoEditor::setEmotionPeakThreshold(float threshold) {
    emotionPeakThreshold = juce::jlimit(0.0f, 100.0f, threshold);
}

//==============================================================================
// Export
//==============================================================================

void BiofeedbackVideoEditor::exportEditedVideo(const ExportSettings& settings) {
    DBG("Exporting video to: " << settings.outputFile.getFullPathName());
    DBG("Resolution: " << settings.width << "x" << settings.height);
    DBG("FPS: " << settings.fps << ", Bitrate: " << settings.bitrate);
    DBG("Codec: " << settings.codec << ", Format: " << settings.format);

    exporting = true;
    exportProgress = 0.0f;

    // TODO: Use FFmpeg to export video with effects
    // For now, simulate export
    juce::Timer::callAfterDelay(1000, [this]() {
        exportProgress = 0.5f;
        if (onExportProgress) onExportProgress(0.5f);
    });

    juce::Timer::callAfterDelay(2000, [this]() {
        exportProgress = 1.0f;
        exporting = false;
        if (onExportProgress) onExportProgress(1.0f);
        if (onExportComplete) onExportComplete(true, "Export successful");
    });
}

//==============================================================================
// Internal Methods
//==============================================================================

std::vector<double> BiofeedbackVideoEditor::detectHeartRatePeaks() {
    auto peaks = HeartRatePeakDetector::detectPeaks(bioData, cutSensitivity * 0.5f, 5);

    std::vector<double> peakTimes;
    for (const auto& peak : peaks) {
        peakTimes.push_back(peak.timestamp);
    }

    return peakTimes;
}

std::vector<EmotionPeak> BiofeedbackVideoEditor::analyzeEmotionalState() {
    std::vector<EmotionPeak> peaks;

    for (const auto& bio : bioData) {
        if (bio.coherence > emotionPeakThreshold) {
            EmotionPeak peak;
            peak.timestamp = bio.timestamp;
            peak.intensity = bio.coherence / 100.0f;
            peak.heartRate = bio.heartRate;
            peak.coherence = bio.coherence;

            // Classify emotion based on heart rate and coherence
            if (bio.heartRate > 90.0f && bio.coherence > 70.0f) {
                peak.emotion = "excitement";
            } else if (bio.heartRate < 65.0f && bio.coherence > 75.0f) {
                peak.emotion = "calm";
            } else if (bio.coherence > 80.0f) {
                peak.emotion = "flow";
            } else {
                peak.emotion = "neutral";
            }

            peaks.push_back(peak);
        }
    }

    return peaks;
}

std::vector<double> BiofeedbackVideoEditor::detectSceneChanges() {
    // TODO: Implement video scene change detection
    return {};
}

BiofeedbackEffect BiofeedbackVideoEditor::createParticleEffect(
    double startTime, double endTime, const BioSample& bio)
{
    BiofeedbackEffect effect;
    effect.startTime = startTime;
    effect.endTime = endTime;
    effect.effectType = "particles";
    effect.intensity = bio.eegGamma;

    auto particleConfig = EEGToVisualMapper::mapEEGToParticles(bio);
    effect.particles.count = particleConfig.count;
    effect.particles.speed = particleConfig.speed;
    effect.particles.size = particleConfig.size;
    effect.particles.color = particleConfig.color;
    effect.particles.frequency = bio.eegGamma * 100.0f;

    return effect;
}

BiofeedbackEffect BiofeedbackVideoEditor::createGlitchEffect(
    double startTime, double endTime, const BioSample& bio)
{
    BiofeedbackEffect effect;
    effect.startTime = startTime;
    effect.endTime = endTime;
    effect.effectType = "glitch";
    effect.intensity = juce::jmin(1.0f, bio.gsr / 10.0f);

    effect.glitch.displacement = effect.intensity * 50.0f;
    effect.glitch.blockSize = 8.0f + effect.intensity * 32.0f;
    effect.glitch.rgbSplit = effect.intensity * 20.0f;
    effect.glitch.scanlines = effect.intensity;

    return effect;
}

BiofeedbackEffect BiofeedbackVideoEditor::createColorEffect(
    double startTime, double endTime, const BioSample& bio)
{
    BiofeedbackEffect effect;
    effect.startTime = startTime;
    effect.endTime = endTime;
    effect.effectType = "color_shift";
    effect.intensity = bio.coherence / 100.0f;

    // Map heart rate to temperature
    float hrNormalized = (bio.heartRate - 60.0f) / 40.0f;  // 60-100 BPM → 0-1
    effect.color.temperature = hrNormalized;
    effect.color.saturation = 1.0f + (bio.coherence / 100.0f) * 0.5f;
    effect.color.hueShift = 0.0f;
    effect.color.exposure = 0.0f;

    return effect;
}

BioSample BiofeedbackVideoEditor::interpolateBioData(double timestamp) const {
    if (bioData.empty()) return BioSample();

    // Find surrounding samples
    for (size_t i = 0; i < bioData.size() - 1; ++i) {
        if (bioData[i].timestamp <= timestamp && bioData[i+1].timestamp > timestamp) {
            // Linear interpolation
            float t = (timestamp - bioData[i].timestamp) /
                     (bioData[i+1].timestamp - bioData[i].timestamp);

            BioSample result;
            result.timestamp = timestamp;
            result.heartRate = bioData[i].heartRate + t * (bioData[i+1].heartRate - bioData[i].heartRate);
            result.hrv = bioData[i].hrv + t * (bioData[i+1].hrv - bioData[i].hrv);
            result.coherence = bioData[i].coherence + t * (bioData[i+1].coherence - bioData[i].coherence);
            // ... interpolate other fields

            return result;
        }
    }

    return bioData.empty() ? BioSample() : bioData.back();
}

} // namespace Video
} // namespace Echoelmusic
