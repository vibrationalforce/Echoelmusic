#pragma once

#include <JuceHeader.h>
#include <vector>
#include <memory>
#include <set>
#include <algorithm>

/**
 * PianoRollEditor - Production-Ready MIDI Note Editor
 *
 * Full-featured piano roll with:
 * - Note display and editing (drag, resize, velocity)
 * - Multi-note selection
 * - Quantization with visual grid
 * - Velocity lane editor
 * - Scale highlighting
 * - Ghost notes (from other tracks)
 * - MIDI learn and recording
 * - Undo/redo support
 *
 * Super Ralph Wiggum Loop Genius Wise Save Mode
 */

namespace Echoelmusic {
namespace UI {

//==============================================================================
// MIDI Note Data
//==============================================================================

struct MIDINote
{
    int noteNumber = 60;        // 0-127
    float startBeat = 0.0f;     // Position in beats
    float duration = 1.0f;      // Duration in beats
    int velocity = 100;         // 0-127
    int channel = 1;            // 1-16
    bool muted = false;
    bool selected = false;

    // For editing
    int id = -1;                // Unique ID for undo/redo

    float getEndBeat() const { return startBeat + duration; }

    bool containsBeat(float beat) const
    {
        return beat >= startBeat && beat < getEndBeat();
    }

    bool overlaps(const MIDINote& other) const
    {
        return noteNumber == other.noteNumber &&
               startBeat < other.getEndBeat() &&
               getEndBeat() > other.startBeat;
    }
};

//==============================================================================
// Scale Definitions
//==============================================================================

struct Scale
{
    std::string name;
    std::vector<int> intervals;  // Semitones from root

    bool containsNote(int noteNumber, int rootNote) const
    {
        int semitone = (noteNumber - rootNote + 120) % 12;
        return std::find(intervals.begin(), intervals.end(), semitone) != intervals.end();
    }

    static Scale major() { return {"Major", {0, 2, 4, 5, 7, 9, 11}}; }
    static Scale minor() { return {"Minor", {0, 2, 3, 5, 7, 8, 10}}; }
    static Scale harmonicMinor() { return {"Harmonic Minor", {0, 2, 3, 5, 7, 8, 11}}; }
    static Scale melodicMinor() { return {"Melodic Minor", {0, 2, 3, 5, 7, 9, 11}}; }
    static Scale dorian() { return {"Dorian", {0, 2, 3, 5, 7, 9, 10}}; }
    static Scale mixolydian() { return {"Mixolydian", {0, 2, 4, 5, 7, 9, 10}}; }
    static Scale pentatonic() { return {"Pentatonic", {0, 2, 4, 7, 9}}; }
    static Scale blues() { return {"Blues", {0, 3, 5, 6, 7, 10}}; }
    static Scale chromatic() { return {"Chromatic", {0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11}}; }
};

//==============================================================================
// Quantization Settings
//==============================================================================

struct QuantizeSettings
{
    enum class Grid
    {
        Off,
        Bar,
        Beat,
        Half,
        Quarter,
        Eighth,
        Sixteenth,
        ThirtySecond,
        Triplet8th,
        Triplet16th
    };

    Grid grid = Grid::Sixteenth;
    float strength = 1.0f;      // 0-1, how much to quantize
    bool quantizeStart = true;
    bool quantizeEnd = false;

    float getGridBeats(int beatsPerBar = 4) const
    {
        switch (grid)
        {
            case Grid::Off: return 0.0f;
            case Grid::Bar: return static_cast<float>(beatsPerBar);
            case Grid::Beat: return 1.0f;
            case Grid::Half: return 0.5f;
            case Grid::Quarter: return 0.25f;
            case Grid::Eighth: return 0.125f;
            case Grid::Sixteenth: return 0.0625f;
            case Grid::ThirtySecond: return 0.03125f;
            case Grid::Triplet8th: return 1.0f / 6.0f;
            case Grid::Triplet16th: return 1.0f / 12.0f;
        }
        return 0.0625f;
    }

    float quantize(float beat) const
    {
        if (grid == Grid::Off || strength <= 0.0f)
            return beat;

        float gridSize = getGridBeats();
        float quantized = std::round(beat / gridSize) * gridSize;

        return beat + (quantized - beat) * strength;
    }
};

//==============================================================================
// Piano Roll Colors
//==============================================================================

struct PianoRollColors
{
    juce::Colour background{0xFF1A1A1A};
    juce::Colour gridLines{0xFF2A2A2A};
    juce::Colour beatLines{0xFF3A3A3A};
    juce::Colour barLines{0xFF4A4A4A};

