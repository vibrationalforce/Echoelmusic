import Foundation

/// The hardware keyboard's shortcuts: which key does which transport, edit or view action. One
/// table, so no key does two things and no action has two keys; the app attaches each key to the
/// button that already does its action, and the locate keys to the transport's locate. Nothing
/// here knows about SwiftUI: a key is the character it types plus Command and Shift.
public enum ShortcutMap {
    public enum Action: Hashable, Sendable {
        case playStop, record, loop, undo, redo
        /// The view at this place on the bar of views, from 0.
        case view(Int)
        /// Back to bar 1.
        case toStart
        /// To the bar line before the playhead, or after it.
        case barBack, barForward
    }

    public struct Key: Hashable, Sendable {
        /// What the key types: a letter in lower case, a digit, a space, "\r" for Return.
        public let character: Character
        public let command: Bool
        public let shift: Bool

        public init(_ character: Character, command: Bool = false, shift: Bool = false) {
            self.character = character
            self.command = command
            self.shift = shift
        }

        /// How the key is written on a menu: "⇧⌘Z", "Space", "Return".
        public var title: String {
            let name: String
            switch character {
            case " ": name = "Space"
            case "\r": name = "Return"
            default: name = String(character).uppercased()
            }
            return (shift ? "⇧" : "") + (command ? "⌘" : "") + name
        }
    }

    /// Views on the bar of views the number keys reach: Command-1 to Command-7.
    public static let viewCount = 7

    /// Every shortcut, once. A plain key for the transport, as in a desktop DAW; Command for undo,
    /// redo and the views, so a digit typed into a field is never a view change.
    public static let bindings: [(key: Key, action: Action)] = {
        var all: [(key: Key, action: Action)] = [
            (Key(" "), .playStop),
            (Key("r"), .record),
            (Key("l"), .loop),
            (Key("z", command: true), .undo),
            (Key("z", command: true, shift: true), .redo),
            (Key("\r"), .toStart),
            (Key(","), .barBack),
            (Key("."), .barForward),
        ]
        let digits: [Character] = ["1", "2", "3", "4", "5", "6", "7"]
        for (index, digit) in digits.prefix(viewCount).enumerated() {
            all.append((Key(digit, command: true), .view(index)))
        }
        return all
    }()

    /// The action a key does, or nil for a key without one.
    public static func action(for key: Key) -> Action? {
        bindings.first { $0.key == key }?.action
    }

    /// The key that does `action`, or nil for an action without one (a view past the seventh).
    public static func key(for action: Action) -> Key? {
        bindings.first { $0.action == action }?.key
    }

    /// Where a locate key sends a playhead standing at `tick`: back to the bar line at or before it
    /// (the one before that when it stands on one), or forward to the next bar line — in the bars
    /// of `meter`, never before bar 1 or past what a song holds. Any other action leaves it.
    public static func locate(_ action: Action, from tick: Tick, meter: MeterMap) -> Tick {
        let at = Swift.min(Swift.max(0, tick), MusicalTime.maximumTick)
        let bar = meter.bar(at: at)
        let target: Tick
        switch action {
        case .toStart:
            target = 0
        case .barBack:
            target = meter.barStart(at: at) == at ? meter.tick(ofBar: Swift.max(0, bar - 1)) : meter.barStart(at: at)
        case .barForward:
            target = meter.tick(ofBar: bar + 1)
        default:
            target = at
        }
        return Swift.min(Swift.max(0, target), MusicalTime.maximumTick)
    }
}
