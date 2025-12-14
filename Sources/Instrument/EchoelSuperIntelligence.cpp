#include "EchoelSuperIntelligence.h"
#include <algorithm>
#include <numeric>
#include <cmath>

//==============================================================================
// Constructor
//==============================================================================

EchoelSuperIntelligence::EchoelSuperIntelligence()
    : quantumRng(std::random_device{}())
{
    // Initialize hardware profile to standard MIDI
    currentProfile.type = ControllerType::StandardMIDI;
    currentProfile.name = "Standard MIDI";
    currentProfile.supportsMPE = false;
    currentProfile.pitchBendRange = 2.0f;

    // Initialize Wise Mode features (all enabled by default)
    wiseModeFeatures.fill(true);

    // Initialize quantum state
    for (auto& amp : quantumState) {
        amp = std::complex<float>(1.0f / std::sqrt(static_cast<float>(kQuantumStates)), 0.0f);
    }

    // Initialize note histogram
    noteHistogram.fill(0);
    globalPressHistory.fill(0.0f);

    // Initialize bio state
    currentBioState = BioState();
}

//==============================================================================
// Initialization
//==============================================================================

void EchoelSuperIntelligence::prepare(double newSampleRate, int newBlockSize)
{
    sampleRate = newSampleRate;
    blockSize = newBlockSize;
    sampler.prepare(sampleRate, blockSize);
    reset();
}

void EchoelSuperIntelligence::reset()
{
    sampler.reset();

    for (auto& voice : mpeVoices) {
        voice.active = false;
        voice.pressHistory.fill(0.0f);
        voice.slideHistory.fill(0.0f);
        voice.glideHistory.fill(0.0f);
        voice.historyIndex = 0;
    }

    noteHistogram.fill(0);
    wiseModeState.totalNotesPlayed = 0;
}

//==============================================================================
// Hardware Detection & Configuration
//==============================================================================

EchoelSuperIntelligence::ControllerType
EchoelSuperIntelligence::detectController(const juce::MidiMessage& msg)
{
    // Check for MPE configuration message (MCM)
    if (msg.isController() && msg.getControllerNumber() == 0x06) {
        // RPN MSB for MPE Configuration
        // Could be setting MPE zone
        return ControllerType::StandardMIDI;  // Will update after MCM sequence
    }

    // Detect by channel usage pattern
    int channel = msg.getChannel();

    // Seaboard typically uses channels 2-16 for MPE
    if (channel >= 2 && channel <= 16) {
        // Check for characteristic CC74 (slide)
        if (msg.isController() && msg.getControllerNumber() == 74) {
            currentProfile.type = ControllerType::ROLISeaboard;
            currentProfile.name = "ROLI Seaboard";
            currentProfile.supportsMPE = true;
            currentProfile.supportsSlide = true;
            currentProfile.pitchBendRange = 48.0f;
            mpeEnabled = true;
            return ControllerType::ROLISeaboard;
        }
    }

    // Check for Linnstrument (uses different CC for Y-axis)
    if (msg.isController() && msg.getControllerNumber() == 1) {
        // Linnstrument often uses CC1 for Y-axis
        if (channel >= 1 && channel <= 16) {
            currentProfile.type = ControllerType::Linnstrument;
            currentProfile.name = "Linnstrument";
            currentProfile.supportsMPE = true;
            currentProfile.pitchBendRange = 24.0f;
            mpeEnabled = true;
            return ControllerType::Linnstrument;
        }
    }

    // Check for Osmose (high-resolution aftertouch)
    if (msg.isAftertouch()) {
        if (channel >= 2 && channel <= 16) {
            currentProfile.type = ControllerType::ExpressiveEOsmose;
            currentProfile.name = "Expressive E Osmose";
            currentProfile.supportsMPE = true;
            currentProfile.supportsPolyAT = true;
            currentProfile.pitchBendRange = 48.0f;
            mpeEnabled = true;
            return ControllerType::ExpressiveEOsmose;
        }
    }

    return currentProfile.type;
}

void EchoelSuperIntelligence::setControllerProfile(const HardwareProfile& profile)
{
    currentProfile = profile;
    mpeEnabled = profile.supportsMPE;

    if (profile.supportsMPE) {
        mpeLowerZone = profile.mpeLowerZone;
        mpeUpperZone = profile.mpeUpperZone;
        globalPitchBendRange = profile.pitchBendRange;
    }
}

void EchoelSuperIntelligence::configureMPE(int lowerZone, int upperZone, float pitchBendRange)
{
    mpeLowerZone = lowerZone;
    mpeUpperZone = upperZone;
    globalPitchBendRange = pitchBendRange;
    mpeEnabled = true;
}

