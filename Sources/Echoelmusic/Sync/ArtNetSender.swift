//
//  ArtNetSender.swift
//  Echoelmusic — EchoelSync / EchoelLux
//
//  Native Art-Net (ArtDMX) output over UDP — the open, royalty-free lighting
//  control standard (DMX-512 over IP, port 6454). No SDK, no dependency: builds
//  the ArtDMX packet by hand and sends it via Network.framework, the same way
//  OSCSender/ADMOSCSender stream bio out. Makes the body drive stage lighting:
//  a bio-reactive fixture (dimmer + RGB) that breathes with you.
//
//  Doctrine fit: Art-Net is a documented wire protocol (Artistic Licence) —
//  exactly the "speak open standards, depend on nothing" lane. sACN/E1.31 is a
//  natural follow-up (same idea, multicast).
//
//  SAFETY (CLAUDE.md / W3C WCAG): max 3 Hz flash. Bio is a slow signal and we
//  send smoothed continuous values (no strobing), so the dimmer fades rather
//  than flashes — within the epilepsy limit by construction.
//
//  ArtDMX packet (Art-Net 4):
//    "Art-Net\0" (8) · OpCode 0x5000 LE (2) · ProtVer 14 BE (2) · Sequence (1)
//    · Physical (1) · SubUni (1) · Net (1) · LengthHi/Lo BE (2) · Data[Length]
//

#if canImport(Network)
import Foundation
import Network
#if canImport(Observation)
import Observation
#endif

@MainActor
@Observable
public final class ArtNetSender {

    /// Art-Net node host — UNICAST to the node's IP. #1219 (audit 2026-09-10 `output-sync-2`):
    /// the default WAS limited broadcast 255.255.255.255, which iOS gates behind the
    /// multicast/broadcast networking entitlement this app does not hold — an operator who
    /// switched the route on without typing a node IP saw the patchbay dot go "sending" while
    /// nothing could reach the rig. The default is now the same unicast address sACN has always
    /// used (`defaultHost`); a typed broadcast address still works where the OS allows it.
    public var host: String {
        didSet { Self.persistTarget(host, port, universe); reconnectIfActive() }
    }

    /// Art-Net port is fixed at 6454 by the standard, but kept configurable.
    public var port: UInt16 {
        didSet { Self.persistTarget(host, port, universe); reconnectIfActive() }
    }

    /// 15-bit Art-Net port address (Net<<8 | SubUni). Universe 0 by default.
    public var universe: Int {
        didSet { Self.persistTarget(host, port, universe) }   // packet content, no socket change
    }

    /// DMX value resolution per parameter. 16-bit uses paired coarse/fine
    /// channels (65 536 steps) for smooth, professional fades; 8-bit (256 steps)
    /// is the legacy mode for simple fixtures. Defaults to 16-bit precision.
    /// Selectable since #730 (`PatchbayView`'s Light section, one Picker for both
    /// protocols); before that it had no writer anywhere in the repository.
    ///
    /// ⚠️ THE `didSet` IS NOT DECORATION (#732). `sendIfFresh` has a HOLD branch that
    /// reuses `lastChannels` when no allowed source is available, so a Blackout or
    /// Grand-Master move is still honoured (L1). That array is sized for the
    /// resolution in force when it was built. While nothing could write this
    /// property the sizes could never disagree; the moment a door existed, flipping
    /// it mid-hold left the held array at a stride the encoders no longer use.
    /// Re-encoding — rather than clearing — is what keeps the L1 guarantee.
    ///
    /// ⛔ AND THE TWO QUANTITIES #732 WROTE HERE WERE BOTH TOO MILD (#733). It said
    /// "one tick" and "until the next fresh frame (~1 s)". Measured:
    ///   · NOT one tick. The hold branch stores its own input straight back
    ///     (`channels = lastChannels`, then `lastChannels = channels`), so without
    ///     this `didSet` the wrongly-sized array is re-stored on EVERY hold tick —
    ///     33 ms apart, not once.
    ///   · NOT ~1 s, and there is no clock in it. The bio branch above reads
    ///     `bus.latestBio`, the RAW snapshot, with no freshness window, and nothing
    ///     ever sets it back to nil. So the hold branch is reached only when there
    ///     is no sounding music AND no bio frame from an egress-ALLOWED source has
    ///     ever arrived — and `BioEgressPolicy` gates HealthKit/Watch/ring sources
    ///     permanently, by SOURCE and not by age. For an operator on a wrist source
    ///     there is no "next fresh frame": clearing would have frozen the blackout
    ///     for the rest of the session. The decision was right and the reasoning
    ///     understated it in both directions.
    public var resolution: DMXResolution = .sixteenBit {
        didSet {
            lastChannels = Self.reencode(lastChannels, from: oldValue, to: resolution)
            UserDefaults.standard.set(resolution.rawValue, forKey: Self.resolutionKey)
        }
    }

