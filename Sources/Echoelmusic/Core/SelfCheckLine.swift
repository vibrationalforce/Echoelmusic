// SelfCheckLine.swift
// Echoel — GMMW SH-10. One line that says what the app came up with.
//
// WHY THIS EXISTS. "Did the engine start, at what rate, which body source ran, which outputs are
// streaming, how much memory is left, how hot is the phone?" — a founder log answered that only
// by reading scattered lines, and three of those facts (the outputs actually streaming, the
// memory headroom at rest, the thermal state at launch) were in no line at all. Now the studio
// writes ONE line, once, `launchDelaySeconds` after its deferred starts, and once after every
// engine self-heal that recovered:
//   self-check: launch · engine running 48000 Hz · body voice off · bio camera · safe mode off
//     · streak 1 · headroom 1532 MB · thermal nominal · low power off · outputs osc+artnet
// (one line in the log; wrapped here). Written once per trigger and NEVER periodically — the SH-9
// `main:` summary is the periodic line. It asserts nothing at run time: a fact it cannot read is
// printed as `?`, never trapped on.
//
// ⚠️ WHAT IT DOES NOT SAY, so nobody looks for it here: the output route and the I/O buffer (the
// `latency:` line written when the audio session is configured carries both), the channel count
// and the installed taps (the engine keeps no readable count of either), and how many notes are
// sounding (none at launch, and a held-note count is not a health fact). It reports ONE instant:
// "bio camera" means the camera publisher was running then, not that it had locked a pulse.
//
// Guard: `TheAppSaysWhatItCameUpWithTests`.

import Foundation

/// Everything the line states, gathered by the app at one instant. Plain values, so the line is
/// a pure function of them.
struct SelfCheckFacts: Sendable, Equatable {
    var trigger: String
    var engineRunning: Bool
    var engineDegraded: Bool
    var sampleRate: Double
    var bodyVoiceArmed: Bool
    var bioSources: [String]
    var safeMode: Bool
    var streak: Int
    var headroomBytes: Int?
    var thermal: String
    var lowPower: Bool
    var outputs: [String]
}

enum SelfCheckLine {

    static let prefix = "self-check: "
    /// How long after the deferred starts the launch line is written — long enough for the
    /// outputs and an auto-started body source to come up, short of the SH-1 steady confirm.
    static let launchDelaySeconds = 3.0
    static let separator = " · "

    /// The line, neutralised so no fact (a trigger reason, a source name) can ever read as a
    /// crash marker or a scene transition to the next launch.
    static func format(_ facts: SelfCheckFacts) -> String {
        let engine: String
        if facts.engineDegraded {
            engine = "engine degraded"
        } else if facts.engineRunning {
            engine = "engine running " + rate(facts.sampleRate)
        } else {
            engine = "engine stopped"
        }
        // Hoisted, not inlined into the array: ternaries inside a long literal are the #287
        // "unable to type-check in reasonable time" shape.
        let headroom = facts.headroomBytes.map { "\($0 / 1_048_576) MB" } ?? "?"
        let voice = facts.bodyVoiceArmed ? "armed" : "off"
        let safeMode = facts.safeMode ? "on" : "off"
        let lowPower = facts.lowPower ? "on" : "off"
        let bio = list(facts.bioSources)
        let outputs = list(facts.outputs)
        let fields: [String] = [
            facts.trigger,
            engine,
            "body voice \(voice)",
            "bio \(bio)",
            "safe mode \(safeMode)",
            "streak \(facts.streak)",
            "headroom \(headroom)",
            "thermal \(facts.thermal)",
            "low power \(lowPower)",
            "outputs \(outputs)",
        ]
        return EchoelCrashLog.neutralized(prefix + fields.joined(separator: separator))
    }

    /// Whole hertz, or `? Hz` for a rate that is not a positive finite number.
    static func rate(_ hertz: Double) -> String {
        guard hertz.isFinite, hertz > 0 else { return "? Hz" }
        return "\(Int(hertz.rounded())) Hz"
    }

    static func thermalName(_ state: ProcessInfo.ThermalState) -> String {
        switch state {
        case .nominal: return "nominal"
        case .fair: return "fair"
        case .serious: return "serious"
        case .critical: return "critical"
        @unknown default: return "unknown"
        }
    }

    private static func list(_ names: [String]) -> String {
        names.isEmpty ? "none" : names.joined(separator: "+")
    }
}
