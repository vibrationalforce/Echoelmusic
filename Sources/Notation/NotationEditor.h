/*
  ==============================================================================

    NotationEditor.h
    Created: 2026
    Author:  Echoelmusic

    Professional Score/Notation Editor
    Full music notation with playback, editing, and export

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include <vector>
#include <memory>
#include <map>
#include <set>
#include <optional>

namespace Echoelmusic {
namespace Notation {

//==============================================================================
/** Note duration values */
enum class NoteDuration {
    Whole = 1,
    Half = 2,
    Quarter = 4,
    Eighth = 8,
    Sixteenth = 16,
    ThirtySecond = 32,
    SixtyFourth = 64
};

/** Get duration in beats */
inline double getDurationInBeats(NoteDuration duration, int dots = 0) {
    double beats = 4.0 / static_cast<int>(duration);
    double dotMultiplier = 1.0;
    for (int i = 0; i < dots; ++i) {
        dotMultiplier += std::pow(0.5, i + 1);
    }
    return beats * dotMultiplier;
}

//==============================================================================
/** Accidental type */
enum class Accidental {
    None,
    Sharp,
    Flat,
    Natural,
    DoubleSharp,
    DoubleFlat
};

/** Articulation marks */
enum class Articulation {
    None,
    Staccato,
    Staccatissimo,
    Tenuto,
    Accent,
    Marcato,
    Fermata,
    Trill,
    Mordent,
    Turn,
    Tremolo
};

/** Dynamic marking */
enum class Dynamic {
    PPP, PP, P, MP, MF, F, FF, FFF,
    FP, SFZ, SFP, RF, RFZ
};

inline juce::String dynamicToString(Dynamic dyn) {
    switch (dyn) {
        case Dynamic::PPP: return "ppp";
        case Dynamic::PP:  return "pp";
        case Dynamic::P:   return "p";
        case Dynamic::MP:  return "mp";
        case Dynamic::MF:  return "mf";
        case Dynamic::F:   return "f";
        case Dynamic::FF:  return "ff";
        case Dynamic::FFF: return "fff";
        case Dynamic::FP:  return "fp";
        case Dynamic::SFZ: return "sfz";
        default:           return "";
    }
}

//==============================================================================
/** Clef type */
enum class ClefType {
    Treble,
    Bass,
    Alto,
    Tenor,
    Percussion,
    Tab
};

/** Key signature */
struct KeySignature {
    int sharpsOrFlats = 0;  // Negative = flats, positive = sharps
    bool isMinor = false;

    juce::String getName() const {
        static const char* majorKeys[] = {"C", "G", "D", "A", "E", "B", "F#", "C#"};
        static const char* minorKeys[] = {"A", "E", "B", "F#", "C#", "G#", "D#", "A#"};
        static const char* flatMajor[] = {"C", "F", "Bb", "Eb", "Ab", "Db", "Gb", "Cb"};
        static const char* flatMinor[] = {"A", "D", "G", "C", "F", "Bb", "Eb", "Ab"};

        int index = std::abs(sharpsOrFlats);
        if (index > 7) index = 7;

        if (sharpsOrFlats >= 0) {
            return juce::String(isMinor ? minorKeys[index] : majorKeys[index]) +
                   (isMinor ? " minor" : " major");
        } else {
            return juce::String(isMinor ? flatMinor[index] : flatMajor[index]) +
                   (isMinor ? " minor" : " major");
        }
    }
};

/** Time signature */
struct TimeSignature {
    int numerator = 4;
    int denominator = 4;

    double getBeatsPerMeasure() const {
        return static_cast<double>(numerator) * 4.0 / denominator;
    }
};

//==============================================================================
/** Pitch representation */
struct Pitch {
    int midiNote = 60;          // MIDI note number (C4 = 60)
    Accidental accidental = Accidental::None;

    int getOctave() const { return (midiNote / 12) - 1; }
    int getPitchClass() const { return midiNote % 12; }

    juce::String getName() const {
        static const char* noteNames[] = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"};
        return juce::String(noteNames[getPitchClass()]) + juce::String(getOctave());
    }

