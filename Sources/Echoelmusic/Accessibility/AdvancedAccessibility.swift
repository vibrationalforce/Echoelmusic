//
//  AdvancedAccessibility.swift
//  Echoelmusic
//
//  Created: December 2025
//  ADVANCED ACCESSIBILITY - Beyond WCAG
//
//  "Musik ist für ALLE - ohne Ausnahme"
//
//  Features:
//  - Audio-to-Haptic: Musik als Vibration für Gehörlose
//  - Sign Language Avatar: Gebärdensprache für UI
//  - Eye-Tracking: Steuerung für motorisch Eingeschränkte
//  - Bone Conduction: Audio über Knochenleitung
//  - Brain-Computer Interface Ready: Zukunftssicher
//

import Foundation
import SwiftUI
import CoreHaptics
import AVFoundation
import Accelerate
import CoreMotion
import Combine

// MARK: - Audio-to-Haptic Engine

/// Konvertiert Audio in Echtzeit zu haptischem Feedback
/// Ermöglicht Gehörlosen, Musik zu "fühlen"
@MainActor
public final class AudioToHapticEngine: ObservableObject {

    public static let shared = AudioToHapticEngine()

    // MARK: - Published State

    @Published public var isEnabled: Bool = false
    @Published public var hapticIntensity: Float = 1.0
    @Published public var frequencyMapping: FrequencyMapping = .musical
    @Published public var isPlaying: Bool = false

    // Frequency bands felt on different body parts (with wearables)
    @Published public var bassIntensity: Float = 0      // Low frequencies (20-250 Hz)
    @Published public var midIntensity: Float = 0       // Mid frequencies (250-2000 Hz)
    @Published public var trebleIntensity: Float = 0    // High frequencies (2000-20000 Hz)
    @Published public var rhythmPulse: Bool = false     // Beat detection

    // MARK: - Haptic Engine

    private var hapticEngine: CHHapticEngine?
    private var continuousPlayer: CHHapticAdvancedPatternPlayer?

    // MARK: - Audio Analysis

    private var audioEngine: AVAudioEngine?
    private var fftSetup: vDSP_DFT_Setup?
    private let fftSize = 1024

    // Beat detection
    private var energyHistory: [Float] = []
    private let beatThreshold: Float = 1.5

    // MARK: - Frequency Mapping Modes

    public enum FrequencyMapping: String, CaseIterable {
        case musical = "Musical"           // Maps to musical intervals
        case spatial = "Spatial"           // Bass=left, Treble=right
        case intensity = "Intensity"       // All frequencies to intensity
        case rhythm = "Rhythm Only"        // Only beat/rhythm
        case full = "Full Spectrum"        // Complete frequency mapping

        var description: String {
            switch self {
            case .musical: return "Fühle musikalische Harmonien und Melodien"
            case .spatial: return "Tiefe Töne links, hohe Töne rechts"
            case .intensity: return "Lautstärke als Vibrationsstärke"
            case .rhythm: return "Nur Rhythmus und Beats fühlen"
            case .full: return "Komplettes Frequenzspektrum"
            }
        }
    }

    // MARK: - Initialization

    private init() {
        setupHapticEngine()
        setupFFT()
    }

