/// A copy of a track's signal, after its fader and pan, into a return track. The return's
/// effects and fader then shape what all its senders share — one reverb for the whole song.
public struct Send: Codable, Equatable, Sendable {
    /// A return track.
    public var target: TrackID
    /// Send level in dB, on the fader's scale; the floor is silence.
    public var levelDB: Double

    public init(target: TrackID, levelDB: Double) {
        self.target = target
        self.levelDB = levelDB
    }
}

extension Track {
    public static func isValidOutput(_ channel: Int) -> Bool {
        channel >= 2 && channel % 2 == 0 && channel <= outputChannelLimit - 2
    }

    public func send(to target: TrackID) -> Send? {
        sends.first { $0.target == target }
    }
}
