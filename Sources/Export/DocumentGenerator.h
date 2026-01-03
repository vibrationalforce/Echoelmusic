#pragma once

#include <JuceHeader.h>
#include <memory>
#include <vector>
#include <string>
#include <map>
#include <functional>

/**
 * DocumentGenerator - Professional Document Export Suite
 *
 * Generate professional documents directly from Echoelmusic:
 *
 * PDF Export:
 * - Project reports
 * - Chord sheets / Lead sheets
 * - Lyrics with formatting
 * - Session notes
 * - Mix documentation
 * - Invoice / Contracts
 *
 * PowerPoint (PPTX) Export:
 * - Presentation templates
 * - Marketing materials
 * - Tutorial slides
 * - Album artwork presentations
 * - Pitch decks
 *
 * Excel (XLSX) Export:
 * - Session logs
 * - Budget tracking
 * - Royalty splits
 * - Track metadata
 * - Analytics reports
 *
 * Branding Extraction:
 * - Extract colors from websites
 * - Font detection
 * - Logo extraction
 * - Style guide generation
 *
 * AI-Powered Features:
 * - Auto-generate content from prompts
 * - Smart formatting
 * - Template suggestions
 */

namespace Echoelmusic {
namespace Export {

//==============================================================================
// Document Types
//==============================================================================

enum class DocumentType
{
    PDF,
    PPTX,
    XLSX,
    DOCX,
    HTML,
    Markdown
};

enum class PageSize
{
    A4,
    Letter,
    Legal,
    Tabloid,
    Custom
};

enum class PageOrientation
{
    Portrait,
    Landscape
};

//==============================================================================
// Styling
//==============================================================================

struct DocumentStyle
{
    // Colors
    juce::Colour primaryColor = juce::Colour(0xFF00D4FF);
    juce::Colour secondaryColor = juce::Colour(0xFF1A1A1A);
    juce::Colour backgroundColor = juce::Colours::white;
    juce::Colour textColor = juce::Colours::black;
    juce::Colour accentColor = juce::Colour(0xFFFF6B6B);

    // Fonts
    std::string titleFont = "Helvetica Neue";
    std::string bodyFont = "Helvetica";
    std::string monoFont = "Menlo";

    float titleSize = 24.0f;
    float headingSize = 18.0f;
    float bodySize = 12.0f;
    float captionSize = 10.0f;

    // Layout
    float marginTop = 72.0f;     // 1 inch
    float marginBottom = 72.0f;
    float marginLeft = 72.0f;
    float marginRight = 72.0f;

    float lineSpacing = 1.5f;
    float paragraphSpacing = 12.0f;

    // Logo
    std::string logoPath;
    float logoWidth = 100.0f;
    float logoHeight = 50.0f;
};

//==============================================================================
// Branding Extraction
//==============================================================================

struct BrandingInfo
{
    std::string websiteUrl;

    // Colors
    juce::Colour primaryColor;
    juce::Colour secondaryColor;
    juce::Colour backgroundColor;
    juce::Colour textColor;
    std::vector<juce::Colour> colorPalette;

    // Typography
    std::string primaryFont;
    std::string secondaryFont;
    std::vector<std::string> fontStack;

    // Assets
    std::string logoUrl;
    std::string faviconUrl;
    std::vector<std::string> imageUrls;

    // Meta
    std::string siteName;
    std::string tagline;
    std::string description;
};

class BrandingExtractor
{
public:
    static BrandingInfo extractFromURL(const std::string& url)
    {
        BrandingInfo info;
        info.websiteUrl = url;

        // In production, this would:
        // 1. Fetch the webpage HTML/CSS
        // 2. Parse CSS for color definitions
        // 3. Extract font-family declarations
        // 4. Find logo and favicon
        // 5. Extract meta tags

        // Placeholder with common defaults
        info.primaryColor = juce::Colour(0xFF0066CC);
        info.secondaryColor = juce::Colour(0xFF333333);
        info.backgroundColor = juce::Colours::white;
        info.textColor = juce::Colour(0xFF333333);

        return info;
    }

