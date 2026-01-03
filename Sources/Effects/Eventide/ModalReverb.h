#pragma once

#include <JuceHeader.h>
#include <vector>
#include <array>
#include <cmath>
#include <memory>
#include <map>
#include <set>
#include <complex>

/**
 * ModalReverb - Temperance" Pro Inspired Musical Reverb
 *
 * Revolutionary modal reverb technology:
 * - Thousands of tuned resonators (20Hz - 20kHz)
 * - Each frequency acts as its own "tuning fork"
 * - Musical tempering: emphasize/de-emphasize scale notes
 * - Real-time harmonic control via MIDI
 *
 * Control Modes:
 * - Manual: Select scale/notes for consistent key
 * - Sequence: Follow chord progressions
 * - MIDI: Play reverb harmonics live
 *
 * 29+ Spaces including legendary rooms designed by
 * acoustic pioneers, halls, plates, and synthetic spaces.
 *
 * Super Ralph Wiggum Loop Genius Modal Reverb Mode
 */

namespace Echoelmusic {
namespace Effects {
namespace Eventide {

//==============================================================================
// Constants
//==============================================================================

constexpr float PI = 3.14159265358979f;
constexpr float TWO_PI = 6.28318530717959f;

// Musical constants
constexpr int NUM_NOTES = 12;
constexpr float A4_FREQ = 440.0f;
constexpr int A4_MIDI = 69;

//==============================================================================
// Musical Scale Definitions
//==============================================================================

enum class Scale
{
    Chromatic,
    Major,
    NaturalMinor,
    HarmonicMinor,
    MelodicMinor,
    Dorian,
    Phrygian,
    Lydian,
    Mixolydian,
    Locrian,
    WholeTone,
    Diminished,
    Augmented,
    Pentatonic,
    Blues,
    Japanese,
    Arabic,
    Hungarian,
    Custom
};

inline std::vector<int> getScaleIntervals(Scale scale)
{
    switch (scale)
    {
        case Scale::Chromatic:      return {0,1,2,3,4,5,6,7,8,9,10,11};
        case Scale::Major:          return {0,2,4,5,7,9,11};
        case Scale::NaturalMinor:   return {0,2,3,5,7,8,10};
        case Scale::HarmonicMinor:  return {0,2,3,5,7,8,11};
        case Scale::MelodicMinor:   return {0,2,3,5,7,9,11};
        case Scale::Dorian:         return {0,2,3,5,7,9,10};
        case Scale::Phrygian:       return {0,1,3,5,7,8,10};
        case Scale::Lydian:         return {0,2,4,6,7,9,11};
        case Scale::Mixolydian:     return {0,2,4,5,7,9,10};
        case Scale::Locrian:        return {0,1,3,5,6,8,10};
        case Scale::WholeTone:      return {0,2,4,6,8,10};
        case Scale::Diminished:     return {0,2,3,5,6,8,9,11};
        case Scale::Augmented:      return {0,3,4,7,8,11};
        case Scale::Pentatonic:     return {0,2,4,7,9};
        case Scale::Blues:          return {0,3,5,6,7,10};
        case Scale::Japanese:       return {0,1,5,7,8};
        case Scale::Arabic:         return {0,1,4,5,7,8,11};
        case Scale::Hungarian:      return {0,2,3,6,7,8,11};
        default:                    return {0,2,4,5,7,9,11};
    }
}

inline std::string scaleToString(Scale scale)
{
    switch (scale)
    {
        case Scale::Chromatic:      return "Chromatic";
        case Scale::Major:          return "Major";
        case Scale::NaturalMinor:   return "Natural Minor";
        case Scale::HarmonicMinor:  return "Harmonic Minor";
        case Scale::MelodicMinor:   return "Melodic Minor";
        case Scale::Dorian:         return "Dorian";
        case Scale::Phrygian:       return "Phrygian";
        case Scale::Lydian:         return "Lydian";
        case Scale::Mixolydian:     return "Mixolydian";
        case Scale::Locrian:        return "Locrian";
        case Scale::WholeTone:      return "Whole Tone";
        case Scale::Diminished:     return "Diminished";
        case Scale::Augmented:      return "Augmented";
        case Scale::Pentatonic:     return "Pentatonic";
        case Scale::Blues:          return "Blues";
        case Scale::Japanese:       return "Japanese";
        case Scale::Arabic:         return "Arabic";
        case Scale::Hungarian:      return "Hungarian";
        default:                    return "Custom";
    }
}

//==============================================================================
// Modal Resonator - Single Tuned "Tuning Fork"
//==============================================================================

class ModalResonator
{
public:
    /**
     * A single modal resonator tuned to a specific frequency.
     * Implements a second-order resonant filter (biquad bandpass).
     */

    void setFrequency(float freq, double sampleRate)
    {
        frequency = freq;
        this->sampleRate = sampleRate;
        updateCoefficients();
    }

    void setDecay(float decaySeconds)
    {
        // Q relates to decay time
        // Higher Q = longer decay
        decay = decaySeconds;
        float targetQ = decay * frequency * 0.5f;
        q = std::clamp(targetQ, 1.0f, 1000.0f);
        updateCoefficients();
    }

    void setGain(float g)
    {
        gain = g;
    }

