import Foundation
import Combine
import os.log

// MARK: - Command Protocol
/// Base protocol for all undoable/redoable actions
protocol UndoableCommand {
    /// Human-readable description for UI
    var actionName: String { get }

    /// Execute the action
    func execute()

    /// Reverse the action
    func undo()
}

// MARK: - Undo/Redo Manager
/// Universal Undo/Redo system for Echoelmusic
/// Supports audio editing, video editing, MIDI, and all other operations
@MainActor
final class UndoRedoManager: ObservableObject {

    // MARK: - Singleton
    static let shared = UndoRedoManager()

    // MARK: - Published State
    @Published private(set) var canUndo: Bool = false
    @Published private(set) var canRedo: Bool = false
    @Published private(set) var undoActionName: String = ""
    @Published private(set) var redoActionName: String = ""

    // MARK: - Command Stacks
    private var undoStack: [UndoableCommand] = []
    private var redoStack: [UndoableCommand] = []

    /// Maximum number of undo steps (like Reaper's 32,768)
    private let maxUndoSteps = 1000

    /// Logger
    private let logger = Logger(subsystem: "com.echoelmusic", category: "UndoRedo")

    // MARK: - Initialization
    private init() {}

    // MARK: - Public API

    /// Execute a command and add it to the undo stack
    func execute(_ command: UndoableCommand) {
        command.execute()

        // Add to undo stack
        undoStack.append(command)

        // Clear redo stack (new action invalidates redo history)
        redoStack.removeAll()

        // Limit stack size
        if undoStack.count > maxUndoSteps {
            undoStack.removeFirst()
        }

        updateState()
        logger.debug("✅ Executed: \(command.actionName, privacy: .public)")
    }

    /// Undo the last action
    func undo() {
        guard let command = undoStack.popLast() else { return }

        command.undo()
        redoStack.append(command)

        updateState()
        logger.debug("↩️ Undo: \(command.actionName, privacy: .public)")
    }

    /// Redo the last undone action
    func redo() {
        guard let command = redoStack.popLast() else { return }

        command.execute()
        undoStack.append(command)

        updateState()
        logger.debug("↪️ Redo: \(command.actionName, privacy: .public)")
    }

    /// Clear all history
    func clear() {
        undoStack.removeAll()
        redoStack.removeAll()
        updateState()
    }

    /// Get undo history for UI display
    var undoHistory: [String] {
        undoStack.reversed().map { $0.actionName }
    }

    /// Get redo history for UI display
    var redoHistory: [String] {
        redoStack.reversed().map { $0.actionName }
    }

    // MARK: - Private

    private func updateState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
        undoActionName = undoStack.last?.actionName ?? ""
        redoActionName = redoStack.last?.actionName ?? ""
    }
}

// MARK: - Audio Commands

/// Command for changing track volume
struct TrackVolumeCommand: UndoableCommand {
    let trackID: UUID
    let oldValue: Float
    let newValue: Float
    let applyChange: (UUID, Float) -> Void

    var actionName: String { "Change Track Volume" }

    func execute() {
        applyChange(trackID, newValue)
    }

    func undo() {
        applyChange(trackID, oldValue)
    }
}

/// Command for changing track pan
struct TrackPanCommand: UndoableCommand {
    let trackID: UUID
    let oldValue: Float
    let newValue: Float
    let applyChange: (UUID, Float) -> Void

    var actionName: String { "Change Track Pan" }

    func execute() {
        applyChange(trackID, newValue)
    }

    func undo() {
        applyChange(trackID, oldValue)
    }
}

/// Command for muting/unmuting track
struct TrackMuteCommand: UndoableCommand {
    let trackID: UUID
    let isMuted: Bool
    let applyChange: (UUID, Bool) -> Void

    var actionName: String { isMuted ? "Mute Track" : "Unmute Track" }

    func execute() {
        applyChange(trackID, isMuted)
    }

    func undo() {
        applyChange(trackID, !isMuted)
    }
}