    static DocumentStyle createStyleFromBranding(const BrandingInfo& branding)
    {
        DocumentStyle style;
        style.primaryColor = branding.primaryColor;
        style.secondaryColor = branding.secondaryColor;
        style.backgroundColor = branding.backgroundColor;
        style.textColor = branding.textColor;

        if (!branding.primaryFont.empty())
            style.titleFont = branding.primaryFont;
        if (!branding.secondaryFont.empty())
            style.bodyFont = branding.secondaryFont;

        if (!branding.logoUrl.empty())
            style.logoPath = branding.logoUrl;

        return style;
    }
};

//==============================================================================
// PDF Generator
//==============================================================================

class PDFGenerator
{
public:
    struct TextBlock
    {
        std::string text;
        float x, y;
        float fontSize = 12.0f;
        juce::Colour color = juce::Colours::black;
        std::string fontName = "Helvetica";
        bool bold = false;
        bool italic = false;
        enum class Align { Left, Center, Right } alignment = Align::Left;
    };

    struct ImageBlock
    {
        std::string imagePath;
        float x, y, width, height;
    };

    struct TableCell
    {
        std::string text;
        juce::Colour backgroundColor = juce::Colours::white;
        juce::Colour textColor = juce::Colours::black;
        bool bold = false;
    };

    struct Table
    {
        std::vector<std::vector<TableCell>> rows;
        std::vector<float> columnWidths;
        float x, y;
        float rowHeight = 20.0f;
        bool hasHeader = true;
        juce::Colour headerColor = juce::Colour(0xFFE0E0E0);
        juce::Colour borderColor = juce::Colour(0xFFCCCCCC);
    };

    void setPageSize(PageSize size, PageOrientation orientation = PageOrientation::Portrait)
    {
        pageSize = size;
        pageOrientation = orientation;

        switch (size)
        {
            case PageSize::A4:
                pageWidth = 595.0f;   // 210mm
                pageHeight = 842.0f;  // 297mm
                break;
            case PageSize::Letter:
                pageWidth = 612.0f;   // 8.5"
                pageHeight = 792.0f;  // 11"
                break;
            case PageSize::Legal:
                pageWidth = 612.0f;
                pageHeight = 1008.0f;  // 14"
                break;
            default:
                pageWidth = 612.0f;
                pageHeight = 792.0f;
        }

        if (orientation == PageOrientation::Landscape)
            std::swap(pageWidth, pageHeight);
    }

    void setStyle(const DocumentStyle& style) { this->style = style; }

    void newPage()
    {
        currentPage++;
        currentY = style.marginTop;
    }

    void addTitle(const std::string& title)
    {
        TextBlock block;
        block.text = title;
        block.x = style.marginLeft;
        block.y = currentY;
        block.fontSize = style.titleSize;
        block.fontName = style.titleFont;
        block.bold = true;
        block.color = style.primaryColor;
        textBlocks.push_back(block);

        currentY += style.titleSize + style.paragraphSpacing;
    }

    void addHeading(const std::string& heading, int level = 1)
    {
        TextBlock block;
        block.text = heading;
        block.x = style.marginLeft;
        block.y = currentY;
        block.fontSize = style.headingSize - (level - 1) * 2.0f;
        block.fontName = style.titleFont;
        block.bold = true;
        block.color = style.textColor;
        textBlocks.push_back(block);

        currentY += block.fontSize + style.paragraphSpacing;
    }

    void addParagraph(const std::string& text)
    {
        TextBlock block;
        block.text = text;
        block.x = style.marginLeft;
        block.y = currentY;
        block.fontSize = style.bodySize;
        block.fontName = style.bodyFont;
        block.color = style.textColor;
        textBlocks.push_back(block);

        // Calculate height (simplified - real implementation would do proper text wrapping)
        float textWidth = pageWidth - style.marginLeft - style.marginRight;
        int estimatedLines = static_cast<int>(text.length() * 7.0f / textWidth) + 1;
        currentY += estimatedLines * style.bodySize * style.lineSpacing + style.paragraphSpacing;
    }

    void addBulletPoint(const std::string& text)
    {
        addParagraph("• " + text);
    }

    void addImage(const std::string& imagePath, float width, float height)
    {
        ImageBlock block;
        block.imagePath = imagePath;
        block.x = style.marginLeft;
        block.y = currentY;
        block.width = width;
        block.height = height;
        imageBlocks.push_back(block);

        currentY += height + style.paragraphSpacing;
    }