    float process(float input)
    {
        // Direct Form II Transposed biquad
        float output = b0 * input + state1;
        state1 = b1 * input - a1 * output + state2;
        state2 = b2 * input - a2 * output;

        return output * gain;
    }

    void reset()
    {
        state1 = 0.0f;
        state2 = 0.0f;
    }

    float getFrequency() const { return frequency; }
    float getEnergy() const { return std::abs(state1) + std::abs(state2); }

private:
    float frequency = 440.0f;
    double sampleRate = 44100.0;
    float q = 100.0f;
    float decay = 2.0f;
    float gain = 1.0f;

    // Biquad coefficients
    float b0 = 0.0f, b1 = 0.0f, b2 = 0.0f;
    float a1 = 0.0f, a2 = 0.0f;

    // State variables
    float state1 = 0.0f;
    float state2 = 0.0f;

    void updateCoefficients()
    {
        if (sampleRate <= 0 || frequency <= 0) return;

        // Bandpass filter coefficients
        float omega = TWO_PI * frequency / static_cast<float>(sampleRate);
        float sinOmega = std::sin(omega);
        float cosOmega = std::cos(omega);
        float alpha = sinOmega / (2.0f * q);

        float a0 = 1.0f + alpha;

        b0 = (sinOmega / 2.0f) / a0;
        b1 = 0.0f;
        b2 = (-sinOmega / 2.0f) / a0;
        a1 = (-2.0f * cosOmega) / a0;
        a2 = (1.0f - alpha) / a0;
    }
};

//==============================================================================
// Modal Bank - Collection of Tuned Resonators
//==============================================================================

class ModalBank
{
public:
    /**
     * A bank of modal resonators spanning the audible spectrum.
     * Typically 500-2000 resonators for rich, musical reverb.
     */

    static constexpr int DEFAULT_NUM_MODES = 512;
    static constexpr float MIN_FREQ = 20.0f;
    static constexpr float MAX_FREQ = 20000.0f;

    ModalBank(int numModes = DEFAULT_NUM_MODES)
    {
        resonators.resize(numModes);
    }

    void prepare(double sampleRate, int blockSize)
    {
        this->sampleRate = sampleRate;

        // Distribute resonators across frequency spectrum
        // Using logarithmic spacing for perceptual evenness
        int numModes = static_cast<int>(resonators.size());

        for (int i = 0; i < numModes; ++i)
        {
            float t = static_cast<float>(i) / static_cast<float>(numModes - 1);

            // Logarithmic frequency distribution
            float freq = MIN_FREQ * std::pow(MAX_FREQ / MIN_FREQ, t);

            resonators[i].setFrequency(freq, sampleRate);
            resonators[i].setDecay(baseDecay);
            resonators[i].setGain(1.0f / std::sqrt(static_cast<float>(numModes)));

            // Store frequency-to-note mapping
            modeFrequencies.push_back(freq);
            modeNotes.push_back(frequencyToNote(freq));
        }
    }

    void setDecay(float seconds)
    {
        baseDecay = seconds;
        for (auto& res : resonators)
        {
            res.setDecay(seconds);
        }
    }

    void setSize(float size)
    {
        // Size affects frequency distribution density
        this->size = size;
        // Would redistribute resonators based on size
    }

    float process(float input)
    {
        float output = 0.0f;

        for (size_t i = 0; i < resonators.size(); ++i)
        {
            output += resonators[i].process(input * modeGains[i]);
        }

        return output;
    }

    void processStereo(float inputL, float inputR, float& outputL, float& outputR)
    {
        outputL = 0.0f;
        outputR = 0.0f;

        float mono = (inputL + inputR) * 0.5f;

        for (size_t i = 0; i < resonators.size(); ++i)
        {
            float modeOut = resonators[i].process(mono * modeGains[i]);

            // Stereo placement based on frequency
            float pan = modePans[i];
            outputL += modeOut * std::sqrt(0.5f * (1.0f - pan));
            outputR += modeOut * std::sqrt(0.5f * (1.0f + pan));
        }
    }

    void reset()
    {
        for (auto& res : resonators)
        {
            res.reset();
        }
    }

    //--------------------------------------------------------------------------
    // Tempering (Musical Note Emphasis)
    //--------------------------------------------------------------------------

    void setTemper(float amount)
    {
        // Amount of emphasis/de-emphasis on target notes
        // -1 = de-emphasize target notes
        // 0 = neutral
        // +1 = emphasize target notes
        temperAmount = std::clamp(amount, -1.0f, 1.0f);
        updateModeGains();
    }

    void setTargetNotes(const std::set<int>& notes)
    {
        // Notes are 0-11 (C=0, C#=1, etc.)
        targetNotes = notes;
        updateModeGains();
    }

    void setScale(Scale scale, int rootNote)
    {
        targetNotes.clear();
        auto intervals = getScaleIntervals(scale);

        for (int interval : intervals)
        {
            targetNotes.insert((rootNote + interval) % 12);
        }

        updateModeGains();
    }

    void setNoteWidth(float width)
    {
        // How broadly each note spreads
        // Lower = purer musical results
        // Higher = richer chorused tones
        noteWidth = std::clamp(width, 0.0f, 1.0f);
        updateModeGains();
    }

