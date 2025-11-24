import Foundation
import ClockKit

#if os(watchOS)

/// EOEL Watch Complications
///
/// Zeigt Live-Bio-Daten direkt auf dem Watch Face:
/// - HRV (Heart Rate Variability)
/// - Coherence Level (Low/Medium/High mit Farbcodierung)
/// - Current Heart Rate
/// - Breathing Rate
///
/// Unterstützt alle Complication-Familien:
/// - Modular Small/Large
/// - Utilitarian Small/Large
/// - Circular Small
/// - Extra Large
/// - Graphic Corner/Circular/Rectangular/Bezel
///
@MainActor
class WatchComplicationController: NSObject, CLKComplicationDataSource {

    private let watchApp: WatchApp

    init(watchApp: WatchApp) {
        self.watchApp = watchApp
        super.init()
    }

    // MARK: - Timeline Configuration

    func getComplicationDescriptors(handler: @escaping ([CLKComplicationDescriptor]) -> Void) {
        let descriptors = [
            CLKComplicationDescriptor(
                identifier: "hrv",
                displayName: "HRV",
                supportedFamilies: CLKComplicationFamily.allCases
            ),
            CLKComplicationDescriptor(
                identifier: "coherence",
                displayName: "Kohärenz",
                supportedFamilies: CLKComplicationFamily.allCases
            )
        ]

        handler(descriptors)
    }

    func handleSharedComplicationDescriptors(_ complicationDescriptors: [CLKComplicationDescriptor]) {
        // Do nothing - we don't share complications
    }

    // MARK: - Timeline Population

    func getCurrentTimelineEntry(
        for complication: CLKComplication,
        withHandler handler: @escaping (CLKComplicationTimelineEntry?) -> Void
    ) {
        let data = watchApp.getComplicationData()
        let template = createTemplate(for: complication.family, data: data)

        if let template = template {
            let entry = CLKComplicationTimelineEntry(date: Date(), complicationTemplate: template)
            handler(entry)
        } else {
            handler(nil)
        }
    }

    func getTimelineEntries(
        for complication: CLKComplication,
        after date: Date,
        limit: Int,
        withHandler handler: @escaping ([CLKComplicationTimelineEntry]?) -> Void
    ) {
        // Complications update in real-time via getCurrentTimelineEntry
        handler(nil)
    }

    func getTimelineEndDate(
        for complication: CLKComplication,
        withHandler handler: @escaping (Date?) -> Void
    ) {
        // No end date - continuous updates
        handler(nil)
    }

    func getPrivacyBehavior(
        for complication: CLKComplication,
        withHandler handler: @escaping (CLKComplicationPrivacyBehavior) -> Void
    ) {
        handler(.showOnLockScreen)
    }

    // MARK: - Placeholder Templates

    func getLocalizableSampleTemplate(
        for complication: CLKComplication,
        withHandler handler: @escaping (CLKComplicationTemplate?) -> Void
    ) {
        let sampleData = WatchApp.ComplicationData(
            hrv: 0.75,
            coherence: 0.8,
            coherenceLevel: .high,
            timestamp: Date()
        )

        let template = createTemplate(for: complication.family, data: sampleData)
        handler(template)
    }

    // MARK: - Template Creation

