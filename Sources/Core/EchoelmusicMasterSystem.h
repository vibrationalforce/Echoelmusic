#pragma once

#include <JuceHeader.h>

// Core Audio
#include "../Audio/AudioEngine.h"
#include "../Audio/SampleLibrary.h"
#include "../Audio/SampleProcessor.h"
#include "../Audio/CloudSampleManager.h"
#include "../Audio/ProducerStyleProcessor.h"
#include "../Audio/IntelligentStyleEngine.h"

// Hardware
#include "../Hardware/UniversalDeviceManager.h"
#include "../Hardware/MIDIHardwareManager.h"
#include "../Hardware/OSCManager.h"

// MIDI
#include "../MIDI/MIDIEngine.h"
#include "../MIDI/ChordGenius.h"
#include "../MIDI/ArpWeaver.h"
#include "../MIDI/MelodyForge.h"
#include "../MIDI/BasslineArchitect.h"

// Bio/Health
#include "../BioData/BioDataBridge.h"
#include "../BioData/BioReactiveModulator.h"
#include "../BioData/HRVProcessor.h"

// Remote/Cloud
#include "../Remote/WebRTCTransport.h"
#include "../Remote/EchoelCloudManager.h"

/**
 * EchoelmusicMasterSystem - Complete Integrated Ecosystem
 *
 * UNIFIED SYSTEM integrating:
 * - Audio Engine (Processing, Effects, Mixing)
 * - Sample Management (Cloud, Intelligent Processing)
 * - Hardware Integration (ALL devices, past/present/future)
 * - MIDI (Generation, Processing, Routing)
 * - Bio-Reactive (Heart rate, EEG, stress → Audio)
 * - Collaboration (WebRTC, Cloud)
 * - Education (Music History, Science, Frequencies)
 * - Inclusive Design (Accessibility, Universal Usability)
 *
 * KOMPATIBILITÄT:
 * ✅ Legacy Devices (1970s+)
 * ✅ Current Technology (2000-2030)
 * ✅ Future Technology (2030+)
 * ✅ Elon Musk Tech (Neuralink-ähnlich, Neural interfaces)
 *
 * WISSENSCHAFTLICHE GRUNDLAGEN (NO HEALTH CLAIMS!):
 * - NASA-Research (Adey Windows, ELF frequencies)
 * - Psychoacoustics (Fletcher-Munson, Critical Bands)
 * - Color-Sound Psychology (Kandinsky, Scriabin)
 * - Quantum Physics (Superposition, Entanglement concepts in audio)
 * - Music History (Ancient to Modern, alle Kulturen)
 *
 * INCLUSIVE DESIGN:
 * - Screen Reader Support
 * - Voice Control
 * - Eye Tracking
 * - One-Handed Operation
 * - High Contrast Modes
 * - Multi-Language
 * - Cultural Sensitivity
 *
 * Usage:
 * ```cpp
 * EchoelmusicMasterSystem system;
 *
 * // Initialize complete system
 * system.initialize();
 *
 * // Access any subsystem
 * auto& audio = system.getAudioEngine();
 * auto& devices = system.getDeviceManager();
 * auto& bioData = system.getBioDataBridge();
 * auto& education = system.getEducationalFramework();
 *
 * // Unified workflow
 * system.importSamples(zipFile);
 * system.processWithGenre(MusicGenre::Trap);
 * system.optimizeForDolbyAtmos();
 * system.connectAllDevices();
 * system.enableBioReactivity();
 * ```
 */

//==============================================================================
// System Configuration
//==============================================================================

struct SystemConfiguration
{
    // Audio
    double sampleRate = 48000.0;
    int bufferSize = 512;
    int numInputChannels = 2;
    int numOutputChannels = 2;

    // Quality
    ProducerStyleProcessor::AudioQuality audioQuality =
        ProducerStyleProcessor::AudioQuality::Professional;

    // Dolby Atmos (Standard!)
    bool enableDolbyAtmos = true;
    float atmosHeadroom = 4.0f;

    // Hardware
    bool autoDetectDevices = true;
    bool enableHotSwap = true;

    // Bio-Reactivity
    bool enableBioReactivity = false;
    bool connectHeartRate = false;
    bool connectEEG = false;
    bool connectBCI = false;

    // Cloud/Collaboration
    bool enableCloudSync = false;
    bool enableWebRTC = false;
    bool enableAbletonLink = true;

    // Accessibility
    bool accessibilityMode = false;
    juce::String interactionMode = "standard";  // "standard", "voice", "eye-tracking"
    bool highContrastMode = false;
    bool screenReaderSupport = false;

