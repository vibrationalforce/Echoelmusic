// FiveDimensionalTouchEngine.swift
// Echoelmusic - 5D+ Bio-Reactive Touch Expression System
// Created 2026-01-25 - Phase 10000 ULTIMATE RALPH WIGGUM LAMBDA LOOP MODE
//
// ROLI Seaboard-compatible 5D Touch + Bio-Reactive 6th Dimension
// Compatible with: ROLI Seaboard, Haken Continuum, LinnStrument, Expressive E Osmose

import Foundation
import SwiftUI
import Combine
import CoreMIDI

//==============================================================================
// MARK: - 5D Touch Dimensions (ROLI Seaboard Compatible)
//==============================================================================

/// The 5 Dimensions of Touch (+ Bio-Reactive Extension)
///
/// Industry Standard Terminology (ROLI 5D Touch):
/// - Strike: Initial touch velocity
/// - Press: Continuous pressure (MPE Z-axis)
/// - Glide: Horizontal movement (MPE X-axis)
/// - Slide: Vertical movement (MPE Y-axis)
/// - Lift: Release velocity
///
/// MPE Specification uses X, Y, Z axes:
/// - X = Pitch Bend (Glide)
/// - Y = CC74 Timbre/Brightness (Slide)
/// - Z = Channel Pressure (Press)
///
/// References:
/// - ROLI 5D Touch: https://support.roli.com/support/solutions/articles/36000019157
/// - MPE Specification: https://midi.org/midi-polyphonic-expression-mpe-specification-adopted
public enum TouchDimension: String, CaseIterable, Identifiable, Sendable {
    case strike       // Initial velocity/attack (Note On Velocity)
    case press        // Continuous pressure (Channel Pressure) - MPE Z-Axis
    case glide        // Horizontal movement (Pitch Bend) - MPE X-Axis
    case slide        // Vertical movement (CC74 Brightness) - MPE Y-Axis
    case lift         // Release velocity/lift-off (Note Off Velocity)
    case bio          // Echoelmusic Extension: HRV/Coherence modulation

    public var id: String { rawValue }

    /// Industry-standard dimension name (ROLI terminology)
    public var name: String {
        switch self {
        case .strike: return "Strike"
        case .press: return "Press"
        case .glide: return "Glide"
        case .slide: return "Slide"
        case .lift: return "Lift"
        case .bio: return "Bio"
        }
    }

    /// MPE axis designation (per MPE specification)
    public var mpeAxis: String? {
        switch self {
        case .strike: return nil  // Velocity, not a continuous axis
        case .press: return "Z"   // Pressure axis (Channel Pressure)
        case .glide: return "X"   // Pitch axis (Pitch Bend)
        case .slide: return "Y"   // Timbre axis (CC74)
        case .lift: return nil    // Release velocity, not a continuous axis
        case .bio: return nil     // Echoelmusic proprietary extension
        }
    }

    public var description: String {
        switch self {
        case .strike: return "Initial touch velocity - how hard you hit"
        case .press: return "Continuous pressure while holding (MPE Z-axis)"
        case .glide: return "Horizontal movement - pitch bend (MPE X-axis)"
        case .slide: return "Vertical movement - brightness/timbre (MPE Y-axis)"
        case .lift: return "Release velocity - how you let go"
        case .bio: return "HRV coherence modulates expression (Echoelmusic extension)"
        }
    }

    /// Standard MIDI parameter per MPE specification
    public var midiParameter: String {
        switch self {
        case .strike: return "Note-On Velocity (0-127)"
        case .press: return "Channel Pressure (MPE Z, 0-127)"
        case .glide: return "Pitch Bend (MPE X, 14-bit, ±48 semitones)"
        case .slide: return "CC74 Brightness (MPE Y, 0-127)"
        case .lift: return "Note-Off Velocity (0-127)"
        case .bio: return "CC1 Modulation (Echoelmusic, from HRV)"
        }
    }

    public var icon: String {
        switch self {
        case .strike: return "hand.tap"
        case .press: return "arrow.down.circle.fill"
        case .glide: return "arrow.left.and.right"
        case .slide: return "arrow.up.and.down"
        case .lift: return "hand.raised"
        case .bio: return "heart.fill"
        }
    }

    /// Whether this is a standard MPE/ROLI dimension or Echoelmusic extension
    public var isStandardMPE: Bool {
        switch self {
        case .strike, .press, .glide, .slide, .lift: return true
        case .bio: return false
        }
    }
}

