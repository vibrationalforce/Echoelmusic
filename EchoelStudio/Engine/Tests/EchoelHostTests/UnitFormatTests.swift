import AVFoundation
import XCTest
@testable import EchoelHost

/// What an Echoel unit tells a host about its busses (`UnitFormat`): stereo and nothing else, and
/// only the one sample layout its render block reads and fills.
final class UnitFormatTests: XCTestCase {
    func testAnInstrumentTellsAHostNoInputAndTwoOutputs() {
        XCTAssertEqual(UnitFormat.instrumentCapabilities.map(\.intValue), [0, 2])
        XCTAssertEqual(UnitFormat.channelCounts.map(\.intValue), [2])
    }

    func testStereoFloatInSeparateBuffersIsTakenAtEveryRate() throws {
        for rate in [44_100.0, 48_000.0, 88_200.0, 96_000.0] {
            let stereo = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: rate, channels: 2))
            XCTAssertTrue(UnitFormat.accepts(stereo), "\(rate) Hz")
        }
    }

    func testAFormatARenderBlockCannotFillIsRefused() throws {
        let mono = try XCTUnwrap(AVAudioFormat(standardFormatWithSampleRate: 48_000, channels: 1))
        XCTAssertFalse(UnitFormat.accepts(mono), "one buffer, and the block fills two")
        let interleaved = try XCTUnwrap(AVAudioFormat(commonFormat: .pcmFormatFloat32, sampleRate: 48_000,
                                                      channels: 2, interleaved: true))
        XCTAssertFalse(UnitFormat.accepts(interleaved), "one buffer of both channels is not two buffers")
        let integer = try XCTUnwrap(AVAudioFormat(commonFormat: .pcmFormatInt16, sampleRate: 48_000,
                                                  channels: 2, interleaved: false))
        XCTAssertFalse(UnitFormat.accepts(integer), "the block writes floats")
    }
}