    // Education
    bool enableEducationalFeatures = true;
    bool showScientificInfo = true;
    bool showHistoricalContext = true;

    // Performance
    bool multiThreading = true;
    int numWorkerThreads = 4;
    bool gpuAcceleration = false;
};

//==============================================================================
// System Status
//==============================================================================

struct SystemStatus
{
    // Overall
    bool initialized = false;
    bool running = false;
    juce::String currentMode;  // "Production", "Live Performance", "Education"

    // Audio
    bool audioEngineRunning = false;
    double cpuLoad = 0.0;  // 0-1
    double memoryUsageMB = 0.0;

    // Devices
    int devicesConnected = 0;
    int devicesActive = 0;
    bool djEquipmentConnected = false;
    bool modularSynthConnected = false;
    bool bioSensorsConnected = false;
    bool bciConnected = false;

    // Network
    bool cloudConnected = false;
    bool webRTCActive = false;
    bool abletonLinkActive = false;
    int networkLatencyMs = 0;

    // Bio-Reactivity
    bool bioReactivityActive = false;
    int heartRateBPM = 0;
    float focusLevel = 0.0f;  // 0-1
    float stressLevel = 0.0f;  // 0-1

    // Quality
    float currentLUFS = 0.0f;
    bool atmosCompliant = false;
    juce::String qualityRating;

    juce::String getSummary() const;
};

//==============================================================================
// EchoelmusicMasterSystem - Main Class
//==============================================================================

class EchoelmusicMasterSystem
{
public:
    EchoelmusicMasterSystem();
    ~EchoelmusicMasterSystem();

    //==========================================================================
    // System Lifecycle
    //==========================================================================

    /** Initialize complete system */
    bool initialize(const SystemConfiguration& config = SystemConfiguration());

    /** Start system */
    void start();

    /** Stop system */
    void stop();

    /** Get current status */
    SystemStatus getStatus() const;

    /** Check system health */
    bool checkHealth();

    //==========================================================================
    // Subsystem Access
    //==========================================================================

    AudioEngine& getAudioEngine() { return *audioEngine; }
    SampleLibrary& getSampleLibrary() { return *sampleLibrary; }
    CloudSampleManager& getCloudManager() { return *cloudManager; }
    IntelligentStyleEngine& getStyleEngine() { return *styleEngine; }
    UniversalDeviceManager& getDeviceManager() { return *deviceManager; }
    MIDIEngine& getMIDIEngine() { return *midiEngine; }
    BioDataBridge& getBioDataBridge() { return *bioDataBridge; }
    WebRTCTransport& getWebRTC() { return *webRTC; }

    //==========================================================================
    // Unified Workflows
    //==========================================================================

    /** Complete sample workflow: Import → Process → Cloud → Engine */
    struct SampleWorkflowResult
    {
        int samplesImported = 0;
        int samplesProcessed = 0;
        int samplesUploaded = 0;
        bool success = false;
        juce::StringArray errors;
    };

    SampleWorkflowResult importAndProcessSamples(
        const juce::File& zipFile,
        MusicGenre genre,
        bool uploadToCloud = false);

    /** Complete production workflow: Compose → Arrange → Mix → Master → Export */
    struct ProductionWorkflowResult
    {
        juce::File exportedFile;
        float lufs = 0.0f;
        bool atmosCompliant = false;
        bool success = false;
    };

    ProductionWorkflowResult completeProduction(
        const juce::String& projectName,
        LoudnessTarget loudnessTarget = LoudnessTarget::DolbyAtmos);

    /** Live performance mode: Connect devices → Sync → Perform */
    bool startLivePerformance();
    void stopLivePerformance();

    //==========================================================================
    // Device Integration
    //==========================================================================

    /** Connect all available devices */
    void connectAllDevices();

    /** Sync tempo across all devices */
    void syncTempoAll(float bpm);

    /** Enable/Disable specific device categories */
    void enableDJEquipment(bool enable);
    void enableModularSynths(bool enable);
    void enableBioSensors(bool enable);
    void enableBCI(bool enable);

    //==========================================================================
    // Bio-Reactivity
    //==========================================================================

    /** Enable bio-reactive audio (heart rate, EEG → audio parameters) */
    void enableBioReactivity(bool enable);

    /** Map biometric data to audio parameters */
    void mapHeartRateToTempo(bool enable);
    void mapStressToCompression(bool enable);
    void mapFocusToFilter(bool enable);

    /** Get current biometric data */
    BiometricData getCurrentBiometrics() const;

    //==========================================================================
    // Cloud & Collaboration
    //==========================================================================

    /** Connect to cloud */
    bool connectToCloud(const juce::String& apiKey);

