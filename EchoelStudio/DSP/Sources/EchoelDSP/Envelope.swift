import Foundation

/// An ADSR envelope with exponential segments (the analog RC feel), retriggered from
/// its current level so a new note never clicks. A value type; nothing here allocates.
public struct Envelope: Sendable {
    public enum Stage: Sendable, Equatable { case idle, attack, decay, sustain, release }

    public struct Settings: Equatable, Codable, Sendable {
        /// Seconds. Each is held at least 1 ms so a segment is never a click.
        public var attack: Float
        public var decay: Float
        /// Level 0…1.
        public var sustain: Float
        public var release: Float

        public init(attack: Float = 0.005, decay: Float = 0.2, sustain: Float = 0.7, release: Float = 0.3) {
            self.attack = attack
            self.decay = decay
            self.sustain = sustain
            self.release = release
        }
    }

    public private(set) var stage: Stage = .idle
    public private(set) var level: Float = 0
    private var settings: Settings
    private var sampleRate: Float

    // Per-sample coefficients for the current segment.
    private var coefficient: Float = 0
    private var target: Float = 0
    /// The level the current attack or release began at. A settings change re-times the segment
    /// from here, so an unchanged setting keeps the same curve and a changed one takes effect
    /// without restarting the segment.
    private var segmentStart: Float = 0

    /// The overshoot target of the attack, so the exponential curve reaches 1 in time.
    private static let attackTarget: Float = 1.3
    /// A segment counts as done this close to its goal.
    private static let epsilon: Float = 1e-4
    /// How fast a held note follows a changed sustain level, in seconds: a turned knob or an
    /// automation step glides there instead of stepping in one sample (audit 2026-10-23).
    static let sustainGlide: Float = 0.005
    private var sustainPole: Float = 0

    public init(settings: Settings = Settings(), sampleRate: Float = 48_000) {
        self.settings = settings
        self.sampleRate = sampleRate > 0 && sampleRate.isFinite ? sampleRate : 48_000
        sustainPole = Self.pole(self.sampleRate)
    }

    private static func pole(_ sampleRate: Float) -> Float { expf(-1 / (sustainGlide * sampleRate)) }

    public var isActive: Bool { stage != .idle }

    /// New times and sustain for the running note. Called whenever a patch is applied — every
    /// 32 frames while a parameter is automated — so it must not restart the segment: re-entering
    /// it from the current level would stretch the remaining distance over the whole time again,
    /// and the envelope would never reach its goal.
    public mutating func update(_ settings: Settings) {
        guard settings != self.settings else { return }
        self.settings = settings
        retime()
    }

    public mutating func setSampleRate(_ rate: Float) {
        let rate = rate > 0 && rate.isFinite ? rate : 48_000
        guard rate != sampleRate else { return }
        sampleRate = rate
        sustainPole = Self.pole(rate)
        retime()
    }

    private mutating func retime() {
        switch stage {
        case .attack, .decay, .release: setCurve(for: stage)
        case .sustain: target = Self.sustainLevel(settings)
        case .idle: break
        }
    }

    public mutating func gateOn() { enter(.attack) }

    public mutating func gateOff() {
        guard stage != .idle else { return }
        enter(.release)
    }

    /// Silence now — for voice stealing after a short fade has run elsewhere.
    public mutating func kill() {
        stage = .idle
        level = 0
    }

    @inline(__always)
    public mutating func next() -> Float {
        switch stage {
        case .idle:
            return 0
        case .sustain:
            level = target + (level - target) * sustainPole
        case .attack:
            level = target + (level - target) * coefficient
            if level >= 1 {
                level = 1
                enter(.decay)
            }
        case .decay:
            level = target + (level - target) * coefficient
            if level - target <= Self.epsilon {
                level = target
                stage = .sustain
            }
        case .release:
            level = target + (level - target) * coefficient
            if level <= Self.epsilon {
                level = 0
                stage = .idle
            }
        }
        if !level.isFinite { kill() }
        return level
    }

    private mutating func enter(_ next: Stage) {
        stage = next
        segmentStart = level
        setCurve(for: next)
    }

    private mutating func setCurve(for stage: Stage) {
        switch stage {
        case .attack:
            target = Self.attackTarget
            coefficient = coefficientFor(seconds: settings.attack, from: segmentStart, to: 1, aimingAt: target)
        case .decay:
            target = Self.sustainLevel(settings)
            coefficient = coefficientFor(seconds: settings.decay, from: 1, to: target + Self.epsilon, aimingAt: target)
        case .release:
            target = 0
            coefficient = coefficientFor(seconds: settings.release, from: Swift.max(segmentStart, Self.epsilon * 2),
                                         to: Self.epsilon, aimingAt: 0)
        case .sustain:
            target = Self.sustainLevel(settings)
        case .idle:
            level = 0
        }
    }

    /// The per-sample multiplier that takes the distance to `aim` from `start` down to
    /// `end` in `seconds`.
    private func coefficientFor(seconds: Float, from start: Float, to end: Float, aimingAt aim: Float) -> Float {
        let duration = (seconds.isFinite ? Swift.max(seconds, 0.001) : 0.001) * sampleRate
        let startDistance = Swift.abs(start - aim)
        let endDistance = Swift.abs(end - aim)
        guard startDistance > endDistance, endDistance > 0 else { return 0 }
        return expf(logf(endDistance / startDistance) / duration)
    }

    private static func sustainLevel(_ s: Settings) -> Float {
        s.sustain.isFinite ? Swift.min(Swift.max(s.sustain, 0), 1) : 0.7
    }
}
