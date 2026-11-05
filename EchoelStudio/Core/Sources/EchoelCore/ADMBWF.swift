import Foundation

/// The metadata of an ADM Broadcast Wave file: the Audio Definition Model (ITU-R BS.2076-2) as
/// the `axml` chunk and the table that ties each file channel to it as the `chna` chunk (ITU-R
/// BS.2088-1, EBU Tech 3285 s7). The song exported for an immersive renderer: every track that
/// plays into the master is one audio object on its own channel, placed where ADM-OSC places it
/// (`ADMObject.track`, the pan on the horizontal circle), and the returns — and tracks that do not
/// play into the master — share one stereo bed. Pure description: the samples are the engine's.
///
/// Times are counted in units of 10 µs, the five decimals the ADM time format writes, so every
/// block ends exactly where the next one starts.
public enum ADMBWF {
    /// Time units per second: the ADM time format's five decimals.
    public static let unitsPerSecond: Int64 = 100_000
    /// How often an automated position is looked at: every 20 ms. A move between two looks is
    /// drawn as a straight line — finer than a pan automation lane is ever drawn by hand.
    public static let gridUnits: Int64 = 2_000
    /// A block goes on as long as its straight line stays within this of the automation (degrees).
    public static let toleranceDegrees: Float = 0.5
    /// The longest a moving block's line is checked against the automation (grid steps): a bound
    /// on the work per block, not on the block — a position that holds still runs on.
    static let longestCheckedBlock = 500

    /// One `audioBlockFormat` of an object: where it is from `start` for `duration`. Interpolated
    /// from the previous block's position over the whole block, as BS.2076 reads a block without
    /// a jump; the first block of a moving object jumps.
    public struct Block: Equatable, Sendable {
        public let start: Int64
        public let duration: Int64
        /// Degrees, positive to the left (ADM and ADM-OSC).
        public let azimuth: Float
        public let jumps: Bool

        public init(start: Int64, duration: Int64, azimuth: Float, jumps: Bool = false) {
            self.start = start
            self.duration = duration
            self.azimuth = azimuth
            self.jumps = jumps
        }
    }

    /// One audio object: a track, on one channel of the file.
    public struct Object: Equatable, Sendable {
        public let name: String
        /// In time order, each starting where the one before ends, together the whole file.
        public let blocks: [Block]

        public init(name: String, blocks: [Block]) {
            self.name = name
            self.blocks = blocks
        }
    }

    /// The file's channels: the bed's two first when there is one, then one per object.
    public struct Layout: Equatable, Sendable {
        public let title: String
        public let hasBed: Bool
        public let objects: [Object]
        public let sampleRate: Double
        /// The file's length in time units.
        public let duration: Int64
        public static let bitDepth = 24

        public init(title: String, hasBed: Bool, objects: [Object], sampleRate: Double, duration: Int64) {
            self.title = title
            self.hasBed = hasBed
            self.objects = objects
            self.sampleRate = sampleRate.isFinite && sampleRate > 0 ? sampleRate : 48_000
            self.duration = Swift.max(0, duration)
        }

        public var channelCount: Int { (hasBed ? 2 : 0) + objects.count }

        /// The 1-based file channel of object `index` (0-based).
        public func channel(ofObject index: Int) -> Int { (hasBed ? 2 : 0) + index + 1 }
    }

    /// The time of `frames` frames at `sampleRate`, in time units.
    public static func duration(frames: Int, sampleRate: Double) -> Int64 {
        guard sampleRate.isFinite, sampleRate > 0, frames > 0 else { return 0 }
        let units = (Double(frames) / sampleRate * Double(unitsPerSecond)).rounded()
        return units.isFinite ? Int64(Swift.min(units, Double(Int64.max / 2))) : 0
    }

    /// `hh:mm:ss.zzzzz`, the ADM time format.
    public static func timecode(_ units: Int64) -> String {
        let value = Swift.max(0, units)
        let fraction = value % unitsPerSecond
        let seconds = value / unitsPerSecond
        return pad(seconds / 3600, 2) + ":" + pad(seconds / 60 % 60, 2) + ":" + pad(seconds % 60, 2) + "." + pad(fraction, 5)
    }

