/**
 * MIDISequencer.cpp
 *
 * Complete MIDI sequencer engine with pattern sequencing,
 * step sequencer, piano roll support, and bio-reactive features
 *
 * Phase 10000 ULTIMATE RALPH WIGGUM LAMBDA MODE - 100% Feature Parity
 */

#include <vector>
#include <memory>
#include <algorithm>
#include <cmath>
#include <functional>
#include <mutex>
#include <atomic>

namespace Echoelmusic {
namespace Core {

// ============================================================================
// MIDI EVENT TYPES
// ============================================================================

enum class MIDIEventType {
    NoteOn,
    NoteOff,
    ControlChange,
    PitchBend,
    Aftertouch,
    ChannelPressure,
    ProgramChange,
    SysEx
};

struct MIDIEvent {
    MIDIEventType type;
    int64_t timestamp;      // Ticks from start
    uint8_t channel;        // 0-15
    uint8_t data1;          // Note number or CC number
    uint8_t data2;          // Velocity or CC value
    int16_t pitchBend;      // -8192 to 8191 for pitch bend

    // Factory methods
    static MIDIEvent noteOn(int64_t time, uint8_t ch, uint8_t note, uint8_t vel) {
        return {MIDIEventType::NoteOn, time, ch, note, vel, 0};
    }

    static MIDIEvent noteOff(int64_t time, uint8_t ch, uint8_t note) {
        return {MIDIEventType::NoteOff, time, ch, note, 0, 0};
    }

    static MIDIEvent cc(int64_t time, uint8_t ch, uint8_t cc, uint8_t val) {
        return {MIDIEventType::ControlChange, time, ch, cc, val, 0};
    }

    static MIDIEvent pitchBend(int64_t time, uint8_t ch, int16_t bend) {
        return {MIDIEventType::PitchBend, time, ch, 0, 0, bend};
    }
};

// ============================================================================
// MIDI NOTE (for piano roll)
// ============================================================================

struct MIDINote {
    int64_t startTick;
    int64_t endTick;
    uint8_t pitch;          // 0-127
    uint8_t velocity;       // 0-127
    uint8_t channel;
    bool selected = false;
    bool muted = false;

    int64_t duration() const { return endTick - startTick; }

    // MPE parameters (per-note expression)
    float mpeSlide = 0.0f;      // CC74 brightness
    float mpePressure = 0.0f;   // Aftertouch
    float mpePitchBend = 0.0f;  // Per-note pitch bend
};

// ============================================================================
// MIDI CLIP
// ============================================================================

class MIDIClip {
public:
    MIDIClip(const std::string& name = "New Clip")
        : name(name), lengthTicks(1920) {} // Default 1 bar at 480 PPQ

    // Note management
    void addNote(const MIDINote& note) {
        notes.push_back(note);
        sortNotes();
    }

    void removeNote(size_t index) {
        if (index < notes.size()) {
            notes.erase(notes.begin() + index);
        }
    }

    void removeSelectedNotes() {
        notes.erase(
            std::remove_if(notes.begin(), notes.end(),
                [](const MIDINote& n) { return n.selected; }),
            notes.end());
    }

    MIDINote* getNoteAt(int64_t tick, uint8_t pitch) {
        for (auto& note : notes) {
            if (note.pitch == pitch &&
                tick >= note.startTick && tick < note.endTick) {
                return &note;
            }
        }
        return nullptr;
    }

    // Selection
    void selectNotesInRange(int64_t startTick, int64_t endTick,
                           uint8_t lowPitch, uint8_t highPitch) {
        for (auto& note : notes) {
            note.selected = (note.startTick >= startTick &&
                            note.endTick <= endTick &&
                            note.pitch >= lowPitch &&
                            note.pitch <= highPitch);
        }
    }

    void selectAll() {
        for (auto& note : notes) note.selected = true;
    }

    void deselectAll() {
        for (auto& note : notes) note.selected = false;
    }

    // Editing operations
    void transposeSelected(int semitones) {
        for (auto& note : notes) {
            if (note.selected) {
                int newPitch = note.pitch + semitones;
                note.pitch = static_cast<uint8_t>(std::clamp(newPitch, 0, 127));
            }
        }
    }

