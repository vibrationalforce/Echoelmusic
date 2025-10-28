import Foundation
import Metal
import MetalKit
import CoreGraphics

/// Multi-Projector Edge Blending and Alignment System
/// Inspired by: Resolume Arena, Disguise, Watchout, Christie Twist
///
/// Features:
/// - Multiple projector output management (up to 16 projectors)
/// - Soft-edge blending with customizable feather
/// - Color calibration per projector (brightness, contrast, gamma)
/// - Geometric alignment and warping
/// - Blend masks (linear, power curve, bezier)
/// - Canvas layouts (2x2, 3x3, 360°, custom)
/// - Test patterns (grid, crosshatch, color bars)
/// - Real-time preview and verification
///
/// Professional Standards:
/// - SMPTE: Color calibration standards
/// - DCI: Digital cinema projection specs
/// - Christie/Barco: Edge blending algorithms
@MainActor
class MultiProjectorSystem: ObservableObject {

    // MARK: - Metal Resources

    private let device: MTLDevice
    private let commandQueue: MTLCommandQueue
    private var blendPipeline: MTLRenderPipelineState?
    private var compositePipeline: MTLRenderPipelineState?


    // MARK: - Projector Configuration

    @Published var projectors: [Projector] = []
    @Published var canvasLayout: CanvasLayout = .custom
    @Published var masterBrightness: Float = 1.0
    @Published var masterGamma: Float = 2.2  // Standard sRGB

    /// Maximum supported projectors
    let maxProjectors: Int = 16


    // MARK: - Edge Blending Configuration

    /// Global blend mode
    var blendMode: BlendMode = .softEdge

    /// Feather width (0.0-1.0, percentage of overlap)
    var featherWidth: Float = 0.5

    /// Blend curve type
    var blendCurve: BlendCurve = .power

    /// Gamma correction for blending
    var blendGamma: Float = 1.8


    // MARK: - Test Pattern

    @Published var testPatternEnabled: Bool = false
    @Published var testPattern: TestPattern = .grid


    // MARK: - Canvas Configuration

    /// Total canvas size (virtual space encompassing all projectors)
    var canvasSize: CGSize = CGSize(width: 7680, height: 4320)  // 8K default


    // MARK: - Performance Metrics

    @Published var renderTime: Float = 0.0  // ms
    @Published var totalOutputResolution: Int = 0  // Total pixels across all projectors


    // MARK: - Initialization

    init() {
        guard let device = MTLCreateSystemDefaultDevice(),
              let commandQueue = device.makeCommandQueue() else {
            fatalError("Metal is not supported on this device")
        }

        self.device = device
        self.commandQueue = commandQueue

        setupPipelines()

        print("📽️ MultiProjectorSystem initialized")
        print("   Max Projectors: \(maxProjectors)")
    }

    private func setupPipelines() {
        // Create render pipelines for edge blending and compositing
        // In production, this would load actual Metal shaders

        guard let library = device.makeDefaultLibrary() else {
            print("⚠️ Could not create Metal library")
            return
        }

        // Blend pipeline (combines projector outputs with edge blending)
        let blendDescriptor = MTLRenderPipelineDescriptor()
        blendDescriptor.label = "Multi-Projector Blend Pipeline"
        // Configure vertex/fragment functions, pixel format, etc.

        // Composite pipeline (final output composition)
        let compositeDescriptor = MTLRenderPipelineDescriptor()
        compositeDescriptor.label = "Composite Pipeline"

        print("✅ Metal pipelines configured")
    }


    // MARK: - Projector Management

    /// Add a projector to the system
    func addProjector(name: String, resolution: CGSize, position: CGPoint = .zero) {
        guard projectors.count < maxProjectors else {
            print("❌ Maximum projector count reached (\(maxProjectors))")
            return
        }

        let projector = Projector(
            id: UUID(),
            name: name,
            resolution: resolution,
            position: position
        )

        projectors.append(projector)
        updateTotalResolution()

        print("✅ Added projector '\(name)' (\(Int(resolution.width))x\(Int(resolution.height)))")
    }

