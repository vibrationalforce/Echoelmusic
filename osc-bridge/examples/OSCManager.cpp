// OSCManager.cpp
// Desktop OSC Server Implementation for Echoelmusic (JUCE)

#include "OSCManager.h"

OSCManager::OSCManager()
{
}

OSCManager::~OSCManager()
{
    shutdown();
}

// ========== Connection Management ==========

bool OSCManager::initialize(int port)
{
    if (!connect(port))
    {
        DBG("OSC: Failed to bind to port " + juce::String(port));
        return false;
    }

    addListener(this);
    connected = true;

    DBG("OSC: Server listening on port " + juce::String(port));
    return true;
}

void OSCManager::shutdown()
{
    if (connected)
    {
        disconnect();
        connected = false;
        DBG("OSC: Server shut down");
    }
}

void OSCManager::setClientAddress(const juce::String& ipAddress, int port)
{
    clientAddress = ipAddress;
    clientPort = port;

    if (!oscSender.connect(clientAddress, clientPort))
    {
        DBG("OSC: Failed to connect sender to " + clientAddress + ":" + juce::String(clientPort));
    }
    else
    {
        DBG("OSC: Sender connected to " + clientAddress + ":" + juce::String(clientPort));
    }
}

// ========== Message Receiver ==========

void OSCManager::oscMessageReceived(const juce::OSCMessage& message)
{
    stats.messagesReceived++;
    stats.lastMessageTime = juce::Time::getMillisecondCounterHiRes();

    auto address = message.getAddressPattern().toString();

    // Route to appropriate handler
    if (address.startsWith("/echoel/bio/"))
    {
        handleBiofeedbackMessage(message);
    }
    else if (address.startsWith("/echoel/scene/") ||
             address.startsWith("/echoel/param/") ||
             address.startsWith("/echoel/system/") ||
             address.startsWith("/echoel/audio/"))
    {
        handleControlMessage(message);
    }
    else if (address.startsWith("/echoel/sync/"))
    {
        handleSyncMessage(message);
    }
    else
    {
        DBG("OSC: Unknown message: " + address);
    }
}

void OSCManager::handleBiofeedbackMessage(const juce::OSCMessage& message)
{
    auto address = message.getAddressPattern().toString();

    // Heart Rate
    if (address == "/echoel/bio/heartrate" && message.size() == 1)
    {
        if (auto* arg = message[0].getFloat32())
        {
            float bpm = *arg;
            if (validateRange(bpm, 40.0f, 200.0f, "Heart Rate"))
            {
                DBG("OSC: Heart Rate: " + juce::String(bpm, 1) + " bpm");
                if (onHeartRateReceived)
                    onHeartRateReceived(bpm);
            }
        }
    }
    // HRV
    else if (address == "/echoel/bio/hrv" && message.size() == 1)
    {
        if (auto* arg = message[0].getFloat32())
        {
            float hrv = *arg;
            if (validateRange(hrv, 0.0f, 200.0f, "HRV"))
            {
                DBG("OSC: HRV: " + juce::String(hrv, 1) + " ms");
                if (onHRVReceived)
                    onHRVReceived(hrv);
            }
        }
    }
    // Breath Rate
    else if (address == "/echoel/bio/breathrate" && message.size() == 1)
    {
        if (auto* arg = message[0].getFloat32())
        {
            float breathRate = *arg;
            if (validateRange(breathRate, 5.0f, 30.0f, "Breath Rate"))
            {
                DBG("OSC: Breath Rate: " + juce::String(breathRate, 1) + " /min");
                if (onBreathRateReceived)
                    onBreathRateReceived(breathRate);
            }
        }
    }
}

