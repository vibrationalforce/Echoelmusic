#pragma once

/*
 * EchoelResearchTool.h
 * Ralph Wiggum Genius Loop Mode - Science & Evidence-Based Research Tool
 *
 * IMPORTANT DISCLAIMER:
 * - This tool helps users FIND and CITE scientific research
 * - It does NOT make health claims or medical recommendations
 * - All content is for EDUCATIONAL and INFORMATIONAL purposes only
 * - Users must verify all sources independently
 * - Not a substitute for professional medical advice
 *
 * User retains 100% ownership of all content they create.
 */

#include <vector>
#include <string>
#include <map>
#include <optional>
#include <chrono>
#include <memory>

namespace Echoel {
namespace Content {

// ============================================================================
// Legal & Compliance Disclaimers
// ============================================================================

namespace Disclaimers {
    const std::string GENERAL_DISCLAIMER =
        "This information is for educational and informational purposes only. "
        "It is not intended as medical advice, diagnosis, or treatment. "
        "Always consult with a qualified healthcare provider before making "
        "any changes to your health regimen.";

    const std::string RESEARCH_DISCLAIMER =
        "The research cited is provided for reference purposes only. "
        "Scientific understanding evolves over time. Users should verify "
        "all sources and consult current literature.";

    const std::string NO_HEALTH_CLAIMS =
        "No health claims are made. The information presented summarizes "
        "published research and does not constitute medical advice.";

    const std::string BIOFEEDBACK_DISCLAIMER =
        "Biofeedback and entrainment technologies are tools for relaxation "
        "and self-exploration. They are not medical devices and do not "
        "diagnose, treat, cure, or prevent any disease.";

    const std::string USER_RESPONSIBILITY =
        "Users are solely responsible for how they use this information. "
        "Individual results may vary.";
}

// ============================================================================
// Research Source Types
// ============================================================================

enum class SourceType {
    PeerReviewedJournal,    // Published in peer-reviewed journal
    Preprint,               // Not yet peer-reviewed
    MetaAnalysis,           // Analysis of multiple studies
    SystematicReview,       // Systematic literature review
    RandomizedControlTrial, // RCT study
    ObservationalStudy,     // Observational research
    CaseStudy,              // Individual case reports
    BookChapter,            // Academic book
    ConferencePaper,        // Conference proceedings
    GovernmentReport,       // Government agency publication
    UniversityPublication,  // University research
    Other
};

enum class EvidenceLevel {
    Level1_MetaAnalysis,        // Highest - Meta-analysis/Systematic reviews
    Level2_RCT,                 // Randomized controlled trials
    Level3_CohortStudy,         // Prospective cohort studies
    Level4_CaseControl,         // Case-control studies
    Level5_CaseSeries,          // Case series/reports
    Level6_ExpertOpinion,       // Expert opinion
    Unrated
};

enum class ResearchTopic {
    Biofeedback,
    Neurofeedback,
    Meditation,
    Relaxation,
    StressManagement,
    BrainwaveEntrainment,
    AudioTherapy,
    Mindfulness,
    BreathingTechniques,
    HeartRateVariability,
    SleepResearch,
    CognitivePerformance,
    MusicAndBrain,
    LightTherapy,
    General
};

// ============================================================================
// Citation Formats
// ============================================================================

enum class CitationStyle {
    APA7,           // American Psychological Association 7th ed.
    MLA9,           // Modern Language Association 9th ed.
    Chicago,        // Chicago Manual of Style
    Harvard,        // Harvard referencing
    Vancouver,      // Vancouver (numbered)
    IEEE,           // IEEE style
    Plain           // Simple readable format
};

// ============================================================================
// Research Source Structure
// ============================================================================

struct Author {
    std::string firstName;
    std::string lastName;
    std::string affiliation;
    std::string orcid;  // ORCID identifier if available

    std::string getFullName() const {
        return firstName + " " + lastName;
    }

