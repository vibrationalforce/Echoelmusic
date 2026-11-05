import Foundation

/// The arrangement's video and audio regions as an OpenTimelineIO timeline (`.otio`, JSON) and
/// an OTIOZ bundle — the timeline DaVinci Resolve reads, also in its free version, and every
/// OTIO-aware editor with it (PRO-W2, 2026-11-04; the EDL of PRO-W1 stays as the fallback).
///
/// The schema is the one `opentimelineio` 0.18 writes: `Timeline.1` over a `Stack.1` of
/// `Track.1`s (video first, then audio), each a run of `Gap.1` and `Clip.2` with one
/// `ExternalReference.1`, `RationalTime.1` counted in frames of the chosen rate, the song's
/// markers as `Marker.2` on the stack. The record side starts at 01:00:00:00, as the EDL does.
///
/// An Echoel track whose regions overlap becomes as many OTIO tracks as it needs ("Drums",
/// "Drums 2"), each region on the first that is free at its start — a later-starting region lands
/// on a higher track, which is the one an editor shows, as Echoel does. A region that follows the
/// song's tempo carries a `LinearTimeWarp.1` with the speed it plays at over its stretch.
/// A folder of takes is exported as what it plays (`Track.playedRegions`), the comp's pieces on
/// one track; an overlap of a few frames — a crossfade's rounding — is a `Transition.1` dissolve
/// cut at its middle. Nothing here touches a file; the app writes the text and the bundle.
public enum OTIOExport {
    public typealias FrameRate = EDLExport.FrameRate

    /// The OTIOZ bundle's version file and its contents, as `opentimelineio` writes them.
    public static let bundleVersionFile = "version.txt"
    public static let bundleVersion = "1.0.0"
    /// The timeline inside an OTIOZ bundle.
    public static let bundleContentFile = "content.otio"
    /// The folder of the bundle's media; each `target_url` is `media/<name>`.
    public static let bundleMediaFolder = "media"

    /// One clip as it lands on an OTIO track, in frames of the export's rate from the song's start.
    public struct Cut: Equatable, Sendable {
        public let media: MediaID
        public let name: String
        public let recordIn: Int
        public let recordOut: Int
        public let sourceIn: Int
        /// The file's whole length, in frames.
        public let available: Int
        /// The speed the file plays at, 1 for a region at the file's own speed.
        public let speed: Double
        public let followsTempo: Bool
        /// A dissolve from the cut before into this one (`Transition.1`): frames before the cut point,
        /// played from this cut's file, and frames after it, played from the one before. 0 and 0 is
        /// a plain cut.
        public var dissolveIn = 0
        public var dissolveOut = 0
    }

    /// One OTIO track: an Echoel track, or one of the extra lanes its overlapping regions need.
    public struct Lane: Equatable, Sendable {
        public let name: String
        public let isVideo: Bool
        public let cuts: [Cut]
    }

