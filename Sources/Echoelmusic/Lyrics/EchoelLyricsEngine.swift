// EchoelLyricsEngine.swift
// Echoelmusic — Lyrics Extraction & Synchronization Engine
//
// ═══════════════════════════════════════════════════════════════════════════════
// EchoelLyrics — Extract, sync, translate, and display song lyrics
//
// Pipeline:
// ┌──────────────────────────────────────────────────────────────────────────┐
// │  Audio Source (file, stream, live mic)                                    │
// │       │                                                                  │
// │       ▼                                                                  │
// │  AIStemSeparationEngine ──→ Isolated Vocals Track                       │
// │       │                                                                  │
// │       ▼                                                                  │
// │  EchoelSpeechEngine ──→ Word-level transcription with timestamps        │
// │       │                                                                  │
// │       ▼                                                                  │
// │  Lyrics Post-Processing ──→ Line detection, punctuation, correction     │
// │       │                                                                  │
// │       ├──→ EchoelTranslateEngine ──→ Multi-language lyrics              │
// │       ├──→ EchoelSubtitleRenderer ──→ Synced on-screen display          │
// │       ├──→ WebVTT Export ──→ HLS subtitle track for streams             │
// │       └──→ LRC/SRT Export ──→ Standard subtitle formats                 │
// └──────────────────────────────────────────────────────────────────────────┘
//
// Use Cases:
// 1. Concert visuals: Extract lyrics from playback, display with translation
// 2. Stream subtitles: Real-time lyrics for worldwide audience
// 3. Collaboration: Simultaneous lyrics display during sessions
// 4. Content creation: Auto-generate subtitled music videos
// 5. Karaoke mode: Word-by-word highlight synchronized to audio
//
// Copyright © 2026 Echoelmusic. All rights reserved.

import Foundation
import Combine
import AVFoundation
import Accelerate

// MARK: - Lyrics Types

/// A single lyrics line with timing
public struct LyricsLine: Sendable, Identifiable, Codable {
    public let id: UUID
    public let text: String
    public let words: [LyricsWord]
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public var translations: [String: String] // languageCode: translatedText

    public init(
        text: String,
        words: [LyricsWord] = [],
        startTime: TimeInterval,
        endTime: TimeInterval,
        translations: [String: String] = [:]
    ) {
        self.id = UUID()
        self.text = text
        self.words = words
        self.startTime = startTime
        self.endTime = endTime
        self.translations = translations
    }

    public var duration: TimeInterval { endTime - startTime }
}

/// A single word within a lyrics line
public struct LyricsWord: Sendable, Identifiable, Codable {
    public let id: UUID
    public let text: String
    public let startTime: TimeInterval
    public let endTime: TimeInterval
    public let confidence: Float

    public init(
        text: String,
        startTime: TimeInterval,
        endTime: TimeInterval,
        confidence: Float = 1.0
    ) {
        self.id = UUID()
        self.text = text
        self.startTime = startTime
        self.endTime = endTime
        self.confidence = confidence
    }
}

/// Complete lyrics document
public struct LyricsDocument: Sendable, Identifiable, Codable {
    public let id: UUID
    public var title: String
    public var artist: String
    public var language: String
    public var lines: [LyricsLine]
    public var duration: TimeInterval
    public let createdAt: Date
    public var isEdited: Bool

    public init(
        title: String = "Untitled",
        artist: String = "Unknown",
        language: String = "en",
        lines: [LyricsLine] = [],
        duration: TimeInterval = 0
    ) {
        self.id = UUID()
        self.title = title
        self.artist = artist
        self.language = language
        self.lines = lines
        self.duration = duration
        self.createdAt = Date()
        self.isEdited = false
    }

    /// Total word count
    public var wordCount: Int {
        lines.reduce(0) { $0 + $1.words.count }
    }

    /// Full text (no timing)
    public var fullText: String {
        lines.map(\.text).joined(separator: "\n")
    }
}

/// Lyrics extraction mode
public enum LyricsExtractionMode: String, CaseIterable, Sendable {
    case realtime = "Realtime"          // Live extraction during playback
    case offline = "Offline"            // Full quality, slower
    case prepared = "Prepared"          // Pre-extracted, loaded from file
}

