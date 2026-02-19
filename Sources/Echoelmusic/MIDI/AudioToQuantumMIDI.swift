// AudioToQuantumMIDI.swift
// Echoelmusic - Universal Audio Input to Quantum MIDI Bridge
// λ∞ Ralph Wiggum Apple Ökosystem Environment Lambda Loop Mode
//
// "Mein Klinken-Kabel schmeckt nach Quantenverschränkung!" - Ralph Wiggum
//
// Created 2026-01-21 - Phase 10000.3 UNIVERSAL AUDIO INPUT
//
// ═══════════════════════════════════════════════════════════════════════════════
// UNTERSTÜTZTE EINGABEN:
// - Mikrofon (eingebaut + extern)
// - Line-In / Klinke (3.5mm / 6.3mm via Interface)
// - Audio Interface (Focusrite, Universal Audio, etc.)
// - Audio Files (WAV, AIFF, MP3, M4A)
// - Polyphone Instrumente (Gitarre, Keyboard via Audio)
// - Bluetooth Audio (AirPods, etc.)
// ═══════════════════════════════════════════════════════════════════════════════

import Foundation
import AVFoundation
import Combine
import Accelerate

// MARK: - Audio Input Source

/// Available audio input sources
public enum AudioInputSource: String, CaseIterable, Identifiable, Sendable {
    case microphone = "Mikrofon"
    case lineIn = "Line-In / Klinke"
    case audioInterface = "Audio Interface"
    case audioFile = "Audio Datei"
    case bluetooth = "Bluetooth Audio"
    case aggregate = "Aggregat (Mehrere)"

    public var id: String { rawValue }

    public var systemIcon: String {
        switch self {
        case .microphone: return "mic.fill"
        case .lineIn: return "cable.connector"
        case .audioInterface: return "rectangle.connected.to.line.below"
        case .audioFile: return "doc.richtext.fill"
        case .bluetooth: return "airpodspro"
        case .aggregate: return "square.stack.3d.up.fill"
        }
    }
}

// MARK: - Pitch Detection Mode

/// Pitch detection algorithms optimized for different sources
public enum PitchDetectionMode: String, CaseIterable, Identifiable, Sendable {
    case monophonic = "Monophon (Stimme/Solo)"
    case polyphonic = "Polyphon (Akkorde/Gitarre)"
    case percussive = "Perkussiv (Drums)"
    case hybrid = "Hybrid (Automatisch)"

    public var id: String { rawValue }

    public var description: String {
        switch self {
        case .monophonic: return "YIN-Algorithmus für einzelne Noten"
        case .polyphonic: return "FFT + Peak-Detection für Akkorde"
        case .percussive: return "Onset-Detection für Rhythmus"
        case .hybrid: return "Automatische Erkennung des Typs"
        }
    }
}

// MARK: - Detected Note

/// A detected note from audio analysis
public struct DetectedNote: Identifiable, Sendable {
    public let id = UUID()
    public var midiNote: UInt8
    public var frequency: Float
    public var amplitude: Float
    public var cents: Float
    public var confidence: Float
    public var onset: Bool
    public var isPercussive: Bool

    public init(midiNote: UInt8, frequency: Float, amplitude: Float = 0.5,
                cents: Float = 0, confidence: Float = 1.0,
                onset: Bool = false, isPercussive: Bool = false) {
        self.midiNote = midiNote
        self.frequency = frequency
        self.amplitude = amplitude
        self.cents = cents
        self.confidence = confidence
        self.onset = onset
        self.isPercussive = isPercussive
    }
}

// MARK: - Audio Input Device

/// Represents an available audio input device
public struct AudioInputDevice: Identifiable, Sendable {
    public let id: String
    public let name: String
    public let manufacturer: String
    public let channelCount: Int
    public let sampleRate: Double
    public let isDefault: Bool
    public let source: AudioInputSource

