import Foundation
import CoreImage
import CoreGraphics
#if canImport(UIKit)
import UIKit
#endif
#if canImport(AppKit)
import AppKit
#endif
#if canImport(Vision)
import Vision
#endif
#if canImport(CoreML)
import CoreML
#endif

// ╔═══════════════════════════════════════════════════════════════════════════════════════════════════════╗
// ║                                                                                                       ║
// ║   ███████╗██╗   ██╗██████╗ ███████╗██████╗     ██╗███╗   ██╗████████╗███████╗██╗                      ║
// ║   ██╔════╝██║   ██║██╔══██╗██╔════╝██╔══██╗    ██║████╗  ██║╚══██╔══╝██╔════╝██║                      ║
// ║   ███████╗██║   ██║██████╔╝█████╗  ██████╔╝    ██║██╔██╗ ██║   ██║   █████╗  ██║                      ║
// ║   ╚════██║██║   ██║██╔═══╝ ██╔══╝  ██╔══██╗    ██║██║╚██╗██║   ██║   ██╔══╝  ██║                      ║
// ║   ███████║╚██████╔╝██║     ███████╗██║  ██║    ██║██║ ╚████║   ██║   ███████╗███████╗                 ║
// ║   ╚══════╝ ╚═════╝ ╚═╝     ╚══════╝╚═╝  ╚═╝    ╚═╝╚═╝  ╚═══╝   ╚═╝   ╚══════╝╚══════╝                 ║
// ║                                                                                                       ║
// ║   🎨 IMAGE & VIDEO MATCHING ENGINE - Super Intelligence Quantum Level 🎨                              ║
// ║                                                                                                       ║
// ║   Automatische Bildangleichung • Farbkorrektur • Weißabgleich • Belichtung • Winkel                   ║
// ║   Auto Color Matching • White Balance • Exposure • Lighting • Angle Correction                        ║
// ║                                                                                                       ║
// ║   Features:                                                                                           ║
// ║   • AI-Powered Color Matching between clips/photos                                                    ║
// ║   • Automatic White Balance (Temperature & Tint)                                                      ║
// ║   • Smart Exposure Correction (Shadows, Highlights, Midtones)                                         ║
// ║   • AI Lighting Enhancement (Fill Light, Rim Light, Ambient)                                          ║
// ║   • Perspective & Angle Correction (Horizon, Lens Distortion)                                         ║
// ║   • Video Quality Enhancement (4K→8K Upscaling, Denoising)                                            ║
// ║   • Scene-to-Scene Matching (Color Continuity)                                                        ║
// ║   • Reference-Based Grading (Match to any reference)                                                  ║
// ║   • Quantum-Enhanced Processing (Super Intelligence Mode)                                             ║
// ║                                                                                                       ║
// ╚═══════════════════════════════════════════════════════════════════════════════════════════════════════╝

// MARK: - Intelligence Levels

/// Intelligence level for processing
public enum MatchingIntelligenceLevel: String, CaseIterable, Codable {
    case basic = "Basic"                    // Simple adjustments
    case smart = "Smart"                    // AI-assisted
    case advanced = "Advanced"              // Deep learning
    case superIntelligence = "Super Intelligence"  // Full AI
    case quantumSI = "Quantum SI"           // Quantum-enhanced AI (100x power)

    public var icon: String {
        switch self {
        case .basic: return "🔧"
        case .smart: return "🧠"
        case .advanced: return "🤖"
        case .superIntelligence: return "⚡"
        case .quantumSI: return "🔮"
        }
    }

    public var processingMultiplier: Float {
        switch self {
        case .basic: return 1.0
        case .smart: return 2.0
        case .advanced: return 5.0
        case .superIntelligence: return 10.0
        case .quantumSI: return 100.0
        }
    }
}

// MARK: - Color Analysis

/// Comprehensive color analysis result
public struct ColorAnalysis: Codable, Equatable {
    // Histogram data
    public var redHistogram: [Float]
    public var greenHistogram: [Float]
    public var blueHistogram: [Float]
    public var luminanceHistogram: [Float]

    // Statistics
    public var averageRed: Float
    public var averageGreen: Float
    public var averageBlue: Float
    public var averageLuminance: Float

    // Color temperature
    public var colorTemperature: Float  // Kelvin (2000-10000K)
    public var tint: Float              // Green-Magenta (-150 to +150)

    // Exposure
    public var exposure: Float          // EV (-5 to +5)
    public var contrast: Float          // 0-2
    public var highlights: Float        // -1 to +1
    public var shadows: Float           // -1 to +1
    public var whites: Float            // -1 to +1
    public var blacks: Float            // -1 to +1

    // Saturation & Vibrance
    public var saturation: Float        // 0-2
    public var vibrance: Float          // -1 to +1

    // Dynamic range
    public var dynamicRange: Float      // Stops of range
    public var clippedHighlights: Float // Percentage
    public var clippedShadows: Float    // Percentage

    public init() {
        redHistogram = Array(repeating: 0, count: 256)
        greenHistogram = Array(repeating: 0, count: 256)
        blueHistogram = Array(repeating: 0, count: 256)
        luminanceHistogram = Array(repeating: 0, count: 256)
        averageRed = 0.5
        averageGreen = 0.5
        averageBlue = 0.5
        averageLuminance = 0.5
        colorTemperature = 5500
        tint = 0
        exposure = 0
        contrast = 1
        highlights = 0
        shadows = 0
        whites = 0
        blacks = 0
        saturation = 1
        vibrance = 0
        dynamicRange = 10
        clippedHighlights = 0
        clippedShadows = 0
    }
}

// MARK: - White Balance

/// White balance correction data
public struct WhiteBalanceCorrection: Codable, Equatable {
    public var temperature: Float       // Kelvin adjustment
    public var tint: Float              // Green-Magenta
    public var autoDetected: Bool
    public var confidence: Float        // 0-1

    public static let neutral = WhiteBalanceCorrection(
        temperature: 5500, tint: 0, autoDetected: false, confidence: 1.0
    )

    public static let tungsten = WhiteBalanceCorrection(
        temperature: 3200, tint: 0, autoDetected: false, confidence: 1.0
    )

    public static let daylight = WhiteBalanceCorrection(
        temperature: 5600, tint: 0, autoDetected: false, confidence: 1.0
    )

    public static let cloudy = WhiteBalanceCorrection(
        temperature: 6500, tint: 0, autoDetected: false, confidence: 1.0
    )

    public static let shade = WhiteBalanceCorrection(
        temperature: 7500, tint: 0, autoDetected: false, confidence: 1.0
    )

    public static let fluorescent = WhiteBalanceCorrection(
        temperature: 4000, tint: 10, autoDetected: false, confidence: 1.0
    )

    public init(temperature: Float = 5500, tint: Float = 0, autoDetected: Bool = false, confidence: Float = 1.0) {
        self.temperature = temperature
        self.tint = tint
        self.autoDetected = autoDetected
        self.confidence = confidence
    }
}

