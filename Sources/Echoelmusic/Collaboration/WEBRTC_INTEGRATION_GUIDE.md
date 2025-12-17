# WebRTC Integration Guide for CollaborationEngine

## Current Status: 85% Complete (Stub Implementations)

CollaborationEngine's architecture is production-ready but uses stub implementations for WebRTC peer connections and signaling. This guide covers completing the final 15%.

---

## Missing Components

### 1. WebRTC Client Implementation (Lines 333-370)

**Current Code:**
```swift
class WebRTCClient {
    func createOffer() async throws {
        // In production: Create WebRTC offer SDP
        print("📤 WebRTCClient: Creating offer")
    }

    func sendData(_ data: Data, channel: DataChannel) {
        // In production: Send via data channel
        print("📡 WebRTCClient: Sending \(data.count) bytes")
    }
}
```

**Needed:**
```swift
import WebRTC  // Google WebRTC framework

class WebRTCClient {
    private var peerConnection: RTCPeerConnection?
    private var dataChannels: [DataChannel: RTCDataChannel] = [:]

    func createOffer() async throws {
        let constraints = RTCMediaConstraints(...)
        let offer = try await peerConnection.offer(for: constraints)
        try await peerConnection.setLocalDescription(offer)
        // Send offer via signaling
    }
}
```

### 2. Signaling Client Implementation (Lines 382-419)

**Current Code:**
```swift
class SignalingClient {
    func connect() async throws {
        // In production: Connect to WebSocket
        print("🔌 SignalingClient: Connecting to \(url)")
    }
}
```

**Needed:**
```swift
import Network  // Apple's WebSocket API

class SignalingClient {
    private var webSocket: URLSessionWebSocketTask?

    func connect() async throws {
        let url = URL(string: self.url)!
        webSocket = URLSession.shared.webSocketTask(with: url)
        webSocket?.resume()
        startReceiving()
    }

    func sendOffer(sdp: String) async throws {
        let message = SignalingMessage.offer(sdp: sdp)
        let data = try JSONEncoder().encode(message)
        try await webSocket?.send(.data(data))
    }
}
```

---

## Integration Options

### Option 1: Google WebRTC Framework (Recommended)

**Pros:**
- Official WebRTC implementation
- Full feature support (audio, video, data channels)
- Cross-platform (iOS, macOS, Android, Windows, Linux)
- Battle-tested by Google Meet, Zoom, Discord

**Cons:**
- Large binary size (~100 MB)
- Complex C++ API with Swift wrapper
- BSD license (permissive)

**Swift Package Manager Integration:**
```swift
// In Package.swift
dependencies: [
    .package(url: "https://github.com/stasel/WebRTC.git", from: "119.0.0")
]
```

**CocoaPods Integration:**
```ruby
# In Podfile
pod 'GoogleWebRTC', '~> 1.1'
```

### Option 2: Swift Native WebRTC (starscream + libdatachannel)

**Pros:**
- Pure Swift API
- Smaller binary size
- Easier integration with Swift Concurrency (async/await)

**Cons:**
- Less mature than Google WebRTC
- May lack some advanced features
- Smaller community

**Swift Package Manager:**
```swift
dependencies: [
    .package(url: "https://github.com/stasel/WebRTC-ios.git", from: "1.0.0")
]
```

### Option 3: Hybrid (Apple Network Framework + WebRTC)

Use Apple's Network framework for WebSocket signaling, Google WebRTC for peer connections:

```swift
import Network  // Signaling
import WebRTC   // Peer connections

// Best of both worlds
```

---

## Implementation Plan

### Phase 1: WebSocket Signaling Client (3-4 hours)

Complete `SignalingClient.swift`:

