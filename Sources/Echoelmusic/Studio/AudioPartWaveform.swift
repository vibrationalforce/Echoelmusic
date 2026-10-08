//
//  AudioPartWaveform.swift
//  Echoelmusic — Studio (audio editor W1)
//
//  The waveform inside an audio part's block on the Arrange canvas. `ArrangePartBlock` hands it
//  the part's window (`ArrangeCanvas.AudioWindow`); this leaf reads the file's overview ONCE,
//  off the main actor, and draws the window of it the part plays.
//
//  ⚠️ THE READ IS OFF THE MAIN ACTOR AND CANCELLABLE. `WaveformSketch.overview(ofRef:)` opens
//  and reads a whole file. It runs in `Task.detached`, and the `.task`'s cancellation — the
//  part scrolled away, deleted, or its file changed — is forwarded into it, so an abandoned
//  read stops within one chunk instead of finishing for nobody. The result lands in `@State`
//  once per file: COLD state, never per frame.
//
//  ⚠️ NOTHING HERE IS HOT. The drawing reads the overview and the window, both handed in or
//  read once; no position, no clock, no store. A drag moves the whole block; this leaf redraws
//  only when its size or its window changes (a pinch, a trim, a gain edit).
//
//  ⚠️ IT TAKES NO TOUCHES AND SAYS NOTHING. A tap or a hold on the wave reaches the block —
//  select and drag stay whole — and the block speaks for the part.
//
//  ⭐ W4c — THE FADES ARE DRAWN AS THEY ARE HEARD. Each column is scaled by the part's fade level
//  at its middle (`AudioWindow.fadeLevel`, the player's own rule), and a hairline traces each
//  ramp from silence to full — so a fade reads on the wave, and a part with none is unchanged.
//  The ramps are drawn even while the file is still being read.
//

import SwiftUI

struct AudioPartWaveform: View {

    let window: ArrangeCanvas.AudioWindow
    let tint: Color

    /// The file's overview — nil while it is read, and for a file that cannot be read (then
    /// the block simply stays plain, as before W1).
    @State private var overview: WaveformSketch.Overview?

    var body: some View {
        // Read in `body`, not only inside the renderer, so the landing read re-renders the leaf.
        let overview = self.overview
        let window = self.window
        let tint = self.tint
        Canvas { context, size in
            Self.drawRamps(window, in: &context, size: size, tint: tint)
            guard let overview else { return }
            let columns = WaveformSketch.window(overview, fromSeconds: window.fromSeconds,
                                                lengthSeconds: window.lengthSeconds,
                                                columns: WaveformSketch.columns(forWidthPoints: Double(size.width)),
                                                gain: window.gain)
            guard !columns.isEmpty, size.height > 0 else { return }
            let mid = size.height / 2
            let width = size.width / CGFloat(columns.count)
            var peaks = Path()
            var bodies = Path()
            for (index, column) in columns.enumerated() {
                let x = CGFloat(index) * width
                // W4c: the column at the level its fades leave it, measured at its middle.
                let level = CGFloat(window.fadeLevel(atFraction: (Double(index) + 0.5) / Double(columns.count)))
                let top = mid - CGFloat(column.max) * level * mid
                let bottom = mid - CGFloat(column.min) * level * mid
                // At least a hairline, so silence reads as a flat line rather than a gap.
                peaks.addRect(CGRect(x: x, y: top, width: width, height: Swift.max(Self.hairline, bottom - top)))
                let rms = CGFloat(column.rms) * level * mid
                bodies.addRect(CGRect(x: x, y: mid - rms, width: width, height: rms * 2))
            }
            // Peaks behind, the RMS body in front: the extremes stay visible, the energy reads.
            context.fill(peaks, with: .color(tint.opacity(Self.peakOpacity)))
            context.fill(bodies, with: .color(tint))
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
        .task(id: window.mediaRef) {
            let ref = window.mediaRef
            self.overview = nil
            let reader = Task.detached(priority: .utility) {
                WaveformSketch.overview(ofRef: ref)
            }
            let read = await withTaskCancellationHandler {
                await reader.value
            } onCancel: {
                reader.cancel()
            }
            // A detached hop does not inherit cancellation (`MediaBrowserView`'s note): a read
            // for a file the part no longer plays must not land over the newer one.
            guard !Task.isCancelled else { return }
            self.overview = read
        }
    }

    /// W4c — each fade as a straight line from silence at the part's edge to full height where
    /// the fade ends: the shape the ear hears, drawn over the wave. Nothing for a part without
    /// fades or a block too small to hold a line.
    private nonisolated static func drawRamps(_ window: ArrangeCanvas.AudioWindow, in context: inout GraphicsContext,
                                              size: CGSize, tint: Color) {
        guard size.width > 0, size.height > 0, window.fadeIn > 0 || window.fadeOut > 0 else { return }
        var ramps = Path()
        if window.fadeIn > 0 {
            ramps.move(to: CGPoint(x: 0, y: size.height))
            ramps.addLine(to: CGPoint(x: CGFloat(window.fadeIn) * size.width, y: 0))
        }
        if window.fadeOut > 0 {
            ramps.move(to: CGPoint(x: (1 - CGFloat(window.fadeOut)) * size.width, y: 0))
            ramps.addLine(to: CGPoint(x: size.width, y: size.height))
        }
        context.stroke(ramps, with: .color(tint), lineWidth: Self.rampWidth)
    }

    /// The thinnest a column is drawn — silence is a line, not nothing.
    private static let hairline: CGFloat = 0.5
    /// A fade ramp is a hairline in the track's hue: it marks the shape without hiding the wave.
    private nonisolated static let rampWidth: CGFloat = 1
    /// The peak layer is the track's hue, softened, so the RMS body in full hue reads over it.
    private static let peakOpacity: Double = 0.55
}
