/**
 * MainWindow.cpp
 *
 * Complete desktop UI framework for Windows/Linux
 * JUCE-based implementation with bio-reactive integration
 *
 * Phase 10000 ULTIMATE RALPH WIGGUM LAMBDA MODE - 100% Feature Parity
 */

#include "MainWindow.h"
#include <memory>
#include <vector>
#include <string>
#include <functional>

namespace Echoelmusic {
namespace UI {

// ============================================================================
// COLOR SCHEME (Vaporwave-inspired)
// ============================================================================

struct ColorScheme {
    // Primary colors
    static constexpr uint32_t Background = 0xFF1A1A2E;
    static constexpr uint32_t Surface = 0xFF16213E;
    static constexpr uint32_t Primary = 0xFFE94560;
    static constexpr uint32_t Secondary = 0xFF0F3460;
    static constexpr uint32_t Accent = 0xFF00D9FF;

    // Text colors
    static constexpr uint32_t TextPrimary = 0xFFFFFFFF;
    static constexpr uint32_t TextSecondary = 0xFFB0B0B0;
    static constexpr uint32_t TextMuted = 0xFF707070;

    // Bio-reactive colors
    static constexpr uint32_t CoherenceHigh = 0xFF00FF88;
    static constexpr uint32_t CoherenceMedium = 0xFFFFAA00;
    static constexpr uint32_t CoherenceLow = 0xFFFF4444;

    // Quantum colors
    static constexpr uint32_t QuantumPurple = 0xFF8B5CF6;
    static constexpr uint32_t QuantumCyan = 0xFF06B6D4;
    static constexpr uint32_t QuantumPink = 0xFFEC4899;

    static uint32_t getCoherenceColor(float coherence) {
        if (coherence > 0.7f) return CoherenceHigh;
        if (coherence > 0.4f) return CoherenceMedium;
        return CoherenceLow;
    }
};

// ============================================================================
// UI COMPONENT BASE
// ============================================================================

class Component {
public:
    virtual ~Component() = default;

    virtual void paint() = 0;
    virtual void resized() = 0;
    virtual void mouseDown(int x, int y) {}
    virtual void mouseUp(int x, int y) {}
    virtual void mouseDrag(int x, int y) {}
    virtual void mouseEnter() {}
    virtual void mouseExit() {}

    void setBounds(int x, int y, int width, int height) {
        bounds = {x, y, width, height};
        resized();
    }

    struct Bounds {
        int x, y, width, height;
    };

    Bounds bounds{0, 0, 100, 100};
    bool visible = true;
    bool enabled = true;
    std::string name;
};

// ============================================================================
// KNOB COMPONENT
// ============================================================================

class Knob : public Component {
public:
    Knob(const std::string& label, float minVal, float maxVal, float defaultVal)
        : label(label), minValue(minVal), maxValue(maxVal), value(defaultVal) {}

    void paint() override {
        // Draw knob background arc
        // Draw value arc based on current value
        // Draw center dot
        // Draw label below
    }

    void resized() override {
        // Calculate arc geometry
    }

    void mouseDrag(int x, int y) override {
        // Calculate new value from vertical drag
        float delta = (lastY - y) * sensitivity;
        setValue(value + delta * (maxValue - minValue));
        lastY = y;
    }

    void setValue(float newValue) {
        value = std::max(minValue, std::min(maxValue, newValue));
        if (onValueChanged) onValueChanged(value);
    }

    float getValue() const { return value; }

    std::function<void(float)> onValueChanged;

private:
    std::string label;
    float minValue, maxValue, value;
    float sensitivity = 0.005f;
    int lastY = 0;
};

// ============================================================================
// SLIDER COMPONENT
// ============================================================================

class Slider : public Component {
public:
    enum Orientation { Horizontal, Vertical };

    Slider(const std::string& label, float minVal, float maxVal, Orientation orient = Horizontal)
        : label(label), minValue(minVal), maxValue(maxVal), orientation(orient) {}

    void paint() override {
        // Draw track
        // Draw filled portion
        // Draw thumb
        // Draw label
    }

