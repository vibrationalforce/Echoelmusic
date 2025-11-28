//
//  UndoRedoSystem.swift
//  Echoelmusic
//
//  Created: 2025-11-28
//  Professional Undo/Redo System for Video & Audio Editing
//
//  Features:
//  - Command pattern for all edits
//  - Unlimited undo/redo stack
//  - Grouped operations (transactions)
//  - State snapshots for complex operations
//  - Memory-efficient history management
//

import Foundation
import Combine

// MARK: - Edit Command Protocol

/// Protocol for all undoable commands
public protocol EditCommand {
    /// Unique identifier for this command
    var id: UUID { get }

    /// Human-readable description for UI
    var description: String { get }

    /// Timestamp when command was executed
    var timestamp: Date { get }

    /// Execute the command (do/redo)
    func execute() throws

    /// Reverse the command (undo)
    func undo() throws

    /// Whether this command can be merged with another
    func canMerge(with other: EditCommand) -> Bool

    /// Merge with another command (for coalescing rapid changes)
    func merge(with other: EditCommand) -> EditCommand?
}

// MARK: - Edit History

/// Manages undo/redo history with unlimited stack
@MainActor
public final class EditHistory: ObservableObject {
    // MARK: - Published State

    @Published public private(set) var canUndo: Bool = false
    @Published public private(set) var canRedo: Bool = false
    @Published public private(set) var undoDescription: String = ""
    @Published public private(set) var redoDescription: String = ""
    @Published public private(set) var isDirty: Bool = false

    // MARK: - Private State

    private var undoStack: [EditCommand] = []
    private var redoStack: [EditCommand] = []
    private var currentTransaction: EditTransaction?
    private var savePoint: Int = 0
    private let maxHistorySize: Int

    // MARK: - Initialization

    public init(maxHistorySize: Int = 1000) {
        self.maxHistorySize = maxHistorySize
    }

    // MARK: - Command Execution

    /// Execute a command and add to history
    public func execute(_ command: EditCommand) throws {
        try command.execute()

        // If in a transaction, add to transaction
        if let transaction = currentTransaction {
            transaction.addCommand(command)
        } else {
            // Try to merge with last command
            if let lastCommand = undoStack.last,
               lastCommand.canMerge(with: command),
               let merged = lastCommand.merge(with: command) {
                undoStack.removeLast()
                undoStack.append(merged)
            } else {
                undoStack.append(command)
            }

            // Clear redo stack when new command is executed
            redoStack.removeAll()

            // Trim history if too large
            trimHistory()
        }

        updateState()
    }

    /// Undo last command
    public func undo() throws {
        guard let command = undoStack.popLast() else { return }

        try command.undo()
        redoStack.append(command)
        updateState()
    }

    /// Redo last undone command
    public func redo() throws {
        guard let command = redoStack.popLast() else { return }

        try command.execute()
        undoStack.append(command)
        updateState()
    }

    /// Undo multiple commands
    public func undo(count: Int) throws {
        for _ in 0..<min(count, undoStack.count) {
            try undo()
        }
    }

    /// Redo multiple commands
    public func redo(count: Int) throws {
        for _ in 0..<min(count, redoStack.count) {
            try redo()
        }
    }

    // MARK: - Transactions

    /// Begin a transaction (groups multiple commands as one undo)
    public func beginTransaction(description: String) {
        currentTransaction = EditTransaction(description: description)
    }

    /// End current transaction
    public func endTransaction() throws {
        guard let transaction = currentTransaction else { return }
        currentTransaction = nil

        if !transaction.commands.isEmpty {
            undoStack.append(transaction)
            redoStack.removeAll()
            trimHistory()
        }

        updateState()
    }

    /// Cancel current transaction (undo all commands in it)
    public func cancelTransaction() throws {
        guard let transaction = currentTransaction else { return }
        currentTransaction = nil

        // Undo all commands in reverse order
        for command in transaction.commands.reversed() {
            try command.undo()
        }

        updateState()
    }

    // MARK: - Save Points

    /// Mark current state as saved (dirty flag resets)
    public func markSaved() {
        savePoint = undoStack.count
        isDirty = false
    }

    // MARK: - History Management

    /// Clear all history
    public func clearHistory() {
        undoStack.removeAll()
        redoStack.removeAll()
        savePoint = 0
        updateState()
    }

    /// Get recent history for display
    public func getRecentHistory(count: Int = 10) -> [EditCommand] {
        Array(undoStack.suffix(count).reversed())
    }

    /// Get available redos
    public func getAvailableRedos(count: Int = 10) -> [EditCommand] {
        Array(redoStack.suffix(count).reversed())
    }

    // MARK: - Private Methods

    private func updateState() {
        canUndo = !undoStack.isEmpty
        canRedo = !redoStack.isEmpty
        undoDescription = undoStack.last?.description ?? ""
        redoDescription = redoStack.last?.description ?? ""
        isDirty = undoStack.count != savePoint
    }

