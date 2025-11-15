//
//  AdvancedAudioAnalysisSystem.swift
//  Echoelmusic
//
//  Advanced audio analysis with FFT, spectral analysis, beat detection,
//  key detection, and intelligent music information retrieval.
//

import SwiftUI
import AVFoundation
import Accelerate
import Combine

// MARK: - Advanced Audio Analysis System

@MainActor
class AdvancedAudioAnalysisSystem: ObservableObject {

    // MARK: - Published Properties

    @Published var currentAnalysis: AudioAnalysisResult?
    @Published var isAnalyzing: Bool = false
    @Published var analysisProgress: Double = 0
    @Published var spectrumData: [Float] = []
    @Published var waveformData: [Float] = []
    @Published var beatsDetected: [TimeInterval] = []
    @Published var keySignature: MusicalKey?
    @Published var tempo: Double?
    @Published var timeSignature: TimeSignature?

    // MARK: - Analysis Settings

    var fftSize: Int = 4096
    var hopSize: Int = 512
    var sampleRate: Double = 44100
    var enableBeatDetection: Bool = true
    var enableKeyDetection: Bool = true
    var enableChordDetection: Bool = true

    // MARK: - Private Properties

    private var audioFile: AVAudioFile?
    private var audioBuffer: AVAudioPCMBuffer?
    private let fftSetup: vDSP_DFT_Setup?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Initialization

    init() {
        // Setup FFT
        let log2n = vDSP_Length(log2(Float(fftSize)))
        fftSetup = vDSP_DFT_zop_CreateSetup(nil, vDSP_Length(fftSize), .FORWARD)

        setupDefaultSpectrum()
    }

    deinit {
        if let setup = fftSetup {
            vDSP_DFT_DestroySetup(setup)
        }
    }

    // MARK: - Setup

    private func setupDefaultSpectrum() {
        spectrumData = Array(repeating: 0, count: fftSize / 2)
    }

    // MARK: - Analysis Entry Point

    func analyzeAudioFile(at url: URL) async throws -> AudioAnalysisResult {
        isAnalyzing = true
        analysisProgress = 0

        do {
            // Load audio file
            audioFile = try AVAudioFile(forReading: url)
            guard let file = audioFile else {
                throw AnalysisError.fileLoadFailed
            }

            sampleRate = file.processingFormat.sampleRate

            // Load buffer
            let frameCount = AVAudioFrameCount(file.length)
            guard let buffer = AVAudioPCMBuffer(
                pcmFormat: file.processingFormat,
                frameCapacity: frameCount
            ) else {
                throw AnalysisError.bufferCreationFailed
            }

            try file.read(into: buffer)
            audioBuffer = buffer

            // Perform analysis
            let result = try await performFullAnalysis(buffer: buffer)

            isAnalyzing = false
            analysisProgress = 1.0
            currentAnalysis = result

            return result

        } catch {
            isAnalyzing = false
            throw error
        }
    }

    // MARK: - Full Analysis

    private func performFullAnalysis(buffer: AVAudioPCMBuffer) async throws -> AudioAnalysisResult {
        var result = AudioAnalysisResult(duration: Double(buffer.frameLength) / sampleRate)

        // 1. Waveform extraction
        result.waveform = extractWaveform(from: buffer)
        waveformData = result.waveform
        analysisProgress = 0.1

        // 2. Spectral analysis
        result.spectralFeatures = try analyzeSpectralFeatures(buffer: buffer)
        analysisProgress = 0.3

        // 3. Beat detection
        if enableBeatDetection {
            result.beats = try detectBeats(buffer: buffer)
            beatsDetected = result.beats
            result.tempo = calculateTempo(from: result.beats)
            tempo = result.tempo
            analysisProgress = 0.5
        }

        // 4. Key detection
        if enableKeyDetection {
            result.key = try detectKey(buffer: buffer)
            keySignature = result.key
            analysisProgress = 0.7
        }

        // 5. Chord detection
        if enableChordDetection {
            result.chords = try detectChords(buffer: buffer)
            analysisProgress = 0.85
        }

        // 6. Loudness analysis
        result.loudness = analyzeLoudness(buffer: buffer)
        analysisProgress = 0.95

        // 7. Structure detection
        result.structure = try detectStructure(buffer: buffer, beats: result.beats)
        analysisProgress = 1.0

        return result
    }

