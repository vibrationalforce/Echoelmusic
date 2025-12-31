/*
 * EchoelContentTests.cpp
 * Ralph Wiggum Genius Loop Mode - Content Management Tests
 *
 * Tests for research tools, content management, and compliance checking.
 * Ensures no health claims are made and content is properly managed.
 */

#include <cassert>
#include <iostream>
#include <string>
#include <vector>

#include "../Sources/Content/EchoelResearchTool.h"
#include "../Sources/Content/EchoelContentManager.h"
#include "../Sources/Content/EchoelComplianceChecker.h"

using namespace Echoel::Content;

// ============================================================================
// Test Utilities
// ============================================================================

class TestRunner {
public:
    static void assertTrue(bool condition, const std::string& message) {
        totalTests_++;
        if (condition) {
            passedTests_++;
            std::cout << "  [PASS] " << message << std::endl;
        } else {
            std::cout << "  [FAIL] " << message << std::endl;
        }
    }

    static void assertFalse(bool condition, const std::string& message) {
        assertTrue(!condition, message);
    }

    static void assertEqual(const std::string& a, const std::string& b,
                           const std::string& message) {
        assertTrue(a == b, message + " (got: " + a + ")");
    }

    static void printSummary() {
        std::cout << "\n========================================\n";
        std::cout << "Test Summary: " << passedTests_ << "/" << totalTests_ << " passed\n";
        std::cout << "========================================\n";
    }

    static int getFailCount() { return totalTests_ - passedTests_; }

private:
    static inline int totalTests_ = 0;
    static inline int passedTests_ = 0;
};

// ============================================================================
// Research Tool Tests
// ============================================================================

void testDisclaimers() {
    std::cout << "\n=== Disclaimer Tests ===\n";

    // Check general disclaimer exists and contains key phrases
    std::string general = Disclaimers::GENERAL_DISCLAIMER;
    TestRunner::assertTrue(!general.empty(), "General disclaimer exists");
    TestRunner::assertTrue(general.find("educational") != std::string::npos,
                          "General disclaimer mentions educational");
    TestRunner::assertTrue(general.find("not intended") != std::string::npos ||
                          general.find("not a substitute") != std::string::npos,
                          "General disclaimer has proper warning");

    // Check biofeedback disclaimer
    std::string bio = Disclaimers::BIOFEEDBACK_DISCLAIMER;
    TestRunner::assertTrue(!bio.empty(), "Biofeedback disclaimer exists");
    TestRunner::assertTrue(bio.find("not medical device") != std::string::npos ||
                          bio.find("do not diagnose") != std::string::npos,
                          "Biofeedback disclaimer clarifies non-medical nature");

    // No health claims disclaimer
    std::string noHealth = Disclaimers::NO_HEALTH_CLAIMS;
    TestRunner::assertTrue(!noHealth.empty(), "No health claims disclaimer exists");
}

void testResearchSource() {
    std::cout << "\n=== Research Source Tests ===\n";

    ResearchSource source;
    source.id = "test_001";
    source.title = "Effects of Biofeedback on Relaxation: A Randomized Controlled Trial";
    source.authors = {
        {"John", "Smith", "University of Example", ""},
        {"Jane", "Doe", "Research Institute", ""}
    };
    source.journalName = "Journal of Relaxation Research";
    source.year = 2023;
    source.volume = "15";
    source.issue = "3";
    source.pages = "123-145";
    source.doi = "10.1234/example.2023.001";
    source.sourceType = SourceType::RandomizedControlTrial;
    source.evidenceLevel = EvidenceLevel::Level2_RCT;

    // Test citation generation
    std::string apaCitation = source.getCitation(CitationStyle::APA7);
    TestRunner::assertTrue(!apaCitation.empty(), "APA citation generated");
    TestRunner::assertTrue(apaCitation.find("Smith") != std::string::npos,
                          "Citation includes author");
    TestRunner::assertTrue(apaCitation.find("2023") != std::string::npos,
                          "Citation includes year");

    std::string plainCitation = source.getCitation(CitationStyle::Plain);
    TestRunner::assertTrue(!plainCitation.empty(), "Plain citation generated");

    // Test URL generation
    std::string url = source.getAccessUrl();
    TestRunner::assertTrue(url.find("doi.org") != std::string::npos,
                          "DOI URL generated correctly");
}

