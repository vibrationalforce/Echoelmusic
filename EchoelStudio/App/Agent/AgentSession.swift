import EchoelCore
import Foundation
import Observation
import os
#if canImport(FoundationModels)
import FoundationModels
#endif

/// One line of the assistant chat.
struct AgentLine: Identifiable, Equatable {
    enum Role: Equatable { case musician, assistant, action, problem }
    let id = UUID()
    let role: Role
    let text: String
}

/// Carries out the assistant's actions on the song: each one through the store, all actions of
/// one request coalesced into ONE undo step, so "Undo Agent" takes the whole request back.
@MainActor
final class AgentExecutor {
    private let store: ProjectStore
    private var turnKey = "agent.0"
    /// The song the request was asked about; a different song opened since is never written.
    private var document = 0
    /// Called with a short sentence for every action that changed the song.
    var onAction: ((String) -> Void)?

    init(store: ProjectStore) {
        self.store = store
    }

    var song: String { AgentTools.describe(store.project) }

    func begin(turn: Int) {
        store.endGesture()
        turnKey = "agent.\(turn)"
        document = store.documentGeneration
    }

    func end() { store.endGesture() }

    /// The tool's answer for the model: what was done, or why not, so it can correct itself.
    func run(_ action: AgentAction, _ summary: String) -> String {
        guard store.documentGeneration == document else {
            return "Not done: the musician opened a different song. Stop and say so."
        }
        do {
            let commands = try AgentTools.commands(for: action, in: store.project)
            try store.perform(commands, title: "Agent", coalescingKey: turnKey)
            onAction?(summary)
            return "Done: \(summary)."
        } catch let error as AgentError {
            return "Not done: \(error.description)"
        } catch {
            return "Not done: \(error)"
        }
    }
}

/// The assistant: the musician writes what they want, the on-device language model answers by
/// calling the tools in `AgentTools`. Nothing leaves the device. On a device that cannot run the
/// model at all (before iOS 26, or not eligible for Apple Intelligence) the menu does not offer
/// the assistant; where the musician can fix it (Apple Intelligence off, model still loading) the
/// page says how and offers nothing else.
@MainActor
@Observable
final class AgentSession {
    enum Availability: Equatable {
        case ready
        case unavailable(String)
    }

    private(set) var lines: [AgentLine] = []
    private(set) var isWorking = false
    private(set) var availability: Availability = .unavailable("Checking…")
    /// Whether this device can ever run the model. A menu leaves the assistant out when it cannot,
    /// rather than opening a page that can only say no.
    private(set) var isOffered = false

    @ObservationIgnored private let executor: AgentExecutor
    @ObservationIgnored private var turn = 0
    /// The model session, held as `AnyObject` so this type exists on iOS 18 too.
    @ObservationIgnored private var backend: AnyObject?
    @ObservationIgnored private let log = Logger(subsystem: "com.echoelmusic.studio", category: "agent")

    init(store: ProjectStore) {
        executor = AgentExecutor(store: store)
        executor.onAction = { [weak self] summary in
            self?.lines.append(AgentLine(role: .action, text: summary))
        }
        refreshAvailability()
    }

