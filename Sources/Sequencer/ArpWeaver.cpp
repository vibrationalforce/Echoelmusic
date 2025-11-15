#include "ArpWeaver.h"

//==============================================================================
// Constructor
//==============================================================================

ArpWeaver::ArpWeaver()
{
    initializeScales();
}

//==============================================================================
// Mode & Scale
//==============================================================================

void ArpWeaver::setArpMode(ArpMode mode)
{
    if (arpMode != mode)
    {
        arpMode = mode;
        updateArpSequence();
    }
}

void ArpWeaver::setScale(Scale scale)
{
    if (currentScale != scale)
    {
        currentScale = scale;
        updateArpSequence();
    }
}

void ArpWeaver::setRootNote(int rootMIDI)
{
    rootNote = rootMIDI % 12;
    updateArpSequence();
}

void ArpWeaver::setMusicStyle(MusicStyle style)
{
    if (musicStyle != style)
    {
        musicStyle = style;
        updateArpSequence();
        generateRhythmPattern(style);
    }
}

//==============================================================================
// Range & Pattern
//==============================================================================

void ArpWeaver::setOctaveRange(int octaves)
{
    octaveRange = juce::jlimit(1, 4, octaves);
    updateArpSequence();
}

void ArpWeaver::setRate(float rate)
{
    arpRate = juce::jlimit(0.0625f, 4.0f, rate);  // 1/16 to whole note
}

void ArpWeaver::setSwing(float swing)
{
    arpSwing = juce::jlimit(0.0f, 1.0f, swing);
}

void ArpWeaver::setGateLength(float gate)
{
    gateLength = juce::jlimit(0.1f, 1.0f, gate);
}

//==============================================================================
// Rhythm Pattern
//==============================================================================

void ArpWeaver::setRhythmPattern(const RhythmPattern& pattern)
{
    rhythmPattern = pattern;
}

void ArpWeaver::generateRhythmPattern(MusicStyle style)
{
    rhythmPattern.steps.fill(false);
    rhythmPattern.velocities.fill(0.8f);
    rhythmPattern.gateLengths.fill(0.8f);

    switch (style)
    {
        case MusicStyle::House:
            // Four-on-floor feel
            for (int i = 0; i < 16; i += 4)
                rhythmPattern.steps[i] = true;
            for (int i = 0; i < 16; i += 2)
                rhythmPattern.steps[i] = true;
            break;

        case MusicStyle::Trance:
            // Driving 16th notes
            rhythmPattern.steps.fill(true);
            for (int i = 0; i < 16; i += 2)
                rhythmPattern.velocities[i] = 1.0f;
            break;

        case MusicStyle::HipHop:
            // Syncopated pattern
            rhythmPattern.steps[0] = rhythmPattern.steps[3] = true;
            rhythmPattern.steps[6] = rhythmPattern.steps[9] = true;
            rhythmPattern.steps[12] = rhythmPattern.steps[14] = true;
            break;

        case MusicStyle::DnB:
            // Fast breakbeat feel
            for (int i = 0; i < 16; ++i)
            {
                if (i % 3 == 0 || i % 5 == 0)
                    rhythmPattern.steps[i] = true;
            }
            break;

        case MusicStyle::Techno:
            // Driving 8th notes
            for (int i = 0; i < 16; i += 2)
                rhythmPattern.steps[i] = true;
            break;

        case MusicStyle::Ambient:
            // Sparse, textural
            rhythmPattern.steps[0] = rhythmPattern.steps[5] = true;
            rhythmPattern.steps[10] = rhythmPattern.steps[14] = true;
            rhythmPattern.gateLengths.fill(1.0f);  // Long gates
            break;

        case MusicStyle::Jazz:
            // Swung triplets
            rhythmPattern.steps[0] = rhythmPattern.steps[2] = true;
            rhythmPattern.steps[6] = rhythmPattern.steps[10] = true;
            rhythmPattern.steps[12] = true;
            break;

        case MusicStyle::Classical:
            // Regular 16th notes
            rhythmPattern.steps.fill(true);
            break;

        default:
            // All steps
            rhythmPattern.steps.fill(true);
            break;
    }
}

