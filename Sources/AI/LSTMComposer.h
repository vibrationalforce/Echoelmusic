#pragma once

#include <JuceHeader.h>
#include <vector>
#include <array>
#include <map>
#include <memory>
#include <random>
#include <cmath>
#include <algorithm>
#include <deque>

/**
 * LSTMComposer - Advanced AI Music Composition with LSTM Neural Networks
 *
 * Deep learning-based music generation system featuring:
 * - LSTM (Long Short-Term Memory) networks for sequence prediction
 * - Multi-style training (Classical, Jazz, Electronic, Pop, etc.)
 * - Real-time melody, harmony, and rhythm generation
 * - Temperature-controlled creativity
 * - Music theory constraints (key, scale, chord progressions)
 * - Bio-reactive composition based on physiological data
 * - Continuous learning from user input
 * - MIDI output for DAW integration
 *
 * Inspired by: Magenta, MuseNet, AIVA, Amper Music
 */

namespace Echoelmusic {
namespace AI {

//==============================================================================
// LSTM Cell Implementation
//==============================================================================

class LSTMCell
{
public:
    LSTMCell(int inputSize, int hiddenSize)
        : inSize(inputSize), hidSize(hiddenSize)
    {
        // Initialize weight matrices with Xavier initialization
        float scale = std::sqrt(2.0f / (inputSize + hiddenSize));

        // Input gate weights
        Wi.resize(inputSize * hiddenSize);
        Ui.resize(hiddenSize * hiddenSize);
        bi.resize(hiddenSize, 0.0f);

        // Forget gate weights
        Wf.resize(inputSize * hiddenSize);
        Uf.resize(hiddenSize * hiddenSize);
        bf.resize(hiddenSize, 1.0f);  // Bias towards remembering

        // Cell gate weights
        Wc.resize(inputSize * hiddenSize);
        Uc.resize(hiddenSize * hiddenSize);
        bc.resize(hiddenSize, 0.0f);

        // Output gate weights
        Wo.resize(inputSize * hiddenSize);
        Uo.resize(hiddenSize * hiddenSize);
        bo.resize(hiddenSize, 0.0f);

        // Initialize randomly
        std::random_device rd;
        std::mt19937 gen(rd());
        std::normal_distribution<float> dist(0.0f, scale);

        for (auto* w : { &Wi, &Ui, &Wf, &Uf, &Wc, &Uc, &Wo, &Uo })
            for (float& val : *w)
                val = dist(gen);

        // State vectors
        h.resize(hiddenSize, 0.0f);
        c.resize(hiddenSize, 0.0f);
    }

    std::vector<float> forward(const std::vector<float>& x)
    {
        std::vector<float> i_gate(hidSize), f_gate(hidSize);
        std::vector<float> c_gate(hidSize), o_gate(hidSize);

        // Input gate: i = sigmoid(Wi*x + Ui*h + bi)
        for (int j = 0; j < hidSize; ++j)
        {
            float sum = bi[j];
            for (int k = 0; k < inSize; ++k)
                sum += Wi[k * hidSize + j] * x[k];
            for (int k = 0; k < hidSize; ++k)
                sum += Ui[k * hidSize + j] * h[k];
            i_gate[j] = sigmoid(sum);
        }

        // Forget gate: f = sigmoid(Wf*x + Uf*h + bf)
        for (int j = 0; j < hidSize; ++j)
        {
            float sum = bf[j];
            for (int k = 0; k < inSize; ++k)
                sum += Wf[k * hidSize + j] * x[k];
            for (int k = 0; k < hidSize; ++k)
                sum += Uf[k * hidSize + j] * h[k];
            f_gate[j] = sigmoid(sum);
        }

        // Cell gate: c_tilde = tanh(Wc*x + Uc*h + bc)
        for (int j = 0; j < hidSize; ++j)
        {
            float sum = bc[j];
            for (int k = 0; k < inSize; ++k)
                sum += Wc[k * hidSize + j] * x[k];
            for (int k = 0; k < hidSize; ++k)
                sum += Uc[k * hidSize + j] * h[k];
            c_gate[j] = std::tanh(sum);
        }

        // Output gate: o = sigmoid(Wo*x + Uo*h + bo)
        for (int j = 0; j < hidSize; ++j)
        {
            float sum = bo[j];
            for (int k = 0; k < inSize; ++k)
                sum += Wo[k * hidSize + j] * x[k];
            for (int k = 0; k < hidSize; ++k)
                sum += Uo[k * hidSize + j] * h[k];
            o_gate[j] = sigmoid(sum);
        }

        // Cell state: c = f * c + i * c_tilde
        for (int j = 0; j < hidSize; ++j)
            c[j] = f_gate[j] * c[j] + i_gate[j] * c_gate[j];

        // Hidden state: h = o * tanh(c)
        for (int j = 0; j < hidSize; ++j)
            h[j] = o_gate[j] * std::tanh(c[j]);

        return h;
    }

