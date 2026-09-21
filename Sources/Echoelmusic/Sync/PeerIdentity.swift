// PeerIdentity.swift
// Echoel — #1435. WHO the other phone is, as a value type that owes nothing to any
// framework.
//
// THE DEFECT THIS REPAIRS, measured rather than assumed. `MultipeerSession` built its
// `MCPeerID` from `UIDevice.current.name` and then used that ONE string as the key for
// everything: `peerIDs`, the `discovered` array's dedupe, `peerReadings`, and the
// `senderName` on every payload. `DiscoveredPeer.name` was literally `{ id }` — the
// presentation string and the identity WERE the same value.
//
// ⛔ AND THE COLLISION IS THE DEFAULT CASE, NOT AN EDGE CASE. This repository declares no
// `com.apple.developer.device-information.user-assigned-device-name` entitlement (measured:
// zero hits across every `*.entitlements`, `*.plist` and `*.yml`). Without it, iOS 16 and
// later return the MODEL name from `UIDevice.current.name` — so two iPhones both advertise
// "iPhone", `peerIDs["iPhone"]` overwrites, the dedupe collapses them into one row, and
// `peerReadings["iPhone"]` mixes two bodies into one reading. Three phones would show as one
// peer.
//
// ⚠️ THE ENTITLEMENT HALF IS MEASURED HERE; THE iOS BEHAVIOUR HALF IS APPLE'S CONTRACT AND IS
// NOT PROVEN BY THIS REPOSITORY. Stated separately on purpose — a two-phone check settles it
// in seconds and is registered as NEEDS-FOUNDER-VERIFY rather than assumed.
//
// ⭐ WHAT IS DELIBERATELY *NOT* REUSED, and it is the first thing that looks right:
// `PerformerSignature`. It is per-installation and already persisted, so it reads like a free
// stable ID — and its own header forbids exactly that: it is never transmitted, it is
// deliberately kept OUT of the shared App Group, and it carries `taughtByRestrictedSource`
// because HealthKit-derived frames shape it. Using a bio fingerprint as a network identity
// would turn a privacy boundary into an advertising beacon. The stable ID here is a plain
// random UUID that means nothing about the body.
//
// ⚠️ SCOPE, so the next session does not read more into this type than it holds. This is
// TODAY'S MULTIPEER CORRECTNESS, not a session model. There is no `EchoelSession`, no
// capability negotiation, no presence, no auth, and no `deviceRole` — that field is absent
// because no production code reads one, and a field nobody reads is the #416 trap. It is
// shaped so those can arrive later without moving this type.

import Foundation

/// One participant in a nearby session: a stable key and a human label, kept apart.
///
/// ⭐ THE WHOLE POINT IS THAT THESE TWO ARE DIFFERENT VALUES. `stableID` answers "is this the
/// same phone as before"; `displayName` answers "what do I call them". Collapsing them is the
/// defect this type exists to end, so nothing here derives one from the other.
public struct PeerIdentity: Codable, Equatable, Sendable {

    /// Stable per-INSTALLATION key. Survives relaunch, survives renaming, means nothing about
    /// the person or the hardware. Not a device ID: reinstalling mints a new one, which is
    /// correct — this identifies a participant in a session, not a machine.
    public let stableID: String

    /// What a human sees. Free to change at any time without changing `stableID`.
    public let displayName: String

    public init(stableID: String, displayName: String) {
        self.stableID = stableID
        self.displayName = displayName
    }

    // MARK: - The local participant