    /// Every audio and video region as a cut, video tracks before audio tracks, each Echoel track
    /// split into as few lanes as hold its regions without overlap. A region whose file is gone
    /// or that lasts no frame is left out; a track without one has no lane.
    public static func lanes(for project: Project, rate: FrameRate) -> [Lane] {
        let map = project.tempoMap
        func frames(_ seconds: Double) -> Int? {
            let value = (seconds * rate.actual).rounded()
            guard value.isFinite, value >= 0, value < Double(Int32.max) else { return nil }
            return Int(value)
        }
        var video: [Lane] = [], audio: [Lane] = []
        for track in project.tracks where track.kind == .video || track.kind == .audio {
            var cuts: [Cut] = []
            for region in track.playedRegions(in: project) {
                guard let file = project.mediaFile(region.media), file.sampleRate > 0, file.sampleRate.isFinite,
                      let stop = Arranging.end(of: region, in: project),
                      let recordIn = frames(map.seconds(at: region.start)),
                      let recordOut = frames(map.seconds(at: stop)),
                      let sourceIn = frames(Double(region.offset) / file.sampleRate),
                      recordOut > recordIn else { continue }
                let recordSeconds = map.seconds(at: stop) - map.seconds(at: region.start)
                let fileSeconds = Double(region.length) / file.sampleRate
                var speed = 1.0
                if region.warpBPM != nil, recordSeconds > 0 {
                    let ratio = fileSeconds / recordSeconds
                    if ratio.isFinite, ratio > 0 { speed = ratio }
                }
                cuts.append(Cut(media: file.id, name: file.name, recordIn: recordIn, recordOut: recordOut,
                                sourceIn: sourceIn, available: frames(file.duration) ?? 0,
                                speed: speed, followsTempo: region.warpBPM != nil))
            }
            // Stable by start: at one start, the order the track holds them in.
            let ordered = cuts.enumerated().sorted { a, b in
                a.element.recordIn != b.element.recordIn ? a.element.recordIn < b.element.recordIn : a.offset < b.offset
            }.map(\.element)
            // A comp's pieces overlap by its crossfade (`playedRegions`, 10 ms around each cut): such
            // an overlap — a few frames at most — is a dissolve on one track, cut at its middle, never
            // a second track.
            let crossfade = frames(2 * TakeComp.halfCrossfadeSeconds).map { $0 + 1 } ?? 1
            var packed: [[Cut]] = []
            for cut in ordered {
                if let first = packed.first, let last = first.last, last.recordOut > cut.recordIn,
                   last.recordOut - cut.recordIn <= crossfade, cut.recordOut > last.recordOut,
                   cut.recordIn > last.recordIn {
                    let middle = (cut.recordIn + last.recordOut) / 2
                    let outgoing = Cut(media: last.media, name: last.name, recordIn: last.recordIn, recordOut: middle,
                                   sourceIn: last.sourceIn, available: last.available, speed: last.speed,
                                   followsTempo: last.followsTempo, dissolveIn: last.dissolveIn,
                                   dissolveOut: last.dissolveOut)
                    let incoming = Cut(media: cut.media, name: cut.name, recordIn: middle, recordOut: cut.recordOut,
                                   sourceIn: cut.sourceIn + middle - cut.recordIn, available: cut.available,
                                   speed: cut.speed, followsTempo: cut.followsTempo,
                                   dissolveIn: middle - cut.recordIn, dissolveOut: last.recordOut - middle)
                    packed[0][packed[0].count - 1] = outgoing
                    packed[0].append(incoming)
                    continue
                }
                if let free = packed.firstIndex(where: { ($0.last?.recordOut ?? 0) <= cut.recordIn }) {
                    packed[free].append(cut)
                } else {
                    packed.append([cut])
                }
            }
            for (index, lane) in packed.enumerated() {
                let name = index == 0 ? track.name : "\(track.name) \(index + 1)"
                let item = Lane(name: name, isVideo: track.kind == .video, cuts: lane)
                if track.kind == .video { video.append(item) } else { audio.append(item) }
            }
        }
        return video + audio
    }

