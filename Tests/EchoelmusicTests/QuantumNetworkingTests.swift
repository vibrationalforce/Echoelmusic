// QuantumNetworkingTests.swift
// Echoelmusic - Quantum Networking Tests
// SPDX-License-Identifier: MIT

import XCTest
import Combine
@testable import Echoelmusic

final class QuantumNetworkingTests: XCTestCase {

    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        cancellables = Set<AnyCancellable>()
    }

    override func tearDown() {
        cancellables = nil
        super.tearDown()
    }

    // MARK: - mDNS Discovery Tests

    func testMDNSServiceTypeProperties() {
        XCTAssertEqual(MDNSDiscovery.ServiceType.echoelmusic.rawValue, "_echoelmusic._tcp")
        XCTAssertEqual(MDNSDiscovery.ServiceType.abletonLink.rawValue, "_ableton-link._udp")
        XCTAssertEqual(MDNSDiscovery.ServiceType.midi.rawValue, "_apple-midi._udp")
    }

    func testMDNSServiceTypeDisplayNames() {
        XCTAssertEqual(MDNSDiscovery.ServiceType.echoelmusic.displayName, "Echoelmusic")
        XCTAssertEqual(MDNSDiscovery.ServiceType.abletonLink.displayName, "Ableton Link")
        XCTAssertEqual(MDNSDiscovery.ServiceType.airplay.displayName, "AirPlay")
    }

    func testMDNSDiscoveryGetServices() async {
        let discovery = MDNSDiscovery()
        let services = await discovery.getServices()
        // Initially should be empty
        XCTAssertTrue(services.isEmpty)
    }

    func testMDNSDiscoveryFilterByType() async {
        let discovery = MDNSDiscovery()
        let echoelServices = await discovery.getServices(of: .echoelmusic)
        let linkServices = await discovery.getServices(of: .abletonLink)

        XCTAssertTrue(echoelServices.isEmpty)
        XCTAssertTrue(linkServices.isEmpty)
    }

    // MARK: - mDNS Advertiser Tests

    func testMDNSServiceInfo() {
        let serviceInfo = MDNSAdvertiser.ServiceInfo(
            name: "Test Service",
            port: 8080,
            txtRecord: ["version": "1.0", "platform": "iOS"]
        )

        XCTAssertEqual(serviceInfo.name, "Test Service")
        XCTAssertEqual(serviceInfo.port, 8080)
        XCTAssertEqual(serviceInfo.txtRecord["version"], "1.0")
    }

    // MARK: - Ableton Link Tests

    func testAbletonLinkInitialState() async {
        let link = AbletonLinkManager()
        let state = await link.getState()

        XCTAssertFalse(state.isEnabled)
        XCTAssertEqual(state.numPeers, 0)
        XCTAssertEqual(state.tempo, 120.0)
        XCTAssertEqual(state.quantum, 4.0)
        XCTAssertFalse(state.isPlaying)
    }

    func testAbletonLinkEnable() async {
        let link = AbletonLinkManager()
        await link.enable()
        let state = await link.getState()

        XCTAssertTrue(state.isEnabled)
    }

    func testAbletonLinkDisable() async {
        let link = AbletonLinkManager()
        await link.enable()
        await link.disable()
        let state = await link.getState()

        XCTAssertFalse(state.isEnabled)
        XCTAssertEqual(state.numPeers, 0)
    }

    func testAbletonLinkSetTempo() async {
        let link = AbletonLinkManager()

        // Valid tempo
        try? await link.setTempo(140)
        XCTAssertEqual(await link.getState().tempo, 140)

        // Invalid tempo should throw
        do {
            try await link.setTempo(500)
            XCTFail("Should have thrown for invalid tempo")
        } catch AbletonLinkManager.LinkError.invalidTempo {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }

        do {
            try await link.setTempo(10)
            XCTFail("Should have thrown for invalid tempo")
        } catch AbletonLinkManager.LinkError.invalidTempo {
            // Expected
        } catch {
            XCTFail("Unexpected error: \(error)")
        }
    }

    func testAbletonLinkPlayState() async {
        let link = AbletonLinkManager()

        await link.setPlaying(true, time: 0)
        XCTAssertTrue(await link.getState().isPlaying)

        await link.setPlaying(false, time: 0)
        XCTAssertFalse(await link.getState().isPlaying)
    }

    func testAbletonLinkStatePublisher() async {
        let link = AbletonLinkManager()
        let expectation = XCTestExpectation(description: "State update received")

        await link.statePublisher
            .dropFirst() // Skip initial value
            .sink { state in
                if state.tempo == 150 {
                    expectation.fulfill()
                }
            }
            .store(in: &cancellables)

        await link.simulateTempoUpdate(150)

        await fulfillment(of: [expectation], timeout: 1.0)
    }

    func testAbletonLinkTempoCallback() async {
        let link = AbletonLinkManager()
        let expectation = XCTestExpectation(description: "Tempo callback called")
        var receivedTempo: Double = 0

        await link.onTempoChange { tempo in
            receivedTempo = tempo
            expectation.fulfill()
        }

        await link.simulateTempoUpdate(135)

        await fulfillment(of: [expectation], timeout: 1.0)
        XCTAssertEqual(receivedTempo, 135)
    }

    // MARK: - WebRTC Signaling Tests

    func testWebRTCSignalMessage() {
        let message = WebRTCSignaling.SignalMessage(
            type: .offer,
            peerId: "peer-123",
            payload: "{\"sdp\": \"test\"}"
        )

        XCTAssertEqual(message.type, .offer)
        XCTAssertEqual(message.peerId, "peer-123")
        XCTAssertFalse(message.payload.isEmpty)
    }

    func testWebRTCSignalingLocalPeerId() async {
        let signaling = WebRTCSignaling()
        let peerId = await signaling.getLocalPeerId()

        XCTAssertFalse(peerId.isEmpty)
    }

    // MARK: - Real-Time Audio Transport Tests

    func testAudioTransportConfig() {
        let config = RealTimeAudioTransport.TransportConfig()

        XCTAssertEqual(config.sampleRate, 48000)
        XCTAssertEqual(config.channelCount, 2)
        XCTAssertEqual(config.bufferSize, 256)
        XCTAssertEqual(config.codec, .opus)
    }

    func testAudioTransportSendReceive() async {
        let transport = RealTimeAudioTransport()
        await transport.startStreaming()

        let samples: [Float] = [0.1, 0.2, 0.3, 0.4, 0.5]
        let packet = await transport.send(samples: samples, timestamp: 0)

        XCTAssertEqual(packet.sequenceNumber, 1)
        XCTAssertFalse(packet.data.isEmpty)
    }

    func testAudioTransportStats() async {
        let transport = RealTimeAudioTransport()
        await transport.startStreaming()

        // Send some packets
        for i in 0..<10 {
            _ = await transport.send(samples: [Float(i) * 0.1], timestamp: UInt64(i * 1000))
        }

        let stats = await transport.getStats()
        XCTAssertEqual(stats.sent, 10)
    }

    func testAudioTransportPacketLoss() async {
        let transport = RealTimeAudioTransport()
        let lossPercent = await transport.getPacketLossPercent()

        XCTAssertEqual(lossPercent, 0) // No packets sent yet
    }

    // MARK: - Network Quality Monitor Tests

    func testNetworkQualityLevelOrdering() {
        XCTAssertTrue(NetworkQualityMonitor.QualityLevel.excellent > .good)
        XCTAssertTrue(NetworkQualityMonitor.QualityLevel.good > .fair)
        XCTAssertTrue(NetworkQualityMonitor.QualityLevel.fair > .poor)
        XCTAssertTrue(NetworkQualityMonitor.QualityLevel.poor > .offline)
    }

    func testNetworkQualityRecommendations() {
        XCTAssertEqual(NetworkQualityMonitor.QualityLevel.excellent.recommendedBitrate, 256000)
        XCTAssertEqual(NetworkQualityMonitor.QualityLevel.poor.recommendedBitrate, 64000)
        XCTAssertEqual(NetworkQualityMonitor.QualityLevel.offline.recommendedBitrate, 0)

        XCTAssertEqual(NetworkQualityMonitor.QualityLevel.excellent.recommendedBufferMs, 10)
        XCTAssertEqual(NetworkQualityMonitor.QualityLevel.poor.recommendedBufferMs, 100)
    }

    func testNetworkQualityMonitorInitialStats() async {
        let monitor = NetworkQualityMonitor()
        let stats = await monitor.getStats()

        XCTAssertEqual(stats.latencyMs, 0)
        XCTAssertEqual(stats.jitterMs, 0)
        XCTAssertEqual(stats.packetLossPercent, 0)
    }

    func testNetworkQualityMonitorLatencyUpdate() async {
        let monitor = NetworkQualityMonitor()

        await monitor.updateLatency(25)
        let stats = await monitor.getStats()

        XCTAssertEqual(stats.latencyMs, 25)
    }

    func testNetworkQualityMonitorPacketLossUpdate() async {
        let monitor = NetworkQualityMonitor()

        await monitor.updatePacketLoss(2.5)
        let stats = await monitor.getStats()

        XCTAssertEqual(stats.packetLossPercent, 2.5)
    }

    func testNetworkQualityMonitorBandwidthUpdate() async {
        let monitor = NetworkQualityMonitor()

        await monitor.updateBandwidth(1_000_000)
        let stats = await monitor.getStats()

        XCTAssertEqual(stats.bandwidthBps, 1_000_000)
    }

    // MARK: - Audio Codec Tests

    func testAudioCodecRawValues() {
        XCTAssertEqual(RealTimeAudioTransport.AudioCodec.opus.rawValue, "opus")
        XCTAssertEqual(RealTimeAudioTransport.AudioCodec.aac.rawValue, "aac")
        XCTAssertEqual(RealTimeAudioTransport.AudioCodec.flac.rawValue, "flac")
        XCTAssertEqual(RealTimeAudioTransport.AudioCodec.pcm.rawValue, "pcm")
    }

    // MARK: - Signal Type Tests

    func testWebRTCSignalTypeRawValues() {
        XCTAssertEqual(WebRTCSignaling.SignalType.offer.rawValue, "offer")
        XCTAssertEqual(WebRTCSignaling.SignalType.answer.rawValue, "answer")
        XCTAssertEqual(WebRTCSignaling.SignalType.candidate.rawValue, "candidate")
        XCTAssertEqual(WebRTCSignaling.SignalType.bye.rawValue, "bye")
    }
}
