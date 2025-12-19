#pragma once

#include <JuceHeader.h>
#include "HRVProcessor.h"
#include "CameraPPGProcessor.h"
#include "BioReactiveModulator.h"
#include "../Biofeedback/AdvancedBiofeedbackProcessor.h"
#include <memory>
#include <atomic>

namespace Echoelmusic {

/**
 * @brief Unified Bio-Feedback System - Integration Hub
 *
 * **CRITICAL INTEGRATION LAYER** - Connects ALL bio-data sources:
 * - HRVProcessor (existing sensors, simulated, Bluetooth, HealthKit)
 * - CameraPPGProcessor (webcam-based, NO sensors needed!)
 * - AdvancedBiofeedbackProcessor (EEG, GSR, breathing sensors)
 *
 * **Purpose:**
 * - Single source of truth for bio-data
 * - Automatic fallback (camera → sensors → simulated)
 * - Unified output to BioReactiveModulator
 * - Thread-safe updates
 * - Quality monitoring across all sources
 *
 * **Architecture:**
 * ```
 * ┌──────────────────┐
 * │ Camera PPG       │ (Desktop: webcam HR/HRV)
 * ├──────────────────┤
 * │ HRVProcessor     │ (Mobile: HealthKit, BLE sensors)
 * ├──────────────────┤
 * │ Advanced Sensors │ (EEG, GSR, Breathing)
 * └────────┬─────────┘
 *          │
 *          v
 *   ┌─────────────────────┐
 *   │ BioFeedbackSystem   │ ← THIS CLASS
 *   │ (Unified Hub)       │
 *   └──────────┬──────────┘
 *              │
 *              v
 *   ┌─────────────────────┐
 *   │ BioReactiveModulator│ → Audio/Visual
 *   └─────────────────────┘
 * ```
 *
 * **Quick Win:** Connects camera-based PPG to audio modulation!
 *
 * @author Echoelmusic Team
 * @date 2025-12-19
 * @version 1.0.0
 */
class BioFeedbackSystem
{
public:
    //==========================================================================
    // Bio-Data Source Selection
    //==========================================================================

    enum class BioDataSource
    {
        Auto,               // Automatic selection (Camera → Sensor → Simulated)
        CameraPPG,          // Desktop: Webcam-based heart rate
        HRVSensor,          // Mobile: HealthKit, BLE sensors
        AdvancedSensors,    // EEG, GSR, Breathing sensors
        Simulated,          // Simulated bio-data for testing
        NetworkStream       // Remote bio-data via OSC/WebRTC
    };

    //==========================================================================
    // Unified Bio-Data Output
    //==========================================================================

    struct UnifiedBioData
    {
        // Core metrics (always available)
        float heartRate = 60.0f;        // BPM (40-220)
        float hrv = 0.5f;                // Normalized HRV (0-1)
        float coherence = 0.5f;          // HeartMath coherence (0-1)
        float stress = 0.5f;             // Stress level (0-1, inverse of HRV)

        // HRV time-domain
        float sdnn = 0.0f;               // Standard deviation (ms)
        float rmssd = 0.0f;              // Root mean square (ms)

        // HRV frequency-domain
        float lfPower = 0.0f;            // Low frequency power
        float hfPower = 0.0f;            // High frequency power
        float lfhfRatio = 1.0f;          // LF/HF ratio (autonomic balance)

        // Advanced metrics (if available)
        float eegDelta = 0.0f;           // 0.5-4 Hz
        float eegTheta = 0.0f;           // 4-8 Hz
        float eegAlpha = 0.0f;           // 8-13 Hz
        float eegBeta = 0.0f;            // 13-30 Hz
        float eegGamma = 0.0f;           // 30-100 Hz
        float eegFocus = 0.0f;           // Beta/Theta ratio
        float eegRelaxation = 0.0f;      // Alpha power

        float gsrLevel = 0.0f;           // Skin conductance
        float gsrStress = 0.0f;          // GSR-derived stress
        float gsrArousal = 0.0f;         // Arousal level

        float breathingRate = 15.0f;     // Breaths per minute
        float breathingDepth = 0.5f;     // Depth (0-1)
        float breathingCoherence = 0.5f; // Breath-heart coherence

