# GitHub Issues - Phase 3+ Remaining Work

**Project:** Echoelmusic Modular Architecture
**Generated:** 2025-11-14
**Branch:** `claude/echoelmusic-phase3-migrate-01DsLLpgYQKonYVPjn2E9EJW`

---

## Priority Definitions

- **P1 (Critical):** Blockers for basic functionality, must complete before merge
- **P2 (High):** Important for production readiness, complete within 1-2 sprints
- **P3 (Medium):** Nice-to-have improvements, can be deferred

---

## P1: Critical Issues (Must Complete Before Merge)

### 🔴 P1-001: Update Test Suite Imports
**Priority:** P1 (Critical)
**Estimate:** 2 hours
**Module:** All (Tests/)

**Description:**
Update all test files to import specific modules instead of monolithic `@testable import Echoelmusic`.

**Tasks:**
- [ ] Update `Tests/EchoelmusicTests/` to import specific modules
- [ ] Update test fixtures to use new module structure
- [ ] Verify all tests pass after import changes
- [ ] Update test documentation

**Acceptance Criteria:**
- All test files use `@testable import Echoelmusic[Module]` instead of `@testable import Echoelmusic`
- `swift test` passes without errors
- No deprecated imports remain

**Files to Update:**
```
Tests/EchoelmusicTests/*.swift
```

---

### 🔴 P1-002: Fix Remaining Import References
**Priority:** P1 (Critical)
**Estimate:** 1 hour
**Module:** All

**Description:**
Search and replace any remaining references to monolithic imports in production code.

**Tasks:**
- [ ] Search for `import Echoelmusic` in Sources/Echoelmusic*/
- [ ] Replace with appropriate module imports
- [ ] Verify no compile errors
- [ ] Run static analysis

**Acceptance Criteria:**
- Zero instances of bare `import Echoelmusic` in migrated modules
- Project builds successfully
- No circular dependency warnings

---

### 🔴 P1-003: Implement AudioEngine Core Features
**Priority:** P1 (Critical)
**Estimate:** 8 hours
**Module:** EchoelmusicAudio

**Description:**
Implement missing AudioEngine functionality for start/stop/record/play operations with thread-safe buffer management.

**Tasks:**
- [ ] Implement `start()` method with AVAudioEngine initialization
- [ ] Implement `stop()` method with cleanup
- [ ] Add `record()` method with buffer recording
- [ ] Add `play(url:)` method for WAV playback
- [ ] Implement thread-safe audio buffer queue
- [ ] Add error handling for audio session failures
- [ ] Create minimal UI controls in ContentView
- [ ] Add unit tests for core operations

**Technical Requirements:**
- Thread-safe buffer access (use locks or actors)
- Proper AVAudioEngine lifecycle management
- Support for 44.1kHz/48kHz sample rates
- WAV file format support (16/24-bit)
- Real-time safe operations (no allocations in audio thread)

**Acceptance Criteria:**
- Can start/stop audio engine without crashes
- Can record audio to buffer
- Can playback WAV files
- No audio glitches or dropouts
- All operations tested with unit tests

**Files to Modify:**
```
Sources/EchoelmusicAudio/Engine/AudioEngine.swift
Sources/EchoelmusicUI/Screens/ContentView.swift
Tests/EchoelmusicAudioTests/AudioEngineTests.swift (new)
```

---

### 🔴 P1-004: Implement UnifiedControlHub 60Hz Loop
**Priority:** P1 (Critical)
**Estimate:** 6 hours
**Module:** EchoelmusicControl

**Description:**
Implement the 60Hz control loop (16.67ms tick) with EventBus integration for unified input handling.

**Tasks:**
- [ ] Implement 60Hz Timer/CADisplayLink loop
- [ ] Wire to EventBus for event publishing
- [ ] Integrate gesture recognition
- [ ] Integrate face tracking
- [ ] Integrate bio signal processing
- [ ] Integrate MIDI input
- [ ] Add performance monitoring (measure actual tick rate)
- [ ] Add graceful degradation if frame drops
- [ ] Add unit tests with mock input providers

