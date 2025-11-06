import ClockKit
import SwiftUI

/// Complication provider for Apple Watch face
///
/// **Purpose:** Display HRV and coherence on watch face for quick glance
///
/// **Supported Families:**
/// - Circular Small: HRV value
/// - Rectangular: HRV + Coherence
/// - Graphic Corner: Circular gauge
/// - Graphic Circular: Coherence gauge
/// - Graphic Rectangular: Full stats
///
/// **Update Frequency:** Every 5-15 minutes (ClockKit limit)
///
/// **Platform:** watchOS 7.0+
///
class WatchComplicationProvider: NSObject, CLKComplicationDataSource {

    // MARK: - Timeline

    func getCurrentTimelineEntry(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void) {
        // Get current HRV and coherence from HealthKit
        let hrv = UserDefaults.standard.double(forKey: "lastHRV")
        let coherence = UserDefaults.standard.double(forKey: "lastCoherence")

        let entry = createTimelineEntry(
            for: complication,
            hrv: hrv,
            coherence: coherence,
            date: Date()
        )

        handler(entry)
    }

    func getTimelineEntries(
        for complication: CLKComplication,
        after date: Date,
        limit: Int,
        withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void
    ) {
        // Generate future entries (placeholder data)
        var entries: [CLKComplicationTimelineEntry] = []

        let hrv = UserDefaults.standard.double(forKey: "lastHRV")
        let coherence = UserDefaults.standard.double(forKey: "lastCoherence")

        for i in 0..<min(limit, 24) { // Up to 24 entries (hourly)
            let entryDate = date.addingTimeInterval(TimeInterval(i * 3600)) // Every hour

            if let entry = createTimelineEntry(
                for: complication,
                hrv: hrv,
                coherence: coherence,
                date: entryDate
            ) {
                entries.append(entry)
            }
        }

        handler(entries)
    }

    // MARK: - Placeholder