    void reset()
    {
        std::fill(h.begin(), h.end(), 0.0f);
        std::fill(c.begin(), c.end(), 0.0f);
    }

    const std::vector<float>& getHiddenState() const { return h; }
    int getHiddenSize() const { return hidSize; }

    // Load pre-trained weights
    void loadWeights(const std::vector<float>& weights)
    {
        size_t offset = 0;
        auto loadVec = [&](std::vector<float>& vec) {
            std::copy(weights.begin() + offset,
                     weights.begin() + offset + vec.size(), vec.begin());
            offset += vec.size();
        };

        loadVec(Wi); loadVec(Ui); loadVec(bi);
        loadVec(Wf); loadVec(Uf); loadVec(bf);
        loadVec(Wc); loadVec(Uc); loadVec(bc);
        loadVec(Wo); loadVec(Uo); loadVec(bo);
    }

private:
    int inSize, hidSize;

    // Weights
    std::vector<float> Wi, Ui, bi;  // Input gate
    std::vector<float> Wf, Uf, bf;  // Forget gate
    std::vector<float> Wc, Uc, bc;  // Cell gate
    std::vector<float> Wo, Uo, bo;  // Output gate

    // State
    std::vector<float> h;  // Hidden state
    std::vector<float> c;  // Cell state

    static float sigmoid(float x)
    {
        return 1.0f / (1.0f + std::exp(-x));
    }
};

//==============================================================================
// Dense Layer
//==============================================================================

class DenseLayer
{
public:
    DenseLayer(int inputSize, int outputSize)
        : inSize(inputSize), outSize(outputSize)
    {
        weights.resize(inputSize * outputSize);
        biases.resize(outputSize, 0.0f);
        output.resize(outputSize);

        // Xavier initialization
        float scale = std::sqrt(2.0f / (inputSize + outputSize));
        std::random_device rd;
        std::mt19937 gen(rd());
        std::normal_distribution<float> dist(0.0f, scale);

        for (float& w : weights)
            w = dist(gen);
    }

    std::vector<float> forward(const std::vector<float>& input, bool softmax = false)
    {
        for (int j = 0; j < outSize; ++j)
        {
            float sum = biases[j];
            for (int i = 0; i < inSize; ++i)
                sum += weights[i * outSize + j] * input[i];
            output[j] = sum;
        }

        if (softmax)
            applySoftmax();

        return output;
    }

    void loadWeights(const std::vector<float>& w, const std::vector<float>& b)
    {
        std::copy(w.begin(), w.end(), weights.begin());
        std::copy(b.begin(), b.end(), biases.begin());
    }

private:
    int inSize, outSize;
    std::vector<float> weights;
    std::vector<float> biases;
    std::vector<float> output;