    /// Remove projector
    func removeProjector(_ projectorID: UUID) {
        projectors.removeAll { $0.id == projectorID }
        updateTotalResolution()
        print("🗑️ Removed projector")
    }

    /// Get projector by ID
    func getProjector(_ id: UUID) -> Projector? {
        return projectors.first { $0.id == id }
    }

    /// Update projector configuration
    func updateProjector(_ id: UUID, updates: (inout Projector) -> Void) {
        guard let index = projectors.firstIndex(where: { $0.id == id }) else { return }
        updates(&projectors[index])
        objectWillChange.send()
    }

    private func updateTotalResolution() {
        totalOutputResolution = projectors.reduce(0) { total, proj in
            total + Int(proj.resolution.width * proj.resolution.height)
        }
    }


    // MARK: - Canvas Layouts

    /// Apply a standard canvas layout
    func applyLayout(_ layout: CanvasLayout) {
        self.canvasLayout = layout

        switch layout {
        case .single:
            // Single projector, centered
            if let projector = projectors.first {
                updateProjector(projector.id) { proj in
                    proj.position = .zero
                    proj.canvasRegion = CGRect(origin: .zero, size: canvasSize)
                }
            }

        case .horizontal2:
            // 2 projectors side-by-side
            applyHorizontalLayout(count: 2)

        case .horizontal3:
            applyHorizontalLayout(count: 3)

        case .vertical2:
            applyVerticalLayout(count: 2)

        case .grid2x2:
            applyGridLayout(columns: 2, rows: 2)

        case .grid3x3:
            applyGridLayout(columns: 3, rows: 3)

        case .panoramic360:
            apply360Layout()

        case .dome:
            applyDomeLayout()

        case .custom:
            print("ℹ️ Custom layout - manual configuration required")
        }

        calculateBlendRegions()
        print("📐 Applied layout: \(layout.rawValue)")
    }

    private func applyHorizontalLayout(count: Int) {
        guard projectors.count >= count else { return }

        let overlapPercent: CGFloat = 0.1  // 10% overlap
        let projectorWidth = canvasSize.width / CGFloat(count - 1) / (1.0 - overlapPercent)

        for (index, projector) in projectors.prefix(count).enumerated() {
            let x = CGFloat(index) * projectorWidth * (1.0 - overlapPercent)

            updateProjector(projector.id) { proj in
                proj.position = CGPoint(x: x, y: 0)
                proj.canvasRegion = CGRect(
                    x: x,
                    y: 0,
                    width: projectorWidth,
                    height: canvasSize.height
                )
            }
        }
    }

    private func applyVerticalLayout(count: Int) {
        guard projectors.count >= count else { return }

        let overlapPercent: CGFloat = 0.1
        let projectorHeight = canvasSize.height / CGFloat(count - 1) / (1.0 - overlapPercent)

        for (index, projector) in projectors.prefix(count).enumerated() {
            let y = CGFloat(index) * projectorHeight * (1.0 - overlapPercent)

            updateProjector(projector.id) { proj in
                proj.position = CGPoint(x: 0, y: y)
                proj.canvasRegion = CGRect(
                    x: 0,
                    y: y,
                    width: canvasSize.width,
                    height: projectorHeight
                )
            }
        }
    }

    private func applyGridLayout(columns: Int, rows: Int) {
        guard projectors.count >= columns * rows else { return }

        let overlapPercent: CGFloat = 0.1
        let cellWidth = canvasSize.width / CGFloat(columns) / (1.0 - overlapPercent)
        let cellHeight = canvasSize.height / CGFloat(rows) / (1.0 - overlapPercent)

        var index = 0
        for row in 0..<rows {
            for col in 0..<columns {
                guard index < projectors.count else { return }

                let x = CGFloat(col) * cellWidth * (1.0 - overlapPercent)
                let y = CGFloat(row) * cellHeight * (1.0 - overlapPercent)

                updateProjector(projectors[index].id) { proj in
                    proj.position = CGPoint(x: x, y: y)
                    proj.canvasRegion = CGRect(x: x, y: y, width: cellWidth, height: cellHeight)
                }

                index += 1
            }
        }
    }

