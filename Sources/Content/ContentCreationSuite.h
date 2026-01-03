#pragma once

#include <JuceHeader.h>
#include <vector>
#include <map>
#include <memory>
#include <string>

/**
 * ContentCreationSuite - Unified Content Production System
 *
 * Integrates all content types in one cohesive workflow:
 * - Blog/Article Creation with audio embedding
 * - Recipe Templates (Essential Oils, Food, Wellness)
 * - Album Cover / Visual Design Generator
 * - Social Media Asset Creator
 * - Songwriting & Lyrics Tools
 * - Multi-format Export (Image, Video, Audio, Text)
 *
 * Connected to:
 * - VideoEditingEngine (video content)
 * - PodcastProductionSuite (audio content)
 * - SocialMediaManager (distribution)
 * - VocalSuite (voice content)
 * - LSTMComposer (AI assistance)
 *
 * Format Support:
 * - Instagram (1080x1080, 1080x1920)
 * - TikTok/Reels (1080x1920)
 * - YouTube (1920x1080, 2560x1440)
 * - Twitter/X (1200x675)
 * - LinkedIn (1200x627)
 * - Pinterest (1000x1500)
 * - Blog Featured (1200x630)
 * - Album Cover (3000x3000)
 */

namespace Echoelmusic {
namespace Content {

//==============================================================================
// Content Types
//==============================================================================

enum class ContentType
{
    BlogPost,
    Recipe,
    AlbumCover,
    SocialPost,
    Lyrics,
    Podcast,
    Video,
    Newsletter
};

enum class RecipeCategory
{
    // Essential Oils
    EssentialOil_Diffuser,
    EssentialOil_Topical,
    EssentialOil_Roller,
    EssentialOil_Spray,
    EssentialOil_Bath,

    // Food & Drink
    Food_Main,
    Food_Dessert,
    Food_Smoothie,
    Food_Snack,
    Food_Sauce,

    // Wellness
    Wellness_Meditation,
    Wellness_Yoga,
    Wellness_Breathwork,
    Wellness_Sleep,
    Wellness_Energy
};

enum class VisualFormat
{
    Instagram_Square,      // 1080x1080
    Instagram_Portrait,    // 1080x1350
    Instagram_Story,       // 1080x1920
    TikTok_Video,         // 1080x1920
    YouTube_Thumbnail,     // 1280x720
    YouTube_Banner,        // 2560x1440
    Twitter_Post,          // 1200x675
    Twitter_Header,        // 1500x500
    LinkedIn_Post,         // 1200x627
    Pinterest_Pin,         // 1000x1500
    Facebook_Post,         // 1200x630
    Album_Cover,           // 3000x3000
    Blog_Featured,         // 1200x630
    Podcast_Cover,         // 3000x3000
    Email_Header           // 600x200
};

//==============================================================================
// Blog/Article System
//==============================================================================

struct BlogPost
{
    std::string title;
    std::string subtitle;
    std::string author;
    std::string content;  // Markdown supported
    std::vector<std::string> tags;
    std::string category;
    std::string featuredImagePath;
    std::string audioEmbedPath;  // Optional podcast/audio
    std::string videoEmbedPath;  // Optional video
    std::string seoDescription;
    std::string seoKeywords;
    juce::Time publishDate;
    bool isDraft = true;

    // Export formats
    std::string exportToHTML() const
    {
        std::string html = "<!DOCTYPE html><html><head><title>" + title + "</title>";
        html += "<meta name=\"description\" content=\"" + seoDescription + "\">";
        html += "<meta name=\"keywords\" content=\"" + seoKeywords + "\">";
        html += "</head><body>";
        html += "<article><h1>" + title + "</h1>";
        html += "<h2>" + subtitle + "</h2>";
        html += "<p class=\"author\">By " + author + "</p>";
        html += "<div class=\"content\">" + content + "</div>";
        html += "</article></body></html>";
        return html;
    }

