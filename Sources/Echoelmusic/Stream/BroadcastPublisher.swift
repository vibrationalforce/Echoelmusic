//
//  BroadcastPublisher.swift
//  Echoelmusic — Stream
//
//  The broadcast pillar — a DMMW domain again since 2026-09-24
//  (docs/dev/FOUNDER_PRODUCT_LAW.md); it was cut 2026-07-25 as a phase decision and
//  struck from the identity line 2026-07-31 because nothing streams. WOULD stream the
//  live bio-AV instrument from the phone; the engine (HaishinKit) is not linked, so
//  nothing streams in this build — no copy may claim it. Linking it is a founder-gated
//  dependency slice. Config/UI are preserved for that re-open.
//  This is the SINK side of the Signal Router (rtmp.out / srt.out).
//
//  Build-green first (founder principle #1): the real RTMP/SRT engine is HaishinKit
//  (the sole sanctioned external dependency, MIT). It is integrated behind
//  `#if canImport(HaishinKit)`, so this file COMPILES with or without the package —
//  without it, broadcast is an honest "streaming engine not installed" state, never
//  a dead button. No capture path is wired: nothing constructs this publisher's view
//  and HaishinKit is not linked, so linking the engine is a founder decision (new
//  dependency) and the capture path would be built with it — not "next cycle".
//

import Foundation
#if canImport(Observation)
import Observation
#endif
#if canImport(HaishinKit)
import HaishinKit
#endif

@MainActor
@Observable
public final class BroadcastPublisher {

    /// Wire protocol for the stream.
    public enum Transport: String, Sendable, CaseIterable {
        case rtmp, srt
        public var displayName: String { self == .rtmp ? "RTMP" : "SRT (low-latency)" }
    }

    // MARK: Persisted config (per protocol)

    /// Ingest URL (e.g. rtmp://a.rtmp.youtube.com/live2 or srt://host:port).
    public var url: String { didSet { UserDefaults.standard.set(url, forKey: Self.urlKey) } }
    /// Stream key (kept on-device only; never logged). Lives in the Keychain
    /// (`StreamKeyStore.swift`), never in UserDefaults — it is a publishing credential.
    public var streamKey: String { didSet { keyStore.write(streamKey) } }
    public var transport: Transport {
        didSet { UserDefaults.standard.set(transport.rawValue, forKey: Self.transportKey) }
    }

    // MARK: Live state (observed)

    public private(set) var isLive = false
    /// Honest human-readable state for the UI (never a fake "live").
    public private(set) var statusMessage = ""

    private static let urlKey = "broadcast.url"
    private static let transportKey = "broadcast.transport"

    @ObservationIgnored private let keyStore: StreamSecretStore

    public convenience init() {
        self.init(keyStore: KeychainStreamSecretStore(), defaults: .standard)
    }

    /// The seam a test drives: the key comes out of `keyStore`, and a copy an older build left
    /// in `defaults` is moved there once (`StreamKeyMigration`).
    init(keyStore: StreamSecretStore, defaults: UserDefaults) {
        self.keyStore = keyStore
        self.url = defaults.string(forKey: Self.urlKey) ?? ""
        self.streamKey = StreamKeyMigration.loadMigrating(defaults: defaults, store: keyStore)
        self.transport = Transport(rawValue: defaults.string(forKey: Self.transportKey) ?? "rtmp") ?? .rtmp
    }

    /// Whether the streaming engine is present in this build.
    public var engineAvailable: Bool {
        #if canImport(HaishinKit)
        return true
        #else
        return false
        #endif
    }

    /// Whether we have enough config to attempt a connection.
    public var isConfigured: Bool { !url.isEmpty && !streamKey.isEmpty }

    /// Begin broadcasting. Honest no-op with a message when the engine is absent or
    /// the destination is unconfigured — never claims a live stream it can't make.
    public func start() {
        guard engineAvailable else {
            statusMessage = "Streaming engine not installed in this build."
            isLive = false
            return
        }
        guard isConfigured else {
            statusMessage = "Add an ingest URL and stream key first."
            isLive = false
            return
        }
        #if canImport(HaishinKit)
        // Connection + A/V capture wiring lands in the next cycle (audio tap → encoder
        // → \(transport.rawValue.uppercased())). Kept out of this scaffold so the build
        // stays green while the dependency is added in isolation.
        statusMessage = "Streaming engine ready — connecting path lands next cycle."
        isLive = false
        #endif
    }

    public func stop() {
        isLive = false
        statusMessage = ""
    }
}
