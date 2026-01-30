import SwiftUI

// MARK: - Dynamic Typography System
// Provides Dynamic Type support while maintaining design consistency
// All fonts scale with user's accessibility settings

/// Echoelmusic typography that respects Dynamic Type
public enum EchoelTypography {

    // MARK: - Semantic Text Styles

    /// Large title for main headers (scales from 28-42pt)
    public static var largeTitle: Font {
        .largeTitle.weight(.bold)
    }

    /// Title for section headers (scales from 22-34pt)
    public static var title: Font {
        .title.weight(.semibold)
    }

    /// Title 2 for subsection headers (scales from 20-28pt)
    public static var title2: Font {
        .title2.weight(.semibold)
    }

    /// Title 3 for small headers (scales from 18-24pt)
    public static var title3: Font {
        .title3.weight(.medium)
    }

    /// Headline for emphasized text (scales from 15-21pt)
    public static var headline: Font {
        .headline
    }

    /// Body text for main content (scales from 14-21pt)
    public static var body: Font {
        .body
    }

    /// Callout for secondary content (scales from 13-19pt)
    public static var callout: Font {
        .callout
    }

    /// Subheadline for supporting text (scales from 12-17pt)
    public static var subheadline: Font {
        .subheadline
    }

    /// Footnote for minor text (scales from 11-15pt)
    public static var footnote: Font {
        .footnote
    }

    /// Caption for labels (scales from 10-14pt)
    public static var caption: Font {
        .caption
    }

    /// Caption 2 for smallest text (scales from 9-13pt)
    public static var caption2: Font {
        .caption2
    }

    // MARK: - Specialized Styles

    /// Monospaced for code/data display
    public static var monospaced: Font {
        .system(.body, design: .monospaced)
    }

    /// Rounded for friendly UI elements
    public static var rounded: Font {
        .system(.body, design: .rounded)
    }

    /// Serif for editorial content
    public static var serif: Font {
        .system(.body, design: .serif)
    }

    // MARK: - Fixed Size Alternatives (Use Sparingly!)

    /// For UI elements that absolutely cannot scale (meters, controls)
    /// These still use relative sizing but with tighter bounds
    public static func fixed(_ style: Font.TextStyle, weight: Font.Weight = .regular) -> Font {
        .system(style, design: .default, weight: weight)
    }

    /// Minimum readable size for critical UI (clips, meters)
    public static var minimumReadable: Font {
        .system(size: 10, weight: .medium, design: .rounded)
    }

    /// For large display numbers (BPM, coherence %)
    public static var displayNumber: Font {
        .system(.largeTitle, design: .rounded, weight: .bold)
    }
}

// MARK: - View Extension for Easy Access

extension View {
    /// Apply Echoelmusic typography with Dynamic Type support
    public func echoelFont(_ style: Font) -> some View {
        self.font(style)
            .dynamicTypeSize(...DynamicTypeSize.accessibility3) // Cap at accessibility3 for layout stability
    }

    /// Apply typography that scales but with maximum size limit
    public func echoelFontCapped(_ style: Font, maxSize: DynamicTypeSize = .xxxLarge) -> some View {
        self.font(style)
            .dynamicTypeSize(...maxSize)
    }
}

// MARK: - Accessibility Size Categories

extension DynamicTypeSize {
    /// Check if user has accessibility sizes enabled
    public var isAccessibilitySize: Bool {
        switch self {
        case .accessibility1, .accessibility2, .accessibility3, .accessibility4, .accessibility5:
            return true
        default:
            return false
        }
    }
}

// MARK: - Preview

#if DEBUG
struct DynamicTypography_Previews: PreviewProvider {
    static var previews: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Large Title")
                .font(EchoelTypography.largeTitle)
            Text("Title")
                .font(EchoelTypography.title)
            Text("Title 2")
                .font(EchoelTypography.title2)
            Text("Title 3")
                .font(EchoelTypography.title3)
            Text("Headline")
                .font(EchoelTypography.headline)
            Text("Body")
                .font(EchoelTypography.body)
            Text("Callout")
                .font(EchoelTypography.callout)
            Text("Subheadline")
                .font(EchoelTypography.subheadline)
            Text("Footnote")
                .font(EchoelTypography.footnote)
            Text("Caption")
                .font(EchoelTypography.caption)
            Text("120 BPM")
                .font(EchoelTypography.displayNumber)
        }
        .padding()
        .previewDisplayName("All Styles")
    }
}
#endif
