# Analytics Quick Start Guide

## 5-Minute Setup

### 1. Request Consent (First Launch)

```swift
// ConsentView.swift
import SwiftUI

struct ConsentView: View {
    @State private var analyticsEnabled = false
    @State private var crashReportingEnabled = false
    @State private var performanceEnabled = false
    @AppStorage("hasCompletedConsent") private var hasCompletedConsent = false

    var body: some View {
        VStack(spacing: 20) {
            Text("Help Us Improve Echoelmusic")
                .font(.title)
                .fontWeight(.bold)

            Text("We value your privacy. Choose what data you'd like to share.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)

            VStack(alignment: .leading, spacing: 15) {
                ConsentToggle(
                    title: "Usage Analytics",
                    description: "Help us understand how you use Echoelmusic",
                    isOn: $analyticsEnabled
                )

                ConsentToggle(
                    title: "Crash Reports",
                    description: "Automatically send crash reports to improve stability",
                    isOn: $crashReportingEnabled
                )

                ConsentToggle(
                    title: "Performance Data",
                    description: "Share performance metrics to optimize the app",
                    isOn: $performanceEnabled
                )
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            Button("Continue") {
                saveConsent()
            }
            .buttonStyle(.borderedProminent)

            Button("Skip for Now") {
                hasCompletedConsent = true
            }
            .foregroundColor(.secondary)
        }
        .padding()
    }

    private func saveConsent() {
        PrivacyCompliance.shared.setConsents(
            analytics: analyticsEnabled,
            crashReporting: crashReportingEnabled,
            performance: performanceEnabled
        )
        hasCompletedConsent = true
    }
}

struct ConsentToggle: View {
    let title: String
    let description: String
    @Binding var isOn: Bool

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading) {
                Text(title)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
}
```

### 2. Initialize Analytics (App Launch)

```swift
// EchoelmusicApp.swift
import SwiftUI

@main
struct EchoelmusicApp: App {
    @StateObject private var analyticsManager = AnalyticsManager.shared
    private let appLaunchDate = Date()

    init() {
        setupAnalytics()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .onAppear {
                    trackAppLaunch()
                }
        }
    }

    private func setupAnalytics() {
        // Only start session if user gave consent
        if PrivacyCompliance.shared.isAnalyticsEnabled {
            Task { @MainActor in
                analyticsManager.startSession()
            }
        }
    }

    private func trackAppLaunch() {
        PerformanceMonitor.shared.measureAppLaunch(from: appLaunchDate)
    }
}
```

### 3. Track User Actions

```swift
// PresetView.swift
import SwiftUI

struct PresetView: View {
    @State private var selectedPreset: String?

    var body: some View {
        List(presets) { preset in
            Button(preset.name) {
                selectPreset(preset)
            }
        }
    }

    private func selectPreset(_ preset: Preset) {
        // 1. Record breadcrumb
        CrashReporter.shared.log("User selected preset: \(preset.name)")

        // 2. Track selection
        AnalyticsManager.shared.trackPresetSelected(preset.name)

        // 3. Apply preset
        selectedPreset = preset.name
        applyPreset(preset)

        // 4. Track application
        AnalyticsManager.shared.trackPresetApplied(preset.name)
    }
}
```

### 4. Track Coherence

```swift
// BiofeedbackView.swift
import SwiftUI

struct BiofeedbackView: View {
    @State private var coherencePercentage: Double = 0
    @State private var lastAchievementLevel: Int = 0

    var body: some View {
        VStack {
            CoherenceGauge(value: coherencePercentage)
        }
        .onChange(of: coherencePercentage) { oldValue, newValue in
            trackCoherenceChange(newValue)
        }
    }

    private func trackCoherenceChange(_ coherence: Double) {
        // Track achievement when crossing thresholds
        let currentLevel = Int(coherence / 20) // 0-4 levels (0-20, 20-40, etc.)

        if currentLevel > lastAchievementLevel {
            AnalyticsManager.shared.trackCoherenceAchieved(percentage: coherence)
            lastAchievementLevel = currentLevel
        }
    }
}
```

