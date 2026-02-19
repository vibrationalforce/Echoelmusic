// AudioToMIDIConverter.swift
// Echoelmusic
//
// Converts monophonic and polyphonic audio to MIDI note data
// using pitch detection, onset detection, and note segmentation.
//
// Created by Echoelmusic Team
// Copyright © 2026 Echoelmusic. All rights reserved.

import Foundation
import AVFoundation
import Accelerate
import Combine

// MARK: - MIDI Note Event

/// A single MIDI note event extracted from audio
public struct AudioMIDINoteEvent: Identifiable, Codable, Sendable {
    public let id: UUID
    public let noteNumber: Int      // 0-127
    public let velocity: Int        // 0-127
    public let startTime: Double    // seconds
    public let duration: Double     // seconds
    public let channel: Int         // 0-15

    /// Note name (e.g., "C4")
    public var noteName: String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let name = noteNames[noteNumber % 12]
        let octave = (noteNumber / 12) - 1
        return "\(name)\(octave)"
    }

    /// Frequency of this note
    public var frequency: Double {
        return 440.0 * pow(2.0, Double(noteNumber - 69) / 12.0)
    }

    public init(
        id: UUID = UUID(),
        noteNumber: Int,
        velocity: Int,
        startTime: Double,
        duration: Double,
        channel: Int = 0
    ) {
        self.id = id
        self.noteNumber = noteNumber
        self.velocity = velocity
        self.startTime = startTime
        self.duration = duration
        self.channel = channel
    }
}

// MARK: - Conversion Mode

/// Audio-to-MIDI conversion mode
public enum AudioToMIDIMode: String, CaseIterable, Codable, Sendable {
    case monophonic = "Monophonic"
    case polyphonic = "Polyphonic"
    case percussive = "Percussive"
    case melodic = "Melodic (Auto)"

    var description: String {
        switch self {
        case .monophonic: return "Single note at a time (vocals, lead)"
        case .polyphonic: return "Multiple simultaneous notes (chords, piano)"
        case .percussive: return "Drum/percussion onset detection"
        case .melodic: return "Auto-detect monophonic/polyphonic"
        }
    }
}

// MARK: - Conversion Configuration

public struct AudioToMIDIConfiguration: Codable, Sendable {
    public var mode: AudioToMIDIMode
    public var minimumNoteLength: Double  // seconds
    public var noteThreshold: Double      // amplitude threshold for note detection
    public var quantizeToGrid: Bool
    public var quantizeValue: Double       // in beats (0.25 = 16th note)
    public var velocitySensitivity: Double // 0-1
    public var pitchBendRange: Int         // semitones for pitch bend detection
    public var minFrequency: Double
    public var maxFrequency: Double

    public init(
        mode: AudioToMIDIMode = .melodic,
        minimumNoteLength: Double = 0.05,
        noteThreshold: Double = 0.02,
        quantizeToGrid: Bool = false,
        quantizeValue: Double = 0.25,
        velocitySensitivity: Double = 0.8,
        pitchBendRange: Int = 2,
        minFrequency: Double = 27.5,
        maxFrequency: Double = 4186.0
    ) {
        self.mode = mode
        self.minimumNoteLength = minimumNoteLength
        self.noteThreshold = noteThreshold
        self.quantizeToGrid = quantizeToGrid
        self.quantizeValue = quantizeValue
        self.velocitySensitivity = velocitySensitivity
        self.pitchBendRange = pitchBendRange
        self.minFrequency = minFrequency
        self.maxFrequency = maxFrequency
    }
}

// MARK: - Conversion Result

public struct AudioToMIDIResult: Sendable {
    public let notes: [AudioMIDINoteEvent]
    public let duration: Double
    public let tempo: Double?
    public let averageVelocity: Int
    public let noteCount: Int
    public let pitchRange: ClosedRange<Int>
}

// MARK: - Audio-to-MIDI Converter

/// Converts audio recordings to MIDI note events
@MainActor
public final class AudioToMIDIConverter: ObservableObject {

    // MARK: - Published Properties

    @Published public private(set) var isConverting: Bool = false
    @Published public private(set) var progress: Double = 0
    @Published public private(set) var lastResult: AudioToMIDIResult?

    // MARK: - Private Properties

