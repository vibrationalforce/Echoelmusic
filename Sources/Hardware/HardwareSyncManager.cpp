#include "HardwareSyncManager.h"

namespace Eoel {

HardwareSyncManager::HardwareSyncManager()
{
    DBG("Hardware Sync Manager initialized");
}

HardwareSyncManager::~HardwareSyncManager()
{
    enableMIDIClockOutput(false);
    enableMTCOutput(false);
}

// ===========================
// Sync Source
// ===========================

void HardwareSyncManager::setSyncSource(SyncSource source)
{
    juce::ScopedLock sl(m_lock);

    m_syncSource = source;

    juce::String sourceName;
    switch (source)
    {
        case SyncSource::Internal:      sourceName = "Internal"; break;
        case SyncSource::MIDIClock:     sourceName = "MIDI Clock"; break;
        case SyncSource::MTC:           sourceName = "MIDI Time Code"; break;
        case SyncSource::LTC:           sourceName = "Linear Time Code"; break;
        case SyncSource::WordClock:     sourceName = "Word Clock"; break;
        case SyncSource::AbletonLink:   sourceName = "Ableton Link"; break;
        case SyncSource::ProDJLink:     sourceName = "Pro DJ Link"; break;
    }

    DBG("Sync source set to: " << sourceName);
}

// ===========================
// Transport Control
// ===========================

void HardwareSyncManager::play()
{
    juce::ScopedLock sl(m_lock);

    if (m_transportState == TransportState::Playing)
        return;

    m_transportState = TransportState::Playing;

    if (m_midiClockOutputEnabled)
        sendMIDIStart();

    DBG("Transport: PLAY");

    if (onTransportChanged)
        onTransportChanged(m_transportState);
}

void HardwareSyncManager::stop()
{
    juce::ScopedLock sl(m_lock);

    if (m_transportState == TransportState::Stopped)
        return;

    m_transportState = TransportState::Stopped;
    m_songPosition.store(0.0);

    if (m_midiClockOutputEnabled)
        sendMIDIStop();

    DBG("Transport: STOP");

    if (onTransportChanged)
        onTransportChanged(m_transportState);
}

void HardwareSyncManager::pause()
{
    juce::ScopedLock sl(m_lock);

    m_transportState = TransportState::Paused;

    if (m_midiClockOutputEnabled)
        sendMIDIStop();

    DBG("Transport: PAUSE");

    if (onTransportChanged)
        onTransportChanged(m_transportState);
}

void HardwareSyncManager::record()
{
    juce::ScopedLock sl(m_lock);

    m_transportState = TransportState::Recording;

    if (m_midiClockOutputEnabled)
        sendMIDIStart();

    DBG("Transport: RECORD");

    if (onTransportChanged)
        onTransportChanged(m_transportState);
}

// ===========================
// Tempo & Position
// ===========================

void HardwareSyncManager::setTempo(double bpm)
{
    bpm = juce::jlimit(20.0, 999.0, bpm);

    if (std::abs(m_bpm.load() - bpm) < 0.001)
        return;

    m_bpm.store(bpm);

    DBG("Tempo set to: " << bpm << " BPM");

    if (onTempoChanged)
        onTempoChanged(bpm);
}

void HardwareSyncManager::setSongPosition(double beats)
{
    m_songPosition.store(beats);

    if (m_midiClockOutputEnabled)
        sendMIDISongPosition(static_cast<int>(beats));

    if (onPositionChanged)
        onPositionChanged(beats);
}

juce::String HardwareSyncManager::getSMPTETimecode() const
{
    double position = m_songPosition.load();
    double bpm = m_bpm.load();

    // Convert beats to seconds
    double seconds = (position / bpm) * 60.0;

    // Convert to SMPTE (HH:MM:SS:FF)
    int hours = static_cast<int>(seconds / 3600.0);
    seconds -= hours * 3600.0;

    int minutes = static_cast<int>(seconds / 60.0);
    seconds -= minutes * 60.0;

    int secs = static_cast<int>(seconds);
    int frames = static_cast<int>((seconds - secs) * m_mtcFrameRate);

    return juce::String::formatted("%02d:%02d:%02d:%02d", hours, minutes, secs, frames);
}

// ===========================
// MIDI Clock Output
// ===========================

void HardwareSyncManager::enableMIDIClockOutput(bool enable, const juce::String& midiOutputDevice)
{
    juce::ScopedLock sl(m_lock);

    if (enable && !m_midiClockOutputEnabled)
    {
        // Open MIDI output
        if (midiOutputDevice.isEmpty())
        {
            // Use default device
            auto devices = juce::MidiOutput::getAvailableDevices();
            if (!devices.isEmpty())
            {
                m_midiClockOutput = juce::MidiOutput::openDevice(devices[0].identifier);
            }
        }
        else
        {
            // Use specified device
            auto devices = juce::MidiOutput::getAvailableDevices();
            for (const auto& device : devices)
            {
                if (device.name == midiOutputDevice)
                {
                    m_midiClockOutput = juce::MidiOutput::openDevice(device.identifier);
                    break;
                }
            }
        }

        if (m_midiClockOutput)
        {
            m_midiClockOutputEnabled = true;
            m_midiClockTicks = 0;
            m_midiClockPhase = 0.0;

            DBG("MIDI Clock output ENABLED");
        }
    }
    else if (!enable && m_midiClockOutputEnabled)
    {
        m_midiClockOutput.reset();
        m_midiClockOutputEnabled = false;

        DBG("MIDI Clock output DISABLED");
    }
}

void HardwareSyncManager::sendMIDIStart()
{
    if (m_midiClockOutput)
    {
        m_midiClockOutput->sendMessageNow(juce::MidiMessage::midiStart());
        DBG("MIDI: START");
    }
}

void HardwareSyncManager::sendMIDIStop()
{
    if (m_midiClockOutput)
    {
        m_midiClockOutput->sendMessageNow(juce::MidiMessage::midiStop());
        DBG("MIDI: STOP");
    }
}

void HardwareSyncManager::sendMIDIContinue()
{
    if (m_midiClockOutput)
    {
        m_midiClockOutput->sendMessageNow(juce::MidiMessage::midiContinue());
        DBG("MIDI: CONTINUE");
    }
}

void HardwareSyncManager::sendMIDIClockTick()
{
    if (m_midiClockOutput)
    {
        m_midiClockOutput->sendMessageNow(juce::MidiMessage::midiClock());
    }
}

void HardwareSyncManager::sendMIDISongPosition(int beats)
{
    if (m_midiClockOutput)
    {
        // Song position pointer (in 16th notes)
        int sixteenths = beats * 4;
        m_midiClockOutput->sendMessageNow(juce::MidiMessage::songPositionPointer(sixteenths));
    }
}

// ===========================
// MTC Output
// ===========================

void HardwareSyncManager::enableMTCOutput(bool enable, const juce::String& midiOutputDevice)
{
    juce::ScopedLock sl(m_lock);

    if (enable && !m_mtcOutputEnabled)
    {
        // Open MIDI output (can be same or different from clock output)
        if (midiOutputDevice.isEmpty())
        {
            auto devices = juce::MidiOutput::getAvailableDevices();
            if (!devices.isEmpty())
            {
                m_mtcOutput = juce::MidiOutput::openDevice(devices[0].identifier);
            }
        }
        else
        {
            auto devices = juce::MidiOutput::getAvailableDevices();
            for (const auto& device : devices)
            {
                if (device.name == midiOutputDevice)
                {
                    m_mtcOutput = juce::MidiOutput::openDevice(device.identifier);
                    break;
                }
            }
        }

        if (m_mtcOutput)
        {
            m_mtcOutputEnabled = true;
            DBG("MTC output ENABLED (" << m_mtcFrameRate << " fps)");
        }
    }
    else if (!enable && m_mtcOutputEnabled)
    {
        m_mtcOutput.reset();
        m_mtcOutputEnabled = false;

        DBG("MTC output DISABLED");
    }
}

void HardwareSyncManager::setMTCFrameRate(int fps)
{
    m_mtcFrameRate = fps;
    DBG("MTC frame rate: " << fps << " fps");
}

// ===========================
// LTC Output
// ===========================

void HardwareSyncManager::enableLTCOutput(bool enable, int audioChannel)
{
    m_ltcOutputEnabled = enable;
    m_ltcChannel = audioChannel;

    if (enable)
    {
        DBG("LTC output ENABLED on audio channel " << audioChannel << " (" << m_ltcFrameRate << " fps)");
    }
    else
    {
        DBG("LTC output DISABLED");
    }
}

void HardwareSyncManager::setLTCFrameRate(int fps)
{
    m_ltcFrameRate = fps;
    DBG("LTC frame rate: " << fps << " fps");
}

// ===========================
// Audio Processing
// ===========================

void HardwareSyncManager::processAudio(juce::AudioBuffer<float>& buffer, int numSamples)
{
    juce::ScopedLock sl(m_lock);

    if (m_transportState != TransportState::Playing &&
        m_transportState != TransportState::Recording)
        return;

    // Update MIDI clock
    if (m_midiClockOutputEnabled)
        updateMIDIClock(numSamples);

    // Update MTC
    if (m_mtcOutputEnabled)
        updateMTC(numSamples);

    // Update LTC
    if (m_ltcOutputEnabled)
        updateLTC(buffer, numSamples);

    // Advance song position
    double bpm = m_bpm.load();
    double beatsPerSecond = bpm / 60.0;
    double beatsPerSample = beatsPerSecond / m_sampleRate;
    double beatAdvancement = beatsPerSample * numSamples;

    double currentPosition = m_songPosition.load();
    m_songPosition.store(currentPosition + beatAdvancement);

    // Drift compensation
    if (m_driftCompensation && m_syncSource != SyncSource::Internal)
        compensateDrift();
}

void HardwareSyncManager::updateMIDIClock(int numSamples)
{
    // MIDI Clock: 24 pulses per quarter note (PPQN)
    double bpm = m_bpm.load();
    double pulsesPerSecond = (bpm / 60.0) * 24.0;
    double pulsesPerSample = pulsesPerSecond / m_sampleRate;

    m_midiClockPhase += pulsesPerSample * numSamples;

    while (m_midiClockPhase >= 1.0)
    {
        sendMIDIClockTick();
        m_midiClockPhase -= 1.0;
        m_midiClockTicks++;
    }
}

void HardwareSyncManager::updateMTC(int numSamples)
{
    // MTC: 8 quarter-frame messages per frame
    // Send at frame rate (e.g., 30 fps = 240 quarter-frames/second)

    // Real implementation would generate MTC quarter-frame messages
    // This is simplified
}

void HardwareSyncManager::updateLTC(juce::AudioBuffer<float>& buffer, int numSamples)
{
    if (m_ltcChannel >= buffer.getNumChannels())
        return;

    float* channelData = buffer.getWritePointer(m_ltcChannel);

    // LTC: Manchester-encoded SMPTE timecode
    // Real implementation would generate LTC waveform
    // This is placeholder (silence)

    for (int i = 0; i < numSamples; ++i)
        channelData[i] = 0.0f;
}

void HardwareSyncManager::compensateDrift()
{
    // Measure drift between internal clock and external sync source
    // Adjust tempo slightly to maintain sync

    // Real implementation would compare timestamps and adjust
    // This is simplified
}

// ===========================
// Status
// ===========================

HardwareSyncManager::SyncStatus HardwareSyncManager::getStatus() const
{
    SyncStatus status;
    status.currentSource = m_syncSource;
    status.transport = m_transportState;
    status.bpm = m_bpm.load();
    status.songPosition = m_songPosition.load();
    status.synced = m_synced.load();
    status.drift = m_drift.load();

    return status;
}

} // namespace Eoel