    std::string exportToMarkdown() const
    {
        std::string md = "# " + title + "\n\n";
        md += "## " + subtitle + "\n\n";
        md += "*By " + author + "*\n\n";
        md += content + "\n\n";
        md += "---\nTags: ";
        for (const auto& tag : tags)
            md += "#" + tag + " ";
        return md;
    }
};

//==============================================================================
// Recipe System
//==============================================================================

struct Ingredient
{
    std::string name;
    float amount;
    std::string unit;
    bool isOptional = false;
    std::string notes;
};

struct RecipeStep
{
    int stepNumber;
    std::string instruction;
    int durationMinutes = 0;
    std::string mediaPath;  // Image or video for step
    std::vector<std::string> tips;
};

struct Recipe
{
    std::string title;
    std::string description;
    RecipeCategory category;
    std::vector<Ingredient> ingredients;
    std::vector<RecipeStep> steps;
    int prepTimeMinutes = 0;
    int totalTimeMinutes = 0;
    int servings = 1;
    std::string difficulty;  // Easy, Medium, Hard
    std::vector<std::string> tags;
    std::string imagePath;
    std::string videoPath;

    // Wellness-specific
    std::string benefits;
    std::string cautions;
    std::string chakra;           // For essential oil recipes
    std::string emotionalEffect;  // Calming, Energizing, etc.
    float frequencyHz = 0.0f;     // Binaural frequency pairing

    std::string exportToMarkdown() const
    {
        std::string md = "# " + title + "\n\n";
        md += description + "\n\n";
        md += "**Prep Time:** " + std::to_string(prepTimeMinutes) + " min\n";
        md += "**Total Time:** " + std::to_string(totalTimeMinutes) + " min\n";
        md += "**Servings:** " + std::to_string(servings) + "\n";
        md += "**Difficulty:** " + difficulty + "\n\n";

        md += "## Ingredients\n\n";
        for (const auto& ing : ingredients)
        {
            md += "- " + std::to_string(ing.amount) + " " + ing.unit + " " + ing.name;
            if (ing.isOptional) md += " *(optional)*";
            md += "\n";
        }

        md += "\n## Instructions\n\n";
        for (const auto& step : steps)
        {
            md += std::to_string(step.stepNumber) + ". " + step.instruction + "\n";
        }

        if (!benefits.empty())
            md += "\n## Benefits\n" + benefits + "\n";

        if (!cautions.empty())
            md += "\n## Cautions\n" + cautions + "\n";

        return md;
    }
};

//==============================================================================
// Visual Design Generator
//==============================================================================

struct DesignTemplate
{
    std::string name;
    VisualFormat format;
    juce::Colour backgroundColor;
    juce::Colour primaryColor;
    juce::Colour secondaryColor;
    juce::Colour textColor;
    std::string fontFamily;
    float fontSize = 24.0f;
    std::string layoutStyle;  // Centered, Left, Right, Grid
};

class VisualDesigner
{
public:
    static std::pair<int, int> getDimensions(VisualFormat format)
    {
        switch (format)
        {
            case VisualFormat::Instagram_Square:   return {1080, 1080};
            case VisualFormat::Instagram_Portrait: return {1080, 1350};
            case VisualFormat::Instagram_Story:    return {1080, 1920};
            case VisualFormat::TikTok_Video:       return {1080, 1920};
            case VisualFormat::YouTube_Thumbnail:  return {1280, 720};
            case VisualFormat::YouTube_Banner:     return {2560, 1440};
            case VisualFormat::Twitter_Post:       return {1200, 675};
            case VisualFormat::Twitter_Header:     return {1500, 500};
            case VisualFormat::LinkedIn_Post:      return {1200, 627};
            case VisualFormat::Pinterest_Pin:      return {1000, 1500};
            case VisualFormat::Facebook_Post:      return {1200, 630};
            case VisualFormat::Album_Cover:        return {3000, 3000};
            case VisualFormat::Blog_Featured:      return {1200, 630};
            case VisualFormat::Podcast_Cover:      return {3000, 3000};
            case VisualFormat::Email_Header:       return {600, 200};
            default:                               return {1080, 1080};
        }
    }

