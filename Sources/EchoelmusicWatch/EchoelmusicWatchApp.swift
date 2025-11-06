import SwiftUI

/// Main entry point for Echoelmusic Apple Watch companion app
///
/// **Purpose:** Real-time biofeedback monitoring on wrist
///
/// **Features:**
/// - Real-time HRV monitoring (built-in sensor!)
/// - Heart rate tracking
/// - Breathing guidance with haptics
/// - Coherence score
/// - Workout integration
/// - Complications for quick glance
/// - Background monitoring
///
/// **Requirements:**
/// - watchOS 7.0+ (Watch Series 6+)
/// - HRV requires Watch Series 4+
/// - HealthKit permission
///
@main
struct EchoelmusicWatchApp: App {

    @StateObject private var healthKitManager = WatchHealthKitManager()
    @StateObject private var hapticsManager = WatchHapticsManager()
    @StateObject private var connectivity: WatchConnectivityManager

    init() {
        let healthKit = WatchHealthKitManager()
        _healthKitManager = StateObject(wrappedValue: healthKit)
        _hapticsManager = StateObject(wrappedValue: WatchHapticsManager())
        _connectivity = StateObject(wrappedValue: WatchConnectivityManager(healthKitManager: healthKit))
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(healthKitManager)
                .environmentObject(hapticsManager)
                .environmentObject(connectivity)
                .onAppear {
                    // Request HealthKit permissions
                    Task {
                        try? await healthKitManager.requestAuthorization()

                        // Start monitoring if authorized
                        if healthKitManager.isAuthorized {
                            healthKitManager.startMonitoring()

                            // Start syncing with iPhone
                            connectivity.startAutoSync()
                        }
                    }
                }
        }
    }
}