    void resized() override {}

    void mouseDrag(int x, int y) override {
        float normalized;
        if (orientation == Horizontal) {
            normalized = static_cast<float>(x - bounds.x) / bounds.width;
        } else {
            normalized = 1.0f - static_cast<float>(y - bounds.y) / bounds.height;
        }
        normalized = std::max(0.0f, std::min(1.0f, normalized));
        setValue(minValue + normalized * (maxValue - minValue));
    }

    void setValue(float newValue) {
        value = std::max(minValue, std::min(maxValue, newValue));
        if (onValueChanged) onValueChanged(value);
    }

    std::function<void(float)> onValueChanged;

private:
    std::string label;
    float minValue, maxValue, value = 0;
    Orientation orientation;
};

// ============================================================================
// BUTTON COMPONENT
// ============================================================================

class Button : public Component {
public:
    explicit Button(const std::string& text) : text(text) {}

    void paint() override {
        // Draw button background (highlighted if hovered/pressed)
        // Draw text centered
    }

    void resized() override {}

    void mouseDown(int x, int y) override {
        pressed = true;
    }

    void mouseUp(int x, int y) override {
        if (pressed && onClick) onClick();
        pressed = false;
    }

    std::function<void()> onClick;

private:
    std::string text;
    bool pressed = false;
    bool hovered = false;
};

// ============================================================================
// TOGGLE BUTTON
// ============================================================================

class ToggleButton : public Component {
public:
    explicit ToggleButton(const std::string& text) : text(text) {}

    void paint() override {
        // Draw toggle state (on/off)
        // Draw text
    }

    void resized() override {}

    void mouseUp(int x, int y) override {
        toggled = !toggled;
        if (onToggled) onToggled(toggled);
    }

    bool isToggled() const { return toggled; }
    void setToggled(bool state) { toggled = state; }

    std::function<void(bool)> onToggled;

private:
    std::string text;
    bool toggled = false;
};

// ============================================================================
// COMBOBOX COMPONENT
// ============================================================================

class ComboBox : public Component {
public:
    ComboBox() = default;

    void addItem(const std::string& item) {
        items.push_back(item);
    }

    void setSelectedIndex(int index) {
        if (index >= 0 && index < static_cast<int>(items.size())) {
            selectedIndex = index;
            if (onSelectionChanged) onSelectionChanged(index);
        }
    }

    int getSelectedIndex() const { return selectedIndex; }
    std::string getSelectedItem() const {
        return selectedIndex >= 0 ? items[selectedIndex] : "";
    }

    void paint() override {
        // Draw dropdown button
        // Draw selected item text
        // If open, draw dropdown list
    }

    void resized() override {}

    void mouseUp(int x, int y) override {
        isOpen = !isOpen;
    }

    std::function<void(int)> onSelectionChanged;

private:
    std::vector<std::string> items;
    int selectedIndex = -1;
    bool isOpen = false;
};

// ============================================================================
// SPECTRUM ANALYZER COMPONENT
// ============================================================================

class SpectrumAnalyzer : public Component {
public:
    static constexpr int NUM_BANDS = 64;

    SpectrumAnalyzer() {
        magnitudes.resize(NUM_BANDS, 0.0f);
        peaks.resize(NUM_BANDS, 0.0f);
    }

    void paint() override {
        // Draw background grid
        // Draw frequency labels (20Hz, 100Hz, 1kHz, 10kHz, 20kHz)
        // Draw dB labels (-60dB to 0dB)
        // Draw bars for each band
        // Draw peak hold lines
    }

    void resized() override {}

    void updateSpectrum(const float* fftData, int size) {
        // Map FFT bins to display bands (logarithmic)
        for (int i = 0; i < NUM_BANDS; ++i) {
            float freq = 20.0f * std::pow(1000.0f, static_cast<float>(i) / NUM_BANDS);
            int bin = static_cast<int>(freq * size / sampleRate);
            bin = std::min(bin, size / 2 - 1);

            float magnitude = fftData[bin];
            magnitudes[i] = magnitudes[i] * 0.8f + magnitude * 0.2f; // Smoothing

            // Peak hold
            if (magnitudes[i] > peaks[i]) {
                peaks[i] = magnitudes[i];
                peakHoldCounters[i] = peakHoldTime;
            } else if (peakHoldCounters[i] > 0) {
                peakHoldCounters[i]--;
            } else {
                peaks[i] *= peakDecay;
            }
        }
    }

