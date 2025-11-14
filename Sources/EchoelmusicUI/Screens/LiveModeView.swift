import SwiftUI

/// Live performance mode UI
/// Real-time performance interface with bio-reactive visuals
@MainActor
public struct LiveModeView: View {

    /// View state
    @State private var isPerforming: Bool = false
    @State private var currentMode: PerformanceMode = .audio

    /// Performance modes
    public enum PerformanceMode: String, CaseIterable {
        case audio = "Audio"
        case visual = "Visual"
        case combined = "Combined"
        case xr = "XR"
    }

    public init() {}

    public var body: some View {
        ZStack {
            // Background
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 20) {
                // Header
                Text("LIVE MODE")
                    .font(.system(size: 32, weight: .bold, design: .rounded))
                    .foregroundColor(.white)

                // Mode selector
                Picker("Mode", selection: $currentMode) {
                    ForEach(PerformanceMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
                .padding(.horizontal)

                Spacer()

                // Performance controls placeholder
                performanceControls

                Spacer()

                // Start/Stop button
                Button(action: togglePerformance) {
                    Text(isPerforming ? "STOP" : "START")
                        .font(.system(size: 24, weight: .bold))
                        .foregroundColor(.white)
                        .frame(width: 200, height: 60)
                        .background(isPerforming ? Color.red : Color.green)
                        .cornerRadius(30)
                }
                .padding(.bottom, 40)
            }
        }
    }

    @ViewBuilder
    private var performanceControls: some View {
        VStack(spacing: 15) {
            Text("Performance Controls")
                .font(.headline)
                .foregroundColor(.white.opacity(0.7))

            Text("Mode: \(currentMode.rawValue)")
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.5))

            // TODO Phase 3+: Add actual control UI
        }
    }

    private func togglePerformance() {
        isPerforming.toggle()
        print("🎭 LiveMode: \(isPerforming ? "Started" : "Stopped") performance")
    }
}
