import XCTest
@testable import EchoelCore

/// What each connection says, from values: the body batch's silence law, the song batch, every
/// track as an ADM-OSC object, and the light's look, channels and flash guard.
final class ConnectionsMessagesTests: XCTestCase {
    // MARK: - The body batch

    private func addresses(_ reading: BodyEgressReading) -> [String] {
        ConnectionsOSC.bioMessages(for: reading).map(\.address)
    }

    func testABodyWithNothingMeasuredSaysNothingAtAll() {
        XCTAssertEqual(ConnectionsOSC.bioMessages(for: BodyEgressReading(source: .ble)), [], "no bare flag, no zero")
    }

    func testTheProvenanceFlagLeadsEveryBatchThatCarriesAValue() {
        let messages = ConnectionsOSC.bioMessages(for: BodyEgressReading(source: .ble, beatsPerMinute: 72))
        XCTAssertEqual(messages, [OSCMessage("/echoelmusic/bio/synthetic", [0]), OSCMessage("/echoelmusic/bio/heart/bpm", [72])])
    }

    func testHRVAndCoherenceRideOnAPulse() {
        let full = BodyEgressReading(source: .ble, beatsPerMinute: 64, hrv: 0.4, coherence: 0.9)
        XCTAssertEqual(addresses(full), ["/echoelmusic/bio/synthetic", "/echoelmusic/bio/heart/bpm",
                                         "/echoelmusic/bio/heart/hrv", "/echoelmusic/bio/coherence"])
        XCTAssertEqual(ConnectionsOSC.bioMessages(for: full)[2].floats, [0.4])
        XCTAssertEqual(ConnectionsOSC.bioMessages(for: full)[3].floats, [0.9])
        let noPulse = BodyEgressReading(source: .ble, beatsPerMinute: nil, hrv: 0.4, coherence: 0.9)
        XCTAssertEqual(addresses(noPulse), [], "a variability beside no pulse is a bug upstream, not a reading")
    }

    func testAnImplausibleOrBadValueIsAbsent() {
        XCTAssertEqual(addresses(BodyEgressReading(source: .ble, beatsPerMinute: 250)), [])
        XCTAssertEqual(addresses(BodyEgressReading(source: .ble, beatsPerMinute: .nan)), [])
        XCTAssertEqual(addresses(BodyEgressReading(source: .ble, beatsPerMinute: 70, hrv: 1.5)),
                       ["/echoelmusic/bio/synthetic", "/echoelmusic/bio/heart/bpm"])
        XCTAssertEqual(addresses(BodyEgressReading(source: .ble, beatsPerMinute: 70, coherence: -0.1)),
                       ["/echoelmusic/bio/synthetic", "/echoelmusic/bio/heart/bpm"])
    }

    func testTheBreathPhaseRidesTheRate() {
        let both = BodyEgressReading(source: .camera, breathRate: 12, breathPhase: 0.25)
        XCTAssertEqual(addresses(both), ["/echoelmusic/bio/synthetic", "/echoelmusic/bio/breath/rate", "/echoelmusic/bio/breath/phase"])
        XCTAssertEqual(addresses(BodyEgressReading(source: .camera, breathPhase: 0.25)), [], "a phase without a rate is not a breath")
        XCTAssertEqual(addresses(BodyEgressReading(source: .camera, breathRate: 1)), [], "nobody breathes once a minute")
        XCTAssertEqual(addresses(BodyEgressReading(source: .camera, breathRate: 12)),
                       ["/echoelmusic/bio/synthetic", "/echoelmusic/bio/breath/rate"], "a rate without a waveform sends no phase")
    }

    func testEveryBodyAddressTheBuilderCanSayIsClassified() {
        let everything = BodyEgressReading(source: .ble, beatsPerMinute: 60, hrv: 0.5, coherence: 0.5, breathRate: 10, breathPhase: 0.5)
        for message in ConnectionsOSC.bioMessages(for: everything) {
            XCTAssertEqual(BioEgressPolicy.fieldClass(ofOSCAddress: message.address), .derived, message.address)
            XCTAssertTrue(BioEgressPolicy.carriesBody(address: message.address), message.address)
        }
    }

    // MARK: - The song batch