void EchoelSuperIntelligence::setVelocityCurve(float curve)
{
    currentProfile.velocityCurve = juce::jlimit(0.1f, 4.0f, curve);
}

void EchoelSuperIntelligence::setPressureCurve(float curve)
{
    currentProfile.pressureCurve = juce::jlimit(0.1f, 4.0f, curve);
}

void EchoelSuperIntelligence::setSlideCurve(float curve)
{
    currentProfile.slideCurve = juce::jlimit(0.1f, 4.0f, curve);
}

//==============================================================================
// ROLI Seaboard Configuration
//==============================================================================

void EchoelSuperIntelligence::configureSeaboard(float strikeResponse, float glideResponse,
                                                 float slideResponse, float pressResponse)
{
    currentProfile.type = ControllerType::ROLISeaboard;
    currentProfile.name = "ROLI Seaboard (Custom)";
    currentProfile.supportsMPE = true;
    currentProfile.supportsSlide = true;
    currentProfile.pitchBendRange = 48.0f;

    currentProfile.velocityCurve = strikeResponse;
    currentProfile.slideCurve = slideResponse;
    currentProfile.pressureCurve = pressResponse;
    // Glide response affects pitch bend interpretation

    mpeEnabled = true;
}

void EchoelSuperIntelligence::setSeaboardGlideMode(bool absolute)
{
    // Absolute mode: glide represents absolute pitch
    // Relative mode: glide represents deviation from struck note
    // This affects how we interpret pitch bend messages
    juce::ignoreUnused(absolute);
}

void EchoelSuperIntelligence::setSeaboardSlideCC(int cc)
{
    // Default is CC74, but can be customized
    currentProfile.ccMapping[cc] = 74;  // Map custom CC to internal slide
}

//==============================================================================
// ROLI Airwave Configuration
//==============================================================================

void EchoelSuperIntelligence::configureAirwave(bool enableGestures, float sensitivity)
{
    if (enableGestures) {
        currentProfile.type = ControllerType::ROLIAirwave;
        currentProfile.name = "ROLI Airwave";
    }
    juce::ignoreUnused(sensitivity);
}

void EchoelSuperIntelligence::mapAirwaveGesture(int gestureType, int parameter, float amount)
{
    juce::ignoreUnused(gestureType, parameter, amount);
    // Map Airwave gesture types to internal parameters
    // Gesture types: wave, push, grab, etc.
}

//==============================================================================
// Wise Mode Control
//==============================================================================

void EchoelSuperIntelligence::setWiseModeEnabled(bool enabled)
{
    wiseModeState.enabled = enabled;

    if (enabled) {
        // Initialize Wise Mode state
        wiseModeState.noteWeights.fill(1.0f / 12.0f);
        wiseModeState.keyConfidence = 0.0f;
    }
}

void EchoelSuperIntelligence::setIntelligenceLevel(float level)
{
    wiseModeState.intelligenceLevel = juce::jlimit(0.0f, 1.0f, level);
}

void EchoelSuperIntelligence::setWiseModeFeature(WiseModeFeature feature, bool enabled)
{
    int index = static_cast<int>(feature);
    if (index >= 0 && index < static_cast<int>(wiseModeFeatures.size())) {
        wiseModeFeatures[index] = enabled;
    }
}

std::array<int, 8> EchoelSuperIntelligence::getSuggestedHarmony() const
{
    return wiseModeState.suggestedNotes;
}

int EchoelSuperIntelligence::getPredictedNextNote() const
{
    // Find most likely next note based on histogram and current context
    int maxIndex = 0;
    float maxWeight = 0.0f;

    for (int i = 0; i < 12; ++i) {
        if (wiseModeState.noteWeights[i] > maxWeight) {
            maxWeight = wiseModeState.noteWeights[i];
            maxIndex = i;
        }
    }

    // Return in middle octave (C4 = 60)
    return 60 + maxIndex;
}

float EchoelSuperIntelligence::getOptimalTimbre() const
{
    return calculateOptimalTimbre();
}

void EchoelSuperIntelligence::setScaleLock(int key, int scale, bool enabled)
{
    if (enabled) {
        wiseModeState.detectedKey = key % 12;
        wiseModeState.detectedScale = scale;
        wiseModeState.keyConfidence = 1.0f;  // Locked = full confidence
    } else {
        wiseModeState.keyConfidence = 0.0f;  // Reset to auto-detect
    }
}

//==============================================================================
// Bio-Reactive Integration
//==============================================================================

