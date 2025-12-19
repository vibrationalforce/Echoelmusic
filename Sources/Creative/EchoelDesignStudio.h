#pragma once

#include <JuceHeader.h>
#include <vector>
#include <map>
#include <memory>

/**
 * EchoelDesignStudio - "Canva in die Tasche"
 *
 * Professional design studio for musicians - Canva-level capabilities
 * directly integrated into music production workflow.
 *
 * FEATURES:
 * ========================================================================
 *
 * 🎨 TEMPLATES (300+ Professional Designs)
 *    - Album Covers (Square, Digital, Vinyl, CD)
 *    - Social Media (Instagram, Facebook, Twitter, TikTok, YouTube)
 *    - Promotional Materials (Posters, Flyers, Event Graphics)
 *    - Merchandise (T-shirts, Hoodies, Stickers)
 *    - Streaming Platforms (Spotify Canvas, Apple Music, SoundCloud)
 *    - Music Videos (Lyrics videos, Visualizers, Thumbnails)
 *
 * 🤖 AI-POWERED DESIGN
 *    - Smart Layout Generation (Golden ratio, Rule of thirds)
 *    - AI Color Palette Extraction (from audio spectrum, album mood)
 *    - Intelligent Typography (Font pairing, hierarchy, readability)
 *    - Auto-Resize (One design → all social media sizes)
 *    - Style Transfer (Apply artistic styles)
 *    - Content-Aware Fill
 *
 * 🎵 AUDIO-REACTIVE DESIGN
 *    - Waveform-Based Layouts
 *    - Spectrum Color Palettes
 *    - Beat-Synced Animations
 *    - Frequency-Mapped Typography
 *
 * 💎 ASSET LIBRARY
 *    - 10,000+ Icons (Music, Abstract, Geometric)
 *    - 500+ Fonts (Licensed for commercial use)
 *    - 1,000+ Textures (Grunge, Vintage, Modern)
 *    - Shape Library (Geometric, Organic, Abstract)
 *    - Stock Photos (Music-themed, Royalty-free)
 *
 * 🔧 BRAND KIT
 *    - Save Brand Colors
 *    - Typography Presets
 *    - Logo Management
 *    - Consistent Design System
 *
 * 📤 EXPORT FORMATS
 *    - Raster: PNG, JPG, WebP, TIFF
 *    - Vector: SVG, PDF, EPS
 *    - Video: MP4, MOV, GIF
 *    - Print: 300 DPI, CMYK
 *    - Platform-Optimized: Instagram (1080x1080), Twitter (1200x675), etc.
 *
 * 🌐 COLLABORATION
 *    - Share Design Links
 *    - Team Folders
 *    - Comment System
 *    - Version History
 *
 * COMPETITIVE ADVANTAGE OVER CANVA:
 * ========================================================================
 * ✅ Audio Integration - Designs react to music
 * ✅ Bio-Reactive Colors - Match listener's emotional state
 * ✅ Native Plugin - No browser needed
 * ✅ Real-time Rendering - GPU-accelerated
 * ✅ Musician-Focused - Templates designed by musicians for musicians
 * ✅ No Subscription - One-time purchase
 * ✅ Offline-First - Full functionality without internet
 * ✅ Professional Quality - Broadcast-ready output
 */

class EchoelDesignStudio
{
public:
    //==========================================================================
    // SECURITY CONSTANTS (DoS Protection, Resource Limits)
    //==========================================================================

    // Image constraints (prevent DoS attacks via resource exhaustion)
    static constexpr int MAX_IMAGE_WIDTH = 10000;       // 10K pixels max width
    static constexpr int MAX_IMAGE_HEIGHT = 10000;      // 10K pixels max height
    static constexpr int MAX_PIXELS = 25000000;         // 25 megapixels (5000x5000)
    static constexpr int64_t MAX_FILE_SIZE_BYTES = 100LL * 1024 * 1024;  // 100 MB per file