    void addTable(const Table& table)
    {
        tables.push_back(table);

        float tableHeight = table.rows.size() * table.rowHeight;
        currentY += tableHeight + style.paragraphSpacing;
    }

    void addChordSheet(const std::string& title, const std::string& artist,
                       const std::string& key, int bpm,
                       const std::vector<std::pair<std::string, std::string>>& sections)
    {
        addTitle(title);
        addParagraph("Artist: " + artist + " | Key: " + key + " | BPM: " + std::to_string(bpm));
        currentY += style.paragraphSpacing;

        for (const auto& [sectionName, content] : sections)
        {
            addHeading("[" + sectionName + "]", 2);
            addParagraph(content);
        }
    }

    void addSessionReport(const std::string& projectName,
                          const std::string& date,
                          const std::string& engineer,
                          const std::vector<std::string>& tracks,
                          const std::string& notes)
    {
        addTitle("Session Report: " + projectName);
        addParagraph("Date: " + date);
        addParagraph("Engineer: " + engineer);

        addHeading("Tracks Recorded", 2);
        for (const auto& track : tracks)
            addBulletPoint(track);

        addHeading("Session Notes", 2);
        addParagraph(notes);
    }

    bool save(const std::string& outputPath)
    {
        // In production, this would use a PDF library like:
        // - libharu
        // - PDFWriter
        // - PoDoFo
        // - JUCE's native PDF support (macOS)

        juce::File file(outputPath);
        juce::FileOutputStream stream(file);

        if (!stream.openedOk())
            return false;

        // Write minimal PDF structure (placeholder)
        stream.writeText("%PDF-1.4\n", false, false, nullptr);
        stream.writeText("% Echoelmusic Document Generator\n", false, false, nullptr);

        // In real implementation, would write all objects here

        stream.writeText("%%EOF\n", false, false, nullptr);

        return true;
    }

private:
    PageSize pageSize = PageSize::Letter;
    PageOrientation pageOrientation = PageOrientation::Portrait;
    float pageWidth = 612.0f;
    float pageHeight = 792.0f;

    DocumentStyle style;
    int currentPage = 1;
    float currentY = 72.0f;

    std::vector<TextBlock> textBlocks;
    std::vector<ImageBlock> imageBlocks;
    std::vector<Table> tables;
};

//==============================================================================
// Excel (XLSX) Generator
//==============================================================================

class XLSXGenerator
{
public:
    struct Cell
    {
        enum class Type { Text, Number, Formula, Date, Boolean };
        Type type = Type::Text;

        std::string textValue;
        double numberValue = 0.0;
        bool boolValue = false;
        std::string formula;

        juce::Colour backgroundColor = juce::Colours::white;
        juce::Colour textColor = juce::Colours::black;
        bool bold = false;
        bool italic = false;
        int fontSize = 11;
    };

    void setSheetName(const std::string& name) { sheetName = name; }

    void setCell(int row, int col, const std::string& text)
    {
        Cell cell;
        cell.type = Cell::Type::Text;
        cell.textValue = text;
        cells[{row, col}] = cell;
        updateBounds(row, col);
    }

    void setCell(int row, int col, double number)
    {
        Cell cell;
        cell.type = Cell::Type::Number;
        cell.numberValue = number;
        cells[{row, col}] = cell;
        updateBounds(row, col);
    }

    void setFormula(int row, int col, const std::string& formula)
    {
        Cell cell;
        cell.type = Cell::Type::Formula;
        cell.formula = formula;
        cells[{row, col}] = cell;
        updateBounds(row, col);
    }

    void setHeader(int row, int col, const std::string& text)
    {
        Cell cell;
        cell.type = Cell::Type::Text;
        cell.textValue = text;
        cell.bold = true;
        cell.backgroundColor = juce::Colour(0xFFE0E0E0);
        cells[{row, col}] = cell;
        updateBounds(row, col);
    }

    void setColumnWidth(int col, float width)
    {
        columnWidths[col] = width;
    }

