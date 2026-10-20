import EchoelCore

/// A track the engine would cut — removed from the song, or switched to another instrument,
/// plugin or sample, whose voices then reset — fades out first (ultra-audit A9). The engine
/// plays a bridge: the new song with that track as it was, muted, which its mixer ramps to
/// silence over one chunk. Only then the song itself, in which the track is gone or new.
public enum CutFade {
    /// How long the bridge plays: longer than the slowest render block a device asks for
    /// (4,096 frames at 44.1 kHz is 93 ms), so the mute is heard before the cut.
    public static let duration: Duration = .milliseconds(120)

    /// The song to play before `next`, or nil when `previous` → `next` cuts no track.
    public static func bridge(from previous: Project, to next: Project) -> Project? {
        var bridge = next
        var cuts = false
        for (index, old) in previous.tracks.enumerated() {
            guard let now = next.tracks.firstIndex(where: { $0.id == old.id }) else {
                // Gone: back in at its old place, muted, and soloed no longer — a solo kept for
                // the bridge would silence the other tracks the new song lets play.
                var fading = old
                fading.mixer.isMuted = true
                fading.mixer.isSoloed = false
                bridge.tracks.insert(fading, at: Swift.min(index, bridge.tracks.count))
                cuts = true
                continue
            }
            let current = next.tracks[now]
            guard old.kind == .instrument, Self.resets(from: old.instrument, to: current.instrument),
                  let at = bridge.tracks.firstIndex(where: { $0.id == old.id }) else { continue }
            // Another instrument: the old one, muted, under the new song's solo.
            var fading = old
            fading.mixer.isMuted = true
            fading.mixer.isSoloed = current.mixer.isSoloed
            bridge.tracks[at] = fading
            cuts = true
        }
        return cuts ? bridge : nil
    }

    /// Whether the engine resets the track's voices between these settings.
    private static func resets(from old: InstrumentSettings, to new: InstrumentSettings) -> Bool {
        old.device != new.device || old.plugin != new.plugin || old.sample != new.sample
    }
}
