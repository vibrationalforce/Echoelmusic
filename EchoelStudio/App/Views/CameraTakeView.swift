import AVFoundation
import EchoelCore
import SwiftUI
import UIKit

/// The camera take, in the one sheet slot (wave W7, C4): the rear camera's picture, Record and
/// Stop. Record plays the song from where it stands and films with it; Stop ends both, and the
/// take lands on the video track at the tick its first frame was heard. While the camera is open
/// the pulse camera waits; it comes back when this sheet closes. The sheet cannot be swiped away
/// while a take is being written, so no take is ever lost to a gesture.
struct CameraTakeView: View {
    /// The video track the take lands on; nil makes one.
    let track: TrackID?
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    @Environment(DocumentController.self) private var documents
    @Environment(CameraPulseSource.self) private var pulse
    @Environment(\.dismiss) private var dismiss
    @State private var recorder = VideoTakeRecorder()

    var body: some View {
        VStack(spacing: Theme.Space.m) {
            preview
            Text(caption)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
                .multilineTextAlignment(.center)
            HStack(spacing: Theme.Space.m) {
                Button("Close") { dismiss() }
                    .buttonStyle(ToolButtonStyle())
                    .disabled(isBusy)
                Spacer(minLength: 0)
                recordButton
            }
        }
        .padding(Theme.Space.m)
        .background(Theme.Color.background)
        .interactiveDismissDisabled(isBusy)
        .onAppear { recorder.open(pulse: pulse, engine: engine, store: store, documents: documents) }
        .onDisappear { recorder.close() }
    }

    @ViewBuilder private var preview: some View {
        if let session = recorder.session, recorder.state != .opening {
            CameraPreview(session: session)
                .aspectRatio(9 / 16, contentMode: .fit)
                .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.large))
                .accessibilityLabel("Camera picture")
        } else {
            RoundedRectangle(cornerRadius: Theme.Radius.large)
                .fill(Theme.Color.background)
                .aspectRatio(9 / 16, contentMode: .fit)
                .accessibilityHidden(true)
        }
    }

    private var recordButton: some View {
        Button {
            if recorder.state == .recording { recorder.stopRecording() } else { recorder.record(onto: track) }
        } label: {
            Label(recorder.state == .recording ? "Stop" : "Record", systemImage: recorder.state == .recording ? "stop.fill" : "record.circle")
        }
        .buttonStyle(ToolButtonStyle(isActive: recorder.state == .recording, activeColor: Theme.Color.record))
        .disabled(recorder.state != .ready && recorder.state != .recording)
        .accessibilityHint("Plays the song and films with it; Stop ends both.")
    }

    private var isBusy: Bool { recorder.state == .recording || recorder.state == .finishing }

    private var caption: String {
        switch recorder.state {
        case .closed, .opening: "Opening the camera…"
        case .ready: "Record plays the song and films with it. The take has no sound of its own: the song's mix is its sound."
        case .recording: "Filming. Stop ends the take and the song."
        case .finishing: "Saving the take…"
        case .denied: "Camera access is off for Echoel. Turn it on in Settings › Privacy › Camera."
        case .unavailable(let reason): reason
        }
    }
}

/// The camera's live picture.
private struct CameraPreview: UIViewRepresentable {
    let session: AVCaptureSession

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
        var previewLayer: AVCaptureVideoPreviewLayer? { layer as? AVCaptureVideoPreviewLayer }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        view.previewLayer?.videoGravity = .resizeAspectFill
        view.previewLayer?.session = session
        return view
    }

    func updateUIView(_ view: PreviewView, context: Context) {
        if view.previewLayer?.session !== session { view.previewLayer?.session = session }
    }
}