    /// The timeline as OTIO JSON, indented by four spaces as `opentimelineio` writes it.
    /// `mediaURLs` gives each file's `target_url` (relative, e.g. `media/Take_1.mov` inside a
    /// bundle); a file without one keeps its name in the song as the URL, for the editor to relink.
    public static func json(for project: Project, title: String, rate: FrameRate, recordStart: Int? = nil,
                            mediaURLs: [MediaID: String] = [:]) -> String {
        let start = recordStart ?? EDLExport.defaultRecordStart(rate)
        let r = rate.actual
        var children: [JSON] = []
        for lane in lanes(for: project, rate: rate) {
            var items: [JSON] = []
            var cursor = 0
            for cut in lane.cuts {
                if cut.recordIn > cursor { items.append(gap(cut.recordIn - cursor, rate: r)) }
                if cut.dissolveIn > 0 || cut.dissolveOut > 0 {
                    items.append(.object([
                        ("OTIO_SCHEMA", .string("Transition.1")),
                        ("metadata", .object([])),
                        ("name", .string("")),
                        ("in_offset", time(Double(cut.dissolveIn), rate: r)),
                        ("out_offset", time(Double(cut.dissolveOut), rate: r)),
                        ("transition_type", .string("SMPTE_Dissolve")),
                    ]))
                }
                items.append(clip(cut, rate: r, url: mediaURLs[cut.media] ?? EDLExport.clean(cut.name, fallback: "Clip")))
                cursor = cut.recordOut
            }
            children.append(.object([
                ("OTIO_SCHEMA", .string("Track.1")),
                ("metadata", .object([])),
                ("name", .string(EDLExport.clean(lane.name, fallback: lane.isVideo ? "Video" : "Audio"))),
                ("source_range", .null),
                ("effects", .array([])),
                ("markers", .array([])),
                ("enabled", .bool(true)),
                ("color", .null),
                ("children", .array(items)),
                ("kind", .string(lane.isVideo ? "Video" : "Audio")),
            ]))
        }
        let map = project.tempoMap
        let markers: [JSON] = project.markers.compactMap { marker in
            let frame = (map.seconds(at: marker.tick) * r).rounded()
            guard frame.isFinite, frame >= 0, frame < Double(Int32.max) else { return nil }
            return .object([
                ("OTIO_SCHEMA", .string("Marker.2")),
                ("metadata", .object([])),
                ("name", .string(EDLExport.clean(marker.name, fallback: "Marker"))),
                ("color", .string("YELLOW")),
                ("marked_range", range(start: frame, duration: 0, rate: r)),
                ("comment", .string("")),
            ])
        } + subtitleMarkers(for: project, rate: r)
        let timeline: JSON = .object([
            ("OTIO_SCHEMA", .string("Timeline.1")),
            ("metadata", .object([])),
            ("name", .string(EDLExport.clean(title, fallback: "Echoel"))),
            ("global_start_time", time(Double(start), rate: r)),
            ("tracks", .object([
                ("OTIO_SCHEMA", .string("Stack.1")),
                ("metadata", .object([])),
                ("name", .string("tracks")),
                ("source_range", .null),
                ("effects", .array([])),
                ("markers", .array(markers)),
                ("enabled", .bool(true)),
                ("color", .null),
                ("children", .array(children)),
            ])),
        ])
        var out = ""
        timeline.write(into: &out, indent: 0)
        return out + "\n"
    }

    /// The song's subtitles as `Marker.2`s after its markers (SUBS): each spans its cue, named by
    /// its text on one line and carrying the text in `comment`, in cyan — the colour an editor
    /// tells apart from the yellow locators.
    private static func subtitleMarkers(for project: Project, rate: Double) -> [JSON] {
        let map = project.tempoMap
        return project.subtitles.compactMap { cue in
            let start = (map.seconds(at: cue.start) * rate).rounded()
            let stop = (map.seconds(at: cue.end) * rate).rounded()
            guard start.isFinite, stop.isFinite, start >= 0, stop < Double(Int32.max) else { return nil }
            return .object([
                ("OTIO_SCHEMA", .string("Marker.2")),
                ("metadata", .object([])),
                ("name", .string(EDLExport.clean(cue.text, fallback: "Subtitle"))),
                ("color", .string("CYAN")),
                ("marked_range", range(start: start, duration: Swift.max(0, stop - start), rate: rate)),
                ("comment", .string(cue.text)),
            ])
        }
    }

    private static func gap(_ frames: Int, rate: Double) -> JSON {
        .object([
            ("OTIO_SCHEMA", .string("Gap.1")),
            ("metadata", .object([])),
            ("name", .string("")),
            ("source_range", range(start: 0, duration: Double(frames), rate: rate)),
            ("effects", .array([])),
            ("markers", .array([])),
            ("enabled", .bool(true)),
            ("color", .null),
        ])
    }

