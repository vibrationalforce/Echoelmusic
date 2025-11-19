#include "UniversalDeviceManager.h"

//==============================================================================
// DeviceInfo Implementation
//==============================================================================

juce::String DeviceInfo::getDescription() const
{
    juce::String desc;
    desc << name << " (" << manufacturer << " " << model << ")\n";
    desc << "Category: ";

    switch (category)
    {
        case DeviceCategory::MIDIController:         desc << "MIDI Controller"; break;
        case DeviceCategory::AudioInterface:         desc << "Audio Interface"; break;
        case DeviceCategory::DJEquipment:           desc << "DJ Equipment"; break;
        case DeviceCategory::ModularSynth:          desc << "Modular Synth"; break;
        case DeviceCategory::NetworkAudio:          desc << "Network Audio"; break;
        case DeviceCategory::LightController:       desc << "Light Controller"; break;
        case DeviceCategory::HapticDevice:          desc << "Haptic Device"; break;
        case DeviceCategory::HeartRateMonitor:      desc << "Heart Rate Monitor"; break;
        case DeviceCategory::EEGDevice:             desc << "EEG Device"; break;
        case DeviceCategory::GSRSensor:             desc << "GSR Sensor"; break;
        case DeviceCategory::MotionSensor:          desc << "Motion Sensor"; break;
        case DeviceCategory::BrainComputerInterface: desc << "Brain-Computer Interface"; break;
        case DeviceCategory::QuantumSensor:         desc << "Quantum Sensor"; break;
        case DeviceCategory::HolographicInterface:  desc << "Holographic Interface"; break;
        case DeviceCategory::NeuralImplant:         desc << "Neural Implant"; break;
        case DeviceCategory::EyeTracker:            desc << "Eye Tracker"; break;
        case DeviceCategory::VoiceController:       desc << "Voice Controller"; break;
        case DeviceCategory::AdaptiveController:    desc << "Adaptive Controller"; break;
        default:                                     desc << "Unknown"; break;
    }

    desc << "\nStatus: " << (isConnected ? "Connected" : "Disconnected");
    desc << "\nChannels: " << numChannels;

    if (sampleRate > 0)
        desc << "\nSample Rate: " << sampleRate << " Hz";

    if (batteryPowered)
        desc << "\nBattery: " << batteryPercent << "%";

    return desc;
}

//==============================================================================
// UniversalDeviceManager Implementation
//==============================================================================

UniversalDeviceManager::UniversalDeviceManager()
{
    DBG("UniversalDeviceManager initialized - Universal device compatibility enabled");
}

UniversalDeviceManager::~UniversalDeviceManager()
{
    devices.clear();
    devicesByCategory.clear();
}

//==============================================================================
// Device Discovery
//==============================================================================

void UniversalDeviceManager::scanAllDevices()
{
    DBG("Scanning for all devices (Legacy, Current, Future)...");

    // Traditional devices
    detectMIDIDevices();
    detectAudioInterfaces();
    detectDJEquipment();
    detectModularSynths();

    // Modern devices
    detectNetworkAudio();

    // Biometric/Future
    detectBiometricSensors();
    detectBCI();

    // Accessibility
    detectAccessibilityDevices();

    // Future tech
    scanFutureDevices();

    DBG("Device scan complete - Found " + juce::String(devices.size()) + " devices");

    if (onStatusChange)
        onStatusChange("Device scan complete - " + juce::String(devices.size()) + " devices found");
}

juce::Array<DeviceInfo> UniversalDeviceManager::getAllDevices() const
{
    juce::Array<DeviceInfo> allDevices;

    for (const auto& pair : devices)
    {
        if (pair.second)
            allDevices.add(pair.second->getInfo());
    }

    return allDevices;
}

juce::Array<DeviceInfo> UniversalDeviceManager::getDevicesByCategory(DeviceCategory category) const
{
    juce::Array<DeviceInfo> result;

    for (const auto& pair : devices)
    {
        if (pair.second)
        {
            auto info = pair.second->getInfo();
            if (info.category == category)
                result.add(info);
        }
    }

    return result;
}