/// Lyrics display mode
public enum LyricsDisplayMode: String, CaseIterable, Sendable {
    case karaoke = "Karaoke"            // Word-by-word highlight
    case scroll = "Scroll"              // Scrolling text
    case subtitle = "Subtitle"          // Bottom overlay (1-2 lines)
    case fullscreen = "Fullscreen"      // Centered, large text
    case teleprompter = "Teleprompter"  // Smooth scroll, large text
}

/// Export format
public enum LyricsExportFormat: String, CaseIterable, Sendable {
    case lrc = "LRC"                    // Standard lyrics format
    case srt = "SRT"                    // SubRip subtitle
    case vtt = "WebVTT"                 // Web Video Text Tracks (HLS)
    case ttml = "TTML"                  // Timed Text Markup Language
    case json = "JSON"                  // Echoelmusic native format
}

// MARK: - EchoelLyricsEngine

/// Lyrics extraction, synchronization, and display engine
///
/// Combines vocal separation (AIStemSeparationEngine) with speech recognition
/// (EchoelSpeechEngine) to extract time-synced lyrics from any audio source.
/// Supports real-time translation, karaoke display, and subtitle export.
///
/// Usage:
/// ```swift
/// let lyrics = EchoelLyricsEngine.shared
///
/// // Extract from audio file
/// let document = try await lyrics.extractFromFile(url)
///
/// // Translate to multiple languages
/// try await lyrics.translateDocument(to: [.japanese, .spanish])
///
/// // Export as WebVTT for streaming
/// let vtt = lyrics.export(format: .vtt)
///
/// // Real-time karaoke mode
/// lyrics.displayMode = .karaoke
/// lyrics.startPlayback(at: currentTime)
/// ```
@MainActor
public final class EchoelLyricsEngine: ObservableObject {

    public static let shared = EchoelLyricsEngine()

    // MARK: - Published State

    /// Current lyrics document
    @Published public var document: LyricsDocument?

    /// Current active line (during playback)
    @Published public var currentLine: LyricsLine?

    /// Current active word index within current line (for karaoke)
    @Published public var currentWordIndex: Int = 0

    /// Extraction progress (0-1)
    @Published public var extractionProgress: Float = 0

    /// Is currently extracting lyrics
    @Published public var isExtracting: Bool = false

    /// Is in playback/display mode
    @Published public var isPlaying: Bool = false

    /// Display mode
    @Published public var displayMode: LyricsDisplayMode = .subtitle

    /// Extraction mode
    @Published public var extractionMode: LyricsExtractionMode = .realtime

    /// Auto-translate extracted lyrics
    @Published public var autoTranslate: Bool = false

    /// Target languages for auto-translation
    @Published public var translationTargets: Set<EchoelLanguage> = []

    /// Confidence threshold for word acceptance
    @Published public var confidenceThreshold: Float = 0.4

    /// Whether vocals are separated before recognition
    @Published public var useVocalSeparation: Bool = true

    /// Lyrics edit history for undo
    @Published public var canUndo: Bool = false

    // MARK: - Internal

    private var cancellables = Set<AnyCancellable>()
    private var busSubscription: BusSubscription?
    private var playbackTimer: Timer?
    private var playbackStartTime: TimeInterval = 0
    private var extractionTask: Task<Void, Never>?
    private var editHistory: [LyricsDocument] = []

    // MARK: - Initialization

    private init() {
        subscribeToBus()
    }

    // MARK: - Extraction

