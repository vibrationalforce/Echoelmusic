// EchoelmusicClip.swift
// Echoelmusic App Clip - Instant Performance Minting
//
// Bundle ID: com.echoelmusic.app.clip
// Size Limit: < 10MB
// Purpose: Instant bio-reactive experience at events/concerts
//
// "I'm a unitard!" - Ralph Wiggum, Event Coordinator
//
// Created 2026-02-04

// App Clip code - only compiles in dedicated App Clip target
#if ECHOELMUSIC_CLIP_TARGET
// Copyright (c) 2026 Echoelmusic. All rights reserved.

import SwiftUI
import AppClip

#if canImport(CoreLocation)
import CoreLocation
#endif

// MARK: - App Clip Entry Point

/// Echoelmusic App Clip for instant bio-reactive experiences
/// Features:
/// - Quick coherence capture at events
/// - Instant NFT minting of "Coherence Moments"
/// - Event-specific visualizations
/// - Seamless handoff to full app
// Note: @main removed - App Clip uses separate Xcode target with its own entry point
struct EchoelmusicClipApp: App {
    @StateObject private var clipManager = AppClipManager()
    @StateObject private var healthKit = UnifiedHealthKitEngine.shared

    var body: some Scene {
        WindowGroup {
            EchoelmusicClipRootView()
                .environmentObject(clipManager)
                .environmentObject(healthKit)
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    clipManager.handleInvocation(activity: activity)
                }
        }
    }
}

// MARK: - App Clip Manager

/// Manages App Clip invocation, context, and state
@MainActor
final class AppClipManager: ObservableObject {

    // MARK: - Published State

    @Published var invocationURL: URL?
    @Published var eventContext: EventContext?
    @Published var isCapturing: Bool = false
    @Published var capturedMoment: CoherenceMoment?
    @Published var mintingState: MintingState = .idle
    @Published var errorMessage: String?

    // MARK: - Types

    /// Context from the event/location that triggered the App Clip
    struct EventContext: Codable, Sendable {
        let eventId: String
        let eventName: String
        let artistName: String?
        let venue: String?
        let timestamp: Date
        let latitude: Double?
        let longitude: Double?

        static let preview = EventContext(
            eventId: "preview-001",
            eventName: "Echoelmusic Live",
            artistName: "Echoel",
            venue: "Berlin Techno Temple",
            timestamp: Date(),
            latitude: 52.5200,
            longitude: 13.4050
        )
    }

    /// A captured coherence moment ready for minting
    struct CoherenceMoment: Codable, Identifiable, Sendable {
        let id: UUID
        let timestamp: Date
        let duration: TimeInterval
        let peakCoherence: Double
        let averageCoherence: Double
        let heartRateRange: ClosedRange<Double>
        let breathingRate: Double
        let eventContext: EventContext?

        var coherenceLevel: String {
            if peakCoherence >= 0.7 { return "Transcendent" }
            if peakCoherence >= 0.5 { return "Flowing" }
            if peakCoherence >= 0.3 { return "Grounded" }
            return "Awakening"
        }
    }

    /// NFT minting state
    enum MintingState: Equatable {
        case idle
        case preparing
        case uploading
        case minting
        case complete(txHash: String)
        case failed(error: String)

        var isInProgress: Bool {
            switch self {
            case .preparing, .uploading, .minting: return true
            default: return false
            }
        }
    }

    // MARK: - Private Properties

    private var captureStartTime: Date?
    private var coherenceReadings: [Double] = []
    private var heartRateReadings: [Double] = []

    // MARK: - Invocation Handling