```swift
import Foundation

class SignalingClient {
    private var webSocket: URLSessionWebSocketTask?
    private var isConnected = false
    weak var delegate: SignalingClientDelegate?

    private let url: String

    init(url: String) {
        self.url = url
    }

    // MARK: - Connection

    func connect() async throws {
        guard let wsURL = URL(string: url) else {
            throw SignalingError.invalidURL
        }

        webSocket = URLSession.shared.webSocketTask(with: wsURL)
        webSocket?.resume()
        isConnected = true

        print("🔌 SignalingClient: Connected to \(url)")

        // Start receiving messages
        Task {
            await receiveMessages()
        }
    }

    func disconnect() {
        webSocket?.cancel(with: .goingAway, reason: nil)
        isConnected = false
        print("👋 SignalingClient: Disconnected")
    }

    // MARK: - Message Handling

    private func receiveMessages() async {
        while isConnected {
            do {
                let message = try await webSocket?.receive()

                switch message {
                case .data(let data):
                    await handleMessage(data: data)
                case .string(let string):
                    if let data = string.data(using: .utf8) {
                        await handleMessage(data: data)
                    }
                default:
                    break
                }
            } catch {
                print("❌ SignalingClient: Receive error: \(error)")
                isConnected = false
            }
        }
    }

    private func handleMessage(data: Data) async {
        guard let message = try? JSONDecoder().decode(SignalingMessage.self, from: data) else {
            return
        }

        switch message.type {
        case "offer":
            delegate?.signalingClient(self, didReceiveOffer: message.sdp ?? "")

        case "answer":
            delegate?.signalingClient(self, didReceiveAnswer: message.sdp ?? "")

        case "candidate":
            if let candidate = message.candidate {
                delegate?.signalingClient(self, didReceiveCandidate: candidate)
            }

        case "participant-joined":
            if let participant = message.participant {
                delegate?.signalingClient(self, participantJoined: participant)
            }

        case "participant-left":
            if let participantID = message.participantID {
                delegate?.signalingClient(self, participantLeft: participantID)
            }

        default:
            break
        }
    }

    // MARK: - Sending Messages

    func sendOffer(sdp: String) async throws {
        let message = SignalingMessage(type: "offer", sdp: sdp)
        try await send(message: message)
    }

    func sendAnswer(sdp: String) async throws {
        let message = SignalingMessage(type: "answer", sdp: sdp)
        try await send(message: message)
    }

    func sendCandidate(_ candidate: ICECandidate) async throws {
        let message = SignalingMessage(type: "candidate", candidate: candidate)
        try await send(message: message)
    }

    func joinRoom(sessionID: UUID) async throws {
        let message = SignalingMessage(type: "join", sessionID: sessionID)
        try await send(message: message)
    }

    func joinWithCode(_ code: String) async throws {
        let message = SignalingMessage(type: "join-code", roomCode: code)
        try await send(message: message)
    }

    private func send(message: SignalingMessage) async throws {
        guard isConnected else {
            throw SignalingError.notConnected
        }

        let data = try JSONEncoder().encode(message)
        let wsMessage = URLSessionWebSocketTask.Message.data(data)
        try await webSocket?.send(wsMessage)

        print("📤 SignalingClient: Sent \(message.type)")
    }
}

// MARK: - Signaling Message

struct SignalingMessage: Codable {
    let type: String
    var sdp: String?
    var candidate: ICECandidate?
    var sessionID: UUID?
    var roomCode: String?
    var participant: Participant?
    var participantID: UUID?
}

enum SignalingError: Error {
    case invalidURL
    case notConnected
    case encodingFailed
}
```

### Phase 2: WebRTC Client Implementation (6-8 hours)

Complete `WebRTCClient.swift`:

