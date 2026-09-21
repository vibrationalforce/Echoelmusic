// MultipeerSession.swift
// Echoel — Live Colabo (nearby, peer-to-peer). The DMMW "Live Collaboration"
// pillar's first concrete capability: two phones on the same Wi-Fi/AWDL find each
// other and SHARE a full session (the Codable Project — style·key·tempo·patch·
// notes·drums) with one tap, so collaborators can jam off the same starting point.
//
// Apple's MultipeerConnectivity only — NO external dependency. Real-time tempo/
// phase lock (Ableton Link) is a separate, device-verified step; this is the
// dependency-free, fully-buildable foundation.
//
// Concurrency (mirrors MIDIInput): an @MainActor @Observable class whose MC
// delegate methods are `nonisolated` (MC calls them off-main) and hop back via
// `Task { @MainActor [weak self] in }`. MCPeerID is not Sendable, so it crosses
// the hop inside an explicit @unchecked Sendable box. MCSession/MCPeerID are
// created once and held as immutable `nonisolated let` (MCSession is internally
// thread-safe for send/connectedPeers), so the off-main invitation handler is safe.

#if canImport(MultipeerConnectivity)
import Foundation
import Observation
// @preconcurrency: MultipeerConnectivity's delegate types (MCSession/MCPeerID/…) are
// not Sendability-audited; this suppresses the cross-actor Sendable warnings on the
// nonisolated delegate hops under -strict-concurrency=complete + -warnings-as-errors
// (same as PolarH10BioPublisher's `@preconcurrency import CoreBluetooth`).
@preconcurrency import MultipeerConnectivity
#if canImport(UIKit)
import UIKit
#endif

/// Ferries a non-Sendable reference (MCPeerID) across an actor hop. Safe because
/// MCPeerID is immutable and only used on the main actor after the hop.
private struct UncheckedBox<T>: @unchecked Sendable { let value: T }

/// A peer the browser has found and we could invite.
///
/// ⛔ `name` USED TO BE `{ id }` — one value wearing two hats, and that was the #1435 defect
/// in miniature: the list key and the label a human reads were literally the same string, so
/// two phones advertising the identical device name collapsed into ONE row. They are now two
/// stored fields, and the key is the peer's `PeerIdentity.stableID`.
public struct DiscoveredPeer: Identifiable, Equatable, Sendable {
    public let id: String            // PeerIdentity.stableID — the KEY, never shown
    public let name: String          // PeerIdentity.displayName — shown, never keyed on
}

/// An incoming invitation awaiting the user's EXPLICIT consent. Never auto-accepted
/// (App Store audit 2026-07-16, 5.1.1/5.1.2): while colab is live the user may be
/// sharing live bio readings — WHO receives them is the user's call, not any nearby
/// device's. `respond` wraps MC's invitationHandler; call it exactly once.
public struct PendingInvitation: Identifiable {
    public let id = UUID()
    public let peerName: String
    let respond: (Bool) -> Void
}

@MainActor
@Observable
public final class MultipeerSession: NSObject {

    /// ≤15 chars, lowercase letters/digits/hyphens (MC requirement). "echoel-colab" = 12.
    public static let serviceType = "echoel-colab"

