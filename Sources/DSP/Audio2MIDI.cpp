#include "Audio2MIDI.h"
#include "../Core/DSPOptimizations.h"
#include <cmath>
#include <algorithm>

//==============================================================================
// Audio2MIDI Implementation

Audio2MIDI::Audio2MIDI()
    : forwardFFT(fftOrder),
      window(fftSize, juce::dsp::WindowingFunction<float>::hann)
{
    reset();
}

Audio2MIDI::~Audio2MIDI() {}

void Audio2MIDI::prepare(double sampleRate, int samplesPerBlock, int numChannels)
{
    currentSampleRate = sampleRate;
    currentNumChannels = numChannels;

    // Pre-allocate note vectors to avoid allocations in audio thread
    activeNotes.reserve(static_cast<size_t>(maxPolyphony * 2));
    detectedNotes.reserve(1024);  // Room for a full song's worth of notes
}

void Audio2MIDI::reset()
{
    noteActivity.fill(0.0f);
    activeNotes.clear();
    detectedNotes.clear();
    midiOutputBuffer.clear();
    currentTimeSeconds = 0.0;
    previousEnergy = 0.0f;
}

void Audio2MIDI::process(const juce::AudioBuffer<float>& buffer)
{
    performFFTAnalysis(buffer);
    detectPitch();
    detectOnsets(buffer);
    updateActiveNotes();
    generateMidiEvents();

    currentTimeSeconds += buffer.getNumSamples() / currentSampleRate;
}

juce::MidiBuffer Audio2MIDI::getMidiOutput()
{
    juce::MidiBuffer output = midiOutputBuffer;
    midiOutputBuffer.clear();
    return output;
}

//==============================================================================
// Detection Modes

void Audio2MIDI::setDetectionMode(DetectionMode mode) { detectionMode = mode; }
Audio2MIDI::DetectionMode Audio2MIDI::getDetectionMode() const { return detectionMode; }

//==============================================================================
// Settings

void Audio2MIDI::setMinimumNoteDuration(float ms) { minimumNoteDuration = juce::jlimit(10.0f, 500.0f, ms); }
void Audio2MIDI::setOnsetSensitivity(float sensitivity) { onsetSensitivity = juce::jlimit(0.0f, 1.0f, sensitivity); }
void Audio2MIDI::setPitchSensitivity(float sensitivity) { pitchSensitivity = juce::jlimit(0.0f, 1.0f, sensitivity); }
void Audio2MIDI::setMaxPolyphony(int voices) { maxPolyphony = juce::jlimit(1, 10, voices); }
void Audio2MIDI::setQuantization(bool enabled) { quantizationEnabled = enabled; }
void Audio2MIDI::setQuantizationGrid(float beatDivision) { quantizationGrid = beatDivision; }
void Audio2MIDI::setVelocitySensitive(bool enabled) { velocitySensitive = enabled; }
void Audio2MIDI::setCapturePitchBend(bool enabled) { capturePitchBend = enabled; }

//==============================================================================
// Detected Notes

std::vector<Audio2MIDI::Note> Audio2MIDI::getDetectedNotes() const
{
    return detectedNotes;
}

void Audio2MIDI::clearDetectedNotes()
{
    detectedNotes.clear();
}

//==============================================================================
// Real-Time Monitoring

Audio2MIDI::CurrentPitch Audio2MIDI::getCurrentPitch() const
{
    return currentPitch;
}

std::array<float, 128> Audio2MIDI::getCurrentNoteActivity() const
{
    return noteActivity;
}

//==============================================================================
// Export

void Audio2MIDI::exportToMidi(const juce::File& outputFile)
{
    juce::ignoreUnused(outputFile);
    // Would write MIDI file here
}

juce::MidiMessageSequence Audio2MIDI::getMidiSequence() const
{
    juce::MidiMessageSequence sequence;

    for (const auto& note : detectedNotes)
    {
        // Note on
        juce::MidiMessage noteOn = juce::MidiMessage::noteOn(1, note.midiNote, static_cast<juce::uint8>(note.velocity));
        noteOn.setTimeStamp(note.startTime);
        sequence.addEvent(noteOn);

        // Note off
        juce::MidiMessage noteOff = juce::MidiMessage::noteOff(1, note.midiNote);
        noteOff.setTimeStamp(note.startTime + note.duration);
        sequence.addEvent(noteOff);
    }

    sequence.updateMatchedPairs();
    return sequence;
}

//==============================================================================
// Presets

