#pragma once

#include <JuceHeader.h>
#include <vector>
#include <map>
#include <memory>
#include <array>
#include <functional>
#include <atomic>

/**
 * GrooveboxMode - Standalone Pattern-Based Beat Making
 *
 * Inspired by: Imaginando BAM, Elektron Digitakt, Roland TR-8S
 *
 * Complete groovebox in your DAW:
 * - 16-pad drum machine with velocity sensitivity
 * - 8 synth tracks with built-in engines
 * - Pattern sequencer (1-64 steps)
 * - Song mode with pattern chaining
 * - Performance FX per track
 * - Real-time pattern manipulation
 * - Instant export to DAW timeline
 *
 * Unique Echoelmusic UPS:
 * - Bio-reactive pattern generation
 * - AI-assisted beat creation
 * - Quantum randomization
 * - Cross-platform (iOS/Android/Desktop)
 */

namespace Echoelmusic {
namespace Modes {

//==============================================================================
// Drum Pad
//==============================================================================

struct DrumPad
{
    int padIndex;                   // 0-15
    std::string name;               // "Kick", "Snare", etc.
    std::string samplePath;         // Sample file
    juce::AudioBuffer<float> sample;

    // Synthesis (when no sample)
    enum class SynthType { Sample, Analog, FM, Noise, Physical } synthType = SynthType::Sample;

    // Pad settings
    float volume = 1.0f;
    float pan = 0.0f;
    float pitch = 0.0f;             // Semitones
    float decay = 0.5f;
    float attack = 0.0f;

    // Effects
    float filterCutoff = 1.0f;
    float filterReso = 0.0f;
    float drive = 0.0f;
    float reverb = 0.0f;
    float delay = 0.0f;

    // Performance
    bool muted = false;
    bool solo = false;
    int midiNote = 36;              // C1 default for kick
    juce::Colour color = juce::Colours::grey;
};

//==============================================================================
// Step Sequencer
//==============================================================================

struct Step
{
    bool active = false;
    float velocity = 0.8f;
    float probability = 1.0f;       // 0-1, chance to trigger
    int microTiming = 0;            // -50 to +50 (percentage of step)
    int retrigger = 0;              // 0 = off, 2-8 = retrigger count
    float pitch = 0.0f;             // Pitch offset
    bool slide = false;             // Portamento to next note
    bool accent = false;
};

struct Pattern
{
    std::string name = "Pattern 1";
    int length = 16;                // 1-64 steps
    float swing = 0.0f;             // -100 to +100
    int bpm = 120;                  // Pattern-specific tempo (0 = use global)

    // 16 tracks x 64 steps
    std::array<std::array<Step, 64>, 16> tracks;

    // Pattern settings
    float masterVolume = 1.0f;
    bool quantize = true;
    int timeSignature = 4;          // 3, 4, 5, 6, 7

    Step& getStep(int track, int step)
    {
        return tracks[track % 16][step % 64];
    }
};

//==============================================================================
// Song Mode
//==============================================================================

struct SongSection
{
    int patternIndex;
    int repeats = 1;
    float tempoMultiplier = 1.0f;
};

struct Song
{
    std::string name = "Untitled";
    std::vector<SongSection> sections;
    int currentSection = 0;
    int currentRepeat = 0;
};

//==============================================================================
// Synth Track
//==============================================================================

struct SynthTrack
{
    int trackIndex;                 // 0-7
    std::string name;

    enum class Engine {
        Subtractive,
        FM,
        Wavetable,
        Physical,
        Sampler,
        Granular,
        Additive,
        Neural                      // AI-powered
    } engine = Engine::Subtractive;

    // Oscillators
    struct Oscillator
    {
        enum class Waveform { Sine, Triangle, Saw, Square, Noise, Wavetable };
        Waveform waveform = Waveform::Saw;
        float detune = 0.0f;
        float level = 1.0f;
        int octave = 0;
        int semitone = 0;
    };
    std::array<Oscillator, 3> oscillators;

    // Filter
    enum class FilterType { LowPass, HighPass, BandPass, Notch, Ladder, Comb };
    FilterType filterType = FilterType::LowPass;
    float filterCutoff = 1.0f;
    float filterResonance = 0.0f;
    float filterEnvAmount = 0.5f;

    // Envelopes
    struct ADSR { float a = 0.01f, d = 0.3f, s = 0.5f, r = 0.3f; };
    ADSR ampEnv;
    ADSR filterEnv;

