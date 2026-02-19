// BodyScanResonanceEngine.swift
// Echoelmusic
//
// Body scan resonance system for targeted wellness sessions.
// Uses iPhone/iPad camera + Vision body pose detection + EVM micro-movement
// analysis to map body regions to frequency-based sound/haptic/visual responses.
//
// DISCLAIMER: This is a WELLNESS and CREATIVE tool only.
// NOT a medical device. No medical, diagnostic, or therapeutic claims.
// For relaxation, wellness exploration, and creative sound design purposes.
// Consult healthcare professionals for any health concerns.
//
// Created by Echoelmusic Team
// Copyright © 2026 Echoelmusic. All rights reserved.

import Foundation
import Combine
import AVFoundation
import Accelerate
#if canImport(Vision)
import Vision
#endif
#if canImport(CoreHaptics)
import CoreHaptics
#endif

// MARK: - Body Region

/// Body regions detectable via Vision body pose
public enum BodyRegion: String, CaseIterable, Identifiable, Codable, Sendable {
    case head = "Head"
    case neck = "Neck"
    case chest = "Chest"
    case abdomen = "Abdomen"
    case leftShoulder = "Left Shoulder"
    case rightShoulder = "Right Shoulder"
    case leftArm = "Left Arm"
    case rightArm = "Right Arm"
    case leftHand = "Left Hand"
    case rightHand = "Right Hand"
    case leftHip = "Left Hip"
    case rightHip = "Right Hip"
    case leftLeg = "Left Leg"
    case rightLeg = "Right Leg"

    public var id: String { rawValue }

    /// System icon for body region
    public var icon: String {
        switch self {
        case .head: return "brain.head.profile"
        case .neck: return "person.bust"
        case .chest: return "heart.fill"
        case .abdomen: return "stomach"
        case .leftShoulder, .rightShoulder: return "figure.arms.open"
        case .leftArm, .rightArm: return "hand.raised.fill"
        case .leftHand, .rightHand: return "hand.point.up.fill"
        case .leftHip, .rightHip: return "figure.stand"
        case .leftLeg, .rightLeg: return "figure.walk"
        }
    }

    /// Evidence-based resonance frequency range (Hz) for wellness exploration
    /// References: Rubin et al. 2006, Iaccarino et al. 2016, Judex & Rubin 2010
    public var resonanceRange: (min: Double, max: Double) {
        switch self {
        case .head: return (38.0, 42.0)       // Gamma entrainment (Iaccarino 2016)
        case .neck: return (35.0, 45.0)       // Muscle/tissue range
        case .chest: return (30.0, 40.0)      // Thoracic resonance
        case .abdomen: return (25.0, 35.0)    // Abdominal tissue
        case .leftShoulder, .rightShoulder: return (35.0, 50.0)  // Joint/bone
        case .leftArm, .rightArm: return (40.0, 50.0)   // Bone/muscle (Rubin 2006)
        case .leftHand, .rightHand: return (30.0, 45.0)  // Soft tissue
        case .leftHip, .rightHip: return (35.0, 45.0)    // Large joint
        case .leftLeg, .rightLeg: return (35.0, 50.0)    // Long bone (Judex 2010)
        }
    }

    /// Primary wellness frequency for this region (Hz)
    public var primaryFrequency: Double {
        let range = resonanceRange
        return (range.min + range.max) / 2.0
    }

    /// Recommended haptic pattern type
    public var hapticPattern: TapticPatternType {
        switch self {
        case .head: return .coherent
        case .neck, .chest: return .breathing
        case .abdomen: return .ramping
        case .leftShoulder, .rightShoulder: return .pulsed
        case .leftArm, .rightArm, .leftLeg, .rightLeg: return .continuous
        case .leftHand, .rightHand: return .pulsed
        case .leftHip, .rightHip: return .continuous
        }
    }

