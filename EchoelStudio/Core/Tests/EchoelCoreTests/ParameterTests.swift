import XCTest
@testable import EchoelCore

final class ParameterTests: XCTestCase {
    private func projectWithTrack() throws -> (Project, TrackID) {
        var project = Project()
        let track = TrackID()
        try Command.addTrack(id: track, name: "Bass", kind: .instrument, index: nil).apply(to: &project)
        return (project, track)
    }

    func testEveryListedParameterHasAValueAndACommandThatSetsIt() throws {
        var (project, _) = try projectWithTrack()
        XCTAssertEqual(project.parameters.count, 5 + Project.contextDescriptors.count + SynthParameter.all.count)
        for descriptor in project.parameters {
            XCTAssertNotNil(project.value(of: descriptor.address), descriptor.address.description)
            XCTAssertEqual(project.descriptor(for: descriptor.address), descriptor)
            let target = descriptor.value(forNormalized: 0.5)
            let command = try XCTUnwrap(Command.setParameter(descriptor.address, to: target))
            try command.apply(to: &project)
            let stored = try XCTUnwrap(project.value(of: descriptor.address))
            XCTAssertEqual(stored, target, accuracy: 1e-9, descriptor.address.description)
        }
    }

    func testAnAddressForAMissingTrackNamesNothing() throws {
        let (project, _) = try projectWithTrack()
        let ghost = ParameterAddress.volume(TrackID())
        XCTAssertNil(project.value(of: ghost))
        XCTAssertNil(project.descriptor(for: ghost))
        XCTAssertNil(Command.setParameter(ParameterAddress(.project, .volume), to: 0))
        XCTAssertNil(project.value(of: ParameterAddress(.track(TrackID()), ParameterKey(rawValue: "nope"))))
    }

    func testSettingAParameterGoesThroughTheSameValidation() throws {
        var (project, track) = try projectWithTrack()
        let command = try XCTUnwrap(Command.setParameter(.pan(track), to: 2))
        XCTAssertThrowsError(try command.apply(to: &project))
        XCTAssertEqual(project.value(of: .pan(track)), 0)
    }

    func testRemovingATrackRemovesItsParameters() throws {
        var (project, track) = try projectWithTrack()
        try Command.removeTrack(track).apply(to: &project)
        XCTAssertEqual(project.parameters.count, 3 + Project.contextDescriptors.count, "tempo, master volume and pan, and the musical context")
        XCTAssertNil(project.descriptor(for: .volume(track)))
    }

    func testTheFaderTaperIsMonotonicAndHitsBothEnds() throws {
        let (project, _) = try projectWithTrack()
        let fader = try XCTUnwrap(project.descriptor(for: .masterVolume))
        XCTAssertEqual(fader.value(forNormalized: 0), MixerStrip.volumeRange.lowerBound)
        XCTAssertEqual(fader.value(forNormalized: 1), MixerStrip.volumeRange.upperBound, accuracy: 1e-9)
        var previous = -Double.infinity
        for step in 0...100 {
            let value = fader.value(forNormalized: Double(step) / 100)
            XCTAssertGreaterThanOrEqual(value, previous)
            previous = value
        }
        // Unity gain sits high on the throw, as on a console.
        XCTAssertGreaterThan(fader.normalized(0), 0.7)
        XCTAssertLessThan(fader.normalized(0), 0.85)
    }

    func testNormalizedRoundTripsForBothTapers() throws {
        let (project, track) = try projectWithTrack()
        for address in [ParameterAddress.tempo, .volume(track), .pan(track)] {
            let descriptor = try XCTUnwrap(project.descriptor(for: address))
            for step in 1...20 {
                let n = Double(step) / 20
                let back = descriptor.normalized(descriptor.value(forNormalized: n))
                XCTAssertEqual(back, n, accuracy: 1e-9, "\(address) at \(n)")
            }
        }
    }

    func testNonFiniteControlInputIsHarmless() throws {
        let (project, _) = try projectWithTrack()
        for descriptor in project.parameters {
            for bad in [Double.nan, .infinity, -.infinity] {
                XCTAssertTrue(descriptor.value(forNormalized: bad).isFinite)
                XCTAssertTrue(descriptor.normalized(bad).isFinite)
            }
        }
    }

    func testTheTextFormIsStable() {
        XCTAssertEqual(ParameterAddress.tempo.description, "project/tempo")
        XCTAssertEqual(ParameterAddress.masterVolume.description, "master/mixer.volume")
        let id = TrackID()
        XCTAssertEqual(ParameterAddress.pan(id).description, "track/\(id.description)/mixer.pan")
    }

    func testAnAddressSurvivesEncoding() throws {
        let address = ParameterAddress.volume(TrackID())
        let data = try JSONEncoder().encode(address)
        XCTAssertEqual(try JSONDecoder().decode(ParameterAddress.self, from: data), address)
    }
}
