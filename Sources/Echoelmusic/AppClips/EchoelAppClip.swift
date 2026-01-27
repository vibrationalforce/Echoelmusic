// EchoelAppClip.swift
// Echoelmusic - App Clip for Quick Sessions
//
// Allows users to try Echoelmusic instantly without downloading the full app
// Triggered via: NFC tags, QR codes, App Clip Codes, Safari Smart Banners, Maps, Messages
//
// Created: 2026-01-20

// App Clips are only available on iOS and built as a separate target
// This guard prevents compilation conflicts when building other platforms
#if os(iOS) && canImport(AppClip)

import SwiftUI
import AppClip
import CoreLocation
import StoreKit

/// Logger instance for App Clip operations
private let log = EchoelLogger.shared

// MARK: - App Clip Entry Point

/// App Clip main entry - only compiled for App Clip target
// Note: @main is removed here as App Clips use a separate target with its own entry point
// The App Clip target in Xcode will have its own @main attribute
struct EchoelAppClipApp: App {
    @StateObject private var appClipManager = AppClipManager.shared

    var body: some Scene {
        WindowGroup {
            AppClipRootView()
                .environmentObject(appClipManager)
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    appClipManager.handleUserActivity(activity)
                }
        }
    }
}

// MARK: - App Clip Manager

/// Manages App Clip lifecycle and invocation handling
@MainActor
public final class AppClipManager: ObservableObject {

    public static let shared = AppClipManager()

    // MARK: - Published State

    @Published public var invocationURL: URL?
    @Published public var sessionType: QuickSessionType = .breathwork
    @Published public var isSessionActive = false
    @Published public var sessionProgress: Double = 0
    @Published public var remainingTime: TimeInterval = 180 // 3 minutes default
    @Published public var showUpgradePrompt = false
    @Published public var locationConfirmed = false

    // MARK: - Session Types

    public enum QuickSessionType: String, CaseIterable, Identifiable {
        case breathwork = "Atemübung"
        case meditation = "Kurzmeditation"
        case coherence = "Coherence Check"
        case soundBath = "Sound Bath"
        case energize = "Energie-Boost"

        public var id: String { rawValue }

        public var duration: TimeInterval {
            switch self {
            case .breathwork: return 180     // 3 min
            case .meditation: return 300     // 5 min
            case .coherence: return 120      // 2 min
            case .soundBath: return 180      // 3 min
            case .energize: return 90        // 1.5 min
            }
        }

        public var icon: String {
            switch self {
            case .breathwork: return "wind"
            case .meditation: return "brain.head.profile"
            case .coherence: return "heart.fill"
            case .soundBath: return "waveform.path"
            case .energize: return "bolt.fill"
            }
        }

        public var description: String {
            switch self {
            case .breathwork:
                return "Box Breathing für sofortige Entspannung"
            case .meditation:
                return "Geführte Kurzmeditation mit binauralen Beats"
            case .coherence:
                return "Messe deine Herz-Kohärenz in 2 Minuten"
            case .soundBath:
                return "Entspannende Klanglandschaft"
            case .energize:
                return "Schneller Energie-Boost mit aktivierenden Frequenzen"
            }
        }

        public var audioPreset: String {
            switch self {
            case .breathwork: return "BoxBreathing4x4"
            case .meditation: return "AlphaMeditation"
            case .coherence: return "HeartCoherence"
            case .soundBath: return "TibetanBowls"
            case .energize: return "BetaEnergize"
            }
        }
    }

    // MARK: - Invocation Handling

    /// Handle App Clip invocation from URL
    public func handleUserActivity(_ activity: NSUserActivity) {
        guard activity.activityType == NSUserActivityTypeBrowsingWeb,
              let url = activity.webpageURL else {
            return
        }

        invocationURL = url
        parseInvocationURL(url)

        // Verify location if this is a location-based invocation
        if let region = activity.appClipActivationPayload {
            verifyLocation(payload: region)
        }
    }