    public init(id: String, name: String, manufacturer: String = "Unknown",
                channelCount: Int = 2, sampleRate: Double = 48000,
                isDefault: Bool = false, source: AudioInputSource = .microphone) {
        self.id = id
        self.name = name
        self.manufacturer = manufacturer
        self.channelCount = channelCount
        self.sampleRate = sampleRate
        self.isDefault = isDefault
        self.source = source
    }
}

// MARK: - Audio To Quantum MIDI Engine

/// Universal Audio Input to Quantum MIDI Bridge
/// Supports microphone, line-in, audio interface, and audio files
@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
@MainActor
public final class AudioToQuantumMIDI: ObservableObject {

    // MARK: - Published Properties

    @Published public var isActive: Bool = false
    @Published public var inputSource: AudioInputSource = .microphone
    @Published public var detectionMode: PitchDetectionMode = .hybrid
    @Published public var availableDevices: [AudioInputDevice] = []
    @Published public var selectedDevice: AudioInputDevice?

    // Detected notes
    @Published public private(set) var detectedNotes: [DetectedNote] = []
    @Published public private(set) var dominantNote: DetectedNote?
    @Published public private(set) var isPolyphonic: Bool = false

    // Audio levels
    @Published public private(set) var inputLevel: Float = 0
    @Published public private(set) var peakLevel: Float = 0
    @Published public private(set) var spectralCentroid: Float = 0

    // Settings
    @Published public var inputGain: Float = 1.0
    @Published public var noiseGate: Float = 0.01
    @Published public var maxPolyphony: Int = 6
    @Published public var noteOnThreshold: Float = 0.1
    @Published public var noteOffThreshold: Float = 0.05

    // Quantum MIDI routing
    @Published public var routeToQuantumMIDI: Bool = true
    @Published public var targetInstruments: [QuantumMIDIVoice.InstrumentTarget] = [.piano]

    // MARK: - Private Properties

    private var quantumMIDIOut: QuantumMIDIOut?
    private var audioEngine: AVAudioEngine?
    private var inputNode: AVAudioInputNode?
    private var audioFile: AVAudioFile?
    private var audioPlayerNode: AVAudioPlayerNode?

    // Analysis buffers
    private let pitchDetector = PitchDetector()
    private let bufferSize: Int = 4096
    private let fftSize: Int = 4096
    private var analysisBuffer: [Float] = []
    private var fftSetup: vDSP_DFT_Setup?
    private var fftRealBuffer: [Float] = []
    private var fftImagBuffer: [Float] = []
    private var magnitudeSpectrum: [Float] = []
    private var previousMagnitudes: [Float] = []

    // Note tracking
    private var activeNotes: [UInt8: DetectedNote] = [:]
    private var noteHistory: [UInt8] = []
    private var lastOnsetTime: Date = Date()

    // Polyphonic detection
    private let peakThreshold: Float = 0.02
    private let harmonicTolerance: Float = 0.03 // 3% tolerance for harmonic detection

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    public init(quantumMIDIOut: QuantumMIDIOut? = nil) {
        self.quantumMIDIOut = quantumMIDIOut
        setupFFT()
        scanAvailableDevices()
    }