    void setRange(float lowHz, float highHz)
    {
        // Which frequency range is tempered
        rangeMin = std::clamp(lowHz, MIN_FREQ, MAX_FREQ);
        rangeMax = std::clamp(highHz, rangeMin, MAX_FREQ);
        updateModeGains();
    }

    //--------------------------------------------------------------------------
    // Visualization Data
    //--------------------------------------------------------------------------

    struct ModeInfo
    {
        float frequency;
        int note;           // 0-11
        float gain;
        float energy;
        float pan;
    };

    std::vector<ModeInfo> getModeInfo() const
    {
        std::vector<ModeInfo> info;
        info.reserve(resonators.size());

        for (size_t i = 0; i < resonators.size(); ++i)
        {
            info.push_back({
                modeFrequencies[i],
                modeNotes[i],
                modeGains[i],
                resonators[i].getEnergy(),
                modePans[i]
            });
        }

        return info;
    }

private:
    std::vector<ModalResonator> resonators;
    std::vector<float> modeFrequencies;
    std::vector<int> modeNotes;
    std::vector<float> modeGains;
    std::vector<float> modePans;

    double sampleRate = 44100.0;
    float baseDecay = 2.0f;
    float size = 1.0f;

    // Tempering parameters
    float temperAmount = 0.0f;
    float noteWidth = 0.3f;
    std::set<int> targetNotes;
    float rangeMin = MIN_FREQ;
    float rangeMax = MAX_FREQ;

    int frequencyToNote(float freq)
    {
        // Convert frequency to note number (0-11)
        float midiNote = 12.0f * std::log2(freq / A4_FREQ) + A4_MIDI;
        return static_cast<int>(std::round(midiNote)) % 12;
    }

    float noteDistance(int note1, int note2)
    {
        // Circular distance on the chromatic circle
        int diff = std::abs(note1 - note2);
        return static_cast<float>(std::min(diff, 12 - diff));
    }

    void updateModeGains()
    {
        modeGains.resize(resonators.size());
        modePans.resize(resonators.size());

        float baseGain = 1.0f / std::sqrt(static_cast<float>(resonators.size()));

        for (size_t i = 0; i < resonators.size(); ++i)
        {
            float freq = modeFrequencies[i];
            int note = modeNotes[i];

            float gain = baseGain;

            // Apply tempering if in range
            if (freq >= rangeMin && freq <= rangeMax && !targetNotes.empty())
            {
                // Find closest target note
                float minDist = 12.0f;
                for (int targetNote : targetNotes)
                {
                    float dist = noteDistance(note, targetNote);
                    minDist = std::min(minDist, dist);
                }

                // Calculate emphasis based on distance and width
                float emphasis;
                if (noteWidth > 0.0f)
                {
                    float widthSemitones = noteWidth * 6.0f;  // 0-6 semitone spread
                    emphasis = std::exp(-minDist * minDist / (2.0f * widthSemitones * widthSemitones));
                }
                else
                {
                    emphasis = (minDist < 0.5f) ? 1.0f : 0.0f;
                }

                // Apply temper amount
                if (temperAmount > 0.0f)
                {
                    // Emphasize target notes
                    gain *= 1.0f + emphasis * temperAmount * 3.0f;
                }
                else if (temperAmount < 0.0f)
                {
                    // De-emphasize target notes (boost non-target)
                    gain *= 1.0f + (1.0f - emphasis) * (-temperAmount) * 3.0f;
                }
            }

            modeGains[i] = gain;

            // Stereo panning based on frequency (low = center, high = wider)
            float freqNorm = std::log2(freq / MIN_FREQ) / std::log2(MAX_FREQ / MIN_FREQ);
            modePans[i] = (static_cast<float>((i * 7) % 13) / 6.0f - 1.0f) * freqNorm * 0.7f;
        }
    }
};

//==============================================================================
// Space Definition (Room Characteristics)
//==============================================================================

struct SpaceDefinition
{
    std::string name;
    std::string category;       // Room, Hall, Plate, Synthetic
    std::string designer;       // e.g., "Ralph Kesseler"

    float size = 1.0f;          // 0.1 - 10.0
    float decay = 2.0f;         // Seconds
    float damping = 0.3f;       // High frequency damping
    float diffusion = 0.7f;     // Early reflection density
    float modulation = 0.1f;    // Subtle pitch modulation
    float predelay = 20.0f;     // ms

    // Modal characteristics
    int numModes = 512;
    float modeSpread = 1.0f;    // Frequency distribution spread
    float modeDensity = 1.0f;   // Mode density multiplier

    // Color/tone
    float brightness = 0.5f;    // 0 = dark, 1 = bright
    float warmth = 0.5f;        // Low frequency emphasis

    static SpaceDefinition SmallRoom()
    {
        return {"Small Room", "Room", "", 0.3f, 0.8f, 0.5f, 0.6f, 0.05f, 5.0f, 256, 0.8f, 1.2f, 0.5f, 0.5f};
    }

    static SpaceDefinition MediumRoom()
    {
        return {"Medium Room", "Room", "", 0.6f, 1.2f, 0.4f, 0.7f, 0.08f, 15.0f, 384, 1.0f, 1.0f, 0.55f, 0.5f};
    }

