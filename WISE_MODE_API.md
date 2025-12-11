# Wise Mode API Documentation

## Overview

The Wise Mode system provides an intelligent, adaptive mode management system for Echoelmusic. It optimizes the audio-visual experience based on user context, time of day, and biometric data.

## Table of Contents

1. [Core Types](#core-types)
2. [WiseModeManager](#wisemodemanager)
3. [WisePresetManager](#wisepresetmanager)
4. [WiseScheduler](#wisescheduler)
5. [WiseAnalyticsManager](#wiseanalyticsmanager)
6. [Engine Integration](#engine-integration)
7. [Performance APIs](#performance-apis)
8. [UI Components](#ui-components)

---

## Core Types

### WiseMode

The primary mode enumeration representing different usage contexts.

```swift
enum WiseMode: String, CaseIterable, Codable, Identifiable {
    case focus       // Deep concentration
    case flow        // Creative flow state
    case healing     // Therapeutic application
    case meditation  // Meditative practice
    case energize    // Activation & energy
    case sleep       // Sleep preparation
    case social      // Group sessions
    case custom      // User-defined
}
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `icon` | `String` | SF Symbol name |
| `description` | `String` | Mode description |
| `color` | `Color` | Associated color |
| `binauralFrequency` | `Float` | Recommended binaural frequency (Hz) |
| `recommendedDuration` | `Int` | Session duration in minutes |
| `recommendedVisualization` | `String` | Suggested visualization mode |

### WisdomLevel

User experience and progression levels.

```swift
enum WisdomLevel: Int, CaseIterable, Codable {
    case novice = 0
    case learning = 1
    case practicing = 2
    case proficient = 3
    case expert = 4
    case enlightened = 5
}
```

#### Properties

| Property | Type | Description |
|----------|------|-------------|
| `displayName` | `String` | Localized name |
| `englishName` | `String` | English name |
| `icon` | `String` | SF Symbol |
| `color` | `Color` | Level color |
| `requiredSessions` | `Int` | Sessions needed |
| `requiredCoherence` | `Float` | Required average coherence |

### WiseModeConfiguration

Complete configuration for a Wise Mode.

```swift
struct WiseModeConfiguration: Codable, Identifiable {
    let id: UUID
    var mode: WiseMode
    var binauralFrequency: Float
    var carrierFrequency: Float
    var visualizationMode: String
    var colorScheme: WiseColorScheme
    var hapticFeedback: HapticIntensity
    var audioQuality: AudioQuality
    var bioAdaptive: Bool
    var sessionDuration: Int
}
```

---

## WiseModeManager

Central manager for the Wise Mode system.

### Access

```swift
let manager = WiseModeManager.shared
```

### Published Properties

| Property | Type | Description |
|----------|------|-------------|
| `currentMode` | `WiseMode` | Active mode |
| `wisdomLevel` | `WisdomLevel` | User's level |
| `currentConfiguration` | `WiseModeConfiguration` | Current config |
| `isTransitioning` | `Bool` | Mode transition in progress |
| `transitionProgress` | `Float` | Transition progress (0-1) |
| `currentSessionStats` | `WiseSessionStats?` | Active session |
| `isActive` | `Bool` | Session active |
| `totalSessions` | `Int` | Lifetime sessions |
| `totalMinutes` | `Int` | Lifetime minutes |
| `averageCoherence` | `Float` | Lifetime average |
| `streakDays` | `Int` | Current streak |

### Methods

#### Mode Control

```swift
// Switch to a new mode
func switchMode(to newMode: WiseMode, reason: WiseModeTransition.TransitionReason = .userInitiated)

// Quick actions
func quickFocus()
func quickFlow()
func quickMeditation()
func quickSleep()
```

#### Session Control

```swift
// Start a new session
func startSession()

// End current session
func endSession()

// Update bio data during session
func updateBioData(coherence: Float, hrv: Float)
```

#### Configuration

```swift
// Update configuration
func updateConfiguration(_ config: WiseModeConfiguration)

// Set specific parameter
func setParameter<T>(_ keyPath: WritableKeyPath<WiseModeConfiguration, T>, value: T)
```

### Callbacks

```swift
// Mode change callback
var onModeChange: ((WiseMode, WiseModeConfiguration) -> Void)?

// Wisdom level change
var onWisdomLevelChange: ((WisdomLevel) -> Void)?

// Transition complete
var onTransitionComplete: ((WiseModeTransition) -> Void)?
```

### Example Usage

```swift
// Switch mode
WiseModeManager.shared.switchMode(to: .flow)

// Start session with observation
let manager = WiseModeManager.shared
manager.onModeChange = { mode, config in
    print("Mode changed to: \(mode.rawValue)")
}

manager.startSession()

// Update bio data
manager.updateBioData(coherence: 0.75, hrv: 45.0)

// End session
manager.endSession()
```

---

## WisePresetManager

Manages user-defined presets.

### Access

```swift
let presetManager = WisePresetManager.shared
```

### Published Properties

| Property | Type | Description |
|----------|------|-------------|
| `presets` | `[WisePreset]` | All presets |
| `favoritePresets` | `[WisePreset]` | Favorites |
| `recentPresets` | `[WisePreset]` | Recently used |
| `selectedPreset` | `WisePreset?` | Currently selected |

### Methods

#### CRUD Operations

```swift
// Create preset
func createPreset(
    name: String,
    description: String = "",
    icon: String = "slider.horizontal.3",
    color: PresetColor = .blue,
    configuration: WiseModeConfiguration,
    tags: [String] = []
) -> WisePreset

// Create from current
func createPresetFromCurrent(name: String, description: String = "") -> WisePreset

// Update preset
func updatePreset(_ preset: WisePreset)

// Delete preset
func deletePreset(_ preset: WisePreset)

// Apply preset
func applyPreset(_ preset: WisePreset)

// Toggle favorite
func toggleFavorite(_ preset: WisePreset)

// Duplicate
func duplicatePreset(_ preset: WisePreset) -> WisePreset
```

#### Search & Filter

```swift
// Search by name or tags
func searchPresets(query: String) -> [WisePreset]

// Filter by mode
func filterByMode(_ mode: WiseMode) -> [WisePreset]

// Sort by usage
func sortedByUsage() -> [WisePreset]
```

#### Import/Export

```swift
// Export all presets
func exportPresets() -> Data?

// Export single preset
func exportPreset(_ preset: WisePreset) -> Data?

// Import presets
func importPresets(from data: Data) throws

// Import single preset
func importPreset(from data: Data) throws -> WisePreset
```

---

## WiseScheduler

Automatic mode switching based on schedules.

### Access

```swift
let scheduler = WiseScheduler.shared
```

### Published Properties

| Property | Type | Description |
|----------|------|-------------|
| `scheduleItems` | `[WiseScheduleItem]` | All schedules |
| `isSchedulerEnabled` | `Bool` | Scheduler active |
| `nextScheduledItem` | `WiseScheduleItem?` | Next scheduled |
| `timeUntilNext` | `TimeInterval` | Time to next |

### Schedule Types

```swift
enum ScheduleType: Codable {
    case daily(time: TimeOfDay)
    case weekly(days: [Weekday], time: TimeOfDay)
    case specificDate(date: Date)
    case timeRange(start: TimeOfDay, end: TimeOfDay)
    case smart(trigger: SmartTrigger)
}
```

### Smart Triggers

```swift
enum SmartTrigger: String, Codable {
    case morningRoutine
    case workStart
    case lunchBreak
    case afternoonSlump
    case eveningWindDown
    case bedtime
    case lowEnergy
    case highStress
    case optimalFlow
}
```

### Methods

```swift
// Create schedule
func createSchedule(
    name: String,
    mode: WiseMode,
    schedule: ScheduleType,
    presetID: UUID? = nil,
    notifyBefore: Int = 5,
    autoStart: Bool = true
) -> WiseScheduleItem

// Update schedule
func updateSchedule(_ item: WiseScheduleItem)

// Delete schedule
func deleteSchedule(_ item: WiseScheduleItem)

// Toggle enable/disable
func toggleSchedule(_ item: WiseScheduleItem)

// Check smart triggers based on bio data
func checkSmartTriggers(hrv: Float, coherence: Float, heartRate: Float)
```

---

## WiseAnalyticsManager

Usage statistics and progress tracking.

### Access

```swift
let analytics = WiseAnalyticsManager.shared
```

### Published Properties

| Property | Type | Description |
|----------|------|-------------|
| `currentSnapshot` | `WiseAnalyticsSnapshot?` | Period snapshot |
| `selectedPeriod` | `AnalyticsPeriod` | View period |
| `dailySummaries` | `[DailySummary]` | Daily stats |
| `coherenceHistory` | `[CoherenceDataPoint]` | Coherence trend |
| `sessionHistory` | `[SessionDataPoint]` | Session history |
| `todaySessions` | `Int` | Today's count |
| `todayMinutes` | `Int` | Today's minutes |
| `todayCoherence` | `Float` | Today's avg |
| `currentStreak` | `Int` | Current streak |
| `achievements` | `[WiseAchievement]` | All achievements |
| `recentAchievements` | `[WiseAchievement]` | Recent unlocks |

### Methods

```swift
// Refresh analytics
func refreshAnalytics()

// Set analysis period
func setPeriod(_ period: AnalyticsPeriod)

// Export analytics
func exportAnalytics() -> Data?

// Export sessions as CSV
func exportSessionsCSV() -> String
```

### Analytics Periods

```swift
enum AnalyticsPeriod: String, CaseIterable {
    case day
    case week
    case month
    case year
    case allTime
}
```

---

## Engine Integration

### RecordingEngine Integration

```swift
// Apply Wise Mode preset to recording
extension RecordingEngine {
    func applyWisePreset(_ mode: WiseMode)
    func applyRecordingPreset(_ preset: WiseRecordingPreset)
}
```

### WiseRecordingPreset

```swift
struct WiseRecordingPreset {
    let mode: WiseMode
    var sampleRate: Double
    var bitDepth: Int
    var channelCount: Int
    var retrospectiveBufferDuration: TimeInterval
    var autoNormalize: Bool
    var noiseReduction: NoiseReductionLevel
    var compressionPreset: CompressionPreset
}
```

### CollaborationEngine Integration

```swift
let collaboration = WiseCollaborationManager.shared

// Connect to collaboration engine
collaboration.connect(to: collaborationEngine)

// Create group session
collaboration.createGroupSession(mode: .social)

// Sync mode with group
collaboration.syncModeWithGroup(.meditation)

// Update group coherence
collaboration.updateGroupCoherence(participantData: [...])
```

### AccessibilityManager Integration

```swift
let accessibility = WiseAccessibilityManager.shared

// Connect to accessibility manager
accessibility.connect(to: accessibilityManager)

// Configuration per mode
let config = WiseAccessibilityConfig(mode: .meditation)
```

---

## Performance APIs

### Lazy Loading

```swift
let lazyLoader = WiseLazyLoadingManager.shared

// Load mode resources
await lazyLoader.loadMode(.flow)

// Check if loaded
lazyLoader.isModeLoaded(.flow)

// Get resources
let resources = lazyLoader.getResources(for: .flow)

// Purge inactive modes
lazyLoader.purgeInactiveModes()

// Total memory
let memory = lazyLoader.totalMemoryFootprint()
```

### Memory Analysis

```swift
let memory = WiseMemoryAnalyzer.shared

// Properties
memory.currentMemoryUsage  // Int64
memory.peakMemoryUsage     // Int64
memory.componentBreakdown  // [String: Int64]

// Generate report
let report = memory.generateReport()
```

### Battery Monitoring

```swift
let battery = WiseBatteryMonitor.shared

// Properties
battery.currentBatteryLevel      // Float
battery.isCharging               // Bool
battery.modeEnergyConsumption    // [WiseMode: EnergyConsumption]
battery.currentPowerMode         // PowerMode

// Methods
battery.setPowerMode(.lowPower)
let recommendation = battery.getRecommendation()
```

### Performance Benchmarks

```swift
let benchmark = WisePerformanceBenchmark.shared

// Run full benchmark
await benchmark.runFullBenchmark()

// Benchmark single mode
let result = await benchmark.benchmarkMode(.focus)

// Generate report
let report = benchmark.generateReport()
```

---

## UI Components

### WiseModeSelectionView

Main mode selection interface.

```swift
WiseModeSelectionView()
```

### WisePresetPicker

Preset selection with search and filtering.

```swift
WisePresetPicker()
```

### WiseScheduleEditor

Schedule management interface.

```swift
WiseScheduleEditor()
```

### WiseAnalyticsDashboard

Analytics and statistics view.

```swift
WiseAnalyticsDashboard()
```

### WisePerformanceDashboard

Performance monitoring view.

```swift
WisePerformanceDashboard()
```

### Haptic Feedback

```swift
let haptics = WiseHapticFeedbackManager.shared

// Mode change haptic
haptics.modeChangeHaptic(to: .flow)

// Coherence achieved
haptics.coherenceAchievedHaptic(level: 0.85)

// UI interactions
haptics.buttonTapHaptic()
haptics.sliderChangeHaptic()
haptics.successHaptic()
```

---

## Widget Support

### Widget Entry

```swift
struct WiseModeWidgetEntry: TimelineEntry {
    let date: Date
    let mode: WiseMode
    let wisdomLevel: WisdomLevel
    let todaySessions: Int
    let todayMinutes: Int
    let currentCoherence: Float
    let streakDays: Int
}
```

### Widget Views

- `WiseModeWidgetSmall` - Compact view
- `WiseModeWidgetMedium` - Standard view
- `WiseModeWidgetLarge` - Full view

### Watch Complications

- `WisdomLevelComplication` - Circular progress
- `WiseModeCircularComplication` - Mode icon
- `WiseModeRectangularComplication` - Mode with stats

---

## Best Practices

### 1. Mode Transitions

Always use the manager's `switchMode` method instead of setting the mode directly:

```swift
// Good
WiseModeManager.shared.switchMode(to: .flow)

// Avoid - bypasses transition system
// manager.currentMode = .flow
```

### 2. Session Management

Start and end sessions properly to ensure accurate tracking:

```swift
manager.startSession()
defer { manager.endSession() }

// Your session logic
```

### 3. Bio Data Updates

Update bio data regularly during active sessions:

```swift
// In your bio data processing loop
manager.updateBioData(coherence: coherence, hrv: hrv)
```

### 4. Memory Management

For memory-constrained devices, use lazy loading:

```swift
// Only load needed modes
await WiseLazyLoadingManager.shared.loadMode(targetMode)

// Purge when memory is low
if memory.currentMemoryUsage > threshold {
    WiseLazyLoadingManager.shared.purgeInactiveModes()
}
```

### 5. Battery Optimization

Respect battery state:

```swift
if battery.currentBatteryLevel < 0.2 && !battery.isCharging {
    battery.setPowerMode(.lowPower)
}
```

---

## Version History

| Version | Date | Changes |
|---------|------|---------|
| 1.0.0 | 2024-12 | Initial release |

---

## Support

For questions or issues, please refer to:
- `DEVELOPER_SUGGESTIONS_WISE_MODE.md` for implementation guidelines
- `ECHOEL_WISDOM_ARCHITECTURE.md` for system architecture
- GitHub Issues for bug reports
