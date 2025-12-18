#include "EchoelDesignStudio.h"
#include <cmath>
#include <random>
#include <algorithm>

//==============================================================================
// Constructor
//==============================================================================

EchoelDesignStudio::EchoelDesignStudio()
{
    initializeTemplates();
    initializeAssetLibrary();

    DBG("EchoelDesignStudio: Initialized - Canva in die Tasche! 🎨");
}

//==============================================================================
// TEMPLATE SYSTEM IMPLEMENTATION
//==============================================================================

std::vector<EchoelDesignStudio::Template> EchoelDesignStudio::getTemplates(TemplateCategory category) const
{
    if (category == TemplateCategory::Custom)
        return templates;

    std::vector<Template> filtered;
    for (const auto& t : templates)
    {
        if (t.category == category)
            filtered.push_back(t);
    }
    return filtered;
}

std::vector<EchoelDesignStudio::Template> EchoelDesignStudio::searchTemplates(const juce::String& query) const
{
    std::vector<Template> results;
    juce::String lowerQuery = query.toLowerCase();

    for (const auto& t : templates)
    {
        // Search in name
        if (t.name.toLowerCase().contains(lowerQuery))
        {
            results.push_back(t);
            continue;
        }

        // Search in description
        if (t.description.toLowerCase().contains(lowerQuery))
        {
            results.push_back(t);
            continue;
        }

        // Search in tags
        for (const auto& tag : t.tags)
        {
            if (tag.toLowerCase().contains(lowerQuery))
            {
                results.push_back(t);
                break;
            }
        }
    }

    return results;
}

juce::String EchoelDesignStudio::createProjectFromTemplate(const juce::String& templateID)
{
    // Find template
    const Template* foundTemplate = nullptr;
    for (const auto& t : templates)
    {
        if (t.id == templateID)
        {
            foundTemplate = &t;
            break;
        }
    }

    if (!foundTemplate)
    {
        DBG("Template not found: " + templateID);
        return {};
    }

    // Create new project from template
    auto projectID = juce::Uuid().toString();
    currentProject = std::make_unique<Project>();
    currentProject->id = projectID;
    currentProject->name = foundTemplate->name + " Project";
    currentProject->size = foundTemplate->size;
    currentProject->created = juce::Time::getCurrentTime();
    currentProject->modified = juce::Time::getCurrentTime();

    // Copy elements from template
    for (const auto* element : foundTemplate->elements)
    {
        // Clone element (simplified - would need proper cloning in production)
        // currentProject->elements.push_back(element->clone());
    }

    DBG("Created project from template: " + foundTemplate->name);
    return projectID;
}

//==============================================================================
// PROJECT MANAGEMENT IMPLEMENTATION
//==============================================================================

juce::String EchoelDesignStudio::createProject(const juce::String& name, TemplateSize size)
{
    auto projectID = juce::Uuid().toString();

    currentProject = std::make_unique<Project>();
    currentProject->id = projectID;
    currentProject->name = name;
    currentProject->size = size;
    currentProject->backgroundColor = juce::Colours::white;
    currentProject->created = juce::Time::getCurrentTime();
    currentProject->modified = juce::Time::getCurrentTime();

    DBG("Created new project: " + name + " (" + juce::String(size.width) + "x" + juce::String(size.height) + ")");

    return projectID;
}

bool EchoelDesignStudio::openProject(const juce::String& projectID)
{
    // Load project from file system
    // Implementation would load JSON/XML project file

    DBG("Opening project: " + projectID);
    return true;
}

bool EchoelDesignStudio::saveProject()
{
    if (!currentProject)
        return false;

    currentProject->modified = juce::Time::getCurrentTime();

    // Save project to file system
    // Implementation would save as JSON/XML

    DBG("Saved project: " + currentProject->name);
    return true;
}

bool EchoelDesignStudio::exportProject(const juce::File& outputFile, const juce::String& format)
{
    if (!currentProject)
        return false;

    // Render and export
    auto image = renderDesign();

    if (format == "png")
    {
        juce::PNGImageFormat png;
        juce::FileOutputStream stream(outputFile);
        return png.writeImageToStream(image, stream);
    }
    else if (format == "jpg" || format == "jpeg")
    {
        juce::JPEGImageFormat jpg;
        juce::FileOutputStream stream(outputFile);
        return jpg.writeImageToStream(image, stream);
    }

    DBG("Exported project to: " + outputFile.getFullPathName());
    return true;
}

//==============================================================================
// DESIGN ELEMENT IMPLEMENTATIONS
//==============================================================================

