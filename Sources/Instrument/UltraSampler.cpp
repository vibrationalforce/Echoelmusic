#include "UltraSampler.h"
#include <algorithm>
#include <random>

//==============================================================================
// Constructor
//==============================================================================

UltraSampler::UltraSampler()
{
    // Initialize envelopes with musical defaults
    envelopes[0] = { 0, 5, 0, 100, 0.7f, 200, 0, 0, 0, 0, 1.0f };    // Amp
    envelopes[1] = { 0, 10, 0, 300, 0.3f, 500, 0, -0.3f, 0, 0, 0.5f }; // Filter
    envelopes[2] = { 0, 50, 0, 500, 0.5f, 1000, 0, 0, 0, 0, 0.3f };    // Mod
    envelopes[3] = { 0, 100, 0, 1000, 0.0f, 2000, 0, 0.5f, 0, 0, 0.2f }; // Aux

    // Initialize LFOs
    lfos[0] = { LFO::Shape::Sine, 1.0f, 0.5f, 0.0f, 0.0f, false, 0.25f, true, false };
    lfos[1] = { LFO::Shape::Triangle, 2.0f, 0.3f, 0.25f, 0.0f, false, 0.25f, true, false };
    lfos[2] = { LFO::Shape::Saw, 0.5f, 0.2f, 0.5f, 0.0f, false, 0.25f, true, false };
    lfos[3] = { LFO::Shape::Random, 4.0f, 0.1f, 0.0f, 100.0f, false, 0.25f, true, false };

    // Build sinc interpolation table
    buildSincTable();

    // Reset all voices
    for (auto& voice : voices) {
        voice.active = false;
    }
}

//==============================================================================
// Initialization
//==============================================================================

void UltraSampler::prepare(double newSampleRate, int newBlockSize)
{
    sampleRate = newSampleRate;
    blockSize = newBlockSize;
    reset();
}

void UltraSampler::reset()
{
    for (auto& voice : voices) {
        voice.active = false;
        voice.historyL.fill(0.0f);
        voice.historyR.fill(0.0f);
        voice.historyIndex = 0;

        for (auto& env : voice.envStates) {
            env.stage = Voice::EnvState::Stage::Off;
            env.level = 0.0f;
        }

        for (auto& grain : voice.grains) {
            grain.active = false;
        }
    }
}

//==============================================================================
// Sample Management
//==============================================================================

bool UltraSampler::loadSample(int zoneIndex, const juce::File& file)
{
    if (zoneIndex < 0 || zoneIndex >= kMaxZones) return false;

    juce::AudioFormatManager formatManager;
    formatManager.registerBasicFormats();

    std::unique_ptr<juce::AudioFormatReader> reader(
        formatManager.createReaderFor(file));

    if (!reader) return false;

    auto sample = std::make_shared<SampleData>();
    sample->sourceSampleRate = reader->sampleRate;
    sample->name = file.getFileNameWithoutExtension().toStdString();
    sample->filePath = file.getFullPathName().toStdString();

    int numSamples = static_cast<int>(reader->lengthInSamples);
    sample->left.resize(numSamples);

    juce::AudioBuffer<float> buffer(reader->numChannels, numSamples);
    reader->read(&buffer, 0, numSamples, 0, true, true);

    // Copy to sample data
    std::copy(buffer.getReadPointer(0), buffer.getReadPointer(0) + numSamples,
              sample->left.begin());

    if (reader->numChannels > 1) {
        sample->right.resize(numSamples);
        std::copy(buffer.getReadPointer(1), buffer.getReadPointer(1) + numSamples,
                  sample->right.begin());
    } else {
        sample->right = sample->left;  // Mono to stereo
    }

    // Setup zone
    auto& zone = zones[zoneIndex];
    zone.enabled = true;
    zone.name = file.getFileNameWithoutExtension();
    zone.numVelocityLayers = 1;
    zone.velocityLayers[0].sample = sample;
    zone.velocityLayers[0].velocityLow = 0;
    zone.velocityLayers[0].velocityHigh = 127;

    return true;
}

bool UltraSampler::loadSample(int zoneIndex, const juce::AudioBuffer<float>& buffer,
                              double sourceSampleRate, int rootNote)
{
    if (zoneIndex < 0 || zoneIndex >= kMaxZones) return false;

    auto sample = std::make_shared<SampleData>();
    sample->sourceSampleRate = sourceSampleRate;
    sample->rootNote = rootNote;

    int numSamples = buffer.getNumSamples();
    sample->left.resize(numSamples);

    std::copy(buffer.getReadPointer(0), buffer.getReadPointer(0) + numSamples,
              sample->left.begin());

    if (buffer.getNumChannels() > 1) {
        sample->right.resize(numSamples);
        std::copy(buffer.getReadPointer(1), buffer.getReadPointer(1) + numSamples,
                  sample->right.begin());
    } else {
        sample->right = sample->left;
    }

    auto& zone = zones[zoneIndex];
    zone.enabled = true;
    zone.rootKey = rootNote;
    zone.numVelocityLayers = 1;
    zone.velocityLayers[0].sample = sample;

    return true;
}