    static std::vector<DesignTemplate> getAlbumCoverTemplates()
    {
        return {
            {"Minimalist", VisualFormat::Album_Cover,
             juce::Colours::white, juce::Colours::black, juce::Colours::grey,
             juce::Colours::black, "Helvetica", 72.0f, "Centered"},

            {"Gradient Waves", VisualFormat::Album_Cover,
             juce::Colour(0xFF1a1a2e), juce::Colour(0xFF16213e), juce::Colour(0xFF0f3460),
             juce::Colours::white, "Montserrat", 64.0f, "Centered"},

            {"Vintage Vinyl", VisualFormat::Album_Cover,
             juce::Colour(0xFFf4e4ba), juce::Colour(0xFF8b4513), juce::Colour(0xFFcd853f),
             juce::Colour(0xFF2f1810), "Georgia", 56.0f, "Centered"},

            {"Neon Synthwave", VisualFormat::Album_Cover,
             juce::Colour(0xFF0d0221), juce::Colour(0xFFff00ff), juce::Colour(0xFF00ffff),
             juce::Colours::white, "Orbitron", 60.0f, "Centered"},

            {"Nature Organic", VisualFormat::Album_Cover,
             juce::Colour(0xFF2d5a27), juce::Colour(0xFF8fbc8f), juce::Colour(0xFFf5f5dc),
             juce::Colours::white, "Lora", 52.0f, "Left"}
        };
    }

    static std::vector<DesignTemplate> getSocialMediaTemplates()
    {
        return {
            {"Bold Statement", VisualFormat::Instagram_Square,
             juce::Colour(0xFFff6b6b), juce::Colours::white, juce::Colour(0xFFffd93d),
             juce::Colours::white, "Impact", 48.0f, "Centered"},

            {"Clean Professional", VisualFormat::LinkedIn_Post,
             juce::Colours::white, juce::Colour(0xFF0077b5), juce::Colour(0xFF00a0dc),
             juce::Colour(0xFF333333), "Roboto", 36.0f, "Left"},

            {"Story Gradient", VisualFormat::Instagram_Story,
             juce::Colour(0xFFff7e5f), juce::Colour(0xFFfeb47b), juce::Colour(0xFFff6b6b),
             juce::Colours::white, "Poppins", 42.0f, "Centered"}
        };
    }
};

//==============================================================================
// Songwriting Tools
//==============================================================================

struct LyricSection
{
    std::string type;  // Verse, Chorus, Bridge, Pre-Chorus, Outro, Intro
    std::string content;
    std::string chords;
    int barCount = 4;
    std::string notes;
};

struct Song
{
    std::string title;
    std::string artist;
    std::string key;
    int bpm = 120;
    std::string timeSignature = "4/4";
    std::string genre;
    std::string mood;
    std::vector<LyricSection> sections;
    std::string structure;  // e.g., "ABABCB" for Verse-Chorus-Verse-Chorus-Bridge-Chorus

    std::string exportToChordSheet() const
    {
        std::string sheet = title + " - " + artist + "\n";
        sheet += "Key: " + key + " | BPM: " + std::to_string(bpm) + " | Time: " + timeSignature + "\n\n";

        for (const auto& section : sections)
        {
            sheet += "[" + section.type + "]\n";
            if (!section.chords.empty())
                sheet += section.chords + "\n";
            sheet += section.content + "\n\n";
        }

        return sheet;
    }

    std::string exportToLyrics() const
    {
        std::string lyrics = title + "\n" + artist + "\n\n";

        for (const auto& section : sections)
        {
            lyrics += "[" + section.type + "]\n";
            lyrics += section.content + "\n\n";
        }

        return lyrics;
    }
};

//==============================================================================
// Content Creation Suite - Main Class
//==============================================================================

class ContentCreationSuite
{
public:
    //==========================================================================
    // Initialization
    //==========================================================================

    ContentCreationSuite()
    {
        initializeTemplates();
    }

    //==========================================================================
    // Blog Management
    //==========================================================================

    BlogPost createBlogPost(const std::string& title, const std::string& content)
    {
        BlogPost post;
        post.title = title;
        post.content = content;
        post.publishDate = juce::Time::getCurrentTime();
        blogPosts.push_back(post);
        return post;
    }

    void saveBlogPost(const BlogPost& post, const std::string& path, const std::string& format)
    {
        juce::File file(path);
        if (format == "html")
            file.replaceWithText(post.exportToHTML());
        else if (format == "md")
            file.replaceWithText(post.exportToMarkdown());
    }

    //==========================================================================
    // Recipe Management
    //==========================================================================

