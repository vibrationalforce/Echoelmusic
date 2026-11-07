import XCTest
@testable import EchoelCore

/// The hardware keyboard's table: one action per key, one key per action, and the locate keys
/// land on bar lines.
final class ShortcutMapTests: XCTestCase {
    func testEachKeyMapsToExactlyOneAction() {
        let keys = ShortcutMap.bindings.map(\.key)
        XCTAssertEqual(Set(keys).count, keys.count, "no key does two things")
        let actions = ShortcutMap.bindings.map(\.action)
        XCTAssertEqual(Set(actions).count, actions.count, "no action has two keys")
        for binding in ShortcutMap.bindings {
            XCTAssertEqual(ShortcutMap.action(for: binding.key), binding.action)
            XCTAssertEqual(ShortcutMap.key(for: binding.action), binding.key)
        }
    }

    func testTheTransportKeysAreTheOnesADesktopDAWUses() {
        XCTAssertEqual(ShortcutMap.action(for: .init(" ")), .playStop)
        XCTAssertEqual(ShortcutMap.action(for: .init("r")), .record)
        XCTAssertEqual(ShortcutMap.action(for: .init("l")), .loop)
        XCTAssertEqual(ShortcutMap.action(for: .init("z", command: true)), .undo)
        XCTAssertEqual(ShortcutMap.action(for: .init("z", command: true, shift: true)), .redo)
        XCTAssertEqual(ShortcutMap.action(for: .init("\r")), .toStart)
        XCTAssertEqual(ShortcutMap.action(for: .init(",")), .barBack)
        XCTAssertEqual(ShortcutMap.action(for: .init(".")), .barForward)
        XCTAssertNil(ShortcutMap.action(for: .init("z")), "a plain Z undoes nothing")
        XCTAssertNil(ShortcutMap.action(for: .init("x")))
    }

    func testCommandAndADigitChoosesEachOfTheSevenViews() {
        for index in 0..<ShortcutMap.viewCount {
            let digit = Character(String(index + 1))
            XCTAssertEqual(ShortcutMap.action(for: .init(digit, command: true)), .view(index))
            XCTAssertNil(ShortcutMap.action(for: .init(digit)), "a digit alone is typed, never a view change")
        }
        XCTAssertNil(ShortcutMap.key(for: .view(ShortcutMap.viewCount)))
    }

    func testEveryKeyHasAName() {
        XCTAssertEqual(ShortcutMap.Key(" ").title, "Space")
        XCTAssertEqual(ShortcutMap.Key("\r").title, "Return")
        XCTAssertEqual(ShortcutMap.Key("z", command: true, shift: true).title, "⇧⌘Z")
        XCTAssertEqual(ShortcutMap.Key("3", command: true).title, "⌘3")
    }

    func testTheLocateKeysLandOnBarLines() {
        let meter = MeterMap(signature: .common)
        let bar = MusicalTime.ticksPerBar(.common)
        // In bar 3, a beat after its line: back goes to that line, forward to bar 4.
        let inBarThree = 2 * bar + MusicalTime.ticksPerQuarter
        XCTAssertEqual(ShortcutMap.locate(.barBack, from: inBarThree, meter: meter), 2 * bar)
        XCTAssertEqual(ShortcutMap.locate(.barForward, from: inBarThree, meter: meter), 3 * bar)
        // On a bar line, back goes to the bar before.
        XCTAssertEqual(ShortcutMap.locate(.barBack, from: 2 * bar, meter: meter), bar)
        XCTAssertEqual(ShortcutMap.locate(.barBack, from: 0, meter: meter), 0, "never before bar 1")
        XCTAssertEqual(ShortcutMap.locate(.toStart, from: inBarThree, meter: meter), 0)
        XCTAssertEqual(ShortcutMap.locate(.barForward, from: -5, meter: meter), bar)
        XCTAssertEqual(ShortcutMap.locate(.record, from: inBarThree, meter: meter), inBarThree)
    }

    func testTheLocateKeysCountTheBarsOfAChangedMeter() {
        // One bar of 4/4, then 3/4: bar 2 starts at one 4/4 bar, bar 3 a 3/4 bar later.
        let four = MusicalTime.ticksPerBar(.common)
        let three = MusicalTime.ticksPerBar(TimeSignature(3, 4))
        let meter = MeterMap(signature: .common, changes: [TimeSignatureChange(tick: four, signature: TimeSignature(3, 4))])
        XCTAssertEqual(ShortcutMap.locate(.barForward, from: four, meter: meter), four + three)
        XCTAssertEqual(ShortcutMap.locate(.barBack, from: four + three, meter: meter), four)
    }
}