bool UltraSampler::addVelocityLayer(int zoneIndex, const juce::File& file,
                                    int velocityLow, int velocityHigh)
{
    if (zoneIndex < 0 || zoneIndex >= kMaxZones) return false;
    auto& zone = zones[zoneIndex];
    if (zone.numVelocityLayers >= kMaxVelocityLayers) return false;

    // Load sample
    juce::AudioFormatManager formatManager;
    formatManager.registerBasicFormats();
    std::unique_ptr<juce::AudioFormatReader> reader(
        formatManager.createReaderFor(file));
    if (!reader) return false;

    auto sample = std::make_shared<SampleData>();
    sample->sourceSampleRate = reader->sampleRate;

    int numSamples = static_cast<int>(reader->lengthInSamples);
    sample->left.resize(numSamples);

    juce::AudioBuffer<float> buffer(reader->numChannels, numSamples);
    reader->read(&buffer, 0, numSamples, 0, true, true);

    std::copy(buffer.getReadPointer(0), buffer.getReadPointer(0) + numSamples,
              sample->left.begin());
    if (reader->numChannels > 1) {
        sample->right.resize(numSamples);
        std::copy(buffer.getReadPointer(1), buffer.getReadPointer(1) + numSamples,
                  sample->right.begin());
    } else {
        sample->right = sample->left;
    }

    // Add layer
    auto& layer = zone.velocityLayers[zone.numVelocityLayers];
    layer.sample = sample;
    layer.velocityLow = velocityLow;
    layer.velocityHigh = velocityHigh;
    zone.numVelocityLayers++;

    return true;
}

void UltraSampler::setZoneKeyRange(int zoneIndex, int keyLow, int keyHigh, int rootKey)
{
    if (zoneIndex < 0 || zoneIndex >= kMaxZones) return;
    auto& zone = zones[zoneIndex];
    zone.keyLow = keyLow;
    zone.keyHigh = keyHigh;
    zone.rootKey = rootKey;
}

void UltraSampler::clearZone(int zoneIndex)
{
    if (zoneIndex < 0 || zoneIndex >= kMaxZones) return;
    zones[zoneIndex] = Zone();
}

void UltraSampler::clearAll()
{
    for (auto& zone : zones) {
        zone = Zone();
    }
    reset();
}

//==============================================================================
// Playback Control
//==============================================================================

void UltraSampler::noteOn(int noteNumber, float velocity, int /*channel*/)
{
    // Find matching zone
    int zoneIndex = findZoneForNote(noteNumber, velocity);
    if (zoneIndex < 0) return;

    auto& zone = zones[zoneIndex];

    // Find velocity layer
    int layerIndex = selectVelocityLayer(zone, velocity);
    if (layerIndex < 0) return;

    // Allocate voice
    Voice* voice = allocateVoice(noteNumber);
    if (!voice) return;

    // Initialize voice
    voice->active = true;
    voice->noteNumber = noteNumber;
    voice->velocity = velocity;
    voice->zoneIndex = zoneIndex;
    voice->layerIndex = layerIndex;
    voice->releasing = false;

    // Calculate playback speed based on pitch
    auto& layer = zone.velocityLayers[layerIndex];
    if (layer.sample) {
        float pitchRatio = std::pow(2.0f, (noteNumber - zone.rootKey + zone.pitchOffset) / 12.0f +
                                         zone.fineTune / 1200.0f);
        double sampleRateRatio = layer.sample->sourceSampleRate / sampleRate;
        voice->playbackSpeed = pitchRatio * sampleRateRatio;
    }

    // Set playback position
    voice->playbackPos = zone.sampleStart * (layer.sample ? layer.sample->left.size() : 0);
    voice->loopingForward = true;

    // Reset envelopes
    for (int i = 0; i < 4; ++i) {
        voice->envStates[i].stage = Voice::EnvState::Stage::Delay;
        voice->envStates[i].level = 0.0f;
        voice->envStates[i].stageTime = 0.0f;
    }

    // Reset LFOs if key-synced
    for (int i = 0; i < 4; ++i) {
        if (lfos[i].keySync) {
            voice->lfoPhases[i] = lfos[i].phase;
            voice->lfoFadeLevel[i] = 0.0f;
        }
    }

    // Reset filter states
    voice->filter1L = voice->filter1R = ZDFFilterState();
    voice->filter2L = voice->filter2R = ZDFFilterState();

    // Reset granular
    voice->grainSpawnAccum = 0.0f;
    for (auto& grain : voice->grains) {
        grain.active = false;
    }

    // Clear interpolation history
    voice->historyL.fill(0.0f);
    voice->historyR.fill(0.0f);
    voice->historyIndex = 0;
}

void UltraSampler::noteOff(int noteNumber, float /*velocity*/, int /*channel*/)
{
    for (auto& voice : voices) {
        if (voice.active && voice.noteNumber == noteNumber && !voice.releasing) {
            voice.releasing = true;

            // Move all envelopes to release stage
            for (auto& env : voice.envStates) {
                if (env.stage != Voice::EnvState::Stage::Off) {
                    env.stage = Voice::EnvState::Stage::Release;
                    env.stageTime = 0.0f;
                }
            }
        }
    }
}