    public enum DMXResolution: String, Sendable, CaseIterable {
        case eightBit  = "8-bit"
        case sixteenBit = "16-bit"
    }

    public private(set) var isActive = false
    /// The SUBMISSION time of the most recent packet whose completion then reported no local
    /// error — an `@Observable` mirror of `pump.acceptedSentAt`, kept as stored state because
    /// `NetworkActivityDot` observes it and a computed property over `@ObservationIgnored`
    /// storage is not tracked. One writer: `applySendOutcome`.
    ///
    /// ⛔ THIS DOC SAID "the last packet the network stack ACCEPTED", and #1446 measured the
    /// clock: the value is read in the tick, before `NWConnection.send` is called, so it is
    /// when we HANDED IT OVER — which is the right number for a keep-alive and the wrong word
    /// for what happened. It is still not delivery, and `.contentProcessed` never said it was.
    public private(set) var lastSentTimestamp: TimeInterval = 0

    /// #1218 (audit 2026-09-10 `output-sync-3`) — KEEP-ALIVE, the same number as sACN so the
    /// two light outputs are one decision: the sender emitted only on change, and an Art-Net
    /// node that hears no ArtDmx for ~4 s treats the source as gone (holds or blacks out per
    /// node config). Art-Net has no terminate opcode; the node simply stops hearing us.
    public nonisolated static let keepAliveSeconds: TimeInterval = SACNSender.keepAliveSeconds

    /// L1 Grand Master (every lighting desk's first fader): scales the dimmer
    /// of everything Echoel sends, 0…1. Live state, not persisted — a fresh
    /// launch always starts at full (predictable for the operator).
    public var grandMaster: Float = 1
    /// L1 Blackout: forces the dimmer to 0 NOW (a one-off cut to dark is not a
    /// flash; the RETURN to light rides the normal slew-limiter, so it can
    /// never strobe). Colour channels keep streaming so un-blackout is seamless.
    public var blackout = false

    /// #1006 — how many identical fixtures this stream addresses, and how far apart they sit.
    ///
    /// Default 1, so the wire is byte-identical to every build before this pair existed. The
    /// fan happens AFTER the dimmer and colour slews below, never before: `FlashGuard`
    /// smooths the ONE block, and copying an already-safe block is what keeps the 3 Hz
    /// ceiling a guarantee instead of N independent histories to get right.
    ///
    /// ADDRESSING, not spatial differentiation — all fixtures receive the SAME colour,
    /// because this arm produces exactly one. `spacing` 0 means back-to-back.
    /// ⭐ PERSISTED since #1442, unlike `grandMaster`/`blackout` above — and the difference is
    /// not taste. The rig's SHAPE belongs to the installation, the way `host`/`port`/`universe`
    /// already do; the master fader and the blackout belong to the SESSION, so a stored 5 %
    /// master would read as broken hardware on the next launch. See `decodedFixtureCount` for
    /// why no `+1` offset is needed here although `universe` needs one.
    public var fixtureCount: Int = 1 {
        didSet { UserDefaults.standard.set(fixtureCount, forKey: Self.fixtureCountKey) }
    }
    public var fixtureSpacing: Int = 0 {
        didSet { UserDefaults.standard.set(fixtureSpacing, forKey: Self.fixtureSpacingKey) }
    }


    @ObservationIgnored private weak var bus: EngineBus?
    @ObservationIgnored private var connection: NWConnection?
    @ObservationIgnored private let loop = PollingLoop()
    /// THE EXECUTION STATE of this output: the one in-flight slot, the connection epoch, the
    /// accepted OUTPUT anchors (dimmer/colour) and the accepted DELIVERY anchors. Internal
    /// rather than private so the accounting guard can drive the real state machine without a
    /// socket; the only production writers are `connect`, `stop` and `applySendOutcome`.
    ///
    /// ⛔ EIGHT STORED PROPERTIES STOOD HERE AND ARE GONE (#1446), among them `lastDimmer` and
    /// `lastColour`. Those two advanced on COMPUTE, so an outage let the fade finish inside
    /// this object while the receiver still sat at the old value — and the first packet after
    /// recovery carried the END of the ramp. A slew-limiter measured from a value nobody
    /// received is not a slew-limiter.
    @ObservationIgnored var pump = LightSendPump()
    /// Art-Net wire sequence — advanced per packet CONSTRUCTED, which is what keeps every
    /// attempt (including a retry) uniquely numbered and in order for the node. A GAP is
    /// harmless: Art-Net nodes use the field to reject out-of-order/duplicate packets, never
    /// to detect loss. ⚠️ It is not evidence of delivery and must never be read as such, and
    /// it is neither the generation nor the epoch — three counters, three questions.
    @ObservationIgnored private var sequence: UInt8 = 1