    // LFO
    struct LFO
    {
        enum class Shape { Sine, Triangle, Square, SawUp, SawDown, Random };
        Shape shape = Shape::Sine;
        float rate = 1.0f;
        float depth = 0.0f;
        enum class Dest { Pitch, Filter, Amp, Pan } destination = Dest::Filter;
    };
    std::array<LFO, 2> lfos;

    // Effects
    float drive = 0.0f;
    float chorus = 0.0f;
    float reverb = 0.0f;
    float delay = 0.0f;

    // Mixer
    float volume = 0.8f;
    float pan = 0.0f;
    bool muted = false;
    bool solo = false;
};

//==============================================================================
// Performance FX
//==============================================================================

class PerformanceFX
{
public:
    enum class FXType
    {
        None,
        Filter,         // Sweep filter
        Delay,          // Ping-pong delay
        Reverb,         // Freeze reverb
        Stutter,        // Beat repeat
        BitCrush,       // Lo-fi
        Phaser,         // Jet sound
        Flanger,        // Metallic sweep
        Gate,           // Trance gate
        Slicer,         // Beat slice
        Tape,           // Tape stop/start
        Vinyl,          // Vinyl scratch
        Granular,       // Freeze/stretch
        Pitch,          // Pitch shift
        Reverse,        // Reverse playback
        Pan             // Auto-pan
    };

    FXType type = FXType::None;
    float amount = 0.0f;            // 0-1 (XY pad control)
    float param1 = 0.5f;            // X axis
    float param2 = 0.5f;            // Y axis

    void process(juce::AudioBuffer<float>& buffer)
    {
        if (type == FXType::None || amount < 0.01f)
            return;

        switch (type)
        {
            case FXType::Filter:
                processFilter(buffer);
                break;
            case FXType::Stutter:
                processStutter(buffer);
                break;
            case FXType::BitCrush:
                processBitCrush(buffer);
                break;
            case FXType::Gate:
                processGate(buffer);
                break;
            case FXType::Tape:
                processTape(buffer);
                break;
            default:
                break;
        }
    }

private:
    void processFilter(juce::AudioBuffer<float>& buffer)
    {
        float cutoff = param1 * param1 * 20000.0f + 20.0f;
        // Apply resonant filter sweep
    }

    void processStutter(juce::AudioBuffer<float>& buffer)
    {
        // Repeat small chunks of audio
        int chunkSize = static_cast<int>((1.0f - param1) * 4096) + 64;
        // Implement beat repeat
    }

    void processBitCrush(juce::AudioBuffer<float>& buffer)
    {
        float bitDepth = 1.0f + (1.0f - param1) * 15.0f;
        float sampleRate = 1000.0f + param2 * 47000.0f;
        // Reduce bit depth and sample rate
    }

    void processGate(juce::AudioBuffer<float>& buffer)
    {
        // Rhythmic volume gate
    }

    void processTape(juce::AudioBuffer<float>& buffer)
    {
        // Tape stop/start effect
    }
};

//==============================================================================
// Groovebox Engine
//==============================================================================

class GrooveboxEngine
{
public:
    static GrooveboxEngine& getInstance()
    {
        static GrooveboxEngine instance;
        return instance;
    }

    //--------------------------------------------------------------------------
    // Initialization
    //--------------------------------------------------------------------------

    void prepare(double sampleRate, int blockSize)
    {
        this->sampleRate = sampleRate;
        this->blockSize = blockSize;

        // Initialize 16 drum pads
        for (int i = 0; i < 16; ++i)
        {
            pads[i].padIndex = i;
            pads[i].name = getDefaultPadName(i);
            pads[i].midiNote = 36 + i;  // C1 to D#2
            pads[i].color = getDefaultPadColor(i);
        }

        // Initialize 8 synth tracks
        for (int i = 0; i < 8; ++i)
        {
            synthTracks[i].trackIndex = i;
            synthTracks[i].name = "Synth " + std::to_string(i + 1);
        }

        // Initialize patterns
        for (int i = 0; i < 64; ++i)
        {
            patterns[i].name = "Pattern " + std::to_string(i + 1);
        }
    }

    //--------------------------------------------------------------------------
    // Transport
    //--------------------------------------------------------------------------

    void play() { isPlaying = true; }
    void stop() { isPlaying = false; currentStep = 0; }
    void pause() { isPlaying = false; }

    bool isCurrentlyPlaying() const { return isPlaying; }
    int getCurrentStep() const { return currentStep; }

    void setTempo(float bpm)
    {
        this->bpm = std::clamp(bpm, 20.0f, 300.0f);
        samplesPerStep = static_cast<int>((60.0 / bpm / 4.0) * sampleRate);
    }

