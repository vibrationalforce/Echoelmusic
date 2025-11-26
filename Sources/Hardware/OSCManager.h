#pragma once

#include <JuceHeader.h>
#include <vector>
#include <map>
#include <functional>

namespace Eoel {

/**
 * OSCManager - Open Sound Control network protocol
 *
 * OSC allows network control between music/visual software and hardware.
 *
 * Supported OSC-enabled software:
 * - TouchDesigner, vvvv, Max/MSP, Pure Data
 * - Resolume Arena, MadMapper, VDMX
 * - QLab, Reaper, Bitwig Studio
 * - Processing, openFrameworks
 * - VR/AR applications (Unity, Unreal)
 *
 * Supported OSC hardware:
 * - Lemur (iPad/Android controller)
 * - TouchOSC (iOS/Android)
 * - Monome (Grid, Arc)
 * - Sensel Morph
 * - Lighting consoles (ETC, GrandMA)
 *
 * Features:
 * - Send/receive OSC messages (UDP/TCP)
 * - OSC bundles (timestamped message groups)
 * - OSC pattern matching (wildcards)
 * - Bidirectional control
 * - Auto-discovery (Bonjour/Zeroconf)
 * - Parameter mapping
 */
class OSCManager
{
public:
    struct OSCEndpoint
    {
        juce::String name;
        juce::String host;              // IP address or hostname
        int port;                       // UDP/TCP port
        bool isInput = false;
        bool isOutput = false;
        bool connected = false;
    };

    struct OSCMapping
    {
        juce::String oscAddress;        // e.g., "/synth/filter/cutoff"
        juce::String parameterID;       // Which parameter to control
        float min = 0.0f;
        float max = 1.0f;
        bool bidirectional = false;     // Send parameter changes back via OSC
        std::function<void(float)> callback;
    };

    OSCManager();
    ~OSCManager();

    // ===========================
    // Connection Management
    // ===========================

    /** Start OSC receiver on specified port */
    bool startReceiver(int port = 8000);

    /** Stop OSC receiver */
    void stopReceiver();

    /** Add OSC sender (output) */
    void addSender(const juce::String& name, const juce::String& host, int port);

    /** Remove OSC sender */
    void removeSender(const juce::String& name);

    /** Get all configured endpoints */
    std::vector<OSCEndpoint> getEndpoints() const;

    // ===========================
    // Sending OSC
    // ===========================

    /** Send OSC message with float value */
    void sendFloat(const juce::String& address, float value, const juce::String& senderName = "");

    /** Send OSC message with integer value */
    void sendInt(const juce::String& address, int value, const juce::String& senderName = "");

    /** Send OSC message with string value */
    void sendString(const juce::String& address, const juce::String& value, const juce::String& senderName = "");

    /** Send OSC message with multiple arguments */
    void sendMessage(const juce::OSCMessage& message, const juce::String& senderName = "");

    /** Send OSC bundle (timestamped group of messages) */
    void sendBundle(const juce::OSCBundle& bundle, const juce::String& senderName = "");

    // ===========================
    // Receiving OSC
    // ===========================

    /** Add OSC address listener (pattern matching supported) */
    void addListener(const juce::String& addressPattern, std::function<void(const juce::OSCMessage&)> callback);

    /** Remove listener */
    void removeListener(const juce::String& addressPattern);

    // ===========================
    // Parameter Mapping
    // ===========================

    /** Map OSC address to plugin parameter */
    void addMapping(const OSCMapping& mapping);

    /** Remove mapping */
    void removeMapping(const juce::String& oscAddress);

    /** Clear all mappings */
    void clearMappings();

    /** Enable OSC learn mode */
    void enableLearnMode(bool enable, std::function<void(const juce::String& address)> callback);

    // ===========================
    // Auto-Discovery
    // ===========================

    /** Enable Bonjour/Zeroconf auto-discovery */
    void enableAutoDiscovery(bool enable);

    /** Get discovered OSC services on network */
    std::vector<OSCEndpoint> getDiscoveredServices() const;

    // ===========================
    // Templates for Popular Apps
    // ===========================

    /** Setup for TouchOSC */
    void setupTouchOSC(const juce::String& ipAddress, int sendPort = 9000, int receivePort = 8000);

    /** Setup for TouchDesigner */
    void setupTouchDesigner(const juce::String& ipAddress, int sendPort = 7000, int receivePort = 7001);

    /** Setup for Resolume Arena */
    void setupResolume(const juce::String& ipAddress, int sendPort = 7000, int receivePort = 7001);

    /** Setup for QLab */
    void setupQLab(const juce::String& ipAddress, int sendPort = 53000, int receivePort = 53001);

    /** Setup for Max/MSP */
    void setupMaxMSP(int sendPort = 8000, int receivePort = 9000);

    // ===========================
    // Status
    // ===========================

    /** Check if receiver is active */
    bool isReceiverActive() const { return m_receiverActive; }

    /** Get receiver port */
    int getReceiverPort() const { return m_receiverPort; }

    /** Get number of active senders */
    int getNumSenders() const { return m_senders.size(); }

    // ===========================
    // Callbacks
    // ===========================

    std::function<void(const juce::OSCMessage&)> onMessageReceived;
    std::function<void(const OSCEndpoint& endpoint)> onEndpointConnected;
    std::function<void(const juce::String& name)> onEndpointDisconnected;

private:
    std::unique_ptr<juce::OSCReceiver> m_receiver;
    std::map<juce::String, std::unique_ptr<juce::OSCSender>> m_senders;
    std::vector<OSCMapping> m_mappings;
    std::vector<OSCEndpoint> m_endpoints;

    bool m_receiverActive = false;
    int m_receiverPort = 0;

    bool m_learnMode = false;
    std::function<void(const juce::String& address)> m_learnCallback;

    bool m_autoDiscovery = false;

    juce::CriticalSection m_lock;

    class OSCListener : public juce::OSCReceiver::Listener<juce::OSCReceiver::MessageLoopCallback>
    {
    public:
        OSCListener(OSCManager& manager) : m_manager(manager) {}
        void oscMessageReceived(const juce::OSCMessage& message) override;
        void oscBundleReceived(const juce::OSCBundle& bundle) override;

    private:
        OSCManager& m_manager;
    };

    std::unique_ptr<OSCListener> m_listener;

    void handleOSCMessage(const juce::OSCMessage& message);
    bool matchesPattern(const juce::String& address, const juce::String& pattern) const;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(OSCManager)
};

} // namespace Eoel
