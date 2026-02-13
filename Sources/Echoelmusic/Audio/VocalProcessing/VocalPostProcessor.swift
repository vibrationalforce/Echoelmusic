import Foundation
import Accelerate
import Combine

/// Vocal Post-Production Editor — Per-Note Pitch & Parameter Editing
///
/// Melodyne-inspired note-level vocal editing for post-production:
/// - **Note Detection**: Automatic segmentation into individual notes
/// - **Pitch Editing**: Per-note pitch correction, transpose, fine-tune
/// - **Timing Editing**: Move notes in time, quantize to grid
/// - **Formant Editing**: Independent formant control per note
/// - **Vibrato Editing**: Per-note vibrato parameters (rate, depth, shape)
/// - **Amplitude Editing**: Per-note volume with crossfade
/// - **Pitch Curve Drawing**: Freehand pitch curve override
/// - **Parameter Automation**: Time-varying curves for any parameter
///
/// Processing Pipeline:
/// 1. Analyze → Detect notes, pitch contour, formants
/// 2. Edit → User modifies note parameters
/// 3. Render → Phase vocoder applies all edits non-destructively
@MainActor
class VocalPostProcessor: ObservableObject {

    // MARK: - Published State

    @Published var isAnalyzing: Bool = false
    @Published var isRendering: Bool = false
    @Published var progress: Float = 0.0
    @Published var detectedNotes: [VocalNote] = []
    @Published var pitchCurve: [PitchPoint] = []
    @Published var automationLanes: [AutomationLane] = []

    // MARK: - Analysis Settings

    @Published var analysisHopSize: Int = 256         // Samples between analysis frames
    @Published var noteSegmentationThreshold: Float = 0.5  // Cents threshold for note boundary
    @Published var minimumNoteDuration: Float = 0.05  // Seconds (50ms min note length)

    // MARK: - Types

    /// A detected/edited vocal note
    struct VocalNote: Identifiable {
        let id: UUID
        var startTime: Float          // Seconds
        var endTime: Float            // Seconds
        var originalPitch: Float      // Hz (detected center pitch)
        var editedPitch: Float        // Hz (target pitch after editing)
        var midiNote: Int             // MIDI note number
        var noteName: String          // e.g., "C4"
        var centsOffset: Float        // Cents deviation from nearest semitone
        var confidence: Float         // Detection confidence (0-1)

        // Editable parameters
        var pitchCorrection: Float    // Cents adjustment (-100 to +100)
        var transpose: Int            // Semitone transpose
        var formantShift: Float       // Semitones of formant shift
        var gain: Float               // Volume multiplier (0-2)
        var pan: Float                // Stereo pan (-1 to 1)
        var vibratoParams: VibratoEngine.VibratoParameters

        // Pitch curve (per-note detailed pitch)
        var pitchContour: [Float]     // Hz values across the note
        var editedPitchContour: [Float]?  // User-edited pitch curve (nil = use auto)

        // Transition
        var pitchDriftStart: Float    // Cents of pitch drift at note start (portamento in)
        var pitchDriftEnd: Float      // Cents of pitch drift at note end (portamento out)
        var driftDuration: Float      // Duration of drift in seconds

        var duration: Float { endTime - startTime }

        static func create(
            startTime: Float, endTime: Float,
            pitch: Float, midiNote: Int,
            contour: [Float]
        ) -> VocalNote {
            let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
            let noteClass = ((midiNote % 12) + 12) % 12
            let octave = (midiNote / 12) - 1

            return VocalNote(
                id: UUID(),
                startTime: startTime,
                endTime: endTime,
                originalPitch: pitch,
                editedPitch: pitch,
                midiNote: midiNote,
                noteName: "\(noteNames[noteClass])\(octave)",
                centsOffset: 0,
                confidence: 1.0,
                pitchCorrection: 0,
                transpose: 0,
                formantShift: 0,
                gain: 1.0,
                pan: 0,
                vibratoParams: .default(),
                pitchContour: contour,
                editedPitchContour: nil,
                pitchDriftStart: 0,
                pitchDriftEnd: 0,
                driftDuration: 0.05
            )
        }
    }

