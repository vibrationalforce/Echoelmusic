import SwiftUI
import Metal

/// Comprehensive video export UI for social media platforms
/// Supports Instagram, TikTok, YouTube, and custom exports
struct VideoExportView: View {

    let session: Session

    @StateObject private var exportEngine: VideoExportViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var selectedPlatform: PlatformPreset = .instagramReels
    @State private var selectedVisualization: VisualizationMode = .particles
    @State private var customResolution: VideoResolution = .hd1080
    @State private var customQuality: VideoQuality = .high
    @State private var isExporting = false
    @State private var exportProgress: Double = 0.0
    @State private var showingExportedVideo = false
    @State private var exportedVideoURL: URL?
    @State private var showError = false
    @State private var errorMessage = ""

    init(session: Session) {
        self.session = session

        // Initialize export engine
        let device = MTLCreateSystemDefaultDevice()!
        _exportEngine = StateObject(wrappedValue: VideoExportViewModel(device: device))
    }

    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {

                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "video.fill")
                            .font(.system(size: 48))
                            .foregroundColor(.purple)

                        Text("Export Video")
                            .font(.system(size: 24, weight: .bold))

                        Text(session.name)
                            .font(.system(size: 14))
                            .foregroundColor(.secondary)

                        Text(durationString(session.duration))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 20)

                    // Platform Selection
                    platformSelectionSection

                    // Visualization Selection
                    visualizationSelectionSection

                    // Export Progress
                    if isExporting {
                        exportProgressSection
                    }

                    // Export Button
                    if !isExporting {
                        exportButton
                    }

                    // Platform Info
                    platformInfoSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 40)
            }
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarItems(trailing: Button("Done") {
                dismiss()
            })
            .disabled(isExporting)
        }
        .alert("Export Failed", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage)
        }
        .sheet(isPresented: $showingExportedVideo) {
            if let url = exportedVideoURL {
                VideoPreviewView(videoURL: url)
            }
        }
    }

    // MARK: - Platform Selection

    private var platformSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Platform")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    platformCard(.instagramReels, icon: "camera.fill", color: .purple)
                    platformCard(.instagramStory, icon: "text.bubble.fill", color: .pink)
                    platformCard(.tiktok, icon: "music.note", color: .black)
                    platformCard(.youtubeShorts, icon: "play.rectangle.fill", color: .red)
                    platformCard(.youtubeVideo, icon: "play.rectangle", color: .red.opacity(0.7))
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func platformCard(_ platform: PlatformPreset, icon: String, color: Color) -> some View {
        Button(action: { selectedPlatform = platform }) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selectedPlatform == platform ? color : Color.gray.opacity(0.2))
                        .frame(width: 80, height: 80)

                    Image(systemName: icon)
                        .font(.system(size: 32))
                        .foregroundColor(.white)
                }

                Text(platform.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .frame(width: 80)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Visualization Selection

    private var visualizationSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Visualization")
                .font(.system(size: 16, weight: .semibold))
                .foregroundColor(.primary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    visualizationCard(.particles)
                    visualizationCard(.cymatics)
                    visualizationCard(.waveform)
                    visualizationCard(.spectral)
                    visualizationCard(.mandala)
                }
            }
        }
        .padding(.vertical, 8)
    }

    private func visualizationCard(_ mode: VisualizationMode) -> some View {
        Button(action: { selectedVisualization = mode }) {
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(selectedVisualization == mode ? mode.color.opacity(0.3) : Color.gray.opacity(0.1))
                        .frame(width: 70, height: 70)

                    Image(systemName: mode.icon)
                        .font(.system(size: 28))
                        .foregroundColor(selectedVisualization == mode ? mode.color : .gray)
                }

                Text(mode.rawValue)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundColor(.primary)
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Export Progress

    private var exportProgressSection: some View {
        VStack(spacing: 12) {
            Text("Exporting...")
                .font(.system(size: 16, weight: .semibold))

            ProgressView(value: exportProgress)
                .tint(.purple)

            Text("\(Int(exportProgress * 100))%")
                .font(.system(size: 14, design: .monospaced))
                .foregroundColor(.secondary)

            Text("Rendering video frames...")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .padding(20)
        .background(
            RoundedRectangle(cornerRadius: 15)
                .fill(Color.gray.opacity(0.1))
        )
    }

    // MARK: - Export Button

    private var exportButton: some View {
        Button(action: startExport) {
            HStack {
                Image(systemName: "arrow.down.circle.fill")
                    .font(.system(size: 20))
                Text("Export for \(selectedPlatform.displayName)")
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.purple)
            )
        }
        .padding(.vertical, 8)
    }

    // MARK: - Platform Info

    private var platformInfoSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Export Details")
                .font(.system(size: 16, weight: .semibold))

            infoRow(icon: "square.resize", title: "Resolution", value: selectedPlatform.resolution.aspectRatio)
            infoRow(icon: "timer", title: "Max Duration", value: "\(Int(selectedPlatform.maxDuration))s")
            infoRow(icon: "waveform", title: "Audio", value: "Included")
            infoRow(icon: "heart.fill", title: "Bio-Data", value: "Embedded")

            if session.duration > selectedPlatform.maxDuration {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                    Text("Video will be trimmed to \(Int(selectedPlatform.maxDuration))s")
                        .font(.system(size: 12))
                        .foregroundColor(.orange)
                }
                .padding(.top, 8)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.gray.opacity(0.1))
        )
    }

    private func infoRow(icon: String, title: String, value: String) -> some View {
        HStack {
            Image(systemName: icon)
                .font(.system(size: 14))
                .foregroundColor(.secondary)
                .frame(width: 20)

            Text(title)
                .font(.system(size: 14))
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.primary)
        }
    }

    // MARK: - Actions

    private func startExport() {
        isExporting = true
        exportProgress = 0.0

        Task {
            do {
                let videoURL = try await exportEngine.exportVideo(
                    session: session,
                    platform: selectedPlatform,
                    visualizationMode: selectedVisualization,
                    progressCallback: { progress in
                        DispatchQueue.main.async {
                            exportProgress = progress
                        }
                    }
                )

                await MainActor.run {
                    isExporting = false
                    exportedVideoURL = videoURL
                    showingExportedVideo = true
                }
            } catch {
                await MainActor.run {
                    isExporting = false
                    errorMessage = error.localizedDescription
                    showError = true
                }
            }
        }
    }

    // MARK: - Helpers

    private func durationString(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}


