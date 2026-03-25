#if canImport(ARKit) && canImport(SwiftUI) && os(iOS)
import ARKit
import SwiftUI
import Observation

/// Headless ARKit face tracking for smile detection.
/// Uses TrueDepth camera — no ARView, no GPU rendering.
/// Neural Engine only, ~3-5% CPU overhead.
///
/// Bio-reactive mapping: smile intensity → synth brightness / wavetable morph
@MainActor
@Observable
final class SmileDetector: NSObject {

    /// Smile intensity from 0.0 (neutral) to 1.0 (full smile)
    var smileAmount: Float = 0

    /// Whether face tracking is actively running
    var isDetecting: Bool = false

    /// Whether device supports face tracking (TrueDepth camera required)
    static var isSupported: Bool {
        ARFaceTrackingConfiguration.isSupported
    }

    // MARK: - Private

    @ObservationIgnored private var session: ARSession?
    @ObservationIgnored private var delegate: FaceTrackingDelegate?

    // MARK: - Public API

    func startDetecting() {
        guard SmileDetector.isSupported else {
            log.log(.info, category: .biofeedback, "SmileDetector: TrueDepth not available")
            return
        }
        guard !isDetecting else { return }

        let config = ARFaceTrackingConfiguration()
        config.maximumNumberOfTrackedFaces = 1
        if #available(iOS 17.0, *) {
            config.videoHDRAllowed = false
        }

        let arSession = ARSession()
        let arDelegate = FaceTrackingDelegate { [weak self] smile in
            Task { @MainActor [weak self] in
                self?.smileAmount = smile
            }
        }

        arSession.delegate = arDelegate
        arSession.run(config)

        session = arSession
        delegate = arDelegate
        isDetecting = true

        log.log(.info, category: .biofeedback, "SmileDetector: Started headless face tracking")
    }

    func stopDetecting() {
        session?.pause()
        session = nil
        delegate = nil
        isDetecting = false
        smileAmount = 0

        log.log(.info, category: .biofeedback, "SmileDetector: Stopped")
    }
}

// MARK: - ARSessionDelegate (nonisolated for callback thread)

private final class FaceTrackingDelegate: NSObject, ARSessionDelegate, @unchecked Sendable {

    private let onSmile: @Sendable (Float) -> Void

    /// Throttle to ~15fps to reduce MainActor hops
    private static let updateInterval: TimeInterval = 1.0 / 15.0
    private var lastUpdateTime: TimeInterval = 0

    init(onSmile: @escaping @Sendable (Float) -> Void) {
        self.onSmile = onSmile
        super.init()
    }

    func session(_ session: ARSession, didUpdate anchors: [ARAnchor]) {
        let now = CACurrentMediaTime()
        guard now - lastUpdateTime >= FaceTrackingDelegate.updateInterval else { return }
        lastUpdateTime = now

        guard let face = anchors.first(where: { $0 is ARFaceAnchor }) as? ARFaceAnchor else { return }

        let left = face.blendShapes[.mouthSmileLeft]?.floatValue ?? 0
        let right = face.blendShapes[.mouthSmileRight]?.floatValue ?? 0
        let smile = (left + right) / 2.0

        onSmile(smile)
    }
}
#endif