void UltraSampler::allNotesOff()
{
    for (auto& voice : voices) {
        if (voice.active) {
            voice.releasing = true;
            for (auto& env : voice.envStates) {
                env.stage = Voice::EnvState::Stage::Release;
                env.stageTime = 0.0f;
            }
        }
    }
}

void UltraSampler::setPitchBend(float semitones)
{
    globalPitchBend = semitones;
    for (auto& voice : voices) {
        if (voice.active) {
            voice.pitchBend = semitones;
        }
    }
}

void UltraSampler::setModWheel(float value)
{
    globalModWheel = value;
    for (auto& voice : voices) {
        if (voice.active) {
            voice.modWheel = value;
        }
    }
}

void UltraSampler::setAftertouch(float value)
{
    for (auto& voice : voices) {
        if (voice.active) {
            voice.aftertouch = value;
        }
    }
}

//==============================================================================
// Voice Management
//==============================================================================

UltraSampler::Voice* UltraSampler::allocateVoice(int noteNumber)
{
    // Try to find an inactive voice
    for (auto& voice : voices) {
        if (!voice.active) {
            return &voice;
        }
    }

    // Steal oldest releasing voice
    Voice* oldestReleasing = nullptr;
    float oldestLevel = 2.0f;
    for (auto& voice : voices) {
        if (voice.releasing && voice.envStates[0].level < oldestLevel) {
            oldestReleasing = &voice;
            oldestLevel = voice.envStates[0].level;
        }
    }
    if (oldestReleasing) return oldestReleasing;

    // Steal same-note voice
    for (auto& voice : voices) {
        if (voice.noteNumber == noteNumber) {
            return &voice;
        }
    }

    // Steal oldest voice
    return &voices[0];  // Simple fallback
}

int UltraSampler::findZoneForNote(int noteNumber, float velocity)
{
    int vel127 = static_cast<int>(velocity * 127.0f);

    for (int i = 0; i < kMaxZones; ++i) {
        auto& zone = zones[i];
        if (!zone.enabled) continue;

        if (noteNumber >= zone.keyLow && noteNumber <= zone.keyHigh) {
            // Check if any velocity layer matches
            for (int j = 0; j < zone.numVelocityLayers; ++j) {
                auto& layer = zone.velocityLayers[j];
                if (vel127 >= layer.velocityLow && vel127 <= layer.velocityHigh) {
                    return i;
                }
            }
        }
    }
    return -1;
}

int UltraSampler::selectVelocityLayer(const Zone& zone, float velocity)
{
    int vel127 = static_cast<int>(velocity * 127.0f);

    // Find best matching layer
    for (int i = 0; i < zone.numVelocityLayers; ++i) {
        auto& layer = zone.velocityLayers[i];
        if (vel127 >= layer.velocityLow && vel127 <= layer.velocityHigh) {
            // Handle round-robin
            if (zone.numRoundRobin > 0 && layer.roundRobinGroup > 0) {
                // TODO: Implement round-robin cycling
            }
            return i;
        }
    }

    // Fallback to first layer
    return zone.numVelocityLayers > 0 ? 0 : -1;
}

//==============================================================================
// Processing
//==============================================================================

void UltraSampler::processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midiMessages)
{
    // Process MIDI
    for (const auto metadata : midiMessages) {
        const auto msg = metadata.getMessage();

        if (msg.isNoteOn()) {
            noteOn(msg.getNoteNumber(), msg.getVelocity() / 127.0f, msg.getChannel());
        } else if (msg.isNoteOff()) {
            noteOff(msg.getNoteNumber(), msg.getVelocity() / 127.0f, msg.getChannel());
        } else if (msg.isPitchWheel()) {
            float bend = (msg.getPitchWheelValue() - 8192) / 8192.0f * 2.0f;  // ±2 semitones
            setPitchBend(bend);
        } else if (msg.isControllerOfType(1)) {
            setModWheel(msg.getControllerValue() / 127.0f);
        } else if (msg.isChannelPressure()) {
            setAftertouch(msg.getChannelPressureValue() / 127.0f);
        }
    }

    // Clear output buffer
    buffer.clear();

    int numSamples = buffer.getNumSamples();
    float* leftOut = buffer.getWritePointer(0);
    float* rightOut = buffer.getNumChannels() > 1 ? buffer.getWritePointer(1) : leftOut;

    // Process all active voices
    for (auto& voice : voices) {
        if (!voice.active) continue;

        if (granularParams.enabled) {
            processGranularVoice(voice, leftOut, rightOut, numSamples);
        } else {
            processVoice(voice, leftOut, rightOut, numSamples);
        }
    }

    // Apply master volume
    buffer.applyGain(masterVolume);
}

