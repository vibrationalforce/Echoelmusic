#pragma once

#include <JuceHeader.h>
#include <vector>
#include <set>
#include <memory>
#include <functional>
#include <algorithm>

/**
 * MIDIEditor - Complete MIDI Editing System
 *
 * Professional MIDI editing capabilities including piano roll,
 * note editing, quantization, and automation.
 *
 * Features:
 * - Piano roll note editing
 * - Multi-note selection and editing
 * - Quantization (snap to grid)
 * - Velocity editing
 * - CC automation lanes
 * - Time stretching
 * - Note transformations
 * - Undo/Redo support
 * - MIDI file import/export
 */

namespace Echoel {

//==========================================================================
// MIDI Note
//==========================================================================

struct MIDINote {
    int id = 0;                    // Unique ID
    int noteNumber = 60;           // MIDI note (0-127)
    int velocity = 100;            // Note-on velocity (1-127)
    int releaseVelocity = 64;      // Note-off velocity
    double startTime = 0.0;        // Start position in beats
    double duration = 1.0;         // Duration in beats
    int channel = 1;               // MIDI channel (1-16)

    // Editing state
    bool selected = false;
    bool muted = false;

    MIDINote() = default;
    MIDINote(int note, int vel, double start, double dur, int ch = 1)
        : noteNumber(note), velocity(vel), startTime(start), duration(dur), channel(ch) {}

    double getEndTime() const { return startTime + duration; }

    bool overlaps(const MIDINote& other) const {
        return noteNumber == other.noteNumber &&
               startTime < other.getEndTime() &&
               getEndTime() > other.startTime;
    }
};

//==========================================================================
// MIDI CC Automation Point
//==========================================================================

struct MIDICCPoint {
    double time = 0.0;       // Position in beats
    int value = 0;           // CC value (0-127)
    int curveType = 0;       // 0=linear, 1=smooth, 2=step

    MIDICCPoint() = default;
    MIDICCPoint(double t, int v, int curve = 0) : time(t), value(v), curveType(curve) {}
};

struct MIDICCLane {
    int ccNumber = 0;        // CC number (0-127)
    juce::String name;
    std::vector<MIDICCPoint> points;
    bool visible = true;

    int getValueAt(double time) const {
        if (points.empty()) return 0;
        if (time <= points.front().time) return points.front().value;
        if (time >= points.back().time) return points.back().value;

        for (size_t i = 0; i < points.size() - 1; ++i) {
            if (time >= points[i].time && time < points[i + 1].time) {
                // Interpolate
                double t = (time - points[i].time) / (points[i + 1].time - points[i].time);

                if (points[i].curveType == 2) {  // Step
                    return points[i].value;
                } else if (points[i].curveType == 1) {  // Smooth
                    // Cosine interpolation
                    t = (1.0 - std::cos(t * juce::MathConstants<double>::pi)) / 2.0;
                }

                return static_cast<int>(points[i].value + t * (points[i + 1].value - points[i].value));
            }
        }

        return 0;
    }
};

//==========================================================================
// Quantization Settings
//==========================================================================

struct QuantizeSettings {
    double gridSize = 0.25;        // Grid size in beats (0.25 = 16th note)
    double strength = 100.0;       // Quantize strength (0-100%)
    double swingAmount = 0.0;      // Swing (-100 to 100%)
    bool quantizeStart = true;     // Quantize note starts
    bool quantizeEnd = false;      // Quantize note ends
    bool quantizeVelocity = false; // Quantize velocity to steps
    int velocitySteps = 8;         // Number of velocity steps
};

//==========================================================================
// Edit Operation (for Undo/Redo)
//==========================================================================

enum class EditOperationType {
    AddNotes,
    DeleteNotes,
    MoveNotes,
    ResizeNotes,
    ChangeVelocity,
    Quantize,
    Transpose,
    AddCCPoints,
    DeleteCCPoints,
    MoveCCPoints
};

struct EditOperation {
    EditOperationType type;
    std::vector<MIDINote> notesBefore;
    std::vector<MIDINote> notesAfter;
    std::vector<int> affectedIds;
    int ccNumber = 0;
    std::vector<MIDICCPoint> ccBefore;
    std::vector<MIDICCPoint> ccAfter;
};

//==========================================================================
// MIDI Clip
//==========================================================================

class MIDIClip {
public:
    MIDIClip() = default;
    MIDIClip(const juce::String& name, double length = 4.0)
        : clipName(name), clipLength(length) {}

