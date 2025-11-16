// MARK: - Scientific Validation Framework
// Evidence-based validation for biofeedback interventions
// Requires peer-reviewed evidence for ALL health claims

import Foundation

/// Scientific validation metadata for therapeutic interventions
/// All health-related features MUST provide statistical evidence
public struct ScientificValidation {
    /// P-value from statistical test (null hypothesis significance)
    /// REQUIRED: p < 0.05 for statistical significance
    /// RECOMMENDED: p < 0.01 for strong evidence
    public let pValue: Double

    /// Effect size (Cohen's d or similar metric)
    /// Small: d = 0.2, Medium: d = 0.5, Large: d = 0.8
    /// REQUIRED: d > 0.2 for minimal clinical relevance
    public let effectSize: Double

    /// 95% Confidence interval for effect estimate
    /// Narrow CI indicates precise estimate, wide CI indicates uncertainty
    public let confidenceInterval: (lower: Double, upper: Double)

    /// Sample size used in validation study
    /// REQUIRED: n ≥ 30 for parametric tests (Central Limit Theorem)
    /// RECOMMENDED: n ≥ 100 for robust effect estimation
    public let sampleSize: Int

    /// Whether study included placebo/control group
    /// REQUIRED for causal inference
    public let hasControlGroup: Bool

    /// Whether study was double-blind (neither participant nor assessor knows allocation)
    /// REQUIRED to eliminate expectation and observer bias
    public let isDoubleBlind: Bool

    /// ClinicalTrials.gov identifier (NCT number)
    /// REQUIRED for prospective clinical trials
    /// Example: "NCT04123456"
    public let clinicalTrialID: String?

    /// Institutional Review Board (IRB) approval number
    /// REQUIRED for human subjects research
    /// Ensures ethical oversight and informed consent
    public let ethicsApproval: String?

    /// PubMed IDs (PMIDs) of peer-reviewed publications
    /// REQUIRED: At least one peer-reviewed publication
    /// Example: ["PMID:28438770", "PMID:30476544"]
    public let peerReviewedEvidence: [String]

    /// Digital Object Identifiers for primary references
    /// Example: ["10.1038/nature20587", "10.1016/j.neuroimage.2015.02.042"]
    public let dois: [String]

    /// Study design classification
    public let studyDesign: StudyDesign

    /// Level of evidence according to Oxford Centre for Evidence-Based Medicine
    /// Level 1: Systematic review of RCTs
    /// Level 2: Individual RCT
    /// Level 3: Non-randomized controlled cohort study
    /// Level 4: Case-series, case-control, historically controlled studies
    /// Level 5: Mechanism-based reasoning
    public let evidenceLevel: EvidenceLevel

    /// Date of last validation update
    /// Evidence must be reviewed regularly (recommended: annually)
    public let lastValidated: Date

    /// Known limitations, confounders, or contraindications
    public let limitations: [String]

    // MARK: - Validation Methods

    /// Check if validation meets minimum scientific standards
    public func meetsMinimumStandards() -> Bool {
        return pValue < 0.05 &&
               effectSize >= 0.2 &&
               sampleSize >= 30 &&
               hasControlGroup &&
               !peerReviewedEvidence.isEmpty
    }

    /// Check if validation meets standards for clinical deployment
    public func meetsClinicalStandards() -> Bool {
        return pValue < 0.01 &&
               effectSize >= 0.5 &&
               sampleSize >= 100 &&
               hasControlGroup &&
               isDoubleBlind &&
               ethicsApproval != nil &&
               peerReviewedEvidence.count >= 2 &&
               evidenceLevel.rawValue <= 2
    }

    /// Check if validation meets FDA/MDR medical device standards
    public func meetsMedicalDeviceStandards() -> Bool {
        return meetsClinicalStandards() &&
               clinicalTrialID != nil &&
               !dois.isEmpty &&
               studyDesign == .randomizedControlledTrial
    }