    // Library constraints (prevent unbounded growth)
    static constexpr size_t MAX_ASSETS = 10000;         // Asset library limit
    static constexpr size_t MAX_ELEMENTS = 1000;        // Elements per project limit
    static constexpr size_t MAX_TEMPLATES = 500;        // Template cache limit

    // Performance tuning
    static constexpr int TARGET_FPS = 60;               // Target frame rate
    static constexpr int GPU_THRESHOLD_PIXELS = 4000000; // 4MP (2000x2000) - switch to GPU

    //==========================================================================
    // ERROR HANDLING (Professional Error Management)
    //==========================================================================

    /**
     * Error codes for professional error handling and logging
     */
    enum class ErrorCode
    {
        Success = 0,

        // File errors (1xx)
        FileNotFound = 100,
        FileTooBig = 101,
        FileEmpty = 102,
        FileReadError = 103,
        FileWriteError = 104,

        // Resource errors (2xx)
        AssetLibraryFull = 200,
        ElementLimitReached = 201,
        TemplateCacheFull = 202,

        // Validation errors (3xx)
        ImageTooLarge = 300,
        TooManyPixels = 301,
        OutOfMemory = 302,
        InvalidDimensions = 303,

        // Project errors (4xx)
        ProjectNotFound = 400,
        ProjectCorrupted = 401,
        TemplateNotFound = 402,

        // Unknown/Other
        UnknownError = 999
    };

    /**
     * Convert error code to human-readable message
     */
    static juce::String getErrorMessage(ErrorCode code);

    //==========================================================================
    // TEMPLATE SYSTEM
    //==========================================================================

    /**
     * Template categories for musicians
     */
    enum class TemplateCategory
    {
        AlbumCover,          // Album/EP/Single artwork
        SocialMedia,         // Instagram, Facebook, Twitter posts
        YouTubeThumbnail,    // Video thumbnails
        SpotifyCanvas,       // Vertical looping video (1080x1920)
        EventPoster,         // Concert/festival posters
        Merchandise,         // T-shirt, hoodie graphics
        LyricsVideo,         // Lyric video backgrounds
        Visualizer,          // Audio visualizer templates
        Playlist,            // Playlist cover art
        PressKit,            // EPK/Press materials
        Newsletter,          // Email marketing
        WebsiteBanner,       // Website headers
        Custom               // User-created
    };

    /**
     * Template sizes (optimized for each platform)
     */
    struct TemplateSize
    {
        int width;
        int height;
        juce::String name;           // e.g., "Instagram Post", "Album Cover"
        juce::String platform;       // e.g., "Instagram", "Spotify"
        int dpi = 72;                // 72 for digital, 300 for print

        // Common sizes
        static TemplateSize InstagramPost()      { return {1080, 1080, "Instagram Post", "Instagram", 72}; }
        static TemplateSize InstagramStory()     { return {1080, 1920, "Instagram Story", "Instagram", 72}; }
        static TemplateSize FacebookPost()       { return {1200, 630, "Facebook Post", "Facebook", 72}; }
        static TemplateSize TwitterPost()        { return {1200, 675, "Twitter Post", "Twitter", 72}; }
        static TemplateSize YouTubeThumbnail()   { return {1280, 720, "YouTube Thumbnail", "YouTube", 72}; }
        static TemplateSize AlbumCoverSquare()   { return {3000, 3000, "Album Cover", "Spotify", 300}; }
        static TemplateSize SpotifyCanvas()      { return {1080, 1920, "Spotify Canvas", "Spotify", 72}; }
        static TemplateSize TikTokVideo()        { return {1080, 1920, "TikTok Video", "TikTok", 72}; }
        static TemplateSize Poster18x24()        { return {5400, 7200, "Poster 18x24\"", "Print", 300}; }
    };

    /**
     * Design template
     */
    struct Template
    {
        juce::String id;
        juce::String name;
        TemplateCategory category;
        TemplateSize size;

        // Preview
        juce::Image thumbnail;
        juce::String description;
        std::vector<juce::String> tags;  // "retro", "minimal", "colorful", etc.

        // Design elements
        std::vector<class DesignElement*> elements;

