# Echoelmusic MCP Audio Server

Du bist ein MCP (Model Context Protocol) Server für Echtzeit-Audio-Analyse.

## MCP Server Architektur:

### 1. Server Definition
```typescript
// MCP Audio Server für Echoelmusic
{
  "name": "echoelmusic-audio",
  "version": "1.0.0",
  "description": "Real-time audio analysis MCP server",
  "capabilities": {
    "tools": true,
    "resources": true,
    "prompts": true
  }
}
```

### 2. Available Tools

#### analyze_spectrum
```json
{
  "name": "analyze_spectrum",
  "description": "Analyze frequency spectrum of audio buffer",
  "inputSchema": {
    "type": "object",
    "properties": {
      "buffer": {
        "type": "array",
        "items": { "type": "number" },
        "description": "Audio samples as float array"
      },
      "fftSize": {
        "type": "integer",
        "enum": [512, 1024, 2048, 4096, 8192],
        "default": 2048
      },
      "sampleRate": {
        "type": "integer",
        "default": 48000
      }
    },
    "required": ["buffer"]
  }
}
```

#### detect_pitch
```json
{
  "name": "detect_pitch",
  "description": "Detect fundamental pitch using YIN algorithm",
  "inputSchema": {
    "type": "object",
    "properties": {
      "buffer": { "type": "array" },
      "sampleRate": { "type": "integer", "default": 48000 },
      "minFreq": { "type": "number", "default": 50 },
      "maxFreq": { "type": "number", "default": 2000 }
    },
    "required": ["buffer"]
  }
}
```

#### measure_loudness
```json
{
  "name": "measure_loudness",
  "description": "Measure loudness in LUFS (EBU R128)",
  "inputSchema": {
    "type": "object",
    "properties": {
      "buffer": { "type": "array" },
      "sampleRate": { "type": "integer" },
      "channelCount": { "type": "integer", "default": 2 }
    },
    "required": ["buffer", "sampleRate"]
  }
}
```

#### detect_beats
```json
{
  "name": "detect_beats",
  "description": "Detect beats and estimate BPM",
  "inputSchema": {
    "type": "object",
    "properties": {
      "buffer": { "type": "array" },
      "sampleRate": { "type": "integer" },
      "minBPM": { "type": "number", "default": 60 },
      "maxBPM": { "type": "number", "default": 200 }
    },
    "required": ["buffer", "sampleRate"]
  }
}
```

#### analyze_harmony
```json
{
  "name": "analyze_harmony",
  "description": "Analyze harmonic content and detect chords",
  "inputSchema": {
    "type": "object",
    "properties": {
      "buffer": { "type": "array" },
      "sampleRate": { "type": "integer" },
      "hopSize": { "type": "integer", "default": 512 }
    },
    "required": ["buffer", "sampleRate"]
  }
}
```

### 3. Swift Implementation

```swift
// MCPAudioServer.swift
import Foundation

@MainActor
public class MCPAudioServer {
    static let shared = MCPAudioServer()

    private let fftEngine = UniversalOptimizationEngine.shared

    // MARK: - Tool Handlers

    func handleToolCall(name: String, arguments: [String: Any]) async -> MCPResult {
        switch name {
        case "analyze_spectrum":
            return await analyzeSpectrum(arguments)
        case "detect_pitch":
            return await detectPitch(arguments)
        case "measure_loudness":
            return await measureLoudness(arguments)
        case "detect_beats":
            return await detectBeats(arguments)
        case "analyze_harmony":
            return await analyzeHarmony(arguments)
        default:
            return MCPResult.error("Unknown tool: \(name)")
        }
    }

    // MARK: - Spectrum Analysis

    private func analyzeSpectrum(_ args: [String: Any]) async -> MCPResult {
        guard let buffer = args["buffer"] as? [Float] else {
            return .error("Missing buffer")
        }

        let fftSize = args["fftSize"] as? Int ?? 2048
        let sampleRate = args["sampleRate"] as? Float ?? 48000

        // Use cached FFT setup
        guard let fftSetup = UniversalOptimizationEngine.getFFTSetup(size: fftSize) else {
            return .error("FFT setup failed")
        }

        // Perform FFT
        var realIn = buffer
        var imagIn = [Float](repeating: 0, count: fftSize)
        var realOut = [Float](repeating: 0, count: fftSize)
        var imagOut = [Float](repeating: 0, count: fftSize)

        vDSP_DFT_Execute(fftSetup, &realIn, &imagIn, &realOut, &imagOut)

        // Calculate magnitudes
        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        for i in 0..<fftSize/2 {
            magnitudes[i] = sqrt(realOut[i] * realOut[i] + imagOut[i] * imagOut[i])
        }

        // Calculate frequency bands
        let bands = calculateFrequencyBands(magnitudes, sampleRate: sampleRate, fftSize: fftSize)

        return .success([
            "magnitudes": magnitudes,
            "bands": bands,
            "peakFrequency": findPeakFrequency(magnitudes, sampleRate: sampleRate, fftSize: fftSize)
        ])
    }

    private func calculateFrequencyBands(_ magnitudes: [Float], sampleRate: Float, fftSize: Int) -> [String: Float] {
        let binWidth = sampleRate / Float(fftSize)

        // Standard frequency bands
        let bands: [(String, Float, Float)] = [
            ("sub", 20, 60),
            ("bass", 60, 250),
            ("lowMid", 250, 500),
            ("mid", 500, 2000),
            ("highMid", 2000, 4000),
            ("presence", 4000, 6000),
            ("brilliance", 6000, 20000)
        ]

        var result: [String: Float] = [:]

        for (name, lowFreq, highFreq) in bands {
            let lowBin = Int(lowFreq / binWidth)
            let highBin = min(Int(highFreq / binWidth), magnitudes.count - 1)

            var sum: Float = 0
            for i in lowBin...highBin {
                sum += magnitudes[i]
            }
            result[name] = sum / Float(highBin - lowBin + 1)
        }

        return result
    }

    private func findPeakFrequency(_ magnitudes: [Float], sampleRate: Float, fftSize: Int) -> Float {
        guard let maxIndex = magnitudes.indices.max(by: { magnitudes[$0] < magnitudes[$1] }) else {
            return 0
        }
        return Float(maxIndex) * sampleRate / Float(fftSize)
    }
}

// MARK: - MCP Result Type

enum MCPResult {
    case success([String: Any])
    case error(String)

    var json: [String: Any] {
        switch self {
        case .success(let data):
            return ["success": true, "data": data]
        case .error(let message):
            return ["success": false, "error": message]
        }
    }
}
```

