import Foundation
import XCTest
@testable import EchoelDSP

/// The avatar as an instrument (VA-3): harmonics at the levels the avatar's envelope has at their
/// own frequencies, a breath shaped by its noise envelope, its vibrato, one loudness for every note
/// and Character, notes taken onto voices as `PolySynth` takes them, and nothing that clicks, costs
/// on after it has faded or turns into a number that is not one. The avatars here are measured from
/// the package's own vocal tract (`VocalTract`): nobody's voice.
final class AvatarSourceTests: XCTestCase {
    private let rate: Float = 48_000

    // MARK: Avatars

    /// The grid's levels of a sung vowel: the vocal tract's gain at every band centre, in decibels,
    /// its loudest band at 0 dB (`Vowel.at`: 0 oo … 0.5 ah … 1 ee, a bass's formants at register 0).
    private func vowelTable(character: Float, register: Float = 0) -> [Float] {
        var tract = VocalTract()
        tract.tune(to: Vowel.at(character: character, register: register), sampleRate: rate)
        let response = (0..<8_192).map { (index: Int) -> Float in tract.process(index == 0 ? 1 : 0) }
        var levels: [Float] = []
        for band in 0..<VoiceAvatar.bandCount {
            let hertz = Double(VoiceAvatar.centre(ofBand: band))
            let gain = Self.magnitude(response[...], hertz: hertz, sampleRate: Double(rate)) * Double(response.count)
            levels.append(Float(20 * Foundation.log10(Swift.max(gain, 1e-9))))
        }
        let loudest = levels.max() ?? 0
        return levels.map { (level: Float) -> Float in level - loudest }
    }

    /// A noise envelope with one bump: 0 dB at `hertz`, falling as a bell over `octaves` either way to
    /// 40 dB down.
    private func bump(at hertz: Float, octaves: Float = 0.5) -> [Float] {
        (0..<VoiceAvatar.bandCount).map { (band: Int) -> Float in
            let distance = log2f(VoiceAvatar.centre(ofBand: band) / hertz) / octaves
            return -40 + 40 * expf(-0.5 * distance * distance)
        }
    }

    /// The breath of a voice: quiet below 1 kHz, loudest between 2 and 8 kHz.
    private var breathTable: [Float] {
        (0..<VoiceAvatar.bandCount).map { (band: Int) -> Float in
            let octaves = log2f(VoiceAvatar.centre(ofBand: band) / 4_000)
            return -6 * Swift.max(Swift.abs(octaves) - 1, 0) - 3 * Swift.abs(octaves)
        }
    }

    private func makeAvatar(snapshots: [[Float]], noise: [Float]? = nil, breath: Float = 0,
                            vibrato: VoiceAvatar.Vibrato? = nil) throws -> VoiceAvatar {
        try VoiceAvatar(label: "Test tract", origin: .sound, snapshots: snapshots, noise: noise ?? breathTable,
                        breath: breath, pitchRange: (lowest: 80, highest: 800), vibrato: vibrato)
    }

    // MARK: Playing

    /// One change to the source at a frame.
    private struct Event {
        let frame: Int
        let change: (inout AvatarSource) -> Void
    }

    /// Plays `source` for `frames` samples in blocks of `block`, each event at its own frame: a block
    /// is cut where an event falls, so the event lands between two renders, as a song's notes do.
    private func play(_ source: inout AvatarSource, frames: Int, events: [Event] = [], block: Int = 256) -> [Float] {
        var out = [Float](repeating: 0, count: frames)
        let pending = events.sorted { (first: Event, second: Event) -> Bool in first.frame < second.frame }
        var next = 0
        var start = 0
        while start < frames {
            while next < pending.count, pending[next].frame <= start {
                pending[next].change(&source)
                next += 1
            }
            var end = Swift.min(start + Swift.max(block, 1), frames)
            if next < pending.count { end = Swift.min(end, pending[next].frame) }
            out[start..<end].withUnsafeMutableBufferPointer { (piece: inout UnsafeMutableBufferPointer<Float>) in
                source.render(into: piece)
            }
            start = end
        }
        return out
    }

    /// The magnitude of one frequency in `samples`, by a single-bin DFT in double precision, the
    /// rotation turned by multiplication rather than a cosine per sample.
    private static func magnitude(_ samples: ArraySlice<Float>, hertz: Double, sampleRate: Double) -> Double {
        let step = 2 * Double.pi * hertz / sampleRate
        let turnCos = Foundation.cos(step), turnSin = Foundation.sin(step)
        var cosine = 1.0, sine = 0.0
        var re = 0.0, im = 0.0
        for x in samples {
            re += Double(x) * cosine
            im -= Double(x) * sine
            (cosine, sine) = (cosine * turnCos - sine * turnSin, sine * turnCos + cosine * turnSin)
        }
        return (re * re + im * im).squareRoot() / Double(Swift.max(1, samples.count))
    }

    private func magnitude(_ samples: ArraySlice<Float>, hertz: Double) -> Double {
        Self.magnitude(samples, hertz: hertz, sampleRate: Double(rate))
    }

    private func rms(_ samples: ArraySlice<Float>) -> Float {
        var sum: Double = 0
        for x in samples { sum += Double(x) * Double(x) }
        return Float((sum / Double(Swift.max(1, samples.count))).squareRoot())
    }

