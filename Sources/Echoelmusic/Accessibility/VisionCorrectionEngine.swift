// VisionCorrectionEngine.swift
// Echoelmusic - Advanced Vision Correction & Testing
//
// Features:
// - Built-in vision tests (Sehtest)
// - Strabismus (Schielen) detection & correction
// - Different eye strengths (Anisometropia) compensation
// - Smart Glasses / VR headset lens correction
// - Real-time adaptation per eye

import Foundation
import Combine
import simd
import CoreGraphics

// MARK: - Vision Profile

/// Complete vision profile for both eyes
public struct VisionProfile: Codable {
    public var leftEye: EyeProfile
    public var rightEye: EyeProfile
    public var binocularVision: BinocularProfile
    public var lastTestDate: Date?
    public var needsCorrection: Bool {
        leftEye.needsCorrection || rightEye.needsCorrection || binocularVision.hasStrabismus
    }

    public struct EyeProfile: Codable {
        public var visualAcuity: Double        // 20/20 = 1.0, 20/40 = 0.5
        public var spherical: Double           // Diopter (-/+ for near/farsighted)
        public var cylindrical: Double         // Diopter (astigmatism)
        public var axis: Double                // Degrees (0-180)
        public var nearVision: Double          // Reading distance acuity
        public var farVision: Double           // Distance acuity
        public var contrastSensitivity: Double // 0-1
        public var colorVision: ColorVisionResult
        public var pupilDistance: Double       // mm from center

        public var needsCorrection: Bool {
            abs(spherical) > 0.5 || abs(cylindrical) > 0.5 || visualAcuity < 0.8
        }

        public var correctionDescription: String {
            var desc = ""
            if spherical < 0 {
                desc += "Kurzsichtig (Myopie) "
            } else if spherical > 0 {
                desc += "Weitsichtig (Hyperopie) "
            }
            if abs(cylindrical) > 0.5 {
                desc += "mit Hornhautverkrümmung (Astigmatismus)"
            }
            return desc.isEmpty ? "Normale Sehstärke" : desc
        }
    }

    public struct BinocularProfile: Codable {
        public var interpupillaryDistance: Double  // IPD in mm
        public var convergence: ConvergenceType
        public var strabismusType: StrabismusType
        public var strabismusAngle: Double         // Degrees of deviation
        public var dominantEye: DominantEye
        public var stereopsis: Double              // Depth perception (arc seconds)
        public var fusionAbility: Double           // 0-1 ability to merge images

        public var hasStrabismus: Bool {
            strabismusType != .none && strabismusAngle > 2
        }
    }

    public enum ConvergenceType: String, Codable {
        case normal = "Normal"
        case insufficiency = "Convergence Insufficiency"
        case excess = "Convergence Excess"
    }

    public enum StrabismusType: String, Codable {
        case none = "None"
        case esotropia = "Esotropia (inward)"       // Einwärtsschielen
        case exotropia = "Exotropia (outward)"      // Auswärtsschielen
        case hypertropia = "Hypertropia (upward)"   // Höhenschielen aufwärts
        case hypotropia = "Hypotropia (downward)"   // Höhenschielen abwärts
        case alternating = "Alternating"            // Wechselschielen

        public var germanName: String {
            switch self {
            case .none: return "Kein Schielen"
            case .esotropia: return "Einwärtsschielen"
            case .exotropia: return "Auswärtsschielen"
            case .hypertropia: return "Höhenschielen (aufwärts)"
            case .hypotropia: return "Höhenschielen (abwärts)"
            case .alternating: return "Wechselschielen"
            }
        }
    }

    public enum DominantEye: String, Codable {
        case left = "Left"
        case right = "Right"
        case none = "No dominance"
    }

    public struct ColorVisionResult: Codable {
        public var type: ColorVisionType
        public var severity: Double  // 0-1
        public var confusedColors: [(String, String)]  // Color pairs that are confused

        public enum ColorVisionType: String, Codable {
            case normal = "Normal"
            case protanomaly = "Protanomaly (red-weak)"
            case protanopia = "Protanopia (red-blind)"
            case deuteranomaly = "Deuteranomaly (green-weak)"
            case deuteranopia = "Deuteranopia (green-blind)"
            case tritanomaly = "Tritanomaly (blue-weak)"
            case tritanopia = "Tritanopia (blue-blind)"
            case achromatopsia = "Achromatopsia (total color blindness)"
        }
    }

