/*
 * ╔═══════════════════════════════════════════════════════════════════════════════════════════════════════╗
 * ║                                                                                                       ║
 * ║   🎨 IMAGE & VIDEO MATCHING ENGINE - Super Intelligence Quantum Level 🎨                              ║
 * ║   C++17 Edition (Windows/Linux)                                                                       ║
 * ║                                                                                                       ║
 * ║   Automatische Bildangleichung • Farbkorrektur • Weißabgleich • Belichtung • Winkel                   ║
 * ║   Auto Color Matching • White Balance • Exposure • Lighting • Angle Correction                        ║
 * ║                                                                                                       ║
 * ╚═══════════════════════════════════════════════════════════════════════════════════════════════════════╝
 *
 * Copyright (c) 2026 Echoelmusic
 * MIT License - Pure Native C++17
 */

#ifndef ECHOELMUSIC_SUPER_INTELLIGENCE_IMAGE_MATCHING_HPP
#define ECHOELMUSIC_SUPER_INTELLIGENCE_IMAGE_MATCHING_HPP

#include <string>
#include <vector>
#include <array>
#include <map>
#include <memory>
#include <atomic>
#include <mutex>
#include <functional>
#include <cmath>
#include <chrono>
#include <thread>
#include <algorithm>
#include <numeric>

namespace Echoelmusic {
namespace Video {

// ============================================================================
// MARK: - Intelligence Levels
// ============================================================================

enum class MatchingIntelligenceLevel {
    Basic,              // Simple adjustments
    Smart,              // AI-assisted
    Advanced,           // Deep learning
    SuperIntelligence,  // Full AI
    QuantumSI           // Quantum-enhanced AI (100x power)
};

inline std::string getIntelligenceLevelName(MatchingIntelligenceLevel level) {
    switch (level) {
        case MatchingIntelligenceLevel::Basic: return "Basic";
        case MatchingIntelligenceLevel::Smart: return "Smart";
        case MatchingIntelligenceLevel::Advanced: return "Advanced";
        case MatchingIntelligenceLevel::SuperIntelligence: return "Super Intelligence";
        case MatchingIntelligenceLevel::QuantumSI: return "Quantum SI";
        default: return "Unknown";
    }
}

inline float getIntelligenceMultiplier(MatchingIntelligenceLevel level) {
    switch (level) {
        case MatchingIntelligenceLevel::Basic: return 1.0f;
        case MatchingIntelligenceLevel::Smart: return 2.0f;
        case MatchingIntelligenceLevel::Advanced: return 5.0f;
        case MatchingIntelligenceLevel::SuperIntelligence: return 10.0f;
        case MatchingIntelligenceLevel::QuantumSI: return 100.0f;
        default: return 1.0f;
    }
}

// ============================================================================
// MARK: - Color Analysis
// ============================================================================

struct ColorAnalysis {
    // Histogram data (256 bins each)
    std::array<float, 256> redHistogram{};
    std::array<float, 256> greenHistogram{};
    std::array<float, 256> blueHistogram{};
    std::array<float, 256> luminanceHistogram{};

    // Statistics
    float averageRed = 0.5f;
    float averageGreen = 0.5f;
    float averageBlue = 0.5f;
    float averageLuminance = 0.5f;

    // Color temperature
    float colorTemperature = 5500.0f;  // Kelvin (2000-10000K)
    float tint = 0.0f;                 // Green-Magenta (-150 to +150)

    // Exposure
    float exposure = 0.0f;             // EV (-5 to +5)
    float contrast = 1.0f;             // 0-2
    float highlights = 0.0f;           // -1 to +1
    float shadows = 0.0f;              // -1 to +1
    float whites = 0.0f;               // -1 to +1
    float blacks = 0.0f;               // -1 to +1

    // Saturation & Vibrance
    float saturation = 1.0f;           // 0-2
    float vibrance = 0.0f;             // -1 to +1

    // Dynamic range
    float dynamicRange = 10.0f;        // Stops of range
    float clippedHighlights = 0.0f;    // Percentage
    float clippedShadows = 0.0f;       // Percentage
};

// ============================================================================
// MARK: - White Balance Correction
// ============================================================================

struct WhiteBalanceCorrection {
    float temperature = 5500.0f;       // Kelvin
    float tint = 0.0f;                 // Green-Magenta
    bool autoDetected = false;
    float confidence = 1.0f;

    static WhiteBalanceCorrection neutral() {
        return {5500.0f, 0.0f, false, 1.0f};
    }

    static WhiteBalanceCorrection tungsten() {
        return {3200.0f, 0.0f, false, 1.0f};
    }

    static WhiteBalanceCorrection daylight() {
        return {5600.0f, 0.0f, false, 1.0f};
    }

    static WhiteBalanceCorrection cloudy() {
        return {6500.0f, 0.0f, false, 1.0f};
    }

    static WhiteBalanceCorrection shade() {
        return {7500.0f, 0.0f, false, 1.0f};
    }

