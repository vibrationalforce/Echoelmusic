import SwiftUI

/// Main view for Apple TV app
/// Shows tabs for Visualizations, Group Sessions, Ambient Mode, and Settings
struct ContentView: View {

    @EnvironmentObject var sessionManager: TVSessionManager
    @EnvironmentObject var visualizationManager: TVVisualizationManager
    @EnvironmentObject var connectivity: TVConnectivityManager

    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            // Visualization Tab
            VisualizationView()
                .tabItem {
                    Label("Visualize", systemImage: "waveform.path")
                }
                .tag(0)

            // Group Session Tab
            GroupSessionView()
                .tabItem {
                    Label("Group", systemImage: "person.3.fill")
                }
                .tag(1)

            // Ambient Mode Tab
            AmbientModeView()
                .tabItem {
                    Label("Ambient", systemImage: "sparkles")
                }
                .tag(2)

            // Connected Devices Tab
            DevicesView()
                .tabItem {
                    Label("Devices", systemImage: "iphone")
                }
                .tag(3)

            // Settings Tab
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape.fill")
                }
                .tag(4)
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
        .environmentObject(TVSessionManager())
        .environmentObject(TVVisualizationManager())
        .environmentObject(TVConnectivityManager())
}
