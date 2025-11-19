#include "PianoRollView.h"

//==============================================================================
// Constants
//==============================================================================

namespace PianoRollConstants
{
    const int MIN_NOTE = 0;
    const int MAX_NOTE = 127;
    const int TOTAL_NOTES = 128;

    const int MIN_NOTE_HEIGHT = 4;
    const int MAX_NOTE_HEIGHT = 40;

    const double MIN_BEATS_PER_PIXEL = 0.01;
    const double MAX_BEATS_PER_PIXEL = 2.0;

    const juce::Colour GRID_COLOR = juce::Colour(0x33FFFFFF);
    const juce::Colour NOTE_COLOR = juce::Colour(0xFF4A90E2);
    const juce::Colour NOTE_SELECTED_COLOR = juce::Colour(0xFFFF9500);
    const juce::Colour PLAYHEAD_COLOR = juce::Colour(0xFFFF3B30);

    const juce::Colour WHITE_KEY_COLOR = juce::Colour(0xFFFAFAFA);
    const juce::Colour BLACK_KEY_COLOR = juce::Colour(0xFF2C2C2C);
    const juce::Colour KEY_BORDER_COLOR = juce::Colour(0xFF1A1A1A);
}

//==============================================================================
// Note Bounds Calculation
//==============================================================================

juce::Rectangle<float> PianoRollView::Note::getBounds(double beatsPerPixel, int noteHeight) const
{
    float x = static_cast<float>(startBeat / beatsPerPixel);
    float width = static_cast<float>(lengthBeats / beatsPerPixel);
    float y = (127 - noteNumber) * noteHeight;

    return juce::Rectangle<float>(x, y, width, static_cast<float>(noteHeight));
}

//==============================================================================
// Grid Quantization Values
//==============================================================================

double PianoRollView::GridConfig::getSnapValue() const
{
    if (!snapEnabled)
        return 0.0;

    switch (quantization)
    {
        case Quantization::None:        return 0.0;
        case Quantization::Bar:         return 4.0;
        case Quantization::Half:        return 2.0;
        case Quantization::Quarter:     return 1.0;
        case Quantization::Eighth:      return 0.5;
        case Quantization::Sixteenth:   return 0.25;
        case Quantization::ThirtySecond: return 0.125;
        case Quantization::Triplet:     return 1.0 / 3.0;
        case Quantization::Dotted:      return 1.5;
        default:                        return 0.25;
    }
}

//==============================================================================
// Constructor / Destructor
//==============================================================================

PianoRollView::PianoRollView()
{
    setOpaque(true);

    // Start timer for playhead animation (30 FPS)
    startTimer(33);

    DBG("PianoRollView: Initialized");
}

PianoRollView::~PianoRollView()
{
    stopTimer();
}

//==============================================================================
// Note Management
//==============================================================================

void PianoRollView::addNote(const Note& note)
{
    notes.add(note);

    if (onNoteAdded)
        onNoteAdded(note);

    repaint();
}

void PianoRollView::removeNote(int noteIndex)
{
    if (juce::isPositiveAndBelow(noteIndex, notes.size()))
    {
        notes.remove(noteIndex);

        if (onNoteRemoved)
            onNoteRemoved(noteIndex);

        repaint();
    }
}

juce::Array<PianoRollView::Note> PianoRollView::getAllNotes() const
{
    return notes;
}

void PianoRollView::setNotes(const juce::Array<Note>& newNotes)
{
    notes = newNotes;
    repaint();
}

void PianoRollView::clearNotes()
{
    notes.clear();
    repaint();
}

juce::Array<PianoRollView::Note*> PianoRollView::getSelectedNotes()
{
    juce::Array<Note*> selected;

    for (auto& note : notes)
    {
        if (note.isSelected)
            selected.add(&note);
    }

    return selected;
}

//==============================================================================
// Selection
//==============================================================================

void PianoRollView::selectNote(int noteIndex, bool addToSelection)
{
    if (!addToSelection)
        deselectAll();

    if (juce::isPositiveAndBelow(noteIndex, notes.size()))
    {
        notes.getReference(noteIndex).isSelected = true;
        repaint();
    }
}

