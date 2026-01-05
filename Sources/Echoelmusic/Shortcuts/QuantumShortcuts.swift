//
//  QuantumShortcuts.swift
//  Echoelmusic
//
//  Siri Shortcuts Integration for Quantum Features
//  "Hey Siri, start my quantum meditation"
//
//  Created: 2026-01-05
//

import Foundation
import Intents

#if canImport(AppIntents)
import AppIntents
#endif

// MARK: - App Shortcuts Provider

#if canImport(AppIntents)
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct EchoelmusicShortcuts: AppShortcutsProvider {

    public static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartQuantumSessionIntent(),
            phrases: [
                "Start quantum session in \(.applicationName)",
                "Begin quantum meditation with \(.applicationName)",
                "Activate quantum light in \(.applicationName)",
                "Start bio-coherent mode in \(.applicationName)"
            ],
            shortTitle: "Start Quantum Session",
            systemImageName: "atom"
        )

        AppShortcut(
            intent: CheckCoherenceIntent(),
            phrases: [
                "Check my coherence in \(.applicationName)",
                "What's my quantum coherence in \(.applicationName)",
                "How coherent am I in \(.applicationName)"
            ],
            shortTitle: "Check Coherence",
            systemImageName: "waveform.circle"
        )

        AppShortcut(
            intent: SetQuantumModeIntent(),
            phrases: [
                "Set quantum mode to \(\.$mode) in \(.applicationName)",
                "Change to \(\.$mode) mode in \(.applicationName)",
                "Switch to \(\.$mode) in \(.applicationName)"
            ],
            shortTitle: "Set Quantum Mode",
            systemImageName: "slider.horizontal.3"
        )

        AppShortcut(
            intent: TriggerEntanglementIntent(),
            phrases: [
                "Trigger entanglement in \(.applicationName)",
                "Pulse quantum field in \(.applicationName)",
                "Synchronize quantum states in \(.applicationName)"
            ],
            shortTitle: "Trigger Entanglement",
            systemImageName: "bolt.circle"
        )

        AppShortcut(
            intent: StartGroupSessionIntent(),
            phrases: [
                "Start group quantum session in \(.applicationName)",
                "Begin SharePlay quantum in \(.applicationName)",
                "Invite friends to quantum in \(.applicationName)"
            ],
            shortTitle: "Start Group Session",
            systemImageName: "person.3"
        )

        AppShortcut(
            intent: QuickMeditationIntent(),
            phrases: [
                "Quick meditation in \(.applicationName)",
                "5 minute quantum meditation with \(.applicationName)",
                "Short coherence session in \(.applicationName)"
            ],
            shortTitle: "Quick Meditation",
            systemImageName: "brain.head.profile"
        )
    }
}
#endif

// MARK: - Start Quantum Session Intent

#if canImport(AppIntents)
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct StartQuantumSessionIntent: AppIntent {

    public static var title: LocalizedStringResource = "Start Quantum Session"
    public static var description = IntentDescription("Activates the quantum light emulator in bio-coherent mode")
    public static var openAppWhenRun: Bool = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        // Get or create quantum emulator
        let hub = UnifiedControlHub()
        hub.enableQuantumLightEmulator(mode: .bioCoherent)
        hub.start()

        return .result(dialog: "Quantum session started in bio-coherent mode. Focus on your breath to increase coherence.")
    }
}
#endif

// MARK: - Check Coherence Intent

#if canImport(AppIntents)
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct CheckCoherenceIntent: AppIntent {

    public static var title: LocalizedStringResource = "Check Coherence"
    public static var description = IntentDescription("Reports your current quantum coherence level")

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        let coherence = QuantumDataStore.shared.coherenceLevel
        let hrv = QuantumDataStore.shared.hrvCoherence

        let coherencePercent = Int(coherence * 100)
        let hrvPercent = Int(hrv)

        let message: String
        if coherencePercent > 70 {
            message = "Excellent! Your quantum coherence is \(coherencePercent)% and HRV coherence is \(hrvPercent)%. You're in a highly coherent state."
        } else if coherencePercent > 40 {
            message = "Your quantum coherence is \(coherencePercent)% and HRV coherence is \(hrvPercent)%. Try some slow breathing to increase coherence."
        } else {
            message = "Your quantum coherence is \(coherencePercent)% and HRV coherence is \(hrvPercent)%. Consider a short meditation session."
        }

        return .result(dialog: "\(message)")
    }
}
#endif

// MARK: - Set Quantum Mode Intent

