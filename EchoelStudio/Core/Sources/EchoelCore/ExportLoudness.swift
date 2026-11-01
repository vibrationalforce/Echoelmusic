import Foundation

/// The loudness an export is brought to (CUT, 2026-11-01): Off — the mix as it plays, as every
/// export was before — or one of three integrated-loudness targets a finished file is commonly
/// asked for: −14 LUFS (streaming and social platforms), −16 LUFS (podcasts) and −23 LUFS
/// (broadcast, EBU R 128). Every target keeps the true peak at or under −1 dBTP, so a lossy
/// encoding does not clip. The app renders, then brings the mix there offline
/// (`LoudnessNormalizer` in EchoelDSP) and says what the mix measured before and the file after.
///
/// A device setting, never stored in the song (no format field). The raw values are what the device
/// keeps between launches: keep them as they are.
public enum ExportLoudness: String, CaseIterable, Sendable {
    case off
    case minus14 = "-14"
    case minus16 = "-16"
    case minus23 = "-23"

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
        }
    }

    public var title: String {
        switch self {
        case .off: "Off"
        case .minus14: "−14 LUFS"
        case .minus16: "−16 LUFS"
        case .minus23: "−23 LUFS"
        }
    }

    /// Whether a file measured at `integrated` LUFS is on this target, within `tolerance`. Always
    /// at Off, which has nothing to reach; never for a reading that is not a number (silence).
    public func isReached(by integrated: Double) -> Bool {
        guard let target else { return true }
        return integrated.isFinite && Swift.abs(integrated - target) <= Self.tolerance
    }
}
