import XCTest
@testable import EchoelCore

/// The light a musician's touches leave on the Field: the drops (a touch is a drop, a colour bloom
/// with one thin ring travelling out) and the note clouds (a big soft colour where each sounding
/// note lives). What is tested: the slots and their policy as the earlier app had them, every pitch
/// at one luminance, and that no touch, however fast or however many, makes a general (luminance)
/// flash at any point of the picture (WCAG 2.3.1), simulated per point as the Field's own looks are.
/// The red flash is not covered: `testTheRedFlashIsNotCovered` measures that it is not.
final class FieldTouchLightTests: XCTestCase {
    private typealias Touch = FieldTouchLight
    private typealias Note = FieldTouchLight.Note

    /// A green, a red and a violet tone at A = 440 (C4, A4, D♯4): the three the eye sees least alike.
    private static let green = 261.63, red = 440.0, violet = 311.13

    private static func note(_ id: Int, _ hertz: Double, x: Double = 0.5, y: Double = 0.5, level: Double = 1,
                             live: Bool = true) -> Note {
        Note(id: id, toneHz: hertz, x: x, y: y, level: level, isLive: live)
    }

    /// The drops this frame shows, empty slots left out.
    private static func lit(_ spots: [Touch.Spot]) -> [Touch.Spot] {
        spots.filter { (spot: Touch.Spot) -> Bool in spot.amplitude > 0 }
    }

    // MARK: - The drops

    /// Six slots. When they are full, a strike takes the slot of the dimmest light — its strength
    /// times the life it has left — and of nothing simpler: not the oldest drop, which may still be
    /// bright; not the faintest drop or a wake drop, which may have most of its life to come; not the
    /// drop with the least time left, which may still be bright.
    func testASeventhStrikeTakesTheSlotOfTheDimmestLight() {
        // The oldest drop is bright; a younger wake drop, played softly, is the dimmest (0.31 left).
        var places = Self.placesAfterASeventhStrike(at: 0.3, after: [
            Fall(strike: 0.1, at: 0), Fall(wake: 0.2, at: 0.25, velocity: 0), Fall(strike: 0.3, at: 0.26),
            Fall(strike: 0.4, at: 0.27), Fall(strike: 0.5, at: 0.28), Fall(strike: 0.6, at: 0.29),
        ])
        XCTAssertTrue(places.contains(0.1), "the old bright strike stays")
        XCTAssertFalse(places.contains(0.2), "the dim wake drop gave its slot")
        // An old strike near its end (0.15 of its light left) is dimmer than a young wake drop (0.52),
        // though the wake drop is the fainter drop, and a wake drop.
        places = Self.placesAfterASeventhStrike(at: 0.85, after: [
            Fall(strike: 0.1, at: 0), Fall(wake: 0.2, at: 0.80), Fall(strike: 0.3, at: 0.81),
            Fall(strike: 0.4, at: 0.82), Fall(strike: 0.5, at: 0.83), Fall(strike: 0.6, at: 0.84),
        ])
        XCTAssertFalse(places.contains(0.1), "the old strike, nearly spent, gave its slot")
        XCTAssertTrue(places.contains(0.2), "the young wake drop stays")
        // The dimmest is a soft strike (0.24 left). The oldest drop has the least time left (0.3 s) but
        // more light (0.30); the faintest drop, a soft wake drop, has more light too (0.28).
        places = Self.placesAfterASeventhStrike(at: 1.0, after: [
            Fall(strike: 0.1, at: 0.3), Fall(strike: 0.2, at: 0.4, velocity: 0), Fall(wake: 0.3, at: 0.9, velocity: 0),
            Fall(strike: 0.4, at: 0.95), Fall(strike: 0.5, at: 0.96), Fall(strike: 0.6, at: 0.97),
        ])
        XCTAssertFalse(places.contains(0.2), "the soft strike with the least light left gave its slot")
        XCTAssertTrue(places.contains(0.1), "the oldest drop, with the least time left, stays")
        XCTAssertTrue(places.contains(0.3), "the faintest drop, a wake drop, stays")
    }

    /// A wake drop (the trail of a sliding finger) comes at most once every `wakeInterval` and never
    /// pushes a light out; a strike is never held back.
    func testAWakeDropWaitsItsTurnAndNeverPushesALightOut() {
        var touch = Touch()
        XCTAssertTrue(touch.drop(x: 0.5, y: 0.5, toneHz: Self.green, velocity: 1, strong: false, at: 1.0))
        XCTAssertFalse(touch.drop(x: 0.5, y: 0.5, toneHz: Self.green, velocity: 1, strong: false, at: 1.03),
                       "inside the interval")
        XCTAssertTrue(touch.drop(x: 0.5, y: 0.5, toneHz: Self.green, velocity: 1, strong: false,
                                 at: 1.0 + Touch.wakeInterval))
        XCTAssertTrue(touch.drop(x: 0.4, y: 0.5, toneHz: Self.red, velocity: 1, strong: true, at: 1.06))
        XCTAssertTrue(touch.drop(x: 0.4, y: 0.5, toneHz: Self.red, velocity: 1, strong: true, at: 1.061),
                      "two strikes a millisecond apart: both")
        XCTAssertTrue(touch.drop(x: 0.3, y: 0.5, toneHz: Self.red, velocity: 1, strong: true, at: 1.062))
        XCTAssertTrue(touch.drop(x: 0.2, y: 0.5, toneHz: Self.red, velocity: 1, strong: true, at: 1.063))
        XCTAssertFalse(touch.drop(x: 0.1, y: 0.5, toneHz: Self.violet, velocity: 1, strong: false, at: 1.2),
                       "full: a wake drop is not worth a live light")
        let shown = Self.lit(touch.shown(now: 1.2, still: false, sounding: []).drops)
        XCTAssertEqual(shown.count, Touch.dropSlots)
        XCTAssertFalse(shown.contains { (spot: Touch.Spot) -> Bool in spot.x == 0.1 })
    }

