/*
  ==============================================================================

    EchoelmusicAudioEngine.cpp
    Created: 2025
    Author:  Echoelmusic Team

  ==============================================================================
*/

#include "EchoelmusicAudioEngine.h"

//==============================================================================
EchoelmusicAudioEngine::EchoelmusicAudioEngine()
{
    // Initialize with 16 tracks
    for (int i = 0; i < 16; ++i)
    {
        addTrack ("Track " + juce::String (i + 1));
    }

    DBG ("Echoelmusic Audio Engine initialized");
    DBG ("Target latency: <2ms @ 48kHz (128 samples)");
}

EchoelmusicAudioEngine::~EchoelmusicAudioEngine()
{
}

//==============================================================================
void EchoelmusicAudioEngine::prepareToPlay (double sampleRate, int samplesPerBlock)
{
    currentSampleRate = sampleRate;
    bufferSize = samplesPerBlock;

    // Calculate actual latency
    currentLatency = (static_cast<double>(samplesPerBlock) / sampleRate) * 1000.0;  // in ms

    DBG ("Audio engine prepared:");
    DBG ("  Sample rate: " + juce::String (sampleRate) + " Hz");
    DBG ("  Buffer size: " + juce::String (samplesPerBlock) + " samples");
    DBG ("  Latency: " + juce::String (currentLatency.load(), 2) + " ms");

    // Prepare all track processors
    for (auto& processor : trackProcessors)
    {
        processor->prepare (sampleRate, samplesPerBlock);
    }

    // Prepare master chain
    juce::dsp::ProcessSpec spec;
    spec.sampleRate = sampleRate;
    spec.maximumBlockSize = static_cast<juce::uint32>(samplesPerBlock);
    spec.numChannels = 2;  // Stereo

    masterGain.prepare (spec);
    masterGain.setGainDecibels (0.0f);

    masterLimiter.prepare (spec);
    masterLimiter.setThreshold (-0.1f);  // -0.1 dB
    masterLimiter.setRelease (50.0f);    // 50ms release

    // Allocate master buffer
    masterBuffer.setSize (2, samplesPerBlock);
}

void EchoelmusicAudioEngine::releaseResources()
{
    DBG ("Audio engine resources released");
}

//==============================================================================
void EchoelmusicAudioEngine::processBlock (juce::AudioBuffer<float>& buffer,
                                           juce::MidiBuffer& midiMessages)
{
    juce::ScopedNoDenormals noDenormals;

    auto totalNumInputChannels  = getTotalNumInputChannels();
    auto totalNumOutputChannels = getTotalNumOutputChannels();

    // Start performance measurement
    auto startTime = juce::Time::getHighResolutionTicks();

    // Clear output buffer
    for (auto i = totalNumInputChannels; i < totalNumOutputChannels; ++i)
        buffer.clear (i, 0, buffer.getNumSamples());

    // Process all tracks in parallel
    processTracksParallel (buffer);

    // Mix all tracks with SIMD acceleration
    masterBuffer.clear();
    mixTracksSimd (masterBuffer);

    // Apply master effects
    auto block = juce::dsp::AudioBlock<float> (masterBuffer);
    auto context = juce::dsp::ProcessContextReplacing<float> (block);

    masterGain.process (context);
    masterLimiter.process (context);

    // Copy to output
    for (int channel = 0; channel < juce::jmin (2, totalNumOutputChannels); ++channel)
    {
        buffer.copyFrom (channel, 0, masterBuffer, channel, 0, buffer.getNumSamples());
    }

    // Measure performance
    auto endTime = juce::Time::getHighResolutionTicks();
    auto elapsedSeconds = juce::Time::highResolutionTicksToSeconds (endTime - startTime);
    auto bufferDuration = buffer.getNumSamples() / currentSampleRate;

    cpuUsage = (elapsedSeconds / bufferDuration) * 100.0;

    // Warn if CPU usage too high
    if (cpuUsage.load() > 80.0)
    {
        DBG ("⚠️ High CPU usage: " + juce::String (cpuUsage.load(), 1) + "%");
    }
}

//==============================================================================
void EchoelmusicAudioEngine::processTracksParallel (juce::AudioBuffer<float>& buffer)
{
    // Process each track on a separate thread
    for (size_t i = 0; i < tracks.size(); ++i)
    {
        threadPool.addJob ([this, i, &buffer]()
        {
            auto& track = *tracks[i];
            auto& processor = *trackProcessors[i];

            if (!track.muted.load())
            {
                // Create temporary buffer for this track
                juce::AudioBuffer<float> trackBuffer (2, buffer.getNumSamples());
                trackBuffer.clear();

                // Read from ring buffer (if available)
                // In real implementation: read from audio file or live input

                // Apply track processing
                processor.process (trackBuffer);

                // Apply volume and pan
                float volume = track.volume.load();
                float pan = track.pan.load();

                float leftGain = volume * (pan <= 0.0f ? 1.0f : 1.0f - pan);
                float rightGain = volume * (pan >= 0.0f ? 1.0f : 1.0f + pan);

                trackBuffer.applyGain (0, 0, trackBuffer.getNumSamples(), leftGain);
                trackBuffer.applyGain (1, 0, trackBuffer.getNumSamples(), rightGain);

                // Copy to track buffer (for mixing)
                track.buffer = trackBuffer;
            }
        }, false);
    }

    // Wait for all tracks to finish processing
    while (threadPool.getNumJobs() > 0)
    {
        juce::Thread::yield();
    }
}

