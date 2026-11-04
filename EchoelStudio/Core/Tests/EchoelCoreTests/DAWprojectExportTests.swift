import Foundation
#if canImport(FoundationXML)
import FoundationXML
#endif
import XCTest
@testable import EchoelCore

/// The song as a DAWproject (PRO-W2 slice 2): the way into Bitwig, Studio One, Cubase.
final class DAWprojectExportTests: XCTestCase {
    private let loop = MediaFile(name: "Loop & Co", path: "Media/loop.wav", frameCount: 96_000, sampleRate: 48_000)
    private let quarter = MusicalTime.ticksPerQuarter

    /// 120 BPM in 4/4; a ramp to 60 BPM arriving at bar 3, 3/4 from bar 4. Keys plays a placed clip
    /// with two notes; Drums a loop at bar 1 with fades and a warped loop at bar 2; a reverb return
    /// fed by Drums at −6 dB; a marker at bar 2.
    private func song() throws -> Project {
        var project = Project(name: "Night", tempo: 120)
        let keys = TrackID(), drums = TrackID(), verb = TrackID()
        try Command.addTrack(id: keys, name: "Keys", kind: .instrument, index: nil).apply(to: &project)
        try Command.addTrack(id: drums, name: "Drums", kind: .audio, index: nil).apply(to: &project)
        try Command.addTrack(id: verb, name: "Verb", kind: .returnTrack, index: nil).apply(to: &project)
        try Command.addTrack(id: TrackID(), name: "Video 1", kind: .video, index: nil).apply(to: &project)
        try Command.addMedia(loop).apply(to: &project)
        let clip = ClipID()
        try Command.createClip(track: keys, id: clip, name: "Chords", length: 4 * quarter).apply(to: &project)
        try Command.addNotes(clip, [Note(pitch: 60, velocity: 127, start: 0, length: quarter),
                                    Note(pitch: 64, velocity: 64, start: quarter, length: 8 * quarter)]).apply(to: &project)
        try Command.placeClip(track: keys, id: PlacementID(), clip: clip, start: 0).apply(to: &project)
        let plain = RegionID(), warped = RegionID()
        try Command.placeAudio(track: drums, id: plain, media: loop.id, start: 0).apply(to: &project)
        try Command.setRegionFades(track: drums, plain, fadeIn: 24_000, fadeOut: 0, fadeInCurve: .linear,
                                   fadeOutCurve: .linear).apply(to: &project)
        try Command.placeAudio(track: drums, id: warped, media: loop.id, start: 4 * quarter).apply(to: &project)
        try Command.setRegionWarp(track: drums, warped, nativeBPM: 60, followsTempo: true).apply(to: &project)
        try Command.setSend(track: drums, to: verb, db: -6).apply(to: &project)
        try Command.setTempoChange(at: 8 * quarter, bpm: 60).apply(to: &project)
        try Command.setTempoCurve(at: 8 * quarter, curve: .linear).apply(to: &project)
        try Command.setTimeSignatureChange(at: 12 * quarter, TimeSignature(3, 4)).apply(to: &project)
        try Command.addMarker(at: 4 * quarter, name: "Drop").apply(to: &project)
        return project
    }

    private func xml() throws -> String {
        let project = try song()
        let paths = ExportMedia.names(for: project, using: ExportMedia.arrangementMedia(of: project),
                                      folder: DAWprojectExport.mediaFolder)
        return DAWprojectExport.projectXML(for: project, mediaPaths: paths, channels: [loop.id: 1])
    }

    func testTheProjectIsTheGoldenXML() throws {
        // Times inside a tempo ramp go through `log1p`/`expm1`, whose last bit differs between the
        // C libraries of macOS and Linux; the golden is compared with every number at 12 places.
        XCTAssertEqual(Self.rounded(try xml()), Self.rounded(Self.golden))
        XCTAssertNotEqual(Self.rounded("x=\"1.0000000004\""), Self.rounded("x=\"1.0000000001\""), "a real difference still shows")
    }

