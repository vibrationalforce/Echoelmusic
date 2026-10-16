//
//  SessionLaunchPoint.swift
//  Echoelmusic — Studio (P3: Live's launch quantization for the Session grid)
//
//  WHY A FILE OF ITS OWN. `SessionLaunchView` persists nothing — it is a projection of the song,
//  and `TheSessionLaunchesWhatTheSongPlaysTests` bans storage there so launch STATE can never
//  outlive a take. The launch point is not song or launch state: it is a player preference, like
//  the Arrangement · Session switch, and it lives here, read at every launch.
//

import SwiftUI

/// Where a launched part, a scene or a Stop lands (founder 2026-10-16, Session on Ableton level).
enum SessionLaunchPoint {

    /// The points a player may pick — Live's launch quantization without "None", 1/16 and Beat: an
    /// unquantized launch in the lane-override model starts a part mid-step, and a point finer than
    /// the bar breaks the bar-based phase rule a launched part follows (`SessionLaunchView`'s PHASE
    /// CAVEAT). ⛔ "Beat" was offered from P3 until the finesse review (2026-10-16): a MIDI part
    /// launched on beat 2 did not start from its top but played on the song's bar grid, its first
    /// beat skipped (`launchedStartBar` carries whole bars only), and a Session → Arrangement take
    /// then wrote it a beat off what was heard. It returns with a sub-bar launch phase.
    nonisolated static let offered: [LaunchQuantize] = [.bar, .twoBar, .fourBar]

    /// The persisted choice. One writer, `SessionLaunchPointPicker`; one reader, `current`.
    nonisolated static let key = "session.launchQuantize"

    /// The player's pick, `.bar` by default and for anything not offered — an unknown or retired
    /// raw value never reaches the engine.
    static var current: LaunchQuantize { resolved(UserDefaults.standard.string(forKey: key)) }

    nonisolated static func resolved(_ raw: String?) -> LaunchQuantize {
        guard let raw, let point = LaunchQuantize(rawValue: raw), offered.contains(point) else { return .bar }
        return point
    }
}

/// The launch-point switch above the Session grid. Named choices, so a segmented `Picker` (the
/// `EchoelValueField` law is for numbers). Its own leaf, so a tap re-renders only this row.
struct SessionLaunchPointPicker: View {

    @AppStorage(SessionLaunchPoint.key) private var raw = LaunchQuantize.bar.rawValue

    var body: some View {
        Picker("Launch on", selection: $raw) {
            ForEach(SessionLaunchPoint.offered, id: \.self) { point in
                Text(point.displayName).tag(point.rawValue)
            }
        }
        .pickerStyle(.segmented)
        .accessibilityHint("Where a launched part, scene or stop lands: the next bar, two bars or four bars")
    }
}
