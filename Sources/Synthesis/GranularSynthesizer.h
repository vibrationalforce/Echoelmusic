#pragma once

#include <JuceHeader.h>
#include <array>
#include <vector>
#include <random>
#include <cmath>
#include <memory>
#include <algorithm>
#include <queue>

/**
 * GranularSynthesizer - Professional Granular Synthesis Engine
 *
 * A comprehensive granular synthesis engine with:
 * - Real-time grain cloud generation
 * - Multiple grain window shapes
 * - Position, density, and spray controls
 * - Pitch and time manipulation
 * - Modulation sources (LFO, envelope, random)
 * - Bio-reactive grain control
 * - Multi-source blending
 * - Freeze/stutter effects
 *
 * Inspired by: Granulator II, Quanta, Padshop
 */

namespace Echoelmusic {
namespace Synthesis {

//==============================================================================
// Grain Window Shapes
//==============================================================================

enum class GrainWindow
{
    Hann,           // Smooth, symmetric
    Gaussian,       // Bell curve
    Triangle,       // Linear ramp up/down
    Trapezoid,      // Flat top with ramps
    Tukey,          // Cosine-tapered
    Blackman,       // Steeper rolloff
    Kaiser,         // Adjustable beta parameter
    Exponential,    // Attack-focused
    ReversedExp,    // Decay-focused
    Random          // Per-grain random
};

//==============================================================================
// Modulation Source
//==============================================================================

enum class ModulationSource
{
    None,
    LFO1,
    LFO2,
    Envelope,
    Random,
    MIDI_Velocity,
    MIDI_ModWheel,
    MIDI_Aftertouch,
    BioHRV,
    BioCoherence
};

//==============================================================================
// Individual Grain
//==============================================================================

struct Grain
{
    bool active = false;

    // Source
    int sourceIndex = 0;            // Which source buffer
    double sourcePosition = 0.0;     // Position in source (0-1)
    double playbackPosition = 0.0;   // Current position within grain

    // Grain parameters
    int grainSizeSamples = 2048;
    float pitch = 1.0f;             // Playback speed multiplier
    float amplitude = 1.0f;
    float pan = 0.0f;               // -1 to +1

    // Window
    GrainWindow windowType = GrainWindow::Hann;
    std::vector<float> windowBuffer;

    // Reverse playback
    bool reverse = false;

    void start(int sizeSamples, GrainWindow window, double srcPos,
               float pitchMult, float amp, float panPos, bool rev = false)
    {
        active = true;
        grainSizeSamples = sizeSamples;
        windowType = window;
        sourcePosition = srcPos;
        playbackPosition = rev ? sizeSamples - 1 : 0;
        pitch = pitchMult;
        amplitude = amp;
        pan = panPos;
        reverse = rev;

        generateWindow();
    }

