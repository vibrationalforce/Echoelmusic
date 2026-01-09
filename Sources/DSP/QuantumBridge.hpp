/**
 * QuantumBridge.hpp
 * Echoelmusic - Cross-Platform Quantum Communication Bridge
 *
 * Network protocol for synchronizing quantum states across devices
 * Supports multi-device entanglement sessions
 * 300% Power Mode - Tauchfliegen Edition
 *
 * Created: 2026-01-05
 */

#pragma once

#include <string>
#include <vector>
#include <map>
#include <functional>
#include <memory>
#include <mutex>
#include <atomic>
#include <thread>
#include <chrono>
#include <cstring>

#ifdef _WIN32
    #include <winsock2.h>
    #include <ws2tcpip.h>
    #pragma comment(lib, "ws2_32.lib")
    using socket_t = SOCKET;
    #define SOCKET_INVALID INVALID_SOCKET
    #define SOCKET_ERROR_CODE WSAGetLastError()
#else
    #include <sys/socket.h>
    #include <netinet/in.h>
    #include <arpa/inet.h>
    #include <unistd.h>
    #include <fcntl.h>
    using socket_t = int;
    #define SOCKET_INVALID -1
    #define SOCKET_ERROR_CODE errno
    #define closesocket close
#endif

#include "QuantumLightEmulator.hpp"

namespace Echoelmusic {
namespace Bridge {

// ============================================================================
// MARK: - Protocol Constants
// ============================================================================

constexpr uint16_t DEFAULT_PORT = 42069;
constexpr uint32_t MAGIC_NUMBER = 0x51554E54; // "QUNT"
constexpr uint8_t PROTOCOL_VERSION = 1;

// ============================================================================
// MARK: - Message Types
// ============================================================================

enum class MessageType : uint8_t {
    // Connection
    Handshake = 0x01,
    HandshakeAck = 0x02,
    Disconnect = 0x03,
    Ping = 0x04,
    Pong = 0x05,

    // Session
    SessionStart = 0x10,
    SessionJoin = 0x11,
    SessionLeave = 0x12,
    SessionEnd = 0x13,

    // Quantum State
    StateSync = 0x20,
    CoherenceUpdate = 0x21,
    EntanglementPulse = 0x22,
    CollapseEvent = 0x23,

    // Bio Data
    BioFeedback = 0x30,
    HeartRate = 0x31,
    HRVUpdate = 0x32,

    // Control
    ModeChange = 0x40,
    VisualizationChange = 0x41,
    PresetLoad = 0x42
};

// ============================================================================
// MARK: - Message Header
// ============================================================================

#pragma pack(push, 1)
struct MessageHeader {
    uint32_t magic = MAGIC_NUMBER;
    uint8_t version = PROTOCOL_VERSION;
    MessageType type;
    uint32_t payloadSize = 0;
    uint64_t timestamp = 0;
    uint32_t senderId = 0;
    uint32_t checksum = 0;

    void updateChecksum() {
        checksum = magic ^ static_cast<uint32_t>(type) ^ payloadSize ^
                  static_cast<uint32_t>(timestamp) ^ senderId;
    }

    bool isValid() const {
        uint32_t expected = magic ^ static_cast<uint32_t>(type) ^ payloadSize ^
                           static_cast<uint32_t>(timestamp) ^ senderId;
        return magic == MAGIC_NUMBER && version == PROTOCOL_VERSION && checksum == expected;
    }
};
#pragma pack(pop)

// ============================================================================
// MARK: - Participant Info
// ============================================================================

struct Participant {
    uint32_t id;
    std::string name;
    std::string deviceType; // "iOS", "Android", "Windows", "Linux", "macOS"
    float coherenceLevel = 0.0f;
    double hrvCoherence = 0.0;
    double heartRate = 0.0;
    bool isHost = false;
    std::chrono::steady_clock::time_point lastSeen;
};

// ============================================================================
// MARK: - Session Info
// ============================================================================

struct SessionInfo {
    std::string sessionId;
    std::string name;
    Quantum::EmulationMode mode = Quantum::EmulationMode::BioCoherent;
    uint32_t hostId = 0;
    std::chrono::steady_clock::time_point startTime;
    float groupCoherence = 0.0f;
};

// ============================================================================
// MARK: - Quantum Bridge Client
// ============================================================================

class QuantumBridgeClient {
public:
    using MessageCallback = std::function<void(MessageType, const std::vector<uint8_t>&)>;
    using ParticipantCallback = std::function<void(const Participant&, bool joined)>;
    using CoherenceCallback = std::function<void(float groupCoherence)>;