**Technical Requirements:**
- Target: 60Hz (16.67ms ±1ms)
- Use CADisplayLink on iOS for display sync
- Publish events to EventBus.shared
- Handle missed frames gracefully
- Monitor CPU usage (keep under 5% on iPhone 12+)

**Performance Targets:**
- 60Hz ± 2 frames/sec (58-62 Hz acceptable)
- < 5% CPU usage average
- < 10ms worst-case latency

**Acceptance Criteria:**
- Control loop runs at stable 60Hz
- EventBus receives input events
- All input modalities integrated
- Performance metrics logged
- Unit tests verify timing accuracy

**Files to Modify:**
```
Sources/EchoelmusicControl/Hub/UnifiedControlHub.swift
Tests/EchoelmusicControlTests/UnifiedControlHubTests.swift (new)
```

---

### 🔴 P1-005: Implement SessionModel Save/Load
**Priority:** P1 (Critical)
**Estimate:** 4 hours
**Module:** EchoelmusicCore

**Description:**
Ensure Session/Track types have complete save/load functionality with roundtrip tests.

**Tasks:**
- [ ] Verify Codable conformance for all types
- [ ] Implement error handling for file I/O
- [ ] Add validation for loaded data
- [ ] Create roundtrip tests (save → load → compare)
- [ ] Test with bio data, tracks, metadata
- [ ] Test with nested objects (tracks with effects)
- [ ] Add migration support for future schema changes

**Test Scenarios:**
- Empty session
- Session with 1 track
- Session with 10 tracks
- Session with bio data (1000+ points)
- Session with waveform data
- Corrupted JSON handling

**Acceptance Criteria:**
- Can save session to disk
- Can load session from disk
- Roundtrip preserves all data (deep equality)
- Error handling for corrupted files
- All tests pass

**Files to Verify:**
```
Sources/EchoelmusicCore/Types/Session.swift
Sources/EchoelmusicCore/Types/Track.swift
Tests/EchoelmusicCoreTests/SessionTests.swift (new)
```

---

### 🔴 P1-006: Update Package.swift Dependencies
**Priority:** P1 (Critical)
**Estimate:** 1 hour
**Module:** Root

**Description:**
Ensure Package.swift correctly declares all module dependencies and builds successfully.

**Tasks:**
- [ ] Verify all 9 modules listed as products
- [ ] Verify dependency chain: Core → Audio/Bio/Visual/MIDI → Control → UI
- [ ] Remove any circular dependencies
- [ ] Test build with `swift build`
- [ ] Test on both iOS and macOS (if applicable)

**Acceptance Criteria:**
- `swift build` succeeds
- `swift package show-dependencies` shows correct tree
- No circular dependency warnings
- All modules accessible to tests

**Files to Modify:**
```
Package.swift
```

---

## P2: High Priority Issues (Complete Within 1-2 Sprints)

### 🟡 P2-001: Add Comprehensive Unit Tests
**Priority:** P2 (High)
**Estimate:** 16 hours
**Module:** All

**Description:**
Achieve 60%+ test coverage across all modules.

**Tasks:**
- [ ] EchoelmusicCore: EventBus, StateGraph, Session, Track tests
- [ ] EchoelmusicAudio: AudioEngine, effects nodes, routing tests
- [ ] EchoelmusicBio: HealthKit mocks, bio parameter mapping tests
- [ ] EchoelmusicVisual: Visualization mode tests
- [ ] EchoelmusicMIDI: MIDI 2.0 parsing, MPE zone allocation tests
- [ ] EchoelmusicControl: Gesture recognition, conflict resolution tests
- [ ] EchoelmusicHardware: LED controller mocks
- [ ] EchoelmusicPlatform: Permission manager tests
- [ ] EchoelmusicUI: SwiftUI view tests (with ViewInspector)

