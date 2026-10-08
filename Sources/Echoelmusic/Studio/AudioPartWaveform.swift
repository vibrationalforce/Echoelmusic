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
                let top = mid - CGFloat(column.max) * mid
                let bottom = mid - CGFloat(column.min) * mid
                // At least a hairline, so silence reads as a flat line rather than a gap.
                peaks.addRect(CGRect(x: x, y: top, width: width, height: Swift.max(Self.hairline, bottom - top)))
                let rms = CGFloat(column.rms) * mid
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

    /// The thinnest a column is drawn — silence is a line, not nothing.
    private static let hairline: CGFloat = 0.5
    /// The peak layer is the track's hue, softened, so the RMS body in full hue reads over it.
    private static let peakOpacity: Double = 0.55
}