    QuantumBridgeClient() {
#ifdef _WIN32
        WSADATA wsaData;
        WSAStartup(MAKEWORD(2, 2), &wsaData);
#endif
    }

    ~QuantumBridgeClient() {
        disconnect();
#ifdef _WIN32
        WSACleanup();
#endif
    }

    // MARK: - Connection

    bool connect(const std::string& host, uint16_t port = DEFAULT_PORT) {
        socket_ = socket(AF_INET, SOCK_STREAM, 0);
        if (socket_ == SOCKET_INVALID) {
            lastError_ = "Failed to create socket";
            return false;
        }

        sockaddr_in serverAddr{};
        serverAddr.sin_family = AF_INET;
        serverAddr.sin_port = htons(port);

        if (inet_pton(AF_INET, host.c_str(), &serverAddr.sin_addr) <= 0) {
            lastError_ = "Invalid address";
            closesocket(socket_);
            socket_ = SOCKET_INVALID;
            return false;
        }

        if (::connect(socket_, (sockaddr*)&serverAddr, sizeof(serverAddr)) < 0) {
            lastError_ = "Connection failed";
            closesocket(socket_);
            socket_ = SOCKET_INVALID;
            return false;
        }

        connected_.store(true);

        // Start receive thread
        receiveThread_ = std::thread([this]() { receiveLoop(); });

        // Send handshake
        sendHandshake();

        return true;
    }

    void disconnect() {
        if (!connected_.load()) return;

        sendMessage(MessageType::Disconnect, {});
        connected_.store(false);

        if (receiveThread_.joinable()) {
            receiveThread_.join();
        }

        if (socket_ != SOCKET_INVALID) {
            closesocket(socket_);
            socket_ = SOCKET_INVALID;
        }
    }

    bool isConnected() const { return connected_.load(); }

    // MARK: - Session

    void createSession(const std::string& name, Quantum::EmulationMode mode) {
        std::vector<uint8_t> payload;

        // Serialize session info
        appendString(payload, name);
        payload.push_back(static_cast<uint8_t>(mode));

        sendMessage(MessageType::SessionStart, payload);
    }

    void joinSession(const std::string& sessionId) {
        std::vector<uint8_t> payload;
        appendString(payload, sessionId);
        sendMessage(MessageType::SessionJoin, payload);
    }

    void leaveSession() {
        sendMessage(MessageType::SessionLeave, {});
    }

    // MARK: - Quantum State Sync

    void syncCoherence(float coherence) {
        std::vector<uint8_t> payload(sizeof(float));
        std::memcpy(payload.data(), &coherence, sizeof(float));
        sendMessage(MessageType::CoherenceUpdate, payload);
    }

    void sendEntanglementPulse() {
        sendMessage(MessageType::EntanglementPulse, {});
    }

    void syncBioFeedback(float coherence, double hrv, double heartRate) {
        std::vector<uint8_t> payload(sizeof(float) + 2 * sizeof(double));
        size_t offset = 0;

        std::memcpy(payload.data() + offset, &coherence, sizeof(float));
        offset += sizeof(float);
        std::memcpy(payload.data() + offset, &hrv, sizeof(double));
        offset += sizeof(double);
        std::memcpy(payload.data() + offset, &heartRate, sizeof(double));

        sendMessage(MessageType::BioFeedback, payload);
    }

    void syncMode(Quantum::EmulationMode mode) {
        std::vector<uint8_t> payload = { static_cast<uint8_t>(mode) };
        sendMessage(MessageType::ModeChange, payload);
    }

    // MARK: - Callbacks

    void setMessageCallback(MessageCallback callback) {
        messageCallback_ = std::move(callback);
    }

    void setParticipantCallback(ParticipantCallback callback) {
        participantCallback_ = std::move(callback);
    }

    void setCoherenceCallback(CoherenceCallback callback) {
        coherenceCallback_ = std::move(callback);
    }

    // MARK: - Getters