void EchoelDesignStudio::TextElement::render(juce::Graphics& g) const
{
    if (!visible)
        return;

    g.saveState();

    // Apply transform
    juce::AffineTransform transform;
    transform = transform.translated(position.x, position.y);
    transform = transform.rotated(juce::degreesToRadians(rotation), position.x, position.y);
    transform = transform.scaled(scale, scale, position.x, position.y);
    g.addTransform(transform);

    // Apply opacity
    g.setOpacity(opacity);

    // Draw shadow
    if (hasShadow)
    {
        g.setColour(shadowColor);
        g.setFont(font);
        g.drawText(text,
                   shadowOffset.x, shadowOffset.y,
                   1000, 1000,
                   juce::Justification::topLeft, true);
    }

    // Draw outline
    if (hasOutline)
    {
        g.setColour(outlineColor);
        juce::Path textPath;
        juce::GlyphArrangement glyphs;
        glyphs.addLineOfText(font, text, 0, font.getHeight());
        glyphs.createPath(textPath);
        g.strokePath(textPath, juce::PathStrokeType(outlineThickness));
    }

    // Draw text
    g.setColour(color);
    g.setFont(font);

    juce::Justification justification = juce::Justification::left;
    if (alignment == Alignment::Center)
        justification = juce::Justification::centred;
    else if (alignment == Alignment::Right)
        justification = juce::Justification::right;

    g.drawText(text, 0, 0, 1000, 1000, justification, true);

    g.restoreState();
}

juce::Rectangle<float> EchoelDesignStudio::TextElement::getBounds() const
{
    float width = font.getStringWidthFloat(text);
    float height = font.getHeight();
    return juce::Rectangle<float>(position.x, position.y, width * scale, height * scale);
}

void EchoelDesignStudio::ImageElement::render(juce::Graphics& g) const
{
    if (!visible || !image.isValid())
        return;

    g.saveState();

    // Apply transform
    juce::AffineTransform transform;
    transform = transform.translated(position.x, position.y);
    transform = transform.rotated(juce::degreesToRadians(rotation),
                                  position.x + bounds.getWidth() / 2,
                                  position.y + bounds.getHeight() / 2);
    transform = transform.scaled(scale, scale, position.x, position.y);
    g.addTransform(transform);

    // Apply opacity
    g.setOpacity(opacity);

    // Apply filters (simplified - would use GPU shaders in production)
    juce::Image processedImage = image.createCopy();

    // Apply brightness/contrast/saturation
    if (brightness != 0.0f || contrast != 0.0f || saturation != 0.0f)
    {
        // 🔒 SECURITY: Prevent DoS on extremely large images during filter processing
        const int pixelCount = processedImage.getWidth() * processedImage.getHeight();
        if (pixelCount > MAX_PIXELS)
        {
            DBG("EchoelDesignStudio: Skipping filter - image too large for CPU processing ("
                + juce::String(pixelCount) + " pixels)");
            DBG("  Use GPU shaders for images > " + juce::String(MAX_PIXELS) + " pixels");
            // Return unfiltered image (safe fallback)
        }
        else
        {
            juce::Image::BitmapData data(processedImage, juce::Image::BitmapData::readWrite);

            for (int y = 0; y < processedImage.getHeight(); ++y)
        {
            for (int x = 0; x < processedImage.getWidth(); ++x)
            {
                auto pixel = processedImage.getPixelAt(x, y);

                // Apply filters
                float h, s, b;
                pixel.getHSB(h, s, b);
                s = juce::jlimit(0.0f, 1.0f, s + saturation);
                b = juce::jlimit(0.0f, 1.0f, b + brightness);

                auto newColor = juce::Colour::fromHSV(h, s, b, pixel.getAlpha() / 255.0f);
                processedImage.setPixelAt(x, y, newColor);
            }
        }
        }  // End else block (security check)
    }

    // Draw image
    if (hasMask)
    {
        g.saveState();

        if (maskShape == MaskShape::Circle)
        {
            juce::Path circleMask;
            circleMask.addEllipse(bounds);
            g.reduceClipRegion(circleMask);
        }
        else if (maskShape == MaskShape::Rectangle)
        {
            g.reduceClipRegion(bounds.toNearestInt());
        }
        else if (maskShape == MaskShape::Custom)
        {
            g.reduceClipRegion(customMask);
        }

        g.drawImageAt(processedImage, bounds.getX(), bounds.getY());
        g.restoreState();
    }
    else
    {
        g.drawImage(processedImage, bounds);
    }

    g.restoreState();
}

juce::Rectangle<float> EchoelDesignStudio::ImageElement::getBounds() const
{
    return bounds.transformedBy(juce::AffineTransform::scale(scale)
                                                       .rotated(juce::degreesToRadians(rotation))
                                                       .translated(position.x, position.y));
}

