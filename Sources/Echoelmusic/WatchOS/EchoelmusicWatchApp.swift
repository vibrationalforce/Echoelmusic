//
//  EchoelmusicWatchApp.swift
//  Echoelmusic
//
//  Main entry point for watchOS app
//  Bio-reactive HRV monitoring and coherence tracking
//
//  Created: 2026-02-02
//

#if os(watchOS)
import SwiftUI
import HealthKit

// MARK: - watchOS App Entry Point

@main
struct EchoelmusicWatchApp: App {

    @StateObject private var healthKitManager = HealthKitManager()

    var body: some Scene {
        WindowGroup {
            WatchContentView()
                .environmentObject(healthKitManager)
        }
    }
}

// MARK: - Watch Content View

struct WatchContentView: View {
    @EnvironmentObject var healthKit: HealthKitManager
    @State private var isSessionActive = false
    @State private var showSettings = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Coherence Ring
                    coherenceSection

                    // Bio Metrics
                    bioMetricsSection

                    // Quick Actions
                    quickActionsSection
                }
                .padding()
            }
            .navigationTitle("Echoelmusic")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "gearshape")
                    }
                }
            }
            .sheet(isPresented: $showSettings) {
                WatchSettingsView()
            }
        }
        .task {
            await requestHealthKitAuthorization()
        }
    }

    // MARK: - Coherence Section

    private var coherenceSection: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 8)

            Circle()
                .trim(from: 0, to: CGFloat(healthKit.hrvCoherence / 100))
                .stroke(
                    coherenceGradient,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: healthKit.hrvCoherence)

            VStack(spacing: 2) {
                Text("\(Int(healthKit.hrvCoherence))")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(coherenceColor)

                Text("Coherence")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .frame(height: 120)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Coherence level \(Int(healthKit.hrvCoherence)) percent")
    }

    private var coherenceGradient: AngularGradient {
        AngularGradient(
            colors: [.red, .orange, .yellow, .green, .cyan],
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360 * healthKit.hrvCoherence / 100)
        )
    }

    private var coherenceColor: Color {
        switch healthKit.hrvCoherence {
        case 70...: return .green
        case 40..<70: return .yellow
        default: return .orange
        }
    }

    // MARK: - Bio Metrics Section

    private var bioMetricsSection: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
            MetricCard(
                icon: "heart.fill",
                value: "\(Int(healthKit.heartRate))",
                unit: "BPM",
                color: .red
            )

            MetricCard(
                icon: "waveform.path.ecg",
                value: String(format: "%.0f", healthKit.hrvRMSSD),
                unit: "ms",
                color: .green
            )
        }
    }

    // MARK: - Quick Actions Section

    private var quickActionsSection: some View {
        HStack(spacing: 12) {
            Button(action: toggleSession) {
                Image(systemName: isSessionActive ? "pause.fill" : "play.fill")
                    .font(.title3)
            }
            .buttonStyle(.bordered)
            .tint(isSessionActive ? .red : .green)

            Button(action: { }) {
                Image(systemName: "arrow.triangle.2.circlepath")
                    .font(.title3)
            }
            .buttonStyle(.bordered)
            .tint(.cyan)
        }
    }

    // MARK: - Actions

    private func requestHealthKitAuthorization() async {
        do {
            try await healthKit.requestAuthorization()
            log.info("⌚ HealthKit authorization granted", category: .system)
        } catch {
            log.error("⌚ HealthKit authorization failed: \(error.localizedDescription)", category: .system)
        }
    }

    private func toggleSession() {
        isSessionActive.toggle()

        if isSessionActive {
            Task {
                await healthKit.startMonitoring()
                log.info("⌚ Bio-reactive session started", category: .system)
            }
        } else {
            healthKit.stopMonitoring()
            log.info("⌚ Bio-reactive session stopped", category: .system)
        }
    }
}

// MARK: - Metric Card

struct MetricCard: View {
    let icon: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundColor(color)
                .font(.caption)

            Text(value)
                .font(.system(.body, design: .rounded, weight: .semibold))

            Text(unit)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.15))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Watch Settings View

struct WatchSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hapticFeedback") private var hapticFeedback = true
    @AppStorage("breathingRate") private var breathingRate = 6.0

    var body: some View {
        NavigationStack {
            List {
                Section("Session") {
                    Toggle("Haptic Feedback", isOn: $hapticFeedback)

                    HStack {
                        Text("Breathing Rate")
                        Spacer()
                        Text("\(Int(breathingRate))/min")
                            .foregroundColor(.secondary)
                    }
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("3.0.0")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#endif
