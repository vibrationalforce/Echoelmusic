#include "SpectralGranularSynthUI.h"

//==============================================================================
// GrainCloudVisualizer Implementation
//==============================================================================

SpectralGranularSynthUI::GrainCloudVisualizer::GrainCloudVisualizer()
    : fftData(2048, 0.0f)
{
    setOpaque(false);
}

SpectralGranularSynthUI::GrainCloudVisualizer::~GrainCloudVisualizer() = default;

void SpectralGranularSynthUI::GrainCloudVisualizer::paint(juce::Graphics& g)
{
    // Dark background with subtle gradient
    g.setGradientFill(juce::ColourGradient(
        juce::Colour(0xff0a0a0f), 0.0f, 0.0f,
        juce::Colour(0xff1a1a2e), static_cast<float>(getWidth()), static_cast<float>(getHeight()), false));
    g.fillAll();

    renderGrainCloud(g);
}

void SpectralGranularSynthUI::GrainCloudVisualizer::resized()
{
    // Update grain positions on resize if needed
}

void SpectralGranularSynthUI::GrainCloudVisualizer::renderGrainCloud(juce::Graphics& g)
{
    g.saveState();

    // Enable anti-aliasing for smooth rendering
    g.setImageResamplingQuality(juce::Graphics::highResamplingQuality);

    // Draw connections between nearby grains
    for (size_t i = 0; i < grains.size(); ++i)
    {
        for (size_t j = i + 1; j < grains.size(); ++j)
        {
            float dx = grains[i].x - grains[j].x;
            float dy = grains[i].y - grains[j].y;
            float distance = std::sqrt(dx * dx + dy * dy);

            if (distance < 80.0f)
            {
                float alpha = (1.0f - (distance / 80.0f)) * 0.3f * grains[i].lifespan;
                g.setColour(juce::Colours::cyan.withAlpha(alpha));
                g.drawLine(grains[i].x, grains[i].y, grains[j].x, grains[j].y, 1.0f);
            }
        }
    }

    // Draw grains
    for (const auto& grain : grains)
    {
        if (grain.lifespan > 0.0f)
        {
            // Calculate visual size based on grain size and lifespan
            float visualSize = grain.size * grain.lifespan;

            // Glow effect
            g.setGradientFill(juce::ColourGradient(
                grain.color.withAlpha(grain.brightness * grain.lifespan * 0.5f),
                grain.x, grain.y,
                grain.color.withAlpha(0.0f),
                grain.x + visualSize, grain.y + visualSize, true));
            g.fillEllipse(grain.x - visualSize, grain.y - visualSize, visualSize * 2, visualSize * 2);

            // Core particle
            g.setColour(grain.color.withAlpha(grain.brightness * grain.lifespan));
            g.fillEllipse(grain.x - visualSize * 0.5f, grain.y - visualSize * 0.5f, visualSize, visualSize);
        }
    }

    g.restoreState();
}

void SpectralGranularSynthUI::GrainCloudVisualizer::updateGrains(const float* audioData, int numSamples)
{
    if (numSamples == 0 || audioData == nullptr)
        return;

    // Prepare FFT data
    const int fftSize = 1024;
    for (int i = 0; i < fftSize; ++i)
    {
        fftData[i] = audioData[i % numSamples];
    }

    // Perform FFT
    fft.performFrequencyOnlyForwardTransform(fftData.data());

    // Spawn new grains based on spectral peaks
    spawnGrainsFromSpectrum(fftData);

    // Update existing grains
    for (auto& grain : grains)
    {
        grain.lifespan -= 0.01f;
        grain.y -= grain.size * 0.5f; // Float upward
        grain.x += (juce::Random::getSystemRandom().nextFloat() - 0.5f) * 0.5f; // Slight drift
        grain.z += (juce::Random::getSystemRandom().nextFloat() - 0.5f) * 2.0f;
    }

    // Remove dead grains
    grains.erase(
        std::remove_if(grains.begin(), grains.end(),
                      [](const Grain& g) { return g.lifespan <= 0.0f; }),
        grains.end());

    // Limit grain count for performance
    if (grains.size() > 1000)
    {
        grains.erase(grains.begin(), grains.begin() + static_cast<long>(grains.size() - 1000));
    }

    repaint();
}