    void generateWindow()
    {
        windowBuffer.resize(grainSizeSamples);

        for (int i = 0; i < grainSizeSamples; ++i)
        {
            float phase = static_cast<float>(i) / (grainSizeSamples - 1);

            switch (windowType)
            {
                case GrainWindow::Hann:
                    windowBuffer[i] = 0.5f * (1.0f - std::cos(2.0f * juce::MathConstants<float>::pi * phase));
                    break;

                case GrainWindow::Gaussian:
                {
                    float sigma = 0.4f;
                    float x = (phase - 0.5f) / sigma;
                    windowBuffer[i] = std::exp(-0.5f * x * x);
                    break;
                }

                case GrainWindow::Triangle:
                    windowBuffer[i] = 1.0f - std::abs(2.0f * phase - 1.0f);
                    break;

                case GrainWindow::Trapezoid:
                {
                    float attack = 0.2f, sustain = 0.6f;
                    if (phase < attack)
                        windowBuffer[i] = phase / attack;
                    else if (phase < attack + sustain)
                        windowBuffer[i] = 1.0f;
                    else
                        windowBuffer[i] = (1.0f - phase) / (1.0f - attack - sustain);
                    break;
                }

                case GrainWindow::Tukey:
                {
                    float alpha = 0.5f;
                    if (phase < alpha / 2)
                        windowBuffer[i] = 0.5f * (1 + std::cos(juce::MathConstants<float>::pi * (2 * phase / alpha - 1)));
                    else if (phase < 1 - alpha / 2)
                        windowBuffer[i] = 1.0f;
                    else
                        windowBuffer[i] = 0.5f * (1 + std::cos(juce::MathConstants<float>::pi * (2 * phase / alpha - 2 / alpha + 1)));
                    break;
                }

                case GrainWindow::Blackman:
                {
                    float a0 = 0.42f, a1 = 0.5f, a2 = 0.08f;
                    windowBuffer[i] = a0 - a1 * std::cos(2 * juce::MathConstants<float>::pi * phase)
                                        + a2 * std::cos(4 * juce::MathConstants<float>::pi * phase);
                    break;
                }

                case GrainWindow::Kaiser:
                {
                    float beta = 8.0f;
                    float x = 2.0f * phase - 1.0f;
                    // Simplified Kaiser approximation
                    windowBuffer[i] = std::pow(1.0f - x * x, beta / 10.0f);
                    break;
                }

                case GrainWindow::Exponential:
                {
                    float attack = 0.1f;
                    if (phase < attack)
                        windowBuffer[i] = phase / attack;
                    else
                        windowBuffer[i] = std::exp(-3.0f * (phase - attack) / (1.0f - attack));
                    break;
                }

                case GrainWindow::ReversedExp:
                {
                    float release = 0.1f;
                    if (phase > 1.0f - release)
                        windowBuffer[i] = (1.0f - phase) / release;
                    else
                        windowBuffer[i] = 1.0f - std::exp(-3.0f * phase / (1.0f - release));
                    break;
                }

                case GrainWindow::Random:
                default:
                    // Random window shape (choose at runtime)
                    windowBuffer[i] = 0.5f * (1.0f - std::cos(2.0f * juce::MathConstants<float>::pi * phase));
                    break;
            }
        }
    }

    float getWindowValue() const
    {
        if (!active || windowBuffer.empty())
            return 0.0f;

        int idx = static_cast<int>(playbackPosition);
        if (idx < 0 || idx >= static_cast<int>(windowBuffer.size()))
            return 0.0f;

        return windowBuffer[idx];
    }

    void advance(float speed)
    {
        if (reverse)
            playbackPosition -= speed;
        else
            playbackPosition += speed;

        if (playbackPosition >= grainSizeSamples || playbackPosition < 0)
            active = false;
    }
};

//==============================================================================
// LFO for Modulation
//==============================================================================

class GranularLFO
{
public:
    enum class Shape { Sine, Triangle, Saw, Square, SampleAndHold, Random };

    GranularLFO() = default;

    void setRate(float hz) { rate = hz; }
    void setShape(Shape s) { shape = s; }
    void setAmount(float amt) { amount = amt; }

    void prepare(double sampleRate)
    {
        fs = sampleRate;
        phase = 0.0;
    }

    float process()
    {
        float output = 0.0f;

        switch (shape)
        {
            case Shape::Sine:
                output = std::sin(2.0f * juce::MathConstants<float>::pi * static_cast<float>(phase));
                break;

            case Shape::Triangle:
                output = 2.0f * std::abs(2.0f * static_cast<float>(phase) - 1.0f) - 1.0f;
                break;

            case Shape::Saw:
                output = 2.0f * static_cast<float>(phase) - 1.0f;
                break;

            case Shape::Square:
                output = phase < 0.5 ? 1.0f : -1.0f;
                break;

            case Shape::SampleAndHold:
                if (phase < lastPhase) // Wrapped
                    holdValue = static_cast<float>(rand()) / RAND_MAX * 2.0f - 1.0f;
                output = holdValue;
                break;

            case Shape::Random:
                output = static_cast<float>(rand()) / RAND_MAX * 2.0f - 1.0f;
                break;
        }

        lastPhase = phase;
        phase += rate / fs;
        if (phase >= 1.0)
            phase -= 1.0;

        return output * amount;
    }

private:
    double fs = 48000.0;
    float rate = 1.0f;
    Shape shape = Shape::Sine;
    float amount = 1.0f;
    double phase = 0.0;
    double lastPhase = 0.0;
    float holdValue = 0.0f;
};

//==============================================================================
// Envelope Generator
//==============================================================================

class GranularEnvelope
{
public:
    void setADSR(float attack, float decay, float sustain, float release)
    {
        attackTime = attack;
        decayTime = decay;
        sustainLevel = sustain;
        releaseTime = release;
    }