    /// The creative lighting state (founder decision 2026-09-22), weak — the store lives at
    /// app level and is READ here. This adapter does not own it and must never write it; the
    /// operator's `grandMaster` above is a different concept and stays this object's own.
    @ObservationIgnored private weak var lighting: LightingStore?
    /// Last RAW colour channels + dimmer target actually chosen (pre-master,
    /// pre-slew). Held so a tick with NO fresh/allowed source can still honor a
    /// Blackout / Grand-Master move from the last lit state (L1 — a stale or
    /// egress-gated source must never freeze a blackout). Empty = never lit yet.
    @ObservationIgnored private var lastChannels: [UInt8] = []
    @ObservationIgnored private var lastTarget: Float = 0

    /// The one unicast default both light outputs share (CLAUDE.md PLATFORM NOTES: "DMX:
    /// Requires network 192.168.1.100"). `SACNSender.init` carries the same literal.
    public nonisolated static let defaultHost = "192.168.1.100"

    /// #1219 — the OS's own word on the socket, for the patchbay to show. `nil` while nothing
    /// has gone wrong; the last `.failed`/`.waiting` state or send error otherwise, cleared
    /// when the connection reports `.ready` or a send succeeds. The sending DOT deliberately
    /// does not read this (UDP reaches `.ready` for any routable literal — the dot's own
    /// note); this is the complementary half: what the OS refused, not what it accepted.
    public private(set) var lastError: String?

    public init(host: String = ArtNetSender.defaultHost, port: UInt16 = 6454, universe: Int = 0) {
        let d = UserDefaults.standard
        self.host = d.string(forKey: Self.hostKey) ?? host
        let p = d.integer(forKey: Self.portKey)
        self.port = (p > 0 && p <= 65_535) ? UInt16(p) : port
        // universe persists as stored+1 so a legitimate 0 is distinguishable from "unset".
        let u = d.integer(forKey: Self.universeKey)
        self.universe = u > 0 ? (u - 1) : max(0, universe)
        // #1442 — the show shape, through the ONE shared decoder. Nothing stored ⇒ exactly the
        // values this file declares above, so a fresh install behaves as it did before any of
        // these keys existed.
        self.resolution = Self.decodedResolution(d.string(forKey: Self.resolutionKey))
        self.fixtureCount = Self.decodedFixtureCount(d.integer(forKey: Self.fixtureCountKey))
        self.fixtureSpacing = Self.decodedFixtureSpacing(d.integer(forKey: Self.fixtureSpacingKey))
    }

    public func start(subscribing bus: EngineBus) {
        guard !isActive else { return }
        self.bus = bus
        connect()
        isActive = true
        // The interval is FlashGuard's, not this file's (#372): the flash cap below is
        // derived from the same constant, so a change here cannot outrun the safety bound.
        loop.start(interval: .milliseconds(FlashGuard.senderTickMilliseconds)) { [weak self] in
            guard let self, let bus = self.bus else { return }
            self.sendIfFresh(from: bus)
        }
    }

    /// Attach the creative lighting state (weak — the store lives at app level). Idempotent,
    /// called from `applyRouting` like `ADMOSCSender.attachScene`. Detached (nil) the sender
    /// falls back to the identity, so an un-wired build is bit-identical to the one before
    /// this seam existed.
    public func attachLighting(_ store: LightingStore?) {
        lighting = store
    }

    public func stop() {
        loop.stop()
        connection?.cancel()
        connection = nil
        isActive = false
        // A completion still in flight when the socket dies must not commit into whatever
        // session comes next: close the epoch, retire every outstanding generation, and drop
        // the OUTPUT anchors so the next session snaps like a cold start (#1445/#1446).
        pump.retire()
    }

    // MARK: - Target persistence + live reconnect

    private static let hostKey = "net.artnet.host"
    private static let portKey = "net.artnet.port"
    private static let universeKey = "net.artnet.universe"
    private static func persistTarget(_ host: String, _ port: UInt16, _ universe: Int) {
        let d = UserDefaults.standard
        d.set(host, forKey: hostKey)
        d.set(Int(port), forKey: portKey)
        d.set(universe + 1, forKey: universeKey)   // +1 so a valid universe 0 ≠ "unset"
    }
    // MARK: - Show persistence (resolution + rig shape)