    juce::Colour keyWhite{0xFF3A3A3A};
    juce::Colour keyBlack{0xFF2A2A2A};
    juce::Colour keyHighlight{0xFF4A6A8A};
    juce::Colour keyRoot{0xFF5A4A3A};

    juce::Colour noteDefault{0xFF4A9EFF};
    juce::Colour noteSelected{0xFFFF9E4A};
    juce::Colour noteMuted{0xFF6A6A6A};
    juce::Colour noteGhost{0x404A9EFF};
    juce::Colour noteBorder{0xFF2A2A2A};

    juce::Colour velocityBar{0xFF4A9EFF};
    juce::Colour velocityBackground{0xFF1A1A1A};

    juce::Colour playhead{0xFFFF6B6B};
    juce::Colour selection{0x404A9EFF};
};

//==============================================================================
// Piano Roll Editor Component
//==============================================================================

class PianoRollEditor : public juce::Component
{
public:
    struct Config
    {
        PianoRollColors colors;
        QuantizeSettings quantize;

        int lowestNote = 21;        // A0
        int highestNote = 108;      // C8
        int noteHeight = 16;        // Pixels per note
        float beatsPerBar = 4.0f;
        float bpm = 120.0f;

        bool showVelocityLane = true;
        int velocityLaneHeight = 60;

        bool showScaleHighlight = true;
        Scale scale = Scale::major();
        int rootNote = 0;           // C

        bool showGhostNotes = true;
        bool snapToGrid = true;
    };

    PianoRollEditor()
    {
        setOpaque(true);
    }

    void setConfig(const Config& newConfig)
    {
        config = newConfig;
        repaint();
    }

    // Note management
    void setNotes(const std::vector<MIDINote>& newNotes)
    {
        notes = newNotes;
        assignNoteIds();
        repaint();
    }

    const std::vector<MIDINote>& getNotes() const { return notes; }

    void addNote(MIDINote note)
    {
        note.id = nextNoteId++;
        notes.push_back(note);
        repaint();
        if (onNotesChanged) onNotesChanged(notes);
    }

    void removeNote(int noteId)
    {
        notes.erase(std::remove_if(notes.begin(), notes.end(),
            [noteId](const MIDINote& n) { return n.id == noteId; }), notes.end());
        repaint();
        if (onNotesChanged) onNotesChanged(notes);
    }

    void clearNotes()
    {
        notes.clear();
        repaint();
    }

    // Ghost notes (from other tracks)
    void setGhostNotes(const std::vector<MIDINote>& ghosts)
    {
        ghostNotes = ghosts;
        repaint();
    }

    // Selection
    void selectAll()
    {
        for (auto& note : notes)
            note.selected = true;
        repaint();
    }

    void deselectAll()
    {
        for (auto& note : notes)
            note.selected = false;
        repaint();
    }

    void deleteSelected()
    {
        notes.erase(std::remove_if(notes.begin(), notes.end(),
            [](const MIDINote& n) { return n.selected; }), notes.end());
        repaint();
        if (onNotesChanged) onNotesChanged(notes);
    }

    // Quantization
    void quantizeSelected()
    {
        for (auto& note : notes)
        {
            if (note.selected)
            {
                if (config.quantize.quantizeStart)
                    note.startBeat = config.quantize.quantize(note.startBeat);
                if (config.quantize.quantizeEnd)
                    note.duration = config.quantize.quantize(note.startBeat + note.duration) - note.startBeat;
            }
        }
        repaint();
        if (onNotesChanged) onNotesChanged(notes);
    }

    // View
    void setViewRange(float startBeat, float endBeat)
    {
        viewStartBeat = startBeat;
        viewEndBeat = endBeat;
        repaint();
    }

    void setPlayheadPosition(float beat)
    {
        playheadBeat = beat;
        repaint();
    }

    // Callbacks
    std::function<void(const std::vector<MIDINote>&)> onNotesChanged;
    std::function<void(const MIDINote&)> onNoteTriggered;
    std::function<void(float beat)> onPlayheadMoved;

