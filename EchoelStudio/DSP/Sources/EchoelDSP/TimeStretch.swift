import Foundation

/// WSOLA time-stretch (Verhelst & Roelands 1993), ported from the earlier app's
/// `WSOLAStretcher` (`Sources/Echoelmusic/DSP/EchoelWSOLA.swift`, the core with real callers) into
/// Echoel Studio's DSP for warped regions (AUD-2). Time changes, pitch stays.
///
/// What the port keeps: a fixed synthesis hop of half a Hann frame, per frame a search within
/// ±`tolerance` of the nominal read position for the segment most like the natural continuation
/// of the one before, one search on the mono sum whose offsets serve every channel (the sides stay
/// phase-locked), and the overlap-add normalised by the summed window, so the first and last half
/// frames keep their level. What it adds: the nominal read position comes from a function of the
/// output frame, not from one rate — so a tempo that ramps under a region stretches it as it
/// ramps, and the output ends exactly where the song says. Pure Swift: this package imports only
/// Foundation.
///
/// OFFLINE, never on the render thread: it allocates. The engine stretches a region when the song
/// asks for it, off the audio thread, and the render thread only reads the result.
public struct WSOLAStretcher: Sendable {
    /// Analysis and synthesis frame length (Hann). At least 256, even.
    public let frameSize: Int
    /// The search reaches this many frames either side of the nominal position.
    public let tolerance: Int

    public init(frameSize: Int = 1_024, tolerance: Int = 256) {
        let size = Swift.max(256, frameSize + frameSize % 2)
        self.frameSize = size
        self.tolerance = Swift.min(Swift.max(0, tolerance), size / 2)
    }

    /// `channels` (one or two, of equal length) stretched to `outputCount` frames, where output
    /// frame `t` plays input frame `position(t)` — a mapping that rises with `t`. Every channel is
    /// read at the same offsets. Input shorter than a frame is read straight at the mapped
    /// positions (linear interpolation). Empty input or no output gives empty channels.
    public func stretch(_ channels: [[Float]], outputCount: Int, position: (Int) -> Double) -> [[Float]] {
        guard let first = channels.first, !first.isEmpty, outputCount > 0,
              channels.allSatisfy({ $0.count == first.count }) else {
            return channels.map { _ in [] }
        }
        let count = first.count
        guard count > frameSize, outputCount > frameSize else {
            return channels.map { Self.read($0, outputCount: outputCount, position: position) }
        }
        var mono = first
        if channels.count > 1 {
            let scale = 1 / Float(channels.count)
            for i in 0..<count {
                var sum: Float = 0
                for channel in channels { sum += channel[i] }
                mono[i] = sum * scale
            }
        }
        let offsets = chosenOffsets(mono, outputCount: outputCount, position: position)
        return channels.map { render($0, offsets: offsets, outputCount: outputCount) }
    }

    // MARK: - Search

    private func chosenOffsets(_ signal: [Float], outputCount: Int, position: (Int) -> Double) -> [Int] {
        let n = frameSize, hop = n / 2
        let last = signal.count - n
        let frames = Swift.max(1, (outputCount - n) / hop + 2)
        var offsets: [Int] = []
        offsets.reserveCapacity(frames)
        var chosen = Self.clamp(Int(position(0).rounded()), 0, last)
        offsets.append(chosen)
        signal.withUnsafeBufferPointer { buffer in
            guard let base = buffer.baseAddress else { return }
            for k in 1..<frames {
                let natural = chosen + hop
                let nominal = position(k * hop)
                let center = nominal.isFinite ? Int(nominal.rounded()) : natural
                let lo = Self.clamp(center - tolerance, 0, last)
                let hi = Self.clamp(center + tolerance, 0, last)
                guard natural + hop <= signal.count, lo <= hi else {
                    chosen = Self.clamp(center, 0, last)
                    offsets.append(chosen)
                    continue
                }
                let reference = Self.energy(base + natural, count: hop, stride: 1)
                guard reference > 0 else {
                    chosen = Self.clamp(center, lo, hi)
                    offsets.append(chosen)
                    continue
                }
                // Coarse: every second candidate over every second frame; then the best's neighbours
                // at full resolution.
                var best = lo, score = -Float.infinity
                var d = lo
                while d <= hi {
                    let s = Self.similarity(base + natural, base + d, count: hop, stride: 2)
                    if s > score { score = s; best = d }
                    d += 2
                }
                let refineLo = Swift.max(lo, best - 2), refineHi = Swift.min(hi, best + 2)
                score = -Float.infinity
                for candidate in refineLo...refineHi {
                    let s = Self.similarity(base + natural, base + candidate, count: hop, stride: 1)
                    if s > score { score = s; best = candidate }
                }
                chosen = best
                offsets.append(chosen)
            }
        }
        return offsets
    }

