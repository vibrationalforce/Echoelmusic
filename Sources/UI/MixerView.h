#pragma once

#include <JuceHeader.h>
#include "../Audio/AudioEngine.h"
#include "../Audio/Track.h"

/**
 * MixerView.h
 * Professional mixing console with Vaporwave aesthetic
 *
 * Features:
 * - Channel strips with faders, pan, mute/solo
 * - VU/Peak metering per channel
 * - Master bus with LUFS metering
 * - Send/Return routing
 * - EQ and compressor quick controls
 * - Bio-reactive visual feedback
 *
 * Copyright (c) 2025 Echoelmusic
 */

namespace Echoelmusic {

//==============================================================================
// Vaporwave Colors (shared with MainWindow)
//==============================================================================
namespace VaporwaveColors
{
    inline const juce::Colour Cyan       (0xff00e5ff);
    inline const juce::Colour Magenta    (0xffff00ff);
    inline const juce::Colour Purple     (0xff651fff);
    inline const juce::Colour Background (0xff1a1a2e);
    inline const juce::Colour Surface    (0xff16213e);
    inline const juce::Colour Text       (0xffffffff);
    inline const juce::Colour TextDim    (0xffaaaaaa);
    inline const juce::Colour Green      (0xff00ff88);
    inline const juce::Colour Yellow     (0xffffff00);
    inline const juce::Colour Red        (0xffff4444);
}

//==============================================================================
// Channel Strip - Individual track controls
//==============================================================================
class ChannelStrip : public juce::Component,
                     public juce::Slider::Listener,
                     public juce::Button::Listener
{
public:
    ChannelStrip(Track* track, int index);
    ~ChannelStrip() override;

    void paint(juce::Graphics& g) override;
    void resized() override;
    void sliderValueChanged(juce::Slider* slider) override;
    void buttonClicked(juce::Button* button) override;

    void updateMeters();
    void setSelected(bool selected);
    bool isSelected() const { return selected_; }

    Track* getTrack() const { return track_; }
    int getIndex() const { return index_; }

private:
    Track* track_;
    int index_;
    bool selected_ = false;

    // Controls
    juce::Label nameLabel_;
    juce::Slider volumeFader_;
    juce::Slider panKnob_;
    juce::TextButton muteButton_;
    juce::TextButton soloButton_;
    juce::TextButton recordArmButton_;

    // Metering
    float peakLevelL_ = 0.0f;
    float peakLevelR_ = 0.0f;
    float rmsLevelL_ = 0.0f;
    float rmsLevelR_ = 0.0f;

    // EQ/Comp indicators
    bool eqEnabled_ = false;
    bool compEnabled_ = false;

    void drawMeter(juce::Graphics& g, juce::Rectangle<int> bounds,
                   float peakLevel, float rmsLevel, bool isLeft);
    void drawPanIndicator(juce::Graphics& g, juce::Rectangle<int> bounds);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ChannelStrip)
};

//==============================================================================
// Master Channel - Main bus output
//==============================================================================
class MasterChannel : public juce::Component,
                      public juce::Slider::Listener
{
public:
    MasterChannel(AudioEngine& engine);
    ~MasterChannel() override;

    void paint(juce::Graphics& g) override;
    void resized() override;
    void sliderValueChanged(juce::Slider* slider) override;

    void updateMeters();
    void setLUFS(float shortTerm, float integrated, float range);

private:
    AudioEngine& audioEngine_;

    // Controls
    juce::Label nameLabel_;
    juce::Slider volumeFader_;

    // Stereo metering
    float peakLevelL_ = 0.0f;
    float peakLevelR_ = 0.0f;
    float rmsLevelL_ = 0.0f;
    float rmsLevelR_ = 0.0f;

    // LUFS metering
    float lufsShortTerm_ = -23.0f;
    float lufsIntegrated_ = -23.0f;
    float lufsRange_ = 0.0f;

    void drawStereoMeter(juce::Graphics& g, juce::Rectangle<int> bounds);
    void drawLUFSMeter(juce::Graphics& g, juce::Rectangle<int> bounds);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MasterChannel)
};

//==============================================================================
// MixerView - Main mixer console view
//==============================================================================
class MixerView : public juce::Component,
                  public juce::Timer,
                  public juce::ScrollBar::Listener
{
public:
    MixerView(AudioEngine& engine);
    ~MixerView() override;

    void paint(juce::Graphics& g) override;
    void resized() override;
    void timerCallback() override;
    void scrollBarMoved(juce::ScrollBar* scrollBar, double newRangeStart) override;

    void updateFromEngine();  // Refresh channel strips from engine
    void selectChannel(int index);
    int getSelectedChannel() const { return selectedChannel_; }

    // View modes
    enum class ViewMode {
        Full,       // All controls visible
        Compact,    // Faders and meters only
        Meters      // Meters only (performance mode)
    };
    void setViewMode(ViewMode mode);
    ViewMode getViewMode() const { return viewMode_; }

private:
    AudioEngine& audioEngine_;

    // Channel strips
    juce::OwnedArray<ChannelStrip> channelStrips_;
    std::unique_ptr<MasterChannel> masterChannel_;

    // Scrolling
    std::unique_ptr<juce::ScrollBar> horizontalScrollBar_;
    double scrollOffset_ = 0.0;

    // Selection
    int selectedChannel_ = -1;

    // View mode
    ViewMode viewMode_ = ViewMode::Full;
    int channelWidth_ = 100;  // Width per channel

    // Bio-reactive
    bool bioReactiveEnabled_ = false;
    float bioCoherence_ = 0.5f;

    void rebuildChannelStrips();
    void drawBackground(juce::Graphics& g);

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MixerView)
};

} // namespace Echoelmusic
