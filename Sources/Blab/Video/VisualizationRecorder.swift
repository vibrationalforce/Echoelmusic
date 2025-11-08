import Foundation
import SwiftUI
import UIKit
import AVFoundation
import Combine

/// Visualization to Video Recorder
///
/// Specialized recorder for BLAB visualizations:
/// - Cymatics patterns
/// - Waveforms
/// - Spectral displays
/// - Particle systems
/// - Spatial audio visualizations
@MainActor
class VisualizationRecorder: ObservableObject {

    // MARK: - Published State

    /// Whether recording is active
    @Published var isRecording: Bool = false

    /// Recording duration
    @Published var duration: TimeInterval = 0.0

    /// Frame count
    @Published var frameCount: Int = 0

    /// Current FPS
    @Published var currentFPS: Double = 0.0

    // MARK: - Configuration

    struct Configuration {
        var resolution: CGSize = CGSize(width: 1920, height: 1080)
        var fps: Int = 60
        var captureScale: CGFloat = 2.0  // For Retina displays
        var includeAudio: Bool = true
        var includeTimecode: Bool = true
    }

    var configuration = Configuration()

    // MARK: - Recording Engine

    private var videoRecorder: VideoRecordingEngine
    private var displayLink: CADisplayLink?
    private var viewToRecord: UIView?

    // MARK: - Performance Tracking

    private var lastFrameTime: TimeInterval = 0
    private var fpsCounter: Int = 0
    private var fpsTimer: Timer?

    // MARK: - Dependencies

    private var audioEngine: AudioEngine?
    private var healthKitManager: HealthKitManager?

    // MARK: - Initialization

    init(videoRecorder: VideoRecordingEngine = VideoRecordingEngine()) {
        self.videoRecorder = videoRecorder
        print("🎬 VisualizationRecorder initialized")
    }

    // MARK: - Public API

    /// Start recording a view
    func startRecording(view: UIView) throws {
        guard !isRecording else { return }

        viewToRecord = view

        // Start video recorder
        try videoRecorder.startRecording(visualizationView: view)

        // Setup display link for frame capture
        displayLink = CADisplayLink(target: self, selector: #selector(captureFrame))
        displayLink?.preferredFramesPerSecond = configuration.fps
        displayLink?.add(to: .main, forMode: .common)

        // Start FPS tracking
        startFPSTracking()

        isRecording = true
        print("🎬 Visualization recording started")
    }

    /// Stop recording
    func stopRecording() async throws -> URL? {
        guard isRecording else { return nil }

        isRecording = false

        // Stop display link
        displayLink?.invalidate()
        displayLink = nil

        // Stop FPS tracking
        fpsTimer?.invalidate()
        fpsTimer = nil

        // Stop video recorder
        let url = try await videoRecorder.stopRecording()

        print("🎬 Visualization recording stopped: \(frameCount) frames, \(String(format: "%.2f", currentFPS)) FPS")

        // Reset state
        viewToRecord = nil
        frameCount = 0
        duration = 0
        currentFPS = 0

        return url
    }

    /// Record specific visualization mode
    func recordVisualization(
        mode: VisualizationMode,
        duration: TimeInterval,
        audioSource: AudioEngine? = nil
    ) async throws -> URL {
        // Create visualization view
        let visualizationView = createVisualizationView(for: mode, audioSource: audioSource)

        // Start recording
        try startRecording(view: visualizationView)

        // Wait for duration
        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))

        // Stop recording
        guard let url = try await stopRecording() else {
            throw RecordingError.noOutputURL
        }