    //==========================================================================
    // Note Management
    //==========================================================================

    int addNote(const MIDINote& note) {
        MIDINote n = note;
        n.id = nextNoteId++;
        notes.push_back(n);
        sortNotes();
        return n.id;
    }

    void removeNote(int id) {
        notes.erase(std::remove_if(notes.begin(), notes.end(),
            [id](const MIDINote& n) { return n.id == id; }), notes.end());
    }

    void removeSelectedNotes() {
        notes.erase(std::remove_if(notes.begin(), notes.end(),
            [](const MIDINote& n) { return n.selected; }), notes.end());
    }

    MIDINote* getNote(int id) {
        auto it = std::find_if(notes.begin(), notes.end(),
            [id](const MIDINote& n) { return n.id == id; });
        return it != notes.end() ? &(*it) : nullptr;
    }

    std::vector<MIDINote*> getNotesInRange(double startTime, double endTime) {
        std::vector<MIDINote*> result;
        for (auto& note : notes) {
            if (note.startTime < endTime && note.getEndTime() > startTime) {
                result.push_back(&note);
            }
        }
        return result;
    }

    std::vector<MIDINote*> getSelectedNotes() {
        std::vector<MIDINote*> result;
        for (auto& note : notes) {
            if (note.selected) {
                result.push_back(&note);
            }
        }
        return result;
    }

    //==========================================================================
    // Selection
    //==========================================================================

    void selectAll() {
        for (auto& note : notes) {
            note.selected = true;
        }
    }

    void deselectAll() {
        for (auto& note : notes) {
            note.selected = false;
        }
    }

    void selectNoteAt(double time, int noteNumber, bool addToSelection = false) {
        if (!addToSelection) deselectAll();

        for (auto& note : notes) {
            if (note.noteNumber == noteNumber &&
                time >= note.startTime && time < note.getEndTime()) {
                note.selected = true;
                break;
            }
        }
    }

    void selectNotesInRect(double startTime, double endTime,
                          int lowNote, int highNote, bool addToSelection = false) {
        if (!addToSelection) deselectAll();

        for (auto& note : notes) {
            if (note.startTime < endTime && note.getEndTime() > startTime &&
                note.noteNumber >= lowNote && note.noteNumber <= highNote) {
                note.selected = true;
            }
        }
    }

    //==========================================================================
    // Note Editing
    //==========================================================================

    void moveSelectedNotes(double deltaTime, int deltaNote) {
        for (auto& note : notes) {
            if (note.selected) {
                note.startTime = std::max(0.0, note.startTime + deltaTime);
                note.noteNumber = juce::jlimit(0, 127, note.noteNumber + deltaNote);
            }
        }
        sortNotes();
    }

    void resizeSelectedNotes(double deltaDuration, bool fromStart = false) {
        for (auto& note : notes) {
            if (note.selected) {
                if (fromStart) {
                    double newStart = note.startTime + deltaDuration;
                    if (newStart >= 0 && newStart < note.getEndTime() - 0.01) {
                        note.duration -= deltaDuration;
                        note.startTime = newStart;
                    }
                } else {
                    double newDuration = note.duration + deltaDuration;
                    if (newDuration > 0.01) {
                        note.duration = newDuration;
                    }
                }
            }
        }
    }

    void setSelectedVelocity(int velocity) {
        velocity = juce::jlimit(1, 127, velocity);
        for (auto& note : notes) {
            if (note.selected) {
                note.velocity = velocity;
            }
        }
    }

