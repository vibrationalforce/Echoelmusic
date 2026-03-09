#if canImport(AVFoundation)
import AVFoundation
import SwiftUI
import Accelerate
import Observation

/// Manages microphone access and advanced audio processing
/// Now includes FFT for frequency detection and professional-grade DSP
@MainActor
@Observable
final class MicrophoneManager: NSObject {

    // MARK: - Observed Properties

    /// Current audio level (0.0 to 1.0)
    var audioLevel: Float = 0.0

    /// Detected frequency in Hz (fundamental pitch from FFT)
    var frequency: Float = 0.0

    /// Current pitch in Hz (fundamental frequency from YIN algorithm)
    var currentPitch: Float = 0.0

    /// Whether we have microphone permission
    var hasPermission: Bool = false

    /// Whether we're currently recording
    var isRecording: Bool = false

    /// Audio buffer for waveform visualization (last 512 samples)
    var audioBuffer: [Float]? = nil

    /// FFT magnitudes for spectral visualization (256 bins)
    var fftMagnitudes: [Float]? = nil


    // MARK: - Private Properties

    /// The audio engine that processes audio input
    nonisolated(unsafe) private var audioEngine: AVAudioEngine?

    /// The input node that captures microphone data
    private var inputNode: AVAudioInputNode?

    /// FFT setup for frequency analysis
    private var complexDFT: EchoelComplexDFT?

    /// Buffer size for FFT (power of 2)
    /// Reduced from 2048 to 1024 for lower latency (46ms → 23ms)
    /// Trade-off: frequency resolution 21.5Hz → 43Hz per bin (still acceptable)
    private let fftSize = 1024

    /// Sample rate (will be set from audio format)
    private var sampleRate: Double = AudioConfiguration.preferredSampleRate

    /// YIN pitch detector for fundamental frequency estimation
    private let pitchDetector = PitchDetector()

    /// Dedicated queue for FFT/pitch processing — keeps audio render thread unblocked
    private let processingQueue = DispatchQueue(label: "com.echoelmusic.audio.processing", qos: .userInteractive)

    // MARK: - Pre-allocated FFT Buffers (avoid per-callback allocation)

    /// Pre-allocated buffers for FFT processing — reused every callback
    private var fftRealParts: [Float]
    private var fftWindow: [Float]
    private var fftWindowedParts: [Float]
    private var fftImagZeros: [Float]
    private var fftMagnitudesBuffer: [Float]
    private var fftVisualMagnitudes: [Float]
    private var capturedBufferStorage: [Float]

    // MARK: - Initialization

    override init() {
        // Pre-allocate FFT buffers to avoid per-callback heap allocation
        self.fftRealParts = [Float](repeating: 0, count: fftSize)
        self.fftWindow = [Float](repeating: 0, count: fftSize)
        self.fftWindowedParts = [Float](repeating: 0, count: fftSize)
        self.fftImagZeros = [Float](repeating: 0, count: fftSize)
        self.fftMagnitudesBuffer = [Float](repeating: 0, count: fftSize / 2)
        self.fftVisualMagnitudes = [Float](repeating: 0, count: 256)
        self.capturedBufferStorage = [Float](repeating: 0, count: 512)

        super.init()

        // Pre-compute Hann window once (never changes)
        vDSP_hann_window(&fftWindow, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        checkPermission()
    }


    // MARK: - Permission Handling

    /// Check if we already have microphone permission
    private func checkPermission() {
        #if os(macOS)
        hasPermission = false // macOS handles mic permission via system dialog on first use
        #elseif os(watchOS) || os(tvOS)
        hasPermission = false
        #else
        if #available(iOS 17.0, *) {
            hasPermission = AVAudioApplication.shared.recordPermission == .granted
        } else {
            switch AVAudioSession.sharedInstance().recordPermission {
            case .granted:
                hasPermission = true
            case .denied, .undetermined:
                hasPermission = false
            @unknown default:
                hasPermission = false
            }
        }
        #endif
    }