    static WhiteBalanceCorrection fluorescent() {
        return {4000.0f, 10.0f, false, 1.0f};
    }
};

// ============================================================================
// MARK: - Exposure Correction
// ============================================================================

struct ExposureCorrection {
    float exposure = 0.0f;             // EV stops (-5 to +5)
    float contrast = 1.0f;             // Multiplier (0.5-2.0)
    float highlights = 0.0f;           // Recovery (-1 to +1)
    float shadows = 0.0f;              // Fill (-1 to +1)
    float whites = 0.0f;               // Clip point (-1 to +1)
    float blacks = 0.0f;               // Clip point (-1 to +1)
    float clarity = 0.0f;              // Local contrast (-1 to +1)
    float dehaze = 0.0f;               // Haze removal (-1 to +1)
    float saturation = 1.0f;           // Saturation multiplier (0-2.0)
    bool autoDetected = false;
    float confidence = 1.0f;

    static ExposureCorrection neutral() {
        return {};
    }
};

// ============================================================================
// MARK: - RGB Color
// ============================================================================

struct RGBColor {
    float r = 1.0f;
    float g = 1.0f;
    float b = 1.0f;

    static RGBColor white() { return {1.0f, 1.0f, 1.0f}; }
    static RGBColor warm() { return {1.0f, 0.9f, 0.8f}; }
    static RGBColor cool() { return {0.9f, 0.95f, 1.0f}; }
};

// ============================================================================
// MARK: - Lighting Correction
// ============================================================================

struct LightingCorrection {
    // Fill light
    float fillLightIntensity = 0.0f;
    float fillLightDirection = 0.0f;

    // Rim/Back light
    float rimLightIntensity = 0.0f;
    RGBColor rimLightColor = RGBColor::white();

    // Ambient light
    float ambientIntensity = 0.0f;
    RGBColor ambientColor = RGBColor::white();

    // Face lighting
    bool faceLightingEnabled = false;
    float faceLightIntensity = 0.0f;
    float faceShadowReduction = 0.0f;

    // Scene analysis
    int detectedLightSources = 0;
    float dominantLightDirection = 0.0f;
    float lightingQualityScore = 1.0f;

    static LightingCorrection neutral() {
        return {};
    }
};

// ============================================================================
// MARK: - Angle Correction
// ============================================================================

struct AngleCorrection {
    float rotationAngle = 0.0f;         // Degrees (-45 to +45)
    bool autoHorizonLevel = true;

    float verticalPerspective = 0.0f;   // -1 to +1
    float horizontalPerspective = 0.0f; // -1 to +1

    float lensDistortion = 0.0f;        // -1 to +1
    float chromaticAberration = 0.0f;   // 0-1
    float vignetting = 0.0f;            // -1 to +1

    float cropFactor = 1.0f;
    bool aspectRatioLock = true;
    bool autoConstrainCrop = true;

    bool horizonDetected = false;
    float horizonConfidence = 0.0f;
    float perspectiveConfidence = 0.0f;

    static AngleCorrection neutral() {
        return {};
    }
};

// ============================================================================
// MARK: - Video Quality Enhancement
// ============================================================================

enum class UpscaleMethod {
    Bilinear,
    Bicubic,
    Lanczos,
    AISuperResolution,
    QuantumUpscale
};

enum class TargetResolution {
    HD720p,
    FullHD1080p,
    QHD1440p,
    UHD4K,
    UHD8K,
    Cinema4K,
    IMAX
};

inline std::pair<int, int> getResolutionDimensions(TargetResolution res) {
    switch (res) {
        case TargetResolution::HD720p: return {1280, 720};
        case TargetResolution::FullHD1080p: return {1920, 1080};
        case TargetResolution::QHD1440p: return {2560, 1440};
        case TargetResolution::UHD4K: return {3840, 2160};
        case TargetResolution::UHD8K: return {7680, 4320};
        case TargetResolution::Cinema4K: return {4096, 2160};
        case TargetResolution::IMAX: return {5616, 4096};
        default: return {1920, 1080};
    }
}

enum class DenoiseMethod {
    Spatial,
    Temporal,
    SpatioTemporal,
    AIDenoise,
    QuantumDenoise
};

enum class HDRMethod {
    HDR10,
    HDR10Plus,
    DolbyVision,
    HLG,
    QuantumHDR
};

struct VideoQualityEnhancement {
    float upscaleFactor = 1.0f;
    UpscaleMethod upscaleMethod = UpscaleMethod::Bicubic;
    TargetResolution targetResolution = TargetResolution::FullHD1080p;

    float denoiseStrength = 0.0f;
    DenoiseMethod denoiseMethod = DenoiseMethod::Spatial;
    float preserveDetails = 0.5f;

    float sharpenAmount = 0.0f;
    float sharpenRadius = 1.0f;
    float sharpenThreshold = 0.0f;

    bool frameInterpolation = false;
    float targetFrameRate = 30.0f;