    /// The power density around each of `frequencies`, in decibels: the mean power of the bins within
    /// a sixteenth of an octave either side, over Hann-windowed transforms of 4 096 samples that
    /// overlap by half, averaged (Welch) — so a noise reads its shape, not its chance peaks.
    private func densities(_ samples: [Float], at frequencies: [Double]) -> [Double] {
        let size = 4_096
        let transform = FFT(size: size)
        let window = (0..<size).map { (index: Int) -> Float in
            Float(0.5 - 0.5 * Foundation.cos(2 * Double.pi * Double(index) / Double(size)))
        }
        let binHertz = Double(rate) / Double(size)
        var totals = [Double](repeating: 0, count: frequencies.count)
        var bins = [Int](repeating: 0, count: frequencies.count)
        var start = 0
        while start + size <= samples.count {
            var real = (0..<size).map { (index: Int) -> Float in samples[start + index] * window[index] }
            var imaginary = [Float](repeating: 0, count: size)
            transform.transform(real: &real, imaginary: &imaginary)
            for (index, hertz) in frequencies.enumerated() {
                let first = Swift.max(1, Int((hertz * Foundation.pow(2, -1.0 / 16) / binHertz).rounded(.up)))
                let last = Swift.max(first, Swift.min(size / 2 - 1, Int((hertz * Foundation.pow(2, 1.0 / 16) / binHertz).rounded(.down))))
                for bin in first...last {
                    totals[index] += Double(real[bin] * real[bin] + imaginary[bin] * imaginary[bin])
                    bins[index] += 1
                }
            }
            start += size / 2
        }
        return zip(totals, bins).map { (pair: (Double, Int)) -> Double in
            10 * Foundation.log10(Swift.max(pair.0 / Double(Swift.max(pair.1, 1)), 1e-30))
        }
    }

    /// Integrated loudness after BS.1770 (`LoudnessMeter`), the samples on one channel.
    private func loudness(_ samples: [Float]) -> Double {
        var meter = LoudnessMeter(sampleRate: Double(rate))
        let silence = [Float](repeating: 0, count: samples.count)
        samples.withUnsafeBufferPointer { (left: UnsafeBufferPointer<Float>) in
            silence.withUnsafeBufferPointer { (right: UnsafeBufferPointer<Float>) in
                if let l = left.baseAddress, let r = right.baseAddress { meter.process(left: l, right: r, count: samples.count) }
            }
        }
        return meter.integratedLoudness
    }

    /// One note at `hertz`, held: the last 24 000 samples once it has settled — half a second, so a
    /// whole number of cycles of any note on a whole number of hertz, two apart (110, 164, 220 Hz),
    /// and no harmonic leaks into another's bin.
    private func held(_ avatar: VoiceAvatar, hertz: Float, settings: AvatarSource.Settings = AvatarSource.Settings(attack: 0.005, level: 1))
        -> ArraySlice<Float> {
        var source = AvatarSource(avatar: avatar, settings: settings, sampleRate: rate)
        source.noteOn(pitch: 57, velocity: 127, hertz: hertz)
        let out = play(&source, frames: 30_000)
        return out[(out.count - 24_000)...]
    }

    /// Each harmonic of `hertz` below 4 kHz whose envelope level is within 50 dB of the loudest band:
    /// its frequency, the level it sounds at and the level the avatar has there, in decibels.
    private func harmonics(_ window: ArraySlice<Float>, hertz: Float, avatar: VoiceAvatar,
                           character: Float) -> [(hertz: Double, sounding: Double, envelope: Double)] {
        var found: [(hertz: Double, sounding: Double, envelope: Double)] = []
        var k = 1
        while Float(k) * hertz < 4_000 {
            let frequency = Double(hertz) * Double(k)
            let expected = Double(avatar.level(at: Float(frequency), character: character))
            if expected > -50 {
                found.append((frequency, 20 * Foundation.log10(magnitude(window, hertz: frequency)), expected))
            }
            k += 1
        }
        return found
    }

    /// How far apart the sounding levels and the envelope's are, at most, once their one common
    /// offset is taken out: zero when every harmonic sounds exactly where the envelope puts it.
    private func spread(_ readings: [(hertz: Double, sounding: Double, envelope: Double)]) -> Double {
        let offsets = readings.map { (reading: (hertz: Double, sounding: Double, envelope: Double)) -> Double in
            reading.sounding - reading.envelope
        }
        return (offsets.max() ?? 0) - (offsets.min() ?? 0)
    }

    // MARK: The harmonics

