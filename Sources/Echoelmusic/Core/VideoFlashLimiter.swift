// VideoFlashLimiter.swift
// Echoel — GMMW VV-4 (founder 2026-10-08, "own footage inside own engine"): the law gate that comes
// BEFORE any door shows a person's own video in the visuals. `FlashGuard` budgets the GENERATED
// looks — each one's flash rate is derived from its shader — but footage is not ours: a clip can
// hold a strobe, a lightning storm or a club light at 10 Hz, and no budget written in advance can
// cover it. The seed reader samples at most four frames a second, so it cannot certify a strobe
// either. This type watches the frames that are actually SHOWN and caps the layer's gain.
//
// ⭐ WHAT IT GUARANTEES, and the arithmetic behind it (WCAG 2.3.1, the numbers are `FlashGuard`'s):
// · A TRANSITION is a region's luminance moving `transitionThreshold` against its last extreme
//   (hysteresis, so a slow fade is one transition, not many). Two opposing transitions are a flash.
// · When any one region holds `engageTransitions` (5) transitions inside one second, the gain drops
//   to `engagedGain` (0.05) on that frame. While engaged, no pixel the layer adds can move by 0.05,
//   which is half the WCAG step — so nothing it shows can be a flash at all.
// · Before it engages at most four full transitions have passed, and the gain drop is ONE edge:
//   five transitions, two and a half flashes, in any second. Under the three WCAG allows.
// · It climbs back only after `holdSeconds` with no region over the count, at `releasePerSecond`,
//   stepped through `FlashGuard.maxDelta` so a stall cannot turn the climb into one jump. A source
//   that goes on strobing never releases it; one at two flashes a second never engages it.
//
// ⚠️ WHAT IT IS NOT, so nobody reads more into it:
// · It caps the LAYER, not the screen. The generated field under it has its own budget
//   (`FlashGuard.fieldBudgets`); the sum of the two is a device probe, not a claim here.
// · Its regions are the caller's (`VideoLayerMath.regionMeans`, a 4 × 4 block grid). A counted flash
//   is assumed to cover at least a quarter of one region (`regionCoverage`), which is why the
//   threshold is a quarter of the WCAG step. A flash smaller than that is under the threshold.
// · It ignores WCAG's dark-state exemption (two states both above 0.80 are not a flash): counting
//   them too is the safe direction, and a cap on a bright shimmer costs little.
// · `time` is the DISPLAY clock, monotonic. A media timestamp runs backwards on a seek or a loop;
//   such frames are ignored for counting, and the gain is not reset — a reset would let a person
//   who scrubs a strobing clip get four full transitions through on every scrub.
//
// Pure value type, Foundation only. One instance per playing layer; not on the audio thread.
// Guard: `UserFootageCannotStrobeTests`.

import Foundation

/// Caps the gain of a footage layer so what it adds cannot flash faster than WCAG allows.
public struct VideoFlashLimiter: Sendable {

    /// The share of one region a counted flash is assumed to cover (see the header).
    public static let regionCoverage = 0.25
    /// A region's move against its last extreme that counts as a transition: the WCAG step over
    /// the share of the region a counted flash covers.
    public static let transitionThreshold = FlashGuard.luminanceDeltaThreshold * regionCoverage
    /// Transitions inside one window, in any one region, that engage the cap. One fewer than the
    /// two-per-flash a WCAG-limit second holds, so the edge the cap itself makes still fits.
    public static let engageTransitions = Int(2 * FlashGuard.maxFlashHz) - 1
    /// The window transitions are counted in, in seconds.
    public static let windowSeconds = 1.0
    /// The gain while engaged: half the WCAG step, so no pixel the layer adds can move by a step.
    public static let engagedGain = FlashGuard.luminanceDeltaThreshold / 2
    /// Quiet time before the gain climbs back, in seconds.
    public static let holdSeconds = 1.0
    /// How fast the gain climbs back, per second (0.05 → 1 in about four seconds).
    public static let releasePerSecond = 0.25

    /// The gain to apply to the layer now, `engagedGain`…1.
    public private(set) var gain: Double = 1

    private var regionCount = 0
    /// Per region: the extreme since the last transition (nil before the first frame) and the
    /// direction of the last transition (+1 up, −1 down, 0 none yet).
    private var extremes: [Double?] = []
    private var directions: [Int] = []
    /// Per region, the times of its last `engageTransitions` transitions (a ring).
    private var transitionTimes: [[Double]] = []
    private var ringNext: [Int] = []
    private var lastTime = -Double.infinity
    private var quietSince: Double?

    public init() {}

    /// Feeds one shown frame — `regions` are its region luminances, 0…1 — and returns the gain.
    /// A frame with a non-finite or non-increasing `time`, or no regions, changes nothing.
    @discardableResult
    public mutating func step(time: Double, regions: [Double]) -> Double {
        guard time.isFinite, time > lastTime, !regions.isEmpty else { return gain }
        let dt: Double = lastTime.isFinite ? time - lastTime : 0
        lastTime = time
        if regions.count != regionCount { restartCounting(regions: regions.count) }

        let windowStart = time - Self.windowSeconds
        var busiest = 0
        for region in 0..<regionCount {
            let value = regions[region]
            guard value.isFinite else { continue }
            if registersTransition(region: region, luminance: Swift.min(1, Swift.max(0, value))) {
                transitionTimes[region][ringNext[region]] = time
                ringNext[region] = (ringNext[region] + 1) % Self.engageTransitions
            }
            // Counted in place — this runs on every drawn frame, so no array is built for it.
            let recent: Int = transitionTimes[region].reduce(0) { count, at in at > windowStart ? count + 1 : count }
            busiest = Swift.max(busiest, recent)
        }

        if busiest >= Self.engageTransitions {
            gain = Self.engagedGain
            quietSince = nil
        } else {
            let since = quietSince ?? time
            quietSince = since
            if time - since >= Self.holdSeconds, gain < 1 {
                gain = Swift.min(1, gain + FlashGuard.maxDelta(perSecond: Self.releasePerSecond, dt: dt))
            }
        }
        return gain
    }

    /// A new region layout starts the counting afresh. The gain is kept (see the header).
    private mutating func restartCounting(regions: Int) {
        regionCount = regions
        extremes = Array(repeating: nil, count: regions)
        directions = Array(repeating: 0, count: regions)
        transitionTimes = Array(repeating: Array(repeating: -Double.infinity, count: Self.engageTransitions),
                                count: regions)
        ringNext = Array(repeating: 0, count: regions)
    }

    /// Whether this frame's luminance completes a transition in `region` (hysteresis against the
    /// extreme since the last one).
    private mutating func registersTransition(region: Int, luminance value: Double) -> Bool {
        guard let extreme = extremes[region] else {
            extremes[region] = value
            return false
        }
        let threshold = Self.transitionThreshold
        switch directions[region] {
        case 1:
            if value > extreme { extremes[region] = value; return false }
            guard value <= extreme - threshold else { return false }
            directions[region] = -1
        case -1:
            if value < extreme { extremes[region] = value; return false }
            guard value >= extreme + threshold else { return false }
            directions[region] = 1
        default:
            if value >= extreme + threshold {
                directions[region] = 1
            } else if value <= extreme - threshold {
                directions[region] = -1
            } else {
                return false
            }
        }
        extremes[region] = value
        return true
    }
}