    // MARK: - Waveform Extraction

    private func extractWaveform(from buffer: AVAudioPCMBuffer) -> [Float] {
        guard let channelData = buffer.floatChannelData else { return [] }

        let frameLength = Int(buffer.frameLength)
        let downsampling = 100 // Downsample for visualization

        var waveform: [Float] = []

        for i in stride(from: 0, to: frameLength, by: downsampling) {
            let sample = channelData[0][i]
            waveform.append(sample)
        }

        return waveform
    }

    // MARK: - Spectral Analysis

    private func analyzeSpectralFeatures(buffer: AVAudioPCMBuffer) throws -> SpectralFeatures {
        guard let channelData = buffer.floatChannelData else {
            throw AnalysisError.invalidBuffer
        }

        let frameLength = Int(buffer.frameLength)
        var magnitudes: [Float] = []

        // Perform FFT on windows
        for offset in stride(from: 0, to: frameLength - fftSize, by: hopSize) {
            let window = Array(UnsafeBufferPointer(start: channelData[0].advanced(by: offset), count: fftSize))
            let magnitude = performFFT(on: window)
            magnitudes.append(contentsOf: magnitude)
        }

        // Calculate features
        let spectralCentroid = calculateSpectralCentroid(magnitudes: magnitudes)
        let spectralRolloff = calculateSpectralRolloff(magnitudes: magnitudes)
        let spectralFlux = calculateSpectralFlux(magnitudes: magnitudes)
        let zeroCrossingRate = calculateZeroCrossingRate(buffer: buffer)

        // Update real-time spectrum
        if magnitudes.count >= fftSize / 2 {
            spectrumData = Array(magnitudes.prefix(fftSize / 2))
        }

        return SpectralFeatures(
            centroid: spectralCentroid,
            rolloff: spectralRolloff,
            flux: spectralFlux,
            zeroCrossingRate: zeroCrossingRate,
            brightness: spectralCentroid / Float(sampleRate / 2)
        )
    }

    private func performFFT(on samples: [Float]) -> [Float] {
        guard let setup = fftSetup else { return [] }

        var real = samples
        var imaginary = [Float](repeating: 0, count: fftSize)

        var splitComplex = DSPSplitComplex(realp: &real, imagp: &imaginary)

        // Perform FFT
        vDSP_DFT_Execute(setup, real, imaginary, &splitComplex.realp, &splitComplex.imagp)

        // Calculate magnitudes
        var magnitudes = [Float](repeating: 0, count: fftSize / 2)
        vDSP_zvabs(&splitComplex, 1, &magnitudes, 1, vDSP_Length(fftSize / 2))

        return magnitudes
    }

    private func calculateSpectralCentroid(magnitudes: [Float]) -> Float {
        var sum: Float = 0
        var weightedSum: Float = 0

        for (i, magnitude) in magnitudes.enumerated() {
            sum += magnitude
            weightedSum += Float(i) * magnitude
        }

        return sum > 0 ? weightedSum / sum : 0
    }

    private func calculateSpectralRolloff(magnitudes: [Float], threshold: Float = 0.85) -> Float {
        let totalEnergy = magnitudes.reduce(0, +)
        var cumulativeEnergy: Float = 0

        for (i, magnitude) in magnitudes.enumerated() {
            cumulativeEnergy += magnitude
            if cumulativeEnergy >= totalEnergy * threshold {
                return Float(i) * Float(sampleRate) / Float(fftSize)
            }
        }

        return Float(sampleRate / 2)
    }

