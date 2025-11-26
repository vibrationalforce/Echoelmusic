#pragma once

#include <JuceHeader.h>

/**
 * UniversalDeviceManager - Hardware/Device Integration for ALL Technology
 *
 * KOMPATIBILITÄT:
 * - Legacy Devices (alte MIDI-Controller, Vintage Synths)
 * - Current Technology (DJ-Equipment, Modular Synths, MIDI 2.0)
 * - Future Technology (Brain-Computer Interfaces, Neuralink-ähnlich)
 * - Elon Musk Tech (Neural interfaces, haptic feedback, biometric sensors)
 *
 * SUPPORTED DEVICES:
 * - DJ Equipment: CDJs, Mixers, Controllers (Pioneer, Native Instruments, etc.)
 * - Modular Synths: Eurorack, Buchla, Moog, Serge
 * - MIDI Controllers: Keyboards, Pads, Faders, Knobs
 * - Audio Interfaces: USB, Thunderbolt, PCIe, Network Audio (Dante, AES67)
 * - Haptic Devices: Force feedback, tactile surfaces
 * - Biometric Sensors: Heart rate, EEG, GSR, temperature
 * - Brain-Computer Interfaces: Neural signals, thought control
 * - Motion Sensors: Accelerometers, gyroscopes, gesture control
 * - Light Controllers: DMX, Art-Net, LED matrices
 * - Future Devices: Quantum sensors, neural implants, holographic interfaces
 *
 * PROTOCOLS:
 * - MIDI 1.0 & 2.0
 * - OSC (Open Sound Control)
 * - Ableton Link
 * - DMX512, Art-Net
 * - Modular CV/Gate
 * - USB, Bluetooth, WiFi
 * - Thunderbolt, PCIe
 * - Network Audio (Dante, AES67, Ravenna)
 * - BCI Protocols (OpenBCI, NeuroSky, Emotiv)
 *
 * INCLUSIVE DESIGN:
 * - Adaptive interfaces for disabilities
 * - Voice control
 * - Eye tracking
 * - One-handed operation modes
 * - High-contrast modes
 * - Screen reader support
 *
 * Usage:
 * ```cpp
 * UniversalDeviceManager deviceManager;
 *
 * // Auto-detect all connected devices
 * deviceManager.scanAllDevices();
 *
 * // DJ Equipment
 * auto cdj = deviceManager.getDJController("Pioneer CDJ-3000");
 * cdj->syncTempo(128.0f);
 *
 * // Modular Synth
 * auto modular = deviceManager.getModularSynth("Eurorack");
 * modular->sendCV(0, 5.0f);  // 5V to output 0
 *
 * // Brain-Computer Interface
 * auto bci = deviceManager.getBCI("Neural Interface");
 * bci->onThoughtDetected = [](const Thought& thought) {
 *     // Control music with thoughts!
 * };
 * ```
 */

//==============================================================================
// Device Types
//==============================================================================

enum class DeviceCategory
{
    // Traditional
    MIDIController,         // Keyboards, pads, controllers
    AudioInterface,         // Sound cards, audio I/O
    DJEquipment,           // CDJs, mixers, DJ controllers
    ModularSynth,          // Eurorack, Buchla, Moog

    // Modern
    NetworkAudio,          // Dante, AES67, Ravenna
    LightController,       // DMX, Art-Net, LEDs
    HapticDevice,          // Force feedback, tactile

    // Biometric
    HeartRateMonitor,      // Fitness trackers, chest straps
    EEGDevice,             // Brain wave sensors
    GSRSensor,             // Galvanic skin response
    MotionSensor,          // Accelerometers, gyroscopes

    // Future Tech
    BrainComputerInterface,  // Neural implants, Neuralink-like
    QuantumSensor,          // Quantum-based measurement
    HolographicInterface,   // 3D holographic control
    NeuralImplant,         // Direct brain integration

    // Accessibility
    EyeTracker,            // Eye gaze control
    VoiceController,       // Voice commands
    AdaptiveController,    // Custom adaptive interfaces

    Unknown
};

enum class DeviceCompatibility
{
    Legacy,                // Old devices (pre-2000)
    Current,               // Modern devices (2000-2030)
    Future,                // Future devices (2030+)
    Universal              // Works with all
};

//==============================================================================
// Device Information
//==============================================================================

struct DeviceInfo
{
    juce::String name;
    juce::String manufacturer;
    juce::String model;
    juce::String serialNumber;
    juce::String firmwareVersion;

    DeviceCategory category;
    DeviceCompatibility compatibility;