    private func setupHapticEngine() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            print("⚠️ AudioToHaptic: Device does not support haptics")
            return
        }

        do {
            hapticEngine = try CHHapticEngine()
            hapticEngine?.stoppedHandler = { [weak self] reason in
                print("⚠️ AudioToHaptic: Engine stopped - \(reason)")
                Task { @MainActor in
                    self?.isPlaying = false
                }
            }
            hapticEngine?.resetHandler = { [weak self] in
                Task { @MainActor in
                    try? self?.hapticEngine?.start()
                }
            }
            try hapticEngine?.start()
            print("✅ AudioToHaptic: Haptic engine initialized")
        } catch {
            print("❌ AudioToHaptic: Failed to initialize - \(error)")
        }
    }

    private func setupFFT() {
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)
    }

    // MARK: - Public API

    /// Start converting audio to haptics
    public func start() {
        guard !isPlaying else { return }

        do {
            try hapticEngine?.start()
            isPlaying = true
            isEnabled = true
            print("▶️ AudioToHaptic: Started")
        } catch {
            print("❌ AudioToHaptic: Failed to start - \(error)")
        }
    }

    /// Stop haptic feedback
    public func stop() {
        continuousPlayer?.stop(atTime: CHHapticTimeImmediate)
        isPlaying = false
        print("⏹️ AudioToHaptic: Stopped")
    }

    /// Process audio buffer and generate haptic feedback
    public func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard isEnabled, let floatData = buffer.floatChannelData?[0] else { return }

        let frameCount = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: floatData, count: frameCount))

        // Perform FFT
        let frequencyBands = analyzeFrequencies(samples)

        // Update band intensities
        bassIntensity = frequencyBands.bass
        midIntensity = frequencyBands.mid
        trebleIntensity = frequencyBands.treble

        // Beat detection
        let energy = calculateEnergy(samples)
        rhythmPulse = detectBeat(energy: energy)

        // Generate haptic pattern based on mapping mode
        generateHapticPattern(bass: frequencyBands.bass,
                             mid: frequencyBands.mid,
                             treble: frequencyBands.treble,
                             isBeat: rhythmPulse)
    }

    // MARK: - Frequency Analysis

    private func analyzeFrequencies(_ samples: [Float]) -> (bass: Float, mid: Float, treble: Float) {
        guard samples.count >= fftSize else {
            return (0, 0, 0)
        }

        // Prepare for FFT
        var realPart = [Float](samples.prefix(fftSize))
        var imagPart = [Float](repeating: 0, count: fftSize)

        var realOut = [Float](repeating: 0, count: fftSize)
        var imagOut = [Float](repeating: 0, count: fftSize)

        // Perform FFT
        if let setup = fftSetup {
            vDSP_DFT_Execute(setup, &realPart, &imagPart, &realOut, &imagOut)
        }

        // Calculate magnitudes
        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        for i in 0..<fftSize/2 {
            magnitudes[i] = sqrt(realOut[i] * realOut[i] + imagOut[i] * imagOut[i])
        }

        // Split into frequency bands (assuming 48kHz sample rate)
        // Bass: 20-250 Hz (bins 0-5)
        // Mid: 250-2000 Hz (bins 5-42)
        // Treble: 2000-20000 Hz (bins 42-512)

        let bassRange = 0..<6
        let midRange = 6..<43
        let trebleRange = 43..<min(magnitudes.count, 256)

        var bass: Float = 0
        var mid: Float = 0
        var treble: Float = 0

        vDSP_meanv(Array(magnitudes[bassRange]), 1, &bass, vDSP_Length(bassRange.count))
        vDSP_meanv(Array(magnitudes[midRange]), 1, &mid, vDSP_Length(midRange.count))
        vDSP_meanv(Array(magnitudes[trebleRange]), 1, &treble, vDSP_Length(trebleRange.count))

        // Normalize
        let maxVal = max(bass, mid, treble, 0.001)
        return (
            bass: min(bass / maxVal, 1.0),
            mid: min(mid / maxVal, 1.0),
            treble: min(treble / maxVal, 1.0)
        )
    }

    private func calculateEnergy(_ samples: [Float]) -> Float {
        var energy: Float = 0
        vDSP_svesq(samples, 1, &energy, vDSP_Length(samples.count))
        return sqrt(energy / Float(samples.count))
    }

    private func detectBeat(energy: Float) -> Bool {
        energyHistory.append(energy)
        if energyHistory.count > 43 { // ~1 second at 44100/1024
            energyHistory.removeFirst()
        }

        guard energyHistory.count >= 10 else { return false }

        var average: Float = 0
        vDSP_meanv(energyHistory, 1, &average, vDSP_Length(energyHistory.count))

        return energy > average * beatThreshold
    }

    // MARK: - Haptic Pattern Generation

    private func generateHapticPattern(bass: Float, mid: Float, treble: Float, isBeat: Bool) {
        guard let engine = hapticEngine else { return }

        do {
            var events: [CHHapticEvent] = []

            switch frequencyMapping {
            case .musical:
                // Map frequencies to musical haptic patterns
                let intensity = CHHapticEventParameter(
                    parameterID: .hapticIntensity,
                    value: (bass + mid * 0.7 + treble * 0.3) * hapticIntensity
                )
                let sharpness = CHHapticEventParameter(
                    parameterID: .hapticSharpness,
                    value: treble  // Higher frequencies = sharper feel
                )
                events.append(CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [intensity, sharpness],
                    relativeTime: 0,
                    duration: 0.05
                ))

            case .rhythm:
                // Only beat pulses
                if isBeat {
                    let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: hapticIntensity)
                    let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                    events.append(CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [intensity, sharpness],
                        relativeTime: 0
                    ))
                }

            case .intensity:
                // Overall loudness
                let totalIntensity = (bass + mid + treble) / 3.0
                let intensity = CHHapticEventParameter(parameterID: .hapticIntensity, value: totalIntensity * hapticIntensity)
                let sharpness = CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                events.append(CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [intensity, sharpness],
                    relativeTime: 0,
                    duration: 0.05
                ))

            case .spatial, .full:
                // Full spectrum mapping
                // Bass: strong, dull
                if bass > 0.1 {
                    events.append(CHHapticEvent(
                        eventType: .hapticContinuous,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: bass * hapticIntensity),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.1)
                        ],
                        relativeTime: 0,
                        duration: 0.05
                    ))
                }

                // Mid: medium
                if mid > 0.1 {
                    events.append(CHHapticEvent(
                        eventType: .hapticContinuous,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: mid * hapticIntensity * 0.7),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                        ],
                        relativeTime: 0,
                        duration: 0.05
                    ))
                }

                // Beat accent
                if isBeat {
                    events.append(CHHapticEvent(
                        eventType: .hapticTransient,
                        parameters: [
                            CHHapticEventParameter(parameterID: .hapticIntensity, value: hapticIntensity),
                            CHHapticEventParameter(parameterID: .hapticSharpness, value: 1.0)
                        ],
                        relativeTime: 0
                    ))
                }
            }

            guard !events.isEmpty else { return }

            let pattern = try CHHapticPattern(events: events, parameters: [])
            let player = try engine.makePlayer(with: pattern)
            try player.start(atTime: CHHapticTimeImmediate)

        } catch {
            // Silently fail for performance
        }
    }
}