    /// Educational reference for this body region's frequency
    public var educationalNote: String {
        switch self {
        case .head:
            return "40 Hz gamma entrainment explored in neuroscience research (Iaccarino et al. 2016)"
        case .neck, .chest, .abdomen:
            return "Tissue resonance frequencies based on mechanical vibration research"
        case .leftShoulder, .rightShoulder, .leftHip, .rightHip:
            return "Joint wellness frequencies based on mechanical signal research (Rubin 2006)"
        case .leftArm, .rightArm, .leftLeg, .rightLeg:
            return "Bone adaptation research on low-magnitude mechanical signals (Judex & Rubin 2010)"
        case .leftHand, .rightHand:
            return "Soft tissue frequencies for relaxation and circulation"
        }
    }
}

// MARK: - Body Scan Result

/// Result of a body scan analysis
public struct BodyScanResult: Codable, Sendable {
    public let timestamp: Date
    public let region: BodyRegion
    public let detectedFrequencies: [Double]
    public let dominantFrequency: Double
    public let amplitude: Double
    public let coherenceScore: Double
    public let qualityScore: Double

    /// How well the detected frequency aligns with the region's expected range
    public var alignmentScore: Double {
        let range = region.resonanceRange
        if dominantFrequency >= range.min && dominantFrequency <= range.max {
            let center = (range.min + range.max) / 2.0
            let distance = abs(dominantFrequency - center)
            let maxDist = (range.max - range.min) / 2.0
            return 1.0 - (distance / maxDist) * 0.5
        }
        return max(0, 0.3 - abs(dominantFrequency - region.primaryFrequency) * 0.01)
    }
}

// MARK: - Body Scan Session

/// Complete body scan session with multiple region results
public struct BodyScanSession: Codable, Sendable {
    public let id: UUID
    public let startTime: Date
    public var endTime: Date?
    public var regionResults: [BodyRegion: BodyScanResult]
    public var activeRegion: BodyRegion?
    public var overallCoherence: Double

    public init() {
        self.id = UUID()
        self.startTime = Date()
        self.regionResults = [:]
        self.overallCoherence = 0
    }

    /// Average coherence across all scanned regions
    public var averageCoherence: Double {
        guard !regionResults.isEmpty else { return 0 }
        return regionResults.values.map(\.coherenceScore).reduce(0, +) / Double(regionResults.count)
    }

    /// Regions that haven't been scanned yet
    public var unscanedRegions: [BodyRegion] {
        BodyRegion.allCases.filter { !regionResults.keys.contains($0) }
    }

    enum CodingKeys: String, CodingKey {
        case id, startTime, endTime, overallCoherence
    }
}

// MARK: - Body Scan Resonance Engine

