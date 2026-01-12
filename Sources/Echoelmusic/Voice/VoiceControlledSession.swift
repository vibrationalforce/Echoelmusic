/**
 * VoiceControlledSession.swift
 *
 * Natural language voice control for Echoelmusic sessions
 * Speech recognition, intent parsing, and command execution
 *
 * Phase 10000 ULTIMATE RALPH WIGGUM LAMBDA MODE
 */

import Foundation
import Speech
import NaturalLanguage

// MARK: - Voice Command Types

/// Categories of voice commands
public enum VoiceCommandCategory: String, CaseIterable {
    case session       // "Start session", "End session"
    case transport     // "Play", "Stop", "Record"
    case tempo         // "Set tempo to 120", "Faster", "Slower"
    case mixer         // "Mute drums", "Solo vocals", "Turn up bass"
    case effects       // "Add reverb", "Remove delay", "More distortion"
    case preset        // "Load meditation preset", "Save as workout"
    case biometric     // "Enable heart sync", "Start breathing guide"
    case visual        // "Show coherence", "Hide waveform"
    case collaboration // "Invite user", "Start broadcast"
    case help          // "Help", "What can I say?"
}

/// Parsed voice command
public struct VoiceCommand {
    public var category: VoiceCommandCategory
    public var action: String
    public var parameters: [String: Any]
    public var rawText: String
    public var confidence: Float
    public var timestamp: Date

    public init(category: VoiceCommandCategory, action: String, parameters: [String: Any] = [:], rawText: String, confidence: Float) {
        self.category = category
        self.action = action
        self.parameters = parameters
        self.rawText = rawText
        self.confidence = confidence
        self.timestamp = Date()
    }
}

/// Command execution result
public struct CommandResult {
    public var success: Bool
    public var message: String
    public var speakResponse: Bool

    public static func success(_ message: String, speak: Bool = true) -> CommandResult {
        return CommandResult(success: true, message: message, speakResponse: speak)
    }

    public static func failure(_ message: String, speak: Bool = true) -> CommandResult {
        return CommandResult(success: false, message: message, speakResponse: speak)
    }
}

// MARK: - Intent Recognition

/// Natural language intent parser
public class VoiceIntentParser {

    // MARK: Command Patterns

    private let commandPatterns: [VoiceCommandCategory: [String]] = [
        .session: [
            "start session", "begin session", "new session",
            "end session", "stop session", "finish session",
            "pause session", "resume session"
        ],
        .transport: [
            "play", "start playing", "resume",
            "stop", "pause", "halt",
            "record", "start recording", "stop recording"
        ],
        .tempo: [
            "set tempo", "change tempo", "tempo",
            "faster", "speed up", "increase tempo",
            "slower", "slow down", "decrease tempo",
            "set bpm", "bpm"
        ],
        .mixer: [
            "mute", "unmute", "solo", "unsolo",
            "turn up", "turn down", "increase", "decrease",
            "volume", "gain", "level",
            "pan left", "pan right", "center"
        ],
        .effects: [
            "add reverb", "remove reverb", "more reverb", "less reverb",
            "add delay", "remove delay", "echo",
            "add distortion", "clean", "clarity",
            "add compression", "compress", "limit"
        ],
        .preset: [
            "load preset", "save preset", "apply preset",
            "meditation preset", "workout preset", "focus preset",
            "relaxation", "energy", "sleep"
        ],
        .biometric: [
            "enable heart sync", "disable heart sync",
            "start breathing guide", "stop breathing",
            "show coherence", "track hrv",
            "bio reactive mode", "lambda mode"
        ],
        .visual: [
            "show", "hide", "display", "remove",
            "waveform", "spectrum", "coherence meter",
            "dark mode", "light mode"
        ],
        .collaboration: [
            "invite", "join session", "leave session",
            "start broadcast", "stop broadcast", "go live",
            "share screen", "screen share"
        ],
        .help: [
            "help", "what can i say", "commands",
            "how do i", "show help"
        ]
    ]

    // MARK: Parsing

    public func parse(_ text: String) -> VoiceCommand? {
        let normalizedText = text.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // Find matching category and action
        for (category, patterns) in commandPatterns {
            for pattern in patterns {
                if normalizedText.contains(pattern) {
                    let parameters = extractParameters(from: normalizedText, category: category)
                    return VoiceCommand(
                        category: category,
                        action: pattern,
                        parameters: parameters,
                        rawText: text,
                        confidence: calculateConfidence(normalizedText, pattern: pattern)
                    )
                }
            }
        }

        // Use NLP for fuzzy matching
        return parseWithNLP(normalizedText)
    }

