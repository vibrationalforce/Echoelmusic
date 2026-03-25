#if canImport(UIKit) && canImport(SwiftUI)
import UIKit
import SwiftUI

/// Multi-touch instrument surface using UIKit for polyphonic finger tracking.
/// SwiftUI's DragGesture only tracks one touch — UIKit gives us all of them.
/// Each finger maps to an independent synth voice via EchoelSynth.noteOn/noteOff.
struct MultiTouchInstrumentView: UIViewRepresentable {

    let scale: TouchMusicalScale
    let rootNote: UInt8
    let onTouchesChanged: ([ActiveTouch]) -> Void

    /// Represents one active finger on the surface
    struct ActiveTouch: Identifiable {
        let id: ObjectIdentifier
        let location: CGPoint
        let normalizedX: Float  // 0-1
        let normalizedY: Float  // 0-1
        let midiNote: Int
        let noteName: String
    }

    func makeUIView(context: Context) -> InstrumentUIView {
        let view = InstrumentUIView()
        view.isMultipleTouchEnabled = true
        view.backgroundColor = .clear
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ uiView: InstrumentUIView, context: Context) {
        context.coordinator.scale = scale
        context.coordinator.rootNote = rootNote
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(scale: scale, rootNote: rootNote, onTouchesChanged: onTouchesChanged)
    }

    // MARK: - Coordinator (touch → synth bridge)

    @MainActor
    final class Coordinator {
        var scale: TouchMusicalScale
        var rootNote: UInt8
        let onTouchesChanged: ([ActiveTouch]) -> Void
        private var activeTouches: [UITouch: Int] = [:] // UITouch → midiNote
        private static let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]

        init(scale: TouchMusicalScale, rootNote: UInt8, onTouchesChanged: @escaping ([ActiveTouch]) -> Void) {
            self.scale = scale
            self.rootNote = rootNote
            self.onTouchesChanged = onTouchesChanged
        }

        func touchesBegan(_ touches: Set<UITouch>, in view: UIView) {
            for touch in touches {
                let loc = touch.location(in: view)
                let note = noteFromLocation(loc, in: view.bounds.size)
                activeTouches[touch] = note

                EchoelSynth.shared.noteOn(note: note, velocity: velocityFromTouch(touch))
                HapticHelper.impact(.light)
            }
            publishTouches(in: view)
        }

        func touchesMoved(_ touches: Set<UITouch>, in view: UIView) {
            for touch in touches {
                let loc = touch.location(in: view)
                let newNote = noteFromLocation(loc, in: view.bounds.size)
                let oldNote = activeTouches[touch]

                // Y → filter cutoff (per-touch, affects global filter)
                let normalizedY = Float(loc.y / view.bounds.height)
                let cutoff = 200.0 + (1.0 - normalizedY) * 11800.0
                EchoelSynth.shared.config.filterCutoff = cutoff

                // Note changed? Retrigger
                if newNote != oldNote {
                    if let old = oldNote {
                        EchoelSynth.shared.noteOff(note: old)
                    }
                    EchoelSynth.shared.noteOn(note: newNote, velocity: velocityFromTouch(touch))
                    activeTouches[touch] = newNote
                    HapticHelper.impact(.light)
                }
            }
            publishTouches(in: view)
        }

        func touchesEnded(_ touches: Set<UITouch>, in view: UIView) {
            for touch in touches {
                if let note = activeTouches.removeValue(forKey: touch) {
                    EchoelSynth.shared.noteOff(note: note)
                }
            }
            publishTouches(in: view)
        }

        func touchesCancelled(_ touches: Set<UITouch>, in view: UIView) {
            touchesEnded(touches, in: view)
        }

        // MARK: - Helpers

        private func noteFromLocation(_ location: CGPoint, in size: CGSize) -> Int {
            guard size.width > 0 else { return Int(rootNote) }
            let normalizedX = Float(location.x / size.width)
            let totalDegrees = scale.intervals.count * 2 // 2 octaves
            let degree = Int(normalizedX * Float(totalDegrees))
            let midiNote = Int(scale.noteInScale(degree: degree, root: rootNote))
            return max(21, min(108, midiNote))
        }

        private func velocityFromTouch(_ touch: UITouch) -> Float {
            // Use contact radius as velocity proxy (larger contact = harder press)
            // majorRadius typically ranges 3-30 points
            let radius = Float(touch.majorRadius)
            let normalized = (radius - 3.0) / 27.0 // 0-1
            return max(0.3, min(1.0, 0.5 + normalized * 0.5))
        }

        private func publishTouches(in view: UIView) {
            let touches: [ActiveTouch] = activeTouches.compactMap { (touch, note) in
                let loc = touch.location(in: view)
                let name = Self.noteNames[note % 12]
                let octave = (note / 12) - 1
                return ActiveTouch(
                    id: ObjectIdentifier(touch),
                    location: loc,
                    normalizedX: Float(loc.x / view.bounds.width),
                    normalizedY: Float(loc.y / view.bounds.height),
                    midiNote: note,
                    noteName: "\(name)\(octave)"
                )
            }
            onTouchesChanged(touches)
        }
    }

    // MARK: - UIView subclass

    final class InstrumentUIView: UIView {
        weak var delegate: Coordinator?

        override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
            delegate?.touchesBegan(touches, in: self)
        }

        override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
            delegate?.touchesMoved(touches, in: self)
        }

        override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
            delegate?.touchesEnded(touches, in: self)
        }

        override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent?) {
            delegate?.touchesCancelled(touches, in: self)
        }
    }
}
#endif
