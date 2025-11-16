import Foundation
import HealthKit

#if canImport(UIKit)
import UIKit
#endif

/// Extended biometric data beyond basic HRV/HR
/// Supports scientific multi-dimensional bio-audio mapping
/// Ready for EEG, SpO2, Temperature, GSR, EMG, CGM integration
struct ExtendedBioData: Codable {

    // MARK: - Core Metrics (Already Implemented in HealthKitManager)

    /// Heart rate variability (RMSSD in milliseconds)
    var hrv: Double?

    /// Heart rate (beats per minute)
    var heartRate: Double?

    /// HRV coherence score (0-100, HeartMath scale)
    var hrvCoherence: Double?


    // MARK: - Respiratory Metrics

    /// Respiration rate (breaths per minute)
    /// Source: Apple Watch Series 6+, HealthKit
    var respirationRate: Float?

    /// Respiratory sinus arrhythmia (measure of parasympathetic activity)
    var rsaMagnitude: Float?


    // MARK: - Oxygenation Metrics

    /// Blood oxygen saturation (SpO2) percentage (90-100%)
    /// Source: Apple Watch Series 6+, Pulse oximeters
    /// Medical-grade range: 95-100% (normal), <90% (hypoxemia)
    var spo2: Float?

    /// Peripheral perfusion index (0.02-20%)
    /// Measure of blood flow strength at sensor site
    var perfusionIndex: Float?


    // MARK: - Temperature Metrics

    /// Core body temperature (Celsius)
    /// Source: Wearables with skin temp + algorithm
    /// Normal range: 36.5-37.5°C
    var coreTemperature: Float?

    /// Skin temperature (Celsius)
    /// Source: Apple Watch, Oura Ring, Whoop
    var skinTemperature: Float?

    /// Temperature deviation from baseline (°C)
    /// Useful for fever/stress detection
    var temperatureDelta: Float?


    // MARK: - Electrodermal Activity (GSR/EDA)

    /// Galvanic skin response / Electrodermal activity (μS)
    /// Source: EDA sensors, Empatica E4
    /// Measure of sympathetic nervous system activation
    /// Range: 0.01-10 μS (varies by individual)
    var gsr: Float?

    /// Skin conductance level (tonic component)
    var scl: Float?

    /// Skin conductance response (phasic component)
    var scr: Float?


    // MARK: - Blood Pressure

    /// Systolic blood pressure (mmHg)
    /// Normal: <120 mmHg
    var systolicBP: Int?

    /// Diastolic blood pressure (mmHg)
    /// Normal: <80 mmHg
    var diastolicBP: Int?

    /// Mean arterial pressure (calculated)
    var meanArterialPressure: Float? {
        guard let sys = systolicBP, let dia = diastolicBP else { return nil }
        return Float(dia) + (Float(sys - dia) / 3.0)
    }


    // MARK: - Metabolic Metrics

    /// Blood glucose level (mg/dL)
    /// Source: CGM (Dexcom, Freestyle Libre)
    /// Normal fasting: 70-100 mg/dL
    var bloodGlucose: Float?

    /// Ketone level (mmol/L)
    /// Nutritional ketosis: 0.5-3.0 mmol/L
    var ketones: Float?

    /// Lactate level (mmol/L)
    /// Exercise threshold: ~4 mmol/L
    var lactate: Float?


    // MARK: - Electromyography (EMG)

    /// Muscle activity level (arbitrary units)
    /// Source: EMG sensors
    var muscleActivity: Float?

    /// Muscle tension/fatigue index
    var muscleTension: Float?


    // MARK: - Electroencephalography (EEG)

    /// EEG brainwave data
    /// Source: Muse, OpenBCI, NeuroSky
    var eeg: EEGData?


    // MARK: - Sleep Metrics

    /// Current sleep stage
    /// Source: Apple Watch, Oura, Whoop
    var sleepStage: SleepStage?

    /// Sleep debt (hours below optimal)
    var sleepDebt: TimeInterval?

    /// Circadian phase (0-24 hours)
    /// 0 = midnight of biological clock
    var circadianPhase: Float?


    // MARK: - Stress & Recovery

    /// Stress score (0-100)
    /// Derived from HRV, HR, breathing, GSR
    var stressScore: Float?