    bool isConnected = false;
    bool isActive = false;
    bool supportsHotSwap = true;
    bool requiresCalibration = false;

    // Capabilities
    juce::StringArray supportedProtocols;
    int numInputs = 0;
    int numOutputs = 0;
    int numChannels = 0;
    double sampleRate = 48000.0;
    int bitDepth = 24;

    // Latency info
    double inputLatencyMs = 0.0;
    double outputLatencyMs = 0.0;
    double roundTripLatencyMs = 0.0;

    // Power/Battery
    bool batteryPowered = false;
    int batteryPercent = 100;

    juce::String getDescription() const;
};

//==============================================================================
// Base Device Interface
//==============================================================================

class UniversalDevice
{
public:
    virtual ~UniversalDevice() = default;

    virtual DeviceInfo getInfo() const = 0;
    virtual bool connect() = 0;
    virtual void disconnect() = 0;
    virtual bool isConnected() const = 0;

    virtual void update(double deltaTime) = 0;
    virtual void calibrate() = 0;

    std::function<void(const juce::String& message)> onStatusChange;
    std::function<void(const juce::String& error)> onError;
    std::function<void()> onDisconnected;
};

//==============================================================================
// DJ Equipment
//==============================================================================

class DJController : public UniversalDevice
{
public:
    virtual ~DJController() = default;

    // Tempo & Sync
    virtual void syncTempo(float bpm) = 0;
    virtual float getCurrentTempo() const = 0;
    virtual void syncWithAbletonLink(bool enable) = 0;

    // Transport
    virtual void play() = 0;
    virtual void pause() = 0;
    virtual void cue() = 0;
    virtual void sync() = 0;

    // Pitch/Tempo control
    virtual void setPitchBend(float amount) = 0;  // -1 to +1
    virtual void setTempoBend(float amount) = 0;

    // Effects
    virtual void setFilterCutoff(float value) = 0;  // 0-1
    virtual void setFilterResonance(float value) = 0;
    virtual void triggerEffect(int effectID) = 0;

    // Waveform/Display
    virtual juce::AudioBuffer<float> getWaveform() const = 0;
    virtual double getCurrentPosition() const = 0;  // 0-1

    // Callbacks
    std::function<void(float bpm)> onTempoChange;
    std::function<void(bool playing)> onPlayStateChange;
    std::function<void(double position)> onPositionChange;
};

//==============================================================================
// Modular Synth
//==============================================================================

class ModularSynth : public UniversalDevice
{
public:
    virtual ~ModularSynth() = default;

    // CV (Control Voltage)
    virtual void sendCV(int output, float voltage) = 0;  // 0-10V
    virtual float readCV(int input) = 0;

    // Gate/Trigger
    virtual void sendGate(int output, bool state) = 0;
    virtual bool readGate(int input) = 0;
    virtual void sendTrigger(int output) = 0;  // Short pulse

    // Clock
    virtual void sendClock(int output, float bpm) = 0;
    virtual void sendReset(int output) = 0;

    // Patch Management
    virtual void savePatch(const juce::String& name) = 0;
    virtual void loadPatch(const juce::String& name) = 0;
    virtual juce::StringArray getSavedPatches() const = 0;

    // Callbacks
    std::function<void(int input, float voltage)> onCVReceived;
    std::function<void(int input, bool state)> onGateReceived;
    std::function<void(int input)> onTriggerReceived;
};

//==============================================================================
// Brain-Computer Interface (BCI)
//==============================================================================

struct Thought
{
    enum class Type
    {
        Focus,              // Concentration level
        Relaxation,         // Calm state
        Excitement,         // High energy
        Meditation,         // Deep calm
        Creativity,         // Creative state
        Command,            // Specific mental command
        Unknown
    };

    Type type;
    float intensity = 0.0f;     // 0-1
    float confidence = 0.0f;    // How confident is detection
    juce::String description;

    // Raw brain wave data (optional)
    float delta = 0.0f;         // 0.5-4 Hz (deep sleep)
    float theta = 0.0f;         // 4-8 Hz (drowsiness, meditation)
    float alpha = 0.0f;         // 8-13 Hz (relaxed awareness)
    float beta = 0.0f;          // 13-30 Hz (active thinking)
    float gamma = 0.0f;         // 30-100 Hz (high-level cognition)
};

class BrainComputerInterface : public UniversalDevice
{
public:
    virtual ~BrainComputerInterface() = default;

    // Thought Detection
    virtual Thought getCurrentThought() const = 0;
    virtual juce::Array<Thought> getRecentThoughts(int numSeconds) const = 0;

