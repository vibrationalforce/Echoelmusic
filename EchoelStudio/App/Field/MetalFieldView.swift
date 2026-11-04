#if canImport(MetalKit) && canImport(UIKit)
import EchoelCore
import EchoelDSP
import Foundation
import MetalKit
import SwiftUI
import UIKit

/// Whether this device draws the Field on the GPU. Asked once: the system device does not come
/// and go. Without one (a simulator without Metal) `FieldCanvasView` draws the same frame.
enum MetalField {
    static let isAvailable: Bool = MTLCreateSystemDefaultDevice() != nil
}

/// The Field on the GPU (wave W3): the proven core of the earlier app's renderer — an `MTKView` at
/// a pinned 60 frames a second, a full-screen fragment shader compiled at runtime, uniforms eased
/// on the CPU so nothing ever snaps — fed by the ONE `FieldFrame` snapshot (the song's beat, bar,
/// key and level; the body's pulse, HRV, coherence and breath). The renderer reads that snapshot
/// in its own draw loop, off the SwiftUI graph: nothing here observes a hot value (Law 6).
///
/// Three laws from the earlier app's device rounds, kept on purpose:
/// - The frame rate is never a lever. Heat and power shed detail (`FieldDetail`): the drawable's
///   pixel count and the ring count; at the lowest level the picture holds still.
/// - The drawable is never re-allocated mid-animation (`autoResizeDrawable` off, settled sizes).
/// - The drawable presents inside the current transaction, so a window composited with SwiftUI
///   never beats against the compositor's cadence.
struct MetalFieldView: UIViewRepresentable {
    @Environment(ProjectStore.self) private var store
    @Environment(AudioEngine.self) private var engine
    /// The system's Reduce Motion, read by the SwiftUI parent and handed down cold.
    let reduceMotion: Bool
    /// The picture the musician chose, handed down cold like Reduce Motion.
    var pattern: FieldPattern = .rings
    /// The look blended over it (nil: none) and its share, 0 … 1 — cold too.
    var partner: FieldPattern?
    var mix: Double = 0

    func makeCoordinator() -> MetalFieldRenderer { MetalFieldRenderer() }

    func makeUIView(context: Context) -> MTKView {
        let view = MTKView()
        if let device = MTLCreateSystemDefaultDevice() {
            view.device = device
            context.coordinator.configure(device: device)
        }
        view.delegate = context.coordinator
        view.clearColor = MetalFieldRenderer.ground
        // The shader computes linear light; the sRGB drawable encodes it on write.
        view.colorPixelFormat = .bgra8Unorm_srgb
        // Nothing reads the texture back: the fast path, permanently.
        view.framebufferOnly = true
        view.preferredFramesPerSecond = FieldDetail.frameRate
        view.isPaused = false
        view.enableSetNeedsDisplay = false
        view.isOpaque = true
        // The renderer sizes the drawable itself, once a size has settled (see `settleDrawable`).
        view.autoResizeDrawable = false
        view.presentsWithTransaction = true
        // Touches belong to the SwiftUI window around the picture.
        view.isUserInteractionEnabled = false
        // The battery level is a detail input; iOS reports it only while asked to.
        UIDevice.current.isBatteryMonitoringEnabled = true
        FieldMemory.observe()
        return view
    }

    func updateUIView(_ view: MTKView, context: Context) {
        // Only references and cold settings cross here. The live values are read in `draw(in:)`,
        // so this representable and its parents are never rebuilt by the playhead or the body.
        let renderer = context.coordinator
        renderer.store = store
        renderer.engine = engine
        renderer.reduceMotion = reduceMotion
        renderer.setLooks(primary: pattern, partner: partner, mix: mix)
    }

    /// The view goes: the renderer stops asking the engine for the spectrum.
    static func dismantleUIView(_ view: MTKView, coordinator: MetalFieldRenderer) {
        coordinator.setLooks(primary: .rings, partner: nil, mix: 0)
    }
}

/// Owns the command queue and the pipeline and renders each frame. `MTKView` calls the delegate on
/// the main thread (its display link), so the snapshot is read under `MainActor.assumeIsolated`.
/// When iOS last warned that memory runs short, for the detail level (`FieldDetail.level`). One
/// observer for the process, set up by the first Field; it touches only this stamp, so its block
/// (NS_SWIFT_SENDABLE, delivered on the main queue) captures no renderer.
@MainActor
enum FieldMemory {
    static private(set) var warnedAt: CFAbsoluteTime = -.infinity
    private static var observer: NSObjectProtocol?