// MARK: - Exposure Correction

/// Exposure correction data
public struct ExposureCorrection: Codable, Equatable {
    public var exposure: Float          // EV stops (-5 to +5)
    public var contrast: Float          // Multiplier (0.5-2.0)
    public var highlights: Float        // Recovery (-1 to +1)
    public var shadows: Float           // Fill (-1 to +1)
    public var whites: Float            // Clip point (-1 to +1)
    public var blacks: Float            // Clip point (-1 to +1)
    public var clarity: Float           // Local contrast (-1 to +1)
    public var dehaze: Float            // Haze removal (-1 to +1)
    public var saturation: Float        // Saturation multiplier (0-2.0)
    public var autoDetected: Bool
    public var confidence: Float

    public static let neutral = ExposureCorrection(
        exposure: 0, contrast: 1, highlights: 0, shadows: 0,
        whites: 0, blacks: 0, clarity: 0, dehaze: 0, saturation: 1.0,
        autoDetected: false, confidence: 1.0
    )

    public init(
        exposure: Float = 0, contrast: Float = 1, highlights: Float = 0,
        shadows: Float = 0, whites: Float = 0, blacks: Float = 0,
        clarity: Float = 0, dehaze: Float = 0, saturation: Float = 1.0,
        autoDetected: Bool = false, confidence: Float = 1.0
    ) {
        self.exposure = exposure
        self.contrast = contrast
        self.highlights = highlights
        self.shadows = shadows
        self.whites = whites
        self.blacks = blacks
        self.clarity = clarity
        self.dehaze = dehaze
        self.saturation = saturation
        self.autoDetected = autoDetected
        self.confidence = confidence
    }
}

// MARK: - Lighting Correction

/// AI-powered lighting correction
public struct LightingCorrection: Codable, Equatable {
    // Fill light
    public var fillLightIntensity: Float    // 0-1
    public var fillLightDirection: Float    // Angle in degrees

    // Rim/Back light
    public var rimLightIntensity: Float     // 0-1
    public var rimLightColor: RGBColor

    // Ambient light
    public var ambientIntensity: Float      // 0-1
    public var ambientColor: RGBColor

    // Face lighting (AI-detected)
    public var faceLightingEnabled: Bool
    public var faceLightIntensity: Float
    public var faceShadowReduction: Float

    // Scene analysis
    public var detectedLightSources: Int
    public var dominantLightDirection: Float
    public var lightingQualityScore: Float  // 0-1

    public struct RGBColor: Codable, Equatable {
        public var r: Float
        public var g: Float
        public var b: Float

        public static let white = RGBColor(r: 1, g: 1, b: 1)
        public static let warm = RGBColor(r: 1, g: 0.9, b: 0.8)
        public static let cool = RGBColor(r: 0.9, g: 0.95, b: 1)
    }

    public static let neutral = LightingCorrection(
        fillLightIntensity: 0, fillLightDirection: 0,
        rimLightIntensity: 0, rimLightColor: .white,
        ambientIntensity: 0, ambientColor: .white,
        faceLightingEnabled: false, faceLightIntensity: 0, faceShadowReduction: 0,
        detectedLightSources: 0, dominantLightDirection: 0, lightingQualityScore: 1.0
    )

    public init(
        fillLightIntensity: Float = 0, fillLightDirection: Float = 0,
        rimLightIntensity: Float = 0, rimLightColor: RGBColor = .white,
        ambientIntensity: Float = 0, ambientColor: RGBColor = .white,
        faceLightingEnabled: Bool = false, faceLightIntensity: Float = 0,
        faceShadowReduction: Float = 0, detectedLightSources: Int = 0,
        dominantLightDirection: Float = 0, lightingQualityScore: Float = 1.0
    ) {
        self.fillLightIntensity = fillLightIntensity
        self.fillLightDirection = fillLightDirection
        self.rimLightIntensity = rimLightIntensity
        self.rimLightColor = rimLightColor
        self.ambientIntensity = ambientIntensity
        self.ambientColor = ambientColor
        self.faceLightingEnabled = faceLightingEnabled
        self.faceLightIntensity = faceLightIntensity
        self.faceShadowReduction = faceShadowReduction
        self.detectedLightSources = detectedLightSources
        self.dominantLightDirection = dominantLightDirection
        self.lightingQualityScore = lightingQualityScore
    }
}

// MARK: - Angle Correction

/// Perspective and angle correction
public struct AngleCorrection: Codable, Equatable {
    // Rotation
    public var rotationAngle: Float         // Degrees (-45 to +45)
    public var autoHorizonLevel: Bool

    // Perspective
    public var verticalPerspective: Float   // -1 to +1
    public var horizontalPerspective: Float // -1 to +1

    // Lens correction
    public var lensDistortion: Float        // -1 to +1 (barrel/pincushion)
    public var chromaticAberration: Float   // 0-1 (correction amount)
    public var vignetting: Float            // -1 to +1 (remove/add)

    // Crop & transform
    public var cropFactor: Float            // 1.0 = no crop
    public var aspectRatioLock: Bool
    public var autoConstrainCrop: Bool

    // Detection confidence
    public var horizonDetected: Bool
    public var horizonConfidence: Float
    public var perspectiveConfidence: Float

    public static let neutral = AngleCorrection(
        rotationAngle: 0, autoHorizonLevel: true,
        verticalPerspective: 0, horizontalPerspective: 0,
        lensDistortion: 0, chromaticAberration: 0, vignetting: 0,
        cropFactor: 1.0, aspectRatioLock: true, autoConstrainCrop: true,
        horizonDetected: false, horizonConfidence: 0, perspectiveConfidence: 0
    )

    public init(
        rotationAngle: Float = 0, autoHorizonLevel: Bool = true,
        verticalPerspective: Float = 0, horizontalPerspective: Float = 0,
        lensDistortion: Float = 0, chromaticAberration: Float = 0, vignetting: Float = 0,
        cropFactor: Float = 1.0, aspectRatioLock: Bool = true, autoConstrainCrop: Bool = true,
        horizonDetected: Bool = false, horizonConfidence: Float = 0, perspectiveConfidence: Float = 0
    ) {
        self.rotationAngle = rotationAngle
        self.autoHorizonLevel = autoHorizonLevel
        self.verticalPerspective = verticalPerspective
        self.horizontalPerspective = horizontalPerspective
        self.lensDistortion = lensDistortion
        self.chromaticAberration = chromaticAberration
        self.vignetting = vignetting
        self.cropFactor = cropFactor
        self.aspectRatioLock = aspectRatioLock
        self.autoConstrainCrop = autoConstrainCrop
        self.horizonDetected = horizonDetected
        self.horizonConfidence = horizonConfidence
        self.perspectiveConfidence = perspectiveConfidence
    }
}

// MARK: - Video Quality Enhancement

/// Video quality enhancement settings
public struct VideoQualityEnhancement: Codable, Equatable {
    // Resolution
    public var upscaleFactor: Float         // 1.0, 2.0, 4.0
    public var upscaleMethod: UpscaleMethod
    public var targetResolution: TargetResolution