    void applySoftmax()
    {
        float maxVal = *std::max_element(output.begin(), output.end());
        float sum = 0.0f;
        for (float& v : output)
        {
            v = std::exp(v - maxVal);
            sum += v;
        }
        for (float& v : output)
            v /= sum;
    }
};

//==============================================================================
// Music Theory Helpers
//==============================================================================

struct MusicTheory
{
    // Scale patterns (semitones from root)
    static const std::vector<int>& getScale(const juce::String& scaleName)
    {
        static std::map<juce::String, std::vector<int>> scales = {
            { "Major",           { 0, 2, 4, 5, 7, 9, 11 } },
            { "Minor",           { 0, 2, 3, 5, 7, 8, 10 } },
            { "Harmonic Minor",  { 0, 2, 3, 5, 7, 8, 11 } },
            { "Melodic Minor",   { 0, 2, 3, 5, 7, 9, 11 } },
            { "Dorian",          { 0, 2, 3, 5, 7, 9, 10 } },
            { "Phrygian",        { 0, 1, 3, 5, 7, 8, 10 } },
            { "Lydian",          { 0, 2, 4, 6, 7, 9, 11 } },
            { "Mixolydian",      { 0, 2, 4, 5, 7, 9, 10 } },
            { "Pentatonic",      { 0, 2, 4, 7, 9 } },
            { "Blues",           { 0, 3, 5, 6, 7, 10 } },
            { "Chromatic",       { 0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11 } }
        };

        auto it = scales.find(scaleName);
        if (it != scales.end())
            return it->second;
        return scales["Major"];
    }

    // Chord patterns (semitones from root)
    static std::vector<int> getChord(const juce::String& chordType)
    {
        static std::map<juce::String, std::vector<int>> chords = {
            { "Major",      { 0, 4, 7 } },
            { "Minor",      { 0, 3, 7 } },
            { "Diminished", { 0, 3, 6 } },
            { "Augmented",  { 0, 4, 8 } },
            { "Major7",     { 0, 4, 7, 11 } },
            { "Minor7",     { 0, 3, 7, 10 } },
            { "Dominant7",  { 0, 4, 7, 10 } },
            { "Sus2",       { 0, 2, 7 } },
            { "Sus4",       { 0, 5, 7 } },
            { "Add9",       { 0, 4, 7, 14 } }
        };

        auto it = chords.find(chordType);
        if (it != chords.end())
            return it->second;
        return chords["Major"];
    }

    // Common chord progressions
    static std::vector<std::vector<int>> getProgression(const juce::String& name)
    {
        // Progressions as scale degrees (0-indexed)
        static std::map<juce::String, std::vector<std::vector<int>>> progressions = {
            { "Pop",       { {0}, {4}, {5}, {3} } },           // I-V-vi-IV
            { "Jazz",      { {0}, {3}, {6}, {1} } },           // ii-V-I
            { "Blues",     { {0}, {0}, {0}, {0}, {3}, {3}, {0}, {0}, {4}, {3}, {0}, {0} } },
            { "Classical", { {0}, {3}, {4}, {4}, {0} } },       // I-IV-V-V-I
            { "Rock",      { {0}, {4}, {3}, {0} } },           // I-V-IV-I
            { "Sad",       { {5}, {3}, {0}, {4} } },           // vi-IV-I-V
            { "Epic",      { {0}, {5}, {3}, {4} } }            // I-vi-IV-V
        };

        auto it = progressions.find(name);
        if (it != progressions.end())
            return it->second;
        return progressions["Pop"];
    }

    // Quantize note to scale
    static int quantizeToScale(int note, int rootNote, const std::vector<int>& scale)
    {
        int noteInOctave = (note - rootNote) % 12;
        if (noteInOctave < 0)
            noteInOctave += 12;

        // Find closest scale degree
        int closest = scale[0];
        int minDist = 12;
        for (int degree : scale)
        {
            int dist = std::abs(noteInOctave - degree);
            if (dist > 6) dist = 12 - dist;
            if (dist < minDist)
            {
                minDist = dist;
                closest = degree;
            }
        }

        return note - noteInOctave + closest;
    }
};

//==============================================================================
// Musical Event
//==============================================================================

struct MusicEvent
{
    enum class Type { NoteOn, NoteOff, ChordChange, Rest };

