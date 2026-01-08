// BiometricData.swift
// Core data models for biofeedback

import Foundation

// MARK: - Biometric Data Model

/// Raw biometric data from sensors
public struct BiometricData: Equatable, Sendable {
    public var heartRate: Double           // BPM (40-200)
    public var hrvMs: Double               // HRV RMSSD in ms (10-150)
    public var coherence: Double           // Coherence score (0-100)
    public var breathingRate: Double       // Breaths per minute (4-30)
    public var breathPhase: Double         // 0 = full inhale, 1 = full exhale
    public var timestamp: Date

    public init(
        heartRate: Double = 70,
        hrvMs: Double = 50,
        coherence: Double = 50,
        breathingRate: Double = 12,
        breathPhase: Double = 0.5,
        timestamp: Date = Date()
    ) {
        self.heartRate = heartRate
        self.hrvMs = hrvMs
        self.coherence = coherence
        self.breathingRate = breathingRate
        self.breathPhase = breathPhase
        self.timestamp = timestamp
    }

    /// Normalized coherence (0-1)
    public var normalizedCoherence: Double {
        coherence / 100.0
    }

    /// Coherence level category
    public var coherenceLevel: CoherenceLevel {
        switch coherence {
        case 0..<40: return .low
        case 40..<70: return .medium
        default: return .high
        }
    }
}

// MARK: - Coherence Level

public enum CoherenceLevel: String, CaseIterable {
    case low = "Low"
    case medium = "Medium"
    case high = "High"

    public var description: String {
        switch self {
        case .low: return "Building coherence..."
        case .medium: return "Good coherence"
        case .high: return "Excellent coherence!"
        }
    }

    public var color: String {
        switch self {
        case .low: return "#8B5CF6"      // Purple
        case .medium: return "#3B82F6"   // Blue
        case .high: return "#10B981"     // Green
        }
    }
}

// MARK: - Audio Mode

public enum AudioMode: String, CaseIterable, Identifiable {
    case ambient = "Ambient"
    case binaural = "Binaural"
    case drone = "Drone"
    case silence = "Silence"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .ambient: return "waveform"
        case .binaural: return "headphones"
        case .drone: return "cloud"
        case .silence: return "speaker.slash"
        }
    }

    public var description: String {
        switch self {
        case .ambient: return "Bio-reactive ambient tone"
        case .binaural: return "Binaural beats for focus"
        case .drone: return "Layered ambient drone"
        case .silence: return "Visualization only"
        }
    }
}

// MARK: - Visualization Type

public enum VisualizationType: String, CaseIterable, Identifiable {
    case coherence = "Coherence"
    case mandala = "Mandala"
    case particles = "Particles"
    case waveform = "Waveform"
    case spectrum = "Spectrum"

    public var id: String { rawValue }

    public var icon: String {
        switch self {
        case .coherence: return "circle.hexagongrid"
        case .mandala: return "star.circle"
        case .particles: return "sparkles"
        case .waveform: return "waveform.path"
        case .spectrum: return "chart.bar"
        }
    }
}

// MARK: - Binaural State

public enum BinauralState: String, CaseIterable, Identifiable {
    case delta = "Delta"      // 0.5-4 Hz - Deep sleep
    case theta = "Theta"      // 4-8 Hz - Meditation
    case alpha = "Alpha"      // 8-13 Hz - Relaxation
    case beta = "Beta"        // 13-30 Hz - Focus
    case gamma = "Gamma"      // 30-100 Hz - Peak performance

    public var id: String { rawValue }

    public var frequency: Double {
        switch self {
        case .delta: return 2.0
        case .theta: return 6.0
        case .alpha: return 10.0
        case .beta: return 20.0
        case .gamma: return 40.0
        }
    }

    public var description: String {
        switch self {
        case .delta: return "Deep sleep & healing"
        case .theta: return "Meditation & creativity"
        case .alpha: return "Relaxation & calm"
        case .beta: return "Focus & concentration"
        case .gamma: return "Peak performance"
        }
    }
}
