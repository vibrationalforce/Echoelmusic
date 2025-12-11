# TODO Issues Tracker

> **Generated:** 2025-12-11 | **Total TODOs:** 27
> **Status:** Tracked for conversion to GitHub Issues

---

## Summary by Module

| Module | TODOs | Priority | Status |
|--------|-------|----------|--------|
| Remote/RemoteProcessingEngine.cpp | 15 | High | ⏳ Open |
| BioData/HRVProcessor.h | 3 | Medium | ⏳ Open |
| Audio/AudioExporter.cpp | 1 | Medium | ⏳ Open |
| UI/*.h | 3 | Low | ⏳ Open |
| Cloud/CloudSyncManager.swift | 1 | Medium | ⏳ Open |
| Platforms/*.swift | 2 | Low | ⏳ Open |
| AI/AIComposer.swift | 2 | Medium | ⏳ Open |
| Video/ChromaKeyEngine.swift | 2 | Low | ⏳ Open |

---

## Remote Processing Engine (15 TODOs)

### REMOTE-001: Implement Ableton Link SDK Integration
- **File:** `Sources/Remote/RemoteProcessingEngine.cpp:26`
- **Priority:** 🔴 High
- **Category:** Feature
- **Description:** Implement actual Ableton Link SDK integration for tempo/beat sync
- **Current State:** Dummy implementation returning 120 BPM
- **Requirements:**
  - Download Link SDK from https://github.com/Ableton/link
  - Implement `LinkImpl::getState()` with actual SDK calls
  - Enable tempo sync across devices
- **Acceptance Criteria:**
  - [ ] Link SDK integrated
  - [ ] Tempo sync working with other Link-enabled apps
  - [ ] Beat position accurate within 1ms

---

### REMOTE-002: Implement mDNS/Bonjour Server Discovery
- **File:** `Sources/Remote/RemoteProcessingEngine.cpp:143`
- **Priority:** 🔴 High
- **Category:** Feature
- **Description:** Implement automatic server discovery using mDNS/Bonjour
- **Current State:** Returns dummy server data
- **Requirements:**
  - macOS: Use `NSNetServiceBrowser`
  - Windows: Use DNS-SD API
  - Linux: Use Avahi
  - Service type: `_echoelmusic._tcp.local`
- **Acceptance Criteria:**
  - [ ] Auto-discover servers on local network
  - [ ] Display server capabilities
  - [ ] Handle server appear/disappear events

---

### REMOTE-003: Implement Auto-Reconnect Logic
- **File:** `Sources/Remote/RemoteProcessingEngine.cpp:238`
- **Priority:** 🟡 Medium
- **Category:** Resilience
- **Description:** Implement automatic reconnection when connection is lost
- **Current State:** No auto-reconnect
- **Requirements:**
  - Monitor connection health
  - Detect disconnection within 1 second
  - Exponential backoff for reconnection attempts
  - Max 5 reconnection attempts
- **Acceptance Criteria:**
  - [ ] Detect connection loss
  - [ ] Auto-reconnect with backoff
  - [ ] Notify UI of connection status

---

### REMOTE-004: Enable/Disable Ableton Link
- **File:** `Sources/Remote/RemoteProcessingEngine.cpp:469`
- **Priority:** 🟡 Medium
- **Category:** Feature
- **Description:** Implement Link enable/disable functionality
- **Current State:** Flag set but SDK call commented out
- **Depends On:** REMOTE-001
- **Acceptance Criteria:**
  - [ ] Toggle Link on/off
  - [ ] Persist preference
  - [ ] Update UI state

---

### REMOTE-005: Measure Actual Network Bandwidth
- **File:** `Sources/Remote/RemoteProcessingEngine.cpp:518`
- **Priority:** 🟢 Low
- **Category:** Monitoring
- **Description:** Implement actual bandwidth measurement instead of hardcoded 10 Mbps
- **Current State:** Returns hardcoded `10.0f`
- **Requirements:**
  - Send test packets to measure throughput
  - Calculate bandwidth over 1-second window
  - Update quality score based on bandwidth
- **Acceptance Criteria:**
  - [ ] Accurate bandwidth measurement
  - [ ] Updates every 5 seconds
  - [ ] Triggers quality adjustment

---

### REMOTE-006: Update Codec Parameters Based on Preset
- **File:** `Sources/Remote/RemoteProcessingEngine.cpp:561`
- **Priority:** 🟡 Medium
- **Category:** Feature
- **Description:** Configure Opus codec parameters based on quality preset
- **Current State:** Preset selected but codec not configured
- **Requirements:**
  - UltraLow: 16-bit, 24kHz, bitrate 32kbps
  - Low: 16-bit, 44.1kHz, bitrate 64kbps
  - Medium: 24-bit, 48kHz, bitrate 128kbps
  - High: 32-bit, 96kHz, bitrate 256kbps
  - Studio: 32-bit, 192kHz, bitrate 512kbps
- **Acceptance Criteria:**
  - [ ] Codec parameters match preset
  - [ ] Smooth transition between presets
  - [ ] No audio glitches on change

---

### REMOTE-007: Implement AES-256-GCM Encryption
- **File:** `Sources/Remote/RemoteProcessingEngine.cpp:597`
- **Priority:** 🔴 High
- **Category:** Security
- **Description:** Implement AES-256-GCM encryption for audio data
- **Current State:** No encryption
- **Requirements:**
  - Use AES-256-GCM for audio packets
  - Store key in Keychain (macOS/iOS) or Credential Manager (Windows)
  - Key rotation support
- **Acceptance Criteria:**
  - [ ] All audio data encrypted
  - [ ] Key stored securely
  - [ ] No performance impact >1ms

---

### REMOTE-008: Configure SSL/TLS Certificate Verification
- **File:** `Sources/Remote/RemoteProcessingEngine.cpp:610`
- **Priority:** 🔴 High
- **Category:** Security
- **Description:** Implement SSL/TLS certificate verification for secure connections
- **Current State:** No certificate verification
- **Requirements:**
  - Verify server certificate
  - Support custom CA certificates
  - Reject self-signed by default (configurable)
- **Acceptance Criteria:**
  - [ ] Certificate verification working
  - [ ] Invalid certs rejected
  - [ ] Custom CA support

---

### REMOTE-009: Start WebRTC Signaling Server
- **File:** `Sources/Remote/RemoteProcessingEngine.cpp:622`
- **Priority:** 🔴 High
- **Category:** Feature
- **Description:** Implement WebRTC signaling server for server mode
- **Current State:** Flag set but no actual server
- **Requirements:**
  - WebSocket-based signaling
  - SDP offer/answer exchange
  - ICE candidate exchange
  - Client authentication
- **Acceptance Criteria:**
  - [ ] Server accepts connections
  - [ ] WebRTC handshake completes
  - [ ] Audio streaming works

---

### REMOTE-010: Close All Client Connections
- **File:** `Sources/Remote/RemoteProcessingEngine.cpp:637`
- **Priority:** 🟡 Medium
- **Category:** Feature
- **Description:** Implement graceful shutdown of all client connections
- **Current State:** Flag cleared but connections not closed
- **Depends On:** REMOTE-009
- **Acceptance Criteria:**
  - [ ] All clients notified before disconnect
  - [ ] Connections closed gracefully
  - [ ] Resources freed

---

### REMOTE-011: Store Allowed JWT Tokens
- **File:** `Sources/Remote/RemoteProcessingEngine.cpp:650`
- **Priority:** 🟡 Medium
- **Category:** Security
- **Description:** Implement JWT token storage and verification for client authentication
- **Current State:** No token storage
- **Requirements:**
  - Store allowed tokens securely
  - Verify on connection
  - Support token revocation
- **Acceptance Criteria:**
  - [ ] Tokens stored securely
  - [ ] Invalid tokens rejected
  - [ ] Token revocation works

---

### REMOTE-012: Send START_RECORDING Command
- **File:** `Sources/Remote/RemoteProcessingEngine.cpp:669`
- **Priority:** 🟡 Medium
- **Category:** Feature
- **Description:** Implement remote recording start command
- **Current State:** Returns true but no command sent
- **Requirements:**
  - Send command over control channel
  - Server creates file
  - Start streaming audio for recording
- **Acceptance Criteria:**
  - [ ] Command sent reliably
  - [ ] Server confirms start
  - [ ] Recording begins within 100ms

---

### REMOTE-013: Send STOP_RECORDING Command
- **File:** `Sources/Remote/RemoteProcessingEngine.cpp:680`
- **Priority:** 🟡 Medium
- **Category:** Feature
- **Description:** Implement remote recording stop command
- **Current State:** Logs but no command sent
- **Depends On:** REMOTE-012
- **Acceptance Criteria:**
  - [ ] Command sent reliably
  - [ ] Server finalizes file
  - [ ] File integrity verified

---

### REMOTE-014: Check Recording State
- **File:** `Sources/Remote/RemoteProcessingEngine.cpp:686`
- **Priority:** 🟢 Low
- **Category:** Feature
- **Description:** Query server for current recording state
- **Current State:** Returns false always
- **Depends On:** REMOTE-012
- **Acceptance Criteria:**
  - [ ] Accurate state returned
  - [ ] Updates within 100ms of change

---

### REMOTE-015: Query Recording Position
- **File:** `Sources/Remote/RemoteProcessingEngine.cpp:692`
- **Priority:** 🟢 Low
- **Category:** Feature
- **Description:** Query server for current recording position
- **Current State:** Returns 0 always
- **Depends On:** REMOTE-012
- **Acceptance Criteria:**
  - [ ] Position accurate to 10ms
  - [ ] Updates at 10Hz minimum

---

## BioData Module (3 TODOs)

### BIO-001: Initialize Bluetooth HR Monitor
- **File:** `Sources/BioData/HRVProcessor.h:364`
- **Priority:** 🟡 Medium
- **Category:** Feature
- **Description:** Implement Bluetooth heart rate monitor initialization
- **Requirements:**
  - Scan for BLE HR monitors
  - Connect and subscribe to HR characteristic
  - Parse HR data packets
- **Acceptance Criteria:**
  - [ ] Discover BLE HR monitors
  - [ ] Connect and receive data
  - [ ] Handle disconnection

---

### BIO-002: Initialize HealthKit
- **File:** `Sources/BioData/HRVProcessor.h:368`
- **Priority:** 🟡 Medium
- **Category:** Feature (iOS/watchOS)
- **Description:** Implement HealthKit integration for Apple Watch
- **Requirements:**
  - Request HealthKit authorization
  - Query HR and HRV samples
  - Stream real-time updates
- **Acceptance Criteria:**
  - [ ] Authorization flow complete
  - [ ] Real-time HR updates
  - [ ] HRV data available

---

### BIO-003: Start WebSocket Server for Bio Data
- **File:** `Sources/BioData/HRVProcessor.h:372`
- **Priority:** 🟢 Low
- **Category:** Feature
- **Description:** Implement WebSocket server for external bio data sources
- **Requirements:**
  - WebSocket server on configurable port
  - JSON protocol for bio data
  - Support multiple clients
- **Acceptance Criteria:**
  - [ ] Server accepts connections
  - [ ] Bio data streamed to all clients
  - [ ] Handles reconnection

---

## Audio Module (1 TODO)

### AUDIO-001: Implement Background Thread Export
- **File:** `Sources/Audio/AudioExporter.cpp:304`
- **Priority:** 🟡 Medium
- **Category:** Performance
- **Description:** Implement proper background thread for audio export
- **Requirements:**
  - Export on background thread
  - Progress callbacks
  - Cancellation support
- **Acceptance Criteria:**
  - [ ] Export doesn't block UI
  - [ ] Progress updates at 1Hz
  - [ ] Cancellation works

---

## UI Module (3 TODOs)

### UI-001: Actually Import Files
- **File:** `Sources/UI/ImportDialog.h:247`
- **Priority:** 🟡 Medium
- **Category:** Feature
- **Description:** Implement actual file import into project
- **Acceptance Criteria:**
  - [ ] Files copied to project
  - [ ] Metadata extracted
  - [ ] Appears in project browser

---

### UI-002: Connect Export to Audio Engine
- **File:** `Sources/UI/ExportDialog.h:283`
- **Priority:** 🟡 Medium
- **Category:** Feature
- **Description:** Connect export dialog to actual audio engine
- **Acceptance Criteria:**
  - [ ] Export renders audio
  - [ ] All formats supported
  - [ ] Progress shown

---

### UI-003: Apply Modulated Params
- **File:** `Sources/UI/SimpleMainUI.h:233`
- **Priority:** 🟢 Low
- **Category:** Feature (Phase 2)
- **Description:** Apply modulated parameters to audio processing
- **Note:** Marked for Phase 2 implementation

---

## Swift Modules (5 TODOs)

### CLOUD-001: Auto-Backup Session
- **File:** `Sources/Echoelmusic/Cloud/CloudSyncManager.swift:114`
- **Priority:** 🟡 Medium
- **Category:** Feature
- **Description:** Implement automatic session backup to cloud
- **Acceptance Criteria:**
  - [ ] Auto-backup on session save
  - [ ] Conflict resolution
  - [ ] Restore from backup

---

### PLATFORM-001: tvOS GroupActivities
- **File:** `Sources/Echoelmusic/Platforms/tvOS/TVApp.swift:268`
- **Priority:** 🟢 Low
- **Category:** Feature (tvOS)
- **Description:** Integrate with GroupActivities framework for SharePlay
- **Acceptance Criteria:**
  - [ ] SharePlay session works
  - [ ] Audio synced across devices

---

### PLATFORM-002: watchOS WatchConnectivity
- **File:** `Sources/Echoelmusic/Platforms/watchOS/WatchApp.swift:249`
- **Priority:** 🟢 Low
- **Category:** Feature (watchOS)
- **Description:** Sync with iPhone via WatchConnectivity
- **Acceptance Criteria:**
  - [ ] Watch syncs with iPhone
  - [ ] Bio data transfers

---

### AI-001: Load CoreML Models
- **File:** `Sources/Echoelmusic/AI/AIComposer.swift:21`
- **Priority:** 🟡 Medium
- **Category:** Feature
- **Description:** Load CoreML models for AI composition
- **Acceptance Criteria:**
  - [ ] Models loaded at startup
  - [ ] Fallback if models missing

---

### AI-002: LSTM Melody Generation
- **File:** `Sources/Echoelmusic/AI/AIComposer.swift:31`
- **Priority:** 🟡 Medium
- **Category:** Feature
- **Description:** Implement LSTM-based melody generation
- **Depends On:** AI-001
- **Acceptance Criteria:**
  - [ ] Generate melodies from input
  - [ ] Style transfer support

---

### VIDEO-001: Split Screen Composite
- **File:** `Sources/Echoelmusic/Video/ChromaKeyEngine.swift:428`
- **Priority:** 🟢 Low
- **Category:** Feature
- **Description:** Implement split screen composite mode
- **Acceptance Criteria:**
  - [ ] 2-4 way split supported
  - [ ] Smooth transitions

---

### VIDEO-002: Edge Quality Overlay
- **File:** `Sources/Echoelmusic/Video/ChromaKeyEngine.swift:431`
- **Priority:** 🟢 Low
- **Category:** Feature
- **Description:** Implement edge quality visualization overlay
- **Acceptance Criteria:**
  - [ ] Shows edge quality
  - [ ] Helps with chroma key tuning

---

## Priority Summary

### 🔴 High Priority (7 issues)
- REMOTE-001: Ableton Link SDK
- REMOTE-002: mDNS Discovery
- REMOTE-007: AES Encryption
- REMOTE-008: SSL/TLS Verification
- REMOTE-009: WebRTC Server

### 🟡 Medium Priority (13 issues)
- REMOTE-003, 004, 006, 010, 011, 012, 013
- BIO-001, 002
- AUDIO-001
- UI-001, 002
- CLOUD-001, AI-001, AI-002

### 🟢 Low Priority (7 issues)
- REMOTE-005, 014, 015
- BIO-003
- UI-003
- PLATFORM-001, 002
- VIDEO-001, 002

---

## Implementation Roadmap

### Phase 1: Security & Core (Sprint 1-2)
1. REMOTE-007: AES Encryption
2. REMOTE-008: SSL/TLS
3. REMOTE-009: WebRTC Server
4. REMOTE-002: mDNS Discovery

### Phase 2: Features (Sprint 3-4)
1. REMOTE-001: Ableton Link
2. BIO-001, 002: Biofeedback
3. AI-001, 002: AI Composer
4. AUDIO-001: Background Export

### Phase 3: Polish (Sprint 5-6)
1. REMOTE-003: Auto-Reconnect
2. REMOTE-012-015: Recording
3. UI improvements
4. Platform-specific features

---

## Converting to GitHub Issues

To convert these to GitHub Issues, run:

```bash
# Example for creating an issue
gh issue create \
  --title "REMOTE-001: Implement Ableton Link SDK Integration" \
  --body "$(cat <<EOF
## Description
Implement actual Ableton Link SDK integration for tempo/beat sync

## File
\`Sources/Remote/RemoteProcessingEngine.cpp:26\`

## Priority
🔴 High

## Requirements
- Download Link SDK from https://github.com/Ableton/link
- Implement LinkImpl::getState() with actual SDK calls
- Enable tempo sync across devices

## Acceptance Criteria
- [ ] Link SDK integrated
- [ ] Tempo sync working with other Link-enabled apps
- [ ] Beat position accurate within 1ms
EOF
)" \
  --label "enhancement" \
  --label "priority:high"
```

---

*Generated by Wise Mode TODO Analyzer*
