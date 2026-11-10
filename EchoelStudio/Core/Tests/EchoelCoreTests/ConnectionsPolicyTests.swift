import XCTest
@testable import EchoelCore

/// Every decision of the egress policy, each failing closed: the source gate, the consent gate,
/// the field-class gate, and the composed answer the sender asks.
final class ConnectionsPolicyTests: XCTestCase {
    private let both = BioEgressPolicy.Consent(sharesBody: true, sharesClinicalDetail: true)
    private let bodyOnly = BioEgressPolicy.Consent(sharesBody: true)

    func testOnlyWhatEchoelMeasuresItselfMayLeave() {
        XCTAssertTrue(BioEgressPolicy.allowsEgress(.camera))
        XCTAssertTrue(BioEgressPolicy.allowsEgress(.ble))
        XCTAssertFalse(BioEgressPolicy.allowsEgress(.health), "Health-store data never leaves the device")
        // Recovery 9: the phone's own motion sensors are measured here, like the camera and the strap.
        XCTAssertTrue(BioEgressPolicy.allowsEgress(.motion))
    }

    /// Motion goes the camera's way: only with body sharing on, and only as a classified address.
    func testMotionNeedsBodySharingLikeTheCamera() {
        let motion = "/echoelmusic/bio/motion"
        for source in [BodyChannel.Source.camera, .motion] {
            XCTAssertFalse(BioEgressPolicy.allowsEgress(address: motion, source: source, consent: .off), "\(source)")
            XCTAssertTrue(BioEgressPolicy.allowsEgress(address: motion, source: source,
                                                       consent: BioEgressPolicy.Consent(sharesBody: true)), "\(source)")
        }
        XCTAssertFalse(BioEgressPolicy.allowsEgress(address: "/echoelmusic/bio/motion/tilt", source: .motion,
                                                    consent: BioEgressPolicy.Consent(sharesBody: true)),
                       "an address nobody classified stays silent")
    }

    func testEveryAddressHasOneClassOrNone() {
        XCTAssertEqual(BioEgressPolicy.fieldClass(ofOSCAddress: "/echoelmusic/bio/heart/rmssd"), .clinical)
        XCTAssertEqual(BioEgressPolicy.fieldClass(ofOSCAddress: "/echoelmusic/bio/heart/sdnn"), .clinical)
        XCTAssertEqual(BioEgressPolicy.fieldClass(ofOSCAddress: "/echoelmusic/bio/heart/pnn50"), .clinical)
        XCTAssertEqual(BioEgressPolicy.fieldClass(ofOSCAddress: "/echoelmusic/bio/heart/bpm"), .derived)
        XCTAssertEqual(BioEgressPolicy.fieldClass(ofOSCAddress: "/echoelmusic/bio/synthetic"), .derived)
        XCTAssertEqual(BioEgressPolicy.fieldClass(ofOSCAddress: "/echoelmusic/music/tempo"), .derived)
        XCTAssertEqual(BioEgressPolicy.fieldClass(ofOSCAddress: "/echoelmusic/bio/event/heartbeat"), .derived)
        XCTAssertEqual(BioEgressPolicy.fieldClass(ofOSCAddress: "/echoelmusic/mod/filter"), .derived)
        XCTAssertNil(BioEgressPolicy.fieldClass(ofOSCAddress: "/echoelmusic/bio/heart/waveform"), "unknown is unclassified")
        XCTAssertNil(BioEgressPolicy.fieldClass(ofOSCAddress: "/echoelmusic/music/scale"), "the music set is a set, not a prefix")
        XCTAssertNil(BioEgressPolicy.fieldClass(ofOSCAddress: "/adm/obj/1/aed"), "a foreign namespace is not classified here")
        for address in BioEgressPolicy.clinicalAddresses.union(BioEgressPolicy.derivedAddresses).union(BioEgressPolicy.musicAddresses) {
            XCTAssertNotNil(BioEgressPolicy.fieldClass(ofOSCAddress: address), address)
        }
    }

    func testTheRawClassHasNoSwitch() {
        XCTAssertFalse(BioEgressPolicy.allowsEgress(fieldClass: .raw, consent: both))
        XCTAssertTrue(BioEgressPolicy.allowsEgress(fieldClass: .derived, consent: .off))
        XCTAssertFalse(BioEgressPolicy.allowsEgress(fieldClass: .clinical, consent: bodyOnly))
        XCTAssertTrue(BioEgressPolicy.allowsEgress(fieldClass: .clinical, consent: both))
    }

    func testABodyAddressNeedsConsentAndAnAllowedSource() {
        let bpm = "/echoelmusic/bio/heart/bpm"
        XCTAssertTrue(BioEgressPolicy.allowsEgress(address: bpm, source: .ble, consent: bodyOnly))
        XCTAssertTrue(BioEgressPolicy.allowsEgress(address: bpm, source: .camera, consent: bodyOnly))
        XCTAssertFalse(BioEgressPolicy.allowsEgress(address: bpm, source: .ble, consent: .off), "off until the musician turns body sharing on")
        XCTAssertFalse(BioEgressPolicy.allowsEgress(address: bpm, source: .health, consent: both), "no consent reaches Health data")
        XCTAssertFalse(BioEgressPolicy.allowsEgress(address: bpm, source: nil, consent: both), "an unstamped reading is refused")
    }