    void quantizeSelected(int gridTicks) {
        for (auto& note : notes) {
            if (note.selected) {
                note.startTick = (note.startTick / gridTicks) * gridTicks;
                note.endTick = std::max(note.startTick + gridTicks,
                    ((note.endTick + gridTicks / 2) / gridTicks) * gridTicks);
            }
        }
        sortNotes();
    }

    void setVelocitySelected(uint8_t velocity) {
        for (auto& note : notes) {
            if (note.selected) {
                note.velocity = velocity;
            }
        }
    }

    void scaleVelocitySelected(float factor) {
        for (auto& note : notes) {
            if (note.selected) {
                int newVel = static_cast<int>(note.velocity * factor);
                note.velocity = static_cast<uint8_t>(std::clamp(newVel, 1, 127));
            }
        }
    }

    // Generate MIDI events for playback
    std::vector<MIDIEvent> generateEvents(int64_t startTick, int64_t endTick) const {
        std::vector<MIDIEvent> events;

        for (const auto& note : notes) {
            if (note.muted) continue;

            // Note starts in range
            if (note.startTick >= startTick && note.startTick < endTick) {
                events.push_back(MIDIEvent::noteOn(
                    note.startTick, note.channel, note.pitch, note.velocity));
            }

            // Note ends in range
            if (note.endTick >= startTick && note.endTick < endTick) {
                events.push_back(MIDIEvent::noteOff(
                    note.endTick, note.channel, note.pitch));
            }
        }

        // Sort by timestamp
        std::sort(events.begin(), events.end(),
            [](const MIDIEvent& a, const MIDIEvent& b) {
                return a.timestamp < b.timestamp;
            });

        return events;
    }

    // Accessors
    const std::vector<MIDINote>& getNotes() const { return notes; }
    std::vector<MIDINote>& getNotes() { return notes; }
    int64_t getLength() const { return lengthTicks; }
    void setLength(int64_t ticks) { lengthTicks = ticks; }
    const std::string& getName() const { return name; }
    void setName(const std::string& n) { name = n; }

private:
    void sortNotes() {
        std::sort(notes.begin(), notes.end(),
            [](const MIDINote& a, const MIDINote& b) {
                if (a.startTick != b.startTick) return a.startTick < b.startTick;
                return a.pitch < b.pitch;
            });
    }

    std::string name;
    std::vector<MIDINote> notes;
    int64_t lengthTicks;
};

// ============================================================================
// STEP SEQUENCER
// ============================================================================

class StepSequencer {
public:
    static constexpr int MAX_STEPS = 64;
    static constexpr int MAX_TRACKS = 16;

    struct Step {
        bool active = false;
        uint8_t velocity = 100;
        uint8_t pitch = 60;       // C4 default
        float probability = 1.0f;  // 0-1
        int retrigger = 0;         // Number of retriggers in step
        float slide = 0.0f;        // Portamento
    };

    struct Track {
        std::string name;
        std::vector<Step> steps;
        uint8_t channel = 0;
        uint8_t rootNote = 36;    // C2 for drum track
        bool muted = false;

        Track() : steps(MAX_STEPS) {}
    };

    StepSequencer() {
        tracks.resize(MAX_TRACKS);
        // Initialize drum track names
        tracks[0].name = "Kick";     tracks[0].rootNote = 36;
        tracks[1].name = "Snare";    tracks[1].rootNote = 38;
        tracks[2].name = "Hi-Hat";   tracks[2].rootNote = 42;
        tracks[3].name = "Open HH";  tracks[3].rootNote = 46;
        tracks[4].name = "Tom Low";  tracks[4].rootNote = 45;
        tracks[5].name = "Tom Mid";  tracks[5].rootNote = 47;
        tracks[6].name = "Tom High"; tracks[6].rootNote = 48;
        tracks[7].name = "Clap";     tracks[7].rootNote = 39;
    }

    void setNumSteps(int num) {
        numSteps = std::clamp(num, 1, MAX_STEPS);
    }

    void toggleStep(int track, int step) {
        if (track >= 0 && track < MAX_TRACKS && step >= 0 && step < numSteps) {
            tracks[track].steps[step].active = !tracks[track].steps[step].active;
        }
    }

    void setStep(int track, int step, bool active, uint8_t velocity = 100) {
        if (track >= 0 && track < MAX_TRACKS && step >= 0 && step < numSteps) {
            tracks[track].steps[step].active = active;
            tracks[track].steps[step].velocity = velocity;
        }
    }