    public static var `default`: VisionProfile {
        VisionProfile(
            leftEye: EyeProfile(
                visualAcuity: 1.0,
                spherical: 0,
                cylindrical: 0,
                axis: 0,
                nearVision: 1.0,
                farVision: 1.0,
                contrastSensitivity: 1.0,
                colorVision: ColorVisionResult(type: .normal, severity: 0, confusedColors: []),
                pupilDistance: 32
            ),
            rightEye: EyeProfile(
                visualAcuity: 1.0,
                spherical: 0,
                cylindrical: 0,
                axis: 0,
                nearVision: 1.0,
                farVision: 1.0,
                contrastSensitivity: 1.0,
                colorVision: ColorVisionResult(type: .normal, severity: 0, confusedColors: []),
                pupilDistance: 32
            ),
            binocularVision: BinocularProfile(
                interpupillaryDistance: 64,
                convergence: .normal,
                strabismusType: .none,
                strabismusAngle: 0,
                dominantEye: .right,
                stereopsis: 40,
                fusionAbility: 1.0
            ),
            lastTestDate: nil
        )
    }
}

// MARK: - Vision Test Engine

/// Built-in vision testing system
public final class VisionTestEngine: ObservableObject {

    public static let shared = VisionTestEngine()

    @Published public var currentTest: VisionTest?
    @Published public var testResults: VisionProfile = .default
    @Published public var isTestInProgress: Bool = false

    public enum VisionTest: String, CaseIterable {
        case visualAcuity = "Sehschärfe-Test"
        case astigmatism = "Astigmatismus-Test"
        case colorVision = "Farbsehen-Test"
        case contrast = "Kontrast-Test"
        case strabismus = "Schiel-Test"
        case dominantEye = "Dominantes Auge"
        case depthPerception = "Tiefenwahrnehmung"
        case nearVision = "Nahsicht-Test"

        public var description: String {
            switch self {
            case .visualAcuity:
                return "Testet die Sehschärfe mit Landolt-Ringen oder Snellen-Buchstaben"
            case .astigmatism:
                return "Erkennt Hornhautverkrümmung mit Sonnenstern-Muster"
            case .colorVision:
                return "Ishihara-Test für Farbenblindheit"
            case .contrast:
                return "Testet die Kontrastempfindlichkeit"
            case .strabismus:
                return "Erkennt Schielen durch Abdecktest und Lichtreflex"
            case .dominantEye:
                return "Bestimmt das führende Auge"
            case .depthPerception:
                return "Testet räumliches Sehen (Stereopsis)"
            case .nearVision:
                return "Testet Lesen in der Nähe"
            }
        }

        public var estimatedDuration: Int {  // Seconds
            switch self {
            case .visualAcuity: return 120
            case .astigmatism: return 30
            case .colorVision: return 90
            case .contrast: return 60
            case .strabismus: return 45
            case .dominantEye: return 20
            case .depthPerception: return 60
            case .nearVision: return 60
            }
        }
    }

    private init() {
        loadSavedProfile()
    }

    // MARK: - Visual Acuity Test (Landolt-Ring / Snellen)

    /// Generate Landolt ring test pattern
    public func generateLandoltRing(size: CGFloat, gapDirection: GapDirection) -> LandoltRing {
        return LandoltRing(
            diameter: size,
            strokeWidth: size / 5,
            gapWidth: size / 5,
            gapDirection: gapDirection
        )
    }

    public struct LandoltRing {
        public let diameter: CGFloat
        public let strokeWidth: CGFloat
        public let gapWidth: CGFloat
        public let gapDirection: GapDirection

        /// Convert to visual acuity (based on size at distance)
        public func toVisualAcuity(viewingDistanceCm: Double, screenPPI: Double) -> Double {
            // Standard: 5 arc-minutes for 20/20 vision
            let ringHeightCm = Double(diameter) * 2.54 / screenPPI
            let arcMinutes = atan(ringHeightCm / viewingDistanceCm) * (180 * 60 / .pi)
            return 5.0 / arcMinutes  // 1.0 = 20/20
        }
    }

    public enum GapDirection: String, CaseIterable {
        case top, bottom, left, right
        case topLeft, topRight, bottomLeft, bottomRight

        public var angle: Double {  // Degrees
            switch self {
            case .top: return 90
            case .right: return 0
            case .bottom: return 270
            case .left: return 180
            case .topRight: return 45
            case .topLeft: return 135
            case .bottomLeft: return 225
            case .bottomRight: return 315
            }
        }
    }