    Type type = Type::NoteOn;
    int note = 60;                   // MIDI note number
    float velocity = 0.8f;
    double duration = 0.5;           // Beats
    double timestamp = 0.0;          // Beats
    juce::String chordType = "Major";

    MusicEvent() = default;

    MusicEvent(Type t, int n, float vel, double dur, double time = 0.0)
        : type(t), note(n), velocity(vel), duration(dur), timestamp(time) {}
};

//==============================================================================
// Composition Style
//==============================================================================

struct CompositionStyle
{
    juce::String name;

    // Rhythm parameters
    float noteDensity = 0.7f;        // Notes per beat
    float syncopation = 0.3f;        // Off-beat emphasis
    float restProbability = 0.2f;    // Chance of rest

    // Melody parameters
    float stepwiseMotion = 0.6f;     // Preference for small intervals
    float leapSize = 0.3f;           // Average leap size (octaves)
    float octaveRange = 2.0f;        // Range in octaves

    // Harmony parameters
    juce::String scaleName = "Major";
    juce::String progressionName = "Pop";
    float chordTones = 0.7f;         // Preference for chord tones

    // Dynamics
    float dynamicRange = 0.4f;
    float crescendoTendency = 0.0f;

    // Style presets
    static CompositionStyle Classical()
    {
        CompositionStyle style;
        style.name = "Classical";
        style.noteDensity = 0.6f;
        style.syncopation = 0.1f;
        style.stepwiseMotion = 0.7f;
        style.scaleName = "Major";
        style.progressionName = "Classical";
        style.chordTones = 0.8f;
        return style;
    }

    static CompositionStyle Jazz()
    {
        CompositionStyle style;
        style.name = "Jazz";
        style.noteDensity = 0.8f;
        style.syncopation = 0.5f;
        style.stepwiseMotion = 0.4f;
        style.leapSize = 0.4f;
        style.scaleName = "Dorian";
        style.progressionName = "Jazz";
        style.chordTones = 0.6f;
        return style;
    }

    static CompositionStyle Electronic()
    {
        CompositionStyle style;
        style.name = "Electronic";
        style.noteDensity = 0.9f;
        style.syncopation = 0.4f;
        style.stepwiseMotion = 0.5f;
        style.scaleName = "Minor";
        style.progressionName = "Pop";
        style.chordTones = 0.7f;
        return style;
    }

    static CompositionStyle Ambient()
    {
        CompositionStyle style;
        style.name = "Ambient";
        style.noteDensity = 0.3f;
        style.syncopation = 0.1f;
        style.restProbability = 0.4f;
        style.stepwiseMotion = 0.8f;
        style.scaleName = "Pentatonic";
        style.progressionName = "Sad";
        style.chordTones = 0.9f;
        return style;
    }

    static CompositionStyle Pop()
    {
        CompositionStyle style;
        style.name = "Pop";
        style.noteDensity = 0.7f;
        style.syncopation = 0.3f;
        style.stepwiseMotion = 0.6f;
        style.scaleName = "Major";
        style.progressionName = "Pop";
        style.chordTones = 0.75f;
        return style;
    }
};

//==============================================================================
// LSTM Composer Main Class
//==============================================================================

class LSTMComposer
{
public:
    static constexpr int VocabSize = 128;      // MIDI notes
    static constexpr int HiddenSize = 256;
    static constexpr int SequenceLength = 32;
    static constexpr int NumLayers = 2;

    //==========================================================================
    // Constructor
    //==========================================================================

    LSTMComposer()
    {
        // Initialize LSTM layers
        for (int i = 0; i < NumLayers; ++i)
        {
            int inputSize = (i == 0) ? VocabSize : HiddenSize;
            lstmLayers.push_back(std::make_unique<LSTMCell>(inputSize, HiddenSize));
        }

        // Output layer
        outputLayer = std::make_unique<DenseLayer>(HiddenSize, VocabSize);

        // Initialize random
        std::random_device rd;
        rng.seed(rd());

        // Default style
        currentStyle = CompositionStyle::Pop();
    }

    //==========================================================================
    // Preparation
    //==========================================================================

