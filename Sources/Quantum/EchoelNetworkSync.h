#pragma once

#include <JuceHeader.h>
#include "EchoelQuantumCore.h"

/**
 * EchoelNetworkSync - Ultra-Low-Latency Global Synchronization
 *
 * **LATENCY COMPENSATION SYSTEM**
 * Target: <20ms worldwide latency for real-time collaboration
 *
 * TECHNIQUES USED:
 * 1. **Predictive Buffering** - Predict future audio based on past patterns
 * 2. **Clock Synchronization** - NTP-inspired precision timing
 * 3. **Jitter Buffer** - Smooth out network variations
 * 4. **Forward Error Correction** - Recover lost packets without retransmission
 * 5. **Adaptive Bitrate** - Adjust quality based on connection
 * 6. **Time Stretching** - Micro-adjustments to maintain sync
 * 7. **Pre-Roll Buffer** - Start playback slightly delayed for compensation
 *
 * PROTOCOL:
 * - WebRTC for audio streams (peer-to-peer when possible)
 * - UDP for low-latency, unreliable data
 * - TCP for critical parameters (guaranteed delivery)
 * - Custom binary protocol for efficiency
 *
 * NETWORK TOPOLOGY:
 * - Peer-to-Peer (best for 2-4 collaborators)
 * - Star (one host, others connect - good for 5-16 collaborators)
 * - Mesh (fully distributed - experimental)
 */
class EchoelNetworkSync
{
public:
    //==========================================================================
    // LATENCY COMPENSATION
    //==========================================================================

    /**
     * Network quality metrics
     */
    struct NetworkMetrics
    {
        float latency = 0.0f;           // Round-trip time (ms)
        float jitter = 0.0f;            // Latency variation (ms)
        float packetLoss = 0.0f;        // 0.0-1.0 (percentage)
        float bandwidth = 0.0f;         // Mbps

        // Quality score (0.0-1.0)
        float getQualityScore() const
        {
            float latencyScore = juce::jlimit(0.0f, 1.0f, 1.0f - (latency / 100.0f));
            float jitterScore = juce::jlimit(0.0f, 1.0f, 1.0f - (jitter / 20.0f));
            float lossScore = 1.0f - packetLoss;
            return (latencyScore + jitterScore + lossScore) / 3.0f;
        }

        // Connection quality
        enum class Quality { Excellent, Good, Fair, Poor, Unusable };
        Quality getQuality() const
        {
            if (latency < 20.0f && jitter < 5.0f && packetLoss < 0.01f)
                return Quality::Excellent;
            if (latency < 50.0f && jitter < 10.0f && packetLoss < 0.05f)
                return Quality::Good;
            if (latency < 100.0f && jitter < 20.0f && packetLoss < 0.1f)
                return Quality::Fair;
            if (latency < 200.0f)
                return Quality::Poor;
            return Quality::Unusable;
        }
    };

    /**
     * Latency compensation strategies
     */
    enum class CompensationMode
    {
        None,               // No compensation (lowest latency, least stable)
        Minimal,            // 10-20ms buffer (good for LAN)
        Balanced,           // 20-50ms buffer (good for regional)
        Aggressive,         // 50-100ms buffer (good for intercontinental)
        Automatic           // Auto-adjust based on network quality
    };

    /**
     * Set compensation mode
     */
    void setCompensationMode(CompensationMode mode);
    CompensationMode getCompensationMode() const { return compensationMode; }

    /**
     * Get current network metrics
     */
    NetworkMetrics getNetworkMetrics(const juce::String& nodeID) const;

    /**
     * Get recommended buffer size (ms)
     */
    float getRecommendedBufferSize(const juce::String& nodeID) const;

    //==========================================================================
    // CLOCK SYNCHRONIZATION (NTP-Inspired)
    //==========================================================================

    /**
     * Clock synchronization state
     */
    struct ClockState
    {
        double localTime = 0.0;         // Local monotonic time (seconds)
        double networkTime = 0.0;       // Synchronized network time
        double offset = 0.0;            // Offset from network time
        double drift = 0.0;             // Clock drift rate (ppm)
        double precision = 0.001;       // Synchronization precision (seconds)

        bool isSynchronized() const
        {
            return std::abs(offset) < precision;
        }
    };

    /**
     * Synchronize clocks with network
     */
    void synchronizeClocks();
    ClockState getClockState() const { return clockState; }
    double getNetworkTime() const;

    /**
     * Convert between local and network time
     */
    double localToNetworkTime(double localTime) const;
    double networkToLocalTime(double networkTime) const;