DeviceInfo UniversalDeviceManager::getDeviceInfo(const juce::String& deviceName) const
{
    auto it = devices.find(deviceName);
    if (it != devices.end() && it->second)
        return it->second->getInfo();

    return DeviceInfo();
}

//==============================================================================
// Device Access
//==============================================================================

std::shared_ptr<DJController> UniversalDeviceManager::getDJController(const juce::String& name)
{
    auto device = getDevice(name);
    return std::dynamic_pointer_cast<DJController>(device);
}

std::shared_ptr<ModularSynth> UniversalDeviceManager::getModularSynth(const juce::String& name)
{
    auto device = getDevice(name);
    return std::dynamic_pointer_cast<ModularSynth>(device);
}

std::shared_ptr<BrainComputerInterface> UniversalDeviceManager::getBCI(const juce::String& name)
{
    auto device = getDevice(name);
    return std::dynamic_pointer_cast<BrainComputerInterface>(device);
}

std::shared_ptr<BiometricSensor> UniversalDeviceManager::getBiometricSensor(const juce::String& name)
{
    auto device = getDevice(name);
    return std::dynamic_pointer_cast<BiometricSensor>(device);
}

std::shared_ptr<NetworkAudioDevice> UniversalDeviceManager::getNetworkAudioDevice(const juce::String& name)
{
    auto device = getDevice(name);
    return std::dynamic_pointer_cast<NetworkAudioDevice>(device);
}

std::shared_ptr<AccessibilityDevice> UniversalDeviceManager::getAccessibilityDevice(const juce::String& name)
{
    auto device = getDevice(name);
    return std::dynamic_pointer_cast<AccessibilityDevice>(device);
}

std::shared_ptr<UniversalDevice> UniversalDeviceManager::getDevice(const juce::String& name)
{
    auto it = devices.find(name);
    if (it != devices.end())
        return it->second;

    return nullptr;
}

//==============================================================================
// Auto-Configuration
//==============================================================================

void UniversalDeviceManager::autoConfigureAll()
{
    DBG("Auto-configuring all devices...");

    for (auto& pair : devices)
    {
        if (pair.second && pair.second->isConnected())
        {
            try
            {
                pair.second->calibrate();
                DBG("Auto-configured: " + pair.first);
            }
            catch (const std::exception& e)
            {
                DBG("Failed to auto-configure " + pair.first + ": " + juce::String(e.what()));
            }
        }
    }

    if (onStatusChange)
        onStatusChange("All devices auto-configured");
}

void UniversalDeviceManager::autoSetupDJEquipment()
{
    DBG("Auto-setting up DJ equipment...");

    auto djDevices = getDevicesByCategory(DeviceCategory::DJEquipment);

    for (const auto& info : djDevices)
    {
        auto dj = getDJController(info.name);
        if (dj && dj->isConnected())
        {
            // Enable Ableton Link by default
            dj->syncWithAbletonLink(true);

            // Set default tempo
            dj->syncTempo(120.0f);

            DBG("DJ equipment ready: " + info.name);
        }
    }
}

void UniversalDeviceManager::autoSetupBiometrics()
{
    DBG("Auto-setting up biometric sensors...");

    // Heart rate monitors
    auto hrDevices = getDevicesByCategory(DeviceCategory::HeartRateMonitor);
    for (const auto& info : hrDevices)
    {
        auto hr = getBiometricSensor(info.name);
        if (hr && hr->connect())
        {
            hr->calibrate();
            DBG("Heart rate monitor ready: " + info.name);
        }
    }

    // EEG devices
    auto eegDevices = getDevicesByCategory(DeviceCategory::EEGDevice);
    for (const auto& info : eegDevices)
    {
        auto eeg = getBiometricSensor(info.name);
        if (eeg && eeg->connect())
        {
            eeg->calibrate();
            DBG("EEG device ready: " + info.name);
        }
    }

    // Brain-computer interfaces
    auto bciDevices = getDevicesByCategory(DeviceCategory::BrainComputerInterface);
    for (const auto& info : bciDevices)
    {
        auto bci = getBCI(info.name);
        if (bci && bci->connect())
        {
            bci->calibrate();
            DBG("BCI ready: " + info.name);
        }
    }
}

