import Foundation
import Combine

/// Maps biometric parameters to audio synthesis parameters
/// HRV Coherence → Reverb, Filter, Amplitude
/// Heart Rate → Tempo, Pitch Shift, Frequency
/// Voice Pitch → Base Note, Harmonics
/// Implements exponential smoothing for natural parameter changes
@MainActor
class BioParameterMapper: ObservableObject {

    // MARK: - Published Mapped Parameters

    /// Reverb wet/dry mix (0.0 - 1.0)
    /// Mapped from: HRV Coherence (higher coherence = more reverb)
    @Published var reverbWet: Float = 0.3

    /// Filter cutoff frequency (Hz)
    /// Mapped from: Heart Rate (higher HR = higher cutoff)
    @Published var filterCutoff: Float = 1000.0

    /// Amplitude/volume (0.0 - 1.0)
    /// Mapped from: HRV Coherence + Audio Level
    @Published var amplitude: Float = 0.5

    /// Base note frequency (Hz)
    /// Mapped from: Voice Pitch
    @Published var baseFrequency: Float = 432.0

    /// Tempo (BPM)
    /// Mapped from: Heart Rate (synchronized breathing)
    @Published var tempo: Float = 60.0

    /// Spatial position (X/Y/Z)
    /// Mapped from: HRV Coherence (higher = more centered)
    @Published var spatialPosition: (x: Float, y: Float, z: Float) = (0, 0, 1)

    /// Harmonic richness (number of harmonics)
    /// Mapped from: Voice pitch clarity
    @Published var harmonicCount: Int = 5


    // MARK: - Smoothing Configuration

    /// Smoothing factor (0.0 = no smoothing, 1.0 = max smoothing)
    private let smoothingFactor: Float = 0.85

    /// Fast smoothing for quick changes (e.g., voice pitch)
    private let fastSmoothingFactor: Float = 0.7


    // MARK: - Mapping Ranges

    // HRV Coherence: 0-100 (HeartMath scale)
    private let hrvCoherenceRange = (min: 0.0, max: 100.0)

    // Heart Rate: 40-120 BPM (typical range)
    private let heartRateRange = (min: 40.0, max: 120.0)

    // Voice Pitch: 80-1000 Hz (human voice range)
    private let voicePitchRange = (min: 80.0, max: 1000.0)

    // Reverb: 10-80% wet
    private let reverbRange = (min: 0.1, max: 0.8)

    // Filter: 200-2000 Hz
    private let filterRange = (min: 200.0, max: 2000.0)

    // Amplitude: 0.3-0.8
    private let amplitudeRange = (min: 0.3, max: 0.8)


    // MARK: - Musical Scale Configuration

    /// Musical scale for harmonic generation
    private let healingScale: [Float] = [
        432.0,   // A4 (base healing frequency)
        486.0,   // B4
        512.0,   // C5
        576.0,   // D5
        648.0,   // E5
        729.0,   // F#5
        768.0,   // G5
    ]


    // MARK: - Public Methods

