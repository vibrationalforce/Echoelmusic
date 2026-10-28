import XCTest
@testable import EchoelDSP

/// The G-A ramp vectors (`.claude/skills/g-a-body-modulation/references/FIXTURES.json`, group
/// `ramp`). Each ramp is read in the fixture's blocks, so a reset at a block edge would show.
final class LinearRampTests: XCTestCase {
    private func read(_ ramp: LinearRamp, count: Int, blocks: [Int]) -> [Double] {
        var ramp = ramp
        var output: [Double] = []
        var block = 0
        while output.count < count {
            let length = Swift.min(blocks[block % blocks.count], count - output.count)
            for _ in 0..<length { output.append(ramp.next()) }
            block += 1
        }
        return output
    }

    private func assertClose(_ actual: [Double], _ expected: [Double], file: StaticString = #filePath, line: UInt = #line) {
        XCTAssertEqual(actual.count, expected.count, file: file, line: line)
        for (a, e) in zip(actual, expected) { XCTAssertEqual(a, e, accuracy: 1e-12, file: file, line: line) }
    }

    /// Linear sample-domain ramp reaches target at index 4, independent of blocks.
    func testR01ReachesTheTargetWhateverTheBlocks() throws {
        let ramp = try XCTUnwrap(LinearRamp(from: 0.8, to: 0.2, durationSamples: 4))
        assertClose(read(ramp, count: 7, blocks: [2, 3]), [0.8, 0.65, 0.5, 0.35, 0.2, 0.2, 0.2])
        assertClose(read(ramp, count: 7, blocks: [1]), [0.8, 0.65, 0.5, 0.35, 0.2, 0.2, 0.2])
    }

    /// No transition produces identical value at every sample.
    func testR02NoTransitionHoldsTheValue() throws {
        let ramp = try XCTUnwrap(LinearRamp(from: 0.5, to: 0.5, durationSamples: 4))
        assertClose(read(ramp, count: 3, blocks: [1]), [0.5, 0.5, 0.5])
    }

    /// Zero duration refuses division by zero.
    func testR03ZeroDurationIsRefused() {
        XCTAssertNil(LinearRamp(from: 0.5, to: 0.2, durationSamples: 0))
        XCTAssertNil(LinearRamp(from: .nan, to: 0.2, durationSamples: 4))
        XCTAssertNil(LinearRamp(from: 0.5, to: 1.5, durationSamples: 4))
    }
}