    /// Run visual acuity test
    public func runVisualAcuityTest(eye: Eye, responses: [(size: CGFloat, correct: Bool)]) -> Double {
        // Find smallest correctly identified size
        let correctResponses = responses.filter { $0.correct }
        guard let smallest = correctResponses.min(by: { $0.size < $1.size }) else {
            return 0.1  // Very poor vision if no correct responses
        }

        // Convert to visual acuity (assuming 60cm viewing distance, 110 PPI)
        let landolt = generateLandoltRing(size: smallest.size, gapDirection: .top)
        let acuity = landolt.toVisualAcuity(viewingDistanceCm: 60, screenPPI: 110)

        // Store result
        switch eye {
        case .left:
            testResults.leftEye.visualAcuity = acuity
        case .right:
            testResults.rightEye.visualAcuity = acuity
        case .both:
            break
        }

        return acuity
    }

    public enum Eye: String {
        case left = "Linkes Auge"
        case right = "Rechtes Auge"
        case both = "Beide Augen"
    }

    // MARK: - Astigmatism Test (Sunburst Pattern)

    /// Generate astigmatism test pattern (Sonnenstern)
    public func generateAstigmatismPattern() -> AstigmatismPattern {
        // Create radial lines at different angles
        var lines: [(angle: Double, thickness: CGFloat)] = []
        for i in 0..<12 {
            let angle = Double(i) * 15  // Every 15 degrees
            lines.append((angle, 2.0))
        }
        return AstigmatismPattern(lines: lines, centerRadius: 20)
    }

    public struct AstigmatismPattern {
        public let lines: [(angle: Double, thickness: CGFloat)]
        public let centerRadius: CGFloat
    }

    /// Analyze astigmatism from user response
    public func analyzeAstigmatism(blurryAngles: [Double], eye: Eye) -> (cylindrical: Double, axis: Double) {
        guard !blurryAngles.isEmpty else {
            return (0, 0)
        }

        // Find the axis perpendicular to blurry lines
        let avgBlurryAngle = blurryAngles.reduce(0, +) / Double(blurryAngles.count)
        let axis = (avgBlurryAngle + 90).truncatingRemainder(dividingBy: 180)

        // Estimate cylindrical power based on severity
        let cylindrical = min(3.0, Double(blurryAngles.count) * 0.5)

        // Store result
        switch eye {
        case .left:
            testResults.leftEye.cylindrical = cylindrical
            testResults.leftEye.axis = axis
        case .right:
            testResults.rightEye.cylindrical = cylindrical
            testResults.rightEye.axis = axis
        case .both:
            break
        }

        return (cylindrical, axis)
    }

    // MARK: - Color Vision Test (Ishihara)

    /// Generate Ishihara-style color test plate
    public func generateColorTestPlate(type: ColorPlateType) -> ColorTestPlate {
        let plate = ColorTestPlate(type: type)
        return plate
    }

    public enum ColorPlateType: String, CaseIterable {
        case demonstration    // Everyone can see
        case transforming     // Numbers change for colorblind
        case vanishing        // Numbers disappear for colorblind
        case hiddenDigit      // Only colorblind can see
        case diagnostic       // Identifies type of colorblindness
    }

    public struct ColorTestPlate {
        public let type: ColorPlateType
        public let normalVisionAnswer: String
        public let protanAnswer: String?
        public let deutanAnswer: String?
        public let tritanAnswer: String?

        public init(type: ColorPlateType) {
            self.type = type

            // Simplified - real implementation would have actual plates
            switch type {
            case .demonstration:
                normalVisionAnswer = "12"
                protanAnswer = "12"
                deutanAnswer = "12"
                tritanAnswer = "12"
            case .transforming:
                normalVisionAnswer = "29"
                protanAnswer = "70"
                deutanAnswer = "70"
                tritanAnswer = "29"
            case .vanishing:
                normalVisionAnswer = "74"
                protanAnswer = nil
                deutanAnswer = nil
                tritanAnswer = "74"
            case .hiddenDigit:
                normalVisionAnswer = nil
                protanAnswer = "5"
                deutanAnswer = "5"
                tritanAnswer = nil
            case .diagnostic:
                normalVisionAnswer = "42"
                protanAnswer = "2"
                deutanAnswer = "4"
                tritanAnswer = "42"
            }
        }

        public func evaluate(userAnswer: String?) -> ColorVisionEvaluation {
            if userAnswer == normalVisionAnswer {
                return .normal
            }
            if userAnswer == protanAnswer {
                return .protan
            }
            if userAnswer == deutanAnswer {
                return .deutan
            }
            if userAnswer == tritanAnswer {
                return .tritan
            }
            return .unknown
        }

        public enum ColorVisionEvaluation {
            case normal, protan, deutan, tritan, unknown
        }
    }