//==============================================================================
// MARK: - 5D Touch State
//==============================================================================

/// Complete 5D+ touch state for a single voice
public struct FiveDTouchState: Identifiable, Equatable, Sendable {
    public let id: UUID
    public let note: UInt8
    public let channel: UInt8
    public let timestamp: Date

    // 5D Touch Values (0.0 - 1.0)
    public var strike: Float      // Initial velocity
    public var press: Float       // Continuous pressure
    public var glide: Float       // Pitch bend (-1 to +1, centered at 0)
    public var slide: Float       // Y-axis brightness
    public var lift: Float        // Release velocity (set on note off)

    // 6th Dimension: Bio-Reactive
    public var bioModulation: Float  // From HRV coherence

    public init(
        note: UInt8,
        channel: UInt8,
        strike: Float = 0.8,
        press: Float = 0.0,
        glide: Float = 0.0,
        slide: Float = 0.5,
        lift: Float = 0.0,
        bioModulation: Float = 0.0
    ) {
        self.id = UUID()
        self.note = note
        self.channel = channel
        self.timestamp = Date()
        self.strike = strike
        self.press = press
        self.glide = glide
        self.slide = slide
        self.lift = lift
        self.bioModulation = bioModulation
    }

    /// Get all 6 dimension values as array
    public var allDimensions: [Float] {
        [strike, press, glide, slide, lift, bioModulation]
    }

    /// Calculate expression intensity (average of active dimensions)
    public var expressionIntensity: Float {
        let activeValues = [strike, press, abs(glide), slide, bioModulation]
        return activeValues.reduce(0, +) / Float(activeValues.count)
    }
}

//==============================================================================
// MARK: - 5D Touch Engine
//==============================================================================

/// 5D Bio-Reactive Touch Expression Engine
/// ROLI Seaboard compatible with 6th bio-reactive dimension
@MainActor
public class FiveDimensionalTouchEngine: ObservableObject {

    // MARK: - Published State

    @Published public var activeVoices: [FiveDTouchState] = []
    @Published public var voiceCount: Int = 0
    @Published public var enabledDimensions: Set<TouchDimension> = Set(TouchDimension.allCases)
    @Published public var bioReactiveEnabled: Bool = true
    @Published public var currentCoherence: Float = 0.5

    // MARK: - Configuration

    /// Maximum polyphony (MPE typically uses 15 channels)
    public let maxVoices: Int = 15

    /// Pitch bend range in semitones (ROLI default: 48, Continuum: 96)
    @Published public var pitchBendRange: Int = 48

    /// Sensitivity settings per dimension
    @Published public var strikeSensitivity: Float = 1.0
    @Published public var pressSensitivity: Float = 1.0
    @Published public var glideSensitivity: Float = 1.0
    @Published public var slideSensitivity: Float = 1.0
    @Published public var bioSensitivity: Float = 0.5

    // MARK: - Dependencies

    private var midi2Manager: MIDI2Manager?
    private var mpeZoneManager: MPEZoneManager?
    private var voices: [UUID: FiveDTouchState] = [:]
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init() {
        log.midi("[5D Touch] Engine initialized")
    }

    /// Connect to MIDI system
    public func connect(midi2: MIDI2Manager, mpe: MPEZoneManager) {
        self.midi2Manager = midi2
        self.mpeZoneManager = mpe

        // Configure MPE pitch bend range
        mpe.setPitchBendRange(semitones: UInt8(pitchBendRange))

        log.midi("[5D Touch] Connected to MIDI 2.0 + MPE")
    }

    /// Subscribe to bio-reactive data source
    public func subscribeToBioData<P: Publisher>(
        _ publisher: P
    ) where P.Output == Float, P.Failure == Never {
        publisher
            .receive(on: DispatchQueue.main)
            .sink { [weak self] coherence in
                self?.updateBioModulation(coherence: coherence)
            }
            .store(in: &cancellables)

        log.midi("[5D Touch] Subscribed to bio-reactive data")
    }

    // MARK: - Voice Management