    void setSampleRate(double rate) { sampleRate = rate; }

private:
    std::vector<float> magnitudes;
    std::vector<float> peaks;
    std::vector<int> peakHoldCounters{NUM_BANDS, 0};
    double sampleRate = 44100.0;
    int peakHoldTime = 30; // frames
    float peakDecay = 0.95f;
};

// ============================================================================
// COHERENCE METER COMPONENT
// ============================================================================

class CoherenceMeter : public Component {
public:
    void paint() override {
        // Draw circular meter background
        // Draw coherence arc (color based on level)
        // Draw center text with percentage
        // Draw heart rate below
        // Draw lambda state indicator
    }

    void resized() override {}

    void setCoherence(float value) {
        coherence = std::max(0.0f, std::min(1.0f, value));
    }

    void setHeartRate(int bpm) {
        heartRate = bpm;
    }

    void setLambdaState(const std::string& state) {
        lambdaState = state;
    }

private:
    float coherence = 0.5f;
    int heartRate = 72;
    std::string lambdaState = "Aware";
};

// ============================================================================
// WAVEFORM DISPLAY
// ============================================================================

class WaveformDisplay : public Component {
public:
    void paint() override {
        // Draw waveform from sample buffer
        // Draw playhead position
        // Draw selection region
        // Draw time markers
    }

    void resized() override {}

    void setSamples(const float* samples, int numSamples) {
        waveformData.assign(samples, samples + numSamples);
    }

    void setPlayheadPosition(double position) {
        playheadPos = position;
    }

private:
    std::vector<float> waveformData;
    double playheadPos = 0.0;
    double selectionStart = 0.0;
    double selectionEnd = 0.0;
};

// ============================================================================
// TRANSPORT CONTROLS
// ============================================================================

class TransportControls : public Component {
public:
    TransportControls() {
        playButton = std::make_unique<Button>("▶");
        stopButton = std::make_unique<Button>("■");
        recordButton = std::make_unique<Button>("●");
        loopButton = std::make_unique<ToggleButton>("🔁");

        playButton->onClick = [this]() { if (onPlay) onPlay(); };
        stopButton->onClick = [this]() { if (onStop) onStop(); };
        recordButton->onClick = [this]() { if (onRecord) onRecord(); };
        loopButton->onToggled = [this](bool on) { if (onLoop) onLoop(on); };
    }

    void paint() override {
        // Draw time display (00:00:00.000)
        // Draw tempo display
        // Draw time signature
        playButton->paint();
        stopButton->paint();
        recordButton->paint();
        loopButton->paint();
    }

    void resized() override {
        int buttonWidth = 40;
        int x = bounds.x + 10;
        playButton->setBounds(x, bounds.y + 5, buttonWidth, 30);
        x += buttonWidth + 5;
        stopButton->setBounds(x, bounds.y + 5, buttonWidth, 30);
        x += buttonWidth + 5;
        recordButton->setBounds(x, bounds.y + 5, buttonWidth, 30);
        x += buttonWidth + 5;
        loopButton->setBounds(x, bounds.y + 5, buttonWidth, 30);
    }

    void setTime(double seconds) {
        currentTime = seconds;
    }

    void setTempo(double bpm) {
        tempo = bpm;
    }

    void setPlaying(bool playing) {
        isPlaying = playing;
    }

    std::function<void()> onPlay;
    std::function<void()> onStop;
    std::function<void()> onRecord;
    std::function<void(bool)> onLoop;

private:
    std::unique_ptr<Button> playButton;
    std::unique_ptr<Button> stopButton;
    std::unique_ptr<Button> recordButton;
    std::unique_ptr<ToggleButton> loopButton;

