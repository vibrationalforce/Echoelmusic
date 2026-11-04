import Foundation

/// The names the song's files take inside an export bundle (an `.otioz`, a `.dawproject`): one
/// per file, made of ASCII letters, digits, `-`, `_` and `.` only — so the name is the same as a
/// path, a URL and a ZIP entry, on every system, with nothing to escape — keeping the extension of
/// the file in the song, unique without regard to case (a second "Take 1" is "Take_1_2.mov").
/// PRO-W2, 2026-11-04.
public enum ExportMedia {
    /// Each listed file's name inside `folder` (e.g. `media/Take_1.mov`), in the song's import
    /// order. A file the song does not hold is left out.
    public static func names(for project: Project, using ids: Set<MediaID>, folder: String) -> [MediaID: String] {
        var names: [MediaID: String] = [:]
        var taken = Set<String>()
        for file in project.media where ids.contains(file.id) {
            let ext = safe(URL(fileURLWithPath: file.path).pathExtension, fallback: "")
            let stem = String(safe(file.name, fallback: "Media").prefix(96))
            func candidate(_ number: Int) -> String {
                let base = number == 1 ? stem : "\(stem)_\(number)"
                return ext.isEmpty ? base : "\(base).\(ext)"
            }
            var number = 1
            while taken.contains(candidate(number).lowercased()) { number += 1 }
            taken.insert(candidate(number).lowercased())
            names[file.id] = folder.isEmpty ? candidate(number) : "\(folder)/\(candidate(number))"
        }
        return names
    }

    /// The files the arrangement plays: every audio and video region's, and every placed audio clip's.
    public static func arrangementMedia(of project: Project) -> Set<MediaID> {
        var ids = Set<MediaID>()
        for track in project.tracks {
            for region in track.playedRegions(in: project) { ids.insert(region.media) }
            for placement in track.placements {
                if let audio = track.clips.first(where: { $0.id == placement.clip })?.audio { ids.insert(audio.media) }
            }
        }
        return ids
    }

    /// `text` with every character outside `A–Z a–z 0–9 - _ .` as `_`, runs of `_` folded into
    /// one, no leading dot or underscore; `fallback` when nothing is left.
    static func safe(_ text: String, fallback: String) -> String {
        var out = ""
        for scalar in text.unicodeScalars {
            let keep = scalar.isASCII && (CharacterSet.alphanumerics.contains(scalar) || scalar == "-" || scalar == ".")
            let next: Character = keep ? Character(scalar) : "_"
            if next == "_", out.last == "_" { continue }
            out.append(next)
        }
        while let first = out.first, first == "." || first == "_" { out.removeFirst() }
        while out.last == "_" || out.last == "." { out.removeLast() }
        return out.isEmpty ? fallback : out
    }
}