```swift
import Foundation
import WebRTC

class WebRTCClient {

    // MARK: - Properties

    weak var delegate: WebRTCClientDelegate?

    private let iceServers: [ICEServer]
    private var peerConnection: RTCPeerConnection?
    private var dataChannels: [DataChannel: RTCDataChannel] = [:]

    private static let factory: RTCPeerConnectionFactory = {
        RTCInitializeSSL()
        return RTCPeerConnectionFactory()
    }()

    // MARK: - Initialization

    init(iceServers: [ICEServer]) {
        self.iceServers = iceServers
        setupPeerConnection()
    }

    deinit {
        disconnect()
        RTCCleanupSSL()
    }

    // MARK: - Setup

    private func setupPeerConnection() {
        let config = RTCConfiguration()
        config.iceServers = iceServers.map { server in
            RTCIceServer(urlStrings: server.urls,
                        username: server.username,
                        credential: server.credential)
        }

        config.sdpSemantics = .unifiedPlan
        config.continualGatheringPolicy = .gatherContinually

        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: ["DtlsSrtpKeyAgreement": "true"]
        )

        peerConnection = Self.factory.peerConnection(
            with: config,
            constraints: constraints,
            delegate: self
        )

        // Create data channels
        createDataChannels()

        print("🔌 WebRTCClient: Peer connection created")
    }

    private func createDataChannels() {
        let channels: [DataChannel] = [.audio, .midi, .bio, .chat, .control]

        for channel in channels {
            let config = RTCDataChannelConfiguration()
            config.isOrdered = true
            config.maxRetransmits = 3

            if let dataChannel = peerConnection?.dataChannel(
                forLabel: channel.rawValue,
                configuration: config
            ) {
                dataChannel.delegate = self
                dataChannels[channel] = dataChannel
            }
        }

        print("📡 WebRTCClient: Created \(dataChannels.count) data channels")
    }

    // MARK: - Signaling

    func createOffer() async throws {
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: [
                "OfferToReceiveAudio": "false",
                "OfferToReceiveVideo": "false"
            ],
            optionalConstraints: nil
        )

        guard let peerConnection = peerConnection else {
            throw WebRTCError.noPeerConnection
        }

        let offer = try await peerConnection.offer(for: constraints)
        try await peerConnection.setLocalDescription(offer)

        print("📤 WebRTCClient: Created offer")
    }

    func handleOffer(sdp: String) async throws {
        let sessionDescription = RTCSessionDescription(type: .offer, sdp: sdp)

        guard let peerConnection = peerConnection else {
            throw WebRTCError.noPeerConnection
        }

        try await peerConnection.setRemoteDescription(sessionDescription)

        // Create answer
        let constraints = RTCMediaConstraints(
            mandatoryConstraints: nil,
            optionalConstraints: nil
        )

        let answer = try await peerConnection.answer(for: constraints)
        try await peerConnection.setLocalDescription(answer)

        print("📥 WebRTCClient: Handled offer, created answer")
    }

    func handleAnswer(sdp: String) async throws {
        let sessionDescription = RTCSessionDescription(type: .answer, sdp: sdp)

        guard let peerConnection = peerConnection else {
            throw WebRTCError.noPeerConnection
        }

        try await peerConnection.setRemoteDescription(sessionDescription)

        print("📥 WebRTCClient: Handled answer")
    }

    func addCandidate(_ candidate: ICECandidate) {
        let iceCandidate = RTCIceCandidate(
            sdp: candidate.candidate,
            sdpMLineIndex: Int32(candidate.sdpMLineIndex),
            sdpMid: candidate.sdpMid
        )

        peerConnection?.add(iceCandidate)
        print("🧊 WebRTCClient: Added ICE candidate")
    }

    // MARK: - Data Sending

    func sendData(_ data: Data, channel: DataChannel) {
        guard let dataChannel = dataChannels[channel] else {
            print("❌ WebRTCClient: Data channel \(channel.rawValue) not found")
            return
        }

        guard dataChannel.readyState == .open else {
            print("⚠️ WebRTCClient: Data channel \(channel.rawValue) not open")
            return
        }

        let buffer = RTCDataBuffer(data: data, isBinary: true)
        dataChannel.sendData(buffer)

        print("📡 WebRTCClient: Sent \(data.count) bytes on \(channel.rawValue)")
    }

    // MARK: - Connection Management

    func disconnect() {
        dataChannels.values.forEach { $0.close() }
        dataChannels.removeAll()
        peerConnection?.close()
        peerConnection = nil

        print("🔌 WebRTCClient: Disconnected")
    }
}

// MARK: - RTCPeerConnectionDelegate

extension WebRTCClient: RTCPeerConnectionDelegate {

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange state: RTCPeerConnectionState) {
        print("🔄 WebRTCClient: Connection state: \(state)")

        let mappedState: CollaborationEngine.ConnectionState = {
            switch state {
            case .new, .connecting:
                return .connecting
            case .connected:
                return .connected
            case .disconnected:
                return .disconnected
            case .failed:
                return .failed
            case .closed:
                return .disconnected
            @unknown default:
                return .disconnected
            }
        }()

        delegate?.webRTCClient(self, didChangeConnectionState: mappedState)
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didGenerate candidate: RTCIceCandidate) {
        let iceCandidate = ICECandidate(
            sdpMid: candidate.sdpMid ?? "",
            sdpMLineIndex: Int(candidate.sdpMLineIndex),
            candidate: candidate.sdp
        )

        delegate?.webRTCClient(self, didGenerateCandidate: iceCandidate)
        print("🧊 WebRTCClient: Generated ICE candidate")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange state: RTCIceConnectionState) {
        print("🧊 WebRTCClient: ICE connection state: \(state)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didChange state: RTCIceGatheringState) {
        print("🧊 WebRTCClient: ICE gathering state: \(state)")
    }

    func peerConnection(_ peerConnection: RTCPeerConnection, didOpen dataChannel: RTCDataChannel) {
        print("📡 WebRTCClient: Data channel opened: \(dataChannel.label)")
        dataChannel.delegate = self
    }

    // Required but unused for data-only WebRTC
    func peerConnection(_ peerConnection: RTCPeerConnection, didAdd stream: RTCMediaStream) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove stream: RTCMediaStream) {}
    func peerConnectionShouldNegotiate(_ peerConnection: RTCPeerConnection) {}
    func peerConnection(_ peerConnection: RTCPeerConnection, didRemove candidates: [RTCIceCandidate]) {}
}

// MARK: - RTCDataChannelDelegate

extension WebRTCClient: RTCDataChannelDelegate {

    func dataChannelDidChangeState(_ dataChannel: RTCDataChannel) {
        print("📡 WebRTCClient: Data channel \(dataChannel.label) state: \(dataChannel.readyState)")
    }

    func dataChannel(_ dataChannel: RTCDataChannel, didReceiveMessageWith buffer: RTCDataBuffer) {
        guard let channel = DataChannel(rawValue: dataChannel.label) else {
            return
        }

        delegate?.webRTCClient(self, didReceiveData: buffer.data, channel: channel)
        print("📥 WebRTCClient: Received \(buffer.data.count) bytes on \(channel.rawValue)")
    }
}

// MARK: - Errors

enum WebRTCError: Error {
    case noPeerConnection
    case offerCreationFailed
    case answerCreationFailed
}
```

