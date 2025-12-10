/**
 * MixerView.cpp
 * Professional mixing console implementation
 *
 * Copyright (c) 2025 Echoelmusic
 */

#include "MixerView.h"

namespace Echoelmusic {

//==============================================================================
// ChannelStrip Implementation
//==============================================================================

ChannelStrip::ChannelStrip(Track* track, int index)
    : track_(track), index_(index)
{
    // Track name
    nameLabel_.setText(track ? track->getName() : "---", juce::dontSendNotification);
    nameLabel_.setFont(juce::Font(12.0f, juce::Font::bold));
    nameLabel_.setColour(juce::Label::textColourId, VaporwaveColors::Cyan);
    nameLabel_.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(nameLabel_);

    // Volume fader (vertical)
    volumeFader_.setSliderStyle(juce::Slider::LinearVertical);
    volumeFader_.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 50, 18);
    volumeFader_.setRange(-60.0, 12.0, 0.1);
    volumeFader_.setValue(track ? juce::Decibels::gainToDecibels(track->getVolume()) : 0.0);
    volumeFader_.setSkewFactorFromMidPoint(-6.0);
    volumeFader_.setColour(juce::Slider::thumbColourId, VaporwaveColors::Cyan);
    volumeFader_.setColour(juce::Slider::trackColourId, VaporwaveColors::Surface);
    volumeFader_.setColour(juce::Slider::backgroundColourId, VaporwaveColors::Background);
    volumeFader_.addListener(this);
    addAndMakeVisible(volumeFader_);

    // Pan knob
    panKnob_.setSliderStyle(juce::Slider::RotaryHorizontalVerticalDrag);
    panKnob_.setTextBoxStyle(juce::Slider::NoTextBox, true, 0, 0);
    panKnob_.setRange(-1.0, 1.0, 0.01);
    panKnob_.setValue(track ? track->getPan() : 0.0);
    panKnob_.setColour(juce::Slider::rotarySliderFillColourId, VaporwaveColors::Magenta);
    panKnob_.setColour(juce::Slider::rotarySliderOutlineColourId, VaporwaveColors::Surface);
    panKnob_.addListener(this);
    addAndMakeVisible(panKnob_);

    // Mute button
    muteButton_.setButtonText("M");
    muteButton_.setColour(juce::TextButton::buttonColourId, VaporwaveColors::Surface);
    muteButton_.setColour(juce::TextButton::textColourOnId, VaporwaveColors::Yellow);
    muteButton_.setClickingTogglesState(true);
    muteButton_.setToggleState(track ? track->isMuted() : false, juce::dontSendNotification);
    muteButton_.addListener(this);
    addAndMakeVisible(muteButton_);

    // Solo button
    soloButton_.setButtonText("S");
    soloButton_.setColour(juce::TextButton::buttonColourId, VaporwaveColors::Surface);
    soloButton_.setColour(juce::TextButton::textColourOnId, VaporwaveColors::Green);
    soloButton_.setClickingTogglesState(true);
    soloButton_.setToggleState(track ? track->isSoloed() : false, juce::dontSendNotification);
    soloButton_.addListener(this);
    addAndMakeVisible(soloButton_);

    // Record arm button
    recordArmButton_.setButtonText("R");
    recordArmButton_.setColour(juce::TextButton::buttonColourId, VaporwaveColors::Surface);
    recordArmButton_.setColour(juce::TextButton::textColourOnId, VaporwaveColors::Red);
    recordArmButton_.setClickingTogglesState(true);
    recordArmButton_.setToggleState(track ? track->isArmed() : false, juce::dontSendNotification);
    recordArmButton_.addListener(this);
    addAndMakeVisible(recordArmButton_);
}

ChannelStrip::~ChannelStrip()
{
}

