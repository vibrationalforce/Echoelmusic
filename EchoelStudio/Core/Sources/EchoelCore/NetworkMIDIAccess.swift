import Foundation

/// Who may connect to Network MIDI (the RTP-MIDI session): nobody while it is off, and while it is
/// on only the hosts in its contact list — never anyone on the Wi-Fi, because a host that connects
/// plays the instrument and moves every mapped control. The app holds CoreMIDI's session; the
/// decisions are here, pure, so `NetworkMIDIAccessTests` replays them.
public enum NetworkMIDIAccess {
    /// A network MIDI host as CoreMIDI describes it: a typed address and port, or a Bonjour
    /// service name, or both.
    public struct Host: Equatable, Sendable {
        public var name: String
        public var address: String
        public var port: Int
        public var service: String

        public init(name: String, address: String, port: Int, service: String = "") {
            self.name = name
            self.address = address
            self.port = port
            self.service = service
        }

        /// The same machine: the same address and port when both have an address, else the same
        /// Bonjour service. Two hosts with neither are never the same, so nothing unnamed is kept
        /// on another's account.
        public func isSame(as other: Host) -> Bool {
            let mine = Self.normalized(address), theirs = Self.normalized(other.address)
            if !mine.isEmpty, !theirs.isEmpty { return mine == theirs && port == other.port }
            let myService = Self.normalized(service), theirService = Self.normalized(other.service)
            return !myService.isEmpty && myService == theirService
        }

        private static func normalized(_ text: String) -> String {
            text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
    }

    /// The session's connection policy.
    public enum Policy: Equatable, Sendable {
        case noOne
        case contactsOnly
    }

    /// Off lets nobody in; on lets in the hosts in the contact list, and no one else.
    public static func policy(networkOn: Bool) -> Policy {
        networkOn ? .contactsOnly : .noOne
    }

    /// The positions in `connected` whose hosts must join the contact list before the policy
    /// narrows, so nothing connected now is cut off silently: each host not yet a contact, once.
    public static func contactsToAdd(connected: [Host], contacts: [Host]) -> [Int] {
        var kept = contacts
        var add: [Int] = []
        for (index, host) in connected.enumerated() {
            // A host with neither address nor service matches nothing, not even itself: a contact
            // for it would let nobody in.
            guard host.isSame(as: host) else { continue }
            guard !kept.contains(where: { $0.isSame(as: host) }) else { continue }
            kept.append(host)
            add.append(index)
        }
        return add
    }
}
