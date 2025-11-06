import SwiftUI

/// Main entry point for Echoelmusic Apple TV app
///
/// **Purpose:** Large-screen ambient biofeedback and group sessions
///
/// **Features:**
/// - Immersive full-screen visualizations (77-85" displays!)
/// - Ambient/screensaver mode
/// - Group biofeedback sessions
/// - Living room wellness experience
/// - Remote control navigation
/// - Shared session support
/// - Background audio with visuals
///
/// **Requirements:**
/// - tvOS 15.0+
/// - Apple TV 4K recommended (better graphics)
/// - iPhone companion app for heart rate input
/// - SharePlay for group sessions (optional)
///
/// **Use Cases:**
/// 1. **Solo Sessions:** Individual meditation with large visuals
/// 2. **Group Sessions:** Family breathing exercises together
/// 3. **Ambient Mode:** Always-on calming background
/// 4. **Party Mode:** Reactive visuals to group energy
///
@main
struct EchoelmusicTVApp: App {

    @StateObject private var sessionManager = TVSessionManager()
    @StateObject private var visualizationManager = TVVisualizationManager()
    @StateObject private var connectivity = TVConnectivityManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(sessionManager)
                .environmentObject(visualizationManager)
                .environmentObject(connectivity)
                .onAppear {
                    // Start listening for iPhone connections
                    connectivity.startDiscovery()

                    // Start ambient mode by default
                    visualizationManager.startAmbientMode()
                }
        }
    }
}
