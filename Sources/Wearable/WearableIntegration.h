#pragma once

#include <JuceHeader.h>
#include <vector>
#include <memory>
#include <string>
#include <map>
#include <functional>
#include <atomic>
#include <chrono>
#include <deque>
#include <cmath>

/**
 * WearableIntegration - Bio-Reactive Music System
 *
 * Connect wearable devices for bio-reactive music making:
 * - Apple Watch (heart rate, HRV, motion, haptic feedback)
 * - Oura Ring (HRV, temperature, sleep/readiness)
 * - Fitbit/Garmin (heart rate, steps, stress)
 * - Polar H10 (ECG-grade heart rate)
 * - Muse/Neurosky (EEG brainwaves)
 * - Custom BLE sensors
 *
 * Bio-data can modulate:
 * - Tempo (sync to heart rate)
 * - Filter cutoffs (HRV = emotional state)
 * - Effect intensity (stress level)
 * - Generative parameters (sleep/energy)
 * - Haptic feedback for rhythm
 *
 * Super Ralph Wiggum Loop Genius Bio Mode
 */

namespace Echoelmusic {
namespace Wearable {

//==============================================================================
// Biometric Data Types
//==============================================================================

enum class BiometricType
{
    HeartRate,              // BPM
    HeartRateVariability,   // RMSSD in ms
    RespiratoryRate,        // Breaths per minute
    SkinTemperature,        // Celsius
    BloodOxygen,            // SpO2 percentage
    StressLevel,            // 0-100 computed score
    EnergyLevel,            // 0-100 readiness score
    SleepScore,             // 0-100 from last night
    Steps,                  // Step count
    Calories,               // kcal burned

    // Motion data
    AccelerationX,
    AccelerationY,
    AccelerationZ,
    GyroscopeX,
    GyroscopeY,
    GyroscopeZ,

    // EEG brainwaves
    DeltaWaves,             // 0.5-4 Hz (deep sleep)
    ThetaWaves,             // 4-8 Hz (drowsy, meditation)
    AlphaWaves,             // 8-13 Hz (relaxed, eyes closed)
    BetaWaves,              // 13-32 Hz (alert, focused)
    GammaWaves,             // 32-100 Hz (peak concentration)

    // Derived metrics
    MeditationScore,        // 0-100
    FocusScore,             // 0-100
    RelaxationScore,        // 0-100

    Unknown
};

inline std::string biometricTypeToString(BiometricType type)
{
    switch (type)
    {
        case BiometricType::HeartRate:           return "Heart Rate";
        case BiometricType::HeartRateVariability: return "HRV";
        case BiometricType::RespiratoryRate:     return "Respiratory Rate";
        case BiometricType::SkinTemperature:     return "Skin Temperature";
        case BiometricType::BloodOxygen:         return "Blood Oxygen";
        case BiometricType::StressLevel:         return "Stress Level";
        case BiometricType::EnergyLevel:         return "Energy Level";
        case BiometricType::SleepScore:          return "Sleep Score";
        case BiometricType::AccelerationX:       return "Acceleration X";
        case BiometricType::AccelerationY:       return "Acceleration Y";
        case BiometricType::AccelerationZ:       return "Acceleration Z";
        case BiometricType::AlphaWaves:          return "Alpha Waves";
        case BiometricType::BetaWaves:           return "Beta Waves";
        case BiometricType::ThetaWaves:          return "Theta Waves";
        case BiometricType::DeltaWaves:          return "Delta Waves";
        case BiometricType::GammaWaves:          return "Gamma Waves";
        case BiometricType::MeditationScore:     return "Meditation";
        case BiometricType::FocusScore:          return "Focus";
        default:                                 return "Unknown";
    }
}

//==============================================================================
// Biometric Sample
//==============================================================================

struct BiometricSample
{
    BiometricType type = BiometricType::Unknown;
    double value = 0.0;
    double quality = 1.0;           // Signal quality 0-1
    std::chrono::steady_clock::time_point timestamp;

    BiometricSample() : timestamp(std::chrono::steady_clock::now()) {}

