//
//  ADMOSCSender.swift
//  Echoelmusic — EchoelSync module
//
//  Bridges the live bio bus to ADM-OSC — the open Audio-Definition-Model-over-
//  OSC standard (github.com/immersive-audio-live/ADM-OSC) for object-based
//  audio positioning. Adamson FletcherMachine, L-ISA, d&b Soundscape, Spat,
//  Nuendo etc. all speak it, so this one bridge makes Echoel a bio-reactive
//  OBJECT SOURCE for any immersive rig — body drives an audio object's position
//  and gain in the room, live, over an open standard. No SDK, no new dependency:
//  reuses OSCSender.encode(address:floats:).
//
//  This is opt-in (not every user has an immersive renderer); started from the
//  Sync tab, off by default. See scratchpads/SPEC_ADM_OSC_BRIDGE.md.
//
//  ADM-OSC v1.0 namespace (one 1-based object index `n`), leaves exactly as the spec table
//  names them (github.com/immersive-audio-live/ADM-OSC, docs/adm-osc.bs, "Object" rows):
//    /adm/obj/{n}/azim   float  -180 … +180  (degrees, positive = left)
//    /adm/obj/{n}/elev   float   -90 … +90   (degrees)
//    /adm/obj/{n}/dist   float     0 … 1     (normalized)
//    /adm/obj/{n}/gain   float     0 … 1     (linear, ≤ 1.0)
//  ⛔ Until #1210 (2026-09-10) every formatter in this directory wrote `/position/azimuth`,
//  `/position/elevation`, `/position/distance` (and `/position/x|y|z`) — a shape that exists in
//  NO version of the spec; the leaf names were transcribed from the reference Python helper
//  (`send_object_position_azimuth`) instead of the address table. A conforming renderer logs
//  "unrecognized ADM address" and moves nothing, so the "bio-reactive object source" claim was
//  false on the wire for as long as this file existed. Ranges, sign and the 1-based index were
//  right all along. Guard: `Tests/CISmoke/TheADMOSCLeavesAreTheSpecsTests.swift`.
//  NEEDS-FOUNDER-VERIFY: one object visibly moving in a real ADM-OSC renderer (FletcherMachine,
//  L-ISA, SPAT, or the reference receiver `pip install adm-osc`) after #1210.
//
//  Default bio → object mapping (all four are existing BioSampleFrame fields). EVERY ONE
//  of them is sent only while its own channel is actually measured (#260) — see
//  `admMessages` for why, and note that two of these structural zeros are extremes, not
//  neutral positions:
//    breath phase → azimuth    sound sweeps L↔R with the breath — needs `hasMeasuredBreath`
//    coherence    → distance   coherent = pulled close; scattered = far — needs a pulse
//                              AND a non-zero coherence: 16 accepted RR intervals, ~16 s
//                              at rest on the camera since #1220 (⛔ "which a camera take
//                              may never reach" stood here — true before the rolling history)
//    HRV          → elevation  calm lifts the object — needs a pulse AND a non-zero HRV
//    motion       → gain       movement brings it forward — DORMANT in this build
//                              (#215): nothing measures motion, so the BIO arm sends no
//                              /gain at all rather than a constant. The MUSIC arm
//                              (`MusicMediaMap.admMessages`) still drives /gain from the
//                              master level whenever notes sound. See `motionGain`.
//  Silence on an address means "not measured", never "measured as zero"; the renderer
//  holds its last value, which is what a slipped finger should look like.
//

#if canImport(Network)
import Foundation
import Network
#if canImport(Observation)
import Observation
#endif

@MainActor
@Observable
public final class ADMOSCSender {

    /// Renderer host. FletcherMachine / immersive consoles are usually a LAN box.
    public var host: String {
        didSet { Self.persistTarget(host, port); reconnectIfActive() }
    }

    /// Renderer OSC port. ADM-OSC renderers typically listen on a port distinct
    /// from TouchOSC's 8000 — default 9000, user-configurable.
    public var port: UInt16 {
        didSet { Self.persistTarget(host, port); reconnectIfActive() }
    }