void Audio2MIDI::loadPreset(Preset preset)
{
    switch (preset)
    {
        case Preset::Vocals:
            setDetectionMode(DetectionMode::Monophonic);
            setMinimumNoteDuration(100.0f);
            setOnsetSensitivity(0.6f);
            setPitchSensitivity(0.7f);
            setCapturePitchBend(true);
            setVelocitySensitive(true);
            break;

        case Preset::Guitar:
            setDetectionMode(DetectionMode::Polyphonic);
            setMaxPolyphony(6);
            setMinimumNoteDuration(50.0f);
            setOnsetSensitivity(0.8f);
            setPitchSensitivity(0.6f);
            break;

        case Preset::Piano:
            setDetectionMode(DetectionMode::Polyphonic);
            setMaxPolyphony(10);
            setMinimumNoteDuration(30.0f);
            setOnsetSensitivity(0.7f);
            setPitchSensitivity(0.7f);
            break;

        case Preset::Bass:
            setDetectionMode(DetectionMode::Monophonic);
            setMinimumNoteDuration(100.0f);
            setOnsetSensitivity(0.7f);
            setPitchSensitivity(0.8f);
            break;

        case Preset::Drums:
            setDetectionMode(DetectionMode::Percussive);
            setMinimumNoteDuration(10.0f);
            setOnsetSensitivity(0.9f);
            break;

        default:
            setDetectionMode(DetectionMode::Auto);
            setMinimumNoteDuration(50.0f);
            setOnsetSensitivity(0.7f);
            setPitchSensitivity(0.6f);
            break;
    }
}

//==============================================================================
// Internal Algorithms

void Audio2MIDI::performFFTAnalysis(const juce::AudioBuffer<float>& buffer)
{
    int numSamples = juce::jmin(buffer.getNumSamples(), fftSize);

    // Mix to mono
    fftData.fill(0.0f);
    for (int i = 0; i < numSamples; ++i)
    {
        float sample = 0.0f;
        for (int channel = 0; channel < buffer.getNumChannels(); ++channel)
            sample += buffer.getSample(channel, i);

        fftData[i] = sample / buffer.getNumChannels();
    }

    // Apply window
    window.multiplyWithWindowingTable(fftData.data(), fftSize);

    // Perform FFT
    forwardFFT.performFrequencyOnlyForwardTransform(fftData.data());

    // Store magnitudes
    for (int i = 0; i < fftSize; ++i)
        magnitudes[i] = fftData[i];
}

void Audio2MIDI::detectPitch()
{
    if (detectionMode == DetectionMode::Monophonic || detectionMode == DetectionMode::Auto)
    {
        float frequency = detectFundamentalFrequency();

        currentPitch.frequency = frequency;
        currentPitch.confidence = (frequency > 0.0f) ? 0.8f : 0.0f;

        if (frequency > 0.0f)
        {
            currentPitch.midiNote = frequencyToMidiNote(frequency);
            float exactMidiNote = 12.0f * std::log2(frequency / 440.0f) + 69.0f;
            currentPitch.cents = (exactMidiNote - currentPitch.midiNote) * 100.0f;
            currentPitch.noteActive = true;

            // Update note activity
            noteActivity[currentPitch.midiNote] = 1.0f;
        }
        else
        {
            currentPitch.noteActive = false;
        }
    }
    else if (detectionMode == DetectionMode::Polyphonic)
    {
        auto pitches = detectPolyphonicPitches();

        // Update note activity for all detected pitches
        noteActivity.fill(0.0f);
        for (float pitch : pitches)
        {
            int midiNote = frequencyToMidiNote(pitch);
            if (midiNote >= 0 && midiNote < 128)
                noteActivity[midiNote] = 1.0f;
        }
    }

    // Decay note activity
    for (auto& activity : noteActivity)
    {
        activity *= 0.95f;  // Smooth decay
    }
}

void Audio2MIDI::detectOnsets(const juce::AudioBuffer<float>& buffer)
{
    float energy = calculateEnergy(buffer);
    float energyIncrease = energy - previousEnergy;

    // Onset detected if energy increases significantly
    float onsetThreshold = 0.5f * (1.0f - onsetSensitivity);
    if (energyIncrease > onsetThreshold && energy > 0.01f)
    {
        // New note detected
        if (currentPitch.noteActive && currentPitch.confidence > pitchSensitivity)
        {
            // Check if note is already active
            bool alreadyActive = false;
            for (const auto& note : activeNotes)
            {
                if (note.active && note.midiNote == currentPitch.midiNote)
                {
                    alreadyActive = true;
                    break;
                }
            }

            if (!alreadyActive && static_cast<int>(activeNotes.size()) < maxPolyphony)
            {
                ActiveNote newNote;
                newNote.midiNote = currentPitch.midiNote;
                newNote.startTime = static_cast<float>(currentTimeSeconds);
                newNote.startAmplitude = energy;
                newNote.active = true;
                activeNotes.push_back(newNote);
            }
        }
    }

    previousEnergy = energy;
}

