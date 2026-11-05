import Foundation

/// Reading a song a newer build saved (FWD, 2026-11-05; `docs/FORMAT.md`, "Reading newer songs").
///
/// Names are only ever appended inside format 4, so a song saved by a newer build may name a
/// modulation source or an effect type this build does not know. Where leaving such a part out
/// of the playback is safe — a modulation route, an insert — the song opens, the part is KEPT as
/// the JSON it was read from, plays nothing, and is written back in its place, byte for byte, on
/// the next save. Where it is not safe — what a track is, what a media file is, who owns a
/// parameter, a choice index past the end of its list — the song is refused with the name that
/// is missing (`UnknownStoredName`), never opened with parts silently gone.
///
/// Only the reader makes kept parts. No command can create one (Law 1): commands carry typed
/// values, and a kept part has no type here.

/// A name this build does not know, in a place where nothing can stand in for it: the song needs a
/// newer build. `ProjectCodec` reports it as `DecodeError.needsNewerBuild`.
public struct UnknownStoredName: Error, Equatable, Sendable {
    /// What the name names, as the musician reads it ("track kind", "synth.engine").
    public let field: String
    /// The name, or the index, as the song stores it.
    public let name: String

    public init(field: String, name: String) {
        self.field = field
        self.name = name
    }
}

/// Any JSON value, kept exactly as it was read so it can be written back. Numbers that are whole
/// stay integers, so `1` is not written back as `1.0`; the codec's encoder writes the same bytes
/// for a value read this way as for the typed value a newer build encoded.
public indirect enum StoredJSON: Codable, Equatable, Sendable {
    case null
    case bool(Bool)
    case integer(Int64)
    case number(Double)
    case string(String)
    case array([StoredJSON])
    case object([String: StoredJSON])

    public init(from decoder: any Decoder) throws {
        let single = try decoder.singleValueContainer()
        if single.decodeNil() {
            self = .null
        } else if let value = try? single.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? single.decode(Int64.self) {
            self = .integer(value)
        } else if let value = try? single.decode(Double.self) {
            self = .number(value)
        } else if let value = try? single.decode(String.self) {
            self = .string(value)
        } else if let value = try? single.decode([StoredJSON].self) {
            self = .array(value)
        } else {
            self = .object(try single.decode([String: StoredJSON].self))
        }
    }

    public func encode(to encoder: any Encoder) throws {
        var single = encoder.singleValueContainer()
        switch self {
        case .null: try single.encodeNil()
        case .bool(let value): try single.encode(value)
        case .integer(let value): try single.encode(value)
        case .number(let value): try single.encode(value)
        case .string(let value): try single.encode(value)
        case .array(let value): try single.encode(value)
        case .object(let value): try single.encode(value)
        }
    }
}

/// One part of a list this build cannot play: where it stood in the stored list, its id (so no
/// command can reuse it), the parameter it moves when it is a route, and its JSON.
struct KeptPart: Equatable, Sendable {
    var position: Int
    var id: UUID
    var target: ParameterAddress?
    var raw: StoredJSON
}

/// A stored list as this build holds it: the elements it plays, and the parts from a newer build
/// it keeps. Encoded as ONE array again, each kept part back at the place it was read from — so an
/// untouched song is written back exactly as it was read. A part whose place no longer exists
/// after an edit goes to the end, in the order the parts were read.
struct KeptList<Element: Encodable & Equatable & Sendable>: Encodable, Equatable, Sendable {
    var known: [Element]
    var kept: [KeptPart]

    init(known: [Element] = [], kept: [KeptPart] = []) {
        self.known = known
        self.kept = kept
    }

    /// Splits a list read from disk: an element `plays` keeps is known, every other one is kept
    /// as the JSON at its place. `raw` and `elements` are the same stored array read twice.
    init(elements: [Element], raw: [StoredJSON], id: (Element) -> UUID, plays: (Element) -> Bool) {
        var known = [Element](), kept = [KeptPart]()
        for (index, element) in elements.enumerated() {
            if plays(element) || index >= raw.count {
                known.append(element)
            } else {
                kept.append(KeptPart(position: index, id: id(element), target: nil, raw: raw[index]))
            }
        }
        self.init(known: known, kept: kept)
    }

    var count: Int { known.count + kept.count }

    func encode(to encoder: any Encoder) throws {
        var list = encoder.unkeyedContainer()
        let parts = kept.sorted { $0.position < $1.position }
        var nextKnown = 0, nextPart = 0
        for place in 0..<count {
            if nextPart < parts.count, parts[nextPart].position <= place || nextKnown >= known.count {
                try list.encode(parts[nextPart].raw)
                nextPart += 1
            } else {
                try list.encode(known[nextKnown])
                nextKnown += 1
            }
        }
    }
}