    /** Get staff position (0 = middle C) */
    int getStaffPosition(ClefType clef) const {
        int octave = getOctave();
        int pc = getPitchClass();

        // Convert to staff position (C=0, D=1, E=2, F=3, G=4, A=5, B=6)
        static const int pcToStep[] = {0, 0, 1, 1, 2, 3, 3, 4, 4, 5, 5, 6};
        int step = pcToStep[pc];
        int position = step + octave * 7;

        // Adjust for clef
        switch (clef) {
            case ClefType::Treble: return position - 35; // B4 on line 3
            case ClefType::Bass:   return position - 23; // D3 on line 3
            case ClefType::Alto:   return position - 29; // C4 on line 3
            case ClefType::Tenor:  return position - 31; // A3 on line 3
            default:               return position - 35;
        }
    }
};

//==============================================================================
/** Single note in the score */
class Note {
public:
    Note(int midiNote = 60, NoteDuration duration = NoteDuration::Quarter)
        : duration_(duration)
    {
        pitch_.midiNote = midiNote;
        id_ = juce::Uuid().toString();
    }

    juce::String getId() const { return id_; }

    // Pitch
    Pitch& getPitch() { return pitch_; }
    const Pitch& getPitch() const { return pitch_; }

    // Duration
    NoteDuration getDuration() const { return duration_; }
    void setDuration(NoteDuration dur) { duration_ = dur; }

    int getDots() const { return dots_; }
    void setDots(int dots) { dots_ = juce::jlimit(0, 3, dots); }

    double getDurationInBeats() const {
        return Notation::getDurationInBeats(duration_, dots_);
    }

    // Properties
    bool isTied() const { return tied_; }
    void setTied(bool tied) { tied_ = tied; }

    Articulation getArticulation() const { return articulation_; }
    void setArticulation(Articulation art) { articulation_ = art; }

    // Beam/stem
    bool isStemUp() const { return stemUp_; }
    void setStemUp(bool up) { stemUp_ = up; }

    int getBeamGroup() const { return beamGroup_; }
    void setBeamGroup(int group) { beamGroup_ = group; }

    // Voice (for multiple voices on same staff)
    int getVoice() const { return voice_; }
    void setVoice(int voice) { voice_ = voice; }

    // Selection
    bool isSelected() const { return selected_; }
    void setSelected(bool sel) { selected_ = sel; }

    // Tuplet
    bool isInTuplet() const { return tupletRatio_ > 0; }
    void setTupletRatio(int ratio) { tupletRatio_ = ratio; }
    int getTupletRatio() const { return tupletRatio_; }

private:
    juce::String id_;
    Pitch pitch_;
    NoteDuration duration_;
    int dots_ = 0;
    bool tied_ = false;
    Articulation articulation_ = Articulation::None;
    bool stemUp_ = true;
    int beamGroup_ = -1;
    int voice_ = 0;
    bool selected_ = false;
    int tupletRatio_ = 0;  // 3 for triplet, 5 for quintuplet, etc.
};

//==============================================================================
/** Rest in the score */
class Rest {
public:
    Rest(NoteDuration duration = NoteDuration::Quarter)
        : duration_(duration)
    {
        id_ = juce::Uuid().toString();
    }

    juce::String getId() const { return id_; }

    NoteDuration getDuration() const { return duration_; }
    void setDuration(NoteDuration dur) { duration_ = dur; }

    int getDots() const { return dots_; }
    void setDots(int dots) { dots_ = juce::jlimit(0, 3, dots); }

    double getDurationInBeats() const {
        return Notation::getDurationInBeats(duration_, dots_);
    }

    int getVoice() const { return voice_; }
    void setVoice(int voice) { voice_ = voice; }

private:
    juce::String id_;
    NoteDuration duration_;
    int dots_ = 0;
    int voice_ = 0;
};

//==============================================================================
/** Chord (multiple notes at same time) */
class Chord {
public:
    Chord() {
        id_ = juce::Uuid().toString();
    }