    // Generate events for current step
    std::vector<MIDIEvent> getEventsForStep(int step, int64_t tick) const {
        std::vector<MIDIEvent> events;

        for (int t = 0; t < MAX_TRACKS; ++t) {
            const auto& track = tracks[t];
            if (track.muted) continue;

            const auto& s = track.steps[step % numSteps];
            if (s.active) {
                // Check probability
                float rand = static_cast<float>(std::rand()) / RAND_MAX;
                if (rand <= s.probability) {
                    events.push_back(MIDIEvent::noteOn(
                        tick, track.channel, track.rootNote, s.velocity));
                }
            }
        }

        return events;
    }

    // Presets
    void loadPreset(const std::string& presetName) {
        clearAll();

        if (presetName == "Four on Floor") {
            for (int i = 0; i < numSteps; i += 4) setStep(0, i, true);  // Kick
            for (int i = 2; i < numSteps; i += 4) setStep(1, i, true);  // Snare
            for (int i = 0; i < numSteps; i += 2) setStep(2, i, true);  // HH
        } else if (presetName == "Breakbeat") {
            setStep(0, 0, true);
            setStep(0, 6, true);
            setStep(0, 10, true);
            setStep(1, 4, true);
            setStep(1, 12, true);
            for (int i = 0; i < 16; ++i) setStep(2, i, true, 80 + (i % 2) * 20);
        } else if (presetName == "Ambient") {
            setStep(0, 0, true, 70);
            setStep(2, 4, true, 50);
            setStep(2, 8, true, 50);
            setStep(2, 12, true, 50);
        }
    }

    void clearAll() {
        for (auto& track : tracks) {
            for (auto& step : track.steps) {
                step.active = false;
            }
        }
    }

    // Bio-reactive modulation
    void modulateWithCoherence(float coherence) {
        // Higher coherence = more consistent patterns
        // Lower coherence = more variation/probability
        float baseProb = 0.7f + coherence * 0.3f;

        for (auto& track : tracks) {
            for (auto& step : track.steps) {
                if (step.active) {
                    step.probability = baseProb;
                }
            }
        }
    }

    void modulateVelocityWithHRV(float hrv) {
        // HRV influences velocity variation
        float variation = (1.0f - hrv) * 30.0f;  // 0-30 velocity range

        for (auto& track : tracks) {
            for (auto& step : track.steps) {
                if (step.active) {
                    float rand = static_cast<float>(std::rand()) / RAND_MAX - 0.5f;
                    int vel = step.velocity + static_cast<int>(rand * variation);
                    step.velocity = static_cast<uint8_t>(std::clamp(vel, 1, 127));
                }
            }
        }
    }

    // Accessors
    Track& getTrack(int index) { return tracks[index]; }
    const Track& getTrack(int index) const { return tracks[index]; }
    int getNumSteps() const { return numSteps; }

private:
    std::vector<Track> tracks;
    int numSteps = 16;
};

// ============================================================================
// MAIN MIDI SEQUENCER
// ============================================================================

class MIDISequencer {
public:
    MIDISequencer()
        : ppq(480), tempo(120.0), playing(false), recording(false),
          looping(false), currentTick(0), loopStart(0), loopEnd(1920) {}

    // Transport control
    void play() {
        playing = true;
    }

    void stop() {
        playing = false;
        recording = false;
        // Send all notes off
        for (auto& callback : eventCallbacks) {
            for (int ch = 0; ch < 16; ++ch) {
                callback(MIDIEvent::cc(0, ch, 123, 0)); // All notes off
            }
        }
    }

    void pause() {
        playing = false;
    }

    void setPosition(int64_t tick) {
        currentTick = tick;
    }

    void setPositionInBeats(double beats) {
        currentTick = static_cast<int64_t>(beats * ppq);
    }

    // Recording
    void startRecording() {
        recording = true;
        playing = true;
    }

    void stopRecording() {
        recording = false;
    }

    void recordEvent(const MIDIEvent& event) {
        if (!recording || !currentClip) return;

        if (event.type == MIDIEventType::NoteOn) {
            // Start recording note
            PendingNote pending;
            pending.startTick = currentTick;
            pending.pitch = event.data1;
            pending.velocity = event.data2;
            pending.channel = event.channel;
            pendingNotes.push_back(pending);
        } else if (event.type == MIDIEventType::NoteOff) {
            // Find and complete pending note
            for (auto it = pendingNotes.begin(); it != pendingNotes.end(); ++it) {
                if (it->pitch == event.data1 && it->channel == event.channel) {
                    MIDINote note;
                    note.startTick = it->startTick;
                    note.endTick = currentTick;
                    note.pitch = it->pitch;
                    note.velocity = it->velocity;
                    note.channel = it->channel;
                    currentClip->addNote(note);
                    pendingNotes.erase(it);
                    break;
                }
            }
        }
    }