    /// 1-based ADM object index this bio source drives.
    public var objectIndex: Int

    /// S3 — Immersive-Stage scene streaming. When true, each tick streams the ATTACHED
    /// scene (every placed track as `/adm/obj/1…N`) INSTEAD of the bio→object mapping.
    /// Mutual exclusion is the whole point: streaming the track scene suppresses the
    /// bio object so object 1 never collides. Off by default ⇒ the bio path is
    /// untouched and Release is bit-identical. Toggling it re-arms a fresh send.
    public var streamsScene = false {
        didSet { if streamsScene != oldValue { lastSentScene = nil } }
    }

    /// Dialect for SCENE streaming. The bio→object path is always ADM-OSC polar;
    /// this only affects the `streamsScene` branch.
    ///
    /// ⛔ NOTHING IN `Sources/` WRITES THIS (#745). Measured with comments
    /// stripped: the name occurs TWICE in code, both in this file — this
    /// declaration and the read in `sendIfFresh`. `ImmersiveStageView`, the one
    /// surface that touches this sender's stream controls, names it ZERO times;
    /// its `Toggle` binds `streamsScene` and nothing else. So all three cases of
    /// `SpatialOSCDialect` are built and golden-file tested, and exactly one of
    /// them can ever reach the wire.
    ///
    /// ⚠️ THIS IS SECOND-ORDER DOORLESS, and that distinction decides what to do
    /// about it. `AutoMixChain.preset` (#736) was a live multi-way choice on a
    /// REACHABLE surface, so it earned a door. Here the branch that reads this
    /// property sits behind `streamsScene`, whose only writer lives in a view with
    /// zero construction sites — deliberately parked, like `BroadcastView`. Adding
    /// a picker here would build a control nobody can open. **Register it, do not
    /// door it**; the door belongs in the same commit that re-mounts the stage.
    ///
    /// ⭐ The user-facing copy is already honest about this by accident: the stage
    /// toggle reads "Stream to renderer (ADM-OSC)" — it names the one dialect that
    /// can actually happen. Whoever adds the picker must widen that label in the
    /// same commit, or the label starts lying the moment the choice becomes real.
    ///
    /// NOT A DEFECT TO DELETE. `admCartesianMessages` and `iemMessages` are the
    /// difference between "speaks the open standard" and "speaks our corner of it"
    /// — Cartesian-only consoles and the IEM suite are exactly the rigs the
    /// identity line's immersive pillar is aimed at.
    public var sceneDialect: SpatialOSCDialect = .admOSC

    /// Object count in the most recent streamed scene — drives a UI activity readout
    /// without a timer (like `lastSentTimestamp`).
    public private(set) var lastSceneObjectCount = 0

    public private(set) var isActive = false

    /// CFAbsoluteTime of the last datagram sent — lets the UI render an activity
    /// dot without a timer (mirrors OSCSender).
    public private(set) var lastSentTimestamp: TimeInterval = 0

    @ObservationIgnored private weak var bus: EngineBus?
    @ObservationIgnored private weak var sceneStore: SpatialSceneStore?
    @ObservationIgnored private var lastSentScene: SpatialScene?
    @ObservationIgnored private var connection: NWConnection?
    @ObservationIgnored private let loop = PollingLoop()
    @ObservationIgnored private var lastFrameTimestamp: TimeInterval = -1

    public init(host: String = "127.0.0.1", port: UInt16 = 9000, objectIndex: Int = 1) {
        let d = UserDefaults.standard
        self.host = d.string(forKey: Self.hostKey) ?? host
        let p = d.integer(forKey: Self.portKey)
        self.port = (p > 0 && p <= 65_535) ? UInt16(p) : port
        self.objectIndex = max(1, objectIndex)
    }

    public func start(subscribing bus: EngineBus) {
        guard !isActive else { return }
        self.bus = bus
        connect()
        isActive = true
        loop.start(interval: .milliseconds(50)) { [weak self] in   // ~20 Hz for smooth motion
            guard let self, let bus = self.bus else { return }
            self.sendIfFresh(from: bus)
        }
    }

