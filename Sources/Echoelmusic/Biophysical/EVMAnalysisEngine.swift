// EVMAnalysisEngine.swift
// Echoelmusic
//
// Eulerian Video Magnification (EVM) engine for detecting micro-movements
// in skin/tissue surfaces. Uses Metal for GPU-accelerated spatial decomposition.
//
// Based on: Wu et al. (2012) "Eulerian Video Magnification for Revealing
// Subtle Changes in the World" - MIT CSAIL
//
// DISCLAIMER: For wellness visualization only. Not a medical diagnostic tool.
//
// Created by Echoelmusic Team
// Copyright © 2026 Echoelmusic. All rights reserved.

import Foundation
import AVFoundation
import CoreImage
#if canImport(Metal)
import Metal
import MetalKit
#endif
import Accelerate

// MARK: - EVM Configuration

/// Configuration for EVM analysis
public struct EVMConfiguration: Codable, Sendable {
    /// Target frequency range to amplify (Hz)
    public var frequencyRange: (min: Double, max: Double)

    /// Amplification factor for detected motion
    public var amplificationFactor: Double

    /// Number of pyramid levels for spatial decomposition
    public var pyramidLevels: Int

    /// Temporal filter order
    public var filterOrder: Int

    /// Frame rate for analysis
    public var analysisFrameRate: Double

    /// Region of interest (normalized 0-1)
    public var regionOfInterest: CGRect

    enum CodingKeys: String, CodingKey {
        case amplificationFactor, pyramidLevels, filterOrder, analysisFrameRate
    }

    public init(
        frequencyRange: (min: Double, max: Double) = (1.0, 60.0),
        amplificationFactor: Double = 50.0,
        pyramidLevels: Int = 4,
        filterOrder: Int = 2,
        analysisFrameRate: Double = 30.0,
        regionOfInterest: CGRect = CGRect(x: 0, y: 0, width: 1, height: 1)
    ) {
        self.frequencyRange = frequencyRange
        self.amplificationFactor = amplificationFactor
        self.pyramidLevels = pyramidLevels
        self.filterOrder = filterOrder
        self.analysisFrameRate = analysisFrameRate
        self.regionOfInterest = regionOfInterest
    }

    public init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        amplificationFactor = try container.decode(Double.self, forKey: .amplificationFactor)
        pyramidLevels = try container.decode(Int.self, forKey: .pyramidLevels)
        filterOrder = try container.decode(Int.self, forKey: .filterOrder)
        analysisFrameRate = try container.decode(Double.self, forKey: .analysisFrameRate)
        frequencyRange = (1.0, 60.0)
        regionOfInterest = CGRect(x: 0, y: 0, width: 1, height: 1)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(amplificationFactor, forKey: .amplificationFactor)
        try container.encode(pyramidLevels, forKey: .pyramidLevels)
        try container.encode(filterOrder, forKey: .filterOrder)
        try container.encode(analysisFrameRate, forKey: .analysisFrameRate)
    }
}

// MARK: - Laplacian Pyramid Level

/// Single level of the Laplacian pyramid
struct LaplacianPyramidLevel {
    var data: [Float]
    var width: Int
    var height: Int
    var channels: Int = 3

    var count: Int { width * height * channels }
}

// MARK: - Temporal Filter State

/// IIR butterworth bandpass filter state
struct TemporalFilterState {
    var lowpassState1: [Float]
    var lowpassState2: [Float]
    var highpassState1: [Float]
    var highpassState2: [Float]

    init(size: Int) {
        lowpassState1 = [Float](repeating: 0, count: size)
        lowpassState2 = [Float](repeating: 0, count: size)
        highpassState1 = [Float](repeating: 0, count: size)
        highpassState2 = [Float](repeating: 0, count: size)
    }
}

// MARK: - EVM Analysis Engine