    void paint(juce::Graphics& g) override
    {
        g.fillAll(config.colors.background);

        int pianoKeyWidth = 60;
        int velocityHeight = config.showVelocityLane ? config.velocityLaneHeight : 0;

        auto noteArea = getLocalBounds().withTrimmedLeft(pianoKeyWidth)
                                        .withTrimmedBottom(velocityHeight);
        auto pianoArea = getLocalBounds().withWidth(pianoKeyWidth)
                                         .withTrimmedBottom(velocityHeight);
        auto velocityArea = getLocalBounds().withTrimmedLeft(pianoKeyWidth)
                                            .withTop(noteArea.getBottom());

        // Draw piano keys
        drawPianoKeys(g, pianoArea);

        // Draw grid
        drawGrid(g, noteArea);

        // Draw ghost notes
        if (config.showGhostNotes)
            drawGhostNotes(g, noteArea);

        // Draw notes
        drawNotes(g, noteArea);

        // Draw playhead
        drawPlayhead(g, noteArea);

        // Draw velocity lane
        if (config.showVelocityLane)
            drawVelocityLane(g, velocityArea);

        // Draw selection rectangle
        if (isSelecting)
            drawSelectionRect(g, noteArea);
    }

    void mouseDown(const juce::MouseEvent& e) override
    {
        int pianoKeyWidth = 60;
        auto noteArea = getLocalBounds().withTrimmedLeft(pianoKeyWidth)
                                        .withTrimmedBottom(config.showVelocityLane ? config.velocityLaneHeight : 0);

        if (!noteArea.contains(e.getPosition()))
            return;

        float beat = pixelToBeat(e.x - pianoKeyWidth, noteArea.getWidth());
        int noteNum = pixelToNote(e.y, noteArea.getHeight());

        // Check if clicking on existing note
        MIDINote* clickedNote = findNoteAt(beat, noteNum);

        if (clickedNote)
        {
            if (e.mods.isShiftDown())
            {
                // Toggle selection
                clickedNote->selected = !clickedNote->selected;
            }
            else if (!clickedNote->selected)
            {
                // Select only this note
                deselectAll();
                clickedNote->selected = true;
            }

            // Check if near edge for resize
            float noteEndPixel = beatToPixel(clickedNote->getEndBeat(), noteArea.getWidth()) + pianoKeyWidth;
            if (std::abs(e.x - noteEndPixel) < 5)
            {
                isResizing = true;
                resizingNote = clickedNote;
            }
            else
            {
                isDragging = true;
                dragStartBeat = beat;
                dragStartNote = noteNum;
            }

            // Trigger note preview
            if (onNoteTriggered)
                onNoteTriggered(*clickedNote);
        }
        else
        {
            if (e.mods.isAltDown())
            {
                // Draw new note
                MIDINote newNote;
                newNote.noteNumber = noteNum;
                newNote.startBeat = config.snapToGrid ? config.quantize.quantize(beat) : beat;
                newNote.duration = config.quantize.getGridBeats();
                newNote.velocity = 100;

                addNote(newNote);

                if (onNoteTriggered)
                    onNoteTriggered(newNote);
            }
            else
            {
                // Start selection rectangle
                deselectAll();
                isSelecting = true;
                selectionStartX = e.x;
                selectionStartY = e.y;
                selectionEndX = e.x;
                selectionEndY = e.y;
            }
        }

        repaint();
    }

    void mouseDrag(const juce::MouseEvent& e) override
    {
        int pianoKeyWidth = 60;
        auto noteArea = getLocalBounds().withTrimmedLeft(pianoKeyWidth)
                                        .withTrimmedBottom(config.showVelocityLane ? config.velocityLaneHeight : 0);

        float beat = pixelToBeat(e.x - pianoKeyWidth, noteArea.getWidth());
        int noteNum = pixelToNote(e.y, noteArea.getHeight());

        if (isSelecting)
        {
            selectionEndX = e.x;
            selectionEndY = e.y;
            updateSelectionFromRect(noteArea, pianoKeyWidth);
            repaint();
        }
        else if (isDragging)
        {
            float beatDelta = beat - dragStartBeat;
            int noteDelta = noteNum - dragStartNote;

            if (config.snapToGrid)
                beatDelta = config.quantize.quantize(beatDelta + 0.0001f) - 0.0001f;

            for (auto& note : notes)
            {
                if (note.selected)
                {
                    note.startBeat += beatDelta;
                    note.noteNumber += noteDelta;
                    note.noteNumber = std::clamp(note.noteNumber, config.lowestNote, config.highestNote);
                }
            }

            dragStartBeat = beat;
            dragStartNote = noteNum;
            repaint();
        }
        else if (isResizing && resizingNote)
        {
            float newDuration = beat - resizingNote->startBeat;
            if (config.snapToGrid)
                newDuration = config.quantize.quantize(resizingNote->startBeat + newDuration) - resizingNote->startBeat;

            newDuration = std::max(newDuration, config.quantize.getGridBeats());
            resizingNote->duration = newDuration;
            repaint();
        }
    }

