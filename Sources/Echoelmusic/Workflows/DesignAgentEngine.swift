// DesignAgentEngine.swift
// Echoelmusic
//
// AI-Powered Design Agent for Inspiration, Review, and Standards Enforcement
// Inspired by OneRedOak/claude-code-workflows Design Review System
//
// Created by Echoelmusic on 2025-12-05.

import Foundation
import SwiftUI
import Combine

// MARK: - Design Principles

/// World-class design principles inspired by Stripe, Airbnb, Linear
public struct DesignPrinciples {

    // MARK: Visual Hierarchy

    public struct VisualHierarchy {
        public static let primaryEmphasis: CGFloat = 1.0
        public static let secondaryEmphasis: CGFloat = 0.7
        public static let tertiaryEmphasis: CGFloat = 0.5
        public static let subtleEmphasis: CGFloat = 0.3

        public static let headingScale: [CGFloat] = [34, 28, 22, 18, 16, 14]
        public static let bodySize: CGFloat = 16
        public static let captionSize: CGFloat = 12

        public static let lineHeightMultiplier: CGFloat = 1.5
        public static let paragraphSpacing: CGFloat = 16
    }

    // MARK: Spacing System (8pt Grid)

    public struct Spacing {
        public static let xxxs: CGFloat = 2
        public static let xxs: CGFloat = 4
        public static let xs: CGFloat = 8
        public static let sm: CGFloat = 12
        public static let md: CGFloat = 16
        public static let lg: CGFloat = 24
        public static let xl: CGFloat = 32
        public static let xxl: CGFloat = 48
        public static let xxxl: CGFloat = 64

        public static func grid(_ units: Int) -> CGFloat {
            CGFloat(units) * 8
        }
    }

    // MARK: Color Semantics

    public struct ColorSemantics {
        // Semantic colors
        public static let primary = Color.blue
        public static let secondary = Color.purple
        public static let success = Color.green
        public static let warning = Color.orange
        public static let error = Color.red
        public static let info = Color.cyan

        // Neutral palette
        public static let neutral50 = Color(white: 0.98)
        public static let neutral100 = Color(white: 0.96)
        public static let neutral200 = Color(white: 0.9)
        public static let neutral300 = Color(white: 0.8)
        public static let neutral400 = Color(white: 0.6)
        public static let neutral500 = Color(white: 0.4)
        public static let neutral600 = Color(white: 0.3)
        public static let neutral700 = Color(white: 0.2)
        public static let neutral800 = Color(white: 0.1)
        public static let neutral900 = Color(white: 0.05)
    }

    // MARK: Motion

    public struct Motion {
        public static let instantDuration: Double = 0.1
        public static let fastDuration: Double = 0.2
        public static let normalDuration: Double = 0.3
        public static let slowDuration: Double = 0.5
        public static let extraSlowDuration: Double = 0.8

        public static let easeOut = Animation.easeOut(duration: normalDuration)
        public static let spring = Animation.spring(response: 0.4, dampingFraction: 0.75)
        public static let bouncy = Animation.spring(response: 0.5, dampingFraction: 0.6)
    }

    // MARK: Accessibility (WCAG AA+)

    public struct Accessibility {
        public static let minimumTouchTarget: CGFloat = 44
        public static let minimumContrastRatio: Double = 4.5
        public static let largeTextContrastRatio: Double = 3.0
        public static let focusIndicatorWidth: CGFloat = 2
        public static let reducedMotionDuration: Double = 0
    }
}

// MARK: - Design Review Finding

public struct DesignReviewFinding: Identifiable, Codable {
    public let id: UUID
    public let category: Category
    public let severity: Severity
    public let title: String
    public let description: String
    public let location: String
    public let suggestion: String
    public let principle: String
    public let autoFixable: Bool
    public let timestamp: Date

    public enum Category: String, Codable, CaseIterable {
        case visualHierarchy = "Visual Hierarchy"
        case spacing = "Spacing & Layout"
        case typography = "Typography"
        case color = "Color & Contrast"
        case accessibility = "Accessibility"
        case responsiveness = "Responsiveness"
        case interaction = "Interaction"
        case consistency = "Consistency"
        case performance = "Performance"
        case animation = "Animation"
        case iconography = "Iconography"
        case dataVisualization = "Data Visualization"
    }