void ChannelStrip::paint(juce::Graphics& g)
{
    auto bounds = getLocalBounds();

    // Background
    g.setColour(selected_ ? VaporwaveColors::Purple.withAlpha(0.3f) : VaporwaveColors::Surface);
    g.fillRoundedRectangle(bounds.toFloat(), 4.0f);

    // Border (glow when selected)
    g.setColour(selected_ ? VaporwaveColors::Cyan : VaporwaveColors::Cyan.withAlpha(0.3f));
    g.drawRoundedRectangle(bounds.toFloat().reduced(0.5f), 4.0f, selected_ ? 2.0f : 1.0f);

    // Meter area (left side of fader)
    auto meterArea = bounds.reduced(5, 60);
    meterArea = meterArea.removeFromLeft(20);
    meterArea.removeFromTop(25);  // Space for pan knob

    // Draw stereo meters
    auto meterL = meterArea.removeFromLeft(8);
    auto meterR = meterArea.removeFromRight(8);
    drawMeter(g, meterL, peakLevelL_, rmsLevelL_, true);
    drawMeter(g, meterR, peakLevelR_, rmsLevelR_, false);

    // EQ/Comp indicators
    auto indicatorArea = bounds.removeFromBottom(20).reduced(5, 2);
    g.setFont(juce::Font(9.0f));

    // EQ indicator
    auto eqBounds = indicatorArea.removeFromLeft(25);
    g.setColour(eqEnabled_ ? VaporwaveColors::Cyan : VaporwaveColors::TextDim);
    g.drawText("EQ", eqBounds, juce::Justification::centred);

    indicatorArea.removeFromLeft(5);

    // Comp indicator
    auto compBounds = indicatorArea.removeFromLeft(25);
    g.setColour(compEnabled_ ? VaporwaveColors::Magenta : VaporwaveColors::TextDim);
    g.drawText("C", compBounds, juce::Justification::centred);
}

void ChannelStrip::resized()
{
    auto bounds = getLocalBounds().reduced(5);

    // Track name (top)
    nameLabel_.setBounds(bounds.removeFromTop(20));
    bounds.removeFromTop(5);

    // Record arm button (top right area)
    auto topButtonArea = bounds.removeFromTop(25);
    recordArmButton_.setBounds(topButtonArea.removeFromRight(25));

    // Pan knob (below name)
    auto panArea = bounds.removeFromTop(40);
    panKnob_.setBounds(panArea.withSizeKeepingCentre(40, 40));
    bounds.removeFromTop(5);

    // Mute/Solo buttons
    auto buttonArea = bounds.removeFromTop(25);
    muteButton_.setBounds(buttonArea.removeFromLeft(buttonArea.getWidth() / 2).reduced(2, 0));
    soloButton_.setBounds(buttonArea.reduced(2, 0));
    bounds.removeFromTop(5);

    // Volume fader (remaining space, leaving room for meter on left)
    auto faderArea = bounds;
    faderArea.removeFromLeft(25);  // Space for meters
    volumeFader_.setBounds(faderArea);
}

void ChannelStrip::sliderValueChanged(juce::Slider* slider)
{
    if (!track_) return;

    if (slider == &volumeFader_)
    {
        float gain = juce::Decibels::decibelsToGain((float)volumeFader_.getValue());
        track_->setVolume(gain);
    }
    else if (slider == &panKnob_)
    {
        track_->setPan((float)panKnob_.getValue());
    }
}

void ChannelStrip::buttonClicked(juce::Button* button)
{
    if (!track_) return;

    if (button == &muteButton_)
    {
        track_->setMuted(muteButton_.getToggleState());
        muteButton_.setColour(juce::TextButton::buttonColourId,
            muteButton_.getToggleState() ? VaporwaveColors::Yellow.withAlpha(0.5f) : VaporwaveColors::Surface);
    }
    else if (button == &soloButton_)
    {
        track_->setSoloed(soloButton_.getToggleState());
        soloButton_.setColour(juce::TextButton::buttonColourId,
            soloButton_.getToggleState() ? VaporwaveColors::Green.withAlpha(0.5f) : VaporwaveColors::Surface);
    }
    else if (button == &recordArmButton_)
    {
        track_->setArmed(recordArmButton_.getToggleState());
        recordArmButton_.setColour(juce::TextButton::buttonColourId,
            recordArmButton_.getToggleState() ? VaporwaveColors::Red.withAlpha(0.5f) : VaporwaveColors::Surface);
    }
}

void ChannelStrip::updateMeters()
{
    if (!track_) return;

    // Get current levels from track
    peakLevelL_ = track_->getPeakLevel(0);
    peakLevelR_ = track_->getPeakLevel(1);
    rmsLevelL_ = track_->getRMSLevel(0);
    rmsLevelR_ = track_->getRMSLevel(1);

    repaint();
}

void ChannelStrip::setSelected(bool selected)
{
    if (selected_ != selected)
    {
        selected_ = selected;
        repaint();
    }
}