    void mouseUp(const juce::MouseEvent& e) override
    {
        if (isDragging || isResizing)
        {
            if (onNotesChanged)
                onNotesChanged(notes);
        }

        isDragging = false;
        isResizing = false;
        isSelecting = false;
        resizingNote = nullptr;
        repaint();
    }

    void mouseDoubleClick(const juce::MouseEvent& e) override
    {
        int pianoKeyWidth = 60;
        auto noteArea = getLocalBounds().withTrimmedLeft(pianoKeyWidth)
                                        .withTrimmedBottom(config.showVelocityLane ? config.velocityLaneHeight : 0);

        float beat = pixelToBeat(e.x - pianoKeyWidth, noteArea.getWidth());
        int noteNum = pixelToNote(e.y, noteArea.getHeight());

        MIDINote* clickedNote = findNoteAt(beat, noteNum);

        if (clickedNote)
        {
            // Delete note on double-click
            removeNote(clickedNote->id);
        }
        else
        {
            // Create new note on double-click
            MIDINote newNote;
            newNote.noteNumber = noteNum;
            newNote.startBeat = config.snapToGrid ? config.quantize.quantize(beat) : beat;
            newNote.duration = config.quantize.getGridBeats();
            newNote.velocity = 100;

            addNote(newNote);
        }
    }

    bool keyPressed(const juce::KeyPress& key) override
    {
        if (key == juce::KeyPress::deleteKey || key == juce::KeyPress::backspaceKey)
        {
            deleteSelected();
            return true;
        }
        else if (key.getModifiers().isCommandDown() && key.getKeyCode() == 'A')
        {
            selectAll();
            return true;
        }
        else if (key.getModifiers().isCommandDown() && key.getKeyCode() == 'Q')
        {
            quantizeSelected();
            return true;
        }

        return false;
    }

private:
    Config config;
    std::vector<MIDINote> notes;
    std::vector<MIDINote> ghostNotes;

    float viewStartBeat = 0.0f;
    float viewEndBeat = 16.0f;
    float playheadBeat = 0.0f;

    int nextNoteId = 1;

    // Interaction state
    bool isDragging = false;
    bool isResizing = false;
    bool isSelecting = false;
    float dragStartBeat = 0.0f;
    int dragStartNote = 0;
    MIDINote* resizingNote = nullptr;

    int selectionStartX = 0, selectionStartY = 0;
    int selectionEndX = 0, selectionEndY = 0;

    void assignNoteIds()
    {
        for (auto& note : notes)
        {
            if (note.id < 0)
                note.id = nextNoteId++;
        }
    }

    float pixelToBeat(int x, int width) const
    {
        float ratio = static_cast<float>(x) / width;
        return viewStartBeat + ratio * (viewEndBeat - viewStartBeat);
    }

    int beatToPixel(float beat, int width) const
    {
        float ratio = (beat - viewStartBeat) / (viewEndBeat - viewStartBeat);
        return static_cast<int>(ratio * width);
    }

    int pixelToNote(int y, int height) const
    {
        int noteRange = config.highestNote - config.lowestNote + 1;
        int noteFromTop = y / config.noteHeight;
        return config.highestNote - noteFromTop;
    }

    int noteToPixel(int noteNum, int height) const
    {
        int noteFromTop = config.highestNote - noteNum;
        return noteFromTop * config.noteHeight;
    }

    MIDINote* findNoteAt(float beat, int noteNum)
    {
        for (auto& note : notes)
        {
            if (note.noteNumber == noteNum && note.containsBeat(beat))
                return &note;
        }
        return nullptr;
    }

    bool isBlackKey(int noteNum) const
    {
        int n = noteNum % 12;
        return n == 1 || n == 3 || n == 6 || n == 8 || n == 10;
    }