    private static func similarity(_ a: UnsafePointer<Float>, _ b: UnsafePointer<Float>, count: Int, stride: Int) -> Float {
        var dot: Float = 0, energyA: Float = 0, energyB: Float = 0
        var i = 0
        while i < count {
            let x = a[i], y = b[i]
            dot += x * y
            energyA += x * x
            energyB += y * y
            i += stride
        }
        guard energyA > 0, energyB > 0 else { return -1 }
        return dot / (energyA.squareRoot() * energyB.squareRoot())
    }

    private static func energy(_ p: UnsafePointer<Float>, count: Int, stride: Int) -> Float {
        var sum: Float = 0
        var i = 0
        while i < count {
            sum += p[i] * p[i]
            i += stride
        }
        return sum
    }

    // MARK: - Overlap-add

    private func render(_ input: [Float], offsets: [Int], outputCount: Int) -> [Float] {
        let n = frameSize, hop = n / 2
        // The periodic Hann: w[i] + w[i + n/2] == 1, so the steady state adds to exactly one.
        let window = (0..<n).map { (i: Int) -> Float in Float(0.5 - 0.5 * cos(2 * Double.pi * Double(i) / Double(n))) }
        let total = (offsets.count - 1) * hop + n
        var out = [Float](repeating: 0, count: total)
        var weight = [Float](repeating: 0, count: total)
        for (k, from) in offsets.enumerated() {
            let at = k * hop
            guard from >= 0, from + n <= input.count, at + n <= total else { continue }
            for i in 0..<n {
                out[at + i] += input[from + i] * window[i]
                weight[at + i] += window[i]
            }
        }
        // The head's and the tail's half frames have one window, not two: normalise by what each
        // frame got (floored, so a frame no window reached stays silent).
        let length = Swift.min(outputCount, total)
        var result = [Float](repeating: 0, count: outputCount)
        let lastAt = (offsets.count - 1) * hop
        for i in 0..<length {
            let w = weight[i]
            if w > 1e-3 {
                let value = out[i] / w
                result[i] = value.isFinite ? value : 0
            } else if i < hop, let first = offsets.first, first + i < input.count {
                // Only the first frame reaches here, and its window divided out is the input itself.
                result[i] = input[first + i]
            } else if i >= lastAt, let final = offsets.last, final + i - lastAt < input.count {
                result[i] = input[final + i - lastAt]
            }
        }
        // A tail the frames did not reach holds the input read straight, so the length is exact.
        if length < outputCount, let lastOffset = offsets.last {
            for i in length..<outputCount {
                let read = lastOffset + (i - (offsets.count - 1) * hop)
                result[i] = read >= 0 && read < input.count ? input[read] : 0
            }
        }
        return result
    }

    /// The input read straight at the mapped positions, for input shorter than a frame.
    private static func read(_ input: [Float], outputCount: Int, position: (Int) -> Double) -> [Float] {
        var result = [Float](repeating: 0, count: outputCount)
        guard !input.isEmpty else { return result }
        for t in 0..<outputCount {
            let p = position(t)
            guard p.isFinite, p >= 0 else { continue }
            let index = Int(p)
            guard index < input.count else { break }
            let next = Swift.min(index + 1, input.count - 1)
            let fraction = Float(p - Double(index))
            result[t] = input[index] + (input[next] - input[index]) * fraction
        }
        return result
    }

    private static func clamp(_ value: Int, _ lower: Int, _ upper: Int) -> Int {
        Swift.min(Swift.max(value, lower), Swift.max(lower, upper))
    }
}

extension SampleBuffer {
    /// `length` frames from `offset` stretched to `outputCount` frames at this buffer's rate, where
    /// output frame `t` plays frame `offset + position(t)` — both sides read at the same offsets.
    /// Nil for a stretch outside the buffer or no output. Offline: it allocates.
    public func stretched(offset: Int, length: Int, outputCount: Int,
                          stretcher: WSOLAStretcher = WSOLAStretcher(),
                          position: (Int) -> Double) -> SampleBuffer? {
        guard offset >= 0, length > 0, offset < frameCount, outputCount > 0 else { return nil }
        let count = Swift.min(length, frameCount - offset)
        var sides = [[Float]](repeating: [Float](repeating: 0, count: count), count: channelCount)
        for i in 0..<count {
            for c in 0..<channelCount { sides[c][i] = frames[(offset + i) * channelCount + c] }
        }
        let out = stretcher.stretch(sides, outputCount: outputCount, position: position)
        if out.count == 2 { return SampleBuffer(left: out[0], right: out[1], sampleRate: sampleRate, rootPitch: rootPitch) }
        return out.first.flatMap { SampleBuffer(samples: $0, sampleRate: sampleRate, rootPitch: rootPitch) }
    }
}
