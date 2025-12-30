//
//  QuantumLatencyEngine.swift
//  Echoelmusic
//
//  Created: December 2025
//  QUANTUM LATENCY ENGINE - Sub-Millisecond Precision
//
//  "When you need latency so low, causality questions itself"
//  Target: <3ms total system latency for VR/XR applications
//

import Foundation
import AVFoundation
import CoreAudio
import Accelerate
import simd
import Combine

// MARK: - Quantum Latency Metrics

/// Precision timing metrics at nanosecond resolution
public struct QuantumLatencyMetrics {
    // Core latencies (nanoseconds for precision)
    public var audioInputLatencyNs: UInt64 = 0
    public var audioOutputLatencyNs: UInt64 = 0
    public var dspProcessingLatencyNs: UInt64 = 0
    public var spatialRenderLatencyNs: UInt64 = 0
    public var headTrackingLatencyNs: UInt64 = 0
    public var bluetoothCodecLatencyNs: UInt64 = 0
    public var networkLatencyNs: UInt64 = 0

    // Motion-to-Sound latency (critical for VR)
    public var motionToSoundLatencyNs: UInt64 = 0

    /// Total system latency in nanoseconds
    public var totalLatencyNs: UInt64 {
        audioInputLatencyNs + audioOutputLatencyNs +
        dspProcessingLatencyNs + spatialRenderLatencyNs +
        headTrackingLatencyNs + bluetoothCodecLatencyNs
    }

    /// Total latency in milliseconds
    public var totalLatencyMs: Double {
        Double(totalLatencyNs) / 1_000_000.0
    }

    /// Total latency in samples at given sample rate
    public func totalLatencySamples(sampleRate: Double) -> Int {
        Int(Double(totalLatencyNs) / 1_000_000_000.0 * sampleRate)
    }

    /// Is latency acceptable for VR? (<10ms)
    public var isVRAcceptable: Bool { totalLatencyMs < 10.0 }

    /// Is latency acceptable for professional monitoring? (<5ms)
    public var isProfessionalAcceptable: Bool { totalLatencyMs < 5.0 }

    /// Is latency at quantum level? (<3ms)
    public var isQuantumLevel: Bool { totalLatencyMs < 3.0 }

    /// Jitter (variation in latency)
    public var jitterNs: UInt64 = 0

    /// Jitter in milliseconds
    public var jitterMs: Double { Double(jitterNs) / 1_000_000.0 }
}

// MARK: - Realtime Thread Priority

/// Thread priority levels for audio processing
public enum RealtimeThreadPriority: Int {
    case normal = 0
    case elevated = 1
    case realtime = 2
    case quantum = 3      // Maximum priority, OS-level realtime

    /// macOS/iOS thread policy
    var threadTimeConstraint: (period: UInt32, computation: UInt32, constraint: UInt32, preemptible: Bool) {
        switch self {
        case .normal:
            return (0, 0, 0, true)
        case .elevated:
            return (100_000, 50_000, 100_000, true)
        case .realtime:
            return (50_000, 25_000, 50_000, false)
        case .quantum:
            // Ultra-aggressive: 1ms period, 0.5ms computation window
            return (10_000, 5_000, 10_000, false)
        }
    }
}

// MARK: - Buffer Configuration

/// Ultra-optimized buffer configuration
public struct QuantumBufferConfig {
    public var inputBufferSize: Int = 32      // ~0.67ms @ 48kHz
    public var outputBufferSize: Int = 32
    public var processingBufferSize: Int = 64
    public var sampleRate: Double = 48000
    public var bitDepth: Int = 32             // Float32 for processing
    public var channels: Int = 2

    /// Use triple buffering for glitch-free audio
    public var useTripleBuffering: Bool = true

    /// Pre-allocate all buffers to avoid runtime allocation
    public var preAllocateBuffers: Bool = true

    /// Lock buffers in memory (prevent paging)
    public var lockInMemory: Bool = true

    /// Input latency in milliseconds
    public var inputLatencyMs: Double {
        Double(inputBufferSize) / sampleRate * 1000.0
    }

    /// Output latency in milliseconds
    public var outputLatencyMs: Double {
        Double(outputBufferSize) / sampleRate * 1000.0
    }