/// Eulerian Video Magnification analysis engine
/// Detects micro-movements (1-60 Hz) in video frames using spatial decomposition
/// and temporal filtering.
public final class EVMAnalysisEngine: NSObject {

    // MARK: - Properties

    private var configuration: EVMConfiguration
    private var isAnalyzing = false

    // Metal resources
    private var device: MTLDevice?
    private var commandQueue: MTLCommandQueue?
    private var computePipelineState: MTLComputePipelineState?

    // Camera capture
    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureVideoDataOutput?
    private let captureQueue = DispatchQueue(label: "com.echoelmusic.evm.capture", qos: .userInteractive)

    // Frame buffer for temporal analysis
    private var frameBuffer: [[Float]] = []
    private var pyramidBuffer: [[LaplacianPyramidLevel]] = []
    private var filterStates: [TemporalFilterState] = []
    private let maxBufferSize = 256

    // Analysis results
    private var frequencyBins: [Double] = []
    public private(set) var latestResult: EVMAnalysisResult?

    // FFT setup
    private var fftSetup: vDSP_DFT_Setup?
    private let fftLength = 256

    // MARK: - Initialization

    public override init() {
        self.configuration = EVMConfiguration()
        super.init()
        setupMetal()
        setupFFT()
    }

    public init(configuration: EVMConfiguration) {
        self.configuration = configuration
        super.init()
        setupMetal()
        setupFFT()
    }

    // MARK: - Metal Setup

    private func setupMetal() {
        guard let device = MTLCreateSystemDefaultDevice() else {
            log.warning("Metal not available for EVM analysis")
            return
        }

        self.device = device
        self.commandQueue = device.makeCommandQueue()

        // Create compute pipeline for Laplacian pyramid
        do {
            let library = try device.makeDefaultLibrary(bundle: Bundle.main)
            if let function = library?.makeFunction(name: "laplacianPyramidDownsample") {
                computePipelineState = try device.makeComputePipelineState(function: function)
            }
        } catch {
            log.error("Failed to create EVM compute pipeline: \(error)")
        }
    }

    private func setupFFT() {
        fftSetup = vDSP_DFT_zrop_CreateSetup(
            nil,
            vDSP_Length(fftLength),
            .FORWARD
        )
    }

    // MARK: - Public API

    /// Start EVM analysis with frequency range
    public func startAnalysis(frequencyRange: (min: Double, max: Double)) async throws {
        guard !isAnalyzing else { return }

        configuration.frequencyRange = frequencyRange

        // Request camera access
        let status = AVCaptureDevice.authorizationStatus(for: .video)
        if status == .notDetermined {
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            if !granted {
                throw BiophysicalError.cameraAccessDenied
            }
        } else if status != .authorized {
            throw BiophysicalError.cameraAccessDenied
        }

        // Setup camera capture
        try setupCameraCapture()

        isAnalyzing = true
        captureSession?.startRunning()
    }

    /// Stop EVM analysis
    public func stopAnalysis() {
        isAnalyzing = false
        captureSession?.stopRunning()
        frameBuffer.removeAll()
        pyramidBuffer.removeAll()
        filterStates.removeAll()
    }

    /// Update configuration
    public func updateConfiguration(_ config: EVMConfiguration) {
        self.configuration = config
        // Reset filter states for new frequency range
        filterStates.removeAll()
    }

    // MARK: - Camera Setup

    private func setupCameraCapture() throws {
        let session = AVCaptureSession()
        session.sessionPreset = .medium

        // Find front camera (for face/skin analysis)
        guard let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front) else {
            throw BiophysicalError.sensorNotAvailable
        }

        // Configure camera for optimal frame rate
        try camera.lockForConfiguration()
        camera.activeVideoMinFrameDuration = CMTime(value: 1, timescale: Int32(configuration.analysisFrameRate))
        camera.activeVideoMaxFrameDuration = CMTime(value: 1, timescale: Int32(configuration.analysisFrameRate))
        camera.unlockForConfiguration()

