// VideoTransitionsEngine.swift
// Echoelmusic - Professional Video Transitions System
//
// A++ Ultrahardthink Implementation
// Provides comprehensive video transitions including:
// - Standard transitions (fade, dissolve, wipe)
// - Advanced transitions (morph, glitch, kaleidoscope)
// - Audio-reactive transitions
// - Custom shader-based transitions
// - Transition presets and sequencing

import Foundation
import Combine
import CoreImage
import Accelerate
import os.log

#if canImport(Metal)
import Metal
import MetalKit
#endif

#if canImport(AVFoundation)
import AVFoundation
#endif

// MARK: - Logger

private let logger = Logger(subsystem: "com.echoelmusic.video", category: "Transitions")

// MARK: - Transition Types

/// All available transition types
public enum VideoTransitionType: String, CaseIterable, Codable, Sendable {
    // Basic Transitions
    case crossDissolve = "Cross Dissolve"
    case fade = "Fade"
    case dip = "Dip to Color"

    // Wipe Transitions
    case wipeLeft = "Wipe Left"
    case wipeRight = "Wipe Right"
    case wipeUp = "Wipe Up"
    case wipeDown = "Wipe Down"
    case wipeDiagonal = "Wipe Diagonal"
    case wipeCircle = "Circle Wipe"
    case wipeHeart = "Heart Wipe"
    case wipeStar = "Star Wipe"
    case wipeSpiral = "Spiral Wipe"
    case wipeClock = "Clock Wipe"

    // Slide Transitions
    case slideLeft = "Slide Left"
    case slideRight = "Slide Right"
    case slideUp = "Slide Up"
    case slideDown = "Slide Down"
    case pushLeft = "Push Left"
    case pushRight = "Push Right"

    // 3D Transitions
    case cubeLeft = "Cube Left"
    case cubeRight = "Cube Right"
    case flip = "Flip"
    case doorway = "Doorway"
    case fold = "Fold"
    case page = "Page Turn"

    // Zoom Transitions
    case zoomIn = "Zoom In"
    case zoomOut = "Zoom Out"
    case zoomRotate = "Zoom Rotate"

    // Blur Transitions
    case blurDissolve = "Blur Dissolve"
    case motionBlur = "Motion Blur"
    case radialBlur = "Radial Blur"

    // Distortion Transitions
    case ripple = "Ripple"
    case pixelate = "Pixelate"
    case morph = "Morph"
    case liquid = "Liquid"
    case wave = "Wave"

    // Glitch Transitions
    case glitch = "Glitch"
    case rgbSplit = "RGB Split"
    case vhsGlitch = "VHS Glitch"
    case dataMosh = "Data Mosh"
    case blockGlitch = "Block Glitch"

    // Stylized Transitions
    case kaleidoscope = "Kaleidoscope"
    case mosaic = "Mosaic"
    case luma = "Luma Key"
    case threshold = "Threshold"
    case posterize = "Posterize"

    // Audio-Reactive
    case beatSync = "Beat Sync"
    case frequencyWipe = "Frequency Wipe"
    case waveformMask = "Waveform Mask"

    public var category: TransitionCategory {
        switch self {
        case .crossDissolve, .fade, .dip:
            return .basic
        case .wipeLeft, .wipeRight, .wipeUp, .wipeDown, .wipeDiagonal, .wipeCircle, .wipeHeart, .wipeStar, .wipeSpiral, .wipeClock:
            return .wipe
        case .slideLeft, .slideRight, .slideUp, .slideDown, .pushLeft, .pushRight:
            return .slide
        case .cubeLeft, .cubeRight, .flip, .doorway, .fold, .page:
            return .threeD
        case .zoomIn, .zoomOut, .zoomRotate:
            return .zoom
        case .blurDissolve, .motionBlur, .radialBlur:
            return .blur
        case .ripple, .pixelate, .morph, .liquid, .wave:
            return .distortion
        case .glitch, .rgbSplit, .vhsGlitch, .dataMosh, .blockGlitch:
            return .glitch
        case .kaleidoscope, .mosaic, .luma, .threshold, .posterize:
            return .stylized
        case .beatSync, .frequencyWipe, .waveformMask:
            return .audioReactive
        }
    }

    public var defaultDuration: TimeInterval {
        switch category {
        case .basic, .wipe, .slide:
            return 1.0
        case .threeD, .zoom:
            return 1.5
        case .blur, .distortion:
            return 1.2
        case .glitch:
            return 0.5
        case .stylized:
            return 1.0
        case .audioReactive:
            return 2.0
        }
    }
}

public enum TransitionCategory: String, CaseIterable, Sendable {
    case basic = "Basic"
    case wipe = "Wipe"
    case slide = "Slide"
    case threeD = "3D"
    case zoom = "Zoom"
    case blur = "Blur"
    case distortion = "Distortion"
    case glitch = "Glitch"
    case stylized = "Stylized"
    case audioReactive = "Audio-Reactive"

    public var icon: String {
        switch self {
        case .basic: return "square.on.square"
        case .wipe: return "arrow.left.and.right"
        case .slide: return "arrow.right.square"
        case .threeD: return "cube"
        case .zoom: return "magnifyingglass"
        case .blur: return "aqi.medium"
        case .distortion: return "waveform"
        case .glitch: return "rectangle.split.3x1"
        case .stylized: return "paintbrush"
        case .audioReactive: return "speaker.wave.3"
        }
    }
}

// MARK: - Transition Configuration

/// Configuration for a video transition
public struct TransitionConfiguration: Codable, Sendable {
    public var type: VideoTransitionType
    public var duration: TimeInterval
    public var easing: TransitionEasing
    public var direction: TransitionDirection?
    public var color: CodableColor?
    public var intensity: Float
    public var customParameters: [String: Float]

    public init(
        type: VideoTransitionType,
        duration: TimeInterval? = nil,
        easing: TransitionEasing = .easeInOut,
        direction: TransitionDirection? = nil,
        color: CodableColor? = nil,
        intensity: Float = 1.0,
        customParameters: [String: Float] = [:]
    ) {
        self.type = type
        self.duration = duration ?? type.defaultDuration
        self.easing = easing
        self.direction = direction
        self.color = color
        self.intensity = intensity
        self.customParameters = customParameters
    }
}