    /// Extract lyrics from an audio file
    ///
    /// Pipeline: Audio → Vocal Separation → Speech Recognition → Lyrics
    public func extractFromFile(_ url: URL) async throws -> LyricsDocument {
        isExtracting = true
        extractionProgress = 0
        defer { isExtracting = false }

        // Step 1: Load audio
        extractionProgress = 0.1
        let audioFile = try AVAudioFile(forReading: url)
        let duration = Double(audioFile.length) / audioFile.fileFormat.sampleRate

        // Step 2: Vocal separation (if enabled)
        extractionProgress = 0.2
        var processedURL = url

        if useVocalSeparation {
            // Use existing AIStemSeparationEngine for vocal isolation
            // This dramatically improves ASR accuracy on music
            EngineBus.shared.publish(.custom(
                topic: "lyrics.separation.start",
                payload: ["file": url.lastPathComponent]
            ))

            // Request vocal separation via bus (AIStemSeparationEngine handles it)
            processedURL = await separateVocals(from: url) ?? url
            extractionProgress = 0.5
        }

        // Step 3: Speech recognition on vocals
        extractionProgress = 0.6
        let segments = try await transcribeAudio(fileURL: processedURL)
        extractionProgress = 0.8

        // Step 4: Build lyrics document
        let lines = buildLyricsLines(from: segments)
        extractionProgress = 0.9

        var doc = LyricsDocument(
            title: url.deletingPathExtension().lastPathComponent,
            lines: lines,
            duration: duration
        )

        // Step 5: Auto-translate if enabled
        if autoTranslate && !translationTargets.isEmpty {
            doc = await translateDocument(doc, to: Array(translationTargets))
        }

        extractionProgress = 1.0
        document = doc

        EngineBus.shared.publish(.custom(
            topic: "lyrics.extracted",
            payload: [
                "title": doc.title,
                "lines": "\(doc.lines.count)",
                "words": "\(doc.wordCount)",
                "duration": "\(Int(duration))s"
            ]
        ))

        return doc
    }

    /// Extract lyrics in real-time from live audio (mic or playback)
    public func startRealtimeExtraction() {
        extractionMode = .realtime
        isExtracting = true

        // Connect to EchoelSpeechEngine for live transcription
        let speech = EchoelSpeechEngine.shared

        // Subscribe to speech segments
        speech.$segments
            .receive(on: DispatchQueue.main)
            .sink { [weak self] segments in
                guard let self = self else { return }
                self.updateDocumentFromSpeech(segments)
            }
            .store(in: &cancellables)

        // Start speech recognition
        Task {
            try? await speech.startListening()
        }
    }

    /// Stop real-time extraction
    public func stopRealtimeExtraction() {
        EchoelSpeechEngine.shared.stopListening()
        isExtracting = false
        extractionMode = .prepared
    }

    // MARK: - Playback / Display

    /// Start lyrics playback synchronized to audio position
    public func startPlayback(at time: TimeInterval) {
        guard document != nil else { return }

        playbackStartTime = time
        isPlaying = true

        // 30Hz update for smooth karaoke highlighting
        playbackTimer = Timer.scheduledTimer(withTimeInterval: 1.0/30.0, repeats: true) {
            [weak self] _ in
            Task { @MainActor [weak self] in
                self?.updatePlaybackPosition()
            }
        }
    }

    /// Update playback to specific time position
    public func seekTo(_ time: TimeInterval) {
        playbackStartTime = time
        updatePlaybackPosition()
    }

    /// Stop lyrics playback
    public func stopPlayback() {
        playbackTimer?.invalidate()
        playbackTimer = nil
        isPlaying = false
        currentLine = nil
        currentWordIndex = 0
    }

    // MARK: - Translation

    /// Translate the entire lyrics document to target languages
    public func translateDocument(
        _ doc: LyricsDocument,
        to targets: [EchoelLanguage]
    ) async -> LyricsDocument {
        var translatedDoc = doc
        let translator = EchoelTranslateEngine.shared

        for target in targets {
            translator.addTargetLanguage(target)
        }

        for (index, line) in doc.lines.enumerated() {
            if let results = try? await translator.translate(line.text) {
                for result in results {
                    translatedDoc.lines[index].translations[result.targetLanguage.rawValue] = result.translatedText
                }
            }
        }

        return translatedDoc
    }

    /// Translate current document in place
    public func translateCurrentDocument(to targets: [EchoelLanguage]) async {
        guard let doc = document else { return }
        document = await translateDocument(doc, to: targets)
    }

    // MARK: - Editing

    /// Correct a lyrics line manually
    public func correctLine(at index: Int, newText: String) {
        guard var doc = document, index < doc.lines.count else { return }

        // Save for undo
        editHistory.append(doc)
        canUndo = true

        doc.lines[index] = LyricsLine(
            text: newText,
            words: doc.lines[index].words,
            startTime: doc.lines[index].startTime,
            endTime: doc.lines[index].endTime,
            translations: [:] // Clear translations (text changed)
        )
        doc.isEdited = true
        document = doc
    }