    BiometricSample(BiometricType t, double v, double q = 1.0)
        : type(t), value(v), quality(q), timestamp(std::chrono::steady_clock::now()) {}
};

//==============================================================================
// Device Types
//==============================================================================

enum class WearableDeviceType
{
    AppleWatch,
    OuraRing,
    PolarH10,
    Fitbit,
    Garmin,
    MuseHeadband,
    Neurosky,
    GenericBLE,
    Simulator,      // For testing without hardware
    Unknown
};

inline std::string deviceTypeToString(WearableDeviceType type)
{
    switch (type)
    {
        case WearableDeviceType::AppleWatch:    return "Apple Watch";
        case WearableDeviceType::OuraRing:      return "Oura Ring";
        case WearableDeviceType::PolarH10:      return "Polar H10";
        case WearableDeviceType::Fitbit:        return "Fitbit";
        case WearableDeviceType::Garmin:        return "Garmin";
        case WearableDeviceType::MuseHeadband:  return "Muse";
        case WearableDeviceType::Neurosky:      return "Neurosky";
        case WearableDeviceType::GenericBLE:    return "BLE Device";
        case WearableDeviceType::Simulator:     return "Simulator";
        default:                                return "Unknown";
    }
}

//==============================================================================
// Wearable Device Interface
//==============================================================================

class WearableDevice
{
public:
    struct DeviceInfo
    {
        std::string name;
        std::string identifier;
        WearableDeviceType type = WearableDeviceType::Unknown;
        std::string firmwareVersion;
        int batteryLevel = 100;
        bool isConnected = false;
    };

    using DataCallback = std::function<void(const BiometricSample&)>;
    using ConnectionCallback = std::function<void(bool connected)>;

    virtual ~WearableDevice() = default;

    //--------------------------------------------------------------------------
    // Connection
    //--------------------------------------------------------------------------

    virtual bool connect() = 0;
    virtual void disconnect() = 0;
    virtual bool isConnected() const = 0;

    virtual DeviceInfo getDeviceInfo() const = 0;

    //--------------------------------------------------------------------------
    // Capabilities
    //--------------------------------------------------------------------------

    virtual std::vector<BiometricType> getSupportedMetrics() const = 0;
    virtual bool supportsHapticFeedback() const { return false; }

    //--------------------------------------------------------------------------
    // Data Streaming
    //--------------------------------------------------------------------------

    virtual void startStreaming() = 0;
    virtual void stopStreaming() = 0;
    virtual bool isStreaming() const = 0;

    void setDataCallback(DataCallback callback) { dataCallback = callback; }
    void setConnectionCallback(ConnectionCallback callback) { connectionCallback = callback; }

    //--------------------------------------------------------------------------
    // Haptic Feedback (if supported)
    //--------------------------------------------------------------------------

    virtual void sendHapticPulse(float intensity, int durationMs) {}
    virtual void sendHapticPattern(const std::vector<std::pair<float, int>>& pattern) {}

protected:
    DataCallback dataCallback;
    ConnectionCallback connectionCallback;

    void notifyData(const BiometricSample& sample)
    {
        if (dataCallback)
            dataCallback(sample);
    }

    void notifyConnection(bool connected)
    {
        if (connectionCallback)
            connectionCallback(connected);
    }
};

//==============================================================================
// Apple Watch Connection (via HealthKit/WatchConnectivity)
//==============================================================================

class AppleWatchDevice : public WearableDevice
{
public:
    AppleWatchDevice()
    {
        info.type = WearableDeviceType::AppleWatch;
        info.name = "Apple Watch";
    }

    bool connect() override
    {
        // On macOS/iOS, would use WCSession for Watch Connectivity
        // and HealthKit for health data access

        // #if JUCE_MAC || JUCE_IOS
        // WCSession.default.delegate = self
        // WCSession.default.activate()
        // Request HealthKit authorization for heart rate, HRV, etc.
        // #endif

        info.isConnected = true;
        notifyConnection(true);
        return true;
    }

    void disconnect() override
    {
        info.isConnected = false;
        notifyConnection(false);
    }

    bool isConnected() const override { return info.isConnected; }

    DeviceInfo getDeviceInfo() const override { return info; }