/// Main engine for body scan resonance wellness sessions.
/// Integrates camera-based body pose detection with targeted frequency responses.
@MainActor
public final class BodyScanResonanceEngine: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var isScanning: Bool = false
    @Published public private(set) var currentRegion: BodyRegion?
    @Published public private(set) var detectedRegions: [BodyRegion] = []
    @Published public private(set) var scanResults: [BodyRegion: BodyScanResult] = [:]
    @Published public private(set) var currentCoherence: Double = 0.0
    @Published public private(set) var bodyPoseConfidence: Double = 0.0
    @Published public private(set) var isStimulating: Bool = false
    @Published public private(set) var errorMessage: String?
    @Published public var selectedRegion: BodyRegion?
    @Published public var autoScan: Bool = true

    /// Detected body joint positions (normalized 0-1) for visualization
    @Published public private(set) var jointPositions: [BodyRegion: CGPoint] = [:]

    // MARK: - Sub-Engines

    private let evmEngine = EVMAnalysisEngine()
    private let stimulationEngine = TapticStimulationEngine()
    private let wellnessEngine = BiophysicalWellnessEngine()

    // MARK: - Vision

    #if canImport(Vision)
    private lazy var bodyPoseRequest: VNDetectHumanBodyPoseRequest = {
        let request = VNDetectHumanBodyPoseRequest()
        return request
    }()
    #endif

    // MARK: - Camera

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let captureQueue = DispatchQueue(label: "com.echoelmusic.bodyscan.capture", qos: .userInteractive)
    private let analysisQueue = DispatchQueue(label: "com.echoelmusic.bodyscan.analysis", qos: .userInitiated)

    // MARK: - Session

    private var currentSession = BodyScanSession()
    private var updateTimer: DispatchSourceTimer?
    private var sessionTimer: Timer?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Audio

    private var audioGenerator: BiophysicalAudioGenerator?

    // MARK: - Safety

    public static let maxSessionDuration: TimeInterval = 900 // 15 min
    public static let maxStimulationIntensity: Double = 0.8
    public static let cooldownDuration: TimeInterval = 300 // 5 min

    // MARK: - Disclaimer

    @Published public var disclaimerAcknowledged: Bool = false

    public static let disclaimer = """
    BODY SCAN RESONANCE — WELLNESS TOOL

    This tool uses your device camera to detect body regions and explore
    frequency-based wellness responses. It is designed for:

    • Relaxation and stress reduction
    • Creative sound design and exploration
    • Wellness-focused frequency exploration
    • Bio-reactive music and visual experiences

    IMPORTANT:
    • NOT a medical device or diagnostic tool
    • No health, medical, or therapeutic claims
    • Does not diagnose, treat, or cure any condition
    • Results are subjective and vary by individual
    • Consult healthcare professionals for health concerns
    • Do not use if you have epilepsy, pacemakers, or seizure disorders

    Session limited to 15 minutes for safety.
    Camera data is processed on-device only (no cloud upload).
    """

    // MARK: - Initialization

    public init() {
        audioGenerator = BiophysicalAudioGenerator()
    }

    // MARK: - Public API

    /// Acknowledge disclaimer before use
    public func acknowledgeDisclaimer() {
        disclaimerAcknowledged = true
    }

    /// Start body scan session
    public func startScan() async throws {
        guard disclaimerAcknowledged else {
            throw BiophysicalError.disclaimerNotAcknowledged
        }
        guard !isScanning else { return }

        // Request camera access
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            guard granted else { throw BiophysicalError.cameraAccessDenied }
        } else if status != .authorized {
            throw BiophysicalError.cameraAccessDenied
        }

        try setupCamera()

        currentSession = BodyScanSession()
        isScanning = true
        scanResults = [:]
        detectedRegions = []
        jointPositions = [:]

        captureSession?.startRunning()
        startUpdateLoop()
        startSessionTimer()

        log.info("Body scan session started")
    }

    /// Stop scan session
    public func stopScan() async {
        isScanning = false
        currentSession.endTime = Date()

        captureSession?.stopRunning()
        stopUpdateLoop()
        stopSessionTimer()
        await stopStimulation()

        log.info("Body scan session stopped")
    }

    /// Focus on a specific body region for targeted wellness
    public func focusRegion(_ region: BodyRegion) async throws {
        selectedRegion = region
        currentRegion = region

        if isStimulating {
            await stopStimulation()
        }

        try await startStimulation(for: region)
    }

    /// Stop stimulation for current region
    public func stopCurrentStimulation() async {
        await stopStimulation()
    }

    // MARK: - Camera Setup

    private func setupCamera() throws {
        let session = AVCaptureSession()
        session.sessionPreset = .medium

        // Use back camera for body scan (wider FOV)
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
              ?? AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw BiophysicalError.sensorNotAvailable
        }

        try camera.lockForConfiguration()
        camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: 30)
        camera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: 30)
        camera.unlockForConfiguration()

        let input = try AVCaptureDeviceInput(device: camera)
        if session.canAddInput(input) { session.addInput(input) }

        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA]
        output.setSampleBufferDelegate(self, queue: captureQueue)
        output.alwaysDiscardsLateVideoFrames = true
        if session.canAddOutput(output) { session.addOutput(output) }

        self.captureSession = session
        self.videoOutput = output
    }

    // MARK: - Body Pose Detection

    #if canImport(Vision)
    private func detectBodyPose(in pixelBuffer: CVPixelBuffer) {
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])

        do {
            try handler.perform([bodyPoseRequest])

            guard let observation = bodyPoseRequest.results?.first else {
                DispatchQueue.main.async { [weak self] in
                    self?.bodyPoseConfidence = 0
                    self?.detectedRegions = []
                }
                return
            }

            let joints = extractJointPositions(from: observation)
            let regions = identifyRegions(from: joints)

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.bodyPoseConfidence = Double(observation.confidence)
                self.jointPositions = joints
                self.detectedRegions = regions

                // Auto-scan: focus on nearest detected region
                if self.autoScan, self.selectedRegion == nil, let firstRegion = regions.first {
                    self.currentRegion = firstRegion
                }
            }

        } catch {
            log.error("Body pose detection failed: \(error)")
        }
    }

    private func extractJointPositions(from observation: VNHumanBodyPoseObservation) -> [BodyRegion: CGPoint] {
        var positions: [BodyRegion: CGPoint] = [:]

        let jointMap: [(VNHumanBodyPoseObservation.JointName, BodyRegion)] = [
            (.nose, .head),
            (.neck, .neck),
            (.leftShoulder, .leftShoulder),
            (.rightShoulder, .rightShoulder),
            (.leftElbow, .leftArm),
            (.rightElbow, .rightArm),
            (.leftWrist, .leftHand),
            (.rightWrist, .rightHand),
            (.leftHip, .leftHip),
            (.rightHip, .rightHip),
            (.leftKnee, .leftLeg),
            (.rightKnee, .rightLeg),
        ]

        for (jointName, region) in jointMap {
            if let point = try? observation.recognizedPoint(jointName),
               point.confidence > 0.3 {
                positions[region] = CGPoint(x: point.location.x, y: 1.0 - point.location.y)
            }
        }

        // Synthesize chest/abdomen from shoulders and hips
        if let ls = positions[.leftShoulder], let rs = positions[.rightShoulder] {
            let chestCenter = CGPoint(x: (ls.x + rs.x) / 2, y: (ls.y + rs.y) / 2 + 0.05)
            positions[.chest] = chestCenter
        }

        if let lh = positions[.leftHip], let rh = positions[.rightHip],
           let ls = positions[.leftShoulder], let rs = positions[.rightShoulder] {
            let hipCenter = CGPoint(x: (lh.x + rh.x) / 2, y: (lh.y + rh.y) / 2)
            let shoulderCenter = CGPoint(x: (ls.x + rs.x) / 2, y: (ls.y + rs.y) / 2)
            let abdomenCenter = CGPoint(
                x: (hipCenter.x + shoulderCenter.x) / 2,
                y: (hipCenter.y + shoulderCenter.y) / 2
            )
            positions[.abdomen] = abdomenCenter
        }

        return positions
    }

    private func identifyRegions(from joints: [BodyRegion: CGPoint]) -> [BodyRegion] {
        return joints.keys.sorted { $0.rawValue < $1.rawValue }
    }
    #endif

    // MARK: - Stimulation

    private func startStimulation(for region: BodyRegion) async throws {
        isStimulating = true

        let frequency = region.primaryFrequency
        let intensity = min(region.resonanceRange.max * 0.015, Self.maxStimulationIntensity)

        // Start haptic stimulation
        try await stimulationEngine.startHapticPattern(
            frequency: frequency,
            intensity: intensity
        )

        // Start audio tone (low amplitude — creative/wellness, not medical)
        audioGenerator?.startTone(frequency: frequency, amplitude: 0.25)

        log.info("Stimulation started for \(region.rawValue) at \(frequency)Hz")
    }

    private func stopStimulation() async {
        isStimulating = false
        stimulationEngine.stopHaptics()
        audioGenerator?.stopTone()
    }

    // MARK: - Update Loop

    private func startUpdateLoop() {
        updateTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(flags: [], queue: analysisQueue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(100), leeway: .milliseconds(10))
        timer.setEventHandler { [weak self] in
            DispatchQueue.main.async { [weak self] in
                self?.updateScanState()
            }
        }
        timer.resume()
        updateTimer = timer
    }

    private func stopUpdateLoop() {
        updateTimer?.cancel()
        updateTimer = nil
    }

    private func updateScanState() {
        guard isScanning else { return }

        // Update coherence from EVM results
        if let evmResult = evmEngine.latestResult {
            currentCoherence = evmResult.qualityScore

            if let region = currentRegion {
                let result = BodyScanResult(
                    timestamp: Date(),
                    region: region,
                    detectedFrequencies: evmResult.detectedFrequencies,
                    dominantFrequency: evmResult.detectedFrequencies.first ?? region.primaryFrequency,
                    amplitude: evmResult.spatialAmplitudes.first ?? 0,
                    coherenceScore: evmResult.qualityScore,
                    qualityScore: evmResult.qualityScore
                )
                scanResults[region] = result
                currentSession.regionResults[region] = result
            }
        }

        currentSession.overallCoherence = currentSession.averageCoherence
    }

    // MARK: - Session Timer

    private func startSessionTimer() {
        sessionTimer = Timer.scheduledTimer(withTimeInterval: Self.maxSessionDuration, repeats: false) { [weak self] _ in
            Task { @MainActor [weak self] in
                await self?.stopScan()
                self?.errorMessage = "Session completed (15 minute safety limit reached)"
            }
        }
    }

    private func stopSessionTimer() {
        sessionTimer?.invalidate()
        sessionTimer = nil
    }

    // MARK: - Cleanup

    deinit {
        sessionTimer?.invalidate()
        updateTimer?.cancel()
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension BodyScanResonanceEngine: AVCaptureVideoDataOutputSampleBufferDelegate {
    nonisolated public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else { return }

        #if canImport(Vision)
        // Run body pose detection on capture queue
        let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, orientation: .up, options: [:])
        let request = VNDetectHumanBodyPoseRequest()

        do {
            try handler.perform([request])

            guard let observation = request.results?.first else {
                DispatchQueue.main.async { [weak self] in
                    self?.bodyPoseConfidence = 0
                    self?.detectedRegions = []
                }
                return
            }

            // Extract joints on capture queue
            var positions: [BodyRegion: CGPoint] = [:]
            let jointMap: [(VNHumanBodyPoseObservation.JointName, BodyRegion)] = [
                (.nose, .head), (.neck, .neck),
                (.leftShoulder, .leftShoulder), (.rightShoulder, .rightShoulder),
                (.leftElbow, .leftArm), (.rightElbow, .rightArm),
                (.leftWrist, .leftHand), (.rightWrist, .rightHand),
                (.leftHip, .leftHip), (.rightHip, .rightHip),
                (.leftKnee, .leftLeg), (.rightKnee, .rightLeg),
            ]

            for (jointName, region) in jointMap {
                if let point = try? observation.recognizedPoint(jointName),
                   point.confidence > 0.3 {
                    positions[region] = CGPoint(x: point.location.x, y: 1.0 - point.location.y)
                }
            }

            // Synthesize chest/abdomen
            if let ls = positions[.leftShoulder], let rs = positions[.rightShoulder] {
                positions[.chest] = CGPoint(x: (ls.x + rs.x) / 2, y: (ls.y + rs.y) / 2 + 0.05)
            }
            if let lh = positions[.leftHip], let rh = positions[.rightHip],
               let ls = positions[.leftShoulder], let rs = positions[.rightShoulder] {
                let hip = CGPoint(x: (lh.x + rh.x) / 2, y: (lh.y + rh.y) / 2)
                let shoulder = CGPoint(x: (ls.x + rs.x) / 2, y: (ls.y + rs.y) / 2)
                positions[.abdomen] = CGPoint(x: (hip.x + shoulder.x) / 2, y: (hip.y + shoulder.y) / 2)
            }

            let regions = positions.keys.sorted { $0.rawValue < $1.rawValue }
            let confidence = Double(observation.confidence)

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.bodyPoseConfidence = confidence
                self.jointPositions = positions
                self.detectedRegions = regions

                if self.autoScan, self.selectedRegion == nil, let first = regions.first {
                    self.currentRegion = first
                }
            }
        } catch {
            // Silent — pose detection is best-effort
        }
        #endif
    }
}