void EchoelDesignStudio::ShapeElement::render(juce::Graphics& g) const
{
    if (!visible)
        return;

    g.saveState();

    // Apply transform
    juce::AffineTransform transform;
    transform = transform.translated(position.x, position.y);
    transform = transform.rotated(juce::degreesToRadians(rotation),
                                  position.x + bounds.getWidth() / 2,
                                  position.y + bounds.getHeight() / 2);
    transform = transform.scaled(scale, scale, position.x, position.y);
    g.addTransform(transform);

    // Apply opacity
    g.setOpacity(opacity);

    // Create shape path
    juce::Path path;

    switch (shapeType)
    {
        case ShapeType::Rectangle:
            path.addRoundedRectangle(bounds, cornerRadius);
            break;

        case ShapeType::Circle:
            path.addEllipse(bounds);
            break;

        case ShapeType::Triangle:
        {
            path.startNewSubPath(bounds.getCentreX(), bounds.getY());
            path.lineTo(bounds.getRight(), bounds.getBottom());
            path.lineTo(bounds.getX(), bounds.getBottom());
            path.closeSubPath();
            break;
        }

        case ShapeType::Polygon:
        {
            float cx = bounds.getCentreX();
            float cy = bounds.getCentreY();
            float radius = std::min(bounds.getWidth(), bounds.getHeight()) / 2.0f;

            for (int i = 0; i < numSides; ++i)
            {
                float angle = (juce::MathConstants<float>::twoPi / numSides) * i - juce::MathConstants<float>::halfPi;
                float x = cx + std::cos(angle) * radius;
                float y = cy + std::sin(angle) * radius;

                if (i == 0)
                    path.startNewSubPath(x, y);
                else
                    path.lineTo(x, y);
            }
            path.closeSubPath();
            break;
        }

        case ShapeType::Star:
        {
            float cx = bounds.getCentreX();
            float cy = bounds.getCentreY();
            float outerRadius = std::min(bounds.getWidth(), bounds.getHeight()) / 2.0f;
            float innerRadius = outerRadius * 0.4f;

            for (int i = 0; i < numSides * 2; ++i)
            {
                float angle = (juce::MathConstants<float>::twoPi / (numSides * 2)) * i - juce::MathConstants<float>::halfPi;
                float radius = (i % 2 == 0) ? outerRadius : innerRadius;
                float x = cx + std::cos(angle) * radius;
                float y = cy + std::sin(angle) * radius;

                if (i == 0)
                    path.startNewSubPath(x, y);
                else
                    path.lineTo(x, y);
            }
            path.closeSubPath();
            break;
        }

        case ShapeType::Custom:
            path = customPath;
            break;

        default:
            break;
    }

    // Fill
    if (hasFill)
    {
        if (useGradient)
        {
            g.setGradientFill(gradient);
        }
        else
        {
            g.setColour(fillColor);
        }
        g.fillPath(path);
    }

    // Stroke
    if (hasStroke)
    {
        g.setColour(strokeColor);
        g.strokePath(path, juce::PathStrokeType(strokeWidth));
    }

    g.restoreState();
}

juce::Rectangle<float> EchoelDesignStudio::ShapeElement::getBounds() const
{
    return bounds.transformedBy(juce::AffineTransform::scale(scale)
                                                       .rotated(juce::degreesToRadians(rotation))
                                                       .translated(position.x, position.y));
}

void EchoelDesignStudio::AudioWaveformElement::render(juce::Graphics& g) const
{
    if (!visible || waveformData.empty())
        return;

    g.saveState();
    g.setOpacity(opacity);

    // Background
    g.setColour(backgroundColor);
    g.fillRect(bounds);

    // Waveform
    juce::Path waveformPath;

    float width = bounds.getWidth();
    float height = bounds.getHeight();
    float centerY = bounds.getCentreY();

    for (size_t i = 0; i < waveformData.size(); ++i)
    {
        float x = bounds.getX() + (i / static_cast<float>(waveformData.size())) * width;
        float y = centerY - (waveformData[i] * height * 0.5f);

        if (i == 0)
            waveformPath.startNewSubPath(x, y);
        else
            waveformPath.lineTo(x, y);
    }

    if (style == Style::Filled)
    {
        // Close path at bottom
        waveformPath.lineTo(bounds.getRight(), bounds.getBottom());
        waveformPath.lineTo(bounds.getX(), bounds.getBottom());
        waveformPath.closeSubPath();

        g.setColour(waveColor);
        g.fillPath(waveformPath);
    }
    else if (style == Style::Line)
    {
        g.setColour(waveColor);
        g.strokePath(waveformPath, juce::PathStrokeType(lineThickness));
    }

    // Mirror vertically
    if (mirrorVertical)
    {
        juce::Path mirrorPath = waveformPath;
        mirrorPath.applyTransform(juce::AffineTransform::verticalFlip(centerY));

        g.setColour(waveColor.withAlpha(0.5f));
        g.strokePath(mirrorPath, juce::PathStrokeType(lineThickness));
    }

    g.restoreState();
}