void UniversalDeviceManager::autoSetupAccessibility()
{
    DBG("Auto-setting up accessibility devices...");

    // Eye trackers
    auto eyeTrackers = getDevicesByCategory(DeviceCategory::EyeTracker);
    for (const auto& info : eyeTrackers)
    {
        auto eye = getAccessibilityDevice(info.name);
        if (eye && eye->connect())
        {
            eye->calibrate();
            DBG("Eye tracker ready: " + info.name);
        }
    }

    // Voice controllers
    auto voiceDevices = getDevicesByCategory(DeviceCategory::VoiceController);
    for (const auto& info : voiceDevices)
    {
        auto voice = getAccessibilityDevice(info.name);
        if (voice && voice->connect())
        {
            voice->startListening();
            DBG("Voice controller ready: " + info.name);
        }
    }
}

//==============================================================================
// Device Templates
//==============================================================================

bool UniversalDeviceManager::loadDeviceTemplate(const juce::String& templateName)
{
    DBG("Loading device template: " + templateName);

    // Load from file
    auto appData = juce::File::getSpecialLocation(juce::File::userApplicationDataDirectory);
    auto templatesDir = appData.getChildFile("Echoelmusic").getChildFile("DeviceTemplates");
    auto templateFile = templatesDir.getChildFile(templateName + ".json");

    if (!templateFile.existsAsFile())
    {
        DBG("Template not found: " + templateName);
        return false;
    }

    try
    {
        auto jsonText = templateFile.loadFileAsString();
        auto json = juce::JSON::parse(jsonText);

        if (!json.isObject())
            return false;

        // Parse and apply template
        // (Implementation would parse JSON and configure devices)

        DBG("Template loaded successfully: " + templateName);
        return true;
    }
    catch (const std::exception& e)
    {
        DBG("Failed to load template: " + juce::String(e.what()));
        return false;
    }
}

bool UniversalDeviceManager::saveDeviceTemplate(const juce::String& templateName)
{
    DBG("Saving device template: " + templateName);

    auto appData = juce::File::getSpecialLocation(juce::File::userApplicationDataDirectory);
    auto templatesDir = appData.getChildFile("Echoelmusic").getChildFile("DeviceTemplates");

    if (!templatesDir.exists())
        templatesDir.createDirectory();

    auto templateFile = templatesDir.getChildFile(templateName + ".json");

    try
    {
        juce::DynamicObject::Ptr root = new juce::DynamicObject();
        root->setProperty("templateName", templateName);
        root->setProperty("created", juce::Time::getCurrentTime().toString(true, true));

        // Save device configurations
        // (Implementation would serialize current device states to JSON)

        auto jsonText = juce::JSON::toString(juce::var(root.get()), true);
        templateFile.replaceWithText(jsonText);

        DBG("Template saved successfully: " + templateName);
        return true;
    }
    catch (const std::exception& e)
    {
        DBG("Failed to save template: " + juce::String(e.what()));
        return false;
    }
}

juce::StringArray UniversalDeviceManager::getAvailableTemplates() const
{
    juce::StringArray templates;

    auto appData = juce::File::getSpecialLocation(juce::File::userApplicationDataDirectory);
    auto templatesDir = appData.getChildFile("Echoelmusic").getChildFile("DeviceTemplates");

    if (templatesDir.exists())
    {
        auto files = templatesDir.findChildFiles(juce::File::findFiles, false, "*.json");

        for (const auto& file : files)
            templates.add(file.getFileNameWithoutExtension());
    }

    return templates;
}

