import Foundation
import Combine

/// Macro System for BLAB Automation
///
/// Features:
/// - Record and playback action sequences
/// - Conditional logic (if/then/else)
/// - Timed actions and delays
/// - Parameter automation
/// - Trigger on events
/// - Save/load macros
///
/// Usage:
/// ```swift
/// let macro = Macro(name: "Go Live")
/// macro.addAction(.enableNDI)
/// macro.addAction(.enableRTMP(key: "..."))
/// macro.addAction(.startRecording)
/// MacroSystem.shared.execute(macro)
/// ```
@available(iOS 15.0, *)
public class MacroSystem: ObservableObject {

    // MARK: - Singleton

    public static let shared = MacroSystem()

    // MARK: - Published Properties

    @Published public private(set) var macros: [Macro] = []
    @Published public private(set) var isRecording: Bool = false
    @Published public private(set) var isExecuting: Bool = false
    @Published public private(set) var currentMacro: Macro?

    // MARK: - Macro Definition

    public struct Macro: Identifiable, Codable {
        public let id: UUID
        public var name: String
        public var actions: [MacroAction]
        public var trigger: MacroTrigger
        public var enabled: Bool

        public init(id: UUID = UUID(), name: String, actions: [MacroAction] = [],
                   trigger: MacroTrigger = .manual, enabled: Bool = true) {
            self.id = id
            self.name = name
            self.actions = actions
            self.trigger = trigger
            self.enabled = enabled
        }
    }

    // MARK: - Macro Actions

    public enum MacroAction: Codable {
        case startAudio
        case stopAudio
        case toggleSpatial
        case toggleBinaural
        case enableNDI
        case disableNDI
        case enableRTMP(streamKey: String, platform: String)
        case disableRTMP
        case startRecording
        case stopRecording
        case setDSPPreset(preset: String)
        case enableNoiseGate(threshold: Float)
        case enableCompressor(threshold: Float, ratio: Float)
        case enableLimiter(threshold: Float)
        case setBitrate(bitrate: Int)
        case setSampleRate(sampleRate: Int)
        case setBufferSize(bufferSize: Int)
        case streamDeckButton(index: Int)
        case delay(seconds: Double)
        case conditional(condition: String, thenActions: [MacroAction], elseActions: [MacroAction])
        case log(message: String)
        case notify(title: String, message: String)

        var description: String {
            switch self {
            case .startAudio: return "Start Audio Engine"
            case .stopAudio: return "Stop Audio Engine"
            case .toggleSpatial: return "Toggle Spatial Audio"
            case .toggleBinaural: return "Toggle Binaural Beats"
            case .enableNDI: return "Enable NDI"
            case .disableNDI: return "Disable NDI"
            case .enableRTMP(let key, let platform): return "Enable RTMP (\(platform))"
            case .disableRTMP: return "Disable RTMP"
            case .startRecording: return "Start Recording"
            case .stopRecording: return "Stop Recording"
            case .setDSPPreset(let preset): return "DSP Preset: \(preset)"
            case .enableNoiseGate(let threshold): return "Noise Gate (\(threshold) dB)"
            case .enableCompressor(let threshold, let ratio): return "Compressor (\(threshold) dB, \(ratio):1)"
            case .enableLimiter(let threshold): return "Limiter (\(threshold) dB)"
            case .setBitrate(let bitrate): return "Bitrate: \(bitrate) kbps"
            case .setSampleRate(let rate): return "Sample Rate: \(rate) Hz"
            case .setBufferSize(let size): return "Buffer: \(size) frames"
            case .streamDeckButton(let index): return "Stream Deck Button \(index)"
            case .delay(let seconds): return "Wait \(seconds)s"
            case .conditional(let condition, _, _): return "If \(condition)"
            case .log(let message): return "Log: \(message)"
            case .notify(let title, _): return "Notify: \(title)"
            }
        }
    }

    // MARK: - Macro Triggers

    public enum MacroTrigger: Codable {
        case manual
        case onAppStart
        case onAudioStart
        case onAudioStop
        case onNDIConnect
        case onRTMPConnect
        case onRecordingStart
        case onTimer(interval: TimeInterval)
        case onBiometric(condition: String)