void EchoelSuperIntelligence::setBioState(const BioState& state)
{
    currentBioState = state;

    // Calculate derived metrics
    currentBioState.stressLevel = 1.0f - state.coherence;
    currentBioState.focusLevel = state.coherence * 0.5f + 0.5f;

    // Flow state detection (high coherence + moderate arousal)
    if (state.coherence > 0.6f && state.emotionArousal > 0.3f && state.emotionArousal < 0.7f) {
        currentBioState.flowState = (state.coherence - 0.6f) / 0.4f;
    } else {
        currentBioState.flowState *= 0.95f;  // Decay
    }

    // Update bio-sync for all active voices
    for (auto& voice : mpeVoices) {
        if (voice.active) {
            voice.coherenceLevel = state.coherence;
            voice.bioInfluence = bioInfluence;
        }
    }

    // Pass to sampler
    sampler.setBioData(state.hrv, state.coherence, state.heartRate);
}

void EchoelSuperIntelligence::setBioInfluence(float amount)
{
    bioInfluence = juce::jlimit(0.0f, 1.0f, amount);
    sampler.setBioReactiveEnabled(amount > 0.01f);
}

float EchoelSuperIntelligence::getBioResonance() const
{
    return calculateBioResonance();
}

void EchoelSuperIntelligence::setBreathSyncEnabled(bool enabled)
{
    breathSyncEnabled = enabled;
}

void EchoelSuperIntelligence::setTargetCoherence(float coherence)
{
    wiseModeState.targetCoherence = juce::jlimit(0.0f, 1.0f, coherence);
}

//==============================================================================
// MPE Input Processing
//==============================================================================

void EchoelSuperIntelligence::processMidiMessage(const juce::MidiMessage& msg)
{
    // Auto-detect controller if unknown
    if (currentProfile.type == ControllerType::Unknown) {
        detectController(msg);
    }

    int channel = msg.getChannel();

    // Check if this is an MPE member channel
    bool isMPEChannel = mpeEnabled && (channel >= mpeLowerZone && channel <= mpeUpperZone);

    if (msg.isNoteOn()) {
        if (isMPEChannel) {
            processMPENoteOn(channel, msg.getNoteNumber(), msg.getVelocity());
        } else {
            // Standard MIDI - use sampler directly
            sampler.noteOn(msg.getNoteNumber(), msg.getVelocity() / 127.0f, channel);
        }
    }
    else if (msg.isNoteOff()) {
        if (isMPEChannel) {
            processMPENoteOff(channel, msg.getNoteNumber(), msg.getVelocity());
        } else {
            sampler.noteOff(msg.getNoteNumber(), msg.getVelocity() / 127.0f, channel);
        }
    }
    else if (msg.isChannelPressure()) {
        if (isMPEChannel) {
            processMPEPressure(channel, msg.getChannelPressureValue());
        }
    }
    else if (msg.isAftertouch()) {
        // Polyphonic aftertouch
        if (isMPEChannel) {
            // Find voice for this note and update pressure
            for (auto& voice : mpeVoices) {
                if (voice.active && voice.channel == channel &&
                    voice.noteNumber == msg.getNoteNumber()) {
                    voice.press = msg.getAfterTouchValue() / 127.0f;
                    voice.press = applyPressureCurve(voice.press);
                }
            }
        }
    }
    else if (msg.isPitchWheel()) {
        if (isMPEChannel) {
            processMPEPitchBend(channel, msg.getPitchWheelValue());
        } else {
            float bend = (msg.getPitchWheelValue() - 8192) / 8192.0f * 2.0f;
            sampler.setPitchBend(bend);
        }
    }
    else if (msg.isController()) {
        int cc = msg.getControllerNumber();
        int value = msg.getControllerValue();

        if (cc == 74 && isMPEChannel) {
            // CC74 = Slide (Y-axis) in MPE
            processMPESlide(channel, value);
        }
        else if (cc == 1) {
            // Mod wheel
            sampler.setModWheel(value / 127.0f);
        }
        else if (cc == 2) {
            // Breath controller
            if (currentProfile.supportsBreath) {
                // Map breath to filter or amplitude
            }
        }
        else if (cc == 11) {
            // Expression
            if (currentProfile.supportsExpression) {
                // Map expression to volume
            }
        }
    }
}

void EchoelSuperIntelligence::processMidiBuffer(const juce::MidiBuffer& buffer)
{
    for (const auto metadata : buffer) {
        processMidiMessage(metadata.getMessage());
    }
}