    func getLocalizableSampleTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        let template = createTemplate(
            for: complication,
            hrv: 45.0,
            coherence: 75.0
        )
        handler(template)
    }

    func getPlaceholderTemplate(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationTemplate?) -> Void) {
        let template = createTemplate(
            for: complication,
            hrv: 45.0,
            coherence: 75.0
        )
        handler(template)
    }

    // MARK: - Privacy

    func getPrivacyBehavior(for complication: CLKComplication, withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void) {
        // Show actual data (health info is personal but user opts in)
        handler(.showOnLockScreen)
    }

    // MARK: - Descriptor

    func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
        let descriptors = [
            CLKComplicationDescriptor(
                identifier: "echoelmusic_hrv",
                displayName: "Echoelmusic HRV",
                supportedFamilies: [
                    .circularSmall,
                    .modularSmall,
                    .modularLarge,
                    .utilitarianSmall,
                    .utilitarianLarge,
                    .graphicCorner,
                    .graphicCircular,
                    .graphicRectangular
                ]
            )
        ]

        handler(descriptors)
    }

    // MARK: - Template Creation

    private func createTimelineEntry(
        for complication: CLKComplication,
        hrv: Double,
        coherence: Double,
        date: Date
    ) -> CLKComplicationTimelineEntry? {
        guard let template = createTemplate(
            for: complication,
            hrv: hrv,
            coherence: coherence
        ) else {
            return nil
        }

        return CLKComplicationTimelineEntry(date: date, complicationTemplate: template)
    }

    private func createTemplate(
        for complication: CLKComplication,
        hrv: Double,
        coherence: Double
    ) -> CLKComplicationTemplate? {
        switch complication.family {
        case .circularSmall:
            return createCircularSmallTemplate(hrv: hrv)

        case .modularSmall:
            return createModularSmallTemplate(hrv: hrv, coherence: coherence)

        case .modularLarge:
            return createModularLargeTemplate(hrv: hrv, coherence: coherence)

        case .utilitarianSmall:
            return createUtilitarianSmallTemplate(hrv: hrv)

        case .utilitarianLarge:
            return createUtilitarianLargeTemplate(hrv: hrv, coherence: coherence)

        case .graphicCorner:
            return createGraphicCornerTemplate(hrv: hrv, coherence: coherence)

        case .graphicCircular:
            return createGraphicCircularTemplate(coherence: coherence)

        case .graphicRectangular:
            return createGraphicRectangularTemplate(hrv: hrv, coherence: coherence)

        case .graphicBezel:
            return createGraphicBezelTemplate(hrv: hrv, coherence: coherence)

        case .graphicExtraLarge:
            return createGraphicExtraLargeTemplate(coherence: coherence)

        default:
            return nil
        }
    }

    // MARK: - Template Implementations

    private func createCircularSmallTemplate(hrv: Double) -> CLKComplicationTemplate {
        let template = CLKComplicationTemplateCircularSmallStackText()
        template.line1TextProvider = CLKSimpleTextProvider(text: "\(Int(hrv))")
        template.line2TextProvider = CLKSimpleTextProvider(text: "HRV")
        return template
    }

    private func createModularSmallTemplate(hrv: Double, coherence: Double) -> CLKComplicationTemplate {
        let template = CLKComplicationTemplateModularSmallStackText()
        template.line1TextProvider = CLKSimpleTextProvider(text: "\(Int(hrv))")
        template.line2TextProvider = CLKSimpleTextProvider(text: "ms")
        return template
    }

    private func createModularLargeTemplate(hrv: Double, coherence: Double) -> CLKComplicationTemplate {
        let template = CLKComplicationTemplateModularLargeStandardBody()
        template.headerTextProvider = CLKSimpleTextProvider(text: "Echoelmusic")
        template.body1TextProvider = CLKSimpleTextProvider(text: "HRV: \(Int(hrv)) ms")
        template.body2TextProvider = CLKSimpleTextProvider(text: "Coherence: \(Int(coherence))%")
        return template
    }

    private func createUtilitarianSmallTemplate(hrv: Double) -> CLKComplicationTemplate {
        let template = CLKComplicationTemplateUtilitarianSmallFlat()
        template.textProvider = CLKSimpleTextProvider(text: "\(Int(hrv)) ms")
        return template
    }

    private func createUtilitarianLargeTemplate(hrv: Double, coherence: Double) -> CLKComplicationTemplate {
        let template = CLKComplicationTemplateUtilitarianLargeFlat()
        template.textProvider = CLKSimpleTextProvider(text: "HRV \(Int(hrv)) • \(Int(coherence))% coherence")
        return template
    }

    @available(watchOS 7.0, *)
    private func createGraphicCornerTemplate(hrv: Double, coherence: Double) -> CLKComplicationTemplate {
        let gaugeProvider = CLKSimpleGaugeProvider(
            style: .fill,
            gaugeColor: coherenceColor(coherence),
            fillFraction: Float(coherence / 100.0)
        )

        let template = CLKComplicationTemplateGraphicCornerGaugeText()
        template.gaugeProvider = gaugeProvider
        template.outerTextProvider = CLKSimpleTextProvider(text: "\(Int(hrv))")
        return template
    }

    @available(watchOS 7.0, *)
    private func createGraphicCircularTemplate(coherence: Double) -> CLKComplicationTemplate {
        let gaugeProvider = CLKSimpleGaugeProvider(
            style: .fill,
            gaugeColor: coherenceColor(coherence),
            fillFraction: Float(coherence / 100.0)
        )

        let template = CLKComplicationTemplateGraphicCircularClosedGaugeText()
        template.gaugeProvider = gaugeProvider
        template.centerTextProvider = CLKSimpleTextProvider(text: "\(Int(coherence))%")
        return template
    }

    @available(watchOS 7.0, *)
    private func createGraphicRectangularTemplate(hrv: Double, coherence: Double) -> CLKComplicationTemplate {
        let gaugeProvider = CLKSimpleGaugeProvider(
            style: .fill,
            gaugeColor: coherenceColor(coherence),
            fillFraction: Float(coherence / 100.0)
        )

        let template = CLKComplicationTemplateGraphicRectangularStandardBody()
        template.headerTextProvider = CLKSimpleTextProvider(text: "Echoelmusic")
        template.body1TextProvider = CLKSimpleTextProvider(text: "HRV: \(Int(hrv)) ms")
        template.body2TextProvider = CLKSimpleTextProvider(text: "Coherence: \(Int(coherence))%")
        return template
    }

    @available(watchOS 7.0, *)
    private func createGraphicBezelTemplate(hrv: Double, coherence: Double) -> CLKComplicationTemplate {
        let gaugeProvider = CLKSimpleGaugeProvider(
            style: .fill,
            gaugeColor: coherenceColor(coherence),
            fillFraction: Float(coherence / 100.0)
        )

        let circularTemplate = CLKComplicationTemplateGraphicCircularClosedGaugeText()
        circularTemplate.gaugeProvider = gaugeProvider
        circularTemplate.centerTextProvider = CLKSimpleTextProvider(text: "\(Int(coherence))%")

        let template = CLKComplicationTemplateGraphicBezelCircularText()
        template.circularTemplate = circularTemplate
        template.textProvider = CLKSimpleTextProvider(text: "HRV: \(Int(hrv)) ms")
        return template
    }

    @available(watchOS 7.0, *)
    private func createGraphicExtraLargeTemplate(coherence: Double) -> CLKComplicationTemplate {
        let gaugeProvider = CLKSimpleGaugeProvider(
            style: .fill,
            gaugeColor: coherenceColor(coherence),
            fillFraction: Float(coherence / 100.0)
        )

        let template = CLKComplicationTemplateGraphicExtraLargeCircularClosedGaugeText()
        template.gaugeProvider = gaugeProvider
        template.centerTextProvider = CLKSimpleTextProvider(text: "\(Int(coherence))%")
        return template
    }

    // MARK: - Helpers

    private func coherenceColor(_ coherence: Double) -> UIColor {
        if coherence >= 80 {
            return .systemGreen
        } else if coherence >= 60 {
            return .systemYellow
        } else if coherence >= 40 {
            return .systemOrange
        } else {
            return .systemRed
        }
    }
}

// MARK: - UserDefaults Extension

extension UserDefaults {
    /// Update complication data
    static func updateComplicationData(hrv: Double, coherence: Double) {
        standard.set(hrv, forKey: "lastHRV")
        standard.set(coherence, forKey: "lastCoherence")

        // Request complication update
        let server = CLKComplicationServer.sharedInstance()
        for complication in server.activeComplications ?? [] {
            server.reloadTimeline(for: complication)
        }
    }
}
