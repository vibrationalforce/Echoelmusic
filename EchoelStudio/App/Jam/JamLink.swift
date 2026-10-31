import Darwin
import EchoelEngine
import Foundation
// `@preconcurrency`: MultipeerConnectivity predates Swift concurrency and its objects are not
// Sendable. They never leave this file: the link keeps them under its lock and hands the main actor
// only Sendable values (`Event`).
@preconcurrency import MultipeerConnectivity

/// Seconds on this phone's monotonic clock — the clock the audio's host times count in
/// (`mach_absolute_time`), so a jam's anchors and the engine's heard position share one time base.
enum JamTime {
    private static let timebase: (numer: UInt32, denom: UInt32) = {
        var info = mach_timebase_info_data_t()
        mach_timebase_info(&info)
        return (Swift.max(info.numer, 1), Swift.max(info.denom, 1))
    }()

    static func now() -> Double {
        seconds(mach_absolute_time())
    }

    static func seconds(_ hostTime: UInt64) -> Double {
        Double(hostTime) * Double(timebase.numer) / Double(timebase.denom) / 1e9
    }
}

/// The jam's link to the phones nearby (W16): Apple's MultipeerConnectivity — peer-to-peer Wi-Fi
/// or Bluetooth, no router, no internet, no server of ours, encrypted — and the one place in Echoel
/// Studio that opens it (CLAUDE.md law 10; `studio.yml`'s "Network only where named" lists this
/// file). It exists only while the musician hosts or joins a jam, and `close()` ends every
/// connection. It moves the small `JamMessage`s and nothing else, and it answers a guest's ping on
/// the spot, on the link's own queue, so the round trip measures the network and not how busy the
/// screen is (the earlier app's link probes learned the same). It decides nothing: `JamSession`
/// hosts and follows.
final class JamLink: NSObject, @unchecked Sendable {
    /// What the link reports, on its own queue; the receiver hops to the main actor.
    enum Event: Sendable {
        /// A jam nearby, while looking.
        case found(JamPeer)
        case lost(JamPeer)
        case connected(JamPeer)
        case disconnected(JamPeer)
        /// A message, with when it arrived on this phone's clock (`JamTime`).
        case received(JamMessage, from: JamPeer, at: Double)
        /// A phone with a newer Echoel, whose messages this one does not read.
        case newer(JamPeer)
        /// The system would not let this phone be found or look (local network access).
        case refused(any Error)
    }

    /// A session holds eight phones, this one included.
    static let maximumGuests = 7
    /// How long a host has to take this phone in.
    static let joinTimeout: TimeInterval = 15

    private let me: MCPeerID
    private let session: MCSession
    private let onEvent: @Sendable (Event) -> Void
    private let lock = NSLock()
    // Guarded by `lock`.
    private var advertiser: MCNearbyServiceAdvertiser?
    private var browser: MCNearbyServiceBrowser?
    private var nearby: [String: MCPeerID] = [:]
    private var hosting = false

    /// `linkName`: `JamPeer.linkName`, which keeps it within what the link takes.
    init(linkName: String, onEvent: @escaping @Sendable (Event) -> Void) {
        let peer = MCPeerID(displayName: linkName)
        me = peer
        session = MCSession(peer: peer, securityIdentity: nil, encryptionPreference: .required)
        self.onEvent = onEvent
        super.init()
        session.delegate = self
    }

    /// Other phones can find this one and join it; each that asks is taken while there is room.
    func host() {
        let advertiser = MCNearbyServiceAdvertiser(peer: me, discoveryInfo: ["v": String(JamProtocol.version)],
                                                   serviceType: JamProtocol.serviceType)
        advertiser.delegate = self
        let previous = lock.withLock { () -> MCNearbyServiceAdvertiser? in
            let previous = self.advertiser
            self.advertiser = advertiser
            self.hosting = true
            return previous
        }
        previous?.stopAdvertisingPeer()
        advertiser.startAdvertisingPeer()
    }

    /// Looks for jams nearby.
    func browse() {
        let browser = MCNearbyServiceBrowser(peer: me, serviceType: JamProtocol.serviceType)
        browser.delegate = self
        let previous = lock.withLock { () -> MCNearbyServiceBrowser? in
            let previous = self.browser
            self.browser = browser
            self.nearby = [:]
            return previous
        }
        previous?.stopBrowsingForPeers()
        browser.startBrowsingForPeers()
    }

    /// Stops looking: joined, or the search was given up.
    func stopBrowsing() {
        let previous = lock.withLock { () -> MCNearbyServiceBrowser? in
            let previous = self.browser
            self.browser = nil
            self.nearby = [:]
            return previous
        }
        previous?.stopBrowsingForPeers()
    }

