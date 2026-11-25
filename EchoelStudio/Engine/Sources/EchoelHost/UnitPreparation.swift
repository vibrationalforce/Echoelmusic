import AudioToolbox
import AVFoundation
import Foundation

/// The steps that make a loaded Audio Unit — Apple's, Echoel's or another maker's — ready to play
/// inside the engine's render pass, in the order units expect them. Main thread, before the unit
/// reaches the render thread; nothing here runs while it renders.
///
/// 1. The song's saved settings (`fullStateForDocument`). Some units rebuild their busses or
///    their parameter tree from them, so they come before anything is negotiated with the busses.
/// 2. The main busses switched on. A unit renders only enabled busses; one whose input stayed
///    off refuses every block.
/// 3. The engine's largest block, the host blocks that carry tempo and transport, offline for an
///    export — most units read the host blocks only when they allocate.
/// 4. A layout on the busses (the input first for an effect, whose output may follow it) and
///    render resources: stereo at the engine's rate, set only where a bus is not already in it,
///    else mono or a mixed layout, whichever the unit first allocates with (`candidates`).
public enum UnitPreparation {
    public enum Failure: Error, Equatable {
        /// The unit has no output bus (or an effect no input bus) to play through.
        case noOutput, noInput
        /// The bus takes neither stereo nor mono 32-bit float at the engine's rate.
        case formatRefused(isInput: Bool)
    }

    /// The channels the main busses ended with: 2, or 1 for a bus that takes mono only. An
    /// instrument has no input (`inputChannels` 0).
    public struct Layout: Equatable, Sendable {
        public let inputChannels: Int
        public let outputChannels: Int
        public init(inputChannels: Int, outputChannels: Int) {
            self.inputChannels = inputChannels
            self.outputChannels = outputChannels
        }
    }

    /// `state` is the property list the song stores for the unit (`fullStateForDocument`); one
    /// that cannot be read is skipped and the unit starts from its own defaults.
    @discardableResult
    public static func prepare(_ unit: AUAudioUnit, isEffect: Bool, sampleRate: Double, maximumFrames: Int,
                               state: Data?, clock: HostClock?, offline: Bool = false) throws -> Layout {
        if let state, let settings = settings(from: state) {
            unit.fullStateForDocument = settings
        }
        guard unit.outputBusses.count > 0 else { throw Failure.noOutput }
        if isEffect, unit.inputBusses.count == 0 { throw Failure.noInput }
        if isEffect { unit.inputBusses[0].isEnabled = true }
        unit.outputBusses[0].isEnabled = true
        unit.maximumFramesToRender = AUAudioFrameCount(Swift.max(1, maximumFrames))
        if let clock {
            unit.musicalContextBlock = clock.musicalContextBlock
            unit.transportStateBlock = clock.transportStateBlock
        }
        if offline { unit.isRenderingOffline = true }
        // Some units take a format when it is set and refuse it only when they allocate — those
        // built on Apple's version-2 SDK, and units that state their channels
        // (`channelCapabilities`) without checking a format as it is set. So each layout is tried
        // up to the allocation, stereo first; the first one the unit allocates with is the one.
        var refusal: Error = Failure.formatRefused(isInput: false)
        for layout in candidates(isEffect: isEffect) {
            do {
                try apply(layout, to: unit, sampleRate: sampleRate)
            } catch {
                refusal = error
                continue
            }
            do {
                try unit.allocateRenderResources()
                return layout
            } catch {
                refusal = error
                if unit.renderResourcesAllocated { unit.deallocateRenderResources() }
            }
        }
        throw refusal
    }

    /// The layouts a host plays through, in the order they are tried: stereo, then mono, then
    /// the two mixed ones an effect may have (mono in and stereo out, or the other way).
    static func candidates(isEffect: Bool) -> [Layout] {
        isEffect
            ? [Layout(inputChannels: 2, outputChannels: 2), Layout(inputChannels: 1, outputChannels: 1),
               Layout(inputChannels: 1, outputChannels: 2), Layout(inputChannels: 2, outputChannels: 1)]
            : [Layout(inputChannels: 0, outputChannels: 2), Layout(inputChannels: 0, outputChannels: 1)]
    }

    /// Both main busses in `layout` at `sampleRate`, the input first.
    private static func apply(_ layout: Layout, to unit: AUAudioUnit, sampleRate: Double) throws {
        if layout.inputChannels > 0 {
            try set(unit.inputBusses[0], channels: layout.inputChannels, sampleRate: sampleRate, isInput: true)
        }
        try set(unit.outputBusses[0], channels: layout.outputChannels, sampleRate: sampleRate, isInput: false)
    }

    /// A bus already in that layout at that rate is left as it is — a unit with a fixed format
    /// may refuse even a change to the format it has.
    private static func set(_ bus: AUAudioUnitBus, channels: Int, sampleRate: Double, isInput: Bool) throws {
        let current = bus.format
        let fits = channels == 2 ? UnitFormat.accepts(current)
            : current.commonFormat == .pcmFormatFloat32 && current.channelCount == 1
        if current.sampleRate == sampleRate, fits { return }
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate,
                                         channels: AVAudioChannelCount(channels)),
              (try? bus.setFormat(format)) != nil else {
            throw Failure.formatRefused(isInput: isInput)
        }
    }

    /// The settings a song stores for a unit, read back; nil when they are not a dictionary.
    public static func settings(from state: Data) -> [String: Any]? {
        try? PropertyListSerialization.propertyList(from: state, format: nil) as? [String: Any]
    }
}