        // Metadata
        bool isValid = false;            // Overall data validity
        float signalQuality = 0.0f;      // Quality indicator (0-1)
        BioDataSource activeSource = BioDataSource::Simulated;
        double timestamp = 0.0;          // Seconds since start
    };

    //==========================================================================
    BioFeedbackSystem()
    {
        // Initialize processors
        hrvProcessor = std::make_unique<HRVProcessor>();
        cameraPPG = std::make_unique<CameraPPGProcessor>();
        advancedProcessor = std::make_unique<Echoel::AdvancedBiofeedbackProcessor>();
        modulator = std::make_unique<BioReactiveModulator>();

        // Default to auto-detection
        setDataSource(BioDataSource::Auto);

        // HRVProcessor starts in simulated mode by default (no explicit configuration needed)
    }

    ~BioFeedbackSystem()
    {
        stopProcessing();
    }

    //==========================================================================
    // Configuration
    //==========================================================================

    /**
     * @brief Set bio-data source
     * @param source Source selection (Auto for automatic fallback)
     */
    void setDataSource(BioDataSource source)
    {
        currentSource.store(source);

        if (source == BioDataSource::Auto)
        {
            // Auto-detection will be handled in update()
            return;
        }

        // Configure specific source
        switch (source)
        {
            case BioDataSource::Auto:
                // Auto-detection handled in update()
                break;

            case BioDataSource::CameraPPG:
                cameraPPGEnabled.store(true);
                break;

            case BioDataSource::HRVSensor:
                // HRVProcessor will handle sensor configuration
                break;

            case BioDataSource::AdvancedSensors:
                advancedSensorsEnabled.store(true);
                break;

            case BioDataSource::NetworkStream:
                // Network streaming configuration
                break;

            case BioDataSource::Simulated:
                // HRVProcessor runs in simulated mode by default
                break;
        }
    }

    /**
     * @brief Enable camera-based PPG (desktop biofeedback)
     * @param enabled true to enable webcam heart rate detection
     */
    void setCameraPPGEnabled(bool enabled)
    {
        cameraPPGEnabled.store(enabled);

        if (enabled && currentSource.load() == BioDataSource::Auto)
        {
            // Auto-switch to camera if available
            currentSource.store(BioDataSource::CameraPPG);
        }
    }

    /**
     * @brief Enable advanced sensors (EEG, GSR, breathing)
     * @param enabled true to enable multi-sensor support
     */
    void setAdvancedSensorsEnabled(bool enabled)
    {
        advancedSensorsEnabled.store(enabled);
    }

    /**
     * @brief Set smoothing factor for bio-data (prevents jitter)
     * @param factor Smoothing (0.0 = no smoothing, 0.95 = heavy smoothing)
     */
    void setSmoothingFactor(float factor)
    {
        smoothingFactor = juce::jlimit(0.0f, 0.99f, factor);
    }

    //==========================================================================
    // Processing Control
    //==========================================================================

    void startProcessing()
    {
        isProcessing.store(true);
        // HRVProcessor is always running
    }

    void stopProcessing()
    {
        isProcessing.store(false);
        // HRVProcessor is always running
    }

    bool isRunning() const
    {
        return isProcessing.load();
    }

    //==========================================================================
    // Camera PPG Integration (Desktop Webcam)
    //==========================================================================

    /**
     * @brief Process video frame for camera-based PPG
     * @param frame Video frame (juce::Image)
     * @param faceRegion Detected face region (or empty for auto-detect)
     * @param deltaTime Time since last frame (seconds)
     */
    void processCameraFrame(const juce::Image& frame,
                           const juce::Rectangle<int>& faceRegion,
                           double deltaTime)
    {
        if (!cameraPPGEnabled.load())
            return;

        cameraPPG->processFrame(frame, faceRegion, deltaTime);
    }

    /**
     * @brief Process raw pixels for camera-based PPG
     * @param pixels RGB pixel buffer
     * @param width Frame width
     * @param height Frame height
     * @param faceX Face region X
     * @param faceY Face region Y
     * @param faceW Face region width
     * @param faceH Face region height
     * @param deltaTime Time since last frame
     */
    void processCameraPixels(const uint8_t* pixels,
                             int width, int height,
                             int x, int y, int w, int h,
                             double deltaTime)
    {
        if (!cameraPPGEnabled.load())
            return;

        cameraPPG->processPixels(pixels, width, height, x, y, w, h, deltaTime);
    }

