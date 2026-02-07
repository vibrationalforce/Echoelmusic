//
//  QuantumWidgets.swift
//  Echoelmusic
//
//  iOS Home Screen Widgets for Quantum Light Experience
//  A+++ Widget Gallery with real-time coherence tracking
//
//  Created: 2026-01-05
//

import Foundation
import SwiftUI
import WidgetKit

#if canImport(AppIntents)
import AppIntents
#endif

// MARK: - Safe Deep Link Helper

/// Static fallback URL for widgets (compile-time guaranteed valid)
private let widgetFallbackURL = URL(fileURLWithPath: "/")

/// Creates safe deep link URLs for widgets with fallback
private func safeDeepLink(_ path: String) -> URL {
    URL(string: "echoelmusic://\(path)") ?? URL(string: "echoelmusic://home") ?? widgetFallbackURL
}

// MARK: - Widget Visualization Type (Local Definition)

/// Local visualization type enum for Widget target (mirrors WidgetVisualizationType)
@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
enum WidgetVisualizationType: String, CaseIterable, Sendable {
    case interferencePattern = "Interference Pattern"
    case waveFunction = "Wave Function"
    case coherenceField = "Coherence Field"
    case photonFlow = "Photon Flow"
    case sacredGeometry = "Sacred Geometry"
    case quantumTunnel = "Quantum Tunnel"
    case biophotonAura = "Biophoton Aura"
    case lightMandala = "Light Mandala"
    case holographicDisplay = "Holographic Display"
    case cosmicWeb = "Cosmic Web"
}

// MARK: - Widget Bundle

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
public struct EchoelmusicWidgets: WidgetBundle {
    public init() {}

    public var body: some Widget {
        CoherenceWidget()
        QuickSessionWidget()
        PresetWidget()
        VisualizationWidget()
    }
}

// MARK: - Coherence Widget

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct CoherenceWidget: Widget {
    let kind: String = "CoherenceWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: CoherenceWidgetIntent.self,
            provider: CoherenceTimelineProvider()
        ) { entry in
            CoherenceWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Quantum Coherence")
        .description("Track your quantum coherence level in real-time")
        .supportedFamilies([.systemSmall, .systemMedium, .accessoryCircular, .accessoryRectangular])
    }
}