void UltraSampler::processVoice(Voice& voice, float* leftOut, float* rightOut, int numSamples)
{
    if (voice.zoneIndex < 0 || voice.zoneIndex >= kMaxZones) {
        voice.active = false;
        return;
    }

    auto& zone = zones[voice.zoneIndex];
    if (voice.layerIndex < 0 || voice.layerIndex >= zone.numVelocityLayers) {
        voice.active = false;
        return;
    }

    auto& layer = zone.velocityLayers[voice.layerIndex];
    if (!layer.sample || layer.sample->left.empty()) {
        voice.active = false;
        return;
    }

    auto& sample = *layer.sample;
    int sampleLength = static_cast<int>(sample.left.size());

    // Calculate end position
    double endPos = zone.sampleEnd * sampleLength;

    for (int i = 0; i < numSamples; ++i) {
        // Process envelopes
        float ampEnv = processEnvelope(voice, 0);
        float filterEnv = processEnvelope(voice, 1);

        // Check if voice should end
        if (voice.envStates[0].stage == Voice::EnvState::Stage::Off) {
            voice.active = false;
            return;
        }

        // Process LFOs
        float lfo1 = processLFO(voice, 0);
        float lfo2 = processLFO(voice, 1);

        // Apply modulation to playback speed (pitch)
        float pitchMod = voice.pitchBend;
        pitchMod += lfo1 * 0.5f;  // LFO1 to pitch

        if (bioReactiveEnabled) {
            pitchMod += (bioCoherence - 0.5f) * 0.1f;  // Bio-modulation
        }

        double currentSpeed = voice.playbackSpeed * std::pow(2.0f, pitchMod / 12.0f);

        // Read sample with interpolation
        float sampleL = readSample(sample, voice.playbackPos, 0, voice);
        float sampleR = readSample(sample, voice.playbackPos, 1, voice);

        // Apply filter
        float cutoffMod = filter1Cutoff;
        cutoffMod += filterEnv * 4000.0f;  // Envelope to cutoff
        cutoffMod += lfo2 * 1000.0f;       // LFO2 to filter
        cutoffMod = juce::jlimit(20.0f, 20000.0f, cutoffMod);

        if (filter1Type != FilterType::Off) {
            sampleL = processFilter(sampleL, filter1Type, cutoffMod, filter1Resonance,
                                   voice.filter1L, true);
            sampleR = processFilter(sampleR, filter1Type, cutoffMod, filter1Resonance,
                                   voice.filter1R, false);
        }

        // Apply velocity and envelope
        float gain = voice.velocity * ampEnv * zone.volume;

        // Apply pan
        float panL = std::sqrt(1.0f - zone.pan);
        float panR = std::sqrt(zone.pan);

        // Output
        leftOut[i] += sampleL * gain * panL;
        rightOut[i] += sampleR * gain * panR;

        // Advance playback position
        if (zone.loopMode == Zone::LoopMode::Off || !sample.loopEnabled) {
            voice.playbackPos += currentSpeed;
            if (voice.playbackPos >= endPos) {
                voice.active = false;
                return;
            }
        } else {
            // Handle looping
            voice.playbackPos += voice.loopingForward ? currentSpeed : -currentSpeed;

            double loopStart = sample.loopStart;
            double loopEnd = sample.loopEnd > 0 ? sample.loopEnd : sampleLength;

            switch (zone.loopMode) {
                case Zone::LoopMode::Forward:
                    if (voice.playbackPos >= loopEnd) {
                        voice.playbackPos = loopStart + std::fmod(voice.playbackPos - loopEnd,
                                                                  loopEnd - loopStart);
                    }
                    break;

                case Zone::LoopMode::Backward:
                    voice.loopingForward = false;
                    if (voice.playbackPos <= loopStart) {
                        voice.playbackPos = loopEnd - std::fmod(loopStart - voice.playbackPos,
                                                               loopEnd - loopStart);
                    }
                    break;

                case Zone::LoopMode::PingPong:
                    if (voice.loopingForward && voice.playbackPos >= loopEnd) {
                        voice.playbackPos = loopEnd - (voice.playbackPos - loopEnd);
                        voice.loopingForward = false;
                    } else if (!voice.loopingForward && voice.playbackPos <= loopStart) {
                        voice.playbackPos = loopStart + (loopStart - voice.playbackPos);
                        voice.loopingForward = true;
                    }
                    break;

                default:
                    break;
            }
        }
    }
}

//==============================================================================
// Granular Processing
//==============================================================================