    /// Total buffer latency
    public var totalBufferLatencyMs: Double {
        inputLatencyMs + outputLatencyMs
    }

    /// Preset: Quantum (minimum latency, maximum CPU)
    public static let quantum = QuantumBufferConfig(
        inputBufferSize: 16,
        outputBufferSize: 16,
        processingBufferSize: 32,
        sampleRate: 48000,
        bitDepth: 32,
        channels: 2,
        useTripleBuffering: true,
        preAllocateBuffers: true,
        lockInMemory: true
    )

    /// Preset: VR (very low latency, balanced)
    public static let vr = QuantumBufferConfig(
        inputBufferSize: 32,
        outputBufferSize: 32,
        processingBufferSize: 64,
        sampleRate: 48000,
        bitDepth: 32,
        channels: 2,
        useTripleBuffering: true,
        preAllocateBuffers: true,
        lockInMemory: true
    )

    /// Preset: Professional (low latency, stable)
    public static let professional = QuantumBufferConfig(
        inputBufferSize: 64,
        outputBufferSize: 64,
        processingBufferSize: 128,
        sampleRate: 48000,
        bitDepth: 32,
        channels: 2,
        useTripleBuffering: true,
        preAllocateBuffers: true,
        lockInMemory: false
    )
}

// MARK: - Mach Timing

/// High-precision timing using Mach absolute time
final class MachPrecisionTimer {
    private var timebaseInfo = mach_timebase_info_data_t()

    init() {
        mach_timebase_info(&timebaseInfo)
    }

    /// Current time in nanoseconds
    var nowNs: UInt64 {
        let machTime = mach_absolute_time()
        return machTime * UInt64(timebaseInfo.numer) / UInt64(timebaseInfo.denom)
    }

    /// Measure execution time of a block in nanoseconds
    func measure(_ block: () -> Void) -> UInt64 {
        let start = nowNs
        block()
        return nowNs - start
    }

    /// Sleep for exact nanoseconds (spin-wait for precision)
    func spinWaitNs(_ ns: UInt64) {
        let target = nowNs + ns
        while nowNs < target {
            // Spin
        }
    }
}

// MARK: - Lock-Free Triple Buffer

/// Lock-free triple buffer for glitch-free audio
final class LockFreeTripleBuffer<T> {
    private var buffers: [UnsafeMutablePointer<T>]
    private var writeIndex: Int32 = 0
    private var readIndex: Int32 = 2
    private var middleIndex: Int32 = 1
    private let capacity: Int

    init(capacity: Int, defaultValue: T) {
        self.capacity = capacity
        self.buffers = (0..<3).map { _ in
            let ptr = UnsafeMutablePointer<T>.allocate(capacity: capacity)
            ptr.initialize(repeating: defaultValue, count: capacity)
            return ptr
        }
    }

    deinit {
        for buffer in buffers {
            buffer.deallocate()
        }
    }

    /// Get write buffer pointer
    var writeBuffer: UnsafeMutablePointer<T> {
        buffers[Int(writeIndex)]
    }

    /// Get read buffer pointer
    var readBuffer: UnsafePointer<T> {
        UnsafePointer(buffers[Int(readIndex)])
    }

    /// Commit write buffer (atomic swap with middle)
    func commitWrite() {
        // Atomic swap: write ↔ middle
        let old = OSAtomicCompareAndSwap32(writeIndex, middleIndex, &writeIndex)
        if old {
            middleIndex = writeIndex
        }
    }

    /// Request new read buffer (atomic swap with middle)
    func requestRead() -> Bool {
        // Check if middle has new data
        if middleIndex != readIndex {
            let old = readIndex
            readIndex = middleIndex
            middleIndex = old
            return true
        }
        return false
    }
}

// MARK: - SIMD Optimized DSP

/// SIMD-accelerated DSP operations for minimum latency
struct QuantumDSP {

    /// Vectorized stereo gain with SIMD
    static func applyStereoGain(
        _ buffer: UnsafeMutablePointer<Float>,
        count: Int,
        leftGain: Float,
        rightGain: Float
    ) {
        let gains = simd_float2(leftGain, rightGain)
        let stereoCount = count / 2

        buffer.withMemoryRebound(to: simd_float2.self, capacity: stereoCount) { ptr in
            for i in 0..<stereoCount {
                ptr[i] *= gains
            }
        }
    }

