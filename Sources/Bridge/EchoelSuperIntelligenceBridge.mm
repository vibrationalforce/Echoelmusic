/**
 * EchoelSuperIntelligence Bridge Implementation
 *
 * Objective-C++ implementation connecting:
 * - C++ EchoelSuperIntelligence engine
 * - Swift EchoelUniversalCore
 * - Swift MPEZoneManager
 * - Swift QuantumIntelligenceEngine
 * - C++ BioReactiveModulator
 */

#import <Foundation/Foundation.h>
#import "EchoelSuperIntelligenceBridge.h"
#import "../Instrument/EchoelSuperIntelligence.h"
#import "../BioData/BioReactiveModulator.h"
#import "../Hardware/HardwareSyncManager.h"

//==============================================================================
// Bridge Handle Wrapper
//==============================================================================

struct ESI_Handle
{
    std::unique_ptr<EchoelSuperIntelligence> engine;
    std::unique_ptr<BioReactiveModulator> bioModulator;

    // Cached state for thread safety
    ESI_BioState currentBioState;
    ESI_QuantumState currentQuantumState;
    ESI_WiseModeState currentWiseModeState;

    // Callbacks
    Echoelmusic::BioParameterCallback bioCallback;
    Echoelmusic::QuantumSuggestionCallback quantumCallback;
    Echoelmusic::ScaleDetectionCallback scaleCallback;
    Echoelmusic::GesturePatternCallback gestureCallback;

    ESI_Handle(double sampleRate, int maxBlockSize)
    {
        engine = std::make_unique<EchoelSuperIntelligence>();
        engine->prepare(sampleRate, maxBlockSize);

        bioModulator = std::make_unique<BioReactiveModulator>();

        // Initialize default states
        memset(&currentBioState, 0, sizeof(currentBioState));
        currentBioState.heartRate = 70.0f;
        currentBioState.coherence = 0.5f;

        memset(&currentQuantumState, 0, sizeof(currentQuantumState));
        currentQuantumState.superpositionStrength = 0.5f;
        currentQuantumState.creativity = 0.5f;

        memset(&currentWiseModeState, 0, sizeof(currentWiseModeState));
        currentWiseModeState.learningRate = 0.1f;
        currentWiseModeState.adaptationSpeed = 0.5f;
    }
};

//==============================================================================
// Bridge Initialization
//==============================================================================

void* ESI_Create(double sampleRate, int maxBlockSize)
{
    @autoreleasepool {
        try {
            auto* handle = new ESI_Handle(sampleRate, maxBlockSize);
            NSLog(@"[ESI Bridge] Created EchoelSuperIntelligence engine");
            NSLog(@"[ESI Bridge] Sample rate: %.0f Hz, Block size: %d", sampleRate, maxBlockSize);
            return handle;
        }
        catch (const std::exception& e) {
            NSLog(@"[ESI Bridge] ERROR: Failed to create engine: %s", e.what());
            return nullptr;
        }
    }
}

void ESI_Destroy(void* handle)
{
    @autoreleasepool {
        if (handle) {
            delete static_cast<ESI_Handle*>(handle);
            NSLog(@"[ESI Bridge] Destroyed EchoelSuperIntelligence engine");
        }
    }
}

//==============================================================================
// Bio-Reactive Integration
//==============================================================================

void ESI_UpdateBioData(void* handle, const ESI_BioState* bioState)
{
    if (!handle || !bioState) return;

    auto* h = static_cast<ESI_Handle*>(handle);

    // Cache state
    h->currentBioState = *bioState;

    // Update engine
    EchoelSuperIntelligence::BioState engineBioState;
    engineBioState.heartRate = bioState->heartRate;
    engineBioState.hrv = bioState->hrv;
    engineBioState.coherence = bioState->coherence;
    engineBioState.stress = bioState->stress;
    engineBioState.breathingRate = bioState->breathingRate;
    engineBioState.breathingPhase = bioState->breathingPhase;

    h->engine->setBioState(engineBioState);

    // Process through bio modulator
    BioDataInput::BioDataSample sample;
    sample.heartRate = bioState->heartRate;
    sample.hrv = bioState->hrv;
    sample.coherence = bioState->coherence;
    sample.stressIndex = bioState->stress;
    sample.isValid = true;

    auto modulatedParams = h->bioModulator->process(sample);

    // Invoke callback if set
    if (h->bioCallback) {
        h->bioCallback(
            modulatedParams.filterCutoff,
            modulatedParams.reverbMix,
            modulatedParams.compressionRatio,
            modulatedParams.delayTime
        );
    }
}

