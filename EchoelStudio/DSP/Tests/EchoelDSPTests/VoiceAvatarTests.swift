import Foundation
import XCTest
@testable import EchoelDSP

/// The voice avatar (VA-1): a timbre measured from a sound and never a recording of it — tables on a
/// band grid in hertz, snapshots from dark to bright, a noise envelope — and an encoding that keeps
/// every number exactly.
final class VoiceAvatarTests: XCTestCase {
    /// Every band at `decibels`.
    private func flat(_ decibels: Float) -> [Float] {
        [Float](repeating: decibels, count: VoiceAvatar.bandCount)
    }

    /// A tilt of `slope` dB per band about the middle of the grid: negative is dark, positive bright.
    private func tilt(_ slope: Float) -> [Float] {
        (0..<VoiceAvatar.bandCount).map { (band: Int) -> Float in slope * (Float(band) - 23.5) }
    }

    /// Levels across the whole range a table holds, every bit of the mantissa in play, after the
    /// edges of that range; the same every run for the same `state`.
    private func scattered(_ state: inout UInt64) -> [Float] {
        let lowest = VoiceAvatar.floorDecibels, highest = VoiceAvatar.ceilingDecibels
        var levels: [Float] = [lowest, highest, 0, Float.leastNormalMagnitude, -Float.leastNormalMagnitude,
                               lowest.nextUp, highest.nextDown, 1 / 3, -1 / 3, 0.1]
        while levels.count < VoiceAvatar.bandCount {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            let unit = Float(state >> 40) / Float(1 << 24)
            levels.append(lowest + (highest - lowest) * unit)
        }
        return levels
    }

    private func bits(_ table: [Float]) -> [UInt32] {
        table.map { (level: Float) -> UInt32 in level.bitPattern }
    }

    private func makeAvatar(label: String = "Test", origin: VoiceAvatar.Origin = .sound, snapshots: [[Float]]? = nil,
                            noise: [Float]? = nil, breath: Float = 0.2,
                            pitchRange: (lowest: Float, highest: Float)? = (lowest: 110, highest: 440),
                            vibrato: VoiceAvatar.Vibrato? = nil) throws -> VoiceAvatar {
        try VoiceAvatar(label: label, origin: origin, snapshots: snapshots ?? [tilt(-1), flat(0), tilt(1)],
                        noise: noise ?? flat(-40), breath: breath, pitchRange: pitchRange, vibrato: vibrato)
    }

    /// The level `VoiceAvatar.level(at:in:)` reads from `table` at `hertz`.
    private func read(_ table: [Float], at hertz: Float) -> Float {
        table.withUnsafeBufferPointer { (levels: UnsafeBufferPointer<Float>) -> Float in
            VoiceAvatar.level(at: hertz, in: levels)
        }
    }

    /// The refusal `make` throws, or nil when it makes an avatar.
    private func refusal(_ make: () throws -> VoiceAvatar) -> VoiceAvatar.Refusal? {
        do {
            _ = try make()
            return nil
        } catch {
            return error as? VoiceAvatar.Refusal
        }
    }

    /// An encoding as a JSON object, to change a field and read it back.
    private func jsonObject(of encoding: Data) throws -> [String: Any] {
        try XCTUnwrap(JSONSerialization.jsonObject(with: encoding) as? [String: Any])
    }

    /// `fields` with `key` set to `value` (removed for nil), written back as JSON.
    private func edited(_ fields: [String: Any], _ key: String, _ value: Any?) throws -> Data {
        var changed = fields
        changed[key] = value
        return try JSONSerialization.data(withJSONObject: changed)
    }

