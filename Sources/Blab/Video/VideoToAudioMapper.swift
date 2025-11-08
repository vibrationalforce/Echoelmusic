import Foundation
import CoreImage
import AVFoundation
import Vision
import Accelerate

/// Video to Audio Mapper
///
/// Maps visual information to audio parameters:
/// - Brightness → Filter Cutoff
/// - Color → Pitch
/// - Motion → Rhythm
/// - Optical Flow → Spatial Position
/// - Face Detection → Expression Synthesis
@MainActor
class VideoToAudioMapper: NSObject, ObservableObject {

    // MARK: - Published State

    /// Whether mapping is active
    @Published var isActive: Bool = false

    /// Current mapped parameters
    @Published var audioParameters: MappedAudioParameters = MappedAudioParameters()

    // MARK: - Configuration

    struct MappingConfiguration {
        var brightnessToFilter: Bool = true
        var colorToPitch: Bool = true
        var motionToRhythm: Bool = true
        var opticalFlowToSpatial: Bool = true
        var faceDetection: Bool = true
    }

    var configuration = MappingConfiguration()

    // MARK: - Vision Processing

    private var faceDetectionRequest: VNDetectFaceRectanglesRequest?
    private var opticalFlowRequest: VNGenerateOpticalFlowRequest?

    // MARK: - Previous Frame

    private var previousFrame: CIImage?
    private var previousBrightness: Float = 0.5

    // MARK: - CoreImage Context

    private let ciContext = CIContext()

    // MARK: - Public API

    /// Start video → audio mapping
    func start() {
        guard !isActive else { return }

        setupVisionRequests()
        isActive = true

        print("🎬→🎵 Video-to-Audio mapping started")
    }

    /// Stop mapping
    func stop() {
        isActive = false
        print("🎬→🎵 Video-to-Audio mapping stopped")
    }

    /// Process video frame and map to audio parameters
    func processFrame(_ image: CIImage) -> MappedAudioParameters {
        guard isActive else { return audioParameters }

        var params = MappedAudioParameters()

        // 1. Brightness → Filter Cutoff
        if configuration.brightnessToFilter {
            let brightness = analyzeBrightness(image)
            params.filterCutoff = mapBrightnessToFrequency(brightness)
        }

        // 2. Color → Pitch
        if configuration.colorToPitch {
            let dominantColor = analyzeDominantColor(image)
            params.pitch = mapColorToPitch(dominantColor)
        }

        // 3. Motion → Rhythm
        if configuration.motionToRhythm {
            if let motion = analyzeMotion(current: image, previous: previousFrame) {
                params.tempo = mapMotionToTempo(motion)
                params.rhythmIntensity = motion
            }
        }

        // 4. Optical Flow → Spatial Position
        if configuration.opticalFlowToSpatial {
            if let flow = analyzeOpticalFlow(current: image, previous: previousFrame) {
                params.spatialPosition = flow
            }
        }

        // 5. Face Detection → Expression
        if configuration.faceDetection {
            if let faces = detectFaces(in: image), !faces.isEmpty {
                params.faceDetected = true
                params.faceCount = faces.count
                params.facePosition = faces.first?.boundingBox.origin ?? .zero
            }
        }

        previousFrame = image
        audioParameters = params

        return params
    }

    // MARK: - Analysis Methods

    private func analyzeBrightness(_ image: CIImage) -> Float {
        // Use histogram to calculate average brightness
        guard let histogram = CIFilter(name: "CIAreaHistogram") else {
            return 0.5
        }

        histogram.setValue(image, forKey: kCIInputImageKey)
        histogram.setValue(1, forKey: "inputCount")
        histogram.setValue(CIVector(cgRect: image.extent), forKey: "inputExtent")

        guard let outputImage = histogram.outputImage else {
            return 0.5
        }

        // Read histogram data
        var bitmap = [UInt8](repeating: 0, count: 4)
        ciContext.render(outputImage, toBitmap: &bitmap, rowBytes: 4, bounds: CGRect(x: 0, y: 0, width: 1, height: 1), format: .RGBA8, colorSpace: nil)

        let brightness = Float(bitmap[0]) / 255.0
        return brightness
    }

