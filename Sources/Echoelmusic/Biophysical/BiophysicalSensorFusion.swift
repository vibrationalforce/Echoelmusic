// BiophysicalSensorFusion.swift
// Echoelmusic
//
// Multi-sensor fusion coordinator for biophysical scanning.
// Integrates LiDAR, TrueDepth IR, barometer, IMU, and camera EVM
// with Kalman-filtered state estimation.
//
// Hardware capabilities:
// - LiDAR: 576-point depth grid, 15 Hz (iPad Pro 2020+, iPhone 12 Pro+)
// - TrueDepth: 30,000 IR points, 30 Hz (iPhone X+, iPad Pro 2018+)
// - Barometer: CMAltimeter, ~1 Hz (vibration detection via pressure delta)
// - IMU: Accelerometer 100 Hz, Gyroscope 100 Hz
// - Camera: EVM via RGB, 30-60 fps
//
// DISCLAIMER: Wellness and creative exploration tool only.
// NOT a medical or diagnostic device. No medical claims.
//
// Created by Echoelmusic Team
// Copyright © 2026 Echoelmusic. All rights reserved.

import Foundation
import Combine
import AVFoundation
import Accelerate
#if canImport(ARKit)
import ARKit
#endif
#if canImport(CoreMotion)
import CoreMotion
#endif

// MARK: - Sensor Types

/// Available sensor modalities for biophysical scanning
public enum BiophysicalSensor: String, CaseIterable, Codable, Sendable {
    case lidar = "LiDAR"
    case trueDepth = "TrueDepth IR"
    case barometer = "Barometer"
    case accelerometer = "Accelerometer"
    case gyroscope = "Gyroscope"
    case cameraEVM = "Camera (EVM)"

    /// Sensor sampling rate in Hz
    public var sampleRate: Double {
        switch self {
        case .lidar: return 15.0           // Apple LiDAR max
        case .trueDepth: return 30.0       // TrueDepth depth stream
        case .barometer: return 10.0       // CMAltimeter update rate
        case .accelerometer: return 100.0  // CoreMotion default
        case .gyroscope: return 100.0
        case .cameraEVM: return 30.0       // Standard video rate
        }
    }

    /// Nyquist frequency limit (max detectable freq = sampleRate / 2)
    public var nyquistLimit: Double { sampleRate / 2.0 }

    /// Whether this sensor is suitable for the 35-50 Hz biophysical range
    public var coversTargetRange: Bool {
        nyquistLimit >= 50.0 // Need at least 50 Hz Nyquist for 50 Hz detection
    }
}

// MARK: - Fused Sensor Reading

/// Single timestamped reading from all active sensors
public struct FusedSensorReading: Sendable {
    public let timestamp: TimeInterval  // CACurrentMediaTime
    public let depthMap: DepthMapReading?
    public let inertial: InertialReading?
    public let barometric: BarometricReading?
    public let evmFrequencies: [Double]?
    public let fusedConfidence: Double  // 0-1 Kalman-weighted confidence
}

/// Depth reading from LiDAR or TrueDepth
public struct DepthMapReading: Sendable {
    public let source: BiophysicalSensor  // .lidar or .trueDepth
    public let width: Int
    public let height: Int
    public let depthValues: [Float]       // Depth in meters
    public let confidenceValues: [Float]? // Per-pixel confidence
    public let pointCount: Int
    public let meanDepth: Float
    public let depthVariance: Float       // Micro-movement indicator
}

/// Inertial reading (accelerometer + gyroscope)
public struct InertialReading: Sendable {
    public let acceleration: SIMD3<Float>  // m/s² (gravity removed)
    public let rotationRate: SIMD3<Float>  // rad/s
    public let magnitude: Float            // RMS acceleration
    public let dominantFrequency: Float    // FFT-detected Hz
}