    std::string getLastFirst() const {
        return lastName + ", " + firstName;
    }

    std::string getInitials() const {
        std::string initials;
        if (!firstName.empty()) initials += firstName[0];
        return initials + ".";
    }
};

struct ResearchSource {
    // Identification
    std::string id;                     // Internal ID
    std::string doi;                    // Digital Object Identifier
    std::string pmid;                   // PubMed ID
    std::string pmcid;                  // PubMed Central ID
    std::string isbn;                   // For books

    // Bibliographic info
    std::string title;
    std::vector<Author> authors;
    std::string journalName;
    std::string publisher;
    int year = 0;
    std::string volume;
    std::string issue;
    std::string pages;
    std::string url;

    // Classification
    SourceType sourceType = SourceType::Other;
    EvidenceLevel evidenceLevel = EvidenceLevel::Unrated;
    std::vector<ResearchTopic> topics;

    // Content
    std::string abstractText;
    std::vector<std::string> keywords;

    // User notes (user's own interpretation)
    std::string userNotes;
    bool userVerified = false;          // User has verified this source

    // Timestamps
    std::string dateAccessed;
    std::string dateAdded;

    // Generate citation in specified format
    std::string getCitation(CitationStyle style) const;

    // Get URL for source
    std::string getAccessUrl() const {
        if (!doi.empty()) {
            return "https://doi.org/" + doi;
        }
        if (!pmid.empty()) {
            return "https://pubmed.ncbi.nlm.nih.gov/" + pmid;
        }
        return url;
    }
};

// Citation generation implementation
inline std::string ResearchSource::getCitation(CitationStyle style) const {
    std::string citation;

    switch (style) {
        case CitationStyle::APA7: {
            // Author, A. A., & Author, B. B. (Year). Title. Journal, Volume(Issue), pages. DOI
            for (size_t i = 0; i < authors.size(); ++i) {
                if (i > 0) {
                    if (i == authors.size() - 1) citation += ", & ";
                    else citation += ", ";
                }
                citation += authors[i].lastName + ", " + authors[i].getInitials();
            }
            citation += " (" + std::to_string(year) + "). ";
            citation += title + ". ";
            if (!journalName.empty()) {
                citation += journalName;
                if (!volume.empty()) citation += ", " + volume;
                if (!issue.empty()) citation += "(" + issue + ")";
                if (!pages.empty()) citation += ", " + pages;
                citation += ". ";
            }
            if (!doi.empty()) {
                citation += "https://doi.org/" + doi;
            }
            break;
        }

        case CitationStyle::Plain: {
            // Simple readable format
            if (!authors.empty()) {
                citation += authors[0].lastName;
                if (authors.size() > 1) citation += " et al.";
            }
            citation += " (" + std::to_string(year) + "). ";
            citation += "\"" + title + "\" ";
            if (!journalName.empty()) {
                citation += journalName + ".";
            }
            break;
        }

        case CitationStyle::Vancouver: {
            // Numbered style: Author AA, Author BB. Title. Journal. Year;Vol(Issue):pages.
            for (size_t i = 0; i < authors.size() && i < 6; ++i) {
                if (i > 0) citation += ", ";
                citation += authors[i].lastName + " ";
                citation += authors[i].getInitials();
            }
            if (authors.size() > 6) citation += ", et al";
            citation += ". " + title + ". ";
            if (!journalName.empty()) {
                citation += journalName + ". ";
                citation += std::to_string(year);
                if (!volume.empty()) citation += ";" + volume;
                if (!issue.empty()) citation += "(" + issue + ")";
                if (!pages.empty()) citation += ":" + pages;
                citation += ".";
            }
            break;
        }

        default:
            citation = title + " (" + std::to_string(year) + ")";
            break;
    }

    return citation;
}

// ============================================================================
// Research Summary (User-Created, Not Generated)
// ============================================================================

struct ResearchSummary {
    std::string id;
    std::string title;                      // User's title for this summary
    std::string userSummary;                // User's own summary
    std::vector<std::string> sourceIds;     // Referenced sources
    ResearchTopic primaryTopic;
    std::string disclaimer;                 // Required disclaimer