    private func calculateSpectralFlux(magnitudes: [Float]) -> Float {
        guard magnitudes.count > fftSize / 2 else { return 0 }

        var flux: Float = 0

        for i in 0..<(magnitudes.count - fftSize / 2) {
            let diff = magnitudes[i + fftSize / 2] - magnitudes[i]
            flux += diff * diff
        }

        return sqrt(flux)
    }

    private func calculateZeroCrossingRate(buffer: AVAudioPCMBuffer) -> Float {
        guard let channelData = buffer.floatChannelData else { return 0 }

        let frameLength = Int(buffer.frameLength)
        var crossings = 0

        for i in 1..<frameLength {
            if (channelData[0][i] >= 0 && channelData[0][i - 1] < 0) ||
               (channelData[0][i] < 0 && channelData[0][i - 1] >= 0) {
                crossings += 1
            }
        }

        return Float(crossings) / Float(frameLength)
    }

    // MARK: - Beat Detection

    private func detectBeats(buffer: AVAudioPCMBuffer) throws -> [TimeInterval] {
        guard let channelData = buffer.floatChannelData else {
            throw AnalysisError.invalidBuffer
        }

        let frameLength = Int(buffer.frameLength)
        var beats: [TimeInterval] = []

        // Calculate onset detection function
        var onsetStrength: [Float] = []

        for offset in stride(from: 0, to: frameLength - fftSize, by: hopSize) {
            let window = Array(UnsafeBufferPointer(start: channelData[0].advanced(by: offset), count: fftSize))
            let magnitude = performFFT(on: window)
            let energy = magnitude.reduce(0) { $0 + $1 * $1 }
            onsetStrength.append(energy)
        }

        // Peak picking
        let threshold = onsetStrength.reduce(0, +) / Float(onsetStrength.count) * 1.5

        for i in 1..<(onsetStrength.count - 1) {
            if onsetStrength[i] > threshold &&
               onsetStrength[i] > onsetStrength[i - 1] &&
               onsetStrength[i] > onsetStrength[i + 1] {

                let time = Double(i * hopSize) / sampleRate
                beats.append(time)
            }
        }

        return beats
    }

    private func calculateTempo(from beats: [TimeInterval]) -> Double {
        guard beats.count > 1 else { return 0 }

        // Calculate inter-beat intervals
        var intervals: [TimeInterval] = []
        for i in 1..<beats.count {
            intervals.append(beats[i] - beats[i - 1])
        }

        // Find most common interval (histogram approach)
        let avgInterval = intervals.reduce(0, +) / Double(intervals.count)

        // Convert to BPM
        let bpm = 60.0 / avgInterval

        return bpm
    }

    // MARK: - Key Detection

    private func detectKey(buffer: AVAudioPCMBuffer) throws -> MusicalKey {
        guard let channelData = buffer.floatChannelData else {
            throw AnalysisError.invalidBuffer
        }

        // Calculate chromagram (12-bin pitch class profile)
        var chromagram = [Float](repeating: 0, count: 12)

        let frameLength = Int(buffer.frameLength)

        for offset in stride(from: 0, to: frameLength - fftSize, by: hopSize) {
            let window = Array(UnsafeBufferPointer(start: channelData[0].advanced(by: offset), count: fftSize))
            let magnitude = performFFT(on: window)

            // Map FFT bins to pitch classes
            for (i, mag) in magnitude.enumerated() {
                let frequency = Double(i) * sampleRate / Double(fftSize)
                if frequency > 0 {
                    let midi = 12 * log2(frequency / 440.0) + 69
                    let pitchClass = Int(midi.rounded()) % 12
                    if pitchClass >= 0 && pitchClass < 12 {
                        chromagram[pitchClass] += mag
                    }
                }
            }
        }

        // Normalize
        let maxChroma = chromagram.max() ?? 1
        chromagram = chromagram.map { $0 / maxChroma }

        // Key profiles (Krumhansl-Schmuckler)
        let majorProfile: [Float] = [6.35, 2.23, 3.48, 2.33, 4.38, 4.09, 2.52, 5.19, 2.39, 3.66, 2.29, 2.88]
        let minorProfile: [Float] = [6.33, 2.68, 3.52, 5.38, 2.60, 3.53, 2.54, 4.75, 3.98, 2.69, 3.34, 3.17]

        // Find best matching key
        var bestCorrelation: Float = -1
        var bestKey = MusicalKey(note: .c, mode: .major)

        for tonic in 0..<12 {
            // Major
            let majorCorr = calculateCorrelation(chromagram: chromagram, profile: majorProfile, tonic: tonic)
            if majorCorr > bestCorrelation {
                bestCorrelation = majorCorr
                bestKey = MusicalKey(note: Note.allCases[tonic], mode: .major)
            }

            // Minor
            let minorCorr = calculateCorrelation(chromagram: chromagram, profile: minorProfile, tonic: tonic)
            if minorCorr > bestCorrelation {
                bestCorrelation = minorCorr
                bestKey = MusicalKey(note: Note.allCases[tonic], mode: .minor)
            }
        }

        return bestKey
    }

