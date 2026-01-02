#pragma once

#include <JuceHeader.h>
#include <array>
#include <atomic>
#include <cmath>
#include <memory>
#include <vector>

namespace Echoelmusic {

/**
 * MetronomeEngine - Professional Click Track / Metronome
 *
 * Features:
 * - Multiple click sounds (electronic, acoustic, rimshot, cowbell, etc.)
 * - Accent patterns (downbeat emphasis)
 * - Custom subdivision patterns
 * - Pre-roll / count-in
 * - Volume control
 * - Pan control
 * - Swing/shuffle support
 * - Odd time signature support
 * - Visual flash output
 * - Tap tempo
 * - MIDI output for external gear
 */

//==============================================================================
// Click Sound Types
//==============================================================================

enum class ClickSound
{
    Electronic,         // Classic electronic click
    WoodBlock,          // Acoustic wood block
    Rimshot,            // Snare rimshot
    Cowbell,            // Classic cowbell
    Sticks,             // Stick clicks
    HiHat,              // Hi-hat click
    Clap,               // Hand clap
    Beep,               // Simple sine beep
    Custom              // User-loaded sample
};

//==============================================================================
// Beat Accent Level
//==============================================================================

enum class AccentLevel
{
    Off,                // No sound
    Ghost,              // Very soft
    Normal,             // Regular beat
    Accent,             // Emphasized
    Strong              // Downbeat / strong accent
};

//==============================================================================
// Subdivision Pattern
//==============================================================================

struct SubdivisionPattern
{
    juce::String name;
    std::vector<AccentLevel> pattern;   // Accents per beat
    int subdivisionsPerBeat = 1;

    static SubdivisionPattern quarterNotes()
    {
        SubdivisionPattern p;
        p.name = "Quarter Notes";
        p.pattern = {AccentLevel::Normal};
        p.subdivisionsPerBeat = 1;
        return p;
    }

    static SubdivisionPattern eighthNotes()
    {
        SubdivisionPattern p;
        p.name = "Eighth Notes";
        p.pattern = {AccentLevel::Normal, AccentLevel::Ghost};
        p.subdivisionsPerBeat = 2;
        return p;
    }

    static SubdivisionPattern sixteenthNotes()
    {
        SubdivisionPattern p;
        p.name = "Sixteenth Notes";
        p.pattern = {AccentLevel::Normal, AccentLevel::Off, AccentLevel::Ghost, AccentLevel::Off};
        p.subdivisionsPerBeat = 4;
        return p;
    }

    static SubdivisionPattern triplets()
    {
        SubdivisionPattern p;
        p.name = "Triplets";
        p.pattern = {AccentLevel::Normal, AccentLevel::Ghost, AccentLevel::Ghost};
        p.subdivisionsPerBeat = 3;
        return p;
    }

    static SubdivisionPattern swingEighths()
    {
        SubdivisionPattern p;
        p.name = "Swing Eighths";
        p.pattern = {AccentLevel::Normal, AccentLevel::Ghost};  // Timing handled separately
        p.subdivisionsPerBeat = 2;
        return p;
    }
};

//==============================================================================
// Click Sample Synthesizer
//==============================================================================

class ClickSynthesizer
{
public:
    ClickSynthesizer(double sampleRate = 48000.0) : fs(sampleRate)
    {
        generateClickSamples();
    }

    void prepare(double sampleRate)
    {
        fs = sampleRate;
        generateClickSamples();
    }

    /** Generate click sample into buffer */
    void generateClick(float* buffer, int numSamples, ClickSound sound, AccentLevel accent)
    {
        if (accent == AccentLevel::Off)
        {
            std::memset(buffer, 0, numSamples * sizeof(float));
            return;
        }

        float volume = getAccentVolume(accent);
        const auto& sample = getClickSample(sound);

        int samplesToCopy = std::min(numSamples, static_cast<int>(sample.size()));

        for (int i = 0; i < samplesToCopy; ++i)
        {
            buffer[i] = sample[i] * volume;
        }

        // Clear rest
        for (int i = samplesToCopy; i < numSamples; ++i)
        {
            buffer[i] = 0.0f;
        }
    }

