import Foundation

/// A voice avatar: the colour of a voice or of a sound, measured from it and never recorded. It
/// keeps numbers on a fixed grid of bands and never audio — no samples, no phases, nothing that runs
/// in time — so nothing in it can play back what it was measured from. Measure only your own voice,
/// or a sound you may use; never another person's voice.
///
/// Every table lies on one grid: `bandCount` bands, log-spaced from `lowestHertz` to `highestHertz`,
/// their centres computed by `centre(ofBand:)`. An avatar holds
/// - up to `maximumSnapshots` snapshots of the voiced spectral envelope, in decibels, ordered from
///   dark to bright (`brightness(of:)`). They are the Character axis: Character 0 is the darkest,
///   1 the brightest, and between two neighbours every band moves in a straight line in decibels
///   (`envelope(character:)`). An avatar without a snapshot is noise only: nothing voiced was measured;
/// - the noise envelope, in decibels: the breath and the consonants;
/// - how much of the sound is breath rather than tone, the fundamentals it was measured at and its
///   vibrato, if it sang with one;
/// - a label, never empty, and where it came from (`Origin`), so an avatar can always say what it is.
///
/// The envelope is kept in hertz, not per harmonic, so an avatar keeps its vowel on every note it
/// plays: a timbre kept per harmonic number moves its formants with the pitch. Levels are relative;
/// the learner puts the loudest band of a table at 0 dB.
///
/// Every avatar that exists is whole: `init` refuses a table of the wrong length and replaces a level
/// that is not finite, or that no measurement can give, with the floor. Making an avatar, ordering
/// its snapshots and encoding it allocate, so they belong off the render thread. Reading a level from
/// a table (`level(at:in:)`) and reading the envelope or the noise into a buffer the caller owns
/// (`readEnvelope(character:into:)`, `readNoise(into:)`) allocate nothing: a render path reads the
/// buffer an avatar was copied into.
public struct VoiceAvatar: Equatable, Sendable {
    // MARK: The grid

    /// Bands in every table.
    public static let bandCount = 48
    /// The centre of the first band and of the last, in hertz.
    public static let lowestHertz: Float = 50
    public static let highestHertz: Float = 16_000

    /// How far apart two neighbouring centres are, as a ratio: (16 000 / 50)^(1/47) ≈ 1.1306, about
    /// 2.12 semitones.
    public static var bandRatio: Double {
        Foundation.pow(Double(highestHertz) / Double(lowestHertz), 1 / Double(bandCount - 1))
    }

    /// The centre of band `index`, in hertz: `lowestHertz` · (`highestHertz` / `lowestHertz`)^(index / 47),
    /// so the first is 50 Hz and the last 16 kHz exactly. An index outside the grid reads its nearest
    /// end. Arithmetic only.
    public static func centre(ofBand index: Int) -> Float {
        guard index > 0 else { return lowestHertz }
        guard index < bandCount - 1 else { return highestHertz }
        let span = Double(highestHertz) / Double(lowestHertz)
        return Float(Double(lowestHertz) * Foundation.pow(span, Double(index) / Double(bandCount - 1)))
    }

    /// Every centre, the lowest first. Allocates.
    public static var bandCentres: [Float] {
        (0..<bandCount).map { (index: Int) -> Float in centre(ofBand: index) }
    }

    // MARK: What a table may hold

