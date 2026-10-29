import AVFoundation
import CoreMedia
import EchoelCore
import Foundation
import HaishinKit
import RTMPHaishinKit
import SRTHaishinKit
import VideoToolbox

/// The one file that speaks a streaming protocol (wave W14): HaishinKit (BSD-3,
/// github.com/HaishinKit/HaishinKit.swift) carries RTMP, RTMPS and SRT, encodes H.264 and AAC on
/// the device's hardware and reconnects a dropped TCP link a few times by itself. Echoel adds no
/// protocol code of its own — the product law: integrate, never rebuild the specialist part.
///
/// One session per destination. Each has its own encoder, so destinations may differ in shape
/// and bit rate; the picture of one shape is drawn once and handed to every destination in that
/// shape (`append(video:format:)`), the master mix to all of them (`append(audio:when:)`).
/// Nothing opens until `open` is called — the musician's Go Live — and `closeAll` ends every one.
actor StreamPublisher {
    /// What a destination is doing, as the live page shows it.
    enum State: Equatable, Sendable {
        case connecting
        case live
        case failed(String)
        case closed
    }

    /// One destination's reading, sent to `onUpdate` whenever it changes.
    struct Report: Equatable, Sendable {
        var state: State
        /// Measured upload of this destination, kilobits a second; nil before the first reading.
        var sentKbps: Int?
        /// The network could not carry the bit rate; the encoder steps down until it can.
        var isCongested = false
    }

    private struct Destination {
        let session: any Session
        let format: StreamFormat
    }

    private var destinations: [UUID: Destination] = [:]
    private var registered = false
    /// Called on this actor with every change of a destination's report.
    private var onUpdate: (@Sendable (UUID, Report) -> Void)?

    func setOnUpdate(_ handler: (@Sendable (UUID, Report) -> Void)?) {
        onUpdate = handler
    }

    /// Opens `target` at `url` (built from its server and key just before, never stored). Returns
    /// once the server accepted the publish, or throws what it said.
    func open(_ target: StreamTarget, url: URL) async throws {
        if !registered {
            await SessionBuilderFactory.shared.register(RTMPSessionFactory())
            await SessionBuilderFactory.shared.register(SRTSessionFactory())
            registered = true
        }
        await close(target.id)
        guard let session = try await SessionBuilderFactory.shared.make(url).setMode(.publish).build() else {
            throw StreamPublisherError.unsupported
        }
        let stream = await session.stream
        let size = CGSize(width: target.format.pixelWidth, height: target.format.pixelHeight)
        let videoBitRate = target.quality.videoKbps * 1_000
        try await stream.setVideoSettings(VideoCodecSettings(
            videoSize: size,
            bitRate: videoBitRate,
            profileLevel: kVTProfileLevel_H264_High_AutoLevel as String,
            scalingMode: .normal,
            bitRateMode: .average,
            maxKeyFrameIntervalDuration: 2,
            // No B-frames: every platform's ingest takes it, and a live picture is not held back.
            allowFrameReordering: false,
            expectedFrameRate: Double(StreamQuality.framesPerSecond)))
        try await stream.setAudioSettings(AudioCodecSettings(bitRate: target.quality.audioKbps * 1_000))
        let id = target.id
        let report: @Sendable (Int, Bool) -> Void = { [weak self] kbps, congested in
            Task { await self?.measured(id, kbps: kbps, congested: congested) }
        }
        await stream.setBitRateStrategy(MeasuredBitRate(maximumVideoBitRate: videoBitRate, report: report))
        destinations[id] = Destination(session: session, format: target.format)
        publish(id, Report(state: .connecting))
        do {
            try await session.connect { [weak self] in
                Task { await self?.dropped(id) }
            }
        } catch {
            destinations[id] = nil
            publish(id, Report(state: .failed(Self.describe(error))))
            throw error
        }
        publish(id, Report(state: .live))
    }

    /// The picture of `format`, to every open destination in that shape.
    func append(video sampleBuffer: CMSampleBuffer, format: StreamFormat) async {
        nonisolated(unsafe) let buffer = sampleBuffer
        for destination in destinations.values where destination.format == format {
            await destination.session.stream.append(buffer)
        }
    }

    /// One block of the master mix, to every open destination. `when` carries the host time the
    /// picture's timestamps share, so sound and picture stay together.
    func append(audio pcm: AVAudioPCMBuffer, when: AVAudioTime) async {
        nonisolated(unsafe) let buffer = pcm
        nonisolated(unsafe) let time = when
        for destination in destinations.values {
            await destination.session.stream.append(buffer, when: time)
        }
    }

    /// Whether any destination still wants a picture of `format`.
    func wants(_ format: StreamFormat) -> Bool {
        destinations.values.contains { $0.format == format }
    }

    var isOpen: Bool { !destinations.isEmpty }

    func close(_ id: UUID) async {
        guard let destination = destinations.removeValue(forKey: id) else { return }
        try? await destination.session.close()
        publish(id, Report(state: .closed))
    }

    func closeAll() async {
        for id in Array(destinations.keys) { await close(id) }
    }

    // MARK: - Reports

    private var reports: [UUID: Report] = [:]

    private func publish(_ id: UUID, _ report: Report) {
        reports[id] = report
        onUpdate?(id, report)
    }

    private func measured(_ id: UUID, kbps: Int, congested: Bool) {
        guard destinations[id] != nil, var report = reports[id] else { return }
        report.sentKbps = kbps
        report.isCongested = congested
        guard report != reports[id] else { return }
        publish(id, report)
    }

    /// The server or the network closed a live destination and the stack's own retries are spent.
    private func dropped(_ id: UUID) {
        guard destinations.removeValue(forKey: id) != nil else { return }
        publish(id, Report(state: .failed("The server closed the stream.")))
    }

    private static func describe(_ error: any Error) -> String {
        switch error {
        case RTMPConnection.Error.requestFailed(let response):
            "The server refused the connection (\(response.status?.code ?? "no reason")). Check the server address."
        case RTMPStream.Error.requestFailed(let response):
            "The server refused the stream (\(response.status?.code ?? "no reason")). Check the stream key."
        case SessionBuilderFactory.Error.notFound, SessionBuilderFactory.Error.illegalArgument:
            "The address is not an RTMP, RTMPS or SRT address."
        default:
            "Could not connect: \(error.localizedDescription)"
        }
    }
}