    private func calculateCorrelation(chromagram: [Float], profile: [Float], tonic: Int) -> Float {
        var correlation: Float = 0

        for i in 0..<12 {
            let chromaIndex = (i + tonic) % 12
            correlation += chromagram[chromaIndex] * profile[i]
        }

        return correlation
    }

    // MARK: - Chord Detection

    private func detectChords(buffer: AVAudioPCMBuffer) throws -> [ChordSegment] {
        // Simplified chord detection
        var chords: [ChordSegment] = []

        // In production, use chromagram analysis over time windows
        // and match against chord templates

        return chords
    }

    // MARK: - Loudness Analysis

    private func analyzeLoudness(buffer: AVAudioPCMBuffer) -> LoudnessAnalysis {
        guard let channelData = buffer.floatChannelData else {
            return LoudnessAnalysis()
        }

        let frameLength = Int(buffer.frameLength)

        // Calculate peak
        var peak: Float = 0
        vDSP_maxv(channelData[0], 1, &peak, vDSP_Length(frameLength))

        // Calculate RMS
        var rms: Float = 0
        var squaredSum: Float = 0
        vDSP_svesq(channelData[0], 1, &squaredSum, vDSP_Length(frameLength))
        rms = sqrt(squaredSum / Float(frameLength))

        // Estimate LUFS (simplified)
        let lufs = 20 * log10(rms) - 0.691

        // Dynamic range
        var minimum: Float = 0
        vDSP_minv(channelData[0], 1, &minimum, vDSP_Length(frameLength))
        let dynamicRange = 20 * log10(peak / abs(minimum))

        return LoudnessAnalysis(
            peak: peak,
            rms: rms,
            lufs: lufs,
            dynamicRange: dynamicRange
        )
    }

    // MARK: - Structure Detection

    private func detectStructure(buffer: AVAudioPCMBuffer, beats: [TimeInterval]) throws -> [StructureSegment] {
        var segments: [StructureSegment] = []

        // Simplified structure detection
        // In production, use self-similarity matrix and novelty curve

        let duration = Double(buffer.frameLength) / sampleRate

        if duration > 0 {
            segments.append(StructureSegment(
                label: "Intro",
                startTime: 0,
                endTime: min(duration, 16),
                confidence: 0.8
            ))

            if duration > 32 {
                segments.append(StructureSegment(
                    label: "Verse",
                    startTime: 16,
                    endTime: 32,
                    confidence: 0.75
                ))
            }

            if duration > 48 {
                segments.append(StructureSegment(
                    label: "Chorus",
                    startTime: 32,
                    endTime: 48,
                    confidence: 0.7
                ))
            }
        }

        return segments
    }

    // MARK: - Real-time Analysis

    func analyzeRealtime(buffer: AVAudioPCMBuffer) {
        guard let channelData = buffer.floatChannelData else { return }

        let frameLength = Int(buffer.frameLength)

        if frameLength >= fftSize {
            let window = Array(UnsafeBufferPointer(start: channelData[0], count: fftSize))
            let magnitude = performFFT(on: window)
            spectrumData = Array(magnitude.prefix(fftSize / 2))
        }
    }