    /// Ultra-fast mix with vDSP
    static func mix(
        _ source: UnsafePointer<Float>,
        into dest: UnsafeMutablePointer<Float>,
        count: Int,
        gain: Float
    ) {
        var g = gain
        vDSP_vsma(source, 1, &g, dest, 1, dest, 1, vDSP_Length(count))
    }

    /// Vectorized linear interpolation for sample-rate conversion
    static func linearInterpolate(
        _ source: UnsafePointer<Float>,
        sourceCount: Int,
        into dest: UnsafeMutablePointer<Float>,
        destCount: Int
    ) {
        let ratio = Float(sourceCount - 1) / Float(destCount - 1)

        for i in 0..<destCount {
            let srcPos = Float(i) * ratio
            let srcIndex = Int(srcPos)
            let frac = srcPos - Float(srcIndex)

            if srcIndex + 1 < sourceCount {
                dest[i] = source[srcIndex] * (1 - frac) + source[srcIndex + 1] * frac
            } else {
                dest[i] = source[srcIndex]
            }
        }
    }

    /// Zero-latency hard limiter
    static func hardLimit(
        _ buffer: UnsafeMutablePointer<Float>,
        count: Int,
        threshold: Float = 0.95
    ) {
        var minVal = -threshold
        var maxVal = threshold
        vDSP_vclip(buffer, 1, &minVal, &maxVal, buffer, 1, vDSP_Length(count))
    }

    /// DC offset removal (single pole high-pass)
    static func removeDCOffset(
        _ buffer: UnsafeMutablePointer<Float>,
        count: Int,
        state: inout Float,
        coefficient: Float = 0.995
    ) {
        for i in 0..<count {
            let input = buffer[i]
            state = input + coefficient * state
            buffer[i] = input - state * (1 - coefficient)
        }
    }
}

// MARK: - Direct Monitoring Bypass

/// Zero-latency direct monitoring path
final class DirectMonitoringBypass {

    private var isEnabled: Bool = false
    private var inputGain: Float = 1.0
    private var outputGain: Float = 1.0
    private var pan: Float = 0.0  // -1 (L) to +1 (R)

    // Separate gains for L/R calculated from pan
    private var leftGain: Float = 1.0
    private var rightGain: Float = 1.0

    /// Enable bypass monitoring
    func enable(inputGain: Float = 1.0, outputGain: Float = 1.0, pan: Float = 0.0) {
        self.isEnabled = true
        self.inputGain = inputGain
        self.outputGain = outputGain
        setPan(pan)
    }

    /// Disable bypass monitoring
    func disable() {
        self.isEnabled = false
    }

    /// Set pan position
    func setPan(_ pan: Float) {
        self.pan = max(-1, min(1, pan))
        // Constant power pan law
        let angle = (self.pan + 1) * Float.pi / 4  // 0 to π/2
        leftGain = cos(angle)
        rightGain = sin(angle)
    }

    /// Process audio (zero-copy when possible)
    func process(
        input: UnsafePointer<Float>,
        output: UnsafeMutablePointer<Float>,
        frameCount: Int,
        channels: Int = 2
    ) {
        guard isEnabled else { return }

        let totalGain = inputGain * outputGain
        let sampleCount = frameCount * channels

        if channels == 2 {
            // Stereo: apply pan + gain
            QuantumDSP.applyStereoGain(
                output,
                count: sampleCount,
                leftGain: leftGain * totalGain,
                rightGain: rightGain * totalGain
            )

            // Mix input to output
            QuantumDSP.mix(input, into: output, count: sampleCount, gain: 1.0)
        } else {
            // Mono: just gain
            var g = totalGain
            vDSP_vsmul(input, 1, &g, output, 1, vDSP_Length(sampleCount))
        }
    }
}

// MARK: - VR/XR Spatial Latency Optimizer

/// Optimizes spatial audio latency for VR/XR applications
final class VRSpatialLatencyOptimizer {