### Phase 3: Signaling Server (Node.js) (4-6 hours)

Create `signaling-server/server.js`:

```javascript
const WebSocket = require('ws');
const http = require('http');
const { v4: uuidv4 } = require('uuid');

const server = http.createServer();
const wss = new WebSocket.Server({ server });

// Room management
const rooms = new Map(); // roomID -> { host, clients: Set }
const roomCodes = new Map(); // code -> roomID

// WebSocket connection handler
wss.on('connection', (ws) => {
    let clientID = uuidv4();
    let currentRoom = null;

    console.log(`✅ Client connected: ${clientID}`);

    ws.on('message', async (data) => {
        try {
            const message = JSON.parse(data);

            switch (message.type) {
                case 'create-room':
                    handleCreateRoom(ws, clientID, message);
                    break;

                case 'join':
                    handleJoinRoom(ws, clientID, message);
                    break;

                case 'join-code':
                    handleJoinWithCode(ws, clientID, message);
                    break;

                case 'offer':
                case 'answer':
                case 'candidate':
                    handleSignaling(ws, currentRoom, message);
                    break;

                case 'leave':
                    handleLeave(clientID, currentRoom);
                    break;
            }
        } catch (error) {
            console.error('❌ Message handling error:', error);
        }
    });

    ws.on('close', () => {
        console.log(`👋 Client disconnected: ${clientID}`);
        if (currentRoom) {
            handleLeave(clientID, currentRoom);
        }
    });

    // Room handlers
    function handleCreateRoom(ws, clientID, message) {
        const roomID = uuidv4();
        const roomCode = generateRoomCode();

        rooms.set(roomID, {
            host: clientID,
            clients: new Set([clientID]),
            hostWS: ws
        });

        roomCodes.set(roomCode, roomID);
        currentRoom = roomID;

        ws.send(JSON.stringify({
            type: 'room-created',
            roomID: roomID,
            roomCode: roomCode
        }));

        console.log(`🚪 Room created: ${roomCode} (${roomID})`);
    }

    function handleJoinRoom(ws, clientID, message) {
        const room = rooms.get(message.sessionID);

        if (!room) {
            ws.send(JSON.stringify({ type: 'error', message: 'Room not found' }));
            return;
        }

        room.clients.add(clientID);
        currentRoom = message.sessionID;

        // Notify host
        room.hostWS.send(JSON.stringify({
            type: 'participant-joined',
            participant: { id: clientID, name: message.name || 'Guest' }
        }));

        console.log(`👋 Client ${clientID} joined room ${message.sessionID}`);
    }

    function handleJoinWithCode(ws, clientID, message) {
        const roomID = roomCodes.get(message.roomCode);

        if (!roomID) {
            ws.send(JSON.stringify({ type: 'error', message: 'Invalid room code' }));
            return;
        }

        handleJoinRoom(ws, clientID, { ...message, sessionID: roomID });
    }

    function handleSignaling(ws, roomID, message) {
        if (!roomID) return;

        const room = rooms.get(roomID);
        if (!room) return;

        // Broadcast to all other clients in room
        room.clients.forEach(clientWS => {
            if (clientWS !== ws) {
                clientWS.send(JSON.stringify(message));
            }
        });
    }

    function handleLeave(clientID, roomID) {
        if (!roomID) return;

        const room = rooms.get(roomID);
        if (!room) return;

        room.clients.delete(clientID);

        // Notify others
        room.clients.forEach(clientWS => {
            clientWS.send(JSON.stringify({
                type: 'participant-left',
                participantID: clientID
            }));
        });

        // Clean up empty rooms
        if (room.clients.size === 0) {
            rooms.delete(roomID);
            roomCodes.forEach((id, code) => {
                if (id === roomID) roomCodes.delete(code);
            });
        }
    }
});

// Helper: Generate 6-character room code
function generateRoomCode() {
    const chars = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
    return Array.from({ length: 6 }, () =>
        chars[Math.floor(Math.random() * chars.length)]
    ).join('');
}

// Start server
const PORT = process.env.PORT || 8080;
server.listen(PORT, () => {
    console.log(`🚀 Signaling server running on port ${PORT}`);
});
```

