import Foundation
import simd
import Accelerate

// MARK: - Spatial 3D Canvas
// 3D dimensional painting and drawing in space
// Like FlockDraw but in full 3D with audio-reactive and biofeedback integration

/// Spatial3DCanvas: Immersive 3D drawing and painting system
/// Enables creation of volumetric art in spatial environments
///
/// Features:
/// - Freehand 3D brush strokes
/// - Volumetric sculpting
/// - Audio-reactive painting
/// - Biofeedback color/size modulation
/// - Collaborative multi-user support
/// - Export to 3D formats (OBJ, GLTF, USD)
public final class Spatial3DCanvas {

    // MARK: - Types

    /// 3D brush stroke
    public struct Stroke: Identifiable {
        public let id: UUID
        public var points: [StrokePoint]
        public var brush: BrushSettings
        public var createdAt: Date
        public var authorId: String
        public var layer: Int
        public var isVisible: Bool
        public var isLocked: Bool

        public init(brush: BrushSettings, authorId: String = "local", layer: Int = 0) {
            self.id = UUID()
            self.points = []
            self.brush = brush
            self.createdAt = Date()
            self.authorId = authorId
            self.layer = layer
            self.isVisible = true
            self.isLocked = false
        }
    }

    /// Point in a 3D stroke
    public struct StrokePoint {
        public var position: SIMD3<Float>
        public var normal: SIMD3<Float>
        public var tangent: SIMD3<Float>
        public var pressure: Float
        public var tilt: SIMD2<Float>
        public var rotation: Float
        public var timestamp: TimeInterval
        public var color: SIMD4<Float>
        public var size: Float

        public init(
            position: SIMD3<Float>,
            pressure: Float = 1.0,
            color: SIMD4<Float> = SIMD4(1, 1, 1, 1),
            size: Float = 0.01
        ) {
            self.position = position
            self.normal = SIMD3(0, 1, 0)
            self.tangent = SIMD3(1, 0, 0)
            self.pressure = pressure
            self.tilt = .zero
            self.rotation = 0
            self.timestamp = Date().timeIntervalSince1970
            self.color = color
            self.size = size
        }
    }

    /// Brush settings
    public struct BrushSettings {
        public var type: BrushType
        public var size: Float                    // Base size in meters
        public var sizeVariation: Float           // Random variation (0-1)
        public var sizePressureCurve: Float       // How pressure affects size

        public var color: SIMD4<Float>            // RGBA
        public var colorVariation: Float          // Random hue variation
        public var colorPressureCurve: Float      // How pressure affects opacity

        public var hardness: Float                // Edge falloff (0=soft, 1=hard)
        public var opacity: Float                 // Base opacity
        public var flow: Float                    // Paint flow rate

        public var spacing: Float                 // Distance between dabs (ratio of size)
        public var smoothing: Float               // Input smoothing (0-1)
        public var stabilizer: Int                // Stabilizer strength (0 = off)

        public var jitter: Float                  // Position randomness
        public var scatter: Float                 // Perpendicular scatter

        public var textureId: String?             // Brush texture
        public var isEmissive: Bool               // Glowing brush
        public var emissionIntensity: Float

        // 3D specific
        public var tubeMode: Bool                 // Render as 3D tubes
        public var ribbonMode: Bool               // Render as ribbons
        public var particleMode: Bool             // Spawn particles
        public var volumetric: Bool               // Create volumetric data

        public init(type: BrushType = .round) {
            self.type = type
            self.size = 0.01
            self.sizeVariation = 0
            self.sizePressureCurve = 0.5
            self.color = SIMD4(1, 1, 1, 1)
            self.colorVariation = 0
            self.colorPressureCurve = 0.3
            self.hardness = 0.8
            self.opacity = 1.0
            self.flow = 1.0
            self.spacing = 0.25
            self.smoothing = 0.5
            self.stabilizer = 0
            self.jitter = 0
            self.scatter = 0
            self.textureId = nil
            self.isEmissive = false
            self.emissionIntensity = 1
            self.tubeMode = true
            self.ribbonMode = false
            self.particleMode = false
            self.volumetric = false
        }
    }