    /// A strike lives `strikeSeconds`, a wake drop `wakeSeconds`; its progress is the share of that
    /// life gone, and then it is gone. It sits where it fell, in the Field's own place, held to the frame.
    func testADropLivesItsLifeWhereItFell() throws {
        var touch = Touch()
        XCTAssertTrue(touch.drop(x: 0.25, y: 0.75, toneHz: Self.green, velocity: 1, strong: true, at: 10))
        XCTAssertTrue(touch.drop(x: 1.4, y: -0.2, toneHz: Self.red, velocity: 1, strong: false, at: 10))
        var shown = Self.lit(touch.shown(now: 10 + Touch.wakeSeconds / 2, still: false, sounding: []).drops)
        XCTAssertEqual(shown.count, 2)
        let strike = try XCTUnwrap(shown.first { (spot: Touch.Spot) -> Bool in spot.x == 0.25 })
        XCTAssertEqual(strike.y, 0.75, "y counts up from the bottom, as the Field's own coordinates do")
        XCTAssertEqual(strike.progress, Touch.wakeSeconds / 2 / Touch.strikeSeconds, accuracy: 1e-12)
        let wake = try XCTUnwrap(shown.first { (spot: Touch.Spot) -> Bool in spot.x == 1 })
        XCTAssertEqual(wake.y, 0, "a drop outside the frame lands on its edge")
        XCTAssertEqual(wake.progress, 0.5, accuracy: 1e-12)
        XCTAssertEqual(wake.amplitude, Touch.wakeShare, accuracy: 1e-12, "a wake drop is the fainter light")
        XCTAssertEqual(strike.amplitude, 1, accuracy: 1e-12)
        shown = Self.lit(touch.shown(now: 10 + Touch.wakeSeconds, still: false, sounding: []).drops)
        XCTAssertEqual(shown.map { (spot: Touch.Spot) -> Double in spot.x }, [0.25], "the wake drop is gone")
        shown = Self.lit(touch.shown(now: 10 + Touch.strikeSeconds, still: false, sounding: []).drops)
        XCTAssertTrue(shown.isEmpty, "and the strike after it")
        let empty = touch.shown(now: 11, still: false, sounding: [])
        XCTAssertEqual(empty.drops.count, Touch.dropSlots, "always every slot, the empty ones dark")
        XCTAssertEqual(empty.clouds.count, Touch.cloudSlots)
        XCTAssertTrue(empty.drops.allSatisfy { (spot: Touch.Spot) -> Bool in spot == Touch.Spot.empty })
    }

    /// The softest touch keeps `softestShare` of a drop's light; how hard it played scales the rest.
    func testHowHardATouchPlaysIsHowBrightItsDropIs() throws {
        var touch = Touch()
        XCTAssertTrue(touch.drop(x: 0.2, y: 0.5, toneHz: Self.green, velocity: 0, strong: true, at: 0))
        XCTAssertTrue(touch.drop(x: 0.4, y: 0.5, toneHz: Self.green, velocity: 0.5, strong: true, at: 0))
        XCTAssertTrue(touch.drop(x: 0.6, y: 0.5, toneHz: Self.green, velocity: 7, strong: true, at: 0))
        XCTAssertTrue(touch.drop(x: 0.8, y: 0.5, toneHz: Self.green, velocity: .nan, strong: true, at: 0))
        let shown = Self.lit(touch.shown(now: 0.1, still: false, sounding: []).drops)
        let strength = Dictionary(uniqueKeysWithValues: shown.map { (spot: Touch.Spot) -> (Double, Double) in
            (spot.x, spot.amplitude)
        })
        XCTAssertEqual(try XCTUnwrap(strength[0.2]), Touch.softestShare, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(strength[0.4]), Touch.softestShare + (1 - Touch.softestShare) / 2, accuracy: 1e-12)
        XCTAssertEqual(try XCTUnwrap(strength[0.6]), 1, accuracy: 1e-12, "harder than hardest is hardest")
        XCTAssertEqual(try XCTUnwrap(strength[0.8]), Touch.softestShare, accuracy: 1e-12, "no number: the softest")
    }

    /// One drop drawn: a bloom where it fell, and one thin ring that travels out from it and fades.
    /// It is round on the screen, whatever the frame's shape.
    func testADropBloomsWhereItFellWithOneRingTravellingOut() {
        var touch = Touch()
        XCTAssertTrue(touch.drop(x: 0.5, y: 0.5, toneHz: Self.green, velocity: 1, strong: true, at: 0))
        let aspect = 9.0 / 16
        var ringRadii: [Double] = []
        for step in 1...6 {
            let now = 0.1 * Double(step)
            let frame = touch.shown(now: now, still: false, sounding: [])
            // The light along a line out from the drop, in heights of the frame; the ring is its
            // outermost peak (the bloom is brighter than the ring late in the drop's life).
            let profile = (0...450).map { (index: Int) -> Double in
                frame.light(u: 0.5 + Double(index) * 0.001 / aspect, v: 0.5, aspect: aspect).luminance
            }
            let peaks = (1..<450).filter { (index: Int) -> Bool in
                profile[index] > profile[index - 1] && profile[index] >= profile[index + 1]
            }
            XCTAssertEqual(peaks.count, 1, "one ring at \(now) s")
            ringRadii.append(Double(peaks.last ?? 0) * 0.001)
            // Round: as far up as across.
            let across = frame.light(u: 0.5 + 0.1 / aspect, v: 0.5, aspect: aspect).luminance
            let up = frame.light(u: 0.5, v: 0.6, aspect: aspect).luminance
            XCTAssertEqual(across, up, accuracy: 1e-12)
        }
        for (inner, outer) in zip(ringRadii, ringRadii.dropFirst()) {
            XCTAssertGreaterThan(outer, inner, "the ring travels out")
        }
        let early = touch.shown(now: 0.1, still: false, sounding: []).light(u: 0.5, v: 0.5, aspect: aspect).luminance
        let late = touch.shown(now: 0.8, still: false, sounding: []).light(u: 0.5, v: 0.5, aspect: aspect).luminance
        XCTAssertGreaterThan(early, 0.5 * Touch.dropLuminance, "it blooms where it fell")
        XCTAssertLessThan(late, early / 3, "and dissolves")
        let struck = touch.shown(now: 0, still: false, sounding: []).light(u: 0.5, v: 0.5, aspect: aspect).luminance
        XCTAssertEqual(struck, 0, accuracy: 1e-12, "a drop eases in: nothing in the frame it is struck")
    }

    // MARK: - Every pitch as present as every other

    /// The drops and the clouds wear each pitch's light at one relative luminance, so violet and red
    /// are as present as green — and each colour still fits the screen. Across every MIDI note at
    /// five concert pitches, and across the whole circle of the light octave.
    func testEveryPitchIsAsPresentAsEveryOther() {
        var tones: [Double] = []
        for concert in [415.0, 432, 440, 442, 466] {
            for pitch in 0...127 { tones.append(ToneLight.hertz(ofPitch: pitch, concertPitch: concert)) }
        }
        for index in 0..<2_000 { tones.append(440 * pow(2, Double(index) / 2_000)) }
        for hertz in tones {
            let dropColour = Touch.evenColour(forToneHz: hertz, luminance: Touch.dropLuminance)
            let cloudColour = Touch.evenColour(forToneHz: hertz, luminance: Touch.cloudLuminance)
            XCTAssertEqual(dropColour.luminance, Touch.dropLuminance, accuracy: 1e-9, "\(hertz) Hz")
            XCTAssertEqual(cloudColour.luminance, Touch.cloudLuminance, accuracy: 1e-9, "\(hertz) Hz")
            XCTAssertLessThan(dropColour.peak, 1, "\(hertz) Hz: reached inside the gamut, not cut at its edge")
        }
        // The raw lights differ by far more than a factor of three; the drops do not differ at all.
        let raw = [Self.green, Self.red, Self.violet].map { (hertz: Double) -> Double in
            ToneLight.colour(forToneHz: hertz).luminance
        }
        XCTAssertGreaterThan((raw.max() ?? 0) / (raw.min() ?? 1), 3)
        var touch = Touch()
        for (index, hertz) in [Self.green, Self.red, Self.violet].enumerated() {
            XCTAssertTrue(touch.drop(x: 0.2 + 0.3 * Double(index), y: 0.5, toneHz: hertz, velocity: 1, strong: true, at: 0))
        }
        let shown = Self.lit(touch.shown(now: 0.2, still: false, sounding: []).drops)
        XCTAssertEqual(shown.count, 3)
        for spot in shown {
            XCTAssertEqual(spot.colour.luminance, Touch.dropLuminance, accuracy: 1e-9)
        }
        XCTAssertNotEqual(shown[0].colour, shown[1].colour, "the same luminance, not the same colour")
        // A tone that is no number still shows, as ToneLight's grey at the same luminance.
        XCTAssertEqual(Touch.evenColour(forToneHz: .nan, luminance: Touch.dropLuminance).luminance,
                       Touch.dropLuminance, accuracy: 1e-9)
    }