    /// Recovery score (0-100)
    /// Morning HRV/RHR relative to baseline
    var recoveryScore: Float?

    /// Autonomic balance (sympathetic vs. parasympathetic)
    /// -1.0 (sympathetic dominant) to +1.0 (parasympathetic dominant)
    var autonomicBalance: Float?


    // MARK: - Environmental Context

    /// Ambient temperature (Celsius)
    var ambientTemperature: Float?

    /// Humidity (percentage)
    var humidity: Float?

    /// Barometric pressure (hPa)
    var pressure: Float?

    /// Altitude (meters)
    var altitude: Float?


    // MARK: - Timestamps

    /// When this data was captured
    var timestamp: Date = Date()


    // MARK: - Computed Properties

    /// Overall physiological load (0-100)
    /// Combines HR, HRV, stress, recovery
    var physiologicalLoad: Float {
        var load: Float = 50.0  // Baseline

        // Heart rate contribution
        if let hr = heartRate {
            let hrNormalized = Float((hr - 40.0) / 80.0)  // 40-120 BPM range
            load += hrNormalized * 20.0
        }

        // HRV contribution (inverse - low HRV = high load)
        if let coherence = hrvCoherence {
            load -= Float(coherence) * 0.3
        }

        // Stress contribution
        if let stress = stressScore {
            load += stress * 0.2
        }

        return max(0, min(100, load))
    }

    /// Readiness for activity (0-100)
    /// Higher = better prepared for physical/mental exertion
    var readinessScore: Float {
        var readiness: Float = 50.0

        // Recovery contribution
        if let recovery = recoveryScore {
            readiness += recovery * 0.3
        }

        // HRV coherence contribution
        if let coherence = hrvCoherence {
            readiness += Float(coherence) * 0.2
        }

        // Sleep debt contribution (negative)
        if let debt = sleepDebt, debt > 0 {
            readiness -= Float(debt) * 5.0  // -5 points per hour of debt
        }

        return max(0, min(100, readiness))
    }
}


// MARK: - EEG Data Structure

/// Electroencephalography (EEG) brainwave data
/// Scientific basis: 5 primary frequency bands
struct EEGData: Codable {

    /// Delta waves (0.5-4 Hz) - Deep sleep, unconscious
    /// High delta = deep sleep, healing, regeneration
    var delta: Float?  // μV²

    /// Theta waves (4-8 Hz) - Light sleep, meditation, creativity
    /// High theta = drowsiness, meditation, subconscious access
    var theta: Float?

    /// Alpha waves (8-12 Hz) - Relaxed awareness, calm focus
    /// High alpha = relaxation, closed eyes, meditative state
    var alpha: Float?

    /// Beta waves (12-30 Hz) - Active thinking, concentration
    /// High beta = active cognition, anxiety, focus
    var beta: Float?

    /// Gamma waves (30-100 Hz) - Peak concentration, insight
    /// High gamma = peak performance, cognitive binding
    var gamma: Float?

    /// Overall signal quality (0-100)
    var signalQuality: Float?

    /// Dominant frequency band
    var dominantBand: BrainwaveType? {
        guard let d = delta, let t = theta, let a = alpha, let b = beta, let g = gamma else {
            return nil
        }

        let maxPower = max(d, t, a, b, g)

        if maxPower == d { return .delta }
        if maxPower == t { return .theta }
        if maxPower == a { return .alpha }
        if maxPower == b { return .beta }
        if maxPower == g { return .gamma }

        return nil
    }

    /// Mental state inference from EEG
    var mentalState: MentalState {
        guard let dominant = dominantBand else { return .unknown }

        switch dominant {
        case .delta:
            return .deepSleep
        case .theta:
            return .meditative
        case .alpha:
            return .relaxed
        case .beta:
            return .focused
        case .gamma:
            return .peakPerformance
        }
    }
}


// MARK: - Supporting Enums

/// Brainwave frequency bands
enum BrainwaveType: String, Codable {
    case delta = "Delta"      // 0.5-4 Hz
    case theta = "Theta"      // 4-8 Hz
    case alpha = "Alpha"      // 8-12 Hz
    case beta = "Beta"        // 12-30 Hz
    case gamma = "Gamma"      // 30-100 Hz

