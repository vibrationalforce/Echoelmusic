//
//  QuantumLiveActivity.swift
//  Echoelmusic
//
//  Live Activities for Quantum Sessions on Lock Screen and Dynamic Island
//  A+++ Real-time quantum coherence tracking
//
//  Created: 2026-01-05
//

import Foundation
import SwiftUI

#if canImport(ActivityKit)
import ActivityKit
#endif

#if canImport(WidgetKit)
import WidgetKit
#endif

// MARK: - Live Activity Attributes

#if canImport(ActivityKit)
@available(iOS 16.1, *)
public struct QuantumSessionAttributes: ActivityAttributes {

    public struct ContentState: Codable, Hashable {
        public var coherenceLevel: Float
        public var hrvCoherence: Float
        public var sessionDuration: TimeInterval
        public var photonCount: Int
        public var isEntangled: Bool
        public var entangledDevices: Int

        public init(
            coherenceLevel: Float = 0.5,
            hrvCoherence: Float = 50,
            sessionDuration: TimeInterval = 0,
            photonCount: Int = 0,
            isEntangled: Bool = false,
            entangledDevices: Int = 0
        ) {
            self.coherenceLevel = coherenceLevel
            self.hrvCoherence = hrvCoherence
            self.sessionDuration = sessionDuration
            self.photonCount = photonCount
            self.isEntangled = isEntangled
            self.entangledDevices = entangledDevices
        }
    }

    public var sessionName: String
    public var sessionMode: String
    public var sessionIcon: String
    public var targetDuration: TimeInterval

    public init(
        sessionName: String,
        sessionMode: String,
        sessionIcon: String = "🌟",
        targetDuration: TimeInterval = 600
    ) {
        self.sessionName = sessionName
        self.sessionMode = sessionMode
        self.sessionIcon = sessionIcon
        self.targetDuration = targetDuration
    }
}

// MARK: - Live Activity Widget

@available(iOS 16.2, *)
public struct QuantumLiveActivityWidget: Widget {
    public init() {}

