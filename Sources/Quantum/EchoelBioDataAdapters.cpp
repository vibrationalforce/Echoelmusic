#include "EchoelBioDataAdapters.h"

//==============================================================================
// 1. APPLE WATCH / HEALTHKIT ADAPTER (iOS/macOS)
//==============================================================================

EchoelAppleWatchAdapter::EchoelAppleWatchAdapter()
{
    // currentState.source = EchoelQuantumCore::BioDataSource::AppleWatch;
}

EchoelAppleWatchAdapter::~EchoelAppleWatchAdapter()
{
    disconnect();
}

bool EchoelAppleWatchAdapter::connect(const juce::String& config)
{
    // Platform check
    #if JUCE_IOS || JUCE_MAC

    // Request HealthKit authorization
    requestHeartRateAuthorization();
    requestHRVAuthorization();

    connected = true;
    deviceName = "Apple Watch";

    DBG("EchoelAppleWatchAdapter: Connected to Apple Watch via HealthKit");
    return true;

    #else

    DBG("EchoelAppleWatchAdapter: HealthKit only available on iOS/macOS");
    return false;

    #endif
}

void EchoelAppleWatchAdapter::disconnect()
{
    if (!connected)
        return;

    stopStreaming();
    connected = false;

    DBG("EchoelAppleWatchAdapter: Disconnected from Apple Watch");
}

EchoelQuantumCore::QuantumBioState EchoelAppleWatchAdapter::getCurrentState() const
{
    return currentState;
}

void EchoelAppleWatchAdapter::startStreaming()
{
    if (!connected)
    {
        DBG("EchoelAppleWatchAdapter: Cannot start streaming - not connected");
        return;
    }

    #if JUCE_IOS || JUCE_MAC

    startHeartRateQuery();
    startHRVQuery();
    streaming = true;

    DBG("EchoelAppleWatchAdapter: Started streaming bio-data");

    #endif
}

void EchoelAppleWatchAdapter::stopStreaming()
{
    streaming = false;
    DBG("EchoelAppleWatchAdapter: Stopped streaming");
}

void EchoelAppleWatchAdapter::requestHeartRateAuthorization()
{
    #if JUCE_IOS || JUCE_MAC
    // HealthKit authorization request
    // In production, use HKHealthStore APIs
    DBG("EchoelAppleWatchAdapter: Requesting Heart Rate authorization");
    #endif
}

void EchoelAppleWatchAdapter::requestHRVAuthorization()
{
    #if JUCE_IOS || JUCE_MAC
    // HealthKit authorization request
    DBG("EchoelAppleWatchAdapter: Requesting HRV authorization");
    #endif
}

void EchoelAppleWatchAdapter::startHeartRateQuery()
{
    #if JUCE_IOS || JUCE_MAC
    // Start continuous heart rate query
    // Use HKAnchoredObjectQuery for real-time updates
    DBG("EchoelAppleWatchAdapter: Started heart rate query");
    #endif
}

void EchoelAppleWatchAdapter::startHRVQuery()
{
    #if JUCE_IOS || JUCE_MAC
    // Start HRV query (HKHeartbeatSeriesSample)
    DBG("EchoelAppleWatchAdapter: Started HRV query");
    #endif
}

void EchoelAppleWatchAdapter::processHeartRateData(double timestamp, float bpm)
{
    // Store timestamp for RR interval calculation
    heartbeatTimestamps.push_back(timestamp);

    // Keep only last 100 beats
    if (heartbeatTimestamps.size() > 100)
        heartbeatTimestamps.erase(heartbeatTimestamps.begin());

    // Calculate RR intervals
    if (heartbeatTimestamps.size() >= 2)
    {
        rrIntervals.clear();
        for (size_t i = 1; i < heartbeatTimestamps.size(); ++i)
        {
            float rrMs = static_cast<float>((heartbeatTimestamps[i] - heartbeatTimestamps[i - 1]) * 1000.0);
            rrIntervals.push_back(rrMs);
        }
    }
}

