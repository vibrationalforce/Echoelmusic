//
//  watchOSUI.swift
//  EOEL
//
//  Created: 2025-11-26
//  Copyright © 2025 EOEL. All rights reserved.
//
//  watchOS COMPLETE UI + COMPLICATIONS
//  Full Watch experience with complications, background monitoring, workouts
//

#if os(watchOS)
import SwiftUI
import HealthKit
import ClockKit

// MARK: - Main Watch View

struct WatchMainView: View {

    @StateObject private var watchApp = WatchApp()
    @State private var selectedTab: Tab = .session

    enum Tab {
        case session
        case metrics
        case history
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // Session Tab
            SessionView(watchApp: watchApp)
                .tag(Tab.session)

            // Metrics Tab
            MetricsView(watchApp: watchApp)
                .tag(Tab.metrics)

            // History Tab
            HistoryView()
                .tag(Tab.history)

            // Settings Tab
            SettingsView(watchApp: watchApp)
                .tag(Tab.settings)
        }
        .tabViewStyle(.page)
    }
}

// MARK: - Session View

struct SessionView: View {

    @ObservedObject var watchApp: WatchApp

    var body: some View {
        VStack(spacing: 12) {
            // Current coherence
            CoherenceRing(coherence: watchApp.currentMetrics.coherence)

            // Session controls
            if watchApp.isSessionActive {
                VStack(spacing: 8) {
                    Text(formatDuration(watchApp.sessionDuration))
                        .font(.system(.title2, design: .rounded))
                        .fontWeight(.semibold)

                    Button(action: {
                        Task {
                            try? await watchApp.stopSession()
                        }
                    }) {
                        Label("Stop", systemImage: "stop.fill")
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.red)
                }
            } else {
                // Session type picker
                Menu {
                    ForEach(WatchApp.SessionType.allCases, id: \.self) { type in
                        Button(type.rawValue) {
                            Task {
                                try? await watchApp.startSession(type: type)
                            }
                        }
                    }
                } label: {
                    Label("Start Session", systemImage: "play.fill")
                }
                .buttonStyle(.borderedProminent)
                .tint(.green)
            }
        }
        .padding()
        .navigationTitle("EOEL")
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}

// MARK: - Coherence Ring

struct CoherenceRing: View {

    let coherence: Double

    var coherenceLevel: String {
        switch coherence {
        case 0..<40: return "Low"
        case 40..<60: return "Medium"
        default: return "High"
        }
    }

    var coherenceColor: Color {
        switch coherence {
        case 0..<40: return .orange
        case 40..<60: return .yellow
        default: return .green
        }
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.gray.opacity(0.3), lineWidth: 12)
                .frame(width: 100, height: 100)

            // Progress ring
            Circle()
                .trim(from: 0, to: coherence / 100)
                .stroke(
                    coherenceColor,
                    style: StrokeStyle(lineWidth: 12, lineCap: .round)
                )
                .frame(width: 100, height: 100)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut, value: coherence)