    /// Parse URL to determine session type
    private func parseInvocationURL(_ url: URL) {
        // URL format: https://echoelmusic.com/clip/[session-type]
        // Examples:
        // - https://echoelmusic.com/clip/breathwork
        // - https://echoelmusic.com/clip/meditation?duration=300
        // - https://echoelmusic.com/clip/event/abc123

        let pathComponents = url.pathComponents

        if pathComponents.contains("breathwork") {
            sessionType = .breathwork
        } else if pathComponents.contains("meditation") {
            sessionType = .meditation
        } else if pathComponents.contains("coherence") {
            sessionType = .coherence
        } else if pathComponents.contains("soundbath") {
            sessionType = .soundBath
        } else if pathComponents.contains("energize") {
            sessionType = .energize
        }

        // Parse duration from query params
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let durationParam = components.queryItems?.first(where: { $0.name == "duration" }),
           let durationValue = durationParam.value,
           let duration = TimeInterval(durationValue) {
            remainingTime = min(duration, 300) // Max 5 min for App Clip
        } else {
            remainingTime = sessionType.duration
        }
    }

    /// Verify location for location-based App Clips
    private func verifyLocation(payload: Any) {
        // App Clips can verify the user is at a specific location
        // This is useful for:
        // - Meditation studios (scan code on entry)
        // - Events/workshops
        // - Partner locations

        guard let activationPayload = payload as? APActivationPayload else {
            locationConfirmed = true // Skip verification if no payload
            return
        }

        activationPayload.confirmAcquired(in: CLCircularRegion(
            center: CLLocationCoordinate2D(latitude: 0, longitude: 0),
            radius: 100,
            identifier: "echoelmusic-venue"
        )) { inRegion, error in
            DispatchQueue.main.async {
                self.locationConfirmed = inRegion || error != nil
            }
        }
    }

    // MARK: - Session Control

    /// Start quick session
    public func startSession() {
        isSessionActive = true
        sessionProgress = 0
        remainingTime = sessionType.duration

        // Start timer
        startSessionTimer()

        // Start audio
        startSessionAudio()
    }

    /// Stop session
    public func stopSession() {
        isSessionActive = false
        sessionProgress = 0
        stopSessionAudio()
    }

    private var sessionTimer: Timer?

    private func startSessionTimer() {
        let totalDuration = sessionType.duration
        sessionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
            guard let self = self else { return }

            Task { @MainActor in
                self.remainingTime -= 1
                self.sessionProgress = 1 - (self.remainingTime / totalDuration)

                if self.remainingTime <= 0 {
                    self.completeSession()
                }
            }
        }
    }

    private func completeSession() {
        sessionTimer?.invalidate()
        sessionTimer = nil
        isSessionActive = false
        sessionProgress = 1

        // Show upgrade prompt after session completes
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
            self.showUpgradePrompt = true
        }
    }

    private func startSessionAudio() {
        // In production: Start audio engine with preset
        log.debug("Starting audio: \(sessionType.audioPreset)", category: .audio)
    }

    private func stopSessionAudio() {
        // In production: Stop audio engine
        log.debug("Stopping audio", category: .audio)
    }

    // MARK: - Full App Promotion

    /// Prompt user to download full app
    public func promptFullAppDownload() {
        // Use SKOverlay to show App Store overlay
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene else {
            return
        }

        let config = SKOverlay.AppClipConfiguration(position: .bottom)
        let overlay = SKOverlay(configuration: config)
        overlay.present(in: windowScene)
    }
}

// MARK: - App Clip Root View

struct AppClipRootView: View {
    @EnvironmentObject var appClipManager: AppClipManager

    var body: some View {
        NavigationStack {
            ZStack {
                // Background gradient
                LinearGradient(
                    colors: [Color.purple.opacity(0.3), Color.blue.opacity(0.2)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()

                VStack(spacing: 24) {
                    // Logo
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 80))
                        .foregroundStyle(.linearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ))

                    Text("Echoelmusic")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Quick Session")
                        .font(.headline)
                        .foregroundColor(.secondary)

                    if appClipManager.isSessionActive {
                        ActiveSessionView()
                    } else {
                        SessionSelectorView()
                    }

                    Spacer()

                    // Full app CTA
                    Button {
                        appClipManager.promptFullAppDownload()
                    } label: {
                        HStack {
                            Image(systemName: "arrow.down.app.fill")
                            Text("Vollversion laden")
                        }
                        .font(.headline)
                        .foregroundColor(.white)
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color.accentColor)
                        .cornerRadius(12)
                    }
                    .padding(.horizontal)
                }
                .padding()
            }
            .sheet(isPresented: $appClipManager.showUpgradePrompt) {
                UpgradePromptView()
            }
        }
    }
}