void EchoelAppleWatchAdapter::processHRVData(float sdnn, float rmssd)
{
    // Update bio-state with HRV metrics
    currentState.hrv = juce::jmap(sdnn, 0.0f, 100.0f, 0.0f, 1.0f);

    // RMSSD indicates parasympathetic activity
    float parasympathetic = juce::jmap(rmssd, 0.0f, 50.0f, 0.0f, 1.0f);

    // Calculate coherence (simplified)
    currentState.coherence = parasympathetic;

    // Stress inversely related to HRV
    currentState.stress = 1.0f - currentState.hrv;
}

//==============================================================================
// 2. POLAR H10 BLUETOOTH HRM ADAPTER
//==============================================================================

EchoelPolarH10Adapter::EchoelPolarH10Adapter()
{
    // currentState.source = EchoelQuantumCore::BioDataSource::PolarH10;
}

EchoelPolarH10Adapter::~EchoelPolarH10Adapter()
{
    disconnect();
}

bool EchoelPolarH10Adapter::connect(const juce::String& config)
{
    // Config format: "deviceID" or empty for scan
    if (config.isEmpty())
    {
        DBG("EchoelPolarH10Adapter: Scanning for Polar H10 devices...");
        scanForDevices();
        return false;  // User must select device
    }

    return connectToDevice(config);
}

void EchoelPolarH10Adapter::disconnect()
{
    if (!connected)
        return;

    stopStreaming();
    connected = false;

    DBG("EchoelPolarH10Adapter: Disconnected from " + deviceName);
}

EchoelQuantumCore::QuantumBioState EchoelPolarH10Adapter::getCurrentState() const
{
    return currentState;
}

void EchoelPolarH10Adapter::startStreaming()
{
    if (!connected)
    {
        DBG("EchoelPolarH10Adapter: Cannot start streaming - not connected");
        return;
    }

    streaming = true;
    DBG("EchoelPolarH10Adapter: Started streaming RR intervals");
}

void EchoelPolarH10Adapter::stopStreaming()
{
    streaming = false;
    DBG("EchoelPolarH10Adapter: Stopped streaming");
}

void EchoelPolarH10Adapter::scanForDevices()
{
    // Bluetooth LE scan
    // Look for devices with name starting with "Polar H10"

    DBG("EchoelPolarH10Adapter: Scanning for Bluetooth devices...");

    // Simulated device discovery
    discoveredDevices.clear();
    discoveredDevices.push_back("Polar H10 12345678");
    discoveredDevices.push_back("Polar H10 87654321");

    DBG("EchoelPolarH10Adapter: Found " + juce::String(discoveredDevices.size()) + " devices");
}

std::vector<juce::String> EchoelPolarH10Adapter::getAvailableDevices() const
{
    return discoveredDevices;
}

bool EchoelPolarH10Adapter::connectToDevice(const juce::String& deviceId)
{
    this->deviceId = deviceId;
    deviceName = deviceId;

    // Bluetooth connection
    // Subscribe to Heart Rate Measurement characteristic (UUID: 0x2A37)
    // Subscribe to RR Interval data

    connected = true;
    batteryLevel = 0.85f;  // Would be read from Battery Service

    DBG("EchoelPolarH10Adapter: Connected to " + deviceName);
    return true;
}

void EchoelPolarH10Adapter::processRRInterval(float rrMs)
{
    if (!streaming)
        return;

    // Store RR interval
    std::vector<float> rrIntervals;
    rrIntervals.push_back(rrMs);

    // Keep last 100 RR intervals for HRV calculation
    if (rrIntervals.size() > 100)
        rrIntervals.erase(rrIntervals.begin());

    // Calculate HRV metrics every 10 intervals
    if (rrIntervals.size() >= 10)
    {
        calculateHRVMetrics();
    }
}

void EchoelPolarH10Adapter::calculateHRVMetrics()
{
    // Calculate SDNN, RMSSD, etc.
    // Update currentState

    // Placeholder implementation
    currentState.hrv = 0.7f;
    currentState.coherence = 0.6f;
    currentState.stress = 0.3f;
}

//==============================================================================
// 3. MUSE HEADBAND EEG ADAPTER
//==============================================================================

EchoelMuseAdapter::EchoelMuseAdapter()
{
    // currentState.source = EchoelQuantumCore::BioDataSource::MuseHeadband;

    // Initialize EEG channels
    for (auto& channel : rawEEGChannels)
        channel.reserve(256);  // 256 Hz sample rate
}

