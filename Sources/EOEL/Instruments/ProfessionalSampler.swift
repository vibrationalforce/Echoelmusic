//
//  ProfessionalSampler.swift
//  EOEL
//
//  Professional Multi-Sample Instrument
//  Kontakt-style sampler with multi-layer support
//

import AVFoundation
import Accelerate

// MARK: - Sample Region

struct SampleRegion: Identifiable, Codable {
    let id: UUID
    var name: String
    var audioFileURL: URL?
    var rootNote: UInt8  // MIDI note (60 = C4)
    var minNote: UInt8  // Key range start
    var maxNote: UInt8  // Key range end
    var minVelocity: UInt8  // Velocity range start (0-127)
    var maxVelocity: UInt8  // Velocity range end (0-127)
    var tuning: Float  // Cents (-100 to +100)
    var volume: Float  // 0-1
    var pan: Float  // -1 (left) to +1 (right)
    var loopEnabled: Bool = false
    var loopStart: Int = 0  // Sample frame
    var loopEnd: Int = 0  // Sample frame

    init(name: String, rootNote: UInt8 = 60) {
        self.id = UUID()
        self.name = name
        self.rootNote = rootNote
        self.minNote = rootNote
        self.maxNote = rootNote
        self.minVelocity = 0
        self.maxVelocity = 127
        self.tuning = 0.0
        self.volume = 1.0
        self.pan = 0.0
    }

    func matches(note: UInt8, velocity: UInt8) -> Bool {
        return note >= minNote && note <= maxNote && velocity >= minVelocity && velocity <= maxVelocity
    }
}

// MARK: - Sampler Voice

class SamplerVoice {
    var isActive: Bool = false
    var note: UInt8 = 0
    var velocity: UInt8 = 0
    var sampleData: [Float] = []
    var playbackPosition: Double = 0.0
    var pitchRatio: Double = 1.0
    var amplitude: Float = 1.0
    var pan: Float = 0.0

    // ADSR Envelope
    var envelopePhase: EnvelopePhase = .idle
    var envelopeLevel: Float = 0.0

    enum EnvelopePhase {
        case idle, attack, decay, sustain, release
    }

    struct ADSREnvelope {
        var attack: Float = 0.01  // seconds
        var decay: Float = 0.1
        var sustain: Float = 0.7  // level (0-1)
        var release: Float = 0.3
    }

    var envelope: ADSREnvelope = ADSREnvelope()

    // Loop settings
    var loopEnabled: Bool = false
    var loopStart: Int = 0
    var loopEnd: Int = 0

    func trigger(note: UInt8, velocity: UInt8, sampleData: [Float], region: SampleRegion, sampleRate: Float) {
        self.isActive = true
        self.note = note
        self.velocity = velocity
        self.sampleData = sampleData
        self.playbackPosition = 0.0
        self.amplitude = region.volume * Float(velocity) / 127.0
        self.pan = region.pan
        self.loopEnabled = region.loopEnabled
        self.loopStart = region.loopStart
        self.loopEnd = region.loopEnd

        // Calculate pitch ratio (semitones to frequency ratio)
        let pitchOffset = Float(note) - Float(region.rootNote) + region.tuning / 100.0
        self.pitchRatio = Double(pow(2.0, pitchOffset / 12.0))

        // Start envelope
        envelopePhase = .attack
        envelopeLevel = 0.0
    }

    func release() {
        envelopePhase = .release
    }