    func testTheBandGridIsLogSpacedFromFiftyHertzToSixteenKilohertz() {
        XCTAssertEqual(VoiceAvatar.bandCount, 48)
        let centres = VoiceAvatar.bandCentres
        XCTAssertEqual(centres.count, 48)
        XCTAssertEqual(centres.first, 50, "the first band sits at 50 Hz exactly")
        XCTAssertEqual(centres.last, 16_000, "the last band sits at 16 kHz exactly")

        // Neighbours (16 000 / 50)^(1/47) apart: about ×1.1306, 2.125 semitones.
        let ratio = Foundation.pow(16_000.0 / 50, 1.0 / 47)
        XCTAssertEqual(VoiceAvatar.bandRatio, ratio, accuracy: 1e-12)
        XCTAssertEqual(ratio, 1.130_579_39, accuracy: 1e-8)
        XCTAssertEqual(12 * log2(ratio), 2.124_75, accuracy: 1e-5)
        for band in 0..<47 {
            XCTAssertEqual(Double(centres[band + 1]) / Double(centres[band]), ratio, accuracy: 1e-6,
                           "bands \(band) and \(band + 1)")
        }

        // Every centre is 50 · 320^(band / 47), computed: the second band 56.53 Hz, the middle one
        // 951.0 Hz, the last but one 14 152 Hz.
        for band in 0..<48 {
            let exact = 50 * Foundation.pow(320, Double(band) / 47)
            XCTAssertEqual(Double(VoiceAvatar.centre(ofBand: band)), exact, accuracy: exact * 1e-6, "band \(band)")
            XCTAssertEqual(VoiceAvatar.centre(ofBand: band), centres[band])
        }
        XCTAssertEqual(VoiceAvatar.centre(ofBand: 1), 56.529, accuracy: 1e-3)
        XCTAssertEqual(VoiceAvatar.centre(ofBand: 24), 951.03, accuracy: 1e-2)
        XCTAssertEqual(VoiceAvatar.centre(ofBand: 46), 14_152.04, accuracy: 1e-2)
        XCTAssertEqual(VoiceAvatar.centre(ofBand: -1), 50, "an index outside the grid reads its nearest end")
        XCTAssertEqual(VoiceAvatar.centre(ofBand: 48), 16_000)
    }

    func testALevelBetweenBandsIsInterpolatedInLogFrequency() throws {
        // Band n at −2n dB.
        let levels = (0..<48).map { (band: Int) -> Float in -2 * Float(band) }
        for band in 0..<48 {
            XCTAssertEqual(read(levels, at: VoiceAvatar.centre(ofBand: band)), levels[band], accuracy: 1e-3, "band \(band)")
        }

        // Halfway and a quarter of the way from band 10 to band 11 on a log-frequency axis.
        let ratio = VoiceAvatar.bandRatio
        XCTAssertEqual(read(levels, at: Float(50 * Foundation.pow(ratio, 10.5))), -21, accuracy: 1e-3)
        XCTAssertEqual(read(levels, at: Float(50 * Foundation.pow(ratio, 10.25))), -20.5, accuracy: 1e-3)

        // The middle in hertz lies past the middle in log frequency: 51.53 % of the way, so it reads
        // −21.031 dB where a straight line in hertz would give −21.
        let low = Double(VoiceAvatar.centre(ofBand: 10)), high = Double(VoiceAvatar.centre(ofBand: 11))
        let share = Foundation.log((low + high) / 2 / low) / Foundation.log(high / low)
        XCTAssertEqual(share, 0.515_33, accuracy: 1e-5)
        let middle = read(levels, at: Float((low + high) / 2))
        XCTAssertEqual(middle, -21.030_66, accuracy: 1e-3)
        XCTAssertGreaterThan(Swift.abs(middle + 21), 0.02, "not a straight line in hertz")

        // Held at the ends; a frequency that is not a number reads as the floor, and so does a table
        // that is not on the grid.
        for hertz: Float in [50, 49.9, 20, 0, -100, -.infinity] {
            XCTAssertEqual(read(levels, at: hertz), 0, "\(hertz) Hz")
        }
        for hertz: Float in [16_000, 16_001, 24_000, .infinity] {
            XCTAssertEqual(read(levels, at: hertz), -94, "\(hertz) Hz")
        }
        XCTAssertEqual(read(levels, at: .nan), VoiceAvatar.floorDecibels)
        XCTAssertEqual(read(Array(levels.prefix(47)), at: 440), VoiceAvatar.floorDecibels)

        // The avatar reads its own tables the same way.
        let avatar = try makeAvatar(snapshots: [levels], noise: levels)
        for hertz: Float in [50, 82.4, 440, 1_234.5, 9_000, 16_000, .nan] {
            XCTAssertEqual(avatar.level(at: hertz, character: 0.7).bitPattern, read(levels, at: hertz).bitPattern, "\(hertz) Hz")
            XCTAssertEqual(avatar.noiseLevel(at: hertz).bitPattern, read(levels, at: hertz).bitPattern, "\(hertz) Hz")
        }
    }

