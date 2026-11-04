import Foundation

/// The song as a DAWproject (`.dawproject`, the open MIT format of github.com/bitwig/dawproject):
/// a ZIP with `project.xml`, `metadata.xml` and the audio files, which Bitwig Studio, Studio One,
/// Cubase, Cubasis and others open with tracks, clips and tempo intact (PRO-W2, 2026-11-04).
///
/// What it carries, in the elements of the published `Project.xsd` (version 1.0):
/// - **Transport**: the song's tempo and first time signature; tempo changes and ramps as
///   `TempoAutomation` (a point's `interpolation` is `linear` where the next change is a ramp,
///   `hold` otherwise), meter changes as `TimeSignatureAutomation`.
/// - **Structure**: one `Track` per instrument, audio and return track (`notes`, `audio`, an
///   `effect` channel) and the master; each `Channel` with mute, solo, pan (normalized 0…1),
///   volume (linear) and post-fader sends into the returns.
/// - **Arrangement**: every audio region as a `Clip` over `Warps` — beats against the file's
///   seconds, so a region at the file's own speed keeps its timing under tempo changes and ramps,
///   and a region that follows the tempo stretches from its native tempo — with its fades (in
///   beats); every placed MIDI clip with its `Notes` (velocity 0…1); every placed audio clip like
///   a region; the song's markers.
/// - Not carried, because the format has no place a DAW would read for them: Echoel's own
///   instruments and effects (no plug-in state outside Echoel), automation of Echoel parameters,
///   controllers and pitch bends inside clips, region gain, video tracks, session scenes.
///
/// Times are in beats (quarter notes) from the song's start. Nothing here touches a file.
public enum DAWprojectExport {
    public static let projectFile = "project.xml"
    public static let metadataFile = "metadata.xml"
    /// The folder of the bundle's audio; each `File path` is `audio/<name>`.
    public static let mediaFolder = "audio"

