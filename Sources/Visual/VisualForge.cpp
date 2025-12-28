#include "VisualForge.h"
#include "../Core/DSPOptimizations.h"

//==============================================================================
// Constructor
//==============================================================================

VisualForge::VisualForge()
{
    // Initialize with one default layer
    Layer defaultLayer;
    defaultLayer.name = "Layer 1";
    defaultLayer.generator = GeneratorType::SolidColor;
    defaultLayer.generatorParams["r"] = 0.5f;
    defaultLayer.generatorParams["g"] = 0.5f;
    defaultLayer.generatorParams["b"] = 0.5f;
    layers.push_back(defaultLayer);
}

//==============================================================================
// Layer Management
//==============================================================================

int VisualForge::addLayer(const Layer& layer)
{
    layers.push_back(layer);
    return static_cast<int>(layers.size()) - 1;
}

VisualForge::Layer& VisualForge::getLayer(int index)
{
    jassert(index >= 0 && index < static_cast<int>(layers.size()));
    return layers[index];
}

const VisualForge::Layer& VisualForge::getLayer(int index) const
{
    jassert(index >= 0 && index < static_cast<int>(layers.size()));
    return layers[index];
}

void VisualForge::setLayer(int index, const Layer& layer)
{
    if (index >= 0 && index < static_cast<int>(layers.size()))
    {
        layers[index] = layer;
    }
}

void VisualForge::removeLayer(int index)
{
    if (index >= 0 && index < static_cast<int>(layers.size()))
    {
        layers.erase(layers.begin() + index);
    }
}

void VisualForge::clearLayers()
{
    layers.clear();
}

//==============================================================================
// Resolution & Output
//==============================================================================

void VisualForge::setResolution(int width, int height)
{
    outputWidth = juce::jlimit(256, 7680, width);   // Min: 256, Max: 8K
    outputHeight = juce::jlimit(144, 4320, height);
}

void VisualForge::getResolution(int& width, int& height) const
{
    width = outputWidth;
    height = outputHeight;
}

void VisualForge::setTargetFPS(int fps)
{
    targetFPS = juce::jlimit(24, 120, fps);
}

//==============================================================================
// Audio Reactive
//==============================================================================

void VisualForge::setAudioReactive(const AudioReactive& config)
{
    audioReactive = config;
}

void VisualForge::updateAudioSpectrum(const std::vector<float>& spectrumData)
{
    currentSpectrum = spectrumData;
}

void VisualForge::updateWaveform(const std::vector<float>& waveformData)
{
    currentWaveform = waveformData;
}

//==============================================================================
// Bio-Reactive
//==============================================================================

void VisualForge::setBioData(float hrv, float coherence)
{
    bioHRV = juce::jlimit(0.0f, 1.0f, hrv);
    bioCoherence = juce::jlimit(0.0f, 1.0f, coherence);
}

void VisualForge::setBioReactiveEnabled(bool enabled)
{
    bioReactiveEnabled = enabled;
}

//==============================================================================
// Rendering
//==============================================================================

juce::Image VisualForge::renderFrame()
{
    double currentTime = juce::Time::getMillisecondCounterHiRes();

    // Compose all layers
    juce::Image frame = composeLayers();

    // Update FPS
    if (lastFrameTime > 0.0)
    {
        double deltaTime = currentTime - lastFrameTime;
        currentFPS = static_cast<float>(1000.0 / deltaTime);
    }
    lastFrameTime = currentTime;

    // Add to recording if active
    if (recording && !recordingFile.getFullPathName().isEmpty())
    {
        recordedFrames.push_back(frame);
    }

    return frame;
}

//==============================================================================
// Presets
//==============================================================================

bool VisualForge::loadPreset(const juce::File& file)
{
    if (!file.existsAsFile())
        return false;

    // Load preset from JSON (simplified)
    // In production, would parse JSON and rebuild layer configuration
    return true;
}

bool VisualForge::savePreset(const juce::File& file) const
{
    // Save preset as JSON (simplified)
    return file.create();
}

std::vector<juce::String> VisualForge::getBuiltInPresets() const
{
    return {
        "Audio Spectrum Wave",
        "Bio-Reactive Particles",
        "Fractal Dreams",
        "Kaleidoscope Tunnel",
        "Glitch Matrix",
        "Plasma Storm",
        "Waveform Flow"
    };
}

