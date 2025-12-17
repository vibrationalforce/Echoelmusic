#include "ModulationMatrixUI.h"

//==============================================================================
// Constructor / Destructor
//==============================================================================

ModulationMatrixUI::ModulationMatrixUI()
{
    // Initialize modulation slots with colors
    for (int i = 0; i < 16; ++i)
    {
        modulationSlots[i].color = juce::Colour::fromHSV(i / 16.0f, 0.7f, 0.9f, 1.0f);
    }

    // Create UI components for editing selected slot
    sourceSelector = std::make_unique<juce::ComboBox>("Source");
    sourceSelector->addItem("None", static_cast<int>(ModulationSlot::Source::None));
    sourceSelector->addItem("LFO 1", static_cast<int>(ModulationSlot::Source::LFO1));
    sourceSelector->addItem("LFO 2", static_cast<int>(ModulationSlot::Source::LFO2));
    sourceSelector->addItem("LFO 3", static_cast<int>(ModulationSlot::Source::LFO3));
    sourceSelector->addItem("LFO 4", static_cast<int>(ModulationSlot::Source::LFO4));
    sourceSelector->addItem("Envelope 1", static_cast<int>(ModulationSlot::Source::Envelope1));
    sourceSelector->addItem("Envelope 2", static_cast<int>(ModulationSlot::Source::Envelope2));
    sourceSelector->addItem("Envelope 3", static_cast<int>(ModulationSlot::Source::Envelope3));
    sourceSelector->addItem("Envelope 4", static_cast<int>(ModulationSlot::Source::Envelope4));
    sourceSelector->addItem("Velocity", static_cast<int>(ModulationSlot::Source::Velocity));
    sourceSelector->addItem("Aftertouch", static_cast<int>(ModulationSlot::Source::Aftertouch));
    sourceSelector->addItem("Mod Wheel", static_cast<int>(ModulationSlot::Source::ModWheel));
    sourceSelector->addItem("HRV (Bio)", static_cast<int>(ModulationSlot::Source::HRV));
    sourceSelector->addItem("Coherence (Bio)", static_cast<int>(ModulationSlot::Source::Coherence));
    sourceSelector->addItem("Stress (Bio)", static_cast<int>(ModulationSlot::Source::Stress));
    sourceSelector->addItem("Random", static_cast<int>(ModulationSlot::Source::Random));
    sourceSelector->onChange = [this]()
    {
        if (selectedSlot >= 0 && selectedSlot < 16)
        {
            modulationSlots[selectedSlot].source = static_cast<ModulationSlot::Source>(sourceSelector->getSelectedId());
            repaint();
        }
    };
    addAndMakeVisible(*sourceSelector);

    destinationSelector = std::make_unique<juce::ComboBox>("Destination");
    destinationSelector->addItem("None", static_cast<int>(ModulationSlot::Destination::None));
    destinationSelector->addItem("Filter Cutoff", static_cast<int>(ModulationSlot::Destination::FilterCutoff));
    destinationSelector->addItem("Filter Resonance", static_cast<int>(ModulationSlot::Destination::FilterResonance));
    destinationSelector->addItem("Pitch", static_cast<int>(ModulationSlot::Destination::Pitch));
    destinationSelector->addItem("Amplitude", static_cast<int>(ModulationSlot::Destination::Amplitude));
    destinationSelector->addItem("Pan", static_cast<int>(ModulationSlot::Destination::Pan));
    destinationSelector->addItem("Reverb Mix", static_cast<int>(ModulationSlot::Destination::ReverbMix));
    destinationSelector->addItem("Delay Time", static_cast<int>(ModulationSlot::Destination::DelayTime));
    destinationSelector->addItem("Distortion", static_cast<int>(ModulationSlot::Destination::DistortionAmount));
    destinationSelector->addItem("Mid/Side Balance", static_cast<int>(ModulationSlot::Destination::MidSideBalance));
    destinationSelector->addItem("Humanizer Amount", static_cast<int>(ModulationSlot::Destination::HumanizerAmount));
    destinationSelector->addItem("Swarm Density", static_cast<int>(ModulationSlot::Destination::SwarmDensity));
    destinationSelector->addItem("Pitch Correction", static_cast<int>(ModulationSlot::Destination::PitchCorrectionStrength));
    destinationSelector->onChange = [this]()
    {
        if (selectedSlot >= 0 && selectedSlot < 16)
        {
            modulationSlots[selectedSlot].destination = static_cast<ModulationSlot::Destination>(destinationSelector->getSelectedId());
            repaint();
        }
    };
    addAndMakeVisible(*destinationSelector);

    depthSlider = std::make_unique<juce::Slider>(juce::Slider::RotaryHorizontalVerticalDrag, juce::Slider::TextBoxBelow);
    depthSlider->setRange(-1.0, 1.0, 0.01);
    depthSlider->setValue(0.0);
    depthSlider->onValueChange = [this]()
    {
        if (selectedSlot >= 0 && selectedSlot < 16)
        {
            modulationSlots[selectedSlot].depth = static_cast<float>(depthSlider->getValue());
            repaint();
        }
    };
    addAndMakeVisible(*depthSlider);

    depthLabel = std::make_unique<juce::Label>("Depth Label", "Depth");
    depthLabel->setJustificationType(juce::Justification::centred);
    addAndMakeVisible(*depthLabel);

    enabledToggle = std::make_unique<juce::ToggleButton>("Enabled");
    enabledToggle->setToggleState(true, juce::dontSendNotification);
    enabledToggle->onClick = [this]()
    {
        if (selectedSlot >= 0 && selectedSlot < 16)
        {
            modulationSlots[selectedSlot].enabled = enabledToggle->getToggleState();
            repaint();
        }
    };
    addAndMakeVisible(*enabledToggle);
}

