// InertialAnalysisEngine.swift
// Echoelmusic
//
// Inertial Measurement Unit (IMU) analysis engine using CoreMotion.
// Samples accelerometer at 100Hz and performs FFT analysis to detect
// vibrations in the 30-50 Hz range.
//
// DISCLAIMER: For wellness informational purposes only. Not a medical device.
//
// Created by Echoelmusic Team
// Copyright © 2026 Echoelmusic. All rights reserved.

import Foundation
import Combine
import CoreMotion
import Accelerate
import Combine

// MARK: - Inertial Configuration

/// Configuration for inertial analysis
public struct InertialConfiguration: Codable, Sendable {
    /// Sample rate in Hz (target: 100 Hz)
    public var sampleRate: Double

    /// FFT window size (power of 2)
    public var fftWindowSize: Int

    /// Target frequency range for analysis (Hz)
    public var targetFrequencyRange: (min: Double, max: Double)

    /// Noise floor threshold
    public var noiseFloorThreshold: Double

    /// Moving average window for smoothing
    public var smoothingWindowSize: Int

    enum CodingKeys: String, CodingKey {
        case sampleRate, fftWindowSize, noiseFloorThreshold, smoothingWindowSize
    }

    public init(
        sampleRate: Double = 100.0,
        fftWindowSize: Int = 256,
        targetFrequencyRange: (min: Double, max: Double) = (30.0, 50.0),
        noiseFloorThreshold: Double = 0.001,
        smoothingWindowSize: Int = 5
    ) {
        self.sampleRate = sampleRate
        self.fftWindowSize = fftWindowSize
        self.targetFrequencyRange = targetFrequencyRange
        self.noiseFloorThreshold = noiseFloorThreshold
        self.smoothingWindowSize = smoothingWindowSize
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        sampleRate = try container.decode(Double.self, forKey: .sampleRate)
        fftWindowSize = try container.decode(Int.self, forKey: .fftWindowSize)
        noiseFloorThreshold = try container.decode(Double.self, forKey: .noiseFloorThreshold)
        smoothingWindowSize = try container.decode(Int.self, forKey: .smoothingWindowSize)
        targetFrequencyRange = (30.0, 50.0)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(sampleRate, forKey: .sampleRate)
        try container.encode(fftWindowSize, forKey: .fftWindowSize)
        try container.encode(noiseFloorThreshold, forKey: .noiseFloorThreshold)
        try container.encode(smoothingWindowSize, forKey: .smoothingWindowSize)
    }
}

// MARK: - Accelerometer Sample

/// Single accelerometer sample with timestamp
struct AccelerometerSample {
    let timestamp: TimeInterval
    let x: Double
    let y: Double
    let z: Double

    /// Combined magnitude
    var magnitude: Double {
        sqrt(x * x + y * y + z * z)
    }

    /// Gravity-removed magnitude (for detecting device vibration)
    var vibrationalMagnitude: Double {
        // Remove gravity (approximately 1.0 g when at rest)
        abs(magnitude - 1.0)
    }
}

// MARK: - Inertial Analysis Engine