/// Command for adding a track
struct AddTrackCommand: UndoableCommand {
    let track: Track
    let addTrack: (Track) -> Void
    let removeTrack: (UUID) -> Void

    var actionName: String { "Add Track" }

    func execute() {
        addTrack(track)
    }

    func undo() {
        removeTrack(track.id)
    }
}

/// Command for deleting a track
struct DeleteTrackCommand: UndoableCommand {
    let track: Track
    let index: Int
    let addTrack: (Track, Int) -> Void
    let removeTrack: (UUID) -> Void

    var actionName: String { "Delete Track" }

    func execute() {
        removeTrack(track.id)
    }

    func undo() {
        addTrack(track, index)
    }
}

// MARK: - Audio Clip Commands

/// Command for moving an audio clip
struct MoveClipCommand: UndoableCommand {
    let clipID: UUID
    let oldPosition: TimeInterval
    let newPosition: TimeInterval
    let applyChange: (UUID, TimeInterval) -> Void

    var actionName: String { "Move Clip" }

    func execute() {
        applyChange(clipID, newPosition)
    }

    func undo() {
        applyChange(clipID, oldPosition)
    }
}

/// Command for trimming a clip
struct TrimClipCommand: UndoableCommand {
    let clipID: UUID
    let oldStart: TimeInterval
    let oldEnd: TimeInterval
    let newStart: TimeInterval
    let newEnd: TimeInterval
    let applyChange: (UUID, TimeInterval, TimeInterval) -> Void

    var actionName: String { "Trim Clip" }

    func execute() {
        applyChange(clipID, newStart, newEnd)
    }

    func undo() {
        applyChange(clipID, oldStart, oldEnd)
    }
}

/// Command for splitting a clip
struct SplitClipCommand: UndoableCommand {
    let originalClipID: UUID
    let newClipID: UUID
    let splitTime: TimeInterval
    let splitClip: (UUID, TimeInterval) -> UUID
    let mergeClips: (UUID, UUID) -> Void

    var actionName: String { "Split Clip" }

    func execute() {
        _ = splitClip(originalClipID, splitTime)
    }

    func undo() {
        mergeClips(originalClipID, newClipID)
    }
}

// MARK: - Effect Commands

/// Command for adding an effect
struct AddEffectCommand: UndoableCommand {
    let trackID: UUID
    let effectType: String
    let addEffect: (UUID, String) -> Void
    let removeEffect: (UUID, String) -> Void

    var actionName: String { "Add \(effectType)" }

    func execute() {
        addEffect(trackID, effectType)
    }

    func undo() {
        removeEffect(trackID, effectType)
    }
}

/// Command for changing effect parameter
struct EffectParameterCommand: UndoableCommand {
    let effectID: UUID
    let parameterName: String
    let oldValue: Float
    let newValue: Float
    let applyChange: (UUID, String, Float) -> Void

    var actionName: String { "Change \(parameterName)" }

    func execute() {
        applyChange(effectID, parameterName, newValue)
    }

    func undo() {
        applyChange(effectID, parameterName, oldValue)
    }
}

// MARK: - Video Commands

/// Command for video clip operations
struct VideoClipCommand: UndoableCommand {
    enum Operation {
        case add, delete, move, trim, split
    }

    let operation: Operation
    let clipData: Any
    let execute_: () -> Void
    let undo_: () -> Void

    var actionName: String {
        switch operation {
        case .add: return "Add Video Clip"
        case .delete: return "Delete Video Clip"
        case .move: return "Move Video Clip"
        case .trim: return "Trim Video Clip"
        case .split: return "Split Video Clip"
        }
    }

    func execute() {
        execute_()
    }

    func undo() {
        undo_()
    }
}

/// Command for video keyframe changes
struct KeyframeCommand: UndoableCommand {
    let clipID: UUID
    let propertyName: String
    let oldKeyframes: [(time: TimeInterval, value: Float)]
    let newKeyframes: [(time: TimeInterval, value: Float)]
    let applyKeyframes: (UUID, String, [(TimeInterval, Float)]) -> Void