extension Project {
    /// The parts of this song a newer build saved that this build keeps but does not play:
    /// modulation routes and inserts (`docs/FORMAT.md`, "Reading newer songs").
    public var keptFromNewerBuild: Int {
        storedRoutes.kept.count + storedMasterInserts.kept.count + tracks.reduce(0) { $0 + $1.keptInsertCount }
    }

    /// What the musician reads when such a song opens; nil when there is nothing kept.
    public var newerBuildNotice: String? {
        let count = keptFromNewerBuild
        guard count > 0 else { return nil }
        let items = count == 1 ? "1 item is" : "\(count) items are"
        return "This song was saved by a newer Echoel Studio. \(items) kept but inactive until you update."
    }

    /// Routes kept from a newer build. They count against `Modulation.routeLimit` with the others.
    public var keptRouteCount: Int { storedRoutes.kept.count }
    /// Master inserts kept from a newer build. They take a place of `Insert.maximumPerTrack`.
    public var keptMasterInsertCount: Int { storedMasterInserts.kept.count }

    /// The routes a song stores, split: those this build plays, and those it keeps. A route is kept
    /// when it names a source, curve or polarity this build does not know, or a parameter of a
    /// track (or the master, or the song) that is here but that this build does not know. Every
    /// route has all seven keys of their types, a depth within −1 … 1 and an owner this build
    /// knows — one that does not refuses the song as it always did.
    func splitRoutes(_ loose: [LooseRoute], raw: [StoredJSON]) throws -> KeptList<ModulationRoute> {
        var list = KeptList<ModulationRoute>()
        for (index, route) in loose.enumerated() {
            if let source = ModulationSource(rawValue: route.source),
               let curve = ModulationRoute.Curve(rawValue: route.curve),
               let polarity = ModulationRoute.Polarity(rawValue: route.polarity) {
                let known = ModulationRoute(id: route.id, source: source, target: route.target, depth: route.depth,
                                            curve: curve, polarity: polarity, enabled: route.enabled)
                // A target on a track that is not here is damage, and the validation refuses it.
                if descriptor(for: route.target) != nil || !ownerExists(route.target) || index >= raw.count {
                    list.known.append(known)
                    continue
                }
            }
            guard index < raw.count else { continue }
            list.kept.append(KeptPart(position: index, id: route.id, target: route.target, raw: raw[index]))
        }
        return list
    }

    func ownerExists(_ address: ParameterAddress) -> Bool {
        if case .track(let id) = address.owner { return track(id) != nil }
        return true
    }

    /// The kept parts obey what every stored part obeys: ids unique among their kind, a route's
    /// depth in range and its owner here, the list within its limit.
    func validateKeptParts() throws {
        var routeIDs = Set(modRoutes.map(\.id))
        for part in storedRoutes.kept {
            guard routeIDs.insert(part.id).inserted else { throw CommandError.duplicateID(part.id.uuidString) }
            guard let target = part.target, ownerExists(target) else {
                throw Self.invalid("modRoutes", "a route's target names a track that is not in this song")
            }
            guard case .object(let fields) = part.raw, case let depth?? = fields["depth"].map(Self.number),
                  depth.isFinite, (-1...1).contains(depth) else {
                throw Self.invalid("modRoutes", "a route's depth is outside −1…1")
            }
        }
        guard storedRoutes.count <= Modulation.routeLimit else {
            throw Self.invalid("modRoutes", "more than \(Modulation.routeLimit) routes")
        }
    }

    private static func number(_ value: StoredJSON) -> Double? {
        switch value {
        case .integer(let whole): Double(whole)
        case .number(let number): number
        default: nil
        }
    }
}

extension Track {
    /// Inserts kept from a newer build: an effect of a type this build does not know. Each takes a
    /// place of `Insert.maximumPerTrack`, plays nothing, and is written back where it was.
    public var keptInsertCount: Int { storedInserts.kept.count }
}

/// A route as every format-3 and later build stores it, its names still unread — so a route with
/// a name from a newer build can be told from a damaged one.
struct LooseRoute: Decodable {
    let id: UUID
    let source: String
    let target: ParameterAddress
    let depth: Double
    let curve: String
    let polarity: String
    let enabled: Bool
}

extension KeptList where Element == Insert {
    /// An insert plays when its plugin is an effect. One whose type this build does not take in an
    /// insert slot — a MIDI effect, or a type it does not know at all — came from a newer build: it
    /// is kept and the signal passes it by. An instrument in an insert slot is no newer build's
    /// doing; it stays in the list, and the validation refuses the song as before.
    static func reading(_ inserts: [Insert], raw: [StoredJSON]) -> KeptList<Insert> {
        KeptList(elements: inserts, raw: raw, id: \.id.rawValue,
                 plays: { $0.plugin.role == .effect || $0.plugin.role == .instrument })
    }
}
