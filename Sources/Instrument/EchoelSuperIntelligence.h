#pragma once

#include "UltraSampler.h"
#include <JuceHeader.h>
#include <array>
#include <vector>
#include <memory>
#include <atomic>
#include <map>
#include <functional>
#include <random>

/**
 * ╔═══════════════════════════════════════════════════════════════════════════╗
 * ║                    ECHOEL SUPER INTELLIGENCE                               ║
 * ║                                                                            ║
 * ║     "Where Bio-Reactive Sound Meets Quantum Creativity"                   ║
 * ║                                                                            ║
 * ╚═══════════════════════════════════════════════════════════════════════════╝
 *
 * The Ultimate MPE-Ready Instrument for Echoelmusic
 *
 * ══════════════════════════════════════════════════════════════════════════════
 *                           WISE MODE™
 * ══════════════════════════════════════════════════════════════════════════════
 *
 * Wise Mode is Echoelmusic's proprietary AI-powered intelligent assistance:
 *
 * • PREDICTIVE ARTICULATION - Learns your playing style and anticipates
 *   expression, pre-loading samples and adjusting parameters before you play
 *
 * • HARMONIC INTELLIGENCE - Suggests complementary notes, auto-harmonizes,
 *   and prevents dissonance based on detected key/scale
 *
 * • BIO-SYNC ADAPTATION - Continuously adjusts timbre, response, and dynamics
 *   based on your heart rate variability and coherence state
 *
 * • GESTURE MEMORY - Remembers your favorite MPE gestures and creates
 *   personalized response curves
 *
 * • QUANTUM CREATIVITY - Uses quantum-inspired algorithms for generative
 *   variation, ensuring every performance is unique yet coherent
 *
 * ══════════════════════════════════════════════════════════════════════════════
 *                     UNIVERSAL HARDWARE SUPPORT
 * ══════════════════════════════════════════════════════════════════════════════
 *
 * CURRENT MPE CONTROLLERS:
 * • ROLI Seaboard RISE/RISE 2 (5D Touch: Strike, Glide, Slide, Press, Lift)
 * • ROLI Lumi Keys
 * • ROLI Airwave (gesture control)
 * • Sensel Morph
 * • Linnstrument 128/200
 * • Continuum Fingerboard
 * • Osmose by Expressive E
 * • Erae Touch
 * • Joué Play/Pro
 * • Keith McMillen K-Board Pro 4
 * • Madrona Labs Soundplane
 *
 * CLASSIC CONTROLLERS:
 * • Standard MIDI keyboards (any manufacturer)
 * • Aftertouch-enabled keyboards
 * • Breath controllers (TEControl, Akai EWI)
 * • Guitar MIDI (Fishman TriplePlay, MIDI Guitar 2)
 * • Drum pads (Akai MPC, Native Instruments Maschine)
 * • DJ controllers (mapped to parameters)
 *
 * FUTURE HARDWARE:
 * • Neural interface devices (BCI)
 * • Spatial gesture controllers (Leap Motion, ultrasonics)
 * • Haptic feedback controllers
 * • AI co-pilot controllers
 * • Biometric wearables (direct HRV input)
 * • VR/AR motion controllers
 *
 * ══════════════════════════════════════════════════════════════════════════════
 *                        ARCHITECTURE
 * ══════════════════════════════════════════════════════════════════════════════
 *
 *                    ┌─────────────────────────────┐
 *                    │    WISE MODE AI ENGINE      │
 *                    │  ┌─────────┐ ┌──────────┐  │
 *                    │  │Predictive│ │ Harmonic │  │
 *                    │  │   AI    │ │  Intel   │  │
 *                    │  └────┬────┘ └────┬─────┘  │
 *                    │       │           │        │
 *                    │  ┌────▼───────────▼────┐   │
 *                    │  │   Quantum Sampler   │   │
 *                    │  └────────┬────────────┘   │
 *                    └───────────┼────────────────┘
 *                                │
 *     ┌──────────────────────────┼──────────────────────────┐
 *     │                          │                          │
 *     ▼                          ▼                          ▼
 * ┌────────┐              ┌────────────┐              ┌──────────┐
 * │  MPE   │              │    BIO     │              │ HARDWARE │
 * │ ENGINE │◄────────────►│  REACTOR   │◄────────────►│   HAL    │
 * └───┬────┘              └─────┬──────┘              └────┬─────┘
 *     │                         │                          │
 *     │    ┌────────────────────┼────────────────────┐    │
 *     │    │                    │                    │    │
 *     ▼    ▼                    ▼                    ▼    ▼
 * ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────────────┐
 * │ Seaboard │  │ Airwave  │  │HealthKit │  │ Future Hardware  │
 * │ 5D Touch │  │ Gesture  │  │   HRV    │  │ Neural/Spatial   │
 * └──────────┘  └──────────┘  └──────────┘  └──────────────────┘
 */
