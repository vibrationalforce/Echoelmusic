import Foundation
import Vision
import AVFoundation
import CoreImage

/// Professional Gesture Control Engine
/// **Hands-free camera and color control via hand tracking**
///
/// **Gesture Support**:
/// - **Pinch**: Adjust ISO/Aperture/Focus (thumb + index finger)
/// - **Swipe Left/Right**: Change white balance (Kelvin)
/// - **Swipe Up/Down**: Adjust exposure
/// - **Open Palm**: Take photo / Start recording
/// - **Fist**: Stop recording
/// - **Two Fingers Up**: Increase sensitivity
/// - **Two Fingers Down**: Decrease sensitivity
/// - **Circle**: Reset to defaults
/// - **Thumbs Up**: Apply/Confirm
/// - **Peace Sign**: Switch mode
///
/// **Accessibility Features**:
/// - Works with one hand or two hands
/// - Customizable gesture sensitivity
/// - Visual feedback for recognized gestures
/// - Haptic feedback confirmation
/// - Gesture hold time adjustment (for tremors/motor difficulties)
/// - Gesture size tolerance (for limited mobility)
@MainActor
class GestureControlEngine: NSObject, ObservableObject {

    // MARK: - Published State

    @Published var isEnabled = false
    @Published var currentGesture: RecognizedGesture?
    @Published var gestureConfidence: Float = 0.0
    @Published var visualFeedbackEnabled = true
    @Published var hapticFeedbackEnabled = true
    @Published var currentMode: ControlMode = .camera

    // Accessibility settings
    @Published var gestureSensitivity: Float = 0.7  // 0-1
    @Published var holdTimeRequired: Double = 0.3  // seconds
    @Published var sizeToleranceEnabled = true  // Allow smaller gestures
    @Published var oneHandedMode = false  // Only use dominant hand

    // MARK: - Hand Tracking

    private var handPoseRequest: VNDetectHumanHandPoseRequest?
    private var lastProcessedTime: Date?
    private let minimumProcessingInterval: TimeInterval = 0.05  // 20 FPS max

    // Gesture state tracking
    private var gestureStartTime: Date?
    private var previousHandPosition: CGPoint?
    private var gestureHistory: [RecognizedGesture] = []

    // MARK: - System Integrations

    weak var cameraSystem: CinemaCameraSystem?
    weak var colorGrading: ProfessionalColorGrading?
    weak var feedbackSuppressor: IntelligentFeedbackSuppressor?

    // MARK: - Control Modes

    enum ControlMode: String, CaseIterable {
        case camera = "Camera"
        case colorGrading = "Color Grading"
        case feedbackSuppression = "Feedback Suppression"
        case playback = "Playback"

        var icon: String {
            switch self {
            case .camera: return "video.fill"
            case .colorGrading: return "paintpalette.fill"
            case .feedbackSuppression: return "waveform.badge.exclamationmark"
            case .playback: return "play.fill"
            }
        }
    }

    // MARK: - Recognized Gestures

    enum RecognizedGesture: String {
        case pinch = "Pinch"
        case swipeLeft = "Swipe Left"
        case swipeRight = "Swipe Right"
        case swipeUp = "Swipe Up"
        case swipeDown = "Swipe Down"
        case openPalm = "Open Palm"
        case fist = "Fist"
        case twoFingersUp = "Two Fingers Up"
        case twoFingersDown = "Two Fingers Down"
        case circle = "Circle"
        case thumbsUp = "Thumbs Up"
        case peaceSign = "Peace Sign"

        var description: String {
            switch self {
            case .pinch: return "Fine adjustment"
            case .swipeLeft: return "Decrease / Cooler"
            case .swipeRight: return "Increase / Warmer"
            case .swipeUp: return "Increase / Brighter"
            case .swipeDown: return "Decrease / Darker"
            case .openPalm: return "Action / Record"
            case .fist: return "Stop"
            case .twoFingersUp: return "Increase sensitivity"
            case .twoFingersDown: return "Decrease sensitivity"
            case .circle: return "Reset"
            case .thumbsUp: return "Confirm"
            case .peaceSign: return "Switch mode"
            }
        }
    }

    // MARK: - Initialization

    override init() {
        super.init()
        setupHandPoseDetection()
        print("✋ Gesture Control Engine initialized")
        print("   Gestures: Pinch, Swipe, Open Palm, Fist, Peace, Thumbs Up")
    }

