#pragma once

#include <JuceHeader.h>
#include <atomic>

namespace Echoelmusic {

/**
 * HardwareSyncManager - Master clock sync for all hardware
 *
 * Supported sync protocols:
 * - MIDI Clock (24 PPQN - pulses per quarter note)
 * - MIDI Time Code (MTC) - SMPTE timecode via MIDI
 * - Linear Time Code (LTC) - SMPTE timecode via audio
 * - Word Clock (digital audio clock sync)
 * - S/PDIF sync
 * - ADAT sync
 * - Ableton Link (network sync)
 * - Pro DJ Link (Pioneer network sync)
 *
 * Use cases:
 * - Sync DAW with hardware sequencers/drum machines
 * - Sync multiple DAWs together
 * - Sync video playback with audio (film scoring)
 * - Sync lights/lasers with music
 * - Sync modular synthesizer sequencers
 *
 * Features:
 * - Master/slave clock modes
 * - Sample-accurate sync
 * - Drift compensation
 * - Tempo change smoothing
 * - Transport control (play/stop/record)
 */
class HardwareSyncManager
{
public:
    enum class SyncSource
    {
        Internal,           // Software tempo
        MIDIClock,          // External MIDI clock
        MTC,                // MIDI Time Code
        LTC,                // Linear Time Code (audio)
        WordClock,          // Digital audio clock
        AbletonLink,        // Network sync
        ProDJLink          // Pioneer network sync
    };

    enum class TransportState
    {
        Stopped,
        Playing,
        Recording,
        Paused
    };

    struct SyncStatus
    {
        SyncSource currentSource = SyncSource::Internal;
        TransportState transport = TransportState::Stopped;
        double bpm = 120.0;
        double songPosition = 0.0;      // Beats
        bool synced = false;            // External sync locked
        double drift = 0.0;             // ms drift from external clock
    };

    HardwareSyncManager();
    ~HardwareSyncManager();

    // ===========================
    // Sync Source
    // ===========================

    /** Set sync source (master clock) */
    void setSyncSource(SyncSource source);

    /** Get current sync source */
    SyncSource getSyncSource() const { return m_syncSource; }

    /** Check if synced to external clock */
    bool isSynced() const { return m_synced.load(); }

    // ===========================
    // Transport Control
    // ===========================

    /** Play */
    void play();

    /** Stop */
    void stop();

    /** Pause */
    void pause();

    /** Record */
    void record();

    /** Get transport state */
    TransportState getTransportState() const { return m_transportState; }

    // ===========================
    // Tempo & Position
    // ===========================

    /** Set tempo (when in Internal mode) */
    void setTempo(double bpm);

    /** Get current tempo */
    double getTempo() const { return m_bpm.load(); }

    /** Set song position (beats) */
    void setSongPosition(double beats);

    /** Get song position (beats) */
    double getSongPosition() const { return m_songPosition.load(); }

    /** Get song position (SMPTE timecode) */
    juce::String getSMPTETimecode() const;

    // ===========================
    // MIDI Clock Output
    // ===========================

    /** Enable MIDI clock output */
    void enableMIDIClockOutput(bool enable, const juce::String& midiOutputDevice = "");

    /** Send MIDI start message */
    void sendMIDIStart();

    /** Send MIDI stop message */
    void sendMIDIStop();

    /** Send MIDI continue message */
    void sendMIDIContinue();

    /** Send MIDI clock tick (24 PPQN) */
    void sendMIDIClockTick();

    /** Send MIDI song position pointer */
    void sendMIDISongPosition(int beats);

    // ===========================
    // MTC (MIDI Time Code) Output
    // ===========================

    /** Enable MTC output */
    void enableMTCOutput(bool enable, const juce::String& midiOutputDevice = "");

    /** Set MTC frame rate */
    void setMTCFrameRate(int fps = 30); // 24, 25, 30, 29.97

    // ===========================
    // LTC (Linear Time Code) Output
    // ===========================

    /** Enable LTC output (via audio channel) */
    void enableLTCOutput(bool enable, int audioChannel = 0);

    /** Set LTC frame rate */
    void setLTCFrameRate(int fps = 30);

    // ===========================
    // Audio Processing
    // ===========================

    /**
     * Process audio buffer (update sync, send/receive timecode)
     * Call this in your audio callback
     */
    void processAudio(juce::AudioBuffer<float>& buffer, int numSamples);

    // ===========================
    // Drift Compensation
    // ===========================

    /** Get clock drift (ms) */
    double getDrift() const { return m_drift.load(); }

    /** Enable drift compensation */
    void enableDriftCompensation(bool enable) { m_driftCompensation = enable; }

    // ===========================
    // Status
    // ===========================

    /** Get sync status */
    SyncStatus getStatus() const;

    // ===========================
    // Callbacks
    // ===========================

    std::function<void(TransportState state)> onTransportChanged;
    std::function<void(double bpm)> onTempoChanged;
    std::function<void(double beats)> onPositionChanged;
    std::function<void(bool synced)> onSyncStatusChanged;

private:
    SyncSource m_syncSource = SyncSource::Internal;
    TransportState m_transportState = TransportState::Stopped;

    std::atomic<double> m_bpm { 120.0 };
    std::atomic<double> m_songPosition { 0.0 };
    std::atomic<bool> m_synced { false };
    std::atomic<double> m_drift { 0.0 };

    // MIDI Clock
    bool m_midiClockOutputEnabled = false;
    std::unique_ptr<juce::MidiOutput> m_midiClockOutput;
    int m_midiClockTicks = 0;       // 24 ticks per quarter note
    double m_midiClockPhase = 0.0;

    // MTC
    bool m_mtcOutputEnabled = false;
    std::unique_ptr<juce::MidiOutput> m_mtcOutput;
    int m_mtcFrameRate = 30;

    // LTC
    bool m_ltcOutputEnabled = false;
    int m_ltcChannel = 0;
    int m_ltcFrameRate = 30;

    // Sync
    bool m_driftCompensation = true;
    double m_sampleRate = 44100.0;

    juce::CriticalSection m_lock;

    void updateMIDIClock(int numSamples);
    void updateMTC(int numSamples);
    void updateLTC(juce::AudioBuffer<float>& buffer, int numSamples);
    void compensateDrift();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(HardwareSyncManager)
};

} // namespace Echoelmusic
