import EchoelCore
import Foundation

/// The light the note grid's touches leave on the Field (G3), between the grids and every picture
/// that draws it. A grid writes each drop it strikes and the notes it sounds; each renderer reads
/// its own frame of the light in its draw loop (`MetalFieldRenderer`), at the time it draws. Drops
/// are stamped and read on one clock, `CFAbsoluteTimeGetCurrent`, so a drop is as old in every
/// picture as it is.
///
/// Each picture keeps its own `FieldTouchLight`: a still one (Reduce Motion, the lowest detail)
/// shows no drops and lets its clouds only fade, without taking the drops from a picture that moves,
/// such as the live stream's. Each grid keeps its own notes (`FieldGridSounding`): the full-screen
/// Field and the Instrument page's card each carry a grid, and an iPad can show both at once in two
/// windows, so a grid that sounds nothing never takes the clouds of the one being played (G5). One
/// for the process, on the main actor, where the touches arrive and the renderers draw. Not
/// observed: no view body reads it, so a touch rebuilds no view (Law 6).
@MainActor
final class FieldTouchChannel {
    static let shared = FieldTouchChannel()

    /// Each picture's light, by its renderer.
    private var lights: [ObjectIdentifier: FieldTouchLight] = [:]
    /// The notes each grid sounds now, and all of them for the clouds.
    private var sounding = FieldGridSounding()

    private init() {}

    /// A drop for every picture (`FieldTouchLight.drop`), at `now`, seconds on the renderers' clock
    /// (`CFAbsoluteTimeGetCurrent`). A picture that has not drawn yet starts without it.
    func drop(x: Double, y: Double, toneHz: Double, velocity: Double, strong: Bool, at now: Double) {
        for reader in Array(lights.keys) {
            _ = lights[reader]?.drop(x: x, y: y, toneHz: toneHz, velocity: velocity, strong: strong, at: now)
        }
    }

    /// The notes the grid `grid` sounds from now on (`FieldGridTouches.notes(on:)`); none when it
    /// goes. Its own only: the notes of every other grid stay as they are.
    func sound(_ notes: [FieldTouchLight.Note], from grid: UUID) {
        sounding.sound(notes, from: grid)
    }

    /// The frame of `reader`'s light at `now`, seconds on the same clock, still or not as its picture
    /// is, with the clouds of every grid's notes.
    func shown(by reader: ObjectIdentifier, now: Double, still: Bool) -> FieldTouchLight.Shown {
        lights[reader, default: FieldTouchLight()].shown(now: now, still: still, sounding: sounding.notes)
    }

    /// `reader` draws no more: its light goes with it.
    func forget(_ reader: ObjectIdentifier) {
        lights[reader] = nil
    }
}