    private func analyzeDominantColor(_ image: CIImage) -> UIColor {
        // Sample center pixel for dominant color
        let extent = image.extent
        let center = CGPoint(x: extent.midX, y: extent.midY)
        let sampleRect = CGRect(x: center.x - 5, y: center.y - 5, width: 10, height: 10)

        var bitmap = [UInt8](repeating: 0, count: 400)  // 10x10 pixels * 4 bytes
        ciContext.render(image, toBitmap: &bitmap, rowBytes: 40, bounds: sampleRect, format: .RGBA8, colorSpace: nil)

        // Average color
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0

        for i in stride(from: 0, to: 400, by: 4) {
            r += CGFloat(bitmap[i])
            g += CGFloat(bitmap[i + 1])
            b += CGFloat(bitmap[i + 2])
        }

        let count = CGFloat(100)  // 10x10 pixels
        return UIColor(red: r / (count * 255), green: g / (count * 255), blue: b / (count * 255), alpha: 1.0)
    }

    private func analyzeMotion(current: CIImage, previous: CIImage?) -> Float? {
        guard let prev = previous else { return nil }

        // Simple motion detection via frame differencing
        let diff = current.applyingFilter("CIDifferenceBlendMode", parameters: [
            kCIInputBackgroundImageKey: prev
        ])

        // Calculate average difference
        let brightness = analyzeBrightness(diff)

        return brightness
    }

    private func analyzeOpticalFlow(current: CIImage, previous: CIImage?) -> SIMD3<Float>? {
        guard let prev = previous else { return nil }

        // Use Vision framework for optical flow
        let request = VNGenerateOpticalFlowRequest()

        do {
            let currentHandler = VNImageRequestHandler(ciImage: current)
            let prevHandler = VNImageRequestHandler(ciImage: prev)

            request.setComputationDevice(.cpu, for: .accurate)

            try prevHandler.perform([request])

            if let observation = request.results?.first as? VNPixelBufferObservation {
                // Analyze flow vectors
                let flow = analyzeFlowVectors(observation.pixelBuffer)
                return flow
            }
        } catch {
            print("⚠️ Optical flow error: \(error)")
        }

        return nil
    }

    private func analyzeFlowVectors(_ pixelBuffer: CVPixelBuffer) -> SIMD3<Float> {
        // Sample center region for dominant flow direction
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return SIMD3<Float>(0, 0, 0)
        }

        // Sample center 10x10 region
        var avgX: Float = 0
        var avgY: Float = 0

        let centerX = width / 2
        let centerY = height / 2

        for y in (centerY - 5)...(centerY + 5) {
            for x in (centerX - 5)...(centerX + 5) {
                let offset = y * bytesPerRow + x * 2 * MemoryLayout<Float>.size
                let ptr = baseAddress.advanced(by: offset).assumingMemoryBound(to: Float.self)

                avgX += ptr[0]
                avgY += ptr[1]
            }
        }

        avgX /= 100.0
        avgY /= 100.0

        return SIMD3<Float>(avgX, avgY, 0)
    }

    private func detectFaces(in image: CIImage) -> [VNFaceObservation]? {
        let request = VNDetectFaceRectanglesRequest()

        do {
            let handler = VNImageRequestHandler(ciImage: image)
            try handler.perform([request])

            return request.results as? [VNFaceObservation]
        } catch {
            print("⚠️ Face detection error: \(error)")
            return nil
        }
    }

    // MARK: - Mapping Functions

    private func mapBrightnessToFrequency(_ brightness: Float) -> Float {
        // Brightness 0-1 → Frequency 200-8000 Hz
        let minFreq: Float = 200.0
        let maxFreq: Float = 8000.0

        return minFreq + brightness * (maxFreq - minFreq)
    }

    private func mapColorToPitch(_ color: UIColor) -> Float {
        var hue: CGFloat = 0
        color.getHue(&hue, saturation: nil, brightness: nil, alpha: nil)

        // Hue 0-1 → MIDI note 60-84 (C4-C6)
        let minNote: Float = 60.0
        let maxNote: Float = 84.0

        let note = minNote + Float(hue) * (maxNote - minNote)

        // Convert MIDI note to frequency
        return 440.0 * pow(2.0, (note - 69.0) / 12.0)
    }

    private func mapMotionToTempo(_ motion: Float) -> Float {
        // Motion 0-1 → Tempo 60-180 BPM
        let minTempo: Float = 60.0
        let maxTempo: Float = 180.0

        return minTempo + motion * (maxTempo - minTempo)
    }

    // MARK: - Setup

    private func setupVisionRequests() {
        faceDetectionRequest = VNDetectFaceRectanglesRequest()
        opticalFlowRequest = VNGenerateOpticalFlowRequest()
    }

    // MARK: - Supporting Types

    struct MappedAudioParameters {
        var filterCutoff: Float = 1000.0
        var pitch: Float = 440.0
        var tempo: Float = 120.0
        var rhythmIntensity: Float = 0.5
        var spatialPosition: SIMD3<Float> = SIMD3<Float>(0, 0, 0)
        var faceDetected: Bool = false
        var faceCount: Int = 0
        var facePosition: CGPoint = .zero
    }
}