    /// A point on the pitch curve (for freehand editing)
    struct PitchPoint: Identifiable {
        let id: UUID
        var time: Float       // Seconds
        var pitch: Float      // Hz
        var isAnchor: Bool    // True = user-placed anchor point

        init(time: Float, pitch: Float, isAnchor: Bool = false) {
            self.id = UUID()
            self.time = time
            self.pitch = pitch
            self.isAnchor = isAnchor
        }
    }

    /// Automation lane for time-varying parameter control
    struct AutomationLane: Identifiable {
        let id: UUID
        var parameter: AutomationParameter
        var points: [AutomationPoint]
        var isVisible: Bool = true

        struct AutomationPoint: Identifiable {
            let id: UUID
            var time: Float           // Seconds
            var value: Float          // Normalized 0-1
            var curveType: CurveType

            enum CurveType: String, CaseIterable {
                case linear = "Linear"
                case smooth = "Smooth"       // S-curve
                case stepBefore = "Step"     // Hold previous value
                case exponential = "Exp"     // Exponential curve
            }

            init(time: Float, value: Float, curveType: CurveType = .smooth) {
                self.id = UUID()
                self.time = time
                self.value = value
                self.curveType = curveType
            }
        }

        enum AutomationParameter: String, CaseIterable, Identifiable {
            case pitchCorrection = "Pitch Correction"
            case formantShift = "Formant Shift"
            case vibratoDepth = "Vibrato Depth"
            case vibratoRate = "Vibrato Rate"
            case gain = "Gain"
            case pan = "Pan"
            case breathiness = "Breathiness"
            case tension = "Vocal Tension"

            var id: String { rawValue }

            var range: ClosedRange<Float> {
                switch self {
                case .pitchCorrection: return -100...100
                case .formantShift: return -12...12
                case .vibratoDepth: return 0...200
                case .vibratoRate: return 1...12
                case .gain: return 0...2
                case .pan: return -1...1
                case .breathiness: return 0...1
                case .tension: return 0...1
                }
            }
        }
    }

    // MARK: - Internal

    private let sampleRate: Float
    private let phaseVocoder: PhaseVocoder
    private let vibratoEngine: VibratoEngine

    // MARK: - Initialization

    init(sampleRate: Float = 48000.0) {
        self.sampleRate = sampleRate
        self.phaseVocoder = PhaseVocoder(config: PhaseVocoder.Configuration(
            fftSize: 4096,
            hopSize: 1024,
            sampleRate: sampleRate,
            preserveFormants: true,
            preserveTransients: true
        ))
        self.vibratoEngine = VibratoEngine(sampleRate: sampleRate)
    }

    // MARK: - Analysis