EchoelMuseAdapter::~EchoelMuseAdapter()
{
    disconnect();
}

bool EchoelMuseAdapter::connect(const juce::String& config)
{
    // Connect via Bluetooth or Muse Direct API

    DBG("EchoelMuseAdapter: Connecting to Muse headband...");

    connected = true;
    deviceName = "Muse 2";
    batteryLevel = 0.75f;

    // Initialize electrode quality
    for (auto& quality : electrodeQuality)
        quality = 1.0f;

    DBG("EchoelMuseAdapter: Connected to Muse headband");
    return true;
}

void EchoelMuseAdapter::disconnect()
{
    if (!connected)
        return;

    stopStreaming();
    connected = false;

    DBG("EchoelMuseAdapter: Disconnected from Muse headband");
}

EchoelQuantumCore::QuantumBioState EchoelMuseAdapter::getCurrentState() const
{
    return currentState;
}

void EchoelMuseAdapter::startStreaming()
{
    if (!connected)
    {
        DBG("EchoelMuseAdapter: Cannot start streaming - not connected");
        return;
    }

    streaming = true;
    DBG("EchoelMuseAdapter: Started streaming EEG data (4 channels @ 256 Hz)");
}

void EchoelMuseAdapter::stopStreaming()
{
    streaming = false;
    DBG("EchoelMuseAdapter: Stopped streaming");
}

float EchoelMuseAdapter::getElectrodeQuality(Electrode electrode) const
{
    return electrodeQuality[static_cast<int>(electrode)];
}

bool EchoelMuseAdapter::isHeadbandFittedProperly() const
{
    // Check if all electrodes have good contact
    for (auto quality : electrodeQuality)
    {
        if (quality < 0.5f)
            return false;
    }
    return true;
}

void EchoelMuseAdapter::processEEGSample(int channel, float value)
{
    if (!streaming || channel < 0 || channel >= 4)
        return;

    rawEEGChannels[channel].push_back(value);

    // Keep last 256 samples (1 second at 256 Hz)
    if (rawEEGChannels[channel].size() > 256)
        rawEEGChannels[channel].erase(rawEEGChannels[channel].begin());

    // Calculate band powers every 256 samples
    if (rawEEGChannels[channel].size() == 256)
    {
        calculateBandPowers();
        updateBioState();
    }
}

void EchoelMuseAdapter::calculateBandPowers()
{
    // FFT-based band power calculation
    // In production, use juce::dsp::FFT

    // Placeholder values
    delta = 0.2f;
    theta = 0.3f;
    alpha = 0.5f;
    beta = 0.4f;
    gamma = 0.1f;
}

void EchoelMuseAdapter::updateBioState()
{
    currentState.delta = delta;
    currentState.theta = theta;
    currentState.alpha = alpha;
    currentState.beta = beta;
    currentState.gamma = gamma;

    // Calculate flow state (Alpha-Theta crossover)
    currentState.flowState = (alpha > 0.4f && theta > 0.3f) ? (alpha + theta) / 2.0f : 0.0f;
}

//==============================================================================
// 4. EMOTIV EPOC+ PROFESSIONAL EEG ADAPTER
//==============================================================================

EchoelEmotivAdapter::EchoelEmotivAdapter()
{
    // currentState.source = EchoelQuantumCore::BioDataSource::EmotivEPOC;

    // Initialize 14 EEG channels
    for (auto& channel : rawEEGChannels)
        channel.reserve(256);
}

EchoelEmotivAdapter::~EchoelEmotivAdapter()
{
    disconnect();
}

bool EchoelEmotivAdapter::connect(const juce::String& config)
{
    // Connect via Emotiv SDK

    DBG("EchoelEmotivAdapter: Connecting to Emotiv EPOC+...");

    connected = true;
    deviceName = "Emotiv EPOC+";
    batteryLevel = 0.80f;

    // Initialize electrode quality
    for (auto& quality : electrodeQuality)
        quality = 1.0f;

    DBG("EchoelEmotivAdapter: Connected to Emotiv EPOC+ (14 channels)");
    return true;
}