void SpectralGranularSynthUI::GrainCloudVisualizer::spawnGrainsFromSpectrum(const std::vector<float>& spectrum)
{
    const int numBands = 32;
    for (int i = 0; i < numBands; ++i)
    {
        float magnitude = spectrum[i * 16];
        if (magnitude > 0.1f)
        {
            Grain newGrain;
            newGrain.x = (static_cast<float>(i) / static_cast<float>(numBands)) * static_cast<float>(getWidth());
            newGrain.y = static_cast<float>(getHeight()) / 2.0f;
            newGrain.z = juce::Random::getSystemRandom().nextFloat() * 100.0f;
            newGrain.size = magnitude * 10.0f;
            newGrain.brightness = magnitude;

            // Copy spectral content
            for (int j = 0; j < 32; ++j)
            {
                newGrain.spectralContent[j] = spectrum[j];
            }

            // Color based on frequency
            float hue = static_cast<float>(i) / static_cast<float>(numBands);
            newGrain.color = juce::Colour::fromHSV(hue, 0.8f, magnitude, 1.0f);
            newGrain.lifespan = 1.0f;

            grains.push_back(newGrain);
        }
    }
}

//==============================================================================
// SpectralAnalyzer Implementation
//==============================================================================

SpectralGranularSynthUI::SpectralAnalyzer::SpectralAnalyzer()
{
    setOpaque(true);
    magnitudes.fill(0.0f);
}

SpectralGranularSynthUI::SpectralAnalyzer::~SpectralAnalyzer() = default;

void SpectralGranularSynthUI::SpectralAnalyzer::paint(juce::Graphics& g)
{
    // Background gradient
    g.setGradientFill(juce::ColourGradient(
        juce::Colour(0xff1a1a2e), 0.0f, 0.0f,
        juce::Colour(0xff0f0f1e), 0.0f, static_cast<float>(getHeight()), false));
    g.fillAll();

    const int numBars = 512;
    const float barWidth = static_cast<float>(getWidth()) / static_cast<float>(numBars);

    // Draw spectrum bars with glow effect
    for (int i = 0; i < numBars; ++i)
    {
        float x = static_cast<float>(i) * barWidth;
        float barHeight = magnitudes[i] * static_cast<float>(getHeight());

        // Frequency-based color (red to purple)
        float hue = (static_cast<float>(i) / static_cast<float>(numBars)) * 0.8f;
        auto color = juce::Colour::fromHSV(hue, 0.9f, 0.9f, 1.0f);

        // Glow effect
        g.setColour(color.withAlpha(0.3f));
        g.fillRect(x - 2.0f, static_cast<float>(getHeight()) - barHeight - 2.0f, barWidth + 4.0f, barHeight + 4.0f);

        // Main bar
        g.setColour(color);
        g.fillRect(x, static_cast<float>(getHeight()) - barHeight, barWidth, barHeight);
    }

    // Peak hold line
    g.setColour(juce::Colours::white.withAlpha(0.8f));
    g.strokePath(spectrumPath, juce::PathStrokeType(2.0f));

    // Draw frequency grid
    g.setColour(juce::Colours::white.withAlpha(0.1f));
    for (int i = 1; i < 10; ++i)
    {
        float y = static_cast<float>(getHeight()) * static_cast<float>(i) / 10.0f;
        g.drawHorizontalLine(static_cast<int>(y), 0.0f, static_cast<float>(getWidth()));
    }
}

void SpectralGranularSynthUI::SpectralAnalyzer::updateSpectrum(const float* fftData, int numBins)
{
    spectrumPath.clear();
    spectrumPath.startNewSubPath(0.0f, static_cast<float>(getHeight()));

    for (int i = 0; i < numBins && i < 512; ++i)
    {
        // Smoothing
        magnitudes[i] = magnitudes[i] * 0.7f + fftData[i] * 0.3f;

        // Convert to dB
        float db = 20.0f * std::log10(magnitudes[i] + 0.00001f);
        float normalized = juce::jmap(db, -60.0f, 0.0f, 0.0f, 1.0f);

        float x = (static_cast<float>(i) / 512.0f) * static_cast<float>(getWidth());
        float y = static_cast<float>(getHeight()) - (normalized * static_cast<float>(getHeight()));

        if (i == 0)
            spectrumPath.startNewSubPath(x, y);
        else
            spectrumPath.lineTo(x, y);
    }

    repaint();
}

//==============================================================================
// SwarmVisualizer Implementation
//==============================================================================