    static func observe() {
        guard observer == nil else { return }
        observer = NotificationCenter.default.addObserver(
            forName: UIApplication.didReceiveMemoryWarningNotification, object: nil, queue: .main
        ) { _ in
            MainActor.assumeIsolated {
                FieldMemory.warnedAt = CFAbsoluteTimeGetCurrent()
                DiagnosticLog.app.note("field: memory warning, detail down")
            }
        }
    }
}

final class MetalFieldRenderer: NSObject, MTKViewDelegate {
    /// `Theme.Color.background` (black) as Metal's clear colour: the ground the Field draws on.
    /// The other clear colour here, the no-shader grey, is computed from the centre light (data).
    nonisolated static let ground = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)

    /// The numbers the shader reads. Mirrored by BYTE LAYOUT, not by name, in the MSL `Uniforms`
    /// struct of `FieldShader.field` (EchoelCore) — no compiler checks the two agree, so a field is only ever
    /// appended at the end, in both places, in one commit.
    private struct Uniforms {
        var aspect: Float = 1
        var beatPhase: Float = 0
        var fieldPhase: Float = 0
        var pulsePhase: Float = 0
        var beatLight: Float = 0
        var centreLight: Float = 0
        var levelLight: Float = 0
        var coherence: Float = 0.5
        var breath: Float = 0.5
        var toneHz: Float = Float(FieldFrame.middleC)
        var density: Float = Float(FieldMotion.ringDensity)
        var hasPulse: Float = 0
        var hasCoherence: Float = 0

        init() {}

        /// One frame of `FieldMotion`, at the drawable's `aspect`.
        init(aspect: Float, shown: FieldMotion.Shown) {
            self.aspect = aspect
            beatPhase = Float(shown.beatPhase)
            fieldPhase = Float(shown.fieldPhase)
            pulsePhase = Float(shown.pulsePhase)
            beatLight = Float(shown.beatLight)
            centreLight = Float(shown.centreLight)
            levelLight = Float(shown.levelLight)
            coherence = Float(shown.coherence)
            breath = Float(shown.breath)
            toneHz = Float(shown.toneHz)
            density = Float(shown.density)
            hasPulse = shown.hasPulse ? 1 : 0
            hasCoherence = shown.hasCoherence ? 1 : 0
        }
    }

    /// The Chladni plate's numbers, read by the shader at buffer 1 — mirrored by BYTE LAYOUT in the
    /// MSL `Chladni` struct (six `float4`, then four `float`): changed in both places in one commit.
    /// `active` 0 draws the rings, so every pass binds one, the rings' passes a zero one.
    private struct ChladniUniforms {
        var fromM = SIMD4<Float>(repeating: 0)
        var fromN = SIMD4<Float>(repeating: 0)
        var fromW = SIMD4<Float>(repeating: 0)
        var toM = SIMD4<Float>(repeating: 0)
        var toN = SIMD4<Float>(repeating: 0)
        var toW = SIMD4<Float>(repeating: 0)
        var active: Float = 0
        var mix: Float = 1
        var light: Float = 0
        var grains: Float = 0

        init() {}

        /// One frame of `ChladniMotion` with `grains` sand grains along each side of the plate.
        init(_ shown: ChladniMotion.Shown, grains: Double) {
            fromM = SIMD4<Float>(shown.from.m)
            fromN = SIMD4<Float>(shown.from.n)
            fromW = SIMD4<Float>(shown.from.weight)
            toM = SIMD4<Float>(shown.to.m)
            toN = SIMD4<Float>(shown.to.n)
            toW = SIMD4<Float>(shown.to.weight)
            active = 1
            mix = Float(shown.mix)
            light = Float(shown.light)
            self.grains = Float(grains)
        }
    }

    /// The looks' numbers, read by the shader at buffer 2 — mirrored by BYTE LAYOUT in the MSL
    /// `Look` struct (eight `float`): changed in both places in one commit. All zero draws the
    /// rings alone, which is what the video layer's pass binds.
    private struct LookUniforms {
        var primary: Float = 0
        var partner: Float = 0
        var blend: Float = 0
        var phaseOffset: Float = 0
        var soundHz: Float = 0
        var dishK: Float = 0
        var dishStrength: Float = 0
        var dishHex: Float = 0

        init() {}

        /// One frame of `FieldLookMotion`.
        init(_ shown: FieldLookMotion.Shown) {
            primary = Float(shown.primary.shaderIndex)
            partner = Float(shown.partner.shaderIndex)
            blend = Float(shown.mix)
            phaseOffset = Float(shown.phaseOffset)
            soundHz = Float(shown.soundHz)
            dishK = Float(shown.dishK)
            dishStrength = Float(shown.dishStrength)
            dishHex = Float(shown.dishHex)
        }
    }

    /// Sand grains along one side of the plate at full detail: 180 × 180 ≈ 32 000 grains, one per
    /// cell of the grid the shader lays over the plate. The detail level scales the side
    /// (`FieldDetail.patternScale`): about 16 000 grains at low, 8 000 at minimal.
    static let grainsPerSide = 180.0

    weak var store: ProjectStore?
    weak var engine: AudioEngine?
    var reduceMotion = false
    private(set) var pattern: FieldPattern = .rings
    private var partner: FieldPattern?
    private var mixShare = 0.0
    private weak var listeningTo: AudioEngine?
    private var look = LookUniforms()
    private var lastEncodedLook = LookUniforms()
    private var lookMotion = FieldLookMotion()
    private var chladni = ChladniUniforms()
    private var lastEncodedChladni = ChladniUniforms()
    private var chladniMotion = ChladniMotion()
    /// The master's partials as last read on the main thread, for this frame's plate.
    private var peaks = SpectralPeaks.silent

    /// Switches the picture and its blend; every look but the rings listens to the master while it
    /// is drawn, and only then.
    @MainActor
    func setLooks(primary: FieldPattern, partner next: FieldPattern?, mix: Double) {
        if pattern != primary {
            pattern = primary
            chladniMotion = ChladniMotion()
            DiagnosticLog.app.note("field: pattern", [("look", primary.shaderIndex)])
        }
        if partner != next {
            partner = next
            DiagnosticLog.app.note("field: blend", [("look", next?.shaderIndex ?? -1)])
        }
        mixShare = mix.isFinite ? Swift.min(Swift.max(mix, 0), 1) : 0
        let listens = primary.listensToSound || (next?.listensToSound ?? false)
        let wanted = listens ? engine : nil
        if listeningTo !== wanted {
            listeningTo?.listenForSpectrum(false, by: ObjectIdentifier(self))
            wanted?.listenForSpectrum(true, by: ObjectIdentifier(self))
            listeningTo = wanted
        }
    }

    private var commandQueue: MTLCommandQueue?
    private var pipeline: MTLRenderPipelineState?
    /// Compiled once per process and per device: every window and the fullscreen share it. Only a
    /// successful build is cached, so a failed compile is logged again rather than frozen in.
    nonisolated(unsafe) private static var sharedPipeline: MTLRenderPipelineState?
    nonisolated(unsafe) private static var sharedPipelineDevice: MTLDevice?

    private var uniforms = Uniforms()
    private var lastEncoded = Uniforms()
    private var hasEncodedOnce = false
    private var frame = FieldFrame()
    private var lastFrameTime = CFAbsoluteTimeGetCurrent()

    /// The clocks, the flash guards and the glides (EchoelCore `FieldMotion`: pure, tested) — the
    /// same motion the video export steps through, frame by frame.
    private var motion = FieldMotion()

    // Detail: sampled once a second from heat, power and the frame rate this loop achieves.
    private var detail = FieldDetail(level: .full)
    private var candidateLevel: FieldDetail.Level = .full
    private var candidateSamples = 0
    private var framesInWindow = 0
    private var windowStart = CFAbsoluteTimeGetCurrent()

    // Settled-size drawable management.
    private var pendingDrawableSize = CGSize.zero
    private var pendingStableFrames = 0
    private var lastResolutionScale: CGFloat = 1

    func configure(device: MTLDevice) {
        commandQueue = device.makeCommandQueue()
        pipeline = Self.pipeline(for: device)
    }

    /// The Field's pipeline on `device`, compiled once per process and per device and shared by
    /// every window, the live stream and the video layer (W15). Nil when the shader does not build;
    /// the reason is in the log. Call it on the main thread, where the cache is kept.
    static func pipeline(for device: MTLDevice) -> MTLRenderPipelineState? {
        if let cached = sharedPipeline, sharedPipelineDevice === device {
            DiagnosticLog.app.note("field: shader reused")
            return cached
        }
        // The MSL is EchoelCore's `FieldShader`, which the gate compiles (FieldShaderTests); on the
        // device only this line and the picture say that it failed, so both speak before the step.
        DiagnosticLog.app.note("field: shader compiling")
        let library: MTLLibrary
        do {
            library = try device.makeLibrary(source: FieldShader.field.source, options: nil)
        } catch {
            DiagnosticLog.app.note("field: shader compile failed, flat picture", error: error)
            return nil
        }
        guard let vertex = library.makeFunction(name: FieldShader.field.vertexFunction),
              let fragment = library.makeFunction(name: FieldShader.field.fragmentFunction) else {
            DiagnosticLog.app.note("field: shader entry point missing, flat picture")
            return nil
        }
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.vertexFunction = vertex
        descriptor.fragmentFunction = fragment
        descriptor.colorAttachments[0].pixelFormat = .bgra8Unorm_srgb
        do {
            let built = try device.makeRenderPipelineState(descriptor: descriptor)
            sharedPipeline = built
            sharedPipelineDevice = device
            DiagnosticLog.app.note("field: shader ready")
            return built
        } catch {
            DiagnosticLog.app.note("field: pipeline failed, flat picture", error: error)
            return nil
        }
    }

    /// Draws one Field frame from `shown` into `texture` on `buffer`, cleared to the ground: the
    /// video layer's Field (W15) — the export's from its computed motion, the preview's from its
    /// own — with the window's pipeline and shader, at the texture's size and `aspect`. False when
    /// the pass could not be encoded. Any thread: it touches only what it is handed.
    nonisolated static func encode(_ shown: FieldMotion.Shown, aspect: Float, pipeline: MTLRenderPipelineState,
                                   into texture: MTLTexture, on buffer: MTLCommandBuffer) -> Bool {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        pass.colorAttachments[0].clearColor = ground
        guard let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) else { return false }
        encoder.setRenderPipelineState(pipeline)
        var sent = Uniforms(aspect: aspect, shown: shown)
        var plate = ChladniUniforms()
        var looks = LookUniforms()
        encoder.setVertexBytes(&sent, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.setFragmentBytes(&sent, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.setFragmentBytes(&plate, length: MemoryLayout<ChladniUniforms>.stride, index: 1)
        encoder.setFragmentBytes(&looks, length: MemoryLayout<LookUniforms>.stride, index: 2)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        return true
    }

    func mtkView(_ view: MTKView, drawableSizeWillChange size: CGSize) {
        uniforms.aspect = size.height > 0 ? Float(size.width / size.height) : 1
    }

    func draw(in view: MTKView) {
        let now = CFAbsoluteTimeGetCurrent()
        // Real elapsed time, clamped after a stall, so every easing is frame-rate independent.
        let seconds = Swift.min(Swift.max(now - lastFrameTime, 0), 0.1)
        lastFrameTime = now

        // The display link calls this on the main thread: the snapshot, the device readings and
        // the drawable's size are read there, off the SwiftUI graph.
        MainActor.assumeIsolated {
            if let store, let engine {
                frame = FieldFrame.current(store: store, engine: engine)
            }
            peaks = listeningTo?.fieldSpectrum.peaks ?? .silent
            sampleDevice(at: now)
            settleDrawable(of: view)
        }

        step(seconds: seconds)

        // The picture cannot have changed: skip the pass and leave the last frame on the layer.
        // Not a pause — the display link keeps its cadence, and the next change encodes at once.
        if hasEncodedOnce, Self.bytesEqual(uniforms, lastEncoded), Self.bytesEqual(chladni, lastEncodedChladni),
           Self.bytesEqual(look, lastEncodedLook) { return }

        guard let drawable = view.currentDrawable,
              let pass = view.currentRenderPassDescriptor,
              let queue = commandQueue,
              let buffer = queue.makeCommandBuffer() else { return }
        // Recorded after the guard: a frame without a drawable was not shown.
        lastEncoded = uniforms
        lastEncodedChladni = chladni
        lastEncodedLook = look
        hasEncodedOnce = true

        if let pipeline, let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) {
            encoder.setRenderPipelineState(pipeline)
            var sent = uniforms
            var plate = chladni
            var looks = look
            encoder.setVertexBytes(&sent, length: MemoryLayout<Uniforms>.stride, index: 0)
            encoder.setFragmentBytes(&sent, length: MemoryLayout<Uniforms>.stride, index: 0)
            encoder.setFragmentBytes(&plate, length: MemoryLayout<ChladniUniforms>.stride, index: 1)
            encoder.setFragmentBytes(&looks, length: MemoryLayout<LookUniforms>.stride, index: 2)
            encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
            encoder.endEncoding()
        } else {
            // No shader: a calm, guarded grey from the centre light, never a crash.
            let glow = 0.01 + 0.05 * Double(uniforms.centreLight)
            pass.colorAttachments[0].clearColor = MTLClearColor(red: glow, green: glow, blue: glow, alpha: 1)
            buffer.makeRenderCommandEncoder(descriptor: pass)?.endEncoding()
        }

        // Synchronous present in the current transaction (`presentsWithTransaction`): commit, wait
        // until scheduled, present the drawable itself — never `buffer.present(drawable)`.
        buffer.commit()
        buffer.waitUntilScheduled()
        drawable.present()
    }

    /// Advances the motion by `seconds` and sets this frame's uniforms from `frame` — the one
    /// computation the window and the live stream share (`FieldMotion`, which the video export
    /// steps too). Under Reduce Motion or at the lowest detail the picture holds still.
    private func step(seconds: Double) {
        let still = reduceMotion || detail.isStill
        let shown = motion.step(frame, after: seconds, still: still, patternScale: detail.patternScale)
        uniforms = Uniforms(aspect: uniforms.aspect, shown: shown)
        // The looks hear the master's strongest partials — pitch and drive — and blend two looks,
        // the share and the lattice's light flash-guarded (EchoelCore `FieldLookMotion`: tested).
        let heard = FieldLookMotion.hearing(frequencies: peaks.frequencies, amplitudes: peaks.amplitudes, count: peaks.count)
        let looks = lookMotion.step(primary: pattern, partner: partner, mix: mixShare, hertz: heard.hertz,
                                    drive: heard.drive, tonicHz: frame.tonicHz, fieldPhase: shown.fieldPhase,
                                    after: seconds, still: still, patternScale: detail.patternScale)
        look = LookUniforms(looks)
        guard looks.primary == .chladni || looks.partner == .chladni else {
            chladni = ChladniUniforms()
            return
        }
        // The plate hears the master's strongest partials (the tap's thread analyses them; this
        // reads the last result) and cross-fades to the figure they choose (EchoelCore: tested).
        let target = ChladniPlate.modes(frequencies: peaks.frequencies, amplitudes: peaks.amplitudes, count: peaks.count)
        let plate = chladniMotion.step(towards: target, after: seconds, still: still)
        chladni = ChladniUniforms(plate, grains: (Self.grainsPerSide * detail.patternScale).rounded())
    }

    /// Draws the next frame into `texture` — the live stream's picture (wave W14): the same
    /// snapshot, clocks, flash guards and shader as the window, at the texture's own size and
    /// aspect, so a 9:16, 16:9, 1:1 or 4:5 frame is the same Field framed for its shape. Commits and
    /// returns at once; `completed` runs on Metal's thread when the GPU has written the texture.
    /// False when nothing was encoded (no queue yet). Never in the background: iOS refuses GPU work there.
    @MainActor
    func render(into texture: MTLTexture, completed: @escaping @Sendable () -> Void) -> Bool {
        let now = CFAbsoluteTimeGetCurrent()
        let seconds = Swift.min(Swift.max(now - lastFrameTime, 0), 0.1)
        lastFrameTime = now
        if let store, let engine {
            frame = FieldFrame.current(store: store, engine: engine)
        }
        peaks = listeningTo?.fieldSpectrum.peaks ?? .silent
        uniforms.aspect = texture.height > 0 ? Float(texture.width) / Float(texture.height) : 1
        step(seconds: seconds)
        guard let queue = commandQueue, let buffer = queue.makeCommandBuffer() else { return false }
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = texture
        pass.colorAttachments[0].loadAction = .clear
        pass.colorAttachments[0].storeAction = .store
        if let pipeline {
            pass.colorAttachments[0].clearColor = MetalFieldRenderer.ground
            if let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) {
                encoder.setRenderPipelineState(pipeline)
                var sent = uniforms
                var plate = chladni
                var looks = look
                encoder.setVertexBytes(&sent, length: MemoryLayout<Uniforms>.stride, index: 0)
                encoder.setFragmentBytes(&sent, length: MemoryLayout<Uniforms>.stride, index: 0)
                encoder.setFragmentBytes(&plate, length: MemoryLayout<ChladniUniforms>.stride, index: 1)
                encoder.setFragmentBytes(&looks, length: MemoryLayout<LookUniforms>.stride, index: 2)
                encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
                encoder.endEncoding()
            }
        } else {
            let glow = 0.01 + 0.05 * Double(uniforms.centreLight)
            pass.colorAttachments[0].clearColor = MTLClearColor(red: glow, green: glow, blue: glow, alpha: 1)
            buffer.makeRenderCommandEncoder(descriptor: pass)?.endEncoding()
        }
        // @Sendable: formed on the main actor, run on Metal's thread — without it the closure would
        // carry a main-actor check into that thread and trap there.
        buffer.addCompletedHandler { @Sendable _ in completed() }
        buffer.commit()
        return true
    }

    /// Once a second: the frame rate this loop achieved, the heat and the power → the detail
    /// level. A new level is taken only when two samples in a row agree, so the picture does not
    /// hunt between two levels at the frame-rate edge.
    @MainActor
    private func sampleDevice(at now: CFAbsoluteTime) {
        framesInWindow += 1
        let elapsed = now - windowStart
        guard elapsed >= 1 else { return }
        let measured = Double(framesInWindow) / elapsed
        framesInWindow = 0
        windowStart = now
        let info = ProcessInfo.processInfo
        let thermal: FieldDetail.Thermal = switch info.thermalState {
        case .nominal: .nominal
        case .fair: .fair
        case .serious: .serious
        case .critical: .critical
        @unknown default: .serious
        }
        let device = UIDevice.current
        let charging = device.batteryState == .charging || device.batteryState == .full
        let level = FieldDetail.level(thermal: thermal, lowPower: info.isLowPowerModeEnabled,
                                      batteryLevel: Double(device.batteryLevel), charging: charging,
                                      measuredFrameRate: measured,
                                      memoryWarned: now - FieldMemory.warnedAt < FieldDetail.memoryWarningSeconds)
        if level == candidateLevel {
            candidateSamples += 1
        } else {
            candidateLevel = level
            candidateSamples = 1
        }
        guard level != detail.level, candidateSamples >= 2 else { return }
        detail = FieldDetail(level: level)
        DiagnosticLog.app.note("field: detail", [("level", Double(level.rawValue)), ("fps", measured)])
    }

    /// The drawable follows the layout only once a size has held for two frames (or is the first
    /// real one), so a resize animation scales the last image instead of re-allocating mid-motion.
    /// The detail level's resolution scale is a deliberate step and applies on its own frame.
    @MainActor
    private func settleDrawable(of view: MTKView) {
        let traitScale = view.traitCollection.displayScale
        let scale = traitScale > 0 ? traitScale : view.contentScaleFactor
        let resolution = CGFloat(detail.resolutionScale)
        let leverMoved = resolution != lastResolutionScale
        lastResolutionScale = resolution
        let want = CGSize(width: Swift.max(1, (view.bounds.width * scale * resolution).rounded()),
                          height: Swift.max(1, (view.bounds.height * scale * resolution).rounded()))
        let have = view.drawableSize
        if abs(want.width - have.width) > 0.5 || abs(want.height - have.height) > 0.5 {
            if abs(want.width - pendingDrawableSize.width) < 0.5, abs(want.height - pendingDrawableSize.height) < 0.5 {
                pendingStableFrames += 1
            } else {
                pendingDrawableSize = want
                pendingStableFrames = 0
            }
            if pendingStableFrames >= 2 || have.width <= 2 || have.height <= 2 || leverMoved {
                view.drawableSize = want
            }
        } else {
            pendingStableFrames = 0
        }
        let size = view.drawableSize
        if size.height > 0 { uniforms.aspect = Float(size.width / size.height) }
    }

    /// Byte equality of two plain-`Float` structs: NaN equals NaN, which is the question asked.
    private static func bytesEqual<T>(_ a: T, _ b: T) -> Bool {
        withUnsafeBytes(of: a) { left in withUnsafeBytes(of: b) { right in left.elementsEqual(right) } }
    }
}
#endif