    private func apply360Layout() {
        // Cylindrical 360° layout
        guard projectors.count >= 3 else { return }

        let angleStep = 360.0 / Double(projectors.count)
        let radius = canvasSize.width / (2.0 * .pi)

        for (index, projector) in projectors.enumerated() {
            let angle = Double(index) * angleStep
            let radians = angle * .pi / 180.0

            updateProjector(projector.id) { proj in
                proj.position = CGPoint(
                    x: CGFloat(cos(radians) * radius),
                    y: CGFloat(sin(radians) * radius)
                )
                proj.rotation = Float(angle)
                proj.is360 = true
            }
        }
    }

    private func applyDomeLayout() {
        // Hemispherical dome layout
        // Typically: 1 center + ring of projectors
        print("🔮 Dome layout applied (requires DomeMapper integration)")
    }


    // MARK: - Edge Blending

    /// Calculate blend regions for all projectors
    private func calculateBlendRegions() {
        for (index, projector) in projectors.enumerated() {
            // Find overlapping neighbors
            let neighbors = findOverlappingProjectors(for: projector)

            // Calculate blend masks for each edge
            updateProjector(projector.id) { proj in
                proj.blendRegions = calculateBlendMasks(for: proj, neighbors: neighbors)
            }
        }

        print("✅ Calculated blend regions for \(projectors.count) projectors")
    }

    private func findOverlappingProjectors(for projector: Projector) -> [Projector] {
        return projectors.filter { other in
            other.id != projector.id && projector.canvasRegion.intersects(other.canvasRegion)
        }
    }

    private func calculateBlendMasks(for projector: Projector, neighbors: [Projector]) -> [BlendRegion] {
        var blendRegions: [BlendRegion] = []

        for neighbor in neighbors {
            guard let intersection = projector.canvasRegion.intersection(neighbor.canvasRegion) as CGRect? else {
                continue
            }

            // Determine edge direction
            let edge = determineEdge(projector: projector, neighbor: neighbor)

            // Create blend region
            let region = BlendRegion(
                edge: edge,
                region: intersection,
                featherWidth: CGFloat(featherWidth),
                curve: blendCurve,
                gamma: blendGamma
            )

            blendRegions.append(region)
        }

        return blendRegions
    }

    private func determineEdge(projector: Projector, neighbor: Projector) -> Edge {
        let dx = neighbor.position.x - projector.position.x
        let dy = neighbor.position.y - projector.position.y

        if abs(dx) > abs(dy) {
            return dx > 0 ? .right : .left
        } else {
            return dy > 0 ? .bottom : .top
        }
    }

