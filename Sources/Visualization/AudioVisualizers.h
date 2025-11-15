#pragma once

#include <JuceHeader.h>
#include <vector>

//==============================================================================
/**
 * @brief Real-time Audio Waveform Visualizer
 *
 * Features:
 * - Circular buffer for smooth waveform display
 * - Auto-scaling based on amplitude
 * - Gradient colors (cyan to purple)
 * - 60 FPS refresh rate
 */
class WaveformVisualizer : public juce::Component,
                          private juce::Timer
{
public:
    WaveformVisualizer()
    {
        // Initialize circular buffer (2 seconds at 60 FPS)
        waveformBuffer.resize(bufferSize, 0.0f);
        startTimerHz(60);  // 60 FPS
    }

    void pushAudioData(const juce::AudioBuffer<float>& buffer)
    {
        if (buffer.getNumChannels() == 0 || buffer.getNumSamples() == 0)
            return;

        // Downsample to display resolution
        const int stride = juce::jmax(1, buffer.getNumSamples() / 10);

        for (int i = 0; i < buffer.getNumSamples(); i += stride)
        {
            // Average L+R channels
            float sample = buffer.getSample(0, i);
            if (buffer.getNumChannels() > 1)
                sample = (sample + buffer.getSample(1, i)) * 0.5f;

            // Add to circular buffer
            waveformBuffer[writePosition] = sample;
            writePosition = (writePosition + 1) % bufferSize;
        }
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();

        // Background
        g.fillAll(juce::Colour(0xff0a0a0f));

        // Grid lines
        g.setColour(juce::Colour(0xff1a1a2f).withAlpha(0.5f));
        for (int i = 1; i < 4; ++i)
        {
            float y = bounds.getHeight() * i / 4.0f;
            g.drawHorizontalLine(static_cast<int>(y), bounds.getX(), bounds.getRight());
        }

        // Center line
        g.setColour(juce::Colour(0xff2a2a4f).withAlpha(0.7f));
        g.drawHorizontalLine(static_cast<int>(bounds.getCentreY()), bounds.getX(), bounds.getRight());

        // Draw waveform
        if (waveformBuffer.empty())
            return;

        juce::Path waveformPath;
        bool firstPoint = true;

        for (int x = 0; x < getWidth(); ++x)
        {
            // Map x position to buffer position
            int bufferIndex = (writePosition + (x * bufferSize / getWidth())) % bufferSize;
            float sample = waveformBuffer[bufferIndex];

            // Scale to display height
            float y = bounds.getCentreY() - (sample * bounds.getHeight() * 0.4f * currentScale);
            y = juce::jlimit(bounds.getY(), bounds.getBottom(), y);

            if (firstPoint)
            {
                waveformPath.startNewSubPath(static_cast<float>(x), y);
                firstPoint = false;
            }
            else
            {
                waveformPath.lineTo(static_cast<float>(x), y);
            }
        }

        // Gradient stroke (cyan to purple)
        juce::ColourGradient gradient(
            juce::Colour(0xff00d4ff), bounds.getX(), bounds.getCentreY(),
            juce::Colour(0xffaa44ff), bounds.getRight(), bounds.getCentreY(),
            false
        );
        g.setGradientFill(gradient);
        g.strokePath(waveformPath, juce::PathStrokeType(2.0f));

        // Glow effect
        g.setGradientFill(gradient);
        g.setOpacity(0.3f);
        g.strokePath(waveformPath, juce::PathStrokeType(4.0f));
    }

private:
    void timerCallback() override
    {
        // Auto-scale based on peak level
        float peak = 0.0f;
        for (float sample : waveformBuffer)
            peak = juce::jmax(peak, std::abs(sample));

        float targetScale = peak > 0.1f ? (0.8f / peak) : 1.0f;
        currentScale += (targetScale - currentScale) * 0.1f;  // Smooth scaling

        repaint();
    }

    static constexpr int bufferSize = 2048;
    std::vector<float> waveformBuffer;
    int writePosition = 0;
    float currentScale = 1.0f;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(WaveformVisualizer)
};

//==============================================================================
/**
 * @brief Real-time FFT Spectrum Analyzer
 *
 * Features:
 * - 2048-point FFT
 * - Logarithmic frequency scale (20Hz - 20kHz)
 * - Smooth peak decay
 * - Gradient colors (bass=red, mid=orange, high=cyan)
 * - 30 FPS refresh rate
 */