        // Metadata
        juce::String author;
        bool isPremium = false;
        int popularityScore = 0;
    };

    /** Get all available templates */
    std::vector<Template> getTemplates(TemplateCategory category = TemplateCategory::Custom) const;

    /** Search templates */
    std::vector<Template> searchTemplates(const juce::String& query) const;

    /** Create project from template */
    juce::String createProjectFromTemplate(const juce::String& templateID);

    //==========================================================================
    // DESIGN ELEMENTS
    //==========================================================================

    /**
     * Base design element
     */
    class DesignElement
    {
    public:
        enum class Type
        {
            Text,
            Image,
            Shape,
            Icon,
            Line,
            Group,
            Frame,
            AudioWaveform,
            AudioSpectrum,
            BioReactiveShape
        };

        virtual ~DesignElement() = default;
        virtual Type getType() const = 0;
        virtual void render(juce::Graphics& g) const = 0;
        virtual juce::Rectangle<float> getBounds() const = 0;

        // Transform
        juce::Point<float> position {0.0f, 0.0f};
        float rotation = 0.0f;        // Degrees
        float scale = 1.0f;
        float opacity = 1.0f;
        bool visible = true;
        bool locked = false;

        // Layer order
        int zIndex = 0;

        juce::String elementID;
        juce::String name;
    };

    /**
     * Text element with professional typography
     */
    class TextElement : public DesignElement
    {
    public:
        Type getType() const override { return Type::Text; }
        void render(juce::Graphics& g) const override;
        juce::Rectangle<float> getBounds() const override;

        juce::String text = "Text";
        juce::Font font;
        juce::Colour color = juce::Colours::black;

        // Typography
        enum class Alignment { Left, Center, Right, Justify };
        Alignment alignment = Alignment::Left;
        float lineSpacing = 1.2f;
        float letterSpacing = 0.0f;    // em units

        // Effects
        bool hasOutline = false;
        juce::Colour outlineColor = juce::Colours::white;
        float outlineThickness = 2.0f;

        bool hasShadow = false;
        juce::Colour shadowColor = juce::Colours::black;
        juce::Point<float> shadowOffset {2.0f, 2.0f};
        float shadowBlur = 4.0f;

        // Animation (for video exports)
        bool animated = false;
        enum class Animation { None, FadeIn, SlideIn, TypeWriter, Bounce };
        Animation animationType = Animation::None;
    };

    /**
     * Image element
     */
    class ImageElement : public DesignElement
    {
    public:
        Type getType() const override { return Type::Image; }
        void render(juce::Graphics& g) const override;
        juce::Rectangle<float> getBounds() const override;

        juce::Image image;
        juce::Rectangle<float> bounds;

        // Filters
        float brightness = 0.0f;       // -1.0 to 1.0
        float contrast = 0.0f;         // -1.0 to 1.0
        float saturation = 0.0f;       // -1.0 to 1.0
        float blur = 0.0f;             // 0.0 to 10.0

        // Masking
        bool hasMask = false;
        enum class MaskShape { Rectangle, Circle, Custom };
        MaskShape maskShape = MaskShape::Rectangle;
        juce::Path customMask;
    };

    /**
     * Shape element (vector graphics)
     */
    class ShapeElement : public DesignElement
    {
    public:
        Type getType() const override { return Type::Shape; }
        void render(juce::Graphics& g) const override;
        juce::Rectangle<float> getBounds() const override;

        enum class ShapeType
        {
            Rectangle, Circle, Triangle, Polygon, Star,
            Line, Arrow, Curve, Custom
        };

        ShapeType shapeType = ShapeType::Rectangle;
        juce::Path customPath;

        // Fill
        juce::Colour fillColor = juce::Colours::blue;
        bool hasFill = true;

        // Gradient fill
        bool useGradient = false;
        juce::ColourGradient gradient;

        // Stroke
        bool hasStroke = false;
        juce::Colour strokeColor = juce::Colours::black;
        float strokeWidth = 2.0f;

