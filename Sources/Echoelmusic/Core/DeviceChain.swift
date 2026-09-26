// DeviceChain.swift
// Echoel — a track's insert chain (Phase 3 / DC1, founder order 2026-09-25: "native DeviceChain";
// plan `scratchpads/PLAN_DEVICE_CHAIN_2026-09-26.md`). The WA3 contract's §D shape, minimally:
// `inserts: [DeviceInsert]` on the lane that owns them.
//
// ⭐ THE INSTRUMENT SLOT HOLDS HOW THE ECHOEL IS SET, NEVER WHAT PLAYS (Phase 3 / EF1, plan
// `scratchpads/PLAN_ECHOEL_DEVICE_2026-09-26.md`). WA3 §P: "a track's instrument slot is a Device
// instance, never a lane field". What plays a lane stays DERIVED (the roll-lane rule and
// `builtinInstrument`) — ONE truth; the `instrument` insert is the Echoel instance's STATE on the
// track that plays it (today one fact: its FX character), so the song carries its Echoel. When the
// derivation moves into the slot, it REPLACES the rule — never beside it.
//
// ⭐ AN UNKNOWN INSERT TYPE IS KEPT, NEVER DROPPED (WA3 §C2, the #527 law). Its state is an opaque
// `stateBlob`, so a song written by a later build round-trips through this one byte for byte,
// and simply does not sound here. A decoder that dropped what it did not know would silently
// delete the user's effect the first time an older build saved the song.
// ⚠️ THE LIMIT, stated rather than implied (review of e061ca2d3): "kept" holds for an unknown
// TYPE inside THIS envelope (id, typeID, typeVersion, isEnabled, stateBlob). An insert whose
// ENVELOPE this build cannot decode (a later build that drops `stateBlob`, say) is skipped on
// decode and gone on the next save. Changing the envelope is therefore a migration, never a
// field edit. And a character insert of a LATER `typeVersion` is not read as a character here
// (`DeviceInsert.character`), nor re-stamped in place: choosing an effect replaces its state AND
// its version, so a later build never finds v1 bytes under a v2 label.
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
    /// The instrument instance's state (EF1) — on the roll lane, the Echoel device
    /// (`DeviceInsert.echoelTypeID`). Its own coding key: a chain without one writes the DC1 bytes.
    /// ⚠️ A DC1-era build does not know this key and drops it on its next save.
    public var instrument: DeviceInsert?

    public init(inserts: [DeviceInsert]) {
        self.inserts = inserts
        self.instrument = nil
    }

    /// Nothing to store: no insert and no instrument — the lane's field stays absent.
    public var isEmpty: Bool { inserts.isEmpty && instrument == nil }

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
    /// character insert keeps its identity, and the instrument is never touched. Returns nil when
    /// nothing is left, so a track with no effect stores no chain at all (the lane's field stays
    /// absent, as before DC1).
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
                result[index].typeVersion = DeviceInsert.characterTypeVersion
                result[index].stateBlob = DeviceInsert.blob(for: character)
            } else {
                result.append(DeviceInsert.character(character))
            }
        } else {
            result.removeAll { $0.typeID == DeviceInsert.characterTypeID }
        }
        var next = self
        next.inserts = result
        return next.isEmpty ? nil : next
    }

    // A hand-written decoder so one unreadable insert is skipped, not the whole chain — and the
    // chain itself is `try?`-decoded by `TimelineLane`, so a broken chain never costs the lane.
    private enum CodingKeys: String, CodingKey { case inserts, instrument }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        let lossy = (try? c.decodeIfPresent([LossyInsert].self, forKey: .inserts)) ?? []
        inserts = lossy.compactMap(\.value)
        instrument = (try? c.decodeIfPresent(DeviceInsert.self, forKey: .instrument)) ?? nil
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
    /// The state format this build writes and reads for a character insert: the raw value, UTF-8.
    public static let characterTypeVersion = 1

    public init(id: UUID = UUID(), typeID: String, typeVersion: Int, isEnabled: Bool, stateBlob: Data) {
        self.id = id
        self.typeID = typeID
        self.typeVersion = typeVersion
        self.isEnabled = isEnabled
        self.stateBlob = stateBlob
    }

    /// A character insert — the state is the character's raw value, UTF-8.
    public static func character(_ character: FXCharacter) -> DeviceInsert {
        DeviceInsert(typeID: characterTypeID, typeVersion: characterTypeVersion, isEnabled: true,
                     stateBlob: blob(for: character))
    }

    static func blob(for character: FXCharacter) -> Data {
        Data(character.rawValue.utf8)
    }

    /// The character this insert names, or nil when it is not a character insert, its state is a
    /// LATER format than this build reads, or its state names no character this build knows (a
    /// later build's name decodes to nothing, not a crash).
    public var character: FXCharacter? {
        guard typeID == Self.characterTypeID,
              typeVersion <= Self.characterTypeVersion,
              let raw = String(data: stateBlob, encoding: .utf8) else { return nil }
        return FXCharacter(rawValue: raw)
    }

    // MARK: - The Echoel instance (EF1)

    /// The Echoel instrument as a device instance (WA3 §A.2).
    public static let echoelTypeID = "com.echoelmusic.device.echoel"
    /// The state format this build reads and writes: sorted-keys JSON `[String: String]`.
    public static let echoelTypeVersion = 1
    static let echoelFXKey = "fxCharacter"

    /// A fresh Echoel instance carrying one fact.
    public static func echoel(fxCharacter: FXCharacter) -> DeviceInsert {
        DeviceInsert(typeID: echoelTypeID, typeVersion: echoelTypeVersion, isEnabled: true,
                     stateBlob: echoelBlob([echoelFXKey: fxCharacter.rawValue]))
    }

    /// The instance's fields, or nil when this is not an Echoel instance THIS build can read — a
    /// LATER `typeVersion`, another type, or a state that is not the v1 shape.
    var echoelFields: [String: String]? {
        guard typeID == Self.echoelTypeID, typeVersion <= Self.echoelTypeVersion else { return nil }
        return try? JSONDecoder().decode([String: String].self, from: stateBlob)
    }

    /// The FX character the instance is set to — nil when unreadable, unset, or a name this build
    /// does not know (a later build's character decodes to nothing, not a crash).
    public var echoelFXCharacter: FXCharacter? {
        echoelFields?[Self.echoelFXKey].flatMap(FXCharacter.init(rawValue:))
    }

    /// This instance with its FX character set — every OTHER field kept as it was. Nil when it is
    /// not an Echoel instance this build can read: a later build's instance is never rewritten
    /// with v1 meaning, so the song keeps it byte for byte.
    public func settingEchoelFX(_ character: FXCharacter) -> DeviceInsert? {
        guard var fields = echoelFields else { return nil }
        fields[Self.echoelFXKey] = character.rawValue
        var next = self
        next.typeVersion = Self.echoelTypeVersion
        next.stateBlob = Self.echoelBlob(fields)
        return next
    }

    /// Sorted keys, so one state has one byte form and "unchanged" is an equality.
    static func echoelBlob(_ fields: [String: String]) -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return (try? encoder.encode(fields)) ?? Data()
    }
}
