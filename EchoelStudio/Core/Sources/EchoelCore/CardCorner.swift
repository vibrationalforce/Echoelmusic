import Foundation

/// The corner of a view a small card rests in — the Field window over the other views. A card
/// that floats over controls has to be able to get out of their way: the musician drags it and it
/// rests in the nearest corner; the corner is kept on this device, never in the song.
///
/// A value type with the rule only. Leading and trailing are the reading direction's sides, so
/// the caller says which way the drag went in those terms.
public enum CardCorner: String, CaseIterable, Sendable {
    case topLeading
    case topTrailing
    case bottomLeading
    case bottomTrailing

    /// How far a drag has to go along one axis to cross to the other side, in points: far enough
    /// that a slip of the thumb leaves the card where it was.
    public static let crossingDistance: Double = 60

    public var isTop: Bool { self == .topLeading || self == .topTrailing }
    public var isLeading: Bool { self == .topLeading || self == .bottomLeading }

    /// The corner on the given sides.
    public static func corner(top: Bool, leading: Bool) -> CardCorner {
        switch (top, leading) {
        case (true, true): .topLeading
        case (true, false): .topTrailing
        case (false, true): .bottomLeading
        case (false, false): .bottomTrailing
        }
    }

    /// Where the card rests after it is let go `towardTrailing` points to the trailing side and
    /// `down` points lower than it rested (negative: to the leading side, up). Each axis is decided
    /// on its own: a drag of `crossingDistance` or more toward the other side crosses, anything
    /// shorter — or a number that is none — stays.
    public func moved(towardTrailing: Double, down: Double) -> CardCorner {
        var top = isTop
        var leading = isLeading
        if towardTrailing.isFinite {
            if leading, towardTrailing >= Self.crossingDistance { leading = false }
            else if !leading, towardTrailing <= -Self.crossingDistance { leading = true }
        }
        if down.isFinite {
            if top, down >= Self.crossingDistance { top = false }
            else if !top, down <= -Self.crossingDistance { top = true }
        }
        return Self.corner(top: top, leading: leading)
    }

    /// The next corner going round — for a control that moves the card without a drag.
    public var next: CardCorner {
        switch self {
        case .bottomTrailing: .bottomLeading
        case .bottomLeading: .topLeading
        case .topLeading: .topTrailing
        case .topTrailing: .bottomTrailing
        }
    }

    /// This corner, unless `taken` holds it: then the corner beside it on the same edge.
    public func avoiding(_ taken: CardCorner?) -> CardCorner {
        guard let taken, taken == self else { return self }
        return Self.corner(top: isTop, leading: !isLeading)
    }
}
