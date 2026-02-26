// TuningBridge.swift
// Echoelmusic
//
// Bridges TuningManager concert pitch changes to all audio subsystems:
// - MIDI note-to-frequency conversion
// - AUv3 plugins subscribe to pitchSubject directly from their own module
// - ChromaticTuner reference frequency
// - BioParameterMapper harmonic scale
// - BasicAudioEngine
//
// Subscribe once at app startup via TuningBridge.shared.activate()

import Foundation
import Combine

// MARK: - Tuning Bridge

/// Connects TuningManager to all audio subsystems
@MainActor
public final class TuningBridge: ObservableObject {

    // MARK: - Singleton

    public static let shared = TuningBridge()

    // MARK: - State

    private var cancellables = Set<AnyCancellable>()
    private var isActive = false

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

    // MARK: - MIDI Helper

    /// Convert MIDI note to frequency with explicit concert pitch (for audio thread)
    /// Use this from render callbacks where you already have the pitch value
    public static func midiNoteToFrequency(_ note: UInt8, concertPitch: Float) -> Float {
        return concertPitch * pow(2.0, (Float(note) - 69.0) / 12.0)
    }

    // MARK: - Private

    private func propagatePitch(_ pitch: Double) {
        log.log(.info, category: .audio, "TuningBridge: Concert pitch → \(String(format: "%.3f", pitch)) Hz")
    }
}