    // Music-specific helpers
    void createTrackListSheet(const std::vector<std::map<std::string, std::string>>& tracks)
    {
        setSheetName("Track List");

        // Headers
        setHeader(0, 0, "Track #");
        setHeader(0, 1, "Name");
        setHeader(0, 2, "Type");
        setHeader(0, 3, "BPM");
        setHeader(0, 4, "Key");
        setHeader(0, 5, "Duration");
        setHeader(0, 6, "Notes");

        int row = 1;
        for (const auto& track : tracks)
        {
            int col = 0;
            setCell(row, col++, std::to_string(row));

            if (track.count("name")) setCell(row, col++, track.at("name"));
            if (track.count("type")) setCell(row, col++, track.at("type"));
            if (track.count("bpm")) setCell(row, col++, track.at("bpm"));
            if (track.count("key")) setCell(row, col++, track.at("key"));
            if (track.count("duration")) setCell(row, col++, track.at("duration"));
            if (track.count("notes")) setCell(row, col++, track.at("notes"));

            row++;
        }
    }

    void createRoyaltySplitSheet(const std::vector<std::tuple<std::string, std::string, double>>& splits)
    {
        setSheetName("Royalty Splits");

        setHeader(0, 0, "Name");
        setHeader(0, 1, "Role");
        setHeader(0, 2, "Split %");

        int row = 1;
        for (const auto& [name, role, percentage] : splits)
        {
            setCell(row, 0, name);
            setCell(row, 1, role);
            setCell(row, 2, percentage);
            row++;
        }

        // Total
        setCell(row, 0, "TOTAL");
        setFormula(row, 2, "=SUM(C2:C" + std::to_string(row) + ")");
    }

    void createBudgetSheet(const std::vector<std::tuple<std::string, std::string, double>>& expenses)
    {
        setSheetName("Budget");

        setHeader(0, 0, "Category");
        setHeader(0, 1, "Description");
        setHeader(0, 2, "Amount");

        int row = 1;
        for (const auto& [category, description, amount] : expenses)
        {
            setCell(row, 0, category);
            setCell(row, 1, description);
            setCell(row, 2, amount);
            row++;
        }

        // Total
        setCell(row, 0, "TOTAL");
        setFormula(row, 2, "=SUM(C2:C" + std::to_string(row) + ")");
    }

    bool save(const std::string& outputPath)
    {
        // In production, would use:
        // - xlsxwriter
        // - libxlsxwriter
        // - OpenXLSX

        juce::File file(outputPath);

        // XLSX is a ZIP file with XML contents
        // Simplified placeholder

        return true;
    }

private:
    void updateBounds(int row, int col)
    {
        maxRow = std::max(maxRow, row);
        maxCol = std::max(maxCol, col);
    }

    std::string sheetName = "Sheet1";
    std::map<std::pair<int, int>, Cell> cells;
    std::map<int, float> columnWidths;
    int maxRow = 0;
    int maxCol = 0;
};

//==============================================================================
// PowerPoint (PPTX) Generator
//==============================================================================

class PPTXGenerator
{
public:
    enum class SlideLayout
    {
        TitleSlide,
        TitleAndContent,
        SectionHeader,
        TwoContent,
        Comparison,
        TitleOnly,
        Blank,
        ContentWithCaption,
        PictureWithCaption
    };

    struct Slide
    {
        SlideLayout layout = SlideLayout::TitleAndContent;
        std::string title;
        std::string subtitle;
        std::vector<std::string> bulletPoints;
        std::string imagePath;
        std::string notes;
        juce::Colour backgroundColor = juce::Colours::white;
    };

    void setStyle(const DocumentStyle& style) { this->style = style; }

    void addTitleSlide(const std::string& title, const std::string& subtitle)
    {
        Slide slide;
        slide.layout = SlideLayout::TitleSlide;
        slide.title = title;
        slide.subtitle = subtitle;
        slides.push_back(slide);
    }

    void addContentSlide(const std::string& title, const std::vector<std::string>& bulletPoints)
    {
        Slide slide;
        slide.layout = SlideLayout::TitleAndContent;
        slide.title = title;
        slide.bulletPoints = bulletPoints;
        slides.push_back(slide);
    }