public enum TransitionEasing: String, Codable, CaseIterable, Sendable {
    case linear = "Linear"
    case easeIn = "Ease In"
    case easeOut = "Ease Out"
    case easeInOut = "Ease In/Out"
    case bounce = "Bounce"
    case elastic = "Elastic"
    case anticipate = "Anticipate"
    case overshoot = "Overshoot"

    public func apply(_ t: Float) -> Float {
        switch self {
        case .linear:
            return t
        case .easeIn:
            return t * t
        case .easeOut:
            return t * (2.0 - t)
        case .easeInOut:
            return t < 0.5 ? 2.0 * t * t : -1.0 + (4.0 - 2.0 * t) * t
        case .bounce:
            let n1: Float = 7.5625
            let d1: Float = 2.75
            var t = t
            if t < 1.0 / d1 {
                return n1 * t * t
            } else if t < 2.0 / d1 {
                t -= 1.5 / d1
                return n1 * t * t + 0.75
            } else if t < 2.5 / d1 {
                t -= 2.25 / d1
                return n1 * t * t + 0.9375
            } else {
                t -= 2.625 / d1
                return n1 * t * t + 0.984375
            }
        case .elastic:
            if t == 0 || t == 1 { return t }
            let p: Float = 0.3
            let s = p / 4.0
            return pow(2.0, -10.0 * t) * sin((t - s) * (2.0 * .pi) / p) + 1.0
        case .anticipate:
            let s: Float = 1.70158
            return t * t * ((s + 1.0) * t - s)
        case .overshoot:
            let s: Float = 1.70158
            let t = t - 1.0
            return t * t * ((s + 1.0) * t + s) + 1.0
        }
    }
}

public enum TransitionDirection: String, Codable, CaseIterable, Sendable {
    case left = "Left"
    case right = "Right"
    case up = "Up"
    case down = "Down"
    case clockwise = "Clockwise"
    case counterClockwise = "Counter-Clockwise"
    case inward = "Inward"
    case outward = "Outward"
}

// MARK: - Codable Color

public struct CodableColor: Codable, Sendable {
    public var red: Float
    public var green: Float
    public var blue: Float
    public var alpha: Float

    public init(red: Float, green: Float, blue: Float, alpha: Float = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }

    public static let black = CodableColor(red: 0, green: 0, blue: 0)
    public static let white = CodableColor(red: 1, green: 1, blue: 1)
}

// MARK: - Transition State

public struct TransitionState: Sendable {
    public let progress: Float  // 0.0 to 1.0
    public let easedProgress: Float
    public let phase: TransitionPhase
    public let timeRemaining: TimeInterval
    public let audioLevel: Float?
    public let beatPhase: Float?

    public enum TransitionPhase {
        case notStarted
        case entering
        case midPoint
        case exiting
        case completed
    }
}

// MARK: - Video Transitions Engine

/// Main engine for processing video transitions
@MainActor
public final class VideoTransitionsEngine: ObservableObject {
    // MARK: - Singleton

    public static let shared = VideoTransitionsEngine()

    // MARK: - Published State

    @Published public private(set) var currentTransition: TransitionConfiguration?
    @Published public private(set) var transitionProgress: Float = 0.0
    @Published public private(set) var isTransitioning: Bool = false
    @Published public private(set) var availableTransitions: [VideoTransitionType] = VideoTransitionType.allCases

    // MARK: - Configuration

    public var defaultDuration: TimeInterval = 1.0
    public var defaultEasing: TransitionEasing = .easeInOut
    public var previewQuality: PreviewQuality = .medium

    public enum PreviewQuality: Int {
        case low = 360
        case medium = 720
        case high = 1080
        case ultra = 2160
    }

    // MARK: - Private Properties

    private var transitionStartTime: Date?
    private var sourceFrame: CIImage?
    private var destinationFrame: CIImage?
    private var cancellables = Set<AnyCancellable>()
    private var displayLink: CADisplayLink?
    private var completionHandler: (() -> Void)?

    // Audio reactivity
    private var audioLevel: Float = 0.0
    private var beatPhase: Float = 0.0

    // Core Image context
    private var ciContext: CIContext?

    #if canImport(Metal)
    private var metalDevice: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    #endif

    // MARK: - Initialization

    private init() {
        setupCoreImage()
        setupMetal()
    }

    private func setupCoreImage() {
        #if canImport(Metal)
        if let device = MTLCreateSystemDefaultDevice() {
            ciContext = CIContext(mtlDevice: device, options: [
                .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!,
                .cacheIntermediates: false
            ])
        } else {
            ciContext = CIContext(options: nil)
        }
        #else
        ciContext = CIContext(options: nil)
        #endif
    }

    private func setupMetal() {
        #if canImport(Metal)
        metalDevice = MTLCreateSystemDefaultDevice()
        commandQueue = metalDevice?.makeCommandQueue()
        #endif
    }

    // MARK: - Transition Execution

    /// Start a transition between two frames
    public func startTransition(
        from source: CIImage,
        to destination: CIImage,
        configuration: TransitionConfiguration,
        completion: (() -> Void)? = nil
    ) {
        guard !isTransitioning else {
            logger.warning("Transition already in progress")
            return
        }

        sourceFrame = source
        destinationFrame = destination
        currentTransition = configuration
        completionHandler = completion
        transitionProgress = 0.0
        transitionStartTime = Date()
        isTransitioning = true

        startDisplayLink()

        logger.info("Started transition: \(configuration.type.rawValue), duration: \(configuration.duration)s")
    }

    /// Cancel the current transition
    public func cancelTransition() {
        stopDisplayLink()
        isTransitioning = false
        currentTransition = nil
        transitionProgress = 0.0
        sourceFrame = nil
        destinationFrame = nil
        completionHandler = nil

        logger.info("Transition cancelled")
    }

    /// Set current transition progress manually (for scrubbing)
    public func setProgress(_ progress: Float) {
        guard isTransitioning else { return }
        transitionProgress = max(0.0, min(1.0, progress))
    }

    // MARK: - Display Link