void ESI_GetBioModulatedParams(void* handle,
    float* outFilterCutoff,
    float* outReverbMix,
    float* outCompressionRatio,
    float* outDelayTime)
{
    if (!handle) return;

    auto* h = static_cast<ESI_Handle*>(handle);
    auto params = h->bioModulator->getCurrentParameters();

    if (outFilterCutoff) *outFilterCutoff = params.filterCutoff;
    if (outReverbMix) *outReverbMix = params.reverbMix;
    if (outCompressionRatio) *outCompressionRatio = params.compressionRatio;
    if (outDelayTime) *outDelayTime = params.delayTime;
}

//==============================================================================
// MPE Voice Management
//==============================================================================

int ESI_StartMPEVoice(void* handle, int channel, int note, float velocity)
{
    if (!handle) return -1;

    auto* h = static_cast<ESI_Handle*>(handle);

    // Create MPE event
    EchoelSuperIntelligence::MPEEvent event;
    event.type = EchoelSuperIntelligence::MPEEventType::NoteOn;
    event.channel = channel;
    event.note = note;
    event.value = velocity;

    h->engine->processMPEEvent(event);

    // Return voice index (simplified - real implementation tracks voices)
    return (channel * 128 + note) % EchoelSuperIntelligence::kMaxMPEVoices;
}

void ESI_UpdateMPEVoice(void* handle, int voiceIndex,
    float pressure, float slide, float glide)
{
    if (!handle) return;

    auto* h = static_cast<ESI_Handle*>(handle);

    // Extract channel/note from voice index (simplified)
    int channel = voiceIndex / 128;
    int note = voiceIndex % 128;

    // Send pressure (channel aftertouch)
    EchoelSuperIntelligence::MPEEvent pressureEvent;
    pressureEvent.type = EchoelSuperIntelligence::MPEEventType::Pressure;
    pressureEvent.channel = channel;
    pressureEvent.note = note;
    pressureEvent.value = pressure;
    h->engine->processMPEEvent(pressureEvent);

    // Send slide (CC74)
    EchoelSuperIntelligence::MPEEvent slideEvent;
    slideEvent.type = EchoelSuperIntelligence::MPEEventType::Slide;
    slideEvent.channel = channel;
    slideEvent.note = note;
    slideEvent.value = slide;
    h->engine->processMPEEvent(slideEvent);

    // Send glide (pitch bend)
    EchoelSuperIntelligence::MPEEvent glideEvent;
    glideEvent.type = EchoelSuperIntelligence::MPEEventType::PitchBend;
    glideEvent.channel = channel;
    glideEvent.note = note;
    glideEvent.value = glide;
    h->engine->processMPEEvent(glideEvent);
}

void ESI_StopMPEVoice(void* handle, int voiceIndex, float releaseVelocity)
{
    if (!handle) return;

    auto* h = static_cast<ESI_Handle*>(handle);

    int channel = voiceIndex / 128;
    int note = voiceIndex % 128;

    EchoelSuperIntelligence::MPEEvent event;
    event.type = EchoelSuperIntelligence::MPEEventType::NoteOff;
    event.channel = channel;
    event.note = note;
    event.value = releaseVelocity;

    h->engine->processMPEEvent(event);
}

int ESI_GetActiveMPEVoices(void* handle, ESI_MPEVoice* outVoices, int maxVoices)
{
    if (!handle || !outVoices) return 0;

    auto* h = static_cast<ESI_Handle*>(handle);

    int activeCount = 0;

    for (int i = 0; i < EchoelSuperIntelligence::kMaxMPEVoices && activeCount < maxVoices; ++i)
    {
        const auto& voice = h->engine->getMPEVoice(i);
        if (voice.active)
        {
            outVoices[activeCount].channel = voice.channel;
            outVoices[activeCount].note = voice.note;
            outVoices[activeCount].velocity = voice.strikeVelocity;
            outVoices[activeCount].pressure = voice.currentPress;
            outVoices[activeCount].slide = voice.currentSlide;
            outVoices[activeCount].glide = voice.currentGlide;
            outVoices[activeCount].lift = 0.0f;
            outVoices[activeCount].isActive = 1;
            activeCount++;
        }
    }

    return activeCount;
}

//==============================================================================
// Quantum Intelligence Integration
//==============================================================================

void ESI_UpdateQuantumState(void* handle, const ESI_QuantumState* quantumState)
{
    if (!handle || !quantumState) return;

    auto* h = static_cast<ESI_Handle*>(handle);
    h->currentQuantumState = *quantumState;

    // Update engine quantum parameters
    h->engine->setQuantumCreativity(quantumState->creativity);
}

float ESI_GetQuantumVariation(void* handle, int parameterID, float baseValue)
{
    if (!handle) return baseValue;

    auto* h = static_cast<ESI_Handle*>(handle);
    return h->engine->getQuantumVariation(parameterID, baseValue);
}

