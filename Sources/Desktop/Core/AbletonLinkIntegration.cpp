/**
 * AbletonLinkIntegration.cpp
 *
 * Ableton Link protocol integration for cross-device tempo synchronization
 *
 * Phase 10000 ULTIMATE RALPH WIGGUM LAMBDA MODE
 */

#include <string>
#include <vector>
#include <memory>
#include <functional>
#include <cmath>
#include <algorithm>
#include <cstdint>
#include <thread>
#include <atomic>
#include <mutex>
#include <chrono>
#include <array>
#include <map>

namespace Echoelmusic {
namespace Sync {

// ============================================================================
// Link Time Representation
// ============================================================================

using Microseconds = int64_t;
using Beats = double;

struct LinkTime {
    Microseconds micros = 0;

    static LinkTime now() {
        auto now = std::chrono::steady_clock::now();
        auto duration = now.time_since_epoch();
        return {std::chrono::duration_cast<std::chrono::microseconds>(duration).count()};
    }

    static LinkTime fromSeconds(double seconds) {
        return {static_cast<Microseconds>(seconds * 1000000.0)};
    }

    double toSeconds() const {
        return static_cast<double>(micros) / 1000000.0;
    }

    LinkTime operator+(const LinkTime& other) const {
        return {micros + other.micros};
    }

    LinkTime operator-(const LinkTime& other) const {
        return {micros - other.micros};
    }

    bool operator<(const LinkTime& other) const {
        return micros < other.micros;
    }
};

// ============================================================================
// Link Timeline State
// ============================================================================

struct LinkTimelineState {
    double tempo = 120.0;        // BPM
    Beats beatAtTime = 0.0;      // Beat position at reference time
    LinkTime timeAtBeat;         // Reference time
    double quantum = 4.0;        // Phase quantum (beats per bar)
    bool isPlaying = false;
    Beats startStopBeatAtTime = 0.0;

    // Calculate beat at a given time
    Beats beatAtTime_(const LinkTime& time) const {
        double deltaSeconds = (time - timeAtBeat).toSeconds();
        double deltaBeat = deltaSeconds * tempo / 60.0;
        return beatAtTime + deltaBeat;
    }

    // Calculate time at a given beat
    LinkTime timeAtBeat_(Beats beat) const {
        double deltaBeat = beat - beatAtTime;
        double deltaSeconds = deltaBeat * 60.0 / tempo;
        return timeAtBeat + LinkTime::fromSeconds(deltaSeconds);
    }

    // Get phase within quantum (0 to quantum)
    double phase(const LinkTime& time) const {
        Beats beat = beatAtTime_(time);
        double phase = std::fmod(beat, quantum);
        if (phase < 0) phase += quantum;
        return phase;
    }

    // Force phase to a specific position
    void forcePhase(const LinkTime& time, double targetPhase) {
        double currentPhase = phase(time);
        double phaseDiff = targetPhase - currentPhase;
        if (phaseDiff > quantum / 2.0) phaseDiff -= quantum;
        if (phaseDiff < -quantum / 2.0) phaseDiff += quantum;
        beatAtTime = beatAtTime_(time) + phaseDiff;
        timeAtBeat = time;
    }
};

// ============================================================================
// Link Session State
// ============================================================================

struct LinkSessionState {
    int numPeers = 0;
    bool isConnectedToNetwork = false;
    std::string networkInterface;
    uint16_t port = 0;

    // Peer information
    struct PeerInfo {
        uint64_t peerId;
        std::string name;
        double tempo;
        bool isPlaying;
        LinkTime lastSeen;
    };
    std::vector<PeerInfo> peers;
};

// ============================================================================
// Link Callback Definitions
// ============================================================================

using NumPeersCallback = std::function<void(int)>;
using TempoCallback = std::function<void(double)>;
using StartStopCallback = std::function<void(bool)>;
using PhaseCallback = std::function<void(double)>;

// ============================================================================
// Link Protocol Constants
// ============================================================================

namespace LinkProtocol {
    constexpr uint16_t DEFAULT_PORT = 20808;
    constexpr int HEARTBEAT_INTERVAL_MS = 200;
    constexpr int PEER_TIMEOUT_MS = 2000;
    constexpr int DISCOVERY_INTERVAL_MS = 1000;