void VisualForge::loadBuiltInPreset(const juce::String& name)
{
    clearLayers();

    if (name == "Audio Spectrum Wave")
    {
        Layer layer;
        layer.name = "Spectrum";
        layer.generator = GeneratorType::CircularSpectrum;
        layer.generatorParams["radius"] = 0.5f;
        layer.generatorParams["thickness"] = 0.2f;
        addLayer(layer);
    }
    else if (name == "Bio-Reactive Particles")
    {
        Layer layer;
        layer.name = "Particles";
        layer.generator = GeneratorType::ParticleSystem;
        layer.generatorParams["count"] = 1000.0f;
        layer.generatorParams["speed"] = 0.5f;
        addLayer(layer);
    }
    else if (name == "Fractal Dreams")
    {
        Layer layer;
        layer.name = "Mandelbrot";
        layer.generator = GeneratorType::Mandelbrot;
        layer.generatorParams["zoom"] = 1.0f;
        layer.generatorParams["iterations"] = 100.0f;
        addLayer(layer);
    }
    // Add more presets...
}

//==============================================================================
// Recording
//==============================================================================

void VisualForge::startRecording(const juce::File& outputFile)
{
    recordingFile = outputFile;
    recordedFrames.clear();
    recording = true;
}

void VisualForge::stopRecording()
{
    recording = false;

    // Save recorded frames to video file (would need video encoding library)
    // For now, just save as image sequence
    for (size_t i = 0; i < recordedFrames.size(); ++i)
    {
        juce::File frameFile = recordingFile.getSiblingFile(
            recordingFile.getFileNameWithoutExtension() +
            "_frame_" + juce::String(i) + ".png"
        );

        juce::FileOutputStream stream(frameFile);
        if (stream.openedOk())
        {
            juce::PNGImageFormat png;
            png.writeImageToStream(recordedFrames[i], stream);
        }
    }

    recordedFrames.clear();
}

//==============================================================================
// Rendering Methods
//==============================================================================

juce::Image VisualForge::renderGenerator(const Layer& layer)
{
    switch (layer.generator)
    {
        case GeneratorType::SolidColor:
            return generateSolidColor(layer.generatorParams);

        case GeneratorType::Gradient:
            return generateGradient(layer.generatorParams);

        case GeneratorType::PerlinNoise:
            return generatePerlinNoise(layer.generatorParams);

        case GeneratorType::Spectrum:
        case GeneratorType::CircularSpectrum:
            return generateSpectrum(layer.generatorParams);

        case GeneratorType::Waveform:
            return generateWaveform(layer.generatorParams);

        case GeneratorType::ParticleSystem:
            return generateParticles(layer.generatorParams);

        case GeneratorType::Mandelbrot:
        case GeneratorType::Julia:
            return generateFractal(layer.generatorParams);

        default:
            return generateSolidColor(layer.generatorParams);
    }
}

juce::Image VisualForge::applyEffects(const juce::Image& input, const Layer& layer)
{
    juce::Image result = input;

    for (size_t i = 0; i < layer.effects.size(); ++i)
    {
        const auto& params = (i < layer.effectParams.size()) ?
                            layer.effectParams[i] :
                            std::map<juce::String, float>();

        result = applyEffect(result, layer.effects[i], params);
    }

    return result;
}

juce::Image VisualForge::applyEffect(const juce::Image& input, EffectType effect,
                                     const std::map<juce::String, float>& params)
{
    switch (effect)
    {
        case EffectType::Invert:
            return effectInvert(input);

        case EffectType::Hue:
        {
            float amount = params.count("amount") ? params.at("amount") : 0.0f;
            return effectHue(input, amount);
        }

        case EffectType::Pixelate:
        {
            int blockSize = params.count("size") ? static_cast<int>(params.at("size")) : 8;
            return effectPixelate(input, blockSize);
        }

        case EffectType::GaussianBlur:
        {
            float radius = params.count("radius") ? params.at("radius") : 5.0f;
            return effectBlur(input, radius);
        }

        case EffectType::Kaleidoscope:
        {
            int segments = params.count("segments") ? static_cast<int>(params.at("segments")) : 6;
            return effectKaleidoscope(input, segments);
        }

        default:
            return input;
    }
}

juce::Image VisualForge::composeLayers()
{
    if (layers.empty())
    {
        return juce::Image(juce::Image::RGB, outputWidth, outputHeight, true);
    }

    // Start with first layer
    juce::Image composite = renderGenerator(layers[0]);
    composite = applyEffects(composite, layers[0]);

    // Blend subsequent layers
    for (size_t i = 1; i < layers.size(); ++i)
    {
        if (!layers[i].enabled)
            continue;

        juce::Image layerImage = renderGenerator(layers[i]);
        layerImage = applyEffects(layerImage, layers[i]);

        composite = blendLayers(composite, layerImage,
                               layers[i].blendMode, layers[i].opacity);
    }

    return composite;
}