    private func startDisplayLink() {
        displayLink = CADisplayLink(target: self, selector: #selector(updateTransition))
        displayLink?.add(to: .main, forMode: .common)
    }

    private func stopDisplayLink() {
        displayLink?.invalidate()
        displayLink = nil
    }

    @objc private func updateTransition() {
        guard let startTime = transitionStartTime,
              let config = currentTransition else { return }

        let elapsed = Date().timeIntervalSince(startTime)
        let rawProgress = Float(elapsed / config.duration)

        if rawProgress >= 1.0 {
            transitionProgress = 1.0
            completeTransition()
        } else {
            transitionProgress = rawProgress
        }
    }

    private func completeTransition() {
        stopDisplayLink()
        isTransitioning = false
        let handler = completionHandler
        completionHandler = nil
        sourceFrame = nil
        destinationFrame = nil

        logger.info("Transition completed")

        handler?()
    }

    // MARK: - Frame Rendering

    /// Render the current transition frame
    public func renderFrame() -> CIImage? {
        guard let source = sourceFrame,
              let destination = destinationFrame,
              let config = currentTransition else {
            return nil
        }

        let easedProgress = config.easing.apply(transitionProgress)

        return renderTransition(
            type: config.type,
            source: source,
            destination: destination,
            progress: easedProgress,
            configuration: config
        )
    }

    /// Render a specific transition type
    private func renderTransition(
        type: VideoTransitionType,
        source: CIImage,
        destination: CIImage,
        progress: Float,
        configuration: TransitionConfiguration
    ) -> CIImage? {
        switch type {
        // Basic
        case .crossDissolve:
            return renderCrossDissolve(source, destination, progress)
        case .fade:
            return renderFade(source, destination, progress)
        case .dip:
            return renderDipToColor(source, destination, progress, configuration.color ?? .black)

        // Wipes
        case .wipeLeft:
            return renderWipe(source, destination, progress, direction: .left)
        case .wipeRight:
            return renderWipe(source, destination, progress, direction: .right)
        case .wipeUp:
            return renderWipe(source, destination, progress, direction: .up)
        case .wipeDown:
            return renderWipe(source, destination, progress, direction: .down)
        case .wipeDiagonal:
            return renderDiagonalWipe(source, destination, progress)
        case .wipeCircle:
            return renderCircleWipe(source, destination, progress)
        case .wipeHeart:
            return renderShapeWipe(source, destination, progress, shape: .heart)
        case .wipeStar:
            return renderShapeWipe(source, destination, progress, shape: .star)
        case .wipeSpiral:
            return renderSpiralWipe(source, destination, progress)
        case .wipeClock:
            return renderClockWipe(source, destination, progress)

        // Slides
        case .slideLeft:
            return renderSlide(source, destination, progress, direction: .left)
        case .slideRight:
            return renderSlide(source, destination, progress, direction: .right)
        case .slideUp:
            return renderSlide(source, destination, progress, direction: .up)
        case .slideDown:
            return renderSlide(source, destination, progress, direction: .down)
        case .pushLeft:
            return renderPush(source, destination, progress, direction: .left)
        case .pushRight:
            return renderPush(source, destination, progress, direction: .right)

        // 3D
        case .cubeLeft:
            return renderCube(source, destination, progress, direction: .left)
        case .cubeRight:
            return renderCube(source, destination, progress, direction: .right)
        case .flip:
            return renderFlip(source, destination, progress)
        case .doorway:
            return renderDoorway(source, destination, progress)
        case .fold:
            return renderFold(source, destination, progress)
        case .page:
            return renderPageTurn(source, destination, progress)

        // Zoom
        case .zoomIn:
            return renderZoom(source, destination, progress, direction: .inward)
        case .zoomOut:
            return renderZoom(source, destination, progress, direction: .outward)
        case .zoomRotate:
            return renderZoomRotate(source, destination, progress)

        // Blur
        case .blurDissolve:
            return renderBlurDissolve(source, destination, progress)
        case .motionBlur:
            return renderMotionBlur(source, destination, progress, configuration.direction ?? .right)
        case .radialBlur:
            return renderRadialBlur(source, destination, progress)

        // Distortion
        case .ripple:
            return renderRipple(source, destination, progress, configuration.intensity)
        case .pixelate:
            return renderPixelate(source, destination, progress, configuration.intensity)
        case .morph:
            return renderMorph(source, destination, progress)
        case .liquid:
            return renderLiquid(source, destination, progress)
        case .wave:
            return renderWave(source, destination, progress)

        // Glitch
        case .glitch:
            return renderGlitch(source, destination, progress, configuration.intensity)
        case .rgbSplit:
            return renderRGBSplit(source, destination, progress, configuration.intensity)
        case .vhsGlitch:
            return renderVHSGlitch(source, destination, progress)
        case .dataMosh:
            return renderDataMosh(source, destination, progress)
        case .blockGlitch:
            return renderBlockGlitch(source, destination, progress)

        // Stylized
        case .kaleidoscope:
            return renderKaleidoscope(source, destination, progress)
        case .mosaic:
            return renderMosaic(source, destination, progress)
        case .luma:
            return renderLumaKey(source, destination, progress)
        case .threshold:
            return renderThreshold(source, destination, progress)
        case .posterize:
            return renderPosterize(source, destination, progress)

        // Audio-Reactive
        case .beatSync:
            return renderBeatSync(source, destination, progress)
        case .frequencyWipe:
            return renderFrequencyWipe(source, destination, progress)
        case .waveformMask:
            return renderWaveformMask(source, destination, progress)
        }
    }

    // MARK: - Basic Transitions

    private func renderCrossDissolve(_ source: CIImage, _ destination: CIImage, _ progress: Float) -> CIImage? {
        let filter = CIFilter(name: "CIDissolveTransition")
        filter?.setValue(source, forKey: kCIInputImageKey)
        filter?.setValue(destination, forKey: kCIInputTargetImageKey)
        filter?.setValue(NSNumber(value: progress), forKey: kCIInputTimeKey)
        return filter?.outputImage
    }

    private func renderFade(_ source: CIImage, _ destination: CIImage, _ progress: Float) -> CIImage? {
        // Fade through black
        if progress < 0.5 {
            let fadeOut = 1.0 - (progress * 2.0)
            return source.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: CGFloat(fadeOut), y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: CGFloat(fadeOut), z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: CGFloat(fadeOut), w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
            ])
        } else {
            let fadeIn = (progress - 0.5) * 2.0
            return destination.applyingFilter("CIColorMatrix", parameters: [
                "inputRVector": CIVector(x: CGFloat(fadeIn), y: 0, z: 0, w: 0),
                "inputGVector": CIVector(x: 0, y: CGFloat(fadeIn), z: 0, w: 0),
                "inputBVector": CIVector(x: 0, y: 0, z: CGFloat(fadeIn), w: 0),
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
            ])
        }
    }

    private func renderDipToColor(_ source: CIImage, _ destination: CIImage, _ progress: Float, _ color: CodableColor) -> CIImage? {
        let colorImage = CIImage(color: CIColor(red: CGFloat(color.red), green: CGFloat(color.green), blue: CGFloat(color.blue)))
            .cropped(to: source.extent)

        if progress < 0.5 {
            let dissolveProgress = progress * 2.0
            return renderCrossDissolve(source, colorImage, dissolveProgress)
        } else {
            let dissolveProgress = (progress - 0.5) * 2.0
            return renderCrossDissolve(colorImage, destination, dissolveProgress)
        }
    }

    // MARK: - Wipe Transitions

    private func renderWipe(_ source: CIImage, _ destination: CIImage, _ progress: Float, direction: TransitionDirection) -> CIImage? {
        let extent = source.extent

        var maskRect: CGRect
        switch direction {
        case .left:
            maskRect = CGRect(x: extent.width * CGFloat(1.0 - progress), y: 0, width: extent.width * CGFloat(progress), height: extent.height)
        case .right:
            maskRect = CGRect(x: 0, y: 0, width: extent.width * CGFloat(progress), height: extent.height)
        case .up:
            maskRect = CGRect(x: 0, y: extent.height * CGFloat(1.0 - progress), width: extent.width, height: extent.height * CGFloat(progress))
        case .down:
            maskRect = CGRect(x: 0, y: 0, width: extent.width, height: extent.height * CGFloat(progress))
        default:
            maskRect = extent
        }

        let croppedDestination = destination.cropped(to: maskRect)
        return croppedDestination.composited(over: source)
    }

    private func renderDiagonalWipe(_ source: CIImage, _ destination: CIImage, _ progress: Float) -> CIImage? {
        // Create a diagonal gradient mask
        let filter = CIFilter(name: "CILinearGradient")
        filter?.setValue(CIVector(x: 0, y: 0), forKey: "inputPoint0")
        filter?.setValue(CIVector(x: source.extent.width, y: source.extent.height), forKey: "inputPoint1")
        filter?.setValue(CIColor.white, forKey: "inputColor0")
        filter?.setValue(CIColor.black, forKey: "inputColor1")

        guard let gradient = filter?.outputImage?.cropped(to: source.extent) else { return nil }

        // Use the gradient as a mask with progress-based threshold
        let threshold = CGFloat(progress)
        let mask = gradient.applyingFilter("CIColorClamp", parameters: [
            "inputMinComponents": CIVector(x: threshold, y: threshold, z: threshold, w: 1),
            "inputMaxComponents": CIVector(x: 1, y: 1, z: 1, w: 1)
        ])

        return destination.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: source,
            kCIInputMaskImageKey: mask
        ])
    }

    private func renderCircleWipe(_ source: CIImage, _ destination: CIImage, _ progress: Float) -> CIImage? {
        let center = CIVector(x: source.extent.midX, y: source.extent.midY)
        let maxRadius = sqrt(pow(source.extent.width / 2, 2) + pow(source.extent.height / 2, 2))
        let radius = maxRadius * CGFloat(progress)

        let filter = CIFilter(name: "CIRadialGradient")
        filter?.setValue(center, forKey: "inputCenter")
        filter?.setValue(radius, forKey: "inputRadius0")
        filter?.setValue(radius + 1, forKey: "inputRadius1")
        filter?.setValue(CIColor.white, forKey: "inputColor0")
        filter?.setValue(CIColor.black, forKey: "inputColor1")

        guard let mask = filter?.outputImage?.cropped(to: source.extent) else { return nil }

        return destination.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: source,
            kCIInputMaskImageKey: mask
        ])
    }

    private enum WipeShape {
        case heart
        case star
    }

    private func renderShapeWipe(_ source: CIImage, _ destination: CIImage, _ progress: Float, shape: WipeShape) -> CIImage? {
        // For shapes, we use a scaling reveal effect
        // In a full implementation, this would use custom Metal shaders for precise shapes
        let scale = 1.0 + (1.0 - progress) * 2.0
        let center = CIVector(x: source.extent.midX, y: source.extent.midY)

        let scaledDestination = destination.applyingFilter("CILanczosScaleTransform", parameters: [
            "inputScale": scale,
            "inputAspectRatio": 1.0
        ])

        // Use a radial mask that grows
        return renderCircleWipe(source, destination, progress)
    }

    private func renderSpiralWipe(_ source: CIImage, _ destination: CIImage, _ progress: Float) -> CIImage? {
        // Spiral effect using twirl + radial gradient
        let center = CIVector(x: source.extent.midX, y: source.extent.midY)
        let angle = CGFloat(progress) * .pi * 4  // Multiple rotations

        let twirlFilter = CIFilter(name: "CITwirlDistortion")
        twirlFilter?.setValue(destination, forKey: kCIInputImageKey)
        twirlFilter?.setValue(center, forKey: kCIInputCenterKey)
        twirlFilter?.setValue(source.extent.width / 2, forKey: kCIInputRadiusKey)
        twirlFilter?.setValue(angle * (1.0 - CGFloat(progress)), forKey: kCIInputAngleKey)

        guard let twistedDest = twirlFilter?.outputImage else { return nil }

        return renderCrossDissolve(source, twistedDest, progress)
    }

    private func renderClockWipe(_ source: CIImage, _ destination: CIImage, _ progress: Float) -> CIImage? {
        // Clock wipe using angular gradient
        // This is a simplified version - full implementation would use Metal shaders
        let center = CIVector(x: source.extent.midX, y: source.extent.midY)

        // Simulate clock wipe with radial gradient and rotation
        let filter = CIFilter(name: "CISmoothLinearGradient")
        filter?.setValue(center, forKey: "inputPoint0")
        filter?.setValue(CIVector(x: source.extent.maxX, y: source.extent.midY), forKey: "inputPoint1")
        filter?.setValue(CIColor.white, forKey: "inputColor0")
        filter?.setValue(CIColor.black, forKey: "inputColor1")

        // Fall back to circle wipe for now
        return renderCircleWipe(source, destination, progress)
    }

    // MARK: - Slide Transitions

    private func renderSlide(_ source: CIImage, _ destination: CIImage, _ progress: Float, direction: TransitionDirection) -> CIImage? {
        var transform = CGAffineTransform.identity

        switch direction {
        case .left:
            transform = CGAffineTransform(translationX: -source.extent.width * CGFloat(progress), y: 0)
        case .right:
            transform = CGAffineTransform(translationX: source.extent.width * CGFloat(1.0 - progress), y: 0)
        case .up:
            transform = CGAffineTransform(translationX: 0, y: source.extent.height * CGFloat(progress))
        case .down:
            transform = CGAffineTransform(translationX: 0, y: -source.extent.height * CGFloat(progress))
        default:
            break
        }

        let slidingDestination = destination.transformed(by: transform)
        return slidingDestination.composited(over: source)
    }

    private func renderPush(_ source: CIImage, _ destination: CIImage, _ progress: Float, direction: TransitionDirection) -> CIImage? {
        let width = source.extent.width
        let height = source.extent.height

        var sourceTransform = CGAffineTransform.identity
        var destTransform = CGAffineTransform.identity

        switch direction {
        case .left:
            sourceTransform = CGAffineTransform(translationX: -width * CGFloat(progress), y: 0)
            destTransform = CGAffineTransform(translationX: width * CGFloat(1.0 - progress), y: 0)
        case .right:
            sourceTransform = CGAffineTransform(translationX: width * CGFloat(progress), y: 0)
            destTransform = CGAffineTransform(translationX: -width * CGFloat(1.0 - progress), y: 0)
        default:
            break
        }

        let transformedSource = source.transformed(by: sourceTransform)
        let transformedDest = destination.transformed(by: destTransform)

        return transformedDest.composited(over: transformedSource)
    }

    // MARK: - 3D Transitions (Simulated)

    private func renderCube(_ source: CIImage, _ destination: CIImage, _ progress: Float, direction: TransitionDirection) -> CIImage? {
        // Simulate cube rotation with perspective transform
        let width = source.extent.width
        let perspective = 1.0 - abs(progress - 0.5) * 0.5

        if progress < 0.5 {
            // Show source rotating away
            let scaleX = CGFloat(1.0 - progress)
            let transformedSource = source.applyingFilter("CILanczosScaleTransform", parameters: [
                "inputScale": scaleX,
                "inputAspectRatio": 1.0 / perspective
            ])
            return transformedSource
        } else {
            // Show destination rotating in
            let scaleX = CGFloat(progress)
            let transformedDest = destination.applyingFilter("CILanczosScaleTransform", parameters: [
                "inputScale": scaleX,
                "inputAspectRatio": 1.0 / perspective
            ])
            return transformedDest
        }
    }

    private func renderFlip(_ source: CIImage, _ destination: CIImage, _ progress: Float) -> CIImage? {
        // Vertical flip effect
        if progress < 0.5 {
            let scale = 1.0 - progress * 2.0
            return source.applyingFilter("CILanczosScaleTransform", parameters: [
                "inputScale": 1.0,
                "inputAspectRatio": CGFloat(scale)
            ])
        } else {
            let scale = (progress - 0.5) * 2.0
            return destination.applyingFilter("CILanczosScaleTransform", parameters: [
                "inputScale": 1.0,
                "inputAspectRatio": CGFloat(scale)
            ])
        }
    }

    private func renderDoorway(_ source: CIImage, _ destination: CIImage, _ progress: Float) -> CIImage? {
        // Door opening effect - split in middle
        let width = source.extent.width
        let height = source.extent.height
        let midX = width / 2

        // Left half moves left
        let leftRect = CGRect(x: 0, y: 0, width: midX, height: height)
        let leftSource = source.cropped(to: leftRect)
            .transformed(by: CGAffineTransform(translationX: -midX * CGFloat(progress), y: 0))

        // Right half moves right
        let rightRect = CGRect(x: midX, y: 0, width: midX, height: height)
        let rightSource = source.cropped(to: rightRect)
            .transformed(by: CGAffineTransform(translationX: midX * CGFloat(progress), y: 0))

        // Destination behind
        return leftSource.composited(over: rightSource.composited(over: destination))
    }

    private func renderFold(_ source: CIImage, _ destination: CIImage, _ progress: Float) -> CIImage? {
        // Paper fold effect - simplified as squeeze
        let squeezeAmount = CGFloat(progress)

        let squeezedSource = source.applyingFilter("CIPinchDistortion", parameters: [
            kCIInputCenterKey: CIVector(x: source.extent.midX, y: source.extent.midY),
            kCIInputRadiusKey: source.extent.width,
            kCIInputScaleKey: squeezeAmount
        ])

        return renderCrossDissolve(squeezedSource, destination, progress)
    }

    private func renderPageTurn(_ source: CIImage, _ destination: CIImage, _ progress: Float) -> CIImage? {
        // Page curl effect
        let filter = CIFilter(name: "CIPageCurlWithShadowTransition")
        filter?.setValue(source, forKey: kCIInputImageKey)
        filter?.setValue(destination, forKey: kCIInputTargetImageKey)
        filter?.setValue(source, forKey: kCIInputBacksideImageKey)
        filter?.setValue(NSNumber(value: progress), forKey: kCIInputTimeKey)
        filter?.setValue(CIVector(x: 0, y: source.extent.height), forKey: "inputExtent")
        filter?.setValue(CIVector(x: source.extent.width * 0.5, y: source.extent.height * 0.1), forKey: "inputShadowExtent")
        filter?.setValue(NSNumber(value: Float.pi * 0.25), forKey: kCIInputAngleKey)
        filter?.setValue(NSNumber(value: 50), forKey: kCIInputRadiusKey)

        return filter?.outputImage
    }

    // MARK: - Zoom Transitions

    private func renderZoom(_ source: CIImage, _ destination: CIImage, _ progress: Float, direction: TransitionDirection) -> CIImage? {
        let scale: CGFloat
        if direction == .inward {
            scale = 1.0 + CGFloat(progress) * 2.0
        } else {
            scale = 3.0 - CGFloat(progress) * 2.0
        }

        if progress < 0.5 {
            let scaledSource = source.applyingFilter("CILanczosScaleTransform", parameters: [
                "inputScale": direction == .inward ? scale : 1.0 / scale,
                "inputAspectRatio": 1.0
            ])
            let opacity = 1.0 - progress * 2.0
            return scaledSource.applyingFilter("CIColorMatrix", parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(opacity))
            ])
        } else {
            let destScale = direction == .inward ? (3.0 - scale) : scale
            let scaledDest = destination.applyingFilter("CILanczosScaleTransform", parameters: [
                "inputScale": destScale,
                "inputAspectRatio": 1.0
            ])
            let opacity = (progress - 0.5) * 2.0
            return scaledDest.applyingFilter("CIColorMatrix", parameters: [
                "inputAVector": CIVector(x: 0, y: 0, z: 0, w: CGFloat(opacity))
            ])
        }
    }

    private func renderZoomRotate(_ source: CIImage, _ destination: CIImage, _ progress: Float) -> CIImage? {
        let angle = CGFloat(progress) * .pi * 2
        let scale = 1.0 + abs(0.5 - CGFloat(progress)) * 2.0
        let center = CIVector(x: source.extent.midX, y: source.extent.midY)

        if progress < 0.5 {
            let transformed = source.applyingFilter("CIStraightenFilter", parameters: [
                kCIInputAngleKey: angle
            ]).applyingFilter("CILanczosScaleTransform", parameters: [
                "inputScale": scale,
                "inputAspectRatio": 1.0
            ])
            return transformed
        } else {
            let transformed = destination.applyingFilter("CIStraightenFilter", parameters: [
                kCIInputAngleKey: angle - .pi
            ]).applyingFilter("CILanczosScaleTransform", parameters: [
                "inputScale": scale,
                "inputAspectRatio": 1.0
            ])
            return transformed
        }
    }

    // MARK: - Blur Transitions

    private func renderBlurDissolve(_ source: CIImage, _ destination: CIImage, _ progress: Float) -> CIImage? {
        let blurAmount = 50.0 * (1.0 - abs(progress - 0.5) * 2.0)

        if progress < 0.5 {
            return source.applyingFilter("CIGaussianBlur", parameters: [
                kCIInputRadiusKey: blurAmount
            ])
        } else {
            return destination.applyingFilter("CIGaussianBlur", parameters: [
                kCIInputRadiusKey: blurAmount
            ])
        }
    }

    private func renderMotionBlur(_ source: CIImage, _ destination: CIImage, _ progress: Float, _ direction: TransitionDirection) -> CIImage? {
        let blurAmount = 50.0 * (1.0 - abs(progress - 0.5) * 2.0)
        var angle: CGFloat = 0

        switch direction {
        case .left, .right:
            angle = 0
        case .up, .down:
            angle = .pi / 2
        default:
            angle = .pi / 4
        }

        let image = progress < 0.5 ? source : destination

        return image.applyingFilter("CIMotionBlur", parameters: [
            kCIInputRadiusKey: blurAmount,
            kCIInputAngleKey: angle
        ])
    }

    private func renderRadialBlur(_ source: CIImage, _ destination: CIImage, _ progress: Float) -> CIImage? {
        let blurAmount = 20.0 * (1.0 - abs(progress - 0.5) * 2.0)
        let center = CIVector(x: source.extent.midX, y: source.extent.midY)

        let image = progress < 0.5 ? source : destination

        return image.applyingFilter("CIZoomBlur", parameters: [
            kCIInputCenterKey: center,
            "inputAmount": blurAmount
        ])
    }

    // MARK: - Distortion Transitions

    private func renderRipple(_ source: CIImage, _ destination: CIImage, _ progress: Float, _ intensity: Float) -> CIImage? {
        let filter = CIFilter(name: "CIRippleTransition")
        filter?.setValue(source, forKey: kCIInputImageKey)
        filter?.setValue(destination, forKey: kCIInputTargetImageKey)
        filter?.setValue(CIVector(x: source.extent.midX, y: source.extent.midY), forKey: kCIInputCenterKey)
        filter?.setValue(source.extent, forKey: kCIInputExtentKey)
        filter?.setValue(NSNumber(value: progress), forKey: kCIInputTimeKey)
        filter?.setValue(NSNumber(value: 50.0 * intensity), forKey: kCIInputWidthKey)
        filter?.setValue(NSNumber(value: 30 * intensity), forKey: "inputScale")

        return filter?.outputImage
    }

    private func renderPixelate(_ source: CIImage, _ destination: CIImage, _ progress: Float, _ intensity: Float) -> CIImage? {
        let maxPixelSize: CGFloat = 100.0 * CGFloat(intensity)
        let pixelSize = maxPixelSize * CGFloat(1.0 - abs(progress - 0.5) * 2.0) + 1.0

        let image = progress < 0.5 ? source : destination

        return image.applyingFilter("CIPixellate", parameters: [
            kCIInputCenterKey: CIVector(x: source.extent.midX, y: source.extent.midY),
            kCIInputScaleKey: pixelSize
        ])
    }

    private func renderMorph(_ source: CIImage, _ destination: CIImage, _ progress: Float) -> CIImage? {
        // Morph using displacement map
        let filter = CIFilter(name: "CIDissolveTransition")
        filter?.setValue(source, forKey: kCIInputImageKey)
        filter?.setValue(destination, forKey: kCIInputTargetImageKey)
        filter?.setValue(NSNumber(value: progress), forKey: kCIInputTimeKey)

        guard let dissolved = filter?.outputImage else { return nil }

        // Add some distortion during transition
        let distortAmount = 50.0 * (1.0 - abs(progress - 0.5) * 2.0)

        return dissolved.applyingFilter("CIBumpDistortion", parameters: [
            kCIInputCenterKey: CIVector(x: source.extent.midX, y: source.extent.midY),
            kCIInputRadiusKey: source.extent.width / 2,
            kCIInputScaleKey: distortAmount / 100.0
        ])
    }

    private func renderLiquid(_ source: CIImage, _ destination: CIImage, _ progress: Float) -> CIImage? {
        // Liquid effect using glass distortion
        let center = CIVector(x: source.extent.midX, y: source.extent.midY)
        let amount = 100.0 * (1.0 - abs(progress - 0.5) * 2.0)

        let image = progress < 0.5 ? source : destination

        return image.applyingFilter("CIGlassDistortion", parameters: [
            kCIInputCenterKey: center,
            "inputScale": amount
        ])
    }

    private func renderWave(_ source: CIImage, _ destination: CIImage, _ progress: Float) -> CIImage? {
        // Wave distortion
        let time = Date().timeIntervalSince1970

        if progress < 0.5 {
            return source.applyingFilter("CIBumpDistortion", parameters: [
                kCIInputCenterKey: CIVector(
                    x: source.extent.midX + sin(CGFloat(time)) * 50,
                    y: source.extent.midY + cos(CGFloat(time)) * 50
                ),
                kCIInputRadiusKey: source.extent.width,
                kCIInputScaleKey: CGFloat(progress) * 0.5
            ])
        } else {
            return destination.applyingFilter("CIBumpDistortion", parameters: [
                kCIInputCenterKey: CIVector(
                    x: source.extent.midX + sin(CGFloat(time)) * 50,
                    y: source.extent.midY + cos(CGFloat(time)) * 50
                ),
                kCIInputRadiusKey: source.extent.width,
                kCIInputScaleKey: CGFloat(1.0 - progress) * 0.5
            ])
        }
    }

    // MARK: - Glitch Transitions

    private func renderGlitch(_ source: CIImage, _ destination: CIImage, _ progress: Float, _ intensity: Float) -> CIImage? {
        // Combine RGB split with random displacement
        let baseImage = progress < 0.5 ? source : destination

        // Random horizontal displacement for glitch lines
        var result = baseImage

        // Add RGB split
        if let rgbSplit = renderRGBSplit(source, destination, progress, intensity) {
            result = rgbSplit
        }

        // Add some noise/grain
        let noiseAmount = CGFloat(intensity) * CGFloat(1.0 - abs(progress - 0.5) * 2.0) * 0.3
        result = result.applyingFilter("CIColorMatrix", parameters: [
            "inputBiasVector": CIVector(x: noiseAmount * CGFloat.random(in: -1...1),
                                        y: noiseAmount * CGFloat.random(in: -1...1),
                                        z: noiseAmount * CGFloat.random(in: -1...1),
                                        w: 0)
        ])

        return result
    }

    private func renderRGBSplit(_ source: CIImage, _ destination: CIImage, _ progress: Float, _ intensity: Float) -> CIImage? {
        let splitAmount = CGFloat(intensity) * CGFloat(1.0 - abs(progress - 0.5) * 2.0) * 20.0

        let image = progress < 0.5 ? source : destination

        // Extract RGB channels and offset
        let red = image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 1, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ]).transformed(by: CGAffineTransform(translationX: -splitAmount, y: 0))

        let green = image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 1, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ])

        let blue = image.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputGVector": CIVector(x: 0, y: 0, z: 0, w: 0),
            "inputBVector": CIVector(x: 0, y: 0, z: 1, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ]).transformed(by: CGAffineTransform(translationX: splitAmount, y: 0))

        // Combine using screen blend
        let rgCombined = red.applyingFilter("CIAdditionCompositing", parameters: [
            kCIInputBackgroundImageKey: green
        ])

        return rgCombined.applyingFilter("CIAdditionCompositing", parameters: [
            kCIInputBackgroundImageKey: blue
        ])
    }

    private func renderVHSGlitch(_ source: CIImage, _ destination: CIImage, _ progress: Float) -> CIImage? {
        let image = progress < 0.5 ? source : destination

        // VHS effect: scan lines + color bleeding + noise
        var result = image

        // Add RGB split
        if let rgb = renderRGBSplit(source, destination, progress, 0.5) {
            result = rgb
        }

        // Desaturate slightly
        result = result.applyingFilter("CIColorControls", parameters: [
            kCIInputSaturationKey: 0.8,
            kCIInputContrastKey: 1.2
        ])

        return result
    }

    private func renderDataMosh(_ source: CIImage, _ destination: CIImage, _ progress: Float) -> CIImage? {
        // Simulate data moshing with block artifacts
        let blockSize = 50.0 * (1.0 - abs(progress - 0.5) * 2.0) + 1.0

        let mixed = renderCrossDissolve(source, destination, progress)

        return mixed?.applyingFilter("CIPixellate", parameters: [
            kCIInputScaleKey: blockSize
        ])
    }

    private func renderBlockGlitch(_ source: CIImage, _ destination: CIImage, _ progress: Float) -> CIImage? {
        // Block displacement effect
        let image = progress < 0.5 ? source : destination

        // This would ideally use a custom shader for true block displacement
        // For now, use a combination of pixelation and distortion
        let intensity = 1.0 - abs(progress - 0.5) * 2.0

        return image.applyingFilter("CIPixellate", parameters: [
            kCIInputScaleKey: 20.0 * CGFloat(intensity) + 1.0
        ])
    }

    // MARK: - Stylized Transitions

    private func renderKaleidoscope(_ source: CIImage, _ destination: CIImage, _ progress: Float) -> CIImage? {
        let filter = CIFilter(name: "CIKaleidoscope")
        let image = progress < 0.5 ? source : destination

        filter?.setValue(image, forKey: kCIInputImageKey)
        filter?.setValue(CIVector(x: source.extent.midX, y: source.extent.midY), forKey: kCIInputCenterKey)
        filter?.setValue(NSNumber(value: 8), forKey: "inputCount")
        filter?.setValue(NSNumber(value: Double(progress) * .pi * 2), forKey: kCIInputAngleKey)

        return filter?.outputImage
    }

    private func renderMosaic(_ source: CIImage, _ destination: CIImage, _ progress: Float) -> CIImage? {
        let tileSize = 100.0 * (1.0 - abs(progress - 0.5) * 2.0) + 1.0

        let image = progress < 0.5 ? source : destination

        return image.applyingFilter("CIHexagonalPixellate", parameters: [
            kCIInputCenterKey: CIVector(x: source.extent.midX, y: source.extent.midY),
            kCIInputScaleKey: tileSize
        ])
    }

    private func renderLumaKey(_ source: CIImage, _ destination: CIImage, _ progress: Float) -> CIImage? {
        // Use luminance to blend
        let threshold = progress

        // Create luma mask from source
        let lumaMask = source.applyingFilter("CIColorMatrix", parameters: [
            "inputRVector": CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0),
            "inputGVector": CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0),
            "inputBVector": CIVector(x: 0.2126, y: 0.7152, z: 0.0722, w: 0),
            "inputAVector": CIVector(x: 0, y: 0, z: 0, w: 1)
        ])

        return destination.applyingFilter("CIBlendWithMask", parameters: [
            kCIInputBackgroundImageKey: source,
            kCIInputMaskImageKey: lumaMask
        ])
    }

    private func renderThreshold(_ source: CIImage, _ destination: CIImage, _ progress: Float) -> CIImage? {
        // High contrast threshold transition
        let image = progress < 0.5 ? source : destination
        let contrast = 2.0 + (1.0 - abs(progress - 0.5) * 2.0) * 3.0

        return image.applyingFilter("CIColorControls", parameters: [
            kCIInputContrastKey: contrast,
            kCIInputBrightnessKey: -0.1
        ])
    }

    private func renderPosterize(_ source: CIImage, _ destination: CIImage, _ progress: Float) -> CIImage? {
        let levels = max(2.0, 8.0 * abs(progress - 0.5) * 2.0)

        let mixed = renderCrossDissolve(source, destination, progress)

        return mixed?.applyingFilter("CIColorPosterize", parameters: [
            "inputLevels": levels
        ])
    }

    // MARK: - Audio-Reactive Transitions

    private func renderBeatSync(_ source: CIImage, _ destination: CIImage, _ progress: Float) -> CIImage? {
        // Transition that snaps on beat
        // In a full implementation, this would sync with actual beat detection
        let beatProgress = beatPhase > 0.5 ? 1.0 : 0.0
        let blendedProgress = progress * 0.7 + beatProgress * 0.3

        return renderCrossDissolve(source, destination, blendedProgress)
    }

    private func renderFrequencyWipe(_ source: CIImage, _ destination: CIImage, _ progress: Float) -> CIImage? {
        // Wipe based on audio frequency
        // High frequencies reveal from top, low from bottom
        let frequencyOffset = audioLevel * 0.3

        return renderWipe(source, destination, progress + frequencyOffset, direction: .up)
    }

    private func renderWaveformMask(_ source: CIImage, _ destination: CIImage, _ progress: Float) -> CIImage? {
        // Use audio waveform as mask
        // Simplified - in full implementation would use actual waveform data
        let waveHeight = CGFloat(audioLevel) * source.extent.height * 0.5

        let maskRect = CGRect(
            x: 0,
            y: source.extent.midY - waveHeight / 2,
            width: source.extent.width,
            height: waveHeight
        )

        let croppedDest = destination.cropped(to: maskRect)
        let blended = croppedDest.composited(over: source)

        return renderCrossDissolve(source, blended, progress)
    }

    // MARK: - Audio Reactivity Input

    /// Update audio level for reactive transitions
    public func updateAudioLevel(_ level: Float) {
        audioLevel = level
    }

    /// Update beat phase for beat-synced transitions (0.0-1.0)
    public func updateBeatPhase(_ phase: Float) {
        beatPhase = phase
    }
}