void EchoelSuperIntelligence::processMPENoteOn(int channel, int note, int velocity)
{
    // Allocate MPE voice
    MPEVoice* voice = allocateMPEVoice(channel, note);
    if (!voice) return;

    voice->active = true;
    voice->channel = channel;
    voice->noteNumber = note;
    voice->strike = applyVelocityCurve(velocity / 127.0f);
    voice->press = voice->strike;  // Initial pressure = strike
    voice->slide = 0.5f;           // Center position
    voice->glide = 0.0f;           // No initial bend
    voice->lift = 0.0f;

    // Reset history
    voice->pressHistory.fill(voice->press);
    voice->slideHistory.fill(voice->slide);
    voice->glideHistory.fill(voice->glide);
    voice->historyIndex = 0;

    // Apply bio state
    voice->coherenceLevel = currentBioState.coherence;
    voice->bioInfluence = bioInfluence;

    // Update Wise Mode
    if (wiseModeState.enabled) {
        updateHarmonicIntelligence(note);
        noteHistogram[note % 12]++;
        wiseModeState.totalNotesPlayed++;
        wiseModeState.averageVelocity =
            (wiseModeState.averageVelocity * (wiseModeState.totalNotesPlayed - 1) + voice->strike) /
            wiseModeState.totalNotesPlayed;
    }

    // Trigger sampler note
    sampler.noteOn(note, voice->strike, channel);
}

void EchoelSuperIntelligence::processMPENoteOff(int channel, int note, int velocity)
{
    MPEVoice* voice = findMPEVoice(channel, note);
    if (!voice) return;

    voice->lift = velocity / 127.0f;
    voice->active = false;

    // Update Wise Mode gesture memory
    if (wiseModeState.enabled) {
        updatePredictiveArticulation(*voice);
        updateGestureMemory(*voice);
    }

    // Trigger sampler note off
    sampler.noteOff(note, voice->lift, channel);
}

void EchoelSuperIntelligence::processMPEPressure(int channel, int pressure)
{
    // Update all active voices on this channel
    for (auto& voice : mpeVoices) {
        if (voice.active && voice.channel == channel) {
            voice.press = applyPressureCurve(pressure / 127.0f);

            // Update history
            voice.pressHistory[voice.historyIndex] = voice.press;

            // Bio-modulation
            if (bioInfluence > 0.0f) {
                applyBioModulation(voice);
            }
        }
    }
}

void EchoelSuperIntelligence::processMPESlide(int channel, int value)
{
    for (auto& voice : mpeVoices) {
        if (voice.active && voice.channel == channel) {
            voice.slide = applySlideCurve(value / 127.0f);
            voice.slideHistory[voice.historyIndex] = voice.slide;
        }
    }
}

void EchoelSuperIntelligence::processMPEPitchBend(int channel, int value)
{
    // Convert 14-bit pitch bend to semitones
    float normalized = (value - 8192) / 8192.0f;
    float semitones = normalized * globalPitchBendRange;

    for (auto& voice : mpeVoices) {
        if (voice.active && voice.channel == channel) {
            voice.glide = semitones;
            voice.glideHistory[voice.historyIndex] = voice.glide;
            voice.historyIndex = (voice.historyIndex + 1) % 64;

            // Gesture recognition
            if (wiseModeState.enabled) {
                recognizeGestures(voice);
            }
        }
    }
}

int EchoelSuperIntelligence::getActiveMPEVoiceCount() const
{
    int count = 0;
    for (const auto& voice : mpeVoices) {
        if (voice.active) ++count;
    }
    return count;
}

MPEVoice* EchoelSuperIntelligence::allocateMPEVoice(int channel, int noteNumber)
{
    // First, try to find an inactive voice
    for (auto& voice : mpeVoices) {
        if (!voice.active) {
            return &voice;
        }
    }

    // Steal oldest voice on same channel
    for (auto& voice : mpeVoices) {
        if (voice.channel == channel) {
            return &voice;
        }
    }

    // Steal first voice
    return &mpeVoices[0];
}

MPEVoice* EchoelSuperIntelligence::findMPEVoice(int channel, int noteNumber)
{
    for (auto& voice : mpeVoices) {
        if (voice.active && voice.channel == channel && voice.noteNumber == noteNumber) {
            return &voice;
        }
    }
    return nullptr;
}

//==============================================================================
// Wise Mode AI
//==============================================================================

