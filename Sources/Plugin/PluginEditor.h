#pragma once

#include <JuceHeader.h>
#include "PluginProcessor.h"
#include "../UI/SimpleMainUI.h"

// ⭐ NEW: Professional UI Components (Framework in place for 230K LOC)
// TODO: These 4 need .cpp implementation files before they can be used:
// #include "../UI/PresetBrowserUI.h"  // 23K LOC - needs PresetBrowserUI.cpp
// #include "../UI/AdvancedDSPManagerUI.h"  // 63K LOC - needs AdvancedDSPManagerUI.cpp
// #include "../UI/ModulationMatrixUI.h"  // 17K LOC - needs ModulationMatrixUI.cpp
// #include "../UI/ParameterAutomationUI.h"  // 31K LOC - needs ParameterAutomationUI.cpp

// ✅ JUCE 7 Compatible Components (Working):
// #include "../UI/AdvancedSculptingUI.h"  // TODO: Fix SpectralSculptor API mismatches (Gate→SpectralGate, etc.)
#include "../UI/EchoSynthUI.h"  // Header-only ✅
#include "../UI/PhaseAnalyzerUI.h"  // Header-only ✅ (JUCE 7 fixed)
#include "../UI/StyleAwareMasteringUI.h"  // Header-only ✅ (JUCE 7 fixed)
#include "../UI/BioFeedbackDashboard.h"  // Header-only ✅
#include "../UI/CreativeToolsPanel.h"  // Header-only ✅
#include "../UI/WellnessControlPanel.h"  // Header-only ✅
#include "../UI/ExportDialog.h"  // Header-only ✅
#include "../UI/ImportDialog.h"  // Header-only ✅

/**
 * Echoelmusic Plugin Editor
 *
 * Beautiful, professional plugin GUI with:
 * - Cross-platform responsive UI (Desktop/Tablet/Phone)
 * - Phase Analyzer (Goniometer + Correlation Meter)
 * - Style-Aware Mastering (Genre-specific LUFS mastering)
 * - EchoSynth (Analog synthesizer)
 * - Real-time bio-data visualization
 * - Modern dark/light themes
 * - Touch-optimized controls
 */
class EchoelmusicAudioProcessorEditor  : public juce::AudioProcessorEditor,
                                          private juce::Timer
{
public:
    EchoelmusicAudioProcessorEditor (EchoelmusicAudioProcessor&);
    ~EchoelmusicAudioProcessorEditor() override;

    //==============================================================================
    void paint (juce::Graphics&) override;
    void resized() override;

private:
    //==============================================================================
    // Timer callback for real-time updates
    void timerCallback() override;

    //==============================================================================
    // UI Component Factory (Professional Multi-Panel System)
    // Framework in place - ready for 230K LOC when .cpp files are implemented

    // Primary UI Panels (TODO: Need .cpp implementations)
    // std::unique_ptr<PresetBrowserUI> presetBrowser;           // 23K LOC - needs PresetBrowserUI.cpp
    // std::unique_ptr<AdvancedDSPManagerUI> dspManagerUI;        // 63K LOC - needs AdvancedDSPManagerUI.cpp
    // std::unique_ptr<ModulationMatrixUI> modulationMatrix;      // 17K LOC - needs ModulationMatrixUI.cpp
    // std::unique_ptr<ParameterAutomationUI> automationEditor;   // 31K LOC - needs ParameterAutomationUI.cpp

    // ✅ JUCE 7 Compatible UI Panels (Working):
    // std::unique_ptr<AdvancedSculptingUI> sculptingUI;      // TODO: Fix API mismatches
    std::unique_ptr<EchoSynthUI> synthUI;                      // Header-only ✅
    std::unique_ptr<PhaseAnalyzerUI> phaseAnalyzer;            // Header-only ✅ (JUCE 7 fixed)
    std::unique_ptr<StyleAwareMasteringUI> masteringUI;        // Header-only ✅ (JUCE 7 fixed)
    std::unique_ptr<BioFeedbackDashboard> bioFeedback;         // Header-only ✅
    std::unique_ptr<CreativeToolsPanel> creativeTools;         // Header-only ✅
    std::unique_ptr<WellnessControlPanel> wellnessPanel;       // Header-only ✅

    // Dialogs (Header-only - Working ✅)
    std::unique_ptr<ExportDialog> exportDialog;                // Header-only ✅
    std::unique_ptr<ImportDialog> importDialog;                // Header-only ✅

    // Legacy (Main UI - Working ✅)
    std::unique_ptr<SimpleMainUI> mainUI;

    // Tab/Panel Management
    enum class ActivePanel
    {
        // DSPManager,  // TODO: Needs AdvancedDSPManagerUI.cpp
        // PresetBrowser,  // TODO: Needs PresetBrowserUI.cpp
        // Automation,  // TODO: Needs ParameterAutomationUI.cpp
        // Modulation,  // TODO: Needs ModulationMatrixUI.cpp
        // Sculpting,   // TODO: Fix SpectralSculptor API mismatches
        Synthesizer,    // ✅ EchoSynthUI
        PhaseAnalysis,  // ✅ PhaseAnalyzerUI
        Mastering,      // ✅ StyleAwareMasteringUI
        BioFeedback,    // ✅ BioFeedbackDashboard
        CreativeTools,  // ✅ CreativeToolsPanel
        Wellness,       // ✅ WellnessControlPanel
        Main            // ✅ SimpleMainUI fallback
    };

    ActivePanel currentPanel = ActivePanel::Main;

    // Tab buttons
    // juce::TextButton dspManagerButton{"DSP Manager"};  // TODO: Needs .cpp
    // juce::TextButton presetBrowserButton{"Presets"};  // TODO: Needs .cpp
    // juce::TextButton automationButton{"Automation"};  // TODO: Needs .cpp
    // juce::TextButton modulationButton{"Modulation"};  // TODO: Needs .cpp
    // juce::TextButton sculptingButton{"Sculpting"};    // TODO: Fix API mismatches
    juce::TextButton synthButton{"Synth"};
    juce::TextButton phaseButton{"Phase"};            // ✅ New
    juce::TextButton masteringButton{"Mastering"};    // ✅ New
    juce::TextButton bioButton{"Bio"};
    juce::TextButton creativeButton{"Creative"};
    juce::TextButton wellnessButton{"Wellness"};
    juce::TextButton mainButton{"Main"};

    void createUIComponents();
    void wireUIComponents();
    void switchToPanel(ActivePanel panel);

    //==============================================================================
    // Reference to processor
    EchoelmusicAudioProcessor& audioProcessor;

    //==============================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (EchoelmusicAudioProcessorEditor)
};