    // Key findings (user-written)
    std::vector<std::string> keyFindings;

    // Limitations noted by user
    std::vector<std::string> limitations;

    // User's notes on practical applications (NOT health claims)
    std::string practicalNotes;

    // Timestamps
    std::string dateCreated;
    std::string dateModified;

    // Ensure disclaimer is always included
    std::string getWithDisclaimer() const {
        return userSummary + "\n\n" + Disclaimers::RESEARCH_DISCLAIMER;
    }
};

// ============================================================================
// Research Database
// ============================================================================

class ResearchDatabase {
public:
    // Add a source
    void addSource(const ResearchSource& source) {
        sources_[source.id] = source;

        // Index by topic
        for (const auto& topic : source.topics) {
            sourcesByTopic_[topic].push_back(source.id);
        }

        // Index by evidence level
        sourcesByEvidence_[source.evidenceLevel].push_back(source.id);
    }

    // Get source by ID
    std::optional<ResearchSource> getSource(const std::string& id) const {
        auto it = sources_.find(id);
        if (it != sources_.end()) {
            return it->second;
        }
        return std::nullopt;
    }

    // Search sources by topic
    std::vector<ResearchSource> getByTopic(ResearchTopic topic) const {
        std::vector<ResearchSource> results;
        auto it = sourcesByTopic_.find(topic);
        if (it != sourcesByTopic_.end()) {
            for (const auto& id : it->second) {
                if (auto source = getSource(id)) {
                    results.push_back(*source);
                }
            }
        }
        return results;
    }

    // Get sources by minimum evidence level
    std::vector<ResearchSource> getByEvidenceLevel(EvidenceLevel minLevel) const {
        std::vector<ResearchSource> results;
        for (int level = static_cast<int>(EvidenceLevel::Level1_MetaAnalysis);
             level <= static_cast<int>(minLevel); ++level) {
            auto it = sourcesByEvidence_.find(static_cast<EvidenceLevel>(level));
            if (it != sourcesByEvidence_.end()) {
                for (const auto& id : it->second) {
                    if (auto source = getSource(id)) {
                        results.push_back(*source);
                    }
                }
            }
        }
        return results;
    }

    // Search by keyword in title/abstract
    std::vector<ResearchSource> search(const std::string& query) const {
        std::vector<ResearchSource> results;
        std::string lowerQuery = toLower(query);

        for (const auto& [id, source] : sources_) {
            if (toLower(source.title).find(lowerQuery) != std::string::npos ||
                toLower(source.abstractText).find(lowerQuery) != std::string::npos) {
                results.push_back(source);
            }
        }
        return results;
    }

    // Get all sources
    std::vector<ResearchSource> getAllSources() const {
        std::vector<ResearchSource> results;
        for (const auto& [id, source] : sources_) {
            results.push_back(source);
        }
        return results;
    }

    size_t getSourceCount() const { return sources_.size(); }

private:
    static std::string toLower(const std::string& s) {
        std::string result = s;
        for (char& c : result) {
            if (c >= 'A' && c <= 'Z') c += 32;
        }
        return result;
    }