void EchoelSuperIntelligence::updateHarmonicIntelligence(int noteNumber)
{
    if (!wiseModeFeatures[static_cast<int>(WiseModeFeature::HarmonicIntelligence)]) return;

    int pitchClass = noteNumber % 12;

    // Update note weights using exponential moving average
    float learningRate = 0.1f * wiseModeState.intelligenceLevel;
    for (int i = 0; i < 12; ++i) {
        if (i == pitchClass) {
            wiseModeState.noteWeights[i] += learningRate * (1.0f - wiseModeState.noteWeights[i]);
        } else {
            wiseModeState.noteWeights[i] *= (1.0f - learningRate * 0.1f);
        }
    }

    // Normalize
    float sum = 0.0f;
    for (float w : wiseModeState.noteWeights) sum += w;
    if (sum > 0.0f) {
        for (float& w : wiseModeState.noteWeights) w /= sum;
    }

    // Key detection using Krumhansl-Schmuckler algorithm (simplified)
    static const std::array<float, 12> majorProfile =
        {6.35f, 2.23f, 3.48f, 2.33f, 4.38f, 4.09f, 2.52f, 5.19f, 2.39f, 3.66f, 2.29f, 2.88f};

    float maxCorrelation = -1.0f;
    int bestKey = 0;

    for (int key = 0; key < 12; ++key) {
        float correlation = 0.0f;
        for (int i = 0; i < 12; ++i) {
            int rotatedIndex = (i + key) % 12;
            correlation += wiseModeState.noteWeights[i] * majorProfile[rotatedIndex];
        }
        if (correlation > maxCorrelation) {
            maxCorrelation = correlation;
            bestKey = key;
        }
    }

    wiseModeState.detectedKey = bestKey;
    wiseModeState.keyConfidence = maxCorrelation / 50.0f;  // Normalize

    // Generate harmonic suggestions
    wiseModeState.suggestedNotes = generateHarmonicSuggestions();
}

void EchoelSuperIntelligence::updatePredictiveArticulation(const MPEVoice& voice)
{
    if (!wiseModeFeatures[static_cast<int>(WiseModeFeature::PredictiveArticulation)]) return;

    // Analyze press envelope
    float pressSum = 0.0f;
    for (float p : voice.pressHistory) pressSum += p;
    float avgPress = pressSum / 64.0f;

    // Predict next dynamics
    wiseModeState.predictedDynamics =
        wiseModeState.predictedDynamics * 0.8f + avgPress * 0.2f;

    // Analyze gesture complexity
    float pressVariance = 0.0f;
    for (float p : voice.pressHistory) {
        pressVariance += (p - avgPress) * (p - avgPress);
    }
    wiseModeState.gestureComplexity = std::sqrt(pressVariance / 64.0f);
}

void EchoelSuperIntelligence::updateGestureMemory(const MPEVoice& voice)
{
    if (!wiseModeFeatures[static_cast<int>(WiseModeFeature::GestureMemory)]) return;

    // Store gesture in global history
    globalPressHistory[gestureHistoryIndex] = voice.press;
    gestureHistoryIndex = (gestureHistoryIndex + 1) % kGestureHistorySize;
}

std::array<int, 8> EchoelSuperIntelligence::generateHarmonicSuggestions()
{
    std::array<int, 8> suggestions;
    suggestions.fill(-1);

    int key = wiseModeState.detectedKey;
    int baseOctave = 60;  // C4

    // Major scale degrees
    static const int majorScale[] = {0, 2, 4, 5, 7, 9, 11};

    // Suggest chord tones and scale tones
    suggestions[0] = baseOctave + key;                          // Root
    suggestions[1] = baseOctave + key + majorScale[2];          // Third
    suggestions[2] = baseOctave + key + majorScale[4];          // Fifth
    suggestions[3] = baseOctave + key + majorScale[6];          // Seventh
    suggestions[4] = baseOctave + key + majorScale[1];          // Second
    suggestions[5] = baseOctave + key + majorScale[3];          // Fourth
    suggestions[6] = baseOctave + key + majorScale[5];          // Sixth
    suggestions[7] = baseOctave + key + 12;                     // Octave

    return suggestions;
}

float EchoelSuperIntelligence::calculateOptimalTimbre() const
{
    // Base timbre on playing intensity and bio state
    float intensity = wiseModeState.playingIntensity;
    float coherence = currentBioState.coherence;

    // High coherence = brighter, more open timbre
    // High intensity = more aggressive timbre
    float timbre = 0.5f + (coherence - 0.5f) * 0.3f + (intensity - 0.5f) * 0.2f;

    return juce::jlimit(0.0f, 1.0f, timbre);
}

