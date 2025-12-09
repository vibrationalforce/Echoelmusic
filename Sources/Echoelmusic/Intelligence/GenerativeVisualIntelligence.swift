import Foundation
import simd

// ═══════════════════════════════════════════════════════════════════════════════
// GENERATIVE VISUAL INTELLIGENCE
// ═══════════════════════════════════════════════════════════════════════════════
//
// AI-Powered Visual Generation Skills:
// • Procedural Visual Generator (latent space)
// • Audio-Reactive Scene Composer
// • Intelligent Color Harmony
// • Dynamic Composition Engine
// • Bio-Responsive Visual Adaptation
// • Style Transfer Controller
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Latent Space Visual Generator

/// Neural latent space for procedural visual generation
public final class LatentVisualGenerator {

    /// Generated visual parameters
    public struct VisualOutput {
        public let colors: [SIMD3<Float>]     // Palette colors
        public let shapes: [ShapeParams]       // Shape definitions
        public let particles: ParticleConfig   // Particle system config
        public let flow: FlowFieldParams       // Flow field parameters
        public let composition: CompositionParams
    }

    public struct ShapeParams {
        public var position: SIMD2<Float>
        public var scale: SIMD2<Float>
        public var rotation: Float
        public var roundness: Float
        public var complexity: Int
        public var opacity: Float
    }

    public struct ParticleConfig {
        public var count: Int
        public var size: Float
        public var speed: Float
        public var lifetime: Float
        public var turbulence: Float
        public var gravity: SIMD2<Float>
        public var colorMode: Int
    }

    public struct FlowFieldParams {
        public var scale: Float
        public var speed: Float
        public var complexity: Int
        public var curl: Float
        public var divergence: Float
    }

    public struct CompositionParams {
        public var centerWeight: Float
        public var symmetry: Int
        public var layerCount: Int
        public var depthRange: Float
        public var focusPoint: SIMD2<Float>
    }

    // Latent space dimensions
    private let latentDim = 64
    private var currentLatent: [Float]
    private var targetLatent: [Float]
    private var transitionSpeed: Float = 0.1

    // Decoder network
    private var decoderWeights1: [[Float]]
    private var decoderWeights2: [[Float]]
    private var decoderWeights3: [[Float]]
    private let hidden1 = 128
    private let hidden2 = 96
    private let outputDim = 48

    public init() {
        currentLatent = (0..<latentDim).map { _ in Float.random(in: -1...1) }
        targetLatent = currentLatent

        // Initialize decoder
        let scale1 = sqrt(2.0 / Float(latentDim))
        let scale2 = sqrt(2.0 / Float(hidden1))
        let scale3 = sqrt(2.0 / Float(hidden2))

        decoderWeights1 = (0..<hidden1).map { _ in
            (0..<latentDim).map { _ in Float.random(in: -scale1...scale1) }
        }
        decoderWeights2 = (0..<hidden2).map { _ in
            (0..<hidden1).map { _ in Float.random(in: -scale2...scale2) }
        }
        decoderWeights3 = (0..<outputDim).map { _ in
            (0..<hidden2).map { _ in Float.random(in: -scale3...scale3) }
        }
    }

    /// Set target latent from audio/bio features
    public func setTargetFromFeatures(
        audioEnergy: Float,
        audioSpectrum: [Float],
        coherence: Float,
        heartRate: Float,
        emotion: String
    ) {
        // Encode features into latent space
        var newLatent = [Float](repeating: 0, count: latentDim)

        // Audio energy influences first 8 dimensions
        for i in 0..<8 {
            newLatent[i] = audioEnergy * Float.random(in: 0.8...1.2)
        }

        // Spectrum influences dimensions 8-24
        for i in 0..<min(16, audioSpectrum.count) {
            newLatent[8 + i] = audioSpectrum[i]
        }

        // Bio features influence dimensions 24-32
        newLatent[24] = coherence
        newLatent[25] = (heartRate - 60) / 100  // Normalize around 60 bpm
        newLatent[26] = coherence * coherence   // Coherence squared for emphasis

        // Emotion encoding in dimensions 32-40
        let emotionEncoding = encodeEmotion(emotion)
        for i in 0..<8 {
            newLatent[32 + i] = emotionEncoding[i]
        }

        // Random variation in remaining dimensions
        for i in 40..<latentDim {
            newLatent[i] = currentLatent[i] * 0.9 + Float.random(in: -0.1...0.1)
        }

        targetLatent = newLatent
    }

