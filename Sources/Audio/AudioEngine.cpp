#include "AudioEngine.h"
#include "Track.h"

// Forward declaration of bio-reactive parameters from Objective-C++ bridge
// Implementation in EchoelmusicAudioEngineBridge.mm
namespace EchoelmusicBioReactive {
    float getFilterCutoffHz();
    float getReverbSize();
    float getReverbDecay();
    float getBioVolume();
    float getDelayTimeMs();
    float getDelayFeedback();
    float getModulationRateHz();
    float getModulationDepth();
    float getDistortionAmount();
    float getCompressorThresholdDb();
    float getCompressorRatio();
}

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

    bioReactiveFXBuffer.setSize(2, maximumBlockSize);
    bioReactiveFXBuffer.clear();

    // Prepare bio-reactive DSP chain
    bioReactiveDSPSpec.sampleRate = sampleRate;
    bioReactiveDSPSpec.maximumBlockSize = (juce::uint32)maximumBlockSize;
    bioReactiveDSPSpec.numChannels = 2;

    // Filter (State Variable TPT - low/high/bandpass)
    bioReactiveFilter.prepare(bioReactiveDSPSpec);
    bioReactiveFilter.setType(Filter::Type::lowpass);
    bioReactiveFilter.setCutoffFrequency(1000.0f); // Default, will be modulated by HRV
    bioReactiveFilter.setResonance(0.707f); // Butterworth (flat response)

    // Reverb
    juce::dsp::Reverb::Parameters reverbParams;
    reverbParams.roomSize = 0.5f;     // Will be modulated by cardiac coherence
    reverbParams.damping = 0.5f;
    reverbParams.wetLevel = 0.3f;     // 30% wet by default
    reverbParams.dryLevel = 0.7f;     // 70% dry
    reverbParams.width = 1.0f;        // Full stereo width
    reverbParams.freezeMode = 0.0f;
    bioReactiveReverb.setParameters(reverbParams);

    // Delay (pre-allocated to 2 seconds max)
    bioReactiveDelay.prepare(bioReactiveDSPSpec);
    bioReactiveDelay.reset();
    bioReactiveDelay.setMaximumDelayInSamples((int)(sampleRate * 2.0));

    // Reset LFO phase
    lfoPhase = 0.0f;

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

        // Apply bio-reactive DSP (HRV-modulated effects)
        applyBioReactiveDSP(masterBuffer, numSamples);

        // Update playhead position
        updatePlayhead(numSamples);
    }

    // Apply master volume (after bio-reactive DSP)
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
// Bio-Reactive DSP (HRV-Modulated Effects)
//==============================================================================

void AudioEngine::applyBioReactiveDSP(juce::AudioBuffer<float>& buffer, int numSamples)
{
    // Read atomic bio-reactive parameters (lock-free, real-time safe)
    const float filterCutoff = EchoelmusicBioReactive::getFilterCutoffHz();
    const float reverbSize = EchoelmusicBioReactive::getReverbSize();
    const float bioVolume = EchoelmusicBioReactive::getBioVolume();
    const float delayTimeMs = EchoelmusicBioReactive::getDelayTimeMs();
    const float delayFeedback = EchoelmusicBioReactive::getDelayFeedback();
    const float modRateHz = EchoelmusicBioReactive::getModulationRateHz();
    const float modDepth = EchoelmusicBioReactive::getModulationDepth();

    const int numChannels = juce::jmin(buffer.getNumChannels(), 2);
    if (numChannels == 0 || numSamples == 0)
        return;

    // 1. FILTER (HRV modulates cutoff frequency)
    // Update filter parameters (smoothed to avoid zipper noise)
    bioReactiveFilter.setCutoffFrequency(filterCutoff);

    // Process filter
    juce::dsp::AudioBlock<float> block(buffer);
    juce::dsp::ProcessContextReplacing<float> filterContext(block);
    filterContext.getOutputBlock() = filterContext.getOutputBlock().getSubsetChannelBlock(0, numChannels);
    bioReactiveFilter.process(filterContext);

    // 2. REVERB (Cardiac coherence modulates room size)
    juce::dsp::Reverb::Parameters reverbParams = bioReactiveReverb.getParameters();
    reverbParams.roomSize = juce::jlimit(0.0f, 1.0f, reverbSize);
    reverbParams.wetLevel = 0.3f; // 30% wet mix
    reverbParams.dryLevel = 0.7f; // 70% dry mix
    bioReactiveReverb.setParameters(reverbParams);

    // Process reverb
    bioReactiveReverb.processStereo(buffer.getWritePointer(0),
                                    numChannels > 1 ? buffer.getWritePointer(1) : buffer.getWritePointer(0),
                                    numSamples);

    // 3. DELAY (Heart rate interval modulates delay time)
    const int delaySamples = juce::jlimit(1, (int)(currentSampleRate * 2.0),
                                          (int)(delayTimeMs * currentSampleRate / 1000.0f));
    bioReactiveDelay.setDelay((float)delaySamples);

    // Process delay with feedback (manual implementation for control)
    for (int channel = 0; channel < numChannels; ++channel)
    {
        auto* channelData = buffer.getWritePointer(channel);

        for (int sample = 0; sample < numSamples; ++sample)
        {
            // Read delayed sample
            float delayedSample = bioReactiveDelay.popSample(channel);

            // Mix with current sample (50% wet)
            float output = channelData[sample] * 0.7f + delayedSample * 0.3f;

            // Push to delay line with feedback
            bioReactiveDelay.pushSample(channel, channelData[sample] + delayedSample * delayFeedback);

            channelData[sample] = output;
        }
    }

    // 4. LFO MODULATION (Breathing rate modulates amplitude/filter)
    // Update LFO phase
    const float lfoIncrement = (modRateHz / (float)currentSampleRate) * juce::MathConstants<float>::twoPi;

    for (int sample = 0; sample < numSamples; ++sample)
    {
        // Calculate LFO value (sine wave, 0-1 range)
        float lfoValue = (std::sin(lfoPhase) + 1.0f) * 0.5f;

        // Apply modulation to amplitude (gentle breathing effect)
        float modulation = 1.0f - (modDepth * 0.2f * (1.0f - lfoValue));

        for (int channel = 0; channel < numChannels; ++channel)
        {
            auto* channelData = buffer.getWritePointer(channel);
            channelData[sample] *= modulation;
        }

        // Advance LFO phase
        lfoPhase += lfoIncrement;
        if (lfoPhase >= juce::MathConstants<float>::twoPi)
            lfoPhase -= juce::MathConstants<float>::twoPi;
    }

    // 5. BIO VOLUME (Final gain stage from HRV)
    buffer.applyGain(bioVolume);
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