        var description: String {
            switch self {
            case .manual: return "Manual"
            case .onAppStart: return "On App Start"
            case .onAudioStart: return "When Audio Starts"
            case .onAudioStop: return "When Audio Stops"
            case .onNDIConnect: return "When NDI Connects"
            case .onRTMPConnect: return "When RTMP Connects"
            case .onRecordingStart: return "When Recording Starts"
            case .onTimer(let interval): return "Every \(interval)s"
            case .onBiometric(let condition): return "Biometric: \(condition)"
            }
        }
    }

    // MARK: - Private Properties

    private var recordedActions: [MacroAction] = []
    private var cancellables = Set<AnyCancellable>()
    private weak var audioEngine: AudioEngine?
    private weak var controlHub: UnifiedControlHub?

    // MARK: - Initialization

    private init() {
        loadMacros()
        setupTriggers()
    }

    // MARK: - Setup

    public func setup(audioEngine: AudioEngine, controlHub: UnifiedControlHub) {
        self.audioEngine = audioEngine
        self.controlHub = controlHub

        print("[Macro] ✅ System initialized")
    }

    // MARK: - Macro Management

    /// Add a macro
    public func addMacro(_ macro: Macro) {
        macros.append(macro)
        saveMacros()
        print("[Macro] ✅ Added: \(macro.name)")
    }

    /// Remove a macro
    public func removeMacro(_ macro: Macro) {
        macros.removeAll { $0.id == macro.id }
        saveMacros()
        print("[Macro] Removed: \(macro.name)")
    }

    /// Update a macro
    public func updateMacro(_ macro: Macro) {
        if let index = macros.firstIndex(where: { $0.id == macro.id }) {
            macros[index] = macro
            saveMacros()
            print("[Macro] ✅ Updated: \(macro.name)")
        }
    }

    // MARK: - Recording

    /// Start recording a new macro
    public func startRecording(name: String) {
        guard !isRecording else {
            print("[Macro] Already recording")
            return
        }

        isRecording = true
        recordedActions = []
        currentMacro = Macro(name: name)

        print("[Macro] 🔴 Recording started: \(name)")
    }

    /// Record an action
    public func recordAction(_ action: MacroAction) {
        guard isRecording else { return }
        recordedActions.append(action)
        print("[Macro] 📝 Recorded: \(action.description)")
    }

    /// Stop recording and save macro
    public func stopRecording() {
        guard isRecording else { return }

        if var macro = currentMacro {
            macro.actions = recordedActions
            addMacro(macro)
        }

        isRecording = false
        recordedActions = []
        currentMacro = nil

        print("[Macro] ⏹️ Recording stopped")
    }

    /// Cancel recording
    public func cancelRecording() {
        isRecording = false
        recordedActions = []
        currentMacro = nil
        print("[Macro] ❌ Recording cancelled")
    }

    // MARK: - Execution

    /// Execute a macro
    public func execute(_ macro: Macro) async {
        guard !isExecuting else {
            print("[Macro] Already executing a macro")
            return
        }

        guard macro.enabled else {
            print("[Macro] Macro is disabled: \(macro.name)")
            return
        }

        isExecuting = true
        currentMacro = macro

        print("[Macro] ▶️ Executing: \(macro.name)")

        for action in macro.actions {
            await executeAction(action)
        }

        isExecuting = false
        currentMacro = nil

        print("[Macro] ✅ Completed: \(macro.name)")
    }

    /// Execute by name
    public func execute(named name: String) async {
        guard let macro = macros.first(where: { $0.name == name }) else {
            print("[Macro] ⚠️ Macro not found: \(name)")
            return
        }

        await execute(macro)
    }

