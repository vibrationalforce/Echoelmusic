import EchoelCore

/// What an 8×8 clip grid shows of the session, and what each pad means: the model behind a grid
/// controller. Columns are the session's tracks (instrument and audio), rows its scenes, from an offset the arrows move.
/// Pure — the main thread builds it from the song and the session state; a template draws it.
public struct ClipGrid: Equatable, Sendable {
    public enum Pad: Equatable, Sendable {
        /// No track or no scene at this pad.
        case off
        /// A slot without a clip.
        case empty
        case clip(color: Int)
        /// Waiting for its launch boundary.
        case queued(color: Int)
        case playing(color: Int)
    }

    public static let size = 8

    /// The tracks and scenes on the grid, left to right and top to bottom.
    public let tracks: [TrackID]
    public let scenes: [SceneID]
    public let trackOffset: Int
    public let sceneOffset: Int
    /// `pads[row][column]`, row 0 at the top.
    public let pads: [[Pad]]
    /// Whether more tracks or scenes lie beyond each edge — what the arrows can reach.
    public let canMoveUp: Bool
    public let canMoveDown: Bool
    public let canMoveLeft: Bool
    public let canMoveRight: Bool

    /// The session's instrument and audio tracks and scenes from the offsets, which are clamped so the grid
    /// never shows less than it could.
    public init(project: Project, playing: [TrackID: ClipID], queued: [TrackID: ClipID],
                trackOffset: Int, sceneOffset: Int) {
        let allTracks = project.tracks.filter { $0.kind != .returnTrack }
        let allScenes = project.scenes
        let tracksFrom = Self.clamp(trackOffset, count: allTracks.count)
        let scenesFrom = Self.clamp(sceneOffset, count: allScenes.count)
        let shownTracks = Array(allTracks.dropFirst(tracksFrom).prefix(Self.size))
        let shownScenes = Array(allScenes.dropFirst(scenesFrom).prefix(Self.size))
        tracks = shownTracks.map(\.id)
        scenes = shownScenes.map(\.id)
        self.trackOffset = tracksFrom
        self.sceneOffset = scenesFrom
        pads = (0..<Self.size).map { row in
            (0..<Self.size).map { column in
                guard row < shownScenes.count, column < shownTracks.count else { return .off }
                let track = shownTracks[column]
                guard let clip = track.clipInSlot(shownScenes[row].id) else { return .empty }
                if playing[track.id] == clip { return .playing(color: track.colorIndex) }
                if queued[track.id] == clip { return .queued(color: track.colorIndex) }
                return .clip(color: track.colorIndex)
            }
        }
        canMoveUp = scenesFrom > 0
        canMoveDown = scenesFrom + Self.size < allScenes.count
        canMoveLeft = tracksFrom > 0
        canMoveRight = tracksFrom + Self.size < allTracks.count
    }

    /// The track and scene under a pad, or nil where the grid shows none.
    public func slot(column: Int, row: Int) -> (track: TrackID, scene: SceneID)? {
        guard column >= 0, column < tracks.count, row >= 0, row < scenes.count else { return nil }
        return (tracks[column], scenes[row])
    }

    public func scene(row: Int) -> SceneID? {
        row >= 0 && row < scenes.count ? scenes[row] : nil
    }

    private static func clamp(_ offset: Int, count: Int) -> Int {
        Swift.min(Swift.max(offset, 0), Swift.max(count - size, 0))
    }
}

/// Novation Launchpad (Mini MK3, X, Pro MK3) in Programmer mode: the pads are notes 11…88 (row
/// 1 at the bottom, column 1 at the left), the arrows and the right-hand scene column are
/// controllers, and a light is the same message sent back with a palette colour — channel 1
/// lit, 2 flashing, 3 pulsing.
public enum Launchpad {
    public enum Model: Sendable, Equatable {
        case miniMK3, x, proMK3

        var deviceID: UInt8 {
            switch self {
            case .miniMK3: 0x0D
            case .x: 0x0C
            case .proMK3: 0x0E
            }
        }
    }

    public enum Press: Equatable, Sendable {
        case pad(column: Int, row: Int)
        case scene(row: Int)
        case up, down, left, right
    }

    /// The model a MIDI port's name belongs to, or nil for any other device. Its "DAW" port is
    /// left alone: that one belongs to a DAW mode we do not use.
    public static func model(named name: String) -> Model? {
        let lower = name.lowercased()
        let named = lower.contains("launchpad") || ["lpminimk3", "lpx", "lppromk3"].contains { lower.hasPrefix($0) }
        guard named, !lower.contains("daw") else { return nil }
        if lower.contains("pro") { return .proMK3 }
        if lower.contains("lpx") || lower.contains("launchpad x") { return .x }
        return .miniMK3
    }

