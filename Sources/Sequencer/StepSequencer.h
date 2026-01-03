#pragma once

#include <JuceHeader.h>
#include <vector>
#include <array>
#include <memory>
#include <functional>
#include <atomic>

/**
 * StepSequencer - Production-Ready Pattern Sequencer
 *
 * Classic step sequencer with modern features:
 * - 16/32/64 step patterns
 * - 16 tracks (drum channels)
 * - Per-step velocity, probability, ratchet
 * - Pattern chaining and song mode
 * - Swing and shuffle
 * - Real-time LED-style display
 * - MIDI output with timing accuracy
 *
 * Super Ralph Wiggum Loop Genius Wise Save Mode
 */

namespace Echoelmusic {
namespace Sequencer {

//==============================================================================
// Step Data
//==============================================================================

struct Step
{
    bool active = false;
    int velocity = 100;         // 0-127
    float probability = 1.0f;   // 0-1, chance of playing
    int ratchet = 1;            // 1-4, number of hits per step
    float nudge = 0.0f;         // -50 to +50 ms timing offset
    int pitch = 0;              // Pitch offset from base note
    float decay = 1.0f;         // Note duration multiplier
    bool accent = false;
    bool slide = false;         // For 303-style slides

    bool shouldTrigger() const
    {
        if (!active) return false;
        if (probability >= 1.0f) return true;
        return (std::rand() / static_cast<float>(RAND_MAX)) < probability;
    }
};

//==============================================================================
// Track Definition
//==============================================================================

struct Track
{
    std::string name = "Track";
    int midiNote = 36;          // Base MIDI note (C1 for kick)
    int midiChannel = 10;       // MIDI channel (10 for drums)
    float volume = 1.0f;
    float pan = 0.0f;           // -1 to +1
    bool muted = false;
    bool solo = false;
    juce::Colour color{0xFF4A9EFF};

    std::array<Step, 64> steps{};  // Max 64 steps

    void clear()
    {
        for (auto& step : steps)
            step = Step{};
    }
};

//==============================================================================
// Pattern
//==============================================================================

struct Pattern
{
    std::string name = "Pattern";
    int numSteps = 16;          // Active steps (16, 32, or 64)
    int numTracks = 8;          // Active tracks
    float swing = 0.0f;         // 0-100%
    int division = 16;          // Steps per bar (16 = 16th notes)

    std::array<Track, 16> tracks{};

    void clear()
    {
        for (auto& track : tracks)
            track.clear();
    }

    Track& getTrack(int index)
    {
        return tracks[std::clamp(index, 0, 15)];
    }

    Step& getStep(int trackIndex, int stepIndex)
    {
        return tracks[std::clamp(trackIndex, 0, 15)]
               .steps[std::clamp(stepIndex, 0, 63)];
    }
};

//==============================================================================
// Step Sequencer Engine
//==============================================================================

class StepSequencerEngine
{
public:
    struct Config
    {
        float bpm = 120.0f;
        int sampleRate = 44100;
        bool followHost = false;
        bool syncToMIDIClock = false;
    };

    StepSequencerEngine()
    {
        initializeDefaultKit();
    }

    void setConfig(const Config& cfg)
    {
        config = cfg;
        calculateTiming();
    }

    // Pattern management
    void setPattern(const Pattern& p)
    {
        pattern = p;
    }

    Pattern& getPattern() { return pattern; }
    const Pattern& getPattern() const { return pattern; }

    // Transport
    void start()
    {
        isPlaying = true;
        currentStep = 0;
        sampleCounter = 0;
    }

    void stop()
    {
        isPlaying = false;
        currentStep = 0;
    }

    void pause()
    {
        isPlaying = false;
    }

    bool playing() const { return isPlaying; }

    int getCurrentStep() const { return currentStep; }

    void setCurrentStep(int step)
    {
        currentStep = step % pattern.numSteps;
    }