/// Barometric pressure reading for vibration detection
public struct BarometricReading: Sendable {
    public let pressure: Double           // kPa
    public let relativeAltitude: Double   // meters from start
    public let pressureDelta: Double      // Pressure change rate (Pa/s)
    public let detectedVibration: Bool    // True if >threshold delta
}

// MARK: - Kalman Filter State

/// Simple 1D Kalman filter for sensor fusion
struct KalmanFilter1D {
    var estimate: Double = 0
    var errorCovariance: Double = 1.0
    var processNoise: Double = 0.01     // Q - system noise
    var measurementNoise: Double = 0.1  // R - measurement noise

    mutating func update(measurement: Double) -> Double {
        // Predict
        let predictedErrorCov = errorCovariance + processNoise

        // Update
        let kalmanGain = predictedErrorCov / (predictedErrorCov + measurementNoise)
        estimate = estimate + kalmanGain * (measurement - estimate)
        errorCovariance = (1.0 - kalmanGain) * predictedErrorCov

        return estimate
    }
}

// MARK: - LiDAR Depth Scanner

/// LiDAR-based depth scanning using ARKit world tracking.
/// Captures 576-point depth grid at 15 Hz for spatial analysis.
///
/// Nyquist: 15 Hz → max detectable freq = 7.5 Hz (body sway, breathing).
/// NOT suitable for 35-50 Hz bone/muscle detection.
/// Used for: spatial mapping, body contour, structural analysis.
#if canImport(ARKit)
@MainActor
public final class LiDARDepthScanner: NSObject, ObservableObject {

    @Published public private(set) var isScanning = false
    @Published public private(set) var latestDepthMap: DepthMapReading?
    @Published public private(set) var isLiDARAvailable = false

    private var arSession: ARSession?
    private var depthHistory: [Float] = [] // Mean depth over time for frequency analysis
    private let maxHistorySize = 256

    public override init() {
        super.init()
        checkAvailability()
    }

    private func checkAvailability() {
        isLiDARAvailable = ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
    }

    /// Start LiDAR depth scanning
    public func startScanning() throws {
        guard isLiDARAvailable else {
            throw BiophysicalError.sensorNotAvailable
        }

        let config = ARWorldTrackingConfiguration()
        config.frameSemantics = .sceneDepth

        let session = ARSession()
        session.delegate = self
        session.run(config)

        arSession = session
        isScanning = true
        depthHistory = []
    }

    /// Stop scanning
    public func stopScanning() {
        arSession?.pause()
        arSession = nil
        isScanning = false
    }

    deinit {
        // arSession cleanup handled by stopScanning() — deinit is nonisolated in Swift 6
    }
}

extension LiDARDepthScanner: ARSessionDelegate {
    nonisolated public func session(_ session: ARSession, didUpdate frame: ARFrame) {
        guard let depthMap = frame.sceneDepth?.depthMap else { return }

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return }
        let floatBuffer = baseAddress.assumingMemoryBound(to: Float32.self)
        let count = width * height

        // Extract depth values
        var depths = [Float](repeating: 0, count: count)
        for i in 0..<count { depths[i] = floatBuffer[i] }

        // Calculate statistics
        var mean: Float = 0
        vDSP_meanv(depths, 1, &mean, vDSP_Length(count))
        var variance: Float = 0
        vDSP_measqv(depths, 1, &variance, vDSP_Length(count))
        variance -= mean * mean

        // Extract confidence if available
        var confidenceValues: [Float]?
        if let confidenceMap = frame.sceneDepth?.confidenceMap {
            CVPixelBufferLockBaseAddress(confidenceMap, .readOnly)
            defer { CVPixelBufferUnlockBaseAddress(confidenceMap, .readOnly) }
            if let confBase = CVPixelBufferGetBaseAddress(confidenceMap) {
                let confBuffer = confBase.assumingMemoryBound(to: UInt8.self)
                let confCount = CVPixelBufferGetWidth(confidenceMap) * CVPixelBufferGetHeight(confidenceMap)
                confidenceValues = (0..<confCount).map { Float(confBuffer[$0]) / 2.0 } // 0,1,2 → 0, 0.5, 1.0
            }
        }