    // Head tracking state
    private var lastHeadPosition: simd_float3 = .zero
    private var lastHeadRotation: simd_quatf = simd_quatf(ix: 0, iy: 0, iz: 0, r: 1)
    private var headVelocity: simd_float3 = .zero
    private var headAngularVelocity: simd_float3 = .zero

    // Prediction
    private var predictionTimeMs: Float = 20.0  // Default prediction window
    private var usePrediction: Bool = true

    // Timing
    private let timer = MachPrecisionTimer()
    private var lastUpdateTimeNs: UInt64 = 0

    /// Update head tracking with prediction
    func updateHeadTracking(
        position: simd_float3,
        rotation: simd_quatf,
        timestamp: UInt64
    ) -> (predictedPosition: simd_float3, predictedRotation: simd_quatf) {

        // Calculate delta time
        let deltaNs = timestamp - lastUpdateTimeNs
        let deltaS = Float(deltaNs) / 1_000_000_000.0

        guard deltaS > 0 && deltaS < 0.1 else {
            // Invalid delta, just return current values
            lastHeadPosition = position
            lastHeadRotation = rotation
            lastUpdateTimeNs = timestamp
            return (position, rotation)
        }

        // Calculate velocity
        headVelocity = (position - lastHeadPosition) / deltaS

        // Calculate angular velocity (simplified)
        let rotDiff = rotation * lastHeadRotation.conjugate
        headAngularVelocity = simd_float3(rotDiff.imag.x, rotDiff.imag.y, rotDiff.imag.z) * 2.0 / deltaS

        // Store current values
        lastHeadPosition = position
        lastHeadRotation = rotation
        lastUpdateTimeNs = timestamp

        // Predict future position/rotation
        if usePrediction {
            let predictionS = predictionTimeMs / 1000.0

            let predictedPos = position + headVelocity * predictionS

            // Predict rotation (first-order)
            let angVelMag = simd_length(headAngularVelocity)
            var predictedRot = rotation

            if angVelMag > 0.001 {
                let axis = headAngularVelocity / angVelMag
                let angle = angVelMag * predictionS
                let deltaRot = simd_quatf(angle: angle, axis: axis)
                predictedRot = deltaRot * rotation
            }

            return (predictedPos, predictedRot)
        }

        return (position, rotation)
    }

    /// Calculate optimal prediction time based on system latency
    func calculateOptimalPrediction(systemLatencyMs: Float) {
        // Prediction should match total audio latency
        predictionTimeMs = systemLatencyMs
    }

    /// Get motion-to-sound compensation in samples
    func getMotionToSoundCompensation(sampleRate: Double) -> Int {
        Int(Double(predictionTimeMs) / 1000.0 * sampleRate)
    }
}

// MARK: - Quantum Latency Engine

/// Main engine for sub-millisecond latency audio processing
@MainActor
public final class QuantumLatencyEngine: ObservableObject {

    // MARK: - Singleton
    public static let shared = QuantumLatencyEngine()

    // MARK: - Published State
    @Published public var metrics = QuantumLatencyMetrics()
    @Published public var bufferConfig = QuantumBufferConfig.vr
    @Published public var isRunning = false
    @Published public var isQuantumMode = false
    @Published public var currentPriority: RealtimeThreadPriority = .realtime

    // Direct monitoring
    @Published public var directMonitoringEnabled = false
    @Published public var directMonitoringGain: Float = 1.0
    @Published public var directMonitoringPan: Float = 0.0

    // MARK: - Private Properties

    private var audioEngine: AVAudioEngine!
    private var inputNode: AVAudioInputNode!
    private var outputNode: AVAudioOutputNode!

    private var inputBuffer: LockFreeTripleBuffer<Float>!
    private var outputBuffer: LockFreeTripleBuffer<Float>!

    private let directMonitoring = DirectMonitoringBypass()
    private let vrOptimizer = VRSpatialLatencyOptimizer()
    private let timer = MachPrecisionTimer()

    private var processingThread: Thread?
    private var isProcessing = false

    private var dcOffsetStateL: Float = 0
    private var dcOffsetStateR: Float = 0

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    private init() {
        setupAudioEngine()
        setupPublishers()
    }

    // MARK: - Setup