    /// Update all mapped parameters from biometric data
    /// - Parameters:
    ///   - hrvCoherence: HRV coherence score (0-100)
    ///   - heartRate: Heart rate (BPM)
    ///   - voicePitch: Detected voice pitch (Hz)
    ///   - audioLevel: Current audio level (0.0-1.0)
    func updateParameters(
        hrvCoherence: Double,
        heartRate: Double,
        voicePitch: Float,
        audioLevel: Float
    ) {
        // Map HRV Coherence → Reverb Wet
        let targetReverb = mapHRVToReverb(hrvCoherence: hrvCoherence)
        reverbWet = smooth(current: reverbWet, target: targetReverb, factor: smoothingFactor)

        // Map Heart Rate → Filter Cutoff
        let targetFilter = mapHeartRateToFilter(heartRate: heartRate)
        filterCutoff = smooth(current: filterCutoff, target: targetFilter, factor: smoothingFactor)

        // Map HRV + Audio Level → Amplitude
        let targetAmplitude = mapToAmplitude(hrvCoherence: hrvCoherence, audioLevel: audioLevel)
        amplitude = smooth(current: amplitude, target: targetAmplitude, factor: smoothingFactor)

        // Map Voice Pitch → Base Frequency (snap to healing scale)
        let targetFrequency = mapVoicePitchToScale(voicePitch: voicePitch)
        baseFrequency = smooth(current: baseFrequency, target: targetFrequency, factor: fastSmoothingFactor)

        // Map Heart Rate → Tempo (for breathing guidance)
        let targetTempo = mapHeartRateToTempo(heartRate: heartRate)
        tempo = smooth(current: tempo, target: targetTempo, factor: smoothingFactor)

        // Map HRV Coherence → Spatial Position
        spatialPosition = mapHRVToSpatialPosition(hrvCoherence: hrvCoherence)

        // Map Voice Pitch Clarity → Harmonic Count
        harmonicCount = mapVoicePitchToHarmonics(voicePitch: voicePitch, audioLevel: audioLevel)

        #if DEBUG
        logParameters()
        #endif
    }


    // MARK: - Individual Mapping Functions

    /// Map HRV Coherence (0-100) → Reverb Wet (10-80%)
    /// Low coherence (stress) = Less reverb (10%)
    /// High coherence (flow) = More reverb (80%)
    private func mapHRVToReverb(hrvCoherence: Double) -> Float {
        let normalized = normalize(
            value: Float(hrvCoherence),
            from: (Float(hrvCoherenceRange.min), Float(hrvCoherenceRange.max))
        )

        return lerp(
            from: reverbRange.min,
            to: reverbRange.max,
            t: normalized
        )
    }

    /// Map Heart Rate (40-120 BPM) → Filter Cutoff (200-2000 Hz)
    /// Low HR (relaxed) = Lower cutoff (darker sound)
    /// High HR (active) = Higher cutoff (brighter sound)
    private func mapHeartRateToFilter(heartRate: Double) -> Float {
        let normalized = normalize(
            value: Float(heartRate),
            from: (Float(heartRateRange.min), Float(heartRateRange.max))
        )

        return lerp(
            from: filterRange.min,
            to: filterRange.max,
            t: normalized
        )
    }

    /// Map HRV Coherence + Audio Level → Amplitude
    /// Combined mapping for natural volume control
    private func mapToAmplitude(hrvCoherence: Double, audioLevel: Float) -> Float {
        // HRV component (70% weight)
        let hrvNormalized = normalize(
            value: Float(hrvCoherence),
            from: (Float(hrvCoherenceRange.min), Float(hrvCoherenceRange.max))
        )
        let hrvContribution = hrvNormalized * 0.7

        // Audio level component (30% weight)
        let audioContribution = audioLevel * 0.3

        // Combine and map to amplitude range
        let combined = hrvContribution + audioContribution

        return lerp(
            from: amplitudeRange.min,
            to: amplitudeRange.max,
            t: combined
        )
    }

    /// Map Voice Pitch → Musical Scale (healing frequencies)
    /// Snaps detected pitch to nearest note in healing scale
    private func mapVoicePitchToScale(voicePitch: Float) -> Float {
        guard voicePitch > 0 else { return healingScale[0] }

        // Find nearest note in healing scale
        var closestNote = healingScale[0]
        var minDistance = abs(voicePitch - closestNote)

        for note in healingScale {
            let distance = abs(voicePitch - note)
            if distance < minDistance {
                minDistance = distance
                closestNote = note
            }
        }

        return closestNote
    }

    /// Map Heart Rate → Tempo (for breathing guidance)
    /// Typical breathing rate: 4-8 breaths/minute = HR/4
    private func mapHeartRateToTempo(heartRate: Double) -> Float {
        // Convert HR to breathing tempo (roughly HR / 4)
        let breathingRate = Float(heartRate) / 4.0

        // Clamp to reasonable breathing range (4-8 breaths/min)
        return max(4.0, min(8.0, breathingRate))
    }