//==============================================================================
// Cross-Device Sync
//==============================================================================

void UniversalDeviceManager::syncTempoAll(float bpm)
{
    DBG("Syncing tempo across all devices: " + juce::String(bpm) + " BPM");

    for (auto& pair : devices)
    {
        // DJ Controllers
        if (auto dj = std::dynamic_pointer_cast<DJController>(pair.second))
        {
            if (dj->isConnected())
                dj->syncTempo(bpm);
        }

        // Modular Synths (send clock)
        if (auto modular = std::dynamic_pointer_cast<ModularSynth>(pair.second))
        {
            if (modular->isConnected())
            {
                for (int i = 0; i < modular->getInfo().numOutputs; ++i)
                    modular->sendClock(i, bpm);
            }
        }
    }
}

void UniversalDeviceManager::syncTransportAll(bool playing)
{
    DBG("Syncing transport across all devices: " + juce::String(playing ? "PLAY" : "STOP"));

    for (auto& pair : devices)
    {
        if (auto dj = std::dynamic_pointer_cast<DJController>(pair.second))
        {
            if (dj->isConnected())
            {
                if (playing)
                    dj->play();
                else
                    dj->pause();
            }
        }
    }
}

void UniversalDeviceManager::enableAbletonLinkAll(bool enable)
{
    DBG("Ableton Link " + juce::String(enable ? "enabled" : "disabled") + " for all devices");

    for (auto& pair : devices)
    {
        if (auto dj = std::dynamic_pointer_cast<DJController>(pair.second))
        {
            if (dj->isConnected())
                dj->syncWithAbletonLink(enable);
        }
    }
}

//==============================================================================
// Future Tech Integration
//==============================================================================

void UniversalDeviceManager::scanFutureDevices()
{
    DBG("Scanning for future/experimental devices...");

    // Quantum sensors (simulated for now)
    // In a real implementation, this would interface with quantum hardware APIs

    // Neural implants (Neuralink-like)
    // Would connect to BCI protocols

    // Holographic interfaces
    // Would detect spatial input devices

    DBG("Future device scan complete");
}

void UniversalDeviceManager::enableQuantumSensors(bool enable)
{
    DBG("Quantum sensors " + juce::String(enable ? "enabled" : "disabled"));

    auto quantumDevices = getDevicesByCategory(DeviceCategory::QuantumSensor);

    for (const auto& info : quantumDevices)
    {
        auto device = getDevice(info.name);
        if (device)
        {
            if (enable)
                device->connect();
            else
                device->disconnect();
        }
    }
}

void UniversalDeviceManager::enableNeuralInterface(bool enable)
{
    DBG("Neural interface " + juce::String(enable ? "enabled" : "disabled"));

    auto neuralDevices = getDevicesByCategory(DeviceCategory::NeuralImplant);

    for (const auto& info : neuralDevices)
    {
        auto device = getDevice(info.name);
        if (device)
        {
            if (enable)
                device->connect();
            else
                device->disconnect();
        }
    }

    // Also enable BCIs
    auto bciDevices = getDevicesByCategory(DeviceCategory::BrainComputerInterface);

    for (const auto& info : bciDevices)
    {
        auto bci = getBCI(info.name);
        if (bci)
        {
            if (enable)
                bci->connect();
            else
                bci->disconnect();
        }
    }
}

//==============================================================================
// Inclusive Design
//==============================================================================

void UniversalDeviceManager::enableAccessibilityMode(bool enable)
{
    accessibilityMode = enable;

    DBG("Accessibility mode " + juce::String(enable ? "enabled" : "disabled"));

    if (enable)
        autoSetupAccessibility();

    if (onStatusChange)
        onStatusChange("Accessibility mode " + juce::String(enable ? "enabled" : "disabled"));
}

