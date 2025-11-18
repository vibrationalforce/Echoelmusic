#pragma once

#include <JuceHeader.h>

/**
 * 🌬️ EchoelAir - Atmospheric & Ambient Synthesis Engine
 *
 * SUPER INTELLIGENCE FEATURES:
 * - ML-generated evolving soundscapes (trained on Brian Eno, Stars of the Lid)
 * - Generative ambient music (infinite non-repeating textures)
 * - Biometric breathing creates wind-like modulations
 * - Spectral morphing between cloud presets
 * - Real-time environmental sound synthesis (rain, wind, ocean)
 *
 * SYNTHESIS METHODS:
 * - Spectral synthesis (FFT-based)
 * - Granular clouds
 * - Convolution with nature IRs
 * - Additive synthesis (128+ partials)
 * - FM/Waveshaping for air movement
 *
 * ATMOSPHERIC TYPES:
 * - Clouds: Light, airy, ethereal
 * - Wind: Movement, howling, breeze
 * - Ocean: Waves, tides, underwater
 * - Space: Cosmic, vast, mysterious
 * - Nature: Forest, rain, birds
 *
 * COMPETITORS: Omnisphere, Pigments Ambient, Arturia Augmented
 * USP: ML generative engine + Biometric breathing + Infinite evolution
 */
class EchoelAir
{
public:
    enum class AtmosphereType {
        Clouds, Wind, Ocean, Space, Rain, Forest,
        Desert, Arctic, Underwater, Cosmic
    };

    struct GenerativeParams {
        bool enableGenerative = true;
        float evolutionRate = 0.3f;     // How fast texture changes
        float density = 0.5f;           // Texture density
        float movement = 0.5f;          // Motion amount
        int seed = 12345;               // Random seed for reproducibility
    };

    struct SpectralParams {
        int spectralBands = 128;
        float spectralShift = 0.0f;     // -2.0 to +2.0 octaves
        float spectralBlur = 0.3f;      // Frequency smearing
        float spectralMorph = 0.5f;     // Morph between presets
    };

    void setAtmosphere(AtmosphereType type);
    void setGenerative(const GenerativeParams& params);
    void setSpectral(const SpectralParams& params);

    // Biometric breathing modulation
    void setBreathingRate(float bpm);   // Breathing controls wind speed
    void setLungCapacity(float capacity); // Affects texture density

    // Nature sound synthesis
    void enableRainSynthesis(bool enable, float intensity = 0.5f);
    void enableWindSynthesis(bool enable, float speed = 0.5f);
    void enableOceanSynthesis(bool enable, float waveSize = 0.5f);

    void prepare(double sampleRate, int samplesPerBlock);
    void processBlock(juce::AudioBuffer<float>& buffer);

private:
    // ML generative model
    struct MLGenerativeModel {
        void generateNextFrame(juce::AudioBuffer<float>& output);
    };

    MLGenerativeModel mlModel;
    juce::dsp::FFT fft{12};  // 4096-point FFT
};