    void prepare(double sampleRate, double bpm = 120.0)
    {
        this->sampleRate = sampleRate;
        this->beatsPerMinute = bpm;
        samplesPerBeat = sampleRate * 60.0 / bpm;
    }

    void reset()
    {
        for (auto& layer : lstmLayers)
            layer->reset();
        inputHistory.clear();
        generatedSequence.clear();
        currentBeat = 0.0;
    }

    //==========================================================================
    // Style & Key Configuration
    //==========================================================================

    void setStyle(const CompositionStyle& style)
    {
        currentStyle = style;
    }

    void setKey(int rootNote, const juce::String& scaleName = "Major")
    {
        keyRoot = rootNote % 12;
        currentScale = MusicTheory::getScale(scaleName);
    }

    void setTempo(double bpm)
    {
        beatsPerMinute = bpm;
        samplesPerBeat = sampleRate * 60.0 / bpm;
    }

    void setTemperature(float temp)
    {
        temperature = juce::jlimit(0.1f, 2.0f, temp);
    }

    void setCreativity(float creativity)
    {
        // Higher creativity = more deviation from theory
        theoryInfluence = 1.0f - juce::jlimit(0.0f, 1.0f, creativity);
    }

    //==========================================================================
    // Bio-Reactive Composition
    //==========================================================================

    void setBioData(float hrv, float coherence)
    {
        bioHRV = juce::jlimit(0.0f, 1.0f, hrv);
        bioCoherence = juce::jlimit(0.0f, 1.0f, coherence);
    }

    void setBioReactiveEnabled(bool enabled)
    {
        bioReactiveEnabled = enabled;
    }

    //==========================================================================
    // Seed / Prime the Network
    //==========================================================================

    void seedWithMelody(const std::vector<int>& notes)
    {
        reset();

        for (int note : notes)
        {
            // One-hot encode
            std::vector<float> input(VocabSize, 0.0f);
            input[note] = 1.0f;

            // Forward through network
            std::vector<float> hidden = input;
            for (auto& layer : lstmLayers)
                hidden = layer->forward(hidden);

            // Store in history
            inputHistory.push_back(note);
        }
    }

    void seedWithChordProgression(const juce::String& progressionName)
    {
        auto progression = MusicTheory::getProgression(progressionName);
        std::vector<int> notes;

        for (const auto& degree : progression)
        {
            int root = keyRoot + (degree[0] * 2) % 12;  // Simplified
            auto chord = MusicTheory::getChord("Major");
            for (int interval : chord)
                notes.push_back(60 + root + interval);
        }

        seedWithMelody(notes);
    }

    //==========================================================================
    // Generation
    //==========================================================================

    std::vector<MusicEvent> generateMelody(int numBeats)
    {
        std::vector<MusicEvent> events;

        double currentTime = 0.0;
        int lastNote = 60;

        while (currentTime < numBeats)
        {
            // Get style-influenced parameters
            float density = currentStyle.noteDensity;
            float restProb = currentStyle.restProbability;

            // Bio-reactive modulation
            if (bioReactiveEnabled)
            {
                density *= 0.5f + bioHRV * 0.5f;
                restProb *= 1.0f - bioCoherence * 0.5f;
            }

            // Decide: note or rest?
            std::uniform_real_distribution<float> dist(0.0f, 1.0f);
            if (dist(rng) < restProb)
            {
                // Rest
                double restDuration = 0.25 + dist(rng) * 0.75;
                events.push_back({ MusicEvent::Type::Rest, 0, 0.0f, restDuration, currentTime });
                currentTime += restDuration;
                continue;
            }

            // Generate next note using LSTM
            int nextNote = generateNextNote(lastNote);

            // Apply music theory constraints
            nextNote = applyTheoryConstraints(nextNote, lastNote);

            // Quantize to scale
            nextNote = MusicTheory::quantizeToScale(nextNote, keyRoot, currentScale);

            // Generate velocity
            float velocity = 0.5f + dist(rng) * 0.4f;
            if (bioReactiveEnabled)
                velocity *= 0.7f + bioCoherence * 0.3f;

            // Generate duration based on density
            double duration = 0.25 / density;
            duration = std::max(0.125, std::min(2.0, duration));

            // Add syncopation
            if (dist(rng) < currentStyle.syncopation)
                currentTime += 0.125;

            // Create event
            events.push_back({ MusicEvent::Type::NoteOn, nextNote, velocity, duration, currentTime });

            lastNote = nextNote;
            currentTime += duration;
        }

        return events;
    }