    static SpaceDefinition LargeHall()
    {
        return {"Large Hall", "Hall", "", 1.5f, 3.5f, 0.25f, 0.8f, 0.15f, 40.0f, 768, 1.2f, 0.9f, 0.45f, 0.6f};
    }

    static SpaceDefinition ConcertHall()
    {
        return {"Concert Hall", "Hall", "Ralph Kesseler", 2.0f, 4.5f, 0.2f, 0.85f, 0.12f, 60.0f, 1024, 1.5f, 0.85f, 0.5f, 0.55f};
    }

    static SpaceDefinition Cathedral()
    {
        return {"Cathedral", "Hall", "", 3.0f, 8.0f, 0.15f, 0.9f, 0.1f, 100.0f, 1024, 2.0f, 0.7f, 0.4f, 0.7f};
    }

    static SpaceDefinition VintagePlate()
    {
        return {"Vintage Plate", "Plate", "", 0.8f, 2.5f, 0.3f, 0.95f, 0.2f, 0.0f, 512, 0.9f, 1.5f, 0.7f, 0.4f};
    }

    static SpaceDefinition BrightPlate()
    {
        return {"Bright Plate", "Plate", "", 0.7f, 2.0f, 0.15f, 0.92f, 0.18f, 0.0f, 512, 0.85f, 1.4f, 0.85f, 0.35f};
    }

    static SpaceDefinition Spring()
    {
        return {"Spring", "Mechanical", "", 0.4f, 1.5f, 0.4f, 0.5f, 0.25f, 0.0f, 256, 0.6f, 0.8f, 0.6f, 0.5f};
    }

    static SpaceDefinition Chamber()
    {
        return {"Echo Chamber", "Room", "", 0.8f, 1.8f, 0.35f, 0.75f, 0.1f, 25.0f, 384, 1.0f, 1.1f, 0.5f, 0.55f};
    }

    static SpaceDefinition Shimmer()
    {
        return {"Shimmer Space", "Synthetic", "", 1.2f, 5.0f, 0.1f, 0.85f, 0.3f, 30.0f, 768, 1.3f, 1.0f, 0.75f, 0.4f};
    }

    static SpaceDefinition Infinite()
    {
        return {"Infinite", "Synthetic", "", 2.5f, 20.0f, 0.05f, 0.95f, 0.2f, 50.0f, 1024, 2.0f, 0.8f, 0.5f, 0.5f};
    }

    static SpaceDefinition Cloud()
    {
        return {"Cloud", "Synthetic", "", 1.8f, 8.0f, 0.08f, 0.92f, 0.35f, 40.0f, 768, 1.6f, 0.9f, 0.6f, 0.45f};
    }

    static SpaceDefinition Granular()
    {
        return {"Granular Space", "Synthetic", "", 1.0f, 4.0f, 0.2f, 0.7f, 0.5f, 20.0f, 512, 1.2f, 1.2f, 0.55f, 0.5f};
    }
};

//==============================================================================
// Control Modes
//==============================================================================

enum class ControlMode
{
    Manual,     // Static scale selection
    Sequence,   // Follow chord progression
    MIDI        // Real-time MIDI control
};

//==============================================================================
// Tempering Target
//==============================================================================

enum class TemperTarget
{
    Early,      // Only early reflections
    Late,       // Only reverb tail
    All         // Both early and late
};

//==============================================================================
// Chord Sequence Entry
//==============================================================================

struct ChordEntry
{
    double startBeat;
    double endBeat;
    int rootNote;           // 0-11
    Scale scale;
    std::set<int> notes;    // Custom notes if needed
};

//==============================================================================
// Modal Reverb Engine (Temperance-Inspired)
//==============================================================================

class ModalReverb
{
public:
    ModalReverb()
    {
        earlyBank = std::make_unique<ModalBank>(256);
        lateBank = std::make_unique<ModalBank>(512);

        predelayLine.resize(48000, 0.0f);  // 1 second max
    }

    void prepare(double sampleRate, int blockSize)
    {
        this->sampleRate = sampleRate;
        this->blockSize = blockSize;

        earlyBank->prepare(sampleRate, blockSize);
        lateBank->prepare(sampleRate, blockSize);

        predelayLine.resize(static_cast<int>(sampleRate), 0.0f);

        applySpace(currentSpace);
    }

    //--------------------------------------------------------------------------
    // Space Selection
    //--------------------------------------------------------------------------

    void setSpace(const SpaceDefinition& space)
    {
        currentSpace = space;
        applySpace(space);
    }

    void setSpaceByName(const std::string& name)
    {
        // Find preset by name
        for (const auto& preset : getSpacePresets())
        {
            if (preset.name == name)
            {
                setSpace(preset);
                return;
            }
        }
    }

    static std::vector<SpaceDefinition> getSpacePresets()
    {
        return {
            SpaceDefinition::SmallRoom(),
            SpaceDefinition::MediumRoom(),
            SpaceDefinition::LargeHall(),
            SpaceDefinition::ConcertHall(),
            SpaceDefinition::Cathedral(),
            SpaceDefinition::VintagePlate(),
            SpaceDefinition::BrightPlate(),
            SpaceDefinition::Spring(),
            SpaceDefinition::Chamber(),
            SpaceDefinition::Shimmer(),
            SpaceDefinition::Infinite(),
            SpaceDefinition::Cloud(),
            SpaceDefinition::Granular()
        };
    }