    std::vector<BiometricType> getSupportedMetrics() const override
    {
        return {
            BiometricType::HeartRate,
            BiometricType::HeartRateVariability,
            BiometricType::BloodOxygen,
            BiometricType::RespiratoryRate,
            BiometricType::AccelerationX,
            BiometricType::AccelerationY,
            BiometricType::AccelerationZ,
            BiometricType::GyroscopeX,
            BiometricType::GyroscopeY,
            BiometricType::GyroscopeZ,
            BiometricType::Steps,
            BiometricType::Calories
        };
    }

    bool supportsHapticFeedback() const override { return true; }

    void startStreaming() override
    {
        streaming = true;
        // Start HealthKit workout session for real-time data
        // HKWorkoutSession with HKLiveWorkoutDataSource
    }

    void stopStreaming() override
    {
        streaming = false;
    }

    bool isStreaming() const override { return streaming; }

    void sendHapticPulse(float intensity, int durationMs) override
    {
        // WKInterfaceDevice.current().play(.notification)
        // or custom haptic using CoreHaptics on iOS 13+
    }

private:
    DeviceInfo info;
    bool streaming = false;
};

//==============================================================================
// Oura Ring Connection (via Oura Cloud API)
//==============================================================================

class OuraRingDevice : public WearableDevice
{
public:
    OuraRingDevice(const std::string& accessToken = "")
        : apiToken(accessToken)
    {
        info.type = WearableDeviceType::OuraRing;
        info.name = "Oura Ring";
    }

    void setAccessToken(const std::string& token) { apiToken = token; }

    bool connect() override
    {
        if (apiToken.empty())
            return false;

        // Oura Ring connects via cloud API (no direct BLE for third-party apps)
        // Would make OAuth2 authenticated request to:
        // https://api.ouraring.com/v2/usercollection/daily_readiness
        // https://api.ouraring.com/v2/usercollection/heartrate

        info.isConnected = true;
        notifyConnection(true);
        return true;
    }

    void disconnect() override
    {
        info.isConnected = false;
        notifyConnection(false);
    }

    bool isConnected() const override { return info.isConnected; }

    DeviceInfo getDeviceInfo() const override { return info; }

    std::vector<BiometricType> getSupportedMetrics() const override
    {
        return {
            BiometricType::HeartRate,
            BiometricType::HeartRateVariability,
            BiometricType::SkinTemperature,
            BiometricType::RespiratoryRate,
            BiometricType::SleepScore,
            BiometricType::EnergyLevel,        // Readiness score
            BiometricType::StressLevel         // Derived from HRV
        };
    }

    void startStreaming() override
    {
        streaming = true;
        // Poll API periodically for new data
        // Real-time streaming not available - Oura syncs periodically
    }

    void stopStreaming() override { streaming = false; }
    bool isStreaming() const override { return streaming; }

    // Fetch daily readiness/sleep data
    void fetchDailyData()
    {
        // GET https://api.ouraring.com/v2/usercollection/daily_readiness
        // Authorization: Bearer {apiToken}

        // Parse response and emit samples
        // notifyData(BiometricSample(BiometricType::EnergyLevel, readinessScore));
        // notifyData(BiometricSample(BiometricType::SleepScore, sleepScore));
    }

private:
    DeviceInfo info;
    std::string apiToken;
    bool streaming = false;
};

//==============================================================================
// Polar H10 BLE Heart Rate Monitor
//==============================================================================

class PolarH10Device : public WearableDevice
{
public:
    PolarH10Device()
    {
        info.type = WearableDeviceType::PolarH10;
        info.name = "Polar H10";
    }

    bool connect() override
    {
        // Scan for BLE devices with Heart Rate Service (0x180D)
        // Connect to device matching "Polar H10" name

        // Standard BLE services used:
        // - Heart Rate Service (0x180D)
        //   - Heart Rate Measurement (0x2A37) - notify
        // - Device Information (0x180A)
        // - Battery Service (0x180F)

        // Polar-specific for raw ECG:
        // - PMD Service for ECG data stream

        info.isConnected = true;
        notifyConnection(true);
        return true;
    }

