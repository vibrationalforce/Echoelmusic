# Analytics & Monitoring System

**Privacy-first analytics and monitoring for Echoelmusic**

## Overview

The Analytics system provides comprehensive event tracking, performance monitoring, crash reporting, and privacy compliance for the Echoelmusic platform. It's designed with privacy-first principles, full GDPR compliance, and opt-out support.

## Features

### 1. Event Tracking
- Session management
- Feature usage tracking
- Coherence achievement tracking
- Subscription tracking
- Error tracking
- Collaboration tracking
- Plugin tracking

### 2. Performance Monitoring
- App launch time
- Screen render time
- Network request timing
- Custom metric tracking
- Timer utilities

### 3. Crash Reporting
- Non-fatal error logging
- Breadcrumb trail (last 100 events)
- User info attachment
- Context capture

### 4. Privacy Compliance
- GDPR consent management
- Data deletion (right to erasure)
- Data export (right to portability)
- Opt-out support
- Privacy-first defaults

## Quick Start

### Basic Usage

```swift
import Echoelmusic

// 1. Set user consent (GDPR)
PrivacyCompliance.shared.setConsents(
    analytics: true,
    crashReporting: true,
    performance: true
)

// 2. Start session
AnalyticsManager.shared.startSession()

// 3. Track events
AnalyticsManager.shared.trackPresetSelected("Deep Meditation")
AnalyticsManager.shared.trackCoherenceAchieved(percentage: 85.0)

// 4. Track errors
AnalyticsManager.shared.trackError(error, context: "During preset load")

// 5. End session
AnalyticsManager.shared.endSession()
```

## Components

### AnalyticsManager

Central singleton for all analytics operations.

```swift
let manager = AnalyticsManager.shared

// Track events
manager.track(.sessionStarted)
manager.track(.presetSelected(name: "Bio-Reactive Flow"))
manager.track(.coherenceAchieved(level: .high))

// Track feature usage
manager.trackFeatureUsage("quantum_mode")

// Track quantum mode changes
manager.trackQuantumModeChanged("bio_coherent")

// Track visualization changes
manager.trackVisualizationChanged("interference_pattern")

// Track collaboration
manager.trackCollaborationJoined("session_123")
manager.trackCollaborationLeft("session_123", duration: 600.0)

// Track subscriptions
manager.trackSubscriptionViewed("premium")
manager.trackSubscriptionPurchased("premium", price: 19.99)

// Track sharing and export
manager.trackShareCompleted("image")
manager.trackExportCompleted("mp4", duration: 5.5)

// Set user properties
manager.setUserProperty(key: "subscription_tier", value: "premium")

// Identify user
manager.identify(userId: "user_12345")
```

### AnalyticsEvent

All trackable events with type-safe properties.

```swift
// Available events:
.sessionStarted
.sessionEnded(duration: TimeInterval)
.presetSelected(name: String)
.presetApplied(name: String)
.coherenceAchieved(level: CoherenceLevel)
.featureUsed(name: String)
.errorOccurred(type: String, message: String)
.subscriptionViewed(tier: String)
.subscriptionPurchased(tier: String, price: Decimal)
.shareCompleted(type: String)
.exportCompleted(format: String, duration: TimeInterval)
.quantumModeChanged(mode: String)
.visualizationChanged(type: String)
.collaborationJoined(sessionId: String)
.collaborationLeft(sessionId: String, duration: TimeInterval)
.pluginLoaded(name: String)
.performanceWarning(metric: String, value: Double)
```

### Performance Monitor

Track performance metrics and timing.

```swift
let monitor = PerformanceMonitor.shared

// Manual timers
monitor.startTimer("audio_processing")
// ... do work ...
let duration = monitor.stopTimer("audio_processing")

// Closure-based timing
let result = monitor.measure("calculation") {
    return expensiveCalculation()
}

// Async timing
let data = await monitor.measureAsync("network_request") {
    return await fetchData()
}

// App launch
monitor.measureAppLaunch(from: launchDate)

// Screen render
monitor.measureScreenRender(screenName: "HomeView", duration: 0.05)

// Network request
monitor.measureNetworkRequest(
    endpoint: "/api/session",
    duration: 0.5,
    success: true
)

// Custom metrics
monitor.reportMetric(name: "coherence", value: 0.85, unit: "%")
```

### Crash Reporter

Non-fatal error tracking with breadcrumbs.