    func refreshAvailability() {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let current = SystemLanguageModel.default.availability
            if case .unavailable(.deviceNotEligible) = current { isOffered = false } else { isOffered = true }
            switch current {
            case .available:
                availability = .ready
            case .unavailable(.deviceNotEligible):
                availability = .unavailable("This device cannot run Apple Intelligence, which the assistant needs.")
            case .unavailable(.appleIntelligenceNotEnabled):
                availability = .unavailable("Turn on Apple Intelligence in Settings to use the assistant.")
            case .unavailable(.modelNotReady):
                availability = .unavailable("Apple Intelligence is still getting ready. Try again in a few minutes.")
            case .unavailable:
                availability = .unavailable("The assistant is not available on this device.")
            }
            return
        }
        #endif
        isOffered = false
        availability = .unavailable("The assistant needs iOS 26 with Apple Intelligence.")
    }

    func clear() {
        lines.removeAll()
        backend = nil
    }

    func send(_ request: String) async {
        let text = request.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !isWorking, availability == .ready else { return }
        lines.append(AgentLine(role: .musician, text: text))
        isWorking = true
        turn += 1
        executor.begin(turn: turn)
        defer {
            executor.end()
            isWorking = false
        }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            let prompt = "The song now:\n\(executor.song)\n\nThe musician says: \(text)"
            do {
                let answer = try await model().respond(prompt)
                lines.append(AgentLine(role: .assistant, text: answer))
            } catch let error as LanguageModelSession.GenerationError {
                if case .exceededContextWindowSize = error {
                    // The conversation outgrew the model's window: start over with the song as context.
                    backend = nil
                    lines.append(AgentLine(role: .problem, text: "The conversation got too long, so I started a fresh one. Please ask again."))
                } else {
                    log.error("agent: \(String(describing: error), privacy: .public)")
                    lines.append(AgentLine(role: .problem, text: Self.sentence(for: error)))
                }
            } catch {
                log.error("agent: \(error.localizedDescription, privacy: .public)")
                lines.append(AgentLine(role: .problem, text: "Something went wrong: \(error.localizedDescription)"))
            }
        }
        #endif
    }

    #if canImport(FoundationModels)
    @available(iOS 26.0, *)
    private func model() -> AgentModel {
        if let existing = backend as? AgentModel { return existing }
        let created = AgentModel(executor: executor)
        backend = created
        return created
    }

    @available(iOS 26.0, *)
    private static func sentence(for error: LanguageModelSession.GenerationError) -> String {
        switch error {
        case .guardrailViolation: "I can't help with that request."
        case .unsupportedLanguageOrLocale: "I can't work in this language yet."
        default: "The model could not answer: \(error.localizedDescription)"
        }
    }
    #endif
}

#if canImport(FoundationModels)
/// The on-device model session with the song tools.
@available(iOS 26.0, *)
@MainActor
final class AgentModel {
    private let session: LanguageModelSession

    init(executor: AgentExecutor) {
        let tools: [any Tool] = [
            SetTempoTool(executor: executor), AddTrackTool(executor: executor), RemoveTrackTool(executor: executor),
            RenameTrackTool(executor: executor), SetSoundTool(executor: executor), DrumPatternTool(executor: executor),
            WriteNotesTool(executor: executor), MixTool(executor: executor), EffectTool(executor: executor),
            RepeatClipTool(executor: executor), AutomateTool(executor: executor),
        ]
        session = LanguageModelSession(tools: tools, instructions: Self.instructions)
    }

    func respond(_ prompt: String) async throws -> String {
        try await session.respond(to: prompt).content
    }

    static let instructions = """
    You are the assistant inside Echoel, a music production app. You change the song only by \
    calling tools. Each tool answers "Done" or "Not done" with the reason; after "Not done", fix \
    the arguments and try once more, or tell the musician what is missing. Never say something \
    was done that no tool reported as Done.
    Tracks are named by their name or their number. Positions are bars (bar 1 is the start of the \
    song) and beats inside the bar (beat 1 is the first). A drum pattern is written in 16th-note \
    steps, 16 steps per bar of 4/4: x is a hit, X an accented hit, . a rest. A four-on-the-floor \
    kick is x...x...x...x... and a backbeat snare ....x.......x... . Notes are named like C4 \
    (middle C), F#3 or Bb2; a chord joins notes with +, for example C4+E4+G4.
    Sounds for an instrument track: \(InstrumentPreset.all.map(\.name).joined(separator: ", ")).
    Drums: \(DrumLane.standardKit.map(\.name).joined(separator: ", ")).
    Effects: \(StandardEffect.allCases.map(\.title).joined(separator: ", ")).
    A movement of a parameter over bars (a fade, a filter opening) is the automate tool; values are in \
    the parameter's unit: volume in dB (0 is unity, -144 silence), pan -1 to 1, cutoff in Hz.
    Answer in one or two short sentences, in the language the musician writes in.
    """
}

// MARK: - Tools

@available(iOS 26.0, *)
struct SetTempoTool: Tool {
    let executor: AgentExecutor
    let name = "set_tempo"
    let description = "Sets the song tempo."

    @Generable
    struct Arguments {
        @Guide(description: "Beats per minute, 20 to 999.")
        var bpm: Double
    }

    func call(arguments: Arguments) async throws -> String {
        await executor.run(.setTempo(bpm: arguments.bpm), "tempo \(arguments.bpm) BPM")
    }
}

