#pragma once

#include <JuceHeader.h>
#include <algorithm>
#include <array>
#include <cmath>
#include <functional>
#include <map>
#include <vector>

namespace Echoelmusic {

/**
 * QuantizationEngine - Complete MIDI and Audio Quantization System
 *
 * Features:
 * - MIDI note quantization (start time and length)
 * - Grid-based snapping
 * - Groove templates (swing, shuffle, humanize)
 * - Strength control (0-100%)
 * - Multiple grid values (1/1 to 1/64, triplets, dotted)
 * - Iterative quantization
 * - Audio transient quantization
 * - Real-time input quantization
 * - Undo-friendly non-destructive mode
 */

//==============================================================================
// Grid Values
//==============================================================================

enum class GridValue
{
    Bar_1,          // Whole note / bar
    Half,           // 1/2
    Quarter,        // 1/4
    Eighth,         // 1/8
    Sixteenth,      // 1/16
    ThirtySecond,   // 1/32
    SixtyFourth,    // 1/64

    // Triplets
    HalfTriplet,
    QuarterTriplet,
    EighthTriplet,
    SixteenthTriplet,
    ThirtySecondTriplet,

    // Dotted
    HalfDotted,
    QuarterDotted,
    EighthDotted,
    SixteenthDotted
};

inline double getGridValueInBeats(GridValue grid)
{
    switch (grid)
    {
        case GridValue::Bar_1:              return 4.0;
        case GridValue::Half:               return 2.0;
        case GridValue::Quarter:            return 1.0;
        case GridValue::Eighth:             return 0.5;
        case GridValue::Sixteenth:          return 0.25;
        case GridValue::ThirtySecond:       return 0.125;
        case GridValue::SixtyFourth:        return 0.0625;

        case GridValue::HalfTriplet:        return 4.0 / 3.0;
        case GridValue::QuarterTriplet:     return 2.0 / 3.0;
        case GridValue::EighthTriplet:      return 1.0 / 3.0;
        case GridValue::SixteenthTriplet:   return 0.5 / 3.0;
        case GridValue::ThirtySecondTriplet: return 0.25 / 3.0;

        case GridValue::HalfDotted:         return 3.0;
        case GridValue::QuarterDotted:      return 1.5;
        case GridValue::EighthDotted:       return 0.75;
        case GridValue::SixteenthDotted:    return 0.375;

        default: return 1.0;
    }
}

inline juce::String getGridValueName(GridValue grid)
{
    switch (grid)
    {
        case GridValue::Bar_1:              return "1/1 (Bar)";
        case GridValue::Half:               return "1/2";
        case GridValue::Quarter:            return "1/4";
        case GridValue::Eighth:             return "1/8";
        case GridValue::Sixteenth:          return "1/16";
        case GridValue::ThirtySecond:       return "1/32";
        case GridValue::SixtyFourth:        return "1/64";

        case GridValue::HalfTriplet:        return "1/2T";
        case GridValue::QuarterTriplet:     return "1/4T";
        case GridValue::EighthTriplet:      return "1/8T";
        case GridValue::SixteenthTriplet:   return "1/16T";
        case GridValue::ThirtySecondTriplet: return "1/32T";

        case GridValue::HalfDotted:         return "1/2.";
        case GridValue::QuarterDotted:      return "1/4.";
        case GridValue::EighthDotted:       return "1/8.";
        case GridValue::SixteenthDotted:    return "1/16.";

        default: return "1/4";
    }
}

//==============================================================================
// Quantization Mode
//==============================================================================

enum class QuantizeMode
{
    NoteStart,          // Quantize note start only
    NoteEnd,            // Quantize note end only
    NoteStartAndEnd,    // Quantize both start and end
    NoteLength,         // Quantize to fixed lengths
    NoteStartAndLength  // Quantize start, then apply fixed length
};

//==============================================================================
// Groove Template
//==============================================================================

struct GrooveTemplate
{
    juce::String name = "Straight";

    // Timing offsets for each grid position (in percentage of grid, -50 to +50)
    std::vector<float> timingOffsets;