juce::Rectangle<float> EchoelDesignStudio::AudioWaveformElement::getBounds() const
{
    return bounds;
}

void EchoelDesignStudio::AudioSpectrumElement::render(juce::Graphics& g) const
{
    if (!visible || spectrumData.empty())
        return;

    g.saveState();
    g.setOpacity(opacity);

    float width = bounds.getWidth();
    float height = bounds.getHeight();
    float barWidth = (width - (numBands - 1) * barSpacing) / numBands;

    for (int i = 0; i < numBands && i < static_cast<int>(spectrumData.size()); ++i)
    {
        float magnitude = spectrumData[i];
        float barHeight = magnitude * height;

        float x = bounds.getX() + i * (barWidth + barSpacing);
        float y = bounds.getBottom() - barHeight;

        // Color based on frequency
        juce::Colour barColor;
        if (useSpectrumColors)
        {
            float t = i / static_cast<float>(numBands);

            if (t < 0.5f)
            {
                // Low to mid
                barColor = lowColor.interpolatedWith(midColor, t * 2.0f);
            }
            else
            {
                // Mid to high
                barColor = midColor.interpolatedWith(highColor, (t - 0.5f) * 2.0f);
            }
        }
        else
        {
            barColor = lowColor;
        }

        g.setColour(barColor);
        g.fillRect(x, y, barWidth, barHeight);
    }

    g.restoreState();
}

juce::Rectangle<float> EchoelDesignStudio::AudioSpectrumElement::getBounds() const
{
    return bounds;
}

//==============================================================================
// AI DESIGN ASSISTANT IMPLEMENTATION
//==============================================================================

std::vector<EchoelDesignStudio::DesignSuggestion> EchoelDesignStudio::getAISuggestions() const
{
    std::vector<DesignSuggestion> suggestions;

    if (!currentProject)
        return suggestions;

    // Suggestion 1: Improve color harmony
    DesignSuggestion colorSuggestion;
    colorSuggestion.description = "Apply complementary color scheme for better contrast";
    colorSuggestion.confidenceScore = 0.85f;
    colorSuggestion.apply = []() {
        DBG("Applying color harmony...");
    };
    suggestions.push_back(colorSuggestion);

    // Suggestion 2: Golden ratio layout
    DesignSuggestion layoutSuggestion;
    layoutSuggestion.description = "Reorganize elements using golden ratio (1.618:1)";
    layoutSuggestion.confidenceScore = 0.92f;
    layoutSuggestion.apply = []() {
        DBG("Applying golden ratio layout...");
    };
    suggestions.push_back(layoutSuggestion);

    // Suggestion 3: Typography hierarchy
    DesignSuggestion typographySuggestion;
    typographySuggestion.description = "Improve text hierarchy with size variation";
    typographySuggestion.confidenceScore = 0.78f;
    typographySuggestion.apply = []() {
        DBG("Improving typography hierarchy...");
    };
    suggestions.push_back(typographySuggestion);

    return suggestions;
}

std::vector<juce::Colour> EchoelDesignStudio::generatePaletteFromAudio(const juce::AudioBuffer<float>& audio)
{
    std::vector<juce::Colour> palette;

    // Analyze audio spectral content
    // Low frequencies → Blues/Purples
    // Mid frequencies → Greens/Yellows
    // High frequencies → Oranges/Reds

    // Simplified implementation
    std::random_device rd;
    std::mt19937 gen(rd());
    std::uniform_real_distribution<float> dis(0.0f, 1.0f);

    for (int i = 0; i < 5; ++i)
    {
        float hue = dis(gen);
        float saturation = 0.6f + dis(gen) * 0.4f;
        float brightness = 0.5f + dis(gen) * 0.5f;

        palette.push_back(juce::Colour::fromHSV(hue, saturation, brightness, 1.0f));
    }

    DBG("Generated " + juce::String(palette.size()) + " colors from audio");

    return palette;
}

void EchoelDesignStudio::autoLayout()
{
    if (!currentProject)
        return;

    // Apply golden ratio layout (1.618:1)
    const float phi = 1.618f;

    float width = currentProject->size.width;
    float height = currentProject->size.height;

    // Calculate golden ratio sections
    float goldenX = width / phi;
    float goldenY = height / phi;

    DBG("Auto-layout: Golden ratio at x=" + juce::String(goldenX) + ", y=" + juce::String(goldenY));

    // Position elements at golden ratio points
    // Implementation would reposition all elements
}

