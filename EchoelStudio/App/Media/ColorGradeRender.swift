import AVFoundation
import CoreImage
import CoreImage.CIFilterBuiltins
import CoreVideo
import EchoelCore
import Foundation

/// Draws a video part through its colour correction (COLOR) — the one drawing the video window and
/// the video export share, so both show the same picture. The grade becomes a colour cube
/// (`ColorGrade.cube`), and Core Image reads every frame through it with no colour management of
/// its own: the frame's values go in as they are and come out through the cube, so the result is
/// the mapping `ColorGrade` documents and nothing else. A standard grade is never drawn here; the
/// player and the export then show the file as they always did.
final class ColorGradeRenderer: @unchecked Sendable {
    static let shared = ColorGradeRenderer()

    private let context = CIContext(options: [.workingColorSpace: NSNull(), .outputColorSpace: NSNull(),
                                              .cacheIntermediates: false])
    /// The last few grades' cubes; a cube is made once and read by every frame of that grade.
    private var cubes: [ColorGrade: Data] = [:]
    private var made: [ColorGrade] = []
    private let lock = NSLock()

    private func cube(for grade: ColorGrade) -> Data {
        lock.lock()
        defer { lock.unlock() }
        if let cube = cubes[grade] { return cube }
        let cube = grade.cube().withUnsafeBufferPointer { Data(buffer: $0) }
        cubes[grade] = cube
        made.append(grade)
        if made.count > 8 { cubes[made.removeFirst()] = nil }
        return cube
    }

    /// `image` through `grade`.
    func graded(_ image: CIImage, by grade: ColorGrade) -> CIImage {
        let held = grade.held
        guard !held.isNeutral else { return image }
        let filter = CIFilter.colorCube()
        filter.cubeDimension = Float(ColorGrade.cubeSize)
        filter.cubeData = cube(for: held)
        filter.inputImage = image
        return filter.outputImage ?? image
    }

    /// `source` through `grade`, placed by `placing` — the transform the export's layer
    /// instruction takes, in pixels from the top left — into `output`, black where it does not
    /// reach. Without a source the frame is black.
    func draw(_ source: CVPixelBuffer?, grade: ColorGrade, placing: CGAffineTransform, into output: CVPixelBuffer) {
        let frame = CGRect(x: 0, y: 0, width: CVPixelBufferGetWidth(output), height: CVPixelBufferGetHeight(output))
        var picture = CIImage(color: CIColor(red: 0, green: 0, blue: 0)).cropped(to: frame)
        if let source {
            let image = graded(CIImage(cvPixelBuffer: source, options: [.colorSpace: NSNull()]), by: grade)
            // Core Image counts from the bottom left; the transform counts from the top left.
            let intoTopLeft = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: CGFloat(CVPixelBufferGetHeight(source)))
            let intoBottomLeft = CGAffineTransform(a: 1, b: 0, c: 0, d: -1, tx: 0, ty: frame.height)
            let placed = image.transformed(by: intoTopLeft.concatenating(placing).concatenating(intoBottomLeft))
            picture = placed.composited(over: picture).cropped(to: frame)
        }
        context.render(picture, to: output, bounds: frame, colorSpace: nil)
    }

    /// `source` through `grade` into a new frame of its own size, for a drawing that places it
    /// itself (the Field Layer's export). Nil when no frame could be made.
    func graded(_ source: CVPixelBuffer, by grade: ColorGrade) -> CVPixelBuffer? {
        let attributes: [String: Any] = [kCVPixelBufferMetalCompatibilityKey as String: true,
                                         kCVPixelBufferIOSurfacePropertiesKey as String: [String: Int]()]
        var made: CVPixelBuffer?
        guard CVPixelBufferCreate(kCFAllocatorDefault, CVPixelBufferGetWidth(source), CVPixelBufferGetHeight(source),
                                  kCVPixelFormatType_32BGRA, attributes as CFDictionary, &made) == kCVReturnSuccess,
              let made else { return nil }
        draw(source, grade: grade, placing: .identity, into: made)
        return made
    }
}