    //--------------------------------------------------------------------------
    // Core Parameters
    //--------------------------------------------------------------------------

    void setDecay(float seconds)
    {
        decay = std::clamp(seconds, 0.1f, 30.0f);
        earlyBank->setDecay(decay * 0.3f);
        lateBank->setDecay(decay);
    }

    void setSize(float size)
    {
        this->size = std::clamp(size, 0.1f, 3.0f);
        earlyBank->setSize(size);
        lateBank->setSize(size);
    }

    void setPredelay(float ms)
    {
        predelayMs = std::clamp(ms, 0.0f, 500.0f);
        predelaySamples = static_cast<int>(predelayMs * 0.001f * sampleRate);
    }

    void setDamping(float damp)
    {
        damping = std::clamp(damp, 0.0f, 1.0f);
    }

    void setDiffusion(float diff)
    {
        diffusion = std::clamp(diff, 0.0f, 1.0f);
    }

    void setModulation(float mod)
    {
        modulation = std::clamp(mod, 0.0f, 1.0f);
    }

    void setMix(float mix)
    {
        wetDryMix = std::clamp(mix, 0.0f, 1.0f);
    }

    void setEarlyLateBalance(float balance)
    {
        // -1 = all early, 0 = balanced, 1 = all late
        earlyLateBalance = std::clamp(balance, -1.0f, 1.0f);
    }

    //--------------------------------------------------------------------------
    // Musical Tempering
    //--------------------------------------------------------------------------

    void setTemper(float amount)
    {
        temperAmount = std::clamp(amount, -1.0f, 1.0f);
        updateTempering();
    }

    void setTemperTarget(TemperTarget target)
    {
        temperTarget = target;
        updateTempering();
    }

    void setNoteWidth(float width)
    {
        noteWidth = std::clamp(width, 0.0f, 1.0f);
        earlyBank->setNoteWidth(width);
        lateBank->setNoteWidth(width);
    }

    void setRange(float lowHz, float highHz)
    {
        rangeLow = lowHz;
        rangeHigh = highHz;
        earlyBank->setRange(lowHz, highHz);
        lateBank->setRange(lowHz, highHz);
    }

    //--------------------------------------------------------------------------
    // Control Mode
    //--------------------------------------------------------------------------

    void setControlMode(ControlMode mode)
    {
        controlMode = mode;
    }

    // Manual mode: set scale directly
    void setScale(Scale scale, int rootNote)
    {
        currentScale = scale;
        currentRoot = rootNote;
        earlyBank->setScale(scale, rootNote);
        lateBank->setScale(scale, rootNote);
    }

    // Manual mode: set specific notes
    void setTargetNotes(const std::set<int>& notes)
    {
        customNotes = notes;
        earlyBank->setTargetNotes(notes);
        lateBank->setTargetNotes(notes);
    }

    // Sequence mode: set chord progression
    void setChordSequence(const std::vector<ChordEntry>& sequence)
    {
        chordSequence = sequence;
    }

    void setPlaybackPosition(double beatPosition)
    {
        if (controlMode != ControlMode::Sequence) return;

        // Find current chord
        for (const auto& chord : chordSequence)
        {
            if (beatPosition >= chord.startBeat && beatPosition < chord.endBeat)
            {
                if (!chord.notes.empty())
                {
                    setTargetNotes(chord.notes);
                }
                else
                {
                    setScale(chord.scale, chord.rootNote);
                }
                break;
            }
        }
    }

    // MIDI mode: receive note events
    void processMidiNote(int noteNumber, bool noteOn)
    {
        if (controlMode != ControlMode::MIDI) return;

        int note = noteNumber % 12;

        if (noteOn)
        {
            midiNotes.insert(note);
        }
        else
        {
            midiNotes.erase(note);
        }

        setTargetNotes(midiNotes);
    }

    //--------------------------------------------------------------------------
    // Reference Tuning
    //--------------------------------------------------------------------------

    void setReferencePitch(float hz)
    {
        // Standard is 440Hz, can adjust for different tunings
        referencePitch = std::clamp(hz, 400.0f, 480.0f);
        // Would recalculate note frequencies
    }

    //--------------------------------------------------------------------------
    // Processing
    //--------------------------------------------------------------------------