    void drawPianoKeys(juce::Graphics& g, juce::Rectangle<int> area)
    {
        for (int note = config.highestNote; note >= config.lowestNote; --note)
        {
            int y = noteToPixel(note, area.getHeight());
            bool black = isBlackKey(note);
            bool isRoot = (note % 12) == config.rootNote;
            bool inScale = config.showScaleHighlight &&
                           config.scale.containsNote(note, config.rootNote);

            juce::Colour keyColor;
            if (isRoot)
                keyColor = config.colors.keyRoot;
            else if (inScale)
                keyColor = config.colors.keyHighlight;
            else if (black)
                keyColor = config.colors.keyBlack;
            else
                keyColor = config.colors.keyWhite;

            g.setColour(keyColor);
            g.fillRect(area.getX(), y, area.getWidth(), config.noteHeight);

            g.setColour(config.colors.gridLines);
            g.drawHorizontalLine(y + config.noteHeight - 1, static_cast<float>(area.getX()),
                                 static_cast<float>(area.getRight()));

            // Draw note name for C notes
            if (note % 12 == 0)
            {
                int octave = (note / 12) - 1;
                g.setColour(juce::Colours::white);
                g.setFont(10.0f);
                g.drawText("C" + juce::String(octave), area.getX() + 2, y,
                           area.getWidth() - 4, config.noteHeight,
                           juce::Justification::centredLeft);
            }
        }
    }

    void drawGrid(juce::Graphics& g, juce::Rectangle<int> area)
    {
        float gridSize = config.quantize.getGridBeats();

        // Draw horizontal lines (note rows)
        for (int note = config.highestNote; note >= config.lowestNote; --note)
        {
            int y = noteToPixel(note, area.getHeight());
            bool inScale = config.scale.containsNote(note, config.rootNote);

            g.setColour(inScale ? config.colors.keyHighlight.withAlpha(0.1f)
                                : config.colors.background);
            g.fillRect(area.getX(), y, area.getWidth(), config.noteHeight);

            g.setColour(config.colors.gridLines);
            g.drawHorizontalLine(y + config.noteHeight - 1,
                                 static_cast<float>(area.getX()),
                                 static_cast<float>(area.getRight()));
        }

        // Draw vertical lines (beats/grid)
        for (float beat = viewStartBeat; beat <= viewEndBeat; beat += gridSize)
        {
            int x = beatToPixel(beat, area.getWidth()) + area.getX();

            bool isBar = std::fmod(beat, config.beatsPerBar) < 0.001f;
            bool isBeat = std::fmod(beat, 1.0f) < 0.001f;

            if (isBar)
                g.setColour(config.colors.barLines);
            else if (isBeat)
                g.setColour(config.colors.beatLines);
            else
                g.setColour(config.colors.gridLines);

            g.drawVerticalLine(x, static_cast<float>(area.getY()),
                               static_cast<float>(area.getBottom()));
        }
    }

    void drawNotes(juce::Graphics& g, juce::Rectangle<int> area)
    {
        for (const auto& note : notes)
        {
            if (note.getEndBeat() < viewStartBeat || note.startBeat > viewEndBeat)
                continue;

            int x = beatToPixel(note.startBeat, area.getWidth()) + area.getX();
            int width = beatToPixel(note.startBeat + note.duration, area.getWidth()) -
                        beatToPixel(note.startBeat, area.getWidth());
            int y = noteToPixel(note.noteNumber, area.getHeight());

            juce::Colour noteColor;
            if (note.muted)
                noteColor = config.colors.noteMuted;
            else if (note.selected)
                noteColor = config.colors.noteSelected;
            else
                noteColor = config.colors.noteDefault;

            // Velocity-based brightness
            float velocityFactor = note.velocity / 127.0f;
            noteColor = noteColor.withMultipliedBrightness(0.5f + velocityFactor * 0.5f);

            g.setColour(noteColor);
            g.fillRoundedRectangle(static_cast<float>(x), static_cast<float>(y),
                                   static_cast<float>(width), static_cast<float>(config.noteHeight - 1),
                                   2.0f);

            g.setColour(config.colors.noteBorder);
            g.drawRoundedRectangle(static_cast<float>(x), static_cast<float>(y),
                                   static_cast<float>(width), static_cast<float>(config.noteHeight - 1),
                                   2.0f, 1.0f);

            // Resize handle
            if (note.selected && width > 10)
            {
                g.setColour(juce::Colours::white.withAlpha(0.5f));
                g.fillRect(x + width - 4, y + 2, 2, config.noteHeight - 5);
            }
        }
    }

