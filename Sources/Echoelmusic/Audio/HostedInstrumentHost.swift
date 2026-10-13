// HostedInstrumentHost.swift
// Echoel — production level, slice H2b (founder 2026-10-13: „… auv3 Plugins für Effekte und MIDI
// Instrumente …"). Loads the Audio Unit instrument a rack track chose (`DeviceInsert
// .pluginInstrument`, written by `TimelineStore.setLanePluginInstrument`), hangs it into the master
// mix through `AudioEngine.attachAudioUnit`, and plays the track's notes on it as MIDI.
//
// ONE OWNER PER RACK SLOT. The region player names, per slot, which component it wants
// (`setInstrument(_:forSlot:)`) at the same points it names the slot's built-in kind; the app's
// note sink asks `owns(_:)` and sends a hosted slot's notes HERE instead of to `LaneVoiceRack`.
// So a chosen plugin silences the built-in voice of that track — never both at once.
//
// WHAT IS NOT OURS. The unit renders in its own process; nothing in this file runs on the audio
// thread. MIDI goes through the unit's `scheduleMIDIEventBlock`, which the system documents as
// safe to call from any thread, stamped `AUEventSampleTimeImmediate` — note timing is the
// transport step's (main-actor) timing, like every rack voice's control plane.
//
// LOADING IS ASYNCHRONOUS and can take a few hundred milliseconds the first time. Notes for a
// slot whose unit is still loading are DROPPED, not queued (a late burst would be worse than a
// missed attack). A load that finishes after the slot changed its mind is thrown away before it
// touches the graph. A component that cannot be loaded on this device (not installed, refused)
// gives the slot back to its built-in voice, so a song from another device still sounds.
//
// MEDIA-SERVICES RESET invalidates every out-of-process unit. The engine's own reset path has one
// owner (`AudioConfiguration.onMediaServicesReset`), so this host listens to the notification
// itself, forgets every unit WITHOUT touching the old graph, and forgets what each slot wanted —
// the next prime names it again and the unit is loaded afresh.
//
// NEEDS-FOUNDER-VERIFY H2: a third-party instrument chosen on a rack track sounds on the device;
// no click beyond the short pause at load; it survives a headphone change and a media reset;
// nothing changes for a track with no plugin chosen.

import Foundation
#if canImport(AVFoundation)
import AVFoundation

@MainActor
final class HostedInstrumentHost {

    /// 'Echo' — this app's own components (the Echoel AUv3) are never hosted inside the app.
    static let ownManufacturer: UInt32 = 0x4563_686F

    private struct Hosted {
        let component: DeviceInsert.PluginComponent
        let unit: AVAudioUnit
    }

    /// Carries the loaded unit across the completion handler's thread hop. The unit is touched
    /// only on the main actor after the hop.
    private final class UnitBox: @unchecked Sendable {
        let unit: AVAudioUnit?
        init(_ unit: AVAudioUnit?) { self.unit = unit }
    }

    private let engine: AudioEngine
    /// What each slot wants to play. Set before the load starts; a slot with an entry owns its
    /// notes (they reach the unit once it is loaded, and are dropped while it loads).
    private var wanted: [Int: DeviceInsert.PluginComponent] = [:]
    private var hosted: [Int: Hosted] = [:]
    /// The level and pan the region player last asked for, applied when a unit arrives.
    private var mix: [Int: (gain: Float, pan: Float)] = [:]
    private var resetObserver: NSObjectProtocol?

    init(engine: AudioEngine) {
        self.engine = engine
        #if os(iOS)
        resetObserver = NotificationCenter.default.addObserver(
            forName: AVAudioSession.mediaServicesWereResetNotification, object: nil, queue: .main
        ) { @Sendable [weak self] _ in
            Task { @MainActor in self?.forgetAfterMediaReset() }
        }
        #endif
    }

    /// Whether `slot`'s notes belong to a hosted unit (loaded or loading) instead of the rack.
    func owns(_ slot: Int) -> Bool { wanted[slot] != nil }