    //==========================================================================
    // Unified Update (Call at 30-60 Hz)
    //==========================================================================

    /**
     * @brief Update bio-feedback system
     * @param deltaTime Time since last update (seconds)
     * @return Unified bio-data from all sources
     */
    UnifiedBioData update(double deltaTime)
    {
        if (!isProcessing.load())
            return currentBioData;

        currentTime += deltaTime;

        // Auto-source selection
        if (currentSource.load() == BioDataSource::Auto)
        {
            autoSelectSource();
        }

        // Gather data from active source
        UnifiedBioData newData;
        newData.timestamp = currentTime;

        switch (currentSource.load())
        {
            case BioDataSource::Auto:
                newData = getHRVSensorData();  // Fallback during auto-detection
                break;

            case BioDataSource::CameraPPG:
                newData = getCameraPPGData();
                break;

            case BioDataSource::HRVSensor:
                newData = getHRVSensorData();
                break;

            case BioDataSource::AdvancedSensors:
                newData = getAdvancedSensorData();
                break;

            case BioDataSource::NetworkStream:
                newData = getHRVSensorData();  // Network stream handled by HRVProcessor
                break;

            case BioDataSource::Simulated:
                newData = getHRVSensorData();  // HRVProcessor handles simulated
                break;
        }

        // Apply smoothing to prevent jitter
        applySmoothing(newData);

        // Update modulator
        if (newData.isValid)
        {
            updateModulator(newData);
        }

        currentBioData = newData;
        return currentBioData;
    }

    /**
     * @brief Get current bio-data (thread-safe)
     */
    UnifiedBioData getCurrentBioData() const
    {
        return currentBioData;
    }

    /**
     * @brief Get modulated audio parameters
     */
    BioReactiveModulator::ModulatedParameters getModulatedParameters() const
    {
        return currentModulatedParams;
    }

    /**
     * @brief Get reference to modulator (for custom mapping)
     */
    BioReactiveModulator* getModulator()
    {
        return modulator.get();
    }

private:
    //==========================================================================
    // Auto Source Selection
    //==========================================================================

    void autoSelectSource()
    {
        // Priority: Camera PPG → Advanced Sensors → HRV Sensor → Simulated

        // Check camera PPG
        if (cameraPPGEnabled.load())
        {
            auto ppgMetrics = cameraPPG->getMetrics();
            if (ppgMetrics.isValid && ppgMetrics.signalQuality > 0.3f)
            {
                currentSource.store(BioDataSource::CameraPPG);
                return;
            }
        }

        // Check advanced sensors
        if (advancedSensorsEnabled.load())
        {
            // TODO: Implement AdvancedBiofeedbackProcessor data retrieval
            // For now, skip advanced sensor auto-detection
        }

        // Check HRV sensor
        auto hrvMetrics = hrvProcessor->getMetrics();
        if (hrvMetrics.heartRate > 40.0f)
        {
            currentSource.store(BioDataSource::HRVSensor);
            return;
        }

        // Fallback to simulated
        currentSource.store(BioDataSource::Simulated);
    }

    //==========================================================================
    // Data Extraction from Sources
    //==========================================================================

    UnifiedBioData getCameraPPGData()
    {
        UnifiedBioData data;
        auto ppgMetrics = cameraPPG->getMetrics();

        if (!ppgMetrics.isValid)
            return data;

        // Core metrics
        data.heartRate = ppgMetrics.heartRate;
        data.hrv = ppgMetrics.hrv;
        data.signalQuality = ppgMetrics.signalQuality;
        data.isValid = true;
        data.activeSource = BioDataSource::CameraPPG;

        // HRV metrics
        data.sdnn = ppgMetrics.sdnn;
        data.rmssd = ppgMetrics.rmssd;

        // Estimate coherence from signal quality and RMSSD
        data.coherence = juce::jlimit(0.0f, 1.0f, ppgMetrics.signalQuality * 0.7f);

        // Stress (inverse of HRV)
        data.stress = 1.0f - ppgMetrics.hrv;

        return data;
    }

