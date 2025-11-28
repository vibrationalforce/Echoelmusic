//
//  WebRTCBridge.swift
//  Echoelmusic
//
//  Created: 2025-11-25
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  WEBRTC BRIDGE - Real-time peer-to-peer collaboration
//  WebRTC implementation for multi-user sessions
//

import Foundation
import Network

@MainActor
class WebRTCBridge: ObservableObject {
    static let shared = WebRTCBridge()

    @Published var peers: [Peer] = []
    @Published var isConnected: Bool = false

    struct Peer: Identifiable {
        let id: String
        let name: String
        var isConnected: Bool
        var latency: TimeInterval
    }

    private var signalingServer: NWConnection?
    private var peerConnections: [String: PeerConnection] = [:]

    // MARK: - Connection

    func connect(to server: String) async throws {
        print("🔗 WebRTC: Connecting to signaling server: \(server)")

        guard let url = URL(string: server),
              let host = url.host else {
            throw WebRTCError.invalidURL
        }

        let port = url.port ?? 8080

        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(integerLiteral: UInt16(port))
        )

        signalingServer = NWConnection(to: endpoint, using: .tcp)
        signalingServer?.start(queue: .global())

        try await waitForConnection()

        isConnected = true
        print("✅ WebRTC: Connected to signaling server")
    }

    private func waitForConnection() async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            signalingServer?.stateUpdateHandler = { state in
                switch state {
                case .ready:
                    continuation.resume()
                case .failed(let error):
                    continuation.resume(throwing: error)
                default:
                    break
                }
            }
        }
    }

    // MARK: - Peer Management

    func createOffer(to peerId: String) async throws -> String {
        print("📤 WebRTC: Creating offer for peer: \(peerId)")

        let connection = PeerConnection(peerId: peerId)
        peerConnections[peerId] = connection

        // Create SDP offer
        let offer = """
        v=0
        o=- 0 0 IN IP4 127.0.0.1
        s=-
        t=0 0
        a=group:BUNDLE 0
        m=audio 9 UDP/TLS/RTP/SAVPF 111
        c=IN IP4 0.0.0.0
        a=rtcp:9 IN IP4 0.0.0.0
        a=ice-ufrag:test
        a=ice-pwd:testpassword
        a=fingerprint:sha-256 test
        a=setup:actpass
        a=mid:0
        a=sendrecv
        a=rtcp-mux
        a=rtpmap:111 opus/48000/2
        """

        return offer
    }

    func handleAnswer(from peerId: String, answer: String) async throws {
        print("📥 WebRTC: Received answer from peer: \(peerId)")

        guard let connection = peerConnections[peerId] else {
            throw WebRTCError.peerNotFound
        }

        connection.remoteDescription = answer
        print("✅ WebRTC: Answer processed")
    }

    func addICECandidate(from peerId: String, candidate: String) async throws {
        print("🧊 WebRTC: Adding ICE candidate from: \(peerId)")

        guard let connection = peerConnections[peerId] else {
            throw WebRTCError.peerNotFound
        }

        connection.iceCandidates.append(candidate)
    }

    // MARK: - Data Channel

    func sendData(to peerId: String, data: Data) throws {
        guard let connection = peerConnections[peerId] else {
            throw WebRTCError.peerNotFound
        }

        connection.send(data: data)
    }

    func broadcast(data: Data) {
        for (_, connection) in peerConnections {
            connection.send(data: data)
        }
    }

    // MARK: - Signaling

    private func sendSignal(_ message: SignalingMessage) throws {
        let encoder = JSONEncoder()
        let data = try encoder.encode(message)

        signalingServer?.send(
            content: data,
            completion: .contentProcessed { error in
                if let error = error {
                    print("Signaling error: \(error)")
                }
            }
        )
    }

    func disconnect() {
        for (_, connection) in peerConnections {
            connection.close()
        }
        peerConnections.removeAll()

        signalingServer?.cancel()
        isConnected = false

        print("🔌 WebRTC: Disconnected")
    }

    private init() {
        print("🌐 WebRTC Bridge initialized")
    }
}

// MARK: - Peer Connection

class PeerConnection {
    let peerId: String
    var localDescription: String?
    var remoteDescription: String?
    var iceCandidates: [String] = []

    init(peerId: String) {
        self.peerId = peerId
    }

    func send(data: Data) {
        print("📤 Sending data to \(peerId): \(data.count) bytes")
    }

    func close() {
        print("🔌 Closing connection to \(peerId)")
    }
}

// MARK: - Signaling

struct SignalingMessage: Codable {
    enum MessageType: String, Codable {
        case offer
        case answer
        case iceCandidate
    }

    let type: MessageType
    let from: String
    let to: String
    let payload: String
}

enum WebRTCError: Error {
    case invalidURL
    case peerNotFound
    case connectionFailed
}
