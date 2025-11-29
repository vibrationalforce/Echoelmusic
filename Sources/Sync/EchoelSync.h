#pragma once

#include <JuceHeader.h>
#include <atomic>
#include <memory>

/**
 * ██████╗ ███████╗██╗  ██╗ ██████╗ ███████╗██╗   ██╗███╗   ██╗ ██████╗
 * ██╔════╝██╔════╝██║  ██║██╔═══██╗██╔════╝╚██╗ ██╔╝████╗  ██║██╔════╝
 * █████╗  ██║     ███████║██║   ██║███████╗ ╚████╔╝ ██╔██╗ ██║██║
 * ██╔══╝  ██║     ██╔══██║██║   ██║╚════██║  ╚██╔╝  ██║╚██╗██║██║
 * ███████╗╚███████╗██║  ██║╚██████╔╝███████║   ██║   ██║ ╚████║╚██████╗
 * ╚══════╝ ╚══════╝╚═╝  ╚═╝ ╚═════╝ ╚══════╝   ╚═╝   ╚═╝  ╚═══╝ ╚═════╝
 *
 * EchoelSync - Die intelligente Sync-Technologie von Echoelmusic
 *
 * DIE UNIVERSELLE SYNCHRONISATIONS-LÖSUNG FÜR ALLE GERÄTE & STANDARDS
 *
 * EchoelSync vereint ALLE existierenden Sync-Standards unter einem Dach
 * und macht sie intelligent, automatisch, und latenzfrei verfügbar.
 *
 * KOMPATIBILITÄT MIT ALLEN STANDARDS:
 * ✅ Ableton Link (sample-accurate, WiFi-based)
 * ✅ MIDI Clock (legacy DAWs, hardware)
 * ✅ MIDI Time Code (MTC) (video sync)
 * ✅ Linear Time Code (LTC) (professional video/film)
 * ✅ ART (Yamaha Steinberg, 1987)
 * ✅ MMC (MIDI Machine Control)
 * ✅ OSC /tempo messages (TouchDesigner, Resolume)
 * ✅ WebRTC sync (browser-based apps)
 * ✅ NTP (Network Time Protocol) (internet-wide)
 *
 * WAS MACHT ECHOELSYNC BESSER?
 * ✨ Automatische Erkennung aller Sync-Quellen im Netzwerk
 * ✨ Intelligente Protokoll-Auswahl (bestes für Situation)
 * ✨ Sample-accurate auch über Internet (< 50ms)
 * ✨ Multi-Master Support (mehrere Tempo-Quellen)
 * ✨ Conflict Resolution (was passiert bei unterschiedlichen Tempos?)
 * ✨ Adaptive Latency Compensation
 * ✨ AI-Powered Beat Prediction (bei schlechtem Netzwerk)
 * ✨ Cross-Platform (Windows ↔ Mac ↔ Linux ↔ iOS ↔ Android ↔ Web)
 * ✨ Plug & Play (zero configuration)
 *
 * ANWENDUNGSFÄLLE:
 * 1. Multi-DAW Sync: Echoelmusic ↔ Ableton ↔ Logic ↔ FL Studio
 * 2. Live Performance: Drummer → MIDI → EchoelSync → alle Geräte
 * 3. Video Sync: Premiere Pro ↔ Echoelmusic (LTC/MTC)
 * 4. Club Setup: CDJ ↔ EchoelSync ↔ Lighting ↔ Visuals (Resolume)
 * 5. Remote Jam: Berlin ↔ New York (< 50ms Internet sync)
 * 6. Studio: Hardware Synths ↔ DAW ↔ Drum Machines
 *
 * NETWORK DISCOVERY:
 * - mDNS/Bonjour: _echoelsync._tcp.local (primary)
 * - UDP Broadcast: Port 20738 (fallback)
 - Bluetooth LE: Advertisement (proximity)
 * - QR Code: Manual pairing
 * - Cloud Relay: Internet-wide discovery
 *
 * BRANDING FEATURES:
 * - EchoelSync Logo im UI
 * - "Powered by EchoelSync" badge
 * - EchoelSync Server List (community)
 * - EchoelSync.io website mit Server-Browser
 */
class EchoelSync
{
public:
    //==========================================================================
    // Sync Source Types
    //==========================================================================