    juce::String getId() const { return id_; }

    void addNote(std::unique_ptr<Note> note) {
        notes_.push_back(std::move(note));
        sortNotes();
    }

    void removeNote(int index) {
        if (index >= 0 && index < static_cast<int>(notes_.size())) {
            notes_.erase(notes_.begin() + index);
        }
    }

    Note* getNote(int index) {
        return index >= 0 && index < static_cast<int>(notes_.size()) ?
               notes_[index].get() : nullptr;
    }

    int getNumNotes() const { return static_cast<int>(notes_.size()); }

    std::vector<Note*> getNotes() {
        std::vector<Note*> result;
        for (auto& n : notes_) result.push_back(n.get());
        return result;
    }

    double getDurationInBeats() const {
        if (notes_.empty()) return 0.0;
        return notes_[0]->getDurationInBeats();
    }

    NoteDuration getDuration() const {
        if (notes_.empty()) return NoteDuration::Quarter;
        return notes_[0]->getDuration();
    }

private:
    void sortNotes() {
        std::sort(notes_.begin(), notes_.end(),
                  [](const auto& a, const auto& b) {
                      return a->getPitch().midiNote < b->getPitch().midiNote;
                  });
    }

    juce::String id_;
    std::vector<std::unique_ptr<Note>> notes_;
};

//==============================================================================
/** Measure/bar in the score */
class Measure {
public:
    Measure(int measureNumber = 1)
        : measureNumber_(measureNumber)
    {
    }

    int getMeasureNumber() const { return measureNumber_; }

    //==============================================================================
    // Time signature
    void setTimeSignature(int num, int denom) {
        timeSig_.numerator = num;
        timeSig_.denominator = denom;
    }

    const TimeSignature& getTimeSignature() const { return timeSig_; }

    // Key signature
    void setKeySignature(int sharpsOrFlats, bool isMinor = false) {
        keySig_.sharpsOrFlats = sharpsOrFlats;
        keySig_.isMinor = isMinor;
    }

    const KeySignature& getKeySignature() const { return keySig_; }

    // Clef
    void setClef(ClefType clef) { clef_ = clef; }
    ClefType getClef() const { return clef_; }

    //==============================================================================
    // Content management
    void addChord(std::unique_ptr<Chord> chord, double beatPosition) {
        chords_.push_back({beatPosition, std::move(chord)});
        sortContent();
    }

    void addRest(std::unique_ptr<Rest> rest, double beatPosition) {
        rests_.push_back({beatPosition, std::move(rest)});
    }

    std::vector<std::pair<double, Chord*>> getChords() {
        std::vector<std::pair<double, Chord*>> result;
        for (auto& c : chords_) {
            result.push_back({c.first, c.second.get()});
        }
        return result;
    }

    //==============================================================================
    // Dynamics and expressions
    void addDynamic(Dynamic dyn, double beatPosition) {
        dynamics_[beatPosition] = dyn;
    }

    std::optional<Dynamic> getDynamicAt(double beat) const {
        auto it = dynamics_.find(beat);
        if (it != dynamics_.end()) return it->second;
        return std::nullopt;
    }

    //==============================================================================
    // Tempo
    void setTempo(double bpm) { tempo_ = bpm; }
    double getTempo() const { return tempo_; }

    //==============================================================================
    // Bar lines
    enum class BarlineType { Normal, Double, Final, Repeat };
    void setEndBarline(BarlineType type) { endBarline_ = type; }
    BarlineType getEndBarline() const { return endBarline_; }

    //==============================================================================
    // Repeat signs
    bool hasRepeatStart() const { return repeatStart_; }
    void setRepeatStart(bool rep) { repeatStart_ = rep; }

    bool hasRepeatEnd() const { return repeatEnd_; }
    void setRepeatEnd(bool rep) { repeatEnd_ = rep; }

    int getRepeatCount() const { return repeatCount_; }
    void setRepeatCount(int count) { repeatCount_ = count; }

private:
    void sortContent() {
        std::sort(chords_.begin(), chords_.end(),
                  [](const auto& a, const auto& b) { return a.first < b.first; });
    }