    /// The blocks of a track panned `pan` whose pan automation is `lane`, over `duration` units of
    /// a song with `tempoMap`. Without a lane, or with one that never moves, one block for the
    /// whole file; otherwise the automation looked at every `gridUnits`, a block for each stretch
    /// a straight line follows within `toleranceDegrees`.
    public static func blocks(pan: Double, lane: AutomationLane?, tempoMap: TempoMap, duration: Int64) -> [Block] {
        let total = Swift.max(0, duration)
        guard let lane, lane.points.count > 1, total > 1 else {
            let value = lane?.points.first?.value ?? pan
            return [Block(start: 0, duration: total, azimuth: azimuth(pan: value))]
        }
        let seconds = { (units: Int64) -> Double in Double(units) / Double(unitsPerSecond) }
        let at = { (units: Int64) -> Float in
            azimuth(pan: lane.value(atPosition: tempoMap.position(atSeconds: seconds(units))) ?? pan)
        }
        // A first block of one unit holds the start, so the next line leaves from the right place.
        var blocks = [Block(start: 0, duration: 1, azimuth: at(0), jumps: true)]
        var times: [Int64] = [1]
        var values: [Float] = [at(0)]
        var grid = gridUnits
        while grid < total {
            times.append(grid)
            values.append(at(grid))
            grid += gridUnits
        }
        times.append(total)
        values.append(at(total))
        // Greedy: the block from `anchor` grows while every look inside it lies on its line.
        var anchor = 0
        while anchor < times.count - 1 {
            var last = anchor + 1
            var still = values[last] == values[anchor]
            while last + 1 < times.count {
                let candidate = last + 1
                let staysStill = still && values[candidate] == values[anchor]
                guard staysStill || fits(anchor: anchor, end: candidate, times: times, values: values) else { break }
                still = staysStill
                last = candidate
            }
            blocks.append(Block(start: times[anchor], duration: times[last] - times[anchor], azimuth: values[last]))
            anchor = last
        }
        return blocks
    }

    /// Whether the straight line from `anchor` to `end` passes within the tolerance of every look
    /// between them — checked only up to `longestCheckedBlock` steps, so the work per block stays
    /// bounded (a stretch that holds still is extended without this check).
    static func fits(anchor: Int, end: Int, times: [Int64], values: [Float]) -> Bool {
        guard end - anchor <= longestCheckedBlock, end - anchor > 1 else { return end - anchor == 1 }
        let from = values[anchor], to = values[end]
        let span = Double(times[end] - times[anchor])
        guard span > 0 else { return false }
        for index in (anchor + 1)..<end {
            let t = Double(times[index] - times[anchor]) / span
            let line = Double(from) + (Double(to) - Double(from)) * t
            if Swift.abs(line - Double(values[index])) > Double(toleranceDegrees) { return false }
        }
        return true
    }

    /// The azimuth ADM-OSC sends for a track at `pan`.
    public static func azimuth(pan: Double) -> Float {
        ADMObject.track(index: 1, pan: pan, level: 1).azimuth
    }

    // MARK: - Identifiers

    static let bedPack = "AP_00011001"
    static let bedChannels = ["AC_00011001", "AC_00011002"]
    static let bedSpeakers: [(label: String, azimuth: Float, name: String)] = [("M+030", 30, "FrontLeft"),
                                                                                ("M-030", -30, "FrontRight")]

    static func hex(_ value: Int, _ digits: Int) -> String {
        let text = String(value, radix: 16, uppercase: true)
        return String(repeating: "0", count: Swift.max(0, digits - text.count)) + text
    }

    /// The 4-hex-digit number of object `index` (0-based): 1001, 1002, … as BS.2076 numbers
    /// what a file defines itself.
    static func objectNumber(_ index: Int) -> String { hex(0x1001 + index, 4) }

    static func pack(ofObject index: Int) -> String { "AP_0003" + objectNumber(index) }
    static func channelFormat(ofObject index: Int) -> String { "AC_0003" + objectNumber(index) }
    static func trackFormat(ofChannelFormat id: String) -> String { "AT_" + id.dropFirst(3) + "_01" }
    static func streamFormat(ofChannelFormat id: String) -> String { "AS_" + id.dropFirst(3) }
    static func trackUID(_ channel: Int) -> String { "ATU_" + hex(channel, 8) }

    /// Per file channel (1-based, in order): its track UID, track format and pack.
    public static func channelTable(_ layout: Layout) -> [(channel: Int, uid: String, trackFormat: String, pack: String)] {
        var rows: [(channel: Int, uid: String, trackFormat: String, pack: String)] = []
        if layout.hasBed {
            for (offset, channel) in bedChannels.enumerated() {
                rows.append((offset + 1, trackUID(offset + 1), trackFormat(ofChannelFormat: channel), bedPack))
            }
        }
        for index in layout.objects.indices {
            let channel = layout.channel(ofObject: index)
            rows.append((channel, trackUID(channel), trackFormat(ofChannelFormat: channelFormat(ofObject: index)),
                         pack(ofObject: index)))
        }
        return rows
    }

    // MARK: - chna