**Target Coverage:**
- Core: 80%+ (critical foundation)
- Audio: 70%+
- Others: 50%+
- Overall: 60%+

**Estimate Breakdown:**
- Core: 3 hours
- Audio: 5 hours
- Bio: 2 hours
- Visual: 2 hours
- MIDI: 2 hours
- Control: 2 hours
- UI: 0 hours (deferred UI testing)

---

### 🟡 P2-002: Performance Profiling & Optimization
**Priority:** P2 (High)
**Estimate:** 8 hours
**Module:** All (especially Audio, Control)

**Description:**
Profile and optimize performance-critical paths.

**Tasks:**
- [ ] Profile AudioEngine audio thread (Instruments: Time Profiler)
- [ ] Profile UnifiedControlHub 60Hz loop (Instruments: Time Profiler)
- [ ] Identify allocations in audio thread (Instruments: Allocations)
- [ ] Optimize hot paths (< 1ms per audio buffer)
- [ ] Reduce EventBus overhead
- [ ] Test on iPhone SE (low-end device)

**Performance Targets:**
- Audio thread: < 1ms per buffer callback (at 256 samples, 44.1kHz)
- Control loop: < 10ms per 60Hz tick
- UI responsiveness: 60fps animations
- Memory: < 100MB baseline usage

**Acceptance Criteria:**
- No dropped audio frames under normal load
- 60Hz control loop maintains ±2 frames/sec
- UI remains responsive during recording
- Memory usage stable over 1-hour session

---

### 🟡 P2-003: Implement NodeGraph → RoutingGraph Merge
**Priority:** P2 (High)
**Estimate:** 4 hours
**Module:** EchoelmusicAudio

**Description:**
Merge existing NodeGraph with new RoutingGraph implementation to avoid duplication.

**Tasks:**
- [ ] Review NodeGraph vs RoutingGraph APIs
- [ ] Identify overlapping functionality
- [ ] Merge into single RoutingGraph implementation
- [ ] Update AudioEngine to use merged implementation
- [ ] Update UI views (EffectsChainView) to use merged API
- [ ] Add migration guide for API changes

**Decision Points:**
- Keep NodeGraph name or RoutingGraph?
- Use Protocol-oriented or Class-based design?
- Support both async and sync APIs?

**Acceptance Criteria:**
- Single audio routing implementation
- All tests pass
- No breaking changes to public API (or deprecation warnings)

---

### 🟡 P2-004: Implement PermissionsManager Integration Tests
**Priority:** P2 (High)
**Estimate:** 3 hours
**Module:** EchoelmusicPlatform

**Description:**
Create integration tests for PermissionsManager with mocked system APIs.

**Tasks:**
- [ ] Mock AVCaptureDevice for camera/microphone
- [ ] Mock HKHealthStore for HealthKit
- [ ] Mock CMMotionManager for motion
- [ ] Test request flows (granted, denied, not determined)
- [ ] Test permission status checks
- [ ] Test bulk permission requests

**Test Scenarios:**
- All permissions granted
- All permissions denied
- Mixed permissions
- Permission status changes
- Request timeout handling

**Acceptance Criteria:**
- 80%+ test coverage for PermissionsManager
- All permission types tested
- Edge cases handled (timeouts, system errors)

---

### 🟡 P2-005: Add Module READMEs Example Code Verification
**Priority:** P2 (High)
**Estimate:** 2 hours
**Module:** All

**Description:**
Verify all example code in module READMEs compiles and runs correctly.

**Tasks:**
- [ ] Extract code snippets from all 9 READMEs
- [ ] Create test files that run each example
- [ ] Fix any compilation errors
- [ ] Update README examples if needed
- [ ] Add CI job to verify examples