    std::vector<MusicEvent> generateHarmony(const std::vector<MusicEvent>& melody, int numVoices = 3)
    {
        std::vector<MusicEvent> harmony;

        for (const auto& event : melody)
        {
            if (event.type != MusicEvent::Type::NoteOn)
                continue;

            // Generate harmony notes based on chord tones
            auto chordIntervals = MusicTheory::getChord("Major");

            for (int v = 1; v < numVoices && v < static_cast<int>(chordIntervals.size()); ++v)
            {
                int harmonyNote = event.note + chordIntervals[v];

                // Keep in reasonable range
                while (harmonyNote > event.note + 12)
                    harmonyNote -= 12;
                while (harmonyNote < event.note - 24)
                    harmonyNote += 12;

                harmony.push_back({
                    MusicEvent::Type::NoteOn,
                    harmonyNote,
                    event.velocity * 0.7f,
                    event.duration,
                    event.timestamp
                });
            }
        }

        return harmony;
    }

    std::vector<MusicEvent> generateBassline(int numBeats)
    {
        std::vector<MusicEvent> bassline;

        auto progression = MusicTheory::getProgression(currentStyle.progressionName);
        int progIndex = 0;
        double currentTime = 0.0;

        while (currentTime < numBeats)
        {
            // Get current chord root
            int chordDegree = progression[progIndex % progression.size()][0];
            int bassNote = keyRoot + 36 + (chordDegree * 2) % 12;  // Low octave

            // Create bass note
            bassline.push_back({
                MusicEvent::Type::NoteOn,
                bassNote,
                0.9f,
                1.0,
                currentTime
            });

            // Optionally add passing tones
            std::uniform_real_distribution<float> dist(0.0f, 1.0f);
            if (dist(rng) > 0.5f)
            {
                // Add fifth
                bassline.push_back({
                    MusicEvent::Type::NoteOn,
                    bassNote + 7,
                    0.7f,
                    0.5,
                    currentTime + 0.5
                });
            }

            currentTime += 1.0;  // One bar
            progIndex++;
        }

        return bassline;
    }

    std::vector<MusicEvent> generateDrumPattern(int numBeats, const juce::String& style = "Basic")
    {
        std::vector<MusicEvent> drums;

        // GM Drum map
        constexpr int Kick = 36;
        constexpr int Snare = 38;
        constexpr int HiHat = 42;
        constexpr int OpenHat = 46;
        constexpr int Ride = 51;

        double currentTime = 0.0;
        std::uniform_real_distribution<float> dist(0.0f, 1.0f);

        while (currentTime < numBeats)
        {
            int beatInBar = static_cast<int>(currentTime * 4) % 16;

            // Kick on 1 and 3 (or varied for different styles)
            if (beatInBar == 0 || beatInBar == 8)
            {
                drums.push_back({ MusicEvent::Type::NoteOn, Kick, 1.0f, 0.1, currentTime });
            }
            else if (beatInBar == 6 && dist(rng) > 0.5f)
            {
                // Syncopated kick
                drums.push_back({ MusicEvent::Type::NoteOn, Kick, 0.8f, 0.1, currentTime });
            }

            // Snare on 2 and 4
            if (beatInBar == 4 || beatInBar == 12)
            {
                drums.push_back({ MusicEvent::Type::NoteOn, Snare, 0.95f, 0.1, currentTime });
            }

            // Hi-hat pattern
            if (beatInBar % 2 == 0)
            {
                bool open = (beatInBar == 2 || beatInBar == 10) && dist(rng) > 0.6f;
                drums.push_back({
                    MusicEvent::Type::NoteOn,
                    open ? OpenHat : HiHat,
                    0.6f + dist(rng) * 0.2f,
                    0.05,
                    currentTime
                });
            }

            currentTime += 0.0625;  // 16th notes
        }

        return drums;
    }