    /// Generate validation report for regulatory submission
    public func generateReport() -> String {
        var report = "=== SCIENTIFIC VALIDATION REPORT ===\n\n"

        report += "Statistical Significance:\n"
        report += "  P-value: \(String(format: "%.4f", pValue))"
        report += pValue < 0.001 ? " (***)" : (pValue < 0.01 ? " (**)" : (pValue < 0.05 ? " (*)" : " (ns)"))
        report += "\n"

        report += "\nEffect Size:\n"
        report += "  Cohen's d: \(String(format: "%.2f", effectSize))"
        report += effectSize >= 0.8 ? " (Large)" : (effectSize >= 0.5 ? " (Medium)" : (effectSize >= 0.2 ? " (Small)" : " (Negligible)"))
        report += "\n"

        report += "\nConfidence Interval (95%):\n"
        report += "  [\(String(format: "%.2f", confidenceInterval.lower)), \(String(format: "%.2f", confidenceInterval.upper))]\n"

        report += "\nStudy Design:\n"
        report += "  Type: \(studyDesign.rawValue)\n"
        report += "  Sample Size: n = \(sampleSize)\n"
        report += "  Control Group: \(hasControlGroup ? "Yes" : "No")\n"
        report += "  Double-Blind: \(isDoubleBlind ? "Yes" : "No")\n"
        report += "  Evidence Level: \(evidenceLevel.rawValue)\n"

        if let trialID = clinicalTrialID {
            report += "\nClinical Trial:\n"
            report += "  Registration: \(trialID)\n"
        }

        if let ethics = ethicsApproval {
            report += "\nEthics:\n"
            report += "  IRB Approval: \(ethics)\n"
        }

        report += "\nPeer-Reviewed Evidence:\n"
        for pmid in peerReviewedEvidence {
            report += "  • \(pmid)\n"
        }

        if !dois.isEmpty {
            report += "\nDOIs:\n"
            for doi in dois {
                report += "  • https://doi.org/\(doi)\n"
            }
        }

        if !limitations.isEmpty {
            report += "\nLimitations:\n"
            for limitation in limitations {
                report += "  • \(limitation)\n"
            }
        }

        report += "\nValidation Status:\n"
        report += "  Minimum Standards: \(meetsMinimumStandards() ? "✅ PASS" : "❌ FAIL")\n"
        report += "  Clinical Standards: \(meetsClinicalStandards() ? "✅ PASS" : "❌ FAIL")\n"
        report += "  Medical Device Standards: \(meetsMedicalDeviceStandards() ? "✅ PASS" : "❌ FAIL")\n"

        report += "\nLast Validated: \(ISO8601DateFormatter().string(from: lastValidated))\n"

        return report
    }
}

// MARK: - Study Design Classification

public enum StudyDesign: String, CaseIterable {
    case randomizedControlledTrial = "Randomized Controlled Trial (RCT)"
    case systematicReview = "Systematic Review/Meta-Analysis"
    case cohortStudy = "Prospective Cohort Study"
    case caseControlStudy = "Case-Control Study"
    case crossSectionalStudy = "Cross-Sectional Study"
    case caseSeries = "Case Series"
    case mechanisticStudy = "Mechanistic/Physiological Study"
    case animalStudy = "Animal Study (Pre-clinical)"
    case inVitroStudy = "In Vitro Study"
}

// MARK: - Evidence Level Classification

public enum EvidenceLevel: Int, CaseIterable {
    case level1 = 1  // Systematic review of RCTs
    case level2 = 2  // Individual RCT
    case level3 = 3  // Non-randomized controlled cohort
    case level4 = 4  // Case-series, case-control
    case level5 = 5  // Mechanism-based reasoning

    public var description: String {
        switch self {
        case .level1: return "Level 1: Systematic Review of RCTs"
        case .level2: return "Level 2: Individual RCT"
        case .level3: return "Level 3: Non-randomized Controlled Cohort"
        case .level4: return "Level 4: Case-Series/Case-Control"
        case .level5: return "Level 5: Mechanism-Based Reasoning"
        }
    }
}

// MARK: - Validation Error

public enum ValidationError: Error {
    case insufficientEvidence(String)
    case notStatisticallySignificant(pValue: Double)
    case effectSizeTooSmall(effectSize: Double)
    case sampleSizeTooSmall(n: Int)
    case noControlGroup
    case noBlinding
    case noPeerReview
    case noEthicsApproval
    case evidenceLevelTooLow(level: Int)
    case outdatedEvidence(lastValidated: Date)

    public var localizedDescription: String {
        switch self {
        case .insufficientEvidence(let reason):
            return "Insufficient evidence: \(reason)"
        case .notStatisticallySignificant(let p):
            return "Not statistically significant (p = \(String(format: "%.3f", p)) ≥ 0.05)"
        case .effectSizeTooSmall(let d):
            return "Effect size too small (d = \(String(format: "%.2f", d)) < 0.2)"
        case .sampleSizeTooSmall(let n):
            return "Sample size too small (n = \(n) < 30)"
        case .noControlGroup:
            return "No control group (required for causal inference)"
        case .noBlinding:
            return "Not double-blind (risk of bias)"
        case .noPeerReview:
            return "No peer-reviewed publications"
        case .noEthicsApproval:
            return "No ethics approval (IRB required for human subjects)"
        case .evidenceLevelTooLow(let level):
            return "Evidence level too low (Level \(level) > 3)"
        case .outdatedEvidence(let date):
            return "Evidence outdated (last validated: \(date))"
        }
    }
}