    /// #1442 — the light TARGET persisted and the light SHOW did not, inside ONE panel. An
    /// operator aimed the app at a rig, told it the rig has twelve lamps eight slots apart,
    /// relaunched, and was pointed at the same rig addressing ONE lamp at 16-bit.
    ///
    /// ⚠️ THE OLD BEHAVIOUR WAS DELIBERATE and `PatchbayView` named the price of changing it:
    /// *"a stored count of 32 would fan a stranger's rig on first open."* Measured, that risk
    /// is already carried by the keys above: the stream only runs when a PERSISTED patchbay
    /// route is enabled (`EchoelmusicApp`: `hasEnabledRoute(toSink: "artnet.out")`) and it is
    /// aimed at the PERSISTED host/port/universe. A first open that emits anything is already
    /// aimed at the stored rig; the shape was the only part of that aim that did not survive.
    ///
    /// ⭐ EACH KEY IS WRITTEN BY ITS OWN SETTER, not by one combined `persistTarget`-style
    /// helper. Three fields written together would let an observer firing mid-`init` store a
    /// sibling's DEFAULT over that sibling's stored value; per-field writes make the order
    /// irrelevant, which is worth more than the symmetry with the block above.
    private static let resolutionKey = "net.artnet.resolution"
    private static let fixtureCountKey = "net.artnet.fixtureCount"
    private static let fixtureSpacingKey = "net.artnet.fixtureSpacing"

    /// The ONE decode rule for the show fields, shared by both light senders (#416) the same
    /// way `DMXResolution` and `reencode` already are. The two senders keep SEPARATE keys —
    /// they address different rigs in general — but a clamp written twice is the defect
    /// whether or not the two copies agree today.
    ///
    /// ⭐ NO `+1` OFFSET HERE, unlike `universe`, and copying the neighbour would have been the
    /// obvious move. `universe` needs the offset because 0 is a LEGAL Art-Net universe and
    /// `UserDefaults.integer(forKey:)` also returns 0 for "never written". These two do not:
    /// a fixture COUNT is legal only from 1 up, so a stored 0 unambiguously means unset; and
    /// `fixtureSpacing`'s own default IS 0, so unset and a stored 0 decode to the same value.
    /// An offset would have been ceremony that adds a way to be wrong.
    public static func decodedResolution(_ stored: String?) -> DMXResolution {
        guard let stored, let r = DMXResolution(rawValue: stored) else { return .sixteenBit }
        return r
    }
    /// Clamped to the fan's own ceiling. `DMXFixtureFan.fanned` clamps too, so this is defence
    /// in depth — but the PROPERTY is what the patchbay shows the operator, and showing 9999
    /// while sending 32 is a lie about the rig.
    public static func decodedFixtureCount(_ stored: Int) -> Int {
        stored > 0 ? Swift.min(stored, DMXFixtureFan.maxFixtures) : 1
    }
    public static func decodedFixtureSpacing(_ stored: Int) -> Int {
        Swift.max(stored, 0)
    }

    /// A host/port edit takes effect immediately while the output is live (connect()
    /// otherwise only runs in start()): drop the old socket, reconnect. Idle ⇒ no-op.
    private func reconnectIfActive() {
        guard isActive else { return }
        connection?.cancel()
        connect()
    }

    // MARK: - Connection

    private func connect() {
        // #1446 — a new socket is a NEW DELIVERY EPOCH. Opened before the port guard on
        // purpose: if the port is unusable we have already cancelled the old connection, so
        // retiring its outstanding attempts is the conservative direction. `openEpoch` also
        // arms `needsResend`, which is what makes the current look go out on the new
        // connection instead of waiting for the keep-alive.
        pump.openEpoch()
        let epoch = pump.epoch
        guard let nwPort = NWEndpoint.Port(rawValue: port) else { return }
        // Allow sending to a broadcast address (255.255.255.255) as well as unicast.
        let params = NWParameters.udp
        params.allowLocalEndpointReuse = true
        let endpoint = NWEndpoint.hostPort(host: .init(host), port: nwPort)
        let conn = NWConnection(to: endpoint, using: params)
        // #1219 — surface `.failed`/`.waiting` (no route, broadcast without entitlement, no
        // interface) into `lastError`. Runs on `.main` (the start queue), hence assumeIsolated.
        conn.stateUpdateHandler = { [weak self] state in
            MainActor.assumeIsolated {
                // An old connection's health says nothing about the one that replaced it —
                // without this gate a dying socket overwrites the new socket's `lastError`
                // and the operator reads a fault that no longer exists (#1446).
                guard let self, epoch == self.pump.epoch else { return }
                switch state {
                case .failed(let error):  self.lastError = "Art-Net: \(error.localizedDescription)"
                case .waiting(let error): self.lastError = "Art-Net waiting: \(error.localizedDescription)"
                case .ready:              self.lastError = nil
                default:                  break
                }
            }
        }
        conn.start(queue: .main)
        self.connection = conn
    }

    // MARK: - Subscriber tick