// MARK: - Session Selector View

struct SessionSelectorView: View {
    @EnvironmentObject var appClipManager: AppClipManager

    var body: some View {
        VStack(spacing: 16) {
            Text("Wähle deine Session")
                .font(.headline)

            ForEach(AppClipManager.QuickSessionType.allCases) { sessionType in
                SessionTypeCard(sessionType: sessionType)
                    .onTapGesture {
                        appClipManager.sessionType = sessionType
                    }
            }

            Button {
                appClipManager.startSession()
            } label: {
                HStack {
                    Image(systemName: "play.fill")
                    Text("Session starten")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.green)
                .cornerRadius(12)
            }
            .padding(.top)
        }
    }
}

struct SessionTypeCard: View {
    let sessionType: AppClipManager.QuickSessionType
    @EnvironmentObject var appClipManager: AppClipManager

    var isSelected: Bool {
        appClipManager.sessionType == sessionType
    }

    var body: some View {
        HStack {
            Image(systemName: sessionType.icon)
                .font(.title2)
                .foregroundColor(isSelected ? .white : .accentColor)
                .frame(width: 44, height: 44)
                .background(isSelected ? Color.accentColor : Color.accentColor.opacity(0.1))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 4) {
                Text(sessionType.rawValue)
                    .font(.headline)
                Text(sessionType.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("\(Int(sessionType.duration / 60)) min")
                .font(.caption)
                .foregroundColor(.secondary)

            if isSelected {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.accentColor)
            }
        }
        .padding()
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemBackground))
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }
}

// MARK: - Active Session View

struct ActiveSessionView: View {
    @EnvironmentObject var appClipManager: AppClipManager

    var body: some View {
        VStack(spacing: 24) {
            // Session type
            HStack {
                Image(systemName: appClipManager.sessionType.icon)
                    .font(.title)
                Text(appClipManager.sessionType.rawValue)
                    .font(.title2)
                    .fontWeight(.semibold)
            }

            // Progress ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)

                Circle()
                    .trim(from: 0, to: appClipManager.sessionProgress)
                    .stroke(
                        LinearGradient(
                            colors: [.purple, .blue],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 1), value: appClipManager.sessionProgress)

                VStack {
                    Text(timeString(from: appClipManager.remainingTime))
                        .font(.system(size: 44, weight: .bold, design: .rounded))
                        .monospacedDigit()

                    Text("verbleibend")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 200, height: 200)

            // Breathing guide (for breathwork sessions)
            if appClipManager.sessionType == .breathwork {
                BreathingGuideView()
            }

            // Stop button
            Button {
                appClipManager.stopSession()
            } label: {
                HStack {
                    Image(systemName: "stop.fill")
                    Text("Beenden")
                }
                .font(.headline)
                .foregroundColor(.white)
                .padding()
                .frame(maxWidth: .infinity)
                .background(Color.red)
                .cornerRadius(12)
            }
        }
        .padding()
    }