    // MARK: - Observed state
    public private(set) var isLive = false
    /// Everyone currently connected, keyed apart from how they are labelled (#1435).
    public private(set) var connectedPeers: [PeerIdentity] = []
    /// The labels only. Kept as a computed projection so the several `.isEmpty` readers in
    /// `LiveColaboView` stay exactly as they were; it must NEVER become the key again, which
    /// is the whole point of `connectedPeers` sitting beside it.
    public var connectedPeerNames: [String] { connectedPeers.map(\.displayName) }
    public private(set) var discovered: [DiscoveredPeer] = []
    /// Set when a peer sends us a session — the UI offers to load/import it.
    public private(set) var incoming: ColabPayload?
    /// Set when a nearby device asks to join — the UI shows an Accept/Decline
    /// card; nothing connects until the user answers (never auto-accepted).
    public private(set) var pendingInvitation: PendingInvitation?
    /// Last status line for the UI (e.g. "Shared with 2 peers").
    public private(set) var status: String = "Off"
    /// Live bio per connected peer (E5): `PeerIdentity.stableID` → last reading AND when it
    /// arrived here. Shown SIDE BY SIDE with our own — never combined into a
    /// cross-person score (decision 2026-06-20). Cleared on disconnect/stop.
    /// Updates arrive at the sender's ~2.5 Hz — read this only in leaf views
    /// (render safety).
    ///
    /// ⚠️ IT IS `PeerReading` AND NOT `BioPeek` ON PURPOSE (#508). A bare peek has no
    /// time on it, so every reader would have to invent its own answer to "is this peer
    /// still sending?" — and the honest answer is not derivable from the numbers. Ask
    /// `PeerReading.live(at:)`; never render `.peek` directly. That one substitution is
    /// what keeps a pocketed phone from showing a perfectly steady pulse on someone
    /// else's screen for the rest of the session.
    ///
    /// ⛔ THE KEY IS THE STABLE ID SINCE #1435, NOT THE DISPLAY NAME. Two phones that both
    /// advertise "iPhone" — the default on iOS 16+ without the user-assigned-device-name
    /// entitlement, which this app does not declare — wrote into ONE entry here and mixed two
    /// bodies into a single reading. Ask `displayName(forPeer:)` for the label; never render a
    /// key.
    public private(set) var peerReadings: [String: PeerReading] = [:]

    /// Called when a session payload arrives (e.g. import into the library / load live).
    public var onReceiveSession: ((ColabPayload) -> Void)?

    // MARK: - MC objects (immutable references; MCSession is internally thread-safe)
    // MCSession/MCPeerID are NOT Sendable, so a plain `nonisolated let` is illegal.
    // The reference is immutable and only the off-main advertiser invitation handler
    // touches `mcSession` (a thread-safe MC call), so `nonisolated(unsafe)` is correct.
    private let myPeerID: MCPeerID
    private nonisolated(unsafe) let mcSession: MCSession

    @ObservationIgnored private var advertiser: MCNearbyServiceAdvertiser?
    @ObservationIgnored private var browser: MCNearbyServiceBrowser?
    /// `PeerIdentity.stableID` → MCPeerID, so the UI can invite by identity (MainActor-only).
    @ObservationIgnored private var peerIDs: [String: MCPeerID] = [:]
    /// This installation's own identity — the thing `myPeerID` spells for the transport, and
    /// the source of the `senderName` every payload carries.
    @ObservationIgnored private let identity: PeerIdentity

    public override init() {
        // @MainActor init, so UIDevice (MainActor API) is directly accessible.
        #if canImport(UIKit)
        let raw = UIDevice.current.name
        #else
        let raw = ProcessInfo.processInfo.hostName
        #endif
        // ⭐ THE ADVERTISED STRING IS NO LONGER THE DEVICE NAME (#1435). It is
        // `PeerIdentity.transportName` — label, separator, stable key — so two phones with the
        // same device name are two peers on the wire. It can never be empty (the key never is),
        // which also retires the old `"Echoelmusic"` guard against MCPeerID's empty-name trap.
        let me = PeerIdentity.local(defaults: .standard,
                                    fallbackName: raw.isEmpty ? "Echoelmusic" : raw)
        self.identity = me
        let id = MCPeerID(displayName: me.transportName)
        self.myPeerID = id
        self.mcSession = MCSession(peer: id, securityIdentity: nil, encryptionPreference: .required)
        super.init()
        self.mcSession.delegate = self
    }

    // MARK: - Lifecycle