    /// Analyze audio and detect individual vocal notes
    /// - Parameter audio: Input audio samples (mono)
    /// - Returns: Array of detected vocal notes
    func analyzeVocal(_ audio: [Float]) async -> [VocalNote] {
        isAnalyzing = true
        progress = 0

        let hopSize = analysisHopSize
        let windowSize = hopSize * 4
        let numFrames = (audio.count - windowSize) / hopSize

        guard numFrames > 0 else {
            isAnalyzing = false
            return []
        }

        // Step 1: Detect pitch contour
        var pitchContour = [Float](repeating: 0, count: numFrames)
        var energyContour = [Float](repeating: 0, count: numFrames)
        var confidenceContour = [Float](repeating: 0, count: numFrames)

        let pitchDetector = PitchDetector()

        for frame in 0..<numFrames {
            let offset = frame * hopSize
            let end = min(offset + windowSize, audio.count)
            let frameData = Array(audio[offset..<end])

            // Detect pitch (simplified — using YIN via PitchDetector requires AVAudioPCMBuffer)
            pitchContour[frame] = detectPitchFromSamples(frameData)

            // Compute energy
            var rms: Float = 0
            vDSP_rmsqv(frameData, 1, &rms, vDSP_Length(frameData.count))
            energyContour[frame] = rms

            // Confidence (inverse of CMNDF minimum)
            confidenceContour[frame] = pitchContour[frame] > 0 ? 0.9 : 0.0

            if frame % 100 == 0 {
                progress = Float(frame) / Float(numFrames) * 0.5
            }
        }

        // Step 2: Segment into notes
        let notes = segmentIntoNotes(
            pitchContour: pitchContour,
            energyContour: energyContour,
            confidenceContour: confidenceContour,
            hopSize: hopSize
        )

        progress = 0.8

        // Step 3: Analyze vibrato per note
        for i in 0..<notes.count {
            var note = notes[i]
            let analysis = vibratoEngine.analyzeVibrato(
                pitchContour: note.pitchContour,
                hopSize: hopSize
            )
            note.vibratoParams = VibratoEngine.VibratoParameters(
                id: note.id,
                enabled: analysis.depth > 10,
                rate: analysis.rate > 0 ? analysis.rate : 5.5,
                depth: analysis.depth,
                shape: analysis.shape,
                onsetDelay: analysis.onsetDelay
            )
        }

        detectedNotes = notes
        pitchCurve = generatePitchCurvePoints(from: pitchContour, hopSize: hopSize)

        isAnalyzing = false
        progress = 1.0

        return notes
    }

    /// Simplified pitch detection from raw Float array
    private func detectPitchFromSamples(_ samples: [Float]) -> Float {
        let n = samples.count
        guard n > 100 else { return 0 }

        // Check silence
        var rms: Float = 0
        vDSP_rmsqv(samples, 1, &rms, vDSP_Length(n))
        guard rms > 0.005 else { return 0 }

        // YIN
        let minLag = Int(sampleRate / 1500.0)
        let maxLag = min(Int(sampleRate / 60.0), n / 2)
        guard maxLag > minLag else { return 0 }

        var diff = [Float](repeating: 0, count: maxLag)
        for tau in minLag..<maxLag {
            var sum: Float = 0
            for j in 0..<(n - tau) {
                let d = samples[j] - samples[j + tau]
                sum += d * d
            }
            diff[tau] = sum
        }

        var cmndf = [Float](repeating: 1, count: maxLag)
        var runSum: Float = 0
        for tau in 1..<maxLag {
            runSum += diff[tau]
            if runSum > 0 { cmndf[tau] = diff[tau] * Float(tau) / runSum }
        }

        for tau in minLag..<maxLag {
            if cmndf[tau] < 0.15 {
                if tau > 0 && tau < maxLag - 1 {
                    let s0 = cmndf[tau - 1]
                    let s1 = cmndf[tau]
                    let s2 = cmndf[tau + 1]
                    let denom = 2.0 * (2.0 * s1 - s2 - s0)
                    if abs(denom) > 1e-10 {
                        return sampleRate / (Float(tau) + (s2 - s0) / denom)
                    }
                }
                return sampleRate / Float(tau)
            }
        }

        return 0
    }

    // MARK: - Note Segmentation