void UniversalDeviceManager::setInteractionMode(const juce::String& mode)
{
    currentInteractionMode = mode;

    DBG("Interaction mode set to: " + mode);

    if (mode == "voice")
    {
        // Enable all voice controllers
        auto voiceDevices = getDevicesByCategory(DeviceCategory::VoiceController);
        for (const auto& info : voiceDevices)
        {
            auto voice = getAccessibilityDevice(info.name);
            if (voice && voice->isConnected())
                voice->startListening();
        }
    }
    else if (mode == "eye-tracking")
    {
        // Enable all eye trackers
        auto eyeDevices = getDevicesByCategory(DeviceCategory::EyeTracker);
        for (const auto& info : eyeDevices)
        {
            auto eye = getAccessibilityDevice(info.name);
            if (eye && !eye->isConnected())
                eye->connect();
        }
    }
    else if (mode == "one-handed")
    {
        // Configure for one-handed operation
        auto adaptiveDevices = getDevicesByCategory(DeviceCategory::AdaptiveController);
        for (const auto& info : adaptiveDevices)
        {
            auto adaptive = getAccessibilityDevice(info.name);
            if (adaptive && adaptive->isConnected())
                adaptive->setOneHandedMode(true);
        }
    }

    if (onStatusChange)
        onStatusChange("Interaction mode: " + mode);
}

juce::StringArray UniversalDeviceManager::getAvailableAccessibilityFeatures() const
{
    juce::StringArray features;

    features.add("voice-control");
    features.add("eye-tracking");
    features.add("one-handed-mode");
    features.add("high-contrast");
    features.add("large-text");
    features.add("screen-reader");
    features.add("gesture-control");
    features.add("adaptive-controller");

    return features;
}

//==============================================================================
// Monitoring
//==============================================================================

juce::String UniversalDeviceManager::getDeviceStatusSummary() const
{
    juce::String summary;

    summary << "=== ECHOELMUSIC DEVICE STATUS ===\n\n";
    summary << "Total Devices: " << devices.size() << "\n";

    int connected = 0;
    for (const auto& pair : devices)
    {
        if (pair.second && pair.second->isConnected())
            connected++;
    }

    summary << "Connected: " << connected << "\n";
    summary << "Disconnected: " << (devices.size() - connected) << "\n\n";

    // By category
    summary << "--- By Category ---\n";

    for (int cat = 0; cat <= (int)DeviceCategory::Unknown; ++cat)
    {
        auto category = static_cast<DeviceCategory>(cat);
        auto devicesInCategory = getDevicesByCategory(category);

        if (devicesInCategory.size() > 0)
        {
            summary << devicesInCategory[0].getDescription().upToFirstOccurrenceOf("\n", false, false);
            summary << ": " << devicesInCategory.size() << "\n";
        }
    }

    summary << "\n--- System Status ---\n";
    summary << "Accessibility Mode: " << (accessibilityMode ? "ON" : "OFF") << "\n";
    summary << "Interaction Mode: " << currentInteractionMode << "\n";
    summary << "Total Latency: " << getTotalSystemLatency() << " ms\n";

    return summary;
}

double UniversalDeviceManager::getTotalSystemLatency() const
{
    double totalLatency = 0.0;
    int deviceCount = 0;

    for (const auto& pair : devices)
    {
        if (pair.second && pair.second->isConnected())
        {
            auto info = pair.second->getInfo();
            totalLatency += info.roundTripLatencyMs;
            deviceCount++;
        }
    }

    return deviceCount > 0 ? totalLatency / deviceCount : 0.0;
}

bool UniversalDeviceManager::checkDeviceHealth()
{
    bool allHealthy = true;

    for (auto& pair : devices)
    {
        if (pair.second && pair.second->isConnected())
        {
            try
            {
                // Update device to check responsiveness
                pair.second->update(0.0);
            }
            catch (const std::exception& e)
            {
                DBG("Device health check failed for " + pair.first + ": " + juce::String(e.what()));
                allHealthy = false;

                if (onError)
                    onError("Device " + pair.first + " health check failed");
            }
        }
    }

    return allHealthy;
}

