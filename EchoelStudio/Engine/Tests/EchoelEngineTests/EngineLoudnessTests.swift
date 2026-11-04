import EchoelCore
import EchoelDSP
@testable import EchoelKernels
import XCTest

/// The same patch on another engine (audit 2026-11-04): a preset jumped by up to 16 LU when only
/// its engine changed, and the choir presets clipped a six-note chord on the classic, FM, sub and
/// morph engines at +1.6 … +3.7 dBFS. `SynthEngine.loudnessTrim` is the gain inside the voice that
/// evens them out; the song stores nothing new.
final class EngineLoudnessTests: XCTestCase {
    private let rate = 48_000.0
    private let chord: [UInt8] = [48, 60, 64, 67, 71, 74]

    private func address(_ identifier: String) -> Int {
        SynthKernel.parameters.firstIndex { $0.identifier == identifier } ?? -1
    }

    /// Integrated loudness and peak of `chord` held for `seconds` on a kernel set by `values`.
    private func play(_ values: [String: Double], seconds: Double) -> (loudness: Double, peak: Float) {
        let kernel = SynthKernel(sampleRate: rate, maximumFrames: 512)
        for (identifier, value) in values { kernel.setParameter(address(identifier), Float(value)) }
        for pitch in chord { kernel.receive(status: 0x90, pitch, 100) }
        let left = UnsafeMutablePointer<Float>.allocate(capacity: 512)
        let right = UnsafeMutablePointer<Float>.allocate(capacity: 512)
        defer {
            left.deallocate()
            right.deallocate()
        }
        var meter = LoudnessMeter(sampleRate: rate)
        var peak: Float = 0
        for _ in 0..<Int(seconds * rate) / 512 {
            kernel.render(frames: 512, left: left, right: right, gain: 1)
            meter.process(left: left, right: right, count: 512)
            for i in 0..<512 { peak = Swift.max(peak, Swift.abs(left[i])) }
        }
        return (meter.integratedLoudness, peak)
    }

    /// The reference patch: Init with the filter open, at Character 0, 0.5 and 1. A held engine
    /// is measured by its loudness, the mallet — which rings down — by its strike's peak.
    func testTheReferencePatchSoundsAboutAsLoudOnEveryEngine() {
        var loudness: [SynthEngine: Double] = [:]
        var peaks: [SynthEngine: Double] = [:]
        for (index, engine) in SynthEngine.allCases.enumerated() {
            var sumLoudness = 0.0, sumPeak = 0.0
            for character in [0.0, 0.5, 1.0] {
                let result = play(["synth_engine": Double(index), "synth_character": character, "synth_cutoff": 18_000,
                                   "synth_filterAmount": 0, "synth_resonance": 0], seconds: 1)
                sumLoudness += result.loudness
                sumPeak += 20 * log10(Double(Swift.max(result.peak, 1e-9)))
            }
            loudness[engine] = sumLoudness / 3
            peaks[engine] = sumPeak / 3
        }
        // The mallet and the plucked string ring down instead of holding: measured by their peak.
        let ringing: Set<SynthEngine> = [.mallet, .pluck]
        let held = SynthEngine.allCases.filter { !ringing.contains($0) }.compactMap { loudness[$0] }.sorted()
        let middle = held[held.count / 2]
        for engine in SynthEngine.allCases where !ringing.contains(engine) {
            XCTAssertEqual(loudness[engine] ?? 0, middle, accuracy: 3, "\(engine) against the others' \(middle) LUFS")
        }
        let heldPeaks = SynthEngine.allCases.filter { !ringing.contains($0) }.compactMap { peaks[$0] }.sorted()
        for engine in ringing {
            XCTAssertEqual(peaks[engine] ?? 0, heldPeaks[heldPeaks.count / 2], accuracy: 3, "the \(engine)'s strike")
        }
    }

    /// A six-note chord of a choir preset stays under full scale on every engine.
    func testNoChoirPresetClipsAChordOnAnyEngine() {
        for name in ["Choir Ah", "Choir Oo", "Low Chant"] {
            guard let preset = InstrumentPreset.named(name) else { return XCTFail("no preset \(name)") }
            for (index, engine) in SynthEngine.allCases.enumerated() {
                var values: [String: Double] = [:]
                for (key, value) in preset.values { values[key.replacingOccurrences(of: ".", with: "_")] = value }
                values["synth_engine"] = Double(index)
                let peak = play(values, seconds: 1.5).peak
                XCTAssertLessThan(peak, 1, "\(name) on \(engine)")
            }
        }
    }
}