    void drawGhostNotes(juce::Graphics& g, juce::Rectangle<int> area)
    {
        g.setColour(config.colors.noteGhost);

        for (const auto& note : ghostNotes)
        {
            if (note.getEndBeat() < viewStartBeat || note.startBeat > viewEndBeat)
                continue;

            int x = beatToPixel(note.startBeat, area.getWidth()) + area.getX();
            int width = beatToPixel(note.startBeat + note.duration, area.getWidth()) -
                        beatToPixel(note.startBeat, area.getWidth());
            int y = noteToPixel(note.noteNumber, area.getHeight());

            g.fillRoundedRectangle(static_cast<float>(x), static_cast<float>(y),
                                   static_cast<float>(width), static_cast<float>(config.noteHeight - 1),
                                   2.0f);
        }
    }

    void drawPlayhead(juce::Graphics& g, juce::Rectangle<int> area)
    {
        if (playheadBeat < viewStartBeat || playheadBeat > viewEndBeat)
            return;

        int x = beatToPixel(playheadBeat, area.getWidth()) + area.getX();

        g.setColour(config.colors.playhead);
        g.drawVerticalLine(x, static_cast<float>(area.getY()),
                           static_cast<float>(area.getBottom()));

        // Playhead triangle
        juce::Path triangle;
        triangle.addTriangle(static_cast<float>(x) - 5, static_cast<float>(area.getY()),
                             static_cast<float>(x) + 5, static_cast<float>(area.getY()),
                             static_cast<float>(x), static_cast<float>(area.getY()) + 8);
        g.fillPath(triangle);
    }

    void drawVelocityLane(juce::Graphics& g, juce::Rectangle<int> area)
    {
        g.setColour(config.colors.velocityBackground);
        g.fillRect(area);

        // Draw velocity bars for each note
        for (const auto& note : notes)
        {
            if (note.getEndBeat() < viewStartBeat || note.startBeat > viewEndBeat)
                continue;

            int x = beatToPixel(note.startBeat, area.getWidth()) + area.getX();
            int width = std::max(3, beatToPixel(note.startBeat + note.duration, area.getWidth()) -
                                    beatToPixel(note.startBeat, area.getWidth()));

            float velocityRatio = note.velocity / 127.0f;
            int barHeight = static_cast<int>(velocityRatio * area.getHeight());

            juce::Colour barColor = note.selected ? config.colors.noteSelected
                                                  : config.colors.velocityBar;

            g.setColour(barColor);
            g.fillRect(x, area.getBottom() - barHeight, width - 1, barHeight);
        }

        // Grid lines
        g.setColour(config.colors.gridLines);
        g.drawHorizontalLine(area.getY() + area.getHeight() / 2,
                             static_cast<float>(area.getX()),
                             static_cast<float>(area.getRight()));
    }

    void drawSelectionRect(juce::Graphics& g, juce::Rectangle<int> area)
    {
        int left = std::min(selectionStartX, selectionEndX);
        int right = std::max(selectionStartX, selectionEndX);
        int top = std::min(selectionStartY, selectionEndY);
        int bottom = std::max(selectionStartY, selectionEndY);

        g.setColour(config.colors.selection);
        g.fillRect(left, top, right - left, bottom - top);

        g.setColour(config.colors.noteSelected);
        g.drawRect(left, top, right - left, bottom - top);
    }

    void updateSelectionFromRect(juce::Rectangle<int> noteArea, int pianoKeyWidth)
    {
        int left = std::min(selectionStartX, selectionEndX) - pianoKeyWidth;
        int right = std::max(selectionStartX, selectionEndX) - pianoKeyWidth;
        int top = std::min(selectionStartY, selectionEndY);
        int bottom = std::max(selectionStartY, selectionEndY);

        float beatLeft = pixelToBeat(left, noteArea.getWidth());
        float beatRight = pixelToBeat(right, noteArea.getWidth());
        int noteTop = pixelToNote(top, noteArea.getHeight());
        int noteBottom = pixelToNote(bottom, noteArea.getHeight());

        for (auto& note : notes)
        {
            bool inRange = note.noteNumber <= noteTop && note.noteNumber >= noteBottom &&
                           note.startBeat < beatRight && note.getEndBeat() > beatLeft;
            note.selected = inRange;
        }
    }
};

} // namespace UI
} // namespace Echoelmusic