    /// `text` with every quoted decimal number written with 12 places after the point.
    private static func rounded(_ text: String) -> String {
        var out = ""
        for (index, piece) in text.components(separatedBy: "\"").enumerated() {
            if index > 0 { out += "\"" }
            if index % 2 == 1, piece.contains("."), let value = Double(piece) {
                out += String(format: "%.12f", value)
            } else {
                out += piece
            }
        }
        return out
    }

    func testItParsesAsXMLWithTheElementsTheFormatNames() throws {
        let text = try xml()
        let parser = XMLParser(data: Data(text.utf8))
        let collector = ElementCollector()
        parser.delegate = collector
        XCTAssertTrue(parser.parse(), "well-formed")
        XCTAssertEqual(collector.names.first, "Project")
        XCTAssertEqual(collector.count("Track"), 4, "keys, drums, the return and the master — no video")
        XCTAssertEqual(collector.count("Note"), 2)
        XCTAssertEqual(collector.count("Audio"), 2)
        XCTAssertEqual(collector.count("Send"), 1)
        XCTAssertEqual(collector.count("RealPoint"), 2)
        XCTAssertEqual(collector.count("TimeSignaturePoint"), 2)
        XCTAssertTrue(text.contains("name=\"Loop &amp; Co\""), "escaped")
    }

    func testAStretchAtTheFileSpeedFollowsTheRampWithWarpPoints() throws {
        let project = try song()
        // The ramp runs from the start to beat 8: a point at each quarter inside it, the change, the end.
        let ticks = DAWprojectExport.clockPoints(from: 0, to: 12 * quarter, map: project.tempoMap)
        XCTAssertEqual(ticks, [0, 1, 2, 3, 4, 5, 6, 7, 8, 12].map { $0 * quarter })
        let flat = DAWprojectExport.clockPoints(from: quarter, to: 3 * quarter, map: TempoMap(bpm: 100))
        XCTAssertEqual(flat, [quarter, 3 * quarter])
    }

    func testTheMetadataNamesTheSong() {
        XCTAssertEqual(DAWprojectExport.metadataXML(title: "A <B>"),
                       "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n<MetaData>\n  <Title>A &lt;B&gt;</Title>\n</MetaData>\n")
    }
}

private final class ElementCollector: NSObject, XMLParserDelegate {
    var names: [String] = []
    func count(_ name: String) -> Int { names.filter { $0 == name }.count }
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        names.append(elementName)
    }
}