    /// Evaluate complete color vision test
    public func evaluateColorVisionTest(responses: [(plate: ColorTestPlate, answer: String?)]) -> VisionProfile.ColorVisionResult {
        var protanScore = 0
        var deutanScore = 0
        var tritanScore = 0
        var normalScore = 0

        for (plate, answer) in responses {
            let result = plate.evaluate(userAnswer: answer)
            switch result {
            case .normal: normalScore += 1
            case .protan: protanScore += 1
            case .deutan: deutanScore += 1
            case .tritan: tritanScore += 1
            case .unknown: break
            }
        }

        let total = responses.count
        let type: VisionProfile.ColorVisionResult.ColorVisionType
        let severity: Double

        if normalScore >= total - 1 {
            type = .normal
            severity = 0
        } else if protanScore > deutanScore && protanScore > tritanScore {
            type = protanScore > total / 2 ? .protanopia : .protanomaly
            severity = Double(protanScore) / Double(total)
        } else if deutanScore > tritanScore {
            type = deutanScore > total / 2 ? .deuteranopia : .deuteranomaly
            severity = Double(deutanScore) / Double(total)
        } else if tritanScore > 0 {
            type = tritanScore > total / 2 ? .tritanopia : .tritanomaly
            severity = Double(tritanScore) / Double(total)
        } else {
            type = .normal
            severity = 0
        }

        // Confused color pairs based on type
        let confusedColors: [(String, String)]
        switch type {
        case .protanopia, .protanomaly:
            confusedColors = [("Rot", "Grün"), ("Rot", "Braun"), ("Pink", "Grau")]
        case .deuteranopia, .deuteranomaly:
            confusedColors = [("Grün", "Rot"), ("Grün", "Braun"), ("Blaugrün", "Grau")]
        case .tritanopia, .tritanomaly:
            confusedColors = [("Blau", "Grün"), ("Gelb", "Violett"), ("Blau", "Grau")]
        case .achromatopsia:
            confusedColors = [("Alle Farben", "Grautöne")]
        case .normal:
            confusedColors = []
        }

        let result = VisionProfile.ColorVisionResult(
            type: type,
            severity: severity,
            confusedColors: confusedColors
        )

        testResults.leftEye.colorVision = result
        testResults.rightEye.colorVision = result

        return result
    }

    // MARK: - Strabismus Test (Cover Test / Hirschberg)

    /// Analyze strabismus from eye position data
    public func analyzeStrabismus(leftPupilPosition: CGPoint, rightPupilPosition: CGPoint, irisRadius: CGFloat) -> VisionProfile.BinocularProfile {
        // Calculate deviation in iris-radius units (1 IR ≈ 15 degrees)
        let horizontalDiff = rightPupilPosition.x - leftPupilPosition.x
        let verticalDiff = rightPupilPosition.y - leftPupilPosition.y

        // Normalize to degrees
        let horizontalAngle = Double(horizontalDiff / irisRadius) * 15
        let verticalAngle = Double(verticalDiff / irisRadius) * 15

        let totalAngle = sqrt(horizontalAngle * horizontalAngle + verticalAngle * verticalAngle)

        // Determine type
        let type: VisionProfile.StrabismusType
        if totalAngle < 2 {
            type = .none
        } else if abs(horizontalAngle) > abs(verticalAngle) {
            type = horizontalAngle > 0 ? .exotropia : .esotropia
        } else {
            type = verticalAngle > 0 ? .hypotropia : .hypertropia
        }

        let profile = VisionProfile.BinocularProfile(
            interpupillaryDistance: testResults.binocularVision.interpupillaryDistance,
            convergence: testResults.binocularVision.convergence,
            strabismusType: type,
            strabismusAngle: totalAngle,
            dominantEye: testResults.binocularVision.dominantEye,
            stereopsis: testResults.binocularVision.stereopsis,
            fusionAbility: type == .none ? 1.0 : max(0, 1.0 - totalAngle / 30)
        )

        testResults.binocularVision = profile
        return profile
    }

    // MARK: - Dominant Eye Test

    /// Determine dominant eye from pointing test
    public func determineDominantEye(
        leftEyeAlignment: Double,  // Offset when right closed
        rightEyeAlignment: Double  // Offset when left closed
    ) -> VisionProfile.DominantEye {
        // The eye with less alignment shift is dominant
        let dominant: VisionProfile.DominantEye
        if abs(leftEyeAlignment) < abs(rightEyeAlignment) {
            dominant = .left
        } else if abs(rightEyeAlignment) < abs(leftEyeAlignment) {
            dominant = .right
        } else {
            dominant = .none
        }

        testResults.binocularVision.dominantEye = dominant
        return dominant
    }

    // MARK: - Depth Perception Test (Stereopsis)