// MARK: - Coherence Widget Intent

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct CoherenceWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Coherence Widget"
    static var description = IntentDescription("Configure coherence display")

    @Parameter(title: "Show HRV")
    var showHRV: Bool

    @Parameter(title: "Color Scheme")
    var colorScheme: WidgetColorScheme

    init() {
        showHRV = true
        colorScheme = .quantum
    }

    init(showHRV: Bool = true, colorScheme: WidgetColorScheme = .quantum) {
        self.showHRV = showHRV
        self.colorScheme = colorScheme
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
enum WidgetColorScheme: String, AppEnum {
    case quantum = "Quantum"
    case nature = "Nature"
    case calm = "Calm"
    case energy = "Energy"

    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Color Scheme"

    static var caseDisplayRepresentations: [WidgetColorScheme: DisplayRepresentation] = [
        .quantum: DisplayRepresentation(title: "Quantum"),
        .nature: DisplayRepresentation(title: "Nature"),
        .calm: DisplayRepresentation(title: "Calm"),
        .energy: DisplayRepresentation(title: "Energy")
    ]
}

// MARK: - Coherence Timeline Provider

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct CoherenceTimelineProvider: AppIntentTimelineProvider {

    func placeholder(in context: Context) -> CoherenceEntry {
        CoherenceEntry(
            date: Date(),
            coherence: 0.65,
            hrv: 55,
            trend: .stable,
            configuration: CoherenceWidgetIntent()
        )
    }

    func snapshot(for configuration: CoherenceWidgetIntent, in context: Context) async -> CoherenceEntry {
        // Return current data
        let store = QuantumDataStore.shared
        return CoherenceEntry(
            date: Date(),
            coherence: store.coherenceLevel,
            hrv: store.hrvCoherence,
            trend: .stable,
            configuration: configuration
        )
    }

    func timeline(for configuration: CoherenceWidgetIntent, in context: Context) async -> WidgetKit.Timeline<CoherenceEntry> {
        var entries: [CoherenceEntry] = []
        let currentDate = Date()
        let store = QuantumDataStore.shared

        // Generate entries for next hour
        for minuteOffset in 0..<60 {
            let entryDate = Calendar.current.date(byAdding: .minute, value: minuteOffset, to: currentDate)!

            let entry = CoherenceEntry(
                date: entryDate,
                coherence: store.coherenceLevel,
                hrv: store.hrvCoherence,
                trend: .stable,
                configuration: configuration
            )
            entries.append(entry)
        }

        return WidgetKit.Timeline(entries: entries, policy: .atEnd)
    }
}

// MARK: - Coherence Entry

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct CoherenceEntry: TimelineEntry {
    let date: Date
    let coherence: Double
    let hrv: Double
    let trend: CoherenceTrend
    let configuration: CoherenceWidgetIntent

    enum CoherenceTrend {
        case increasing, decreasing, stable
    }
}

// MARK: - Coherence Widget View

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct CoherenceWidgetView: View {
    var entry: CoherenceEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .systemSmall:
            SmallCoherenceView(entry: entry)
        case .systemMedium:
            MediumCoherenceView(entry: entry)
        case .accessoryCircular:
            CircularCoherenceView(entry: entry)
        case .accessoryRectangular:
            RectangularCoherenceView(entry: entry)
        default:
            SmallCoherenceView(entry: entry)
        }
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct SmallCoherenceView: View {
    let entry: CoherenceEntry

    var body: some View {
        VStack(spacing: 8) {
            // Coherence Ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)

                Circle()
                    .trim(from: 0, to: CGFloat(entry.coherence))
                    .stroke(
                        coherenceGradient,
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(Int(entry.coherence * 100))")
                        .font(.system(size: 28, weight: .bold, design: .rounded))

                    Text("coherence")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 80, height: 80)

            if entry.configuration.showHRV {
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundColor(.red)

                    Text("\(Int(entry.hrv))% HRV")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private var coherenceGradient: AngularGradient {
        AngularGradient(
            colors: colorsForScheme(entry.configuration.colorScheme),
            center: .center,
            startAngle: .degrees(0),
            endAngle: .degrees(360 * Double(entry.coherence))
        )
    }

    private func colorsForScheme(_ scheme: WidgetColorScheme) -> [Color] {
        switch scheme {
        case .quantum:
            return [.purple, .cyan, .blue]
        case .nature:
            return [.green, .mint, .teal]
        case .calm:
            return [.blue, .indigo, .purple]
        case .energy:
            return [.orange, .red, .pink]
        }
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct MediumCoherenceView: View {
    let entry: CoherenceEntry

    var body: some View {
        HStack(spacing: 20) {
            // Coherence Ring
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 10)

                Circle()
                    .trim(from: 0, to: CGFloat(entry.coherence))
                    .stroke(
                        LinearGradient(colors: [.purple, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing),
                        style: StrokeStyle(lineWidth: 10, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 2) {
                    Text("\(Int(entry.coherence * 100))%")
                        .font(.system(size: 24, weight: .bold, design: .rounded))

                    Text("Quantum")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .frame(width: 100, height: 100)

            // Stats
            VStack(alignment: .leading, spacing: 12) {
                StatRow(icon: "waveform.path.ecg", title: "HRV Coherence", value: "\(Int(entry.hrv))%", color: .green)

                StatRow(icon: "arrow.up.right", title: "Trend", value: trendText, color: trendColor)

                StatRow(icon: "clock", title: "Updated", value: timeText, color: .gray)
            }

            Spacer()
        }
        .padding()
    }

    private var trendText: String {
        switch entry.trend {
        case .increasing: return "Rising"
        case .decreasing: return "Falling"
        case .stable: return "Stable"
        }
    }

    private var trendColor: Color {
        switch entry.trend {
        case .increasing: return .green
        case .decreasing: return .orange
        case .stable: return .blue
        }
    }

    private var timeText: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: entry.date)
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct StatRow: View {
    let icon: String
    let title: String
    let value: String
    let color: Color

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundColor(color)
                .frame(width: 20)

            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.caption.bold())
        }
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct CircularCoherenceView: View {
    let entry: CoherenceEntry

    var body: some View {
        Gauge(value: Double(entry.coherence)) {
            Image(systemName: "atom")
        } currentValueLabel: {
            Text("\(Int(entry.coherence * 100))")
        }
        .gaugeStyle(.accessoryCircular)
        .tint(Gradient(colors: [.purple, .cyan]))
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct RectangularCoherenceView: View {
    let entry: CoherenceEntry

    var body: some View {
        VStack(alignment: .leading) {
            HStack {
                Image(systemName: "atom")
                Text("Quantum Coherence")
            }
            .font(.caption2)

            Text("\(Int(entry.coherence * 100))%")
                .font(.title2.bold())

            Gauge(value: Double(entry.coherence)) { }
                .gaugeStyle(.accessoryLinear)
                .tint(Gradient(colors: [.purple, .cyan]))
        }
    }
}

// MARK: - Quick Session Widget

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct QuickSessionWidget: Widget {
    let kind: String = "QuickSessionWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: QuickSessionProvider()) { entry in
            QuickSessionWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Quick Session")
        .description("Start a quantum session with one tap")
        .supportedFamilies([.systemSmall])
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct QuickSessionProvider: TimelineProvider {
    func placeholder(in context: Context) -> QuickSessionEntry {
        QuickSessionEntry(date: Date(), isActive: false)
    }

    func getSnapshot(in context: Context, completion: @escaping (QuickSessionEntry) -> Void) {
        completion(QuickSessionEntry(date: Date(), isActive: false))
    }

    func getTimeline(in context: Context, completion: @escaping (WidgetKit.Timeline<QuickSessionEntry>) -> Void) {
        let entry = QuickSessionEntry(date: Date(), isActive: QuantumDataStore.shared.isQuantumActive)
        let timeline = WidgetKit.Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(60)))
        completion(timeline)
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct QuickSessionEntry: TimelineEntry {
    let date: Date
    let isActive: Bool
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct QuickSessionWidgetView: View {
    var entry: QuickSessionEntry

    var body: some View {
        Link(destination: safeDeepLink("start-session")) {
            VStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(
                            entry.isActive
                            ? LinearGradient(colors: [.green, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                            : LinearGradient(colors: [.purple, .blue], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .frame(width: 60, height: 60)

                    Image(systemName: entry.isActive ? "pause.fill" : "play.fill")
                        .font(.title2)
                        .foregroundColor(.white)
                }

                Text(entry.isActive ? "Tap to Pause" : "Start Session")
                    .font(.caption.bold())

                Text("Quantum Light")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

// MARK: - Preset Widget

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct PresetWidget: Widget {
    let kind: String = "PresetWidget"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(
            kind: kind,
            intent: PresetWidgetIntent.self,
            provider: PresetTimelineProvider()
        ) { entry in
            PresetWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Quantum Preset")
        .description("Quick access to your favorite preset")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct PresetWidgetIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Preset Widget"
    static var description = IntentDescription("Select a preset to display")

    @Parameter(title: "Preset")
    var presetId: String?

    init() {}

    init(presetId: String?) {
        self.presetId = presetId
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct PresetTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> PresetEntry {
        PresetEntry(date: Date(), preset: BuiltInPresets.deepMeditation, configuration: PresetWidgetIntent())
    }

    func snapshot(for configuration: PresetWidgetIntent, in context: Context) async -> PresetEntry {
        let preset = findPreset(id: configuration.presetId) ?? BuiltInPresets.deepMeditation
        return PresetEntry(date: Date(), preset: preset, configuration: configuration)
    }

    func timeline(for configuration: PresetWidgetIntent, in context: Context) async -> WidgetKit.Timeline<PresetEntry> {
        let preset = findPreset(id: configuration.presetId) ?? BuiltInPresets.deepMeditation
        let entry = PresetEntry(date: Date(), preset: preset, configuration: configuration)
        return WidgetKit.Timeline(entries: [entry], policy: .never)
    }

    private func findPreset(id: String?) -> QuantumPreset? {
        guard let id = id else { return nil }
        // Use BuiltInPresets.all directly to avoid MainActor isolation issues in widget timeline providers
        return BuiltInPresets.all.first { $0.id == id }
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct PresetEntry: TimelineEntry {
    let date: Date
    let preset: QuantumPreset
    let configuration: PresetWidgetIntent
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct PresetWidgetView: View {
    var entry: PresetEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        Link(destination: safeDeepLink("preset/\(entry.preset.id)")) {
            switch family {
            case .systemSmall:
                SmallPresetView(preset: entry.preset)
            case .systemMedium:
                MediumPresetView(preset: entry.preset)
            default:
                SmallPresetView(preset: entry.preset)
            }
        }
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct SmallPresetView: View {
    let preset: QuantumPreset

    var body: some View {
        VStack(spacing: 8) {
            Text(preset.icon)
                .font(.system(size: 40))

            Text(preset.name)
                .font(.caption.bold())
                .lineLimit(1)

            Text(preset.category.rawValue)
                .font(.caption2)
                .foregroundColor(.secondary)

            HStack(spacing: 4) {
                Image(systemName: "clock")
                Text("\(Int(preset.sessionDuration / 60))m")
            }
            .font(.caption2)
            .foregroundColor(.secondary)
        }
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct MediumPresetView: View {
    let preset: QuantumPreset

    var body: some View {
        HStack(spacing: 16) {
            Text(preset.icon)
                .font(.system(size: 50))

            VStack(alignment: .leading, spacing: 4) {
                Text(preset.name)
                    .font(.headline)

                Text(preset.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)

                HStack {
                    Label("\(Int(preset.sessionDuration / 60)) min", systemImage: "clock")
                    Label(preset.emulationMode, systemImage: "atom")
                }
                .font(.caption2)
                .foregroundColor(.secondary)
            }

            Spacer()

            Image(systemName: "play.circle.fill")
                .font(.largeTitle)
                .foregroundColor(.purple)
        }
        .padding()
    }
}

// MARK: - Visualization Widget

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct VisualizationWidget: Widget {
    let kind: String = "VisualizationWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VisualizationProvider()) { entry in
            VisualizationWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Quantum Visualization")
        .description("Beautiful quantum-inspired patterns")
        .supportedFamilies([.systemMedium, .systemLarge])
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct VisualizationProvider: TimelineProvider {
    func placeholder(in context: Context) -> VisualizationEntry {
        VisualizationEntry(date: Date(), visualizationType: .coherenceField, coherence: 0.7)
    }

    func getSnapshot(in context: Context, completion: @escaping (VisualizationEntry) -> Void) {
        completion(VisualizationEntry(date: Date(), visualizationType: .coherenceField, coherence: 0.7))
    }

    func getTimeline(in context: Context, completion: @escaping (WidgetKit.Timeline<VisualizationEntry>) -> Void) {
        var entries: [VisualizationEntry] = []
        let currentDate = Date()
        let visualizations = WidgetVisualizationType.allCases

        // Rotate through visualizations every 15 minutes
        for (index, viz) in visualizations.enumerated() {
            let entryDate = Calendar.current.date(byAdding: .minute, value: index * 15, to: currentDate)!
            entries.append(VisualizationEntry(
                date: entryDate,
                visualizationType: viz,
                coherence: Float.random(in: 0.4...0.9)
            ))
        }

        let timeline = WidgetKit.Timeline(entries: entries, policy: .atEnd)
        completion(timeline)
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct VisualizationEntry: TimelineEntry {
    let date: Date
    let visualizationType: WidgetVisualizationType
    let coherence: Float
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct VisualizationWidgetView: View {
    var entry: VisualizationEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        ZStack {
            // Background visualization
            WidgetVisualizationCanvas(type: entry.visualizationType, coherence: entry.coherence)

            // Overlay info
            VStack {
                Spacer()

                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.visualizationType.rawValue)
                            .font(.caption.bold())

                        Text("Tap to open")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    CircularCoherenceGauge(coherence: entry.coherence)
                        .frame(width: 50, height: 50)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
        }
        .widgetURL(safeDeepLink("visualization/\(entry.visualizationType.rawValue)"))
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct WidgetVisualizationCanvas: View {
    let type: WidgetVisualizationType
    let coherence: Float

    var body: some View {
        Canvas { context, size in
            drawVisualization(context: context, size: size)
        }
        .background(
            LinearGradient(
                colors: gradientColors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private var gradientColors: [Color] {
        switch type {
        case .interferencePattern, .waveFunction:
            return [.blue.opacity(0.8), .purple.opacity(0.6)]
        case .coherenceField, .photonFlow:
            return [.purple.opacity(0.8), .pink.opacity(0.6)]
        case .sacredGeometry, .lightMandala:
            return [.yellow.opacity(0.6), .orange.opacity(0.4)]
        case .quantumTunnel, .holographicDisplay:
            return [.cyan.opacity(0.8), .blue.opacity(0.6)]
        case .biophotonAura:
            return [.green.opacity(0.6), .teal.opacity(0.4)]
        case .cosmicWeb:
            return [.indigo.opacity(0.8), .black.opacity(0.9)]
        }
    }

    private func drawVisualization(context: GraphicsContext, size: CGSize) {
        let center = CGPoint(x: size.width / 2, y: size.height / 2)
        let coherenceValue = CGFloat(coherence)

        // Simplified visualization for widget
        let rings = Int(5 + coherenceValue * 10)
        for i in 0..<rings {
            let progress = CGFloat(i) / CGFloat(rings)
            let radius = progress * min(size.width, size.height) * 0.4
            let opacity = 1.0 - progress * 0.7

            let circle = Path(ellipseIn: CGRect(
                x: center.x - radius,
                y: center.y - radius,
                width: radius * 2,
                height: radius * 2
            ))

            context.stroke(
                circle,
                with: .color(.white.opacity(opacity)),
                lineWidth: 1.5
            )
        }
    }
}

@available(iOS 17.0, macOS 14.0, watchOS 10.0, *)
struct CircularCoherenceGauge: View {
    let coherence: Float

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 4)

            Circle()
                .trim(from: 0, to: CGFloat(coherence))
                .stroke(Color.white, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                .rotationEffect(.degrees(-90))

            Text("\(Int(coherence * 100))")
                .font(.caption2.bold())
                .foregroundColor(.white)
        }
    }
}
