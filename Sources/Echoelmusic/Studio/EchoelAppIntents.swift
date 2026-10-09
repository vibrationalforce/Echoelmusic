#if canImport(AppIntents)
import AppIntents
import Foundation

/// Siri / Shortcuts / Spotlight entry points. The App Intents framework is iOS
/// 16+, comfortably under the app's iOS 18 floor, so no availability gating is
/// needed. Each intent opens the app and deposits a request in a shared App-Group
/// inbox; `EchoelStudioView` consumes it when it next becomes active and routes
/// it to the exact same handler the on-screen button uses (start/stop/keep loop).
/// Intents stay deliberately thin — they don't touch the audio engine directly,
/// so there is no cross-process audio-thread or actor-isolation hazard.

/// The action a Siri/Shortcuts request asks the app to perform.
enum EchoelIntentAction: String {
    case start
    case stop
    case keepLoop
}

/// Tiny cross-process mailbox in the shared App Group. The intent (which may run
/// out of process) posts; the app takes (read-once) on activation.
enum EchoelIntentInbox {
    private static let key = "pendingIntentAction"
    private static var defaults: UserDefaults? { UserDefaults(suiteName: AppGroupStore.appGroupID) }

    static func post(_ action: EchoelIntentAction) {
        defaults?.set(action.rawValue, forKey: key)
    }

    /// Read and clear the pending action (so it fires exactly once).
    static func take() -> EchoelIntentAction? {
        guard let d = defaults, let raw = d.string(forKey: key) else { return nil }
        d.removeObject(forKey: key)
        return EchoelIntentAction(rawValue: raw)
    }
}

struct StartEchoelSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Start Echoelmusic"
    static let description = IntentDescription(
        "Start the instrument and the pulse reading — your body begins making music.")
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        EchoelIntentInbox.post(.start)
        return .result()
    }
}

struct StopEchoelSessionIntent: AppIntent {
    static let title: LocalizedStringResource = "Stop Echoelmusic"
    static let description = IntentDescription("Stop the instrument and the pulse reading.")
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        EchoelIntentInbox.post(.stop)
        return .result()
    }
}

struct KeepLastLoopIntent: AppIntent {
    static let title: LocalizedStringResource = "Keep Last Loop"
    static let description = IntentDescription(
        "Capture the loop you just played from the always-on buffer.")
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        EchoelIntentInbox.post(.keepLoop)
        return .result()
    }
}

// MARK: - Agent requests (GMMW AI-1)
//
// ⭐ TYPED, NOT UNDERSTOOD. Each intent below names ONE registered command and fills its arguments
// from typed parameters — no model, no keyword matching. It posts `EchoelProposedAction` data to the
// agent's mailbox (`EchoelAgentInbox`); the app's ONE executor plans it through `EchoelPlanning.plan`
// and runs it through the same paths the buttons use (`EchoelAgentDesk`). The outcome — done,
// refused, too old — shows in the app's notice row with an Undo (`AgentReportBanner`).
// ⚠️ An intent grants nothing: no consent is written here, and a command that needs one is refused.
// ⚠️ The intent asks the desk to run the request at once, because with `openAppWhenRun` it runs in
// the app's own process, possibly after the app became active — the mailbox alone would then wait
// for the NEXT activation. Before the app's startup bound the executor, the call is a no-op and the
// startup takes the request instead.
// NEEDS-FOUNDER-VERIFY (device, AI-1): with a track selected, say "Change the track level in
// Echoelmusic" → Siri asks for the decibels → the app opens, the track moves, and the notice row
// says what changed with an Undo that takes it back. "Copy the selected part in Echoelmusic" → one
// copy. With nothing selected → the notice says to select one. A locked phone unlocked within two
// minutes runs the request; later, the notice says it waited too long and nothing changed.

/// Make the selected track louder or quieter by a number of decibels.
struct ChangeSelectedTrackLevelIntent: AppIntent {
    static let title: LocalizedStringResource = "Change Track Level"
    static let description = IntentDescription(
        "Makes the selected track louder or quieter by a number of decibels. Echoel shows what it changed and can undo it.")
    static let openAppWhenRun: Bool = true

