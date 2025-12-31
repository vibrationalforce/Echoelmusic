#pragma once

/*
 * EchoelContentManager.h
 * Ralph Wiggum Genius Loop Mode - Multi-Platform Content Management
 *
 * IMPORTANT:
 * - This is an ASSISTIVE tool for content organization
 * - User creates ALL content - tool only helps organize and format
 * - 100% of content ownership and credits remain with user
 * - No auto-generation of content
 * - Built-in compliance checking for health claim avoidance
 *
 * Supported Platforms:
 * - Website/Blog
 * - Instagram
 * - Facebook
 * - Twitter/X
 * - LinkedIn
 * - YouTube
 * - TikTok
 * - Pinterest
 * - Newsletter/Email
 */

#include <vector>
#include <string>
#include <map>
#include <optional>
#include <chrono>
#include <memory>
#include <functional>

namespace Echoel {
namespace Content {

// ============================================================================
// Platform Specifications
// ============================================================================

enum class Platform {
    Website,
    Blog,
    Instagram,
    InstagramStory,
    InstagramReel,
    Facebook,
    FacebookStory,
    Twitter,
    LinkedIn,
    YouTube,
    YouTubeShorts,
    TikTok,
    Pinterest,
    Newsletter,
    Email,
    Podcast,
    Press
};

struct PlatformSpec {
    Platform platform;
    std::string name;
    std::string displayName;

    // Text limits
    int maxTitleLength = 100;
    int maxBodyLength = 2000;
    int maxHashtags = 30;
    int recommendedHashtags = 5;

    // Media specs
    std::vector<std::string> supportedImageFormats;
    std::vector<std::string> supportedVideoFormats;
    std::string recommendedImageSize;
    std::string recommendedVideoSize;
    int maxVideoDurationSeconds = 60;

