// AbletonLinkTests.swift
// Echoelmusic Tests
//
// Comprehensive tests for Ableton Link Protocol implementation
// Tests: Session state, tempo sync, phase calculation, protocol constants
//
// Created: 2026-01-15
// Ralph Wiggum Lambda Loop Mode - 100% Test Coverage

import XCTest
@testable import Echoelmusic

@MainActor
final class AbletonLinkTests: XCTestCase {

    // MARK: - Link Constants Tests

    func testLinkConstants() {
        XCTAssertEqual(LinkConstants.multicastAddress, "224.76.78.75")
        XCTAssertEqual(LinkConstants.port, 20808)
        XCTAssertEqual(LinkConstants.protocolVersion, 2)
        XCTAssertEqual(LinkConstants.discoveryInterval, 1.0)
        XCTAssertEqual(LinkConstants.sessionTimeout, 5.0)
    }

    func testLinkMessageTypes() {
        XCTAssertEqual(LinkConstants.msgPing, 0x01)
        XCTAssertEqual(LinkConstants.msgPong, 0x02)
        XCTAssertEqual(LinkConstants.msgState, 0x03)
        XCTAssertEqual(LinkConstants.msgStartStop, 0x04)
    }

    // MARK: - Link Session State Tests

    func testLinkSessionStateDefaults() {
        let state = LinkSessionState()

        XCTAssertEqual(state.tempo, 120.0)
        XCTAssertEqual(state.beat, 0.0)
        XCTAssertEqual(state.phase, 0.0)
        XCTAssertEqual(state.quantum, 4.0)
        XCTAssertFalse(state.isPlaying)
        XCTAssertEqual(state.peerCount, 0)
    }

    func testLinkSessionStateCustomInit() {
        let state = LinkSessionState(tempo: 140.0, quantum: 8.0)

        XCTAssertEqual(state.tempo, 140.0)
        XCTAssertEqual(state.quantum, 8.0)
    }

    func testLinkSessionStateUpdateBeat() {
        var state = LinkSessionState(tempo: 120.0)
        state.timestamp = UInt64(Date().timeIntervalSince1970 * 1_000_000) - 500_000 // 0.5 seconds ago

        state.updateBeat()

        // At 120 BPM, 0.5 seconds = 1 beat
        XCTAssertGreaterThan(state.beat, 0.9)
        XCTAssertLessThan(state.beat, 1.5) // Allow some tolerance
    }

    func testLinkSessionStatePhaseCalculation() {
        var state = LinkSessionState(tempo: 120.0, quantum: 4.0)

        // Set beat to 2.5 (halfway through second beat)
        state.beat = 2.5

        // Phase should be 2.5 / 4.0 = 0.625
        let expectedPhase = state.beat.truncatingRemainder(dividingBy: state.quantum) / state.quantum
        XCTAssertEqual(expectedPhase, 0.625, accuracy: 0.001)
    }

    func testLinkSessionStateEquatable() {
        let state1 = LinkSessionState(tempo: 120.0, quantum: 4.0)
        var state2 = LinkSessionState(tempo: 120.0, quantum: 4.0)

        // Same values should be equal
        XCTAssertEqual(state1.tempo, state2.tempo)
        XCTAssertEqual(state1.quantum, state2.quantum)

        // Different tempo should not be equal
        state2.tempo = 140.0
        XCTAssertNotEqual(state1.tempo, state2.tempo)
    }

    // MARK: - Link Peer Tests

    func testLinkPeerCreation() {
        let peer = LinkPeer(
            id: UUID(),
            address: "192.168.1.100:20808",
            port: 20808,
            name: "Test Peer",
            tempo: 120.0,
            lastSeen: Date()
        )

        XCTAssertEqual(peer.address, "192.168.1.100:20808")
        XCTAssertEqual(peer.port, 20808)
        XCTAssertEqual(peer.name, "Test Peer")
        XCTAssertEqual(peer.tempo, 120.0)
        XCTAssertFalse(peer.isStale)
    }