    func testAnAvatarRoundTripsThroughItsEncodingBitForBit() throws {
        var state: UInt64 = 0x2545_F491_4F6C_DD1D
        var snapshots: [[Float]] = []
        for _ in 0..<VoiceAvatar.maximumSnapshots { snapshots.append(scattered(&state)) }
        let original = try VoiceAvatar(label: "My voice, low takes", origin: .ownVoice, snapshots: snapshots,
                                       noise: scattered(&state), breath: 0.3,
                                       pitchRange: (lowest: 82.406_89, highest: 659.255_1),
                                       vibrato: VoiceAvatar.Vibrato(rate: 5.37, depth: 41.3))
        let encoding = try original.encoded()
        let decoded = try VoiceAvatar(encoded: encoding)

        XCTAssertEqual(decoded, original)
        XCTAssertEqual(decoded.snapshots.count, 8)
        for (index, snapshot) in original.snapshots.enumerated() {
            XCTAssertEqual(bits(decoded.snapshots[index]), bits(snapshot), "snapshot \(index)")
        }
        XCTAssertEqual(bits(decoded.noise), bits(original.noise))
        XCTAssertEqual(decoded.breath.bitPattern, original.breath.bitPattern)
        let range = try XCTUnwrap(decoded.pitchRange), originalRange = try XCTUnwrap(original.pitchRange)
        XCTAssertEqual(range.lowerBound.bitPattern, originalRange.lowerBound.bitPattern)
        XCTAssertEqual(range.upperBound.bitPattern, originalRange.upperBound.bitPattern)
        let vibrato = try XCTUnwrap(decoded.vibrato), originalVibrato = try XCTUnwrap(original.vibrato)
        XCTAssertEqual(vibrato.rate.bitPattern, originalVibrato.rate.bitPattern)
        XCTAssertEqual(vibrato.depth.bitPattern, originalVibrato.depth.bitPattern)
        XCTAssertEqual(decoded.label, "My voice, low takes")
        XCTAssertEqual(decoded.origin, .ownVoice)

        // The same avatar always stores the same bytes, and they are few: eight snapshots, the noise
        // and a short label in under 3 KB.
        XCTAssertEqual(try decoded.encoded(), encoding)
        XCTAssertEqual(try original.encoded(), encoding)
        XCTAssertLessThan(encoding.count, 3_000)

        // Under 6 KB whatever the label. This one fills both limits with what JSON writes longest:
        // 127 control characters, six bytes each (`\u0001`), and a quote carrying marks up to 512
        // bytes. It comes back byte for byte.
        let widest = String(repeating: "\u{1}", count: 127) + "\"" + String(repeating: "\u{301}", count: 192)
        XCTAssertEqual(widest.count, VoiceAvatar.maximumLabelLength)
        XCTAssertEqual(widest.utf8.count, VoiceAvatar.maximumLabelBytes)
        let labelled = try VoiceAvatar(label: widest, origin: .ownVoice, snapshots: snapshots, noise: original.noise,
                                       breath: 0.3, pitchRange: (lowest: 82.406_89, highest: 659.255_1),
                                       vibrato: VoiceAvatar.Vibrato(rate: 5.37, depth: 41.3))
        let stored = try labelled.encoded()
        XCTAssertLessThan(stored.count, 6_000)
        XCTAssertEqual(Array(try VoiceAvatar(encoded: stored).label.utf8), Array(widest.utf8))

        // An avatar of noise only — nothing voiced, no pitch, no vibrato — comes back the same too.
        let breathOnly = try VoiceAvatar(label: "Breath", origin: .sound, snapshots: [], noise: scattered(&state), breath: 1)
        let again = try VoiceAvatar(encoded: try breathOnly.encoded())
        XCTAssertEqual(again, breathOnly)
        XCTAssertEqual(bits(again.noise), bits(breathOnly.noise))
        XCTAssertTrue(again.snapshots.isEmpty)
        XCTAssertNil(again.pitchRange)
        XCTAssertNil(again.vibrato)
    }