void EchoelEmotivAdapter::disconnect()
{
    if (!connected)
        return;

    stopStreaming();
    connected = false;

    DBG("EchoelEmotivAdapter: Disconnected from Emotiv EPOC+");
}

EchoelQuantumCore::QuantumBioState EchoelEmotivAdapter::getCurrentState() const
{
    return currentState;
}

void EchoelEmotivAdapter::startStreaming()
{
    if (!connected)
    {
        DBG("EchoelEmotivAdapter: Cannot start streaming - not connected");
        return;
    }

    streaming = true;
    DBG("EchoelEmotivAdapter: Started streaming EEG data (14 channels @ 256 Hz)");
}

void EchoelEmotivAdapter::stopStreaming()
{
    streaming = false;
    DBG("EchoelEmotivAdapter: Stopped streaming");
}

float EchoelEmotivAdapter::getElectrodeQuality(Electrode electrode) const
{
    return electrodeQuality[static_cast<int>(electrode)];
}

float EchoelEmotivAdapter::getEngagement() const { return engagement; }
float EchoelEmotivAdapter::getExcitement() const { return excitement; }
float EchoelEmotivAdapter::getStress() const { return stress; }
float EchoelEmotivAdapter::getRelaxation() const { return relaxation; }
float EchoelEmotivAdapter::getFocus() const { return focus; }
float EchoelEmotivAdapter::getInterest() const { return interest; }

void EchoelEmotivAdapter::processEEGSample(int channel, float value)
{
    if (!streaming || channel < 0 || channel >= 14)
        return;

    rawEEGChannels[channel].push_back(value);

    // Keep last 256 samples
    if (rawEEGChannels[channel].size() > 256)
        rawEEGChannels[channel].erase(rawEEGChannels[channel].begin());

    // Calculate performance metrics
    if (rawEEGChannels[channel].size() == 256)
    {
        calculatePerformanceMetrics();
        updateBioState();
    }
}

void EchoelEmotivAdapter::calculatePerformanceMetrics()
{
    // Emotiv SDK provides performance metrics
    // In production, use Emotiv API

    // Placeholder values
    engagement = 0.6f;
    excitement = 0.5f;
    stress = 0.4f;
    relaxation = 0.6f;
    focus = 0.7f;
    interest = 0.5f;
}

void EchoelEmotivAdapter::updateBioState()
{
    // Map Emotiv metrics to QuantumBioState
    currentState.stress = stress;
    currentState.coherence = relaxation;
    currentState.flowState = (focus + engagement) / 2.0f;

    // Calculate band powers from raw EEG
    // (Similar to Muse implementation)
}

//==============================================================================
// 5. WEBSOCKET BIO-DATA ADAPTER
//==============================================================================

EchoelWebSocketAdapter::EchoelWebSocketAdapter()
{
    // currentState.source = EchoelQuantumCore::BioDataSource::WebSocket;
}

EchoelWebSocketAdapter::~EchoelWebSocketAdapter()
{
    disconnect();
}

bool EchoelWebSocketAdapter::connect(const juce::String& config)
{
    // Config format: "ws://host:port"
    serverUrl = config;

    DBG("EchoelWebSocketAdapter: Connecting to " + serverUrl);

    // In production, create actual WebSocket connection
    // webSocket = std::make_unique<juce::WebSocket>();

    connected = true;

    DBG("EchoelWebSocketAdapter: Connected to WebSocket server");
    return true;
}

void EchoelWebSocketAdapter::disconnect()
{
    if (!connected)
        return;

    stopStreaming();

    // if (webSocket)
    //     webSocket.reset();

    connected = false;

    DBG("EchoelWebSocketAdapter: Disconnected from WebSocket server");
}

EchoelQuantumCore::QuantumBioState EchoelWebSocketAdapter::getCurrentState() const
{
    return currentState;
}

void EchoelWebSocketAdapter::startStreaming()
{
    streaming = true;
    DBG("EchoelWebSocketAdapter: Started streaming");
}

void EchoelWebSocketAdapter::stopStreaming()
{
    streaming = false;
    DBG("EchoelWebSocketAdapter: Stopped streaming");
}

