#pragma once

#include <JuceHeader.h>
#include <atomic>
#include <functional>

namespace Echoelmusic {

/**
 * AbletonLink - Network-based tempo synchronization
 *
 * Sync with other Link-enabled devices on the network:
 * - Ableton Live, Logic Pro, FL Studio
 * - DJ software (Traktor, Serato, Rekordbox)
 * - Mobile apps (iOS/Android)
 * - Hardware (Pioneer CDJs, Akai Force, etc.)
 *
 * Features:
 * - Ultra-low latency tempo sync
 * - Phase alignment (beat/bar sync)
 * - Start/Stop transport sync
 * - Quantum settings (4/8/16 beat loops)
 * - Network auto-discovery
 */
class AbletonLink
{
public:
    struct SessionState
    {
        double tempo = 120.0;           // BPM
        double beat = 0.0;              // Current beat position
        double phase = 0.0;             // Phase within quantum (0.0 to 1.0)
        int numPeers = 0;               // Connected devices
        bool isPlaying = false;         // Transport state
        int quantum = 4;                // Beats per loop (4, 8, 16, 32)
    };

    AbletonLink();
    ~AbletonLink();

    // ===========================
    // Link Control
    // ===========================

    /** Enable/disable Link */
    void setEnabled(bool enabled);
    bool isEnabled() const { return m_enabled.load(); }

    /** Enable/disable Start Stop Sync */
    void setStartStopSyncEnabled(bool enabled);
    bool isStartStopSyncEnabled() const { return m_startStopSync.load(); }

    // ===========================
    // Tempo & Transport
    // ===========================

    /** Set tempo (will sync to network if connected) */
    void setTempo(double bpm);
    double getTempo() const;

    /** Set quantum (beats per loop: 4, 8, 16, 32) */
    void setQuantum(int quantum);
    int getQuantum() const { return m_quantum.load(); }

    /** Transport control */
    void play();
    void stop();
    void requestBeatAtTime(double beat, std::chrono::microseconds time);

    // ===========================
    // Session State
    // ===========================

    /** Get current session state */
    SessionState getSessionState() const;

    /** Get number of connected peers */
    int getNumPeers() const { return m_numPeers.load(); }

    /** Get current beat position */
    double getBeat() const;

    /** Get phase within quantum (0.0 to 1.0) */
    double getPhase() const;

    /** Check if transport is playing */
    bool isPlaying() const { return m_isPlaying.load(); }

    // ===========================
    // Audio Processing
    // ===========================

    /**
     * Process audio buffer with Link timing
     * Call this in your audio callback to maintain sync
     */
    void processAudio(juce::AudioBuffer<float>& buffer, int numSamples);

    /**
     * Get beat position for a specific sample in the buffer
     * Useful for scheduling events with sample-accurate timing
     */
    double getBeatAtSample(int sampleIndex, int bufferSize) const;

    // ===========================
    // Callbacks
    // ===========================

    /** Called when tempo changes (from network or local) */
    std::function<void(double newTempo)> onTempoChanged;

    /** Called when transport state changes */
    std::function<void(bool isPlaying)> onPlayStateChanged;

    /** Called when number of peers changes */
    std::function<void(int numPeers)> onNumPeersChanged;

    /** Called when a new session is joined */
    std::function<void()> onSessionJoined;

private:
    // Link state
    std::atomic<bool> m_enabled { false };
    std::atomic<bool> m_startStopSync { false };
    std::atomic<double> m_tempo { 120.0 };
    std::atomic<int> m_quantum { 4 };
    std::atomic<int> m_numPeers { 0 };
    std::atomic<bool> m_isPlaying { false };

    // Timing
    std::atomic<double> m_currentBeat { 0.0 };
    std::atomic<double> m_phase { 0.0 };

    // Audio sync
    double m_sampleRate = 44100.0;
    std::chrono::microseconds m_lastTime { 0 };

    // Thread safety
    juce::CriticalSection m_lock;

    // Update loop (polls Link state at ~120Hz)
    class UpdateThread : public juce::Thread
    {
    public:
        UpdateThread(AbletonLink& link) : juce::Thread("Link Update"), m_link(link) {}
        void run() override;
    private:
        AbletonLink& m_link;
    };

    std::unique_ptr<UpdateThread> m_updateThread;

    void updateState();
    void notifyCallbacks();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(AbletonLink)
};

} // namespace Echoelmusic