// MARK: - Preset Generation

extension BodyScanResonanceEngine {

    /// Generate a BiophysicalPreset from body scan results
    public func generatePreset(from region: BodyRegion) -> BiophysicalPreset {
        switch region {
        case .head: return .neuralFocus
        case .neck, .chest: return .relaxation
        case .abdomen: return .circulation
        case .leftShoulder, .rightShoulder, .leftHip, .rightHip: return .boneHarmony
        case .leftArm, .rightArm, .leftLeg, .rightLeg: return .muscleFlow
        case .leftHand, .rightHand: return .circulation
        }
    }

    /// Create a creative sound profile from scan results (for music production use)
    public func generateCreativeSoundProfile(from results: [BodyRegion: BodyScanResult]) -> [String: Any] {
        var profile: [String: Any] = [
            "type": "body_scan_resonance",
            "timestamp": Date().timeIntervalSince1970,
            "disclaimer": "Wellness exploration profile — not medical data"
        ]

        var frequencies: [Double] = []
        var amplitudes: [Double] = []
        var regionNames: [String] = []

        for (region, result) in results.sorted(by: { $0.key.rawValue < $1.key.rawValue }) {
            frequencies.append(result.dominantFrequency)
            amplitudes.append(result.amplitude)
            regionNames.append(region.rawValue)
        }

        profile["frequencies"] = frequencies
        profile["amplitudes"] = amplitudes
        profile["regions"] = regionNames
        profile["coherence"] = results.values.map(\.coherenceScore).reduce(0, +) / Double(max(1, results.count))

        return profile
    }
}