    /// The quietest level a table holds, in decibels. A quieter level is stored as the floor, and so
    /// is one that is not finite or lies above `ceilingDecibels`.
    public static let floorDecibels: Float = -120
    /// The loudest level a table may hold, in decibels. The learner puts the loudest band at 0 dB, so a
    /// level above this one comes from damage, not from a sound, and is stored as the floor.
    public static let ceilingDecibels: Float = 24
    /// The most snapshots an avatar holds.
    public static let maximumSnapshots = 8
    /// The longest label, in characters: the limit a song puts on a name (`Names.maximumLength` in
    /// EchoelCore).
    public static let maximumLabelLength = 128
    /// The longest label in bytes of UTF-8: four for each character, the most one Unicode scalar takes,
    /// so 128 characters of one scalar each always fit, and a character made of several (a letter with
    /// its marks, an emoji sequence) counts all of its bytes. It keeps every avatar small, which the
    /// count of characters cannot: one character can carry any number of combining marks. The same
    /// limit an instrument pack puts on the names it carries (`InstrumentPack` in EchoelCore).
    public static let maximumLabelBytes = 4 * maximumLabelLength
    /// The fundamentals an avatar can say it was measured at, in hertz: from where a pitch can be heard
    /// to the top of the grid, above which no harmonic is left to colour.
    public static let pitchLimits: ClosedRange<Float> = 20 ... 16_000
    /// The encoding this build writes, and the newest it reads (`encoded()`). Changing the grid, a
    /// table's layout or the list of origins is a new version.
    public static let formatVersion = 1

    /// Where an avatar came from. Stored by name: never rename one. A new origin goes at the end and
    /// is a new format version, so an older build refuses the avatar instead of telling the wrong
    /// story about it.
    public enum Origin: String, CaseIterable, Sendable {
        /// One of Echoel's own avatars, shipped as numbers.
        case factory
        /// Measured from the musician's own voice.
        case ownVoice
        /// Measured from a sound the musician may use: an instrument, a synth, a recording of their own.
        case sound
    }

    /// The vibrato a voice sang with: how fast its pitch swings, and how far either way.
    public struct Vibrato: Equatable, Sendable {
        /// Swings per second, in hertz.
        public let rate: Float
        /// How far the pitch swings either way, in cents.
        public let depth: Float

        /// The rates and depths a vibrato can have. Slower or shallower is no vibrato; faster or deeper
        /// is a measurement gone wrong and is held at the top.
        public static let rates: ClosedRange<Float> = 0.1 ... 20
        public static let depths: ClosedRange<Float> = 0.1 ... 600

        /// Nil — no vibrato — for a rate or depth that is not finite or lies below its range.
        public init?(rate: Float, depth: Float) {
            guard rate.isFinite, depth.isFinite, rate >= Self.rates.lowerBound, depth >= Self.depths.lowerBound else {
                return nil
            }
            self.rate = Swift.min(rate, Self.rates.upperBound)
            self.depth = Swift.min(depth, Self.depths.upperBound)
        }
    }

    /// Why an avatar was not made or not read. Nothing is half made: a refused avatar does not exist.
    public enum Refusal: Error, Equatable, Sendable {
        /// The label is empty, or nothing but spaces.
        case emptyLabel
        /// The label is longer than `maximumLabelLength` characters or `maximumLabelBytes` bytes.
        case labelTooLong
        /// A table does not hold `bandCount` levels.
        case wrongTableLength
        /// More than `maximumSnapshots` snapshots.
        case tooManySnapshots
        /// Written by a newer Echoel, in the format version given: refused whole, never half read.
        case newerVersion(Int)
        /// Not an avatar, or one that breaks its own shape.
        case unreadable
    }

    // MARK: The avatar

    /// What the avatar is called wherever it is listed, trimmed of spaces at either end; never empty.
    public let label: String
    /// Where it came from: Echoel's own, the musician's voice, or a sound they may use.
    public let origin: Origin
    /// The voiced envelopes from dark to bright, each `bandCount` levels in decibels. Empty for an
    /// avatar of noise only.
    public let snapshots: [[Float]]
    /// The noise envelope: `bandCount` levels in decibels.
    public let noise: [Float]
    /// How much of the sound is breath rather than tone, 0 … 1.
    public let breath: Float
    /// The lowest and the highest fundamental the avatar was measured at, in hertz; nil when nothing
    /// voiced was measured.
    public let pitchRange: ClosedRange<Float>?
    /// The vibrato it was measured with; nil when it had none.
    public let vibrato: Vibrato?