    void prepare(double sampleRate) { fs = sampleRate; }

    void noteOn()
    {
        stage = Stage::Attack;
        level = 0.0f;
    }

    void noteOff()
    {
        stage = Stage::Release;
    }

    float process()
    {
        switch (stage)
        {
            case Stage::Attack:
                level += 1.0f / (attackTime * static_cast<float>(fs));
                if (level >= 1.0f)
                {
                    level = 1.0f;
                    stage = Stage::Decay;
                }
                break;

            case Stage::Decay:
                level -= (1.0f - sustainLevel) / (decayTime * static_cast<float>(fs));
                if (level <= sustainLevel)
                {
                    level = sustainLevel;
                    stage = Stage::Sustain;
                }
                break;

            case Stage::Sustain:
                level = sustainLevel;
                break;

            case Stage::Release:
                level -= sustainLevel / (releaseTime * static_cast<float>(fs));
                if (level <= 0.0f)
                {
                    level = 0.0f;
                    stage = Stage::Idle;
                }
                break;

            case Stage::Idle:
                level = 0.0f;
                break;
        }

        return level;
    }

    bool isActive() const { return stage != Stage::Idle; }
    float getLevel() const { return level; }

private:
    enum class Stage { Idle, Attack, Decay, Sustain, Release };

    double fs = 48000.0;
    Stage stage = Stage::Idle;
    float level = 0.0f;

    float attackTime = 0.01f;
    float decayTime = 0.1f;
    float sustainLevel = 0.7f;
    float releaseTime = 0.3f;
};

//==============================================================================
// GranularSynthesizer Main Class
//==============================================================================

class GranularSynthesizer
{
public:
    static constexpr int MaxGrains = 128;
    static constexpr int MaxSources = 4;

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    GranularSynthesizer()
    {
        grains.resize(MaxGrains);
        sourceBuffers.resize(MaxSources);

        std::random_device rd;
        rng.seed(rd());
    }

    ~GranularSynthesizer() = default;

    //==========================================================================
    // Preparation
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize)
    {
        currentSampleRate = sampleRate;
        blockSize = maxBlockSize;

        lfo1.prepare(sampleRate);
        lfo2.prepare(sampleRate);
        ampEnvelope.prepare(sampleRate);

        grainBuffer.setSize(2, maxBlockSize);
        outputBuffer.setSize(2, maxBlockSize);

        // Default grain size in samples
        grainSizeSamples = static_cast<int>(grainSizeMs * sampleRate / 1000.0);

        // Grain trigger interval
        updateGrainInterval();
    }

    //==========================================================================
    // Source Management
    //==========================================================================

    void loadSource(int index, const juce::AudioBuffer<float>& buffer, double sourceSampleRate)
    {
        if (index < 0 || index >= MaxSources)
            return;

        sourceBuffers[index] = buffer;
        sourceSampleRates[index] = sourceSampleRate;
    }

    void loadSource(int index, const juce::File& audioFile)
    {
        if (index < 0 || index >= MaxSources)
            return;

        juce::AudioFormatManager formatManager;
        formatManager.registerBasicFormats();

        std::unique_ptr<juce::AudioFormatReader> reader(
            formatManager.createReaderFor(audioFile));

        if (reader)
        {
            sourceBuffers[index].setSize(reader->numChannels,
                                         static_cast<int>(reader->lengthInSamples));
            reader->read(&sourceBuffers[index], 0,
                        static_cast<int>(reader->lengthInSamples), 0, true, true);
            sourceSampleRates[index] = reader->sampleRate;
        }
    }

    void clearSource(int index)
    {
        if (index >= 0 && index < MaxSources)
            sourceBuffers[index].clear();
    }

