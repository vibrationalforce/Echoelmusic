import Foundation

/// A stretch of an audio file on an audio track's timeline. The region starts at a musical
/// position and plays the file from `offset` for `length` frames. Without warp it plays at the
/// file's own speed, so a tempo change moves where it starts but never how it sounds; with warp
/// (`followsTempo` and a `nativeBPM`) it follows the song's tempo, its pitch unchanged.
///
/// Fades, gain and warp are optional fields added inside format 4 (AUD-2, 2026-11-04): absent,
/// the region plays as every earlier build played it, and an earlier build that meets them
/// ignores them and plays the region as before.
public struct AudioRegion: Codable, Equatable, Sendable, Identifiable {
    public var id: RegionID
    public var media: MediaID
    /// Timeline position in ticks.
    public var start: Tick
    /// First frame of the file that plays.
    public var offset: Int
    /// Frames played from `offset`; at least one, never past the end of the file.
    public var length: Int
    /// Frames of the file the region rises over from its start; nil is none.
    public var fadeIn: Int?
    /// Frames of the file the region falls over to its end; nil is none.
    public var fadeOut: Int?
    /// The stored curve names; nil — the key absent — is linear. A name this build does not
    /// know is kept and saved back unchanged and plays linear (the format's rule for names).
    private var fadeInCurveName: String?
    private var fadeOutCurveName: String?
    /// The region's own level in dB, before the track's fader; nil is 0 dB.
    public var gainDB: Double?
    /// The tempo the file was played at, in BPM: what warp stretches from. Kept while warp is off,
    /// so switching it back on finds it.
    public var nativeBPM: Double?
    /// The region follows the song's tempo (needs `nativeBPM`); nil is false.
    public var followsTempo: Bool?
    /// The bake that made the file it plays (W3, `RegionBaking`); nil for a region that plays its
    /// file as imported or recorded.
    public var bake: RegionBaking?
    /// A video part's colour correction (COLOR, `ColorGrade`); nil shows its file as it is. Only a
    /// video track's regions carry one.
    public var grade: ColorGrade?

    public static let gainRange: ClosedRange<Double> = -60...24
    public static let nativeBPMRange: ClosedRange<Double> = 20...999

    public init(id: RegionID = RegionID(), media: MediaID, start: Tick, offset: Int = 0, length: Int) {
        self.id = id
        self.media = media
        self.start = start
        self.offset = offset
        self.length = length
    }

    public var fadeInCurve: FadeCurve {
        get { fadeInCurveName.flatMap(FadeCurve.init(rawValue:)) ?? .linear }
        set { fadeInCurveName = newValue == .linear ? nil : newValue.rawValue }
    }

    public var fadeOutCurve: FadeCurve {
        get { fadeOutCurveName.flatMap(FadeCurve.init(rawValue:)) ?? .linear }
        set { fadeOutCurveName = newValue == .linear ? nil : newValue.rawValue }
    }

    /// The stored curve names this build does not know, kept and saved back unchanged.
    public var unrecognizedFadeCurves: [String] {
        [fadeInCurveName, fadeOutCurveName].compactMap { $0 }.filter { FadeCurve(rawValue: $0) == nil }
    }

    /// The fade lengths as they play inside the region: each held to 0…length, the fade-out to
    /// what the fade-in leaves ("in wins", the earlier app's one rule, `FadeEnvelope.effective`).
    public var effectiveFades: (fadeIn: Int, fadeOut: Int) {
        let rise = Swift.min(Swift.max(fadeIn ?? 0, 0), Swift.max(length, 0))
        let fall = Swift.min(Swift.max(fadeOut ?? 0, 0), Swift.max(length, 0) - rise)
        return (rise, fall)
    }

    /// The region's level as a factor: 1 at 0 dB, 0 for a gain that is not a number.
    public var linearGain: Double {
        guard let gainDB else { return 1 }
        guard gainDB.isFinite else { return 0 }
        return Foundation.pow(10, Swift.min(Swift.max(gainDB, Self.gainRange.lowerBound), Self.gainRange.upperBound) / 20)
    }

    /// The native tempo warp stretches from, when the region follows the song's tempo.
    public var warpBPM: Double? {
        guard followsTempo == true, let nativeBPM, nativeBPM.isFinite, Self.nativeBPMRange.contains(nativeBPM) else { return nil }
        return nativeBPM
    }

    private enum CodingKeys: String, CodingKey {
        case id, media, start, offset, length, fadeIn, fadeOut
        case fadeInCurveName = "fadeInCurve", fadeOutCurveName = "fadeOutCurve"
        case gainDB, nativeBPM, followsTempo, bake, grade
    }
}

/// How a region's fade moves between silence and full level. Stored by name; a new curve goes at
/// the end and into `StoredNamesTests`.
public enum FadeCurve: String, Codable, CaseIterable, Sendable {
    /// Level in proportion to time.
    case linear
    /// Sine-shaped: the level a crossfade of two equal-power fades keeps.
    case equalPower
    /// Starts slowly and ends steeply on the way in (the square of linear) — a soft entry.
    case exponential
    /// Slow at both ends, steepest in the middle (smoothstep).
    case sCurve

