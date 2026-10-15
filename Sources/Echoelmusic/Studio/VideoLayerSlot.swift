// VideoLayerSlot.swift
// Echoel — GMMW VV-5b: the ONE place a playing video's frames enter the visual. Every renderer of
// the field (floating window, external stage) holds this slot as its `footageSource` — set once,
// in `MetalBioView.makeUIView` — and PULLS from it synchronously, in `draw(in:)`, on the main thread.
//
// ⚠️ SCOPE, SAID FIRST: TWO OWNERS ATTACH A VIDEO OUTPUT — the video card's `VideoFootageOwner`
// (VV-6, "Show in Visuals", playing the copy VV-3a keeps) and the picture lane's `VideoLaneAVSink`
// (One World V3a). Since One World V1 the slot says which owner wins: the LAST attach wins, and an owner
// lets go only of its OWN output (`detachVideoOutput(ifAttached:)`) — there is no detach that clears
// whatever happens to be attached. While nothing is attached
// every pull is one lock and a nil, and the picture is exactly the pre-VV-5b field. Not
// device-verified: nothing here may be claimed in store text, on the website or in
// `ContentPipeline/CLAIMS.md` until a device run has seen it.
//
// THE SHAPE — the lock-leaf shape of `TouchRippleChannel` and `AudioFeatureChannel`: one `NSLock`,
// no queue of its own, no task, no timer, no observer, no delegate, nothing observable. A frame moves
// only when a renderer asks for one, on the thread that draws (the 10.76.48 law: never a hop per frame).
// ⚠️ The OWNERS inherit the other half of that law, and this file cannot enforce it for them: a
// closure the VV-6/VV-8 owner hands AVFoundation from a `@MainActor` type (a delegate queue, a
// periodic time observer) is either delivered on `.main` or spelled `@Sendable` — otherwise it traps
// at its entry on a worker (builds 2613/2618, `.claude/rules/swift-audio.md`). Per Apple's docs (the
// iOS 27 surface; the Xcode 26.2 gate is what decides for this build) `AVPlayer` is `@MainActor` and
// `AVPlayerItemVideoOutput` is not, which is why the slot can call the output from here.
//
// ONE PULLER. An output hands each new buffer out ONCE (`hasNewPixelBuffer` turns false after the
// copy), and two renderers can be mounted for one layout pass (the window yielding to the beamer). So
// the slot is the only caller of the output, keeps the latest frame, and serves it to every pull: the
// limiter counts once per DRAW — a second renderer pulling within `VideoFlashLimiter.shortestFrameSeconds`
// of the first shares that draw and its count; the affine is computed per pull, for the caller's aspect.
//
// THE FLASH LAW (VV-4) IS APPLIED HERE, ON THE SAME DRAW, TO WHAT IS SHOWN. A new buffer is read on
// the CPU once — point samples of the Y and CbCr planes, 2 x 2 per limiter cell, converted exactly as
// the shader converts, linearised per sample, averaged into the cells — and cached. On EVERY draw the
// cached cells are scaled by the dial eased for that draw and `VideoFlashLimiter.step` counts them, so
// the limiter sees what the screen shows even while the dial moves between two buffers. The screen
// shows dial x gain x cell; the limiter's shown channels multiply by the gain themselves, so the dial
// has to be in the cells or a dial climbing against falling footage would make reversals no channel
// counts. The count runs before the frame is offered, so the gain rides on the very draw it counted.
// Its clock is the DISPLAY clock (`CACurrentMediaTime`); the limiter's header forbids media time.
// Opacity = eased dial x gain, and the gain is never eased. A buffer that cannot be read fails CLOSED:
// the layer drops on that frame. ⚠️ Because the dial is in the cells, a dial moved back and forth
// faster than about 2.5 Hz is counted like footage flicker (the windows' quarter step) and can hold
// the cap at `VideoFlashLimiter.engagedGain` until it stops — the safe direction, but a surprise.
//
// THE DIAL eases at `VideoFlashLimiter.releasePerSecond` through `FlashGuard.maxDelta`, so a whole
// WCAG step takes 0.4 s and a dial alone cannot flash. Whenever a pull shows nothing — attached with
// no buffer yet, a refused buffer, a viewport or turn the map cannot fit, a frame the renderer could
// not bind (`footageDropped`) — the dial goes back to 0, so the next frame fades in instead of
// appearing at a level it climbed to unseen. A tier block that hides a layer is reported the same
// way. The gap rule is ONE per slot, not per renderer: when NO renderer pulled for
// `VideoFlashLimiter.longestFrameSeconds` (every mount hidden, a remount) the ease restarts at 0; a
// surface hidden and shown again within that time comes back at the eased level, together with its
// own field. A second renderer that mounts while the first keeps pulling joins at the current level,
// and a main-thread hitch over 0.25 s drops the layer to 0 for a frame before it fades back — one
// fall each, both driven by a user action or a stall, neither a rise. A detach snaps off — one step,
// per user action.
//
// THE OUTPUT RECIPE stays inside the keys the Discussion of Apple's `init(outputSettings:)` page names
// for uncompressed output: `kCVPixelBuffer*` plus `AVVideoAllowWideColorKey`. `AVVideoColorPropertiesKey`
// is not among them and is deliberately absent; how the initializer treats any other key (accept,
// ignore or raise) is unmeasured. The shader and `shownLuminance` decode BT.709; whether AVFoundation
// hands a wide-gamut or HDR source over as 8-bit BT.709 under these settings is a device probe, and the
// first-frame breadcrumb prints the matrix and transfer tags the buffer arrived with.
//
// DEVICE PROBES (open, none can be settled here): that `init(outputSettings:)` accepts this recipe;
// whether the output honours the 4:2:0 format and the size cap; what it does with a 601, wide-gamut
// or HDR clip; whether buffers arrive in the track's natural orientation so `preferredTransform`
// turns them upright; memory and heat at 1080p. Not a probe, a note: Apple's docs mark
// `copyPixelBuffer(forItemTime:itemTimeForDisplay:)` deprecated from iOS 27, replaced by
// `pixelBufferAndDisplayTime(forItemTime:)` — a warning on that SDK, not on today's.
// Guard: `TheVideoFrameIsPulledOnTheDrawTests`.

