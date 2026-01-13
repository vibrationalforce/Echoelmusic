# EchoelCore Swift Integration Guide

## Overview

This guide explains how to integrate the C++ EchoelCore framework with your Swift/iOS/macOS application using the Objective-C++ bridge.

## Architecture

```
┌─────────────────────────────────────────────────────────────────┐
│                        Swift Application                         │
│                                                                 │
│  ┌──────────────┐    ┌──────────────┐    ┌──────────────┐      │
│  │ SwiftUI      │    │ AudioEngine  │    │ HealthKit    │      │
│  │ Views        │    │ (AVAudio)    │    │ Manager      │      │
│  └──────┬───────┘    └──────┬───────┘    └──────┬───────┘      │
│         │                   │                   │               │
│         └───────────────────┼───────────────────┘               │
│                             │                                   │
│                    ┌────────▼────────┐                          │
│                    │ EchoelCoreBridge │  ◄── Objective-C++     │
│                    │    (ObjC++)      │                         │
│                    └────────┬────────┘                          │
└─────────────────────────────┼───────────────────────────────────┘
                              │
┌─────────────────────────────┼───────────────────────────────────┐
│                    ┌────────▼────────┐                          │
│                    │   LambdaLoop    │  ◄── C++17               │
│                    │  (60Hz Control) │                          │
│                    └────────┬────────┘                          │
│                             │                                   │
│         ┌───────────────────┼───────────────────┐               │
│         │                   │                   │               │
│  ┌──────▼──────┐    ┌──────▼──────┐    ┌──────▼──────┐         │
│  │ MCPBioServer│    │ WebXRBridge │    │  Photonic   │         │
│  │ (AI Agents) │    │ (VR/AR/PWA) │    │ Interconnect│         │
│  └─────────────┘    └─────────────┘    └─────────────┘         │
│                                                                 │
│                      EchoelCore (C++17)                         │
└─────────────────────────────────────────────────────────────────┘
```

## Setup

### 1. Add Bridge Files to Xcode Project

Copy the following files to your Xcode project:

```
Sources/EchoelCore/Bridge/
├── EchoelCoreBridge.h      # Objective-C header (import in bridging header)
├── EchoelCoreBridge.mm     # Objective-C++ implementation
└── INTEGRATION.md          # This file
```

### 2. Create Bridging Header

Create `YourApp-Bridging-Header.h`:

```objc
#import "EchoelCoreBridge.h"
```

In Xcode Build Settings:
- Set "Objective-C Bridging Header" to `$(SRCROOT)/YourApp/YourApp-Bridging-Header.h`

### 3. Enable C++17

In Build Settings:
- Set "C++ Language Dialect" to `C++17` or `GNU++17`
- Add `$(SRCROOT)/Sources/EchoelCore` to "Header Search Paths"

## Usage Examples

### Basic Setup

```swift
import Foundation

class EchoelManager: ObservableObject {
    private let bridge = EchoelCoreBridge()
    private var displayLink: CADisplayLink?

    @Published var lambdaScore: Float = 0
    @Published var state: ECLambdaState = .dormant

    func start() {
        // Initialize
        guard bridge.initialize() else {
            print("Failed to initialize EchoelCore")
            return
        }

        // Set up event callback
        bridge.setEventCallback { [weak self] event in
            self?.handleEvent(event)
        }

        // Start the loop
        bridge.start()

        // Set up 60Hz tick via CADisplayLink
        displayLink = CADisplayLink(target: self, selector: #selector(tick))
        displayLink?.preferredFrameRateRange = CAFrameRateRange(minimum: 60, maximum: 60)
        displayLink?.add(to: .main, forMode: .common)
    }

    func stop() {
        displayLink?.invalidate()
        displayLink = nil
        bridge.shutdown()
    }

    @objc private func tick() {
        bridge.tick()

        // Update published properties
        DispatchQueue.main.async {
            self.lambdaScore = self.bridge.lambdaScore
            self.state = self.bridge.state
        }
    }

    private func handleEvent(_ event: ECLambdaEvent) {
        switch event.type {
        case .stateTransition:
            print("State changed: \(EchoelCoreBridge.stateName(for: ECLambdaState(rawValue: Int(event.value2))!))")
        case .coherenceChanged:
            print("Coherence: \(event.value1) → \(event.value2)")
        default:
            break
        }
    }
}
```

### HealthKit Integration

```swift
import HealthKit

extension EchoelManager {
    func connectHealthKit() {
        let healthStore = HKHealthStore()

        // Request heart rate authorization
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!

        healthStore.requestAuthorization(toShare: nil, read: [heartRateType]) { success, error in
            guard success else { return }
            self.startHeartRateQuery(healthStore: healthStore)
        }
    }

    private func startHeartRateQuery(healthStore: HKHealthStore) {
        let heartRateType = HKQuantityType.quantityType(forIdentifier: .heartRate)!

        let query = HKAnchoredObjectQuery(
            type: heartRateType,
            predicate: nil,
            anchor: nil,
            limit: HKObjectQueryNoLimit
        ) { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHeartRateSamples(samples as? [HKQuantitySample])
        }

        query.updateHandler = { [weak self] query, samples, deletedObjects, anchor, error in
            self?.processHeartRateSamples(samples as? [HKQuantitySample])
        }

        healthStore.execute(query)
    }

    private func processHeartRateSamples(_ samples: [HKQuantitySample]?) {
        guard let sample = samples?.last else { return }

        let heartRate = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))

        // Calculate HRV and coherence from RR intervals (simplified)
        let hrv: Float = 0.5  // Replace with actual HRV calculation
        let coherence: Float = 0.5  // Replace with HeartMath algorithm

        // Update EchoelCore
        bridge.updateBioData(
            withHRV: hrv,
            coherence: coherence,
            heartRate: Float(heartRate),
            breathPhase: 0  // From breathing sensor
        )
    }
}
```