**Package.json:**
```json
{
  "name": "echoelmusic-signaling",
  "version": "1.0.0",
  "dependencies": {
    "ws": "^8.14.0",
    "uuid": "^9.0.0"
  },
  "scripts": {
    "start": "node server.js"
  }
}
```

### Phase 4: Testing (2-3 hours)

**Local Testing Setup:**

1. Start signaling server:
```bash
cd signaling-server
npm install
npm start
# Server running on ws://localhost:8080
```

2. Update CollaborationEngine.swift:
```swift
private let signalingURL = "ws://localhost:8080"  // Local testing
```

3. Test scenario:
```swift
// Device 1 (Host)
let engine1 = CollaborationEngine()
try await engine1.createSession(as: true)
print("Room code: \(engine1.currentSession?.roomCode)")

// Device 2 (Guest)
let engine2 = CollaborationEngine()
try await engine2.joinWithCode("ABC123")

// Send data
engine1.sendMIDIData(midiData)
```

---

## Build Instructions

### iOS/macOS (Swift Package Manager)

Add to `Package.swift`:
```swift
dependencies: [
    .package(url: "https://github.com/stasel/WebRTC.git", from: "119.0.0")
],
targets: [
    .target(
        name: "Echoelmusic",
        dependencies: ["WebRTC"]
    )
]
```

### iOS/macOS (CocoaPods)

Create `Podfile`:
```ruby
platform :ios, '14.0'

target 'Echoelmusic' do
  use_frameworks!

  pod 'GoogleWebRTC', '~> 1.1'
end
```

Install:
```bash
pod install
```

### Signaling Server (Node.js)

```bash
cd signaling-server
npm install
node server.js
```

