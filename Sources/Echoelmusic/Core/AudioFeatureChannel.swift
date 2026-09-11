//  AudioFeatureChannel.swift
//  Echoel — the lock-protected leaf that carries input features to the picture (#1248).
//
//  THE SHAPE, AND WHY NOT THE BUS. `EngineBus` snapshots are `@MainActor @Observable`; a
//  feature written 15 times a second would either need a `Task { @MainActor }` per publish
//  (the #30/#951 executor flood, banned in `EngineBus.publish`) or invalidate an observable
//  every write. The picture already solves this three times — `TouchToneChannel`,
//  `TouchVisualEnergy`, `TouchRippleChannel` in `MetalBioView.swift`: an `NSLock`-guarded
//  value the producer writes and `draw(in:)` reads ONCE per frame, off the SwiftUI graph.
//  This is the fourth, for audio. Nothing observes it; nothing churns.
//
//  ONSET ENERGY decays here (~0.6 s) the way `TouchVisualEnergy` decays (~1.2 s), so the
//  renderer gets a swell-and-release, not a 15 Hz staircase — and it floors to the EXACT 0
//  that `AudioFeatureFrame` promises, for the #1244 skip.
//
//  STALENESS. A frame older than `maxAgeSeconds` reads as silent even if nobody called
//  `reset()` — monitoring can end through a route loss (#612) without passing the OFF ladder.

import Foundation

public final class AudioFeatureChannel: @unchecked Sendable {
    public static let shared = AudioFeatureChannel()

    public static let maxAgeSeconds: Double = 0.5
    /// Onset energy time constant.
    public static let onsetTauSeconds: Float = 0.6
    /// Energy below this is the exact 0 (#1244).
    public static let energyFloor: Float = 0.002

    public struct Snapshot: Sendable {
        public let frame: AudioFeatureFrame
        /// Decayed transient energy, 0…1, exact 0 at rest.
        public let onsetEnergy: Float
    }

    private let lock = NSLock()
    private var latest: AudioFeatureFrame = .silent(at: 0)
    private var energy: Float = 0
    private var lastRead: Double = 0

    public init() {}

    /// Producer side (the guard tick, MainActor). Zero actor hops, one lock.
    public func publish(_ frame: AudioFeatureFrame) {
        lock.lock()
        latest = frame
        energy = min(1, energy + max(0, frame.onset) * 0.6)
        lock.unlock()
    }

    /// Consumer side — once per rendered frame.
    public func snapshot(now: Double) -> Snapshot {
        lock.lock()
        defer { lock.unlock() }
        if lastRead == 0 { lastRead = now }
        let dt = Float(max(0, now - lastRead))
        lastRead = now
        energy = energy * exp(-dt / Self.onsetTauSeconds)
        if energy < Self.energyFloor { energy = 0 }
        let fresh = now - latest.timestamp <= Self.maxAgeSeconds
        let frame = fresh ? latest : .silent(at: latest.timestamp)
        if !fresh { energy = 0 }
        return Snapshot(frame: frame, onsetEnergy: energy)
    }

    /// Monitoring OFF / session stop: nothing lingers into the next take.
    public func reset() {
        lock.lock()
        latest = .silent(at: 0)
        energy = 0
        lastRead = 0
        lock.unlock()
    }
}
