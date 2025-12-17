#pragma once

#include <JuceHeader.h>
#include "ResponsiveLayout.h"
#include "UIComponents.h"
#include "../DSP/AdvancedDSPManager.h"

//==============================================================================
/**
 * @brief Modulation Matrix UI
 *
 * Visual routing grid for modulating any parameter with any source.
 * Inspired by professional synthesizers like Serum, Phaseplant, and Vital.
 *
 * **Features:**
 * - Visual routing grid (sources × destinations)
 * - Up to 16 modulation slots
 * - Depth/amount control per connection
 * - Bipolar modulation (-100% to +100%)
 * - Color-coded by modulation type
 * - Real-time visual feedback
 * - Bio-reactive sources (HRV, Coherence, Stress)
 *
 * **Modulation Sources:**
 * - LFO 1-4
 * - Envelope 1-4
 * - Velocity
 * - Aftertouch
 * - Mod Wheel
 * - HRV (Bio-reactive)
 * - Coherence (Bio-reactive)
 * - Stress Level (Bio-reactive)
 * - Random
 *
 * **Modulation Destinations:**
 * - Filter Cutoff
 * - Filter Resonance
 * - Pitch
 * - Amplitude
 * - Pan
 * - Reverb Mix
 * - Delay Time
 * - Distortion Amount
 * - Any DSP processor parameter
 */
class ModulationMatrixUI : public ResponsiveComponent
{
public:
    //==========================================================================
    // Constructor / Destructor

    ModulationMatrixUI();
    ~ModulationMatrixUI() override;

    //==========================================================================
    // DSP Manager Connection

    void setDSPManager(AdvancedDSPManager* manager);
    AdvancedDSPManager* getDSPManager() const { return dspManager; }

    //==========================================================================
    // Component Methods

    void paint(juce::Graphics& g) override;
    void resized() override;
    void mouseDown(const juce::MouseEvent& event) override;
    void mouseDrag(const juce::MouseEvent& event) override;
    void mouseUp(const juce::MouseEvent& event) override;

private:
    //==========================================================================
    // Modulation Slot

    struct ModulationSlot
    {
        enum class Source
        {
            None = 0,
            LFO1, LFO2, LFO3, LFO4,
            Envelope1, Envelope2, Envelope3, Envelope4,
            Velocity,
            Aftertouch,
            ModWheel,
            HRV,             // Bio-reactive
            Coherence,       // Bio-reactive
            Stress,          // Bio-reactive
            Random
        };

        enum class Destination
        {
            None = 0,
            FilterCutoff,
            FilterResonance,
            Pitch,
            Amplitude,
            Pan,
            ReverbMix,
            DelayTime,
            DistortionAmount,
            // Advanced DSP destinations
            MidSideBalance,
            HumanizerAmount,
            SwarmDensity,
            PitchCorrectionStrength
        };

        Source source = Source::None;
        Destination destination = Destination::None;
        float depth = 0.0f;              // -1.0 to +1.0 (bipolar)
        bool enabled = true;

        // Visual state
        juce::Colour color;
        float visualValue = 0.0f;         // Current modulation value for display
    };

    //==========================================================================
    // Grid Cell Component

    struct GridCell : public juce::Component
    {
        GridCell(ModulationMatrixUI& owner, int slotIndex);

        void paint(juce::Graphics& g) override;
        void mouseDown(const juce::MouseEvent& event) override;
        void mouseDrag(const juce::MouseEvent& event) override;

        ModulationMatrixUI& owner;
        int slotIndex;
        bool isHovered = false;
    };

    //==========================================================================
    // Helper Methods

    juce::String getSourceName(ModulationSlot::Source source) const;
    juce::String getDestinationName(ModulationSlot::Destination destination) const;
    juce::Colour getColorForSource(ModulationSlot::Source source) const;

    void updateModulationValues();
    void applyModulation();

    int getSlotAtPosition(int x, int y) const;
    juce::Rectangle<int> getBoundsForSlot(int slotIndex) const;

    //==========================================================================
    // Member Variables

    AdvancedDSPManager* dspManager = nullptr;

    // Modulation slots (up to 16 connections)
    std::array<ModulationSlot, 16> modulationSlots;

    // Currently selected slot for editing
    int selectedSlot = -1;

    // Grid dimensions
    static constexpr int gridRows = 4;
    static constexpr int gridCols = 4;

    // UI Components for selected slot
    std::unique_ptr<juce::ComboBox> sourceSelector;
    std::unique_ptr<juce::ComboBox> destinationSelector;
    std::unique_ptr<juce::Slider> depthSlider;
    std::unique_ptr<juce::Label> depthLabel;
    std::unique_ptr<juce::ToggleButton> enabledToggle;

    // Grid visualization area
    juce::Rectangle<int> gridArea;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(ModulationMatrixUI)
};
