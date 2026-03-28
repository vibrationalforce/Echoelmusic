import Foundation

/// Circadian phases based on time of day.
/// Determines base character of the soundscape.
enum CircadianPhase: String, Sendable {
    case sleep     // 22:00 - 06:00 — deep bass, very slow
    case wake      // 06:00 - 09:00 — gentle brightening
    case active    // 09:00 - 19:00 — full spectrum, responsive
    case windDown  // 19:00 - 22:00 — gradual darkening
}

/// Determines circadian phase from system clock.
/// Can be enhanced with Oura Ring sleep data in the future.
struct CircadianClock: Sendable {

    var currentPhase: CircadianPhase {
        let hour = Calendar.current.component(.hour, from: Date())
        switch hour {
        case 0..<6:    return .sleep
        case 6..<9:    return .wake
        case 9..<19:   return .active
        case 19..<22:  return .windDown
        default:       return .sleep
        }
    }
}
