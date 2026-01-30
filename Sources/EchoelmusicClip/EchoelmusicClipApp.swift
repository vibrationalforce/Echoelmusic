// =============================================================================
// ECHOELMUSIC APP CLIP
// =============================================================================
// Lightweight App Clip for instant bio-reactive audio experiences
// Bundle ID: com.echoelmusic.app.Clip
// =============================================================================

import SwiftUI

@main
struct EchoelmusicClipApp: App {
    var body: some Scene {
        WindowGroup {
            ClipContentView()
        }
    }
}

struct ClipContentView: View {
    @State private var coherenceLevel: Double = 0.5
    @State private var isPlaying: Bool = false

    var body: some View {
        VStack(spacing: 24) {
            // Header
            VStack(spacing: 8) {
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 60))
                    .foregroundStyle(.linearGradient(
                        colors: [.purple, .blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))

                Text("Echoelmusic")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Bio-Reactive Audio")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 40)

            Spacer()

            // Coherence Visualization
            ZStack {
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 8)
                    .frame(width: 200, height: 200)

                Circle()
                    .trim(from: 0, to: coherenceLevel)
                    .stroke(
                        LinearGradient(
                            colors: [.blue, .purple],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        style: StrokeStyle(lineWidth: 8, lineCap: .round)
                    )
                    .frame(width: 200, height: 200)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: coherenceLevel)

                VStack {
                    Text("\(Int(coherenceLevel * 100))%")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                    Text("Coherence")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Play Button
            Button(action: {
                isPlaying.toggle()
                if isPlaying {
                    startSimulation()
                }
            }) {
                HStack {
                    Image(systemName: isPlaying ? "pause.fill" : "play.fill")
                    Text(isPlaying ? "Pause" : "Start Experience")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .cornerRadius(16)
            }
            .padding(.horizontal, 32)

            // Get Full App
            Button(action: openFullApp) {
                Text("Get the Full App")
                    .font(.subheadline)
                    .foregroundColor(.blue)
            }
            .padding(.bottom, 40)
        }
        .preferredColorScheme(.dark)
    }

    private func startSimulation() {
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { timer in
            guard isPlaying else {
                timer.invalidate()
                return
            }
            withAnimation {
                coherenceLevel = Double.random(in: 0.3...0.9)
            }
        }
    }

    private func openFullApp() {
        if let url = URL(string: "https://apps.apple.com/app/echoelmusic/id0000000000") {
            UIApplication.shared.open(url)
        }
    }
}

#Preview {
    ClipContentView()
}
