#pragma once

#include <JuceHeader.h>
#include <vector>
#include <memory>

namespace echoelmusic {
namespace midi {

/**
 * @brief MIDI Engine - Core MIDI processing and routing
 *
 * MVP MIDI COMPONENT - Handles all MIDI operations
 *
 * Features:
 * - MIDI input/output routing
 * - MIDI recording to tracks
 * - MIDI playback from tracks
 * - MIDI clock sync
 * - MPE support (MIDI Polyphonic Expression)
 * - MIDI learn for parameter mapping
 *
 * Inspired by BLAB architecture (voice-to-MIDI, real-time processing)
 *
 * @author Claude Code (ULTRATHINK SUPER LASER MODE)
 * @date 2025-11-18
 */
class MIDIEngine
{
public:
    /**
     * @brief MIDI note structure
     */
    struct Note
    {
        int noteNumber = 60;      // 0-127 (Middle C = 60)
        int velocity = 100;        // 0-127
        double startTime = 0.0;    // Seconds
        double duration = 0.5;     // Seconds
        int channel = 1;           // 1-16

        // MPE support
        float pitchBend = 0.0f;    // -1.0 to +1.0
        float pressure = 0.0f;     // 0.0 to 1.0
        float timbre = 0.0f;       // 0.0 to 1.0 (CC74)
    };

    /**
     * @brief Get singleton instance
     */
    static MIDIEngine& getInstance();

    /**
     * @brief Initialize MIDI engine
     */
    bool initialize();

    /**
     * @brief Process MIDI buffer (called from audio thread)
     *
     * @param midiBuffer MIDI messages to process
     * @param numSamples Number of audio samples in this buffer
     */
    void processMIDI(juce::MidiBuffer& midiBuffer, int numSamples);

    /**
     * @brief Add MIDI note to track
     *
     * @param trackIndex Track to add note to
     * @param note Note data
     */
    void addNote(int trackIndex, const Note& note);

    /**
     * @brief Remove MIDI note from track
     *
     * @param trackIndex Track index
     * @param noteIndex Note index
     */
    void removeNote(int trackIndex, int noteIndex);

    /**
     * @brief Get notes for track in time range
     *
     * @param trackIndex Track index
     * @param startTime Start time (seconds)
     * @param endTime End time (seconds)
     * @return Vector of notes in range
     */
    std::vector<Note> getNotesInRange(int trackIndex, double startTime, double endTime) const;

    /**
     * @brief Enable MIDI input device
     *
     * @param deviceName MIDI input device name
     * @return true if enabled successfully
     */
    bool enableMIDIInput(const juce::String& deviceName);

    /**
     * @brief Disable MIDI input
     */
    void disableMIDIInput();

    /**
     * @brief Get available MIDI input devices
     *
     * @return Array of device names
     */
    juce::StringArray getAvailableMIDIInputs() const;

    /**
     * @brief Enable MIDI output device
     *
     * @param deviceName MIDI output device name
     * @return true if enabled successfully
     */
    bool enableMIDIOutput(const juce::String& deviceName);

    /**
     * @brief Send MIDI message to output
     *
     * @param message MIDI message
     */
    void sendMIDIMessage(const juce::MidiMessage& message);

    /**
     * @brief Enable MPE mode (MIDI Polyphonic Expression)
     *
     * @param enabled true to enable MPE
     * @param zone MPE zone (0 = lower, 1 = upper)
     */
    void setMPEMode(bool enabled, int zone = 0);

    /**
     * @brief MIDI Learn - Capture next MIDI CC for parameter mapping
     *
     * @param callback Called when MIDI CC is received
     */
    void startMIDILearn(std::function<void(int ccNumber, int channel)> callback);

    /**
     * @brief Stop MIDI Learn
     */
    void stopMIDILearn();

    /**
     * @brief Check if recording MIDI
     */
    bool isRecording() const { return m_isRecording; }

    /**
     * @brief Start MIDI recording
     */
    void startRecording(int trackIndex);

    /**
     * @brief Stop MIDI recording
     */
    void stopRecording();

    /**
     * @brief Quantize notes to grid
     *
     * @param trackIndex Track to quantize
     * @param gridSize Grid size in beats (e.g., 0.25 = 16th notes)
     */
    void quantizeNotes(int trackIndex, double gridSize);

    /**
     * @brief Transpose notes
     *
     * @param trackIndex Track to transpose
     * @param semitones Semitones to transpose (-12 to +12)
     */
    void transposeNotes(int trackIndex, int semitones);

private:
    MIDIEngine();
    ~MIDIEngine();

    // Prevent copying
    MIDIEngine(const MIDIEngine&) = delete;
    MIDIEngine& operator=(const MIDIEngine&) = delete;

    /**
     * @brief Handle incoming MIDI message
     */
    void handleMIDIMessage(const juce::MidiMessage& message);

    /**
     * @brief Convert audio input to MIDI (inspired by BLAB voice-to-MIDI)
     */
    void audioToMIDI(const float* audioBuffer, int numSamples);

    /**
     * @brief Detect pitch from audio (YIN algorithm from BLAB)
     */
    float detectPitch(const float* buffer, int numSamples) const;

private:
    bool m_initialized = false;
    bool m_isRecording = false;
    int m_recordingTrackIndex = -1;

    // MIDI devices
    std::unique_ptr<juce::MidiInput> m_midiInput;
    std::unique_ptr<juce::MidiOutput> m_midiOutput;

    // MPE support
    bool m_mpeEnabled = false;
    juce::MPEInstrument m_mpeInstrument;

    // MIDI Learn
    bool m_midiLearnActive = false;
    std::function<void(int, int)> m_midiLearnCallback;

    // Track notes (one vector per track)
    std::map<int, std::vector<Note>> m_trackNotes;

    // Real-time MIDI buffer for recording
    juce::MidiBuffer m_recordingBuffer;
    double m_recordingStartTime = 0.0;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MIDIEngine)
};

} // namespace midi
} // namespace echoelmusic