SpectralGranularSynthUI::SwarmVisualizer::SwarmVisualizer()
{
    setOpaque(false);

    // Initialize swarm particles
    for (int i = 0; i < 100; ++i)
    {
        Particle p;
        p.position = juce::Point<float>(
            juce::Random::getSystemRandom().nextFloat() * 400.0f,
            juce::Random::getSystemRandom().nextFloat() * 300.0f
        );
        p.velocity = juce::Point<float>(0.0f, 0.0f);
        p.phase = juce::Random::getSystemRandom().nextFloat() * juce::MathConstants<float>::twoPi;
        p.frequency = 0.05f + juce::Random::getSystemRandom().nextFloat() * 0.05f;
        p.colour = juce::Colour::fromHSV(
            juce::Random::getSystemRandom().nextFloat(),
            0.7f, 0.9f, 1.0f
        );
        swarm.push_back(p);
    }

    attractorPoint = juce::Point<float>(200.0f, 150.0f);
    startTimer(33); // ~30 FPS
}

SpectralGranularSynthUI::SwarmVisualizer::~SwarmVisualizer()
{
    stopTimer();
}

void SpectralGranularSynthUI::SwarmVisualizer::paint(juce::Graphics& g)
{
    g.fillAll(juce::Colour(0xff0a0a0f));

    // Draw connections between nearby particles
    g.setColour(juce::Colours::cyan.withAlpha(0.2f));
    for (size_t i = 0; i < swarm.size(); ++i)
    {
        for (size_t j = i + 1; j < swarm.size(); ++j)
        {
            float distance = swarm[i].position.getDistanceFrom(swarm[j].position);
            if (distance < 50.0f * swarmDensity)
            {
                float alpha = 1.0f - (distance / (50.0f * swarmDensity));
                g.setColour(juce::Colours::cyan.withAlpha(alpha * 0.3f));
                g.drawLine(swarm[i].position.x, swarm[i].position.y,
                          swarm[j].position.x, swarm[j].position.y);
            }
        }
    }

    // Draw particles
    for (const auto& particle : swarm)
    {
        float size = 3.0f + std::sin(particle.phase) * 2.0f;
        g.setColour(particle.colour);
        g.fillEllipse(particle.position.x - size / 2.0f,
                     particle.position.y - size / 2.0f, size, size);
    }
}

void SpectralGranularSynthUI::SwarmVisualizer::timerCallback()
{
    updateSwarm();
    repaint();
}

void SpectralGranularSynthUI::SwarmVisualizer::updateSwarm()
{
    for (auto& particle : swarm)
    {
        // Attraction to center point
        auto toAttractor = attractorPoint - particle.position;
        particle.velocity += toAttractor * 0.001f * (1.0f - swarmChaos);

        // Random movement
        particle.velocity.x += (juce::Random::getSystemRandom().nextFloat() - 0.5f) * swarmChaos;
        particle.velocity.y += (juce::Random::getSystemRandom().nextFloat() - 0.5f) * swarmChaos;

        // Damping
        particle.velocity *= 0.98f;

        // Update position
        particle.position += particle.velocity;

        // Wrap around edges
        if (particle.position.x < 0.0f) particle.position.x = static_cast<float>(getWidth());
        if (particle.position.x > static_cast<float>(getWidth())) particle.position.x = 0.0f;
        if (particle.position.y < 0.0f) particle.position.y = static_cast<float>(getHeight());
        if (particle.position.y > static_cast<float>(getHeight())) particle.position.y = 0.0f;

        // Update phase
        particle.phase += particle.frequency;
    }
}

void SpectralGranularSynthUI::SwarmVisualizer::setSwarmParameters(float density, float chaos)
{
    swarmDensity = density;
    swarmChaos = chaos;
}

//==============================================================================
// TextureVisualizer Implementation
//==============================================================================

SpectralGranularSynthUI::TextureVisualizer::TextureVisualizer()
    : textureImage(juce::Image::ARGB, 256, 256, true)
{
    setOpaque(true);
    updateTexture(1.0f, 1.0f, 10.0f);
}

SpectralGranularSynthUI::TextureVisualizer::~TextureVisualizer() = default;

void SpectralGranularSynthUI::TextureVisualizer::paint(juce::Graphics& g)
{
    g.drawImageWithin(textureImage, 0, 0, getWidth(), getHeight(),
                     juce::RectanglePlacement::stretchToFit);
}