    // Message types
    enum class MessageType : uint8_t {
        Heartbeat = 0x01,
        TempoChange = 0x02,
        StartStop = 0x03,
        PhaseSync = 0x04,
        Discovery = 0x05,
        DiscoveryResponse = 0x06
    };

    // Message header
    struct MessageHeader {
        uint32_t magic = 0x4C494E4B;  // "LINK"
        uint8_t version = 1;
        MessageType type;
        uint16_t length;
        uint64_t senderId;
    };
}

// ============================================================================
// Ableton Link Engine
// ============================================================================

class AbletonLinkEngine {
public:
    AbletonLinkEngine()
        : enabled_(false), startStopSyncEnabled_(false) {
        // Initialize timeline
        timeline_.tempo = 120.0;
        timeline_.quantum = 4.0;
        timeline_.timeAtBeat = LinkTime::now();
        timeline_.beatAtTime = 0.0;
    }

    ~AbletonLinkEngine() {
        disable();
    }

    // Enable/disable Link
    void enable() {
        if (enabled_) return;
        enabled_ = true;

        // Start network threads
        running_ = true;
        heartbeatThread_ = std::thread(&AbletonLinkEngine::heartbeatLoop, this);
        discoveryThread_ = std::thread(&AbletonLinkEngine::discoveryLoop, this);
    }

    void disable() {
        if (!enabled_) return;
        enabled_ = false;
        running_ = false;

        if (heartbeatThread_.joinable()) {
            heartbeatThread_.join();
        }
        if (discoveryThread_.joinable()) {
            discoveryThread_.join();
        }
    }

    bool isEnabled() const { return enabled_; }

    // Enable/disable start/stop sync
    void enableStartStopSync(bool enable) {
        startStopSyncEnabled_ = enable;
    }

    bool isStartStopSyncEnabled() const { return startStopSyncEnabled_; }

    // Get number of connected peers
    int numPeers() const { return sessionState_.numPeers; }

    // Timeline capture/commit pattern
    LinkTimelineState captureAudioTimeline() const {
        std::lock_guard<std::mutex> lock(timelineMutex_);
        return timeline_;
    }

    void commitAudioTimeline(const LinkTimelineState& timeline) {
        std::lock_guard<std::mutex> lock(timelineMutex_);
        timeline_ = timeline;
        broadcastTimelineUpdate();
    }

    LinkTimelineState captureAppTimeline() const {
        return captureAudioTimeline();
    }

    void commitAppTimeline(const LinkTimelineState& timeline) {
        commitAudioTimeline(timeline);
    }

    // Convenience methods
    double tempo() const {
        return captureAudioTimeline().tempo;
    }

    void setTempo(double tempo) {
        auto timeline = captureAudioTimeline();
        timeline.tempo = std::clamp(tempo, 20.0, 999.0);
        timeline.timeAtBeat = LinkTime::now();
        commitAudioTimeline(timeline);
    }

    double quantum() const {
        return captureAudioTimeline().quantum;
    }

    void setQuantum(double quantum) {
        auto timeline = captureAudioTimeline();
        timeline.quantum = std::max(1.0, quantum);
        commitAudioTimeline(timeline);
    }

    bool isPlaying() const {
        return captureAudioTimeline().isPlaying;
    }

    void setIsPlaying(bool playing) {
        if (!startStopSyncEnabled_) return;

        auto timeline = captureAudioTimeline();
        timeline.isPlaying = playing;
        timeline.startStopBeatAtTime = timeline.beatAtTime_(LinkTime::now());
        commitAudioTimeline(timeline);
    }

    // Calculate current beat position
    Beats beatAtTime(const LinkTime& time) const {
        return captureAudioTimeline().beatAtTime_(time);
    }

    double phase(const LinkTime& time) const {
        return captureAudioTimeline().phase(time);
    }