**Files:**
```
Sources/EchoelmusicCore/README.md
Sources/EchoelmusicAudio/README.md
Sources/EchoelmusicBio/README.md
Sources/EchoelmusicVisual/README.md
Sources/EchoelmusicMIDI/README.md
Sources/EchoelmusicControl/README.md
Sources/EchoelmusicHardware/README.md
Sources/EchoelmusicPlatform/README.md
Sources/EchoelmusicUI/README.md
```

---

### 🟡 P2-006: Create Architecture Documentation
**Priority:** P2 (High)
**Estimate:** 4 hours
**Module:** Docs

**Description:**
Create comprehensive architecture documentation for onboarding and reference.

**Tasks:**
- [ ] Create ARCHITECTURE.md with module diagram
- [ ] Document dependency flow
- [ ] Document EventBus usage patterns
- [ ] Document StateGraph state machine patterns
- [ ] Create API reference for each module
- [ ] Add sequence diagrams for key flows (recording, playback, gesture→audio)

**Deliverables:**
- `ARCHITECTURE.md` (overview, dependencies, patterns)
- `docs/modules/` (per-module deep dives)
- `docs/flows/` (sequence diagrams)

---

## P3: Medium Priority Issues (Can Be Deferred)

### 🟢 P3-001: Implement Neural Audio Hooks (CoreML)
**Priority:** P3 (Medium)
**Estimate:** 20 hours
**Module:** EchoelmusicAudio

**Description:**
Implement neural audio processing with CoreML models (emotion detection, voice analysis, adaptive EQ).

**Status:** Placeholder implemented in Phase 2, requires actual CoreML integration.

**Tasks:**
- [ ] Create/train emotion detection model
- [ ] Create/train voice analysis model
- [ ] Create/train adaptive EQ model
- [ ] Integrate CoreML inference into audio pipeline
- [ ] Add real-time inference support (< 10ms latency)
- [ ] Add fallback for devices without Neural Engine

**Deferred Reason:** Not critical for basic functionality, requires model training.

---

### 🟢 P3-002: Implement XR/visionOS Support
**Priority:** P3 (Medium)
**Estimate:** 30 hours
**Module:** EchoelmusicVisual

**Description:**
Implement full visionOS/RealityKit integration for XR visualization modes.

**Status:** Placeholder implemented in Phase 2 (XRBridge).

**Tasks:**
- [ ] Create RealityKit scenes for each visualization mode
- [ ] Implement hand tracking integration
- [ ] Implement eye tracking integration
- [ ] Add spatial audio for visionOS
- [ ] Test on Apple Vision Pro simulator

**Deferred Reason:** Requires visionOS device/simulator, not critical for iOS.

---

### 🟢 P3-003: Implement Voice Command Engine
**Priority:** P3 (Medium)
**Estimate:** 16 hours
**Module:** EchoelmusicControl

**Description:**
Implement full voice command recognition with Speech framework.

**Status:** Placeholder implemented in Phase 2 (VoiceCommandEngine).

**Tasks:**
- [ ] Integrate Speech framework
- [ ] Define command vocabulary (start, stop, record, etc.)
- [ ] Implement command parsing
- [ ] Add command confirmation UI
- [ ] Test in noisy environments

**Deferred Reason:** Nice-to-have feature, not critical for basic functionality.

---

### 🟢 P3-004: Implement Wearable Device Integration
**Priority:** P3 (Medium)
**Estimate:** 24 hours
**Module:** EchoelmusicHardware

**Description:**
Implement full wearable device support (Apple Watch, smart rings, EEG headsets).

**Status:** Placeholder implemented in Phase 2 (WearableManager).

**Tasks:**
- [ ] Implement Apple Watch connectivity
- [ ] Implement BLE device discovery
- [ ] Create device adapters for common wearables
- [ ] Add battery monitoring
- [ ] Create pairing UI

**Deferred Reason:** Requires physical hardware, not critical for basic functionality.

---