    // MARK: - The flash budget

    /// The budget, in numbers: the drops together never add more than `dropLuminance`, the clouds
    /// together never more than `cloudLuminance`, and both together stay under WCAG's general-flash
    /// threshold — so no change of the touch light can be a general (luminance) flash, at any rate.
    /// (The red flash is another matter: `testTheRedFlashIsNotCovered`.) Each fits the screen for
    /// every pitch: pure blue is the dimmest full colour.
    func testTheTouchLightStaysUnderTheGeneralFlashThreshold() {
        XCTAssertEqual(Touch.touchLuminance, Touch.dropLuminance + Touch.cloudLuminance, accuracy: 1e-15)
        XCTAssertLessThan(Touch.touchLuminance, FlashLimit.generalFlashThreshold)
        let blue = ToneLight.RGB(red: 0, green: 0, blue: 1).luminance
        XCTAssertLessThanOrEqual(Touch.dropLuminance, blue)
        XCTAssertLessThanOrEqual(Touch.cloudLuminance, blue)
        XCTAssertEqual(Touch.cloudWeightRate * Touch.cloudLuminance, FlashLimit.maximumRate, accuracy: 1e-12)

        // A lone full strike reaches its budget at its brightest point, and no more.
        var lone = Touch()
        XCTAssertTrue(lone.drop(x: 0.5, y: 0.5, toneHz: Self.green, velocity: 1, strong: true, at: 0))
        var brightest = 0.0
        for frame in 0...60 {
            let shown = lone.shown(now: Double(frame) / 120, still: false, sounding: [])
            for index in 0...300 {
                let luminance = shown.light(u: 0.5 + Double(index) * 0.001, v: 0.5, aspect: 1).luminance
                brightest = Swift.max(brightest, luminance)
            }
        }
        XCTAssertGreaterThan(brightest, 0.98 * Touch.dropLuminance)
        XCTAssertLessThanOrEqual(brightest, Touch.dropLuminance + 1e-12)

        // Six strikes and five full clouds on one spot: the whole light still keeps the budget.
        var crowd = Touch()
        let chord = (0..<5).map { (index: Int) -> Note in Self.note(index, Self.violet * Double(index + 1), level: 1) }
        _ = crowd.shown(now: 0, still: false, sounding: chord)
        for index in 0..<6 {
            XCTAssertTrue(crowd.drop(x: 0.5, y: 0.5, toneHz: Self.green * Double(index + 1), velocity: 1, strong: true,
                                     at: 0.001 * Double(index)))
        }
        var most = 0.0
        for frame in 1...30 {
            let shown = crowd.shown(now: Double(frame) / 60, still: false, sounding: chord)
            for i in 0...20 {
                for j in 0...20 {
                    let light = shown.light(u: 0.4 + Double(i) * 0.01, v: 0.4 + Double(j) * 0.01, aspect: 1)
                    most = Swift.max(most, light.luminance)
                    XCTAssertLessThanOrEqual(light.peak, 1)
                }
            }
        }
        XCTAssertLessThanOrEqual(most, Touch.touchLuminance + 1e-12)
        XCTAssertGreaterThan(most, 0.9 * Touch.touchLuminance, "and comes close to it: the budget is spent, not wasted")

        // A deep blue drop's ring at its brightest, passing the centre of a deep blue cloud, would pass
        // the screen's full blue: the light is then that blue as bright as the screen shows it, and
        // still the same blue.
        let deepBlue = 293.66  // D4 at A = 440
        let full = ToneLight.colour(forToneHz: deepBlue)
        XCTAssertLessThan(full.luminance, Touch.touchLuminance, "a blue the budget can pass")
        let cloudCentre = Self.note(1, deepBlue, x: 0.5 + 0.077)  // where the ring is just after it eased in
        var deep = Touch()
        _ = deep.shown(now: 0, still: false, sounding: [cloudCentre])
        XCTAssertTrue(deep.drop(x: 0.5, y: 0.5, toneHz: deepBlue, velocity: 1, strong: true, at: 0))
        var bluest = ToneLight.RGB(grey: 0)
        for frame in 1...12 {
            let shown = deep.shown(now: Double(frame) / 120, still: false, sounding: [cloudCentre])
            for index in 0...200 {
                let light = shown.light(u: 0.5 + Double(index) * 0.0005, v: 0.5, aspect: 1)
                if light.luminance > bluest.luminance { bluest = light }
            }
        }
        XCTAssertEqual(bluest.peak, 1, accuracy: 1e-9, "held at the gamut's edge, not cut channel by channel")
        XCTAssertEqual(bluest.luminance, full.luminance, accuracy: 1e-9)
        XCTAssertEqual(bluest.green / bluest.blue, full.green / full.blue, accuracy: 1e-9, "the same blue")
    }