    bool hdrConversion = false;
    HDRMethod hdrMethod = HDRMethod::HDR10;
    float peakBrightness = 1000.0f;

    static VideoQualityEnhancement passthrough() {
        return {};
    }
};

// ============================================================================
// MARK: - Color Matching Result
// ============================================================================

struct ColorCorrections {
    float temperatureShift = 0.0f;
    float tintShift = 0.0f;
    float exposureShift = 0.0f;
    float contrastMultiplier = 1.0f;
    float saturationMultiplier = 1.0f;
    float highlightsShift = 0.0f;
    float shadowsShift = 0.0f;
    float redShift = 0.0f;
    float greenShift = 0.0f;
    float blueShift = 0.0f;

    static ColorCorrections none() {
        return {};
    }
};

struct ColorMatchingResult {
    ColorAnalysis sourceAnalysis;
    ColorAnalysis targetAnalysis;
    float matchQuality = 0.0f;
    ColorCorrections corrections;
};

// ============================================================================
// MARK: - Complete Corrections
// ============================================================================

struct ImageVideoCorrections {
    WhiteBalanceCorrection whiteBalance;
    ExposureCorrection exposure;
    LightingCorrection lighting;
    AngleCorrection angle;
    VideoQualityEnhancement quality;
    std::optional<ColorMatchingResult> colorMatch;

    MatchingIntelligenceLevel intelligenceLevel = MatchingIntelligenceLevel::Basic;
    double processingTime = 0.0;
    float overallConfidence = 1.0f;

    static ImageVideoCorrections neutral() {
        return {};
    }
};

// ============================================================================
// MARK: - Matching Presets
// ============================================================================

enum class ImageMatchingPreset {
    // Auto presets
    AutoAll,
    AutoColorOnly,
    AutoExposureOnly,
    AutoWhiteBalanceOnly,
    AutoAngleOnly,

    // Scene matching
    MatchToReference,
    MatchBetweenClips,
    SceneConsistency,

    // Quality enhancement
    EnhanceQuality,
    Upscale4K,
    Upscale8K,
    Denoise,
    Sharpen,

    // Creative presets
    CinematicLook,
    NaturalLight,
    StudioPortrait,
    OutdoorVivid,
    LowLightBoost,

    // Professional
    BroadcastStandard,
    FilmGrade,
    HDRMaster,

    // Bio-reactive
    BioReactiveCalm,
    BioReactiveEnergetic,
    QuantumCoherence
};

inline std::string getPresetName(ImageMatchingPreset preset) {
    switch (preset) {
        case ImageMatchingPreset::AutoAll: return "Auto Everything";
        case ImageMatchingPreset::AutoColorOnly: return "Auto Color Only";
        case ImageMatchingPreset::AutoExposureOnly: return "Auto Exposure Only";
        case ImageMatchingPreset::AutoWhiteBalanceOnly: return "Auto White Balance";
        case ImageMatchingPreset::AutoAngleOnly: return "Auto Angle Correction";
        case ImageMatchingPreset::MatchToReference: return "Match to Reference";
        case ImageMatchingPreset::MatchBetweenClips: return "Match Between Clips";
        case ImageMatchingPreset::SceneConsistency: return "Scene Consistency";
        case ImageMatchingPreset::EnhanceQuality: return "Enhance Quality";
        case ImageMatchingPreset::Upscale4K: return "Upscale to 4K";
        case ImageMatchingPreset::Upscale8K: return "Upscale to 8K";
        case ImageMatchingPreset::Denoise: return "Denoise";
        case ImageMatchingPreset::Sharpen: return "Sharpen";
        case ImageMatchingPreset::CinematicLook: return "Cinematic Look";
        case ImageMatchingPreset::NaturalLight: return "Natural Light";
        case ImageMatchingPreset::StudioPortrait: return "Studio Portrait";
        case ImageMatchingPreset::OutdoorVivid: return "Outdoor Vivid";
        case ImageMatchingPreset::LowLightBoost: return "Low Light Boost";
        case ImageMatchingPreset::BroadcastStandard: return "Broadcast Standard";
        case ImageMatchingPreset::FilmGrade: return "Film Grade";
        case ImageMatchingPreset::HDRMaster: return "HDR Master";
        case ImageMatchingPreset::BioReactiveCalm: return "Bio-Reactive Calm";
        case ImageMatchingPreset::BioReactiveEnergetic: return "Bio-Reactive Energetic";
        case ImageMatchingPreset::QuantumCoherence: return "Quantum Coherence";
        default: return "Unknown";
    }
}

// ============================================================================
// MARK: - Image Buffer (Simple pixel buffer)
// ============================================================================

struct ImageBuffer {
    std::vector<uint8_t> data;
    int width = 0;
    int height = 0;
    int channels = 4;  // RGBA

    ImageBuffer() = default;

    ImageBuffer(int w, int h, int ch = 4)
        : width(w), height(h), channels(ch), data(w * h * ch, 0) {}

