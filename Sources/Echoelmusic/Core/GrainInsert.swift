// GrainInsert.swift
// Echoel — GMMW GA-10a: Echoel Grain as an insert on a track's `DeviceChain`, the MODEL only.
//
// ⭐ OFF UNTIL CHOSEN. No chain carries a grain insert unless a writer put one there, and a chain
// without one answers `soundingGrain == nil` — so every song written before GA-10 plays exactly as
// before. GA-10b bakes the sound off the render thread and GA-10c plays it; this slice decides
// nothing about audio and has no caller in the app yet.
//
// ⭐ THE SAME LAWS AS THE CHARACTER INSERT (`DeviceChain.swift` header), because a second set of
// rules for a second insert type would be a second truth:
// · an insert of any OTHER type, above all one this build cannot read, is kept in place, verbatim;
// · ONE grain insert per chain — a second would be a claim the player does not keep;
// · a grain insert of a LATER `typeVersion` is not read with this build's meaning, and choosing
//   settings over it replaces its state AND its version together;
// · a chain left with nothing stores no chain at all.
//
// ⚠️ The state is the settings as sorted-key JSON. Every field decodes IF PRESENT with its default,
// so a v1 state written by a later build that ADDS a field still reads here; a field that changes
// meaning is v2, and v2 is not read.

import Foundation

/// The six knobs of `GrainCloud` plus the insert's own two: how much of the cloud is heard, and the
/// seed that gives a track its own grain pattern. Values are kept as written and clamped on use,
/// so a song never loses what was stored, and nothing out of range ever reaches the kernel.
public struct GrainSettings: Codable, Sendable, Equatable {
    /// Where in the part's audio the grains read, 0 (start) … 1 (end).
    public var position: Float = 0
    /// Grain length in milliseconds, 10 … 500.
    public var grainMilliseconds: Float = 80
    /// 0 … 1 → overlap 0.5 … 3.5 grains (`GrainCloud.density`).
    public var density: Float = 0.5
    /// How far around `position` a grain may start, in seconds, 0 … 0.5.
    public var spraySeconds: Float = 0.05
    /// Grain transposition in semitones, −24 … +24.
    public var pitchSemitones: Float = 0
    /// 0 = every grain centred, 1 = grains scattered hard left and right.
    public var stereoSpread: Float = 0.5
    /// 0 = only the dry part, 1 = only the cloud.
    public var mix: Float = 1
    /// The grain pattern. Two tracks with equal settings and equal seeds play the same pattern
    /// (`GrainCloud` header). ⚠️ Nothing here assigns one: `DeviceInsert.grain` and `settingGrain`
    /// store the seed they are handed, default 0. The writer that first places a grain on a track
    /// (GA-10d, the UI) chooses a per-track seed — until then every grain shares one pattern.
    public var seed: UInt64 = 0

    public init() {}

    /// Ranges, stated once for the model — the kernel's own, plus `mix`. ⚠️ `GrainCloud` clamps
    /// the same six again on every use (`DSP/` cannot read a `Core/` type), so a drift between the
    /// two can narrow a value, never let an unsafe one through.
    public enum Limits {
        public static let position: ClosedRange<Float> = 0...1
        public static let grainMilliseconds: ClosedRange<Float> = 10...500
        public static let density: ClosedRange<Float> = 0...1
        public static let spraySeconds: ClosedRange<Float> = 0...0.5
        public static let pitchSemitones: ClosedRange<Float> = -24...24
        public static let stereoSpread: ClosedRange<Float> = 0...1
        public static let mix: ClosedRange<Float> = 0...1
    }

    /// Every value inside its range; a non-finite value becomes the default.
    public var sanitized: GrainSettings {
        let d = GrainSettings()
        var s = self
        s.position = Self.bounded(position, Limits.position, d.position)
        s.grainMilliseconds = Self.bounded(grainMilliseconds, Limits.grainMilliseconds, d.grainMilliseconds)
        s.density = Self.bounded(density, Limits.density, d.density)
        s.spraySeconds = Self.bounded(spraySeconds, Limits.spraySeconds, d.spraySeconds)
        s.pitchSemitones = Self.bounded(pitchSemitones, Limits.pitchSemitones, d.pitchSemitones)
        s.stereoSpread = Self.bounded(stereoSpread, Limits.stereoSpread, d.stereoSpread)
        s.mix = Self.bounded(mix, Limits.mix, d.mix)
        return s
    }