void ChannelStrip::drawMeter(juce::Graphics& g, juce::Rectangle<int> bounds,
                              float peakLevel, float rmsLevel, bool isLeft)
{
    juce::ignoreUnused(isLeft);

    // Background
    g.setColour(VaporwaveColors::Background);
    g.fillRoundedRectangle(bounds.toFloat(), 2.0f);

    // Convert to dB
    float peakDB = juce::Decibels::gainToDecibels(peakLevel, -60.0f);
    float rmsDB = juce::Decibels::gainToDecibels(rmsLevel, -60.0f);

    // Normalize to 0-1
    float peakNorm = juce::jmap(peakDB, -60.0f, 6.0f, 0.0f, 1.0f);
    float rmsNorm = juce::jmap(rmsDB, -60.0f, 6.0f, 0.0f, 1.0f);
    peakNorm = juce::jlimit(0.0f, 1.0f, peakNorm);
    rmsNorm = juce::jlimit(0.0f, 1.0f, rmsNorm);

    // RMS meter (filled)
    auto rmsBounds = bounds.toFloat();
    float rmsHeight = rmsBounds.getHeight() * rmsNorm;
    rmsBounds.removeFromTop(rmsBounds.getHeight() - rmsHeight);

    // Gradient: Green -> Yellow -> Red
    auto gradient = juce::ColourGradient(
        VaporwaveColors::Green, bounds.getCentreX(), (float)bounds.getBottom(),
        VaporwaveColors::Red, bounds.getCentreX(), (float)bounds.getY(),
        false);
    gradient.addColour(0.7, VaporwaveColors::Yellow);

    g.setGradientFill(gradient);
    g.fillRoundedRectangle(rmsBounds, 2.0f);

    // Peak line
    float peakY = bounds.getY() + bounds.getHeight() * (1.0f - peakNorm);
    g.setColour(VaporwaveColors::Cyan);
    g.drawHorizontalLine((int)peakY, (float)bounds.getX(), (float)bounds.getRight());

    // Clip indicator
    if (peakDB > 0.0f)
    {
        g.setColour(VaporwaveColors::Red);
        g.fillRect(bounds.removeFromTop(5));
    }
}

void ChannelStrip::drawPanIndicator(juce::Graphics& g, juce::Rectangle<int> bounds)
{
    // Pan position visualization
    float pan = track_ ? track_->getPan() : 0.0f;
    float centerX = bounds.getCentreX();
    float panX = centerX + pan * (bounds.getWidth() / 2.0f - 5.0f);

    g.setColour(VaporwaveColors::Magenta);
    g.fillEllipse(panX - 3, bounds.getCentreY() - 3, 6, 6);
}

//==============================================================================
// MasterChannel Implementation
//==============================================================================

MasterChannel::MasterChannel(AudioEngine& engine)
    : audioEngine_(engine)
{
    // Name label
    nameLabel_.setText("MASTER", juce::dontSendNotification);
    nameLabel_.setFont(juce::Font(14.0f, juce::Font::bold));
    nameLabel_.setColour(juce::Label::textColourId, VaporwaveColors::Magenta);
    nameLabel_.setJustificationType(juce::Justification::centred);
    addAndMakeVisible(nameLabel_);

    // Volume fader
    volumeFader_.setSliderStyle(juce::Slider::LinearVertical);
    volumeFader_.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 60, 18);
    volumeFader_.setRange(-60.0, 12.0, 0.1);
    volumeFader_.setValue(0.0);  // 0 dB default
    volumeFader_.setSkewFactorFromMidPoint(-6.0);
    volumeFader_.setColour(juce::Slider::thumbColourId, VaporwaveColors::Magenta);
    volumeFader_.setColour(juce::Slider::trackColourId, VaporwaveColors::Surface);
    volumeFader_.addListener(this);
    addAndMakeVisible(volumeFader_);
}

MasterChannel::~MasterChannel()
{
}

void MasterChannel::paint(juce::Graphics& g)
{
    auto bounds = getLocalBounds();

    // Background with gradient
    auto gradient = juce::ColourGradient(
        VaporwaveColors::Purple.withAlpha(0.3f), 0, 0,
        VaporwaveColors::Surface, 0, (float)bounds.getHeight(),
        false);
    g.setGradientFill(gradient);
    g.fillRoundedRectangle(bounds.toFloat(), 6.0f);

    // Border glow
    g.setColour(VaporwaveColors::Magenta.withAlpha(0.5f));
    g.drawRoundedRectangle(bounds.toFloat().reduced(0.5f), 6.0f, 2.0f);

    // Meter area
    auto meterArea = bounds.reduced(10, 70);
    meterArea = meterArea.removeFromLeft(40);
    meterArea.removeFromTop(30);  // Space for LUFS display
    drawStereoMeter(g, meterArea);

    // LUFS display
    auto lufsArea = bounds.reduced(5, 0);
    lufsArea = lufsArea.removeFromTop(60);
    lufsArea.removeFromTop(25);  // Space for name
    drawLUFSMeter(g, lufsArea);
}