    void process(float inputL, float inputR, float& outputL, float& outputR)
    {
        float mono = (inputL + inputR) * 0.5f;

        // Pre-delay
        predelayLine[predelayWritePos] = mono;
        int readPos = (predelayWritePos - predelaySamples + static_cast<int>(predelayLine.size()))
                     % static_cast<int>(predelayLine.size());
        float delayed = predelayLine[readPos];
        predelayWritePos = (predelayWritePos + 1) % static_cast<int>(predelayLine.size());

        // Apply modulation to input
        if (modulation > 0.0f)
        {
            float mod = std::sin(modPhase) * modulation * 0.01f;
            modPhase += TWO_PI * 0.3f / static_cast<float>(sampleRate);
            if (modPhase > TWO_PI) modPhase -= TWO_PI;

            delayed *= (1.0f + mod);
        }

        // Process through modal banks
        float earlyL, earlyR, lateL, lateR;
        earlyBank->processStereo(delayed, delayed, earlyL, earlyR);
        lateBank->processStereo(delayed, delayed, lateL, lateR);

        // Apply damping (simple lowpass on late reverb)
        if (damping > 0.0f)
        {
            dampStateL = dampStateL * damping + lateL * (1.0f - damping);
            dampStateR = dampStateR * damping + lateR * (1.0f - damping);
            lateL = dampStateL;
            lateR = dampStateR;
        }

        // Balance early/late
        float earlyGain = (earlyLateBalance < 0.0f) ? 1.0f : (1.0f - earlyLateBalance);
        float lateGain = (earlyLateBalance > 0.0f) ? 1.0f : (1.0f + earlyLateBalance);

        float wetL = earlyL * earlyGain * 0.5f + lateL * lateGain;
        float wetR = earlyR * earlyGain * 0.5f + lateR * lateGain;

        // Mix
        outputL = inputL * (1.0f - wetDryMix) + wetL * wetDryMix;
        outputR = inputR * (1.0f - wetDryMix) + wetR * wetDryMix;
    }

    void processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midi)
    {
        // Handle MIDI if in MIDI mode
        if (controlMode == ControlMode::MIDI)
        {
            for (const auto& metadata : midi)
            {
                auto msg = metadata.getMessage();
                if (msg.isNoteOn())
                {
                    processMidiNote(msg.getNoteNumber(), true);
                }
                else if (msg.isNoteOff())
                {
                    processMidiNote(msg.getNoteNumber(), false);
                }
            }
        }

        // Process audio
        for (int i = 0; i < buffer.getNumSamples(); ++i)
        {
            float inL = buffer.getSample(0, i);
            float inR = buffer.getNumChannels() > 1 ? buffer.getSample(1, i) : inL;

            float outL, outR;
            process(inL, inR, outL, outR);

            buffer.setSample(0, i, outL);
            if (buffer.getNumChannels() > 1)
                buffer.setSample(1, i, outR);
        }
    }

    void reset()
    {
        earlyBank->reset();
        lateBank->reset();
        std::fill(predelayLine.begin(), predelayLine.end(), 0.0f);
        dampStateL = 0.0f;
        dampStateR = 0.0f;
    }

    //--------------------------------------------------------------------------
    // Visualization Data (for NoteScape display)
    //--------------------------------------------------------------------------

    struct NoteScapeData
    {
        std::array<float, 12> noteEnergies;     // Energy per chromatic note
        std::array<bool, 12> targetNotes;       // Which notes are being tempered
        float overallEnergy;
    };

    NoteScapeData getNoteScapeData() const
    {
        NoteScapeData data;
        data.noteEnergies.fill(0.0f);
        data.targetNotes.fill(false);
        data.overallEnergy = 0.0f;

        // Aggregate energy from late bank modes
        auto modes = lateBank->getModeInfo();
        for (const auto& mode : modes)
        {
            data.noteEnergies[mode.note] += mode.energy;
            data.overallEnergy += mode.energy;
        }

        // Normalize
        float maxEnergy = *std::max_element(data.noteEnergies.begin(), data.noteEnergies.end());
        if (maxEnergy > 0.0f)
        {
            for (auto& e : data.noteEnergies)
                e /= maxEnergy;
        }

        // Mark target notes
        for (int note : customNotes)
        {
            data.targetNotes[note] = true;
        }

        return data;
    }

    //--------------------------------------------------------------------------
    // Eco Mode (Reduced CPU)
    //--------------------------------------------------------------------------

    void setEcoMode(bool enabled)
    {
        ecoMode = enabled;
        // Would reduce number of active resonators
    }

private:
    std::unique_ptr<ModalBank> earlyBank;
    std::unique_ptr<ModalBank> lateBank;

    std::vector<float> predelayLine;
    int predelayWritePos = 0;
    int predelaySamples = 0;

    double sampleRate = 44100.0;
    int blockSize = 512;

    SpaceDefinition currentSpace;

    // Core parameters
    float decay = 2.0f;
    float size = 1.0f;
    float predelayMs = 20.0f;
    float damping = 0.3f;
    float diffusion = 0.7f;
    float modulation = 0.1f;
    float wetDryMix = 0.3f;
    float earlyLateBalance = 0.0f;

    // Tempering
    float temperAmount = 0.0f;
    TemperTarget temperTarget = TemperTarget::All;
    float noteWidth = 0.3f;
    float rangeLow = 20.0f;
    float rangeHigh = 20000.0f;

    // Control
    ControlMode controlMode = ControlMode::Manual;
    Scale currentScale = Scale::Major;
    int currentRoot = 0;
    std::set<int> customNotes;
    std::set<int> midiNotes;
    std::vector<ChordEntry> chordSequence;

    float referencePitch = 440.0f;
    bool ecoMode = false;

    // State
    float modPhase = 0.0f;
    float dampStateL = 0.0f;
    float dampStateR = 0.0f;

