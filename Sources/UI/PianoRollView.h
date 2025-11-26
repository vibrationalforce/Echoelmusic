#pragma once

#include <JuceHeader.h>
#include <memory>
#include <functional>

/**
 * PianoRollView - Professional MIDI Note Editor
 *
 * Full-featured piano roll for MIDI composition and editing.
 *
 * Features:
 * - Visual note editing (add, remove, resize, move)
 * - Piano keyboard on left side
 * - Grid with configurable quantization
 * - Velocity editor
 * - Multi-note selection
 * - Copy/paste/duplicate
 * - Snap-to-grid
 * - Zoom (horizontal & vertical)
 * - Playhead following
 * - MIDI-MPE support (per-note expression)
 *
 * Inspiration:
 * - Ableton Live Piano Roll
 * - FL Studio Piano Roll
 * - Logic Pro Piano Roll
 * - Bitwig Grid Editor
 *
 * Use Cases:
 * - Compose melodies and chords
 * - Edit recorded MIDI
 * - Create drum patterns
 * - Fine-tune timing and velocity
 */
class PianoRollView : public juce::Component,
                      public juce::ChangeListener,
                      public juce::Timer
{
public:
    //==========================================================================
    // MIDI Note Structure
    //==========================================================================

    struct Note
    {
        int noteNumber;         // 0-127 (MIDI note number)
        double startBeat;       // Position in beats
        double lengthBeats;     // Length in beats
        float velocity;         // 0.0-1.0

        // MPE/Expression (optional)
        float pressure = 0.0f;  // 0.0-1.0
        float pitchBend = 0.0f; // -1.0 to +1.0
        float timbre = 0.0f;    // 0.0-1.0

        juce::Colour color;     // Note color
        bool isSelected = false;

        juce::Rectangle<float> getBounds(double beatsPerPixel, int noteHeight) const;
    };

    //==========================================================================
    // Grid Settings
    //==========================================================================

    struct GridConfig
    {
        enum class Quantization
        {
            None,
            Bar,            // 4 beats
            Half,           // 2 beats
            Quarter,        // 1 beat
            Eighth,         // 0.5 beats
            Sixteenth,      // 0.25 beats
            ThirtySecond,   // 0.125 beats
            Triplet,        // 1/3 beat
            Dotted          // 1.5 beats
        };

        Quantization quantization = Quantization::Sixteenth;
        bool snapEnabled = true;
        bool showGrid = true;

        double getSnapValue() const;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    PianoRollView();
    ~PianoRollView() override;

    //==========================================================================
    // Note Management
    //==========================================================================

    /** Add note */
    void addNote(const Note& note);

    /** Remove note */
    void removeNote(int noteIndex);

    /** Get all notes */
    juce::Array<Note> getAllNotes() const;

    /** Set all notes (replace) */
    void setNotes(const juce::Array<Note>& notes);

    /** Clear all notes */
    void clearNotes();

    /** Get selected notes */
    juce::Array<Note*> getSelectedNotes();

    //==========================================================================
    // Selection
    //==========================================================================

    /** Select note */
    void selectNote(int noteIndex, bool addToSelection = false);

    /** Deselect all */
    void deselectAll();

    /** Select all */
    void selectAll();

    /** Delete selected */
    void deleteSelected();

    //==========================================================================
    // Editing
    //==========================================================================

    /** Copy selected notes */
    void copySelected();

    /** Paste notes */
    void paste();

    /** Duplicate selected */
    void duplicateSelected();

    /** Quantize selected notes */
    void quantizeSelected();

    /** Transpose selected notes */
    void transposeSelected(int semitones);

    /** Set velocity of selected notes */
    void setSelectedVelocity(float velocity);

    //==========================================================================
    // Zoom & View
    //==========================================================================

    /** Set horizontal zoom (beats per pixel) */
    void setHorizontalZoom(double beatsPerPixel);

    /** Set vertical zoom (pixels per note) */
    void setVerticalZoom(int pixelsPerNote);

    /** Get horizontal zoom */
    double getHorizontalZoom() const { return beatsPerPixel; }

    /** Get vertical zoom */
    int getVerticalZoom() const { return noteHeight; }

    /** Zoom to fit all notes */
    void zoomToFit();

    /** Scroll to position */
    void scrollToPosition(double beat);

    //==========================================================================
    // Grid
    //==========================================================================

    /** Set grid configuration */
    void setGridConfig(const GridConfig& config);

    /** Get grid configuration */
    GridConfig getGridConfig() const { return gridConfig; }

    /** Toggle snap */
    void toggleSnap();

    /** Toggle grid visibility */
    void toggleGridVisibility();

    //==========================================================================
    // Playback Integration
    //==========================================================================

    /** Set playhead position (in beats) */
    void setPlayheadPosition(double beat);

    /** Get playhead position */
    double getPlayheadPosition() const { return playheadBeat; }

    /** Set tempo (for time display) */
    void setTempo(double bpm);

    /** Set time signature */
    void setTimeSignature(int numerator, int denominator);

    //==========================================================================
    // Piano Keyboard
    //==========================================================================

    /** Set keyboard width */
    void setKeyboardWidth(int width);

    /** Get keyboard width */
    int getKeyboardWidth() const { return keyboardWidth; }

    /** Highlight keys (for chord display) */
    void highlightKeys(const juce::Array<int>& noteNumbers);

    //==========================================================================
    // Callbacks
    //==========================================================================

    std::function<void(const Note& note)> onNoteAdded;
    std::function<void(int noteIndex)> onNoteRemoved;
    std::function<void(const Note& note)> onNoteChanged;
    std::function<void(const juce::Array<Note>&)> onSelectionChanged;
    std::function<void(int noteNumber)> onPreviewNote;  // For auditioning

    //==========================================================================
    // Component Overrides
    //==========================================================================

    void paint(juce::Graphics& g) override;
    void resized() override;

    void mouseDown(const juce::MouseEvent& e) override;
    void mouseDrag(const juce::MouseEvent& e) override;
    void mouseUp(const juce::MouseEvent& e) override;
    void mouseDoubleClick(const juce::MouseEvent& e) override;
    void mouseWheelMove(const juce::MouseEvent& e, const juce::MouseWheelDetails& wheel) override;

    //==========================================================================
    // ChangeListener
    //==========================================================================

    void changeListenerCallback(juce::ChangeBroadcaster* source) override;

    //==========================================================================
    // Timer (for playhead animation)
    //==========================================================================

    void timerCallback() override;

private:
    //==========================================================================
    // Note Storage
    //==========================================================================

    juce::Array<Note> notes;
    juce::Array<Note> clipboard;

    //==========================================================================
    // View State
    //==========================================================================

    double beatsPerPixel = 0.1;     // Horizontal zoom
    int noteHeight = 12;             // Vertical zoom (pixels per note)
    int keyboardWidth = 80;          // Piano keyboard width

    juce::Point<double> viewOffset { 0.0, 0.0 };  // Scroll position

    //==========================================================================
    // Grid
    //==========================================================================

    GridConfig gridConfig;

    //==========================================================================
    // Playback
    //==========================================================================

    double playheadBeat = 0.0;
    double tempo = 120.0;
    int timeSignatureNumerator = 4;
    int timeSignatureDenominator = 4;

    //==========================================================================
    // Editing State
    //==========================================================================

    enum class EditMode
    {
        None,
        Drawing,        // Adding new notes
        Selecting,      // Dragging selection box
        Moving,         // Moving notes
        ResizingLeft,   // Resizing note start
        ResizingRight   // Resizing note end
    };

    EditMode currentEditMode = EditMode::None;
    juce::Point<float> dragStartPosition;
    juce::Rectangle<float> selectionBox;

    Note* hoveredNote = nullptr;
    Note* draggedNote = nullptr;

    //==========================================================================
    // Helper Methods
    //==========================================================================

    /** Convert pixel position to beat */
    double pixelToBeat(float x) const;

    /** Convert beat to pixel position */
    float beatToPixel(double beat) const;

    /** Convert pixel Y to note number */
    int pixelToNoteNumber(float y) const;

    /** Convert note number to pixel Y */
    float noteNumberToPixel(int noteNumber) const;

    /** Snap beat to grid */
    double snapBeat(double beat) const;

    /** Find note at position */
    Note* findNoteAt(const juce::Point<float>& position);

    /** Check if dragging note edge */
    bool isNearNoteEdge(const Note& note, const juce::Point<float>& position, bool& isLeftEdge);

    /** Draw piano keyboard */
    void drawPianoKeyboard(juce::Graphics& g, juce::Rectangle<int> area);

    /** Draw grid */
    void drawGrid(juce::Graphics& g, juce::Rectangle<int> area);

    /** Draw notes */
    void drawNotes(juce::Graphics& g, juce::Rectangle<int> area);

    /** Draw playhead */
    void drawPlayhead(juce::Graphics& g, juce::Rectangle<int> area);

    /** Is black key? */
    bool isBlackKey(int noteNumber) const;

    /** Get note name */
    juce::String getNoteName(int noteNumber) const;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(PianoRollView)
};