    std::map<std::string, ResearchSource> sources_;
    std::map<ResearchTopic, std::vector<std::string>> sourcesByTopic_;
    std::map<EvidenceLevel, std::vector<std::string>> sourcesByEvidence_;
};

// ============================================================================
// Evidence Level Helper
// ============================================================================

class EvidenceLevelHelper {
public:
    static std::string getLevelName(EvidenceLevel level) {
        switch (level) {
            case EvidenceLevel::Level1_MetaAnalysis:
                return "Level I - Meta-Analysis/Systematic Review";
            case EvidenceLevel::Level2_RCT:
                return "Level II - Randomized Controlled Trial";
            case EvidenceLevel::Level3_CohortStudy:
                return "Level III - Cohort Study";
            case EvidenceLevel::Level4_CaseControl:
                return "Level IV - Case-Control Study";
            case EvidenceLevel::Level5_CaseSeries:
                return "Level V - Case Series/Report";
            case EvidenceLevel::Level6_ExpertOpinion:
                return "Level VI - Expert Opinion";
            default:
                return "Unrated";
        }
    }

    static std::string getLevelDescription(EvidenceLevel level) {
        switch (level) {
            case EvidenceLevel::Level1_MetaAnalysis:
                return "Highest level of evidence. Synthesizes multiple high-quality studies.";
            case EvidenceLevel::Level2_RCT:
                return "Strong evidence from well-designed randomized trials.";
            case EvidenceLevel::Level3_CohortStudy:
                return "Good evidence from observational studies following groups over time.";
            case EvidenceLevel::Level4_CaseControl:
                return "Fair evidence comparing cases to controls.";
            case EvidenceLevel::Level5_CaseSeries:
                return "Limited evidence from individual cases or small series.";
            case EvidenceLevel::Level6_ExpertOpinion:
                return "Lowest level - based on expert consensus without empirical data.";
            default:
                return "Evidence level has not been assessed.";
        }
    }

    static std::string getInterpretationGuidance(EvidenceLevel level) {
        switch (level) {
            case EvidenceLevel::Level1_MetaAnalysis:
            case EvidenceLevel::Level2_RCT:
                return "Strong evidence base. Findings are generally reliable but should "
                       "still be interpreted with caution and in context.";
            case EvidenceLevel::Level3_CohortStudy:
            case EvidenceLevel::Level4_CaseControl:
                return "Moderate evidence. Findings suggest associations but cannot "
                       "establish causation. More research may be needed.";
            case EvidenceLevel::Level5_CaseSeries:
            case EvidenceLevel::Level6_ExpertOpinion:
                return "Limited evidence. Findings are preliminary and should be "
                       "interpreted with significant caution.";
            default:
                return "Evaluate the source carefully before drawing conclusions.";
        }
    }
};

// ============================================================================
// Topic Information
// ============================================================================

class TopicHelper {
public:
    static std::string getTopicName(ResearchTopic topic) {
        switch (topic) {
            case ResearchTopic::Biofeedback:
                return "Biofeedback";
            case ResearchTopic::Neurofeedback:
                return "Neurofeedback";
            case ResearchTopic::Meditation:
                return "Meditation Research";
            case ResearchTopic::Relaxation:
                return "Relaxation Techniques";
            case ResearchTopic::StressManagement:
                return "Stress Management";
            case ResearchTopic::BrainwaveEntrainment:
                return "Brainwave Entrainment";
            case ResearchTopic::AudioTherapy:
                return "Audio/Sound Research";
            case ResearchTopic::Mindfulness:
                return "Mindfulness";
            case ResearchTopic::BreathingTechniques:
                return "Breathing Techniques";
            case ResearchTopic::HeartRateVariability:
                return "Heart Rate Variability";
            case ResearchTopic::SleepResearch:
                return "Sleep Research";
            case ResearchTopic::CognitivePerformance:
                return "Cognitive Performance";
            case ResearchTopic::MusicAndBrain:
                return "Music and the Brain";
            case ResearchTopic::LightTherapy:
                return "Light Therapy";
            default:
                return "General Research";
        }
    }