    // Force phase alignment
    void forceBeatAtTime(Beats beat, const LinkTime& time) {
        auto timeline = captureAudioTimeline();
        timeline.beatAtTime = beat;
        timeline.timeAtBeat = time;
        commitAudioTimeline(timeline);
    }

    void requestBeatAtStartPlayingTime(Beats beat) {
        if (!startStopSyncEnabled_) return;

        auto timeline = captureAudioTimeline();
        timeline.startStopBeatAtTime = beat;
        commitAudioTimeline(timeline);
    }

    // Callbacks
    void setNumPeersCallback(NumPeersCallback callback) {
        numPeersCallback_ = callback;
    }

    void setTempoCallback(TempoCallback callback) {
        tempoCallback_ = callback;
    }

    void setStartStopCallback(StartStopCallback callback) {
        startStopCallback_ = callback;
    }

    void setPhaseCallback(PhaseCallback callback) {
        phaseCallback_ = callback;
    }

    // Session state
    const LinkSessionState& sessionState() const {
        return sessionState_;
    }

private:
    void heartbeatLoop() {
        while (running_) {
            sendHeartbeat();
            cleanupStaleConnections();
            std::this_thread::sleep_for(
                std::chrono::milliseconds(LinkProtocol::HEARTBEAT_INTERVAL_MS));
        }
    }

    void discoveryLoop() {
        while (running_) {
            sendDiscoveryMessage();
            std::this_thread::sleep_for(
                std::chrono::milliseconds(LinkProtocol::DISCOVERY_INTERVAL_MS));
        }
    }

    void sendHeartbeat() {
        // In real implementation, this would send UDP multicast
        // For now, simulate local-only operation

        auto timeline = captureAudioTimeline();

        // Build heartbeat message
        std::vector<uint8_t> message;
        message.reserve(64);

        // Header
        LinkProtocol::MessageHeader header;
        header.type = LinkProtocol::MessageType::Heartbeat;
        header.senderId = localPeerId_;
        header.length = 32;

        // Payload: tempo, beat, phase
        // ... (actual UDP serialization would go here)
    }

    void sendDiscoveryMessage() {
        // UDP multicast discovery
        // In real implementation, sends to 224.76.78.75:20808
    }

    void broadcastTimelineUpdate() {
        auto timeline = captureAudioTimeline();

        if (tempoCallback_) {
            tempoCallback_(timeline.tempo);
        }

        if (startStopCallback_ && startStopSyncEnabled_) {
            startStopCallback_(timeline.isPlaying);
        }
    }

    void cleanupStaleConnections() {
        auto now = LinkTime::now();
        int removedPeers = 0;

        auto& peers = sessionState_.peers;
        peers.erase(
            std::remove_if(peers.begin(), peers.end(),
                [&](const LinkSessionState::PeerInfo& peer) {
                    bool stale = (now - peer.lastSeen).micros >
                        LinkProtocol::PEER_TIMEOUT_MS * 1000;
                    if (stale) removedPeers++;
                    return stale;
                }),
            peers.end());

        if (removedPeers > 0) {
            sessionState_.numPeers = static_cast<int>(peers.size());
            if (numPeersCallback_) {
                numPeersCallback_(sessionState_.numPeers);
            }
        }
    }

    void handleIncomingMessage(const std::vector<uint8_t>& data) {
        if (data.size() < sizeof(LinkProtocol::MessageHeader)) return;

        auto* header = reinterpret_cast<const LinkProtocol::MessageHeader*>(data.data());

        // Ignore our own messages
        if (header->senderId == localPeerId_) return;

        switch (header->type) {
            case LinkProtocol::MessageType::Heartbeat:
                handleHeartbeat(data);
                break;
            case LinkProtocol::MessageType::TempoChange:
                handleTempoChange(data);
                break;
            case LinkProtocol::MessageType::StartStop:
                handleStartStop(data);
                break;
            case LinkProtocol::MessageType::PhaseSync:
                handlePhaseSync(data);
                break;
            case LinkProtocol::MessageType::Discovery:
                handleDiscovery(data);
                break;
            case LinkProtocol::MessageType::DiscoveryResponse:
                handleDiscoveryResponse(data);
                break;
        }
    }