    // Process audio block - returns MIDI events to trigger
    struct MIDIEvent
    {
        int note;
        int velocity;
        int channel;
        int sampleOffset;
        bool noteOn;
        float duration;
    };

    std::vector<MIDIEvent> process(int numSamples)
    {
        std::vector<MIDIEvent> events;

        if (!isPlaying) return events;

        int samplesProcessed = 0;

        while (samplesProcessed < numSamples)
        {
            int samplesUntilNextStep = samplesPerStep - sampleCounter;
            int samplesToProcess = std::min(samplesUntilNextStep, numSamples - samplesProcessed);

            // Check if we cross a step boundary
            if (sampleCounter + samplesToProcess >= samplesPerStep)
            {
                int sampleOffset = samplesProcessed + samplesUntilNextStep;

                // Trigger all active steps
                for (int t = 0; t < pattern.numTracks; ++t)
                {
                    auto& track = pattern.tracks[t];

                    if (track.muted) continue;
                    if (anySolo && !track.solo) continue;

                    auto& step = track.steps[currentStep];

                    if (step.shouldTrigger())
                    {
                        // Handle ratchets
                        for (int r = 0; r < step.ratchet; ++r)
                        {
                            MIDIEvent event;
                            event.note = track.midiNote + step.pitch;
                            event.velocity = step.accent ? 127 : step.velocity;
                            event.channel = track.midiChannel;
                            event.noteOn = true;

                            // Calculate ratchet timing
                            int ratchetOffset = (r * samplesPerStep) / step.ratchet;

                            // Apply swing
                            int swingOffset = 0;
                            if (currentStep % 2 == 1)
                            {
                                swingOffset = static_cast<int>(pattern.swing / 100.0f * samplesPerStep * 0.5f);
                            }

                            // Apply nudge
                            int nudgeOffset = static_cast<int>(step.nudge * config.sampleRate / 1000.0f);

                            event.sampleOffset = std::clamp(
                                sampleOffset + ratchetOffset + swingOffset + nudgeOffset,
                                0, numSamples - 1);

                            event.duration = (samplesPerStep / step.ratchet) * step.decay;

                            events.push_back(event);
                        }
                    }
                }

                // Advance step
                currentStep = (currentStep + 1) % pattern.numSteps;
                sampleCounter = 0;

                if (onStepChanged)
                    onStepChanged(currentStep);
            }
            else
            {
                sampleCounter += samplesToProcess;
            }

            samplesProcessed += samplesToProcess;
        }

        return events;
    }

    // Edit operations
    void toggleStep(int track, int step)
    {
        auto& s = pattern.getStep(track, step);
        s.active = !s.active;
    }

    void setStepVelocity(int track, int step, int velocity)
    {
        pattern.getStep(track, step).velocity = std::clamp(velocity, 0, 127);
    }

    void setStepProbability(int track, int step, float probability)
    {
        pattern.getStep(track, step).probability = std::clamp(probability, 0.0f, 1.0f);
    }

    void setStepRatchet(int track, int step, int ratchet)
    {
        pattern.getStep(track, step).ratchet = std::clamp(ratchet, 1, 4);
    }

    // Track operations
    void muteTrack(int track, bool mute)
    {
        pattern.tracks[track].muted = mute;
    }

    void soloTrack(int track, bool solo)
    {
        pattern.tracks[track].solo = solo;
        updateSoloState();
    }

    void clearTrack(int track)
    {
        pattern.tracks[track].clear();
    }

    // Pattern operations
    void shiftPattern(int offset)
    {
        for (auto& track : pattern.tracks)
        {
            std::array<Step, 64> temp = track.steps;
            for (int i = 0; i < pattern.numSteps; ++i)
            {
                int newPos = (i + offset + pattern.numSteps) % pattern.numSteps;
                track.steps[newPos] = temp[i];
            }
        }
    }

    void reversePattern()
    {
        for (auto& track : pattern.tracks)
        {
            for (int i = 0; i < pattern.numSteps / 2; ++i)
            {
                std::swap(track.steps[i], track.steps[pattern.numSteps - 1 - i]);
            }
        }
    }