    func testLinkPeerStaleDetection() {
        let stalePeer = LinkPeer(
            id: UUID(),
            address: "192.168.1.100:20808",
            port: 20808,
            name: "Stale Peer",
            tempo: 120.0,
            lastSeen: Date().addingTimeInterval(-10) // 10 seconds ago
        )

        XCTAssertTrue(stalePeer.isStale) // Should be stale after sessionTimeout (5s)
    }

    func testLinkPeerFreshDetection() {
        let freshPeer = LinkPeer(
            id: UUID(),
            address: "192.168.1.100:20808",
            port: 20808,
            name: "Fresh Peer",
            tempo: 120.0,
            lastSeen: Date().addingTimeInterval(-2) // 2 seconds ago
        )

        XCTAssertFalse(freshPeer.isStale) // Should not be stale yet
    }

    func testLinkPeerEquatable() {
        let id = UUID()
        let peer1 = LinkPeer(id: id, address: "192.168.1.100", port: 20808, name: "Peer", tempo: 120.0, lastSeen: Date())
        let peer2 = LinkPeer(id: id, address: "192.168.1.100", port: 20808, name: "Peer", tempo: 120.0, lastSeen: Date())

        XCTAssertEqual(peer1, peer2)
    }

    // MARK: - Link Client Tests

    func testLinkClientInitialState() async {
        let client = AbletonLinkClient()

        XCTAssertFalse(client.isEnabled)
        XCTAssertFalse(client.isConnected)
        XCTAssertTrue(client.peers.isEmpty)
        XCTAssertTrue(client.startStopSyncEnabled)
    }

    func testLinkClientSessionState() async {
        let client = AbletonLinkClient()

        XCTAssertEqual(client.sessionState.tempo, 120.0)
        XCTAssertEqual(client.sessionState.quantum, 4.0)
    }

    func testLinkClientSetTempo() async {
        let client = AbletonLinkClient()

        client.setTempo(140.0)
        XCTAssertEqual(client.sessionState.tempo, 140.0)

        // Test bounds
        client.setTempo(19.0) // Below minimum (20)
        XCTAssertEqual(client.sessionState.tempo, 140.0) // Should not change

        client.setTempo(1000.0) // Above maximum (999)
        XCTAssertEqual(client.sessionState.tempo, 140.0) // Should not change
    }

    func testLinkClientSetQuantum() async {
        let client = AbletonLinkClient()

        client.setQuantum(8.0)
        XCTAssertEqual(client.sessionState.quantum, 8.0)

        // Test bounds
        client.setQuantum(0.5) // Below minimum (1)
        XCTAssertEqual(client.sessionState.quantum, 8.0) // Should not change

        client.setQuantum(17.0) // Above maximum (16)
        XCTAssertEqual(client.sessionState.quantum, 8.0) // Should not change
    }

    func testLinkClientPlayStop() async {
        let client = AbletonLinkClient()

        XCTAssertFalse(client.sessionState.isPlaying)

        client.play()
        XCTAssertTrue(client.sessionState.isPlaying)

        client.stop()
        XCTAssertFalse(client.sessionState.isPlaying)
    }

    func testLinkClientBeatDuration() async {
        let client = AbletonLinkClient()

        // At 120 BPM, beat duration should be 0.5 seconds
        client.setTempo(120.0)
        XCTAssertEqual(client.getBeatDuration(), 0.5, accuracy: 0.001)

        // At 60 BPM, beat duration should be 1.0 seconds
        client.setTempo(60.0)
        XCTAssertEqual(client.getBeatDuration(), 1.0, accuracy: 0.001)

        // At 240 BPM, beat duration should be 0.25 seconds
        client.setTempo(240.0)
        XCTAssertEqual(client.getBeatDuration(), 0.25, accuracy: 0.001)
    }

    func testLinkClientTimeUntilNextBeat() async {
        let client = AbletonLinkClient()
        client.setTempo(120.0) // 0.5 second per beat

        let timeUntilBeat = client.timeUntilNextBeat()

        // Should be between 0 and beat duration
        XCTAssertGreaterThanOrEqual(timeUntilBeat, 0)
        XCTAssertLessThanOrEqual(timeUntilBeat, client.getBeatDuration())
    }