//==============================================================================
void EchoelmusicAudioEngine::mixTracksSimd (juce::AudioBuffer<float>& outputBuffer)
{
    const int numSamples = outputBuffer.getNumSamples();

    // Check for solo
    bool anySoloed = false;
    for (const auto& track : tracks)
    {
        if (track->soloed.load())
        {
            anySoloed = true;
            break;
        }
    }

    // Mix all tracks
    for (const auto& track : tracks)
    {
        if (track->muted.load())
            continue;

        if (anySoloed && !track->soloed.load())
            continue;

        // SIMD-accelerated mixing
        for (int channel = 0; channel < 2; ++channel)
        {
            auto* src = track->buffer.getReadPointer (channel);
            auto* dst = outputBuffer.getWritePointer (channel);

#if JUCE_INTEL
            // Intel SSE/AVX
            for (int i = 0; i < numSamples; i += 8)
            {
                __m256 srcVec = _mm256_loadu_ps (&src[i]);
                __m256 dstVec = _mm256_loadu_ps (&dst[i]);
                dstVec = _mm256_add_ps (dstVec, srcVec);
                _mm256_storeu_ps (&dst[i], dstVec);
            }
#elif JUCE_ARM
            // ARM NEON
            for (int i = 0; i < numSamples; i += 4)
            {
                float32x4_t srcVec = vld1q_f32 (&src[i]);
                float32x4_t dstVec = vld1q_f32 (&dst[i]);
                dstVec = vaddq_f32 (dstVec, srcVec);
                vst1q_f32 (&dst[i], dstVec);
            }
#else
            // Fallback: standard addition
            juce::FloatVectorOperations::add (dst, src, numSamples);
#endif
        }
    }
}

//==============================================================================
int EchoelmusicAudioEngine::addTrack (const juce::String& name)
{
    auto track = std::make_unique<AudioTrack>();
    track->name = name;
    track->buffer.setSize (2, bufferSize);
    track->buffer.clear();

    auto processor = std::make_unique<TrackProcessor>();
    processor->prepare (currentSampleRate, bufferSize);

    tracks.push_back (std::move (track));
    trackProcessors.push_back (std::move (processor));

    int index = static_cast<int>(tracks.size()) - 1;

    DBG ("Track added: " + name + " (index: " + juce::String (index) + ")");

    return index;
}

void EchoelmusicAudioEngine::removeTrack (int trackIndex)
{
    if (trackIndex >= 0 && trackIndex < static_cast<int>(tracks.size()))
    {
        juce::String trackName = tracks[trackIndex]->name;
        tracks.erase (tracks.begin() + trackIndex);
        trackProcessors.erase (trackProcessors.begin() + trackIndex);

        DBG ("Track removed: " + trackName);
    }
}

//==============================================================================
juce::AudioProcessorEditor* EchoelmusicAudioEngine::createEditor()
{
    // Return generic editor for now
    // In production: custom UI
    return new juce::GenericAudioProcessorEditor (*this);
}

//==============================================================================
void EchoelmusicAudioEngine::getStateInformation (juce::MemoryBlock& destData)
{
    // Serialize state (tracks, parameters, etc.)
    juce::XmlElement root ("ECHOELMUSIC");
    root.setAttribute ("version", "1.0.0");

    // Save tracks
    auto* tracksXml = root.createNewChildElement ("TRACKS");
    tracksXml->setAttribute ("count", static_cast<int>(tracks.size()));

    for (size_t i = 0; i < tracks.size(); ++i)
    {
        auto& track = *tracks[i];
        auto* trackXml = tracksXml->createNewChildElement ("TRACK");
        trackXml->setAttribute ("name", track.name);
        trackXml->setAttribute ("volume", track.volume.load());
        trackXml->setAttribute ("pan", track.pan.load());
        trackXml->setAttribute ("muted", track.muted.load());
        trackXml->setAttribute ("soloed", track.soloed.load());
    }

    copyXmlToBinary (root, destData);
}

void EchoelmusicAudioEngine::setStateInformation (const void* data, int sizeInBytes)
{
    // Deserialize state
    std::unique_ptr<juce::XmlElement> root = getXmlFromBinary (data, sizeInBytes);

    if (root != nullptr && root->hasTagName ("ECHOELMUSIC"))
    {
        auto* tracksXml = root->getChildByName ("TRACKS");
        if (tracksXml != nullptr)
        {
            // Restore tracks
            for (auto* trackXml : tracksXml->getChildIterator())
            {
                if (trackXml->hasTagName ("TRACK"))
                {
                    juce::String name = trackXml->getStringAttribute ("name");
                    int index = addTrack (name);

                    if (index >= 0 && index < static_cast<int>(tracks.size()))
                    {
                        auto& track = *tracks[index];
                        track.volume = static_cast<float>(trackXml->getDoubleAttribute ("volume", 1.0));
                        track.pan = static_cast<float>(trackXml->getDoubleAttribute ("pan", 0.0));
                        track.muted = trackXml->getBoolAttribute ("muted", false);
                        track.soloed = trackXml->getBoolAttribute ("soloed", false);
                    }
                }
            }
        }

        DBG ("State restored successfully");
    }
}