    void randomizePattern(float density = 0.5f)
    {
        for (auto& track : pattern.tracks)
        {
            for (int i = 0; i < pattern.numSteps; ++i)
            {
                track.steps[i].active = (std::rand() / static_cast<float>(RAND_MAX)) < density;
                if (track.steps[i].active)
                {
                    track.steps[i].velocity = 80 + std::rand() % 48;
                }
            }
        }
    }

    // Euclidean rhythm generator
    void generateEuclidean(int track, int hits, int steps)
    {
        pattern.tracks[track].clear();

        if (hits <= 0 || steps <= 0) return;
        hits = std::min(hits, steps);

        // Bjorklund's algorithm
        std::vector<bool> rhythm(steps, false);
        int bucket = 0;

        for (int i = 0; i < steps; ++i)
        {
            bucket += hits;
            if (bucket >= steps)
            {
                bucket -= steps;
                rhythm[i] = true;
            }
        }

        for (int i = 0; i < std::min(steps, pattern.numSteps); ++i)
        {
            pattern.tracks[track].steps[i].active = rhythm[i];
            if (rhythm[i])
                pattern.tracks[track].steps[i].velocity = 100;
        }
    }

    // Callbacks
    std::function<void(int step)> onStepChanged;

private:
    Config config;
    Pattern pattern;

    std::atomic<bool> isPlaying{false};
    int currentStep = 0;
    int sampleCounter = 0;
    int samplesPerStep = 5512;  // Default for 120 BPM, 16th notes

    bool anySolo = false;

    void calculateTiming()
    {
        // Samples per step = (60 / BPM) * sampleRate / stepsPerBeat
        float stepsPerBeat = pattern.division / 4.0f;
        samplesPerStep = static_cast<int>((60.0f / config.bpm) * config.sampleRate / stepsPerBeat);
    }

    void updateSoloState()
    {
        anySolo = false;
        for (const auto& track : pattern.tracks)
        {
            if (track.solo)
            {
                anySolo = true;
                break;
            }
        }
    }