    /// `project.xml`. `mediaPaths` gives each audio file's path inside the bundle (from
    /// `ExportMedia.names`); a clip whose file has none is left out. `channels` gives each file's
    /// channel count, which the format requires; a file without one is stereo.
    public static func projectXML(for project: Project, mediaPaths: [MediaID: String],
                                  channels: [MediaID: Int] = [:], application: String = "Echoel Studio",
                                  version: String = "11.0.0") -> String {
        var ids = IDs()
        let tracks = project.tracks.filter { $0.kind != .video }
        let trackIDs = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, ids.next("track")) })
        let channelIDs = Dictionary(uniqueKeysWithValues: tracks.map { ($0.id, ids.next("channel")) })
        let masterTrack = ids.next("track"), masterChannel = ids.next("channel")

        var structure: [XML] = []
        for track in tracks {
            guard let trackID = trackIDs[track.id], let channelID = channelIDs[track.id] else { continue }
            let content = track.kind == .instrument ? "notes" : "audio"
            let sends: [XML] = track.sends.compactMap { send in
                guard let target = channelIDs[send.target] else { return nil }
                return XML("Send", [("destination", target), ("type", "post"), ("id", ids.next("send"))], [
                    XML("Volume", volume(send.levelDB, id: ids.next("volume"))),
                ])
            }
            var parts: [XML] = [
                XML("Mute", [("value", track.mixer.isMuted ? "true" : "false"), ("id", ids.next("mute"))]),
                XML("Pan", pan(track.mixer.pan, id: ids.next("pan"))),
            ]
            if !sends.isEmpty { parts.append(XML("Sends", [], sends)) }
            parts.append(XML("Volume", volume(track.mixer.volumeDB, id: ids.next("volume"))))
            structure.append(XML("Track", [("contentType", content), ("loaded", "true"), ("id", trackID),
                                           ("name", EDLExport.clean(track.name, fallback: "Track"))], [
                XML("Channel", [("audioChannels", "2"), ("destination", masterChannel),
                                ("role", track.kind == .returnTrack ? "effect" : "regular"),
                                ("solo", track.mixer.isSoloed ? "true" : "false"), ("id", channelID)], parts),
            ]))
        }
        structure.append(XML("Track", [("contentType", "audio notes"), ("loaded", "true"), ("id", masterTrack),
                                       ("name", "Master")], [
            XML("Channel", [("audioChannels", "2"), ("role", "master"), ("solo", "false"), ("id", masterChannel)], [
                XML("Mute", [("value", project.master.isMuted ? "true" : "false"), ("id", ids.next("mute"))]),
                XML("Pan", pan(project.master.pan, id: ids.next("pan"))),
                XML("Volume", volume(project.master.volumeDB, id: ids.next("volume"))),
            ]),
        ]))

        let tempoID = "tempo", signatureID = "signature"
        let transport = XML("Transport", [], [
            XML("Tempo", [("max", "999"), ("min", "20"), ("unit", "bpm"), ("value", number(project.tempo)),
                          ("id", tempoID), ("name", "Tempo")]),
            XML("TimeSignature", [("denominator", "\(project.timeSignature.denominator)"),
                                  ("numerator", "\(project.timeSignature.numerator)"), ("id", signatureID)]),
        ])

        var trackLanes: [XML] = []
        for track in tracks {
            guard let trackID = trackIDs[track.id] else { continue }
            let clips = self.clips(of: track, in: project, mediaPaths: mediaPaths, channels: channels, ids: &ids)
            guard !clips.isEmpty else { continue }
            trackLanes.append(XML("Lanes", [("track", trackID), ("id", ids.next("lanes"))], [
                XML("Clips", [("id", ids.next("clips"))], clips.map(\.xml)),
            ]))
        }
        var arrangement: [XML] = [XML("Lanes", [("timeUnit", "beats"), ("id", ids.next("lanes"))], trackLanes)]
        if !project.markers.isEmpty {
            arrangement.append(XML("Markers", [("id", ids.next("markers"))], project.markers.map {
                XML("Marker", [("time", beats($0.tick)), ("name", EDLExport.clean($0.name, fallback: "Marker"))])
            }))
        }
        if !project.tempoChanges.isEmpty {
            var points: [XML] = [XML("Target", [("parameter", tempoID)])]
            let changes = project.tempoChanges
            for index in -1..<changes.count {
                let tick = index < 0 ? 0 : changes[index].tick
                let bpm = index < 0 ? project.tempo : changes[index].bpm
                let rampsOn = index + 1 < changes.count && changes[index + 1].curve == .linear
                points.append(XML("RealPoint", [("time", beats(tick)), ("value", number(bpm)),
                                                ("interpolation", rampsOn ? "linear" : "hold")]))
            }
            arrangement.append(XML("TempoAutomation", [("unit", "bpm"), ("id", ids.next("tempoAutomation"))], points))
        }
        if !project.timeSignatureChanges.isEmpty {
            var points: [XML] = [XML("Target", [("parameter", signatureID)])]
            points.append(signaturePoint(0, project.timeSignature))
            points += project.timeSignatureChanges.map { signaturePoint($0.tick, $0.signature) }
            arrangement.append(XML("TimeSignatureAutomation", [("id", ids.next("signatureAutomation"))], points))
        }

        let root = XML("Project", [("version", "1.0")], [
            XML("Application", [("name", application), ("version", version)]),
            transport,
            XML("Structure", [], structure),
            XML("Arrangement", [("id", ids.next("arrangement"))], arrangement),
        ])
        var out = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        root.write(into: &out, indent: 0)
        return out
    }

    /// `metadata.xml`: the song's name as the title.
    public static func metadataXML(title: String) -> String {
        var out = "<?xml version=\"1.0\" encoding=\"UTF-8\" standalone=\"yes\"?>\n"
        XML("MetaData", [], [XML("Title", text: EDLExport.clean(title, fallback: "Echoel"))]).write(into: &out, indent: 0)
        return out
    }

    // MARK: - Clips

    private static func clips(of track: Track, in project: Project, mediaPaths: [MediaID: String],
                              channels: [MediaID: Int], ids: inout IDs) -> [(start: Tick, xml: XML)] {
        var out: [(start: Tick, xml: XML)] = []
        let map = project.tempoMap
        if track.kind == .audio {
            for region in track.regions {
                guard let file = project.mediaFile(region.media), let path = mediaPaths[file.id],
                      let stop = Arranging.end(of: region, in: project), stop > region.start else { continue }
                let firstSecond = Double(region.offset) / file.sampleRate
                let points: [(Tick, Double)]
                if region.warpBPM != nil {
                    // File time is beats at the native tempo: one straight line.
                    points = [(region.start, firstSecond), (stop, firstSecond + Double(region.length) / file.sampleRate)]
                } else {
                    points = clockPoints(from: region.start, to: stop, map: map).map {
                        ($0, firstSecond + map.seconds(at: $0) - map.seconds(at: region.start))
                    }
                }
                var attributes: [(String, String)] = [("time", beats(region.start)), ("duration", beats(stop - region.start)),
                                                      ("playStart", "0.0")]
                let fades = region.effectiveFades
                if fades.fadeIn > 0 || fades.fadeOut > 0 {
                    let rise = project.position(of: region, atFileFrames: Double(fades.fadeIn)).map { $0 - Double(region.start) } ?? 0
                    let fallStart = project.position(of: region, atFileFrames: Double(region.length - fades.fadeOut))
                    let fall = fallStart.map { Double(stop) - $0 } ?? 0
                    attributes += [("fadeTimeUnit", "beats"),
                                   ("fadeInTime", number(Swift.max(0, rise) / Double(MusicalTime.ticksPerQuarter))),
                                   ("fadeOutTime", number(Swift.max(0, fall) / Double(MusicalTime.ticksPerQuarter)))]
                }
                attributes.append(("name", EDLExport.clean(file.name, fallback: "Audio")))
                out.append((region.start, XML("Clip", attributes, [
                    warps(points, start: region.start, file: file, path: path, channels: channels[file.id] ?? 2,
                          stretched: region.warpBPM != nil, ids: &ids),
                ])))
            }
        }
        for placement in track.placements {
            guard let clip = track.clips.first(where: { $0.id == placement.clip }), clip.length > 0 else { continue }
            let end = placement.start + clip.length
            if let audio = clip.audio {
                guard track.kind == .audio, let file = project.mediaFile(audio.media), let path = mediaPaths[file.id],
                      file.sampleRate > 0, file.sampleRate.isFinite else { continue }
                let heard = map.tick(atSeconds: map.seconds(at: placement.start) + Double(audio.length) / file.sampleRate)
                let stop = Swift.min(end, heard)
                guard stop > placement.start else { continue }
                let firstSecond = Double(audio.offset) / file.sampleRate
                let points = clockPoints(from: placement.start, to: stop, map: map).map {
                    ($0, firstSecond + map.seconds(at: $0) - map.seconds(at: placement.start))
                }
                out.append((placement.start, XML("Clip", [("time", beats(placement.start)),
                                                          ("duration", beats(stop - placement.start)), ("playStart", "0.0"),
                                                          ("name", EDLExport.clean(clip.name, fallback: "Clip"))], [
                    warps(points, start: placement.start, file: file, path: path, channels: channels[file.id] ?? 2,
                          stretched: false, ids: &ids),
                ])))
            } else if track.kind == .instrument {
                let notes: [XML] = clip.notes.sorted { ($0.start, $0.pitch) < ($1.start, $1.pitch) }.compactMap { note in
                    guard note.start >= 0, note.start < clip.length, note.length > 0 else { return nil }
                    let length = Swift.min(note.length, clip.length - note.start)
                    return XML("Note", [("time", beats(note.start)), ("duration", beats(length)), ("channel", "0"),
                                        ("key", "\(note.pitch)"), ("vel", number(Double(note.velocity) / 127))])
                }
                out.append((placement.start, XML("Clip", [("time", beats(placement.start)), ("duration", beats(clip.length)),
                                                          ("playStart", "0.0"),
                                                          ("name", EDLExport.clean(clip.name, fallback: "Clip"))], [
                    XML("Notes", [("timeUnit", "beats"), ("id", ids.next("notes"))], notes),
                ])))
            }
        }
        return out.enumerated().sorted { a, b in
            a.element.start != b.element.start ? a.element.start < b.element.start : a.offset < b.offset
        }.map(\.element)
    }

    private static func warps(_ points: [(Tick, Double)], start: Tick, file: MediaFile, path: String, channels: Int,
                              stretched: Bool, ids: inout IDs) -> XML {
        var children: [XML] = [
            XML("Audio", [("algorithm", stretched ? "stretch" : "repitch"), ("channels", "\(Swift.max(1, channels))"),
                          ("sampleRate", "\(Int(file.sampleRate.rounded()))"), ("duration", number(file.duration)),
                          ("id", ids.next("audio"))], [
                XML("File", [("path", path)]),
            ]),
        ]
        children += points.map { XML("Warp", [("time", beats($0.0 - start)), ("contentTime", number($0.1))]) }
        return XML("Warps", [("contentTimeUnit", "seconds"), ("timeUnit", "beats"), ("id", ids.next("warps"))], children)
    }

    /// Where a stretch at the file's own speed needs a warp point so that beats against seconds is
    /// a straight line between them: its two ends, every tempo change inside, and every quarter
    /// note inside a ramp, at most 4 096 points.
    static func clockPoints(from start: Tick, to stop: Tick, map: TempoMap) -> [Tick] {
        var ticks: Set<Tick> = [start, stop]
        for segment in map.segments where segment.startTick > start && segment.startTick < stop {
            ticks.insert(segment.startTick)
        }
        if map.hasRamps {
            let quarter = MusicalTime.ticksPerQuarter
            var tick = (start / quarter + 1) * quarter
            while tick < stop, ticks.count < 4_096 {
                if map.isRamp(at: tick) { ticks.insert(tick) }
                tick += quarter
            }
        }
        return ticks.sorted()
    }

    // MARK: - Values

    private static func signaturePoint(_ tick: Tick, _ signature: TimeSignature) -> XML {
        XML("TimeSignaturePoint", [("time", beats(tick)), ("numerator", "\(signature.numerator)"),
                                   ("denominator", "\(signature.denominator)")])
    }

    /// A fader level in dB as the format's linear gain, 0 for the floor (silence), at most 2.
    private static func volume(_ db: Double, id: String) -> [(String, String)] {
        let gain = db.isFinite && db > MixerStrip.volumeRange.lowerBound ? Swift.min(Foundation.pow(10, db / 20), 2) : 0
        return [("max", "2.0"), ("min", "0.0"), ("unit", "linear"), ("value", number(gain)), ("id", id), ("name", "Volume")]
    }

    /// −1…+1 as the format's normalized 0…1, centre 0.5.
    private static func pan(_ pan: Double, id: String) -> [(String, String)] {
        let value = pan.isFinite ? (Swift.min(Swift.max(pan, -1), 1) + 1) / 2 : 0.5
        return [("max", "1.0"), ("min", "0.0"), ("unit", "normalized"), ("value", number(value)), ("id", id), ("name", "Pan")]
    }

    static func beats(_ ticks: Tick) -> String { number(Double(ticks) / Double(MusicalTime.ticksPerQuarter)) }

    /// Swift's shortest round-trip form (`4.0`, `0.3333333333333333`), the same on every platform;
    /// 0 for a value that is not a number.
    static func number(_ value: Double) -> String { value.isFinite ? "\(value)" : "0.0" }

    /// Element ids, unique and stable: the kind and a running number (`track1`, `clips4`).
    private struct IDs {
        private var counts: [String: Int] = [:]
        mutating func next(_ kind: String) -> String {
            let number = (counts[kind] ?? 0) + 1
            counts[kind] = number
            return "\(kind)\(number)"
        }
    }

    /// An element with its attributes in the order written and its children, or its text.
    struct XML {
        let name: String
        let attributes: [(String, String)]
        let children: [XML]
        let text: String?

        init(_ name: String, _ attributes: [(String, String)] = [], _ children: [XML] = []) {
            self.name = name
            self.attributes = attributes
            self.children = children
            self.text = nil
        }

        init(_ name: String, text: String) {
            self.name = name
            self.attributes = []
            self.children = []
            self.text = text
        }

        func write(into out: inout String, indent: Int) {
            out += String(repeating: "  ", count: indent) + "<" + name
            for (key, value) in attributes { out += " \(key)=\"\(XML.escape(value))\"" }
            if let text {
                out += ">\(XML.escape(text))</\(name)>\n"
            } else if children.isEmpty {
                out += "/>\n"
            } else {
                out += ">\n"
                for child in children { child.write(into: &out, indent: indent + 1) }
                out += String(repeating: "  ", count: indent) + "</\(name)>\n"
            }
        }

        static func escape(_ text: String) -> String {
            var out = ""
            for scalar in text.unicodeScalars {
                switch scalar {
                case "&": out += "&amp;"
                case "<": out += "&lt;"
                case ">": out += "&gt;"
                case "\"": out += "&quot;"
                case "'": out += "&apos;"
                case "\t", "\n", "\r": out += " "
                default:
                    // XML 1.0 has no place for the other control characters.
                    if scalar.value >= 0x20, scalar.value != 0xFFFE, scalar.value != 0xFFFF { out.unicodeScalars.append(scalar) }
                }
            }
            return out
        }
    }
}
