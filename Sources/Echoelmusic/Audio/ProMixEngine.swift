// ProMixEngine.swift
// Echoelmusic - Professional Mixing Engine
//
// Full-featured mixing console with channel strips, routing matrix,
// automation, sends/returns, insert effects, and mix snapshots.
// Designed for professional music producers (Logic Pro, Ableton, Pro Tools users).
//
// Created by Echoelmusic Team
// Copyright 2026 Echoelmusic. MIT License.

import Foundation
import AVFoundation
import Combine

// MARK: - Channel Color

/// Visual color assignments for channel strips in the mixer UI.
public enum ChannelColor: String, CaseIterable, Codable, Sendable {
    case red, orange, yellow, green, cyan, blue, purple, pink
    case coral, teal, indigo, magenta, slate, cream
}

// MARK: - Channel Type

/// Classification of mixer channel types.
public enum ChannelType: String, CaseIterable, Codable, Sendable {
    case audio
    case instrument
    case aux
    case bus
    case master
    case send
}

// MARK: - Input Source

/// Available input sources for a channel strip.
public enum InputSource: String, Codable, Sendable {
    case none
    case mic
    case lineIn
    case bus
    case sidechain
}

// MARK: - Pro Effect Type

/// Professional-grade audio effect types available for insert slots.
public enum ProEffectType: String, CaseIterable, Codable, Sendable {
    // EQ
    case parametricEQ
    case graphicEQ
    case midSideEQ
    case dynamicEQ

    // Dynamics
    case compressor
    case multibandCompressor
    case limiter
    case gate
    case deEsser
    case transientShaper
    case sidechain

    // Saturation / Color
    case saturation
    case tapeEmulation
    case tubeWarmth

    // Reverb
    case convolutionReverb
    case algorithmicReverb
    case plateReverb
    case springReverb
    case shimmerReverb

    // Delay
    case stereoDelay
    case pingPongDelay
    case tapeDelay
    case analogDelay

    // Modulation
    case chorus
    case flanger
    case phaser
    case tremolo
    case rotarySpeaker

    // Pitch
    case pitchShift
    case harmonizer
    case vocoder

    // Lo-Fi / Creative
    case bitCrusher
    case lofi

    // Stereo / Imaging
    case stereoWidener
}

// MARK: - Automation Curve Type

/// Interpolation curve types for automation data.
public enum AutomationCurveType: String, Codable, Sendable {
    case linear
    case exponential
    case sCurve
    case hold
}

// MARK: - Automation Parameter

/// Parameters that can be automated across the mixing session.
public enum AutomationParameter: Codable, Sendable, Hashable {
    case volume
    case pan
    case mute
    case sendLevel
    case insertParam
    case auxLevel
    case filterCutoff
    case filterResonance
    case reverbMix
    case delayMix
    case compThreshold
    case eqBand1
    case eqBand2
    case eqBand3
    case eqBand4
    case eqBand5
    case eqBand6
    case eqBand7
    case eqBand8
    case custom(String)
}

// MARK: - Meter State

/// Real-time metering data for a channel strip.
public struct MeterState: Codable, Sendable {
    /// Current peak level (0-1).
    public var peak: Float
    /// Current RMS level (0-1).
    public var rms: Float
    /// Peak-hold level (0-1), decays over time.
    public var peakHold: Float
    /// Whether the channel is currently clipping.
    public var isClipping: Bool

    public init(peak: Float = 0, rms: Float = 0, peakHold: Float = 0, isClipping: Bool = false) {
        self.peak = peak
        self.rms = rms
        self.peakHold = peakHold
        self.isClipping = isClipping
    }
}

// MARK: - Insert Slot

/// A single insert effect slot on a channel strip, with up to 8 per channel.
public struct InsertSlot: Identifiable, Codable, Sendable {
    public let id: UUID
    /// The effect type loaded into this slot.
    public var effectType: ProEffectType
    /// Whether this insert is bypassed.
    public var isEnabled: Bool
    /// Dry/wet blend (0 = fully dry, 1 = fully wet).
    public var dryWet: Float
    /// Effect-specific parameter values keyed by parameter name.
    public var parameters: [String: Float]

    public init(
        id: UUID = UUID(),
        effectType: ProEffectType,
        isEnabled: Bool = true,
        dryWet: Float = 1.0,
        parameters: [String: Float] = [:]
    ) {
        self.id = id
        self.effectType = effectType
        self.isEnabled = isEnabled
        self.dryWet = clamp(dryWet, 0, 1)
        self.parameters = parameters
    }
}

// MARK: - Send Slot

/// A send routing slot on a channel strip, with up to 8 per channel.
public struct SendSlot: Identifiable, Codable, Sendable {
    public let id: UUID
    /// The destination aux/bus channel UUID.
    public var destinationID: UUID?
    /// Send level (0-1).
    public var level: Float
    /// If true, the send taps before the channel fader.
    public var isPreFader: Bool
    /// Whether this send is active.
    public var isEnabled: Bool

    public init(
        id: UUID = UUID(),
        destinationID: UUID? = nil,
        level: Float = 0.0,
        isPreFader: Bool = false,
        isEnabled: Bool = true
    ) {
        self.id = id
        self.destinationID = destinationID
        self.level = clamp(level, 0, 1)
        self.isPreFader = isPreFader
        self.isEnabled = isEnabled
    }
}

// MARK: - Channel Strip

/// A professional channel strip with volume, pan, inserts, sends, metering, and routing.
public struct ChannelStrip: Identifiable, Codable, Sendable {

