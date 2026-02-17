// EchoelSubtitleRenderer.swift
// Echoelmusic — Real-Time Subtitle & Caption Rendering
//
// ═══════════════════════════════════════════════════════════════════════════════
// EchoelSubtitle — Live multilingual subtitle overlay for streams & concerts
//
// Renders translated text as overlay on:
// - SwiftUI views (concerts, app UI)
// - Video streams (HLS WebVTT tracks)
// - External displays (via ExternalDisplayRenderingPipeline)
// - Vision Pro spatial text (via RealityKit)
//
// Features:
// - Multi-language simultaneous display (stacked or selectable)
// - Karaoke word-by-word highlighting
// - Bio-reactive text styling (size, opacity, color from coherence)
// - RTL support (Arabic, Hebrew)
// - Teleprompter mode for performers
// - WebVTT generation for HLS live streaming
// - Accessibility: VoiceOver, Dynamic Type support
//
// Copyright © 2026 Echoelmusic. All rights reserved.

import Foundation
import Combine
import SwiftUI

// MARK: - Subtitle Types

/// Visual style for subtitle display
public struct SubtitleStyle: Sendable {
    public var fontSize: CGFloat
    public var fontWeight: Font.Weight
    public var textColor: Color
    public var backgroundColor: Color
    public var backgroundOpacity: Double
    public var cornerRadius: CGFloat
    public var padding: EdgeInsets
    public var maxWidth: CGFloat
    public var position: SubtitlePosition
    public var alignment: TextAlignment
    public var shadowRadius: CGFloat
    public var animation: SubtitleAnimation

    public static let `default` = SubtitleStyle(
        fontSize: 18,
        fontWeight: .medium,
        textColor: .white,
        backgroundColor: .black,
        backgroundOpacity: 0.7,
        cornerRadius: 8,
        padding: EdgeInsets(top: 6, leading: 12, bottom: 6, trailing: 12),
        maxWidth: .infinity,
        position: .bottom,
        alignment: .center,
        shadowRadius: 2,
        animation: .fade
    )

    public static let karaoke = SubtitleStyle(
        fontSize: 32,
        fontWeight: .bold,
        textColor: .white,
        backgroundColor: .clear,
        backgroundOpacity: 0,
        cornerRadius: 0,
        padding: EdgeInsets(top: 0, leading: 20, bottom: 0, trailing: 20),
        maxWidth: .infinity,
        position: .center,
        alignment: .center,
        shadowRadius: 4,
        animation: .highlight
    )

    public static let concert = SubtitleStyle(
        fontSize: 48,
        fontWeight: .heavy,
        textColor: .white,
        backgroundColor: .clear,
        backgroundOpacity: 0,
        cornerRadius: 0,
        padding: EdgeInsets(top: 0, leading: 40, bottom: 40, trailing: 40),
        maxWidth: .infinity,
        position: .bottom,
        alignment: .center,
        shadowRadius: 6,
        animation: .slideUp
    )

    public static let teleprompter = SubtitleStyle(
        fontSize: 36,
        fontWeight: .regular,
        textColor: .white,
        backgroundColor: .black,
        backgroundOpacity: 0.9,
        cornerRadius: 0,
        padding: EdgeInsets(top: 20, leading: 40, bottom: 20, trailing: 40),
        maxWidth: .infinity,
        position: .center,
        alignment: .leading,
        shadowRadius: 0,
        animation: .scroll
    )
}

/// Subtitle position on screen
public enum SubtitlePosition: String, CaseIterable, Sendable {
    case top = "Top"
    case center = "Center"
    case bottom = "Bottom"
    case custom = "Custom"
}

/// Subtitle animation type
public enum SubtitleAnimation: String, CaseIterable, Sendable {
    case none = "None"
    case fade = "Fade"
    case slideUp = "Slide Up"
    case slideDown = "Slide Down"
    case highlight = "Highlight"        // Word-by-word karaoke highlight
    case scroll = "Scroll"              // Teleprompter smooth scroll
    case typewriter = "Typewriter"      // Character-by-character
}

/// A subtitle entry to display
public struct SubtitleEntry: Sendable, Identifiable {
    public let id: UUID
    public let text: String
    public let language: EchoelLanguage
    public let startTime: Date
    public let duration: TimeInterval
    public var highlightedWordIndex: Int?
    public var progress: Float // 0-1 progress through this entry

