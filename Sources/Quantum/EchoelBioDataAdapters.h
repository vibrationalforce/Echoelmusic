#pragma once

#include <JuceHeader.h>
#include <juce_osc/juce_osc.h>
#include "EchoelQuantumCore.h"

/**
 * EchoelBioDataAdapters - Hardware Integration for Bio-Sensors
 *
 * Provides unified adapters for various bio-data sources:
 * - Apple Watch (HealthKit)
 * - Polar H10 (Bluetooth HRM)
 * - Muse Headband (EEG)
 * - Emotiv EPOC (Professional EEG)
 * - NeuroSky MindWave (Consumer EEG)
 * - WebSocket/OSC/MIDI streams
 *
 * ARCHITECTURE:
 * - Each adapter implements IBioDataAdapter interface
 * - Adapters convert device-specific data to QuantumBioState
 * - Real-time streaming with minimal latency
 * - Error handling and connection recovery
 */

//==============================================================================
// Base Adapter Interface
//==============================================================================

class IBioDataAdapter
{
public:
    virtual ~IBioDataAdapter() = default;

    /**
     * Connect to bio-data source
     */
    virtual bool connect(const juce::String& config) = 0;

    /**
     * Disconnect from source
     */
    virtual void disconnect() = 0;

    /**
     * Check connection status
     */
    virtual bool isConnected() const = 0;

    /**
     * Get current bio-state
     */
    virtual EchoelQuantumCore::QuantumBioState getCurrentState() const = 0;

    /**
     * Start/Stop streaming
     */
    virtual void startStreaming() = 0;
    virtual void stopStreaming() = 0;

    /**
     * Get adapter info
     */
    virtual juce::String getAdapterName() const = 0;
    virtual juce::String getDeviceName() const = 0;
    virtual float getBatteryLevel() const { return 1.0f; }  // Optional
};

//==============================================================================
// 1. Apple Watch / HealthKit Adapter (iOS/macOS)
//==============================================================================

class EchoelAppleWatchAdapter : public IBioDataAdapter
{
public:
    EchoelAppleWatchAdapter();
    ~EchoelAppleWatchAdapter() override;

    bool connect(const juce::String& config) override;
    void disconnect() override;
    bool isConnected() const override { return connected; }

    EchoelQuantumCore::QuantumBioState getCurrentState() const override;

    void startStreaming() override;
    void stopStreaming() override;

    juce::String getAdapterName() const override { return "Apple Watch (HealthKit)"; }
    juce::String getDeviceName() const override { return deviceName; }
    float getBatteryLevel() const override { return batteryLevel; }

    /**
     * HealthKit-specific queries
     */
    void requestHeartRateAuthorization();
    void requestHRVAuthorization();
    void startHeartRateQuery();
    void startHRVQuery();

private:
    bool connected = false;
    bool streaming = false;
    juce::String deviceName = "Apple Watch";
    float batteryLevel = 1.0f;

    EchoelQuantumCore::QuantumBioState currentState;

    // HealthKit data
    std::vector<double> heartbeatTimestamps;
    std::vector<float> rrIntervals;

    void processHeartRateData(double timestamp, float bpm);
    void processHRVData(float sdnn, float rmssd);
};

//==============================================================================
// 2. Polar H10 Bluetooth HRM Adapter
//==============================================================================

class EchoelPolarH10Adapter : public IBioDataAdapter
{
public:
    EchoelPolarH10Adapter();
    ~EchoelPolarH10Adapter() override;

    bool connect(const juce::String& config) override;
    void disconnect() override;
    bool isConnected() const override { return connected; }

    EchoelQuantumCore::QuantumBioState getCurrentState() const override;

    void startStreaming() override;
    void stopStreaming() override;

    juce::String getAdapterName() const override { return "Polar H10 (Bluetooth HRM)"; }
    juce::String getDeviceName() const override { return deviceName; }
    float getBatteryLevel() const override { return batteryLevel; }

    /**
     * Bluetooth scanning
     */
    void scanForDevices();
    std::vector<juce::String> getAvailableDevices() const;
    bool connectToDevice(const juce::String& deviceID);

private:
    bool connected = false;
    bool streaming = false;
    juce::String deviceName = "Polar H10";
    juce::String deviceId;
    float batteryLevel = 1.0f;

