import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
import XCTest
@testable import EchoelCore

/// The metadata of an ADM BWF: an `axml` that parses and whose every reference names something it
/// defines, a `chna` that names the same UIDs, formats and packs channel for channel, and object
/// positions that are the pans ADM-OSC sends.
final class ADMBWFTests: XCTestCase {
    private func layout(bed: Bool = true, names: [String] = ["Keys", "A <B> & \"C\""],
                        blocks: [[ADMBWF.Block]]? = nil) -> ADMBWF.Layout {
        let objects = names.enumerated().map { index, name in
            ADMBWF.Object(name: name, blocks: blocks?[index]
                          ?? [ADMBWF.Block(start: 0, duration: 1_000_000, azimuth: Float(index) * 10)])
        }
        return ADMBWF.Layout(title: "Song", hasBed: bed, objects: objects, sampleRate: 48_000, duration: 1_000_000)
    }

    func testTheAxmlParsesAndEveryReferenceIsDefined() throws {
        let parsed = try ADMElements(ADMBWF.axml(layout()))
        // Every …IDRef and every audioTrackUIDRef names an element defined in the same document.
        XCTAssertFalse(parsed.references.isEmpty)
        for (kind, id) in parsed.references {
            XCTAssertTrue(parsed.defined.contains(id), "\(kind) \(id) is defined")
        }
        // IDs are unique.
        XCTAssertEqual(parsed.definedList.count, Set(parsed.definedList).count)
        XCTAssertEqual(parsed.count("audioObject"), 3, "the bed and two objects")
        XCTAssertEqual(parsed.count("audioTrackUID"), 4)
        XCTAssertEqual(parsed.names.first, "ebuCoreMain")
        XCTAssertTrue(parsed.objectNames.contains("A <B> & \"C\""), "a name survives escaping")
    }

    func testTheChnaNamesEveryChannelAsTheAxmlDoes() throws {
        let value = layout()
        let chna = ADMBWF.chna(value)
        XCTAssertEqual(chna.count, 4 + 40 * 4)
        let bytes = [UInt8](chna)
        XCTAssertEqual(Int(bytes[0]) | Int(bytes[1]) << 8, 4, "tracks")
        XCTAssertEqual(Int(bytes[2]) | Int(bytes[3]) << 8, 4, "UIDs")
        let parsed = try ADMElements(ADMBWF.axml(value))
        for row in 0..<4 {
            let base = 4 + row * 40
            XCTAssertEqual(Int(bytes[base]) | Int(bytes[base + 1]) << 8, row + 1)
            let text = { (from: Int, count: Int) in
                String(decoding: Array(bytes[(base + from)..<(base + from + count)]).filter { $0 != 0 }, as: UTF8.self)
            }
            let uid = text(2, 12), track = text(14, 14), pack = text(28, 11)
            XCTAssertEqual(bytes[base + 39], 0)
            XCTAssertTrue(parsed.defined.contains(uid), uid)
            XCTAssertTrue(parsed.defined.contains(track), track)
            XCTAssertTrue(parsed.defined.contains(pack), pack)
            XCTAssertEqual(parsed.trackUIDs[uid]?.track, track, "the axml ties the same UID to the same track format")
            XCTAssertEqual(parsed.trackUIDs[uid]?.pack, pack)
        }
    }

    func testWithoutABedTheObjectsStartAtChannelOne() throws {
        let value = layout(bed: false, names: ["Only"])
        XCTAssertEqual(value.channelCount, 1)
        XCTAssertEqual(value.channel(ofObject: 0), 1)
        let parsed = try ADMElements(ADMBWF.axml(value))
        XCTAssertEqual(parsed.count("audioObject"), 1)
        XCTAssertEqual(parsed.count("audioPackFormat"), 1)
        for (kind, id) in parsed.references { XCTAssertTrue(parsed.defined.contains(id), "\(kind) \(id)") }
    }

    func testTheAzimuthIsThePanADMOSCSends() {
        for pan in [-1.0, -0.5, 0, 0.3, 1] {
            XCTAssertEqual(ADMBWF.azimuth(pan: pan), ADMObject.track(index: 1, pan: pan, level: 1).azimuth)
        }
        XCTAssertEqual(ADMBWF.azimuth(pan: -1), 90, "hard left is +90°")
        let blocks = ADMBWF.blocks(pan: 0.5, lane: nil, tempoMap: TempoMap(bpm: 120), duration: 500_000)
        XCTAssertEqual(blocks, [ADMBWF.Block(start: 0, duration: 500_000, azimuth: -45)])
    }