void UltraSampler::processGranularVoice(Voice& voice, float* leftOut, float* rightOut, int numSamples)
{
    if (voice.zoneIndex < 0) {
        voice.active = false;
        return;
    }

    auto& zone = zones[voice.zoneIndex];
    if (voice.layerIndex < 0 || voice.layerIndex >= zone.numVelocityLayers) {
        voice.active = false;
        return;
    }

    auto& layer = zone.velocityLayers[voice.layerIndex];
    if (!layer.sample) {
        voice.active = false;
        return;
    }

    auto& sample = *layer.sample;

    // Process envelopes for overall amplitude
    float ampEnv = processEnvelope(voice, 0);
    if (voice.envStates[0].stage == Voice::EnvState::Stage::Off) {
        voice.active = false;
        return;
    }

    // Grain spawn rate
    float grainInterval = 1.0f / granularParams.grainDensity;
    float samplesPerGrain = static_cast<float>(sampleRate) * grainInterval;

    static std::random_device rd;
    static std::mt19937 gen(rd());
    std::uniform_real_distribution<float> randPos(-granularParams.grainPositionRand,
                                                   granularParams.grainPositionRand);
    std::uniform_real_distribution<float> randPitch(-granularParams.grainPitchRand,
                                                     granularParams.grainPitchRand);
    std::uniform_real_distribution<float> randPan(0.5f - granularParams.grainPanSpread * 0.5f,
                                                  0.5f + granularParams.grainPanSpread * 0.5f);

    for (int i = 0; i < numSamples; ++i) {
        // Check if we need to spawn a new grain
        voice.grainSpawnAccum += 1.0f;
        if (voice.grainSpawnAccum >= samplesPerGrain) {
            voice.grainSpawnAccum -= samplesPerGrain;

            // Find inactive grain slot
            for (auto& grain : voice.grains) {
                if (!grain.active) {
                    grain.active = true;

                    // Set grain position
                    float basePos = granularParams.grainPosition;
                    basePos += randPos(gen);
                    basePos = juce::jlimit(0.0f, 1.0f, basePos);
                    grain.position = basePos * sample.left.size();

                    // Set grain pitch
                    float pitchOffset = randPitch(gen);
                    grain.speed = voice.playbackSpeed * std::pow(2.0f, pitchOffset / 12.0f);

                    // Set grain pan
                    grain.pan = randPan(gen);

                    // Reset window position
                    grain.windowPos = 0.0f;

                    grain.gain = 1.0f;
                    break;
                }
            }
        }

        // Process all active grains
        float outL = 0.0f;
        float outR = 0.0f;

        float grainSizeSamples = granularParams.grainSize * 0.001f * static_cast<float>(sampleRate);

        for (auto& grain : voice.grains) {
            if (!grain.active) continue;

            float grainSample = processGrain(grain, sample, 0);
            float grainSampleR = processGrain(grain, sample, 1);

            // Apply window
            float window = grainWindow(grain.windowPos, granularParams.windowType);

            // Apply pan
            float panL = std::sqrt(1.0f - grain.pan);
            float panR = std::sqrt(grain.pan);

            outL += grainSample * window * grain.gain * panL;
            outR += grainSampleR * window * grain.gain * panR;

            // Advance grain
            grain.position += grain.speed;
            grain.windowPos += 1.0f / grainSizeSamples;

            // Check if grain is finished
            if (grain.windowPos >= 1.0f) {
                grain.active = false;
            }
        }

        // Apply voice envelope and output
        float gain = voice.velocity * ampEnv * zone.volume;
        leftOut[i] += outL * gain;
        rightOut[i] += outR * gain;
    }

    // Advance base grain position slowly for evolution
    if (!voice.releasing) {
        granularParams.grainPosition += 0.00001f;
        if (granularParams.grainPosition > 1.0f) {
            granularParams.grainPosition = 0.0f;
        }
    }
}

float UltraSampler::processGrain(Voice::Grain& grain, const SampleData& sample, int channel)
{
    const auto& data = (channel == 0) ? sample.left : sample.right;
    if (data.empty()) return 0.0f;

    int pos = static_cast<int>(grain.position);
    if (pos < 0 || pos >= static_cast<int>(data.size())) return 0.0f;

    // Simple linear interpolation for grains
    int pos2 = pos + 1;
    if (pos2 >= static_cast<int>(data.size())) pos2 = pos;

    float frac = static_cast<float>(grain.position - pos);
    return data[pos] + frac * (data[pos2] - data[pos]);
}

//==============================================================================
// Sample Reading with Interpolation
//==============================================================================

float UltraSampler::readSample(const SampleData& sample, double pos, int channel, Voice& voice)
{
    InterpolationMode mode = interpMode;

    // Auto mode: select based on pitch ratio
    if (mode == InterpolationMode::Auto) {
        double pitchRatio = std::abs(voice.playbackSpeed);
        if (pitchRatio > 2.0 || pitchRatio < 0.5) {
            mode = InterpolationMode::Sinc64;
        } else if (pitchRatio > 1.5 || pitchRatio < 0.67) {
            mode = InterpolationMode::Sinc8;
        } else {
            mode = InterpolationMode::Hermite;
        }
    }

    switch (mode) {
        case InterpolationMode::Linear:
            return readSampleLinear(sample, pos, channel);
        case InterpolationMode::Hermite:
            return readSampleHermite(sample, pos, channel);
        case InterpolationMode::Sinc8:
        case InterpolationMode::Sinc64:
            return readSampleSinc(sample, pos, channel, voice);
        default:
            return readSampleHermite(sample, pos, channel);
    }
}

float UltraSampler::readSampleSinc(const SampleData& sample, double pos, int channel, Voice& voice)
{
    const auto& data = (channel == 0) ? sample.left : sample.right;
    int size = static_cast<int>(data.size());
    if (size == 0) return 0.0f;

    int intPos = static_cast<int>(pos);
    float frac = static_cast<float>(pos - intPos);

    // Use precomputed sinc table
    int tableIndex = static_cast<int>(frac * 256) & 255;
    auto& sincCoeffs = sincTable[tableIndex];

    float output = 0.0f;
    int halfTaps = kSincTaps / 2;

    for (int t = 0; t < kSincTaps; ++t) {
        int sampleIndex = intPos + t - halfTaps;

        // Handle boundaries
        if (sampleIndex < 0) sampleIndex = 0;
        if (sampleIndex >= size) sampleIndex = size - 1;

        output += data[sampleIndex] * sincCoeffs[t];
    }

    return output;
}

