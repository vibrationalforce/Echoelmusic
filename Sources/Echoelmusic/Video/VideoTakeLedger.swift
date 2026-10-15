// VideoTakeLedger.swift
// Echoel — One World C1/M1. The bookkeeping of ONE camera take, as a pure value: which files the
// take owns, which have answered, who waits for the result, and who receives it. `VideoTakeCamera`
// holds one ledger under its lock and does nothing but call it and carry out what it answers —
// so the decisions run in a test without a camera (review 2026-10-15, ChatGPT/Astra B1/B4).
//
// ⭐ THE RESULT IS DECIDED AND HANDED OVER IN ONE STEP. The last file's answer completes the take
// AND picks the receiver in the same call, under the same lock. There is no moment in which the
// take looks finished but its result is still unclaimed — the gap in which a Stop used to read
// "nothing pending" and answer with a failure while the real files went to nobody (B1).
//
// ⭐ EXACTLY ONE RECEIVER PER TAKE. The first Stop that waits receives the files; any later Stop
// for the same take receives `.handedOver` — a defined answer that lands nothing. A take that ended
// on its own (an interruption, a full disk) keeps its result until a Stop claims it, and a new
// take cannot start while such a result is unclaimed, so no result is ever overwritten.
//
// ⭐ A STOP BEFORE THE CAMERA CONFIRMED IS REMEMBERED (B4). `stopRequested` stays set for the take,
// so an output whose recording starts after the Stop is stopped the moment it starts.

import Foundation

struct VideoTakeLedger: Sendable {

    /// What one take wrote, per lens. Either may be nil (a lens that failed, or the front lens of
    /// a single-lens take); never both — a take with no file is `.nothingRecorded`.
    struct Files: Equatable, Sendable {
        let rear: URL?
        let front: URL?
    }

    /// The answer a Stop receives.
    enum Outcome: Equatable, Sendable {
        /// The files of the take — handed to exactly one receiver.
        case taken(Files)
        /// The take wrote no usable file, or there was no take.
        case nothingRecorded
        /// Another Stop for the same take received its files; this one lands nothing.
        case handedOver
    }

    /// What `requestStop` asks the caller to do.
    enum StopStep: Equatable, Sendable {
        /// Answer at once.
        case answer(Outcome)
        /// Wait under this ticket; `fileFinished` names it when the take completes.
        case wait(ticket: Int)
    }

    private(set) var pendingRear: URL?
    private(set) var pendingFront: URL?
    private var writtenRear: URL?
    private var writtenFront: URL?
    /// A finished take's result that no Stop has claimed yet.
    private(set) var unclaimed: Outcome?
    /// Tickets of the Stops waiting for the take in flight, oldest first.
    private(set) var waiting: [Int] = []
    private var nextTicket = 0
    /// A Stop arrived for the take in flight — an output that starts after it is stopped at once.
    private(set) var stopRequested = false

    /// Whether a take's files are still owed (recording, or finalising after Stop).
    var takeInFlight: Bool { pendingRear != nil || pendingFront != nil }

    /// Start a take that owns `rear` (and `front`). Refused while a take is in flight or a finished
    /// take's result is still unclaimed — the old result is never overwritten.
    mutating func begin(rear: URL, front: URL?) -> Bool {
        guard !takeInFlight, unclaimed == nil else { return false }
        pendingRear = rear
        pendingFront = front
        writtenRear = nil
        writtenFront = nil
        waiting = []
        stopRequested = false
        return true
    }

    /// A Stop arrives: claim a finished result, wait for the take in flight, or learn that there
    /// is nothing to wait for.
    mutating func requestStop() -> StopStep {
        if let result = unclaimed {
            unclaimed = nil
            return .answer(result)
        }
        guard takeInFlight else { return .answer(.nothingRecorded) }
        stopRequested = true
        nextTicket += 1
        waiting.append(nextTicket)
        return .wait(ticket: nextTicket)
    }

    /// One output finished writing `url`. Answers whether the URL belonged to this take, and — when
    /// it was the last one owed — every waiting ticket with its answer: the first receives the
    /// files, the rest `.handedOver`. With no one waiting the result is kept for the next Stop.
    mutating func fileFinished(_ url: URL, written: Bool) -> (owned: Bool, deliveries: [(ticket: Int, outcome: Outcome)]) {
        let isRear = pendingRear != nil && url == pendingRear
        let isFront = pendingFront != nil && url == pendingFront
        guard isRear || isFront else { return (false, []) }
        if isRear {
            pendingRear = nil
            if written { writtenRear = url }
        } else {
            pendingFront = nil
            if written { writtenFront = url }
        }
        guard !takeInFlight else { return (true, []) }
        let files = Files(rear: writtenRear, front: writtenFront)
        let result: Outcome = files.rear == nil && files.front == nil ? .nothingRecorded : .taken(files)
        stopRequested = false
        guard let first = waiting.first else {
            unclaimed = result
            return (true, [])
        }
        let rest = waiting.dropFirst().map { (ticket: $0, outcome: Outcome.handedOver) }
        waiting = []
        return (true, [(ticket: first, outcome: result)] + rest)
    }
}