```swift
let reporter = CrashReporter.shared

// Record breadcrumbs
reporter.log("User opened preset picker")
reporter.debug("Loading presets from cache")
reporter.warning("Cache miss, loading from network")
reporter.error("Network request failed")

// Set user info
reporter.setUserInfo(key: "user_id", value: "123")
reporter.setUserInfo(key: "coherence", value: 0.85)

// Report non-fatal errors
reporter.reportNonFatal(
    error: error,
    context: ["preset": "Deep Meditation"]
)

// Report non-fatal messages
reporter.reportNonFatal(
    message: "Unexpected state transition",
    context: ["from": "idle", "to": "processing"]
)

// Get recent breadcrumbs
let breadcrumbs = reporter.getRecentBreadcrumbs(count: 20)
```

### Privacy Compliance

GDPR and privacy management.

```swift
let privacy = PrivacyCompliance.shared

// Check consent status
if privacy.isAnalyticsEnabled {
    // Track analytics
}

// Set individual consents
privacy.isAnalyticsEnabled = true
privacy.isCrashReportingEnabled = true
privacy.isPerformanceMonitoringEnabled = true

// Set all consents at once
privacy.setConsents(
    analytics: true,
    crashReporting: true,
    performance: true
)

// Check consent date
if let consentDate = privacy.consentDate {
    print("Consent given on: \(consentDate)")
}

// Export user data (GDPR right to portability)
let userData = privacy.exportUserData()
// Returns: ["consents": {...}, "breadcrumbs": [...]]

// Delete all data (GDPR right to erasure)
privacy.deleteAllData()
```

## Analytics Providers

The system supports multiple analytics backends through the `AnalyticsProvider` protocol.

### Built-in Providers

#### 1. ConsoleAnalyticsProvider
Logs to console (debug builds).

```swift
let provider = ConsoleAnalyticsProvider()
```

#### 2. FileAnalyticsProvider
Logs to JSON Lines file.

```swift
let fileURL = FileManager.default.documentsDirectory
    .appendingPathComponent("analytics.jsonl")
let provider = FileAnalyticsProvider(fileURL: fileURL)
```

#### 3. FirebaseAnalyticsProvider (Stub)
Ready for Firebase integration.

```swift
// Add Firebase SDK dependency, then:
let provider = FirebaseAnalyticsProvider()
```

### Custom Provider

Implement your own analytics backend:

```swift
class CustomAnalyticsProvider: AnalyticsProvider {
    func track(event: String, properties: [String: Any]) {
        // Send to your analytics service
    }

    func setUserProperty(key: String, value: Any?) {
        // Set user property
    }

    func identify(userId: String) {
        // Identify user
    }

    func reset() {
        // Reset on logout
    }

    func flush() {
        // Flush pending events
    }
}
```

## Privacy-First Design

### Default Behavior
- **All analytics disabled by default** (opt-in, not opt-out)
- No data collection without explicit consent
- Clear consent screens required

### GDPR Compliance
- ✅ Right to consent
- ✅ Right to withdraw consent
- ✅ Right to data portability (export)
- ✅ Right to erasure (delete)
- ✅ Transparent data collection

### Data Minimization
- Only essential data collected
- No PII without explicit consent
- Anonymized where possible

## Integration Guide

### Step 1: Add Consent Screen

```swift
struct ConsentView: View {
    @State private var analyticsConsent = false
    @State private var crashConsent = false
    @State private var perfConsent = false

    var body: some View {
        Form {
            Section {
                Text("We use analytics to improve Echoelmusic")
                    .font(.subheadline)
            }

            Toggle("Analytics", isOn: $analyticsConsent)
            Toggle("Crash Reports", isOn: $crashConsent)
            Toggle("Performance", isOn: $perfConsent)

            Button("Save Preferences") {
                PrivacyCompliance.shared.setConsents(
                    analytics: analyticsConsent,
                    crashReporting: crashConsent,
                    performance: perfConsent
                )
            }
        }
    }
}
```

### Step 2: Initialize Analytics

```swift
@main
struct EchoelmusicApp: App {
    init() {
        // Start session if consent given
        if PrivacyCompliance.shared.isAnalyticsEnabled {
            AnalyticsManager.shared.startSession()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    // Track app launch
                    let launchDate = Date() // Store this at app launch
                    PerformanceMonitor.shared.measureAppLaunch(from: launchDate)
                }
        }
    }
}
```

### Step 3: Track User Journey

```swift
struct PresetPickerView: View {
    func selectPreset(_ preset: Preset) {
        // Track selection
        AnalyticsManager.shared.trackPresetSelected(preset.name)

        // Apply preset
        applyPreset(preset)

        // Track application
        AnalyticsManager.shared.trackPresetApplied(preset.name)

        // Record breadcrumb
        CrashReporter.shared.log("Applied preset: \(preset.name)")
    }
}
```