    private func sendIfFresh(from bus: EngineBus) {
        // Music drives the COLOUR when it's sounding (pitch/chord → SpectralColor),
        // bio drives it otherwise — bio stays the co-modulator. Dedup on the chosen
        // source's timestamp so a music-only change still updates the fixture.
        let music = bus.freshMusical(maxAge: 1.5)
        let useMusic = music?.isSounding ?? false
        let sourceTimestamp: TimeInterval
        var channels: [UInt8]
        let target: Float
        if useMusic, let m = music {
            sourceTimestamp = m.timestamp
            channels = MusicMediaMap.dmxChannels(forMusic: m, resolution: resolution)
            target = MusicMediaMap.dimmerUnit(forMusic: m)
        } else if let frame = bus.latestBio, BioEgressPolicy.allowsEgress(frame.source) {
            // 5.1.3: a HealthKit/Watch/ring-sourced frame must not drive a network
            // fixture (unicast DMX leaves the device). Such a frame is treated as
            // no-bio here — the light holds its last state (same gate OSC/ADM apply).
            sourceTimestamp = frame.timestamp
            channels = Self.dmxChannels(for: frame, resolution: resolution)
            target = Self.dimmerUnit(for: frame)
        } else if !lastChannels.isEmpty {
            // No fresh/allowed source, but the rig is already lit: hold the last
            // colour and keep running the master/slew logic below so a Blackout or
            // Grand-Master move is honored NOW (L1 — a stale/gated source must never
            // freeze a blackout). The guard uses the unchanged timestamp, so this
            // only emits while master state moves or the slew is still settling.
            // Held channels are always from an allowed source (a gated frame never
            // reaches the store below), so nothing new egresses.
            sourceTimestamp = pump.acceptedFrameTimestamp
            channels = lastChannels
            target = lastTarget
        } else {
            return
        }
        // Remember the RAW colour + target so a later no-source tick can still
        // honor master/blackout from the held state.
        lastChannels = channels
        lastTarget = target
        // CREATIVE stage — the composition's own level, BEFORE any operator or safety stage.
        // ⚠️ `lastTarget` above deliberately holds the GENERATED value, never this one: the
        // hold arm re-enters here every tick, so caching the scaled value would multiply the
        // look in again on each pass and fade the rig to nothing on a stale source.
        let look = LightingStore.sanitizedLookIntensity(lighting?.lookIntensity
                                                        ?? LightingStore.defaultLookIntensity)
        let creative = LightingStore.creativeTarget(target, lookIntensity: look)
        // Grand Master scales the CREATIVE target; Blackout cuts to 0 instantly (and
        // resets the slew anchor, so the return to light ramps up from dark).
        let mastered = Self.masteredDimmer(creative, grandMaster: grandMaster, blackout: blackout)
        // Send when the source is fresh, the master state moved, the creative level moved, or
        // the slew ramp hasn't reached its target yet (a paused source must not freeze a fade
        // mid-ramp, and must never block a blackout).
        // ⭐ EVERY COMPARISON IS AGAINST WHAT THE NETWORK ACCEPTED (#1446), never against what
        // a previous tick computed. During an outage these anchors stand still, so each reason
        // to send stays true and the retry keeps being eligible instead of being consumed.
        let masterMoved = grandMaster != pump.acceptedGrandMaster || blackout != pump.acceptedBlackout
        let lookMoved = look != pump.acceptedLookIntensity
        let slewSettling = pump.acceptedDimmer >= 0 && abs(mastered - pump.acceptedDimmer) > 0.001
        // #1218 — or the node is about to forget us: re-send the held look.
        let keepAliveDue = pump.keepAliveDue(now: CFAbsoluteTimeGetCurrent(),
                                             after: Self.keepAliveSeconds)
        // ⭐ MAX_IN_FLIGHT = 1 (#1446). One ordinary data send at a time: while a completion is
        // outstanding this tick builds NOTHING — no packet, no sequence number, no generation.
        // The desired state is not queued; it is simply re-read from the bus and the controls
        // on the next eligible tick, so repeated ticks coalesce to the LATEST state by
        // construction. This is what makes the outstanding work bounded by code rather than by
        // how fast the network happens to be.
        guard !pump.isBusy else { return }
        guard pump.needsResend || sourceTimestamp != pump.acceptedFrameTimestamp
                || masterMoved || lookMoved
                || slewSettling || keepAliveDue else { return }
        // ⛔ THE FOUR DELIVERY ANCHORS USED TO BE ASSIGNED HERE, and that was the first half of
        // the defect (#1445): `send` below reports `false` with no socket, so this line consumed
        // `lookMoved`, `masterMoved`, the freshness compare and the keep-alive clock for a packet
        // that never left. ⛔ AND THE SECOND HALF SURVIVED THAT REPAIR (#1446): the FADE still
        // advanced here, so an outage finished the ramp internally and the first packet after
        // recovery carried its END. Both categories now commit in `applySendOutcome`, from the
        // completion, and only for an attempt whose local processing reported no error.
        // Hard flash guarantee for PHYSICAL fixtures: slew-limit the dimmer
        // (luminance) channel so even a pathological input jump can never strobe
        // the lights. The step is `FlashGuard.senderTickDelta` — a per-SECOND
        // luminance velocity resolved at THIS loop's interval (#372), so halving
        // the interval above halves the step instead of doubling the flash rate.
        // At today's 33 ms that is the same 0.08 as before → full fade ≥0.4 s.
        let limited = FlashGuard.slewedDimmer(from: pump.acceptedDimmer, to: mastered,
                                              blackout: blackout,
                                              maxDelta: FlashGuard.senderTickDelta)
        Self.applyDimmer(&channels, resolution: resolution, dimmer: limited)
        // Slew the COLOUR channels too — a fast hue swing at high dimmer would
        // otherwise strobe even though the dimmer is rate-limited (Law 6 gap).
        // ⚠️ A COPY of the accepted anchor, never the anchor itself: `applySlewedColour`
        // updates its `last` in place, and writing straight into the stored anchor is how the
        // hue walked to its destination during an outage (#1446). The candidate commits with
        // the packet or dies with it.
        var colour = pump.acceptedColour
        Self.applySlewedColour(&channels, resolution: resolution, last: &colour,
                               maxDelta: FlashGuard.senderTickDelta)
        let fanned = DMXFixtureFan.fanned(channels, count: fixtureCount, spacing: fixtureSpacing)
        let packet = Self.artDMXPacket(universe: universe, sequence: sequence, channels: fanned)
        sequence = sequence == 255 ? 1 : sequence &+ 1   // 1...255, 0 = disabled
        let attempt = pump.submit(frameTimestamp: sourceTimestamp,
                                  grandMaster: grandMaster,
                                  blackout: blackout,
                                  lookIntensity: look,
                                  sentAt: CFAbsoluteTimeGetCurrent(),
                                  dimmer: limited,
                                  colour: colour)
        // No socket ⇒ the handover never happened ⇒ free the slot again and commit nothing.
        // Without this the ONE in-flight slot would latch shut the first time the cable is out.
        if !send(packet, attempt: attempt) { pump.abandon(attempt) }
    }

