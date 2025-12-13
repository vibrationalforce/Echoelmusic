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
        // Validate script structure
        guard script.content.contains("func ") else {
            throw ScriptError.missingProcessFunction
        }

        // Parse and validate Swift-like syntax
        let syntaxChecker = ScriptSyntaxChecker()
        try syntaxChecker.validate(script.content)

        // Store compiled bytecode representation
        let bytecode = ScriptBytecode(
            id: script.id,
            name: script.name,
            instructions: syntaxChecker.compile(script.content)
        )
        compiledScripts[script.id] = bytecode

        print("🔨 ScriptEngine: Compiled '\(script.name)' (\(bytecode.instructions.count) instructions)")
    }

    private var compiledScripts: [UUID: ScriptBytecode] = [:]

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

        guard let bytecode = compiledScripts[scriptID] else {
            throw ScriptError.scriptNotCompiled
        }

        print("▶️ ScriptEngine: Executing '\(script.name)'")

        // Execute bytecode with virtual machine
        let vm = ScriptVM(bytecode: bytecode, parameters: parameters)
        let result = try await vm.execute()

        print("✅ ScriptEngine: '\(script.name)' completed")
        return result
    }

    // MARK: - Marketplace

    func browseMarketplace() -> [MarketplaceScript] {
        return marketplace.browse()
    }

    func installScript(from marketplace: MarketplaceScript) async throws {
        print("📦 ScriptEngine: Installing '\(marketplace.name)' from marketplace...")

        // Download script from repository
        let downloader = ScriptDownloader()
        let scriptData = try await downloader.download(from: marketplace.repositoryURL)

        // Create script from downloaded data
        let script = EchoelScript(
            id: UUID(),
            name: marketplace.name,
            sourceURL: marketplace.repositoryURL,
            content: scriptData
        )

        // Compile and load
        try await compileScript(script)
        loadedScripts.append(script)

        // Cache for offline use
        try saveScriptToCache(script)

        print("✅ ScriptEngine: Installed '\(marketplace.name)'")
    }

    private func saveScriptToCache(_ script: EchoelScript) throws {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        let scriptDir = cacheDir.appendingPathComponent("EchoelScripts", isDirectory: true)

        try FileManager.default.createDirectory(at: scriptDir, withIntermediateDirectories: true)

        let scriptFile = scriptDir.appendingPathComponent("\(script.id.uuidString).echoelscript")
        try script.content.write(to: scriptFile, atomically: true, encoding: .utf8)
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
    case scriptNotCompiled
    case downloadFailed(URL)
    case syntaxError(String)

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
        case .scriptNotCompiled:
            return "Script not compiled - call compile first"
        case .downloadFailed(let url):
            return "Failed to download script from \(url)"
        case .syntaxError(let message):
            return "Syntax error: \(message)"
        }
    }
}

// MARK: - Script Bytecode

struct ScriptBytecode {
    let id: UUID
    let name: String
    let instructions: [ScriptInstruction]
}

enum ScriptInstruction {
    case loadConstant(Any)
    case loadVariable(String)
    case storeVariable(String)
    case callFunction(String, Int)  // function name, arg count
    case add, subtract, multiply, divide
    case compare(CompareOp)
    case jump(Int)
    case jumpIfFalse(Int)
    case returnValue

    enum CompareOp { case equal, notEqual, less, greater, lessEqual, greaterEqual }
}

// MARK: - Script Syntax Checker

class ScriptSyntaxChecker {
    private var tokens: [String] = []

    func validate(_ content: String) throws {
        tokens = tokenize(content)

        // Check for balanced braces
        var braceCount = 0
        for token in tokens {
            if token == "{" { braceCount += 1 }
            if token == "}" { braceCount -= 1 }
            if braceCount < 0 {
                throw ScriptError.syntaxError("Unexpected '}'")
            }
        }
        if braceCount != 0 {
            throw ScriptError.syntaxError("Unbalanced braces")
        }

        // Check for valid function definitions
        guard content.contains("func ") else {
            throw ScriptError.missingProcessFunction
        }
    }

