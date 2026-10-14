// PluginEffectInsert.swift
// Echoel — production H6-1 (founder 2026-10-13: „… auv3 Plugins für Effekte und MIDI Instrumente
// …"). A third-party Audio Unit EFFECT on a track, stored as one insert of the track's chain —
// the `GrainInsert` shape, in its own file so `DeviceChain.swift` keeps one subject.
//
// ⚠️ A SEPARATE TYPE ID AND A SEPARATE READER, ON PURPOSE. `DeviceInsert.pluginComponent` reads
// INSTRUMENT inserts only, and `MultiRollFanout.hostedInstrument` loads whatever it returns as an
// instrument. Widening that reader to accept effects would load an effect found in a foreign
// song's instrument slot as an instrument. So an effect insert answers `pluginEffectComponent`
// and never `pluginComponent`, and the reverse holds too.
//
// The state is the same sorted-keys JSON of `PluginComponent` the instrument uses; the unit's
// own settings ride under one more key later (H6, the H4a pattern). The chain keeps AT MOST ONE
// plugin effect — an array that could hold three while one sounds would be a claim.
//
// Nothing sounds from this file. The writer, the host and the graph insert are later slices
// (`scratchpads/PLAN_H6_EFFECT_PLUGINS_2026-10-14.md`).

import Foundation

extension DeviceInsert {
    public static let pluginEffectTypeID = "com.echoelmusic.device.auv3.effect"
    /// The state format this build reads and writes: sorted-keys JSON of `PluginComponent`.
    public static let pluginEffectTypeVersion = 1

    /// A fresh plugin-effect insert naming `component`.
    public static func pluginEffect(_ component: PluginComponent) -> DeviceInsert {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return DeviceInsert(typeID: pluginEffectTypeID, typeVersion: pluginEffectTypeVersion,
                            isEnabled: true, stateBlob: (try? encoder.encode(component)) ?? Data())
    }

    /// The effect this insert names, or nil when it is not a plugin effect, its state is a LATER
    /// format than this build reads, or the state does not decode — fails closed, so a later
    /// build's insert is kept byte for byte and never loaded with v1 meaning.
    public var pluginEffectComponent: PluginComponent? {
        guard typeID == Self.pluginEffectTypeID,
              typeVersion <= Self.pluginEffectTypeVersion else { return nil }
        return try? JSONDecoder().decode(PluginComponent.self, from: stateBlob)
    }
}

extension DeviceChain {
    /// The plugin-effect insert of this chain (the first one), enabled or not.
    public var pluginEffectInsert: DeviceInsert? {
        inserts.first { $0.typeID == DeviceInsert.pluginEffectTypeID }
    }

    /// The effect the track plays through, or nil for none: the first ENABLED plugin-effect insert
    /// this build can read.
    public var soundingPluginEffect: DeviceInsert.PluginComponent? {
        for insert in inserts where insert.isEnabled && insert.typeID == DeviceInsert.pluginEffectTypeID {
            if let component = insert.pluginEffectComponent { return component }
        }
        return nil
    }

    /// This chain with its plugin effect set to `component` (nil = none) — the `settingGrain`
    /// twin. Other inserts are kept in place, untouched; the instrument is never touched; a second
    /// plugin effect is dropped. The SAME component again keeps its insert as it is (its id, and
    /// later its saved settings); another component replaces the state. Nil when nothing is left.
    public func settingPluginEffect(_ component: DeviceInsert.PluginComponent?) -> DeviceChain? {
        var result = inserts
        let first = result.firstIndex { $0.typeID == DeviceInsert.pluginEffectTypeID }
        result = result.enumerated().compactMap { index, insert in
            insert.typeID == DeviceInsert.pluginEffectTypeID && index != first ? nil : insert
        }
        if let component {
            if let index = result.firstIndex(where: { $0.typeID == DeviceInsert.pluginEffectTypeID }) {
                if result[index].pluginEffectComponent != component {
                    let fresh = DeviceInsert.pluginEffect(component)
                    result[index].typeVersion = fresh.typeVersion
                    result[index].stateBlob = fresh.stateBlob
                }
                result[index].isEnabled = true
            } else {
                result.append(DeviceInsert.pluginEffect(component))
            }
        } else {
            result.removeAll { $0.typeID == DeviceInsert.pluginEffectTypeID }
        }
        var next = self
        next.inserts = result
        return next.isEmpty ? nil : next
    }
}