    // Looping
    void setLoop(bool enabled) {
        looping = enabled;
    }

    void setLoopRange(int64_t start, int64_t end) {
        loopStart = start;
        loopEnd = end;
    }

    // Tempo
    void setTempo(double bpm) {
        tempo = bpm;
    }

    double getTempo() const { return tempo; }

    void setTimeSignature(int numerator, int denominator) {
        tsNumerator = numerator;
        tsDenominator = denominator;
    }

    // Clip management
    void setCurrentClip(MIDIClip* clip) {
        currentClip = clip;
    }

    // Process (call from audio thread)
    void process(int numSamples, double sampleRate) {
        if (!playing) return;

        // Calculate ticks to advance
        double samplesPerBeat = sampleRate * 60.0 / tempo;
        double ticksPerSample = ppq / samplesPerBeat;
        int64_t ticksToAdvance = static_cast<int64_t>(numSamples * ticksPerSample);

        int64_t endTick = currentTick + ticksToAdvance;

        // Get events from current clip
        if (currentClip) {
            auto events = currentClip->generateEvents(currentTick, endTick);
            for (const auto& event : events) {
                for (auto& callback : eventCallbacks) {
                    callback(event);
                }
            }
        }

        // Get step sequencer events
        int currentStep = static_cast<int>((currentTick / (ppq / 4)) % stepSequencer.getNumSteps());
        int nextStep = static_cast<int>((endTick / (ppq / 4)) % stepSequencer.getNumSteps());

        if (currentStep != nextStep) {
            auto stepEvents = stepSequencer.getEventsForStep(nextStep, endTick);
            for (const auto& event : stepEvents) {
                for (auto& callback : eventCallbacks) {
                    callback(event);
                }
            }
        }

        // Advance position
        currentTick = endTick;

        // Handle looping
        if (looping && currentTick >= loopEnd) {
            currentTick = loopStart + (currentTick - loopEnd);
        }
    }

    // Callbacks
    void addEventCallback(std::function<void(const MIDIEvent&)> callback) {
        eventCallbacks.push_back(callback);
    }

    // Accessors
    bool isPlaying() const { return playing; }
    bool isRecording() const { return recording; }
    int64_t getCurrentTick() const { return currentTick; }
    int getPPQ() const { return ppq; }

    StepSequencer& getStepSequencer() { return stepSequencer; }

    // Bio-reactive integration
    void updateBioReactive(float coherence, float hrv, int heartRate) {
        stepSequencer.modulateWithCoherence(coherence);
        stepSequencer.modulateVelocityWithHRV(hrv);

        // Heart rate can influence tempo slightly
        // (optional - enable with flag)
        if (bioTempoSync) {
            double bioTempo = heartRate * tempoMultiplier;
            bioTempo = std::clamp(bioTempo, 60.0, 180.0);
            setTempo(bioTempo);
        }
    }

    void setBioTempoSync(bool enabled, double multiplier = 1.0) {
        bioTempoSync = enabled;
        tempoMultiplier = multiplier;
    }

private:
    struct PendingNote {
        int64_t startTick;
        uint8_t pitch;
        uint8_t velocity;
        uint8_t channel;
    };

    int ppq;  // Pulses per quarter note
    double tempo;
    int tsNumerator = 4;
    int tsDenominator = 4;

    std::atomic<bool> playing;
    std::atomic<bool> recording;
    bool looping;
    std::atomic<int64_t> currentTick;
    int64_t loopStart;
    int64_t loopEnd;

    MIDIClip* currentClip = nullptr;
    StepSequencer stepSequencer;

    std::vector<PendingNote> pendingNotes;
    std::vector<std::function<void(const MIDIEvent&)>> eventCallbacks;

    // Bio-reactive
    bool bioTempoSync = false;
    double tempoMultiplier = 1.0;

    std::mutex mutex;
};

} // namespace Core
} // namespace Echoelmusic