void testEvidenceLevels() {
    std::cout << "\n=== Evidence Level Tests ===\n";

    // Test level names
    std::string level1 = EvidenceLevelHelper::getLevelName(
        EvidenceLevel::Level1_MetaAnalysis);
    TestRunner::assertTrue(level1.find("Meta") != std::string::npos,
                          "Level 1 correctly named");

    std::string level2 = EvidenceLevelHelper::getLevelName(
        EvidenceLevel::Level2_RCT);
    TestRunner::assertTrue(level2.find("Randomized") != std::string::npos,
                          "Level 2 correctly named");

    // Test descriptions
    std::string desc = EvidenceLevelHelper::getLevelDescription(
        EvidenceLevel::Level1_MetaAnalysis);
    TestRunner::assertTrue(!desc.empty(), "Level 1 has description");
    TestRunner::assertTrue(desc.find("highest") != std::string::npos ||
                          desc.find("Highest") != std::string::npos,
                          "Level 1 described as highest");

    // Test interpretation guidance
    std::string guidance = EvidenceLevelHelper::getInterpretationGuidance(
        EvidenceLevel::Level5_CaseSeries);
    TestRunner::assertTrue(guidance.find("caution") != std::string::npos,
                          "Lower levels recommend caution");
}

void testResearchDatabase() {
    std::cout << "\n=== Research Database Tests ===\n";

    ResearchDatabase db;

    // Add test sources
    ResearchSource source1;
    source1.id = "src_001";
    source1.title = "Biofeedback Study 1";
    source1.year = 2022;
    source1.topics = {ResearchTopic::Biofeedback};
    source1.evidenceLevel = EvidenceLevel::Level2_RCT;
    db.addSource(source1);

    ResearchSource source2;
    source2.id = "src_002";
    source2.title = "Meditation Meta-Analysis";
    source2.year = 2023;
    source2.topics = {ResearchTopic::Meditation, ResearchTopic::Mindfulness};
    source2.evidenceLevel = EvidenceLevel::Level1_MetaAnalysis;
    db.addSource(source2);

    // Test retrieval
    auto retrieved = db.getSource("src_001");
    TestRunner::assertTrue(retrieved.has_value(), "Source retrieved by ID");
    TestRunner::assertEqual(retrieved->title, "Biofeedback Study 1", "Correct source retrieved");

    // Test topic search
    auto biofeedbackSources = db.getByTopic(ResearchTopic::Biofeedback);
    TestRunner::assertTrue(biofeedbackSources.size() >= 1, "Topic search works");

    // Test evidence level filter
    auto highQuality = db.getByEvidenceLevel(EvidenceLevel::Level2_RCT);
    TestRunner::assertTrue(highQuality.size() >= 2, "Evidence filter works");

    // Test text search
    auto searchResults = db.search("meditation");
    TestRunner::assertTrue(searchResults.size() >= 1, "Text search works");
}

void testResearchTool() {
    std::cout << "\n=== Research Tool Tests ===\n";

    EchoelResearchTool tool;

    // Test disclaimer retrieval
    std::string disclaimer = tool.getGeneralDisclaimer();
    TestRunner::assertTrue(!disclaimer.empty(), "Can get general disclaimer");

    std::string bioDisclaimer = tool.getBiofeedbackDisclaimer();
    TestRunner::assertTrue(!bioDisclaimer.empty(), "Can get biofeedback disclaimer");

    // Test topic disclaimer
    std::string topicDisc = tool.getRequiredDisclaimer(ResearchTopic::BrainwaveEntrainment);
    TestRunner::assertTrue(!topicDisc.empty(), "Topic-specific disclaimer generated");

    // Test summary templates
    auto templates = tool.getSummaryTemplates();
    TestRunner::assertTrue(!templates.empty(), "Summary templates available");
    for (const auto& t : templates) {
        TestRunner::assertTrue(!t.requiredSections.empty(),
                              "Template '" + t.name + "' has required sections");
    }
}

// ============================================================================
// Content Manager Tests
// ============================================================================

void testPlatformSpecs() {
    std::cout << "\n=== Platform Specs Tests ===\n";

    // Test Instagram specs
    auto instaSpec = PlatformSpecs::getSpec(Platform::Instagram);
    TestRunner::assertEqual(instaSpec.name, "instagram", "Instagram spec name correct");
    TestRunner::assertTrue(instaSpec.maxBodyLength == 2200, "Instagram character limit correct");
    TestRunner::assertTrue(instaSpec.maxHashtags == 30, "Instagram hashtag limit correct");

    // Test Twitter specs
    auto twitterSpec = PlatformSpecs::getSpec(Platform::Twitter);
    TestRunner::assertTrue(twitterSpec.maxBodyLength == 280, "Twitter character limit correct");

    // Test LinkedIn specs
    auto linkedinSpec = PlatformSpecs::getSpec(Platform::LinkedIn);
    TestRunner::assertTrue(linkedinSpec.maxBodyLength == 3000, "LinkedIn character limit correct");

    // Test all platforms exist
    auto allPlatforms = PlatformSpecs::getAllPlatforms();
    TestRunner::assertTrue(allPlatforms.size() > 10, "Many platforms supported");
}

