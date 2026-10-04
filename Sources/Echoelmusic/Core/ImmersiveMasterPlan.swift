// ImmersiveMasterPlan.swift
// Spatial S-A1 (ADR-007, accepted 2026-10-04): WHAT an immersive master of the open piece
// contains, decided once, before any byte is captured or written. A pure value — Foundation
// only, no clock, no randomness, no store — so the same piece always yields the same plan, and
// the stem capture (S-A3), the export folder (S-A4) and the ADM BWF writer (S-A5) all read ONE
// answer to "which channel is what" instead of three.
//
// THE RULES (ADR-007 §2, each one a decision, not a default):
// · Every AUDIO track becomes one OBJECT — a mono channel placed from the spatial scene. Only
//   audio tracks are objects because only they have a place in the headphone space today (S3c);
//   a MIDI lane sounds through the generated voices, which are not positioned.
// · The generated voices (synth, bass, body voice) go into ONE stereo BED, BS.2051 0+2+0
//   (`AP_00010002`, referenced from the BS.2094 common definitions, never re-declared).
// · A bio lane is neither: it modulates, it does not sound.
// · No LFE and no height bed in v1. `ChannelRole.lfe` exists so a later plan can say it; the
//   builder below never emits it.
//
// ⚠️ NAMING: the role type is `ChannelRole`, NOT `SpatialRole` — that name belongs to the
// collaboration permission in `SpatialScene.swift`, and a second type of the same name would
// not compile.
//
// ⚠️ HONESTY (ADR-007 §9): this plan is the open ITU/EBU profile. It never names the piece
// "Atmos_Master" — that programme name is how a Dolby profile identifies itself, and whether a
// file of ours may carry it is a legal question (ADR-007 F-E) that is still open. Nothing here
// is a Dolby, Atmos or Apple Spatial Audio claim.
//
// Built: yes. Wired: NO — nothing constructs a plan in the app yet (S-A3/S-A4 will). Device: no.

import Foundation

// MARK: - Channel role

/// A BS.2051 loudspeaker label a bed channel is rendered to. v1 knows only the stereo pair.
public enum BS2051Channel: String, Codable, Sendable, CaseIterable {
    /// Front left, +30° azimuth (ADM common definition `AC_00010001`).
    case frontLeft = "M+030"
    /// Front right, −30° azimuth (ADM common definition `AC_00010002`).
    case frontRight = "M-030"

    /// The BS.2094 common-definition channel format this label is.
    public var admChannelFormatID: String {
        switch self {
        case .frontLeft:  return "AC_00010001"
        case .frontRight: return "AC_00010002"
        }
    }
}

/// What one channel of an immersive master IS.
public enum ChannelRole: Codable, Sendable, Equatable, Hashable {
    /// A positioned mono source — one audio track.
    case object
    /// One channel of a channel-based bed, rendered to a fixed loudspeaker label.
    case bed(channel: BS2051Channel)
    /// The low-frequency effects channel. Not emitted in v1 (ADR-007 §2).
    case lfe
}

// MARK: - The plan

/// The channel layout of one immersive master, in file order.
public struct ImmersiveMasterPlan: Codable, Sendable, Equatable {

    /// Wire version of this plan's JSON. Bump ONLY with an update of
    /// `docs/ECHOEL_SESSION_PROTOCOL.md` (the section "Immersive master plan").
    public static let formatVersion = 1
    /// The immersive master's sample rate (ADR-007 §2, F-C). The stereo export stays 44.1 kHz.
    public static let sampleRate = 48_000
    /// The immersive master's PCM word length (ADR-007 §2, F-C).
    public static let bitDepth = 24
    /// The ADM version the BW64 writer declares (ADR-007 §1).
    public static let admVersion = "ITU-R_BS.2076-2"
    /// The BS.2094 common-definition pack the generated-voice bed refers to (0+2+0 stereo).
    public static let stereoBedPackFormatID = "AP_00010002"
    /// The name used when the piece's own name is empty or reserved.
    public static let fallbackProgrammeName = "Echoel Piece"
    /// Programme names a Dolby profile reads as its own (ADR-007 F-E) — never written by us.
    static let reservedProgrammeNames: Set<String> = ["atmos_master"]

    /// One channel of the master.
    public struct Channel: Codable, Sendable, Equatable {
        /// 1-based position in the file (the BW64 `chna` track index). Contiguous from 1.
        public let trackIndex: Int
        public let role: ChannelRole
        /// What a mixing engineer reads in their session: the track's name, or the bed's.
        public let name: String
        /// The audio track an object comes from. nil for a bed channel.
        public let laneID: UUID?
        /// Where an object starts. nil for a bed channel (a bed has no position, it has a label).
        public let position: SpatialPosition?
    }

    /// Decodes from older payloads; always `formatVersion` when built here.
    public let version: Int
    /// The ADM `audioProgrammeName`.
    public let programmeName: String
    /// Every channel, in file order: the bed first (when there is one), then the objects in
    /// track order.
    public let channels: [Channel]

    /// The number of positioned sources.
    public var objectCount: Int { channels.filter { $0.role == .object }.count }
    /// The number of bed channels.
    public var bedChannelCount: Int {
        channels.filter { if case .bed = $0.role { return true } else { return false } }.count
    }
    /// A plan with no channel has nothing to write; the export must say so instead of writing
    /// an empty file.
    public var isEmpty: Bool { channels.isEmpty }

    // MARK: Building

    /// The plan for a piece.
    ///
    /// - Parameters:
    ///   - programmeName: the piece's name. Trimmed; an empty or reserved name becomes
    ///     `fallbackProgrammeName`.
    ///   - lanes: the piece's tracks, in their song order.
    ///   - scene: the spatial scene of the piece. An object takes its place from here; a track
    ///     the scene does not know yet takes the place `SpatialSceneStore` would give it, so the
    ///     plan and a fresh scene rebuild can never disagree (#416).
    ///   - includesGeneratedVoices: whether the generated voices sound in this piece, i.e.
    ///     whether there is a bed to write.
    public static func make(programmeName: String,
                            lanes: [TimelineLane],
                            scene: SpatialScene,
                            includesGeneratedVoices: Bool = true) -> ImmersiveMasterPlan {
        var channels: [Channel] = []
        if includesGeneratedVoices {
            for label in BS2051Channel.allCases {
                channels.append(Channel(trackIndex: channels.count + 1,
                                        role: .bed(channel: label),
                                        name: "Generated voices \(label.rawValue)",
                                        laneID: nil,
                                        position: nil))
            }
        }
        for lane in lanes where lane.kind == .audio && !lane.isBio {
            let place = scene.object(id: lane.id.uuidString)?.position
                ?? SpatialSceneStore.defaultPosition(forLane: lane.id, in: lanes)
                ?? .front
            channels.append(Channel(trackIndex: channels.count + 1,
                                    role: .object,
                                    name: trackName(lane.name, number: channels.count + 1),
                                    laneID: lane.id,
                                    position: place))
        }
        return ImmersiveMasterPlan(version: formatVersion,
                                   programmeName: sanitizedProgrammeName(programmeName),
                                   channels: channels)
    }

    /// The programme name a file may carry: trimmed, never empty, never a reserved name.
    static func sanitizedProgrammeName(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !reservedProgrammeNames.contains(trimmed.lowercased()) else {
            return fallbackProgrammeName
        }
        return trimmed
    }

    /// A track's name as a channel name: trimmed, or "Track N" when empty.
    private static func trackName(_ raw: String, number: Int) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Track \(number)" : trimmed
    }
}