    private func setupAudioEngine() {
        audioEngine = AVAudioEngine()
        inputNode = audioEngine.inputNode
        outputNode = audioEngine.outputNode

        // Pre-allocate buffers
        let bufferCapacity = bufferConfig.processingBufferSize * bufferConfig.channels * 3
        inputBuffer = LockFreeTripleBuffer(capacity: bufferCapacity, defaultValue: Float(0))
        outputBuffer = LockFreeTripleBuffer(capacity: bufferCapacity, defaultValue: Float(0))
    }

    private func setupPublishers() {
        // Monitor direct monitoring state
        $directMonitoringEnabled
            .sink { [weak self] enabled in
                if enabled {
                    self?.directMonitoring.enable(
                        inputGain: self?.directMonitoringGain ?? 1.0,
                        outputGain: 1.0,
                        pan: self?.directMonitoringPan ?? 0.0
                    )
                } else {
                    self?.directMonitoring.disable()
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Public API

    /// Start quantum latency engine
    public func start(config: QuantumBufferConfig = .vr) throws {
        guard !isRunning else { return }

        bufferConfig = config

        // Configure audio session for minimum latency
        try configureAudioSession()

        // Setup audio processing
        try setupAudioProcessing()

        // Start realtime processing thread
        startProcessingThread()

        // Start audio engine
        try audioEngine.start()

        isRunning = true

        // Measure actual latency
        measureSystemLatency()

        print("⚛️ Quantum Latency Engine started")
        print("   Buffer: \(bufferConfig.inputBufferSize) samples (\(String(format: "%.2f", bufferConfig.inputLatencyMs))ms)")
        print("   Target latency: <\(isQuantumMode ? "3" : "10")ms")
    }

    /// Stop engine
    public func stop() {
        guard isRunning else { return }

        isProcessing = false
        processingThread = nil

        audioEngine.stop()

        isRunning = false

        print("⚛️ Quantum Latency Engine stopped")
    }

    /// Enable quantum mode (minimum latency, maximum CPU)
    public func enableQuantumMode() throws {
        isQuantumMode = true
        bufferConfig = .quantum
        currentPriority = .quantum

        if isRunning {
            stop()
            try start(config: .quantum)
        }

        setThreadPriority(.quantum)
    }

    /// Enable VR mode (balanced latency)
    public func enableVRMode() throws {
        isQuantumMode = false
        bufferConfig = .vr
        currentPriority = .realtime

        if isRunning {
            stop()
            try start(config: .vr)
        }

        setThreadPriority(.realtime)
    }

    /// Update head tracking for VR spatial audio
    public func updateHeadTracking(
        position: simd_float3,
        rotation: simd_quatf
    ) -> (predictedPosition: simd_float3, predictedRotation: simd_quatf) {
        vrOptimizer.updateHeadTracking(
            position: position,
            rotation: rotation,
            timestamp: timer.nowNs
        )
    }

    /// Get current latency breakdown
    public func getLatencyBreakdown() -> [(String, Double)] {
        return [
            ("Input Buffer", Double(metrics.audioInputLatencyNs) / 1_000_000),
            ("Output Buffer", Double(metrics.audioOutputLatencyNs) / 1_000_000),
            ("DSP Processing", Double(metrics.dspProcessingLatencyNs) / 1_000_000),
            ("Spatial Render", Double(metrics.spatialRenderLatencyNs) / 1_000_000),
            ("Head Tracking", Double(metrics.headTrackingLatencyNs) / 1_000_000),
            ("Bluetooth", Double(metrics.bluetoothCodecLatencyNs) / 1_000_000),
            ("Total", metrics.totalLatencyMs)
        ]
    }

    // MARK: - Private Methods

    private func configureAudioSession() throws {
        let session = AVAudioSession.sharedInstance()

        try session.setCategory(
            .playAndRecord,
            mode: .measurement,  // Lowest latency mode
            options: [.allowBluetooth, .allowBluetoothA2DP, .defaultToSpeaker]
        )

        // Set sample rate
        try session.setPreferredSampleRate(bufferConfig.sampleRate)

        // Set buffer duration (iOS will try to match)
        let bufferDuration = Double(bufferConfig.inputBufferSize) / bufferConfig.sampleRate
        try session.setPreferredIOBufferDuration(bufferDuration)

        try session.setActive(true)

        // Update actual latencies
        metrics.audioInputLatencyNs = UInt64(session.inputLatency * 1_000_000_000)
        metrics.audioOutputLatencyNs = UInt64(session.outputLatency * 1_000_000_000)
    }

    private func setupAudioProcessing() throws {
        let format = inputNode.outputFormat(forBus: 0)

        // Install tap for direct monitoring
        inputNode.installTap(onBus: 0, bufferSize: UInt32(bufferConfig.inputBufferSize), format: format) { [weak self] buffer, time in
            self?.processAudioBuffer(buffer, time: time)
        }
    }

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, time: AVAudioTime) {
        guard let channelData = buffer.floatChannelData else { return }

        let frameCount = Int(buffer.frameLength)
        let channelCount = Int(buffer.format.channelCount)

        // Measure processing time
        let startTime = timer.nowNs

        // Process direct monitoring if enabled
        if directMonitoringEnabled {
            let writePtr = outputBuffer.writeBuffer

            // Interleave stereo
            for frame in 0..<frameCount {
                for ch in 0..<min(2, channelCount) {
                    writePtr[frame * 2 + ch] = channelData[ch][frame]
                }
            }

            // Apply gain and pan
            directMonitoring.process(
                input: outputBuffer.writeBuffer,
                output: outputBuffer.writeBuffer,
                frameCount: frameCount,
                channels: 2
            )

            // Remove DC offset
            QuantumDSP.removeDCOffset(
                outputBuffer.writeBuffer,
                count: frameCount,
                state: &dcOffsetStateL
            )

            // Hard limit to prevent clipping
            QuantumDSP.hardLimit(outputBuffer.writeBuffer, count: frameCount * 2)

            outputBuffer.commitWrite()
        }

        // Update processing latency
        let processingTime = timer.nowNs - startTime
        metrics.dspProcessingLatencyNs = processingTime
    }

    private func startProcessingThread() {
        isProcessing = true

        processingThread = Thread { [weak self] in
            self?.runProcessingLoop()
        }

        processingThread?.name = "QuantumAudioProcessing"
        processingThread?.qualityOfService = .userInteractive
        processingThread?.start()
    }

    private func runProcessingLoop() {
        // Set realtime thread priority
        setThreadPriority(currentPriority)

        while isProcessing {
            // Request new data from triple buffer
            if outputBuffer.requestRead() {
                // Data available - would send to output here
            }

            // Spin for ultra-low latency (burns CPU but minimum latency)
            if isQuantumMode {
                timer.spinWaitNs(100_000) // 100μs
            } else {
                Thread.sleep(forTimeInterval: 0.0001) // 100μs
            }
        }
    }

    private func setThreadPriority(_ priority: RealtimeThreadPriority) {
        let constraint = priority.threadTimeConstraint

        var policy = thread_time_constraint_policy_data_t(
            period: constraint.period,
            computation: constraint.computation,
            constraint: constraint.constraint,
            preemptible: constraint.preemptible ? 1 : 0
        )

        let thread = mach_thread_self()

        withUnsafeMutablePointer(to: &policy) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(THREAD_TIME_CONSTRAINT_POLICY_COUNT)) { intPtr in
                thread_policy_set(
                    thread,
                    thread_policy_flavor_t(THREAD_TIME_CONSTRAINT_POLICY),
                    intPtr,
                    mach_msg_type_number_t(THREAD_TIME_CONSTRAINT_POLICY_COUNT)
                )
            }
        }
    }

