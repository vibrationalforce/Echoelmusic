import EchoelCore
import XCTest
@testable import EchoelEngine

/// A song position becomes a tick on the render thread. One that is not a number must not trap
/// there, which would end the app: it reads as the song's start (render audit 2026-11-25, B30).
final class SongTickTests: XCTestCase {
    func testAPositionThatIsNotANumberReadsAsTheStartInsteadOfTrapping() {
        XCTAssertEqual(EngineCore.songTick(.nan), 0)
        XCTAssertEqual(EngineCore.songTick(.infinity), 0)
        XCTAssertEqual(EngineCore.songTick(-.infinity), 0)
        XCTAssertEqual(EngineCore.songTick(1e300), 0, "past what a tick can hold")
    }

    func testEveryOtherPositionConvertsAsBefore() {
        XCTAssertEqual(EngineCore.songTick(1_920.7), 1_920)
        XCTAssertEqual(EngineCore.songTick(-3.5), -3)
        XCTAssertEqual(EngineCore.songTick(Double(MusicalTime.maximumTick)), MusicalTime.maximumTick)
    }
}
