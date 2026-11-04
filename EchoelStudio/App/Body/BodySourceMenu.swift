import SwiftUI

/// The body-source chooser in the Song menu (wave W1): Off, the chest strap, the rear camera, or
/// Apple Health (REC-1, what an Apple Watch measured).
/// One source at a time — choosing one stops the other, so the lens and the strap never both feed
/// the same modulation cells (one producer per source). Off is its own explicit entry, so turning
/// the body off is a choice the musician can see, not the absence of one.
///
/// A leaf on purpose: it reads `isOn` of both sources, which changes only when the musician
/// chooses, and the Song menu around it reads neither (Law 6).
struct BodySourceMenu: View {
    @Environment(HeartRateStrap.self) private var strap
    @Environment(CameraPulseSource.self) private var camera
    @Environment(HealthHeartRate.self) private var health
    @Environment(PhoneMotionSource.self) private var phoneMotion

    var body: some View {
        Menu("Body Source", systemImage: "heart") {
            Button {
                strap.stop()
                camera.stop()
                health.stop()
                phoneMotion.stop()
            } label: {
                choice("Off", chosen: !strap.isOn && !camera.isOn && !health.isOn && !phoneMotion.isOn)
            }
            Button {
                camera.stop()
                health.stop()
                strap.start()
            } label: {
                choice("Heart Rate Strap", chosen: strap.isOn)
            }
            // The rear camera reads the pulse from a fingertip over the lens and flash; the frames
            // never leave the device.
            Button {
                strap.stop()
                health.stop()
                camera.start()
            } label: {
                choice("Camera (fingertip on the rear lens)", chosen: camera.isOn)
            }
            // Apple Health: read only, never written, never sent off the device. A Watch reading is
            // seconds late, so it modulates slowly and never sets the beat — the caption says so.
            Button {
                strap.stop()
                camera.stop()
                health.start()
            } label: {
                choice("Apple Health (Apple Watch)", chosen: health.isOn,
                       caption: "Arrives 4–5 s late: slow modulation only, never the beat. Read only, stays on this iPhone.")
            }
            // The phone itself, beside whichever pulse source is chosen: it feeds other sources
            // (tilt, turning, movement), so it is a switch of its own rather than a fifth choice.
            Divider()
            Button {
                if phoneMotion.isOn { phoneMotion.stop() } else { phoneMotion.start() }
            } label: {
                choice("Phone Motion", chosen: phoneMotion.isOn,
                       caption: phoneMotion.status == .unavailable ? "This device has no motion sensors."
                           : "Tilt, turning and movement of this iPhone, beside the pulse source.")
            }
        }
    }

    @ViewBuilder
    private func choice(_ title: String, chosen: Bool, caption: String? = nil) -> some View {
        if chosen {
            Label(title, systemImage: "checkmark")
        } else {
            Text(title)
        }
        // A menu row shows a second text as its subtitle.
        if let caption { Text(caption) }
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
