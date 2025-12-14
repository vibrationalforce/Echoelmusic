/**
 * ╔══════════════════════════════════════════════════════════════════════════════╗
 * ║              ECHOELMUSIC WEARABLE SUPPORT                                    ║
 * ║         Apple Watch • Wear OS • Fitbit • Garmin • Samsung                   ║
 * ╚══════════════════════════════════════════════════════════════════════════════╝
 *
 * Unified wearable interface for bio-reactive audio processing.
 *
 * Supported Devices:
 * ━━━━━━━━━━━━━━━━━━
 * APPLE:
 *   • Apple Watch Series 4+ (ECG, HRV, SpO2)
 *   • Apple Watch Ultra (Advanced sensors)
 *
 * GOOGLE/SAMSUNG:
 *   • Pixel Watch (Fitbit sensors)
 *   • Samsung Galaxy Watch 4/5/6 (BioActive sensor)
 *   • Wear OS 3+ devices
 *
 * FITBIT:
 *   • Fitbit Sense/Sense 2 (EDA, ECG, SpO2)
 *   • Fitbit Versa 3/4 (HR, HRV)
 *   • Fitbit Charge 5/6 (HR, HRV, EDA)
 *
 * GARMIN:
 *   • Garmin Venu 2/3 (HRV, Body Battery)
 *   • Garmin Forerunner (Advanced metrics)
 *   • Connect IQ compatible devices
 *
 * POLAR:
 *   • Polar H10 (Chest strap, raw ECG)
 *   • Polar Verity Sense (Optical HR)
 *   • Polar Vantage V2/V3 (HRV, Recovery)
 *
 * WHOOP:
 *   • WHOOP 4.0 (HRV, Strain, Recovery)
 *
 * OURA:
 *   • Oura Ring Gen 3 (HRV, Sleep, Readiness)
 */

#pragma once

#include "PlatformSupport.h"
#include <functional>
#include <vector>
#include <string>
#include <memory>
#include <atomic>

namespace echoelmusic {
namespace wearable {

//==============================================================================
// WEARABLE DEVICE TYPE
//==============================================================================

enum class DeviceType {
    Unknown,

    // Apple
    AppleWatch,
    AppleWatchUltra,

    // Google/Samsung
    PixelWatch,
    GalaxyWatch,
    WearOS,

    // Fitbit
    FitbitSense,
    FitbitVersa,
    FitbitCharge,

    // Garmin
    GarminVenu,
    GarminForerunner,
    GarminFenix,

    // Polar
    PolarH10,
    PolarVerity,
    PolarVantage,

    // Other
    Whoop,
    OuraRing,
    GenericBLE
};

inline const char* getDeviceName(DeviceType type) {
    switch (type) {
        case DeviceType::AppleWatch: return "Apple Watch";
        case DeviceType::AppleWatchUltra: return "Apple Watch Ultra";
        case DeviceType::PixelWatch: return "Pixel Watch";
        case DeviceType::GalaxyWatch: return "Galaxy Watch";
        case DeviceType::WearOS: return "Wear OS Device";
        case DeviceType::FitbitSense: return "Fitbit Sense";
        case DeviceType::FitbitVersa: return "Fitbit Versa";
        case DeviceType::FitbitCharge: return "Fitbit Charge";
        case DeviceType::GarminVenu: return "Garmin Venu";
        case DeviceType::GarminForerunner: return "Garmin Forerunner";
        case DeviceType::GarminFenix: return "Garmin Fenix";
        case DeviceType::PolarH10: return "Polar H10";
        case DeviceType::PolarVerity: return "Polar Verity Sense";
        case DeviceType::PolarVantage: return "Polar Vantage";
        case DeviceType::Whoop: return "WHOOP 4.0";
        case DeviceType::OuraRing: return "Oura Ring";
        case DeviceType::GenericBLE: return "Generic BLE HR";
        default: return "Unknown Device";
    }
}

//==============================================================================
// SENSOR CAPABILITIES
//==============================================================================

struct SensorCapabilities {
    bool heartRate = false;          // Basic HR
    bool heartRateVariability = false; // HRV (RMSSD, SDNN)
    bool ecg = false;                // Electrocardiogram
    bool bloodOxygen = false;        // SpO2
    bool skinTemperature = false;
    bool electrodermalActivity = false; // EDA/GSR
    bool respirationRate = false;
    bool bloodPressure = false;
    bool bodyComposition = false;    // Bioimpedance
    bool sleepTracking = false;
    bool stressTracking = false;
    bool rawPPG = false;             // Raw photoplethysmography

