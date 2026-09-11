//  AudioFeatureExtractor.swift
//  Echoel — the pure feature stage between an audio INPUT and the picture (#1248).
//
//  WHY THIS EXISTS. Founder 2026-09-11: *"per microphon zum Beispiel auf Konzerten, im Club
//  oder auf Festivals oder andere Audio Inputs die physikalisch assoziierten visuals zu
//  generieren"*. Measured before this slice: no visual read the input at all. The monitor tap
//  already fills a 2048-sample window and `AudioEngine.updateFeedbackGuard` already runs the
//  FFT on it at ~15 Hz — only the howl detector read the result. This type turns that same
//  window + spectrum into five small numbers a renderer can use, and nothing else.
//
//  WHAT IT PRODUCES, and why each is an AMPLITUDE and not a rate (the 3 Hz flash law lives in
//  `FlashGuard`; a feature that is itself a rate would bypass it):
//    · `level`     0…1 from RMS in dBFS (−60 … −6 dB), the loudness of the room/line
//    · `low/mid/high` the spectrum's share below 200 Hz / 200–2000 Hz / above 2 kHz (sum ≈ 1)
//    · `centroid`  0…1 spectral centroid on a log-frequency axis (dark … bright)
//    · `onset`     0…1 transient strength: half-wave spectral flux against its running mean
//
//  ⚠️ SILENCE IS EXACTLY ZERO. Under `silenceFloorDBFS` every field is the literal 0 — not a
//  small float. `MetalBioView`'s #1244 skip compares the uniform block byte-for-byte and only
//  fires while nothing moves; a feature that trembled at 1e-5 in a quiet room would keep the
//  hottest device drawing sixty full frames a second for nothing.
//
//  WHERE IT RUNS. `@MainActor` context, on a COPY of the tap window, at the guard tick's rate.
//  Never in the tap and never on the render thread — it holds arrays and may allocate once
//  when the FFT size changes. Foundation only, so the arithmetic is testable end-to-end.

import Foundation

/// One frame of input features. `silent` is the all-zero frame.
public struct AudioFeatureFrame: Equatable, Sendable {
    public var level: Float
    public var low: Float
    public var mid: Float
    public var high: Float
    public var centroid: Float
    public var onset: Float
    public var timestamp: Double

    public init(level: Float, low: Float, mid: Float, high: Float,
                centroid: Float, onset: Float, timestamp: Double) {
        self.level = level; self.low = low; self.mid = mid; self.high = high
        self.centroid = centroid; self.onset = onset; self.timestamp = timestamp
    }

    public static func silent(at timestamp: Double) -> AudioFeatureFrame {
        AudioFeatureFrame(level: 0, low: 0, mid: 0, high: 0, centroid: 0, onset: 0, timestamp: timestamp)
    }

    public var isSilent: Bool { level == 0 }
}

/// Stateful (flux history) but pure: same inputs, same outputs.
public struct AudioFeatureExtractor: Sendable {

    /// Below this RMS the frame is the exact-zero `silent` frame.
    public static let silenceFloorDBFS: Float = -60
    /// RMS at which `level` reaches 1.
    public static let fullScaleDBFS: Float = -6
    /// Band edges in Hz.
    public static let lowEdgeHz: Float = 200
    public static let highEdgeHz: Float = 2000
    /// Log-frequency axis for the centroid starts here.
    public static let centroidFloorHz: Float = 20

    private var previousMagnitudes: [Float] = []
    private var fluxMean: Float = 0
    /// EMA coefficient for the flux mean (~1 s at 15 Hz).
    private let fluxMeanAlpha: Float = 0.07

    public init() {}

    /// - Parameters:
    ///   - samples: the time-domain window the spectrum was taken from (for RMS).
    ///   - magnitudes: `EchoelRealFFT.forward` magnitudes — `fftSize / 2` bins, bin k at
    ///     `k * sampleRate / fftSize` Hz.
    ///   - sampleRate: the tap's rate; ≤ 0 yields the silent frame.
    public mutating func analyze(samples: [Float], magnitudes: [Float],
                                 sampleRate: Double, timestamp: Double) -> AudioFeatureFrame {
        guard sampleRate > 0, !samples.isEmpty, !magnitudes.isEmpty else {
            return .silent(at: timestamp)
        }
        // RMS in plain Swift: 2048 multiplies at 15 Hz is nothing, and Foundation-only keeps
        // this testable without Accelerate.
        var sum: Float = 0
        for s in samples where s.isFinite { sum += s * s }
        let rms = sqrt(sum / Float(samples.count))
        guard rms > 0, rms.isFinite else { return .silent(at: timestamp) }
        let dbfs = 20 * log10(rms)
        guard dbfs > Self.silenceFloorDBFS else {
            // Keep the flux history moving toward silence so the first loud frame after a
            // pause reads as an onset, not as a continuation.
            fluxMean *= (1 - fluxMeanAlpha)
            previousMagnitudes = magnitudes
            return .silent(at: timestamp)
        }
        let level = ((dbfs - Self.silenceFloorDBFS) / (Self.fullScaleDBFS - Self.silenceFloorDBFS))
            .clamped(to: 0...1)

        // Bands, centroid and flux in one pass over the bins.
        let binHz = Float(sampleRate) / Float(magnitudes.count * 2)
        var total: Float = 0, low: Float = 0, mid: Float = 0, high: Float = 0
        var weighted: Float = 0
        var flux: Float = 0
        let havePrevious = previousMagnitudes.count == magnitudes.count
        for k in 1..<magnitudes.count {
            let m = magnitudes[k]
            guard m.isFinite, m >= 0 else { continue }
            let hz = Float(k) * binHz
            total += m
            if hz < Self.lowEdgeHz { low += m } else if hz < Self.highEdgeHz { mid += m } else { high += m }
            weighted += m * hz
            if havePrevious {
                let d = m - previousMagnitudes[k]
                if d > 0 { flux += d }
            }
        }
        previousMagnitudes = magnitudes
        guard total > 0 else { return .silent(at: timestamp) }

        let centroidHz = weighted / total
        let nyquist = Float(sampleRate) * 0.5
        let axis = log2(max(nyquist, Self.centroidFloorHz * 2) / Self.centroidFloorHz)
        let centroid = (log2(max(centroidHz, Self.centroidFloorHz) / Self.centroidFloorHz) / axis)
            .clamped(to: 0...1)

        // Onset: flux relative to its running mean. A steady tone has flux ≈ mean → 0; a
        // transient is several times the mean → toward 1. The mean updates AFTER the compare
        // so the first hit of a new phrase is not absorbed by itself.
        var onset: Float = 0
        if havePrevious {
            let reference = fluxMean + 1e-6
            let ratio = flux / reference
            onset = ((ratio - 1.5) / 3).clamped(to: 0...1)
            fluxMean += (flux - fluxMean) * fluxMeanAlpha
        } else {
            fluxMean = flux
        }

        return AudioFeatureFrame(level: level,
                                 low: low / total, mid: mid / total, high: high / total,
                                 centroid: centroid, onset: onset, timestamp: timestamp)
    }
}