void MasterChannel::resized()
{
    auto bounds = getLocalBounds().reduced(5);

    // Name (top)
    nameLabel_.setBounds(bounds.removeFromTop(25));
    bounds.removeFromTop(40);  // Space for LUFS display

    // Fader (right side, leaving space for meters)
    auto faderArea = bounds;
    faderArea.removeFromLeft(50);  // Space for stereo meters
    volumeFader_.setBounds(faderArea);
}

void MasterChannel::sliderValueChanged(juce::Slider* slider)
{
    if (slider == &volumeFader_)
    {
        float gain = juce::Decibels::decibelsToGain((float)volumeFader_.getValue());
        audioEngine_.setMasterVolume(gain);
    }
}

void MasterChannel::updateMeters()
{
    peakLevelL_ = audioEngine_.getMasterPeakLevel();
    peakLevelR_ = audioEngine_.getMasterPeakLevel();  // TODO: Separate L/R
    rmsLevelL_ = peakLevelL_ * 0.7f;  // Approximation
    rmsLevelR_ = peakLevelR_ * 0.7f;

    // LUFS would come from the LUFS meter in AudioEngine
    // For now, estimate from RMS
    lufsShortTerm_ = juce::Decibels::gainToDecibels(rmsLevelL_, -60.0f) - 3.0f;
    lufsIntegrated_ = lufsShortTerm_;  // Would be averaged over time

    repaint();
}

void MasterChannel::setLUFS(float shortTerm, float integrated, float range)
{
    lufsShortTerm_ = shortTerm;
    lufsIntegrated_ = integrated;
    lufsRange_ = range;
    repaint();
}

void MasterChannel::drawStereoMeter(juce::Graphics& g, juce::Rectangle<int> bounds)
{
    // Background
    g.setColour(VaporwaveColors::Background);
    g.fillRoundedRectangle(bounds.toFloat(), 4.0f);

    auto leftMeter = bounds.removeFromLeft(bounds.getWidth() / 2 - 2);
    bounds.removeFromLeft(4);
    auto rightMeter = bounds;

    // Convert to dB and normalize
    auto drawMeterBar = [&](juce::Rectangle<int> area, float peak, float rms) {
        float peakDB = juce::Decibels::gainToDecibels(peak, -60.0f);
        float rmsDB = juce::Decibels::gainToDecibels(rms, -60.0f);
        float peakNorm = juce::jmap(peakDB, -60.0f, 6.0f, 0.0f, 1.0f);
        float rmsNorm = juce::jmap(rmsDB, -60.0f, 6.0f, 0.0f, 1.0f);
        peakNorm = juce::jlimit(0.0f, 1.0f, peakNorm);
        rmsNorm = juce::jlimit(0.0f, 1.0f, rmsNorm);

        // RMS fill
        auto rmsBounds = area.toFloat();
        float rmsHeight = rmsBounds.getHeight() * rmsNorm;
        rmsBounds.removeFromTop(rmsBounds.getHeight() - rmsHeight);

        auto gradient = juce::ColourGradient(
            VaporwaveColors::Cyan, area.getCentreX(), (float)area.getBottom(),
            VaporwaveColors::Red, area.getCentreX(), (float)area.getY(),
            false);
        gradient.addColour(0.6, VaporwaveColors::Green);
        gradient.addColour(0.85, VaporwaveColors::Yellow);

        g.setGradientFill(gradient);
        g.fillRoundedRectangle(rmsBounds, 2.0f);

        // Peak line
        float peakY = area.getY() + area.getHeight() * (1.0f - peakNorm);
        g.setColour(VaporwaveColors::Text);
        g.drawHorizontalLine((int)peakY, (float)area.getX(), (float)area.getRight());
    };

    drawMeterBar(leftMeter, peakLevelL_, rmsLevelL_);
    drawMeterBar(rightMeter, peakLevelR_, rmsLevelR_);

    // L/R labels
    g.setColour(VaporwaveColors::TextDim);
    g.setFont(juce::Font(9.0f));
    g.drawText("L", leftMeter.removeFromBottom(12), juce::Justification::centred);
    g.drawText("R", rightMeter.removeFromBottom(12), juce::Justification::centred);
}

void MasterChannel::drawLUFSMeter(juce::Graphics& g, juce::Rectangle<int> bounds)
{
    g.setFont(juce::Font(10.0f));

    // Short-term LUFS
    g.setColour(VaporwaveColors::Cyan);
    juce::String shortTermStr = juce::String(lufsShortTerm_, 1) + " LUFS";
    g.drawText(shortTermStr, bounds.removeFromTop(15), juce::Justification::centred);

    // Integrated LUFS
    g.setColour(VaporwaveColors::TextDim);
    juce::String integratedStr = "Int: " + juce::String(lufsIntegrated_, 1);
    g.drawText(integratedStr, bounds.removeFromTop(12), juce::Justification::centred);

    // Target indicator (-14 LUFS for streaming)
    bool isLoud = lufsShortTerm_ > -14.0f;
    g.setColour(isLoud ? VaporwaveColors::Red : VaporwaveColors::Green);
    g.drawText(isLoud ? "LOUD" : "OK", bounds, juce::Justification::centred);
}