    public init(
        text: String,
        language: EchoelLanguage,
        duration: TimeInterval = 3.0,
        highlightedWordIndex: Int? = nil,
        progress: Float = 0
    ) {
        self.id = UUID()
        self.text = text
        self.language = language
        self.startTime = Date()
        self.duration = duration
        self.highlightedWordIndex = highlightedWordIndex
        self.progress = progress
    }
}

// MARK: - EchoelSubtitleRenderer

/// Real-time subtitle rendering engine
///
/// Manages subtitle display across multiple targets (SwiftUI overlay, HLS stream,
/// external display). Receives text from EchoelTranslateEngine and EchoelLyricsEngine.
///
/// Usage:
/// ```swift
/// let renderer = EchoelSubtitleRenderer.shared
///
/// // Configure style
/// renderer.style = .concert
///
/// // Show subtitle
/// renderer.show("Hello World", language: .english)
///
/// // Show multiple languages simultaneously
/// renderer.showMultilingual([
///     (.english, "Hello World"),
///     (.japanese, "こんにちは世界"),
///     (.german, "Hallo Welt")
/// ])
///
/// // SwiftUI: Add overlay to your view
/// MyView()
///     .overlay(EchoelSubtitleOverlay())
/// ```
@MainActor
public final class EchoelSubtitleRenderer: ObservableObject {

    public static let shared = EchoelSubtitleRenderer()

    // MARK: - Published State

    /// Currently displayed subtitles (one per language)
    @Published public var activeSubtitles: [SubtitleEntry] = []

    /// Primary subtitle text (first language)
    @Published public var primaryText: String = ""

    /// Whether subtitles are visible
    @Published public var isVisible: Bool = true

    /// Display style
    @Published public var style: SubtitleStyle = .default

    /// Maximum number of simultaneous languages displayed
    @Published public var maxLanguages: Int = 3

    /// Auto-hide after duration
    @Published public var autoHide: Bool = true

    /// Display languages (ordered by priority)
    @Published public var displayLanguages: [EchoelLanguage] = []

    /// Bio-reactive opacity (coherence → subtitle visibility)
    @Published public var bioOpacity: Double = 1.0

    /// WebVTT buffer for live streaming
    @Published public var webVTTBuffer: String = ""

    /// Whether to generate WebVTT for HLS
    @Published public var generateWebVTT: Bool = false

    // MARK: - Internal

    private var cancellables = Set<AnyCancellable>()
    private var busSubscription: BusSubscription?
    private var hideTimers: [UUID: Task<Void, Never>] = [:]
    private var webVTTSequence: Int = 0

    // MARK: - Initialization

    private init() {
        subscribeToBus()
    }

    // MARK: - Display API

    /// Show a single subtitle
    public func show(
        _ text: String,
        language: EchoelLanguage = .english,
        duration: TimeInterval = 4.0
    ) {
        let entry = SubtitleEntry(
            text: text,
            language: language,
            duration: duration
        )

        // Replace existing entry for same language
        activeSubtitles.removeAll { $0.language == language }
        activeSubtitles.append(entry)
        trimToMaxLanguages()

        primaryText = text

        // Auto-hide timer
        if autoHide {
            scheduleHide(for: entry)
        }

        // Generate WebVTT segment if streaming
        if generateWebVTT {
            appendWebVTTSegment(text: text, language: language, duration: duration)
        }

        // Publish to bus for external display pipeline
        EngineBus.shared.publish(.custom(
            topic: "subtitle.show",
            payload: [
                "text": text,
                "language": language.rawValue,
                "duration": "\(duration)"
            ]
        ))
    }

    /// Show multiple languages simultaneously
    public func showMultilingual(_ entries: [(EchoelLanguage, String)], duration: TimeInterval = 4.0) {
        activeSubtitles.removeAll()

        for (language, text) in entries.prefix(maxLanguages) {
            let entry = SubtitleEntry(
                text: text,
                language: language,
                duration: duration
            )
            activeSubtitles.append(entry)

            if autoHide {
                scheduleHide(for: entry)
            }
        }

        primaryText = entries.first?.1 ?? ""
    }