ModulationMatrixUI::~ModulationMatrixUI()
{
}

//==============================================================================
// DSP Manager Connection
//==============================================================================

void ModulationMatrixUI::setDSPManager(AdvancedDSPManager* manager)
{
    dspManager = manager;
}

//==============================================================================
// Component Methods
//==============================================================================

void ModulationMatrixUI::paint(juce::Graphics& g)
{
    // Background
    g.fillAll(juce::Colour(0xff1a1a2e));

    // Title
    g.setColour(juce::Colours::white);
    g.setFont(juce::Font(20.0f, juce::Font::bold));
    g.drawText("Modulation Matrix", 10, 10, getWidth() - 20, 30, juce::Justification::centred);

    // Draw grid
    if (gridArea.isEmpty())
        return;

    const int cellWidth = gridArea.getWidth() / gridCols;
    const int cellHeight = gridArea.getHeight() / gridRows;

    // Draw grid cells
    for (int i = 0; i < 16; ++i)
    {
        const auto& slot = modulationSlots[i];
        int row = i / gridCols;
        int col = i % gridCols;

        juce::Rectangle<int> cellBounds(
            gridArea.getX() + col * cellWidth,
            gridArea.getY() + row * cellHeight,
            cellWidth,
            cellHeight
        );

        // Cell background
        if (i == selectedSlot)
        {
            g.setColour(juce::Colour(0xff2a2a4e).brighter(0.3f));
            g.fillRect(cellBounds.reduced(2));
        }
        else
        {
            g.setColour(juce::Colour(0xff16213e));
            g.fillRect(cellBounds.reduced(2));
        }

        // Connection indicator
        if (slot.source != ModulationSlot::Source::None &&
            slot.destination != ModulationSlot::Destination::None)
        {
            // Draw color-coded connection with depth indicator
            float alpha = slot.enabled ? 1.0f : 0.3f;
            g.setColour(slot.color.withAlpha(alpha));

            float depthHeight = std::abs(slot.depth) * (cellBounds.getHeight() - 20);
            int yPos = slot.depth >= 0 ?
                       cellBounds.getCentreY() - static_cast<int>(depthHeight / 2) :
                       cellBounds.getCentreY() - static_cast<int>(depthHeight / 2);

            g.fillRect(cellBounds.getCentreX() - 20, yPos, 40, static_cast<int>(depthHeight));

            // Draw source/destination labels
            g.setColour(juce::Colours::white.withAlpha(alpha));
            g.setFont(juce::Font(10.0f));
            g.drawText(getSourceName(slot.source).substring(0, 3),
                       cellBounds.reduced(4, 4),
                       juce::Justification::topLeft, false);
            g.drawText(getDestinationName(slot.destination).substring(0, 3),
                       cellBounds.reduced(4, 4),
                       juce::Justification::bottomRight, false);

            // Draw depth value
            g.drawText(juce::String(static_cast<int>(slot.depth * 100)) + "%",
                       cellBounds,
                       juce::Justification::centred, false);
        }
        else
        {
            // Empty slot indicator
            g.setColour(juce::Colours::white.withAlpha(0.2f));
            g.drawText("+", cellBounds, juce::Justification::centred, false);
        }

        // Cell border
        g.setColour(juce::Colour(0xff0f3460).brighter(i == selectedSlot ? 0.5f : 0.0f));
        g.drawRect(cellBounds.reduced(2), 2);
    }

    // Draw slot number labels
    g.setFont(juce::Font(10.0f));
    for (int i = 0; i < 16; ++i)
    {
        int row = i / gridCols;
        int col = i % gridCols;
        juce::Rectangle<int> cellBounds(
            gridArea.getX() + col * cellWidth,
            gridArea.getY() + row * cellHeight,
            cellWidth,
            cellHeight
        );
        g.setColour(juce::Colours::white.withAlpha(0.3f));
        g.drawText(juce::String(i + 1), cellBounds.reduced(4), juce::Justification::topRight, false);
    }
}