### 🟢 P3-005: Implement Advanced Spatial Audio Modes
**Priority:** P3 (Medium)
**Estimate:** 12 hours
**Module:** EchoelmusicAudio

**Description:**
Implement advanced spatial audio modes (4D AFA field, custom geometry).

**Status:** Basic spatial audio implemented, advanced modes need work.

**Tasks:**
- [ ] Implement 4D Azimuth-Frequency-Amplitude field
- [ ] Add custom geometry editor
- [ ] Implement spatial source migration
- [ ] Add spatial audio presets
- [ ] Optimize for low latency

**Deferred Reason:** Advanced feature, basic spatial audio sufficient for MVP.

---

### 🟢 P3-006: Add Comprehensive Logging & Analytics
**Priority:** P3 (Medium)
**Estimate:** 8 hours
**Module:** All

**Description:**
Implement structured logging and optional analytics across all modules.

**Tasks:**
- [ ] Integrate OSLog for structured logging
- [ ] Add log levels (debug, info, warning, error)
- [ ] Add performance metrics logging
- [ ] Create logging dashboard (optional)
- [ ] Add opt-in analytics (privacy-respecting)

**Deferred Reason:** Nice-to-have for debugging, not critical for basic functionality.

---

### 🟢 P3-007: Implement Session Templates & Presets
**Priority:** P3 (Medium)
**Estimate:** 6 hours
**Module:** EchoelmusicCore, EchoelmusicUI

**Description:**
Expand session template system with more presets and user-created templates.

**Status:** Basic templates exist (meditation, healing, creative).

**Tasks:**
- [ ] Add 10+ preset templates
- [ ] Implement user-created template saving
- [ ] Add template browser UI
- [ ] Add template sharing (export/import)
- [ ] Add template categories/tags

**Deferred Reason:** Enhancement to existing functionality, not critical.

---

### 🟢 P3-008: Improve Error Handling & Recovery
**Priority:** P3 (Medium)
**Estimate:** 8 hours
**Module:** All

**Description:**
Implement comprehensive error handling and recovery strategies.

**Tasks:**
- [ ] Define standard error types per module
- [ ] Implement error recovery strategies
- [ ] Add user-facing error messages
- [ ] Add error reporting (crash logs)
- [ ] Test error scenarios (network failures, permission denials, etc.)

**Deferred Reason:** Basic error handling exists, comprehensive coverage not critical for MVP.

---

## Summary Statistics

### Issue Breakdown
- **P1 (Critical):** 6 issues, ~22 hours
- **P2 (High):** 6 issues, ~37 hours
- **P3 (Medium):** 8 issues, ~124 hours

### Total Effort Estimate
- **P1:** 22 hours (3 days)
- **P2:** 37 hours (5 days)
- **P3:** 124 hours (16 days)
- **Total:** 183 hours (24 days)

### Recommended Sprint Plan

**Sprint 1 (P1 - Must Complete Before Merge):** 3 days
- Complete all P1 issues
- Verify builds and tests pass
- Ready for PR review

**Sprint 2-3 (P2 - Production Readiness):** 5 days
- Complete all P2 issues
- Achieve 60%+ test coverage
- Performance profiling complete

**Future Sprints (P3 - Enhancements):** 16 days
- Implement advanced features
- Neural audio, XR, voice commands, wearables

---

## How to Create Issues

```bash
# Copy this file to create GitHub issues
cat GITHUB_ISSUES.md

# Or use GitHub CLI
gh issue create --title "P1-001: Update Test Suite Imports" \
                --body "$(sed -n '/P1-001/,/^---$/p' GITHUB_ISSUES.md)" \
                --label "P1,tests"
```

---

**Generated:** 2025-11-14
**Engineer:** Claude (Sonnet 4.5)
**Branch:** `claude/echoelmusic-phase3-migrate-01DsLLpgYQKonYVPjn2E9EJW`