    uint32_t localId() const { return localId_; }
    const std::vector<Participant>& participants() const { return participants_; }
    const SessionInfo& sessionInfo() const { return sessionInfo_; }
    std::string lastError() const { return lastError_; }

private:
    void sendHandshake() {
        std::vector<uint8_t> payload;

        // Device info
        appendString(payload, deviceName_);
#ifdef _WIN32
        appendString(payload, "Windows");
#elif defined(__APPLE__)
        appendString(payload, "macOS");
#elif defined(__linux__)
        appendString(payload, "Linux");
#else
        appendString(payload, "Unknown");
#endif

        sendMessage(MessageType::Handshake, payload);
    }

    void sendMessage(MessageType type, const std::vector<uint8_t>& payload) {
        if (!connected_.load()) return;

        MessageHeader header;
        header.type = type;
        header.payloadSize = static_cast<uint32_t>(payload.size());
        header.timestamp = std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::system_clock::now().time_since_epoch()
        ).count();
        header.senderId = localId_;
        header.updateChecksum();

        std::lock_guard<std::mutex> lock(sendMutex_);

        // Send header
        send(socket_, reinterpret_cast<const char*>(&header), sizeof(header), 0);

        // Send payload
        if (!payload.empty()) {
            send(socket_, reinterpret_cast<const char*>(payload.data()), payload.size(), 0);
        }
    }

    void receiveLoop() {
        while (connected_.load()) {
            MessageHeader header;
            int received = recv(socket_, reinterpret_cast<char*>(&header), sizeof(header), 0);

            if (received <= 0) {
                connected_.store(false);
                break;
            }

            if (!header.isValid()) {
                continue; // Invalid message
            }

            std::vector<uint8_t> payload(header.payloadSize);
            if (header.payloadSize > 0) {
                recv(socket_, reinterpret_cast<char*>(payload.data()), header.payloadSize, 0);
            }

            handleMessage(header.type, payload, header.senderId);
        }
    }

    void handleMessage(MessageType type, const std::vector<uint8_t>& payload, uint32_t senderId) {
        switch (type) {
            case MessageType::HandshakeAck:
                handleHandshakeAck(payload);
                break;

            case MessageType::CoherenceUpdate:
                handleCoherenceUpdate(payload, senderId);
                break;

            case MessageType::EntanglementPulse:
                handleEntanglementPulse(senderId);
                break;

            case MessageType::BioFeedback:
                handleBioFeedback(payload, senderId);
                break;

            case MessageType::SessionJoin:
                handleParticipantJoin(payload);
                break;

            case MessageType::SessionLeave:
                handleParticipantLeave(senderId);
                break;

            case MessageType::Ping:
                sendMessage(MessageType::Pong, {});
                break;

            default:
                break;
        }

        // Call user callback
        if (messageCallback_) {
            messageCallback_(type, payload);
        }
    }

    void handleHandshakeAck(const std::vector<uint8_t>& payload) {
        if (payload.size() >= sizeof(uint32_t)) {
            std::memcpy(&localId_, payload.data(), sizeof(uint32_t));
        }
    }

    void handleCoherenceUpdate(const std::vector<uint8_t>& payload, uint32_t senderId) {
        if (payload.size() < sizeof(float)) return;

        float coherence;
        std::memcpy(&coherence, payload.data(), sizeof(float));

        // Update participant
        for (auto& p : participants_) {
            if (p.id == senderId) {
                p.coherenceLevel = coherence;
                p.lastSeen = std::chrono::steady_clock::now();
                break;
            }
        }

        // Calculate group coherence
        float total = 0.0f;
        for (const auto& p : participants_) {
            total += p.coherenceLevel;
        }
        float groupCoherence = participants_.empty() ? 0.0f : total / participants_.size();
        sessionInfo_.groupCoherence = groupCoherence;

        if (coherenceCallback_) {
            coherenceCallback_(groupCoherence);
        }
    }

    void handleEntanglementPulse(uint32_t senderId) {
        // Entanglement pulse received - could trigger visual/audio feedback
        for (auto& p : participants_) {
            if (p.id == senderId) {
                p.lastSeen = std::chrono::steady_clock::now();
                break;
            }
        }
    }

