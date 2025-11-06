import SwiftUI

/// Ambient mode view - Always-on calming visuals
/// Perfect for background display in living room
struct AmbientModeView: View {

    @EnvironmentObject var visualizationManager: TVVisualizationManager

    @State private var showInfo = false

    var body: some View {
        ZStack {
            // Full-screen ambient visualization
            VisualizationCanvas(
                style: visualizationManager.currentStyle,
                intensity: visualizationManager.intensity,
                coherence: 60.0 // Neutral coherence for ambient
            )
            .ignoresSafeArea()

            // Minimal overlay (only shows on interaction)
            if showInfo {
                VStack {
                    Spacer()

                    HStack {
                        Spacer()

                        // Info card
                        VStack(alignment: .trailing, spacing: 12) {
                            Text("Ambient Mode")
                                .font(.title2.bold())
                                .foregroundColor(.white)

                            Text(visualizationManager.currentStyle.name)
                                .font(.body)
                                .foregroundColor(.white.opacity(0.8))

                            Button(action: {
                                visualizationManager.stopAmbientMode()
                            }) {
                                Label("Exit", systemImage: "xmark.circle.fill")
                                    .font(.body.bold())
                            }
                            .buttonStyle(.bordered)
                            .tint(.red)
                        }
                        .padding(24)
                        .background(Color.black.opacity(0.6))
                        .cornerRadius(20)
                        .padding(.trailing, 60)
                        .padding(.bottom, 60)
                    }
                }
                .transition(.opacity)
            }
        }
        .onAppear {
            visualizationManager.startAmbientMode()

            // Auto-hide info after 3 seconds
            DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                withAnimation {
                    showInfo = false
                }
            }
        }
        .onDisappear {
            visualizationManager.stopAmbientMode()
        }
        .focusable()
        .onMoveCommand { _ in
            // Any remote interaction shows info
            withAnimation {
                showInfo.toggle()
            }
        }
        .onPlayPauseCommand {
            visualizationManager.togglePlayPause()
        }
    }
}

#Preview {
    AmbientModeView()
        .environmentObject(TVVisualizationManager())
}