    int measureNumber_;
    TimeSignature timeSig_;
    KeySignature keySig_;
    ClefType clef_ = ClefType::Treble;
    double tempo_ = 120.0;

    std::vector<std::pair<double, std::unique_ptr<Chord>>> chords_;
    std::vector<std::pair<double, std::unique_ptr<Rest>>> rests_;
    std::map<double, Dynamic> dynamics_;

    BarlineType endBarline_ = BarlineType::Normal;
    bool repeatStart_ = false;
    bool repeatEnd_ = false;
    int repeatCount_ = 2;
};

//==============================================================================
/** Staff (single line of music) */
class Staff {
public:
    Staff(const juce::String& name = "Staff")
        : name_(name)
    {
        id_ = juce::Uuid().toString();
    }

    juce::String getId() const { return id_; }
    juce::String getName() const { return name_; }
    void setName(const juce::String& name) { name_ = name; }

    ClefType getClef() const { return clef_; }
    void setClef(ClefType clef) { clef_ = clef; }

    //==============================================================================
    Measure* addMeasure() {
        int num = static_cast<int>(measures_.size()) + 1;
        auto measure = std::make_unique<Measure>(num);
        Measure* ptr = measure.get();
        measures_.push_back(std::move(measure));
        return ptr;
    }

    Measure* getMeasure(int index) {
        return index >= 0 && index < static_cast<int>(measures_.size()) ?
               measures_[index].get() : nullptr;
    }

    int getNumMeasures() const { return static_cast<int>(measures_.size()); }

    //==============================================================================
    // Transposition
    int getTransposition() const { return transposition_; }
    void setTransposition(int semitones) { transposition_ = semitones; }

    // MIDI output
    int getMIDIChannel() const { return midiChannel_; }
    void setMIDIChannel(int channel) { midiChannel_ = juce::jlimit(1, 16, channel); }

    int getMIDIProgram() const { return midiProgram_; }
    void setMIDIProgram(int program) { midiProgram_ = juce::jlimit(0, 127, program); }

private:
    juce::String id_;
    juce::String name_;
    ClefType clef_ = ClefType::Treble;
    std::vector<std::unique_ptr<Measure>> measures_;
    int transposition_ = 0;
    int midiChannel_ = 1;
    int midiProgram_ = 0;
};

//==============================================================================
/** Part (instrument, may have multiple staves) */
class Part {
public:
    Part(const juce::String& name = "Piano")
        : name_(name)
    {
        id_ = juce::Uuid().toString();
    }

    juce::String getId() const { return id_; }
    juce::String getName() const { return name_; }
    void setName(const juce::String& name) { name_ = name; }

    juce::String getAbbreviation() const { return abbreviation_; }
    void setAbbreviation(const juce::String& abbr) { abbreviation_ = abbr; }

    //==============================================================================
    Staff* addStaff(const juce::String& name = "") {
        auto staff = std::make_unique<Staff>(name.isEmpty() ? name_ : name);
        Staff* ptr = staff.get();
        staves_.push_back(std::move(staff));
        return ptr;
    }

    Staff* getStaff(int index) {
        return index >= 0 && index < static_cast<int>(staves_.size()) ?
               staves_[index].get() : nullptr;
    }

    int getNumStaves() const { return static_cast<int>(staves_.size()); }

    //==============================================================================
    // Grand staff (piano)
    void setupGrandStaff() {
        staves_.clear();
        auto treble = addStaff("Right Hand");
        treble->setClef(ClefType::Treble);
        auto bass = addStaff("Left Hand");
        bass->setClef(ClefType::Bass);
    }

private:
    juce::String id_;
    juce::String name_;
    juce::String abbreviation_;
    std::vector<std::unique_ptr<Staff>> staves_;
};

//==============================================================================
/** Complete musical score */
class Score {
public:
    Score(const juce::String& title = "Untitled Score")
        : title_(title)
    {
    }