    func renderSample(sampleRate: Float) -> (left: Float, right: Float) {
        guard isActive, !sampleData.isEmpty else { return (0, 0) }

        // Linear interpolation for sample playback
        let index = Int(playbackPosition)
        let frac = Float(playbackPosition - Double(index))

        guard index < sampleData.count - 1 else {
            if loopEnabled && loopEnd > loopStart {
                // Loop back to loop start
                playbackPosition = Double(loopStart)
            } else {
                // End of sample
                isActive = false
            }
            return (0, 0)
        }

        let sample1 = sampleData[index]
        let sample2 = sampleData[index + 1]
        var sample = sample1 + (sample2 - sample1) * frac

        // Update envelope
        updateEnvelope(sampleRate: sampleRate)
        sample *= envelopeLevel

        // Apply amplitude
        sample *= amplitude

        // Advance playback position
        playbackPosition += pitchRatio

        // Check for loop point
        if loopEnabled && Int(playbackPosition) >= loopEnd {
            playbackPosition = Double(loopStart)
        }

        // Apply panning (constant power pan law)
        let panRadians = pan * Float.pi / 4.0  // -45° to +45°
        let left = sample * cos(panRadians)
        let right = sample * sin(panRadians)

        return (left, right)
    }

    private func updateEnvelope(sampleRate: Float) {
        let samplesPerSecond = sampleRate

        switch envelopePhase {
        case .idle:
            envelopeLevel = 0.0

        case .attack:
            let increment = 1.0 / (envelope.attack * samplesPerSecond)
            envelopeLevel += increment
            if envelopeLevel >= 1.0 {
                envelopeLevel = 1.0
                envelopePhase = .decay
            }

        case .decay:
            let decrement = (1.0 - envelope.sustain) / (envelope.decay * samplesPerSecond)
            envelopeLevel -= decrement
            if envelopeLevel <= envelope.sustain {
                envelopeLevel = envelope.sustain
                envelopePhase = .sustain
            }

        case .sustain:
            envelopeLevel = envelope.sustain

        case .release:
            let decrement = envelope.sustain / (envelope.release * samplesPerSecond)
            envelopeLevel -= decrement
            if envelopeLevel <= 0.0 {
                envelopeLevel = 0.0
                envelopePhase = .idle
                isActive = false
            }
        }
    }
}

// MARK: - Professional Sampler Engine

@MainActor
class ProfessionalSampler: ObservableObject {

    @Published var name: String = "Sampler"
    @Published var regions: [SampleRegion] = []
    @Published var polyphony: Int = 64
    @Published var masterVolume: Float = 1.0
    @Published var masterTuning: Float = 0.0  // Cents

    private var voices: [SamplerVoice] = []
    private var loadedSamples: [UUID: [Float]] = [:]  // [regionID: samples]
    private let sampleRate: Float

    // Filters and effects
    @Published var filterEnabled: Bool = false
    @Published var filterCutoff: Float = 5000.0  // Hz
    @Published var filterResonance: Float = 1.0

    init(sampleRate: Float = 48000.0) {
        self.sampleRate = sampleRate

        // Create voice pool
        for _ in 0..<64 {
            voices.append(SamplerVoice())
        }
    }

    // MARK: - Region Management

    func addRegion(_ region: SampleRegion) {
        regions.append(region)
        if let url = region.audioFileURL {
            loadSample(for: region.id, from: url)
        }
    }

    func removeRegion(_ regionID: UUID) {
        regions.removeAll { $0.id == regionID }
        loadedSamples.removeValue(forKey: regionID)
    }

    func loadSample(for regionID: UUID, from url: URL) {
        guard let audioFile = try? AVAudioFile(forReading: url) else {
            print("❌ Failed to load audio file: \(url)")
            return
        }

        let format = audioFile.processingFormat
        let frameCount = AVAudioFrameCount(audioFile.length)

        guard let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            print("❌ Failed to create buffer")
            return
        }