    // Velocity scaling for each grid position (0.5 to 1.5)
    std::vector<float> velocityScales;

    // Duration scaling for each grid position (0.5 to 1.5)
    std::vector<float> durationScales;

    int gridDivisions = 16;  // How many positions per bar

    static GrooveTemplate createStraight()
    {
        GrooveTemplate t;
        t.name = "Straight";
        t.gridDivisions = 16;
        t.timingOffsets.resize(16, 0.0f);
        t.velocityScales.resize(16, 1.0f);
        t.durationScales.resize(16, 1.0f);
        return t;
    }

    static GrooveTemplate createSwing(float amount = 60.0f)
    {
        GrooveTemplate t;
        t.name = "Swing " + juce::String(static_cast<int>(amount)) + "%";
        t.gridDivisions = 16;
        t.timingOffsets.resize(16, 0.0f);
        t.velocityScales.resize(16, 1.0f);
        t.durationScales.resize(16, 1.0f);

        // Swing: delay every other 16th note
        float swingOffset = (amount - 50.0f) * 0.5f;
        for (int i = 1; i < 16; i += 2)
        {
            t.timingOffsets[i] = swingOffset;
        }

        return t;
    }

    static GrooveTemplate createShuffle()
    {
        GrooveTemplate t;
        t.name = "Shuffle";
        t.gridDivisions = 12;  // Triplet-based
        t.timingOffsets.resize(12, 0.0f);
        t.velocityScales.resize(12, 1.0f);
        t.durationScales.resize(12, 1.0f);

        // Triplet shuffle pattern
        for (int i = 0; i < 12; i += 3)
        {
            t.velocityScales[i] = 1.2f;      // Downbeat accent
            t.velocityScales[i + 2] = 0.9f;  // Upbeat slightly softer
        }

        return t;
    }

    static GrooveTemplate createHumanize(float amount = 10.0f)
    {
        GrooveTemplate t;
        t.name = "Humanize";
        t.gridDivisions = 16;
        t.timingOffsets.resize(16);
        t.velocityScales.resize(16);
        t.durationScales.resize(16);

        // Random but repeatable humanization
        std::srand(42);
        for (int i = 0; i < 16; ++i)
        {
            t.timingOffsets[i] = ((std::rand() % 100) / 100.0f - 0.5f) * amount;
            t.velocityScales[i] = 1.0f + ((std::rand() % 100) / 100.0f - 0.5f) * (amount / 50.0f);
            t.durationScales[i] = 1.0f + ((std::rand() % 100) / 100.0f - 0.5f) * (amount / 100.0f);
        }

        return t;
    }

    static GrooveTemplate createMPC60()
    {
        GrooveTemplate t;
        t.name = "MPC 60";
        t.gridDivisions = 16;
        t.timingOffsets.resize(16, 0.0f);
        t.velocityScales.resize(16, 1.0f);
        t.durationScales.resize(16, 1.0f);

        // Classic MPC 60 swing feel
        t.timingOffsets = {0, 12, 0, 10, 0, 14, 0, 8, 0, 12, 0, 10, 0, 14, 0, 8};
        t.velocityScales = {1.1f, 0.9f, 1.05f, 0.95f, 1.1f, 0.9f, 1.05f, 0.95f,
                           1.1f, 0.9f, 1.05f, 0.95f, 1.1f, 0.9f, 1.05f, 0.95f};

        return t;
    }
};

//==============================================================================
// MIDI Note for Quantization
//==============================================================================

struct QuantizableNote
{
    int noteNumber = 60;
    int velocity = 100;
    double startBeat = 0.0;     // Position in beats
    double lengthBeats = 1.0;   // Duration in beats
    int channel = 1;

    // Original values (for undo/non-destructive)
    double originalStartBeat = 0.0;
    double originalLengthBeats = 1.0;
    int originalVelocity = 100;

    // Quantization result
    bool wasQuantized = false;
    double quantizationOffset = 0.0;

    void storeOriginal()
    {
        originalStartBeat = startBeat;
        originalLengthBeats = lengthBeats;
        originalVelocity = velocity;
    }

