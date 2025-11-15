#pragma once

#include <JuceHeader.h>
#include "BioFeedbackDashboard.h"
#include "WellnessControlPanel.h"
#include "CreativeToolsPanel.h"

//==============================================================================
/**
 * @brief Echoelmusic Main UI - Mobile-Friendly Tab Layout
 *
 * Unified interface for:
 * 1. Bio-Feedback Dashboard (ZENTRAL für die Niche!)
 * 2. Wellness Control Panel (AVE + Color + Vibro)
 * 3. Creative Tools Panel (Delay + Harmonic + Dynamic)
 * 4. Audio Mixer (future)
 *
 * Design-Philosophie: Kreativ + Gesund + Mobil + Biofeedback
 *
 * **EINZIGARTIG FÜR DIE NICHE**:
 * - Bio-Feedback PROMINENT (nicht versteckt!)
 * - Wellness Features ZUGÄNGLICH (AVE, Color, Vibro)
 * - Creative Tools PRAKTISCH (BPM-Sync, Golden Ratio, LUFS)
 * - Mobile-Freundlich (Touch-optimiert, Tab-basiert)
 */
class EchoelMusicMainUI : public juce::Component
{
public:
    //==============================================================================
    EchoelMusicMainUI()
    {
        // Create panels
        bioFeedbackDashboard = std::make_unique<BioFeedbackDashboard>();
        wellnessPanel = std::make_unique<WellnessControlPanel>();
        creativeToolsPanel = std::make_unique<CreativeToolsPanel>();

        // Setup tabbed component
        addAndMakeVisible(tabbedComponent);
        tabbedComponent.setTabBarDepth(50);  // Larger tabs for touch

        // Add tabs (order matters - Bio-Feedback FIRST!)
        tabbedComponent.addTab("🫀 Bio-Feedback",
                              juce::Colours::darkred,
                              bioFeedbackDashboard.get(),
                              false);  // Don't delete on removal

        tabbedComponent.addTab("🧘‍♀️ Wellness",
                              juce::Colours::darkgreen,
                              wellnessPanel.get(),
                              false);

        tabbedComponent.addTab("🎚️ Creative Tools",
                              juce::Colours::darkblue,
                              creativeToolsPanel.get(),
                              false);

        // Header
        addAndMakeVisible(headerLabel);
        headerLabel.setText("Echoelmusic DAW", juce::dontSendNotification);
        headerLabel.setFont(juce::Font(28.0f, juce::Font::bold));
        headerLabel.setJustificationType(juce::Justification::centred);
        headerLabel.setColour(juce::Label::textColourId, juce::Colours::white);

        addAndMakeVisible(subtitleLabel);
        subtitleLabel.setText("Kreativ • Gesund • Mobil • Biofeedback", juce::dontSendNotification);
        subtitleLabel.setFont(juce::Font(14.0f));
        subtitleLabel.setJustificationType(juce::Justification::centred);
        subtitleLabel.setColour(juce::Label::textColourId, juce::Colours::grey);

        // Status bar
        addAndMakeVisible(statusBar);
        updateStatusBar();
    }

    ~EchoelMusicMainUI() override
    {
        // Remove tabs before deleting content
        tabbedComponent.clearTabs();
    }

    //==============================================================================
    void paint(juce::Graphics& g) override
    {
        // Gradient background
        g.fillAll(juce::Colour(0xff0a0a0a));

        auto headerArea = getLocalBounds().removeFromTop(80);
        juce::ColourGradient gradient(
            juce::Colour(0xff1a1a2a), headerArea.getX(), headerArea.getY(),
            juce::Colour(0xff0a0a0a), headerArea.getX(), headerArea.getBottom(),
            false
        );
        g.setGradientFill(gradient);
        g.fillRect(headerArea);
    }

    void resized() override
    {
        auto bounds = getLocalBounds();

        // Header
        auto headerArea = bounds.removeFromTop(80);
        headerLabel.setBounds(headerArea.removeFromTop(40));
        subtitleLabel.setBounds(headerArea);

        // Status bar at bottom
        auto statusArea = bounds.removeFromBottom(30);
        statusBar.setBounds(statusArea);

        // Tabbed component
        tabbedComponent.setBounds(bounds);
    }

    //==============================================================================
    // Access to panels (for audio processing integration)
    BioFeedbackDashboard* getBioFeedbackDashboard()
    {
        return bioFeedbackDashboard.get();
    }

    WellnessControlPanel* getWellnessPanel()
    {
        return wellnessPanel.get();
    }

    CreativeToolsPanel* getCreativeToolsPanel()
    {
        return creativeToolsPanel.get();
    }

    //==============================================================================
    void updateStatusBar()
    {
        juce::String status = "Ready";

        // Check if wellness systems are active
        if (wellnessPanel)
        {
            auto aveState = wellnessPanel->getAVEState();
            auto colorState = wellnessPanel->getColorState();

            if (aveState.isActive)
                status += " | AVE Active";
            if (colorState.isActive)
                status += " | Color Active";
        }

        // Check bio-feedback
        if (bioFeedbackDashboard)
        {
            auto metrics = bioFeedbackDashboard->getCurrentMetrics();
            status += " | HR: " + juce::String(metrics.heartRate, 0) + " BPM";
            status += " | HRV: " + juce::String(metrics.hrv * 100.0f, 0) + "%";
        }

        statusBar.setText(status, juce::dontSendNotification);
    }

private:
    //==============================================================================
    // UI Components
    juce::TabbedComponent tabbedComponent {juce::TabbedButtonBar::TabsAtTop};
    juce::Label headerLabel;
    juce::Label subtitleLabel;
    juce::Label statusBar;

    // Panels (owned by this component, but managed by TabbedComponent)
    std::unique_ptr<BioFeedbackDashboard> bioFeedbackDashboard;
    std::unique_ptr<WellnessControlPanel> wellnessPanel;
    std::unique_ptr<CreativeToolsPanel> creativeToolsPanel;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(EchoelMusicMainUI)
};


//==============================================================================
/**
 * @brief Responsive Layout Helper
 *
 * Detects screen size and adjusts layout for mobile/desktop.
 */
class ResponsiveLayoutManager
{
public:
    enum class ScreenSize
    {
        Mobile,      // < 800px width
        Tablet,      // 800-1200px
        Desktop      // > 1200px
    };

    static ScreenSize detectScreenSize(int width)
    {
        if (width < 800)
            return ScreenSize::Mobile;
        else if (width < 1200)
            return ScreenSize::Tablet;
        else
            return ScreenSize::Desktop;
    }

    static bool isTouchDevice()
    {
        // Check if running on touch device
        #if JUCE_IOS || JUCE_ANDROID
            return true;
        #else
            return false;
        #endif
    }

    static int getOptimalTabHeight(ScreenSize size)
    {
        switch (size)
        {
            case ScreenSize::Mobile: return 60;   // Larger for touch
            case ScreenSize::Tablet: return 50;
            case ScreenSize::Desktop: return 40;
            default: return 50;
        }
    }

    static int getOptimalFontSize(ScreenSize size)
    {
        switch (size)
        {
            case ScreenSize::Mobile: return 16;   // Larger for readability
            case ScreenSize::Tablet: return 14;
            case ScreenSize::Desktop: return 12;
            default: return 14;
        }
    }
};