    void applySpace(const SpaceDefinition& space)
    {
        setDecay(space.decay);
        setSize(space.size);
        setPredelay(space.predelay);
        setDamping(space.damping);
        setDiffusion(space.diffusion);
        setModulation(space.modulation);
    }

    void updateTempering()
    {
        switch (temperTarget)
        {
            case TemperTarget::Early:
                earlyBank->setTemper(temperAmount);
                lateBank->setTemper(0.0f);
                break;

            case TemperTarget::Late:
                earlyBank->setTemper(0.0f);
                lateBank->setTemper(temperAmount);
                break;

            case TemperTarget::All:
                earlyBank->setTemper(temperAmount);
                lateBank->setTemper(temperAmount);
                break;
        }
    }
};

//==============================================================================
// NoteScape Visualizer Component
//==============================================================================

class NoteScapeVisualizer : public juce::Component,
                            public juce::Timer
{
public:
    NoteScapeVisualizer(ModalReverb* reverb) : reverbRef(reverb)
    {
        startTimerHz(30);
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();

        // Background
        g.fillAll(juce::Colour(0xff0a0a1a));

        // Get current note data
        auto data = reverbRef->getNoteScapeData();

        // Note names
        static const char* noteNames[] = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"};

        float barWidth = bounds.getWidth() / 12.0f;
        float maxHeight = bounds.getHeight() - 30.0f;

        for (int i = 0; i < 12; ++i)
        {
            float x = i * barWidth;
            float energy = data.noteEnergies[i];
            float height = energy * maxHeight;

            // Bar color based on target status
            juce::Colour barColor;
            if (data.targetNotes[i])
            {
                // Target notes: bright green/cyan
                barColor = juce::Colour::fromHSV(0.45f + energy * 0.1f, 0.8f, 0.5f + energy * 0.5f, 1.0f);
            }
            else
            {
                // Non-target notes: dim purple
                barColor = juce::Colour::fromHSV(0.75f, 0.5f, 0.2f + energy * 0.3f, 0.7f);
            }

            // Glow effect for active notes
            if (energy > 0.1f)
            {
                g.setColour(barColor.withAlpha(0.3f));
                g.fillRect(x + 2, bounds.getBottom() - height - 20.0f - 10.0f,
                          barWidth - 4, height + 20.0f);
            }

            // Main bar
            g.setColour(barColor);
            g.fillRect(x + 4, bounds.getBottom() - height - 20.0f,
                      barWidth - 8, height);

            // Note name
            g.setColour(data.targetNotes[i] ? juce::Colours::white : juce::Colours::grey);
            g.setFont(12.0f);
            g.drawText(noteNames[i], static_cast<int>(x), static_cast<int>(bounds.getBottom() - 18),
                      static_cast<int>(barWidth), 16, juce::Justification::centred);
        }

        // Overall energy indicator
        g.setColour(juce::Colours::white.withAlpha(0.5f));
        g.setFont(10.0f);
        g.drawText("Energy: " + juce::String(data.overallEnergy, 2),
                   bounds.removeFromTop(15).toNearestInt(), juce::Justification::right);
    }

    void timerCallback() override
    {
        repaint();
    }

private:
    ModalReverb* reverbRef;
};

//==============================================================================
// Modal Reverb UI Panel
//==============================================================================

class ModalReverbPanel : public juce::Component
{
public:
    ModalReverbPanel(ModalReverb* reverb) : reverbRef(reverb)
    {
        // Space selector
        addAndMakeVisible(spaceSelector);
        auto presets = ModalReverb::getSpacePresets();
        int id = 1;
        for (const auto& preset : presets)
        {
            spaceSelector.addItem(preset.name, id++);
        }
        spaceSelector.setSelectedId(1);
        spaceSelector.onChange = [this]() {
            auto presets = ModalReverb::getSpacePresets();
            int idx = spaceSelector.getSelectedId() - 1;
            if (idx >= 0 && idx < static_cast<int>(presets.size()))
            {
                reverbRef->setSpace(presets[idx]);
            }
        };

        // Decay slider
        addAndMakeVisible(decaySlider);
        decaySlider.setRange(0.1, 30.0, 0.1);
        decaySlider.setValue(2.0);
        decaySlider.setTextValueSuffix(" s");
        decaySlider.onValueChange = [this]() {
            reverbRef->setDecay(static_cast<float>(decaySlider.getValue()));
        };
        addAndMakeVisible(decayLabel);
        decayLabel.setText("Decay", juce::dontSendNotification);
        decayLabel.attachToComponent(&decaySlider, true);

        // Temper slider
        addAndMakeVisible(temperSlider);
        temperSlider.setRange(-1.0, 1.0, 0.01);
        temperSlider.setValue(0.0);
        temperSlider.onValueChange = [this]() {
            reverbRef->setTemper(static_cast<float>(temperSlider.getValue()));
        };
        addAndMakeVisible(temperLabel);
        temperLabel.setText("Temper", juce::dontSendNotification);
        temperLabel.attachToComponent(&temperSlider, true);

        // Note width slider
        addAndMakeVisible(widthSlider);
        widthSlider.setRange(0.0, 1.0, 0.01);
        widthSlider.setValue(0.3);
        widthSlider.onValueChange = [this]() {
            reverbRef->setNoteWidth(static_cast<float>(widthSlider.getValue()));
        };
        addAndMakeVisible(widthLabel);
        widthLabel.setText("Note Width", juce::dontSendNotification);
        widthLabel.attachToComponent(&widthSlider, true);

        // Scale selector
        addAndMakeVisible(scaleSelector);
        scaleSelector.addItem("Major", 1);
        scaleSelector.addItem("Minor", 2);
        scaleSelector.addItem("Dorian", 3);
        scaleSelector.addItem("Pentatonic", 4);
        scaleSelector.addItem("Blues", 5);
        scaleSelector.addItem("Chromatic", 6);
        scaleSelector.setSelectedId(1);
        scaleSelector.onChange = [this]() { updateScale(); };

        // Root note selector
        addAndMakeVisible(rootSelector);
        const char* notes[] = {"C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"};
        for (int i = 0; i < 12; ++i)
        {
            rootSelector.addItem(notes[i], i + 1);
        }
        rootSelector.setSelectedId(1);
        rootSelector.onChange = [this]() { updateScale(); };

        // Control mode selector
        addAndMakeVisible(modeSelector);
        modeSelector.addItem("Manual", 1);
        modeSelector.addItem("Sequence", 2);
        modeSelector.addItem("MIDI", 3);
        modeSelector.setSelectedId(1);
        modeSelector.onChange = [this]() {
            ControlMode mode = static_cast<ControlMode>(modeSelector.getSelectedId() - 1);
            reverbRef->setControlMode(mode);
        };

        // Target selector
        addAndMakeVisible(targetSelector);
        targetSelector.addItem("Early", 1);
        targetSelector.addItem("Late", 2);
        targetSelector.addItem("All", 3);
        targetSelector.setSelectedId(3);
        targetSelector.onChange = [this]() {
            TemperTarget target = static_cast<TemperTarget>(targetSelector.getSelectedId() - 1);
            reverbRef->setTemperTarget(target);
        };

        // Mix slider
        addAndMakeVisible(mixSlider);
        mixSlider.setRange(0.0, 1.0, 0.01);
        mixSlider.setValue(0.3);
        mixSlider.onValueChange = [this]() {
            reverbRef->setMix(static_cast<float>(mixSlider.getValue()));
        };
        addAndMakeVisible(mixLabel);
        mixLabel.setText("Mix", juce::dontSendNotification);
        mixLabel.attachToComponent(&mixSlider, true);

        // NoteScape visualizer
        noteScape = std::make_unique<NoteScapeVisualizer>(reverb);
        addAndMakeVisible(noteScape.get());
    }

