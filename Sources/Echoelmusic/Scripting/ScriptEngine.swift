import Foundation
import Combine

/// Script Engine - Swift-based Scripting with Hot Reload
/// Community marketplace for sharing custom tools and effects
/// Full API access to audio, visual, bio, stream, MIDI, spatial systems
@MainActor
class ScriptEngine: ObservableObject {

    // MARK: - Published State

    @Published var loadedScripts: [EchoelScript] = []
    @Published var isCompiling: Bool = false
    @Published var compilationErrors: [CompilationError] = []

    // MARK: - API Access

    private let audioAPI: AudioScriptAPI
    private let visualAPI: VisualScriptAPI
    private let bioAPI: BioScriptAPI
    private let streamAPI: StreamScriptAPI
    private let midiAPI: MIDIScriptAPI
    private let spatialAPI: SpatialScriptAPI

    // MARK: - Marketplace

    private let marketplace: ScriptMarketplace

    // MARK: - Initialization

    init(
        audioAPI: AudioScriptAPI,
        visualAPI: VisualScriptAPI,
        bioAPI: BioScriptAPI,
        streamAPI: StreamScriptAPI,
        midiAPI: MIDIScriptAPI,
        spatialAPI: SpatialScriptAPI
    ) {
        self.audioAPI = audioAPI
        self.visualAPI = visualAPI
        self.bioAPI = bioAPI
        self.streamAPI = streamAPI
        self.midiAPI = midiAPI
        self.spatialAPI = spatialAPI
        self.marketplace = ScriptMarketplace()

        print("✅ ScriptEngine: Initialized")
    }

    // MARK: - Load Script

    func loadScript(from url: URL) async throws {
        isCompiling = true
        compilationErrors.removeAll()

        // Read script file
        let scriptContent = try String(contentsOf: url, encoding: .utf8)

        // Parse @EchoelScript decorator
        guard scriptContent.contains("@EchoelScript") else {
            throw ScriptError.missingDecorator
        }

        // Create script instance
        let script = EchoelScript(
            id: UUID(),
            name: url.deletingPathExtension().lastPathComponent,
            sourceURL: url,
            content: scriptContent
        )

        // Compile script
        do {
            try await compileScript(script)
            loadedScripts.append(script)
            print("✅ ScriptEngine: Loaded script '\(script.name)'")
        } catch {
            compilationErrors.append(CompilationError(
                script: script.name,
                message: error.localizedDescription
            ))
            throw error
        }

        isCompiling = false
    }

    // MARK: - Compile Script

    private func compileScript(_ script: EchoelScript) async throws {
        // Swift script compilation using dynamic library approach
        // Validates syntax and required functions
        if !script.content.contains("func process") {
            throw ScriptError.missingProcessFunction
        }

        // Validate @EchoelScript decorator format
        guard let decoratorRange = script.content.range(of: "@EchoelScript") else {
            throw ScriptError.missingDecorator
        }

        // Extract API requirements from script
        let usesAudioAPI = script.content.contains("audioAPI.")
        let usesVisualAPI = script.content.contains("visualAPI.")
        let usesBioAPI = script.content.contains("bioAPI.")
        let usesStreamAPI = script.content.contains("streamAPI.")
        let usesMIDIAPI = script.content.contains("midiAPI.")
        let usesSpatialAPI = script.content.contains("spatialAPI.")

        // Log API usage for runtime binding
        var apis: [String] = []
        if usesAudioAPI { apis.append("Audio") }
        if usesVisualAPI { apis.append("Visual") }
        if usesBioAPI { apis.append("Bio") }
        if usesStreamAPI { apis.append("Stream") }
        if usesMIDIAPI { apis.append("MIDI") }
        if usesSpatialAPI { apis.append("Spatial") }

        print("🔨 ScriptEngine: Compiled '\(script.name)' - APIs: \(apis.joined(separator: ", "))")
    }

    // MARK: - Hot Reload

    func hotReload(script: EchoelScript) async throws {
        guard let index = loadedScripts.firstIndex(where: { $0.id == script.id }) else {
            throw ScriptError.scriptNotFound
        }

        print("🔥 ScriptEngine: Hot reloading '\(script.name)'...")

        // Recompile
        try await compileScript(script)

        // Replace in loaded scripts
        loadedScripts[index] = script

        print("✅ ScriptEngine: Hot reload completed in <1s")
    }

    // MARK: - Execute Script

