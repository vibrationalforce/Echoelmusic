#include "AudioEngine.h"
#include "Track.h"

//==============================================================================
AudioEngine::AudioEngine()
{
}

AudioEngine::~AudioEngine()
{
    releaseResources();
}

//==============================================================================
// Setup & Configuration
//==============================================================================

void AudioEngine::prepare(double sampleRate, int maximumBlockSize)
{
    currentSampleRate = sampleRate;
    currentBlockSize = maximumBlockSize;

    // Pre-allocate master buffers
    masterBuffer.setSize(2, maximumBlockSize);
    masterBuffer.clear();

    recordBuffer.setSize(2, maximumBlockSize);
    recordBuffer.clear();

    // Prepare all tracks
    const juce::ScopedLock sl(tracksLock);
    for (auto& track : tracks)
    {
        if (track != nullptr)
            track->prepare(sampleRate, maximumBlockSize);
    }
}

void AudioEngine::releaseResources()
{
    stop();

    const juce::ScopedLock sl(tracksLock);
    for (auto& track : tracks)
    {
        if (track != nullptr)
            track->releaseResources();
    }
}

//==============================================================================
// Transport Control
//==============================================================================

void AudioEngine::play()
{
    playing.store(true);
}

void AudioEngine::stop()
{
    playing.store(false);
    recording.store(false);
}

void AudioEngine::setPosition(int64_t positionInSamples)
{
    playheadPosition.store(juce::jmax(int64_t(0), positionInSamples));
}

void AudioEngine::setLoopRegion(int64_t startSample, int64_t endSample)
{
    loopStart = startSample;
    loopEnd = endSample;
}

void AudioEngine::setLooping(bool shouldLoop)
{
    looping = shouldLoop;
}

//==============================================================================
// Tempo & Time Signature
//==============================================================================

void AudioEngine::setTempo(double bpm)
{
    currentTempo.store(juce::jlimit(20.0, 999.0, bpm));
}

void AudioEngine::getTimeSignature(int& numerator, int& denominator) const
{
    numerator = timeSignatureNumerator;
    denominator = timeSignatureDenominator;
}

void AudioEngine::setTimeSignature(int numerator, int denominator)
{
    timeSignatureNumerator = juce::jlimit(1, 16, numerator);
    timeSignatureDenominator = juce::jlimit(1, 16, denominator);
}

//==============================================================================
// Track Management
//==============================================================================

int AudioEngine::addAudioTrack(const juce::String& name)
{
    const juce::ScopedLock sl(tracksLock);

    auto track = std::make_unique<Track>(Track::Type::Audio, name);
    track->prepare(currentSampleRate, currentBlockSize);

    tracks.push_back(std::move(track));
    return (int)tracks.size() - 1;
}

int AudioEngine::addMIDITrack(const juce::String& name)
{
    const juce::ScopedLock sl(tracksLock);

    auto track = std::make_unique<Track>(Track::Type::MIDI, name);
    track->prepare(currentSampleRate, currentBlockSize);

    tracks.push_back(std::move(track));
    return (int)tracks.size() - 1;
}

void AudioEngine::removeTrack(int trackIndex)
{
    const juce::ScopedLock sl(tracksLock);

    if (juce::isPositiveAndBelow(trackIndex, (int)tracks.size()))
        tracks.erase(tracks.begin() + trackIndex);
}

int AudioEngine::getNumTracks() const
{
    return (int)tracks.size();
}

Track* AudioEngine::getTrack(int index) const
{
    const juce::ScopedLock sl(tracksLock);

    if (juce::isPositiveAndBelow(index, (int)tracks.size()))
        return tracks[index].get();

    return nullptr;
}

//==============================================================================
// Recording
//==============================================================================

void AudioEngine::armTrack(int trackIndex, bool armed)
{
    auto* track = getTrack(trackIndex);
    if (track != nullptr)
        track->setArmed(armed);
}

bool AudioEngine::isTrackArmed(int trackIndex) const
{
    auto* track = getTrack(trackIndex);
    return track != nullptr ? track->isArmed() : false;
}

void AudioEngine::startRecording()
{
    recording.store(true);
    if (!playing.load())
        play();
}

void AudioEngine::stopRecording()
{
    recording.store(false);
}

//==============================================================================
// Master Bus
//==============================================================================

float AudioEngine::getMasterLevelLUFS() const
{
    // Simplified LUFS calculation (full implementation later)
    float peak = juce::jmax(masterPeakLeft.load(), masterPeakRight.load());
    if (peak < 0.00001f)
        return -80.0f;

    return juce::Decibels::gainToDecibels(peak) - 23.0f; // Rough LUFS estimate
}

float AudioEngine::getMasterPeakLevel() const
{
    float peak = juce::jmax(masterPeakLeft.load(), masterPeakRight.load());
    return juce::Decibels::gainToDecibels(peak);
}

void AudioEngine::setMasterVolume(float volume)
{
    masterVolume.store(juce::jlimit(0.0f, 2.0f, volume));
}