    public enum Severity: String, Codable, CaseIterable {
        case critical = "Critical"
        case major = "Major"
        case minor = "Minor"
        case suggestion = "Suggestion"

        public var emoji: String {
            switch self {
            case .critical: return "🔴"
            case .major: return "🟠"
            case .minor: return "🟡"
            case .suggestion: return "🔵"
            }
        }

        public var priority: Int {
            switch self {
            case .critical: return 4
            case .major: return 3
            case .minor: return 2
            case .suggestion: return 1
            }
        }
    }

    public init(
        category: Category,
        severity: Severity,
        title: String,
        description: String,
        location: String,
        suggestion: String,
        principle: String,
        autoFixable: Bool = false
    ) {
        self.id = UUID()
        self.category = category
        self.severity = severity
        self.title = title
        self.description = description
        self.location = location
        self.suggestion = suggestion
        self.principle = principle
        self.autoFixable = autoFixable
        self.timestamp = Date()
    }
}

// MARK: - Design Inspiration

public struct DesignInspiration: Identifiable, Codable {
    public let id: UUID
    public let source: InspirationSource
    public let category: Category
    public let title: String
    public let description: String
    public let imageURL: URL?
    public let colorPalette: [String]
    public let techniques: [String]
    public let applicability: Float
    public let tags: [String]

    public enum InspirationSource: String, Codable {
        case stripe = "Stripe"
        case airbnb = "Airbnb"
        case linear = "Linear"
        case apple = "Apple"
        case figma = "Figma"
        case notion = "Notion"
        case vercel = "Vercel"
        case raycast = "Raycast"
        case arc = "Arc Browser"
        case framer = "Framer"
        case dribbble = "Dribbble"
        case behance = "Behance"
        case awwwards = "Awwwards"
        case internal = "Echoelmusic"
    }

    public enum Category: String, Codable {
        case dashboard = "Dashboard"
        case controls = "Audio Controls"
        case visualization = "Visualization"
        case navigation = "Navigation"
        case collaboration = "Collaboration"
        case mobile = "Mobile"
        case wearable = "Wearable"
        case spatial = "Spatial/VR"
        case onboarding = "Onboarding"
        case marketing = "Marketing"
    }
}

// MARK: - Design Agent Engine

@MainActor
public final class DesignAgentEngine: ObservableObject {
    public static let shared = DesignAgentEngine()

    // MARK: Published State

    @Published public private(set) var isAnalyzing = false
    @Published public private(set) var currentFindings: [DesignReviewFinding] = []
    @Published public private(set) var inspirations: [DesignInspiration] = []
    @Published public private(set) var designScore: Float = 0
    @Published public private(set) var lastReviewDate: Date?
    @Published public private(set) var analysisProgress: Float = 0

    // MARK: Configuration

    public var brandGuidelines: BrandGuidelines = .echoelmusic
    public var strictnessLevel: StrictnessLevel = .balanced
    public var enableAutoFix = false

    // MARK: Private

    private var reviewQueue = OperationQueue()
    private var cancellables = Set<AnyCancellable>()
    private var componentRegistry: [String: ComponentMetadata] = [:]
    private var stylePatterns: [StylePattern] = []

    // MARK: Initialization

    private init() {
        reviewQueue.maxConcurrentOperationCount = 4
        reviewQueue.qualityOfService = .userInitiated
        loadBuiltInPatterns()
        loadInspirationLibrary()
    }

    // MARK: - Design Review