    void handleBioFeedback(const std::vector<uint8_t>& payload, uint32_t senderId) {
        if (payload.size() < sizeof(float) + 2 * sizeof(double)) return;

        float coherence;
        double hrv, heartRate;
        size_t offset = 0;

        std::memcpy(&coherence, payload.data() + offset, sizeof(float));
        offset += sizeof(float);
        std::memcpy(&hrv, payload.data() + offset, sizeof(double));
        offset += sizeof(double);
        std::memcpy(&heartRate, payload.data() + offset, sizeof(double));

        for (auto& p : participants_) {
            if (p.id == senderId) {
                p.coherenceLevel = coherence;
                p.hrvCoherence = hrv;
                p.heartRate = heartRate;
                p.lastSeen = std::chrono::steady_clock::now();
                break;
            }
        }
    }

    void handleParticipantJoin(const std::vector<uint8_t>& payload) {
        Participant p;
        size_t offset = 0;

        if (payload.size() < sizeof(uint32_t)) return;
        std::memcpy(&p.id, payload.data() + offset, sizeof(uint32_t));
        offset += sizeof(uint32_t);

        p.name = extractString(payload, offset);
        p.deviceType = extractString(payload, offset);
        p.lastSeen = std::chrono::steady_clock::now();

        participants_.push_back(p);

        if (participantCallback_) {
            participantCallback_(p, true);
        }
    }

    void handleParticipantLeave(uint32_t senderId) {
        auto it = std::find_if(participants_.begin(), participants_.end(),
            [senderId](const Participant& p) { return p.id == senderId; });

        if (it != participants_.end()) {
            Participant p = *it;
            participants_.erase(it);

            if (participantCallback_) {
                participantCallback_(p, false);
            }
        }
    }

    // Helper functions
    void appendString(std::vector<uint8_t>& data, const std::string& str) {
        uint32_t len = static_cast<uint32_t>(str.size());
        size_t offset = data.size();
        data.resize(offset + sizeof(uint32_t) + len);
        std::memcpy(data.data() + offset, &len, sizeof(uint32_t));
        std::memcpy(data.data() + offset + sizeof(uint32_t), str.data(), len);
    }

    std::string extractString(const std::vector<uint8_t>& data, size_t& offset) {
        if (offset + sizeof(uint32_t) > data.size()) return "";

        uint32_t len;
        std::memcpy(&len, data.data() + offset, sizeof(uint32_t));
        offset += sizeof(uint32_t);

        if (offset + len > data.size()) return "";

        std::string str(reinterpret_cast<const char*>(data.data() + offset), len);
        offset += len;
        return str;
    }

    socket_t socket_ = SOCKET_INVALID;
    std::atomic<bool> connected_{false};
    std::thread receiveThread_;
    std::mutex sendMutex_;

    uint32_t localId_ = 0;
    std::string deviceName_ = "Echoelmusic Device";
    std::vector<Participant> participants_;
    SessionInfo sessionInfo_;

    MessageCallback messageCallback_;
    ParticipantCallback participantCallback_;
    CoherenceCallback coherenceCallback_;

    std::string lastError_;
};

// ============================================================================
// MARK: - Quantum Bridge Server (for hosting sessions)
// ============================================================================

class QuantumBridgeServer {
public:
    QuantumBridgeServer() {
#ifdef _WIN32
        WSADATA wsaData;
        WSAStartup(MAKEWORD(2, 2), &wsaData);
#endif
    }

    ~QuantumBridgeServer() {
        stop();
#ifdef _WIN32
        WSACleanup();
#endif
    }

    bool start(uint16_t port = DEFAULT_PORT) {
        serverSocket_ = socket(AF_INET, SOCK_STREAM, 0);
        if (serverSocket_ == SOCKET_INVALID) {
            return false;
        }

        int opt = 1;
        setsockopt(serverSocket_, SOL_SOCKET, SO_REUSEADDR, (const char*)&opt, sizeof(opt));

        sockaddr_in serverAddr{};
        serverAddr.sin_family = AF_INET;
        serverAddr.sin_addr.s_addr = INADDR_ANY;
        serverAddr.sin_port = htons(port);

        if (bind(serverSocket_, (sockaddr*)&serverAddr, sizeof(serverAddr)) < 0) {
            closesocket(serverSocket_);
            serverSocket_ = SOCKET_INVALID;
            return false;
        }

        if (listen(serverSocket_, 10) < 0) {
            closesocket(serverSocket_);
            serverSocket_ = SOCKET_INVALID;
            return false;
        }

        running_.store(true);
        acceptThread_ = std::thread([this]() { acceptLoop(); });

        return true;
    }