    // Best practices
    std::vector<std::string> contentTips;
    std::string bestTimeToPost;
    std::vector<std::string> doList;
    std::vector<std::string> dontList;
};

class PlatformSpecs {
public:
    static PlatformSpec getSpec(Platform platform) {
        switch (platform) {
            case Platform::Instagram:
                return {
                    Platform::Instagram,
                    "instagram",
                    "Instagram Post",
                    100,
                    2200,
                    30,
                    11,
                    {"jpg", "png"},
                    {"mp4", "mov"},
                    "1080x1080 (square) or 1080x1350 (portrait)",
                    "1080x1920 (9:16)",
                    60,
                    {
                        "Use high-quality visuals",
                        "First line is crucial - hook readers",
                        "Use line breaks for readability",
                        "End with a call to action"
                    },
                    "Weekdays 11am-1pm, 7pm-9pm",
                    {"Use relevant hashtags", "Engage with comments", "Post consistently"},
                    {"Don't use too many hashtags", "Avoid low-quality images"}
                };

            case Platform::InstagramStory:
                return {
                    Platform::InstagramStory,
                    "instagram_story",
                    "Instagram Story",
                    100,
                    200,
                    10,
                    3,
                    {"jpg", "png"},
                    {"mp4", "mov"},
                    "1080x1920 (9:16)",
                    "1080x1920 (9:16)",
                    15,
                    {
                        "Keep text minimal and readable",
                        "Use interactive elements (polls, questions)",
                        "Add location and hashtag stickers"
                    },
                    "Throughout the day",
                    {"Use stickers and polls", "Keep content casual"},
                    {"Don't overload with text"}
                };

            case Platform::Twitter:
                return {
                    Platform::Twitter,
                    "twitter",
                    "Twitter/X Post",
                    280,
                    280,
                    5,
                    2,
                    {"jpg", "png", "gif"},
                    {"mp4"},
                    "1200x675 (16:9)",
                    "1920x1080",
                    140,
                    {
                        "Be concise and punchy",
                        "Use threads for longer content",
                        "Engage with trending topics when relevant"
                    },
                    "Weekdays 8am-10am, 12pm-1pm",
                    {"Use threads for depth", "Engage with replies"},
                    {"Don't use too many hashtags"}
                };

            case Platform::LinkedIn:
                return {
                    Platform::LinkedIn,
                    "linkedin",
                    "LinkedIn Post",
                    150,
                    3000,
                    5,
                    3,
                    {"jpg", "png"},
                    {"mp4"},
                    "1200x627 or 1080x1080",
                    "1920x1080",
                    600,
                    {
                        "Professional tone but personable",
                        "Share insights and expertise",
                        "Use line breaks and emojis sparingly",
                        "First 2-3 lines visible before 'see more'"
                    },
                    "Tue-Thu 8am-10am, 12pm, 5pm-6pm",
                    {"Share professional insights", "Engage with comments"},
                    {"Avoid overly salesy content"}
                };

            case Platform::Facebook:
                return {
                    Platform::Facebook,
                    "facebook",
                    "Facebook Post",
                    100,
                    63206,
                    10,
                    3,
                    {"jpg", "png", "gif"},
                    {"mp4", "mov"},
                    "1200x630 or 1080x1080",
                    "1280x720",
                    240,
                    {
                        "Encourage engagement with questions",
                        "Native video performs better than links",
                        "Use Facebook-specific features"
                    },
                    "Wed-Fri 1pm-4pm",
                    {"Encourage discussion", "Use native video"},
                    {"Don't post too frequently"}
                };

            case Platform::YouTube:
                return {
                    Platform::YouTube,
                    "youtube",
                    "YouTube Video",
                    100,
                    5000,
                    15,
                    5,
                    {"jpg", "png"},
                    {"mp4", "mov", "avi"},
                    "1280x720 (thumbnail)",
                    "1920x1080 or 3840x2160",
                    7200,
                    {
                        "Hook viewers in first 10 seconds",
                        "Use timestamps in description",
                        "Create compelling thumbnails",
                        "Include clear call to action"
                    },
                    "Thu-Sun 12pm-4pm",
                    {"Optimize titles and descriptions", "Use end screens"},
                    {"Don't use clickbait", "Avoid long intros"}
                };

            case Platform::TikTok:
                return {
                    Platform::TikTok,
                    "tiktok",
                    "TikTok Video",
                    100,
                    2200,
                    10,
                    4,
                    {"jpg", "png"},
                    {"mp4", "mov"},
                    "1080x1920 (9:16)",
                    "1080x1920 (9:16)",
                    180,
                    {
                        "Hook in first 1-2 seconds",
                        "Use trending sounds",
                        "Keep content authentic and casual",
                        "Vertical format only"
                    },
                    "Tue-Thu 7pm-9pm",
                    {"Follow trends", "Be authentic"},
                    {"Don't be too polished", "Avoid hard selling"}
                };

            case Platform::Blog:
            case Platform::Website:
                return {
                    Platform::Blog,
                    "blog",
                    "Blog Post",
                    70,
                    50000,
                    10,
                    5,
                    {"jpg", "png", "webp"},
                    {"mp4"},
                    "1200x630 (featured)",
                    "1920x1080",
                    3600,
                    {
                        "Use clear headings (H1, H2, H3)",
                        "Include internal and external links",
                        "Optimize for SEO",
                        "Use images to break up text"
                    },
                    "Consistent schedule",
                    {"Use SEO best practices", "Include sources"},
                    {"Don't keyword stuff"}
                };

            case Platform::Newsletter:
                return {
                    Platform::Newsletter,
                    "newsletter",
                    "Newsletter",
                    60,
                    10000,
                    0,
                    0,
                    {"jpg", "png"},
                    {},
                    "600px width",
                    "",
                    0,
                    {
                        "Clear subject line is crucial",
                        "Personalize when possible",
                        "Mobile-friendly design",
                        "Clear call to action"
                    },
                    "Tue-Thu 10am",
                    {"Segment your audience", "A/B test subject lines"},
                    {"Don't send too frequently"}
                };

            case Platform::Pinterest:
                return {
                    Platform::Pinterest,
                    "pinterest",
                    "Pinterest Pin",
                    100,
                    500,
                    20,
                    5,
                    {"jpg", "png"},
                    {"mp4"},
                    "1000x1500 (2:3)",
                    "1080x1920",
                    60,
                    {
                        "Vertical images perform best",
                        "Use text overlays on images",
                        "Rich pins for more context"
                    },
                    "Sat-Sun 8pm-11pm",
                    {"Use rich pins", "Create boards"},
                    {"Avoid horizontal images"}
                };

            default:
                return {
                    Platform::Website,
                    "generic",
                    "Generic Content",
                    100,
                    5000,
                    10,
                    5,
                    {"jpg", "png"},
                    {"mp4"},
                    "1200x630",
                    "1920x1080",
                    300,
                    {},
                    "",
                    {},
                    {}
                };
        }
    }