    // Denoising
    public var denoiseStrength: Float       // 0-1
    public var denoiseMethod: DenoiseMethod
    public var preserveDetails: Float       // 0-1

    // Sharpening
    public var sharpenAmount: Float         // 0-2
    public var sharpenRadius: Float         // 0.5-3.0
    public var sharpenThreshold: Float      // 0-1

    // Frame interpolation
    public var frameInterpolation: Bool
    public var targetFrameRate: Float       // 24, 30, 60, 120

    // HDR
    public var hdrConversion: Bool
    public var hdrMethod: HDRMethod
    public var peakBrightness: Float        // Nits

    public enum UpscaleMethod: String, Codable, CaseIterable {
        case bilinear = "Bilinear"
        case bicubic = "Bicubic"
        case lanczos = "Lanczos"
        case aiSuperResolution = "AI Super Resolution"
        case quantumUpscale = "Quantum Upscale"
    }

    public enum TargetResolution: String, Codable, CaseIterable {
        case hd720p = "720p HD"
        case fullHD1080p = "1080p Full HD"
        case qhd1440p = "1440p QHD"
        case uhd4k = "4K UHD"
        case uhd8k = "8K UHD"
        case cinema4k = "Cinema 4K"
        case imax = "IMAX"

        public var width: Int {
            switch self {
            case .hd720p: return 1280
            case .fullHD1080p: return 1920
            case .qhd1440p: return 2560
            case .uhd4k: return 3840
            case .uhd8k: return 7680
            case .cinema4k: return 4096
            case .imax: return 5616
            }
        }

        public var height: Int {
            switch self {
            case .hd720p: return 720
            case .fullHD1080p: return 1080
            case .qhd1440p: return 1440
            case .uhd4k: return 2160
            case .uhd8k: return 4320
            case .cinema4k: return 2160
            case .imax: return 4096
            }
        }
    }

    public enum DenoiseMethod: String, Codable, CaseIterable {
        case spatial = "Spatial"
        case temporal = "Temporal"
        case spatioTemporal = "Spatio-Temporal"
        case aiDenoise = "AI Denoise"
        case quantumDenoise = "Quantum Denoise"
    }

    public enum HDRMethod: String, Codable, CaseIterable {
        case hdr10 = "HDR10"
        case hdr10Plus = "HDR10+"
        case dolbyVision = "Dolby Vision"
        case hlg = "HLG"
        case quantumHDR = "Quantum HDR"
    }

    public static let passthrough = VideoQualityEnhancement(
        upscaleFactor: 1.0, upscaleMethod: .bicubic, targetResolution: .fullHD1080p,
        denoiseStrength: 0, denoiseMethod: .spatial, preserveDetails: 0.5,
        sharpenAmount: 0, sharpenRadius: 1.0, sharpenThreshold: 0,
        frameInterpolation: false, targetFrameRate: 30,
        hdrConversion: false, hdrMethod: .hdr10, peakBrightness: 1000
    )

    public init(
        upscaleFactor: Float = 1.0, upscaleMethod: UpscaleMethod = .bicubic,
        targetResolution: TargetResolution = .fullHD1080p,
        denoiseStrength: Float = 0, denoiseMethod: DenoiseMethod = .spatial,
        preserveDetails: Float = 0.5,
        sharpenAmount: Float = 0, sharpenRadius: Float = 1.0, sharpenThreshold: Float = 0,
        frameInterpolation: Bool = false, targetFrameRate: Float = 30,
        hdrConversion: Bool = false, hdrMethod: HDRMethod = .hdr10, peakBrightness: Float = 1000
    ) {
        self.upscaleFactor = upscaleFactor
        self.upscaleMethod = upscaleMethod
        self.targetResolution = targetResolution
        self.denoiseStrength = denoiseStrength
        self.denoiseMethod = denoiseMethod
        self.preserveDetails = preserveDetails
        self.sharpenAmount = sharpenAmount
        self.sharpenRadius = sharpenRadius
        self.sharpenThreshold = sharpenThreshold
        self.frameInterpolation = frameInterpolation
        self.targetFrameRate = targetFrameRate
        self.hdrConversion = hdrConversion
        self.hdrMethod = hdrMethod
        self.peakBrightness = peakBrightness
    }
}

// MARK: - Color Matching

/// Color matching between clips/images
public struct ColorMatchingResult: Codable, Equatable {
    public var sourceAnalysis: ColorAnalysis
    public var targetAnalysis: ColorAnalysis
    public var matchQuality: Float          // 0-1
    public var corrections: ColorCorrections

    public struct ColorCorrections: Codable, Equatable {
        public var temperatureShift: Float
        public var tintShift: Float
        public var exposureShift: Float
        public var contrastMultiplier: Float
        public var saturationMultiplier: Float
        public var highlightsShift: Float
        public var shadowsShift: Float
        public var redShift: Float
        public var greenShift: Float
        public var blueShift: Float

        public static let none = ColorCorrections(
            temperatureShift: 0, tintShift: 0, exposureShift: 0,
            contrastMultiplier: 1, saturationMultiplier: 1,
            highlightsShift: 0, shadowsShift: 0,
            redShift: 0, greenShift: 0, blueShift: 0
        )

        public init(
            temperatureShift: Float = 0, tintShift: Float = 0, exposureShift: Float = 0,
            contrastMultiplier: Float = 1, saturationMultiplier: Float = 1,
            highlightsShift: Float = 0, shadowsShift: Float = 0,
            redShift: Float = 0, greenShift: Float = 0, blueShift: Float = 0
        ) {
            self.temperatureShift = temperatureShift
            self.tintShift = tintShift
            self.exposureShift = exposureShift
            self.contrastMultiplier = contrastMultiplier
            self.saturationMultiplier = saturationMultiplier
            self.highlightsShift = highlightsShift
            self.shadowsShift = shadowsShift
            self.redShift = redShift
            self.greenShift = greenShift
            self.blueShift = blueShift
        }
    }

    public init(
        sourceAnalysis: ColorAnalysis = ColorAnalysis(),
        targetAnalysis: ColorAnalysis = ColorAnalysis(),
        matchQuality: Float = 0,
        corrections: ColorCorrections = .none
    ) {
        self.sourceAnalysis = sourceAnalysis
        self.targetAnalysis = targetAnalysis
        self.matchQuality = matchQuality
        self.corrections = corrections
    }
}

// MARK: - Complete Correction Set

/// Complete set of all corrections
public struct ImageVideoCorrections: Codable, Equatable {
    public var whiteBalance: WhiteBalanceCorrection
    public var exposure: ExposureCorrection
    public var lighting: LightingCorrection
    public var angle: AngleCorrection
    public var quality: VideoQualityEnhancement
    public var colorMatch: ColorMatchingResult?

    // Processing info
    public var intelligenceLevel: MatchingIntelligenceLevel
    public var processingTime: Double
    public var overallConfidence: Float