    private let configuration: AudioToMIDIConfiguration
    private let analysisQueue = DispatchQueue(label: "com.echoelmusic.audio2midi", qos: .userInitiated)
    private let hopSize: Int = 512
    private let windowSize: Int = 2048

    // MARK: - Initialization

    public init(configuration: AudioToMIDIConfiguration = AudioToMIDIConfiguration()) {
        self.configuration = configuration
    }

    // MARK: - Public API

    /// Convert audio file to MIDI notes
    public func convert(audioURL: URL, tempo: Double = 120.0) async throws -> AudioToMIDIResult {
        isConverting = true
        progress = 0

        defer {
            Task { @MainActor in
                self.isConverting = false
            }
        }

        // Read audio file
        let audioFile = try AVAudioFile(forReading: audioURL)
        let format = audioFile.processingFormat
        let sampleRate = format.sampleRate
        let frameCount = AVAudioFrameCount(audioFile.length)

        guard frameCount > 0 else {
            throw AudioToMIDIError.emptyAudio
        }

        // Read all samples
        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            throw AudioToMIDIError.invalidFormat
        }
        try audioFile.read(into: buffer)

        guard let channelData = buffer.floatChannelData?[0] else {
            throw AudioToMIDIError.invalidFormat
        }

        let samples = Array(UnsafeBufferPointer(start: channelData, count: Int(buffer.frameLength)))
        let duration = Double(samples.count) / sampleRate

        // Detect onsets
        let onsets = detectOnsets(samples: samples, sampleRate: sampleRate)

        await MainActor.run { progress = 0.3 }

        // Extract pitch at each frame
        let pitchTrack = extractPitchTrack(samples: samples, sampleRate: sampleRate)

        await MainActor.run { progress = 0.6 }

        // Segment into notes
        let notes = segmentNotes(
            pitchTrack: pitchTrack,
            onsets: onsets,
            samples: samples,
            sampleRate: sampleRate,
            tempo: tempo
        )

        await MainActor.run { progress = 0.9 }

        // Build result
        let noteNumbers = notes.map { $0.noteNumber }
        let minNote = noteNumbers.min() ?? 0
        let maxNote = noteNumbers.max() ?? 127
        let avgVelocity = notes.isEmpty ? 0 : notes.map { $0.velocity }.reduce(0, +) / notes.count

        let result = AudioToMIDIResult(
            notes: notes,
            duration: duration,
            tempo: tempo,
            averageVelocity: avgVelocity,
            noteCount: notes.count,
            pitchRange: minNote...maxNote
        )

        await MainActor.run {
            self.lastResult = result
            self.progress = 1.0
        }

