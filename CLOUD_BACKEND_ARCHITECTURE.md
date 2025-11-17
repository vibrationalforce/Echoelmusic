# Echoelmusic Codebase Structure Summary

## Overview
**Project Name:** Echoelmusic (branded as "BLAB" - Breath → Sound → Light → Consciousness)
**Type:** Native iOS/cross-platform app (Swift)
**Build System:** Swift Package Manager (Package.swift)
**Minimum Deployment:** iOS 15+, macOS 12+, watchOS 8+, tvOS 15+, visionOS 1+
**Swift Version:** 5.7+

---

## 1. TECH STACK

### Frontend Framework
- **UI Framework:** SwiftUI (declarative UI)
- **Build Tool:** Swift Package Manager (SPM)
- **Project Configuration:** XcodeGen (project.yml)

### Core Audio/Media
- **Audio Engine:** AVFoundation (AVAudioEngine, AVAudioFile)
- **DSP:** Accelerate framework (FFT, vDSP)
- **Video:** AVFoundation (AVPlayer, CMMotionManager)
- **Biofeedback:** HealthKit framework (HRV, Heart Rate)

### State Management
- **Reactive:** Combine framework (@Published, ObservableObject, Combine subscriptions)
- **SwiftUI:** @StateObject, @EnvironmentObject, @State
- **Pattern:** Manager classes with @MainActor annotation

### Cloud & Storage
- **Current Cloud:** CloudKit (iCloud) - basic implementation
- **Local Storage:** File system (Documents directory)
- **Persistence:** JSON encoding/decoding (Codable)

---

## 2. CURRENT DATA STORAGE APPROACH

### Local File System Storage
```
~/Documents/
  └── Sessions/
      └── {UUID}/
          ├── session.json (Session metadata + biodata)
          └── audio_files/ (track audio files)
```

### Data Models

**Core Session Model:**
```swift
struct Session: Identifiable, Codable {
    let id: UUID
    var name: String
    var tracks: [Track]
    var tempo: Double
    var timeSignature: TimeSignature
    var duration: TimeInterval
    var createdAt: Date
    var modifiedAt: Date
    var bioData: [BioDataPoint]
    var metadata: SessionMetadata
}
```

**Track Model:**
```swift
struct Track: Identifiable, Codable {
    let id: UUID
    var name: String
    var url: URL?  // Audio file path
    var duration: TimeInterval
    var volume: Float
    var pan: Float
    var isMuted: Bool
    var isSoloed: Bool
    var effects: [String]  // Node IDs
    var waveformData: [Float]?
    var type: TrackType  // .audio, .voice, .binaural, .spatial, .master
    var createdAt: Date
    var modifiedAt: Date
}
```

**Bio Data Point:**
```swift
struct BioDataPoint: Codable {
    var timestamp: TimeInterval
    var hrv: Double  // Heart Rate Variability
    var heartRate: Double
    var coherence: Double  // HeartMath coherence
    var audioLevel: Float
    var frequency: Float
}
```

**Session Metadata:**
```swift
struct SessionMetadata: Codable {
    var tags: [String]
    var genre: String?
    var mood: String?
    var notes: String?
}
```

### Existing Cloud Integration
- **CloudSyncManager** - CloudKit integration (basic, not production-ready)
  - Saves Session to iCloud private database
  - Fetches sessions from iCloud
  - Auto-backup timer (5-minute intervals)
  - No conflict resolution or multi-device sync

---

## 3. STATE MANAGEMENT ARCHITECTURE

### Observable Objects (Managers)
Each manager is an @MainActor class that conforms to ObservableObject:

1. **MicrophoneManager**
   - Audio input capture
   - FFT frequency detection
   - YIN pitch detection
   - Real-time audio level

2. **AudioEngine**
   - Central audio hub
   - Coordinates microphone, binaural beats, spatial audio
   - Bio-parameter mapping (HRV → audio)
   - Node graph for effects

3. **RecordingEngine**
   - Multi-track recording
   - Session creation/playback
   - Track management
   - Audio file I/O

4. **HealthKitManager**
   - HRV monitoring (RMSSD)
   - Heart rate tracking
   - HeartMath coherence calculation
   - HealthKit authorization