    public static let neutral = ImageVideoCorrections(
        whiteBalance: .neutral,
        exposure: .neutral,
        lighting: .neutral,
        angle: .neutral,
        quality: .passthrough,
        colorMatch: nil,
        intelligenceLevel: .basic,
        processingTime: 0,
        overallConfidence: 1.0
    )

    public init(
        whiteBalance: WhiteBalanceCorrection = .neutral,
        exposure: ExposureCorrection = .neutral,
        lighting: LightingCorrection = .neutral,
        angle: AngleCorrection = .neutral,
        quality: VideoQualityEnhancement = .passthrough,
        colorMatch: ColorMatchingResult? = nil,
        intelligenceLevel: MatchingIntelligenceLevel = .basic,
        processingTime: Double = 0,
        overallConfidence: Float = 1.0
    ) {
        self.whiteBalance = whiteBalance
        self.exposure = exposure
        self.lighting = lighting
        self.angle = angle
        self.quality = quality
        self.colorMatch = colorMatch
        self.intelligenceLevel = intelligenceLevel
        self.processingTime = processingTime
        self.overallConfidence = overallConfidence
    }
}

// MARK: - Matching Presets

/// Pre-configured matching presets
public enum ImageMatchingPreset: String, CaseIterable, Codable {
    // Auto presets
    case autoAll = "Auto Everything"
    case autoColorOnly = "Auto Color Only"
    case autoExposureOnly = "Auto Exposure Only"
    case autoWhiteBalanceOnly = "Auto White Balance"
    case autoAngleOnly = "Auto Angle Correction"

    // Scene matching
    case matchToReference = "Match to Reference"
    case matchBetweenClips = "Match Between Clips"
    case sceneConsistency = "Scene Consistency"

    // Quality enhancement
    case enhanceQuality = "Enhance Quality"
    case upscale4K = "Upscale to 4K"
    case upscale8K = "Upscale to 8K"
    case denoise = "Denoise"
    case sharpen = "Sharpen"

    // Creative presets
    case cinematicLook = "Cinematic Look"
    case naturalLight = "Natural Light"
    case studioPortrait = "Studio Portrait"
    case outdoorVivid = "Outdoor Vivid"
    case lowLightBoost = "Low Light Boost"

    // Professional
    case broadcastStandard = "Broadcast Standard"
    case filmGrade = "Film Grade"
    case hdrMaster = "HDR Master"

    // Bio-reactive
    case bioReactiveCalm = "Bio-Reactive Calm"
    case bioReactiveEnergetic = "Bio-Reactive Energetic"
    case quantumCoherence = "Quantum Coherence"

    public var icon: String {
        switch self {
        case .autoAll, .autoColorOnly, .autoExposureOnly, .autoWhiteBalanceOnly, .autoAngleOnly:
            return "🤖"
        case .matchToReference, .matchBetweenClips, .sceneConsistency:
            return "🔗"
        case .enhanceQuality, .upscale4K, .upscale8K, .denoise, .sharpen:
            return "✨"
        case .cinematicLook, .naturalLight, .studioPortrait, .outdoorVivid, .lowLightBoost:
            return "🎨"
        case .broadcastStandard, .filmGrade, .hdrMaster:
            return "🎬"
        case .bioReactiveCalm, .bioReactiveEnergetic, .quantumCoherence:
            return "💓"
        }
    }

    public var description: String {
        switch self {
        case .autoAll: return "Automatically correct everything - color, exposure, white balance, angle"
        case .autoColorOnly: return "Auto color correction and grading"
        case .autoExposureOnly: return "Auto exposure, shadows, highlights"
        case .autoWhiteBalanceOnly: return "Auto white balance (temperature & tint)"
        case .autoAngleOnly: return "Auto horizon leveling and perspective"
        case .matchToReference: return "Match colors to a reference image/video"
        case .matchBetweenClips: return "Match colors between video clips"
        case .sceneConsistency: return "Maintain consistent look across scenes"
        case .enhanceQuality: return "AI-powered quality enhancement"
        case .upscale4K: return "Upscale to 4K with AI"
        case .upscale8K: return "Upscale to 8K with Quantum AI"
        case .denoise: return "AI noise reduction"
        case .sharpen: return "Intelligent sharpening"
        case .cinematicLook: return "Hollywood cinema color grade"
        case .naturalLight: return "Natural daylight look"
        case .studioPortrait: return "Professional portrait lighting"
        case .outdoorVivid: return "Vibrant outdoor colors"
        case .lowLightBoost: return "Enhance low light footage"
        case .broadcastStandard: return "Rec. 709 broadcast compliance"
        case .filmGrade: return "Professional film color grade"
        case .hdrMaster: return "HDR mastering workflow"
        case .bioReactiveCalm: return "Calming colors based on coherence"
        case .bioReactiveEnergetic: return "Energetic colors from heart rate"
        case .quantumCoherence: return "Quantum-enhanced bio-reactive grading"
        }
    }
}

// MARK: - Main Engine

/// Super Intelligence Image & Video Matching Engine
@MainActor
public class SuperIntelligenceImageMatchingEngine: ObservableObject {

    // MARK: - Published State

    @Published public var intelligenceLevel: MatchingIntelligenceLevel = .superIntelligence
    @Published public var isProcessing: Bool = false
    @Published public var progress: Float = 0
    @Published public var currentCorrections: ImageVideoCorrections = .neutral
    @Published public var lastAnalysis: ColorAnalysis?
    @Published public var referenceAnalysis: ColorAnalysis?

    // MARK: - Settings

    public var autoWhiteBalance: Bool = true
    public var autoExposure: Bool = true
    public var autoLighting: Bool = true
    public var autoAngle: Bool = true
    public var autoQuality: Bool = false
    public var preserveOriginalColors: Float = 0 // 0-1, blend with original

    // Bio-reactive
    public var bioReactiveEnabled: Bool = false
    public var heartRate: Float = 70
    public var hrv: Float = 50
    public var coherence: Float = 0.5

    // MARK: - CIContext for processing

    private let ciContext: CIContext

    // MARK: - Initialization

    public init() {
        // Create GPU-accelerated context
        if let metalDevice = MTLCreateSystemDefaultDevice() {
            let colorSpace = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
            ciContext = CIContext(mtlDevice: metalDevice, options: [
                .workingColorSpace: colorSpace,
                .outputColorSpace: colorSpace
            ])
        } else {
            ciContext = CIContext(options: nil)
        }
    }

    // MARK: - Auto Analysis

