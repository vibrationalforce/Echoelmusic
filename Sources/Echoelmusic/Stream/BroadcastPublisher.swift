//
//  BroadcastPublisher.swift
//  Echoelmusic — Stream
//
//  The broadcast pillar — a DMMW domain since 2026-09-24 (docs/dev/FOUNDER_PRODUCT_LAW.md),
//  executed on the founder's release of 2026-10-04 ("BROADCAST AUSFÜHREN"). It owns ONE
//  thing: the stream's lifecycle — Go Live, connecting, live, reconnecting, stopped, failed —
//  and it drives three parts that each own their own job:
//
//    · `BroadcastMasterPump` — moves the master mix (from the recorder's ring, after the whole
//      master chain) and the visual's pictures to the encoder, on its own queue;
//    · `BroadcastEngine` — the library side (HaishinKit RTMP/RTMPS, `RTMPBroadcastEngine`),
//      present only when the package is linked;
//    · `BroadcastSession.swift` — the pure rules: phases, words, URL check, reconnect delays,
//      key redaction.
//
//  ⚠️ WITHOUT A LINKED ENGINE NOTHING STREAMS, AND THE PUBLISHER SAYS SO. `engineAvailable` is
//  `BroadcastEngineFactory.make() != nil`, i.e. `canImport(RTMPHaishinKit)`. No copy may claim
//  streaming in a build where it is false (`TheBroadcastHasNoDoorWithoutAnEngineTests`).
//
//  ⚠️ THE STREAM KEY. Kept in the Keychain (`StreamKeyStore.swift`), handed to the engine as
//  the publish name, never interpolated into a string, never logged; engine error text is
//  scrubbed with `BroadcastRedaction` before anything shows it.
//

import Foundation
#if canImport(Observation)
import Observation
#endif

@MainActor
@Observable
public final class BroadcastPublisher {

    /// Wire protocol. Kept for the persisted value of older builds; this build speaks RTMP and
    /// RTMPS (chosen by the URL's scheme). SRT is not linked.
    public enum Transport: String, Sendable, CaseIterable {
        case rtmp, srt
        public var displayName: String { self == .rtmp ? "RTMP" : "SRT (low-latency)" }
    }

    // MARK: Persisted config

    /// Ingest URL (e.g. rtmp://a.rtmp.youtube.com/live2 or rtmps://…).
    public var url: String { didSet { UserDefaults.standard.set(url, forKey: Self.urlKey) } }
    /// Stream key (kept on-device only; never logged). Lives in the Keychain
    /// (`StreamKeyStore.swift`), never in UserDefaults — it is a publishing credential.
    public var streamKey: String { didSet { keyStore.write(streamKey) } }
    public var transport: Transport {
        didSet { UserDefaults.standard.set(transport.rawValue, forKey: Self.transportKey) }
    }

    // MARK: Live state (observed)

    /// Where the stream is. The ONE state; everything the view shows derives from it.
    private(set) var phase: BroadcastPhase = .idle {
        didSet { statusMessage = Self.words(for: phase, url: url, key: streamKey) }
    }

    /// True from "Go Live" until the stream has ended — the button reads "Stop".
    public var isLive: Bool { phase.isActive }

    /// Honest human-readable state for the UI (never a fake "live"). Scrubbed of the key.
    public private(set) var statusMessage = ""

    /// What the picture track carries — refreshed at 2 Hz while a stream runs, so a frozen or
    /// black picture is visible in words, not discovered by a viewer.
    public private(set) var pictureState: BroadcastPictureStateWords = .waiting
    /// Seconds of the master mix replaced by silence because the reader fell behind (0 = none).
    public private(set) var silencedSeconds: Double = 0

    private static let urlKey = "broadcast.url"
    private static let transportKey = "broadcast.transport"

    @ObservationIgnored private let keyStore: StreamSecretStore
    #if canImport(AVFoundation) && canImport(Metal) && canImport(CoreVideo)
    @ObservationIgnored private let engine: BroadcastEngine?
    @ObservationIgnored private var pump: BroadcastMasterPump?
    @ObservationIgnored private weak var ring: MasterRingSource?
    #endif
    @ObservationIgnored private var lifecycleTask: Task<Void, Never>?
    @ObservationIgnored private var statusTask: Task<Void, Never>?
    /// Bumped on every start/stop, so a late answer from a superseded attempt is ignored.
    @ObservationIgnored private var generation = 0