    float getTempo() const { return bpm; }

    //--------------------------------------------------------------------------
    // Pattern Management
    //--------------------------------------------------------------------------

    Pattern& getCurrentPattern() { return patterns[currentPatternIndex]; }
    Pattern& getPattern(int index) { return patterns[index % 64]; }

    void selectPattern(int index)
    {
        if (index >= 0 && index < 64)
            currentPatternIndex = index;
    }

    void copyPattern(int from, int to)
    {
        if (from >= 0 && from < 64 && to >= 0 && to < 64)
            patterns[to] = patterns[from];
    }

    void clearPattern(int index)
    {
        if (index >= 0 && index < 64)
            patterns[index] = Pattern();
    }

    //--------------------------------------------------------------------------
    // Step Editing
    //--------------------------------------------------------------------------

    void toggleStep(int track, int step)
    {
        auto& s = getCurrentPattern().getStep(track, step);
        s.active = !s.active;
    }

    void setStepVelocity(int track, int step, float velocity)
    {
        getCurrentPattern().getStep(track, step).velocity = std::clamp(velocity, 0.0f, 1.0f);
    }

    void setStepProbability(int track, int step, float prob)
    {
        getCurrentPattern().getStep(track, step).probability = std::clamp(prob, 0.0f, 1.0f);
    }

    //--------------------------------------------------------------------------
    // Pad Triggering
    //--------------------------------------------------------------------------

    void triggerPad(int padIndex, float velocity = 1.0f)
    {
        if (padIndex >= 0 && padIndex < 16)
        {
            padTriggers[padIndex] = velocity;
            if (recordEnabled && isPlaying)
            {
                // Record to current step
                getCurrentPattern().getStep(padIndex, currentStep).active = true;
                getCurrentPattern().getStep(padIndex, currentStep).velocity = velocity;
            }
        }
    }

    void releasePad(int padIndex)
    {
        if (padIndex >= 0 && padIndex < 16)
            padTriggers[padIndex] = 0.0f;
    }

    //--------------------------------------------------------------------------
    // Audio Processing
    //--------------------------------------------------------------------------

    void processBlock(juce::AudioBuffer<float>& buffer)
    {
        if (!isPlaying)
        {
            // Still process triggered pads when stopped
            processPads(buffer);
            return;
        }

        int numSamples = buffer.getNumSamples();
        int samplesProcessed = 0;

        while (samplesProcessed < numSamples)
        {
            int samplesToNextStep = samplesPerStep - sampleCounter;
            int samplesToProcess = std::min(samplesToNextStep, numSamples - samplesProcessed);

            // Process current step
            if (sampleCounter == 0)
            {
                triggerStep(currentStep);
            }

            // Process audio
            juce::AudioBuffer<float> subBuffer(buffer.getArrayOfWritePointers(),
                                                buffer.getNumChannels(),
                                                samplesProcessed,
                                                samplesToProcess);
            processPads(subBuffer);
            processSynths(subBuffer);
            processPerformanceFX(subBuffer);

            sampleCounter += samplesToProcess;
            samplesProcessed += samplesToProcess;

            // Advance step
            if (sampleCounter >= samplesPerStep)
            {
                sampleCounter = 0;
                currentStep = (currentStep + 1) % getCurrentPattern().length;
            }
        }
    }

    //--------------------------------------------------------------------------
    // Record Mode
    //--------------------------------------------------------------------------

    void enableRecord(bool enable) { recordEnabled = enable; }
    bool isRecording() const { return recordEnabled; }

    //--------------------------------------------------------------------------
    // AI Features
    //--------------------------------------------------------------------------

    void generateBeat(const std::string& style, float complexity)
    {
        // AI-generated beat based on style
        // Uses PatternGenerator from AI systems
    }

    void humanize(float amount)
    {
        // Add micro-timing and velocity variation
        for (int t = 0; t < 16; ++t)
        {
            for (int s = 0; s < getCurrentPattern().length; ++s)
            {
                auto& step = getCurrentPattern().getStep(t, s);
                if (step.active)
                {
                    step.velocity *= (1.0f + (rand() / static_cast<float>(RAND_MAX) - 0.5f) * amount * 0.3f);
                    step.microTiming = static_cast<int>((rand() / static_cast<float>(RAND_MAX) - 0.5f) * amount * 20);
                }
            }
        }
    }

