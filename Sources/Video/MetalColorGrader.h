// MetalColorGrader.h - GPU-Accelerated Color Grading for VideoWeaver
// Hardware-accelerated image processing using Metal compute shaders
#pragma once

#include "../Common/GlobalWarningFixes.h"
#include <JuceHeader.h>
#include <memory>

namespace Echoel {

//==============================================================================
// Color Grading Parameters
//==============================================================================

struct ColorGradingParams {
    float brightness = 0.0f;      // -1.0 to 1.0
    float contrast = 0.0f;        // -1.0 to 1.0
    float saturation = 0.0f;      // -1.0 to 1.0
    float hue = 0.0f;            // 0.0 to 1.0
    float temperature = 0.0f;     // -1.0 to 1.0 (cool to warm)
    float tint = 0.0f;           // -1.0 to 1.0 (green to magenta)
    float exposure = 0.0f;        // -2.0 to 2.0 (EV stops)
    float highlights = 0.0f;      // -1.0 to 1.0
    float shadows = 0.0f;         // -1.0 to 1.0
    float whites = 0.0f;          // -1.0 to 1.0
    float blacks = 0.0f;          // -1.0 to 1.0
    float vignette = 0.0f;        // 0.0 to 1.0
    float grain = 0.0f;           // 0.0 to 1.0
};

struct ChromaKeyParams {
    juce::Colour keyColor{0xff00ff00};  // Default green
    float threshold = 0.4f;
    float smoothness = 0.1f;
    float spillSuppression = 0.5f;
};

//==============================================================================
// Metal Color Grader (GPU-Accelerated)
//==============================================================================

class MetalColorGrader {
public:
    MetalColorGrader();
    ~MetalColorGrader();

    // Initialize Metal device and pipeline
    bool initialize();

    // Apply color grading to an image (returns new processed image)
    juce::Image applyColorGrading(const juce::Image& input, const ColorGradingParams& params);

    // Apply 3D LUT to an image
    juce::Image applyLUT(const juce::Image& input, const juce::Image& lutImage);

    // Apply chroma key (greenscreen removal)
    juce::Image applyChromaKey(const juce::Image& input, const ChromaKeyParams& params);

    // Apply blur (radius in pixels)
    juce::Image applyBlur(const juce::Image& input, float radius);

    // Apply sharpen (amount 0.0 to 1.0)
    juce::Image applySharpen(const juce::Image& input, float amount);

    // Check if Metal is available on this system
    static bool isMetalAvailable();

    // Get GPU device name
    juce::String getDeviceName() const;

    // Performance metrics
    struct PerformanceMetrics {
        double lastProcessingTimeMs = 0.0;
        double averageProcessingTimeMs = 0.0;
        int64_t totalFramesProcessed = 0;
    };

    PerformanceMetrics getPerformanceMetrics() const { return metrics; }

private:
    struct Impl;  // Pimpl pattern to hide Metal types from header
    std::unique_ptr<Impl> impl;

    PerformanceMetrics metrics;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MetalColorGrader)
};

//==============================================================================
// CPU Fallback Color Grader (for non-Metal systems)
//==============================================================================

class CPUColorGrader {
public:
    // Same interface as MetalColorGrader for seamless fallback
    static juce::Image applyColorGrading(const juce::Image& input, const ColorGradingParams& params);
    static juce::Image applyChromaKey(const juce::Image& input, const ChromaKeyParams& params);
    static juce::Image applyBlur(const juce::Image& input, float radius);
    static juce::Image applySharpen(const juce::Image& input, float amount);

private:
    // Helper functions
    static juce::Colour rgbToHsv(const juce::Colour& rgb);
    static juce::Colour hsvToRgb(float h, float s, float v, float a);
    static float luminance(const juce::Colour& rgb);
};

//==============================================================================
// Smart Color Grader (Auto-selects GPU or CPU)
//==============================================================================

class ColorGrader {
public:
    ColorGrader();
    ~ColorGrader();

    // Automatically uses Metal if available, falls back to CPU
    juce::Image applyColorGrading(const juce::Image& input, const ColorGradingParams& params);
    juce::Image applyChromaKey(const juce::Image& input, const ChromaKeyParams& params);
    juce::Image applyBlur(const juce::Image& input, float radius);
    juce::Image applySharpen(const juce::Image& input, float amount);

    // Check which backend is being used
    bool isUsingGPU() const { return usingGPU; }

    juce::String getBackendInfo() const;

private:
    std::unique_ptr<MetalColorGrader> gpuGrader;
    bool usingGPU = false;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ColorGrader)
};

} // namespace Echoel