/// Inertial measurement analysis using CoreMotion accelerometer
/// Performs real-time FFT to detect vibration frequencies (30-50 Hz target)
@MainActor
public final class InertialAnalysisEngine: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var isAnalyzing: Bool = false
    @Published public private(set) var latestResult: InertialAnalysisResult?
    @Published public private(set) var currentDominantFrequency: Double = 0.0
    @Published public private(set) var signalStrength: Double = 0.0

    // MARK: - Private Properties

    private var configuration: InertialConfiguration
    private let motionManager = CMMotionManager()
    private let analysisQueue = DispatchQueue(label: "com.echoelmusic.inertial.analysis", qos: .userInteractive)

    // Sample buffer for FFT
    private var sampleBuffer: [AccelerometerSample] = []
    private let maxBufferSize: Int

    // FFT resources
    private var fftSetup: vDSP_DFT_Setup?
    private var windowFunction: [Float] = []

    // Frequency spectrum history for smoothing
    private var spectrumHistory: [[Float]] = []

    // MARK: - Initialization

    public init(configuration: InertialConfiguration = InertialConfiguration()) {
        self.configuration = configuration
        self.maxBufferSize = configuration.fftWindowSize * 2

        setupFFT()
        createWindowFunction()
    }

    // MARK: - FFT Setup

    private func setupFFT() {
        fftSetup = vDSP_DFT_zrop_CreateSetup(
            nil,
            vDSP_Length(configuration.fftWindowSize),
            .FORWARD
        )
    }

    private func createWindowFunction() {
        // Hanning window for better frequency resolution
        windowFunction = [Float](repeating: 0, count: configuration.fftWindowSize)
        vDSP_hann_window(&windowFunction, vDSP_Length(configuration.fftWindowSize), Int32(vDSP_HANN_NORM))
    }

    // MARK: - Public API

    /// Check if accelerometer is available
    public var isAccelerometerAvailable: Bool {
        motionManager.isAccelerometerAvailable
    }

    /// Start inertial analysis with specified sample rate
    public func startAnalysis(sampleRate: Double = 100.0) async throws {
        guard isAccelerometerAvailable else {
            throw BiophysicalError.sensorNotAvailable
        }

        guard !isAnalyzing else { return }

        configuration.sampleRate = sampleRate
        sampleBuffer.removeAll()
        spectrumHistory.removeAll()

        // Configure motion manager
        motionManager.accelerometerUpdateInterval = 1.0 / sampleRate

        // Start updates
        motionManager.startAccelerometerUpdates(to: OperationQueue()) { [weak self] data, error in
            guard let self = self, let data = data, error == nil else { return }

            let sample = AccelerometerSample(
                timestamp: data.timestamp,
                x: data.acceleration.x,
                y: data.acceleration.y,
                z: data.acceleration.z
            )

            self.analysisQueue.async {
                self.processSample(sample)
            }
        }

        await MainActor.run {
            isAnalyzing = true
        }
    }

    /// Stop inertial analysis
    public func stopAnalysis() {
        motionManager.stopAccelerometerUpdates()

        Task { @MainActor in
            isAnalyzing = false
        }
    }

    /// Update configuration
    public func updateConfiguration(_ config: InertialConfiguration) {
        self.configuration = config

        // Recreate FFT setup if window size changed
        if let fftSetup = fftSetup {
            vDSP_DFT_DestroySetup(fftSetup)
        }
        setupFFT()
        createWindowFunction()
    }

    // MARK: - Sample Processing

    private func processSample(_ sample: AccelerometerSample) {
        // Add to buffer
        sampleBuffer.append(sample)

        // Remove old samples
        if sampleBuffer.count > maxBufferSize {
            sampleBuffer.removeFirst()
        }

        // Perform FFT when we have enough samples
        if sampleBuffer.count >= configuration.fftWindowSize {
            performFFTAnalysis()
        }
    }

    // MARK: - FFT Analysis

    private func performFFTAnalysis() {
        let windowSize = configuration.fftWindowSize

        // Extract most recent samples
        let recentSamples = Array(sampleBuffer.suffix(windowSize))

        // Convert to float array (use magnitude for omnidirectional detection)
        var magnitudes = recentSamples.map { Float($0.vibrationalMagnitude) }

        // Apply window function
        vDSP_vmul(magnitudes, 1, windowFunction, 1, &magnitudes, 1, vDSP_Length(windowSize))

        // Prepare FFT arrays
        var realInput = magnitudes
        var imagInput = [Float](repeating: 0, count: windowSize)
        var realOutput = [Float](repeating: 0, count: windowSize)
        var imagOutput = [Float](repeating: 0, count: windowSize)

        // Perform FFT
        guard let fftSetup = fftSetup else { return }
        vDSP_DFT_Execute(fftSetup, &realInput, &imagInput, &realOutput, &imagOutput)

        // Calculate power spectrum
        var powerSpectrum = [Float](repeating: 0, count: windowSize / 2)
        var splitComplex = DSPSplitComplex(realp: &realOutput, imagp: &imagOutput)
        vDSP_zvabs(&splitComplex, 1, &powerSpectrum, 1, vDSP_Length(windowSize / 2))

        // Scale by 2/N for proper amplitude
        var scale = Float(2.0 / Double(windowSize))
        vDSP_vsmul(powerSpectrum, 1, &scale, &powerSpectrum, 1, vDSP_Length(windowSize / 2))

        // Apply smoothing using history
        spectrumHistory.append(powerSpectrum)
        if spectrumHistory.count > configuration.smoothingWindowSize {
            spectrumHistory.removeFirst()
        }

        let smoothedSpectrum = averageSpectrums(spectrumHistory)

        // Analyze spectrum
        let result = analyzeSpectrum(smoothedSpectrum)

        // Update results on main thread
        DispatchQueue.main.async { [weak self] in
            self?.latestResult = result
            self?.currentDominantFrequency = result.dominantFrequency
            self?.signalStrength = result.rmsVibration
        }
    }

    /// Average multiple spectrums for smoothing
    private func averageSpectrums(_ spectrums: [[Float]]) -> [Float] {
        guard !spectrums.isEmpty else { return [] }
        guard spectrums.count > 1 else { return spectrums[0] }

        let length = spectrums[0].count
        var result = [Float](repeating: 0, count: length)

        for spectrum in spectrums {
            guard spectrum.count == length else { continue }
            vDSP_vadd(result, 1, spectrum, 1, &result, 1, vDSP_Length(length))
        }

        var divisor = Float(spectrums.count)
        vDSP_vsdiv(result, 1, &divisor, &result, 1, vDSP_Length(length))

        return result
    }

    /// Analyze power spectrum to extract frequency information
    private func analyzeSpectrum(_ spectrum: [Float]) -> InertialAnalysisResult {
        let binWidth = configuration.sampleRate / Double(configuration.fftWindowSize)

        // Find target frequency bin range
        let minBin = Int(configuration.targetFrequencyRange.min / binWidth)
        let maxBin = min(Int(configuration.targetFrequencyRange.max / binWidth), spectrum.count - 1)

        // Find dominant frequency in target range
        var peakBin = minBin
        var peakPower: Float = 0

        for bin in minBin...maxBin {
            if spectrum[bin] > peakPower {
                peakPower = spectrum[bin]
                peakBin = bin
            }
        }

        // Quadratic interpolation for more accurate frequency
        let dominantFrequency: Double
        if peakBin > 0 && peakBin < spectrum.count - 1 {
            let alpha = spectrum[peakBin - 1]
            let beta = spectrum[peakBin]
            let gamma = spectrum[peakBin + 1]

            let p = 0.5 * Double(alpha - gamma) / Double(alpha - 2 * beta + gamma)
            dominantFrequency = (Double(peakBin) + p) * binWidth
        } else {
            dominantFrequency = Double(peakBin) * binWidth
        }

        // Calculate RMS in target range
        var targetRangeSpectrum = Array(spectrum[minBin...maxBin])
        var rms: Float = 0
        vDSP_rmsqv(targetRangeSpectrum, 1, &rms, vDSP_Length(targetRangeSpectrum.count))

        // Find peak acceleration from recent samples
        let recentMagnitudes = sampleBuffer.suffix(configuration.fftWindowSize).map { $0.magnitude }
        let peakAcceleration = recentMagnitudes.max() ?? 0

        // Check if dominant frequency is in target range
        let isInTargetRange = dominantFrequency >= configuration.targetFrequencyRange.min &&
                              dominantFrequency <= configuration.targetFrequencyRange.max &&
                              Double(peakPower) > configuration.noiseFloorThreshold

        return InertialAnalysisResult(
            timestamp: Date(),
            dominantFrequency: dominantFrequency,
            frequencySpectrum: spectrum.map { Double($0) },
            peakAcceleration: peakAcceleration,
            rmsVibration: Double(rms),
            isInTargetRange: isInTargetRange
        )
    }

    // MARK: - Cleanup

    deinit {
        stopAnalysis()
        if let fftSetup = fftSetup {
            vDSP_DFT_DestroySetup(fftSetup)
        }
    }
}

