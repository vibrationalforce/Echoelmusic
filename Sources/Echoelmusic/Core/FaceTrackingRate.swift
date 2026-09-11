//
//  FaceTrackingRate.swift
//  Echoelmusic — Core (pure)
//
//  K7b (#1267) — the front-camera TRACKING RATE as a choice (prompt: "Tracking-Rate
//  konfigurierbar (60/30/15 Hz), Standard 30 Hz, wenn 60 nichts hörbar verbessert" and
//  "Kameratextur in reduzierter Auflösung, wenn sie ohnehin verfremdet wird"). ARKit offers a
//  list of video formats (frames per second × resolution); this picks the one for the wanted
//  rate with the FEWEST pixels — the texture is layered and blended, never shown raw, and the
//  body pass down-samples anyway. No Hz is invented: a rate ARKit does not offer is not
//  offered to the performer either (`offered(from:)`), and a wanted rate without a format
//  leaves ARKit's default in place (`pick` returns nil).
//
//  The body analysis keeps its own ~15 passes/s whatever the capture rate: the stride is
//  derived from the capture rate (`stride(forCaptureHz:)`), so 60 → every 4th, 30 → every 2nd.
//

import Foundation

public enum FaceTrackingRate {
    /// The shipped default — 30 Hz: half the thermal cost of 60, and the K3/K4 smoothing
    /// (τ ≥ 80 ms) cannot hear the difference. 60 stays offered where ARKit has it.
    public static let defaultHz = 30
    /// The body pass's target rate (Vision hand + body pose ≈ 15 passes/s is plenty for a
    /// modulation source and stays inside the thermal budget).
    public static let analysisHz = 15

    /// Every N-th delivered frame gets a body pass, so the pass rate stays ~`analysisHz`.
    public static func stride(forCaptureHz hz: Int) -> Int {
        Swift.max(1, hz / analysisHz)
    }

    /// The distinct rates ARKit offers, highest first — what the picker shows. Non-positive
    /// entries are dropped (a defensive read of a foreign list).
    public static func offered(from formatRates: [Int]) -> [Int] {
        Array(Set(formatRates.filter { $0 > 0 })).sorted(by: >)
    }

    /// Index of the format to run: the wanted rate at the fewest pixels. `nil` when no format
    /// has that rate — the caller keeps ARKit's default rather than guessing.
    public static func pick(from formats: [(hz: Int, pixels: Int)], wantHz: Int) -> Int? {
        var best: Int?
        for (i, f) in formats.enumerated() where f.hz == wantHz {
            if let b = best, formats[b].pixels <= f.pixels { continue }
            best = i
        }
        return best
    }
}