void ModulationMatrixUI::resized()
{
    auto bounds = getLocalBounds().reduced(10);

    // Title area
    bounds.removeFromTop(40);

    // Controls area (right side)
    auto controlsArea = bounds.removeFromRight(250);
    controlsArea.removeFromTop(10);

    sourceSelector->setBounds(controlsArea.removeFromTop(30).reduced(5));
    controlsArea.removeFromTop(5);

    destinationSelector->setBounds(controlsArea.removeFromTop(30).reduced(5));
    controlsArea.removeFromTop(10);

    depthLabel->setBounds(controlsArea.removeFromTop(20).reduced(5));
    depthSlider->setBounds(controlsArea.removeFromTop(100).reduced(5));
    controlsArea.removeFromTop(10);

    enabledToggle->setBounds(controlsArea.removeFromTop(30).reduced(5));

    // Grid area (left side)
    gridArea = bounds.reduced(10);
}

void ModulationMatrixUI::mouseDown(const juce::MouseEvent& event)
{
    int slot = getSlotAtPosition(event.x, event.y);
    if (slot >= 0 && slot < 16)
    {
        selectedSlot = slot;

        // Update UI controls to reflect selected slot
        sourceSelector->setSelectedId(static_cast<int>(modulationSlots[slot].source), juce::dontSendNotification);
        destinationSelector->setSelectedId(static_cast<int>(modulationSlots[slot].destination), juce::dontSendNotification);
        depthSlider->setValue(modulationSlots[slot].depth, juce::dontSendNotification);
        enabledToggle->setToggleState(modulationSlots[slot].enabled, juce::dontSendNotification);

        repaint();
    }
}

void ModulationMatrixUI::mouseDrag(const juce::MouseEvent& event)
{
    // Future: Could implement drag-to-adjust-depth
}

void ModulationMatrixUI::mouseUp(const juce::MouseEvent& event)
{
    // Apply modulation changes
    applyModulation();
}

//==============================================================================
// Helper Methods
//==============================================================================

juce::String ModulationMatrixUI::getSourceName(ModulationSlot::Source source) const
{
    switch (source)
    {
        case ModulationSlot::Source::None: return "None";
        case ModulationSlot::Source::LFO1: return "LFO1";
        case ModulationSlot::Source::LFO2: return "LFO2";
        case ModulationSlot::Source::LFO3: return "LFO3";
        case ModulationSlot::Source::LFO4: return "LFO4";
        case ModulationSlot::Source::Envelope1: return "Env1";
        case ModulationSlot::Source::Envelope2: return "Env2";
        case ModulationSlot::Source::Envelope3: return "Env3";
        case ModulationSlot::Source::Envelope4: return "Env4";
        case ModulationSlot::Source::Velocity: return "Vel";
        case ModulationSlot::Source::Aftertouch: return "AT";
        case ModulationSlot::Source::ModWheel: return "MW";
        case ModulationSlot::Source::HRV: return "HRV";
        case ModulationSlot::Source::Coherence: return "Coh";
        case ModulationSlot::Source::Stress: return "Str";
        case ModulationSlot::Source::Random: return "Rnd";
        default: return "???";
    }
}