    static std::vector<Platform> getAllPlatforms() {
        return {
            Platform::Website, Platform::Blog, Platform::Instagram,
            Platform::InstagramStory, Platform::InstagramReel,
            Platform::Facebook, Platform::FacebookStory, Platform::Twitter,
            Platform::LinkedIn, Platform::YouTube, Platform::YouTubeShorts,
            Platform::TikTok, Platform::Pinterest, Platform::Newsletter,
            Platform::Email, Platform::Podcast, Platform::Press
        };
    }
};

// ============================================================================
// Content Types
// ============================================================================

enum class ContentType {
    Educational,        // Teaching/explaining concepts
    Informational,      // Sharing information
    BehindTheScenes,    // Process/journey content
    Tutorial,           // How-to guides
    Announcement,       // News/updates
    Testimonial,        // User stories (with consent)
    Research,           // Science-based content
    Inspiration,        // Motivational/inspiring
    Community,          // Engaging with audience
    ProductInfo,        // About products/services
    FAQ,                // Frequently asked questions
    CaseStudy           // Detailed examples
};

enum class ContentStatus {
    Draft,
    Review,
    Approved,
    Scheduled,
    Published,
    Archived
};

// ============================================================================
// Content Item Structure
// ============================================================================

struct ContentItem {
    // Identification
    std::string id;
    std::string title;
    ContentType type = ContentType::Educational;
    ContentStatus status = ContentStatus::Draft;

    // Content (User-Created)
    std::string headline;               // Main headline/hook
    std::string body;                   // Main content
    std::string callToAction;           // CTA text
    std::vector<std::string> hashtags;
    std::vector<std::string> keywords;

    // Media references (paths/URLs)
    std::vector<std::string> images;
    std::vector<std::string> videos;
    std::string thumbnailPath;

    // Metadata
    std::string author;
    std::string createdDate;
    std::string modifiedDate;
    std::string scheduledDate;

    // Compliance
    bool disclaimerIncluded = false;
    std::string disclaimer;
    bool complianceChecked = false;
    std::vector<std::string> complianceIssues;

    // Source references (for research-based content)
    std::vector<std::string> sourceIds;

    // Platform versions
    std::map<Platform, std::string> platformVersions;

    // Notes
    std::string internalNotes;
};

// ============================================================================
// Content Templates (User Starting Points)
// ============================================================================

struct ContentTemplate {
    std::string id;
    std::string name;
    ContentType type;
    std::vector<Platform> suitableFor;

    // Structure guidance
    std::vector<std::string> sections;
    std::vector<std::string> tips;
    std::string exampleStructure;

    // Required elements
    bool requiresDisclaimer = true;
    bool requiresSources = false;
    std::string suggestedDisclaimer;
};

class TemplateLibrary {
public:
    std::vector<ContentTemplate> getTemplates() const {
        return {
            {
                "edu_research_summary",
                "Research Summary Post",
                ContentType::Research,
                {Platform::Blog, Platform::LinkedIn, Platform::Facebook},
                {
                    "Hook/Introduction",
                    "Research Overview",
                    "Key Findings",
                    "What This Means (no claims)",
                    "Limitations",
                    "Sources",
                    "Disclaimer"
                },
                {
                    "Lead with an interesting finding",
                    "Use simple language",
                    "Always cite sources",
                    "Include study limitations",
                    "No health claims - informational only"
                },
                "Did you know that researchers have been studying [topic]? "
                "A recent [study type] found that [finding]. "
                "Here's what the science says...\n\n"
                "[Key points]\n\n"
                "Important note: [limitations]\n\n"
                "Sources: [citations]\n\n"
                "[Disclaimer]",
                true,
                true,
                "This information is for educational purposes only and does not "
                "constitute medical advice."
            },
            {
                "social_tip",
                "Quick Tip Post",
                ContentType::Educational,
                {Platform::Instagram, Platform::Twitter, Platform::TikTok},
                {
                    "Attention-grabbing hook",
                    "The tip (1-3 sentences)",
                    "Why it matters",
                    "Call to action",
                    "Hashtags"
                },
                {
                    "Keep it concise",
                    "Use emojis strategically",
                    "Make it actionable",
                    "No health claims"
                },
                "💡 Quick tip: [tip]\n\n"
                "Why? [brief explanation]\n\n"
                "Try it and let me know how it goes! 👇\n\n"
                "#relevant #hashtags",
                false,
                false,
                ""
            },
            {
                "tutorial_post",
                "Tutorial/How-To",
                ContentType::Tutorial,
                {Platform::Blog, Platform::YouTube, Platform::Instagram},
                {
                    "Introduction",
                    "What you'll learn",
                    "Prerequisites",
                    "Step-by-step instructions",
                    "Tips & tricks",
                    "Common mistakes",
                    "Conclusion"
                },
                {
                    "Number your steps clearly",
                    "Use visuals for each step",
                    "Keep instructions simple",
                    "Address common problems"
                },
                "How to [achieve goal]: A Step-by-Step Guide\n\n"
                "What you'll need: [list]\n\n"
                "Step 1: [instruction]\n"
                "Step 2: [instruction]\n"
                "...\n\n"
                "Pro tip: [bonus tip]",
                false,
                false,
                ""
            },
            {
                "bts_journey",
                "Behind-the-Scenes",
                ContentType::BehindTheScenes,
                {Platform::Instagram, Platform::InstagramStory, Platform::TikTok},
                {
                    "Context/setup",
                    "The process",
                    "Challenges faced",
                    "What we learned",
                    "Invitation to engage"
                },
                {
                    "Be authentic",
                    "Show real moments",
                    "Share learnings",
                    "Invite questions"
                },
                "Ever wondered how [thing] gets made? 🎬\n\n"
                "Here's a peek behind the scenes...\n\n"
                "[story/process]\n\n"
                "What would you like to see more of?",
                false,
                false,
                ""
            },
            {
                "faq_post",
                "FAQ/Q&A",
                ContentType::FAQ,
                {Platform::Blog, Platform::Instagram, Platform::Facebook},
                {
                    "Question",
                    "Short answer",
                    "Detailed explanation",
                    "Additional resources",
                    "Disclaimer if needed"
                },
                {
                    "Use actual questions from audience",
                    "Keep answers clear",
                    "Link to resources",
                    "Be careful with health questions"
                },
                "Q: [common question]\n\n"
                "A: [clear answer]\n\n"
                "[Additional context]\n\n"
                "Have more questions? Drop them below! 👇",
                false,
                false,
                ""
            }
        };
    }

