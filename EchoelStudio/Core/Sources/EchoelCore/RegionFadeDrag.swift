import Foundation

/// A region's fades set by hand on the arrangement: a grip at each top corner drags its fade
/// longer or shorter, and VoiceOver moves it a beat at a time. Every path ends in the one
/// existing command, `setRegionFades`, built once when the finger lifts — one undo step per drag.
/// The edge names the fade: `.start` the fade-in, `.end` the fade-out.
extension Arranging {
    /// The region's fades with the one at `edge` set to `frames`, held inside the region as it
    /// plays now: the fade-in to 0…length − fade-out, the fade-out to 0…length − fade-in, the
    /// other fade as it plays (`effectiveFades`) — so a fade on a trimmed region stays inside the
    /// trimmed length, and a negative one is none.
    public static func fadeLengths(_ region: AudioRegion, edge: Edge, toFrames frames: Int) -> (fadeIn: Int, fadeOut: Int) {
        let length = Swift.max(region.length, 0)
        let now = region.effectiveFades
        switch edge {
        case .start: return (Swift.min(Swift.max(frames, 0), length - now.fadeOut), now.fadeOut)
        case .end: return (now.fadeIn, Swift.min(Swift.max(frames, 0), length - now.fadeIn))
        }
    }

    /// The command that sets the fade at `edge` to `frames` (held as `fadeLengths` holds it),
    /// keeping both curves. Nil when the fades would not change, so a drag that ends where it
    /// began leaves no undo step.
    public static func faded(_ region: AudioRegion, edge: Edge, toFrames frames: Int, in track: Track) -> Command? {
        let next = fadeLengths(region, edge: edge, toFrames: frames)
        let now = region.effectiveFades
        guard next.fadeIn != now.fadeIn || next.fadeOut != now.fadeOut else { return nil }
        return .setRegionFades(track: track.id, region.id, fadeIn: next.fadeIn, fadeOut: next.fadeOut,
                               fadeInCurve: region.fadeInCurve, fadeOutCurve: region.fadeOutCurve)
    }

    /// The fade at `edge` a finger `points` along sets, on a region drawn `widthPoints` wide: the
    /// fade-in grows to the right, the fade-out to the left, at the region's frames per point.
    /// Unclamped (`fadeLengths` holds it); the fade as it plays for a width or a drag that is not
    /// a positive number.
    public static func fadeFrames(_ region: AudioRegion, edge: Edge, dragged points: Double, widthPoints: Double) -> Int {
        let now = region.effectiveFades
        let current = edge == .start ? now.fadeIn : now.fadeOut
        guard points.isFinite, widthPoints.isFinite, widthPoints > 0, region.length > 0 else { return current }
        let length = Double(region.length)
        let moved = Swift.min(Swift.max(points / widthPoints * length, -length), length)
        let delta = Int(moved.rounded())
        return edge == .start ? current + delta : current - delta
    }

    /// The command for the fade at `edge` made `beats` beats longer (shorter when negative): a beat
    /// measured where that fade lies — from the region's start for the fade-in, back from its end
    /// for the fade-out — in the frames the region plays there. Nil when the song lacks the file,
    /// a beat spans no frames, or the fade would not change.
    public static func faded(_ region: AudioRegion, edge: Edge, byBeats beats: Int, in track: Track,
                             project: Project) -> Command? {
        guard let file = project.mediaFile(region.media), file.sampleRate > 0, file.sampleRate.isFinite,
              let stop = end(of: region, in: project) else { return nil }
        let map = project.tempoMap
        let beat = project.meterMap.ticksPerBeat(at: edge == .start ? region.start : stop)
        let from = edge == .start ? region.start : Swift.max(region.start, stop - beat)
        let until = edge == .start ? region.start + beat : stop
        let span: Double
        if region.warpBPM != nil, let a = project.fileFrames(of: region, at: from), let b = project.fileFrames(of: region, at: until) {
            span = b - a
        } else {
            span = (map.seconds(at: until) - map.seconds(at: from)) * file.sampleRate
        }
        guard span.isFinite, span >= 1, span < Double(Int32.max) else { return nil }
        let perBeat = Int(span.rounded())
        let now = region.effectiveFades
        let current = edge == .start ? now.fadeIn : now.fadeOut
        // A thousand beats either way is past any region's length, and keeps the product exact.
        let steps = Swift.min(Swift.max(beats, -1_000), 1_000)
        return faded(region, edge: edge, toFrames: current + steps * perBeat, in: track)
    }
}