enum StreamPublisherError: LocalizedError {
    case unsupported

    var errorDescription: String? { "The address is not an RTMP, RTMPS or SRT address." }
}

/// HaishinKit's own adaptive strategy (the video rate steps down when the network cannot carry it
/// and back up when it can again), plus the one reading the live page shows: bytes out a second.
private actor MeasuredBitRate: StreamBitRateStrategy {
    nonisolated let mamimumVideoBitRate: Int
    nonisolated let mamimumAudioBitRate: Int = 0
    private let adaptive: StreamVideoAdaptiveBitRateStrategy
    private let report: @Sendable (Int, Bool) -> Void

    init(maximumVideoBitRate: Int, report: @escaping @Sendable (Int, Bool) -> Void) {
        mamimumVideoBitRate = maximumVideoBitRate
        adaptive = StreamVideoAdaptiveBitRateStrategy(mamimumVideoBitrate: maximumVideoBitRate)
        self.report = report
    }

    func adjustBitrate(_ event: NetworkMonitorEvent, stream: some StreamConvertible) async {
        switch event {
        case .status(let reading):
            report(reading.currentBytesOutPerSecond * 8 / 1_000, false)
        case .publishInsufficientBWOccured(let reading):
            report(reading.currentBytesOutPerSecond * 8 / 1_000, true)
        case .reset:
            break
        }
        await adaptive.adjustBitrate(event, stream: stream)
    }
}