//==============================================================================
// Envelope Processing
//==============================================================================

float UltraSampler::processEnvelope(Voice& voice, int envIndex)
{
    auto& env = envelopes[envIndex];
    auto& state = voice.envStates[envIndex];

    float deltaTime = 1.0f / static_cast<float>(sampleRate);
    state.stageTime += deltaTime * 1000.0f;  // Convert to ms

    switch (state.stage) {
        case Voice::EnvState::Stage::Delay:
            if (state.stageTime >= env.delay) {
                state.stage = Voice::EnvState::Stage::Attack;
                state.stageTime = 0.0f;
            }
            state.level = 0.0f;
            break;

        case Voice::EnvState::Stage::Attack: {
            float attackTime = env.attack * (1.0f - env.velocityToAttack * voice.velocity);
            attackTime = std::max(1.0f, attackTime);
            float t = state.stageTime / attackTime;
            if (t >= 1.0f) {
                state.stage = Voice::EnvState::Stage::Hold;
                state.stageTime = 0.0f;
                state.level = 1.0f;
            } else {
                state.level = calculateEnvelopeCurve(t, env.attackCurve);
            }
            break;
        }

        case Voice::EnvState::Stage::Hold:
            if (state.stageTime >= env.hold) {
                state.stage = Voice::EnvState::Stage::Decay;
                state.stageTime = 0.0f;
            }
            state.level = 1.0f;
            break;

        case Voice::EnvState::Stage::Decay: {
            float t = state.stageTime / std::max(1.0f, env.decay);
            if (t >= 1.0f) {
                state.stage = Voice::EnvState::Stage::Sustain;
                state.level = env.sustain;
            } else {
                float curvedT = calculateEnvelopeCurve(t, env.decayCurve);
                state.level = 1.0f - curvedT * (1.0f - env.sustain);
            }
            break;
        }

        case Voice::EnvState::Stage::Sustain:
            state.level = env.sustain;
            break;

        case Voice::EnvState::Stage::Release: {
            float t = state.stageTime / std::max(1.0f, env.release);
            if (t >= 1.0f) {
                state.stage = Voice::EnvState::Stage::Off;
                state.level = 0.0f;
            } else {
                float curvedT = calculateEnvelopeCurve(t, env.releaseCurve);
                state.level = env.sustain * (1.0f - curvedT);
            }
            break;
        }

        case Voice::EnvState::Stage::Off:
            state.level = 0.0f;
            break;
    }

    return state.level * env.velocityToLevel * voice.velocity +
           state.level * (1.0f - env.velocityToLevel);
}

//==============================================================================
// LFO Processing
//==============================================================================

float UltraSampler::processLFO(Voice& voice, int lfoIndex)
{
    auto& lfo = lfos[lfoIndex];
    float& phase = voice.lfoPhases[lfoIndex];
    float& fadeLevel = voice.lfoFadeLevel[lfoIndex];

    // Calculate rate
    float rate = lfo.rate;
    if (lfo.tempoSync) {
        // TODO: Get tempo from host
        rate = 120.0f / 60.0f * lfo.beatDivision;
    }

    // Advance phase
    phase += rate / static_cast<float>(sampleRate);
    if (phase >= 1.0f) phase -= 1.0f;

    // Calculate LFO value
    float value = 0.0f;
    switch (lfo.shape) {
        case LFO::Shape::Sine:
            value = std::sin(phase * juce::MathConstants<float>::twoPi);
            break;
        case LFO::Shape::Triangle:
            value = 4.0f * std::abs(phase - 0.5f) - 1.0f;
            break;
        case LFO::Shape::Saw:
            value = 2.0f * phase - 1.0f;
            break;
        case LFO::Shape::Square:
            value = phase < 0.5f ? 1.0f : -1.0f;
            break;
        case LFO::Shape::SampleHold:
            // TODO: Implement sample & hold
            value = 0.0f;
            break;
        case LFO::Shape::Random:
            value = static_cast<float>(rand()) / RAND_MAX * 2.0f - 1.0f;
            break;
    }

    // Apply fade
    if (lfo.fade > 0.0f) {
        fadeLevel += 1.0f / (lfo.fade * static_cast<float>(sampleRate) * 0.001f);
        fadeLevel = std::min(1.0f, fadeLevel);
        value *= fadeLevel;
    }

    // Convert to unipolar if needed
    if (lfo.unipolar) {
        value = (value + 1.0f) * 0.5f;
    }

    return value * lfo.depth;
}

//==============================================================================
// Filter Processing (Zero-Delay Feedback)
//==============================================================================

