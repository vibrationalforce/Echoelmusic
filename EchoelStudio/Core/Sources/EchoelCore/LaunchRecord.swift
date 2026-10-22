/// Whether the last launch reached a steady state (ultra-audit R4). A launch that dies before it
/// does — a song that traps while it opens, decodes or plays — must not be repeated by reopening
/// that song on every launch: the next launch starts a new song instead, and every song stays in
/// the list. The app keeps `isPending` in its defaults; this type only decides.
public struct LaunchRecord: Equatable, Sendable {
    /// Seconds after the launch began at which it counts as healthy.
    public static var steadySeconds: Double { 10 }

    /// True from the start of a launch until it is confirmed.
    public private(set) var isPending: Bool

    public init(isPending: Bool = false) {
        self.isPending = isPending
    }

    /// Called once per launch, before a song opens. Returns whether the previous launch ended
    /// before it was confirmed.
    public mutating func begin() -> Bool {
        let previousDied = isPending
        isPending = true
        return previousDied
    }

    /// Confirms the running launch `seconds` after it began; `leaving` when the app went to the
    /// background, which confirms it whenever it happens: a launch that got there is alive. The
    /// app says so only once the song it opened has finished loading, the last thing at launch
    /// that could still end it. A floor of three seconds stood here and took a quick exit for a
    /// crash, so a song opened, left at once and ended later by the system was held at the next
    /// launch for nothing (review 2026-10-22). Returns whether it confirmed now.
    @discardableResult
    public mutating func confirm(after seconds: Double, leaving: Bool) -> Bool {
        guard isPending, seconds.isFinite, seconds >= 0 else { return false }
        guard leaving || seconds >= Self.steadySeconds else { return false }
        isPending = false
        return true
    }
}

/// The songs a launch does not open by itself (ultra-audit R4, review 2026-10-20). While a launch
/// is not confirmed, the song it opens is named here BEFORE it is read; when that launch dies, the
/// next one holds the song back: it stays in the list and opens when it is chosen, but no launch
/// opens it on its own again. Without this, the launch after a crash started a new song, the one
/// after that reopened the same song, and a song that traps while it opens crashed every second
/// launch. The app keeps the values in its defaults; this type only decides.
public struct SongQuarantine: Equatable, Sendable {
    /// At most this many songs are held; the one held longest is let go first.
    public static var capacity: Int { 8 }

    /// The song the running launch is opening, while that launch is not confirmed.
    public private(set) var opening: String?
    /// The held songs by file name, the most recently held last.
    public private(set) var held: [String]

    public init(opening: String? = nil, held: [String] = []) {
        self.opening = opening.flatMap { $0.isEmpty ? nil : $0 }
        var unique: [String] = []
        for name in held where !name.isEmpty && !unique.contains(name) { unique.append(name) }
        self.held = Array(unique.suffix(Self.capacity))
    }

    /// At the start of a launch. When the previous launch died, the song it was opening is held
    /// and returned. Either way the new launch has opened nothing yet.
    public mutating func launchBegan(previousDied: Bool) -> String? {
        defer { opening = nil }
        guard previousDied, let suspect = opening else { return nil }
        held.removeAll { $0 == suspect }
        held.append(suspect)
        if held.count > Self.capacity { held.removeFirst(held.count - Self.capacity) }
        return suspect
    }

    /// The launch, not yet confirmed, is about to open `name`; nil for a new song.
    public mutating func willOpen(_ name: String?) {
        opening = name.flatMap { $0.isEmpty ? nil : $0 }
    }

    /// The launch counts as healthy, so what it opened did not kill it.
    public mutating func launchConfirmed() {
        opening = nil
    }

    /// The song was chosen and opened: launches open it again.
    public mutating func chosen(_ name: String) {
        held.removeAll { $0 == name }
    }

    public func holds(_ name: String) -> Bool {
        held.contains(name)
    }
}