    private func encodeEmotion(_ emotion: String) -> [Float] {
        var encoding = [Float](repeating: 0, count: 8)

        switch emotion.lowercased() {
        case "calm": encoding = [0.2, 0.8, 0.1, 0.3, 0.9, 0.2, 0.1, 0.4]
        case "happy": encoding = [0.9, 0.3, 0.8, 0.1, 0.2, 0.9, 0.7, 0.1]
        case "sad": encoding = [0.1, 0.4, 0.2, 0.9, 0.3, 0.1, 0.2, 0.8]
        case "energetic": encoding = [0.8, 0.1, 0.9, 0.2, 0.1, 0.8, 0.9, 0.2]
        case "peaceful": encoding = [0.3, 0.9, 0.2, 0.1, 0.8, 0.3, 0.1, 0.6]
        case "tense": encoding = [0.6, 0.2, 0.4, 0.7, 0.2, 0.5, 0.8, 0.3]
        case "euphoric": encoding = [1.0, 0.2, 0.9, 0.1, 0.1, 1.0, 0.8, 0.1]
        default: encoding = [0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5, 0.5]
        }

        return encoding
    }

    /// Update latent space (call each frame)
    public func update(dt: Float) {
        // Smooth interpolation toward target
        for i in 0..<latentDim {
            currentLatent[i] += (targetLatent[i] - currentLatent[i]) * transitionSpeed * dt * 60
        }
    }

    /// Generate visual parameters from current latent
    public func generate() -> VisualOutput {
        // Decode latent to output
        let decoded = decode(currentLatent)

        // Parse decoded output into visual parameters
        let colors = parseColors(Array(decoded[0..<12]))
        let shapes = parseShapes(Array(decoded[12..<24]))
        let particles = parseParticles(Array(decoded[24..<32]))
        let flow = parseFlow(Array(decoded[32..<40]))
        let composition = parseComposition(Array(decoded[40..<48]))

        return VisualOutput(
            colors: colors,
            shapes: shapes,
            particles: particles,
            flow: flow,
            composition: composition
        )
    }

    private func decode(_ latent: [Float]) -> [Float] {
        // Layer 1
        var hidden1Out = [Float](repeating: 0, count: hidden1)
        for h in 0..<hidden1 {
            var sum: Float = 0
            for i in 0..<latentDim {
                sum += latent[i] * decoderWeights1[h][i]
            }
            hidden1Out[h] = leakyRelu(sum)
        }

        // Layer 2
        var hidden2Out = [Float](repeating: 0, count: hidden2)
        for h in 0..<hidden2 {
            var sum: Float = 0
            for i in 0..<hidden1 {
                sum += hidden1Out[i] * decoderWeights2[h][i]
            }
            hidden2Out[h] = leakyRelu(sum)
        }

        // Output layer
        var output = [Float](repeating: 0, count: outputDim)
        for o in 0..<outputDim {
            var sum: Float = 0
            for h in 0..<hidden2 {
                sum += hidden2Out[h] * decoderWeights3[o][h]
            }
            output[o] = tanh(sum)  // Output in [-1, 1]
        }

        return output
    }

    private func leakyRelu(_ x: Float, alpha: Float = 0.1) -> Float {
        return x > 0 ? x : alpha * x
    }

    private func parseColors(_ data: [Float]) -> [SIMD3<Float>] {
        // 4 colors from 12 values
        var colors: [SIMD3<Float>] = []
        for i in stride(from: 0, to: 12, by: 3) {
            let r = (data[i] + 1) / 2      // Map [-1,1] to [0,1]
            let g = (data[i + 1] + 1) / 2
            let b = (data[i + 2] + 1) / 2
            colors.append(SIMD3(r, g, b))
        }
        return colors
    }