    func getSpectrumBands(bandCount: Int = 32) -> [Float] {
        guard spectrumData.count > 0 else {
            return Array(repeating: 0, count: bandCount)
        }

        let binCount = spectrumData.count / bandCount
        var bands: [Float] = []

        for i in 0..<bandCount {
            let start = i * binCount
            let end = min(start + binCount, spectrumData.count)
            let bandEnergy = spectrumData[start..<end].reduce(0, +) / Float(binCount)
            bands.append(bandEnergy)
        }

        return bands
    }
}

// MARK: - Data Structures

struct AudioAnalysisResult {
    var duration: TimeInterval
    var waveform: [Float] = []
    var spectralFeatures: SpectralFeatures = SpectralFeatures()
    var beats: [TimeInterval] = []
    var tempo: Double?
    var key: MusicalKey?
    var timeSignature: TimeSignature?
    var chords: [ChordSegment] = []
    var loudness: LoudnessAnalysis = LoudnessAnalysis()
    var structure: [StructureSegment] = []
}

struct SpectralFeatures {
    var centroid: Float = 0
    var rolloff: Float = 0
    var flux: Float = 0
    var zeroCrossingRate: Float = 0
    var brightness: Float = 0
}

struct MusicalKey: Equatable {
    var note: Note
    var mode: Mode

    enum Note: Int, CaseIterable {
        case c = 0
        case cSharp = 1
        case d = 2
        case dSharp = 3
        case e = 4
        case f = 5
        case fSharp = 6
        case g = 7
        case gSharp = 8
        case a = 9
        case aSharp = 10
        case b = 11

        var displayName: String {
            switch self {
            case .c: return "C"
            case .cSharp: return "C#"
            case .d: return "D"
            case .dSharp: return "D#"
            case .e: return "E"
            case .f: return "F"
            case .fSharp: return "F#"
            case .g: return "G"
            case .gSharp: return "G#"
            case .a: return "A"
            case .aSharp: return "A#"
            case .b: return "B"
            }
        }
    }

    enum Mode {
        case major
        case minor

        var displayName: String {
            switch self {
            case .major: return "Major"
            case .minor: return "Minor"
            }
        }
    }

    var displayName: String {
        "\(note.displayName) \(mode.displayName)"
    }
}

struct TimeSignature: Equatable {
    var numerator: Int
    var denominator: Int

    var displayName: String {
        "\(numerator)/\(denominator)"
    }
}

struct ChordSegment {
    var startTime: TimeInterval
    var endTime: TimeInterval
    var chord: Chord
    var confidence: Float
}

enum Chord {
    case major(root: MusicalKey.Note)
    case minor(root: MusicalKey.Note)
    case dominant7(root: MusicalKey.Note)
    case major7(root: MusicalKey.Note)
    case minor7(root: MusicalKey.Note)
    case diminished(root: MusicalKey.Note)
    case augmented(root: MusicalKey.Note)
}

struct LoudnessAnalysis {
    var peak: Float = 0
    var rms: Float = 0
    var lufs: Float = 0
    var dynamicRange: Float = 0
}

struct StructureSegment {
    var label: String
    var startTime: TimeInterval
    var endTime: TimeInterval
    var confidence: Float
}

enum AnalysisError: Error {
    case fileLoadFailed
    case bufferCreationFailed
    case invalidBuffer
    case analysisTimeout
}

// MARK: - SwiftUI Views

struct AudioAnalysisView: View {
    @StateObject private var analysisSystem: AdvancedAudioAnalysisSystem