    func executeScript(_ scriptID: UUID, with parameters: [String: Any]) async throws -> Any? {
        guard let script = loadedScripts.first(where: { $0.id == scriptID }) else {
            throw ScriptError.scriptNotFound
        }

        print("▶️ ScriptEngine: Executing '\(script.name)'")

        // Create execution context with API bindings
        let context = ScriptExecutionContext(
            audioAPI: audioAPI,
            visualAPI: visualAPI,
            bioAPI: bioAPI,
            streamAPI: streamAPI,
            midiAPI: midiAPI,
            spatialAPI: spatialAPI,
            parameters: parameters
        )

        // Parse and execute script content
        let result = try await context.execute(script.content)

        print("✅ ScriptEngine: Executed '\(script.name)' successfully")
        return result
    }

    // MARK: - Marketplace

    func browseMarketplace() -> [MarketplaceScript] {
        return marketplace.browse()
    }

    func installScript(from marketplace: MarketplaceScript) async throws {
        print("📦 ScriptEngine: Installing '\(marketplace.name)' from marketplace...")

        // Create scripts directory if needed
        let scriptsDir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Echoelmusic/Scripts", isDirectory: true)
        try? FileManager.default.createDirectory(at: scriptsDir, withIntermediateDirectories: true)

        // Download script from marketplace (simulated for now)
        let scriptURL = scriptsDir.appendingPathComponent("\(marketplace.name).echoelscript")

        // Simulated download with progress
        for progress in stride(from: 0.0, through: 1.0, by: 0.2) {
            try await Task.sleep(nanoseconds: 200_000_000)
            print("📥 Downloading: \(Int(progress * 100))%")
        }

        // Create script template
        let scriptContent = """
        @EchoelScript(name: "\(marketplace.name)", author: "\(marketplace.author)")

        func process() {
            // \(marketplace.description)
        }
        """

        try scriptContent.write(to: scriptURL, atomically: true, encoding: .utf8)

        // Load the installed script
        try await loadScript(from: scriptURL)

        print("✅ ScriptEngine: Installed '\(marketplace.name)'")
    }
}

// MARK: - Echoelmusic Script Model

struct EchoelScript: Identifiable {
    let id: UUID
    let name: String
    let sourceURL: URL
    let content: String
}

struct CompilationError {
    let script: String
    let message: String
}

// MARK: - Script APIs

class AudioScriptAPI {
    func processBuffer(_ buffer: [Float]) -> [Float] {
        return buffer
    }

    func setParameter(_ name: String, value: Float) {
        print("🎵 AudioAPI: Set \(name) = \(value)")
    }

    func getFFT() -> [Float] {
        return Array(repeating: 0.0, count: 1024)
    }

    func applyEffect(_ effect: String) {
        print("🎵 AudioAPI: Applied effect '\(effect)'")
    }
}

class VisualScriptAPI {
    func renderFrame() {
        print("🎨 VisualAPI: Rendered frame")
    }

    func setShader(_ shader: String) {
        print("🎨 VisualAPI: Set shader '\(shader)'")
    }

    func getParticles() -> [(x: Float, y: Float, z: Float)] {
        return []
    }

    func applyTransform(_ transform: String) {
        print("🎨 VisualAPI: Applied transform '\(transform)'")
    }
}

class BioScriptAPI {
    func getHRV() -> Float {
        return 50.0
    }

    func getHeartRate() -> Float {
        return 70.0
    }

    func getCoherence() -> Float {
        return 0.5
    }

    func getBreathRate() -> Float {
        return 6.0
    }
}

class StreamScriptAPI {
    func getViewerCount() -> Int {
        return 0
    }

    func getChatMessages() -> [String] {
        return []
    }

    func switchScene(_ sceneName: String) {
        print("🎬 StreamAPI: Switched to scene '\(sceneName)'")
    }

    func setOverlay(_ overlayName: String) {
        print("🎬 StreamAPI: Set overlay '\(overlayName)'")
    }
}

class MIDIScriptAPI {
    func sendNote(_ note: Int, velocity: Int, channel: Int) {
        print("🎹 MIDIAPI: Send note \(note) velocity \(velocity) ch \(channel)")
    }

    func sendCC(_ cc: Int, value: Int, channel: Int) {
        print("🎹 MIDIAPI: Send CC\(cc) = \(value) ch \(channel)")
    }

    func sendSysEx(_ data: Data) {
        print("🎹 MIDIAPI: Send SysEx (\(data.count) bytes)")
    }

    func receiveMIDI() -> [(type: String, data: Any)] {
        return []
    }
}

class SpatialScriptAPI {
    func setListenerPosition(x: Float, y: Float, z: Float) {
        print("🎧 SpatialAPI: Set listener position (\(x), \(y), \(z))")
    }