    void disconnect() override
    {
        info.isConnected = false;
        notifyConnection(false);
    }

    bool isConnected() const override { return info.isConnected; }
    DeviceInfo getDeviceInfo() const override { return info; }

    std::vector<BiometricType> getSupportedMetrics() const override
    {
        return {
            BiometricType::HeartRate,
            BiometricType::HeartRateVariability,  // Computed from RR intervals
        };
    }

    void startStreaming() override
    {
        streaming = true;
        // Subscribe to Heart Rate Measurement characteristic
        // Parse heart rate and RR intervals from notification data
    }

    void stopStreaming() override { streaming = false; }
    bool isStreaming() const override { return streaming; }

    // Calculate HRV from RR intervals
    double calculateHRV(const std::vector<int>& rrIntervals)
    {
        if (rrIntervals.size() < 2)
            return 0.0;

        // Calculate RMSSD (Root Mean Square of Successive Differences)
        double sumSquaredDiff = 0.0;
        for (size_t i = 1; i < rrIntervals.size(); ++i)
        {
            double diff = rrIntervals[i] - rrIntervals[i-1];
            sumSquaredDiff += diff * diff;
        }

        return std::sqrt(sumSquaredDiff / (rrIntervals.size() - 1));
    }

private:
    DeviceInfo info;
    bool streaming = false;
    std::vector<int> rrBuffer;  // RR intervals in ms
};

//==============================================================================
// Muse EEG Headband
//==============================================================================

class MuseDevice : public WearableDevice
{
public:
    MuseDevice()
    {
        info.type = WearableDeviceType::MuseHeadband;
        info.name = "Muse Headband";
    }

    bool connect() override
    {
        // Connect via Muse SDK or direct BLE
        // Muse 2/S have 4 EEG sensors + PPG + accelerometer

        info.isConnected = true;
        notifyConnection(true);
        return true;
    }

    void disconnect() override
    {
        info.isConnected = false;
        notifyConnection(false);
    }

    bool isConnected() const override { return info.isConnected; }
    DeviceInfo getDeviceInfo() const override { return info; }

    std::vector<BiometricType> getSupportedMetrics() const override
    {
        return {
            BiometricType::DeltaWaves,
            BiometricType::ThetaWaves,
            BiometricType::AlphaWaves,
            BiometricType::BetaWaves,
            BiometricType::GammaWaves,
            BiometricType::MeditationScore,
            BiometricType::FocusScore,
            BiometricType::RelaxationScore,
            BiometricType::HeartRate,           // Muse 2/S have PPG
            BiometricType::AccelerationX,
            BiometricType::AccelerationY,
            BiometricType::AccelerationZ
        };
    }

    void startStreaming() override
    {
        streaming = true;
        // Subscribe to EEG data stream
        // Process FFT to extract band powers
    }

    void stopStreaming() override { streaming = false; }
    bool isStreaming() const override { return streaming; }

    // Compute band powers from raw EEG
    void processEEGSample(const std::vector<float>& rawEEG, double sampleRate)
    {
        // Apply bandpass filters for each frequency band:
        // Delta: 0.5-4 Hz
        // Theta: 4-8 Hz
        // Alpha: 8-13 Hz
        // Beta: 13-32 Hz
        // Gamma: 32-100 Hz

        // Compute power in each band using FFT or filter banks
        // Normalize and emit as samples
    }

private:
    DeviceInfo info;
    bool streaming = false;
};

//==============================================================================
// Simulator Device (for testing without hardware)
//==============================================================================

class SimulatorDevice : public WearableDevice
{
public:
    SimulatorDevice()
    {
        info.type = WearableDeviceType::Simulator;
        info.name = "Bio Simulator";
        info.identifier = "simulator-001";
        info.isConnected = false;
    }

    bool connect() override
    {
        info.isConnected = true;
        notifyConnection(true);
        return true;
    }

    void disconnect() override
    {
        stopStreaming();
        info.isConnected = false;
        notifyConnection(false);
    }

    bool isConnected() const override { return info.isConnected; }
    DeviceInfo getDeviceInfo() const override { return info; }

