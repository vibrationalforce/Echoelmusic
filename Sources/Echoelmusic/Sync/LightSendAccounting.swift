//
//  LightSendAccounting.swift
//  Echoelmusic — EchoelSync / EchoelLux
//
//  The EXECUTION MODEL of one light output: what may be put on the wire right now,
//  what a send outcome is allowed to commit, and the bound on how much may be
//  outstanding at once. Both light senders share the LAW here and each keeps its own
//  instance (#416: one definition per decision, the same split
//  `ArtNetSender.DMXResolution` and `masteredDimmer` already use).
//
//  ⛔ WHY THIS TYPE EXISTS — TWO ROUNDS OF THE SAME DEFECT, both found by independent
//  review of the lighting ownership seam (2026-09-22).
//
//  ROUND ONE (#1445). Both senders advanced their "lastSent…" anchors in the tick,
//  BEFORE the packet reached `NWConnection`, and `send` began with
//  `guard let conn = connection else { return }`. With no socket the tick CONSUMED the
//  very facts that make a retry happen: `lookMoved`, `masterMoved`, the source-freshness
//  compare and the keep-alive clock all fell back to "already sent" for a packet that
//  never existed.
//
//  ROUND TWO (#1446) — the half round one left standing, and it is the SAFETY half.
//  The fade itself still advanced on COMPUTE: `lastDimmer = limited` and the in-place
//  `lastColour` ran every tick whether or not anything left the device. Pull the cable at
//  dark, command full, wait a second, plug back in — the sender had internally finished
//  the ramp, so the first packet the receiver saw carried the FINAL value. A jump from 0
//  to 1 in one DMX frame, out of a slew-limiter written to make exactly that impossible.
//  Nothing bounded outstanding sends either, and a replaced connection kept committing
//  into the new one's bookkeeping.
//
//  ⚠️ THE CONTRACT THIS TYPE ENCODES IS LOCAL PROCESSING, NOT DELIVERY.
//  `NWConnection.send(completion: .contentProcessed)` calls back when the connection has
//  finished processing the content, or with the error that stopped it. That is NOT "the
//  NIC transmitted it", NOT "the packet left the device", and certainly NOT "a fixture
//  received it" — UDP carries no acknowledgement at any layer this app can see. The
//  strongest honest sentence is: the completion reported no local error. Never write, and
//  never let a label imply, more than that.
//
//  ⚠️ AND IT IS NOT A TRANSPORT FRAMEWORK. It is a value type with a handful of scalars:
//  no queue, no pending-send collection, no closure accumulation, no protocol abstraction,
//  no knowledge of sockets, DMX, universes or fixtures. It cannot grow with traffic,
//  because the bound below is ONE outstanding ordinary data send and a tick that finds one
//  outstanding builds nothing at all.
//

import Foundation

/// What one send attempt would commit to its sender's anchors, if the completion reports
/// no local error. Pure value type — no socket, no actor, fully drivable in a test.
public struct LightSendAttempt: Sendable, Equatable {

    /// Which CONNECTION LIFETIME this attempt belongs to. A completion whose epoch is no
    /// longer the pump's is from a socket that has since been replaced or stopped, and it
    /// must not commit into the current one's bookkeeping — otherwise a late success on the
    /// OLD endpoint tells the NEW endpoint that its state is already out, and the operator
    /// who just corrected the host IP sees nothing arrive until the keep-alive.
    public let epoch: UInt64

    /// Monotonic per sender, incremented once per attempted packet. The ONLY purpose is
    /// ordering: a completion may commit only if its generation is newer than what is
    /// already committed. It is NOT the protocol sequence number (Art-Net and sACN each
    /// have their own, advanced per packet CONSTRUCTED) and must never be used as one —
    /// a wire sequence proves nothing about delivery, and this proves nothing about the wire.
    public let generation: UInt64

    /// The source frame timestamp this packet carried. Committed on success so the next
    /// tick's freshness compare is about what was SENT, not about what was merely computed.
    public let frameTimestamp: TimeInterval

    /// Operator state as of this packet.
    public let grandMaster: Float
    public let blackout: Bool

    /// Creative state as of this packet (founder decision 2026-09-22). Sits beside the
    /// operator anchors; it is not one of them.
    public let lookIntensity: Float

    /// `CFAbsoluteTimeGetCurrent()` read in the tick, at the moment this packet was handed
    /// to `NWConnection.send` — SUBMISSION time, not completion time, and the difference is
    /// written down because the previous wording called it "acceptance time" and that was
    /// simply the wrong clock. It is committed only if the completion later reports no
    /// error, so the value a sender exposes means: *the submission time of the most recent
    /// attempt whose local processing then finished without an error*. The keep-alive
    /// question is "how long since we handed something over", which is this clock.
    public let sentAt: TimeInterval