    /** Start collaboration session */
    bool startCollaborationSession(const juce::String& sessionID);

    /** Share project */
    juce::String shareProject(const juce::String& projectName);

    //==========================================================================
    // Educational Features
    //==========================================================================

    /** Get music historical context */
    struct HistoricalContext
    {
        juce::String era;           // "Ancient", "Medieval", "Renaissance", etc.
        juce::String culture;       // "Western", "African", "Asian", etc.
        juce::String description;
        juce::StringArray keyFigures;
        juce::StringArray instruments;
        juce::String audioExample;  // Path to example
    };

    HistoricalContext getHistoricalContext(const juce::String& era) const;
    juce::StringArray getAllHistoricalEras() const;

    /** Get frequency information (scientific, NO health claims!) */
    struct FrequencyInfo
    {
        float frequency;            // Hz
        juce::String scientificName;
        juce::String description;

        // NASA/Scientific Research (observable phenomena only!)
        bool inAdeyWindow = false;  // Adey Windows (6-16 Hz shown in NASA studies)
        bool isSchumannResonance = false;  // 7.83 Hz Earth resonance
        bool isAudibleRange = false;  // 20-20kHz human hearing

        // Psychoacoustics (scientifically documented)
        juce::String perceptualQuality;  // "Bright", "Warm", "Dark"
        bool isCriticalBand = false;     // Critical band center frequency

        // Music Theory
        juce::String musicalNote;        // "A4", "C3", etc.
        float midiNote = 0.0f;

        // Color Association (Kandinsky/Scriabin color-sound theory)
        juce::Colour associatedColor;
        juce::String colorTheory;

        // NO HEALTH CLAIMS! Only observable, documented phenomena
        juce::StringArray scientificReferences;  // Links to papers
    };

    FrequencyInfo getFrequencyInfo(float frequency) const;

    /** Get psychoacoustic information */
    struct PsychoAcousticInfo
    {
        juce::String phenomenon;    // "Fletcher-Munson", "Critical Bands", etc.
        juce::String description;
        juce::Image visualGraph;    // Graph/Chart
        juce::StringArray references;
    };

    PsychoAcousticInfo getPsychoAcousticInfo(const juce::String& phenomenon) const;

    /** Get quantum audio concepts (educational, theoretical) */
    struct QuantumAudioConcept
    {
        juce::String concept;       // "Superposition", "Entanglement", etc.
        juce::String explanation;   // How it relates to audio
        juce::String audioExample;  // Practical audio demonstration
        bool experimental = true;
        juce::StringArray references;
    };

    QuantumAudioConcept getQuantumConcept(const juce::String& concept) const;

    //==========================================================================
    // Accessibility & Inclusive Design
    //==========================================================================

    /** Enable accessibility mode */
    void enableAccessibilityMode(bool enable);

    /** Set interaction mode */
    void setInteractionMode(const juce::String& mode);

    /** Voice command */
    void enableVoiceControl(bool enable);
    bool processVoiceCommand(const juce::String& command);

    /** Eye tracking */
    void enableEyeTracking(bool enable);

    /** Screen reader support */
    void enableScreenReader(bool enable);
    juce::String getScreenReaderText() const;

    //==========================================================================
    // Compatibility & Future-Proofing
    //==========================================================================

    /** Check device compatibility */
    struct CompatibilityInfo
    {
        bool legacy Compatible = true;      // Works with pre-2000 devices
        bool currentCompatible = true;      // Works with 2000-2030 devices
        bool futureCompatible = true;       // Ready for 2030+ devices

        juce::StringArray supportedPlatforms;
        juce::StringArray supportedProtocols;
        juce::StringArray limitations;
    };

    CompatibilityInfo getCompatibilityInfo() const;

    /** Export for future platforms */
    bool exportForPlatform(const juce::String& platform, const juce::File& outputFile);

    //==========================================================================
    // Scientific Foundation (Evidence-Based)
    //==========================================================================

    /** Get scientific research references */
    struct ScientificReference
    {
        juce::String topic;         // "Adey Windows", "Schumann Resonance", etc.
        juce::String study;         // Study name
        juce::String authors;
        juce::String journal;
        int year;
        juce::String doi;           // Digital Object Identifier
        juce::String summary;
        juce::String relevance;     // How it relates to Echoelmusic

        // IMPORTANT: NO HEALTH CLAIMS!
        // Only observable, documented, peer-reviewed phenomena
    };

    juce::Array<ScientificReference> getScientificReferences(const juce::String& topic) const;
    juce::StringArray getAllResearchTopics() const;