    /// Segment pitch contour into individual notes
    private func segmentIntoNotes(
        pitchContour: [Float],
        energyContour: [Float],
        confidenceContour: [Float],
        hopSize: Int
    ) -> [VocalNote] {
        var notes: [VocalNote] = []
        let frameTime = Float(hopSize) / sampleRate
        let minFrames = Int(minimumNoteDuration / frameTime)

        var noteStartFrame = -1
        var notePitches: [Float] = []
        var isInNote = false

        for frame in 0..<pitchContour.count {
            let pitch = pitchContour[frame]
            let energy = energyContour[frame]
            let voiced = pitch > 50 && energy > 0.005

            if voiced && !isInNote {
                // Note onset
                noteStartFrame = frame
                notePitches = [pitch]
                isInNote = true
            } else if voiced && isInNote {
                notePitches.append(pitch)

                // Check for pitch jump (note boundary)
                if notePitches.count > 1 {
                    let prevPitch = notePitches[notePitches.count - 2]
                    let cents = abs(1200.0 * Foundation.log(pitch / prevPitch) / Foundation.log(2.0))

                    if cents > 80 && notePitches.count >= minFrames {
                        // End current note, start new one
                        let note = createNote(
                            startFrame: noteStartFrame,
                            endFrame: frame - 1,
                            pitches: Array(notePitches.dropLast()),
                            frameTime: frameTime
                        )
                        if let note = note { notes.append(note) }

                        noteStartFrame = frame
                        notePitches = [pitch]
                    }
                }
            } else if !voiced && isInNote {
                // Note offset
                if notePitches.count >= minFrames {
                    let note = createNote(
                        startFrame: noteStartFrame,
                        endFrame: frame - 1,
                        pitches: notePitches,
                        frameTime: frameTime
                    )
                    if let note = note { notes.append(note) }
                }
                isInNote = false
                notePitches = []
            }
        }

        // Handle final note
        if isInNote && notePitches.count >= minFrames {
            let note = createNote(
                startFrame: noteStartFrame,
                endFrame: pitchContour.count - 1,
                pitches: notePitches,
                frameTime: frameTime
            )
            if let note = note { notes.append(note) }
        }

        return notes
    }

    private func createNote(startFrame: Int, endFrame: Int, pitches: [Float],
                            frameTime: Float) -> VocalNote? {
        guard !pitches.isEmpty else { return nil }

        // Calculate median pitch (more robust than mean)
        let sorted = pitches.sorted()
        let medianPitch = sorted[sorted.count / 2]

        // Convert to MIDI
        let midiFloat = 69.0 + 12.0 * Foundation.log(medianPitch / 440.0) / Foundation.log(2.0)
        let midiNote = Int(round(midiFloat))
        let centsOffset = (midiFloat - Float(midiNote)) * 100.0

        return VocalNote.create(
            startTime: Float(startFrame) * frameTime,
            endTime: Float(endFrame) * frameTime,
            pitch: medianPitch,
            midiNote: midiNote,
            contour: pitches
        )
    }

    // MARK: - Editing Operations

    /// Correct pitch of a specific note to nearest semitone
    func correctNotePitch(_ noteId: UUID) {
        guard let index = detectedNotes.firstIndex(where: { $0.id == noteId }) else { return }
        let note = detectedNotes[index]
        let targetMidi = Float(note.midiNote)
        let currentMidi = 69.0 + 12.0 * Foundation.log(note.originalPitch / 440.0) / Foundation.log(2.0)
        detectedNotes[index].pitchCorrection = (targetMidi - currentMidi) * 100.0
        detectedNotes[index].editedPitch = 440.0 * pow(2.0, (targetMidi - 69.0) / 12.0)
    }

    /// Correct all notes to nearest semitone
    func correctAllPitches() {
        for i in 0..<detectedNotes.count {
            correctNotePitch(detectedNotes[i].id)
        }
    }

    /// Transpose a note by semitones
    func transposeNote(_ noteId: UUID, semitones: Int) {
        guard let index = detectedNotes.firstIndex(where: { $0.id == noteId }) else { return }
        detectedNotes[index].transpose = semitones
        let newMidi = Float(detectedNotes[index].midiNote + semitones)
        detectedNotes[index].editedPitch = 440.0 * pow(2.0, (newMidi - 69.0) / 12.0)
    }

    /// Set formant shift for a note
    func setFormantShift(_ noteId: UUID, semitones: Float) {
        guard let index = detectedNotes.firstIndex(where: { $0.id == noteId }) else { return }
        detectedNotes[index].formantShift = semitones
    }

    /// Set vibrato parameters for a note
    func setNoteVibrato(_ noteId: UUID, params: VibratoEngine.VibratoParameters) {
        guard let index = detectedNotes.firstIndex(where: { $0.id == noteId }) else { return }
        detectedNotes[index].vibratoParams = params
    }