    /// Begin advertising AND browsing so any two Echoel devices discover each other.
    public func start() {
        guard !isLive else { return }
        let adv = MCNearbyServiceAdvertiser(peer: myPeerID, discoveryInfo: nil, serviceType: Self.serviceType)
        adv.delegate = self
        let br = MCNearbyServiceBrowser(peer: myPeerID, serviceType: Self.serviceType)
        br.delegate = self
        advertiser = adv
        browser = br
        adv.startAdvertisingPeer()
        br.startBrowsingForPeers()
        isLive = true
        status = "Looking for nearby Echoelmusic…"
    }

    public func stop() {
        // Never leave an MC invitation handler dangling — decline it so the
        // inviter gets an answer instead of a 20 s timeout.
        pendingInvitation?.respond(false)
        pendingInvitation = nil
        advertiser?.stopAdvertisingPeer()
        browser?.stopBrowsingForPeers()
        advertiser = nil
        browser = nil
        mcSession.disconnect()
        isLive = false
        discovered.removeAll()
        peerIDs.removeAll()
        connectedPeers.removeAll()
        peerReadings.removeAll()
        status = "Off"
    }

    /// Invite a discovered peer into the session, BY IDENTITY.
    ///
    /// ⚠️ The parameter is `DiscoveredPeer.id` (a `PeerIdentity.stableID`), never `.name`
    /// (#1435). Inviting by label picked an arbitrary one of two identically-named phones.
    public func invite(_ stableID: String) {
        guard let peer = peerIDs[stableID], let browser else { return }
        let label = discovered.first { $0.id == stableID }?.name ?? stableID
        browser.invitePeer(peer, to: mcSession, withContext: nil, timeout: 20)
        status = "Inviting \(label)…"
    }

    /// The label for a peer key — the one place a `stableID` is turned back into something a
    /// person reads. Falls back to the key itself, which is only reachable for a reading that
    /// arrived before the connection state did.
    public func displayName(forPeer stableID: String) -> String {
        connectedPeers.first { $0.stableID == stableID }?.displayName
            ?? discovered.first { $0.id == stableID }?.name
            ?? stableID
    }

    /// Send a whole session to every connected peer.
    ///
    /// ⛔ WHY THE ENCODE BRANCH REPORTS (#518). This method had THREE exits and only
    /// TWO of them said anything: "No peers connected", "Share failed" — and a bare
    /// `return` when the payload would not encode. The user taps "Share current
    /// session" and the button visibly does nothing.
    ///
    /// ⭐ THE SILENT ONE IS THE ONLY ONE AN ORDINARY TAP CAN REACH, which is why this
    /// is not merely an asymmetry. `LiveColaboView.shareButton` is
    /// `.disabled(colab.connectedPeerNames.isEmpty)`, so the peers branch is
    /// pre-empted by the UI in every case except a race (our mirrored name list vs
    /// `mcSession.connectedPeers`, which are two different sources and can diverge for
    /// an instant). The transport branch needs the send itself to throw. **The encode
    /// branch needs only a NaN**, and `JSONEncoder`'s default
    /// `nonConformingFloatEncodingStrategy` is `.throw` — while `Project` carries
    /// `bpm`, `a4Hz`, a whole `SynthPatch`, every `Note`, and since #217 a whole
    /// `RawTake` through exactly this encoder.
    ///
    /// ⭐ ONE DEFECT, TWO DOORS, ONE FIXED UNTIL NOW. #514 gave the SAVE path a voice
    /// for this exact failure on this exact type (`AppGroupStore.save`, whose own note
    /// says the error's `codingPath` names the field). The SHARE path put the same
    /// `Project` through the same class of encoder and stayed mute. #512 closed the
    /// third door, for `BioPeek` on the bio stream.
    ///
    /// ⚠️ THE STATUS LINE IS THE SCREEN HERE, and that is the difference from #514/#515.
    /// A failed save has no surface of its own — whether it should get one is a founder
    /// question. This method already writes `status` on its two other exits and
    /// `LiveColaboView` already renders it, so the honest thing is simply to use the
    /// surface that exists. The wording must not read as "try again": a re-tap re-encodes
    /// the same project and fails identically, so it names the SESSION, not the network.
    ///
    /// ⚠️ AND THE LOG LINE IS NOT THE SCREEN. `log.log` goes to `os_log`, NOT to
    /// the diag log, which is what the reachable "Diagnostics" row renders
    /// (`EchoelCrashLog.diagnosticsExport()` since #916; it was `currentLog()` before). So the status text deliberately does not send anyone to Diagnostics;
    /// the log is a telemetry floor for a sysdiagnose, exactly as in #514.
    public func share(project: Project) {
        // ⚠️ `identity.displayName`, NOT `myPeerID.displayName` (#1435) — the latter is now the
        // TRANSPORT spelling and would put a separator and a UUID into a human-facing line.
        let payload = ColabPayload(kind: "session", senderName: identity.displayName, project: project)
        let data: Data
        do {
            data = try payload.encodedThrowing()
        } catch {
            log.log(.error, category: .system,
                    "Colab: session payload failed to ENCODE — not shared — \(error)")
            status = "This session can't be encoded — not shared"
            return
        }
        let peers = mcSession.connectedPeers
        guard !peers.isEmpty else { status = "No peers connected"; return }
        do {
            try mcSession.send(data, toPeers: peers, with: .reliable)
            status = "Shared with \(peers.count) peer\(peers.count == 1 ? "" : "s")"
        } catch {
            status = "Share failed"
        }
    }

