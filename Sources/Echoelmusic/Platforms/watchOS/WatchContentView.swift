import SwiftUI

#if os(watchOS)

/// Alternative content view for Echoelmusic Apple Watch app (renamed to avoid conflict with WatchAppView)
/// Bio-reactive meditation and breathing guidance with haptic feedback
struct WatchContentViewAlt: View {

    @State private var watchApp = WatchApp()
    @State private var selectedTab: Tab = .metrics
    @State private var showingSessionPicker = false

    enum Tab: String, CaseIterable {
        case metrics = "Metrics"
        case breathing = "Breathing"
        case history = "History"
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Bio Metrics Tab
            MetricsView(watchApp: watchApp)
                .tag(Tab.metrics)

            // Breathing Session Tab
            BreathingView(watchApp: watchApp)
                .tag(Tab.breathing)

            // Session History Tab
            HistoryView()
                .tag(Tab.history)
        }
        .tabViewStyle(.verticalPage)
    }
}

// MARK: - Metrics View

struct MetricsView: View {
    @Bindable var watchApp: WatchApp

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Header
                Text("ECHOELMUSIC")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(.cyan)
                    .tracking(2)

                // Coherence Ring
                coherenceRing
                    .frame(height: 100)

                // Heart Rate & HRV
                HStack(spacing: 16) {
                    metricCard(
                        icon: "heart.fill",
                        value: "\(Int(watchApp.currentMetrics.heartRate))",
                        unit: "BPM",
                        color: .red
                    )

                    metricCard(
                        icon: "waveform.path.ecg",
                        value: String(format: "%.0f", watchApp.currentMetrics.hrv),
                        unit: "HRV",
                        color: .green
                    )
                }

                // Session Button
                if !watchApp.isSessionActive {
                    Button(action: { startQuickSession() }) {
                        HStack {
                            Image(systemName: "play.fill")
                            Text("Start Session")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.cyan)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Start meditation session")
                } else {
                    Button(action: { stopSession() }) {
                        HStack {
                            Image(systemName: "stop.fill")
                            Text("Stop")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(.black)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 8)
                        .background(Color.red)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel("Stop current session")
                }
            }
            .padding()
        }
        .background(Color.black)
    }

    private var coherenceRing: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 8)

            // Progress ring
            Circle()
                .trim(from: 0, to: watchApp.currentMetrics.coherence)
                .stroke(
                    coherenceColor,
                    style: StrokeStyle(lineWidth: 8, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 0.5), value: watchApp.currentMetrics.coherence)

            // Center content
            VStack(spacing: 2) {
                Text("\(Int(watchApp.currentMetrics.coherence * 100))")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundColor(coherenceColor)

                Text("COHERENCE")
                    .font(.system(size: 8, weight: .medium))
                    .foregroundColor(.gray)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Coherence level \(Int(watchApp.currentMetrics.coherence * 100)) percent")
    }

    private var coherenceColor: Color {
        switch watchApp.currentMetrics.coherenceLevel {
        case .high: return .green
        case .medium: return .yellow
        case .low: return .red
        }
    }

    private func metricCard(icon: String, value: String, unit: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(color)

            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .foregroundColor(.white)

            Text(unit)
                .font(.system(size: 10))
                .foregroundColor(.gray)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(unit): \(value)")
    }

    private func startQuickSession() {
        Task {
            try? await watchApp.startSession(type: .breathing)
        }
    }

    private func stopSession() {
        Task {
            await watchApp.stopSession()
        }
    }
}

// MARK: - Breathing View

struct BreathingView: View {
    @Bindable var watchApp: WatchApp
    @State private var breathPhase: BreathPhase = .inhale
    @State private var animationProgress: Double = 0

    enum BreathPhase: String {
        case inhale = "Einatmen"
        case hold = "Halten"
        case exhale = "Ausatmen"

        var color: Color {
            switch self {
            case .inhale: return .cyan
            case .hold: return .yellow
            case .exhale: return .purple
            }
        }
    }

    var body: some View {
        VStack(spacing: 16) {
            Text(breathPhase.rawValue.uppercased())
                .font(.system(size: 14, weight: .bold))
                .foregroundColor(breathPhase.color)
                .tracking(2)

            // Breathing circle
            ZStack {
                Circle()
                    .fill(breathPhase.color.opacity(0.2))

                Circle()
                    .fill(breathPhase.color.opacity(0.5))
                    .scaleEffect(0.3 + animationProgress * 0.7)
                    .animation(.easeInOut(duration: 4), value: animationProgress)
            }
            .frame(width: 100, height: 100)

            // Rate selector
            HStack {
                Text("\(Int(watchApp.breathingRate))")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.white)

                Text("Atemzüge/min")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }

            // Controls
            HStack(spacing: 20) {
                Button(action: decreaseRate) {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.cyan)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Decrease breathing rate")

                Button(action: increaseRate) {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.cyan)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Increase breathing rate")
            }
        }
        .padding()
        .background(Color.black)
        .onAppear {
            startBreathingAnimation()
        }
    }

    private func startBreathingAnimation() {
        withAnimation(.easeInOut(duration: 4).repeatForever(autoreverses: true)) {
            animationProgress = 1.0
        }
    }

    private func decreaseRate() {
        watchApp.breathingRate = max(4, watchApp.breathingRate - 1)
    }

    private func increaseRate() {
        watchApp.breathingRate = min(12, watchApp.breathingRate + 1)
    }
}

// MARK: - History View

struct HistoryView: View {
    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                Text("SESSION HISTORY")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.gray)
                    .tracking(2)

                // Placeholder sessions
                ForEach(0..<3, id: \.self) { index in
                    historyRow(
                        date: "Today",
                        duration: "\(10 + index * 5) min",
                        coherence: 60 + index * 10
                    )
                }

                Text("View more on iPhone")
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
                    .padding(.top, 8)
            }
            .padding()
        }
        .background(Color.black)
    }

    private func historyRow(date: String, duration: String, coherence: Int) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(date)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.white)

                Text(duration)
                    .font(.system(size: 10))
                    .foregroundColor(.gray)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(coherence)%")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(coherenceColor(coherence))

                Text("coherence")
                    .font(.system(size: 8))
                    .foregroundColor(.gray)
            }
        }
        .padding(10)
        .background(Color.white.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Session on \(date), \(duration), \(coherence) percent coherence")
    }

    private func coherenceColor(_ value: Int) -> Color {
        if value >= 70 { return .green }
        if value >= 50 { return .yellow }
        return .red
    }
}

// Note: Main entry point is in WatchAppView.swift (EchoelmusicWatchApp)

#endif