class EchoelSuperIntelligence
{
public:
    //==========================================================================
    // Constants
    //==========================================================================

    static constexpr int kMaxMPEChannels = 16;
    static constexpr int kMaxMPEVoices = 48;
    static constexpr int kGestureHistorySize = 256;
    static constexpr int kHarmonicContextSize = 12;
    static constexpr int kQuantumStates = 64;

    //==========================================================================
    // MPE Dimensions (ROLI 5D Touch Compatible)
    //==========================================================================

    enum class MPEDimension
    {
        Strike,      // Initial velocity (Note On velocity)
        Press,       // Continuous pressure (Channel Pressure / Poly AT)
        Slide,       // Y-axis position (CC74)
        Glide,       // X-axis / Pitch bend
        Lift         // Release velocity (Note Off velocity)
    };

    //==========================================================================
    // Wise Mode Features
    //==========================================================================

    enum class WiseModeFeature
    {
        PredictiveArticulation,
        HarmonicIntelligence,
        BioSyncAdaptation,
        GestureMemory,
        QuantumCreativity,
        AutoExpression,
        ScaleAwareness,
        DynamicTimbre,
        BreathSync,
        EmotionMapping
    };

    //==========================================================================
    // Hardware Controller Types
    //==========================================================================

    enum class ControllerType
    {
        Unknown,

        // MPE Controllers (Current)
        ROLISeaboard,
        ROLISeaboard2,
        ROLILumi,
        ROLIAirwave,
        SenselMorph,
        Linnstrument,
        ContinuumFingerboard,
        ExpressiveEOsmose,
        EraeTouch,
        JouePlay,
        KeithMcMillenKBoard,
        MadronaLabsSoundplane,

        // Classic Controllers
        StandardMIDI,
        AftertouchKeyboard,
        BreathController,
        GuitarMIDI,
        DrumPad,
        DJController,

        // Future Hardware
        NeuralInterface,
        SpatialGesture,
        HapticController,
        AICoilot,
        BiometricWearable,
        VRMotionController,
        ARGlassController,

        // Echoelmusic Proprietary
        EchoelBioSensor,
        EchoelQuantumPad
    };

    //==========================================================================
    // MPE Voice Structure
    //==========================================================================

    struct MPEVoice
    {
        bool active = false;
        int channel = 0;           // MPE channel (1-15 for member channels)
        int noteNumber = 0;
        float strike = 0.0f;       // Initial velocity
        float press = 0.0f;        // Current pressure
        float slide = 0.0f;        // Y-axis (0-1)
        float glide = 0.0f;        // Pitch bend (-1 to +1, in semitones)
        float lift = 0.0f;         // Release velocity

        // Extended MPE (future-proof)
        float dimension6 = 0.0f;   // Reserved for future controllers
        float dimension7 = 0.0f;
        float dimension8 = 0.0f;

        // Gesture history for Wise Mode
        std::array<float, 64> pressHistory;
        std::array<float, 64> slideHistory;
        std::array<float, 64> glideHistory;
        int historyIndex = 0;

        // Bio-sync state
        float bioInfluence = 0.0f;
        float coherenceLevel = 0.0f;

        // AI predictions
        float predictedNextPress = 0.0f;
        float predictedRelease = 0.0f;

        MPEVoice() {
            pressHistory.fill(0.0f);
            slideHistory.fill(0.0f);
            glideHistory.fill(0.0f);
        }
    };

    //==========================================================================
    // Hardware Abstraction Layer (HAL)
    //==========================================================================

    struct HardwareProfile
    {
        ControllerType type = ControllerType::Unknown;
        juce::String name;
        juce::String manufacturer;

        // Capabilities
        bool supportsMPE = false;
        bool supportsPolyAT = false;
        bool supportsChannelAT = false;
        bool supportsSlide = false;        // Y-axis (CC74)
        bool supportsBreath = false;       // CC2
        bool supportsExpression = false;   // CC11
        bool supports14Bit = false;        // High-resolution CCs
        bool supportsNRPN = false;

