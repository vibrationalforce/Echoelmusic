import EchoelDSP
@testable import EchoelEngine
import Foundation
import XCTest

/// The click's sound is handed to the render thread without it ever freeing one.
final class ClickSoundTests: XCTestCase {
    private func sound(_ value: Float) -> SampleBuffer? {
        SampleBuffer(samples: [Float](repeating: value, count: 480), sampleRate: 48_000)
    }

    func testANewSoundIsTakenOnTheNextChunk() {
        let click = ClickSound()
        XCTAssertNil(click.sound)
        let first = sound(0.5)
        click.set(first)
        XCTAssertNil(click.sound, "nothing changes before the render thread drains")
        click.drain()
        XCTAssertTrue(click.sound === first)
        click.set(nil)
        click.drain()
        XCTAssertNil(click.sound, "nil is the built-in click again")
    }

    func testASoundNeverTakenIsDroppedAndAReplacedOneIsLetGo() {
        let click = ClickSound()
        click.set(sound(0.1))
        click.set(sound(0.2))
        XCTAssertEqual(click.heldSounds, 1, "the first was never taken and never can be")
        click.drain()
        click.set(sound(0.3))
        XCTAssertEqual(click.heldSounds, 2, "the one that plays and the one waiting")
        click.drain()
        XCTAssertEqual(click.heldSounds, 1, "the replaced one is let go once the render thread took the new one")
    }
}