    private func extractParameters(from text: String, category: VoiceCommandCategory) -> [String: Any] {
        var params: [String: Any] = [:]

        // Extract numbers
        let numbers = extractNumbers(from: text)
        if !numbers.isEmpty {
            params["value"] = numbers[0]
            if numbers.count > 1 {
                params["values"] = numbers
            }
        }

        // Extract track/channel names
        let trackKeywords = ["drums", "bass", "vocals", "guitar", "keys", "synth", "master", "all"]
        for keyword in trackKeywords {
            if text.contains(keyword) {
                params["track"] = keyword
                break
            }
        }

        // Extract preset names
        if category == .preset {
            let presetKeywords = ["meditation", "workout", "focus", "relaxation", "energy", "sleep", "creative"]
            for keyword in presetKeywords {
                if text.contains(keyword) {
                    params["preset"] = keyword
                    break
                }
            }
        }

        // Extract effect types
        if category == .effects {
            let effectKeywords = ["reverb", "delay", "distortion", "compression", "eq", "filter", "chorus"]
            for keyword in effectKeywords {
                if text.contains(keyword) {
                    params["effect"] = keyword
                    break
                }
            }
        }

        return params
    }

    private func extractNumbers(from text: String) -> [Double] {
        let pattern = #"(\d+\.?\d*)"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }

        let range = NSRange(text.startIndex..., in: text)
        let matches = regex.matches(in: text, range: range)

        return matches.compactMap { match -> Double? in
            guard let range = Range(match.range(at: 1), in: text) else { return nil }
            return Double(text[range])
        }
    }

    private func calculateConfidence(_ text: String, pattern: String) -> Float {
        // Simple confidence based on exact match vs partial
        if text == pattern { return 1.0 }
        if text.hasPrefix(pattern) || text.hasSuffix(pattern) { return 0.9 }
        return 0.7
    }

    private func parseWithNLP(_ text: String) -> VoiceCommand? {
        let tagger = NLTagger(tagSchemes: [.lexicalClass, .lemma])
        tagger.string = text

        var verbs: [String] = []
        var nouns: [String] = []

        tagger.enumerateTags(in: text.startIndex..<text.endIndex, unit: .word, scheme: .lexicalClass) { tag, range in
            if let tag = tag {
                let word = String(text[range])
                switch tag {
                case .verb:
                    verbs.append(word)
                case .noun:
                    nouns.append(word)
                default:
                    break
                }
            }
            return true
        }

        // Try to match verbs to categories
        let verbToCategory: [String: VoiceCommandCategory] = [
            "start": .session, "begin": .session, "stop": .session, "end": .session,
            "play": .transport, "pause": .transport, "record": .transport,
            "mute": .mixer, "unmute": .mixer, "solo": .mixer,
            "add": .effects, "remove": .effects,
            "load": .preset, "save": .preset,
            "show": .visual, "hide": .visual,
            "invite": .collaboration, "join": .collaboration
        ]

        for verb in verbs {
            if let category = verbToCategory[verb.lowercased()] {
                return VoiceCommand(
                    category: category,
                    action: verb,
                    parameters: [:],
                    rawText: text,
                    confidence: 0.6
                )
            }
        }

        return nil
    }
}

// MARK: - Speech Recognition Engine

/// Real-time speech recognition
@MainActor
public class SpeechRecognitionEngine: ObservableObject {

    @Published public var isListening: Bool = false
    @Published public var currentTranscript: String = ""
    @Published public var lastCommand: VoiceCommand?
    @Published public var error: String?

    private var speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private var audioEngine: AVAudioEngine?

    public init() {
        speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
        audioEngine = AVAudioEngine()
    }

    public func requestAuthorization() async -> Bool {
        await withCheckedContinuation { continuation in
            SFSpeechRecognizer.requestAuthorization { status in
                continuation.resume(returning: status == .authorized)
            }
        }
    }

    public func startListening() throws {
        guard let speechRecognizer = speechRecognizer, speechRecognizer.isAvailable else {
            throw VoiceControlError.speechRecognizerUnavailable
        }

        guard let audioEngine = audioEngine else {
            throw VoiceControlError.audioEngineUnavailable
        }

        // Stop any existing recognition
        stopListening()

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else {
            throw VoiceControlError.requestCreationFailed
        }

        recognitionRequest.shouldReportPartialResults = true

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
        try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

        // Setup audio input
        let inputNode = audioEngine.inputNode
        let recordingFormat = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            recognitionRequest.append(buffer)
        }

        // Start recognition task
        recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            Task { @MainActor in
                if let result = result {
                    self?.currentTranscript = result.bestTranscription.formattedString

                    // Process final result
                    if result.isFinal {
                        self?.processTranscript(result.bestTranscription.formattedString)
                    }
                }

                if let error = error {
                    self?.error = error.localizedDescription
                    self?.stopListening()
                }
            }
        }

        // Start audio engine
        audioEngine.prepare()
        try audioEngine.start()

        isListening = true
    }

    public func stopListening() {
        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)
        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        recognitionRequest = nil
        recognitionTask = nil
        isListening = false
    }

    private func processTranscript(_ transcript: String) {
        let parser = VoiceIntentParser()
        if let command = parser.parse(transcript) {
            lastCommand = command
        }
    }
}