    Recipe createRecipe(const std::string& title, RecipeCategory category)
    {
        Recipe recipe;
        recipe.title = title;
        recipe.category = category;

        // Auto-set defaults based on category
        switch (category)
        {
            case RecipeCategory::EssentialOil_Diffuser:
                recipe.difficulty = "Easy";
                recipe.prepTimeMinutes = 2;
                recipe.totalTimeMinutes = 2;
                break;
            case RecipeCategory::Food_Main:
                recipe.difficulty = "Medium";
                recipe.prepTimeMinutes = 15;
                recipe.totalTimeMinutes = 45;
                break;
            case RecipeCategory::Wellness_Meditation:
                recipe.difficulty = "Easy";
                recipe.prepTimeMinutes = 0;
                recipe.totalTimeMinutes = 15;
                break;
            default:
                recipe.difficulty = "Easy";
        }

        recipes.push_back(recipe);
        return recipe;
    }

    void addIngredient(Recipe& recipe, const std::string& name, float amount,
                       const std::string& unit, bool optional = false)
    {
        Ingredient ing;
        ing.name = name;
        ing.amount = amount;
        ing.unit = unit;
        ing.isOptional = optional;
        recipe.ingredients.push_back(ing);
    }

    void addStep(Recipe& recipe, const std::string& instruction, int durationMinutes = 0)
    {
        RecipeStep step;
        step.stepNumber = static_cast<int>(recipe.steps.size()) + 1;
        step.instruction = instruction;
        step.durationMinutes = durationMinutes;
        recipe.steps.push_back(step);
    }

    //==========================================================================
    // Essential Oil Recipe Templates
    //==========================================================================

    Recipe createEssentialOilBlend(const std::string& name, const std::string& purpose)
    {
        Recipe recipe = createRecipe(name, RecipeCategory::EssentialOil_Diffuser);
        recipe.benefits = purpose;

        // Common diffuser instructions
        addStep(recipe, "Add water to your diffuser up to the fill line", 1);
        addStep(recipe, "Add the essential oils as listed above", 1);
        addStep(recipe, "Turn on diffuser and enjoy for 30-60 minutes", 0);

        return recipe;
    }

    std::vector<Recipe> getEssentialOilTemplates()
    {
        std::vector<Recipe> templates;

        // Calming Blend
        Recipe calm = createEssentialOilBlend("Peaceful Dreams", "Promotes relaxation and restful sleep");
        calm.chakra = "Crown, Third Eye";
        calm.emotionalEffect = "Calming, Grounding";
        calm.frequencyHz = 432.0f;
        addIngredient(calm, "Lavender", 3, "drops");
        addIngredient(calm, "Chamomile", 2, "drops");
        addIngredient(calm, "Cedarwood", 2, "drops");
        templates.push_back(calm);

        // Focus Blend
        Recipe focus = createEssentialOilBlend("Mind Clarity", "Enhances focus and mental clarity");
        focus.chakra = "Third Eye";
        focus.emotionalEffect = "Focusing, Clarifying";
        focus.frequencyHz = 528.0f;
        addIngredient(focus, "Rosemary", 3, "drops");
        addIngredient(focus, "Peppermint", 2, "drops");
        addIngredient(focus, "Lemon", 2, "drops");
        templates.push_back(focus);

        // Energy Blend
        Recipe energy = createEssentialOilBlend("Morning Sunrise", "Uplifting and energizing");
        energy.chakra = "Solar Plexus, Sacral";
        energy.emotionalEffect = "Energizing, Uplifting";
        energy.frequencyHz = 639.0f;
        addIngredient(energy, "Orange", 3, "drops");
        addIngredient(energy, "Grapefruit", 2, "drops");
        addIngredient(energy, "Peppermint", 1, "drops");
        templates.push_back(energy);

        return templates;
    }

    //==========================================================================
    // Songwriting
    //==========================================================================

    Song createSong(const std::string& title, const std::string& key, int bpm)
    {
        Song song;
        song.title = title;
        song.key = key;
        song.bpm = bpm;
        songs.push_back(song);
        return song;
    }