    void initializeDefaultKit()
    {
        // Standard GM drum mapping
        struct DrumDef { const char* name; int note; juce::Colour color; };

        std::array<DrumDef, 16> drums = {{
            {"Kick", 36, juce::Colour(0xFFFF6B6B)},
            {"Snare", 38, juce::Colour(0xFF4ECDC4)},
            {"Closed HH", 42, juce::Colour(0xFFFFE66D)},
            {"Open HH", 46, juce::Colour(0xFFFFA07A)},
            {"Low Tom", 45, juce::Colour(0xFF98D8C8)},
            {"Mid Tom", 47, juce::Colour(0xFFF7DC6F)},
            {"High Tom", 50, juce::Colour(0xFFBB8FCE)},
            {"Crash", 49, juce::Colour(0xFF85C1E9)},
            {"Ride", 51, juce::Colour(0xFFABEBC6)},
            {"Clap", 39, juce::Colour(0xFFF5B7B1)},
            {"Rimshot", 37, juce::Colour(0xFFD7BDE2)},
            {"Cowbell", 56, juce::Colour(0xFFFAD7A0)},
            {"Tambourine", 54, juce::Colour(0xFFA9CCE3)},
            {"Shaker", 70, juce::Colour(0xFFD5F5E3)},
            {"Perc 1", 60, juce::Colour(0xFFE8DAEF)},
            {"Perc 2", 61, juce::Colour(0xFFFDEBD0)}
        }};

        for (int i = 0; i < 16; ++i)
        {
            pattern.tracks[i].name = drums[i].name;
            pattern.tracks[i].midiNote = drums[i].note;
            pattern.tracks[i].color = drums[i].color;
            pattern.tracks[i].midiChannel = 10;
        }

        pattern.numTracks = 8;
        pattern.numSteps = 16;
    }
};

//==============================================================================
// Step Sequencer UI Component
//==============================================================================

class StepSequencerUI : public juce::Component,
                        public juce::Timer
{
public:
    struct Colors
    {
        juce::Colour background{0xFF1A1A1A};
        juce::Colour gridLines{0xFF2A2A2A};
        juce::Colour stepOff{0xFF3A3A3A};
        juce::Colour stepOn{0xFF4A9EFF};
        juce::Colour stepAccent{0xFFFF9E4A};
        juce::Colour currentStep{0xFFFFFFFF};
        juce::Colour trackLabel{0xFF8A8A8A};
        juce::Colour trackLabelBg{0xFF2A2A2A};
    };

    StepSequencerUI()
    {
        startTimerHz(30);
    }

    void setEngine(StepSequencerEngine* eng)
    {
        engine = eng;
    }

    void paint(juce::Graphics& g) override
    {
        g.fillAll(colors.background);

        if (!engine) return;

        const auto& pattern = engine->getPattern();
        int trackLabelWidth = 80;
        int stepWidth = (getWidth() - trackLabelWidth) / pattern.numSteps;
        int trackHeight = getHeight() / pattern.numTracks;

        // Draw track labels
        for (int t = 0; t < pattern.numTracks; ++t)
        {
            const auto& track = pattern.tracks[t];
            int y = t * trackHeight;

            // Track label background
            g.setColour(colors.trackLabelBg);
            g.fillRect(0, y, trackLabelWidth, trackHeight);

            // Track color indicator
            g.setColour(track.color);
            g.fillRect(0, y, 4, trackHeight);

            // Track name
            g.setColour(track.muted ? colors.trackLabel.withAlpha(0.3f) : colors.trackLabel);
            g.setFont(12.0f);
            g.drawText(track.name, 8, y, trackLabelWidth - 12, trackHeight,
                       juce::Justification::centredLeft);

            // Mute/Solo indicators
            if (track.muted)
            {
                g.setColour(juce::Colours::red.withAlpha(0.5f));
                g.drawText("M", trackLabelWidth - 20, y, 20, trackHeight / 2,
                           juce::Justification::centred);
            }
            if (track.solo)
            {
                g.setColour(juce::Colours::yellow);
                g.drawText("S", trackLabelWidth - 20, y + trackHeight / 2, 20, trackHeight / 2,
                           juce::Justification::centred);
            }
        }

        // Draw steps
        int currentStep = engine->getCurrentStep();

        for (int t = 0; t < pattern.numTracks; ++t)
        {
            const auto& track = pattern.tracks[t];
            int y = t * trackHeight;

            for (int s = 0; s < pattern.numSteps; ++s)
            {
                int x = trackLabelWidth + s * stepWidth;
                const auto& step = track.steps[s];

                // Step background
                bool isCurrent = (s == currentStep) && engine->playing();
                bool isBeatStart = (s % 4 == 0);

                juce::Colour bgColor = colors.stepOff;
                if (isBeatStart)
                    bgColor = bgColor.brighter(0.1f);

                g.setColour(bgColor);
                g.fillRect(x + 1, y + 1, stepWidth - 2, trackHeight - 2);

                // Active step
                if (step.active)
                {
                    float velocityBrightness = step.velocity / 127.0f;
                    juce::Colour stepColor = step.accent ? colors.stepAccent : track.color;
                    stepColor = stepColor.withMultipliedBrightness(0.5f + velocityBrightness * 0.5f);

                    // Probability indicator (partial fill)
                    if (step.probability < 1.0f)
                    {
                        int fillHeight = static_cast<int>((trackHeight - 4) * step.probability);
                        g.setColour(stepColor.withAlpha(0.3f));
                        g.fillRect(x + 2, y + 2, stepWidth - 4, trackHeight - 4);
                        g.setColour(stepColor);
                        g.fillRect(x + 2, y + trackHeight - 2 - fillHeight, stepWidth - 4, fillHeight);
                    }
                    else
                    {
                        g.setColour(stepColor);
                        g.fillRect(x + 2, y + 2, stepWidth - 4, trackHeight - 4);
                    }

                    // Ratchet indicator
                    if (step.ratchet > 1)
                    {
                        g.setColour(juce::Colours::white.withAlpha(0.7f));
                        for (int r = 0; r < step.ratchet; ++r)
                        {
                            int dotX = x + 4 + r * 4;
                            g.fillEllipse(static_cast<float>(dotX), static_cast<float>(y + 4), 3.0f, 3.0f);
                        }
                    }
                }

                // Current step indicator
                if (isCurrent)
                {
                    g.setColour(colors.currentStep.withAlpha(0.5f));
                    g.drawRect(x + 1, y + 1, stepWidth - 2, trackHeight - 2, 2);
                }

                // Grid lines
                g.setColour(colors.gridLines);
                g.drawVerticalLine(x, static_cast<float>(y), static_cast<float>(y + trackHeight));
            }

            // Horizontal grid line
            g.setColour(colors.gridLines);
            g.drawHorizontalLine(y + trackHeight - 1, static_cast<float>(trackLabelWidth),
                                 static_cast<float>(getWidth()));
        }
    }

    void mouseDown(const juce::MouseEvent& e) override
    {
        if (!engine) return;

        auto [track, step] = getStepAt(e.x, e.y);

        if (track >= 0 && step >= 0)
        {
            if (e.mods.isRightButtonDown())
            {
                // Show context menu
                showStepMenu(track, step);
            }
            else if (e.mods.isAltDown())
            {
                // Adjust velocity
                isAdjustingVelocity = true;
                adjustTrack = track;
                adjustStep = step;
            }
            else
            {
                // Toggle step
                engine->toggleStep(track, step);
                repaint();
            }
        }
        else if (e.x < 80)  // Track label area
        {
            if (e.mods.isCommandDown())
            {
                engine->soloTrack(track, !engine->getPattern().tracks[track].solo);
            }
            else
            {
                engine->muteTrack(track, !engine->getPattern().tracks[track].muted);
            }
            repaint();
        }
    }

    void mouseDrag(const juce::MouseEvent& e) override
    {
        if (!engine) return;

        if (isAdjustingVelocity)
        {
            int velocity = 127 - (e.y * 127 / getHeight());
            velocity = std::clamp(velocity, 0, 127);
            engine->setStepVelocity(adjustTrack, adjustStep, velocity);
            repaint();
        }
        else
        {
            // Paint mode - toggle steps as we drag
            auto [track, step] = getStepAt(e.x, e.y);

            if (track >= 0 && step >= 0 && (track != lastPaintTrack || step != lastPaintStep))
            {
                engine->toggleStep(track, step);
                lastPaintTrack = track;
                lastPaintStep = step;
                repaint();
            }
        }
    }

    void mouseUp(const juce::MouseEvent& e) override
    {
        isAdjustingVelocity = false;
        lastPaintTrack = -1;
        lastPaintStep = -1;
    }

    void timerCallback() override
    {
        repaint();  // Refresh for playhead animation
    }

private:
    StepSequencerEngine* engine = nullptr;
    Colors colors;

    bool isAdjustingVelocity = false;
    int adjustTrack = 0, adjustStep = 0;
    int lastPaintTrack = -1, lastPaintStep = -1;

    std::pair<int, int> getStepAt(int x, int y)
    {
        if (!engine) return {-1, -1};

        const auto& pattern = engine->getPattern();
        int trackLabelWidth = 80;

        if (x < trackLabelWidth) return {y / (getHeight() / pattern.numTracks), -1};

        int stepWidth = (getWidth() - trackLabelWidth) / pattern.numSteps;
        int trackHeight = getHeight() / pattern.numTracks;

        int track = y / trackHeight;
        int step = (x - trackLabelWidth) / stepWidth;

        if (track < 0 || track >= pattern.numTracks) return {-1, -1};
        if (step < 0 || step >= pattern.numSteps) return {track, -1};

        return {track, step};
    }

    void showStepMenu(int track, int step)
    {
        juce::PopupMenu menu;

        auto& s = engine->getPattern().getStep(track, step);

        menu.addItem("Accent", true, s.accent, [this, track, step, &s]() {
            s.accent = !s.accent;
            repaint();
        });

        juce::PopupMenu ratchetMenu;
        for (int r = 1; r <= 4; ++r)
        {
            ratchetMenu.addItem(juce::String(r) + "x", true, s.ratchet == r,
                [this, track, step, r]() {
                    engine->setStepRatchet(track, step, r);
                    repaint();
                });
        }
        menu.addSubMenu("Ratchet", ratchetMenu);

        juce::PopupMenu probMenu;
        for (int p = 25; p <= 100; p += 25)
        {
            float prob = p / 100.0f;
            probMenu.addItem(juce::String(p) + "%", true,
                std::abs(s.probability - prob) < 0.01f,
                [this, track, step, prob]() {
                    engine->setStepProbability(track, step, prob);
                    repaint();
                });
        }
        menu.addSubMenu("Probability", probMenu);

        menu.showMenuAsync(juce::PopupMenu::Options());
    }
};

//==============================================================================
// Pattern Bank Manager
//==============================================================================

class PatternBank
{
public:
    static constexpr int MaxPatterns = 64;

