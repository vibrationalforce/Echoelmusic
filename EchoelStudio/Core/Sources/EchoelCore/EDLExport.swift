import Foundation

/// The arrangement's video and audio regions as an edit decision list in CMX 3600 — the oldest
/// timeline exchange every editor reads, and the first way from Echoel into DaVinci Resolve
/// (PRO-W1, 2026-11-04; OpenTimelineIO follows). Each region is one cut event: its file as the
/// source (a clip name and a source-file comment, which Resolve relinks by), the stretch of the
/// file it plays as source timecode, and where it sits in the song as record timecode, over the
/// song's tempo map. Video regions are on `V`; the first audio track on `A`, the next on `A2`,
/// `A3` … Markers follow as `* LOC:` comments. Nothing here touches a file; the app writes the
/// text and copies the media beside it.
public enum EDLExport {
    /// The timecode rates an EDL counts in. The fractional ones count non-drop frames at their
    /// nominal base (24, 30, 60) while a second holds 1000/1001 of that, as the CMX format does.
    public enum FrameRate: String, CaseIterable, Sendable {
        case fps23_976, fps24, fps25, fps29_97, fps30, fps50, fps59_94, fps60

        /// Frames in one timecode second.
        public var nominal: Int {
            switch self {
            case .fps23_976, .fps24: 24
            case .fps25: 25
            case .fps29_97, .fps30: 30
            case .fps50: 50
            case .fps59_94, .fps60: 60
            }
        }

        /// Frames in one real second.
        public var actual: Double {
            switch self {
            case .fps23_976, .fps29_97, .fps59_94: Double(nominal) * 1_000 / 1_001
            default: Double(nominal)
            }
        }

        public var title: String {
            switch self {
            case .fps23_976: "23.976 fps"
            case .fps24: "24 fps"
            case .fps25: "25 fps"
            case .fps29_97: "29.97 fps"
            case .fps30: "30 fps"
            case .fps50: "50 fps"
            case .fps59_94: "59.94 fps"
            case .fps60: "60 fps"
            }
        }
    }

    /// One cut event, in frames of the rate it was made at.
    public struct Event: Equatable, Sendable {
        public let number: Int
        /// `V`, `A`, `A2` …
        public let channel: String
        public let media: MediaID
        public let clipName: String
        public let sourceIn: Int
        public let sourceOut: Int
        public let recordIn: Int
        public let recordOut: Int
        /// The region follows the song's tempo (warp), so its source plays at another speed.
        public let followsTempo: Bool
    }

    /// Where the song's first frame lands on the record side: one hour, the editors' convention.
    public static func defaultRecordStart(_ rate: FrameRate) -> Int { 3_600 * rate.nominal }

    /// The events of every audio and video region the song holds, in record order (then video
    /// before audio, then track order). A region whose file is gone or that lasts no frame is left out.
    public static func events(for project: Project, rate: FrameRate, recordStart: Int? = nil) -> [Event] {
        let start = recordStart ?? defaultRecordStart(rate)
        let map = project.tempoMap
        func frames(_ seconds: Double) -> Int? {
            let value = (seconds * rate.actual).rounded()
            guard value.isFinite, value >= 0, value < Double(Int32.max) else { return nil }
            return Int(value)
        }
        var audioNumber = 0
        var unordered: [(order: Int, event: Event)] = []
        for (trackIndex, track) in project.tracks.enumerated() {
            let channel: String
            switch track.kind {
            case .video: channel = "V"
            case .audio:
                audioNumber += 1
                channel = audioNumber == 1 ? "A" : "A\(audioNumber)"
            case .instrument, .returnTrack: continue
            }
            for region in track.regions {
                guard let file = project.mediaFile(region.media), file.sampleRate > 0, file.sampleRate.isFinite,
                      let stop = Arranging.end(of: region, in: project),
                      let recordIn = frames(map.seconds(at: region.start)),
                      let recordOut = frames(map.seconds(at: stop)),
                      let sourceIn = frames(Double(region.offset) / file.sampleRate),
                      recordOut > recordIn else { continue }
                let event = Event(number: 0, channel: channel, media: file.id, clipName: file.name,
                                  sourceIn: sourceIn, sourceOut: sourceIn + recordOut - recordIn,
                                  recordIn: start + recordIn, recordOut: start + recordOut,
                                  followsTempo: region.warpBPM != nil)
                unordered.append((trackIndex, event))
            }
        }
        let ordered = unordered.sorted { a, b in
            if a.event.recordIn != b.event.recordIn { return a.event.recordIn < b.event.recordIn }
            let aVideo = a.event.channel == "V", bVideo = b.event.channel == "V"
            if aVideo != bVideo { return aVideo }
            return a.order < b.order
        }
        return ordered.enumerated().map { index, item in
            let e = item.event
            return Event(number: index + 1, channel: e.channel, media: e.media, clipName: e.clipName,
                         sourceIn: e.sourceIn, sourceOut: e.sourceOut, recordIn: e.recordIn, recordOut: e.recordOut,
                         followsTempo: e.followsTempo)
        }
    }