// MARK: - Voice Command Executor

/// Executes parsed voice commands
public protocol VoiceCommandDelegate: AnyObject {
    func startSession(name: String?) async -> CommandResult
    func endSession() async -> CommandResult
    func setTransportState(_ state: TransportState) async -> CommandResult
    func setTempo(_ bpm: Double) async -> CommandResult
    func adjustTempo(delta: Double) async -> CommandResult
    func setTrackVolume(track: String, volume: Float) async -> CommandResult
    func muteTrack(_ track: String, muted: Bool) async -> CommandResult
    func soloTrack(_ track: String, soloed: Bool) async -> CommandResult
    func addEffect(_ effect: String, to track: String?) async -> CommandResult
    func removeEffect(_ effect: String, from track: String?) async -> CommandResult
    func loadPreset(_ name: String) async -> CommandResult
    func savePreset(_ name: String) async -> CommandResult
    func setBioReactiveMode(_ enabled: Bool) async -> CommandResult
    func startBreathingGuide() async -> CommandResult
    func showVisual(_ visual: String) async -> CommandResult
    func hideVisual(_ visual: String) async -> CommandResult
}

public enum TransportState: String {
    case playing, paused, stopped, recording
}

@MainActor
public class VoiceCommandExecutor: ObservableObject {

    @Published public var lastResult: CommandResult?
    @Published public var commandHistory: [VoiceCommand] = []

    public weak var delegate: VoiceCommandDelegate?

    private let synthesizer = AVSpeechSynthesizer()

    public func execute(_ command: VoiceCommand) async -> CommandResult {
        commandHistory.append(command)

        let result: CommandResult

        switch command.category {
        case .session:
            result = await executeSessionCommand(command)
        case .transport:
            result = await executeTransportCommand(command)
        case .tempo:
            result = await executeTempoCommand(command)
        case .mixer:
            result = await executeMixerCommand(command)
        case .effects:
            result = await executeEffectsCommand(command)
        case .preset:
            result = await executePresetCommand(command)
        case .biometric:
            result = await executeBiometricCommand(command)
        case .visual:
            result = await executeVisualCommand(command)
        case .collaboration:
            result = await executeCollaborationCommand(command)
        case .help:
            result = executeHelpCommand(command)
        }

        lastResult = result

        if result.speakResponse {
            speak(result.message)
        }

        return result
    }

    // MARK: Command Execution

    private func executeSessionCommand(_ command: VoiceCommand) async -> CommandResult {
        guard let delegate = delegate else {
            return .failure("Session control not available")
        }

        switch command.action {
        case "start session", "begin session", "new session":
            let name = command.parameters["name"] as? String
            return await delegate.startSession(name: name)
        case "end session", "stop session", "finish session":
            return await delegate.endSession()
        default:
            return .failure("Unknown session command")
        }
    }

    private func executeTransportCommand(_ command: VoiceCommand) async -> CommandResult {
        guard let delegate = delegate else {
            return .failure("Transport control not available")
        }

        switch command.action {
        case "play", "start playing", "resume":
            return await delegate.setTransportState(.playing)
        case "stop", "halt":
            return await delegate.setTransportState(.stopped)
        case "pause":
            return await delegate.setTransportState(.paused)
        case "record", "start recording":
            return await delegate.setTransportState(.recording)
        default:
            return .failure("Unknown transport command")
        }
    }

    private func executeTempoCommand(_ command: VoiceCommand) async -> CommandResult {
        guard let delegate = delegate else {
            return .failure("Tempo control not available")
        }

        if let value = command.parameters["value"] as? Double {
            return await delegate.setTempo(value)
        }

        switch command.action {
        case "faster", "speed up", "increase tempo":
            return await delegate.adjustTempo(delta: 10)
        case "slower", "slow down", "decrease tempo":
            return await delegate.adjustTempo(delta: -10)
        default:
            return .failure("Please specify a tempo value")
        }
    }

    private func executeMixerCommand(_ command: VoiceCommand) async -> CommandResult {
        guard let delegate = delegate else {
            return .failure("Mixer control not available")
        }

        let track = command.parameters["track"] as? String ?? "master"

        switch command.action {
        case "mute":
            return await delegate.muteTrack(track, muted: true)
        case "unmute":
            return await delegate.muteTrack(track, muted: false)
        case "solo":
            return await delegate.soloTrack(track, soloed: true)
        case "unsolo":
            return await delegate.soloTrack(track, soloed: false)
        case "turn up", "increase":
            return await delegate.setTrackVolume(track: track, volume: 0.8)
        case "turn down", "decrease":
            return await delegate.setTrackVolume(track: track, volume: 0.5)
        default:
            return .failure("Unknown mixer command")
        }
    }