5. **Other Managers:**
   - CloudSyncManager (cloud sync)
   - VideoExportManager (video export)
   - RecordingEngine (recording/playback)
   - UnifiedControlHub (multimodal input)

### Dependency Injection Pattern
```swift
@main
struct EchoelmusicApp: App {
    @StateObject private var microphoneManager = MicrophoneManager()
    @StateObject private var audioEngine: AudioEngine
    @StateObject private var healthKitManager = HealthKitManager()
    @StateObject private var recordingEngine = RecordingEngine()
    
    init() {
        // Create managers and pass to child views via @EnvironmentObject
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(microphoneManager)
                .environmentObject(audioEngine)
                .environmentObject(healthKitManager)
                .environmentObject(recordingEngine)
        }
    }
}
```

---

## 4. PROJECT FILE STRUCTURE

### Main Entry Point
- `/Sources/Echoelmusic/EchoelmusicApp.swift` - @main app struct
- `/Sources/Echoelmusic/ContentView.swift` - Main UI (450+ lines)

### Core Modules (30+ feature folders)

```
Sources/Echoelmusic/
├── Audio/                  # Audio engine, DSP, effects
│   ├── AudioEngine.swift
│   ├── AudioConfiguration.swift
│   ├── Nodes/             # Audio node graph
│   ├── DSP/              # Digital Signal Processing
│   └── Effects/          # Audio effects
├── Recording/             # Session & track management
│   ├── Session.swift      # Core data model
│   ├── Track.swift        # Track data model
│   ├── RecordingEngine.swift
│   └── ExportManager.swift
├── Biofeedback/          # HealthKit integration
│   └── HealthKitManager.swift
├── Cloud/                # Cloud sync
│   └── CloudSyncManager.swift  # CloudKit integration
├── Video/                # Video processing
├── Visual/               # Visualization engines
├── AI/                   # Machine learning
├── Spatial/              # Spatial audio & AR tracking
├── MIDI/                 # MIDI 2.0 + MPE support
├── Stream/               # RTMP streaming
├── Automation/           # Automation engine
├── Views/                # SwiftUI components
├── Onboarding/           # First-time experience
└── [25 other modules]    # Healthcare, performance, accessibility, etc.
```

### Package Configuration
- `Package.swift` - SPM definition
- `project.yml` - XcodeGen config
- `CMakeLists.txt` - CMake build (cross-platform)

---

## 5. EXISTING API/SERVICE LAYER

### Current State: MINIMAL
No dedicated API client or backend service layer exists yet.