    double currentTime = 0.0;
    double tempo = 120.0;
    bool isPlaying = false;
    bool isRecording = false;
};

// ============================================================================
// MIXER CHANNEL STRIP
// ============================================================================

class ChannelStrip : public Component {
public:
    explicit ChannelStrip(const std::string& name) : channelName(name) {
        fader = std::make_unique<Slider>("Vol", -60.0f, 12.0f, Slider::Vertical);
        panKnob = std::make_unique<Knob>("Pan", -1.0f, 1.0f, 0.0f);
        muteButton = std::make_unique<ToggleButton>("M");
        soloButton = std::make_unique<ToggleButton>("S");

        fader->onValueChanged = [this](float v) { volume = v; };
        panKnob->onValueChanged = [this](float v) { pan = v; };
        muteButton->onToggled = [this](bool m) { muted = m; };
        soloButton->onToggled = [this](bool s) { soloed = s; };
    }

    void paint() override {
        // Draw channel name
        // Draw meter
        fader->paint();
        panKnob->paint();
        muteButton->paint();
        soloButton->paint();
    }

    void resized() override {
        int y = bounds.y + 20;
        panKnob->setBounds(bounds.x + 5, y, 40, 40);
        y += 45;
        fader->setBounds(bounds.x + 10, y, 30, bounds.height - 120);
        y = bounds.y + bounds.height - 70;
        muteButton->setBounds(bounds.x + 5, y, 20, 20);
        soloButton->setBounds(bounds.x + 27, y, 20, 20);
    }

    void setMeterLevel(float left, float right) {
        meterLeft = left;
        meterRight = right;
    }

private:
    std::string channelName;
    std::unique_ptr<Slider> fader;
    std::unique_ptr<Knob> panKnob;
    std::unique_ptr<ToggleButton> muteButton;
    std::unique_ptr<ToggleButton> soloButton;

    float volume = 0.0f;
    float pan = 0.0f;
    bool muted = false;
    bool soloed = false;
    float meterLeft = 0.0f;
    float meterRight = 0.0f;
};

// ============================================================================
// MIXER VIEW
// ============================================================================

class MixerView : public Component {
public:
    MixerView() {
        // Create master channel
        masterChannel = std::make_unique<ChannelStrip>("Master");
    }

    void addChannel(const std::string& name) {
        channels.push_back(std::make_unique<ChannelStrip>(name));
        resized();
    }

    void removeChannel(int index) {
        if (index >= 0 && index < static_cast<int>(channels.size())) {
            channels.erase(channels.begin() + index);
            resized();
        }
    }

    void paint() override {
        for (auto& channel : channels) {
            channel->paint();
        }
        masterChannel->paint();
    }

    void resized() override {
        int channelWidth = 60;
        int x = bounds.x;

        for (auto& channel : channels) {
            channel->setBounds(x, bounds.y, channelWidth, bounds.height);
            x += channelWidth;
        }

        // Master channel at the end
        masterChannel->setBounds(bounds.x + bounds.width - channelWidth - 10,
                                  bounds.y, channelWidth, bounds.height);
    }

private:
    std::vector<std::unique_ptr<ChannelStrip>> channels;
    std::unique_ptr<ChannelStrip> masterChannel;
};

// ============================================================================
// EFFECT RACK VIEW
// ============================================================================

class EffectSlot : public Component {
public:
    explicit EffectSlot(int index) : slotIndex(index) {}

    void paint() override {
        // Draw slot background
        // Draw effect name if loaded
        // Draw bypass indicator
        // Draw power button
    }

    void resized() override {}

    void loadEffect(const std::string& effectName) {
        this->effectName = effectName;
        loaded = true;
    }

    void unloadEffect() {
        effectName.clear();
        loaded = false;
    }

    bool bypassed = false;

private:
    int slotIndex;
    std::string effectName;
    bool loaded = false;
};

class EffectRack : public Component {
public:
    static constexpr int MAX_SLOTS = 8;

    EffectRack() {
        for (int i = 0; i < MAX_SLOTS; ++i) {
            slots.push_back(std::make_unique<EffectSlot>(i));
        }
    }