    //==========================================================================
    // Grain Parameters
    //==========================================================================

    /** Set grain size in milliseconds (1-2000 ms) */
    void setGrainSize(float sizeMs)
    {
        grainSizeMs = juce::jlimit(1.0f, 2000.0f, sizeMs);
        grainSizeSamples = static_cast<int>(grainSizeMs * currentSampleRate / 1000.0);
    }

    /** Set grain size variation (0-1) */
    void setGrainSizeVariation(float variation)
    {
        grainSizeVariation = juce::jlimit(0.0f, 1.0f, variation);
    }

    /** Set grain density (grains per second, 0.1-200) */
    void setDensity(float grainsPerSecond)
    {
        density = juce::jlimit(0.1f, 200.0f, grainsPerSecond);
        updateGrainInterval();
    }

    /** Set position in source (0-1) */
    void setPosition(float pos)
    {
        position = juce::jlimit(0.0f, 1.0f, pos);
    }

    /** Set position spray/randomization (0-1) */
    void setPositionSpray(float spray)
    {
        positionSpray = juce::jlimit(0.0f, 1.0f, spray);
    }

    /** Enable position scrubbing (follows position exactly) */
    void setScrubMode(bool enabled)
    {
        scrubMode = enabled;
    }

    /** Set pitch shift in semitones (-48 to +48) */
    void setPitch(float semitones)
    {
        pitchShift = juce::jlimit(-48.0f, 48.0f, semitones);
    }

    /** Set pitch variation in semitones (0-24) */
    void setPitchVariation(float semitones)
    {
        pitchVariation = juce::jlimit(0.0f, 24.0f, semitones);
    }

    /** Enable pitch quantization to musical intervals */
    void setPitchQuantize(bool enabled)
    {
        pitchQuantize = enabled;
    }

    /** Set window shape */
    void setWindowShape(GrainWindow shape)
    {
        windowShape = shape;
    }

    /** Set stereo spread (0-1) */
    void setStereoSpread(float spread)
    {
        stereoSpread = juce::jlimit(0.0f, 1.0f, spread);
    }

    /** Set reverse probability (0-1) */
    void setReverseProbability(float prob)
    {
        reverseProbability = juce::jlimit(0.0f, 1.0f, prob);
    }

    /** Set source blend (for multi-source, 0-1) */
    void setSourceBlend(float blend)
    {
        sourceBlend = juce::jlimit(0.0f, 1.0f, blend);
    }

    /** Select active source (0-3) */
    void setActiveSource(int source)
    {
        activeSource = juce::jlimit(0, MaxSources - 1, source);
    }

    //==========================================================================
    // Freeze & Stutter
    //==========================================================================

    /** Freeze playback at current position */
    void setFreeze(bool enabled)
    {
        frozen = enabled;
        if (frozen)
            freezePosition = position;
    }

    bool isFrozen() const { return frozen; }

    /** Stutter/retrigger effect */
    void triggerStutter(float stutterRate)
    {
        stuttering = true;
        stutterInterval = static_cast<int>(currentSampleRate / stutterRate);
        stutterCounter = 0;
    }

    void stopStutter()
    {
        stuttering = false;
    }

    //==========================================================================
    // Modulation
    //==========================================================================

    /** Configure LFO 1 */
    void setLFO1(float rate, GranularLFO::Shape shape, float amount)
    {
        lfo1.setRate(rate);
        lfo1.setShape(shape);
        lfo1.setAmount(amount);
    }

    /** Configure LFO 2 */
    void setLFO2(float rate, GranularLFO::Shape shape, float amount)
    {
        lfo2.setRate(rate);
        lfo2.setShape(shape);
        lfo2.setAmount(amount);
    }

    /** Set amplitude envelope ADSR (in seconds) */
    void setEnvelope(float attack, float decay, float sustain, float release)
    {
        ampEnvelope.setADSR(attack, decay, sustain, release);
    }

    /** Set modulation routing */
    void setModulationRouting(ModulationSource source, const juce::String& destination, float amount)
    {
        modRoutings[destination] = { source, amount };
    }

    //==========================================================================
    // Bio-Reactive Control
    //==========================================================================