    // MARK: Identity

    public let id: UUID
    /// Display name shown in the mixer UI.
    public var name: String
    /// The type of this channel (audio, instrument, aux, bus, master, send).
    public var type: ChannelType

    // MARK: Level & Pan

    /// Fader level (0-1, default 0.8).
    public var volume: Float {
        didSet { volume = clamp(volume, 0, 1) }
    }
    /// Stereo pan position (-1 = hard left, 0 = center, 1 = hard right).
    public var pan: Float {
        didSet { pan = clamp(pan, -1, 1) }
    }

    // MARK: State

    /// Whether the channel output is muted.
    public var mute: Bool
    /// Whether the channel is soloed.
    public var solo: Bool
    /// Whether the channel is armed for recording.
    public var isArmed: Bool

    // MARK: Routing

    /// Insert effect chain (up to 8 slots).
    public var inserts: [InsertSlot]
    /// Send routing slots (up to 8 slots).
    public var sends: [SendSlot]
    /// Where this channel receives its signal from.
    public var inputSource: InputSource
    /// The bus or master channel this channel routes its output to.
    public var outputDestination: UUID?

    // MARK: Appearance

    /// Color label for the channel strip in the mixer UI.
    public var color: ChannelColor

    // MARK: Metering

    /// Real-time metering state.
    public var metering: MeterState

    // MARK: Initialization

    public init(
        id: UUID = UUID(),
        name: String,
        type: ChannelType,
        volume: Float = 0.8,
        pan: Float = 0.0,
        mute: Bool = false,
        solo: Bool = false,
        isArmed: Bool = false,
        inserts: [InsertSlot] = [],
        sends: [SendSlot] = [],
        inputSource: InputSource = .none,
        outputDestination: UUID? = nil,
        color: ChannelColor = .blue,
        metering: MeterState = MeterState()
    ) {
        self.id = id
        self.name = name
        self.type = type
        self.volume = clamp(volume, 0, 1)
        self.pan = clamp(pan, -1, 1)
        self.mute = mute
        self.solo = solo
        self.isArmed = isArmed
        self.inserts = inserts
        self.sends = sends
        self.inputSource = inputSource
        self.outputDestination = outputDestination
        self.color = color
        self.metering = metering
    }

    /// The maximum number of insert slots per channel.
    public static let maxInserts = 8
    /// The maximum number of send slots per channel.
    public static let maxSends = 8
}

// MARK: - Automation Point

/// A single automation breakpoint with a time, value, and interpolation curve.
public struct AutomationPoint: Codable, Sendable, Comparable {
    /// Position in the timeline (seconds).
    public var time: TimeInterval
    /// Parameter value at this point (0-1 normalized).
    public var value: Float
    /// How to interpolate from the previous point to this one.
    public var curveType: AutomationCurveType

    public init(time: TimeInterval, value: Float, curveType: AutomationCurveType = .linear) {
        self.time = time
        self.value = clamp(value, 0, 1)
        self.curveType = curveType
    }

    public static func < (lhs: AutomationPoint, rhs: AutomationPoint) -> Bool {
        lhs.time < rhs.time
    }
}

// MARK: - Automation Lane

/// An automation lane that stores and evaluates time-varying parameter data for a channel.
public struct AutomationLane: Identifiable, Codable, Sendable {
    public let id: UUID
    /// The parameter this lane controls.
    public var parameter: AutomationParameter
    /// The channel strip this lane is bound to.
    public var channelID: UUID
    /// Sorted breakpoints describing the automation curve.
    public var points: [AutomationPoint]
    /// Whether this lane's automation is applied during playback.
    public var isEnabled: Bool
    /// Whether this lane is actively recording new automation data.
    public var isRecording: Bool

    public init(
        id: UUID = UUID(),
        parameter: AutomationParameter,
        channelID: UUID,
        points: [AutomationPoint] = [],
        isEnabled: Bool = true,
        isRecording: Bool = false
    ) {
        self.id = id
        self.parameter = parameter
        self.channelID = channelID
        self.points = points.sorted()
        self.isEnabled = isEnabled
        self.isRecording = isRecording
    }

    // MARK: Interpolation

    /// Returns the interpolated value at the given time.
    ///
    /// Handles edge cases (no points, before first point, after last point)
    /// and supports linear, exponential, s-curve, and hold interpolation.
    public func valueAt(time: TimeInterval) -> Float {
        guard !points.isEmpty else { return 0 }

        // Before the first point
        if let first = points.first, time <= first.time {
            return first.value
        }

        // After the last point
        if let last = points.last, time >= last.time {
            return last.value
        }

        // Find the surrounding breakpoint pair
        for i in 0..<(points.count - 1) {
            let a = points[i]
            let b = points[i + 1]

            if time >= a.time && time <= b.time {
                let span = b.time - a.time
                guard span > 0 else { return a.value }
                let t = Float((time - a.time) / span)

                switch b.curveType {
                case .linear:
                    return a.value + (b.value - a.value) * t

                case .exponential:
                    let curved = t * t
                    return a.value + (b.value - a.value) * curved

                case .sCurve:
                    // Smoothstep: 3t^2 - 2t^3
                    let s = t * t * (3.0 - 2.0 * t)
                    return a.value + (b.value - a.value) * s

                case .hold:
                    return a.value
                }
            }
        }

        return points.last?.value ?? 0
    }
}

// MARK: - Routing Connection