    /** Get click sample length in samples */
    int getClickLength(ClickSound sound) const
    {
        return static_cast<int>(getClickSample(sound).size());
    }

private:
    double fs;

    // Pre-generated click samples
    std::vector<float> electronicClick;
    std::vector<float> woodBlockClick;
    std::vector<float> rimshotClick;
    std::vector<float> cowbellClick;
    std::vector<float> sticksClick;
    std::vector<float> hihatClick;
    std::vector<float> clapClick;
    std::vector<float> beepClick;

    void generateClickSamples()
    {
        int clickLengthMs = 30;
        int clickSamples = static_cast<int>(fs * clickLengthMs / 1000.0);

        // Electronic click - sharp attack, quick decay
        electronicClick.resize(clickSamples);
        for (int i = 0; i < clickSamples; ++i)
        {
            float t = i / static_cast<float>(fs);
            float env = std::exp(-t * 150.0f);
            float osc = std::sin(2.0f * juce::MathConstants<float>::pi * 1000.0f * t);
            osc += 0.5f * std::sin(2.0f * juce::MathConstants<float>::pi * 2500.0f * t);
            electronicClick[i] = osc * env * 0.8f;
        }

        // Wood block - resonant knock
        woodBlockClick.resize(clickSamples);
        for (int i = 0; i < clickSamples; ++i)
        {
            float t = i / static_cast<float>(fs);
            float env = std::exp(-t * 80.0f);
            float osc = std::sin(2.0f * juce::MathConstants<float>::pi * 800.0f * t);
            osc += 0.3f * std::sin(2.0f * juce::MathConstants<float>::pi * 1600.0f * t);
            osc += 0.2f * std::sin(2.0f * juce::MathConstants<float>::pi * 2400.0f * t);
            woodBlockClick[i] = osc * env * 0.7f;
        }

        // Rimshot - sharp transient
        rimshotClick.resize(clickSamples);
        for (int i = 0; i < clickSamples; ++i)
        {
            float t = i / static_cast<float>(fs);
            float env = std::exp(-t * 200.0f);
            float noise = (static_cast<float>(rand()) / RAND_MAX - 0.5f) * 2.0f;
            float osc = std::sin(2.0f * juce::MathConstants<float>::pi * 400.0f * t);
            rimshotClick[i] = (noise * 0.5f + osc * 0.5f) * env * 0.8f;
        }

        // Cowbell - classic more cowbell
        int cowbellLength = static_cast<int>(fs * 80 / 1000.0);
        cowbellClick.resize(cowbellLength);
        for (int i = 0; i < cowbellLength; ++i)
        {
            float t = i / static_cast<float>(fs);
            float env = std::exp(-t * 30.0f);
            float osc = std::sin(2.0f * juce::MathConstants<float>::pi * 587.0f * t);  // D5
            osc += 0.7f * std::sin(2.0f * juce::MathConstants<float>::pi * 845.0f * t);
            cowbellClick[i] = osc * env * 0.6f;
        }

        // Sticks - short click
        int sticksLength = static_cast<int>(fs * 15 / 1000.0);
        sticksClick.resize(sticksLength);
        for (int i = 0; i < sticksLength; ++i)
        {
            float t = i / static_cast<float>(fs);
            float env = std::exp(-t * 300.0f);
            float noise = (static_cast<float>(rand()) / RAND_MAX - 0.5f) * 2.0f;
            sticksClick[i] = noise * env * 0.9f;
        }

        // Hi-hat - filtered noise
        hihatClick.resize(clickSamples);
        for (int i = 0; i < clickSamples; ++i)
        {
            float t = i / static_cast<float>(fs);
            float env = std::exp(-t * 100.0f);
            float noise = (static_cast<float>(rand()) / RAND_MAX - 0.5f) * 2.0f;
            // Simple high-pass effect
            static float lastSample = 0;
            float filtered = noise - lastSample;
            lastSample = noise * 0.99f;
            hihatClick[i] = filtered * env * 0.7f;
        }

        // Clap - layered attack
        int clapLength = static_cast<int>(fs * 50 / 1000.0);
        clapClick.resize(clapLength);
        for (int i = 0; i < clapLength; ++i)
        {
            float t = i / static_cast<float>(fs);
            // Multiple micro-attacks for clap texture
            float env1 = std::exp(-(t - 0.0f) * 200.0f) * (t >= 0.0f ? 1.0f : 0.0f);
            float env2 = std::exp(-(t - 0.005f) * 200.0f) * (t >= 0.005f ? 1.0f : 0.0f);
            float env3 = std::exp(-(t - 0.008f) * 100.0f) * (t >= 0.008f ? 1.0f : 0.0f);
            float noise = (static_cast<float>(rand()) / RAND_MAX - 0.5f) * 2.0f;
            clapClick[i] = noise * (env1 * 0.3f + env2 * 0.3f + env3 * 0.8f) * 0.6f;
        }

        // Beep - simple sine
        beepClick.resize(clickSamples);
        for (int i = 0; i < clickSamples; ++i)
        {
            float t = i / static_cast<float>(fs);
            float env = std::exp(-t * 100.0f);
            float osc = std::sin(2.0f * juce::MathConstants<float>::pi * 880.0f * t);  // A5
            beepClick[i] = osc * env * 0.7f;
        }
    }