    func testNonFiniteOrOutOfRangeTablesAreSanitised() throws {
        let floorLevel = VoiceAvatar.floorDecibels
        XCTAssertEqual(floorLevel, -120)
        XCTAssertEqual(VoiceAvatar.ceilingDecibels, 24)

        var damaged = flat(-30)
        let bad: [Float] = [.nan, .infinity, -.infinity, 500, -500, 24.5, -121, -120, 24, -0.0,
                            .leastNonzeroMagnitude, -Float.leastNormalMagnitude / 2]
        for (band, level) in bad.enumerated() { damaged[band] = level }
        let avatar = try makeAvatar(snapshots: [damaged], noise: damaged, breath: .nan)
        let expected: [Float] = [floorLevel, floorLevel, floorLevel, floorLevel, floorLevel, floorLevel, floorLevel,
                                 -120, 24, 0, 0, 0]
        XCTAssertEqual(Array(avatar.snapshots[0].prefix(bad.count)), expected)
        XCTAssertEqual(Array(avatar.noise.prefix(bad.count)), expected)
        XCTAssertEqual(Array(avatar.snapshots[0].suffix(48 - bad.count)), [Float](repeating: -30, count: 48 - bad.count),
                       "a level in range is kept as it is")
        for band in 9..<12 {
            XCTAssertEqual(avatar.snapshots[0][band].bitPattern, 0, "minus zero and subnormals are stored as zero")
        }
        XCTAssertEqual(avatar.breath, 0, "a breath share that is not a number is none")
        XCTAssertTrue(avatar.envelope(character: 0.5).allSatisfy(\.isFinite))

        // Breath is a share. A pitch range is ordered and held to where pitch can be; one with a
        // bound that is not a number is none.
        XCTAssertEqual(try makeAvatar(breath: -1).breath, 0)
        XCTAssertEqual(try makeAvatar(breath: 3).breath, 1)
        XCTAssertNil(try makeAvatar(pitchRange: (lowest: .nan, highest: 440)).pitchRange)
        XCTAssertNil(try makeAvatar(pitchRange: (lowest: 110, highest: .infinity)).pitchRange)
        let reversed = try XCTUnwrap(try makeAvatar(pitchRange: (lowest: 440, highest: 110)).pitchRange)
        XCTAssertEqual(reversed.lowerBound, 110)
        XCTAssertEqual(reversed.upperBound, 440)
        let wide = try XCTUnwrap(try makeAvatar(pitchRange: (lowest: 5, highest: 40_000)).pitchRange)
        XCTAssertEqual(wide.lowerBound, 20)
        XCTAssertEqual(wide.upperBound, 16_000)

        // A vibrato that is not one is none; one beyond reason is held at the top.
        XCTAssertNil(VoiceAvatar.Vibrato(rate: .nan, depth: 30))
        XCTAssertNil(VoiceAvatar.Vibrato(rate: 5, depth: 0))
        XCTAssertNil(VoiceAvatar.Vibrato(rate: -5, depth: 30))
        XCTAssertNil(VoiceAvatar.Vibrato(rate: 5, depth: .infinity))
        let wild = try XCTUnwrap(VoiceAvatar.Vibrato(rate: 40, depth: 5_000))
        XCTAssertEqual(wild.rate, 20)
        XCTAssertEqual(wild.depth, 600)

        // A character outside 0 … 1 is held to it; one that is not a number is the middle.
        let morph = try makeAvatar()
        XCTAssertEqual(morph.envelope(character: .nan), morph.envelope(character: 0.5))
        XCTAssertEqual(morph.envelope(character: -3), morph.envelope(character: 0))
        XCTAssertEqual(morph.envelope(character: 7), morph.envelope(character: 1))

        // A table of the wrong length is refused, and so are more than eight snapshots.
        XCTAssertEqual(refusal { try makeAvatar(snapshots: [[Float](repeating: 0, count: 47)]) }, .wrongTableLength)
        XCTAssertEqual(refusal { try makeAvatar(snapshots: [flat(0), [Float](repeating: 0, count: 49)]) }, .wrongTableLength)
        XCTAssertEqual(refusal { try makeAvatar(noise: []) }, .wrongTableLength)
        XCTAssertEqual(refusal { try makeAvatar(snapshots: [[Float]](repeating: flat(0), count: 9)) }, .tooManySnapshots)
        XCTAssertNil(refusal { try makeAvatar(snapshots: [[Float]](repeating: flat(0), count: 8)) })
    }