    // Brain Wave Monitoring
    virtual float getDeltaWave() const = 0;      // Deep sleep
    virtual float getThetaWave() const = 0;      // Meditation
    virtual float getAlphaWave() const = 0;      // Relaxed
    virtual float getBetaWave() const = 0;       // Active
    virtual float getGammaWave() const = 0;      // Peak cognition

    // Mental State
    virtual float getFocusLevel() const = 0;      // 0-1
    virtual float getRelaxationLevel() const = 0;  // 0-1
    virtual float getStressLevel() const = 0;      // 0-1

    // Commands (trained mental commands)
    virtual void trainCommand(const juce::String& commandName) = 0;
    virtual bool detectCommand(const juce::String& commandName) = 0;
    virtual juce::StringArray getTrainedCommands() const = 0;

    // Callbacks
    std::function<void(const Thought& thought)> onThoughtDetected;
    std::function<void(const juce::String& command)> onCommandDetected;
    std::function<void(float focus, float relaxation)> onMentalStateChange;
};

//==============================================================================
// Biometric Sensors
//==============================================================================

struct BiometricData
{
    // Heart
    int heartRateBPM = 0;
    float heartRateVariability = 0.0f;  // HRV (ms)

    // Skin
    float galvanicSkinResponse = 0.0f;  // μS
    float skinTemperature = 0.0f;       // °C

    // Movement
    juce::Vector3D<float> acceleration;
    juce::Vector3D<float> rotation;
    juce::Vector3D<float> magneticField;

    // Breath
    int breathsPerMinute = 0;
    float breathDepth = 0.0f;           // 0-1

    // Derived
    float arousalLevel = 0.0f;          // 0-1 (calculated from GSR + HR)
    float stressLevel = 0.0f;           // 0-1
    float energyLevel = 0.0f;           // 0-1
};

class BiometricSensor : public UniversalDevice
{
public:
    virtual ~BiometricSensor() = default;

    virtual BiometricData getCurrentData() const = 0;
    virtual juce::Array<BiometricData> getHistoricalData(int seconds) const = 0;

    // Specific readings
    virtual int getHeartRate() const = 0;
    virtual float getGSR() const = 0;
    virtual float getTemperature() const = 0;
    virtual juce::Vector3D<float> getAcceleration() const = 0;

    // Analysis
    virtual float getStressLevel() const = 0;
    virtual float getArousalLevel() const = 0;
    virtual bool isMoving() const = 0;

    std::function<void(const BiometricData& data)> onDataUpdate;
    std::function<void(float stress)> onStressChange;
};

//==============================================================================
// Network Audio Devices
//==============================================================================

class NetworkAudioDevice : public UniversalDevice
{
public:
    enum class Protocol
    {
        Dante,              // Audinate Dante
        AES67,              // AES67 standard
        Ravenna,            // Ravenna/AES67
        AVB,                // Audio Video Bridging
        NDI,                // Network Device Interface (video+audio)
        SMPTE2110           // SMPTE ST 2110 (broadcast)
    };

    virtual ~NetworkAudioDevice() = default;

    virtual Protocol getProtocol() const = 0;
    virtual juce::IPAddress getIPAddress() const = 0;
    virtual int getPort() const = 0;

    virtual void routeAudio(int inputChannel, int outputChannel) = 0;
    virtual void setLatencyMode(bool lowLatency) = 0;

    virtual int getNetworkLatencyMs() const = 0;
    virtual float getPacketLossPercent() const = 0;
};

//==============================================================================
// Accessibility Devices
//==============================================================================

class AccessibilityDevice : public UniversalDevice
{
public:
    virtual ~AccessibilityDevice() = default;

    // Eye Tracking
    virtual juce::Point<float> getGazePosition() const = 0;  // Normalized 0-1
    virtual bool isBlinking() const = 0;
    virtual float getEyeOpenness() const = 0;  // 0-1

    // Voice Control
    virtual void startListening() = 0;
    virtual void stopListening() = 0;
    virtual bool isListening() const = 0;

    // Gesture
    virtual juce::String getCurrentGesture() const = 0;

    // Adaptive
    virtual void setOneHandedMode(bool enable) = 0;
    virtual void setHighContrastMode(bool enable) = 0;
    virtual void setLargeTextMode(bool enable) = 0;

    std::function<void(const juce::Point<float>& gazePos)> onGazeMove;
    std::function<void(const juce::String& command)> onVoiceCommand;
    std::function<void(const juce::String& gesture)> onGestureDetected;
};

//==============================================================================
// UniversalDeviceManager - Main Class
//==============================================================================