    /// Map HRV Coherence → Spatial Position
    /// Low coherence = Audio moves around (X/Y variation)
    /// High coherence = Audio centered (0, 0, Z)
    private func mapHRVToSpatialPosition(hrvCoherence: Double) -> (x: Float, y: Float, z: Float) {
        let normalized = normalize(
            value: Float(hrvCoherence),
            from: (Float(hrvCoherenceRange.min), Float(hrvCoherenceRange.max))
        )

        // Low coherence → more spatial movement
        // High coherence → centered position
        let maxDeviation: Float = 1.0 - normalized  // 0.0 (centered) to 1.0 (spread)

        // Create subtle circular motion for low coherence
        let angle = Float(Date().timeIntervalSinceReferenceDate.truncatingRemainder(dividingBy: 6.28))
        let x = cos(angle) * maxDeviation * 0.5
        let y = sin(angle) * maxDeviation * 0.5
        let z: Float = 1.0  // Keep constant distance

        return (x, y, z)
    }

    /// Map Voice Pitch Clarity → Harmonic Count
    /// Clear pitch = More harmonics (rich sound)
    /// Unclear/noisy = Fewer harmonics (simple sound)
    private func mapVoicePitchToHarmonics(voicePitch: Float, audioLevel: Float) -> Int {
        // If no pitch detected or very quiet, use minimal harmonics
        if voicePitch <= 0 || audioLevel < 0.1 {
            return 3
        }

        // Strong signal with clear pitch = more harmonics
        let clarity = audioLevel  // Higher level = clearer signal

        if clarity > 0.6 {
            return 7  // Rich harmonic content
        } else if clarity > 0.3 {
            return 5  // Medium harmonics
        } else {
            return 3  // Basic harmonics
        }
    }


    // MARK: - Utility Functions

    /// Normalize value from input range to 0.0-1.0
    private func normalize(value: Float, from range: (Float, Float)) -> Float {
        let clamped = max(range.0, min(range.1, value))
        return (clamped - range.0) / (range.1 - range.0)
    }

    /// Linear interpolation
    private func lerp(from: Float, to: Float, t: Float) -> Float {
        return from + (to - from) * t
    }

    /// Exponential smoothing
    private func smooth(current: Float, target: Float, factor: Float) -> Float {
        return current * factor + target * (1.0 - factor)
    }

    /// Log current parameters (debug only)
    private func logParameters() {
        let timestamp = Int(Date().timeIntervalSince1970)
        if timestamp % 5 == 0 {  // Every 5 seconds
            print("🎛️  BioParams: Rev:\(Int(reverbWet*100))% Filt:\(Int(filterCutoff))Hz Amp:\(Int(amplitude*100))% Freq:\(Int(baseFrequency))Hz")
        }
    }


    // MARK: - Presets