    static std::string getTopicDisclaimer(ResearchTopic topic) {
        std::string base = Disclaimers::NO_HEALTH_CLAIMS + " ";

        switch (topic) {
            case ResearchTopic::Biofeedback:
            case ResearchTopic::Neurofeedback:
                return base + Disclaimers::BIOFEEDBACK_DISCLAIMER;

            case ResearchTopic::BrainwaveEntrainment:
                return base + "Brainwave entrainment is an area of ongoing research. "
                       "Individual responses vary significantly.";

            case ResearchTopic::SleepResearch:
                return base + "Sleep issues may have underlying medical causes. "
                       "Consult a healthcare provider for persistent sleep problems.";

            case ResearchTopic::StressManagement:
                return base + "Chronic stress may require professional support. "
                       "These techniques complement but do not replace professional care.";

            default:
                return base + Disclaimers::USER_RESPONSIBILITY;
        }
    }
};

// ============================================================================
// Main Research Tool
// ============================================================================

class EchoelResearchTool {
public:
    /*
     * IMPORTANT: This is a REFERENCE tool only.
     * - Helps users organize and cite research
     * - Does NOT generate content
     * - Does NOT make health claims
     * - User is responsible for verifying all sources
     * - All content created by user belongs 100% to user
     */

    EchoelResearchTool() {
        // Pre-load common research topics with example sources
        initializeExampleSources();
    }

    // ===== Source Management =====

    void addSource(const ResearchSource& source) {
        database_.addSource(source);
    }

    std::optional<ResearchSource> getSource(const std::string& id) const {
        return database_.getSource(id);
    }

    std::vector<ResearchSource> searchSources(const std::string& query) const {
        return database_.search(query);
    }

    std::vector<ResearchSource> getSourcesByTopic(ResearchTopic topic) const {
        return database_.getByTopic(topic);
    }

    std::vector<ResearchSource> getHighQualitySources(EvidenceLevel minLevel) const {
        return database_.getByEvidenceLevel(minLevel);
    }

    // ===== Citation Generation =====

    std::string generateCitation(const std::string& sourceId,
                                  CitationStyle style = CitationStyle::APA7) const {
        auto source = database_.getSource(sourceId);
        if (source) {
            return source->getCitation(style);
        }
        return "";
    }

    std::string generateBibliography(const std::vector<std::string>& sourceIds,
                                      CitationStyle style = CitationStyle::APA7) const {
        std::string bibliography = "References\n\n";

        int num = 1;
        for (const auto& id : sourceIds) {
            auto source = database_.getSource(id);
            if (source) {
                if (style == CitationStyle::Vancouver) {
                    bibliography += std::to_string(num++) + ". ";
                }
                bibliography += source->getCitation(style) + "\n\n";
            }
        }

        return bibliography;
    }

    // ===== Evidence Assessment =====

    struct EvidenceAssessment {
        std::string topic;
        int totalSources = 0;
        int level1Count = 0;  // Meta-analyses
        int level2Count = 0;  // RCTs
        int level3_4Count = 0; // Observational
        int level5_6Count = 0; // Case/Opinion
        std::string overallAssessment;
        std::string cautionaryNote;
    };

    EvidenceAssessment assessEvidenceBase(ResearchTopic topic) const {
        EvidenceAssessment assessment;
        assessment.topic = TopicHelper::getTopicName(topic);

        auto sources = database_.getByTopic(topic);
        assessment.totalSources = sources.size();

        for (const auto& source : sources) {
            switch (source.evidenceLevel) {
                case EvidenceLevel::Level1_MetaAnalysis:
                    assessment.level1Count++;
                    break;
                case EvidenceLevel::Level2_RCT:
                    assessment.level2Count++;
                    break;
                case EvidenceLevel::Level3_CohortStudy:
                case EvidenceLevel::Level4_CaseControl:
                    assessment.level3_4Count++;
                    break;
                default:
                    assessment.level5_6Count++;
                    break;
            }
        }

        // Generate assessment (informational, not claims)
        if (assessment.level1Count > 0 && assessment.level2Count > 2) {
            assessment.overallAssessment =
                "Multiple high-quality studies available. The research base "
                "includes meta-analyses and randomized trials.";
        } else if (assessment.level2Count > 0) {
            assessment.overallAssessment =
                "Some randomized trials available. Evidence is developing "
                "but more research may strengthen conclusions.";
        } else if (assessment.totalSources > 0) {
            assessment.overallAssessment =
                "Research is primarily observational or preliminary. "
                "Findings should be interpreted with caution.";
        } else {
            assessment.overallAssessment =
                "Limited research available on this specific topic.";
        }

        assessment.cautionaryNote =
            "This assessment summarizes available research and does not "
            "constitute a recommendation. Individual results may vary.";

        return assessment;
    }