        do {
            try audioFile.read(into: buffer)

            // Convert to mono float array
            guard let channelData = buffer.floatChannelData else { return }
            let channelCount = Int(buffer.format.channelCount)
            let frameLength = Int(buffer.frameLength)

            var monoSamples = [Float](repeating: 0.0, count: frameLength)

            if channelCount == 1 {
                // Mono source
                memcpy(&monoSamples, channelData[0], frameLength * MemoryLayout<Float>.stride)
            } else {
                // Stereo/multi-channel - mix to mono
                for i in 0..<frameLength {
                    var sum: Float = 0.0
                    for ch in 0..<channelCount {
                        sum += channelData[ch][i]
                    }
                    monoSamples[i] = sum / Float(channelCount)
                }
            }

            loadedSamples[regionID] = monoSamples
            print("✅ Loaded sample: \(url.lastPathComponent) - \(frameLength) frames")

        } catch {
            print("❌ Error reading audio file: \(error)")
        }
    }

    // MARK: - MIDI Handling

    func noteOn(note: UInt8, velocity: UInt8) {
        // Find matching regions
        let matchingRegions = regions.filter { $0.matches(note: note, velocity: velocity) }

        guard !matchingRegions.isEmpty else {
            print("⚠️ No region matches note \(note) velocity \(velocity)")
            return
        }

        // Trigger voice for each matching region (layering support)
        for region in matchingRegions {
            guard let sampleData = loadedSamples[region.id] else {
                print("⚠️ Sample not loaded for region: \(region.name)")
                continue
            }

            // Find available voice
            if let voice = voices.first(where: { !$0.isActive }) {
                voice.trigger(note: note, velocity: velocity, sampleData: sampleData,
                            region: region, sampleRate: sampleRate)
            } else {
                // Voice stealing - steal oldest voice
                voices[0].trigger(note: note, velocity: velocity, sampleData: sampleData,
                                region: region, sampleRate: sampleRate)
            }
        }
    }

    func noteOff(note: UInt8) {
        for voice in voices where voice.note == note && voice.isActive {
            voice.release()
        }
    }

    func allNotesOff() {
        for voice in voices {
            voice.release()
        }
    }

    // MARK: - Audio Rendering

    func renderAudio(frameCount: Int) -> (left: [Float], right: [Float]) {
        var leftBuffer = [Float](repeating: 0.0, count: frameCount)
        var rightBuffer = [Float](repeating: 0.0, count: frameCount)

        for i in 0..<frameCount {
            var leftSum: Float = 0.0
            var rightSum: Float = 0.0

            // Sum all active voices
            for voice in voices where voice.isActive {
                let (left, right) = voice.renderSample(sampleRate: sampleRate)
                leftSum += left
                rightSum += right
            }

            leftBuffer[i] = leftSum * masterVolume
            rightBuffer[i] = rightSum * masterVolume
        }

        return (leftBuffer, rightBuffer)
    }

    // MARK: - Preset Management

    struct Preset: Codable {
        let name: String
        let regions: [SampleRegion]
        let masterVolume: Float
        let masterTuning: Float
    }

    func savePreset(name: String) -> Preset {
        return Preset(
            name: name,
            regions: regions,
            masterVolume: masterVolume,
            masterTuning: masterTuning
        )
    }

    func loadPreset(_ preset: Preset) {
        self.name = preset.name
        self.masterVolume = preset.masterVolume
        self.masterTuning = preset.masterTuning

        // Clear existing regions
        regions.removeAll()
        loadedSamples.removeAll()

        // Load preset regions
        for region in preset.regions {
            addRegion(region)
        }
    }
}

// MARK: - Sampler UI

struct SamplerView: View {
    @ObservedObject var sampler: ProfessionalSampler

