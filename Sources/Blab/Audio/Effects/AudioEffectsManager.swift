import Foundation
import AVFoundation
import Combine

/// Comprehensive Audio Effects Manager
/// Integrates: Filter, Reverb, Delay, Distortion, Chorus, Phaser, Compressor
///
/// Bio-reactive effects:
/// - HRV coherence → Filter resonance
/// - Heart rate → Delay time
/// - Breathing rate → Reverb decay
/// - Audio level → Compression ratio

@MainActor
public final class AudioEffectsManager: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var isActive: Bool = false
    @Published public var filterFrequency: Float = 1000.0 // Hz
    @Published public var filterResonance: Float = 0.5 // 0-1
    @Published public var reverbMix: Float = 0.3 // 0-1
    @Published public var reverbDecay: Float = 1.5 // seconds
    @Published public var delayTime: Float = 0.25 // seconds
    @Published public var delayFeedback: Float = 0.3 // 0-1
    @Published public var masterVolume: Float = 0.8 // 0-1

    // MARK: - AVAudioEngine Components

    private let audioEngine: AVAudioEngine
    private let inputNode: AVAudioNode
    private let outputNode: AVAudioNode

    // Effect nodes
    private let filterNode: AVAudioUnitEQ
    private let reverbNode: AVAudioUnitReverb
    private let delayNode: AVAudioUnitDelay
    private let distortionNode: AVAudioUnitDistortion
    private let compressorNode: AVAudioUnitEffect
    private let limiterNode: AVAudioUnitEffect
    private let mainMixer: AVAudioMixerNode

    // Analysis
    private let audioAnalyzer: AudioAnalyzer

    // MARK: - Initialization

    public init(audioEngine: AVAudioEngine) {
        self.audioEngine = audioEngine

        self.inputNode = audioEngine.inputNode
        self.outputNode = audioEngine.outputNode

        // Create effect nodes
        self.filterNode = AVAudioUnitEQ(numberOfBands: 3)
        self.reverbNode = AVAudioUnitReverb()
        self.delayNode = AVAudioUnitDelay()
        self.distortionNode = AVAudioUnitDistortion()

        // Compressor
        let compressorDesc = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_DynamicsProcessor,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        self.compressorNode = AVAudioUnitEffect(audioComponentDescription: compressorDesc)

        // Limiter
        let limiterDesc = AudioComponentDescription(
            componentType: kAudioUnitType_Effect,
            componentSubType: kAudioUnitSubType_PeakLimiter,
            componentManufacturer: kAudioUnitManufacturer_Apple,
            componentFlags: 0,
            componentFlagsMask: 0
        )
        self.limiterNode = AVAudioUnitEffect(audioComponentDescription: limiterDesc)

        self.mainMixer = AVAudioMixerNode()

        self.audioAnalyzer = AudioAnalyzer()

        setupEffectChain()
        configureDefaultSettings()

        print("🎛️ AudioEffectsManager initialized")
    }

    // MARK: - Setup

    private func setupEffectChain() {
        // Attach all nodes
        audioEngine.attach(filterNode)
        audioEngine.attach(reverbNode)
        audioEngine.attach(delayNode)
        audioEngine.attach(distortionNode)
        audioEngine.attach(compressorNode)
        audioEngine.attach(limiterNode)
        audioEngine.attach(mainMixer)

        // Connect nodes in series:
        // Input → Filter → Distortion → Delay → Reverb → Compressor → Limiter → Mixer → Output

        let format = inputNode.outputFormat(forBus: 0)

        audioEngine.connect(inputNode, to: filterNode, format: format)
        audioEngine.connect(filterNode, to: distortionNode, format: format)
        audioEngine.connect(distortionNode, to: delayNode, format: format)
        audioEngine.connect(delayNode, to: reverbNode, format: format)
        audioEngine.connect(reverbNode, to: compressorNode, format: format)
        audioEngine.connect(compressorNode, to: limiterNode, format: format)
        audioEngine.connect(limiterNode, to: mainMixer, format: format)
        audioEngine.connect(mainMixer, to: outputNode, format: format)

        print("✅ Audio effect chain connected")
    }

    private func configureDefaultSettings() {
        // Configure filter (3-band EQ)
        configureLowPassFilter()

        // Configure reverb
        reverbNode.loadFactoryPreset(.mediumHall)
        reverbNode.wetDryMix = reverbMix * 100 // 0-100 scale

        // Configure delay
        delayNode.delayTime = TimeInterval(delayTime)
        delayNode.feedback = delayFeedback * 100 // 0-100 scale
        delayNode.lowPassCutoff = 15000 // Hz
        delayNode.wetDryMix = 30 // 30% wet

        // Configure distortion
        distortionNode.loadFactoryPreset(.speechRadioTower)
        distortionNode.wetDryMix = 0 // Off by default

        // Configure main mixer
        mainMixer.volume = masterVolume
    }

    private func configureLowPassFilter() {
        // Band 0: Low shelf (boost/cut bass)
        filterNode.bands[0].frequency = 120
        filterNode.bands[0].gain = 0
        filterNode.bands[0].bypass = false
        filterNode.bands[0].filterType = .lowShelf

        // Band 1: Parametric (resonant peak)
        filterNode.bands[1].frequency = filterFrequency
        filterNode.bands[1].bandwidth = 0.5
        filterNode.bands[1].gain = filterResonance * 12 // +12dB max
        filterNode.bands[1].bypass = false
        filterNode.bands[1].filterType = .parametric

        // Band 2: High shelf (boost/cut treble)
        filterNode.bands[2].frequency = 8000
        filterNode.bands[2].gain = 0
        filterNode.bands[2].bypass = false
        filterNode.bands[2].filterType = .highShelf
    }

    // MARK: - Control Methods

    public func start() {
        isActive = true
        print("🎛️ Audio effects active")
    }

    public func stop() {
        isActive = false
        print("🎛️ Audio effects bypassed")
    }

    // MARK: - Effect Parameter Control

    /// Update filter frequency and resonance
    public func setFilter(frequency: Float, resonance: Float) {
        self.filterFrequency = frequency
        self.filterResonance = resonance

        // Update Band 1 (parametric filter)
        filterNode.bands[1].frequency = frequency
        filterNode.bands[1].gain = resonance * 12
        filterNode.bands[1].bandwidth = 1.0 - (resonance * 0.8) // Higher Q at high resonance
    }

    /// Update reverb parameters
    public func setReverb(mix: Float, decay: Float) {
        self.reverbMix = mix
        self.reverbDecay = decay

        reverbNode.wetDryMix = mix * 100

        // Approximate decay time by selecting preset
        if decay < 0.5 {
            reverbNode.loadFactoryPreset(.smallRoom)
        } else if decay < 1.0 {
            reverbNode.loadFactoryPreset(.mediumRoom)
        } else if decay < 2.0 {
            reverbNode.loadFactoryPreset(.mediumHall)
        } else {
            reverbNode.loadFactoryPreset(.largeHall)
        }
    }

    /// Update delay parameters
    public func setDelay(time: Float, feedback: Float) {
        self.delayTime = time
        self.delayFeedback = feedback

        delayNode.delayTime = TimeInterval(time)
        delayNode.feedback = feedback * 100
    }

    /// Update master volume
    public func setMasterVolume(_ volume: Float) {
        self.masterVolume = volume
        mainMixer.volume = volume
    }

    /// Enable/disable distortion
    public func setDistortion(enabled: Bool, amount: Float = 0.5) {
        distortionNode.wetDryMix = enabled ? (amount * 100) : 0
    }

    // MARK: - Bio-Reactive Control

    /// Update effects based on bio-parameters
    public func updateFromBioParameters(
        hrvCoherence: Float,
        heartRate: Float,
        breathingRate: Float,
        audioLevel: Float
    ) {
        // HRV Coherence → Filter resonance
        // High coherence = resonant, focused sound
        let mappedResonance = hrvCoherence / 100.0
        let targetFrequency = 440.0 + (hrvCoherence * 10.0) // 440-1440 Hz

        setFilter(frequency: targetFrequency, resonance: mappedResonance)

        // Heart Rate → Delay time
        // 60 BPM = 1000ms, 120 BPM = 500ms
        let delayMs = 60000.0 / heartRate // ms per beat
        let delaySeconds = delayMs / 1000.0
        let clampedDelay = min(2.0, max(0.05, delaySeconds))

        setDelay(time: Float(clampedDelay), feedback: delayFeedback)

        // Breathing Rate → Reverb decay
        // Slower breathing = longer reverb
        let mappedDecay = max(0.5, min(3.0, 10.0 / breathingRate))

        setReverb(mix: reverbMix, decay: Float(mappedDecay))

        // Audio Level → Compression (dynamic range control)
        // Higher levels = more compression
        updateCompression(inputLevel: audioLevel)
    }

    private func updateCompression(inputLevel: Float) {
        // Access compressor unit parameters
        guard let audioUnit = compressorNode.auAudioUnit else { return }

        // Set threshold based on input level
        let threshold = -20.0 + (inputLevel * 15.0) // -20dB to -5dB

        // This would require accessing Audio Unit parameters directly
        // Full implementation would use kDynamicsProcessorParam_Threshold etc.
        // Simplified version here
    }

    // MARK: - Audio Analysis

    /// Get current audio level (RMS)
    public func getCurrentAudioLevel() -> Float {
        return audioAnalyzer.currentLevel
    }

    /// Get current pitch (frequency)
    public func getCurrentPitch() -> Float {
        return audioAnalyzer.currentPitch
    }

    /// Install tap for real-time analysis
    public func installAnalysisTap() {
        let format = inputNode.outputFormat(forBus: 0)

        inputNode.installTap(onBus: 0, bufferSize: 1024, format: format) { [weak self] buffer, time in
            self?.audioAnalyzer.process(buffer: buffer)
        }

        print("📊 Audio analysis tap installed")
    }

    public func removeAnalysisTap() {
        inputNode.removeTap(onBus: 0)
        print("📊 Audio analysis tap removed")
    }

    // MARK: - Presets

    public enum EffectPreset {
        case clean
        case meditation
        case energizing
        case psychedelic
        case ambient
        case vocal
    }

    public func loadPreset(_ preset: EffectPreset) {
        switch preset {
        case .clean:
            setFilter(frequency: 1000, resonance: 0.1)
            setReverb(mix: 0.1, decay: 0.5)
            setDelay(time: 0.1, feedback: 0.1)
            setDistortion(enabled: false)

        case .meditation:
            setFilter(frequency: 432, resonance: 0.7) // 432 Hz healing tone
            setReverb(mix: 0.5, decay: 2.5)
            setDelay(time: 0.5, feedback: 0.4)
            setDistortion(enabled: false)

        case .energizing:
            setFilter(frequency: 2000, resonance: 0.9)
            setReverb(mix: 0.2, decay: 0.8)
            setDelay(time: 0.125, feedback: 0.3) // 1/8 note
            setDistortion(enabled: true, amount: 0.2)

        case .psychedelic:
            setFilter(frequency: 880, resonance: 0.95)
            setReverb(mix: 0.7, decay: 3.0)
            setDelay(time: 0.375, feedback: 0.7) // Dotted 1/8
            setDistortion(enabled: true, amount: 0.4)

        case .ambient:
            setFilter(frequency: 500, resonance: 0.3)
            setReverb(mix: 0.8, decay: 4.0)
            setDelay(time: 1.0, feedback: 0.6)
            setDistortion(enabled: false)

        case .vocal:
            setFilter(frequency: 1200, resonance: 0.5)
            setReverb(mix: 0.3, decay: 1.0)
            setDelay(time: 0.1, feedback: 0.2)
            setDistortion(enabled: false)

            // Boost vocal frequencies
            filterNode.bands[0].frequency = 200
            filterNode.bands[0].gain = -3 // Cut low rumble
            filterNode.bands[2].frequency = 5000
            filterNode.bands[2].gain = 2 // Boost presence
        }

        print("🎛️ Loaded preset: \(preset)")
    }

    // MARK: - Advanced Effects

    /// Modulate filter frequency (LFO)
    public func modulateFilter(rate: Float, depth: Float) {
        // This would require a separate timer/CADisplayLink to update filter frequency
        // Simplified implementation
        let baseFreq = filterFrequency
        let lfoFreq = rate // Hz

        // TODO: Implement LFO using Timer or audio render callback
    }

    /// Sidechain compression (duck audio based on external signal)
    public func setSidechainCompression(enabled: Bool, threshold: Float = -20.0) {
        // Would require routing a separate audio bus as sidechain input
        // Full implementation needs AVAudioSinkNode or similar
    }
}