#if canImport(MetalKit) && canImport(UIKit) && canImport(SwiftUI) && canImport(AVFoundation)
import AVFoundation
import CoreGraphics
import CoreVideo
import Foundation
import QuartzCore

/// The three calls the slot makes on a video output. `AVPlayerItemVideoOutput` has them already;
/// the protocol exists so the blocking bundle can drive the whole pull with a stand-in.
protocol VideoFrameOutput: AnyObject {
    func itemTime(forHostTime hostTimeInSeconds: CFTimeInterval) -> CMTime
    func hasNewPixelBuffer(forItemTime itemTime: CMTime) -> Bool
    func copyPixelBuffer(forItemTime itemTime: CMTime,
                         itemTimeForDisplay outItemTimeForDisplay: UnsafeMutablePointer<CMTime>?) -> CVPixelBuffer?
}

extension AVPlayerItemVideoOutput: VideoFrameOutput {}

final class VideoLayerSlot: FootageFrameSource, @unchecked Sendable {

    static let shared = VideoLayerSlot()

    /// Sample points per side of the grid the limiter's cells are averaged from — 2 x 2 points per
    /// cell, half a cell apart. A cell is therefore an ESTIMATE of its mean from four points, not the
    /// mean: a flash smaller than about half a cell can fall between them (`VideoFlashLimiter` header,
    /// "WHAT IT IS NOT").
    static let samplesPerSide = 2 * VideoLayerMath.flashCellsPerSide
    /// The longest side a frame is decoded at; a 4K clip arrives as 1080p.
    static let maxLongSidePixels = 1920.0