/// A single signal routing connection between two channels.
public struct RoutingConnection: Identifiable, Codable, Sendable {
    public let id: UUID
    /// Source channel UUID.
    public var sourceID: UUID
    /// Destination channel UUID.
    public var destinationID: UUID
    /// Routing level (0-1).
    public var level: Float

    public init(
        id: UUID = UUID(),
        sourceID: UUID,
        destinationID: UUID,
        level: Float = 1.0
    ) {
        self.id = id
        self.sourceID = sourceID
        self.destinationID = destinationID
        self.level = clamp(level, 0, 1)
    }
}

// MARK: - Routing Matrix

/// Manages all signal routing connections in the mixer, resolving destinations for any channel.
public struct RoutingMatrix: Codable, Sendable {
    /// All active routing connections.
    public var connections: [RoutingConnection]

    public init(connections: [RoutingConnection] = []) {
        self.connections = connections
    }

    /// Returns all destination channel UUIDs for the given source channel.
    public func resolve(for sourceID: UUID) -> [UUID] {
        connections
            .filter { $0.sourceID == sourceID && $0.level > 0 }
            .map { $0.destinationID }
    }

    /// Adds a new routing connection between two channels.
    public mutating func addConnection(from sourceID: UUID, to destinationID: UUID, level: Float = 1.0) {
        // Prevent duplicate connections
        guard !connections.contains(where: { $0.sourceID == sourceID && $0.destinationID == destinationID }) else {
            // Update existing connection level instead
            if let index = connections.firstIndex(where: { $0.sourceID == sourceID && $0.destinationID == destinationID }) {
                connections[index].level = clamp(level, 0, 1)
            }
            return
        }
        let connection = RoutingConnection(sourceID: sourceID, destinationID: destinationID, level: level)
        connections.append(connection)
    }

    /// Removes the routing connection between two channels.
    public mutating func removeConnection(from sourceID: UUID, to destinationID: UUID) {
        connections.removeAll { $0.sourceID == sourceID && $0.destinationID == destinationID }
    }
}

// MARK: - Channel Snapshot

/// A serializable snapshot of a single channel strip's state.
public struct ChannelSnapshot: Codable, Sendable, Identifiable {
    public let id: UUID
    public var channelID: UUID
    public var volume: Float
    public var pan: Float
    public var mute: Bool
    public var solo: Bool
    public var sends: [SendSlot]
    public var inserts: [InsertSlot]

    public init(
        id: UUID = UUID(),
        channelID: UUID,
        volume: Float,
        pan: Float,
        mute: Bool,
        solo: Bool,
        sends: [SendSlot],
        inserts: [InsertSlot]
    ) {
        self.id = id
        self.channelID = channelID
        self.volume = volume
        self.pan = pan
        self.mute = mute
        self.solo = solo
        self.sends = sends
        self.inserts = inserts
    }
}

// MARK: - Mix Snapshot

/// A complete, serializable snapshot of the entire mixer state for recall.
public struct MixSnapshot: Identifiable, Codable, Sendable {
    public let id: UUID
    /// User-assigned name for this snapshot.
    public var name: String
    /// When this snapshot was captured.
    public var date: Date
    /// Saved state for every channel strip.
    public var channelStates: [ChannelSnapshot]

    public init(
        id: UUID = UUID(),
        name: String,
        date: Date = Date(),
        channelStates: [ChannelSnapshot] = []
    ) {
        self.id = id
        self.name = name
        self.date = date
        self.channelStates = channelStates
    }
}

// MARK: - Pro Mix Engine

/// Professional mixing engine with full channel strip, routing, automation, and snapshot support.
///
/// Provides a DAW-grade mixing console suitable for music production workflows
/// comparable to Logic Pro, Ableton Live, and Pro Tools.
///
/// Usage:
/// ```swift
/// let mixer = ProMixEngine.defaultSession()
/// let track = mixer.addChannel(name: "Vocals", type: .audio)
/// mixer.addInsert(to: track.id, effect: .compressor)
/// mixer.addSend(from: track.id, to: reverbBusID, level: 0.35, preFader: false)
/// mixer.processBlock(frameCount: 256)
/// ```
@MainActor
public class ProMixEngine: ObservableObject {

    // MARK: - Published Properties

    /// All channel strips in the mixer (excluding master).
    @Published public var channels: [ChannelStrip] = []

    /// The master output channel strip.
    @Published public var masterChannel: ChannelStrip

    /// Transport state: whether the session is playing.
    @Published public var isPlaying: Bool = false

    /// Current playback position (seconds).
    @Published public var currentTime: TimeInterval = 0

    // MARK: - Automation

    /// All automation lanes across the session.
    public var automationLanes: [AutomationLane] = []

    // MARK: - Routing

    /// The signal routing matrix that resolves all connections.
    public var routingMatrix: RoutingMatrix = RoutingMatrix()

    // MARK: - Audio Configuration

    /// Session sample rate in Hz.
    public let sampleRate: Double

    /// Audio buffer size in frames.
    public let bufferSize: Int

    // MARK: - Private

    private let logger = ProfessionalLogger.shared
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    /// Creates a new ProMixEngine with the specified audio configuration.
    ///
    /// - Parameters:
    ///   - sampleRate: Session sample rate in Hz (default: 48000).
    ///   - bufferSize: Audio buffer size in frames (default: 256).
    public init(sampleRate: Double = 48000, bufferSize: Int = 256) {
        self.sampleRate = sampleRate
        self.bufferSize = bufferSize
        self.masterChannel = ChannelStrip(
            name: "Master",
            type: .master,
            volume: 1.0,
            pan: 0.0,
            inputSource: .bus,
            color: .slate
        )
        logger.log(.info, category: .audio, "ProMixEngine initialized (\(sampleRate)Hz, \(bufferSize) frames)")
    }