    /// Handle App Clip invocation from URL
    func handleInvocation(activity: NSUserActivity) {
        guard let url = activity.webpageURL else { return }
        invocationURL = url

        // Parse event context from URL
        // Expected format: https://echoelmusic.com/clip?event=xxx&artist=yyy&venue=zzz
        if let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
           let queryItems = components.queryItems {

            let eventId = queryItems.first(where: { $0.name == "event" })?.value ?? UUID().uuidString
            let eventName = queryItems.first(where: { $0.name == "name" })?.value ?? "Live Event"
            let artistName = queryItems.first(where: { $0.name == "artist" })?.value
            let venue = queryItems.first(where: { $0.name == "venue" })?.value

            eventContext = EventContext(
                eventId: eventId,
                eventName: eventName,
                artistName: artistName,
                venue: venue,
                timestamp: Date(),
                latitude: nil,
                longitude: nil
            )

            log.info("App Clip invoked for event: \(eventName)")
        }
    }

    // MARK: - Coherence Capture

    /// Start capturing a coherence moment
    func startCapture(healthKit: UnifiedHealthKitEngine) {
        guard !isCapturing else { return }

        isCapturing = true
        captureStartTime = Date()
        coherenceReadings = []
        heartRateReadings = []

        // Request HealthKit access if needed
        Task {
            if !healthKit.isAuthorized {
                try? await healthKit.requestAuthorization()
            }
            healthKit.startStreaming()
        }

        log.info("Started coherence capture")
    }

    /// Record a coherence reading
    func recordReading(coherence: Double, heartRate: Double) {
        guard isCapturing else { return }
        coherenceReadings.append(coherence)
        heartRateReadings.append(heartRate)
    }

    /// Stop capture and create moment
    func stopCapture(healthKit: UnifiedHealthKitEngine) -> CoherenceMoment? {
        guard isCapturing, let startTime = captureStartTime else { return nil }

        isCapturing = false
        healthKit.stopStreaming()

        let duration = Date().timeIntervalSince(startTime)
        let peakCoherence = coherenceReadings.max() ?? 0
        let avgCoherence = coherenceReadings.isEmpty ? 0 : coherenceReadings.reduce(0, +) / Double(coherenceReadings.count)
        let minHR = heartRateReadings.min() ?? 60
        let maxHR = heartRateReadings.max() ?? 100

        let moment = CoherenceMoment(
            id: UUID(),
            timestamp: startTime,
            duration: duration,
            peakCoherence: peakCoherence,
            averageCoherence: avgCoherence,
            heartRateRange: minHR...maxHR,
            breathingRate: healthKit.breathingRate,
            eventContext: eventContext
        )

        capturedMoment = moment
        log.info("Captured coherence moment: peak=\(peakCoherence), avg=\(avgCoherence)")

        return moment
    }

    // MARK: - NFT Minting

    /// Mint the captured moment as an NFT
    func mintMoment(_ moment: CoherenceMoment) async {
        mintingState = .preparing

        do {
            // Prepare metadata
            let metadata = NFTFactory.BioReactiveMetadata(
                sessionId: moment.id.uuidString,
                duration: moment.duration,
                peakCoherence: moment.peakCoherence,
                averageCoherence: moment.averageCoherence,
                heartRateRange: moment.heartRateRange,
                breathingPattern: "Event Capture",
                emotionalSignature: moment.coherenceLevel,
                timestamp: moment.timestamp
            )

            mintingState = .uploading

            // Create NFT via factory (stub - would call actual blockchain)
            let factory = NFTFactory.shared
            let txHash = try await factory.mintBioReactiveNFT(
                metadata: metadata,
                contentType: .coherenceMoment
            )

            mintingState = .complete(txHash: txHash)
            log.info("Minted NFT: \(txHash)")

        } catch {
            mintingState = .failed(error: error.localizedDescription)
            errorMessage = error.localizedDescription
            log.error("Minting failed: \(error)")
        }
    }

    // MARK: - Full App Handoff

    /// Generate URL for handoff to full app
    func fullAppURL() -> URL? {
        guard let moment = capturedMoment else { return nil }

        var components = URLComponents()
        components.scheme = "echoelmusic"
        components.host = "moment"
        components.queryItems = [
            URLQueryItem(name: "id", value: moment.id.uuidString),
            URLQueryItem(name: "coherence", value: String(format: "%.2f", moment.peakCoherence))
        ]

        return components.url
    }
}

