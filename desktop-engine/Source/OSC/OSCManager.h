// OSCManager.h
// Desktop OSC Server Implementation Template for Echoelmusic (JUCE)
//
// Usage:
// 1. Copy OSCManager.h and OSCManager.cpp to: desktop-engine/Source/OSC/
// 2. Add to JUCE project in Projucer
// 3. Include in MainComponent.h: #include "OSC/OSCManager.h"
// 4. Initialize: oscManager.initialize(8000);
// 5. Set callbacks: oscManager.onHeartRateReceived = [](float bpm) { /* ... */ };

#pragma once
#include <JuceHeader.h>
#include <functional>
#include <atomic>

/**
 * OSC Server Manager for Echoelmusic Desktop Engine
 *
 * Receives biofeedback data from iOS app and sends analysis back.
 * Uses JUCE's OSCReceiver/OSCSender for communication.
 */
class OSCManager : public juce::OSCReceiver,
                   private juce::OSCReceiver::Listener<juce::OSCReceiver::MessageLoopCallback>
{
public:
    OSCManager();
    ~OSCManager() override;

    // ========== Connection Management ==========

    /**
     * Initialize OSC server
     * @param port UDP port to bind (default: 8000)
     * @return true if successful
     */
    bool initialize(int port = 8000);

    /**
     * Shutdown OSC server
     */
    void shutdown();

    /**
     * Check if OSC server is connected
     */
    bool isConnected() const { return connected.load(); }

    // ========== Callbacks for Received Data ==========

    /// Called when heart rate received from iOS
    std::function<void(float bpm)> onHeartRateReceived;

    /// Called when HRV received from iOS
    std::function<void(float ms)> onHRVReceived;

    /// Called when breath rate received from iOS
    std::function<void(float breathsPerMin)> onBreathRateReceived;

    /// Called when voice pitch received from iOS
    std::function<void(float frequencyHz, float confidence)> onPitchReceived;

    /// Called when audio amplitude received from iOS
    std::function<void(float db)> onAmplitudeReceived;

    /// Called when scene selection received from iOS
    std::function<void(int sceneId)> onSceneSelected;

    /// Called when parameter change received from iOS
    std::function<void(juce::String paramName, float value)> onParameterChanged;

    /// Called when system command received (start/stop/reset)
    std::function<void(juce::String command)> onSystemCommand;

    // ========== Send Analysis to iOS ==========

    /**
     * Send audio analysis (RMS and peak levels) to iOS
     * @param rmsDb RMS level in dB (-80 to 0)
     * @param peakDb Peak level in dB (-80 to 0)
     */
    void sendAudioAnalysis(float rmsDb, float peakDb);

    /**
     * Send spectrum analysis to iOS
     * @param bands 8 frequency bands in dB (-80 to 0)
     */
    void sendSpectrum(const std::vector<float>& bands);

    /**
     * Send CPU load to iOS
     * @param percentage CPU usage (0-100)
     */
    void sendCPULoad(float percentage);

    /**
     * Set iOS client address (for sending messages back)
     * @param ipAddress iOS device IP (e.g., "192.168.1.50")
     * @param port iOS listening port (default: 8001)
     */
    void setClientAddress(const juce::String& ipAddress, int port = 8001);

    // ========== Statistics ==========

    struct Statistics {
        int messagesReceived = 0;
        int messagesSent = 0;
        int errors = 0;
        double lastMessageTime = 0.0;
        float latencyMs = 0.0f;
    };

    Statistics getStatistics() const { return stats; }
    void resetStatistics();

private:
    // ========== OSC Receiver Implementation ==========

    /**
     * Called when OSC message received (JUCE callback)
     */
    void oscMessageReceived(const juce::OSCMessage& message) override;

    // ========== Helper Methods ==========

    void handleBiofeedbackMessage(const juce::OSCMessage& message);
    void handleControlMessage(const juce::OSCMessage& message);
    void handleSyncMessage(const juce::OSCMessage& message);

    bool validateRange(float value, float min, float max, const juce::String& name);

    // ========== Members ==========

    juce::OSCSender oscSender;
    juce::String clientAddress;
    int clientPort = 8001;

    std::atomic<bool> connected{false};
    Statistics stats;

    juce::CriticalSection callbackLock;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(OSCManager)
};