    void stop() {
        running_.store(false);

        if (serverSocket_ != SOCKET_INVALID) {
            closesocket(serverSocket_);
            serverSocket_ = SOCKET_INVALID;
        }

        if (acceptThread_.joinable()) {
            acceptThread_.join();
        }

        // Close all client connections
        std::lock_guard<std::mutex> lock(clientsMutex_);
        for (auto& [id, socket] : clients_) {
            closesocket(socket);
        }
        clients_.clear();
    }

    bool isRunning() const { return running_.load(); }

    void broadcast(MessageType type, const std::vector<uint8_t>& payload, uint32_t excludeId = 0) {
        MessageHeader header;
        header.type = type;
        header.payloadSize = static_cast<uint32_t>(payload.size());
        header.timestamp = std::chrono::duration_cast<std::chrono::milliseconds>(
            std::chrono::system_clock::now().time_since_epoch()
        ).count();
        header.senderId = 0; // Server
        header.updateChecksum();

        std::lock_guard<std::mutex> lock(clientsMutex_);
        for (auto& [id, socket] : clients_) {
            if (id != excludeId) {
                send(socket, reinterpret_cast<const char*>(&header), sizeof(header), 0);
                if (!payload.empty()) {
                    send(socket, reinterpret_cast<const char*>(payload.data()), payload.size(), 0);
                }
            }
        }
    }

    size_t clientCount() const {
        std::lock_guard<std::mutex> lock(clientsMutex_);
        return clients_.size();
    }

private:
    void acceptLoop() {
        while (running_.load()) {
            sockaddr_in clientAddr{};
            socklen_t clientLen = sizeof(clientAddr);

            socket_t clientSocket = accept(serverSocket_, (sockaddr*)&clientAddr, &clientLen);

            if (clientSocket == SOCKET_INVALID) {
                if (running_.load()) continue;
                break;
            }

            uint32_t clientId = nextClientId_++;

            {
                std::lock_guard<std::mutex> lock(clientsMutex_);
                clients_[clientId] = clientSocket;
            }

            // Start client handler thread
            std::thread([this, clientSocket, clientId]() {
                handleClient(clientSocket, clientId);
            }).detach();
        }
    }

    void handleClient(socket_t clientSocket, uint32_t clientId) {
        while (running_.load()) {
            MessageHeader header;
            int received = recv(clientSocket, reinterpret_cast<char*>(&header), sizeof(header), 0);

            if (received <= 0) break;
            if (!header.isValid()) continue;

            std::vector<uint8_t> payload(header.payloadSize);
            if (header.payloadSize > 0) {
                recv(clientSocket, reinterpret_cast<char*>(payload.data()), header.payloadSize, 0);
            }

            // Handle handshake
            if (header.type == MessageType::Handshake) {
                // Send ack with client ID
                std::vector<uint8_t> ack(sizeof(uint32_t));
                std::memcpy(ack.data(), &clientId, sizeof(uint32_t));

                MessageHeader ackHeader;
                ackHeader.type = MessageType::HandshakeAck;
                ackHeader.payloadSize = sizeof(uint32_t);
                ackHeader.updateChecksum();

                send(clientSocket, reinterpret_cast<const char*>(&ackHeader), sizeof(ackHeader), 0);
                send(clientSocket, reinterpret_cast<const char*>(ack.data()), ack.size(), 0);

                // Broadcast join
                broadcast(MessageType::SessionJoin, payload, clientId);
            }
            // Forward other messages to all clients
            else if (header.type != MessageType::Disconnect) {
                header.senderId = clientId;
                header.updateChecksum();
                broadcast(header.type, payload, clientId);
            }
        }

        // Cleanup
        {
            std::lock_guard<std::mutex> lock(clientsMutex_);
            clients_.erase(clientId);
        }

        closesocket(clientSocket);

        // Broadcast leave
        broadcast(MessageType::SessionLeave, {}, clientId);
    }

    socket_t serverSocket_ = SOCKET_INVALID;
    std::atomic<bool> running_{false};
    std::thread acceptThread_;

    std::map<uint32_t, socket_t> clients_;
    mutable std::mutex clientsMutex_;
    std::atomic<uint32_t> nextClientId_{1};
};

} // namespace Bridge
} // namespace Echoelmusic