    @Parameter(title: "Change in decibels",
               description: "Negative makes the track quieter, positive makes it louder.")
    var decibels: Double

    func perform() async throws -> some IntentResult {
        EchoelAgentInbox.post(
            request: "Change the selected track's level by \(decibels) dB",
            actions: [EchoelProposedAction(command: EchoelCommandID.setTrackLevel.rawValue,
                                           arguments: ["track": "selected", "decibels": String(decibels),
                                                       "mode": "relative"])],
            now: Date())
        await EchoelAgentDesk.shared.runPending(now: Date())
        return .result()
    }
}

/// Copy the selected part to right after itself.
struct CopySelectedPartIntent: AppIntent {
    static let title: LocalizedStringResource = "Copy Selected Part"
    static let description = IntentDescription(
        "Copies the selected part to right after itself on the same track. Echoel can undo it.")
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        EchoelAgentInbox.post(
            request: "Copy the selected part",
            actions: [EchoelProposedAction(command: EchoelCommandID.duplicatePart.rawValue,
                                           arguments: ["part": "selected"])],
            now: Date())
        await EchoelAgentDesk.shared.runPending(now: Date())
        return .result()
    }
}

/// Undo the last change Echoel made for a request — only where nobody changed it since.
struct UndoEchoelChangeIntent: AppIntent {
    static let title: LocalizedStringResource = "Undo Echoel's Last Change"
    static let description = IntentDescription(
        "Undoes the last change Echoel made for you. A value you changed yourself since is kept.")
    static let openAppWhenRun: Bool = true

    func perform() async throws -> some IntentResult {
        EchoelAgentInbox.post(
            request: "Undo Echoel's last change",
            actions: [EchoelProposedAction(command: EchoelCommandID.undoAgentChange.rawValue, arguments: [:])],
            now: Date())
        await EchoelAgentDesk.shared.runPending(now: Date())
        return .result()
    }
}

/// Surfaces the intents to Siri, Spotlight and the Shortcuts app with spoken
/// phrases. `\(.applicationName)` resolves to the app's display name.
struct EchoelAppShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartEchoelSessionIntent(),
            phrases: [
                "Start \(.applicationName)",
                "Start playing in \(.applicationName)",
                "Make music with my body in \(.applicationName)"
            ],
            shortTitle: "Start playing",
            systemImageName: "waveform.path.ecg")
        AppShortcut(
            intent: StopEchoelSessionIntent(),
            phrases: [
                "Stop \(.applicationName)",
                "Stop playing in \(.applicationName)"
            ],
            shortTitle: "Stop playing",
            systemImageName: "stop.circle.fill")
        AppShortcut(
            intent: KeepLastLoopIntent(),
            phrases: [
                "Keep the last loop in \(.applicationName)",
                "Save that loop in \(.applicationName)"
            ],
            shortTitle: "Keep Last Loop",
            systemImageName: "scissors")
        AppShortcut(
            intent: ChangeSelectedTrackLevelIntent(),
            phrases: [
                "Change the track level in \(.applicationName)",
                "Change the selected track's level in \(.applicationName)"
            ],
            shortTitle: "Change Track Level",
            systemImageName: "slider.horizontal.3")
        AppShortcut(
            intent: CopySelectedPartIntent(),
            phrases: [
                "Copy the selected part in \(.applicationName)",
                "Copy this part in \(.applicationName)"
            ],
            shortTitle: "Copy Selected Part",
            systemImageName: "plus.square.on.square")
        AppShortcut(
            intent: UndoEchoelChangeIntent(),
            phrases: [
                "Undo the last change in \(.applicationName)",
                "Undo your last change in \(.applicationName)"
            ],
            shortTitle: "Undo Echoel's Change",
            systemImageName: "arrow.uturn.backward")
    }
}
#endif