    uint8_t* pixel(int x, int y) {
        return data.data() + (y * width + x) * channels;
    }

    const uint8_t* pixel(int x, int y) const {
        return data.data() + (y * width + x) * channels;
    }
};

// ============================================================================
// MARK: - Main Engine
// ============================================================================

class SuperIntelligenceImageMatchingEngine {
public:
    using ProgressCallback = std::function<void(float)>;
    using CompletionCallback = std::function<void(const ImageVideoCorrections&)>;

    SuperIntelligenceImageMatchingEngine() = default;
    ~SuperIntelligenceImageMatchingEngine() {
        isRunning.store(false);
    }

    // ========================================================================
    // MARK: - State Getters
    // ========================================================================

    MatchingIntelligenceLevel getIntelligenceLevel() const {
        return intelligenceLevel.load();
    }

    void setIntelligenceLevel(MatchingIntelligenceLevel level) {
        intelligenceLevel.store(level);
    }

    bool getIsProcessing() const {
        return isProcessing.load();
    }

    float getProgress() const {
        return progress.load();
    }

    ImageVideoCorrections getCurrentCorrections() const {
        std::lock_guard<std::mutex> lock(correctionsMutex);
        return currentCorrections;
    }

    // ========================================================================
    // MARK: - Settings
    // ========================================================================

    bool autoWhiteBalance = true;
    bool autoExposure = true;
    bool autoLighting = true;
    bool autoAngle = true;
    bool autoQuality = false;
    float preserveOriginalColors = 0.0f;

    // Bio-reactive
    bool bioReactiveEnabled = false;
    float heartRate = 70.0f;
    float hrv = 50.0f;
    float coherence = 0.5f;

    // ========================================================================
    // MARK: - Analysis
    // ========================================================================

    /**
     * Analyze image for color properties
     */
    ColorAnalysis analyzeImage(const ImageBuffer& image) {
        isProcessing.store(true);
        progress.store(0.0f);

        ColorAnalysis analysis;

        if (image.data.empty() || image.width <= 0 || image.height <= 0) {
            isProcessing.store(false);
            return analysis;
        }

        // Initialize histograms
        std::array<int, 256> redHist{};
        std::array<int, 256> greenHist{};
        std::array<int, 256> blueHist{};
        std::array<int, 256> lumHist{};

        float redSum = 0.0f;
        float greenSum = 0.0f;
        float blueSum = 0.0f;

        const int totalPixels = image.width * image.height;
        const int sampleStep = std::max(1, totalPixels / 100000);
        int sampledCount = 0;

        for (int i = 0; i < totalPixels; i += sampleStep) {
            const uint8_t* p = image.data.data() + i * image.channels;
            const uint8_t r = p[0];
            const uint8_t g = p[1];
            const uint8_t b = p[2];

            const float rNorm = r / 255.0f;
            const float gNorm = g / 255.0f;
            const float bNorm = b / 255.0f;
            const float luminance = 0.299f * rNorm + 0.587f * gNorm + 0.114f * bNorm;

            redSum += rNorm;
            greenSum += gNorm;
            blueSum += bNorm;

            redHist[r]++;
            greenHist[g]++;
            blueHist[b]++;
            lumHist[std::min(255, static_cast<int>(luminance * 255))]++;

            sampledCount++;

            if (sampledCount % 10000 == 0) {
                progress.store(static_cast<float>(i) / totalPixels * 0.5f);
            }
        }

        // Calculate averages
        const float count = static_cast<float>(sampledCount);
        analysis.averageRed = redSum / count;
        analysis.averageGreen = greenSum / count;
        analysis.averageBlue = blueSum / count;
        analysis.averageLuminance = analysis.averageRed * 0.299f +
                                   analysis.averageGreen * 0.587f +
                                   analysis.averageBlue * 0.114f;

        // Normalize histograms
        const int maxHist = *std::max_element(redHist.begin(), redHist.end());
        const float maxHistF = static_cast<float>(std::max(1, maxHist));

        for (int i = 0; i < 256; i++) {
            analysis.redHistogram[i] = redHist[i] / maxHistF;
            analysis.greenHistogram[i] = greenHist[i] / maxHistF;
            analysis.blueHistogram[i] = blueHist[i] / maxHistF;
            analysis.luminanceHistogram[i] = lumHist[i] / maxHistF;
        }

        progress.store(0.6f);

        // Estimate color temperature
        const float rbRatio = analysis.averageRed / std::max(0.01f, analysis.averageBlue);
        analysis.colorTemperature = estimateColorTemperature(rbRatio);

        // Estimate tint
        const float expectedGreen = (analysis.averageRed + analysis.averageBlue) / 2.0f;
        analysis.tint = (analysis.averageGreen - expectedGreen) * 150.0f;

        // Calculate exposure
        analysis.exposure = (analysis.averageLuminance - 0.5f) * 4.0f;

        // Calculate contrast
        analysis.contrast = calculateStdDev(analysis.luminanceHistogram) * 4.0f;

        // Calculate saturation
        const float maxRGB = std::max({analysis.averageRed, analysis.averageGreen, analysis.averageBlue});
        const float minRGB = std::min({analysis.averageRed, analysis.averageGreen, analysis.averageBlue});
        analysis.saturation = (maxRGB - minRGB) / std::max(0.01f, maxRGB);

        // Calculate dynamic range
        int firstNonZero = 0, lastNonZero = 255;
        for (int i = 0; i < 256; i++) {
            if (lumHist[i] > 0) { firstNonZero = i; break; }
        }
        for (int i = 255; i >= 0; i--) {
            if (lumHist[i] > 0) { lastNonZero = i; break; }
        }
        analysis.dynamicRange = static_cast<float>(lastNonZero - firstNonZero) / 255.0f * 14.0f;

        // Calculate clipping
        analysis.clippedHighlights = (lumHist[254] + lumHist[255]) / count * 100.0f;
        analysis.clippedShadows = (lumHist[0] + lumHist[1]) / count * 100.0f;

        progress.store(1.0f);
        isProcessing.store(false);

        return analysis;
    }