    private static func clip(_ cut: Cut, rate: Double, url: String) -> JSON {
        var effects: [JSON] = []
        if cut.followsTempo {
            effects.append(.object([
                ("OTIO_SCHEMA", .string("LinearTimeWarp.1")),
                ("metadata", .object([])),
                ("name", .string("")),
                ("effect_name", .string("LinearTimeWarp")),
                ("enabled", .bool(true)),
                ("time_scalar", .number(cut.speed)),
            ]))
        }
        let metadata: JSON = cut.followsTempo ? .object([("echoel", .object([("follows_tempo", .bool(true))]))]) : .object([])
        return .object([
            ("OTIO_SCHEMA", .string("Clip.2")),
            ("metadata", metadata),
            ("name", .string(EDLExport.clean(cut.name, fallback: "Clip"))),
            ("source_range", range(start: Double(cut.sourceIn), duration: Double(cut.recordOut - cut.recordIn), rate: rate)),
            ("effects", .array(effects)),
            ("markers", .array([])),
            ("enabled", .bool(true)),
            ("color", .null),
            ("media_references", .object([
                ("DEFAULT_MEDIA", .object([
                    ("OTIO_SCHEMA", .string("ExternalReference.1")),
                    ("metadata", .object([])),
                    ("name", .string("")),
                    ("available_range", range(start: 0, duration: Double(cut.available), rate: rate)),
                    ("available_image_bounds", .null),
                    ("target_url", .string(url)),
                ])),
            ])),
            ("active_media_reference_key", .string("DEFAULT_MEDIA")),
        ])
    }

    private static func range(start: Double, duration: Double, rate: Double) -> JSON {
        .object([
            ("OTIO_SCHEMA", .string("TimeRange.1")),
            ("duration", time(duration, rate: rate)),
            ("start_time", time(start, rate: rate)),
        ])
    }

    private static func time(_ value: Double, rate: Double) -> JSON {
        .object([("OTIO_SCHEMA", .string("RationalTime.1")), ("rate", .number(rate)), ("value", .number(value))])
    }

    /// A JSON value with its keys in the order written — OTIO puts `OTIO_SCHEMA` first.
    indirect enum JSON {
        case object([(String, JSON)])
        case array([JSON])
        case string(String)
        case number(Double)
        case bool(Bool)
        case null

        func write(into out: inout String, indent: Int) {
            let pad = String(repeating: " ", count: indent + 4), close = String(repeating: " ", count: indent)
            switch self {
            case .object(let pairs):
                guard !pairs.isEmpty else { out += "{}"; return }
                out += "{\n"
                for (index, pair) in pairs.enumerated() {
                    out += pad
                    JSON.string(pair.0).write(into: &out, indent: indent + 4)
                    out += ": "
                    pair.1.write(into: &out, indent: indent + 4)
                    out += index == pairs.count - 1 ? "\n" : ",\n"
                }
                out += close + "}"
            case .array(let items):
                guard !items.isEmpty else { out += "[]"; return }
                out += "[\n"
                for (index, item) in items.enumerated() {
                    out += pad
                    item.write(into: &out, indent: indent + 4)
                    out += index == items.count - 1 ? "\n" : ",\n"
                }
                out += close + "]"
            case .string(let text):
                out += "\""
                for scalar in text.unicodeScalars {
                    switch scalar {
                    case "\"": out += "\\\""
                    case "\\": out += "\\\\"
                    case "\n": out += "\\n"
                    case "\r": out += "\\r"
                    case "\t": out += "\\t"
                    default:
                        if scalar.value < 0x20 {
                            out += String(format: "\\u%04x", scalar.value)
                        } else {
                            out.unicodeScalars.append(scalar)
                        }
                    }
                }
                out += "\""
            case .number(let value):
                // Swift's shortest round-trip form: `24.0`, `23.976023976023978` — the same on every
                // platform. JSON has no infinity or NaN; such a value cannot arise above and writes 0.
                out += value.isFinite ? "\(value)" : "0.0"
            case .bool(let value):
                out += value ? "true" : "false"
            case .null:
                out += "null"
            }
        }
    }
}