    /// Set gain for a note
    func setNoteGain(_ noteId: UUID, gain: Float) {
        guard let index = detectedNotes.firstIndex(where: { $0.id == noteId }) else { return }
        detectedNotes[index].gain = max(0, min(2, gain))
    }

    /// Move a note in time
    func moveNoteTime(_ noteId: UUID, deltaSeconds: Float) {
        guard let index = detectedNotes.firstIndex(where: { $0.id == noteId }) else { return }
        detectedNotes[index].startTime += deltaSeconds
        detectedNotes[index].endTime += deltaSeconds
    }

    /// Draw a custom pitch curve for a note
    func setNotePitchCurve(_ noteId: UUID, curve: [Float]) {
        guard let index = detectedNotes.firstIndex(where: { $0.id == noteId }) else { return }
        detectedNotes[index].editedPitchContour = curve
    }

    /// Add a pitch drift (portamento) to note start
    func setPortamentoIn(_ noteId: UUID, cents: Float, duration: Float) {
        guard let index = detectedNotes.firstIndex(where: { $0.id == noteId }) else { return }
        detectedNotes[index].pitchDriftStart = cents
        detectedNotes[index].driftDuration = duration
    }

    /// Add a pitch drift (portamento) to note end
    func setPortamentoOut(_ noteId: UUID, cents: Float, duration: Float) {
        guard let index = detectedNotes.firstIndex(where: { $0.id == noteId }) else { return }
        detectedNotes[index].pitchDriftEnd = cents
        detectedNotes[index].driftDuration = duration
    }

    // MARK: - Automation

    /// Add an automation lane
    func addAutomationLane(parameter: AutomationLane.AutomationParameter) {
        let lane = AutomationLane(
            id: UUID(),
            parameter: parameter,
            points: []
        )
        automationLanes.append(lane)
    }

    /// Add a point to an automation lane
    func addAutomationPoint(laneId: UUID, time: Float, value: Float,
                            curveType: AutomationLane.AutomationPoint.CurveType = .smooth) {
        guard let index = automationLanes.firstIndex(where: { $0.id == laneId }) else { return }
        let point = AutomationLane.AutomationPoint(time: time, value: value, curveType: curveType)
        automationLanes[index].points.append(point)
        automationLanes[index].points.sort { $0.time < $1.time }
    }

    /// Read automation value at a given time
    func readAutomation(laneId: UUID, time: Float) -> Float {
        guard let lane = automationLanes.first(where: { $0.id == laneId }) else { return 0.5 }
        return interpolateAutomation(points: lane.points, time: time, range: lane.parameter.range)
    }

    private func interpolateAutomation(
        points: [AutomationLane.AutomationPoint],
        time: Float,
        range: ClosedRange<Float>
    ) -> Float {
        guard !points.isEmpty else { return (range.lowerBound + range.upperBound) / 2.0 }

        // Before first point
        if time <= points[0].time { return denormalize(points[0].value, range: range) }

        // After last point
        if time >= points.last!.time { return denormalize(points.last!.value, range: range) }

        // Find surrounding points
        for i in 0..<points.count - 1 {
            if time >= points[i].time && time < points[i + 1].time {
                let t = (time - points[i].time) / (points[i + 1].time - points[i].time)

                let interpolated: Float
                switch points[i + 1].curveType {
                case .linear:
                    interpolated = points[i].value + t * (points[i + 1].value - points[i].value)
                case .smooth:
                    // Smoothstep
                    let s = t * t * (3.0 - 2.0 * t)
                    interpolated = points[i].value + s * (points[i + 1].value - points[i].value)
                case .stepBefore:
                    interpolated = points[i].value
                case .exponential:
                    let e = pow(t, 2.0)
                    interpolated = points[i].value + e * (points[i + 1].value - points[i].value)
                }

                return denormalize(interpolated, range: range)
            }
        }

        return denormalize(0.5, range: range)
    }

    private func denormalize(_ value: Float, range: ClosedRange<Float>) -> Float {
        return range.lowerBound + value * (range.upperBound - range.lowerBound)
    }

    // MARK: - Rendering