void PianoRollView::deselectAll()
{
    for (auto& note : notes)
        note.isSelected = false;

    repaint();
}

void PianoRollView::selectAll()
{
    for (auto& note : notes)
        note.isSelected = true;

    if (onSelectionChanged)
        onSelectionChanged(getSelectedNotes());

    repaint();
}

void PianoRollView::deleteSelected()
{
    for (int i = notes.size() - 1; i >= 0; --i)
    {
        if (notes[i].isSelected)
        {
            removeNote(i);
        }
    }
}

//==============================================================================
// Editing
//==============================================================================

void PianoRollView::copySelected()
{
    clipboard.clear();

    for (const auto& note : notes)
    {
        if (note.isSelected)
            clipboard.add(note);
    }

    DBG("PianoRollView: Copied " << clipboard.size() << " notes");
}

void PianoRollView::paste()
{
    if (clipboard.isEmpty())
        return;

    deselectAll();

    // Find earliest note in clipboard
    double earliestBeat = std::numeric_limits<double>::max();
    for (const auto& note : clipboard)
        earliestBeat = std::min(earliestBeat, note.startBeat);

    // Paste at playhead position
    double offset = playheadBeat - earliestBeat;

    for (const auto& note : clipboard)
    {
        Note newNote = note;
        newNote.startBeat += offset;
        newNote.isSelected = true;
        addNote(newNote);
    }

    DBG("PianoRollView: Pasted " << clipboard.size() << " notes");
}

void PianoRollView::duplicateSelected()
{
    copySelected();

    if (clipboard.isEmpty())
        return;

    // Find rightmost note
    double rightmostEnd = 0.0;
    for (const auto& note : notes)
    {
        if (note.isSelected)
            rightmostEnd = std::max(rightmostEnd, note.startBeat + note.lengthBeats);
    }

    deselectAll();

    // Find earliest note in clipboard
    double earliestBeat = std::numeric_limits<double>::max();
    for (const auto& note : clipboard)
        earliestBeat = std::min(earliestBeat, note.startBeat);

    // Duplicate right after selection
    double offset = rightmostEnd - earliestBeat;

    for (const auto& note : clipboard)
    {
        Note newNote = note;
        newNote.startBeat += offset;
        newNote.isSelected = true;
        addNote(newNote);
    }
}

void PianoRollView::quantizeSelected()
{
    double snapValue = gridConfig.getSnapValue();

    if (snapValue == 0.0)
        return;

    for (auto& note : notes)
    {
        if (note.isSelected)
        {
            // Quantize start position
            double quantizedStart = std::round(note.startBeat / snapValue) * snapValue;
            note.startBeat = quantizedStart;

            // Optionally quantize length
            double quantizedLength = std::round(note.lengthBeats / snapValue) * snapValue;
            if (quantizedLength > 0.0)
                note.lengthBeats = quantizedLength;
        }
    }

    repaint();
}

void PianoRollView::transposeSelected(int semitones)
{
    for (auto& note : notes)
    {
        if (note.isSelected)
        {
            int newNote = juce::jlimit(0, 127, note.noteNumber + semitones);
            note.noteNumber = newNote;
        }
    }

    repaint();
}

void PianoRollView::setSelectedVelocity(float velocity)
{
    velocity = juce::jlimit(0.0f, 1.0f, velocity);

    for (auto& note : notes)
    {
        if (note.isSelected)
            note.velocity = velocity;
    }

    repaint();
}

//==============================================================================
// Zoom & View
//==============================================================================

void PianoRollView::setHorizontalZoom(double newBeatsPerPixel)
{
    beatsPerPixel = juce::jlimit(PianoRollConstants::MIN_BEATS_PER_PIXEL,
                                  PianoRollConstants::MAX_BEATS_PER_PIXEL,
                                  newBeatsPerPixel);
    repaint();
}

void PianoRollView::setVerticalZoom(int pixelsPerNote)
{
    noteHeight = juce::jlimit(PianoRollConstants::MIN_NOTE_HEIGHT,
                               PianoRollConstants::MAX_NOTE_HEIGHT,
                               pixelsPerNote);
    repaint();
}