    std::vector<BiometricType> getSupportedMetrics() const override
    {
        return {
            BiometricType::HeartRate,
            BiometricType::HeartRateVariability,
            BiometricType::StressLevel,
            BiometricType::EnergyLevel,
            BiometricType::AlphaWaves,
            BiometricType::BetaWaves,
            BiometricType::AccelerationX,
            BiometricType::AccelerationY,
            BiometricType::AccelerationZ
        };
    }

    void startStreaming() override
    {
        streaming = true;
        startTime = std::chrono::steady_clock::now();

        // Start simulation timer
        simulationTimer = std::make_unique<juce::Timer>();
        // Would call generateSimulatedData() at 10Hz
    }

    void stopStreaming() override
    {
        streaming = false;
        simulationTimer.reset();
    }

    bool isStreaming() const override { return streaming; }

    // Simulation parameters
    void setBaseHeartRate(double bpm) { baseHeartRate = bpm; }
    void setStressLevel(double stress) { targetStress = stress; }
    void setActivityLevel(double activity) { activityLevel = activity; }

private:
    DeviceInfo info;
    bool streaming = false;
    std::chrono::steady_clock::time_point startTime;

    double baseHeartRate = 70.0;
    double targetStress = 30.0;
    double activityLevel = 0.3;

    double phase = 0.0;

    std::unique_ptr<juce::Timer> simulationTimer;

    void generateSimulatedData()
    {
        auto now = std::chrono::steady_clock::now();
        auto elapsed = std::chrono::duration<double>(now - startTime).count();

        // Simulate realistic heart rate with variation
        double hrVariation = 5.0 * std::sin(elapsed * 0.1) +      // Slow drift
                            2.0 * std::sin(elapsed * 0.5) +       // Respiratory influence
                            1.0 * ((std::rand() % 100) / 100.0 - 0.5);  // Random noise

        double heartRate = baseHeartRate + hrVariation + (activityLevel * 30.0);

        // Simulate HRV (inversely related to stress)
        double hrv = 50.0 * (1.0 - targetStress / 100.0) +
                     10.0 * ((std::rand() % 100) / 100.0);

        // Simulate stress response to activity
        double stress = targetStress + activityLevel * 20.0;
        stress = std::clamp(stress, 0.0, 100.0);

        // Simulate motion
        double accX = 0.1 * std::sin(elapsed * 2.0) * activityLevel;
        double accY = 0.1 * std::cos(elapsed * 2.3) * activityLevel;
        double accZ = 1.0 + 0.05 * std::sin(elapsed * 1.8) * activityLevel;

        // Simulate brainwaves (normalized 0-1)
        double alpha = 0.5 + 0.3 * (1.0 - stress / 100.0);  // Higher when relaxed
        double beta = 0.3 + 0.4 * (stress / 100.0);         // Higher when stressed

        // Emit samples
        notifyData(BiometricSample(BiometricType::HeartRate, heartRate));
        notifyData(BiometricSample(BiometricType::HeartRateVariability, hrv));
        notifyData(BiometricSample(BiometricType::StressLevel, stress));
        notifyData(BiometricSample(BiometricType::EnergyLevel, 70.0 - stress * 0.5));
        notifyData(BiometricSample(BiometricType::AccelerationX, accX));
        notifyData(BiometricSample(BiometricType::AccelerationY, accY));
        notifyData(BiometricSample(BiometricType::AccelerationZ, accZ));
        notifyData(BiometricSample(BiometricType::AlphaWaves, alpha));
        notifyData(BiometricSample(BiometricType::BetaWaves, beta));
    }
};

//==============================================================================
// Bio Modulation Mapping
//==============================================================================

struct BioModulationMapping
{
    BiometricType sourceType = BiometricType::HeartRate;
    std::string targetParameter;        // e.g., "tempo", "filter_cutoff"

    double inputMin = 50.0;             // Input range min (e.g., 50 BPM)
    double inputMax = 120.0;            // Input range max
    double outputMin = 0.0;             // Output range min
    double outputMax = 1.0;             // Output range max

    bool inverted = false;              // Invert the mapping
    double smoothing = 0.9;             // Smoothing factor (0-1)
    double sensitivity = 1.0;           // Multiplier for response