    /// The headline of an avatar: the colour lives in hertz. A2 and A3 on the same "ah" — formants
    /// at 600, 1040 and 2250 Hz — sound every harmonic at the level the envelope has at its own
    /// frequency, and where the two notes share a frequency (every multiple of 220 Hz) they sound
    /// alike there, each against its own level at 660 Hz. A timbre kept per harmonic number would
    /// have sung A3's third harmonic, at 660 Hz, at the level of A2's third, at 330 Hz.
    func testAnOctaveApartTheFormantsStayInPlace() throws {
        let avatar = try makeAvatar(snapshots: [vowelTable(character: 0.5)])
        var shared: [Double: [Double: Double]] = [:]
        for hertz: Float in [110, 220] {
            let window = held(avatar, hertz: hertz)
            XCTAssertTrue(window.allSatisfy(\.isFinite))
            let readings = harmonics(window, hertz: hertz, avatar: avatar, character: 0.5)
            XCTAssertGreaterThan(readings.count, 8, "\(hertz) Hz")
            XCTAssertLessThan(spread(readings), 0.05, "\(hertz) Hz: every harmonic at the envelope's level, in decibels")
            var levels: [Double: Double] = [:]
            for reading in readings where Int(reading.hertz.rounded()) % 220 == 0 { levels[reading.hertz] = reading.sounding }
            shared[Double(hertz)] = levels
        }
        let low = try XCTUnwrap(shared[110]), high = try XCTUnwrap(shared[220])
        let lowAnchor = try XCTUnwrap(low[660]), highAnchor = try XCTUnwrap(high[660])
        var compared = 0
        for (frequency, level) in high {
            guard let other = low[frequency] else { continue }
            XCTAssertEqual(level - highAnchor, other - lowAnchor, accuracy: 0.05, "\(frequency) Hz")
            compared += 1
        }
        XCTAssertGreaterThan(compared, 6)
    }

    /// Character morphs between the snapshots, darkest at 0, brightest at 1: at each Character the
    /// harmonics sound at the levels the avatar gives for it, and the sound at 1 is brighter than at
    /// 0 on the avatar's own scale (`VoiceAvatar.brightness(of:)`: where the power sits on the grid).
    func testCharacterTravelsTheSnapshotsFromDarkToBright() throws {
        let avatar = try makeAvatar(snapshots: [vowelTable(character: 0), vowelTable(character: 0.5), vowelTable(character: 1)])
        var brightness: [Float: Double] = [:]
        for character: Float in [0, 0.25, 0.5, 0.8, 1] {
            // 164 Hz: 82 whole cycles in the window, so no harmonic leaks into another's bin.
            let window = held(avatar, hertz: 164, settings: AvatarSource.Settings(character: character, attack: 0.005, level: 1))
            let readings = harmonics(window, hertz: 164, avatar: avatar, character: character)
            XCTAssertGreaterThan(readings.count, 8, "character \(character)")
            XCTAssertLessThan(spread(readings), 0.05, "character \(character)")
            var weighted = 0.0, total = 0.0
            var k = 1
            while 164 * Double(k) < 16_000 {
                let frequency = 164 * Double(k)
                let power = Foundation.pow(magnitude(window, hertz: frequency), 2)
                weighted += Foundation.log2(frequency / 50) / Foundation.log2(320) * power
                total += power
                k += 1
            }
            brightness[character] = weighted / Swift.max(total, 1e-30)
        }
        XCTAssertGreaterThan(brightness[1] ?? 0, (brightness[0] ?? 1) + 0.02, "\(brightness)")
    }

    /// A note computes only its harmonics below Nyquist — all sixty-four at 300 Hz, twenty-three at
    /// 1 kHz — and one left above it, by the same key struck higher or by a voice taken for a higher
    /// note, glides out and then leaves the loop. It is set to zero once it is inaudible: left to its
    /// glide, it would stop short of zero in the subnormal range and cost on every sample for the
    /// rest of the note.
    func testAHarmonicLeftAboveNyquistFadesOutAndStopsCosting() throws {
        let avatar = try makeAvatar(snapshots: [vowelTable(character: 0.5)])
        let settings = AvatarSource.Settings(level: 1)
        func belowNyquist(_ hertz: Float) -> Int {
            (1...AvatarSource.partialCount).filter { (k: Int) -> Bool in Float(k) * hertz < rate / 2 }.count
        }
        var fresh = AvatarSource(avatar: avatar, settings: settings, voiceCount: 1, sampleRate: rate)
        fresh.noteOn(pitch: 60, velocity: 127, hertz: 1_000)
        _ = play(&fresh, frames: 4_800)
        XCTAssertEqual(fresh.harmonicsInPlay, 23)

        var source = AvatarSource(avatar: avatar, settings: settings, voiceCount: 1, sampleRate: rate)
        source.noteOn(pitch: 60, velocity: 127, hertz: 300)
        _ = play(&source, frames: 4_800)
        XCTAssertEqual(source.harmonicsInPlay, 64)
        source.noteOn(pitch: 60, velocity: 127, hertz: 700)
        XCTAssertTrue(play(&source, frames: 48_000).allSatisfy(\.isFinite))
        XCTAssertEqual(source.harmonicsInPlay, belowNyquist(700), "the same key struck higher, a second on")
        source.noteOn(pitch: 84, velocity: 127)
        let taken = play(&source, frames: 48_000)
        XCTAssertGreaterThan(rms(taken[24_000...]), 0.1)
        XCTAssertEqual(source.harmonicsInPlay, belowNyquist(Temperament.standard.frequency(of: 84)),
                       "the one voice taken for C6, a second on")
        XCTAssertEqual(source.activeVoiceCount, 1)
    }

    // MARK: Loudness