    var actionName: String { "Change \(propertyName) Keyframes" }

    func execute() {
        applyKeyframes(clipID, propertyName, newKeyframes)
    }

    func undo() {
        applyKeyframes(clipID, propertyName, oldKeyframes)
    }
}

// MARK: - MIDI Commands

/// Command for MIDI note operations
struct MIDINoteCommand: UndoableCommand {
    enum Operation {
        case add, delete, move, resize
    }

    let operation: Operation
    let noteID: UUID
    let oldData: (pitch: Int, velocity: Int, start: TimeInterval, duration: TimeInterval)?
    let newData: (pitch: Int, velocity: Int, start: TimeInterval, duration: TimeInterval)?
    let applyChange: (UUID, Int, Int, TimeInterval, TimeInterval) -> Void
    let deleteNote: (UUID) -> Void
    let addNote: (UUID, Int, Int, TimeInterval, TimeInterval) -> Void

    var actionName: String {
        switch operation {
        case .add: return "Add MIDI Note"
        case .delete: return "Delete MIDI Note"
        case .move: return "Move MIDI Note"
        case .resize: return "Resize MIDI Note"
        }
    }

    func execute() {
        switch operation {
        case .add:
            if let data = newData {
                addNote(noteID, data.pitch, data.velocity, data.start, data.duration)
            }
        case .delete:
            deleteNote(noteID)
        case .move, .resize:
            if let data = newData {
                applyChange(noteID, data.pitch, data.velocity, data.start, data.duration)
            }
        }
    }

    func undo() {
        switch operation {
        case .add:
            deleteNote(noteID)
        case .delete:
            if let data = oldData {
                addNote(noteID, data.pitch, data.velocity, data.start, data.duration)
            }
        case .move, .resize:
            if let data = oldData {
                applyChange(noteID, data.pitch, data.velocity, data.start, data.duration)
            }
        }
    }
}

// MARK: - Generic Track Command

/// Generic command for track operations
struct GenericTrackCommand: UndoableCommand {
    let actionName: String
    let trackID: UUID
    let execute_: () -> Void
    let undo_: () -> Void

    func execute() {
        execute_()
    }

    func undo() {
        undo_()
    }

    init(actionName: String, trackID: UUID, execute: @escaping () -> Void, undo: @escaping () -> Void) {
        self.actionName = actionName
        self.trackID = trackID
        self.execute_ = execute
        self.undo_ = undo
    }
}

// MARK: - Compound Command

/// Groups multiple commands into one undoable action
struct CompoundCommand: UndoableCommand {
    let commands: [UndoableCommand]
    let name: String

    var actionName: String { name }

    func execute() {
        commands.forEach { $0.execute() }
    }

    func undo() {
        commands.reversed().forEach { $0.undo() }
    }
}

// MARK: - Batch Undo

extension UndoRedoManager {
    /// Begin a batch operation (groups multiple changes into one undo step)
    func beginBatch(name: String) -> BatchUndoContext {
        BatchUndoContext(manager: self, name: name)
    }
}

/// Context for grouping multiple commands
@MainActor
class BatchUndoContext {
    private let manager: UndoRedoManager
    private let name: String
    private var commands: [UndoableCommand] = []

    init(manager: UndoRedoManager, name: String) {
        self.manager = manager
        self.name = name
    }

    /// Add a command to the batch (executes immediately)
    func add(_ command: UndoableCommand) {
        command.execute()
        commands.append(command)
    }

    /// Commit the batch as a single undo step
    func commit() {
        guard !commands.isEmpty else { return }

        let compound = CompoundCommand(commands: commands, name: name)
        // Add directly to stack without executing (already executed)
        manager.addToUndoStackWithoutExecuting(compound)
    }
}

extension UndoRedoManager {
    fileprivate func addToUndoStackWithoutExecuting(_ command: UndoableCommand) {
        undoStack.append(command)
        redoStack.removeAll()

        if undoStack.count > maxUndoSteps {
            undoStack.removeFirst()
        }

        updateState()
    }
}