    /// Target audio frequency for entrainment
    var targetFrequency: Float {
        switch self {
        case .delta: return 2.0
        case .theta: return 6.0
        case .alpha: return 10.0
        case .beta: return 20.0
        case .gamma: return 40.0
        }
    }
}

/// Inferred mental state from EEG
enum MentalState: String, Codable {
    case unknown = "Unknown"
    case deepSleep = "Deep Sleep"
    case meditative = "Meditative"
    case relaxed = "Relaxed"
    case focused = "Focused"
    case peakPerformance = "Peak Performance"
}

/// Sleep stage classification
enum SleepStage: String, Codable {
    case awake = "Awake"
    case light = "Light Sleep"      // NREM Stage 1-2
    case deep = "Deep Sleep"        // NREM Stage 3 (slow-wave sleep)
    case rem = "REM Sleep"          // Rapid Eye Movement
    case unknown = "Unknown"

    /// Corresponding BioPreset
    func toBioPreset() -> BioParameterMapper.BioPreset {
        switch self {
        case .awake:
            return .focus
        case .light:
            return .sleepLight
        case .deep:
            return .sleepDeep
        case .rem:
            return .sleepREM
        case .unknown:
            return .sleep
        }
    }

    /// Target brainwave for stage
    var targetBrainwave: BrainwaveType {
        switch self {
        case .awake:
            return .alpha
        case .light:
            return .theta
        case .deep:
            return .delta
        case .rem:
            return .theta
        case .unknown:
            return .alpha
        }
    }
}


// MARK: - Integration Helpers

extension ExtendedBioData {

    /// Create from HealthKit samples
    static func from(healthKit: HealthKitBioData) -> ExtendedBioData {
        var data = ExtendedBioData()

        data.hrv = healthKit.hrv
        data.heartRate = healthKit.heartRate
        data.hrvCoherence = healthKit.hrvCoherence
        data.respirationRate = healthKit.respirationRate

        return data
    }

    /// Merge with HealthKit data
    mutating func merge(healthKit: HealthKitBioData) {
        if let hrv = healthKit.hrv { self.hrv = hrv }
        if let hr = healthKit.heartRate { self.heartRate = hr }
        if let coherence = healthKit.hrvCoherence { self.hrvCoherence = coherence }
        if let rr = healthKit.respirationRate { self.respirationRate = rr }
    }

    /// Export for scientific analysis
    func exportForResearch() -> [String: Any] {
        var dict: [String: Any] = [:]

        dict["timestamp"] = timestamp.timeIntervalSince1970

        // Core metrics
        if let hrv = hrv { dict["hrv_rmssd_ms"] = hrv }
        if let hr = heartRate { dict["heart_rate_bpm"] = hr }
        if let coherence = hrvCoherence { dict["hrv_coherence"] = coherence }

        // Respiratory
        if let rr = respirationRate { dict["respiration_rate_bpm"] = rr }
        if let rsa = rsaMagnitude { dict["rsa_magnitude"] = rsa }

        // Oxygenation
        if let spo2 = spo2 { dict["spo2_percent"] = spo2 }
        if let pi = perfusionIndex { dict["perfusion_index"] = pi }

        // Temperature
        if let temp = coreTemperature { dict["core_temp_c"] = temp }
        if let skin = skinTemperature { dict["skin_temp_c"] = skin }

        // EDA
        if let gsr = gsr { dict["gsr_microsiemens"] = gsr }

        // Blood pressure
        if let sys = systolicBP { dict["bp_systolic_mmhg"] = sys }
        if let dia = diastolicBP { dict["bp_diastolic_mmhg"] = dia }

        // Metabolic
        if let glucose = bloodGlucose { dict["glucose_mg_dl"] = glucose }

        // EEG
        if let eeg = eeg {
            dict["eeg_delta"] = eeg.delta
            dict["eeg_theta"] = eeg.theta
            dict["eeg_alpha"] = eeg.alpha
            dict["eeg_beta"] = eeg.beta
            dict["eeg_gamma"] = eeg.gamma
        }

        // Computed
        dict["physiological_load"] = physiologicalLoad
        dict["readiness_score"] = readinessScore

        return dict
    }
}


// MARK: - HealthKit Bridge

/// Bridge structure for HealthKit data
struct HealthKitBioData {
    var hrv: Double?
    var heartRate: Double?
    var hrvCoherence: Double?
    var respirationRate: Float?
}