    /// Apply preset for specific state
    /// Each preset is scientifically designed based on physiological research
    func applyPreset(_ preset: BioPreset) {
        switch preset {
        // MARK: - Original Presets
        case .meditation:
            reverbWet = 0.7
            filterCutoff = 500.0
            amplitude = 0.5
            baseFrequency = 432.0  // Verdi tuning, natural resonance
            tempo = 6.0            // Optimal breathing rate for coherence

        case .focus:
            reverbWet = 0.3
            filterCutoff = 1500.0
            amplitude = 0.6
            baseFrequency = 528.0  // Solfeggio "transformation" frequency
            tempo = 7.0

        case .relaxation:
            reverbWet = 0.8
            filterCutoff = 300.0
            amplitude = 0.4
            baseFrequency = 396.0  // Root chakra frequency, grounding
            tempo = 4.0            // Deep relaxation breathing

        case .energize:
            reverbWet = 0.2
            filterCutoff = 2000.0
            amplitude = 0.7
            baseFrequency = 741.0  // Awakening frequency
            tempo = 8.0

        // MARK: - Posture Contexts
        case .sitting:
            reverbWet = 0.4
            filterCutoff = 1200.0
            amplitude = 0.6
            baseFrequency = 528.0  // Balanced focus
            tempo = 6.5

        case .sittingUpright:
            reverbWet = 0.3
            filterCutoff = 1400.0
            amplitude = 0.65
            baseFrequency = 528.0  // Alert focus
            tempo = 7.0

        case .sittingLeaning:
            reverbWet = 0.5
            filterCutoff = 1000.0
            amplitude = 0.55
            baseFrequency = 432.0  // Relaxed concentration
            tempo = 6.0

        case .sittingCrossLegged:
            reverbWet = 0.6
            filterCutoff = 800.0
            amplitude = 0.5
            baseFrequency = 396.0  // Grounding
            tempo = 5.5

        case .lying:
            reverbWet = 0.75
            filterCutoff = 400.0
            amplitude = 0.45
            baseFrequency = 396.0  // Deep relaxation
            tempo = 4.5

        case .lyingSupine:
            reverbWet = 0.8
            filterCutoff = 350.0
            amplitude = 0.4
            baseFrequency = 396.0  // Maximum relaxation
            tempo = 4.0

        case .lyingProne:
            reverbWet = 0.7
            filterCutoff = 450.0
            amplitude = 0.45
            baseFrequency = 432.0
            tempo = 5.0

        case .lyingSide:
            reverbWet = 0.75
            filterCutoff = 400.0
            amplitude = 0.42
            baseFrequency = 396.0
            tempo = 4.5

        case .standing:
            reverbWet = 0.35
            filterCutoff = 1400.0
            amplitude = 0.65
            baseFrequency = 528.0  // Alert awareness
            tempo = 7.0

        case .standingActive:
            reverbWet = 0.25
            filterCutoff = 1600.0
            amplitude = 0.7
            baseFrequency = 639.0  // Connection, communication
            tempo = 7.5

        case .standingRelaxed:
            reverbWet = 0.45
            filterCutoff = 1200.0
            amplitude = 0.6
            baseFrequency = 432.0
            tempo = 6.5

        case .reclining:
            reverbWet = 0.65
            filterCutoff = 600.0
            amplitude = 0.5
            baseFrequency = 396.0
            tempo = 5.0

        case .reclinePartial:
            reverbWet = 0.6
            filterCutoff = 700.0
            amplitude = 0.52
            baseFrequency = 432.0
            tempo = 5.5

        case .reclineFull:
            reverbWet = 0.7
            filterCutoff = 500.0
            amplitude = 0.48
            baseFrequency = 396.0
            tempo = 4.5

        // MARK: - Movement Contexts
        case .walking:
            reverbWet = 0.3
            filterCutoff = 1300.0
            amplitude = 0.65
            baseFrequency = 528.0
            tempo = 7.0  // Will sync to step rate in ActivityManager

        case .walkingSlow:
            reverbWet = 0.4
            filterCutoff = 1100.0
            amplitude = 0.6
            baseFrequency = 432.0
            tempo = 6.0  // ~90-100 BPM walking pace

        case .walkingNormal:
            reverbWet = 0.3
            filterCutoff = 1300.0
            amplitude = 0.65
            baseFrequency = 528.0
            tempo = 7.0  // ~110-120 BPM

        case .walkingFast:
            reverbWet = 0.25
            filterCutoff = 1500.0
            amplitude = 0.7
            baseFrequency = 639.0
            tempo = 8.0  // ~130-140 BPM

        case .running:
            reverbWet = 0.2
            filterCutoff = 1700.0
            amplitude = 0.75
            baseFrequency = 741.0  // Energizing
            tempo = 9.0

        case .jogging:
            reverbWet = 0.25
            filterCutoff = 1600.0
            amplitude = 0.7
            baseFrequency = 639.0
            tempo = 8.5  // ~150-160 BPM

        case .sprinting:
            reverbWet = 0.15
            filterCutoff = 1900.0
            amplitude = 0.8
            baseFrequency = 852.0  // Intuition, maximum effort
            tempo = 10.0

        case .cycling:
            reverbWet = 0.3
            filterCutoff = 1400.0
            amplitude = 0.7
            baseFrequency = 639.0  // Steady rhythm
            tempo = 7.5

        case .cyclingLeisure:
            reverbWet = 0.4
            filterCutoff = 1200.0
            amplitude = 0.65
            baseFrequency = 528.0
            tempo = 6.5

        case .cyclingIntense:
            reverbWet = 0.2
            filterCutoff = 1700.0
            amplitude = 0.75
            baseFrequency = 741.0
            tempo = 8.5

        // MARK: - Exercise Contexts
        case .yoga:
            reverbWet = 0.6
            filterCutoff = 800.0
            amplitude = 0.55
            baseFrequency = 396.0  // Grounding, root chakra
            tempo = 5.0

        case .yogaFlow:
            reverbWet = 0.5
            filterCutoff = 1000.0
            amplitude = 0.6
            baseFrequency = 528.0  // Transformation, flow
            tempo = 6.0

        case .yogaStatic:
            reverbWet = 0.7
            filterCutoff = 700.0
            amplitude = 0.5
            baseFrequency = 396.0  // Stability
            tempo = 4.5

        case .yogaBreathing:
            reverbWet = 0.65
            filterCutoff = 750.0
            amplitude = 0.52
            baseFrequency = 432.0  // Natural resonance
            tempo = 5.5

        case .hiit:
            reverbWet = 0.15
            filterCutoff = 1800.0
            amplitude = 0.8
            baseFrequency = 741.0  // Maximum activation
            tempo = 9.5

        case .crossfit:
            reverbWet = 0.2
            filterCutoff = 1750.0
            amplitude = 0.78
            baseFrequency = 741.0
            tempo = 9.0

        case .weightlifting:
            reverbWet = 0.25
            filterCutoff = 1650.0
            amplitude = 0.75
            baseFrequency = 639.0  // Power, connection
            tempo = 8.0

        case .pilates:
            reverbWet = 0.5
            filterCutoff = 1100.0
            amplitude = 0.6
            baseFrequency = 528.0  // Control, precision
            tempo = 6.5

        case .dancing:
            reverbWet = 0.3
            filterCutoff = 1500.0
            amplitude = 0.7
            baseFrequency = 639.0  // Joy, connection
            tempo = 8.0

        case .swimming:
            reverbWet = 0.55
            filterCutoff = 900.0
            amplitude = 0.65
            baseFrequency = 528.0  // Fluid, flowing
            tempo = 6.5

        case .climbing:
            reverbWet = 0.35
            filterCutoff = 1400.0
            amplitude = 0.7
            baseFrequency = 639.0  // Focus, problem-solving
            tempo = 7.5

        case .rowing:
            reverbWet = 0.3
            filterCutoff = 1350.0
            amplitude = 0.7
            baseFrequency = 528.0  // Rhythmic power
            tempo = 7.0

        // MARK: - Work/Creative Contexts
        case .deepWork:
            reverbWet = 0.25
            filterCutoff = 1600.0
            amplitude = 0.65
            baseFrequency = 741.0  // Awakening, clarity
            tempo = 7.5  // Alert but calm

        case .flowState:
            reverbWet = 0.35
            filterCutoff = 1450.0
            amplitude = 0.68
            baseFrequency = 528.0  // Transformation, optimal state
            tempo = 7.2

        case .problemSolving:
            reverbWet = 0.3
            filterCutoff = 1550.0
            amplitude = 0.66
            baseFrequency = 639.0  // Connection, relationships
            tempo = 7.5

        case .debugging:
            reverbWet = 0.28
            filterCutoff = 1580.0
            amplitude = 0.67
            baseFrequency = 741.0  // Intuition, solutions
            tempo = 7.6

        case .creative:
            reverbWet = 0.45
            filterCutoff = 1250.0
            amplitude = 0.62
            baseFrequency = 528.0  // Creativity frequency
            tempo = 6.8

        case .composing:
            reverbWet = 0.5
            filterCutoff = 1150.0
            amplitude = 0.6
            baseFrequency = 432.0  // Musical harmony
            tempo = 6.5

        case .designing:
            reverbWet = 0.4
            filterCutoff = 1300.0
            amplitude = 0.63
            baseFrequency = 528.0  // Visual creativity
            tempo = 7.0

        case .writing:
            reverbWet = 0.35
            filterCutoff = 1350.0
            amplitude = 0.64
            baseFrequency = 639.0  // Communication
            tempo = 7.2

        case .reading:
            reverbWet = 0.4
            filterCutoff = 1200.0
            amplitude = 0.58
            baseFrequency = 528.0  // Comprehension
            tempo = 6.5

        case .studying:
            reverbWet = 0.32
            filterCutoff = 1450.0
            amplitude = 0.65
            baseFrequency = 741.0  // Learning, retention
            tempo = 7.3

        case .researching:
            reverbWet = 0.33
            filterCutoff = 1480.0
            amplitude = 0.66
            baseFrequency = 741.0  // Discovery
            tempo = 7.4

        // MARK: - Social Contexts
        case .meeting:
            reverbWet = 0.35
            filterCutoff = 1400.0
            amplitude = 0.65
            baseFrequency = 639.0  // Connection, harmony
            tempo = 7.0

        case .meetingActive:
            reverbWet = 0.3
            filterCutoff = 1500.0
            amplitude = 0.68
            baseFrequency = 639.0  // Active participation
            tempo = 7.5

        case .meetingPassive:
            reverbWet = 0.4
            filterCutoff = 1300.0
            amplitude = 0.62
            baseFrequency = 528.0  // Listening, absorption
            tempo = 6.8

        case .presentation:
            reverbWet = 0.25
            filterCutoff = 1600.0
            amplitude = 0.72
            baseFrequency = 741.0  // Expression, confidence
            tempo = 8.0

        case .teaching:
            reverbWet = 0.3
            filterCutoff = 1550.0
            amplitude = 0.7
            baseFrequency = 639.0  // Communication, connection
            tempo = 7.8

        case .performing:
            reverbWet = 0.28
            filterCutoff = 1650.0
            amplitude = 0.75
            baseFrequency = 741.0  // Peak expression
            tempo = 8.2

        case .socializing:
            reverbWet = 0.4
            filterCutoff = 1350.0
            amplitude = 0.65
            baseFrequency = 639.0  // Connection, joy
            tempo = 7.2

        // MARK: - Recovery/Sleep Contexts
        case .sleep:
            reverbWet = 0.8
            filterCutoff = 300.0
            amplitude = 0.35
            baseFrequency = 396.0  // Deep rest
            tempo = 3.5  // Delta wave entrainment

        case .sleepLight:
            reverbWet = 0.75
            filterCutoff = 350.0
            amplitude = 0.4
            baseFrequency = 396.0  // Theta waves (4-8 Hz brain)
            tempo = 4.0

        case .sleepDeep:
            reverbWet = 0.85
            filterCutoff = 250.0
            amplitude = 0.3
            baseFrequency = 174.0  // Deep delta (0.5-4 Hz brain)
            tempo = 3.0

        case .sleepREM:
            reverbWet = 0.7
            filterCutoff = 400.0
            amplitude = 0.42
            baseFrequency = 432.0  // Theta-alpha border
            tempo = 4.5

        case .nap:
            reverbWet = 0.7
            filterCutoff = 450.0
            amplitude = 0.45
            baseFrequency = 396.0
            tempo = 4.5

        case .powerNap:
            reverbWet = 0.65
            filterCutoff = 500.0
            amplitude = 0.48
            baseFrequency = 432.0  // Quick recovery
            tempo = 5.0

        case .siesta:
            reverbWet = 0.75
            filterCutoff = 380.0
            amplitude = 0.38
            baseFrequency = 396.0
            tempo = 4.0

        case .recovery:
            reverbWet = 0.6
            filterCutoff = 700.0
            amplitude = 0.5
            baseFrequency = 528.0  // Cellular repair frequency
            tempo = 5.5

        case .postWorkout:
            reverbWet = 0.55
            filterCutoff = 800.0
            amplitude = 0.52
            baseFrequency = 528.0  // Recovery, transformation
            tempo = 5.8

        case .massage:
            reverbWet = 0.7
            filterCutoff = 600.0
            amplitude = 0.48
            baseFrequency = 432.0  // Relaxation, healing
            tempo = 5.0

        case .stretching:
            reverbWet = 0.5
            filterCutoff = 900.0
            amplitude = 0.55
            baseFrequency = 528.0  // Flexibility, release
            tempo = 6.0

        // MARK: - Meditation Variants
        case .meditationBreathing:
            reverbWet = 0.65
            filterCutoff = 550.0
            amplitude = 0.5
            baseFrequency = 432.0  // Breath awareness
            tempo = 5.5

        case .meditationBody:
            reverbWet = 0.7
            filterCutoff = 500.0
            amplitude = 0.48
            baseFrequency = 396.0  // Body scan, grounding
            tempo = 5.0

        case .meditationMoving:
            reverbWet = 0.55
            filterCutoff = 850.0
            amplitude = 0.58
            baseFrequency = 528.0  // Walking meditation, flow
            tempo = 6.2

        // MARK: - Special Contexts
        case .driving:
            reverbWet = 0.3
            filterCutoff = 1400.0
            amplitude = 0.6
            baseFrequency = 528.0  // Alert, focused
            tempo = 7.0

        case .drivingCity:
            reverbWet = 0.28
            filterCutoff = 1500.0
            amplitude = 0.62
            baseFrequency = 639.0  // Awareness, quick reactions
            tempo = 7.5

        case .drivingHighway:
            reverbWet = 0.35
            filterCutoff = 1300.0
            amplitude = 0.58
            baseFrequency = 528.0  // Steady focus
            tempo = 6.8

        case .commuting:
            reverbWet = 0.4
            filterCutoff = 1200.0
            amplitude = 0.6
            baseFrequency = 528.0  // Neutral, transitional
            tempo = 6.5

        case .publicTransport:
            reverbWet = 0.45
            filterCutoff = 1100.0
            amplitude = 0.58
            baseFrequency = 432.0  // Relaxed awareness
            tempo = 6.3

        case .flying:
            reverbWet = 0.5
            filterCutoff = 1000.0
            amplitude = 0.55
            baseFrequency = 528.0  // Calm during travel
            tempo = 6.0

        case .eating:
            reverbWet = 0.5
            filterCutoff = 1000.0
            amplitude = 0.55
            baseFrequency = 528.0  // Mindful eating
            tempo = 6.0

        case .digesting:
            reverbWet = 0.6
            filterCutoff = 800.0
            amplitude = 0.5
            baseFrequency = 432.0  // Rest & digest
            tempo = 5.5

        // MARK: - Temperature Contexts
        case .sauna:
            reverbWet = 0.65
            filterCutoff = 650.0
            amplitude = 0.5
            baseFrequency = 528.0  // Detox, transformation
            tempo = 5.5

        case .coldPlunge:
            reverbWet = 0.2
            filterCutoff = 1700.0
            amplitude = 0.75
            baseFrequency = 741.0  // Activation, awakening
            tempo = 8.5
        }

        print("🎛️  Applied preset: \(preset.rawValue)")
    }