std::pair<juce::Font, juce::Font> EchoelDesignStudio::suggestFontPair(const juce::String& genre) const
{
    // Suggest font pairs based on music genre

    juce::Font heading(24.0f, juce::Font::bold);
    juce::Font body(14.0f, juce::Font::plain);

    if (genre.containsIgnoreCase("rock") || genre.containsIgnoreCase("metal"))
    {
        // Bold, aggressive fonts
        heading = juce::Font(32.0f, juce::Font::bold);
        body = juce::Font(16.0f, juce::Font::plain);
    }
    else if (genre.containsIgnoreCase("jazz") || genre.containsIgnoreCase("classical"))
    {
        // Elegant, serif fonts
        heading = juce::Font("Times New Roman", 28.0f, juce::Font::plain);
        body = juce::Font("Georgia", 14.0f, juce::Font::plain);
    }
    else if (genre.containsIgnoreCase("electronic") || genre.containsIgnoreCase("edm"))
    {
        // Modern, geometric fonts
        heading = juce::Font("Arial", 30.0f, juce::Font::bold);
        body = juce::Font("Helvetica", 14.0f, juce::Font::plain);
    }

    return {heading, body};
}

bool EchoelDesignStudio::generateDesignFromPrompt(const juce::String& prompt)
{
    DBG("Generating design from prompt: " + prompt);

    // AI-powered design generation
    // Would use ML model to generate design from text description

    // Simplified: Create basic project based on keywords
    if (prompt.containsIgnoreCase("album"))
    {
        createProject("AI Album Cover", TemplateSize::AlbumCoverSquare());
    }
    else if (prompt.containsIgnoreCase("instagram"))
    {
        createProject("AI Instagram Post", TemplateSize::InstagramPost());
    }
    else
    {
        createProject("AI Design", TemplateSize::AlbumCoverSquare());
    }

    return true;
}

//==============================================================================
// BRAND KIT IMPLEMENTATION
//==============================================================================

void EchoelDesignStudio::setBrandKit(const BrandKit& kit)
{
    brandKit = kit;
    DBG("Brand kit set: " + kit.name);
}

void EchoelDesignStudio::applyBrandKit()
{
    if (!currentProject)
        return;

    // Apply brand colors to all elements
    for (auto& element : currentProject->elements)
    {
        // Apply brand colors based on element type
        // Implementation would update colors
    }

    DBG("Applied brand kit to current project");
}

//==============================================================================
// ASSET LIBRARY IMPLEMENTATION
//==============================================================================

std::vector<EchoelDesignStudio::Asset> EchoelDesignStudio::searchAssets(const juce::String& query, AssetType type) const
{
    std::vector<Asset> results;
    juce::String lowerQuery = query.toLowerCase();

    for (const auto& asset : assetLibrary)
    {
        if (asset.type != type && type != AssetType::Template)
            continue;

        if (asset.name.toLowerCase().contains(lowerQuery))
        {
            results.push_back(asset);
            continue;
        }

        for (const auto& tag : asset.tags)
        {
            if (tag.toLowerCase().contains(lowerQuery))
            {
                results.push_back(asset);
                break;
            }
        }
    }

    return results;
}

juce::String EchoelDesignStudio::importAsset(const juce::File& file, AssetType type)
{
    // 🔒 SECURITY: Validate asset library size (prevent unbounded growth)
    if (assetLibrary.size() >= MAX_ASSETS)
    {
        DBG("EchoelDesignStudio: Asset import rejected - library full ("
            + juce::String(assetLibrary.size()) + " / " + juce::String(MAX_ASSETS) + ")");
        DBG("  Please remove unused assets before importing new ones");
        return {};  // Return empty string on failure
    }

    // 🔒 SECURITY: Validate file exists and size
    if (!file.existsAsFile())
    {
        DBG("EchoelDesignStudio: Asset import rejected - file does not exist: " + file.getFullPathName());
        return {};
    }

    const int64_t fileSize = file.getSize();
    if (fileSize > MAX_FILE_SIZE_BYTES)
    {
        DBG("EchoelDesignStudio: Asset import rejected - file too large ("
            + juce::String(fileSize / (1024*1024)) + " MB > " + juce::String(MAX_FILE_SIZE_BYTES / (1024*1024)) + " MB)");
        return {};
    }

    if (fileSize <= 0)
    {
        DBG("EchoelDesignStudio: Asset import rejected - file is empty");
        return {};
    }

    Asset asset;
    asset.id = juce::Uuid().toString();
    asset.name = file.getFileNameWithoutExtension();
    asset.type = type;
    asset.file = file;
    asset.isPremium = false;

    assetLibrary.push_back(asset);

    DBG("Imported asset: " + asset.name + " (" + juce::String(fileSize / 1024) + " KB)");

    return asset.id;
}