    /** Set bio-feedback data for reactive synthesis */
    void setBioData(float hrv, float coherence)
    {
        bioHRV = juce::jlimit(0.0f, 1.0f, hrv);
        bioCoherence = juce::jlimit(0.0f, 1.0f, coherence);
    }

    /** Enable bio-reactive mode */
    void setBioReactiveEnabled(bool enabled)
    {
        bioReactiveEnabled = enabled;
    }

    //==========================================================================
    // MIDI Control
    //==========================================================================

    void noteOn(int midiNote, float velocity)
    {
        currentMidiNote = midiNote;
        currentVelocity = velocity;

        // Calculate pitch based on MIDI note
        int rootNote = 60; // C4
        float notePitch = std::pow(2.0f, (midiNote - rootNote) / 12.0f);
        midiPitchMultiplier = notePitch;

        ampEnvelope.noteOn();
        playing = true;
    }

    void noteOff()
    {
        ampEnvelope.noteOff();
    }

    void setModWheel(float value)
    {
        modWheelValue = value;
    }

    void setAftertouch(float value)
    {
        aftertouchValue = value;
    }

    //==========================================================================
    // Processing
    //==========================================================================

    void processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midiMessages)
    {
        // Handle MIDI messages
        for (const auto metadata : midiMessages)
        {
            auto message = metadata.getMessage();

            if (message.isNoteOn())
                noteOn(message.getNoteNumber(), message.getFloatVelocity());
            else if (message.isNoteOff())
                noteOff();
            else if (message.isController())
            {
                if (message.getControllerNumber() == 1) // Mod wheel
                    setModWheel(message.getControllerValue() / 127.0f);
            }
            else if (message.isAftertouch())
                setAftertouch(message.getAfterTouchValue() / 127.0f);
        }

        // Clear output
        buffer.clear();

        if (!playing || sourceBuffers[activeSource].getNumSamples() == 0)
            return;

        int numSamples = buffer.getNumSamples();

        // Process modulation
        processModulation(numSamples);

        // Process each sample
        for (int sample = 0; sample < numSamples; ++sample)
        {
            // Trigger new grains
            grainTriggerCounter++;
            if (grainTriggerCounter >= grainTriggerInterval)
            {
                grainTriggerCounter = 0;
                triggerGrain();
            }

            // Stutter retriggering
            if (stuttering)
            {
                stutterCounter++;
                if (stutterCounter >= stutterInterval)
                {
                    stutterCounter = 0;
                    // Kill all grains and retrigger
                    for (auto& grain : grains)
                        grain.active = false;
                    triggerGrain();
                }
            }

            // Process all active grains
            float outL = 0.0f;
            float outR = 0.0f;

            for (auto& grain : grains)
            {
                if (!grain.active)
                    continue;

                // Read from source
                float sourceValue = readSourceSample(grain);

                // Apply window
                float windowed = sourceValue * grain.getWindowValue() * grain.amplitude;

                // Apply panning
                float panL = std::cos((grain.pan + 1.0f) * 0.25f * juce::MathConstants<float>::pi);
                float panR = std::sin((grain.pan + 1.0f) * 0.25f * juce::MathConstants<float>::pi);

                outL += windowed * panL;
                outR += windowed * panR;

                // Advance grain
                grain.advance(grain.pitch);
            }

            // Apply envelope
            float envLevel = ampEnvelope.process();

            // Apply master volume and envelope
            outL *= masterVolume * envLevel;
            outR *= masterVolume * envLevel;

            // Write to buffer
            if (buffer.getNumChannels() >= 2)
            {
                buffer.addSample(0, sample, outL);
                buffer.addSample(1, sample, outR);
            }
            else if (buffer.getNumChannels() >= 1)
            {
                buffer.addSample(0, sample, (outL + outR) * 0.5f);
            }
        }

        // Check if envelope has finished
        if (!ampEnvelope.isActive())
            playing = false;
    }

    //==========================================================================
    // Master Controls
    //==========================================================================

    void setMasterVolume(float volume)
    {
        masterVolume = juce::jlimit(0.0f, 2.0f, volume);
    }