void ESI_RequestQuantumSuggestion(void* handle, int context, float* outSuggestion)
{
    if (!handle || !outSuggestion) return;

    auto* h = static_cast<ESI_Handle*>(handle);

    // Get quantum suggestion from engine
    auto suggestion = h->engine->getQuantumSuggestion(context);

    // Fill output buffer (8 values)
    for (int i = 0; i < 8; ++i)
    {
        outSuggestion[i] = suggestion.values[i];
    }

    // Invoke callback if set
    if (h->quantumCallback)
    {
        h->quantumCallback(suggestion.type, suggestion.confidence);
    }
}

//==============================================================================
// Wise Mode Control
//==============================================================================

void ESI_SetWiseModeFeature(void* handle, int feature, int enabled)
{
    if (!handle) return;

    auto* h = static_cast<ESI_Handle*>(handle);

    auto wiseModeFeature = static_cast<EchoelSuperIntelligence::WiseModeFeature>(feature);
    h->engine->setWiseModeFeature(wiseModeFeature, enabled != 0);

    // Update cached state
    switch (wiseModeFeature)
    {
        case EchoelSuperIntelligence::WiseModeFeature::PredictiveArticulation:
            h->currentWiseModeState.predictiveEnabled = enabled;
            break;
        case EchoelSuperIntelligence::WiseModeFeature::HarmonicIntelligence:
            h->currentWiseModeState.harmonicEnabled = enabled;
            break;
        case EchoelSuperIntelligence::WiseModeFeature::BioSyncAdaptation:
            h->currentWiseModeState.bioSyncEnabled = enabled;
            break;
        case EchoelSuperIntelligence::WiseModeFeature::GestureMemory:
            h->currentWiseModeState.gestureMemoryEnabled = enabled;
            break;
        case EchoelSuperIntelligence::WiseModeFeature::QuantumCreativity:
            h->currentWiseModeState.quantumCreativityEnabled = enabled;
            break;
        default:
            break;
    }
}

void ESI_GetWiseModeState(void* handle, ESI_WiseModeState* outState)
{
    if (!handle || !outState) return;

    auto* h = static_cast<ESI_Handle*>(handle);
    *outState = h->currentWiseModeState;
}

void ESI_SetWiseModeLearningRate(void* handle, float rate)
{
    if (!handle) return;

    auto* h = static_cast<ESI_Handle*>(handle);
    h->currentWiseModeState.learningRate = rate;
    h->engine->setWiseModeLearningRate(rate);
}

void ESI_DetectScaleAndKey(void* handle, const int* notes, int noteCount)
{
    if (!handle || !notes || noteCount <= 0) return;

    auto* h = static_cast<ESI_Handle*>(handle);

    // Analyze notes to detect scale/key
    std::vector<int> noteVector(notes, notes + noteCount);
    auto detection = h->engine->detectScaleAndKey(noteVector);

    h->currentWiseModeState.detectedKey = detection.key;
    h->currentWiseModeState.detectedScale = detection.scale;

    // Invoke callback if set
    if (h->scaleCallback)
    {
        h->scaleCallback(detection.key, detection.scale);
    }
}

//==============================================================================
// Hardware Controller Integration
//==============================================================================

void ESI_RegisterController(void* handle, const ESI_ControllerInfo* controller)
{
    if (!handle || !controller) return;

    auto* h = static_cast<ESI_Handle*>(handle);

    EchoelSuperIntelligence::HardwareProfile profile;
    profile.controllerType = static_cast<EchoelSuperIntelligence::ControllerType>(controller->controllerType);
    profile.name = controller->name;
    profile.supportsMPE = controller->hasMPE != 0;
    profile.supports5DTouch = controller->has5DTouch != 0;
    profile.supportsAirwave = controller->hasAirwave != 0;
    profile.pitchBendRange = controller->pitchBendRange;

    h->engine->registerHardware(profile);

    NSLog(@"[ESI Bridge] Registered controller: %s (MPE: %d, 5D: %d)",
          controller->name, controller->hasMPE, controller->has5DTouch);
}

void ESI_GetControllerProfile(void* handle, int controllerType,
    float* outPressureCurve, float* outSlideCurve, float* outGlideCurve)
{
    if (!handle) return;

    auto* h = static_cast<ESI_Handle*>(handle);
    auto type = static_cast<EchoelSuperIntelligence::ControllerType>(controllerType);

    auto profile = h->engine->getHardwareProfile(type);

    // Copy response curves (256 points each)
    if (outPressureCurve)
        memcpy(outPressureCurve, profile.pressureResponseCurve.data(), 256 * sizeof(float));
    if (outSlideCurve)
        memcpy(outSlideCurve, profile.slideResponseCurve.data(), 256 * sizeof(float));
    if (outGlideCurve)
        memcpy(outGlideCurve, profile.glideResponseCurve.data(), 256 * sizeof(float));
}

int ESI_IsControllerSupported(int controllerType)
{
    // All current and future controllers are supported
    return controllerType >= 0 && controllerType <= 25;
}