    /// Clear the incoming-session prompt after the UI handles it.
    public func clearIncoming() { incoming = nil }

    /// The user's answer to the pending join request. Responds to MC exactly
    /// once and clears the card; a no-op when nothing is pending.
    public func respondToInvitation(accept: Bool) {
        guard let pending = pendingInvitation else { return }
        pendingInvitation = nil
        pending.respond(accept)
        if accept {
            status = "Joining \(pending.peerName)…"
        } else if isLive {
            status = connectedPeerNames.isEmpty ? "Looking for nearby Echoelmusic…" : status
        }
    }

    /// Surface an invitation for explicit consent. One at a time: a newer
    /// invitation DECLINES the previous pending one (an unanswered MC handler
    /// would dangle into the inviter's timeout). Internal for tests.
    func handleInvitation(from name: String, respond: @escaping (Bool) -> Void) {
        pendingInvitation?.respond(false)
        pendingInvitation = PendingInvitation(peerName: name, respond: respond)
        status = "\(name) wants to join"
    }

    /// Stream one live bio reading to every connected peer (E5). Unreliable
    /// transport by design — a lost telemetry frame is worthless a moment later;
    /// never let it queue behind a session transfer. The cadence is
    /// `PeerReading.sendInterval`, and the receiver's staleness window is derived
    /// from it (#508), so a drop is expected and a silence is meaningful.
    ///
    /// ⛔ THIS TOOK A `BioPeek` UNTIL #511, and that is why the App Store 5.1.3 egress
    /// gate could only live at the CALL SITE: a peek carries no source, so this method
    /// had nothing to check. The note that stood here registered the fix and named its
    /// price ("moving it would need this signature to take the frame rather than the
    /// peek"); it is paid. Taking the FRAME means the rule is applied by the thing that
    /// sends, not by whoever remembers — and `BioPeek.egressible(from:)` is the one
    /// place that decides it, calling `BioEgressPolicy` rather than restating it (#186).
    ///
    /// ⚠️ Do NOT add a `sendBio(_ peek: BioPeek)` overload back "for convenience". The
    /// whole point is that a peek can no longer reach the wire without a source having
    /// been asked about first.
    public func sendBio(_ frame: BioSampleFrame) {
        guard let peek = BioPeek.egressible(from: frame) else { return }
        let peers = mcSession.connectedPeers
        guard !peers.isEmpty else { return }
        // `identity.displayName` for the same reason as `share(project:)` above.
        let payload = ColabPayload(kind: "bio", senderName: identity.displayName, bio: peek)
        guard let data = payload.encoded() else { return }
        try? mcSession.send(data, toPeers: peers, with: .unreliable)
    }

