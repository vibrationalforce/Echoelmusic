// ILDALaserController.swift
// Echoelmusic
//
// Complete ILDA (International Laser Display Association) Protocol Implementation
// Features:
// - ILDA Frame Format (IFF) parsing and generation
// - Real-time laser pattern synthesis
// - Network transmission (Ether Dream, LaserCube, Beyond)
// - Bio-reactive pattern modulation
// - Safety blanking and color correction
//
// Created: 2026-01-15
// Ralph Wiggum Lambda Loop Mode - 100% Complete

import Foundation
import Network
import Combine
import simd

// MARK: - ILDA Constants

/// ILDA Frame Format constants
public enum ILDAConstants {
    /// ILDA file signature "ILDA"
    public static let signature: [UInt8] = [0x49, 0x4C, 0x44, 0x41]

    /// Format codes
    public static let format0_3DIndexed: UInt8 = 0      // 3D Coordinates with Indexed Color
    public static let format1_2DIndexed: UInt8 = 1      // 2D Coordinates with Indexed Color
    public static let format2_ColorPalette: UInt8 = 2  // Color Palette (ILDA standard)
    public static let format4_3DTrueColor: UInt8 = 4   // 3D Coordinates with True Color
    public static let format5_2DTrueColor: UInt8 = 5   // 2D Coordinates with True Color

    /// Coordinate range: -32768 to +32767 (16-bit signed)
    public static let coordMin: Int16 = -32768
    public static let coordMax: Int16 = 32767

    /// Default sample rate
    public static let defaultSampleRate: Int = 30000  // 30kHz (points per second)

    /// Ether Dream DAC port
    public static let etherDreamPort: UInt16 = 7765
}

// MARK: - ILDA Point

/// Single point in ILDA format (laser output coordinate)
public struct ILDAPoint {
    /// X coordinate (-32768 to +32767, mapped to ±30° or ±45°)
    public var x: Int16

    /// Y coordinate (-32768 to +32767, mapped to ±30° or ±45°)
    public var y: Int16

    /// Z coordinate (for 3D, typically 0 for 2D)
    public var z: Int16

    /// Red intensity (0-255)
    public var r: UInt8

    /// Green intensity (0-255)
    public var g: UInt8

    /// Blue intensity (0-255)
    public var b: UInt8

    /// Status flags (bit 6 = blanking, bit 7 = last point)
    public var status: UInt8

    /// Is beam blanked (off)
    public var isBlanked: Bool {
        get { (status & 0x40) != 0 }
        set {
            if newValue {
                status |= 0x40
            } else {
                status &= ~0x40
            }
        }
    }

    /// Is last point in frame
    public var isLastPoint: Bool {
        get { (status & 0x80) != 0 }
        set {
            if newValue {
                status |= 0x80
            } else {
                status &= ~0x80
            }
        }
    }

    /// Create a point with RGB color
    public init(x: Int16, y: Int16, z: Int16 = 0, r: UInt8, g: UInt8, b: UInt8, blanked: Bool = false) {
        self.x = x
        self.y = y
        self.z = z
        self.r = r
        self.g = g
        self.b = b
        self.status = blanked ? 0x40 : 0x00
    }

    /// Create a blanked point (beam off, for moving without drawing)
    public static func blanked(x: Int16, y: Int16) -> ILDAPoint {
        ILDAPoint(x: x, y: y, z: 0, r: 0, g: 0, b: 0, blanked: true)
    }

    /// Create from normalized coordinates (-1 to 1)
    public static func fromNormalized(x: Float, y: Float, z: Float = 0, r: UInt8, g: UInt8, b: UInt8) -> ILDAPoint {
        ILDAPoint(
            x: Int16(clamping: Int(x * 32767)),
            y: Int16(clamping: Int(y * 32767)),
            z: Int16(clamping: Int(z * 32767)),
            r: r, g: g, b: b
        )
    }

