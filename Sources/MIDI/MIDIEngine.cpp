#include "MIDIEngine.h"
#include <cmath>
#include <algorithm>

namespace echoelmusic {
namespace midi {

// ============================================================================
// SINGLETON
// ============================================================================

MIDIEngine& MIDIEngine::getInstance()
{
    static MIDIEngine instance;
    return instance;
}

// ============================================================================
// CONSTRUCTOR / DESTRUCTOR
// ============================================================================

MIDIEngine::MIDIEngine()
{
    // MPE instrument setup (for controllers like ROLI Seaboard)
    m_mpeInstrument.setZoneLayout(juce::MPEZoneLayout::setLowerZone(15));
}

MIDIEngine::~MIDIEngine()
{
    if (m_midiInput != nullptr)
        m_midiInput->stop();
}

// ============================================================================
// INITIALIZATION
// ============================================================================

bool MIDIEngine::initialize()
{
    if (m_initialized)
        return true;

    DBG("MIDI Engine initializing...");

    // Log available MIDI devices
    auto inputs = juce::MidiInput::getAvailableDevices();
    DBG("Available MIDI Inputs (" + juce::String(inputs.size()) + "):");
    for (const auto& device : inputs)
    {
        DBG("  - " + device.name);
    }

    auto outputs = juce::MidiOutput::getAvailableDevices();
    DBG("Available MIDI Outputs (" + juce::String(outputs.size()) + "):");
    for (const auto& device : outputs)
    {
        DBG("  - " + device.name);
    }

    m_initialized = true;
    return true;
}

// ============================================================================
// MIDI PROCESSING
// ============================================================================

void MIDIEngine::processMIDI(juce::MidiBuffer& midiBuffer, int numSamples)
{
    // Process incoming MIDI messages
    for (const auto metadata : midiBuffer)
    {
        auto message = metadata.getMessage();
        handleMIDIMessage(message);
    }

    // If recording, add messages to recording buffer
    if (m_isRecording)
    {
        m_recordingBuffer.addEvents(midiBuffer, 0, numSamples, 0);
    }

    // TODO: Generate MIDI output from recorded notes (playback)
    // This would read notes from m_trackNotes and add to midiBuffer
}

void MIDIEngine::handleMIDIMessage(const juce::MidiMessage& message)
{
    // MIDI Learn
    if (m_midiLearnActive)
    {
        if (message.isController())
        {
            int ccNumber = message.getControllerNumber();
            int channel = message.getChannel();

            DBG("MIDI Learn: CC" + juce::String(ccNumber) + " on channel " + juce::String(channel));

            if (m_midiLearnCallback)
            {
                m_midiLearnCallback(ccNumber, channel);
            }

            stopMIDILearn();
            return;
        }
    }

    // MPE handling
    if (m_mpeEnabled)
    {
        m_mpeInstrument.processNextMidiEvent(message);
    }

    // Log MIDI message
    if (message.isNoteOn())
    {
        DBG("MIDI Note ON: " + juce::String(message.getNoteNumber()) +
            " velocity: " + juce::String(message.getVelocity()));
    }
    else if (message.isNoteOff())
    {
        DBG("MIDI Note OFF: " + juce::String(message.getNoteNumber()));
    }
}

// ============================================================================
// NOTE MANAGEMENT
// ============================================================================

void MIDIEngine::addNote(int trackIndex, const Note& note)
{
    m_trackNotes[trackIndex].push_back(note);
    DBG("Added MIDI note to track " + juce::String(trackIndex) +
        ": Note " + juce::String(note.noteNumber) +
        " at " + juce::String(note.startTime, 2) + "s");
}

void MIDIEngine::removeNote(int trackIndex, int noteIndex)
{
    auto it = m_trackNotes.find(trackIndex);
    if (it != m_trackNotes.end())
    {
        auto& notes = it->second;
        if (noteIndex >= 0 && noteIndex < notes.size())
        {
            notes.erase(notes.begin() + noteIndex);
            DBG("Removed note " + juce::String(noteIndex) + " from track " + juce::String(trackIndex));
        }
    }
}

std::vector<MIDIEngine::Note> MIDIEngine::getNotesInRange(
    int trackIndex,
    double startTime,
    double endTime) const
{
    std::vector<Note> result;

    auto it = m_trackNotes.find(trackIndex);
    if (it == m_trackNotes.end())
        return result;

    const auto& notes = it->second;

    for (const auto& note : notes)
    {
        double noteEnd = note.startTime + note.duration;

        // Check if note overlaps with time range
        if (note.startTime < endTime && noteEnd > startTime)
        {
            result.push_back(note);
        }
    }

    return result;
}

// ============================================================================
// DEVICE MANAGEMENT
// ============================================================================

bool MIDIEngine::enableMIDIInput(const juce::String& deviceName)
{
    auto devices = juce::MidiInput::getAvailableDevices();

    for (const auto& device : devices)
    {
        if (device.name == deviceName)
        {
            m_midiInput = juce::MidiInput::openDevice(device.identifier,
                [this](const juce::MidiMessage& message)
                {
                    handleMIDIMessage(message);
                });

            if (m_midiInput != nullptr)
            {
                m_midiInput->start();
                DBG("MIDI Input enabled: " + deviceName);
                return true;
            }
        }
    }

    DBG("Error: MIDI Input device not found: " + deviceName);
    return false;
}

void MIDIEngine::disableMIDIInput()
{
    if (m_midiInput != nullptr)
    {
        m_midiInput->stop();
        m_midiInput.reset();
        DBG("MIDI Input disabled");
    }
}

juce::StringArray MIDIEngine::getAvailableMIDIInputs() const
{
    juce::StringArray result;

    auto devices = juce::MidiInput::getAvailableDevices();
    for (const auto& device : devices)
    {
        result.add(device.name);
    }

    return result;
}

bool MIDIEngine::enableMIDIOutput(const juce::String& deviceName)
{
    auto devices = juce::MidiOutput::getAvailableDevices();

    for (const auto& device : devices)
    {
        if (device.name == deviceName)
        {
            m_midiOutput = juce::MidiOutput::openDevice(device.identifier);

            if (m_midiOutput != nullptr)
            {
                DBG("MIDI Output enabled: " + deviceName);
                return true;
            }
        }
    }

    DBG("Error: MIDI Output device not found: " + deviceName);
    return false;
}

void MIDIEngine::sendMIDIMessage(const juce::MidiMessage& message)
{
    if (m_midiOutput != nullptr)
    {
        m_midiOutput->sendMessageNow(message);
    }
}

// ============================================================================
// MPE SUPPORT
// ============================================================================

void MIDIEngine::setMPEMode(bool enabled, int zone)
{
    m_mpeEnabled = enabled;

    if (enabled)
    {
        if (zone == 0)
        {
            // Lower zone (channels 2-15, controlled by channel 1)
            m_mpeInstrument.setZoneLayout(juce::MPEZoneLayout::setLowerZone(15));
            DBG("MPE enabled: Lower zone (15 channels)");
        }
        else
        {
            // Upper zone (channels 2-15, controlled by channel 16)
            m_mpeInstrument.setZoneLayout(juce::MPEZoneLayout::setUpperZone(15));
            DBG("MPE enabled: Upper zone (15 channels)");
        }
    }
    else
    {
        DBG("MPE disabled");
    }
}

// ============================================================================
// MIDI LEARN
// ============================================================================

void MIDIEngine::startMIDILearn(std::function<void(int, int)> callback)
{
    m_midiLearnActive = true;
    m_midiLearnCallback = callback;
    DBG("MIDI Learn started - waiting for CC message...");
}

void MIDIEngine::stopMIDILearn()
{
    m_midiLearnActive = false;
    m_midiLearnCallback = nullptr;
    DBG("MIDI Learn stopped");
}

// ============================================================================
// RECORDING
// ============================================================================

void MIDIEngine::startRecording(int trackIndex)
{
    m_isRecording = true;
    m_recordingTrackIndex = trackIndex;
    m_recordingBuffer.clear();
    m_recordingStartTime = juce::Time::getMillisecondCounterHiRes() / 1000.0;

    DBG("MIDI Recording started on track " + juce::String(trackIndex));
}

void MIDIEngine::stopRecording()
{
    if (!m_isRecording)
        return;

    m_isRecording = false;

    // Convert recorded buffer to notes
    double currentTime = 0.0;
    std::map<int, double> noteOnTimes;  // noteNumber -> startTime

    for (const auto metadata : m_recordingBuffer)
    {
        auto message = metadata.getMessage();
        int samplePosition = metadata.samplePosition;

        // Calculate time (assuming 48kHz sample rate for now)
        currentTime = samplePosition / 48000.0;

        if (message.isNoteOn())
        {
            int noteNumber = message.getNoteNumber();
            noteOnTimes[noteNumber] = currentTime;
        }
        else if (message.isNoteOff())
        {
            int noteNumber = message.getNoteNumber();

            // Find corresponding note on
            auto it = noteOnTimes.find(noteNumber);
            if (it != noteOnTimes.end())
            {
                Note note;
                note.noteNumber = noteNumber;
                note.velocity = message.getVelocity();
                note.startTime = it->second;
                note.duration = currentTime - it->second;
                note.channel = message.getChannel();

                addNote(m_recordingTrackIndex, note);

                noteOnTimes.erase(it);
            }
        }
    }

    m_recordingBuffer.clear();
    DBG("MIDI Recording stopped");
}

// ============================================================================
// UTILITIES
// ============================================================================

void MIDIEngine::quantizeNotes(int trackIndex, double gridSize)
{
    auto it = m_trackNotes.find(trackIndex);
    if (it == m_trackNotes.end())
        return;

    auto& notes = it->second;

    for (auto& note : notes)
    {
        // Quantize start time to nearest grid position
        double gridPosition = std::round(note.startTime / gridSize) * gridSize;
        note.startTime = gridPosition;

        // Optionally quantize duration
        double durationGrids = std::round(note.duration / gridSize);
        if (durationGrids < 1.0)
            durationGrids = 1.0;
        note.duration = durationGrids * gridSize;
    }

    DBG("Quantized track " + juce::String(trackIndex) + " to grid: " + juce::String(gridSize, 3));
}

void MIDIEngine::transposeNotes(int trackIndex, int semitones)
{
    auto it = m_trackNotes.find(trackIndex);
    if (it == m_trackNotes.end())
        return;

    auto& notes = it->second;

    for (auto& note : notes)
    {
        int newNote = note.noteNumber + semitones;

        // Clamp to valid MIDI range (0-127)
        newNote = juce::jlimit(0, 127, newNote);

        note.noteNumber = newNote;
    }

    DBG("Transposed track " + juce::String(trackIndex) + " by " + juce::String(semitones) + " semitones");
}

// ============================================================================
// AUDIO TO MIDI (Inspired by BLAB voice-to-MIDI)
// ============================================================================

void MIDIEngine::audioToMIDI(const float* audioBuffer, int numSamples)
{
    // TODO: Implement YIN pitch detection algorithm (from BLAB)
    // This would detect pitch from audio and convert to MIDI notes
    // For MVP, this is a nice-to-have feature
}

float MIDIEngine::detectPitch(const float* buffer, int numSamples) const
{
    // TODO: Implement YIN algorithm for pitch detection
    // Reference: BLAB's YIN implementation in MicrophoneManager.swift
    // For now, return placeholder
    return 440.0f;  // A4
}

} // namespace midi
} // namespace echoelmusic
