//
//  LightSendAccounting.swift
//  Echoelmusic — EchoelSync / EchoelLux
//
//  The delivery bookkeeping of ONE light packet, and the ONE rule that decides
//  whether a send outcome may commit it (#416: one definition per decision, the
//  same split `ArtNetSender.DMXResolution` and `masteredDimmer` already use —
//  both light senders share the LAW, each keeps its own state).
//
//  ⛔ WHY THIS TYPE EXISTS. Both senders used to advance their "lastSent…" anchors
//  in the tick, BEFORE the packet reached `NWConnection`, and `send` began with
//  `guard let conn = connection else { return }`. So with no socket the tick
//  CONSUMED the very facts that make a retry happen: `lookMoved`, `masterMoved`,
//  the source-freshness compare and the keep-alive clock all fell back to "already
//  sent" for a packet that never existed. Pull the network cable, move the look or
//  hit Blackout, plug back in — nothing was re-sent, because from the sender's
//  point of view it already had been. Found by independent review of the lighting
//  ownership seam (2026-09-22).
//
//  ⚠️ THE CONTRACT THIS TYPE ENCODES IS LOCAL ACCEPTANCE, NOT DELIVERY.
//  `NWConnection.send(completion: .contentProcessed)` reports when the content has
//  been passed to the network stack, or why it could not be. On UDP there is no
//  receiver acknowledgement at any layer this app can see, so the strongest honest
//  statement is "the stack took it without reporting an error". Never write, and
//  never let a label imply, that a fixture received anything.
//
//  ⚠️ AND IT IS NOT A TRANSPORT FRAMEWORK. Two fields of mechanism — a generation
//  counter and a comparison — because UDP sends can complete out of order and a
//  LATE completion of an OLDER packet must not roll delivery state backward onto
//  a newer one that already committed. Nothing is queued; each attempt carries its
//  own bookkeeping in the completion closure, so there is no pending-send
//  structure to grow.
//

import Foundation

/// What one send attempt would commit to its sender's delivery anchors, if the network
/// stack accepts it. Pure value type — no socket, no actor, fully drivable in a test.
///
/// Every field is a DELIVERY/DEDUP anchor. Render/slew state (`lastDimmer`, `lastColour`)
/// is deliberately NOT here: that advances when a packet is COMPUTED, because it is this
/// app's own deterministic ramp and the next tick's step is measured from it. Mixing the
/// two categories in one place is exactly how the defect above was written.
public struct LightSendAttempt: Sendable, Equatable {

    /// Monotonic per sender, incremented once per attempted packet. The ONLY purpose is
    /// ordering: a completion may commit only if its generation is newer than what is
    /// already committed. It is NOT the protocol sequence number (Art-Net and sACN each
    /// have their own, advanced per packet CONSTRUCTED) and must never be used as one —
    /// a wire sequence proves nothing about delivery, and this proves nothing about the wire.
    public let generation: UInt64

    /// The source frame timestamp this packet carried. Committed on success so the next
    /// tick's `sourceTimestamp != lastFrameTimestamp` compare is about what was SENT, not
    /// about what was merely computed.
    public let frameTimestamp: TimeInterval

    /// Operator state as of this packet.
    public let grandMaster: Float
    public let blackout: Bool

    /// Creative state as of this packet (founder decision 2026-09-22). Sits beside the
    /// operator anchors; it is not one of them.
    public let lookIntensity: Float

    /// `CFAbsoluteTimeGetCurrent()` at the moment the packet was handed over — captured at
    /// ATTEMPT time and committed on success, rather than read again in the completion.
    /// The keep-alive question is "how long since a packet got out", and the handover is
    /// when it got out; the completion's own clock is later by an amount that has nothing
    /// to do with the receiver's timeout.
    public let sentAt: TimeInterval

    public init(generation: UInt64,
                frameTimestamp: TimeInterval,
                grandMaster: Float,
                blackout: Bool,
                lookIntensity: Float,
                sentAt: TimeInterval) {
        self.generation = generation
        self.frameTimestamp = frameTimestamp
        self.grandMaster = grandMaster
        self.blackout = blackout
        self.lookIntensity = lookIntensity
        self.sentAt = sentAt
    }
}

/// The one rule both light senders apply to a send outcome.
public enum LightSendAccounting {

    /// May this outcome commit its attempt's delivery anchors?
    ///
    /// Two independent reasons to refuse, and they are different failures:
    ///   · `failed` — the stack reported an error, so nothing left the device for this
    ///     packet. Committing would tell the next tick a retry is unnecessary.
    ///   · a stale generation — an OLDER packet completing after a NEWER one already
    ///     committed. Committing would roll delivery state backward and re-open a
    ///     resend of state that is already out.
    ///
    /// ⚠️ Strictly greater than, never `>=`: a generation is consumed by exactly one
    /// commit, and `>=` would let a duplicate completion of the same attempt re-stamp
    /// `sentAt`, quietly pushing the keep-alive deadline out on no new packet.
    public static func commits(_ attempt: LightSendAttempt,
                               over committedGeneration: UInt64,
                               failed: Bool) -> Bool {
        guard !failed else { return false }
        return attempt.generation > committedGeneration
    }
}