@available(iOS 26.0, *)
struct AddTrackTool: Tool {
    let executor: AgentExecutor
    let name = "add_track"
    let description = "Adds a track at the end. A drums track comes with an empty one-bar beat."

    @Generable
    struct Arguments {
        @Guide(description: "The track's name, for example Drums, Bass or Pad.")
        var name: String
        @Guide(description: "instrument, drums or audio.")
        var kind: String
        @Guide(description: "For an instrument track: one of the sound names. Leave out otherwise.")
        var sound: String?
    }

    func call(arguments: Arguments) async throws -> String {
        await executor.run(.addTrack(name: arguments.name, kind: arguments.kind, sound: arguments.sound),
                           "added the \(arguments.kind) track \(arguments.name)")
    }
}

@available(iOS 26.0, *)
struct RemoveTrackTool: Tool {
    let executor: AgentExecutor
    let name = "remove_track"
    let description = "Deletes a track with everything on it."

    @Generable
    struct Arguments {
        @Guide(description: "The track's name or number.")
        var track: String
    }

    func call(arguments: Arguments) async throws -> String {
        await executor.run(.removeTrack(track: arguments.track), "removed track \(arguments.track)")
    }
}

@available(iOS 26.0, *)
struct RenameTrackTool: Tool {
    let executor: AgentExecutor
    let name = "rename_track"
    let description = "Gives a track a new name."

    @Generable
    struct Arguments {
        @Guide(description: "The track's current name or number.")
        var track: String
        @Guide(description: "The new name.")
        var name: String
    }

    func call(arguments: Arguments) async throws -> String {
        await executor.run(.renameTrack(track: arguments.track, name: arguments.name),
                           "renamed \(arguments.track) to \(arguments.name)")
    }
}

@available(iOS 26.0, *)
struct SetSoundTool: Tool {
    let executor: AgentExecutor
    let name = "set_sound"
    let description = "Gives an instrument track one of the built-in synth sounds."

    @Generable
    struct Arguments {
        @Guide(description: "The track's name or number.")
        var track: String
        @Guide(description: "One of the sound names.")
        var sound: String
    }

    func call(arguments: Arguments) async throws -> String {
        await executor.run(.setSound(track: arguments.track, sound: arguments.sound),
                           "\(arguments.track) plays \(arguments.sound)")
    }
}

@available(iOS 26.0, *)
struct DrumPatternTool: Tool {
    let executor: AgentExecutor
    let name = "drum_pattern"
    let description = "Writes one drum of a drums track as a 16th-note step pattern. It repeats over the bars and replaces what that drum played there."

    @Generable
    struct Arguments {
        @Guide(description: "The drums track's name or number.")
        var track: String
        @Guide(description: "One drum of the kit, for example Kick, Snare, Closed Hat.")
        var drum: String
        @Guide(description: "Steps: x hit, X accent, . rest. 16 steps are one bar.")
        var steps: String
        @Guide(description: "The first bar, 1 or later. Leave out for bar 1.")
        var bar: Int?
        @Guide(description: "How many bars, 1 to 64. Leave out for 1.")
        var bars: Int?
    }

    func call(arguments: Arguments) async throws -> String {
        await executor.run(.drumPattern(track: arguments.track, drum: arguments.drum, steps: arguments.steps,
                                        bar: arguments.bar ?? 1, bars: arguments.bars ?? 1),
                           "\(arguments.drum) on \(arguments.track): \(arguments.steps)")
    }
}

@available(iOS 26.0, *)
struct WriteNotesTool: Tool {
    let executor: AgentExecutor
    let name = "write_notes"
    let description = "Writes notes into an instrument track's clip at a bar."

    @Generable
    struct Arguments {
        @Guide(description: "The instrument track's name or number.")
        var track: String
        @Guide(description: "Notes separated by commas, each \"pitch beat length\": C4 1 1, E4+G4 2 0.5. Beat starts at 1 and may be fractional; length is in beats.")
        var notes: String
        @Guide(description: "The bar the clip starts at, 1 or later. Leave out for bar 1.")
        var bar: Int?
        @Guide(description: "The clip's length in bars, 1 to 64. Leave out for 1.")
        var bars: Int?
        @Guide(description: "True to clear the clip first.")
        var replace: Bool?
    }