    /// Brush types
    public enum BrushType: String, CaseIterable {
        case round = "Round"
        case flat = "Flat"
        case marker = "Marker"
        case pencil = "Pencil"
        case airbrush = "Airbrush"
        case ink = "Ink"
        case watercolor = "Watercolor"
        case oil = "Oil Paint"
        case charcoal = "Charcoal"
        case eraser = "Eraser"

        // 3D specific
        case ribbon = "Ribbon"
        case tube = "Tube"
        case particle = "Particle"
        case light = "Light Trail"
        case neon = "Neon"
        case smoke = "Smoke"
        case fire = "Fire"
        case electricity = "Electricity"
        case rainbow = "Rainbow"
        case stars = "Stars"

        // Sculpting
        case sculpt = "Sculpt"
        case carve = "Carve"
        case smooth = "Smooth"
        case pinch = "Pinch"
        case inflate = "Inflate"
    }

    /// Canvas layer
    public struct Layer: Identifiable {
        public let id: UUID
        public var name: String
        public var isVisible: Bool
        public var isLocked: Bool
        public var opacity: Float
        public var blendMode: BlendMode
        public var strokes: [UUID]  // Stroke IDs in this layer

        public init(name: String) {
            self.id = UUID()
            self.name = name
            self.isVisible = true
            self.isLocked = false
            self.opacity = 1.0
            self.blendMode = .normal
            self.strokes = []
        }
    }

    /// Blend modes
    public enum BlendMode: String, CaseIterable {
        case normal = "Normal"
        case multiply = "Multiply"
        case screen = "Screen"
        case overlay = "Overlay"
        case add = "Add"
        case subtract = "Subtract"
    }

    // MARK: - Audio-Reactive Settings

    /// Audio influence on brush
    public struct AudioReactiveSettings {
        public var enabled: Bool = false

        // Frequency bands influence
        public var bassToSize: Float = 0          // Low freq → brush size
        public var midToHue: Float = 0            // Mid freq → color hue
        public var highToBrightness: Float = 0    // High freq → brightness

        // Overall audio
        public var amplitudeToOpacity: Float = 0
        public var amplitudeToEmission: Float = 0
        public var beatToSpawn: Bool = false      // Spawn on beat

        // Spectral
        public var spectralToColor: Bool = false  // Full spectrum → rainbow

        public init() {}
    }

    /// Biofeedback influence on brush
    public struct BiofeedbackSettings {
        public var enabled: Bool = false

        // Heart
        public var heartRateToSpeed: Float = 0    // HR → stroke speed
        public var hrvToSmoothness: Float = 0     // HRV → line smoothness
        public var heartbeatPulse: Bool = false   // Pulse brush on heartbeat

        // Emotion
        public var valenceToHue: Float = 0        // Positive = warm, negative = cool
        public var arousalToSize: Float = 0       // High arousal = bigger
        public var emotionToColor: Bool = false   // Full emotion mapping

        // Focus
        public var focusToOpacity: Float = 0      // More focus = more opaque
        public var relaxationToBlur: Float = 0    // Relaxed = softer edges

        public init() {}
    }

    // MARK: - Properties

    /// All strokes on canvas
    private var strokes: [UUID: Stroke] = [:]

    /// Stroke order for rendering
    private var strokeOrder: [UUID] = []

    /// Current active stroke (being drawn)
    private var activeStroke: Stroke?

    /// Layers
    public private(set) var layers: [Layer] = []

    /// Active layer index
    public var activeLayerIndex: Int = 0

    /// Current brush settings
    public var brush = BrushSettings()

    /// Audio-reactive settings
    public var audioReactive = AudioReactiveSettings()

    /// Biofeedback settings
    public var biofeedback = BiofeedbackSettings()

    /// Canvas bounds (in meters)
    public var bounds: (min: SIMD3<Float>, max: SIMD3<Float>) = (
        SIMD3(-10, -10, -10),
        SIMD3(10, 10, 10)
    )

    /// Grid settings
    public var gridEnabled: Bool = true
    public var gridSize: Float = 0.1  // meters
    public var snapToGrid: Bool = false

    /// Symmetry settings
    public var symmetryEnabled: Bool = false
    public var symmetryAxes: SIMD3<Bool> = SIMD3(false, false, false)  // X, Y, Z mirror
    public var radialSymmetry: Int = 1  // Number of radial copies