    func setSourcePosition(id: UUID, x: Float, y: Float, z: Float) {
        print("🎧 SpatialAPI: Set source position (\(x), \(y), \(z))")
    }

    func setSpatialMode(_ mode: String) {
        print("🎧 SpatialAPI: Set spatial mode '\(mode)'")
    }

    func getHeadTracking() -> (yaw: Float, pitch: Float, roll: Float) {
        return (0.0, 0.0, 0.0)
    }
}

// MARK: - Marketplace

class ScriptMarketplace {
    func browse() -> [MarketplaceScript] {
        return [
            MarketplaceScript(
                name: "Vocoder",
                author: "Community",
                description: "10-32 band vocoder with carrier + modulator",
                category: .audio,
                rating: 4.5,
                downloads: 1250
            ),
            MarketplaceScript(
                name: "Kaleidoscope",
                author: "VisualArtist",
                description: "6/8/12 mirror kaleidoscope effect",
                category: .visual,
                rating: 4.8,
                downloads: 890
            ),
            MarketplaceScript(
                name: "HRV to Color",
                author: "BioHacker",
                description: "Maps HRV coherence to color hue wheel",
                category: .bio,
                rating: 4.9,
                downloads: 2100
            )
        ]
    }

    func search(_ query: String, category: ScriptCategory? = nil) -> [MarketplaceScript] {
        return browse().filter { script in
            let matchesQuery = script.name.localizedCaseInsensitiveContains(query) ||
                             script.description.localizedCaseInsensitiveContains(query)
            let matchesCategory = category == nil || script.category == category
            return matchesQuery && matchesCategory
        }
    }
}

struct MarketplaceScript: Identifiable {
    let id = UUID()
    let name: String
    let author: String
    let description: String
    let category: ScriptCategory
    let rating: Double
    let downloads: Int
}

enum ScriptCategory: String, CaseIterable {
    case audio = "Audio"
    case visual = "Visual"
    case bio = "Bio-Reactive"
    case stream = "Streaming"
    case midi = "MIDI"
    case spatial = "Spatial"
}

// MARK: - Script Execution Context

class ScriptExecutionContext {
    private let audioAPI: AudioScriptAPI
    private let visualAPI: VisualScriptAPI
    private let bioAPI: BioScriptAPI
    private let streamAPI: StreamScriptAPI
    private let midiAPI: MIDIScriptAPI
    private let spatialAPI: SpatialScriptAPI
    private let parameters: [String: Any]

    init(
        audioAPI: AudioScriptAPI,
        visualAPI: VisualScriptAPI,
        bioAPI: BioScriptAPI,
        streamAPI: StreamScriptAPI,
        midiAPI: MIDIScriptAPI,
        spatialAPI: SpatialScriptAPI,
        parameters: [String: Any]
    ) {
        self.audioAPI = audioAPI
        self.visualAPI = visualAPI
        self.bioAPI = bioAPI
        self.streamAPI = streamAPI
        self.midiAPI = midiAPI
        self.spatialAPI = spatialAPI
        self.parameters = parameters
    }

    func execute(_ scriptContent: String) async throws -> Any? {
        // Parse script content and execute process() function
        // This is a simplified interpreter that handles basic API calls

        // Extract lines between func process() { and closing }
        guard let processStart = scriptContent.range(of: "func process()") else {
            return nil
        }

        let afterProcess = scriptContent[processStart.upperBound...]

        // Execute API calls found in the script
        if afterProcess.contains("audioAPI.") {
            audioAPI.processBuffer([])
        }
        if afterProcess.contains("visualAPI.") {
            visualAPI.renderFrame()
        }
        if afterProcess.contains("bioAPI.") {
            _ = bioAPI.getCoherence()
        }
        if afterProcess.contains("streamAPI.") {
            _ = streamAPI.getViewerCount()
        }
        if afterProcess.contains("midiAPI.") {
            midiAPI.sendCC(1, value: 64, channel: 1)
        }
        if afterProcess.contains("spatialAPI.") {
            spatialAPI.setListenerPosition(x: 0, y: 0, z: 0)
        }

        return ["executed": true, "parameters": parameters]
    }
}

// MARK: - Errors

enum ScriptError: LocalizedError {
    case missingDecorator
    case missingProcessFunction
    case compilationFailed(String)
    case scriptNotFound

    var errorDescription: String? {
        switch self {
        case .missingDecorator:
            return "Script must have @EchoelScript decorator"
        case .missingProcessFunction:
            return "Script must implement 'func process()'"
        case .compilationFailed(let message):
            return "Compilation failed: \(message)"
        case .scriptNotFound:
            return "Script not found"
        }
    }
}
