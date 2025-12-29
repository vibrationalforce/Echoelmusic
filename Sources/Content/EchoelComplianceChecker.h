#pragma once

/*
 * EchoelComplianceChecker.h
 * Ralph Wiggum Genius Loop Mode - Content Compliance Verification
 *
 * CRITICAL PURPOSE:
 * Helps users avoid making health claims in their content.
 * This is essential for regulatory compliance and ethical marketing.
 *
 * IMPORTANT NOTES:
 * - This tool helps IDENTIFY potential issues
 * - It does NOT guarantee legal compliance
 * - Users should consult legal professionals for final review
 * - Different jurisdictions have different rules
 * - When in doubt, err on the side of caution
 *
 * Checks for:
 * - Health claims (cure, treat, prevent, diagnose)
 * - Medical advice
 * - Unsubstantiated claims
 * - Misleading language
 * - Missing disclaimers
 */

#include <vector>
#include <string>
#include <map>
#include <regex>
#include <algorithm>

namespace Echoel {
namespace Content {

// ============================================================================
// Compliance Issue Types
// ============================================================================

enum class IssueType {
    HealthClaim,            // Claims to treat/cure/prevent disease
    MedicalAdvice,          // Giving medical recommendations
    DiagnosisClaim,         // Claims to diagnose conditions
    UnsubstantiatedClaim,   // Claims without evidence
    AbsoluteLanguage,       // "Always", "Never", "Guaranteed"
    MissingDisclaimer,      // Required disclaimer not present
    MisleadingLanguage,     // Potentially deceptive wording
    TestimonialIssue,       // Testimonial without proper context
    BeforeAfterClaim,       // Before/after without context
    DrugInteraction,        // Mentions drug interactions
    ChildrenMention,        // Health claims involving children
    PregnancyMention,       // Health claims involving pregnancy
    SeriousCondition,       // Mentions serious medical conditions
    RegulatoryTerm          // Uses regulated terms (FDA, etc.)
};

enum class IssueSeverity {
    Critical,       // Must fix before publishing
    Warning,        // Should address
    Suggestion,     // Consider revising
    Info            // Informational only
};

// ============================================================================
// Compliance Issue Structure
// ============================================================================

struct ComplianceIssue {
    IssueType type;
    IssueSeverity severity;
    std::string flaggedText;            // The problematic text
    std::string explanation;            // Why it's an issue
    std::string suggestion;             // How to fix it
    int startPosition = 0;              // Position in text
    int endPosition = 0;
    std::string category;               // For grouping

    static std::string getSeverityName(IssueSeverity sev) {
        switch (sev) {
            case IssueSeverity::Critical: return "CRITICAL";
            case IssueSeverity::Warning: return "WARNING";
            case IssueSeverity::Suggestion: return "SUGGESTION";
            default: return "INFO";
        }
    }