    /// Undo/redo stacks
    private var undoStack: [CanvasAction] = []
    private var redoStack: [CanvasAction] = []
    private let maxUndoLevels = 100

    /// Collaborative session
    public var collaborativeSession: CollaborativeSession?

    /// Input smoothing buffer
    private var smoothingBuffer: [SIMD3<Float>] = []

    // Audio/biofeedback state (updated externally)
    public var audioState: AudioState = AudioState()
    public var biofeedbackState: BiofeedbackState = BiofeedbackState()

    // MARK: - Initialization

    public init() {
        // Create default layer
        layers.append(Layer(name: "Layer 1"))
    }

    // MARK: - Drawing

    /// Begin a new stroke
    public func beginStroke(at position: SIMD3<Float>, pressure: Float = 1.0) {
        guard !layers.isEmpty else { return }

        var newStroke = Stroke(brush: brush, layer: activeLayerIndex)

        // Apply audio/biofeedback modulation
        let modulatedSettings = modulateBrush(brush, at: position)
        newStroke.brush = modulatedSettings

        // Add first point
        let color = modulatedSettings.color
        let size = modulatedSettings.size * (0.5 + pressure * modulatedSettings.sizePressureCurve)

        let point = StrokePoint(
            position: snapToGrid ? snapPosition(position) : position,
            pressure: pressure,
            color: color,
            size: size
        )
        newStroke.points.append(point)

        activeStroke = newStroke
        smoothingBuffer = [position]

        // Handle symmetry
        if symmetryEnabled {
            // Mirror strokes would be created as separate strokes
        }
    }

    /// Continue current stroke
    public func continueStroke(to position: SIMD3<Float>, pressure: Float = 1.0, tilt: SIMD2<Float> = .zero) {
        guard var stroke = activeStroke else { return }

        // Input smoothing
        smoothingBuffer.append(position)
        if smoothingBuffer.count > Int(brush.smoothing * 10) + 1 {
            smoothingBuffer.removeFirst()
        }

        let smoothedPosition = smoothingBuffer.reduce(.zero, +) / Float(smoothingBuffer.count)
        let finalPosition = snapToGrid ? snapPosition(smoothedPosition) : smoothedPosition

        // Check spacing
        if let lastPoint = stroke.points.last {
            let distance = simd_length(finalPosition - lastPoint.position)
            let minSpacing = brush.size * brush.spacing
            guard distance >= minSpacing else { return }
        }

        // Modulate brush based on current audio/bio state
        let modulatedBrush = modulateBrush(brush, at: finalPosition)

        // Calculate tangent and normal
        var tangent = SIMD3<Float>(1, 0, 0)
        var normal = SIMD3<Float>(0, 1, 0)

        if let lastPoint = stroke.points.last {
            let direction = finalPosition - lastPoint.position
            if simd_length(direction) > 0.0001 {
                tangent = simd_normalize(direction)

                // Calculate normal perpendicular to tangent and up
                let up = SIMD3<Float>(0, 1, 0)
                normal = simd_normalize(simd_cross(tangent, up))
                if simd_length(normal) < 0.0001 {
                    normal = SIMD3(1, 0, 0)
                }
            }
        }

        // Apply jitter
        var jitteredPosition = finalPosition
        if brush.jitter > 0 {
            let jitterAmount = brush.size * brush.jitter
            jitteredPosition += SIMD3(
                Float.random(in: -jitterAmount...jitterAmount),
                Float.random(in: -jitterAmount...jitterAmount),
                Float.random(in: -jitterAmount...jitterAmount)
            )
        }

        // Create point
        var point = StrokePoint(
            position: jitteredPosition,
            pressure: pressure,
            color: modulatedBrush.color,
            size: modulatedBrush.size * (0.5 + pressure * modulatedBrush.sizePressureCurve)
        )
        point.tangent = tangent
        point.normal = normal
        point.tilt = tilt

        stroke.points.append(point)
        activeStroke = stroke
    }