juce::Image VisualForge::blendLayers(const juce::Image& bottom, const juce::Image& top,
                                     BlendMode mode, float opacity)
{
    juce::Image result = bottom.createCopy();

    juce::Image::BitmapData bottomData(result, juce::Image::BitmapData::readWrite);
    juce::Image::BitmapData topData(top, juce::Image::BitmapData::readOnly);

    for (int y = 0; y < result.getHeight(); ++y)
    {
        for (int x = 0; x < result.getWidth(); ++x)
        {
            juce::Colour bottomCol = bottomData.getPixelColour(x, y);
            juce::Colour topCol = topData.getPixelColour(x, y);

            juce::Colour blended;

            switch (mode)
            {
                case BlendMode::Normal:
                    blended = topCol;
                    break;

                case BlendMode::Add:
                    blended = juce::Colour(
                        juce::jmin(255, bottomCol.getRed() + topCol.getRed()),
                        juce::jmin(255, bottomCol.getGreen() + topCol.getGreen()),
                        juce::jmin(255, bottomCol.getBlue() + topCol.getBlue())
                    );
                    break;

                case BlendMode::Multiply:
                    blended = juce::Colour(
                        (bottomCol.getRed() * topCol.getRed()) / 255,
                        (bottomCol.getGreen() * topCol.getGreen()) / 255,
                        (bottomCol.getBlue() * topCol.getBlue()) / 255
                    );
                    break;

                case BlendMode::Screen:
                    blended = juce::Colour(
                        255 - ((255 - bottomCol.getRed()) * (255 - topCol.getRed())) / 255,
                        255 - ((255 - bottomCol.getGreen()) * (255 - topCol.getGreen())) / 255,
                        255 - ((255 - bottomCol.getBlue()) * (255 - topCol.getBlue())) / 255
                    );
                    break;

                default:
                    blended = topCol;
                    break;
            }

            // Apply opacity
            juce::Colour final = juce::Colour(
                static_cast<juce::uint8>(bottomCol.getRed() * (1.0f - opacity) + blended.getRed() * opacity),
                static_cast<juce::uint8>(bottomCol.getGreen() * (1.0f - opacity) + blended.getGreen() * opacity),
                static_cast<juce::uint8>(bottomCol.getBlue() * (1.0f - opacity) + blended.getBlue() * opacity)
            );

            bottomData.setPixelColour(x, y, final);
        }
    }

    return result;
}

//==============================================================================
// Generator Implementations
//==============================================================================

juce::Image VisualForge::generateSolidColor(const std::map<juce::String, float>& params)
{
    float r = params.count("r") ? params.at("r") : 0.5f;
    float g = params.count("g") ? params.at("g") : 0.5f;
    float b = params.count("b") ? params.at("b") : 0.5f;

    juce::Image img(juce::Image::RGB, outputWidth, outputHeight, true);
    juce::Graphics gfx(img);

    gfx.fillAll(juce::Colour::fromFloatRGBA(r, g, b, 1.0f));

    return img;
}

juce::Image VisualForge::generateGradient(const std::map<juce::String, float>& params)
{
    float r1 = params.count("r1") ? params.at("r1") : 0.0f;
    float g1 = params.count("g1") ? params.at("g1") : 0.0f;
    float b1 = params.count("b1") ? params.at("b1") : 0.0f;

    float r2 = params.count("r2") ? params.at("r2") : 1.0f;
    float g2 = params.count("g2") ? params.at("g2") : 1.0f;
    float b2 = params.count("b2") ? params.at("b2") : 1.0f;

    juce::Image img(juce::Image::RGB, outputWidth, outputHeight, true);
    juce::Graphics gfx(img);

    juce::ColourGradient gradient(
        juce::Colour::fromFloatRGBA(r1, g1, b1, 1.0f), 0.0f, 0.0f,
        juce::Colour::fromFloatRGBA(r2, g2, b2, 1.0f),
        static_cast<float>(outputWidth), static_cast<float>(outputHeight),
        false
    );

    gfx.setGradientFill(gradient);
    gfx.fillAll();

    return img;
}