    func testTheSongBatchNamesTempoKeyBeatAndLevel() {
        let messages = ConnectionsOSC.musicMessages(tempo: 120, root: 7, beatPhase: 0.25, masterLevel: 0.5)
        XCTAssertEqual(messages, [
            OSCMessage("/echoelmusic/music/tempo", [120]),
            OSCMessage("/echoelmusic/music/key/root", [7]),
            OSCMessage("/echoelmusic/music/beat/phase", [0.25]),
            OSCMessage("/echoelmusic/music/level/master", [0.5]),
        ])
        for message in messages {
            XCTAssertTrue(BioEgressPolicy.allowsEgress(address: message.address, source: nil, consent: .off), message.address)
        }
    }

    func testTheSongBatchHoldsItsValuesToTheirRanges() {
        let messages = ConnectionsOSC.musicMessages(tempo: .nan, root: -1, beatPhase: 1.5, masterLevel: 2)
        XCTAssertEqual(messages[0].floats, [0], "no tempo reads as stopped")
        XCTAssertEqual(messages[1].floats, [11], "a root below C wraps to B")
        XCTAssertEqual(messages[2].floats, [1])
        XCTAssertEqual(messages[3].floats, [1], "a clipping mix reads as full scale, not as silence")
    }

    // MARK: - ADM-OSC objects

    func testATrackIsAnObjectOnTheHorizonAtTheReferenceDistance() {
        let left = ADMObject.track(index: 1, pan: -1, level: 0.5)
        XCTAssertEqual(left, ADMObject(index: 1, azimuth: 90, elevation: 0, distance: 1, gain: 0.5), "hard left is +90°: the standard counts left positive")
        XCTAssertEqual(ADMObject.track(index: 2, pan: 1, level: 1).azimuth, -90)
        XCTAssertEqual(ADMObject.track(index: 3, pan: 0, level: 0).azimuth, 0)
        XCTAssertEqual(ADMObject.track(index: 4, pan: -0.5, level: 0).azimuth, 45)
        XCTAssertEqual(ADMObject.track(index: 0, pan: 0, level: 0).index, 1, "the standard has no object 0")
        XCTAssertEqual(ADMObject.track(index: 1, pan: .nan, level: .infinity), ADMObject(index: 1, azimuth: 0, elevation: 0, distance: 1, gain: 0))
    }

    func testAnObjectSendsItsPositionPackedThenItsGain() {
        let object = ADMObject.track(index: 12, pan: 0.5, level: 0.25)
        XCTAssertEqual(object.positionMessage, OSCMessage("/adm/obj/12/aed", [-45, 0, 1]))
        XCTAssertEqual(object.gainMessage, OSCMessage("/adm/obj/12/gain", [0.25]))
        XCTAssertEqual(object.messages, [object.positionMessage, object.gainMessage])
        XCTAssertTrue(object.hasSamePosition(as: ADMObject.track(index: 12, pan: 0.5, level: 0.9)), "a louder object has not moved")
        XCTAssertFalse(object.hasSamePosition(as: ADMObject.track(index: 12, pan: 0.6, level: 0.25)))
        XCTAssertFalse(object.hasSamePosition(as: ADMObject.track(index: 13, pan: 0.5, level: 0.25)), "another object, another place")
    }

    func testAnObjectIsHeldToTheStandardsRanges() {
        let object = ADMObject(index: 5, azimuth: 400, elevation: -100, distance: 3, gain: 1.5)
        XCTAssertEqual(object, ADMObject(index: 5, azimuth: 180, elevation: -90, distance: 1, gain: 1))
    }

    // MARK: - The light

    /// Component-wise, within floating-point noise: a hue of 2/3 lands on blue with a green of
    /// a few ulps, which the wire rounds away.
    private func assertLook(_ look: LightFixture.Look, _ dimmer: Double, _ red: Double, _ green: Double, _ blue: Double,
                            _ message: String = "", line: UInt = #line) {
        XCTAssertEqual(look.dimmer, dimmer, accuracy: 1e-9, "dimmer: " + message, line: line)
        XCTAssertEqual(look.red, red, accuracy: 1e-9, "red: " + message, line: line)
        XCTAssertEqual(look.green, green, accuracy: 1e-9, "green: " + message, line: line)
        XCTAssertEqual(look.blue, blue, accuracy: 1e-9, "blue: " + message, line: line)
    }

    func testTheLightRestsAtItsFloorInTheKeysColour() {
        let stopped = FieldFrame(keyHue: 0, level: 0.8, isPlaying: false)
        assertLook(LightFixture.look(for: stopped, sharesBody: false), 0.2, 1, 0, 0, "C is red; a stopped song adds nothing")
    }