    /// End current stroke
    public func endStroke() {
        guard let stroke = activeStroke, !stroke.points.isEmpty else {
            activeStroke = nil
            return
        }

        // Store stroke
        strokes[stroke.id] = stroke
        strokeOrder.append(stroke.id)

        // Add to layer
        if activeLayerIndex < layers.count {
            layers[activeLayerIndex].strokes.append(stroke.id)
        }

        // Add to undo stack
        undoStack.append(.addStroke(stroke.id))
        if undoStack.count > maxUndoLevels {
            undoStack.removeFirst()
        }
        redoStack.removeAll()

        // Broadcast to collaborative session
        collaborativeSession?.broadcastStroke(stroke)

        activeStroke = nil
        smoothingBuffer.removeAll()
    }

    // MARK: - Brush Modulation

    /// Modulate brush settings based on audio and biofeedback
    private func modulateBrush(_ brush: BrushSettings, at position: SIMD3<Float>) -> BrushSettings {
        var modulated = brush

        // Audio modulation
        if audioReactive.enabled {
            // Bass → size
            if audioReactive.bassToSize > 0 {
                modulated.size *= 1 + audioState.bass * audioReactive.bassToSize
            }

            // Mid → hue shift
            if audioReactive.midToHue > 0 {
                var hsv = rgbToHsv(modulated.color)
                hsv.x = fmod(hsv.x + audioState.mid * audioReactive.midToHue, 1.0)
                modulated.color = hsvToRgb(hsv)
            }

            // High → brightness
            if audioReactive.highToBrightness > 0 {
                var hsv = rgbToHsv(modulated.color)
                hsv.z = min(1, hsv.z + audioState.high * audioReactive.highToBrightness)
                modulated.color = hsvToRgb(hsv)
            }

            // Amplitude → opacity
            if audioReactive.amplitudeToOpacity > 0 {
                modulated.color.w *= 0.5 + audioState.amplitude * audioReactive.amplitudeToOpacity * 0.5
            }

            // Amplitude → emission
            if audioReactive.amplitudeToEmission > 0 && brush.isEmissive {
                modulated.emissionIntensity = 1 + audioState.amplitude * audioReactive.amplitudeToEmission * 3
            }
        }

        // Biofeedback modulation
        if biofeedback.enabled {
            // Valence → hue (positive = warm, negative = cool)
            if biofeedback.valenceToHue > 0 {
                var hsv = rgbToHsv(modulated.color)
                // Warm colors around 0-0.15 (red-yellow), cool around 0.5-0.7 (cyan-blue)
                let warmHue: Float = 0.08  // Orange
                let coolHue: Float = 0.6   // Blue
                let targetHue = biofeedbackState.valence > 0 ? warmHue : coolHue
                hsv.x = simd_mix(hsv.x, targetHue, abs(biofeedbackState.valence) * biofeedback.valenceToHue)
                modulated.color = hsvToRgb(hsv)
            }

            // Arousal → size
            if biofeedback.arousalToSize > 0 {
                modulated.size *= 1 + biofeedbackState.arousal * biofeedback.arousalToSize
            }

            // Focus → opacity
            if biofeedback.focusToOpacity > 0 {
                modulated.color.w *= 0.5 + biofeedbackState.focus * biofeedback.focusToOpacity * 0.5
            }

            // Relaxation → hardness (softer when relaxed)
            if biofeedback.relaxationToBlur > 0 {
                modulated.hardness *= 1 - biofeedbackState.relaxation * biofeedback.relaxationToBlur
            }

            // HRV → smoothness (more smoothing with higher HRV)
            if biofeedback.hrvToSmoothness > 0 {
                modulated.smoothing = min(1, modulated.smoothing + biofeedbackState.hrv * biofeedback.hrvToSmoothness)
            }
        }

        return modulated
    }

    // MARK: - Grid & Snapping

    /// Snap position to grid
    private func snapPosition(_ position: SIMD3<Float>) -> SIMD3<Float> {
        return SIMD3(
            round(position.x / gridSize) * gridSize,
            round(position.y / gridSize) * gridSize,
            round(position.z / gridSize) * gridSize
        )
    }

    // MARK: - Layer Management

    /// Add new layer
    public func addLayer(name: String? = nil) -> Layer {
        let layerName = name ?? "Layer \(layers.count + 1)"
        let layer = Layer(name: layerName)
        layers.append(layer)
        activeLayerIndex = layers.count - 1
        return layer
    }