    void addLyricSection(Song& song, const std::string& type, const std::string& lyrics,
                         const std::string& chords = "")
    {
        LyricSection section;
        section.type = type;
        section.content = lyrics;
        section.chords = chords;
        song.sections.push_back(section);

        // Auto-update structure
        if (type == "Verse") song.structure += "A";
        else if (type == "Chorus") song.structure += "B";
        else if (type == "Bridge") song.structure += "C";
        else if (type == "Pre-Chorus") song.structure += "P";
    }

    //==========================================================================
    // Visual Design
    //==========================================================================

    DesignTemplate getTemplate(const std::string& name)
    {
        for (const auto& t : designTemplates)
            if (t.name == name) return t;
        return designTemplates[0];  // Default
    }

    std::vector<DesignTemplate> getTemplatesForFormat(VisualFormat format)
    {
        std::vector<DesignTemplate> matching;
        for (const auto& t : designTemplates)
            if (t.format == format) matching.push_back(t);
        return matching;
    }

    std::pair<int, int> getFormatDimensions(VisualFormat format)
    {
        return VisualDesigner::getDimensions(format);
    }

    //==========================================================================
    // Multi-Format Export
    //==========================================================================

    struct ExportSettings
    {
        VisualFormat visualFormat = VisualFormat::Instagram_Square;
        std::string audioFormat = "mp3";
        std::string videoFormat = "mp4";
        int audioQuality = 320;  // kbps
        int videoQuality = 1080;
        bool includeAudio = false;
        bool includeVideo = false;
    };

    void exportContent(ContentType type, const std::string& outputPath, const ExportSettings& settings)
    {
        auto dims = getFormatDimensions(settings.visualFormat);

        // Export logic would integrate with:
        // - VideoEditingEngine for video export
        // - PodcastProductionSuite for audio export
        // - VisualDesigner for image export

        juce::File outDir(outputPath);
        if (!outDir.exists())
            outDir.createDirectory();

        // Create manifest
        juce::File manifest = outDir.getChildFile("manifest.json");
        std::string json = "{\n";
        json += "  \"type\": \"" + contentTypeToString(type) + "\",\n";
        json += "  \"width\": " + std::to_string(dims.first) + ",\n";
        json += "  \"height\": " + std::to_string(dims.second) + ",\n";
        json += "  \"audioFormat\": \"" + settings.audioFormat + "\",\n";
        json += "  \"videoFormat\": \"" + settings.videoFormat + "\"\n";
        json += "}";
        manifest.replaceWithText(json);
    }

    //==========================================================================
    // AI Integration Hooks
    //==========================================================================

    // These would connect to LSTMComposer and other AI systems
    std::string generateBlogTitle(const std::string& topic) { return ""; }
    std::string generateLyrics(const std::string& theme, const std::string& mood) { return ""; }
    std::vector<std::string> suggestHashtags(const std::string& content) { return {}; }

    //==========================================================================
    // Getters
    //==========================================================================

    const std::vector<BlogPost>& getBlogPosts() const { return blogPosts; }
    const std::vector<Recipe>& getRecipes() const { return recipes; }
    const std::vector<Song>& getSongs() const { return songs; }

private:
    std::vector<BlogPost> blogPosts;
    std::vector<Recipe> recipes;
    std::vector<Song> songs;
    std::vector<DesignTemplate> designTemplates;

    void initializeTemplates()
    {
        auto albumTemplates = VisualDesigner::getAlbumCoverTemplates();
        auto socialTemplates = VisualDesigner::getSocialMediaTemplates();

        designTemplates.insert(designTemplates.end(), albumTemplates.begin(), albumTemplates.end());
        designTemplates.insert(designTemplates.end(), socialTemplates.begin(), socialTemplates.end());
    }

    std::string contentTypeToString(ContentType type)
    {
        switch (type)
        {
            case ContentType::BlogPost: return "blog";
            case ContentType::Recipe: return "recipe";
            case ContentType::AlbumCover: return "album_cover";
            case ContentType::SocialPost: return "social";
            case ContentType::Lyrics: return "lyrics";
            case ContentType::Podcast: return "podcast";
            case ContentType::Video: return "video";
            case ContentType::Newsletter: return "newsletter";
            default: return "unknown";
        }
    }

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ContentCreationSuite)
};

} // namespace Content
} // namespace Echoelmusic
