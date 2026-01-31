//
//  QuantumCoherenceComplication.swift
//  Echoelmusic
//
//  watchOS Complications for Quantum Coherence and Bio-Data
//  A+++ Apple Watch integration
//
//  Created: 2026-01-05
//

#if os(watchOS)
import SwiftUI
import ClockKit
import WidgetKit

// MARK: - Complication Data Provider

@available(watchOS 9.0, *)
public class QuantumComplicationDataSource: NSObject, CLKComplicationDataSource {

    // Shared data store
    private let dataStore = QuantumDataStore.shared

    // MARK: - Supported Complications

    public func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
        let descriptors = [
            CLKComplicationDescriptor(
                identifier: "quantum-coherence",
                displayName: "Quantum Coherence",
                supportedFamilies: CLKComplicationFamily.allCases
            ),
            CLKComplicationDescriptor(
                identifier: "bio-sync",
                displayName: "Bio-Sync Status",
                supportedFamilies: [.circularSmall, .graphicCorner, .graphicCircular]
            ),
            CLKComplicationDescriptor(
                identifier: "light-field",
                displayName: "Light Field",
                supportedFamilies: [.graphicRectangular, .graphicExtraLarge]
            )
        ]
        handler(descriptors)
    }

    // MARK: - Timeline Configuration

    public func getTimelineEndDate(
        for complication: CLKComplication,
        withHandler handler: @escaping (Date?) -> Void
    ) {
        // Update every minute
        handler(Date().addingTimeInterval(60 * 60))
    }

    public func getPrivacyBehavior(
        for complication: CLKComplication,
        withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void
    ) {
        // Bio-data should be hidden on lock screen
        handler(.hideOnLockScreen)
    }

    // MARK: - Current Timeline Entry

    public func getCurrentTimelineEntry(
        for complication: CLKComplication,
        withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void
    ) {
        let template = createTemplate(for: complication, date: Date())
        if let template = template {
            let entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
            handler(entry)
        } else {
            handler(nil)
        }
    }

    // MARK: - Timeline Entries

    public func getTimelineEntries(
        for complication: CLKComplication,
        after date: Date,
        limit: Int,
        withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void
    ) {
        var entries: [CLKComplicationTimelineEntry] = []

        // Generate entries for next hour (every 5 minutes)
        for i in 0..<min(limit, 12) {
            let entryDate = date.addingTimeInterval(TimeInterval(i * 5 * 60))
            if let template = createTemplate(for: complication, date: entryDate) {
                entries.append(CLKComplicationTimelineEntry(date: entryDate, complicationTemplate: template))
            }
        }

        handler(entries)
    }

    // MARK: - Template Creation

    private func createTemplate(for complication: CLKComplication, date: Date) -> CLKComplicationTemplate? {
        let coherence = Float(dataStore.coherenceLevel) // Convert Double to Float for ClockKit
        let heartRate = dataStore.heartRate
        let hrvCoherence = dataStore.hrvCoherence

        switch complication.family {
        case .circularSmall:
            return createCircularSmallTemplate(coherence: coherence)

        case .modularSmall:
            return createModularSmallTemplate(coherence: coherence)

        case .modularLarge:
            return createModularLargeTemplate(coherence: coherence, heartRate: heartRate)

        case .utilitarianSmall, .utilitarianSmallFlat:
            return createUtilitarianSmallTemplate(coherence: coherence)

        case .utilitarianLarge:
            return createUtilitarianLargeTemplate(coherence: coherence, hrvCoherence: hrvCoherence)

        case .extraLarge:
            return createExtraLargeTemplate(coherence: coherence)

        case .graphicCorner:
            return createGraphicCornerTemplate(coherence: coherence)

        case .graphicCircular:
            return createGraphicCircularTemplate(coherence: coherence)

        case .graphicRectangular:
            return createGraphicRectangularTemplate(
                coherence: coherence,
                heartRate: heartRate,
                hrvCoherence: hrvCoherence
            )

        case .graphicBezel:
            return createGraphicBezelTemplate(coherence: coherence)

        case .graphicExtraLarge:
            return createGraphicExtraLargeTemplate(coherence: coherence)

        @unknown default:
            return nil
        }
    }

    // MARK: - Circular Small

    private func createCircularSmallTemplate(coherence: Float) -> CLKComplicationTemplate {
        let gaugeProvider = CLKSimpleGaugeProvider(
            style: .fill,
            gaugeColor: coherenceColor(coherence),
            fillFraction: coherence
        )

        return CLKComplicationTemplateCircularSmallSimpleImage(
            imageProvider: CLKImageProvider(onePieceImage: safeSystemImage("waveform.circle.fill"))
        )
    }

    // MARK: - Modular Small

    private func createModularSmallTemplate(coherence: Float) -> CLKComplicationTemplate {
        return CLKComplicationTemplateModularSmallSimpleImage(
            imageProvider: CLKImageProvider(onePieceImage: safeSystemImage("atom"))
        )
    }

    // MARK: - Modular Large

    private func createModularLargeTemplate(coherence: Float, heartRate: Double) -> CLKComplicationTemplate {
        let headerProvider = CLKSimpleTextProvider(text: "Quantum")
        let body1Provider = CLKSimpleTextProvider(text: "Coherence: \(Int(coherence * 100))%")
        let body2Provider = CLKSimpleTextProvider(text: "HR: \(Int(heartRate)) BPM")

        return CLKComplicationTemplateModularLargeStandardBody(
            headerTextProvider: headerProvider,
            body1TextProvider: body1Provider,
            body2TextProvider: body2Provider
        )
    }

    // MARK: - Utilitarian Small

    private func createUtilitarianSmallTemplate(coherence: Float) -> CLKComplicationTemplate {
        return CLKComplicationTemplateUtilitarianSmallFlat(
            textProvider: CLKSimpleTextProvider(text: "\(Int(coherence * 100))%")
        )
    }

    // MARK: - Utilitarian Large

    private func createUtilitarianLargeTemplate(coherence: Float, hrvCoherence: Double) -> CLKComplicationTemplate {
        return CLKComplicationTemplateUtilitarianLargeFlat(
            textProvider: CLKSimpleTextProvider(text: "Q:\(Int(coherence * 100))% HRV:\(Int(hrvCoherence))%")
        )
    }

    // MARK: - Extra Large

    private func createExtraLargeTemplate(coherence: Float) -> CLKComplicationTemplate {
        return CLKComplicationTemplateExtraLargeSimpleImage(
            imageProvider: CLKImageProvider(onePieceImage: safeSystemImage("waveform.circle.fill"))
        )
    }

    // MARK: - Graphic Corner

    private func createGraphicCornerTemplate(coherence: Float) -> CLKComplicationTemplate {
        let gaugeProvider = CLKSimpleGaugeProvider(
            style: .fill,
            gaugeColor: coherenceColor(coherence),
            fillFraction: coherence
        )

        let textProvider = CLKSimpleTextProvider(text: "\(Int(coherence * 100))%")

        return CLKComplicationTemplateGraphicCornerGaugeText(
            gaugeProvider: gaugeProvider,
            outerTextProvider: textProvider
        )
    }

    // MARK: - Graphic Circular

    private func createGraphicCircularTemplate(coherence: Float) -> CLKComplicationTemplate {
        let gaugeProvider = CLKSimpleGaugeProvider(
            style: .ring,
            gaugeColor: coherenceColor(coherence),
            fillFraction: coherence
        )

        return CLKComplicationTemplateGraphicCircularClosedGaugeImage(
            gaugeProvider: gaugeProvider,
            imageProvider: CLKFullColorImageProvider(fullColorImage: safeSystemImage("atom"))
        )
    }

    // MARK: - Graphic Rectangular

    private func createGraphicRectangularTemplate(
        coherence: Float,
        heartRate: Double,
        hrvCoherence: Double
    ) -> CLKComplicationTemplate {
        let headerProvider = CLKSimpleTextProvider(text: "QUANTUM LIGHT")
        let body1Provider = CLKSimpleTextProvider(text: "Coherence: \(Int(coherence * 100))%")

        let gaugeProvider = CLKSimpleGaugeProvider(
            style: .fill,
            gaugeColor: coherenceColor(coherence),
            fillFraction: coherence
        )

        return CLKComplicationTemplateGraphicRectangularTextGauge(
            headerTextProvider: headerProvider,
            body1TextProvider: body1Provider,
            gaugeProvider: gaugeProvider
        )
    }

    // MARK: - Graphic Bezel

    private func createGraphicBezelTemplate(coherence: Float) -> CLKComplicationTemplate {
        let circularTemplate = createGraphicCircularTemplate(coherence: coherence)

        // Safe cast with fallback
        guard let graphicCircular = circularTemplate as? CLKComplicationTemplateGraphicCircular else {
            // Fallback: return the circular template itself if cast fails
            return circularTemplate
        }

        return CLKComplicationTemplateGraphicBezelCircularText(
            circularTemplate: graphicCircular,
            textProvider: CLKSimpleTextProvider(text: "Quantum \(Int(coherence * 100))%")
        )
    }

    // MARK: - Graphic Extra Large

    private func createGraphicExtraLargeTemplate(coherence: Float) -> CLKComplicationTemplate {
        let gaugeProvider = CLKSimpleGaugeProvider(
            style: .fill,
            gaugeColor: coherenceColor(coherence),
            fillFraction: coherence
        )

        return CLKComplicationTemplateGraphicExtraLargeCircularClosedGaugeImage(
            gaugeProvider: gaugeProvider,
            imageProvider: CLKFullColorImageProvider(fullColorImage: safeSystemImage("waveform.circle.fill"))
        )
    }

    // MARK: - Helpers

    /// Safe system image loader with fallback
    private func safeSystemImage(_ name: String) -> UIImage {
        UIImage(systemName: name) ?? UIImage()
    }

    private func coherenceColor(_ coherence: Float) -> UIColor {
        if coherence > 0.7 {
            return .green
        } else if coherence > 0.4 {
            return .yellow
        } else {
            return .orange
        }
    }
}