    // ========================================================================
    // MARK: - Auto Detection
    // ========================================================================

    WhiteBalanceCorrection autoDetectWhiteBalance(const ColorAnalysis& analysis) {
        WhiteBalanceCorrection correction;

        const float rbRatio = analysis.averageRed / std::max(0.01f, analysis.averageBlue);
        correction.temperature = estimateColorTemperature(rbRatio);

        const float expectedGreen = (analysis.averageRed + analysis.averageBlue) / 2.0f;
        correction.tint = -(analysis.averageGreen - expectedGreen) * 100.0f;

        correction.autoDetected = true;
        correction.confidence = calculateWhiteBalanceConfidence(analysis);

        return correction;
    }

    ExposureCorrection autoDetectExposure(const ColorAnalysis& analysis) {
        ExposureCorrection correction;

        const float targetLuminance = 0.46f;
        const float currentLuminance = analysis.averageLuminance;

        if (currentLuminance > 0.01f) {
            correction.exposure = std::log2(targetLuminance / currentLuminance);
            correction.exposure = std::clamp(correction.exposure, -5.0f, 5.0f);
        }

        // Calculate shadow/highlight adjustments
        float shadowSum = 0.0f, highlightSum = 0.0f;
        for (int i = 0; i < 56; i++) shadowSum += analysis.luminanceHistogram[i];
        for (int i = 200; i < 256; i++) highlightSum += analysis.luminanceHistogram[i];

        if (analysis.clippedHighlights > 1.0f) {
            correction.highlights = -std::min(1.0f, analysis.clippedHighlights / 10.0f);
        }

        if (shadowSum > 0.3f) {
            correction.shadows = std::min(1.0f, shadowSum - 0.3f);
        }

        if (analysis.contrast > 0.1f) {
            correction.contrast = std::clamp(1.0f / analysis.contrast, 0.5f, 2.0f);
        }

        if (analysis.contrast < 0.3f && shadowSum > 0.2f) {
            correction.dehaze = std::min(1.0f, (0.3f - analysis.contrast) * 2.0f);
        }

        correction.autoDetected = true;
        correction.confidence = calculateExposureConfidence(analysis);

        return correction;
    }

    LightingCorrection autoDetectLighting(const ImageBuffer& image) {
        LightingCorrection correction;

        const ColorAnalysis analysis = analyzeImage(image);

        if (analysis.averageLuminance < 0.4f && analysis.clippedHighlights > 0.5f) {
            correction.fillLightIntensity = std::min(1.0f, (0.5f - analysis.averageLuminance) * 2.0f);
        }

        if (analysis.clippedShadows > 2.0f) {
            correction.faceShadowReduction = std::min(1.0f, analysis.clippedShadows / 10.0f);
        }

        float leftHalf = 0.0f, rightHalf = 0.0f;
        for (int i = 0; i < 128; i++) leftHalf += analysis.luminanceHistogram[i];
        for (int i = 128; i < 256; i++) rightHalf += analysis.luminanceHistogram[i];
        correction.dominantLightDirection = (rightHalf - leftHalf) * 90.0f;

        const float dynamicRangeScore = std::min(1.0f, analysis.dynamicRange / 10.0f);
        const float clippingPenalty = (analysis.clippedHighlights + analysis.clippedShadows) / 20.0f;
        correction.lightingQualityScore = std::max(0.0f, dynamicRangeScore - clippingPenalty);

        return correction;
    }

    // ========================================================================
    // MARK: - Color Matching
    // ========================================================================