    EchoelQuantumCore::QuantumBioState currentState;

    // Bluetooth connection
    std::vector<juce::String> discoveredDevices;

    void processRRInterval(float rrMs);
    void calculateHRVMetrics();
};

//==============================================================================
// 3. Muse Headband EEG Adapter
//==============================================================================

class EchoelMuseAdapter : public IBioDataAdapter
{
public:
    EchoelMuseAdapter();
    ~EchoelMuseAdapter() override;

    bool connect(const juce::String& config) override;
    void disconnect() override;
    bool isConnected() const override { return connected; }

    EchoelQuantumCore::QuantumBioState getCurrentState() const override;

    void startStreaming() override;
    void stopStreaming() override;

    juce::String getAdapterName() const override { return "Muse Headband (EEG)"; }
    juce::String getDeviceName() const override { return deviceName; }
    float getBatteryLevel() const override { return batteryLevel; }

    /**
     * Muse-specific features
     */
    enum class Electrode { TP9, AF7, AF8, TP10 };
    float getElectrodeQuality(Electrode electrode) const;
    bool isHeadbandFittedProperly() const;

private:
    bool connected = false;
    bool streaming = false;
    juce::String deviceName = "Muse";
    float batteryLevel = 1.0f;

    EchoelQuantumCore::QuantumBioState currentState;

    // EEG data (4 channels: TP9, AF7, AF8, TP10)
    std::array<std::vector<float>, 4> rawEEGChannels;
    std::array<float, 4> electrodeQuality;

    // Processed band powers
    float delta = 0.0f, theta = 0.0f, alpha = 0.0f, beta = 0.0f, gamma = 0.0f;

    void processEEGSample(int channel, float value);
    void calculateBandPowers();
    void updateBioState();
};

//==============================================================================
// 4. Emotiv EPOC+ Professional EEG Adapter
//==============================================================================

class EchoelEmotivAdapter : public IBioDataAdapter
{
public:
    EchoelEmotivAdapter();
    ~EchoelEmotivAdapter() override;

    bool connect(const juce::String& config) override;
    void disconnect() override;
    bool isConnected() const override { return connected; }

    EchoelQuantumCore::QuantumBioState getCurrentState() const override;

    void startStreaming() override;
    void stopStreaming() override;

    juce::String getAdapterName() const override { return "Emotiv EPOC+ (Professional EEG)"; }
    juce::String getDeviceName() const override { return deviceName; }
    float getBatteryLevel() const override { return batteryLevel; }

    /**
     * Emotiv-specific features (14 channels)
     */
    enum class Electrode
    {
        AF3, F7, F3, FC5, T7, P7, O1,
        AF4, F8, F4, FC6, T8, P8, O2
    };

    float getElectrodeQuality(Electrode electrode) const;

    /**
     * Performance metrics (Emotiv SDK)
     */
    float getEngagement() const;
    float getExcitement() const;
    float getStress() const;
    float getRelaxation() const;
    float getFocus() const;
    float getInterest() const;

private:
    bool connected = false;
    bool streaming = false;
    juce::String deviceName = "Emotiv EPOC+";
    float batteryLevel = 1.0f;

    EchoelQuantumCore::QuantumBioState currentState;

    // 14-channel EEG
    std::array<std::vector<float>, 14> rawEEGChannels;
    std::array<float, 14> electrodeQuality;

    // Performance metrics
    float engagement = 0.5f;
    float excitement = 0.5f;
    float stress = 0.5f;
    float relaxation = 0.5f;
    float focus = 0.5f;
    float interest = 0.5f;

    void processEEGSample(int channel, float value);
    void calculatePerformanceMetrics();
    void updateBioState();
};

//==============================================================================
// 5. WebSocket Bio-Data Adapter (Custom streams)
//==============================================================================

class EchoelWebSocketAdapter : public IBioDataAdapter
{
public:
    EchoelWebSocketAdapter();
    ~EchoelWebSocketAdapter() override;

    bool connect(const juce::String& config) override;  // config = "ws://host:port"
    void disconnect() override;
    bool isConnected() const override { return connected; }