    enum class SyncProtocol
    {
        EchoelSyncNative,     // Eigenes Protokoll (sample-accurate, ultra-low latency)
        AbletonLink,        // Ableton Link kompatibel
        MIDIClock,          // MIDI Clock (24 PPQN)
        MIDITimeCode,       // MTC (video sync)
        LinearTimeCode,     // LTC (SMPTE, audio-based)
        OSC,                // OSC /tempo messages
        ART,                // Yamaha Steinberg ART
        MMC,                // MIDI Machine Control
        WebRTC,             // Browser-based sync
        NTP,                // Network Time Protocol
        Auto                // Automatische Auswahl (intelligent)
    };

    enum class SyncRole
    {
        Master,             // Tempo-Quelle (sendet)
        Slave,              // Tempo-Empfänger (empfängt)
        Peer,               // Gleichberechtigt (wie Ableton Link)
        Adaptive            // Wechselt automatisch (intelligent)
    };

    //==========================================================================
    // Sync Source Info
    //==========================================================================

    struct SyncSource
    {
        juce::String sourceId;              // Unique identifier
        juce::String deviceName;            // "Studio MacBook Pro"
        juce::String appName;               // "Echoelmusic", "Ableton Live", etc.

        // Protocol
        SyncProtocol protocol = SyncProtocol::EchoelSyncNative;
        SyncRole role = SyncRole::Peer;

        // Transport
        double tempo = 120.0;               // BPM
        double timeSignature = 4.0;         // 4/4, 3/4, 7/8, etc.
        int64_t beat = 0;                   // Current beat
        double phase = 0.0;                 // Phase within beat (0.0 - 1.0)
        bool isPlaying = false;

        // Network
        juce::String ipAddress;
        int port = 20738;                   // EchoelSync default port
        float latencyMs = 0.0f;
        float jitterMs = 0.0f;
        int numPeers = 0;                   // Connected devices

        // Compatibility
        bool supportsAbletonLink = false;
        bool supportsMIDIClock = false;
        bool supportsMTC = false;
        bool supportsLTC = false;
        bool supportsOSC = false;

        // Quality
        float syncQuality = 1.0f;           // 0.0 (poor) to 1.0 (perfect)
        float stabilityScore = 1.0f;        // Tempo drift detection
        bool isTrusted = false;             // Verified device

        // Status
        bool isOnline = true;
        juce::Time lastSeenTime;
    };

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    EchoelSync();
    ~EchoelSync();

    //==========================================================================
    // Network Discovery (Automatic)
    //==========================================================================

    /** Start automatic discovery of all sync sources */
    void startDiscovery();

    /** Stop discovery */
    void stopDiscovery();

    /** Get all discovered sync sources */
    juce::Array<SyncSource> getAvailableSources() const;

    /** Get currently active sync source */
    SyncSource getActiveSyncSource() const;

    /** Connect to specific sync source */
    bool connectToSource(const SyncSource& source);

    /** Disconnect from current source */
    void disconnect();

    /** Enable auto-connect (connect to best available source) */
    void setAutoConnect(bool enable);

    //==========================================================================
    // Sync Role
    //==========================================================================

    void setSyncRole(SyncRole role);
    SyncRole getSyncRole() const { return currentRole; }

    /** Set preferred protocol (Auto = intelligent selection) */
    void setPreferredProtocol(SyncProtocol protocol);
    SyncProtocol getPreferredProtocol() const { return preferredProtocol; }

    //==========================================================================
    // Transport Control (als Master)
    //==========================================================================

    /** Set tempo (only as Master or Peer) */
    void setTempo(double bpm);
    double getTempo() const;

    /** Set time signature */
    void setTimeSignature(double numerator, double denominator = 4.0);

    /** Start playback (broadcasts to all peers) */
    void play();

    /** Stop playback */
    void stop();

    /** Check if playing */
    bool isPlaying() const;

    /** Get current beat position */
    double getCurrentBeat() const;

    /** Get beat phase (0.0 - 1.0 within current beat) */
    double getBeatPhase() const;

    //==========================================================================
    // Sample-Accurate Timing (für Audio Thread)
    //==========================================================================