//==============================================================================
// Latch & Hold
//==============================================================================

void ArpWeaver::setLatchEnabled(bool enabled)
{
    latchEnabled = enabled;
    if (!enabled)
    {
        latchedNotes.clear();
    }
}

void ArpWeaver::clearLatch()
{
    latchedNotes.clear();
    updateArpSequence();
}

//==============================================================================
// Bio-Reactive Control
//==============================================================================

void ArpWeaver::setBioData(float hrv, float coherence)
{
    bioHRV = juce::jlimit(0.0f, 1.0f, hrv);
    bioCoherence = juce::jlimit(0.0f, 1.0f, coherence);

    if (bioReactiveEnabled)
    {
        updateArpSequence();
    }
}

void ArpWeaver::setBioReactiveEnabled(bool enabled)
{
    bioReactiveEnabled = enabled;
}

//==============================================================================
// MIDI Input/Output
//==============================================================================

void ArpWeaver::processNoteOn(int midiNote, float velocity)
{
    juce::ignoreUnused(velocity);

    // Add to held notes
    if (std::find(heldNotes.begin(), heldNotes.end(), midiNote) == heldNotes.end())
    {
        heldNotes.push_back(midiNote);
    }

    // Latch
    if (latchEnabled)
    {
        if (std::find(latchedNotes.begin(), latchedNotes.end(), midiNote) == latchedNotes.end())
        {
            latchedNotes.push_back(midiNote);
        }
    }

    updateArpSequence();
}

void ArpWeaver::processNoteOff(int midiNote)
{
    // Remove from held notes
    heldNotes.erase(std::remove(heldNotes.begin(), heldNotes.end(), midiNote), heldNotes.end());

    if (!latchEnabled)
    {
        updateArpSequence();
    }
}

std::vector<ArpWeaver::ArpNote> ArpWeaver::getArpNotes(double sampleRate, int numSamples,
                                                        double& currentPhase, double tempo)
{
    std::vector<ArpNote> notes;

    if (arpNotes.empty())
        return notes;

    // Calculate phase increment
    const double beatsPerSecond = tempo / 60.0;
    const double noteLength = arpRate * 4.0;  // Convert to beats
    const double phaseIncrement = (beatsPerSecond / noteLength) * numSamples / sampleRate;

    currentPhase += phaseIncrement;

    // Trigger notes when phase crosses integer boundaries
    if (static_cast<int>(currentPhase) > static_cast<int>(currentPhase - phaseIncrement))
    {
        // Check rhythm pattern
        if (rhythmPattern.steps[currentStep])
        {
            ArpNote note;
            note.midiNote = arpNotes[currentArpIndex];
            note.velocity = rhythmPattern.velocities[currentStep];
            note.gateLength = rhythmPattern.gateLengths[currentStep] * gateLength;
            note.noteOn = true;

            // Apply bio-reactive modulation
            if (bioReactiveEnabled)
            {
                note.velocity *= (0.5f + bioHRV * 0.5f);  // 0.5 to 1.0
            }

            notes.push_back(note);
        }

        // Advance arp index
        currentArpIndex = (currentArpIndex + 1) % arpNotes.size();

        // Advance step
        currentStep = (currentStep + 1) % 16;
    }

    // Apply swing
    if (arpSwing > 0.01f && (currentStep % 2) == 1)
    {
        // Delay odd steps for swing feel
        // (This would need more sophisticated timing in real implementation)
    }

    return notes;
}

//==============================================================================
// Chord Detection
//==============================================================================

juce::String ArpWeaver::getDetectedChord() const
{
    const auto& notes = latchEnabled && !latchedNotes.empty() ? latchedNotes : heldNotes;
    return detectChord(notes);
}

std::vector<juce::String> ArpWeaver::suggestProgression() const
{
    // Simple chord progression suggestions based on current chord
    std::vector<juce::String> suggestions;

    juce::String currentChord = getDetectedChord();

    // Basic progressions
    if (currentChord.contains("I"))
    {
        suggestions = {"IV", "V", "vi", "ii"};
    }
    else if (currentChord.contains("IV"))
    {
        suggestions = {"V", "I", "ii", "vii°"};
    }
    else if (currentChord.contains("V"))
    {
        suggestions = {"I", "vi", "IV"};
    }
    else
    {
        // Default common progressions
        suggestions = {"I", "IV", "V", "vi"};
    }

    return suggestions;
}