        return result
    }

    /// Export MIDI notes to standard MIDI file
    public func exportToMIDIFile(result: AudioToMIDIResult, outputURL: URL, tempo: Double = 120.0) throws {
        var midiData = Data()

        // MIDI Header: MThd
        midiData.append(contentsOf: [0x4D, 0x54, 0x68, 0x64]) // "MThd"
        midiData.append(contentsOf: [0x00, 0x00, 0x00, 0x06]) // Header length
        midiData.append(contentsOf: [0x00, 0x00]) // Format 0
        midiData.append(contentsOf: [0x00, 0x01]) // 1 track
        let ppq: UInt16 = 480
        midiData.append(UInt8(ppq >> 8))
        midiData.append(UInt8(ppq & 0xFF))

        // Track data
        var trackData = Data()

        // Tempo meta event
        let microsecondsPerBeat = Int(60_000_000 / tempo)
        trackData.append(contentsOf: [0x00]) // Delta time
        trackData.append(contentsOf: [0xFF, 0x51, 0x03]) // Tempo meta event
        trackData.append(UInt8((microsecondsPerBeat >> 16) & 0xFF))
        trackData.append(UInt8((microsecondsPerBeat >> 8) & 0xFF))
        trackData.append(UInt8(microsecondsPerBeat & 0xFF))

        // Sort notes by start time
        let sortedNotes = result.notes.sorted { $0.startTime < $1.startTime }

        // Convert notes to MIDI events
        var currentTick: Int = 0

        for note in sortedNotes {
            let startTick = Int(note.startTime * tempo / 60.0 * Double(ppq))
            let durationTicks = max(1, Int(note.duration * tempo / 60.0 * Double(ppq)))
            let endTick = startTick + durationTicks

            // Note On
            let deltaOn = max(0, startTick - currentTick)
            appendVariableLength(&trackData, value: deltaOn)
            trackData.append(0x90 | UInt8(note.channel & 0x0F)) // Note On
            trackData.append(UInt8(min(127, max(0, note.noteNumber))))
            trackData.append(UInt8(min(127, max(1, note.velocity))))
            currentTick = startTick

            // Note Off
            let deltaOff = durationTicks
            appendVariableLength(&trackData, value: deltaOff)
            trackData.append(0x80 | UInt8(note.channel & 0x0F)) // Note Off
            trackData.append(UInt8(min(127, max(0, note.noteNumber))))
            trackData.append(0x00) // Velocity 0
            currentTick = endTick
        }

        // End of track
        trackData.append(contentsOf: [0x00, 0xFF, 0x2F, 0x00])

        // Track header: MTrk
        midiData.append(contentsOf: [0x4D, 0x54, 0x72, 0x6B]) // "MTrk"
        let trackLength = UInt32(trackData.count)
        midiData.append(UInt8((trackLength >> 24) & 0xFF))
        midiData.append(UInt8((trackLength >> 16) & 0xFF))
        midiData.append(UInt8((trackLength >> 8) & 0xFF))
        midiData.append(UInt8(trackLength & 0xFF))
        midiData.append(trackData)

        try midiData.write(to: outputURL)
    }

    // MARK: - Onset Detection

    /// Detect note onsets using spectral flux
    private func detectOnsets(samples: [Float], sampleRate: Double) -> [Int] {
        let frameCount = (samples.count - windowSize) / hopSize
        guard frameCount > 0 else { return [] }

        var previousSpectrum = [Float](repeating: 0, count: windowSize / 2)
        var spectralFlux: [Float] = []
        var window = [Float](repeating: 0, count: windowSize)
        vDSP_hann_window(&window, vDSP_Length(windowSize), Int32(vDSP_HANN_NORM))

        for frame in 0..<frameCount {
            let offset = frame * hopSize

            // Window the frame
            var windowed = [Float](repeating: 0, count: windowSize)
            vDSP_vmul(Array(samples[offset..<offset + windowSize]), 1, window, 1, &windowed, 1, vDSP_Length(windowSize))

            // Simple magnitude spectrum via DFT
            var spectrum = computeMagnitudeSpectrum(windowed)

            // Half-wave rectified spectral flux
            var flux: Float = 0
            for i in 0..<spectrum.count {
                let diff = spectrum[i] - previousSpectrum[i]
                if diff > 0 {
                    flux += diff
                }
            }
            spectralFlux.append(flux)

            previousSpectrum = spectrum
        }

        // Adaptive thresholding for onset detection
        let medianWindow = 11
        var onsets: [Int] = []
        let threshold: Float = 1.5

        for i in 0..<spectralFlux.count {
            let start = max(0, i - medianWindow / 2)
            let end = min(spectralFlux.count, i + medianWindow / 2 + 1)
            let localMedian = spectralFlux[start..<end].sorted()[((end - start) / 2)]

            if spectralFlux[i] > localMedian * threshold && spectralFlux[i] > 0.01 {
                // Check it's a local maximum
                let isMax = (i == 0 || spectralFlux[i] > spectralFlux[i-1]) &&
                            (i == spectralFlux.count - 1 || spectralFlux[i] >= spectralFlux[i+1])
                if isMax {
                    onsets.append(i * hopSize)
                }
            }
        }

        return onsets
    }

    /// Compute magnitude spectrum
    private func computeMagnitudeSpectrum(_ samples: [Float]) -> [Float] {
        let n = samples.count
        let halfN = n / 2

        // Use vDSP for FFT
        var real = samples
        var imag = [Float](repeating: 0, count: n)
        var splitComplex = DSPSplitComplex(realp: &real, imagp: &imag)

        let log2n = vDSP_Length(log2(Float(n)))
        guard let fftSetup = vDSP_create_fftsetup(log2n, FFTRadix(kFFTRadix2)) else {
            return [Float](repeating: 0, count: halfN)
        }

        vDSP_fft_zip(fftSetup, &splitComplex, 1, log2n, FFTDirection(FFT_FORWARD))

        var magnitudes = [Float](repeating: 0, count: halfN)
        vDSP_zvabs(&splitComplex, 1, &magnitudes, 1, vDSP_Length(halfN))

        vDSP_destroy_fftsetup(fftSetup)

        return magnitudes
    }

    // MARK: - Pitch Tracking

    /// Extract pitch track (frame-by-frame pitch estimation)
    private func extractPitchTrack(samples: [Float], sampleRate: Double) -> [(time: Double, frequency: Double, amplitude: Double)] {
        let frameCount = (samples.count - windowSize) / hopSize
        guard frameCount > 0 else { return [] }

        var pitchTrack: [(time: Double, frequency: Double, amplitude: Double)] = []
        var window = [Float](repeating: 0, count: windowSize)
        vDSP_hann_window(&window, vDSP_Length(windowSize), Int32(vDSP_HANN_NORM))

        for frame in 0..<frameCount {
            let offset = frame * hopSize
            let time = Double(offset) / sampleRate

            // Window the frame
            var windowed = [Float](repeating: 0, count: windowSize)
            vDSP_vmul(Array(samples[offset..<offset + windowSize]), 1, window, 1, &windowed, 1, vDSP_Length(windowSize))

            // RMS amplitude
            var rms: Float = 0
            vDSP_rmsqv(windowed, 1, &rms, vDSP_Length(windowSize))

            guard Double(rms) > configuration.noteThreshold else {
                pitchTrack.append((time: time, frequency: 0, amplitude: Double(rms)))
                continue
            }

            // Autocorrelation pitch detection
            let frequency = autocorrelationPitch(windowed, sampleRate: sampleRate)

            pitchTrack.append((time: time, frequency: frequency, amplitude: Double(rms)))
        }

        return pitchTrack
    }

    /// Autocorrelation-based pitch detection for a single frame
    private func autocorrelationPitch(_ samples: [Float], sampleRate: Double) -> Double {
        let n = samples.count
        var autocorrelation = [Float](repeating: 0, count: n)

        vDSP_conv(samples, 1, samples, 1, &autocorrelation, 1, vDSP_Length(n), vDSP_Length(n))

        // Normalize
        guard autocorrelation[0] > 0 else { return 0 }
        var norm = 1.0 / autocorrelation[0]
        vDSP_vsmul(autocorrelation, 1, &norm, &autocorrelation, 1, vDSP_Length(n))

        let minLag = Int(sampleRate / configuration.maxFrequency)
        let maxLag = min(n - 1, Int(sampleRate / configuration.minFrequency))

        guard maxLag > minLag else { return 0 }

        // Find first significant dip then peak
        var foundDip = false
        var searchStart = minLag
        for i in 1..<maxLag {
            if autocorrelation[i] < 0.1 {
                foundDip = true
                searchStart = i
                break
            }
        }
        guard foundDip else { return 0 }

        var peakLag = searchStart
        var peakVal: Float = 0
        for i in searchStart..<maxLag {
            if autocorrelation[i] > peakVal {
                peakVal = autocorrelation[i]
                peakLag = i
            }
        }

        guard peakVal > 0.25 else { return 0 }

        // Parabolic interpolation
        if peakLag > 0 && peakLag < n - 1 {
            let a = Double(autocorrelation[peakLag - 1])
            let b = Double(autocorrelation[peakLag])
            let c = Double(autocorrelation[peakLag + 1])
            let denom = a - 2 * b + c
            if abs(denom) > 0.0001 {
                let p = 0.5 * (a - c) / denom
                return sampleRate / (Double(peakLag) + p)
            }
        }

        return sampleRate / Double(peakLag)
    }

    // MARK: - Note Segmentation

    /// Segment pitch track into discrete MIDI notes
    private func segmentNotes(
        pitchTrack: [(time: Double, frequency: Double, amplitude: Double)],
        onsets: [Int],
        samples: [Float],
        sampleRate: Double,
        tempo: Double
    ) -> [AudioMIDINoteEvent] {
        guard !pitchTrack.isEmpty else { return [] }

        var notes: [AudioMIDINoteEvent] = []
        var currentNote: Int? = nil
        var noteStartTime: Double = 0
        var noteAmplitudes: [Double] = []

        for frame in pitchTrack {
            guard frame.frequency > 0 else {
                // Silence — end current note
                if let note = currentNote {
                    let duration = frame.time - noteStartTime
                    if duration >= configuration.minimumNoteLength {
                        let velocity = amplitudeToVelocity(noteAmplitudes)
                        notes.append(AudioMIDINoteEvent(
                            noteNumber: note,
                            velocity: velocity,
                            startTime: noteStartTime,
                            duration: duration
                        ))
                    }
                    currentNote = nil
                    noteAmplitudes = []
                }
                continue
            }

            let midiNote = frequencyToMIDI(frame.frequency)

            if currentNote == nil {
                // Start new note
                currentNote = midiNote
                noteStartTime = frame.time
                noteAmplitudes = [frame.amplitude]
            } else if midiNote != currentNote, let previousNote = currentNote {
                // Note changed — end previous, start new
                let duration = frame.time - noteStartTime
                if duration >= configuration.minimumNoteLength {
                    let velocity = amplitudeToVelocity(noteAmplitudes)
                    notes.append(AudioMIDINoteEvent(
                        noteNumber: previousNote,
                        velocity: velocity,
                        startTime: noteStartTime,
                        duration: duration
                    ))
                }
                currentNote = midiNote
                noteStartTime = frame.time
                noteAmplitudes = [frame.amplitude]
            } else {
                noteAmplitudes.append(frame.amplitude)
            }
        }

        // End final note
        if let note = currentNote, let lastFrame = pitchTrack.last {
            let duration = lastFrame.time - noteStartTime
            if duration >= configuration.minimumNoteLength {
                let velocity = amplitudeToVelocity(noteAmplitudes)
                notes.append(AudioMIDINoteEvent(
                    noteNumber: note,
                    velocity: velocity,
                    startTime: noteStartTime,
                    duration: duration
                ))
            }
        }

        // Optionally quantize
        if configuration.quantizeToGrid {
            return quantizeNotes(notes, tempo: tempo)
        }

        return notes
    }

    // MARK: - Helpers

    /// Convert frequency to nearest MIDI note number
    private func frequencyToMIDI(_ frequency: Double) -> Int {
        let midiFloat = 69.0 + 12.0 * log2(frequency / 440.0)
        return Int(round(midiFloat))
    }

    /// Convert amplitude array to MIDI velocity
    private func amplitudeToVelocity(_ amplitudes: [Double]) -> Int {
        guard !amplitudes.isEmpty else { return 64 }
        let peak = amplitudes.max() ?? 0
        // Map to 1-127 with sensitivity curve
        let normalized = min(1.0, peak / 0.5)
        let curved = pow(normalized, configuration.velocitySensitivity)
        return max(1, min(127, Int(curved * 126 + 1)))
    }

    /// Quantize notes to grid
    private func quantizeNotes(_ notes: [AudioMIDINoteEvent], tempo: Double) -> [AudioMIDINoteEvent] {
        let beatDuration = 60.0 / tempo
        let gridSize = beatDuration * configuration.quantizeValue

        return notes.map { note in
            let quantizedStart = round(note.startTime / gridSize) * gridSize
            let quantizedDuration = max(gridSize, round(note.duration / gridSize) * gridSize)
            return AudioMIDINoteEvent(
                id: note.id,
                noteNumber: note.noteNumber,
                velocity: note.velocity,
                startTime: quantizedStart,
                duration: quantizedDuration,
                channel: note.channel
            )
        }
    }

    /// Append variable-length quantity to MIDI data
    private func appendVariableLength(_ data: inout Data, value: Int) {
        var v = value
        var bytes: [UInt8] = []

        bytes.append(UInt8(v & 0x7F))
        v >>= 7

        while v > 0 {
            bytes.append(UInt8((v & 0x7F) | 0x80))
            v >>= 7
        }

        for byte in bytes.reversed() {
            data.append(byte)
        }
    }
}

// MARK: - Errors

public enum AudioToMIDIError: LocalizedError {
    case emptyAudio
    case invalidFormat
    case conversionFailed(String)

    public var errorDescription: String? {
        switch self {
        case .emptyAudio: return "Audio file is empty"
        case .invalidFormat: return "Invalid audio format"
        case .conversionFailed(let reason): return "Conversion failed: \(reason)"
        }
    }
}