    public var body: some WidgetConfiguration {
        ActivityConfiguration(for: QuantumSessionAttributes.self) { context in
            // Lock Screen / Banner View
            QuantumLockScreenView(context: context)
        } dynamicIsland: { context in
            DynamicIsland {
                // Expanded leading
                DynamicIslandExpandedRegion(.leading) {
                    VStack(alignment: .leading) {
                        Text(context.attributes.sessionIcon)
                            .font(.title2)

                        Text(context.attributes.sessionMode)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // Expanded trailing
                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing) {
                        Text("\(Int(context.state.coherenceLevel * 100))%")
                            .font(.title2.bold())
                            .foregroundColor(coherenceColor(context.state.coherenceLevel))

                        Text("Coherence")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // Expanded center
                DynamicIslandExpandedRegion(.center) {
                    HStack(spacing: 16) {
                        VStack {
                            Image(systemName: "heart.fill")
                                .foregroundColor(.red)
                            Text("\(Int(context.state.hrvCoherence))%")
                                .font(.caption)
                        }

                        VStack {
                            Image(systemName: "clock")
                                .foregroundColor(.cyan)
                            Text(formatDuration(context.state.sessionDuration))
                                .font(.caption)
                        }

                        if context.state.isEntangled {
                            VStack {
                                Image(systemName: "link")
                                    .foregroundColor(.purple)
                                Text("\(context.state.entangledDevices)")
                                    .font(.caption)
                            }
                        }
                    }
                }

                // Expanded bottom
                DynamicIslandExpandedRegion(.bottom) {
                    HStack {
                        // Progress bar
                        ProgressView(
                            value: context.state.sessionDuration,
                            total: context.attributes.targetDuration
                        )
                        .progressViewStyle(.linear)
                        .tint(coherenceColor(context.state.coherenceLevel))

                        // Action buttons
                        Button {
                            // Deep link to app
                        } label: {
                            Image(systemName: "pause.fill")
                                .padding(8)
                                .background(.ultraThinMaterial)
                                .clipShape(Circle())
                        }
                    }
                }
            } compactLeading: {
                // Compact leading
                HStack(spacing: 4) {
                    Text(context.attributes.sessionIcon)
                    Text("\(Int(context.state.coherenceLevel * 100))")
                        .fontWeight(.bold)
                        .foregroundColor(coherenceColor(context.state.coherenceLevel))
                }
            } compactTrailing: {
                // Compact trailing
                Text(formatDuration(context.state.sessionDuration))
                    .font(.caption.monospacedDigit())
            } minimal: {
                // Minimal view
                ZStack {
                    Circle()
                        .stroke(Color.gray.opacity(0.3), lineWidth: 2)

                    Circle()
                        .trim(from: 0, to: CGFloat(context.state.coherenceLevel))
                        .stroke(coherenceColor(context.state.coherenceLevel), lineWidth: 2)
                        .rotationEffect(.degrees(-90))

                    Text("\(Int(context.state.coherenceLevel * 100))")
                        .font(.system(size: 10, weight: .bold))
                }
            }
        }
    }

    private func coherenceColor(_ coherence: Float) -> Color {
        if coherence > 0.7 { return .green }
        if coherence > 0.4 { return .yellow }
        return .orange
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Lock Screen View

@available(iOS 16.1, *)
struct QuantumLockScreenView: View {
    let context: ActivityViewContext<QuantumSessionAttributes>

    var body: some View {
        HStack(spacing: 16) {
            // Left: Session info
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(context.attributes.sessionIcon)
                    Text(context.attributes.sessionName)
                        .font(.headline)
                }

                Text(context.attributes.sessionMode)
                    .font(.caption)
                    .foregroundColor(.secondary)

                // Timer
                Text(formatDuration(context.state.sessionDuration))
                    .font(.title3.monospacedDigit())
                    .foregroundColor(.cyan)
            }

            Spacer()

            // Center: Stats
            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    StatPill(
                        icon: "heart.fill",
                        value: "\(Int(context.state.hrvCoherence))%",
                        color: .red
                    )

                    StatPill(
                        icon: "sparkles",
                        value: "\(context.state.photonCount)",
                        color: .yellow
                    )

                    if context.state.isEntangled {
                        StatPill(
                            icon: "link",
                            value: "\(context.state.entangledDevices)",
                            color: .purple
                        )
                    }
                }
            }

            Spacer()

            // Right: Coherence gauge
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 6)

                Circle()
                    .trim(from: 0, to: CGFloat(context.state.coherenceLevel))
                    .stroke(
                        AngularGradient(
                            colors: [.red, .yellow, .green],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 6, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Text("\(Int(context.state.coherenceLevel * 100))")
                        .font(.title2.bold())

                    Text("%")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 70, height: 70)
        }
        .padding()
        .background(
            LinearGradient(
                colors: [.purple.opacity(0.3), .blue.opacity(0.2)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

@available(iOS 16.1, *)
struct StatPill: View {
    let icon: String
    let value: String
    let color: Color

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
                .foregroundColor(color)

            Text(value)
                .font(.caption2.bold())
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(color.opacity(0.2))
        .clipShape(Capsule())
    }
}

// MARK: - Live Activity Manager

@available(iOS 16.1, *)
@MainActor
public class QuantumLiveActivityManager: ObservableObject {

    public static let shared = QuantumLiveActivityManager()

    @Published public var currentActivity: Activity<QuantumSessionAttributes>?
    @Published public var isActive: Bool = false

    private var updateTimer: Timer?

    private init() {}

    // MARK: - Start Activity

    public func startSession(
        name: String,
        mode: String,
        icon: String = "🌟",
        targetDuration: TimeInterval = 600
    ) async throws {

        // Check if activities are supported
        guard ActivityAuthorizationInfo().areActivitiesEnabled else {
            echoelLog.info("Live Activities not enabled on this device", category: .ui)
            return
        }

        let attributes = QuantumSessionAttributes(
            sessionName: name,
            sessionMode: mode,
            sessionIcon: icon,
            targetDuration: targetDuration
        )

        let initialState = QuantumSessionAttributes.ContentState(
            coherenceLevel: 0.5,
            hrvCoherence: 50,
            sessionDuration: 0,
            photonCount: 0,
            isEntangled: false,
            entangledDevices: 0
        )

        let content = ActivityContent(state: initialState, staleDate: nil)

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )

            isActive = true
            startUpdateTimer()

            echoelLog.info("Live Activity started: \(name)", category: .ui)

        } catch {
            echoelLog.error("Live Activity failed to start: \(error)", category: .ui)
            throw error
        }
    }

    // MARK: - Update Activity

    public func updateState(
        coherenceLevel: Float,
        hrvCoherence: Float,
        sessionDuration: TimeInterval,
        photonCount: Int = 0,
        isEntangled: Bool = false,
        entangledDevices: Int = 0
    ) async {

        guard let activity = currentActivity else { return }

        let updatedState = QuantumSessionAttributes.ContentState(
            coherenceLevel: coherenceLevel,
            hrvCoherence: hrvCoherence,
            sessionDuration: sessionDuration,
            photonCount: photonCount,
            isEntangled: isEntangled,
            entangledDevices: entangledDevices
        )

        let content = ActivityContent(state: updatedState, staleDate: nil)

        await activity.update(content)
    }

    // MARK: - End Activity

    public func endSession(showSummary: Bool = true) async {
        guard let activity = currentActivity else { return }

        stopUpdateTimer()

        let finalState = activity.content.state

        if showSummary {
            // Show final state for a few seconds
            let content = ActivityContent(state: finalState, staleDate: Date().addingTimeInterval(5))
            await activity.end(content, dismissalPolicy: .after(Date().addingTimeInterval(5)))
        } else {
            await activity.end(nil, dismissalPolicy: .immediate)
        }

        currentActivity = nil
        isActive = false

        echoelLog.info("Live Activity ended", category: .ui)
    }

    // MARK: - Auto Update Timer

    private func startUpdateTimer() {
        updateTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                await self.autoUpdate()
            }
        }
    }