    /// Performs comprehensive design review on a view hierarchy
    public func reviewDesign<V: View>(_ view: V, context: ReviewContext = .default) async -> DesignReviewReport {
        isAnalyzing = true
        analysisProgress = 0
        currentFindings = []

        defer {
            isAnalyzing = false
            analysisProgress = 1.0
        }

        var findings: [DesignReviewFinding] = []

        // Phase 1: Visual Hierarchy Analysis (20%)
        analysisProgress = 0.1
        findings.append(contentsOf: await analyzeVisualHierarchy(context))
        analysisProgress = 0.2

        // Phase 2: Spacing & Layout (40%)
        findings.append(contentsOf: await analyzeSpacingAndLayout(context))
        analysisProgress = 0.4

        // Phase 3: Typography & Color (55%)
        findings.append(contentsOf: await analyzeTypographyAndColor(context))
        analysisProgress = 0.55

        // Phase 4: Accessibility (70%)
        findings.append(contentsOf: await analyzeAccessibility(context))
        analysisProgress = 0.7

        // Phase 5: Interaction Patterns (85%)
        findings.append(contentsOf: await analyzeInteractionPatterns(context))
        analysisProgress = 0.85

        // Phase 6: Consistency Check (95%)
        findings.append(contentsOf: await analyzeConsistency(context))
        analysisProgress = 0.95

        // Calculate design score
        let score = calculateDesignScore(findings: findings)
        designScore = score
        currentFindings = findings
        lastReviewDate = Date()

        // Auto-fix if enabled
        if enableAutoFix {
            await applyAutoFixes(findings.filter { $0.autoFixable })
        }

        analysisProgress = 1.0

        return DesignReviewReport(
            findings: findings,
            score: score,
            summary: generateSummary(findings: findings, score: score),
            recommendations: generateRecommendations(findings: findings),
            timestamp: Date()
        )
    }

    // MARK: - Analysis Phases

    private func analyzeVisualHierarchy(_ context: ReviewContext) async -> [DesignReviewFinding] {
        var findings: [DesignReviewFinding] = []

        // Check heading hierarchy
        if context.hasSkippedHeadingLevels {
            findings.append(DesignReviewFinding(
                category: .visualHierarchy,
                severity: .major,
                title: "Skipped Heading Levels",
                description: "Heading levels jump from H1 to H3, skipping H2",
                location: context.viewPath,
                suggestion: "Use sequential heading levels (H1 → H2 → H3) for proper document structure",
                principle: "Semantic HTML and logical content hierarchy"
            ))
        }

        // Check primary action visibility
        if context.hasMissingPrimaryCTA {
            findings.append(DesignReviewFinding(
                category: .visualHierarchy,
                severity: .major,
                title: "Missing Primary Action",
                description: "No clear primary call-to-action button visible",
                location: context.viewPath,
                suggestion: "Add a prominent primary button with visual emphasis",
                principle: "Every view should have one clear primary action"
            ))
        }

        // Check information density
        if context.informationDensity > 0.8 {
            findings.append(DesignReviewFinding(
                category: .visualHierarchy,
                severity: .minor,
                title: "High Information Density",
                description: "View contains too much information without clear grouping",
                location: context.viewPath,
                suggestion: "Group related elements and add whitespace between sections",
                principle: "Reduce cognitive load through progressive disclosure",
                autoFixable: true
            ))
        }

        return findings
    }

    private func analyzeSpacingAndLayout(_ context: ReviewContext) async -> [DesignReviewFinding] {
        var findings: [DesignReviewFinding] = []

        // Check 8pt grid alignment
        for violation in context.gridViolations {
            findings.append(DesignReviewFinding(
                category: .spacing,
                severity: .minor,
                title: "8pt Grid Violation",
                description: "Spacing of \(violation.value)pt doesn't align to 8pt grid",
                location: violation.location,
                suggestion: "Use \(roundToGrid(violation.value))pt instead",
                principle: "8-point grid system for consistent spacing",
                autoFixable: true
            ))
        }

        // Check padding consistency
        if context.hasInconsistentPadding {
            findings.append(DesignReviewFinding(
                category: .spacing,
                severity: .minor,
                title: "Inconsistent Padding",
                description: "Different padding values used for similar elements",
                location: context.viewPath,
                suggestion: "Use consistent padding from spacing scale: 8, 16, 24, 32pt",
                principle: "Consistent internal spacing creates visual rhythm",
                autoFixable: true
            ))
        }

        // Check touch targets
        for smallTarget in context.smallTouchTargets {
            findings.append(DesignReviewFinding(
                category: .spacing,
                severity: .critical,
                title: "Small Touch Target",
                description: "Interactive element is \(Int(smallTarget.size))pt, below 44pt minimum",
                location: smallTarget.location,
                suggestion: "Increase touch target to at least 44pt for accessibility",
                principle: "WCAG 2.1 Target Size (Level AAA) requirement",
                autoFixable: true
            ))
        }

        return findings
    }

