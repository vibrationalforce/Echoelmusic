import SwiftUI

/// The body-source chooser in the Song menu (wave W1): Off, the chest strap, or the rear camera.
/// One source at a time — choosing one stops the other, so the lens and the strap never both feed
/// the same modulation cells (one producer per source). Off is its own explicit entry, so turning
/// the body off is a choice the musician can see, not the absence of one.
///
/// A leaf on purpose: it reads `isOn` of both sources, which changes only when the musician
/// chooses, and the Song menu around it reads neither (Law 6).
struct BodySourceMenu: View {
    @Environment(HeartRateStrap.self) private var strap
    @Environment(CameraPulseSource.self) private var camera

    var body: some View {
        Menu("Body Source", systemImage: "heart") {
            Button {
                strap.stop()
                camera.stop()
            } label: {
                choice("Off", chosen: !strap.isOn && !camera.isOn)
            }
            Button {
                camera.stop()
                strap.start()
            } label: {
                choice("Heart Rate Strap", chosen: strap.isOn)
            }
            // The rear camera reads the pulse from a fingertip over the lens and flash; the frames
            // never leave the device.
            Button {
                strap.stop()
                camera.start()
            } label: {
                choice("Camera (fingertip on the rear lens)", chosen: camera.isOn)
            }
        }
    }

    @ViewBuilder
    private func choice(_ title: String, chosen: Bool) -> some View {
        if chosen {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
    }
}

/// The camera's acquisition cue under the transport, as its own leaf (Law 6): what the finger
/// should do, or why the camera is not reading. Nothing while the camera is off or a pulse is
/// locked; the cue changes at most a few times a second and only when its words change.
struct CameraPulseCueLine: View {
    @Environment(CameraPulseSource.self) private var camera

    var body: some View {
        if let line = Self.line(for: camera.status, cue: camera.cue) {
            Text(line)
                .font(Theme.Font.caption)
                .foregroundStyle(Theme.Color.textSecondary)
                .padding(.bottom, Theme.Space.xs)
        }
    }

    static func line(for status: CameraPulseSource.Status, cue: PulseCue) -> String? {
        switch status {
        case .off: nil
        case .unavailable(let reason): reason
        case .denied: PulseCue.cameraDenied.fullHint
        case .starting: "Opening the camera."
        case .measuring: cue == .locked ? nil : "Camera: \(cue.fullHint)"
        case .interrupted: "iOS paused the camera. It resumes when the camera is free again."
        }
    }
}