    void handleHeartbeat(const std::vector<uint8_t>& data) {
        // Update peer's last seen time and tempo
        // Merge timeline state from peer
    }

    void handleTempoChange(const std::vector<uint8_t>& data) {
        // Extract new tempo and update local timeline
        // Call tempo callback
    }

    void handleStartStop(const std::vector<uint8_t>& data) {
        if (!startStopSyncEnabled_) return;
        // Handle play/stop from peer
    }

    void handlePhaseSync(const std::vector<uint8_t>& data) {
        // Align phase with peer
    }

    void handleDiscovery(const std::vector<uint8_t>& data) {
        // Respond to discovery request
    }

    void handleDiscoveryResponse(const std::vector<uint8_t>& data) {
        // Add peer to known peers list
    }

    // State
    std::atomic<bool> enabled_;
    std::atomic<bool> startStopSyncEnabled_;
    std::atomic<bool> running_{false};

    mutable std::mutex timelineMutex_;
    LinkTimelineState timeline_;
    LinkSessionState sessionState_;

    uint64_t localPeerId_ = std::hash<std::thread::id>{}(std::this_thread::get_id());

    // Threads
    std::thread heartbeatThread_;
    std::thread discoveryThread_;

    // Callbacks
    NumPeersCallback numPeersCallback_;
    TempoCallback tempoCallback_;
    StartStopCallback startStopCallback_;
    PhaseCallback phaseCallback_;
};

// ============================================================================
// Bio-Reactive Link Extensions
// ============================================================================

class BioReactiveLinkEngine : public AbletonLinkEngine {
public:
    BioReactiveLinkEngine() : AbletonLinkEngine() {}

    // Bio-reactive tempo adjustment
    void setBioReactiveMode(bool enabled) {
        bioReactiveMode_ = enabled;
    }

    bool isBioReactiveMode() const { return bioReactiveMode_; }

    // Update tempo from heart rate
    void updateFromHeartRate(float heartRate, float coherence) {
        if (!bioReactiveMode_) return;

        // Smooth heart rate mapping to tempo
        float targetTempo = mapHeartRateToTempo(heartRate);

        // Higher coherence = smoother transitions
        float smoothing = 0.1f + coherence * 0.4f;  // 0.1-0.5

        currentBioTempo_ = currentBioTempo_ * (1.0f - smoothing) + targetTempo * smoothing;

        // Only apply if difference is significant
        double currentTempo = tempo();
        if (std::abs(currentBioTempo_ - currentTempo) > 0.5) {
            setTempo(currentBioTempo_);
        }
    }

    // Breathing-synced phase alignment
    void alignToBreathing(float breathPhase) {
        if (!bioReactiveMode_) return;

        // breathPhase: 0.0 = inhale start, 0.5 = exhale start, 1.0 = cycle complete
        // Align downbeat to exhale start for relaxation

        double targetPhase = breathPhase * quantum();
        auto timeline = captureAudioTimeline();
        timeline.forcePhase(LinkTime::now(), targetPhase);
        commitAudioTimeline(timeline);
    }

    // Coherence-based quantum adjustment
    void updateQuantumFromCoherence(float coherence) {
        if (!bioReactiveMode_) return;

        // High coherence = longer phrases (8 beats)
        // Low coherence = shorter phrases (2-4 beats)
        double targetQuantum = 2.0 + coherence * 6.0;  // 2-8 beats

        if (std::abs(targetQuantum - quantum()) > 0.5) {
            setQuantum(std::round(targetQuantum));
        }
    }

