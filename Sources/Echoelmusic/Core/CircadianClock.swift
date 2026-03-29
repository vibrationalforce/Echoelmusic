import Foundation

/// Circadian phases based on time of day + optional Oura Ring sleep data.
/// Determines base character of the soundscape.
enum CircadianPhase: String, Sendable, CaseIterable {
    case sleep     // Deep bass (40-80Hz), very slow modulation
    case wake      // Mid-range, gentle brightening
    case active    // Full spectrum, responsive
    case windDown  // Gradual darkening toward sleep tone

    /// Suggested base frequency range for this phase
    var baseFrequencyRange: ClosedRange<Float> {
        switch self {
        case .sleep:    return 55...110     // A1-A2
        case .wake:     return 110...220    // A2-A3
        case .active:   return 165...330    // E3-E4
        case .windDown: return 110...220    // A2-A3
        }
    }

    /// Modulation speed multiplier (1.0 = normal)
    var modulationSpeed: Float {
        switch self {
        case .sleep:    return 0.3
        case .wake:     return 0.6
        case .active:   return 1.0
        case .windDown: return 0.5
        }
    }
}

/// Determines circadian phase from system clock + optional Oura Ring data.
/// When Oura data is available, sleep/wake boundaries adjust to actual sleep patterns.
struct CircadianClock: Sendable {

    /// Optional Oura sleep data to refine phase boundaries
    var ouraSnapshot: OuraSnapshot?

    var currentPhase: CircadianPhase {
        let hour = Calendar.current.component(.hour, from: Date())

        // If Oura data available, use actual sleep schedule
        if let oura = ouraSnapshot {
            return phaseFromOura(hour: hour, oura: oura)
        }

        // Default time-based phases
        switch hour {
        case 0..<6:    return .sleep
        case 6..<9:    return .wake
        case 9..<19:   return .active
        case 19..<22:  return .windDown
        default:       return .sleep
        }
    }

    /// Suggested base frequency for current phase (interpolated within range)
    var suggestedBaseFrequency: Float {
        let range = currentPhase.baseFrequencyRange
        let minute = Float(Calendar.current.component(.minute, from: Date())) / 60.0
        return range.lowerBound + (range.upperBound - range.lowerBound) * minute
    }

    // MARK: - Oura-Enhanced Phase Detection

    private func phaseFromOura(hour: Int, oura: OuraSnapshot) -> CircadianPhase {
        // Oura readiness score affects energy phase
        // Low readiness (< 60) = stay in gentler phases longer
        let lowEnergy = oura.readinessScore < 60

        // Oura sleep score affects sleep/wake boundary
        // Poor sleep (< 70) = extend wake-up phase
        let poorSleep = oura.sleepScore < 70

        switch hour {
        case 0..<6:
            return .sleep
        case 6..<9:
            return .wake
        case 9..<11:
            // Poor sleep or low readiness = extended gentle wake
            return (poorSleep || lowEnergy) ? .wake : .active
        case 11..<18:
            return lowEnergy ? .active : .active // Could add sub-phases later
        case 18..<20:
            return lowEnergy ? .windDown : .active
        case 20..<22:
            return .windDown
        default:
            return .sleep
        }
    }
}