    /// Delete layer
    public func deleteLayer(at index: Int) {
        guard index < layers.count, layers.count > 1 else { return }

        let layer = layers[index]

        // Remove strokes in this layer
        for strokeId in layer.strokes {
            strokes.removeValue(forKey: strokeId)
            strokeOrder.removeAll { $0 == strokeId }
        }

        layers.remove(at: index)

        if activeLayerIndex >= layers.count {
            activeLayerIndex = layers.count - 1
        }
    }

    /// Merge layers
    public func mergeLayers(_ indices: [Int]) {
        guard indices.count >= 2 else { return }

        let sortedIndices = indices.sorted()
        let targetIndex = sortedIndices[0]
        var targetLayer = layers[targetIndex]

        for index in sortedIndices.dropFirst().reversed() {
            let layer = layers[index]
            targetLayer.strokes.append(contentsOf: layer.strokes)
            layers.remove(at: index)
        }

        layers[targetIndex] = targetLayer

        if activeLayerIndex >= layers.count {
            activeLayerIndex = layers.count - 1
        }
    }

    // MARK: - Undo/Redo

    /// Canvas actions for undo/redo
    private enum CanvasAction {
        case addStroke(UUID)
        case removeStroke(UUID, Stroke)
        case modifyStroke(UUID, Stroke)  // Old state
    }

    /// Undo last action
    public func undo() {
        guard let action = undoStack.popLast() else { return }

        switch action {
        case .addStroke(let id):
            if let stroke = strokes.removeValue(forKey: id) {
                strokeOrder.removeAll { $0 == id }
                if activeLayerIndex < layers.count {
                    layers[activeLayerIndex].strokes.removeAll { $0 == id }
                }
                redoStack.append(.removeStroke(id, stroke))
            }

        case .removeStroke(let id, let stroke):
            strokes[id] = stroke
            strokeOrder.append(id)
            if stroke.layer < layers.count {
                layers[stroke.layer].strokes.append(id)
            }
            redoStack.append(.addStroke(id))

        case .modifyStroke(let id, let oldStroke):
            if let currentStroke = strokes[id] {
                strokes[id] = oldStroke
                redoStack.append(.modifyStroke(id, currentStroke))
            }
        }
    }

    /// Redo last undone action
    public func redo() {
        guard let action = redoStack.popLast() else { return }

        switch action {
        case .addStroke(let id):
            // Re-add requires stored stroke data - simplified
            break

        case .removeStroke(let id, let stroke):
            strokes[id] = stroke
            strokeOrder.append(id)
            if stroke.layer < layers.count {
                layers[stroke.layer].strokes.append(id)
            }
            undoStack.append(.addStroke(id))

        case .modifyStroke(let id, let stroke):
            if let currentStroke = strokes[id] {
                strokes[id] = stroke
                undoStack.append(.modifyStroke(id, currentStroke))
            }
        }
    }

    // MARK: - Clear

    /// Clear all strokes
    public func clearAll() {
        // Store for undo
        for (id, stroke) in strokes {
            undoStack.append(.removeStroke(id, stroke))
        }

        strokes.removeAll()
        strokeOrder.removeAll()

        for i in 0..<layers.count {
            layers[i].strokes.removeAll()
        }

        redoStack.removeAll()
    }

    /// Clear active layer
    public func clearActiveLayer() {
        guard activeLayerIndex < layers.count else { return }

        let layer = layers[activeLayerIndex]

        for strokeId in layer.strokes {
            if let stroke = strokes.removeValue(forKey: strokeId) {
                strokeOrder.removeAll { $0 == strokeId }
                undoStack.append(.removeStroke(strokeId, stroke))
            }
        }

        layers[activeLayerIndex].strokes.removeAll()
    }

    // MARK: - Query

    /// Get all strokes
    public func getAllStrokes() -> [Stroke] {
        return strokeOrder.compactMap { strokes[$0] }
    }

    /// Get visible strokes (respecting layer visibility)
    public func getVisibleStrokes() -> [Stroke] {
        return strokeOrder.compactMap { id -> Stroke? in
            guard let stroke = strokes[id] else { return nil }
            guard stroke.isVisible else { return nil }
            guard stroke.layer < layers.count else { return nil }
            guard layers[stroke.layer].isVisible else { return nil }
            return stroke
        }
    }

    /// Get active stroke (being drawn)
    public func getActiveStroke() -> Stroke? {
        return activeStroke
    }