    /// `frames` as `HH:MM:SS:FF` at the rate's nominal base, non-drop. Negative counts as 0; past
    /// 24 hours it wraps, as timecode does.
    public static func timecode(_ frames: Int, rate: FrameRate) -> String {
        let base = rate.nominal
        let total = Swift.max(0, frames) % (24 * 3_600 * base)
        let f = total % base, seconds = total / base
        return String(format: "%02d:%02d:%02d:%02d", seconds / 3_600, seconds / 60 % 60, seconds % 60, f)
    }

    /// The whole list as text, lines ending CR LF. `fileNames` names the file each media id was
    /// written as beside the list (`SOURCE FILE`), so an editor finds it; without one the clip
    /// name stands alone. At most 999 events, as CMX numbers them in three digits.
    public static func text(for project: Project, title: String, rate: FrameRate, recordStart: Int? = nil,
                            fileNames: [MediaID: String] = [:]) -> String {
        let start = recordStart ?? defaultRecordStart(rate)
        var lines = ["TITLE: \(clean(title, fallback: "Echoel"))", "FCM: NON-DROP FRAME", ""]
        for event in events(for: project, rate: rate, recordStart: start).prefix(999) {
            let number = String(format: "%03d", event.number)
            let channel = event.channel.padding(toLength: 6, withPad: " ", startingAt: 0)
            lines.append("\(number)  AX       \(channel)C        "
                + [event.sourceIn, event.sourceOut, event.recordIn, event.recordOut]
                    .map { timecode($0, rate: rate) }.joined(separator: " "))
            lines.append("* FROM CLIP NAME: \(clean(event.clipName, fallback: "Clip"))")
            if let file = fileNames[event.media] { lines.append("* SOURCE FILE: \(clean(file, fallback: "Clip"))") }
            if event.followsTempo { lines.append("* ECHOEL: follows the song tempo; the source plays at another speed") }
            lines.append("")
        }
        let map = project.tempoMap
        for marker in project.markers {
            let frame = (map.seconds(at: marker.tick) * rate.actual).rounded()
            guard frame.isFinite, frame >= 0, frame < Double(Int32.max) else { continue }
            lines.append("* LOC: \(timecode(start + Int(frame), rate: rate)) YELLOW \(clean(marker.name, fallback: "Marker"))")
        }
        return lines.joined(separator: "\r\n") + "\r\n"
    }

    /// One line of text: no line breaks, at most 128 characters, a fallback when nothing is left.
    static func clean(_ text: String, fallback: String) -> String {
        let flat = text.components(separatedBy: .newlines).joined(separator: " ").trimmingCharacters(in: .whitespaces)
        return flat.isEmpty ? fallback : String(flat.prefix(128))
    }
}