//==============================================================================
// Sync Integration
//==============================================================================

void AudioEngine::setSyncEnabled(bool enabled)
{
    syncEnabled = enabled;
}

void AudioEngine::setSyncTempoCallback(std::function<double()> callback)
{
    syncTempoCallback = callback;
}

void AudioEngine::setSyncTransportCallback(std::function<bool()> isPlayingCallback)
{
    syncTransportCallback = isPlayingCallback;
}

//==============================================================================
// Audio Callback (REAL-TIME THREAD!)
//==============================================================================

void AudioEngine::audioDeviceIOCallbackWithContext(
    const float* const* inputChannelData,
    int numInputChannels,
    float* const* outputChannelData,
    int numOutputChannels,
    int numSamples,
    const juce::AudioIODeviceCallbackContext& context)
{
    juce::ignoreUnused(context);

    // CRITICAL: This runs in real-time audio thread!
    // NO allocations, NO locks (except very brief), NO blocking calls!

    // Check for external sync
    if (syncEnabled)
    {
        if (syncTempoCallback)
        {
            double syncTempo = syncTempoCallback();
            if (syncTempo > 0.0)
                currentTempo.store(syncTempo);
        }

        if (syncTransportCallback)
        {
            bool syncPlaying = syncTransportCallback();
            playing.store(syncPlaying);
        }
    }

    // Process audio
    processAudioBlock(inputChannelData, outputChannelData,
                     numInputChannels, numOutputChannels, numSamples);
}

void AudioEngine::processAudioBlock(const float* const* input, float* const* output,
                                   int numInputs, int numOutputs, int numSamples)
{
    // Clear master buffer
    masterBuffer.clear(0, numSamples);

    if (playing.load())
    {
        // Record input to armed tracks
        if (recording.load())
            recordInputToTracks(input, numInputs, numSamples);

        // Mix all tracks to master
        mixTracksToMaster(numSamples);

        // Update playhead position
        updatePlayhead(numSamples);
    }

    // Apply master volume
    float volume = masterVolume.load();
    for (int channel = 0; channel < juce::jmin(2, masterBuffer.getNumChannels()); ++channel)
    {
        masterBuffer.applyGain(channel, 0, numSamples, volume);
    }

    // Copy to output
    for (int channel = 0; channel < numOutputs; ++channel)
    {
        if (channel < masterBuffer.getNumChannels())
        {
            juce::FloatVectorOperations::copy(output[channel],
                                             masterBuffer.getReadPointer(channel),
                                             numSamples);
        }
        else
        {
            juce::FloatVectorOperations::clear(output[channel], numSamples);
        }
    }

    // Update metering
    updateMetering(output, numOutputs, numSamples);
}

void AudioEngine::mixTracksToMaster(int numSamples)
{
    // This will be brief - just check if we can iterate safely
    // In production, use a lock-free structure
    const juce::ScopedTryLock sl(tracksLock);

    if (!sl.isLocked())
        return; // Track list is being modified, skip this block

    for (auto& track : tracks)
    {
        if (track != nullptr && track->isMuted() == false && track->isSoloed() == false)
        {
            track->processBlock(masterBuffer, numSamples);
        }
    }
}

void AudioEngine::recordInputToTracks(const float* const* input, int numInputs, int numSamples)
{
    const juce::ScopedTryLock sl(tracksLock);

    if (!sl.isLocked())
        return;

    for (auto& track : tracks)
    {
        if (track != nullptr && track->isArmed() && track->getType() == Track::Type::Audio)
        {
            // Record input to track
            track->recordInput(input, numInputs, numSamples, playheadPosition.load());
        }
    }
}

void AudioEngine::updatePlayhead(int numSamples)
{
    int64_t newPosition = playheadPosition.load() + numSamples;

    // Handle looping
    if (looping && newPosition >= loopEnd && loopEnd > loopStart)
    {
        newPosition = loopStart + (newPosition - loopEnd);
    }

    playheadPosition.store(newPosition);
}

void AudioEngine::updateMetering(const float* const* output, int numOutputs, int numSamples)
{
    if (numOutputs >= 1)
    {
        float peakL = 0.0f;
        for (int i = 0; i < numSamples; ++i)
            peakL = juce::jmax(peakL, std::abs(output[0][i]));

        masterPeakLeft.store(peakL);
    }

    if (numOutputs >= 2)
    {
        float peakR = 0.0f;
        for (int i = 0; i < numSamples; ++i)
            peakR = juce::jmax(peakR, std::abs(output[1][i]));

        masterPeakRight.store(peakR);
    }
}

//==============================================================================
// Audio Device Lifecycle
//==============================================================================

void AudioEngine::audioDeviceAboutToStart(juce::AudioIODevice* device)
{
    prepare(device->getCurrentSampleRate(), device->getCurrentBufferSizeSamples());
}

void AudioEngine::audioDeviceStopped()
{
    releaseResources();
}