    /// An avatar from what was measured, checked. The label is trimmed. A level that is not finite,
    /// lies at or below `floorDecibels` or above `ceilingDecibels` is stored as the floor; minus zero
    /// and a subnormal level are stored as zero, so two equal levels are equal bit for bit. The
    /// snapshots are put in order from dark to bright, two as bright as each other in the order they
    /// came. Breath is held to 0 … 1, and one that is not finite is none. The pitch range is put in
    /// order and held to `pitchLimits`; a bound that is not finite leaves no range.
    ///
    /// Refuses a label that is empty, or longer than `maximumLabelLength` characters or
    /// `maximumLabelBytes` bytes once trimmed; a table that does not hold `bandCount` levels; and more
    /// than `maximumSnapshots` snapshots.
    public init(label: String, origin: Origin, snapshots: [[Float]], noise: [Float], breath: Float,
                pitchRange: (lowest: Float, highest: Float)? = nil, vibrato: Vibrato? = nil) throws(Refusal) {
        let trimmed = label.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw .emptyLabel }
        // The bytes first: they bound how far counting the characters has to walk.
        guard trimmed.utf8.count <= Self.maximumLabelBytes, trimmed.count <= Self.maximumLabelLength else {
            throw .labelTooLong
        }
        guard snapshots.count <= Self.maximumSnapshots else { throw .tooManySnapshots }
        guard noise.count == Self.bandCount,
              snapshots.allSatisfy({ (table: [Float]) -> Bool in table.count == Self.bandCount }) else {
            throw .wrongTableLength
        }
        let cleaned = snapshots.map { (table: [Float]) -> [Float] in Self.sanitised(table) }
        let brightnesses = cleaned.map { (table: [Float]) -> Float in Self.brightness(of: table) }
        let order = cleaned.indices.sorted { (first: Int, second: Int) -> Bool in
            brightnesses[first] == brightnesses[second] ? first < second : brightnesses[first] < brightnesses[second]
        }
        self.label = trimmed
        self.origin = origin
        self.snapshots = order.map { (index: Int) -> [Float] in cleaned[index] }
        self.noise = Self.sanitised(noise)
        self.breath = breath.isFinite ? Self.canonical(Swift.min(Swift.max(breath, 0), 1)) : 0
        self.pitchRange = Self.sanitised(pitchRange: pitchRange)
        self.vibrato = vibrato
    }

    // MARK: Reading

    /// The voiced envelope at `character`, `bandCount` levels in decibels: Character 0 is the darkest
    /// snapshot, 1 the brightest, and between two neighbours every band moves in a straight line. A
    /// character outside 0 … 1 is held to it; one that is not finite is the middle, 0.5. The floor
    /// everywhere for an avatar of noise only. Allocates; `readEnvelope(character:into:)` does not.
    public func envelope(character: Float) -> [Float] {
        var levels = [Float](repeating: Self.floorDecibels, count: Self.bandCount)
        _ = levels.withUnsafeMutableBufferPointer { (buffer: inout UnsafeMutableBufferPointer<Float>) -> Bool in
            readEnvelope(character: character, into: buffer)
        }
        return levels
    }

    /// Writes the voiced envelope at `character` — the levels `envelope(character:)` gives — into the
    /// first `bandCount` places of `buffer` and leaves the rest alone. Writes nothing and returns false
    /// when the buffer is shorter than the grid. Allocates nothing.
    public func readEnvelope(character: Float, into buffer: UnsafeMutableBufferPointer<Float>) -> Bool {
        guard buffer.count >= Self.bandCount else { return false }
        guard let morph = morphPosition(character) else {
            for band in 0..<Self.bandCount { buffer[band] = Self.floorDecibels }
            return true
        }
        let darker = snapshots[morph.lower], brighter = snapshots[morph.upper]
        for band in 0..<Self.bandCount {
            buffer[band] = Self.blend(darker[band], brighter[band], morph.t)
        }
        return true
    }

    /// Writes the noise envelope into the first `bandCount` places of `buffer` and leaves the rest
    /// alone; writes nothing and returns false when the buffer is shorter. Allocates nothing.
    public func readNoise(into buffer: UnsafeMutableBufferPointer<Float>) -> Bool {
        guard buffer.count >= Self.bandCount else { return false }
        for band in 0..<Self.bandCount { buffer[band] = noise[band] }
        return true
    }

    /// The voiced level at `hertz` and `character`, in decibels: exactly what `level(at:in:)` reads
    /// from `envelope(character:)`, without making the envelope. Allocates nothing.
    public func level(at hertz: Float, character: Float) -> Float {
        guard let grid = Self.gridPosition(of: hertz), let morph = morphPosition(character) else {
            return Self.floorDecibels
        }
        let darker = snapshots[morph.lower], brighter = snapshots[morph.upper]
        let below = Self.blend(darker[grid.lower], brighter[grid.lower], morph.t)
        let above = Self.blend(darker[grid.upper], brighter[grid.upper], morph.t)
        return Self.blend(below, above, grid.t)
    }

    /// The noise level at `hertz`, in decibels: `level(at:in:)` on the noise envelope.
    public func noiseLevel(at hertz: Float) -> Float {
        noise.withUnsafeBufferPointer { (table: UnsafeBufferPointer<Float>) -> Float in
            Self.level(at: hertz, in: table)
        }
    }

    /// The level at `hertz` in a table on the grid, in decibels: a straight line between the two
    /// nearest band centres on a log-frequency axis; the first band's level at and below its centre,
    /// the last band's at and above its centre. A frequency that is not a number, and a table shorter
    /// than the grid, read as the floor. Arithmetic only, nothing allocates: render-safe.
    public static func level(at hertz: Float, in table: UnsafeBufferPointer<Float>) -> Float {
        guard table.count >= bandCount, let grid = gridPosition(of: hertz) else { return floorDecibels }
        return blend(table[grid.lower], table[grid.upper], grid.t)
    }

    /// How bright a table is, 0 … 1: where its power sits on the grid — the mean band number, each
    /// band weighted by its power, from the first band (0) to the last (1). A table at one level
    /// everywhere is 0.5, and so is a table that is not on the grid. The snapshots are ordered by it.
    public static func brightness(of table: [Float]) -> Float {
        guard table.count == bandCount else { return 0.5 }
        var total = 0.0, weighted = 0.0
        for (band, decibels) in table.enumerated() {
            let power = Foundation.pow(10, Double(sanitised(level: decibels)) / 10)
            total += power
            weighted += Double(band) * power
        }
        guard total > 0 else { return 0.5 }
        return Float(weighted / total / Double(bandCount - 1))
    }

    /// Where `character` falls among the snapshots: the one at or below it, the next one up, and how
    /// far between them, 0 ..< 1 — 0 on a snapshot, so every snapshot reads exactly. Nil for an avatar
    /// of noise only.
    @inline(__always)
    private func morphPosition(_ character: Float) -> (lower: Int, upper: Int, t: Float)? {
        let count = snapshots.count
        guard count > 0 else { return nil }
        let held = character.isFinite ? Swift.min(Swift.max(character, 0), 1) : 0.5
        let position = held * Float(count - 1)
        let lower = Swift.min(Int(position), count - 1)
        return (lower, Swift.min(lower + 1, count - 1), position - Float(lower))
    }

    /// Where `hertz` falls on the grid: the band at or below it, the next one up, and how far between
    /// them on a log-frequency axis, 0 ..< 1. The first band at and below its centre, the last at and
    /// above its centre; nil for a frequency that is not a number.
    @inline(__always)
    static func gridPosition(of hertz: Float) -> (lower: Int, upper: Int, t: Float)? {
        guard !hertz.isNaN else { return nil }
        let last = bandCount - 1
        guard hertz > lowestHertz else { return (0, 0, 0) }
        guard hertz < highestHertz else { return (last, last, 0) }
        let position = log2f(hertz / lowestHertz) / log2f(highestHertz / lowestHertz) * Float(last)
        let lower = Swift.min(Swift.max(Int(position), 0), last)
        let t = Swift.min(Swift.max(position - Float(lower), 0), 1)
        return (lower, Swift.min(lower + 1, last), t)
    }

    /// `a` moved the share `t` of the way to `b`: exactly `a` at 0, and exactly `a` everywhere when
    /// `b` is `a`, so a flat table reads its level at every frequency.
    @inline(__always)
    static func blend(_ a: Float, _ b: Float, _ t: Float) -> Float {
        a + (b - a) * t
    }

    // MARK: Sanitising

    /// A level as a table keeps it: the floor for one that is not finite, lies at or below the floor
    /// or above `ceilingDecibels`; zero for minus zero and a subnormal level.
    static func sanitised(level decibels: Float) -> Float {
        guard decibels.isFinite, decibels > floorDecibels, decibels <= ceilingDecibels else { return floorDecibels }
        return canonical(decibels)
    }

    static func sanitised(_ table: [Float]) -> [Float] {
        table.map { (decibels: Float) -> Float in sanitised(level: decibels) }
    }

    /// Zero for minus zero and for a subnormal value; the value otherwise.
    static func canonical(_ value: Float) -> Float {
        Swift.abs(value) < Float.leastNormalMagnitude ? 0 : value
    }

    /// The pitch range in order and held to `pitchLimits`; nil for none or for a bound that is not finite.
    static func sanitised(pitchRange: (lowest: Float, highest: Float)?) -> ClosedRange<Float>? {
        guard let pitchRange, pitchRange.lowest.isFinite, pitchRange.highest.isFinite else { return nil }
        let a = Swift.min(Swift.max(pitchRange.lowest, pitchLimits.lowerBound), pitchLimits.upperBound)
        let b = Swift.min(Swift.max(pitchRange.highest, pitchLimits.lowerBound), pitchLimits.upperBound)
        return Swift.min(a, b) ... Swift.max(a, b)
    }

    // MARK: Encoding

    /// The avatar as stored: compact JSON with its keys sorted, so the same avatar always gives the same
    /// bytes. About 2.6 KB with eight snapshots and a short label, and under 6 KB whatever the label: a
    /// label holds at most `maximumLabelBytes` bytes, and JSON writes none of them as more than six.
    /// It holds `formatVersion`, the label, the origin by name, breath, the pitch range and the vibrato
    /// when there are any, and every table as its levels in IEEE 754 single precision, little-endian,
    /// in base64: exact by construction, where a decimal number would pass through each reader's own
    /// parsing. The other numbers are written as the doubles that hold them exactly. Off the render
    /// thread.
    public func encoded() throws -> Data {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys, .withoutEscapingSlashes]
        return try encoder.encode(self)
    }

    /// Reads what `encoded()` wrote, in this format version or an older one, through `init`, so every
    /// rule above holds for a stored avatar too. Refuses whole, never half read: data that is not an
    /// avatar, an avatar written by a newer version, and one whose label or tables `init` refuses.
    public init(encoded data: Data) throws(Refusal) {
        do {
            self = try JSONDecoder().decode(VoiceAvatar.self, from: data)
        } catch let refusal as Refusal {
            throw refusal
        } catch {
            throw .unreadable
        }
    }

    /// A table as stored: its levels as IEEE 754 single-precision floats, little-endian, in base64 —
    /// 192 bytes in 256 characters.
    static func encodedTable(_ table: [Float]) -> String {
        var bytes: [UInt8] = []
        bytes.reserveCapacity(table.count * 4)
        for decibels in table {
            let pattern = decibels.bitPattern
            for shift in stride(from: 0, to: 32, by: 8) {
                bytes.append(UInt8(truncatingIfNeeded: pattern >> shift))
            }
        }
        return Data(bytes).base64EncodedString()
    }

    /// The table `encodedTable(_:)` wrote, every level as it was written; `init` checks them. Refuses
    /// text that is not base64 and a table that does not hold `bandCount` levels.
    static func decodedTable(_ text: String) throws(Refusal) -> [Float] {
        guard let data = Data(base64Encoded: text) else { throw .unreadable }
        guard data.count == bandCount * 4 else { throw .wrongTableLength }
        let bytes = [UInt8](data)
        return (0..<bandCount).map { (band: Int) -> Float in
            var pattern: UInt32 = 0
            for byte in 0..<4 { pattern |= UInt32(bytes[band * 4 + byte]) << (8 * byte) }
            return Float(bitPattern: pattern)
        }
    }
}