    private func stopUpdateTimer() {
        updateTimer?.invalidate()
        updateTimer = nil
    }

    private func autoUpdate() async {
        guard isActive, let activity = currentActivity else { return }

        let dataStore = QuantumDataStore.shared
        let currentDuration = activity.content.state.sessionDuration + 1

        await updateState(
            coherenceLevel: Float(dataStore.coherenceLevel),
            hrvCoherence: Float(dataStore.hrvCoherence),
            sessionDuration: currentDuration,
            photonCount: Int.random(in: 50...200),
            isEntangled: dataStore.entanglementCount > 0,
            entangledDevices: dataStore.entanglementCount
        )
    }
}

// MARK: - Live Activity Push Notification Support

@available(iOS 16.1, *)
public struct QuantumLiveActivityPushToken {
    public let token: Data

    public var tokenString: String {
        token.map { String(format: "%02x", $0) }.joined()
    }

    public init(token: Data) {
        self.token = token
    }
}

// MARK: - Live Activity Intent (for Shortcuts)

#if canImport(AppIntents)
import AppIntents

@available(iOS 16.2, *)
struct StartLiveActivityIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Quantum Live Activity"
    static var description = IntentDescription("Starts a live activity for the quantum session")

    @Parameter(title: "Session Name")
    var sessionName: String

    @Parameter(title: "Duration (minutes)", default: 10)
    var duration: Int

    init() {
        sessionName = "Quantum Session"
        duration = 10
    }

    @MainActor
    func perform() async throws -> some IntentResult {
        try await QuantumLiveActivityManager.shared.startSession(
            name: sessionName,
            mode: "Bio-Coherent",
            targetDuration: TimeInterval(duration * 60)
        )

        return .result()
    }
}

@available(iOS 16.2, *)
struct EndLiveActivityIntent: AppIntent {
    static var title: LocalizedStringResource = "End Quantum Live Activity"
    static var description = IntentDescription("Ends the current quantum live activity")

    init() {}

    @MainActor
    func perform() async throws -> some IntentResult {
        await QuantumLiveActivityManager.shared.endSession()
        return .result()
    }
}
#endif

#endif

// MARK: - Cross-Platform Stub

#if !canImport(ActivityKit)
@MainActor
public class QuantumLiveActivityManager: ObservableObject {
    public static let shared = QuantumLiveActivityManager()
    @Published public var isActive: Bool = false

    private init() {}

    public func startSession(name: String, mode: String, icon: String = "🌟", targetDuration: TimeInterval = 600) async throws {
        echoelLog.debug("Live Activity not available on this platform", category: .ui)
    }

    public func endSession(showSummary: Bool = true) async {
        echoelLog.debug("Live Activity not available on this platform", category: .ui)
    }
}
#endif