    void quantize(int division = 16)
    {
        // Snap all steps to grid
        for (int t = 0; t < 16; ++t)
        {
            for (int s = 0; s < getCurrentPattern().length; ++s)
            {
                getCurrentPattern().getStep(t, s).microTiming = 0;
            }
        }
    }

    //--------------------------------------------------------------------------
    // Export
    //--------------------------------------------------------------------------

    juce::MidiMessageSequence exportToMIDI()
    {
        juce::MidiMessageSequence sequence;
        double ticksPerStep = 480.0 / 4.0;  // PPQ / steps per beat

        for (int t = 0; t < 16; ++t)
        {
            for (int s = 0; s < getCurrentPattern().length; ++s)
            {
                auto& step = getCurrentPattern().getStep(t, s);
                if (step.active)
                {
                    double startTime = s * ticksPerStep;
                    double endTime = startTime + ticksPerStep * 0.9;

                    int velocity = static_cast<int>(step.velocity * 127);
                    int note = pads[t].midiNote;

                    sequence.addEvent(juce::MidiMessage::noteOn(1, note, static_cast<uint8_t>(velocity)), startTime);
                    sequence.addEvent(juce::MidiMessage::noteOff(1, note), endTime);
                }
            }
        }

        sequence.sort();
        return sequence;
    }

    void exportToDAWTimeline()
    {
        // Export current pattern as MIDI clip to DAW timeline
        auto midi = exportToMIDI();
        // Integration with DAW timeline system
    }

    //--------------------------------------------------------------------------
    // Accessors
    //--------------------------------------------------------------------------

    DrumPad& getPad(int index) { return pads[index % 16]; }
    SynthTrack& getSynthTrack(int index) { return synthTracks[index % 8]; }
    PerformanceFX& getPerformanceFX() { return performanceFX; }

private:
    GrooveboxEngine() = default;

    // Audio
    double sampleRate = 44100.0;
    int blockSize = 512;
    int samplesPerStep = 5512;      // At 120 BPM
    int sampleCounter = 0;

    // Transport
    std::atomic<bool> isPlaying{false};
    float bpm = 120.0f;
    int currentStep = 0;

    // Patterns
    std::array<Pattern, 64> patterns;
    int currentPatternIndex = 0;

    // Instruments
    std::array<DrumPad, 16> pads;
    std::array<SynthTrack, 8> synthTracks;
    std::array<float, 16> padTriggers{};

    // FX
    PerformanceFX performanceFX;

    // Record
    bool recordEnabled = false;

    // Song
    Song song;
    bool songMode = false;

    void triggerStep(int step)
    {
        auto& pattern = getCurrentPattern();
        for (int t = 0; t < 16; ++t)
        {
            auto& s = pattern.getStep(t, step);
            if (s.active)
            {
                // Check probability
                if (s.probability >= 1.0f ||
                    (rand() / static_cast<float>(RAND_MAX)) < s.probability)
                {
                    padTriggers[t] = s.velocity;
                }
            }
        }
    }

    void processPads(juce::AudioBuffer<float>& buffer)
    {
        // Process all triggered pads
        for (int p = 0; p < 16; ++p)
        {
            if (padTriggers[p] > 0.0f)
            {
                // Render pad sample/synth into buffer
                // Apply pad settings (pitch, filter, etc.)
            }
        }
    }

    void processSynths(juce::AudioBuffer<float>& buffer)
    {
        // Process all synth tracks
    }

    void processPerformanceFX(juce::AudioBuffer<float>& buffer)
    {
        performanceFX.process(buffer);
    }

    std::string getDefaultPadName(int index)
    {
        static const char* names[] = {
            "Kick", "Snare", "Clap", "Rim",
            "HH Closed", "HH Open", "Tom Low", "Tom Mid",
            "Tom High", "Crash", "Ride", "Shaker",
            "Perc 1", "Perc 2", "FX 1", "FX 2"
        };
        return names[index % 16];
    }

    juce::Colour getDefaultPadColor(int index)
    {
        static juce::Colour colors[] = {
            juce::Colours::red, juce::Colours::orange, juce::Colours::yellow, juce::Colours::lime,
            juce::Colours::cyan, juce::Colours::blue, juce::Colours::purple, juce::Colours::magenta,
            juce::Colours::red, juce::Colours::orange, juce::Colours::yellow, juce::Colours::lime,
            juce::Colours::cyan, juce::Colours::blue, juce::Colours::purple, juce::Colours::magenta
        };
        return colors[index % 16];
    }
};

//==============================================================================
// Convenience
//==============================================================================

#define Groovebox GrooveboxEngine::getInstance()

} // namespace Modes
} // namespace Echoelmusic