    private func setupFFT() {
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)
        analysisBuffer = Array(repeating: 0, count: bufferSize)
        fftRealBuffer = Array(repeating: 0, count: fftSize)
        fftImagBuffer = Array(repeating: 0, count: fftSize)
        magnitudeSpectrum = Array(repeating: 0, count: fftSize / 2)
        previousMagnitudes = Array(repeating: 0, count: fftSize / 2)
    }

    // MARK: - Device Management

    /// Scan for available audio input devices
    public func scanAvailableDevices() {
        var devices: [AudioInputDevice] = []

        #if os(macOS)
        // On macOS, enumerate all audio devices
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioHardwarePropertyDevices,
            mScope: kAudioObjectPropertyScopeGlobal,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        AudioObjectGetPropertyDataSize(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize
        )

        let deviceCount = Int(dataSize) / MemoryLayout<AudioDeviceID>.size
        var deviceIDs = [AudioDeviceID](repeating: 0, count: deviceCount)

        AudioObjectGetPropertyData(
            AudioObjectID(kAudioObjectSystemObject),
            &propertyAddress,
            0,
            nil,
            &dataSize,
            &deviceIDs
        )

        for deviceID in deviceIDs {
            if let device = getDeviceInfo(deviceID: deviceID) {
                devices.append(device)
            }
        }
        #endif

        // Always add built-in microphone
        let builtInMic = AudioInputDevice(
            id: "built-in-mic",
            name: "Eingebautes Mikrofon",
            manufacturer: "Apple",
            channelCount: 1,
            isDefault: true,
            source: .microphone
        )
        devices.insert(builtInMic, at: 0)

        availableDevices = devices

        // Select default device
        if selectedDevice == nil {
            selectedDevice = devices.first
        }
    }

    #if os(macOS)
    private func getDeviceInfo(deviceID: AudioDeviceID) -> AudioInputDevice? {
        var propertyAddress = AudioObjectPropertyAddress(
            mSelector: kAudioDevicePropertyStreamConfiguration,
            mScope: kAudioDevicePropertyScopeInput,
            mElement: kAudioObjectPropertyElementMain
        )

        var dataSize: UInt32 = 0
        guard AudioObjectGetPropertyDataSize(deviceID, &propertyAddress, 0, nil, &dataSize) == noErr else {
            return nil
        }

        // Check if device has input channels
        let bufferListPointer = UnsafeMutablePointer<AudioBufferList>.allocate(capacity: 1)
        defer { bufferListPointer.deallocate() }

        guard AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, bufferListPointer) == noErr else {
            return nil
        }

        let channelCount = Int(bufferListPointer.pointee.mBuffers.mNumberChannels)
        guard channelCount > 0 else { return nil } // Skip output-only devices

        // Get device name
        propertyAddress.mSelector = kAudioDevicePropertyDeviceNameCFString
        var deviceName: CFString = "" as CFString
        dataSize = UInt32(MemoryLayout<CFString>.size)

        AudioObjectGetPropertyData(deviceID, &propertyAddress, 0, nil, &dataSize, &deviceName)

        // Determine source type
        let name = deviceName as String
        let source: AudioInputSource
        if name.lowercased().contains("line") || name.lowercased().contains("input") {
            source = .lineIn
        } else if name.lowercased().contains("bluetooth") || name.lowercased().contains("airpod") {
            source = .bluetooth
        } else if name.lowercased().contains("focusrite") || name.lowercased().contains("universal audio") ||
                    name.lowercased().contains("motu") || name.lowercased().contains("rme") ||
                    name.lowercased().contains("apogee") || name.lowercased().contains("presonus") {
            source = .audioInterface
        } else {
            source = .microphone
        }

        return AudioInputDevice(
            id: String(deviceID),
            name: name,
            channelCount: channelCount,
            source: source
        )
    }
    #endif

    // MARK: - Lifecycle

    /// Start audio input processing
    public func start() async throws {
        guard !isActive else { return }

        // Initialize Quantum MIDI Out if not provided
        if quantumMIDIOut == nil && routeToQuantumMIDI {
            quantumMIDIOut = QuantumMIDIOut(polyphony: 32)
            try await quantumMIDIOut?.start()
        }

        // Setup audio engine based on input source
        switch inputSource {
        case .microphone, .lineIn, .audioInterface, .bluetooth:
            try setupLiveAudioInput()
        case .audioFile:
            // Audio file requires separate load call
            break
        case .aggregate:
            try setupAggregateInput()
        }

        isActive = true
        log.audio("🎚️⚛️ AudioToQuantumMIDI ACTIVATED")
        log.audio("   Source: \(inputSource.rawValue)")
        log.audio("   Detection: \(detectionMode.rawValue)")
        log.audio("   Device: \(selectedDevice?.name ?? "Default")")
    }

    /// Stop audio input processing
    public func stop() {
        isActive = false

        // Stop all active notes
        for note in activeNotes.keys {
            sendNoteOff(note)
        }
        activeNotes.removeAll()

        // Stop audio engine
        audioPlayerNode?.stop()
        audioEngine?.stop()
        audioEngine = nil

        quantumMIDIOut?.stop()

        log.audio("🎚️⚛️ AudioToQuantumMIDI DEACTIVATED")
    }

    // MARK: - Live Audio Setup

    private func setupLiveAudioInput() throws {
        audioEngine = AVAudioEngine()

        guard let engine = audioEngine else {
            throw AudioInputError.engineSetupFailed
        }

        // Configure audio session
        #if os(iOS)
        try AVAudioSession.sharedInstance().setCategory(
            .playAndRecord,
            mode: .measurement,
            options: [.allowBluetooth, .defaultToSpeaker]
        )
        try AVAudioSession.sharedInstance().setActive(true)
        #endif

        inputNode = engine.inputNode
        let format = inputNode?.outputFormat(forBus: 0)

        guard let audioFormat = format, audioFormat.sampleRate > 0 else {
            throw AudioInputError.invalidFormat
        }

        // Install tap for audio analysis
        inputNode?.installTap(onBus: 0, bufferSize: AVAudioFrameCount(bufferSize), format: audioFormat) { [weak self] buffer, time in
            Task { @MainActor in
                self?.processAudioBuffer(buffer)
            }
        }

        try engine.start()
    }

    private func setupAggregateInput() throws {
        // For aggregate devices (multiple inputs combined)
        // This would require creating an aggregate device on macOS
        try setupLiveAudioInput()
    }

    // MARK: - Audio File Loading

    /// Load an audio file for analysis
    public func loadAudioFile(url: URL) async throws {
        audioFile = try AVAudioFile(forReading: url)

        guard let file = audioFile else {
            throw AudioInputError.fileLoadFailed
        }

        // Setup playback engine
        audioEngine = AVAudioEngine()
        audioPlayerNode = AVAudioPlayerNode()

        guard let engine = audioEngine, let player = audioPlayerNode else {
            throw AudioInputError.engineSetupFailed
        }

        engine.attach(player)
        engine.connect(player, to: engine.mainMixerNode, format: file.processingFormat)

        // Install tap for analysis
        engine.mainMixerNode.installTap(onBus: 0, bufferSize: AVAudioFrameCount(bufferSize), format: file.processingFormat) { [weak self] buffer, time in
            Task { @MainActor in
                self?.processAudioBuffer(buffer)
            }
        }

        // Schedule file playback
        await player.scheduleFile(file, at: nil)

        try engine.start()
        player.play()

        log.audio("📂 Audio file loaded: \(url.lastPathComponent)")
    }

    // MARK: - Audio Processing

    private func processAudioBuffer(_ buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData?[0] else { return }
        let frameCount = Int(buffer.frameLength)

        // Apply input gain
        let samplesToProcess = min(frameCount, bufferSize)
        for i in 0..<samplesToProcess {
            analysisBuffer[i] = channelData[i] * inputGain
        }

        // Calculate input level (RMS)
        var rms: Float = 0
        vDSP_rmsqv(analysisBuffer, 1, &rms, vDSP_Length(samplesToProcess))
        inputLevel = rms
        peakLevel = max(peakLevel * 0.99, rms) // Peak hold with decay

        // Noise gate
        if rms < noiseGate {
            handleSilence()
            return
        }

        // Detect based on mode
        switch detectionMode {
        case .monophonic:
            detectMonophonic(sampleRate: Float(buffer.format.sampleRate))

        case .polyphonic:
            detectPolyphonic(sampleRate: Float(buffer.format.sampleRate))

        case .percussive:
            detectPercussive(sampleRate: Float(buffer.format.sampleRate))

        case .hybrid:
            detectHybrid(sampleRate: Float(buffer.format.sampleRate))
        }

        // Route to Quantum MIDI
        if routeToQuantumMIDI {
            routeNotesToQuantumMIDI()
        }
    }

    // MARK: - Monophonic Detection (delegates to shared PitchDetector)

    private func detectMonophonic(sampleRate: Float) {
        let frequency = pitchDetector.detectPitch(samples: analysisBuffer, sampleRate: sampleRate)
        guard frequency >= 60 && frequency <= 2000 else { return }

        let (midiNote, cents) = frequencyToMIDI(frequency)

        let note = DetectedNote(
            midiNote: midiNote,
            frequency: frequency,
            amplitude: inputLevel,
            cents: cents,
            confidence: 0.9
        )

        detectedNotes = [note]
        dominantNote = note
        isPolyphonic = false
    }

    // MARK: - Polyphonic Detection (FFT + Peak)

    private func detectPolyphonic(sampleRate: Float) {
        guard let fft = fftSetup else { return }

        // Apply Hann window
        var windowedBuffer = [Float](repeating: 0, count: fftSize)
        for i in 0..<min(bufferSize, fftSize) {
            let window = 0.5 * (1.0 - cos(2.0 * .pi * Float(i) / Float(fftSize - 1)))
            windowedBuffer[i] = analysisBuffer[i] * window
        }

        // Perform FFT
        fftRealBuffer = windowedBuffer
        fftImagBuffer = [Float](repeating: 0, count: fftSize)

        var realInput = fftRealBuffer
        var imagInput = fftImagBuffer
        vDSP_DFT_Execute(fft, &realInput, &imagInput, &fftRealBuffer, &fftImagBuffer)

        // Calculate magnitude spectrum
        for i in 0..<fftSize/2 {
            let real = fftRealBuffer[i]
            let imag = fftImagBuffer[i]
            magnitudeSpectrum[i] = sqrt(real * real + imag * imag)
        }

        // Calculate spectral centroid
        var weightedSum: Float = 0
        var totalMagnitude: Float = 0
        for i in 0..<fftSize/2 {
            let freq = Float(i) * sampleRate / Float(fftSize)
            weightedSum += freq * magnitudeSpectrum[i]
            totalMagnitude += magnitudeSpectrum[i]
        }
        spectralCentroid = totalMagnitude > 0 ? weightedSum / totalMagnitude : 0

        // Find peaks in spectrum
        var peaks: [(frequency: Float, magnitude: Float)] = []
        let minBin = Int(60.0 * Float(fftSize) / sampleRate) // 60 Hz min
        let maxBin = Int(4000.0 * Float(fftSize) / sampleRate) // 4000 Hz max

        for i in max(1, minBin)..<min(fftSize/2 - 1, maxBin) {
            let mag = magnitudeSpectrum[i]
            let prevMag = magnitudeSpectrum[i - 1]
            let nextMag = magnitudeSpectrum[i + 1]

            // Is this a peak?
            if mag > prevMag && mag > nextMag && mag > peakThreshold {
                // Parabolic interpolation for better frequency resolution
                let delta = 0.5 * (prevMag - nextMag) / (prevMag - 2 * mag + nextMag)
                let refinedBin = Float(i) + delta
                let frequency = refinedBin * sampleRate / Float(fftSize)

                peaks.append((frequency, mag))
            }
        }

        // Sort by magnitude
        peaks.sort { $0.magnitude > $1.magnitude }

        // Filter harmonics (keep fundamentals)
        var fundamentals: [(frequency: Float, magnitude: Float)] = []
        for peak in peaks {
            let isHarmonic = fundamentals.contains { fundamental in
                let ratio = peak.frequency / fundamental.frequency
                let roundedRatio = round(ratio)
                return roundedRatio >= 2 && abs(ratio - roundedRatio) < harmonicTolerance
            }

            if !isHarmonic {
                fundamentals.append(peak)
                if fundamentals.count >= maxPolyphony {
                    break
                }
            }
        }

        // Convert to detected notes
        var notes: [DetectedNote] = []
        for fundamental in fundamentals {
            let (midiNote, cents) = frequencyToMIDI(fundamental.frequency)
            let note = DetectedNote(
                midiNote: midiNote,
                frequency: fundamental.frequency,
                amplitude: fundamental.magnitude,
                cents: cents,
                confidence: fundamental.magnitude / (peaks.first?.magnitude ?? 1.0)
            )
            notes.append(note)
        }

        detectedNotes = notes
        dominantNote = notes.first
        isPolyphonic = notes.count > 1
    }

    // MARK: - Percussive Detection (Onset)

    private func detectPercussive(sampleRate: Float) {
        // Calculate spectral flux (difference from previous frame)
        var flux: Float = 0

        for i in 0..<fftSize/2 {
            let diff = magnitudeSpectrum[i] - previousMagnitudes[i]
            if diff > 0 {
                flux += diff
            }
        }

        // Store current magnitudes
        previousMagnitudes = magnitudeSpectrum

        // Detect onset
        let onsetThreshold: Float = 0.5
        let now = Date()
        let minOnsetInterval: TimeInterval = 0.05 // 50ms minimum

        if flux > onsetThreshold && now.timeIntervalSince(lastOnsetTime) > minOnsetInterval {
            lastOnsetTime = now

            // Map spectral centroid to note (approximate pitch mapping for drums)
            let midiNote: UInt8
            if spectralCentroid < 200 {
                midiNote = 36 // Kick
            } else if spectralCentroid < 1000 {
                midiNote = 38 // Snare
            } else {
                midiNote = 42 // Hi-hat
            }

            let note = DetectedNote(
                midiNote: midiNote,
                frequency: spectralCentroid,
                amplitude: flux,
                onset: true,
                isPercussive: true
            )

            detectedNotes = [note]
            dominantNote = note
            isPolyphonic = false
        }
    }

    // MARK: - Hybrid Detection

    private func detectHybrid(sampleRate: Float) {
        // First do polyphonic detection
        detectPolyphonic(sampleRate: sampleRate)

        // Check if it looks percussive
        let spectralSpread = calculateSpectralSpread()
        let zeroCrossingRate = calculateZeroCrossingRate()

        // Percussive signals have high zero-crossing rate and spread spectrum
        if zeroCrossingRate > 0.3 && spectralSpread > 1000 {
            detectPercussive(sampleRate: sampleRate)
        }

        // If only one clear note, use monophonic for better accuracy
        if detectedNotes.count == 1 {
            detectMonophonic(sampleRate: sampleRate)
        }
    }

    private func calculateSpectralSpread() -> Float {
        var spread: Float = 0
        let centroid = spectralCentroid

        for i in 0..<fftSize/2 {
            let freq = Float(i) * 48000 / Float(fftSize) // Assume 48kHz
            let diff = freq - centroid
            spread += diff * diff * magnitudeSpectrum[i]
        }

        return sqrt(spread)
    }

    private func calculateZeroCrossingRate() -> Float {
        var crossings: Int = 0

        for i in 1..<bufferSize {
            if (analysisBuffer[i] >= 0) != (analysisBuffer[i-1] >= 0) {
                crossings += 1
            }
        }

        return Float(crossings) / Float(bufferSize)
    }

    // MARK: - MIDI Conversion

    private func frequencyToMIDI(_ freq: Float) -> (note: UInt8, cents: Float) {
        guard freq > 0 else { return (0, 0) }

        let noteFloat = 12.0 * log2(freq / 440.0) + 69.0
        let noteInt = Int(noteFloat.rounded())
        let cents = (noteFloat - Float(noteInt)) * 100

        return (UInt8(max(0, min(127, noteInt))), cents)
    }

    // MARK: - Quantum MIDI Routing

    private func routeNotesToQuantumMIDI() {
        guard let midiOut = quantumMIDIOut else { return }

        let currentNoteSet = Set(detectedNotes.map { $0.midiNote })
        let activeNoteSet = Set(activeNotes.keys)

        // Note Off for notes no longer detected
        for note in activeNoteSet.subtracting(currentNoteSet) {
            sendNoteOff(note)
        }

        // Note On for new notes
        for detectedNote in detectedNotes {
            if !activeNotes.keys.contains(detectedNote.midiNote) &&
               detectedNote.amplitude > noteOnThreshold {
                sendNoteOn(detectedNote)
            }
        }
    }

    private func sendNoteOn(_ note: DetectedNote) {
        guard let midiOut = quantumMIDIOut else { return }

        for instrument in targetInstruments {
            midiOut.noteOn(
                note: note.midiNote,
                velocity: note.amplitude,
                instrument: instrument
            )
        }

        activeNotes[note.midiNote] = note
    }

    private func sendNoteOff(_ midiNote: UInt8) {
        guard let midiOut = quantumMIDIOut else { return }

        for instrument in targetInstruments {
            midiOut.noteOff(note: midiNote, instrument: instrument)
        }

        activeNotes.removeValue(forKey: midiNote)
    }

    // MARK: - Silence Handling

    private func handleSilence() {
        // Note off for all active notes
        for note in activeNotes.keys {
            sendNoteOff(note)
        }

        detectedNotes.removeAll()
        dominantNote = nil
    }

    // MARK: - Presets

    /// Preset for voice input
    public func loadVoicePreset() {
        inputSource = .microphone
        detectionMode = .monophonic
        maxPolyphony = 1
        noteOnThreshold = 0.1
        noteOffThreshold = 0.05
        targetInstruments = [.bioReactive]
    }

    /// Preset for guitar input
    public func loadGuitarPreset() {
        inputSource = .lineIn
        detectionMode = .polyphonic
        maxPolyphony = 6
        noteOnThreshold = 0.08
        noteOffThreshold = 0.04
        targetInstruments = [.physicalModeling]
    }

    /// Preset for keyboard/piano input
    public func loadKeyboardPreset() {
        inputSource = .audioInterface
        detectionMode = .polyphonic
        maxPolyphony = 10
        noteOnThreshold = 0.05
        noteOffThreshold = 0.02
        targetInstruments = [.piano]
    }

    /// Preset for drums
    public func loadDrumsPreset() {
        inputSource = .audioInterface
        detectionMode = .percussive
        maxPolyphony = 4
        noteOnThreshold = 0.15
        noteOffThreshold = 0.1
        targetInstruments = [.tr808]
    }

    /// Preset for audio file analysis
    public func loadSamplePreset() {
        inputSource = .audioFile
        detectionMode = .hybrid
        maxPolyphony = 8
        noteOnThreshold = 0.05
        noteOffThreshold = 0.03
        targetInstruments = [.wavetable, .granular]
    }

    // MARK: - Cleanup

    deinit {
        if let fft = fftSetup {
            vDSP_DFT_DestroySetup(fft)
        }
    }
}

// MARK: - Errors

public enum AudioInputError: Error, LocalizedError {
    case engineSetupFailed
    case invalidFormat
    case fileLoadFailed
    case deviceNotAvailable

    public var errorDescription: String? {
        switch self {
        case .engineSetupFailed: return "Audio engine setup failed"
        case .invalidFormat: return "Invalid audio format"
        case .fileLoadFailed: return "Failed to load audio file"
        case .deviceNotAvailable: return "Audio device not available"
        }
    }
}