float UltraSampler::processFilter(float input, FilterType type, float cutoff, float resonance,
                                  ZDFFilterState& state, bool /*isLeft*/)
{
    if (type == FilterType::Off) return input;

    // Normalize cutoff to 0-1 range
    float fc = cutoff / static_cast<float>(sampleRate);
    fc = juce::jlimit(0.001f, 0.49f, fc);

    // Calculate filter coefficients (simplified SVF)
    float g = std::tan(juce::MathConstants<float>::pi * fc);
    float k = 2.0f - 2.0f * resonance;  // Q from resonance

    // ZDF SVF topology
    float a1 = 1.0f / (1.0f + g * (g + k));
    float a2 = g * a1;
    float a3 = g * a2;

    float v3 = input - state.ic2eq;
    float v1 = a1 * state.ic1eq + a2 * v3;
    float v2 = state.ic2eq + a2 * state.ic1eq + a3 * v3;

    state.ic1eq = 2.0f * v1 - state.ic1eq;
    state.ic2eq = 2.0f * v2 - state.ic2eq;

    // Output based on filter type
    switch (type) {
        case FilterType::LowPass12:
        case FilterType::LowPass24:
            return v2;
        case FilterType::HighPass12:
        case FilterType::HighPass24:
            return input - k * v1 - v2;
        case FilterType::BandPass:
            return v1;
        case FilterType::BandReject:
            return input - k * v1;
        default:
            return input;
    }
}

//==============================================================================
// Sinc Table Construction
//==============================================================================

void UltraSampler::buildSincTable()
{
    const float pi = juce::MathConstants<float>::pi;
    int halfTaps = kSincTaps / 2;

    for (int tableIdx = 0; tableIdx < 256; ++tableIdx) {
        float frac = tableIdx / 256.0f;

        for (int t = 0; t < kSincTaps; ++t) {
            float x = (t - halfTaps) + frac;

            float sincVal;
            if (std::abs(x) < 0.0001f) {
                sincVal = 1.0f;
            } else {
                sincVal = std::sin(pi * x) / (pi * x);
            }

            // Apply Blackman window
            float windowPos = (t + frac) / kSincTaps;
            float window = 0.42f - 0.5f * std::cos(2.0f * pi * windowPos) +
                          0.08f * std::cos(4.0f * pi * windowPos);

            sincTable[tableIdx][t] = sincVal * window;
        }

        // Normalize
        float sum = 0.0f;
        for (int t = 0; t < kSincTaps; ++t) {
            sum += sincTable[tableIdx][t];
        }
        if (sum > 0.0f) {
            for (int t = 0; t < kSincTaps; ++t) {
                sincTable[tableIdx][t] /= sum;
            }
        }
    }
}

//==============================================================================
// Parameter Setters
//==============================================================================

void UltraSampler::setMasterVolume(float volume) { masterVolume = volume; }
void UltraSampler::setMasterTune(float cents) { masterTune = cents; }
void UltraSampler::setPolyphony(int voices) { maxPolyphony = std::min(voices, kMaxVoices); }
void UltraSampler::setGlideTime(float ms) { glideTime = ms; }
void UltraSampler::setInterpolationMode(InterpolationMode mode) { interpMode = mode; }

void UltraSampler::setFilter1Type(FilterType type) { filter1Type = type; }
void UltraSampler::setFilter1Cutoff(float hz) { filter1Cutoff = hz; }
void UltraSampler::setFilter1Resonance(float q) { filter1Resonance = q; }
void UltraSampler::setFilter1KeyTrack(float amount) { filter1KeyTrack = amount; }

void UltraSampler::setFilter2Type(FilterType type) { filter2Type = type; }
void UltraSampler::setFilter2Cutoff(float hz) { filter2Cutoff = hz; }
void UltraSampler::setFilter2Resonance(float q) { filter2Resonance = q; }
void UltraSampler::setFilterRouting(float mix) { filterMix = mix; }

void UltraSampler::setEnvelope(int envIndex, const Envelope& env)
{
    if (envIndex >= 0 && envIndex < 4) envelopes[envIndex] = env;
}

void UltraSampler::setLFO(int lfoIndex, const LFO& lfo)
{
    if (lfoIndex >= 0 && lfoIndex < 4) lfos[lfoIndex] = lfo;
}

void UltraSampler::setModSlot(int slot, ModSource source, ModDest dest, float amount)
{
    if (slot >= 0 && slot < kMaxModSlots) {
        modSlots[slot] = { source, dest, amount, true };
    }
}

void UltraSampler::setMacro(int index, float value)
{
    if (index >= 0 && index < 8) macros[index] = value;
}

void UltraSampler::setGranularParams(const GranularParams& params) { granularParams = params; }
void UltraSampler::setTimeStretchParams(const TimeStretchParams& params) { timeStretchParams = params; }

void UltraSampler::setBioData(float hrv, float coherence, float heartRate)
{
    bioHRV = hrv;
    bioCoherence = coherence;
    bioHeartRate = heartRate;
}

void UltraSampler::setBioReactiveEnabled(bool enabled) { bioReactiveEnabled = enabled; }

//==============================================================================
// Analysis
//==============================================================================

int UltraSampler::getActiveVoiceCount() const
{
    int count = 0;
    for (const auto& voice : voices) {
        if (voice.active) ++count;
    }
    return count;
}

float UltraSampler::getZonePlaybackPosition(int zoneIndex) const
{
    for (const auto& voice : voices) {
        if (voice.active && voice.zoneIndex == zoneIndex) {
            auto& zone = zones[zoneIndex];
            if (voice.layerIndex >= 0 && voice.layerIndex < zone.numVelocityLayers) {
                auto& layer = zone.velocityLayers[voice.layerIndex];
                if (layer.sample && !layer.sample->left.empty()) {
                    return static_cast<float>(voice.playbackPos / layer.sample->left.size());
                }
            }
        }
    }
    return 0.0f;
}