    private static func bounded(_ value: Float, _ range: ClosedRange<Float>, _ fallback: Float) -> Float {
        value.isFinite ? min(max(value, range.lowerBound), range.upperBound) : fallback
    }

    private enum CodingKeys: String, CodingKey {
        case position, grainMilliseconds, density, spraySeconds, pitchSemitones, stereoSpread, mix, seed
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let d = GrainSettings()
        position = (try? c.decodeIfPresent(Float.self, forKey: .position)) ?? d.position
        grainMilliseconds = (try? c.decodeIfPresent(Float.self, forKey: .grainMilliseconds)) ?? d.grainMilliseconds
        density = (try? c.decodeIfPresent(Float.self, forKey: .density)) ?? d.density
        spraySeconds = (try? c.decodeIfPresent(Float.self, forKey: .spraySeconds)) ?? d.spraySeconds
        pitchSemitones = (try? c.decodeIfPresent(Float.self, forKey: .pitchSemitones)) ?? d.pitchSemitones
        stereoSpread = (try? c.decodeIfPresent(Float.self, forKey: .stereoSpread)) ?? d.stereoSpread
        mix = (try? c.decodeIfPresent(Float.self, forKey: .mix)) ?? d.mix
        seed = (try? c.decodeIfPresent(UInt64.self, forKey: .seed)) ?? d.seed
    }
}

extension DeviceInsert {
    /// Echoel Grain (GA-9 kernel) as an insert.
    public static let grainTypeID = "com.echoelmusic.device.fx.grain"
    /// The state format this build reads and writes: `GrainSettings` as sorted-key JSON.
    public static let grainTypeVersion = 1

    /// A fresh, enabled grain insert carrying these settings, sanitised BEFORE encoding: JSON has
    /// no NaN, so an unsanitised non-finite value would encode to an empty, unreadable state.
    public static func grain(_ settings: GrainSettings) -> DeviceInsert {
        DeviceInsert(typeID: grainTypeID, typeVersion: grainTypeVersion, isEnabled: true,
                     stateBlob: grainBlob(settings.sanitized))
    }

    /// The settings this insert holds, sanitised — or nil when it is not a grain insert, its state is
    /// a LATER format, or its state does not decode.
    public var grainSettings: GrainSettings? {
        guard typeID == Self.grainTypeID, typeVersion <= Self.grainTypeVersion,
              let settings = try? JSONDecoder().decode(GrainSettings.self, from: stateBlob) else { return nil }
        return settings.sanitized
    }

    /// Sorted keys, so one setting has one byte form and "unchanged" is an equality.
    static func grainBlob(_ settings: GrainSettings) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(settings)) ?? Data()
    }
}

extension DeviceChain {
    /// The grain the track plays through, or nil for none: the first ENABLED grain insert this
    /// build can read.
    public var soundingGrain: GrainSettings? {
        for insert in inserts where insert.isEnabled && insert.typeID == DeviceInsert.grainTypeID {
            if let settings = insert.grainSettings { return settings }
        }
        return nil
    }

    /// This chain with its grain set to `settings` (nil = none) — the twin of `settingCharacter`.
    /// Inserts of any other type are kept, in place, untouched; an existing grain insert keeps its
    /// identity and is enabled; a second grain insert is dropped; the instrument is never touched.
    /// Nil when nothing is left, so the lane stores no chain.
    public func settingGrain(_ settings: GrainSettings?) -> DeviceChain? {
        var result = inserts
        let firstGrain = result.firstIndex { $0.typeID == DeviceInsert.grainTypeID }
        result = result.enumerated().compactMap { index, insert in
            insert.typeID == DeviceInsert.grainTypeID && index != firstGrain ? nil : insert
        }
        if let settings {
            let blob = DeviceInsert.grainBlob(settings.sanitized)
            if let index = result.firstIndex(where: { $0.typeID == DeviceInsert.grainTypeID }) {
                result[index].isEnabled = true
                result[index].typeVersion = DeviceInsert.grainTypeVersion
                result[index].stateBlob = blob
            } else {
                result.append(DeviceInsert.grain(settings))
            }
        } else {
            result.removeAll { $0.typeID == DeviceInsert.grainTypeID }
        }
        var next = self
        next.inserts = result
        return next.isEmpty ? nil : next
    }
}