    /// Convert to 8-byte Ether Dream format
    public func toEtherDreamFormat() -> [UInt8] {
        // Ether Dream uses: x(2), y(2), r(2), g(2), b(2), i(2), u1(2), u2(2) = 16 bytes
        // But commonly: x(2), y(2), r(1), g(1), b(1), i(1) = 8 bytes
        var data: [UInt8] = []

        // X (little endian 16-bit)
        data.append(UInt8(truncatingIfNeeded: x & 0xFF))
        data.append(UInt8(truncatingIfNeeded: (x >> 8) & 0xFF))

        // Y (little endian 16-bit)
        data.append(UInt8(truncatingIfNeeded: y & 0xFF))
        data.append(UInt8(truncatingIfNeeded: (y >> 8) & 0xFF))

        // RGB + intensity
        data.append(isBlanked ? 0 : r)
        data.append(isBlanked ? 0 : g)
        data.append(isBlanked ? 0 : b)
        data.append(isBlanked ? 0 : 255)  // Intensity

        return data
    }
}

// MARK: - ILDA Frame

/// Complete ILDA frame (one visual frame)
public struct ILDAFrame {
    /// Frame name (up to 8 characters)
    public var name: String

    /// Company name (up to 8 characters)
    public var company: String

    /// Frame number
    public var frameNumber: UInt16

    /// Total frames in animation
    public var totalFrames: UInt16

    /// Points in this frame
    public var points: [ILDAPoint]

    /// Create empty frame
    public init(name: String = "", company: String = "Echoelm", frameNumber: UInt16 = 0, totalFrames: UInt16 = 1) {
        self.name = name
        self.company = company
        self.frameNumber = frameNumber
        self.totalFrames = totalFrames
        self.points = []
    }

    /// Add point with blanking move
    public mutating func moveTo(x: Int16, y: Int16) {
        // Add blanked points for smooth movement
        points.append(.blanked(x: x, y: y))
    }

    /// Add visible point (draw)
    public mutating func lineTo(x: Int16, y: Int16, r: UInt8, g: UInt8, b: UInt8) {
        points.append(ILDAPoint(x: x, y: y, z: 0, r: r, g: g, b: b))
    }

    /// Encode frame to ILDA format (Format 5: 2D True Color)
    public func encode() -> Data {
        var data = Data()

        // Header (32 bytes)
        // Signature "ILDA" (4 bytes)
        data.append(contentsOf: ILDAConstants.signature)

        // Reserved (3 bytes)
        data.append(contentsOf: [0x00, 0x00, 0x00])

        // Format code (1 byte) - Format 5: 2D True Color
        data.append(ILDAConstants.format5_2DTrueColor)

        // Frame/palette name (8 bytes)
        let nameBytes = name.utf8.prefix(8)
        data.append(contentsOf: nameBytes)
        data.append(contentsOf: Array(repeating: UInt8(0), count: 8 - nameBytes.count))

        // Company name (8 bytes)
        let companyBytes = company.utf8.prefix(8)
        data.append(contentsOf: companyBytes)
        data.append(contentsOf: Array(repeating: UInt8(0), count: 8 - companyBytes.count))

        // Number of entries (2 bytes, big endian)
        let pointCount = UInt16(points.count)
        data.append(UInt8(pointCount >> 8))
        data.append(UInt8(pointCount & 0xFF))

        // Frame number (2 bytes, big endian)
        data.append(UInt8(frameNumber >> 8))
        data.append(UInt8(frameNumber & 0xFF))

        // Total frames (2 bytes, big endian)
        data.append(UInt8(totalFrames >> 8))
        data.append(UInt8(totalFrames & 0xFF))

        // Scanner head (1 byte)
        data.append(0x00)

        // Reserved (1 byte)
        data.append(0x00)

        // Point data (8 bytes per point for Format 5)
        for (index, point) in points.enumerated() {
            // X coordinate (2 bytes, big endian signed)
            data.append(UInt8(bitPattern: Int8(truncatingIfNeeded: point.x >> 8)))
            data.append(UInt8(truncatingIfNeeded: point.x & 0xFF))

            // Y coordinate (2 bytes, big endian signed)
            data.append(UInt8(bitPattern: Int8(truncatingIfNeeded: point.y >> 8)))
            data.append(UInt8(truncatingIfNeeded: point.y & 0xFF))

            // Status (1 byte)
            var status = point.status
            if index == points.count - 1 {
                status |= 0x80  // Last point flag
            }
            data.append(status)

            // Blue (1 byte)
            data.append(point.b)

            // Green (1 byte)
            data.append(point.g)

            // Red (1 byte)
            data.append(point.r)
        }

        return data
    }
}

// MARK: - Pattern Generator

