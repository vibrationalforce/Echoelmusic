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
        // A return holds effects and a video track pictures: neither has a clip to launch.
        let allTracks = project.tracks.filter { $0.kind == .instrument || $0.kind == .audio }
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
    /// A waiting pad's colour when the pads stay steady (`animates` is false): white, apart from
    /// the green of a playing pad.
    static let waitingColor: UInt8 = 3

    /// The most a light may flash in one second (WCAG 2.3.1, the 3 Hz ceiling).
    public static let maximumFlashesPerSecond = 3.0

    /// Whether a waiting pad may flash and a playing one pulse on a device that a clock drives at
    /// `fastestBPM` at most (`clockReachesDevice`), or that never heard one and runs on its own
    /// default tempo. The device runs those animations one cycle a beat (ANNAHME from Novation's
    /// programmer reference, not measured on a device), so they stay on only up to three a second;
    /// an unknown tempo counts as too fast. A device keeps the last clock it heard after that clock
    /// stops, so the light loop asks `animates(keptClockBPM:)`.
    public static func animates(clockReachesDevice: Bool, fastestBPM: Double) -> Bool {
        guard clockReachesDevice else { return true }
        guard fastestBPM.isFinite, fastestBPM > 0 else { return false }
        return fastestBPM / 60 <= maximumFlashesPerSecond
    }

    /// What a Launchpad may keep from our clock, for the light loop, which looks every 40 ms.
    /// After a clock stops the device keeps "the last clock if no clock is provided" (Novation's
    /// programmer reference), not its own 120 BPM, and it follows a new tempo only once enough of
    /// its pulses have reached it. So `bpm` is a bound, never an estimate: while our clock is
    /// chosen for the device, it covers at once the fastest tempo the clock may send (Play brings
    /// it, and a start and stop between two looks goes unseen), and it falls to a slower tempo
    /// only after the clock has sent that one without a break for `settle`. Not chosen, it stays.
    public struct KeptClock: Equatable, Sendable {
        /// Output latency, the clock's offset (up to 100 ms), Bluetooth MIDI (150 to 250 ms) and
        /// the device locking on to the new tempo. ANNAHME: the lock-on time is not measured.
        public static let settle: Duration = .seconds(3)
        /// The longest gap between two render calls while the engine renders (a 4,096-frame
        /// buffer at 44.1 kHz is 93 ms); a longer one counts as no pulse leaving.
        public static let renderGap: Duration = .milliseconds(250)

        /// The fastest tempo the device may keep from our clock, infinity while it is unknown;
        /// nil while our clock never could have reached the device.
        public private(set) var bpm: Double?
        /// The slower tempo our clock has been sending without a break, and since when.
        private var slower: Double?
        private var slowerSince: Duration = .zero
        private var renders: UInt64 = 0
        private var renderedAt: Duration?

        public init(bpm: Double? = nil) {
            self.bpm = bpm.map { $0.isNaN ? Double.infinity : $0 }
        }

        /// One look. `clockChosen`: our clock goes to this device. `transportRuns`: the song plays,
        /// past any count-in; no pulse leaves before. `renderCount`: the engine's render calls so
        /// far; pulses leave only while it moves. `fastestBPM`: the fastest tempo the pulses
        /// carry, NaN when unknown. `now`: time on a steady clock.
        public mutating func look(clockChosen: Bool, transportRuns: Bool, renderCount: UInt64,
                                  fastestBPM: Double, now: Duration) {
            if renderCount != renders {
                renders = renderCount
                renderedAt = now
            }
            guard clockChosen else {
                slower = nil
                return
            }
            let sent = fastestBPM.isNaN ? Double.infinity : fastestBPM
            guard let kept = bpm, kept > sent else {
                bpm = sent
                slower = nil
                return
            }
            let rendering = renderedAt.map { now - $0 <= Self.renderGap } ?? false
            guard transportRuns, rendering else {
                slower = nil
                return
            }
            if slower != sent {
                slower = sent
                slowerSince = now
            } else if now - slowerSince >= Self.settle {
                bpm = sent
                slower = nil
            }
        }
    }

    /// Whether the pads may flash and pulse on a device that keeps at most `kept` BPM from our
    /// clock (`KeptClock.bpm`); nil, a device our clock never reached, flashes on its own default
    /// tempo.
    public static func animates(keptClockBPM kept: Double?) -> Bool {
        guard let kept else { return true }
        return animates(clockReachesDevice: true, fastestBPM: kept)
    }

    /// The fastest tempo `song` plays at: its own tempo or a tempo change; a ramp never passes its
    /// ends. Give it the song as the engine plays it (`ClockFollower.played` puts a followed
    /// clock's tempo in place of the song's), because that is the tempo our clock sends. NaN as
    /// soon as one tempo is unknown, so an unknown tempo counts as too fast.
    public static func fastestBPM(of song: Project) -> Double {
        song.tempoChanges.reduce(song.tempo) { (fastest: Double, change: TempoChange) -> Double in
            fastest.isNaN || change.bpm.isNaN ? Double.nan : Swift.max(fastest, change.bpm)
        }
    }

    /// The fastest tempo our clock may send while the engine plays `song`, the song as
    /// `AudioEngine.playing` gives it. NaN, unknown, while the song follows a clock whose tempo is
    /// not measured yet (the engine is already pulled to that clock), or a timecode, which paces
    /// the song by nudging its playhead, so a sender running fast sends our pulses faster.
    public static func clockBPM(playing song: Project, followsClock: Bool, clockTempo: Double?,
                                chasesTimecode: Bool) -> Double {
        if chasesTimecode { return Double.nan }
        if followsClock, !(clockTempo?.isFinite ?? false) { return Double.nan }
        return fastestBPM(of: song)
    }

    /// The messages that bring the device's lights from `previous` (nil: unknown, send all) to
    /// `grid`, three bytes each. With `animated` false every pad is lit steadily (channel 1). A
    /// caller that switches `animated` passes `previous` nil, so every pad is sent again.
    public static func lights(_ grid: ClipGrid, previous: ClipGrid?, animated: Bool = true) -> [[UInt8]] {
        var messages: [[UInt8]] = []
        for row in 0..<ClipGrid.size {
            for column in 0..<ClipGrid.size {
                let pad = grid.pads[row][column]
                if let previous, previous.pads[row][column] == pad { continue }
                let note = UInt8((8 - row) * 10 + column + 1)
                messages.append(light(pad, note: note, animated: animated))
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

    private static func light(_ pad: ClipGrid.Pad, note: UInt8, animated: Bool) -> [UInt8] {
        let color = { (index: Int) in trackColors[((index % trackColors.count) + trackColors.count) % trackColors.count] }
        switch pad {
        case .off, .empty: return [0x90, note, 0]
        case .clip(let index): return [0x90, note, color(index)]
        case .queued: return animated ? [0x91, note, playingColor] : [0x90, note, waitingColor]
        case .playing: return animated ? [0x92, note, playingColor] : [0x90, note, playingColor]
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
