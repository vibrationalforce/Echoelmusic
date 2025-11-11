#include "OSCManager.h"

namespace Echoelmusic {

OSCManager::OSCManager()
{
    m_listener = std::make_unique<OSCListener>(*this);
}

OSCManager::~OSCManager()
{
    stopReceiver();
}

// ===========================
// Connection Management
// ===========================

bool OSCManager::startReceiver(int port)
{
    juce::ScopedLock sl(m_lock);

    if (m_receiverActive)
        stopReceiver();

    m_receiver = std::make_unique<juce::OSCReceiver>();

    if (m_receiver->connect(port))
    {
        m_receiver->addListener(m_listener.get());
        m_receiverActive = true;
        m_receiverPort = port;

        DBG("OSC Receiver started on port " << port);
        return true;
    }
    else
    {
        DBG("Failed to start OSC receiver on port " << port);
        m_receiver.reset();
        return false;
    }
}

void OSCManager::stopReceiver()
{
    juce::ScopedLock sl(m_lock);

    if (m_receiver)
    {
        m_receiver->removeListener(m_listener.get());
        m_receiver->disconnect();
        m_receiver.reset();
    }

    m_receiverActive = false;
    m_receiverPort = 0;

    DBG("OSC Receiver stopped");
}

void OSCManager::addSender(const juce::String& name, const juce::String& host, int port)
{
    juce::ScopedLock sl(m_lock);

    auto sender = std::make_unique<juce::OSCSender>();

    if (sender->connect(host, port))
    {
        m_senders[name] = std::move(sender);

        OSCEndpoint endpoint;
        endpoint.name = name;
        endpoint.host = host;
        endpoint.port = port;
        endpoint.isOutput = true;
        endpoint.connected = true;

        m_endpoints.push_back(endpoint);

        DBG("OSC Sender added: " << name << " → " << host << ":" << port);

        if (onEndpointConnected)
            onEndpointConnected(endpoint);
    }
    else
    {
        DBG("Failed to connect OSC sender to " << host << ":" << port);
    }
}

void OSCManager::removeSender(const juce::String& name)
{
    juce::ScopedLock sl(m_lock);

    auto it = m_senders.find(name);
    if (it != m_senders.end())
    {
        it->second->disconnect();
        m_senders.erase(it);

        // Remove from endpoints
        m_endpoints.erase(
            std::remove_if(m_endpoints.begin(), m_endpoints.end(),
                [&name](const OSCEndpoint& ep) { return ep.name == name; }),
            m_endpoints.end());

        DBG("OSC Sender removed: " << name);

        if (onEndpointDisconnected)
            onEndpointDisconnected(name);
    }
}

std::vector<OSCManager::OSCEndpoint> OSCManager::getEndpoints() const
{
    juce::ScopedLock sl(m_lock);
    return m_endpoints;
}

// ===========================
// Sending OSC
// ===========================

void OSCManager::sendFloat(const juce::String& address, float value, const juce::String& senderName)
{
    juce::OSCMessage message(address);
    message.addFloat32(value);
    sendMessage(message, senderName);
}

void OSCManager::sendInt(const juce::String& address, int value, const juce::String& senderName)
{
    juce::OSCMessage message(address);
    message.addInt32(value);
    sendMessage(message, senderName);
}

void OSCManager::sendString(const juce::String& address, const juce::String& value, const juce::String& senderName)
{
    juce::OSCMessage message(address);
    message.addString(value);
    sendMessage(message, senderName);
}

void OSCManager::sendMessage(const juce::OSCMessage& message, const juce::String& senderName)
{
    juce::ScopedLock sl(m_lock);

    if (senderName.isEmpty())
    {
        // Send to all senders
        for (auto& pair : m_senders)
        {
            pair.second->send(message);
        }
    }
    else
    {
        // Send to specific sender
        auto it = m_senders.find(senderName);
        if (it != m_senders.end())
        {
            it->second->send(message);
        }
    }
}

void OSCManager::sendBundle(const juce::OSCBundle& bundle, const juce::String& senderName)
{
    juce::ScopedLock sl(m_lock);

    if (senderName.isEmpty())
    {
        for (auto& pair : m_senders)
        {
            pair.second->send(bundle);
        }
    }
    else
    {
        auto it = m_senders.find(senderName);
        if (it != m_senders.end())
        {
            it->second->send(bundle);
        }
    }
}

// ===========================
// Parameter Mapping
// ===========================

void OSCManager::addMapping(const OSCMapping& mapping)
{
    juce::ScopedLock sl(m_lock);
    m_mappings.push_back(mapping);

    DBG("OSC mapping added: " << mapping.oscAddress << " → " << mapping.parameterID);
}

void OSCManager::removeMapping(const juce::String& oscAddress)
{
    juce::ScopedLock sl(m_lock);

    m_mappings.erase(
        std::remove_if(m_mappings.begin(), m_mappings.end(),
            [&oscAddress](const OSCMapping& m) { return m.oscAddress == oscAddress; }),
        m_mappings.end());
}

void OSCManager::clearMappings()
{
    juce::ScopedLock sl(m_lock);
    m_mappings.clear();
    DBG("All OSC mappings cleared");
}

void OSCManager::enableLearnMode(bool enable, std::function<void(const juce::String& address)> callback)
{
    m_learnMode = enable;
    m_learnCallback = callback;

    DBG("OSC Learn Mode: " << (enable ? "ENABLED - Waiting for OSC message..." : "DISABLED"));
}

// ===========================
// Auto-Discovery
// ===========================

void OSCManager::enableAutoDiscovery(bool enable)
{
    m_autoDiscovery = enable;

    if (enable)
    {
        DBG("OSC auto-discovery ENABLED (Bonjour/Zeroconf)");
        // Real implementation would use juce::NetworkServiceDiscovery
    }
    else
    {
        DBG("OSC auto-discovery DISABLED");
    }
}

std::vector<OSCManager::OSCEndpoint> OSCManager::getDiscoveredServices() const
{
    std::vector<OSCEndpoint> discovered;
    // Real implementation would return discovered OSC services
    return discovered;
}

// ===========================
// Templates
// ===========================

void OSCManager::setupTouchOSC(const juce::String& ipAddress, int sendPort, int receivePort)
{
    startReceiver(receivePort);
    addSender("TouchOSC", ipAddress, sendPort);

    DBG("TouchOSC configured:");
    DBG("  Send to: " << ipAddress << ":" << sendPort);
    DBG("  Receive on: port " << receivePort);
}

void OSCManager::setupTouchDesigner(const juce::String& ipAddress, int sendPort, int receivePort)
{
    startReceiver(receivePort);
    addSender("TouchDesigner", ipAddress, sendPort);

    DBG("TouchDesigner configured:");
    DBG("  Send to: " << ipAddress << ":" << sendPort);
    DBG("  Receive on: port " << receivePort);
}

void OSCManager::setupResolume(const juce::String& ipAddress, int sendPort, int receivePort)
{
    startReceiver(receivePort);
    addSender("Resolume", ipAddress, sendPort);

    DBG("Resolume Arena configured:");
    DBG("  Send to: " << ipAddress << ":" << sendPort);
    DBG("  Receive on: port " << receivePort);
}

void OSCManager::setupQLab(const juce::String& ipAddress, int sendPort, int receivePort)
{
    startReceiver(receivePort);
    addSender("QLab", ipAddress, sendPort);

    DBG("QLab configured:");
    DBG("  Send to: " << ipAddress << ":" << sendPort);
    DBG("  Receive on: port " << receivePort);
}

void OSCManager::setupMaxMSP(int sendPort, int receivePort)
{
    startReceiver(receivePort);
    addSender("MaxMSP", "127.0.0.1", sendPort); // Localhost

    DBG("Max/MSP configured (localhost):");
    DBG("  Send to: port " << sendPort);
    DBG("  Receive on: port " << receivePort);
}

// ===========================
// OSC Listener
// ===========================

void OSCManager::OSCListener::oscMessageReceived(const juce::OSCMessage& message)
{
    m_manager.handleOSCMessage(message);
}

void OSCManager::OSCListener::oscBundleReceived(const juce::OSCBundle& bundle)
{
    // Process each message in bundle
    for (int i = 0; i < bundle.size(); ++i)
    {
        auto element = bundle[i];
        if (element.isMessage())
            m_manager.handleOSCMessage(element.getMessage());
        else if (element.isBundle())
            oscBundleReceived(element.getBundle());
    }
}

void OSCManager::handleOSCMessage(const juce::OSCMessage& message)
{
    juce::String address = message.getAddressPattern().toString();

    // Learn mode
    if (m_learnMode)
    {
        if (m_learnCallback)
            m_learnCallback(address);

        m_learnMode = false;
        return;
    }

    // Check mappings
    for (const auto& mapping : m_mappings)
    {
        if (matchesPattern(address, mapping.oscAddress))
        {
            // Extract value
            if (message.size() > 0)
            {
                float value = 0.0f;

                if (message[0].isFloat32())
                    value = message[0].getFloat32();
                else if (message[0].isInt32())
                    value = static_cast<float>(message[0].getInt32());

                // Scale value
                value = juce::jmap(value, mapping.min, mapping.max, 0.0f, 1.0f);

                // Trigger callback
                if (mapping.callback)
                    mapping.callback(value);
            }

            break;
        }
    }

    // Global callback
    if (onMessageReceived)
        onMessageReceived(message);

    // Debug log
    DBG("OSC received: " << address);
}

bool OSCManager::matchesPattern(const juce::String& address, const juce::String& pattern) const
{
    // Simple pattern matching (wildcards: * and ?)
    // Real implementation would support full OSC pattern matching spec

    if (pattern == address)
        return true;

    // Support wildcards
    if (pattern.contains("*"))
    {
        // Very simple wildcard matching
        juce::String prefix = pattern.upToFirstOccurrenceOf("*", false, false);
        return address.startsWith(prefix);
    }

    return false;
}

} // namespace Echoelmusic