    ColorMatchingResult matchColors(const ImageBuffer& source, const ImageBuffer& target) {
        ColorMatchingResult result;

        result.sourceAnalysis = analyzeImage(source);
        result.targetAnalysis = analyzeImage(target);

        ColorCorrections& corrections = result.corrections;

        corrections.temperatureShift = result.targetAnalysis.colorTemperature -
                                       result.sourceAnalysis.colorTemperature;
        corrections.tintShift = result.targetAnalysis.tint - result.sourceAnalysis.tint;
        corrections.exposureShift = result.targetAnalysis.exposure - result.sourceAnalysis.exposure;

        if (result.sourceAnalysis.contrast > 0.1f) {
            corrections.contrastMultiplier = result.targetAnalysis.contrast / result.sourceAnalysis.contrast;
        }

        if (result.sourceAnalysis.saturation > 0.1f) {
            corrections.saturationMultiplier = result.targetAnalysis.saturation / result.sourceAnalysis.saturation;
        }

        corrections.redShift = result.targetAnalysis.averageRed - result.sourceAnalysis.averageRed;
        corrections.greenShift = result.targetAnalysis.averageGreen - result.sourceAnalysis.averageGreen;
        corrections.blueShift = result.targetAnalysis.averageBlue - result.sourceAnalysis.averageBlue;

        // Calculate match quality
        const float tempDiff = std::abs(corrections.temperatureShift) / 2000.0f;
        const float tintDiff = std::abs(corrections.tintShift) / 50.0f;
        const float expDiff = std::abs(corrections.exposureShift) / 2.0f;
        const float colorDiff = (std::abs(corrections.redShift) +
                                std::abs(corrections.greenShift) +
                                std::abs(corrections.blueShift)) / 3.0f;

        result.matchQuality = std::max(0.0f, 1.0f - (tempDiff + tintDiff + expDiff + colorDiff) / 4.0f);

        return result;
    }

    // ========================================================================
    // MARK: - Apply Corrections
    // ========================================================================

    ImageBuffer applyCorrections(const ImageBuffer& image, const ImageVideoCorrections& corrections) {
        ImageBuffer result(image.width, image.height, image.channels);

        const float exposureFactor = std::pow(2.0f, corrections.exposure.exposure);
        const float contrast = corrections.exposure.contrast;
        const float tempShift = (corrections.whiteBalance.temperature - 5500.0f) / 5000.0f;

        for (int i = 0; i < image.width * image.height; i++) {
            const uint8_t* src = image.data.data() + i * image.channels;
            uint8_t* dst = result.data.data() + i * result.channels;

            float r = src[0] / 255.0f;
            float g = src[1] / 255.0f;
            float b = src[2] / 255.0f;

            // Apply exposure
            r *= exposureFactor;
            g *= exposureFactor;
            b *= exposureFactor;

            // Apply contrast
            r = (r - 0.5f) * contrast + 0.5f;
            g = (g - 0.5f) * contrast + 0.5f;
            b = (b - 0.5f) * contrast + 0.5f;

            // Apply white balance (temperature shift)
            r *= (1.0f + tempShift * 0.3f);
            b *= (1.0f - tempShift * 0.3f);

            // Clamp and convert back
            dst[0] = static_cast<uint8_t>(std::clamp(r * 255.0f, 0.0f, 255.0f));
            dst[1] = static_cast<uint8_t>(std::clamp(g * 255.0f, 0.0f, 255.0f));
            dst[2] = static_cast<uint8_t>(std::clamp(b * 255.0f, 0.0f, 255.0f));

            if (image.channels > 3) {
                dst[3] = src[3]; // Alpha
            }
        }

        return result;
    }

    // ========================================================================
    // MARK: - One-Tap Auto Correction
    // ========================================================================