        // Add input
        let input = try AVCaptureDeviceInput(device: camera)
        if session.canAddInput(input) {
            session.addInput(input)
        }

        // Add video output
        let output = AVCaptureVideoDataOutput()
        output.videoSettings = [
            kCVPixelBufferPixelFormatTypeKey as String: kCVPixelFormatType_32BGRA
        ]
        output.setSampleBufferDelegate(self, queue: captureQueue)
        output.alwaysDiscardsLateVideoFrames = true

        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        self.captureSession = session
        self.videoOutput = output
    }

    // MARK: - Laplacian Pyramid

    /// Build Laplacian pyramid from image data
    private func buildLaplacianPyramid(from imageData: [Float], width: Int, height: Int) -> [LaplacianPyramidLevel] {
        var pyramid: [LaplacianPyramidLevel] = []
        var currentData = imageData
        var currentWidth = width
        var currentHeight = height

        for level in 0..<configuration.pyramidLevels {
            // Gaussian blur and downsample
            let (downsampled, newWidth, newHeight) = downsampleWithGaussian(
                currentData,
                width: currentWidth,
                height: currentHeight
            )

            // Upsample back to original size for subtraction
            let upsampled = upsampleWithGaussian(downsampled, width: newWidth, height: newHeight)

            // Laplacian = Original - Upsampled(Downsampled(Original))
            var laplacian = [Float](repeating: 0, count: currentData.count)
            vDSP_vsub(upsampled, 1, currentData, 1, &laplacian, 1, vDSP_Length(min(currentData.count, upsampled.count)))

            pyramid.append(LaplacianPyramidLevel(
                data: laplacian,
                width: currentWidth,
                height: currentHeight
            ))

            currentData = downsampled
            currentWidth = newWidth
            currentHeight = newHeight
        }

        return pyramid
    }

    /// Downsample image with Gaussian blur
    private func downsampleWithGaussian(_ data: [Float], width: Int, height: Int) -> ([Float], Int, Int) {
        let newWidth = width / 2
        let newHeight = height / 2
        let channels = 3

        guard newWidth > 0 && newHeight > 0 else {
            return (data, width, height)
        }

        var result = [Float](repeating: 0, count: newWidth * newHeight * channels)

        // Simple 2x2 averaging with Gaussian weights
        let weights: [Float] = [0.25, 0.25, 0.25, 0.25]

        for y in 0..<newHeight {
            for x in 0..<newWidth {
                for c in 0..<channels {
                    let srcX = x * 2
                    let srcY = y * 2

                    var sum: Float = 0
                    for dy in 0..<2 {
                        for dx in 0..<2 {
                            let srcIdx = ((srcY + dy) * width + (srcX + dx)) * channels + c
                            if srcIdx < data.count {
                                sum += data[srcIdx] * weights[dy * 2 + dx]
                            }
                        }
                    }

                    let dstIdx = (y * newWidth + x) * channels + c
                    result[dstIdx] = sum
                }
            }
        }

        return (result, newWidth, newHeight)
    }

    /// Upsample image with Gaussian interpolation
    private func upsampleWithGaussian(_ data: [Float], width: Int, height: Int) -> [Float] {
        let newWidth = width * 2
        let newHeight = height * 2
        let channels = 3

        var result = [Float](repeating: 0, count: newWidth * newHeight * channels)

        for y in 0..<newHeight {
            for x in 0..<newWidth {
                for c in 0..<channels {
                    let srcX = x / 2
                    let srcY = y / 2

                    let srcIdx = (srcY * width + srcX) * channels + c
                    let dstIdx = (y * newWidth + x) * channels + c

                    if srcIdx < data.count {
                        result[dstIdx] = data[srcIdx]
                    }
                }
            }
        }

        return result
    }

    // MARK: - Temporal Filtering

    /// Apply bandpass filter to isolate target frequencies
    private func applyTemporalFilter(to pyramid: [LaplacianPyramidLevel], levelIndex: Int) -> LaplacianPyramidLevel {
        guard levelIndex < pyramid.count else {
            return pyramid[0]
        }

        let level = pyramid[levelIndex]

        // Initialize filter state if needed
        while filterStates.count <= levelIndex {
            filterStates.append(TemporalFilterState(size: level.count))
        }

        // Calculate filter coefficients for butterworth bandpass
        let fs = configuration.analysisFrameRate
        let lowFreq = configuration.frequencyRange.min
        let highFreq = configuration.frequencyRange.max

        // Normalized frequencies
        let wLow = 2.0 * lowFreq / fs
        let wHigh = 2.0 * highFreq / fs

        // Simple IIR bandpass approximation
        let alpha = Float((wHigh - wLow) / 2.0)
        let beta = Float(1.0 - alpha)

        var filteredData = level.data
        var state = filterStates[levelIndex]

        // Apply filter to each pixel
        for i in 0..<level.count {
            // Highpass (remove DC and low frequencies)
            let hp = level.data[i] - state.lowpassState1[i]
            state.lowpassState1[i] = state.lowpassState1[i] * beta + level.data[i] * alpha

            // Lowpass (remove high frequencies above cutoff)
            let lp = state.highpassState1[i] * beta + hp * alpha
            state.highpassState1[i] = lp

            filteredData[i] = lp
        }

        filterStates[levelIndex] = state

        return LaplacianPyramidLevel(
            data: filteredData,
            width: level.width,
            height: level.height
        )
    }

    // MARK: - Frequency Analysis

    /// Analyze frequencies in filtered signal using FFT
    private func analyzeFrequencies(_ signal: [Float]) -> [Double] {
        guard signal.count >= fftLength else { return [] }

        // Prepare input for FFT
        var realInput = [Float](signal.prefix(fftLength))
        var imagInput = [Float](repeating: 0, count: fftLength)
        var realOutput = [Float](repeating: 0, count: fftLength)
        var imagOutput = [Float](repeating: 0, count: fftLength)

        // Apply Hanning window
        var window = [Float](repeating: 0, count: fftLength)
        vDSP_hann_window(&window, vDSP_Length(fftLength), Int32(vDSP_HANN_NORM))
        vDSP_vmul(realInput, 1, window, 1, &realInput, 1, vDSP_Length(fftLength))

        // Perform FFT
        if let fftSetup = fftSetup {
            vDSP_DFT_Execute(fftSetup, &realInput, &imagInput, &realOutput, &imagOutput)
        }

        // Calculate magnitude spectrum
        var magnitudes = [Float](repeating: 0, count: fftLength / 2)
        var splitComplex = DSPSplitComplex(realp: &realOutput, imagp: &imagOutput)
        vDSP_zvabs(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftLength / 2))

        // Find peak frequencies
        let binWidth = configuration.analysisFrameRate / Double(fftLength)
        var detectedFrequencies: [Double] = []

        // Focus on target frequency range
        let minBin = Int(configuration.frequencyRange.min / binWidth)
        let maxBin = min(Int(configuration.frequencyRange.max / binWidth), fftLength / 2 - 1)

        // Find local maxima
        for bin in max(1, minBin)..<maxBin {
            if magnitudes[bin] > magnitudes[bin - 1] && magnitudes[bin] > magnitudes[bin + 1] {
                let frequency = Double(bin) * binWidth
                if magnitudes[bin] > 0.1 {  // Threshold
                    detectedFrequencies.append(frequency)
                }
            }
        }

        return detectedFrequencies.sorted()
    }

    // MARK: - Image Processing

    /// Convert pixel buffer to float array
    private func pixelBufferToFloatArray(_ pixelBuffer: CVPixelBuffer) -> ([Float], Int, Int) {
        CVPixelBufferLockBaseAddress(pixelBuffer, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(pixelBuffer, .readOnly) }

        let width = CVPixelBufferGetWidth(pixelBuffer)
        let height = CVPixelBufferGetHeight(pixelBuffer)
        let bytesPerRow = CVPixelBufferGetBytesPerRow(pixelBuffer)

        guard let baseAddress = CVPixelBufferGetBaseAddress(pixelBuffer) else {
            return ([], 0, 0)
        }

        let buffer = baseAddress.assumingMemoryBound(to: UInt8.self)
        var floatArray = [Float](repeating: 0, count: width * height * 3)

        // Convert BGRA to RGB float (normalized 0-1)
        for y in 0..<height {
            for x in 0..<width {
                let srcOffset = y * bytesPerRow + x * 4
                let dstOffset = (y * width + x) * 3

                floatArray[dstOffset + 0] = Float(buffer[srcOffset + 2]) / 255.0  // R
                floatArray[dstOffset + 1] = Float(buffer[srcOffset + 1]) / 255.0  // G
                floatArray[dstOffset + 2] = Float(buffer[srcOffset + 0]) / 255.0  // B
            }
        }

        return (floatArray, width, height)
    }

    // MARK: - Cleanup

    deinit {
        stopAnalysis()
        if let fftSetup = fftSetup {
            vDSP_DFT_DestroySetup(fftSetup)
        }
    }
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate

extension EVMAnalysisEngine: AVCaptureVideoDataOutputSampleBufferDelegate {

    public func captureOutput(
        _ output: AVCaptureOutput,
        didOutput sampleBuffer: CMSampleBuffer,
        from connection: AVCaptureConnection
    ) {
        guard isAnalyzing,
              let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) else {
            return
        }

        // Convert to float array
        let (imageData, width, height) = pixelBufferToFloatArray(pixelBuffer)
        guard !imageData.isEmpty else { return }

        // Build Laplacian pyramid
        let pyramid = buildLaplacianPyramid(from: imageData, width: width, height: height)

        // Store in buffer
        pyramidBuffer.append(pyramid)
        if pyramidBuffer.count > maxBufferSize {
            pyramidBuffer.removeFirst()
        }

        // Apply temporal filtering and analyze
        guard pyramidBuffer.count >= 2 else { return }

        var allDetectedFrequencies: [Double] = []
        var spatialAmplitudes: [Double] = []
        var motionVectors: [(x: Double, y: Double)] = []

        for levelIndex in 0..<min(configuration.pyramidLevels, pyramid.count) {
            // Apply temporal filter
            let filtered = applyTemporalFilter(to: pyramid, levelIndex: levelIndex)

            // Analyze frequencies
            let frequencies = analyzeFrequencies(filtered.data)
            allDetectedFrequencies.append(contentsOf: frequencies)

            // Calculate spatial amplitude
            var rms: Float = 0
            vDSP_rmsqv(filtered.data, 1, &rms, vDSP_Length(filtered.count))
            spatialAmplitudes.append(Double(rms) * configuration.amplificationFactor)

            // Estimate motion vector from gradient
            let motionX = Double(filtered.data.first ?? 0)
            let motionY = Double(filtered.data.last ?? 0)
            motionVectors.append((x: motionX, y: motionY))
        }

        // Calculate quality score based on signal strength
        let avgAmplitude = spatialAmplitudes.reduce(0, +) / Double(max(1, spatialAmplitudes.count))
        let qualityScore = min(1.0, avgAmplitude * 10)

        // Create result
        let result = EVMAnalysisResult(
            timestamp: Date(),
            detectedFrequencies: Array(Set(allDetectedFrequencies)).sorted(),
            spatialAmplitudes: spatialAmplitudes,
            motionVectors: motionVectors,
            qualityScore: qualityScore
        )

        // Update latest result on main thread
        DispatchQueue.main.async { [weak self] in
            self?.latestResult = result
        }
    }
}
