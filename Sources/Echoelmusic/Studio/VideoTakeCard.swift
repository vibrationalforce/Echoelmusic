// VideoTakeCard.swift
// Echoel — One World C1. "Record Video" in the Workstation: a card INSIDE the plate (no modal —
// the presentation chain does not grow) with the rear camera's live preview and one Record / Stop
// button. A finished take is handed to the Workstation, which lands it through the same
// transaction as "Import Video"; this leaf never writes a store.
//
// ⭐ ONE CAMERA OWNER AT A TIME, AND PRODUCTION WINS (founder 2026-10-15: "Biofeedback ist nur ein
// kleines gimmick … hauptfocus auf professionelle Medienproduktion"). The rear lens cannot serve
// the pulse sensor (`CameraCapture`) and the recorder at once, so opening the card STOPS the
// camera pulse and says so; the strap, the Watch and Apple Health keep feeding bio. `isRunning`
// flips on start and stop only — a cold read, and it stays in this leaf (the 10.76.41/50 law).
//
// ⚠️ NOT DEVICE-VERIFIED (preview orientation, the first-frame delay, a take during playback).

#if canImport(AVFoundation) && canImport(UIKit)
import AVFoundation
import SwiftUI
import UIKit

struct VideoTakeCard: View {
    @Environment(CameraRPPGBioPublisher.self) private var cameraRPPG

    /// The Workstation lands the finished file (`VideoImport.perform`) and deletes it after.
    let land: (URL) -> Void
    let close: () -> Void

    @State private var camera: VideoTakeCamera?
    @State private var phase: Phase = .opening
    @State private var startedAt: Date?
    /// The card stopped a running camera pulse to take the lens.
    @State private var pulsePaused = false
    /// Why the last take failed — said above Record, which stays offered for the next take.
    @State private var takeError: String?