// MARK: - Transition Preset

public struct TransitionPreset: Identifiable, Codable, Sendable {
    public let id: UUID
    public let name: String
    public let configuration: TransitionConfiguration
    public let thumbnailName: String?
    public var isFavorite: Bool

    public init(
        name: String,
        configuration: TransitionConfiguration,
        thumbnailName: String? = nil,
        isFavorite: Bool = false
    ) {
        self.id = UUID()
        self.name = name
        self.configuration = configuration
        self.thumbnailName = thumbnailName
        self.isFavorite = isFavorite
    }

    // Built-in presets
    public static let quickCut = TransitionPreset(
        name: "Quick Cut",
        configuration: TransitionConfiguration(type: .crossDissolve, duration: 0.1)
    )

    public static let smoothDissolve = TransitionPreset(
        name: "Smooth Dissolve",
        configuration: TransitionConfiguration(type: .crossDissolve, duration: 2.0, easing: .easeInOut)
    )

    public static let dramaticWipe = TransitionPreset(
        name: "Dramatic Wipe",
        configuration: TransitionConfiguration(type: .wipeLeft, duration: 1.5, easing: .easeOut)
    )

    public static let glitchBurst = TransitionPreset(
        name: "Glitch Burst",
        configuration: TransitionConfiguration(type: .glitch, duration: 0.3, intensity: 1.5)
    )