void EchoelWebSocketAdapter::processMessage(const juce::String& jsonMessage)
{
    if (!streaming)
        return;

    // Parse JSON message
    auto json = juce::JSON::parse(jsonMessage);

    if (json.isObject())
    {
        auto obj = json.getDynamicObject();

        // Extract bio-data
        if (obj->hasProperty("hrv"))
            currentState.hrv = static_cast<float>(obj->getProperty("hrv"));

        if (obj->hasProperty("coherence"))
            currentState.coherence = static_cast<float>(obj->getProperty("coherence"));

        if (obj->hasProperty("stress"))
            currentState.stress = static_cast<float>(obj->getProperty("stress"));

        // EEG bands
        if (obj->hasProperty("delta"))
            currentState.delta = static_cast<float>(obj->getProperty("delta"));

        if (obj->hasProperty("theta"))
            currentState.theta = static_cast<float>(obj->getProperty("theta"));

        if (obj->hasProperty("alpha"))
            currentState.alpha = static_cast<float>(obj->getProperty("alpha"));

        if (obj->hasProperty("beta"))
            currentState.beta = static_cast<float>(obj->getProperty("beta"));

        if (obj->hasProperty("gamma"))
            currentState.gamma = static_cast<float>(obj->getProperty("gamma"));
    }
}
// 
// //==============================================================================
// // 6. OSC BIO-DATA ADAPTER
// //==============================================================================
// // 
// // EchoelOSCAdapter::EchoelOSCAdapter()
// // {
// //     // currentState.source = EchoelQuantumCore::BioDataSource::OSC;
// //     oscReceiver = std::make_unique<juce::OSCReceiver>();
// // }
// // 
// // EchoelOSCAdapter::~EchoelOSCAdapter()
// // {
// //     disconnect();
// // }
// 
// bool EchoelOSCAdapter::connect(const juce::String& config)
// {
//     // Config format: "port:8000"
//     port = config.fromFirstOccurrenceOf("port:", false, true).getIntValue();
// 
//     if (port == 0)
//         port = 8000;  // Default port
// 
//     DBG("EchoelOSCAdapter: Binding to OSC port " + juce::String(port));
// 
//     if (oscReceiver->connect(port))
//     {
//         oscReceiver->addListener(this);
//         connected = true;
// 
//         DBG("EchoelOSCAdapter: Successfully bound to port " + juce::String(port));
//         return true;
//     }
// 
//     DBG("EchoelOSCAdapter: Failed to bind to port " + juce::String(port));
//     return false;
// }
// 
// void EchoelOSCAdapter::disconnect()
// {
//     if (!connected)
//         return;
// 
//     stopStreaming();
// 
//     if (// oscReceiver)
//     {
//         // oscReceiver->removeListener(this);
//         // oscReceiver->disconnect();
//     }
// 
//     connected = false;
// 
//     DBG("EchoelOSCAdapter: Disconnected from OSC port " + juce::String(port));
// }
// 
// EchoelQuantumCore::QuantumBioState EchoelOSCAdapter::getCurrentState() const
// {
//     return currentState;
// }
// 
// void EchoelOSCAdapter::startStreaming()
// {
//     streaming = true;
//     DBG("EchoelOSCAdapter: Started streaming");
// }
// 
// void EchoelOSCAdapter::stopStreaming()
// {
//     streaming = false;
//     DBG("EchoelOSCAdapter: Stopped streaming");
// }
// 
// void EchoelOSCAdapter::oscMessageReceived(const juce::OSCMessage& message)
// {
//     if (!streaming)
//         return;
// 
//     auto address = message.getAddressPattern().toString();
// 
//     // HRV
//     if (address == "/bio/hrv" && message.size() >= 1)
//     {
//         if (message[0].isFloat32())
//             currentState.hrv = message[0].getFloat32();
//     }
// 
//     // Coherence
//     else if (address == "/bio/coherence" && message.size() >= 1)
//     {
//         if (message[0].isFloat32())
//             currentState.coherence = message[0].getFloat32();
//     }
// 
//     // Stress
//     else if (address == "/bio/stress" && message.size() >= 1)
//     {
//         if (message[0].isFloat32())
//             currentState.stress = message[0].getFloat32();
//     }
// 
//     // EEG bands
//     else if (address == "/bio/delta" && message.size() >= 1)
//     {
//         if (message[0].isFloat32())
//             currentState.delta = message[0].getFloat32();
//     }
// 
//     else if (address == "/bio/theta" && message.size() >= 1)
//     {
//         if (message[0].isFloat32())
//             currentState.theta = message[0].getFloat32();
//     }
// 
//     else if (address == "/bio/alpha" && message.size() >= 1)
//     {
//         if (message[0].isFloat32())
//             currentState.alpha = message[0].getFloat32();
//     }
// 
//     else if (address == "/bio/beta" && message.size() >= 1)
//     {
//         if (message[0].isFloat32())
//             currentState.beta = message[0].getFloat32();
//     }
// 
//     else if (address == "/bio/gamma" && message.size() >= 1)
//     {
//         if (message[0].isFloat32())
//             currentState.gamma = message[0].getFloat32();
//     }
// }
// 
// //==============================================================================
// // 7. MIDI CC BIO-DATA ADAPTER
// //==============================================================================
// 
// EchoelMIDIAdapter::EchoelMIDIAdapter()
// {
//     // currentState.source = EchoelQuantumCore::BioDataSource::MIDI_CC;
// }
//
// EchoelMIDIAdapter::~EchoelMIDIAdapter()
// {
//     disconnect();
// }
//
// bool EchoelMIDIAdapter::connect(const juce::String& config)
// {
//     // Config = MIDI device name
//     midiDeviceName = config;
//
//     DBG("EchoelMIDIAdapter: Opening MIDI device: " + midiDeviceName);
//
//     // Find MIDI input device
//     auto devices = juce::MidiInput::getAvailableDevices();
// 
//     for (auto& device : devices)
//     {
//         if (device.name == midiDeviceName || midiDeviceName.isEmpty())
//         {
//             midiInput = juce::MidiInput::openDevice(device.identifier, this);
// 
//             if (midiInput)
//             {
//                 midiInput->start();
//                 midiDeviceName = device.name;
//                 connected = true;
// 
//                 DBG("EchoelMIDIAdapter: Connected to " + midiDeviceName);
//                 return true;
//             }
//         }
//     }
// 
//     DBG("EchoelMIDIAdapter: Failed to open MIDI device");
//     return false;
// }
// 
// void EchoelMIDIAdapter::disconnect()
// {
//     if (!connected)
//         return;
// 
//     stopStreaming();
// 
//     if (midiInput)
//     {
//         midiInput->stop();
//         midiInput.reset();
//     }
// 
//     connected = false;
// 
//     DBG("EchoelMIDIAdapter: Disconnected from " + midiDeviceName);
// }
// 
// EchoelQuantumCore::QuantumBioState EchoelMIDIAdapter::getCurrentState() const
// {
//     return currentState;
// }
// 
// void EchoelMIDIAdapter::startStreaming()
// {
//     streaming = true;
//     DBG("EchoelMIDIAdapter: Started streaming");
// }
// 
// void EchoelMIDIAdapter::stopStreaming()
// {
//     streaming = false;
//     DBG("EchoelMIDIAdapter: Stopped streaming");
// }
// 
void EchoelMIDIAdapter::mapCC(int ccNumber, const juce::String& bioParameter)
{
    ccMappings[ccNumber] = bioParameter;
    DBG("EchoelMIDIAdapter: Mapped CC " + juce::String(ccNumber) + " to " + bioParameter);
}