    /// Hand one packet to the stack. ⚠️ NO connection ⇒ NO attempt and NOTHING committed, so
    /// the next tick still sees every reason to retry (#1445). That early return is the whole
    /// reason the anchors moved out of the tick.
    @discardableResult
    private func send(_ data: Data, attempt: LightSendAttempt) -> Bool {
        guard let conn = connection else { return false }
        // #1219 — a send the OS refuses (e.g. EPERM on a broadcast literal) is the error an
        // operator needs to see; a send it accepts clears it. Same queue as the state handler.
        conn.send(content: data, completion: .contentProcessed { [weak self] error in
            MainActor.assumeIsolated {
                guard let self else { return }
                if attempt.epoch == self.pump.epoch {
                    if let error { self.lastError = "Art-Net send: \(error.localizedDescription)" }
                    else if self.lastError?.hasPrefix("Art-Net send:") == true { self.lastError = nil }
                }
                self.applySendOutcome(attempt, failed: error != nil)
            }
        })
        return true
    }

    /// Commit one attempt's DELIVERY anchors, or refuse. Internal, not private: the accounting
    /// guard drives THIS method — the same one the production completion calls — so the law is
    /// proven end to end without a socket and without a test-only branch in shipping logic.
    func applySendOutcome(_ attempt: LightSendAttempt, failed: Bool) {
        pump.complete(attempt, failed: failed)
        // The ONE observable mirror (see the property's doc). Compared before assigning so a
        // refused completion cannot churn every `@Observable` reader of the activity dot.
        if lastSentTimestamp != pump.acceptedSentAt { lastSentTimestamp = pump.acceptedSentAt }
    }

    // MARK: - Pure kernels (testable without a socket)

    /// Maps a bio frame to a 4-channel fixture: dimmer + R + G + B (0...255).
    /// Smooth, continuous values — no strobing (epilepsy-safe by construction).
    ///   ch1 dimmer = 0.3 + 0.7·coherence (always lit, brighter when coherent)
    ///   ch2 R = heart rate (normalized)   — energy
    ///   ch3 G = HRV                        — calm/variability
    ///   ch4 B = breath phase              — breathing motion
    public static func dmxChannels(for f: BioSampleFrame) -> [UInt8] {
        let hrNorm = clampUnit((f.heartRateBPM - 40) / 160)
        let dimmer = clampUnit(0.3 + 0.7 * f.coherence)
        return [
            byte(dimmer),
            byte(hrNorm),
            byte(clampUnit(f.hrvNormalized)),
            byte(clampUnit(f.breathPhase))
        ]
    }

