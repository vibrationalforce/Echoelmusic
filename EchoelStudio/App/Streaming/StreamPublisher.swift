import AVFoundation
import CoreMedia
import EchoelCore
import Foundation
import HaishinKit
import RTMPHaishinKit
import VideoToolbox

/// The one file that speaks a streaming protocol (wave W14): HaishinKit (BSD-3,
/// github.com/HaishinKit/HaishinKit.swift) carries RTMP and RTMPS, encodes H.264 and AAC on
/// the device's hardware and reconnects a dropped TCP link a few times by itself. Echoel adds no
/// protocol code of its own — the product law: integrate, never rebuild the specialist part.
///
/// One session per destination. Each has its own encoder, so destinations may differ in shape
/// and bit rate; the picture of one shape is drawn once and handed to every destination in that
/// shape, the master mix to all of them (the two `append`s).
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
        let session: any StreamSession
        let format: StreamFormat
    }

    private var destinations: [UUID: Destination] = [:]
    /// The opens under way. A close ends one, and its `open` then stops instead of going live.
    private var openings = StreamOpenings()
    private var registered = false
    /// Called on this actor with every change of a destination's report.
    private var onUpdate: (@Sendable (UUID, Report) -> Void)?

    func setOnUpdate(_ handler: (@Sendable (UUID, Report) -> Void)?) {
        onUpdate = handler
    }

    /// Opens `target` at `url` (built from its server and key just before, never stored). Returns
    /// once the server accepted the publish, or throws what it said.
    func open(_ target: StreamTarget, url: URL) async throws {
        let id = target.id
        // Begun before the first `await`: from here to the server's answer a Stop can come in at
        // every one. It ends this attempt (`close`, `closeAll`), and each check below then stops
        // instead of going on.
        let attempt = openings.begin(id)
        defer { openings.finish(attempt, for: id) }
        if !registered {
            await StreamSessionBuilderFactory.shared.register(RTMPSessionFactory())
            registered = true
        }
        // What an earlier Go Live left under this id goes first; this attempt stays under way.
        await closeKept(id)
        guard let session = try await StreamSessionBuilderFactory.shared.make(url).setMode(.publish).build() else {
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
        let report: @Sendable (Int, Bool) -> Void = { [weak self] kbps, congested in
            Task { await self?.measured(id, kbps: kbps, congested: congested) }
        }
        await stream.setBitRateStrategy(MeasuredBitRate(maximumVideoBitRate: videoBitRate, report: report))
        // Stopped while the session was made: `closeAll` found no destination to close. The
        // session never connected, and it is not kept.
        guard openings.isUnderWay(attempt, for: id) else { throw StreamPublisherError.stopped }
        destinations[id] = Destination(session: session, format: target.format)
        publish(id, Report(state: .connecting))
        do {
            try await session.connect { [weak self] in
                Task { await self?.dropped(id) }
            }
        } catch {
            // Stopped while it connected: `close` closed the session, and that is no failure of
            // the server's to show. A newer open's destination under this id is not touched.
            guard openings.isUnderWay(attempt, for: id) else { throw StreamPublisherError.stopped }
            destinations[id] = nil
            publish(id, Report(state: .failed(Self.describe(error))))
            throw error
        }
        guard openings.isUnderWay(attempt, for: id) else {
            // The server answered after the Stop. The destination is gone, so nothing would ever
            // close this session: it is closed here and does not go live.
            try? await session.close()
            throw StreamPublisherError.stopped
        }
        publish(id, Report(state: .live))
    }

    /// A picture of one shape, to every open destination in that shape.
    func append(_ frame: FieldStreamSource.Frame) async {
        nonisolated(unsafe) let buffer = frame.sampleBuffer
        for destination in destinations.values where destination.format == frame.format {
            await destination.session.stream.append(buffer)
        }
    }

    /// One block of the master mix, to every open destination. Its time is the host time the
    /// picture's timestamps share, so sound and picture stay together.
    func append(_ block: MasterAudioTap.Block) async {
        nonisolated(unsafe) let buffer = block.buffer
        nonisolated(unsafe) let time = block.time
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
        // An open still under way for it is over, whether or not its session is kept yet.
        openings.close(id)
        await closeKept(id)
    }

    /// Closes the destination kept under `id`. An open under way for it goes on.
    private func closeKept(_ id: UUID) async {
        guard let destination = destinations.removeValue(forKey: id) else { return }
        try? await destination.session.close()
        publish(id, Report(state: .closed))
    }

    func closeAll() async {
        // Also the destinations still being made, which `destinations` does not hold yet.
        openings.closeAll()
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
        case StreamSessionBuilderFactory.Error.notFound, StreamSessionBuilderFactory.Error.illegalArgument:
            "The address is not an RTMP or RTMPS address."
        default:
            "Could not connect (\(error.localizedDescription)). Check the network and the server address."
        }
    }
}

enum StreamPublisherError: LocalizedError {
    case unsupported
    /// Stop came in while the destination was being opened: it is closed, and nothing failed.
    case stopped

    var errorDescription: String? {
        switch self {
        case .unsupported: "The address is not an RTMP or RTMPS address."
        case .stopped: "The stream was stopped before this destination opened."
        }
    }
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
