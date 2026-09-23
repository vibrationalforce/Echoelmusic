// DetailedMeteringClaims.swift
// Echoel — S4a (founder 2026-09-23, "all tasks"): who may keep the EXPENSIVE mastering meters
// (true-peak oversampling + EBU R128) running on the output tap.
//
// ⭐ A SET OF OWNERS, NOT A BOOL AND NOT A COUNTER. Until S4a the gate was one `Bool` written
// by `MasterLoudnessGrid`'s appear/disappear, and its own note predicted the defect: two
// readers on screen at once, and the first to leave freezes the other's numbers. The scope's
// live peak is the second reader. A plain counter is the other wrong answer — a repeated
// `onAppear` (SwiftUI does that) unbalances it, and #299 is what an unbalanced refcount cost
// (`RecordRouteOwner` held the phone in `.playAndRecord`). The house pattern is an owner enum
// plus a `Set`: claiming twice is one claim, releasing without a claim is a no-op.
//
// Pure and Foundation-only; `AudioEngine` owns one of these on the main actor and writes the
// resulting Bool to the tap through the pointer it always used. Nothing here reaches the audio
// thread.

import Foundation

/// A surface that reads the expensive mastering meters while it is on screen.
enum DetailedMeteringOwner: Hashable, CaseIterable, Sendable {
    /// `MasterLoudnessGrid` — momentary/short-term/integrated LUFS, LRA, true-peak max.
    case masterPanel
    /// `ScopePeakLabel` — the live true peak under the oscilloscope.
    case scope
}

/// The set of surfaces currently holding the gate open.
struct DetailedMeteringClaims: Sendable, Equatable {
    private(set) var owners: Set<DetailedMeteringOwner> = []

    /// True while any owner holds a claim.
    var gateOpen: Bool { !owners.isEmpty }

    /// Add `owner`; returns whether the gate is open afterwards. Idempotent.
    @discardableResult
    mutating func claim(_ owner: DetailedMeteringOwner) -> Bool {
        owners.insert(owner)
        return gateOpen
    }

    /// Remove `owner`; returns whether the gate is open afterwards. Releasing an owner that
    /// holds no claim changes nothing.
    @discardableResult
    mutating func release(_ owner: DetailedMeteringOwner) -> Bool {
        owners.remove(owner)
        return gateOpen
    }
}