    /// The worst a hand can do at one spot of the picture, in three phases: two seconds of a finger
    /// sliding there alone, so its wake drops fill the slots; four seconds of strikes ten times a
    /// second and six strikes at the same moment three times a second while it slides on; two seconds
    /// of the slide with a strike once a second, so wake drops and strikes take slots from each other.
    /// All the while a note is switched on and off every frame, a chord on and off at every rate from
    /// ten times a second to once, and new notes take slots from fading ones. The earlier app left this
    /// unproven (≈ 73 % of a cloud's swing survived 3 Hz). The general (luminance) flash only.
    func testNoTouchMakesAGeneralFlashAtAnyPoint() {
        let spot = (x: 0.5, y: 0.5)
        let tones = [Self.green, Self.red, Self.violet]
        var wakeDrops = 0
        assertNoPointMakesAGeneralFlash("a hand at one spot", around: spot, seconds: 8) {
            (frame: Int, now: Double, touch: inout FieldTouchLight) -> [Note] in
            let second = frame / 60
            let storm = second >= 2 && second < 6
            if (storm && frame % 6 == 0) || (second >= 6 && frame % 60 == 0) {
                _ = touch.drop(x: spot.x, y: spot.y, toneHz: tones[(frame / 6) % 3], velocity: 1, strong: true, at: now)
            }
            let wiggle = 0.01 * Double(frame % 5) - 0.02
            if touch.drop(x: spot.x + wiggle, y: spot.y - wiggle, toneHz: tones[frame % 3], velocity: 1, strong: false, at: now) {
                wakeDrops += 1
            }
            if storm, frame % 20 == 0 {
                for index in 0..<6 {
                    _ = touch.drop(x: spot.x + 0.01 * Double(index - 3), y: spot.y, toneHz: tones[index % 3], velocity: 1,
                                   strong: true, at: now)
                }
            }
            var sounding: [Note] = []
            // A note switched on and off every frame, the fastest a note can come and go.
            if frame % 2 == 0 { sounding.append(Self.note(1, Self.green, x: spot.x, y: spot.y)) }
            // A chord of four on the spot switched on and off at every rate from ten times a second
            // to once a second, the half-period growing each second: so its clouds also swing all
            // the way, all together, which a note too fast for its easing never does.
            let half = [3, 6, 10, 15, 20, 30][(frame / 60) % 6]
            if (frame / half) % 2 == 0 {
                for index in 0..<4 {
                    sounding.append(Self.note(10 + index, tones[index % 3] * Double(index + 1),
                                              x: spot.x + 0.02 * (Double(index) - 1.5), y: spot.y))
                }
            }
            // A new note five times a second, taking the slot of a fading one.
            sounding.append(Self.note(100 + frame / 12, tones[(frame / 12) % 3], x: spot.x, y: spot.y + 0.03))
            return sounding
        }
        // In the tall frame and the wide one: the trail really took slots, about nine a second while
        // the strikes left it room, so the wake drops' light is part of what was measured.
        XCTAssertGreaterThan(wakeDrops, 2 * 20, "the sliding finger's wake drops took part")
    }

    /// A finger tapping one cell: each tap strikes a drop and lights its note's cloud at the same
    /// place at the same moment, the note held 0.3 s, from once every two seconds to four times a
    /// second — so both go dark between slow taps and come back together. Each under the threshold
    /// alone, they would not be under it together; this is why the drops and the clouds share one
    /// budget. The general (luminance) flash only.
    func testATappedCellNeverMakesAGeneralFlash() {
        let spot = (x: 0.3, y: 0.6)
        assertNoPointMakesAGeneralFlash("a tapped cell", around: spot, seconds: 10) {
            (frame: Int, now: Double, touch: inout FieldTouchLight) -> [Note] in
            // Four seconds of a tap every two seconds, then two seconds each of one, two and four a second.
            let (period, start) = frame < 240 ? (120, 0) : frame < 360 ? (60, 240) : frame < 480 ? (30, 360) : (15, 480)
            let phase = (frame - start) % period
            if phase == 0 {
                _ = touch.drop(x: spot.x, y: spot.y, toneHz: Self.green, velocity: 1, strong: true, at: now)
            }
            return phase < Swift.min(18, period - 1) ? [Self.note(1, Self.green, x: spot.x, y: spot.y)] : []
        }
    }

    /// Over the Field's own worst picture — the rings at full level, a beat ring three times a second,
    /// the key, the coherence and the breath slammed from end to end, at most six transitions of a
    /// general flash a second at its worst point (`FieldLookTests`) — the touch light keeps every point
    /// at that count: two seconds of a finger sliding alone, four of two strikes at once, ten or six
    /// times a second, round four places while it slides on, and two of the slide alone again, with
    /// notes switched on and off all the while. The touch light is under the threshold on its own; this
    /// measures that, laid over the moving picture as the Field lays it, it does not tip a point of that
    /// picture over the law either. The general (luminance) flash only.
    func testTheTouchLightKeepsTheFieldsOwnGeneralFlashCount() {
        let rate = 60.0
        let places = [(0.35, 0.35), (0.65, 0.35), (0.35, 0.65), (0.65, 0.65)]
        for aspect in [1.0, 16.0 / 9] {
            for every in [6, 10] {
                var field = FieldMotion(), looks = FieldLookMotion(), touch = Touch()
                var series = [[Double]](repeating: [], count: 100)
                var wakeDrops = 0
                for frame in 0..<Int(8 * rate) {
                    let now = Double(frame) / rate
                    let beat = (Double(frame) * 3 / rate).truncatingRemainder(dividingBy: 1)
                    let loud = FieldFrame(beatPhase: beat, barPhase: Double(frame % 3) / 3,
                                          tonicHz: (frame / Int(2 * rate)) % 2 == 0 ? 261.63 : 493.88, level: 1, pulse: 1,
                                          coherence: Double((frame / 30) % 2), breath: Double((frame / 20) % 2), isPlaying: true)
                    let picture = field.step(loud, after: 1 / rate, still: false, patternScale: 1)
                    let look = looks.step(primary: .rings, partner: nil, mix: 0, hertz: nil, drive: 0, tonicHz: picture.toneHz,
                                          fieldPhase: picture.fieldPhase, after: 1 / rate, still: false, patternScale: 1)
                    let striking = frame >= Int(2 * rate) && frame < Int(6 * rate)
                    if striking, frame % every == 0 {
                        let place = places[(frame / every) % places.count]
                        _ = touch.drop(x: place.0, y: place.1, toneHz: Self.green, velocity: 1, strong: true, at: now)
                        _ = touch.drop(x: place.0 + 0.1, y: place.1, toneHz: Self.red, velocity: 1, strong: true, at: now)
                    }
                    let wiggle = 0.01 * Double(frame % 5) - 0.02
                    if touch.drop(x: 0.5 + wiggle, y: 0.5 - wiggle, toneHz: Self.violet, velocity: 1, strong: false, at: now) {
                        wakeDrops += 1
                    }
                    var sounding: [Note] = []
                    if frame % 2 == 0 { sounding.append(Self.note(1, Self.green)) }
                    if (frame / 3) % 2 == 0 {
                        for index in 0..<4 {
                            sounding.append(Self.note(10 + index, 300 + 50 * Double(index), x: 0.2 + 0.2 * Double(index)))
                        }
                    }
                    let lights = touch.shown(now: now, still: false, sounding: sounding)
                    for i in 0..<10 {
                        for j in 0..<10 {
                            let u = (Double(i) + 0.5) / 10, v = (Double(j) + 0.5) / 10
                            let under = FieldLook.light(.rings, u: u, v: v, aspect: aspect, field: picture, look: look,
                                                        plate: ChladniMotion.Shown(), turns: look.turns)
                            let light = lights.light(u: u, v: v, aspect: aspect)
                            series[i * 10 + j].append(Touch.composite(light, over: ToneLight.RGB(grey: under)).luminance)
                        }
                    }
                }
                XCTAssertGreaterThan(wakeDrops, 20, "aspect \(aspect), a strike every \(every) frames: the slide took slots")
                for (index, values) in series.enumerated() {
                    assertAtMostThreeGeneralFlashesASecond(values, "point \(index), aspect \(aspect), a strike every \(every) frames",
                                                           rate: Int(rate))
                }
            }
        }
    }