//==============================================================================
// Private Methods
//==============================================================================

void UniversalDeviceManager::registerDevice(const juce::String& name, std::shared_ptr<UniversalDevice> device)
{
    devices[name] = device;

    auto info = device->getInfo();
    devicesByCategory[info.category].add(name);

    DBG("Registered device: " + name);

    if (onDeviceConnected)
        onDeviceConnected(info);
}

void UniversalDeviceManager::unregisterDevice(const juce::String& name)
{
    auto it = devices.find(name);
    if (it != devices.end())
    {
        auto info = it->second->getInfo();

        devices.erase(it);
        devicesByCategory[info.category].removeString(name);

        DBG("Unregistered device: " + name);

        if (onDeviceDisconnected)
            onDeviceDisconnected(info);
    }
}

//==============================================================================
// Device Detection
//==============================================================================

void UniversalDeviceManager::detectMIDIDevices()
{
    DBG("Detecting MIDI devices...");

    auto midiInputs = juce::MidiInput::getAvailableDevices();
    auto midiOutputs = juce::MidiOutput::getAvailableDevices();

    DBG("Found " + juce::String(midiInputs.size()) + " MIDI inputs");
    DBG("Found " + juce::String(midiOutputs.size()) + " MIDI outputs");

    // MIDI devices would be registered here
    // This is a placeholder - real implementation would create device wrappers
}

void UniversalDeviceManager::detectAudioInterfaces()
{
    DBG("Detecting audio interfaces...");

    juce::AudioDeviceManager tempDeviceManager;
    tempDeviceManager.initialiseWithDefaultDevices(0, 2);

    auto* currentDevice = tempDeviceManager.getCurrentAudioDevice();
    if (currentDevice)
    {
        DBG("Audio interface: " + currentDevice->getName());
        DBG("Sample rate: " + juce::String(currentDevice->getCurrentSampleRate()));
        DBG("Buffer size: " + juce::String(currentDevice->getCurrentBufferSizeSamples()));
    }
}

void UniversalDeviceManager::detectDJEquipment()
{
    DBG("Detecting DJ equipment...");

    // Would scan for:
    // - Pioneer CDJs (via Pro DJ Link)
    // - Native Instruments controllers (via HID)
    // - Traktor controllers
    // - Denon equipment
    // etc.
}

void UniversalDeviceManager::detectModularSynths()
{
    DBG("Detecting modular synths...");

    // Would scan for:
    // - Expert Sleepers interfaces (ES-8, ES-9)
    // - ADAT/SPDIF CV interfaces
    // - USB CV modules
    // - Network-connected modular systems
}

void UniversalDeviceManager::detectNetworkAudio()
{
    DBG("Detecting network audio devices...");

    // Would scan for:
    // - Dante devices (mDNS discovery)
    // - AES67 streams
    // - Ravenna devices
    // - AVB endpoints
}

void UniversalDeviceManager::detectBiometricSensors()
{
    DBG("Detecting biometric sensors...");

    // Would scan for:
    // - Bluetooth heart rate monitors
    // - USB GSR sensors
    // - Motion sensors (accelerometer, gyro)
    // - Temperature sensors
}

void UniversalDeviceManager::detectBCI()
{
    DBG("Detecting brain-computer interfaces...");

    // Would scan for:
    // - OpenBCI boards
    // - NeuroSky MindWave
    // - Emotiv EPOC
    // - Muse headbands
    // - Future: Neuralink-like neural implants
}

void UniversalDeviceManager::detectAccessibilityDevices()
{
    DBG("Detecting accessibility devices...");

    // Would scan for:
    // - Eye trackers (Tobii, etc.)
    // - Voice control systems
    // - Adaptive controllers (Xbox Adaptive Controller, etc.)
    // - Switch interfaces
    // - Sip-and-puff controllers
}