    // MARK: - Channel Management

    /// Adds a new channel strip to the mixer.
    ///
    /// - Parameters:
    ///   - name: Display name for the channel.
    ///   - type: Channel type (audio, instrument, aux, bus, master, send).
    /// - Returns: The newly created channel strip.
    @discardableResult
    public func addChannel(name: String, type: ChannelType) -> ChannelStrip {
        let channel = ChannelStrip(
            name: name,
            type: type,
            outputDestination: masterChannel.id,
            color: defaultColor(for: channels.count)
        )
        channels.append(channel)

        // Route to master by default
        routingMatrix.addConnection(from: channel.id, to: masterChannel.id)

        logger.log(.debug, category: .audio, "Added channel '\(name)' (\(type.rawValue))")
        return channel
    }

    /// Removes a channel strip from the mixer by its UUID.
    ///
    /// Also cleans up any routing connections and automation lanes referencing the channel.
    public func removeChannel(id: UUID) {
        guard let index = channels.firstIndex(where: { $0.id == id }) else { return }
        let name = channels[index].name

        // Clean up routing connections
        routingMatrix.connections.removeAll { $0.sourceID == id || $0.destinationID == id }

        // Clean up sends referencing this channel on other strips
        for i in channels.indices {
            channels[i].sends.removeAll { $0.destinationID == id }
        }

        // Clean up automation lanes
        automationLanes.removeAll { $0.channelID == id }

        channels.remove(at: index)
        logger.log(.debug, category: .audio, "Removed channel '\(name)'")
    }

    // MARK: - Insert Effects

    /// Adds an insert effect to a channel strip.
    ///
    /// Respects the maximum of 8 inserts per channel.
    ///
    /// - Parameters:
    ///   - channelID: The UUID of the target channel.
    ///   - effect: The effect type to insert.
    /// - Returns: The created insert slot, or nil if the channel was not found or inserts are full.
    @discardableResult
    public func addInsert(to channelID: UUID, effect: ProEffectType) -> InsertSlot? {
        guard let index = channelIndex(for: channelID) else { return nil }
        guard channels[index].inserts.count < ChannelStrip.maxInserts else {
            logger.log(.warning, category: .audio, "Insert limit reached on '\(channels[index].name)'")
            return nil
        }

        let slot = InsertSlot(effectType: effect, parameters: defaultParameters(for: effect))
        channels[index].inserts.append(slot)

        logger.log(.debug, category: .audio, "Added \(effect.rawValue) insert to '\(channels[index].name)'")
        return slot
    }

    // MARK: - Send Routing

    /// Creates a send from one channel to an aux/bus destination.
    ///
    /// - Parameters:
    ///   - sourceID: The source channel UUID.
    ///   - destinationID: The destination aux/bus channel UUID.
    ///   - level: Send level (0-1).
    ///   - preFader: Whether the send taps before the fader.
    public func addSend(from sourceID: UUID, to destinationID: UUID, level: Float = 0.5, preFader: Bool = false) {
        guard let index = channelIndex(for: sourceID) else { return }
        guard channels[index].sends.count < ChannelStrip.maxSends else {
            logger.log(.warning, category: .audio, "Send limit reached on '\(channels[index].name)'")
            return
        }

        let send = SendSlot(
            destinationID: destinationID,
            level: level,
            isPreFader: preFader,
            isEnabled: true
        )
        channels[index].sends.append(send)

        logger.log(.debug, category: .audio, "Added send from '\(channels[index].name)' to destination (level: \(level))")
    }

    // MARK: - Bus & Aux Management

    /// Creates a new auxiliary bus channel (e.g., for reverb or delay returns).
    ///
    /// - Parameter name: Display name for the aux bus.
    /// - Returns: The newly created aux channel strip.
    @discardableResult
    public func createAuxBus(name: String) -> ChannelStrip {
        let aux = addChannel(name: name, type: .aux)
        logger.log(.info, category: .audio, "Created aux bus '\(name)'")
        return aux
    }

    /// Creates a bus group that sums a set of channels before routing to master.
    ///
    /// - Parameters:
    ///   - name: Display name for the bus group.
    ///   - channelIDs: The UUIDs of channels to route into this bus.
    /// - Returns: The newly created bus channel strip.
    @discardableResult
    public func createBusGroup(name: String, channelIDs: [UUID]) -> ChannelStrip {
        let bus = addChannel(name: name, type: .bus)

        for channelID in channelIDs {
            guard let index = channelIndex(for: channelID) else { continue }

            // Reroute channel output from master to this bus
            routingMatrix.removeConnection(from: channelID, to: masterChannel.id)
            routingMatrix.addConnection(from: channelID, to: bus.id)
            channels[index].outputDestination = bus.id
        }

        logger.log(.info, category: .audio, "Created bus group '\(name)' with \(channelIDs.count) channels")
        return bus
    }

    // MARK: - Sidechain