    /// What the luminance budget does not cover, measured so that no test above is read as covering
    /// it. WCAG 2.3.1 also counts flashes of saturated red, and `VideoFlashLimit` counts them in
    /// footage as moves of `VideoFlashLimit.redCellStep` of the red signal (linear R − G − B). By that
    /// count a red note tapped four times a second over a dark picture, a blue note tapped as fast
    /// over a red one (the light of A at 0.6 of the screen's red, close to the colour the Field
    /// wears in a song in A), and a finger sliding alone in red each flash red more than three times
    /// a second at many points round them, while the luminance there swings by less than the
    /// general-flash threshold: the general budget cannot see it. The day the Field's lights get a
    /// red rule, this test fails. Then rewrite it to prove the rule, and `FieldTouchLight`'s doc with it.
    func testTheRedFlashIsNotCovered() {
        let keyOfA = ToneLight.colour(forToneHz: Self.red)
        let redPicture = keyOfA.scaled(by: 0.6 / keyOfA.peak)
        let deepBlue = 293.66  // D4 at A = 440
        let scenarios: [(label: String, toneHz: Double, picture: ToneLight.RGB, tapsPerSecond: Int, slides: Bool)] = [
            ("a red note tapped over a dark picture", Self.red, ToneLight.RGB(grey: 0), 4, false),
            ("a blue note tapped over the red of A", deepBlue, redPicture, 4, false),
            ("a finger sliding alone in red", Self.red, ToneLight.RGB(grey: 0), 0, true),
        ]
        for scenario in scenarios {
            var touch = Touch()
            // 9 x 9 points within 0.2 heights of the touch, three seconds at 60 frames a second.
            var reds = [[Double]](repeating: [], count: 81)
            var luminances = [[Double]](repeating: [], count: 81)
            for frame in 0..<180 {
                let now = Double(frame) / 60
                let tapping = scenario.tapsPerSecond > 0
                let phase = tapping ? frame % (60 / scenario.tapsPerSecond) : 0
                if tapping, phase == 0 {
                    _ = touch.drop(x: 0.5, y: 0.5, toneHz: scenario.toneHz, velocity: 1, strong: true, at: now)
                }
                if scenario.slides {
                    let wiggle = 0.01 * Double(frame % 5) - 0.02
                    _ = touch.drop(x: 0.5 + wiggle, y: 0.5 - wiggle, toneHz: scenario.toneHz, velocity: 1, strong: false, at: now)
                }
                let sounding: [Note] = tapping && phase < 5 ? [Self.note(1, scenario.toneHz)] : []
                let frameShown = touch.shown(now: now, still: false, sounding: sounding)
                for i in 0..<9 {
                    for j in 0..<9 {
                        let light = frameShown.light(u: 0.3 + 0.05 * Double(i), v: 0.3 + 0.05 * Double(j), aspect: 1)
                        let seen = Touch.composite(light, over: scenario.picture)
                        let screen = seen.encoded
                        reds[i * 9 + j].append(VideoFlashLimit.redSignal(red: screen.red, green: screen.green, blue: screen.blue))
                        luminances[i * 9 + j].append(seen.luminance)
                    }
                }
            }
            var flashing = 0
            for index in reds.indices {
                let swing = (luminances[index].max() ?? 0) - (luminances[index].min() ?? 0)
                XCTAssertLessThan(swing, FlashLimit.generalFlashThreshold, "\(scenario.label), point \(index): no general flash")
                if Self.mostTransitionsInASecond(reds[index], step: VideoFlashLimit.redCellStep, rate: 60) > 6 { flashing += 1 }
            }
            XCTAssertGreaterThan(flashing, reds.count / 5, "\(scenario.label): more than three red flashes a second at many points")
        }
    }

    // MARK: - The clouds

    /// A live note's cloud comes in with the earlier app's finger easing, a note of the song more
    /// gently, and both go with the same slower fall — the earlier time constants, exactly.
    func testACloudComesAndGoesWithTheEarlierEasing() throws {
        let live = Self.note(60, Self.green, x: 0.3, y: 0.4, level: 1, live: true)
        let song = Self.note(64, Self.red, x: 0.6, y: 0.4, level: 0.5, live: false)
        var touch = Touch()
        _ = touch.shown(now: 0, still: false, sounding: [])
        _ = touch.shown(now: 0, still: false, sounding: [live, song])
        var shown = touch.shown(now: Touch.liveRiseSeconds, still: false, sounding: [live, song])
        let finger = try XCTUnwrap(shown.clouds.first { (spot: Touch.Spot) -> Bool in spot.x == 0.3 })
        XCTAssertEqual(finger.amplitude, 1 - exp(-1), accuracy: 1e-9)
        XCTAssertEqual(finger.y, 0.4)
        XCTAssertEqual(finger.colour.luminance, Touch.cloudLuminance, accuracy: 1e-9)
        var last = 0.0
        for step in 1...3 {
            shown = touch.shown(now: Touch.liveRiseSeconds + 0.1 * Double(step), still: false, sounding: [live, song])
            let bed = try XCTUnwrap(shown.clouds.first { (spot: Touch.Spot) -> Bool in spot.x == 0.6 })
            last = bed.amplitude
        }
        // The song's note had liveRiseSeconds + 0.3 s; its level is half.
        XCTAssertEqual(last, 0.5 * (1 - exp(-(Touch.liveRiseSeconds + 0.3) / Touch.songRiseSeconds)), accuracy: 1e-9)
        let before = try XCTUnwrap(shown.clouds.first { (spot: Touch.Spot) -> Bool in spot.x == 0.3 }).amplitude
        let release = Touch.liveRiseSeconds + 0.3
        // In steps no longer than `longestStep`, as a renderer's frames are.
        for elapsed in [0.05, 0.15, 0.25] {
            _ = touch.shown(now: release + elapsed, still: false, sounding: [song])
        }
        shown = touch.shown(now: release + Touch.fallSeconds, still: false, sounding: [song])
        let fading = try XCTUnwrap(shown.clouds.first { (spot: Touch.Spot) -> Bool in spot.x == 0.3 })
        XCTAssertEqual(fading.amplitude, before * exp(-1), accuracy: 1e-9, "after the fall's time constant: 1/e")
        // Long after, the slot is free and dark.
        for step in 1...60 { shown = touch.shown(now: release + Touch.fallSeconds + 0.1 * Double(step), still: false, sounding: [song]) }
        XCTAssertFalse(shown.clouds.contains { (spot: Touch.Spot) -> Bool in spot.x == 0.3 })
        XCTAssertEqual(Self.lit(shown.clouds).count, 1)
    }