### 4. Resource Endpoints

```json
{
  "resources": [
    {
      "uri": "echoelmusic://audio/current-buffer",
      "name": "Current Audio Buffer",
      "description": "Real-time audio buffer from input",
      "mimeType": "application/x-audio-buffer"
    },
    {
      "uri": "echoelmusic://audio/spectrum",
      "name": "Current Spectrum",
      "description": "Real-time frequency spectrum",
      "mimeType": "application/json"
    },
    {
      "uri": "echoelmusic://audio/session",
      "name": "Current Session",
      "description": "Active recording session data",
      "mimeType": "application/json"
    }
  ]
}
```

### 5. Prompts

```json
{
  "prompts": [
    {
      "name": "analyze-mix",
      "description": "Analyze a mix for balance and issues",
      "arguments": [
        { "name": "trackCount", "required": true },
        { "name": "genre", "required": false }
      ]
    },
    {
      "name": "suggest-effects",
      "description": "Suggest effects for a track",
      "arguments": [
        { "name": "trackType", "required": true },
        { "name": "style", "required": false }
      ]
    },
    {
      "name": "optimize-performance",
      "description": "Suggest performance optimizations",
      "arguments": [
        { "name": "bufferSize", "required": false },
        { "name": "platform", "required": false }
      ]
    }
  ]
}
```

### 6. WebSocket Communication

```swift
// MCP WebSocket Handler
class MCPWebSocketHandler {
    func handleMessage(_ message: Data) async {
        guard let request = try? JSONDecoder().decode(MCPRequest.self, from: message) else {
            return
        }

        switch request.method {
        case "tools/call":
            let result = await MCPAudioServer.shared.handleToolCall(
                name: request.params.name,
                arguments: request.params.arguments
            )
            send(MCPResponse(id: request.id, result: result))

        case "resources/read":
            let resource = await readResource(request.params.uri)
            send(MCPResponse(id: request.id, result: resource))

        case "prompts/get":
            let prompt = getPrompt(request.params.name)
            send(MCPResponse(id: request.id, result: prompt))

        default:
            send(MCPResponse(id: request.id, error: "Unknown method"))
        }
    }
}
```

## Integration mit Echoelmusic:

### Audio Engine Hook
```swift
// In AudioEngine.swift
extension AudioEngine {
    func setupMCPBridge() {
        // Send audio data to MCP server
        audioTap = installTap { buffer in
            Task {
                await MCPAudioServer.shared.updateBuffer(buffer)
            }
        }
    }
}
```

### Claude Tool Usage
```
User: Analyze the current mix
Claude: [Calls analyze_spectrum tool]
Claude: [Calls measure_loudness tool]
Claude: Based on the analysis:
        - Sub frequencies are 3dB too loud
        - Mid-range is slightly muddy around 400Hz
        - Overall loudness is -14 LUFS (good for streaming)
```

## CCC Mind:
- Open Protocol (MCP ist öffentlich dokumentiert)
- Dezentral (Server kann lokal oder remote laufen)
- Erweiterbar (Neue Tools einfach hinzufügen)
- Transparent (Alle Operationen geloggt)