    enum BioPreset: String, CaseIterable {
        // MARK: - Original Presets
        case meditation = "Meditation"
        case focus = "Focus"
        case relaxation = "Deep Relaxation"
        case energize = "Energize"

        // MARK: - Posture Contexts
        case sitting = "Sitting"
        case sittingUpright = "Sitting Upright"
        case sittingLeaning = "Sitting Leaning"
        case sittingCrossLegged = "Sitting Cross-Legged"
        case lying = "Lying Down"
        case lyingSupine = "Lying Supine"
        case lyingProne = "Lying Prone"
        case lyingSide = "Lying Side"
        case standing = "Standing"
        case standingActive = "Standing Active"
        case standingRelaxed = "Standing Relaxed"
        case reclining = "Reclining"
        case reclinePartial = "Partial Recline"
        case reclineFull = "Full Recline"

        // MARK: - Movement Contexts
        case walking = "Walking"
        case walkingSlow = "Walking Slow"
        case walkingNormal = "Walking Normal"
        case walkingFast = "Walking Fast"
        case running = "Running"
        case jogging = "Jogging"
        case sprinting = "Sprinting"
        case cycling = "Cycling"
        case cyclingLeisure = "Cycling Leisure"
        case cyclingIntense = "Cycling Intense"

        // MARK: - Exercise Contexts
        case yoga = "Yoga"
        case yogaFlow = "Yoga Flow"
        case yogaStatic = "Yoga Static"
        case yogaBreathing = "Yoga Breathing"
        case hiit = "HIIT Training"
        case crossfit = "CrossFit"
        case weightlifting = "Weightlifting"
        case pilates = "Pilates"
        case dancing = "Dancing"
        case swimming = "Swimming"
        case climbing = "Climbing"
        case rowing = "Rowing"