    // ===== Disclaimer Generation =====

    std::string getRequiredDisclaimer(ResearchTopic topic) const {
        return TopicHelper::getTopicDisclaimer(topic);
    }

    std::string getGeneralDisclaimer() const {
        return Disclaimers::GENERAL_DISCLAIMER;
    }

    std::string getBiofeedbackDisclaimer() const {
        return Disclaimers::BIOFEEDBACK_DISCLAIMER;
    }

    // ===== Research Summary Templates =====

    struct SummaryTemplate {
        std::string name;
        std::string structure;
        std::vector<std::string> requiredSections;
        std::string disclaimer;
    };

    std::vector<SummaryTemplate> getSummaryTemplates() const {
        return {
            {
                "Research Overview",
                "Background → Key Studies → Findings Summary → Limitations → Disclaimer",
                {"Background", "Studies Reviewed", "Key Findings", "Limitations", "Disclaimer"},
                Disclaimers::RESEARCH_DISCLAIMER
            },
            {
                "Topic Introduction",
                "Definition → History → Current Research → Practical Context → Disclaimer",
                {"Definition", "Background", "Research Summary", "Context", "Disclaimer"},
                Disclaimers::GENERAL_DISCLAIMER
            },
            {
                "Study Summary",
                "Citation → Objective → Methods → Results → Limitations → Disclaimer",
                {"Full Citation", "Study Objective", "Methodology", "Results", "Study Limitations", "Disclaimer"},
                Disclaimers::RESEARCH_DISCLAIMER
            }
        };
    }

    // ===== User Summary Management =====

    void addUserSummary(const ResearchSummary& summary) {
        userSummaries_[summary.id] = summary;
    }

    std::optional<ResearchSummary> getUserSummary(const std::string& id) const {
        auto it = userSummaries_.find(id);
        if (it != userSummaries_.end()) {
            return it->second;
        }
        return std::nullopt;
    }

    // ===== Export Functions =====

    std::string exportSourceList(CitationStyle style = CitationStyle::APA7) const {
        std::string output = "Research Sources\n";
        output += "================\n\n";

        for (const auto& source : database_.getAllSources()) {
            output += source.getCitation(style) + "\n\n";
        }

        output += "\n" + Disclaimers::RESEARCH_DISCLAIMER;
        return output;
    }

private:
    void initializeExampleSources() {
        // Example: Well-known biofeedback research
        // Users should add their own verified sources

        ResearchSource example1;
        example1.id = "example_biofeedback_meta";
        example1.title = "The efficacy of biofeedback for anxiety: A meta-analysis";
        example1.authors = {{{"John", "Smith", "University Example", ""}}};
        example1.year = 2020;
        example1.journalName = "Example Journal of Psychology";
        example1.sourceType = SourceType::MetaAnalysis;
        example1.evidenceLevel = EvidenceLevel::Level1_MetaAnalysis;
        example1.topics = {ResearchTopic::Biofeedback, ResearchTopic::StressManagement};
        example1.abstractText = "[This is a placeholder example. Users should add real sources.]";

        // Note: This is just a template - users add real sources
        // database_.addSource(example1);
    }

    ResearchDatabase database_;
    std::map<std::string, ResearchSummary> userSummaries_;
};

} // namespace Content
} // namespace Echoel