    public convenience init() {
        self.init(keyStore: KeychainStreamSecretStore(), defaults: .standard)
    }

    /// The seam a test drives: the key comes out of `keyStore`, and a copy an older build left
    /// in `defaults` is moved there once (`StreamKeyMigration`).
    convenience init(keyStore: StreamSecretStore, defaults: UserDefaults) {
        #if canImport(AVFoundation) && canImport(Metal) && canImport(CoreVideo)
        self.init(keyStore: keyStore, defaults: defaults, engine: BroadcastEngineFactory.make())
        #else
        self.init(keyStore: keyStore, defaults: defaults, engineless: ())
        #endif
    }

    #if canImport(AVFoundation) && canImport(Metal) && canImport(CoreVideo)
    /// The full seam: an injected engine (a fake in tests, nil = not linked).
    init(keyStore: StreamSecretStore, defaults: UserDefaults, engine: BroadcastEngine?) {
        self.keyStore = keyStore
        self.engine = engine
        self.url = defaults.string(forKey: Self.urlKey) ?? ""
        self.streamKey = StreamKeyMigration.loadMigrating(defaults: defaults, store: keyStore)
        self.transport = Transport(rawValue: defaults.string(forKey: Self.transportKey) ?? "rtmp") ?? .rtmp
    }
    #else
    private init(keyStore: StreamSecretStore, defaults: UserDefaults, engineless: Void) {
        self.keyStore = keyStore
        self.url = defaults.string(forKey: Self.urlKey) ?? ""
        self.streamKey = StreamKeyMigration.loadMigrating(defaults: defaults, store: keyStore)
        self.transport = Transport(rawValue: defaults.string(forKey: Self.transportKey) ?? "rtmp") ?? .rtmp
    }
    #endif

    /// Whether the streaming engine is present in this build.
    public var engineAvailable: Bool {
        #if canImport(AVFoundation) && canImport(Metal) && canImport(CoreVideo)
        return engine != nil
        #else
        return false
        #endif
    }

    /// Whether we have enough config to attempt a connection.
    public var isConfigured: Bool { !url.isEmpty && !streamKey.isEmpty }

    /// True when the address asks for TLS (rtmps://).
    public var isEncrypted: Bool { BroadcastDestination.isEncrypted(url) }

    #if canImport(AVFoundation) && canImport(Metal) && canImport(CoreVideo)
    /// Hands the publisher the master ring it streams from (`AudioEngine.retroCapture`). The
    /// door calls this; without it there is no sound to send and Go Live says so.
    func attach(ring: MasterRingSource) {
        self.ring = ring
    }
    #endif

    // MARK: - Go Live / Stop

    /// Begin broadcasting. Honest failure with a sentence when the engine is absent, the
    /// destination is incomplete or malformed, or there is no sound source — never claims a
    /// live stream it can't make.
    public func start() {
        guard !phase.isActive else { return }
        guard engineAvailable else { phase = .failed(.engineMissing); return }
        guard isConfigured else { phase = .failed(.notConfigured); return }
        if let failure = BroadcastDestination.validate(url) { phase = .failed(failure); return }
        #if canImport(AVFoundation) && canImport(Metal) && canImport(CoreVideo)
        guard let engine, let ring else { phase = .failed(.noSound); return }
        generation += 1
        let token = generation
        let pump = BroadcastMasterPump(ring: ring)
        self.pump = pump
        phase = .connecting
        engine.setConnectionLostHandler { [weak self] in
            Task { @MainActor [weak self] in self?.connectionLost(token: token) }
        }
        lifecycleTask = Task { [weak self] in
            await self?.connect(engine: engine, pump: pump, token: token, attempt: 0)
        }
        #endif
    }

    /// End the stream. Safe in every phase; a stream is never left half-open.
    public func stop() {
        generation += 1
        lifecycleTask?.cancel()
        lifecycleTask = nil
        stopStatusPolling()
        #if canImport(AVFoundation) && canImport(Metal) && canImport(CoreVideo)
        pump?.stop()
        pump = nil
        guard phase.isActive, let engine else { phase = .idle; return }
        phase = .stopping
        let token = generation
        Task { [weak self] in
            await engine.stop()
            guard let self, self.generation == token else { return }
            self.phase = .idle
        }
        #else
        phase = .idle
        #endif
    }

