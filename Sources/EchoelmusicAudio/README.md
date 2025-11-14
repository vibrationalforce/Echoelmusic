# EchoelmusicAudio

**Purpose:** Audio engine, DSP nodes, routing graph, neural hooks.

## Responsibilities

- AudioCore start/stop, buffer callbacks, routing
- DSP chain (EQ, Compressor, Reverb, Delay, Filter)
- NeuralAudioHooks stub for CoreML/ONNX models (placeholder API only)
- Real-time audio thread safety

## Getting Started

```swift
import EchoelmusicAudio

// Create and start audio engine
let config = AudioEngineConfiguration(
    sampleRate: 48000,
    bufferSize: 512
)
let engine = AudioEngine(config: config)
try engine.start()

// Process audio through routing graph
let graph = RoutingGraph()
graph.addNode(nodeID)
```

## Testing

Run AudioEngine start/stop tests in `Tests/EchoelmusicAudioTests`

## Notes

- Keep audio thread real-time safe (avoid allocations on real-time thread)
- Use RoutingGraph for dynamic signal flow
- NeuralAudioHooks are placeholders for Phase 4 CoreML integration