    /// Configures sidechain routing so that one channel's signal triggers a compressor on another.
    ///
    /// - Parameters:
    ///   - compressorChannelID: The channel with the compressor that should receive the sidechain input.
    ///   - sidechainSourceID: The channel whose signal drives the compressor's detector.
    public func setSidechain(compressorChannelID: UUID, sidechainSourceID: UUID) {
        guard let index = channelIndex(for: compressorChannelID) else { return }

        // Find or create a sidechain insert
        if let insertIndex = channels[index].inserts.firstIndex(where: { $0.effectType == .sidechain || $0.effectType == .compressor }) {
            channels[index].inserts[insertIndex].parameters["sidechainSourceID"] = Float(sidechainSourceID.hashValue)
        } else {
            var slot = InsertSlot(effectType: .sidechain, parameters: defaultParameters(for: .sidechain))
            slot.parameters["sidechainSourceID"] = Float(sidechainSourceID.hashValue)
            channels[index].inserts.append(slot)
        }

        routingMatrix.addConnection(from: sidechainSourceID, to: compressorChannelID, level: 1.0)

        logger.log(.debug, category: .audio, "Sidechain: source -> '\(channels[index].name)'")
    }

    // MARK: - Solo

    /// Engages exclusive solo on a channel, un-soloing all others.
    ///
    /// If the target channel is already soloed, it will be un-soloed (and all solos cleared).
    ///
    /// - Parameter channelID: The channel UUID to solo exclusively.
    public func soloExclusive(channelID: UUID) {
        guard let targetIndex = channelIndex(for: channelID) else { return }
        let wasAlreadySoloed = channels[targetIndex].solo

        // Un-solo everything
        for i in channels.indices {
            channels[i].solo = false
        }

        // Toggle: if it was already soloed, leave everything un-soloed
        if !wasAlreadySoloed {
            channels[targetIndex].solo = true
        }

        logger.log(.debug, category: .audio, "Solo exclusive: '\(channels[targetIndex].name)' = \(!wasAlreadySoloed)")
    }

    // MARK: - Audio Processing

    /// Processes one audio block through the entire mixer signal chain.
    ///
    /// This is the top-level DSP entry point called from the render callback.
    /// It updates automation, processes each channel's insert chain and sends,
    /// sums into buses, and writes to the master output.
    ///
    /// - Parameter frameCount: Number of audio frames to process.
    public func processBlock(frameCount: Int) {
        guard isPlaying else { return }

        // Step 1: Apply automation values at the current playhead position
        updateAutomation(time: currentTime)

        // Step 2: Determine which channels are audible (solo logic)
        let anySoloed = channels.contains { $0.solo }

        // Step 3: Process each channel
        for i in channels.indices {
            let channel = channels[i]

            // Skip muted channels; if any channel is soloed, skip non-soloed channels
            let isAudible = !channel.mute && (!anySoloed || channel.solo)
            guard isAudible else {
                channels[i].metering = MeterState()
                continue
            }

            // Process insert chain
            processInserts(channelIndex: i, frameCount: frameCount)

            // Process sends
            processSends(channelIndex: i, frameCount: frameCount)

            // Update metering (simulated in-engine; real DSP would feed actual levels)
            updateMetering(channelIndex: i)
        }

        // Step 4: Sum all routed signals into the master bus
        processMasterBus(frameCount: frameCount)

        // Step 5: Advance the playhead
        let blockDuration = Double(frameCount) / sampleRate
        currentTime += blockDuration
    }

    /// Resolves the full routing chain for a channel, returning all destination UUIDs.
    ///
    /// - Parameter channelID: The source channel UUID.
    /// - Returns: An array of destination channel UUIDs.
    public func routeSignal(from channelID: UUID) -> [UUID] {
        var destinations = routingMatrix.resolve(for: channelID)

        // Include send destinations
        if let index = channelIndex(for: channelID) {
            let sendDestinations = channels[index].sends
                .filter { $0.isEnabled && $0.destinationID != nil }
                .compactMap { $0.destinationID }
            destinations.append(contentsOf: sendDestinations)
        }

        return destinations
    }

