import Foundation
import HealthKit

/// Clinical Evidence-Based Therapies
/// Validated interventions from systematic reviews and meta-analyses
/// Educational implementation - not medical advice, consult healthcare provider
///
/// Key Sources:
/// - Cochrane Database of Systematic Reviews (highest evidence level)
/// - PubMed Central peer-reviewed journals
/// - Clinical practice guidelines from major medical organizations
/// - Evidence levels per Oxford Centre for Evidence-Based Medicine
@MainActor
class ClinicalEvidenceBase: ObservableObject {

    // MARK: - Published State

    @Published var availableInterventions: [ClinicalIntervention] = []
    @Published var selectedIntervention: ClinicalIntervention?

    // MARK: - Clinical Interventions (Evidence-Based)

    struct ClinicalIntervention: Identifiable {
        let id = UUID()
        let name: String
        let indication: String
        let evidenceLevel: EvidenceLevel
        let cochraneReview: String?
        let effectSize: EffectSize
        let safetyProfile: SafetyProfile
        let contraindications: [String]
        let implementation: InterventionProtocol

        enum EvidenceLevel: String {
            case level1a = "Level 1a - Systematic Review of RCTs"
            case level1b = "Level 1b - Individual RCT"
            case level2a = "Level 2a - Systematic Review of Cohort Studies"
            case level2b = "Level 2b - Individual Cohort Study"

            var description: String {
                switch self {
                case .level1a: return "Highest quality evidence - multiple randomized trials"
                case .level1b: return "High quality - single large randomized trial"
                case .level2a: return "Moderate quality - observational studies"
                case .level2b: return "Moderate quality - single cohort study"
                }
            }
        }

        enum EffectSize: String {
            case large = "Large Effect (Cohen's d > 0.8)"
            case medium = "Medium Effect (Cohen's d 0.5-0.8)"
            case small = "Small Effect (Cohen's d 0.2-0.5)"
            case minimal = "Minimal Effect (Cohen's d < 0.2)"

            var cohensD: Float {
                switch self {
                case .large: return 0.9
                case .medium: return 0.6
                case .small: return 0.3
                case .minimal: return 0.1
                }
            }
        }

        enum SafetyProfile: String {
            case veryLow = "Very Low Risk - Minimal adverse effects"
            case low = "Low Risk - Rare mild adverse effects"
            case moderate = "Moderate Risk - Common mild or rare serious adverse effects"
            case high = "High Risk - Medical supervision required"
        }
    }

    // MARK: - Intervention Protocol

    struct InterventionProtocol {
        let durationWeeks: Int
        let frequencyPerWeek: Int
        let sessionDuration: Int  // minutes
        let parameters: [String: Any]
    }

    // MARK: - Initialize Evidence Base

    init() {
        loadEvidenceBasedInterventions()
        print("✅ Clinical Evidence Base: Initialized")
        print("📚 All interventions backed by peer-reviewed research")
    }