void PianoRollView::zoomToFit()
{
    if (notes.isEmpty())
        return;

    // Find note range
    double minBeat = std::numeric_limits<double>::max();
    double maxBeat = 0.0;

    for (const auto& note : notes)
    {
        minBeat = std::min(minBeat, note.startBeat);
        maxBeat = std::max(maxBeat, note.startBeat + note.lengthBeats);
    }

    // Calculate zoom to fit
    int contentWidth = getWidth() - keyboardWidth - 20;
    double totalBeats = maxBeat - minBeat;

    if (totalBeats > 0.0)
    {
        beatsPerPixel = totalBeats / contentWidth;
        viewOffset.setX(minBeat);
    }

    repaint();
}

void PianoRollView::scrollToPosition(double beat)
{
    viewOffset.setX(beat);
    repaint();
}

//==============================================================================
// Grid
//==============================================================================

void PianoRollView::setGridConfig(const GridConfig& config)
{
    gridConfig = config;
    repaint();
}

void PianoRollView::toggleSnap()
{
    gridConfig.snapEnabled = !gridConfig.snapEnabled;
    DBG("PianoRollView: Snap " << (gridConfig.snapEnabled ? "ON" : "OFF"));
}

void PianoRollView::toggleGridVisibility()
{
    gridConfig.showGrid = !gridConfig.showGrid;
    repaint();
}

//==============================================================================
// Playback Integration
//==============================================================================

void PianoRollView::setPlayheadPosition(double beat)
{
    playheadBeat = beat;
    // Repaint will happen in timerCallback
}

void PianoRollView::setTempo(double bpm)
{
    tempo = bpm;
}

void PianoRollView::setTimeSignature(int numerator, int denominator)
{
    timeSignatureNumerator = numerator;
    timeSignatureDenominator = denominator;
}

//==============================================================================
// Piano Keyboard
//==============================================================================

void PianoRollView::setKeyboardWidth(int width)
{
    keyboardWidth = juce::jlimit(40, 200, width);
    resized();
}

void PianoRollView::highlightKeys(const juce::Array<int>& noteNumbers)
{
    // TODO: Store highlighted keys and draw differently
    repaint();
}

//==============================================================================
// Component Overrides - Paint
//==============================================================================

void PianoRollView::paint(juce::Graphics& g)
{
    auto bounds = getLocalBounds();

    // Background
    g.fillAll(juce::Colour(0xFF1E1E1E));

    // Split into keyboard and content area
    auto keyboardArea = bounds.removeFromLeft(keyboardWidth);
    auto contentArea = bounds;

    // Draw piano keyboard
    drawPianoKeyboard(g, keyboardArea);

    // Clip to content area
    g.saveState();
    g.reduceClipRegion(contentArea);

    // Translate for scroll offset
    g.addTransform(juce::AffineTransform::translation(
        -static_cast<float>(viewOffset.getX() / beatsPerPixel) + keyboardWidth,
        static_cast<float>(viewOffset.getY())
    ));

    // Draw grid
    if (gridConfig.showGrid)
        drawGrid(g, contentArea);

    // Draw notes
    drawNotes(g, contentArea);

    // Draw playhead
    drawPlayhead(g, contentArea);

    g.restoreState();
}

void PianoRollView::resized()
{
    // Nothing specific to resize
}

//==============================================================================
// Mouse Interaction
//==============================================================================

