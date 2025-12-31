#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <memory>

/**
 * BreakbeatEngine - Professional Breakbeat Processing System
 *
 * Complete breakbeat manipulation inspired by classic jungle/DnB production.
 * Handles loading, slicing, time-stretching, and real-time manipulation of breaks.
 *
 * Features:
 * - Classic break library (Amen, Think, Apache, Funky Drummer, etc.)
 * - Transient-aware automatic slicing
 * - Beat-preserving time-stretching
 * - Real-time pitch/time manipulation
 * - Break layering and blending
 * - Ghost note generation
 * - Swing and humanization
 * - Bio-reactive break manipulation
 *
 * Inspired by: Propellerhead ReCycle, Native Instruments Battery, Serato Sample
 */
class BreakbeatEngine
{
public:
    //==========================================================================
    // Classic Break Types
    //==========================================================================

    enum class ClassicBreak
    {
        Amen,              // The Winstons - Amen Brother (1969)
        Think,             // Lyn Collins - Think (1972)
        Apache,            // Incredible Bongo Band - Apache (1973)
        FunkyDrummer,      // James Brown - Funky Drummer (1970)
        Impeach,           // The Honey Drippers - Impeach the President (1973)
        Skull,             // Skull Snaps - It's a New Day (1973)
        HotPants,          // Bobby Byrd - Hot Pants (1971)
        Synthetic,         // Synthetic Substitution (1973)
        Ashley,            // Ashley's Roachclip (1974)
        Soul,              // Soul Pride (1969)
        GoodTimes,         // Chic - Good Times (1979)
        LookOfLove,        // ABC - Look of Love (1982)
        Custom             // User-loaded break
    };

    //==========================================================================
    // Slice Data
    //==========================================================================

    struct Slice
    {
        int startSample = 0;
        int endSample = 0;
        float velocity = 1.0f;        // Detected velocity/energy
        float pitch = 0.0f;           // Pitch offset in semitones
        bool isTransient = true;      // True if slice starts on transient
        int midiNote = 36;            // Assigned MIDI note (C1 = 36)

        // Per-slice effects
        float filterCutoff = 1.0f;    // 0.0 to 1.0 (normalized)
        float pan = 0.5f;             // 0.0 (L) to 1.0 (R)
        float attack = 0.0f;          // ms
        float decay = 0.0f;           // ms
        bool reverse = false;
        bool mute = false;
    };

    //==========================================================================
    // Break Data
    //==========================================================================

    struct Break
    {
        juce::AudioBuffer<float> audioData;
        double sourceSampleRate = 44100.0;
        std::string name;
        float originalBPM = 0.0f;     // Detected or set BPM
        int numBars = 1;              // Number of bars in break
        int beatsPerBar = 4;          // Time signature

        std::vector<Slice> slices;

        // Calculated values
        int samplesPerBeat() const {
            if (originalBPM <= 0) return 0;
            return static_cast<int>(sourceSampleRate * 60.0 / originalBPM);
        }
    };

    //==========================================================================
    // Pattern Step
    //==========================================================================

    struct PatternStep
    {
        int sliceIndex = -1;          // -1 = rest
        float velocity = 1.0f;
        float pitch = 0.0f;           // Semitones
        bool reverse = false;
        bool roll = false;            // Drum roll / retrigger
        int rollDivision = 4;         // Roll speed (1/4, 1/8, 1/16, etc.)
        float probability = 1.0f;     // 0.0 to 1.0 (chance to play)
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    BreakbeatEngine();
    ~BreakbeatEngine() = default;

    //==========================================================================
    // Break Management
    //==========================================================================

    /** Load a classic break from built-in library */
    void loadClassicBreak(ClassicBreak breakType);

    /** Load break from audio file */
    bool loadBreakFromFile(const juce::File& audioFile);

    /** Load break from audio buffer */
    void loadBreakFromBuffer(const juce::AudioBuffer<float>& buffer,
                             double sampleRate, const std::string& name);

    /** Get current break */
    const Break& getCurrentBreak() const { return currentBreak; }

    /** Set original BPM (for tempo sync) */
    void setOriginalBPM(float bpm);

    //==========================================================================
    // Slicing
    //==========================================================================

    enum class SliceMode
    {
        Transient,         // Slice on detected transients
        Grid,              // Equal grid slicing (8, 16, 32 slices)
        Manual,            // User-defined slice points
        Beat,              // Slice on beats
        Bar                // Slice on bars
    };

    /** Auto-slice the current break */
    void autoSlice(SliceMode mode, int numSlices = 16);

    /** Set transient detection sensitivity (0.0 to 1.0) */
    void setTransientSensitivity(float sensitivity);

    /** Add manual slice point */
    void addSlicePoint(int samplePosition);

    /** Remove slice at index */
    void removeSlice(int index);

    /** Get slice count */
    int getSliceCount() const { return static_cast<int>(currentBreak.slices.size()); }

    /** Get slice by index */
    Slice& getSlice(int index);
    const Slice& getSlice(int index) const;

    //==========================================================================
    // Playback Controls
    //==========================================================================

    /** Set target BPM (time-stretches break to match) */
    void setTargetBPM(float bpm);