    //==========================================================================
    // System Monitoring & Optimization
    //==========================================================================

    /** Get performance metrics */
    struct PerformanceMetrics
    {
        double cpuLoad = 0.0;       // 0-1
        double memoryUsageMB = 0.0;
        double diskUsageGB = 0.0;
        double networkBandwidthMbps = 0.0;

        double audioLatencyMs = 0.0;
        double systemLatencyMs = 0.0;

        int droppedSamples = 0;
        int xruns = 0;

        juce::String bottleneck;    // "CPU", "Memory", "Disk", "Network", "None"
    };

    PerformanceMetrics getPerformanceMetrics() const;

    /** Optimize system */
    void optimizePerformance();

    //==========================================================================
    // Callbacks
    //==========================================================================

    std::function<void(const SystemStatus& status)> onStatusChange;
    std::function<void(const juce::String& message)> onMessage;
    std::function<void(const juce::String& error)> onError;
    std::function<void(const BiometricData& data)> onBiometricUpdate;
    std::function<void(const Thought& thought)> onThoughtDetected;

private:
    //==========================================================================
    // Subsystems (Unique Pointers for RAII)
    //==========================================================================

    std::unique_ptr<AudioEngine> audioEngine;
    std::unique_ptr<SampleLibrary> sampleLibrary;
    std::unique_ptr<CloudSampleManager> cloudManager;
    std::unique_ptr<ProducerStyleProcessor> producerProcessor;
    std::unique_ptr<IntelligentStyleEngine> styleEngine;
    std::unique_ptr<UniversalDeviceManager> deviceManager;
    std::unique_ptr<MIDIEngine> midiEngine;
    std::unique_ptr<ChordGenius> chordGenius;
    std::unique_ptr<ArpWeaver> arpWeaver;
    std::unique_ptr<BioDataBridge> bioDataBridge;
    std::unique_ptr<WebRTCTransport> webRTC;
    std::unique_ptr<EchoelCloudManager> cloudSync;

    //==========================================================================
    // State
    //==========================================================================

    SystemConfiguration config;
    SystemStatus status;

    bool initialized = false;
    bool running = false;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    bool initializeAudioEngine();
    bool initializeDeviceManager();
    bool initializeMIDI();
    bool initializeBioData();
    bool initializeCloud();

    void updateStatus();
    void checkConnections();

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(EchoelmusicMasterSystem)
};

//==============================================================================
// Global Access (Singleton Pattern)
//==============================================================================

class Echoelmusic
{
public:
    static EchoelmusicMasterSystem& getInstance()
    {
        static EchoelmusicMasterSystem instance;
        return instance;
    }

    // Convenience accessors
    static AudioEngine& audio() { return getInstance().getAudioEngine(); }
    static IntelligentStyleEngine& style() { return getInstance().getStyleEngine(); }
    static UniversalDeviceManager& devices() { return getInstance().getDeviceManager(); }
    static BioDataBridge& bio() { return getInstance().getBioDataBridge(); }

private:
    Echoelmusic() = delete;
    ~Echoelmusic() = delete;
};

//==============================================================================
// Usage Examples
//==============================================================================

/*
// EXAMPLE 1: Complete Sample Workflow
auto& system = Echoelmusic::getInstance();

// Import .zip, process with Trap genre, upload to cloud, optimize for Atmos
auto result = system.importAndProcessSamples(
    juce::File("samples.zip"),
    MusicGenre::Trap,
    true  // upload to cloud
);

// EXAMPLE 2: Bio-Reactive Performance
system.connectAllDevices();
system.enableBioReactivity(true);
system.mapHeartRateToTempo(true);
system.mapStressToCompression(true);

system.startLivePerformance();

// EXAMPLE 3: Educational Mode
auto freqInfo = system.getFrequencyInfo(7.83f);  // Schumann Resonance
DBG("Frequency: " << freqInfo.scientificName);
DBG("In Adey Window: " << freqInfo.inAdeyWindow);
DBG("References: " << freqInfo.scientificReferences.joinIntoString(", "));

// EXAMPLE 4: Accessible Interface
system.enableAccessibilityMode(true);
system.setInteractionMode("voice");
system.enableVoiceControl(true);

system.processVoiceCommand("Start recording");

// EXAMPLE 5: Future Device Integration
system.getDeviceManager().enableNeuralInterface(true);
auto bci = system.getDeviceManager().getBCI("Neural Implant");

bci->onThoughtDetected = [](const Thought& thought) {
    if (thought.type == Thought::Type::Focus)
    {
        // Increase filter cutoff when focusing
        Echoelmusic::audio().setFilterCutoff(thought.intensity);
    }
};
*/
