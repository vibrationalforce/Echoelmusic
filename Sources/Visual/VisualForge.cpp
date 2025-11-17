#include "VisualForge.h"

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

        case GeneratorType::FlowField:
            return generateFlowField(layer.generatorParams);

        case GeneratorType::Cube3D:
            return generate3DCube(layer.generatorParams);

        case GeneratorType::Sphere3D:
            return generate3DSphere(layer.generatorParams);

        case GeneratorType::Torus3D:
            return generate3DTorus(layer.generatorParams);

        case GeneratorType::Mandelbrot:
        case GeneratorType::Julia:
            return generateFractal(layer.generatorParams);

        case GeneratorType::LSystem:
        case GeneratorType::FractalTree:
            return generateLSystem(layer.generatorParams);

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
    for (int y = 0; y < outputHeight; ++y)
    {
        for (int x = 0; x < outputWidth; ++x)
        {
            float nx = x * scale + time;
            float ny = y * scale;

            // Simple noise approximation
            float noise = std::sin(nx * 0.5f) * std::cos(ny * 0.5f);
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
// Advanced Generator Implementations
//==============================================================================

juce::Image VisualForge::generateFlowField(const std::map<juce::String, float>& params)
{
    // FLOW FIELD PARTICLE SYSTEM - UP TO 100,000 PARTICLES
    // Uses Perlin noise to create organic, flowing particle motion

    int particleCount = params.count("count") ? static_cast<int>(params.at("count")) : 10000;
    particleCount = juce::jlimit(1000, 100000, particleCount); // Max 100k particles!

    float flowStrength = params.count("flow") ? params.at("flow") : 0.1f;
    float time = params.count("time") ? params.at("time") : 0.0f;

    juce::Image img(juce::Image::ARGB, outputWidth, outputHeight, true);
    juce::Graphics gfx(img);

    gfx.fillAll(juce::Colours::black);

    // Particle structure
    struct Particle
    {
        float x, y;
        float vx, vy;
        juce::Colour color;
        float life;
        float size;
    };

    static std::vector<Particle> particles;

    // Initialize particles if needed
    if (particles.size() != static_cast<size_t>(particleCount))
    {
        particles.clear();
        particles.reserve(particleCount);

        for (int i = 0; i < particleCount; ++i)
        {
            Particle p;
            p.x = juce::Random::getSystemRandom().nextFloat() * outputWidth;
            p.y = juce::Random::getSystemRandom().nextFloat() * outputHeight;
            p.vx = 0.0f;
            p.vy = 0.0f;
            p.life = juce::Random::getSystemRandom().nextFloat();
            p.size = 1.0f + juce::Random::getSystemRandom().nextFloat() * 2.0f;

            // Audio-reactive color
            float hue = currentSpectrum.empty() ? p.life :
                       currentSpectrum[i % currentSpectrum.size()];
            p.color = juce::Colour::fromHSV(hue, 0.8f, 0.9f, 0.6f);

            particles.push_back(p);
        }
    }

    // Update and render particles
    for (auto& p : particles)
    {
        // PERLIN NOISE FLOW FIELD
        // Calculate flow direction based on position
        float noiseX = (p.x * 0.005f) + time * 0.1f;
        float noiseY = (p.y * 0.005f) + time * 0.1f;

        // Simplified 2D Perlin noise
        float angle = std::sin(noiseX * 3.14159f) * std::cos(noiseY * 3.14159f) * 6.28318f;

        // Bio-reactive flow modulation
        if (bioReactiveEnabled)
        {
            angle += (bioHRV - 0.5f) * 3.14159f;
            flowStrength *= (0.5f + bioCoherence * 0.5f);
        }

        // Audio-reactive flow
        if (!currentSpectrum.empty())
        {
            int specIndex = static_cast<int>(p.x / outputWidth * currentSpectrum.size());
            specIndex = juce::jlimit(0, static_cast<int>(currentSpectrum.size()) - 1, specIndex);
            flowStrength *= (0.8f + currentSpectrum[specIndex] * 0.4f);
        }

        // Update velocity based on flow field
        p.vx += std::cos(angle) * flowStrength;
        p.vy += std::sin(angle) * flowStrength;

        // Damping
        p.vx *= 0.95f;
        p.vy *= 0.95f;

        // Update position
        p.x += p.vx;
        p.y += p.vy;

        // Wrap around edges
        if (p.x < 0) p.x += outputWidth;
        if (p.x >= outputWidth) p.x -= outputWidth;
        if (p.y < 0) p.y += outputHeight;
        if (p.y >= outputHeight) p.y -= outputHeight;

        // Update life
        p.life += 0.01f;
        if (p.life > 1.0f) p.life -= 1.0f;

        // Update color based on life and audio
        float hue = p.life;
        if (!currentSpectrum.empty())
        {
            int specIndex = static_cast<int>(p.life * currentSpectrum.size());
            specIndex = juce::jlimit(0, static_cast<int>(currentSpectrum.size()) - 1, specIndex);
            hue = currentSpectrum[specIndex];
        }
        p.color = juce::Colour::fromHSV(hue, 0.8f, 0.9f, 0.6f);

        // Render particle with motion blur
        gfx.setColour(p.color);
        gfx.fillEllipse(p.x - p.size/2, p.y - p.size/2, p.size, p.size);

        // Trail effect
        gfx.setColour(p.color.withAlpha(0.3f));
        gfx.drawLine(p.x, p.y, p.x - p.vx * 2, p.y - p.vy * 2, 0.5f);
    }

    return img;
}

juce::Image VisualForge::generate3DCube(const std::map<juce::String, float>& params)
{
    // 3D ROTATING CUBE WITH AUDIO-REACTIVE ROTATION

    float rotationX = params.count("rotX") ? params.at("rotX") : 0.0f;
    float rotationY = params.count("rotY") ? params.at("rotY") : 0.0f;
    float rotationZ = params.count("rotZ") ? params.at("rotZ") : 0.0f;
    float scale = params.count("scale") ? params.at("scale") : 100.0f;

    // Bio-reactive rotation
    if (bioReactiveEnabled)
    {
        rotationY += bioHRV * 3.14159f;
        rotationX += bioCoherence * 1.5708f;
        scale *= (0.8f + bioHRV * 0.4f);
    }

    // Audio-reactive rotation
    if (!currentSpectrum.empty())
    {
        float avgSpec = 0.0f;
        for (float s : currentSpectrum) avgSpec += s;
        avgSpec /= currentSpectrum.size();
        rotationZ += avgSpec * 6.28318f;
        scale *= (1.0f + avgSpec * 0.5f);
    }

    juce::Image img(juce::Image::ARGB, outputWidth, outputHeight, true);
    juce::Graphics gfx(img);

    gfx.fillAll(juce::Colours::black);

    // Define cube vertices
    std::vector<juce::Point<float>> vertices = {
        {-1, -1, -1}, {1, -1, -1}, {1, 1, -1}, {-1, 1, -1},
        {-1, -1, 1}, {1, -1, 1}, {1, 1, 1}, {-1, 1, 1}
    };

    // Rotate and project vertices
    std::vector<juce::Point<float>> projected;
    for (auto& v : vertices)
    {
        // 3D rotation matrices
        float x = v.x, y = v.y, z = v.z;

        // Rotate X
        float y1 = y * std::cos(rotationX) - z * std::sin(rotationX);
        float z1 = y * std::sin(rotationX) + z * std::cos(rotationX);

        // Rotate Y
        float x2 = x * std::cos(rotationY) + z1 * std::sin(rotationY);
        float z2 = -x * std::sin(rotationY) + z1 * std::cos(rotationY);

        // Rotate Z
        float x3 = x2 * std::cos(rotationZ) - y1 * std::sin(rotationZ);
        float y3 = x2 * std::sin(rotationZ) + y1 * std::cos(rotationZ);

        // Perspective projection
        float perspective = 300.0f / (300.0f + z2);
        float px = x3 * scale * perspective + outputWidth / 2;
        float py = y3 * scale * perspective + outputHeight / 2;

        projected.push_back({px, py});
    }

    // Draw cube edges with frequency-reactive colors
    const int edges[][2] = {
        {0,1}, {1,2}, {2,3}, {3,0},  // Front face
        {4,5}, {5,6}, {6,7}, {7,4},  // Back face
        {0,4}, {1,5}, {2,6}, {3,7}   // Connecting edges
    };

    for (int i = 0; i < 12; ++i)
    {
        float hue = static_cast<float>(i) / 12.0f;
        if (!currentSpectrum.empty())
        {
            int specIndex = i * currentSpectrum.size() / 12;
            hue = currentSpectrum[specIndex];
        }

        gfx.setColour(juce::Colour::fromHSV(hue, 0.9f, 1.0f, 1.0f));
        gfx.drawLine(projected[edges[i][0]].x, projected[edges[i][0]].y,
                     projected[edges[i][1]].x, projected[edges[i][1]].y, 3.0f);
    }

    return img;
}

juce::Image VisualForge::generate3DSphere(const std::map<juce::String, float>& params)
{
    // 3D SPHERE WITH AUDIO-REACTIVE DISPLACEMENT

    float rotation = params.count("rotation") ? params.at("rotation") : 0.0f;
    float radius = params.count("radius") ? params.at("radius") : 150.0f;
    int resolution = params.count("resolution") ? static_cast<int>(params.at("resolution")) : 32;

    juce::Image img(juce::Image::ARGB, outputWidth, outputHeight, true);
    juce::Graphics gfx(img);

    gfx.fillAll(juce::Colours::black);

    // Generate sphere vertices using spherical coordinates
    for (int lat = 0; lat < resolution; ++lat)
    {
        for (int lon = 0; lon < resolution; ++lon)
        {
            float theta = lat * 3.14159f / resolution;
            float phi = lon * 2.0f * 3.14159f / resolution + rotation;

            // Spherical to Cartesian conversion
            float x = radius * std::sin(theta) * std::cos(phi);
            float y = radius * std::sin(theta) * std::sin(phi);
            float z = radius * std::cos(theta);

            // Audio-reactive displacement
            float displacement = 1.0f;
            if (!currentSpectrum.empty())
            {
                int specIndex = (lat * resolution + lon) % currentSpectrum.size();
                displacement += currentSpectrum[specIndex] * 0.3f;
            }

            // Bio-reactive pulsing
            if (bioReactiveEnabled)
            {
                displacement *= (0.9f + bioCoherence * 0.2f);
            }

            x *= displacement;
            y *= displacement;
            z *= displacement;

            // Perspective projection
            float perspective = 400.0f / (400.0f + z);
            float px = x * perspective + outputWidth / 2;
            float py = y * perspective + outputHeight / 2;

            // Color based on position and audio
            float hue = static_cast<float>(lat) / resolution;
            if (!currentSpectrum.empty())
            {
                int specIndex = lat * currentSpectrum.size() / resolution;
                hue = currentSpectrum[specIndex];
            }

            gfx.setColour(juce::Colour::fromHSV(hue, 0.8f, 0.9f, 0.8f));
            gfx.fillEllipse(px - 2, py - 2, 4, 4);
        }
    }

    return img;
}

juce::Image VisualForge::generate3DTorus(const std::map<juce::String, float>& params)
{
    // 3D TORUS WITH BIO-REACTIVE PARTICLE EMISSION

    float rotation = params.count("rotation") ? params.at("rotation") : 0.0f;
    float majorRadius = params.count("majorRadius") ? params.at("majorRadius") : 120.0f;
    float minorRadius = params.count("minorRadius") ? params.at("minorRadius") : 40.0f;
    int resolution = 64;

    juce::Image img(juce::Image::ARGB, outputWidth, outputHeight, true);
    juce::Graphics gfx(img);

    gfx.fillAll(juce::Colours::black);

    // Generate torus vertices
    for (int u = 0; u < resolution; ++u)
    {
        for (int v = 0; v < resolution; ++v)
        {
            float theta = u * 2.0f * 3.14159f / resolution + rotation;
            float phi = v * 2.0f * 3.14159f / resolution;

            // Torus parametric equations
            float x = (majorRadius + minorRadius * std::cos(phi)) * std::cos(theta);
            float y = (majorRadius + minorRadius * std::cos(phi)) * std::sin(theta);
            float z = minorRadius * std::sin(phi);

            // Bio-reactive modulation
            if (bioReactiveEnabled)
            {
                float modulation = 1.0f + (bioHRV - 0.5f) * 0.3f;
                x *= modulation;
                y *= modulation;
            }

            // Perspective projection
            float perspective = 500.0f / (500.0f + z);
            float px = x * perspective + outputWidth / 2;
            float py = y * perspective + outputHeight / 2;

            // Frequency-reactive color
            float hue = static_cast<float>(v) / resolution;
            if (!currentSpectrum.empty())
            {
                int specIndex = v * currentSpectrum.size() / resolution;
                hue = currentSpectrum[specIndex];
            }

            gfx.setColour(juce::Colour::fromHSV(hue, 0.9f, 1.0f, 0.9f));
            gfx.fillEllipse(px - 1.5f, py - 1.5f, 3, 3);
        }
    }

    // Emit particles from torus (bio-reactive)
    if (bioReactiveEnabled)
    {
        int particleCount = static_cast<int>(bioCoherence * 100);
        for (int i = 0; i < particleCount; ++i)
        {
            float theta = juce::Random::getSystemRandom().nextFloat() * 6.28318f;
            float phi = juce::Random::getSystemRandom().nextFloat() * 6.28318f;

            float x = (majorRadius + minorRadius * std::cos(phi)) * std::cos(theta);
            float y = (majorRadius + minorRadius * std::cos(phi)) * std::sin(theta);
            float z = minorRadius * std::sin(phi);

            float perspective = 500.0f / (500.0f + z);
            float px = x * perspective + outputWidth / 2;
            float py = y * perspective + outputHeight / 2;

            gfx.setColour(juce::Colours::white.withAlpha(0.6f));
            gfx.fillEllipse(px - 1, py - 1, 2, 2);
        }
    }

    return img;
}

juce::Image VisualForge::generateLSystem(const std::map<juce::String, float>& params)
{
    // L-SYSTEM FRACTAL GENERATOR
    // Creates organic, plant-like fractals using Lindenmayer systems

    int iterations = params.count("iterations") ? static_cast<int>(params.at("iterations")) : 5;
    float angle = params.count("angle") ? params.at("angle") : 25.0f;
    float length = params.count("length") ? params.at("length") : 10.0f;

    // Bio-reactive parameters
    if (bioReactiveEnabled)
    {
        angle += bioCoherence * 20.0f; // More coherence = more branching
        length *= (0.8f + bioHRV * 0.4f);
    }

    iterations = juce::jlimit(1, 7, iterations); // Max 7 iterations for performance

    juce::Image img(juce::Image::ARGB, outputWidth, outputHeight, true);
    juce::Graphics gfx(img);

    gfx.fillAll(juce::Colours::black);

    // L-System rules (Fractal Tree)
    // Axiom: "F"
    // Rules: F -> FF+[+F-F-F]-[-F+F+F]
    juce::String axiom = "F";
    juce::String result = axiom;

    // Apply production rules iteratively
    for (int iter = 0; iter < iterations; ++iter)
    {
        juce::String next = "";
        for (int i = 0; i < result.length(); ++i)
        {
            juce::juce_wchar c = result[i];
            if (c == 'F')
            {
                // Tree branching rule
                next += "FF+[+F-F-F]-[-F+F+F]";
            }
            else
            {
                next += c;
            }
        }
        result = next;
    }

    // Interpret the L-system string and draw
    struct TurtleState
    {
        float x, y;
        float heading; // Angle in radians
    };

    std::vector<TurtleState> stack;
    TurtleState turtle;
    turtle.x = outputWidth / 2.0f;
    turtle.y = outputHeight - 50.0f;
    turtle.heading = -90.0f * 3.14159f / 180.0f; // Start facing up

    float angleRad = angle * 3.14159f / 180.0f;

    // Draw the L-system
    for (int i = 0; i < result.length() && i < 10000; ++i) // Limit for performance
    {
        juce::juce_wchar c = result[i];

        if (c == 'F')
        {
            // Draw forward
            float newX = turtle.x + length * std::cos(turtle.heading);
            float newY = turtle.y + length * std::sin(turtle.heading);

            // Color based on depth and audio
            float hue = static_cast<float>(stack.size()) / 10.0f;
            if (!currentSpectrum.empty())
            {
                int specIndex = stack.size() % currentSpectrum.size();
                hue = currentSpectrum[specIndex];
            }

            gfx.setColour(juce::Colour::fromHSV(hue, 0.7f, 0.9f, 0.8f));
            gfx.drawLine(turtle.x, turtle.y, newX, newY, 1.5f);

            turtle.x = newX;
            turtle.y = newY;
        }
        else if (c == '+')
        {
            // Turn right
            turtle.heading += angleRad;
        }
        else if (c == '-')
        {
            // Turn left
            turtle.heading -= angleRad;
        }
        else if (c == '[')
        {
            // Push state
            stack.push_back(turtle);
        }
        else if (c == ']')
        {
            // Pop state
            if (!stack.empty())
            {
                turtle = stack.back();
                stack.pop_back();
            }
        }
    }

    return img;
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