    /// Create new 5D touch voice (Strike dimension)
    public func noteOn(
        note: UInt8,
        velocity: Float,
        initialSlide: Float = 0.5
    ) -> FiveDTouchState? {
        guard let mpe = mpeZoneManager else {
            log.midi("[5D Touch] MPE not connected", level: .warning)
            return nil
        }

        // Apply strike sensitivity
        let adjustedVelocity = min(1.0, velocity * strikeSensitivity)

        // Allocate MPE voice
        guard let mpeVoice = mpe.allocateVoice(note: note, velocity: adjustedVelocity) else {
            log.midi("[5D Touch] Failed to allocate voice", level: .warning)
            return nil
        }

        // Create 5D state
        var state = FiveDTouchState(
            note: note,
            channel: mpeVoice.channel,
            strike: adjustedVelocity,
            slide: initialSlide
        )

        // Apply initial bio modulation if enabled
        if bioReactiveEnabled {
            state.bioModulation = currentCoherence * bioSensitivity
        }

        // Set initial slide (brightness)
        mpe.setVoiceBrightness(voice: mpeVoice, brightness: initialSlide * slideSensitivity)

        // Store state
        voices[state.id] = state
        updatePublishedState()

        log.midi("[5D Touch] Note On: \(note) vel=\(adjustedVelocity) slide=\(initialSlide)")

        return state
    }

    /// Update Press dimension (continuous pressure)
    public func updatePress(voiceId: UUID, pressure: Float) {
        guard enabledDimensions.contains(.press),
              var state = voices[voiceId],
              let mpe = mpeZoneManager,
              let mpeVoice = mpe.getVoiceByNote(note: state.note) else { return }

        let adjustedPressure = min(1.0, pressure * pressSensitivity)
        state.press = adjustedPressure
        voices[voiceId] = state

        mpe.setVoicePressure(voice: mpeVoice, pressure: adjustedPressure)
        updatePublishedState()
    }

    /// Update Glide dimension (pitch bend)
    public func updateGlide(voiceId: UUID, bend: Float) {
        guard enabledDimensions.contains(.glide),
              var state = voices[voiceId],
              let mpe = mpeZoneManager,
              let mpeVoice = mpe.getVoiceByNote(note: state.note) else { return }

        let adjustedBend = max(-1.0, min(1.0, bend * glideSensitivity))
        state.glide = adjustedBend
        voices[voiceId] = state

        mpe.setVoicePitchBend(voice: mpeVoice, bend: adjustedBend)
        updatePublishedState()
    }

    /// Update Slide dimension (Y-axis brightness)
    public func updateSlide(voiceId: UUID, brightness: Float) {
        guard enabledDimensions.contains(.slide),
              var state = voices[voiceId],
              let mpe = mpeZoneManager,
              let mpeVoice = mpe.getVoiceByNote(note: state.note) else { return }

        let adjustedBrightness = min(1.0, brightness * slideSensitivity)
        state.slide = adjustedBrightness
        voices[voiceId] = state

        mpe.setVoiceBrightness(voice: mpeVoice, brightness: adjustedBrightness)
        updatePublishedState()
    }

    /// Update all dimensions at once (optimized for continuous input)
    public func update5D(
        voiceId: UUID,
        press: Float? = nil,
        glide: Float? = nil,
        slide: Float? = nil
    ) {
        guard var state = voices[voiceId],
              let mpe = mpeZoneManager,
              let mpeVoice = mpe.getVoiceByNote(note: state.note) else { return }

        // Update Press
        if let press = press, enabledDimensions.contains(.press) {
            let adjusted = min(1.0, press * pressSensitivity)
            state.press = adjusted
            mpe.setVoicePressure(voice: mpeVoice, pressure: adjusted)
        }

        // Update Glide
        if let glide = glide, enabledDimensions.contains(.glide) {
            let adjusted = max(-1.0, min(1.0, glide * glideSensitivity))
            state.glide = adjusted
            mpe.setVoicePitchBend(voice: mpeVoice, bend: adjusted)
        }

        // Update Slide
        if let slide = slide, enabledDimensions.contains(.slide) {
            let adjusted = min(1.0, slide * slideSensitivity)
            state.slide = adjusted
            mpe.setVoiceBrightness(voice: mpeVoice, brightness: adjusted)
        }

        voices[voiceId] = state
        updatePublishedState()
    }

    /// Note Off with Lift dimension (release velocity)
    public func noteOff(voiceId: UUID, releaseVelocity: Float = 0.5) {
        guard var state = voices[voiceId],
              let mpe = mpeZoneManager,
              let mpeVoice = mpe.getVoiceByNote(note: state.note) else { return }

        // Record lift velocity
        state.lift = releaseVelocity

        // Release MPE voice
        mpe.deallocateVoice(voice: mpeVoice)

        // Remove from tracking
        voices.removeValue(forKey: voiceId)
        updatePublishedState()

        log.midi("[5D Touch] Note Off: \(state.note) lift=\(releaseVelocity)")
    }

