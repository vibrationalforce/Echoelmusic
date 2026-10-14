// HostedInstrumentHost.swift
// Echoel — production level, slice H2b (founder 2026-10-13: „… auv3 Plugins für Effekte und MIDI
// Instrumente …"). Loads the Audio Unit instrument a rack track chose (`DeviceInsert
// .pluginInstrument`, written by `TimelineStore.setLanePluginInstrument`), hangs it into the master
// mix through `AudioEngine.attachAudioUnit`, and plays the track's notes on it as MIDI.
//
// ONE OWNER PER RACK SLOT. The region player names, per slot, which component it wants
// (`setInstrument(_:state:forSlot:)`) at the same points it names the slot's built-in kind; the app's
// note sink hands every slot's notes to `route(_:forSlot:)`, which sends a LOADED unit's notes
// here and returns the rest to `LaneVoiceRack`. So a playing plugin silences the built-in voice of
// that track — never the same note on both.
//
// WHAT IS NOT OURS. The unit renders in its own process; nothing in this file runs on the audio
// thread. MIDI goes through the unit's `scheduleMIDIEventBlock`, which the system documents as
// safe to call from any thread, stamped `AUEventSampleTimeImmediate` — note timing is the
// transport step's (main-actor) timing, like every rack voice's control plane.
//
// LOADING IS ASYNCHRONOUS and can take a few hundred milliseconds the first time. While a slot's
// unit is still loading, its attacks are played by the slot's BUILT-IN voice (P0-2, review of the
// hosting slices 2026-10-14: the first version dropped them, so a freshly chosen plugin opened
// with a hole of silence). Every release goes to whoever played its attack, so a note the built-in
// voice started while the unit loaded is never stranded when the unit arrives. Notes are not
// queued for the unit (a late burst would be worse than a missed attack). A load that finishes after the slot changed its mind is thrown away before it
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
    /// What each slot wants to play. Set before the load starts; the slot's attacks reach the unit
    /// once it is loaded, and the built-in voice while it loads (`route`).
    private var wanted: [Int: DeviceInsert.PluginComponent] = [:]
    private var hosted: [Int: Hosted] = [:]
    /// The level and pan the region player last asked for, applied when a unit arrives.
    private var mix: [Int: (gain: Float, pan: Float)] = [:]
    /// The component that could not be loaded on this device, per slot — not retried until the
    /// slot names something else or the media services reset.
    private var failed: [Int: DeviceInsert.PluginComponent] = [:]
    /// H4c — the settings the song keeps for the unit a slot is loading, applied when it arrives.
    private var pendingState: [Int: Data] = [:]
    /// H4d — the settings the LOADED unit of a slot was last given by the song or reported to it
    /// (`captureState`). A slot naming the same component with OTHER settings (another project
    /// opened, an older version restored) gets them applied; the same bytes coming back from the
    /// song after a capture change nothing, so a plugin the person is playing is never reset.
    private var appliedState: [Int: Data] = [:]
    private var transpose: [Int: Int] = [:]
    /// Per slot: the note number each held attack was sent with, keyed by the track's own pitch.
    private var sounding: [Int: [Int: UInt8]] = [:]
    /// Per slot: the pitches whose attack the BUILT-IN voice played while the unit loaded (P0-2).
    /// Their releases go back to the built-in voice, wherever the unit is by then.
    private var builtInHeld: [Int: Set<Int>] = [:]
    /// Per slot: the number of the newest load request. Only that request's answer may change the
    /// slot — the component alone cannot tell A's first load from A's second after A → B → A.
    private var loadRequest: [Int: Int] = [:]
    private var resetObserver: NSObjectProtocol?
    private var invalidationObserver: NSObjectProtocol?

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
        // A plugin whose extension process crashed is INVALIDATED: it renders nothing and takes no
        // MIDI. The system posts this per instance, with the dead `AUAudioUnit` as the object.
        invalidationObserver = NotificationCenter.default.addObserver(
            forName: Notification.Name(kAudioComponentInstanceInvalidationNotification as String),
            object: nil, queue: .main
        ) { @Sendable [weak self] note in
            guard let object = note.object else { return }
            let dead = ObjectIdentifier(object as AnyObject)
            Task { @MainActor in self?.forgetInvalidated(dead) }
        }
    }

    /// The one routing decision for a slot's notes (P0-2). A loaded unit gets the attacks; a slot
    /// with no unit, or whose unit is still loading, gives them back to the caller for the built-in
    /// voice. A release follows its attack. Returns what the built-in voice must play — never the
    /// same note to both.
    func route(_ events: [LaneNotePump.Event], forSlot slot: Int) -> [LaneNotePump.Event] {
        guard wanted[slot] != nil else {
            builtInHeld[slot] = nil
            return events
        }
        var builtIn: [LaneNotePump.Event] = []
        var unit: [LaneNotePump.Event] = []
        for event in events {
            if event.isOn {
                if hosted[slot] != nil {
                    unit.append(event)
                } else {
                    builtIn.append(event)
                    builtInHeld[slot, default: []].insert(event.pitch)
                }
            } else if builtInHeld[slot]?.remove(event.pitch) != nil {
                builtIn.append(event)
            } else {
                unit.append(event)
            }
        }
        if !unit.isEmpty { send(unit, toSlot: slot) }
        return builtIn
    }

    /// The one decision per slot: play `component`, or (nil) give the slot back to its built-in
    /// voice. Naming what the slot already wants with the settings it already has does nothing, so
    /// the player may say it on every load. `state` is the unit's own settings as the song keeps
    /// them (H4c): applied once the unit has loaded, applied in place to a loaded unit when they
    /// differ (H4d), and a unit that carries settings the song does not keep loads afresh (H4e).
    func setInstrument(_ component: DeviceInsert.PluginComponent?, state: Data?, forSlot slot: Int) {
        if wanted[slot] == component {
            // H4d (review of 1657030d6…8b1203e93, finding G): the same component with OTHER song
            // settings. Without this, a unit still loaded from project A kept A's sound in project
            // B, and closing its window then wrote A's settings into B.
            guard let component else { return }
            guard hosted[slot]?.component == component else {
                // Still loading: the newest settings win — nil too, so it never inherits another's.
                pendingState[slot] = state
                return
            }
            if let state {
                guard appliedState[slot] != state, let unit = hosted[slot]?.unit else { return }
                restore(state, to: unit, name: component.name)
                appliedState[slot] = state
                return
            }
            // H4e (deep audit 2026-10-14, Lieferung 1.1): the song keeps NO settings for this
            // unit, but the unit was given some — another project's track, or a song from before
            // the pick was kept. A unit cannot be reset to its defaults in place, so it loads
            // afresh. A unit nobody gave settings to (a fresh pick, its window still open) is
            // left alone, so an onset never resets what the person is playing.
            guard appliedState[slot] != nil else { return }
            log.audio("Plugin '\(component.name)' on rack slot \(slot) loads afresh — this song keeps no settings for it")
        }
        if let component, failed[slot] == component { return }   // keeps its built-in voice
        unload(slot)
        failed[slot] = nil
        guard let component, component.manufacturer != Self.ownManufacturer else { return }
        wanted[slot] = component
        pendingState[slot] = state
        let description = AudioComponentDescription(componentType: component.type,
                                                    componentSubType: component.subtype,
                                                    componentManufacturer: component.manufacturer,
                                                    componentFlags: 0,
                                                    componentFlagsMask: 0)
        let request = (loadRequest[slot] ?? 0) &+ 1
        loadRequest[slot] = request
        AVAudioUnit.instantiate(with: description, options: []) { @Sendable [weak self] unit, error in
            let box = UnitBox(unit)
            let failure = error.map { String(describing: $0) }
            Task { @MainActor in
                self?.finishLoad(box.unit, failure: failure, slot: slot, component: component, request: request)
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
    /// `component` is the plugin the caller means: while stopped, a pick does not reach the host,
    /// so the slot can still hold the PREVIOUS plugin — that one is never shown as the new one.
    func requestView(forSlot slot: Int, expecting component: DeviceInsert.PluginComponent,
                     done: @escaping @MainActor @Sendable (UIViewController?) -> Void) -> Bool {
        guard hosted[slot]?.component == component else { return false }
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
    /// `component` as in `requestView`: the settings of a different plugin are never kept under
    /// this one's name.
    func captureState(forSlot slot: Int, expecting component: DeviceInsert.PluginComponent) -> Data? {
        guard hosted[slot]?.component == component,
              let unit = hosted[slot]?.unit,
              let state = unit.auAudioUnit.fullStateForDocument else { return nil }
        do {
            let data = try PropertyListSerialization.data(fromPropertyList: state, format: .binary, options: 0)
            // H4d: the song will hand these bytes back — nothing to re-apply. H4e: only bytes the
            // song can KEEP; settings over its limit are refused, the song hands back nil, and a
            // recorded capture would then reload the unit the person just set up.
            if data.count <= DeviceInsert.pluginStateLimit { appliedState[slot] = data }
            return data
        } catch {
            log.audio("Plugin '\(hosted[slot]?.component.name ?? "?")' settings could not be saved: \(error)", level: .warning)
            return nil
        }
    }

    // MARK: - Private

    private func finishLoad(_ unit: AVAudioUnit?, failure: String?, slot: Int,
                            component: DeviceInsert.PluginComponent, request: Int) {
        // Stale: a newer request was made for this slot (deep audit 2026-10-14, Lieferung 1.2 —
        // after A → B → A a late success OR a late failure of the FIRST A matched the component
        // check: the success attached the wrong instance, the failure marked A failed while the
        // second load was still coming). Then: the slot wants something else, or holds a unit.
        guard loadRequest[slot] == request else { return }
        guard wanted[slot] == component, hosted[slot] == nil else { return }
        guard let unit else {
            log.audio("Plugin '\(component.name)' could not be loaded: \(failure ?? "no unit") — the track plays its built-in voice",
                      level: .warning)
            wanted[slot] = nil
            failed[slot] = component
            return
        }
        guard engine.attachAudioUnit(unit, slot: slot) else {
            // Remember it, like a failed load: otherwise every later region onset instantiates
            // the plugin again, and each attempt can pause the running engine.
            wanted[slot] = nil
            failed[slot] = component
            return
        }
        if let data = pendingState.removeValue(forKey: slot) {
            restore(data, to: unit, name: component.name)
            appliedState[slot] = data
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

    /// H4c — give the unit back the settings the song kept. A state that is not a property list
    /// dictionary is skipped with a warning: the unit then plays its default sound, as before H4.
    private func restore(_ data: Data, to unit: AVAudioUnit, name: String) {
        do {
            guard let state = try PropertyListSerialization.propertyList(from: data, format: nil) as? [String: Any] else {
                log.audio("Plugin '\(name)' settings are not a dictionary — it plays its default sound", level: .warning)
                return
            }
            unit.auAudioUnit.fullStateForDocument = state
        } catch {
            log.audio("Plugin '\(name)' settings could not be read: \(error) — it plays its default sound", level: .warning)
        }
    }

    /// Silence the unit (all notes off on every channel), then take it out of the graph.
    private func unload(_ slot: Int) {
        wanted[slot] = nil
        pendingState[slot] = nil
        appliedState[slot] = nil
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

    /// A hosted unit's process died: take the dead unit out of the graph and give its slot back to
    /// the built-in voice. It is remembered as failed, so the next region onset does not load a
    /// crashing plugin again and again; picking it anew (or a media reset) tries once more.
    private func forgetInvalidated(_ dead: ObjectIdentifier) {
        guard let slot = hosted.first(where: { ObjectIdentifier($0.value.unit.auAudioUnit) == dead })?.key,
              let held = hosted.removeValue(forKey: slot) else { return }
        EchoelCrashLog.breadcrumb("plugin: '\(held.component.name)' stopped working — slot \(slot) back to its built-in voice")
        engine.detachAudioUnit(held.unit)
        wanted[slot] = nil
        pendingState[slot] = nil
        appliedState[slot] = nil
        sounding[slot] = nil
        failed[slot] = held.component
    }

    private func forgetAfterMediaReset() {
        log.audio("Media services were reset — hosted plugins will load again on the next play", level: .warning)
        for held in hosted.values { engine.detachAudioUnit(held.unit) }   // the engine outlives the reset
        hosted.removeAll()
        wanted.removeAll()
        pendingState.removeAll()
        appliedState.removeAll()
        failed.removeAll()
        sounding.removeAll()
    }
}
#endif
