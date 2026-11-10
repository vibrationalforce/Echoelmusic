import EchoelCore
import XCTest
@testable import EchoelEngine

final class ModulationInputsTests: XCTestCase {
    func testEverySourceStartsAbsent() {
        let inputs = ModulationInputs()
        for source in ModulationSource.allCases { XCTAssertNil(inputs.value(source), source.rawValue) }
    }

    func testAMeasurementIsReadBackAndClearedOnNil() {
        let inputs = ModulationInputs()
        inputs.set(.heartRate, 0.4)
        inputs.set(.breath, 1)
        XCTAssertEqual(inputs.value(.heartRate), 0.4)
        XCTAssertEqual(inputs.value(.breath), 1)
        XCTAssertNil(inputs.value(.hrv), "one source does not fill another")
        inputs.set(.heartRate, nil)
        XCTAssertNil(inputs.value(.heartRate), "a stopped source is absent again")
        inputs.clear()
        XCTAssertNil(inputs.value(.breath))
    }

    /// REC-1: a value from Apple Health moves sound on the device but is never handed to MIDI out;
    /// the next writer brings its own provenance.
    func testAPrivateValueIsReadButNeverShared() {
        let inputs = ModulationInputs()
        inputs.set(.heartRate, 0.4)
        XCTAssertEqual(inputs.shareableValue(.heartRate), 0.4)
        inputs.set(.heartRate, 0.5, mayLeaveDevice: false)
        XCTAssertEqual(inputs.value(.heartRate), 0.5, "it still modulates on the device")
        XCTAssertNil(inputs.shareableValue(.heartRate), "it never leaves")
        inputs.set(.heartRate, 0, mayLeaveDevice: false)
        XCTAssertEqual(inputs.value(.heartRate), 0, "a private zero is still zero")
        XCTAssertNil(inputs.shareableValue(.heartRate), "and still private")
        inputs.set(.heartRate, nil, mayLeaveDevice: false)
        XCTAssertNil(inputs.value(.heartRate))
        XCTAssertNil(inputs.shareableValue(.heartRate))
        inputs.set(.heartRate, 0.6)
        XCTAssertEqual(inputs.shareableValue(.heartRate), 0.6, "a strap value after it is shareable again")
        XCTAssertNil(inputs.shareableValue(.hrv), "absent stays absent")
    }

    /// The live stream's picture is drawn from a frame that asks for shareable values only
    /// (`FieldFrame.leavingDevice`): Apple Health's pulse moves the window on the device and is
    /// absent from the picture that leaves; a value that may leave is in both.
    func testAFrameLeavingTheDeviceCarriesNoPrivatePulse() {
        let inputs = ModulationInputs()
        inputs.set(.heartRate, 0.5, mayLeaveDevice: false)
        inputs.set(.coherence, 0.7)
        let onDevice = FieldFrame(level: 0.4, pulse: inputs.value(.heartRate), coherence: inputs.value(.coherence))
        XCTAssertEqual(onDevice.pulse, 0.5, "the window on this device shows it")
        let fromHealth = onDevice.leavingDevice { (source: ModulationSource) -> Double? in
            inputs.shareableValue(source)
        }
        XCTAssertNil(fromHealth.pulse, "a pulse from Apple Health is not in a picture that leaves")
        XCTAssertEqual(fromHealth.coherence, 0.7, "what may leave still is")
        XCTAssertEqual(fromHealth.level, onDevice.level)
        inputs.set(.heartRate, 0.6)
        let fromStrap = onDevice.leavingDevice { (source: ModulationSource) -> Double? in
            inputs.shareableValue(source)
        }
        XCTAssertEqual(fromStrap.pulse, 0.6, "a strap's pulse after it leaves again")
    }

    /// G-A M09: a value out of the domain is absent, not clamped into the strongest swing.
    func testAValueOutsideZeroToOneIsAbsent() {
        let inputs = ModulationInputs()
        for bad in [-0.01, 1.01, .nan, .infinity] {
            inputs.set(.coherence, 0.5)
            inputs.set(.coherence, bad)
            XCTAssertNil(inputs.value(.coherence), "\(bad)")
        }
    }

    func testTheIndexIsTheSourcesPlaceInTheList() {
        let inputs = ModulationInputs()
        inputs.set(.macro1, 0.25)
        let index = ModulationInputs.index(.macro1)
        XCTAssertEqual(index.flatMap { inputs.value(at: $0) }, 0.25)
        XCTAssertNil(inputs.value(at: -1))
        XCTAssertNil(inputs.value(at: ModulationSource.allCases.count))
    }
}