    private func analyzeTypographyAndColor(_ context: ReviewContext) async -> [DesignReviewFinding] {
        var findings: [DesignReviewFinding] = []

        // Check font weight consistency
        if context.fontWeightVariations > 5 {
            findings.append(DesignReviewFinding(
                category: .typography,
                severity: .minor,
                title: "Too Many Font Weights",
                description: "\(context.fontWeightVariations) different font weights used",
                location: context.viewPath,
                suggestion: "Limit to 3-4 font weights: regular, medium, semibold, bold",
                principle: "Typography restraint improves readability"
            ))
        }

        // Check line height
        for issue in context.lineHeightIssues {
            findings.append(DesignReviewFinding(
                category: .typography,
                severity: .minor,
                title: "Suboptimal Line Height",
                description: "Line height \(issue.ratio) is outside optimal range",
                location: issue.location,
                suggestion: "Use 1.4-1.6× line height for body text",
                principle: "Proper line height improves readability",
                autoFixable: true
            ))
        }

        // Check color contrast
        for contrastIssue in context.contrastIssues {
            let severity: DesignReviewFinding.Severity = contrastIssue.ratio < 3.0 ? .critical : .major
            findings.append(DesignReviewFinding(
                category: .color,
                severity: severity,
                title: "Insufficient Color Contrast",
                description: "Contrast ratio \(String(format: "%.2f", contrastIssue.ratio)):1 below \(contrastIssue.isLargeText ? "3.0" : "4.5"):1 minimum",
                location: contrastIssue.location,
                suggestion: "Increase contrast between foreground and background colors",
                principle: "WCAG AA contrast requirements for accessibility"
            ))
        }

        return findings
    }

    private func analyzeAccessibility(_ context: ReviewContext) async -> [DesignReviewFinding] {
        var findings: [DesignReviewFinding] = []

        // Check missing labels
        for unlabeledElement in context.unlabeledElements {
            findings.append(DesignReviewFinding(
                category: .accessibility,
                severity: .critical,
                title: "Missing Accessibility Label",
                description: "Interactive element lacks accessibility label",
                location: unlabeledElement,
                suggestion: "Add .accessibilityLabel() with descriptive text",
                principle: "Screen reader users need labeled elements",
                autoFixable: true
            ))
        }

        // Check focus order
        if context.hasFocusOrderIssues {
            findings.append(DesignReviewFinding(
                category: .accessibility,
                severity: .major,
                title: "Illogical Focus Order",
                description: "Tab/focus order doesn't follow visual layout",
                location: context.viewPath,
                suggestion: "Ensure focus moves logically through content",
                principle: "Focus order should match visual hierarchy"
            ))
        }

        // Check for motion sensitivity
        if context.hasUnreducedMotion {
            findings.append(DesignReviewFinding(
                category: .accessibility,
                severity: .major,
                title: "Missing Reduced Motion Support",
                description: "Animations don't respect reduced motion preference",
                location: context.viewPath,
                suggestion: "Use @Environment(\\.accessibilityReduceMotion) to adapt",
                principle: "Respect user's motion preferences (WCAG 2.3.3)",
                autoFixable: true
            ))
        }

        return findings
    }

    private func analyzeInteractionPatterns(_ context: ReviewContext) async -> [DesignReviewFinding] {
        var findings: [DesignReviewFinding] = []

        // Check for feedback on interactions
        if context.hasMissingFeedback {
            findings.append(DesignReviewFinding(
                category: .interaction,
                severity: .major,
                title: "Missing Interaction Feedback",
                description: "Button/control lacks visual feedback on press",
                location: context.viewPath,
                suggestion: "Add pressed state, haptic feedback, or animation",
                principle: "Every interaction needs immediate feedback"
            ))
        }

        // Check gesture discoverability
        for hiddenGesture in context.hiddenGestures {
            findings.append(DesignReviewFinding(
                category: .interaction,
                severity: .minor,
                title: "Hidden Gesture",
                description: "Custom gesture '\(hiddenGesture.name)' has no visual affordance",
                location: hiddenGesture.location,
                suggestion: "Add visual hints or onboarding for custom gestures",
                principle: "Gestures should be discoverable or documented"
            ))
        }

        // Check loading states
        if context.hasMissingLoadingState {
            findings.append(DesignReviewFinding(
                category: .interaction,
                severity: .major,
                title: "Missing Loading State",
                description: "Async operation lacks loading indicator",
                location: context.viewPath,
                suggestion: "Add skeleton, spinner, or progress indicator",
                principle: "Users need feedback during async operations"
            ))
        }

        return findings
    }

