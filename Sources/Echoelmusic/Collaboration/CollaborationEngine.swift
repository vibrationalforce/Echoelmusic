import Foundation
import Combine

/// Collaboration Engine - Ultra-Low-Latency Multiplayer with WebRTC
/// Group Bio-Sync, Shared Metronome, Collective Coherence
/// Target latency: <20ms LAN, <50ms Internet
@MainActor
class CollaborationEngine: ObservableObject {

    @Published var isActive: Bool = false
    @Published var currentSession: CollaborationSession?
    @Published var participants: [Participant] = []
    @Published var groupCoherence: Float = 0.0
    @Published var averageHRV: Float = 0.0

    // MARK: - Session Management

    func createSession(as host: Bool) async throws {
        let session = CollaborationSession(
            id: UUID(),
            hostID: UUID(),
            participants: [],
            isHost: host
        )
        currentSession = session
        isActive = true
        print("✅ CollaborationEngine: Created session (host: \(host))")
    }

    func joinSession(sessionID: UUID) async throws {
        // TODO: WebRTC connection
        print("🔗 CollaborationEngine: Joining session \(sessionID)")
    }

    func leaveSession() {
        currentSession = nil
        participants.removeAll()
        isActive = false
        print("👋 CollaborationEngine: Left session")
    }

    // MARK: - Group Bio-Sync

    func updateGroupBio(participantBio: [(id: UUID, hrv: Float, coherence: Float)]) {
        // KRITISCH: Verhindere Division durch Null
        guard !participantBio.isEmpty else {
            averageHRV = 0.0
            groupCoherence = 0.0
            return
        }

        let count = Float(participantBio.count)
        averageHRV = participantBio.map { $0.hrv }.reduce(0, +) / count
        groupCoherence = participantBio.map { $0.coherence }.reduce(0, +) / count

        print("🧠 CollaborationEngine: Group HRV: \(averageHRV), Group Coherence: \(groupCoherence)")
    }

    func identifyFlowLeader() -> UUID? {
        return participants.max(by: { $0.coherence < $1.coherence })?.id
    }
}

struct CollaborationSession: Identifiable {
    let id: UUID
    let hostID: UUID
    var participants: [Participant]
    let isHost: Bool
}

struct Participant: Identifiable {
    let id: UUID
    var name: String
    var hrv: Float
    var coherence: Float
    var isMuted: Bool
}