    /// Applies all enabled automation lanes to their respective channel parameters.
    ///
    /// - Parameter time: The current playhead position in seconds.
    public func updateAutomation(time: TimeInterval) {
        for lane in automationLanes where lane.isEnabled {
            let value = lane.valueAt(time: time)

            guard let index = channelIndex(for: lane.channelID) else { continue }

            switch lane.parameter {
            case .volume:
                channels[index].volume = value
            case .pan:
                channels[index].pan = (value * 2.0) - 1.0 // Map 0-1 to -1..1
            case .mute:
                channels[index].mute = value >= 0.5
            case .sendLevel:
                if let sendIndex = channels[index].sends.indices.first {
                    channels[index].sends[sendIndex].level = value
                }
            case .insertParam:
                if let insertIndex = channels[index].inserts.indices.first {
                    channels[index].inserts[insertIndex].dryWet = value
                }
            case .auxLevel:
                channels[index].volume = value
            case .filterCutoff:
                applyInsertAutomation(channelIndex: index, paramKey: "cutoff", value: value)
            case .filterResonance:
                applyInsertAutomation(channelIndex: index, paramKey: "resonance", value: value)
            case .reverbMix:
                applyEffectDryWet(channelIndex: index, effectType: .algorithmicReverb, value: value)
                applyEffectDryWet(channelIndex: index, effectType: .convolutionReverb, value: value)
                applyEffectDryWet(channelIndex: index, effectType: .plateReverb, value: value)
                applyEffectDryWet(channelIndex: index, effectType: .springReverb, value: value)
                applyEffectDryWet(channelIndex: index, effectType: .shimmerReverb, value: value)
            case .delayMix:
                applyEffectDryWet(channelIndex: index, effectType: .stereoDelay, value: value)
                applyEffectDryWet(channelIndex: index, effectType: .pingPongDelay, value: value)
                applyEffectDryWet(channelIndex: index, effectType: .tapeDelay, value: value)
                applyEffectDryWet(channelIndex: index, effectType: .analogDelay, value: value)
            case .compThreshold:
                applyInsertAutomation(channelIndex: index, paramKey: "threshold", value: value)
            case .eqBand1:
                applyInsertAutomation(channelIndex: index, paramKey: "eqBand1Gain", value: value)
            case .eqBand2:
                applyInsertAutomation(channelIndex: index, paramKey: "eqBand2Gain", value: value)
            case .eqBand3:
                applyInsertAutomation(channelIndex: index, paramKey: "eqBand3Gain", value: value)
            case .eqBand4:
                applyInsertAutomation(channelIndex: index, paramKey: "eqBand4Gain", value: value)
            case .eqBand5:
                applyInsertAutomation(channelIndex: index, paramKey: "eqBand5Gain", value: value)
            case .eqBand6:
                applyInsertAutomation(channelIndex: index, paramKey: "eqBand6Gain", value: value)
            case .eqBand7:
                applyInsertAutomation(channelIndex: index, paramKey: "eqBand7Gain", value: value)
            case .eqBand8:
                applyInsertAutomation(channelIndex: index, paramKey: "eqBand8Gain", value: value)
            case .custom(let key):
                applyInsertAutomation(channelIndex: index, paramKey: key, value: value)
            }
        }
    }

    // MARK: - Mix Snapshots

    /// Captures the current state of every channel into a serializable snapshot.
    ///
    /// - Parameter name: A name for this snapshot (default: timestamped).
    /// - Returns: A `MixSnapshot` containing all channel states.
    public func snapshotMix(name: String? = nil) -> MixSnapshot {
        let snapshotName = name ?? "Snapshot \(DateFormatter.localizedString(from: Date(), dateStyle: .short, timeStyle: .medium))"

        var channelSnapshots: [ChannelSnapshot] = []
        for channel in channels {
            let snap = ChannelSnapshot(
                channelID: channel.id,
                volume: channel.volume,
                pan: channel.pan,
                mute: channel.mute,
                solo: channel.solo,
                sends: channel.sends,
                inserts: channel.inserts
            )
            channelSnapshots.append(snap)
        }

        // Include master
        let masterSnap = ChannelSnapshot(
            channelID: masterChannel.id,
            volume: masterChannel.volume,
            pan: masterChannel.pan,
            mute: masterChannel.mute,
            solo: masterChannel.solo,
            sends: masterChannel.sends,
            inserts: masterChannel.inserts
        )
        channelSnapshots.append(masterSnap)

        let snapshot = MixSnapshot(name: snapshotName, channelStates: channelSnapshots)
        logger.log(.info, category: .audio, "Mix snapshot saved: '\(snapshotName)' (\(channelSnapshots.count) channels)")
        return snapshot
    }

    /// Restores mixer state from a previously saved snapshot.
    ///
    /// Only applies to channels that still exist in the session.
    ///
    /// - Parameter snapshot: The `MixSnapshot` to recall.
    public func recallMix(snapshot: MixSnapshot) {
        for state in snapshot.channelStates {
            // Check if this is the master channel
            if state.channelID == masterChannel.id {
                masterChannel.volume = state.volume
                masterChannel.pan = state.pan
                masterChannel.mute = state.mute
                masterChannel.solo = state.solo
                masterChannel.sends = state.sends
                masterChannel.inserts = state.inserts
                continue
            }

            // Find the matching channel
            guard let index = channelIndex(for: state.channelID) else { continue }
            channels[index].volume = state.volume
            channels[index].pan = state.pan
            channels[index].mute = state.mute
            channels[index].solo = state.solo
            channels[index].sends = state.sends
            channels[index].inserts = state.inserts
        }

        logger.log(.info, category: .audio, "Mix snapshot recalled: '\(snapshot.name)'")
    }

    // MARK: - Default Session