juce::String ModulationMatrixUI::getDestinationName(ModulationSlot::Destination destination) const
{
    switch (destination)
    {
        case ModulationSlot::Destination::None: return "None";
        case ModulationSlot::Destination::FilterCutoff: return "Cutoff";
        case ModulationSlot::Destination::FilterResonance: return "Resonance";
        case ModulationSlot::Destination::Pitch: return "Pitch";
        case ModulationSlot::Destination::Amplitude: return "Amp";
        case ModulationSlot::Destination::Pan: return "Pan";
        case ModulationSlot::Destination::ReverbMix: return "Reverb";
        case ModulationSlot::Destination::DelayTime: return "Delay";
        case ModulationSlot::Destination::DistortionAmount: return "Dist";
        case ModulationSlot::Destination::MidSideBalance: return "M/S";
        case ModulationSlot::Destination::HumanizerAmount: return "Human";
        case ModulationSlot::Destination::SwarmDensity: return "Swarm";
        case ModulationSlot::Destination::PitchCorrectionStrength: return "PitchC";
        default: return "???";
    }
}

juce::Colour ModulationMatrixUI::getColorForSource(ModulationSlot::Source source) const
{
    // Color-code by source type
    if (source >= ModulationSlot::Source::LFO1 && source <= ModulationSlot::Source::LFO4)
        return juce::Colour(0xff4a90e2); // Blue for LFOs
    else if (source >= ModulationSlot::Source::Envelope1 && source <= ModulationSlot::Source::Envelope4)
        return juce::Colour(0xffe24a90); // Pink for envelopes
    else if (source == ModulationSlot::Source::HRV || source == ModulationSlot::Source::Coherence || source == ModulationSlot::Source::Stress)
        return juce::Colour(0xff4ae290); // Green for bio-reactive
    else
        return juce::Colour(0xffe2904a); // Orange for others
}

void ModulationMatrixUI::updateModulationValues()
{
    if (!dspManager)
        return;

    // Update visual values from bio-data and other sources
    for (auto& slot : modulationSlots)
    {
        if (!slot.enabled || slot.source == ModulationSlot::Source::None)
            continue;

        // Get source value
        float sourceValue = 0.0f;
        switch (slot.source)
        {
            case ModulationSlot::Source::HRV:
                sourceValue = dspManager->getCurrentHRV();
                break;
            case ModulationSlot::Source::Coherence:
                sourceValue = dspManager->getCurrentCoherence();
                break;
            case ModulationSlot::Source::Stress:
                sourceValue = dspManager->getCurrentStress();
                break;
            case ModulationSlot::Source::Random:
                sourceValue = juce::Random::getSystemRandom().nextFloat();
                break;
            default:
                // LFOs, envelopes, etc. would be implemented here
                sourceValue = 0.5f;
                break;
        }

        slot.visualValue = sourceValue * slot.depth;
    }
}

void ModulationMatrixUI::applyModulation()
{
    // In production, this would actually modulate DSP parameters
    // For now, just update visual state
    updateModulationValues();
    repaint();
}

int ModulationMatrixUI::getSlotAtPosition(int x, int y) const
{
    if (!gridArea.contains(x, y))
        return -1;

    int cellWidth = gridArea.getWidth() / gridCols;
    int cellHeight = gridArea.getHeight() / gridRows;

    int col = (x - gridArea.getX()) / cellWidth;
    int row = (y - gridArea.getY()) / cellHeight;

    if (col >= 0 && col < gridCols && row >= 0 && row < gridRows)
        return row * gridCols + col;

    return -1;
}

juce::Rectangle<int> ModulationMatrixUI::getBoundsForSlot(int slotIndex) const
{
    if (slotIndex < 0 || slotIndex >= 16)
        return {};

    int cellWidth = gridArea.getWidth() / gridCols;
    int cellHeight = gridArea.getHeight() / gridRows;

    int row = slotIndex / gridCols;
    int col = slotIndex % gridCols;

    return juce::Rectangle<int>(
        gridArea.getX() + col * cellWidth,
        gridArea.getY() + row * cellHeight,
        cellWidth,
        cellHeight
    );
}

//==============================================================================
// GridCell Implementation
//==============================================================================

ModulationMatrixUI::GridCell::GridCell(ModulationMatrixUI& o, int index)
    : owner(o), slotIndex(index)
{
}

void ModulationMatrixUI::GridCell::paint(juce::Graphics& g)
{
    // Handled by parent ModulationMatrixUI
}

void ModulationMatrixUI::GridCell::mouseDown(const juce::MouseEvent& event)
{
    owner.selectedSlot = slotIndex;
    owner.repaint();
}

void ModulationMatrixUI::GridCell::mouseDrag(const juce::MouseEvent& event)
{
    // Future: drag-to-adjust depth
}