void testContentTemplates() {
    std::cout << "\n=== Content Template Tests ===\n";

    TemplateLibrary library;

    // Get all templates
    auto templates = library.getTemplates();
    TestRunner::assertTrue(!templates.empty(), "Templates available");

    // Check research template has disclaimer requirement
    auto researchTemplate = library.getTemplate("edu_research_summary");
    TestRunner::assertTrue(researchTemplate.has_value(), "Research template exists");
    TestRunner::assertTrue(researchTemplate->requiresDisclaimer,
                          "Research template requires disclaimer");
    TestRunner::assertTrue(researchTemplate->requiresSources,
                          "Research template requires sources");

    // Test platform-specific templates
    auto instaTemplates = library.getTemplatesForPlatform(Platform::Instagram);
    TestRunner::assertTrue(!instaTemplates.empty(), "Instagram templates available");
}

void testContentFormatter() {
    std::cout << "\n=== Content Formatter Tests ===\n";

    ContentFormatter formatter;

    ContentItem item;
    item.headline = "Interesting Finding About Relaxation";
    item.body = "Research suggests that regular relaxation practices may support "
                "overall wellbeing. Here's what the science says...";
    item.callToAction = "What relaxation techniques work for you?";
    item.disclaimer = "This is for educational purposes only.";
    item.disclaimerIncluded = true;

    // Format for Instagram
    auto instaFormatted = formatter.formatForPlatform(item, Platform::Instagram);
    TestRunner::assertTrue(!instaFormatted.text.empty(), "Instagram format generated");
    TestRunner::assertTrue(instaFormatted.withinLimits, "Content within Instagram limits");

    // Format for Twitter (should be shorter)
    auto twitterFormatted = formatter.formatForPlatform(item, Platform::Twitter);
    TestRunner::assertTrue(!twitterFormatted.text.empty(), "Twitter format generated");
}

void testContentCalendar() {
    std::cout << "\n=== Content Calendar Tests ===\n";

    ContentCalendar calendar;

    CalendarEntry entry1;
    entry1.contentId = "content_001";
    entry1.scheduledDate = "2024-01-15";
    entry1.platform = Platform::Instagram;
    calendar.scheduleContent(entry1);

    CalendarEntry entry2;
    entry2.contentId = "content_002";
    entry2.scheduledDate = "2024-01-15";
    entry2.platform = Platform::LinkedIn;
    calendar.scheduleContent(entry2);

    // Test date retrieval
    auto entriesForDate = calendar.getEntriesForDate("2024-01-15");
    TestRunner::assertTrue(entriesForDate.size() == 2, "Retrieved entries for date");

    // Test platform filter
    auto instaEntries = calendar.getEntriesForPlatform(Platform::Instagram);
    TestRunner::assertTrue(instaEntries.size() >= 1, "Platform filter works");
}

void testContentManager() {
    std::cout << "\n=== Content Manager Tests ===\n";

    EchoelContentManager manager;

    // Create content
    ContentItem item;
    item.id = "test_content_001";
    item.title = "Understanding Relaxation Research";
    item.headline = "What Science Says About Relaxation";
    item.body = "Recent studies have explored various relaxation techniques...";
    item.type = ContentType::Research;
    item.status = ContentStatus::Draft;
    item.sourceIds = {"source_001", "source_002"};
    item.disclaimerIncluded = true;
    item.disclaimer = "For educational purposes only.";

    manager.addContent(item);

    // Retrieve content
    auto retrieved = manager.getContent("test_content_001");
    TestRunner::assertTrue(retrieved.has_value(), "Content retrieved");
    TestRunner::assertEqual(retrieved->title, "Understanding Relaxation Research",
                           "Content title correct");

    // Test publish checklist
    auto checklist = manager.getPublishChecklist("test_content_001", Platform::Blog);
    TestRunner::assertTrue(checklist.totalCount > 0, "Checklist has items");

    // Test hashtag suggestions
    auto hashtags = manager.suggestHashtags("biofeedback relaxation", Platform::Instagram);
    TestRunner::assertTrue(!hashtags.empty(), "Hashtag suggestions generated");
}

// ============================================================================
// Compliance Checker Tests
// ============================================================================