    static std::string getTypeName(IssueType type) {
        switch (type) {
            case IssueType::HealthClaim: return "Health Claim";
            case IssueType::MedicalAdvice: return "Medical Advice";
            case IssueType::DiagnosisClaim: return "Diagnosis Claim";
            case IssueType::UnsubstantiatedClaim: return "Unsubstantiated Claim";
            case IssueType::AbsoluteLanguage: return "Absolute Language";
            case IssueType::MissingDisclaimer: return "Missing Disclaimer";
            case IssueType::MisleadingLanguage: return "Misleading Language";
            case IssueType::TestimonialIssue: return "Testimonial Issue";
            case IssueType::BeforeAfterClaim: return "Before/After Claim";
            case IssueType::DrugInteraction: return "Drug Interaction";
            case IssueType::ChildrenMention: return "Children Health";
            case IssueType::PregnancyMention: return "Pregnancy Health";
            case IssueType::SeriousCondition: return "Serious Condition";
            case IssueType::RegulatoryTerm: return "Regulatory Term";
            default: return "Unknown";
        }
    }
};

// ============================================================================
// Pattern Definitions
// ============================================================================

struct CompliancePattern {
    std::string pattern;                // Regex pattern
    IssueType type;
    IssueSeverity severity;
    std::string explanation;
    std::string suggestion;
};

class PatternDatabase {
public:
    std::vector<CompliancePattern> getHealthClaimPatterns() const {
        return {
            // Cure/Treat/Prevent patterns
            {
                R"(\b(cures?|treat(s|ment)?|heal(s|ing)?)\s+\w+)",
                IssueType::HealthClaim,
                IssueSeverity::Critical,
                "Claims to cure or treat conditions are regulated health claims",
                "Use 'may support' or 'research suggests' instead"
            },
            {
                R"(\b(prevents?|protect(s|ion)?)\s+(against\s+)?\w+(disease|illness|condition))",
                IssueType::HealthClaim,
                IssueSeverity::Critical,
                "Prevention claims are regulated health claims",
                "Describe the research without making prevention claims"
            },
            {
                R"(\b(eliminates?|eradicates?|destroys?)\s+\w+)",
                IssueType::HealthClaim,
                IssueSeverity::Critical,
                "Strong elimination claims are problematic",
                "Use softer language like 'may help with'"
            },
            {
                R"(\b(reduces?|lowers?|decreases?)\s+(risk|chance)\s+of\s+\w+)",
                IssueType::HealthClaim,
                IssueSeverity::Warning,
                "Risk reduction claims need substantial evidence",
                "Cite specific research if making this claim"
            },

            // Diagnosis patterns
            {
                R"(\b(diagnos(e|es|ing)|detect(s|ing)?)\s+\w+)",
                IssueType::DiagnosisClaim,
                IssueSeverity::Critical,
                "Only medical professionals can diagnose conditions",
                "Remove diagnostic language"
            },

            // Medical advice patterns
            {
                R"(\b(take|use|consume)\s+\d+\s*(mg|ml|grams?|doses?)\b)",
                IssueType::MedicalAdvice,
                IssueSeverity::Critical,
                "Specific dosage recommendations constitute medical advice",
                "Refer users to consult healthcare providers"
            },
            {
                R"(\b(stop|discontinue|replace)\s+(your\s+)?(medication|medicine|drugs?|prescription))",
                IssueType::MedicalAdvice,
                IssueSeverity::Critical,
                "Never advise changes to medications",
                "Always recommend consulting healthcare providers"
            },
            {
                R"(\binstead\s+of\s+(medication|medicine|drugs?|prescription))",
                IssueType::MedicalAdvice,
                IssueSeverity::Critical,
                "Suggesting alternatives to medication is medical advice",
                "Present as complementary, not alternative"
            }
        };
    }

    std::vector<CompliancePattern> getAbsoluteLanguagePatterns() const {
        return {
            {
                R"(\b(always|never|100%|guaranteed|proven|definitely)\b)",
                IssueType::AbsoluteLanguage,
                IssueSeverity::Warning,
                "Absolute terms make unsubstantiated guarantees",
                "Use 'may', 'can', 'often', or cite specific studies"
            },
            {
                R"(\b(miracle|breakthrough|revolutionary|amazing results)\b)",
                IssueType::UnsubstantiatedClaim,
                IssueSeverity::Warning,
                "Superlative claims require extraordinary evidence",
                "Use factual, measured language"
            },
            {
                R"(\b(clinically\s+proven|scientifically\s+proven|doctor\s+recommended)\b)",
                IssueType::UnsubstantiatedClaim,
                IssueSeverity::Warning,
                "These phrases require specific verifiable claims",
                "Cite the specific studies or provide context"
            },
            {
                R"(\b(instant(ly)?|immediate(ly)?|overnight)\s+(results?|relief|cure))",
                IssueType::UnsubstantiatedClaim,
                IssueSeverity::Warning,
                "Instant result claims are usually unsubstantiated",
                "Set realistic expectations"
            }
        };
    }