//==============================================================================
// Reset
//==============================================================================

void ArpWeaver::reset()
{
    heldNotes.clear();
    latchedNotes.clear();
    arpNotes.clear();
    currentArpIndex = 0;
    currentStep = 0;
}

//==============================================================================
// Internal Methods - Scale Initialization
//==============================================================================

void ArpWeaver::initializeScales()
{
    scales[static_cast<size_t>(Scale::Chromatic)] =
        ScaleData(Scale::Chromatic, "Chromatic", {0,1,2,3,4,5,6,7,8,9,10,11});

    scales[static_cast<size_t>(Scale::Major)] =
        ScaleData(Scale::Major, "Major", {0,2,4,5,7,9,11});

    scales[static_cast<size_t>(Scale::Minor)] =
        ScaleData(Scale::Minor, "Natural Minor", {0,2,3,5,7,8,10});

    scales[static_cast<size_t>(Scale::HarmonicMinor)] =
        ScaleData(Scale::HarmonicMinor, "Harmonic Minor", {0,2,3,5,7,8,11});

    scales[static_cast<size_t>(Scale::MelodicMinor)] =
        ScaleData(Scale::MelodicMinor, "Melodic Minor", {0,2,3,5,7,9,11});

    scales[static_cast<size_t>(Scale::Dorian)] =
        ScaleData(Scale::Dorian, "Dorian", {0,2,3,5,7,9,10});

    scales[static_cast<size_t>(Scale::Phrygian)] =
        ScaleData(Scale::Phrygian, "Phrygian", {0,1,3,5,7,8,10});

    scales[static_cast<size_t>(Scale::Lydian)] =
        ScaleData(Scale::Lydian, "Lydian", {0,2,4,6,7,9,11});

    scales[static_cast<size_t>(Scale::Mixolydian)] =
        ScaleData(Scale::Mixolydian, "Mixolydian", {0,2,4,5,7,9,10});

    scales[static_cast<size_t>(Scale::Aeolian)] =
        ScaleData(Scale::Aeolian, "Aeolian", {0,2,3,5,7,8,10});

    scales[static_cast<size_t>(Scale::Locrian)] =
        ScaleData(Scale::Locrian, "Locrian", {0,1,3,5,6,8,10});

    scales[static_cast<size_t>(Scale::MajorPentatonic)] =
        ScaleData(Scale::MajorPentatonic, "Major Pentatonic", {0,2,4,7,9});

    scales[static_cast<size_t>(Scale::MinorPentatonic)] =
        ScaleData(Scale::MinorPentatonic, "Minor Pentatonic", {0,3,5,7,10});

    scales[static_cast<size_t>(Scale::Blues)] =
        ScaleData(Scale::Blues, "Blues", {0,3,5,6,7,10});

    scales[static_cast<size_t>(Scale::WholeTone)] =
        ScaleData(Scale::WholeTone, "Whole Tone", {0,2,4,6,8,10});

    scales[static_cast<size_t>(Scale::Diminished)] =
        ScaleData(Scale::Diminished, "Diminished", {0,2,3,5,6,8,9,11});

    scales[static_cast<size_t>(Scale::Augmented)] =
        ScaleData(Scale::Augmented, "Augmented", {0,3,4,7,8,11});

    scales[static_cast<size_t>(Scale::Spanish)] =
        ScaleData(Scale::Spanish, "Spanish", {0,1,4,5,7,8,10});

    scales[static_cast<size_t>(Scale::Gypsy)] =
        ScaleData(Scale::Gypsy, "Gypsy", {0,2,3,6,7,8,11});

    scales[static_cast<size_t>(Scale::Arabic)] =
        ScaleData(Scale::Arabic, "Arabic", {0,1,4,5,7,8,11});

    scales[static_cast<size_t>(Scale::Persian)] =
        ScaleData(Scale::Persian, "Persian", {0,1,4,5,6,8,11});

    // Initialize remaining scales with chromatic
    for (size_t i = static_cast<size_t>(Scale::Persian) + 1;
         i < static_cast<size_t>(Scale::NumScales); ++i)
    {
        scales[i] = scales[static_cast<size_t>(Scale::Chromatic)];
    }
}

