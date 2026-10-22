import EchoelCore
import EchoelDSP
import XCTest
@testable import EchoelKernels

/// The registry the app's engine makes its built-in kernels from (S-26 D2.4): the engine plays
/// whatever this returns, so a device without a kernel here is a silent track there.
final class BuiltInKernelsTests: XCTestCase {
    private let rate = 48_000.0

    func testEveryBuiltInDeviceHasAKernelThatPublishesItsDevicesTable() throws {
        for device in InstrumentDevice.builtIn {
            let kernel = try XCTUnwrap(BuiltInKernels.kernel(for: device, sampleRate: rate, maximumFrames: 512),
                                       "\(device) has no kernel")
            XCTAssertEqual(type(of: kernel).parameters, device.parameters.map(InstrumentKernelParameter.init), "\(device)")
            XCTAssertEqual(kernel.sampleRate, rate, "\(device)")
        }
    }

    func testAPluginAndAnInstrumentFromALaterBuildHaveNoKernel() {
        XCTAssertNil(BuiltInKernels.kernel(for: .plugin, sampleRate: rate, maximumFrames: 512))
        XCTAssertNil(BuiltInKernels.kernel(for: .unrecognized, sampleRate: rate, maximumFrames: 512))
    }

    /// The engine hands a track's sample to the one kernel that takes it, and only the sampler does.
    func testOnlyTheSamplerTakesASampleFromTheEngine() throws {
        for device in InstrumentDevice.builtIn {
            let kernel = try XCTUnwrap(BuiltInKernels.kernel(for: device, sampleRate: rate, maximumFrames: 512))
            XCTAssertEqual(kernel is any SampleAssigningKernel, device == .sampler, "\(device)")
        }
    }

    /// The engine always played the kit at unity; the plugin starts at the table's default instead.
    func testTheEnginesKitStartsAtUnity() throws {
        let kit = try XCTUnwrap(BuiltInKernels.kernel(for: .drums, sampleRate: rate, maximumFrames: 512))
        // The kit's one row, its level.
        XCTAssertEqual(kit.parameter(0), 1)
    }
}