    void restoreOriginal()
    {
        startBeat = originalStartBeat;
        lengthBeats = originalLengthBeats;
        velocity = originalVelocity;
        wasQuantized = false;
    }

    double endBeat() const { return startBeat + lengthBeats; }
};

//==============================================================================
// Quantization Settings
//==============================================================================

struct QuantizationSettings
{
    GridValue gridValue = GridValue::Sixteenth;
    QuantizeMode mode = QuantizeMode::NoteStart;

    float strength = 100.0f;        // 0-100%
    float lengthStrength = 100.0f;  // For length quantization

    bool quantizeToNearest = true;  // vs. quantize forward only
    bool useGroove = false;
    GrooveTemplate groove;

    // Swing shortcut (overrides groove if > 50)
    float swingPercent = 50.0f;     // 50 = no swing, 67 = 2:1 swing

    // Range filter
    bool useRange = false;
    double rangeStartBeat = 0.0;
    double rangeEndBeat = 0.0;

    // Velocity filter
    bool useVelocityFilter = false;
    int minVelocity = 0;
    int maxVelocity = 127;

    // Note filter
    bool useNoteFilter = false;
    int minNote = 0;
    int maxNote = 127;
};

//==============================================================================
// Quantization Engine
//==============================================================================

class QuantizationEngine
{
public:
    QuantizationEngine() = default;

    //==========================================================================
    // Main Quantization Functions
    //==========================================================================

    /** Quantize a single note */
    QuantizableNote quantizeNote(QuantizableNote note, const QuantizationSettings& settings) const
    {
        // Store original for undo
        note.storeOriginal();

        // Check filters
        if (!passesFilters(note, settings))
            return note;

        double gridSize = getGridValueInBeats(settings.gridValue);

        // Apply swing if needed
        double swingOffset = 0.0;
        if (settings.swingPercent != 50.0f)
        {
            swingOffset = calculateSwingOffset(note.startBeat, gridSize, settings.swingPercent);
        }
        else if (settings.useGroove)
        {
            swingOffset = calculateGrooveOffset(note.startBeat, settings.groove);
        }

        switch (settings.mode)
        {
            case QuantizeMode::NoteStart:
                quantizeNoteStart(note, gridSize, settings.strength, swingOffset, settings.quantizeToNearest);
                break;

            case QuantizeMode::NoteEnd:
                quantizeNoteEnd(note, gridSize, settings.strength, swingOffset, settings.quantizeToNearest);
                break;

            case QuantizeMode::NoteStartAndEnd:
                quantizeNoteStart(note, gridSize, settings.strength, swingOffset, settings.quantizeToNearest);
                quantizeNoteEnd(note, gridSize, settings.lengthStrength, swingOffset, settings.quantizeToNearest);
                break;

            case QuantizeMode::NoteLength:
                quantizeNoteLength(note, gridSize, settings.lengthStrength);
                break;

            case QuantizeMode::NoteStartAndLength:
                quantizeNoteStart(note, gridSize, settings.strength, swingOffset, settings.quantizeToNearest);
                quantizeNoteLength(note, gridSize, settings.lengthStrength);
                break;
        }

        // Apply groove velocity if enabled
        if (settings.useGroove)
        {
            float velScale = getGrooveVelocityScale(note.startBeat, settings.groove);
            note.velocity = juce::jlimit(1, 127, static_cast<int>(note.velocity * velScale));
        }

        note.wasQuantized = true;
        return note;
    }

    /** Quantize a vector of notes */
    std::vector<QuantizableNote> quantizeNotes(std::vector<QuantizableNote> notes,
                                                const QuantizationSettings& settings) const
    {
        for (auto& note : notes)
        {
            note = quantizeNote(note, settings);
        }
        return notes;
    }

    /** Quantize notes in place */
    void quantizeNotesInPlace(std::vector<QuantizableNote>& notes,
                              const QuantizationSettings& settings) const
    {
        for (auto& note : notes)
        {
            note = quantizeNote(note, settings);
        }
    }

    //==========================================================================
    // Grid Snapping
    //==========================================================================