        let reading = DepthMapReading(
            source: .lidar,
            width: width,
            height: height,
            depthValues: depths,
            confidenceValues: confidenceValues,
            pointCount: count,
            meanDepth: mean,
            depthVariance: variance
        )

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.latestDepthMap = reading
            self.depthHistory.append(mean)
            if self.depthHistory.count > self.maxHistorySize {
                self.depthHistory.removeFirst()
            }
        }
    }
}
#endif

// MARK: - TrueDepth Depth Extractor

/// Extracts depth data from TrueDepth camera's 30,000 IR dot projector.
/// Uses AVCaptureDepthDataOutput for real-time depth maps at 30 Hz.
///
/// Nyquist: 30 Hz → max detectable freq = 15 Hz (breathing, micro-sway).
/// Used for: near-field skin surface analysis, tissue topology.
#if os(iOS)
@MainActor
public final class TrueDepthExtractor: NSObject, ObservableObject {

    @Published public private(set) var isCapturing = false
    @Published public private(set) var latestDepthMap: DepthMapReading?
    @Published public private(set) var depthVarianceHistory: [Float] = []

    private var captureSession: AVCaptureSession?
    private var depthOutput: AVCaptureDepthDataOutput?
    private let captureQueue = DispatchQueue(label: "com.echoelmusic.truedepth", qos: .userInteractive)
    private let maxHistorySize = 256

    /// Start TrueDepth depth capture
    public func startCapture() throws {
        let session = AVCaptureSession()
        session.sessionPreset = .photo

        // Find TrueDepth camera
        guard let device = AVCaptureDevice.default(.builtInTrueDepthCamera, for: .video, position: .front) else {
            throw BiophysicalError.sensorNotAvailable
        }

        let input = try AVCaptureDeviceInput(device: device)
        if session.canAddInput(input) { session.addInput(input) }

        // Depth data output
        let depthOutput = AVCaptureDepthDataOutput()
        depthOutput.isFilteringEnabled = true // Smooth depth data
        depthOutput.setDelegate(self, callbackQueue: captureQueue)
        if session.canAddOutput(depthOutput) { session.addOutput(depthOutput) }

        // Also need video output for synchronized depth
        let videoOutput = AVCaptureVideoDataOutput()
        if session.canAddOutput(videoOutput) { session.addOutput(videoOutput) }

        // Configure depth format
        if let connection = depthOutput.connection(with: .depthData) {
            connection.isEnabled = true
        }

        self.captureSession = session
        self.depthOutput = depthOutput

        session.startRunning()
        isCapturing = true
    }

    /// Stop depth capture
    public func stopCapture() {
        captureSession?.stopRunning()
        captureSession = nil
        depthOutput = nil
        isCapturing = false
    }

    deinit {
        // captureSession cleanup handled by stopCapture() — deinit is nonisolated in Swift 6
    }
}

extension TrueDepthExtractor: AVCaptureDepthDataOutputDelegate {
    nonisolated public func depthDataOutput(
        _ output: AVCaptureDepthDataOutput,
        didOutput depthData: AVDepthData,
        timestamp: CMTime,
        connection: AVCaptureConnection
    ) {
        // Convert to float32 depth map
        let converted = depthData.converting(toDepthDataType: kCVPixelFormatType_DepthFloat32)
        let depthMap = converted.depthDataMap

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return }
        let floatBuffer = baseAddress.assumingMemoryBound(to: Float32.self)
        let count = width * height

        var depths = [Float](repeating: 0, count: count)
        for i in 0..<count { depths[i] = floatBuffer[i] }

        // Statistics
        var mean: Float = 0
        vDSP_meanv(depths, 1, &mean, vDSP_Length(count))
        var variance: Float = 0
        vDSP_measqv(depths, 1, &variance, vDSP_Length(count))
        variance -= mean * mean

