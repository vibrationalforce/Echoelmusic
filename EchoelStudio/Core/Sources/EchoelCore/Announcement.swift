/// A sentence VoiceOver says by itself, without the musician moving to it, and how urgently.
///
/// A control says its own name and value when it is touched; an announcement is for what changes
/// where the finger is not — a song that could not be saved, audio that stopped, an export under
/// way and how it ended, a jam whose host went quiet. The app posts it (`Theme.Accessibility`);
/// what is said and when is decided here, as plain values, where a test can hold it (Law 8).
public struct Announcement: Equatable, Sendable {
    public enum Priority: Int, Comparable, Sendable {
        /// After what VoiceOver is saying: a result that arrives together with something the
        /// system says anyway, such as the share sheet that opens with a finished export.
        case queued
        /// Now, and the next thing said may cut it short: news.
        case normal
        /// Now, and nothing cuts it short: something went wrong, or work is at stake.
        case urgent

        public static func < (lhs: Priority, rhs: Priority) -> Bool { lhs.rawValue < rhs.rawValue }
    }

    public let text: String
    public let priority: Priority

    public init(_ text: String, priority: Priority) {
        self.text = text
        self.priority = priority
    }

    /// Several things to say at once, as one: two announcements posted together cut each other
    /// short, so they are said in a row, at the most urgent of their priorities. Nil for none.
    public static func joined(_ parts: [Announcement]) -> Announcement? {
        guard let mostUrgent = parts.map(\.priority).max() else { return nil }
        return Announcement(parts.map(\.text).joined(separator: " "), priority: mostUrgent)
    }
}

/// The lines of the transport's status strip that VoiceOver hears about, as plain values read from
/// the app. Every one changes with an event — a failed write, a pause, an export, MIDI Learn — never
/// with the clock, so the strip may watch them (Law 6).
public struct StatusStrip: Equatable, Sendable {
    /// The song's changes could not be written.
    public var saveError: String?
    /// The audio could not start, or a take could not be written.
    public var audioError: String?
    /// What went wrong with a song, an import or an export, or what an export left out.
    public var documentError: String?
    /// Why the song paused by itself, or which plugin came back.
    public var notice: String?
    /// What MIDI Learn waits for, while it is on.
    public var learning: String?
    /// While an export runs (or a song is prepared for sharing): the step the strip shows.
    public var exportStep: String?
    /// The loudness of the export just made, while it is news.
    public var exportResult: String?

    public init(saveError: String? = nil, audioError: String? = nil, documentError: String? = nil,
                notice: String? = nil, learning: String? = nil, exportStep: String? = nil,
                exportResult: String? = nil) {
        self.saveError = saveError
        self.audioError = audioError
        self.documentError = documentError
        self.notice = notice
        self.learning = learning
        self.exportStep = exportStep
        self.exportResult = exportResult
    }

    /// What VoiceOver says when the strip goes from `old` to `new`, or nil: a problem as soon as it
    /// stands, urgently; an export when it starts and how it ended, never each step between (a long
    /// stem export would talk over the music); a line that stays as it was, never again.
    public static func announcement(from old: StatusStrip, to new: StatusStrip) -> Announcement? {
        var parts: [Announcement] = []
        func arrived(_ text: String?, after previous: String?, _ priority: Announcement.Priority) {
            guard let text, text != previous else { return }
            parts.append(Announcement(text, priority: priority))
        }
        arrived(new.saveError, after: old.saveError, .urgent)
        arrived(new.audioError, after: old.audioError, .urgent)
        if old.exportStep != nil, new.exportStep == nil {
            // How the export ended. Its message is said even in the words the line already had: a
            // second failure for the same reason is news, though the strip reads as it did.
            if let problem = new.documentError {
                parts.append(Announcement(problem, priority: .urgent))
            } else if let result = new.exportResult {
                parts.append(Announcement(result, priority: .queued))
            }
        } else {
            arrived(new.documentError, after: old.documentError, .urgent)
        }
        if old.exportStep == nil, let step = new.exportStep {
            parts.append(Announcement(step, priority: .normal))
        }
        arrived(new.notice, after: old.notice, .normal)
        arrived(new.learning, after: old.learning, .queued)
        return Announcement.joined(parts)
    }
}