/// The grade a stretch shows, read on the compositor's thread: fixed for an export, moved along by
/// the video window as the song clock passes from part to part of one file.
final class ColorGradeSource: @unchecked Sendable {
    private let lock = NSLock()
    private var current: ColorGrade

    init(_ grade: ColorGrade = .neutral) {
        current = grade
    }

    var grade: ColorGrade {
        get {
            lock.lock()
            defer { lock.unlock() }
            return current
        }
        set {
            lock.lock()
            current = newValue
            lock.unlock()
        }
    }
}

/// One stretch drawn through a colour correction: a part of a video file placed in the frame — or
/// black — and the grade it shows.
final class ColorGradeInstruction: NSObject, AVVideoCompositionInstructionProtocol {
    /// A time range, carried across the compositor's threads; it is never changed after `init`.
    private struct Span: @unchecked Sendable {
        let value: CMTimeRange
    }

    private let span: Span
    let enablePostProcessing = false
    /// The window's grade may change while a picture stands still: a frame is never reused.
    let containsTweening = true
    let passthroughTrackID: CMPersistentTrackID = kCMPersistentTrackID_Invalid
    /// The picture track this stretch shows; nil for black.
    let track: CMPersistentTrackID?
    let placing: CGAffineTransform
    let grade: ColorGradeSource

    init(timeRange: CMTimeRange, track: CMPersistentTrackID?, placing: CGAffineTransform, grade: ColorGradeSource) {
        span = Span(value: timeRange)
        self.track = track
        self.placing = placing
        self.grade = grade
        super.init()
    }

    var timeRange: CMTimeRange { span.value }

    var requiredSourceTrackIDs: [NSValue]? {
        guard let track else { return [] }
        return [NSNumber(value: track)]
    }
}

/// The compositor of a picture with a colour correction, in the video window and the video export
/// alike: each frame through `ColorGradeRenderer`, finished before the request returns.
final class ColorGradeCompositor: NSObject, AVVideoCompositing {
    var sourcePixelBufferAttributes: [String: any Sendable]? {
        [kCVPixelBufferPixelFormatTypeKey as String: [kCVPixelFormatType_32BGRA],
         kCVPixelBufferMetalCompatibilityKey as String: true]
    }

    var requiredPixelBufferAttributesForRenderContext: [String: any Sendable] {
        [kCVPixelBufferPixelFormatTypeKey as String: [kCVPixelFormatType_32BGRA],
         kCVPixelBufferMetalCompatibilityKey as String: true,
         kCVPixelBufferIOSurfacePropertiesKey as String: [String: Int]()]
    }

    func renderContextChanged(_ newRenderContext: AVVideoCompositionRenderContext) {}

    func startRequest(_ request: AVAsynchronousVideoCompositionRequest) {
        guard let instruction = request.videoCompositionInstruction as? ColorGradeInstruction,
              let output = request.renderContext.newPixelBuffer() else {
            request.finish(with: Self.failure)
            return
        }
        // The frame is written as it is encoded; the encoder is told Rec. 709, as the source was read.
        CVBufferSetAttachment(output, kCVImageBufferColorPrimariesKey, kCVImageBufferColorPrimaries_ITU_R_709_2, .shouldPropagate)
        CVBufferSetAttachment(output, kCVImageBufferTransferFunctionKey, kCVImageBufferTransferFunction_ITU_R_709_2, .shouldPropagate)
        CVBufferSetAttachment(output, kCVImageBufferYCbCrMatrixKey, kCVImageBufferYCbCrMatrix_ITU_R_709_2, .shouldPropagate)
        let source = instruction.track.flatMap { request.sourceFrame(byTrackID: $0) }
        ColorGradeRenderer.shared.draw(source, grade: instruction.grade.grade, placing: instruction.placing, into: output)
        request.finish(withComposedVideoFrame: output)
    }

    func cancelAllPendingVideoCompositionRequests() {}

    static var failure: NSError {
        NSError(domain: "com.echoelmusic.studio.color", code: 1)
    }
}