    private func parseShapes(_ data: [Float]) -> [ShapeParams] {
        // 2 shapes from 12 values
        var shapes: [ShapeParams] = []
        for i in stride(from: 0, to: 12, by: 6) {
            shapes.append(ShapeParams(
                position: SIMD2(data[i], data[i + 1]),
                scale: SIMD2((data[i + 2] + 1) / 2, (data[i + 3] + 1) / 2),
                rotation: data[i + 4] * .pi,
                roundness: (data[i + 5] + 1) / 2,
                complexity: Int((data[i] + 1) * 4) + 3,
                opacity: 0.8
            ))
        }
        return shapes
    }

    private func parseParticles(_ data: [Float]) -> ParticleConfig {
        return ParticleConfig(
            count: Int((data[0] + 1) * 500) + 100,
            size: (data[1] + 1) * 5 + 1,
            speed: (data[2] + 1) * 50 + 10,
            lifetime: (data[3] + 1) * 2 + 0.5,
            turbulence: (data[4] + 1) / 2,
            gravity: SIMD2(data[5] * 10, data[6] * 20),
            colorMode: Int((data[7] + 1) * 2)
        )
    }

    private func parseFlow(_ data: [Float]) -> FlowFieldParams {
        return FlowFieldParams(
            scale: (data[0] + 1) * 50 + 10,
            speed: (data[1] + 1) * 2 + 0.5,
            complexity: Int((data[2] + 1) * 3) + 1,
            curl: data[3],
            divergence: data[4]
        )
    }

    private func parseComposition(_ data: [Float]) -> CompositionParams {
        return CompositionParams(
            centerWeight: (data[0] + 1) / 2,
            symmetry: Int((data[1] + 1) * 4) + 1,
            layerCount: Int((data[2] + 1) * 3) + 2,
            depthRange: (data[3] + 1) * 5 + 1,
            focusPoint: SIMD2(data[4], data[5])
        )
    }
}

// MARK: - Intelligent Color Harmony

/// AI-driven color harmony generator
public final class ColorHarmonyAI {

    public enum HarmonyType {
        case complementary
        case analogous
        case triadic
        case splitComplementary
        case tetradic
        case monochromatic
    }

    /// Color with metadata
    public struct HarmonyColor {
        public let rgb: SIMD3<Float>
        public let hsv: SIMD3<Float>
        public let role: String  // "primary", "secondary", "accent", etc.
        public let weight: Float // Usage weight 0-1
    }

    // Color preference learning
    private var preferenceWeights: [Float]
    private let prefDim = 16

    public init() {
        preferenceWeights = [Float](repeating: 0.5, count: prefDim)
    }

    /// Generate harmonious color palette
    public func generatePalette(
        baseHue: Float,          // 0-1
        mood: String,
        audioEnergy: Float,
        coherence: Float,
        count: Int = 5
    ) -> [HarmonyColor] {
        // Determine harmony type based on mood
        let harmonyType = selectHarmonyType(mood: mood, coherence: coherence)

        // Generate base palette
        var palette = generateBaseHarmony(
            hue: baseHue,
            type: harmonyType,
            count: count
        )

        // Adjust saturation/value based on energy and coherence
        palette = adjustForMood(palette, energy: audioEnergy, coherence: coherence, mood: mood)

        return palette
    }

    private func selectHarmonyType(mood: String, coherence: Float) -> HarmonyType {
        switch mood.lowercased() {
        case "calm", "peaceful":
            return coherence > 0.6 ? .analogous : .monochromatic
        case "energetic", "euphoric":
            return .triadic
        case "tense":
            return .splitComplementary
        case "sad", "melancholic":
            return .monochromatic
        case "happy":
            return coherence > 0.5 ? .triadic : .complementary
        default:
            return .analogous
        }
    }