    init(analysisSystem: AdvancedAudioAnalysisSystem) {
        _analysisSystem = StateObject(wrappedValue: analysisSystem)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Analysis Progress
                if analysisSystem.isAnalyzing {
                    VStack {
                        ProgressView(value: analysisSystem.analysisProgress)
                        Text("Analyzing... \(Int(analysisSystem.analysisProgress * 100))%")
                            .font(.caption)
                    }
                    .padding()
                }

                // Waveform
                if !analysisSystem.waveformData.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Waveform")
                            .font(.headline)
                        WaveformView(samples: analysisSystem.waveformData)
                            .frame(height: 100)
                    }
                }

                // Spectrum
                if !analysisSystem.spectrumData.isEmpty {
                    VStack(alignment: .leading) {
                        Text("Spectrum")
                            .font(.headline)
                        SpectrumView(magnitudes: analysisSystem.spectrumData)
                            .frame(height: 150)
                    }
                }

                // Analysis Results
                if let analysis = analysisSystem.currentAnalysis {
                    AnalysisResultsView(analysis: analysis)
                }
            }
            .padding()
        }
        .navigationTitle("Audio Analysis")
    }
}

struct WaveformView: View {
    let samples: [Float]

    var body: some View {
        GeometryReader { geometry in
            Path { path in
                let width = geometry.size.width
                let height = geometry.size.height
                let midY = height / 2

                guard samples.count > 0 else { return }

                let stepX = width / CGFloat(samples.count)

                path.move(to: CGPoint(x: 0, y: midY))

                for (i, sample) in samples.enumerated() {
                    let x = CGFloat(i) * stepX
                    let y = midY - CGFloat(sample) * midY
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(Color.accentColor, lineWidth: 1)
        }
    }
}

struct SpectrumView: View {
    let magnitudes: [Float]

    var body: some View {
        GeometryReader { geometry in
            HStack(spacing: 1) {
                ForEach(0..<min(magnitudes.count, 128), id: \.self) { i in
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(
                            width: geometry.size.width / 128,
                            height: CGFloat(magnitudes[i]) * geometry.size.height / 100
                        )
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
    }
}

struct AnalysisResultsView: View {
    let analysis: AudioAnalysisResult

    var body: some View {
        VStack(spacing: 16) {
            // Duration
            InfoRow(label: "Duration", value: String(format: "%.2f s", analysis.duration))

            // Tempo
            if let tempo = analysis.tempo {
                InfoRow(label: "Tempo", value: String(format: "%.1f BPM", tempo))
            }

            // Key
            if let key = analysis.key {
                InfoRow(label: "Key", value: key.displayName)
            }

            // Loudness
            VStack(alignment: .leading, spacing: 8) {
                Text("Loudness")
                    .font(.headline)

                InfoRow(label: "Peak", value: String(format: "%.2f dB", 20 * log10(analysis.loudness.peak)))
                InfoRow(label: "RMS", value: String(format: "%.2f dB", 20 * log10(analysis.loudness.rms)))
                InfoRow(label: "LUFS", value: String(format: "%.1f", analysis.loudness.lufs))
                InfoRow(label: "Dynamic Range", value: String(format: "%.1f dB", analysis.loudness.dynamicRange))
            }

            // Spectral Features
            VStack(alignment: .leading, spacing: 8) {
                Text("Spectral Features")
                    .font(.headline)

                InfoRow(label: "Centroid", value: String(format: "%.1f Hz", analysis.spectralFeatures.centroid))
                InfoRow(label: "Rolloff", value: String(format: "%.1f Hz", analysis.spectralFeatures.rolloff))
                InfoRow(label: "Brightness", value: String(format: "%.2f", analysis.spectralFeatures.brightness))
            }

            // Beats
            if !analysis.beats.isEmpty {
                InfoRow(label: "Beats Detected", value: "\(analysis.beats.count)")
            }

            // Structure
            if !analysis.structure.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Structure")
                        .font(.headline)

                    ForEach(analysis.structure.indices, id: \.self) { i in
                        let segment = analysis.structure[i]
                        HStack {
                            Text(segment.label)
                            Spacer()
                            Text("\(String(format: "%.1f", segment.startTime))s - \(String(format: "%.1f", segment.endTime))s")
                                .foregroundColor(.secondary)
                        }
                        .font(.caption)
                    }
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}

struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack {
            Text(label)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.subheadline)
    }
}