    void setMaxGrains(int maxGrains)
    {
        maxActiveGrains = juce::jlimit(1, MaxGrains, maxGrains);
    }

    //==========================================================================
    // State
    //==========================================================================

    int getActiveGrainCount() const
    {
        return std::count_if(grains.begin(), grains.end(),
                            [](const Grain& g) { return g.active; });
    }

    float getCurrentPosition() const { return frozen ? freezePosition : position; }

    //==========================================================================
    // Presets
    //==========================================================================

    enum class Preset
    {
        CloudPad,
        GlitchTexture,
        TimeStretch,
        SpectralFreeze,
        RhythmicGrain,
        AmbientDrone,
        VocalTexture,
        ReverseCloud,
        ShimmerPad,
        BioReactive
    };

    void loadPreset(Preset preset)
    {
        switch (preset)
        {
            case Preset::CloudPad:
                setGrainSize(80.0f);
                setDensity(30.0f);
                setPositionSpray(0.1f);
                setPitchVariation(0.1f);
                setStereoSpread(0.8f);
                setWindowShape(GrainWindow::Gaussian);
                setEnvelope(0.5f, 0.2f, 0.8f, 1.5f);
                break;

            case Preset::GlitchTexture:
                setGrainSize(10.0f);
                setGrainSizeVariation(0.9f);
                setDensity(100.0f);
                setPositionSpray(0.4f);
                setPitchVariation(12.0f);
                setStereoSpread(1.0f);
                setReverseProbability(0.3f);
                setWindowShape(GrainWindow::Random);
                break;

            case Preset::TimeStretch:
                setGrainSize(50.0f);
                setDensity(40.0f);
                setPositionSpray(0.02f);
                setPitchVariation(0.0f);
                setStereoSpread(0.2f);
                setWindowShape(GrainWindow::Hann);
                setScrubMode(true);
                break;

            case Preset::SpectralFreeze:
                setGrainSize(200.0f);
                setDensity(20.0f);
                setPositionSpray(0.01f);
                setPitchVariation(0.0f);
                setStereoSpread(0.5f);
                setWindowShape(GrainWindow::Blackman);
                setFreeze(true);
                break;

            case Preset::RhythmicGrain:
                setGrainSize(25.0f);
                setDensity(8.0f);
                setPositionSpray(0.0f);
                setPitchVariation(0.0f);
                setStereoSpread(0.3f);
                setWindowShape(GrainWindow::Trapezoid);
                break;

            case Preset::AmbientDrone:
                setGrainSize(500.0f);
                setDensity(5.0f);
                setPositionSpray(0.3f);
                setPitchVariation(0.5f);
                setStereoSpread(1.0f);
                setWindowShape(GrainWindow::Gaussian);
                setEnvelope(2.0f, 1.0f, 0.9f, 4.0f);
                break;

            case Preset::VocalTexture:
                setGrainSize(100.0f);
                setDensity(25.0f);
                setPositionSpray(0.15f);
                setPitchVariation(2.0f);
                setStereoSpread(0.6f);
                setWindowShape(GrainWindow::Tukey);
                break;

            case Preset::ReverseCloud:
                setGrainSize(150.0f);
                setDensity(15.0f);
                setPositionSpray(0.2f);
                setReverseProbability(0.7f);
                setStereoSpread(0.9f);
                setWindowShape(GrainWindow::ReversedExp);
                break;

            case Preset::ShimmerPad:
                setGrainSize(120.0f);
                setDensity(35.0f);
                setPositionSpray(0.05f);
                setPitch(12.0f);  // Octave up
                setPitchVariation(0.2f);
                setStereoSpread(1.0f);
                setWindowShape(GrainWindow::Hann);
                setLFO1(0.1f, GranularLFO::Shape::Sine, 0.3f);
                break;

            case Preset::BioReactive:
                setGrainSize(80.0f);
                setDensity(20.0f);
                setPositionSpray(0.2f);
                setPitchVariation(3.0f);
                setStereoSpread(0.7f);
                setBioReactiveEnabled(true);
                setWindowShape(GrainWindow::Gaussian);
                break;
        }
    }

private:
    //==========================================================================
    // Member Variables
    //==========================================================================