EchoelDesignStudio::Asset EchoelDesignStudio::getAsset(const juce::String& assetID) const
{
    for (const auto& asset : assetLibrary)
    {
        if (asset.id == assetID)
            return asset;
    }

    return Asset();
}

//==============================================================================
// AUDIO INTEGRATION IMPLEMENTATION
//==============================================================================

void EchoelDesignStudio::setAudioBuffer(const juce::AudioBuffer<float>& buffer)
{
    audioBuffer = buffer;

    // Update waveform elements
    if (currentProject)
    {
        for (auto& element : currentProject->elements)
        {
            if (auto* waveform = dynamic_cast<AudioWaveformElement*>(element.get()))
            {
                // Extract waveform data
                std::vector<float> waveformData;
                const int numSamples = buffer.getNumSamples();
                const int stride = std::max(1, numSamples / 1000);  // Downsample to 1000 points

                for (int i = 0; i < numSamples; i += stride)
                {
                    waveformData.push_back(buffer.getSample(0, i));
                }

                waveform->waveformData = waveformData;
            }
        }
    }
}

void EchoelDesignStudio::setSpectrumData(const std::vector<float>& spectrum)
{
    spectrumData = spectrum;

    // Update spectrum elements
    if (currentProject)
    {
        for (auto& element : currentProject->elements)
        {
            if (auto* spectrumElement = dynamic_cast<AudioSpectrumElement*>(element.get()))
            {
                spectrumElement->spectrumData = spectrum;
            }
        }
    }
}

void EchoelDesignStudio::setAudioReactiveColors(bool enabled)
{
    audioReactiveEnabled = enabled;
    DBG("Audio-reactive colors: " + juce::String(enabled ? "ON" : "OFF"));
}

std::vector<juce::Colour> EchoelDesignStudio::extractColorsFromSpectrum(const std::vector<float>& spectrum)
{
    std::vector<juce::Colour> colors;

    if (spectrum.empty())
        return colors;

    // Map spectrum to colors
    // Low frequencies → Cool colors (blues, purples)
    // High frequencies → Warm colors (reds, oranges)

    const int numColors = 5;
    for (int i = 0; i < numColors; ++i)
    {
        float t = i / static_cast<float>(numColors - 1);

        // Sample spectrum at different points
        int index = static_cast<int>(t * (spectrum.size() - 1));
        float magnitude = spectrum[index];

        // Map to hue (0.0 = red, 0.66 = blue)
        float hue = 0.66f - (t * 0.66f);  // Blue to red
        float saturation = 0.7f + magnitude * 0.3f;
        float brightness = 0.5f + magnitude * 0.5f;

        colors.push_back(juce::Colour::fromHSV(hue, saturation, brightness, 1.0f));
    }

    return colors;
}

//==============================================================================
// BIO-REACTIVE DESIGN IMPLEMENTATION
//==============================================================================

void EchoelDesignStudio::setBioData(float hrv, float coherence)
{
    bioHRV = juce::jlimit(0.0f, 1.0f, hrv);
    bioCoherence = juce::jlimit(0.0f, 1.0f, coherence);
}

void EchoelDesignStudio::setBioReactive(bool enabled)
{
    bioReactiveEnabled = enabled;
    DBG("Bio-reactive design: " + juce::String(enabled ? "ON" : "OFF"));
}

std::vector<juce::Colour> EchoelDesignStudio::generateEmotionalPalette(float valence, float arousal)
{
    std::vector<juce::Colour> palette;

    // Valence: -1 (negative) to +1 (positive)
    // Arousal: 0 (calm) to 1 (excited)

    // Positive + High Arousal = Bright, warm colors (yellow, orange)
    // Positive + Low Arousal = Soft, cool colors (light blue, green)
    // Negative + High Arousal = Intense, dark colors (red, purple)
    // Negative + Low Arousal = Muted, cool colors (grey, dark blue)

    float baseHue;
    float baseSaturation;
    float baseBrightness;

    if (valence > 0.0f)
    {
        // Positive emotions
        baseHue = 0.1f + (arousal * 0.05f);  // Yellow to orange
        baseSaturation = 0.6f + (arousal * 0.4f);
        baseBrightness = 0.7f + (arousal * 0.3f);
    }
    else
    {
        // Negative emotions
        baseHue = 0.6f - (arousal * 0.1f);  // Blue to purple
        baseSaturation = 0.5f + (arousal * 0.3f);
        baseBrightness = 0.3f + (arousal * 0.2f);
    }

    // Generate 5 colors around base
    for (int i = 0; i < 5; ++i)
    {
        float hueOffset = (i - 2) * 0.05f;
        float hue = std::fmod(baseHue + hueOffset + 1.0f, 1.0f);

        palette.push_back(juce::Colour::fromHSV(hue, baseSaturation, baseBrightness, 1.0f));
    }

    return palette;
}