    /// 16-bit fixture mapping: each of the four parameters becomes a
    /// coarse(MSB)+fine(LSB) channel pair (8 channels total, 65 536 steps each),
    /// the professional standard for click-free dimmer/colour fades.
    /// Channel order: dimmer(hi,lo) · R(hi,lo) · G(hi,lo) · B(hi,lo).
    public static func dmxChannels16(for f: BioSampleFrame) -> [UInt8] {
        let hrNorm = clampUnit((f.heartRateBPM - 40) / 160)
        let dimmer = clampUnit(0.3 + 0.7 * f.coherence)
        return word(dimmer) + word(hrNorm) + word(clampUnit(f.hrvNormalized)) + word(clampUnit(f.breathPhase))
    }

    /// Resolution-dispatched mapping used by the live sender (and sACN).
    public static func dmxChannels(for f: BioSampleFrame, resolution: DMXResolution) -> [UInt8] {
        switch resolution {
        case .eightBit:  return dmxChannels(for: f)
        case .sixteenBit: return dmxChannels16(for: f)
        }
    }

    /// Builds one ArtDMX packet. `channels` is padded to an even length in
    /// [2, 512] as the spec requires.
    public static func artDMXPacket(universe: Int, sequence: UInt8, channels: [UInt8]) -> Data {
        var dmx = channels
        if dmx.count < 2 { dmx += Array(repeating: 0, count: 2 - dmx.count) }
        if dmx.count > 512 { dmx = Array(dmx.prefix(512)) }
        if dmx.count % 2 != 0 { dmx.append(0) }          // length must be even
        let length = dmx.count
        let uni = max(0, universe)

        var data = Data()
        data.append(contentsOf: Array("Art-Net".utf8))   // 7 bytes
        data.append(0)                                    // null terminator → 8
        data.append(contentsOf: [0x00, 0x50])             // OpCode OpOutput/ArtDMX (0x5000), little-endian
        data.append(contentsOf: [0x00, 0x0E])             // ProtVer 14, big-endian
        data.append(sequence)                             // Sequence
        data.append(0x00)                                 // Physical
        data.append(UInt8(uni & 0xFF))                    // SubUni (low byte)
        data.append(UInt8((uni >> 8) & 0x7F))             // Net (high 7 bits)
        data.append(UInt8((length >> 8) & 0xFF))          // LengthHi
        data.append(UInt8(length & 0xFF))                 // LengthLo
        data.append(contentsOf: dmx)                      // DMX data
        return data
    }

    /// The dimmer (luminance) unit value a frame maps to — must match the
    /// `dmxChannels*` builders (0.3 + 0.7·coherence). Exposed for the slew path
    /// and tests.
    static func dimmerUnit(for f: BioSampleFrame) -> Float { clampUnit(0.3 + 0.7 * f.coherence) }

    /// L1 master law, shared by Art-Net and sACN: Blackout wins (dimmer 0,
    /// whatever the master says), otherwise the Grand Master scales the dimmer
    /// linearly. Guards non-finite input; everything clamps to [0…1].
    public static func masteredDimmer(_ dimmer: Float, grandMaster: Float, blackout: Bool) -> Float {
        guard !blackout else { return 0 }
        let gm = clampUnit(grandMaster.isFinite ? grandMaster : 1)
        return clampUnit(dimmer) * gm
    }

    /// Overwrites the dimmer channel(s) of an already-built DMX array with a
    /// (slew-limited) value. ch0 for 8-bit; ch0..1 (coarse/fine) for 16-bit.
    /// Leaves the colour channels (R/G/B) untouched.
    static func applyDimmer(_ channels: inout [UInt8], resolution: DMXResolution, dimmer: Float) {
        switch resolution {
        case .eightBit:
            guard channels.count >= 1 else { return }
            channels[0] = byte(dimmer)
        case .sixteenBit:
            guard channels.count >= 2 else { return }
            let w = word(dimmer)
            channels[0] = w[0]
            channels[1] = w[1]
        }
    }