    private func analyzeConsistency(_ context: ReviewContext) async -> [DesignReviewFinding] {
        var findings: [DesignReviewFinding] = []

        // Check component consistency
        for inconsistency in context.componentInconsistencies {
            findings.append(DesignReviewFinding(
                category: .consistency,
                severity: .minor,
                title: "Inconsistent Component Usage",
                description: "'\(inconsistency.componentA)' and '\(inconsistency.componentB)' serve similar purpose with different styles",
                location: inconsistency.location,
                suggestion: "Consolidate into single reusable component",
                principle: "Reuse components for consistent UX"
            ))
        }

        // Check against brand guidelines
        for violation in context.brandViolations {
            findings.append(DesignReviewFinding(
                category: .consistency,
                severity: .major,
                title: "Brand Guideline Violation",
                description: violation.description,
                location: violation.location,
                suggestion: violation.suggestion,
                principle: "Maintain brand consistency across all views"
            ))
        }

        return findings
    }

    // MARK: - Design Inspiration

    /// Gets design inspiration for a specific feature or component
    public func getInspiration(
        for category: DesignInspiration.Category,
        context: String = "",
        count: Int = 5
    ) async -> [DesignInspiration] {
        // Filter and rank inspirations based on context
        let filtered = inspirations.filter { $0.category == category }
        let ranked = filtered.sorted { $0.applicability > $1.applicability }
        return Array(ranked.prefix(count))
    }

    /// Generates design suggestions based on current context
    public func generateDesignSuggestions(for component: String) async -> [DesignSuggestion] {
        var suggestions: [DesignSuggestion] = []

        // Audio-specific suggestions
        if component.lowercased().contains("waveform") {
            suggestions.append(DesignSuggestion(
                title: "Waveform Visualization",
                description: "Consider using gradient fills that respond to audio energy",
                techniques: ["Metal shaders", "Liquid Glass overlay", "Bio-reactive colors"],
                inspiration: inspirations.first { $0.tags.contains("audio") }
            ))
        }

        if component.lowercased().contains("mixer") {
            suggestions.append(DesignSuggestion(
                title: "Mixer Layout",
                description: "Use vertical faders with horizontal meters, group by bus",
                techniques: ["Grid layout", "Drag-to-reorder", "Collapsible groups"],
                inspiration: inspirations.first { $0.tags.contains("mixer") }
            ))
        }

        if component.lowercased().contains("spectrum") {
            suggestions.append(DesignSuggestion(
                title: "Spectrum Analyzer",
                description: "Logarithmic frequency scale with smooth peak decay",
                techniques: ["FFT binning", "Logarithmic scale", "Peak hold"],
                inspiration: inspirations.first { $0.tags.contains("spectrum") }
            ))
        }

        return suggestions
    }

    // MARK: - Scoring

    private func calculateDesignScore(findings: [DesignReviewFinding]) -> Float {
        guard !findings.isEmpty else { return 100 }

        var deductions: Float = 0

        for finding in findings {
            switch finding.severity {
            case .critical: deductions += 15
            case .major: deductions += 8
            case .minor: deductions += 3
            case .suggestion: deductions += 1
            }
        }

        // Apply strictness multiplier
        let multiplier: Float
        switch strictnessLevel {
        case .lenient: multiplier = 0.7
        case .balanced: multiplier = 1.0
        case .strict: multiplier = 1.3
        case .perfectionist: multiplier = 1.5
        }

        let finalScore = max(0, 100 - (deductions * multiplier))
        return finalScore
    }