    private func trimHistory() {
        while undoStack.count > maxHistorySize {
            undoStack.removeFirst()
            if savePoint > 0 { savePoint -= 1 }
        }
    }
}

// MARK: - Edit Transaction

/// Groups multiple commands as a single undo operation
public final class EditTransaction: EditCommand {
    public let id: UUID
    public let description: String
    public let timestamp: Date
    public private(set) var commands: [EditCommand] = []

    public init(description: String) {
        self.id = UUID()
        self.description = description
        self.timestamp = Date()
    }

    public func addCommand(_ command: EditCommand) {
        commands.append(command)
    }

    public func execute() throws {
        for command in commands {
            try command.execute()
        }
    }

    public func undo() throws {
        for command in commands.reversed() {
            try command.undo()
        }
    }

    public func canMerge(with other: EditCommand) -> Bool {
        false  // Transactions don't merge
    }

    public func merge(with other: EditCommand) -> EditCommand? {
        nil
    }
}

// MARK: - Video Edit Commands

/// Clip move command
public struct MoveClipCommand: EditCommand {
    public let id = UUID()
    public let timestamp = Date()
    public let description: String

    private let clipId: UUID
    private let oldTrackIndex: Int
    private let newTrackIndex: Int
    private let oldStartTime: Double
    private let newStartTime: Double
    private weak var editor: VideoEditController?

    public init(editor: VideoEditController, clipId: UUID, from oldTrack: Int, to newTrack: Int, fromTime: Double, toTime: Double) {
        self.editor = editor
        self.clipId = clipId
        self.oldTrackIndex = oldTrack
        self.newTrackIndex = newTrack
        self.oldStartTime = fromTime
        self.newStartTime = toTime
        self.description = "Move Clip"
    }

    public func execute() throws {
        editor?.moveClip(clipId, toTrack: newTrackIndex, atTime: newStartTime)
    }

    public func undo() throws {
        editor?.moveClip(clipId, toTrack: oldTrackIndex, atTime: oldStartTime)
    }

    public func canMerge(with other: EditCommand) -> Bool {
        guard let otherMove = other as? MoveClipCommand else { return false }
        return otherMove.clipId == clipId &&
               Date().timeIntervalSince(otherMove.timestamp) < 0.5  // Within 500ms
    }

    public func merge(with other: EditCommand) -> EditCommand? {
        guard let otherMove = other as? MoveClipCommand,
              otherMove.clipId == clipId else { return nil }

        return MoveClipCommand(
            editor: editor!,
            clipId: clipId,
            from: oldTrackIndex,
            to: otherMove.newTrackIndex,
            fromTime: oldStartTime,
            toTime: otherMove.newStartTime
        )
    }
}

/// Clip trim command
public struct TrimClipCommand: EditCommand {
    public let id = UUID()
    public let timestamp = Date()
    public let description: String

    private let clipId: UUID
    private let oldInPoint: Double
    private let oldOutPoint: Double
    private let newInPoint: Double
    private let newOutPoint: Double
    private weak var editor: VideoEditController?

    public init(editor: VideoEditController, clipId: UUID, oldIn: Double, oldOut: Double, newIn: Double, newOut: Double) {
        self.editor = editor
        self.clipId = clipId
        self.oldInPoint = oldIn
        self.oldOutPoint = oldOut
        self.newInPoint = newIn
        self.newOutPoint = newOut
        self.description = "Trim Clip"
    }

    public func execute() throws {
        editor?.trimClip(clipId, inPoint: newInPoint, outPoint: newOutPoint)
    }

    public func undo() throws {
        editor?.trimClip(clipId, inPoint: oldInPoint, outPoint: oldOutPoint)
    }

    public func canMerge(with other: EditCommand) -> Bool {
        guard let otherTrim = other as? TrimClipCommand else { return false }
        return otherTrim.clipId == clipId &&
               Date().timeIntervalSince(otherTrim.timestamp) < 0.3
    }

    public func merge(with other: EditCommand) -> EditCommand? {
        guard let otherTrim = other as? TrimClipCommand,
              otherTrim.clipId == clipId else { return nil }

        return TrimClipCommand(
            editor: editor!,
            clipId: clipId,
            oldIn: oldInPoint,
            oldOut: oldOutPoint,
            newIn: otherTrim.newInPoint,
            newOut: otherTrim.newOutPoint
        )
    }
}

/// Split clip command
public struct SplitClipCommand: EditCommand {
    public let id = UUID()
    public let timestamp = Date()
    public let description = "Split Clip"

    private let clipId: UUID
    private let splitTime: Double
    private var newClipId: UUID?
    private weak var editor: VideoEditController?

    public init(editor: VideoEditController, clipId: UUID, atTime: Double) {
        self.editor = editor
        self.clipId = clipId
        self.splitTime = atTime
    }

    public func execute() throws {
        newClipId = editor?.splitClip(clipId, atTime: splitTime)
    }

    public func undo() throws {
        guard let newId = newClipId else { return }
        editor?.joinClips(clipId, newId)
    }

    public func canMerge(with other: EditCommand) -> Bool { false }
    public func merge(with other: EditCommand) -> EditCommand? { nil }
}