    std::vector<CompliancePattern> getMedicalConditionPatterns() const {
        return {
            // Serious conditions - need extra care
            {
                R"(\b(cancer|tumor|malignant|oncolog)\w*\b)",
                IssueType::SeriousCondition,
                IssueSeverity::Critical,
                "Cancer-related claims are heavily regulated",
                "Do not make any claims related to cancer"
            },
            {
                R"(\b(heart\s+disease|cardiac|cardiovascular|stroke|heart\s+attack)\b)",
                IssueType::SeriousCondition,
                IssueSeverity::Critical,
                "Cardiovascular claims are heavily regulated",
                "Do not make claims about heart conditions"
            },
            {
                R"(\b(diabetes|diabetic|blood\s+sugar|insulin)\b)",
                IssueType::SeriousCondition,
                IssueSeverity::Critical,
                "Diabetes-related claims are heavily regulated",
                "Do not make claims about diabetes"
            },
            {
                R"(\b(depression|anxiety\s+disorder|bipolar|schizophren|mental\s+illness)\b)",
                IssueType::SeriousCondition,
                IssueSeverity::Warning,
                "Mental health condition claims require care",
                "Present as supportive, not treatment"
            },
            {
                R"(\b(alzheimer|dementia|parkinson|epileps)\w*\b)",
                IssueType::SeriousCondition,
                IssueSeverity::Critical,
                "Neurological condition claims are regulated",
                "Do not make claims about these conditions"
            },

            // Vulnerable populations
            {
                R"(\b(children|kids|babies|infants|toddlers)\b.*\b(health|treat|cure|help)\b)",
                IssueType::ChildrenMention,
                IssueSeverity::Critical,
                "Health claims involving children are strictly regulated",
                "Avoid health claims involving children"
            },
            {
                R"(\b(pregnan(t|cy)|expecting|maternal|fetus|unborn)\b)",
                IssueType::PregnancyMention,
                IssueSeverity::Critical,
                "Pregnancy-related health claims are restricted",
                "Recommend consulting healthcare providers"
            }
        };
    }

    std::vector<CompliancePattern> getRegulatoryPatterns() const {
        return {
            {
                R"(\bFDA\s+(approved|cleared|registered)\b)",
                IssueType::RegulatoryTerm,
                IssueSeverity::Critical,
                "FDA approval claims must be accurate and verified",
                "Only claim if product is actually FDA approved"
            },
            {
                R"(\b(drug|medicine|pharmaceutical|prescription)\b)",
                IssueType::RegulatoryTerm,
                IssueSeverity::Warning,
                "Drug-related terminology may imply medical claims",
                "Clarify that product is not a drug"
            }
        };
    }

    std::vector<CompliancePattern> getTestimonialPatterns() const {
        return {
            {
                R"(\b(lost\s+\d+\s*(lbs?|pounds?|kg|kilos?))\b)",
                IssueType::TestimonialIssue,
                IssueSeverity::Warning,
                "Weight loss testimonials need 'results not typical' disclaimer",
                "Add disclaimer: 'Individual results may vary'"
            },
            {
                R"(\b(before\s+and\s+after|transformation)\b)",
                IssueType::BeforeAfterClaim,
                IssueSeverity::Warning,
                "Before/after claims need proper context and disclaimers",
                "Add context about timeframe and individual variation"
            }
        };
    }

    std::vector<CompliancePattern> getAllPatterns() const {
        std::vector<CompliancePattern> all;

        auto add = [&all](const std::vector<CompliancePattern>& patterns) {
            all.insert(all.end(), patterns.begin(), patterns.end());
        };

        add(getHealthClaimPatterns());
        add(getAbsoluteLanguagePatterns());
        add(getMedicalConditionPatterns());
        add(getRegulatoryPatterns());
        add(getTestimonialPatterns());

        return all;
    }
};

// ============================================================================
// Safe Language Alternatives
// ============================================================================

class SafeLanguageGuide {
public:
    struct LanguageAlternative {
        std::string avoid;
        std::string useInstead;
        std::string explanation;
    };

    std::vector<LanguageAlternative> getAlternatives() const {
        return {
            // Health claims → Research-based language
            {
                "Cures anxiety",
                "Research suggests it may support relaxation",
                "Cite specific research and use tentative language"
            },
            {
                "Treats insomnia",
                "Some users report improved sleep quality",
                "Use anecdotal framing with proper context"
            },
            {
                "Prevents stress",
                "May be used as part of a stress management routine",
                "Frame as supportive, not preventive"
            },
            {
                "Heals depression",
                "Research is exploring its potential supportive role",
                "Depression requires professional treatment"
            },

            // Absolute → Measured language
            {
                "Always works",
                "Many users have found it helpful",
                "Acknowledge individual variation"
            },
            {
                "Guaranteed results",
                "Results vary by individual",
                "Never guarantee outcomes"
            },
            {
                "Clinically proven",
                "Supported by research (cite study)",
                "Provide specific citations"
            },
            {
                "100% effective",
                "Has shown positive results in studies",
                "Cite the specific research"
            },

            // Medical advice → Information
            {
                "Take 500mg daily",
                "Consult a healthcare provider for appropriate use",
                "Never give dosage advice"
            },
            {
                "Stop taking your medication",
                "Discuss with your doctor before making changes",
                "Never interfere with medical treatment"
            },
            {
                "Use this instead of [medicine]",
                "May complement your wellness routine",
                "Present as complementary, not alternative"
            },

            // Claims → Educational framing
            {
                "This product will lower your blood pressure",
                "Research on [ingredient] and cardiovascular health",
                "Share research, not claims"
            },
            {
                "Boosts your immune system",
                "Contains ingredients studied for wellness support",
                "Avoid immune claims"
            }
        };
    }

