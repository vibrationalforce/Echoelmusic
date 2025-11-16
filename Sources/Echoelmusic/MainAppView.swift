import SwiftUI

/// Main application view with tab-based navigation
/// Provides access to all major features of Echoelmusic
struct MainAppView: View {

    // MARK: - Environment Objects

    @EnvironmentObject var microphoneManager: MicrophoneManager
    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var recordingEngine: RecordingEngine
    @EnvironmentObject var unifiedControlHub: UnifiedControlHub

    // MARK: - State

    @State private var selectedTab: Tab = .dashboard

    // MARK: - Tab Definition

    enum Tab {
        case dashboard
        case camera
        case studio
        case sessions
        case monetization

        var icon: String {
            switch self {
            case .dashboard: return "waveform.circle.fill"
            case .camera: return "video.circle.fill"
            case .studio: return "slider.horizontal.3"
            case .sessions: return "folder.fill"
            case .monetization: return "dollarsign.circle.fill"
            }
        }

        var title: String {
            switch self {
            case .dashboard: return "Live"
            case .camera: return "Stream"
            case .studio: return "Studio"
            case .sessions: return "Sessions"
            case .monetization: return "Pro"
            }
        }
    }

    // MARK: - Body

    var body: some View {
        TabView(selection: $selectedTab) {

            // MARK: Tab 1 - Dashboard (Live Performance)
            ContentView()
                .tabItem {
                    Label(Tab.dashboard.title, systemImage: Tab.dashboard.icon)
                }
                .tag(Tab.dashboard)

            // MARK: Tab 2 - Camera/Streaming
            CameraStreamingView()
                .tabItem {
                    Label(Tab.camera.title, systemImage: Tab.camera.icon)
                }
                .tag(Tab.camera)

            // MARK: Tab 3 - Studio Editor
            StudioEditorView()
                .tabItem {
                    Label(Tab.studio.title, systemImage: Tab.studio.icon)
                }
                .tag(Tab.studio)

            // MARK: Tab 4 - Session History
            SessionHistoryView()
                .tabItem {
                    Label(Tab.sessions.title, systemImage: Tab.sessions.icon)
                }
                .tag(Tab.sessions)

            // MARK: Tab 5 - Monetization/Pro
            MonetizationView()
                .tabItem {
                    Label(Tab.monetization.title, systemImage: Tab.monetization.icon)
                }
                .tag(Tab.monetization)
        }
        .accentColor(.cyan)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Preview

#Preview {
    MainAppView()
        .environmentObject(MicrophoneManager())
        .environmentObject(AudioEngine(microphoneManager: MicrophoneManager()))
        .environmentObject(HealthKitManager())
        .environmentObject(RecordingEngine())
        .environmentObject(UnifiedControlHub(audioEngine: AudioEngine(microphoneManager: MicrophoneManager())))
}