    /// This installation's identity, minted once and persisted.
    ///
    /// ⚠️ THE FALLBACK LABEL IS A PARAMETER RATHER THAN A `UIDevice` READ, and that is what
    /// keeps this type Foundation-only and drivable from the blocking bundle. The caller is
    /// already `@MainActor` and already holds the device name; this file must not import UIKit
    /// to fetch a string its one caller has in hand.
    ///
    /// ⭐ THE LABEL PREFERS THE CANONICAL ARTIST NAME (`SessionContext.artistName`) rather than
    /// inventing a second user-name truth. `SessionContext.typedArtistName(fromStored:)` is the
    /// existing answer to "has the user actually named themselves" — the brand mark `E~` means
    /// they have not — so an unnamed user still advertises the device name exactly as before
    /// this change, and a named one advertises the name they chose everywhere else in the app.
    ///
    /// ⚠️ ONE MIGRATION IS NOT REPEATED HERE ON PURPOSE (#416): `SessionContext.init` folds a
    /// legacy stored `"Echoel"` onto the brand mark, and this factory can run BEFORE that
    /// instance exists (`MultipeerSession` is constructed earlier in `EchoelmusicApp`). Such an
    /// install would advertise the label `Echoel` for one launch. That is a cosmetic difference
    /// in a string nobody keys on — restating the migration to erase it would buy a second copy
    /// of a decision, which is the more expensive mistake.
    public static func local(defaults: UserDefaults, fallbackName: String) -> PeerIdentity {
        let key = SessionContext.installationIDStorageKey
        let id: String
        // ⚠️ THE STORED VALUE IS VALIDATED, NOT MERELY CHECKED FOR EMPTINESS, and the reason is
        // the byte budget below rather than tidiness. `transportName` can only promise to fit
        // inside MCPeerID's 63 bytes because the key is a 36-byte UUID string; a key of any
        // other length would silently spend the label's whole budget and could overflow the
        // limit outright. Anything that is not a UUID is therefore re-minted rather than
        // carried — a fresh identity for this install, which is the safe direction.
        if let stored = defaults.string(forKey: key), UUID(uuidString: stored) != nil {
            id = stored
        } else {
            id = UUID().uuidString
            defaults.set(id, forKey: key)
        }
        let artist = defaults.string(forKey: SessionContext.artistStorageKey) ?? ""
        let typed = SessionContext.typedArtistName(fromStored: artist)
        let label = typed.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallbackName : typed
        return PeerIdentity(stableID: id, displayName: label)
    }

    // MARK: - The transport spelling

    /// Separator between label and key in the transport name. A character that cannot occur in
    /// a `stableID` (a UUID string: hex and hyphens only), so the LAST one is unambiguously the
    /// split point even when the label contains one.
    private static let separator: Character = "\u{001F}"   // ASCII unit separator

    /// `MCPeerID.displayName` is capped at 63 bytes and must be non-empty.
    private static let transportByteLimit = 63

    /// The identity as ONE string the transport can carry, label first so a truncation eats the
    /// label rather than the key.
    ///
    /// ⚠️ THE KEY IS BUDGETED FIRST, DELIBERATELY. Truncating from the right would cut the UUID
    /// and reintroduce collisions on exactly the long names most likely to be real artist names
    /// — the defect would come back wearing a fix. The label gets what remains (26 bytes beside
    /// a 36-byte UUID and the separator), cut on a CHARACTER boundary and re-measured in BYTES,
    /// because a name in German, Japanese or emoji is not one byte per character.
    ///
    /// ⚠️ AND THE 26 BYTES ARE A CONSEQUENCE OF KEEPING ONE SPELLING OF THE ID, not an oversight.
    /// A compact re-encoding of the same 16 bytes would free about 14 more, at the price of a
    /// stored form and a transmitted form that differ — two spellings of one decision, which is
    /// the trade this repo keeps retracting. Make it knowingly or not at all.
    public var transportName: String {
        let keyPart = String(Self.separator) + stableID
        let keyBytes = keyPart.utf8.count
        var label = displayName
        while label.utf8.count + keyBytes > Self.transportByteLimit, !label.isEmpty {
            label.removeLast()
        }
        return label + keyPart
    }

    /// Recover an identity from a transport name, or nil when the peer is not speaking this
    /// vocabulary.
    ///
    /// ⚠️ NIL IS A REAL ANSWER AND THE CALLER MUST HANDLE IT: a peer running an older build
    /// advertises a bare device name with no separator. `MultipeerSession` falls back to
    /// `legacy(transportName:)`, which is exactly the old behaviour FOR THAT PEER — old phones
    /// still collide with each other, new ones never do. Refusing to connect would be a worse
    /// answer than a degraded one.
    public init?(transportName: String) {
        guard let cut = transportName.lastIndex(of: Self.separator) else { return nil }
        let key = String(transportName[transportName.index(after: cut)...])
        guard !key.isEmpty else { return nil }
        self.stableID = key
        self.displayName = String(transportName[transportName.startIndex..<cut])
    }

    /// The identity for a peer that does not speak this vocabulary: its advertised string is all
    /// we know, so it is both the key and the label — the pre-#1435 behaviour, confined to the
    /// peers that actually need it.
    public static func legacy(transportName: String) -> PeerIdentity {
        PeerIdentity(stableID: transportName, displayName: transportName)
    }

    /// The identity behind a transport name, whichever vocabulary it speaks.
    public static func resolve(transportName: String) -> PeerIdentity {
        PeerIdentity(transportName: transportName) ?? legacy(transportName: transportName)
    }
}