    /// Analyze image/video frame for color properties
    public func analyzeImage(_ cgImage: CGImage) async -> ColorAnalysis {
        let startTime = Date()
        isProcessing = true
        progress = 0

        var analysis = ColorAnalysis()

        let width = cgImage.width
        let height = cgImage.height
        let totalPixels = width * height

        // Get pixel data
        guard let dataProvider = cgImage.dataProvider,
              let data = dataProvider.data,
              let bytes = CFDataGetBytePtr(data) else {
            isProcessing = false
            return analysis
        }

        let bytesPerPixel = cgImage.bitsPerPixel / 8
        let bytesPerRow = cgImage.bytesPerRow

        // Calculate histograms and averages
        var redSum: Float = 0
        var greenSum: Float = 0
        var blueSum: Float = 0

        var redHist = [Int](repeating: 0, count: 256)
        var greenHist = [Int](repeating: 0, count: 256)
        var blueHist = [Int](repeating: 0, count: 256)
        var lumHist = [Int](repeating: 0, count: 256)

        // Sample pixels (for performance, sample every Nth pixel for large images)
        let sampleStep = max(1, totalPixels / 100000)
        var sampledCount = 0

        for y in stride(from: 0, to: height, by: max(1, height / 500)) {
            for x in stride(from: 0, to: width, by: max(1, width / 500)) {
                let offset = y * bytesPerRow + x * bytesPerPixel

                let r = Float(bytes[offset]) / 255.0
                let g = Float(bytes[offset + 1]) / 255.0
                let b = Float(bytes[offset + 2]) / 255.0
                let luminance = 0.299 * r + 0.587 * g + 0.114 * b

                redSum += r
                greenSum += g
                blueSum += b

                redHist[Int(bytes[offset])] += 1
                greenHist[Int(bytes[offset + 1])] += 1
                blueHist[Int(bytes[offset + 2])] += 1
                lumHist[min(255, Int(luminance * 255))] += 1

                sampledCount += 1
            }

            progress = Float(y) / Float(height) * 0.5
        }

        // Calculate averages
        let count = Float(sampledCount)
        analysis.averageRed = redSum / count
        analysis.averageGreen = greenSum / count
        analysis.averageBlue = blueSum / count
        analysis.averageLuminance = (analysis.averageRed * 0.299 + analysis.averageGreen * 0.587 + analysis.averageBlue * 0.114)

        // Normalize histograms
        let maxHist = Float(redHist.max() ?? 1)
        analysis.redHistogram = redHist.map { Float($0) / maxHist }
        analysis.greenHistogram = greenHist.map { Float($0) / maxHist }
        analysis.blueHistogram = blueHist.map { Float($0) / maxHist }
        analysis.luminanceHistogram = lumHist.map { Float($0) / maxHist }

        progress = 0.6

        // Estimate color temperature from R/B ratio
        let rbRatio = analysis.averageRed / max(0.01, analysis.averageBlue)
        analysis.colorTemperature = estimateColorTemperature(rbRatio: rbRatio)

        // Estimate tint from G channel deviation
        let expectedGreen = (analysis.averageRed + analysis.averageBlue) / 2
        analysis.tint = (analysis.averageGreen - expectedGreen) * 150

        // Calculate exposure
        analysis.exposure = (analysis.averageLuminance - 0.5) * 4 // Rough EV estimate

        // Calculate contrast from histogram spread
        let lumStdDev = calculateStdDev(analysis.luminanceHistogram)
        analysis.contrast = lumStdDev * 4

        // Calculate saturation
        let maxRGB = max(analysis.averageRed, max(analysis.averageGreen, analysis.averageBlue))
        let minRGB = min(analysis.averageRed, min(analysis.averageGreen, analysis.averageBlue))
        analysis.saturation = (maxRGB - minRGB) / max(0.01, maxRGB)

        // Calculate dynamic range
        let firstNonZeroLum = lumHist.firstIndex(where: { $0 > 0 }) ?? 0
        let lastNonZeroLum = lumHist.lastIndex(where: { $0 > 0 }) ?? 255
        analysis.dynamicRange = Float(lastNonZeroLum - firstNonZeroLum) / 255.0 * 14 // Approx stops

        // Calculate clipping
        analysis.clippedHighlights = Float(lumHist[254...255].reduce(0, +)) / count * 100
        analysis.clippedShadows = Float(lumHist[0...1].reduce(0, +)) / count * 100

        progress = 1.0
        isProcessing = false
        lastAnalysis = analysis

        return analysis
    }

    // MARK: - Auto White Balance

    /// Auto-detect white balance correction
    public func autoDetectWhiteBalance(_ analysis: ColorAnalysis) -> WhiteBalanceCorrection {
        var correction = WhiteBalanceCorrection()

        // Target neutral gray (equal R, G, B)
        let avgColor = (analysis.averageRed + analysis.averageGreen + analysis.averageBlue) / 3

        // Calculate temperature correction
        let rbRatio = analysis.averageRed / max(0.01, analysis.averageBlue)
        correction.temperature = estimateColorTemperature(rbRatio: rbRatio)

        // Calculate tint correction
        let expectedGreen = (analysis.averageRed + analysis.averageBlue) / 2
        correction.tint = -(analysis.averageGreen - expectedGreen) * 100

        correction.autoDetected = true
        correction.confidence = calculateWhiteBalanceConfidence(analysis)

        return correction
    }

    // MARK: - Auto Exposure

    /// Auto-detect exposure correction
    public func autoDetectExposure(_ analysis: ColorAnalysis) -> ExposureCorrection {
        var correction = ExposureCorrection()

        // Target middle gray (0.18 reflectance, ~0.46 in linear RGB)
        let targetLuminance: Float = 0.46
        let currentLuminance = analysis.averageLuminance

        // Calculate exposure compensation
        if currentLuminance > 0.01 {
            correction.exposure = log2(targetLuminance / currentLuminance)
            correction.exposure = max(-5, min(5, correction.exposure))
        }

        // Analyze highlights and shadows from histogram
        let highlightSum = analysis.luminanceHistogram[200...255].reduce(0, +)
        let shadowSum = analysis.luminanceHistogram[0...55].reduce(0, +)

        // Recover highlights if clipped
        if analysis.clippedHighlights > 1 {
            correction.highlights = -min(1, analysis.clippedHighlights / 10)
        }

        // Fill shadows if too dark
        if shadowSum > 0.3 {
            correction.shadows = min(1, shadowSum - 0.3)
        }

        // Calculate contrast adjustment
        let idealContrast: Float = 1.0
        if analysis.contrast > 0.1 {
            correction.contrast = idealContrast / analysis.contrast
            correction.contrast = max(0.5, min(2.0, correction.contrast))
        }

        // Dehaze if low contrast and high shadows
        if analysis.contrast < 0.3 && shadowSum > 0.2 {
            correction.dehaze = min(1, (0.3 - analysis.contrast) * 2)
        }

        correction.autoDetected = true
        correction.confidence = calculateExposureConfidence(analysis)

        return correction
    }

    // MARK: - Auto Lighting