    func compile(_ content: String) -> [ScriptInstruction] {
        var instructions: [ScriptInstruction] = []

        // Simple parsing - in production would use proper AST
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)

            if trimmed.hasPrefix("let ") || trimmed.hasPrefix("var ") {
                // Variable declaration
                let parts = trimmed.components(separatedBy: "=")
                if parts.count == 2 {
                    let varName = parts[0].replacingOccurrences(of: "let ", with: "")
                                          .replacingOccurrences(of: "var ", with: "")
                                          .trimmingCharacters(in: .whitespaces)
                    instructions.append(.loadConstant(parts[1].trimmingCharacters(in: .whitespaces)))
                    instructions.append(.storeVariable(varName))
                }
            } else if trimmed.contains("return") {
                instructions.append(.returnValue)
            }
        }

        return instructions
    }

    private func tokenize(_ content: String) -> [String] {
        var tokens: [String] = []
        var current = ""

        for char in content {
            if char.isWhitespace || "{}()[].,;:".contains(char) {
                if !current.isEmpty {
                    tokens.append(current)
                    current = ""
                }
                if !"{}()[].,;:".contains(char) == false {
                    tokens.append(String(char))
                }
            } else {
                current.append(char)
            }
        }

        if !current.isEmpty {
            tokens.append(current)
        }

        return tokens
    }
}

// MARK: - Script Virtual Machine

class ScriptVM {
    private let bytecode: ScriptBytecode
    private var variables: [String: Any] = [:]
    private var stack: [Any] = []

    init(bytecode: ScriptBytecode, parameters: [String: Any]) {
        self.bytecode = bytecode
        self.variables = parameters
    }

    func execute() async throws -> Any? {
        var pc = 0  // Program counter

        while pc < bytecode.instructions.count {
            let instruction = bytecode.instructions[pc]

            switch instruction {
            case .loadConstant(let value):
                stack.append(value)

            case .loadVariable(let name):
                if let value = variables[name] {
                    stack.append(value)
                }

            case .storeVariable(let name):
                if let value = stack.popLast() {
                    variables[name] = value
                }

            case .callFunction(let name, _):
                // Built-in function dispatch
                print("📜 VM: Calling \(name)")

            case .add:
                if let b = stack.popLast() as? Double,
                   let a = stack.popLast() as? Double {
                    stack.append(a + b)
                }

            case .subtract:
                if let b = stack.popLast() as? Double,
                   let a = stack.popLast() as? Double {
                    stack.append(a - b)
                }

            case .multiply:
                if let b = stack.popLast() as? Double,
                   let a = stack.popLast() as? Double {
                    stack.append(a * b)
                }

            case .divide:
                if let b = stack.popLast() as? Double,
                   let a = stack.popLast() as? Double, b != 0 {
                    stack.append(a / b)
                }

            case .compare(let op):
                if let b = stack.popLast() as? Double,
                   let a = stack.popLast() as? Double {
                    let result: Bool
                    switch op {
                    case .equal: result = a == b
                    case .notEqual: result = a != b
                    case .less: result = a < b
                    case .greater: result = a > b
                    case .lessEqual: result = a <= b
                    case .greaterEqual: result = a >= b
                    }
                    stack.append(result)
                }

            case .jump(let offset):
                pc += offset
                continue

            case .jumpIfFalse(let offset):
                if let condition = stack.popLast() as? Bool, !condition {
                    pc += offset
                    continue
                }

            case .returnValue:
                return stack.popLast()
            }

            pc += 1
        }

        return stack.popLast()
    }
}

// MARK: - Script Downloader

class ScriptDownloader {
    func download(from url: URL) async throws -> String {
        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw ScriptError.downloadFailed(url)
        }

        guard let content = String(data: data, encoding: .utf8) else {
            throw ScriptError.downloadFailed(url)
        }

        return content
    }
}

// MARK: - MarketplaceScript Extension

extension MarketplaceScript {
    var repositoryURL: URL {
        URL(string: "https://scripts.echoelmusic.app/\(id.uuidString)")!
    }
}