    // Group coherence sync (for multi-participant sessions)
    void syncToGroupCoherence(float groupCoherence, int numParticipants) {
        if (!bioReactiveMode_) return;

        // When group coherence is high, lock phase more strictly
        if (groupCoherence > 0.7f && numParticipants > 1) {
            // Force phase to nearest downbeat
            auto timeline = captureAudioTimeline();
            double currentPhase = timeline.phase(LinkTime::now());
            double nearestDownbeat = std::round(currentPhase / quantum()) * quantum();
            timeline.forcePhase(LinkTime::now(), std::fmod(nearestDownbeat, quantum()));
            commitAudioTimeline(timeline);
        }
    }

private:
    float mapHeartRateToTempo(float heartRate) {
        // Resting HR (~60-80) → slower tempo (80-100 BPM)
        // Active HR (~100-140) → medium tempo (100-140 BPM)
        // Peak HR (~140-180) → fast tempo (140-180 BPM)

        float minHR = 60.0f;
        float maxHR = 180.0f;
        float minTempo = 70.0f;
        float maxTempo = 180.0f;

        float normalized = std::clamp((heartRate - minHR) / (maxHR - minHR), 0.0f, 1.0f);

        // S-curve mapping for natural feel
        normalized = normalized * normalized * (3.0f - 2.0f * normalized);

        return minTempo + normalized * (maxTempo - minTempo);
    }

    bool bioReactiveMode_ = false;
    float currentBioTempo_ = 120.0f;
};

// ============================================================================
// Link-to-MIDI Clock Converter
// ============================================================================

class LinkToMIDIClockConverter {
public:
    LinkToMIDIClockConverter(AbletonLinkEngine& link) : link_(link) {}

    // Generate MIDI clock messages for external gear
    struct MIDIClockMessage {
        enum Type {
            Clock = 0xF8,      // 24 PPQ clock tick
            Start = 0xFA,
            Continue = 0xFB,
            Stop = 0xFC,
            SongPosition = 0xF2
        };

        Type type;
        uint16_t position = 0;  // For SongPosition (in 16th notes)
        Microseconds timestamp;
    };

    using MIDIClockCallback = std::function<void(const MIDIClockMessage&)>;

    void setCallback(MIDIClockCallback callback) {
        callback_ = callback;
    }

    void start() {
        running_ = true;
        clockThread_ = std::thread(&LinkToMIDIClockConverter::clockLoop, this);
    }

    void stop() {
        running_ = false;
        if (clockThread_.joinable()) {
            clockThread_.join();
        }
    }

private:
    void clockLoop() {
        double lastBeat = 0.0;
        bool wasPlaying = false;

        while (running_) {
            auto timeline = link_.captureAudioTimeline();
            auto now = LinkTime::now();
            double currentBeat = timeline.beatAtTime_(now);

            // 24 PPQ - send clock on each 1/24th of a beat
            double ppqBeat = std::floor(currentBeat * 24.0) / 24.0;

            if (ppqBeat > lastBeat) {
                // Send clock tick for each 1/24th beat we passed
                int ticksToSend = static_cast<int>((ppqBeat - lastBeat) * 24.0);
                for (int i = 0; i < ticksToSend; i++) {
                    if (callback_) {
                        callback_({MIDIClockMessage::Clock, 0, now.micros});
                    }
                }
                lastBeat = ppqBeat;
            }

            // Handle start/stop
            if (timeline.isPlaying != wasPlaying) {
                if (timeline.isPlaying) {
                    if (callback_) {
                        // Send song position
                        uint16_t pos = static_cast<uint16_t>(currentBeat * 4);  // 16th notes
                        callback_({MIDIClockMessage::SongPosition, pos, now.micros});
                        callback_({MIDIClockMessage::Start, 0, now.micros});
                    }
                } else {
                    if (callback_) {
                        callback_({MIDIClockMessage::Stop, 0, now.micros});
                    }
                }
                wasPlaying = timeline.isPlaying;
            }

            // Sleep until next tick (approximately)
            double beatsPerSecond = timeline.tempo / 60.0;
            double ticksPerSecond = beatsPerSecond * 24.0;
            int sleepMicros = static_cast<int>(1000000.0 / ticksPerSecond);
            std::this_thread::sleep_for(std::chrono::microseconds(sleepMicros));
        }
    }