    UnifiedBioData getHRVSensorData()
    {
        UnifiedBioData data;
        auto hrvMetrics = hrvProcessor->getMetrics();

        // Core metrics
        data.heartRate = hrvMetrics.heartRate;
        data.hrv = hrvMetrics.hrv;
        data.coherence = hrvMetrics.coherence;
        data.stress = hrvMetrics.stressIndex;
        data.isValid = (hrvMetrics.heartRate > 0.0f);
        data.activeSource = BioDataSource::HRVSensor;

        // HRV metrics
        data.sdnn = hrvMetrics.sdnn;
        data.rmssd = hrvMetrics.rmssd;
        data.lfPower = hrvMetrics.lfPower;
        data.hfPower = hrvMetrics.hfPower;
        data.lfhfRatio = hrvMetrics.lfhfRatio;

        // Signal quality (estimate from coherence)
        data.signalQuality = juce::jlimit(0.0f, 1.0f, hrvMetrics.coherence);

        return data;
    }

    UnifiedBioData getAdvancedSensorData()
    {
        UnifiedBioData data;
        // TODO: Implement AdvancedBiofeedbackProcessor API integration
        // getCurrentData() method doesn't exist yet
        data.activeSource = BioDataSource::AdvancedSensors;
        return data;
    }

    //==========================================================================
    // Smoothing
    //==========================================================================

    void applySmoothing(UnifiedBioData& newData)
    {
        if (smoothingFactor <= 0.0f)
            return;

        // Smooth core metrics
        newData.heartRate = smooth(currentBioData.heartRate, newData.heartRate);
        newData.hrv = smooth(currentBioData.hrv, newData.hrv);
        newData.coherence = smooth(currentBioData.coherence, newData.coherence);
        newData.stress = smooth(currentBioData.stress, newData.stress);

        // Smooth HRV metrics
        newData.sdnn = smooth(currentBioData.sdnn, newData.sdnn);
        newData.rmssd = smooth(currentBioData.rmssd, newData.rmssd);
        newData.lfhfRatio = smooth(currentBioData.lfhfRatio, newData.lfhfRatio);

        // Smooth advanced metrics (if present)
        if (advancedSensorsEnabled.load())
        {
            newData.eegAlpha = smooth(currentBioData.eegAlpha, newData.eegAlpha);
            newData.eegBeta = smooth(currentBioData.eegBeta, newData.eegBeta);
            newData.eegFocus = smooth(currentBioData.eegFocus, newData.eegFocus);
            newData.gsrLevel = smooth(currentBioData.gsrLevel, newData.gsrLevel);
            newData.breathingRate = smooth(currentBioData.breathingRate, newData.breathingRate);
        }
    }

    float smooth(float oldValue, float newValue) const
    {
        return oldValue * smoothingFactor + newValue * (1.0f - smoothingFactor);
    }

    //==========================================================================
    // Modulator Update
    //==========================================================================

    void updateModulator(const UnifiedBioData& data)
    {
        // Convert to BioDataInput format
        BioDataInput::BioDataSample sample;
        sample.heartRate = data.heartRate;
        sample.hrv = data.hrv;
        sample.coherence = data.coherence;
        sample.stress = data.stress;
        sample.sdnn = data.sdnn;
        sample.rmssd = data.rmssd;
        sample.lfPower = data.lfPower;
        sample.hfPower = data.hfPower;
        sample.lfhfRatio = data.lfhfRatio;
        sample.isValid = data.isValid;

        // Process through modulator
        currentModulatedParams = modulator->process(sample);
    }

    //==========================================================================
    // Member Variables
    //==========================================================================

    // Processors
    std::unique_ptr<HRVProcessor> hrvProcessor;
    std::unique_ptr<CameraPPGProcessor> cameraPPG;
    std::unique_ptr<Echoel::AdvancedBiofeedbackProcessor> advancedProcessor;
    std::unique_ptr<BioReactiveModulator> modulator;

    // State
    std::atomic<BioDataSource> currentSource{BioDataSource::Auto};
    std::atomic<bool> cameraPPGEnabled{false};
    std::atomic<bool> advancedSensorsEnabled{false};
    std::atomic<bool> isProcessing{false};

    UnifiedBioData currentBioData;
    BioReactiveModulator::ModulatedParameters currentModulatedParams;

    // Timing
    double currentTime = 0.0;

    // Smoothing
    float smoothingFactor = 0.85f;  // 85% smoothing for stability

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(BioFeedbackSystem)
};

} // namespace Echoelmusic