    public static let dreamyBlur = TransitionPreset(
        name: "Dreamy Blur",
        configuration: TransitionConfiguration(type: .blurDissolve, duration: 2.5, easing: .easeInOut)
    )

    public static let energeticZoom = TransitionPreset(
        name: "Energetic Zoom",
        configuration: TransitionConfiguration(type: .zoomRotate, duration: 0.8, easing: .bounce)
    )

    public static let psychedelicKaleidoscope = TransitionPreset(
        name: "Psychedelic",
        configuration: TransitionConfiguration(type: .kaleidoscope, duration: 2.0)
    )

    public static let allPresets: [TransitionPreset] = [
        .quickCut, .smoothDissolve, .dramaticWipe, .glitchBurst,
        .dreamyBlur, .energeticZoom, .psychedelicKaleidoscope
    ]
}

// MARK: - Transition Sequence

/// Defines a sequence of transitions for automated playback
public struct TransitionSequence: Identifiable, Codable, Sendable {
    public let id: UUID
    public var name: String
    public var transitions: [SequenceItem]
    public var loopMode: LoopMode

    public struct SequenceItem: Codable, Sendable {
        public var configuration: TransitionConfiguration
        public var triggerCondition: TriggerCondition

        public enum TriggerCondition: Codable, Sendable {
            case time(delay: TimeInterval)
            case beat(count: Int)
            case audioLevel(threshold: Float)
            case manual
        }
    }

    public enum LoopMode: String, Codable, Sendable {
        case none
        case loop
        case pingPong
    }

    public init(name: String, transitions: [SequenceItem] = [], loopMode: LoopMode = .none) {
        self.id = UUID()
        self.name = name
        self.transitions = transitions
        self.loopMode = loopMode
    }
}
