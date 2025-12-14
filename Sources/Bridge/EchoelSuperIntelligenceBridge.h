/**
 * ╔═══════════════════════════════════════════════════════════════════════════╗
 * ║           ECHOEL SUPER INTELLIGENCE - SWIFT/C++ BRIDGE                     ║
 * ║                                                                            ║
 * ║     Unified integration layer connecting all Echoelmusic systems          ║
 * ║                                                                            ║
 * ╚═══════════════════════════════════════════════════════════════════════════╝
 *
 * This bridge connects the C++ EchoelSuperIntelligence engine with:
 * - EchoelUniversalCore (Swift) - Master integration hub
 * - MPEZoneManager (Swift) - MPE voice allocation
 * - QuantumIntelligenceEngine (Swift) - Quantum-inspired algorithms
 * - BioReactiveModulator (C++) - Bio-data processing
 * - HardwareSyncManager (C++) - Hardware synchronization
 *
 * Integration Architecture:
 *
 *     ┌────────────────────────────────────────────────────────────────┐
 *     │                    SWIFT LAYER                                 │
 *     │  ┌──────────────────┐  ┌─────────────────┐  ┌────────────────┐│
 *     │  │EchoelUniversalCore│  │ MPEZoneManager  │  │QuantumEngine   ││
 *     │  └────────┬─────────┘  └───────┬─────────┘  └───────┬────────┘│
 *     └───────────┼────────────────────┼────────────────────┼─────────┘
 *                 │                    │                    │
 *     ┌───────────▼────────────────────▼────────────────────▼─────────┐
 *     │              ECHOEL SUPER INTELLIGENCE BRIDGE                  │
 *     │                 (Objective-C++ / C Interface)                  │
 *     └───────────┬────────────────────┬────────────────────┬─────────┘
 *                 │                    │                    │
 *     ┌───────────▼────────────────────▼────────────────────▼─────────┐
 *     │                    C++ LAYER                                   │
 *     │  ┌──────────────────┐  ┌─────────────────┐  ┌────────────────┐│
 *     │  │SuperIntelligence │  │BioReactiveModulator│ │HardwareSyncMgr││
 *     │  └──────────────────┘  └─────────────────┘  └────────────────┘│
 *     └────────────────────────────────────────────────────────────────┘
 */

#pragma once