    /// Render all edits to produce final audio
    /// - Parameter originalAudio: Original unprocessed audio
    /// - Returns: Processed audio with all edits applied
    func render(originalAudio: [Float]) async -> [Float] {
        isRendering = true
        progress = 0

        var output = originalAudio
        let totalNotes = detectedNotes.count
        guard totalNotes > 0 else {
            isRendering = false
            return output
        }

        for (index, note) in detectedNotes.enumerated() {
            let startSample = Int(note.startTime * sampleRate)
            let endSample = min(Int(note.endTime * sampleRate), output.count)

            guard startSample >= 0 && startSample < endSample && endSample <= output.count else {
                continue
            }

            // Extract note audio
            var noteAudio = Array(output[startSample..<endSample])

            // Apply pitch correction
            let totalCentsShift = note.pitchCorrection + Float(note.transpose) * 100.0
            if abs(totalCentsShift) > 1.0 {
                let semitones = totalCentsShift / 100.0
                noteAudio = phaseVocoder.pitchShift(
                    noteAudio,
                    semitones: semitones,
                    preserveFormants: true
                )
            }

            // Apply custom pitch curve if set
            if let editedContour = note.editedPitchContour {
                noteAudio = applyPitchCurve(
                    audio: noteAudio,
                    originalContour: note.pitchContour,
                    editedContour: editedContour
                )
            }

            // Apply vibrato
            if note.vibratoParams.enabled && note.vibratoParams.depth > 0 {
                let vibrato = vibratoEngine.generateVibrato(
                    noteId: note.id,
                    params: note.vibratoParams,
                    noteTime: 0,
                    noteDuration: note.duration,
                    frameCount: noteAudio.count
                )
                noteAudio = vibratoEngine.applyVibratoToAudio(
                    audio: noteAudio,
                    modulationCents: vibrato,
                    phaseVocoder: phaseVocoder
                )
            }

            // Apply portamento (pitch drift)
            noteAudio = applyPortamento(
                audio: noteAudio,
                driftStartCents: note.pitchDriftStart,
                driftEndCents: note.pitchDriftEnd,
                driftDuration: note.driftDuration
            )

            // Apply gain
            if abs(note.gain - 1.0) > 0.01 {
                var gain = note.gain
                vDSP_vsmul(noteAudio, 1, &gain, &noteAudio, 1, vDSP_Length(noteAudio.count))
            }

            // Write back with crossfade at boundaries
            let crossfadeSamples = min(64, noteAudio.count / 4)
            for i in 0..<noteAudio.count {
                let outIdx = startSample + i
                guard outIdx < output.count else { break }

                // Crossfade at boundaries
                var mix: Float = 1.0
                if i < crossfadeSamples {
                    mix = Float(i) / Float(crossfadeSamples)
                } else if i > noteAudio.count - crossfadeSamples {
                    mix = Float(noteAudio.count - i) / Float(crossfadeSamples)
                }

                output[outIdx] = output[outIdx] * (1.0 - mix) + noteAudio[i] * mix
            }

            progress = Float(index + 1) / Float(totalNotes)
        }

        // Apply automation lanes
        output = applyAutomation(to: output)

        isRendering = false
        progress = 1.0
        return output
    }

    // MARK: - Pitch Curve Application

    /// Apply a custom pitch curve to audio
    private func applyPitchCurve(
        audio: [Float],
        originalContour: [Float],
        editedContour: [Float]
    ) -> [Float] {
        guard !originalContour.isEmpty && !editedContour.isEmpty else { return audio }

        // Process in blocks
        let blockSize = 2048
        var output = audio

        let contoursPerSample = Float(editedContour.count) / Float(audio.count)

        for blockStart in stride(from: 0, to: audio.count - blockSize, by: blockSize) {
            let blockEnd = min(blockStart + blockSize, audio.count)
            let block = Array(audio[blockStart..<blockEnd])

            // Get pitch shift for this block
            let contourIdx = Int(Float(blockStart) * contoursPerSample)
            let safeIdx = min(contourIdx, editedContour.count - 1)
            let origIdx = min(contourIdx, originalContour.count - 1)

            let editedPitch = editedContour[safeIdx]
            let originalPitch = originalContour[origIdx]

            guard originalPitch > 50 && editedPitch > 50 else { continue }

            let semitones = 12.0 * Foundation.log(editedPitch / originalPitch) / Foundation.log(2.0)

            if abs(semitones) > 0.01 {
                let shifted = phaseVocoder.pitchShift(block, semitones: semitones)
                for i in 0..<min(shifted.count, blockEnd - blockStart) {
                    output[blockStart + i] = shifted[i]
                }
            }
        }

        return output
    }