    // MARK: - MainActor handlers (called from the nonisolated delegates)

    /// ⚠️ EVERY ONE OF THESE THREE RESOLVES THE TRANSPORT STRING FIRST (#1435). The delegates
    /// hand over `MCPeerID.displayName`, which is now a `PeerIdentity.transportName`; keying on
    /// it raw would work, but it would put the separator and the UUID on screen and it would
    /// lose the distinction for a legacy peer, whose transport name IS its label.
    private func handleFound(_ peerID: MCPeerID) {
        let peer = PeerIdentity.resolve(transportName: peerID.displayName)
        peerIDs[peer.stableID] = peerID
        if !discovered.contains(where: { $0.id == peer.stableID }) {
            discovered.append(DiscoveredPeer(id: peer.stableID, name: peer.displayName))
        }
    }

    private func handleLost(_ transportName: String) {
        let peer = PeerIdentity.resolve(transportName: transportName)
        peerIDs[peer.stableID] = nil
        discovered.removeAll { $0.id == peer.stableID }
    }

    private func handleStateChange(_ transportName: String, connected: Bool) {
        let peer = PeerIdentity.resolve(transportName: transportName)
        if connected {
            if !connectedPeers.contains(where: { $0.stableID == peer.stableID }) {
                connectedPeers.append(peer)
            }
            discovered.removeAll { $0.id == peer.stableID }
            status = "Connected to \(peer.displayName)"
        } else {
            connectedPeers.removeAll { $0.stableID == peer.stableID }
            peerReadings[peer.stableID] = nil
            if connectedPeers.isEmpty && isLive { status = "Looking for nearby Echoelmusic…" }
        }
    }

    /// - Parameter peerName: the AUTHENTICATED `MCPeerID.displayName` the transport
    ///   handed us alongside the bytes — NOT the `senderName` field inside them.
    ///
    /// ⛔ WHY THE PARAMETER EXISTS (#517). This method used to take only `data`, and
    /// then keyed `peerReadings` and worded the status by `payload.senderName` — a
    /// field the SENDER writes. `handleStateChange` cleans up by `peerID.displayName`.
    /// Two different names for one peer, so a payload claiming any other string filed
    /// a reading under a key the disconnect path never clears: a phantom row that
    /// outlives the session for the process lifetime. That defeats exactly the
    /// property #508 was built to give ("a quiet peer stops looking alive") — through
    /// the KEY rather than through the timestamp, which is why #508's freshness guard
    /// could not catch it.
    ///
    /// ⭐ The rewrite happens ONCE, here at the boundary (#416), via
    /// `ColabPayload.attributed(to:)` — not as four defensive reads downstream. Every
    /// later reader (`peerReadings`, `incoming`, `onReceiveSession`, `status`) then
    /// sees a payload whose `senderName` is a transport fact by construction.
    /// ⭐ #1435 SPLIT THE ONE STRING THIS METHOD USED IN TWO. `attributed(to:)` still takes a
    /// TRANSPORT FACT rather than the sender's claim — that is #517 and it is untouched — but
    /// the fact now has two halves: the reading is filed under `stableID`, and the label that
    /// reaches `status` and `senderName` is `displayName`.
    private func handleData(_ data: Data, from peerName: String) {
        let peer = PeerIdentity.resolve(transportName: peerName)
        guard let payload = ColabPayload.decode(data)?.attributed(to: peer.displayName) else { return }
        // Bio pings update the per-peer reading quietly — no incoming prompt,
        // no status churn (they arrive continuously while a peer shares).
        if payload.kind == "bio", let peek = payload.bio {
            // Stamped with OUR clock at the moment it arrived (#508). The peek carries
            // no time, and a sender field could not report the failures that matter —
            // a dropped link, a backgrounded app, a peer that crashed. Only arrival
            // here can distinguish a peer still breathing from one that went quiet.
            peerReadings[peer.stableID] = PeerReading(peek: peek,
                                                      arrivedAt: CFAbsoluteTimeGetCurrent())
            return
        }
        incoming = payload
        onReceiveSession?(payload)
        status = "Session received from \(payload.senderName)"
    }
}