    void scaleSelectedVelocity(float factor) {
        for (auto& note : notes) {
            if (note.selected) {
                note.velocity = juce::jlimit(1, 127,
                    static_cast<int>(note.velocity * factor));
            }
        }
    }

    void transposeSelected(int semitones) {
        for (auto& note : notes) {
            if (note.selected) {
                note.noteNumber = juce::jlimit(0, 127, note.noteNumber + semitones);
            }
        }
    }

    //==========================================================================
    // Quantization
    //==========================================================================

    void quantizeSelected(const QuantizeSettings& settings) {
        for (auto& note : notes) {
            if (note.selected) {
                if (settings.quantizeStart) {
                    double originalStart = note.startTime;
                    double quantizedStart = quantizeTime(note.startTime, settings);
                    double delta = quantizedStart - originalStart;
                    note.startTime = originalStart + delta * (settings.strength / 100.0);
                }

                if (settings.quantizeEnd) {
                    double endTime = note.getEndTime();
                    double quantizedEnd = quantizeTime(endTime, settings);
                    double delta = quantizedEnd - endTime;
                    double newEnd = endTime + delta * (settings.strength / 100.0);
                    note.duration = newEnd - note.startTime;
                }

                if (settings.quantizeVelocity) {
                    int step = 127 / settings.velocitySteps;
                    note.velocity = ((note.velocity + step / 2) / step) * step;
                    note.velocity = juce::jlimit(1, 127, note.velocity);
                }
            }
        }
        sortNotes();
    }

    //==========================================================================
    // CC Automation
    //==========================================================================

    MIDICCLane& getOrCreateCCLane(int ccNumber) {
        for (auto& lane : ccLanes) {
            if (lane.ccNumber == ccNumber) return lane;
        }
        MIDICCLane lane;
        lane.ccNumber = ccNumber;
        lane.name = getCCName(ccNumber);
        ccLanes.push_back(lane);
        return ccLanes.back();
    }

    void addCCPoint(int ccNumber, double time, int value) {
        auto& lane = getOrCreateCCLane(ccNumber);
        lane.points.push_back(MIDICCPoint(time, value));
        sortCCPoints(lane);
    }

    void removeCCPoint(int ccNumber, double time, double tolerance = 0.01) {
        for (auto& lane : ccLanes) {
            if (lane.ccNumber == ccNumber) {
                lane.points.erase(std::remove_if(lane.points.begin(), lane.points.end(),
                    [time, tolerance](const MIDICCPoint& p) {
                        return std::abs(p.time - time) < tolerance;
                    }), lane.points.end());
                break;
            }
        }
    }

    //==========================================================================
    // Undo/Redo
    //==========================================================================

    void beginEdit() {
        // Save current state for undo
        currentEdit.notesBefore = notes;
    }

    void endEdit(EditOperationType type) {
        currentEdit.type = type;
        currentEdit.notesAfter = notes;
        undoStack.push_back(currentEdit);
        redoStack.clear();

        // Limit undo history
        if (undoStack.size() > 100) {
            undoStack.erase(undoStack.begin());
        }
    }

    void undo() {
        if (undoStack.empty()) return;

        EditOperation op = undoStack.back();
        undoStack.pop_back();

        notes = op.notesBefore;
        redoStack.push_back(op);
    }

    void redo() {
        if (redoStack.empty()) return;

        EditOperation op = redoStack.back();
        redoStack.pop_back();

        notes = op.notesAfter;
        undoStack.push_back(op);
    }

    bool canUndo() const { return !undoStack.empty(); }
    bool canRedo() const { return !redoStack.empty(); }

    //==========================================================================
    // MIDI File I/O
    //==========================================================================