extension DAWprojectExportTests {
    /// Valid against the published `Project.xsd` of github.com/bitwig/dawproject (`xmllint --schema`,
    /// 2026-11-04).
    static let golden = """
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <Project version="1.0">
      <Application name="Echoel Studio" version="11.0.0"/>
      <Transport>
        <Tempo max="999" min="20" unit="bpm" value="120.0" id="tempo" name="Tempo"/>
        <TimeSignature denominator="4" numerator="4" id="signature"/>
      </Transport>
      <Structure>
        <Track contentType="notes" loaded="true" id="track1" name="Keys">
          <Channel audioChannels="2" destination="channel4" role="regular" solo="false" id="channel1">
            <Mute value="false" id="mute1"/>
            <Pan max="1.0" min="0.0" unit="normalized" value="0.5" id="pan1" name="Pan"/>
            <Volume max="2.0" min="0.0" unit="linear" value="1.0" id="volume1" name="Volume"/>
          </Channel>
        </Track>
        <Track contentType="audio" loaded="true" id="track2" name="Drums">
          <Channel audioChannels="2" destination="channel4" role="regular" solo="false" id="channel2">
            <Mute value="false" id="mute2"/>
            <Pan max="1.0" min="0.0" unit="normalized" value="0.5" id="pan2" name="Pan"/>
            <Sends>
              <Send destination="channel3" type="post" id="send1">
                <Volume max="2.0" min="0.0" unit="linear" value="0.5011872336272722" id="volume2" name="Volume"/>
              </Send>
            </Sends>
            <Volume max="2.0" min="0.0" unit="linear" value="1.0" id="volume3" name="Volume"/>
          </Channel>
        </Track>
        <Track contentType="audio" loaded="true" id="track3" name="Verb">
          <Channel audioChannels="2" destination="channel4" role="effect" solo="false" id="channel3">
            <Mute value="false" id="mute3"/>
            <Pan max="1.0" min="0.0" unit="normalized" value="0.5" id="pan3" name="Pan"/>
            <Volume max="2.0" min="0.0" unit="linear" value="1.0" id="volume4" name="Volume"/>
          </Channel>
        </Track>
        <Track contentType="audio notes" loaded="true" id="track4" name="Master">
          <Channel audioChannels="2" role="master" solo="false" id="channel4">
            <Mute value="false" id="mute4"/>
            <Pan max="1.0" min="0.0" unit="normalized" value="0.5" id="pan4" name="Pan"/>
            <Volume max="2.0" min="0.0" unit="linear" value="1.0" id="volume5" name="Volume"/>
          </Channel>
        </Track>
      </Structure>
      <Arrangement id="arrangement1">
        <Lanes timeUnit="beats" id="lanes3">
          <Lanes track="track1" id="lanes1">
            <Clips id="clips1">
              <Clip time="0.0" duration="4.0" playStart="0.0" name="Chords">
                <Notes timeUnit="beats" id="notes1">
                  <Note time="0.0" duration="1.0" channel="0" key="60" vel="1.0"/>
                  <Note time="1.0" duration="3.0" channel="0" key="64" vel="0.5039370078740157"/>
                </Notes>
              </Clip>
            </Clips>
          </Lanes>
          <Lanes track="track2" id="lanes2">
            <Clips id="clips2">
              <Clip time="0.0" duration="3.5385416666666667" playStart="0.0" fadeTimeUnit="beats" fadeInTime="0.9693909949843874" fadeOutTime="0.0" name="Loop &amp; Co">
                <Warps contentTimeUnit="seconds" timeUnit="beats" id="warps1">
                  <Audio algorithm="repitch" channels="1" sampleRate="48000" duration="2.0" id="audio1">
                    <File path="audio/Loop_Co.wav"/>
                  </Audio>
                  <Warp time="0.0" contentTime="0.0"/>
                  <Warp time="1.0" contentTime="0.5163081691005694"/>
                  <Warp time="2.0" contentTime="1.068251140996181"/>
                  <Warp time="3.0" contentTime="1.6611149182259561"/>
                  <Warp time="3.5385416666666667" contentTime="1.9995853962460717"/>
                </Warps>
              </Clip>
              <Clip time="4.0" duration="2.0" playStart="0.0" name="Loop &amp; Co">
                <Warps contentTimeUnit="seconds" timeUnit="beats" id="warps2">
                  <Audio algorithm="stretch" channels="1" sampleRate="48000" duration="2.0" id="audio2">
                    <File path="audio/Loop_Co.wav"/>
                  </Audio>
                  <Warp time="0.0" contentTime="0.0"/>
                  <Warp time="2.0" contentTime="2.0"/>
                </Warps>
              </Clip>
            </Clips>
          </Lanes>
        </Lanes>
        <Markers id="markers1">
          <Marker time="4.0" name="Drop"/>
        </Markers>
        <TempoAutomation unit="bpm" id="tempoAutomation1">
          <Target parameter="tempo"/>
          <RealPoint time="0.0" value="120.0" interpolation="linear"/>
          <RealPoint time="8.0" value="60.0" interpolation="hold"/>
        </TempoAutomation>
        <TimeSignatureAutomation id="signatureAutomation1">
          <Target parameter="signature"/>
          <TimeSignaturePoint time="0.0" numerator="4" denominator="4"/>
          <TimeSignaturePoint time="12.0" numerator="3" denominator="4"/>
        </TimeSignatureAutomation>
      </Arrangement>
    </Project>

    """
}
