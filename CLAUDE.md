# Echoelmusic - Claude Project Memory

> **Quantum Audio-Visual Music Production Platform**
> Bio-Reactive | AI-Powered | Cross-Platform | Real-Time Collaboration

---

## Project Identity

**Name:** Echoelmusic
**Type:** Professional Music Production Software
**Philosophy:** Chaos Computer Club Mind - Open, Decentralized, Hacker Ethics
**Target:** Musicians, Producers, VJs, Live Performers, Wellness Practitioners

---

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────┐
│                      ECHOELMUSIC CORE                           │
├─────────────────────────────────────────────────────────────────┤
│  ┌──────────┐  ┌──────────┐  ┌──────────┐  ┌──────────┐        │
│  │  Audio   │  │  Visual  │  │   Bio    │  │   AI     │        │
│  │  Engine  │  │  Engine  │  │  Engine  │  │  Engine  │        │
│  └────┬─────┘  └────┬─────┘  └────┬─────┘  └────┬─────┘        │
│       └─────────────┴─────────────┴─────────────┘              │
│                         │                                       │
│              ┌──────────┴──────────┐                           │
│              │  EchoelUniversalCore │                           │
│              │   (Central Brain)    │                           │
│              └──────────────────────┘                           │
├─────────────────────────────────────────────────────────────────┤
│  Platforms: iOS | macOS | visionOS | Linux | Windows | Android │
└─────────────────────────────────────────────────────────────────┘
```

---

## Key Systems

### 1. Audio Engine
- **Location:** `Sources/Echoelmusic/Audio/`
- **Key Files:**
  - `AudioEngine.swift` - Core audio processing
  - `DSP/RealTimeDSPEngine.swift` - Real-time DSP effects
  - `DSP/SIMDAudioProcessor.swift` - SIMD-optimized processing
- **Constraints:** Real-time safe, no allocation in audio thread
- **Sample Rates:** 44.1k, 48k, 96k, 192k
- **Buffer Sizes:** 64, 128, 256, 512, 1024, 2048

### 2. Visual Engine
- **Location:** `Sources/Echoelmusic/Visual/`
- **Key Files:**
  - `QuantumVisualEngine.swift` - Bio-reactive visuals
  - `UnifiedVisualSoundEngine.swift` - Audio-visual sync
  - `NeuralStyleTransfer.swift` - AI style transfer
- **Renderer:** Metal GPU
- **Target FPS:** 60-120

### 3. Bio Engine
- **Location:** `Sources/Echoelmusic/Biofeedback/`
- **Key Files:**
  - `HealthKitManager.swift` - Apple Health integration
  - `BioParameterMapper.swift` - Bio → Audio/Visual mapping
- **Data:** HRV, Heart Rate, Coherence, Breathing

### 4. AI Engine
- **Location:** `Sources/Echoelmusic/AI/`
- **Key Files:**
  - `AIComposer.swift` - Melody/rhythm generation
  - `MLClassifiers.swift` - Audio classification
  - `EnhancedMLModels.swift` - Pattern recognition
- **Framework:** Core ML, Create ML

### 5. Cloud & Collaboration
- **Location:** `Sources/Echoelmusic/Cloud/`, `Collaboration/`
- **Key Files:**
  - `CRDTSyncEngine.swift` - Conflict-free sync
  - `WebRTCCollaborationEngine.swift` - Real-time collab
- **Protocol:** CRDT (ORSet, LWW-Register)

### 6. Self-Healing System
- **Location:** `Sources/Echoelmusic/Core/`
- **Key Files:**
  - `SelfHealingEngine.swift` - Auto-recovery
  - `QuantumSelfHealingEngine.swift` - Platform adaptation
  - `UniversalOptimizationEngine.swift` - Performance optimization

---

## Code Statistics

```
Total Files:     320+
Total Lines:     130,738
Swift Files:     229
Commands:        24+
Languages:       Swift, Metal, GLSL, C++
```

---

## Critical Patterns

### Real-Time Audio Rules
```swift
// ✅ DO: Pre-allocate buffers
let bufferPool = LockFreeBufferPool<Float>(bufferSize: 4096, poolSize: 8)