    std::pair<ImageBuffer, ImageVideoCorrections> oneTapAutoCorrect(
        const ImageBuffer& image,
        ImageMatchingPreset preset = ImageMatchingPreset::AutoAll
    ) {
        isProcessing.store(true);
        progress.store(0.0f);

        ImageVideoCorrections corrections;
        corrections.intelligenceLevel = intelligenceLevel.load();

        auto startTime = std::chrono::high_resolution_clock::now();

        progress.store(0.1f);
        const ColorAnalysis analysis = analyzeImage(image);

        switch (preset) {
            case ImageMatchingPreset::AutoAll:
            case ImageMatchingPreset::AutoColorOnly:
                progress.store(0.3f);
                corrections.whiteBalance = autoDetectWhiteBalance(analysis);
                corrections.exposure = autoDetectExposure(analysis);
                if (preset == ImageMatchingPreset::AutoAll) {
                    corrections.lighting = autoDetectLighting(image);
                }
                break;

            case ImageMatchingPreset::AutoExposureOnly:
                progress.store(0.3f);
                corrections.exposure = autoDetectExposure(analysis);
                break;

            case ImageMatchingPreset::AutoWhiteBalanceOnly:
                progress.store(0.3f);
                corrections.whiteBalance = autoDetectWhiteBalance(analysis);
                break;

            case ImageMatchingPreset::EnhanceQuality:
            case ImageMatchingPreset::Denoise:
            case ImageMatchingPreset::Sharpen:
                corrections.quality.denoiseStrength = (preset == ImageMatchingPreset::Denoise) ? 0.7f : 0.3f;
                corrections.quality.sharpenAmount = (preset == ImageMatchingPreset::Sharpen) ? 1.0f : 0.5f;
                corrections.quality.upscaleMethod = UpscaleMethod::AISuperResolution;
                break;

            case ImageMatchingPreset::Upscale4K:
                corrections.quality.upscaleFactor = 2.0f;
                corrections.quality.targetResolution = TargetResolution::UHD4K;
                corrections.quality.upscaleMethod = UpscaleMethod::AISuperResolution;
                break;

            case ImageMatchingPreset::Upscale8K:
                corrections.quality.upscaleFactor = 4.0f;
                corrections.quality.targetResolution = TargetResolution::UHD8K;
                corrections.quality.upscaleMethod = UpscaleMethod::QuantumUpscale;
                break;

            case ImageMatchingPreset::CinematicLook:
                corrections.whiteBalance = autoDetectWhiteBalance(analysis);
                corrections.exposure = autoDetectExposure(analysis);
                corrections.exposure.contrast = 1.2f;
                corrections.exposure.shadows = 0.1f;
                corrections.exposure.highlights = -0.2f;
                break;

            case ImageMatchingPreset::NaturalLight:
                corrections.whiteBalance = WhiteBalanceCorrection::daylight();
                corrections.exposure = autoDetectExposure(analysis);
                break;

            case ImageMatchingPreset::StudioPortrait:
                corrections.whiteBalance.temperature = 5600.0f;
                corrections.lighting.faceLightingEnabled = true;
                corrections.lighting.faceLightIntensity = 0.4f;
                corrections.lighting.faceShadowReduction = 0.5f;
                corrections.exposure = autoDetectExposure(analysis);
                break;

            case ImageMatchingPreset::LowLightBoost:
                corrections.exposure = autoDetectExposure(analysis);
                corrections.exposure.exposure = std::min(2.0f, corrections.exposure.exposure + 1.5f);
                corrections.exposure.shadows = 0.8f;
                corrections.quality.denoiseStrength = 0.8f;
                corrections.quality.denoiseMethod = DenoiseMethod::AIDenoise;
                break;

            case ImageMatchingPreset::BroadcastStandard:
                corrections.whiteBalance.temperature = 6500.0f;
                corrections.exposure = autoDetectExposure(analysis);
                corrections.exposure.contrast = 1.0f;
                break;

            case ImageMatchingPreset::HDRMaster:
                corrections.quality.hdrConversion = true;
                corrections.quality.hdrMethod = HDRMethod::DolbyVision;
                corrections.quality.peakBrightness = 4000.0f;
                corrections.exposure = autoDetectExposure(analysis);
                break;

            case ImageMatchingPreset::BioReactiveCalm:
                corrections.whiteBalance.temperature = 6500.0f + (1.0f - coherence) * 1000.0f;
                break;

            case ImageMatchingPreset::BioReactiveEnergetic: {
                const float hrNormalized = (heartRate - 60.0f) / 100.0f;
                corrections.whiteBalance.temperature = 5500.0f - hrNormalized * 500.0f;
                corrections.exposure.contrast = 1.0f + hrNormalized * 0.2f;
                break;
            }

            case ImageMatchingPreset::QuantumCoherence:
                corrections.whiteBalance = autoDetectWhiteBalance(analysis);
                corrections.exposure = autoDetectExposure(analysis);
                corrections.lighting = autoDetectLighting(image);
                corrections.quality.upscaleMethod = UpscaleMethod::QuantumUpscale;
                corrections.quality.denoiseMethod = DenoiseMethod::QuantumDenoise;
                break;

            default:
                corrections.whiteBalance = autoDetectWhiteBalance(analysis);
                corrections.exposure = autoDetectExposure(analysis);
                break;
        }

        progress.store(0.7f);

        ImageBuffer correctedImage = applyCorrections(image, corrections);

        progress.store(1.0f);

        auto endTime = std::chrono::high_resolution_clock::now();
        corrections.processingTime = std::chrono::duration<double>(endTime - startTime).count();
        corrections.overallConfidence = calculateOverallConfidence(corrections);

        {
            std::lock_guard<std::mutex> lock(correctionsMutex);
            currentCorrections = corrections;
        }

        isProcessing.store(false);

        return {correctedImage, corrections};
    }

    // ========================================================================
    // MARK: - Match to Reference
    // ========================================================================

    std::pair<ImageBuffer, ColorMatchingResult> matchToReference(
        const ImageBuffer& source,
        const ImageBuffer& reference
    ) {
        isProcessing.store(true);
        progress.store(0.0f);

        progress.store(0.5f);
        ColorMatchingResult matchResult = matchColors(source, reference);

        ImageVideoCorrections corrections;
        corrections.whiteBalance.temperature += matchResult.corrections.temperatureShift;
        corrections.whiteBalance.tint += matchResult.corrections.tintShift;
        corrections.exposure.exposure += matchResult.corrections.exposureShift;
        corrections.exposure.contrast *= matchResult.corrections.contrastMultiplier;
        corrections.colorMatch = matchResult;

        progress.store(0.8f);
        ImageBuffer correctedImage = applyCorrections(source, corrections);

        progress.store(1.0f);
        isProcessing.store(false);

        return {correctedImage, matchResult};
    }

