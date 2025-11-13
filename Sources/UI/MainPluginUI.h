#pragma once

#include <JuceHeader.h>
#include "ResponsiveLayout.h"
#include "ModernLookAndFeel.h"
#include "PhaseAnalyzerUI.h"
#include "StyleAwareMasteringUI.h"
#include "EchoSynthUI.h"

//==============================================================================
/**
 * @brief Main Plugin UI - Tabbed Interface
 *
 * Features:
 * - Tab navigation between different tools
 * - Responsive layout (Desktop/Tablet/Phone)
 * - Theme switcher
 * - Touch-optimized
 */
class MainPluginUI : public ResponsiveComponent
{
public:
    enum class View
    {
        PhaseAnalyzer,
        StyleAwareMastering,
        EchoSynth,
        Effects,
        Mixer
    };

    MainPluginUI()
    {
        // Set up modern look and feel
        modernLookAndFeel = std::make_unique<ModernLookAndFeel>(ModernLookAndFeel::Theme::Dark);
        setLookAndFeel(modernLookAndFeel.get());

        // Create navigation tabs
        addAndMakeVisible(tabBar);
        tabBar.setTabBarDepth(44);  // Touch-friendly height
        tabBar.addTab("Phase Analyzer", modernLookAndFeel->getColors().backgroundDark, 0);
        tabBar.addTab("Mastering", modernLookAndFeel->getColors().backgroundDark, 1);
        tabBar.addTab("EchoSynth", modernLookAndFeel->getColors().backgroundDark, 2);
        tabBar.addTab("Effects", modernLookAndFeel->getColors().backgroundDark, 3);
        tabBar.addTab("Mixer", modernLookAndFeel->getColors().backgroundDark, 4);

        tabBar.setCurrentTabIndex(0);
        tabBar.addChangeListener(this);

        // Create views
        phaseAnalyzerUI = std::make_unique<PhaseAnalyzerUI>();
        styleAwareMasteringUI = std::make_unique<StyleAwareMasteringUI>();
        echoSynthUI = std::make_unique<EchoSynthUI>();

        // Show initial view
        showView(View::PhaseAnalyzer);

        // Theme toggle button
        addAndMakeVisible(themeButton);
        themeButton.setButtonText("☀");  // Sun icon for light mode
        themeButton.onClick = [this] { toggleTheme(); };

        // Set initial size (will adapt based on device)
        setSize(1200, 800);
    }

    ~MainPluginUI() override
    {
        setLookAndFeel(nullptr);
        tabBar.removeChangeListener(this);
    }

    void showView(View view)
    {
        currentView = view;

        // Hide all views
        if (phaseAnalyzerUI)
            phaseAnalyzerUI->setVisible(false);
        if (styleAwareMasteringUI)
            styleAwareMasteringUI->setVisible(false);
        if (echoSynthUI)
            echoSynthUI->setVisible(false);

        // Show selected view
        switch (view)
        {
            case View::PhaseAnalyzer:
                if (!phaseAnalyzerUI->isOnDesktop() && phaseAnalyzerUI->getParentComponent() == nullptr)
                    addAndMakeVisible(phaseAnalyzerUI.get());
                phaseAnalyzerUI->setVisible(true);
                break;

            case View::StyleAwareMastering:
                if (!styleAwareMasteringUI->isOnDesktop() && styleAwareMasteringUI->getParentComponent() == nullptr)
                    addAndMakeVisible(styleAwareMasteringUI.get());
                styleAwareMasteringUI->setVisible(true);
                break;

            case View::EchoSynth:
                if (!echoSynthUI->isOnDesktop() && echoSynthUI->getParentComponent() == nullptr)
                    addAndMakeVisible(echoSynthUI.get());
                echoSynthUI->setVisible(true);
                break;

            default:
                break;
        }

        resized();
    }

    void changeListenerCallback(juce::ChangeBroadcaster* source) override
    {
        if (source == &tabBar)
        {
            int tabIndex = tabBar.getCurrentTabIndex();
            showView(static_cast<View>(tabIndex));
        }
    }

    void performResponsiveLayout() override
    {
        auto bounds = getLocalBounds();
        auto metrics = getLayoutMetrics();

        // Theme button in top-right corner
        themeButton.setBounds(bounds.getRight() - 50, 5, 40, 34);

        // Tab bar at top
        int tabBarHeight = (metrics.deviceType == ResponsiveLayout::DeviceType::Phone) ? 50 : 44;
        tabBar.setBounds(bounds.removeFromTop(tabBarHeight));

        // Content area for views
        auto contentBounds = bounds.reduced(metrics.margin);

        if (phaseAnalyzerUI && phaseAnalyzerUI->isVisible())
            phaseAnalyzerUI->setBounds(contentBounds);
        if (styleAwareMasteringUI && styleAwareMasteringUI->isVisible())
            styleAwareMasteringUI->setBounds(contentBounds);
        if (echoSynthUI && echoSynthUI->isVisible())
            echoSynthUI->setBounds(contentBounds);
    }

    void paint(juce::Graphics& g) override
    {
        g.fillAll(modernLookAndFeel->getColors().backgroundDark);
    }

    // Audio processing methods
    void prepareToPlay(double sampleRate, int samplesPerBlock)
    {
        if (phaseAnalyzerUI)
            phaseAnalyzerUI->prepare(sampleRate, samplesPerBlock);
        if (styleAwareMasteringUI)
            styleAwareMasteringUI->prepare(sampleRate, samplesPerBlock);
    }

    void processBlock(juce::AudioBuffer<float>& buffer)
    {
        if (currentView == View::PhaseAnalyzer && phaseAnalyzerUI)
            phaseAnalyzerUI->process(buffer);
        else if (currentView == View::StyleAwareMastering && styleAwareMasteringUI)
            styleAwareMasteringUI->process(buffer);
    }

private:
    void toggleTheme()
    {
        if (modernLookAndFeel->getTheme() == ModernLookAndFeel::Theme::Dark)
        {
            modernLookAndFeel->setTheme(ModernLookAndFeel::Theme::Light);
            themeButton.setButtonText("🌙");  // Moon icon for dark mode
        }
        else
        {
            modernLookAndFeel->setTheme(ModernLookAndFeel::Theme::Dark);
            themeButton.setButtonText("☀");  // Sun icon for light mode
        }

        repaint();
    }

    std::unique_ptr<ModernLookAndFeel> modernLookAndFeel;

    juce::TabbedButtonBar tabBar { juce::TabbedButtonBar::TabsAtTop };
    juce::TextButton themeButton;

    std::unique_ptr<PhaseAnalyzerUI> phaseAnalyzerUI;
    std::unique_ptr<StyleAwareMasteringUI> styleAwareMasteringUI;
    std::unique_ptr<EchoSynthUI> echoSynthUI;

    View currentView = View::PhaseAnalyzer;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MainPluginUI)
};