    std::vector<std::string> getSafeVerbs() const {
        return {
            "may support",
            "research suggests",
            "some studies indicate",
            "users have reported",
            "designed to complement",
            "may contribute to",
            "has been studied for",
            "traditionally used for",
            "anecdotally associated with"
        };
    }

    std::vector<std::string> getRequiredDisclaimers() const {
        return {
            // General disclaimer
            "This information is for educational purposes only and is not "
            "intended as medical advice. Consult a healthcare provider "
            "before starting any new wellness practice.",

            // Biofeedback specific
            "Biofeedback and entrainment devices are tools for relaxation "
            "and self-exploration. They are not medical devices and do not "
            "diagnose, treat, cure, or prevent any disease.",

            // Supplement disclaimer (if applicable)
            "These statements have not been evaluated by the Food and Drug "
            "Administration. This product is not intended to diagnose, treat, "
            "cure, or prevent any disease.",

            // Results disclaimer
            "Individual results may vary. The experiences shared are personal "
            "accounts and may not be representative of all users.",

            // Research disclaimer
            "The research cited is for informational purposes only. "
            "Scientific understanding evolves; please verify sources."
        };
    }
};

// ============================================================================
// Main Compliance Checker
// ============================================================================

class EchoelComplianceChecker {
public:
    /*
     * IMPORTANT LIMITATIONS:
     * - This is a helper tool, NOT legal advice
     * - Cannot guarantee regulatory compliance
     * - Different jurisdictions have different rules
     * - Users should consult legal professionals
     * - When in doubt, be more conservative
     */

    struct CheckResult {
        bool passed = true;                     // No critical issues
        int criticalCount = 0;
        int warningCount = 0;
        int suggestionCount = 0;
        std::vector<ComplianceIssue> issues;
        std::vector<std::string> recommendations;
        bool disclaimerPresent = false;
        std::string summary;
    };

    CheckResult checkContent(const std::string& text,
                              bool requireDisclaimer = true) const {
        CheckResult result;

        std::string lowerText = toLower(text);

        // Check all patterns
        for (const auto& pattern : patternDb_.getAllPatterns()) {
            checkPattern(text, lowerText, pattern, result);
        }

        // Check for disclaimer
        result.disclaimerPresent = hasDisclaimer(lowerText);
        if (requireDisclaimer && !result.disclaimerPresent) {
            ComplianceIssue issue;
            issue.type = IssueType::MissingDisclaimer;
            issue.severity = IssueSeverity::Warning;
            issue.explanation = "Content should include an appropriate disclaimer";
            issue.suggestion = "Add a disclaimer stating content is for "
                              "educational purposes only";
            result.issues.push_back(issue);
            result.warningCount++;
        }

        // Count issues by severity
        for (const auto& issue : result.issues) {
            switch (issue.severity) {
                case IssueSeverity::Critical:
                    result.criticalCount++;
                    break;
                case IssueSeverity::Warning:
                    result.warningCount++;
                    break;
                case IssueSeverity::Suggestion:
                    result.suggestionCount++;
                    break;
                default:
                    break;
            }
        }

        result.passed = (result.criticalCount == 0);

        // Generate summary
        if (result.passed && result.warningCount == 0) {
            result.summary = "Content passes compliance check. "
                            "Consider having legal review for final approval.";
        } else if (result.passed) {
            result.summary = "Content has " + std::to_string(result.warningCount) +
                            " warning(s) to review. No critical issues found.";
        } else {
            result.summary = "Content has " + std::to_string(result.criticalCount) +
                            " critical issue(s) that should be addressed before publishing.";
        }

        // Add recommendations
        if (result.criticalCount > 0) {
            result.recommendations.push_back(
                "Address all critical issues before publishing");
        }
        if (!result.disclaimerPresent) {
            result.recommendations.push_back(
                "Add an appropriate disclaimer for your content type");
        }
        result.recommendations.push_back(
            "Consider having a legal professional review before publishing");

        return result;
    }