    // BT.709 Y'CbCr -> R'G'B', DERIVED from `VideoLayerMath`'s weights (one definition, #416). The
    // MSL footage branch in `MetalBioView` writes the same four numbers as literals rounded to four
    // places; `TheVideoFrameIsPulledOnTheDrawTests` reads them there and holds the two together.
    static let crToRed: Double = 2 * (1 - VideoLayerMath.redWeight)
    static let cbToBlue: Double = 2 * (1 - VideoLayerMath.blueWeight)
    static let cbToGreen: Double = 2 * VideoLayerMath.blueWeight * (1 - VideoLayerMath.blueWeight) / VideoLayerMath.greenWeight
    static let crToGreen: Double = 2 * VideoLayerMath.redWeight * (1 - VideoLayerMath.redWeight) / VideoLayerMath.greenWeight

    private struct Shown {
        let buffer: CVPixelBuffer
        let sequence: UInt64
        let width: Double
        let height: Double
    }

    private let lock = NSLock()
    private let clock: @Sendable () -> Double
    private var output: (any VideoFrameOutput)?
    private var preferredTransform = CGAffineTransform.identity
    /// Never reset by an attach: a strobe cut to another clip stays capped (the safe direction).
    private var limiter = VideoFlashLimiter()
    private var shown: Shown?
    /// The cached frame's cells as decoded — the dial is applied per count, never stored in them.
    private var shownCells: [Double] = []
    /// `shownCells` x the eased dial, reused by every count so a pull allocates nothing.
    private var countedCells: [Double] = []
    /// The same frame's red-flash cells (VV-4c) — cached and counted exactly like the luminance.
    private var shownRedCells: [Double] = []
    private var countedRedCells: [Double] = []
    /// The same frame's linear R, G and B cells (VV-4e) — what the layer can add to the red over any
    /// field; cached and counted exactly like the luminance.
    private var shownColourCells = VideoFlashLimiter.ColourCells(red: [], green: [], blue: [])
    private var countedColourCells = VideoFlashLimiter.ColourCells(red: [], green: [], blue: [])
    /// The limiter's gain from the last count; the limiter is kept across attaches, so is this.
    private var gain = 1.0
    /// Counts every accepted buffer of the process (there is one slot): never 0, never reused, so a
    /// long-lived renderer can never keep an older clip's pair bound under a repeated number.
    private var nextSequence: UInt64 = 0
    private var dialTarget = 0.0
    private var easedDial = 0.0
    private var lastPullSeconds: Double?
    private var samples: [Double] = []
    private var redSamples: [Double] = []
    private var colourSamples: [Double] = []
    private var firstFrameAnnounced = false
    private var refusalAnnounced = false

    /// `clock` is the DISPLAY clock, in seconds; a test hands in its own. The app has one slot.
    init(clock: @escaping @Sendable () -> Double = { CACurrentMediaTime() }) {
        self.clock = clock
    }

    // MARK: - The output (the owner's side — VV-6, then VV-8)

    /// The pixel size an output is asked for: the natural size, scaled down (never up) so the long
    /// side is at most `maxLongSidePixels`, even on both sides. nil for a size that is not finite
    /// and positive — the output then keeps the file's own size.
    static func outputPixelSize(naturalWidth: Double, naturalHeight: Double) -> (width: Int, height: Int)? {
        guard naturalWidth.isFinite, naturalHeight.isFinite, naturalWidth > 0, naturalHeight > 0 else { return nil }
        let scale = Swift.min(1, maxLongSidePixels / Swift.max(naturalWidth, naturalHeight))
        let width = Swift.max(2, Int((naturalWidth * scale / 2).rounded()) * 2)
        let height = Swift.max(2, Int((naturalHeight * scale / 2).rounded()) * 2)
        return (width, height)
    }