class UniversalDeviceManager
{
public:
    UniversalDeviceManager();
    ~UniversalDeviceManager();

    //==========================================================================
    // Device Discovery
    //==========================================================================

    /** Scan for all connected devices */
    void scanAllDevices();

    /** Get all detected devices */
    juce::Array<DeviceInfo> getAllDevices() const;

    /** Get devices by category */
    juce::Array<DeviceInfo> getDevicesByCategory(DeviceCategory category) const;

    /** Get device by name */
    DeviceInfo getDeviceInfo(const juce::String& deviceName) const;

    //==========================================================================
    // Device Access
    //==========================================================================

    /** Get DJ controller */
    std::shared_ptr<DJController> getDJController(const juce::String& name);

    /** Get modular synth */
    std::shared_ptr<ModularSynth> getModularSynth(const juce::String& name);

    /** Get brain-computer interface */
    std::shared_ptr<BrainComputerInterface> getBCI(const juce::String& name);

    /** Get biometric sensor */
    std::shared_ptr<BiometricSensor> getBiometricSensor(const juce::String& name);

    /** Get network audio device */
    std::shared_ptr<NetworkAudioDevice> getNetworkAudioDevice(const juce::String& name);

    /** Get accessibility device */
    std::shared_ptr<AccessibilityDevice> getAccessibilityDevice(const juce::String& name);

    /** Get any device */
    std::shared_ptr<UniversalDevice> getDevice(const juce::String& name);

    //==========================================================================
    // Auto-Configuration
    //==========================================================================

    /** Auto-configure optimal settings for current devices */
    void autoConfigureAll();

    /** Detect and setup all DJ equipment */
    void autoSetupDJEquipment();

    /** Detect and setup all biometric sensors */
    void autoSetupBiometrics();

    /** Detect and setup accessibility devices */
    void autoSetupAccessibility();

    //==========================================================================
    // Device Templates
    //==========================================================================

    /** Load device template (pre-configured settings) */
    bool loadDeviceTemplate(const juce::String& templateName);

    /** Save current device configuration as template */
    bool saveDeviceTemplate(const juce::String& templateName);

    /** Get available templates */
    juce::StringArray getAvailableTemplates() const;

    //==========================================================================
    // Cross-Device Sync
    //==========================================================================

    /** Sync tempo across all devices */
    void syncTempoAll(float bpm);

    /** Sync transport (play/stop) across all devices */
    void syncTransportAll(bool playing);

    /** Enable Ableton Link for all compatible devices */
    void enableAbletonLinkAll(bool enable);

    //==========================================================================
    // Future Tech Integration
    //==========================================================================

    /** Detect future/experimental devices */
    void scanFutureDevices();

    /** Enable quantum sensor integration */
    void enableQuantumSensors(bool enable);

    /** Enable neural interface */
    void enableNeuralInterface(bool enable);

    //==========================================================================
    // Inclusive Design
    //==========================================================================

    /** Enable accessibility features */
    void enableAccessibilityMode(bool enable);

    /** Set interaction mode */
    void setInteractionMode(const juce::String& mode);  // "standard", "one-handed", "voice", "eye-tracking"

    /** Get available accessibility features */
    juce::StringArray getAvailableAccessibilityFeatures() const;

    //==========================================================================
    // Monitoring
    //==========================================================================

    /** Get device status summary */
    juce::String getDeviceStatusSummary() const;

    /** Get total latency (all devices) */
    double getTotalSystemLatency() const;

    /** Check device health */
    bool checkDeviceHealth();

    //==========================================================================
    // Callbacks
    //==========================================================================

    std::function<void(const DeviceInfo& device)> onDeviceConnected;
    std::function<void(const DeviceInfo& device)> onDeviceDisconnected;
    std::function<void(const juce::String& message)> onStatusChange;
    std::function<void(const juce::String& error)> onError;

private:
    std::map<juce::String, std::shared_ptr<UniversalDevice>> devices;
    std::map<DeviceCategory, juce::Array<juce::String>> devicesByCategory;

    bool accessibilityMode = false;
    juce::String currentInteractionMode = "standard";

    void registerDevice(const juce::String& name, std::shared_ptr<UniversalDevice> device);
    void unregisterDevice(const juce::String& name);

    // Device detection
    void detectMIDIDevices();
    void detectAudioInterfaces();
    void detectDJEquipment();
    void detectModularSynths();
    void detectNetworkAudio();
    void detectBiometricSensors();
    void detectBCI();
    void detectAccessibilityDevices();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(UniversalDeviceManager)
};