    void importMIDI(const juce::MidiMessageSequence& sequence, double ticksPerBeat = 480.0) {
        notes.clear();

        std::unordered_map<int, std::pair<double, int>> activeNotes;  // note -> (start, velocity)

        for (int i = 0; i < sequence.getNumEvents(); ++i) {
            auto* event = sequence.getEventPointer(i);
            const auto& msg = event->message;
            double time = msg.getTimeStamp() / ticksPerBeat;

            if (msg.isNoteOn()) {
                activeNotes[msg.getNoteNumber()] = {time, msg.getVelocity()};
            } else if (msg.isNoteOff()) {
                auto it = activeNotes.find(msg.getNoteNumber());
                if (it != activeNotes.end()) {
                    MIDINote note;
                    note.noteNumber = msg.getNoteNumber();
                    note.startTime = it->second.first;
                    note.velocity = it->second.second;
                    note.duration = time - it->second.first;
                    note.channel = msg.getChannel();
                    addNote(note);
                    activeNotes.erase(it);
                }
            } else if (msg.isController()) {
                addCCPoint(msg.getControllerNumber(), time, msg.getControllerValue());
            }
        }
    }

    juce::MidiMessageSequence exportMIDI(double ticksPerBeat = 480.0) const {
        juce::MidiMessageSequence sequence;

        for (const auto& note : notes) {
            if (note.muted) continue;

            double startTicks = note.startTime * ticksPerBeat;
            double endTicks = note.getEndTime() * ticksPerBeat;

            auto noteOn = juce::MidiMessage::noteOn(note.channel, note.noteNumber, (uint8_t)note.velocity);
            noteOn.setTimeStamp(startTicks);
            sequence.addEvent(noteOn);

            auto noteOff = juce::MidiMessage::noteOff(note.channel, note.noteNumber, (uint8_t)note.releaseVelocity);
            noteOff.setTimeStamp(endTicks);
            sequence.addEvent(noteOff);
        }

        // Add CC data
        for (const auto& lane : ccLanes) {
            for (const auto& point : lane.points) {
                auto cc = juce::MidiMessage::controllerEvent(1, lane.ccNumber, point.value);
                cc.setTimeStamp(point.time * ticksPerBeat);
                sequence.addEvent(cc);
            }
        }

        sequence.sort();
        return sequence;
    }

    //==========================================================================
    // Properties
    //==========================================================================

    const juce::String& getName() const { return clipName; }
    void setName(const juce::String& name) { clipName = name; }

    double getLength() const { return clipLength; }
    void setLength(double length) { clipLength = length; }

    const std::vector<MIDINote>& getNotes() const { return notes; }
    const std::vector<MIDICCLane>& getCCLanes() const { return ccLanes; }

    int getNoteCount() const { return static_cast<int>(notes.size()); }
    int getSelectedNoteCount() const {
        return static_cast<int>(std::count_if(notes.begin(), notes.end(),
            [](const MIDINote& n) { return n.selected; }));
    }

private:
    double quantizeTime(double time, const QuantizeSettings& settings) const {
        double gridSize = settings.gridSize;
        double gridPos = std::round(time / gridSize);

        // Apply swing to even grid positions
        if (settings.swingAmount != 0.0 && static_cast<int>(gridPos) % 2 == 1) {
            gridPos += settings.swingAmount / 100.0 * 0.5;
        }

        return gridPos * gridSize;
    }

    void sortNotes() {
        std::sort(notes.begin(), notes.end(),
            [](const MIDINote& a, const MIDINote& b) {
                if (a.startTime != b.startTime) return a.startTime < b.startTime;
                return a.noteNumber < b.noteNumber;
            });
    }

    void sortCCPoints(MIDICCLane& lane) {
        std::sort(lane.points.begin(), lane.points.end(),
            [](const MIDICCPoint& a, const MIDICCPoint& b) {
                return a.time < b.time;
            });
    }

