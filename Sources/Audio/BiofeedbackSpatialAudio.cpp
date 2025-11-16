/*
  ==============================================================================
   ECHOELMUSIC - Biofeedback Spatial Audio Implementation
  ==============================================================================
*/

#include "BiofeedbackSpatialAudio.h"

namespace Echoelmusic {
namespace Audio {

//==============================================================================
// SpeakerConfig Presets
//==============================================================================

SpeakerConfig SpeakerConfig::createStereo() {
    SpeakerConfig config;
    config.name = "Stereo";
    config.positions = {
        Position3D(-1.0f, 0.0f, 0.0f),  // Left
        Position3D( 1.0f, 0.0f, 0.0f)   // Right
    };
    return config;
}

SpeakerConfig SpeakerConfig::create5_1() {
    SpeakerConfig config;
    config.name = "5.1 Surround";
    config.positions = {
        Position3D(-0.5f, 0.0f,  1.0f),  // Front Left
        Position3D( 0.5f, 0.0f,  1.0f),  // Front Right
        Position3D( 0.0f, 0.0f,  1.0f),  // Center
        Position3D( 0.0f, 0.0f, -1.0f),  // LFE (Subwoofer)
        Position3D(-1.0f, 0.0f, -1.0f),  // Rear Left
        Position3D( 1.0f, 0.0f, -1.0f)   // Rear Right
    };
    return config;
}

SpeakerConfig SpeakerConfig::create7_1() {
    SpeakerConfig config;
    config.name = "7.1 Surround";
    config.positions = {
        Position3D(-0.5f, 0.0f,  1.0f),  // Front Left
        Position3D( 0.5f, 0.0f,  1.0f),  // Front Right
        Position3D( 0.0f, 0.0f,  1.0f),  // Center
        Position3D( 0.0f,-1.0f,  0.0f),  // LFE
        Position3D(-1.0f, 0.0f, -1.0f),  // Rear Left
        Position3D( 1.0f, 0.0f, -1.0f),  // Rear Right
        Position3D(-1.0f, 0.0f,  0.0f),  // Side Left
        Position3D( 1.0f, 0.0f,  0.0f)   // Side Right
    };
    return config;
}

SpeakerConfig SpeakerConfig::createAtmos7_1_4() {
    SpeakerConfig config;
    config.name = "Dolby Atmos 7.1.4";

    // Base 7.1
    config.positions = {
        Position3D(-0.5f, 0.0f,  1.0f),  // Front Left
        Position3D( 0.5f, 0.0f,  1.0f),  // Front Right
        Position3D( 0.0f, 0.0f,  1.0f),  // Center
        Position3D( 0.0f,-1.0f,  0.0f),  // LFE
        Position3D(-1.0f, 0.0f, -1.0f),  // Rear Left
        Position3D( 1.0f, 0.0f, -1.0f),  // Rear Right
        Position3D(-1.0f, 0.0f,  0.0f),  // Side Left
        Position3D( 1.0f, 0.0f,  0.0f),  // Side Right

        // Height channels (4)
        Position3D(-0.5f, 2.0f,  1.0f),  // Top Front Left
        Position3D( 0.5f, 2.0f,  1.0f),  // Top Front Right
        Position3D(-0.5f, 2.0f, -1.0f),  // Top Rear Left
        Position3D( 0.5f, 2.0f, -1.0f)   // Top Rear Right
    };
    return config;
}

SpeakerConfig SpeakerConfig::createFibonacciArray12() {
    SpeakerConfig config;
    config.name = "Fibonacci Field Array (12)";
    config.positions = FibonacciSphereDistribution::generate(12, 3.0f);
    return config;
}

//==============================================================================
// BiofeedbackSpatialAudioEngine Implementation
//==============================================================================

BiofeedbackSpatialAudioEngine::BiofeedbackSpatialAudioEngine() {
    spatialMode = SpatialMode::Stereo;
    speakerConfig = SpeakerConfig::createStereo();
    heartKickEnabled = true;
    heartKickGain = 0.5f;
}

BiofeedbackSpatialAudioEngine::~BiofeedbackSpatialAudioEngine() {
}

//==============================================================================
// Setup
//==============================================================================

void BiofeedbackSpatialAudioEngine::setSampleRate(double sampleRate_) {
    sampleRate = sampleRate_;
    DBG("Spatial audio sample rate: " << sampleRate);
}

void BiofeedbackSpatialAudioEngine::setBufferSize(int bufferSize_) {
    bufferSize = bufferSize_;
}

void BiofeedbackSpatialAudioEngine::setSpatialMode(SpatialMode mode) {
    spatialMode = mode;

    const char* modeName[] = {
        "Stereo", "5.1 Surround", "7.1 Surround", "Dolby Atmos 7.1.4",
        "Binaural", "Ambisonics", "Fibonacci Array (12)", "Custom"
    };
    DBG("Spatial mode set to: " << modeName[(int)mode]);

    // Update speaker config based on mode
    switch (mode) {
        case SpatialMode::Stereo:
            speakerConfig = SpeakerConfig::createStereo();
            break;
        case SpatialMode::Surround_5_1:
            speakerConfig = SpeakerConfig::create5_1();
            break;
        case SpatialMode::Surround_7_1:
            speakerConfig = SpeakerConfig::create7_1();
            break;
        case SpatialMode::Atmos_7_1_4:
            speakerConfig = SpeakerConfig::createAtmos7_1_4();
            break;
        case SpatialMode::AFA_12:
            speakerConfig = SpeakerConfig::createFibonacciArray12();
            break;
        default:
            break;
    }
}

void BiofeedbackSpatialAudioEngine::setSpeakerConfig(const SpeakerConfig& config) {
    speakerConfig = config;
    spatialMode = SpatialMode::Custom;
    DBG("Custom speaker config set: " << config.name);
}

//==============================================================================
// Source Management
//==============================================================================

int BiofeedbackSpatialAudioEngine::addSource(const juce::String& name, const Position3D& position) {
    SpatialSource source;
    source.id = nextSourceId++;
    source.name = name;
    source.position = position;
    source.gain = 1.0f;
    source.spread = 0.0f;
    source.biofeedbackControlled = false;
    source.followBreathing = false;
    source.syncToHeartbeat = false;
    source.eegModulated = false;

    sources.push_back(source);
    DBG("Added spatial source: " << name << " at (" << position.x << ", " << position.y << ", " << position.z << ")");

    return source.id;
}

void BiofeedbackSpatialAudioEngine::removeSource(int sourceId) {
    sources.erase(
        std::remove_if(sources.begin(), sources.end(),
            [sourceId](const SpatialSource& s) { return s.id == sourceId; }),
        sources.end()
    );
}

void BiofeedbackSpatialAudioEngine::setSourcePosition(int sourceId, const Position3D& position) {
    auto* source = getSource(sourceId);
    if (source) {
        source->position = position;
    }
}

void BiofeedbackSpatialAudioEngine::setSourceGain(int sourceId, float gain) {
    auto* source = getSource(sourceId);
    if (source) {
        source->gain = juce::jlimit(0.0f, 2.0f, gain);
    }
}

SpatialSource* BiofeedbackSpatialAudioEngine::getSource(int sourceId) {
    for (auto& source : sources) {
        if (source.id == sourceId)
            return &source;
    }
    return nullptr;
}

//==============================================================================
// Listener Control
//==============================================================================

void BiofeedbackSpatialAudioEngine::setListenerPosition(const Position3D& position) {
    listener.position = position;
}

void BiofeedbackSpatialAudioEngine::setListenerOrientation(float yaw, float pitch, float roll) {
    listener.yaw = yaw;
    listener.pitch = pitch;
    listener.roll = roll;
}

void BiofeedbackSpatialAudioEngine::enableHeadTracking(bool enable) {
    listener.headTrackingEnabled = enable;
    DBG("Head tracking " << (enable ? "enabled" : "disabled"));
}

//==============================================================================
// Biofeedback Integration
//==============================================================================

void BiofeedbackSpatialAudioEngine::updateBreathing(float breathingPhase) {
    currentBreathingPhase = juce::jlimit(0.0f, 1.0f, breathingPhase);
}

void BiofeedbackSpatialAudioEngine::updateHeartbeat(float heartRate, bool beatNow) {
    currentHeartRate = juce::jlimit(40.0f, 200.0f, heartRate);
    heartBeatNow = beatNow;

    if (beatNow && heartKickEnabled) {
        // Reset kick phase to trigger new kick
        heartKickPhase = 0;
    }
}

void BiofeedbackSpatialAudioEngine::updateEEG(float delta, float theta, float alpha, float beta, float gamma) {
    eegBands[0] = delta;
    eegBands[1] = theta;
    eegBands[2] = alpha;
    eegBands[3] = beta;
    eegBands[4] = gamma;
}

void BiofeedbackSpatialAudioEngine::enableBreathingControl(int sourceId, bool enable) {
    auto* source = getSource(sourceId);
    if (source) {
        source->followBreathing = enable;
        source->biofeedbackControlled = enable;
    }
}

void BiofeedbackSpatialAudioEngine::enableHeartbeatSync(int sourceId, bool enable) {
    auto* source = getSource(sourceId);
    if (source) {
        source->syncToHeartbeat = enable;
        source->biofeedbackControlled = enable;
    }
}

void BiofeedbackSpatialAudioEngine::enableEEGModulation(int sourceId, bool enable) {
    auto* source = getSource(sourceId);
    if (source) {
        source->eegModulated = enable;
        source->biofeedbackControlled = enable;
    }
}

//==============================================================================
// Audio Processing
//==============================================================================

void BiofeedbackSpatialAudioEngine::process(const juce::AudioBuffer<float>& input, juce::AudioBuffer<float>& output) {
    output.clear();

    // Process heart kick if enabled
    if (heartKickEnabled && heartKickPhase < sampleRate * 0.5) {
        auto kick = generateHeartKick();
        for (int ch = 0; ch < output.getNumChannels() && ch < kick.getNumChannels(); ++ch) {
            output.addFrom(ch, 0, kick, ch, 0, juce::jmin(kick.getNumSamples(), output.getNumSamples()), heartKickGain);
        }
    }

    // Process all sources
    for (auto& source : sources) {
        processSource(source.id, input, output);
    }
}

void BiofeedbackSpatialAudioEngine::processSource(int sourceId, const juce::AudioBuffer<float>& input, juce::AudioBuffer<float>& output) {
    auto* source = getSource(sourceId);
    if (!source) return;

    Position3D actualPosition = source->position;

    // Apply biofeedback modulation
    if (source->followBreathing) {
        actualPosition = calculateBreathingModulatedPosition(*source);
    }

    float gainMod = 1.0f;
    if (source->syncToHeartbeat) {
        gainMod = calculateHeartbeatGainModulation(*source);
    }

    // Apply spatial panning based on mode
    switch (spatialMode) {
        case SpatialMode::Stereo:
            panSourceStereo(*source, input, output);
            break;
        case SpatialMode::Surround_5_1:
        case SpatialMode::Surround_7_1:
        case SpatialMode::Atmos_7_1_4:
            panSourceSurround(*source, input, output);
            break;
        case SpatialMode::Binaural:
            panSourceBinaural(*source, input, output);
            break;
        case SpatialMode::Ambisonics:
            panSourceAmbisonics(*source, input, output);
            break;
        default:
            break;
    }
}

//==============================================================================
// Heart Kick Generator
//==============================================================================

void BiofeedbackSpatialAudioEngine::enableHeartKick(bool enable) {
    heartKickEnabled = enable;
}

void BiofeedbackSpatialAudioEngine::setHeartKickGain(float gain) {
    heartKickGain = juce::jlimit(0.0f, 1.0f, gain);
}

juce::AudioBuffer<float> BiofeedbackSpatialAudioEngine::generateHeartKick() {
    return HeartKickGenerator::generateKick(sampleRate, 60.0f);
}

//==============================================================================
// Panning Algorithms
//==============================================================================

void BiofeedbackSpatialAudioEngine::panSourceStereo(const SpatialSource& source, const juce::AudioBuffer<float>& input, juce::AudioBuffer<float>& output) {
    if (output.getNumChannels() < 2) return;

    // Simple stereo panning
    float pan = juce::jlimit(-1.0f, 1.0f, source.position.x);  // -1 = left, 1 = right
    float leftGain = std::sqrt((1.0f - pan) / 2.0f) * source.gain;
    float rightGain = std::sqrt((1.0f + pan) / 2.0f) * source.gain;

    // Distance attenuation
    float distance = source.position.distanceTo(listener.position);
    float distanceGain = calculateDistanceGain(source.position, listener.position);
    leftGain *= distanceGain;
    rightGain *= distanceGain;

    for (int i = 0; i < input.getNumSamples(); ++i) {
        float sample = input.getSample(0, i);
        output.addSample(0, i, sample * leftGain);
        output.addSample(1, i, sample * rightGain);
    }
}

void BiofeedbackSpatialAudioEngine::panSourceSurround(const SpatialSource& source, const juce::AudioBuffer<float>& input, juce::AudioBuffer<float>& output) {
    // TODO: Implement surround panning (VBAP - Vector Base Amplitude Panning)
}

void BiofeedbackSpatialAudioEngine::panSourceBinaural(const SpatialSource& source, const juce::AudioBuffer<float>& input, juce::AudioBuffer<float>& output) {
    // TODO: Apply HRTF for binaural rendering
    applyHRTF(source.position, input, output);
}

void BiofeedbackSpatialAudioEngine::panSourceAmbisonics(const SpatialSource& source, const juce::AudioBuffer<float>& input, juce::AudioBuffer<float>& output) {
    // TODO: Implement first-order ambisonics encoding
}

float BiofeedbackSpatialAudioEngine::calculateDistanceGain(const Position3D& sourcePos, const Position3D& listenerPos) {
    float distance = sourcePos.distanceTo(listenerPos);
    if (distance < 0.1f) distance = 0.1f;  // Avoid division by zero

    // Inverse square law
    return 1.0f / (distance * distance);
}

void BiofeedbackSpatialAudioEngine::applyHRTF(const Position3D& sourcePos, const juce::AudioBuffer<float>& input, juce::AudioBuffer<float>& output) {
    // TODO: Implement proper HRTF filtering
    // For now, use simple stereo panning as fallback
}

float BiofeedbackSpatialAudioEngine::calculateDopplerShift(const SpatialSource& source) {
    // TODO: Calculate doppler shift based on source velocity
    return 1.0f;
}

//==============================================================================
// Biofeedback Processing
//==============================================================================

Position3D BiofeedbackSpatialAudioEngine::calculateBreathingModulatedPosition(const SpatialSource& source) {
    Position3D modulated = source.position;

    // Breathing phase: 0.0 (exhale) → 1.0 (inhale)
    // Inhale → closer (z += 2m), Exhale → farther (z -= 2m)
    float zOffset = (currentBreathingPhase - 0.5f) * 4.0f;  // -2m to +2m
    modulated.z += zOffset;

    return modulated;
}

float BiofeedbackSpatialAudioEngine::calculateHeartbeatGainModulation(const SpatialSource& source) {
    // Pulse gain on heartbeat
    if (heartBeatNow) {
        return 1.5f;  // +50% gain boost on beat
    }
    return 1.0f;
}

void BiofeedbackSpatialAudioEngine::applyEEGModulation(const SpatialSource& source, juce::AudioBuffer<float>& buffer) {
    // TODO: Modulate audio based on EEG bands
    // Delta → Bass boost
    // Theta → Mid boost
    // Alpha → High boost
    // Beta → Distortion
    // Gamma → High-frequency modulation
}

} // namespace Audio
} // namespace Echoelmusic