//==============================================================================
// MixerView Implementation
//==============================================================================

MixerView::MixerView(AudioEngine& engine)
    : audioEngine_(engine)
{
    // Horizontal scrollbar
    horizontalScrollBar_ = std::make_unique<juce::ScrollBar>(false);
    horizontalScrollBar_->addListener(this);
    addAndMakeVisible(horizontalScrollBar_.get());

    // Master channel
    masterChannel_ = std::make_unique<MasterChannel>(engine);
    addAndMakeVisible(masterChannel_.get());

    // Build channel strips
    rebuildChannelStrips();

    // Start meter update timer (30 FPS)
    startTimer(33);
}

MixerView::~MixerView()
{
    stopTimer();
}

void MixerView::paint(juce::Graphics& g)
{
    drawBackground(g);
}

void MixerView::resized()
{
    auto bounds = getLocalBounds();

    // Scrollbar at bottom
    horizontalScrollBar_->setBounds(bounds.removeFromBottom(15));

    // Master channel on right
    masterChannel_->setBounds(bounds.removeFromRight(120).reduced(5));

    // Separator
    bounds.removeFromRight(5);

    // Channel strips
    int numChannels = channelStrips_.size();
    int totalWidth = numChannels * channelWidth_;

    // Update scrollbar range
    horizontalScrollBar_->setRangeLimits(0.0, (double)totalWidth);
    horizontalScrollBar_->setCurrentRange(scrollOffset_, bounds.getWidth());

    // Position channel strips
    int xOffset = -(int)scrollOffset_;
    for (auto* strip : channelStrips_)
    {
        strip->setBounds(bounds.getX() + xOffset, bounds.getY(),
                        channelWidth_ - 5, bounds.getHeight());
        xOffset += channelWidth_;
    }
}

void MixerView::timerCallback()
{
    // Update all meters
    for (auto* strip : channelStrips_)
        strip->updateMeters();

    masterChannel_->updateMeters();
}

void MixerView::scrollBarMoved(juce::ScrollBar* scrollBar, double newRangeStart)
{
    if (scrollBar == horizontalScrollBar_.get())
    {
        scrollOffset_ = newRangeStart;
        resized();
    }
}

void MixerView::updateFromEngine()
{
    rebuildChannelStrips();
}

void MixerView::selectChannel(int index)
{
    if (index == selectedChannel_)
        return;

    // Deselect previous
    if (selectedChannel_ >= 0 && selectedChannel_ < channelStrips_.size())
        channelStrips_[selectedChannel_]->setSelected(false);

    selectedChannel_ = index;

    // Select new
    if (selectedChannel_ >= 0 && selectedChannel_ < channelStrips_.size())
        channelStrips_[selectedChannel_]->setSelected(true);
}

void MixerView::setViewMode(ViewMode mode)
{
    viewMode_ = mode;

    switch (mode)
    {
        case ViewMode::Full:
            channelWidth_ = 100;
            break;
        case ViewMode::Compact:
            channelWidth_ = 70;
            break;
        case ViewMode::Meters:
            channelWidth_ = 40;
            break;
    }

    resized();
}

void MixerView::rebuildChannelStrips()
{
    channelStrips_.clear();

    int numTracks = audioEngine_.getNumTracks();
    for (int i = 0; i < numTracks; ++i)
    {
        auto* track = audioEngine_.getTrack(i);
        auto strip = std::make_unique<ChannelStrip>(track, i);
        addAndMakeVisible(strip.get());
        channelStrips_.add(strip.release());
    }

    resized();
}

void MixerView::drawBackground(juce::Graphics& g)
{
    auto bounds = getLocalBounds();

    // Background
    g.fillAll(VaporwaveColors::Background);

    // Scanlines (subtle CRT effect)
    g.setColour(juce::Colours::black.withAlpha(0.03f));
    for (int y = 0; y < bounds.getHeight(); y += 2)
        g.drawHorizontalLine(y, 0, (float)bounds.getWidth());

    // Glow border at top
    g.setColour(VaporwaveColors::Purple.withAlpha(0.5f));
    g.drawLine(0, 0, (float)bounds.getWidth(), 0, 2.0f);
}

} // namespace Echoelmusic
