import XCTest
@testable import EchoelCore

/// Network MIDI lets in only the hosts it knows: nobody while off, the contact list while on, and
/// whoever is connected when it is switched on joins that list rather than being cut off.
final class NetworkMIDIAccessTests: XCTestCase {
    private typealias Host = NetworkMIDIAccess.Host

    func testOffLetsNobodyInAndOnOnlyTheContacts() {
        XCTAssertEqual(NetworkMIDIAccess.policy(networkOn: false), .noOne)
        XCTAssertEqual(NetworkMIDIAccess.policy(networkOn: true), .contactsOnly)
    }

    func testOnlyAPairingWindowLetsANewHostIn() {
        XCTAssertEqual(NetworkMIDIAccess.policy(networkOn: true, pairing: true), .anyone)
        XCTAssertEqual(NetworkMIDIAccess.policy(networkOn: true, pairing: false), .contactsOnly)
        XCTAssertEqual(NetworkMIDIAccess.policy(networkOn: false, pairing: true), .noOne,
                       "pairing never opens a session that is off")
    }

    func testTheSameAddressAndPortIsTheSameHost() {
        let mac = Host(name: "Studio Mac", address: "192.168.1.20", port: 5004)
        XCTAssertTrue(mac.isSame(as: Host(name: "renamed", address: " 192.168.1.20 ", port: 5004)))
        XCTAssertFalse(mac.isSame(as: Host(name: "Studio Mac", address: "192.168.1.20", port: 5006)),
                       "another port is another session")
        XCTAssertFalse(mac.isSame(as: Host(name: "Studio Mac", address: "192.168.1.21", port: 5004)),
                       "a name is not an identity")
    }

    func testABonjourHostIsKnownByItsServiceName() {
        let found = Host(name: "iPad", address: "", port: 0, service: "Echoel iPad")
        XCTAssertTrue(found.isSame(as: Host(name: "x", address: "", port: 0, service: "echoel ipad")))
        XCTAssertFalse(found.isSame(as: Host(name: "iPad", address: "", port: 0, service: "Other")))
        let blank = Host(name: "nobody", address: "", port: 0)
        XCTAssertFalse(blank.isSame(as: blank), "a host with nothing to match is never matched")
    }

    func testWhoIsConnectedJoinsTheContactsOnceBeforeTheDoorNarrows() {
        let known = Host(name: "Mac", address: "10.0.0.2", port: 5004)
        let connected = [
            Host(name: "Mac", address: "10.0.0.2", port: 5004),
            Host(name: "PC", address: "10.0.0.3", port: 5004),
            Host(name: "PC again", address: "10.0.0.3", port: 5004),
            Host(name: "nothing to match", address: "", port: 0),
            Host(name: "iPad", address: "", port: 0, service: "iPad"),
        ]
        XCTAssertEqual(NetworkMIDIAccess.contactsToAdd(connected: connected, contacts: [known]), [1, 4])
        XCTAssertEqual(NetworkMIDIAccess.contactsToAdd(connected: [], contacts: [known]), [])
        XCTAssertEqual(NetworkMIDIAccess.contactsToAdd(connected: [known], contacts: []), [0])
    }

    func testAHostIsShownByItsNameElseWhereItIs() {
        XCTAssertEqual(Host(name: " Studio Mac ", address: "10.0.0.2", port: 5004).title, "Studio Mac")
        XCTAssertEqual(Host(name: "", address: "10.0.0.2", port: 5004).title, "10.0.0.2:5004")
        XCTAssertEqual(Host(name: "", address: "10.0.0.2", port: 0).title, "10.0.0.2")
        XCTAssertEqual(Host(name: "", address: "", port: 0, service: "iPad").title, "iPad")
        XCTAssertEqual(Host(name: "", address: "", port: 0).title, "Unnamed host")
    }
}