    /** Snap a position to the grid */
    double snapToGrid(double positionBeats, GridValue grid, bool snapToNearest = true) const
    {
        double gridSize = getGridValueInBeats(grid);
        return snapToGridSize(positionBeats, gridSize, snapToNearest);
    }

    /** Snap with custom grid size */
    double snapToGridSize(double positionBeats, double gridSize, bool snapToNearest = true) const
    {
        if (snapToNearest)
        {
            return std::round(positionBeats / gridSize) * gridSize;
        }
        else
        {
            // Snap forward only
            return std::ceil(positionBeats / gridSize) * gridSize;
        }
    }

    /** Get nearest grid position */
    double getNearestGridPosition(double positionBeats, GridValue grid) const
    {
        return snapToGrid(positionBeats, grid, true);
    }

    /** Get previous grid position */
    double getPreviousGridPosition(double positionBeats, GridValue grid) const
    {
        double gridSize = getGridValueInBeats(grid);
        return std::floor(positionBeats / gridSize) * gridSize;
    }

    /** Get next grid position */
    double getNextGridPosition(double positionBeats, GridValue grid) const
    {
        double gridSize = getGridValueInBeats(grid);
        return std::ceil(positionBeats / gridSize) * gridSize;
    }

    //==========================================================================
    // Real-time Input Quantization
    //==========================================================================

    /** Quantize incoming MIDI note in real-time */
    double quantizeInputTime(double inputTimeBeats, GridValue grid, double lookaheadBeats = 0.1) const
    {
        double gridSize = getGridValueInBeats(grid);

        double prevGrid = std::floor(inputTimeBeats / gridSize) * gridSize;
        double nextGrid = prevGrid + gridSize;

        double distToPrev = inputTimeBeats - prevGrid;
        double distToNext = nextGrid - inputTimeBeats;

        // If within lookahead of next grid, snap forward
        if (distToNext <= lookaheadBeats)
        {
            return nextGrid;
        }
        // If very close to previous grid, snap back
        else if (distToPrev <= lookaheadBeats)
        {
            return prevGrid;
        }

        // Otherwise return input time (no quantization)
        return inputTimeBeats;
    }

    //==========================================================================
    // Iterative Quantization
    //==========================================================================

    /** Apply partial quantization (for iterative approach) */
    QuantizableNote iterativeQuantize(QuantizableNote note, const QuantizationSettings& settings,
                                       int iterations, int currentIteration) const
    {
        // Calculate effective strength for this iteration
        float iterationStrength = settings.strength * (static_cast<float>(currentIteration + 1) / iterations);

        QuantizationSettings iterSettings = settings;
        iterSettings.strength = iterationStrength;

        return quantizeNote(note, iterSettings);
    }

    //==========================================================================
    // Groove Templates
    //==========================================================================

    /** Get available groove templates */
    std::vector<GrooveTemplate> getBuiltInGrooves() const
    {
        return {
            GrooveTemplate::createStraight(),
            GrooveTemplate::createSwing(54.0f),
            GrooveTemplate::createSwing(58.0f),
            GrooveTemplate::createSwing(62.0f),
            GrooveTemplate::createSwing(67.0f),
            GrooveTemplate::createShuffle(),
            GrooveTemplate::createHumanize(5.0f),
            GrooveTemplate::createHumanize(10.0f),
            GrooveTemplate::createHumanize(20.0f),
            GrooveTemplate::createMPC60()
        };
    }