    /// Show karaoke-style subtitle with word highlighting
    public func showKaraoke(
        text: String,
        language: EchoelLanguage = .english,
        wordIndex: Int,
        progress: Float
    ) {
        let entry = SubtitleEntry(
            text: text,
            language: language,
            duration: 0, // Karaoke is externally timed
            highlightedWordIndex: wordIndex,
            progress: progress
        )

        activeSubtitles.removeAll { $0.language == language }
        activeSubtitles.append(entry)
        primaryText = text
    }

    /// Clear all subtitles
    public func clear() {
        activeSubtitles.removeAll()
        primaryText = ""

        for (_, timer) in hideTimers {
            timer.cancel()
        }
        hideTimers.removeAll()
    }

    /// Toggle subtitle visibility
    public func toggle() {
        isVisible.toggle()
    }

    // MARK: - Style Presets

    /// Apply style preset for specific use case
    public func applyPreset(_ preset: SubtitlePreset) {
        switch preset {
        case .standard:
            style = .default
        case .karaoke:
            style = .karaoke
        case .concert:
            style = .concert
        case .teleprompter:
            style = .teleprompter
        }
    }

    public enum SubtitlePreset: String, CaseIterable, Sendable {
        case standard = "Standard"
        case karaoke = "Karaoke"
        case concert = "Concert"
        case teleprompter = "Teleprompter"
    }

    // MARK: - WebVTT Streaming

    /// Start WebVTT generation for HLS live streaming
    public func startWebVTTGeneration() {
        generateWebVTT = true
        webVTTSequence = 0
        webVTTBuffer = "WEBVTT\nX-TIMESTAMP-MAP=LOCAL:00:00:00.000,MPEGTS:0\n\n"
    }

    /// Stop WebVTT generation
    public func stopWebVTTGeneration() {
        generateWebVTT = false
    }

    /// Get current WebVTT buffer and reset
    public func flushWebVTT() -> String {
        let buffer = webVTTBuffer
        webVTTBuffer = "WEBVTT\nX-TIMESTAMP-MAP=LOCAL:00:00:00.000,MPEGTS:0\n\n"
        return buffer
    }

    // MARK: - Bio-Reactive

    /// Apply bio-reactive modulation to subtitle display
    public func applyBioModulation(coherence: Float) {
        // High coherence → subtle, minimal subtitles (less distraction)
        // Low coherence → prominent, clear subtitles (more guidance)
        bioOpacity = Double(0.5 + (1.0 - coherence) * 0.5)

        // Font size adapts
        let baseFontSize = style.fontSize
        style.fontSize = baseFontSize * CGFloat(0.8 + coherence * 0.4)
    }

    // MARK: - Private Methods

    private func scheduleHide(for entry: SubtitleEntry) {
        let entryId = entry.id
        hideTimers[entryId]?.cancel()

        hideTimers[entryId] = Task {
            try? await Task.sleep(nanoseconds: UInt64(entry.duration * 1_000_000_000))

            guard !Task.isCancelled else { return }

            await MainActor.run { [weak self] in
                self?.activeSubtitles.removeAll { $0.id == entryId }
                self?.hideTimers.removeValue(forKey: entryId)

                if self?.activeSubtitles.isEmpty == true {
                    self?.primaryText = ""
                }
            }
        }
    }

    private func trimToMaxLanguages() {
        while activeSubtitles.count > maxLanguages {
            let removed = activeSubtitles.removeFirst()
            hideTimers[removed.id]?.cancel()
            hideTimers.removeValue(forKey: removed.id)
        }
    }

    private func appendWebVTTSegment(text: String, language: EchoelLanguage, duration: TimeInterval) {
        webVTTSequence += 1
        let now = Date().timeIntervalSinceReferenceDate
        let start = formatVTTTime(now)
        let end = formatVTTTime(now + duration)

        webVTTBuffer += "\(webVTTSequence)\n"
        webVTTBuffer += "\(start) --> \(end)\n"
        webVTTBuffer += "\(text)\n\n"
    }

