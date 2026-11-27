import EchoelCore
import Foundation

/// The light the note grid's touches leave on the Field (G3), between the grid and every picture
/// that draws it. The grid writes each drop it strikes and the notes it sounds; each renderer reads
/// its own frame of the light in its draw loop (`MetalFieldRenderer`), at the time it draws. Drops
/// are stamped and read on one clock, `CFAbsoluteTimeGetCurrent`, so a drop is as old in every
/// picture as it is.
///
/// Each picture keeps its own `FieldTouchLight`: a still one (Reduce Motion, the lowest detail)
/// shows no drops and lets its clouds only fade, without taking the drops from a picture that moves,
/// such as the live stream's. One for the process, on the main actor, where the touches arrive and
/// the renderers draw. Not observed: no view body reads it, so a touch rebuilds no view (Law 6).
@MainActor
final class FieldTouchChannel {
    static let shared = FieldTouchChannel()

    /// Each picture's light, by its renderer.
    private var lights: [ObjectIdentifier: FieldTouchLight] = [:]
    /// The notes the grid sounds now, for the clouds.
    private var sounding: [FieldTouchLight.Note] = []

    private init() {}

    /// A drop for every picture (`FieldTouchLight.drop`), at `now`, seconds on the renderers' clock
    /// (`CFAbsoluteTimeGetCurrent`). A picture that has not drawn yet starts without it.
    func drop(x: Double, y: Double, toneHz: Double, velocity: Double, strong: Bool, at now: Double) {
        for reader in Array(lights.keys) {
            _ = lights[reader]?.drop(x: x, y: y, toneHz: toneHz, velocity: velocity, strong: strong, at: now)
        }
    }

    /// The notes the grid sounds from now on (`FieldGridTouches.notes(on:)`); none when it goes.
    func sound(_ notes: [FieldTouchLight.Note]) {
        sounding = notes
    }

    /// The frame of `reader`'s light at `now`, seconds on the same clock, still or not as its picture is.
    func shown(by reader: ObjectIdentifier, now: Double, still: Bool) -> FieldTouchLight.Shown {
        lights[reader, default: FieldTouchLight()].shown(now: now, still: still, sounding: sounding)
    }

    /// `reader` draws no more: its light goes with it.
    func forget(_ reader: ObjectIdentifier) {
        lights[reader] = nil
    }
}