### What Exists:
1. **CloudSyncManager** 
   - Uses CloudKit (Apple's iCloud backend)
   - Direct database access (no HTTP API)
   - Limited functionality (save, fetch, auto-backup)

2. **RTMPClient** (in Stream module)
   - RTMP streaming to Twitch/YouTube
   - Separate from data sync

3. **No REST/GraphQL API client**
   - No HTTP networking utilities
   - No centralized error handling for network errors

### Architecture Gap for Supabase Integration:
- Need to create API service layer
- Need centralized URLSession management
- Need Codable mappings for API responses
- Need authentication/token management

---

## 6. BUILD SYSTEM & DEPENDENCIES

### Swift Package Manager (SPM)
```swift
// Package.swift
let package = Package(
    name: "Echoelmusic",
    platforms: [
        .iOS(.v15),
        .macOS(.v12),
        .watchOS(.v8),
        .tvOS(.v15),
        .visionOS(.v1)
    ],
    products: [
        .library(name: "Echoelmusic", targets: ["Echoelmusic"])
    ],
    dependencies: [],  // Currently no external dependencies
    targets: [
        .target(name: "Echoelmusic", dependencies: []),
        .testTarget(name: "EchoelmusicTests", dependencies: ["Echoelmusic"])
    ]
)
```

### Current Dependencies
- **None declared in Package.swift** (uses only Apple frameworks)
- Uses native frameworks:
  - Foundation
  - SwiftUI
  - AVFoundation
  - Combine
  - HealthKit
  - CloudKit
  - ARKit
  - Vision
  - Metal
  - CoreML

---

## 7. RECOMMENDED CLOUD BACKEND STRUCTURE FOR SUPABASE

### Suggested Architecture
```
Sources/Echoelmusic/
├── Backend/                        # NEW - Backend integration layer
│   ├── Services/
│   │   ├── SupabaseClient.swift   # Supabase auth & API wrapper
│   │   ├── SessionService.swift    # CRUD operations for sessions
│   │   ├── ProjectService.swift    # Project management
│   │   ├── PresetService.swift     # Preset management
│   │   └── StorageService.swift    # Cloud file storage
│   ├── Models/
│   │   ├── APIModels.swift         # API response models
│   │   ├── AuthUser.swift          # User data from Supabase Auth
│   │   └── CloudSession.swift      # Cloud session representation
│   ├── Error/
│   │   └── NetworkError.swift      # Unified error handling
│   └── Middleware/
│       └── AuthInterceptor.swift   # Token management
├── Recording/                      # EXISTING
│   ├── Session.swift               # Local session model
│   ├── Track.swift                 # Local track model
│   └── RecordingEngine.swift
└── Cloud/                          # EXISTING (can be enhanced)
    └── CloudSyncManager.swift      # Sync coordinator
```

---

## 8. CURRENT PERSISTENCE FLOW

### Session Lifecycle
```
User Creates Session
    ↓
RecordingEngine creates Session struct
    ↓
Tracks added with audio files
    ↓
Session.save() → JSON to Documents/Sessions/{UUID}/session.json
    ↓
CloudSyncManager.saveSession() → CloudKit (optional)
    ↓
Session.load() → Reads from Documents/Sessions/{UUID}/session.json
```

### Missing: 
- Version control/migration system
- Conflict resolution for cloud sync
- Selective sync (partial uploads)
- Background sync
- Offline queue

---

## 9. KEY ARCHITECTURAL PATTERNS

### 1. Observable Object Pattern
```swift
@MainActor
class AudioEngine: ObservableObject {
    @Published var isRunning: Bool = false
    @Published var binauralBeatsEnabled: Bool = false
    // Published properties automatically update SwiftUI views
}
```

### 2. Dependency Injection via Environment
```swift
@EnvironmentObject var audioEngine: AudioEngine
@EnvironmentObject var recordingEngine: RecordingEngine
// Injected from EchoelmusicApp
```

### 3. Manager Pattern
Each major feature has a manager class that:
- Owns its state (@Published properties)
- Manages lifecycle (init, cleanup)
- Provides public API methods
- Sends notifications via Combine

---

## 10. RECOMMENDED NEXT STEPS FOR SUPABASE INTEGRATION

### Phase 1: Foundation
1. Create `Backend/Services/SupabaseClient.swift` wrapper
2. Add Supabase Swift SDK to Package.swift
3. Create API models matching your Supabase schema
4. Implement authentication service

### Phase 2: Data Sync
1. Create `SessionService` for CRUD operations
2. Extend `CloudSyncManager` to use Supabase (not just CloudKit)
3. Implement bidirectional sync
4. Add conflict resolution

### Phase 3: Storage
1. Create `StorageService` for uploading audio files to Supabase Storage
2. Implement resumable uploads
3. Add progress tracking

### Phase 4: Offline Support
1. Implement offline queue in RecordingEngine
2. Add local cache layer
3. Background sync on reconnect

---

## FILE LOCATIONS TO UPDATE

### Critical Files for Backend Integration
- ✅ `/Sources/Echoelmusic/Recording/Session.swift` - Data model
- ✅ `/Sources/Echoelmusic/Recording/RecordingEngine.swift` - Add cloud sync hooks
- ✅ `/Sources/Echoelmusic/Cloud/CloudSyncManager.swift` - Extend with Supabase
- ✅ `/Sources/Echoelmusic/EchoelmusicApp.swift` - Add auth initialization
- ✅ `Package.swift` - Add Supabase dependency

### New Files to Create
- `/Sources/Echoelmusic/Backend/Services/SupabaseClient.swift`
- `/Sources/Echoelmusic/Backend/Services/SessionService.swift`
- `/Sources/Echoelmusic/Backend/Models/APIModels.swift`
- `/Sources/Echoelmusic/Backend/Error/NetworkError.swift`
- `/Sources/Echoelmusic/Backend/Middleware/AuthInterceptor.swift`