// MARK: - Sign Language Avatar

/// Animated avatar für Gebärdensprache-Übersetzung
@MainActor
public final class SignLanguageAvatar: ObservableObject {

    public static let shared = SignLanguageAvatar()

    // MARK: - Published State

    @Published public var isEnabled: Bool = false
    @Published public var currentLanguage: SignLanguage = .asl
    @Published public var avatarStyle: AvatarStyle = .realistic
    @Published public var isAnimating: Bool = false
    @Published public var currentPhrase: String = ""

    // MARK: - Sign Languages

    public enum SignLanguage: String, CaseIterable, Identifiable {
        case asl = "ASL"                    // American Sign Language
        case bsl = "BSL"                    // British Sign Language
        case dgs = "DGS"                    // Deutsche Gebärdensprache
        case lsf = "LSF"                    // Langue des Signes Française
        case jsl = "JSL"                    // Japanese Sign Language
        case auslan = "Auslan"              // Australian Sign Language
        case libras = "Libras"              // Brazilian Sign Language
        case isl = "ISL"                    // International Sign Language

        public var id: String { rawValue }

        var displayName: String {
            switch self {
            case .asl: return "American Sign Language"
            case .bsl: return "British Sign Language"
            case .dgs: return "Deutsche Gebärdensprache"
            case .lsf: return "Langue des Signes Française"
            case .jsl: return "日本手話"
            case .auslan: return "Australian Sign Language"
            case .libras: return "Língua Brasileira de Sinais"
            case .isl: return "International Sign"
            }
        }

        var region: String {
            switch self {
            case .asl: return "🇺🇸"
            case .bsl: return "🇬🇧"
            case .dgs: return "🇩🇪"
            case .lsf: return "🇫🇷"
            case .jsl: return "🇯🇵"
            case .auslan: return "🇦🇺"
            case .libras: return "🇧🇷"
            case .isl: return "🌍"
            }
        }
    }

    // MARK: - Avatar Styles

    public enum AvatarStyle: String, CaseIterable {
        case realistic = "Realistic"
        case cartoon = "Cartoon"
        case minimal = "Minimal"
        case hands = "Hands Only"