    func testAnAvatarWithoutALabelIsRefused() throws {
        for label in ["", " ", "   \t ", "\n"] {
            XCTAssertEqual(refusal { try makeAvatar(label: label) }, .emptyLabel, "\"\(label)\"")
        }
        XCTAssertEqual(try makeAvatar(label: "  Echoel, oo to ee \n").label, "Echoel, oo to ee", "kept trimmed")

        // Nor does one come in through an encoding: a stored avatar whose label was emptied is
        // refused, and so is one without a label at all.
        let fields = try jsonObject(of: try makeAvatar().encoded())
        XCTAssertEqual(refusal { try VoiceAvatar(encoded: try edited(fields, "label", "  ")) }, .emptyLabel)
        XCTAssertEqual(refusal { try VoiceAvatar(encoded: try edited(fields, "label", nil)) }, .unreadable)
    }

    func testALabelIsCappedInCharactersAndInBytes() throws {
        XCTAssertEqual(VoiceAvatar.maximumLabelLength, 128)
        XCTAssertEqual(VoiceAvatar.maximumLabelBytes, 512)
        XCTAssertEqual(try makeAvatar(label: String(repeating: "a", count: 128)).label.count, 128)
        XCTAssertEqual(refusal { try makeAvatar(label: String(repeating: "a", count: 129)) }, .labelTooLong)

        // 128 characters of one scalar each always fit: four bytes each at most, 512 in all.
        let faces = String(repeating: "\u{1F600}", count: 128)
        XCTAssertEqual(faces.utf8.count, 512)
        XCTAssertEqual(Array(try makeAvatar(label: faces).label.utf8), Array(faces.utf8))

        // A character made of several scalars counts all of its bytes, so the bytes hold where the
        // characters cannot: one letter carrying 2 000 marks is one character of 4 001 bytes, and 128
        // families of four are 128 characters of 3 200 bytes.
        let marked = "a" + String(repeating: "\u{301}", count: 2_000)
        XCTAssertEqual(marked.count, 1)
        XCTAssertEqual(marked.utf8.count, 4_001)
        XCTAssertEqual(refusal { try makeAvatar(label: marked) }, .labelTooLong)
        let families = String(repeating: "\u{1F468}\u{200D}\u{1F469}\u{200D}\u{1F467}\u{200D}\u{1F466}", count: 128)
        XCTAssertEqual(families.count, 128)
        XCTAssertEqual(families.utf8.count, 3_200)
        XCTAssertEqual(refusal { try makeAvatar(label: families) }, .labelTooLong)

        // At the edge, counted once the spaces at either end are trimmed: 512 bytes fit, 513 do not.
        let edge = "a" + String(repeating: "\u{301}", count: 255) + "b"
        XCTAssertEqual(edge.utf8.count, 512)
        XCTAssertEqual(Array(try makeAvatar(label: "  " + edge + " \n").label.utf8), Array(edge.utf8))
        XCTAssertEqual(refusal { try makeAvatar(label: edge + "c") }, .labelTooLong)

        // A stored avatar is held to the same limits.
        let fields = try jsonObject(of: try makeAvatar().encoded())
        XCTAssertEqual(refusal { try VoiceAvatar(encoded: try edited(fields, "label", marked)) }, .labelTooLong)
        XCTAssertEqual(refusal { try VoiceAvatar(encoded: try edited(fields, "label", edge + "c")) }, .labelTooLong)
        XCTAssertNil(refusal { try VoiceAvatar(encoded: try edited(fields, "label", edge)) })
    }