void EchoelMIDIAdapter::handleIncomingMidiMessage(juce::MidiInput* source, const juce::MidiMessage& message)
{
    if (!streaming)
        return;

    if (message.isController())
    {
        int ccNumber = message.getControllerNumber();
        float value = message.getControllerValue() / 127.0f;  // Normalize to 0.0-1.0

        // Check if this CC is mapped
        auto it = ccMappings.find(ccNumber);
        if (it != ccMappings.end())
        {
            updateBioParameter(it->second, value);
        }
    }
}

void EchoelMIDIAdapter::updateBioParameter(const juce::String& parameter, float value)
{
    if (parameter == "hrv")
        currentState.hrv = value;
    else if (parameter == "coherence")
        currentState.coherence = value;
    else if (parameter == "stress")
        currentState.stress = value;
    else if (parameter == "delta")
        currentState.delta = value;
    else if (parameter == "theta")
        currentState.theta = value;
    else if (parameter == "alpha")
        currentState.alpha = value;
    else if (parameter == "beta")
        currentState.beta = value;
    else if (parameter == "gamma")
        currentState.gamma = value;
}

//==============================================================================
// ADAPTER FACTORY
//==============================================================================

std::unique_ptr<IBioDataAdapter> EchoelBioDataAdapterFactory::createAdapter(
    EchoelQuantumCore::BioDataSource source)
{
    switch (source)
    {
        case EchoelQuantumCore::BioDataSource::AppleWatch:
            return std::make_unique<EchoelAppleWatchAdapter>();

        case EchoelQuantumCore::BioDataSource::PolarH10:
            return std::make_unique<EchoelPolarH10Adapter>();

        case EchoelQuantumCore::BioDataSource::MuseHeadband:
            return std::make_unique<EchoelMuseAdapter>();

        case EchoelQuantumCore::BioDataSource::EmotivEPOC:
            return std::make_unique<EchoelEmotivAdapter>();

        case EchoelQuantumCore::BioDataSource::WebSocket:
            return std::make_unique<EchoelWebSocketAdapter>();

        case EchoelQuantumCore::BioDataSource::OSC:
            // OSC adapter temporarily disabled - needs proper JUCE OSC setup
            return nullptr;  // return std::make_unique<EchoelOSCAdapter>();

        case EchoelQuantumCore::BioDataSource::MIDI_CC:
            // MIDI adapter temporarily disabled
            return nullptr;  // return std::make_unique<EchoelMIDIAdapter>();

        default:
            return nullptr;
    }
}