        // MPE Configuration
        int mpeLowerZone = 1;              // First member channel
        int mpeUpperZone = 15;             // Last member channel
        float pitchBendRange = 48.0f;      // Semitones (Seaboard default)
        float slideRange = 1.0f;           // 0-1 normalized

        // Response curves
        float velocityCurve = 1.0f;        // 0.5 = soft, 2.0 = hard
        float pressureCurve = 1.0f;
        float slideCurve = 1.0f;

        // Physical dimensions (for gesture scaling)
        float keyWidth = 1.0f;             // Relative key width
        float slideHeight = 1.0f;          // Y-axis range in mm

        // Custom mappings
        std::map<int, int> ccMapping;      // CC# -> internal param
    };

    //==========================================================================
    // Wise Mode AI State
    //==========================================================================

    struct WiseModeState
    {
        bool enabled = false;
        float intelligenceLevel = 0.5f;    // 0 = minimal, 1 = full AI

        // Harmonic Intelligence
        int detectedKey = 0;               // 0-11 (C-B)
        int detectedScale = 0;             // 0 = major, 1 = minor, etc.
        float keyConfidence = 0.0f;
        std::array<float, 12> noteWeights; // Probability of each pitch class
        std::array<int, 8> suggestedNotes; // AI-suggested harmony

        // Predictive Articulation
        float predictedDynamics = 0.5f;
        float predictedTimbre = 0.5f;
        float playingIntensity = 0.5f;
        float gestureComplexity = 0.0f;

        // Bio-Sync
        float bioResonance = 0.5f;         // How well sound matches bio-state
        float targetCoherence = 0.7f;      // Desired coherence level
        float adaptationRate = 0.1f;

        // Quantum Creativity
        std::array<float, kQuantumStates> quantumAmplitudes;
        float quantumEntropy = 0.5f;
        float variationAmount = 0.2f;

        // Learning
        int totalNotesPlayed = 0;
        float averageVelocity = 0.0f;
        float averageDuration = 0.0f;
        std::array<int, 12> noteHistogram;

        WiseModeState() {
            noteWeights.fill(1.0f / 12.0f);
            suggestedNotes.fill(-1);
            quantumAmplitudes.fill(1.0f / kQuantumStates);
            noteHistogram.fill(0);
        }
    };

    //==========================================================================
    // Gesture Recognition
    //==========================================================================

    struct GesturePattern
    {
        juce::String name;
        std::vector<float> pressProfile;
        std::vector<float> slideProfile;
        std::vector<float> glideProfile;
        float matchThreshold = 0.8f;

        // Response mapping
        std::function<void(float intensity)> onRecognized;
    };

    //==========================================================================
    // Bio-Reactive Integration
    //==========================================================================

    struct BioState
    {
        float hrv = 0.5f;                  // Heart rate variability (0-1)
        float coherence = 0.5f;            // HeartMath coherence (0-1)
        float heartRate = 70.0f;           // BPM
        float breathRate = 12.0f;          // Breaths per minute
        float skinConductance = 0.5f;      // GSR (future)
        float eegAlpha = 0.5f;             // Brain alpha waves (future)
        float eegTheta = 0.5f;             // Brain theta waves (future)
        float emotionValence = 0.5f;       // Positive/negative (-1 to 1)
        float emotionArousal = 0.5f;       // Calm/excited (0 to 1)

        // Derived metrics
        float stressLevel = 0.3f;
        float focusLevel = 0.5f;
        float flowState = 0.0f;            // 0-1 (in "the zone")

        // Trends
        float hrvTrend = 0.0f;             // Rising/falling
        float coherenceTrend = 0.0f;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    EchoelSuperIntelligence();
    ~EchoelSuperIntelligence() = default;

    //==========================================================================
    // Initialization
    //==========================================================================

    void prepare(double sampleRate, int maxBlockSize);
    void reset();

    //==========================================================================
    // Hardware Detection & Configuration
    //==========================================================================

    /** Auto-detect connected controller */
    ControllerType detectController(const juce::MidiMessage& msg);

    /** Set controller profile */
    void setControllerProfile(const HardwareProfile& profile);

    /** Get current controller profile */
    const HardwareProfile& getControllerProfile() const { return currentProfile; }

    /** Configure MPE zones */
    void configureMPE(int lowerZone, int upperZone, float pitchBendRange);