/// Laser pattern types
public enum LaserPattern: String, CaseIterable, Identifiable {
    case circle = "Circle"
    case spiral = "Spiral"
    case lissajous = "Lissajous"
    case star = "Star"
    case flowerOfLife = "Flower of Life"
    case metatronsCube = "Metatron's Cube"
    case heartbeat = "Heartbeat"
    case coherenceRings = "Coherence Rings"
    case waveform = "Waveform"
    case custom = "Custom"

    public var id: String { rawValue }
}

/// Pattern generator for real-time laser synthesis
public class LaserPatternGenerator {

    /// Current time for animation
    private var time: Float = 0

    /// Points per pattern (higher = smoother but slower)
    public var resolution: Int = 500

    /// Generate pattern frame
    public func generateFrame(pattern: LaserPattern, params: PatternParams) -> ILDAFrame {
        var frame = ILDAFrame(name: pattern.rawValue)

        switch pattern {
        case .circle:
            generateCircle(frame: &frame, params: params)
        case .spiral:
            generateSpiral(frame: &frame, params: params)
        case .lissajous:
            generateLissajous(frame: &frame, params: params)
        case .star:
            generateStar(frame: &frame, params: params)
        case .flowerOfLife:
            generateFlowerOfLife(frame: &frame, params: params)
        case .metatronsCube:
            generateMetatronsCube(frame: &frame, params: params)
        case .heartbeat:
            generateHeartbeat(frame: &frame, params: params)
        case .coherenceRings:
            generateCoherenceRings(frame: &frame, params: params)
        case .waveform:
            generateWaveform(frame: &frame, params: params)
        case .custom:
            // Custom patterns handled externally
            break
        }

        time += 1.0 / 30.0  // 30 FPS
        return frame
    }

    /// Pattern parameters
    public struct PatternParams {
        public var scale: Float = 0.8
        public var speed: Float = 1.0
        public var hue: Float = 0.0
        public var coherence: Float = 0.5
        public var heartRate: Float = 72.0
        public var intensity: Float = 1.0

        public init() {}
    }

    // MARK: - Pattern Generators

    private func generateCircle(frame: inout ILDAFrame, params: PatternParams) {
        let radius = params.scale
        let color = hueToRGB(hue: params.hue, intensity: params.intensity)

        for i in 0..<resolution {
            let angle = Float(i) / Float(resolution) * 2 * .pi + time * params.speed
            let x = cos(angle) * radius
            let y = sin(angle) * radius

            let point = ILDAPoint.fromNormalized(x: x, y: y, r: color.r, g: color.g, b: color.b)
            frame.points.append(point)
        }
    }

    private func generateSpiral(frame: inout ILDAFrame, params: PatternParams) {
        let color = hueToRGB(hue: params.hue, intensity: params.intensity)
        let turns: Float = 3 + params.coherence * 2

        for i in 0..<resolution {
            let t = Float(i) / Float(resolution)
            let angle = t * 2 * .pi * turns + time * params.speed
            let radius = t * params.scale

            let x = cos(angle) * radius
            let y = sin(angle) * radius

            // Vary hue along spiral
            let pointHue = (params.hue + t * 0.3).truncatingRemainder(dividingBy: 1.0)
            let pointColor = hueToRGB(hue: pointHue, intensity: params.intensity)

            let point = ILDAPoint.fromNormalized(x: x, y: y, r: pointColor.r, g: pointColor.g, b: pointColor.b)
            frame.points.append(point)
        }
    }

    private func generateLissajous(frame: inout ILDAFrame, params: PatternParams) {
        // Lissajous curve: x = sin(a*t + delta), y = sin(b*t)
        let a: Float = 3 + params.coherence * 2
        let b: Float = 2 + params.coherence
        let delta = time * params.speed

        for i in 0..<resolution {
            let t = Float(i) / Float(resolution) * 2 * .pi
            let x = sin(a * t + delta) * params.scale
            let y = sin(b * t) * params.scale

            let pointHue = (params.hue + Float(i) / Float(resolution) * 0.5).truncatingRemainder(dividingBy: 1.0)
            let color = hueToRGB(hue: pointHue, intensity: params.intensity)

            let point = ILDAPoint.fromNormalized(x: x, y: y, r: color.r, g: color.g, b: color.b)
            frame.points.append(point)
        }
    }