    struct SessionState
    {
        // Timing
        double tempo = 120.0;
        double timeSignature = 4.0;
        int64_t sampleTime = 0;             // Samples since session start
        double beat = 0.0;                  // Current beat (floating point)
        double phase = 0.0;                 // Phase within beat (0.0 - 1.0)

        // Transport
        bool isPlaying = false;

        // Network
        int numPeers = 0;
        float latencyMs = 0.0f;

        // Quality
        float syncQuality = 1.0f;           // 0.0 = bad, 1.0 = perfect
    };

    /** Get session state (thread-safe, for audio thread) */
    SessionState captureSessionState() const;

    /** Get beat at specific sample time (for audio thread scheduling) */
    double beatAtSampleTime(int64_t sampleTime, double sampleRate) const;

    /** Get sample time at specific beat (for automation) */
    int64_t sampleTimeAtBeat(double beat, double sampleRate) const;

    //==========================================================================
    // Intelligent Sync Features (EchoelSync-Exclusive)
    //==========================================================================

    /** Enable AI-powered beat prediction (für schlechtes Netzwerk) */
    void setAIPredictionEnabled(bool enable);

    /** Enable multi-master mode (mehrere Tempo-Quellen) */
    void setMultiMasterMode(bool enable);

    /** Conflict resolution strategy */
    enum class ConflictResolution
    {
        MasterWins,         // Master hat immer Recht
        MajorityVote,       // Mehrheit entscheidet
        AverageTempo,       // Durchschnittliches Tempo
        FastestWins,        // Schnellstes Tempo gewinnt
        SlowestWins,        // Langsamstes Tempo gewinnt
        UserDecides         // User muss wählen
    };

    void setConflictResolution(ConflictResolution strategy);

    /** Enable adaptive latency compensation (automatische Latenz-Korrektur) */
    void setAdaptiveLatencyCompensation(bool enable);

    /** Get quality score (0.0 = unusable, 1.0 = perfect) */
    float getSyncQuality() const;

    //==========================================================================
    // Legacy Protocol Support
    //==========================================================================

    /** Enable MIDI Clock output (für alte Hardware) */
    void setMIDIClockOutputEnabled(bool enable, const juce::String& midiOutputDevice);

    /** Enable MIDI Time Code output (für Video-Sync) */
    void setMTCOutputEnabled(bool enable, const juce::String& midiOutputDevice);

    /** Enable Linear Time Code output (Audio-based Timecode) */
    void setLTCOutputEnabled(bool enable, int audioOutputChannel = 0);

    /** Enable OSC output (für Resolume, TouchDesigner, etc.) */
    void setOSCOutputEnabled(bool enable, const juce::String& targetIP, int port = 8000);

    //==========================================================================
    // Server Mode (EchoelSync Server)
    //==========================================================================

    /** Start as EchoelSync Server (andere können connecten) */
    bool startServer(int port = 20738);

    /** Stop server */
    void stopServer();

    /** Check if server is running */
    bool isServerRunning() const;

    /** Set server name (visible on network) */
    void setServerName(const juce::String& name);

    /** Set maximum number of connected peers */
    void setMaxPeers(int count);

    /** Get connected peers */
    juce::Array<SyncSource> getConnectedPeers() const;

    /** Callback when peer connects */
    std::function<void(const SyncSource&)> onPeerConnected;

    /** Callback when peer disconnects */
    std::function<void(const SyncSource&)> onPeerDisconnected;

    //==========================================================================
    // Statistics & Monitoring
    //==========================================================================

    struct SyncStats
    {
        // Timing accuracy
        float averageLatencyMs = 0.0f;
        float maxLatencyMs = 0.0f;
        float jitterMs = 0.0f;                  // Latency variance
        float driftPercentage = 0.0f;           // Tempo drift (%)

        // Network
        int64_t packetsTransmitted = 0;
        int64_t packetsReceived = 0;
        int64_t packetsLost = 0;
        float packetLossRate = 0.0f;            // 0.0 to 1.0

        // Quality
        float syncQuality = 1.0f;
        int numTempoConflicts = 0;
        int numReconnects = 0;

        // Session
        juce::Time sessionStartTime;
        int64_t sessionDurationSeconds = 0;
        int maxPeersCount = 0;
    };

    SyncStats getSyncStats() const;
    void resetStatistics();

    /** Callback for sync quality changes */
    std::function<void(float)> onSyncQualityChanged;