    /// THE OUTPUT this packet carried, and the reason round two exists. The dimmer and the
    /// three colour channels are committed on success and are the anchor the NEXT packet's
    /// slew step is measured from, so a fade can only progress as far as the network has
    /// actually taken it.
    public let dimmer: Float
    /// R, G, B in 0…1 — empty only if the sender had no colour history when it submitted.
    public let colour: [Float]

    public init(epoch: UInt64,
                generation: UInt64,
                frameTimestamp: TimeInterval,
                grandMaster: Float,
                blackout: Bool,
                lookIntensity: Float,
                sentAt: TimeInterval,
                dimmer: Float,
                colour: [Float]) {
        self.epoch = epoch
        self.generation = generation
        self.frameTimestamp = frameTimestamp
        self.grandMaster = grandMaster
        self.blackout = blackout
        self.lookIntensity = lookIntensity
        self.sentAt = sentAt
        self.dimmer = dimmer
        self.colour = colour
    }
}

/// The one rule both light senders apply to a send outcome.
public enum LightSendAccounting {

    /// May this outcome commit its attempt's anchors?
    ///
    /// Three independent reasons to refuse, and they are different failures:
    ///   · `failed` — the completion reported an error, so nothing was processed for this
    ///     packet. Committing would tell the next tick a retry is unnecessary.
    ///   · a stale EPOCH — the connection this attempt was submitted on has been replaced
    ///     or stopped. Its outcome says nothing about the socket that exists now.
    ///   · a stale GENERATION — an OLDER packet completing after a NEWER one already
    ///     committed. Committing would roll state backward and re-open a resend of state
    ///     that is already out.
    ///
    /// ⚠️ Strictly greater than, never `>=`: a generation is consumed by exactly one
    /// commit, and `>=` would let a duplicate completion of the same attempt re-stamp
    /// `sentAt`, quietly pushing the keep-alive deadline out on no new packet.
    public static func commits(_ attempt: LightSendAttempt,
                               over committedGeneration: UInt64,
                               epoch: UInt64,
                               failed: Bool) -> Bool {
        guard !failed else { return false }
        guard attempt.epoch == epoch else { return false }
        return attempt.generation > committedGeneration
    }
}

/// The per-sender execution state: the bound, the epoch, and the two kinds of anchor.
///
/// ⭐ TWO CATEGORIES, NEVER MIXED — the distinction round two was written to restore:
///   · **ACCEPTED OUTPUT** (`acceptedDimmer`, `acceptedColour`) — what the network last
///     took. The slew-limiter measures its next step from here, so an outage freezes the
///     ramp at the last value a receiver could plausibly hold, and recovery continues from
///     there instead of jumping.
///   · **ACCEPTED DELIVERY / DEDUP** (`acceptedFrameTimestamp`, `acceptedGrandMaster`,
///     `acceptedBlackout`, `acceptedLookIntensity`, `acceptedSentAt`) — what the next tick
///     compares against when deciding whether there is anything to send at all.
/// There is deliberately NO third "computed" anchor. A variable that sometimes means
/// computed and sometimes means accepted is how round two shipped; one meaning each.
///
/// ⭐ WHAT IS NOT HERE, ON PURPOSE: generation of the music, the bio frame, the colour
/// mapping, the DMX bytes. Output progression is acceptance-relative; GENERATION is not.
/// The composition keeps running at full rate whatever the network does.
public struct LightSendPump {

    // MARK: - Transport

    /// Connection lifetime. Bumped by `openEpoch()` (a new socket) and `retire()` (stop).
    /// Not persisted, not a wire value, never sent anywhere.
    public private(set) var epoch: UInt64 = 0
    /// Attempted packets, monotonic for the life of the sender — never reset, so a stop and
    /// restart cannot reissue a number an outstanding completion is still carrying.
    public private(set) var generation: UInt64 = 0
    /// The newest generation whose completion committed. Raised to `generation` whenever an
    /// epoch closes, which retires every attempt outstanding at that moment.
    public private(set) var committedGeneration: UInt64 = 0
    /// The generation of the ONE ordinary data send currently outstanding, or nil.
    ///
    /// ⭐ MAX_IN_FLIGHT = 1, and it is a structural bound rather than a limit that is
    /// checked: there is one optional slot, and `submit` is the only writer that fills it.
    /// A tick that finds it full returns before building a packet, so nothing accumulates —
    /// no array, no closure chain, no sequence numbers burned.
    ///
    /// ⚠️ THE RESIDUAL, STATED RATHER THAN HIDDEN: if a completion never arrives (a
    /// connection parked in `.waiting` with no route), this stays full and the sender is
    /// quiet until the epoch closes. That is not a queue's problem solved differently —
    /// a transport that cannot process anything cannot carry a blackout either, and a
    /// backlog would deliver STALE pre-blackout packets first on recovery. The escapes are
    /// the operator's: changing host/port/universe reconnects, and stopping retires.
    public private(set) var inFlight: UInt64?
    /// Set when an epoch opens; cleared by the first commit on that epoch. It makes the
    /// current state eligible immediately after a connect or a restart, even when every
    /// other reason says "unchanged" — the defect where a quick stop/start went silent
    /// until the keep-alive deadline, which for sACN follows a Stream_Terminated the
    /// receiver has already acted on.
    public private(set) var needsResend = false

