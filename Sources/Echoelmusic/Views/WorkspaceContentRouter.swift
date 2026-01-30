import SwiftUI

// MARK: - Workspace Content Router
// Extracted from MainNavigationHub for better modularity and testability
// Routes workspace selection to the appropriate view

struct WorkspaceContentRouter: View {

    // MARK: - Properties

    let workspace: MainNavigationHub.Workspace

    // MARK: - Environment

    @EnvironmentObject var healthKitManager: HealthKitManager
    @EnvironmentObject var audioEngine: AudioEngine
    @EnvironmentObject var microphoneManager: MicrophoneManager

    // MARK: - Body

    var body: some View {
        content
            .transition(.opacity.combined(with: .scale(scale: 0.98)))
            .animation(.easeInOut(duration: 0.2), value: workspace)
    }

    // MARK: - Content Router

    @ViewBuilder
    private var content: some View {
        switch workspace {
        case .palace:
            VaporwavePalace()
                .environmentObject(healthKitManager)
                .environmentObject(audioEngine)
                .environmentObject(microphoneManager)

        case .daw:
            DAWArrangementView()

        case .session:
            SessionClipView()

        case .video:
            VideoEditorView()

        case .vj:
            VJLaserControlView()

        case .nodes:
            NodeEditorView()

        case .midi:
            MIDIRoutingView()

        case .mixing:
            AudioRoutingMatrixView()

        case .ai:
            AISuperIntelligenceView()

        case .hardware:
            HardwarePickerView()

        case .streaming:
            StreamingView()

        case .settings:
            VaporwaveSettings()
                .environmentObject(healthKitManager)
                .environmentObject(audioEngine)
        }
    }
}

// MARK: - Workspace Metadata Extension

extension MainNavigationHub.Workspace {

    /// Human-readable description for accessibility
    var accessibilityLabel: String {
        switch self {
        case .palace: return "Vaporwave Palace - Main creative dashboard"
        case .daw: return "Digital Audio Workstation - Arrangement view"
        case .session: return "Session View - Clip launcher"
        case .video: return "Video Editor - Edit and process video"
        case .vj: return "VJ and Laser Control - Visual performance"
        case .nodes: return "Node Editor - Visual programming"
        case .midi: return "MIDI Routing - Connect devices"
        case .mixing: return "Mixing Console - Audio routing matrix"
        case .ai: return "AI Tools - Super intelligence features"
        case .hardware: return "Hardware - Device configuration"
        case .streaming: return "Streaming - Live broadcast"
        case .settings: return "Settings - App configuration"
        }
    }

    /// Keyboard shortcut for workspace (for macOS)
    var keyboardShortcut: KeyEquivalent? {
        switch self {
        case .palace: return "1"
        case .daw: return "2"
        case .session: return "3"
        case .video: return "4"
        case .vj: return "5"
        case .nodes: return "6"
        case .midi: return "7"
        case .mixing: return "8"
        case .ai: return "9"
        case .hardware: return "0"
        case .streaming: return nil
        case .settings: return ","
        }
    }
}

// MARK: - Preview

#if DEBUG
struct WorkspaceContentRouter_Previews: PreviewProvider {
    static var previews: some View {
        WorkspaceContentRouter(workspace: .palace)
            .environmentObject(HealthKitManager())
            .environmentObject(AudioEngine())
            .environmentObject(MicrophoneManager())
    }
}
#endif