std::vector<EchoelQuantumCore::BioDataSource> EchoelBioDataAdapterFactory::getAvailableAdapters()
{
    std::vector<EchoelQuantumCore::BioDataSource> adapters;

    // HealthKit (iOS/macOS only)
    #if JUCE_IOS || JUCE_MAC
    adapters.push_back(EchoelQuantumCore::BioDataSource::AppleWatch);
    #endif

    // Bluetooth adapters (all platforms with Bluetooth)
    adapters.push_back(EchoelQuantumCore::BioDataSource::PolarH10);
    adapters.push_back(EchoelQuantumCore::BioDataSource::MuseHeadband);
    adapters.push_back(EchoelQuantumCore::BioDataSource::EmotivEPOC);

    // Network adapters (all platforms)
    adapters.push_back(EchoelQuantumCore::BioDataSource::WebSocket);
    // OSC and MIDI temporarily disabled
    // adapters.push_back(EchoelQuantumCore::BioDataSource::OSC);
    // adapters.push_back(EchoelQuantumCore::BioDataSource::MIDI_CC);

    return adapters;
}

std::unique_ptr<IBioDataAdapter> EchoelBioDataAdapterFactory::autoDetect()
{
    DBG("EchoelBioDataAdapterFactory: Auto-detecting bio-data sources...");

    // Try platform-specific sources first
    #if JUCE_IOS || JUCE_MAC
    auto appleWatch = std::make_unique<EchoelAppleWatchAdapter>();
    if (appleWatch->connect(""))
    {
        DBG("EchoelBioDataAdapterFactory: Auto-detected Apple Watch");
        return appleWatch;
    }
    #endif

    // Try Bluetooth devices
    auto polar = std::make_unique<EchoelPolarH10Adapter>();
    polar->scanForDevices();
    auto devices = polar->getAvailableDevices();
    if (!devices.empty())
    {
        if (polar->connect(devices[0]))
        {
            DBG("EchoelBioDataAdapterFactory: Auto-detected Polar H10");
            return polar;
        }
    }

    // Try OSC (default port 8000) - temporarily disabled
    // auto osc = std::make_unique<EchoelOSCAdapter>();
    // if (osc->connect("port:8000"))
    // {
    //     DBG("EchoelBioDataAdapterFactory: Auto-detected OSC stream on port 8000");
    //     return osc;
    // }

    DBG("EchoelBioDataAdapterFactory: No bio-data sources detected");
    return nullptr;
}