    double currentSampleRate = 48000.0;
    int blockSize = 512;

    // Sources
    std::vector<juce::AudioBuffer<float>> sourceBuffers;
    std::array<double, MaxSources> sourceSampleRates = { 48000.0, 48000.0, 48000.0, 48000.0 };
    int activeSource = 0;
    float sourceBlend = 0.0f;

    // Grains
    std::vector<Grain> grains;
    int maxActiveGrains = 64;

    // Grain parameters
    float grainSizeMs = 50.0f;
    int grainSizeSamples = 2400;
    float grainSizeVariation = 0.0f;
    float density = 20.0f;
    float position = 0.5f;
    float positionSpray = 0.1f;
    bool scrubMode = false;
    float pitchShift = 0.0f;
    float pitchVariation = 0.0f;
    bool pitchQuantize = false;
    GrainWindow windowShape = GrainWindow::Hann;
    float stereoSpread = 0.5f;
    float reverseProbability = 0.0f;

    // Freeze & Stutter
    bool frozen = false;
    float freezePosition = 0.5f;
    bool stuttering = false;
    int stutterInterval = 4800;
    int stutterCounter = 0;

    // Grain triggering
    int grainTriggerInterval = 2400;
    int grainTriggerCounter = 0;

    // Modulation
    GranularLFO lfo1, lfo2;
    GranularEnvelope ampEnvelope;
    float lfo1Value = 0.0f;
    float lfo2Value = 0.0f;

    struct ModRouting
    {
        ModulationSource source = ModulationSource::None;
        float amount = 0.0f;
    };
    std::map<juce::String, ModRouting> modRoutings;

    // Bio-reactive
    float bioHRV = 0.5f;
    float bioCoherence = 0.5f;
    bool bioReactiveEnabled = false;

    // MIDI
    int currentMidiNote = 60;
    float currentVelocity = 1.0f;
    float midiPitchMultiplier = 1.0f;
    float modWheelValue = 0.0f;
    float aftertouchValue = 0.0f;
    bool playing = false;

    // Master
    float masterVolume = 0.7f;

    // Buffers
    juce::AudioBuffer<float> grainBuffer;
    juce::AudioBuffer<float> outputBuffer;

    // Random
    std::mt19937 rng;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void updateGrainInterval()
    {
        grainTriggerInterval = std::max(1, static_cast<int>(currentSampleRate / density));
    }

    void triggerGrain()
    {
        // Find inactive grain slot
        int grainIndex = -1;
        for (int i = 0; i < maxActiveGrains; ++i)
        {
            if (!grains[i].active)
            {
                grainIndex = i;
                break;
            }
        }

        if (grainIndex < 0)
            return; // All slots busy

        // Calculate grain parameters with variation
        std::uniform_real_distribution<float> dist(0.0f, 1.0f);
        std::normal_distribution<float> normalDist(0.0f, 1.0f);

        // Grain size with variation
        float sizeVariation = grainSizeVariation * normalDist(rng) * 0.5f;
        int grainSize = static_cast<int>(grainSizeSamples * (1.0f + sizeVariation));
        grainSize = juce::jlimit(64, 192000, grainSize);

        // Position with spray
        float currentPos = frozen ? freezePosition : position;
        float posOffset = positionSpray * normalDist(rng) * 0.5f;
        float grainPos = juce::jlimit(0.0f, 1.0f, currentPos + posOffset);

        // Pitch with variation
        float pitchVar = pitchVariation * normalDist(rng) * 0.5f;
        float finalPitch = pitchShift + pitchVar;

        if (pitchQuantize)
        {
            // Quantize to semitones
            finalPitch = std::round(finalPitch);
        }

        float pitchMultiplier = std::pow(2.0f, finalPitch / 12.0f) * midiPitchMultiplier;

        // Stereo position
        float pan = stereoSpread * (dist(rng) * 2.0f - 1.0f);

        // Reverse probability
        bool reverse = dist(rng) < reverseProbability;

        // Window shape (randomize if set to Random)
        GrainWindow window = windowShape;
        if (window == GrainWindow::Random)
        {
            int randWindow = static_cast<int>(dist(rng) * 8);
            window = static_cast<GrainWindow>(randWindow);
        }

        // Apply modulation
        float modulatedAmp = currentVelocity;
        if (bioReactiveEnabled)
        {
            modulatedAmp *= 0.5f + bioCoherence * 0.5f;
        }

        // Start grain
        grains[grainIndex].sourceIndex = activeSource;
        grains[grainIndex].start(grainSize, window, grainPos,
                                 pitchMultiplier, modulatedAmp, pan, reverse);
    }