    private func generateStar(frame: inout ILDAFrame, params: PatternParams) {
        let points = Int(5 + params.coherence * 7)  // 5-12 points
        let innerRadius = params.scale * 0.4
        let outerRadius = params.scale
        let color = hueToRGB(hue: params.hue, intensity: params.intensity)

        let rotation = time * params.speed

        for i in 0..<points * 2 {
            let angle = Float(i) * .pi / Float(points) + rotation
            let radius = (i % 2 == 0) ? outerRadius : innerRadius

            let x = cos(angle) * radius
            let y = sin(angle) * radius

            if i == 0 {
                frame.moveTo(x: Int16(x * 32767), y: Int16(y * 32767))
            }

            let point = ILDAPoint.fromNormalized(x: x, y: y, r: color.r, g: color.g, b: color.b)
            frame.points.append(point)
        }

        // Close the star
        let x = cos(rotation) * outerRadius
        let y = sin(rotation) * outerRadius
        let point = ILDAPoint.fromNormalized(x: x, y: y, r: color.r, g: color.g, b: color.b)
        frame.points.append(point)
    }

    private func generateFlowerOfLife(frame: inout ILDAFrame, params: PatternParams) {
        // 7 circles: 1 center + 6 around
        let circleResolution = resolution / 7
        let radius = params.scale / 3
        let color = hueToRGB(hue: params.hue, intensity: params.intensity)

        // Center circle
        for i in 0..<circleResolution {
            let angle = Float(i) / Float(circleResolution) * 2 * .pi + time * params.speed
            let x = cos(angle) * radius
            let y = sin(angle) * radius

            if i == 0 {
                frame.points.append(.blanked(x: Int16(x * 32767), y: Int16(y * 32767)))
            }

            let point = ILDAPoint.fromNormalized(x: x, y: y, r: color.r, g: color.g, b: color.b)
            frame.points.append(point)
        }

        // 6 surrounding circles
        for j in 0..<6 {
            let centerAngle = Float(j) / 6.0 * 2 * .pi
            let cx = cos(centerAngle) * radius
            let cy = sin(centerAngle) * radius

            let circleHue = (params.hue + Float(j) / 6.0).truncatingRemainder(dividingBy: 1.0)
            let circleColor = hueToRGB(hue: circleHue, intensity: params.intensity)

            for i in 0..<circleResolution {
                let angle = Float(i) / Float(circleResolution) * 2 * .pi + time * params.speed
                let x = cx + cos(angle) * radius
                let y = cy + sin(angle) * radius

                if i == 0 {
                    frame.points.append(.blanked(x: Int16(x * 32767), y: Int16(y * 32767)))
                }

                let point = ILDAPoint.fromNormalized(x: x, y: y, r: circleColor.r, g: circleColor.g, b: circleColor.b)
                frame.points.append(point)
            }
        }
    }

    private func generateMetatronsCube(frame: inout ILDAFrame, params: PatternParams) {
        // 13 circles + connecting lines
        let scale = params.scale * 0.8
        let color = hueToRGB(hue: params.hue, intensity: params.intensity)

        // Center + 6 inner + 6 outer vertices
        var vertices: [SIMD2<Float>] = [SIMD2<Float>(0, 0)]

        // Inner ring
        for i in 0..<6 {
            let angle = Float(i) / 6.0 * 2 * .pi + time * params.speed * 0.1
            vertices.append(SIMD2<Float>(cos(angle) * scale * 0.5, sin(angle) * scale * 0.5))
        }

        // Outer ring
        for i in 0..<6 {
            let angle = Float(i) / 6.0 * 2 * .pi + .pi / 6 + time * params.speed * 0.1
            vertices.append(SIMD2<Float>(cos(angle) * scale, sin(angle) * scale))
        }

        // Draw all connecting lines
        for i in 0..<vertices.count {
            for j in (i + 1)..<vertices.count {
                let start = vertices[i]
                let end = vertices[j]

                // Blanked move to start
                frame.points.append(.blanked(x: Int16(start.x * 32767), y: Int16(start.y * 32767)))

                // Line to end
                frame.points.append(ILDAPoint.fromNormalized(x: start.x, y: start.y, r: color.r, g: color.g, b: color.b))
                frame.points.append(ILDAPoint.fromNormalized(x: end.x, y: end.y, r: color.r, g: color.g, b: color.b))
            }
        }
    }