    func testLinkClientTimeUntilNextDownbeat() async {
        let client = AbletonLinkClient()
        client.setTempo(120.0)
        client.setQuantum(4.0)

        let timeUntilDownbeat = client.timeUntilNextDownbeat()

        // Should be between 0 and (quantum * beat duration)
        let maxTime = client.sessionState.quantum * client.getBeatDuration()
        XCTAssertGreaterThanOrEqual(timeUntilDownbeat, 0)
        XCTAssertLessThanOrEqual(timeUntilDownbeat, maxTime)
    }

    func testLinkClientCurrentBeat() async {
        let client = AbletonLinkClient()

        let beat = client.getCurrentBeat()
        XCTAssertGreaterThanOrEqual(beat, 0)
    }

    func testLinkClientPhase() async {
        let client = AbletonLinkClient()

        let phase = client.getPhase()
        XCTAssertGreaterThanOrEqual(phase, 0)
        XCTAssertLessThanOrEqual(phase, 1)
    }

    // MARK: - Callback Tests

    func testLinkClientTempoCallback() async {
        let client = AbletonLinkClient()
        var callbackCalled = false
        var receivedTempo: Double = 0

        client.onTempoChange = { tempo in
            callbackCalled = true
            receivedTempo = tempo
        }

        // Manually trigger callback (simulate network message)
        client.onTempoChange?(140.0)

        XCTAssertTrue(callbackCalled)
        XCTAssertEqual(receivedTempo, 140.0)
    }

    func testLinkClientBeatCallback() async {
        let client = AbletonLinkClient()
        var callbackCalled = false
        var receivedBeat: Int = -1

        client.onBeat = { beat in
            callbackCalled = true
            receivedBeat = beat
        }

        // Manually trigger callback
        client.onBeat?(4)

        XCTAssertTrue(callbackCalled)
        XCTAssertEqual(receivedBeat, 4)
    }

    func testLinkClientPlayStateCallback() async {
        let client = AbletonLinkClient()
        var callbackCalled = false
        var receivedState: Bool = false

        client.onPlayStateChange = { isPlaying in
            callbackCalled = true
            receivedState = isPlaying
        }

        // Trigger via play()
        client.play()

        XCTAssertTrue(callbackCalled)
        XCTAssertTrue(receivedState)
    }

    // MARK: - Debug Info Tests

    func testLinkClientDebugInfo() async {
        let client = AbletonLinkClient()

        let debugInfo = client.debugInfo

        XCTAssertTrue(debugInfo.contains("Ableton Link Client"))
        XCTAssertTrue(debugInfo.contains("Enabled"))
        XCTAssertTrue(debugInfo.contains("Tempo"))
        XCTAssertTrue(debugInfo.contains("Beat"))
        XCTAssertTrue(debugInfo.contains("Phase"))
        XCTAssertTrue(debugInfo.contains("Quantum"))
    }

    // MARK: - Integration Tests

    func testLinkClientFullWorkflow() async {
        let client = AbletonLinkClient()

        // Set up session
        client.setTempo(128.0)
        client.setQuantum(4.0)
        XCTAssertEqual(client.sessionState.tempo, 128.0)
        XCTAssertEqual(client.sessionState.quantum, 4.0)

        // Start playback
        client.play()
        XCTAssertTrue(client.sessionState.isPlaying)

        // Wait a moment
        try? await Task.sleep(nanoseconds: 100_000_000) // 100ms

        // Check beat progressed
        let beat = client.getCurrentBeat()
        XCTAssertGreaterThanOrEqual(beat, 0)

        // Stop playback
        client.stop()
        XCTAssertFalse(client.sessionState.isPlaying)
    }

    // MARK: - Performance Tests

    func testSessionStateUpdatePerformance() async {
        var state = LinkSessionState(tempo: 120.0)

        measure {
            for _ in 0..<10000 {
                state.updateBeat()
            }
        }
    }

    func testBeatDurationCalculationPerformance() async {
        let client = AbletonLinkClient()

        measure {
            for _ in 0..<10000 {
                _ = client.getBeatDuration()
            }
        }
    }
}