    enum Phase: Equatable {
        case opening
        case ready
        case recording
        case saving
        case failed(String)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: EchoelTheme.spaceS) {
            HStack(spacing: EchoelTheme.spaceS) {
                Text("Record Video")
                    .font(EchoelTheme.font(13, .semibold))
                    .foregroundStyle(EchoelTheme.text)
                Spacer(minLength: 0)
                Button { shut() } label: {
                    Image(systemName: "xmark")
                        .font(EchoelTheme.font(12, .semibold))
                        .foregroundStyle(EchoelTheme.dim)
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(phase == .recording || phase == .saving)
                .accessibilityLabel("Close camera")
            }
            ZStack {
                RoundedRectangle(cornerRadius: EchoelTheme.radius).fill(EchoelTheme.bg)
                if let camera, phase == .ready || phase == .recording || phase == .saving {
                    VideoTakePreview(session: camera.session)
                        .clipShape(RoundedRectangle(cornerRadius: EchoelTheme.radius))
                        .accessibilityLabel("Camera preview")
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: 260)
            .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius).stroke(EchoelTheme.border, lineWidth: 1))
            statusLine
            if phase == .ready || phase == .recording {
                Button { phase == .recording ? stop() : record() } label: {
                    Label(phase == .recording ? "Stop" : "Record",
                          systemImage: phase == .recording ? "stop.fill" : "record.circle")
                        .font(EchoelTheme.font(13, .semibold))
                        .foregroundStyle(EchoelTheme.text)
                        .frame(maxWidth: .infinity, minHeight: 44)
                        .background(phase == .recording ? EchoelTheme.recording : EchoelTheme.surface)
                        .clipShape(RoundedRectangle(cornerRadius: EchoelTheme.radius))
                        .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius).stroke(EchoelTheme.border, lineWidth: 1))
                }
                .buttonStyle(.plain)
                .accessibilityHint("The take lands on the video track when you stop")
            }
        }
        .padding(EchoelTheme.spaceM)
        .background(EchoelTheme.surface)
        .clipShape(RoundedRectangle(cornerRadius: EchoelTheme.radius))
        .overlay(RoundedRectangle(cornerRadius: EchoelTheme.radius).stroke(EchoelTheme.border, lineWidth: 1))
        .task { await openCamera() }
        // The camera pulse started while the card is open: it takes the rear lens, so the take
        // ends here and keeps what was recorded, instead of reading "Recording" over nothing.
        .onChange(of: cameraRPPG.isRunning) { _, running in
            if running { pulseTookTheCamera() }
        }
        .onDisappear { leave() }
    }

    @ViewBuilder private var statusLine: some View {
        switch phase {
        case .opening:
            note(Text("Opening the camera…"))
        case .ready:
            if let takeError {
                note(Text(verbatim: takeError))
            } else if pulsePaused {
                note(Text("The camera pulse is paused while the camera records video."))
            } else {
                note(Text("Video only — the sound of the take is the song's own tracks."))
            }
        case .recording:
            if let startedAt {
                TimelineView(.periodic(from: startedAt, by: 1)) { context in
                    note(Text(verbatim: Self.elapsed(from: startedAt, to: context.date)))
                }
            }
        case .saving:
            note(Text("Saving the take…"))
        case .failed(let message):
            note(Text(verbatim: message))
        }
    }

    private func note(_ text: Text) -> some View {
        text
            .font(EchoelTheme.font(11))
            .foregroundStyle(EchoelTheme.dim)
            .fixedSize(horizontal: false, vertical: true)
    }

    /// "Recording 0:07" — minutes and seconds since the take began.
    static func elapsed(from start: Date, to now: Date) -> String {
        let seconds = max(0, Int(now.timeIntervalSince(start)))
        return String(localized: "Recording") + " " + String(format: "%d:%02d", seconds / 60, seconds % 60)
    }

    // MARK: - Actions

    private func openCamera() async {
        if cameraRPPG.isRunning {
            cameraRPPG.stop()
            pulsePaused = true
        }
        let recorder = VideoTakeCamera()
        camera = recorder
        switch await recorder.open() {
        case .success:
            phase = .ready
        case .failure(.denied):
            phase = .failed(String(localized: "Camera access is off. Turn it on in Settings › Echoelmusic."))
        case .failure:
            phase = .failed(String(localized: "The camera could not start."))
        }
    }

    private func record() {
        guard let camera else { return }
        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("echoel-take-\(UUID().uuidString).mov")
        Task { @MainActor in
            if await camera.startRecording(to: url) {
                takeError = nil
                startedAt = Date()
                phase = .recording
            } else {
                takeError = String(localized: "The take could not start.")
            }
        }
    }

    private func stop() {
        guard let camera else { return }
        phase = .saving
        Task { @MainActor in
            switch await camera.stopRecording() {
            case .success(let file):
                startedAt = nil
                if phase == .saving { phase = .ready }   // a pulse that took the lens keeps its word
                land(file)
            case .failure:
                startedAt = nil
                takeError = String(localized: "The take could not be saved.")
                if phase == .saving { phase = .ready }
            }
        }
    }

    /// The camera pulse took the lens mid-card: land what was recorded, then say why it stopped.
    private func pulseTookTheCamera() {
        if phase == .recording { stop() }
        camera?.close()
        phase = .failed(String(localized: "The camera pulse took the camera. Close and reopen to record again."))
    }

    /// Leaving the plate mid-take keeps the take: it is stopped and landed, never left in tmp.
    private func leave() {
        guard let camera else { return }
        if phase == .recording {
            let land = self.land
            Task { @MainActor in
                if case .success(let file) = await camera.stopRecording() { land(file) }
                camera.close()
            }
        } else {
            camera.close()
        }
    }

    private func shut() {
        camera?.close()
        close()
    }
}

/// The rear camera's live picture: `AVCaptureVideoPreviewLayer` as the view's own layer.
private struct VideoTakePreview: UIViewRepresentable {
    let session: AVCaptureSession

    func makeUIView(context: Context) -> VideoTakePreviewView {
        let view = VideoTakePreviewView()
        if let layer = view.layer as? AVCaptureVideoPreviewLayer {
            layer.session = session
            layer.videoGravity = .resizeAspectFill
        }
        return view
    }

    func updateUIView(_ uiView: VideoTakePreviewView, context: Context) {}
}

final class VideoTakePreviewView: UIView {
    override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
}
#endif