    //==========================================================================
    // PREDICTIVE BUFFERING (LASER SCANNER MODE 🎯)
    //==========================================================================

    /**
     * **LASER SCANNER MODE** - Ultra-precise predictive sync
     *
     * Uses machine learning to predict future audio based on:
     * - Past waveform patterns
     * - Musical context (tempo, key, harmony)
     * - Player behavior patterns
     * - Bio-data trends
     *
     * Like a laser scanner, it "scans ahead" to predict what's coming,
     * allowing for tighter synchronization than physically possible.
     */
    struct LaserScannerMode
    {
        bool enabled = true;

        // Prediction parameters
        int predictionWindowMs = 50;    // How far ahead to predict
        float predictionConfidence = 0.8f; // 0.0-1.0

        // Model
        enum class Model
        {
            Linear,         // Simple linear prediction
            AR,             // Autoregressive model
            LSTM,           // Long Short-Term Memory (AI)
            Transformer     // Transformer model (best, most CPU)
        } model = Model::AR;

        // Context awareness
        bool useMusicalContext = true;
        bool useBioContext = true;
        bool usePlayerBehavior = true;
    };

    void enableLaserScannerMode(bool enable);
    void setLaserScannerModel(LaserScannerMode::Model model);
    LaserScannerMode getLaserScannerMode() const { return laserScanner; }

    /**
     * Predict future audio samples
     * Returns predicted buffer based on historical data
     */
    juce::AudioBuffer<float> predictFutureAudio(
        const juce::String& nodeID,
        int numSamples,
        const juce::AudioBuffer<float>& history);

    /**
     * Get prediction confidence (0.0-1.0)
     */
    float getPredictionConfidence(const juce::String& nodeID) const;

    //==========================================================================
    // JITTER BUFFER (Smooth Network Variations)
    //==========================================================================

    /**
     * Jitter buffer - smooths out network timing variations
     */
    struct JitterBuffer
    {
        int minBufferMs = 10;           // Minimum buffer size
        int maxBufferMs = 200;          // Maximum buffer size
        int targetBufferMs = 50;        // Target buffer size
        int currentBufferMs = 50;       // Current actual size

        // Adaptive adjustment
        bool adaptive = true;
        float adaptRate = 0.1f;         // How fast to adjust (0.0-1.0)

        // Statistics
        int underruns = 0;              // Buffer ran out
        int overruns = 0;               // Buffer overflowed
        float averageJitter = 0.0f;     // Average jitter (ms)
    };

    JitterBuffer& getJitterBuffer(const juce::String& nodeID);
    void setJitterBufferSize(const juce::String& nodeID, int targetMs);

    //==========================================================================
    // FORWARD ERROR CORRECTION (Packet Loss Recovery)
    //==========================================================================

    /**
     * FEC - Recover lost packets without retransmission
     */
    enum class FECMode
    {
        None,               // No error correction
        XOR,                // Simple XOR parity
        ReedSolomon,        // Reed-Solomon codes (good balance)
        LDPC,               // Low-Density Parity Check (best, most CPU)
        Adaptive            // Adjust based on packet loss rate
    };

    void setFECMode(FECMode mode);
    FECMode getFECMode() const { return fecMode; }

    /**
     * Packet recovery statistics
     */
    struct PacketStats
    {
        int sent = 0;
        int received = 0;
        int recovered = 0;              // Recovered via FEC
        int lost = 0;                   // Unrecoverable

        float getLossRate() const
        {
            return sent > 0 ? static_cast<float>(lost) / sent : 0.0f;
        }

        float getRecoveryRate() const
        {
            int totalLost = recovered + lost;
            return totalLost > 0 ? static_cast<float>(recovered) / totalLost : 0.0f;
        }
    };

    PacketStats getPacketStats(const juce::String& nodeID) const;

    //==========================================================================
    // ADAPTIVE BITRATE (Quality vs Latency)
    //==========================================================================

    /**
     * Automatically adjust audio quality based on connection
     */
    struct AdaptiveBitrate
    {
        bool enabled = true;

        // Quality levels
        enum class Quality
        {
            UltraLow,       // 16kbps - emergency mode
            Low,            // 32kbps - voice quality
            Medium,         // 64kbps - good music quality
            High,           // 128kbps - excellent quality
            Lossless        // 1411kbps - uncompressed (LANonly)
        };

        Quality currentQuality = Quality::High;
        Quality targetQuality = Quality::High;