void SpectralGranularSynthUI::TextureVisualizer::updateTexture(float brightness, float contrast, float complexity)
{
    for (int y = 0; y < 256; ++y)
    {
        for (int x = 0; x < 256; ++x)
        {
            // Perlin noise-like texture generation
            float noise = 0.0f;
            float amplitude = 1.0f;
            float frequency = complexity * 0.01f;

            for (int octave = 0; octave < 4; ++octave)
            {
                noise += std::sin(static_cast<float>(x) * frequency) *
                        std::cos(static_cast<float>(y) * frequency) * amplitude;
                amplitude *= 0.5f;
                frequency *= 2.0f;
            }

            noise = (noise + 1.0f) * 0.5f; // Normalize to 0-1
            noise = std::pow(noise, contrast);
            noise *= brightness;

            textureData[y][x] = noise;

            auto value = static_cast<uint8_t>(noise * 255.0f);
            textureImage.setPixelAt(x, y,
                juce::Colour::fromRGB(value, static_cast<uint8_t>(static_cast<float>(value) * 0.8f), static_cast<uint8_t>(static_cast<float>(value) * 0.6f)));
        }
    }

    repaint();
}

//==============================================================================
// SpectralGranularSynthUI Main Implementation
//==============================================================================

SpectralGranularSynthUI::SpectralGranularSynthUI(juce::AudioProcessorValueTreeState& vts)
    : parameters(vts),
      grainSizeLabel("", "Grain Size"),
      grainDensityLabel("", "Density"),
      spectralShiftLabel("", "Spectral Shift"),
      textureAmountLabel("", "Texture"),
      swarmChaosLabel("", "Chaos"),
      freezeLabel("", "Freeze"),
      randomizeButton("Randomize"),
      morphButton("Morph")
{
    // Create visualizers
    grainCloud = std::make_unique<GrainCloudVisualizer>();
    spectralAnalyzer = std::make_unique<SpectralAnalyzer>();
    swarmViz = std::make_unique<SwarmVisualizer>();
    textureViz = std::make_unique<TextureVisualizer>();

    addAndMakeVisible(*grainCloud);
    addAndMakeVisible(*spectralAnalyzer);
    addAndMakeVisible(*swarmViz);
    addAndMakeVisible(*textureViz);

    // Setup sliders
    setupSlider(grainSizeSlider, grainSizeLabel, 0.001, 2.0, 0.1);
    setupSlider(grainDensitySlider, grainDensityLabel, 1.0, 100.0, 20.0);
    setupSlider(spectralShiftSlider, spectralShiftLabel, -24.0, 24.0, 0.0);
    setupSlider(textureAmountSlider, textureAmountLabel, 0.0, 1.0, 0.5);
    setupSlider(swarmChaosSlider, swarmChaosLabel, 0.0, 1.0, 0.3);
    setupSlider(freezeSlider, freezeLabel, 0.0, 1.0, 0.0);

    // Setup buttons
    addAndMakeVisible(randomizeButton);
    addAndMakeVisible(morphButton);

    randomizeButton.onClick = [this] { randomizeParameters(); };
    morphButton.onClick = [this] { startMorphing(); };

    // Apply custom look and feel
    applyCustomLookAndFeel();

    // Start timer for updates
    startTimer(30); // ~33 FPS

    setSize(1000, 700);
}

SpectralGranularSynthUI::~SpectralGranularSynthUI()
{
    stopTimer();
}

void SpectralGranularSynthUI::paint(juce::Graphics& g)
{
    // Dark gradient background
    g.setGradientFill(juce::ColourGradient(
        juce::Colour(0xff0a0a0f), 0.0f, 0.0f,
        juce::Colour(0xff1a1a2e), static_cast<float>(getWidth()), static_cast<float>(getHeight()), false));
    g.fillAll();

    // Title
    g.setColour(juce::Colours::white);
    g.setFont(juce::Font(24.0f, juce::Font::bold));
    g.drawText("Spectral Granular Synth", getLocalBounds().removeFromTop(40),
               juce::Justification::centred, true);
}

