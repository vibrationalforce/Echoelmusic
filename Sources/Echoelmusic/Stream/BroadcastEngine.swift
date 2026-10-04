//
//  BroadcastEngine.swift
//  Echoelmusic — Stream
//
//  The seam between the broadcast's own logic (state, pump, timestamps — this repo) and the
//  library that speaks RTMP and runs the encoders (HaishinKit — linked, never rebuilt;
//  `docs/dev/FOUNDER_PRODUCT_LAW.md`, integrate-don't-rebuild). The publisher only ever talks
//  to this protocol, so every rule above the wire is testable with a fake engine, and the
//  RTMP adapter (`RTMPBroadcastEngine.swift`, compiled only when the package is linked) stays
//  a thin translation.
//

import Foundation

/// What the encoders are asked to produce. One standard profile on purpose: a choice the
/// person cannot judge without a receiver is not a choice to show them yet.
struct BroadcastEncodeSettings: Sendable, Equatable {
    var video: BroadcastVideoSpec
    var videoBitRate: Int
    var keyFrameIntervalSeconds: Int
    var audioBitRate: Int
    var audioSampleRate: Double

    /// 1280×720 at 30 fps, 2.5 Mbit/s H.264, AAC 128 kbit/s at 48 kHz, a key frame every 2 s —
    /// inside the published ingest recommendations of the large platforms for 720p30
    /// (NEEDS-VERIFY per platform before any claim; the founder's own receiver decides).
    static let standard = BroadcastEncodeSettings(
        video: .standard,
        videoBitRate: 2_500_000,
        keyFrameIntervalSeconds: 2,
        audioBitRate: 128_000,
        audioSampleRate: 48_000)
}

/// Why an engine could not start. Mapped 1:1 onto `BroadcastFailure` by the publisher.
enum BroadcastEngineError: Error, Equatable {
    /// The server could not be reached or the RTMP handshake/connect failed.
    case connectFailed
    /// Connected, but the server refused the publish (wrong key, stream already live …).
    case publishRejected
}

#if canImport(AVFoundation) && canImport(Metal) && canImport(CoreVideo)
/// A streaming engine. One instance per publisher; `start` may be called again after `stop`
/// (that is how a reconnect works).
protocol BroadcastEngine: AnyObject, Sendable {
    /// Connects to `url`, publishes `streamName`, starts the encoders and returns the sink the
    /// pump feeds. Throws `BroadcastEngineError`. Must never log `streamName`.
    func start(url: String, streamName: String, settings: BroadcastEncodeSettings) async throws -> BroadcastMediaSink
    /// Stops publishing and closes the connection. Idempotent; never throws.
    func stop() async
    /// Called — on any thread — when a connection that was live drops. Set before `start`.
    func setConnectionLostHandler(_ handler: @escaping @Sendable () -> Void)
}

/// The engine this build carries, or nil. The ONE place that knows whether the library is
/// linked: `BroadcastPublisher.engineAvailable` is this answer, nothing else.
enum BroadcastEngineFactory {
    static func make() -> BroadcastEngine? {
        #if canImport(RTMPHaishinKit)
        return RTMPBroadcastEngine()
        #else
        return nil
        #endif
    }
}
#endif