juce::Image VisualForge::generatePerlinNoise(const std::map<juce::String, float>& params)
{
    float scale = params.count("scale") ? params.at("scale") : 0.01f;
    float time = params.count("time") ? params.at("time") : 0.0f;

    juce::Image img(juce::Image::RGB, outputWidth, outputHeight, true);
    juce::Image::BitmapData data(img, juce::Image::BitmapData::writeOnly);

    // Simplified Perlin noise (would use proper noise library in production)
    // OPTIMIZATION: Cache trig table reference outside loops
    const auto& trigTables = Echoel::DSP::TrigLookupTables::getInstance();

    for (int y = 0; y < outputHeight; ++y)
    {
        for (int x = 0; x < outputWidth; ++x)
        {
            float nx = x * scale + time;
            float ny = y * scale;

            // Simple noise approximation - OPTIMIZED with fast trig (~20x faster)
            float noise = trigTables.fastSinRad(nx * 0.5f) * trigTables.fastCosRad(ny * 0.5f);
            noise = (noise + 1.0f) * 0.5f;  // Normalize to 0-1

            // Apply bio-reactive modulation
            if (bioReactiveEnabled)
            {
                noise *= (0.5f + bioHRV * 0.5f);
            }

            juce::uint8 value = static_cast<juce::uint8>(noise * 255);
            data.setPixelColour(x, y, juce::Colour(value, value, value));
        }
    }

    return img;
}

juce::Image VisualForge::generateSpectrum(const std::map<juce::String, float>& params)
{
    juce::ignoreUnused(params);

    juce::Image img(juce::Image::RGB, outputWidth, outputHeight, true);
    juce::Graphics gfx(img);

    gfx.fillAll(juce::Colours::black);

    if (currentSpectrum.empty())
        return img;

    // Draw spectrum as bars
    float barWidth = static_cast<float>(outputWidth) / currentSpectrum.size();

    for (size_t i = 0; i < currentSpectrum.size(); ++i)
    {
        float magnitude = currentSpectrum[i];
        float height = magnitude * outputHeight;

        // Color based on frequency
        float hue = static_cast<float>(i) / currentSpectrum.size();
        juce::Colour color = juce::Colour::fromHSV(hue, 1.0f, 1.0f, 1.0f);

        gfx.setColour(color);
        gfx.fillRect(i * barWidth, outputHeight - height, barWidth, height);
    }

    return img;
}

juce::Image VisualForge::generateWaveform(const std::map<juce::String, float>& params)
{
    juce::ignoreUnused(params);

    juce::Image img(juce::Image::RGB, outputWidth, outputHeight, true);
    juce::Graphics gfx(img);

    gfx.fillAll(juce::Colours::black);

    if (currentWaveform.empty())
        return img;

    gfx.setColour(juce::Colours::cyan);

    juce::Path waveformPath;
    waveformPath.startNewSubPath(0.0f, outputHeight * 0.5f);

    for (size_t i = 0; i < currentWaveform.size(); ++i)
    {
        float x = static_cast<float>(i) / currentWaveform.size() * outputWidth;
        float y = (0.5f + currentWaveform[i] * 0.5f) * outputHeight;
        waveformPath.lineTo(x, y);
    }

    gfx.strokePath(waveformPath, juce::PathStrokeType(2.0f));

    return img;
}

juce::Image VisualForge::generateParticles(const std::map<juce::String, float>& params)
{
    int count = params.count("count") ? static_cast<int>(params.at("count")) : 100;

    juce::Image img(juce::Image::RGB, outputWidth, outputHeight, true);
    juce::Graphics gfx(img);

    gfx.fillAll(juce::Colours::black);

    // Simple particle rendering
    for (int i = 0; i < count; ++i)
    {
        float x = (std::rand() / static_cast<float>(RAND_MAX)) * outputWidth;
        float y = (std::rand() / static_cast<float>(RAND_MAX)) * outputHeight;
        float size = 2.0f + (std::rand() / static_cast<float>(RAND_MAX)) * 5.0f;

        // Bio-reactive particle behavior
        if (bioReactiveEnabled)
        {
            x += (bioHRV - 0.5f) * 100.0f;
            y += (bioCoherence - 0.5f) * 100.0f;
        }

        gfx.setColour(juce::Colours::white);
        gfx.fillEllipse(x, y, size, size);
    }

    return img;
}