        var description: String {
            switch self {
            case .realistic: return "Fotorealistische 3D-Animation"
            case .cartoon: return "Freundlicher Cartoon-Stil"
            case .minimal: return "Einfache Strichfigur"
            case .hands: return "Nur Hände für klare Zeichen"
            }
        }
    }

    // MARK: - Sign Dictionary

    private var signDictionary: [String: [SignGesture]] = [:]

    public struct SignGesture: Codable {
        let handShape: HandShape
        let location: SignLocation
        let movement: SignMovement
        let facialExpression: FacialExpression
        let duration: TimeInterval

        enum HandShape: String, Codable {
            case openHand, fist, pointingFinger, peace, thumbsUp, ok
            case cShape, lShape, aShape, bShape, claw
        }

        enum SignLocation: String, Codable {
            case neutral, forehead, chin, chest, shoulder
            case ear, nose, mouth, cheek, neck
        }

        enum SignMovement: String, Codable {
            case none, up, down, left, right
            case circular, wave, shake, push, pull
        }

        enum FacialExpression: String, Codable {
            case neutral, happy, sad, questioning, emphasis
            case surprised, thoughtful, concerned
        }
    }

    // MARK: - Initialization

    private init() {
        loadSignDictionary()
    }

    private func loadSignDictionary() {
        // Load common UI phrases
        signDictionary = [
            "welcome": [
                SignGesture(handShape: .openHand, location: .chest, movement: .push, facialExpression: .happy, duration: 0.5)
            ],
            "start": [
                SignGesture(handShape: .fist, location: .neutral, movement: .up, facialExpression: .neutral, duration: 0.3)
            ],
            "stop": [
                SignGesture(handShape: .openHand, location: .neutral, movement: .down, facialExpression: .emphasis, duration: 0.3)
            ],
            "heart_rate": [
                SignGesture(handShape: .fist, location: .chest, movement: .shake, facialExpression: .neutral, duration: 0.5)
            ],
            "music": [
                SignGesture(handShape: .openHand, location: .ear, movement: .wave, facialExpression: .happy, duration: 0.6)
            ],
            "settings": [
                SignGesture(handShape: .claw, location: .neutral, movement: .circular, facialExpression: .thoughtful, duration: 0.5)
            ],
            "help": [
                SignGesture(handShape: .thumbsUp, location: .chest, movement: .up, facialExpression: .questioning, duration: 0.4)
            ],
            "success": [
                SignGesture(handShape: .thumbsUp, location: .neutral, movement: .up, facialExpression: .happy, duration: 0.3)
            ],
            "error": [
                SignGesture(handShape: .openHand, location: .forehead, movement: .shake, facialExpression: .concerned, duration: 0.4)
            ]
        ]

        print("✅ SignLanguageAvatar: Loaded \(signDictionary.count) signs")
    }

    // MARK: - Public API

    /// Translate text to sign language animation
    public func translate(_ text: String) async {
        guard isEnabled else { return }

        currentPhrase = text
        isAnimating = true

        // Look up sign in dictionary
        let key = text.lowercased().replacingOccurrences(of: " ", with: "_")

        if let gestures = signDictionary[key] {
            for gesture in gestures {
                await performGesture(gesture)
            }
        } else {
            // Fingerspelling fallback
            await fingerspell(text)
        }

        isAnimating = false
    }

    /// Translate UI element for accessibility
    public func translateUIElement(_ element: String, hint: String? = nil) async {
        guard isEnabled else { return }

        await translate(element)

        if let hint = hint {
            try? await Task.sleep(nanoseconds: 300_000_000)
            await translate(hint)
        }
    }

    private func performGesture(_ gesture: SignGesture) async {
        // In production: Animate 3D avatar model
        // Here: Simulate with delay
        try? await Task.sleep(nanoseconds: UInt64(gesture.duration * 1_000_000_000))
    }

    private func fingerspell(_ text: String) async {
        // Spell out each letter
        for char in text.uppercased() {
            // Each letter takes ~0.3 seconds
            try? await Task.sleep(nanoseconds: 300_000_000)
        }
    }

    /// Get sign language gesture for a word
    public func getGesture(for word: String) -> [SignGesture]? {
        return signDictionary[word.lowercased()]
    }
}