    /** Set pitch shift (semitones, independent of tempo) */
    void setPitchShift(float semitones);

    /** Set playback direction */
    void setReverse(bool reverse);

    /** Set swing amount (0.0 to 1.0) */
    void setSwing(float amount);

    /** Set humanization (timing randomness) */
    void setHumanize(float amount);

    /** Trigger specific slice */
    void triggerSlice(int sliceIndex, float velocity = 1.0f);

    /** Stop all playback */
    void stop();

    //==========================================================================
    // Pattern Sequencer
    //==========================================================================

    /** Set pattern length (steps) */
    void setPatternLength(int steps);

    /** Set pattern step */
    void setPatternStep(int stepIndex, const PatternStep& step);

    /** Get pattern step */
    PatternStep getPatternStep(int stepIndex) const;

    /** Clear pattern */
    void clearPattern();

    /** Generate random pattern */
    void generateRandomPattern(float density = 0.75f);

    /** Generate classic jungle pattern */
    void generateJunglePattern();

    //==========================================================================
    // Effects
    //==========================================================================

    /** Set master filter cutoff (affects all slices) */
    void setFilterCutoff(float frequency);

    /** Set filter resonance */
    void setFilterResonance(float resonance);

    /** Set distortion/saturation amount */
    void setDistortion(float amount);

    /** Set bit crush amount (0.0 = off, 1.0 = heavy) */
    void setBitCrush(float amount);

    /** Set vinyl/tape simulation */
    void setVinylSim(float amount);

    /** Set ghost note volume (quiet hits between main hits) */
    void setGhostNoteLevel(float level);

    //==========================================================================
    // Break Layering
    //==========================================================================

    /** Add layer break */
    void addLayerBreak(const Break& layer, float mixLevel = 0.5f);

    /** Set layer mix level */
    void setLayerMixLevel(int layerIndex, float level);

    /** Remove layer */
    void removeLayer(int layerIndex);

    /** Get layer count */
    int getLayerCount() const { return static_cast<int>(layerBreaks.size()); }

    //==========================================================================
    // Bio-Reactive
    //==========================================================================

    void setBioReactiveEnabled(bool enabled);
    void setBioData(float hrv, float coherence, float energy);
    void setBioToSwing(float amount);      // Bio → swing amount
    void setBioToFilter(float amount);     // Bio → filter cutoff
    void setBioToChop(float amount);       // Bio → chop intensity

    //==========================================================================
    // Processing
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize);
    void reset();
    void process(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midiMessages);

    /** Process single slice (for external triggering) */
    void processSlice(int sliceIndex, juce::AudioBuffer<float>& buffer,
                      int startSample, int numSamples, float velocity = 1.0f);

    //==========================================================================
    // Presets
    //==========================================================================

    enum class Preset
    {
        Classic,           // Original break, no processing
        Chopped,           // Heavy chop/rearrange
        Timestretched,     // Stretched for slower tempos
        Pitched,           // Pitch-shifted jungle style
        Crushed,           // Lo-fi crushed
        Layered,           // Multiple breaks layered
        Atmospheric,       // Reverb/delay heavy
        Hardcore           // Fast, distorted
    };

    void loadPreset(Preset preset);

private:
    //==========================================================================
    // State
    //==========================================================================

    Break currentBreak;
    std::vector<Break> layerBreaks;
    std::vector<float> layerMixLevels;

    double currentSampleRate = 48000.0;
    float targetBPM = 170.0f;          // Default jungle tempo
    float pitchShift = 0.0f;
    bool reverse = false;
    float swing = 0.0f;
    float humanize = 0.0f;
    float transientSensitivity = 0.5f;

    // Effects
    float filterCutoff = 20000.0f;
    float filterResonance = 0.0f;
    float distortion = 0.0f;
    float bitCrush = 0.0f;
    float vinylSim = 0.0f;
    float ghostNoteLevel = 0.3f;

    // Pattern
    std::vector<PatternStep> pattern;
    int patternLength = 16;
    int currentStep = 0;
    double stepPosition = 0.0;

    // Bio-reactive
    bool bioReactiveEnabled = false;
    float bioHRV = 0.5f;
    float bioCoherence = 0.5f;
    float bioEnergy = 0.5f;
    float bioToSwing = 0.3f;
    float bioToFilter = 0.3f;
    float bioToChop = 0.2f;

    // Playback state
    struct PlayingSlice
    {
        int sliceIndex = -1;
        double position = 0.0;
        float velocity = 1.0f;
        float pitch = 0.0f;
        bool reverse = false;
        bool active = false;
    };
    std::array<PlayingSlice, 16> playingSlices;

    // Filter state
    float filterZ1 = 0.0f, filterZ2 = 0.0f;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void detectTransients(std::vector<int>& transientPositions);
    float calculateSliceVelocity(int startSample, int endSample);
    void initializeClassicBreaks();
    float applyTimeStretch(float position, float stretchRatio);
    float applyPitchShift(float sample, float semitones);
    float applyFilter(float sample);
    float applyDistortion(float sample, float amount);
    float applyBitCrush(float sample, float amount);

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(BreakbeatEngine)
};