// MARK: - Platform-Specific Notes

/*
 HARDWARE LIMITS REFERENCE (for CLAUDE.md):

 iOS Accelerometer:
 - Maximum sample rate: 100 Hz (officially supported)
 - Some devices support higher rates (up to 400 Hz) but not guaranteed
 - CMMotionManager.accelerometerUpdateInterval minimum: 0.01 (100 Hz)
 - Data is already low-pass filtered by hardware
 - Timestamps are in boot time, not wall clock

 Android Accelerometer (for reference):
 - SENSOR_DELAY_FASTEST: Device-dependent (typically 100-200 Hz)
 - SENSOR_DELAY_GAME: ~50 Hz
 - Sampling rates vary significantly by device manufacturer
 - Some devices have irregular sampling intervals
 - Requires robust timestamp handling for FFT

 FFT Considerations:
 - At 100 Hz sample rate, Nyquist frequency = 50 Hz
 - To detect 30-50 Hz, 100 Hz sampling is the minimum
 - 256-sample window at 100 Hz = 2.56 seconds of data
 - Frequency resolution = 100 / 256 = 0.39 Hz per bin
 - Hanning window reduces spectral leakage

 Vibration Detection:
 - Target range (30-50 Hz) is at the upper limit of accelerometer capability
 - Signal amplitude may be low, requiring sensitive thresholds
 - Device must be in contact with vibrating surface
 - Background noise from hand tremor (~8-12 Hz) should be filtered

 Power Consumption:
 - Continuous 100 Hz accelerometer: ~10-20 mW additional drain
 - Consider reducing rate when not actively analyzing
 - Batch processing can reduce wake-ups
 */