// MARK: - Video Export View Model

@MainActor
class VideoExportViewModel: ObservableObject {

    private let device: MTLDevice
    private var compositionEngine: VideoCompositionEngine?

    @Published var isExporting = false
    @Published var exportProgress: Double = 0.0

    init(device: MTLDevice) {
        self.device = device
    }

    func exportVideo(
        session: Session,
        platform: PlatformPreset,
        visualizationMode: VisualizationMode,
        progressCallback: @escaping (Double) -> Void
    ) async throws -> URL {

        // Initialize composition engine
        compositionEngine = VideoCompositionEngine(device: device)

        // Observe progress
        compositionEngine?.$exportProgress
            .sink { progress in
                progressCallback(progress)
            }
            .store(in: &cancellables)

        // Export video
        return try await compositionEngine!.exportForPlatform(
            session: session,
            platform: platform,
            visualizationMode: visualizationMode
        )
    }

    private var cancellables = Set<AnyCancellable>()
}


// MARK: - Video Preview View

struct VideoPreviewView: View {
    let videoURL: URL
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationView {
            VStack {
                Text("Video Exported Successfully!")
                    .font(.system(size: 20, weight: .bold))
                    .padding()

                Text(videoURL.lastPathComponent)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundColor(.secondary)
                    .padding(.bottom, 20)

                // TODO: Add video player here
                // For now, just show the file path

                Spacer()

                // Share button
                ShareLink(item: videoURL) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Share Video")
                            .font(.system(size: 16, weight: .semibold))
                    }
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color.blue)
                    )
                }
                .padding(.horizontal, 20)

                Button(action: { dismiss() }) {
                    Text("Done")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundColor(.blue)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }
                .padding(.horizontal, 20)
            }
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

import Combine