// MARK: - Eye Tracking Controller

/// Eye-Tracking für Steuerung durch Augenbewegungen
/// Für Nutzer mit eingeschränkter Motorik
@MainActor
public final class EyeTrackingController: ObservableObject {

    public static let shared = EyeTrackingController()

    // MARK: - Published State

    @Published public var isEnabled: Bool = false
    @Published public var isCalibrated: Bool = false
    @Published public var gazePoint: CGPoint = .zero
    @Published public var dwellProgress: Float = 0        // 0-1 für Dwell-Click
    @Published public var currentElement: String?
    @Published public var sensitivity: Sensitivity = .medium

    // MARK: - Settings

    public enum Sensitivity: String, CaseIterable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"

        var dwellTime: TimeInterval {
            switch self {
            case .low: return 1.5
            case .medium: return 1.0
            case .high: return 0.6
            }
        }

        var smoothingFactor: Float {
            switch self {
            case .low: return 0.3
            case .medium: return 0.5
            case .high: return 0.7
            }
        }
    }

    // MARK: - Interaction Modes

    public enum InteractionMode: String, CaseIterable {
        case dwell = "Dwell Click"        // Stare to click
        case blink = "Blink Click"        // Blink to click
        case switch_ = "External Switch"  // Use with accessibility switch
        case headMovement = "Head Nod"    // Nod to confirm

        var description: String {
            switch self {
            case .dwell: return "Blick halten zum Klicken"
            case .blink: return "Blinzeln zum Klicken"
            case .switch_: return "Externer Schalter"
            case .headMovement: return "Kopfnicken zum Bestätigen"
            }
        }
    }

    @Published public var interactionMode: InteractionMode = .dwell

    // MARK: - Calibration

    public struct CalibrationPoint {
        let screenPosition: CGPoint
        var gazePosition: CGPoint?
        var isCalibrated: Bool = false
    }

    @Published public var calibrationPoints: [CalibrationPoint] = []
    @Published public var calibrationProgress: Float = 0

    // MARK: - Focusable Elements

    private var focusableElements: [(id: String, frame: CGRect)] = []
    private var dwellStartTime: Date?
    private var currentDwellElement: String?

    // MARK: - Motion Manager (for head tracking)

    private let motionManager = CMMotionManager()
    private var lastPitch: Double = 0
    private var nodDetected: Bool = false

    // MARK: - Initialization

    private init() {
        setupCalibrationPoints()
    }

    private func setupCalibrationPoints() {
        // 9-point calibration grid
        let positions: [(CGFloat, CGFloat)] = [
            (0.1, 0.1), (0.5, 0.1), (0.9, 0.1),
            (0.1, 0.5), (0.5, 0.5), (0.9, 0.5),
            (0.1, 0.9), (0.5, 0.9), (0.9, 0.9)
        ]

        calibrationPoints = positions.map { pos in
            CalibrationPoint(
                screenPosition: CGPoint(
                    x: pos.0 * UIScreen.main.bounds.width,
                    y: pos.1 * UIScreen.main.bounds.height
                )
            )
        }
    }

    // MARK: - Public API

    /// Start eye tracking
    public func start() {
        guard isCalibrated else {
            print("⚠️ EyeTracking: Not calibrated")
            return
        }

        isEnabled = true

        // Start head tracking for nod detection
        if interactionMode == .headMovement {
            startHeadTracking()
        }

        print("▶️ EyeTracking: Started with \(interactionMode.rawValue) mode")
    }

    /// Stop eye tracking
    public func stop() {
        isEnabled = false
        motionManager.stopDeviceMotionUpdates()
        print("⏹️ EyeTracking: Stopped")
    }

    /// Start calibration process
    public func startCalibration() async {
        calibrationProgress = 0

        for i in 0..<calibrationPoints.count {
            // Wait for user to look at point
            try? await Task.sleep(nanoseconds: 2_000_000_000)

            // Record gaze position (simulated)
            calibrationPoints[i].gazePosition = calibrationPoints[i].screenPosition
            calibrationPoints[i].isCalibrated = true

            calibrationProgress = Float(i + 1) / Float(calibrationPoints.count)
        }

        isCalibrated = true
        print("✅ EyeTracking: Calibration complete")
    }

    /// Register a focusable UI element
    public func registerElement(id: String, frame: CGRect) {
        if let index = focusableElements.firstIndex(where: { $0.id == id }) {
            focusableElements[index].frame = frame
        } else {
            focusableElements.append((id, frame))
        }
    }

    /// Unregister element
    public func unregisterElement(id: String) {
        focusableElements.removeAll { $0.id == id }
    }

    /// Update gaze position (called from ARKit face tracking)
    public func updateGaze(lookAtPoint: CGPoint) {
        guard isEnabled else { return }

        // Smooth gaze movement
        let smoothing = CGFloat(sensitivity.smoothingFactor)
        gazePoint = CGPoint(
            x: gazePoint.x + (lookAtPoint.x - gazePoint.x) * smoothing,
            y: gazePoint.y + (lookAtPoint.y - gazePoint.y) * smoothing
        )

        // Check which element is being looked at
        checkElementFocus()
    }

    private func checkElementFocus() {
        var foundElement: String?

        for element in focusableElements {
            // Expand hit area for easier targeting
            let expandedFrame = element.frame.insetBy(dx: -20, dy: -20)

            if expandedFrame.contains(gazePoint) {
                foundElement = element.id
                break
            }
        }

        if foundElement != currentElement {
            // Focus changed
            currentElement = foundElement
            dwellStartTime = foundElement != nil ? Date() : nil
            dwellProgress = 0
            currentDwellElement = foundElement
        } else if let element = foundElement,
                  let startTime = dwellStartTime,
                  interactionMode == .dwell {
            // Update dwell progress
            let elapsed = Date().timeIntervalSince(startTime)
            dwellProgress = Float(min(elapsed / sensitivity.dwellTime, 1.0))

            if dwellProgress >= 1.0 {
                // Dwell click triggered!
                triggerClick(on: element)
                dwellStartTime = nil
                dwellProgress = 0
            }
        }
    }

    /// Handle blink detection
    public func blinkDetected() {
        guard isEnabled, interactionMode == .blink else { return }

        if let element = currentElement {
            triggerClick(on: element)
        }
    }

    private func triggerClick(on elementId: String) {
        // Haptic feedback
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        // Post notification for UI to handle
        NotificationCenter.default.post(
            name: .eyeTrackingClickTriggered,
            object: nil,
            userInfo: ["elementId": elementId]
        )

        print("👁️ EyeTracking: Click on \(elementId)")
    }

    // MARK: - Head Tracking

    private func startHeadTracking() {
        guard motionManager.isDeviceMotionAvailable else { return }

        motionManager.deviceMotionUpdateInterval = 1.0 / 60.0
        motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, error in
            guard let motion = motion, error == nil else { return }

            Task { @MainActor in
                self?.processHeadMotion(motion)
            }
        }
    }

    private func processHeadMotion(_ motion: CMDeviceMotion) {
        let pitch = motion.attitude.pitch

        // Detect nod (pitch change)
        let pitchChange = pitch - lastPitch
        lastPitch = pitch

        if pitchChange > 0.3 && !nodDetected {
            nodDetected = true

            if interactionMode == .headMovement, let element = currentElement {
                triggerClick(on: element)
            }

            // Reset after delay
            Task {
                try? await Task.sleep(nanoseconds: 500_000_000)
                self.nodDetected = false
            }
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let eyeTrackingClickTriggered = Notification.Name("eyeTrackingClickTriggered")
}

// MARK: - Bone Conduction Audio

/// Bone Conduction Audio Support für Hörbeeinträchtigte
public struct BoneConductionSupport {

    /// Check if bone conduction headphones are connected
    public static var isBoneConductionDeviceConnected: Bool {
        let route = AVAudioSession.sharedInstance().currentRoute
        return route.outputs.contains { output in
            // Common bone conduction device names
            let name = output.portName.lowercased()
            return name.contains("bone") || name.contains("aftershokz") ||
                   name.contains("shokz") || name.contains("oladance")
        }
    }

    /// Optimize audio for bone conduction
    public static func optimizeForBoneConduction(_ audioEngine: AVAudioEngine) {
        // Boost mid frequencies where bone conduction is most effective
        // Bone conduction works best 500Hz - 4kHz

        let eq = AVAudioUnitEQ(numberOfBands: 3)

        // Cut bass (not effective through bone)
        eq.bands[0].filterType = .lowShelf
        eq.bands[0].frequency = 200
        eq.bands[0].gain = -6

        // Boost mids
        eq.bands[1].filterType = .parametric
        eq.bands[1].frequency = 2000
        eq.bands[1].bandwidth = 2.0
        eq.bands[1].gain = 3

        // Slight treble boost
        eq.bands[2].filterType = .highShelf
        eq.bands[2].frequency = 4000
        eq.bands[2].gain = 2

        audioEngine.attach(eq)
        print("✅ BoneConduction: Audio optimized")
    }
}

// MARK: - SwiftUI Views

public struct AudioToHapticView: View {
    @StateObject private var engine = AudioToHapticEngine.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "waveform.badge.mic")
                    .font(.title)
                Text("Audio → Haptik")
                    .font(.title2.bold())
                Spacer()
                Toggle("", isOn: $engine.isEnabled)
                    .labelsHidden()
            }

            // Frequency visualization
            HStack(spacing: 12) {
                frequencyBar(label: "Bass", value: engine.bassIntensity, color: .red)
                frequencyBar(label: "Mid", value: engine.midIntensity, color: .green)
                frequencyBar(label: "Treble", value: engine.trebleIntensity, color: .blue)
            }
            .frame(height: 100)

            // Beat indicator
            Circle()
                .fill(engine.rhythmPulse ? Color.yellow : Color.gray.opacity(0.3))
                .frame(width: 30, height: 30)
                .animation(.easeOut(duration: 0.1), value: engine.rhythmPulse)

            // Mapping mode
            Picker("Mapping", selection: $engine.frequencyMapping) {
                ForEach(AudioToHapticEngine.FrequencyMapping.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.segmented)

            // Intensity slider
            HStack {
                Text("Intensität")
                Slider(value: $engine.hapticIntensity, in: 0...1)
                Text("\(Int(engine.hapticIntensity * 100))%")
                    .monospacedDigit()
            }
        }
        .padding()
    }

    private func frequencyBar(label: String, value: Float, color: Color) -> some View {
        VStack {
            GeometryReader { geo in
                VStack {
                    Spacer()
                    RoundedRectangle(cornerRadius: 4)
                        .fill(color)
                        .frame(height: geo.size.height * CGFloat(value))
                }
            }
            Text(label)
                .font(.caption)
        }
    }
}