    /// Evaluate stereopsis from random dot stereogram response
    public func evaluateStereopsis(correctResponses: Int, totalTests: Int, arcSecondsLevels: [Double]) -> Double {
        guard totalTests > 0 && correctResponses > 0 else {
            return 800  // Very poor stereopsis
        }

        // Find smallest arc-second level correctly identified
        let correctIndex = min(correctResponses - 1, arcSecondsLevels.count - 1)
        let stereopsis = arcSecondsLevels[correctIndex]

        testResults.binocularVision.stereopsis = stereopsis
        return stereopsis
    }

    // MARK: - Complete Test Suite

    /// Run complete vision test suite
    public func runCompleteTestSuite() async -> VisionProfile {
        isTestInProgress = true

        // This would guide user through all tests
        // For now, return current results
        testResults.lastTestDate = Date()

        isTestInProgress = false
        saveProfile()
        return testResults
    }

    // MARK: - Persistence

    private func loadSavedProfile() {
        if let data = UserDefaults.standard.data(forKey: "visionProfile"),
           let profile = try? JSONDecoder().decode(VisionProfile.self, from: data) {
            testResults = profile
        }
    }

    private func saveProfile() {
        if let data = try? JSONEncoder().encode(testResults) {
            UserDefaults.standard.set(data, forKey: "visionProfile")
        }
    }

    /// Manual profile entry (from eye doctor)
    public func enterManualProfile(_ profile: VisionProfile) {
        testResults = profile
        testResults.lastTestDate = Date()
        saveProfile()
    }
}

// MARK: - Smart Glasses / VR Correction Engine

/// Real-time vision correction for smart glasses and VR headsets
public final class SmartGlassesCorrectionEngine: ObservableObject {

    public static let shared = SmartGlassesCorrectionEngine()

    @Published public var isActive: Bool = false
    @Published public var deviceType: DeviceType = .unknown
    @Published public var correctionEnabled: Bool = true
    @Published public var leftEyeCorrection: EyeCorrection = EyeCorrection()
    @Published public var rightEyeCorrection: EyeCorrection = EyeCorrection()
    @Published public var strabismusCorrection: StrabismusCorrection = StrabismusCorrection()

    public enum DeviceType: String {
        case unknown = "Unknown"
        case visionPro = "Apple Vision Pro"
        case metaQuest = "Meta Quest"
        case pico = "Pico"
        case varjo = "Varjo"
        case smartGlasses = "Smart Glasses"
        case arGlasses = "AR Glasses"
    }

    public struct EyeCorrection {
        public var enabled: Bool = false
        public var magnification: Double = 1.0      // For visual acuity
        public var sphericalCorrection: Double = 0  // Diopter simulation
        public var cylindricalCorrection: Double = 0
        public var axisCorrection: Double = 0
        public var contrastEnhancement: Double = 1.0
        public var colorCorrection: ColorCorrectionMatrix = .identity
        public var edgeEnhancement: Double = 0
        public var brightnessOffset: Double = 0
        public var renderScale: Double = 1.0
        public var focalDistance: Double = 2.0      // Meters
    }

    public struct StrabismusCorrection {
        public var enabled: Bool = false
        public var horizontalShift: Double = 0      // Pixels
        public var verticalShift: Double = 0        // Pixels
        public var convergenceAdjustment: Double = 0 // For esotropia/exotropia
        public var prismSimulation: Double = 0      // Prism diopters
        public var dominantEyePriority: Double = 0.5 // 0 = left, 1 = right
        public var fusionAssist: Bool = false
    }

    public struct ColorCorrectionMatrix: Codable {
        public var r: (r: Double, g: Double, b: Double) = (1, 0, 0)
        public var g: (r: Double, g: Double, b: Double) = (0, 1, 0)
        public var b: (r: Double, g: Double, b: Double) = (0, 0, 1)

        public static let identity = ColorCorrectionMatrix()

        /// Daltonization matrices for color blindness
        public static func forColorVision(_ type: VisionProfile.ColorVisionResult.ColorVisionType) -> ColorCorrectionMatrix {
            switch type {
            case .protanopia, .protanomaly:
                return ColorCorrectionMatrix(
                    r: (0.567, 0.433, 0.0),
                    g: (0.558, 0.442, 0.0),
                    b: (0.0, 0.242, 0.758)
                )
            case .deuteranopia, .deuteranomaly:
                return ColorCorrectionMatrix(
                    r: (0.625, 0.375, 0.0),
                    g: (0.7, 0.3, 0.0),
                    b: (0.0, 0.3, 0.7)
                )
            case .tritanopia, .tritanomaly:
                return ColorCorrectionMatrix(
                    r: (0.95, 0.05, 0.0),
                    g: (0.0, 0.433, 0.567),
                    b: (0.0, 0.475, 0.525)
                )
            case .normal, .achromatopsia:
                return .identity
            }
        }
    }