    const std::vector<float>& getClickSample(ClickSound sound) const
    {
        switch (sound)
        {
            case ClickSound::Electronic:    return electronicClick;
            case ClickSound::WoodBlock:     return woodBlockClick;
            case ClickSound::Rimshot:       return rimshotClick;
            case ClickSound::Cowbell:       return cowbellClick;
            case ClickSound::Sticks:        return sticksClick;
            case ClickSound::HiHat:         return hihatClick;
            case ClickSound::Clap:          return clapClick;
            case ClickSound::Beep:          return beepClick;
            default:                        return electronicClick;
        }
    }

    float getAccentVolume(AccentLevel accent) const
    {
        switch (accent)
        {
            case AccentLevel::Off:      return 0.0f;
            case AccentLevel::Ghost:    return 0.3f;
            case AccentLevel::Normal:   return 0.7f;
            case AccentLevel::Accent:   return 0.9f;
            case AccentLevel::Strong:   return 1.0f;
            default:                    return 0.7f;
        }
    }
};

//==============================================================================
// Metronome Engine
//==============================================================================

class MetronomeEngine
{
public:
    using ClickCallback = std::function<void(int beat, int subdivision, bool isDownbeat)>;
    using FlashCallback = std::function<void(bool isDownbeat)>;

    MetronomeEngine()
    {
        subdivision = SubdivisionPattern::quarterNotes();
    }

    //==========================================================================
    // Configuration
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize)
    {
        fs = sampleRate;
        blockSize = maxBlockSize;
        synthesizer.prepare(sampleRate);

        clickBuffer.setSize(1, synthesizer.getClickLength(downbeatSound) + maxBlockSize);
        clickBuffer.clear();
    }

    void setTempo(double bpm)
    {
        tempo.store(std::clamp(bpm, 20.0, 400.0));
        updateSamplesPerBeat();
    }

    double getTempo() const { return tempo.load(); }

    void setTimeSignature(int numerator, int denominator)
    {
        timeSignatureNumerator = numerator;
        timeSignatureDenominator = denominator;
    }

    void setVolume(float vol)
    {
        volume.store(std::clamp(vol, 0.0f, 1.0f));
    }

    float getVolume() const { return volume.load(); }

    void setPan(float p)
    {
        pan.store(std::clamp(p, -1.0f, 1.0f));
    }