    /** Set response curve */
    void setVelocityCurve(float curve);
    void setPressureCurve(float curve);
    void setSlideCurve(float curve);

    //==========================================================================
    // ROLI Seaboard Specific
    //==========================================================================

    /** Configure Seaboard 5D Touch response */
    void configureSeaboard(float strikeResponse, float glideResponse,
                          float slideResponse, float pressResponse);

    /** Enable/disable Seaboard-specific features */
    void setSeaboardGlideMode(bool absolute);  // Absolute vs relative pitch
    void setSeaboardSlideCC(int cc);           // Usually CC74

    //==========================================================================
    // ROLI Airwave Support
    //==========================================================================

    /** Configure Airwave gesture mapping */
    void configureAirwave(bool enableGestures, float sensitivity);

    /** Set Airwave gesture to parameter mapping */
    void mapAirwaveGesture(int gestureType, int parameter, float amount);

    //==========================================================================
    // Wise Mode Control
    //==========================================================================

    /** Enable/disable Wise Mode */
    void setWiseModeEnabled(bool enabled);
    bool isWiseModeEnabled() const { return wiseModeState.enabled; }

    /** Set intelligence level (0-1) */
    void setIntelligenceLevel(float level);

    /** Enable specific Wise Mode features */
    void setWiseModeFeature(WiseModeFeature feature, bool enabled);

    /** Get AI-suggested notes for harmony */
    std::array<int, 8> getSuggestedHarmony() const;

    /** Get predicted next note */
    int getPredictedNextNote() const;

    /** Get optimal timbre setting based on playing */
    float getOptimalTimbre() const;

    /** Manual scale/key lock */
    void setScaleLock(int key, int scale, bool enabled);

    //==========================================================================
    // Bio-Reactive Integration
    //==========================================================================

    /** Update bio-state from HealthKit or sensors */
    void setBioState(const BioState& state);

    /** Set bio-reactive influence amount */
    void setBioInfluence(float amount);

    /** Get current bio-resonance score */
    float getBioResonance() const;

    /** Enable breath sync mode */
    void setBreathSyncEnabled(bool enabled);

    /** Set target coherence for adaptive response */
    void setTargetCoherence(float coherence);

    //==========================================================================
    // MPE Input Processing
    //==========================================================================

    /** Process incoming MIDI (auto-detects MPE) */
    void processMidiMessage(const juce::MidiMessage& msg);

    /** Process full MIDI buffer */
    void processMidiBuffer(const juce::MidiBuffer& buffer);

    /** Get MPE voice state */
    const MPEVoice& getMPEVoice(int index) const { return mpeVoices[index]; }

    /** Get active MPE voice count */
    int getActiveMPEVoiceCount() const;

    //==========================================================================
    // Gesture Recognition
    //==========================================================================

    /** Register custom gesture pattern */
    void registerGesture(const GesturePattern& pattern);

    /** Clear all registered gestures */
    void clearGestures();

    /** Get last recognized gesture */
    juce::String getLastRecognizedGesture() const;

    //==========================================================================
    // Quantum Creativity
    //==========================================================================

    /** Generate quantum variation for parameter */
    float getQuantumVariation(int paramIndex);

    /** Set quantum entropy (randomness level) */
    void setQuantumEntropy(float entropy);

    /** Collapse quantum state (deterministic output) */
    void collapseQuantumState();

    /** Get current quantum coherence */
    float getQuantumCoherence() const;

    //==========================================================================
    // Sound Engine Integration
    //==========================================================================

    /** Get underlying UltraSampler */
    UltraSampler& getSampler() { return sampler; }
    const UltraSampler& getSampler() const { return sampler; }

    /** Process audio with full MPE/Wise Mode */
    void processBlock(juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midiMessages);

    //==========================================================================
    // Presets
    //==========================================================================

    enum class IntelligencePreset
    {
        // Performance Modes
        PureInstrument,           // No AI, direct response
        SubtleAssist,             // Gentle AI guidance
        FullWisdom,               // Maximum AI integration

        // Controller-Specific
        SeaboardExpressive,       // Optimized for Seaboard
        LinnstrumentGrid,         // Optimized for Linnstrument
        OsmoseAftertouch,         // Optimized for Osmose
        ContinuumGlide,           // Optimized for Continuum

        // Bio-Reactive Modes
        MeditativeFlow,           // Calm, coherence-seeking
        EnergeticPerformance,     // High-energy response
        BreathingSpace,           // Breath-synced

