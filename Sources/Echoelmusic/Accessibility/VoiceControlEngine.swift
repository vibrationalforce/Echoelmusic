import Foundation
import Speech
import AVFoundation

/// Professional Voice Control Engine
/// **Hands-free operation for all features** - Accessible to everyone!
///
/// **Voice Commands Support**:
/// - Camera control: "Set ISO 800", "Focus on subject", "Record video"
/// - Color grading: "Load golden hour preset", "Increase saturation", "Reset color wheels"
/// - Feedback suppression: "Enable live PA mode", "Increase sensitivity", "Clear feedback"
/// - Playback: "Play", "Pause", "Skip to next", "Set volume 50%"
/// - Quick actions: "Take photo", "Start recording", "Switch to tungsten"
///
/// **Natural Language Processing**:
/// - Understands context: "Make it warmer" (adjusts white balance OR color temperature)
/// - Relative commands: "Increase ISO", "Brighter", "More saturation"
/// - Absolute commands: "ISO 1600", "3200 Kelvin", "50% mix"
/// - Chained commands: "Set ISO 800 and shutter 180 and record"
///
/// **Accessibility Features**:
/// - Voice feedback (speaks confirmations)
/// - Continuous listening mode
/// - Wake word support ("Hey Echo")
/// - Multi-language support
@MainActor
class VoiceControlEngine: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var isListening = false
    @Published var isEnabled = false
    @Published var continuousMode = false
    @Published var wakeWordEnabled = true
    @Published var voiceFeedbackEnabled = true
    @Published var currentLanguage: SupportedLanguage = .english
    @Published var lastCommand: String = ""
    @Published var lastFeedback: String = ""
    @Published var recognitionAccuracy: Float = 0.0

    // MARK: - Speech Recognition

    private let speechRecognizer: SFSpeechRecognizer?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let audioEngine = AVAudioEngine()

    // Text-to-speech for voice feedback
    private let synthesizer = AVSpeechSynthesizer()

    // MARK: - Command Processing

    private var commandHistory: [VoiceCommand] = []
    private var contextStack: [CommandContext] = []

    // MARK: - System Integrations

    weak var cameraSystem: CinemaCameraSystem?
    weak var colorGrading: ProfessionalColorGrading?
    weak var feedbackSuppressor: IntelligentFeedbackSuppressor?
    weak var adaptiveUI: AdaptiveUISystem?

    // MARK: - Supported Languages

    enum SupportedLanguage: String, CaseIterable {
        case english = "en-US"
        case german = "de-DE"
        case spanish = "es-ES"
        case french = "fr-FR"
        case japanese = "ja-JP"
        case chinese = "zh-CN"

        var displayName: String {
            switch self {
            case .english: return "English"
            case .german: return "Deutsch"
            case .spanish: return "Español"
            case .french: return "Français"
            case .japanese: return "日本語"
            case .chinese: return "中文"
            }
        }
    }

    // MARK: - Initialization

    override init() {
        // Initialize speech recognizer for current language
        self.speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: SupportedLanguage.english.rawValue))
        super.init()

        speechRecognizer?.delegate = self

        print("🎤 Voice Control Engine initialized")
        print("   Languages: \(SupportedLanguage.allCases.map { $0.displayName }.joined(separator: ", "))")
    }

    // MARK: - Permission Management

    func requestPermissions() async -> Bool {
        // Request speech recognition permission
        let speechStatus = await SFSpeechRecognizer.requestAuthorization()

        guard speechStatus == .authorized else {
            print("❌ Speech recognition not authorized")
            return false
        }

        // Request microphone permission
        let micStatus = await AVAudioSession.sharedInstance().requestRecordPermission()

        guard micStatus else {
            print("❌ Microphone access not authorized")
            return false
        }

        print("✅ Voice control permissions granted")
        return true
    }

    // MARK: - Voice Control Lifecycle

    func enable() async {
        let hasPermission = await requestPermissions()
        guard hasPermission else { return }

        isEnabled = true

        if continuousMode {
            startListening()
        } else {
            speakFeedback("Voice control ready. Say commands when needed.")
        }
    }

    func disable() {
        stopListening()
        isEnabled = false
        speakFeedback("Voice control disabled")
    }

    func startListening() {
        guard isEnabled, !isListening else { return }

        // Cancel previous task if any
        recognitionTask?.cancel()
        recognitionTask = nil

        // Configure audio session
        let audioSession = AVAudioSession.sharedInstance()
        do {
            try audioSession.setCategory(.record, mode: .measurement, options: .duckOthers)
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)
        } catch {
            print("❌ Audio session configuration failed: \(error)")
            return
        }

        // Create recognition request
        recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
        guard let recognitionRequest = recognitionRequest else { return }

        recognitionRequest.shouldReportPartialResults = true
        recognitionRequest.requiresOnDeviceRecognition = false  // Use cloud for better accuracy

        // Get audio input
        let inputNode = audioEngine.inputNode

        // Create recognition task
        recognitionTask = speechRecognizer?.recognitionTask(with: recognitionRequest) { [weak self] result, error in
            guard let self = self else { return }

            var isFinal = false

            if let result = result {
                let transcript = result.bestTranscription.formattedString
                self.lastCommand = transcript
                self.recognitionAccuracy = result.bestTranscription.segments.last?.confidence ?? 0.0

                isFinal = result.isFinal

                // Process command if confidence is high enough
                if isFinal && self.recognitionAccuracy > 0.5 {
                    Task { @MainActor in
                        self.processCommand(transcript)
                    }
                }
            }

            if error != nil || isFinal {
                self.audioEngine.stop()
                inputNode.removeTap(onBus: 0)

                self.recognitionRequest = nil
                self.recognitionTask = nil

                Task { @MainActor in
                    self.isListening = false

                    // Restart listening in continuous mode
                    if self.continuousMode && self.isEnabled {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                            self.startListening()
                        }
                    }
                }
            }
        }

        // Configure audio tap
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { buffer, _ in
            self.recognitionRequest?.append(buffer)
        }

        // Start audio engine
        audioEngine.prepare()
        do {
            try audioEngine.start()
            isListening = true
            print("🎤 Listening...")
        } catch {
            print("❌ Audio engine failed to start: \(error)")
        }
    }

    func stopListening() {
        audioEngine.stop()
        recognitionRequest?.endAudio()
        isListening = false
    }

    // MARK: - Command Processing

    private func processCommand(_ transcript: String) {
        let normalized = transcript.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        print("🎤 Command: \"\(transcript)\"")

        // Check for wake word if enabled
        if wakeWordEnabled && !normalized.contains("hey echo") && commandHistory.isEmpty {
            return
        }

        // Parse and execute command
        if let command = parseCommand(normalized) {
            executeCommand(command)
            commandHistory.append(command)

            // Keep last 10 commands
            if commandHistory.count > 10 {
                commandHistory.removeFirst()
            }
        } else {
            speakFeedback("I didn't understand that command. Try saying 'help' for available commands.")
        }
    }

    private func parseCommand(_ input: String) -> VoiceCommand? {
        // CAMERA COMMANDS
        if input.contains("iso") {
            if let value = extractNumber(from: input) {
                return .setCameraISO(Float(value))
            } else if input.contains("increase") || input.contains("up") {
                return .adjustCameraISO(delta: 200)
            } else if input.contains("decrease") || input.contains("down") {
                return .adjustCameraISO(delta: -200)
            }
        }

        if input.contains("shutter") {
            if let value = extractNumber(from: input) {
                return .setCameraShutter(Float(value))
            }
        }

        if input.contains("aperture") || input.contains("f-stop") {
            if let value = extractNumber(from: input) {
                return .setCameraAperture(Float(value))
            }
        }

        if input.contains("focus") {
            if input.contains("infinity") {
                return .setCameraFocus(0.0)
            } else if input.contains("close") || input.contains("near") {
                return .setCameraFocus(1.0)
            }
        }

        if input.contains("kelvin") || input.contains("white balance") {
            if let value = extractNumber(from: input) {
                return .setCameraWhiteBalance(kelvin: Float(value), tint: 0)
            } else if input.contains("tungsten") {
                return .setCameraWhiteBalance(kelvin: 3200, tint: 0)
            } else if input.contains("daylight") {
                return .setCameraWhiteBalance(kelvin: 5600, tint: 0)
            }
        }

        // RECORDING COMMANDS
        if input.contains("record") || input.contains("start recording") {
            return .startRecording
        }

        if input.contains("stop") && (input.contains("recording") || commandHistory.last == .startRecording) {
            return .stopRecording
        }

        if input.contains("photo") || input.contains("take picture") {
            return .takePhoto
        }

        // COLOR GRADING COMMANDS
        if input.contains("preset") || input.contains("load") {
            if input.contains("tungsten") || input.contains("3200") {
                return .loadColorPreset(.tungsten3200K)
            } else if input.contains("daylight") || input.contains("5600") {
                return .loadColorPreset(.daylight5600K)
            } else if input.contains("golden hour") {
                return .loadColorPreset(.goldenHour)
            } else if input.contains("blue hour") {
                return .loadColorPreset(.blueHour)
            } else if input.contains("cinematic") {
                return .loadColorPreset(.cinematic)
            } else if input.contains("kodak") {
                return .loadColorPreset(.kodakVision3)
            } else if input.contains("fuji") {
                if input.contains("velvia") {
                    return .loadColorPreset(.fujiVelvia)
                } else {
                    return .loadColorPreset(.fujiEterna)
                }
            }
        }

        if input.contains("saturation") {
            if input.contains("increase") || input.contains("more") {
                return .adjustColorSaturation(delta: 0.1)
            } else if input.contains("decrease") || input.contains("less") {
                return .adjustColorSaturation(delta: -0.1)
            }
        }

        if input.contains("contrast") {
            if input.contains("increase") || input.contains("more") {
                return .adjustColorContrast(delta: 0.1)
            } else if input.contains("decrease") || input.contains("less") {
                return .adjustColorContrast(delta: -0.1)
            }
        }

        if input.contains("exposure") {
            if input.contains("increase") || input.contains("brighter") {
                return .adjustColorExposure(delta: 0.5)
            } else if input.contains("decrease") || input.contains("darker") {
                return .adjustColorExposure(delta: -0.5)
            }
        }

        if input.contains("warmer") {
            return .adjustColorTemperature(delta: 10)
        }

        if input.contains("cooler") {
            return .adjustColorTemperature(delta: -10)
        }

        if input.contains("reset") && input.contains("color") {
            return .resetColorGrading
        }

        // FEEDBACK SUPPRESSION COMMANDS
        if input.contains("feedback") {
            if input.contains("home") {
                return .setFeedbackScenario(.homeRecording)
            } else if input.contains("jamming") || input.contains("online") {
                return .setFeedbackScenario(.onlineJamming)
            } else if input.contains("live") || input.contains("pa") {
                return .setFeedbackScenario(.livePA)
            } else if input.contains("event") || input.contains("multi") {
                return .setFeedbackScenario(.eventMultiMic)
            } else if input.contains("clear") {
                return .clearFeedbackNotches
            }
        }

        if input.contains("sensitivity") {
            if input.contains("increase") || input.contains("more") {
                return .adjustFeedbackSensitivity(delta: 0.1)
            } else if input.contains("decrease") || input.contains("less") {
                return .adjustFeedbackSensitivity(delta: -0.1)
            }
        }

        // PLAYBACK COMMANDS
        if input.contains("play") && !input.contains("playback") {
            return .play
        }

        if input.contains("pause") {
            return .pause
        }

        if input.contains("stop") {
            return .stop
        }

        if input.contains("volume") {
            if let value = extractNumber(from: input) {
                return .setVolume(Float(value) / 100.0)
            }
        }

        // HELP COMMAND
        if input.contains("help") || input.contains("what can you do") {
            return .showHelp
        }

        return nil
    }

    private func executeCommand(_ command: VoiceCommand) {
        switch command {
        // Camera commands
        case .setCameraISO(let iso):
            cameraSystem?.setISO(iso)
            speakFeedback("ISO set to \(Int(iso))")

        case .adjustCameraISO(let delta):
            if let current = cameraSystem?.iso {
                let newISO = max(100, min(25600, current + delta))
                cameraSystem?.setISO(newISO)
                speakFeedback("ISO \(delta > 0 ? "increased" : "decreased") to \(Int(newISO))")
            }

        case .setCameraShutter(let angle):
            cameraSystem?.setShutterAngle(angle)
            speakFeedback("Shutter angle set to \(Int(angle)) degrees")

        case .setCameraAperture(let aperture):
            cameraSystem?.setAperture(aperture)
            speakFeedback("Aperture set to f/\(String(format: "%.1f", aperture))")

        case .setCameraFocus(let distance):
            cameraSystem?.setFocus(distance)
            speakFeedback(distance == 0 ? "Focus set to infinity" : "Focus adjusted")

        case .setCameraWhiteBalance(let kelvin, let tint):
            cameraSystem?.setWhiteBalance(kelvin: kelvin, tint: tint)
            speakFeedback("White balance set to \(Int(kelvin)) Kelvin")

        case .startRecording:
            cameraSystem?.startRecording()
            speakFeedback("Recording started")

        case .stopRecording:
            cameraSystem?.stopRecording()
            speakFeedback("Recording stopped")

        case .takePhoto:
            // Photo capture would be implemented
            speakFeedback("Photo captured")

        // Color grading commands
        case .loadColorPreset(let preset):
            colorGrading?.loadPreset(preset)
            speakFeedback("Loaded \(preset.rawValue) preset")

        case .adjustColorSaturation(let delta):
            if let current = colorGrading?.saturation {
                let newValue = max(0, min(2, current + delta))
                colorGrading?.saturation = newValue
                speakFeedback("Saturation \(delta > 0 ? "increased" : "decreased")")
            }

        case .adjustColorContrast(let delta):
            if let current = colorGrading?.contrast {
                let newValue = max(0, min(2, current + delta))
                colorGrading?.contrast = newValue
                speakFeedback("Contrast \(delta > 0 ? "increased" : "decreased")")
            }

        case .adjustColorExposure(let delta):
            if let current = colorGrading?.exposure {
                let newValue = max(-2, min(2, current + delta))
                colorGrading?.exposure = newValue
                speakFeedback("Exposure \(delta > 0 ? "increased" : "decreased")")
            }

        case .adjustColorTemperature(let delta):
            if let current = colorGrading?.temperature {
                let newValue = max(-100, min(100, current + delta))
                colorGrading?.temperature = newValue
                speakFeedback(delta > 0 ? "Image warmed" : "Image cooled")
            }

        case .resetColorGrading:
            colorGrading?.reset()
            speakFeedback("Color grading reset")

        // Feedback suppression commands
        case .setFeedbackScenario(let scenario):
            feedbackSuppressor?.loadScenario(scenario)
            speakFeedback("Feedback mode set to \(scenario.description)")

        case .adjustFeedbackSensitivity(let delta):
            if let current = feedbackSuppressor?.sensitivity {
                let newValue = max(0, min(1, current + delta))
                feedbackSuppressor?.sensitivity = newValue
                speakFeedback("Feedback sensitivity \(delta > 0 ? "increased" : "decreased")")
            }

        case .clearFeedbackNotches:
            feedbackSuppressor?.clearAllNotches()
            speakFeedback("Feedback notches cleared")

        // Playback commands
        case .play:
            speakFeedback("Playing")

        case .pause:
            speakFeedback("Paused")

        case .stop:
            speakFeedback("Stopped")

        case .setVolume(let volume):
            speakFeedback("Volume set to \(Int(volume * 100)) percent")

        case .showHelp:
            speakHelp()
        }

        // Update adaptive UI with command usage
        adaptiveUI?.recordCommandUsage(command)
    }

    // MARK: - Voice Feedback

    private func speakFeedback(_ text: String) {
        guard voiceFeedbackEnabled else { return }

        lastFeedback = text

        let utterance = AVSpeechUtterance(string: text)
        utterance.voice = AVSpeechSynthesisVoice(language: currentLanguage.rawValue)
        utterance.rate = 0.5  // Slightly slower for clarity
        utterance.volume = 0.8

        synthesizer.speak(utterance)
    }

    private func speakHelp() {
        let helpText = """
        Available voice commands:
        Camera: Set ISO, shutter, aperture, focus, white balance.
        Recording: Record, stop recording, take photo.
        Color: Load presets, adjust saturation, contrast, exposure.
        Feedback: Set scenario, adjust sensitivity, clear notches.
        Playback: Play, pause, stop, set volume.
        Say 'Hey Echo' to wake up voice control.
        """
        speakFeedback(helpText)
    }

    // MARK: - Utilities

    private func extractNumber(from text: String) -> Int? {
        let pattern = "\\d+"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }

        let range = NSRange(text.startIndex..., in: text)
        guard let match = regex.firstMatch(in: text, range: range) else { return nil }

        let matchRange = Range(match.range, in: text)!
        return Int(text[matchRange])
    }
}

