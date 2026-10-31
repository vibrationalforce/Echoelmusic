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

    func testConsentStartsOff() {
        XCTAssertEqual(BioEgressPolicy.Consent(), .off)
        XCTAssertFalse(BioEgressPolicy.Consent.off.sharesBody)
        XCTAssertFalse(BioEgressPolicy.Consent.off.sharesClinicalDetail)
    }
}