        // Shape-specific
        int numSides = 5;              // For polygon/star
        float cornerRadius = 0.0f;     // For rounded rectangle

        juce::Rectangle<float> bounds;
    };

    /**
     * Audio waveform element (unique to Echoelmusic!)
     */
    class AudioWaveformElement : public DesignElement
    {
    public:
        Type getType() const override { return Type::AudioWaveform; }
        void render(juce::Graphics& g) const override;
        juce::Rectangle<float> getBounds() const override;

        std::vector<float> waveformData;
        juce::Rectangle<float> bounds;

        juce::Colour waveColor = juce::Colours::white;
        juce::Colour backgroundColor = juce::Colours::black;

        enum class Style { Filled, Line, Bars, Circular, Radial };
        Style style = Style::Filled;

        float lineThickness = 2.0f;
        bool mirrorVertical = false;
    };

    /**
     * Audio spectrum element (unique to Echoelmusic!)
     */
    class AudioSpectrumElement : public DesignElement
    {
    public:
        Type getType() const override { return Type::AudioSpectrum; }
        void render(juce::Graphics& g) const override;
        juce::Rectangle<float> getBounds() const override;

        std::vector<float> spectrumData;
        juce::Rectangle<float> bounds;

        enum class Style { Bars, Line, Circular, Radial, Spiral };
        Style style = Style::Bars;

        // Color mapping
        bool useSpectrumColors = true;  // Map frequency to color
        juce::Colour lowColor = juce::Colours::blue;
        juce::Colour midColor = juce::Colours::green;
        juce::Colour highColor = juce::Colours::red;

        int numBands = 64;
        float barSpacing = 2.0f;
    };

    //==========================================================================
    // PROJECT MANAGEMENT
    //==========================================================================

    /**
     * Design project
     */
    struct Project
    {
        juce::String id;
        juce::String name;
        TemplateSize size;
        juce::Colour backgroundColor = juce::Colours::white;

        std::vector<std::unique_ptr<DesignElement>> elements;

        // Metadata
        juce::Time created;
        juce::Time modified;
        juce::String author;

        // Version history
        std::vector<juce::String> versions;  // Snapshot IDs
    };

    /** Create new project */
    juce::String createProject(const juce::String& name, TemplateSize size);

    /** Open existing project */
    bool openProject(const juce::String& projectID);

    /** Save current project */
    bool saveProject();

    /** Export project */
    bool exportProject(const juce::File& outputFile, const juce::String& format);

    /** Get current project */
    Project* getCurrentProject() { return currentProject.get(); }

    //==========================================================================
    // AI DESIGN ASSISTANT
    //==========================================================================

    /**
     * AI-powered design suggestions
     */
    struct DesignSuggestion
    {
        juce::String description;
        std::function<void()> apply;  // Function to apply this suggestion
        float confidenceScore;         // 0.0 to 1.0
    };

    /** Generate AI design suggestions */
    std::vector<DesignSuggestion> getAISuggestions() const;

    /** Auto-generate color palette from audio */
    std::vector<juce::Colour> generatePaletteFromAudio(const juce::AudioBuffer<float>& audio);

    /** Auto-generate layout (Golden ratio, Rule of thirds) */
    void autoLayout();

    /** Smart font pairing */
    std::pair<juce::Font, juce::Font> suggestFontPair(const juce::String& genre) const;

    /** Generate design from text prompt */
    bool generateDesignFromPrompt(const juce::String& prompt);

    //==========================================================================
    // BRAND KIT
    //==========================================================================

    struct BrandKit
    {
        juce::String name;

        // Colors
        std::vector<juce::Colour> brandColors;
        juce::Colour primaryColor;
        juce::Colour secondaryColor;
        juce::Colour accentColor;

        // Typography
        juce::Font primaryFont;
        juce::Font secondaryFont;
        juce::Font headingFont;
        juce::Font bodyFont;

        // Logo
        juce::Image logo;
        juce::Image logoWhite;  // For dark backgrounds
        juce::Image logoBlack;  // For light backgrounds