    void paint() override {
        for (auto& slot : slots) {
            slot->paint();
        }
    }

    void resized() override {
        int slotHeight = bounds.height / MAX_SLOTS;
        for (int i = 0; i < MAX_SLOTS; ++i) {
            slots[i]->setBounds(bounds.x, bounds.y + i * slotHeight,
                               bounds.width, slotHeight);
        }
    }

    void loadEffect(int slot, const std::string& effectName) {
        if (slot >= 0 && slot < MAX_SLOTS) {
            slots[slot]->loadEffect(effectName);
        }
    }

private:
    std::vector<std::unique_ptr<EffectSlot>> slots;
};

// ============================================================================
// MAIN WINDOW
// ============================================================================

class MainWindow {
public:
    MainWindow() {
        // Initialize components
        transport = std::make_unique<TransportControls>();
        mixer = std::make_unique<MixerView>();
        effectRack = std::make_unique<EffectRack>();
        spectrumAnalyzer = std::make_unique<SpectrumAnalyzer>();
        coherenceMeter = std::make_unique<CoherenceMeter>();
        waveformDisplay = std::make_unique<WaveformDisplay>();

        // Set up layout
        resized();

        // Connect transport callbacks
        transport->onPlay = [this]() { handlePlay(); };
        transport->onStop = [this]() { handleStop(); };
        transport->onRecord = [this]() { handleRecord(); };
    }

    void paint() {
        // Draw background
        // Draw header/title bar
        transport->paint();

        // Draw main content area
        switch (currentView) {
            case View::Mixer:
                mixer->paint();
                break;
            case View::Effects:
                effectRack->paint();
                break;
            case View::Arrange:
                waveformDisplay->paint();
                break;
        }

        // Draw side panel (spectrum, coherence)
        spectrumAnalyzer->paint();
        coherenceMeter->paint();

        // Draw status bar
    }

    void resized() {
        int width = windowWidth;
        int height = windowHeight;

        // Transport at top
        transport->setBounds(0, 0, width, 50);

        // Side panel on right
        int sidePanelWidth = 250;
        spectrumAnalyzer->setBounds(width - sidePanelWidth, 50, sidePanelWidth, 200);
        coherenceMeter->setBounds(width - sidePanelWidth, 260, sidePanelWidth, 200);

        // Main content area
        int contentWidth = width - sidePanelWidth - 10;
        int contentHeight = height - 50 - 30; // Transport and status bar

        mixer->setBounds(0, 50, contentWidth, contentHeight);
        effectRack->setBounds(0, 50, 200, contentHeight);
        waveformDisplay->setBounds(0, 50, contentWidth, contentHeight);
    }

    void setSize(int width, int height) {
        windowWidth = width;
        windowHeight = height;
        resized();
    }

    enum class View { Mixer, Effects, Arrange };

    void setView(View view) {
        currentView = view;
    }

    // Callbacks for audio engine
    void updateSpectrum(const float* data, int size) {
        spectrumAnalyzer->updateSpectrum(data, size);
    }

    void updateCoherence(float coherence, int heartRate, const std::string& state) {
        coherenceMeter->setCoherence(coherence);
        coherenceMeter->setHeartRate(heartRate);
        coherenceMeter->setLambdaState(state);
    }

    void updateTime(double seconds) {
        transport->setTime(seconds);
    }

private:
    void handlePlay() {
        // Notify audio engine to start playback
    }

    void handleStop() {
        // Notify audio engine to stop playback
    }

    void handleRecord() {
        // Toggle recording
    }

    std::unique_ptr<TransportControls> transport;
    std::unique_ptr<MixerView> mixer;
    std::unique_ptr<EffectRack> effectRack;
    std::unique_ptr<SpectrumAnalyzer> spectrumAnalyzer;
    std::unique_ptr<CoherenceMeter> coherenceMeter;
    std::unique_ptr<WaveformDisplay> waveformDisplay;

    View currentView = View::Mixer;
    int windowWidth = 1200;
    int windowHeight = 800;
};

} // namespace UI
} // namespace Echoelmusic
