import EchoelCore
import EchoelDSP
import XCTest
@testable import EchoelKernels

final class DrumKernelTests: XCTestCase {
    private func render(_ kernel: DrumKernel, frames: Int, gain: Float = 1) -> ([Float], [Float]) {
        var left = [Float](repeating: 0, count: frames)
        var right = [Float](repeating: 0, count: frames)
        left.withUnsafeMutableBufferPointer { l in
            right.withUnsafeMutableBufferPointer { r in
                guard let lp = l.baseAddress, let rp = r.baseAddress else { return }
                kernel.render(frames: frames, left: lp, right: rp, gain: gain)
            }
        }
        return (left, right)
    }

    private func peak(_ samples: [Float]) -> Float { samples.map { abs($0) }.max() ?? 0 }

    func testAKickOnNote36SoundsOnBothChannelsAndAnUnmappedNoteDoesNot() {
        let kernel = DrumKernel(sampleRate: 48_000)
        kernel.receive(status: 0x90, 20, 100)
        XCTAssertEqual(peak(render(kernel, frames: 4_800).0), 0, "note 20 is no drum")
        kernel.receive(status: 0x99, 36, 120)
        let (left, right) = render(kernel, frames: 4_800)
        XCTAssertGreaterThan(peak(left), 0.05)
        XCTAssertEqual(left, right)
        kernel.receive(status: 0x89, 36, 0)
        XCTAssertGreaterThan(peak(render(kernel, frames: 480).0), 0, "a note-off does not cut a one-shot")
        kernel.receive(status: 0xB9, 120, 0)
        XCTAssertEqual(peak(render(kernel, frames: 480).0), 0, "all sound off silences it")
    }

    func testTheLevelIsClampedAndTheDemoGainSilences() {
        let kernel = DrumKernel(sampleRate: 48_000)
        XCTAssertEqual(DrumKernel.parameters.first?.identifier, "drums_level", "the level stays at address 0")
        kernel.setParameter(0, 3)
        XCTAssertEqual(kernel.parameter(0), 1)
        kernel.setParameter(0, .nan)
        XCTAssertEqual(kernel.parameter(0), 1)
        kernel.setParameter(0, 0)
        _ = render(kernel, frames: 4_800)              // the level glides down
        kernel.receive(status: 0x90, 38, 127)
        XCTAssertLessThan(peak(render(kernel, frames: 2_400).0), 1e-4)
        kernel.setParameter(0, 1)
        kernel.receive(status: 0x90, 38, 127)
        XCTAssertEqual(peak(render(kernel, frames: 2_400, gain: 0).0), 0)
    }

    /// The app's engine renders no silent kernel, so a level set in a break has to reach the next
    /// hit from its first sample instead of gliding in after the transient.
    func testAHitOnASilentKitStartsAtTheLevelSetWhileItWasSilent() {
        let muted = DrumKernel(sampleRate: 48_000, maximumFrames: 4_096, level: 1)
        muted.setParameter(0, 0)
        muted.receive(status: 0x90, 36, 127)
        XCTAssertEqual(peak(render(muted, frames: 480).0), 0, "the kick is silent from its first sample")

        let raised = DrumKernel(sampleRate: 48_000, maximumFrames: 4_096, level: 0)
        raised.setParameter(0, 1)
        raised.receive(status: 0x90, 36, 127)
        let reference = DrumKernel(sampleRate: 48_000, maximumFrames: 4_096, level: 1)
        reference.receive(status: 0x90, 36, 127)
        let expected: [Float] = render(reference, frames: 480).0
        XCTAssertGreaterThan(peak(expected), 0.05, "the reference kick sounds")
        XCTAssertEqual(render(raised, frames: 480).0, expected, "a level raised in a break plays the next hit at that level")
    }

    /// The kit's sound by address (EchoelTools A11): every row reaches its piece, values are
    /// clamped to the row and a value that is not finite is ignored; at its defaults the kernel
    /// plays the kit as it always did.
    func testTheSoundRowsReachTheKitAndClamp() {
        let rows = InstrumentDevice.drums.parameters
        func address(_ key: String) -> Int { rows.firstIndex { $0.key.rawValue == key } ?? -1 }
        let kernel = DrumKernel(sampleRate: 48_000)
        let tune = address("drums.snare.tune")
        kernel.setParameter(tune, 99)
        XCTAssertEqual(kernel.parameter(tune), 24)
        kernel.setParameter(tune, .nan)
        XCTAssertEqual(kernel.parameter(tune), 24)
        XCTAssertEqual(kernel.parameter(rows.count), 0, "an address past the table reads 0")
        kernel.setParameter(rows.count, 1)

        let plain = DrumKernel(sampleRate: 48_000, maximumFrames: 4_096, level: 1)
        let tuned = DrumKernel(sampleRate: 48_000, maximumFrames: 4_096, level: 1)
        var kit = DrumKit(sampleRate: 48_000)
        tuned.setParameter(address("drums.kick.tune"), 7)
        tuned.setParameter(address("drums.kick.level"), 0.5)
        tuned.setParameter(address("drums.kickGlide"), 2)
        kit.setSound(DrumKit.PieceSound(tune: 7, level: 0.5), for: .kick)
        kit.setKickGlide(2)
        for kernel in [plain, tuned] { kernel.receive(status: 0x90, 36, 120) }
        kit.noteOn(pitch: 36, velocity: 120)
        var direct = [Float](repeating: 0, count: 4_800)
        direct.withUnsafeMutableBufferPointer { kit.render(into: $0) }
        XCTAssertEqual(render(tuned, frames: 4_800).0, direct, "the rows play as the kit set directly")
        var reference = DrumKit(sampleRate: 48_000)
        reference.noteOn(pitch: 36, velocity: 120)
        var untouched = [Float](repeating: 0, count: 4_800)
        untouched.withUnsafeMutableBufferPointer { reference.render(into: $0) }
        XCTAssertEqual(render(plain, frames: 4_800).0, untouched, "the defaults play the kit as it always sounded")
    }
}

/// The line the Studio and the plugin show (`DrumNoteMap`) names what the kit really plays.
final class DrumMapTests: XCTestCase {
    func testEveryNoteInTheShownMapPlaysThePieceItNames() {
        let expected: [String: DrumKit.Piece] = [
            "Kick": .kick, "Snare": .snare, "Clap": .clap, "Closed Hat": .closedHat,
            "Low Tom": .lowTom, "Open Hat": .openHat, "Crash": .crash, "High Tom": .highTom,
        ]
        XCTAssertEqual(DrumNoteMap.pieces.count, DrumKit.Piece.allCases.count, "every piece is named once")
        for (name, note) in DrumNoteMap.pieces {
            XCTAssertEqual(DrumKit.Piece.forPitch(UInt8(note)), expected[name], "\(name) \(note)")
        }
        let notes = DrumNoteMap.pieces.map(\.note)
        XCTAssertEqual(notes, notes.sorted(), "in note order")
        XCTAssertTrue(DrumNoteMap.line.hasPrefix("General MIDI drum map: Kick 36 · Snare 38"))
        XCTAssertTrue(DrumNoteMap.line.hasSuffix("High Tom 50."))
    }
}
