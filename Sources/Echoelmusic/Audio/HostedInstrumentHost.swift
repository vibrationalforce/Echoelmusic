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
// itself. ⛔ The first version forgot the units WITHOUT detaching, "because the old graph is
// gone" — it is not: `AudioEngine.masterEngine` is ONE `AVAudioEngine` for the app's life, and the
// reset path restarts that same engine, so a dead unit stayed connected to the mixer and the next
// load added a second one (review of H2b, 2026-10-13). Now every unit is DETACHED (legal on a live
// engine object even when its unit is dead — no MIDI is sent to it), then forgotten, and the next
// prime loads it afresh.
//
// A COMPONENT THAT FAILED TO LOAD is remembered per slot, so the next region onset does not try
// again — every retry would mute the built-in voice while it waits. Naming another component, or
// a media reset, clears the memory.
//
// TRANSPOSE: the rack voices apply the track's Transpose inside themselves; a hosted unit gets
// MIDI, so the shift is added to the note number here, and a release uses the number its attack
// was SENT with, so a transpose change while a note is held never strands it. Detune and the
// octave doubler are rack-voice features and do not reach a hosted unit.
//
// THE PLUGIN'S OWN SCREEN (H3). `requestView(forSlot:done:)` asks the LOADED unit for its view
// controller only when the window opens, and nothing here keeps it: the window holds it while it is
// shown and drops it on close (a plugin's screen can cost real memory, and every instance shares
// one budget). The system completes the request off the main thread — the result crosses in a
// box and is handed over on the main actor. A nil controller is a real answer: the plugin has no
// screen of its own. A slot that is still loading, or has no unit, answers false at once.
//
// NEEDS-FOUNDER-VERIFY H2: a third-party instrument chosen on a rack track sounds on the device;
// no click beyond the short pause at load; it survives a headphone change and a media reset;
// nothing changes for a track with no plugin chosen.

import Foundation
#if canImport(AVFoundation)
import AVFoundation
#if canImport(UIKit)
import UIKit
#endif

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

    /// The one host the running app made (`EchoelmusicApp` builds it once, at start). The Device
    /// page reaches it here to open a plugin's own screen; weak, so nothing here keeps it alive.
    private(set) static weak var live: HostedInstrumentHost?

    private let engine: AudioEngine
    /// What each slot wants to play. Set before the load starts; a slot with an entry owns its
    /// notes (they reach the unit once it is loaded, and are dropped while it loads).
    private var wanted: [Int: DeviceInsert.PluginComponent] = [:]
    private var hosted: [Int: Hosted] = [:]
    /// The level and pan the region player last asked for, applied when a unit arrives.
    private var mix: [Int: (gain: Float, pan: Float)] = [:]
    /// The component that could not be loaded on this device, per slot — not retried until the
    /// slot names something else or the media services reset.
    private var failed: [Int: DeviceInsert.PluginComponent] = [:]
    private var transpose: [Int: Int] = [:]
    /// Per slot: the note number each held attack was sent with, keyed by the track's own pitch.
    private var sounding: [Int: [Int: UInt8]] = [:]
    private var resetObserver: NSObjectProtocol?

    init(engine: AudioEngine) {
        self.engine = engine
        Self.live = self
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
        if let component, failed[slot] == component { return }   // keeps its built-in voice
        unload(slot)
        failed[slot] = nil
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
            let velocity = event.velocity.isFinite ? event.velocity : 0
            let pitch: UInt8
            if velocity > 0 {
                pitch = UInt8(max(0, min(127, event.pitch + (transpose[slot] ?? 0))))
                sounding[slot, default: [:]][event.pitch] = pitch
            } else {
                pitch = sounding[slot]?.removeValue(forKey: event.pitch)
                    ?? UInt8(max(0, min(127, event.pitch + (transpose[slot] ?? 0))))
            }
            let bytes: [UInt8] = velocity > 0
                ? [0x90, pitch, UInt8(max(1, min(127, (velocity * 127).rounded())))]
                : [0x80, pitch, 0]
            bytes.withUnsafeBufferPointer { buffer in
                if let base = buffer.baseAddress { block(AUEventSampleTimeImmediate, 0, 3, base) }
            }
        }
    }

    /// The track's Transpose in semitones, added to every note this slot sends from now on.
    func setTranspose(slot: Int, semitones: Int) {
        transpose[slot] = max(-48, min(48, semitones))
    }

    /// The track's level and pan, on the unit's mixer input (`AVAudioMixing`, control plane).
    /// ⚠️ A mixer input's volume is 0…1; the rack's 0…2 boost above unity does not reach a unit.
    func setMix(slot: Int, gain: Float? = nil, pan: Float? = nil) {
        var current = mix[slot] ?? (gain: 1, pan: 0)
        if let gain { current.gain = gain.isFinite ? max(0, gain) : 0 }
        if let pan { current.pan = pan.isFinite ? max(-1, min(1, pan)) : 0 }
        mix[slot] = current
        if let unit = hosted[slot]?.unit { Self.apply(current, to: unit) }
    }

    #if canImport(UIKit)
    /// Carries the plugin's view controller across the completion handler's thread hop.
    private final class ControllerBox: @unchecked Sendable {
        let controller: UIViewController?
        init(_ controller: UIViewController?) { self.controller = controller }
    }

    /// Ask `slot`'s loaded unit for its own screen. False at once when the slot holds no loaded
    /// unit (nothing will be called); otherwise `done` runs once, on the main actor, with the
    /// controller or nil (the plugin has no screen of its own).
    func requestView(forSlot slot: Int,
                     done: @escaping @MainActor @Sendable (UIViewController?) -> Void) -> Bool {
        guard let unit = hosted[slot]?.unit else { return false }
        unit.auAudioUnit.requestViewController { @Sendable controller in
            let box = ControllerBox(controller)
            Task { @MainActor in done(box.controller) }
        }
        return true
    }
    #endif

    /// H4b — the loaded unit's own settings (`fullStateForDocument`) as a binary property list, for
    /// the song to keep; nil when the slot holds no loaded unit, the unit reports none, or the
    /// report is not a property list. Asked on the main actor when the plugin window closes — a
    /// rare, user-paced moment, never per step.
    func captureState(forSlot slot: Int) -> Data? {
        guard let unit = hosted[slot]?.unit,
              let state = unit.auAudioUnit.fullStateForDocument else { return nil }
        do {
            return try PropertyListSerialization.data(fromPropertyList: state, format: .binary, options: 0)
        } catch {
            log.audio("Plugin '\(hosted[slot]?.component.name ?? "?")' settings could not be saved: \(error)", level: .warning)
            return nil
        }
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
            failed[slot] = component
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
        sounding[slot] = nil
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
        for held in hosted.values { engine.detachAudioUnit(held.unit) }   // the engine outlives the reset
        hosted.removeAll()
        wanted.removeAll()
        failed.removeAll()
        sounding.removeAll()
    }
}
#endif