    #if canImport(AVFoundation) && canImport(Metal) && canImport(CoreVideo)
    // MARK: - Lifecycle (MainActor)

    /// One connect attempt. `attempt` 0 = Go Live; ≥ 1 = reconnect.
    private func connect(engine: BroadcastEngine, pump: BroadcastMasterPump, token: Int, attempt: Int) async {
        let url = self.url
        let key = self.streamKey
        let settings = BroadcastEncodeSettings.standard
        do {
            let sink = try await engine.start(url: url, streamName: key, settings: settings)
            guard generation == token, !Task.isCancelled else { await engine.stop(); return }
            let t0 = BroadcastStartGate.startTicks(now: mach_absolute_time(), timebase: .host)
            pump.start(sink: sink, spec: settings.video, startTicks: t0)
            phase = .live
            startStatusPolling(pump: pump)
            log.log(.info, category: .streaming, "Broadcast live (attempt \(attempt))")
        } catch {
            guard generation == token, !Task.isCancelled else { return }
            let failure: BroadcastFailure = (error as? BroadcastEngineError) == .publishRejected
                ? .publishRejected : .connectFailed
            log.log(.warning, category: .streaming,
                    "Broadcast start failed (attempt \(attempt)): \(String(describing: failure))")
            if attempt == 0 {
                await engine.stop()
                phase = .failed(failure)
            } else {
                await retry(engine: engine, pump: pump, token: token, after: attempt)
            }
        }
    }

    private func connectionLost(token: Int) {
        guard generation == token, phase == .live, let engine, let pump else { return }
        pump.stop()
        stopStatusPolling()
        log.log(.warning, category: .streaming, "Broadcast connection lost")
        lifecycleTask = Task { [weak self] in
            await self?.retry(engine: engine, pump: pump, token: token, after: 0)
        }
    }

    /// Waits the policy's delay for the next attempt, then reconnects — or ends the stream
    /// honestly when the attempts are used up.
    private func retry(engine: BroadcastEngine, pump: BroadcastMasterPump, token: Int, after previous: Int) async {
        let attempt = previous + 1
        guard let delay = BroadcastReconnectPolicy.delaySeconds(attempt: attempt) else {
            await engine.stop()
            guard generation == token else { return }
            phase = .failed(.retriesExhausted)
            return
        }
        phase = .reconnecting(attempt: attempt)
        await engine.stop()
        try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
        guard generation == token, !Task.isCancelled else { return }
        await connect(engine: engine, pump: pump, token: token, attempt: attempt)
    }

    private func startStatusPolling(pump: BroadcastMasterPump) {
        stopStatusPolling()
        statusTask = Task { [weak self, weak pump] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 500_000_000)
                guard let self, let pump else { return }
                self.apply(pump.snapshot())
            }
        }
    }

    /// Written only when a value changes — a view reading these is not a 2 Hz observer while
    /// nothing moves (the freeze law).
    private func apply(_ snapshot: BroadcastMasterPump.Snapshot) {
        let words = BroadcastPictureStateWords(snapshot.picture)
        if words != pictureState { pictureState = words }
        let silenced = (snapshot.silencedSeconds * 10).rounded() / 10
        if silenced != silencedSeconds { silencedSeconds = silenced }
    }
    #endif

    private func stopStatusPolling() {
        statusTask?.cancel()
        statusTask = nil
    }

    private static func words(for phase: BroadcastPhase, url: String, key: String) -> String {
        BroadcastRedaction.scrub(BroadcastStatusWords.text(for: phase,
                                                           encrypted: BroadcastDestination.isEncrypted(url)),
                                 secret: key)
    }
}

/// The picture state as words the view prints. Defined without AVFoundation so the view
/// compiles in every configuration.
public enum BroadcastPictureStateWords: Equatable, Sendable {
    case waiting, rendering, holding, black

    var sentence: String {
        switch self {
        case .waiting: return "Picture: waiting for the first frame."
        case .rendering: return "Picture: the visual, live."
        case .holding: return "Picture: the visual is not moving — the last frame is held."
        case .black: return "Picture: no visual on screen — sending black. Open the visual window."
        }
    }

    #if canImport(AVFoundation) && canImport(Metal) && canImport(CoreVideo)
    init(_ state: BroadcastPictureState) {
        switch state {
        case .waiting: self = .waiting
        case .rendering: self = .rendering
        case .holding: self = .holding
        case .black: self = .black
        }
    }
    #endif
}