    func testAutomatedPanWritesContiguousBlocksThatFollowTheLane() {
        let map = TempoMap(bpm: 120)
        // 120 bpm: one bar of four quarters is two seconds. Left to right across the first bar, then held.
        let bar = Tick(MusicalTime.ticksPerQuarter * 4)
        let lane = AutomationLane(target: .pan(TrackID()), points: [AutomationPoint(tick: 0, value: -1),
                                                                    AutomationPoint(tick: bar, value: 1)])
        let total: Int64 = 400_000
        let blocks = ADMBWF.blocks(pan: 0, lane: lane, tempoMap: map, duration: total)
        XCTAssertGreaterThan(blocks.count, 1)
        XCTAssertTrue(blocks[0].jumps)
        XCTAssertEqual(blocks[0].azimuth, 90)
        XCTAssertEqual(blocks.first?.start, 0)
        for (a, b) in zip(blocks, blocks.dropFirst()) { XCTAssertEqual(a.start + a.duration, b.start, "contiguous") }
        XCTAssertEqual((blocks.last?.start ?? 0) + (blocks.last?.duration ?? 0), total)
        // A straight ramp needs one line: the start, the ramp, the hold.
        XCTAssertLessThanOrEqual(blocks.count, 4)
        // Where each block ends, its azimuth is the lane's.
        for block in blocks.dropFirst() {
            let seconds = Double(block.start + block.duration) / Double(ADMBWF.unitsPerSecond)
            let pan = lane.value(atPosition: map.position(atSeconds: seconds)) ?? 0
            XCTAssertEqual(block.azimuth, ADMBWF.azimuth(pan: pan), accuracy: 0.01)
        }
        XCTAssertEqual(blocks.last?.azimuth, -90)
        // A curved lane takes more blocks than a straight one, and stays within the tolerance.
        let curved = AutomationLane(target: lane.target, points: [AutomationPoint(tick: 0, value: -1, curve: 0.8),
                                                                  AutomationPoint(tick: bar, value: 1)])
        let bent = ADMBWF.blocks(pan: 0, lane: curved, tempoMap: map, duration: total)
        XCTAssertGreaterThan(bent.count, blocks.count)
        let xml = ADMBWF.xml(layout(bed: false, names: ["Moving"], blocks: [bent]))
        XCTAssertTrue(xml.contains("<jumpPosition interpolationLength=\"0\">1</jumpPosition>"))
    }

    func testTheTimeFormatHasFiveDecimals() {
        XCTAssertEqual(ADMBWF.timecode(0), "00:00:00.00000")
        XCTAssertEqual(ADMBWF.timecode(366_123_456), "01:01:01.23456")
        XCTAssertEqual(ADMBWF.duration(frames: 48_000, sampleRate: 48_000), 100_000)
        XCTAssertEqual(ADMBWF.decimal(-45), "-45.0")
        XCTAssertEqual(ADMBWF.decimal(12.3456), "12.346")
    }

    func testTheSameLayoutWritesTheSameBytes() {
        XCTAssertEqual(ADMBWF.axml(layout()), ADMBWF.axml(layout()))
        XCTAssertEqual(ADMBWF.chna(layout()), ADMBWF.chna(layout()))
    }
}

/// What an `axml` document defines and references, read by `XMLParser`.
struct ADMElements {
    var names: [String] = []
    var definedList: [String] = []
    var references: [(String, String)] = []
    var trackUIDs: [String: (track: String, pack: String)] = [:]
    var objectNames: [String] = []
    var defined: Set<String> { Set(definedList) }

    func count(_ name: String) -> Int { names.filter { $0 == name }.count }

    init(_ data: Data) throws {
        let collector = ADMCollector()
        let parser = XMLParser(data: data)
        parser.delegate = collector
        guard parser.parse() else { throw collector.error ?? CocoaError(.fileReadCorruptFile) }
        names = collector.names
        definedList = collector.defined
        references = collector.references
        trackUIDs = collector.trackUIDs
        objectNames = collector.objectNames
    }
}

private final class ADMCollector: NSObject, XMLParserDelegate {
    var names: [String] = []
    var defined: [String] = []
    var references: [(String, String)] = []
    var trackUIDs: [String: (track: String, pack: String)] = [:]
    var objectNames: [String] = []
    var error: Error?
    private var text = ""
    private var currentUID: String?

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        names.append(elementName)
        text = ""
        for (key, value) in attributeDict where key.hasSuffix("ID") || key == "UID" {
            if key != "audioBlockFormatID" { defined.append(value) }
        }
        if elementName == "audioTrackUID" { currentUID = attributeDict["UID"] }
        if elementName == "audioObject", let name = attributeDict["audioObjectName"] { objectNames.append(name) }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if elementName.hasSuffix("IDRef") || elementName == "audioTrackUIDRef" {
            references.append((elementName, value))
            if let uid = currentUID {
                var row = trackUIDs[uid] ?? (track: "", pack: "")
                if elementName == "audioTrackFormatIDRef" { row.track = value }
                if elementName == "audioPackFormatIDRef" { row.pack = value }
                trackUIDs[uid] = row
            }
        }
        if elementName == "audioTrackUID" { currentUID = nil }
        text = ""
    }

    func parser(_ parser: XMLParser, parseErrorOccurred parseError: Error) { error = parseError }
}
