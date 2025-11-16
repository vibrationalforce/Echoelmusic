#pragma once

#include <JuceHeader.h>
#include <vector>
#include <atomic>

/**
 * VisualizerBase - Base class for all audio visualizers
 *
 * Provides common functionality for visualizers:
 * - Thread-safe audio data updates
 * - FPS limiting and performance optimization
 * - Double-buffering for smooth rendering
 * - Common visual effects (glow, gradients, etc.)
 */
class VisualizerBase : public juce::Component,
                       public juce::Timer
{
public:
    VisualizerBase();
    ~VisualizerBase() override;

    // Timer callback for periodic updates
    void timerCallback() override;

    // Update with audio data (thread-safe)
    void updateAudioData(const float* data, int numSamples);
    void updateFFTData(const float* data, int numBins);

    // FPS control
    void setTargetFPS(int fps);
    int getTargetFPS() const { return targetFPS; }

    // Performance metrics
    double getActualFPS() const { return actualFPS; }
    double getAverageRenderTime() const { return averageRenderTime; }

protected:
    // Override these in derived classes
    virtual void renderVisualization(juce::Graphics& g) = 0;
    virtual void updateVisualizationData() = 0;

    // Access to audio data (call from renderVisualization)
    const std::vector<float>& getAudioBuffer() const { return audioBuffer; }
    const std::vector<float>& getFFTBuffer() const { return fftBuffer; }

    // Common visual effects
    void drawGlow(juce::Graphics& g, const juce::Rectangle<float>& area,
                  const juce::Colour& color, float intensity);
    void drawGradientBackground(juce::Graphics& g, const juce::Colour& color1,
                               const juce::Colour& color2);

private:
    // Audio data buffers
    std::vector<float> audioBuffer;
    std::vector<float> fftBuffer;
    juce::CriticalSection bufferLock;

    // FPS management
    int targetFPS = 60;
    std::atomic<double> actualFPS{0.0};
    juce::int64 lastFrameTime = 0;

    // Performance tracking
    std::atomic<double> averageRenderTime{0.0};
    static constexpr int performanceSampleCount = 60;
    std::array<double, performanceSampleCount> renderTimes{};
    int renderTimeIndex = 0;

    void paint(juce::Graphics& g) final;
    void updatePerformanceMetrics(double renderTime);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(VisualizerBase)
};

/**
 * CustomLookAndFeel - Modern, futuristic look and feel for Echoelmusic
 */
class CustomLookAndFeel : public juce::LookAndFeel_V4
{
public:
    CustomLookAndFeel();
    ~CustomLookAndFeel() override;

    // Slider rendering
    void drawRotarySlider(juce::Graphics& g, int x, int y, int width, int height,
                         float sliderPos, float rotaryStartAngle, float rotaryEndAngle,
                         juce::Slider& slider) override;

    void drawLinearSlider(juce::Graphics& g, int x, int y, int width, int height,
                         float sliderPos, float minSliderPos, float maxSliderPos,
                         const juce::Slider::SliderStyle style, juce::Slider& slider) override;

    // Button rendering
    void drawButtonBackground(juce::Graphics& g, juce::Button& button, const juce::Colour& backgroundColour,
                             bool shouldDrawButtonAsHighlighted, bool shouldDrawButtonAsDown) override;

    // Label rendering
    void drawLabel(juce::Graphics& g, juce::Label& label) override;

    // ComboBox rendering
    void drawComboBox(juce::Graphics& g, int width, int height, bool isButtonDown,
                     int buttonX, int buttonY, int buttonW, int buttonH,
                     juce::ComboBox& box) override;

    // Popup menu rendering
    void drawPopupMenuBackground(juce::Graphics& g, int width, int height) override;

private:
    juce::Colour primaryColor{0xff00ffff};      // Cyan
    juce::Colour secondaryColor{0xff0088cc};    // Blue
    juce::Colour backgroundColor{0xff1a1a2e};   // Dark blue
    juce::Colour textColor{0xffffffff};         // White

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(CustomLookAndFeel)
};

/**
 * ParameterBridge - Bidirectional parameter updates between UI and processor
 *
 * Features:
 * - Thread-safe parameter updates
 * - 60 FPS update rate limiting
 * - Automatic value smoothing
 * - Change notifications
 */
class ParameterBridge : public juce::AudioProcessorValueTreeState::Listener
{
public:
    ParameterBridge(juce::AudioProcessorValueTreeState& vts);
    ~ParameterBridge() override;

    // AudioProcessorValueTreeState::Listener
    void parameterChanged(const juce::String& parameterID, float newValue) override;

    // Register UI components
    void registerSlider(const juce::String& parameterID, juce::Slider* slider);
    void registerButton(const juce::String& parameterID, juce::Button* button);
    void registerComboBox(const juce::String& parameterID, juce::ComboBox* comboBox);

    // Unregister components
    void unregisterAll();

    // Manual update trigger
    void updateAllUIComponents();

private:
    juce::AudioProcessorValueTreeState& valueTreeState;

    struct UIComponentMapping
    {
        juce::Component* component = nullptr;
        juce::String parameterID;
        float lastValue = 0.0f;
        juce::int64 lastUpdateTime = 0;
    };

    std::vector<UIComponentMapping> mappings;
    juce::CriticalSection mappingLock;

    void updateUIComponent(const juce::String& parameterID, float value);
    juce::Component* findComponentByParameterID(const juce::String& parameterID);

    static constexpr int minUpdateIntervalMs = 16; // ~60 FPS

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ParameterBridge)
};