void PianoRollView::mouseDown(const juce::MouseEvent& e)
{
    auto position = e.position;

    // Check if clicking on keyboard
    if (position.getX() < keyboardWidth)
    {
        // Preview note
        int noteNumber = pixelToNoteNumber(position.getY());

        if (onPreviewNote)
            onPreviewNote(noteNumber);

        return;
    }

    // Convert to content coordinates
    position.setX(position.getX() - keyboardWidth + static_cast<float>(viewOffset.getX() / beatsPerPixel));
    position.setY(position.getY() - static_cast<float>(viewOffset.getY()));

    // Find note at position
    Note* clickedNote = findNoteAt(position);

    if (clickedNote != nullptr)
    {
        // Check if near edge (for resizing)
        bool isLeftEdge = false;
        if (isNearNoteEdge(*clickedNote, position, isLeftEdge))
        {
            currentEditMode = isLeftEdge ? EditMode::ResizingLeft : EditMode::ResizingRight;
            draggedNote = clickedNote;
        }
        else
        {
            // Moving note
            currentEditMode = EditMode::Moving;
            draggedNote = clickedNote;

            // Select note
            if (!e.mods.isShiftDown())
                deselectAll();

            clickedNote->isSelected = true;
        }

        dragStartPosition = position;
    }
    else
    {
        // Drawing new note or selecting
        if (e.mods.isAltDown() || e.mods.isCommandDown())
        {
            // Selection box
            currentEditMode = EditMode::Selecting;
            selectionBox = juce::Rectangle<float>(position, position);

            if (!e.mods.isShiftDown())
                deselectAll();
        }
        else
        {
            // Draw new note
            currentEditMode = EditMode::Drawing;

            double beat = snapBeat(pixelToBeat(position.getX()));
            int noteNumber = pixelToNoteNumber(position.getY());
            double length = gridConfig.getSnapValue();
            if (length == 0.0)
                length = 0.25;  // Default to 16th note

            Note newNote;
            newNote.noteNumber = noteNumber;
            newNote.startBeat = beat;
            newNote.lengthBeats = length;
            newNote.velocity = 0.8f;
            newNote.color = PianoRollConstants::NOTE_COLOR;
            newNote.isSelected = true;

            addNote(newNote);
            draggedNote = &notes.getReference(notes.size() - 1);
            currentEditMode = EditMode::ResizingRight;
        }
    }

    repaint();
}

void PianoRollView::mouseDrag(const juce::MouseEvent& e)
{
    auto position = e.position;
    position.setX(position.getX() - keyboardWidth + static_cast<float>(viewOffset.getX() / beatsPerPixel));
    position.setY(position.getY() - static_cast<float>(viewOffset.getY()));

    if (currentEditMode == EditMode::Moving && draggedNote != nullptr)
    {
        // Move note
        double deltaBeat = pixelToBeat(position.getX()) - pixelToBeat(dragStartPosition.getX());
        int deltaNote = pixelToNoteNumber(position.getY()) - pixelToNoteNumber(dragStartPosition.getY());

        for (auto& note : notes)
        {
            if (note.isSelected)
            {
                note.startBeat = snapBeat(note.startBeat + deltaBeat);
                note.noteNumber = juce::jlimit(0, 127, note.noteNumber + deltaNote);
            }
        }

        dragStartPosition = position;
        repaint();
    }
    else if (currentEditMode == EditMode::ResizingRight && draggedNote != nullptr)
    {
        // Resize note end
        double newEnd = snapBeat(pixelToBeat(position.getX()));
        double newLength = newEnd - draggedNote->startBeat;

        if (newLength > 0.0)
            draggedNote->lengthBeats = newLength;

        repaint();
    }
    else if (currentEditMode == EditMode::ResizingLeft && draggedNote != nullptr)
    {
        // Resize note start
        double newStart = snapBeat(pixelToBeat(position.getX()));
        double oldEnd = draggedNote->startBeat + draggedNote->lengthBeats;

        if (newStart < oldEnd)
        {
            draggedNote->startBeat = newStart;
            draggedNote->lengthBeats = oldEnd - newStart;
        }

        repaint();
    }
    else if (currentEditMode == EditMode::Selecting)
    {
        // Update selection box
        selectionBox = juce::Rectangle<float>(dragStartPosition, position);

        // Select notes in box
        for (auto& note : notes)
        {
            auto noteBounds = note.getBounds(beatsPerPixel, noteHeight);
            note.isSelected = selectionBox.intersects(noteBounds);
        }

        repaint();
    }
}

void PianoRollView::mouseUp(const juce::MouseEvent& e)
{
    currentEditMode = EditMode::None;
    draggedNote = nullptr;
    selectionBox = juce::Rectangle<float>();

    repaint();
}

