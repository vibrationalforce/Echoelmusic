// SpectrumVisualizerView.swift
// Real-time FFT spectrum visualizer for Desktop Engine feedback
//
// Displays 8-band frequency spectrum from Desktop Engine

import SwiftUI

/// Real-time spectrum visualizer receiving FFT data from Desktop Engine
struct SpectrumVisualizerView: View {
    @StateObject private var viewModel = SpectrumViewModel()

    var body: some View {
        VStack(spacing: 20) {
            // Title
            Text("Desktop Audio Analysis")
                .font(.title2)
                .fontWeight(.bold)

            // Spectrum Bars
            HStack(alignment: .bottom, spacing: 8) {
                ForEach(0..<8, id: \.self) { index in
                    SpectrumBar(
                        value: viewModel.spectrum[index],
                        label: viewModel.bandLabels[index],
                        color: viewModel.barColor(for: viewModel.spectrum[index])
                    )
                }
            }
            .frame(height: 250)
            .padding(.horizontal)

            // RMS and Peak Meters
            HStack(spacing: 30) {
                VStack {
                    Text("RMS")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(String(format: "%.1f dB", viewModel.rmsDb))
                        .font(.system(.title3, design: .monospaced))
                        .foregroundColor(meterColor(viewModel.rmsDb))
                }

                VStack {
                    Text("Peak")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(String(format: "%.1f dB", viewModel.peakDb))
                        .font(.system(.title3, design: .monospaced))
                        .foregroundColor(meterColor(viewModel.peakDb))
                }
            }
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(12)

            // Connection Status
            HStack {
                Circle()
                    .fill(viewModel.isReceiving ? Color.green : Color.gray)
                    .frame(width: 10, height: 10)

                Text(viewModel.isReceiving ? "Receiving Desktop Data" : "Waiting for Desktop...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    private func meterColor(_ db: Float) -> Color {
        if db > -6 {
            return .red
        } else if db > -12 {
            return .orange
        } else if db > -24 {
            return .green
        } else {
            return .secondary
        }
    }
}

// MARK: - Spectrum Bar Component

struct SpectrumBar: View {
    let value: Float  // -80 to 0 dB
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            // Bar
            GeometryReader { geometry in
                VStack {
                    Spacer()

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [color.opacity(0.8), color],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(height: normalizedHeight(geometry.size.height))
                        .animation(.easeOut(duration: 0.1), value: value)
                }
            }

            // Label
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.5)
        }
    }

    /// Convert dB (-80 to 0) to normalized height (0 to 1)
    private func normalizedHeight(_ maxHeight: CGFloat) -> CGFloat {
        let dbNormalized = (value + 80.0) / 80.0  // 0 to 1
        let clamped = max(0, min(1, dbNormalized))
        return CGFloat(clamped) * maxHeight
    }
}

// MARK: - View Model

class SpectrumViewModel: ObservableObject {
    @Published var spectrum: [Float] = Array(repeating: -80.0, count: 8)
    @Published var rmsDb: Float = -80.0
    @Published var peakDb: Float = -80.0
    @Published var isReceiving: Bool = false

    let bandLabels = ["Sub", "Bass", "Lo-Mid", "Mid", "Hi-Mid", "Pres", "Brill", "Air"]

    private var lastUpdateTime: Date?
    private var timeoutTimer: Timer?

    init() {
        setupObservers()
        startTimeoutTimer()
    }

    deinit {
        timeoutTimer?.invalidate()
    }

    private func setupObservers() {
        // Spectrum data
        NotificationCenter.default.addObserver(
            forName: .oscSpectrumReceived,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let spectrum = notification.object as? [Float], spectrum.count == 8 {
                self?.spectrum = spectrum
                self?.updateReceivingStatus()
            }
        }

        // RMS level
        NotificationCenter.default.addObserver(
            forName: .oscRMSReceived,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let rms = notification.object as? Float {
                self?.rmsDb = rms
                self?.updateReceivingStatus()
            }
        }

        // Peak level
        NotificationCenter.default.addObserver(
            forName: .oscPeakReceived,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            if let peak = notification.object as? Float {
                self?.peakDb = peak
                self?.updateReceivingStatus()
            }
        }
    }

    private func updateReceivingStatus() {
        lastUpdateTime = Date()
        isReceiving = true
    }

    private func startTimeoutTimer() {
        timeoutTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self, let lastUpdate = self.lastUpdateTime else {
                self?.isReceiving = false
                return
            }

            // Mark as not receiving if no data for 2 seconds
            if Date().timeIntervalSince(lastUpdate) > 2.0 {
                self.isReceiving = false
            }
        }
    }

    /// Get bar color based on dB level
    func barColor(for db: Float) -> Color {
        if db > -6 {
            return .red
        } else if db > -12 {
            return .orange
        } else if db > -24 {
            return .yellow
        } else if db > -48 {
            return .green
        } else {
            return .blue
        }
    }
}

// MARK: - Preview

struct SpectrumVisualizerView_Previews: PreviewProvider {
    static var previews: some View {
        SpectrumVisualizerView()
            .preferredColorScheme(.dark)
    }
}