class SpectrumAnalyzer : public juce::Component,
                         private juce::Timer
{
public:
    SpectrumAnalyzer()
        : forwardFFT(fftOrder),
          window(fftSize, juce::dsp::WindowingFunction<float>::hann)
    {
        // Initialize FFT data
        fftData.resize(fftSize * 2, 0.0f);
        spectrumData.resize(fftSize / 2, 0.0f);

        startTimerHz(30);  // 30 FPS
    }

    void pushAudioData(const juce::AudioBuffer<float>& buffer)
    {
        if (buffer.getNumChannels() == 0)
            return;

        // Copy samples to FFT buffer
        for (int i = 0; i < juce::jmin(buffer.getNumSamples(), fftSize); ++i)
        {
            // Average L+R channels
            float sample = buffer.getSample(0, i);
            if (buffer.getNumChannels() > 1)
                sample = (sample + buffer.getSample(1, i)) * 0.5f;

            fftData[i] = sample;
        }

        // Apply window
        window.multiplyWithWindowingTable(fftData.data(), fftSize);

        // Perform FFT
        forwardFFT.performFrequencyOnlyForwardTransform(fftData.data());

        // Copy to spectrum data with smoothing
        for (int i = 0; i < fftSize / 2; ++i)
        {
            float magnitude = fftData[i];
            spectrumData[i] = spectrumData[i] * 0.7f + magnitude * 0.3f;  // Smooth
        }
    }

    void paint(juce::Graphics& g) override
    {
        auto bounds = getLocalBounds().toFloat();

        // Background
        g.fillAll(juce::Colour(0xff0a0a0f));

        // Grid lines (dB scale)
        g.setColour(juce::Colour(0xff1a1a2f).withAlpha(0.5f));
        for (int db = 0; db >= -60; db -= 12)
        {
            float y = bounds.getY() + juce::jmap(static_cast<float>(db), -60.0f, 0.0f, bounds.getHeight(), 0.0f);
            g.drawHorizontalLine(static_cast<int>(y), bounds.getX(), bounds.getRight());
        }

        // Frequency labels
        g.setColour(juce::Colour(0xff808080));
        g.setFont(10.0f);
        const float frequencies[] = { 20, 50, 100, 200, 500, 1000, 2000, 5000, 10000, 20000 };
        for (float freq : frequencies)
        {
            float x = bounds.getX() + frequencyToX(freq, bounds.getWidth());
            juce::String label = freq < 1000 ? juce::String(static_cast<int>(freq))
                                             : juce::String(freq / 1000.0f, 1) + "k";
            g.drawText(label, static_cast<int>(x - 20), static_cast<int>(bounds.getBottom() - 15), 40, 12,
                      juce::Justification::centred);
        }

        // Draw spectrum
        juce::Path spectrumPath;
        spectrumPath.startNewSubPath(bounds.getX(), bounds.getBottom());

        for (int i = 1; i < fftSize / 2; ++i)
        {
            float frequency = (i * 44100.0f) / fftSize;
            if (frequency < 20.0f || frequency > 20000.0f)
                continue;

            float x = bounds.getX() + frequencyToX(frequency, bounds.getWidth());
            float magnitude = spectrumData[i];

            // Convert to dB
            float db = juce::jlimit(-60.0f, 0.0f, juce::Decibels::gainToDecibels(magnitude + 0.0001f));
            float y = bounds.getY() + juce::jmap(db, -60.0f, 0.0f, bounds.getHeight(), 0.0f);

            spectrumPath.lineTo(x, y);
        }

        spectrumPath.lineTo(bounds.getRight(), bounds.getBottom());
        spectrumPath.closeSubPath();

        // Gradient fill (bass=red, mid=orange, high=cyan)
        juce::ColourGradient gradient(
            juce::Colour(0xffff4444), bounds.getX(), bounds.getCentreY(),
            juce::Colour(0xff00d4ff), bounds.getRight(), bounds.getCentreY(),
            false
        );
        gradient.addColour(0.3, juce::Colour(0xffffaa00));  // Orange in middle

        g.setGradientFill(gradient);
        g.setOpacity(0.7f);
        g.fillPath(spectrumPath);

        // Outline
        g.setGradientFill(gradient);
        g.setOpacity(1.0f);
        g.strokePath(spectrumPath, juce::PathStrokeType(2.0f));
    }

private:
    void timerCallback() override
    {
        repaint();
    }

    float frequencyToX(float frequency, float width) const
    {
        // Logarithmic frequency scale
        float minFreq = 20.0f;
        float maxFreq = 20000.0f;
        float normalized = std::log(frequency / minFreq) / std::log(maxFreq / minFreq);
        return normalized * width;
    }

    static constexpr int fftOrder = 11;
    static constexpr int fftSize = 1 << fftOrder;  // 2048

    juce::dsp::FFT forwardFFT;
    juce::dsp::WindowingFunction<float> window;
    std::vector<float> fftData;
    std::vector<float> spectrumData;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SpectrumAnalyzer)
};