    private func loadEvidenceBasedInterventions() {
        availableInterventions = [
            // 1. HRV Biofeedback for Anxiety/Stress
            ClinicalIntervention(
                name: "HRV Biofeedback",
                indication: "Anxiety, Stress, PTSD, Hypertension",
                evidenceLevel: .level1a,
                cochraneReview: "Goessl VC et al. (2017) 'The effect of heart rate variability biofeedback training on stress and anxiety' - Psychological Medicine",
                effectSize: .medium,
                safetyProfile: .veryLow,
                contraindications: ["Cardiac arrhythmia (consult cardiologist)", "Pacemaker (consult physician)"],
                implementation: InterventionProtocol(
                    durationWeeks: 8,
                    frequencyPerWeek: 3,
                    sessionDuration: 20,
                    parameters: ["breathingRate": 6.0, "coherenceThreshold": 0.6]
                )
            ),

            // 2. Slow Breathing for Hypertension
            ClinicalIntervention(
                name: "Device-Guided Slow Breathing",
                indication: "Essential Hypertension",
                evidenceLevel: .level1a,
                cochraneReview: "Mahtani KR et al. (2016) 'Device-guided breathing exercises in the control of human blood pressure' - Cochrane Database Syst Rev",
                effectSize: .small,
                safetyProfile: .veryLow,
                contraindications: [],
                implementation: InterventionProtocol(
                    durationWeeks: 8,
                    frequencyPerWeek: 7,
                    sessionDuration: 15,
                    parameters: ["breathingRate": 6.0, "targetSystolic": 120]
                )
            ),

            // 3. Mindfulness-Based Stress Reduction (MBSR)
            ClinicalIntervention(
                name: "Mindfulness-Based Stress Reduction",
                indication: "Chronic Stress, Depression, Chronic Pain",
                evidenceLevel: .level1a,
                cochraneReview: "Khoury B et al. (2015) 'Mindfulness-based stress reduction for healthy individuals' - Journal of Psychosomatic Research",
                effectSize: .medium,
                safetyProfile: .veryLow,
                contraindications: ["Acute psychosis (consult psychiatrist)"],
                implementation: InterventionProtocol(
                    durationWeeks: 8,
                    frequencyPerWeek: 1,
                    sessionDuration: 120,
                    parameters: ["dailyPractice": 45, "groupSessions": true]
                )
            ),

            // 4. Progressive Muscle Relaxation
            ClinicalIntervention(
                name: "Progressive Muscle Relaxation",
                indication: "Generalized Anxiety, Insomnia, Tension Headache",
                evidenceLevel: .level1a,
                cochraneReview: "McCallie MS et al. (2006) 'A meta-analysis of progressive muscle relaxation in the treatment of anxiety' - Clinical Psychology Review",
                effectSize: .medium,
                safetyProfile: .veryLow,
                contraindications: ["Recent muscle injury", "Severe osteoporosis"],
                implementation: InterventionProtocol(
                    durationWeeks: 4,
                    frequencyPerWeek: 5,
                    sessionDuration: 20,
                    parameters: ["muscleGroups": 16, "tensionDuration": 7]
                )
            ),

            // 5. Aerobic Exercise for Depression
            ClinicalIntervention(
                name: "Aerobic Exercise Training",
                indication: "Major Depression, Mild-Moderate Depression",
                evidenceLevel: .level1a,
                cochraneReview: "Cooney GM et al. (2013) 'Exercise for depression' - Cochrane Database Syst Rev",
                effectSize: .large,
                safetyProfile: .low,
                contraindications: ["Unstable cardiovascular disease", "Uncontrolled hypertension > 180/110"],
                implementation: InterventionProtocol(
                    durationWeeks: 12,
                    frequencyPerWeek: 3,
                    sessionDuration: 45,
                    parameters: ["targetHR": "60-80% max", "modality": "walking/cycling"]
                )
            ),

            // 6. Cognitive Behavioral Therapy (Digital)
            ClinicalIntervention(
                name: "Digital CBT for Insomnia",
                indication: "Chronic Insomnia",
                evidenceLevel: .level1a,
                cochraneReview: "Zachariae R et al. (2016) 'Internet-delivered cognitive-behavioral therapy for insomnia' - Sleep Medicine Reviews",
                effectSize: .large,
                safetyProfile: .veryLow,
                contraindications: [],
                implementation: InterventionProtocol(
                    durationWeeks: 6,
                    frequencyPerWeek: 1,
                    sessionDuration: 30,
                    parameters: ["sleepRestriction": true, "stimulusControl": true]
                )
            ),

            // 7. Light Therapy for Seasonal Affective Disorder
            ClinicalIntervention(
                name: "Bright Light Therapy",
                indication: "Seasonal Affective Disorder (SAD)",
                evidenceLevel: .level1a,
                cochraneReview: "Golden RN et al. (2005) 'The efficacy of light therapy in the treatment of mood disorders' - American Journal of Psychiatry",
                effectSize: .large,
                safetyProfile: .low,
                contraindications: ["Retinal disease", "Photosensitive medications (consult physician)"],
                implementation: InterventionProtocol(
                    durationWeeks: 4,
                    frequencyPerWeek: 7,
                    sessionDuration: 30,
                    parameters: ["intensity": 10000, "wavelength": "white", "timing": "morning"]
                )
            )
        ]
    }

    // MARK: - Search Interventions

    func searchInterventions(for indication: String) -> [ClinicalIntervention] {
        return availableInterventions.filter { intervention in
            intervention.indication.localizedCaseInsensitiveContains(indication)
        }
    }

    func filterByEvidenceLevel(_ level: ClinicalIntervention.EvidenceLevel) -> [ClinicalIntervention] {
        return availableInterventions.filter { $0.evidenceLevel == level }
    }

    // MARK: - Safety Check

    func checkContraindications(for intervention: ClinicalIntervention, userConditions: [String]) -> [String] {
        var warnings: [String] = []

        for condition in userConditions {
            for contraindication in intervention.contraindications {
                if contraindication.localizedCaseInsensitiveContains(condition) {
                    warnings.append("⚠️ Contraindication: \(contraindication)")
                }
            }
        }

        if warnings.isEmpty {
            warnings.append("✅ No known contraindications detected")
        }

        warnings.append("⚠️ Always consult your healthcare provider before starting any intervention")

        return warnings
    }

    // MARK: - Evidence Summary

    func getEvidenceSummary(for intervention: ClinicalIntervention) -> String {
        var summary = """
        📚 EVIDENCE SUMMARY

        Intervention: \(intervention.name)
        Indication: \(intervention.indication)

        Evidence Level: \(intervention.evidenceLevel.rawValue)
        \(intervention.evidenceLevel.description)

        Effect Size: \(intervention.effectSize.rawValue)
        Cohen's d = \(String(format: "%.2f", intervention.effectSize.cohensD))

        Safety: \(intervention.safetyProfile.rawValue)

        Protocol:
        - Duration: \(intervention.implementation.durationWeeks) weeks
        - Frequency: \(intervention.implementation.frequencyPerWeek)x per week
        - Session: \(intervention.implementation.sessionDuration) minutes

        """

        if let cochrane = intervention.cochraneReview {
            summary += "\nCochrane/Systematic Review:\n\(cochrane)\n"
        }

        if !intervention.contraindications.isEmpty {
            summary += "\nContraindications:\n"
            for contraindication in intervention.contraindications {
                summary += "- \(contraindication)\n"
            }
        }

        summary += "\n⚠️ DISCLAIMER: This is educational information only. Always consult qualified healthcare professionals before starting any treatment."

        return summary
    }
}