    private func executeEffectsCommand(_ command: VoiceCommand) async -> CommandResult {
        guard let delegate = delegate else {
            return .failure("Effects control not available")
        }

        let effect = command.parameters["effect"] as? String ?? "reverb"
        let track = command.parameters["track"] as? String

        if command.action.contains("add") || command.action.contains("more") {
            return await delegate.addEffect(effect, to: track)
        } else if command.action.contains("remove") || command.action.contains("less") {
            return await delegate.removeEffect(effect, from: track)
        }

        return .failure("Unknown effects command")
    }

    private func executePresetCommand(_ command: VoiceCommand) async -> CommandResult {
        guard let delegate = delegate else {
            return .failure("Preset control not available")
        }

        let preset = command.parameters["preset"] as? String ?? "default"

        if command.action.contains("load") || command.action.contains("apply") {
            return await delegate.loadPreset(preset)
        } else if command.action.contains("save") {
            return await delegate.savePreset(preset)
        }

        return .failure("Unknown preset command")
    }

    private func executeBiometricCommand(_ command: VoiceCommand) async -> CommandResult {
        guard let delegate = delegate else {
            return .failure("Biometric control not available")
        }

        if command.action.contains("heart sync") {
            let enable = !command.action.contains("disable")
            return await delegate.setBioReactiveMode(enable)
        }

        if command.action.contains("breathing") {
            return await delegate.startBreathingGuide()
        }

        if command.action.contains("lambda") {
            return await delegate.setBioReactiveMode(true)
        }

        return .failure("Unknown biometric command")
    }

    private func executeVisualCommand(_ command: VoiceCommand) async -> CommandResult {
        guard let delegate = delegate else {
            return .failure("Visual control not available")
        }

        let visual = command.parameters["visual"] as? String ?? "coherence"

        if command.action == "show" || command.action == "display" {
            return await delegate.showVisual(visual)
        } else if command.action == "hide" || command.action == "remove" {
            return await delegate.hideVisual(visual)
        }

        return .failure("Unknown visual command")
    }

    private func executeCollaborationCommand(_ command: VoiceCommand) async -> CommandResult {
        // Collaboration commands would interface with CollaborationHub
        return .failure("Collaboration commands coming soon")
    }

    private func executeHelpCommand(_ command: VoiceCommand) -> CommandResult {
        let helpText = """
        You can say things like:
        • Start session, End session
        • Play, Stop, Pause, Record
        • Set tempo to 120, Faster, Slower
        • Mute drums, Solo vocals
        • Add reverb, Remove delay
        • Load meditation preset
        • Enable heart sync, Start breathing guide
        • Show coherence, Hide waveform
        """
        return .success(helpText)
    }

    // MARK: Speech Synthesis

    private func speak(_ text: String) {
        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.rate = 0.5
        synthesizer.speak(utterance)
    }
}

// MARK: - Voice Controlled Session Manager

/// Main manager combining recognition, parsing, and execution
@MainActor
public class VoiceControlledSessionManager: ObservableObject {

    @Published public var isActive: Bool = false
    @Published public var currentTranscript: String = ""
    @Published public var lastCommand: VoiceCommand?
    @Published public var lastResult: CommandResult?
    @Published public var error: String?

    public let speechEngine = SpeechRecognitionEngine()
    public let commandExecutor = VoiceCommandExecutor()
    private let intentParser = VoiceIntentParser()

    public init() {
        setupObservers()
    }

    private func setupObservers() {
        // In production, use Combine to observe speechEngine changes
    }

    public func start() async throws {
        let authorized = await speechEngine.requestAuthorization()
        guard authorized else {
            throw VoiceControlError.notAuthorized
        }

        try speechEngine.startListening()
        isActive = true
    }

    public func stop() {
        speechEngine.stopListening()
        isActive = false
    }

    public func processCommand(_ text: String) async {
        if let command = intentParser.parse(text) {
            lastCommand = command
            lastResult = await commandExecutor.execute(command)
        }
    }
}

// MARK: - Errors

public enum VoiceControlError: Error {
    case notAuthorized
    case speechRecognizerUnavailable
    case audioEngineUnavailable
    case requestCreationFailed
}

// MARK: - Supported Languages

public enum VoiceControlLanguage: String, CaseIterable {
    case english = "en-US"
    case german = "de-DE"
    case japanese = "ja-JP"
    case spanish = "es-ES"
    case french = "fr-FR"
    case chinese = "zh-CN"
    case korean = "ko-KR"
    case portuguese = "pt-BR"
    case italian = "it-IT"
    case russian = "ru-RU"
    case arabic = "ar-SA"
    case hindi = "hi-IN"
}