    private func timeString(from timeInterval: TimeInterval) -> String {
        let minutes = Int(timeInterval) / 60
        let seconds = Int(timeInterval) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Breathing Guide View

struct BreathingGuideView: View {
    @State private var breathPhase: BreathPhase = .inhale
    @State private var scale: CGFloat = 0.6

    enum BreathPhase: String {
        case inhale = "Einatmen"
        case hold1 = "Halten"
        case exhale = "Ausatmen"
        case hold2 = "Halten"
    }

    var body: some View {
        VStack(spacing: 8) {
            Circle()
                .fill(
                    RadialGradient(
                        colors: [.blue.opacity(0.6), .purple.opacity(0.3)],
                        center: .center,
                        startRadius: 0,
                        endRadius: 50
                    )
                )
                .frame(width: 100, height: 100)
                .scaleEffect(scale)
                .animation(.easeInOut(duration: 4), value: scale)

            Text(breathPhase.rawValue)
                .font(.headline)
                .foregroundColor(.secondary)
        }
        .onAppear {
            startBreathingCycle()
        }
    }

    private func startBreathingCycle() {
        // 4-4-4-4 Box Breathing
        Timer.scheduledTimer(withTimeInterval: 4, repeats: true) { _ in
            switch breathPhase {
            case .inhale:
                breathPhase = .hold1
                scale = 1.0
            case .hold1:
                breathPhase = .exhale
            case .exhale:
                breathPhase = .hold2
                scale = 0.6
            case .hold2:
                breathPhase = .inhale
            }
        }
        scale = 1.0
    }
}

// MARK: - Upgrade Prompt View

struct UpgradePromptView: View {
    @EnvironmentObject var appClipManager: AppClipManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "star.circle.fill")
                    .font(.system(size: 80))
                    .foregroundStyle(.linearGradient(
                        colors: [.yellow, .orange],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))

                Text("Session abgeschlossen!")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Entdecke die volle Echoelmusic-Erfahrung")
                    .font(.headline)
                    .foregroundColor(.secondary)

                // Features list
                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(icon: "applewatch", title: "Apple Watch Integration", description: "Echtzeit HRV & Coherence")
                    FeatureRow(icon: "waveform.path.ecg", title: "Bio-Reaktive Audio", description: "Musik die auf dich reagiert")
                    FeatureRow(icon: "person.3.fill", title: "Gruppen-Sessions", description: "Meditiere mit Freunden")
                    FeatureRow(icon: "cloud.fill", title: "Cloud Sync", description: "Alle Geräte synchronisiert")
                }
                .padding()
                .background(Color(.systemGray6))
                .cornerRadius(12)

                Spacer()

                Button {
                    appClipManager.promptFullAppDownload()
                    dismiss()
                } label: {
                    HStack {
                        Image(systemName: "arrow.down.app.fill")
                        Text("Jetzt laden - Kostenlos testen")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .padding()
                    .frame(maxWidth: .infinity)
                    .background(Color.accentColor)
                    .cornerRadius(12)
                }

                Button("Später") {
                    dismiss()
                }
                .foregroundColor(.secondary)
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let title: String
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.accentColor)
                .frame(width: 32)

            VStack(alignment: .leading) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - App Clip Code Generator (for creating codes)

/// Utility for generating App Clip Code configurations
public struct AppClipCodeGenerator {

    /// Generate URL for specific session type
    public static func generateURL(for sessionType: AppClipManager.QuickSessionType, duration: TimeInterval? = nil) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "echoelmusic.com"
        components.path = "/clip/\(sessionType.rawValue.lowercased())"

        if let duration = duration {
            components.queryItems = [URLQueryItem(name: "duration", value: String(Int(duration)))]
        }

        // Safe fallback - components should always produce valid URL with these inputs
        return components.url ?? URL(string: "https://echoelmusic.com/clip")!
    }

    /// Generate URL for event
    public static func generateEventURL(eventId: String) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "echoelmusic.com"
        components.path = "/clip/event/\(eventId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? eventId)"

        // Safe fallback
        return components.url ?? URL(string: "https://echoelmusic.com/clip/event")!
    }

    /// Generate URL for venue
    public static func generateVenueURL(venueId: String, sessionType: AppClipManager.QuickSessionType) -> URL {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "echoelmusic.com"
        components.path = "/clip/venue/\(venueId.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed) ?? venueId)"
        components.queryItems = [URLQueryItem(name: "session", value: sessionType.rawValue.lowercased())]

        // Safe fallback
        return components.url ?? URL(string: "https://echoelmusic.com/clip/venue")!
    }
}

// MARK: - Preview

#if DEBUG
struct AppClipRootView_Previews: PreviewProvider {
    static var previews: some View {
        AppClipRootView()
            .environmentObject(AppClipManager.shared)
    }
}
#endif

#endif // os(iOS) && canImport(AppClip)