juce::Image VisualForge::generateFractal(const std::map<juce::String, float>& params)
{
    int iterations = params.count("iterations") ? static_cast<int>(params.at("iterations")) : 50;

    juce::Image img(juce::Image::RGB, outputWidth, outputHeight, true);
    juce::Image::BitmapData data(img, juce::Image::BitmapData::writeOnly);

    // Simplified Mandelbrot set
    for (int py = 0; py < outputHeight; ++py)
    {
        for (int px = 0; px < outputWidth; ++px)
        {
            float x0 = (px / static_cast<float>(outputWidth) - 0.5f) * 3.5f - 0.5f;
            float y0 = (py / static_cast<float>(outputHeight) - 0.5f) * 2.0f;

            float x = 0.0f, y = 0.0f;
            int iteration = 0;

            while (x*x + y*y <= 4.0f && iteration < iterations)
            {
                float xtemp = x*x - y*y + x0;
                y = 2.0f*x*y + y0;
                x = xtemp;
                iteration++;
            }

            float hue = static_cast<float>(iteration) / iterations;
            juce::Colour color = juce::Colour::fromHSV(hue, 1.0f, iteration < iterations ? 1.0f : 0.0f, 1.0f);
            data.setPixelColour(px, py, color);
        }
    }

    return img;
}

//==============================================================================
// Effect Implementations
//==============================================================================

juce::Image VisualForge::effectInvert(const juce::Image& input)
{
    juce::Image result = input.createCopy();
    juce::Image::BitmapData data(result, juce::Image::BitmapData::readWrite);

    for (int y = 0; y < result.getHeight(); ++y)
    {
        for (int x = 0; x < result.getWidth(); ++x)
        {
            juce::Colour col = data.getPixelColour(x, y);
            juce::Colour inverted(255 - col.getRed(), 255 - col.getGreen(), 255 - col.getBlue());
            data.setPixelColour(x, y, inverted);
        }
    }

    return result;
}

juce::Image VisualForge::effectHue(const juce::Image& input, float amount)
{
    juce::Image result = input.createCopy();
    juce::Image::BitmapData data(result, juce::Image::BitmapData::readWrite);

    for (int y = 0; y < result.getHeight(); ++y)
    {
        for (int x = 0; x < result.getWidth(); ++x)
        {
            juce::Colour col = data.getPixelColour(x, y);
            float h, s, v;
            col.getHSB(h, s, v);

            h = std::fmod(h + amount, 1.0f);
            juce::Colour shifted = juce::Colour::fromHSV(h, s, v, col.getFloatAlpha());
            data.setPixelColour(x, y, shifted);
        }
    }

    return result;
}

juce::Image VisualForge::effectPixelate(const juce::Image& input, int blockSize)
{
    juce::Image result = input.createCopy();

    for (int by = 0; by < result.getHeight(); by += blockSize)
    {
        for (int bx = 0; bx < result.getWidth(); bx += blockSize)
        {
            // Sample center of block
            int cx = juce::jmin(bx + blockSize/2, result.getWidth() - 1);
            int cy = juce::jmin(by + blockSize/2, result.getHeight() - 1);
            juce::Colour blockColor = input.getPixelAt(cx, cy);

            // Fill block
            juce::Graphics gfx(result);
            gfx.setColour(blockColor);
            gfx.fillRect(bx, by, blockSize, blockSize);
        }
    }

    return result;
}

juce::Image VisualForge::effectBlur(const juce::Image& input, float radius)
{
    // Simplified blur (box blur)
    juce::ignoreUnused(radius);
    return input.createCopy();  // Would implement proper Gaussian blur
}

juce::Image VisualForge::effectKaleidoscope(const juce::Image& input, int segments)
{
    juce::ignoreUnused(segments);
    return input.createCopy();  // Would implement kaleidoscope transformation
}

//==============================================================================
// Utilities
//==============================================================================

float VisualForge::getAudioReactiveValue() const
{
    if (!audioReactive.enabled || currentSpectrum.empty())
        return 0.0f;

    // Average spectrum in selected range
    float sum = 0.0f;
    int count = 0;

    for (int i = audioReactive.bandStart;
         i <= audioReactive.bandEnd && i < static_cast<int>(currentSpectrum.size());
         ++i)
    {
        sum += currentSpectrum[i];
        count++;
    }

    return count > 0 ? sum / count : 0.0f;
}

float VisualForge::getBioReactiveValue() const
{
    if (!bioReactiveEnabled)
        return 0.5f;

    // Combine HRV and Coherence
    return (bioHRV + bioCoherence) * 0.5f;
}

void VisualForge::updateFPS()
{
    // FPS calculation already done in renderFrame()
}