//==============================================================================
/**
 * @brief Audio-Reactive Particle System
 *
 * Features:
 * - Particles spawn based on audio amplitude
 * - Color changes based on frequency content
 * - Physics simulation (velocity, gravity, friction)
 * - Glow/bloom effects
 * - 60 FPS animation
 */
class ParticleSystem : public juce::Component,
                       private juce::Timer
{
public:
    struct Particle
    {
        juce::Point<float> position;
        juce::Point<float> velocity;
        juce::Colour color;
        float size;
        float lifetime;
        float maxLifetime;
    };

    ParticleSystem()
    {
        particles.reserve(maxParticles);
        startTimerHz(60);  // 60 FPS
    }

    void pushAudioData(const juce::AudioBuffer<float>& buffer)
    {
        if (buffer.getNumChannels() == 0 || buffer.getNumSamples() == 0)
            return;

        // Calculate RMS amplitude
        float rms = buffer.getRMSLevel(0, 0, buffer.getNumSamples());
        if (buffer.getNumChannels() > 1)
            rms = (rms + buffer.getRMSLevel(1, 0, buffer.getNumSamples())) * 0.5f;

        currentAmplitude = rms;

        // Spawn particles based on amplitude
        if (rms > 0.1f && particles.size() < maxParticles)
        {
            int numToSpawn = static_cast<int>(rms * 10);
            for (int i = 0; i < numToSpawn; ++i)
                spawnParticle();
        }
    }

    void paint(juce::Graphics& g) override
    {
        // Background
        g.fillAll(juce::Colour(0xff0a0a0f));

        // Draw particles
        for (const auto& particle : particles)
        {
            // Glow effect
            g.setColour(particle.color.withAlpha(0.3f));
            g.fillEllipse(particle.position.x - particle.size * 2,
                         particle.position.y - particle.size * 2,
                         particle.size * 4, particle.size * 4);

            // Core
            g.setColour(particle.color);
            g.fillEllipse(particle.position.x - particle.size,
                         particle.position.y - particle.size,
                         particle.size * 2, particle.size * 2);
        }

        // FPS counter
        g.setColour(juce::Colours::white.withAlpha(0.5f));
        g.setFont(10.0f);
        g.drawText("Particles: " + juce::String(particles.size()), 10, 10, 150, 20,
                  juce::Justification::left);
    }

private:
    void timerCallback() override
    {
        auto bounds = getLocalBounds().toFloat();

        // Update particles
        for (auto it = particles.begin(); it != particles.end();)
        {
            // Physics
            it->velocity.y += 0.5f;  // Gravity
            it->velocity *= 0.98f;   // Friction
            it->position += it->velocity;

            // Lifetime
            it->lifetime -= 0.016f;  // 60 FPS

            // Remove dead particles
            if (it->lifetime <= 0.0f ||
                it->position.y > bounds.getBottom() + 50)
            {
                it = particles.erase(it);
            }
            else
            {
                // Fade out
                float alpha = it->lifetime / it->maxLifetime;
                it->color = it->color.withAlpha(alpha);
                ++it;
            }
        }

        repaint();
    }

    void spawnParticle()
    {
        auto bounds = getLocalBounds().toFloat();

        Particle p;
        p.position.x = bounds.getCentreX() + (random.nextFloat() - 0.5f) * 100;
        p.position.y = bounds.getBottom() - 50;

        float angle = -juce::MathConstants<float>::pi / 2 + (random.nextFloat() - 0.5f) * 1.0f;
        float speed = 5.0f + random.nextFloat() * 10.0f * currentAmplitude;
        p.velocity.x = std::cos(angle) * speed;
        p.velocity.y = std::sin(angle) * speed;

        // Color based on amplitude (low=cyan, high=purple)
        float hue = juce::jmap(currentAmplitude, 0.0f, 1.0f, 0.5f, 0.8f);
        p.color = juce::Colour::fromHSV(hue, 0.8f, 1.0f, 1.0f);

        p.size = 3.0f + random.nextFloat() * 5.0f;
        p.lifetime = 2.0f + random.nextFloat() * 2.0f;
        p.maxLifetime = p.lifetime;

        particles.push_back(p);
    }

    static constexpr int maxParticles = 500;
    std::vector<Particle> particles;
    juce::Random random;
    float currentAmplitude = 0.0f;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ParticleSystem)
};
