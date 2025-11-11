#include "BioReactiveVisualizer.h"

//==============================================================================
// Constructor / Destructor
//==============================================================================

BioReactiveVisualizer::BioReactiveVisualizer()
{
    initializeParticles();
    startTimer (16); // ~60 FPS
}

BioReactiveVisualizer::~BioReactiveVisualizer()
{
    stopTimer();
}

//==============================================================================
// Component
//==============================================================================

void BioReactiveVisualizer::paint (juce::Graphics& g)
{
    // Background
    g.fillAll (juce::Colour (0xff1a1a1a));

    // Draw gradient background based on coherence
    auto color = getColorForCoherence (smoothedCoherence);
    juce::ColourGradient gradient (
        color.withAlpha (0.05f), getWidth() / 2.0f, getHeight() / 2.0f,
        color.withAlpha (0.0f), 0.0f, 0.0f,
        true
    );
    g.setGradientFill (gradient);
    g.fillRect (getLocalBounds());

    // Draw visualization layers
    drawWaveform (g);
    drawParticles (g);
    drawCoherenceIndicator (g);
}

void BioReactiveVisualizer::resized()
{
    // Reinitialize particles to fit new bounds
    initializeParticles();
}

//==============================================================================
// Bio-Data Updates
//==============================================================================

void BioReactiveVisualizer::updateBioData (float hrv, float coherence)
{
    // Clamp values
    currentHRV = juce::jlimit (0.0f, 1.0f, hrv);
    currentCoherence = juce::jlimit (0.0f, 1.0f, coherence);
}

//==============================================================================
// Timer Callback
//==============================================================================

void BioReactiveVisualizer::timerCallback()
{
    // Smooth bio-data values for animation
    const float smoothing = 0.1f;
    smoothedHRV += (currentHRV - smoothedHRV) * smoothing;
    smoothedCoherence += (currentCoherence - smoothedCoherence) * smoothing;

    // Update animation time
    animationTime += 0.016f; // 60 FPS

    // Update particles
    updateParticles();

    // Trigger repaint
    repaint();
}

//==============================================================================
// Particle System
//==============================================================================

void BioReactiveVisualizer::initializeParticles()
{
    particles.clear();

    auto bounds = getLocalBounds().toFloat();
    auto centerX = bounds.getCentreX();
    auto centerY = bounds.getCentreY();

    juce::Random random;

    for (int i = 0; i < maxParticles; ++i)
    {
        Particle p;

        // Random position around center
        float angle = random.nextFloat() * juce::MathConstants<float>::twoPi;
        float distance = random.nextFloat() * juce::jmin (bounds.getWidth(), bounds.getHeight()) * 0.4f;

        p.position.x = centerX + std::cos (angle) * distance;
        p.position.y = centerY + std::sin (angle) * distance;

        // Random velocity
        p.velocity.x = (random.nextFloat() - 0.5f) * 2.0f;
        p.velocity.y = (random.nextFloat() - 0.5f) * 2.0f;

        p.size = random.nextFloat() * 3.0f + 1.0f;
        p.alpha = random.nextFloat() * 0.5f + 0.5f;
        p.phase = random.nextFloat() * juce::MathConstants<float>::twoPi;

        p.color = juce::Colour (0xff00d4ff); // Default cyan

        particles.push_back (p);
    }
}

void BioReactiveVisualizer::updateParticles()
{
    auto bounds = getLocalBounds().toFloat();
    auto centerX = bounds.getCentreX();
    auto centerY = bounds.getCentreY();

    // Particle count based on HRV (more HRV = more active particles)
    int activeParticles = (int)(smoothedHRV * maxParticles);

    for (int i = 0; i < particles.size(); ++i)
    {
        auto& p = particles[i];

        // Only update active particles
        if (i >= activeParticles)
        {
            p.alpha = juce::jmax (0.0f, p.alpha - 0.05f);
            continue;
        }
        else
        {
            p.alpha = juce::jmin (1.0f, p.alpha + 0.05f);
        }

        // Update color based on coherence
        p.color = getColorForCoherence (smoothedCoherence);

        // Bio-reactive motion
        float hrvSpeed = smoothedHRV * 2.0f;
        float coherenceAttraction = smoothedCoherence;

        // Sine wave motion based on phase
        float waveX = std::sin (animationTime * 2.0f + p.phase) * 20.0f * smoothedHRV;
        float waveY = std::cos (animationTime * 2.0f + p.phase) * 20.0f * smoothedHRV;

        // Move towards center when coherence is high
        auto toCenter = juce::Point<float> (centerX, centerY) - p.position;
        auto toCenterNormalized = toCenter.toFloat() / (toCenter.getDistanceFromOrigin() + 0.001f);

        p.velocity += toCenterNormalized * coherenceAttraction * 0.5f;
        p.velocity += juce::Point<float> (waveX, waveY) * 0.1f;

        // Apply velocity
        p.position += p.velocity * hrvSpeed;

        // Damping
        p.velocity *= 0.95f;

        // Wrap around edges
        if (p.position.x < 0.0f) p.position.x = bounds.getWidth();
        if (p.position.x > bounds.getWidth()) p.position.x = 0.0f;
        if (p.position.y < 0.0f) p.position.y = bounds.getHeight();
        if (p.position.y > bounds.getHeight()) p.position.y = 0.0f;

        // Size variation based on HRV
        p.size = 1.0f + smoothedHRV * 4.0f;
    }
}

//==============================================================================
// Rendering
//==============================================================================