        // Creative Modes
        QuantumExplorer,          // Maximum variation
        HarmonicGuide,            // Strong harmonic suggestions
        GestureArtist             // Gesture-focused
    };

    void loadPreset(IntelligencePreset preset);

    //==========================================================================
    // Analytics & Visualization
    //==========================================================================

    /** Get playing statistics */
    struct PlayingStats
    {
        int totalNotes = 0;
        float averageVelocity = 0.0f;
        float averageDuration = 0.0f;
        float expressionRange = 0.0f;
        float slideUsage = 0.0f;
        float glideUsage = 0.0f;
        float pressUsage = 0.0f;
        int detectedKey = 0;
        float keyConfidence = 0.0f;
        float flowStateLevel = 0.0f;
    };

    PlayingStats getPlayingStats() const;

    /** Get MPE dimension visualization data */
    std::array<float, 128> getPressVisualization() const;
    std::array<float, 128> getSlideVisualization() const;
    std::array<float, 128> getGlideVisualization() const;

    /** Get Wise Mode activity visualization */
    float getWiseModeActivity() const;

private:
    //==========================================================================
    // Internal State
    //==========================================================================

    double sampleRate = 48000.0;
    int blockSize = 512;

    // Sound engine
    UltraSampler sampler;

    // MPE State
    std::array<MPEVoice, kMaxMPEVoices> mpeVoices;
    HardwareProfile currentProfile;
    bool mpeEnabled = true;
    int mpeLowerZone = 1;
    int mpeUpperZone = 15;
    float globalPitchBendRange = 48.0f;

    // Wise Mode
    WiseModeState wiseModeState;
    std::array<bool, 10> wiseModeFeatures;  // Feature toggles

    // Bio State
    BioState currentBioState;
    float bioInfluence = 0.5f;
    bool breathSyncEnabled = false;

    // Gesture Recognition
    std::vector<GesturePattern> registeredGestures;
    juce::String lastGesture;

    // Quantum State
    std::mt19937 quantumRng;
    std::array<std::complex<float>, kQuantumStates> quantumState;

    // Learning
    std::array<int, 12> noteHistogram;
    std::array<float, kGestureHistorySize> globalPressHistory;
    int gestureHistoryIndex = 0;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    // MPE Processing
    MPEVoice* allocateMPEVoice(int channel, int noteNumber);
    MPEVoice* findMPEVoice(int channel, int noteNumber);
    void processMPENoteOn(int channel, int note, int velocity);
    void processMPENoteOff(int channel, int note, int velocity);
    void processMPEPressure(int channel, int pressure);
    void processMPESlide(int channel, int value);
    void processMPEPitchBend(int channel, int value);
    void processMPETimbre(int channel, int value);

    // Wise Mode AI
    void updateHarmonicIntelligence(int noteNumber);
    void updatePredictiveArticulation(const MPEVoice& voice);
    void updateGestureMemory(const MPEVoice& voice);
    void updateQuantumState();
    float calculateBioResonance();
    std::array<int, 8> generateHarmonicSuggestions();
    int predictNextNote();
    float calculateOptimalTimbre();

    // Gesture Recognition
    void recognizeGestures(const MPEVoice& voice);
    float matchGesturePattern(const GesturePattern& pattern, const MPEVoice& voice);

    // Bio Processing
    void applyBioModulation(MPEVoice& voice);
    void updateFlowState();

    // Response Curves
    float applyVelocityCurve(float velocity);
    float applyPressureCurve(float pressure);
    float applySlideCurve(float slide);

    // Hardware Detection
    void detectSeaboard(const juce::MidiMessage& msg);
    void detectLinnstrument(const juce::MidiMessage& msg);
    void detectOsmose(const juce::MidiMessage& msg);

    // Quantum
    float measureQuantumState(int index);
    void evolveQuantumState(float deltaTime);

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(EchoelSuperIntelligence)
};

//==============================================================================
// Inline Implementations
//==============================================================================

inline float EchoelSuperIntelligence::applyVelocityCurve(float velocity)
{
    return std::pow(velocity, currentProfile.velocityCurve);
}

inline float EchoelSuperIntelligence::applyPressureCurve(float pressure)
{
    return std::pow(pressure, currentProfile.pressureCurve);
}

inline float EchoelSuperIntelligence::applySlideCurve(float slide)
{
    return std::pow(slide, currentProfile.slideCurve);
}
