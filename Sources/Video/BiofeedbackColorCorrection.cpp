/*
  ==============================================================================
   ECHOELMUSIC - Biofeedback Color Correction Implementation
  ==============================================================================
*/

#include "BiofeedbackColorCorrection.h"

namespace Echoelmusic {
namespace Video {

//==============================================================================
// BiofeedbackColorCorrection Implementation
//==============================================================================

BiofeedbackColorCorrection::BiofeedbackColorCorrection() {
    biofeedbackEnabled = true;
    smoothingFactor = 0.95f;
    lutIntensity = 1.0f;
    currentPreset = ColorPreset::BiofeedbackDriven;

    // Initialize with neutral values
    currentParams.temperature = 0.0f;
    currentParams.tint = 0.0f;
    currentParams.saturation = 1.0f;
    currentParams.contrast = 1.0f;
    currentParams.exposure = 0.0f;
    currentParams.vibrance = 1.0f;
    currentParams.highlights = 0.0f;
    currentParams.shadows = 0.0f;
    currentParams.hueShift = 0.0f;
    currentParams.smoothingFactor = smoothingFactor;

    targetParams = currentParams;
}

BiofeedbackColorCorrection::~BiofeedbackColorCorrection() {
}

//==============================================================================
// Biofeedback Input
//==============================================================================

void BiofeedbackColorCorrection::updatePhysiologicalState(const PhysiologicalState& state) {
    currentState = state;

    if (!biofeedbackEnabled) return;

    // Calculate target parameters from physiological state
    targetParams.temperature = mapHeartRateToTemperature(state.heartRate);
    targetParams.saturation = mapCoherenceToSaturation(state.coherence);
    targetParams.contrast = mapStressToContrast(state.stress);
    targetParams.exposure = mapBreathingToExposure(state.breathing);

    // Smooth transition
    currentParams.temperature = smoothValue(currentParams.temperature, targetParams.temperature, smoothingFactor);
    currentParams.saturation = smoothValue(currentParams.saturation, targetParams.saturation, smoothingFactor);
    currentParams.contrast = smoothValue(currentParams.contrast, targetParams.contrast, smoothingFactor);
    currentParams.exposure = smoothValue(currentParams.exposure, targetParams.exposure, smoothingFactor);

    if (onColorParamsChanged)
        onColorParamsChanged(currentParams);
}

//==============================================================================
// Color Correction
//==============================================================================

juce::Image BiofeedbackColorCorrection::applyColorCorrection(const juce::Image& input) {
    if (input.isNull()) return input;

    juce::Image output = input.createCopy();
    applyColorCorrectionInPlace(output);
    return output;
}

void BiofeedbackColorCorrection::applyColorCorrectionInPlace(juce::Image& image) {
    if (image.isNull()) return;

    // Apply corrections in order
    applyExposure(image, currentParams.exposure);
    applyTemperature(image, currentParams.temperature);
    applySaturation(image, currentParams.saturation);
    applyContrast(image, currentParams.contrast);
    applyHueShift(image, currentParams.hueShift);

    // Apply LUT if loaded
    if (currentLUT && lutIntensity > 0.0f) {
        juce::Image::BitmapData bitmap(image, juce::Image::BitmapData::readWrite);
        for (int y = 0; y < image.getHeight(); ++y) {
            for (int x = 0; x < image.getWidth(); ++x) {
                juce::Colour original = bitmap.getPixelColour(x, y);
                juce::Colour lutColor = applyLUT(original);

                // Blend LUT with original based on intensity
                float r = original.getFloatRed() + (lutColor.getFloatRed() - original.getFloatRed()) * lutIntensity;
                float g = original.getFloatGreen() + (lutColor.getFloatGreen() - original.getFloatGreen()) * lutIntensity;
                float b = original.getFloatBlue() + (lutColor.getFloatBlue() - original.getFloatBlue()) * lutIntensity;

                bitmap.setPixelColour(x, y, juce::Colour::fromFloatRGBA(r, g, b, original.getFloatAlpha()));
            }
        }
    }
}

BiofeedbackColorParams BiofeedbackColorCorrection::getCurrentColorParams() const {
    return currentParams;
}

//==============================================================================
// LUT Management
//==============================================================================

void BiofeedbackColorCorrection::loadLUT(const juce::File& lutFile) {
    if (!lutFile.existsAsFile()) {
        DBG("LUT file not found: " << lutFile.getFullPathName());
        return;
    }

    currentLUT = std::make_unique<ColorLUT>(ColorLUT::loadFromCubeFile(lutFile));
    DBG("Loaded LUT: " << currentLUT->name);
}

void BiofeedbackColorCorrection::setLUTIntensity(float intensity) {
    lutIntensity = juce::jlimit(0.0f, 1.0f, intensity);
}

//==============================================================================
// Manual Overrides
//==============================================================================

void BiofeedbackColorCorrection::setManualTemperature(float temp) {
    targetParams.temperature = juce::jlimit(-1.0f, 1.0f, temp);
    biofeedbackEnabled = false;
}

void BiofeedbackColorCorrection::setManualSaturation(float sat) {
    targetParams.saturation = juce::jlimit(0.0f, 2.0f, sat);
    biofeedbackEnabled = false;
}

void BiofeedbackColorCorrection::setManualContrast(float contrast) {
    targetParams.contrast = juce::jlimit(0.0f, 2.0f, contrast);
    biofeedbackEnabled = false;
}

void BiofeedbackColorCorrection::enableBiofeedbackControl(bool enable) {
    biofeedbackEnabled = enable;
    DBG("Biofeedback color control " << (enable ? "enabled" : "disabled"));
}

//==============================================================================
// Presets
//==============================================================================

void BiofeedbackColorCorrection::setPreset(ColorPreset preset) {
    currentPreset = preset;

    switch (preset) {
        case ColorPreset::Cinematic:
            targetParams.saturation = 0.9f;
            targetParams.contrast = 1.1f;
            targetParams.temperature = 0.1f;  // Slightly warm
            biofeedbackEnabled = false;
            break;

        case ColorPreset::Commercial:
            targetParams.saturation = 1.3f;
            targetParams.contrast = 1.2f;
            targetParams.vibrance = 1.4f;
            biofeedbackEnabled = false;
            break;

        case ColorPreset::MusicVideo:
            targetParams.saturation = 1.5f;
            targetParams.contrast = 1.3f;
            targetParams.vibrance = 1.6f;
            biofeedbackEnabled = false;
            break;

        case ColorPreset::Natural:
            targetParams.saturation = 1.0f;
            targetParams.contrast = 1.0f;
            targetParams.temperature = 0.0f;
            biofeedbackEnabled = false;
            break;

        case ColorPreset::BiofeedbackDriven:
            biofeedbackEnabled = true;
            break;
    }
}

//==============================================================================
// Internal Mapping Functions
//==============================================================================

float BiofeedbackColorCorrection::mapHeartRateToTemperature(float heartRate) {
    // 60-70 BPM  → Cool (-0.3)
    // 70-80 BPM  → Neutral (0.0)
    // 80-100 BPM → Warm (+0.3)
    // 100+ BPM   → Hot (+0.6)

    if (heartRate < 70.0f) return -0.3f;
    if (heartRate < 80.0f) return 0.0f;
    if (heartRate < 100.0f) return juce::jmap(heartRate, 80.0f, 100.0f, 0.0f, 0.3f);
    return juce::jmap(heartRate, 100.0f, 120.0f, 0.3f, 0.6f);
}

float BiofeedbackColorCorrection::mapCoherenceToSaturation(float coherence) {
    // < 30  → Low Saturation (0.7)
    // 30-60 → Normal (1.0)
    // 60-80 → High (1.3)
    // 80+   → Vibrant (1.5)

    if (coherence < 30.0f) return 0.7f;
    if (coherence < 60.0f) return juce::jmap(coherence, 30.0f, 60.0f, 0.7f, 1.0f);
    if (coherence < 80.0f) return juce::jmap(coherence, 60.0f, 80.0f, 1.0f, 1.3f);
    return juce::jmap(coherence, 80.0f, 100.0f, 1.3f, 1.5f);
}

float BiofeedbackColorCorrection::mapStressToContrast(float stress) {
    // < 30  → Soft (0.9)
    // 30-60 → Normal (1.0)
    // 60-80 → Punchy (1.2)
    // 80+   → Harsh (1.4)

    if (stress < 30.0f) return 0.9f;
    if (stress < 60.0f) return juce::jmap(stress, 30.0f, 60.0f, 0.9f, 1.0f);
    if (stress < 80.0f) return juce::jmap(stress, 60.0f, 80.0f, 1.0f, 1.2f);
    return juce::jmap(stress, 80.0f, 100.0f, 1.2f, 1.4f);
}

float BiofeedbackColorCorrection::mapBreathingToExposure(float breathing) {
    // Slow breathing (< 12) → Slightly darker
    // Normal (12-16) → Neutral
    // Fast (> 16) → Slightly brighter

    if (breathing < 12.0f) return -0.1f;
    if (breathing > 16.0f) return 0.1f;
    return 0.0f;
}

//==============================================================================
// Color Operations
//==============================================================================

void BiofeedbackColorCorrection::applyTemperature(juce::Image& image, float temperature) {
    auto mult = ColorTemperatureConverter::temperatureToRGB(temperature);

    juce::Image::BitmapData bitmap(image, juce::Image::BitmapData::readWrite);
    for (int y = 0; y < image.getHeight(); ++y) {
        for (int x = 0; x < image.getWidth(); ++x) {
            juce::Colour pixel = bitmap.getPixelColour(x, y);
            bitmap.setPixelColour(x, y, juce::Colour::fromFloatRGBA(
                juce::jlimit(0.0f, 1.0f, pixel.getFloatRed() * mult.r),
                juce::jlimit(0.0f, 1.0f, pixel.getFloatGreen() * mult.g),
                juce::jlimit(0.0f, 1.0f, pixel.getFloatBlue() * mult.b),
                pixel.getFloatAlpha()
            ));
        }
    }
}

void BiofeedbackColorCorrection::applySaturation(juce::Image& image, float saturation) {
    juce::Image::BitmapData bitmap(image, juce::Image::BitmapData::readWrite);
    for (int y = 0; y < image.getHeight(); ++y) {
        for (int x = 0; x < image.getWidth(); ++x) {
            juce::Colour pixel = bitmap.getPixelColour(x, y);

            float h, s, v;
            pixel.getHSB(h, s, v);
            s *= saturation;
            s = juce::jlimit(0.0f, 1.0f, s);

            bitmap.setPixelColour(x, y, juce::Colour::fromHSV(h, s, v, pixel.getFloatAlpha()));
        }
    }
}

void BiofeedbackColorCorrection::applyContrast(juce::Image& image, float contrast) {
    juce::Image::BitmapData bitmap(image, juce::Image::BitmapData::readWrite);
    for (int y = 0; y < image.getHeight(); ++y) {
        for (int x = 0; x < image.getWidth(); ++x) {
            juce::Colour pixel = bitmap.getPixelColour(x, y);

            float r = (pixel.getFloatRed() - 0.5f) * contrast + 0.5f;
            float g = (pixel.getFloatGreen() - 0.5f) * contrast + 0.5f;
            float b = (pixel.getFloatBlue() - 0.5f) * contrast + 0.5f;

            bitmap.setPixelColour(x, y, juce::Colour::fromFloatRGBA(
                juce::jlimit(0.0f, 1.0f, r),
                juce::jlimit(0.0f, 1.0f, g),
                juce::jlimit(0.0f, 1.0f, b),
                pixel.getFloatAlpha()
            ));
        }
    }
}

void BiofeedbackColorCorrection::applyExposure(juce::Image& image, float exposure) {
    float multiplier = std::pow(2.0f, exposure);

    juce::Image::BitmapData bitmap(image, juce::Image::BitmapData::readWrite);
    for (int y = 0; y < image.getHeight(); ++y) {
        for (int x = 0; x < image.getWidth(); ++x) {
            juce::Colour pixel = bitmap.getPixelColour(x, y);

            bitmap.setPixelColour(x, y, juce::Colour::fromFloatRGBA(
                juce::jlimit(0.0f, 1.0f, pixel.getFloatRed() * multiplier),
                juce::jlimit(0.0f, 1.0f, pixel.getFloatGreen() * multiplier),
                juce::jlimit(0.0f, 1.0f, pixel.getFloatBlue() * multiplier),
                pixel.getFloatAlpha()
            ));
        }
    }
}

void BiofeedbackColorCorrection::applyHueShift(juce::Image& image, float hueShift) {
    if (hueShift == 0.0f) return;

    juce::Image::BitmapData bitmap(image, juce::Image::BitmapData::readWrite);
    for (int y = 0; y < image.getHeight(); ++y) {
        for (int x = 0; x < image.getWidth(); ++x) {
            juce::Colour pixel = bitmap.getPixelColour(x, y);

            float h, s, v;
            pixel.getHSB(h, s, v);
            h += hueShift / 360.0f;
            while (h < 0.0f) h += 1.0f;
            while (h > 1.0f) h -= 1.0f;

            bitmap.setPixelColour(x, y, juce::Colour::fromHSV(h, s, v, pixel.getFloatAlpha()));
        }
    }
}

juce::Colour BiofeedbackColorCorrection::applyLUT(const juce::Colour& input) {
    if (!currentLUT) return input;
    return LUTInterpolator::interpolate(*currentLUT, input);
}

float BiofeedbackColorCorrection::smoothValue(float current, float target, float smoothingFactor) {
    return current * smoothingFactor + target * (1.0f - smoothingFactor);
}

} // namespace Video
} // namespace Echoelmusic