    private func createTemplate(
        for family: CLKComplicationFamily,
        data: WatchApp.ComplicationData
    ) -> CLKComplicationTemplate? {

        switch family {
        case .modularSmall:
            return createModularSmallTemplate(data: data)

        case .modularLarge:
            return createModularLargeTemplate(data: data)

        case .utilitarianSmall:
            return createUtilitarianSmallTemplate(data: data)

        case .utilitarianLarge:
            return createUtilitarianLargeTemplate(data: data)

        case .circularSmall:
            return createCircularSmallTemplate(data: data)

        case .extraLarge:
            return createExtraLargeTemplate(data: data)

        case .graphicCorner:
            return createGraphicCornerTemplate(data: data)

        case .graphicCircular:
            return createGraphicCircularTemplate(data: data)

        case .graphicRectangular:
            return createGraphicRectangularTemplate(data: data)

        case .graphicBezel:
            return createGraphicBezelTemplate(data: data)

        case .graphicExtraLarge:
            if #available(watchOS 7.0, *) {
                return createGraphicExtraLargeTemplate(data: data)
            }
            return nil

        @unknown default:
            return nil
        }
    }

    // MARK: - Modular Family

    private func createModularSmallTemplate(data: WatchApp.ComplicationData) -> CLKComplicationTemplate {
        let template = CLKComplicationTemplateModularSmallSimpleText()
        template.textProvider = CLKSimpleTextProvider(text: String(format: "%.2f", data.hrv))
        return template
    }

    private func createModularLargeTemplate(data: WatchApp.ComplicationData) -> CLKComplicationTemplate {
        let template = CLKComplicationTemplateModularLargeStandardBody()
        template.headerTextProvider = CLKSimpleTextProvider(text: "EOEL")

        let hrvText = String(format: "HRV: %.2f", data.hrv)
        let coherenceText = String(format: "Kohärenz: %@", data.coherenceLevel.rawValue)

        template.body1TextProvider = CLKSimpleTextProvider(text: hrvText)
        template.body2TextProvider = CLKSimpleTextProvider(text: coherenceText)

        return template
    }

    // MARK: - Utilitarian Family

    private func createUtilitarianSmallTemplate(data: WatchApp.ComplicationData) -> CLKComplicationTemplate {
        let template = CLKComplicationTemplateUtilitarianSmallFlat()
        template.textProvider = CLKSimpleTextProvider(text: String(format: "%.2f", data.hrv))
        return template
    }

    private func createUtilitarianLargeTemplate(data: WatchApp.ComplicationData) -> CLKComplicationTemplate {
        let template = CLKComplicationTemplateUtilitarianLargeFlat()
        let text = String(format: "HRV %.2f • %@", data.hrv, data.coherenceLevel.rawValue)
        template.textProvider = CLKSimpleTextProvider(text: text)
        return template
    }

    // MARK: - Circular Family

    private func createCircularSmallTemplate(data: WatchApp.ComplicationData) -> CLKComplicationTemplate {
        let template = CLKComplicationTemplateCircularSmallSimpleText()
        template.textProvider = CLKSimpleTextProvider(text: String(format: "%.1f", data.hrv))
        return template
    }

    // MARK: - Extra Large

    private func createExtraLargeTemplate(data: WatchApp.ComplicationData) -> CLKComplicationTemplate {
        let template = CLKComplicationTemplateExtraLargeSimpleText()
        template.textProvider = CLKSimpleTextProvider(text: String(format: "%.2f", data.hrv))
        return template
    }

    // MARK: - Graphic Family (watchOS 5+)

    private func createGraphicCornerTemplate(data: WatchApp.ComplicationData) -> CLKComplicationTemplate {
        let template = CLKComplicationTemplateGraphicCornerTextView()
        template.textProvider = CLKSimpleTextProvider(text: "HRV")

        // Gauge zeigt Coherence
        let gaugeProvider = CLKSimpleGaugeProvider(
            style: .fill,
            gaugeColor: getCoherenceColor(level: data.coherenceLevel),
            fillFraction: Float(data.coherence)
        )

        if let template = template as? CLKComplicationTemplateGraphicCornerGaugeText {
            template.gaugeProvider = gaugeProvider
            template.outerTextProvider = CLKSimpleTextProvider(text: String(format: "%.2f", data.hrv))
        }

        return template
    }

    private func createGraphicCircularTemplate(data: WatchApp.ComplicationData) -> CLKComplicationTemplate {
        let template = CLKComplicationTemplateGraphicCircularClosedGaugeText()

        // HRV als Zahl in der Mitte
        template.centerTextProvider = CLKSimpleTextProvider(text: String(format: "%.2f", data.hrv))

        // Coherence als Ring
        let gaugeProvider = CLKSimpleGaugeProvider(
            style: .fill,
            gaugeColor: getCoherenceColor(level: data.coherenceLevel),
            fillFraction: Float(data.coherence)
        )
        template.gaugeProvider = gaugeProvider

        return template
    }

    private func createGraphicRectangularTemplate(data: WatchApp.ComplicationData) -> CLKComplicationTemplate {
        let template = CLKComplicationTemplateGraphicRectangularStandardBody()

        template.headerTextProvider = CLKSimpleTextProvider(
            text: "EOEL",
            shortText: "Echo"
        )

        // Mehrere Zeilen mit Bio-Daten
        let hrvText = String(format: "HRV: %.2f", data.hrv)
        let coherenceText = String(format: "Kohärenz: %@ (%.0f%%)",
                                   data.coherenceLevel.rawValue,
                                   data.coherence * 100)

        template.body1TextProvider = CLKSimpleTextProvider(text: hrvText)
        template.body2TextProvider = CLKSimpleTextProvider(text: coherenceText)

        return template
    }

    private func createGraphicBezelTemplate(data: WatchApp.ComplicationData) -> CLKComplicationTemplate {
        let template = CLKComplicationTemplateGraphicBezelCircularText()

        // Circular Teil
        let circularTemplate = CLKComplicationTemplateGraphicCircularClosedGaugeText()
        circularTemplate.centerTextProvider = CLKSimpleTextProvider(text: String(format: "%.2f", data.hrv))

        let gaugeProvider = CLKSimpleGaugeProvider(
            style: .fill,
            gaugeColor: getCoherenceColor(level: data.coherenceLevel),
            fillFraction: Float(data.coherence)
        )
        circularTemplate.gaugeProvider = gaugeProvider

        template.circularTemplate = circularTemplate

        // Text um den Ring
        template.textProvider = CLKSimpleTextProvider(
            text: String(format: "Kohärenz: %@", data.coherenceLevel.rawValue)
        )

        return template
    }

    @available(watchOS 7.0, *)
    private func createGraphicExtraLargeTemplate(data: WatchApp.ComplicationData) -> CLKComplicationTemplate {
        let template = CLKComplicationTemplateGraphicExtraLargeCircularClosedGaugeText()

        template.centerTextProvider = CLKSimpleTextProvider(text: String(format: "%.2f", data.hrv))

        let gaugeProvider = CLKSimpleGaugeProvider(
            style: .fill,
            gaugeColor: getCoherenceColor(level: data.coherenceLevel),
            fillFraction: Float(data.coherence)
        )
        template.gaugeProvider = gaugeProvider

        return template
    }

    // MARK: - Helper Methods

    private func getCoherenceColor(level: WatchApp.BioMetrics.CoherenceLevel) -> UIColor {
        let (r, g, b) = level.color
        return UIColor(red: r, green: g, blue: b, alpha: 1.0)
    }
}

#endif