    func testTheLevelAndTheBeatLightTheSong() {
        let loud = FieldFrame(beatPhase: 0, keyHue: 1.0 / 3, level: 1, isPlaying: true)
        assertLook(LightFixture.look(for: loud, sharesBody: false), 1, 0, 1, 0, "full level on the beat is full brightness")
        let lateInTheBeat = FieldFrame(beatPhase: 0.5, keyHue: 2.0 / 3, level: 0.5, isPlaying: true)
        assertLook(LightFixture.look(for: lateInTheBeat, sharesBody: false), 0.2 + 0.3 + 0.1, 0, 0, 1)
    }

    func testTheBodyReachesTheLampOnlyWhenShared() {
        let coherent = FieldFrame(coherence: 1, isPlaying: false)
        XCTAssertEqual(LightFixture.look(for: coherent, sharesBody: true).dimmer, 0.7, accuracy: 1e-12, "coherence lifts the floor")
        XCTAssertEqual(LightFixture.look(for: coherent, sharesBody: false).dimmer, 0.2, "unshared, the body is not read")
        XCTAssertEqual(LightFixture.look(for: FieldFrame(isPlaying: false), sharesBody: true).dimmer, 0.2, "unmeasured, there is nothing to lift")
    }

    func testTheColourWheelIsSaturatedAndWraps() {
        let wheel: [(hue: Double, red: Double, green: Double, blue: Double)] = [
            (0, 1, 0, 0), (1.0 / 6, 1, 1, 0), (1.0 / 3, 0, 1, 0), (0.5, 0, 1, 1), (2.0 / 3, 0, 0, 1), (5.0 / 6, 1, 0, 1), (1, 1, 0, 0),
        ]
        for stop in wheel {
            let colour = LightFixture.rgb(hue: stop.hue)
            XCTAssertEqual(colour.red, stop.red, accuracy: 1e-9, "hue \(stop.hue)")
            XCTAssertEqual(colour.green, stop.green, accuracy: 1e-9, "hue \(stop.hue)")
            XCTAssertEqual(colour.blue, stop.blue, accuracy: 1e-9, "hue \(stop.hue)")
        }
    }

    func testTheChannelsAreDimmerThenRGBFromTheStartSlot() {
        let look = LightFixture.Look(dimmer: 1, red: 1, green: 0.5, blue: 0)
        XCTAssertEqual(LightFixture.channels(look, resolution: .eightBit), [255, 255, 128, 0])
        XCTAssertEqual(LightFixture.channels(look, resolution: .sixteenBit), [0xFF, 0xFF, 0xFF, 0xFF, 0x80, 0x00, 0x00, 0x00], "coarse then fine")
        XCTAssertEqual(LightFixture.channels(look, resolution: .eightBit, startChannel: 3), [0, 0, 255, 255, 128, 0])
        XCTAssertEqual(LightFixture.channels(look, resolution: .sixteenBit, startChannel: 512).count, 512, "never past the universe")
        XCTAssertEqual(LightFixture.channels(look, resolution: .eightBit, startChannel: -4), [255, 255, 128, 0])
        XCTAssertEqual(LightFixture.Resolution.eightBit.channelCount, 4)
        XCTAssertEqual(LightFixture.Resolution.sixteenBit.channelCount, 8)
    }

    func testALookHoldsItsValuesToUnit() {
        XCTAssertEqual(LightFixture.Look(dimmer: 2, red: -1, green: .nan, blue: 0.5), LightFixture.Look(dimmer: 1, red: 0, green: 0, blue: 0.5))
    }

    func testTheSlewNeverOutrunsTheFlashGuard() {
        var slew = LightSlew()
        let step = slew.next(towards: LightFixture.Look(dimmer: 1, red: 1, green: 1, blue: 1), after: 0.5)
        XCTAssertEqual(step.dimmer, FlashLimit.maximumRate * 0.5, accuracy: 1e-12)
        XCTAssertEqual(step.red, FlashLimit.maximumRate * 0.5, accuracy: 1e-12)
        XCTAssertEqual(slew.current, step)
        var settled = LightSlew()
        for _ in 0..<60 { _ = settled.next(towards: LightFixture.Look(dimmer: 0.4, red: 0.2, green: 0.2, blue: 0.2), after: 0.1) }
        assertLook(settled.current, 0.4, 0.2, 0.2, 0.2, "a steady look arrives")
    }
}