    /// Execute a single action
    private func executeAction(_ action: MacroAction) async {
        guard let audioEngine = audioEngine else {
            print("[Macro] ⚠️ Audio engine not available")
            return
        }

        print("[Macro] → \(action.description)")

        switch action {
        case .startAudio:
            audioEngine.start()

        case .stopAudio:
            audioEngine.stop()

        case .toggleSpatial:
            audioEngine.toggleSpatialAudio()

        case .toggleBinaural:
            audioEngine.toggleBinauralBeats()

        case .enableNDI:
            controlHub?.quickEnableNDI()

        case .disableNDI:
            audioEngine.disableNDI()

        case .enableRTMP(let streamKey, let platform):
            // Would need proper platform enum conversion
            print("[Macro] RTMP: \(platform) with key: \(streamKey.prefix(8))...")

        case .disableRTMP:
            audioEngine.disableRTMP()

        case .startRecording:
            print("[Macro] Start recording (TODO)")

        case .stopRecording:
            print("[Macro] Stop recording (TODO)")

        case .setDSPPreset(let preset):
            if let presetEnum = AdvancedDSP.Preset(rawValue: preset) {
                audioEngine.dspProcessor.applyPreset(presetEnum)
            }

        case .enableNoiseGate(let threshold):
            audioEngine.dspProcessor.advanced.enableNoiseGate(threshold: threshold)

        case .enableCompressor(let threshold, let ratio):
            audioEngine.dspProcessor.advanced.enableCompressor(threshold: threshold, ratio: ratio)

        case .enableLimiter(let threshold):
            audioEngine.dspProcessor.advanced.enableLimiter(threshold: threshold)

        case .setBitrate(let bitrate):
            print("[Macro] Set bitrate: \(bitrate) kbps")

        case .setSampleRate(let rate):
            print("[Macro] Set sample rate: \(rate) Hz")

        case .setBufferSize(let size):
            print("[Macro] Set buffer size: \(size) frames")

        case .streamDeckButton(let index):
            StreamDeckController.shared.handleButtonPress(index)

        case .delay(let seconds):
            try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))

        case .conditional(let condition, let thenActions, let elseActions):
            let conditionMet = evaluateCondition(condition)
            let actions = conditionMet ? thenActions : elseActions
            for action in actions {
                await executeAction(action)
            }

        case .log(let message):
            print("[Macro] 📝 \(message)")

        case .notify(let title, let message):
            print("[Macro] 🔔 \(title): \(message)")
        }
    }

    // MARK: - Conditional Logic

    private func evaluateCondition(_ condition: String) -> Bool {
        guard let audioEngine = audioEngine else { return false }

        // Simple condition evaluation
        switch condition {
        case "audio_running":
            return audioEngine.isRunning
        case "ndi_enabled":
            return audioEngine.isNDIEnabled
        case "rtmp_enabled":
            return audioEngine.isRTMPEnabled
        case "spatial_enabled":
            return audioEngine.spatialAudioEnabled
        default:
            return false
        }
    }

    // MARK: - Triggers

    private func setupTriggers() {
        // Setup automatic triggers
        // This would subscribe to various events and execute macros
    }

    // MARK: - Persistence

    private func saveMacros() {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .prettyPrinted

        do {
            let data = try encoder.encode(macros)
            UserDefaults.standard.set(data, forKey: "blab_macros")
            print("[Macro] 💾 Saved \(macros.count) macros")
        } catch {
            print("[Macro] ❌ Failed to save: \(error)")
        }
    }

    private func loadMacros() {
        guard let data = UserDefaults.standard.data(forKey: "blab_macros") else {
            print("[Macro] No saved macros found")
            createDefaultMacros()
            return
        }

        let decoder = JSONDecoder()
        do {
            macros = try decoder.decode([Macro].self, from: data)
            print("[Macro] ✅ Loaded \(macros.count) macros")
        } catch {
            print("[Macro] ❌ Failed to load: \(error)")
            createDefaultMacros()
        }
    }

    // MARK: - Default Macros

    private func createDefaultMacros() {
        // "Go Live" macro
        var goLive = Macro(name: "Go Live")
        goLive.actions = [
            .startAudio,
            .delay(seconds: 1.0),
            .enableNDI,
            .delay(seconds: 0.5),
            .setDSPPreset(preset: "Broadcast"),
            .log(message: "Going live!")
        ]
        macros.append(goLive)

        // "Start Recording" macro
        var startRecording = Macro(name: "Start Recording Session")
        startRecording.actions = [
            .setDSPPreset(preset: "Vocals"),
            .enableNoiseGate(threshold: -40),
            .enableCompressor(threshold: -18, ratio: 3.0),
            .enableLimiter(threshold: -1.0),
            .startRecording,
            .notify(title: "Recording", message: "Session started")
        ]
        macros.append(startRecording)

        // "Shutdown" macro
        var shutdown = Macro(name: "Shutdown")
        shutdown.actions = [
            .stopRecording,
            .disableRTMP,
            .disableNDI,
            .delay(seconds: 1.0),
            .stopAudio,
            .log(message: "Shutdown complete")
        ]
        macros.append(shutdown)

        saveMacros()
        print("[Macro] ✅ Created default macros")
    }
}