    bool isActive = true;

    double mapValue(double input) const
    {
        if (!isActive) return outputMin;

        // Clamp input to range
        double normalized = (input - inputMin) / (inputMax - inputMin);
        normalized = std::clamp(normalized, 0.0, 1.0);

        // Apply inversion
        if (inverted)
            normalized = 1.0 - normalized;

        // Apply sensitivity curve
        normalized = std::pow(normalized, 1.0 / sensitivity);

        // Map to output range
        return outputMin + normalized * (outputMax - outputMin);
    }
};

//==============================================================================
// Wearable Manager
//==============================================================================

class WearableManager
{
public:
    using DataCallback = std::function<void(BiometricType, double)>;

    static WearableManager& getInstance()
    {
        static WearableManager instance;
        return instance;
    }

    //--------------------------------------------------------------------------
    // Device Management
    //--------------------------------------------------------------------------

    void addDevice(std::unique_ptr<WearableDevice> device)
    {
        auto* ptr = device.get();

        // Setup callbacks
        device->setDataCallback([this, ptr](const BiometricSample& sample)
        {
            handleIncomingData(ptr, sample);
        });

        device->setConnectionCallback([this, ptr](bool connected)
        {
            handleConnectionChange(ptr, connected);
        });

        devices.push_back(std::move(device));
    }

    void removeDevice(WearableDevice* device)
    {
        device->disconnect();
        devices.erase(
            std::remove_if(devices.begin(), devices.end(),
                [device](const auto& d) { return d.get() == device; }),
            devices.end());
    }

    std::vector<WearableDevice*> getDevices() const
    {
        std::vector<WearableDevice*> result;
        for (const auto& d : devices)
            result.push_back(d.get());
        return result;
    }

    std::vector<WearableDevice*> getConnectedDevices() const
    {
        std::vector<WearableDevice*> result;
        for (const auto& d : devices)
        {
            if (d->isConnected())
                result.push_back(d.get());
        }
        return result;
    }

    //--------------------------------------------------------------------------
    // Data Access
    //--------------------------------------------------------------------------

    double getLatestValue(BiometricType type) const
    {
        auto it = latestValues.find(type);
        if (it != latestValues.end())
            return it->second;
        return 0.0;
    }

    double getSmoothedValue(BiometricType type) const
    {
        auto it = smoothedValues.find(type);
        if (it != smoothedValues.end())
            return it->second;
        return getLatestValue(type);
    }

    std::deque<BiometricSample> getHistory(BiometricType type, int maxSamples = 100) const
    {
        auto it = sampleHistory.find(type);
        if (it != sampleHistory.end())
        {
            const auto& history = it->second;
            int count = std::min(maxSamples, static_cast<int>(history.size()));
            return std::deque<BiometricSample>(history.end() - count, history.end());
        }
        return {};
    }

    void setDataCallback(DataCallback callback)
    {
        userDataCallback = callback;
    }

    //--------------------------------------------------------------------------
    // Modulation Mappings
    //--------------------------------------------------------------------------

    void addMapping(const BioModulationMapping& mapping)
    {
        mappings.push_back(mapping);
    }

    void removeMapping(size_t index)
    {
        if (index < mappings.size())
            mappings.erase(mappings.begin() + index);
    }

    void clearMappings()
    {
        mappings.clear();
    }

    std::vector<BioModulationMapping>& getMappings() { return mappings; }

    double getMappedValue(const std::string& targetParam) const
    {
        for (const auto& mapping : mappings)
        {
            if (mapping.targetParameter == targetParam && mapping.isActive)
            {
                double input = getSmoothedValue(mapping.sourceType);
                return mapping.mapValue(input);
            }
        }
        return 0.0;
    }

    //--------------------------------------------------------------------------
    // Bio-Tempo Sync
    //--------------------------------------------------------------------------