**Production Deployment:**
- Use nginx reverse proxy for SSL (wss://)
- Deploy on AWS EC2, DigitalOcean, or Heroku
- Add TURN servers for NAT traversal
- Implement authentication and room passwords

---

## Quick Win Implementation (3-4 hours)

For immediate local testing without signaling server:

```swift
// Local WebRTC connection (same device)
class LocalWebRTCTest {
    let peer1 = WebRTCClient(iceServers: [])
    let peer2 = WebRTCClient(iceServers: [])

    func test() async throws {
        // Peer 1 creates offer
        try await peer1.createOffer()
        let offer = peer1.localDescription

        // Peer 2 receives offer and creates answer
        try await peer2.handleOffer(sdp: offer)
        let answer = peer2.localDescription

        // Peer 1 receives answer
        try await peer1.handleAnswer(sdp: answer)

        // Exchange ICE candidates directly
        peer1.onICECandidate = { candidate in
            peer2.addCandidate(candidate)
        }
        peer2.onICECandidate = { candidate in
            peer1.addCandidate(candidate)
        }

        // Test data sending
        peer1.sendData("Hello".data(using: .utf8)!, channel: .chat)
    }
}
```

---

## Performance & Optimization

### Target Metrics:
- **Latency**: <20ms LAN, <50ms Internet
- **Throughput**: 1 Mbps per channel (audio streaming)
- **Connection time**: <2 seconds
- **CPU usage**: <5% per peer connection

### Optimization Strategies:

1. **Data Channel Settings:**
```swift
config.maxRetransmits = 0  // For audio (prefer low latency)
config.isOrdered = false   // For bio-data
```

2. **Message Batching:**
```swift
// Batch MIDI messages (send every 10ms)
var midiBuffer: [Data] = []
Timer.scheduledTimer(withTimeInterval: 0.01) {
    if !midiBuffer.isEmpty {
        sendBatchedMIDI(midiBuffer)
        midiBuffer.removeAll()
    }
}
```

3. **Compression:**
```swift
// Compress large payloads
import Compression
let compressed = data.compressed(using: .lz4)
```

---

## Security Considerations

**1. STUN/TURN Server Security:**
```swift
// Use authenticated TURN servers
ICEServer(
    urls: ["turn:turn.echoelmusic.com:3478"],
    username: "time-limited-username",
    credential: "generated-token"
)
```

**2. End-to-End Encryption:**
WebRTC uses DTLS-SRTP by default, but add application-level encryption for sensitive bio-data:

```swift
import CryptoKit

func encryptBioData(_ data: Data) -> Data {
    let key = SymmetricKey(size: .bits256)
    let sealed = try! AES.GCM.seal(data, using: key)
    return sealed.combined!
}
```

**3. Room Code Brute-Force Protection:**
```javascript
// In signaling server
const rateLimiter = new Map(); // clientIP -> attempts

function checkRateLimit(ip) {
    const attempts = rateLimiter.get(ip) || 0;
    if (attempts > 10) {
        throw new Error('Too many attempts');
    }
    rateLimiter.set(ip, attempts + 1);
}
```

---

## Troubleshooting

**Problem: "Failed to create peer connection"**
```swift
// Solution: Check ICE server configuration
print(peerConnection?.configuration.iceServers)

// Verify STUN servers are reachable
curl -v telnet://stun.l.google.com:19302
```

**Problem: "Data channel not opening"**
```swift
// Solution: Ensure both sides create the same data channels
// OR: Only the offering side creates channels, answering side receives them
```

**Problem: "High latency (>100ms)"**
- Check network: `ping 8.8.8.8`
- Use TURN server if behind NAT
- Reduce data channel message size
- Disable retransmissions for real-time data

**Problem: "Connection drops frequently"**
```swift
// Solution: Implement reconnection logic
func handleConnectionFailure() {
    Task {
        try await Task.sleep(nanoseconds: 2_000_000_000) // 2s
        try await reconnect()
    }
}
```

---

## Summary

**Current Status:**
- ✅ CollaborationEngine architecture complete (85%)
- ✅ Data models and protocols complete
- ✅ Group bio-sync logic complete
- ⚠️ WebRTCClient: stub implementation (15% missing)
- ⚠️ SignalingClient: stub implementation (15% missing)
- ❌ Signaling server: needs implementation

**To Reach 100%:**
1. Implement SignalingClient with WebSocket (3-4 hours)
2. Implement WebRTCClient with Google WebRTC (6-8 hours)
3. Create Node.js signaling server (4-6 hours)
4. Local testing (2-3 hours)
5. Production deployment (signaling server + TURN) (4-6 hours)

**Total Effort:** 19-27 hours (2-3 days)

**Quick Win (3-4 hours):**
- Implement local WebRTC test (same device, no signaling)
- Gets peer connection working immediately
- Can test data channels, latency, group bio-sync

---

## Resources

**WebRTC Documentation:**
- Official: https://webrtc.org/getting-started/overview
- Google WebRTC iOS: https://github.com/stasel/WebRTC
- Swift WebRTC examples: https://github.com/stasel/WebRTC-Example

**Signaling Servers:**
- Socket.io: https://socket.io/
- Simple WebSocket: https://github.com/websockets/ws
- Production: Janus Gateway, Jitsi, Mediasoup

**TURN Servers:**
- Coturn (open source): https://github.com/coturn/coturn
- Twilio TURN: https://www.twilio.com/docs/stun-turn
- Xirsys: https://xirsys.com/

**Testing Tools:**
- WebRTC Troubleshooter: https://test.webrtc.org/
- Wireshark (packet analysis)
- Network Link Conditioner (iOS latency simulation)