        let reading = DepthMapReading(
            source: .trueDepth,
            width: width,
            height: height,
            depthValues: depths,
            confidenceValues: nil,
            pointCount: count,
            meanDepth: mean,
            depthVariance: variance
        )

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.latestDepthMap = reading
            self.depthVarianceHistory.append(variance)
            if self.depthVarianceHistory.count > self.maxHistorySize {
                self.depthVarianceHistory.removeFirst()
            }
        }
    }
}
#endif // os(iOS)

// MARK: - Barometer Vibration Detector

/// Detects vibrations via barometric pressure changes.
/// Research shows CMAltimeter can detect speaker vibrations and touch events.
///
/// Sampling: ~10 Hz effective (CMAltimeter update interval).
/// Nyquist: 5 Hz max — detects breathing, body sway, infrasound.
/// Used for: supplementary low-frequency vibration confirmation.
#if canImport(CoreMotion)
@MainActor
public final class BarometerVibrationDetector: ObservableObject {

    @Published public private(set) var isActive = false
    @Published public private(set) var latestReading: BarometricReading?
    @Published public private(set) var vibrationDetected = false
    @Published public private(set) var pressureHistory: [Double] = []

    private let altimeter = CMAltimeter()
    private var baselinePressure: Double?
    private var lastPressure: Double?
    private let vibrationThreshold: Double = 0.005 // kPa delta threshold
    private let maxHistorySize = 256

    /// Check if barometer is available
    public var isAvailable: Bool {
        CMAltimeter.isRelativeAltitudeAvailable()
    }

    /// Start barometric pressure monitoring
    public func startMonitoring() {
        guard isAvailable else { return }

        altimeter.startRelativeAltitudeUpdates(to: .main) { [weak self] data, error in
            guard let self, let data else { return }

            let pressure = data.pressure.doubleValue // kPa
            let altitude = data.relativeAltitude.doubleValue // meters

            // Calculate pressure rate of change
            let delta: Double
            if let last = self.lastPressure {
                delta = abs(pressure - last) * 10.0 // Scale up for sensitivity
            } else {
                delta = 0
            }

            if self.baselinePressure == nil {
                self.baselinePressure = pressure
            }
            self.lastPressure = pressure

            let reading = BarometricReading(
                pressure: pressure,
                relativeAltitude: altitude,
                pressureDelta: delta,
                detectedVibration: delta > self.vibrationThreshold
            )

            self.latestReading = reading
            self.vibrationDetected = reading.detectedVibration
            self.pressureHistory.append(pressure)
            if self.pressureHistory.count > self.maxHistorySize {
                self.pressureHistory.removeFirst()
            }
        }

        isActive = true
    }

    /// Stop monitoring
    public func stopMonitoring() {
        altimeter.stopRelativeAltitudeUpdates()
        isActive = false
        baselinePressure = nil
        lastPressure = nil
    }
}
#endif

// MARK: - Sensor Fusion Coordinator

/// Unified multi-sensor coordinator with Kalman-filtered state estimation.
/// Fuses LiDAR, TrueDepth, barometer, IMU, and camera EVM into a single
/// coherent biophysical state for the BodyScanResonanceEngine.
@MainActor
public final class BiophysicalSensorFusion: ObservableObject {

    // MARK: - Published State

    @Published public private(set) var activeSensors: Set<BiophysicalSensor> = []
    @Published public private(set) var latestFusedReading: FusedSensorReading?
    @Published public private(set) var fusedCoherence: Double = 0
    @Published public private(set) var dominantFrequency: Double = 0
    @Published public private(set) var sensorHealth: [BiophysicalSensor: Double] = [:]

    // MARK: - Sub-Sensors

    #if canImport(ARKit)
    private let lidarScanner = LiDARDepthScanner()
    #endif
    #if os(iOS)
    private let trueDepthExtractor = TrueDepthExtractor()
    #endif
    #if canImport(CoreMotion)
    private let barometerDetector = BarometerVibrationDetector()
    private let motionManager = SharedMotionManager.shared
    #endif