    /// Creates a default mixing session with 8 audio tracks, 2 aux buses, and a master.
    ///
    /// Aux buses:
    /// - "Reverb" with an algorithmic reverb insert
    /// - "Delay" with a stereo delay insert
    ///
    /// Each audio track gets a default send to both aux buses.
    ///
    /// - Returns: A fully configured `ProMixEngine` ready for use.
    public static func defaultSession() -> ProMixEngine {
        let engine = ProMixEngine(sampleRate: 48000, bufferSize: 256)

        // Create aux buses first so we can wire sends
        let reverbBus = engine.createAuxBus(name: "Reverb")
        let delayBus = engine.createAuxBus(name: "Delay")

        // Add reverb insert to the reverb bus
        if let reverbIndex = engine.channelIndex(for: reverbBus.id) {
            let reverbSlot = InsertSlot(
                effectType: .algorithmicReverb,
                dryWet: 1.0,
                parameters: engine.defaultParameters(for: .algorithmicReverb)
            )
            engine.channels[reverbIndex].inserts.append(reverbSlot)
            engine.channels[reverbIndex].color = .purple
        }

        // Add delay insert to the delay bus
        if let delayIndex = engine.channelIndex(for: delayBus.id) {
            let delaySlot = InsertSlot(
                effectType: .stereoDelay,
                dryWet: 1.0,
                parameters: engine.defaultParameters(for: .stereoDelay)
            )
            engine.channels[delayIndex].inserts.append(delaySlot)
            engine.channels[delayIndex].color = .teal
        }

        // Create 8 audio tracks with default sends
        let trackNames = [
            "Kick", "Snare", "Hi-Hat", "Bass",
            "Guitar", "Keys", "Vocals", "Synth"
        ]
        let trackColors: [ChannelColor] = [
            .red, .orange, .yellow, .green,
            .blue, .cyan, .indigo, .magenta
        ]

        for i in 0..<8 {
            let track = engine.addChannel(name: trackNames[i], type: .audio)

            if let trackIndex = engine.channelIndex(for: track.id) {
                engine.channels[trackIndex].color = trackColors[i]
                engine.channels[trackIndex].inputSource = .mic

                // Default reverb send at -18 dB equivalent (~0.12)
                let reverbSend = SendSlot(
                    destinationID: reverbBus.id,
                    level: 0.12,
                    isPreFader: false,
                    isEnabled: true
                )
                engine.channels[trackIndex].sends.append(reverbSend)

                // Default delay send at -24 dB equivalent (~0.06)
                let delaySend = SendSlot(
                    destinationID: delayBus.id,
                    level: 0.06,
                    isPreFader: false,
                    isEnabled: true
                )
                engine.channels[trackIndex].sends.append(delaySend)
            }
        }

        engine.logger.log(.info, category: .audio, "Default session created: 8 tracks, 2 aux buses, master")
        return engine
    }

    // MARK: - Private Helpers

    /// Returns the index of a channel in the `channels` array by its UUID.
    internal func channelIndex(for id: UUID) -> Int? {
        channels.firstIndex(where: { $0.id == id })
    }

    /// Returns a default color for a channel based on its position.
    private func defaultColor(for index: Int) -> ChannelColor {
        let colors = ChannelColor.allCases
        return colors[index % colors.count]
    }

    /// Processes the insert effect chain for a single channel.
    private func processInserts(channelIndex: Int, frameCount: Int) {
        let channel = channels[channelIndex]
        for insert in channel.inserts where insert.isEnabled {
            // Each insert processes the audio buffer in place.
            // In a real implementation this would call into the DSP graph.
            _ = insert.dryWet
            _ = insert.parameters
        }
    }

    /// Processes all sends for a single channel, routing signal to aux/bus destinations.
    private func processSends(channelIndex: Int, frameCount: Int) {
        let channel = channels[channelIndex]
        for send in channel.sends where send.isEnabled {
            guard let destID = send.destinationID else { continue }
            let sendLevel = send.isPreFader ? send.level : send.level * channel.volume
            _ = sendLevel
            _ = destID
            // In a real implementation, this would mix the signal into the destination buffer.
        }
    }

    /// Simulates metering updates for a channel.
    private func updateMetering(channelIndex: Int) {
        let channel = channels[channelIndex]
        // Simulated metering based on volume — a real implementation feeds actual RMS/peak from the DSP graph.
        let simulatedLevel = channel.volume * (channel.mute ? 0 : 1)
        let rms = simulatedLevel * 0.707 // Approximate RMS for a sine wave
        let peak = simulatedLevel

        channels[channelIndex].metering = MeterState(
            peak: peak,
            rms: rms,
            peakHold: max(peak, channels[channelIndex].metering.peakHold * 0.995),
            isClipping: peak > 0.99
        )
    }

    /// Processes the master bus summing and metering.
    private func processMasterBus(frameCount: Int) {
        // In a real implementation, the master bus sums all routed channels.
        // Here we simulate master metering from active channels.
        var sumLevel: Float = 0
        let anySoloed = channels.contains { $0.solo }

        for channel in channels {
            let isAudible = !channel.mute && (!anySoloed || channel.solo)
            guard isAudible else { continue }

            let effectiveLevel = channel.volume
            sumLevel += effectiveLevel
        }

        // Normalize the sum (simple approximation)
        let channelCount = max(Float(channels.filter { !$0.mute }.count), 1)
        let normalizedLevel = min(sumLevel / channelCount, 1.0) * masterChannel.volume

        masterChannel.metering = MeterState(
            peak: normalizedLevel,
            rms: normalizedLevel * 0.707,
            peakHold: max(normalizedLevel, masterChannel.metering.peakHold * 0.995),
            isClipping: normalizedLevel > 0.99
        )
    }

    /// Applies an automation value to a named parameter on the first matching insert.
    private func applyInsertAutomation(channelIndex: Int, paramKey: String, value: Float) {
        for insertIdx in channels[channelIndex].inserts.indices {
            if channels[channelIndex].inserts[insertIdx].parameters[paramKey] != nil {
                channels[channelIndex].inserts[insertIdx].parameters[paramKey] = value
                return
            }
        }
    }

    /// Applies an automation value to the dry/wet of a specific effect type on a channel.
    private func applyEffectDryWet(channelIndex: Int, effectType: ProEffectType, value: Float) {
        for insertIdx in channels[channelIndex].inserts.indices {
            if channels[channelIndex].inserts[insertIdx].effectType == effectType {
                channels[channelIndex].inserts[insertIdx].dryWet = value
                return
            }
        }
    }