    private func generateBaseHarmony(hue: Float, type: HarmonyType, count: Int) -> [HarmonyColor] {
        var colors: [HarmonyColor] = []

        switch type {
        case .complementary:
            colors.append(makeColor(h: hue, s: 0.7, v: 0.9, role: "primary", weight: 0.4))
            colors.append(makeColor(h: fmod(hue + 0.5, 1), s: 0.6, v: 0.8, role: "secondary", weight: 0.3))
            colors.append(makeColor(h: hue, s: 0.3, v: 0.95, role: "background", weight: 0.2))
            colors.append(makeColor(h: fmod(hue + 0.5, 1), s: 0.9, v: 0.7, role: "accent", weight: 0.1))

        case .analogous:
            colors.append(makeColor(h: hue, s: 0.7, v: 0.9, role: "primary", weight: 0.35))
            colors.append(makeColor(h: fmod(hue + 0.083, 1), s: 0.6, v: 0.85, role: "secondary", weight: 0.25))
            colors.append(makeColor(h: fmod(hue - 0.083 + 1, 1), s: 0.6, v: 0.85, role: "tertiary", weight: 0.25))
            colors.append(makeColor(h: hue, s: 0.2, v: 0.95, role: "background", weight: 0.15))

        case .triadic:
            colors.append(makeColor(h: hue, s: 0.8, v: 0.9, role: "primary", weight: 0.4))
            colors.append(makeColor(h: fmod(hue + 0.333, 1), s: 0.7, v: 0.8, role: "secondary", weight: 0.3))
            colors.append(makeColor(h: fmod(hue + 0.667, 1), s: 0.7, v: 0.8, role: "tertiary", weight: 0.2))
            colors.append(makeColor(h: hue, s: 0.1, v: 0.98, role: "background", weight: 0.1))

        case .splitComplementary:
            colors.append(makeColor(h: hue, s: 0.75, v: 0.9, role: "primary", weight: 0.4))
            colors.append(makeColor(h: fmod(hue + 0.417, 1), s: 0.65, v: 0.8, role: "secondary", weight: 0.25))
            colors.append(makeColor(h: fmod(hue + 0.583, 1), s: 0.65, v: 0.8, role: "tertiary", weight: 0.25))
            colors.append(makeColor(h: hue, s: 0.15, v: 0.95, role: "background", weight: 0.1))

        case .tetradic:
            colors.append(makeColor(h: hue, s: 0.7, v: 0.9, role: "primary", weight: 0.3))
            colors.append(makeColor(h: fmod(hue + 0.25, 1), s: 0.6, v: 0.85, role: "secondary", weight: 0.25))
            colors.append(makeColor(h: fmod(hue + 0.5, 1), s: 0.6, v: 0.85, role: "tertiary", weight: 0.25))
            colors.append(makeColor(h: fmod(hue + 0.75, 1), s: 0.6, v: 0.85, role: "quaternary", weight: 0.2))

        case .monochromatic:
            colors.append(makeColor(h: hue, s: 0.8, v: 0.9, role: "primary", weight: 0.3))
            colors.append(makeColor(h: hue, s: 0.6, v: 0.7, role: "secondary", weight: 0.25))
            colors.append(makeColor(h: hue, s: 0.4, v: 0.5, role: "tertiary", weight: 0.2))
            colors.append(makeColor(h: hue, s: 0.2, v: 0.3, role: "dark", weight: 0.15))
            colors.append(makeColor(h: hue, s: 0.1, v: 0.95, role: "light", weight: 0.1))
        }

        // Pad or trim to requested count
        while colors.count < count {
            let last = colors.last!
            colors.append(makeColor(
                h: fmod(last.hsv.x + 0.05, 1),
                s: last.hsv.y * 0.9,
                v: last.hsv.z,
                role: "extra",
                weight: 0.05
            ))
        }

        return Array(colors.prefix(count))
    }

    private func makeColor(h: Float, s: Float, v: Float, role: String, weight: Float) -> HarmonyColor {
        let rgb = hsvToRgb(h: h, s: s, v: v)
        return HarmonyColor(
            rgb: rgb,
            hsv: SIMD3(h, s, v),
            role: role,
            weight: weight
        )
    }

