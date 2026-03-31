#if canImport(SwiftUI)
import SwiftUI

/// HRV4Training-inspired camera pulse measurement view.
/// Shows finger detection, signal quality, progress, and live HR.
struct CameraMeasurementView: View {

    @Environment(SoundscapeEngine.self) private var engine
    @Environment(\.dismiss) private var dismiss

    @State private var measurementProgress: Double = 0
    @State private var timer: Timer?
    private let measurementDuration: Double = 60 // 60 seconds

    var body: some View {
        ZStack {
            // Red glow background when finger detected
            let isDetected = engine.bioSourceManager.isCameraActive
                && engine.bioSourceManager.primarySource == .camera
            Color.black.ignoresSafeArea()

            if isDetected {
                Color.red.opacity(0.08).ignoresSafeArea()
                    .animation(.easeInOut(duration: 0.5), value: isDetected)
            }

            VStack(spacing: 32) {
                Spacer()

                // Status icon
                ZStack {
                    Circle()
                        .fill(isDetected ? Color.red.opacity(0.15) : Color.white.opacity(0.03))
                        .frame(width: 120, height: 120)

                    if isDetected {
                        // Live heart rate
                        VStack(spacing: 4) {
                            Text("\(Int(engine.bioSourceManager.snapshot.heartRate))")
                                .font(.system(size: 40, weight: .light, design: .rounded))
                                .foregroundStyle(.white.opacity(0.8))
                                .contentTransition(.numericText())
                            Text("BPM")
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.white.opacity(0.3))
                                .kerning(2)
                        }
                    } else {
                        Image(systemName: "hand.point.up.fill")
                            .font(.system(size: 36))
                            .foregroundStyle(.white.opacity(0.2))
                    }
                }

                // Instruction
                Text(isDetected ? "Measuring pulse..." : "Place your finger over the camera")
                    .font(.system(size: 17, weight: .medium))
                    .foregroundStyle(.white.opacity(isDetected ? 0.6 : 0.4))

                if !isDetected {
                    Text("Cover the camera lens completely.\nThe flashlight will illuminate your finger.")
                        .font(.system(size: 13))
                        .foregroundStyle(.white.opacity(0.2))
                        .multilineTextAlignment(.center)
                }

                // Signal quality bar
                if isDetected {
                    VStack(spacing: 8) {
                        // Quality
                        HStack(spacing: 4) {
                            Text("Signal")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(.white.opacity(0.25))
                            Spacer()
                            let quality = engine.bioSourceManager.confidence
                            Text(quality > 0.7 ? "Good" : quality > 0.4 ? "OK" : "Weak")
                                .font(.system(size: 11, weight: .medium))
                                .foregroundStyle(quality > 0.7 ? .green : quality > 0.4 ? .yellow : .red)
                        }

                        // Progress bar
                        GeometryReader { geo in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(.white.opacity(0.06))
                                    .frame(height: 4)
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(.white.opacity(0.3))
                                    .frame(width: geo.size.width * measurementProgress, height: 4)
                                    .animation(.linear(duration: 1), value: measurementProgress)
                            }
                        }
                        .frame(height: 4)

                        Text("\(Int(measurementProgress * measurementDuration))s / \(Int(measurementDuration))s")
                            .font(.system(size: 10, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.15))
                    }
                    .padding(.horizontal, 40)
                }

                Spacer()

                // Actions
                HStack(spacing: 20) {
                    if !engine.bioSourceManager.isCameraActive {
                        Button {
                            engine.bioSourceManager.startCamera()
                            startMeasurementTimer()
                        } label: {
                            Text("Start Measurement")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.black)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(.white, in: RoundedRectangle(cornerRadius: 12))
                        }
                    } else {
                        Button {
                            engine.bioSourceManager.stopCamera()
                            stopMeasurementTimer()
                            dismiss()
                        } label: {
                            Text("Stop")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.5))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                        }
                    }
                }
                .padding(.horizontal, 40)
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
        .onDisappear {
            stopMeasurementTimer()
        }
    }

    private func startMeasurementTimer() {
        measurementProgress = 0
        timer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { _ in
            Task { @MainActor in
                measurementProgress = min(1.0, measurementProgress + 1.0 / measurementDuration)
                if measurementProgress >= 1.0 {
                    stopMeasurementTimer()
                }
            }
        }
    }

    private func stopMeasurementTimer() {
        timer?.invalidate()
        timer = nil
    }
}
#endif