        // Style guide
        juce::String styleGuide;  // Markdown text
    };

    /** Set brand kit */
    void setBrandKit(const BrandKit& kit);

    /** Get brand kit */
    const BrandKit& getBrandKit() const { return brandKit; }

    /** Apply brand kit to current project */
    void applyBrandKit();

    //==========================================================================
    // ASSET LIBRARY
    //==========================================================================

    enum class AssetType
    {
        Icon,
        Shape,
        Texture,
        Photo,
        Font,
        Template
    };

    struct Asset
    {
        juce::String id;
        juce::String name;
        AssetType type;
        juce::File file;
        juce::Image thumbnail;
        std::vector<juce::String> tags;
        bool isPremium = false;
    };

    /** Search asset library */
    std::vector<Asset> searchAssets(const juce::String& query, AssetType type) const;

    /** Import custom asset */
    juce::String importAsset(const juce::File& file, AssetType type);

    /** Get asset by ID */
    Asset getAsset(const juce::String& assetID) const;

    //==========================================================================
    // AUDIO INTEGRATION (Unique to Echoelmusic!)
    //==========================================================================

    /** Set audio buffer for waveform/spectrum elements */
    void setAudioBuffer(const juce::AudioBuffer<float>& buffer);

    /** Update spectrum data */
    void setSpectrumData(const std::vector<float>& spectrum);

    /** Enable audio-reactive colors */
    void setAudioReactiveColors(bool enabled);

    /** Extract dominant colors from audio spectrum */
    std::vector<juce::Colour> extractColorsFromSpectrum(const std::vector<float>& spectrum);

    //==========================================================================
    // BIO-REACTIVE DESIGN (Unique to Echoelmusic!)
    //==========================================================================

    /** Set bio-data for reactive design */
    void setBioData(float hrv, float coherence);

    /** Enable bio-reactive elements */
    void setBioReactive(bool enabled);

    /** Generate color palette based on emotional state */
    std::vector<juce::Colour> generateEmotionalPalette(float valence, float arousal);

    //==========================================================================
    // RENDERING & EXPORT
    //==========================================================================

    /** Render current design to image */
    juce::Image renderDesign(int width = -1, int height = -1) const;

    /** Export to file */
    enum class ExportFormat
    {
        PNG, JPG, WebP, TIFF,           // Raster
        SVG, PDF, EPS,                   // Vector
        MP4, MOV, GIF                    // Video/Animation
    };

    bool exportDesign(const juce::File& outputFile, ExportFormat format, int quality = 100);

    /** Export to multiple sizes (auto-resize for all platforms) */
    bool exportMultipleSizes(const juce::File& outputDir, const juce::String& baseName);

    //==========================================================================
    // COLLABORATION (Future feature)
    //==========================================================================

    /** Share design link */
    juce::String shareDesign(const juce::String& projectID);

    /** Add comment to design */
    void addComment(const juce::Point<float>& position, const juce::String& comment);

    //==========================================================================
    // Constructor / Destructor
    //==========================================================================

    EchoelDesignStudio();
    ~EchoelDesignStudio() = default;

private:
    //==========================================================================
    // Member Variables
    //==========================================================================

    std::unique_ptr<Project> currentProject;
    std::vector<Template> templates;
    std::vector<Asset> assetLibrary;
    BrandKit brandKit;

    // Audio data
    juce::AudioBuffer<float> audioBuffer;
    std::vector<float> spectrumData;
    bool audioReactiveEnabled = false;

    // Bio data
    float bioHRV = 0.5f;
    float bioCoherence = 0.5f;
    bool bioReactiveEnabled = false;

    //==========================================================================
    // Helper Methods
    //==========================================================================

    void initializeTemplates();
    void initializeAssetLibrary();
    juce::Image renderElement(const DesignElement& element) const;
    juce::Colour getAudioReactiveColor(const juce::Colour& baseColor) const;
    juce::Colour getBioReactiveColor(const juce::Colour& baseColor) const;

    //==========================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (EchoelDesignStudio)
};