    private func adjustForMood(
        _ palette: [HarmonyColor],
        energy: Float,
        coherence: Float,
        mood: String
    ) -> [HarmonyColor] {
        return palette.map { color in
            var h = color.hsv.x
            var s = color.hsv.y
            var v = color.hsv.z

            // Energy affects saturation
            s = s * (0.7 + energy * 0.3)

            // Coherence affects brightness consistency
            if coherence > 0.7 {
                v = v * (0.9 + coherence * 0.1)
            }

            // Mood-specific adjustments
            switch mood.lowercased() {
            case "calm", "peaceful":
                s *= 0.8
                v = min(v * 1.1, 1)
            case "energetic":
                s = min(s * 1.2, 1)
            case "sad":
                s *= 0.6
                v *= 0.8
            case "tense":
                s = min(s * 1.1, 1)
                v *= 0.9
            default:
                break
            }

            let rgb = hsvToRgb(h: h, s: s, v: v)
            return HarmonyColor(
                rgb: rgb,
                hsv: SIMD3(h, s, v),
                role: color.role,
                weight: color.weight
            )
        }
    }

    private func hsvToRgb(h: Float, s: Float, v: Float) -> SIMD3<Float> {
        let c = v * s
        let x = c * (1 - abs(fmod(h * 6, 2) - 1))
        let m = v - c

        var rgb: SIMD3<Float>
        let sector = Int(h * 6) % 6

        switch sector {
        case 0: rgb = SIMD3(c, x, 0)
        case 1: rgb = SIMD3(x, c, 0)
        case 2: rgb = SIMD3(0, c, x)
        case 3: rgb = SIMD3(0, x, c)
        case 4: rgb = SIMD3(x, 0, c)
        default: rgb = SIMD3(c, 0, x)
        }

        return rgb + SIMD3(repeating: m)
    }

    /// Learn from user preference
    public func learnPreference(palette: [HarmonyColor], rating: Float) {
        // Simple preference learning
        for (i, color) in palette.enumerated() {
            let idx = i % prefDim
            preferenceWeights[idx] = preferenceWeights[idx] * 0.95 + rating * color.hsv.x * 0.05
        }
    }
}

// MARK: - Dynamic Scene Composer

/// AI-powered scene composition
public final class SceneComposer {

    /// Scene element
    public struct SceneElement {
        public let type: ElementType
        public let position: SIMD3<Float>
        public let scale: Float
        public let rotation: Float
        public let depth: Float
        public let importance: Float
    }

    public enum ElementType {
        case background
        case midground
        case foreground
        case particle
        case light
        case overlay
    }

    /// Composed scene
    public struct ComposedScene {
        public let elements: [SceneElement]
        public let cameraPosition: SIMD3<Float>
        public let focalPoint: SIMD3<Float>
        public let ambientColor: SIMD3<Float>
        public let mood: String
    }

    // Composition rules
    private var ruleOfThirdsWeight: Float = 0.7
    private var goldenRatioWeight: Float = 0.5
    private var symmetryWeight: Float = 0.3

    public init() {}