#ifdef __cplusplus
extern "C" {
#endif

//==============================================================================
// Bio State Structure (C-compatible)
//==============================================================================

typedef struct {
    float heartRate;          // BPM (60-180)
    float hrv;                // Heart Rate Variability (0-1 normalized)
    float coherence;          // HeartMath coherence (0-1)
    float stress;             // Stress index (0-1, inverted coherence)
    float breathingRate;      // Breaths per minute
    float breathingPhase;     // Current breathing phase (0-1)
    float skinConductance;    // GSR (0-1)
    float temperature;        // Relative skin temperature
} ESI_BioState;

//==============================================================================
// MPE Voice Structure (C-compatible)
//==============================================================================

typedef struct {
    int channel;              // MIDI channel (0-15)
    int note;                 // MIDI note (0-127)
    float velocity;           // Strike velocity (0-1)
    float pressure;           // Current pressure (0-1)
    float slide;              // Y-axis position (0-1)
    float glide;              // Pitch bend (-1 to +1)
    float lift;               // Release velocity (0-1)
    int isActive;             // Voice active flag
} ESI_MPEVoice;

//==============================================================================
// Quantum State Structure (C-compatible)
//==============================================================================

typedef struct {
    float superpositionStrength;  // Quantum superposition (0-1)
    float entanglementStrength;   // Entanglement with other systems (0-1)
    float creativity;             // Quantum-derived creativity (0-1)
    float coherenceTime;          // Simulated coherence time (microseconds)
    int quantumMode;              // 0=Classical, 1=Hybrid, 2=Simulation
} ESI_QuantumState;

//==============================================================================
// Hardware Controller Info (C-compatible)
//==============================================================================

typedef struct {
    int controllerType;           // ControllerType enum value
    char name[64];                // Controller name
    int hasMPE;                   // MPE capable
    int has5DTouch;               // ROLI 5D Touch
    int hasAirwave;               // Gesture control
    int pitchBendRange;           // Semitones (typically 48 for Seaboard)
    int firmwareVersion;          // Firmware version * 100
} ESI_ControllerInfo;

//==============================================================================
// Wise Mode State (C-compatible)
//==============================================================================

typedef struct {
    int predictiveEnabled;
    int harmonicEnabled;
    int bioSyncEnabled;
    int gestureMemoryEnabled;
    int quantumCreativityEnabled;
    float learningRate;           // AI learning rate (0-1)
    float adaptationSpeed;        // How fast to adapt (0-1)
    int detectedScale;            // Current detected scale
    int detectedKey;              // Current detected key (0-11)
} ESI_WiseModeState;

//==============================================================================
// Bridge Initialization
//==============================================================================

/**
 * Initialize the Super Intelligence engine
 * @param sampleRate Audio sample rate
 * @param maxBlockSize Maximum audio buffer size
 * @return Handle to the engine instance (NULL on failure)
 */
void* ESI_Create(double sampleRate, int maxBlockSize);

/**
 * Destroy the Super Intelligence engine
 * @param handle Engine handle from ESI_Create
 */
void ESI_Destroy(void* handle);

//==============================================================================
// Bio-Reactive Integration
//==============================================================================

/**
 * Update bio-data from HealthKit/wearables
 * Called from Swift HealthKitManager
 */
void ESI_UpdateBioData(void* handle, const ESI_BioState* bioState);

/**
 * Get current bio-modulated parameters
 */
void ESI_GetBioModulatedParams(void* handle,
    float* outFilterCutoff,
    float* outReverbMix,
    float* outCompressionRatio,
    float* outDelayTime);

//==============================================================================
// MPE Voice Management
//==============================================================================

/**
 * Start MPE voice (called from MPEZoneManager)
 * @return Voice index or -1 on failure
 */
int ESI_StartMPEVoice(void* handle, int channel, int note, float velocity);

/**
 * Update MPE voice expression
 */
void ESI_UpdateMPEVoice(void* handle, int voiceIndex,
    float pressure, float slide, float glide);

/**
 * Stop MPE voice
 */
void ESI_StopMPEVoice(void* handle, int voiceIndex, float releaseVelocity);

/**
 * Get all active MPE voices
 */
int ESI_GetActiveMPEVoices(void* handle, ESI_MPEVoice* outVoices, int maxVoices);

//==============================================================================
// Quantum Intelligence Integration
//==============================================================================

/**
 * Update quantum state from QuantumIntelligenceEngine
 */
void ESI_UpdateQuantumState(void* handle, const ESI_QuantumState* quantumState);

/**
 * Get quantum-derived variation for a parameter
 * @param parameterID Parameter to vary
 * @param baseValue Base value
 * @return Varied value
 */
float ESI_GetQuantumVariation(void* handle, int parameterID, float baseValue);

/**
 * Request quantum creative suggestion
 * @param context Current creative context
 * @param outSuggestion Output suggestion buffer
 */
void ESI_RequestQuantumSuggestion(void* handle, int context, float* outSuggestion);

//==============================================================================
// Wise Mode Control
//==============================================================================

/**
 * Enable/disable Wise Mode features
 */
void ESI_SetWiseModeFeature(void* handle, int feature, int enabled);

/**
 * Get current Wise Mode state
 */
void ESI_GetWiseModeState(void* handle, ESI_WiseModeState* outState);

/**
 * Set Wise Mode learning rate
 */
void ESI_SetWiseModeLearningRate(void* handle, float rate);

/**
 * Trigger Wise Mode scale/key detection
 */
void ESI_DetectScaleAndKey(void* handle, const int* notes, int noteCount);

//==============================================================================
// Hardware Controller Integration
//==============================================================================

/**
 * Register detected hardware controller
 */
void ESI_RegisterController(void* handle, const ESI_ControllerInfo* controller);

/**
 * Get optimized profile for controller
 */
void ESI_GetControllerProfile(void* handle, int controllerType,
    float* outPressureCurve, float* outSlideCurve, float* outGlideCurve);

/**
 * Check if controller is supported
 */
int ESI_IsControllerSupported(int controllerType);

//==============================================================================
// Audio Processing
//==============================================================================

/**
 * Process audio block
 */
void ESI_ProcessBlock(void* handle, float* leftChannel, float* rightChannel, int numSamples);

/**
 * Process MIDI events
 */
void ESI_ProcessMIDI(void* handle, const unsigned char* midiData, int dataSize, int sampleOffset);

//==============================================================================
// EchoelUniversalCore Integration
//==============================================================================

/**
 * Receive system state from EchoelUniversalCore
 */
void ESI_ReceiveUniversalState(void* handle,
    float coherence, float energy, float flow, float creativity);

/**
 * Send state update to EchoelUniversalCore
 */
void ESI_GetStateForUniversalCore(void* handle,
    float* outCoherence, float* outEnergy, float* outCreativity);

//==============================================================================
// Preset Management
//==============================================================================

typedef enum {
    ESI_Preset_PureInstrument = 0,
    ESI_Preset_SeaboardExpressive,
    ESI_Preset_MeditativeFlow,
    ESI_Preset_QuantumExplorer,
    ESI_Preset_BioReactive,
    ESI_Preset_GestureArtist,
    ESI_Preset_HarmonicWise,
    ESI_Preset_BreathSync,
    ESI_Preset_NeuralLink,
    ESI_Preset_CosmicVoyager,
    ESI_Preset_InnerJourney,
    ESI_Preset_CollectiveConsciousness
} ESI_Preset;

/**
 * Load preset
 */
void ESI_LoadPreset(void* handle, ESI_Preset preset);

/**
 * Get preset name
 */
const char* ESI_GetPresetName(ESI_Preset preset);

//==============================================================================
// State Serialization
//==============================================================================

/**
 * Serialize engine state to buffer
 * @return Size of serialized data, or required buffer size if buffer is NULL
 */
int ESI_SerializeState(void* handle, char* buffer, int bufferSize);

/**
 * Deserialize engine state from buffer
 */
int ESI_DeserializeState(void* handle, const char* buffer, int bufferSize);

#ifdef __cplusplus
}
#endif

//==============================================================================
// C++ Only - Swift Callback Types
//==============================================================================

#ifdef __cplusplus

#include <functional>

namespace Echoelmusic {

/**
 * Callback when bio-modulated parameters change
 */
using BioParameterCallback = std::function<void(float filterCutoff, float reverbMix,
                                                 float compression, float delay)>;

/**
 * Callback when quantum suggestion is generated
 */
using QuantumSuggestionCallback = std::function<void(int suggestionType, float confidence)>;

/**
 * Callback when Wise Mode detects scale/key
 */
using ScaleDetectionCallback = std::function<void(int key, int scale)>;

/**
 * Callback when gesture memory pattern is detected
 */
using GesturePatternCallback = std::function<void(int patternID, float confidence)>;

/**
 * Set callbacks for Swift integration
 */
void ESI_SetBioParameterCallback(void* handle, BioParameterCallback callback);
void ESI_SetQuantumSuggestionCallback(void* handle, QuantumSuggestionCallback callback);
void ESI_SetScaleDetectionCallback(void* handle, ScaleDetectionCallback callback);
void ESI_SetGesturePatternCallback(void* handle, GesturePatternCallback callback);

} // namespace Echoelmusic

#endif // __cplusplus
