// MediaSeedLook.swift
// Echoel — MS2 (founder order 2026-09-27): what a picture's `MediaSeed` does to the visuals, and
// how to take it back. Pure and Foundation-only; the only side effect is `write(to:)` on a
// `UserDefaults` the caller hands in.
//
// ⭐ IT GOES THROUGH THE VISUAL PATH THAT ALREADY EXISTS — no second one. The live visual reads
// six `@AppStorage` values (`StudioDefaultKeys.visualIntensity/Detail/Motion/Spread/Hue/
// Saturation`) plus the preset chip `visual.preset`, on all three mounted surfaces. A seed is
// turned into a `VisualPreset`, so the preset's own clamps (`VisualPreset.init`) decide every
// range — one definition, not a copy (#416) — and every value stays inside the flash-safe ranges
// a preset may use. Writing the keys is what `VisualMoodMap.apply` already does from the mood pad.
//
// ⭐ UNDO IS A SNAPSHOT, NOT A HISTORY. Applying returns the look from BEFORE the photo; writing
// that snapshot back is the undo — per value, and only where the value still shows what the photo
// wrote (a value moved since belongs to the player). "Still shows" is decided ON THE ROW'S DISPLAY
// GRID (`VisualLookSnapshot.sameOnDisplayGrid`, review repair 2d): a preset value is a `Float`
// widened to `Double` (0.800000011920929), and a person who re-types the "0.80" the row shows has
// not moved it — while one grid step (0.81) is a real move and is never swallowed. One pending
// application app-wide: `MediaLookUndo`. `TimelineStore`'s history deliberately holds regions, notes,
// automation and clip sources only — visual settings are not in it, and folding them in would
// change what its undo means everywhere.
//
// ⚠️ WHAT THE PHOTO CHANGES, AND WHAT IT DOES NOT.
// · Brightness → Intensity · contrast → Detail · saturation → Saturation.
// · Colour → Hue, which is a ROTATION of the physical tone→light colour (`echoelHue`), not a
//   target colour: the picture does not turn "the colour of the photo". A photo with no dominant
//   colour (grey, black and white) leaves the hue where it is.
// · Motion and Spread stay: a still has no motion to give.
// · The preset chip is cleared — the result is no factory preset, and a lit chip would claim one.
//
// ⭐ A VIDEO (MV2) TAKES THE SAME ROAD, with one difference in what it gives: brightness and colour
// follow the photo rules, and its measured picture change (`VideoSeed.motionEnergy`) sets Motion —
// the one thing a still cannot give. Detail stays, because a video's contrast is not measured.
// A stored video seed that fails `isPlausible` applies nothing.

import Foundation

/// The mapping from a picture's seed to the visual preset it applies.
enum MediaSeedLook {

    /// Intensity at a black picture and its rise to a white one (VisualPreset range 0…1.5).
    static let intensityFloor = 0.35
    static let intensitySpan = 1.05
    /// Detail (ring density) at a flat picture and its rise to full contrast (range 8…90).
    static let detailFloor = 10.0
    static let detailSpan = 76.0
    /// Visual saturation at a grey picture and its rise to a fully saturated one (range 0…2).
    static let saturationFloor = 0.4
    static let saturationSpan = 1.4

    /// The preset a seed applies. Motion and spread are the CURRENT ones, kept.
    static func preset(for seed: MediaSeed, keepingMotion motion: Double, spread: Double) -> VisualPreset {
        func unit(_ v: Double) -> Double { v.isFinite ? Swift.min(1, Swift.max(0, v)) : 0 }
        let hue: Float? = seed.hasDominantColour && seed.hue.isFinite ? Float(seed.hue) : nil
        return VisualPreset(id: "", name: "From photo",
                            intensity: Float(intensityFloor + intensitySpan * unit(seed.brightness)),
                            detail: Float(detailFloor + detailSpan * unit(seed.contrast)),
                            motion: Float(motion.isFinite ? motion : 1),
                            spread: Float(spread.isFinite ? spread : 1),
                            blurb: "colour, brightness and contrast of a photo",
                            hue: hue,
                            saturation: Float(saturationFloor + saturationSpan * unit(seed.saturation)))
    }
}

/// The mapping from a video's seed to the visual preset it applies.
enum VideoSeedLook {

    /// Motion at a still clip and its rise to full picture change (VisualPreset range 0…1.5). A
    /// still clip slows the visual; it does not freeze it.
    static let motionFloor = 0.15
    static let motionSpan = 1.2