    //==============================================================================
    // Metadata
    juce::String getTitle() const { return title_; }
    void setTitle(const juce::String& title) { title_ = title; }

    juce::String getComposer() const { return composer_; }
    void setComposer(const juce::String& composer) { composer_ = composer; }

    juce::String getCopyright() const { return copyright_; }
    void setCopyright(const juce::String& cr) { copyright_ = cr; }

    //==============================================================================
    // Parts
    Part* addPart(const juce::String& name) {
        auto part = std::make_unique<Part>(name);
        Part* ptr = part.get();
        parts_.push_back(std::move(part));
        return ptr;
    }

    Part* getPart(int index) {
        return index >= 0 && index < static_cast<int>(parts_.size()) ?
               parts_[index].get() : nullptr;
    }

    int getNumParts() const { return static_cast<int>(parts_.size()); }

    //==============================================================================
    // Default time/key signature
    void setDefaultTimeSignature(int num, int denom) {
        defaultTimeSig_.numerator = num;
        defaultTimeSig_.denominator = denom;
    }

    void setDefaultKeySignature(int sharpsOrFlats, bool isMinor = false) {
        defaultKeySig_.sharpsOrFlats = sharpsOrFlats;
        defaultKeySig_.isMinor = isMinor;
    }

    void setDefaultTempo(double bpm) { defaultTempo_ = bpm; }
    double getDefaultTempo() const { return defaultTempo_; }

    //==============================================================================
    // Export to MIDI
    juce::MidiMessageSequence exportToMIDI() const {
        juce::MidiMessageSequence sequence;
        double currentTime = 0.0;
        double ticksPerBeat = 480.0;

        for (const auto& part : parts_) {
            for (int staffIdx = 0; staffIdx < part->getNumStaves(); ++staffIdx) {
                auto* staff = part->getStaff(staffIdx);
                int channel = staff->getMIDIChannel();

                // Program change
                sequence.addEvent(juce::MidiMessage::programChange(
                    channel, staff->getMIDIProgram()));

                double measureTime = 0.0;
                for (int m = 0; m < staff->getNumMeasures(); ++m) {
                    auto* measure = staff->getMeasure(m);
                    double beatsInMeasure = measure->getTimeSignature().getBeatsPerMeasure();

                    for (auto& [beatPos, chord] : const_cast<Staff*>(staff)->getMeasure(m)->getChords()) {
                        double noteTime = measureTime + beatPos;
                        double noteTimeInTicks = noteTime * ticksPerBeat;

                        for (auto* note : chord->getNotes()) {
                            int midiNote = note->getPitch().midiNote + staff->getTransposition();
                            double duration = note->getDurationInBeats() * ticksPerBeat;

                            sequence.addEvent(juce::MidiMessage::noteOn(
                                channel, midiNote, (juce::uint8)100), noteTimeInTicks);
                            sequence.addEvent(juce::MidiMessage::noteOff(
                                channel, midiNote), noteTimeInTicks + duration);
                        }
                    }

                    measureTime += beatsInMeasure;
                }
            }
        }

        sequence.sort();
        return sequence;
    }

    //==============================================================================
    // Export to MusicXML
    juce::String exportToMusicXML() const {
        juce::String xml;
        xml += "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n";
        xml += "<!DOCTYPE score-partwise PUBLIC \"-//Recordare//DTD MusicXML 3.1 Partwise//EN\" \"http://www.musicxml.org/dtds/partwise.dtd\">\n";
        xml += "<score-partwise version=\"3.1\">\n";

        // Work info
        xml += "  <work>\n";
        xml += "    <work-title>" + title_ + "</work-title>\n";
        xml += "  </work>\n";

        // Identification
        xml += "  <identification>\n";
        xml += "    <creator type=\"composer\">" + composer_ + "</creator>\n";
        xml += "    <rights>" + copyright_ + "</rights>\n";
        xml += "  </identification>\n";

        // Part list
        xml += "  <part-list>\n";
        for (size_t i = 0; i < parts_.size(); ++i) {
            xml += "    <score-part id=\"P" + juce::String(i + 1) + "\">\n";
            xml += "      <part-name>" + parts_[i]->getName() + "</part-name>\n";
            xml += "    </score-part>\n";
        }
        xml += "  </part-list>\n";

        // Parts with measures
        for (size_t i = 0; i < parts_.size(); ++i) {
            xml += "  <part id=\"P" + juce::String(i + 1) + "\">\n";
            // Add measures here...
            xml += "  </part>\n";
        }

        xml += "</score-partwise>\n";
        return xml;
    }

private:
    juce::String title_;
    juce::String composer_;
    juce::String copyright_;