    private init() {
        detectDevice()
        loadVisionProfile()
    }

    /// Detect connected VR/AR device
    private func detectDevice() {
        #if os(visionOS)
        deviceType = .visionPro
        #else
        // Would check for connected devices
        deviceType = .unknown
        #endif
    }

    /// Load and apply vision profile corrections
    public func loadVisionProfile() {
        let visionProfile = VisionTestEngine.shared.testResults

        // Configure left eye
        leftEyeCorrection = createCorrection(for: visionProfile.leftEye)

        // Configure right eye
        rightEyeCorrection = createCorrection(for: visionProfile.rightEye)

        // Configure strabismus correction
        strabismusCorrection = createStrabismusCorrection(for: visionProfile.binocularVision)
    }

    private func createCorrection(for eye: VisionProfile.EyeProfile) -> EyeCorrection {
        var correction = EyeCorrection()

        // Visual acuity - magnification
        if eye.visualAcuity < 1.0 {
            correction.magnification = 1.0 / eye.visualAcuity
            correction.magnification = min(2.0, correction.magnification) // Cap at 2x
            correction.enabled = true
        }

        // Spherical correction simulation
        if abs(eye.spherical) > 0.5 {
            correction.sphericalCorrection = eye.spherical
            correction.enabled = true
        }

        // Cylindrical (astigmatism) correction
        if abs(eye.cylindrical) > 0.5 {
            correction.cylindricalCorrection = eye.cylindrical
            correction.axisCorrection = eye.axis
            correction.enabled = true
        }

        // Contrast sensitivity
        if eye.contrastSensitivity < 0.8 {
            correction.contrastEnhancement = 1.0 / eye.contrastSensitivity
            correction.contrastEnhancement = min(2.0, correction.contrastEnhancement)
            correction.enabled = true
        }

        // Color vision
        if eye.colorVision.type != .normal {
            correction.colorCorrection = ColorCorrectionMatrix.forColorVision(eye.colorVision.type)
            correction.enabled = true
        }

        return correction
    }

    private func createStrabismusCorrection(for binocular: VisionProfile.BinocularProfile) -> StrabismusCorrection {
        var correction = StrabismusCorrection()

        guard binocular.hasStrabismus else { return correction }

        correction.enabled = true

        // Calculate pixel shift based on strabismus angle
        // Assuming ~50 pixels per degree at typical VR resolution
        let pixelsPerDegree: Double = 50

        switch binocular.strabismusType {
        case .esotropia:
            // Eyes turn inward - shift images outward
            correction.horizontalShift = binocular.strabismusAngle * pixelsPerDegree
            correction.convergenceAdjustment = -binocular.strabismusAngle
        case .exotropia:
            // Eyes turn outward - shift images inward
            correction.horizontalShift = -binocular.strabismusAngle * pixelsPerDegree
            correction.convergenceAdjustment = binocular.strabismusAngle
        case .hypertropia:
            correction.verticalShift = -binocular.strabismusAngle * pixelsPerDegree
        case .hypotropia:
            correction.verticalShift = binocular.strabismusAngle * pixelsPerDegree
        case .alternating:
            // For alternating strabismus, prioritize dominant eye
            correction.dominantEyePriority = binocular.dominantEye == .right ? 0.8 : 0.2
        case .none:
            break
        }

        // Prism simulation
        correction.prismSimulation = binocular.strabismusAngle * 1.75 // Approx conversion to prism diopters

        // Enable fusion assist if fusion ability is reduced
        correction.fusionAssist = binocular.fusionAbility < 0.7

        return correction
    }

    // MARK: - Real-Time Rendering Adjustments

    /// Get rendering parameters for left eye
    public func getLeftEyeRenderParams() -> RenderParameters {
        return createRenderParams(leftEyeCorrection, strabismusCorrection, isRightEye: false)
    }

    /// Get rendering parameters for right eye
    public func getRightEyeRenderParams() -> RenderParameters {
        return createRenderParams(rightEyeCorrection, strabismusCorrection, isRightEye: true)
    }