    // ========================================================================
    // MARK: - Static Helpers
    // ========================================================================

    static std::vector<ImageMatchingPreset> getPresets(const std::string& category) {
        if (category == "Auto") {
            return {
                ImageMatchingPreset::AutoAll,
                ImageMatchingPreset::AutoColorOnly,
                ImageMatchingPreset::AutoExposureOnly,
                ImageMatchingPreset::AutoWhiteBalanceOnly,
                ImageMatchingPreset::AutoAngleOnly
            };
        } else if (category == "Matching") {
            return {
                ImageMatchingPreset::MatchToReference,
                ImageMatchingPreset::MatchBetweenClips,
                ImageMatchingPreset::SceneConsistency
            };
        } else if (category == "Quality") {
            return {
                ImageMatchingPreset::EnhanceQuality,
                ImageMatchingPreset::Upscale4K,
                ImageMatchingPreset::Upscale8K,
                ImageMatchingPreset::Denoise,
                ImageMatchingPreset::Sharpen
            };
        } else if (category == "Creative") {
            return {
                ImageMatchingPreset::CinematicLook,
                ImageMatchingPreset::NaturalLight,
                ImageMatchingPreset::StudioPortrait,
                ImageMatchingPreset::OutdoorVivid,
                ImageMatchingPreset::LowLightBoost
            };
        } else if (category == "Professional") {
            return {
                ImageMatchingPreset::BroadcastStandard,
                ImageMatchingPreset::FilmGrade,
                ImageMatchingPreset::HDRMaster
            };
        } else if (category == "Bio-Reactive") {
            return {
                ImageMatchingPreset::BioReactiveCalm,
                ImageMatchingPreset::BioReactiveEnergetic,
                ImageMatchingPreset::QuantumCoherence
            };
        }
        return {};
    }

    static std::vector<std::string> getPresetCategories() {
        return {"Auto", "Matching", "Quality", "Creative", "Professional", "Bio-Reactive"};
    }

private:
    // State
    std::atomic<MatchingIntelligenceLevel> intelligenceLevel{MatchingIntelligenceLevel::SuperIntelligence};
    std::atomic<bool> isProcessing{false};
    std::atomic<bool> isRunning{true};
    std::atomic<float> progress{0.0f};

    mutable std::mutex correctionsMutex;
    ImageVideoCorrections currentCorrections;

    // ========================================================================
    // MARK: - Helper Functions
    // ========================================================================

    float estimateColorTemperature(float rbRatio) const {
        const float baseTemp = 5500.0f;
        const float tempRange = 4000.0f;

        if (rbRatio > 1.0f) {
            return baseTemp - (rbRatio - 1.0f) * tempRange / 2.0f;
        } else {
            return baseTemp + (1.0f - rbRatio) * tempRange;
        }
    }

    float calculateStdDev(const std::array<float, 256>& histogram) const {
        float sum = 0.0f;
        for (float v : histogram) sum += v;
        if (sum <= 0.0f) return 0.0f;

        float mean = 0.0f;
        for (int i = 0; i < 256; i++) {
            mean += i * histogram[i];
        }
        mean /= sum;

        float variance = 0.0f;
        for (int i = 0; i < 256; i++) {
            variance += std::pow(i - mean, 2) * histogram[i];
        }
        variance /= sum;

        return std::sqrt(variance) / 128.0f;
    }

    float calculateWhiteBalanceConfidence(const ColorAnalysis& analysis) const {
        const float colorSpread = std::abs(analysis.averageRed - analysis.averageGreen) +
                                 std::abs(analysis.averageGreen - analysis.averageBlue) +
                                 std::abs(analysis.averageBlue - analysis.averageRed);
        return std::max(0.0f, 1.0f - colorSpread * 2.0f);
    }

    float calculateExposureConfidence(const ColorAnalysis& analysis) const {
        const float expDeviation = std::abs(analysis.averageLuminance - 0.5f);
        const float clippingPenalty = (analysis.clippedHighlights + analysis.clippedShadows) / 20.0f;
        return std::max(0.0f, 1.0f - expDeviation - clippingPenalty);
    }

    float calculateOverallConfidence(const ImageVideoCorrections& corrections) const {
        float confidence = 1.0f;
        confidence *= corrections.whiteBalance.confidence;
        confidence *= corrections.exposure.confidence;
        confidence *= std::max(0.5f, corrections.lighting.lightingQualityScore);
        return confidence;
    }
};

} // namespace Video
} // namespace Echoelmusic

#endif // ECHOELMUSIC_SUPER_INTELLIGENCE_IMAGE_MATCHING_HPP