// MARK: - Organ Resonance Reference Data

/// Evidence-based organ resonance frequencies from peer-reviewed MR Elastography studies.
/// Ported from CoherenceCore shared-types. For EDUCATIONAL and WELLNESS context only.
///
/// Sources: PMC6223825, PMC3066083
/// DISCLAIMER: These are research reference values, NOT diagnostic parameters.
public struct OrganResonanceReference: Identifiable, Codable, Sendable {
    public let id: String
    public let organ: String
    public let clinicalFrequencyHz: Double
    public let frequencyRangeHz: (min: Double, max: Double)
    public let tissueType: String
    public let educationalNote: String
    public let source: String

    enum CodingKeys: String, CodingKey {
        case id, organ, clinicalFrequencyHz, tissueType, educationalNote, source
        case freqMin, freqMax
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(String.self, forKey: .id)
        organ = try c.decode(String.self, forKey: .organ)
        clinicalFrequencyHz = try c.decode(Double.self, forKey: .clinicalFrequencyHz)
        let fMin = try c.decode(Double.self, forKey: .freqMin)
        let fMax = try c.decode(Double.self, forKey: .freqMax)
        frequencyRangeHz = (fMin, fMax)
        tissueType = try c.decode(String.self, forKey: .tissueType)
        educationalNote = try c.decode(String.self, forKey: .educationalNote)
        source = try c.decode(String.self, forKey: .source)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(organ, forKey: .organ)
        try c.encode(clinicalFrequencyHz, forKey: .clinicalFrequencyHz)
        try c.encode(frequencyRangeHz.min, forKey: .freqMin)
        try c.encode(frequencyRangeHz.max, forKey: .freqMax)
        try c.encode(tissueType, forKey: .tissueType)
        try c.encode(educationalNote, forKey: .educationalNote)
        try c.encode(source, forKey: .source)
    }