    /// Request microphone permission from the user
    func requestPermission() {
        #if os(macOS) || os(watchOS) || os(tvOS)
        log.audio("Microphone permission request not supported on this platform", level: .warning)
        #else
        if #available(iOS 17.0, *) {
            Task {
                let granted = await AVAudioApplication.requestRecordPermission()
                await MainActor.run {
                    self.hasPermission = granted
                    if granted {
                        log.audio("Microphone permission granted")
                        try? AudioConfiguration.upgradeToPlayAndRecord()
                    } else {
                        log.audio("Microphone permission denied", level: .error)
                    }
                }
            }
        } else {
            AVAudioSession.sharedInstance().requestRecordPermission { [weak self] granted in
                Task { @MainActor in
                    self?.hasPermission = granted
                    if granted {
                        log.audio("Microphone permission granted")
                        try? AudioConfiguration.upgradeToPlayAndRecord()
                    } else {
                        log.audio("Microphone permission denied", level: .error)
                    }
                }
            }
        }
        #endif
    }


    // MARK: - Recording Control

    /// Start recording audio from the microphone
    func startRecording() {
        guard hasPermission else {
            log.audio("⚠️ Cannot start recording: No microphone permission", level: .warning)
            requestPermission()
            return
        }

        do {
            // DO NOT override audio session category here.
            // AudioConfiguration.configureAudioSession() already sets .playAndRecord
            // which supports both mic input and audio output.
            // Setting .record here would kill ALL audio output (synths, drums, playback).
            // .measurement mode also disables Bluetooth codec negotiation (A2DP/AAC).
            #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
            if !AudioConfiguration.isSessionConfigured {
                try AudioConfiguration.configureAudioSession()
            }
            #endif

            // Create and configure the audio engine
            audioEngine = AVAudioEngine()
            guard let audioEngine = audioEngine else {
                log.error("MicrophoneManager: failed to create AVAudioEngine", category: .audio)
                return
            }

            inputNode = audioEngine.inputNode

            // Get the input format from the microphone
            let recordingFormat = inputNode?.outputFormat(forBus: 0)
            guard let format = recordingFormat else {
                log.error("MicrophoneManager: failed to get microphone input format", category: .audio)
                return
            }

            // Store sample rate for frequency calculation
            sampleRate = format.sampleRate

            // Setup FFT
            complexDFT = EchoelComplexDFT(size: fftSize)

            // Install a tap to capture audio data — dispatch off the audio render thread
            // Capture sampleRate locally to avoid reading @MainActor property from processingQueue
            let capturedSampleRate = sampleRate
            inputNode?.installTap(onBus: 0, bufferSize: UInt32(fftSize), format: format) { [weak self] buffer, _ in
                self?.processingQueue.async {
                    self?.processAudioBuffer(buffer, sampleRate: capturedSampleRate)
                }
            }

            // Prepare and start the audio engine
            audioEngine.prepare()
            try audioEngine.start()

            self.isRecording = true

            log.audio("🎙️ Recording started with FFT enabled")

        } catch {
            log.audio("❌ Failed to start recording: \(error.localizedDescription)", level: .error)
            self.isRecording = false
        }
    }

    /// Stop recording audio
    func stopRecording() {
        // Safely stop the audio engine
        if let engine = audioEngine, engine.isRunning {
            engine.stop()
            engine.inputNode.removeTap(onBus: 0)
        }

        audioEngine = nil
        inputNode = nil

        // Release FFT wrapper
        complexDFT = nil

        // Deactivate the audio session
        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        try? AVAudioSession.sharedInstance().setActive(false)
        #endif

        self.isRecording = false
        self.audioLevel = 0.0
        self.frequency = 0.0
        self.currentPitch = 0.0

        log.audio("⏹️ Recording stopped")
    }


    // MARK: - Audio Processing with FFT

    /// Process incoming audio data with FFT for frequency detection
    /// sampleRate is passed explicitly to avoid reading @MainActor property from processingQueue
    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer, sampleRate: Double) {
        guard let channelData = buffer.floatChannelData else { return }

        let frameLength = Int(buffer.frameLength)
        let channelDataValue = channelData.pointee

        // Calculate RMS (amplitude/volume)
        var sumSquares: Float = 0.0
        vDSP_measqv(channelDataValue, 1, &sumSquares, vDSP_Length(frameLength))
        let rms = sqrt(sumSquares)

        // Normalize to 0-1 range with better sensitivity
        let normalizedLevel = min(rms * 15.0, 1.0)

        // Capture audio buffer for waveform visualization (last 512 samples)
        // Uses pre-allocated storage to avoid per-callback allocation
        let bufferSampleCount = min(512, frameLength)
        cblas_scopy(Int32(bufferSampleCount), channelDataValue, 1, &capturedBufferStorage, 1)
        let capturedBuffer = Array(capturedBufferStorage.prefix(bufferSampleCount))

        // Perform FFT for frequency detection and get magnitudes
        let (detectedFrequency, magnitudes) = performFFT(on: channelDataValue, frameLength: frameLength, sampleRate: sampleRate)

        // Perform YIN pitch detection for fundamental frequency
        let detectedPitch = pitchDetector.detectPitch(buffer: buffer, sampleRate: Float(sampleRate))


        // Update UI on main actor with smoothing
        Task { @MainActor [weak self] in
            guard let self = self else { return }

            // Smooth audio level changes
            self.audioLevel = self.audioLevel * 0.7 + normalizedLevel * 0.3

            // Smooth frequency changes (only update if significantly different)
            if detectedFrequency > 50 { // Ignore very low frequencies (likely noise)
                self.frequency = self.frequency * 0.8 + detectedFrequency * 0.2
            }

            // Smooth pitch changes (YIN is more robust than FFT for voice)
            if detectedPitch > 0 {
                self.currentPitch = self.currentPitch * 0.8 + detectedPitch * 0.2
            } else {
                // Decay pitch to zero if no pitch detected
                self.currentPitch *= 0.9
            }

            // Update audio buffer and FFT magnitudes for visualizations
            self.audioBuffer = capturedBuffer
            self.fftMagnitudes = magnitudes
        }
    }

    /// Perform FFT to detect fundamental frequency and return magnitudes
    /// Uses pre-allocated buffers (fftRealParts, fftWindowedParts, etc.) to avoid
    /// per-callback heap allocation on the processing queue.
    private func performFFT(on data: UnsafePointer<Float>, frameLength: Int, sampleRate: Double) -> (frequency: Float, magnitudes: [Float]) {
        guard let dft = complexDFT else { return (0, []) }

        // Zero-fill pre-allocated buffer, then copy audio data
        memset(&fftRealParts, 0, fftSize * MemoryLayout<Float>.size)
        let copyLength = min(frameLength, fftSize)
        memcpy(&fftRealParts, data, copyLength * MemoryLayout<Float>.size)

        // Apply pre-computed Hann window to reduce spectral leakage
        vDSP_vmul(fftRealParts, 1, fftWindow, 1, &fftWindowedParts, 1, vDSP_Length(fftSize))

        // Perform FFT via EchoelComplexDFT (handles overlapping access safety internally)
        let result = dft.forward(real: fftWindowedParts, imag: fftImagZeros)
        let realParts = result.real
        let imagParts = result.imag

        // Calculate magnitudes (power spectrum) into pre-allocated buffer
        let halfSize = fftSize / 2
        for i in 0..<halfSize {
            fftMagnitudesBuffer[i] = sqrt(realParts[i] * realParts[i] + imagParts[i] * imagParts[i])
        }

        // Downsample magnitudes for visualization (256 bins for spectral mode)
        let visualBins = 256
        let binRatio = Swift.max(1, halfSize / visualBins)
        for i in 0..<visualBins {
            let startIdx = i * binRatio
            let endIdx = min(startIdx + binRatio, halfSize)
            guard startIdx < halfSize else { break }
            var sum: Float = 0
            for j in startIdx..<endIdx {
                sum += fftMagnitudesBuffer[j]
            }
            fftVisualMagnitudes[i] = sum / Float(binRatio)
        }

        // Find peak frequency (ignore DC component at index 0)
        guard halfSize > 1 else { return (0, Array(fftVisualMagnitudes)) }
        var maxMagnitude: Float = 0
        var maxIndex: vDSP_Length = 0

        vDSP_maxvi(Array(fftMagnitudesBuffer[1...]), 1, &maxMagnitude, &maxIndex, vDSP_Length(halfSize - 1))
        maxIndex += 1 // Adjust for skipping index 0

        // Convert bin index to frequency
        let frequency = Float(maxIndex) * Float(sampleRate) / Float(fftSize)

        // Return copy of visual magnitudes for UI (must be independent of mutable buffer)
        let visualResult = Array(fftVisualMagnitudes)

        // Only return frequencies in audible/useful range
        if frequency > 50 && frequency < 2000 && maxMagnitude > 0.01 {
            return (frequency, visualResult)
        }

        return (0.0, visualResult)
    }


    // MARK: - Cleanup

    /// Clean up when the object is destroyed
    deinit {
        if let engine = audioEngine, engine.isRunning {
            engine.stop()
        }
        audioEngine = nil
    }
}
#endif