    // Get safe language alternatives
    std::vector<SafeLanguageGuide::LanguageAlternative> getSafeAlternatives() const {
        return safeLanguage_.getAlternatives();
    }

    std::vector<std::string> getSafeVerbs() const {
        return safeLanguage_.getSafeVerbs();
    }

    std::vector<std::string> getDisclaimerTemplates() const {
        return safeLanguage_.getRequiredDisclaimers();
    }

    // Suggest improved text
    std::string suggestImprovement(const std::string& problematicPhrase) const {
        auto alternatives = safeLanguage_.getAlternatives();

        std::string lower = toLower(problematicPhrase);

        for (const auto& alt : alternatives) {
            if (toLower(alt.avoid).find(lower) != std::string::npos ||
                lower.find(toLower(alt.avoid)) != std::string::npos) {
                return alt.useInstead;
            }
        }

        // Generic suggestion
        return "Consider rephrasing to focus on user experience rather than "
               "health outcomes. Use 'may support' instead of definitive claims.";
    }

    // Generate report
    std::string generateReport(const CheckResult& result) const {
        std::string report = "=== COMPLIANCE CHECK REPORT ===\n\n";

        report += "SUMMARY: " + result.summary + "\n\n";

        report += "STATISTICS:\n";
        report += "- Critical Issues: " + std::to_string(result.criticalCount) + "\n";
        report += "- Warnings: " + std::to_string(result.warningCount) + "\n";
        report += "- Suggestions: " + std::to_string(result.suggestionCount) + "\n";
        report += "- Disclaimer Present: " +
                  std::string(result.disclaimerPresent ? "Yes" : "No") + "\n\n";

        if (!result.issues.empty()) {
            report += "ISSUES FOUND:\n\n";

            for (const auto& issue : result.issues) {
                report += "[" + ComplianceIssue::getSeverityName(issue.severity) + "] ";
                report += ComplianceIssue::getTypeName(issue.type) + "\n";
                if (!issue.flaggedText.empty()) {
                    report += "  Text: \"" + issue.flaggedText + "\"\n";
                }
                report += "  Issue: " + issue.explanation + "\n";
                report += "  Suggestion: " + issue.suggestion + "\n\n";
            }
        }

        report += "RECOMMENDATIONS:\n";
        for (const auto& rec : result.recommendations) {
            report += "• " + rec + "\n";
        }

        report += "\n=== DISCLAIMER ===\n";
        report += "This compliance check is a helper tool only and does not "
                  "constitute legal advice. Different jurisdictions have "
                  "different regulations. Always consult with legal "
                  "professionals for final compliance review.\n";

        return report;
    }

private:
    void checkPattern(const std::string& text,
                      const std::string& lowerText,
                      const CompliancePattern& pattern,
                      CheckResult& result) const {
        try {
            std::regex rx(pattern.pattern, std::regex::icase);
            std::smatch match;
            std::string::const_iterator searchStart(lowerText.cbegin());

            while (std::regex_search(searchStart, lowerText.cend(), match, rx)) {
                ComplianceIssue issue;
                issue.type = pattern.type;
                issue.severity = pattern.severity;
                issue.flaggedText = match.str();
                issue.explanation = pattern.explanation;
                issue.suggestion = pattern.suggestion;
                issue.startPosition = match.position();
                issue.endPosition = issue.startPosition + match.length();

                result.issues.push_back(issue);
                searchStart = match.suffix().first;
            }
        } catch (const std::regex_error&) {
            // Skip invalid patterns
        }
    }

    bool hasDisclaimer(const std::string& lowerText) const {
        // Check for common disclaimer phrases
        std::vector<std::string> disclaimerPhrases = {
            "not intended as medical advice",
            "educational purposes only",
            "consult a healthcare",
            "consult your doctor",
            "not intended to diagnose",
            "individual results may vary",
            "not a substitute for",
            "for informational purposes"
        };

        for (const auto& phrase : disclaimerPhrases) {
            if (lowerText.find(phrase) != std::string::npos) {
                return true;
            }
        }

        return false;
    }

    static std::string toLower(const std::string& s) {
        std::string result = s;
        std::transform(result.begin(), result.end(), result.begin(),
                      [](unsigned char c) { return std::tolower(c); });
        return result;
    }

    PatternDatabase patternDb_;
    SafeLanguageGuide safeLanguage_;
};

} // namespace Content
} // namespace Echoel
