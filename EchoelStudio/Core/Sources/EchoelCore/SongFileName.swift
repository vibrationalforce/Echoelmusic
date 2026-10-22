/// Whether the open song's package takes a new name before the next write. The package follows a
/// CHANGE of the song's own name — Rename Song, its Undo, its Redo — and nothing else: a song
/// whose file was called something else when it opened (one brought in from Files as
/// "Track (1)") keeps that file name until it is renamed. While anything reads from or writes into
/// the package, the move waits for a write after it. Pure, so the rules are tested here; the
/// document controller asks it before each write.
public struct SongFileName: Equatable, Sendable {
    /// The song's name the package last followed: the name it had when it opened, or the one it
    /// moved for. Nil before any song is open.
    private var followedName: String?

    public init() {}

    /// A song opened or started with `name`. A move the previous song was waiting for goes with
    /// it: the next song's package is its own.
    public mutating func opened(named name: String) {
        followedName = name
    }

    /// The song is called `name` now and the package has not followed it yet.
    public func isDue(for name: String) -> Bool {
        followedName.map { $0 != name } ?? false
    }

    /// Whether to move the package now, for a song called `name`. Never while it is `busy`; an
    /// Undo back to the name the package already has leaves nothing to do.
    public func shouldMove(for name: String, busy: Bool) -> Bool {
        !busy && isDue(for: name)
    }

    /// The package follows `name` now — moved, or given up after a move that failed, which is said
    /// once and not tried again on every write.
    public mutating func followed(_ name: String) {
        followedName = name
    }
}