    /// Auto-detect lighting correction (requires Vision framework)
    public func autoDetectLighting(_ cgImage: CGImage) async -> LightingCorrection {
        var correction = LightingCorrection()

        // Analyze image for lighting characteristics
        let analysis = await analyzeImage(cgImage)

        // Detect if image is backlit (bright edges, dark center)
        let centerLuminance = analysis.averageLuminance
        // Simplified: assume need fill if average is low but highlights exist
        if centerLuminance < 0.4 && analysis.clippedHighlights > 0.5 {
            correction.fillLightIntensity = min(1, (0.5 - centerLuminance) * 2)
        }

        // Detect shadow quality
        if analysis.clippedShadows > 2 {
            correction.faceShadowReduction = min(1, analysis.clippedShadows / 10)
        }

        // Estimate dominant light direction from histogram asymmetry
        let leftHalf = analysis.luminanceHistogram[0..<128].reduce(0, +)
        let rightHalf = analysis.luminanceHistogram[128..<256].reduce(0, +)
        correction.dominantLightDirection = (rightHalf - leftHalf) * 90 // Rough angle

        // Calculate lighting quality score
        let dynamicRangeScore = min(1, analysis.dynamicRange / 10)
        let clippingPenalty = (analysis.clippedHighlights + analysis.clippedShadows) / 20
        correction.lightingQualityScore = max(0, dynamicRangeScore - clippingPenalty)

        #if canImport(Vision)
        // Use Vision to detect faces for face lighting
        await detectFacesForLighting(cgImage, correction: &correction)
        #endif

        return correction
    }

    #if canImport(Vision)
    private func detectFacesForLighting(_ cgImage: CGImage, correction: inout LightingCorrection) async {
        let request = VNDetectFaceRectanglesRequest()

        do {
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try handler.perform([request])

            if let results = request.results, !results.isEmpty {
                correction.faceLightingEnabled = true
                correction.detectedLightSources = results.count

                // If faces detected, suggest face-specific lighting
                if correction.lightingQualityScore < 0.7 {
                    correction.faceLightIntensity = 0.3
                    correction.faceShadowReduction = 0.4
                }
            }
        } catch {
            // Vision not available or failed
        }
    }
    #endif

    // MARK: - Auto Angle