//==============================================================================
// Audio Processing
//==============================================================================

void ESI_ProcessBlock(void* handle, float* leftChannel, float* rightChannel, int numSamples)
{
    if (!handle || !leftChannel || !rightChannel) return;

    auto* h = static_cast<ESI_Handle*>(handle);

    juce::AudioBuffer<float> buffer(2, numSamples);
    buffer.copyFrom(0, 0, leftChannel, numSamples);
    buffer.copyFrom(1, 0, rightChannel, numSamples);

    h->engine->process(buffer);

    buffer.copyTo(0, 0, leftChannel, numSamples);
    buffer.copyTo(1, 0, rightChannel, numSamples);
}

void ESI_ProcessMIDI(void* handle, const unsigned char* midiData, int dataSize, int sampleOffset)
{
    if (!handle || !midiData || dataSize < 1) return;

    auto* h = static_cast<ESI_Handle*>(handle);

    juce::MidiMessage message(midiData, dataSize);
    h->engine->processMIDIMessage(message, sampleOffset);
}

//==============================================================================
// EchoelUniversalCore Integration
//==============================================================================

void ESI_ReceiveUniversalState(void* handle,
    float coherence, float energy, float flow, float creativity)
{
    if (!handle) return;

    auto* h = static_cast<ESI_Handle*>(handle);

    // Update engine with universal state
    h->engine->setUniversalState(coherence, energy, flow, creativity);
}

void ESI_GetStateForUniversalCore(void* handle,
    float* outCoherence, float* outEnergy, float* outCreativity)
{
    if (!handle) return;

    auto* h = static_cast<ESI_Handle*>(handle);

    auto state = h->engine->getEngineState();

    if (outCoherence) *outCoherence = state.coherence;
    if (outEnergy) *outEnergy = state.energy;
    if (outCreativity) *outCreativity = state.creativity;
}

//==============================================================================
// Preset Management
//==============================================================================

static const char* presetNames[] = {
    "Pure Instrument",
    "Seaboard Expressive",
    "Meditative Flow",
    "Quantum Explorer",
    "Bio-Reactive",
    "Gesture Artist",
    "Harmonic Wise",
    "Breath Sync",
    "Neural Link",
    "Cosmic Voyager",
    "Inner Journey",
    "Collective Consciousness"
};

void ESI_LoadPreset(void* handle, ESI_Preset preset)
{
    if (!handle) return;

    auto* h = static_cast<ESI_Handle*>(handle);

    auto enginePreset = static_cast<EchoelSuperIntelligence::IntelligencePreset>(preset);
    h->engine->loadPreset(enginePreset);

    NSLog(@"[ESI Bridge] Loaded preset: %s", presetNames[preset]);
}

const char* ESI_GetPresetName(ESI_Preset preset)
{
    if (preset >= 0 && preset < sizeof(presetNames) / sizeof(presetNames[0]))
        return presetNames[preset];
    return "Unknown";
}

//==============================================================================
// State Serialization
//==============================================================================

int ESI_SerializeState(void* handle, char* buffer, int bufferSize)
{
    if (!handle) return 0;

    auto* h = static_cast<ESI_Handle*>(handle);

    juce::MemoryOutputStream stream;
    h->engine->saveState(stream);

    int dataSize = static_cast<int>(stream.getDataSize());

    if (buffer && bufferSize >= dataSize)
    {
        memcpy(buffer, stream.getData(), dataSize);
    }

    return dataSize;
}

int ESI_DeserializeState(void* handle, const char* buffer, int bufferSize)
{
    if (!handle || !buffer || bufferSize <= 0) return 0;

    auto* h = static_cast<ESI_Handle*>(handle);

    juce::MemoryInputStream stream(buffer, bufferSize, false);
    return h->engine->loadState(stream) ? 1 : 0;
}

//==============================================================================
// C++ Callbacks
//==============================================================================

namespace Echoelmusic {

void ESI_SetBioParameterCallback(void* handle, BioParameterCallback callback)
{
    if (!handle) return;
    static_cast<ESI_Handle*>(handle)->bioCallback = std::move(callback);
}

void ESI_SetQuantumSuggestionCallback(void* handle, QuantumSuggestionCallback callback)
{
    if (!handle) return;
    static_cast<ESI_Handle*>(handle)->quantumCallback = std::move(callback);
}

void ESI_SetScaleDetectionCallback(void* handle, ScaleDetectionCallback callback)
{
    if (!handle) return;
    static_cast<ESI_Handle*>(handle)->scaleCallback = std::move(callback);
}

void ESI_SetGesturePatternCallback(void* handle, GesturePatternCallback callback)
{
    if (!handle) return;
    static_cast<ESI_Handle*>(handle)->gestureCallback = std::move(callback);
}

} // namespace Echoelmusic