    EchoelQuantumCore::QuantumBioState getCurrentState() const override;

    void startStreaming() override;
    void stopStreaming() override;

    juce::String getAdapterName() const override { return "WebSocket Stream"; }
    juce::String getDeviceName() const override { return serverUrl; }

    /**
     * Expected JSON format:
     * {
     *   "hrv": 0.5,
     *   "coherence": 0.7,
     *   "stress": 0.3,
     *   "delta": 0.2, "theta": 0.3, "alpha": 0.5, "beta": 0.4, "gamma": 0.1
     * }
     */
    void processMessage(const juce::String& jsonMessage);

private:
    bool connected = false;
    bool streaming = false;
    juce::String serverUrl;

    EchoelQuantumCore::QuantumBioState currentState;

    // WebSocket implementation (to be added when needed)
    // std::unique_ptr<juce::WebSocket> webSocket;
};

//==============================================================================
// 6. OSC Bio-Data Adapter
//==============================================================================

class EchoelOSCAdapter : public IBioDataAdapter,
                          public juce::OSCReceiver::Listener<juce::OSCReceiver::MessageLoopCallback>
{
public:
    EchoelOSCAdapter();
    ~EchoelOSCAdapter() override;

    bool connect(const juce::String& config) override;  // config = "port:8000"
    void disconnect() override;
    bool isConnected() const override { return connected; }

    EchoelQuantumCore::QuantumBioState getCurrentState() const override;

    void startStreaming() override;
    void stopStreaming() override;

    juce::String getAdapterName() const override { return "OSC Stream"; }
    juce::String getDeviceName() const override { return "OSC Port " + juce::String(port); }

    /**
     * Expected OSC messages:
     * /bio/hrv <float>
     * /bio/coherence <float>
     * /bio/stress <float>
     * /bio/alpha <float>
     * /bio/beta <float>
     * etc.
     */
    void oscMessageReceived(const juce::OSCMessage& message) override;

private:
    bool connected = false;
    bool streaming = false;
    int port = 8000;

    EchoelQuantumCore::QuantumBioState currentState;

    std::unique_ptr<juce::OSCReceiver> oscReceiver;
};

//==============================================================================
// 7. MIDI CC Bio-Data Adapter (Use MIDI controllers as bio-data)
//==============================================================================

class EchoelMIDIAdapter : public IBioDataAdapter,
                           public juce::MidiInputCallback
{
public:
    EchoelMIDIAdapter();
    ~EchoelMIDIAdapter() override;

    bool connect(const juce::String& config) override;  // config = MIDI device name
    void disconnect() override;
    bool isConnected() const override { return connected; }

    EchoelQuantumCore::QuantumBioState getCurrentState() const override;

    void startStreaming() override;
    void stopStreaming() override;

    juce::String getAdapterName() const override { return "MIDI CC Mapper"; }
    juce::String getDeviceName() const override { return midiDeviceName; }

    /**
     * Map MIDI CC to bio-parameters
     * Example: CC 1 (Mod Wheel) -> HRV
     *          CC 2 (Breath) -> Alpha waves
     */
    void mapCC(int ccNumber, const juce::String& bioParameter);

    void handleIncomingMidiMessage(juce::MidiInput* source, const juce::MidiMessage& message) override;

private:
    bool connected = false;
    bool streaming = false;
    juce::String midiDeviceName;

    EchoelQuantumCore::QuantumBioState currentState;

    std::unique_ptr<juce::MidiInput> midiInput;
    std::map<int, juce::String> ccMappings;  // CC number -> bio parameter

    void updateBioParameter(const juce::String& parameter, float value);
};

//==============================================================================
// Adapter Factory
//==============================================================================

class EchoelBioDataAdapterFactory
{
public:
    /**
     * Create adapter for specified source
     */
    static std::unique_ptr<IBioDataAdapter> createAdapter(
        EchoelQuantumCore::BioDataSource source);

    /**
     * Get list of available adapters on this platform
     */
    static std::vector<EchoelQuantumCore::BioDataSource> getAvailableAdapters();

    /**
     * Auto-detect and connect to any available bio-data source
     */
    static std::unique_ptr<IBioDataAdapter> autoDetect();
};
