import AudioToolbox
import AVFoundation
import Foundation

/// The steps that make a loaded Audio Unit — Apple's, Echoel's or another maker's — ready to play
/// inside the engine's render pass, in the order units expect them. Main thread, before the unit
/// reaches the render thread; nothing here runs while it renders.
///
/// 1. The song's saved settings (`fullStateForDocument`). Some units rebuild their busses or
///    their parameter tree from them, so they come before anything is negotiated with the busses.
/// 2. The main busses switched on — the input first for an effect, whose output may follow it.
///    A unit renders only enabled busses; one whose input stayed off refuses every block.
/// 3. Stereo at the engine's rate on each of them, set only where the bus is not already in a
///    layout the engine's render blocks read and fill (`UnitFormat.accepts`) at that rate.
/// 4. The engine's largest block, the host blocks that carry tempo and transport, offline for an
///    export, then render resources — most units read the host blocks only when they allocate.
public enum UnitPreparation {
    public enum Failure: Error, Equatable {
        /// The unit has no output bus (or an effect no input bus) to play through.
        case noOutput, noInput
        /// The bus does not take stereo, 32-bit float, one buffer per channel, at the engine's rate.
        case formatRefused(isInput: Bool)
    }

    /// `state` is the property list the song stores for the unit (`fullStateForDocument`); one
    /// that cannot be read is skipped and the unit starts from its own defaults.
    public static func prepare(_ unit: AUAudioUnit, isEffect: Bool, sampleRate: Double, maximumFrames: Int,
                               state: Data?, clock: HostClock?, offline: Bool = false) throws {
        if let state, let settings = settings(from: state) {
            unit.fullStateForDocument = settings
        }
        try negotiateBusses(unit, isEffect: isEffect, sampleRate: sampleRate)
        unit.maximumFramesToRender = AUAudioFrameCount(Swift.max(1, maximumFrames))
        if let clock {
            unit.musicalContextBlock = clock.musicalContextBlock
            unit.transportStateBlock = clock.transportStateBlock
        }
        if offline { unit.isRenderingOffline = true }
        try unit.allocateRenderResources()
    }

    /// Steps 2 and 3: the main busses on and in stereo at `sampleRate`.
    public static func negotiateBusses(_ unit: AUAudioUnit, isEffect: Bool, sampleRate: Double) throws {
        guard unit.outputBusses.count > 0 else { throw Failure.noOutput }
        if isEffect {
            guard unit.inputBusses.count > 0 else { throw Failure.noInput }
            try negotiate(unit.inputBusses[0], sampleRate: sampleRate, isInput: true)
        }
        try negotiate(unit.outputBusses[0], sampleRate: sampleRate, isInput: false)
    }

    private static func negotiate(_ bus: AUAudioUnitBus, sampleRate: Double, isInput: Bool) throws {
        bus.isEnabled = true
        let current = bus.format
        if current.sampleRate == sampleRate, UnitFormat.accepts(current) { return }
        guard let stereo = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 2) else {
            throw Failure.formatRefused(isInput: isInput)
        }
        do {
            try bus.setFormat(stereo)
        } catch {
            throw Failure.formatRefused(isInput: isInput)
        }
    }

    /// The settings a song stores for a unit, read back; nil when they are not a dictionary.
    public static func settings(from state: Data) -> [String: Any]? {
        try? PropertyListSerialization.propertyList(from: state, format: nil) as? [String: Any]
    }
}