    std::optional<ContentTemplate> getTemplate(const std::string& id) const {
        for (const auto& t : getTemplates()) {
            if (t.id == id) return t;
        }
        return std::nullopt;
    }

    std::vector<ContentTemplate> getTemplatesForPlatform(Platform platform) const {
        std::vector<ContentTemplate> result;
        for (const auto& t : getTemplates()) {
            for (const auto& p : t.suitableFor) {
                if (p == platform) {
                    result.push_back(t);
                    break;
                }
            }
        }
        return result;
    }
};

// ============================================================================
// Content Formatter
// ============================================================================

class ContentFormatter {
public:
    // Format content for specific platform
    struct FormattedContent {
        std::string text;
        int characterCount = 0;
        bool withinLimits = true;
        std::vector<std::string> warnings;
        std::string hashtags;
    };

    FormattedContent formatForPlatform(const ContentItem& item, Platform platform) const {
        FormattedContent result;
        auto spec = PlatformSpecs::getSpec(platform);

        // Build platform-specific version
        std::string text;

        switch (platform) {
            case Platform::Twitter:
                text = formatForTwitter(item);
                break;
            case Platform::Instagram:
                text = formatForInstagram(item);
                break;
            case Platform::LinkedIn:
                text = formatForLinkedIn(item);
                break;
            case Platform::Blog:
            case Platform::Website:
                text = formatForBlog(item);
                break;
            default:
                text = item.headline + "\n\n" + item.body;
                break;
        }

        result.text = text;
        result.characterCount = text.length();
        result.withinLimits = (result.characterCount <= spec.maxBodyLength);

        if (!result.withinLimits) {
            result.warnings.push_back(
                "Content exceeds " + spec.displayName + " limit of " +
                std::to_string(spec.maxBodyLength) + " characters");
        }

        // Format hashtags
        if (!item.hashtags.empty() && spec.maxHashtags > 0) {
            for (size_t i = 0; i < item.hashtags.size() &&
                 i < static_cast<size_t>(spec.maxHashtags); ++i) {
                if (i > 0) result.hashtags += " ";
                result.hashtags += "#" + item.hashtags[i];
            }
        }

        return result;
    }

private:
    std::string formatForTwitter(const ContentItem& item) const {
        std::string text = item.headline;
        if (!item.callToAction.empty()) {
            text += "\n\n" + item.callToAction;
        }
        // Leave room for hashtags
        return text;
    }

