#pragma once

#include <JuceHeader.h>
#include "../Wellness/AudioVisualEntrainment.h"
#include "../Wellness/ColorLightTherapy.h"
#include "../Wellness/VibrotherapySystem.h"

//==============================================================================
/**
 * @brief Wellness Control Panel - UI Integration
 *
 * Unified control panel for all wellness features:
 * - Audio-Visual Entrainment (AVE)
 * - Color Light Therapy
 * - Vibrotherapy
 *
 * **WICHTIG**: Alle Features mit Safety Warnings & Acknowledgment!
 *
 * Design für: Kreativ + Gesund + Mobil + Biofeedback
 */
class WellnessControlPanel : public juce::Component,
                             public juce::Timer
{
public:
    //==============================================================================
    WellnessControlPanel()
    {
        // Initialize systems
        aveSystem = std::make_unique<AudioVisualEntrainment>();
        colorTherapy = std::make_unique<ColorLightTherapy>();
        vibroSystem = std::make_unique<VibrotherapySystem>();

        setupUI();
        startTimerHz(30);  // 30 FPS updates
    }

    ~WellnessControlPanel() override
    {
        stopTimer();
    }

    //==============================================================================
    void paint(juce::Graphics& g) override
    {
        // Background
        g.fillAll(juce::Colour(0xff1a1a1a));

        // Title
        g.setColour(juce::Colours::white);
        g.setFont(24.0f);
        g.drawText("Wellness Suite 🧘‍♀️", getLocalBounds().removeFromTop(40), juce::Justification::centred);

        // Safety Warning Banner
        if (!safetyAcknowledged)
        {
            auto warningBanner = getLocalBounds().removeFromTop(80).reduced(10);
            g.setColour(juce::Colours::red.withAlpha(0.3f));
            g.fillRect(warningBanner);
            g.setColour(juce::Colours::red);
            g.drawRect(warningBanner, 2);
            g.setFont(14.0f);
            g.drawText("⚠️ SAFETY WARNING: Read disclaimers before use! ⚠️",
                      warningBanner, juce::Justification::centred);
        }
    }

    void resized() override
    {
        auto bounds = getLocalBounds().reduced(10);
        bounds.removeFromTop(40);  // Title

        // Safety warning area
        if (!safetyAcknowledged)
            bounds.removeFromTop(80);

        // Safety Acknowledgment Button (if not acknowledged)
        if (!safetyAcknowledged)
        {
            safetyButton.setBounds(bounds.removeFromTop(40).reduced(10));
        }

        bounds.removeFromTop(10);  // Spacing

        // Split into 3 columns (AVE, Color, Vibro)
        int panelWidth = bounds.getWidth() / 3 - 10;

        auto aveArea = bounds.removeFromLeft(panelWidth);
        bounds.removeFromLeft(10);  // Spacing
        auto colorArea = bounds.removeFromLeft(panelWidth);
        bounds.removeFromLeft(10);  // Spacing
        auto vibroArea = bounds;

        layoutAVEPanel(aveArea);
        layoutColorPanel(colorArea);
        layoutVibroPanel(vibroArea);
    }

    //==============================================================================
    void timerCallback() override
    {
        // Update systems
        float deltaTime = 1.0f / 30.0f;

        if (aveSystem)
            aveSystem->update(deltaTime);

        if (colorTherapy)
            colorTherapy->update(deltaTime);

        if (vibroSystem)
            vibroSystem->update(deltaTime);

        // Update UI displays
        updateStatusDisplays();
    }

    //==============================================================================
    // Get current wellness states (for audio/visual rendering)
    const AudioVisualEntrainment::SessionState& getAVEState() const
    {
        return aveSystem->getSessionState();
    }

    const ColorLightTherapy::ColorState& getColorState() const
    {
        return colorTherapy->getColorState();
    }

    float getVibrationAmplitude() const
    {
        return vibroSystem->getVibrationAmplitude();
    }

private:
    //==============================================================================
    void setupUI()
    {
        // Safety Acknowledgment Button
        addAndMakeVisible(safetyButton);
        safetyButton.setButtonText("I ACKNOWLEDGE SAFETY WARNINGS");
        safetyButton.setColour(juce::TextButton::buttonColourId, juce::Colours::red);
        safetyButton.onClick = [this]
        {
            // Show full safety warning dialog
            if (showSafetyWarningDialog())
            {
                safetyAcknowledged = true;
                safetyButton.setVisible(false);
                resized();
            }
        };

        // === AVE CONTROLS ===
        addAndMakeVisible(aveLabel);
        aveLabel.setText("Audio-Visual Entrainment", juce::dontSendNotification);
        aveLabel.setColour(juce::Label::textColourId, juce::Colours::cyan);
        aveLabel.setFont(juce::Font(16.0f, juce::Font::bold));

        addAndMakeVisible(aveBandCombo);
        aveBandCombo.addItem("Delta (0.5-4 Hz) - Deep Sleep", 1);
        aveBandCombo.addItem("Theta (4-8 Hz) - Meditation", 2);
        aveBandCombo.addItem("Alpha (8-13 Hz) - Relaxation", 3);
        aveBandCombo.addItem("Beta (13-30 Hz) - Focus", 4);
        aveBandCombo.addItem("Gamma (30-100 Hz) - High Focus", 5);
        aveBandCombo.setSelectedId(3);  // Default: Alpha

        addAndMakeVisible(aveIntensitySlider);
        aveIntensitySlider.setRange(0.0, 0.3, 0.01);  // Max 30% (safety!)
        aveIntensitySlider.setValue(0.15);
        aveIntensitySlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 60, 20);

        addAndMakeVisible(aveIntensityLabel);
        aveIntensityLabel.setText("Intensity", juce::dontSendNotification);
        aveIntensityLabel.attachToComponent(&aveIntensitySlider, false);

        addAndMakeVisible(aveStartButton);
        aveStartButton.setButtonText("Start AVE");
        aveStartButton.setColour(juce::TextButton::buttonColourId, juce::Colours::green);
        aveStartButton.onClick = [this] { toggleAVE(); };

        addAndMakeVisible(aveStatusLabel);
        aveStatusLabel.setText("Status: Stopped", juce::dontSendNotification);
        aveStatusLabel.setColour(juce::Label::textColourId, juce::Colours::grey);

        // === COLOR THERAPY CONTROLS ===
        addAndMakeVisible(colorLabel);
        colorLabel.setText("Color Light Therapy", juce::dontSendNotification);
        colorLabel.setColour(juce::Label::textColourId, juce::Colours::orange);
        colorLabel.setFont(juce::Font(16.0f, juce::Font::bold));

        addAndMakeVisible(colorModeCombo);
        colorModeCombo.addItem("Warm (< 3000K) - Evening", 1);
        colorModeCombo.addItem("Neutral (4000-5000K)", 2);
        colorModeCombo.addItem("Cool (> 6000K) - Morning", 3);
        colorModeCombo.addItem("Daylight (5500-6500K)", 4);
        colorModeCombo.addItem("Sunset (2000-3000K)", 5);
        colorModeCombo.addItem("Night (Deep Red)", 6);
        colorModeCombo.setSelectedId(2);  // Default: Neutral

        addAndMakeVisible(colorIntensitySlider);
        colorIntensitySlider.setRange(0.0, 0.5, 0.01);  // Max 50% (safety!)
        colorIntensitySlider.setValue(0.25);
        colorIntensitySlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 60, 20);

        addAndMakeVisible(colorIntensityLabel);
        colorIntensityLabel.setText("Intensity", juce::dontSendNotification);
        colorIntensityLabel.attachToComponent(&colorIntensitySlider, false);

        addAndMakeVisible(colorStartButton);
        colorStartButton.setButtonText("Start Color");
        colorStartButton.setColour(juce::TextButton::buttonColourId, juce::Colours::orange);
        colorStartButton.onClick = [this] { toggleColor(); };

        addAndMakeVisible(colorStatusLabel);
        colorStatusLabel.setText("Status: Stopped", juce::dontSendNotification);
        colorStatusLabel.setColour(juce::Label::textColourId, juce::Colours::grey);

        // === VIBROTHERAPY CONTROLS ===
        addAndMakeVisible(vibroLabel);
        vibroLabel.setText("Vibrotherapy", juce::dontSendNotification);
        vibroLabel.setColour(juce::Label::textColourId, juce::Colours::magenta);
        vibroLabel.setFont(juce::Font(16.0f, juce::Font::bold));

        addAndMakeVisible(vibroModeCombo);
        vibroModeCombo.addItem("Low Freq (10-50 Hz) - Deep", 1);
        vibroModeCombo.addItem("Mid Freq (50-200 Hz) - Clear", 2);
        vibroModeCombo.addItem("High Freq (200-400 Hz) - Fine", 3);
        vibroModeCombo.addItem("Pulsed Pattern", 4);
        vibroModeCombo.addItem("Ramped Intensity", 5);
        vibroModeCombo.addItem("Audio Sync", 6);
        vibroModeCombo.setSelectedId(2);  // Default: Mid Freq

        addAndMakeVisible(vibroIntensitySlider);
        vibroIntensitySlider.setRange(0.0, 0.5, 0.01);  // Max 50% (safety!)
        vibroIntensitySlider.setValue(0.25);
        vibroIntensitySlider.setTextBoxStyle(juce::Slider::TextBoxBelow, false, 60, 20);

        addAndMakeVisible(vibroIntensityLabel);
        vibroIntensityLabel.setText("Intensity", juce::dontSendNotification);
        vibroIntensityLabel.attachToComponent(&vibroIntensitySlider, false);

        addAndMakeVisible(vibroStartButton);
        vibroStartButton.setButtonText("Start Vibro");
        vibroStartButton.setColour(juce::TextButton::buttonColourId, juce::Colours::magenta);
        vibroStartButton.onClick = [this] { toggleVibro(); };

        addAndMakeVisible(vibroStatusLabel);
        vibroStatusLabel.setText("Status: Stopped", juce::dontSendNotification);
        vibroStatusLabel.setColour(juce::Label::textColourId, juce::Colours::grey);

        // === EMERGENCY STOP (PROMINENT!) ===
        addAndMakeVisible(emergencyStopButton);
        emergencyStopButton.setButtonText("🛑 EMERGENCY STOP ALL 🛑");
        emergencyStopButton.setColour(juce::TextButton::buttonColourId, juce::Colours::darkred);
        emergencyStopButton.onClick = [this] { emergencyStopAll(); };
    }

    //==============================================================================
    void layoutAVEPanel(juce::Rectangle<int> area)
    {
        aveLabel.setBounds(area.removeFromTop(25));
        area.removeFromTop(5);
        aveBandCombo.setBounds(area.removeFromTop(30));
        area.removeFromTop(25);  // Space for label
        aveIntensitySlider.setBounds(area.removeFromTop(60));
        area.removeFromTop(10);
        aveStartButton.setBounds(area.removeFromTop(35));
        area.removeFromTop(5);
        aveStatusLabel.setBounds(area.removeFromTop(25));
    }

    void layoutColorPanel(juce::Rectangle<int> area)
    {
        colorLabel.setBounds(area.removeFromTop(25));
        area.removeFromTop(5);
        colorModeCombo.setBounds(area.removeFromTop(30));
        area.removeFromTop(25);  // Space for label
        colorIntensitySlider.setBounds(area.removeFromTop(60));
        area.removeFromTop(10);
        colorStartButton.setBounds(area.removeFromTop(35));
        area.removeFromTop(5);
        colorStatusLabel.setBounds(area.removeFromTop(25));
    }

    void layoutVibroPanel(juce::Rectangle<int> area)
    {
        vibroLabel.setBounds(area.removeFromTop(25));
        area.removeFromTop(5);
        vibroModeCombo.setBounds(area.removeFromTop(30));
        area.removeFromTop(25);  // Space for label
        vibroIntensitySlider.setBounds(area.removeFromTop(60));
        area.removeFromTop(10);
        vibroStartButton.setBounds(area.removeFromTop(35));
        area.removeFromTop(5);
        vibroStatusLabel.setBounds(area.removeFromTop(25));

        // Emergency stop at bottom
        area.removeFromTop(20);
        emergencyStopButton.setBounds(area.removeFromTop(50));
    }

    //==============================================================================
    bool showSafetyWarningDialog()
    {
        juce::String warningText = SafetyWarningText::getFullWarningText();

        juce::AlertWindow::showMessageBox(
            juce::AlertWindow::WarningIcon,
            "⚠️ SAFETY WARNING - WICHTIG ⚠️",
            warningText,
            "I ACKNOWLEDGE"
        );

        return true;  // User acknowledged
    }

    //==============================================================================
    void toggleAVE()
    {
        if (!safetyAcknowledged)
        {
            juce::AlertWindow::showMessageBox(juce::AlertWindow::WarningIcon,
                "Safety Warning", "Please acknowledge safety warnings first!");
            return;
        }

        if (aveSystem->getSessionState().isActive)
        {
            aveSystem->stopSession();
            aveStartButton.setButtonText("Start AVE");
        }
        else
        {
            // Configure settings
            AudioVisualEntrainment::SessionSettings settings;
            settings.safetyWarningAcknowledged = true;
            settings.intensity = static_cast<float>(aveIntensitySlider.getValue());

            // Set frequency band
            int bandId = aveBandCombo.getSelectedId();
            switch (bandId)
            {
                case 1: settings.band = AudioVisualEntrainment::FrequencyBand::Delta; break;
                case 2: settings.band = AudioVisualEntrainment::FrequencyBand::Theta; break;
                case 3: settings.band = AudioVisualEntrainment::FrequencyBand::Alpha; break;
                case 4: settings.band = AudioVisualEntrainment::FrequencyBand::Beta; break;
                case 5: settings.band = AudioVisualEntrainment::FrequencyBand::Gamma; break;
            }

            if (aveSystem->startSession(settings))
            {
                aveStartButton.setButtonText("Stop AVE");
            }
        }
    }

    void toggleColor()
    {
        if (!safetyAcknowledged)
        {
            juce::AlertWindow::showMessageBox(juce::AlertWindow::WarningIcon,
                "Safety Warning", "Please acknowledge safety warnings first!");
            return;
        }

        if (colorTherapy->getColorState().isActive)
        {
            colorTherapy->stopSession();
            colorStartButton.setButtonText("Start Color");
        }
        else
        {
            ColorLightTherapy::ColorSettings settings;
            settings.safetyWarningAcknowledged = true;
            settings.intensity = static_cast<float>(colorIntensitySlider.getValue());

            // Set color mode
            int modeId = colorModeCombo.getSelectedId();
            switch (modeId)
            {
                case 1: settings.mode = ColorLightTherapy::ColorMode::Warm; break;
                case 2: settings.mode = ColorLightTherapy::ColorMode::Neutral; break;
                case 3: settings.mode = ColorLightTherapy::ColorMode::Cool; break;
                case 4: settings.mode = ColorLightTherapy::ColorMode::Daylight; break;
                case 5: settings.mode = ColorLightTherapy::ColorMode::Sunset; break;
                case 6: settings.mode = ColorLightTherapy::ColorMode::Night; break;
            }

            if (colorTherapy->startSession(settings))
            {
                colorStartButton.setButtonText("Stop Color");
            }
        }
    }

    void toggleVibro()
    {
        if (!safetyAcknowledged)
        {
            juce::AlertWindow::showMessageBox(juce::AlertWindow::WarningIcon,
                "Safety Warning", "Please acknowledge safety warnings first!");
            return;
        }

        if (vibroSystem->getVibrationState().isActive)
        {
            vibroSystem->stopSession();
            vibroStartButton.setButtonText("Start Vibro");
        }
        else
        {
            VibrotherapySystem::VibrationSettings settings;
            settings.safetyWarningAcknowledged = true;
            settings.intensity = static_cast<float>(vibroIntensitySlider.getValue());

            // Set vibration mode
            int modeId = vibroModeCombo.getSelectedId();
            switch (modeId)
            {
                case 1: settings.mode = VibrotherapySystem::VibrationMode::LowFrequency;
                        settings.frequencyHz = 30.0f; break;
                case 2: settings.mode = VibrotherapySystem::VibrationMode::MidFrequency;
                        settings.frequencyHz = 100.0f; break;
                case 3: settings.mode = VibrotherapySystem::VibrationMode::HighFrequency;
                        settings.frequencyHz = 250.0f; break;
                case 4: settings.mode = VibrotherapySystem::VibrationMode::Pulsed;
                        settings.pulsedEnabled = true; break;
                case 5: settings.mode = VibrotherapySystem::VibrationMode::Ramped;
                        settings.rampingEnabled = true; break;
                case 6: settings.mode = VibrotherapySystem::VibrationMode::AudioSynchronized;
                        settings.audioSyncEnabled = true; break;
            }

            if (vibroSystem->startSession(settings))
            {
                vibroStartButton.setButtonText("Stop Vibro");
            }
        }
    }

    void emergencyStopAll()
    {
        aveSystem->stopSession();
        colorTherapy->stopSession();
        vibroSystem->stopSession();

        aveStartButton.setButtonText("Start AVE");
        colorStartButton.setButtonText("Start Color");
        vibroStartButton.setButtonText("Start Vibro");

        juce::AlertWindow::showMessageBox(juce::AlertWindow::InfoIcon,
            "Emergency Stop", "All wellness systems stopped!");
    }

    //==============================================================================
    void updateStatusDisplays()
    {
        // AVE status
        if (aveSystem->getSessionState().isActive)
        {
            float elapsed = aveSystem->getSessionState().elapsedSeconds;
            aveStatusLabel.setText("Status: Active (" + juce::String(elapsed, 1) + "s)",
                                  juce::dontSendNotification);
            aveStatusLabel.setColour(juce::Label::textColourId, juce::Colours::green);
        }
        else
        {
            aveStatusLabel.setText("Status: Stopped", juce::dontSendNotification);
            aveStatusLabel.setColour(juce::Label::textColourId, juce::Colours::grey);
        }

        // Color status
        if (colorTherapy->getColorState().isActive)
        {
            float elapsed = colorTherapy->getColorState().elapsedSeconds;
            colorStatusLabel.setText("Status: Active (" + juce::String(elapsed, 1) + "s)",
                                    juce::dontSendNotification);
            colorStatusLabel.setColour(juce::Label::textColourId, juce::Colours::green);
        }
        else
        {
            colorStatusLabel.setText("Status: Stopped", juce::dontSendNotification);
            colorStatusLabel.setColour(juce::Label::textColourId, juce::Colours::grey);
        }

        // Vibro status
        if (vibroSystem->getVibrationState().isActive)
        {
            float elapsed = vibroSystem->getVibrationState().elapsedSeconds;
            vibroStatusLabel.setText("Status: Active (" + juce::String(elapsed, 1) + "s)",
                                    juce::dontSendNotification);
            vibroStatusLabel.setColour(juce::Label::textColourId, juce::Colours::green);
        }
        else
        {
            vibroStatusLabel.setText("Status: Stopped", juce::dontSendNotification);
            vibroStatusLabel.setColour(juce::Label::textColourId, juce::Colours::grey);
        }
    }

    //==============================================================================
    // Systems
    std::unique_ptr<AudioVisualEntrainment> aveSystem;
    std::unique_ptr<ColorLightTherapy> colorTherapy;
    std::unique_ptr<VibrotherapySystem> vibroSystem;

    // Safety
    bool safetyAcknowledged = false;
    juce::TextButton safetyButton;

    // AVE UI
    juce::Label aveLabel;
    juce::ComboBox aveBandCombo;
    juce::Slider aveIntensitySlider;
    juce::Label aveIntensityLabel;
    juce::TextButton aveStartButton;
    juce::Label aveStatusLabel;

    // Color Therapy UI
    juce::Label colorLabel;
    juce::ComboBox colorModeCombo;
    juce::Slider colorIntensitySlider;
    juce::Label colorIntensityLabel;
    juce::TextButton colorStartButton;
    juce::Label colorStatusLabel;

    // Vibrotherapy UI
    juce::Label vibroLabel;
    juce::ComboBox vibroModeCombo;
    juce::Slider vibroIntensitySlider;
    juce::Label vibroIntensityLabel;
    juce::TextButton vibroStartButton;
    juce::Label vibroStatusLabel;

    // Emergency
    juce::TextButton emergencyStopButton;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(WellnessControlPanel)
};