void SpectralGranularSynthUI::resized()
{
    auto bounds = getLocalBounds();
    bounds.removeFromTop(40); // Title space

    // Top section - visualizers
    auto topSection = bounds.removeFromTop(400);
    auto vizWidth = topSection.getWidth() / 2;

    grainCloud->setBounds(topSection.removeFromLeft(vizWidth));
    spectralAnalyzer->setBounds(topSection);

    // Middle section - more visualizers
    auto middleSection = bounds.removeFromTop(200);
    swarmViz->setBounds(middleSection.removeFromLeft(vizWidth));
    textureViz->setBounds(middleSection);

    // Bottom section - controls
    auto controlSection = bounds.removeFromTop(80);
    auto sliderWidth = controlSection.getWidth() / 6;

    grainSizeSlider.setBounds(controlSection.removeFromLeft(sliderWidth).reduced(5));
    grainDensitySlider.setBounds(controlSection.removeFromLeft(sliderWidth).reduced(5));
    spectralShiftSlider.setBounds(controlSection.removeFromLeft(sliderWidth).reduced(5));
    textureAmountSlider.setBounds(controlSection.removeFromLeft(sliderWidth).reduced(5));
    swarmChaosSlider.setBounds(controlSection.removeFromLeft(sliderWidth).reduced(5));
    freezeSlider.setBounds(controlSection.removeFromLeft(sliderWidth).reduced(5));

    // Buttons at bottom
    auto buttonSection = bounds.removeFromTop(40);
    randomizeButton.setBounds(buttonSection.removeFromLeft(100).reduced(5));
    morphButton.setBounds(buttonSection.removeFromLeft(100).reduced(5));
}

void SpectralGranularSynthUI::timerCallback()
{
    updateVisualizersFromAudioData();
}

void SpectralGranularSynthUI::setupSlider(juce::Slider& slider, juce::Label& label,
                                          double min, double max, double defaultValue)
{
    slider.setRange(min, max);
    slider.setValue(defaultValue);
    slider.setSliderStyle(juce::Slider::RotaryVerticalDrag);
    slider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 60, 20);

    addAndMakeVisible(slider);
    addAndMakeVisible(label);
    label.attachToComponent(&slider, false);
    label.setJustificationType(juce::Justification::centred);
}

void SpectralGranularSynthUI::updateVisualizersFromAudioData()
{
    // Generate dummy audio data for testing
    // In production, this would connect to the actual audio processor
    std::array<float, 1024> dummyAudioData;
    for (int i = 0; i < 1024; ++i)
    {
        dummyAudioData[i] = std::sin(static_cast<float>(i) * 0.01f) * std::exp(static_cast<float>(-i) * 0.001f);
    }

    grainCloud->updateGrains(dummyAudioData.data(), 1024);
    spectralAnalyzer->updateSpectrum(dummyAudioData.data(), 512);

    // Update swarm based on parameters
    swarmViz->setSwarmParameters(
        static_cast<float>(grainDensitySlider.getValue() / 100.0),
        static_cast<float>(swarmChaosSlider.getValue())
    );

    // Update texture
    textureViz->updateTexture(
        1.0f,
        1.0f + static_cast<float>(textureAmountSlider.getValue()),
        static_cast<float>(spectralShiftSlider.getValue()) + 24.0f
    );
}

void SpectralGranularSynthUI::updateFromAudioData(const float* audioData, int numSamples)
{
    if (grainCloud && audioData && numSamples > 0)
    {
        grainCloud->updateGrains(audioData, numSamples);
    }
}

void SpectralGranularSynthUI::updateFromFFTData(const float* fftData, int numBins)
{
    if (spectralAnalyzer && fftData && numBins > 0)
    {
        spectralAnalyzer->updateSpectrum(fftData, numBins);
    }
}

void SpectralGranularSynthUI::randomizeParameters()
{
    auto& random = juce::Random::getSystemRandom();
    grainSizeSlider.setValue(random.nextFloat() * 2.0);
    grainDensitySlider.setValue(random.nextInt(100));
    spectralShiftSlider.setValue((random.nextFloat() - 0.5) * 48.0);
    textureAmountSlider.setValue(random.nextFloat());
    swarmChaosSlider.setValue(random.nextFloat());
}

void SpectralGranularSynthUI::startMorphing()
{
    // Implement parameter morphing animation
    // This would smoothly transition between parameter states
    // For now, just randomize as a placeholder
    randomizeParameters();
}

void SpectralGranularSynthUI::applyCustomLookAndFeel()
{
    // Custom look for futuristic appearance
    getLookAndFeel().setColour(juce::Slider::thumbColourId, juce::Colour(0xff00ffff));
    getLookAndFeel().setColour(juce::Slider::rotarySliderFillColourId, juce::Colour(0xff0088cc));
    getLookAndFeel().setColour(juce::Slider::rotarySliderOutlineColourId, juce::Colour(0xff003366));
    getLookAndFeel().setColour(juce::TextButton::buttonColourId, juce::Colour(0xff1a1a2e));
    getLookAndFeel().setColour(juce::TextButton::textColourOffId, juce::Colours::cyan);
}
