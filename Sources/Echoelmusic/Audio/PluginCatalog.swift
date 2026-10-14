// PluginCatalog.swift
// Echoel — production level, slice H1 (founder 2026-10-13): which Audio Unit v3 instruments and
// effects are installed on this device. READ ONLY — nothing here loads, attaches or plays a
// plugin; that is H2b (`scratchpads/PLAN_PRODUCTION_LEVEL_2026-10-13.md`).
//
// WHY A VALUE TYPE OF FOUR-CHARACTER CODES. H2a stores the chosen plugin in a track's
// `DeviceInsert.stateBlob`, which must stay Foundation-only and Codable. `AudioComponentDescription`
// is neither, so the catalog hands out `PluginDescriptor` — the three codes that identify a
// component on every device, plus the names a person reads — and only `installed(_:)` touches
// AVFoundation.
//
// The query runs off the main actor: `AVAudioUnitComponentManager` scans registrations, and a
// device with many plugins makes that slow. The caller (`TrackPluginRow`) hops with
// `Task.detached`, as `AudioPartEditorView` does for a file read.

import Foundation
#if canImport(AVFoundation)
import AVFoundation
#endif

/// One installed Audio Unit, identified the way the system identifies it.
struct PluginDescriptor: Codable, Hashable, Sendable, Identifiable {

    enum Role: String, Codable, Sendable, CaseIterable {
        /// `aumu` — plays notes (a software instrument).
        case instrument
        /// `aufx` — processes audio.
        case effect
        /// `aumf` — processes audio and also takes MIDI.
        case musicEffect
    }

    let type: UInt32
    let subtype: UInt32
    let manufacturer: UInt32
    let name: String
    let manufacturerName: String
    let version: Int

    var id: String {
        "\(Self.fourCC(type))/\(Self.fourCC(subtype))/\(Self.fourCC(manufacturer))"
    }

    var role: Role? { PluginCatalog.role(forType: type) }

    /// Apple's own units (`appl`) ship with iOS. They are listed after third-party plugins.
    var isApple: Bool { manufacturer == PluginCatalog.appleManufacturer }

    /// `0x61756D75` → "aumu". A byte outside printable ASCII is written as `?`, so a malformed
    /// code can never produce an empty or multi-line identifier.
    static func fourCC(_ code: UInt32) -> String {
        let bytes = [24, 16, 8, 0].map { UInt8((code >> UInt32($0)) & 0xFF) }
        return String(bytes.map { (0x20...0x7E).contains($0) ? Character(UnicodeScalar($0)) : "?" })
    }
}

enum PluginCatalog {

    /// `kAudioUnitType_MusicDevice` — 'aumu'.
    static let instrumentType: UInt32 = 0x6175_6D75
    /// `kAudioUnitType_Effect` — 'aufx'.
    static let effectType: UInt32 = 0x6175_6678
    /// `kAudioUnitType_MusicEffect` — 'aumf'.
    static let musicEffectType: UInt32 = 0x6175_6D66
    /// 'appl'.
    static let appleManufacturer: UInt32 = 0x6170_706C

    static func type(for role: PluginDescriptor.Role) -> UInt32 {
        switch role {
        case .instrument: return instrumentType
        case .effect: return effectType
        case .musicEffect: return musicEffectType
        }
    }

    static func role(forType type: UInt32) -> PluginDescriptor.Role? {
        PluginDescriptor.Role.allCases.first { Self.type(for: $0) == type }
    }

    /// One entry per component, third-party first, then by manufacturer and name (case-blind).
    /// A component listed twice by the system keeps its first entry.
    static func ordered(_ list: [PluginDescriptor]) -> [PluginDescriptor] {
        var seen: Set<String> = []
        let unique = list.filter { seen.insert($0.id).inserted }
        return unique.sorted { a, b in
            if a.isApple != b.isApple { return !a.isApple }
            let maker = a.manufacturerName.localizedCaseInsensitiveCompare(b.manufacturerName)
            if maker != .orderedSame { return maker == .orderedAscending }
            let name = a.name.localizedCaseInsensitiveCompare(b.name)
            if name != .orderedSame { return name == .orderedAscending }
            return a.id < b.id
        }
    }

    #if canImport(AVFoundation)
    /// The installed components of one role, ordered. Call it off the main actor.
    static func installed(_ role: PluginDescriptor.Role) -> [PluginDescriptor] {
        let query = AudioComponentDescription(componentType: type(for: role),
                                              componentSubType: 0,
                                              componentManufacturer: 0,
                                              componentFlags: 0,
                                              componentFlagsMask: 0)
        let found = AVAudioUnitComponentManager.shared().components(matching: query)
        return ordered(found.map { component in
            let description = component.audioComponentDescription
            return PluginDescriptor(type: description.componentType,
                                    subtype: description.componentSubType,
                                    manufacturer: description.componentManufacturer,
                                    name: component.name,
                                    manufacturerName: component.manufacturerName,
                                    version: component.version)
        })
    }
    #endif
}