    init(id: String, organ: String, clinicalFrequencyHz: Double, frequencyRangeHz: (min: Double, max: Double), tissueType: String, educationalNote: String, source: String) {
        self.id = id
        self.organ = organ
        self.clinicalFrequencyHz = clinicalFrequencyHz
        self.frequencyRangeHz = frequencyRangeHz
        self.tissueType = tissueType
        self.educationalNote = educationalNote
        self.source = source
    }

    /// Full evidence-based reference table (from MR Elastography literature)
    public static let referenceTable: [OrganResonanceReference] = [
        OrganResonanceReference(
            id: "liver",
            organ: "Liver",
            clinicalFrequencyHz: 60,
            frequencyRangeHz: (50, 70),
            tissueType: "Parenchymal Organ",
            educationalNote: "MRE clinical frequency for shear modulus measurement (kPa)",
            source: "PMC6223825 — MR Elastography"
        ),
        OrganResonanceReference(
            id: "heart",
            organ: "Heart",
            clinicalFrequencyHz: 110,
            frequencyRangeHz: (80, 140),
            tissueType: "Cardiac Muscle",
            educationalNote: "Myocardial strain measurement via MRE",
            source: "PMC3066083 — MRE Review"
        ),
        OrganResonanceReference(
            id: "spleen",
            organ: "Spleen",
            clinicalFrequencyHz: 100,
            frequencyRangeHz: (80, 120),
            tissueType: "Parenchymal Organ",
            educationalNote: "Spleen stiffness measurement (SSM)",
            source: "PMC6223825"
        ),
        OrganResonanceReference(
            id: "brain",
            organ: "Brain",
            clinicalFrequencyHz: 45,
            frequencyRangeHz: (25, 62.5),
            tissueType: "Neural Tissue",
            educationalNote: "Viscoelasticity measurement for neuroscience research",
            source: "PMC3066083"
        ),
        OrganResonanceReference(
            id: "bone",
            organ: "Bone",
            clinicalFrequencyHz: 40,
            frequencyRangeHz: (35, 50),
            tissueType: "Mineralized Tissue",
            educationalNote: "Low-magnitude mechanical signals for bone adaptation",
            source: "Rubin et al. 2006, Judex & Rubin 2010"
        ),
        OrganResonanceReference(
            id: "muscle",
            organ: "Muscle",
            clinicalFrequencyHz: 47,
            frequencyRangeHz: (45, 50),
            tissueType: "Skeletal Muscle",
            educationalNote: "Mechanical influences on muscle tissue",
            source: "Judex & Rubin 2010"
        ),
        OrganResonanceReference(
            id: "skin",
            organ: "Skin",
            clinicalFrequencyHz: 35,
            frequencyRangeHz: (30, 45),
            tissueType: "Integumentary",
            educationalNote: "Dermal viscoelastic properties",
            source: "Medical ultrasound reference values"
        ),
        OrganResonanceReference(
            id: "cartilage",
            organ: "Cartilage",
            clinicalFrequencyHz: 42,
            frequencyRangeHz: (35, 50),
            tissueType: "Connective Tissue",
            educationalNote: "Joint cartilage mechanical resonance",
            source: "Mechanical vibration research"
        ),
    ]