    /// The ONE recipe for an output: 4:2:0 bi-planar video range (one of the two formats the
    /// renderer binds), IOSurface-backed and Metal-compatible (zero-copy texture views), no wide
    /// colour, capped in size. Documented keys only — see the header on why there is no colour key.
    static func outputSettings(naturalWidth: Double, naturalHeight: Double) -> [String: any Sendable] {
        var settings: [String: any Sendable] = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
            kCVPixelBufferMetalCompatibilityKey as String: true,
            kCVPixelBufferIOSurfacePropertiesKey as String: [String: any Sendable](),
            AVVideoAllowWideColorKey: false
        ]
        if let size = outputPixelSize(naturalWidth: naturalWidth, naturalHeight: naturalHeight) {
            settings[kCVPixelBufferWidthKey as String] = size.width
            settings[kCVPixelBufferHeightKey as String] = size.height
        }
        return settings
    }

    static func makeVideoOutput(naturalWidth: Double, naturalHeight: Double) -> AVPlayerItemVideoOutput {
        AVPlayerItemVideoOutput(outputSettings: outputSettings(naturalWidth: naturalWidth,
                                                               naturalHeight: naturalHeight))
    }

    /// Shows `output`'s frames in the visual. `preferredTransform` is the video track's own; `dial`
    /// is the user's layer level, 0…1. The layer fades in from 0. Called by the owner, never a body.
    func attachVideoOutput(_ output: any VideoFrameOutput, preferredTransform: CGAffineTransform, dial: Double) {
        lock.lock()
        defer { lock.unlock() }
        self.output = output
        self.preferredTransform = preferredTransform
        dialTarget = dial.clamped(to: 0...1)
        easedDial = 0
        shown = nil
        shownCells = []
        shownRedCells = []
        shownColourCells = VideoFlashLimiter.ColourCells(red: [], green: [], blue: [])
        lastPullSeconds = nil
        firstFrameAnnounced = false
        refusalAnnounced = false
    }

    /// Whether `output` is the one attached now — an owner asks before re-attaching, so a
    /// re-attach never restarts a layer that is already showing (the fade-in).
    func holds(_ output: any VideoFrameOutput) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return self.output === output
    }

    func setDial(_ dial: Double) {
        lock.lock()
        defer { lock.unlock() }
        dialTarget = dial.clamped(to: 0...1)
    }

    /// The layer goes on the next draw — but only while `owned` is the output attached NOW (One
    /// World V1). The rule for the one slot: the LAST attach wins, and each owner can take down only
    /// its own output. So the video card's Hide can never blank a picture lane that attached after
    /// it, and a lane that stops can never blank the card's footage. The limiter is kept (see its
    /// declaration).
    func detachVideoOutput(ifAttached owned: any VideoFrameOutput) {
        lock.lock()
        defer { lock.unlock() }
        guard output === owned else { return }
        output = nil
        shown = nil
        shownCells = []
        shownRedCells = []
        shownColourCells = VideoFlashLimiter.ColourCells(red: [], green: [], blue: [])
        easedDial = 0
        lastPullSeconds = nil
    }

    /// The renderer could not show the frame it pulled (no texture pair for it). The layer was absent
    /// on that draw, so the next draw fades in from 0 — the rule for a refused buffer, applied to a
    /// drop the slot cannot see.
    func footageDropped() {
        lock.lock()
        defer { lock.unlock() }
        easedDial = 0
    }

    // MARK: - The pull (the renderer's side)

    /// Called by `MetalBioRenderer.refreshFootage()` once per draw, per renderer. A NEW buffer is
    /// copied here and nowhere else and cached; the limiter then counts what this draw shows — the
    /// cached cells at the dial eased for THIS pull. Every pull — the first or the second renderer in
    /// one layout pass — gets that same frame, fitted to its own aspect.
    func pullFootageFrame(viewportAspect: Float) -> FootageFrame? {
        lock.lock()
        defer { lock.unlock() }
        guard let output else { return nil }
        let now = clock()
        let itemTime = output.itemTime(forHostTime: now)
        var fresh: CVPixelBuffer?
        if itemTime.isValid, output.hasNewPixelBuffer(forItemTime: itemTime) {
            fresh = output.copyPixelBuffer(forItemTime: itemTime, itemTimeForDisplay: nil)
        }
        let newDraw = easeDialLocked(displaySeconds: now)
        if let fresh { ingestLocked(fresh) }
        // A buffer that reaches the second renderer of a pass is counted at the time of the draw it
        // shares: on its own time the limiter's clock would step by at least its shortest frame.
        if shown != nil, newDraw || fresh != nil {
            countLocked(displaySeconds: newDraw ? now : (lastPullSeconds ?? now))
        }
        return frameLocked(viewportAspect: Double(viewportAspect))
    }

    /// One ease step toward the target, or back to 0 after a gap no renderer pulled across. false =
    /// this pull follows the last by less than `VideoFlashLimiter.shortestFrameSeconds`: the second
    /// renderer of one layout pass. It gets the same dial and is not counted again, so two mounts
    /// never run the limiter's clock ahead of the display's.
    private func easeDialLocked(displaySeconds: Double) -> Bool {
        if let last = lastPullSeconds {
            let dt = displaySeconds - last
            if !dt.isFinite || dt > VideoFlashLimiter.longestFrameSeconds {
                easedDial = 0
            } else if dt < VideoFlashLimiter.shortestFrameSeconds {
                return false
            } else {
                let step = FlashGuard.maxDelta(perSecond: VideoFlashLimiter.releasePerSecond, dt: dt)
                easedDial += (dialTarget - easedDial).clamped(to: -step...step)
            }
        }
        if displaySeconds.isFinite { lastPullSeconds = displaySeconds }
        return true
    }

    /// Decodes and caches a new buffer. A buffer that cannot be read is not shown at all.
    private func ingestLocked(_ buffer: CVPixelBuffer) {
        guard let cells = Self.flashCells(of: buffer, samples: &samples),
              let redCells = Self.redFlashCells(of: buffer, samples: &redSamples),
              let colourCells = Self.colourCells(of: buffer, samples: &colourSamples) else {
            // Fail closed: a frame the limiter cannot count is not shown, and the stale one goes too.
            shown = nil
            if !refusalAnnounced {
                refusalAnnounced = true
                EchoelCrashLog.breadcrumb("video layer: frame refused - not 4:2:0 bi-planar, or unreadable")
            }
            return
        }
        shownCells = cells
        shownRedCells = redCells
        shownColourCells = colourCells
        nextSequence &+= 1
        if nextSequence == 0 { nextSequence = 1 }
        let width = CVPixelBufferGetWidth(buffer)
        let height = CVPixelBufferGetHeight(buffer)
        shown = Shown(buffer: buffer, sequence: nextSequence, width: Double(width), height: Double(height))
        if !firstFrameAnnounced {
            firstFrameAnnounced = true
            let range = CVPixelBufferGetPixelFormatType(buffer) == kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange
                ? "video range" : "full range"
            let matrix = (CVBufferCopyAttachment(buffer, kCVImageBufferYCbCrMatrixKey, nil) as? String) ?? "no matrix tag"
            let transfer = (CVBufferCopyAttachment(buffer, kCVImageBufferTransferFunctionKey, nil) as? String)
                ?? "no transfer tag"
            EchoelCrashLog.breadcrumb("video layer: first frame \(width)x\(height), \(range), \(matrix), \(transfer)")
        }
    }

    /// The limiter counts what the screen shows on this draw: the cached cells x the dial eased for
    /// it. Every draw, not only a new buffer — a dial moving between two buffers changes the picture
    /// too — and the gain it returns rides on that very draw.
    private func countLocked(displaySeconds: Double) {
        if countedCells.count != shownCells.count {
            countedCells = [Double](repeating: 0, count: shownCells.count)
        }
        for index in shownCells.indices { countedCells[index] = shownCells[index] * easedDial }
        if countedRedCells.count != shownRedCells.count {
            countedRedCells = [Double](repeating: 0, count: shownRedCells.count)
        }
        for index in shownRedCells.indices { countedRedCells[index] = shownRedCells[index] * easedDial }
        Self.scale(shownColourCells.red, by: easedDial, into: &countedColourCells.red)
        Self.scale(shownColourCells.green, by: easedDial, into: &countedColourCells.green)
        Self.scale(shownColourCells.blue, by: easedDial, into: &countedColourCells.blue)
        gain = limiter.step(time: displaySeconds, cells: countedCells, redCells: countedRedCells,
                            colourCells: countedColourCells, cellsPerSide: VideoLayerMath.flashCellsPerSide)
    }

    /// `source` x `factor` into `target`, which keeps its storage once it has the right count.
    private static func scale(_ source: [Double], by factor: Double, into target: inout [Double]) {
        if target.count != source.count { target = [Double](repeating: 0, count: source.count) }
        for index in source.indices { target[index] = source[index] * factor }
    }

    /// The cached frame for one caller's aspect. Nothing to show sends the dial back to 0 (header).
    private func frameLocked(viewportAspect: Double) -> FootageFrame? {
        guard let shown,
              let map = Self.viewportToImage(viewportAspect: viewportAspect, bufferWidth: shown.width,
                                             bufferHeight: shown.height, transform: preferredTransform) else {
            easedDial = 0
            return nil
        }
        let opacity = Float((easedDial * gain).clamped(to: 0...1))
        return FootageFrame(pixelBuffer: shown.buffer, sequence: shown.sequence,
                            viewportToImage: map, opacity: opacity)
    }

    // MARK: - Pure arithmetic (driven by the blocking bundle)

    /// The relative luminance the SHADER shows for one Y/Cb/Cr sample (each 0…1, as a texture reads
    /// a byte): range expansion, BT.709 matrix and clamp exactly as in the MSL footage branch, then
    /// `VideoLayerMath.relativeLuminance`, which undoes the same sRGB curve the shader undoes.
    static func shownLuminance(y: Double, cb: Double, cr: Double, videoRange: Bool) -> Double {
        let colour = shownRGB(y: y, cb: cb, cr: cr, videoRange: videoRange)
        return VideoLayerMath.relativeLuminance(red: colour.red, green: colour.green, blue: colour.blue)
    }

    /// The sRGB colour, each 0…1, the SHADER shows for one Y/Cb/Cr sample: range expansion, BT.709
    /// matrix and clamp exactly as in the MSL footage branch. Both measures above read it.
    private static func shownRGB(y: Double, cb: Double, cr: Double,
                                 videoRange: Bool) -> (red: Double, green: Double, blue: Double) {
        let luma: Double
        let blueDifference: Double
        let redDifference: Double
        if videoRange {
            luma = ((y - 16.0 / 255.0) * (255.0 / 219.0)).clamped(to: 0...1)
            blueDifference = (cb - 128.0 / 255.0) * (255.0 / 224.0)
            redDifference = (cr - 128.0 / 255.0) * (255.0 / 224.0)
        } else {
            luma = y.clamped(to: 0...1)
            blueDifference = cb - 128.0 / 255.0
            redDifference = cr - 128.0 / 255.0
        }
        let red = (luma + crToRed * redDifference).clamped(to: 0...1)
        let green = (luma - cbToGreen * blueDifference - crToGreen * redDifference).clamped(to: 0...1)
        let blue = (luma + cbToBlue * blueDifference).clamped(to: 0...1)
        return (red, green, blue)
    }

    /// The red-flash signal the SHADER shows for one Y/Cb/Cr sample (VV-4c): the same decode as
    /// `shownLuminance`, then `VideoLayerMath.redFlashSignal`.
    static func shownRedSignal(y: Double, cb: Double, cr: Double, videoRange: Bool) -> Double {
        let colour = shownRGB(y: y, cb: cb, cr: cr, videoRange: videoRange)
        return VideoLayerMath.redFlashSignal(red: colour.red, green: colour.green, blue: colour.blue)
    }

    /// One LINEAR channel the SHADER shows for one Y/Cb/Cr sample (VV-4e): the same decode as
    /// `shownLuminance`, then `VideoLayerMath.linearComponent`. 0 = red, 1 = green, 2 = blue.
    static func shownLinearChannel(_ channel: Int, y: Double, cb: Double, cr: Double, videoRange: Bool) -> Double {
        let colour = shownRGB(y: y, cb: cb, cr: cr, videoRange: videoRange)
        let component = channel == 0 ? colour.red : (channel == 1 ? colour.green : colour.blue)
        return VideoLayerMath.linearComponent(component)
    }

    /// The limiter's `flashCellsPerSide` x `flashCellsPerSide` cells for one frame: every sample
    /// linearised first, then averaged (averaging encoded values first would under-read a swing).
    /// nil — no frame — for any format the renderer would not bind, or a buffer that cannot be read.
    static func flashCells(of buffer: CVPixelBuffer, samples: inout [Double]) -> [Double]? {
        cells(of: buffer, samples: &samples, measure: shownLuminance)
    }

    /// The same cells of the red-flash signal (VV-4c): every sample decoded to its colour, its
    /// `VideoLayerMath.redFlashSignal` taken in linear light, then averaged — like the luminance.
    static func redFlashCells(of buffer: CVPixelBuffer, samples: inout [Double]) -> [Double]? {
        cells(of: buffer, samples: &samples, measure: shownRedSignal)
    }

    /// The same cells of linear red, green and blue (VV-4e), each sample linearised, then averaged —
    /// a linear sum of these is exact on the means. nil like the two above.
    static func colourCells(of buffer: CVPixelBuffer, samples: inout [Double]) -> VideoFlashLimiter.ColourCells? {
        guard let red = cells(of: buffer, samples: &samples, measure: { shownLinearChannel(0, y: $0, cb: $1, cr: $2, videoRange: $3) }),
              let green = cells(of: buffer, samples: &samples, measure: { shownLinearChannel(1, y: $0, cb: $1, cr: $2, videoRange: $3) }),
              let blue = cells(of: buffer, samples: &samples, measure: { shownLinearChannel(2, y: $0, cb: $1, cr: $2, videoRange: $3) })
        else { return nil }
        return VideoFlashLimiter.ColourCells(red: red, green: green, blue: blue)
    }

    /// The one sampling grid every measure reads, so they can never sample different points.
    private static func cells(of buffer: CVPixelBuffer, samples: inout [Double],
                              measure: (Double, Double, Double, Bool) -> Double) -> [Double]? {
        let videoRange: Bool
        switch CVPixelBufferGetPixelFormatType(buffer) {
        case kCVPixelFormatType_420YpCbCr8BiPlanarFullRange: videoRange = false
        case kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange: videoRange = true
        default: return nil
        }
        guard CVPixelBufferGetPlaneCount(buffer) == 2,
              CVPixelBufferLockBaseAddress(buffer, .readOnly) == kCVReturnSuccess else { return nil }
        defer { CVPixelBufferUnlockBaseAddress(buffer, .readOnly) }
        let lumaWidth = CVPixelBufferGetWidthOfPlane(buffer, 0)
        let lumaHeight = CVPixelBufferGetHeightOfPlane(buffer, 0)
        let chromaWidth = CVPixelBufferGetWidthOfPlane(buffer, 1)
        let chromaHeight = CVPixelBufferGetHeightOfPlane(buffer, 1)
        let lumaStride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 0)
        let chromaStride = CVPixelBufferGetBytesPerRowOfPlane(buffer, 1)
        guard lumaWidth > 0, lumaHeight > 0, chromaWidth > 0, chromaHeight > 0,
              lumaStride >= lumaWidth, chromaStride >= chromaWidth * 2,
              let lumaBase = CVPixelBufferGetBaseAddressOfPlane(buffer, 0),
              let chromaBase = CVPixelBufferGetBaseAddressOfPlane(buffer, 1) else { return nil }
        let side = samplesPerSide
        if samples.count != side * side { samples = [Double](repeating: 0, count: side * side) }
        for row in 0..<side {
            let lumaY = Swift.min(lumaHeight - 1, (2 * row + 1) * lumaHeight / (2 * side))
            let chromaY = Swift.min(chromaHeight - 1, lumaY * chromaHeight / lumaHeight)
            for column in 0..<side {
                let lumaX = Swift.min(lumaWidth - 1, (2 * column + 1) * lumaWidth / (2 * side))
                let chromaX = Swift.min(chromaWidth - 1, lumaX * chromaWidth / lumaWidth)
                let lumaByte = lumaBase.load(fromByteOffset: lumaY * lumaStride + lumaX, as: UInt8.self)
                let chromaOffset = chromaY * chromaStride + chromaX * 2
                let cbByte = chromaBase.load(fromByteOffset: chromaOffset, as: UInt8.self)
                let crByte = chromaBase.load(fromByteOffset: chromaOffset + 1, as: UInt8.self)
                samples[row * side + column] = measure(Double(lumaByte) / 255,
                                                       Double(cbByte) / 255,
                                                       Double(crByte) / 255,
                                                       videoRange)
            }
        }
        return VideoLayerMath.regionMeans(samples, side: side, blocks: VideoLayerMath.flashCellsPerSide)
    }

    /// The renderer's `viewportToImage` for one aspect: normalized viewport (top-left origin) ->
    /// normalized BUFFER coordinates (top-left origin), with the track's turn applied and the shown
    /// picture aspect-fitted (outside 0…1 is letterbox). Built from the transform's a, b, c, d and the
    /// turned rectangle's corners — the file's own tx/ty are not trusted. nil for a viewport, a
    /// buffer or a transform that cannot be inverted. One pure function for every target aspect: the
    /// floating card, the beamer, and — once it has an engine — the stream.
    static func viewportToImage(viewportAspect: Double, bufferWidth: Double, bufferHeight: Double,
                                transform: CGAffineTransform) -> CGAffineTransform? {
        let a = Double(transform.a)
        let b = Double(transform.b)
        let c = Double(transform.c)
        let d = Double(transform.d)
        let determinant: Double = a * d - b * c
        guard viewportAspect.isFinite, viewportAspect > 0, determinant.isFinite, determinant != 0,
              let shownSize = VideoLayerMath.displaySize(width: bufferWidth, height: bufferHeight,
                                                         a: a, b: b, c: c, d: d),
              let fit = VideoLayerMath.aspectFit(contentWidth: shownSize.width, contentHeight: shownSize.height,
                                                 containerWidth: viewportAspect, containerHeight: 1) else {
            return nil
        }
        let cornerX: Double = Swift.min(0, a * bufferWidth, c * bufferHeight, a * bufferWidth + c * bufferHeight)
        let cornerY: Double = Swift.min(0, b * bufferWidth, d * bufferHeight, b * bufferWidth + d * bufferHeight)
        func imagePoint(_ u: Double, _ v: Double) -> (x: Double, y: Double) {
            let shownX: Double = (u * viewportAspect - fit.x) / fit.width * shownSize.width + cornerX
            let shownY: Double = (v - fit.y) / fit.height * shownSize.height + cornerY
            return ((d * shownX - c * shownY) / determinant / bufferWidth,
                    (a * shownY - b * shownX) / determinant / bufferHeight)
        }
        let origin = imagePoint(0, 0)
        let alongX = imagePoint(1, 0)
        let alongY = imagePoint(0, 1)
        let map = CGAffineTransform(a: alongX.x - origin.x, b: alongX.y - origin.y,
                                    c: alongY.x - origin.x, d: alongY.y - origin.y,
                                    tx: origin.x, ty: origin.y)
        guard map.a.isFinite, map.b.isFinite, map.c.isFinite, map.d.isFinite,
              map.tx.isFinite, map.ty.isFinite else { return nil }
        return map
    }
}
#endif