/// Delete clip command
public struct DeleteClipCommand: EditCommand {
    public let id = UUID()
    public let timestamp = Date()
    public let description = "Delete Clip"

    private let clipId: UUID
    private let clipData: Data?  // Serialized clip for undo
    private let trackIndex: Int
    private weak var editor: VideoEditController?

    public init(editor: VideoEditController, clipId: UUID, clipData: Data?, trackIndex: Int) {
        self.editor = editor
        self.clipId = clipId
        self.clipData = clipData
        self.trackIndex = trackIndex
    }

    public func execute() throws {
        editor?.deleteClip(clipId)
    }

    public func undo() throws {
        guard let data = clipData else { return }
        editor?.restoreClip(data, toTrack: trackIndex)
    }

    public func canMerge(with other: EditCommand) -> Bool { false }
    public func merge(with other: EditCommand) -> EditCommand? { nil }
}

/// Add track command
public struct AddTrackCommand: EditCommand {
    public let id = UUID()
    public let timestamp = Date()
    public let description: String

    private let trackType: TrackType
    private var addedTrackId: UUID?
    private weak var editor: VideoEditController?

    public enum TrackType: String {
        case video, audio, subtitle
    }

    public init(editor: VideoEditController, type: TrackType) {
        self.editor = editor
        self.trackType = type
        self.description = "Add \(type.rawValue.capitalized) Track"
    }

    public func execute() throws {
        addedTrackId = editor?.addTrack(type: trackType)
    }

    public func undo() throws {
        guard let trackId = addedTrackId else { return }
        editor?.deleteTrack(trackId)
    }

    public func canMerge(with other: EditCommand) -> Bool { false }
    public func merge(with other: EditCommand) -> EditCommand? { nil }
}

/// Effect change command
public struct EffectChangeCommand: EditCommand {
    public let id = UUID()
    public let timestamp = Date()
    public let description: String

    private let clipId: UUID
    private let effectId: UUID
    private let parameterName: String
    private let oldValue: Float
    private let newValue: Float
    private weak var editor: VideoEditController?

    public init(editor: VideoEditController, clipId: UUID, effectId: UUID, parameter: String, oldValue: Float, newValue: Float) {
        self.editor = editor
        self.clipId = clipId
        self.effectId = effectId
        self.parameterName = parameter
        self.oldValue = oldValue
        self.newValue = newValue
        self.description = "Adjust \(parameter)"
    }

    public func execute() throws {
        editor?.setEffectParameter(clipId: clipId, effectId: effectId, parameter: parameterName, value: newValue)
    }

    public func undo() throws {
        editor?.setEffectParameter(clipId: clipId, effectId: effectId, parameter: parameterName, value: oldValue)
    }

    public func canMerge(with other: EditCommand) -> Bool {
        guard let otherEffect = other as? EffectChangeCommand else { return false }
        return otherEffect.clipId == clipId &&
               otherEffect.effectId == effectId &&
               otherEffect.parameterName == parameterName &&
               Date().timeIntervalSince(otherEffect.timestamp) < 0.2
    }

    public func merge(with other: EditCommand) -> EditCommand? {
        guard let otherEffect = other as? EffectChangeCommand else { return nil }

        return EffectChangeCommand(
            editor: editor!,
            clipId: clipId,
            effectId: effectId,
            parameter: parameterName,
            oldValue: oldValue,
            newValue: otherEffect.newValue
        )
    }
}

// MARK: - Video Edit Controller Protocol

/// Protocol for video editor that supports undo/redo
public protocol VideoEditController: AnyObject {
    func moveClip(_ clipId: UUID, toTrack: Int, atTime: Double)
    func trimClip(_ clipId: UUID, inPoint: Double, outPoint: Double)
    func splitClip(_ clipId: UUID, atTime: Double) -> UUID?
    func joinClips(_ clipId1: UUID, _ clipId2: UUID)
    func deleteClip(_ clipId: UUID)
    func restoreClip(_ data: Data, toTrack: Int)
    func addTrack(type: AddTrackCommand.TrackType) -> UUID?
    func deleteTrack(_ trackId: UUID)
    func setEffectParameter(clipId: UUID, effectId: UUID, parameter: String, value: Float)
}

// MARK: - Keyboard Shortcuts

/// Standard keyboard shortcuts for undo/redo
public struct EditKeyboardShortcuts {
    public static let undo = "⌘Z"
    public static let redo = "⇧⌘Z"
    public static let undoAlt = "⌘Z"
    public static let redoAlt = "⌘Y"

    public static func handleKeyPress(key: String, modifiers: Set<String>, history: EditHistory) {
        Task { @MainActor in
            do {
                if modifiers.contains("command") && key == "z" {
                    if modifiers.contains("shift") {
                        try history.redo()
                    } else {
                        try history.undo()
                    }
                } else if modifiers.contains("command") && key == "y" {
                    try history.redo()
                }
            } catch {
                print("Undo/Redo failed: \(error)")
            }
        }
    }
}
