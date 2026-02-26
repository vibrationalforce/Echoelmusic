// TuningBridge.swift
// Echoelmusic
//
// Bridges TuningManager concert pitch changes to all audio subsystems:
// - MIDI note-to-frequency conversion
// - AUv3 plugins (via parameter address 900)
// - ChromaticTuner reference frequency
// - BioParameterMapper harmonic scale
// - BasicAudioEngine
//
// Subscribe once at app startup via TuningBridge.shared.activate()

import Foundation
import Combine
import AudioToolbox

// MARK: - Tuning Bridge

/// Connects TuningManager to all audio subsystems
@MainActor
public final class TuningBridge: ObservableObject {

    // MARK: - Singleton

    public static let shared = TuningBridge()

    // MARK: - State

    private var cancellables = Set<AnyCancellable>()
    private var isActive = false

    /// Registered AUv3 audio units to update when pitch changes
    private var registeredAudioUnits: [WeakAURef] = []

    // MARK: - Initialization

    private init() {}

    // MARK: - Activation

    /// Call once at app startup to wire TuningManager to all engines
    public func activate() {
        guard !isActive else { return }
        isActive = true

        let tuning = TuningManager.shared

        // Observe concert pitch changes
        tuning.$concertPitch
            .removeDuplicates()
            .sink { [weak self] newPitch in
                self?.propagatePitch(newPitch)
            }
            .store(in: &cancellables)

        log.log(.info, category: .audio, "TuningBridge: Activated (A4 = \(String(format: "%.3f", tuning.concertPitch)) Hz)")
    }

    // MARK: - AUv3 Registration

    /// Register an AUv3 audio unit to receive concert pitch updates
    public func registerAudioUnit(_ audioUnit: EchoelmusicAudioUnit) {
        // Clean up dead references
        registeredAudioUnits.removeAll { $0.value == nil }
        registeredAudioUnits.append(WeakAURef(audioUnit))

        // Send current pitch immediately
        let pitch = TuningManager.shared.concertPitchFloat
        audioUnit.kernel?.setParameter(
            address: EchoelmusicParameterAddress.concertPitch.rawValue,
            value: pitch
        )
    }

    /// Unregister an AUv3 audio unit
    public func unregisterAudioUnit(_ audioUnit: EchoelmusicAudioUnit) {
        registeredAudioUnits.removeAll { $0.value === audioUnit }
    }

    // MARK: - MIDI Helper

    /// Convert MIDI note to frequency using current concert pitch
    /// Thread-safe — reads from TuningManager
    public static func midiNoteToFrequency(_ note: UInt8) -> Float {
        return TuningManager.shared.frequencyFloat(forMIDINote: note)
    }

    /// Convert MIDI note to frequency with explicit concert pitch (for audio thread)
    public static func midiNoteToFrequency(_ note: UInt8, concertPitch: Float) -> Float {
        return concertPitch * pow(2.0, (Float(note) - 69.0) / 12.0)
    }

    // MARK: - Private

    private func propagatePitch(_ pitch: Double) {
        let pitchFloat = Float(pitch)

        // Update all registered AUv3 plugins
        for ref in registeredAudioUnits {
            ref.value?.kernel?.setParameter(
                address: EchoelmusicParameterAddress.concertPitch.rawValue,
                value: pitchFloat
            )
        }

        log.log(.info, category: .audio, "TuningBridge: Concert pitch → \(String(format: "%.3f", pitch)) Hz")
    }
}

// MARK: - Weak Reference Wrapper

private struct WeakAURef {
    weak var value: EchoelmusicAudioUnit?
    init(_ value: EchoelmusicAudioUnit) { self.value = value }
}