    /// Every note from A2 to D#5 and every Character from the darkest snapshot to the brightest
    /// sings at about one loudness, measured as BS.1770 measures it — breath included, a quarter of
    /// the power here: within 0.2 LU (0.063 measured on Linux; 0.008 without the breath).
    func testEveryNoteAndCharacterSingsAtAboutOneLevel() throws {
        let avatar = try makeAvatar(snapshots: [vowelTable(character: 0), vowelTable(character: 0.5), vowelTable(character: 1)],
                                    breath: 0.25)
        var readings: [Double] = []
        for pitch: UInt8 in [45, 55, 65, 75] {
            for character: Float in [0, 0.5, 1] {
                var source = AvatarSource(avatar: avatar, settings: AvatarSource.Settings(character: character, attack: 0.01, level: 1),
                                          sampleRate: rate)
                source.noteOn(pitch: pitch, velocity: 127)
                let out = play(&source, frames: 38_400)
                XCTAssertTrue(out.allSatisfy(\.isFinite))
                let reading = loudness(Array(out[9_600...]))
                XCTAssertTrue(reading.isFinite, "note \(pitch) character \(character)")
                readings.append(reading)
            }
        }
        let loudest = readings.max() ?? 0, quietest = readings.min() ?? 0
        XCTAssertLessThan(loudest - quietest, 0.2, "\(readings)")
        // A full-velocity note at level 1: the K-weighted power of a full-scale sine, on one channel.
        XCTAssertEqual(readings.reduce(0, +) / Double(readings.count), -3.7, accuracy: 0.2)
    }

    // MARK: Clicks

    /// At the brightest Character, with breath and the shortest attack: the onset starts from nothing
    /// and climbs over its first millisecond, and the key up falls along the release asked for, from
    /// where the note is to 80 dB down in its time (`Envelope`): over the first 5 ms still at nine
    /// tenths of the held level (an instant cut would be at none), halfway through a hundredth of
    /// it, the last sound within 5 ms of the release's end, then exact silence. An attack or a release
    /// is never shorter than 5 ms.
    func testANoteStartsAndEndsWithoutAClick() throws {
        XCTAssertEqual(AvatarSource.Settings(attack: 0, release: 0.000_1).clamped.attack, 0.005)
        XCTAssertEqual(AvatarSource.Settings(attack: 0, release: 0.000_1).clamped.release, 0.005)
        let avatar = try makeAvatar(snapshots: [vowelTable(character: 0), vowelTable(character: 1)], breath: 0.2)
        let release = 0.2
        var source = AvatarSource(avatar: avatar, settings: AvatarSource.Settings(character: 1, attack: 0.005, release: Float(release), level: 1),
                                  sampleRate: rate)
        let noteOff = 19_200
        let out = play(&source, frames: 38_400, events: [
            Event(frame: 0) { (synth: inout AvatarSource) in synth.noteOn(pitch: 57, velocity: 127) },
            Event(frame: noteOff) { (synth: inout AvatarSource) in synth.noteOff(pitch: 57) },
        ])
        XCTAssertTrue(out.allSatisfy(\.isFinite))
        let sustained = rms(out[9_600..<noteOff])
        XCTAssertGreaterThan(sustained, 0.1)
        XCTAssertLessThan(Swift.abs(out[0]), 0.01, "the first sample is next to nothing")
        XCTAssertLessThan(rms(out[0..<48]), sustained * 0.3, "the first millisecond is still climbing")

        // The level 5 ms long from `seconds` after the key up, against the held level.
        func released(_ seconds: Double) -> Float {
            let start = noteOff + Int((seconds * Double(rate)).rounded())
            return rms(out[start..<(start + 240)]) / sustained
        }
        XCTAssertGreaterThan(released(0), 0.8, "the key up goes on falling, no cut (0.95 measured)")
        XCTAssertEqual(released(release / 2 - 0.002_5), 0.01, accuracy: 0.004, "halfway through the release, 40 dB down")
        let last = try XCTUnwrap(out[noteOff...].lastIndex { (x: Float) -> Bool in x != 0 })
        XCTAssertEqual(Double(last - noteOff) / Double(rate), release, accuracy: 0.005,
                       "the release lasts as long as asked, then exact silence")
        XCTAssertEqual(source.activeVoiceCount, 0, "and the voice is free again")
    }

