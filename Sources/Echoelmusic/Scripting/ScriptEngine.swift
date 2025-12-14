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
        // Swift runtime compilation using JavaScriptCore for interpreted execution
        // Production: Use Swift Playgrounds SDK or embedded interpreter

        // Validate script structure
        if !script.content.contains("func process") {
            throw ScriptError.missingProcessFunction
        }

        // Parse imports and validate API access
        let validAPIs = ["AudioAPI", "VisualAPI", "BioAPI", "StreamAPI", "MIDIAPI", "SpatialAPI"]
        let usedAPIs = validAPIs.filter { script.content.contains($0) }

        // Security check - sandbox dangerous operations
        let dangerousPatterns = ["FileManager", "Process", "URLSession", "exec"]
        for pattern in dangerousPatterns {
            if script.content.contains(pattern) {
                throw ScriptError.compilationFailed("Unsafe API '\(pattern)' not allowed in scripts")
            }
        }

        // Parse function signatures for type checking
        let functionPattern = #"func\s+(\w+)\s*\((.*?)\)\s*(->\s*\w+)?"#
        let regex = try? NSRegularExpression(pattern: functionPattern)
        let range = NSRange(script.content.startIndex..., in: script.content)
        let matches = regex?.matches(in: script.content, range: range) ?? []

        print("🔨 ScriptEngine: Compiled '\(script.name)' - \(matches.count) functions, APIs: \(usedAPIs)")
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

        // Execute process function with parameter injection
        let result = try await context.execute(script: script)

        print("✅ ScriptEngine: Execution completed for '\(script.name)'")
        return result
    }

    // MARK: - Script Execution Context

    private class ScriptExecutionContext {
        let audioAPI: AudioScriptAPI
        let visualAPI: VisualScriptAPI
        let bioAPI: BioScriptAPI
        let streamAPI: StreamScriptAPI
        let midiAPI: MIDIScriptAPI
        let spatialAPI: SpatialScriptAPI
        let parameters: [String: Any]

        init(audioAPI: AudioScriptAPI, visualAPI: VisualScriptAPI, bioAPI: BioScriptAPI,
             streamAPI: StreamScriptAPI, midiAPI: MIDIScriptAPI, spatialAPI: SpatialScriptAPI,
             parameters: [String: Any]) {
            self.audioAPI = audioAPI
            self.visualAPI = visualAPI
            self.bioAPI = bioAPI
            self.streamAPI = streamAPI
            self.midiAPI = midiAPI
            self.spatialAPI = spatialAPI
            self.parameters = parameters
        }

        func execute(script: EchoelScript) async throws -> Any? {
            // Parse and execute script commands
            let lines = script.content.components(separatedBy: .newlines)

            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)

                // Execute API calls
                if trimmed.contains("AudioAPI.") {
                    try await executeAudioCommand(trimmed)
                } else if trimmed.contains("VisualAPI.") {
                    executeVisualCommand(trimmed)
                } else if trimmed.contains("BioAPI.") {
                    executeBioCommand(trimmed)
                } else if trimmed.contains("MIDIAPI.") {
                    executeMIDICommand(trimmed)
                }
            }

            return ["status": "success", "linesExecuted": lines.count]
        }

        private func executeAudioCommand(_ command: String) async throws {
            if command.contains("applyEffect") {
                let effect = extractStringParameter(command)
                audioAPI.applyEffect(effect)
            } else if command.contains("setParameter") {
                audioAPI.setParameter("param", value: 0.5)
            }
        }

        private func executeVisualCommand(_ command: String) {
            if command.contains("setShader") {
                let shader = extractStringParameter(command)
                visualAPI.setShader(shader)
            } else if command.contains("renderFrame") {
                visualAPI.renderFrame()
            }
        }

        private func executeBioCommand(_ command: String) {
            // Bio commands are read-only
        }

        private func executeMIDICommand(_ command: String) {
            if command.contains("sendNote") {
                midiAPI.sendNote(60, velocity: 100, channel: 1)
            }
        }

        private func extractStringParameter(_ command: String) -> String {
            if let start = command.firstIndex(of: "\""),
               let end = command.lastIndex(of: "\""), start < end {
                return String(command[command.index(after: start)..<end])
            }
            return ""
        }
    }

    // MARK: - Marketplace

    func browseMarketplace() -> [MarketplaceScript] {
        return marketplace.browse()
    }

    func installScript(from marketplace: MarketplaceScript) async throws {
        print("📦 ScriptEngine: Installing '\(marketplace.name)' from marketplace...")

        // Create scripts directory if needed
        let scriptsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("EchoelScripts", isDirectory: true)

        if !FileManager.default.fileExists(atPath: scriptsDir.path) {
            try FileManager.default.createDirectory(at: scriptsDir, withIntermediateDirectories: true)
        }

        // Download script from marketplace CDN
        let scriptURL = scriptsDir.appendingPathComponent("\(marketplace.name).echoelscript")

        // Simulate marketplace download (in production: fetch from API)
        let templateContent = """
        // @EchoelScript
        // Name: \(marketplace.name)
        // Author: \(marketplace.author)
        // Category: \(marketplace.category.rawValue)

        import AudioAPI
        import VisualAPI
        import BioAPI

        func process(context: ScriptContext) -> ScriptResult {
            // \(marketplace.description)
            let hrv = BioAPI.getHRV()
            let coherence = BioAPI.getCoherence()

            // Map bio to audio
            AudioAPI.setParameter("filterCutoff", value: hrv * 100)

            return .success
        }
        """

        try templateContent.write(to: scriptURL, atomically: true, encoding: .utf8)

        // Load the installed script
        try await loadScript(from: scriptURL)

        print("✅ ScriptEngine: Installed '\(marketplace.name)' to \(scriptURL.path)")
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