    private func createRenderParams(_ eye: EyeCorrection, _ strabismus: StrabismusCorrection, isRightEye: Bool) -> RenderParameters {
        var params = RenderParameters()

        if !correctionEnabled {
            return params
        }

        // Magnification
        params.scale = eye.magnification

        // Position offset for strabismus
        if strabismus.enabled {
            let sign: Double = isRightEye ? 1.0 : -1.0
            params.horizontalOffset = strabismus.horizontalShift * sign / 2
            params.verticalOffset = strabismus.verticalShift
            params.convergenceOffset = strabismus.convergenceAdjustment
        }

        // Contrast
        params.contrast = eye.contrastEnhancement

        // Color matrix
        params.colorMatrix = eye.colorCorrection

        // Edge enhancement for low vision
        params.edgeEnhancement = eye.edgeEnhancement

        // Blur simulation for incorrect focus (demonstration)
        params.blurRadius = 0 // Normally wouldn't blur, but could show effect of no correction

        // Brightness
        params.brightness = 1.0 + eye.brightnessOffset

        return params
    }

    public struct RenderParameters {
        public var scale: Double = 1.0
        public var horizontalOffset: Double = 0
        public var verticalOffset: Double = 0
        public var convergenceOffset: Double = 0
        public var contrast: Double = 1.0
        public var brightness: Double = 1.0
        public var colorMatrix: ColorCorrectionMatrix = .identity
        public var edgeEnhancement: Double = 0
        public var blurRadius: Double = 0

        /// Generate shader uniforms
        public func toShaderUniforms() -> [String: Any] {
            return [
                "u_scale": scale,
                "u_offset": SIMD2<Float>(Float(horizontalOffset), Float(verticalOffset)),
                "u_contrast": contrast,
                "u_brightness": brightness,
                "u_colorMatrix": [
                    colorMatrix.r.r, colorMatrix.r.g, colorMatrix.r.b,
                    colorMatrix.g.r, colorMatrix.g.g, colorMatrix.g.b,
                    colorMatrix.b.r, colorMatrix.b.g, colorMatrix.b.b
                ],
                "u_edgeEnhance": edgeEnhancement,
                "u_blurRadius": blurRadius
            ]
        }
    }

    // MARK: - IPD Calibration

    /// Calibrate interpupillary distance
    public func calibrateIPD(measuredIPD: Double) {
        VisionTestEngine.shared.testResults.binocularVision.interpupillaryDistance = measuredIPD
    }

    /// Get recommended IPD setting
    public func getRecommendedIPD() -> Double {
        return VisionTestEngine.shared.testResults.binocularVision.interpupillaryDistance
    }

    // MARK: - Activation

    /// Activate corrections
    public func activate() {
        loadVisionProfile()
        isActive = true
        correctionEnabled = true

        print("""

        ╔═══════════════════════════════════════════════════════════════════════════╗
        ║            SMART GLASSES VISION CORRECTION ACTIVATED                      ║
        ╠═══════════════════════════════════════════════════════════════════════════╣
        ║                                                                           ║
        ║   Device: \(deviceType.rawValue.padding(toLength: 30, withPad: " ", startingAt: 0))                        ║
        ║                                                                           ║
        ║   Linkes Auge:                                                            ║
        ║   - Korrektur aktiv: \(leftEyeCorrection.enabled ? "✅" : "❌")                                           ║
        ║   - Vergrößerung: \(String(format: "%.1fx", leftEyeCorrection.magnification))                                              ║
        ║   - Sphärisch: \(String(format: "%.2f", leftEyeCorrection.sphericalCorrection)) dpt                                          ║
        ║   - Zylinder: \(String(format: "%.2f", leftEyeCorrection.cylindricalCorrection)) dpt / \(String(format: "%.0f°", leftEyeCorrection.axisCorrection))                            ║
        ║                                                                           ║
        ║   Rechtes Auge:                                                           ║
        ║   - Korrektur aktiv: \(rightEyeCorrection.enabled ? "✅" : "❌")                                           ║
        ║   - Vergrößerung: \(String(format: "%.1fx", rightEyeCorrection.magnification))                                              ║
        ║   - Sphärisch: \(String(format: "%.2f", rightEyeCorrection.sphericalCorrection)) dpt                                          ║
        ║   - Zylinder: \(String(format: "%.2f", rightEyeCorrection.cylindricalCorrection)) dpt / \(String(format: "%.0f°", rightEyeCorrection.axisCorrection))                            ║
        ║                                                                           ║
        ║   Schielkorrektur:                                                        ║
        ║   - Aktiv: \(strabismusCorrection.enabled ? "✅" : "❌")                                                    ║
        ║   - Horizontale Verschiebung: \(String(format: "%.0f", strabismusCorrection.horizontalShift)) px                            ║
        ║   - Vertikale Verschiebung: \(String(format: "%.0f", strabismusCorrection.verticalShift)) px                              ║
        ║   - Prismen-Simulation: \(String(format: "%.1f", strabismusCorrection.prismSimulation)) pdpt                              ║
        ║                                                                           ║
        ╚═══════════════════════════════════════════════════════════════════════════╝

        """)
    }