    std::vector<std::unique_ptr<Part>> parts_;

    TimeSignature defaultTimeSig_;
    KeySignature defaultKeySig_;
    double defaultTempo_ = 120.0;
};

//==============================================================================
/** Notation editor with playback */
class NotationEditor {
public:
    NotationEditor() {
        score_ = std::make_unique<Score>();
    }

    Score* getScore() { return score_.get(); }

    //==============================================================================
    // Note input
    void setInputDuration(NoteDuration dur) { inputDuration_ = dur; }
    NoteDuration getInputDuration() const { return inputDuration_; }

    void setInputDots(int dots) { inputDots_ = dots; }

    void inputNote(int midiNote, Staff* staff, int measureIndex, double beatPosition) {
        auto* measure = staff->getMeasure(measureIndex);
        if (!measure) return;

        auto chord = std::make_unique<Chord>();
        auto note = std::make_unique<Note>(midiNote, inputDuration_);
        note->setDots(inputDots_);
        chord->addNote(std::move(note));
        measure->addChord(std::move(chord), beatPosition);
    }

    //==============================================================================
    // Playback
    void play() {
        if (!score_) return;
        midiSequence_ = score_->exportToMIDI();
        isPlaying_ = true;
        playbackPosition_ = 0.0;
    }

    void stop() {
        isPlaying_ = false;
        playbackPosition_ = 0.0;
    }

    void pause() {
        isPlaying_ = false;
    }

    bool isPlaying() const { return isPlaying_; }
    double getPlaybackPosition() const { return playbackPosition_; }

    void setPlaybackPosition(double beats) {
        playbackPosition_ = std::max(0.0, beats);
    }

    //==============================================================================
    // Selection
    void selectNote(Note* note) {
        clearSelection();
        if (note) {
            note->setSelected(true);
            selectedNotes_.push_back(note);
        }
    }

    void addToSelection(Note* note) {
        if (note && !note->isSelected()) {
            note->setSelected(true);
            selectedNotes_.push_back(note);
        }
    }

    void clearSelection() {
        for (auto* note : selectedNotes_) {
            note->setSelected(false);
        }
        selectedNotes_.clear();
    }

    std::vector<Note*> getSelectedNotes() { return selectedNotes_; }

    //==============================================================================
    // Edit selected notes
    void transposeSelection(int semitones) {
        for (auto* note : selectedNotes_) {
            note->getPitch().midiNote += semitones;
        }
    }

    void setSelectionDuration(NoteDuration dur) {
        for (auto* note : selectedNotes_) {
            note->setDuration(dur);
        }
    }

    void deleteSelection() {
        // Implementation would remove notes from their parent chords
        clearSelection();
    }

    //==============================================================================
    // View settings
    void setZoom(double zoom) { zoom_ = juce::jlimit(0.25, 4.0, zoom); }
    double getZoom() const { return zoom_; }

    void setPageWidth(int width) { pageWidth_ = width; }
    int getPageWidth() const { return pageWidth_; }

private:
    std::unique_ptr<Score> score_;
    juce::MidiMessageSequence midiSequence_;

    NoteDuration inputDuration_ = NoteDuration::Quarter;
    int inputDots_ = 0;

    bool isPlaying_ = false;
    double playbackPosition_ = 0.0;

    std::vector<Note*> selectedNotes_;

    double zoom_ = 1.0;
    int pageWidth_ = 800;
};

} // namespace Notation
} // namespace Echoelmusic