    /// The level 0…1 of a fade-in `progress` 0…1 through it; a fade-out reads it backwards.
    /// Every curve starts at 0 and ends at 1; a progress outside 0…1 or not a number is held.
    public func level(_ progress: Double) -> Double {
        let x = progress.isFinite ? Swift.min(Swift.max(progress, 0), 1) : 0
        switch self {
        case .linear: return x
        case .equalPower: return Foundation.sin(x * Double.pi / 2)
        case .exponential: return x * x
        case .sCurve: return x * x * (3 - 2 * x)
        }
    }
}

/// Where Follow Song Tempo starts from (W-1).
public enum WarpTempoSource: Equatable, Sendable {
    /// The native tempo the region already has — typed, or heard at import.
    case stored
    /// The tempo heard in the region's audio just now.
    case heard
    /// Nothing known: the song's tempo, so the region keeps its length until a tempo is set.
    case song
}

extension AudioRegion {
    /// A heard tempo as a native tempo: nil when there is none or it is outside `nativeBPMRange`.
    public static func nativeBPM(heard: Double?) -> Double? {
        guard let heard, heard.isFinite, nativeBPMRange.contains(heard) else { return nil }
        return heard
    }

    /// The native tempo Follow Song Tempo turns on with: the region's own when it has one (a
    /// detection never overrules a set tempo), else the heard one, else the song's at the region,
    /// held to `nativeBPMRange` (120 for a tempo that is not a number).
    public func warpStart(heard: Double?, songBPM: Double) -> (bpm: Double, source: WarpTempoSource) {
        if let nativeBPM, nativeBPM.isFinite, Self.nativeBPMRange.contains(nativeBPM) { return (nativeBPM, .stored) }
        if let bpm = Self.nativeBPM(heard: heard) { return (bpm, .heard) }
        guard songBPM.isFinite else { return (120, .song) }
        return (Swift.min(Swift.max(songBPM, Self.nativeBPMRange.lowerBound), Self.nativeBPMRange.upperBound), .song)
    }

    /// Whether the region has a native tempo warp can stretch from.
    public var hasNativeBPM: Bool {
        guard let nativeBPM else { return false }
        return nativeBPM.isFinite && Self.nativeBPMRange.contains(nativeBPM)
    }
}

extension Track {
    public func regionIndex(_ id: RegionID) -> Int? {
        regions.firstIndex { $0.id == id }
    }
}

extension Arranging {
    /// The commands that give region `copy` the fades, level and warp of `region` — none where it
    /// has none, so a plain region's duplicate is the two commands it always was.
    static func edits(of region: AudioRegion, onto copy: RegionID, in track: Track) -> [Command] {
        var commands: [Command] = []
        if region.fadeIn != nil || region.fadeOut != nil || region.fadeInCurve != .linear || region.fadeOutCurve != .linear {
            commands.append(.setRegionFades(track: track.id, copy, fadeIn: region.fadeIn ?? 0, fadeOut: region.fadeOut ?? 0,
                                            fadeInCurve: region.fadeInCurve, fadeOutCurve: region.fadeOutCurve))
        }
        if let gain = region.gainDB, gain != 0 { commands.append(.setRegionGain(track: track.id, copy, gainDB: gain)) }
        if let native = region.nativeBPM, native.isFinite, AudioRegion.nativeBPMRange.contains(native) {
            commands.append(.setRegionWarp(track: track.id, copy, nativeBPM: native, followsTempo: region.followsTempo == true))
        }
        return commands
    }
}

extension Project {
    /// Fractional file frames of `region` from its start to `tick` (negative before it): over the
    /// song's tempo map for a region at the file's own speed, over its native tempo for a warped one,
    /// whose file time is beats. Nil when the song no longer has its file.
    public func fileFrames(of region: AudioRegion, at tick: Tick) -> Double? {
        guard let file = mediaFile(region.media), file.sampleRate > 0, file.sampleRate.isFinite else { return nil }
        if let native = region.warpBPM {
            return Double(tick - region.start) / Double(MusicalTime.ticksPerQuarter) * 60 / native * file.sampleRate
        }
        let map = tempoMap
        return (map.seconds(at: tick) - map.seconds(at: region.start)) * file.sampleRate
    }

    /// The song position, in fractional ticks, where file frame `frames` after the region's
    /// `offset` sounds — the inverse of `fileFrames(of:at:)`.
    public func position(of region: AudioRegion, atFileFrames frames: Double) -> Double? {
        guard let file = mediaFile(region.media), file.sampleRate > 0, file.sampleRate.isFinite, frames.isFinite else { return nil }
        if let native = region.warpBPM {
            return Double(region.start) + frames / file.sampleRate * native / 60 * Double(MusicalTime.ticksPerQuarter)
        }
        let map = tempoMap
        return map.position(atSeconds: map.seconds(at: region.start) + frames / file.sampleRate)
    }
}