    /** Extract groove from existing notes */
    GrooveTemplate extractGroove(const std::vector<QuantizableNote>& notes, GridValue grid) const
    {
        GrooveTemplate groove;
        groove.name = "Extracted";
        groove.gridDivisions = 16;
        groove.timingOffsets.resize(16, 0.0f);
        groove.velocityScales.resize(16, 1.0f);
        groove.durationScales.resize(16, 1.0f);

        double gridSize = getGridValueInBeats(grid);

        // Collect offsets for each grid position
        std::vector<std::vector<float>> offsetsPerPosition(16);
        std::vector<std::vector<float>> velocitiesPerPosition(16);

        for (const auto& note : notes)
        {
            double nearestGrid = snapToGridSize(note.startBeat, gridSize, true);
            double offset = note.startBeat - nearestGrid;

            int barPosition = static_cast<int>(std::fmod(nearestGrid / gridSize, 16.0));
            if (barPosition >= 0 && barPosition < 16)
            {
                // Convert to percentage of grid
                float offsetPercent = static_cast<float>(offset / gridSize * 100.0);
                offsetsPerPosition[barPosition].push_back(offsetPercent);
                velocitiesPerPosition[barPosition].push_back(static_cast<float>(note.velocity));
            }
        }

        // Average the collected data
        float avgVelocity = 100.0f;
        for (int i = 0; i < 16; ++i)
        {
            if (!velocitiesPerPosition[i].empty())
            {
                float sum = 0;
                for (float v : velocitiesPerPosition[i]) sum += v;
                avgVelocity = sum / velocitiesPerPosition[i].size();
            }
        }

        for (int i = 0; i < 16; ++i)
        {
            if (!offsetsPerPosition[i].empty())
            {
                float sum = 0;
                for (float o : offsetsPerPosition[i]) sum += o;
                groove.timingOffsets[i] = sum / offsetsPerPosition[i].size();
            }

            if (!velocitiesPerPosition[i].empty())
            {
                float sum = 0;
                for (float v : velocitiesPerPosition[i]) sum += v;
                float avg = sum / velocitiesPerPosition[i].size();
                groove.velocityScales[i] = avg / avgVelocity;
            }
        }

        return groove;
    }

    //==========================================================================
    // Audio Transient Quantization
    //==========================================================================

    struct TransientMarker
    {
        double positionBeats;
        float strength;     // Transient strength
        bool isQuantized = false;
        double quantizedPosition;
    };

    /** Quantize audio transients (for warping) */
    std::vector<TransientMarker> quantizeTransients(std::vector<TransientMarker> transients,
                                                     const QuantizationSettings& settings) const
    {
        double gridSize = getGridValueInBeats(settings.gridValue);

        for (auto& t : transients)
        {
            double nearestGrid = snapToGridSize(t.positionBeats, gridSize, settings.quantizeToNearest);
            double offset = nearestGrid - t.positionBeats;

            // Apply strength
            t.quantizedPosition = t.positionBeats + (offset * settings.strength / 100.0);
            t.isQuantized = true;
        }

        return transients;
    }

private:
    //==========================================================================
    // Internal Helpers
    //==========================================================================

    bool passesFilters(const QuantizableNote& note, const QuantizationSettings& settings) const
    {
        // Range filter
        if (settings.useRange)
        {
            if (note.startBeat < settings.rangeStartBeat || note.startBeat > settings.rangeEndBeat)
                return false;
        }

        // Velocity filter
        if (settings.useVelocityFilter)
        {
            if (note.velocity < settings.minVelocity || note.velocity > settings.maxVelocity)
                return false;
        }

        // Note filter
        if (settings.useNoteFilter)
        {
            if (note.noteNumber < settings.minNote || note.noteNumber > settings.maxNote)
                return false;
        }

        return true;
    }

    void quantizeNoteStart(QuantizableNote& note, double gridSize, float strength,
                           double grooveOffset, bool snapToNearest) const
    {
        double nearestGrid = snapToGridSize(note.startBeat, gridSize, snapToNearest);
        nearestGrid += grooveOffset * gridSize / 100.0;  // Apply groove

        double offset = nearestGrid - note.startBeat;
        note.quantizationOffset = offset * strength / 100.0;
        note.startBeat += note.quantizationOffset;
    }

    void quantizeNoteEnd(QuantizableNote& note, double gridSize, float strength,
                         double grooveOffset, bool snapToNearest) const
    {
        double endBeat = note.endBeat();
        double nearestGrid = snapToGridSize(endBeat, gridSize, snapToNearest);

        double offset = nearestGrid - endBeat;
        double newEnd = endBeat + (offset * strength / 100.0);

        note.lengthBeats = newEnd - note.startBeat;
        if (note.lengthBeats < 0.01) note.lengthBeats = 0.01;  // Minimum length
    }