    /// Deactivate corrections
    public func deactivate() {
        isActive = false
    }
}

// MARK: - Quick Start

/// Easy access to vision correction
public struct VisionCorrectionQuickStart {

    /// Run vision test
    @MainActor
    public static func runVisionTest() async -> VisionProfile {
        return await VisionTestEngine.shared.runCompleteTestSuite()
    }

    /// Activate smart glasses correction
    public static func activateSmartGlassesCorrection() {
        SmartGlassesCorrectionEngine.shared.activate()
    }

    /// Enter manual prescription
    public static func enterPrescription(
        leftSphere: Double, leftCylinder: Double, leftAxis: Double,
        rightSphere: Double, rightCylinder: Double, rightAxis: Double,
        ipd: Double
    ) {
        var profile = VisionTestEngine.shared.testResults

        profile.leftEye.spherical = leftSphere
        profile.leftEye.cylindrical = leftCylinder
        profile.leftEye.axis = leftAxis

        profile.rightEye.spherical = rightSphere
        profile.rightEye.cylindrical = rightCylinder
        profile.rightEye.axis = rightAxis

        profile.binocularVision.interpupillaryDistance = ipd

        VisionTestEngine.shared.enterManualProfile(profile)
        SmartGlassesCorrectionEngine.shared.loadVisionProfile()
    }

    /// Print current vision status
    public static func printVisionStatus() {
        let profile = VisionTestEngine.shared.testResults

        print("""

        ╔═══════════════════════════════════════════════════════════════════════════╗
        ║                         VISION STATUS / SEHSTATUS                         ║
        ╠═══════════════════════════════════════════════════════════════════════════╣
        ║                                                                           ║
        ║   👁️ LINKES AUGE:                                                          ║
        ║      Sehschärfe: \(String(format: "%.0f%%", profile.leftEye.visualAcuity * 100)) (\(profile.leftEye.visualAcuity >= 1.0 ? "20/20" : String(format: "20/%.0f", 20/profile.leftEye.visualAcuity)))                                    ║
        ║      Sphärisch: \(String(format: "%+.2f", profile.leftEye.spherical)) dpt                                           ║
        ║      Zylinder: \(String(format: "%+.2f", profile.leftEye.cylindrical)) dpt / Achse \(String(format: "%.0f°", profile.leftEye.axis))                         ║
        ║      Status: \(profile.leftEye.correctionDescription.padding(toLength: 40, withPad: " ", startingAt: 0))   ║
        ║                                                                           ║
        ║   👁️ RECHTES AUGE:                                                         ║
        ║      Sehschärfe: \(String(format: "%.0f%%", profile.rightEye.visualAcuity * 100)) (\(profile.rightEye.visualAcuity >= 1.0 ? "20/20" : String(format: "20/%.0f", 20/profile.rightEye.visualAcuity)))                                    ║
        ║      Sphärisch: \(String(format: "%+.2f", profile.rightEye.spherical)) dpt                                           ║
        ║      Zylinder: \(String(format: "%+.2f", profile.rightEye.cylindrical)) dpt / Achse \(String(format: "%.0f°", profile.rightEye.axis))                         ║
        ║      Status: \(profile.rightEye.correctionDescription.padding(toLength: 40, withPad: " ", startingAt: 0))   ║
        ║                                                                           ║
        ║   👀 BEIDÄUGIG:                                                            ║
        ║      Pupillendistanz (IPD): \(String(format: "%.1f", profile.binocularVision.interpupillaryDistance)) mm                               ║
        ║      Schielen: \(profile.binocularVision.strabismusType.germanName.padding(toLength: 30, withPad: " ", startingAt: 0))               ║
        ║      Schielwinkel: \(String(format: "%.1f°", profile.binocularVision.strabismusAngle))                                            ║
        ║      Dominantes Auge: \(profile.binocularVision.dominantEye.rawValue.padding(toLength: 10, withPad: " ", startingAt: 0))                                   ║
        ║      Tiefensehen: \(String(format: "%.0f", profile.binocularVision.stereopsis)) Bogensekunden                               ║
        ║                                                                           ║
        ║   🎨 FARBSEHEN:                                                            ║
        ║      Typ: \(profile.leftEye.colorVision.type.rawValue.padding(toLength: 30, withPad: " ", startingAt: 0))                    ║
        ║                                                                           ║
        ║   Letzter Test: \((profile.lastTestDate?.formatted() ?? "Noch nicht getestet").padding(toLength: 30, withPad: " ", startingAt: 0))               ║
        ║                                                                           ║
        ╚═══════════════════════════════════════════════════════════════════════════╝

        """)
    }
}