    PatternBank()
    {
        patterns.resize(MaxPatterns);
        for (int i = 0; i < MaxPatterns; ++i)
            patterns[i].name = "Pattern " + std::to_string(i + 1);
    }

    void savePattern(int slot, const Pattern& pattern)
    {
        if (slot >= 0 && slot < MaxPatterns)
            patterns[slot] = pattern;
    }

    Pattern& getPattern(int slot)
    {
        return patterns[std::clamp(slot, 0, MaxPatterns - 1)];
    }

    void copyPattern(int from, int to)
    {
        if (from >= 0 && from < MaxPatterns && to >= 0 && to < MaxPatterns)
            patterns[to] = patterns[from];
    }

    void clearPattern(int slot)
    {
        if (slot >= 0 && slot < MaxPatterns)
            patterns[slot].clear();
    }

private:
    std::vector<Pattern> patterns;
};

//==============================================================================
// Song Mode (Pattern Chain)
//==============================================================================

class SongMode
{
public:
    struct ChainEntry
    {
        int patternIndex = 0;
        int repeats = 1;
    };

    void addEntry(int patternIndex, int repeats = 1)
    {
        chain.push_back({patternIndex, repeats});
    }

    void removeEntry(int index)
    {
        if (index >= 0 && index < static_cast<int>(chain.size()))
            chain.erase(chain.begin() + index);
    }

    void clear()
    {
        chain.clear();
        currentEntry = 0;
        currentRepeat = 0;
    }

    int getCurrentPattern() const
    {
        if (chain.empty()) return 0;
        return chain[currentEntry].patternIndex;
    }

    bool advance()
    {
        if (chain.empty()) return false;

        currentRepeat++;
        if (currentRepeat >= chain[currentEntry].repeats)
        {
            currentRepeat = 0;
            currentEntry++;

            if (currentEntry >= static_cast<int>(chain.size()))
            {
                if (loop)
                    currentEntry = 0;
                else
                    return false;  // End of song
            }
        }

        return true;
    }

    void reset()
    {
        currentEntry = 0;
        currentRepeat = 0;
    }

    void setLoop(bool shouldLoop) { loop = shouldLoop; }
    bool isLooping() const { return loop; }

    const std::vector<ChainEntry>& getChain() const { return chain; }

private:
    std::vector<ChainEntry> chain;
    int currentEntry = 0;
    int currentRepeat = 0;
    bool loop = true;
};

} // namespace Sequencer
} // namespace Echoelmusic