    // MARK: - Bio-Reactive (6th Dimension)

    /// Update bio modulation for all active voices
    private func updateBioModulation(coherence: Float) {
        guard bioReactiveEnabled else { return }

        currentCoherence = coherence
        let modulation = coherence * bioSensitivity

        for (id, var state) in voices {
            state.bioModulation = modulation
            voices[id] = state

            // Send as CC1 (Modulation Wheel) - widely supported
            if let mpe = mpeZoneManager {
                mpe.sendMasterControlChange(controller: 1, value: modulation)
            }
        }

        updatePublishedState()
    }

    // MARK: - State Management

    private func updatePublishedState() {
        activeVoices = Array(voices.values).sorted { $0.timestamp < $1.timestamp }
        voiceCount = voices.count
    }

    /// Release all voices
    public func releaseAllVoices() {
        for (id, _) in voices {
            noteOff(voiceId: id, releaseVelocity: 0.0)
        }
        voices.removeAll()
        updatePublishedState()

        log.midi("[5D Touch] Released all voices")
    }

    /// Get voice by ID
    public func getVoice(id: UUID) -> FiveDTouchState? {
        voices[id]
    }
}

//==============================================================================
// MARK: - 5D Touch Controller Presets
//==============================================================================

/// Pre-configured settings for popular 5D controllers
public enum FiveDControllerPreset: String, CaseIterable, Identifiable, Sendable {
    case roliSeaboard = "ROLI Seaboard"
    case hakenContinuum = "Haken Continuum"
    case linnstrument = "LinnStrument"
    case expressiveEOsmose = "Expressive E Osmose"
    case echoelTouch = "Echoel Touch"
    case echoelBioReactive = "Echoel Bio-Reactive"

    public var id: String { rawValue }

    public var pitchBendRange: Int {
        switch self {
        case .roliSeaboard: return 48
        case .hakenContinuum: return 96
        case .linnstrument: return 48
        case .expressiveEOsmose: return 48
        case .echoelTouch: return 48
        case .echoelBioReactive: return 24
        }
    }

    public var strikeSensitivity: Float {
        switch self {
        case .roliSeaboard: return 1.0
        case .hakenContinuum: return 0.9
        case .linnstrument: return 1.1
        case .expressiveEOsmose: return 1.0
        case .echoelTouch: return 1.0
        case .echoelBioReactive: return 0.8
        }
    }

    public var pressSensitivity: Float {
        switch self {
        case .roliSeaboard: return 1.0
        case .hakenContinuum: return 1.2
        case .linnstrument: return 0.9
        case .expressiveEOsmose: return 1.1
        case .echoelTouch: return 1.0
        case .echoelBioReactive: return 0.7
        }
    }

    public var glideSensitivity: Float {
        switch self {
        case .roliSeaboard: return 1.0
        case .hakenContinuum: return 1.0
        case .linnstrument: return 1.0
        case .expressiveEOsmose: return 0.8
        case .echoelTouch: return 1.0
        case .echoelBioReactive: return 0.6
        }
    }

    public var slideSensitivity: Float {
        switch self {
        case .roliSeaboard: return 1.0
        case .hakenContinuum: return 1.0
        case .linnstrument: return 0.8
        case .expressiveEOsmose: return 1.0
        case .echoelTouch: return 1.0
        case .echoelBioReactive: return 1.2
        }
    }

    public var bioSensitivity: Float {
        switch self {
        case .roliSeaboard: return 0.3
        case .hakenContinuum: return 0.3
        case .linnstrument: return 0.3
        case .expressiveEOsmose: return 0.3
        case .echoelTouch: return 0.5
        case .echoelBioReactive: return 1.0  // Full bio-reactive mode
        }
    }

    public var enablesBioReactive: Bool {
        switch self {
        case .echoelBioReactive: return true
        default: return false
        }
    }

    /// Apply preset to engine
    public func apply(to engine: FiveDimensionalTouchEngine) {
        engine.pitchBendRange = pitchBendRange
        engine.strikeSensitivity = strikeSensitivity
        engine.pressSensitivity = pressSensitivity
        engine.glideSensitivity = glideSensitivity
        engine.slideSensitivity = slideSensitivity
        engine.bioSensitivity = bioSensitivity
        engine.bioReactiveEnabled = enablesBioReactive

        log.midi("[5D Touch] Applied preset: \(rawValue)")
    }
}