    juce::String getCCName(int ccNumber) const {
        static const std::unordered_map<int, juce::String> ccNames = {
            {1, "Modulation"}, {2, "Breath"}, {4, "Foot"},
            {7, "Volume"}, {10, "Pan"}, {11, "Expression"},
            {64, "Sustain"}, {65, "Portamento"}, {66, "Sostenuto"},
            {67, "Soft Pedal"}, {68, "Legato"}, {71, "Resonance"},
            {72, "Release"}, {73, "Attack"}, {74, "Brightness"},
            {91, "Reverb"}, {93, "Chorus"}, {94, "Detune"}
        };

        auto it = ccNames.find(ccNumber);
        if (it != ccNames.end()) return it->second;
        return "CC " + juce::String(ccNumber);
    }

    juce::String clipName = "MIDI Clip";
    double clipLength = 4.0;  // Beats

    std::vector<MIDINote> notes;
    std::vector<MIDICCLane> ccLanes;
    int nextNoteId = 1;

    std::vector<EditOperation> undoStack;
    std::vector<EditOperation> redoStack;
    EditOperation currentEdit;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MIDIClip)
};

//==========================================================================
// MIDI Editor - Main Class
//==========================================================================

class MIDIEditor {
public:
    MIDIEditor() = default;

    //==========================================================================
    // Clip Management
    //==========================================================================

    void setClip(MIDIClip* clip) { activeClip = clip; }
    MIDIClip* getClip() { return activeClip; }

    //==========================================================================
    // View Settings
    //==========================================================================

    void setViewRange(double startBeat, double endBeat) {
        viewStartBeat = startBeat;
        viewEndBeat = endBeat;
    }

    void setNoteRange(int lowNote, int highNote) {
        viewLowNote = lowNote;
        viewHighNote = highNote;
    }

    void setGridSize(double beats) { gridSize = beats; }
    double getGridSize() const { return gridSize; }

    void setSnapToGrid(bool snap) { snapEnabled = snap; }
    bool isSnapEnabled() const { return snapEnabled; }

    //==========================================================================
    // Quantization
    //==========================================================================

    void setQuantizeSettings(const QuantizeSettings& settings) {
        quantizeSettings = settings;
    }

    const QuantizeSettings& getQuantizeSettings() const { return quantizeSettings; }

    void quantizeSelection() {
        if (activeClip) {
            activeClip->beginEdit();
            activeClip->quantizeSelected(quantizeSettings);
            activeClip->endEdit(EditOperationType::Quantize);
        }
    }

    //==========================================================================
    // Tools
    //==========================================================================

    enum class Tool {
        Select,
        Draw,
        Erase,
        Velocity,
        Split,
        Glue
    };

    void setTool(Tool tool) { currentTool = tool; }
    Tool getTool() const { return currentTool; }

    //==========================================================================
    // Mouse Interaction
    //==========================================================================

    void mouseDown(double beatPos, int noteNumber, bool shift, bool alt) {
        if (!activeClip) return;

        switch (currentTool) {
            case Tool::Select:
                activeClip->selectNoteAt(beatPos, noteNumber, shift);
                break;
            case Tool::Draw:
                if (snapEnabled) beatPos = snapToGrid(beatPos);
                activeClip->beginEdit();
                lastCreatedNoteId = activeClip->addNote(
                    MIDINote(noteNumber, defaultVelocity, beatPos, gridSize));
                activeClip->endEdit(EditOperationType::AddNotes);
                break;
            case Tool::Erase:
                activeClip->beginEdit();
                activeClip->selectNoteAt(beatPos, noteNumber);
                activeClip->removeSelectedNotes();
                activeClip->endEdit(EditOperationType::DeleteNotes);
                break;
            default:
                break;
        }
    }

    void mouseDrag(double beatPos, int noteNumber, double startBeatPos, int startNoteNumber) {
        if (!activeClip) return;

        switch (currentTool) {
            case Tool::Select:
                activeClip->selectNotesInRect(
                    std::min(startBeatPos, beatPos),
                    std::max(startBeatPos, beatPos),
                    std::min(startNoteNumber, noteNumber),
                    std::max(startNoteNumber, noteNumber));
                break;
            case Tool::Draw:
                if (auto* note = activeClip->getNote(lastCreatedNoteId)) {
                    double duration = beatPos - note->startTime;
                    if (snapEnabled) duration = std::max(gridSize, snapToGrid(duration));
                    note->duration = std::max(0.01, duration);
                }
                break;
            default:
                break;
        }
    }