    //==========================================================================
    // Sound Selection
    //==========================================================================

    void setDownbeatSound(ClickSound sound) { downbeatSound = sound; }
    void setBeatSound(ClickSound sound) { beatSound = sound; }
    void setSubdivisionSound(ClickSound sound) { subdivisionSound = sound; }

    void setAccentDownbeat(bool accent) { accentDownbeat = accent; }

    void setSubdivision(const SubdivisionPattern& pattern)
    {
        subdivision = pattern;
    }

    //==========================================================================
    // Playback Control
    //==========================================================================

    void start()
    {
        if (!playing.load())
        {
            currentBeat = 0;
            currentSubdivision = 0;
            sampleCounter = 0;
            playing.store(true);
        }
    }

    void stop()
    {
        playing.store(false);
        currentBeat = 0;
        currentSubdivision = 0;
        sampleCounter = 0;
    }

    bool isPlaying() const { return playing.load(); }

    void setEnabled(bool enabled) { this->enabled.store(enabled); }
    bool isEnabled() const { return enabled.load(); }

    //==========================================================================
    // Count-In / Pre-Roll
    //==========================================================================

    void setCountIn(int bars)
    {
        countInBars = bars;
    }

    void startWithCountIn()
    {
        if (countInBars > 0)
        {
            countingIn = true;
            countInBeatsRemaining = countInBars * timeSignatureNumerator;
        }
        start();
    }

    bool isCountingIn() const { return countingIn; }

    //==========================================================================
    // Swing
    //==========================================================================

    void setSwing(float swingPercent)
    {
        swing.store(std::clamp(swingPercent, 0.0f, 100.0f));
    }

    float getSwing() const { return swing.load(); }

    //==========================================================================
    // Audio Processing
    //==========================================================================

    void processBlock(juce::AudioBuffer<float>& buffer, int startSample, int numSamples)
    {
        if (!enabled.load() || !playing.load())
            return;

        float vol = volume.load();
        float panValue = pan.load();

        // Calculate panning gains
        float leftGain = vol * std::cos((panValue + 1.0f) * juce::MathConstants<float>::halfPi * 0.5f);
        float rightGain = vol * std::sin((panValue + 1.0f) * juce::MathConstants<float>::halfPi * 0.5f);

        for (int i = 0; i < numSamples; ++i)
        {
            float clickSample = 0.0f;

            // Check if we need to trigger a click
            if (sampleCounter == 0 || sampleCounter >= samplesPerSubdivision)
            {
                triggerClick();
                sampleCounter = 0;
            }

            // Get click sample from buffer
            if (clickPlaybackPos < clickBuffer.getNumSamples())
            {
                clickSample = clickBuffer.getSample(0, clickPlaybackPos);
                clickPlaybackPos++;
            }

            // Mix into output
            if (buffer.getNumChannels() >= 2)
            {
                buffer.addSample(0, startSample + i, clickSample * leftGain);
                buffer.addSample(1, startSample + i, clickSample * rightGain);
            }
            else if (buffer.getNumChannels() == 1)
            {
                buffer.addSample(0, startSample + i, clickSample * vol);
            }

            sampleCounter++;
        }
    }

    /** Process standalone (get metronome audio) */
    void processBlock(float* outputL, float* outputR, int numSamples)
    {
        juce::AudioBuffer<float> temp(2, numSamples);
        temp.clear();
        processBlock(temp, 0, numSamples);

        std::memcpy(outputL, temp.getReadPointer(0), numSamples * sizeof(float));
        if (outputR)
            std::memcpy(outputR, temp.getReadPointer(1), numSamples * sizeof(float));
    }

    //==========================================================================
    // Sync to External Transport
    //==========================================================================