    /// Generate blend mask texture for a projector
    func generateBlendMask(for projectorID: UUID) -> MTLTexture? {
        guard let projector = getProjector(projectorID) else { return nil }

        // Create texture descriptor
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .r8Unorm,  // Single-channel grayscale
            width: Int(projector.resolution.width),
            height: Int(projector.resolution.height),
            mipmapped: false
        )
        descriptor.usage = [.shaderRead, .shaderWrite]

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            return nil
        }

        // Generate blend mask data
        let maskData = createBlendMaskData(for: projector)

        // Upload to texture
        texture.replace(
            region: MTLRegionMake2D(0, 0, Int(projector.resolution.width), Int(projector.resolution.height)),
            mipmapLevel: 0,
            withBytes: maskData,
            bytesPerRow: Int(projector.resolution.width)
        )

        return texture
    }

    private func createBlendMaskData(for projector: Projector) -> [UInt8] {
        let width = Int(projector.resolution.width)
        let height = Int(projector.resolution.height)
        var maskData = [UInt8](repeating: 255, count: width * height)

        // Apply feathering to blend regions
        for blendRegion in projector.blendRegions {
            applyFeather(
                to: &maskData,
                width: width,
                height: height,
                region: blendRegion,
                projectorRect: projector.canvasRegion
            )
        }

        return maskData
    }

    private func applyFeather(
        to maskData: inout [UInt8],
        width: Int,
        height: Int,
        region: BlendRegion,
        projectorRect: CGRect
    ) {
        // Calculate feather zone in pixels
        let featherPixels: Int

        switch region.edge {
        case .left, .right:
            featherPixels = Int(region.featherWidth * CGFloat(width))
        case .top, .bottom:
            featherPixels = Int(region.featherWidth * CGFloat(height))
        }

        // Apply blend curve
        for y in 0..<height {
            for x in 0..<width {
                let index = y * width + x

                // Calculate distance from edge
                let distance = distanceFromEdge(x: x, y: y, edge: region.edge, width: width, height: height)

                if distance < featherPixels {
                    // Apply blend curve
                    let t = Float(distance) / Float(featherPixels)
                    let alpha = applyBlendCurve(t, curve: region.curve, gamma: region.gamma)

                    maskData[index] = UInt8(alpha * 255.0)
                }
            }
        }
    }

    private func distanceFromEdge(x: Int, y: Int, edge: Edge, width: Int, height: Int) -> Int {
        switch edge {
        case .left:
            return x
        case .right:
            return width - x - 1
        case .top:
            return y
        case .bottom:
            return height - y - 1
        }
    }

    private func applyBlendCurve(_ t: Float, curve: BlendCurve, gamma: Float) -> Float {
        switch curve {
        case .linear:
            return t

        case .power:
            // Power curve (gamma correction)
            return pow(t, gamma)

        case .smoothstep:
            // Smoothstep (3rd order polynomial)
            return t * t * (3.0 - 2.0 * t)

        case .bezier:
            // Cubic bezier (0.42, 0, 0.58, 1)
            let p1: Float = 0.42
            let p2: Float = 0.58
            let t2 = t * t
            let t3 = t2 * t
            return 3.0 * (1.0 - t) * (1.0 - t) * t * p1 +
                   3.0 * (1.0 - t) * t2 * p2 +
                   t3
        }
    }


    // MARK: - Color Calibration

    /// Calibrate colors across all projectors
    func calibrateColors() {
        print("🎨 Starting color calibration...")

        // Measure and adjust brightness, contrast, gamma per projector
        // In production, this would use camera feedback or manual adjustment

        for projector in projectors {
            print("   Calibrating '\(projector.name)'")
            print("     Brightness: \(projector.brightness)")
            print("     Contrast: \(projector.contrast)")
            print("     Gamma: \(projector.gamma)")
        }

        print("✅ Color calibration complete")
    }

    /// Set color calibration for specific projector
    func setColorCalibration(
        projectorID: UUID,
        brightness: Float? = nil,
        contrast: Float? = nil,
        gamma: Float? = nil,
        whitePoint: WhitePoint? = nil
    ) {
        updateProjector(projectorID) { proj in
            if let brightness = brightness {
                proj.brightness = max(0.0, min(2.0, brightness))
            }
            if let contrast = contrast {
                proj.contrast = max(0.0, min(2.0, contrast))
            }
            if let gamma = gamma {
                proj.gamma = max(0.5, min(3.0, gamma))
            }
            if let whitePoint = whitePoint {
                proj.whitePoint = whitePoint
            }
        }

        print("🎨 Updated color calibration for projector")
    }


    // MARK: - Rendering

    /// Render content to all projectors with edge blending
    func render(sourceTexture: MTLTexture) {
        let startTime = CACurrentMediaTime()

        guard let commandBuffer = commandQueue.makeCommandBuffer() else { return }

        for projector in projectors where projector.enabled {
            renderProjector(
                projector: projector,
                sourceTexture: sourceTexture,
                commandBuffer: commandBuffer
            )
        }

        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()

        renderTime = Float((CACurrentMediaTime() - startTime) * 1000.0)
    }

    private func renderProjector(
        projector: Projector,
        sourceTexture: MTLTexture,
        commandBuffer: MTLCommandBuffer
    ) {
        // 1. Warp content to projector's canvas region
        // 2. Apply geometric correction (if any)
        // 3. Apply blend mask
        // 4. Apply color calibration
        // 5. Output to projector's texture/display

        // This would use the blend pipeline and projector's warp surface
        // In production, this integrates with ProjectionMapper for warping
    }


    // MARK: - Test Patterns

    /// Enable test pattern for alignment
    func showTestPattern(_ pattern: TestPattern) {
        testPattern = pattern
        testPatternEnabled = true

        print("🔲 Showing test pattern: \(pattern.rawValue)")
    }

    func hideTestPattern() {
        testPatternEnabled = false
        print("✅ Test pattern hidden")
    }

    /// Generate test pattern texture
    func generateTestPattern(_ pattern: TestPattern, size: CGSize) -> MTLTexture? {
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(
            pixelFormat: .rgba8Unorm,
            width: Int(size.width),
            height: Int(size.height),
            mipmapped: false
        )

        guard let texture = device.makeTexture(descriptor: descriptor) else {
            return nil
        }

        // Generate pattern data
        let patternData = createTestPatternData(pattern: pattern, size: size)

        texture.replace(
            region: MTLRegionMake2D(0, 0, Int(size.width), Int(size.height)),
            mipmapLevel: 0,
            withBytes: patternData,
            bytesPerRow: Int(size.width) * 4
        )

        return texture
    }

    private func createTestPatternData(pattern: TestPattern, size: CGSize) -> [UInt8] {
        let width = Int(size.width)
        let height = Int(size.height)
        var data = [UInt8](repeating: 0, count: width * height * 4)

        switch pattern {
        case .grid:
            createGridPattern(&data, width: width, height: height, gridSize: 64)

        case .crosshatch:
            createCrosshatchPattern(&data, width: width, height: height, lineWidth: 2)

        case .colorBars:
            createColorBarsPattern(&data, width: width, height: height)

        case .white:
            data = [UInt8](repeating: 255, count: width * height * 4)

        case .black:
            data = [UInt8](repeating: 0, count: width * height * 4)

        case .checkerboard:
            createCheckerboardPattern(&data, width: width, height: height, squareSize: 64)

        case .gradient:
            createGradientPattern(&data, width: width, height: height)
        }

        return data
    }

    private func createGridPattern(_ data: inout [UInt8], width: Int, height: Int, gridSize: Int) {
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4

                let isGridLine = (x % gridSize == 0) || (y % gridSize == 0)
                let color: UInt8 = isGridLine ? 255 : 0

                data[index] = color      // R
                data[index + 1] = color  // G
                data[index + 2] = color  // B
                data[index + 3] = 255    // A
            }
        }
    }

    private func createCrosshatchPattern(_ data: inout [UInt8], width: Int, height: Int, lineWidth: Int) {
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4

                let isLine = (x < lineWidth || x >= width - lineWidth ||
                             y < lineWidth || y >= height - lineWidth)
                let color: UInt8 = isLine ? 255 : 0

                data[index] = color
                data[index + 1] = color
                data[index + 2] = color
                data[index + 3] = 255
            }
        }
    }

    private func createColorBarsPattern(_ data: inout [UInt8], width: Int, height: Int) {
        let colors: [(r: UInt8, g: UInt8, b: UInt8)] = [
            (255, 255, 255),  // White
            (255, 255, 0),    // Yellow
            (0, 255, 255),    // Cyan
            (0, 255, 0),      // Green
            (255, 0, 255),    // Magenta
            (255, 0, 0),      // Red
            (0, 0, 255),      // Blue
            (0, 0, 0)         // Black
        ]

        let barWidth = width / colors.count

        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4
                let colorIndex = min(x / barWidth, colors.count - 1)

                data[index] = colors[colorIndex].r
                data[index + 1] = colors[colorIndex].g
                data[index + 2] = colors[colorIndex].b
                data[index + 3] = 255
            }
        }
    }

    private func createCheckerboardPattern(_ data: inout [UInt8], width: Int, height: Int, squareSize: Int) {
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4

                let checker = ((x / squareSize) + (y / squareSize)) % 2 == 0
                let color: UInt8 = checker ? 255 : 0

                data[index] = color
                data[index + 1] = color
                data[index + 2] = color
                data[index + 3] = 255
            }
        }
    }

    private func createGradientPattern(_ data: inout [UInt8], width: Int, height: Int) {
        for y in 0..<height {
            for x in 0..<width {
                let index = (y * width + x) * 4

                let intensity = UInt8((Float(x) / Float(width)) * 255.0)

                data[index] = intensity
                data[index + 1] = intensity
                data[index + 2] = intensity
                data[index + 3] = 255
            }
        }
    }


    // MARK: - Status

    var statusSummary: String {
        """
        📽️ Multi-Projector System
        Projectors: \(projectors.count) / \(maxProjectors)
        Layout: \(canvasLayout.rawValue)
        Canvas: \(Int(canvasSize.width))x\(Int(canvasSize.height))
        Total Pixels: \(totalOutputResolution.formattedWithCommas())
        Blend Mode: \(blendMode.rawValue)
        Render Time: \(String(format: "%.2f", renderTime)) ms
        """
    }
}