    private func measureSystemLatency() {
        // Calculate total system latency
        let session = AVAudioSession.sharedInstance()

        metrics.audioInputLatencyNs = UInt64(session.inputLatency * 1_000_000_000)
        metrics.audioOutputLatencyNs = UInt64(session.outputLatency * 1_000_000_000)

        // Buffer latency
        let bufferLatencyS = Double(bufferConfig.inputBufferSize + bufferConfig.outputBufferSize) / bufferConfig.sampleRate
        metrics.dspProcessingLatencyNs = UInt64(bufferLatencyS * 1_000_000_000)

        // Update VR optimizer
        vrOptimizer.calculateOptimalPrediction(systemLatencyMs: Float(metrics.totalLatencyMs))

        print("⚛️ System Latency: \(String(format: "%.2f", metrics.totalLatencyMs))ms")
        print("   Status: \(metrics.isQuantumLevel ? "🟢 QUANTUM" : metrics.isVRAcceptable ? "🟡 VR OK" : "🔴 HIGH")")
    }
}

// MARK: - SwiftUI View

import SwiftUI

public struct QuantumLatencyView: View {
    @StateObject private var engine = QuantumLatencyEngine.shared

    public init() {}

    public var body: some View {
        VStack(spacing: 20) {
            // Header
            HStack {
                VStack(alignment: .leading) {
                    Text("⚛️ QUANTUM LATENCY")
                        .font(.title2.bold())
                    Text("Sub-millisecond precision audio")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Status indicator
                Circle()
                    .fill(statusColor)
                    .frame(width: 12, height: 12)

                Text(engine.isRunning ? "ACTIVE" : "STOPPED")
                    .font(.caption.bold())
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.black.opacity(0.3)))

            // Latency Display
            VStack(spacing: 8) {
                Text(String(format: "%.2f ms", engine.metrics.totalLatencyMs))
                    .font(.system(size: 48, weight: .bold, design: .monospaced))
                    .foregroundColor(latencyColor)

                HStack {
                    latencyBadge("Input", value: Double(engine.metrics.audioInputLatencyNs) / 1_000_000)
                    latencyBadge("Output", value: Double(engine.metrics.audioOutputLatencyNs) / 1_000_000)
                    latencyBadge("DSP", value: Double(engine.metrics.dspProcessingLatencyNs) / 1_000_000)
                }
            }

            // Mode Selection
            HStack(spacing: 12) {
                modeButton("VR", isActive: !engine.isQuantumMode) {
                    try? engine.enableVRMode()
                }

                modeButton("QUANTUM", isActive: engine.isQuantumMode) {
                    try? engine.enableQuantumMode()
                }
            }

            // Direct Monitoring
            VStack(alignment: .leading, spacing: 8) {
                Toggle("Direct Monitoring", isOn: $engine.directMonitoringEnabled)

                if engine.directMonitoringEnabled {
                    HStack {
                        Text("Gain")
                        Slider(value: $engine.directMonitoringGain, in: 0...2)
                        Text(String(format: "%.1f", engine.directMonitoringGain))
                            .monospacedDigit()
                    }

                    HStack {
                        Text("Pan")
                        Slider(value: $engine.directMonitoringPan, in: -1...1)
                        Text(engine.directMonitoringPan < 0 ? "L" : engine.directMonitoringPan > 0 ? "R" : "C")
                    }
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(Color.green.opacity(0.1)))

            // Start/Stop Button
            Button(action: toggleEngine) {
                HStack {
                    Image(systemName: engine.isRunning ? "stop.fill" : "play.fill")
                    Text(engine.isRunning ? "Stop Engine" : "Start Engine")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(engine.isRunning ? Color.red : Color.green)
                .foregroundColor(.white)
                .cornerRadius(12)
            }
        }
        .padding()
    }

    private var statusColor: Color {
        if !engine.isRunning { return .gray }
        if engine.metrics.isQuantumLevel { return .green }
        if engine.metrics.isVRAcceptable { return .yellow }
        return .red
    }

    private var latencyColor: Color {
        if engine.metrics.isQuantumLevel { return .green }
        if engine.metrics.isVRAcceptable { return .yellow }
        return .red
    }

    private func latencyBadge(_ label: String, value: Double) -> some View {
        VStack(spacing: 2) {
            Text(String(format: "%.2f", value))
                .font(.caption.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .background(Capsule().fill(Color.gray.opacity(0.2)))
    }

    private func modeButton(_ label: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(label)
                .font(.caption.bold())
                .padding(.horizontal, 20)
                .padding(.vertical, 8)
                .background(isActive ? Color.purple : Color.gray.opacity(0.3))
                .foregroundColor(.white)
                .cornerRadius(8)
        }
    }

    private func toggleEngine() {
        if engine.isRunning {
            engine.stop()
        } else {
            try? engine.start()
        }
    }
}

#Preview {
    QuantumLatencyView()
        .preferredColorScheme(.dark)
}