    // MARK: - Kalman Filters

    private var frequencyFilter = KalmanFilter1D(
        estimate: 40.0, errorCovariance: 1.0, processNoise: 0.1, measurementNoise: 0.5
    )
    private var coherenceFilter = KalmanFilter1D(
        estimate: 0.5, errorCovariance: 0.5, processNoise: 0.05, measurementNoise: 0.2
    )

    // MARK: - IMU State

    private var accelBuffer: [Float] = []
    private var accelFFTSetup: vDSP_DFT_Setup?
    private let fftSize = 256
    private let imuSampleRate: Float = 100.0

    // MARK: - Fusion Timer

    private var fusionTimer: DispatchSourceTimer?
    private let fusionQueue = DispatchQueue(label: "com.echoelmusic.sensorfusion", qos: .userInteractive)
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    public init() {
        accelFFTSetup = vDSP_DFT_zrop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)
    }

    deinit {
        fusionTimer?.cancel()
        fusionTimer = nil // Prevent pending callbacks from firing
        if let setup = accelFFTSetup { vDSP_DFT_DestroySetup(setup) }
    }

    // MARK: - Public API

    /// Start all available sensors
    public func startAllSensors() async throws {
        // LiDAR (if available — requires hardware support)
        #if canImport(ARKit)
        if lidarScanner.isLiDARAvailable {
            try lidarScanner.startScanning()
            activeSensors.insert(.lidar)
            sensorHealth[.lidar] = 1.0
        }
        #endif

        // TrueDepth
        #if os(iOS)
        do {
            try trueDepthExtractor.startCapture()
            activeSensors.insert(.trueDepth)
            sensorHealth[.trueDepth] = 1.0
        } catch {
            log.info("TrueDepth not available: \(error)")
        }
        #endif

        // Barometer
        #if canImport(CoreMotion)
        if barometerDetector.isAvailable {
            barometerDetector.startMonitoring()
            activeSensors.insert(.barometer)
            sensorHealth[.barometer] = 1.0
        }

        // IMU — use deviceMotion which properly separates gravity via sensor fusion
        if motionManager.isDeviceMotionAvailable {
            motionManager.deviceMotionUpdateInterval = 1.0 / Double(imuSampleRate)
            motionManager.startDeviceMotionUpdates(to: .main) { [weak self] motion, _ in
                guard let self, let motion else { return }
                // userAcceleration is gravity-free (Apple's sensor fusion handles this)
                let accel = motion.userAcceleration
                let mag = Float(sqrt(accel.x * accel.x + accel.y * accel.y + accel.z * accel.z))
                self.accelBuffer.append(mag)
                if self.accelBuffer.count > self.fftSize * 2 {
                    self.accelBuffer.removeFirst(self.accelBuffer.count - self.fftSize * 2)
                }
            }
            activeSensors.insert(.accelerometer)
            activeSensors.insert(.gyroscope) // deviceMotion includes both
            sensorHealth[.accelerometer] = 1.0
            sensorHealth[.gyroscope] = 1.0
        }
        #endif

        // Start fusion loop at 30 Hz
        startFusionLoop()
    }

    /// Stop all sensors
    public func stopAllSensors() {
        #if canImport(ARKit)
        lidarScanner.stopScanning()
        #endif
        #if os(iOS)
        trueDepthExtractor.stopCapture()
        #endif
        #if canImport(CoreMotion)
        barometerDetector.stopMonitoring()
        motionManager.stopDeviceMotionUpdates()
        #endif

        fusionTimer?.cancel()
        fusionTimer = nil
        activeSensors = []
        sensorHealth = [:]
    }

    /// Get Nyquist-safe sensor recommendation for a target frequency
    public func recommendSensors(for targetFrequency: Double) -> [BiophysicalSensor] {
        BiophysicalSensor.allCases.filter { sensor in
            sensor.nyquistLimit >= targetFrequency && activeSensors.contains(sensor)
        }
    }

    // MARK: - Fusion Loop

    private func startFusionLoop() {
        // Sensor fusion at 15Hz (66ms) — matches sensor Nyquist requirements
        // while halving CPU wakeups vs previous 30Hz.
        fusionTimer?.cancel()
        let timer = DispatchSource.makeTimerSource(flags: [], queue: fusionQueue)
        timer.schedule(deadline: .now(), repeating: .milliseconds(66), leeway: .milliseconds(8))
        timer.setEventHandler { [weak self] in
            DispatchQueue.main.async { [weak self] in
                self?.performFusion()
            }
        }
        timer.resume()
        fusionTimer = timer
    }

    private func performFusion() {
        let now = CACurrentMediaTime()

        // Gather readings from all active sensors
        var depthReading: DepthMapReading?
        #if canImport(ARKit)
        depthReading = lidarScanner.latestDepthMap
        #endif
        #if os(iOS)
        if depthReading == nil {
            depthReading = trueDepthExtractor.latestDepthMap
        }
        #endif

        // IMU frequency analysis (from userAcceleration buffer)
        let imuFreq = detectIMUFrequency()
        let inertial: InertialReading?
        #if canImport(CoreMotion)
        if let motion = motionManager.deviceMotion {
            let accel = motion.userAcceleration
            let rate = motion.rotationRate
            inertial = InertialReading(
                acceleration: SIMD3<Float>(Float(accel.x), Float(accel.y), Float(accel.z)),
                rotationRate: SIMD3<Float>(Float(rate.x), Float(rate.y), Float(rate.z)),
                magnitude: Float(sqrt(accel.x * accel.x + accel.y * accel.y + accel.z * accel.z)),
                dominantFrequency: imuFreq
            )
        } else {
            inertial = nil
        }
        let barometric = barometerDetector.latestReading
        #else
        let inertial: InertialReading? = nil
        let barometric: BarometricReading? = nil
        #endif

        // Fused frequency estimate from IMU FFT only (the one sensor with Nyquist > 50 Hz)
        // LiDAR (7.5 Hz Nyquist) and TrueDepth (15 Hz Nyquist) cannot detect 35-50 Hz range,
        // so they contribute depth context (spatial mapping) but NOT frequency data.
        if imuFreq > 0 {
            dominantFrequency = frequencyFilter.update(measurement: Double(imuFreq))
        }

        // Confidence based on actual sensor data quality, not just sensor count
        var confidenceFactors: [Double] = []
        if imuFreq > 0 {
            // IMU producing valid frequency → high confidence
            confidenceFactors.append(0.8)
        } else if !accelBuffer.isEmpty {
            // IMU running but no clear frequency → partial confidence
            confidenceFactors.append(0.3)
        }
        if let depth = depthReading {
            // Depth data available → adds spatial context confidence
            confidenceFactors.append(depth.confidenceValues != nil ? 0.9 : 0.6)
        }
        #if canImport(CoreMotion)
        if let baro = barometric, baro.detectedVibration {
            // Barometer confirms physical vibration (supplementary)
            confidenceFactors.append(0.5)
        }
        #endif
        let rawConfidence = confidenceFactors.isEmpty ? 0 : confidenceFactors.reduce(0, +) / Double(confidenceFactors.count)
        fusedCoherence = coherenceFilter.update(measurement: rawConfidence)

        // Create fused reading
        latestFusedReading = FusedSensorReading(
            timestamp: now,
            depthMap: depthReading,
            inertial: inertial,
            barometric: barometric,
            evmFrequencies: nil, // EVM handled by EVMAnalysisEngine
            fusedConfidence: fusedCoherence
        )
    }

    // MARK: - IMU Frequency Analysis

    private func detectIMUFrequency() -> Float {
        guard accelBuffer.count >= fftSize, let fftSetup = accelFFTSetup else { return 0 }

        var realInput = Array(accelBuffer.suffix(fftSize))
        var imagInput = [Float](repeating: 0, count: fftSize)
        var realOutput = [Float](repeating: 0, count: fftSize)
        var imagOutput = [Float](repeating: 0, count: fftSize)

        // Hanning window
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))
        vDSP_vmul(realInput, 1, window, 1, &realInput, 1, vDSP_Length(fftSize))

        // FFT
        vDSP_DFT_Execute(fftSetup, &realInput, &imagInput, &realOutput, &imagOutput)

        // Magnitude
        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        var splitComplex = DSPSplitComplex(realp: &realOutput, imagp: &imagOutput)
        vDSP_zvabs(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))

        // Find peak in 1-60 Hz range
        let binWidth = imuSampleRate / Float(fftSize)
        let minBin = max(1, Int(1.0 / binWidth))
        let maxBin = min(Int(60.0 / binWidth), fftSize / 2 - 1)

        var maxMag: Float = 0
        var maxBinIdx = minBin
        for bin in minBin...maxBin {
            if magnitudes[bin] > maxMag {
                maxMag = magnitudes[bin]
                maxBinIdx = bin
            }
        }

        return maxMag > 0.01 ? Float(maxBinIdx) * binWidth : 0
    }
}