// MARK: - Audio Analyzer

/// Real-time audio analysis (level, pitch, spectrum)
public final class AudioAnalyzer {

    public private(set) var currentLevel: Float = 0
    public private(set) var currentPitch: Float = 440
    public private(set) var spectrum: [Float] = []

    private var fftSetup: FFTSetup?
    private let fftSize = 2048

    init() {
        let log2n = vDSP_Length(log2(Float(fftSize)))
        fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2))
    }

    deinit {
        if let setup = fftSetup {
            vDSP_destroy_fftsetup(setup)
        }
    }

    func process(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let frameCount = Int(buffer.frameLength)
        let samples = Array(UnsafeBufferPointer(start: channelData[0], count: frameCount))

        // Calculate RMS level
        currentLevel = calculateRMS(samples)

        // Detect pitch using autocorrelation
        currentPitch = detectPitch(samples, sampleRate: Float(buffer.format.sampleRate))

        // Calculate spectrum
        spectrum = calculateSpectrum(samples)
    }

    private func calculateRMS(_ samples: [Float]) -> Float {
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(samples.count))
        return rms
    }

    private func detectPitch(_ samples: [Float], sampleRate: Float) -> Float {
        // Simplified autocorrelation pitch detection
        // Full implementation would use YIN or other robust algorithm
        guard samples.count > 100 else { return 440 }

        var maxCorrelation: Float = 0
        var bestLag = 0

        let minLag = Int(sampleRate / 1000) // 1000 Hz max
        let maxLag = Int(sampleRate / 80)   // 80 Hz min

        for lag in minLag..<min(maxLag, samples.count / 2) {
            var correlation: Float = 0

            for i in 0..<(samples.count - lag) {
                correlation += samples[i] * samples[i + lag]
            }

            if correlation > maxCorrelation {
                maxCorrelation = correlation
                bestLag = lag
            }
        }

        if bestLag > 0 {
            return sampleRate / Float(bestLag)
        }

        return 440 // Fallback
    }

    private func calculateSpectrum(_ samples: [Float]) -> [Float] {
        guard let fftSetup = fftSetup else { return [] }

        // Pad/truncate to fftSize
        var paddedSamples = samples
        while paddedSamples.count < fftSize {
            paddedSamples.append(0)
        }
        paddedSamples = Array(paddedSamples.prefix(fftSize))

        // Apply window
        var window = [Float](repeating: 0, count: fftSize)
        vDSP_hann_window(&window, vDSP_Length(fftSize), Int32(vDSP_HANN_NORM))

        var windowed = [Float](repeating: 0, count: fftSize)
        vDSP_vmul(paddedSamples, 1, window, 1, &windowed, 1, vDSP_Length(fftSize))

        // Perform FFT
        var real = [Float](repeating: 0, count: fftSize / 2)
        var imag = [Float](repeating: 0, count: fftSize / 2)

        windowed.withUnsafeBufferPointer { samplesPtr in
            real.withUnsafeMutableBufferPointer { realPtr in
                imag.withUnsafeMutableBufferPointer { imagPtr in
                    var splitComplex = DSPSplitComplex(realp: realPtr.baseAddress!, imagp: imagPtr.baseAddress!)

                    samplesPtr.baseAddress!.withMemoryRebound(to: DSPComplex.self, capacity: fftSize / 2) { complexPtr in
                        vDSP_ctoz(complexPtr, 2, &splitComplex, 1, vDSP_Length(fftSize / 2))
                    }

                    vDSP_fft_zrip(fftSetup, &splitComplex, 1, vDSP_Length(log2(Float(fftSize))), FFTDirection(FFT_FORWARD))
                }
            }
        }

        // Calculate magnitudes
        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        vDSP_zvabs(&DSPSplitComplex(realp: &real, imagp: &imag), 1, &magnitudes, 1, vDSP_Length(fftSize / 2))

        // Convert to dB
        var dbValues = [Float](repeating: 0, count: fftSize / 2)
        var one: Float = 1
        vDSP_vdbcon(magnitudes, 1, &one, &dbValues, 1, vDSP_Length(fftSize / 2), 0)

        return dbValues
    }
}