    func testCharacterMorphsBetweenNeighbouringSnapshotsFromDarkToBright() throws {
        let dark = tilt(-1), middle = flat(0), bright = tilt(1)
        XCTAssertLessThan(VoiceAvatar.brightness(of: dark), 0.2)
        XCTAssertEqual(VoiceAvatar.brightness(of: middle), 0.5)
        XCTAssertGreaterThan(VoiceAvatar.brightness(of: bright), 0.8)

        let avatar = try makeAvatar(snapshots: [bright, dark, middle])
        XCTAssertEqual(avatar.snapshots, [dark, middle, bright], "ordered dark to bright, whatever order they came in")
        XCTAssertEqual(avatar.envelope(character: 0), dark)
        XCTAssertEqual(avatar.envelope(character: 0.5), middle)
        XCTAssertEqual(avatar.envelope(character: 1), bright)
        let quarter = avatar.envelope(character: 0.25), threeQuarters = avatar.envelope(character: 0.75)
        for band in 0..<48 {
            XCTAssertEqual(quarter[band], (dark[band] + middle[band]) / 2, accuracy: 1e-5, "band \(band)")
            XCTAssertEqual(threeQuarters[band], (middle[band] + bright[band]) / 2, accuracy: 1e-5, "band \(band)")
        }

        // Brighter at every step along the axis, and the level at a frequency follows the same morph.
        var last: Float = -1
        for step in 0...10 {
            let now = VoiceAvatar.brightness(of: avatar.envelope(character: Float(step) / 10))
            XCTAssertGreaterThan(now, last, "step \(step)")
            last = now
        }
        for hertz: Float in [60, 500, 3_000, 12_000] {
            XCTAssertEqual(avatar.level(at: hertz, character: 0.25).bitPattern, read(quarter, at: hertz).bitPattern)
        }

        // One snapshot plays at every character. Two as bright as each other keep the order they came in.
        let single = try makeAvatar(snapshots: [bright])
        XCTAssertEqual(single.envelope(character: 0), bright)
        XCTAssertEqual(single.envelope(character: 0.6), bright)
        XCTAssertEqual(try makeAvatar(snapshots: [flat(0), flat(-10)]).snapshots, [flat(0), flat(-10)])
        XCTAssertEqual(try makeAvatar(snapshots: [flat(-10), flat(0)]).snapshots, [flat(-10), flat(0)])

        // No snapshot is an avatar of noise only: silent where it would be voiced.
        let breathOnly = try makeAvatar(snapshots: [], breath: 1, pitchRange: nil)
        XCTAssertEqual(breathOnly.envelope(character: 0.5), flat(VoiceAvatar.floorDecibels))
        XCTAssertEqual(breathOnly.level(at: 440, character: 0.5), VoiceAvatar.floorDecibels)
        XCTAssertEqual(breathOnly.noiseLevel(at: 440), -40)
    }