    /// An avatar swapped, or Character turned, between two renders while a note sounds: each
    /// harmonic glides to its new level instead of stepping there. Read period by period (a 240 Hz
    /// note, 200 samples, so every harmonic is a whole number of cycles in a window), the harmonics
    /// that move by more than 3 dB have gone about half the way over the first 4 ms (0.48 to 0.57
    /// measured, wherever the change falls between two control steps; harmonics that step there read
    /// 1.0 to 1.13) and all of it by 21 ms. With breath on both sides, a swapped note then goes on in
    /// the new avatar's colour.
    func testSwappingTheAvatarBetweenBlocksDoesNotStep() throws {
        let settings = AvatarSource.Settings(character: 0, attack: 0.005, level: 1)
        let period = 200
        // Without breath, so that a harmonic reads clean in one period.
        let dark = try makeAvatar(snapshots: [vowelTable(character: 0)])
        let bright = try makeAvatar(snapshots: [vowelTable(character: 1)])
        let both = try makeAvatar(snapshots: [vowelTable(character: 0), vowelTable(character: 1)])
        let turned = AvatarSource.Settings(character: 1, attack: 0.005, level: 1)
        let changes: [(name: String, avatar: VoiceAvatar, change: (inout AvatarSource) -> Void)] = [
            ("avatar swapped", dark, { (synth: inout AvatarSource) in synth.setAvatar(bright) }),
            ("Character turned", both, { (synth: inout AvatarSource) in synth.setSettings(turned) }),
        ]
        for (name, avatar, change) in changes {
            for swap in [24_000, 24_010, 24_031] {
                var source = AvatarSource(avatar: avatar, settings: settings, sampleRate: rate)
                source.noteOn(pitch: 57, velocity: 127, hertz: 240)
                let out = play(&source, frames: 50_000, events: [Event(frame: swap, change: change)])
                XCTAssertTrue(out.allSatisfy(\.isFinite))
                assertGlides(out, at: swap, period: period, "\(name) at \(swap)")
            }
        }

        let breathyDark = try makeAvatar(snapshots: [vowelTable(character: 0)], breath: 0.1)
        let breathyBright = try makeAvatar(snapshots: [vowelTable(character: 1)], noise: bump(at: 6_000), breath: 0.3)
        var source = AvatarSource(avatar: breathyDark, settings: settings, sampleRate: rate)
        source.noteOn(pitch: 57, velocity: 127, hertz: 240)
        let out = play(&source, frames: 60_000, events: [
            Event(frame: 24_000) { (synth: inout AvatarSource) in synth.setAvatar(breathyBright) },
        ])
        XCTAssertTrue(out.allSatisfy(\.isFinite))
        let settled = harmonics(out[(out.count - 24_000)...], hertz: 240, avatar: breathyBright, character: 0.5)
        XCTAssertGreaterThan(settled.count, 4)
        XCTAssertLessThan(spread(settled.filter { (reading: (hertz: Double, sounding: Double, envelope: Double)) -> Bool in
            reading.envelope > -30
        }), 1, "the note goes on in the new avatar's colour")
    }

    /// That the harmonics of the 240 Hz note in `out` glide around a change at `swap`, read in
    /// windows of `period` samples, one cycle of the note (see the test above): each harmonic that
    /// moves by more than 3 dB, its level before the change and once settled; then the median of
    /// how far they have gone in a window, from 0 at the old level to 1 at the new.
    private func assertGlides(_ out: [Float], at swap: Int, period: Int, _ label: String) {
        var moving: [(hertz: Double, before: Double, after: Double)] = []
        for k in 1...40 {
            let hertz = 240 * Double(k)
            let before = magnitude(out[(swap - 4_000)..<swap], hertz: hertz)
            let after = magnitude(out[(swap + 20_000)..<(swap + 24_000)], hertz: hertz)
            if Swift.max(before, after) > 1e-3, Swift.abs(20 * Foundation.log10(after / before)) > 3 {
                moving.append((hertz, before, after))
            }
        }
        XCTAssertGreaterThan(moving.count, 8, label)
        guard !moving.isEmpty else { return }
        func gone(inPeriod n: Int) -> Double {
            let start = swap + n * period
            let shares = moving.map { (harmonic: (hertz: Double, before: Double, after: Double)) -> Double in
                (magnitude(out[start..<(start + period)], hertz: harmonic.hertz) - harmonic.before) / (harmonic.after - harmonic.before)
            }.sorted()
            return shares[shares.count / 2]
        }
        XCTAssertEqual(gone(inPeriod: -1), 0, accuracy: 0.02, "\(label): nothing moves before it")
        XCTAssertLessThan(gone(inPeriod: 0), 0.75, "\(label): the first 4 ms glide, they do not step")
        XCTAssertGreaterThan(gone(inPeriod: 4), 0.95, "\(label): arrived by 21 ms")
    }

    // MARK: Notes

