/// A harmony voice's interval, by name: the harmonizer's choices are harmonies, not semitone
/// steps (founder 2026-07-29: "keine Semitone-Schritte sondern sinnvolle harmonische"). Of the
/// twenty-five whole steps within an octave either way, these are the ones that harmonise when held
/// in parallel under a melody; seconds, sevenths and the tritone beat instead, so they are not
/// offered. Where an interval has a major and a minor form, the name says which.
///
/// A fixed interval does not follow the key: a "major third up" stays major over a minor chord.
/// Ported from the earlier app's `HarmonyInterval`, with Off first so a voice can be silent.
///
/// The harmonizer stores a voice as the INDEX of its choice in this list (an Audio Unit indexed
/// parameter), so the order is frozen like the scales' (`StoredNamesTests`): never reorder, a new
/// interval goes at the end.
public enum HarmonyInterval: Int, CaseIterable, Sendable, Identifiable {
    case off
    case octaveDown, majorSixthDown, minorSixthDown, fifthDown, fourthDown, majorThirdDown, minorThirdDown
    case unison
    case minorThirdUp, majorThirdUp, fourthUp, fifthUp, minorSixthUp, majorSixthUp, octaveUp

    public var id: Int { rawValue }

    /// The shift in semitones; nil for Off.
    public var semitones: Int? {
        switch self {
        case .off: nil
        case .octaveDown: -12
        case .majorSixthDown: -9
        case .minorSixthDown: -8
        case .fifthDown: -7
        case .fourthDown: -5
        case .majorThirdDown: -4
        case .minorThirdDown: -3
        case .unison: 0
        case .minorThirdUp: 3
        case .majorThirdUp: 4
        case .fourthUp: 5
        case .fifthUp: 7
        case .minorSixthUp: 8
        case .majorSixthUp: 9
        case .octaveUp: 12
        }
    }

    /// Plain words, no theory shorthand: a performer should not have to decode "P5" on stage.
    public var title: String {
        switch self {
        case .off: "Off"
        case .octaveDown: "Octave down"
        case .majorSixthDown: "Major sixth down"
        case .minorSixthDown: "Minor sixth down"
        case .fifthDown: "Fifth down"
        case .fourthDown: "Fourth down"
        case .majorThirdDown: "Major third down"
        case .minorThirdDown: "Minor third down"
        case .unison: "Unison (double)"
        case .minorThirdUp: "Minor third up"
        case .majorThirdUp: "Major third up"
        case .fourthUp: "Fourth up"
        case .fifthUp: "Fifth up"
        case .minorSixthUp: "Minor sixth up"
        case .majorSixthUp: "Major sixth up"
        case .octaveUp: "Octave up"
        }
    }

    /// The choice at a stored index; an index this build does not know reads as Off.
    public init(index: Float) {
        guard index.isFinite, index >= 0, index < Float(Self.allCases.count) else {
            self = .off
            return
        }
        self = Self(rawValue: Int(index.rounded())) ?? .off
    }
}