    /// A cloud's brightest point never moves faster than the Field's flash guard allows
    /// (`FlashLimit.maximumRate`), however its note comes and goes — and where the guard binds (a
    /// slot handed over under Reduce Motion falls as fast as it may), it moves at exactly that rate.
    func testACloudsBrightestPointNeverOutrunsTheFlashGuard() {
        var touch = Touch()
        var previous = touch.shown(now: 0, still: false, sounding: [])
        for frame in 1..<600 {
            let now = Double(frame) / 60
            var sounding: [Note] = []
            if frame % 2 == 0 { sounding.append(Self.note(1, Self.green, x: 0.2)) }
            if (frame / 7) % 2 == 0 { sounding.append(Self.note(2, Self.red, x: 0.4, live: false)) }
            for index in 0..<5 where (frame / 30 + index) % 3 != 0 {
                sounding.append(Self.note(10 + frame / 45 + index, Self.violet * Double(index + 1), x: 0.6))
            }
            let shown = touch.shown(now: now, still: frame > 400, sounding: sounding)
            for (old, new) in zip(previous.clouds, shown.clouds) {
                let step = Swift.abs(new.amplitude - old.amplitude) * Touch.cloudLuminance
                XCTAssertLessThanOrEqual(step, FlashLimit.maximumRate / 60 + 1e-12, "frame \(frame)")
            }
            previous = shown
        }
        // A handover under Reduce Motion: five lit clouds, one note ends as a new one begins.
        var still = Touch()
        let five = (0..<5).map { (index: Int) -> Note in Self.note(index, Self.green * Double(index + 1), x: 0.1 + 0.2 * Double(index)) }
        var shown = still.shown(now: 0, still: true, sounding: five)
        var four = Array(five.dropLast())
        four.append(Self.note(9, Self.violet, x: 0.95))
        let full = shown.clouds[4].amplitude
        shown = still.shown(now: 1.0 / 60, still: true, sounding: four)
        XCTAssertEqual(full - shown.clouds[4].amplitude, Touch.cloudWeightRate / 60, accuracy: 1e-9)
    }

    /// Five slots, each keeping its note — its colour and its place — from frame to frame. A new note
    /// takes a dark slot when there is one, so a fading cloud fades where it is; only when every free
    /// slot is still lit does the quietest carry over, and then it is never cut: it keeps its light
    /// and travels to the new note's place and colour with the earlier chase constants.
    func testACloudCarriesOverToANewNoteAndIsNeverCut() throws {
        var touch = Touch()
        let notes = (0..<5).map { (index: Int) -> Note in Self.note(index, Self.green * pow(2, Double(index) / 12),
                                                                       x: 0.1 + 0.2 * Double(index), y: 0.2) }
        var shown = touch.shown(now: 0, still: false, sounding: notes)
        XCTAssertEqual(shown.clouds.map { (spot: Touch.Spot) -> Double in spot.x }, notes.map { (note: Note) -> Double in note.x })
        for frame in 1...30 {
            let again = touch.shown(now: Double(frame) / 60, still: false, sounding: Array(notes.reversed()))
            XCTAssertEqual(again.clouds.map { (spot: Touch.Spot) -> Double in spot.x }, notes.map { (note: Note) -> Double in note.x },
                           "a slot keeps its note, whatever order the notes come in")
        }
        // The note in slot 4 ends; a new one comes at once: the only free slot is still lit.
        var next = Array(notes.prefix(4))
        let newcomer = Self.note(50, Self.violet, x: 0.5, y: 0.9)
        next.append(newcomer)
        let carried = touch.shown(now: 0.5, still: false, sounding: notes).clouds[4]
        shown = touch.shown(now: 0.5 + 1.0 / 60, still: false, sounding: next)
        XCTAssertGreaterThan(shown.clouds[4].amplitude, 0.9 * carried.amplitude, "carried over, not cut")
        let target = Touch.evenColour(forToneHz: Self.violet, luminance: Touch.cloudLuminance)
        let claimed = 0.5 + 1.0 / 60
        let start = shown.clouds[4]
        XCTAssertNotEqual(start.colour, target, "the colour chases, it does not jump")
        // The claim's own frame chased for 1/60 s; three more frames make the chase's time constant.
        for elapsed in [0.1, 0.2, Touch.placeChaseSeconds - 1.0 / 60] {
            shown = touch.shown(now: claimed + elapsed, still: false, sounding: next)
        }
        let travelled = (shown.clouds[4].y - carried.y) / (newcomer.y - carried.y)
        XCTAssertEqual(travelled, 1 - exp(-1), accuracy: 1e-9, "the place, after its chase constant")
        // A dark free slot is taken first: end two notes, let one go dark, then two new notes come.
        var settle = Touch()
        _ = settle.shown(now: 0, still: false, sounding: notes)
        _ = settle.shown(now: 0.05, still: false, sounding: Array(notes.prefix(3)))
        for step in 1...40 { _ = settle.shown(now: 0.05 + 0.1 * Double(step), still: false, sounding: Array(notes.prefix(3))) }
        // Slots 3 and 4 are dark now; note 3 comes back lit for a moment and ends again.
        _ = settle.shown(now: 4.1, still: false, sounding: Array(notes.prefix(4)))
        _ = settle.shown(now: 4.2, still: false, sounding: Array(notes.prefix(4)))
        let fading = settle.shown(now: 4.25, still: false, sounding: Array(notes.prefix(3))).clouds[3]
        XCTAssertGreaterThan(fading.amplitude, Touch.invisibleWeight)
        let after = settle.shown(now: 4.26, still: false, sounding: Array(notes.prefix(3)) + [newcomer])
        XCTAssertEqual(after.clouds[3].x, fading.x, "the fading cloud fades where it is")
        XCTAssertEqual(after.clouds[4].x, newcomer.x, "the new note took the dark slot, in its own place")
        XCTAssertEqual(after.clouds[4].colour, target, "and its own colour, at once: nothing showed there")
        XCTAssertLessThan(after.clouds[4].progress, 0.2, "a new cloud starts small and grows")
    }