    func call(arguments: Arguments) async throws -> String {
        await executor.run(.writeNotes(track: arguments.track, notes: arguments.notes, bar: arguments.bar ?? 1,
                                       bars: arguments.bars ?? 1, replace: arguments.replace ?? false),
                           "notes on \(arguments.track): \(arguments.notes)")
    }
}

@available(iOS 26.0, *)
struct MixTool: Tool {
    let executor: AgentExecutor
    let name = "mix"
    let description = "Sets a track's fader, pan, mute or solo, or the master fader and pan. Leave out what stays."

    @Generable
    struct Arguments {
        @Guide(description: "The track's name or number, or master.")
        var track: String
        @Guide(description: "Fader in dB, at most 6. 0 is unity.")
        var volumeDB: Double?
        @Guide(description: "-1 left to 1 right, 0 centre.")
        var pan: Double?
        var mute: Bool?
        var solo: Bool?
    }

    func call(arguments: Arguments) async throws -> String {
        await executor.run(.mix(track: arguments.track, volumeDB: arguments.volumeDB, pan: arguments.pan,
                                mute: arguments.mute, solo: arguments.solo),
                           "mixed \(arguments.track)")
    }
}
@available(iOS 26.0, *)
struct EffectTool: Tool {
    let executor: AgentExecutor
    let name = "effect"
    let description = "Adds one of the effects to the end of a track's chain, or removes it."

    @Generable
    struct Arguments {
        @Guide(description: "The track's name or number.")
        var track: String
        @Guide(description: "One of the effect names.")
        var effect: String
        @Guide(description: "True to remove the effect instead of adding it.")
        var remove: Bool?
    }

    func call(arguments: Arguments) async throws -> String {
        if arguments.remove == true {
            return await executor.run(.removeEffect(track: arguments.track, effect: arguments.effect),
                                      "removed \(arguments.effect) from \(arguments.track)")
        }
        return await executor.run(.addEffect(track: arguments.track, effect: arguments.effect),
                                  "\(arguments.effect) on \(arguments.track)")
    }
}

@available(iOS 26.0, *)
struct RepeatClipTool: Tool {
    let executor: AgentExecutor
    let name = "repeat_clip"
    let description = "Plays the clip that starts at a bar again and again, back to back, to make a part longer."

    @Generable
    struct Arguments {
        @Guide(description: "The track's name or number.")
        var track: String
        @Guide(description: "The bar the clip starts at. Leave out for bar 1.")
        var bar: Int?
        @Guide(description: "How many more times it plays, 1 to 64.")
        var times: Int
    }

    func call(arguments: Arguments) async throws -> String {
        await executor.run(.repeatClip(track: arguments.track, bar: arguments.bar ?? 1, times: arguments.times),
                           "repeated \(arguments.track) \(arguments.times) times")
    }
}
@available(iOS 26.0, *)
struct AutomateTool: Tool {
    let executor: AgentExecutor
    let name = "automate"
    let description = "Moves a parameter of a track or the master from one value to another between two bars: fades, filter sweeps, pans."

    @Generable
    struct Arguments {
        @Guide(description: "The track's name or number, or master.")
        var track: String
        @Guide(description: "volume, pan, or a synth parameter: cutoff, resonance, filter envelope, attack, decay, sustain, release, level.")
        var parameter: String
        @Guide(description: "The bar the movement starts at.")
        var fromBar: Int
        @Guide(description: "The bar it arrives at, later than fromBar.")
        var toBar: Int
        @Guide(description: "The value at the start, in the parameter's unit.")
        var from: Double
        @Guide(description: "The value at the end, in the parameter's unit.")
        var to: Double
        @Guide(description: "-1 to 1: below 0 moves early, above 0 moves late. Leave out for a straight line.")
        var curve: Double?
    }

    func call(arguments: Arguments) async throws -> String {
        await executor.run(.automate(track: arguments.track, parameter: arguments.parameter, fromBar: arguments.fromBar,
                                     toBar: arguments.toBar, from: arguments.from, to: arguments.to,
                                     curve: arguments.curve ?? 0),
                           "\(arguments.parameter) on \(arguments.track) from \(arguments.from) to \(arguments.to), bars \(arguments.fromBar)–\(arguments.toBar)")
    }
}
#endif