    /// The `chna` chunk's body: the number of tracks and of UIDs, then per channel its index,
    /// track UID (12 bytes), track format (14) and pack (11), and one byte of padding.
    public static func chna(_ layout: Layout) -> Data {
        let rows = channelTable(layout)
        var out = Data()
        append(UInt16(clamping: layout.channelCount), to: &out)
        append(UInt16(clamping: rows.count), to: &out)
        for row in rows {
            append(UInt16(clamping: row.channel), to: &out)
            out.append(contentsOf: fixed(row.uid, 12))
            out.append(contentsOf: fixed(row.trackFormat, 14))
            out.append(contentsOf: fixed(row.pack, 11))
            out.append(0)
        }
        return out
    }

    static func fixed(_ text: String, _ count: Int) -> [UInt8] {
        let bytes = Array(text.utf8.prefix(count))
        return bytes + [UInt8](repeating: 0, count: count - bytes.count)
    }

    static func append<T: FixedWidthInteger>(_ value: T, to data: inout Data) {
        withUnsafeBytes(of: value.littleEndian) { data.append(contentsOf: $0) }
    }

    // MARK: - axml

    /// The `axml` chunk's body: one programme, one content, the bed and every object, each with its
    /// pack, channel, stream and track formats, and a track UID per file channel — every ID the
    /// file names defined in it, so a reader needs no common definitions.
    public static func axml(_ layout: Layout) -> Data {
        Data(xml(layout).utf8)
    }

    public static func xml(_ layout: Layout) -> String {
        let end = timecode(layout.duration)
        let rate = String(Int(layout.sampleRate.rounded()))
        var x = "<?xml version=\"1.0\" encoding=\"UTF-8\"?>\n"
        x += "<ebuCoreMain xmlns:dc=\"http://purl.org/dc/elements/1.1/\" xmlns=\"urn:ebu:metadata-schema:ebuCore_2016\">\n"
        x += " <coreMetadata>\n  <format>\n   <audioFormatExtended version=\"ITU-R_BS.2076-2\">\n"
        x += "    <audioProgramme audioProgrammeID=\"APR_1001\" audioProgrammeName=\"\(escape(layout.title))\" start=\"00:00:00.00000\" end=\"\(end)\">\n"
        x += "     <audioContentIDRef>ACO_1001</audioContentIDRef>\n    </audioProgramme>\n"
        x += "    <audioContent audioContentID=\"ACO_1001\" audioContentName=\"\(escape(layout.title))\">\n"
        let objectIDs = (layout.hasBed ? ["AO_1001"] : []) + layout.objects.indices.map { "AO_" + hex(0x1002 + $0, 4) }
        for id in objectIDs { x += "     <audioObjectIDRef>\(id)</audioObjectIDRef>\n" }
        x += "    </audioContent>\n"
        let table = channelTable(layout)
        if layout.hasBed {
            x += "    <audioObject audioObjectID=\"AO_1001\" audioObjectName=\"Bed\" start=\"00:00:00.00000\" duration=\"\(end)\">\n"
            x += "     <audioPackFormatIDRef>\(bedPack)</audioPackFormatIDRef>\n"
            for row in table.prefix(2) { x += "     <audioTrackUIDRef>\(row.uid)</audioTrackUIDRef>\n" }
            x += "    </audioObject>\n"
        }
        for (index, object) in layout.objects.enumerated() {
            let uid = trackUID(layout.channel(ofObject: index))
            x += "    <audioObject audioObjectID=\"\(objectIDs[(layout.hasBed ? 1 : 0) + index])\" audioObjectName=\"\(escape(object.name))\" start=\"00:00:00.00000\" duration=\"\(end)\">\n"
            x += "     <audioPackFormatIDRef>\(pack(ofObject: index))</audioPackFormatIDRef>\n"
            x += "     <audioTrackUIDRef>\(uid)</audioTrackUIDRef>\n    </audioObject>\n"
        }
        if layout.hasBed {
            x += "    <audioPackFormat audioPackFormatID=\"\(bedPack)\" audioPackFormatName=\"Bed\" typeLabel=\"0001\" typeDefinition=\"DirectSpeakers\">\n"
            for channel in bedChannels { x += "     <audioChannelFormatIDRef>\(channel)</audioChannelFormatIDRef>\n" }
            x += "    </audioPackFormat>\n"
        }
        for (index, object) in layout.objects.enumerated() {
            x += "    <audioPackFormat audioPackFormatID=\"\(pack(ofObject: index))\" audioPackFormatName=\"\(escape(object.name))\" typeLabel=\"0003\" typeDefinition=\"Objects\">\n"
            x += "     <audioChannelFormatIDRef>\(channelFormat(ofObject: index))</audioChannelFormatIDRef>\n    </audioPackFormat>\n"
        }
        if layout.hasBed {
            for (channel, speaker) in zip(bedChannels, bedSpeakers) {
                x += "    <audioChannelFormat audioChannelFormatID=\"\(channel)\" audioChannelFormatName=\"\(speaker.name)\" typeLabel=\"0001\" typeDefinition=\"DirectSpeakers\">\n"
                x += "     <audioBlockFormat audioBlockFormatID=\"AB_\(channel.dropFirst(3))_00000001\">\n"
                x += "      <speakerLabel>\(speaker.label)</speakerLabel>\n"
                x += position(azimuth: speaker.azimuth, indent: "      ")
                x += "     </audioBlockFormat>\n    </audioChannelFormat>\n"
            }
        }
        for (index, object) in layout.objects.enumerated() {
            let channel = channelFormat(ofObject: index)
            x += "    <audioChannelFormat audioChannelFormatID=\"\(channel)\" audioChannelFormatName=\"\(escape(object.name))\" typeLabel=\"0003\" typeDefinition=\"Objects\">\n"
            for (number, block) in object.blocks.enumerated() {
                x += "     <audioBlockFormat audioBlockFormatID=\"AB_\(channel.dropFirst(3))_\(hex(number + 1, 8))\" rtime=\"\(timecode(block.start))\" duration=\"\(timecode(block.duration))\">\n"
                if block.jumps { x += "      <jumpPosition interpolationLength=\"0\">1</jumpPosition>\n" }
                x += position(azimuth: block.azimuth, indent: "      ")
                x += "     </audioBlockFormat>\n"
            }
            x += "    </audioChannelFormat>\n"
        }
        let channels = (layout.hasBed ? bedChannels : []) + layout.objects.indices.map(channelFormat(ofObject:))
        let names = (layout.hasBed ? bedSpeakers.map(\.name) : []) + layout.objects.map(\.name)
        for (channel, name) in zip(channels, names) {
            x += "    <audioStreamFormat audioStreamFormatID=\"\(streamFormat(ofChannelFormat: channel))\" audioStreamFormatName=\"PCM_\(escape(name))\" formatLabel=\"0001\" formatDefinition=\"PCM\">\n"
            x += "     <audioChannelFormatIDRef>\(channel)</audioChannelFormatIDRef>\n"
            x += "     <audioTrackFormatIDRef>\(trackFormat(ofChannelFormat: channel))</audioTrackFormatIDRef>\n    </audioStreamFormat>\n"
        }
        for (channel, name) in zip(channels, names) {
            x += "    <audioTrackFormat audioTrackFormatID=\"\(trackFormat(ofChannelFormat: channel))\" audioTrackFormatName=\"PCM_\(escape(name))\" formatLabel=\"0001\" formatDefinition=\"PCM\">\n"
            x += "     <audioStreamFormatIDRef>\(streamFormat(ofChannelFormat: channel))</audioStreamFormatIDRef>\n    </audioTrackFormat>\n"
        }
        for row in table {
            x += "    <audioTrackUID UID=\"\(row.uid)\" sampleRate=\"\(rate)\" bitDepth=\"\(Layout.bitDepth)\">\n"
            x += "     <audioTrackFormatIDRef>\(row.trackFormat)</audioTrackFormatIDRef>\n"
            x += "     <audioPackFormatIDRef>\(row.pack)</audioPackFormatIDRef>\n    </audioTrackUID>\n"
        }
        x += "   </audioFormatExtended>\n  </format>\n </coreMetadata>\n</ebuCoreMain>\n"
        return x
    }

