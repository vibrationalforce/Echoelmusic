import EchoelCore
import EchoelDSP
import XCTest
@testable import EchoelKernels

/// Every one of the kit's eight pieces hears its own tune, decay and level rows through the
/// kernel, sample for sample as the kit set directly. `testTheSoundRowsReachTheKitAndClamp`
/// hears only the kick; this one would catch a row that lands on the wrong piece. The pieces are
/// matched to their rows by an explicit table here, not by the order the kernel uses.
final class DrumKernelPieceRowsTests: XCTestCase {
    /// Row key, the piece it must reach, and a note that plays that piece.
    private static let pieces: [(key: String, piece: DrumKit.Piece, note: UInt8)] = [
        ("kick", .kick, 36), ("snare", .snare, 38), ("clap", .clap, 39), ("lowTom", .lowTom, 41),
        ("highTom", .highTom, 48), ("closedHat", .closedHat, 42), ("openHat", .openHat, 46), ("crash", .crash, 49),
    ]

    func testEveryPiecesRowsReachThatPieceAsTheKitSetDirectly() {
        let rows = InstrumentDevice.drums.parameters
        func address(_ key: String) -> Int { rows.firstIndex { $0.key.rawValue == key } ?? -1 }
        let kernel = DrumKernel(sampleRate: 48_000, maximumFrames: 4_096, level: 1)
        var kit = DrumKit(sampleRate: 48_000)
        for (index, entry) in Self.pieces.enumerated() {
            // Distinct values for every piece, each inside its row's range (tune −24…24,
            // decay 0.1…4, level 0…1), so a swapped row changes the sound.
            let tune = Float(index * 3 - 9)
            let decay = Float(0.4) + Float(index) * Float(0.3)
            let level = Float(0.3) + Float(index) * Float(0.1)
            for (suffix, value) in [("tune", tune), ("decay", decay), ("level", level)] {
                let at = address("drums.\(entry.key).\(suffix)")
                XCTAssertGreaterThanOrEqual(at, 0, "drums.\(entry.key).\(suffix) is a row")
                kernel.setParameter(at, value)
            }
            kit.setSound(DrumKit.PieceSound(tune: tune, decay: decay, level: level), for: entry.piece)
        }
        for entry in Self.pieces {
            kernel.receive(status: 0x90, entry.note, 120)
            kit.noteOn(pitch: entry.note, velocity: 120)
        }

        var direct = [Float](repeating: 0, count: 4_800)
        direct.withUnsafeMutableBufferPointer { (buffer: inout UnsafeMutableBufferPointer<Float>) in
            kit.render(into: buffer)
        }
        XCTAssertEqual(render(kernel, frames: 4_800), direct, "all eight pieces play their own rows")
        XCTAssertGreaterThan(direct.map { abs($0) }.max() ?? 0, 0, "the reference is not silence")
    }

    private func render(_ kernel: DrumKernel, frames: Int) -> [Float] {
        var left = [Float](repeating: 0, count: frames)
        var right = [Float](repeating: 0, count: frames)
        left.withUnsafeMutableBufferPointer { (l: inout UnsafeMutableBufferPointer<Float>) in
            right.withUnsafeMutableBufferPointer { (r: inout UnsafeMutableBufferPointer<Float>) in
                guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                kernel.render(frames: frames, left: lp, right: rp, gain: 1)
            }
        }
        return left
    }
}