    std::string formatForInstagram(const ContentItem& item) const {
        std::string text = item.headline + "\n\n";
        text += item.body + "\n\n";
        if (!item.callToAction.empty()) {
            text += item.callToAction + "\n\n";
        }
        if (item.disclaimerIncluded) {
            text += "---\n" + item.disclaimer;
        }
        return text;
    }

    std::string formatForLinkedIn(const ContentItem& item) const {
        std::string text = item.headline + "\n\n";
        text += item.body + "\n\n";
        if (!item.callToAction.empty()) {
            text += item.callToAction + "\n\n";
        }
        if (item.disclaimerIncluded) {
            text += "—\n" + item.disclaimer;
        }
        return text;
    }

    std::string formatForBlog(const ContentItem& item) const {
        std::string html = "<h1>" + item.headline + "</h1>\n\n";
        html += "<article>\n" + item.body + "\n</article>\n\n";
        if (item.disclaimerIncluded) {
            html += "<aside class=\"disclaimer\">\n" + item.disclaimer + "\n</aside>";
        }
        return html;
    }
};

// ============================================================================
// Content Calendar
// ============================================================================

struct CalendarEntry {
    std::string contentId;
    std::string scheduledDate;
    std::string scheduledTime;
    Platform platform;
    ContentStatus status = ContentStatus::Scheduled;
    std::string notes;
};

class ContentCalendar {
public:
    void scheduleContent(const CalendarEntry& entry) {
        entries_.push_back(entry);
        sortByDate();
    }

    std::vector<CalendarEntry> getEntriesForDate(const std::string& date) const {
        std::vector<CalendarEntry> result;
        for (const auto& entry : entries_) {
            if (entry.scheduledDate == date) {
                result.push_back(entry);
            }
        }
        return result;
    }

    std::vector<CalendarEntry> getEntriesForPlatform(Platform platform) const {
        std::vector<CalendarEntry> result;
        for (const auto& entry : entries_) {
            if (entry.platform == platform) {
                result.push_back(entry);
            }
        }
        return result;
    }

    std::vector<CalendarEntry> getUpcoming(int days = 7) const {
        // Return entries for next N days
        // (simplified - real implementation would use proper date handling)
        std::vector<CalendarEntry> result;
        for (const auto& entry : entries_) {
            if (entry.status == ContentStatus::Scheduled) {
                result.push_back(entry);
            }
        }
        return result;
    }

    void markPublished(const std::string& contentId) {
        for (auto& entry : entries_) {
            if (entry.contentId == contentId) {
                entry.status = ContentStatus::Published;
            }
        }
    }

private:
    void sortByDate() {
        std::sort(entries_.begin(), entries_.end(),
            [](const CalendarEntry& a, const CalendarEntry& b) {
                return a.scheduledDate < b.scheduledDate;
            });
    }

    std::vector<CalendarEntry> entries_;
};

// ============================================================================
// Main Content Manager
// ============================================================================

class EchoelContentManager {
public:
    /*
     * IMPORTANT: This is an organizational tool only.
     * - User creates ALL content
     * - Tool helps format, organize, and check compliance
     * - 100% of content and credits belong to user
     * - No auto-generation
     */

    EchoelContentManager() = default;

    // ===== Content Management =====

    void addContent(const ContentItem& item) {
        content_[item.id] = item;
    }

    std::optional<ContentItem> getContent(const std::string& id) const {
        auto it = content_.find(id);
        if (it != content_.end()) {
            return it->second;
        }
        return std::nullopt;
    }

    void updateContent(const ContentItem& item) {
        content_[item.id] = item;
    }

    void deleteContent(const std::string& id) {
        content_.erase(id);
    }

    std::vector<ContentItem> getAllContent() const {
        std::vector<ContentItem> result;
        for (const auto& [id, item] : content_) {
            result.push_back(item);
        }
        return result;
    }

    std::vector<ContentItem> getContentByStatus(ContentStatus status) const {
        std::vector<ContentItem> result;
        for (const auto& [id, item] : content_) {
            if (item.status == status) {
                result.push_back(item);
            }
        }
        return result;
    }

    // ===== Templates =====

    std::vector<ContentTemplate> getTemplates() const {
        return templateLibrary_.getTemplates();
    }

    std::vector<ContentTemplate> getTemplatesForPlatform(Platform platform) const {
        return templateLibrary_.getTemplatesForPlatform(platform);
    }

    // ===== Platform Formatting =====

    ContentFormatter::FormattedContent formatForPlatform(
        const std::string& contentId, Platform platform) const {

        auto item = getContent(contentId);
        if (item) {
            return formatter_.formatForPlatform(*item, platform);
        }
        return {};
    }