// MARK: - MCSessionDelegate

extension MultipeerSession: MCSessionDelegate {
    public nonisolated func session(_ session: MCSession, peer peerID: MCPeerID, didChange state: MCSessionState) {
        let name = peerID.displayName
        let connected = (state == .connected)
        Task { @MainActor [weak self] in self?.handleStateChange(name, connected: connected) }
    }

    public nonisolated func session(_ session: MCSession, didReceive data: Data, fromPeer peerID: MCPeerID) {
        // The peer here is AUTHENTICATED by the transport — carry it through instead
        // of trusting the name inside the bytes (#517).
        let name = peerID.displayName
        Task { @MainActor [weak self] in self?.handleData(data, from: name) }
    }

    public nonisolated func session(_ session: MCSession, didReceive stream: InputStream, withName streamName: String, fromPeer peerID: MCPeerID) {}
    public nonisolated func session(_ session: MCSession, didStartReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, with progress: Progress) {}
    public nonisolated func session(_ session: MCSession, didFinishReceivingResourceWithName resourceName: String, fromPeer peerID: MCPeerID, at localURL: URL?, withError error: Error?) {}
}

// MARK: - Advertiser (invitations require explicit user consent)

extension MultipeerSession: MCNearbyServiceAdvertiserDelegate {
    public nonisolated func advertiser(_ advertiser: MCNearbyServiceAdvertiser,
                                       didReceiveInvitationFromPeer peerID: MCPeerID,
                                       withContext context: Data?,
                                       invitationHandler: @escaping (Bool, MCSession?) -> Void) {
        // NEVER auto-accept (App Store audit 2026-07-16): while colab is live the
        // user may be streaming live bio to connected peers — a silent join would
        // hand that stream to any nearby device. Hop to the MainActor and surface
        // an Accept/Decline card; the handler (non-Sendable closure) crosses the
        // hop boxed, and `mcSession` is the nonisolated(unsafe) immutable ref MC
        // accepts from any thread. If the user never answers, MC's own inviter
        // timeout (20 s) resolves it; stop() declines a still-pending card.
        // The card shows a LABEL, so resolve the transport spelling (#1435).
        let name = PeerIdentity.resolve(transportName: peerID.displayName).displayName
        let handlerBox = UncheckedBox(value: invitationHandler)
        // MCSession is non-Sendable — box it across the hop like MCPeerID
        // (immutable ref; MC accepts the handler's session from any thread).
        let sessionBox = UncheckedBox(value: mcSession)
        Task { @MainActor [weak self] in
            self?.handleInvitation(from: name) { accept in
                handlerBox.value(accept, accept ? sessionBox.value : nil)
            }
        }
    }
}

// MARK: - Browser

extension MultipeerSession: MCNearbyServiceBrowserDelegate {
    public nonisolated func browser(_ browser: MCNearbyServiceBrowser, foundPeer peerID: MCPeerID, withDiscoveryInfo info: [String: String]?) {
        let box = UncheckedBox(value: peerID)
        Task { @MainActor [weak self] in self?.handleFound(box.value) }
    }

    public nonisolated func browser(_ browser: MCNearbyServiceBrowser, lostPeer peerID: MCPeerID) {
        let name = peerID.displayName
        Task { @MainActor [weak self] in self?.handleLost(name) }
    }
}

#endif