    var body: some View {
        VStack(spacing: 16) {
            Text("PROFESSIONAL SAMPLER")
                .font(.title2.bold())
                .foregroundColor(.cyan)

            // Master Controls
            GroupBox("Master") {
                VStack(spacing: 12) {
                    HStack {
                        Text("Volume")
                        Slider(value: $sampler.masterVolume, in: 0...1)
                        Text(String(format: "%.0f%%", sampler.masterVolume * 100))
                            .frame(width: 50)
                    }

                    HStack {
                        Text("Tuning")
                        Slider(value: $sampler.masterTuning, in: -100...100)
                        Text(String(format: "%.0f¢", sampler.masterTuning))
                            .frame(width: 50)
                    }
                }
            }

            // Regions List
            GroupBox("Regions (\(sampler.regions.count))") {
                ScrollView {
                    VStack(spacing: 8) {
                        ForEach(sampler.regions) { region in
                            regionRow(region)
                        }
                    }
                }
                .frame(height: 200)

                Button("Add Region") {
                    sampler.addRegion(SampleRegion(name: "New Region \(sampler.regions.count + 1)"))
                }
                .buttonStyle(.borderedProminent)
            }

            // Voice Status
            HStack {
                Text("Active Voices:")
                Text("\(sampler.polyphony)")
                    .foregroundColor(.green)

                Spacer()

                Button("All Notes Off") {
                    sampler.allNotesOff()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }

    func regionRow(_ region: SampleRegion) -> some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(region.name)
                    .font(.headline)

                Text("Key: \(region.minNote)-\(region.maxNote) | Vel: \(region.minVelocity)-\(region.maxVelocity)")
                    .font(.caption)
                    .foregroundColor(.gray)

                if let url = region.audioFileURL {
                    Text(url.lastPathComponent)
                        .font(.caption2)
                        .foregroundColor(.cyan)
                } else {
                    Text("No sample loaded")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            Button {
                sampler.removeRegion(region.id)
            } label: {
                Image(systemName: "trash")
                    .foregroundColor(.red)
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(white: 0.15))
        )
    }
}

// MARK: - Factory Kits

extension ProfessionalSampler {

    static func create808DrumKit() -> ProfessionalSampler {
        let sampler = ProfessionalSampler()
        sampler.name = "TR-808 Drum Kit"

        // Kick - C1 (36)
        var kick = SampleRegion(name: "808 Kick", rootNote: 36)
        kick.minNote = 36
        kick.maxNote = 36
        sampler.addRegion(kick)

        // Snare - D1 (38)
        var snare = SampleRegion(name: "808 Snare", rootNote: 38)
        snare.minNote = 38
        snare.maxNote = 38
        sampler.addRegion(snare)

        // Closed Hi-Hat - F#1 (42)
        var hihat = SampleRegion(name: "808 Hi-Hat Closed", rootNote: 42)
        hihat.minNote = 42
        hihat.maxNote = 42
        sampler.addRegion(hihat)

        // Open Hi-Hat - A#1 (46)
        var openHat = SampleRegion(name: "808 Hi-Hat Open", rootNote: 46)
        openHat.minNote = 46
        openHat.maxNote = 46
        sampler.addRegion(openHat)

        // Clap - D#1 (39)
        var clap = SampleRegion(name: "808 Clap", rootNote: 39)
        clap.minNote = 39
        clap.maxNote = 39
        sampler.addRegion(clap)

        return sampler
    }

    static func createPianoInstrument() -> ProfessionalSampler {
        let sampler = ProfessionalSampler()
        sampler.name = "Grand Piano"

        // Multi-velocity layers every 12 semitones
        for rootNote: UInt8 in stride(from: 21, through: 108, by: 12) {
            // Soft layer (velocity 0-63)
            var softLayer = SampleRegion(name: "Piano \(rootNote) ppp", rootNote: rootNote)
            softLayer.minNote = max(0, rootNote - 6)
            softLayer.maxNote = min(127, rootNote + 5)
            softLayer.minVelocity = 0
            softLayer.maxVelocity = 63
            sampler.addRegion(softLayer)

            // Loud layer (velocity 64-127)
            var loudLayer = SampleRegion(name: "Piano \(rootNote) fff", rootNote: rootNote)
            loudLayer.minNote = max(0, rootNote - 6)
            loudLayer.maxNote = min(127, rootNote + 5)
            loudLayer.minVelocity = 64
            loudLayer.maxVelocity = 127
            sampler.addRegion(loudLayer)
        }

        return sampler
    }
}

#Preview("Sampler") {
    SamplerView(sampler: ProfessionalSampler.create808DrumKit())
}