    void mouseUp() {
        // Finalize any ongoing operation
    }

    //==========================================================================
    // Keyboard Shortcuts
    //==========================================================================

    void deleteSelected() {
        if (activeClip) {
            activeClip->beginEdit();
            activeClip->removeSelectedNotes();
            activeClip->endEdit(EditOperationType::DeleteNotes);
        }
    }

    void selectAll() {
        if (activeClip) activeClip->selectAll();
    }

    void deselectAll() {
        if (activeClip) activeClip->deselectAll();
    }

    void undo() {
        if (activeClip) activeClip->undo();
    }

    void redo() {
        if (activeClip) activeClip->redo();
    }

    void copy() {
        if (!activeClip) return;
        clipboard.clear();
        for (const auto& note : activeClip->getNotes()) {
            if (note.selected) {
                clipboard.push_back(note);
            }
        }
    }

    void paste(double atBeat = -1.0) {
        if (!activeClip || clipboard.empty()) return;

        // Find earliest note in clipboard
        double earliestStart = clipboard[0].startTime;
        for (const auto& note : clipboard) {
            earliestStart = std::min(earliestStart, note.startTime);
        }

        // Paste offset
        double offset = (atBeat >= 0 ? atBeat : cursorPosition) - earliestStart;

        activeClip->beginEdit();
        activeClip->deselectAll();

        for (auto note : clipboard) {
            note.startTime += offset;
            note.selected = true;
            activeClip->addNote(note);
        }

        activeClip->endEdit(EditOperationType::AddNotes);
    }

    void duplicate() {
        copy();
        paste();
    }

    //==========================================================================
    // Status
    //==========================================================================

    juce::String getStatus() const {
        juce::String status;
        status << "MIDI Editor\n";
        status << "===========\n\n";
        status << "Tool: " << getToolName(currentTool) << "\n";
        status << "Grid: " << gridSize << " beats\n";
        status << "Snap: " << (snapEnabled ? "On" : "Off") << "\n";

        if (activeClip) {
            status << "\nClip: " << activeClip->getName() << "\n";
            status << "Notes: " << activeClip->getNoteCount() << "\n";
            status << "Selected: " << activeClip->getSelectedNoteCount() << "\n";
            status << "Can Undo: " << (activeClip->canUndo() ? "Yes" : "No") << "\n";
            status << "Can Redo: " << (activeClip->canRedo() ? "Yes" : "No") << "\n";
        }

        return status;
    }

private:
    double snapToGrid(double beat) const {
        return std::round(beat / gridSize) * gridSize;
    }

    juce::String getToolName(Tool tool) const {
        switch (tool) {
            case Tool::Select: return "Select";
            case Tool::Draw: return "Draw";
            case Tool::Erase: return "Erase";
            case Tool::Velocity: return "Velocity";
            case Tool::Split: return "Split";
            case Tool::Glue: return "Glue";
            default: return "Unknown";
        }
    }

    MIDIClip* activeClip = nullptr;

    // View
    double viewStartBeat = 0.0;
    double viewEndBeat = 16.0;
    int viewLowNote = 36;
    int viewHighNote = 96;

    // Grid
    double gridSize = 0.25;  // 16th note
    bool snapEnabled = true;

    // Tool
    Tool currentTool = Tool::Select;
    int defaultVelocity = 100;

    // Editing state
    int lastCreatedNoteId = -1;
    double cursorPosition = 0.0;

    // Clipboard
    std::vector<MIDINote> clipboard;

    // Quantize
    QuantizeSettings quantizeSettings;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MIDIEditor)
};

} // namespace Echoel