    //==========================================================================
    // MIDI Output
    //==========================================================================

    void eventsToMidiBuffer(const std::vector<MusicEvent>& events,
                            juce::MidiBuffer& midiBuffer,
                            double startTime = 0.0)
    {
        for (const auto& event : events)
        {
            if (event.type == MusicEvent::Type::NoteOn)
            {
                int samplePos = static_cast<int>((event.timestamp - startTime) * samplesPerBeat);

                midiBuffer.addEvent(
                    juce::MidiMessage::noteOn(1, event.note,
                                              static_cast<juce::uint8>(event.velocity * 127)),
                    samplePos);

                int noteOffPos = samplePos + static_cast<int>(event.duration * samplesPerBeat);
                midiBuffer.addEvent(
                    juce::MidiMessage::noteOff(1, event.note),
                    noteOffPos);
            }
        }
    }

    //==========================================================================
    // Continuous Generation
    //==========================================================================

    void processBlock(juce::MidiBuffer& midiBuffer, int numSamples)
    {
        if (!isPlaying)
            return;

        double blockBeats = numSamples / samplesPerBeat;

        // Generate ahead if needed
        while (generatedSequence.empty() ||
               generatedSequence.back().timestamp < currentBeat + blockBeats + 4.0)
        {
            auto newEvents = generateMelody(4);  // Generate 4 beats ahead
            for (auto& event : newEvents)
            {
                event.timestamp += generatedSequence.empty() ?
                    currentBeat : generatedSequence.back().timestamp;
                generatedSequence.push_back(event);
            }
        }

        // Output events in this block
        for (const auto& event : generatedSequence)
        {
            if (event.timestamp >= currentBeat && event.timestamp < currentBeat + blockBeats)
            {
                if (event.type == MusicEvent::Type::NoteOn)
                {
                    int samplePos = static_cast<int>((event.timestamp - currentBeat) * samplesPerBeat);

                    midiBuffer.addEvent(
                        juce::MidiMessage::noteOn(1, event.note,
                                                  static_cast<juce::uint8>(event.velocity * 127)),
                        samplePos);

                    int noteOffPos = samplePos + static_cast<int>(event.duration * samplesPerBeat);
                    if (noteOffPos < numSamples)
                    {
                        midiBuffer.addEvent(
                            juce::MidiMessage::noteOff(1, event.note),
                            noteOffPos);
                    }
                }
            }
        }

        currentBeat += blockBeats;

        // Clean up old events
        while (!generatedSequence.empty() && generatedSequence.front().timestamp < currentBeat - 4.0)
            generatedSequence.erase(generatedSequence.begin());
    }

    void play() { isPlaying = true; }
    void stop() { isPlaying = false; }
    bool getIsPlaying() const { return isPlaying; }

    //==========================================================================
    // Training / Learning
    //==========================================================================

    void learnFromMelody(const std::vector<int>& notes)
    {
        // Simplified online learning - adjust weights slightly
        // In production, this would use backpropagation through time

        for (size_t i = 1; i < notes.size(); ++i)
        {
            // Store transition probability
            auto& transitions = learnedTransitions[notes[i - 1]];
            transitions[notes[i]] += 1.0f;
        }
    }

    void saveModel(const juce::File& file)
    {
        // Serialize weights
        juce::MemoryBlock data;
        // ... serialization logic
        file.replaceWithData(data.getData(), data.getSize());
    }

    void loadModel(const juce::File& file)
    {
        // Deserialize weights
        juce::MemoryBlock data;
        file.loadFileAsData(data);
        // ... deserialization logic
    }

private:
    //==========================================================================
    // Member Variables
    //==========================================================================