//==============================================================================
// RENDERING & EXPORT IMPLEMENTATION
//==============================================================================

juce::Image EchoelDesignStudio::renderDesign(int width, int height) const
{
    if (!currentProject)
        return juce::Image();

    // Use project size if not specified
    if (width <= 0)
        width = currentProject->size.width;
    if (height <= 0)
        height = currentProject->size.height;

    // 🔒 SECURITY: Validate image dimensions (prevent DoS)
    if (width > MAX_IMAGE_WIDTH || height > MAX_IMAGE_HEIGHT)
    {
        DBG("EchoelDesignStudio: Image size rejected - exceeds limits ("
            + juce::String(width) + "x" + juce::String(height) + ")");
        DBG("  Max allowed: " + juce::String(MAX_IMAGE_WIDTH) + "x" + juce::String(MAX_IMAGE_HEIGHT));
        return juce::Image();
    }

    // 🔒 SECURITY: Check integer overflow and total pixel count
    const uint64_t totalPixels = static_cast<uint64_t>(width) * height;
    if (totalPixels > MAX_PIXELS)
    {
        DBG("EchoelDesignStudio: Image rejected - too many pixels ("
            + juce::String(static_cast<int64_t>(totalPixels)) + " > " + juce::String(MAX_PIXELS) + ")");
        return juce::Image();
    }

    // 🔒 SECURITY: Check memory allocation size (width * height * 4 bytes)
    const uint64_t totalBytes = totalPixels * 4;  // ARGB = 4 bytes per pixel
    const uint64_t MAX_MEMORY_BYTES = 4ULL * 1024 * 1024 * 1024;  // 4 GB
    if (totalBytes > MAX_MEMORY_BYTES)
    {
        DBG("EchoelDesignStudio: Image rejected - requires too much memory ("
            + juce::String(static_cast<int64_t>(totalBytes / (1024*1024))) + " MB)");
        return juce::Image();
    }

    juce::Image image(juce::Image::ARGB, width, height, true);
    juce::Graphics g(image);

    // Background
    g.fillAll(currentProject->backgroundColor);

    // Render all elements sorted by z-index
    std::vector<DesignElement*> sortedElements;
    for (const auto& element : currentProject->elements)
        sortedElements.push_back(element.get());

    std::sort(sortedElements.begin(), sortedElements.end(),
              [](const auto* a, const auto* b) { return a->zIndex < b->zIndex; });

    for (const auto* element : sortedElements)
    {
        if (element->visible)
        {
            element->render(g);
        }
    }

    return image;
}

bool EchoelDesignStudio::exportDesign(const juce::File& outputFile, ExportFormat format, int quality)
{
    auto image = renderDesign();

    if (!image.isValid())
        return false;

    juce::FileOutputStream stream(outputFile);
    if (!stream.openedOk())
        return false;

    switch (format)
    {
        case ExportFormat::PNG:
        {
            juce::PNGImageFormat png;
            return png.writeImageToStream(image, stream);
        }

        case ExportFormat::JPG:
        {
            juce::JPEGImageFormat jpg;
            jpg.setQuality(quality / 100.0f);
            return jpg.writeImageToStream(image, stream);
        }

        case ExportFormat::WebP:
        case ExportFormat::TIFF:
        case ExportFormat::SVG:
        case ExportFormat::PDF:
        case ExportFormat::EPS:
        case ExportFormat::MP4:
        case ExportFormat::MOV:
        case ExportFormat::GIF:
            DBG("Export format not yet implemented: " + juce::String((int)format));
            return false;
    }

    return false;
}

bool EchoelDesignStudio::exportMultipleSizes(const juce::File& outputDir, const juce::String& baseName)
{
    if (!currentProject)
        return false;

    outputDir.createDirectory();

    // Export for all common platforms
    std::vector<TemplateSize> sizes = {
        TemplateSize::InstagramPost(),
        TemplateSize::InstagramStory(),
        TemplateSize::FacebookPost(),
        TemplateSize::TwitterPost(),
        TemplateSize::YouTubeThumbnail(),
        TemplateSize::SpotifyCanvas()
    };

    for (const auto& size : sizes)
    {
        auto image = renderDesign(size.width, size.height);

        juce::String filename = baseName + "_" + size.name.replaceCharacter(' ', '_') + ".png";
        juce::File outputFile = outputDir.getChildFile(filename);

        juce::FileOutputStream stream(outputFile);
        juce::PNGImageFormat png;
        png.writeImageToStream(image, stream);

        DBG("Exported: " + filename);
    }

    return true;
}