float UltraSampler::getEnvelopeLevel(int envIndex) const
{
    float maxLevel = 0.0f;
    for (const auto& voice : voices) {
        if (voice.active && envIndex >= 0 && envIndex < 4) {
            maxLevel = std::max(maxLevel, voice.envStates[envIndex].level);
        }
    }
    return maxLevel;
}

float UltraSampler::getLFOValue(int lfoIndex) const
{
    for (const auto& voice : voices) {
        if (voice.active && lfoIndex >= 0 && lfoIndex < 4) {
            return voice.lfoPhases[lfoIndex];  // Return phase as proxy
        }
    }
    return 0.0f;
}

//==============================================================================
// Presets
//==============================================================================

void UltraSampler::loadPreset(Preset preset)
{
    // Reset to defaults first
    filter1Type = FilterType::LowPass24;
    filter1Cutoff = 8000.0f;
    filter1Resonance = 0.3f;
    granularParams.enabled = false;

    switch (preset) {
        case Preset::Init:
            // Already reset
            break;

        case Preset::AcousticPiano:
            envelopes[0] = { 0, 2, 0, 50, 0.8f, 300, 0, 0, 0, 0, 1.0f };
            filter1Cutoff = 12000.0f;
            break;

        case Preset::ElectricPiano:
            envelopes[0] = { 0, 1, 0, 200, 0.6f, 400, 0, -0.2f, 0, 0, 0.8f };
            envelopes[1] = { 0, 5, 0, 300, 0.2f, 500, 0, -0.3f, 0, 0, 0.5f };
            filter1Cutoff = 3000.0f;
            filter1Resonance = 0.4f;
            break;

        case Preset::Strings:
            envelopes[0] = { 0, 300, 0, 100, 0.9f, 500, 0.3f, 0, 0, 0, 0.7f };
            filter1Cutoff = 5000.0f;
            lfos[0] = { LFO::Shape::Sine, 5.0f, 0.02f, 0, 0, false, 0.25f, true, false };
            break;

        case Preset::Choir:
            envelopes[0] = { 0, 400, 0, 200, 0.85f, 600, 0.2f, 0, 0, 0, 0.6f };
            filter1Type = FilterType::Formant;
            filter1Cutoff = 1500.0f;
            lfos[0] = { LFO::Shape::Sine, 4.0f, 0.03f, 0, 100, false, 0.25f, true, false };
            break;

        case Preset::PadSweep:
            envelopes[0] = { 0, 500, 0, 300, 0.7f, 1000, 0.5f, 0, 0.3f, 0, 0.5f };
            envelopes[1] = { 0, 1000, 0, 2000, 0.3f, 2000, 0, 0.5f, 0, 0, 0.8f };
            filter1Cutoff = 500.0f;
            filter1Resonance = 0.5f;
            break;

        case Preset::TextureEvolving:
            envelopes[0] = { 0, 800, 0, 500, 0.6f, 1500, 0.4f, 0, 0.2f, 0, 0.4f };
            granularParams.enabled = true;
            granularParams.grainSize = 80.0f;
            granularParams.grainDensity = 15.0f;
            granularParams.grainPositionRand = 0.3f;
            granularParams.grainPitchRand = 0.5f;
            granularParams.grainPanSpread = 0.8f;
            break;

        case Preset::GranularAtmosphere:
            envelopes[0] = { 0, 1000, 0, 500, 0.8f, 2000, 0.6f, 0, 0.4f, 0, 0.3f };
            granularParams.enabled = true;
            granularParams.grainSize = 150.0f;
            granularParams.grainDensity = 8.0f;
            granularParams.grainPositionRand = 0.5f;
            granularParams.grainPitchRand = 2.0f;
            granularParams.grainPanSpread = 1.0f;
            granularParams.windowType = GranularParams::Window::Hann;
            filter1Cutoff = 3000.0f;
            filter1Resonance = 0.4f;
            break;

        case Preset::BioReactivePad:
            envelopes[0] = { 0, 600, 0, 400, 0.75f, 1200, 0.3f, 0, 0.2f, 0, 0.5f };
            granularParams.enabled = true;
            granularParams.grainSize = 100.0f;
            granularParams.grainDensity = 12.0f;
            bioReactiveEnabled = true;
            filter1Cutoff = 2000.0f;
            lfos[0] = { LFO::Shape::Sine, 0.5f, 0.1f, 0, 500, false, 0.25f, true, false };
            break;

        case Preset::DrumKit:
            envelopes[0] = { 0, 0.5f, 0, 50, 0.0f, 100, 0, -0.5f, 0, 0, 1.0f };
            filter1Type = FilterType::Off;
            break;

        case Preset::LoFiKeys:
            envelopes[0] = { 0, 5, 0, 150, 0.5f, 300, 0, 0, 0, 0, 0.9f };
            filter1Cutoff = 2500.0f;
            filter1Resonance = 0.2f;
            // Would add bitcrusher effect here
            break;

        default:
            break;
    }
}