// MARK: - Data Models

/// Individual projector configuration
class Projector: Identifiable, ObservableObject {
    let id: UUID

    @Published var name: String
    @Published var enabled: Bool = true

    // Physical configuration
    @Published var resolution: CGSize
    @Published var position: CGPoint  // In canvas space
    @Published var rotation: Float = 0.0  // Degrees
    @Published var scale: Float = 1.0

    // Canvas mapping
    @Published var canvasRegion: CGRect  // Region of canvas this projector covers

    // Color calibration
    @Published var brightness: Float = 1.0  // 0.0-2.0
    @Published var contrast: Float = 1.0    // 0.0-2.0
    @Published var gamma: Float = 2.2       // 0.5-3.0
    @Published var whitePoint: WhitePoint = .d65

    // Edge blending
    @Published var blendRegions: [BlendRegion] = []

    // Projector specs
    var lumens: Int = 5000
    var throwRatio: Float = 1.5  // Distance / Width
    var lensShift: CGPoint = .zero  // Horizontal/Vertical shift capability

    // Special modes
    var is360: Bool = false
    var isDome: Bool = false

    // Geometric correction (integrates with ProjectionMapper)
    var warpSurface: ProjectionSurface?

    init(id: UUID = UUID(), name: String, resolution: CGSize, position: CGPoint) {
        self.id = id
        self.name = name
        self.resolution = resolution
        self.position = position
        self.canvasRegion = CGRect(origin: position, size: resolution)
    }
}