    static func position(azimuth: Float, indent: String) -> String {
        indent + "<position coordinate=\"azimuth\">\(decimal(azimuth))</position>\n"
            + indent + "<position coordinate=\"elevation\">0.0</position>\n"
            + indent + "<position coordinate=\"distance\">1.0</position>\n"
    }

    /// Degrees with up to three decimals, written the same on every platform.
    static func decimal(_ value: Float) -> String {
        let thousandths = Int((Double(value.isFinite ? value : 0) * 1000).rounded())
        let sign = thousandths < 0 ? "-" : ""
        let magnitude = Swift.abs(thousandths)
        var fraction = pad(Int64(magnitude % 1000), 3)
        while fraction.count > 1, fraction.hasSuffix("0") { fraction.removeLast() }
        return sign + String(magnitude / 1000) + "." + fraction
    }

    static func pad(_ value: Int64, _ digits: Int) -> String {
        let text = String(value)
        return String(repeating: "0", count: Swift.max(0, digits - text.count)) + text
    }

    /// Text for an attribute: the five XML entities escaped, characters XML 1.0 cannot carry left out.
    static func escape(_ text: String) -> String {
        var out = ""
        for scalar in text.unicodeScalars {
            switch scalar {
            case "&": out += "&amp;"
            case "<": out += "&lt;"
            case ">": out += "&gt;"
            case "\"": out += "&quot;"
            case "'": out += "&apos;"
            default:
                let value = scalar.value
                if value == 0x9 || value == 0xA || value == 0xD || (value >= 0x20 && value != 0xFFFE && value != 0xFFFF) {
                    out.unicodeScalars.append(scalar)
                }
            }
        }
        return out
    }
}