//==============================================================================
// Arp Sequence Generation
//==============================================================================

void ArpWeaver::updateArpSequence()
{
    // Get active notes
    const auto& activeNotes = latchEnabled && !latchedNotes.empty() ? latchedNotes : heldNotes;

    if (activeNotes.empty())
    {
        arpNotes.clear();
        return;
    }

    // Quantize to scale
    std::vector<int> scaledNotes = quantizeToScale(activeNotes);

    // Generate arp sequence based on mode
    switch (arpMode)
    {
        case ArpMode::Up:
            arpNotes = generateUp(scaledNotes);
            break;

        case ArpMode::Down:
            arpNotes = generateDown(scaledNotes);
            break;

        case ArpMode::UpDown:
            arpNotes = generateUpDown(scaledNotes);
            break;

        case ArpMode::DownUp:
            arpNotes = generateDownUp(scaledNotes);
            break;

        case ArpMode::AsPlayed:
            arpNotes = generateAsPlayed(scaledNotes);
            break;

        case ArpMode::Random:
            arpNotes = generateRandom(scaledNotes);
            break;

        case ArpMode::Chord:
            arpNotes = scaledNotes;  // Play all at once
            break;

        case ArpMode::Intelligent:
            arpNotes = generateIntelligent(scaledNotes);
            break;

        case ArpMode::TensionRelease:
            arpNotes = generateTensionRelease(scaledNotes);
            break;
    }

    // Apply music style modifications
    applyMusicStyle(arpNotes);

    // Reset arp index
    if (currentArpIndex >= static_cast<int>(arpNotes.size()))
    {
        currentArpIndex = 0;
    }
}

std::vector<int> ArpWeaver::quantizeToScale(const std::vector<int>& notes)
{
    if (currentScale == Scale::Chromatic)
        return notes;

    const auto& scaleData = scales[static_cast<size_t>(currentScale)];
    std::vector<int> quantized;

    for (int note : notes)
    {
        int octave = note / 12;
        int noteInOctave = note % 12;

        // Find closest scale degree
        int minDist = 12;
        int closestInterval = 0;

        for (int interval : scaleData.intervals)
        {
            int scaledNote = (rootNote + interval) % 12;
            int dist = std::abs(noteInOctave - scaledNote);

            if (dist < minDist)
            {
                minDist = dist;
                closestInterval = interval;
            }
        }

        int quantizedNote = octave * 12 + ((rootNote + closestInterval) % 12);
        quantized.push_back(quantizedNote);
    }

    return quantized;
}

//==============================================================================
// Arp Mode Generators
//==============================================================================

std::vector<int> ArpWeaver::generateUp(const std::vector<int>& notes)
{
    std::vector<int> result = notes;
    std::sort(result.begin(), result.end());

    // Expand over octave range
    std::vector<int> expanded;
    for (int oct = 0; oct < octaveRange; ++oct)
    {
        for (int note : result)
        {
            expanded.push_back(note + oct * 12);
        }
    }

    return expanded;
}

std::vector<int> ArpWeaver::generateDown(const std::vector<int>& notes)
{
    auto result = generateUp(notes);
    std::reverse(result.begin(), result.end());
    return result;
}

std::vector<int> ArpWeaver::generateUpDown(const std::vector<int>& notes)
{
    auto up = generateUp(notes);
    auto down = up;
    std::reverse(down.begin(), down.end());

    // Remove duplicates at top/bottom
    if (!up.empty() && !down.empty() && up.back() == down.front())
        down.erase(down.begin());
    if (!up.empty() && !down.empty() && up.front() == down.back())
        down.pop_back();

    up.insert(up.end(), down.begin(), down.end());
    return up;
}

std::vector<int> ArpWeaver::generateDownUp(const std::vector<int>& notes)
{
    auto result = generateUpDown(notes);
    std::reverse(result.begin(), result.end());
    return result;
}

std::vector<int> ArpWeaver::generateAsPlayed(const std::vector<int>& notes)
{
    return notes;  // Keep original order
}