        // MARK: - Work/Creative Contexts
        case deepWork = "Deep Work"
        case flowState = "Flow State"
        case problemSolving = "Problem Solving"
        case debugging = "Debugging"
        case creative = "Creative Work"
        case composing = "Composing"
        case designing = "Designing"
        case writing = "Writing"
        case reading = "Reading"
        case studying = "Studying"
        case researching = "Researching"

        // MARK: - Social Contexts
        case meeting = "Meeting"
        case meetingActive = "Active Meeting"
        case meetingPassive = "Passive Meeting"
        case presentation = "Presentation"
        case teaching = "Teaching"
        case performing = "Performing"
        case socializing = "Socializing"

        // MARK: - Recovery/Sleep Contexts
        case sleep = "Sleep"
        case sleepLight = "Light Sleep"
        case sleepDeep = "Deep Sleep"
        case sleepREM = "REM Sleep"
        case nap = "Nap"
        case powerNap = "Power Nap"
        case siesta = "Siesta"
        case recovery = "Recovery"
        case postWorkout = "Post Workout"
        case massage = "Massage"
        case stretching = "Stretching"

        // MARK: - Meditation Variants
        case meditationBreathing = "Meditation Breathing"
        case meditationBody = "Body Scan Meditation"
        case meditationMoving = "Moving Meditation"