    /// Notes take voices as `PolySynth` takes them, here on two: two keys each take a free voice; a
    /// third takes the oldest held one, whose note stops while the other sings on; letting go of the
    /// key that lost its voice changes nothing; a key struck while one note falls in its release
    /// takes that voice, not the held one; the newest held key struck again keeps its own voice,
    /// though the other is older; and all notes off lets everything fall silent. Each note is read
    /// at its own fundamental (200, 230, 270 and 310 Hz, whole cycles in 0.1 s, where no other note
    /// has a harmonic).
    func testNotesTakeVoicesInPolySynthsOrder() throws {
        let avatar = try makeAvatar(snapshots: [vowelTable(character: 0.5)])
        var source = AvatarSource(avatar: avatar, settings: AvatarSource.Settings(attack: 0.005, release: 0.05, level: 1),
                                  voiceCount: 2, sampleRate: rate)
        let out = play(&source, frames: 72_000, events: [
            Event(frame: 0) { (synth: inout AvatarSource) in
                synth.noteOn(pitch: 60, velocity: 127, hertz: 200)
                synth.noteOn(pitch: 62, velocity: 127, hertz: 230)
            },
            Event(frame: 14_400) { (synth: inout AvatarSource) in synth.noteOn(pitch: 64, velocity: 127, hertz: 270) },
            Event(frame: 24_000) { (synth: inout AvatarSource) in synth.noteOff(pitch: 60) },
            Event(frame: 33_600) { (synth: inout AvatarSource) in synth.noteOff(pitch: 62) },
            Event(frame: 34_560) { (synth: inout AvatarSource) in synth.noteOn(pitch: 65, velocity: 127, hertz: 310) },
            Event(frame: 48_000) { (synth: inout AvatarSource) in synth.noteOn(pitch: 65, velocity: 127, hertz: 310) },
            Event(frame: 57_600) { (synth: inout AvatarSource) in synth.allNotesOff() },
        ])
        XCTAssertTrue(out.allSatisfy(\.isFinite))
        // The level of each fundamental in the 0.1 s from `frame`.
        func level(_ hertz: Double, at frame: Int) -> Double { magnitude(out[frame..<(frame + 4_800)], hertz: hertz) }
        let first = (low: level(200, at: 9_600), next: level(230, at: 9_600))
        XCTAssertGreaterThan(first.low, 0.01, "two keys, two free voices")
        XCTAssertGreaterThan(first.next, 0.01, "two keys, two free voices")
        XCTAssertLessThan(level(200, at: 19_200), first.low * 0.01, "the third key took the oldest held voice")
        XCTAssertEqual(level(230, at: 19_200), first.next, accuracy: first.next * 0.01, "the other sings on")
        let third = level(270, at: 19_200)
        XCTAssertGreaterThan(third, 0.01)
        XCTAssertEqual(level(230, at: 28_800), first.next, accuracy: first.next * 0.01, "letting go of a taken key changes nothing")
        XCTAssertEqual(level(270, at: 28_800), third, accuracy: third * 0.01, "letting go of a taken key changes nothing")
        XCTAssertLessThan(level(230, at: 43_200), first.next * 0.01, "a key struck during a release takes the released voice")
        XCTAssertEqual(level(270, at: 43_200), third, accuracy: third * 0.01, "and leaves the held one")
        let fourth = level(310, at: 43_200)
        XCTAssertGreaterThan(fourth, 0.01)
        XCTAssertEqual(level(310, at: 52_800), fourth, accuracy: fourth * 0.01, "a held key struck again keeps its voice")
        XCTAssertEqual(level(270, at: 52_800), third, accuracy: third * 0.01, "and takes no other, though it is older")
        XCTAssertTrue(out[62_400...].allSatisfy { $0 == 0 }, "all notes off: everything falls silent")
        XCTAssertEqual(source.activeVoiceCount, 0)
    }

    /// The notes share one breath, as loud as theirs would add up in power: four notes breathe
    /// twice as loud as one (6.02 dB). Velocity sets a note's level by its square, breath and tone
    /// alike: velocity 64 sings at (64/127)², 11.9 dB under a full one.
    func testFourNotesBreatheTwiceAsLoudAsOne() throws {
        let air = try makeAvatar(snapshots: [], noise: bump(at: 2_000))
        let voiced = try makeAvatar(snapshots: [vowelTable(character: 0.5)])
        func sing(_ avatar: VoiceAvatar, _ pitches: [UInt8], velocity: UInt8 = 127) -> Float {
            var source = AvatarSource(avatar: avatar, settings: AvatarSource.Settings(level: 1), sampleRate: rate)
            for pitch in pitches { source.noteOn(pitch: pitch, velocity: velocity) }
            let out = play(&source, frames: 24_000)
            XCTAssertTrue(out.allSatisfy(\.isFinite))
            return rms(out[9_600...])
        }
        let one = sing(air, [57])
        XCTAssertGreaterThan(one, 0.05)
        XCTAssertEqual(Double(20 * log10f(sing(air, [57, 60, 64, 67]) / one)), 6.02, accuracy: 0.01, "four notes, twice as loud")
        let square = 40 * Foundation.log10(64.0 / 127)
        XCTAssertEqual(Double(20 * log10f(sing(air, [57], velocity: 64) / one)), square, accuracy: 0.01, "the breath at velocity 64")
        XCTAssertEqual(Double(20 * log10f(sing(voiced, [57], velocity: 64) / sing(voiced, [57]))), square, accuracy: 0.01,
                       "the tone at velocity 64")
    }

    // MARK: Bad input