void testHealthClaimDetection() {
    std::cout << "\n=== Health Claim Detection Tests ===\n";

    EchoelComplianceChecker checker;

    // Test clear health claim
    std::string healthClaim = "This product cures anxiety and treats insomnia.";
    auto result = checker.checkContent(healthClaim);
    TestRunner::assertFalse(result.passed, "Health claim detected as issue");
    TestRunner::assertTrue(result.criticalCount > 0, "Health claim marked as critical");

    // Test medical advice
    std::string medicalAdvice = "Take 500mg daily and stop taking your medication.";
    result = checker.checkContent(medicalAdvice);
    TestRunner::assertFalse(result.passed, "Medical advice detected");
    TestRunner::assertTrue(result.criticalCount > 0, "Medical advice marked as critical");

    // Test safe content
    std::string safeContent =
        "Research suggests that relaxation practices may support overall wellbeing. "
        "Individual results vary. This is for educational purposes only.";
    result = checker.checkContent(safeContent);
    TestRunner::assertTrue(result.passed, "Safe content passes");
    TestRunner::assertTrue(result.criticalCount == 0, "No critical issues in safe content");
}

void testAbsoluteLanguageDetection() {
    std::cout << "\n=== Absolute Language Detection Tests ===\n";

    EchoelComplianceChecker checker;

    // Test absolute claims
    std::string absolute = "This always works and is 100% guaranteed to help everyone.";
    auto result = checker.checkContent(absolute);
    TestRunner::assertTrue(result.warningCount > 0, "Absolute language flagged");

    // Test superlatives
    std::string superlative = "This miracle breakthrough is revolutionary and amazing.";
    result = checker.checkContent(superlative);
    TestRunner::assertTrue(result.warningCount > 0, "Superlative language flagged");

    // Test measured language
    std::string measured = "Many users have found this helpful. Results may vary.";
    result = checker.checkContent(measured);
    TestRunner::assertTrue(result.criticalCount == 0, "Measured language OK");
}

void testSeriousConditionDetection() {
    std::cout << "\n=== Serious Condition Detection Tests ===\n";

    EchoelComplianceChecker checker;

    // Test cancer mention
    std::string cancerClaim = "This helps prevent cancer.";
    auto result = checker.checkContent(cancerClaim);
    TestRunner::assertTrue(result.criticalCount > 0, "Cancer claim detected");

    // Test heart disease
    std::string heartClaim = "This treats heart disease.";
    result = checker.checkContent(heartClaim);
    TestRunner::assertTrue(result.criticalCount > 0, "Heart disease claim detected");

    // Test diabetes
    std::string diabetesClaim = "This cures diabetes.";
    result = checker.checkContent(diabetesClaim);
    TestRunner::assertTrue(result.criticalCount > 0, "Diabetes claim detected");
}

void testDisclaimerDetection() {
    std::cout << "\n=== Disclaimer Detection Tests ===\n";

    EchoelComplianceChecker checker;

    // Without disclaimer
    std::string noDisclaimer = "Relaxation is great for you.";
    auto result = checker.checkContent(noDisclaimer, true);
    TestRunner::assertFalse(result.disclaimerPresent, "Missing disclaimer detected");

    // With disclaimer
    std::string withDisclaimer =
        "Relaxation practices can be beneficial. "
        "This is for educational purposes only and is not intended as medical advice.";
    result = checker.checkContent(withDisclaimer, true);
    TestRunner::assertTrue(result.disclaimerPresent, "Disclaimer detected");
}

void testSafeLanguageGuide() {
    std::cout << "\n=== Safe Language Guide Tests ===\n";

    EchoelComplianceChecker checker;

    // Get alternatives
    auto alternatives = checker.getSafeAlternatives();
    TestRunner::assertTrue(!alternatives.empty(), "Alternatives available");

    // Check alternatives have required fields
    for (const auto& alt : alternatives) {
        TestRunner::assertTrue(!alt.avoid.empty(), "Alternative has 'avoid'");
        TestRunner::assertTrue(!alt.useInstead.empty(), "Alternative has 'useInstead'");
        TestRunner::assertTrue(!alt.explanation.empty(), "Alternative has explanation");
    }

    // Get safe verbs
    auto safeVerbs = checker.getSafeVerbs();
    TestRunner::assertTrue(!safeVerbs.empty(), "Safe verbs available");
    TestRunner::assertTrue(std::find(safeVerbs.begin(), safeVerbs.end(),
                          "may support") != safeVerbs.end(),
                          "'may support' is a safe verb");

    // Get disclaimer templates
    auto disclaimers = checker.getDisclaimerTemplates();
    TestRunner::assertTrue(!disclaimers.empty(), "Disclaimer templates available");
}