//==============================================================================
// MARK: - 5D Touch View
//==============================================================================

/// SwiftUI view showing 5D touch state visualization
public struct FiveDTouchView: View {
    @ObservedObject var engine: FiveDimensionalTouchEngine

    public init(engine: FiveDimensionalTouchEngine) {
        self.engine = engine
    }

    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "hand.point.up.braille.fill")
                Text("5D Touch")
                    .font(.headline)

                Spacer()

                Text("\(engine.voiceCount) voices")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Dimension indicators
            HStack(spacing: 12) {
                ForEach(TouchDimension.allCases) { dimension in
                    DimensionIndicator(
                        dimension: dimension,
                        enabled: engine.enabledDimensions.contains(dimension),
                        value: averageValue(for: dimension)
                    )
                    .onTapGesture {
                        toggleDimension(dimension)
                    }
                }
            }

            // Active voices
            if !engine.activeVoices.isEmpty {
                VStack(spacing: 8) {
                    ForEach(engine.activeVoices) { voice in
                        VoiceRow(voice: voice)
                    }
                }
            } else {
                Text("No active voices")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Bio-reactive indicator
            if engine.bioReactiveEnabled {
                HStack {
                    Image(systemName: "heart.fill")
                        .foregroundColor(.red)
                    Text("Coherence: \(Int(engine.currentCoherence * 100))%")
                        .font(.caption)

                    Spacer()

                    Text("Bio-Reactive Active")
                        .font(.caption2)
                        .foregroundColor(.green)
                }
                .padding(.top, 8)
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }

    private func averageValue(for dimension: TouchDimension) -> Float {
        guard !engine.activeVoices.isEmpty else { return 0 }

        let sum: Float = engine.activeVoices.reduce(0) { result, voice in
            switch dimension {
            case .strike: return result + voice.strike
            case .press: return result + voice.press
            case .glide: return result + abs(voice.glide)
            case .slide: return result + voice.slide
            case .lift: return result + voice.lift
            case .bio: return result + voice.bioModulation
            }
        }

        return sum / Float(engine.activeVoices.count)
    }

    private func toggleDimension(_ dimension: TouchDimension) {
        if engine.enabledDimensions.contains(dimension) {
            engine.enabledDimensions.remove(dimension)
        } else {
            engine.enabledDimensions.insert(dimension)
        }
    }
}

// MARK: - Dimension Indicator

struct DimensionIndicator: View {
    let dimension: TouchDimension
    let enabled: Bool
    let value: Float

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: dimension.icon)
                .font(.title2)
                .foregroundColor(enabled ? .blue : .gray)

            // Value bar
            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))

                    Rectangle()
                        .fill(enabled ? Color.blue : Color.gray)
                        .frame(height: geometry.size.height * CGFloat(value))
                }
            }
            .frame(width: 30, height: 40)
            .cornerRadius(4)

            Text(dimension.name)
                .font(.caption2)
                .foregroundColor(enabled ? .primary : .secondary)
        }
    }
}

// MARK: - Voice Row

struct VoiceRow: View {
    let voice: FiveDTouchState

    private let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

    var body: some View {
        HStack {
            // Note name
            Text(noteName)
                .font(.headline)
                .frame(width: 40)

            // 5D values as mini bars
            HStack(spacing: 4) {
                MiniBar(value: voice.strike, color: .green)
                MiniBar(value: voice.press, color: .orange)
                MiniBar(value: (voice.glide + 1) / 2, color: .blue)
                MiniBar(value: voice.slide, color: .purple)
                MiniBar(value: voice.bioModulation, color: .red)
            }

            Spacer()

            // Expression intensity
            Text("\(Int(voice.expressionIntensity * 100))%")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Color(.systemGray5))
        .cornerRadius(8)
    }

    private var noteName: String {
        let octave = Int(voice.note) / 12 - 1
        let name = noteNames[Int(voice.note) % 12]
        return "\(name)\(octave)"
    }
}

struct MiniBar: View {
    let value: Float
    let color: Color

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                Rectangle()
                    .fill(color.opacity(0.2))