    /// Overwrites the COLOUR (R/G/B) channels of an already-built DMX array with
    /// slew-RATE-limited values, closing the colour half of the flash gap. The
    /// dimmer alone was slewed before, so at a high dimmer a hard colour jump (e.g.
    /// red→cyan on a chord change, recomputed ~30 Hz) was an un-limited luminance
    /// swing (W3C 2.3.1 / Law 6). Each colour channel rides the SAME cap as the
    /// dimmer, which bounds a FULL swing to ~1.2 Hz (a large strobe is
    /// impossible). Since #372 `maxDelta` is PASSED IN rather than defaulted here:
    /// this function is shared (`SACNSender` calls it), so a cap baked in locally
    /// would be a second, invisible copy of the number the caller's loop interval
    /// determines. The default keeps the two existing test call sites honest at the
    /// shipped interval. Honest caveat (inherited from the shared slew primitive, not
    /// new here): a rate cap bounds ≤3 Hz only for flashes of amplitude ≳0.4 — a
    /// tiny-amplitude (0.1–0.2) reversal every 2–3 ticks could still exceed 3 Hz.
    /// That is unreachable with our sources (bio is sub-Hz; music colour changes
    /// per chord/beat, never at 6–12 Hz), so it is a documented residual, not a
    /// live risk; a hard per-amplitude cap would need a flash-FREQUENCY counter
    /// (Council note, out of scope). `last` is the per-channel anchor (R,G,B in
    /// 0…1, -1 = no history yet — the first tick snaps, then ramps), updated in
    /// place; reset it (to []) on stop so a restart doesn't ramp from a stale hue.
    /// The dimmer channel is left untouched (applyDimmer owns it). Shared by both
    /// ArtNet and sACN so both protocols get the identical flash-safe guarantee.
    static func applySlewedColour(_ channels: inout [UInt8], resolution: DMXResolution,
                                  last: inout [Float],
                                  maxDelta: Double = FlashGuard.senderTickDelta) {
        if last.count != 3 { last = [-1, -1, -1] }
        let channelStride = resolution == .sixteenBit ? 2 : 1
        for c in 0..<3 {
            let idx = channelStride + c * channelStride   // ch0 = dimmer; R/G/B follow
            switch resolution {
            case .eightBit:
                guard idx < channels.count else { return }
                let target = Float(channels[idx]) / 255
                let slewed = FlashGuard.slewedDimmer(from: last[c], to: target, blackout: false,
                                                     maxDelta: maxDelta)
                last[c] = slewed
                channels[idx] = byte(slewed)
            case .sixteenBit:
                guard idx + 1 < channels.count else { return }
                let target = Float(UInt16(channels[idx]) << 8 | UInt16(channels[idx + 1])) / 65535
                let slewed = FlashGuard.slewedDimmer(from: last[c], to: target, blackout: false,
                                                     maxDelta: maxDelta)
                last[c] = slewed
                let w = word(slewed)
                channels[idx] = w[0]; channels[idx + 1] = w[1]
            }
        }
    }

    /// Re-encode a held DMX byte array between the two resolutions, so a
    /// mid-hold resolution change cannot leave `sendIfFresh` reading a stride the
    /// array does not have. Pure and shared by both protocols — `SACNSender` holds
    /// the same kind of array and calls this too.
    ///
    /// 8-bit → 16-bit is EXACT and stays exact: `65535 / 255 == 257`, so a byte `b`
    /// becomes the word `b * 257`, i.e. coarse `b` + fine `b`, and converting back
    /// yields `b` again for all 256 values (verified for every byte, not sampled).
    /// 16-bit → 8-bit is lossy by construction — that IS what choosing 8-bit means.
    static func reencode(_ channels: [UInt8], from old: DMXResolution,
                         to new: DMXResolution) -> [UInt8] {
        guard old != new, !channels.isEmpty else { return channels }
        switch (old, new) {
        case (.sixteenBit, .eightBit):
            var out: [UInt8] = []
            out.reserveCapacity(channels.count / 2)
            var i = 0
            while i + 1 < channels.count {
                let v = UInt16(channels[i]) << 8 | UInt16(channels[i + 1])
                out.append(byte(Float(v) / 65535))
                i += 2
            }
            return out
        case (.eightBit, .sixteenBit):
            var out: [UInt8] = []
            out.reserveCapacity(channels.count * 2)
            for b in channels { out.append(contentsOf: word(Float(b) / 255)) }
            return out
        default:
            return channels
        }
    }

    // NaN-safe: a non-finite bio/music channel (NaN/Inf) would otherwise reach
    // UInt8(_ * 255) / UInt16(_ * 65535) below and TRAP the app. Map non-finite → 0.
    private static func clampUnit(_ x: Float) -> Float { Swift.min(Swift.max(x.isFinite ? x : 0, 0), 1) }
    private static func byte(_ unit: Float) -> UInt8 { UInt8(clampUnit(unit) * 255) }

    /// A unit value as a 16-bit coarse(MSB)+fine(LSB) DMX channel pair.
    private static func word(_ unit: Float) -> [UInt8] {
        let v = UInt16(clampUnit(unit) * 65535)
        return [UInt8(v >> 8), UInt8(v & 0xFF)]
    }
}
#endif
