import Foundation

/// The loudness an export is brought to (CUT, 2026-11-01): Off — the mix as it plays, as every
/// export was before — or one of three integrated-loudness targets a finished file is commonly
/// asked for: −14 LUFS (streaming and social platforms), −16 LUFS (podcasts) and −23 LUFS
/// (broadcast, EBU R 128). Every target keeps the true peak at or under −1 dBTP, so a lossy
/// encoding does not clip. The app renders, then brings the mix there offline
/// (`LoudnessNormalizer` in EchoelDSP) and says what the mix measured before and the file after.
///
/// And a fifth, the default since 2026-11-04: Peak −1 dBTP — the mix as it plays, lowered by a
/// plain gain only when its true peak lies above −1 dBTP, never raised, never limited. The Four
/// Tracks starter exported at +0.15 dBTP under Off, a peak a converter or an encoder clips.
///
/// A device setting, never stored in the song (no format field). The raw values are what the device
/// keeps between launches: keep them as they are.
public enum ExportLoudness: String, CaseIterable, Sendable {
    case off
    case minus14 = "-14"
    case minus16 = "-16"
    case minus23 = "-23"
    case peak = "peak"

    /// What an export does on a device where no one has chosen yet.
    public static let exportDefault = ExportLoudness.peak

    /// The true peak no target lets the file pass, in dBTP.
    public static let truePeakCeiling: Double = -1
    /// How close to its target, in LU, a file counts as brought there.
    public static let tolerance: Double = 0.5

    /// The integrated loudness the file is brought to, in LUFS; nil at Off.
    public var target: Double? {
        switch self {
        case .off: nil
        case .minus14: -14
        case .minus16: -16
        case .minus23: -23
        case .peak: nil
        }
    }

    /// Whether the export changes the mix at all; at Off it is copied as it plays.
    public var changesMix: Bool { self != .off }

    /// At Peak, the gain in dB that brings a mix measured at `truePeak` dBTP under the ceiling:
    /// 0 when it is there already or silent. Nil for every other choice.
    public func peakGain(forTruePeak truePeak: Double) -> Double? {
        guard self == .peak else { return nil }
        guard truePeak.isFinite, truePeak > Self.truePeakCeiling else { return 0 }
        return Self.truePeakCeiling - truePeak
    }

    public var title: String {
        switch self {
        case .off: "Off"
        case .minus14: "−14 LUFS"
        case .minus16: "−16 LUFS"
        case .minus23: "−23 LUFS"
        case .peak: "Peak −1 dBTP"
        }
    }

    /// Whether a file measured at `integrated` LUFS is on this target, within `tolerance`. Always
    /// at Off and at Peak, which have no loudness to reach; never for a reading that is not a number (silence).
    public func isReached(by integrated: Double) -> Bool {
        guard let target else { return true }
        return integrated.isFinite && Swift.abs(integrated - target) <= Self.tolerance
    }
}
