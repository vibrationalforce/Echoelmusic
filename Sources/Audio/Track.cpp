#include "Track.h"

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

        // Pre-allocate recording buffer to avoid audio thread allocation
        // 10 minutes at sample rate (lock-free audio thread safety)
        int maxRecordingSamples = static_cast<int>(sampleRate * kMaxRecordingSeconds);
        recordedAudio.setSize(2, maxRecordingSamples, false, true, false);
        recordedAudio.clear();
        recordedSampleCount.store(0);
        recordingBufferInitialized = true;
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
    pan.store(juce::jlimit(-1.0f, 1.0f, newPan));
}

//==============================================================================
void Track::processBlock(juce::AudioBuffer<float>& outputBuffer, int numSamples)
{
    if (type == Type::Audio)
    {
        // Get volume and pan
        float vol = volume.load();
        float panValue = pan.load();

        // Calculate pan gains (constant power)
        float leftGain = std::cos((panValue + 1.0f) * juce::MathConstants<float>::pi * 0.25f);
        float rightGain = std::sin((panValue + 1.0f) * juce::MathConstants<float>::pi * 0.25f);

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

    // Calculate write position (lock-free, no allocation in audio thread)
    int writePos = static_cast<int>(position - recordingStartPosition);
    int bufferSize = recordedAudio.getNumSamples();

    // Bounds check - if we exceed pre-allocated buffer, clip to available space
    // This avoids any allocation in the audio thread
    if (writePos < 0)
        return;

    int samplesToWrite = numSamples;
    if (writePos + samplesToWrite > bufferSize)
    {
        samplesToWrite = bufferSize - writePos;
        if (samplesToWrite <= 0)
            return;  // Buffer full - no allocation, just stop recording
    }

    // Copy input to pre-allocated buffer (lock-free)
    for (int channel = 0; channel < juce::jmin(2, numInputs); ++channel)
    {
        if (input[channel] != nullptr)
        {
            juce::FloatVectorOperations::copy(
                recordedAudio.getWritePointer(channel, writePos),
                input[channel],
                samplesToWrite
            );
        }
    }

    // Update recorded sample count atomically (lock-free)
    int newCount = writePos + samplesToWrite;
    int currentCount = recordedSampleCount.load();
    while (newCount > currentCount)
    {
        if (recordedSampleCount.compare_exchange_weak(currentCount, newCount))
            break;
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