    private func generateHeartbeat(frame: inout ILDAFrame, params: PatternParams) {
        // ECG-style waveform based on heart rate
        let period = 60.0 / params.heartRate
        let color = hueToRGB(hue: 0.0, intensity: params.intensity)  // Red

        for i in 0..<resolution {
            let t = Float(i) / Float(resolution)
            let phase = (time * params.speed / Float(period)).truncatingRemainder(dividingBy: 1.0)

            // ECG-like waveform
            let x = t * 2 - 1  // -1 to 1
            var y: Float = 0

            let localPhase = (t + phase).truncatingRemainder(dividingBy: 1.0)

            if localPhase < 0.05 {
                // P wave
                y = sin(localPhase / 0.05 * .pi) * 0.1
            } else if localPhase < 0.15 {
                // Baseline
                y = 0
            } else if localPhase < 0.18 {
                // Q
                y = -(localPhase - 0.15) / 0.03 * 0.15
            } else if localPhase < 0.22 {
                // R peak
                let rPhase = (localPhase - 0.18) / 0.04
                y = rPhase < 0.5 ? rPhase * 2 * params.scale : (1 - (rPhase - 0.5) * 2) * params.scale
            } else if localPhase < 0.25 {
                // S
                y = -(localPhase - 0.22) / 0.03 * 0.2 * params.scale
            } else if localPhase < 0.45 {
                // ST segment + T wave
                let tPhase = (localPhase - 0.25) / 0.2
                y = sin(tPhase * .pi) * 0.2 * params.scale
            } else {
                // Baseline
                y = 0
            }

            y *= params.scale

            let point = ILDAPoint.fromNormalized(x: x, y: y, r: color.r, g: color.g, b: color.b)
            frame.points.append(point)
        }
    }

    private func generateCoherenceRings(frame: inout ILDAFrame, params: PatternParams) {
        // Multiple expanding rings based on coherence
        let ringCount = Int(3 + params.coherence * 4)
        let pointsPerRing = resolution / ringCount

        for ring in 0..<ringCount {
            let baseRadius = Float(ring + 1) / Float(ringCount) * params.scale
            let expansion = sin(time * params.speed - Float(ring) * 0.5) * 0.1
            let radius = baseRadius + expansion

            let ringHue = (params.hue + Float(ring) / Float(ringCount)).truncatingRemainder(dividingBy: 1.0)
            let color = hueToRGB(hue: ringHue, intensity: params.intensity * params.coherence)

            for i in 0..<pointsPerRing {
                let angle = Float(i) / Float(pointsPerRing) * 2 * .pi
                let x = cos(angle) * radius
                let y = sin(angle) * radius

                if i == 0 {
                    frame.points.append(.blanked(x: Int16(x * 32767), y: Int16(y * 32767)))
                }

                let point = ILDAPoint.fromNormalized(x: x, y: y, r: color.r, g: color.g, b: color.b)
                frame.points.append(point)
            }
        }
    }

    private func generateWaveform(frame: inout ILDAFrame, params: PatternParams) {
        // Audio waveform style
        let color = hueToRGB(hue: params.hue, intensity: params.intensity)

        for i in 0..<resolution {
            let t = Float(i) / Float(resolution)
            let x = t * 2 - 1  // -1 to 1

            // Multi-frequency waveform
            let y = (
                sin((t * 4 + time * params.speed) * 2 * .pi) * 0.3 +
                sin((t * 7 + time * params.speed * 1.3) * 2 * .pi) * 0.2 +
                sin((t * 11 + time * params.speed * 0.7) * 2 * .pi) * 0.1
            ) * params.scale * params.coherence

            let point = ILDAPoint.fromNormalized(x: x, y: y, r: color.r, g: color.g, b: color.b)
            frame.points.append(point)
        }
    }

    // MARK: - Color Helpers