    // MARK: - Accepted OUTPUT (the safety anchors)

    /// The dimmer of the last packet whose completion reported no error. -1 = none yet,
    /// which makes the first packet snap rather than ramp from black.
    public private(set) var acceptedDimmer: Float = -1
    /// R, G, B of the last such packet. Empty = none yet.
    public private(set) var acceptedColour: [Float] = []

    // MARK: - Accepted DELIVERY / DEDUP

    public private(set) var acceptedFrameTimestamp: TimeInterval = -1
    public private(set) var acceptedGrandMaster: Float = 1
    /// ⚠️ EXPLICIT TYPE, not inference: an inferred declaration spells `acceptedBlackout =`,
    /// which is the same text as an ASSIGNMENT — and the guard that proves each anchor has
    /// exactly one writer counts that text. Type it, or the declaration hides a second writer.
    public private(set) var acceptedBlackout: Bool = false
    public private(set) var acceptedLookIntensity: Float = LightingStore.defaultLookIntensity
    public private(set) var acceptedSentAt: TimeInterval = 0

    public init() {}

    /// True while the one outstanding ordinary data send has not completed.
    public var isBusy: Bool { inFlight != nil }

    /// Is the keep-alive due? Asked here rather than spelled out in each sender so the two
    /// light outputs cannot drift into two readings of the same clock (#416). Never true
    /// before anything has ever been accepted — an idle sender must not stream.
    public func keepAliveDue(now: TimeInterval, after seconds: TimeInterval) -> Bool {
        acceptedSentAt > 0 && now - acceptedSentAt >= seconds
    }

    /// A new connection exists: nothing outstanding on the old one may commit into it, and
    /// the current state must go out promptly on the new one.
    public mutating func openEpoch() {
        epoch &+= 1
        inFlight = nil
        committedGeneration = generation
        needsResend = true
    }

    /// The sender is stopping. Same retirement, plus the OUTPUT anchors reset: after a stop
    /// the receiver has been released (sACN says so explicitly with Stream_Terminated, an
    /// Art-Net node times out), so there is no established level on the far side to ramp
    /// from and the next session snaps to its first value exactly as a cold start does.
    public mutating func retire() {
        epoch &+= 1
        inFlight = nil
        committedGeneration = generation
        needsResend = false
        acceptedDimmer = -1
        acceptedColour = []
    }

    /// Take the one in-flight slot and describe the packet that is about to be handed over.
    /// Called only after the caller has decided to send AND found the slot free.
    public mutating func submit(frameTimestamp: TimeInterval,
                                grandMaster: Float,
                                blackout: Bool,
                                lookIntensity: Float,
                                sentAt: TimeInterval,
                                dimmer: Float,
                                colour: [Float]) -> LightSendAttempt {
        generation &+= 1
        inFlight = generation
        return LightSendAttempt(epoch: epoch,
                                generation: generation,
                                frameTimestamp: frameTimestamp,
                                grandMaster: grandMaster,
                                blackout: blackout,
                                lookIntensity: lookIntensity,
                                sentAt: sentAt,
                                dimmer: dimmer,
                                colour: colour)
    }

    /// The handover did not happen (no connection). Free the slot; commit nothing. Without
    /// this the bound would become a deadlock the first time the socket is gone.
    public mutating func abandon(_ attempt: LightSendAttempt) {
        if inFlight == attempt.generation { inFlight = nil }
    }

    /// The completion arrived. Frees the slot if this attempt still owns it, then applies
    /// the one shared rule.
    public mutating func complete(_ attempt: LightSendAttempt, failed: Bool) {
        if attempt.epoch == epoch, inFlight == attempt.generation { inFlight = nil }
        guard LightSendAccounting.commits(attempt, over: committedGeneration,
                                          epoch: epoch, failed: failed) else { return }
        committedGeneration = attempt.generation
        acceptedFrameTimestamp = attempt.frameTimestamp
        acceptedGrandMaster = attempt.grandMaster
        acceptedBlackout = attempt.blackout
        acceptedLookIntensity = attempt.lookIntensity
        acceptedSentAt = attempt.sentAt
        acceptedDimmer = attempt.dimmer
        acceptedColour = attempt.colour
        needsResend = false
    }
}