    /// Get stroke count
    public var strokeCount: Int {
        return strokes.count
    }

    /// Get total point count
    public var totalPointCount: Int {
        return strokes.values.reduce(0) { $0 + $1.points.count }
    }

    // MARK: - Audio/Biofeedback State

    /// Audio analysis state (updated by audio system)
    public struct AudioState {
        public var amplitude: Float = 0       // 0-1
        public var bass: Float = 0            // 0-1 (low frequencies)
        public var mid: Float = 0             // 0-1 (mid frequencies)
        public var high: Float = 0            // 0-1 (high frequencies)
        public var isBeat: Bool = false       // Beat detected this frame
        public var tempo: Float = 120         // BPM
        public var spectrum: [Float] = []     // FFT bins

        public init() {}
    }

    /// Biofeedback state (updated by bio system)
    public struct BiofeedbackState {
        public var heartRate: Float = 70
        public var hrv: Float = 0.5           // Normalized 0-1
        public var valence: Float = 0         // -1 to 1
        public var arousal: Float = 0         // -1 to 1
        public var focus: Float = 0.5         // 0-1
        public var relaxation: Float = 0.5    // 0-1
        public var isHeartbeat: Bool = false  // Heartbeat this frame

        public init() {}
    }

    // MARK: - Collaboration

    /// Collaborative drawing session
    public class CollaborativeSession {
        public var sessionId: String
        public var participants: [Participant] = []
        public var isHost: Bool
        public weak var canvas: Spatial3DCanvas?

        public struct Participant: Identifiable {
            public let id: String
            public var name: String
            public var color: SIMD4<Float>
            public var cursorPosition: SIMD3<Float>?
            public var isDrawing: Bool
        }

        public init(sessionId: String, isHost: Bool) {
            self.sessionId = sessionId
            self.isHost = isHost
        }

        /// Broadcast stroke to other participants
        public func broadcastStroke(_ stroke: Stroke) {
            // Network implementation would go here
        }

        /// Receive stroke from other participant
        public func receiveStroke(_ stroke: Stroke) {
            canvas?.receiveRemoteStroke(stroke)
        }

        /// Update cursor position
        public func updateCursor(position: SIMD3<Float>) {
            // Broadcast cursor to others
        }
    }

    /// Receive stroke from remote participant
    func receiveRemoteStroke(_ stroke: Stroke) {
        strokes[stroke.id] = stroke
        strokeOrder.append(stroke.id)

        // Add to appropriate layer or create new one
        if stroke.layer < layers.count {
            layers[stroke.layer].strokes.append(stroke.id)
        }
    }

    // MARK: - Export

    /// Export formats
    public enum ExportFormat: String, CaseIterable {
        case obj = "OBJ"
        case gltf = "GLTF"
        case usd = "USD"
        case fbx = "FBX"
        case svg3d = "SVG (projected)"
        case pointCloud = "Point Cloud (PLY)"
    }

    /// Export canvas to format
    public func export(format: ExportFormat) -> Data? {
        switch format {
        case .obj:
            return exportOBJ()
        case .pointCloud:
            return exportPointCloud()
        default:
            // Other formats would need full implementations
            return nil
        }
    }

    /// Export to OBJ format (simplified tube mesh)
    private func exportOBJ() -> Data? {
        var obj = "# Spatial3DCanvas Export\n"
        var vertexIndex = 1

        for stroke in getVisibleStrokes() {
            guard stroke.points.count >= 2 else { continue }

            obj += "# Stroke \(stroke.id)\n"

            // Generate tube vertices
            let segments = 8
            for (i, point) in stroke.points.enumerated() {
                let radius = point.size / 2

                for seg in 0..<segments {
                    let angle = Float(seg) / Float(segments) * 2 * .pi
                    let offset = point.normal * cos(angle) * radius +
                                simd_cross(point.tangent, point.normal) * sin(angle) * radius
                    let vertex = point.position + offset

                    obj += "v \(vertex.x) \(vertex.y) \(vertex.z)\n"
                }

                // Generate faces (connect to previous ring)
                if i > 0 {
                    let prevBase = vertexIndex - segments
                    let currBase = vertexIndex

                    for seg in 0..<segments {
                        let next = (seg + 1) % segments

                        let v1 = prevBase + seg
                        let v2 = prevBase + next
                        let v3 = currBase + next
                        let v4 = currBase + seg

                        obj += "f \(v1) \(v2) \(v3) \(v4)\n"
                    }
                }

                vertexIndex += segments
            }
        }

        return obj.data(using: .utf8)
    }