float EchoelSuperIntelligence::calculateBioResonance() const
{
    // Calculate how well the current sound matches the bio state
    float targetEnergy = currentBioState.emotionArousal;
    float targetValence = (currentBioState.emotionValence + 1.0f) / 2.0f;

    float currentEnergy = wiseModeState.playingIntensity;
    float currentBrightness = calculateOptimalTimbre();

    float energyMatch = 1.0f - std::abs(targetEnergy - currentEnergy);
    float timbreMatch = 1.0f - std::abs(targetValence - currentBrightness);

    return (energyMatch + timbreMatch) / 2.0f * currentBioState.coherence;
}

//==============================================================================
// Gesture Recognition
//==============================================================================

void EchoelSuperIntelligence::registerGesture(const GesturePattern& pattern)
{
    registeredGestures.push_back(pattern);
}

void EchoelSuperIntelligence::clearGestures()
{
    registeredGestures.clear();
}

juce::String EchoelSuperIntelligence::getLastRecognizedGesture() const
{
    return lastGesture;
}

void EchoelSuperIntelligence::recognizeGestures(const MPEVoice& voice)
{
    for (const auto& pattern : registeredGestures) {
        float match = matchGesturePattern(pattern, voice);
        if (match >= pattern.matchThreshold) {
            lastGesture = pattern.name;
            if (pattern.onRecognized) {
                pattern.onRecognized(match);
            }
        }
    }
}

float EchoelSuperIntelligence::matchGesturePattern(const GesturePattern& pattern,
                                                    const MPEVoice& voice)
{
    // Simple correlation-based matching
    float correlation = 0.0f;
    int count = 0;

    int patternSize = static_cast<int>(pattern.glideProfile.size());
    for (int i = 0; i < patternSize && i < 64; ++i) {
        int idx = (voice.historyIndex - patternSize + i + 64) % 64;
        correlation += pattern.glideProfile[i] * voice.glideHistory[idx];
        ++count;
    }

    return count > 0 ? correlation / count : 0.0f;
}

//==============================================================================
// Quantum Creativity
//==============================================================================

float EchoelSuperIntelligence::getQuantumVariation(int paramIndex)
{
    if (!wiseModeFeatures[static_cast<int>(WiseModeFeature::QuantumCreativity)]) {
        return 0.0f;
    }

    // Measure quantum state at given index
    return measureQuantumState(paramIndex % kQuantumStates);
}

void EchoelSuperIntelligence::setQuantumEntropy(float entropy)
{
    wiseModeState.quantumEntropy = juce::jlimit(0.0f, 1.0f, entropy);
}

void EchoelSuperIntelligence::collapseQuantumState()
{
    // Collapse to most probable state
    float maxProb = 0.0f;
    int maxIndex = 0;

    for (int i = 0; i < kQuantumStates; ++i) {
        float prob = std::norm(quantumState[i]);
        if (prob > maxProb) {
            maxProb = prob;
            maxIndex = i;
        }
    }

    // Reset to collapsed state
    for (int i = 0; i < kQuantumStates; ++i) {
        quantumState[i] = (i == maxIndex) ? std::complex<float>(1.0f, 0.0f)
                                          : std::complex<float>(0.0f, 0.0f);
    }
}

float EchoelSuperIntelligence::getQuantumCoherence() const
{
    // Calculate quantum coherence as sum of off-diagonal elements
    float coherence = 0.0f;
    for (int i = 0; i < kQuantumStates; ++i) {
        for (int j = i + 1; j < kQuantumStates; ++j) {
            coherence += std::abs(quantumState[i] * std::conj(quantumState[j]));
        }
    }
    return coherence / (kQuantumStates * kQuantumStates / 2);
}

float EchoelSuperIntelligence::measureQuantumState(int index)
{
    // Born rule: probability = |amplitude|^2
    float probability = std::norm(quantumState[index]);

    // Add quantum uncertainty based on entropy
    std::uniform_real_distribution<float> dist(-wiseModeState.quantumEntropy,
                                                wiseModeState.quantumEntropy);
    float variation = dist(quantumRng);

    return juce::jlimit(-1.0f, 1.0f, (probability - 0.5f) * 2.0f + variation);
}

void EchoelSuperIntelligence::evolveQuantumState(float deltaTime)
{
    // Simple quantum evolution (rotation in Hilbert space)
    float theta = deltaTime * wiseModeState.quantumEntropy * 0.1f;

    for (int i = 0; i < kQuantumStates; ++i) {
        float phase = std::arg(quantumState[i]) + theta * (i + 1);
        float mag = std::abs(quantumState[i]);
        quantumState[i] = std::polar(mag, phase);
    }

    // Add decoherence based on bio-coherence
    float decoherence = 1.0f - currentBioState.coherence;
    for (auto& amp : quantumState) {
        amp *= (1.0f - decoherence * deltaTime * 0.01f);
    }

    // Renormalize
    float norm = 0.0f;
    for (const auto& amp : quantumState) norm += std::norm(amp);
    norm = std::sqrt(norm);
    if (norm > 0.0f) {
        for (auto& amp : quantumState) amp /= norm;
    }
}