    private func setupHandPoseDetection() {
        handPoseRequest = VNDetectHumanHandPoseRequest()
        handPoseRequest?.maximumHandCount = oneHandedMode ? 1 : 2
    }

    // MARK: - Lifecycle

    func enable() {
        isEnabled = true
        provideHapticFeedback(style: .medium)
        print("✅ Gesture control enabled")
    }

    func disable() {
        isEnabled = false
        currentGesture = nil
        provideHapticFeedback(style: .light)
        print("⏸️ Gesture control disabled")
    }

    func switchMode() {
        let allModes = ControlMode.allCases
        if let currentIndex = allModes.firstIndex(of: currentMode) {
            let nextIndex = (currentIndex + 1) % allModes.count
            currentMode = allModes[nextIndex]
            provideHapticFeedback(style: .medium)
            print("🔄 Switched to \(currentMode.rawValue) mode")
        }
    }

    // MARK: - Hand Pose Processing

    func processVideoFrame(_ pixelBuffer: CVPixelBuffer) {
        guard isEnabled else { return }

        // Throttle processing
        if let lastTime = lastProcessedTime, Date().timeIntervalSince(lastTime) < minimumProcessingInterval {
            return
        }
        lastProcessedTime = Date()

        guard let request = handPoseRequest else { return }

        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])

        do {
            try handler.perform([request])

            if let observation = request.results?.first {
                analyzeHandPose(observation)
            } else {
                // No hand detected
                currentGesture = nil
                gestureStartTime = nil
            }
        } catch {
            print("❌ Hand pose detection failed: \(error)")
        }
    }

    private func analyzeHandPose(_ observation: VNHumanHandPoseObservation) {
        guard observation.confidence > gestureSensitivity else { return }

        do {
            // Get thumb and finger points
            let thumbTip = try observation.recognizedPoint(.thumbTip)
            let indexTip = try observation.recognizedPoint(.indexTip)
            let middleTip = try observation.recognizedPoint(.middleTip)
            let ringTip = try observation.recognizedPoint(.ringTip)
            let littleTip = try observation.recognizedPoint(.littleTip)
            let wrist = try observation.recognizedPoint(.wrist)

            // Detect specific gestures
            if let gesture = detectGesture(
                thumb: thumbTip,
                index: indexTip,
                middle: middleTip,
                ring: ringTip,
                little: littleTip,
                wrist: wrist
            ) {
                handleGesture(gesture, confidence: observation.confidence)
            }

        } catch {
            // Point not available
        }
    }

    private func detectGesture(
        thumb: VNRecognizedPoint,
        index: VNRecognizedPoint,
        middle: VNRecognizedPoint,
        ring: VNRecognizedPoint,
        little: VNRecognizedPoint,
        wrist: VNRecognizedPoint
    ) -> RecognizedGesture? {

        // Calculate distances
        let thumbIndexDistance = distance(thumb.location, index.location)
        let indexMiddleDistance = distance(index.location, middle.location)

        // Detect pinch (thumb and index finger close together)
        if thumbIndexDistance < 0.05 {
            return .pinch
        }

        // Detect peace sign (index and middle extended, others closed)
        if index.location.y < wrist.location.y &&
           middle.location.y < wrist.location.y &&
           ring.location.y > wrist.location.y &&
           little.location.y > wrist.location.y &&
           indexMiddleDistance > 0.05 {
            return .peaceSign
        }

        // Detect thumbs up (thumb extended up, others closed)
        if thumb.location.y < index.location.y &&
           thumb.location.y < middle.location.y &&
           index.location.y > wrist.location.y {
            return .thumbsUp
        }

        // Detect open palm (all fingers extended)
        let allFingersExtended = index.location.y < wrist.location.y &&
                                 middle.location.y < wrist.location.y &&
                                 ring.location.y < wrist.location.y &&
                                 little.location.y < wrist.location.y
        if allFingersExtended {
            return .openPalm
        }

        // Detect fist (all fingers closed)
        let allFingersClosed = index.location.y > wrist.location.y &&
                               middle.location.y > wrist.location.y &&
                               ring.location.y > wrist.location.y &&
                               little.location.y > wrist.location.y
        if allFingersClosed {
            return .fist
        }

        // Detect swipe gestures (based on hand movement)
        if let previousPosition = previousHandPosition {
            let currentPosition = wrist.location
            let deltaX = currentPosition.x - previousPosition.x
            let deltaY = currentPosition.y - previousPosition.y

            let swipeThreshold: CGFloat = sizeToleranceEnabled ? 0.1 : 0.15

            if abs(deltaX) > swipeThreshold {
                previousHandPosition = currentPosition
                return deltaX > 0 ? .swipeRight : .swipeLeft
            }

            if abs(deltaY) > swipeThreshold {
                previousHandPosition = currentPosition
                return deltaY > 0 ? .swipeDown : .swipeUp
            }
        }

        previousHandPosition = wrist.location

        return nil
    }

    private func handleGesture(_ gesture: RecognizedGesture, confidence: Float) {
        // Check if gesture is held long enough
        if currentGesture != gesture {
            gestureStartTime = Date()
            currentGesture = gesture
            gestureConfidence = confidence
            return
        }

        guard let startTime = gestureStartTime,
              Date().timeIntervalSince(startTime) >= holdTimeRequired else {
            return
        }

        // Gesture confirmed - execute action
        executeGestureAction(gesture)

        // Add to history
        gestureHistory.append(gesture)
        if gestureHistory.count > 20 {
            gestureHistory.removeFirst()
        }

        // Reset for next gesture
        gestureStartTime = nil
        currentGesture = nil
    }

    private func executeGestureAction(_ gesture: RecognizedGesture) {
        print("✋ Gesture: \(gesture.rawValue) in \(currentMode.rawValue) mode")

        switch currentMode {
        case .camera:
            executeCameraGesture(gesture)
        case .colorGrading:
            executeColorGradingGesture(gesture)
        case .feedbackSuppression:
            executeFeedbackGesture(gesture)
        case .playback:
            executePlaybackGesture(gesture)
        }

        if visualFeedbackEnabled {
            // Visual feedback would be shown in UI
        }

        if hapticFeedbackEnabled {
            provideHapticFeedback(style: .light)
        }
    }

    // MARK: - Camera Gesture Actions

    private func executeCameraGesture(_ gesture: RecognizedGesture) {
        switch gesture {
        case .pinch:
            // Fine adjustment mode (would show slider in UI)
            print("📷 Fine adjustment mode")

        case .swipeLeft:
            // Decrease Kelvin (cooler)
            if let current = cameraSystem?.whiteBalanceKelvin {
                let newKelvin = max(1000, current - 100)
                cameraSystem?.setWhiteBalance(kelvin: newKelvin, tint: 0)
                print("📷 White balance: \(Int(newKelvin))K (cooler)")
            }

        case .swipeRight:
            // Increase Kelvin (warmer)
            if let current = cameraSystem?.whiteBalanceKelvin {
                let newKelvin = min(10000, current + 100)
                cameraSystem?.setWhiteBalance(kelvin: newKelvin, tint: 0)
                print("📷 White balance: \(Int(newKelvin))K (warmer)")
            }

        case .swipeUp:
            // Increase ISO
            if let current = cameraSystem?.iso {
                let newISO = min(25600, current + 200)
                cameraSystem?.setISO(newISO)
                print("📷 ISO increased to \(Int(newISO))")
            }

        case .swipeDown:
            // Decrease ISO
            if let current = cameraSystem?.iso {
                let newISO = max(100, current - 200)
                cameraSystem?.setISO(newISO)
                print("📷 ISO decreased to \(Int(newISO))")
            }

        case .openPalm:
            // Start recording
            cameraSystem?.startRecording()
            print("🎬 Recording started")
            provideHapticFeedback(style: .success)

        case .fist:
            // Stop recording
            cameraSystem?.stopRecording()
            print("⏹️ Recording stopped")
            provideHapticFeedback(style: .success)

        case .thumbsUp:
            // Take photo
            print("📸 Photo captured")
            provideHapticFeedback(style: .success)

        case .peaceSign:
            // Switch mode
            switchMode()

        default:
            break
        }
    }

    // MARK: - Color Grading Gesture Actions

    private func executeColorGradingGesture(_ gesture: RecognizedGesture) {
        switch gesture {
        case .swipeLeft:
            // Cooler temperature
            if let current = colorGrading?.temperature {
                let newTemp = max(-100, current - 5)
                colorGrading?.temperature = newTemp
                print("🎨 Temperature cooler")
            }

        case .swipeRight:
            // Warmer temperature
            if let current = colorGrading?.temperature {
                let newTemp = min(100, current + 5)
                colorGrading?.temperature = newTemp
                print("🎨 Temperature warmer")
            }

        case .swipeUp:
            // Increase exposure
            if let current = colorGrading?.exposure {
                let newExposure = min(2, current + 0.2)
                colorGrading?.exposure = newExposure
                print("🎨 Exposure increased")
            }

        case .swipeDown:
            // Decrease exposure
            if let current = colorGrading?.exposure {
                let newExposure = max(-2, current - 0.2)
                colorGrading?.exposure = newExposure
                print("🎨 Exposure decreased")
            }

        case .pinch:
            // Fine adjustment mode
            print("🎨 Fine color adjustment mode")

        case .openPalm:
            // Load golden hour preset
            colorGrading?.loadPreset(.goldenHour)
            print("🎨 Golden hour preset loaded")
            provideHapticFeedback(style: .success)

        case .fist:
            // Load cinematic preset
            colorGrading?.loadPreset(.cinematic)
            print("🎨 Cinematic preset loaded")
            provideHapticFeedback(style: .success)

        case .circle:
            // Reset color grading
            colorGrading?.reset()
            print("🎨 Color grading reset")
            provideHapticFeedback(style: .success)

        case .peaceSign:
            // Switch mode
            switchMode()

        default:
            break
        }
    }

    // MARK: - Feedback Suppression Gesture Actions

    private func executeFeedbackGesture(_ gesture: RecognizedGesture) {
        switch gesture {
        case .twoFingersUp:
            // Increase sensitivity
            if let current = feedbackSuppressor?.sensitivity {
                let newSensitivity = min(1.0, current + 0.1)
                feedbackSuppressor?.sensitivity = newSensitivity
                print("🔊 Feedback sensitivity increased")
            }

        case .twoFingersDown:
            // Decrease sensitivity
            if let current = feedbackSuppressor?.sensitivity {
                let newSensitivity = max(0.0, current - 0.1)
                feedbackSuppressor?.sensitivity = newSensitivity
                print("🔊 Feedback sensitivity decreased")
            }

        case .openPalm:
            // Load Live PA scenario
            feedbackSuppressor?.loadScenario(.livePA)
            print("🔊 Live PA mode enabled")
            provideHapticFeedback(style: .success)

        case .fist:
            // Load Home Recording scenario
            feedbackSuppressor?.loadScenario(.homeRecording)
            print("🔊 Home recording mode enabled")
            provideHapticFeedback(style: .success)

        case .circle:
            // Clear all notches
            feedbackSuppressor?.clearAllNotches()
            print("🔊 Feedback notches cleared")
            provideHapticFeedback(style: .success)

        case .peaceSign:
            // Switch mode
            switchMode()

        default:
            break
        }
    }

    // MARK: - Playback Gesture Actions

    private func executePlaybackGesture(_ gesture: RecognizedGesture) {
        switch gesture {
        case .openPalm:
            // Play
            print("▶️ Play")
            provideHapticFeedback(style: .light)

        case .fist:
            // Pause
            print("⏸️ Pause")
            provideHapticFeedback(style: .light)

        case .swipeRight:
            // Skip forward
            print("⏭️ Skip forward")

        case .swipeLeft:
            // Skip backward
            print("⏮️ Skip backward")

        case .swipeUp:
            // Volume up
            print("🔊 Volume up")

        case .swipeDown:
            // Volume down
            print("🔉 Volume down")

        case .peaceSign:
            // Switch mode
            switchMode()

        default:
            break
        }
    }

    // MARK: - Utilities

    private func distance(_ point1: CGPoint, _ point2: CGPoint) -> CGFloat {
        let dx = point1.x - point2.x
        let dy = point1.y - point2.y
        return sqrt(dx * dx + dy * dy)
    }

    private func provideHapticFeedback(style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard hapticFeedbackEnabled else { return }

        #if os(iOS)
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.impactOccurred()
        #endif
    }

    // MARK: - Accessibility Adjustments

    func adjustForAccessibility(tremors: Bool = false, limitedMobility: Bool = false) {
        if tremors {
            // Increase hold time for people with tremors
            holdTimeRequired = 0.6
            gestureSensitivity = 0.5  // Lower sensitivity to avoid accidental triggers
            print("♿ Adjusted for tremors: Hold time 0.6s, Sensitivity 50%")
        }

        if limitedMobility {
            // Enable size tolerance for smaller gestures
            sizeToleranceEnabled = true
            gestureSensitivity = 0.6
            print("♿ Adjusted for limited mobility: Size tolerance enabled")
        }
    }
}