void PianoRollView::mouseDoubleClick(const juce::MouseEvent& e)
{
    auto position = e.position;
    position.setX(position.getX() - keyboardWidth + static_cast<float>(viewOffset.getX() / beatsPerPixel));
    position.setY(position.getY() - static_cast<float>(viewOffset.getY()));

    // Find note and delete it
    Note* clickedNote = findNoteAt(position);

    if (clickedNote != nullptr)
    {
        for (int i = 0; i < notes.size(); ++i)
        {
            if (&notes.getReference(i) == clickedNote)
            {
                removeNote(i);
                break;
            }
        }
    }
}

void PianoRollView::mouseWheelMove(const juce::MouseEvent& e, const juce::MouseWheelDetails& wheel)
{
    if (e.mods.isCommandDown())
    {
        // Horizontal zoom
        double factor = 1.0 + wheel.deltaY;
        setHorizontalZoom(beatsPerPixel * factor);
    }
    else if (e.mods.isShiftDown())
    {
        // Vertical zoom
        int delta = static_cast<int>(wheel.deltaY * 2);
        setVerticalZoom(noteHeight + delta);
    }
    else
    {
        // Scroll
        viewOffset.addXY(wheel.deltaX * 50.0, wheel.deltaY * 50.0);
        repaint();
    }
}

//==============================================================================
// ChangeListener
//==============================================================================

void PianoRollView::changeListenerCallback(juce::ChangeBroadcaster* source)
{
    // Handle external changes (e.g., from MIDI engine)
    repaint();
}

//==============================================================================
// Timer (Playhead Animation)
//==============================================================================

void PianoRollView::timerCallback()
{
    // Repaint for playhead animation
    repaint();
}

//==============================================================================
// Helper Methods - Conversion
//==============================================================================

double PianoRollView::pixelToBeat(float x) const
{
    return x * beatsPerPixel + viewOffset.getX();
}

float PianoRollView::beatToPixel(double beat) const
{
    return static_cast<float>((beat - viewOffset.getX()) / beatsPerPixel);
}

int PianoRollView::pixelToNoteNumber(float y) const
{
    int noteFromTop = static_cast<int>((y - viewOffset.getY()) / noteHeight);
    return juce::jlimit(0, 127, 127 - noteFromTop);
}

float PianoRollView::noteNumberToPixel(int noteNumber) const
{
    return (127 - noteNumber) * noteHeight + static_cast<float>(viewOffset.getY());
}

double PianoRollView::snapBeat(double beat) const
{
    double snapValue = gridConfig.getSnapValue();

    if (snapValue == 0.0 || !gridConfig.snapEnabled)
        return beat;

    return std::round(beat / snapValue) * snapValue;
}

//==============================================================================
// Helper Methods - Note Finding
//==============================================================================

PianoRollView::Note* PianoRollView::findNoteAt(const juce::Point<float>& position)
{
    for (auto& note : notes)
    {
        auto bounds = note.getBounds(beatsPerPixel, noteHeight);

        if (bounds.contains(position))
            return &note;
    }

    return nullptr;
}

bool PianoRollView::isNearNoteEdge(const Note& note, const juce::Point<float>& position, bool& isLeftEdge)
{
    auto bounds = note.getBounds(beatsPerPixel, noteHeight);

    const float edgeThreshold = 5.0f;

    if (std::abs(position.getX() - bounds.getX()) < edgeThreshold)
    {
        isLeftEdge = true;
        return true;
    }

    if (std::abs(position.getX() - bounds.getRight()) < edgeThreshold)
    {
        isLeftEdge = false;
        return true;
    }

    return false;
}

//==============================================================================
// Drawing - Piano Keyboard
//==============================================================================

void PianoRollView::drawPianoKeyboard(juce::Graphics& g, juce::Rectangle<int> area)
{
    g.setColour(PianoRollConstants::KEY_BORDER_COLOR);
    g.fillRect(area);

    for (int note = 0; note < 128; ++note)
    {
        float y = noteNumberToPixel(note);
        float height = static_cast<float>(noteHeight);

        juce::Rectangle<float> keyRect(
            static_cast<float>(area.getX()),
            y,
            static_cast<float>(area.getWidth()),
            height
        );

        // Clip to visible area
        if (!area.toFloat().intersects(keyRect))
            continue;

        // Draw key
        bool isBlack = isBlackKey(note);
        g.setColour(isBlack ? PianoRollConstants::BLACK_KEY_COLOR : PianoRollConstants::WHITE_KEY_COLOR);
        g.fillRect(keyRect);

        // Border
        g.setColour(PianoRollConstants::KEY_BORDER_COLOR);
        g.drawRect(keyRect, 1.0f);

        // Note name (for C notes)
        if (note % 12 == 0 && noteHeight > 10)
        {
            g.setColour(juce::Colours::grey);
            g.setFont(10.0f);
            g.drawText(getNoteName(note), keyRect.reduced(2), juce::Justification::centredLeft);
        }
    }
}