                Rectangle()
                    .fill(color)
                    .frame(height: geometry.size.height * CGFloat(value))
            }
        }
        .frame(width: 12, height: 30)
        .cornerRadius(2)
    }
}

//==============================================================================
// MARK: - 5D Effects Engine
//==============================================================================

/// Audio effects that respond to 5D touch parameters
public struct FiveDEffectMapping: Identifiable, Sendable {
    public let id = UUID()
    public var dimension: TouchDimension
    public var targetParameter: String
    public var minValue: Float
    public var maxValue: Float
    public var curve: MappingCurve

    public enum MappingCurve: String, CaseIterable, Sendable {
        case linear
        case exponential
        case logarithmic
        case sCurve
    }

    public func map(_ input: Float) -> Float {
        let normalized = max(0, min(1, input))
        let curved: Float

        switch curve {
        case .linear:
            curved = normalized
        case .exponential:
            curved = pow(normalized, 2.0)
        case .logarithmic:
            curved = log10(1 + normalized * 9) // log scale
        case .sCurve:
            curved = normalized * normalized * (3 - 2 * normalized) // smoothstep
        }

        return minValue + curved * (maxValue - minValue)
    }
}

/// Pre-built 5D effect mappings
public enum FiveDEffectPreset: String, CaseIterable, Identifiable, Sendable {
    case expressiveSynth = "Expressive Synth"
    case organicPad = "Organic Pad"
    case aggressiveLead = "Aggressive Lead"
    case bioReactiveDrone = "Bio-Reactive Drone"

    public var id: String { rawValue }

    public var mappings: [FiveDEffectMapping] {
        switch self {
        case .expressiveSynth:
            return [
                FiveDEffectMapping(dimension: .strike, targetParameter: "attack", minValue: 0.001, maxValue: 0.1, curve: .exponential),
                FiveDEffectMapping(dimension: .press, targetParameter: "filterCutoff", minValue: 200, maxValue: 8000, curve: .exponential),
                FiveDEffectMapping(dimension: .glide, targetParameter: "pitchBend", minValue: -2, maxValue: 2, curve: .linear),
                FiveDEffectMapping(dimension: .slide, targetParameter: "brightness", minValue: 0, maxValue: 1, curve: .linear),
                FiveDEffectMapping(dimension: .bio, targetParameter: "reverbMix", minValue: 0.1, maxValue: 0.7, curve: .sCurve)
            ]

        case .organicPad:
            return [
                FiveDEffectMapping(dimension: .strike, targetParameter: "volume", minValue: 0.3, maxValue: 1.0, curve: .logarithmic),
                FiveDEffectMapping(dimension: .press, targetParameter: "chorusDepth", minValue: 0, maxValue: 0.8, curve: .linear),
                FiveDEffectMapping(dimension: .slide, targetParameter: "wavetablePosition", minValue: 0, maxValue: 1, curve: .sCurve),
                FiveDEffectMapping(dimension: .bio, targetParameter: "breathModulation", minValue: 0, maxValue: 1, curve: .linear)
            ]

        case .aggressiveLead:
            return [
                FiveDEffectMapping(dimension: .strike, targetParameter: "distortion", minValue: 0, maxValue: 0.8, curve: .exponential),
                FiveDEffectMapping(dimension: .press, targetParameter: "filterResonance", minValue: 0.1, maxValue: 0.9, curve: .linear),
                FiveDEffectMapping(dimension: .glide, targetParameter: "pitchBend", minValue: -12, maxValue: 12, curve: .linear),
                FiveDEffectMapping(dimension: .slide, targetParameter: "filterCutoff", minValue: 500, maxValue: 12000, curve: .exponential)
            ]

        case .bioReactiveDrone:
            return [
                FiveDEffectMapping(dimension: .strike, targetParameter: "attack", minValue: 0.5, maxValue: 3.0, curve: .logarithmic),
                FiveDEffectMapping(dimension: .press, targetParameter: "harmonics", minValue: 1, maxValue: 16, curve: .linear),
                FiveDEffectMapping(dimension: .slide, targetParameter: "shimmer", minValue: 0, maxValue: 1, curve: .sCurve),
                FiveDEffectMapping(dimension: .bio, targetParameter: "coherenceModulation", minValue: 0, maxValue: 1, curve: .linear),
                FiveDEffectMapping(dimension: .bio, targetParameter: "spatialWidth", minValue: 0.2, maxValue: 1.0, curve: .sCurve)
            ]
        }
    }
}