// ❌ DON'T: Allocate in audio callback
func processAudio() {
    var buffer = [Float](repeating: 0, count: 1024) // BAD!
}
```

### CRDT Usage
```swift
// Use FixedORSet for collaborative data
var tracks = FixedORSet<Track>(nodeID: deviceID)
tracks.add(newTrack)
tracks.merge(with: remoteState) // Automatic conflict resolution
```

### SwiftUI Performance
```swift
// Use .equatable() for expensive views
struct WaveformView: View, Equatable {
    let samples: [Float]
    static func == (lhs: Self, rhs: Self) -> Bool {
        lhs.samples == rhs.samples
    }
}
```

---

## File Naming Conventions

| Type | Pattern | Example |
|------|---------|---------|
| View | `*View.swift` | `MixerView.swift` |
| Engine | `*Engine.swift` | `AudioEngine.swift` |
| Manager | `*Manager.swift` | `HealthKitManager.swift` |
| Processor | `*Processor.swift` | `SIMDAudioProcessor.swift` |
| Node | `*Node.swift` | `ReverbNode.swift` |

---

## Dependencies

### Apple Frameworks
- AVFoundation (Audio)
- Metal (GPU)
- Core ML (AI)
- HealthKit (Bio)
- CloudKit (Sync)
- Combine (Reactive)

### Audio Specific
- vDSP (Accelerate)
- AudioToolbox
- CoreMIDI

---

## Environment

### Supported Platforms
- iOS 17.0+
- macOS 14.0+
- visionOS 1.0+
- Linux (via Swift)
- Windows (via Swift)
- Android (via Kotlin bridge)

### Build System
- Swift Package Manager
- Xcode 15+

---

## Testing

```bash
# Run all tests
swift test

# Run specific test
swift test --filter AudioEngineTests

# Performance tests
swift test --filter PerformanceTests
```

---

## Common Tasks

### Adding a New Effect
1. Create `Sources/Echoelmusic/Audio/Effects/NewEffect.swift`
2. Implement `AudioEffect` protocol
3. Register in `EffectsChainView.swift`
4. Add to node graph in `NodeGraph.swift`

### Adding a New Visualizer
1. Create `Sources/Echoelmusic/Visual/Visualizers/NewVisualizer.swift`
2. Implement `Visualizer` protocol
3. Add Metal shader if needed
4. Register in `AllVisualizers.swift`

### Adding a New CRDT Type
1. Extend `CRDTSyncEngine.swift`
2. Implement merge semantics
3. Add vector clock tracking
4. Test conflict resolution

---

## Known Issues & TODOs

### Critical - ALL COMPLETE
- [x] GPU compute for large FFTs (`GPUFFTComputeEngine.swift`)
- [x] WebRTC TURN server support (`WebRTCTURNManager.swift`)
- [x] Offline queue persistence (`OfflineQueueManager.swift`)

### High Priority - ALL COMPLETE
- [x] Lazy ML model loading (`LazyMLModelLoader.swift`)
- [x] SwiftUI .equatable() audit (19 implementations across 14 files)
- [x] Actor-based concurrency migration (throughout codebase)

### Medium Priority - ALL COMPLETE
- [x] Neural stem separation (`NeuralStemSeparator.swift`)
- [x] Multi-platform sync optimization (`CRDTSyncEngine.swift`)
- [x] Conflict resolution UI (`ConflictResolutionView.swift`)

### New Systems Added (Dec 2025)
- [x] Live Streaming Engine (RTMP to 6 platforms)
- [x] Ultra-Low Latency Collaboration (<50ms WebRTC)
- [x] Thermodynamic Evolution Engine (self-evolving)
- [x] Adaptive Runtime Optimizer (environment-aware)
- [x] Super Intelligent Harmonizer (AI voice leading)
- [x] Voice Character System (80+ types)
- [x] AI Sub-Agent System (swarm intelligence)
- [x] Physics Visual Engine (antigravity particles)
- [x] Plugin System (AU/VST3/AUv3 hosting)

### Quantum Flow Systems (Dec 2025 - Phase 2)
- [x] Universal Import/Export Engine (all audio/video/project formats)
- [x] Content Distribution Network (auto-post to 30+ platforms)
- [x] Quantum Flow State Engine (E_n = φ·π·e·E_{n-1}·(1-S) + δ_n)
- [x] Viral Distribution Engine (CCC-inspired marketing)
- [x] Zero-Friction Collaboration Protocol (seamless creative unity)

---

## Contact & Resources

- **Repository:** This repo
- **Documentation:** `/docs/` (coming soon)
- **Claude Commands:** `/.claude/commands/`
- **Optimization Report:** `/OPTIMIZATION_REPORT.md`

---

## Quick Reference

### Start Audio Engine
```swift
let engine = AudioEngine.shared
try await engine.start()
```

### Process Bio Data
```swift
EchoelUniversalCore.shared.receiveBioData(
    hrv: hrvValue,
    heartRate: bpm,
    coherence: coherenceLevel
)
```

### Enable Optimization
```swift
UniversalOptimizationEngine.shared.setOptimizationLevel(.universal)
```

### Use Claude Skills
```
/optimize-performance  - CPU/GPU/Memory optimization
/audio-engineer        - DSP and mastering
/debug-doctor          - Bug hunting
/quantum-science       - Quantum-inspired algorithms
```

---

## Supercharge Workflow System

### AI-Native Development Workflows
Inspired by [OneRedOak/claude-code-workflows](https://github.com/OneRedOak/claude-code-workflows)

### Available Slash Commands

#### Review Workflows
```
/review [path]           - AI-assisted code review
/design-review [path]    - Comprehensive design review with Playwright
/security-review [path]  - Vulnerability and secrets scan (OWASP Top 10)
/perf-audit [path]       - Performance audit (CPU, memory, render)
/a11y [path]            - Accessibility audit (WCAG AA+)
```

#### Development Workflows
```
/spec <spec-file>        - Specification to verified code
/fix <issue>             - Analyze and fix bugs
/refactor <path>         - Suggest refactoring patterns
```

#### Testing Workflows
```
/test [filter]           - Run tests with coverage
/gen-tests <path>        - Generate tests for code
```

#### Utility Commands
```
/inspire <component>     - Get design inspiration
/help [command]          - Show command help
```

### Design Review Integration
The Design Agent provides world-class design guidance:

```swift
// Run design review
let report = await DesignAgentEngine.shared.reviewDesign(myView)
print("Score: \(report.score)/100")