    /// The one decision per slot: play `component`, or (nil) give the slot back to its built-in
    /// voice. Naming what the slot already wants does nothing, so the player may say it on every
    /// load.
    func setInstrument(_ component: DeviceInsert.PluginComponent?, forSlot slot: Int) {
        guard wanted[slot] != component else { return }
        unload(slot)
        guard let component, component.manufacturer != Self.ownManufacturer else { return }
        wanted[slot] = component
        let description = AudioComponentDescription(componentType: component.type,
                                                    componentSubType: component.subtype,
                                                    componentManufacturer: component.manufacturer,
                                                    componentFlags: 0,
                                                    componentFlagsMask: 0)
        AVAudioUnit.instantiate(with: description, options: []) { @Sendable [weak self] unit, error in
            let box = UnitBox(unit)
            let failure = error.map { String(describing: $0) }
            Task { @MainActor in
                self?.finishLoad(box.unit, failure: failure, slot: slot, component: component)
            }
        }
    }

    /// The track's notes, as MIDI note-on / note-off on channel 1.
    func send(_ events: [LaneNotePump.Event], toSlot slot: Int) {
        guard let block = hosted[slot]?.unit.auAudioUnit.scheduleMIDIEventBlock else { return }
        for event in events {
            let pitch = UInt8(max(0, min(127, event.pitch)))
            let velocity = event.velocity.isFinite ? event.velocity : 0
            let bytes: [UInt8] = velocity > 0
                ? [0x90, pitch, UInt8(max(1, min(127, (velocity * 127).rounded())))]
                : [0x80, pitch, 0]
            bytes.withUnsafeBufferPointer { buffer in
                if let base = buffer.baseAddress { block(AUEventSampleTimeImmediate, 0, 3, base) }
            }
        }
    }

    /// The track's level and pan, on the unit's mixer input (`AVAudioMixing`, control plane).
    func setMix(slot: Int, gain: Float? = nil, pan: Float? = nil) {
        var current = mix[slot] ?? (gain: 1, pan: 0)
        if let gain { current.gain = gain.isFinite ? max(0, gain) : 0 }
        if let pan { current.pan = pan.isFinite ? max(-1, min(1, pan)) : 0 }
        mix[slot] = current
        if let unit = hosted[slot]?.unit { Self.apply(current, to: unit) }
    }

    // MARK: - Private

    private func finishLoad(_ unit: AVAudioUnit?, failure: String?, slot: Int,
                            component: DeviceInsert.PluginComponent) {
        // Stale: the slot wants something else now, or already holds a unit.
        guard wanted[slot] == component, hosted[slot] == nil else { return }
        guard let unit else {
            log.audio("Plugin '\(component.name)' could not be loaded: \(failure ?? "no unit") — the track plays its built-in voice",
                      level: .warning)
            wanted[slot] = nil
            return
        }
        guard engine.attachAudioUnit(unit) else {
            wanted[slot] = nil
            return
        }
        hosted[slot] = Hosted(component: component, unit: unit)
        Self.apply(mix[slot] ?? (gain: 1, pan: 0), to: unit)
        log.audio("Plugin '\(component.name)' by \(component.manufacturerName) plays rack slot \(slot)")
    }

    /// A music-device unit is an `AVAudioUnitMIDIInstrument`, which mixes (`AVAudioMixing`); the
    /// plain `AVAudioUnit` type does not promise it, so the cast is asked, not assumed.
    private static func apply(_ mix: (gain: Float, pan: Float), to unit: AVAudioUnit) {
        guard let mixing = unit as? AVAudioMixing else { return }
        mixing.volume = mix.gain
        mixing.pan = mix.pan
    }

    /// Silence the unit (all notes off on every channel), then take it out of the graph.
    private func unload(_ slot: Int) {
        wanted[slot] = nil
        guard let held = hosted.removeValue(forKey: slot) else { return }
        if let block = held.unit.auAudioUnit.scheduleMIDIEventBlock {
            for channel: UInt8 in 0..<16 {
                let bytes: [UInt8] = [0xB0 | channel, 123, 0]
                bytes.withUnsafeBufferPointer { buffer in
                    if let base = buffer.baseAddress { block(AUEventSampleTimeImmediate, 0, 3, base) }
                }
            }
        }
        engine.detachAudioUnit(held.unit)
    }

    private func forgetAfterMediaReset() {
        log.audio("Media services were reset — hosted plugins will load again on the next play", level: .warning)
        hosted.removeAll()
        wanted.removeAll()
    }
}
#endif