            // Center text
            VStack(spacing: 2) {
                Text("\(Int(coherence))")
                    .font(.system(.title, design: .rounded))
                    .fontWeight(.bold)

                Text(coherenceLevel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Metrics View

struct MetricsView: View {

    @ObservedObject var watchApp: WatchApp

    var body: some View {
        List {
            Section("Heart") {
                MetricRow(
                    icon: "heart.fill",
                    color: .red,
                    label: "Heart Rate",
                    value: "\(Int(watchApp.currentMetrics.heartRate))",
                    unit: "BPM"
                )

                MetricRow(
                    icon: "waveform.path.ecg",
                    color: .blue,
                    label: "HRV",
                    value: "\(Int(watchApp.currentMetrics.hrv))",
                    unit: "ms"
                )
            }

            Section("Coherence") {
                MetricRow(
                    icon: "chart.line.uptrend.xyaxis",
                    color: .green,
                    label: "Coherence",
                    value: "\(Int(watchApp.currentMetrics.coherence))",
                    unit: "%"
                )

                MetricRow(
                    icon: "brain.head.profile",
                    color: .purple,
                    label: "State",
                    value: coherenceState,
                    unit: ""
                )
            }

            Section("Breathing") {
                MetricRow(
                    icon: "lungs.fill",
                    color: .cyan,
                    label: "Rate",
                    value: String(format: "%.1f", watchApp.breathingRate),
                    unit: "BPM"
                )
            }
        }
        .navigationTitle("Metrics")
    }

    private var coherenceState: String {
        switch watchApp.currentMetrics.coherence {
        case 0..<40: return "Stressed"
        case 40..<60: return "Neutral"
        case 60..<80: return "Calm"
        default: return "Flow"
        }
    }
}

struct MetricRow: View {

    let icon: String
    let color: Color
    let label: String
    let value: String
    let unit: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .font(.title3)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 2) {
                    Text(value)
                        .font(.system(.body, design: .rounded))
                        .fontWeight(.semibold)

                    if !unit.isEmpty {
                        Text(unit)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()
        }
    }
}

// MARK: - History View

struct HistoryView: View {

    @State private var sessions: [SessionHistoryItem] = []

    struct SessionHistoryItem: Identifiable {
        let id = UUID()
        let type: String
        let duration: TimeInterval
        let avgCoherence: Double
        let date: Date
    }

    var body: some View {
        List {
            if sessions.isEmpty {
                Text("No sessions yet")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
            } else {
                ForEach(sessions) { session in
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(session.type)
                                .font(.headline)

                            Spacer()

                            Text(formatDuration(session.duration))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }

                        HStack {
                            Text("Coherence: \(Int(session.avgCoherence))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Spacer()

                            Text(session.date, style: .relative)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .navigationTitle("History")
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        return "\(minutes)m"
    }
}

// MARK: - Settings View

struct SettingsView: View {

    @ObservedObject var watchApp: WatchApp

    var body: some View {
        List {
            Section("Sync") {
                Toggle("iPhone Sync", isOn: Binding(
                    get: { watchApp.iPhoneSyncEnabled },
                    set: { enabled in
                        if enabled {
                            watchApp.enableiPhoneSync()
                        } else {
                            watchApp.disableiPhoneSync()
                        }
                    }
                ))
            }

            Section("Breathing") {
                Stepper(
                    "Rate: \(Int(watchApp.breathingRate)) BPM",
                    value: Binding(
                        get: { watchApp.breathingRate },
                        set: { watchApp.breathingRate = $0 }
                    ),
                    in: 4...12
                )
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0.0")
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text("Platform")
                    Spacer()
                    Text("watchOS")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Settings")
    }
}

// MARK: - Complications

@available(watchOS 7.0, *)
class ComplicationController: NSObject, CLKComplicationDataSource {

    // MARK: - Complication Configuration

    func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
        let descriptors = [
            CLKComplicationDescriptor(
                identifier: "hrvCoherence",
                displayName: "HRV Coherence",
                supportedFamilies: [
                    .modularSmall,
                    .modularLarge,
                    .utilitarianSmall,
                    .utilitarianLarge,
                    .circularSmall,
                    .graphicCorner,
                    .graphicCircular,
                    .graphicRectangular,
                    .graphicBezel
                ]
            )
        ]

        handler(descriptors)
    }

    // MARK: - Timeline Configuration

    func getTimelineEndDate(for complication: CLKComplication, withHandler handler: @escaping (Date?) -> Void) {
        // Complications update indefinitely
        handler(nil)
    }

    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        // Show data on lock screen
        handler(.showOnLockScreen)
    }

    // MARK: - Timeline Population

    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        let template = makeTemplate(for: complication.family, coherence: 75, hrv: 65)
        let entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
        handler(entry)
    }

    func getTimelineEntries(
        for complication: CLKComplication,
        after date: Date,
        limit: Int,
        withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void
    ) {
        // Generate future entries (every 5 minutes)
        var entries: [CLKComplicationTimelineEntry] = []

        for i in 0..<limit {
            let entryDate = date.addingTimeInterval(TimeInterval(i * 5 * 60))
            let template = makeTemplate(for: complication.family, coherence: 70 + Double(i), hrv: 60 + Double(i))
            let entry = CLKComplicationTimelineEntry(date: entryDate, complicationTemplate: template)
            entries.append(entry)
        }

        handler(entries)
    }

    // MARK: - Template Generation

    private func makeTemplate(for family: CLKComplicationFamily, coherence: Double, hrv: Double) -> CLKComplicationTemplate {
        switch family {
        case .modularSmall:
            return makeModularSmallTemplate(coherence: coherence)

        case .modularLarge:
            return makeModularLargeTemplate(coherence: coherence, hrv: hrv)

        case .circularSmall:
            return makeCircularSmallTemplate(coherence: coherence)

        case .graphicCircular:
            return makeGraphicCircularTemplate(coherence: coherence)

        case .graphicRectangular:
            return makeGraphicRectangularTemplate(coherence: coherence, hrv: hrv)

        case .graphicCorner:
            return makeGraphicCornerTemplate(coherence: coherence)

        default:
            return makeModularSmallTemplate(coherence: coherence)
        }
    }

    private func makeModularSmallTemplate(coherence: Double) -> CLKComplicationTemplateModularSmallSimpleText {
        let template = CLKComplicationTemplateModularSmallSimpleText()
        template.textProvider = CLKSimpleTextProvider(text: "\(Int(coherence))%")
        return template
    }

    private func makeModularLargeTemplate(coherence: Double, hrv: Double) -> CLKComplicationTemplateModularLargeStandardBody {
        let template = CLKComplicationTemplateModularLargeStandardBody()
        template.headerTextProvider = CLKSimpleTextProvider(text: "EOEL")
        template.body1TextProvider = CLKSimpleTextProvider(text: "Coherence: \(Int(coherence))%")
        template.body2TextProvider = CLKSimpleTextProvider(text: "HRV: \(Int(hrv))ms")
        return template
    }

    private func makeCircularSmallTemplate(coherence: Double) -> CLKComplicationTemplateCircularSmallRingText {
        let template = CLKComplicationTemplateCircularSmallRingText()
        template.textProvider = CLKSimpleTextProvider(text: "\(Int(coherence))")
        template.fillFraction = Float(coherence / 100.0)
        template.ringStyle = .closed
        return template
    }

    @available(watchOS 7.0, *)
    private func makeGraphicCircularTemplate(coherence: Double) -> CLKComplicationTemplateGraphicCircularStackText {
        let template = CLKComplicationTemplateGraphicCircularStackText()
        template.line1TextProvider = CLKSimpleTextProvider(text: "\(Int(coherence))%")
        template.line2TextProvider = CLKSimpleTextProvider(text: "Coherence")
        return template
    }

    @available(watchOS 7.0, *)
    private func makeGraphicRectangularTemplate(coherence: Double, hrv: Double) -> CLKComplicationTemplateGraphicRectangularStandardBody {
        let template = CLKComplicationTemplateGraphicRectangularStandardBody()
        template.headerTextProvider = CLKSimpleTextProvider(text: "EOEL")
        template.body1TextProvider = CLKSimpleTextProvider(text: "Coherence: \(Int(coherence))%")
        template.body2TextProvider = CLKSimpleTextProvider(text: "HRV: \(Int(hrv))ms")
        return template
    }

    @available(watchOS 7.0, *)
    private func makeGraphicCornerTemplate(coherence: Double) -> CLKComplicationTemplateGraphicCornerGaugeText {
        let template = CLKComplicationTemplateGraphicCornerGaugeText()
        template.outerTextProvider = CLKSimpleTextProvider(text: "EOEL")
        template.gaugeProvider = CLKSimpleGaugeProvider(
            style: .fill,
            gaugeColor: coherence > 60 ? .green : (coherence > 40 ? .yellow : .orange),
            fillFraction: Float(coherence / 100.0)
        )
        return template
    }

    // MARK: - Placeholder Templates

    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        let template = makeTemplate(for: complication.family, coherence: 85, hrv: 70)
        handler(template)
    }
}

// MARK: - Background Monitoring

@available(watchOS 7.0, *)
class BackgroundMonitoringManager {

    static let shared = BackgroundMonitoringManager()

    private let healthStore = HKHealthStore()

    /// Enable background heart rate monitoring
    func enableBackgroundMonitoring() {
        // Setup background delivery for heart rate
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate) else {
            return
        }

        healthStore.enableBackgroundDelivery(for: heartRateType, frequency: .immediate) { success, error in
            if success {
                print("⌚ Background monitoring enabled")
            } else if let error = error {
                print("❌ Background monitoring failed: \(error)")
            }
        }

        // Setup background delivery for HRV
        guard let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return
        }

        healthStore.enableBackgroundDelivery(for: hrvType, frequency: .immediate) { success, error in
            if success {
                print("⌚ Background HRV monitoring enabled")
            }
        }
    }

    /// Disable background monitoring
    func disableBackgroundMonitoring() {
        guard let heartRateType = HKObjectType.quantityType(forIdentifier: .heartRate),
              let hrvType = HKObjectType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else {
            return
        }

        healthStore.disableBackgroundDelivery(for: heartRateType) { _, _ in }
        healthStore.disableBackgroundDelivery(for: hrvType) { _, _ in }

        print("⌚ Background monitoring disabled")
    }
}

// MARK: - Workout Integration

@available(watchOS 7.0, *)
class WorkoutIntegration {

    static let shared = WorkoutIntegration()

    private let healthStore = HKHealthStore()
    private var workoutSession: HKWorkoutSession?
    private var workoutBuilder: HKLiveWorkoutBuilder?

    /// Start meditation workout
    func startMeditationWorkout() async throws {
        let configuration = HKWorkoutConfiguration()
        configuration.activityType = .mindAndBody
        configuration.locationType = .indoor

        let session = try HKWorkoutSession(healthStore: healthStore, configuration: configuration)
        let builder = session.associatedWorkoutBuilder()

        builder.dataSource = HKLiveWorkoutDataSource(
            healthStore: healthStore,
            workoutConfiguration: configuration
        )

        workoutSession = session
        workoutBuilder = builder

        session.startActivity(with: Date())
        try await builder.beginCollection(at: Date())

        print("🧘 Meditation workout started")
    }

    /// Stop workout and save
    func stopWorkout() async throws {
        guard let session = workoutSession,
              let builder = workoutBuilder else {
            return
        }

        session.end()
        try await builder.endCollection(at: Date())
        try await builder.finishWorkout()

        print("💾 Meditation workout saved to HealthKit")

        workoutSession = nil
        workoutBuilder = nil
    }
}

#endif