    // Sampling rates
    int hrSampleRateHz = 1;          // Typical: 1 Hz
    int hrvSampleRateHz = 0;         // Typical: 0.2 Hz (every 5 sec)
    int ecgSampleRateHz = 0;         // Typical: 512 Hz
    int ppgSampleRateHz = 0;         // Typical: 25-50 Hz
};

inline SensorCapabilities getCapabilities(DeviceType type) {
    SensorCapabilities caps;

    switch (type) {
        case DeviceType::AppleWatch:
            caps = {true, true, true, true, false, false, true, false, false, true, true, false, 1, 1, 512, 0};
            break;
        case DeviceType::AppleWatchUltra:
            caps = {true, true, true, true, true, false, true, false, false, true, true, false, 1, 1, 512, 0};
            break;
        case DeviceType::GalaxyWatch:
            caps = {true, true, true, true, true, true, true, true, true, true, true, true, 1, 1, 500, 25};
            break;
        case DeviceType::FitbitSense:
            caps = {true, true, true, true, true, true, true, false, false, true, true, false, 1, 1, 300, 0};
            break;
        case DeviceType::PolarH10:
            caps = {true, true, true, false, false, false, false, false, false, false, false, true, 1, 1, 130, 130};
            break;
        case DeviceType::Whoop:
            caps = {true, true, false, true, true, false, true, false, false, true, true, false, 1, 1, 0, 25};
            break;
        case DeviceType::OuraRing:
            caps = {true, true, false, true, true, false, true, false, false, true, true, false, 1, 1, 0, 0};
            break;
        default:
            caps = {true, false, false, false, false, false, false, false, false, false, false, false, 1, 0, 0, 0};
            break;
    }

    return caps;
}

//==============================================================================
// BIO DATA STREAM
//==============================================================================

struct BioDataPacket {
    int64_t timestamp = 0;           // Unix ms

    // Heart
    float heartRate = 0.0f;          // BPM
    float hrvRMSSD = 0.0f;           // ms
    float hrvSDNN = 0.0f;            // ms
    float hrvPNN50 = 0.0f;           // %

    // ECG (if available)
    std::vector<float> ecgSamples;   // Raw ECG waveform

    // Respiration
    float respirationRate = 0.0f;    // breaths/min
    float breathingDepth = 0.0f;     // 0-1

    // Blood
    float bloodOxygen = 0.0f;        // SpO2 %
    float bloodPressureSystolic = 0.0f;
    float bloodPressureDiastolic = 0.0f;

    // Skin
    float skinTemperature = 0.0f;    // °C
    float galvanicSkinResponse = 0.0f; // μS

    // Derived
    float stressLevel = 0.0f;        // 0-1 (derived from HRV)
    float relaxationLevel = 0.0f;    // 0-1 (inverse stress)
    float coherenceLevel = 0.0f;     // 0-1 (HeartMath style)
    float energyLevel = 0.0f;        // 0-1 (derived from HR zones)

    bool isValid = false;
};

//==============================================================================
// WEARABLE CONNECTION
//==============================================================================

enum class ConnectionState {
    Disconnected,
    Scanning,
    Connecting,
    Connected,
    Error
};

struct WearableDevice {
    std::string id;
    std::string name;
    DeviceType type = DeviceType::Unknown;
    SensorCapabilities capabilities;
    ConnectionState state = ConnectionState::Disconnected;
    int batteryLevel = -1;           // -1 if unknown
    int signalStrength = -1;         // RSSI dBm
};

//==============================================================================
// WEARABLE MANAGER
//==============================================================================

class WearableManager {
public:
    using DeviceCallback = std::function<void(const WearableDevice&)>;
    using DataCallback = std::function<void(const BioDataPacket&)>;

    WearableManager() = default;
    virtual ~WearableManager() = default;

    // Scanning
    virtual void startScanning() {
        mScanning = true;
        // Platform-specific implementation
    }

    virtual void stopScanning() {
        mScanning = false;
    }

    bool isScanning() const { return mScanning; }

    // Connection
    virtual bool connect(const std::string& deviceId) {
        mConnectedDeviceId = deviceId;
        return true;
    }

    virtual void disconnect() {
        mConnectedDeviceId.clear();
    }

    bool isConnected() const { return !mConnectedDeviceId.empty(); }

    // Data access
    virtual BioDataPacket getLatestData() const {
        return mLatestData;
    }

    // Callbacks
    void setOnDeviceFound(DeviceCallback callback) { mOnDeviceFound = callback; }
    void setOnDataReceived(DataCallback callback) { mOnDataReceived = callback; }

    // Get connected device
    const WearableDevice& getConnectedDevice() const { return mConnectedDevice; }

    // Get discovered devices
    const std::vector<WearableDevice>& getDiscoveredDevices() const { return mDiscoveredDevices; }

protected:
    void notifyDeviceFound(const WearableDevice& device) {
        mDiscoveredDevices.push_back(device);
        if (mOnDeviceFound) mOnDeviceFound(device);
    }

    void notifyDataReceived(const BioDataPacket& data) {
        mLatestData = data;
        if (mOnDataReceived) mOnDataReceived(data);
    }