    /// Compose scene from visual parameters
    public func compose(
        visualOutput: LatentVisualGenerator.VisualOutput,
        audioEnergy: Float,
        beatPhase: Float,
        coherence: Float
    ) -> ComposedScene {
        var elements: [SceneElement] = []

        // Background layer
        elements.append(SceneElement(
            type: .background,
            position: SIMD3(0, 0, -10),
            scale: 20,
            rotation: 0,
            depth: 1.0,
            importance: 0.3
        ))

        // Add shapes from visual output
        for (i, shape) in visualOutput.shapes.enumerated() {
            let depth = Float(i) / Float(visualOutput.shapes.count)
            let position = applyCompositionRule(
                base: SIMD3(shape.position.x, shape.position.y, -5 + depth * 5),
                beatPhase: beatPhase,
                coherence: coherence
            )

            elements.append(SceneElement(
                type: depth < 0.5 ? .midground : .foreground,
                position: position,
                scale: shape.scale.x * (1 + audioEnergy * 0.3),
                rotation: shape.rotation + beatPhase * 0.1,
                depth: depth,
                importance: shape.opacity
            ))
        }

        // Particle system
        let particleCount = Int(Float(visualOutput.particles.count) * (0.5 + audioEnergy * 0.5))
        for i in 0..<min(particleCount, 50) {
            let angle = Float(i) / Float(particleCount) * 2 * .pi
            let radius = 0.5 + Float.random(in: 0...1) * 2

            elements.append(SceneElement(
                type: .particle,
                position: SIMD3(cos(angle) * radius, sin(angle) * radius, -3),
                scale: visualOutput.particles.size * 0.1,
                rotation: angle,
                depth: 0.6,
                importance: 0.1
            ))
        }

        // Light source
        let lightPos = SIMD3<Float>(
            sin(beatPhase * 2 * .pi) * 3,
            2 + cos(beatPhase * .pi) * 1,
            2
        )
        elements.append(SceneElement(
            type: .light,
            position: lightPos,
            scale: 1 + audioEnergy * 0.5,
            rotation: 0,
            depth: 0.0,
            importance: 0.8
        ))

        // Camera position based on coherence
        let cameraZ: Float = 5 + (1 - coherence) * 3
        let cameraPosition = SIMD3<Float>(0, 0, cameraZ)

        // Focal point follows energy
        let focalPoint = SIMD3<Float>(
            audioEnergy * 0.5 - 0.25,
            (1 - coherence) * 0.3,
            -2
        )

        // Ambient from color palette
        let ambient = visualOutput.colors.first ?? SIMD3(0.1, 0.1, 0.15)

        return ComposedScene(
            elements: elements,
            cameraPosition: cameraPosition,
            focalPoint: focalPoint,
            ambientColor: ambient * 0.3,
            mood: determineMood(energy: audioEnergy, coherence: coherence)
        )
    }

    private func applyCompositionRule(
        base: SIMD3<Float>,
        beatPhase: Float,
        coherence: Float
    ) -> SIMD3<Float> {
        var pos = base

        // Rule of thirds grid points
        let thirdPoints: [SIMD2<Float>] = [
            SIMD2(-0.33, -0.33), SIMD2(0, -0.33), SIMD2(0.33, -0.33),
            SIMD2(-0.33, 0), SIMD2(0, 0), SIMD2(0.33, 0),
            SIMD2(-0.33, 0.33), SIMD2(0, 0.33), SIMD2(0.33, 0.33)
        ]

        // Snap to nearest rule-of-thirds point
        if ruleOfThirdsWeight > 0.5 {
            var nearestDist: Float = .infinity
            var nearest = SIMD2<Float>(0, 0)

            for point in thirdPoints {
                let dist = simd_length(SIMD2(pos.x, pos.y) - point)
                if dist < nearestDist {
                    nearestDist = dist
                    nearest = point
                }
            }

            let influence = ruleOfThirdsWeight * coherence
            pos.x = pos.x * (1 - influence) + nearest.x * influence
            pos.y = pos.y * (1 - influence) + nearest.y * influence
        }

        // Golden ratio spiral influence
        if goldenRatioWeight > 0.3 {
            let phi: Float = 1.618034
            let spiralAngle = beatPhase * 2 * .pi * phi
            let spiralOffset = SIMD2(cos(spiralAngle), sin(spiralAngle)) * 0.1 * goldenRatioWeight
            pos.x += spiralOffset.x
            pos.y += spiralOffset.y
        }

        return pos
    }

    private func determineMood(energy: Float, coherence: Float) -> String {
        if coherence > 0.7 {
            return energy > 0.6 ? "euphoric" : "peaceful"
        } else if energy > 0.7 {
            return coherence > 0.4 ? "energetic" : "tense"
        } else if energy < 0.3 {
            return coherence > 0.5 ? "calm" : "melancholic"
        } else {
            return "neutral"
        }
    }
}

// MARK: - Bio-Responsive Visual Adapter

/// Adapts visuals based on bio-signals in real-time
public final class BioVisualAdapter {