    /// The preset a video seed applies. Detail and spread are the CURRENT ones, kept.
    static func preset(for seed: VideoSeed, keepingDetail detail: Double, spread: Double) -> VisualPreset {
        func unit(_ v: Double) -> Double { v.isFinite ? Swift.min(1, Swift.max(0, v)) : 0 }
        let hue: Float? = seed.hasDominantColour && seed.hue.isFinite ? Float(seed.hue) : nil
        return VisualPreset(id: "", name: "From video",
                            intensity: Float(MediaSeedLook.intensityFloor + MediaSeedLook.intensitySpan * unit(seed.brightness)),
                            detail: Float(detail.isFinite ? detail : 40),
                            motion: Float(motionFloor + motionSpan * unit(seed.motionEnergy)),
                            spread: Float(spread.isFinite ? spread : 1),
                            blurb: "brightness, colour and picture change of a video",
                            hue: hue,
                            saturation: Float(MediaSeedLook.saturationFloor + MediaSeedLook.saturationSpan * unit(seed.saturation)))
    }
}

/// The live visual look — the six values and the preset chip — as one value.
struct VisualLookSnapshot: Equatable, Sendable {

    /// The chip's key and its unset default. `EchoelStudioView` declares both as literals
    /// (`@AppStorage("visual.preset") private var visualPresetID = "vapor"`); there is no
    /// `StudioDefault` for them, so they are named once here and the twin is guarded. The default
    /// matters: reading an unset key as "" and writing it back on undo would un-light the chip
    /// the player sees lit.
    static let presetKey = "visual.preset"
    static let presetDefault = "vapor"

    var intensity: Double
    var detail: Double
    var motion: Double
    var spread: Double
    var hue: Double
    var saturation: Double
    var presetID: String

    /// Reads what the surfaces read: a stored value, else the key's default. A non-finite stored
    /// value reads as the default — a snapshot must be writable back.
    static func read(from defaults: UserDefaults) -> VisualLookSnapshot {
        func value(_ d: StudioDefault<Double>) -> Double {
            guard let stored = defaults.object(forKey: d.key) as? Double, stored.isFinite else { return d.value }
            return stored
        }
        return VisualLookSnapshot(intensity: value(StudioDefaultKeys.visualIntensity),
                                  detail: value(StudioDefaultKeys.visualDetail),
                                  motion: value(StudioDefaultKeys.visualMotion),
                                  spread: value(StudioDefaultKeys.visualSpread),
                                  hue: value(StudioDefaultKeys.visualHue),
                                  saturation: value(StudioDefaultKeys.visualSaturation),
                                  presetID: defaults.string(forKey: presetKey) ?? presetDefault)
    }

    /// Writes all seven keys. Every `@AppStorage` reader of them updates.
    func write(to defaults: UserDefaults) {
        defaults.set(intensity, forKey: StudioDefaultKeys.visualIntensity.key)
        defaults.set(detail, forKey: StudioDefaultKeys.visualDetail.key)
        defaults.set(motion, forKey: StudioDefaultKeys.visualMotion.key)
        defaults.set(spread, forKey: StudioDefaultKeys.visualSpread.key)
        defaults.set(hue, forKey: StudioDefaultKeys.visualHue.key)
        defaults.set(saturation, forKey: StudioDefaultKeys.visualSaturation.key)
        defaults.set(presetID, forKey: Self.presetKey)
    }

    /// The look after a seed is applied to this one. Pure: nothing is written.
    func applying(_ seed: MediaSeed) -> VisualLookSnapshot {
        var next = adopting(MediaSeedLook.preset(for: seed, keepingMotion: motion, spread: spread))
        next.motion = motion   // kept EXACTLY — the preset's Float would round it
        next.spread = spread
        return next
    }

    /// The look after a video seed is applied to this one. Pure: nothing is written.
    func applying(_ video: VideoSeed) -> VisualLookSnapshot {
        var next = adopting(VideoSeedLook.preset(for: video, keepingDetail: detail, spread: spread))
        next.detail = detail   // kept EXACTLY — the preset's Float would round it
        next.spread = spread
        return next
    }

    /// This look with a preset's values; a preset without a hue or saturation keeps this one's.
    private func adopting(_ preset: VisualPreset) -> VisualLookSnapshot {
        var next = self
        next.intensity = Double(preset.intensity)
        next.detail = Double(preset.detail)
        next.motion = Double(preset.motion)
        next.spread = Double(preset.spread)
        if let h = preset.hue { next.hue = Double(h) }
        if let s = preset.saturation { next.saturation = Double(s) }
        next.presetID = ""
        return next
    }
}

extension VisualLookSnapshot {