### Step 4: Track Errors

```swift
func loadPresets() async {
    do {
        let presets = try await presetService.fetchPresets()
    } catch {
        // Track error
        AnalyticsManager.shared.trackError(
            error,
            context: "Loading presets from API"
        )

        // Report non-fatal
        CrashReporter.shared.reportNonFatal(
            error: error,
            context: ["endpoint": "/api/presets"]
        )
    }
}
```

## File Locations

### Analytics Data
- **Local log file**: `Documents/analytics.jsonl`
- **Format**: JSON Lines (one JSON object per line)

### Example Log Entry
```json
{
  "timestamp": "2026-01-07T15:20:00Z",
  "type": "event",
  "name": "preset_selected",
  "properties": {
    "preset_name": "Deep Meditation"
  }
}
```

## Testing

Run the comprehensive test suite:

```bash
swift test --filter AnalyticsTests
```

### Test Coverage
- ✅ Event tracking (all event types)
- ✅ Analytics providers (console, file, Firebase stub)
- ✅ Crash reporter (breadcrumbs, user info, limits)
- ✅ Performance monitor (timers, metrics, async)
- ✅ Privacy compliance (consent, export, deletion)
- ✅ Session tracking
- ✅ GDPR compliance
- ✅ Thread safety
- ✅ Edge cases
- ✅ Performance benchmarks

## Best Practices

### 1. Always Check Consent
```swift
guard PrivacyCompliance.shared.isAnalyticsEnabled else { return }
// Track analytics
```

### 2. Use Breadcrumbs Liberally
```swift
CrashReporter.shared.log("User navigated to settings")
```

### 3. Track Meaningful Events
```swift
// Good
manager.trackCoherenceAchieved(percentage: 85.0)

// Not useful
manager.trackFeatureUsage("button_tapped")
```

### 4. Add Context to Errors
```swift
manager.trackError(error, context: "During quantum mode switch")
```

### 5. Use Performance Monitoring
```swift
let _ = monitor.measure("expensive_operation") {
    return performExpensiveCalculation()
}
```

## Performance Considerations

- **Async Operations**: All analytics operations are async/non-blocking
- **Queue-Based**: File writing uses serial queue to prevent blocking
- **Batch Uploads**: Providers can batch events (e.g., Firebase)
- **Memory Efficient**: Breadcrumbs limited to 100 most recent
- **No Main Thread Blocking**: All operations off main thread

## Security

- **No Sensitive Data**: Never log passwords, tokens, or PII
- **Secure Storage**: User data in Keychain (if applicable)
- **TLS Only**: All network analytics use HTTPS
- **Data Encryption**: File logs can be encrypted (add encryption layer)

## Troubleshooting

### Analytics Not Tracking
1. Check consent: `PrivacyCompliance.shared.isAnalyticsEnabled`
2. Verify session started: `AnalyticsManager.shared.startSession()`
3. Check provider initialization

### File Logs Not Writing
1. Check file permissions
2. Verify Documents directory access
3. Call `flush()` to force write

### Performance Impact
1. Use `measure` to profile analytics overhead
2. Check breadcrumb count
3. Reduce event frequency if needed

## Roadmap

### Phase 1 (Current)
- ✅ Core analytics system
- ✅ Privacy compliance
- ✅ Basic providers (console, file)
- ✅ Crash reporting
- ✅ Performance monitoring

### Phase 2 (Future)
- [ ] Firebase integration (uncomment stub)
- [ ] Mixpanel provider
- [ ] Amplitude provider
- [ ] Custom dashboard
- [ ] Real-time analytics

### Phase 3 (Future)
- [ ] A/B testing framework
- [ ] Funnel analysis
- [ ] Cohort analysis
- [ ] Retention tracking
- [ ] Revenue analytics

## API Reference

See `AnalyticsManager.swift` for complete API documentation.

### Key Classes
- `AnalyticsManager` - Main analytics orchestrator
- `AnalyticsEvent` - Type-safe event enumeration
- `AnalyticsProvider` - Protocol for custom backends
- `PerformanceMonitor` - Performance tracking
- `CrashReporter` - Non-fatal error reporting
- `PrivacyCompliance` - GDPR and privacy management

### Key Protocols
- `AnalyticsProvider` - Implement for custom analytics backend

## Support

For questions or issues:
1. Check this README
2. Review test cases in `AnalyticsTests.swift`
3. See example usage in integration tests
4. Check ProfessionalLogger output

## License

Part of the Echoelmusic platform.

---

**Last Updated**: 2026-01-07
**Version**: 1.0.0
**Status**: Production Ready ✅