    private func generateSummary(findings: [DesignReviewFinding], score: Float) -> String {
        let criticalCount = findings.filter { $0.severity == .critical }.count
        let majorCount = findings.filter { $0.severity == .major }.count

        if score >= 90 {
            return "Excellent design quality with minor refinements possible."
        } else if score >= 75 {
            return "Good design foundation. Address \(majorCount) major issues for improvement."
        } else if score >= 50 {
            return "Design needs attention. Found \(criticalCount) critical and \(majorCount) major issues."
        } else {
            return "Significant design improvements required. \(criticalCount) critical issues must be addressed."
        }
    }

    private func generateRecommendations(findings: [DesignReviewFinding]) -> [String] {
        var recommendations: [String] = []

        let categories = Dictionary(grouping: findings) { $0.category }

        for (category, categoryFindings) in categories.sorted(by: { $0.value.count > $1.value.count }) {
            if categoryFindings.count >= 3 {
                recommendations.append("Focus on \(category.rawValue): \(categoryFindings.count) issues found")
            }
        }

        // Add general recommendations
        if findings.contains(where: { $0.category == .accessibility }) {
            recommendations.append("Run VoiceOver testing to validate accessibility fixes")
        }

        if findings.contains(where: { $0.category == .consistency }) {
            recommendations.append("Consider creating a shared design system component library")
        }

        return recommendations
    }

    // MARK: - Auto Fix

    private func applyAutoFixes(_ findings: [DesignReviewFinding]) async {
        for finding in findings {
            // Log auto-fix attempt
            print("Auto-fixing: \(finding.title) at \(finding.location)")
            // Actual fix implementation would modify code/views
        }
    }

    // MARK: - Helpers

    private func roundToGrid(_ value: CGFloat) -> CGFloat {
        CGFloat(Int(value / 8) * 8)
    }

    private func loadBuiltInPatterns() {
        stylePatterns = [
            StylePattern(name: "Audio Meter", usage: .audioVisualization, variants: ["Linear", "Logarithmic", "VU"]),
            StylePattern(name: "Waveform", usage: .audioVisualization, variants: ["Overview", "Detailed", "Mini"]),
            StylePattern(name: "Knob Control", usage: .control, variants: ["Standard", "Fine", "Stepped"]),
            StylePattern(name: "Transport", usage: .control, variants: ["Minimal", "Full", "Floating"]),
            StylePattern(name: "Track Row", usage: .list, variants: ["Compact", "Standard", "Expanded"]),
        ]
    }

    private func loadInspirationLibrary() {
        inspirations = [
            DesignInspiration(
                id: UUID(),
                source: .apple,
                category: .visualization,
                title: "Logic Pro X Waveform",
                description: "Clean waveform with gradient fill and transient markers",
                imageURL: nil,
                colorPalette: ["#00FF00", "#00AA00", "#005500"],
                techniques: ["Gradient fill", "Transient detection", "Zoom levels"],
                applicability: 0.95,
                tags: ["audio", "waveform", "professional"]
            ),
            DesignInspiration(
                id: UUID(),
                source: .linear,
                category: .dashboard,
                title: "Linear Project Dashboard",
                description: "Clean, minimal dashboard with clear hierarchy",
                imageURL: nil,
                colorPalette: ["#5E6AD2", "#F2F2F2", "#1F2023"],
                techniques: ["Command palette", "Keyboard shortcuts", "List virtualization"],
                applicability: 0.85,
                tags: ["dashboard", "minimal", "productivity"]
            ),
            DesignInspiration(
                id: UUID(),
                source: .stripe,
                category: .controls,
                title: "Stripe Payment Form",
                description: "Smooth input validation with inline error states",
                imageURL: nil,
                colorPalette: ["#635BFF", "#0A2540", "#00D4FF"],
                techniques: ["Inline validation", "Micro-animations", "Error states"],
                applicability: 0.75,
                tags: ["forms", "validation", "smooth"]
            ),
            DesignInspiration(
                id: UUID(),
                source: .airbnb,
                category: .mobile,
                title: "Airbnb Search Experience",
                description: "Full-screen search with category filters",
                imageURL: nil,
                colorPalette: ["#FF385C", "#222222", "#717171"],
                techniques: ["Full-screen modal", "Date picker", "Location search"],
                applicability: 0.70,
                tags: ["search", "mobile", "filters"]
            ),
            DesignInspiration(
                id: UUID(),
                source: .internal,
                category: .visualization,
                title: "Echoelmusic Spectrum",
                description: "Bio-reactive spectrum analyzer with liquid glass",
                imageURL: nil,
                colorPalette: ["#6366F1", "#8B5CF6", "#EC4899"],
                techniques: ["Bio-reactivity", "Liquid Glass", "Metal shaders"],
                applicability: 1.0,
                tags: ["audio", "spectrum", "bio-reactive"]
            ),
            DesignInspiration(
                id: UUID(),
                source: .apple,
                category: .spatial,
                title: "visionOS Window Design",
                description: "Floating windows with depth and glass materials",
                imageURL: nil,
                colorPalette: ["#FFFFFF", "#000000", "#AAAAAA"],
                techniques: ["Glass material", "Spatial layout", "Eye tracking"],
                applicability: 0.90,
                tags: ["spatial", "visionOS", "glass"]
            ),
        ]
    }
}

