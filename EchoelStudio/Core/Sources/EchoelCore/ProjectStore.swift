import Observation

/// The one owner of the open project. Every change goes through `perform`, every change is
/// one undo step, and a failed command changes nothing.
///
/// Undo keeps whole-document snapshots. `Project` is made of value types with copy-on-write
/// storage, so a snapshot shares every array it did not change — a fader move copies a few
/// bytes, not the song. Audio data never lives in the document, only references to files.
@MainActor
@Observable
public final class ProjectStore {
    public private(set) var project: Project
    public private(set) var undoStack: [Step] = []
    public private(set) var redoStack: [Step] = []

    /// Counts the documents opened in this store: whoever started work on one song can tell,
    /// before writing, that a different song has been opened since.
    public private(set) var documentGeneration = 0

    /// How many steps undo remembers. The oldest step is dropped beyond it.
    public var undoLimit = 500

    /// The coalescing key of the gesture that is still open (a fader being dragged). Further
    /// performs with the same key extend the last step instead of adding one.
    @ObservationIgnored private var openCoalescingKey: String?

    public struct Step: Equatable, Sendable {
        public let title: String
        public let before: Project
        public let after: Project
    }

    public init(project: Project = Project()) {
        self.project = project
    }

    public var canUndo: Bool { !undoStack.isEmpty }
    public var canRedo: Bool { !redoStack.isEmpty }
    public var undoTitle: String? { undoStack.last?.title }
    public var redoTitle: String? { redoStack.last?.title }

    /// Performs one command as one undo step.
    ///
    /// - Parameter coalescingKey: give a continuous gesture (dragging a fader, a knob) the
    ///   same key on every call and call `endGesture()` when the finger lifts. The whole drag
    ///   then undoes in one step.
    public func perform(_ command: Command, coalescingKey: String? = nil) throws {
        try perform([command], title: CommandCatalog.spec(for: command.kind).title, coalescingKey: coalescingKey)
    }

    /// Performs several commands as ONE undo step, all or nothing. A command that throws
    /// leaves the project exactly as it was — no half-applied edit.
    public func perform(_ commands: [Command], title: String, coalescingKey: String? = nil) throws {
        guard !commands.isEmpty else { return }
        var draft = project
        for command in commands {
            try command.apply(to: &draft)
        }
        guard draft != project else { return }

        if let key = coalescingKey, key == openCoalescingKey, let last = undoStack.last {
            undoStack[undoStack.count - 1] = Step(title: last.title, before: last.before, after: draft)
        } else {
            undoStack.append(Step(title: title, before: project, after: draft))
            if undoStack.count > undoLimit {
                undoStack.removeFirst(undoStack.count - undoLimit)
            }
        }
        openCoalescingKey = coalescingKey
        redoStack.removeAll()
        project = draft
    }

    /// Writes state that is not an edit — the plugins' own settings, captured before a save or an
    /// export — into the song and into every undo and redo step where it applies. Saving then
    /// neither adds a step nor clears redo, and an undo never takes a plugin back to settings it
    /// no longer has. All or nothing on the open song. In a step, each command is written where it
    /// applies and nowhere else: a plugin's settings only where the same plugin sits, never into
    /// the step before a Choose Plugin (review 2026-10-23).
    public func absorb(_ commands: [Command]) throws {
        guard !commands.isEmpty else { return }
        var draft = project
        for command in commands {
            try command.apply(to: &draft)
        }
        guard draft != project else { return }
        let song = draft
        func absorbed(_ snapshot: Project) -> Project {
            var copy = snapshot
            for command in commands where Self.belongs(command, capturedIn: song, to: snapshot) {
                var attempt = copy
                guard (try? command.apply(to: &attempt)) != nil else { continue }
                copy = attempt
            }
            return copy
        }
        undoStack = undoStack.map { Step(title: $0.title, before: absorbed($0.before), after: absorbed($0.after)) }
        redoStack = redoStack.map { Step(title: $0.title, before: absorbed($0.before), after: absorbed($0.after)) }
        project = draft
    }

    /// Whether `command`, captured from the open `song`, belongs in `snapshot`: settings belong
    /// to the plugin they came from, so a step that holds another plugin on that track or insert
    /// keeps its own. Everything else belongs wherever it applies.
    private static func belongs(_ command: Command, capturedIn song: Project, to snapshot: Project) -> Bool {
        switch command {
        case let .setPluginState(track, _):
            guard let now = song.trackIndex(track), let then = snapshot.trackIndex(track) else { return false }
            return song.tracks[now].instrument.plugin == snapshot.tracks[then].instrument.plugin
        case let .setInsertState(track, id, _):
            guard let now = try? song.requireInsert(id, on: track),
                  let then = try? snapshot.requireInsert(id, on: track) else { return false }
            return song.tracks[now.0].inserts[now.1].plugin == snapshot.tracks[then.0].inserts[then.1].plugin
        case let .setMasterInsertState(id, _):
            guard let now = song.masterInserts.first(where: { $0.id == id }),
                  let then = snapshot.masterInserts.first(where: { $0.id == id }) else { return false }
            return now.plugin == then.plugin
        default:
            return true
        }
    }

    /// Closes an open gesture, so the next perform starts a new undo step.
    public func endGesture() {
        openCoalescingKey = nil
    }

    public func undo() {
        guard let step = undoStack.popLast() else { return }
        openCoalescingKey = nil
        project = step.before
        redoStack.append(step)
    }

    public func redo() {
        guard let step = redoStack.popLast() else { return }
        openCoalescingKey = nil
        project = step.after
        undoStack.append(step)
    }

    /// Opens a different project. Undo history belongs to a document and does not carry over.
    public func open(_ project: Project) {
        openCoalescingKey = nil
        undoStack.removeAll()
        redoStack.removeAll()
        documentGeneration += 1
        self.project = project
    }
}