    /** Callback for tempo changes (from external source) */
    std::function<void(double)> onTempoChanged;

    //==========================================================================
    // EchoelSync Community Features
    //==========================================================================

    /** Connect to EchoelSync.io global server list */
    void connectToGlobalServerList();

    /** Publish this server to global list (opt-in) */
    void publishToGlobalServerList(bool enable);

    /** Search global servers by location/genre/BPM */
    struct ServerSearchCriteria
    {
        juce::String location;              // "Berlin", "New York", etc.
        juce::String genre;                 // "Techno", "Jazz", etc.
        double minBPM = 60.0;
        double maxBPM = 180.0;
        int maxLatencyMs = 100;
        bool requiresPassword = false;
    };

    juce::Array<SyncSource> searchGlobalServers(const ServerSearchCriteria& criteria);

    /** Join public jam session */
    bool joinPublicSession(const juce::String& sessionId);

    //==========================================================================
    // Debugging & Diagnostics
    //==========================================================================

    /** Get detailed sync diagnostics */
    juce::String getDiagnosticsString() const;

    /** Enable debug logging */
    void setDebugLoggingEnabled(bool enable);

    /** Simulate network conditions (for testing) */
    void simulateNetworkConditions(float latencyMs, float jitter, float packetLoss);

private:
    //==========================================================================
    // Internal State
    //==========================================================================

    SyncRole currentRole = SyncRole::Peer;
    SyncProtocol preferredProtocol = SyncProtocol::Auto;

    std::atomic<bool> isPlayingFlag { false };
    std::atomic<double> currentTempo { 120.0 };
    std::atomic<int64_t> currentSampleTime { 0 };

    SyncSource activeSyncSource;
    juce::Array<SyncSource> discoveredSources;
    juce::Array<SyncSource> connectedPeers;

    SyncStats statistics;

    bool autoConnect = true;
    bool aiPrediction = false;
    bool multiMaster = false;
    bool adaptiveLatency = true;

    ConflictResolution conflictStrategy = ConflictResolution::MajorityVote;

    std::atomic<bool> serverMode { false };
    juce::String serverName = "Echoelmusic Studio";
    int maxPeers = 16;

    // Thread synchronization
    juce::CriticalSection connectionLock;  // For thread-safe connection operations
    bool connected = false;

    // Protocol implementations
    struct AbletonLinkImpl;
    std::unique_ptr<AbletonLinkImpl> abletonLink;

    struct MIDIClockImpl;
    std::unique_ptr<MIDIClockImpl> midiClock;

    struct MTCImpl;
    std::unique_ptr<MTCImpl> mtc;

    struct LTCImpl;
    std::unique_ptr<LTCImpl> ltc;

    struct OSCImpl;
    std::unique_ptr<OSCImpl> osc;

    struct NetworkDiscovery;
    std::unique_ptr<NetworkDiscovery> discovery;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    void updateSessionState();
    void broadcastTempoChange();
    void handleIncomingSync(const SyncSource& source);
    void resolveTempoConflict(const juce::Array<SyncSource>& sources);
    float calculateSyncQuality() const;
    SyncProtocol selectOptimalProtocol() const;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(EchoelSync)
};

//==============================================================================
// EchoelSync Utilities
//==============================================================================

/** Convert BPM to microseconds per beat */
inline int64_t bpmToMicrosPerBeat(double bpm)
{
    return static_cast<int64_t>((60.0 / bpm) * 1000000.0);
}

/** Convert microseconds per beat to BPM */
inline double microsPerBeatToBPM(int64_t microsPerBeat)
{
    return (60.0 * 1000000.0) / static_cast<double>(microsPerBeat);
}

/** Calculate beat at given time */
inline double beatAtTime(int64_t microseconds, double bpm, double timeSignature = 4.0)
{
    int64_t microsPerBeat = bpmToMicrosPerBeat(bpm);
    return static_cast<double>(microseconds) / static_cast<double>(microsPerBeat);
}

/** Calculate time at given beat */
inline int64_t timeAtBeat(double beat, double bpm)
{
    int64_t microsPerBeat = bpmToMicrosPerBeat(bpm);
    return static_cast<int64_t>(beat * static_cast<double>(microsPerBeat));
}