### 5. Track Errors

```swift
// DataService.swift
import Foundation

class DataService {
    func loadPresets() async throws -> [Preset] {
        do {
            let presets = try await api.fetchPresets()
            CrashReporter.shared.log("Successfully loaded \(presets.count) presets")
            return presets
        } catch {
            // Track error
            AnalyticsManager.shared.trackError(
                error,
                context: "Loading presets from API"
            )

            // Report with context
            CrashReporter.shared.reportNonFatal(
                error: error,
                context: [
                    "endpoint": "/api/presets",
                    "timestamp": Date().ISO8601Format()
                ]
            )

            throw error
        }
    }
}
```

### 6. Track Performance

```swift
// VideoProcessor.swift
import Foundation

class VideoProcessor {
    func exportVideo(format: String) async throws -> URL {
        let startTime = Date()

        // Start performance timer
        PerformanceMonitor.shared.startTimer("video_export")

        do {
            let outputURL = try await processVideo(format: format)

            // Stop timer
            if let duration = PerformanceMonitor.shared.stopTimer("video_export") {
                // Track export completion
                AnalyticsManager.shared.trackExportCompleted(
                    format,
                    duration: duration
                )
            }

            return outputURL
        } catch {
            PerformanceMonitor.shared.stopTimer("video_export")
            throw error
        }
    }
}
```

### 7. Track Subscriptions

```swift
// SubscriptionView.swift
import SwiftUI
import StoreKit

struct SubscriptionView: View {
    var body: some View {
        VStack {
            ForEach(subscriptionTiers) { tier in
                SubscriptionTierCard(tier: tier)
            }
        }
        .onAppear {
            trackView()
        }
    }

    private func trackView() {
        AnalyticsManager.shared.track(.subscriptionViewed(tier: "all"))
    }
}

struct SubscriptionTierCard: View {
    let tier: SubscriptionTier

    var body: some View {
        Button("Subscribe to \(tier.name)") {
            purchaseTier()
        }
    }

    private func purchaseTier() {
        Task {
            do {
                let transaction = try await purchaseSubscription(tier: tier)

                // Track successful purchase
                AnalyticsManager.shared.trackSubscriptionPurchased(
                    tier.name,
                    price: tier.price
                )

                CrashReporter.shared.log("Subscription purchased: \(tier.name)")
            } catch {
                AnalyticsManager.shared.trackError(
                    error,
                    context: "Subscription purchase: \(tier.name)"
                )
            }
        }
    }
}
```

### 8. Settings & Privacy

```swift
// SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @State private var analyticsEnabled = PrivacyCompliance.shared.isAnalyticsEnabled
    @State private var crashReportingEnabled = PrivacyCompliance.shared.isCrashReportingEnabled
    @State private var performanceEnabled = PrivacyCompliance.shared.isPerformanceMonitoringEnabled

    var body: some View {
        Form {
            Section("Privacy & Analytics") {
                Toggle("Usage Analytics", isOn: $analyticsEnabled)
                    .onChange(of: analyticsEnabled) { _, newValue in
                        PrivacyCompliance.shared.isAnalyticsEnabled = newValue
                    }

                Toggle("Crash Reports", isOn: $crashReportingEnabled)
                    .onChange(of: crashReportingEnabled) { _, newValue in
                        PrivacyCompliance.shared.isCrashReportingEnabled = newValue
                    }

                Toggle("Performance Data", isOn: $performanceEnabled)
                    .onChange(of: performanceEnabled) { _, newValue in
                        PrivacyCompliance.shared.isPerformanceMonitoringEnabled = newValue
                    }

                if let consentDate = PrivacyCompliance.shared.consentDate {
                    Text("Consent given: \(consentDate.formatted())")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Section("Your Data") {
                Button("Export My Data") {
                    exportData()
                }

                Button("Delete All Data", role: .destructive) {
                    deleteAllData()
                }
            }
        }
    }

    private func exportData() {
        let data = PrivacyCompliance.shared.exportUserData()

        // Convert to JSON
        if let jsonData = try? JSONSerialization.data(withJSONObject: data, options: .prettyPrinted),
           let jsonString = String(data: jsonData, encoding: .utf8) {
            // Share JSON
            shareJSON(jsonString)
        }
    }

    private func deleteAllData() {
        PrivacyCompliance.shared.deleteAllData()
        CrashReporter.shared.clearBreadcrumbs()

        // Show confirmation
        print("All analytics data deleted")
    }
}
```