//==============================================================================
// Drawing - Grid
//==============================================================================

void PianoRollView::drawGrid(juce::Graphics& g, juce::Rectangle<int> area)
{
    g.setColour(PianoRollConstants::GRID_COLOR);

    double snapValue = gridConfig.getSnapValue();
    if (snapValue == 0.0)
        snapValue = 1.0;  // Default to quarter notes

    // Vertical grid lines (beats)
    double startBeat = std::floor(viewOffset.getX() / snapValue) * snapValue;
    double endBeat = viewOffset.getX() + area.getWidth() * beatsPerPixel;

    for (double beat = startBeat; beat < endBeat; beat += snapValue)
    {
        float x = beatToPixel(beat) + keyboardWidth;

        // Highlight bar lines
        bool isBarLine = (std::fmod(beat, static_cast<double>(timeSignatureNumerator)) == 0.0);

        if (isBarLine)
            g.setColour(PianoRollConstants::GRID_COLOR.brighter(0.3f));
        else
            g.setColour(PianoRollConstants::GRID_COLOR);

        g.drawVerticalLine(static_cast<int>(x), 0.0f, static_cast<float>(area.getHeight()));
    }

    // Horizontal grid lines (octaves)
    g.setColour(PianoRollConstants::GRID_COLOR);

    for (int note = 0; note < 128; note += 12)
    {
        float y = noteNumberToPixel(note);
        g.drawHorizontalLine(static_cast<int>(y), 0.0f, static_cast<float>(area.getWidth()));
    }
}

//==============================================================================
// Drawing - Notes
//==============================================================================

void PianoRollView::drawNotes(juce::Graphics& g, juce::Rectangle<int> area)
{
    for (const auto& note : notes)
    {
        auto bounds = note.getBounds(beatsPerPixel, noteHeight);
        bounds.translate(keyboardWidth, 0.0f);

        // Clip to visible area
        if (!area.toFloat().intersects(bounds))
            continue;

        // Note color
        juce::Colour noteColor = note.isSelected ?
            PianoRollConstants::NOTE_SELECTED_COLOR :
            note.color;

        // Fade based on velocity
        noteColor = noteColor.withAlpha(0.6f + note.velocity * 0.4f);

        // Draw note
        g.setColour(noteColor);
        g.fillRoundedRectangle(bounds.reduced(1.0f), 2.0f);

        // Border
        g.setColour(noteColor.brighter(0.2f));
        g.drawRoundedRectangle(bounds.reduced(1.0f), 2.0f, 1.0f);
    }
}

//==============================================================================
// Drawing - Playhead
//==============================================================================

void PianoRollView::drawPlayhead(juce::Graphics& g, juce::Rectangle<int> area)
{
    float x = beatToPixel(playheadBeat) + keyboardWidth;

    g.setColour(PianoRollConstants::PLAYHEAD_COLOR);
    g.drawVerticalLine(static_cast<int>(x), 0.0f, static_cast<float>(area.getHeight()));
}

//==============================================================================
// Helper Methods - Music Theory
//==============================================================================

bool PianoRollView::isBlackKey(int noteNumber) const
{
    int noteInOctave = noteNumber % 12;
    return (noteInOctave == 1 || noteInOctave == 3 || noteInOctave == 6 || noteInOctave == 8 || noteInOctave == 10);
}

juce::String PianoRollView::getNoteName(int noteNumber) const
{
    const char* noteNames[] = { "C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B" };
    int octave = (noteNumber / 12) - 1;
    int noteInOctave = noteNumber % 12;

    return juce::String(noteNames[noteInOctave]) + juce::String(octave);
}