    /// The SysEx that switches the device into Programmer mode.
    public static func programmerMode(_ model: Model) -> [UInt8] {
        [0xF0, 0x00, 0x20, 0x29, 0x02, model.deviceID, 0x0E, 0x01, 0xF7]
    }

    /// What a message from the device means; releases and everything else are nil.
    public static func press(status: UInt8, _ data1: UInt8, _ data2: UInt8) -> Press? {
        guard data2 > 0 else { return nil }
        switch status & 0xF0 {
        case 0x90:
            let row = Int(data1) / 10, column = Int(data1) % 10
            guard (1...8).contains(row), (1...8).contains(column) else { return nil }
            return .pad(column: column - 1, row: 8 - row)
        case 0xB0:
            switch data1 {
            case 91: return .up
            case 92: return .down
            case 93: return .left
            case 94: return .right
            default:
                guard data1 % 10 == 9, (1...8).contains(Int(data1) / 10) else { return nil }
                return .scene(row: 8 - Int(data1) / 10)
            }
        default:
            return nil
        }
    }

    /// The palette colour of each of the 12 track colours.
    static let trackColors: [UInt8] = [5, 9, 13, 17, 21, 25, 37, 41, 45, 49, 53, 57]
    static let playingColor: UInt8 = 21
    static let sceneColor: UInt8 = 1
    static let arrowColor: UInt8 = 3

    /// The messages that bring the device's lights from `previous` (nil: unknown, send all) to
    /// `grid`, three bytes each.
    public static func lights(_ grid: ClipGrid, previous: ClipGrid?) -> [[UInt8]] {
        var messages: [[UInt8]] = []
        for row in 0..<ClipGrid.size {
            for column in 0..<ClipGrid.size {
                let pad = grid.pads[row][column]
                if let previous, previous.pads[row][column] == pad { continue }
                let note = UInt8((8 - row) * 10 + column + 1)
                messages.append(light(pad, note: note))
            }
            let lit = row < grid.scenes.count
            if previous == nil || (row < (previous?.scenes.count ?? 0)) != lit {
                messages.append([0xB0, UInt8((8 - row) * 10 + 9), lit ? sceneColor : 0])
            }
        }
        let arrows: [(UInt8, Bool, Bool?)] = [
            (91, grid.canMoveUp, previous?.canMoveUp), (92, grid.canMoveDown, previous?.canMoveDown),
            (93, grid.canMoveLeft, previous?.canMoveLeft), (94, grid.canMoveRight, previous?.canMoveRight),
        ]
        for (number, now, before) in arrows where before != now {
            messages.append([0xB0, number, now ? arrowColor : 0])
        }
        return messages
    }

    private static func light(_ pad: ClipGrid.Pad, note: UInt8) -> [UInt8] {
        let color = { (index: Int) in trackColors[((index % trackColors.count) + trackColors.count) % trackColors.count] }
        switch pad {
        case .off, .empty: return [0x90, note, 0]
        case .clip(let index): return [0x90, note, color(index)]
        case .queued: return [0x91, note, playingColor]
        case .playing: return [0x92, note, playingColor]
        }
    }
}

/// MIDI 1.0 bytes as Universal MIDI Packets, the form CoreMIDI's event lists carry: a channel
/// message is one word (type 2), a SysEx is 7-bit data in two-word packets of up to six bytes
/// (type 3). Each returned array is one packet.
public enum UniversalMIDI {
    public static func packets(_ message: [UInt8]) -> [[UInt32]] {
        guard let status = message.first else { return [] }
        if status == 0xF0 {
            let data = Array(message.dropFirst().prefix { $0 != 0xF7 })
            var chunks: [[UInt8]] = stride(from: 0, to: data.count, by: 6).map { Array(data[$0..<Swift.min($0 + 6, data.count)]) }
            if chunks.isEmpty { chunks = [[]] }
            return chunks.enumerated().map { index, chunk in
                let kind: UInt32 = chunks.count == 1 ? 0 : index == 0 ? 1 : index == chunks.count - 1 ? 3 : 2
                var bytes = chunk + Array(repeating: 0, count: 6 - chunk.count)
                bytes = bytes.map { $0 & 0x7F }
                let first = 0x3 << 28 | kind << 20 | UInt32(chunk.count) << 16 | UInt32(bytes[0]) << 8 | UInt32(bytes[1])
                let second = UInt32(bytes[2]) << 24 | UInt32(bytes[3]) << 16 | UInt32(bytes[4]) << 8 | UInt32(bytes[5])
                return [first, second]
            }
        }
        guard status & 0x80 != 0, status < 0xF0 else { return [] }
        let data1 = message.count > 1 ? UInt32(message[1] & 0x7F) : 0
        let data2 = message.count > 2 ? UInt32(message[2] & 0x7F) : 0
        return [[0x2 << 28 | UInt32(status) << 16 | data1 << 8 | data2]]
    }
}