std::vector<int> ArpWeaver::generateRandom(const std::vector<int>& notes)
{
    auto result = notes;

    // Generate random sequence
    for (int i = 0; i < 8; ++i)
    {
        int randomIndex = std::rand() % result.size();
        result.push_back(result[randomIndex]);
    }

    return result;
}

std::vector<int> ArpWeaver::generateIntelligent(const std::vector<int>& notes)
{
    // AI-powered intelligent note selection
    // Build melody with tension and release

    auto sorted = notes;
    std::sort(sorted.begin(), sorted.end());

    std::vector<int> result;

    // Start with root
    result.push_back(sorted[0]);

    // Add melodic intervals
    for (size_t i = 1; i < sorted.size(); ++i)
    {
        result.push_back(sorted[i]);

        // Add passing tones based on bio-data
        if (bioReactiveEnabled && bioCoherence > 0.5f)
        {
            int midNote = (sorted[i-1] + sorted[i]) / 2;
            result.push_back(midNote);
        }
    }

    return result;
}

std::vector<int> ArpWeaver::generateTensionRelease(const std::vector<int>& notes)
{
    auto sorted = notes;
    std::sort(sorted.begin(), sorted.end());

    std::vector<int> result;

    // Build tension (ascending)
    for (const auto& note : sorted)
    {
        result.push_back(note);
    }

    // Release (descend to root)
    for (auto it = sorted.rbegin(); it != sorted.rend(); ++it)
    {
        result.push_back(*it);
    }

    return result;
}

//==============================================================================
// Music Style Modifiers
//==============================================================================

void ArpWeaver::applyMusicStyle(std::vector<int>& notes)
{
    if (musicStyle == MusicStyle::None || notes.empty())
        return;

    switch (musicStyle)
    {
        case MusicStyle::Trance:
            // Add octave jumps
            if (notes.size() > 2)
            {
                notes.insert(notes.begin() + notes.size()/2, notes[0] + 12);
            }
            break;

        case MusicStyle::Jazz:
            // Add chromatic passing tones
            if (notes.size() > 1)
            {
                std::vector<int> jazzNotes;
                for (size_t i = 0; i < notes.size() - 1; ++i)
                {
                    jazzNotes.push_back(notes[i]);
                    if (notes[i+1] - notes[i] > 2)
                    {
                        jazzNotes.push_back(notes[i] + 1);  // Chromatic approach
                    }
                }
                jazzNotes.push_back(notes.back());
                notes = jazzNotes;
            }
            break;

        default:
            break;
    }
}

//==============================================================================
// Chord Detection
//==============================================================================

juce::String ArpWeaver::detectChord(const std::vector<int>& notes) const
{
    if (notes.empty())
        return "None";

    if (notes.size() == 1)
        return "Single Note";

    // Normalize notes to single octave
    std::vector<int> normalized;
    for (int note : notes)
    {
        int noteClass = note % 12;
        if (std::find(normalized.begin(), normalized.end(), noteClass) == normalized.end())
        {
            normalized.push_back(noteClass);
        }
    }

    std::sort(normalized.begin(), normalized.end());

    // Detect chord quality
    if (normalized.size() >= 3)
    {
        int root = normalized[0];
        juce::String noteName = juce::MidiMessage::getMidiNoteName(root, true, false, 4);

        // Check intervals
        bool hasMajor3rd = std::find(normalized.begin(), normalized.end(), (root + 4) % 12) != normalized.end();
        bool hasMinor3rd = std::find(normalized.begin(), normalized.end(), (root + 3) % 12) != normalized.end();
        bool hasPerfect5th = std::find(normalized.begin(), normalized.end(), (root + 7) % 12) != normalized.end();

        if (hasMajor3rd && hasPerfect5th)
            return noteName + " Major";
        else if (hasMinor3rd && hasPerfect5th)
            return noteName + " Minor";
        else
            return noteName + " (Unknown)";
    }

    return "Interval";
}

std::vector<int> ArpWeaver::getChordNotes(const juce::String& chordName) const
{
    juce::ignoreUnused(chordName);
    // Implementation would parse chord name and return MIDI notes
    return {};
}