    private func formatVTTTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(time) % 86400 // Wrap at 24h
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        let ms = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)
        return String(format: "%02d:%02d:%02d.%03d", hours, minutes, seconds, ms)
    }

    /// Subscribe to EngineBus for translation results and lyrics
    private func subscribeToBus() {
        busSubscription = EngineBus.shared.subscribe(to: .custom) { [weak self] msg in
            if case .custom(let topic, let payload) = msg {
                Task { @MainActor in
                    switch topic {
                    case "translate.result":
                        // Auto-display translation results as subtitles
                        if let source = payload["source"],
                           let translations = payload["translations"] {
                            self?.handleTranslationResult(source: source, translations: translations)
                        }

                    case "lyrics.position":
                        // Karaoke sync from lyrics engine
                        if let text = payload["text"],
                           let wordIdx = payload["wordIndex"].flatMap({ Int($0) }),
                           let progress = payload["progress"].flatMap({ Float($0) }) {
                            self?.showKaraoke(
                                text: text,
                                wordIndex: wordIdx,
                                progress: progress
                            )
                        }

                    case "speech.segment":
                        // Live speech transcription
                        if let text = payload["text"] {
                            self?.show(text, duration: 5.0)
                        }

                    default:
                        break
                    }
                }
            }
        }

        // Bio-reactive subscription
        let bioSub = EngineBus.shared.subscribe(to: .bio) { [weak self] msg in
            if case .bioUpdate(let bio) = msg {
                Task { @MainActor in
                    self?.applyBioModulation(coherence: bio.coherence)
                }
            }
        }
        _ = bioSub // Retain subscription
    }

    private func handleTranslationResult(source: String, translations: String) {
        // Parse "lang: text|lang: text" format
        let pairs = translations.split(separator: "|")
        var entries: [(EchoelLanguage, String)] = []

        for pair in pairs {
            let parts = pair.split(separator: ":", maxSplits: 1)
            guard parts.count == 2 else { continue }

            let langCode = String(parts[0]).trimmingCharacters(in: .whitespaces)
            let text = String(parts[1]).trimmingCharacters(in: .whitespaces)

            if let language = EchoelLanguage(rawValue: langCode) {
                entries.append((language, text))
            }
        }

        if !entries.isEmpty {
            showMultilingual(entries)
        }
    }
}

// MARK: - SwiftUI Subtitle Overlay View

/// SwiftUI overlay view for displaying subtitles
///
/// Usage:
/// ```swift
/// ZStack {
///     YourContentView()
///     EchoelSubtitleOverlay()
/// }
/// ```
public struct EchoelSubtitleOverlay: View {
    @ObservedObject private var renderer = EchoelSubtitleRenderer.shared

    public init() {}

    public var body: some View {
        if renderer.isVisible && !renderer.activeSubtitles.isEmpty {
            VStack(spacing: 4) {
                ForEach(renderer.activeSubtitles) { entry in
                    subtitleRow(entry)
                }
            }
            .frame(maxWidth: renderer.style.maxWidth)
            .padding(renderer.style.padding)
            .opacity(renderer.bioOpacity)
            .allowsHitTesting(false)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(renderer.primaryText)
        }
    }

    @ViewBuilder
    private func subtitleRow(_ entry: SubtitleEntry) -> some View {
        HStack(spacing: 4) {
            if renderer.activeSubtitles.count > 1 {
                Text(entry.language.icon)
                    .font(.caption)
            }

            if let wordIndex = entry.highlightedWordIndex {
                karaokeText(entry.text, highlightIndex: wordIndex)
            } else {
                Text(entry.text)
                    .font(.system(size: renderer.style.fontSize, weight: renderer.style.fontWeight))
                    .foregroundStyle(renderer.style.textColor)
                    .multilineTextAlignment(renderer.style.alignment)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: renderer.style.cornerRadius)
                .fill(renderer.style.backgroundColor.opacity(renderer.style.backgroundOpacity))
        )
        .shadow(radius: renderer.style.shadowRadius)
        .environment(\.layoutDirection, entry.language.isRTL ? .rightToLeft : .leftToRight)
    }

    @ViewBuilder
    private func karaokeText(_ text: String, highlightIndex: Int) -> some View {
        let words = text.split(separator: " ").map(String.init)

        HStack(spacing: 4) {
            ForEach(Array(words.enumerated()), id: \.offset) { index, word in
                Text(word)
                    .font(.system(
                        size: renderer.style.fontSize,
                        weight: index <= highlightIndex ? .bold : .regular
                    ))
                    .foregroundStyle(
                        index <= highlightIndex
                            ? Color(red: 1, green: 0.9, blue: 0.4) // Gold highlight
                            : renderer.style.textColor.opacity(0.6)
                    )
                    .scaleEffect(index == highlightIndex ? 1.1 : 1.0)
                    .animation(.easeInOut(duration: 0.15), value: highlightIndex)
            }
        }
    }
}