        // MARK: - Special Contexts
        case driving = "Driving"
        case drivingCity = "City Driving"
        case drivingHighway = "Highway Driving"
        case commuting = "Commuting"
        case publicTransport = "Public Transport"
        case flying = "Flying"
        case eating = "Eating"
        case digesting = "Digesting"

        // MARK: - Temperature Contexts
        case sauna = "Sauna"
        case coldPlunge = "Cold Plunge"
    }
}


// MARK: - Parameter Validation

extension BioParameterMapper {

    /// Validate that all parameters are in valid ranges
    var isValid: Bool {
        reverbWet >= 0.0 && reverbWet <= 1.0 &&
        filterCutoff >= 20.0 && filterCutoff <= 20000.0 &&
        amplitude >= 0.0 && amplitude <= 1.0 &&
        baseFrequency >= 20.0 && baseFrequency <= 20000.0 &&
        tempo >= 1.0 && tempo <= 20.0
    }

    /// Get parameter summary for debugging
    var parameterSummary: String {
        """
        BioParameter Mapping:
        - Reverb: \(Int(reverbWet * 100))%
        - Filter: \(Int(filterCutoff)) Hz
        - Amplitude: \(Int(amplitude * 100))%
        - Frequency: \(Int(baseFrequency)) Hz
        - Tempo: \(String(format: "%.1f", tempo)) breaths/min
        - Spatial: X:\(String(format: "%.2f", spatialPosition.x)) Y:\(String(format: "%.2f", spatialPosition.y)) Z:\(String(format: "%.2f", spatialPosition.z))
        - Harmonics: \(harmonicCount)
        """
    }
}