//==============================================================================
// Bio Processing
//==============================================================================

void EchoelSuperIntelligence::applyBioModulation(MPEVoice& voice)
{
    if (bioInfluence < 0.01f) return;

    // Modulate press response based on coherence
    float coherenceBoost = (currentBioState.coherence - 0.5f) * bioInfluence;
    voice.press *= (1.0f + coherenceBoost * 0.3f);

    // Modulate timbre based on flow state
    voice.bioInfluence = currentBioState.flowState * bioInfluence;
}

void EchoelSuperIntelligence::updateFlowState()
{
    // Flow state emerges when coherence is high and playing is consistent
    float coherenceFactor = currentBioState.coherence;
    float consistencyFactor = 1.0f - wiseModeState.gestureComplexity;

    currentBioState.flowState =
        currentBioState.flowState * 0.99f +
        coherenceFactor * consistencyFactor * 0.01f;
}

//==============================================================================
// Processing
//==============================================================================

void EchoelSuperIntelligence::processBlock(juce::AudioBuffer<float>& buffer,
                                            juce::MidiBuffer& midiMessages)
{
    // Process MIDI messages
    processMidiBuffer(midiMessages);

    // Update Wise Mode state
    if (wiseModeState.enabled) {
        updateQuantumState();
        updateFlowState();
    }

    // Update MPE voice parameters on sampler
    for (const auto& voice : mpeVoices) {
        if (voice.active) {
            // Apply MPE modulations to sampler
            // This would need proper voice routing in a full implementation
        }
    }

    // Process audio
    sampler.processBlock(buffer, juce::MidiBuffer());  // MIDI already processed
}

//==============================================================================
// Presets
//==============================================================================

void EchoelSuperIntelligence::loadPreset(IntelligencePreset preset)
{
    switch (preset) {
        case IntelligencePreset::PureInstrument:
            wiseModeState.enabled = false;
            bioInfluence = 0.0f;
            break;

        case IntelligencePreset::SubtleAssist:
            wiseModeState.enabled = true;
            wiseModeState.intelligenceLevel = 0.3f;
            bioInfluence = 0.2f;
            break;

        case IntelligencePreset::FullWisdom:
            wiseModeState.enabled = true;
            wiseModeState.intelligenceLevel = 1.0f;
            bioInfluence = 0.8f;
            for (auto& f : wiseModeFeatures) f = true;
            break;

        case IntelligencePreset::SeaboardExpressive:
            currentProfile.type = ControllerType::ROLISeaboard;
            currentProfile.supportsMPE = true;
            currentProfile.pitchBendRange = 48.0f;
            currentProfile.velocityCurve = 1.2f;
            currentProfile.pressureCurve = 0.8f;
            mpeEnabled = true;
            wiseModeState.enabled = true;
            wiseModeState.intelligenceLevel = 0.5f;
            break;

        case IntelligencePreset::LinnstrumentGrid:
            currentProfile.type = ControllerType::Linnstrument;
            currentProfile.supportsMPE = true;
            currentProfile.pitchBendRange = 24.0f;
            currentProfile.velocityCurve = 1.0f;
            mpeEnabled = true;
            break;

        case IntelligencePreset::OsmoseAftertouch:
            currentProfile.type = ControllerType::ExpressiveEOsmose;
            currentProfile.supportsMPE = true;
            currentProfile.supportsPolyAT = true;
            currentProfile.pitchBendRange = 48.0f;
            currentProfile.pressureCurve = 0.7f;
            mpeEnabled = true;
            break;

        case IntelligencePreset::MeditativeFlow:
            wiseModeState.enabled = true;
            wiseModeState.intelligenceLevel = 0.7f;
            bioInfluence = 1.0f;
            wiseModeState.targetCoherence = 0.8f;
            breathSyncEnabled = true;
            wiseModeState.quantumEntropy = 0.1f;
            sampler.loadPreset(UltraSampler::Preset::BioReactivePad);
            break;

        case IntelligencePreset::EnergeticPerformance:
            wiseModeState.enabled = true;
            wiseModeState.intelligenceLevel = 0.5f;
            bioInfluence = 0.6f;
            wiseModeState.quantumEntropy = 0.4f;
            currentProfile.velocityCurve = 0.8f;  // More responsive
            break;

        case IntelligencePreset::BreathingSpace:
            wiseModeState.enabled = true;
            bioInfluence = 1.0f;
            breathSyncEnabled = true;
            wiseModeState.adaptationRate = 0.05f;
            sampler.loadPreset(UltraSampler::Preset::GranularAtmosphere);
            break;

        case IntelligencePreset::QuantumExplorer:
            wiseModeState.enabled = true;
            wiseModeState.intelligenceLevel = 1.0f;
            wiseModeState.quantumEntropy = 0.8f;
            wiseModeState.variationAmount = 0.5f;
            sampler.loadPreset(UltraSampler::Preset::TextureEvolving);
            break;

        case IntelligencePreset::HarmonicGuide:
            wiseModeState.enabled = true;
            wiseModeFeatures[static_cast<int>(WiseModeFeature::HarmonicIntelligence)] = true;
            wiseModeFeatures[static_cast<int>(WiseModeFeature::ScaleAwareness)] = true;
            wiseModeState.intelligenceLevel = 0.9f;
            break;

        case IntelligencePreset::GestureArtist:
            wiseModeState.enabled = true;
            wiseModeFeatures[static_cast<int>(WiseModeFeature::GestureMemory)] = true;
            wiseModeFeatures[static_cast<int>(WiseModeFeature::AutoExpression)] = true;
            currentProfile.velocityCurve = 1.5f;
            currentProfile.pressureCurve = 1.2f;
            break;

        default:
            break;
    }
}