// MARK: - Named Frequency Engines

/// Osteo-Sync Engine: 35-45 Hz bone adaptation frequencies.
/// Reference: Rubin et al. (2006), Judex & Rubin (2010)
public struct OsteoSyncEngine: Sendable {
    public static let frequencyRange: ClosedRange<Double> = 35...45
    public static let primaryFrequency: Double = 40.0
    public static let intensity: Double = 0.6
    public static let sessionDuration: TimeInterval = 600 // 10 min
    public static let educationalReference = "Rubin et al. (2006): Low-magnitude mechanical signals and bone adaptation"

    /// Calculate optimal frequency based on sensor feedback
    public static func optimalFrequency(sensorCoherence: Double) -> Double {
        // Adaptively shift within safe range based on coherence
        let center = primaryFrequency
        let offset = (sensorCoherence - 0.5) * 5.0 // ±2.5 Hz shift
        return max(frequencyRange.lowerBound, min(frequencyRange.upperBound, center + offset))
    }
}

/// Myo-Resonance Engine: 45-50 Hz muscle tissue frequencies.
/// Reference: Judex & Rubin (2010)
public struct MyoResonanceEngine: Sendable {
    public static let frequencyRange: ClosedRange<Double> = 45...50
    public static let primaryFrequency: Double = 47.5
    public static let intensity: Double = 0.7
    public static let sessionDuration: TimeInterval = 480 // 8 min
    public static let educationalReference = "Judex & Rubin (2010): Mechanical influences on muscle tissue"

    public static func optimalFrequency(sensorCoherence: Double) -> Double {
        let center = primaryFrequency
        let offset = (sensorCoherence - 0.5) * 2.5
        return max(frequencyRange.lowerBound, min(frequencyRange.upperBound, center + offset))
    }
}

/// Neural-Flow Engine: 40 Hz gamma entrainment.
/// Reference: Iaccarino et al. (2016)
public struct NeuralFlowEngine: Sendable {
    public static let frequencyRange: ClosedRange<Double> = 38...42
    public static let primaryFrequency: Double = 40.0
    public static let intensity: Double = 0.5
    public static let sessionDuration: TimeInterval = 720 // 12 min
    public static let educationalReference = "Iaccarino et al. (2016): 40 Hz gamma entrainment research"

    public static func optimalFrequency(sensorCoherence: Double) -> Double {
        // Gamma is narrow-band — stay very close to 40 Hz
        let center = primaryFrequency
        let offset = (sensorCoherence - 0.5) * 1.0 // ±0.5 Hz max
        return max(frequencyRange.lowerBound, min(frequencyRange.upperBound, center + offset))
    }
}