    /// Returns sensible default parameter values for a given effect type.
    internal func defaultParameters(for effect: ProEffectType) -> [String: Float] {
        switch effect {
        case .parametricEQ:
            return [
                "eqBand1Gain": 0.5, "eqBand1Freq": 80,
                "eqBand2Gain": 0.5, "eqBand2Freq": 250,
                "eqBand3Gain": 0.5, "eqBand3Freq": 1000,
                "eqBand4Gain": 0.5, "eqBand4Freq": 4000,
                "eqBand5Gain": 0.5, "eqBand5Freq": 8000,
                "eqBand6Gain": 0.5, "eqBand6Freq": 12000,
                "eqBand7Gain": 0.5, "eqBand7Freq": 16000,
                "eqBand8Gain": 0.5, "eqBand8Freq": 20000
            ]
        case .graphicEQ:
            return ["bands": 31, "gain": 0.5]
        case .midSideEQ:
            return ["midGain": 0.5, "sideGain": 0.5, "midFreq": 1000, "sideFreq": 5000]
        case .dynamicEQ:
            return ["threshold": 0.5, "ratio": 0.3, "frequency": 2000, "bandwidth": 0.5]
        case .compressor:
            return ["threshold": 0.6, "ratio": 0.3, "attack": 0.1, "release": 0.3, "makeup": 0.5, "knee": 0.3]
        case .multibandCompressor:
            return ["lowThreshold": 0.5, "midThreshold": 0.5, "highThreshold": 0.5, "crossoverLow": 200, "crossoverHigh": 4000]
        case .limiter:
            return ["ceiling": 0.95, "release": 0.3, "lookahead": 0.1]
        case .gate:
            return ["threshold": 0.2, "attack": 0.05, "release": 0.2, "hold": 0.1, "range": 0.8]
        case .deEsser:
            return ["threshold": 0.5, "frequency": 6000, "bandwidth": 0.3, "reduction": 0.5]
        case .transientShaper:
            return ["attack": 0.5, "sustain": 0.5, "output": 0.5]
        case .saturation:
            return ["drive": 0.3, "tone": 0.5, "output": 0.7]
        case .tapeEmulation:
            return ["saturation": 0.4, "bias": 0.5, "speed": 0.7, "flutter": 0.1, "hiss": 0.05]
        case .tubeWarmth:
            return ["drive": 0.3, "warmth": 0.5, "output": 0.7]
        case .convolutionReverb:
            return ["dryWet": 0.3, "predelay": 0.02, "decay": 0.5, "dampening": 0.5]
        case .algorithmicReverb:
            return ["dryWet": 0.3, "size": 0.5, "decay": 0.5, "dampening": 0.5, "predelay": 0.02, "diffusion": 0.7]
        case .plateReverb:
            return ["dryWet": 0.3, "decay": 0.5, "dampening": 0.6, "predelay": 0.01]
        case .springReverb:
            return ["dryWet": 0.3, "tension": 0.5, "dampening": 0.5, "drip": 0.3]
        case .shimmerReverb:
            return ["dryWet": 0.3, "decay": 0.7, "shimmer": 0.5, "pitch": 0.5, "dampening": 0.4]
        case .stereoDelay:
            return ["dryWet": 0.3, "timeL": 0.25, "timeR": 0.375, "feedback": 0.35, "lowCut": 200, "highCut": 8000]
        case .pingPongDelay:
            return ["dryWet": 0.3, "time": 0.25, "feedback": 0.4, "width": 1.0]
        case .tapeDelay:
            return ["dryWet": 0.3, "time": 0.3, "feedback": 0.35, "saturation": 0.3, "flutter": 0.1, "age": 0.4]
        case .analogDelay:
            return ["dryWet": 0.3, "time": 0.25, "feedback": 0.3, "tone": 0.5, "warmth": 0.4]
        case .chorus:
            return ["rate": 0.3, "depth": 0.5, "dryWet": 0.5, "voices": 2]
        case .flanger:
            return ["rate": 0.2, "depth": 0.5, "feedback": 0.4, "dryWet": 0.5]
        case .phaser:
            return ["rate": 0.3, "depth": 0.5, "feedback": 0.3, "stages": 4, "dryWet": 0.5]
        case .tremolo:
            return ["rate": 0.4, "depth": 0.6, "shape": 0.5]
        case .rotarySpeaker:
            return ["speed": 0.5, "horn": 0.5, "drum": 0.5, "acceleration": 0.3, "dryWet": 0.7]
        case .pitchShift:
            return ["semitones": 0.5, "cents": 0.5, "dryWet": 1.0]
        case .harmonizer:
            return ["interval": 0.5, "key": 0.0, "dryWet": 0.5]
        case .vocoder:
            return ["bands": 16, "attack": 0.1, "release": 0.2, "formant": 0.5, "dryWet": 0.8]
        case .bitCrusher:
            return ["bitDepth": 0.5, "sampleRate": 0.7, "dryWet": 0.5]
        case .lofi:
            return ["bitDepth": 0.6, "sampleRate": 0.5, "noise": 0.2, "flutter": 0.15, "dryWet": 0.5]
        case .stereoWidener:
            return ["width": 0.5, "midSideBalance": 0.5, "monoFreq": 200]
        case .sidechain:
            return ["threshold": 0.5, "ratio": 0.6, "attack": 0.05, "release": 0.2, "sidechainSourceID": 0]
        }
    }
}

// MARK: - Utility

/// Clamps a value between a minimum and maximum bound.
private func clamp(_ value: Float, _ minValue: Float, _ maxValue: Float) -> Float {
    min(max(value, minValue), maxValue)
}