void BioReactiveVisualizer::drawParticles (juce::Graphics& g)
{
    for (const auto& p : particles)
    {
        if (p.alpha <= 0.0f)
            continue;

        g.setColour (p.color.withAlpha (p.alpha * 0.8f));

        // Draw particle with glow effect
        auto particleBounds = juce::Rectangle<float> (
            p.position.x - p.size * 0.5f,
            p.position.y - p.size * 0.5f,
            p.size,
            p.size
        );

        // Outer glow
        g.setColour (p.color.withAlpha (p.alpha * 0.2f));
        g.fillEllipse (particleBounds.expanded (p.size));

        // Core
        g.setColour (p.color.withAlpha (p.alpha));
        g.fillEllipse (particleBounds);
    }

    // Draw connections between nearby particles (when coherence is high)
    if (smoothedCoherence > 0.5f)
    {
        const float maxDistance = 80.0f;
        const float connectionAlpha = (smoothedCoherence - 0.5f) * 2.0f; // 0.0 to 1.0

        for (size_t i = 0; i < particles.size(); ++i)
        {
            if (particles[i].alpha <= 0.0f)
                continue;

            for (size_t j = i + 1; j < particles.size(); ++j)
            {
                if (particles[j].alpha <= 0.0f)
                    continue;

                auto distance = particles[i].position.getDistanceFrom (particles[j].position);

                if (distance < maxDistance)
                {
                    float alpha = (1.0f - distance / maxDistance) * connectionAlpha * 0.3f;
                    g.setColour (juce::Colour (0xff00d4ff).withAlpha (alpha));
                    g.drawLine (particles[i].position.x, particles[i].position.y,
                                particles[j].position.x, particles[j].position.y,
                                1.0f);
                }
            }
        }
    }
}

void BioReactiveVisualizer::drawWaveform (juce::Graphics& g)
{
    auto bounds = getLocalBounds().toFloat();
    const int numWaves = 3;

    for (int wave = 0; wave < numWaves; ++wave)
    {
        juce::Path wavePath;
        const int numPoints = 100;

        float waveHeight = 30.0f * smoothedHRV;
        float frequency = 2.0f + wave * 1.0f;
        float yOffset = bounds.getCentreY() + (wave - 1) * 40.0f;
        float phaseOffset = animationTime * 2.0f + wave * juce::MathConstants<float>::pi * 0.5f;

        for (int i = 0; i <= numPoints; ++i)
        {
            float x = (float)i / numPoints * bounds.getWidth();
            float y = yOffset + std::sin (x / bounds.getWidth() * frequency * juce::MathConstants<float>::twoPi + phaseOffset) * waveHeight;

            if (i == 0)
                wavePath.startNewSubPath (x, y);
            else
                wavePath.lineTo (x, y);
        }

        auto color = getColorForCoherence (smoothedCoherence);
        g.setColour (color.withAlpha (0.1f + smoothedCoherence * 0.2f));
        g.strokePath (wavePath, juce::PathStrokeType (2.0f));
    }
}

void BioReactiveVisualizer::drawCoherenceIndicator (juce::Graphics& g)
{
    auto bounds = getLocalBounds().toFloat();

    // Draw circular coherence indicator in bottom right
    const float indicatorSize = 60.0f;
    auto indicatorBounds = juce::Rectangle<float> (
        bounds.getRight() - indicatorSize - 15.0f,
        bounds.getBottom() - indicatorSize - 15.0f,
        indicatorSize,
        indicatorSize
    );

    // Outer ring
    g.setColour (juce::Colour (0xff404040));
    g.drawEllipse (indicatorBounds, 3.0f);

    // Fill based on coherence
    auto color = getColorForCoherence (smoothedCoherence);
    g.setColour (color.withAlpha (0.3f));
    g.fillEllipse (indicatorBounds);

    // Coherence arc
    juce::Path arc;
    const float startAngle = -juce::MathConstants<float>::pi * 0.5f;
    const float endAngle = startAngle + smoothedCoherence * juce::MathConstants<float>::twoPi;

    arc.addCentredArc (indicatorBounds.getCentreX(), indicatorBounds.getCentreY(),
                       indicatorSize * 0.5f - 5.0f, indicatorSize * 0.5f - 5.0f,
                       0.0f, startAngle, endAngle, true);

    g.setColour (color);
    g.strokePath (arc, juce::PathStrokeType (4.0f));

    // Text label
    g.setColour (juce::Colours::white);
    g.setFont (juce::Font ("Helvetica", 10.0f, juce::Font::bold));
    g.drawText ("COH", indicatorBounds.toNearestInt(), juce::Justification::centred);

    // Percentage
    g.setFont (juce::Font ("Helvetica", 14.0f, juce::Font::bold));
    g.drawText (juce::String ((int)(smoothedCoherence * 100)) + "%",
                indicatorBounds.withY (indicatorBounds.getY() + 25.0f).toNearestInt(),
                juce::Justification::centred);
}

juce::Colour BioReactiveVisualizer::getColorForCoherence (float coherence) const
{
    // Color gradient: Red (low) -> Yellow -> Green -> Cyan (high)
    if (coherence < 0.33f)
    {
        // Red to Yellow
        float t = coherence / 0.33f;
        return juce::Colour (0xfff44336).interpolatedWith (juce::Colour (0xffffeb3b), t);
    }
    else if (coherence < 0.66f)
    {
        // Yellow to Green
        float t = (coherence - 0.33f) / 0.33f;
        return juce::Colour (0xffffeb3b).interpolatedWith (juce::Colour (0xff4caf50), t);
    }
    else
    {
        // Green to Cyan
        float t = (coherence - 0.66f) / 0.34f;
        return juce::Colour (0xff4caf50).interpolatedWith (juce::Colour (0xff00d4ff), t);
    }
}