    /// Under Reduce Motion or at the Field's lowest detail: no drops at all, and the clouds only fade
    /// — they never grow, and a cloud handed to a new note fades out where it is before the new note
    /// fades in at its own place, instead of travelling there.
    func testAStillPictureMakesNoDropsAndItsCloudsOnlyFade() {
        var touch = Touch()
        XCTAssertTrue(touch.drop(x: 0.5, y: 0.5, toneHz: Self.green, velocity: 1, strong: true, at: 0))
        var shown = touch.shown(now: 0.05, still: true, sounding: [])
        XCTAssertTrue(Self.lit(shown.drops).isEmpty)
        shown = touch.shown(now: 0.1, still: false, sounding: [])
        XCTAssertTrue(Self.lit(shown.drops).isEmpty, "a drop made while still never shows later")
        for x in stride(from: 0.0, through: 1, by: 0.1) {
            XCTAssertEqual(shown.light(u: x, v: 0.5, aspect: 1).luminance, 0)
        }

        var still = Touch()
        let five = (0..<5).map { (index: Int) -> Note in Self.note(index, Self.green * Double(index + 1), x: 0.1 + 0.2 * Double(index)) }
        _ = still.shown(now: 0, still: true, sounding: [])
        var previous = still.shown(now: 0, still: true, sounding: five)
        var handed = Array(five.dropLast())
        handed.append(Self.note(9, Self.violet, x: 0.95, y: 0.8))
        var sawDark = false
        for frame in 1...240 {
            let sounding = frame < 60 ? five : handed
            shown = still.shown(now: Double(frame) / 60, still: true, sounding: sounding)
            for (old, new) in zip(previous.clouds, shown.clouds) where new.amplitude > 0 {
                XCTAssertEqual(new.progress, 1, "no growth")
                if old.amplitude > 0 {
                    XCTAssertEqual(new.x, old.x, "no travel")
                    XCTAssertEqual(new.y, old.y)
                }
            }
            if frame >= 60, shown.clouds[4].amplitude == 0 { sawDark = true }
            previous = shown
        }
        XCTAssertTrue(sawDark, "the handed slot went dark before its new note came in")
        XCTAssertEqual(shown.clouds[4].x, 0.95, "and the new note's cloud is at its own place")
        XCTAssertGreaterThan(shown.clouds[4].amplitude, 0.9)
    }

    /// The first frame shows the notes already sounding as they are — lit, grown, in place — with no
    /// fade from nothing: opening the Field during a chord shows the chord, not a grey moment.
    func testTheFirstFrameShowsTheNotesThatAlreadySound() throws {
        var touch = Touch()
        let shown = touch.shown(now: 42, still: false, sounding: [Self.note(7, Self.red, x: 0.7, y: 0.3, level: 0.8)])
        let cloud = try XCTUnwrap(Self.lit(shown.clouds).first)
        XCTAssertEqual(cloud.amplitude, 0.8, accuracy: 1e-12)
        XCTAssertEqual(cloud.progress, 1)
        XCTAssertEqual(cloud.x, 0.7)
        XCTAssertEqual(cloud.y, 0.3)
        XCTAssertEqual(cloud.colour, Touch.evenColour(forToneHz: Self.red, luminance: Touch.cloudLuminance))
        XCTAssertEqual(shown.light(u: 0.7, v: 0.3, aspect: 1).luminance, 0.8 * Touch.cloudLuminance, accuracy: 1e-12,
                       "the cloud is brightest where its note lives")
    }

    /// The same touches and notes at the same times give the same light, number for number.
    func testTheSameTouchesGiveTheSameLight() {
        func play() -> [FieldTouchLight.Shown] {
            var touch = FieldTouchLight()
            var frames: [FieldTouchLight.Shown] = []
            for frame in 0..<240 {
                let now = Double(frame) / 60
                if frame % 9 == 0 {
                    _ = touch.drop(x: Double(frame % 7) / 7, y: 0.5, toneHz: 300 + Double(frame), velocity: 0.7, strong: true, at: now)
                }
                let sounding = (0..<(frame / 40 + 1)).map { (index: Int) -> FieldTouchLight.Note in
                    FieldTouchLight.Note(id: index, toneHz: 220 * Double(index + 1), x: 0.2 * Double(index), y: 0.4,
                                         level: 0.9, isLive: index % 2 == 0)
                }
                frames.append(touch.shown(now: now, still: false, sounding: sounding))
            }
            return frames
        }
        let first = play(), second = play()
        XCTAssertEqual(first, second)
        XCTAssertNotEqual(first[10], first[11], "and the light does move")
    }

    /// Validate at the door: a place or a time that is no number makes no drop, a note that is no
    /// number makes no cloud, two notes of one id make one cloud, and a clock that goes back drops
    /// the drops it cannot place in time. Nothing that comes out is ever not a number.
    func testABadValueChangesNothing() {
        var touch = Touch()
        XCTAssertFalse(touch.drop(x: .nan, y: 0.5, toneHz: Self.green, velocity: 1, strong: true, at: 0))
        XCTAssertFalse(touch.drop(x: 0.5, y: .infinity, toneHz: Self.green, velocity: 1, strong: true, at: 0))
        XCTAssertFalse(touch.drop(x: 0.5, y: 0.5, toneHz: Self.green, velocity: 1, strong: true, at: .nan))
        let bad = [Self.note(1, Self.green, x: .nan), Self.note(2, Self.green, level: .nan), Self.note(3, Self.green, level: -1),
                   Self.note(4, Self.red), Self.note(4, Self.violet, x: 0.9)]
        var shown = touch.shown(now: 1, still: false, sounding: bad)
        XCTAssertTrue(Self.lit(shown.drops).isEmpty)
        XCTAssertEqual(Self.lit(shown.clouds).count, 1, "one good note, once")
        XCTAssertEqual(Self.lit(shown.clouds).first?.x, 0.5, "the first of two notes with one id")
        XCTAssertTrue(touch.drop(x: 0.5, y: 0.5, toneHz: .nan, velocity: 1, strong: true, at: 1))
        let unclocked = touch.shown(now: .nan, still: false, sounding: bad)
        XCTAssertEqual(Self.lit(unclocked.drops).count, 1, "a time that is no number is the last time")
        XCTAssertEqual(unclocked.drops[0].progress, 0)
        shown = touch.shown(now: 0.5, still: false, sounding: bad)
        XCTAssertTrue(Self.lit(shown.drops).isEmpty, "a clock that went back drops what it cannot place")
        XCTAssertEqual(Self.lit(shown.clouds).count, 1, "and steps nothing: the cloud is as it was")
        for frame in [unclocked, shown] {
            for spot in frame.drops + frame.clouds {
                XCTAssertTrue(spot.x.isFinite && spot.y.isFinite && spot.progress.isFinite && spot.amplitude.isFinite)
            }
            for u in stride(from: 0.0, through: 1, by: 0.25) {
                XCTAssertTrue(frame.light(u: u, v: u, aspect: .nan).luminance.isFinite)
                XCTAssertEqual(frame.light(u: .nan, v: u, aspect: 1).luminance, 0, "a point that is no number gets no light")
            }
        }
    }