extension VoiceAvatar: Codable {
    private enum CodingKeys: String, CodingKey {
        case version, label, origin, snapshots, noise, breath, pitchRange, vibrato
    }

    private enum PitchRangeKeys: String, CodingKey {
        case lowest, highest
    }

    private enum VibratoKeys: String, CodingKey {
        case rate, depth
    }

    /// The version comes first: an avatar from a newer build is refused before anything else is read.
    public init(from decoder: Decoder) throws {
        let fields = try decoder.container(keyedBy: CodingKeys.self)
        let version = try fields.decode(Int.self, forKey: .version)
        guard version >= 1 else { throw Refusal.unreadable }
        guard version <= Self.formatVersion else { throw Refusal.newerVersion(version) }
        guard let origin = Origin(rawValue: try fields.decode(String.self, forKey: .origin)) else {
            throw Refusal.unreadable
        }
        let stored = try fields.decode([String].self, forKey: .snapshots)
        guard stored.count <= Self.maximumSnapshots else { throw Refusal.tooManySnapshots }
        var snapshots: [[Float]] = []
        for text in stored { snapshots.append(try Self.decodedTable(text)) }
        var pitchRange: (lowest: Float, highest: Float)?
        if fields.contains(.pitchRange), try !fields.decodeNil(forKey: .pitchRange) {
            let range = try fields.nestedContainer(keyedBy: PitchRangeKeys.self, forKey: .pitchRange)
            pitchRange = (lowest: Float(try range.decode(Double.self, forKey: .lowest)),
                          highest: Float(try range.decode(Double.self, forKey: .highest)))
        }
        var vibrato: Vibrato?
        if fields.contains(.vibrato), try !fields.decodeNil(forKey: .vibrato) {
            let swing = try fields.nestedContainer(keyedBy: VibratoKeys.self, forKey: .vibrato)
            vibrato = Vibrato(rate: Float(try swing.decode(Double.self, forKey: .rate)),
                              depth: Float(try swing.decode(Double.self, forKey: .depth)))
        }
        try self.init(label: try fields.decode(String.self, forKey: .label), origin: origin, snapshots: snapshots,
                      noise: try Self.decodedTable(try fields.decode(String.self, forKey: .noise)),
                      breath: Float(try fields.decode(Double.self, forKey: .breath)),
                      pitchRange: pitchRange, vibrato: vibrato)
    }

    public func encode(to encoder: Encoder) throws {
        var fields = encoder.container(keyedBy: CodingKeys.self)
        try fields.encode(Self.formatVersion, forKey: .version)
        try fields.encode(label, forKey: .label)
        try fields.encode(origin.rawValue, forKey: .origin)
        try fields.encode(snapshots.map { (table: [Float]) -> String in Self.encodedTable(table) }, forKey: .snapshots)
        try fields.encode(Self.encodedTable(noise), forKey: .noise)
        try fields.encode(Double(breath), forKey: .breath)
        if let pitchRange {
            var range = fields.nestedContainer(keyedBy: PitchRangeKeys.self, forKey: .pitchRange)
            try range.encode(Double(pitchRange.lowerBound), forKey: .lowest)
            try range.encode(Double(pitchRange.upperBound), forKey: .highest)
        }
        if let vibrato {
            var swing = fields.nestedContainer(keyedBy: VibratoKeys.self, forKey: .vibrato)
            try swing.encode(Double(vibrato.rate), forKey: .rate)
            try swing.encode(Double(vibrato.depth), forKey: .depth)
        }
    }
}