    /// Tissue acoustic properties for educational reference
    public static let tissueAcousticTable: [(tissue: String, density: Double, soundVelocity: Double, impedance: Double)] = [
        ("Liver", 1050, 1570, 1.65),
        ("Muscle", 1040, 1580, 1.64),
        ("Fat", 925, 1450, 1.34),
        ("Skin", 1100, 1600, 1.76),
        ("Bone", 1900, 4080, 7.75),
        ("Cartilage", 1100, 1660, 1.83),
    ]

    /// Body eigenfrequency range (sitting/standing, FAA Report AM63-30pt11)
    public static let bodyEigenfrequencyRange: ClosedRange<Double> = 1...20

    /// Map a BodyRegion to the closest organ resonance references
    public static func references(for region: BodyRegion) -> [OrganResonanceReference] {
        switch region {
        case .head: return referenceTable.filter { $0.id == "brain" }
        case .chest: return referenceTable.filter { ["heart"].contains($0.id) }
        case .abdomen: return referenceTable.filter { ["liver", "spleen"].contains($0.id) }
        case .neck: return referenceTable.filter { $0.id == "muscle" }
        case .leftShoulder, .rightShoulder, .leftHip, .rightHip:
            return referenceTable.filter { ["bone", "cartilage"].contains($0.id) }
        case .leftArm, .rightArm, .leftLeg, .rightLeg:
            return referenceTable.filter { ["bone", "muscle"].contains($0.id) }
        case .leftHand, .rightHand:
            return referenceTable.filter { ["skin", "cartilage"].contains($0.id) }
        }
    }
}

