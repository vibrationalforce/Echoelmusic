import XCTest
@testable import EchoelEngine

/// Functional 64-channel diagnostics guard. This intentionally measures no realtime performance.
final class RenderLoadChannelCoverageTests: XCTestCase {
    func testAQuietSampleInTheLastOfSixtyFourChannelsIsNotReportedAsSilence() {
        let frames = 128
        let count = 64
        let channels = UnsafeMutablePointer<UnsafeMutablePointer<Float>>.allocate(capacity: count)
        for channel in 0..<count {
            let samples = UnsafeMutablePointer<Float>.allocate(capacity: frames)
            samples.initialize(repeating: 0, count: frames)
            channels[channel] = samples
        }
        defer {
            for channel in 0..<count {
                channels[channel].deinitialize(count: frames)
                channels[channel].deallocate()
            }
            channels.deallocate()
        }

        let load = RenderLoad()
        load.recordOutput(channels, count: count, frames: frames, playing: true)
        channels[count - 1][frames - 1] = 0.000_01
        load.recordOutput(channels, count: count, frames: frames, playing: true)
        channels[count - 1][frames - 1] = 0
        load.recordOutput(channels, count: count, frames: frames, playing: false)

        XCTAssertEqual(load.take().silent, 1,
                       "the only silent callback was the first one; even the last bus matters")
    }
}