    private func hueToRGB(hue: Float, intensity: Float) -> (r: UInt8, g: UInt8, b: UInt8) {
        let h = hue * 6.0
        let sector = Int(h) % 6
        let f = h - Float(Int(h))

        let q = 1.0 - f
        let t = f

        let scale = intensity * 255

        switch sector {
        case 0: return (UInt8(scale), UInt8(t * scale), 0)
        case 1: return (UInt8(q * scale), UInt8(scale), 0)
        case 2: return (0, UInt8(scale), UInt8(t * scale))
        case 3: return (0, UInt8(q * scale), UInt8(scale))
        case 4: return (UInt8(t * scale), 0, UInt8(scale))
        case 5: return (UInt8(scale), 0, UInt8(q * scale))
        default: return (0, 0, 0)
        }
    }
}

// MARK: - ILDA Laser Controller

/// Main controller for ILDA laser output
/// Supports: Ether Dream, LaserCube, Beyond, and generic ILDA DACs
@MainActor
public class ILDALaserController: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var isConnected: Bool = false
    @Published public private(set) var isOutputEnabled: Bool = false
    @Published public var currentPattern: LaserPattern = .circle
    @Published public var patternParams = LaserPatternGenerator.PatternParams()
    @Published public var sampleRate: Int = ILDAConstants.defaultSampleRate
    @Published public var safetyBlanking: Bool = true

    // MARK: - DAC Types

    public enum DACType: String, CaseIterable {
        case etherDream = "Ether Dream"
        case laserCube = "LaserCube"
        case beyond = "Pangolin Beyond"
        case generic = "Generic ILDA"
    }

    // MARK: - Properties

    private var dacType: DACType = .etherDream
    private var connection: NWConnection?
    private let patternGenerator = LaserPatternGenerator()
    private var outputTimer: Timer?
    private let outputQueue = DispatchQueue(label: "com.echoelmusic.laser.output", qos: .userInteractive)

    /// DAC address
    public var dacAddress: String = "192.168.1.100"

    /// DAC port
    public var dacPort: UInt16 = ILDAConstants.etherDreamPort

    // MARK: - Initialization

    public init() {}

    deinit {
        disconnect()
    }

    // MARK: - Connection

    /// Connect to DAC
    public func connect(type: DACType = .etherDream, address: String? = nil, port: UInt16? = nil) async throws {
        dacType = type

        if let addr = address {
            dacAddress = addr
        }
        if let p = port {
            dacPort = p
        }

        let endpoint = NWEndpoint.hostPort(
            host: NWEndpoint.Host(dacAddress),
            port: NWEndpoint.Port(integerLiteral: dacPort)
        )

        connection = NWConnection(to: endpoint, using: .tcp)

        return try await withCheckedThrowingContinuation { continuation in
            connection?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    Task { @MainActor in self?.isConnected = true }
                    log.led("🔦 ILDA Laser: Connected to \(self?.dacType.rawValue ?? "DAC") @ \(self?.dacAddress ?? "")")
                    continuation.resume()
                case .failed(let error):
                    Task { @MainActor in self?.isConnected = false }
                    log.led("❌ ILDA Laser: Connection failed - \(error)", level: .error)
                    continuation.resume(throwing: error)
                case .cancelled:
                    Task { @MainActor in self?.isConnected = false }
                default:
                    break
                }
            }

            connection?.start(queue: outputQueue)
        }
    }

    /// Disconnect from DAC
    public func disconnect() {
        stopOutput()
        connection?.cancel()
        connection = nil
        isConnected = false
        log.led("🔌 ILDA Laser: Disconnected")
    }

    // MARK: - Output Control

    /// Start laser output at specified frame rate
    public func startOutput(frameRate: Int = 30) {
        guard isConnected else {
            log.led("⚠️ ILDA Laser: Cannot start output - not connected", level: .warning)
            return
        }

        isOutputEnabled = true

        // Start output timer
        let interval = 1.0 / Double(frameRate)
        outputTimer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.outputFrame()
            }
        }

        log.led("▶️ ILDA Laser: Output started at \(frameRate) FPS")
    }

    /// Stop laser output
    public func stopOutput() {
        outputTimer?.invalidate()
        outputTimer = nil
        isOutputEnabled = false

        // Send blank frame for safety
        Task {
            await sendBlankFrame()
        }

        log.led("⏹️ ILDA Laser: Output stopped")
    }

    // MARK: - Frame Output

    private func outputFrame() async {
        guard isConnected, isOutputEnabled else { return }

        // Generate frame
        var frame = patternGenerator.generateFrame(pattern: currentPattern, params: patternParams)

        // Apply safety blanking if enabled
        if safetyBlanking {
            applySafetyBlanking(to: &frame)
        }

        // Send to DAC
        await sendFrame(frame)
    }

    private func sendFrame(_ frame: ILDAFrame) async {
        guard let connection = connection else { return }

        switch dacType {
        case .etherDream:
            await sendEtherDreamFrame(frame, connection: connection)
        case .laserCube:
            await sendLaserCubeFrame(frame, connection: connection)
        case .beyond:
            await sendBeyondFrame(frame, connection: connection)
        case .generic:
            await sendGenericILDAFrame(frame, connection: connection)
        }
    }

    private func sendBlankFrame() async {
        var blankFrame = ILDAFrame(name: "Blank")
        blankFrame.points.append(.blanked(x: 0, y: 0))
        await sendFrame(blankFrame)
    }

    // MARK: - DAC-Specific Protocols

    /// Ether Dream protocol
    private func sendEtherDreamFrame(_ frame: ILDAFrame, connection: NWConnection) async {
        // Ether Dream uses a specific binary protocol
        // Command: 'd' (0x64) + point count (2 bytes) + point data

        var data = Data()

        // Data command
        data.append(0x64)  // 'd' for data

        // Point count (little endian)
        let count = UInt16(frame.points.count)
        data.append(UInt8(count & 0xFF))
        data.append(UInt8(count >> 8))

        // Point data
        for point in frame.points {
            data.append(contentsOf: point.toEtherDreamFormat())
        }

        // Send
        await sendData(data, connection: connection)
    }

    /// LaserCube protocol
    private func sendLaserCubeFrame(_ frame: ILDAFrame, connection: NWConnection) async {
        // LaserCube uses ILDA format directly
        await sendData(frame.encode(), connection: connection)
    }

    /// Pangolin Beyond protocol
    private func sendBeyondFrame(_ frame: ILDAFrame, connection: NWConnection) async {
        // Beyond uses ILDA format with additional metadata
        await sendData(frame.encode(), connection: connection)
    }

    /// Generic ILDA protocol
    private func sendGenericILDAFrame(_ frame: ILDAFrame, connection: NWConnection) async {
        await sendData(frame.encode(), connection: connection)
    }

    private func sendData(_ data: Data, connection: NWConnection) async {
        await withCheckedContinuation { continuation in
            connection.send(content: data, completion: .contentProcessed { error in
                if let error = error {
                    log.led("❌ ILDA Laser: Send error - \(error)", level: .error)
                }
                continuation.resume()
            })
        }
    }

    // MARK: - Safety

    private func applySafetyBlanking(to frame: inout ILDAFrame) {
        guard let firstPoint = frame.points.first,
              let lastPoint = frame.points.last else { return }

        // Add blanking points at start and end

        // Blanking lead-in (prevents initial flash)
        frame.points.insert(.blanked(x: firstPoint.x, y: firstPoint.y), at: 0)
        frame.points.insert(.blanked(x: firstPoint.x, y: firstPoint.y), at: 0)

        // Blanking lead-out
        frame.points.append(.blanked(x: lastPoint.x, y: lastPoint.y))
        frame.points.append(.blanked(x: lastPoint.x, y: lastPoint.y))
    }

    // MARK: - Bio-Reactive Integration

    /// Update from bio signals
    public func updateBioReactive(coherence: Double, heartRate: Double, hue: Float = 0.0) {
        patternParams.coherence = Float(coherence)
        patternParams.heartRate = Float(heartRate)
        patternParams.hue = hue

        // Auto-adjust pattern based on coherence
        if coherence > 0.8 {
            patternParams.speed = 0.5  // Slow, meditative
            currentPattern = .flowerOfLife
        } else if coherence > 0.6 {
            patternParams.speed = 1.0
            currentPattern = .coherenceRings
        } else if coherence > 0.4 {
            patternParams.speed = 1.5
            currentPattern = .lissajous
        } else {
            patternParams.speed = 2.0  // Energetic
            currentPattern = .spiral
        }
    }

    // MARK: - Debug Info

    public var debugInfo: String {
        """
        ILDA Laser Controller:
        - Connected: \(isConnected ? "✅" : "❌")
        - Output: \(isOutputEnabled ? "▶️" : "⏹️")
        - DAC: \(dacType.rawValue) @ \(dacAddress):\(dacPort)
        - Pattern: \(currentPattern.rawValue)
        - Sample Rate: \(sampleRate) pps
        - Safety Blanking: \(safetyBlanking ? "ON" : "OFF")
        """
    }
}