    /// A frequency that is not one a harmonic can sound at — not a number, not above zero, at or
    /// above Nyquist — sings nothing, and so does a key outside MIDI; the lowest and the highest key
    /// sing and stay finite, and a Character or a setting that is not a number is its default.
    func testABadPitchIsSilenceNeverNaN() throws {
        let avatar = try makeAvatar(snapshots: [vowelTable(character: 0.5)], breath: 0.3,
                                    vibrato: VoiceAvatar.Vibrato(rate: 5, depth: 60))
        for hertz: Float in [.nan, .infinity, -.infinity, 0, -220, 24_000, 30_000, .greatestFiniteMagnitude] {
            var source = AvatarSource(avatar: avatar, sampleRate: rate)
            source.noteOn(pitch: 60, velocity: 127, hertz: hertz)
            XCTAssertEqual(source.activeVoiceCount, 0, "\(hertz) Hz")
            XCTAssertTrue(play(&source, frames: 4_800).allSatisfy { $0 == 0 }, "\(hertz) Hz")
        }
        // MIDI's top key, 12.5 kHz, lies above Nyquist at 16 kHz: silence there.
        var slow = AvatarSource(avatar: avatar, sampleRate: 16_000)
        slow.noteOn(pitch: 127, velocity: 127)
        XCTAssertTrue(play(&slow, frames: 1_600).allSatisfy { $0 == 0 })
        var outside = AvatarSource(avatar: avatar, sampleRate: rate)
        outside.noteOn(pitch: 128, velocity: 127)
        outside.noteOn(pitch: 255, velocity: 127, hertz: 440)
        XCTAssertEqual(outside.activeVoiceCount, 0)

        // A note just under Nyquist, its vibrato swinging it across: finite, and silent once it is over.
        var edge = AvatarSource(avatar: avatar, settings: AvatarSource.Settings(attack: 0.005, level: 1), sampleRate: rate)
        edge.noteOn(pitch: 60, velocity: 127, hertz: 23_990)
        XCTAssertEqual(edge.activeVoiceCount, 1)
        XCTAssertTrue(play(&edge, frames: 9_600).allSatisfy(\.isFinite))
        XCTAssertEqual(edge.activeVoiceCount, 0, "carried above Nyquist, the note fell silent")

        for pitch: UInt8 in [0, 127] {
            var source = AvatarSource(avatar: avatar, settings: AvatarSource.Settings(level: 1), sampleRate: rate)
            source.noteOn(pitch: pitch, velocity: 127)
            let out = play(&source, frames: 9_600)
            XCTAssertTrue(out.allSatisfy(\.isFinite), "pitch \(pitch)")
            XCTAssertGreaterThan(rms(out[4_800...]), 0.01, "pitch \(pitch)")
        }

        let nonsense = AvatarSource.Settings(character: .nan, attack: .infinity, release: -.infinity, vibrato: .nan, level: .nan)
        XCTAssertEqual(nonsense.clamped, AvatarSource.Settings())
        var fromNonsense = AvatarSource(avatar: avatar, settings: nonsense, sampleRate: .nan)
        var fromDefaults = AvatarSource(avatar: avatar, sampleRate: 48_000)
        fromNonsense.noteOn(pitch: 57, velocity: 100)
        fromDefaults.noteOn(pitch: 57, velocity: 100)
        let first = play(&fromNonsense, frames: 4_800), second = play(&fromDefaults, frames: 4_800)
        XCTAssertTrue(first.allSatisfy(\.isFinite))
        XCTAssertEqual(first, second)
    }

    // MARK: Determinism

    /// The same note struck twice on a silent voice sings the same samples, breath and vibrato
    /// included, and a fresh source sings the same performance sample for sample, in blocks of any
    /// size: an export renders what playback played, whatever buffer either ran at.
    func testTheSameNoteSingsTheSameEveryTime() throws {
        let avatar = try makeAvatar(snapshots: [vowelTable(character: 0), vowelTable(character: 1)], breath: 0.3,
                                    vibrato: VoiceAvatar.Vibrato(rate: 5.5, depth: 40))
        func strikeTwice(block: Int = 256) -> [Float] {
            var source = AvatarSource(avatar: avatar, settings: AvatarSource.Settings(character: 0.4, release: 0.1), sampleRate: rate)
            return play(&source, frames: 48_000, events: [
                Event(frame: 0) { (synth: inout AvatarSource) in synth.noteOn(pitch: 52, velocity: 110) },
                Event(frame: 3_000) { (synth: inout AvatarSource) in synth.noteOn(pitch: 59, velocity: 90) },
                Event(frame: 9_600) { (synth: inout AvatarSource) in synth.allNotesOff() },
                Event(frame: 28_800) { (synth: inout AvatarSource) in synth.noteOn(pitch: 52, velocity: 110) },
                Event(frame: 31_800) { (synth: inout AvatarSource) in synth.noteOn(pitch: 59, velocity: 90) },
                Event(frame: 38_400) { (synth: inout AvatarSource) in synth.allNotesOff() },
            ], block: block)
        }
        let first = strikeTwice()
        XCTAssertTrue(first.allSatisfy(\.isFinite))
        XCTAssertGreaterThan(rms(first[2_400..<9_600]), 0.01)
        XCTAssertTrue(first[19_200..<28_800].allSatisfy { $0 == 0 }, "the first notes have ended before the second")
        XCTAssertEqual(Array(first[0..<19_200]), Array(first[28_800..<48_000]), "struck again, the same samples")
        XCTAssertEqual(strikeTwice(), first, "a fresh source, the same samples")
        for block in [1, 7, 1_000, 4_096] {
            XCTAssertEqual(strikeTwice(block: block), first, "in blocks of \(block), the same samples")
        }
    }

    // MARK: Breath and vibrato

