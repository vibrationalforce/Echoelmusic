// DeviceChain.swift
// Echoel — a track's insert chain (Phase 3 / DC1, founder order 2026-09-25: "native DeviceChain";
// plan `scratchpads/PLAN_DEVICE_CHAIN_2026-09-26.md`). The WA3 contract's §D shape, minimally:
// `inserts: [DeviceInsert]` on the lane that owns them.
//
// ⭐ THE INSTRUMENT SLOT IS NOT HERE, ON PURPOSE. WA3 §P: "a track's instrument slot is a Device
// instance, never a lane field" — and today what plays a lane is DERIVED (the roll-lane rule and
// `builtinInstrument`). A second, stored instrument truth beside that derivation would be two
// opinions about what a track plays. It joins this type when the Echoel device becomes an
// instance (the next Phase 3 step), and replaces the derivation then — not beside it.
//
// ⭐ AN UNKNOWN INSERT IS KEPT, NEVER DROPPED (WA3 §C2, the #527 law). Its state is an opaque
// `stateBlob`, so a song written by a later build round-trips through this one byte for byte,
// and simply does not sound here. A decoder that dropped what it did not know would silently
// delete the user's effect the first time an older build saved the song.
//
// ⚠️ DC1 SOUNDS ONE INSERT, AND SAYS SO. A rack voice has ONE `EchoelFXChain`, so the first
// ENABLED insert of a KNOWN type is what plays (`soundingCharacter`); the inspector writes at most
// one. An array that could hold three while one sounds would be a claim — so the type answers
// the question "what plays", and the writer keeps the array to what plays plus what it cannot
// read.
//
// ⚠️ INTERIM HOME. The contract's final home is the `EchoelCore` target, which is founder-gated
// (#95, `project.yml`). Until then it lives in `Core/`, like `MediaAsset`.

import Foundation

/// The effects on a track, in signal order.
public struct DeviceChain: Codable, Sendable, Equatable {
    public var inserts: [DeviceInsert]

    public init(inserts: [DeviceInsert]) {
        self.inserts = inserts
    }

    /// The character the track's voice plays through, or nil for its shipped default sound: the
    /// first ENABLED insert of the character type whose state names a character that carries its
    /// own preset. `.auto` never answers — it means "the genre's effect", and a track does not
    /// own the genre the Echoel instrument plays.
    public var soundingCharacter: FXCharacter? {
        for insert in inserts where insert.isEnabled && insert.typeID == DeviceInsert.characterTypeID {
            if let character = insert.character, character.preset != nil { return character }
        }
        return nil
    }

    /// This chain with its character effect set to `character` (nil = none). Inserts of any OTHER
    /// type — above all one this build cannot read — are kept, in place, untouched; an existing
    /// character insert keeps its identity. Returns nil when nothing is left, so a track with no
    /// effect stores no chain at all (the lane's field stays absent, as before DC1).
    public func settingCharacter(_ character: FXCharacter?) -> DeviceChain? {
        var result = inserts
        let firstCharacter = result.firstIndex { $0.typeID == DeviceInsert.characterTypeID }
        // Only ONE character insert survives: DC1 sounds one, so a second would be a claim.
        result = result.enumerated().compactMap { index, insert in
            insert.typeID == DeviceInsert.characterTypeID && index != firstCharacter ? nil : insert
        }
        if let character, character.preset != nil {
            if let index = result.firstIndex(where: { $0.typeID == DeviceInsert.characterTypeID }) {
                result[index].isEnabled = true
                result[index].stateBlob = DeviceInsert.blob(for: character)
            } else {
                result.append(DeviceInsert.character(character))
            }
        } else {
            result.removeAll { $0.typeID == DeviceInsert.characterTypeID }
        }
        return result.isEmpty ? nil : DeviceChain(inserts: result)
    }

    // A hand-written decoder so one unreadable insert is skipped, not the whole chain — and the
    // chain itself is `try?`-decoded by `TimelineLane`, so a broken chain never costs the lane.
    private enum CodingKeys: String, CodingKey { case inserts }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let lossy = (try? c.decodeIfPresent([LossyInsert].self, forKey: .inserts)) ?? []
        inserts = lossy.compactMap(\.value)
    }

    private struct LossyInsert: Decodable {
        let value: DeviceInsert?
        init(from decoder: Decoder) throws {
            value = try? DeviceInsert(from: decoder)
        }
    }
}

/// One device instance in a chain (WA3 §C2): identity, type, version, the slot's enable, and the
/// device's own state as an opaque blob.
public struct DeviceInsert: Codable, Sendable, Equatable, Identifiable {
    public var id: UUID
    public var typeID: String
    public var typeVersion: Int
    public var isEnabled: Bool
    public var stateBlob: Data

    /// The one insert type this build plays: a named effect character on the track's voice chain.
    public static let characterTypeID = "com.echoelmusic.device.fx.character"

    public init(id: UUID = UUID(), typeID: String, typeVersion: Int, isEnabled: Bool, stateBlob: Data) {
        self.id = id
        self.typeID = typeID
        self.typeVersion = typeVersion
        self.isEnabled = isEnabled
        self.stateBlob = stateBlob
    }

    /// A character insert — the state is the character's raw value, UTF-8.
    public static func character(_ character: FXCharacter) -> DeviceInsert {
        DeviceInsert(typeID: characterTypeID, typeVersion: 1, isEnabled: true,
                     stateBlob: blob(for: character))
    }

    static func blob(for character: FXCharacter) -> Data {
        Data(character.rawValue.utf8)
    }

    /// The character this insert names, or nil when it is not a character insert or its state
    /// names no character this build knows (a later build's name decodes to nothing, not a crash).
    public var character: FXCharacter? {
        guard typeID == Self.characterTypeID,
              let raw = String(data: stateBlob, encoding: .utf8) else { return nil }
        return FXCharacter(rawValue: raw)
    }
}