    /// Adaptation parameters
    public struct AdaptationParams {
        public var colorWarmth: Float      // 0 = cool, 1 = warm
        public var motionSpeed: Float      // Relative speed multiplier
        public var complexity: Float       // Visual complexity 0-1
        public var brightness: Float       // Overall brightness
        public var saturation: Float       // Color saturation
        public var pulseIntensity: Float   // Beat-synced pulse strength
    }

    // State tracking
    private var coherenceHistory: [Float] = []
    private var heartRateHistory: [Float] = []
    private var breathingPhase: Float = 0

    // Smoothed outputs
    private var currentParams = AdaptationParams(
        colorWarmth: 0.5,
        motionSpeed: 1.0,
        complexity: 0.5,
        brightness: 0.7,
        saturation: 0.6,
        pulseIntensity: 0.3
    )

    public init() {}

    /// Update adaptation based on bio-signals
    public func update(
        coherence: Float,
        heartRate: Float,
        breathingRate: Float,
        dt: Float
    ) -> AdaptationParams {
        // Update history
        coherenceHistory.append(coherence)
        heartRateHistory.append(heartRate)
        if coherenceHistory.count > 60 { coherenceHistory.removeFirst() }
        if heartRateHistory.count > 60 { heartRateHistory.removeFirst() }

        // Calculate trends
        let coherenceTrend = calculateTrend(coherenceHistory)
        let hrTrend = calculateTrend(heartRateHistory)

        // Update breathing phase
        breathingPhase += dt * breathingRate / 60 * 2 * .pi
        if breathingPhase > 2 * .pi { breathingPhase -= 2 * .pi }

        // Calculate target parameters
        var targetParams = AdaptationParams(
            colorWarmth: 0.5,
            motionSpeed: 1.0,
            complexity: 0.5,
            brightness: 0.7,
            saturation: 0.6,
            pulseIntensity: 0.3
        )

        // Coherence affects warmth and complexity
        targetParams.colorWarmth = coherence * 0.6 + 0.2  // Higher coherence = warmer
        targetParams.complexity = 0.3 + coherence * 0.5   // Higher coherence = more complex (calmer)

        // Heart rate affects speed and pulse
        let normalizedHR = (heartRate - 60) / 60  // 0 at 60bpm, 1 at 120bpm
        targetParams.motionSpeed = 0.5 + normalizedHR * 1.0
        targetParams.pulseIntensity = 0.2 + normalizedHR * 0.4

        // Breathing affects brightness (gentle wave)
        let breathingWave = sin(breathingPhase) * 0.5 + 0.5
        targetParams.brightness = 0.6 + breathingWave * 0.2 + coherence * 0.1

        // Saturation based on overall arousal
        targetParams.saturation = 0.4 + normalizedHR * 0.3 + (1 - coherence) * 0.2

        // Smooth transitions
        let smoothing: Float = 0.1 * dt * 60
        currentParams.colorWarmth += (targetParams.colorWarmth - currentParams.colorWarmth) * smoothing
        currentParams.motionSpeed += (targetParams.motionSpeed - currentParams.motionSpeed) * smoothing
        currentParams.complexity += (targetParams.complexity - currentParams.complexity) * smoothing
        currentParams.brightness += (targetParams.brightness - currentParams.brightness) * smoothing
        currentParams.saturation += (targetParams.saturation - currentParams.saturation) * smoothing
        currentParams.pulseIntensity += (targetParams.pulseIntensity - currentParams.pulseIntensity) * smoothing

        return currentParams
    }

    private func calculateTrend(_ history: [Float]) -> Float {
        guard history.count >= 10 else { return 0 }

        let recent = Array(history.suffix(5))
        let older = Array(history.prefix(5))

        let recentMean = recent.reduce(0, +) / Float(recent.count)
        let olderMean = older.reduce(0, +) / Float(older.count)

        return recentMean - olderMean
    }

    public func reset() {
        coherenceHistory.removeAll()
        heartRateHistory.removeAll()
        breathingPhase = 0
    }
}

// MARK: - Style Transfer Controller

/// Controls visual style transfer in real-time
public final class StyleTransferController {