    // Get tempo that follows heart rate
    double getBioTempo() const
    {
        double hr = getSmoothedValue(BiometricType::HeartRate);
        if (hr < 40.0 || hr > 200.0) return 120.0;  // Fallback

        // Quantize to musically useful tempos
        // HR 60 -> 120 BPM (double time)
        // HR 70 -> 140 BPM
        // HR 80 -> 80 BPM (same) or 160 BPM (double)

        // Simple mapping: tempo = heart rate * multiplier
        double tempo = hr;

        // Keep in musical range 60-180 BPM
        while (tempo < 60.0) tempo *= 2.0;
        while (tempo > 180.0) tempo /= 2.0;

        return tempo;
    }

    // Get subdivision feel based on energy
    int getBioSubdivision() const
    {
        double energy = getSmoothedValue(BiometricType::EnergyLevel);
        double stress = getSmoothedValue(BiometricType::StressLevel);

        // High energy + high stress = faster subdivisions
        double factor = (energy + stress) / 200.0;

        if (factor > 0.7) return 16;      // 16th notes
        if (factor > 0.5) return 8;       // 8th notes
        if (factor > 0.3) return 4;       // Quarter notes
        return 2;                          // Half notes
    }

    //--------------------------------------------------------------------------
    // Haptic Feedback
    //--------------------------------------------------------------------------

    void sendHapticToAll(float intensity, int durationMs)
    {
        for (auto& device : devices)
        {
            if (device->isConnected() && device->supportsHapticFeedback())
            {
                device->sendHapticPulse(intensity, durationMs);
            }
        }
    }

    // Haptic metronome - pulse on beat
    void pulseOnBeat(int beatNumber, int beatsPerBar)
    {
        float intensity = (beatNumber == 1) ? 1.0f : 0.5f;
        int duration = (beatNumber == 1) ? 50 : 30;
        sendHapticToAll(intensity, duration);
    }

    //--------------------------------------------------------------------------
    // Smoothing Configuration
    //--------------------------------------------------------------------------

    void setSmoothingFactor(double factor)
    {
        smoothingFactor = std::clamp(factor, 0.0, 0.999);
    }

    void setHistorySize(int size)
    {
        maxHistorySize = std::max(10, size);
    }

private:
    WearableManager() = default;

    std::vector<std::unique_ptr<WearableDevice>> devices;
    std::vector<BioModulationMapping> mappings;

    std::map<BiometricType, double> latestValues;
    std::map<BiometricType, double> smoothedValues;
    std::map<BiometricType, std::deque<BiometricSample>> sampleHistory;

    DataCallback userDataCallback;

    double smoothingFactor = 0.9;
    int maxHistorySize = 300;  // ~30 seconds at 10Hz

    void handleIncomingData(WearableDevice* device, const BiometricSample& sample)
    {
        // Store latest value
        latestValues[sample.type] = sample.value;

        // Apply smoothing
        double& smoothed = smoothedValues[sample.type];
        smoothed = smoothed * smoothingFactor + sample.value * (1.0 - smoothingFactor);

        // Store in history
        auto& history = sampleHistory[sample.type];
        history.push_back(sample);
        while (static_cast<int>(history.size()) > maxHistorySize)
            history.pop_front();

        // Notify user callback
        if (userDataCallback)
            userDataCallback(sample.type, sample.value);
    }