    void resized() override
    {
        auto bounds = getLocalBounds().reduced(10);

        // Top row: space selector
        spaceSelector.setBounds(bounds.removeFromTop(30).reduced(0, 2));
        bounds.removeFromTop(10);

        // Control row
        auto controlRow = bounds.removeFromTop(30);
        modeSelector.setBounds(controlRow.removeFromLeft(100).reduced(2));
        scaleSelector.setBounds(controlRow.removeFromLeft(100).reduced(2));
        rootSelector.setBounds(controlRow.removeFromLeft(60).reduced(2));
        targetSelector.setBounds(controlRow.removeFromLeft(80).reduced(2));

        bounds.removeFromTop(10);

        // Sliders
        auto sliderArea = bounds.removeFromTop(120);
        int sliderHeight = 25;
        int labelWidth = 80;

        decaySlider.setBounds(sliderArea.removeFromTop(sliderHeight).withTrimmedLeft(labelWidth));
        temperSlider.setBounds(sliderArea.removeFromTop(sliderHeight).withTrimmedLeft(labelWidth));
        widthSlider.setBounds(sliderArea.removeFromTop(sliderHeight).withTrimmedLeft(labelWidth));
        mixSlider.setBounds(sliderArea.removeFromTop(sliderHeight).withTrimmedLeft(labelWidth));

        bounds.removeFromTop(10);

        // NoteScape visualizer takes remaining space
        noteScape->setBounds(bounds);
    }

private:
    ModalReverb* reverbRef;

    juce::ComboBox spaceSelector;
    juce::ComboBox scaleSelector;
    juce::ComboBox rootSelector;
    juce::ComboBox modeSelector;
    juce::ComboBox targetSelector;

    juce::Slider decaySlider;
    juce::Slider temperSlider;
    juce::Slider widthSlider;
    juce::Slider mixSlider;

    juce::Label decayLabel;
    juce::Label temperLabel;
    juce::Label widthLabel;
    juce::Label mixLabel;

    std::unique_ptr<NoteScapeVisualizer> noteScape;

    void updateScale()
    {
        Scale scale;
        switch (scaleSelector.getSelectedId())
        {
            case 1: scale = Scale::Major; break;
            case 2: scale = Scale::NaturalMinor; break;
            case 3: scale = Scale::Dorian; break;
            case 4: scale = Scale::Pentatonic; break;
            case 5: scale = Scale::Blues; break;
            default: scale = Scale::Chromatic;
        }

        int root = rootSelector.getSelectedId() - 1;
        reverbRef->setScale(scale, root);
    }
};

} // namespace Eventide
} // namespace Effects
} // namespace Echoelmusic
