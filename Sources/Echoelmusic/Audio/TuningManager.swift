// TuningManager.swift
// Echoelmusic
//
// Global concert pitch (Kammerton) manager.
// Provides a single source of truth for A4 reference frequency
// across all audio engines, MIDI, MPE, AUv3 plugins, and IAA.
//
// Default: 440.000 Hz (ISO 16)
// Range: 392.000 – 493.883 Hz (G4 – B4, covers all practical tunings)
// Precision: 3 decimal places (0.001 Hz)

import Foundation
import Combine

// MARK: - Tuning Manager

/// Global concert pitch manager — single source of truth for A4 reference
@MainActor
public final class TuningManager: ObservableObject {

    // MARK: - Singleton

    /// Shared instance — use this across all engines
    public static let shared = TuningManager()

    // MARK: - Published State

    /// Concert pitch in Hz (A4 reference), 3 decimal places
    /// Default: 440.000 Hz (ISO 16 international standard)
    @Published public var concertPitch: Double = 440.000 {
        didSet {
            let clamped = clamp(concertPitch)
            if clamped != concertPitch {
                concertPitch = clamped
                return
            }
            // Round to 3 decimal places
            let rounded = (concertPitch * 1000).rounded() / 1000
            if rounded != concertPitch {
                concertPitch = rounded
                return
            }
            // Persist
            UserDefaults.standard.set(concertPitch, forKey: storageKey)
            // Notify all subscribers
            pitchSubject.send(concertPitch)
        }
    }

    /// Currently selected tuning reference preset
    @Published public var selectedReference: TuningPreset = .standard440

    // MARK: - Combine Publisher

    /// Real-time publisher for concert pitch changes (for audio thread bridging)
    public let pitchSubject = PassthroughSubject<Double, Never>()

    // MARK: - Constants

    /// Minimum practical concert pitch (G4 — baroque/historical)
    public static let minimumPitch: Double = 392.000

    /// Maximum practical concert pitch (B4 — some orchestras tune high)
    public static let maximumPitch: Double = 493.883

    /// ISO 16 standard concert pitch
    public static let standardPitch: Double = 440.000

    /// Step size for fine adjustment (0.001 Hz)
    public static let fineStep: Double = 0.001

    /// Step size for coarse adjustment (1 Hz)
    public static let coarseStep: Double = 1.0

    // MARK: - Tuning Presets

    public enum TuningPreset: String, CaseIterable, Identifiable {
        case baroque415    = "Baroque (415 Hz)"
        case verdi432      = "Verdi (432 Hz)"
        case standard440   = "Standard (440 Hz)"
        case concert442    = "Concert (442 Hz)"
        case concert443    = "Concert High (443 Hz)"
        case custom        = "Custom"

        public var id: String { rawValue }

        public var frequency: Double {
            switch self {
            case .baroque415:  return 415.000
            case .verdi432:    return 432.000
            case .standard440: return 440.000
            case .concert442:  return 442.000
            case .concert443:  return 443.000
            case .custom:      return 440.000
            }
        }
    }

    // MARK: - Persistence

    private let storageKey = "echoelmusic_concert_pitch"

    // MARK: - Initialization

    private init() {
        let stored = UserDefaults.standard.double(forKey: storageKey)
        if stored >= Self.minimumPitch && stored <= Self.maximumPitch {
            self.concertPitch = (stored * 1000).rounded() / 1000
        }
    }

    // MARK: - Public API

    /// Set concert pitch from a preset
    public func applyPreset(_ preset: TuningPreset) {
        selectedReference = preset
        if preset != .custom {
            concertPitch = preset.frequency
        }
    }

    /// Reset to ISO 16 standard (440.000 Hz)
    public func resetToStandard() {
        applyPreset(.standard440)
    }

    /// Nudge pitch by delta Hz (positive = sharper, negative = flatter)
    public func nudge(by delta: Double) {
        concertPitch = clamp(concertPitch + delta)
        selectedReference = .custom
    }

    /// Convert MIDI note number to frequency using current concert pitch
    /// Formula: f = concertPitch * 2^((note - 69) / 12)
    public func frequency(forMIDINote note: Int) -> Double {
        return concertPitch * pow(2.0, Double(note - 69) / 12.0)
    }

    /// Convert MIDI note number to frequency (Float version for DSP)
    public func frequencyFloat(forMIDINote note: UInt8) -> Float {
        return Float(concertPitch) * pow(2.0, (Float(note) - 69.0) / 12.0)
    }

    /// Concert pitch as Float (for audio thread)
    public var concertPitchFloat: Float {
        Float(concertPitch)
    }

    // MARK: - Private

    private func clamp(_ value: Double) -> Double {
        return Swift.max(Self.minimumPitch, Swift.min(Self.maximumPitch, value))
    }
}