    public enum VisualStyle: String, CaseIterable {
        case organic = "Organic"
        case geometric = "Geometric"
        case fluid = "Fluid"
        case crystalline = "Crystalline"
        case ethereal = "Ethereal"
        case electric = "Electric"
        case cosmic = "Cosmic"
        case minimal = "Minimal"
    }

    /// Style blend
    public struct StyleBlend {
        public let styles: [(VisualStyle, Float)]
        public let transitionProgress: Float
    }

    // Current style state
    private var currentStyle: VisualStyle = .organic
    private var targetStyle: VisualStyle = .organic
    private var transitionProgress: Float = 1.0
    private let transitionDuration: Float = 2.0

    // Style weights learned from usage
    private var styleAffinities: [VisualStyle: Float] = [:]

    public init() {
        // Initialize equal affinities
        for style in VisualStyle.allCases {
            styleAffinities[style] = 1.0 / Float(VisualStyle.allCases.count)
        }
    }

    /// Select style based on audio/bio context
    public func selectStyle(
        emotion: String,
        audioEnergy: Float,
        coherence: Float,
        tempo: Float
    ) {
        let newStyle: VisualStyle

        // Map context to style
        switch emotion.lowercased() {
        case "calm", "peaceful":
            newStyle = coherence > 0.6 ? .ethereal : .fluid
        case "energetic":
            newStyle = tempo > 130 ? .electric : .geometric
        case "happy":
            newStyle = audioEnergy > 0.6 ? .cosmic : .organic
        case "sad", "melancholic":
            newStyle = .minimal
        case "tense":
            newStyle = .crystalline
        case "euphoric":
            newStyle = .cosmic
        default:
            newStyle = .organic
        }

        // Only change if different
        if newStyle != targetStyle {
            currentStyle = targetStyle
            targetStyle = newStyle
            transitionProgress = 0
        }
    }

    /// Update transition (call each frame)
    public func update(dt: Float) -> StyleBlend {
        if transitionProgress < 1.0 {
            transitionProgress += dt / transitionDuration
            transitionProgress = min(transitionProgress, 1.0)
        }

        if transitionProgress >= 1.0 {
            return StyleBlend(
                styles: [(targetStyle, 1.0)],
                transitionProgress: 1.0
            )
        } else {
            // Smooth easing
            let t = easeInOutCubic(transitionProgress)
            return StyleBlend(
                styles: [(currentStyle, 1 - t), (targetStyle, t)],
                transitionProgress: transitionProgress
            )
        }
    }

    private func easeInOutCubic(_ t: Float) -> Float {
        return t < 0.5
            ? 4 * t * t * t
            : 1 - pow(-2 * t + 2, 3) / 2
    }

    /// Get style parameters for rendering
    public func getStyleParams(_ style: VisualStyle) -> [String: Float] {
        switch style {
        case .organic:
            return ["curvature": 0.8, "noise": 0.4, "symmetry": 0.2, "sharpness": 0.2]
        case .geometric:
            return ["curvature": 0.1, "noise": 0.1, "symmetry": 0.8, "sharpness": 0.9]
        case .fluid:
            return ["curvature": 0.9, "noise": 0.6, "symmetry": 0.1, "sharpness": 0.1]
        case .crystalline:
            return ["curvature": 0.2, "noise": 0.3, "symmetry": 0.7, "sharpness": 1.0]
        case .ethereal:
            return ["curvature": 0.6, "noise": 0.2, "symmetry": 0.4, "sharpness": 0.1]
        case .electric:
            return ["curvature": 0.4, "noise": 0.7, "symmetry": 0.3, "sharpness": 0.8]
        case .cosmic:
            return ["curvature": 0.5, "noise": 0.5, "symmetry": 0.6, "sharpness": 0.5]
        case .minimal:
            return ["curvature": 0.3, "noise": 0.0, "symmetry": 0.5, "sharpness": 0.6]
        }
    }

    /// Learn preference
    public func learnPreference(_ style: VisualStyle, rating: Float) {
        let current = styleAffinities[style] ?? 0.5
        styleAffinities[style] = current * 0.9 + rating * 0.1
    }
}