    float readSourceSample(const Grain& grain)
    {
        const auto& source = sourceBuffers[grain.sourceIndex];
        if (source.getNumSamples() == 0)
            return 0.0f;

        // Calculate source position
        int sourceLength = source.getNumSamples();
        double sourcePos = grain.sourcePosition * sourceLength;

        // Offset by playback position (adjusted for pitch)
        if (grain.reverse)
            sourcePos -= grain.playbackPosition;
        else
            sourcePos += grain.playbackPosition;

        // Handle looping
        while (sourcePos < 0)
            sourcePos += sourceLength;
        while (sourcePos >= sourceLength)
            sourcePos -= sourceLength;

        // Linear interpolation
        int pos0 = static_cast<int>(sourcePos);
        int pos1 = (pos0 + 1) % sourceLength;
        float frac = static_cast<float>(sourcePos - pos0);

        float sample = 0.0f;
        int numChannels = source.getNumChannels();

        for (int ch = 0; ch < numChannels; ++ch)
        {
            float s0 = source.getSample(ch, pos0);
            float s1 = source.getSample(ch, pos1);
            sample += s0 + frac * (s1 - s0);
        }

        return sample / numChannels;
    }

    void processModulation(int numSamples)
    {
        // Process LFOs
        lfo1Value = lfo1.process();
        lfo2Value = lfo2.process();

        // Apply modulation routings
        for (const auto& [dest, routing] : modRoutings)
        {
            float modValue = getModulationValue(routing.source) * routing.amount;
            applyModulation(dest, modValue);
        }

        // Bio-reactive modulation
        if (bioReactiveEnabled)
        {
            // HRV modulates grain density
            float densityMod = 1.0f + (bioHRV - 0.5f) * 0.5f;
            int modInterval = static_cast<int>(grainTriggerInterval / densityMod);
            grainTriggerInterval = juce::jlimit(100, 48000, modInterval);

            // Coherence modulates pitch variation
            pitchVariation = pitchVariation * (1.0f - bioCoherence * 0.5f);
        }
    }

    float getModulationValue(ModulationSource source)
    {
        switch (source)
        {
            case ModulationSource::LFO1: return lfo1Value;
            case ModulationSource::LFO2: return lfo2Value;
            case ModulationSource::Envelope: return ampEnvelope.getLevel();
            case ModulationSource::Random: return static_cast<float>(rand()) / RAND_MAX * 2.0f - 1.0f;
            case ModulationSource::MIDI_Velocity: return currentVelocity;
            case ModulationSource::MIDI_ModWheel: return modWheelValue;
            case ModulationSource::MIDI_Aftertouch: return aftertouchValue;
            case ModulationSource::BioHRV: return bioHRV;
            case ModulationSource::BioCoherence: return bioCoherence;
            default: return 0.0f;
        }
    }

    void applyModulation(const juce::String& destination, float value)
    {
        if (destination == "position")
            position = juce::jlimit(0.0f, 1.0f, position + value * 0.1f);
        else if (destination == "pitch")
            pitchShift += value * 12.0f;
        else if (destination == "density")
        {
            float modDensity = density * (1.0f + value);
            updateGrainInterval();
        }
        else if (destination == "grainSize")
            grainSizeMs = juce::jlimit(1.0f, 2000.0f, grainSizeMs * (1.0f + value));
        else if (destination == "stereoSpread")
            stereoSpread = juce::jlimit(0.0f, 1.0f, stereoSpread + value * 0.5f);
    }

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(GranularSynthesizer)
};

} // namespace Synthesis
} // namespace Echoelmusic