    /// Export as point cloud (PLY format)
    private func exportPointCloud() -> Data? {
        var points: [(SIMD3<Float>, SIMD4<Float>)] = []

        for stroke in getVisibleStrokes() {
            for point in stroke.points {
                points.append((point.position, point.color))
            }
        }

        var ply = "ply\nformat ascii 1.0\n"
        ply += "element vertex \(points.count)\n"
        ply += "property float x\nproperty float y\nproperty float z\n"
        ply += "property uchar red\nproperty uchar green\nproperty uchar blue\n"
        ply += "end_header\n"

        for (pos, color) in points {
            let r = UInt8(color.x * 255)
            let g = UInt8(color.y * 255)
            let b = UInt8(color.z * 255)
            ply += "\(pos.x) \(pos.y) \(pos.z) \(r) \(g) \(b)\n"
        }

        return ply.data(using: .utf8)
    }

    // MARK: - Color Utilities

    /// RGB to HSV conversion
    private func rgbToHsv(_ rgba: SIMD4<Float>) -> SIMD3<Float> {
        let r = rgba.x, g = rgba.y, b = rgba.z
        let maxC = max(r, g, b)
        let minC = min(r, g, b)
        let delta = maxC - minC

        var h: Float = 0
        let s: Float = maxC == 0 ? 0 : delta / maxC
        let v: Float = maxC

        if delta > 0 {
            if maxC == r {
                h = fmod((g - b) / delta, 6) / 6
            } else if maxC == g {
                h = ((b - r) / delta + 2) / 6
            } else {
                h = ((r - g) / delta + 4) / 6
            }
        }

        if h < 0 { h += 1 }

        return SIMD3(h, s, v)
    }

    /// HSV to RGB conversion
    private func hsvToRgb(_ hsv: SIMD3<Float>) -> SIMD4<Float> {
        let h = hsv.x, s = hsv.y, v = hsv.z

        let c = v * s
        let x = c * (1 - abs(fmod(h * 6, 2) - 1))
        let m = v - c

        var r: Float = 0, g: Float = 0, b: Float = 0

        let hue6 = h * 6
        if hue6 < 1 {
            r = c; g = x; b = 0
        } else if hue6 < 2 {
            r = x; g = c; b = 0
        } else if hue6 < 3 {
            r = 0; g = c; b = x
        } else if hue6 < 4 {
            r = 0; g = x; b = c
        } else if hue6 < 5 {
            r = x; g = 0; b = c
        } else {
            r = c; g = 0; b = x
        }

        return SIMD4(r + m, g + m, b + m, 1)
    }
}

// MARK: - Brush Presets

extension Spatial3DCanvas {

    /// Brush preset categories
    public enum BrushPresetCategory: String, CaseIterable {
        case basic = "Basic"
        case artistic = "Artistic"
        case effects = "Effects"
        case sculpting = "Sculpting"
    }

    /// Get brush preset
    public static func brushPreset(_ name: String) -> BrushSettings {
        var brush = BrushSettings()

        switch name.lowercased() {
        case "neon":
            brush.type = .neon
            brush.isEmissive = true
            brush.emissionIntensity = 2
            brush.color = SIMD4(0, 1, 1, 1)
            brush.tubeMode = true

        case "smoke":
            brush.type = .smoke
            brush.opacity = 0.3
            brush.hardness = 0.1
            brush.sizeVariation = 0.5
            brush.particleMode = true

        case "fire":
            brush.type = .fire
            brush.isEmissive = true
            brush.color = SIMD4(1, 0.5, 0, 1)
            brush.particleMode = true

        case "ribbon":
            brush.type = .ribbon
            brush.ribbonMode = true
            brush.tubeMode = false

        case "stars":
            brush.type = .stars
            brush.particleMode = true
            brush.isEmissive = true
            brush.spacing = 0.5

        case "rainbow":
            brush.type = .rainbow
            brush.colorVariation = 1.0

        default:
            break
        }

        return brush
    }
}