        // Codec
        enum class Codec
        {
            Opus,           // Recommended (best latency/quality)
            AAC,            // Good quality
            MP3,            // Universal compatibility
            FLAC,           // Lossless
            PCM             // Uncompressed
        } codec = Codec::Opus;

        // Adjustment rate
        float adaptRate = 0.5f;         // How fast to adjust
    };

    void enableAdaptiveBitrate(bool enable);
    void setTargetQuality(AdaptiveBitrate::Quality quality);
    AdaptiveBitrate getAdaptiveBitrate() const { return adaptiveBitrate; }

    //==========================================================================
    // TIME STRETCHING (Micro-adjustments)
    //==========================================================================

    /**
     * Time stretching for micro-sync adjustments
     * Subtly speeds up or slows down audio to maintain sync
     */
    struct TimeStretchingParams
    {
        bool enabled = true;
        float maxStretchRatio = 1.05f;  // Max 5% speed change
        float currentRatio = 1.0f;      // Current stretch ratio

        // Algorithm
        enum class Algorithm
        {
            Simple,         // Simple resampling (fast, lower quality)
            PhaseVocoder,   // Phase vocoder (good balance)
            WSOLA,          // Waveform Similarity Overlap-Add (best)
        } algorithm = Algorithm::WSOLA;
    };

    void enableTimeStretching(bool enable);
    TimeStretchingParams getTimeStretchingParams() const { return timeStretching; }

    /**
     * Apply time stretching to sync with network
     */
    void processTimeStretching(juce::AudioBuffer<float>& buffer, const juce::String& nodeID);

    //==========================================================================
    // SESSION MANAGEMENT
    //==========================================================================

    /**
     * Start/Join sync session
     */
    bool startSession(const juce::String& sessionID, bool isHost);
    bool joinSession(const juce::String& sessionID);
    void leaveSession();

    /**
     * Add/Remove nodes
     */
    bool addNode(const juce::String& nodeID, const juce::IPAddress& address);
    void removeNode(const juce::String& nodeID);

    /**
     * Get session info
     */
    juce::String getSessionID() const { return sessionID; }
    bool isHost() const { return host; }
    int getNodeCount() const;
    std::vector<juce::String> getNodeIDs() const;

    //==========================================================================
    // DIAGNOSTICS & MONITORING
    //==========================================================================

    /**
     * Connection diagnostics
     */
    struct Diagnostics
    {
        // Latency breakdown
        float encodingLatency = 0.0f;   // Audio encoding time
        float networkLatency = 0.0f;    // Network transmission
        float decodingLatency = 0.0f;   // Audio decoding time
        float bufferLatency = 0.0f;     // Jitter buffer delay
        float totalLatency = 0.0f;      // Total round-trip

        // Network path
        std::vector<juce::String> routingPath;
        int hopCount = 0;

        // Recommendations
        std::vector<juce::String> recommendations;
    };

    Diagnostics getDiagnostics(const juce::String& nodeID) const;

    /**
     * Run network test
     */
    void runNetworkTest(const juce::String& nodeID);

    /**
     * Log network events
     */
    void enableNetworkLogging(bool enable);
    juce::String getNetworkLog() const;

    //==========================================================================
    // Constructor
    //==========================================================================

    EchoelNetworkSync();
    ~EchoelNetworkSync();

private:
    // Session
    juce::String sessionID;
    bool host = false;

    // Nodes
    struct NodeState
    {
        juce::String nodeID;
        juce::IPAddress address;
        NetworkMetrics metrics;
        JitterBuffer jitterBuffer;
        PacketStats packetStats;
        ClockState clockState;

        // Prediction history
        juce::AudioBuffer<float> audioHistory;
        int historySize = 4096;  // Samples
    };

    std::map<juce::String, NodeState> nodes;

    // Compensation settings
    CompensationMode compensationMode = CompensationMode::Automatic;
    LaserScannerMode laserScanner;
    FECMode fecMode = FECMode::ReedSolomon;
    AdaptiveBitrate adaptiveBitrate;
    TimeStretchingParams timeStretching;

    // Clock synchronization
    ClockState clockState;

    // Logging
    bool loggingEnabled = false;
    juce::StringArray networkLog;

    // Internal methods
    void updateNetworkMetrics(const juce::String& nodeID);
    void adjustJitterBuffer(const juce::String& nodeID);
    void adaptBitrate(const juce::String& nodeID);
    float calculateOptimalStretchRatio(const juce::String& nodeID);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(EchoelNetworkSync)
};
