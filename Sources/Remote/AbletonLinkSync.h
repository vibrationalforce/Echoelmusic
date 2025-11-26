#pragma once

#include <JuceHeader.h>
#include <atomic>
#include <functional>

/**
 * AbletonLinkSync - Sample-Accurate Tempo Synchronization
 *
 * Implements Ableton Link protocol for ultra-low latency tempo sync
 * across devices and applications.
 *
 * Features:
 * - Sample-accurate beat/bar synchronization
 * - Phase alignment (quantum)
 * - Start/Stop transport sync
 * - Network-wide tempo changes
 * - Auto-discovery of Link peers
 * - Works with ALL Link-enabled apps (Ableton Live, Logic, FL Studio, etc.)
 *
 * Network:
 * - Uses UDP multicast for discovery
 * - Uses UDP for clock sync (NTP-like)
 * - Latency compensation
 * - Works over WiFi, Ethernet, even mobile hotspot
 *
 * Integration:
 * - Download Ableton Link SDK: https://github.com/Ableton/link
 * - Add to project: ThirdParty/link/include/ableton/Link.hpp
 * - C++14 required
 * - Header-only library (no linking needed!)
 *
 * Usage:
 *   AbletonLinkSync link;
 *   link.setEnabled(true);
 *   link.setTempo(128.0);
 *
 *   // In audio callback:
 *   void processBlock(AudioBuffer& buffer, int numSamples)
 *   {
 *       link.processAudio(buffer.getNumSamples());
 *       double beat = link.getBeat();
 *       // Use beat for sequencing, effects, etc.
 *   }
 */
class AbletonLinkSync
{
public:
    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    AbletonLinkSync();
    ~AbletonLinkSync();

    //==========================================================================
    // Enable / Disable
    //==========================================================================

    /** Enable Link (join session) */
    void setEnabled(bool enabled);
    bool isEnabled() const;

    /** Check if connected to peers */
    bool isConnected() const;

    /** Get number of connected peers */
    int getNumPeers() const;

    //==========================================================================
    // Tempo Control
    //==========================================================================

    /** Set tempo (BPM) */
    void setTempo(double bpm);

    /** Get current tempo */
    double getTempo() const;

    /** Callback when tempo changed by another peer */
    std::function<void(double newTempo)> onTempoChanged;

    //==========================================================================
    // Transport Control
    //==========================================================================

    /** Enable start/stop sync */
    void enableStartStopSync(bool enabled);
    bool isStartStopSyncEnabled() const;

    /** Set playing state */
    void setPlaying(bool playing);
    bool isPlaying() const;

    /** Request beat at time (for start alignment) */
    void requestBeatAtTime(double beat, std::chrono::microseconds atTime);

    //==========================================================================
    // Quantum (Phase Alignment)
    //==========================================================================

    /** Set quantum (e.g., 4 = align to 4-beat bars) */
    void setQuantum(double quantum);
    double getQuantum() const;

    /** Force beat at time (for manual phase correction) */
    void forceBeatAtTime(double beat, std::chrono::microseconds atTime);

    //==========================================================================
    // Beat/Phase Queries
    //==========================================================================

    /** Get current beat position */
    double getBeat() const;

    /** Get beat at specific sample offset */
    double getBeatAtSample(int sampleOffset, int bufferSize) const;

    /** Get phase (0.0 to 1.0 within quantum) */
    double getPhase() const;

    /** Get phase at specific sample offset */
    double getPhaseAtSample(int sampleOffset, int bufferSize) const;

    /** Check if currently at quantum boundary */
    bool isAtQuantumBoundary() const;

    //==========================================================================
    // Time Queries
    //==========================================================================

    /** Get current Link time (microseconds) */
    std::chrono::microseconds getTime() const;

    /** Convert sample offset to Link time */
    std::chrono::microseconds sampleOffsetToTime(
        int sampleOffset,
        double sampleRate,
        int bufferSize
    ) const;

    //==========================================================================
    // Audio Processing
    //==========================================================================

    /** Call this in your audio callback */
    void processAudio(int numSamples, double sampleRate = 48000.0);

    /** Get beat at start of current audio buffer */
    double getBufferStartBeat() const { return bufferStartBeat; }

    /** Get phase at start of current audio buffer */
    double getBufferStartPhase() const { return bufferStartPhase; }

    //==========================================================================
    // Callbacks
    //==========================================================================

    std::function<void(int numPeers)> onNumPeersChanged;
    std::function<void(bool playing)> onPlayingStateChanged;

private:
    //==========================================================================
    // Ableton Link Implementation (forward declaration)
    //==========================================================================

    struct LinkImpl;
    std::unique_ptr<LinkImpl> impl;

    //==========================================================================
    // Internal State
    //==========================================================================

    std::atomic<bool> enabled { false };
    std::atomic<double> currentTempo { 120.0 };
    std::atomic<double> currentQuantum { 4.0 };
    std::atomic<bool> playing { false };
    std::atomic<int> numPeers { 0 };

    double bufferStartBeat = 0.0;
    double bufferStartPhase = 0.0;

    double sampleRate = 48000.0;
    std::chrono::microseconds lastProcessTime { 0 };

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void updateInternalState();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(AbletonLinkSync)
};
