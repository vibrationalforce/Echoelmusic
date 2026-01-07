// ContentView - Main MVP User Interface
// Clean, focused bio-reactive experience

import SwiftUI

// MARK: - Content View

public struct ContentView: View {
    @EnvironmentObject var appState: AppState
    @State private var showingDisclaimer: Bool = false
    @State private var hasAcceptedDisclaimer: Bool = false

    public init() {}

    public var body: some View {
        ZStack {
            // Background gradient based on coherence
            backgroundGradient

            VStack(spacing: 0) {
                // Header
                headerView

                Spacer()

                // Main visualization
                CoherenceVisualization(
                    coherence: appState.currentCoherence,
                    heartRate: appState.heartRate,
                    isActive: appState.isSessionActive
                )
                .frame(height: 300)
                .padding(.horizontal, 20)

                Spacer()

                // Bio metrics display
                if appState.isSessionActive {
                    bioMetricsView
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }

                Spacer()

                // Control button
                controlButton
                    .padding(.bottom, 40)
            }
        }
        .onAppear {
            if !hasAcceptedDisclaimer {
                showingDisclaimer = true
            }
        }
        .sheet(isPresented: $showingDisclaimer) {
            DisclaimerView(
                isPresented: $showingDisclaimer,
                onAccept: {
                    hasAcceptedDisclaimer = true
                    Task {
                        _ = await appState.healthKitManager.requestAuthorization()
                    }
                }
            )
        }
        .animation(.easeInOut(duration: 0.5), value: appState.isSessionActive)
        .animation(.easeInOut(duration: 1.0), value: appState.currentCoherence)
    }

    // MARK: - Background

    private var backgroundGradient: some View {
        LinearGradient(
            colors: [
                coherenceColor.opacity(0.3),
                Color.black
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }

    private var coherenceColor: Color {
        let coherence = appState.currentCoherence
        if coherence > 0.7 {
            return .green
        } else if coherence > 0.4 {
            return .blue
        } else {
            return .purple
        }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(spacing: 4) {
            Text("Echoelmusic")
                .font(.system(size: 28, weight: .light, design: .rounded))
                .foregroundColor(.white)

            if appState.isSessionActive {
                Text(appState.formatDuration(appState.sessionDuration))
                    .font(.system(size: 16, weight: .medium, design: .monospaced))
                    .foregroundColor(.white.opacity(0.7))
            }
        }
        .padding(.top, 60)
    }

    // MARK: - Bio Metrics

    private var bioMetricsView: some View {
        HStack(spacing: 30) {
            MetricView(
                icon: "heart.fill",
                value: String(format: "%.0f", appState.heartRate),
                unit: "BPM",
                color: .red
            )

            MetricView(
                icon: "waveform.path.ecg",
                value: String(format: "%.0f", appState.hrvValue),
                unit: "ms HRV",
                color: .orange
            )

            MetricView(
                icon: "sparkles",
                value: String(format: "%.0f%%", appState.currentCoherence * 100),
                unit: "Coherence",
                color: coherenceColor
            )
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 15)
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.white.opacity(0.1))
                .blur(radius: 0.5)
        )
        .padding(.horizontal, 20)
    }

    // MARK: - Control Button

    private var controlButton: some View {
        Button(action: toggleSession) {
            HStack(spacing: 12) {
                Image(systemName: appState.isSessionActive ? "stop.fill" : "play.fill")
                    .font(.system(size: 20))

                Text(appState.isSessionActive ? "End Session" : "Begin Session")
                    .font(.system(size: 18, weight: .semibold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 40)
            .padding(.vertical, 16)
            .background(
                Capsule()
                    .fill(
                        appState.isSessionActive
                            ? Color.red.opacity(0.8)
                            : coherenceColor.opacity(0.8)
                    )
            )
            .shadow(color: coherenceColor.opacity(0.5), radius: 10)
        }
        .scaleEffect(appState.isSessionActive ? 1.0 : 1.05)
        .animation(
            appState.isSessionActive
                ? .none
                : .easeInOut(duration: 1.5).repeatForever(autoreverses: true),
            value: appState.isSessionActive
        )
    }

    // MARK: - Actions

    private func toggleSession() {
        if appState.isSessionActive {
            appState.stopSession()
        } else {
            appState.startSession()
        }
    }
}

// MARK: - Metric View

struct MetricView: View {
    let icon: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 22, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(unit)
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.white.opacity(0.6))
        }
        .frame(minWidth: 80)
    }
}

// MARK: - Disclaimer View

struct DisclaimerView: View {
    @Binding var isPresented: Bool
    let onAccept: () -> Void

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 60))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.top, 20)

                    Text("Health Disclaimer")
                        .font(.title)
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)

                    Text(HealthDisclaimer.fullText)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)

                    Spacer(minLength: 30)

                    Button(action: {
                        onAccept()
                        isPresented = false
                    }) {
                        Text("I Understand")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
                            .cornerRadius(12)
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 30)
                }
            }
            .navigationBarTitleDisplayMode(.inline)
        }
        .interactiveDismissDisabled()
    }
}

// MARK: - Preview

#if DEBUG
struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        ContentView()
            .environmentObject(AppState())
    }
}
#endif