    /// The grid each value is displayed and snapped on — the `decimals:` of the six rows in
    /// `EchoelStudioView.visualAdjustFields`. ⚠️ Spelled a SECOND time on purpose (#416 noted):
    /// `VisualPresetValuesAreReachableTests` requires each row to carry a literal `decimals:`, so
    /// the rows cannot read these; `TheMediaLookUndoComparesOnTheDisplayGridTests` pins the two
    /// spellings to each other by label. A grid change lands in both or goes red.
    enum DisplayGrid {
        static let intensity = 2
        static let detail = 0
        static let motion = 2
        static let spread = 2
        static let hue = 2
        static let saturation = 2
        /// By row label, for the guard above.
        static let byLabel: [String: Int] = ["Intensity": intensity, "Detail": detail, "Motion": motion,
                                             "Spread": spread, "Hue": hue, "Saturation": saturation]
    }

    /// Equal as the row shows them — `ScrubPrecision.gridded`, the ONE grid the rows commit on.
    /// Not a tolerance: two values one grid step apart are different, two values that round to the
    /// same shown number are the same. A non-finite value is never equal to anything.
    static func sameOnDisplayGrid(_ a: Double, _ b: Double, decimals: Int) -> Bool {
        guard a.isFinite, b.isFinite else { return false }
        return ScrubPrecision.gridded(a, decimals: decimals) == ScrubPrecision.gridded(b, decimals: decimals)
    }

    /// The settings that differ from `other` AS DISPLAYED, in row order, named in lower case
    /// ("intensity" … "saturation", "preset" for the chip). Empty means: the same look on screen.
    /// The ONE per-setting comparison — `MediaSeedApplication.undo` and the agent's report both ask it.
    func settingsDifferingOnDisplay(from other: VisualLookSnapshot) -> [String] {
        var differing: [String] = []
        if !Self.sameOnDisplayGrid(intensity, other.intensity, decimals: DisplayGrid.intensity) { differing.append("intensity") }
        if !Self.sameOnDisplayGrid(detail, other.detail, decimals: DisplayGrid.detail) { differing.append("detail") }
        if !Self.sameOnDisplayGrid(motion, other.motion, decimals: DisplayGrid.motion) { differing.append("motion") }
        if !Self.sameOnDisplayGrid(spread, other.spread, decimals: DisplayGrid.spread) { differing.append("spread") }
        if !Self.sameOnDisplayGrid(hue, other.hue, decimals: DisplayGrid.hue) { differing.append("hue") }
        if !Self.sameOnDisplayGrid(saturation, other.saturation, decimals: DisplayGrid.saturation) { differing.append("saturation") }
        if presetID != other.presetID { differing.append("preset") }
        return differing
    }
}

/// One application of a seed: the look before and after. `undo` writes `before` back.
struct MediaSeedApplication: Equatable, Sendable {
    let before: VisualLookSnapshot
    let after: VisualLookSnapshot

    /// Reads the live look, writes the seeded one, and returns both.
    static func apply(_ seed: MediaSeed, to defaults: UserDefaults) -> MediaSeedApplication {
        let before = VisualLookSnapshot.read(from: defaults)
        let after = before.applying(seed)
        after.write(to: defaults)
        return MediaSeedApplication(before: before, after: after)
    }

    /// The same for a video. nil — and nothing written — when the seed is not plausible.
    static func apply(_ video: VideoSeed, to defaults: UserDefaults) -> MediaSeedApplication? {
        guard video.isPlausible else { return nil }
        let before = VisualLookSnapshot.read(from: defaults)
        let after = before.applying(video)
        after.write(to: defaults)
        return MediaSeedApplication(before: before, after: after)
    }

    /// Puts the look from before the photo or video back — but only for the values that still
    /// show what the application wrote, ON THE ROW'S DISPLAY GRID (review repair 2d). A value the
    /// player moved since (on another surface, by hand) is theirs now, and undo leaves it alone
    /// rather than silently reverting it; a value re-entered as the number the row shows is not a
    /// move.
    func undo(on defaults: UserDefaults) {
        let live = VisualLookSnapshot.read(from: defaults)
        let moved = Set(live.settingsDifferingOnDisplay(from: after))
        var target = live
        if !moved.contains("intensity") { target.intensity = before.intensity }
        if !moved.contains("detail") { target.detail = before.detail }
        if !moved.contains("motion") { target.motion = before.motion }
        if !moved.contains("spread") { target.spread = before.spread }
        if !moved.contains("hue") { target.hue = before.hue }
        if !moved.contains("saturation") { target.saturation = before.saturation }
        if !moved.contains("preset") { target.presetID = before.presetID }
        target.write(to: defaults)
    }
}