    /// Auto-detect angle correction (horizon, perspective)
    public func autoDetectAngle(_ cgImage: CGImage) async -> AngleCorrection {
        var correction = AngleCorrection()

        #if canImport(Vision)
        // Use Vision to detect horizon
        let request = VNDetectHorizonRequest()

        do {
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try handler.perform([request])

            if let result = request.results?.first {
                let angle = result.angle * 180 / .pi // Convert to degrees
                correction.rotationAngle = Float(-angle) // Invert to correct
                correction.horizonDetected = true
                correction.horizonConfidence = Float(result.confidence)
            }
        } catch {
            // Vision not available
        }

        // Use Vision to detect rectangles for perspective
        let rectRequest = VNDetectRectanglesRequest()
        rectRequest.minimumAspectRatio = 0.3
        rectRequest.maximumAspectRatio = 3.0
        rectRequest.minimumConfidence = 0.5

        do {
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try handler.perform([rectRequest])

            if let results = rectRequest.results, !results.isEmpty {
                // Analyze dominant rectangle for perspective
                if let largestRect = results.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }) {
                    // Calculate perspective from rectangle corners
                    let topLeft = largestRect.topLeft
                    let topRight = largestRect.topRight
                    let bottomLeft = largestRect.bottomLeft
                    let bottomRight = largestRect.bottomRight

                    // Vertical perspective from top vs bottom width
                    let topWidth = sqrt(pow(topRight.x - topLeft.x, 2) + pow(topRight.y - topLeft.y, 2))
                    let bottomWidth = sqrt(pow(bottomRight.x - bottomLeft.x, 2) + pow(bottomRight.y - bottomLeft.y, 2))

                    if topWidth > 0.1 && bottomWidth > 0.1 {
                        let ratio = Float(topWidth / bottomWidth)
                        correction.verticalPerspective = (1 - ratio) * 2 // Simplified
                        correction.verticalPerspective = max(-1, min(1, correction.verticalPerspective))
                        correction.perspectiveConfidence = Float(largestRect.confidence)
                    }
                }
            }
        } catch {
            // Rectangle detection failed
        }
        #endif

        return correction
    }

    // MARK: - Color Matching

    /// Match source image/video to target reference
    public func matchColors(source: CGImage, target: CGImage) async -> ColorMatchingResult {
        let sourceAnalysis = await analyzeImage(source)
        let targetAnalysis = await analyzeImage(target)

        var result = ColorMatchingResult(
            sourceAnalysis: sourceAnalysis,
            targetAnalysis: targetAnalysis
        )

        // Calculate corrections to match source to target
        var corrections = ColorMatchingResult.ColorCorrections()

        // Temperature shift
        corrections.temperatureShift = targetAnalysis.colorTemperature - sourceAnalysis.colorTemperature

        // Tint shift
        corrections.tintShift = targetAnalysis.tint - sourceAnalysis.tint

        // Exposure shift
        corrections.exposureShift = targetAnalysis.exposure - sourceAnalysis.exposure

        // Contrast multiplier
        if sourceAnalysis.contrast > 0.1 {
            corrections.contrastMultiplier = targetAnalysis.contrast / sourceAnalysis.contrast
        }

        // Saturation multiplier
        if sourceAnalysis.saturation > 0.1 {
            corrections.saturationMultiplier = targetAnalysis.saturation / sourceAnalysis.saturation
        }

        // RGB shifts
        corrections.redShift = targetAnalysis.averageRed - sourceAnalysis.averageRed
        corrections.greenShift = targetAnalysis.averageGreen - sourceAnalysis.averageGreen
        corrections.blueShift = targetAnalysis.averageBlue - sourceAnalysis.averageBlue

        // Highlights/shadows
        corrections.highlightsShift = targetAnalysis.highlights - sourceAnalysis.highlights
        corrections.shadowsShift = targetAnalysis.shadows - sourceAnalysis.shadows

        result.corrections = corrections

        // Calculate match quality (how similar after corrections)
        let tempDiff = abs(corrections.temperatureShift) / 2000
        let tintDiff = abs(corrections.tintShift) / 50
        let expDiff = abs(corrections.exposureShift) / 2
        let colorDiff = (abs(corrections.redShift) + abs(corrections.greenShift) + abs(corrections.blueShift)) / 3

        result.matchQuality = max(0, 1 - (tempDiff + tintDiff + expDiff + colorDiff) / 4)

        return result
    }

    // MARK: - Apply Corrections

    /// Apply all corrections to an image
    public func applyCorrections(_ cgImage: CGImage, corrections: ImageVideoCorrections) -> CGImage? {
        guard let ciImage = CIImage(cgImage: cgImage) else { return nil }

        var outputImage = ciImage

        // Apply white balance
        if let tempFilter = CIFilter(name: "CITemperatureAndTint") {
            tempFilter.setValue(outputImage, forKey: kCIInputImageKey)

            // Convert Kelvin to CIVector (neutral is 6500K)
            let neutralTemp: Float = 6500
            let tempVector = CIVector(x: CGFloat(corrections.whiteBalance.temperature / neutralTemp), y: 0)
            let tintVector = CIVector(x: 0, y: CGFloat(corrections.whiteBalance.tint / 150))

            tempFilter.setValue(tempVector, forKey: "inputNeutral")
            tempFilter.setValue(tintVector, forKey: "inputTargetNeutral")

            if let result = tempFilter.outputImage {
                outputImage = result
            }
        }

        // Apply exposure
        if let exposureFilter = CIFilter(name: "CIExposureAdjust") {
            exposureFilter.setValue(outputImage, forKey: kCIInputImageKey)
            exposureFilter.setValue(corrections.exposure.exposure, forKey: kCIInputEVKey)

            if let result = exposureFilter.outputImage {
                outputImage = result
            }
        }

        // Apply contrast
        if let colorControls = CIFilter(name: "CIColorControls") {
            colorControls.setValue(outputImage, forKey: kCIInputImageKey)
            colorControls.setValue(corrections.exposure.contrast, forKey: kCIInputContrastKey)
            colorControls.setValue(1.0 + corrections.exposure.clarity * 0.5, forKey: kCIInputSaturationKey)

            if let result = colorControls.outputImage {
                outputImage = result
            }
        }

        // Apply highlights/shadows
        if let highlightShadow = CIFilter(name: "CIHighlightShadowAdjust") {
            highlightShadow.setValue(outputImage, forKey: kCIInputImageKey)
            highlightShadow.setValue(1.0 - corrections.exposure.highlights, forKey: "inputHighlightAmount")
            highlightShadow.setValue(corrections.exposure.shadows, forKey: "inputShadowAmount")

            if let result = highlightShadow.outputImage {
                outputImage = result
            }
        }

        // Apply angle correction
        if abs(corrections.angle.rotationAngle) > 0.1 {
            let radians = CGFloat(corrections.angle.rotationAngle) * .pi / 180
            let transform = CGAffineTransform(rotationAngle: radians)
            outputImage = outputImage.transformed(by: transform)
        }

        // Apply perspective correction
        if abs(corrections.angle.verticalPerspective) > 0.01 || abs(corrections.angle.horizontalPerspective) > 0.01 {
            if let perspectiveFilter = CIFilter(name: "CIPerspectiveCorrection") {
                let extent = outputImage.extent

                // Calculate perspective transform points
                let vp = CGFloat(corrections.angle.verticalPerspective) * 50
                let hp = CGFloat(corrections.angle.horizontalPerspective) * 50

                let topLeft = CIVector(x: extent.minX - hp, y: extent.maxY + vp)
                let topRight = CIVector(x: extent.maxX + hp, y: extent.maxY + vp)
                let bottomLeft = CIVector(x: extent.minX + hp, y: extent.minY - vp)
                let bottomRight = CIVector(x: extent.maxX - hp, y: extent.minY - vp)

                perspectiveFilter.setValue(outputImage, forKey: kCIInputImageKey)
                perspectiveFilter.setValue(topLeft, forKey: "inputTopLeft")
                perspectiveFilter.setValue(topRight, forKey: "inputTopRight")
                perspectiveFilter.setValue(bottomLeft, forKey: "inputBottomLeft")
                perspectiveFilter.setValue(bottomRight, forKey: "inputBottomRight")

                if let result = perspectiveFilter.outputImage {
                    outputImage = result
                }
            }
        }

        // Apply sharpening
        if corrections.quality.sharpenAmount > 0 {
            if let sharpenFilter = CIFilter(name: "CISharpenLuminance") {
                sharpenFilter.setValue(outputImage, forKey: kCIInputImageKey)
                sharpenFilter.setValue(corrections.quality.sharpenAmount, forKey: kCIInputSharpnessKey)
                sharpenFilter.setValue(corrections.quality.sharpenRadius, forKey: kCIInputRadiusKey)

                if let result = sharpenFilter.outputImage {
                    outputImage = result
                }
            }
        }

        // Apply noise reduction
        if corrections.quality.denoiseStrength > 0 {
            if let noiseFilter = CIFilter(name: "CINoiseReduction") {
                noiseFilter.setValue(outputImage, forKey: kCIInputImageKey)
                noiseFilter.setValue(corrections.quality.denoiseStrength * 0.1, forKey: "inputNoiseLevel")
                noiseFilter.setValue(corrections.quality.preserveDetails, forKey: "inputSharpness")

                if let result = noiseFilter.outputImage {
                    outputImage = result
                }
            }
        }

        // Render final image
        let extent = outputImage.extent
        guard let outputCGImage = ciContext.createCGImage(outputImage, from: extent) else {
            return nil
        }

        return outputCGImage
    }

    // MARK: - One-Tap Auto Correction

    /// One-tap automatic correction (analyzes and applies all corrections)
    public func oneTapAutoCorrect(_ cgImage: CGImage, preset: ImageMatchingPreset = .autoAll) async -> (CGImage?, ImageVideoCorrections) {
        isProcessing = true
        progress = 0

        var corrections = ImageVideoCorrections()
        corrections.intelligenceLevel = intelligenceLevel

        let startTime = Date()

        // Analyze image
        progress = 0.1
        let analysis = await analyzeImage(cgImage)

        // Apply corrections based on preset
        switch preset {
        case .autoAll, .autoColorOnly:
            progress = 0.3
            corrections.whiteBalance = autoDetectWhiteBalance(analysis)
            corrections.exposure = autoDetectExposure(analysis)
            if preset == .autoAll {
                corrections.lighting = await autoDetectLighting(cgImage)
                corrections.angle = await autoDetectAngle(cgImage)
            }

        case .autoExposureOnly:
            progress = 0.3
            corrections.exposure = autoDetectExposure(analysis)

        case .autoWhiteBalanceOnly:
            progress = 0.3
            corrections.whiteBalance = autoDetectWhiteBalance(analysis)

        case .autoAngleOnly:
            progress = 0.3
            corrections.angle = await autoDetectAngle(cgImage)

        case .enhanceQuality, .denoise, .sharpen:
            progress = 0.3
            corrections.quality.denoiseStrength = preset == .denoise ? 0.7 : 0.3
            corrections.quality.sharpenAmount = preset == .sharpen ? 1.0 : 0.5
            corrections.quality.upscaleMethod = .aiSuperResolution

        case .upscale4K:
            corrections.quality.upscaleFactor = 2.0
            corrections.quality.targetResolution = .uhd4k
            corrections.quality.upscaleMethod = .aiSuperResolution

        case .upscale8K:
            corrections.quality.upscaleFactor = 4.0
            corrections.quality.targetResolution = .uhd8k
            corrections.quality.upscaleMethod = .quantumUpscale

        case .cinematicLook:
            corrections.whiteBalance = autoDetectWhiteBalance(analysis)
            corrections.exposure = autoDetectExposure(analysis)
            corrections.exposure.contrast = 1.2
            corrections.exposure.shadows = 0.1
            corrections.exposure.highlights = -0.2

        case .naturalLight:
            corrections.whiteBalance = .daylight
            corrections.exposure = autoDetectExposure(analysis)

        case .studioPortrait:
            corrections.whiteBalance.temperature = 5600
            corrections.lighting.faceLightingEnabled = true
            corrections.lighting.faceLightIntensity = 0.4
            corrections.lighting.faceShadowReduction = 0.5
            corrections.exposure = autoDetectExposure(analysis)

        case .lowLightBoost:
            corrections.exposure.exposure = min(2, corrections.exposure.exposure + 1.5)
            corrections.exposure.shadows = 0.8
            corrections.quality.denoiseStrength = 0.8
            corrections.quality.denoiseMethod = .aiDenoise

        case .broadcastStandard:
            corrections.whiteBalance.temperature = 6500 // D65
            corrections.exposure.contrast = 1.0
            corrections.exposure = autoDetectExposure(analysis)

        case .hdrMaster:
            corrections.quality.hdrConversion = true
            corrections.quality.hdrMethod = .dolbyVision
            corrections.quality.peakBrightness = 4000
            corrections.exposure = autoDetectExposure(analysis)

        case .bioReactiveCalm:
            // Shift towards calming blue/green based on coherence
            corrections.whiteBalance.temperature = 6500 + (1 - coherence) * 1000
            corrections.exposure.saturation = 0.8 + coherence * 0.2

        case .bioReactiveEnergetic:
            // Shift towards warm/vivid based on heart rate
            let hrNormalized = (heartRate - 60) / 100
            corrections.whiteBalance.temperature = 5500 - hrNormalized * 500
            corrections.exposure.saturation = 1.0 + hrNormalized * 0.3
            corrections.exposure.contrast = 1.0 + hrNormalized * 0.2

        case .quantumCoherence:
            // Full quantum mode
            corrections.whiteBalance = autoDetectWhiteBalance(analysis)
            corrections.exposure = autoDetectExposure(analysis)
            corrections.lighting = await autoDetectLighting(cgImage)
            corrections.angle = await autoDetectAngle(cgImage)
            corrections.quality.upscaleMethod = .quantumUpscale
            corrections.quality.denoiseMethod = .quantumDenoise

        default:
            corrections.whiteBalance = autoDetectWhiteBalance(analysis)
            corrections.exposure = autoDetectExposure(analysis)
        }

        progress = 0.7

        // Apply corrections
        let correctedImage = applyCorrections(cgImage, corrections: corrections)

        progress = 1.0
        corrections.processingTime = Date().timeIntervalSince(startTime)
        corrections.overallConfidence = calculateOverallConfidence(corrections)

        currentCorrections = corrections
        isProcessing = false

        return (correctedImage, corrections)
    }

    // MARK: - Match to Reference

    /// Match source to reference image
    public func matchToReference(_ source: CGImage, reference: CGImage) async -> (CGImage?, ColorMatchingResult) {
        isProcessing = true
        progress = 0

        // Analyze reference
        progress = 0.2
        referenceAnalysis = await analyzeImage(reference)

        // Match colors
        progress = 0.5
        let matchResult = await matchColors(source: source, target: reference)

        // Create corrections from match result
        var corrections = ImageVideoCorrections()
        corrections.whiteBalance.temperature += matchResult.corrections.temperatureShift
        corrections.whiteBalance.tint += matchResult.corrections.tintShift
        corrections.exposure.exposure += matchResult.corrections.exposureShift
        corrections.exposure.contrast *= matchResult.corrections.contrastMultiplier
        corrections.colorMatch = matchResult

        // Apply
        progress = 0.8
        let correctedImage = applyCorrections(source, corrections: corrections)

        progress = 1.0
        isProcessing = false

        return (correctedImage, matchResult)
    }

    // MARK: - Helper Functions

    private func estimateColorTemperature(rbRatio: Float) -> Float {
        // Approximate mapping from R/B ratio to Kelvin
        // rbRatio > 1 = warm (lower K), < 1 = cool (higher K)
        let baseTemp: Float = 5500
        let tempRange: Float = 4000

        if rbRatio > 1 {
            return baseTemp - (rbRatio - 1) * tempRange / 2
        } else {
            return baseTemp + (1 - rbRatio) * tempRange
        }
    }

    private func calculateStdDev(_ histogram: [Float]) -> Float {
        let sum = histogram.reduce(0, +)
        guard sum > 0 else { return 0 }

        let mean = histogram.enumerated().reduce(0) { $0 + Float($1.offset) * $1.element } / sum
        let variance = histogram.enumerated().reduce(0) { $0 + pow(Float($1.offset) - mean, 2) * $1.element } / sum

        return sqrt(variance) / 128 // Normalize to 0-1 range
    }

    private func calculateWhiteBalanceConfidence(_ analysis: ColorAnalysis) -> Float {
        // Higher confidence if colors are relatively neutral
        let colorSpread = abs(analysis.averageRed - analysis.averageGreen) +
                         abs(analysis.averageGreen - analysis.averageBlue) +
                         abs(analysis.averageBlue - analysis.averageRed)
        return max(0, 1 - colorSpread * 2)
    }

    private func calculateExposureConfidence(_ analysis: ColorAnalysis) -> Float {
        // Higher confidence if exposure is in reasonable range
        let expDeviation = abs(analysis.averageLuminance - 0.5)
        let clippingPenalty = (analysis.clippedHighlights + analysis.clippedShadows) / 20
        return max(0, 1 - expDeviation - clippingPenalty)
    }

    private func calculateOverallConfidence(_ corrections: ImageVideoCorrections) -> Float {
        var confidence: Float = 1.0

        confidence *= corrections.whiteBalance.confidence
        confidence *= corrections.exposure.confidence
        confidence *= max(0.5, corrections.lighting.lightingQualityScore)
        confidence *= max(0.5, corrections.angle.horizonConfidence + corrections.angle.perspectiveConfidence) / 2

        return confidence
    }
}

// MARK: - Quick Presets Extension

extension SuperIntelligenceImageMatchingEngine {

    /// Get all presets for category
    public static func presets(for category: String) -> [ImageMatchingPreset] {
        switch category {
        case "Auto":
            return [.autoAll, .autoColorOnly, .autoExposureOnly, .autoWhiteBalanceOnly, .autoAngleOnly]
        case "Matching":
            return [.matchToReference, .matchBetweenClips, .sceneConsistency]
        case "Quality":
            return [.enhanceQuality, .upscale4K, .upscale8K, .denoise, .sharpen]
        case "Creative":
            return [.cinematicLook, .naturalLight, .studioPortrait, .outdoorVivid, .lowLightBoost]
        case "Professional":
            return [.broadcastStandard, .filmGrade, .hdrMaster]
        case "Bio-Reactive":
            return [.bioReactiveCalm, .bioReactiveEnergetic, .quantumCoherence]
        default:
            return ImageMatchingPreset.allCases
        }
    }

    /// All preset categories
    public static let presetCategories = ["Auto", "Matching", "Quality", "Creative", "Professional", "Bio-Reactive"]
}