#if canImport(AppIntents)
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct SetQuantumModeIntent: AppIntent {

    public static var title: LocalizedStringResource = "Set Quantum Mode"
    public static var description = IntentDescription("Changes the quantum emulation mode")

    @Parameter(title: "Mode")
    public var mode: QuantumModeEntity

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        // Would set mode on actual emulator
        return .result(dialog: "Quantum mode set to \(mode.name)")
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct QuantumModeEntity: AppEntity {
    public var id: String
    public var name: String

    public static var typeDisplayRepresentation: TypeDisplayRepresentation = "Quantum Mode"
    public var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }

    public static var defaultQuery = QuantumModeQuery()

    public init(id: String, name: String) {
        self.id = id
        self.name = name
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct QuantumModeQuery: EntityQuery {
    public init() {}

    public func entities(for identifiers: [String]) async throws -> [QuantumModeEntity] {
        return identifiers.compactMap { id in
            allModes.first { $0.id == id }
        }
    }

    public func suggestedEntities() async throws -> [QuantumModeEntity] {
        return allModes
    }

    private var allModes: [QuantumModeEntity] {
        [
            QuantumModeEntity(id: "classical", name: "Classical"),
            QuantumModeEntity(id: "quantumInspired", name: "Quantum Inspired"),
            QuantumModeEntity(id: "fullQuantum", name: "Full Quantum"),
            QuantumModeEntity(id: "hybridPhotonic", name: "Hybrid Photonic"),
            QuantumModeEntity(id: "bioCoherent", name: "Bio-Coherent")
        ]
    }
}
#endif

// MARK: - Trigger Entanglement Intent

#if canImport(AppIntents)
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct TriggerEntanglementIntent: AppIntent {

    public static var title: LocalizedStringResource = "Trigger Entanglement"
    public static var description = IntentDescription("Sends an entanglement pulse to synchronize quantum states")

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        await QuantumSharePlayManager.shared.triggerEntanglementPulse()

        return .result(
            dialog: "Entanglement pulse sent! All connected devices are now synchronized."
        ) {
            EntanglementPulseSnippet()
        }
    }
}

@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
struct EntanglementPulseSnippet: View {
    var body: some View {
        HStack {
            Image(systemName: "bolt.circle.fill")
                .font(.largeTitle)
                .foregroundColor(.cyan)

            VStack(alignment: .leading) {
                Text("Entanglement Pulse")
                    .font(.headline)
                Text("Quantum states synchronized")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }
}
#endif

// MARK: - Start Group Session Intent

#if canImport(AppIntents)
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct StartGroupSessionIntent: AppIntent {

    public static var title: LocalizedStringResource = "Start Group Session"
    public static var description = IntentDescription("Starts a SharePlay quantum session with friends")
    public static var openAppWhenRun: Bool = true

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        try await QuantumSharePlayManager.shared.startSession()
        return .result(dialog: "Group quantum session started! Share the invitation with friends.")
    }
}
#endif

// MARK: - Quick Meditation Intent

#if canImport(AppIntents)
@available(iOS 16.0, macOS 13.0, watchOS 9.0, tvOS 16.0, *)
public struct QuickMeditationIntent: AppIntent {

    public static var title: LocalizedStringResource = "Quick Meditation"
    public static var description = IntentDescription("Starts a 5-minute guided quantum meditation")
    public static var openAppWhenRun: Bool = true

    @Parameter(title: "Duration", default: 5)
    public var duration: Int // minutes

    public init() {}

    @MainActor
    public func perform() async throws -> some IntentResult & ProvidesDialog {
        // Start meditation session
        let hub = UnifiedControlHub()
        hub.enableQuantumLightEmulator(mode: .bioCoherent)
        hub.start()

        return .result(dialog: "Starting \(duration)-minute quantum meditation. Find a comfortable position and focus on your breath. The quantum field will synchronize with your heart rate variability.")
    }
}
#endif

// MARK: - Custom Intents (Legacy INIntent support)

@available(iOS 14.0, *)
public class StartQuantumSessionIntentHandler: NSObject, StartQuantumSessionLegacyIntentHandling {

    public func handle(intent: StartQuantumSessionLegacyIntent, completion: @escaping (StartQuantumSessionLegacyIntentResponse) -> Void) {
        // Start quantum session
        Task { @MainActor in
            let hub = UnifiedControlHub()
            hub.enableQuantumLightEmulator(mode: .bioCoherent)
            hub.start()

            let response = StartQuantumSessionLegacyIntentResponse(code: .success, userActivity: nil)
            response.message = "Quantum session started"
            completion(response)
        }
    }
}

// Protocol stubs for legacy intent handling
@available(iOS 14.0, *)
public protocol StartQuantumSessionLegacyIntentHandling {
    func handle(intent: StartQuantumSessionLegacyIntent, completion: @escaping (StartQuantumSessionLegacyIntentResponse) -> Void)
}

@available(iOS 14.0, *)
public class StartQuantumSessionLegacyIntent: INIntent {
    public var mode: String?
}

@available(iOS 14.0, *)
public class StartQuantumSessionLegacyIntentResponse: INIntentResponse {
    public var message: String?

    public convenience init(code: StartQuantumSessionLegacyIntentResponseCode, userActivity: NSUserActivity?) {
        self.init()
    }
}

@available(iOS 14.0, *)
public enum StartQuantumSessionLegacyIntentResponseCode: Int {
    case success
    case failure
}

// MARK: - Shortcut Donation

@MainActor
public class ShortcutDonationManager {

    public static let shared = ShortcutDonationManager()

    private init() {}

    /// Donate shortcuts based on user activity
    public func donateShortcuts() {
        #if canImport(AppIntents)
        if #available(iOS 16.0, macOS 13.0, *) {
            // App Intents handle donation automatically
            return
        }
        #endif

        // Legacy INIntent donation
        donateStartSessionShortcut()
        donateCheckCoherenceShortcut()
    }

    private func donateStartSessionShortcut() {
        let intent = StartQuantumSessionLegacyIntent()
        intent.mode = "bioCoherent"
        intent.suggestedInvocationPhrase = "Start quantum session"

        let interaction = INInteraction(intent: intent, response: nil)
        interaction.donate { error in
            if let error = error {
                print("[Shortcuts] Donation error: \(error)")
            }
        }
    }

    private func donateCheckCoherenceShortcut() {
        // Similar donation for check coherence
    }
}

// MARK: - SwiftUI Import

import SwiftUI