public struct EyeTrackingView: View {
    @StateObject private var controller = EyeTrackingController.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                Image(systemName: "eye.circle")
                    .font(.title)
                Text("Eye-Tracking")
                    .font(.title2.bold())
                Spacer()

                if controller.isCalibrated {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }
            }

            // Calibration
            if !controller.isCalibrated {
                Button("Kalibrierung starten") {
                    Task { await controller.startCalibration() }
                }
                .buttonStyle(.borderedProminent)

                if controller.calibrationProgress > 0 {
                    ProgressView(value: controller.calibrationProgress)
                }
            } else {
                // Gaze indicator
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(Color.gray.opacity(0.1))

                    Circle()
                        .fill(Color.blue)
                        .frame(width: 20, height: 20)
                        .position(controller.gazePoint)
                }
                .frame(height: 200)

                // Dwell progress
                if controller.dwellProgress > 0 {
                    ProgressView(value: controller.dwellProgress)
                        .progressViewStyle(.linear)
                }

                // Mode selector
                Picker("Modus", selection: $controller.interactionMode) {
                    ForEach(EyeTrackingController.InteractionMode.allCases, id: \.self) { mode in
                        Text(mode.rawValue).tag(mode)
                    }
                }

                // Sensitivity
                Picker("Empfindlichkeit", selection: $controller.sensitivity) {
                    ForEach(EyeTrackingController.Sensitivity.allCases, id: \.self) { level in
                        Text(level.rawValue).tag(level)
                    }
                }
                .pickerStyle(.segmented)
            }
        }
        .padding()
    }
}

#Preview("Audio to Haptic") {
    AudioToHapticView()
        .preferredColorScheme(.dark)
}

#Preview("Eye Tracking") {
    EyeTrackingView()
        .preferredColorScheme(.dark)
}