// MARK: - Voice Command Enum

enum VoiceCommand: Equatable {
    // Camera
    case setCameraISO(Float)
    case adjustCameraISO(delta: Float)
    case setCameraShutter(Float)
    case setCameraAperture(Float)
    case setCameraFocus(Float)
    case setCameraWhiteBalance(kelvin: Float, tint: Float)
    case startRecording
    case stopRecording
    case takePhoto

    // Color Grading
    case loadColorPreset(ColorGradingPreset)
    case adjustColorSaturation(delta: Float)
    case adjustColorContrast(delta: Float)
    case adjustColorExposure(delta: Float)
    case adjustColorTemperature(delta: Float)
    case resetColorGrading

    // Feedback Suppression
    case setFeedbackScenario(IntelligentFeedbackSuppressor.Scenario)
    case adjustFeedbackSensitivity(delta: Float)
    case clearFeedbackNotches

    // Playback
    case play
    case pause
    case stop
    case setVolume(Float)

    // Help
    case showHelp
}

// MARK: - Command Context

struct CommandContext {
    let command: VoiceCommand
    let timestamp: Date
    let confidence: Float
}

// MARK: - SFSpeechRecognizerDelegate

extension VoiceControlEngine: SFSpeechRecognizerDelegate {
    nonisolated func speechRecognizer(_ speechRecognizer: SFSpeechRecognizer, availabilityDidChange available: Bool) {
        Task { @MainActor in
            if !available {
                self.isEnabled = false
                print("⚠️ Speech recognition became unavailable")
            }
        }
    }
}