// MARK: - App Clip Root View

struct EchoelmusicClipRootView: View {
    @EnvironmentObject var clipManager: AppClipManager
    @EnvironmentObject var healthKit: UnifiedHealthKitEngine

    @State private var showingMintSheet = false
    @State private var timer: Timer?

    var body: some View {
        ZStack {
            // Background
            LinearGradient(
                colors: [Color.purple.opacity(0.3), Color.black],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                // Header
                headerView

                Spacer()

                // Main Content
                if clipManager.isCapturing {
                    capturingView
                } else if let moment = clipManager.capturedMoment {
                    momentCapturedView(moment)
                } else {
                    readyToCapture
                }

                Spacer()

                // Event Context
                if let event = clipManager.eventContext {
                    eventBadge(event)
                }

                // Get Full App
                fullAppButton
            }
            .padding()
        }
        .sheet(isPresented: $showingMintSheet) {
            if let moment = clipManager.capturedMoment {
                MintingSheet(moment: moment)
                    .environmentObject(clipManager)
            }
        }
    }

    // MARK: - Subviews

    private var headerView: some View {
        VStack(spacing: 8) {
            Image(systemName: "waveform.circle.fill")
                .font(.system(size: 60))
                .foregroundStyle(
                    LinearGradient(
                        colors: [.pink, .purple],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )

            Text("Echoelmusic")
                .font(.largeTitle.bold())

            Text("Capture Your Coherence")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var readyToCapture: some View {
        VStack(spacing: 20) {
            // Coherence display
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 180, height: 180)

                VStack {
                    Text("\(Int(healthKit.coherence * 100))")
                        .font(.system(size: 56, weight: .bold, design: .rounded))

                    Text("Coherence")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Button {
                clipManager.startCapture(healthKit: healthKit)
                startRecordingTimer()
            } label: {
                Label("Start Capture", systemImage: "record.circle")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.pink)
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }
        }
    }

    private var capturingView: some View {
        VStack(spacing: 20) {
            // Pulsing coherence orb
            ZStack {
                // Pulse rings
                ForEach(0..<3) { i in
                    Circle()
                        .stroke(coherenceColor.opacity(0.3), lineWidth: 2)
                        .frame(width: 180 + CGFloat(i * 30), height: 180 + CGFloat(i * 30))
                        .scaleEffect(1.0 + sin(Date().timeIntervalSinceReferenceDate * 2 + Double(i)) * 0.1)
                }

                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 180, height: 180)

                VStack {
                    Text("\(Int(healthKit.coherence * 100))")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .foregroundColor(coherenceColor)

                    Text("CAPTURING...")
                        .font(.caption.bold())
                        .foregroundColor(.pink)
                }
            }

            // Heart rate
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(.red)
                Text("\(Int(healthKit.heartRate)) BPM")
                    .font(.headline.monospacedDigit())
            }

            Button {
                timer?.invalidate()
                _ = clipManager.stopCapture(healthKit: healthKit)
            } label: {
                Label("Stop Capture", systemImage: "stop.circle.fill")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }
        }
        .onAppear {
            // Start recording readings
            timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
                clipManager.recordReading(
                    coherence: healthKit.coherence,
                    heartRate: healthKit.heartRate
                )
            }
        }
    }

    private func momentCapturedView(_ moment: AppClipManager.CoherenceMoment) -> some View {
        VStack(spacing: 20) {
            // Success badge
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Moment Captured!")
                .font(.title2.bold())

            // Stats
            VStack(spacing: 12) {
                statRow(label: "Peak Coherence", value: "\(Int(moment.peakCoherence * 100))%")
                statRow(label: "Level", value: moment.coherenceLevel)
                statRow(label: "Duration", value: formatDuration(moment.duration))
            }
            .padding()
            .background(.ultraThinMaterial)
            .cornerRadius(16)

            // Mint button
            Button {
                showingMintSheet = true
            } label: {
                Label("Mint as NFT", systemImage: "sparkles")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [.purple, .pink],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .foregroundColor(.white)
                    .cornerRadius(16)
            }

            // New capture
            Button {
                clipManager.capturedMoment = nil
            } label: {
                Text("Capture Another")
                    .foregroundColor(.secondary)
            }
        }
    }

    private func eventBadge(_ event: AppClipManager.EventContext) -> some View {
        HStack {
            Image(systemName: "music.note.house.fill")
                .foregroundColor(.purple)

            VStack(alignment: .leading) {
                Text(event.eventName)
                    .font(.caption.bold())
                if let artist = event.artistName {
                    Text(artist)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    private var fullAppButton: some View {
        Link(destination: URL(string: "https://apps.apple.com/app/echoelmusic")!) {
            HStack {
                Image(systemName: "arrow.down.app.fill")
                Text("Get Full App")
            }
            .font(.footnote)
            .foregroundColor(.secondary)
        }
    }

    // MARK: - Helpers

    private func statRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.semibold)
        }
    }

    private var coherenceColor: Color {
        switch healthKit.coherenceLevel {
        case .high: return .green
        case .medium: return .yellow
        case .low: return .orange
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    private func startRecordingTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { _ in
            clipManager.recordReading(
                coherence: healthKit.coherence,
                heartRate: healthKit.heartRate
            )
        }
    }
}

// MARK: - Minting Sheet

struct MintingSheet: View {
    let moment: AppClipManager.CoherenceMoment
    @EnvironmentObject var clipManager: AppClipManager
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Preview card
                VStack(spacing: 12) {
                    Text("🌟")
                        .font(.system(size: 60))

                    Text(moment.coherenceLevel)
                        .font(.title.bold())

                    Text("\(Int(moment.peakCoherence * 100))% Peak Coherence")
                        .foregroundColor(.secondary)

                    if let event = moment.eventContext {
                        Text(event.eventName)
                            .font(.caption)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(.purple.opacity(0.2))
                            .cornerRadius(8)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity)
                .background(.ultraThinMaterial)
                .cornerRadius(20)

                // Status
                switch clipManager.mintingState {
                case .idle:
                    mintButton
                case .preparing, .uploading, .minting:
                    progressView
                case .complete(let txHash):
                    successView(txHash)
                case .failed(let error):
                    errorView(error)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Mint NFT")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private var mintButton: some View {
        Button {
            Task {
                await clipManager.mintMoment(moment)
            }
        } label: {
            Label("Mint Now", systemImage: "wand.and.stars")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.purple)
                .foregroundColor(.white)
                .cornerRadius(16)
        }
    }

    private var progressView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)

            Text(statusText)
                .foregroundColor(.secondary)
        }
    }

    private var statusText: String {
        switch clipManager.mintingState {
        case .preparing: return "Preparing metadata..."
        case .uploading: return "Uploading to IPFS..."
        case .minting: return "Minting on blockchain..."
        default: return ""
        }
    }

    private func successView(_ txHash: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("Successfully Minted!")
                .font(.headline)

            Text(txHash.prefix(20) + "...")
                .font(.caption.monospaced())
                .foregroundColor(.secondary)

            Button("Done") { dismiss() }
                .buttonStyle(.borderedProminent)
        }
    }

    private func errorView(_ error: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 60))
                .foregroundColor(.orange)

            Text("Minting Failed")
                .font(.headline)

            Text(error)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            Button("Try Again") {
                Task {
                    await clipManager.mintMoment(moment)
                }
            }
            .buttonStyle(.borderedProminent)
        }
    }
}

// MARK: - Preview

#Preview("App Clip") {
    EchoelmusicClipRootView()
        .environmentObject(AppClipManager())
        .environmentObject(UnifiedHealthKitEngine.shared)
}

#endif // ECHOELMUSIC_CLIP_TARGET