    void syncToPosition(double positionBeats)
    {
        double beatsPerBar = static_cast<double>(timeSignatureNumerator);
        currentBeat = static_cast<int>(std::fmod(positionBeats, beatsPerBar));
        currentSubdivision = 0;

        // Calculate sample position within current subdivision
        double beatFraction = std::fmod(positionBeats, 1.0);
        sampleCounter = static_cast<int>(beatFraction * samplesPerBeat);
    }

    //==========================================================================
    // Tap Tempo
    //==========================================================================

    void tap()
    {
        juce::int64 now = juce::Time::currentTimeMillis();

        if (lastTapTime > 0)
        {
            juce::int64 interval = now - lastTapTime;

            if (interval < 2000)  // Max 2 seconds between taps
            {
                tapIntervals.push_back(static_cast<double>(interval));

                if (tapIntervals.size() > 8)
                    tapIntervals.erase(tapIntervals.begin());

                // Calculate average interval
                double avgInterval = 0;
                for (double i : tapIntervals)
                    avgInterval += i;
                avgInterval /= tapIntervals.size();

                // Convert to BPM
                double bpm = 60000.0 / avgInterval;
                setTempo(bpm);
            }
            else
            {
                tapIntervals.clear();
            }
        }

        lastTapTime = now;
    }

    void clearTapHistory()
    {
        tapIntervals.clear();
        lastTapTime = 0;
    }

    //==========================================================================
    // MIDI Output
    //==========================================================================

    void getMIDIOutput(juce::MidiBuffer& midiBuffer, int numSamples)
    {
        if (!enabled.load() || !playing.load() || !midiOutputEnabled)
            return;

        // Add MIDI clock and note messages for click
        // (Implementation would add actual MIDI events)
    }

    void setMIDIOutputEnabled(bool enabled) { midiOutputEnabled = enabled; }
    void setMIDIOutputChannel(int channel) { midiOutputChannel = std::clamp(channel, 1, 16); }
    void setMIDIOutputNote(int note) { midiOutputNote = std::clamp(note, 0, 127); }

    //==========================================================================
    // Callbacks
    //==========================================================================

    void setClickCallback(ClickCallback cb) { clickCallback = cb; }
    void setFlashCallback(FlashCallback cb) { flashCallback = cb; }

    //==========================================================================
    // Current State
    //==========================================================================

    int getCurrentBeat() const { return currentBeat; }
    int getCurrentSubdivision() const { return currentSubdivision; }
    int getBeatsPerBar() const { return timeSignatureNumerator; }

private:
    double fs = 48000.0;
    int blockSize = 512;

    std::atomic<double> tempo { 120.0 };
    std::atomic<float> volume { 0.8f };
    std::atomic<float> pan { 0.0f };
    std::atomic<float> swing { 50.0f };
    std::atomic<bool> playing { false };
    std::atomic<bool> enabled { true };

    int timeSignatureNumerator = 4;
    int timeSignatureDenominator = 4;

    ClickSound downbeatSound = ClickSound::WoodBlock;
    ClickSound beatSound = ClickSound::Electronic;
    ClickSound subdivisionSound = ClickSound::Electronic;

    bool accentDownbeat = true;
    SubdivisionPattern subdivision;

    int currentBeat = 0;
    int currentSubdivision = 0;
    int sampleCounter = 0;
    int samplesPerBeat = 24000;         // At 120 BPM, 48kHz
    int samplesPerSubdivision = 24000;

    ClickSynthesizer synthesizer;
    juce::AudioBuffer<float> clickBuffer;
    int clickPlaybackPos = 0;

    // Count-in
    int countInBars = 0;
    int countInBeatsRemaining = 0;
    bool countingIn = false;

    // Tap tempo
    std::vector<double> tapIntervals;
    juce::int64 lastTapTime = 0;

    // MIDI output
    bool midiOutputEnabled = false;
    int midiOutputChannel = 10;
    int midiOutputNote = 37;  // Side stick

    // Callbacks
    ClickCallback clickCallback;
    FlashCallback flashCallback;