    func testClinicalDetailNeedsItsOwnConsentOnTopOfBodySharing() {
        let rmssd = "/echoelmusic/bio/heart/rmssd"
        XCTAssertFalse(BioEgressPolicy.allowsEgress(address: rmssd, source: .ble, consent: bodyOnly))
        XCTAssertTrue(BioEgressPolicy.allowsEgress(address: rmssd, source: .ble, consent: both))
        XCTAssertFalse(BioEgressPolicy.allowsEgress(address: rmssd, source: .health, consent: both))
        XCTAssertFalse(BioEgressPolicy.allowsEgress(address: rmssd, source: .ble,
                                                    consent: BioEgressPolicy.Consent(sharesBody: false, sharesClinicalDetail: true)),
                       "clinical consent without body sharing shares nothing")
    }

    func testTheSongNeedsNoConsentAndTheUnknownNeverGoes() {
        for address in BioEgressPolicy.musicAddresses {
            XCTAssertTrue(BioEgressPolicy.allowsEgress(address: address, source: nil, consent: .off), address)
        }
        XCTAssertFalse(BioEgressPolicy.allowsEgress(address: "/echoelmusic/music/scale", source: .ble, consent: both))
        XCTAssertFalse(BioEgressPolicy.allowsEgress(address: "/echoelmusic/anything", source: .ble, consent: both))
    }

    func testAnEventOrAModulationTapIsBodyUntilProvenOtherwise() {
        XCTAssertTrue(BioEgressPolicy.carriesBody(address: "/echoelmusic/bio/event/heartbeat"))
        XCTAssertTrue(BioEgressPolicy.carriesBody(address: "/echoelmusic/mod/track.1.cutoff"))
        XCTAssertFalse(BioEgressPolicy.carriesBody(address: "/echoelmusic/music/tempo"))
        XCTAssertFalse(BioEgressPolicy.allowsEgress(address: "/echoelmusic/mod/track.1.cutoff", source: .ble, consent: .off))
        XCTAssertTrue(BioEgressPolicy.allowsEgress(address: "/echoelmusic/mod/track.1.cutoff", source: .ble, consent: bodyOnly))
        XCTAssertFalse(BioEgressPolicy.allowsEgress(address: "/echoelmusic/bio/event/heartbeat", source: .health, consent: both))
    }

    /// Pressure and slide on a MIDI output are a wire off the device like any other: a body source
    /// drives them only with body sharing on, and a source that is not the body's needs no consent.
    func testANotesExpressionFollowsTheBodyOnlyWithBodySharing() {
        let body: [ModulationSource] = [.breath, .coherence, .hrv, .heartRate, .motionTiltX, .motionEnergy]
        for source in body {
            XCTAssertFalse(BioEgressPolicy.allowsLeaving(of: source, consent: .off), source.rawValue)
            XCTAssertTrue(BioEgressPolicy.allowsLeaving(of: source, consent: bodyOnly), source.rawValue)
        }
        let song: [ModulationSource] = [.lfo1, .macro1, .midiCC1, .weave1]
        for source in song {
            XCTAssertTrue(BioEgressPolicy.allowsLeaving(of: source, consent: .off), "\(source.rawValue) is not the body")
        }
    }

    /// A tempo that follows the pulse stays on the device unless the musician shares the body:
    /// with a clock, a jam or OSC carrying the tempo away, Flow follows only with body sharing on.
    func testATempoThatLeavesFollowsThePulseOnlyWithBodySharing() {
        XCTAssertTrue(BioEgressPolicy.allowsFollowingThePulse(tempoLeaves: false, consent: .off), "on the device, always")
        XCTAssertTrue(BioEgressPolicy.allowsFollowingThePulse(tempoLeaves: false, consent: bodyOnly))
        XCTAssertFalse(BioEgressPolicy.allowsFollowingThePulse(tempoLeaves: true, consent: .off), "off the device, not unasked")
        XCTAssertTrue(BioEgressPolicy.allowsFollowingThePulse(tempoLeaves: true, consent: bodyOnly))
        let clinicalOnly = BioEgressPolicy.Consent(sharesBody: false, sharesClinicalDetail: true)
        XCTAssertFalse(BioEgressPolicy.allowsFollowingThePulse(tempoLeaves: true, consent: clinicalOnly),
                       "the detail switch alone shares nothing")
    }

    /// Every source is the body's or it is not, by its stored name — a source added later with a
    /// `body.` name needs consent without anyone listing it.
    func testASourceIsTheBodysByItsStoredName() {
        let body = Set(ModulationSource.allCases.filter { BioEgressPolicy.measuresBody($0) }.map(\.rawValue))
        let expected: Set<String> = ["body.heartRate", "body.hrv", "body.coherence", "body.breath",
                                     "body.motion.tiltX", "body.motion.tiltY", "body.motion.rotation", "body.motion.energy"]
        XCTAssertEqual(body, expected)
    }

    func testConsentStartsOff() {
        XCTAssertEqual(BioEgressPolicy.Consent(), .off)
        XCTAssertFalse(BioEgressPolicy.Consent.off.sharesBody)
        XCTAssertFalse(BioEgressPolicy.Consent.off.sharesClinicalDetail)
    }
}