void Audio2MIDI::updateActiveNotes()
{
    for (auto it = activeNotes.begin(); it != activeNotes.end(); )
    {
        auto& note = *it;

        // Check if note should end (activity dropped)
        float currentActivity = noteActivity[note.midiNote];
        if (currentActivity < 0.1f)
        {
            // Note ended - add to detected notes
            float duration = static_cast<float>(currentTimeSeconds) - note.startTime;

            if (duration >= minimumNoteDuration / 1000.0f)
            {
                Note detectedNote;
                detectedNote.midiNote = note.midiNote;
                detectedNote.startTime = note.startTime;
                detectedNote.duration = duration;
                detectedNote.pitch = midiNoteToFrequency(note.midiNote);
                detectedNote.confidence = 0.8f;

                // Calculate velocity
                if (velocitySensitive)
                    detectedNote.velocity = juce::jlimit(1, 127, static_cast<int>(note.startAmplitude * 127.0f));
                else
                    detectedNote.velocity = 80;

                detectedNotes.push_back(detectedNote);
            }

            it = activeNotes.erase(it);
        }
        else
        {
            ++it;
        }
    }
}

void Audio2MIDI::generateMidiEvents()
{
    // This would generate real-time MIDI events
    // For now, notes are stored in detectedNotes array
}

float Audio2MIDI::detectFundamentalFrequency()
{
    // Simplified fundamental frequency detection using spectral peak
    float binFrequency = static_cast<float>(currentSampleRate) / fftSize;

    int peakBin = 0;
    float peakMagnitude = 0.0f;

    // Search for peak in musical range (80Hz - 2000Hz)
    int minBin = static_cast<int>(80.0f / binFrequency);
    int maxBin = static_cast<int>(2000.0f / binFrequency);

    for (int bin = minBin; bin < maxBin && bin < fftSize / 2; ++bin)
    {
        if (magnitudes[bin] > peakMagnitude)
        {
            peakMagnitude = magnitudes[bin];
            peakBin = bin;
        }
    }

    if (peakMagnitude > 0.01f)  // Minimum threshold
    {
        float frequency = peakBin * binFrequency;

        // Parabolic interpolation for better accuracy
        if (peakBin > 0 && peakBin < fftSize / 2 - 1)
        {
            float alpha = magnitudes[peakBin - 1];
            float beta = magnitudes[peakBin];
            float gamma = magnitudes[peakBin + 1];

            float delta = 0.5f * (alpha - gamma) / (alpha - 2.0f * beta + gamma);
            frequency = (peakBin + delta) * binFrequency;
        }

        return frequency;
    }

    return 0.0f;  // No pitch detected
}

std::vector<float> Audio2MIDI::detectPolyphonicPitches()
{
    std::vector<float> pitches;
    float binFrequency = static_cast<float>(currentSampleRate) / fftSize;

    // Find multiple spectral peaks
    int minBin = static_cast<int>(80.0f / binFrequency);
    int maxBin = static_cast<int>(2000.0f / binFrequency);

    for (int bin = minBin + 2; bin < maxBin - 2 && bin < fftSize / 2 - 2; ++bin)
    {
        // Check if this is a local maximum
        if (magnitudes[bin] > magnitudes[bin - 1] &&
            magnitudes[bin] > magnitudes[bin + 1] &&
            magnitudes[bin] > magnitudes[bin - 2] &&
            magnitudes[bin] > magnitudes[bin + 2] &&
            magnitudes[bin] > 0.05f)  // Threshold
        {
            float frequency = bin * binFrequency;
            pitches.push_back(frequency);

            if (static_cast<int>(pitches.size()) >= maxPolyphony)
                break;
        }
    }

    return pitches;
}

float Audio2MIDI::calculateEnergy(const juce::AudioBuffer<float>& buffer)
{
    float energy = 0.0f;
    int numSamples = buffer.getNumSamples();

    for (int channel = 0; channel < buffer.getNumChannels(); ++channel)
    {
        const float* channelData = buffer.getReadPointer(channel);
        for (int i = 0; i < numSamples; ++i)
        {
            float sample = channelData[i];
            energy += sample * sample;
        }
    }

    // Using fast sqrt for energy calculation
    return Echoel::DSP::FastMath::fastSqrt(energy / (numSamples * buffer.getNumChannels()));
}

int Audio2MIDI::frequencyToMidiNote(float frequency)
{
    if (frequency <= 0.0f)
        return -1;

    float midiNote = 12.0f * std::log2(frequency / 440.0f) + 69.0f;
    return juce::jlimit(0, 127, static_cast<int>(std::round(midiNote)));
}

float Audio2MIDI::midiNoteToFrequency(int midiNote)
{
    // Using fast pow for MIDI to frequency conversion
    return 440.0f * Echoel::DSP::FastMath::fastPow(2.0f, (midiNote - 69) / 12.0f);
}