    PlatformSpec getPlatformSpec(Platform platform) const {
        return PlatformSpecs::getSpec(platform);
    }

    // ===== Calendar =====

    void scheduleContent(const CalendarEntry& entry) {
        calendar_.scheduleContent(entry);
    }

    std::vector<CalendarEntry> getUpcomingContent(int days = 7) const {
        return calendar_.getUpcoming(days);
    }

    std::vector<CalendarEntry> getContentForDate(const std::string& date) const {
        return calendar_.getEntriesForDate(date);
    }

    // ===== Hashtag Suggestions =====

    struct HashtagSuggestion {
        std::string hashtag;
        std::string category;
        int estimatedReach;  // Relative, not absolute
        std::string note;
    };

    std::vector<HashtagSuggestion> suggestHashtags(const std::string& topic,
                                                    Platform platform) const {
        std::vector<HashtagSuggestion> suggestions;

        // These are common categories - user should research current trends
        if (topic.find("biofeedback") != std::string::npos ||
            topic.find("relaxation") != std::string::npos) {
            suggestions.push_back({"wellness", "general", 3, "Broad reach"});
            suggestions.push_back({"mindfulness", "practice", 2, "Engaged community"});
            suggestions.push_back({"selfcare", "lifestyle", 3, "Popular"});
            suggestions.push_back({"relaxation", "specific", 1, "Targeted"});
        }

        if (topic.find("music") != std::string::npos ||
            topic.find("audio") != std::string::npos) {
            suggestions.push_back({"musictherapy", "specific", 1, "Niche but engaged"});
            suggestions.push_back({"soundhealing", "specific", 1, "Growing interest"});
            suggestions.push_back({"ambientmusic", "genre", 2, "Music lovers"});
        }

        // Note for user
        if (!suggestions.empty()) {
            suggestions.push_back({
                "",
                "note",
                0,
                "Research current trending hashtags for your specific audience"
            });
        }

        return suggestions;
    }

    // ===== Content Checklist =====

    struct ContentChecklist {
        std::vector<std::pair<std::string, bool>> items;
        int completedCount = 0;
        int totalCount = 0;
        bool readyToPublish = false;
    };

    ContentChecklist getPublishChecklist(const std::string& contentId,
                                          Platform platform) const {
        ContentChecklist checklist;
        auto item = getContent(contentId);
        auto spec = PlatformSpecs::getSpec(platform);

        if (!item) return checklist;

        // Content checks
        checklist.items.push_back({
            "Headline/title is clear and engaging",
            !item->headline.empty()
        });

        checklist.items.push_back({
            "Body content is complete",
            !item->body.empty()
        });

        checklist.items.push_back({
            "Content within character limit",
            item->body.length() <= static_cast<size_t>(spec.maxBodyLength)
        });

        // Compliance checks
        checklist.items.push_back({
            "Compliance checked (no health claims)",
            item->complianceChecked
        });

        checklist.items.push_back({
            "No compliance issues",
            item->complianceIssues.empty()
        });

        if (item->type == ContentType::Research) {
            checklist.items.push_back({
                "Sources cited",
                !item->sourceIds.empty()
            });

            checklist.items.push_back({
                "Disclaimer included",
                item->disclaimerIncluded
            });
        }

        // Media checks
        checklist.items.push_back({
            "Images/media attached (if needed)",
            !item->images.empty() || item->type == ContentType::Educational
        });

        // Calculate completion
        for (const auto& [text, checked] : checklist.items) {
            checklist.totalCount++;
            if (checked) checklist.completedCount++;
        }

        checklist.readyToPublish =
            (checklist.completedCount == checklist.totalCount);

        return checklist;
    }

    // ===== Export =====

    std::string exportContentPlan(const std::string& startDate,
                                   const std::string& endDate) const {
        std::string output = "Content Plan\n";
        output += "============\n\n";
        output += "Period: " + startDate + " to " + endDate + "\n\n";

        for (const auto& entry : calendar_.getUpcoming(30)) {
            output += entry.scheduledDate + " - ";
            auto item = getContent(entry.contentId);
            if (item) {
                output += item->title;
            }
            output += " [" + PlatformSpecs::getSpec(entry.platform).displayName + "]\n";
        }

        return output;
    }

private:
    std::map<std::string, ContentItem> content_;
    TemplateLibrary templateLibrary_;
    ContentFormatter formatter_;
    ContentCalendar calendar_;
};

} // namespace Content
} // namespace Echoel