void OSCManager::handleControlMessage(const juce::OSCMessage& message)
{
    auto address = message.getAddressPattern().toString();

    // Voice Pitch
    if (address == "/echoel/audio/pitch" && message.size() == 2)
    {
        if (auto* freq = message[0].getFloat32())
        {
            if (auto* conf = message[1].getFloat32())
            {
                float frequency = *freq;
                float confidence = *conf;

                if (validateRange(frequency, 80.0f, 1000.0f, "Pitch Frequency") &&
                    validateRange(confidence, 0.0f, 1.0f, "Pitch Confidence"))
                {
                    // Only log high-confidence pitches to avoid spam
                    if (confidence > 0.7f)
                    {
                        DBG("OSC: Pitch: " + juce::String(frequency, 1) +
                            " Hz (conf: " + juce::String(confidence, 2) + ")");
                    }

                    if (onPitchReceived)
                        onPitchReceived(frequency, confidence);
                }
            }
        }
    }
    // Audio Amplitude
    else if (address == "/echoel/audio/amplitude" && message.size() == 1)
    {
        if (auto* arg = message[0].getFloat32())
        {
            float amplitude = *arg;
            if (validateRange(amplitude, -80.0f, 0.0f, "Amplitude"))
            {
                if (onAmplitudeReceived)
                    onAmplitudeReceived(amplitude);
            }
        }
    }
    // Scene Selection
    else if (address == "/echoel/scene/select" && message.size() == 1)
    {
        if (auto* arg = message[0].getInt32())
        {
            int sceneId = *arg;
            if (sceneId >= 0 && sceneId <= 4)
            {
                DBG("OSC: Scene selected: " + juce::String(sceneId));
                if (onSceneSelected)
                    onSceneSelected(sceneId);
            }
        }
    }
    // Parameter Control
    else if (address.startsWith("/echoel/param/") && message.size() == 1)
    {
        if (auto* arg = message[0].getFloat32())
        {
            juce::String paramName = address.fromLastOccurrenceOf("/", false, false);
            float value = *arg;

            if (validateRange(value, 0.0f, 1.0f, "Parameter " + paramName))
            {
                DBG("OSC: Parameter: " + paramName + " = " + juce::String(value, 3));
                if (onParameterChanged)
                    onParameterChanged(paramName, value);
            }
        }
    }
    // System Commands
    else if (address.startsWith("/echoel/system/"))
    {
        juce::String command = address.fromLastOccurrenceOf("/", false, false);
        DBG("OSC: System command: " + command);

        if (onSystemCommand)
            onSystemCommand(command);
    }
}

void OSCManager::handleSyncMessage(const juce::OSCMessage& message)
{
    auto address = message.getAddressPattern().toString();

    // Ping request
    if (address == "/echoel/sync/ping" && message.size() == 1)
    {
        if (auto* timestamp = message[0].getInt32())
        {
            // Send pong with same timestamp
            if (oscSender.isConnected())
            {
                juce::OSCMessage pong("/echoel/sync/pong");
                pong.addInt32(*timestamp);
                oscSender.send(pong);
            }
        }
    }
}

// ========== Send Messages to iOS ==========

void OSCManager::sendAudioAnalysis(float rmsDb, float peakDb)
{
    if (!oscSender.isConnected())
        return;

    // Clamp values
    rmsDb = juce::jlimit(-80.0f, 0.0f, rmsDb);
    peakDb = juce::jlimit(-80.0f, 0.0f, peakDb);

    // Send RMS
    juce::OSCMessage rmsMsg("/echoel/analysis/rms");
    rmsMsg.addFloat32(rmsDb);
    if (oscSender.send(rmsMsg))
        stats.messagesSent++;

    // Send Peak
    juce::OSCMessage peakMsg("/echoel/analysis/peak");
    peakMsg.addFloat32(peakDb);
    if (oscSender.send(peakMsg))
        stats.messagesSent++;
}

void OSCManager::sendSpectrum(const std::vector<float>& bands)
{
    if (!oscSender.isConnected() || bands.size() != 8)
        return;

    juce::OSCMessage msg("/echoel/analysis/spectrum");

    for (float band : bands)
    {
        float clampedBand = juce::jlimit(-80.0f, 0.0f, band);
        msg.addFloat32(clampedBand);
    }

    if (oscSender.send(msg))
        stats.messagesSent++;
}

void OSCManager::sendCPULoad(float percentage)
{
    if (!oscSender.isConnected())
        return;

    percentage = juce::jlimit(0.0f, 100.0f, percentage);

    juce::OSCMessage msg("/echoel/status/cpu");
    msg.addFloat32(percentage);

    if (oscSender.send(msg))
        stats.messagesSent++;
}

// ========== Utilities ==========

bool OSCManager::validateRange(float value, float min, float max, const juce::String& name)
{
    if (value < min || value > max)
    {
        DBG("OSC: Invalid " + name + ": " + juce::String(value) +
            " (expected " + juce::String(min) + "-" + juce::String(max) + ")");
        stats.errors++;
        return false;
    }
    return true;
}

void OSCManager::resetStatistics()
{
    stats = Statistics();
}