        return url
    }

    /// Capture cymatics animation
    func recordCymatics(duration: TimeInterval, frequency: Float = 440.0) async throws -> URL {
        // Create cymatics renderer
        let renderer = CymaticsRenderer()

        // Create view for renderer
        let size = configuration.resolution
        let view = UIView(frame: CGRect(origin: .zero, size: size))

        // Animate frequency sweep
        let startTime = Date()

        Task {
            while isRecording {
                let elapsed = Date().timeIntervalSince(startTime)
                let sweepFreq = frequency * Float(1.0 + sin(elapsed * 0.5) * 0.5)

                // Update renderer with frequency
                // TODO: Update cymatics with sweepFreq

                try? await Task.sleep(nanoseconds: 16_666_667)  // ~60 FPS
            }
        }

        // Record
        try startRecording(view: view)
        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))

        guard let url = try await stopRecording() else {
            throw RecordingError.noOutputURL
        }

        return url
    }

    /// Record spatial audio visualization
    func recordSpatialVisualization(
        sources: [SpatialSource],
        duration: TimeInterval
    ) async throws -> URL {
        // Create 3D visualization view
        let view = createSpatialVisualizationView(sources: sources)

        try startRecording(view: view)
        try await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))

        guard let url = try await stopRecording() else {
            throw RecordingError.noOutputURL
        }

        return url
    }

    /// Update bio data overlay
    func updateBioData(hrv: Double, heartRate: Double) {
        videoRecorder.updateBioData(hrv: hrv, heartRate: heartRate)
    }

    // MARK: - Private Methods

    @objc private func captureFrame() {
        guard let view = viewToRecord, isRecording else { return }

        // Calculate FPS
        let currentTime = CACurrentMediaTime()
        if lastFrameTime > 0 {
            let delta = currentTime - lastFrameTime
            let instantFPS = 1.0 / delta
            currentFPS = (currentFPS * 0.9) + (instantFPS * 0.1)  // Smooth
        }
        lastFrameTime = currentTime

        // Capture frame
        let renderer = UIGraphicsImageRenderer(size: view.bounds.size, format: UIGraphicsImageRendererFormat())

        let image = renderer.image { context in
            view.layer.render(in: context.cgContext)
        }

        // Append to video
        videoRecorder.appendVideoFrame(image)

        frameCount += 1
        fpsCounter += 1
    }

    private func startFPSTracking() {
        fpsCounter = 0

        fpsTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self = self else { return }
            Task { @MainActor in
                self.duration += 1.0
                // FPS is updated in captureFrame
            }
        }
    }

    private func createVisualizationView(for mode: VisualizationMode, audioSource: AudioEngine?) -> UIView {
        let size = configuration.resolution
        let view = UIView(frame: CGRect(origin: .zero, size: size))
        view.backgroundColor = .black

        // Create visualization layer based on mode
        // TODO: Implement per mode

        return view
    }

    private func createSpatialVisualizationView(sources: [SpatialSource]) -> UIView {
        let size = configuration.resolution
        let view = UIView(frame: CGRect(origin: .zero, size: size))
        view.backgroundColor = .black

        // Create 3D visualization
        // Draw spatial sources as spheres
        for source in sources {
            let sphere = UIView(frame: CGRect(x: 0, y: 0, width: 20, height: 20))
            sphere.backgroundColor = UIColor(hue: CGFloat(source.hue / 360.0), saturation: 1.0, brightness: 1.0, alpha: 0.8)
            sphere.layer.cornerRadius = 10

            // Project 3D position to 2D
            let x = size.width / 2 + CGFloat(source.position.x) * 100
            let y = size.height / 2 + CGFloat(source.position.y) * 100

            sphere.center = CGPoint(x: x, y: y)

            view.addSubview(sphere)
        }

        return view
    }

    // MARK: - Export Helpers

    /// Export with social media presets
    func exportForPlatform(_ platform: SocialPlatform, sourceURL: URL) async throws -> URL {
        let config: VideoRecordingEngine.ExportConfiguration

        switch platform {
        case .instagram:
            config = .instagram
        case .youtube:
            config = .youtube
        case .twitter:
            config = .twitter
        case .tiktok:
            config = VideoRecordingEngine.ExportConfiguration(preset: AVAssetExportPreset1280x720)
        }

        return try await videoRecorder.exportVideo(from: sourceURL, configuration: config)
    }

    enum SocialPlatform {
        case instagram
        case youtube
        case twitter
        case tiktok
    }

    // MARK: - Supporting Types

    enum VisualizationMode {
        case cymatics
        case waveform
        case spectrum
        case particles
        case mandala
        case spatial
    }

    struct SpatialSource {
        let id: UUID
        let position: SIMD3<Float>
        let amplitude: Float
        let hue: Float
    }

    // MARK: - Errors

    enum RecordingError: Error, LocalizedError {
        case noOutputURL
        case recordingInProgress
        case noViewToRecord

        var errorDescription: String? {
            switch self {
            case .noOutputURL:
                return "No output URL generated"
            case .recordingInProgress:
                return "Recording already in progress"
            case .noViewToRecord:
                return "No view specified for recording"
            }
        }
    }
}

// MARK: - SwiftUI Integration

#if canImport(SwiftUI)
import SwiftUI

struct VisualizationRecorderView: View {
    @StateObject private var recorder = VisualizationRecorder()
    @State private var recordedURL: URL?

    var body: some View {
        VStack(spacing: 20) {
            if recorder.isRecording {
                // Recording indicator
                HStack {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                        .opacity(recorder.isRecording ? 1 : 0)
                        .animation(.easeInOut(duration: 0.5).repeatForever(autoreverses: true), value: recorder.isRecording)

                    Text("REC")
                        .font(.system(.headline, design: .monospaced))
                        .foregroundColor(.red)

                    Text(formatDuration(recorder.duration))
                        .font(.system(.headline, design: .monospaced))
                }

                // Stats
                HStack(spacing: 30) {
                    VStack {
                        Text("\(recorder.frameCount)")
                            .font(.title)
                        Text("Frames")
                            .font(.caption)
                    }

                    VStack {
                        Text(String(format: "%.1f", recorder.currentFPS))
                            .font(.title)
                        Text("FPS")
                            .font(.caption)
                    }
                }
            }

            // Controls
            HStack(spacing: 20) {
                if !recorder.isRecording {
                    Button("Start Recording") {
                        // TODO: Provide view to record
                    }
                    .buttonStyle(.borderedProminent)
                } else {
                    Button("Stop Recording") {
                        Task {
                            recordedURL = try? await recorder.stopRecording()
                        }
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }

            if let url = recordedURL {
                Text("Recorded: \(url.lastPathComponent)")
                    .font(.caption)
                    .foregroundColor(.green)
            }
        }
        .padding()
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
}
#endif