    func testTheEnvelopeReadsIntoABufferTheCallerOwns() throws {
        let avatar = try makeAvatar()

        // A buffer of exactly `bandCount` places, the size a render path sets aside, takes the
        // envelope and the noise whole.
        let exact = UnsafeMutableBufferPointer<Float>.allocate(capacity: VoiceAvatar.bandCount)
        defer { exact.deallocate() }
        exact.initialize(repeating: 99)
        XCTAssertTrue(avatar.readEnvelope(character: 0.3, into: exact))
        XCTAssertEqual(Array(exact), avatar.envelope(character: 0.3))
        XCTAssertTrue(avatar.readNoise(into: exact))
        XCTAssertEqual(Array(exact), avatar.noise)

        // A longer one takes them in its first `bandCount` places and leaves the rest alone.
        let buffer = UnsafeMutableBufferPointer<Float>.allocate(capacity: 64)
        defer { buffer.deallocate() }
        buffer.initialize(repeating: 99)

        XCTAssertTrue(avatar.readEnvelope(character: 0.3, into: buffer))
        XCTAssertEqual(Array(buffer.prefix(48)), avatar.envelope(character: 0.3))
        XCTAssertEqual(Array(buffer.suffix(16)), [Float](repeating: 99, count: 16), "past the grid the buffer is left alone")
        XCTAssertTrue(avatar.readNoise(into: buffer))
        XCTAssertEqual(Array(buffer.prefix(48)), avatar.noise)
        XCTAssertTrue(avatar.readEnvelope(character: 0.3, into: buffer))
        XCTAssertEqual(Array(buffer.prefix(48)), avatar.envelope(character: 0.3), "nothing is kept between two reads")

        // What a render path reads from that buffer is the level the avatar gives.
        XCTAssertTrue(avatar.readEnvelope(character: 0.8, into: buffer))
        for hertz: Float in [70, 700, 7_000] {
            XCTAssertEqual(VoiceAvatar.level(at: hertz, in: UnsafeBufferPointer(buffer)).bitPattern,
                           avatar.level(at: hertz, character: 0.8).bitPattern, "\(hertz) Hz")
        }

        // A buffer too short for the grid is refused and left as it was.
        let short = UnsafeMutableBufferPointer<Float>.allocate(capacity: 47)
        defer { short.deallocate() }
        short.initialize(repeating: 7)
        XCTAssertFalse(avatar.readEnvelope(character: 0.5, into: short))
        XCTAssertFalse(avatar.readNoise(into: short))
        XCTAssertTrue(short.allSatisfy { $0 == 7 })
    }

    func testAnEncodingFromANewerVersionOrOfTheWrongShapeIsRefusedWhole() throws {
        let fields = try jsonObject(of: try makeAvatar().encoded())
        let table = try XCTUnwrap(fields["noise"] as? String)
        XCTAssertNotNil(try? VoiceAvatar(encoded: try edited(fields, "label", "Edited")), "the shape itself reads")

        XCTAssertEqual(refusal { try VoiceAvatar(encoded: try edited(fields, "version", 2)) }, .newerVersion(2))
        XCTAssertEqual(refusal { try VoiceAvatar(encoded: try edited(fields, "version", 0)) }, .unreadable)
        XCTAssertEqual(refusal { try VoiceAvatar(encoded: try edited(fields, "version", nil)) }, .unreadable)
        XCTAssertEqual(refusal { try VoiceAvatar(encoded: try edited(fields, "origin", "someoneElse")) }, .unreadable)
        let short = Data(repeating: 0, count: 47 * 4).base64EncodedString()
        XCTAssertEqual(refusal { try VoiceAvatar(encoded: try edited(fields, "noise", short)) }, .wrongTableLength)
        XCTAssertEqual(refusal { try VoiceAvatar(encoded: try edited(fields, "snapshots", [table, short])) }, .wrongTableLength)
        XCTAssertEqual(refusal { try VoiceAvatar(encoded: try edited(fields, "noise", "not base64!")) }, .unreadable)
        XCTAssertEqual(refusal { try VoiceAvatar(encoded: try edited(fields, "snapshots", [String](repeating: table, count: 9))) },
                       .tooManySnapshots)
        XCTAssertEqual(refusal { try VoiceAvatar(encoded: Data("not an avatar".utf8)) }, .unreadable)
        XCTAssertEqual(refusal { try VoiceAvatar(encoded: Data()) }, .unreadable)
        XCTAssertEqual(refusal { try VoiceAvatar(encoded: Data("[]".utf8)) }, .unreadable)
    }