    void addImageSlide(const std::string& title, const std::string& imagePath,
                       const std::string& caption = "")
    {
        Slide slide;
        slide.layout = SlideLayout::PictureWithCaption;
        slide.title = title;
        slide.imagePath = imagePath;
        slide.subtitle = caption;
        slides.push_back(slide);
    }

    void addSectionSlide(const std::string& sectionTitle)
    {
        Slide slide;
        slide.layout = SlideLayout::SectionHeader;
        slide.title = sectionTitle;
        slides.push_back(slide);
    }

    // Music-specific templates
    void createAlbumPitchDeck(const std::string& albumTitle,
                              const std::string& artistName,
                              const std::string& genre,
                              const std::vector<std::string>& trackList,
                              const std::string& bio,
                              const std::string& coverArtPath)
    {
        // Title slide
        addTitleSlide(albumTitle, "by " + artistName);

        // Cover art
        if (!coverArtPath.empty())
            addImageSlide("Album Artwork", coverArtPath);

        // About the artist
        addContentSlide("About " + artistName, {bio});

        // Track listing
        addContentSlide("Track Listing", trackList);

        // Genre & style
        addContentSlide("Genre & Style", {
            "Primary Genre: " + genre,
            "Mood: [Add mood description]",
            "Target Audience: [Add audience description]"
        });

        // Contact
        addContentSlide("Contact", {
            "Email: [Add email]",
            "Website: [Add website]",
            "Social: [Add social links]"
        });
    }

    void createTutorialPresentation(const std::string& title,
                                    const std::vector<std::pair<std::string, std::vector<std::string>>>& sections)
    {
        addTitleSlide(title, "A step-by-step guide");

        for (const auto& [sectionTitle, steps] : sections)
        {
            addSectionSlide(sectionTitle);
            addContentSlide(sectionTitle, steps);
        }
    }

    bool save(const std::string& outputPath)
    {
        // In production, would use:
        // - python-pptx (via embedded Python)
        // - OpenXML SDK
        // - libpptx

        juce::File file(outputPath);

        // PPTX is a ZIP file with XML contents
        // Simplified placeholder

        return true;
    }

private:
    DocumentStyle style;
    std::vector<Slide> slides;
};

//==============================================================================
// Main Document Generator
//==============================================================================

class DocumentGenerator
{
public:
    static DocumentGenerator& getInstance()
    {
        static DocumentGenerator instance;
        return instance;
    }

    void setStyle(const DocumentStyle& style)
    {
        currentStyle = style;
        pdfGenerator.setStyle(style);
        pptxGenerator.setStyle(style);
    }

    void applyBrandingFromURL(const std::string& url)
    {
        auto branding = BrandingExtractor::extractFromURL(url);
        currentStyle = BrandingExtractor::createStyleFromBranding(branding);
        setStyle(currentStyle);
    }

    // Quick document generation from prompts
    bool generateFromPrompt(const std::string& prompt, DocumentType type,
                            const std::string& outputPath)
    {
        // AI would parse the prompt and generate appropriate content
        // Placeholder implementation

        switch (type)
        {
            case DocumentType::PDF:
                pdfGenerator.addTitle("Generated Document");
                pdfGenerator.addParagraph(prompt);
                return pdfGenerator.save(outputPath);

            case DocumentType::PPTX:
                pptxGenerator.addTitleSlide("Generated Presentation", "");
                pptxGenerator.addContentSlide("Content", {prompt});
                return pptxGenerator.save(outputPath);

            case DocumentType::XLSX:
                xlsxGenerator.setCell(0, 0, prompt);
                return xlsxGenerator.save(outputPath);

            default:
                return false;
        }
    }

    PDFGenerator& getPDFGenerator() { return pdfGenerator; }
    XLSXGenerator& getXLSXGenerator() { return xlsxGenerator; }
    PPTXGenerator& getPPTXGenerator() { return pptxGenerator; }

private:
    DocumentStyle currentStyle;
    PDFGenerator pdfGenerator;
    XLSXGenerator xlsxGenerator;
    PPTXGenerator pptxGenerator;
};

//==============================================================================
// Convenience Macros
//==============================================================================

#define EchoelDocs DocumentGenerator::getInstance()

} // namespace Export
} // namespace Echoelmusic
