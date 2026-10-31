#if canImport(MetalKit) && canImport(UIKit)
import EchoelCore
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
    /// struct in `shaderSource` — no compiler checks the two agree, so a field is only ever
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

    weak var store: ProjectStore?
    weak var engine: AudioEngine?
    var reduceMotion = false

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
        // A syntax error in the MSL below is data to every build gate: only this line and the
        // picture say that the shader failed, so both speak before the step that can die.
        DiagnosticLog.app.note("field: shader compiling")
        let library: MTLLibrary
        do {
            library = try device.makeLibrary(source: shaderSource, options: nil)
        } catch {
            DiagnosticLog.app.note("field: shader compile failed, flat picture", error: error)
            return nil
        }
        guard let vertex = library.makeFunction(name: "field_vertex"),
              let fragment = library.makeFunction(name: "field_fragment") else {
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
        encoder.setVertexBytes(&sent, length: MemoryLayout<Uniforms>.stride, index: 0)
        encoder.setFragmentBytes(&sent, length: MemoryLayout<Uniforms>.stride, index: 0)
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
            sampleDevice(at: now)
            settleDrawable(of: view)
        }

        step(seconds: seconds)

        // The picture cannot have changed: skip the pass and leave the last frame on the layer.
        // Not a pause — the display link keeps its cadence, and the next change encodes at once.
        if hasEncodedOnce, Self.bytesEqual(uniforms, lastEncoded) { return }

        guard let drawable = view.currentDrawable,
              let pass = view.currentRenderPassDescriptor,
              let queue = commandQueue,
              let buffer = queue.makeCommandBuffer() else { return }
        // Recorded after the guard: a frame without a drawable was not shown.
        lastEncoded = uniforms
        hasEncodedOnce = true

        if let pipeline, let encoder = buffer.makeRenderCommandEncoder(descriptor: pass) {
            encoder.setRenderPipelineState(pipeline)
            var sent = uniforms
            encoder.setVertexBytes(&sent, length: MemoryLayout<Uniforms>.stride, index: 0)
            encoder.setFragmentBytes(&sent, length: MemoryLayout<Uniforms>.stride, index: 0)
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
        let shown = motion.step(frame, after: seconds, still: reduceMotion || detail.isStill,
                                patternScale: detail.patternScale)
        uniforms = Uniforms(aspect: uniforms.aspect, shown: shown)
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
                encoder.setVertexBytes(&sent, length: MemoryLayout<Uniforms>.stride, index: 0)
                encoder.setFragmentBytes(&sent, length: MemoryLayout<Uniforms>.stride, index: 0)
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

    // MARK: - Shader (Metal Shading Language, compiled at runtime; the app ships no .metal file)

    /// Where the closed spectral circle leaves the pure spectrum: log2(780/640) and log2(780/420),
    /// written as literals from the numbers so the shader cannot drift from them.
    private static let redEdgeLiteral = String(format: "%.9f", Foundation.log2(780.0 / 640.0))
    private static let violetEdgeLiteral = String(format: "%.9f", Foundation.log2(780.0 / 420.0))

    private static let shaderSource = """
    #include <metal_stdlib>
    using namespace metal;

    struct VOut { float4 pos [[position]]; float2 uv; };
    struct Uniforms { float aspect; float beatPhase; float fieldPhase; float pulsePhase;
                      float beatLight; float centreLight; float levelLight; float coherence;
                      float breath; float toneHz; float density; float hasPulse; float hasCoherence; };

    // Wavelength (nm) -> linear sRGB through the CIE 1931 colour-matching functions (the
    // Wyman/Sloan/Shirley 2013 analytic fit) -> XYZ -> linear sRGB (D65).
    float cieLobe(float x, float mu, float s1, float s2) {
        float t = (x - mu) * (x < mu ? 1.0 / s1 : 1.0 / s2);
        return exp(-0.5 * t * t);
    }
    float3 wavelengthToRGB(float wl) {
        float X = 1.056 * cieLobe(wl, 599.8, 37.9, 31.0)
                + 0.362 * cieLobe(wl, 442.0, 16.0, 26.7)
                - 0.065 * cieLobe(wl, 501.1, 20.4, 26.2);
        float Y = 0.821 * cieLobe(wl, 568.8, 46.9, 40.5)
                + 0.286 * cieLobe(wl, 530.9, 16.3, 31.1);
        float Z = 1.217 * cieLobe(wl, 437.0, 11.8, 36.0)
                + 0.681 * cieLobe(wl, 459.0, 26.0, 13.8);
        X = max(0.0, X); Y = max(0.0, Y); Z = max(0.0, Z);
        float3 c = float3( 3.2406 * X - 1.5372 * Y - 0.4986 * Z,
                          -0.9689 * X + 1.8758 * Y + 0.0415 * Z,
                           0.0557 * X - 0.2040 * Y + 1.0570 * Z);
        // Desaturate towards neutral by the most negative channel, not a per-channel clip, so the
        // deep red and violet bands keep their hue instead of collapsing to one flat colour.
        float w = min(0.0, min(c.r, min(c.g, c.b)));
        c -= w;
        float m = max(c.r, max(c.g, c.b));
        if (m > 1.0) c /= m;
        return clamp(c, 0.0, 1.0);
    }

    // The tone, transposed by whole octaves into visible light, on the CLOSED spectral circle:
    // the visible band is barely one octave, and where the eye's response fades (deep red,
    // violet) the circle closes along the CIE purple line, so no pitch is ever dark or black.
    float3 toneColour(float toneHz) {
        float f = max(toneHz, 1.0);
        float p = log2(2.99792458e17 / 780.0 / f);
        float t = ceil(p) - p;
        if (t >= 1.0) t -= 1.0;
        float tRed = \(redEdgeLiteral);
        float tViolet = \(violetEdgeLiteral);
        if (t >= tRed && t <= tViolet) {
            return wavelengthToRGB(780.0 / exp2(t));
        }
        float seam = tRed + 1.0 - tViolet;
        float s = (t < tRed) ? (tRed - t) / seam : (tRed + 1.0 - t) / seam;
        float3 red = wavelengthToRGB(640.0);
        float3 violet = wavelengthToRGB(420.0);
        float3 c = mix(red, violet, s);
        float m = max(c.r, max(c.g, c.b));
        float target = mix(max(red.r, max(red.g, red.b)), max(violet.r, max(violet.g, violet.b)), s);
        if (m > 1e-6) c *= target / m;
        return clamp(c, 0.0, 1.0);
    }

    // Two-beam interference: two radial wave trains, the second detuned by coherence, superposed;
    // the visible field is their intensity (amplitude squared), so the fringes are crisp. The
    // fringe spacing follows the tone (k proportional to f, non-dispersive) around the ring dial.
    // Squaring doubles the temporal rate, so the phase is damped by FieldPulse.foldDamping first:
    // 2 x 0.5 x the 2.5 Hz ceiling lands under WCAG's three flashes a second.
    float fieldRings(float d, float density, float toneHz, float phase, float coh) {
        float pitchK = clamp(max(toneHz, 20.0) / 261.63, 0.5, 2.0);
        float k = clamp(density * pitchK, 4.0, 120.0);
        float p = phase * \(FieldPulse.foldDampingLiteral);
        float w1 = sin(d * k - p);
        float detune = mix(1.6, 1.02, coh);
        float w2 = sin(d * k * detune - p * 0.5);
        float interf = (w1 + w2) * 0.5;
        float intensity = interf * interf;
        return pow(intensity, mix(1.0, 2.6, coh));
    }

    float echoelHash(float2 p) {
        return fract(sin(dot(p, float2(12.9898, 78.233))) * 43758.5453);
    }

    // A full-screen triangle from the vertex id: no vertex buffer.
    vertex VOut field_vertex(uint vid [[vertex_id]]) {
        float2 p = float2((vid << 1) & 2, vid & 2);
        VOut o;
        o.pos = float4(p * 2.0 - 1.0, 0.0, 1.0);
        o.uv = p;
        return o;
    }

    fragment float4 field_fragment(VOut in [[stage_in]], constant Uniforms& u [[buffer(0)]]) {
        // Aspect-correct radial distance from the centre: circles stay circles on a tall phone.
        float2 uv = in.uv;
        uv.x *= u.aspect;
        float2 c = float2(0.5 * u.aspect, 0.5);
        float d = distance(uv, c);
        float coh = clamp(u.coherence, 0.0, 1.0);
        float density = clamp(u.density, 4.0, 120.0);
        float spread = 0.85 + 0.35 * clamp(u.breath, 0.0, 1.0);
        // The field moves with the song's bar (its phase is capped on the CPU); the vignette's
        // edge is always past the screen's corner, so the picture never closes to a black centre.
        float phase = u.fieldPhase * 6.2831853;
        float vEdge = 0.9 + 0.5 * spread;
        float vignette = smoothstep(vEdge, 0.0, d);
        float field = fieldRings(d, density, u.toneHz, phase, coh);
        // The beat: one thin ring grows through each beat; its light passed the flash guard.
        float ringRadius = (0.12 + 0.40 * clamp(u.beatPhase, 0.0, 1.0)) * spread;
        float ringT = (d - ringRadius) / 0.012;
        float ring = exp(-ringT * ringT) * clamp(u.beatLight, 0.0, 1.0);
        // The body: the centre blooms with the pulse (or the level when no body is measured) and
        // each heartbeat widens and brightens it; the brightening stays under the general-flash
        // threshold (FieldPulse.bloomSwing), so only the field's rate counts as flashing.
        float beat = (0.5 - 0.5 * cos(u.pulsePhase * 6.2831853)) * clamp(u.hasPulse, 0.0, 1.0);
        float restGlow = \(FieldPulse.restGlowFloorLiteral) + \(FieldPulse.restGlowSpanLiteral) * clamp(u.centreLight, 0.0, 1.0);
        float beatGain = 0.80 + \(FieldPulse.bloomSwingLiteral) * beat;
        float bloomEdge = (0.34 + 0.18 * beat) * spread;
        float bloom = restGlow * beatGain * smoothstep(bloomEdge, 0.0, d);
        // Coherence, where it is measured, widens a quiet halo; absent, there is none.
        float haloRadius = (0.30 + 0.15 * coh) * spread;
        float haloT = (d - haloRadius) / 0.010;
        float halo = exp(-haloT * haloT) * 0.22 * clamp(u.hasCoherence, 0.0, 1.0);
        float energy = clamp(field * vignette * (0.35 + 0.65 * clamp(u.levelLight, 0.0, 1.0)) + bloom + ring + halo, 0.0, 1.0);
        // The colour: the key's tonic as light, warmed like daylight, fuller with coherence, and
        // lifted to a luminance floor only as far as the gamut allows (never a hue rotation).
        float3 col = toneColour(u.toneHz);
        float l = dot(col, float3(0.2126, 0.7152, 0.0722));
        float3 warm = float3(1.0, 0.92, 0.80);
        col = mix(float3(l) * warm, col, 0.97);
        col = mix(col, warm, 0.05);
        col = mix(col, col * 1.15 + 0.05, coh);
        float lum = dot(col, float3(0.2126, 0.7152, 0.0722));
        float peak = max(max(col.r, max(col.g, col.b)), 1e-4);
        float lift = max(min(0.35 / max(lum, 0.04), 1.0 / peak), 1.0);
        col *= (lum < 0.35) ? lift : 1.0;
        float ambient = \(FieldPulse.ambientLiteral);
        float3 outCol = col * (ambient + (1.0 - ambient) * energy);
        outCol += (echoelHash(in.uv * 1000.0) - 0.5) / 255.0;
        return float4(clamp(outCol, 0.0, 1.0), 1.0);
    }
    """
}
#endif
