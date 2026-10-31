import Foundation

/// Takes that reached the song's `Media/` folder and never the song: the app ended between the
/// take's last block and the save that would have named it (a crash, the battery, the system).
/// A take is written as `Media/<its id>.caf` before it is committed, so such a file is found by
/// its name and its age — newer than the document, since every write that names a take or lets
/// one go (an Undo of "Record Take") comes after the take's file. Older files the song does not
/// name were let go on purpose and stay where they are; files of any other shape are not takes.
public enum TakeRecovery {
    /// A file in the song's media folder: its name and when it was last written.
    public struct FolderFile: Equatable, Sendable {
        public let name: String
        public let modified: Date

        public init(name: String, modified: Date) {
            self.name = name
            self.modified = modified
        }
    }

    /// A take the song does not name, with the length its header states.
    public struct Take: Equatable, Sendable {
        public let id: MediaID
        public let path: String
        public let frameCount: Int
        public let sampleRate: Double

        public init(id: MediaID, path: String, frameCount: Int, sampleRate: Double) {
            self.id = id
            self.path = path
            self.frameCount = frameCount
            self.sampleRate = sampleRate
        }
    }

    /// The name of the track the recovered takes go on, and of each take on it.
    public static let trackName = "Recovered Takes"
    public static let takeName = "Recovered Take"

    /// The paths of `files` that look like takes the song lost, oldest first: `<UUID>.caf`, an id
    /// and a path the song does not hold, written after the document was (`documentModified`;
    /// nil when there is no document date, which counts every such file).
    public static func orphans(in project: Project, files: [FolderFile], documentModified: Date?) -> [(id: MediaID, path: String)] {
        let ids = Set(project.media.map(\.id))
        let paths = Set(project.media.map(\.path))
        return files
            .compactMap { file -> (id: MediaID, path: String, modified: Date)? in
                guard file.name.hasSuffix(".caf") else { return nil }
                guard let uuid = UUID(uuidString: String(file.name.dropLast(4))) else { return nil }
                let id = MediaID(uuid)
                let path = "\(MediaFile.directory)/\(file.name)"
                guard !ids.contains(id), !paths.contains(path) else { return nil }
                if let documentModified, file.modified <= documentModified { return nil }
                return (id, path, file.modified)
            }
            .sorted { $0.modified != $1.modified ? $0.modified < $1.modified : $0.path < $1.path }
            .map { (id: $0.id, path: $0.path) }
    }

    /// The commands that put `takes` back into the song: one new audio track named `trackName`,
    /// each take as a media file and a region on it, back to back from the song's start. Takes
    /// without a usable length are left out; nil when none is left. Performed as one step, one
    /// Undo takes them all back.
    public static func commands(for project: Project, takes: [Take], track: TrackID = TrackID()) -> [Command]? {
        let usable = takes.filter {
            MediaFile(id: $0.id, name: takeName, path: $0.path, frameCount: $0.frameCount, sampleRate: $0.sampleRate).hasUsableFormat
                && project.mediaFile($0.id) == nil
        }
        guard !usable.isEmpty else { return nil }
        let map = project.tempoMap
        var commands: [Command] = [.addTrack(id: track, name: trackName, kind: .audio, index: nil)]
        var seconds = 0.0
        for (number, take) in usable.enumerated() {
            let name = usable.count == 1 ? takeName : "\(takeName) \(number + 1)"
            let file = MediaFile(id: take.id, name: name, path: take.path, frameCount: take.frameCount, sampleRate: take.sampleRate)
            commands.append(.addMedia(file))
            commands.append(.placeAudio(track: track, id: RegionID(), media: take.id, start: map.tick(atSeconds: seconds)))
            seconds += file.duration
        }
        return commands
    }
}