    std::atomic<bool> mScanning{false};
    std::string mConnectedDeviceId;
    WearableDevice mConnectedDevice;
    std::vector<WearableDevice> mDiscoveredDevices;
    BioDataPacket mLatestData;

    DeviceCallback mOnDeviceFound;
    DataCallback mOnDataReceived;
};

//==============================================================================
// COHERENCE CALCULATOR (HeartMath-style)
//==============================================================================

class CoherenceCalculator {
public:
    void addHRVSample(float hrvRMSSD, int64_t timestamp) {
        mHRVHistory.push_back({hrvRMSSD, timestamp});

        // Keep 60 seconds of history
        while (mHRVHistory.size() > 60) {
            mHRVHistory.erase(mHRVHistory.begin());
        }

        calculateCoherence();
    }

    float getCoherence() const { return mCoherence; }
    float getStress() const { return 1.0f - mCoherence; }

    // Coherence zones
    enum class Zone { Low, Medium, High };
    Zone getZone() const {
        if (mCoherence > 0.7f) return Zone::High;
        if (mCoherence > 0.4f) return Zone::Medium;
        return Zone::Low;
    }

private:
    void calculateCoherence() {
        if (mHRVHistory.size() < 10) {
            mCoherence = 0.5f;
            return;
        }

        // Calculate coherence based on HRV pattern regularity
        float sum = 0.0f;
        float sumSq = 0.0f;
        for (const auto& sample : mHRVHistory) {
            sum += sample.hrv;
            sumSq += sample.hrv * sample.hrv;
        }

        float mean = sum / mHRVHistory.size();
        float variance = (sumSq / mHRVHistory.size()) - (mean * mean);
        float cv = std::sqrt(variance) / mean;  // Coefficient of variation

        // Lower CV = more coherent
        mCoherence = std::max(0.0f, std::min(1.0f, 1.0f - cv));
    }

    struct HRVSample {
        float hrv;
        int64_t timestamp;
    };

    std::vector<HRVSample> mHRVHistory;
    float mCoherence = 0.5f;
};

//==============================================================================
// BIO-AUDIO MODULATOR
//==============================================================================

class BioAudioModulator {
public:
    struct ModulationOutput {
        float filterCutoff = 0.0f;      // Hz offset
        float filterResonance = 0.0f;   // 0-1 offset
        float reverbMix = 0.0f;         // 0-1 offset
        float delayTime = 0.0f;         // ms offset
        float lfoRate = 0.0f;           // Hz offset
        float pitch = 0.0f;             // cents offset
        float volume = 0.0f;            // dB offset
        float pan = 0.0f;               // -1 to 1 offset
    };

    void setBioData(const BioDataPacket& data) {
        mBioData = data;
    }

    ModulationOutput calculate() {
        ModulationOutput out;

        if (!mBioData.isValid) return out;

        // HRV → Filter (higher HRV = brighter sound)
        float hrvNorm = (mBioData.hrvRMSSD - 20.0f) / 80.0f;  // Normalize 20-100ms
        hrvNorm = std::max(0.0f, std::min(1.0f, hrvNorm));
        out.filterCutoff = hrvNorm * mFilterAmount * 2000.0f;  // Up to 2kHz

        // Coherence → Resonance (higher coherence = more resonance)
        out.filterResonance = mBioData.coherenceLevel * mResonanceAmount;

        // Stress → Reverb (higher stress = more reverb/space)
        out.reverbMix = mBioData.stressLevel * mReverbAmount;

        // Heart Rate → LFO Rate (sync to heartbeat)
        float hrNorm = mBioData.heartRate / 60.0f;  // Normalize to ~1 Hz at 60 BPM
        out.lfoRate = hrNorm * mLFOAmount;

        // Breathing → Volume (breath modulation)
        if (mBioData.respirationRate > 0) {
            float breathPhase = std::sin(mBreathPhase);
            out.volume = breathPhase * mBreathAmount * 3.0f;  // ±3 dB
            mBreathPhase += (mBioData.respirationRate / 60.0f) * 0.001f;  // Advance phase
        }

        return out;
    }

    // Modulation amounts (0-1)
    void setFilterAmount(float amount) { mFilterAmount = amount; }
    void setResonanceAmount(float amount) { mResonanceAmount = amount; }
    void setReverbAmount(float amount) { mReverbAmount = amount; }
    void setLFOAmount(float amount) { mLFOAmount = amount; }
    void setBreathAmount(float amount) { mBreathAmount = amount; }

private:
    BioDataPacket mBioData;
    float mBreathPhase = 0.0f;

    float mFilterAmount = 0.5f;
    float mResonanceAmount = 0.3f;
    float mReverbAmount = 0.4f;
    float mLFOAmount = 0.5f;
    float mBreathAmount = 0.3f;
};

} // namespace wearable
} // namespace echoelmusic
