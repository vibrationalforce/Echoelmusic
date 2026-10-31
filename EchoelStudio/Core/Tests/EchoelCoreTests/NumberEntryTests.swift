import XCTest
@testable import EchoelCore

final class NumberEntryTests: XCTestCase {
    func testDigitsSignAndSeparatorBuildTheTypedNumber() {
        var entry = NumberEntry(range: -24...24, decimals: 1)
        XCTAssertEqual(entry.value(else: 3), 3, "nothing typed keeps the value that was there")
        entry.type(0)
        entry.type(7)
        XCTAssertEqual(entry.text, "7", "a lone leading zero is replaced")
        entry.typeDecimal()
        entry.type(5)
        entry.type(9)
        XCTAssertEqual(entry.text, "7.5", "no more places than the entry has decimals")
        entry.setNegative(true)
        XCTAssertEqual(entry.text, "-7.5")
        XCTAssertEqual(entry.value(else: 0), -7.5)
        entry.setNegative(false)
        XCTAssertEqual(entry.value(else: 0), 7.5)
        entry.deleteLast()
        entry.deleteLast()
        XCTAssertEqual(entry.text, "7")
    }

    func testMinusIsRefusedWhereTheRangeHasNoNegativeValues() {
        var entry = NumberEntry(range: 0...1, decimals: 2)
        XCTAssertFalse(entry.allowsNegative)
        entry.type(5)
        entry.setNegative(true)
        XCTAssertEqual(entry.text, "5")
        XCTAssertEqual(entry.value(else: 0), 1, "a typed number past the range lands on its end")
    }

    func testAWholeNumberEntryTakesNoSeparatorAndTheTextHasALimit() {
        var entry = NumberEntry(range: 0...127, decimals: 0)
        entry.typeDecimal()
        XCTAssertEqual(entry.text, "", "no separator where the value is whole")
        for _ in 0..<20 { entry.type(9) }
        XCTAssertEqual(entry.text.count, NumberEntry.maxLength)
        XCTAssertEqual(entry.value(else: 0), 127)
    }

    func testOnlyASignOrASeparatorReadsAsNothingTyped() {
        var entry = NumberEntry(range: -1...1, decimals: 2)
        entry.setNegative(true)
        XCTAssertEqual(entry.value(else: 0.25), 0.25)
        entry.typeDecimal()
        XCTAssertEqual(entry.text, "-0.")
        XCTAssertEqual(entry.value(else: 0.25), 0, "\"-0.\" is a typed zero")
    }

    func testShowWritesAValueToTheEntrysGrid() {
        var entry = NumberEntry(range: -100...100, decimals: 0)
        entry.show(-0.2)
        XCTAssertEqual(entry.text, "0", "a rounded negative zero shows without its sign")
        entry.show(42.6)
        XCTAssertEqual(entry.text, "43")
        entry.show(.nan)
        XCTAssertEqual(entry.text, "43", "a non-finite value changes nothing")
    }

    func testSnappingStaysInsideABoundThatIsOffTheGrid() {
        XCTAssertEqual(NumberEntry.snapped(0.0004, to: 0.001...10, decimals: 0), 1)
        XCTAssertEqual(NumberEntry.snapped(19.96, to: 0...19.95, decimals: 1), 19.9)
        XCTAssertEqual(NumberEntry.snapped(.infinity, to: 2...5, decimals: 1), 2)
    }

    func testEachUnitIsTypedInTheUnitAMusicianReads() throws {
        let attack = ParameterDescriptor(address: .tempo, title: "Attack", unit: .seconds,
                                         range: 0.001...10, defaultValue: 0.003, taper: .exponential)
        let time = try XCTUnwrap(NumberEntryFormat(attack))
        XCTAssertEqual(time.unit, "ms")
        XCTAssertEqual(time.decimals, 0)
        XCTAssertEqual(time.displayRange(attack.range), 1...10_000)
        XCTAssertEqual(time.parameter(fromDisplay: 250), 0.25, accuracy: 1e-12)

        let pan = ParameterDescriptor(address: .masterPan, title: "Pan", unit: .pan,
                                      range: -1...1, defaultValue: 0, taper: .linear)
        let panFormat = try XCTUnwrap(NumberEntryFormat(pan))
        XCTAssertEqual(panFormat.unit, "%")
        XCTAssertTrue(panFormat.entry(for: pan.range).allowsNegative, "− pans left")
        XCTAssertEqual(panFormat.display(-0.3), -30, accuracy: 1e-12)

        let root = ParameterDescriptor(address: .tempo, title: "Root key", unit: .amount,
                                       range: 0...127, defaultValue: 60, taper: .stepped)
        XCTAssertEqual(NumberEntryFormat(root)?.decimals, 0)

        let choice = ParameterDescriptor(address: .tempo, title: "Waveform", unit: .choice,
                                         range: 0...3, defaultValue: 1, taper: .stepped, choices: ["A", "B", "C", "D"])
        XCTAssertNil(NumberEntryFormat(choice), "a named choice is a picker, never typed")
    }

    func testATempoIsTypedToTheHundredthAndTheSongKeepsIt() throws {
        var project = Project(name: "Jam")
        let descriptor = try XCTUnwrap(project.descriptor(for: .tempo))
        let format = try XCTUnwrap(NumberEntryFormat(descriptor))
        XCTAssertEqual(format.decimals, 2, "0.01 BPM, as Ableton types a tempo")
        var entry = format.entry(for: descriptor.range)
        for digit in [1, 0, 0] { entry.type(digit) }
        entry.typeDecimal()
        for digit in [2, 5, 9] { entry.type(digit) }
        XCTAssertEqual(entry.text, "100.25", "a third place is not taken")
        let typed = format.parameter(fromDisplay: entry.value(else: 0))
        XCTAssertEqual(typed, 100.25)
        try Command.setTempo(bpm: typed).apply(to: &project)
        // The format stores the tempo as a JSON number: the hundredth survives the file, no bump.
        XCTAssertEqual(try ProjectCodec.decode(ProjectCodec.encode(project)).tempo, 100.25)
    }

    func testASlowDragIsFineAndAFastOneCoversTheRange() {
        XCTAssertEqual(DragPrecision.scale(speed: 20), DragPrecision.fineScale)
        XCTAssertEqual(DragPrecision.scale(speed: -1_000), 1)
        XCTAssertEqual(DragPrecision.scale(speed: .nan), 1)
        let middle = DragPrecision.scale(speed: (DragPrecision.fineSpeed + DragPrecision.fullSpeed) / 2)
        XCTAssertEqual(middle, (DragPrecision.fineScale + 1) / 2, accuracy: 1e-12)
    }

    func testADragTicksAtTheEndsAndAtTheDefaultButNotWhenLeavingIt() {
        let range = -24.0...24.0
        XCTAssertTrue(DragPrecision.reachesDetent(from: 23, to: 24, standard: 0, range: range))
        XCTAssertTrue(DragPrecision.reachesDetent(from: -1, to: 0, standard: 0, range: range))
        XCTAssertTrue(DragPrecision.reachesDetent(from: -1, to: 1, standard: 0, range: range), "crossing it")
        XCTAssertFalse(DragPrecision.reachesDetent(from: 0, to: 1, standard: 0, range: range))
        XCTAssertFalse(DragPrecision.reachesDetent(from: 3, to: 3, standard: 0, range: range))
        XCTAssertFalse(DragPrecision.reachesDetent(from: 3, to: .nan, standard: 0, range: range))
    }
}