    void handleConnectionChange(WearableDevice* device, bool connected)
    {
        // Could emit an event here for UI updates
    }
};

//==============================================================================
// Bio Data Visualizer Component
//==============================================================================

class BioDataVisualizerComponent : public juce::Component,
                                    public juce::Timer
{
public:
    BioDataVisualizerComponent()
    {
        startTimerHz(30);
    }

    void setMetricToDisplay(BiometricType metric)
    {
        displayedMetric = metric;
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();

        // Background
        g.fillAll(juce::Colour(0xff1a1a2e));

        // Get history
        auto& manager = WearableManager::getInstance();
        auto history = manager.getHistory(displayedMetric, static_cast<int>(bounds.getWidth()));

        if (history.empty())
        {
            g.setColour(juce::Colours::grey);
            g.drawText("No data", bounds, juce::Justification::centred);
            return;
        }

        // Find range
        double minVal = history[0].value;
        double maxVal = history[0].value;
        for (const auto& sample : history)
        {
            minVal = std::min(minVal, sample.value);
            maxVal = std::max(maxVal, sample.value);
        }

        // Add padding
        double range = maxVal - minVal;
        if (range < 0.001) range = 1.0;
        minVal -= range * 0.1;
        maxVal += range * 0.1;

        // Draw waveform
        juce::Path path;
        float x = 0;
        float step = bounds.getWidth() / static_cast<float>(history.size());

        for (size_t i = 0; i < history.size(); ++i)
        {
            double normalized = (history[i].value - minVal) / (maxVal - minVal);
            float y = bounds.getBottom() - normalized * bounds.getHeight();

            if (i == 0)
                path.startNewSubPath(x, y);
            else
                path.lineTo(x, y);

            x += step;
        }

        // Draw path
        g.setColour(juce::Colour(0xff00ff88));
        g.strokePath(path, juce::PathStrokeType(2.0f));

        // Current value
        double current = manager.getSmoothedValue(displayedMetric);
        g.setColour(juce::Colours::white);
        g.setFont(24.0f);

        juce::String valueText;
        switch (displayedMetric)
        {
            case BiometricType::HeartRate:
                valueText = juce::String(current, 0) + " BPM";
                break;
            case BiometricType::HeartRateVariability:
                valueText = juce::String(current, 1) + " ms";
                break;
            case BiometricType::StressLevel:
            case BiometricType::EnergyLevel:
                valueText = juce::String(current, 0) + "%";
                break;
            default:
                valueText = juce::String(current, 2);
        }

        g.drawText(valueText, bounds.removeFromTop(40), juce::Justification::centred);

        // Metric name
        g.setFont(14.0f);
        g.setColour(juce::Colours::grey);
        g.drawText(biometricTypeToString(displayedMetric),
                   bounds.removeFromTop(20), juce::Justification::centred);
    }

    void timerCallback() override
    {
        repaint();
    }

private:
    BiometricType displayedMetric = BiometricType::HeartRate;
};

//==============================================================================
// Wearable Settings Panel
//==============================================================================

class WearableSettingsPanel : public juce::Component
{
public:
    WearableSettingsPanel()
    {
        addAndMakeVisible(titleLabel);
        titleLabel.setText("Wearable Devices", juce::dontSendNotification);
        titleLabel.setFont(juce::Font(20.0f, juce::Font::bold));

        addAndMakeVisible(scanButton);
        scanButton.setButtonText("Scan for Devices");
        scanButton.onClick = [this]() { scanForDevices(); };

        addAndMakeVisible(simulatorButton);
        simulatorButton.setButtonText("Add Simulator");
        simulatorButton.onClick = [this]() { addSimulator(); };

        addAndMakeVisible(deviceList);

        addAndMakeVisible(visualizer);

        refreshDeviceList();
    }

    void resized() override
    {
        auto bounds = getLocalBounds().reduced(10);

        titleLabel.setBounds(bounds.removeFromTop(30));
        bounds.removeFromTop(10);

        auto buttonRow = bounds.removeFromTop(30);
        scanButton.setBounds(buttonRow.removeFromLeft(120));
        buttonRow.removeFromLeft(10);
        simulatorButton.setBounds(buttonRow.removeFromLeft(120));

        bounds.removeFromTop(10);

        deviceList.setBounds(bounds.removeFromTop(150));
        bounds.removeFromTop(10);

        visualizer.setBounds(bounds);
    }

private:
    juce::Label titleLabel;
    juce::TextButton scanButton;
    juce::TextButton simulatorButton;
    juce::ListBox deviceList;
    BioDataVisualizerComponent visualizer;

    void scanForDevices()
    {
        // In production: scan BLE for compatible devices
        // For now, just refresh list
        refreshDeviceList();
    }

    void addSimulator()
    {
        auto simulator = std::make_unique<SimulatorDevice>();
        simulator->connect();
        simulator->startStreaming();
        WearableManager::getInstance().addDevice(std::move(simulator));
        refreshDeviceList();
    }

    void refreshDeviceList()
    {
        // Update device list UI
        deviceList.updateContent();
    }
};

} // namespace Wearable
} // namespace Echoelmusic