    AbletonLinkEngine& link_;
    MIDIClockCallback callback_;
    std::thread clockThread_;
    std::atomic<bool> running_{false};
};

// ============================================================================
// Transport Synchronizer
// ============================================================================

class TransportSynchronizer {
public:
    TransportSynchronizer(AbletonLinkEngine& link)
        : link_(link), midiClock_(link) {}

    // Sync modes
    enum class SyncMode {
        Internal,       // Echoelmusic is master
        LinkMaster,     // Follow Link, be MIDI master
        LinkSlave,      // Follow Link tempo only
        MIDIClock,      // Follow external MIDI clock
        Manual          // Manual control
    };

    void setSyncMode(SyncMode mode) {
        syncMode_ = mode;

        switch (mode) {
            case SyncMode::Internal:
                link_.disable();
                midiClock_.stop();
                break;

            case SyncMode::LinkMaster:
                link_.enable();
                midiClock_.start();
                break;

            case SyncMode::LinkSlave:
                link_.enable();
                midiClock_.stop();
                break;

            case SyncMode::MIDIClock:
                link_.disable();
                midiClock_.stop();
                // Enable MIDI clock input
                break;

            case SyncMode::Manual:
                link_.disable();
                midiClock_.stop();
                break;
        }
    }

    SyncMode syncMode() const { return syncMode_; }

    // Transport controls
    void play() {
        isPlaying_ = true;
        if (syncMode_ == SyncMode::LinkMaster || syncMode_ == SyncMode::LinkSlave) {
            link_.setIsPlaying(true);
        }
    }

    void stop() {
        isPlaying_ = false;
        if (syncMode_ == SyncMode::LinkMaster || syncMode_ == SyncMode::LinkSlave) {
            link_.setIsPlaying(false);
        }
    }

    void pause() {
        isPlaying_ = false;
        // Keep position, don't reset
    }

    bool isPlaying() const { return isPlaying_; }

    // Position
    double positionBeats() const {
        if (syncMode_ == SyncMode::LinkMaster || syncMode_ == SyncMode::LinkSlave) {
            return link_.beatAtTime(LinkTime::now());
        }
        return internalPosition_;
    }

    void setPositionBeats(double beats) {
        internalPosition_ = beats;
        if (syncMode_ == SyncMode::LinkMaster) {
            link_.forceBeatAtTime(beats, LinkTime::now());
        }
    }

    // Tempo
    double tempo() const {
        if (syncMode_ == SyncMode::LinkMaster || syncMode_ == SyncMode::LinkSlave) {
            return link_.tempo();
        }
        return internalTempo_;
    }

    void setTempo(double tempo) {
        internalTempo_ = tempo;
        if (syncMode_ == SyncMode::LinkMaster) {
            link_.setTempo(tempo);
        }
    }

    // Tap tempo
    void tapTempo() {
        auto now = LinkTime::now();

        if (tapTimes_.size() >= 4) {
            tapTimes_.erase(tapTimes_.begin());
        }
        tapTimes_.push_back(now);

        if (tapTimes_.size() >= 2) {
            // Calculate average interval
            double totalInterval = 0.0;
            for (size_t i = 1; i < tapTimes_.size(); i++) {
                totalInterval += (tapTimes_[i] - tapTimes_[i-1]).toSeconds();
            }
            double avgInterval = totalInterval / (tapTimes_.size() - 1);

            // Convert to BPM
            double tapTempo = 60.0 / avgInterval;
            tapTempo = std::clamp(tapTempo, 20.0, 300.0);

            setTempo(tapTempo);
        }
    }

    // Nudge tempo
    void nudgeTempoUp() {
        setTempo(tempo() + 0.1);
    }

    void nudgeTempoDown() {
        setTempo(tempo() - 0.1);
    }

private:
    AbletonLinkEngine& link_;
    LinkToMIDIClockConverter midiClock_;

    SyncMode syncMode_ = SyncMode::Internal;
    bool isPlaying_ = false;
    double internalPosition_ = 0.0;
    double internalTempo_ = 120.0;

    std::vector<LinkTime> tapTimes_;
};

} // namespace Sync
} // namespace Echoelmusic
