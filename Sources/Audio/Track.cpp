#include "Track.h"
#include "../Core/DSPOptimizations.h"

//==============================================================================
Track::Track(Type trackType, const juce::String& trackName)
    : type(trackType), name(trackName)
{
}

Track::~Track()
{
}

//==============================================================================
void Track::prepare(double sampleRate, int maximumBlockSize)
{
    currentSampleRate = sampleRate;
    currentBlockSize = maximumBlockSize;

    if (type == Type::Audio)
    {
        // Pre-allocate buffers
        playbackBuffer.setSize(2, maximumBlockSize * 100); // 100 blocks of audio
        playbackBuffer.clear();

        // OPTIMIZATION: Pre-allocate recording buffer to avoid allocations in audio callback
        // Default: 5 minutes at current sample rate (~14MB at 48kHz stereo)
        const int fiveMinutesSamples = static_cast<int>(sampleRate * 60.0 * 5.0);
        recordedAudio.setSize(2, fiveMinutesSamples, false, true, false);
        recordedAudio.clear();
    }
}

void Track::releaseResources()
{
    playbackBuffer.setSize(0, 0);
}

//==============================================================================
void Track::setVolume(float newVolume)
{
    volume.store(juce::jlimit(0.0f, 2.0f, newVolume));
}

void Track::setPan(float newPan)
{
    float clampedPan = juce::jlimit(-1.0f, 1.0f, newPan);
    pan.store(clampedPan);

    // OPTIMIZATION: Pre-calculate pan gains (constant power) to avoid trig in audio thread
    const auto& trigTables = Echoel::DSP::TrigLookupTables::getInstance();
    float normalizedAngle = (clampedPan + 1.0f) * 0.125f;  // Maps -1..1 to 0..0.25 (quarter circle)
    cachedLeftGain.store(trigTables.fastCos(normalizedAngle));
    cachedRightGain.store(trigTables.fastSin(normalizedAngle));
}

//==============================================================================
void Track::processBlock(juce::AudioBuffer<float>& outputBuffer, int numSamples)
{
    if (type == Type::Audio)
    {
        // Get volume and cached pan gains (pre-calculated in setPan)
        float vol = volume.load();
        float leftGain = cachedLeftGain.load();
        float rightGain = cachedRightGain.load();

        // Mix playback buffer to output
        // (Simplified - in reality, we'd read from clips at current position)
        for (int channel = 0; channel < juce::jmin(2, outputBuffer.getNumChannels()); ++channel)
        {
            if (channel < playbackBuffer.getNumChannels() && numSamples <= playbackBuffer.getNumSamples())
            {
                float gain = vol * (channel == 0 ? leftGain : rightGain);

                outputBuffer.addFrom(channel, 0,
                                   playbackBuffer, channel, 0,
                                   numSamples, gain);
            }
        }
    }
    else if (type == Type::MIDI)
    {
        // MIDI processing (later - trigger instruments, etc.)
        // For now, just pass through
    }
}

void Track::recordInput(const float* const* input, int numInputs, int numSamples, int64_t position)
{
    if (type != Type::Audio)
        return;

    // Calculate write position
    const int writePos = static_cast<int>(position - recordingStartPosition);
    const int requiredSize = writePos + numSamples;
    const int currentSize = recordedAudio.getNumSamples();

    // OPTIMIZATION: Only grow if we exceed pre-allocated buffer (rare case)
    if (requiredSize > currentSize)
    {
        // Double the buffer size to minimize future reallocations
        const int newSize = juce::jmax(juce::nextPowerOfTwo(requiredSize),
                                       currentSize * 2);
        recordedAudio.setSize(2, newSize, true, true, false);
    }

    // Copy input to recorded buffer using SIMD-optimized copy
    const int channelsToCopy = juce::jmin(2, numInputs);
    for (int channel = 0; channel < channelsToCopy; ++channel)
    {
        if (input[channel] != nullptr)
        {
            juce::FloatVectorOperations::copy(
                recordedAudio.getWritePointer(channel, writePos),
                input[channel],
                numSamples
            );
        }
    }
}

//==============================================================================
bool Track::addAudioClip(const juce::File& audioFile, int64_t startPosition)
{
    juce::AudioFormatManager formatManager;
    formatManager.registerBasicFormats();

    std::unique_ptr<juce::AudioFormatReader> reader(
        formatManager.createReaderFor(audioFile));

    if (reader == nullptr)
        return false;

    // Read entire file into playback buffer
    int numSamples = (int)reader->lengthInSamples;
    int numChannels = juce::jmin(2, (int)reader->numChannels);

    juce::AudioBuffer<float> tempBuffer(numChannels, numSamples);
    reader->read(&tempBuffer, 0, numSamples, 0, true, true);

    addAudioClip(tempBuffer, startPosition);
    return true;
}

void Track::addAudioClip(const juce::AudioBuffer<float>& buffer, int64_t startPosition)
{
    // Copy buffer to playback buffer at position
    // (Simplified - in reality we'd have a clip management system)

    int numSamples = buffer.getNumSamples();
    int numChannels = juce::jmin(2, buffer.getNumChannels());

    // Ensure playback buffer is large enough
    if (playbackBuffer.getNumSamples() < numSamples)
    {
        playbackBuffer.setSize(2, numSamples, false, true, false);
    }

    for (int channel = 0; channel < numChannels; ++channel)
    {
        juce::FloatVectorOperations::copy(
            playbackBuffer.getWritePointer(channel),
            buffer.getReadPointer(channel),
            numSamples
        );
    }
}

//==============================================================================
void Track::addMIDINote(int noteNumber, float velocity, int64_t startSample, int lengthSamples)
{
    if (type != Type::MIDI)
        return;

    // Add note-on
    juce::MidiMessage noteOn = juce::MidiMessage::noteOn(1, noteNumber, velocity);
    midiSequence.addEvent(noteOn, (int)startSample);

    // Add note-off
    juce::MidiMessage noteOff = juce::MidiMessage::noteOff(1, noteNumber);
    midiSequence.addEvent(noteOff, (int)(startSample + lengthSamples));
}