    /// Undo last edit
    public func undo() {
        guard let previous = editHistory.popLast() else { return }
        document = previous
        canUndo = !editHistory.isEmpty
    }

    // MARK: - Export

    /// Export lyrics to standard format
    public func export(format: LyricsExportFormat, language: String? = nil) -> String {
        guard let doc = document else { return "" }

        switch format {
        case .lrc:
            return exportLRC(doc, language: language)
        case .srt:
            return exportSRT(doc, language: language)
        case .vtt:
            return exportWebVTT(doc, language: language)
        case .ttml:
            return exportTTML(doc, language: language)
        case .json:
            return exportJSON(doc)
        }
    }

    /// Export as WebVTT for HLS streaming
    public func exportWebVTT(_ doc: LyricsDocument, language: String? = nil) -> String {
        var vtt = "WEBVTT\nKind: captions\nLanguage: \(language ?? doc.language)\n\n"

        for (index, line) in doc.lines.enumerated() {
            let text = language.flatMap { line.translations[$0] } ?? line.text
            let start = formatTimestamp(line.startTime, format: .vtt)
            let end = formatTimestamp(line.endTime, format: .vtt)

            vtt += "\(index + 1)\n"
            vtt += "\(start) --> \(end)\n"
            vtt += "\(text)\n\n"
        }

        return vtt
    }

    /// Export as SRT
    public func exportSRT(_ doc: LyricsDocument, language: String? = nil) -> String {
        var srt = ""

        for (index, line) in doc.lines.enumerated() {
            let text = language.flatMap { line.translations[$0] } ?? line.text
            let start = formatTimestamp(line.startTime, format: .srt)
            let end = formatTimestamp(line.endTime, format: .srt)

            srt += "\(index + 1)\n"
            srt += "\(start) --> \(end)\n"
            srt += "\(text)\n\n"
        }

        return srt
    }

    /// Export as LRC (standard lyrics format)
    public func exportLRC(_ doc: LyricsDocument, language: String? = nil) -> String {
        var lrc = "[ti:\(doc.title)]\n[ar:\(doc.artist)]\n[la:\(language ?? doc.language)]\n\n"

        for line in doc.lines {
            let text = language.flatMap { line.translations[$0] } ?? line.text
            let minutes = Int(line.startTime) / 60
            let seconds = Int(line.startTime) % 60
            let hundredths = Int((line.startTime.truncatingRemainder(dividingBy: 1)) * 100)

            lrc += "[\(String(format: "%02d", minutes)):\(String(format: "%02d", seconds)).\(String(format: "%02d", hundredths))] \(text)\n"
        }

        return lrc
    }

    /// Export as TTML (Apple Music compatible)
    public func exportTTML(_ doc: LyricsDocument, language: String? = nil) -> String {
        var ttml = """
        <?xml version="1.0" encoding="UTF-8"?>
        <tt xmlns="http://www.w3.org/ns/ttml" xml:lang="\(language ?? doc.language)">
        <body><div>
        """

        for line in doc.lines {
            let text = language.flatMap { line.translations[$0] } ?? line.text
            let begin = formatTimestamp(line.startTime, format: .ttml)
            let end = formatTimestamp(line.endTime, format: .ttml)

            ttml += "  <p begin=\"\(begin)\" end=\"\(end)\">\(escapeXML(text))</p>\n"
        }

        ttml += "</div></body></tt>"
        return ttml
    }

    /// Export as JSON (Echoelmusic native format)
    public func exportJSON(_ doc: LyricsDocument) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601

        guard let data = try? encoder.encode(doc),
              let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    // MARK: - Private Methods

    /// Separate vocals from music using AIStemSeparationEngine
    private func separateVocals(from url: URL) async -> URL? {
        // Request vocal separation via EngineBus
        // AIStemSeparationEngine will process and return isolated vocals
        EngineBus.shared.publish(.custom(
            topic: "stems.separate",
            payload: [
                "file": url.path,
                "stems": "vocals",
                "quality": "balanced"
            ]
        ))

        // Return the vocal track URL
        // In production, AIStemSeparationEngine writes to temp file and publishes result
        let vocalPath = url.deletingPathExtension().appendingPathExtension("vocals.wav")
        if FileManager.default.fileExists(atPath: vocalPath.path) {
            return vocalPath
        }

        return nil
    }