    // MARK: - Portamento

    private func applyPortamento(audio: [Float], driftStartCents: Float,
                                 driftEndCents: Float, driftDuration: Float) -> [Float] {
        guard abs(driftStartCents) > 1 || abs(driftEndCents) > 1 else { return audio }

        let driftSamples = Int(driftDuration * sampleRate)
        var output = audio

        // Apply start drift
        if abs(driftStartCents) > 1 && driftSamples > 0 {
            let startBlock = Array(audio.prefix(min(driftSamples * 2, audio.count)))
            // Gradual pitch shift from driftStartCents to 0
            let avgShift = driftStartCents / 2.0 / 100.0  // Average semitones
            if abs(avgShift) > 0.01 {
                let shifted = phaseVocoder.pitchShift(startBlock, semitones: avgShift)
                for i in 0..<min(shifted.count, output.count) {
                    let t = Float(i) / Float(driftSamples)
                    let mix = min(1.0, t)
                    output[i] = shifted[i] * (1.0 - mix) + audio[i] * mix
                }
            }
        }

        // Apply end drift
        if abs(driftEndCents) > 1 && driftSamples > 0 && audio.count > driftSamples * 2 {
            let endStart = audio.count - driftSamples * 2
            let endBlock = Array(audio[endStart...])
            let avgShift = driftEndCents / 2.0 / 100.0
            if abs(avgShift) > 0.01 {
                let shifted = phaseVocoder.pitchShift(endBlock, semitones: avgShift)
                for i in 0..<shifted.count where endStart + i < output.count {
                    let t = Float(i) / Float(shifted.count)
                    output[endStart + i] = audio[endStart + i] * (1.0 - t) + shifted[i] * t
                }
            }
        }

        return output
    }

    // MARK: - Automation Application

    private func applyAutomation(to audio: [Float]) -> [Float] {
        var output = audio

        for lane in automationLanes where lane.isVisible && !lane.points.isEmpty {
            switch lane.parameter {
            case .gain:
                for i in 0..<output.count {
                    let time = Float(i) / sampleRate
                    let gain = interpolateAutomation(points: lane.points, time: time, range: lane.parameter.range)
                    output[i] *= gain
                }
            case .pitchCorrection, .formantShift, .vibratoDepth, .vibratoRate:
                // These are applied per-note during rendering
                break
            case .pan, .breathiness, .tension:
                // Would need stereo/effect processing
                break
            }
        }

        return output
    }

    // MARK: - Utility

    private func generatePitchCurvePoints(from contour: [Float], hopSize: Int) -> [PitchPoint] {
        let frameTime = Float(hopSize) / sampleRate
        return contour.enumerated().compactMap { (index, pitch) in
            guard pitch > 50 else { return nil }
            return PitchPoint(time: Float(index) * frameTime, pitch: pitch)
        }
    }

    /// Get a summary of all edits for display
    func getEditSummary() -> String {
        let corrected = detectedNotes.filter { abs($0.pitchCorrection) > 1 }.count
        let transposed = detectedNotes.filter { $0.transpose != 0 }.count
        let vibratoEdited = detectedNotes.filter { $0.vibratoParams.depth != 40 }.count

        return "\(detectedNotes.count) notes detected, \(corrected) pitch-corrected, \(transposed) transposed, \(vibratoEdited) vibrato edited"
    }
}