### Audio Integration

```swift
import AVFoundation

extension EchoelManager {
    func setupAudio() {
        // Configure audio session
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? session.setActive(true)

        // Create audio engine
        let engine = AVAudioEngine()
        let mainMixer = engine.mainMixerNode
        let output = engine.outputNode
        let format = output.inputFormat(forBus: 0)

        // Install tap for bio-reactive processing
        mainMixer.installTap(onBus: 0, bufferSize: 512, format: format) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer)
        }

        try? engine.start()
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }
        let frameCount = Int(buffer.frameLength)

        // Process through photonic pipeline
        var outputBuffer = [Float](repeating: 0, count: frameCount)
        bridge.processPhotonicAudioInput(
            channelData[0],
            output: &outputBuffer,
            size: UInt(frameCount)
        )

        // Copy back to buffer
        memcpy(channelData[0], outputBuffer, frameCount * MemoryLayout<Float>.size)
    }
}
```

### WebXR/Spatial Audio

```swift
extension EchoelManager {
    func setupSpatialAudio() {
        // Start VR session
        bridge.startXRSession(.immersiveVR)

        // Add spatial sources
        let sourceId = bridge.addSpatialSource(atX: 0, y: 0, z: 2)  // 2m in front

        print("Created spatial source: \(sourceId)")
    }

    func renderSpatialAudio(leftBuffer: UnsafeMutablePointer<Float>,
                            rightBuffer: UnsafeMutablePointer<Float>,
                            frames: Int) {
        bridge.processSpatialAudioLeft(leftBuffer, right: rightBuffer, frames: UInt(frames))
    }
}
```

### MCP Server for AI Agents

```swift
extension EchoelManager {
    func handleAIAgentMessage(_ json: String) -> String {
        return bridge.handleMCPMessage(json)
    }

    // Example: Set up WebSocket server for Claude Code integration
    func setupMCPServer() {
        // This would connect to your WebSocket server
        // that receives MCP messages from AI agents

        // Example message handling:
        let response = handleAIAgentMessage("""
        {
            "jsonrpc": "2.0",
            "method": "tools/call",
            "params": {
                "name": "getBioState"
            },
            "id": 1
        }
        """)

        print("MCP Response: \(response)")
    }
}
```

### SwiftUI Integration

```swift
import SwiftUI

struct LambdaStatusView: View {
    @ObservedObject var manager: EchoelManager

    var body: some View {
        VStack(spacing: 20) {
            // Lambda Score Gauge
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 20)

                Circle()
                    .trim(from: 0, to: CGFloat(manager.lambdaScore))
                    .stroke(lambdaColor, style: StrokeStyle(lineWidth: 20, lineCap: .round))
                    .rotationEffect(.degrees(-90))

                VStack {
                    Text("λ")
                        .font(.system(size: 40, weight: .thin))
                    Text(String(format: "%.0f%%", manager.lambdaScore * 100))
                        .font(.title2)
                }
            }
            .frame(width: 200, height: 200)

            // State Label
            Text(EchoelCoreBridge.stateName(for: manager.state))
                .font(.headline)
                .foregroundColor(stateColor)
        }
    }

    var lambdaColor: Color {
        switch manager.lambdaScore {
        case 0..<0.3: return .red
        case 0.3..<0.6: return .orange
        case 0.6..<0.8: return .yellow
        case 0.8..<0.95: return .green
        default: return .purple  // Transcendent
        }
    }

    var stateColor: Color {
        switch manager.state {
        case .dormant: return .gray
        case .active: return .blue
        case .flowing: return .green
        case .transcendent: return .purple
        case .degrading: return .orange
        default: return .primary
        }
    }
}
```

## Thread Safety Notes

1. **Bio Updates**: Call `updateBioData()` from any thread - it's lock-free
2. **Tick**: Call `tick()` from main thread (CADisplayLink)
3. **Audio Processing**: `processPhotonicAudio()` is audio-thread safe
4. **Events**: Callbacks are dispatched to main thread automatically

## Performance Tips

1. Use CADisplayLink for 60Hz tick (not Timer)
2. Don't create/destroy bridge frequently - reuse single instance
3. For audio, prefer `processPhotonicAudio` over manual parameter modulation
4. Monitor Lambda score for load shedding (< 0.3 = system stressed)

## Debugging

```swift
// Get detailed stats
let stats = bridge.getStats()
print("Lambda Score: \(stats.lambdaScore)")
print("Tick Count: \(stats.tickCount)")
print("Avg Tick Time: \(stats.avgTickTimeMs)ms")
print("System Load: \(stats.systemLoad)")
print("Coherence Trend: \(stats.coherenceTrend)")
```

## Common Issues

### "Symbol not found" at runtime
- Ensure C++ standard library is linked
- Check that all EchoelCore headers are in search path

### High CPU usage
- Reduce tick rate if not using all features
- Check `systemLoad` in stats - should be < 0.5

### No bio modulation
- Verify bio data is being updated
- Check coherence value (needs > 0.3 for noticeable effect)

---

MIT License - Echoelmusic 2026