    public func stop() {
        loop.stop()
        connection?.cancel()
        connection = nil
        isActive = false
        lastSentScene = nil
        lastSceneObjectCount = 0
    }

    /// Attach the live Immersive-Stage scene (weak — the store lives at app level).
    /// Streaming only actually happens while `streamsScene` is true AND a route has
    /// opened the socket.
    public func attachScene(_ store: SpatialSceneStore?) {
        sceneStore = store
    }

    // MARK: - Target persistence + live reconnect

    private static let hostKey = "net.adm.host"
    private static let portKey = "net.adm.port"
    private static func persistTarget(_ host: String, _ port: UInt16) {
        let d = UserDefaults.standard
        d.set(host, forKey: hostKey)
        d.set(Int(port), forKey: portKey)
    }
    /// A host/port edit takes effect immediately while streaming (connect() otherwise
    /// only runs in start()): drop the old socket, reconnect. Idle ⇒ no-op.
    private func reconnectIfActive() {
        guard isActive else { return }
        connection?.cancel()
        connect()
    }

    // MARK: - Connection

    private func connect() {
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return }
        let endpoint = NWEndpoint.hostPort(host: .init(host), port: nwPort)
        let conn = NWConnection(to: endpoint, using: .udp)
        conn.start(queue: .main)
        self.connection = conn
    }

    // MARK: - Subscriber tick

    private func sendIfFresh(from bus: EngineBus) {
        // S3 — SCENE STREAMING takes over the socket when armed: every placed track is
        // an object (/adm/obj/1…N via the golden-tested formatter), and the bio→object
        // path below is suppressed entirely so object 1 never collides. Static
        // positions send once (dedup on scene equality); a puck move / recorded
        // automation restreams. Streaming but nothing placed yet ⇒ send nothing (never
        // fall back to bio — that would reintroduce the collision).
        if streamsScene {
            guard let scene = sceneStore?.scene, !scene.objects.isEmpty else {
                if lastSceneObjectCount != 0 { lastSceneObjectCount = 0 }
                return
            }
            // Guard the observed write so a static scene doesn't fire an @Observable
            // notification every 20 Hz tick (that would churn the Immersive Stage's
            // puck body — the readout is a low-frequency status, not a live meter).
            if lastSceneObjectCount != scene.objects.count { lastSceneObjectCount = scene.objects.count }
            guard scene != lastSentScene else { return }
            lastSentScene = scene
            send(scene: scene, dialect: sceneDialect)   // sets lastSentTimestamp
            return
        }
        // Music drives the object POSITION when sounding (pitch→azimuth/elevation,
        // level→distance/gain), bio otherwise — bio stays the co-modulator. Dedup on
        // the chosen source's timestamp so a music-only change still moves the object.
        let music = bus.freshMusical(maxAge: 1.5)
        let sourceTimestamp: TimeInterval
        let messages: [(String, Float)]
        if let m = music, m.isSounding {
            sourceTimestamp = m.timestamp
            messages = MusicMediaMap.admMessages(forMusic: m, object: objectIndex)
        } else if let frame = bus.latestBio, BioEgressPolicy.allowsEgress(frame.source) {
            // 5.1.3: the bio→object co-modulation path sends breath/coherence/HRV-
            // derived positions — only Echoel-measured sources may leave the device.
            sourceTimestamp = frame.timestamp
            messages = Self.admMessages(for: frame, object: objectIndex)
        } else {
            return
        }
        guard sourceTimestamp != lastFrameTimestamp else { return }
        lastFrameTimestamp = sourceTimestamp
        // A frame whose channels are all still unmeasured produces NO addresses (#260), so
        // return before the stamp: `lastSentTimestamp` documents itself as "the last
        // datagram sent" and would otherwise record a tick on which nothing left the
        // device. Matches `OSCSender`'s `if sentAny`.
        //
        // ⚠️ This does NOT fix an indicator, and an earlier draft of this comment claimed it
        // did. `lastSentTimestamp` has no reader anywhere in `Sources/`; the Patchbay dot
        // (`PatchbayView`, `outputRow("ADM-OSC", active:)`) reads `isActive`, deliberately,
        // because a low-frequency flag is freeze-safe. The honest statement of what remains:
        // on a strap-only rig this arm can now send nothing for a whole session while that
        // dot still reads "sending". That is a separate defect, not one this line closes.
        guard !messages.isEmpty else { return }
        // #1421 — the three polar leaves leave as ONE `/aed` when all three are present.
        // Both arms flow through here, so the packing rule has exactly one home.
        for (address, floats) in Self.packedPositionMessages(messages, object: objectIndex) {
            send(address: address, floats: floats)
        }
        lastSentTimestamp = CFAbsoluteTimeGetCurrent()
    }

    private func send(address: String, floats: [Float]) {
        guard let conn = connection else { return }
        // Reuse the audited OSC 1.0 encoder — ADM-OSC is plain OSC on the wire.
        let data = OSCSender.encode(address: address, floats: floats)
        conn.send(content: data, completion: .contentProcessed { _ in })
    }

    // MARK: - Scene-driven send (S3 — driven by the tick while `streamsScene` is armed)

    /// Pushes an entire SpatialScene through the open socket in the given
    /// dialect (ADM-OSC or IEM). Formatting is the pure
    /// `SpatialSceneOSCFormatter` (golden-file tested); this method only
    /// moves bytes. Called by `sendIfFresh` when `streamsScene` is on (mutual
    /// exclusion with the bio→object path); still safe to call directly.
    public func send(scene: SpatialScene, dialect: SpatialOSCDialect = .admOSC) {
        guard connection != nil else { return }
        // #1430 — the scene arm was the THIRD position emitter and the only one that still
        // walked the unpacked list. It now goes through the same fold as the bio and music
        // arms; the formatter is untouched, so its golden tests keep testing what they tested.
        let flat = SpatialSceneOSCFormatter.messages(for: scene, dialect: dialect)
            .map { ($0.address, $0.value) }
        for (address, floats) in Self.packedSceneMessages(flat, dialect: dialect) {
            send(address: address, floats: floats)
        }
        lastSentTimestamp = CFAbsoluteTimeGetCurrent()
    }

    // MARK: - Pure mapping kernel (testable without a socket)

    /// Maps a bio frame to the ADM-OSC (address, value) pairs for object `n`.
    /// Pure value-in/value-out — unit-tested without a socket, like `encode`.
    /// All values are clamped into their ADM-OSC v1.0 ranges.
    ///
    /// ⛔ EVERY ADDRESS RIDES THE MEASUREMENT OF ITS OWN CHANNEL (#260), the same rule
    /// `OSCSender.bioMessages` follows since #245 — and here the stakes are higher than
    /// on the OSC feed, because two of the three structural zeros are not neutral, they
    /// are EXTREMES:
    ///   · unmeasured breath ⇒ `breathPhase` 0 ⇒ azimuth **−180**, the object slammed
    ///     hard left;
    ///   · unmeasured coherence ⇒ `1 - 0` ⇒ distance **1**, the object pushed to the far
    ///     end of the room.
    /// A renderer cannot tell either apart from a performer who really is hard left and far
    /// away.
    ///
    /// ⛔ AND BOTH OCCURRED ON SHIPPING HARDWARE, which is what makes this a defect rather
    /// than a hypothetical. `PolarH10BioPublisher` publishes `breathRate: 0, breathPhase: 0`
    /// on EVERY frame — the strap derives no respiration — and `.ble` is egress-allowed, so
    /// a chest-strap session pinned `/azim` at exactly −180 for its whole
    /// duration, every time. The camera is the same story one axis over: `coherence` stays 0
    /// until 16 accepted RR intervals, and `CameraAnalyzer`'s RR series comes from a fixed
    /// 10 s peak window (≈10 intervals at a resting rate), so `distance` sat at 1 for entire
    /// takes. (An earlier draft of this comment blamed `FaceExpressionBioPublisher`'s
    /// all-zero frame instead. That was WRONG at the time — the type then had zero
    /// instantiations — and the publisher is removed entirely since #1301. The cause named
    /// above is the real one and is what the tests below pin.)
    ///
    /// ⚠️ Consequence to know before mapping: on a bio-only rig an address that is never
    /// measured never arrives, so the object keeps its initial position rather than being
    /// driven to a default. `distance` is the one that arrives LAST — ~16 accepted beats on
    /// either source since #1220 — see `HRVCoherence.minIntervals` and the note in `OSCSender`.
    public nonisolated static func admMessages(for f: BioSampleFrame,
                                               object n: Int) -> [(String, Float)] {
        let idx = max(1, n)
        let prefix = "/adm/obj/\(idx)"
        var msgs: [(String, Float)] = []

        // breath phase [0..1] → azimuth [-180..180]: L↔R sweep with the breath.
        // Gated on `breathRate`, not on the phase: `breathPhase` has no unknown sentinel
        // (0 is a real position, exhale start), so it cannot answer for itself.
        // `isFinite` too, because this is the ONE axis whose gate a corrupt value can pass:
        // the other two compare `> 0`, which is false for NaN, while `3...40` can hold a
        // real rate beside a corrupt phase. `clamp` here is not NaN-safe, so without this a
        // NaN would go out as an azimuth — and even the NaN-safe form would land on −180,
        // the very position this gate exists to stop asserting. `isFinite` also refuses
        // ±infinity, deliberately: an infinite phase would clamp to a legal-looking ±180
        // that is nonetheless not a reading, and this arm's whole rule is that it asserts
        // only what was measured.
        // ⭐ #1140 — `hasMeasuredBreathWaveform`, NOT `hasMeasuredBreath`, and this arm is the
        // one that argued hardest for the distinction before it existed. `HealthKitBioPublisher`
        // reads a real respiratory RATE while `breathPhase` stays frozen at 0.5, so the old gate
        // opened and this line sent `(0.5·2−1)·180` = **azimuth 0°** — the object asserted dead
        // centre front, permanently, as a measurement. That is precisely "an invented number in
        // someone's rig", which the sentence above forbids in so many words. The rate gate was
        // never wrong about the rate; it was answering a different question.
        if f.hasMeasuredBreathWaveform, f.breathPhase.isFinite {
            msgs.append(("\(prefix)/azim",
                         clamp((f.breathPhase * 2 - 1) * 180, -180, 180)))
        }
        // HRV [0..1] → elevation [-90..90]: calm lifts (upper hemisphere 0..60).
        // Both halves, as on the OSC path: an HRV beside a pulse of 0 is a publisher bug,
        // not a reading, and this arm must not put an invented number in someone's rig.
        if f.hasMeasuredHeartRate, f.hrvNormalized > 0 {
            msgs.append(("\(prefix)/elev", clamp(f.hrvNormalized * 60, -90, 90)))
        }
        // coherence [0..1] → distance [0..1]: coherent pulls close (small distance).
        if f.hasMeasuredHeartRate, f.coherence > 0 {
            msgs.append(("\(prefix)/dist", clamp(1 - f.coherence, 0, 1)))
        }
        // motion [0..1] → gain [0..1]: movement brings the object forward — WHEN
        // something measures motion. Today nothing does, so this arm asserts no gain at
        // all (#215); see `motionGain`.
        if let gain = motionGain(motion: f.motionEnergy,
                                 hasProducer: ModSource.motion.hasProducer) {
            msgs.append(("\(prefix)/gain", gain))
        }
        return msgs
    }

    /// Folds the three POLAR leaves into ONE `/adm/obj/{n}/aed`, and only when ALL THREE
    /// are present. Everything else passes through in order, untouched.
    ///
    /// ⭐ WHY THIS EXISTS, cited rather than asserted. ADM-OSC v1.0 §"Minimum Viable
    /// Implementation" (`docs/adm-osc.bs`, the vendored spec this repo already pins its leaf
    /// names against) requires of a SENDER: *"Implement at least one of `/adm/obj/{n}/xyz`
    /// (Cartesian, packed) or `/adm/obj/{n}/aed` (polar, packed) for position"*, and of a
    /// RECEIVER: *"Handle at least one of `/adm/obj/{n}/xyz` or `/adm/obj/{n}/aed`"*.
    /// Until this function existed Echoel sent NEITHER packed form, so it was not a
    /// conforming sender — and, the sharper half, **a conforming receiver is not required to
    /// handle `/azim`, `/elev` or `/dist` at all.** The unpacked-only feed could be dropped
    /// entirely by a renderer that is fully within spec. Packing therefore makes the object
    /// MORE likely to be understood, not less, which is the opposite of what a wire-format
    /// change usually risks — worth stating, because that assumption is what would otherwise
    /// keep this unfixed.
    ///
    /// The second reason is the spec's own: *"Use packed messages (`xyz` or `aed`) for
    /// position updates to ensure atomic delivery."* Three datagrams can arrive split across
    /// two render ticks, so a moving object can be rendered at a position it never occupied —
    /// one axis from this frame, two from the last.
    ///
    /// ⛔ AND THE ALL-THREE CONDITION IS #1140, NOT AN OPTIMISATION. A packed message must
    /// carry three numbers; a partially measured frame has no third number to carry, and the
    /// only ways to send one anyway are to invent it or to repeat a stale one. Both are
    /// exactly what the per-axis gates above exist to prevent — an unmeasured breath would
    /// ride out as azimuth −180 (hard left) and an unmeasured coherence as distance 1 (far
    /// wall), which a renderer cannot tell from a performer who really is there. So: all
    /// three measured ⇒ one atomic `/aed`; anything less ⇒ the individual leaves, each still
    /// riding its own channel's measurement. Atomicity where possible, an invented number
    /// never.
    ///
    /// ⚠️ IT TAKES THE OUTPUT OF THE MAPPERS RATHER THAN THE FRAME, deliberately (#416).
    /// Re-deriving azimuth/elevation/distance here would put each mapping AND each
    /// measurement gate in a second home, and the bio arm's gates are the most carefully
    /// argued lines in this file. This function only regroups what the mappers already
    /// decided, so a value in `/aed` is bit-identical to the one that would have gone out
    /// alone, and a leaf the gates withheld cannot reappear here.
    ///
    /// ⚠️ NOT a bundle. The spec notes packed values *"can also be grouped with other
    /// messages in an OSC bundle for atomic/synchronous delivery with a shared timestamp"* —
    /// that is a further step, needs `#bundle` framing in `OSCSender.encode`, and is not what
    /// the MVI asks for. One packed message per position update is the conformance bar.
    public nonisolated static func packedPositionMessages(_ msgs: [(String, Float)],
                                                          object n: Int) -> [(String, [Float])] {
        let prefix = "/adm/obj/\(max(1, n))"
        let azimuth = prefix + "/azim", elevation = prefix + "/elev", distance = prefix + "/dist"
        func value(_ address: String) -> Float? {
            msgs.first(where: { $0.0 == address })?.1
        }
        guard let a = value(azimuth), let e = value(elevation), let d = value(distance) else {
            return msgs.map { ($0.0, [$0.1]) }
        }
        // `/aed` takes the position's place at the FRONT; every non-positional address keeps
        // its relative order behind it (the music arm's `/gain` followed its three axes).
        var out: [(String, [Float])] = [(prefix + "/aed", [a, e, d])]
        for (address, v) in msgs where address != azimuth && address != elevation && address != distance {
            out.append((address, [v]))
        }
        return out
    }

    /// The SCENE arm's fold — the same packing rule as `packedPositionMessages`, applied to a
    /// flat list that spans MANY objects instead of one.
    ///
    /// ⭐ WHY THIS IS NOT A SECOND HOME FOR THE RULE (#416). It decides nothing about WHICH
    /// leaves pack or when; it only answers "whose leaves are these" and hands each object's
    /// own list to the single fold above. The all-three condition, the `/aed` address, the
    /// front position and the pass-through order all stay in exactly one place — change the
    /// rule there and this arm follows without being touched.
    ///
    /// ⛔ THE REGISTERED DESIGN FOR THIS SAID FOUR FILES AND WAS WRONG, measured rather than
    /// recalled. It read: *"the fold has to move to a Foundation-only home, because
    /// `ADMOSCSender.swift` sits inside `#if canImport(Network)` while the formatter is
    /// deliberately Foundation-only"* — and that is true of the FORMATTER and irrelevant to the
    /// SEND loop. `send(scene:dialect:)` is a method on this very type, inside that very guard,
    /// so it reaches `Self.packedPositionMessages` directly; nothing moves and
    /// `TheADMOSCLeavesAreTheSpecsTests` claim 1 keeps its `/aed` literal here. **A note that
    /// makes work BIGGER than it is parks a real repair** — the mirror of the law CLAUDE.md
    /// states for the slogan that made the iPad switch-back sound like one line.
    ///
    /// ⚠️ GROUPED BY PARSED ADDRESS, NEVER BY EMISSION STRIDE. `SpatialSceneOSCFormatter`
    /// happens to emit each object's four leaves contiguously, four at a time; relying on that
    /// would make this silently wrong the day a channel is added or reordered, and nothing
    /// would go red. Prefix matching is unambiguous for the same reason it is here at all:
    /// `/adm/obj/11/azim` does not carry the prefix `/adm/obj/1/`, because the character after
    /// the index is a slash.
    ///
    /// ⚠️ ORDER IS POSITIONAL, not "objects first". Each object's packed block takes the place
    /// of its FIRST leaf and the rest of that object's leaves are dropped from their old
    /// positions; anything outside the ADM object namespace passes through where it stood. A
    /// two-pass version that appended the non-object messages at the end was written first and
    /// discarded: it is a no-op today (this formatter emits nothing else) and would silently
    /// reorder the wire the day it is not.
    ///
    /// ⛔ THE CARTESIAN HALF OF THE FINDING STAYS OPEN, and saying so is the point. A
    /// `.admOSCCartesian` scene emits `/x`, `/y`, `/z`, which the fold does not recognise, so
    /// those objects pass through UNPACKED — the same behaviour as before this function, not a
    /// regression. The spec's packed Cartesian address is not verified here and this repository
    /// does not build to a remembered spec.
    public nonisolated static func packedSceneMessages(_ msgs: [(String, Float)],
                                                       dialect: SpatialOSCDialect)
        -> [(String, [Float])] {
        switch dialect {
        case .admOSC, .admOSCCartesian:
            break
        case .iemMultiEncoder:
            // A DIFFERENT standard, not an unpacked version of this one: the IEM MultiEncoder
            // has 0-based sources, degrees, dB and no distance parameter, and `/aed` means
            // nothing in its vocabulary. Folding here would emit an address its receiver
            // cannot read. The switch is exhaustive on purpose (#431) — a new dialect has to
            // state which side it is on rather than inheriting an answer.
            return msgs.map { ($0.0, [$0.1]) }
        }

        var groups: [Int: [(String, Float)]] = [:]
        for m in msgs {
            guard let n = Self.admObjectIndex(m.0) else { continue }
            groups[n, default: []].append(m)
        }

        var emitted = Set<Int>()
        var out: [(String, [Float])] = []
        out.reserveCapacity(msgs.count)
        for m in msgs {
            guard let n = Self.admObjectIndex(m.0) else {
                out.append((m.0, [m.1]))
                continue
            }
            guard !emitted.contains(n) else { continue }
            emitted.insert(n)
            out.append(contentsOf: Self.packedPositionMessages(groups[n] ?? [], object: n))
        }
        return out
    }

    /// The 1-based object index an ADM-OSC address belongs to, or `nil` when the address is
    /// not in that namespace at all.
    ///
    /// ⚠️ `nil` FOR INDEX 0 IS DELIBERATE. `packedPositionMessages` raises its argument with
    /// `max(1, n)`, so handing it a 0 would make it look for leaves under `/adm/obj/1` and
    /// quietly mis-group a whole object. Refusing to recognise the address leaves it passing
    /// through untouched, which is the honest outcome for a namespace nothing in this
    /// repository emits.
    nonisolated static func admObjectIndex(_ address: String) -> Int? {
        let root = "/adm/obj/"
        guard address.hasPrefix(root) else { return nil }
        let rest = address.dropFirst(root.count)
        guard let slash = rest.firstIndex(of: "/") else { return nil }
        guard let n = Int(rest[rest.startIndex..<slash]), n >= 1 else { return nil }
        return n
    }

    /// The bio arm's object gain, or `nil` when nothing measures motion — in which case
    /// this sender asserts no gain at all and the renderer keeps whatever it has.
    ///
    /// WHY NIL RATHER THAN A NUMBER, and this is the part a first attempt got wrong.
    /// `sendIfFresh` has TWO gain arms for the same object index, alternating at 20 Hz:
    /// `MusicMediaMap.admMessages` while `MusicalFrame.isSounding`, this one otherwise.
    /// `isSounding` is `!notes.isEmpty && masterLevel > 0`, so the arms swap at every rest
    /// and every phrase boundary, and ADM-OSC carries no slew. So the old constant `0.3`
    /// here was NOT "the only level this object could ever have" — it was the level at
    /// musical rest, and it happened to equal the music arm's own floor, i.e. a clean duck.
    /// Substituting unity would have inverted that into a JUMP of up to +8 dB above where
    /// the music arm left off, on every rest, snapping back at the next note onset — a
    /// boost of whatever tail, bleed or room sits on that object, exactly when the music
    /// stops. Sending nothing produces no step at all, and in a bio-only rig it leaves
    /// `/adm/obj/{n}/gain` unasserted, which is the honest statement: Echoel is not
    /// driving this parameter today. It also matches how the sibling defect was fixed on
    /// the OSC side (`/echoelmusic/bio/motion` is omitted, not zeroed).
    ///
    /// Parameterised on the predicate instead of reading it, so BOTH answers are reachable
    /// from a test. Branching on `ModSource.motion.hasProducer` INSIDE the tests would
    /// leave the live arm permanently dead — prose in `if` clothing — and would silently
    /// switch off the regression assertions on the day a producer lands.
    nonisolated static func motionGain(motion: Float, hasProducer: Bool) -> Float? {
        guard hasProducer else { return nil }
        // Bit-identical to the expression this replaced (`0.3 + motion * 0.7`), because
        // `1 - Float(0.3)` and `Float(0.7)` are the same binary32 value. The live mapping
        // is not being retuned; only its dormant case is being answered differently.
        return clamp(motionRestingGain + motion * (1 - motionRestingGain), 0, 1)
    }

    /// Object gain with a MEASURED motion modulator at rest. Named rather than inlined so
    /// the "what does an unmoving body sound like" decision has one place to be argued
    /// with. Unused while `hasProducer` is false — kept because it is the right resting
    /// point for a live motion channel, not because anything reads it today.
    ///
    /// `nonisolated` deliberately: this class is `@MainActor`, and CLAUDE.md records that
    /// Xcode's toolchain isolates an immutable `static let` on such a class even where
    /// SwiftPM accepts it. Both call sites are on the main actor anyway, so this
    /// pre-empts the toolchain disagreement rather than being load-bearing.
    nonisolated static let motionRestingGain: Float = 0.3

    nonisolated private static func clamp(_ v: Float, _ lo: Float, _ hi: Float) -> Float {
        Swift.min(Swift.max(v, lo), hi)
    }
}
#endif