    // Network
    std::vector<std::unique_ptr<LSTMCell>> lstmLayers;
    std::unique_ptr<DenseLayer> outputLayer;

    // State
    std::deque<int> inputHistory;
    std::vector<MusicEvent> generatedSequence;
    double currentBeat = 0.0;
    bool isPlaying = false;

    // Music parameters
    int keyRoot = 0;                 // C
    std::vector<int> currentScale = MusicTheory::getScale("Major");
    CompositionStyle currentStyle;

    // Generation parameters
    float temperature = 1.0f;
    float theoryInfluence = 0.7f;

    // Bio-reactive
    float bioHRV = 0.5f;
    float bioCoherence = 0.5f;
    bool bioReactiveEnabled = false;

    // Timing
    double sampleRate = 48000.0;
    double beatsPerMinute = 120.0;
    double samplesPerBeat = 24000.0;

    // Learning
    std::map<int, std::map<int, float>> learnedTransitions;

    // Random
    std::mt19937 rng;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    int generateNextNote(int lastNote)
    {
        // Create input (one-hot of last note)
        std::vector<float> input(VocabSize, 0.0f);
        input[juce::jlimit(0, VocabSize - 1, lastNote)] = 1.0f;

        // Forward pass through LSTM layers
        std::vector<float> hidden = input;
        for (auto& layer : lstmLayers)
            hidden = layer->forward(hidden);

        // Output layer with softmax
        auto probabilities = outputLayer->forward(hidden, true);

        // Apply temperature
        if (temperature != 1.0f)
        {
            for (float& p : probabilities)
                p = std::pow(p, 1.0f / temperature);

            float sum = 0.0f;
            for (float p : probabilities)
                sum += p;
            for (float& p : probabilities)
                p /= sum;
        }

        // Incorporate learned transitions
        if (!learnedTransitions.empty())
        {
            auto it = learnedTransitions.find(lastNote);
            if (it != learnedTransitions.end())
            {
                float learnedSum = 0.0f;
                for (const auto& [note, count] : it->second)
                    learnedSum += count;

                if (learnedSum > 0)
                {
                    for (const auto& [note, count] : it->second)
                    {
                        float learnedProb = count / learnedSum;
                        probabilities[note] = probabilities[note] * 0.7f + learnedProb * 0.3f;
                    }
                }
            }
        }

        // Sample from distribution
        std::uniform_real_distribution<float> dist(0.0f, 1.0f);
        float r = dist(rng);
        float cumulative = 0.0f;

        for (int i = 0; i < VocabSize; ++i)
        {
            cumulative += probabilities[i];
            if (r <= cumulative)
                return i;
        }

        return lastNote;  // Fallback
    }

    int applyTheoryConstraints(int generatedNote, int lastNote)
    {
        std::uniform_real_distribution<float> dist(0.0f, 1.0f);

        // Apply theory constraints based on influence parameter
        if (dist(rng) < theoryInfluence)
        {
            // Limit leap size
            int maxLeap = static_cast<int>(currentStyle.leapSize * 12);
            if (std::abs(generatedNote - lastNote) > maxLeap)
            {
                // Constrain to max leap
                int direction = (generatedNote > lastNote) ? 1 : -1;
                generatedNote = lastNote + direction * maxLeap;
            }

            // Prefer stepwise motion
            if (dist(rng) < currentStyle.stepwiseMotion)
            {
                int step = (dist(rng) > 0.5f) ? 2 : -2;  // Whole step
                if (dist(rng) > 0.7f)
                    step = (step > 0) ? 1 : -1;  // Half step
                generatedNote = lastNote + step;
            }

            // Keep in range
            int centerNote = 60 + keyRoot;
            int rangeNotes = static_cast<int>(currentStyle.octaveRange * 12);
            generatedNote = juce::jlimit(centerNote - rangeNotes,
                                         centerNote + rangeNotes,
                                         generatedNote);
        }

        return generatedNote;
    }

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(LSTMComposer)
};

} // namespace AI
} // namespace Echoelmusic