// MARK: - Supporting Types

public struct DesignReviewReport: Codable {
    public let findings: [DesignReviewFinding]
    public let score: Float
    public let summary: String
    public let recommendations: [String]
    public let timestamp: Date

    public var criticalCount: Int {
        findings.filter { $0.severity == .critical }.count
    }

    public var majorCount: Int {
        findings.filter { $0.severity == .major }.count
    }

    public var formattedReport: String {
        var report = """
        # Design Review Report

        **Score:** \(Int(score))/100
        **Date:** \(timestamp.formatted())

        ## Summary
        \(summary)

        ## Findings (\(findings.count) total)

        """

        let grouped = Dictionary(grouping: findings) { $0.severity }
        for severity in DesignReviewFinding.Severity.allCases.reversed() {
            if let severityFindings = grouped[severity], !severityFindings.isEmpty {
                report += "### \(severity.emoji) \(severity.rawValue) (\(severityFindings.count))\n\n"
                for finding in severityFindings {
                    report += "- **\(finding.title)**: \(finding.description)\n"
                    report += "  - Location: `\(finding.location)`\n"
                    report += "  - Fix: \(finding.suggestion)\n\n"
                }
            }
        }

        report += "## Recommendations\n\n"
        for recommendation in recommendations {
            report += "- \(recommendation)\n"
        }

        return report
    }
}

public struct DesignSuggestion: Identifiable {
    public let id = UUID()
    public let title: String
    public let description: String
    public let techniques: [String]
    public let inspiration: DesignInspiration?
}

public struct ReviewContext {
    public var viewPath: String = ""
    public var hasSkippedHeadingLevels = false
    public var hasMissingPrimaryCTA = false
    public var informationDensity: Float = 0.5
    public var gridViolations: [GridViolation] = []
    public var hasInconsistentPadding = false
    public var smallTouchTargets: [SmallTouchTarget] = []
    public var fontWeightVariations = 3
    public var lineHeightIssues: [LineHeightIssue] = []
    public var contrastIssues: [ContrastIssue] = []
    public var unlabeledElements: [String] = []
    public var hasFocusOrderIssues = false
    public var hasUnreducedMotion = false
    public var hasMissingFeedback = false
    public var hiddenGestures: [HiddenGesture] = []
    public var hasMissingLoadingState = false
    public var componentInconsistencies: [ComponentInconsistency] = []
    public var brandViolations: [BrandViolation] = []

    public static let `default` = ReviewContext()

    public struct GridViolation {
        public let value: CGFloat
        public let location: String
    }

    public struct SmallTouchTarget {
        public let size: CGFloat
        public let location: String
    }

    public struct LineHeightIssue {
        public let ratio: Float
        public let location: String
    }

    public struct ContrastIssue {
        public let ratio: Double
        public let isLargeText: Bool
        public let location: String
    }

    public struct HiddenGesture {
        public let name: String
        public let location: String
    }

    public struct ComponentInconsistency {
        public let componentA: String
        public let componentB: String
        public let location: String
    }

    public struct BrandViolation {
        public let description: String
        public let location: String
        public let suggestion: String
    }
}