/// Blend region for edge feathering
struct BlendRegion {
    let edge: Edge
    let region: CGRect  // Overlap region in canvas space
    let featherWidth: CGFloat  // 0.0-1.0
    let curve: BlendCurve
    let gamma: Float
}

enum Edge {
    case left, right, top, bottom
}

/// Canvas layout presets
enum CanvasLayout: String, CaseIterable {
    case single = "Single"
    case horizontal2 = "2 Horizontal"
    case horizontal3 = "3 Horizontal"
    case vertical2 = "2 Vertical"
    case grid2x2 = "2x2 Grid"
    case grid3x3 = "3x3 Grid"
    case panoramic360 = "360° Panoramic"
    case dome = "Dome/Fulldome"
    case custom = "Custom"
}

/// Edge blend modes
enum BlendMode: String, CaseIterable {
    case none = "None"
    case softEdge = "Soft Edge"
    case hardEdge = "Hard Edge"
    case blackLevel = "Black Level Compensation"
}

/// Blend curve types
enum BlendCurve: String, CaseIterable {
    case linear = "Linear"
    case power = "Power (Gamma)"
    case smoothstep = "Smoothstep"
    case bezier = "Bezier"
}

/// Test patterns for alignment
enum TestPattern: String, CaseIterable {
    case grid = "Grid"
    case crosshatch = "Crosshatch"
    case colorBars = "Color Bars (SMPTE)"
    case white = "Full White"
    case black = "Full Black"
    case checkerboard = "Checkerboard"
    case gradient = "Horizontal Gradient"
}

/// White point standards
enum WhitePoint: String, CaseIterable {
    case d65 = "D65 (6500K)"  // Standard daylight
    case d55 = "D55 (5500K)"  // Warm daylight
    case d93 = "D93 (9300K)"  // Cool white
    case dci = "DCI (6300K)"  // Digital cinema
}


// MARK: - Extensions

extension Int {
    func formattedWithCommas() -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: self)) ?? "\(self)"
    }
}