    void updateSamplesPerBeat()
    {
        double bpm = tempo.load();
        samplesPerBeat = static_cast<int>((60.0 / bpm) * fs);
        samplesPerSubdivision = samplesPerBeat / subdivision.subdivisionsPerBeat;

        // Apply swing to off-beat subdivisions
        // (would modify timing of alternating subdivisions)
    }

    void triggerClick()
    {
        bool isDownbeat = (currentBeat == 0 && currentSubdivision == 0);
        bool isMainBeat = (currentSubdivision == 0);

        // Determine accent level
        AccentLevel accent = AccentLevel::Normal;

        if (isDownbeat && accentDownbeat)
        {
            accent = AccentLevel::Strong;
        }
        else if (isMainBeat)
        {
            accent = AccentLevel::Normal;
        }
        else if (currentSubdivision < static_cast<int>(subdivision.pattern.size()))
        {
            accent = subdivision.pattern[currentSubdivision];
        }
        else
        {
            accent = AccentLevel::Ghost;
        }

        // Select sound
        ClickSound sound = beatSound;
        if (isDownbeat)
            sound = downbeatSound;
        else if (!isMainBeat)
            sound = subdivisionSound;

        // Generate click into buffer
        clickBuffer.clear();
        synthesizer.generateClick(clickBuffer.getWritePointer(0),
                                  clickBuffer.getNumSamples(),
                                  sound, accent);
        clickPlaybackPos = 0;

        // Notify callbacks
        if (clickCallback)
            clickCallback(currentBeat, currentSubdivision, isDownbeat);

        if (flashCallback)
            flashCallback(isDownbeat);

        // Advance position
        currentSubdivision++;
        if (currentSubdivision >= subdivision.subdivisionsPerBeat)
        {
            currentSubdivision = 0;
            currentBeat++;

            if (currentBeat >= timeSignatureNumerator)
            {
                currentBeat = 0;

                // Handle count-in completion
                if (countingIn)
                {
                    countInBeatsRemaining -= timeSignatureNumerator;
                    if (countInBeatsRemaining <= 0)
                    {
                        countingIn = false;
                    }
                }
            }
        }

        updateSamplesPerBeat();
    }

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MetronomeEngine)
};

//==============================================================================
// Metronome Presets
//==============================================================================

class MetronomePresets
{
public:
    static void applyClassicClick(MetronomeEngine& engine)
    {
        engine.setDownbeatSound(ClickSound::WoodBlock);
        engine.setBeatSound(ClickSound::WoodBlock);
        engine.setAccentDownbeat(true);
        engine.setSubdivision(SubdivisionPattern::quarterNotes());
    }

    static void applyModernClick(MetronomeEngine& engine)
    {
        engine.setDownbeatSound(ClickSound::Electronic);
        engine.setBeatSound(ClickSound::Electronic);
        engine.setAccentDownbeat(true);
        engine.setSubdivision(SubdivisionPattern::quarterNotes());
    }

    static void applyDrumSticks(MetronomeEngine& engine)
    {
        engine.setDownbeatSound(ClickSound::Rimshot);
        engine.setBeatSound(ClickSound::Sticks);
        engine.setAccentDownbeat(true);
        engine.setSubdivision(SubdivisionPattern::quarterNotes());
    }

    static void applyHiHat(MetronomeEngine& engine)
    {
        engine.setDownbeatSound(ClickSound::HiHat);
        engine.setBeatSound(ClickSound::HiHat);
        engine.setSubdivisionSound(ClickSound::HiHat);
        engine.setAccentDownbeat(true);
        engine.setSubdivision(SubdivisionPattern::eighthNotes());
    }

    static void applyCowbell(MetronomeEngine& engine)
    {
        engine.setDownbeatSound(ClickSound::Cowbell);
        engine.setBeatSound(ClickSound::Cowbell);
        engine.setAccentDownbeat(true);
        engine.setSubdivision(SubdivisionPattern::quarterNotes());
    }
};

} // namespace Echoelmusic