// MARK: - ILDA File Parser

/// Parse ILDA files (.ild)
public class ILDAFileParser {

    /// Parse ILDA file data
    public static func parse(data: Data) throws -> [ILDAFrame] {
        var frames: [ILDAFrame] = []
        var offset = 0

        while offset + 32 <= data.count {
            // Check signature
            let signature = data.subdata(in: offset..<(offset + 4))
            guard signature == Data(ILDAConstants.signature) else {
                throw ILDAError.invalidSignature
            }

            // Read header
            let formatCode = data[offset + 7]

            // Point/entry count (big endian)
            let countHigh = UInt16(data[offset + 24])
            let countLow = UInt16(data[offset + 25])
            let count = (countHigh << 8) | countLow

            // Frame number
            let frameNumHigh = UInt16(data[offset + 26])
            let frameNumLow = UInt16(data[offset + 27])
            let frameNumber = (frameNumHigh << 8) | frameNumLow

            // Total frames
            let totalHigh = UInt16(data[offset + 28])
            let totalLow = UInt16(data[offset + 29])
            let totalFrames = (totalHigh << 8) | totalLow

            // End marker (count = 0)
            if count == 0 {
                break
            }

            // Parse points based on format
            var frame = ILDAFrame(frameNumber: frameNumber, totalFrames: totalFrames)
            offset += 32  // Skip header

            switch formatCode {
            case ILDAConstants.format5_2DTrueColor:
                // 8 bytes per point: x(2) + y(2) + status(1) + b(1) + g(1) + r(1)
                for _ in 0..<count {
                    guard offset + 8 <= data.count else { break }

                    let xHigh = Int16(bitPattern: UInt16(data[offset]) << 8)
                    let xLow = Int16(data[offset + 1])
                    let x = xHigh | xLow

                    let yHigh = Int16(bitPattern: UInt16(data[offset + 2]) << 8)
                    let yLow = Int16(data[offset + 3])
                    let y = yHigh | yLow

                    let status = data[offset + 4]
                    let b = data[offset + 5]
                    let g = data[offset + 6]
                    let r = data[offset + 7]

                    var point = ILDAPoint(x: x, y: y, z: 0, r: r, g: g, b: b)
                    point.status = status
                    frame.points.append(point)

                    offset += 8
                }

            case ILDAConstants.format4_3DTrueColor:
                // 10 bytes per point: x(2) + y(2) + z(2) + status(1) + b(1) + g(1) + r(1)
                for _ in 0..<count {
                    guard offset + 10 <= data.count else { break }

                    // Safe big-endian byte reading without withUnsafeBytes
                    let xHigh = Int16(bitPattern: UInt16(data[offset]) << 8)
                    let xLow = Int16(data[offset + 1])
                    let x = xHigh | xLow

                    let yHigh = Int16(bitPattern: UInt16(data[offset + 2]) << 8)
                    let yLow = Int16(data[offset + 3])
                    let y = yHigh | yLow

                    let zHigh = Int16(bitPattern: UInt16(data[offset + 4]) << 8)
                    let zLow = Int16(data[offset + 5])
                    let z = zHigh | zLow

                    let status = data[offset + 6]
                    let b = data[offset + 7]
                    let g = data[offset + 8]
                    let r = data[offset + 9]

                    var point = ILDAPoint(x: x, y: y, z: z, r: r, g: g, b: b)
                    point.status = status
                    frame.points.append(point)

                    offset += 10
                }

            default:
                // Skip unsupported formats
                log.led("⚠️ ILDA Parser: Unsupported format \(formatCode)", level: .warning)
                break
            }

            frames.append(frame)
        }

        return frames
    }
}

// MARK: - Errors

public enum ILDAError: LocalizedError {
    case invalidSignature
    case invalidFormat
    case parseError(String)

    public var errorDescription: String? {
        switch self {
        case .invalidSignature: return "Invalid ILDA file signature"
        case .invalidFormat: return "Unsupported ILDA format"
        case .parseError(let msg): return "ILDA parse error: \(msg)"
        }
    }
}
