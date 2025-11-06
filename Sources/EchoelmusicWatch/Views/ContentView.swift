import SwiftUI

/// Main view for Apple Watch app
/// Shows tabs for HRV, Heart Rate, Breathing, and Settings
struct ContentView: View {

    @EnvironmentObject var healthKitManager: WatchHealthKitManager
    @EnvironmentObject var hapticsManager: WatchHapticsManager

    var body: some View {
        TabView {
            // HRV Monitoring Tab
            HRVMonitorView()
                .tabItem {
                    Label("HRV", systemImage: "waveform.path.ecg")
                }

            // Heart Rate Tab
            HeartRateView()
                .tabItem {
                    Label("Heart", systemImage: "heart.fill")
                }

            // Breathing Guide Tab
            BreathingGuideView()
                .tabItem {
                    Label("Breathe", systemImage: "wind")
                }

            // Settings Tab
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
        }
        .tabViewStyle(.page)
    }
}

#Preview {
    ContentView()
        .environmentObject(WatchHealthKitManager())
        .environmentObject(WatchHapticsManager())
}