// Get inspiration
let inspirations = await DesignAgentEngine.shared.getInspiration(for: .visualization)
```

### Workflow Orchestrator
Execute multi-step verified workflows:

```swift
// Run code review workflow
let run = await WorkflowOrchestratorEngine.shared.executeWorkflow(
    type: .codeReview,
    context: WorkflowContext(targetPath: "./Sources"),
    triggeredBy: .slashCommand
)

// Generate report
let report = WorkflowOrchestratorEngine.shared.generateReport(for: run)
```

### Design Principles
Following world-class design standards (Stripe, Airbnb, Linear):

| Principle | Value |
|-----------|-------|
| Grid System | 8pt grid |
| Touch Target | 44pt minimum |
| Contrast | WCAG AA 4.5:1 |
| Typography | 3-4 weights max |
| Line Height | 1.4-1.6× |
| Animation | 0.2-0.3s standard |

### Verification-Driven Development
Every step requires verification (from Taskmaster philosophy):

1. **Parse Specification** → Design Document
2. **Generate Design** → Manual Review
3. **Break Down Tasks** → Task List
4. **Implement** → Type Check + Build Check
5. **Write Tests** → Unit + Integration Tests
6. **Verify** → Proof Verification

### Context Engineering
- Max complexity per step: 5 items
- Don't trust - verify every step
- Independent verification for each transformation
- Proofs over tests where possible

---

## Cross-Platform Wearables

### Supported Devices

| Platform | Devices | Data |
|----------|---------|------|
| Apple Watch | Series 6+ | HR, HRV, Activity |
| Vision Pro | visionOS 1.0+ | Hand tracking, Eye gaze |
| Smart Rings | Oura, Samsung, Ultrahuman | HRV, Sleep, Temperature |
| iPhone/iPad | iOS 17+ | Motion, Touch |
| Mac | macOS 14+ | Full audio/visual |
| Android | Via bridge | Basic bio data |
| Linux/Windows | Via Swift | Audio processing |

### Wearable Integration
```swift
// Smart Ring data
let ringData = await SmartRingManager.shared.getCurrentData()
let coherence = ringData.coherence // Calculated from HRV

// Apply to audio
EchoelUniversalCore.shared.receiveBioData(
    hrv: ringData.hrv,
    heartRate: ringData.heartRate,
    coherence: coherence
)
```

---

## System Components (Dec 2025 - Phase 3)

### Workflow System
- [x] Design Agent Engine (`DesignAgentEngine.swift`)
- [x] Workflow Orchestrator (`WorkflowOrchestratorEngine.swift`)
- [x] Slash Command Engine (`SlashCommandEngine.swift`)

### Taskmaster System
- [x] Taskmaster Engine (`TaskmasterEngine.swift`)
- [x] MCP Context Engine (`MCPContextEngine.swift`)

### Design System
- [x] Liquid Glass Design System (`LiquidGlassDesignSystem.swift`)
- [x] Liquid Glass Components (`LiquidGlassComponents.swift`)
- [x] WWDC 2025 Components (`WWDC2025Components.swift`)

### Platform Extensions
- [x] Smart Ring Integration (`SmartRingIntegration.swift`)
- [x] visionOS 26 Spatial Engine (`VisionOS26SpatialEngine.swift`)
- [x] Foundation Models Engine (`FoundationModelsEngine.swift`)

---

*Last Updated: 2025-12-05*
*Optimized by: Universal Deep Space Analysis + Supercharge Workflow*