// MARK: - Quantum Data Store Extension for watchOS
// NOTE: Uses Core/QuantumDataStore.swift with App Groups for cross-device sync

@available(watchOS 8.0, *)
extension QuantumDataStore {
    /// Update biometrics and trigger complication reload
    public func updateAndReloadComplications(
        coherence: Double,
        heartRate: Double,
        hrvCoherence: Double,
        breathingRate: Double
    ) {
        // Update shared data store (syncs via App Groups)
        self.coherenceLevel = coherence
        self.heartRate = heartRate
        self.hrvValue = hrvCoherence
        self.breathingRate = breathingRate

        // Trigger complication update
        reloadComplications()
    }

    private func reloadComplications() {
        let server = CLKComplicationServer.sharedInstance()
        for complication in server.activeComplications ?? [] {
            server.reloadTimeline(for: complication)
        }
    }
}

// MARK: - Watch App Views

@available(watchOS 8.0, *)
public struct QuantumWatchView: View {
    private let dataStore = QuantumDataStore.shared

    public init() {}

    public var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                // Coherence Ring
                CoherenceRingView(coherence: CGFloat(dataStore.coherenceLevel))
                    .frame(height: 100)

                // Status Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    StatCard(
                        title: "Heart Rate",
                        value: "\(Int(dataStore.heartRate))",
                        unit: "BPM",
                        icon: "heart.fill",
                        color: .red
                    )

                    StatCard(
                        title: "HRV",
                        value: "\(Int(dataStore.hrvCoherence))",
                        unit: "%",
                        icon: "waveform.path.ecg",
                        color: .green
                    )

                    StatCard(
                        title: "Breathing",
                        value: String(format: "%.1f", dataStore.breathingRate),
                        unit: "/min",
                        icon: "wind",
                        color: .cyan
                    )

                    StatCard(
                        title: "Entangled",
                        value: "\(dataStore.entanglementCount)",
                        unit: "devices",
                        icon: "link",
                        color: .purple
                    )
                }

                // Quick Actions
                HStack {
                    Button(action: { /* Start quantum session */ }) {
                        Image(systemName: dataStore.isQuantumActive ? "pause.fill" : "play.fill")
                    }
                    .buttonStyle(.bordered)
                    .tint(dataStore.isQuantumActive ? .red : .green)

                    Button(action: { /* Sync to phone */ }) {
                        Image(systemName: "iphone.radiowaves.left.and.right")
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()
        }
        .navigationTitle("Quantum")
    }
}

@available(watchOS 8.0, *)
struct CoherenceRingView: View {
    let coherence: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: 10)

            Circle()
                .trim(from: 0, to: coherence)
                .stroke(
                    AngularGradient(
                        colors: [.red, .yellow, .green, .cyan],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * Double(coherence))
                    ),
                    style: StrokeStyle(lineWidth: 10, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))

            VStack(spacing: 2) {
                Text("\(Int(coherence * 100))")
                    .font(.system(size: 28, weight: .bold, design: .rounded))

                Text("Quantum")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
    }
}

@available(watchOS 8.0, *)
struct StatCard: View {
    let title: String
    let value: String
    let unit: String
    let icon: String
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

#endif

// NOTE: Cross-platform QuantumDataStore is now in Core/QuantumDataStore.swift
// Uses App Groups for data sharing between iPhone, iPad, Apple Watch, etc.