public struct BrandGuidelines {
    public var primaryColor: Color
    public var secondaryColor: Color
    public var fontFamily: String
    public var cornerRadius: CGFloat
    public var spacing: CGFloat

    public static let echoelmusic = BrandGuidelines(
        primaryColor: Color(red: 0.4, green: 0.4, blue: 0.95),
        secondaryColor: Color(red: 0.55, green: 0.35, blue: 0.95),
        fontFamily: "SF Pro",
        cornerRadius: 12,
        spacing: 16
    )
}

public enum StrictnessLevel: String, CaseIterable {
    case lenient = "Lenient"
    case balanced = "Balanced"
    case strict = "Strict"
    case perfectionist = "Perfectionist"
}

public struct StylePattern {
    public let name: String
    public let usage: Usage
    public let variants: [String]

    public enum Usage {
        case audioVisualization
        case control
        case list
        case navigation
        case modal
    }
}

public struct ComponentMetadata {
    public let name: String
    public let path: String
    public let usageCount: Int
    public let lastModified: Date
}

// MARK: - Design Review View

public struct DesignReviewView: View {
    @StateObject private var designAgent = DesignAgentEngine.shared
    @State private var showReport = false
    @State private var currentReport: DesignReviewReport?

    public init() {}

    public var body: some View {
        VStack(spacing: 16) {
            // Header
            HStack {
                Image(systemName: "paintbrush.pointed")
                    .font(.title2)
                Text("Design Agent")
                    .font(.headline)
                Spacer()

                if designAgent.isAnalyzing {
                    ProgressView()
                        .scaleEffect(0.8)
                }
            }
            .padding(.horizontal)

            // Score Card
            if designAgent.designScore > 0 {
                scoreCard
            }

            // Findings Summary
            if !designAgent.currentFindings.isEmpty {
                findingsSummary
            }

            // Actions
            HStack(spacing: 12) {
                Button("Run Review") {
                    Task {
                        let report = await designAgent.reviewDesign(
                            EmptyView(),
                            context: .default
                        )
                        currentReport = report
                        showReport = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(designAgent.isAnalyzing)

                Button("Get Inspiration") {
                    Task {
                        _ = await designAgent.getInspiration(for: .visualization)
                    }
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(isPresented: $showReport) {
            if let report = currentReport {
                DesignReportSheet(report: report)
            }
        }
    }

    private var scoreCard: some View {
        VStack(spacing: 8) {
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 8)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: CGFloat(designAgent.designScore / 100))
                    .stroke(scoreColor, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))

                Text("\(Int(designAgent.designScore))")
                    .font(.title.bold())
            }

            Text("Design Score")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private var findingsSummary: some View {
        HStack(spacing: 16) {
            findingBadge(count: designAgent.currentFindings.filter { $0.severity == .critical }.count, severity: .critical)
            findingBadge(count: designAgent.currentFindings.filter { $0.severity == .major }.count, severity: .major)
            findingBadge(count: designAgent.currentFindings.filter { $0.severity == .minor }.count, severity: .minor)
        }
    }

    private func findingBadge(count: Int, severity: DesignReviewFinding.Severity) -> some View {
        VStack {
            Text("\(count)")
                .font(.headline)
            Text(severity.rawValue)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(8)
        .background(badgeColor(for: severity).opacity(0.2))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var scoreColor: Color {
        if designAgent.designScore >= 90 { return .green }
        if designAgent.designScore >= 75 { return .blue }
        if designAgent.designScore >= 50 { return .orange }
        return .red
    }

    private func badgeColor(for severity: DesignReviewFinding.Severity) -> Color {
        switch severity {
        case .critical: return .red
        case .major: return .orange
        case .minor: return .yellow
        case .suggestion: return .blue
        }
    }
}

struct DesignReportSheet: View {
    let report: DesignReviewReport
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(report.formattedReport)
                    .font(.system(.body, design: .monospaced))
                    .padding()
            }
            .navigationTitle("Design Report")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#if DEBUG
struct DesignAgentEngine_Previews: PreviewProvider {
    static var previews: some View {
        DesignReviewView()
            .frame(width: 300)
            .padding()
    }
}
#endif