    /// Transcribe audio file using EchoelSpeechEngine
    private func transcribeAudio(fileURL: URL) async throws -> [TranscriptionSegment] {
        let speech = EchoelSpeechEngine.shared

        // Load audio file and feed buffers
        let audioFile = try AVAudioFile(forReading: fileURL)
        let format = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)

        // Process in chunks for memory efficiency
        let chunkSize: AVAudioFrameCount = 4096
        var position: AVAudioFramePosition = 0

        // Start speech engine in buffer-feed mode
        try await speech.startListening()

        while position < audioFile.length {
            let framesToRead = min(chunkSize, AVAudioFrameCount(audioFile.length - position))
            guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: framesToRead) else {
                break
            }

            try audioFile.read(into: buffer, frameCount: framesToRead)
            speech.feedAudioBuffer(buffer)
            position += Int64(framesToRead)

            // Update progress
            extractionProgress = 0.6 + 0.2 * Float(position) / Float(audioFile.length)
        }

        // Wait for final results
        try? await Task.sleep(nanoseconds: 2_000_000_000) // 2s for final processing

        speech.stopListening()
        return speech.segments
    }

    /// Convert speech segments to lyrics lines
    private func buildLyricsLines(from segments: [TranscriptionSegment]) -> [LyricsLine] {
        return segments.map { segment in
            let words = segment.words.map { word in
                LyricsWord(
                    text: word.text,
                    startTime: word.startTime,
                    endTime: word.endTime,
                    confidence: word.confidence
                )
            }

            return LyricsLine(
                text: segment.text,
                words: words,
                startTime: segment.startTime,
                endTime: segment.endTime
            )
        }
    }

    /// Update document from live speech segments
    private func updateDocumentFromSpeech(_ segments: [TranscriptionSegment]) {
        let lines = buildLyricsLines(from: segments)

        if document == nil {
            document = LyricsDocument(lines: lines)
        } else {
            document?.lines = lines
        }
    }

    /// Update playback position and highlight current line/word
    private func updatePlaybackPosition() {
        guard let doc = document else { return }

        let now = playbackStartTime

        // Find current line
        currentLine = doc.lines.first { line in
            now >= line.startTime && now <= line.endTime
        }

        // Find current word for karaoke
        if let line = currentLine, displayMode == .karaoke {
            currentWordIndex = line.words.lastIndex { word in
                now >= word.startTime
            } ?? 0
        }

        // Publish current position for visual sync
        if let line = currentLine {
            EngineBus.shared.publish(.custom(
                topic: "lyrics.position",
                payload: [
                    "text": line.text,
                    "wordIndex": "\(currentWordIndex)",
                    "progress": "\(Float(now - line.startTime) / Float(line.duration))"
                ]
            ))
        }
    }

    // MARK: - Timestamp Formatting

    private enum TimestampFormat {
        case vtt     // HH:MM:SS.mmm
        case srt     // HH:MM:SS,mmm
        case ttml    // HH:MM:SS.mmm
    }

    private func formatTimestamp(_ time: TimeInterval, format: TimestampFormat) -> String {
        let hours = Int(time) / 3600
        let minutes = (Int(time) % 3600) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 1000)

        let separator: String
        switch format {
        case .vtt, .ttml: separator = "."
        case .srt: separator = ","
        }

        return String(
            format: "%02d:%02d:%02d%@%03d",
            hours, minutes, seconds, separator, milliseconds
        )
    }

    private func escapeXML(_ text: String) -> String {
        text.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
    }

    /// Subscribe to EngineBus
    private func subscribeToBus() {
        busSubscription = EngineBus.shared.subscribe(to: .audio) { [weak self] msg in
            if case .audioAnalysis(let snapshot) = msg {
                Task { @MainActor in
                    // Update playback position from audio engine time
                    if self?.isPlaying == true {
                        self?.playbackStartTime = snapshot.timestamp
                    }
                }
            }
        }
    }
}