void testComplianceReport() {
    std::cout << "\n=== Compliance Report Tests ===\n";

    EchoelComplianceChecker checker;

    std::string mixedContent =
        "This amazing product cures stress! Always works! "
        "Take 200mg daily for best results.";

    auto result = checker.checkContent(mixedContent);
    std::string report = checker.generateReport(result);

    TestRunner::assertTrue(!report.empty(), "Report generated");
    TestRunner::assertTrue(report.find("CRITICAL") != std::string::npos,
                          "Report includes critical issues");
    TestRunner::assertTrue(report.find("RECOMMENDATIONS") != std::string::npos,
                          "Report includes recommendations");
    TestRunner::assertTrue(report.find("DISCLAIMER") != std::string::npos,
                          "Report includes tool disclaimer");
}

void testSuggestionImprovement() {
    std::cout << "\n=== Suggestion Improvement Tests ===\n";

    EchoelComplianceChecker checker;

    // Test improvement suggestion
    std::string suggestion = checker.suggestImprovement("cures anxiety");
    TestRunner::assertTrue(!suggestion.empty(), "Improvement suggested");
    TestRunner::assertTrue(suggestion.find("may") != std::string::npos ||
                          suggestion.find("support") != std::string::npos ||
                          suggestion.find("Consider") != std::string::npos,
                          "Suggestion uses safer language");
}

// ============================================================================
// Integration Tests
// ============================================================================

void testContentWorkflow() {
    std::cout << "\n=== Content Workflow Integration Tests ===\n";

    // Create research tool
    EchoelResearchTool research;

    // Create content manager
    EchoelContentManager contentMgr;

    // Create compliance checker
    EchoelComplianceChecker compliance;

    // Step 1: Get disclaimer for topic
    std::string disclaimer = research.getRequiredDisclaimer(ResearchTopic::Biofeedback);
    TestRunner::assertTrue(!disclaimer.empty(), "Got topic disclaimer");

    // Step 2: Create content with disclaimer
    ContentItem content;
    content.id = "workflow_test";
    content.title = "Understanding Biofeedback Research";
    content.headline = "What Studies Show About Biofeedback";
    content.body = "Research suggests biofeedback may support relaxation. "
                   "Individual results vary.";
    content.disclaimer = disclaimer;
    content.disclaimerIncluded = true;
    content.type = ContentType::Research;

    // Step 3: Check compliance
    std::string fullText = content.body + "\n\n" + content.disclaimer;
    auto complianceResult = compliance.checkContent(fullText);
    TestRunner::assertTrue(complianceResult.passed, "Content passes compliance");
    TestRunner::assertTrue(complianceResult.disclaimerPresent, "Disclaimer detected");

    // Step 4: Add to content manager
    content.complianceChecked = complianceResult.passed;
    content.complianceIssues.clear();
    for (const auto& issue : complianceResult.issues) {
        content.complianceIssues.push_back(
            ComplianceIssue::getTypeName(issue.type) + ": " + issue.explanation);
    }
    contentMgr.addContent(content);

    // Step 5: Get publish checklist
    auto checklist = contentMgr.getPublishChecklist("workflow_test", Platform::Blog);
    TestRunner::assertTrue(checklist.totalCount > 0, "Checklist generated");

    // Step 6: Format for platform
    auto formatted = contentMgr.formatForPlatform("workflow_test", Platform::LinkedIn);
    TestRunner::assertTrue(!formatted.text.empty(), "Content formatted for platform");
}

// ============================================================================
// Main Test Runner
// ============================================================================

int main() {
    std::cout << "================================================\n";
    std::cout << " Echoel Content Management Test Suite\n";
    std::cout << " No Health Claims - Evidence Based Only\n";
    std::cout << "================================================\n";

    // Research Tool Tests
    testDisclaimers();
    testResearchSource();
    testEvidenceLevels();
    testResearchDatabase();
    testResearchTool();

    // Content Manager Tests
    testPlatformSpecs();
    testContentTemplates();
    testContentFormatter();
    testContentCalendar();
    testContentManager();

    // Compliance Checker Tests
    testHealthClaimDetection();
    testAbsoluteLanguageDetection();
    testSeriousConditionDetection();
    testDisclaimerDetection();
    testSafeLanguageGuide();
    testComplianceReport();
    testSuggestionImprovement();

    // Integration Tests
    testContentWorkflow();

    TestRunner::printSummary();

    return TestRunner::getFailCount() > 0 ? 1 : 0;
}