//==============================================================================
// Analytics
//==============================================================================

EchoelSuperIntelligence::PlayingStats EchoelSuperIntelligence::getPlayingStats() const
{
    PlayingStats stats;
    stats.totalNotes = wiseModeState.totalNotesPlayed;
    stats.averageVelocity = wiseModeState.averageVelocity;
    stats.averageDuration = wiseModeState.averageDuration;
    stats.expressionRange = wiseModeState.gestureComplexity;
    stats.detectedKey = wiseModeState.detectedKey;
    stats.keyConfidence = wiseModeState.keyConfidence;
    stats.flowStateLevel = currentBioState.flowState;

    // Calculate MPE usage
    float slideSum = 0.0f, glideSum = 0.0f, pressSum = 0.0f;
    int activeCount = 0;

    for (const auto& voice : mpeVoices) {
        if (voice.active) {
            slideSum += std::abs(voice.slide - 0.5f);
            glideSum += std::abs(voice.glide);
            pressSum += voice.press;
            ++activeCount;
        }
    }

    if (activeCount > 0) {
        stats.slideUsage = slideSum / activeCount;
        stats.glideUsage = glideSum / activeCount / globalPitchBendRange;
        stats.pressUsage = pressSum / activeCount;
    }

    return stats;
}

std::array<float, 128> EchoelSuperIntelligence::getPressVisualization() const
{
    std::array<float, 128> viz;
    viz.fill(0.0f);

    for (const auto& voice : mpeVoices) {
        if (voice.active && voice.noteNumber >= 0 && voice.noteNumber < 128) {
            viz[voice.noteNumber] = voice.press;
        }
    }

    return viz;
}

std::array<float, 128> EchoelSuperIntelligence::getSlideVisualization() const
{
    std::array<float, 128> viz;
    viz.fill(0.5f);

    for (const auto& voice : mpeVoices) {
        if (voice.active && voice.noteNumber >= 0 && voice.noteNumber < 128) {
            viz[voice.noteNumber] = voice.slide;
        }
    }

    return viz;
}

std::array<float, 128> EchoelSuperIntelligence::getGlideVisualization() const
{
    std::array<float, 128> viz;
    viz.fill(0.0f);

    for (const auto& voice : mpeVoices) {
        if (voice.active && voice.noteNumber >= 0 && voice.noteNumber < 128) {
            viz[voice.noteNumber] = voice.glide / globalPitchBendRange;
        }
    }

    return viz;
}

float EchoelSuperIntelligence::getWiseModeActivity() const
{
    if (!wiseModeState.enabled) return 0.0f;

    float activity = 0.0f;

    // Sum of active AI processes
    activity += wiseModeState.keyConfidence * 0.2f;
    activity += wiseModeState.gestureComplexity * 0.2f;
    activity += currentBioState.flowState * 0.3f;
    activity += getQuantumCoherence() * 0.3f;

    return juce::jlimit(0.0f, 1.0f, activity);
}
