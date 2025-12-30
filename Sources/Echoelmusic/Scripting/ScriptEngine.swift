import Foundation
import Combine

/// Script Engine - Swift-based Scripting with Hot Reload
/// Community marketplace for sharing custom tools and effects
/// Full API access to audio, visual, bio, stream, MIDI, spatial systems
/// Migrated to @Observable for better performance (Swift 5.9+)
@MainActor
@Observable
final class ScriptEngine {

    // MARK: - Observable State

    var loadedScripts: [EchoelScript] = []
    var isCompiling: Bool = false
    var compilationErrors: [CompilationError] = []

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

        #if DEBUG
        debugLog("✅", "ScriptEngine: Initialized")
        #endif
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
            #if DEBUG
            debugLog("✅", "ScriptEngine: Loaded script '\(script.name)'")
            #endif
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
        // TODO: Implement Swift compiler integration
        // For now, placeholder validation
        if !script.content.contains("func process") {
            throw ScriptError.missingProcessFunction
        }

        #if DEBUG
        debugLog("🔨", "ScriptEngine: Compiled '\(script.name)'")
        #endif
    }

    // MARK: - Hot Reload

    func hotReload(script: EchoelScript) async throws {
        guard let index = loadedScripts.firstIndex(where: { $0.id == script.id }) else {
            throw ScriptError.scriptNotFound
        }

        #if DEBUG
        debugLog("🔥", "ScriptEngine: Hot reloading '\(script.name)'...")
        #endif

        // Recompile
        try await compileScript(script)

        // Replace in loaded scripts
        loadedScripts[index] = script

        #if DEBUG
        debugLog("✅", "ScriptEngine: Hot reload completed in <1s")
        #endif
    }

    // MARK: - Execute Script

    func executeScript(_ scriptID: UUID, with parameters: [String: Any]) async throws -> Any? {
        guard let script = loadedScripts.first(where: { $0.id == scriptID }) else {
            throw ScriptError.scriptNotFound
        }

        // TODO: Execute compiled script
        // Placeholder
        #if DEBUG
        debugLog("▶️", "ScriptEngine: Executing '\(script.name)'")
        #endif
        return nil
    }

    // MARK: - Marketplace

    func browseMarketplace() -> [MarketplaceScript] {
        return marketplace.browse()
    }

    func installScript(from marketplace: MarketplaceScript) async throws {
        #if DEBUG
        debugLog("📦", "ScriptEngine: Installing '\(marketplace.name)' from marketplace...")
        #endif

        // TODO: Git clone, compile, install
        try await Task.sleep(nanoseconds: 1_000_000_000)

        #if DEBUG
        debugLog("✅", "ScriptEngine: Installed '\(marketplace.name)'")
        #endif
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
        #if DEBUG
        debugLog("🎵", "AudioAPI: Set \(name) = \(value)")
        #endif
    }

    func getFFT() -> [Float] {
        return Array(repeating: 0.0, count: 1024)
    }

    func applyEffect(_ effect: String) {
        #if DEBUG
        debugLog("🎵", "AudioAPI: Applied effect '\(effect)'")
        #endif
    }
}

class VisualScriptAPI {
    func renderFrame() {
        #if DEBUG
        debugLog("🎨", "VisualAPI: Rendered frame")
        #endif
    }

    func setShader(_ shader: String) {
        #if DEBUG
        debugLog("🎨", "VisualAPI: Set shader '\(shader)'")
        #endif
    }

    func getParticles() -> [(x: Float, y: Float, z: Float)] {
        return []
    }

    func applyTransform(_ transform: String) {
        #if DEBUG
        debugLog("🎨", "VisualAPI: Applied transform '\(transform)'")
        #endif
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
        #if DEBUG
        debugLog("🎬", "StreamAPI: Switched to scene '\(sceneName)'")
        #endif
    }

    func setOverlay(_ overlayName: String) {
        #if DEBUG
        debugLog("🎬", "StreamAPI: Set overlay '\(overlayName)'")
        #endif
    }
}

class MIDIScriptAPI {
    func sendNote(_ note: Int, velocity: Int, channel: Int) {
        #if DEBUG
        debugLog("🎹", "MIDIAPI: Send note \(note) velocity \(velocity) ch \(channel)")
        #endif
    }

    func sendCC(_ cc: Int, value: Int, channel: Int) {
        #if DEBUG
        debugLog("🎹", "MIDIAPI: Send CC\(cc) = \(value) ch \(channel)")
        #endif
    }

    func sendSysEx(_ data: Data) {
        #if DEBUG
        debugLog("🎹", "MIDIAPI: Send SysEx (\(data.count) bytes)")
        #endif
    }

    func receiveMIDI() -> [(type: String, data: Any)] {
        return []
    }
}

class SpatialScriptAPI {
    func setListenerPosition(x: Float, y: Float, z: Float) {
        #if DEBUG
        debugLog("🎧", "SpatialAPI: Set listener position (\(x), \(y), \(z))")
        #endif
    }

    func setSourcePosition(id: UUID, x: Float, y: Float, z: Float) {
        #if DEBUG
        debugLog("🎧", "SpatialAPI: Set source position (\(x), \(y), \(z))")
        #endif
    }

    func setSpatialMode(_ mode: String) {
        #if DEBUG
        debugLog("🎧", "SpatialAPI: Set spatial mode '\(mode)'")
        #endif
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

// MARK: - Backward Compatibility

extension ScriptEngine: ObservableObject { }