## Common Tracking Scenarios

### Quantum Mode Changes
```swift
func changeQuantumMode(to mode: QuantumMode) {
    AnalyticsManager.shared.trackQuantumModeChanged(mode.rawValue)
    CrashReporter.shared.log("Quantum mode changed to \(mode)")
}
```

### Visualization Changes
```swift
func selectVisualization(_ type: VisualizationType) {
    AnalyticsManager.shared.trackVisualizationChanged(type.name)
}
```

### Collaboration Sessions
```swift
func joinSession(_ sessionId: String) {
    AnalyticsManager.shared.trackCollaborationJoined(sessionId)
    sessionStartTime = Date()
}

func leaveSession(_ sessionId: String) {
    let duration = Date().timeIntervalSince(sessionStartTime)
    AnalyticsManager.shared.trackCollaborationLeft(sessionId, duration: duration)
}
```

### Plugin Loading
```swift
func loadPlugin(_ plugin: Plugin) throws {
    do {
        try plugin.initialize()
        AnalyticsManager.shared.trackPluginLoaded(plugin.name)
        CrashReporter.shared.log("Plugin loaded: \(plugin.name)")
    } catch {
        AnalyticsManager.shared.trackError(error, context: "Loading plugin: \(plugin.name)")
        throw error
    }
}
```

## Best Practices

### ✅ DO
- Always check consent before tracking
- Use breadcrumbs liberally (they're cheap)
- Add context to errors
- Track meaningful milestones
- Use performance monitoring for slow operations
- Track feature usage

### ❌ DON'T
- Log sensitive data (passwords, tokens, PII)
- Track every button tap (too noisy)
- Block the main thread
- Ignore user consent
- Track without adding value

## Debugging

### View Analytics Logs (Debug)
```swift
// Analytics logs are visible in console in DEBUG builds
// Look for 📊 emoji prefix
```

### View Analytics File (Release)
```swift
// File location: Documents/analytics.jsonl
// View with:
let fileURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("analytics.jsonl")
print(fileURL.path)
```

### Check Consent Status
```swift
print("Analytics: \(PrivacyCompliance.shared.isAnalyticsEnabled)")
print("Crash Reports: \(PrivacyCompliance.shared.isCrashReportingEnabled)")
print("Performance: \(PrivacyCompliance.shared.isPerformanceMonitoringEnabled)")
```

## Testing

### Unit Tests
```swift
import XCTest
@testable import Echoelmusic

@MainActor
class MyViewTests: XCTestCase {
    func testAnalyticsTracking() {
        // Enable analytics for testing
        PrivacyCompliance.shared.isAnalyticsEnabled = true

        // Track event
        AnalyticsManager.shared.trackFeatureUsage("test_feature")

        // Verify (check logs or use mock provider)
    }
}
```

### Mock Provider
```swift
class MockAnalyticsProvider: AnalyticsProvider {
    var trackedEvents: [(String, [String: Any])] = []

    func track(event: String, properties: [String: Any]) {
        trackedEvents.append((event, properties))
    }

    // ... implement other methods
}
```

## Need Help?

1. Read the full [README.md](README.md)
2. Check [AnalyticsTests.swift](../../Tests/EchoelmusicTests/AnalyticsTests.swift) for examples
3. Review `AnalyticsManager.swift` for API documentation

---

**Ready to track!** 🚀