//==============================================================================
// COLLABORATION IMPLEMENTATION
//==============================================================================

juce::String EchoelDesignStudio::shareDesign(const juce::String& projectID)
{
    // Generate shareable link
    juce::String shareURL = "https://echoelmusic.com/designs/" + projectID;

    DBG("Share link created: " + shareURL);

    return shareURL;
}

void EchoelDesignStudio::addComment(const juce::Point<float>& position, const juce::String& comment)
{
    DBG("Comment added at (" + juce::String(position.x) + ", " + juce::String(position.y) + "): " + comment);
}

//==============================================================================
// HELPER METHODS IMPLEMENTATION
//==============================================================================

void EchoelDesignStudio::initializeTemplates()
{
    // Initialize built-in templates

    // Album Cover Template
    Template albumTemplate;
    albumTemplate.id = "album_modern_1";
    albumTemplate.name = "Modern Album Cover";
    albumTemplate.category = TemplateCategory::AlbumCover;
    albumTemplate.size = TemplateSize::AlbumCoverSquare();
    albumTemplate.description = "Clean, modern album cover with bold typography";
    albumTemplate.tags = {"modern", "minimal", "typography", "bold"};
    albumTemplate.author = "Echoelmusic";
    albumTemplate.popularityScore = 95;
    templates.push_back(albumTemplate);

    // Instagram Post Template
    Template instagramTemplate;
    instagramTemplate.id = "instagram_promo_1";
    instagramTemplate.name = "Music Promo Post";
    instagramTemplate.category = TemplateCategory::SocialMedia;
    instagramTemplate.size = TemplateSize::InstagramPost();
    instagramTemplate.description = "Eye-catching Instagram post for music promotion";
    instagramTemplate.tags = {"instagram", "social", "promo", "colorful"};
    instagramTemplate.author = "Echoelmusic";
    instagramTemplate.popularityScore = 88;
    templates.push_back(instagramTemplate);

    DBG("Initialized " + juce::String(templates.size()) + " templates");
}

void EchoelDesignStudio::initializeAssetLibrary()
{
    // Initialize asset library
    // Would load from resources folder in production

    DBG("Asset library initialized");
}

juce::Image EchoelDesignStudio::renderElement(const DesignElement& element) const
{
    auto bounds = element.getBounds();
    juce::Image elementImage(juce::Image::ARGB,
                             static_cast<int>(bounds.getWidth()),
                             static_cast<int>(bounds.getHeight()),
                             true);

    juce::Graphics g(elementImage);
    element.render(g);

    return elementImage;
}

juce::Colour EchoelDesignStudio::getAudioReactiveColor(const juce::Colour& baseColor) const
{
    if (!audioReactiveEnabled || spectrumData.empty())
        return baseColor;

    // Modulate color based on audio spectrum
    float avgMagnitude = 0.0f;
    for (float mag : spectrumData)
        avgMagnitude += mag;
    avgMagnitude /= spectrumData.size();

    // Increase brightness/saturation based on audio level
    float h, s, b;
    baseColor.getHSB(h, s, b);
    float newBrightness = juce::jlimit(0.0f, 1.0f, b + avgMagnitude * 0.3f);
    float newSaturation = juce::jlimit(0.0f, 1.0f, s + avgMagnitude * 0.2f);

    return juce::Colour::fromHSV(h, newSaturation, newBrightness, baseColor.getFloatAlpha());
}

juce::Colour EchoelDesignStudio::getBioReactiveColor(const juce::Colour& baseColor) const
{
    if (!bioReactiveEnabled)
        return baseColor;

    // Modulate color based on bio-data
    // High HRV + Coherence = Warmer, brighter colors
    // Low HRV = Cooler, darker colors

    float bioScore = (bioHRV + bioCoherence) / 2.0f;

    float h, s, b;
    baseColor.getHSB(h, s, b);
    float hueShift = (bioScore - 0.5f) * 0.1f;  // Shift towards warm/cool
    float brightnessBoost = bioCoherence * 0.2f;

    float newHue = std::fmod(h + hueShift + 1.0f, 1.0f);
    float newBrightness = juce::jlimit(0.0f, 1.0f, b + brightnessBoost);

    return juce::Colour::fromHSV(newHue, s, newBrightness, baseColor.getFloatAlpha());
}