// MARK: - Motion to MIDI Mapper

@MainActor
class MotionToMIDIMapper: ObservableObject {

    // MARK: - Published State

    @Published var isActive: Bool = false
    @Published var generatedNotes: [MIDINote] = []

    // MARK: - Configuration

    var velocityThreshold: Float = 0.3
    var noteQuantization: Bool = true
    var scale: Scale = .major
    var rootNote: UInt8 = 60  // C4

    // MARK: - Motion State

    private var lastMotionTime: Date?
    private var motionHistory: [Float] = []

    // MARK: - Public API

    func start() {
        isActive = true
        print("🎬→🎹 Motion-to-MIDI mapping started")
    }

    func stop() {
        isActive = false
    }

    /// Process motion data and generate MIDI notes
    func processMotion(velocity: SIMD3<Float>, timestamp: Date) {
        guard isActive else { return }

        let speed = simd_length(velocity)

        // Trigger note on motion spike
        if speed > velocityThreshold {
            let timeSinceLastNote = lastMotionTime?.distance(to: timestamp) ?? 1.0

            if timeSinceLastNote > 0.1 {  // Debounce: 100ms
                let note = generateNote(from: velocity, speed: speed)
                generatedNotes.append(note)

                lastMotionTime = timestamp

                print("🎹 Motion MIDI: Note \(note.pitch) Vel \(note.velocity)")
            }
        }

        // Track motion history
        motionHistory.append(speed)
        if motionHistory.count > 100 {
            motionHistory.removeFirst()
        }
    }

    // MARK: - Private Methods

    private func generateNote(from velocity: SIMD3<Float>, speed: Float) -> MIDINote {
        // Direction → Pitch
        let angle = atan2(velocity.y, velocity.x)
        let normalizedAngle = (angle + .pi) / (2 * .pi)  // 0-1

        var pitch: UInt8

        if noteQuantization {
            // Quantize to scale
            let scaleNotes = scale.notes(rootNote: rootNote)
            let index = Int(normalizedAngle * Float(scaleNotes.count))
            pitch = scaleNotes[min(index, scaleNotes.count - 1)]
        } else {
            // Chromatic
            pitch = rootNote + UInt8(normalizedAngle * 24)  // 2 octaves
        }

        // Speed → Velocity
        let velocity = UInt8(min(speed * 127.0, 127.0))

        return MIDINote(pitch: pitch, velocity: velocity, duration: 0.25)
    }

    // MARK: - Supporting Types

    struct MIDINote {
        let pitch: UInt8
        let velocity: UInt8
        let duration: TimeInterval
    }

    enum Scale {
        case major
        case minor
        case pentatonic
        case chromatic

        func notes(rootNote: UInt8) -> [UInt8] {
            let intervals: [UInt8]

            switch self {
            case .major:
                intervals = [0, 2, 4, 5, 7, 9, 11]
            case .minor:
                intervals = [0, 2, 3, 5, 7, 8, 10]
            case .pentatonic:
                intervals = [0, 2, 4, 7, 9]
            case .chromatic:
                intervals = Array(0...11)
            }

            return intervals.map { rootNote + $0 }
        }
    }
}