    /// The light is laid over the picture as a screen: it brightens, never past full, adds at most its
    /// own luminance, shows as itself over black and changes nothing over white.
    func testTheLightIsLaidOverThePictureAsAScreen() {
        let light = ToneLight.RGB(red: 0.05, green: 0.06, blue: 0.3)
        XCTAssertEqual(Touch.composite(light, over: ToneLight.RGB(grey: 0)), light)
        XCTAssertEqual(Touch.composite(light, over: ToneLight.RGB(grey: 1)), ToneLight.RGB(grey: 1))
        for grey in stride(from: 0.0, through: 1, by: 0.05) {
            let picture = ToneLight.RGB(red: grey, green: 1 - grey, blue: grey * grey)
            let shown = Touch.composite(light, over: picture)
            XCTAssertGreaterThanOrEqual(shown.luminance + 1e-12, picture.luminance)
            XCTAssertLessThanOrEqual(shown.luminance - picture.luminance, light.luminance + 1e-12)
            XCTAssertLessThanOrEqual(shown.peak, 1)
        }
    }

    // MARK: - Helpers

    /// One drop for `placesAfterASeventhStrike`: where it falls, whether it is a strike or a wake
    /// drop, how hard it is played and when.
    private struct Fall {
        let x: Double
        let strong: Bool
        let velocity: Double
        let time: Double

        init(strike x: Double, at time: Double, velocity: Double = 1) {
            self.x = x
            strong = true
            self.velocity = velocity
            self.time = time
        }

        init(wake x: Double, at time: Double, velocity: Double = 1) {
            self.x = x
            strong = false
            self.velocity = velocity
            self.time = time
        }
    }

    /// The six `falls`, which fill every slot, then a seventh strike at x 0.9 at `time`: the places
    /// of the drops shown then, the seventh among them.
    private static func placesAfterASeventhStrike(at time: Double, after falls: [Fall],
                                                  file: StaticString = #filePath, line: UInt = #line) -> [Double] {
        var touch = Touch()
        for fall in falls {
            XCTAssertTrue(touch.drop(x: fall.x, y: 0.1, toneHz: green, velocity: fall.velocity, strong: fall.strong,
                                     at: fall.time), "the drop at \(fall.x) is taken", file: file, line: line)
        }
        XCTAssertEqual(lit(touch.shown(now: time, still: false, sounding: []).drops).count, Touch.dropSlots,
                       "every slot is lit before the seventh strike", file: file, line: line)
        XCTAssertTrue(touch.drop(x: 0.9, y: 0.9, toneHz: violet, velocity: 1, strong: true, at: time), file: file, line: line)
        let shown = lit(touch.shown(now: time, still: false, sounding: []).drops)
        XCTAssertEqual(shown.count, Touch.dropSlots, file: file, line: line)
        let places = shown.map { (spot: Touch.Spot) -> Double in spot.x }
        XCTAssertTrue(places.contains(0.9), "the seventh strike is shown", file: file, line: line)
        return places
    }

    /// The pictures the touch light is laid over in the flash tests: dark, grey, coloured, light.
    private static let pictures = [ToneLight.RGB(grey: 0), ToneLight.RGB(grey: 0.18),
                                   ToneLight.RGB(red: 0.30, green: 0.08, blue: 0.02), ToneLight.RGB(grey: 0.85)]

    /// Plays `play` for `seconds` at 60 frames a second, in a tall and a wide frame, and checks every
    /// point round `spot` — as far out as a ring travels — laid over each of `pictures`: its luminance
    /// swing stays under the general-flash threshold, so not one transition of a general flash
    /// happens, where the Field's looks are allowed six a second. `play` makes the frame's drops and
    /// returns the notes that sound in it. The touches must really light the spot, or the check would
    /// prove nothing.
    private func assertNoPointMakesAGeneralFlash(_ label: String, around spot: (x: Double, y: Double), seconds: Double,
                                                 play: (Int, Double, inout FieldTouchLight) -> [Note]) {
        let rate = 60
        for aspect in [9.0 / 16, 16.0 / 9] {
            var touch = FieldTouchLight()
            var points: [(u: Double, v: Double)] = []
            for i in -7...7 {
                for j in -7...7 {
                    points.append((spot.x + Double(i) * 0.05 / aspect, spot.y + Double(j) * 0.05))
                }
            }
            var series = [[Double]](repeating: [], count: points.count * Self.pictures.count)
            var brightest = 0.0
            for frame in 0..<Int(seconds * Double(rate)) {
                let now = Double(frame) / Double(rate)
                let sounding = play(frame, now, &touch)
                let frameShown = touch.shown(now: now, still: false, sounding: sounding)
                for (index, point) in points.enumerated() {
                    let light = frameShown.light(u: point.u, v: point.v, aspect: aspect)
                    brightest = Swift.max(brightest, light.luminance)
                    for (which, picture) in Self.pictures.enumerated() {
                        series[which * points.count + index].append(FieldTouchLight.composite(light, over: picture).luminance)
                    }
                }
            }
            XCTAssertGreaterThan(brightest, 0.75 * FieldTouchLight.touchLuminance, "\(label): the touches lit the spot")
            for (index, values) in series.enumerated() {
                let place = "\(label), point \(index % points.count), picture \(index / points.count), aspect \(aspect)"
                let swing = (values.max() ?? 0) - (values.min() ?? 0)
                XCTAssertLessThan(swing, FlashLimit.generalFlashThreshold, place)
                assertAtMostThreeGeneralFlashesASecond(values, place, rate: rate)
                XCTAssertTrue(Self.transitionFrames(values, step: FlashLimit.generalFlashThreshold).isEmpty, place)
            }
        }
    }

    private func assertAtMostThreeGeneralFlashesASecond(_ series: [Double], _ label: String, rate: Int) {
        let most = Self.mostTransitionsInASecond(series, step: FlashLimit.generalFlashThreshold, rate: rate)
        XCTAssertLessThanOrEqual(most, 6, "\(label): at most three general flashes (six transitions) in any second")
    }

    /// The most transitions of `step` (`transitionFrames`) inside any one second of `series`, a frame
    /// being 1 / `rate` of a second.
    private static func mostTransitionsInASecond(_ series: [Double], step: Double, rate: Int) -> Int {
        let frames = transitionFrames(series, step: step)
        var most = 0
        var first = 0
        for last in frames.indices {
            while frames[last] - frames[first] >= rate { first += 1 }
            most = Swift.max(most, last - first + 1)
        }
        return most
    }

    /// The frames where the light has moved by `step` or more against the last extreme in the
    /// opposite direction: each is one transition of a flash (as `FieldLookTests` counts them).
    private static func transitionFrames(_ series: [Double], step: Double) -> [Int] {
        guard var extreme = series.first else { return [] }
        var rising: Bool?
        var frames: [Int] = []
        for (index, value) in series.enumerated() {
            switch rising {
            case nil:
                if Swift.abs(value - extreme) >= step {
                    rising = value > extreme
                    frames.append(index)
                    extreme = value
                }
            case true?:
                if value > extreme { extreme = value } else if extreme - value >= step {
                    rising = false
                    frames.append(index)
                    extreme = value
                }
            case false?:
                if value < extreme { extreme = value } else if value - extreme >= step {
                    rising = true
                    frames.append(index)
                    extreme = value
                }
            }
        }
        return frames
    }
}