    /// Asks a host found nearby to take this phone in. False when it is no longer found.
    func join(_ host: JamPeer) -> Bool {
        let found = lock.withLock { () -> (browser: MCNearbyServiceBrowser, peer: MCPeerID)? in
            guard let browser = self.browser, let peer = self.nearby[host.id] else { return nil }
            return (browser: browser, peer: peer)
        }
        guard let found else { return false }
        found.browser.invitePeer(found.peer, to: session, withContext: nil, timeout: Self.joinTimeout)
        return true
    }

    /// Sends to everyone connected: the host's guests, or a guest's host. A ping goes unreliably —
    /// a lost one is worth nothing a moment later; the rest reliably and in order.
    func send(_ message: JamMessage, reliably: Bool) {
        let peers = session.connectedPeers
        guard !peers.isEmpty, let data = message.encoded() else { return }
        try? session.send(data, toPeers: peers, with: reliably ? .reliable : .unreliable)
    }

    /// Ends every connection and stops being found or looking. The link is done; a new jam is a
    /// new link.
    func close() {
        let (advertiser, browser) = lock.withLock { () -> (MCNearbyServiceAdvertiser?, MCNearbyServiceBrowser?) in
            let pair = (self.advertiser, self.browser)
            self.advertiser = nil
            self.browser = nil
            self.nearby = [:]
            self.hosting = false
            return pair
        }
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        session.disconnect()
    }

    /// A ping is answered here, on the link's queue, before any hop to the main thread.
    private func answer(_ ping: JamPing, arrived: Double, to peerID: MCPeerID) {
        let pong = JamPong(id: ping.id, guestSentAt: ping.sentAt, hostReceivedAt: arrived, hostSentAt: JamTime.now())
        guard let reply = JamMessage(pong: pong).encoded() else { return }
        try? session.send(reply, toPeers: [peerID], with: .unreliable)
    }
}

// MARK: - MultipeerConnectivity (delivered on the link's own queue, never the main actor)

extension JamLink: MCSessionDelegate {
    func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let peer = JamPeer(linkName: peerID.displayName)
        switch state {
        case .connected: onEvent(.connected(peer))
        case .notConnected: onEvent(.disconnected(peer))
        case .connecting: break
        @unknown default: break
        }
    }

    func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // Stamped first, before anything is read: the arrival is a measurement.
        let arrived = JamTime.now()
        let peer = JamPeer(linkName: peerID.displayName)
        switch JamMessage.decode(data) {
        case .message(let message):
            if message.kind == .ping, let ping = message.ping {
                answer(ping, arrived: arrived, to: peerID)
            } else {
                onEvent(.received(message, from: peer, at: arrived))
            }
        case .newerVersion:
            onEvent(.newer(peer))
        case .unreadable:
            break
        }
    }

    func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String,
                 fromPeer peerID: MCPeerID) {}

    func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, with progress: Progress) {}

    func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String,
                 fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}

    /// Nobody shows an identity (the session is encrypted with MultipeerConnectivity's own keys);
    /// without this answer a connection can stall before it is made.
    func session(_ session: MCSession, didReceiveCertificate certificate: [Any]?, fromPeer peerID: MCPeerID,
                 certificateHandler: @escaping (Bool) -> Void) {
        certificateHandler(true)
    }
}

extension JamLink: MCNearbyServiceAdvertiserDelegate {
    /// A host takes every phone that asks while it hosts and there is room: a jam carries only
    /// timing — tempo, time signature, Play and Stop, where the bars begin — and names, never audio,
    /// a song or a body value (v1), and the musician chose Host a Jam to let the room in.
    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didReceiveInvitationFromPeer peerID: MCPeerID,
                    withContext context: Data?, invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        let open = lock.withLock { self.hosting }
        let room = open && session.connectedPeers.count < Self.maximumGuests
        invitationHandler(room, room ? session : nil)
    }

    func advertiser(_ advertiser: MCNearbyServiceAdvertiser, didNotStartAdvertisingPeer error: Error) {
        onEvent(.refused(error))
    }
}

extension JamLink: MCNearbyServiceBrowserDelegate {
    func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID,
                 withDiscoveryInfo info: [String: String]?) {
        let peer = JamPeer(linkName: peerID.displayName)
        lock.withLock { self.nearby[peer.id] = peerID }
        onEvent(.found(peer))
    }

    func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        let peer = JamPeer(linkName: peerID.displayName)
        lock.withLock { self.nearby[peer.id] = nil }
        onEvent(.lost(peer))
    }

    func browser(_ browser: MCNearbyServiceBrowser, didNotStartBrowsingForPeers error: Error) {
        onEvent(.refused(error))
    }
}