    /// The breath has the shape of the avatar's noise envelope: an avatar of breath alone whose noise
    /// peaks at 2 kHz is loudest there, by far, and one peaking at 500 Hz moves the peak with it.
    /// Without breath, nothing sounds between the harmonics.
    func testTheBreathIsShapedByTheNoiseEnvelope() throws {
        for peak: Float in [500, 2_000] {
            let avatar = try makeAvatar(snapshots: [], noise: bump(at: peak), breath: 0)
            var source = AvatarSource(avatar: avatar, settings: AvatarSource.Settings(level: 1), sampleRate: rate)
            source.noteOn(pitch: 57, velocity: 127)
            let window = Array(play(&source, frames: 33_600)[9_600...])
            XCTAssertTrue(window.allSatisfy(\.isFinite))
            XCTAssertGreaterThan(rms(window[...]), 0.05, "an avatar of breath alone breathes")
            // The power in a quarter-octave around a frequency, from a few hundred bins.
            func density(_ hertz: Double) -> Double {
                var total = 0.0
                for step in -8...8 {
                    total += Foundation.pow(magnitude(window[...], hertz: hertz * Foundation.pow(2, Double(step) / 64)), 2)
                }
                return total
            }
            let at = density(Double(peak))
            for other: Double in [Double(peak) / 4, Double(peak) * 4] {
                XCTAssertGreaterThan(10 * Foundation.log10(at / density(other)), 25, "peak \(peak) against \(other) Hz")
            }
        }

        let ah = vowelTable(character: 0.5)
        var between: [Float: Double] = [:]
        for breath: Float in [0, 0.5] {
            let window = held(try makeAvatar(snapshots: [ah], breath: breath), hertz: 220)
            var sum = 0.0
            for hertz in [330.0, 550, 770, 990, 1_210, 1_430, 2_530, 3_190] { sum += magnitude(window, hertz: hertz) }
            between[breath] = sum
        }
        XCTAssertLessThan(between[0] ?? 1, 1e-4, "no breath: nothing between the harmonics but rounding")
        XCTAssertGreaterThan(between[0.5] ?? 0, 1e-3, "breath fills the space between them")
    }

    /// A flat noise envelope breathes flat: an avatar of breath alone, read in eighth octaves from
    /// 200 Hz to 10 kHz, lies within 2 dB of its median everywhere (1.1 dB at most measured). Its
    /// bands summed alike, without every other one turned over, left notches down to 15 dB deep on
    /// this grid.
    func testAFlatNoiseEnvelopeBreathesFlat() throws {
        let avatar = try makeAvatar(snapshots: [], noise: [Float](repeating: 0, count: VoiceAvatar.bandCount))
        var source = AvatarSource(avatar: avatar, settings: AvatarSource.Settings(level: 1), sampleRate: rate)
        source.noteOn(pitch: 57, velocity: 127)
        let breath = Array(play(&source, frames: 105_600)[9_600...])
        XCTAssertTrue(breath.allSatisfy(\.isFinite))
        var grid: [Double] = []
        var hertz = 200.0
        while hertz <= 10_000 {
            grid.append(hertz)
            hertz *= Foundation.pow(2, 1.0 / 8)
        }
        XCTAssertEqual(grid.count, 46)
        let levels = densities(breath, at: grid)
        let median = levels.sorted()[levels.count / 2]
        for (frequency, level) in zip(grid, levels) {
            XCTAssertEqual(level, median, accuracy: 2, "\(Int(frequency)) Hz")
        }
    }

    /// The notes sing the avatar's vibrato: once it has set in, the pitch swings by its depth either
    /// way at its rate; over the first tenth of a second it is still small; at `vibrato` 0 the pitch
    /// holds.
    func testTheVibratoSwingsAtTheAvatarsRateAndDepth() throws {
        let avatar = try makeAvatar(snapshots: [vowelTable(character: 0.5)], vibrato: VoiceAvatar.Vibrato(rate: 5, depth: 50))
        func pitches(vibrato: Float, frames: Int) -> [(time: Double, cents: Double)] {
            var source = AvatarSource(avatar: avatar, settings: AvatarSource.Settings(attack: 0.005, vibrato: vibrato, level: 1),
                                      sampleRate: rate)
            source.noteOn(pitch: 57, velocity: 127, hertz: 220)
            let out = play(&source, frames: frames)
            let tracker = PitchTracker(sampleRate: Double(rate))
            var found: [(time: Double, cents: Double)] = []
            for (index, sample) in out.enumerated() where tracker.push(sample) && tracker.period > 0 {
                found.append((Double(index) / Double(rate), 1_200 * Foundation.log2(tracker.frequency / 220)))
            }
            return found
        }
        let swinging = pitches(vibrato: 1, frames: 96_000)
        let settled = swinging.filter { (point: (time: Double, cents: Double)) -> Bool in point.time > 0.6 }
        XCTAssertGreaterThan(settled.count, 200)
        let highest = settled.map(\.cents).max() ?? 0, lowest = settled.map(\.cents).min() ?? 0
        XCTAssertEqual(highest, 50, accuracy: 8, "the depth upward")
        XCTAssertEqual(lowest, -50, accuracy: 8, "the depth downward")
        var crossings = 0
        for index in 1..<settled.count where settled[index - 1].cents < 0 && settled[index].cents >= 0 { crossings += 1 }
        XCTAssertEqual(Double(crossings) / ((settled.last?.time ?? 1) - (settled.first?.time ?? 0)), 5, accuracy: 0.8, "the rate")
        let early = swinging.filter { (point: (time: Double, cents: Double)) -> Bool in point.time < 0.1 }
        XCTAssertLessThan(early.map { (point: (time: Double, cents: Double)) -> Double in Swift.abs(point.cents) }.max() ?? 99, 25,
                          "the vibrato sets in")
        let still = pitches(vibrato: 0, frames: 24_000).filter { (point: (time: Double, cents: Double)) -> Bool in point.time > 0.1 }
        XCTAssertLessThan(still.map { (point: (time: Double, cents: Double)) -> Double in Swift.abs(point.cents) }.max() ?? 99, 3)
    }
}