    func testTheStoredNamesAndTheTableLayoutAreFrozen() throws {
        XCTAssertEqual(VoiceAvatar.formatVersion, 1)
        XCTAssertEqual(VoiceAvatar.Origin.allCases.map(\.rawValue), ["factory", "ownVoice", "sound"])
        let full = try makeAvatar(vibrato: VoiceAvatar.Vibrato(rate: 5.5, depth: 30))
        let fields = try jsonObject(of: try full.encoded())
        XCTAssertEqual(Set(fields.keys), ["breath", "label", "noise", "origin", "pitchRange", "snapshots", "version", "vibrato"])
        XCTAssertEqual(Set(try XCTUnwrap(fields["pitchRange"] as? [String: Any]).keys), ["lowest", "highest"])
        XCTAssertEqual(Set(try XCTUnwrap(fields["vibrato"] as? [String: Any]).keys), ["rate", "depth"])
        let breathOnly = try jsonObject(of: try makeAvatar(snapshots: [], pitchRange: nil).encoded())
        XCTAssertNil(breathOnly["pitchRange"], "absent, never null")
        XCTAssertNil(breathOnly["vibrato"])

        // Version 1 written by hand: a table is its 48 levels as little-endian 32-bit floats in
        // base64. Here band 0 holds 1 dB, band 47 −120 dB and every other band 0 dB.
        let table = "AACAPwAA" + String(repeating: "A", count: 244) + "APDC"
        let golden = #"{"breath":0.25,"label":"Golden","noise":"\#(table)","origin":"factory","#
            + #""pitchRange":{"highest":440,"lowest":110},"snapshots":["\#(table)"],"version":1,"#
            + #""vibrato":{"depth":30,"rate":5.5}}"#
        let avatar = try VoiceAvatar(encoded: Data(golden.utf8))
        var expected = flat(0)
        expected[0] = 1
        expected[47] = -120
        XCTAssertEqual(avatar.snapshots, [expected])
        XCTAssertEqual(avatar.noise, expected)
        XCTAssertEqual(avatar.label, "Golden")
        XCTAssertEqual(avatar.origin, .factory)
        XCTAssertEqual(avatar.breath, 0.25)
        XCTAssertEqual(avatar.pitchRange?.lowerBound, 110)
        XCTAssertEqual(avatar.pitchRange?.upperBound, 440)
        XCTAssertEqual(avatar.vibrato?.rate, 5.5)
        XCTAssertEqual(avatar.vibrato?.depth, 30)
        XCTAssertEqual(try jsonObject(of: try avatar.encoded())["noise"] as? String, table, "and written the same way")
    }

    /// Data far larger than any avatar is refused before it is parsed.
    func testOversizedDataIsRefusedUnread() {
        let oversized = Data(repeating: UInt8(ascii: " "), count: VoiceAvatar.maximumEncodedBytes + 1)
        XCTAssertThrowsError(try VoiceAvatar(encoded: oversized)) { (error: any Error) in
            XCTAssertEqual(error as? VoiceAvatar.Refusal, .unreadable)
        }
    }
}