    void quantizeNoteLength(QuantizableNote& note, double gridSize, float strength) const
    {
        double nearestLength = std::round(note.lengthBeats / gridSize) * gridSize;
        if (nearestLength < gridSize) nearestLength = gridSize;

        double offset = nearestLength - note.lengthBeats;
        note.lengthBeats += offset * strength / 100.0;

        if (note.lengthBeats < 0.01) note.lengthBeats = 0.01;
    }

    double calculateSwingOffset(double positionBeats, double gridSize, float swingPercent) const
    {
        // Swing affects every other grid position
        double gridPosition = positionBeats / gridSize;
        int gridIndex = static_cast<int>(std::floor(gridPosition));

        if (gridIndex % 2 == 1)  // Odd positions get swung
        {
            // Convert swing percent to offset
            // 50% = no swing, 67% = triplet feel (2:1 ratio)
            return (swingPercent - 50.0f) * 2.0f;  // -100 to +100 range
        }

        return 0.0;
    }

    double calculateGrooveOffset(double positionBeats, const GrooveTemplate& groove) const
    {
        // Find position within bar
        double beatsPerBar = 4.0;  // Assuming 4/4
        double posInBar = std::fmod(positionBeats, beatsPerBar);
        double gridSize = beatsPerBar / groove.gridDivisions;

        int gridIndex = static_cast<int>(std::floor(posInBar / gridSize)) % groove.gridDivisions;

        if (gridIndex >= 0 && gridIndex < static_cast<int>(groove.timingOffsets.size()))
        {
            return groove.timingOffsets[gridIndex];
        }

        return 0.0;
    }

    float getGrooveVelocityScale(double positionBeats, const GrooveTemplate& groove) const
    {
        double beatsPerBar = 4.0;
        double posInBar = std::fmod(positionBeats, beatsPerBar);
        double gridSize = beatsPerBar / groove.gridDivisions;

        int gridIndex = static_cast<int>(std::floor(posInBar / gridSize)) % groove.gridDivisions;

        if (gridIndex >= 0 && gridIndex < static_cast<int>(groove.velocityScales.size()))
        {
            return groove.velocityScales[gridIndex];
        }

        return 1.0f;
    }
};

//==============================================================================
// Quantization Presets
//==============================================================================

class QuantizationPresets
{
public:
    static QuantizationSettings tight16th()
    {
        QuantizationSettings s;
        s.gridValue = GridValue::Sixteenth;
        s.strength = 100.0f;
        s.mode = QuantizeMode::NoteStart;
        return s;
    }

    static QuantizationSettings soft8th()
    {
        QuantizationSettings s;
        s.gridValue = GridValue::Eighth;
        s.strength = 75.0f;
        s.mode = QuantizeMode::NoteStart;
        return s;
    }

    static QuantizationSettings swing16th(float swingAmount = 62.0f)
    {
        QuantizationSettings s;
        s.gridValue = GridValue::Sixteenth;
        s.strength = 100.0f;
        s.swingPercent = swingAmount;
        s.mode = QuantizeMode::NoteStart;
        return s;
    }

    static QuantizationSettings tripletFeel()
    {
        QuantizationSettings s;
        s.gridValue = GridValue::EighthTriplet;
        s.strength = 100.0f;
        s.mode = QuantizeMode::NoteStartAndLength;
        return s;
    }

    static QuantizationSettings humanize()
    {
        QuantizationSettings s;
        s.gridValue = GridValue::Sixteenth;
        s.strength = 50.0f;
        s.useGroove = true;
        s.groove = GrooveTemplate::createHumanize(15.0f);
        s.mode = QuantizeMode::NoteStart;
        return s;
    }

    static QuantizationSettings drumTight()
    {
        QuantizationSettings s;
        s.gridValue = GridValue::Sixteenth;
        s.strength = 100.0f;
        s.mode = QuantizeMode::NoteStartAndLength;
        s.lengthStrength = 50.0f;
        return s;
    }
};

} // namespace Echoelmusic
