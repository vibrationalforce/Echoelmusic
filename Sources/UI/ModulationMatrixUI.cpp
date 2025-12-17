#include "ModulationMatrixUI.h"

// ModulationMatrixUI - Main Implementation
ModulationMatrixUI::ModulationMatrixUI()
{
    // Initialize modulation slots
    for (auto& slot : modulationSlots)
    {
        slot.source = ModulationSlot::Source::None;
        slot.destination = ModulationSlot::Destination::None;
        slot.depth = 0.0f;
        slot.enabled = false;
        slot.color = juce::Colours::grey;
        slot.visualValue = 0.0f;
    }
    
    // Source selector
    sourceSelector = std::make_unique<juce::ComboBox>();
    addAndMakeVisible(*sourceSelector);
    sourceSelector->addItem("None", 1);
    sourceSelector->addItem("LFO 1", 2);
    sourceSelector->addItem("LFO 2", 3);
    sourceSelector->addItem("LFO 3", 4);
    sourceSelector->addItem("LFO 4", 5);
    sourceSelector->addItem("Envelope 1", 6);
    sourceSelector->addItem("Envelope 2", 7);
    sourceSelector->addItem("Envelope 3", 8);
    sourceSelector->addItem("Envelope 4", 9);
    sourceSelector->addItem("Velocity", 10);
    sourceSelector->addItem("Aftertouch", 11);
    sourceSelector->addItem("Mod Wheel", 12);
    sourceSelector->addItem("HRV (Bio)", 13);
    sourceSelector->addItem("Coherence (Bio)", 14);
    sourceSelector->addItem("Stress (Bio)", 15);
    sourceSelector->addItem("Random", 16);
    sourceSelector->setSelectedId(1);
    
    sourceSelector->onChange = [this]()
    {
        if (selectedSlot >= 0 && selectedSlot < 16)
        {
            int id = sourceSelector->getSelectedId();
            modulationSlots[selectedSlot].source = static_cast<ModulationSlot::Source>(id - 1);
            modulationSlots[selectedSlot].color = getColorForSource(modulationSlots[selectedSlot].source);
            repaint();
        }
    };
    
    // Destination selector
    destinationSelector = std::make_unique<juce::ComboBox>();
    addAndMakeVisible(*destinationSelector);
    destinationSelector->addItem("None", 1);
    destinationSelector->addItem("Filter Cutoff", 2);
    destinationSelector->addItem("Filter Resonance", 3);
    destinationSelector->addItem("Pitch", 4);
    destinationSelector->addItem("Amplitude", 5);
    destinationSelector->addItem("Pan", 6);
    destinationSelector->addItem("Reverb Mix", 7);
    destinationSelector->addItem("Delay Time", 8);
    destinationSelector->addItem("Distortion", 9);
    destinationSelector->addItem("Mid/Side Balance", 10);
    destinationSelector->addItem("Humanizer Amount", 11);
    destinationSelector->addItem("Swarm Density", 12);
    destinationSelector->addItem("Pitch Correction", 13);
    destinationSelector->setSelectedId(1);
    
    destinationSelector->onChange = [this]()
    {
        if (selectedSlot >= 0 && selectedSlot < 16)
        {
            int id = destinationSelector->getSelectedId();
            modulationSlots[selectedSlot].destination = static_cast<ModulationSlot::Destination>(id - 1);
            repaint();
        }
    };
    
    // Depth slider (-100% to +100%)
    depthSlider = std::make_unique<juce::Slider>();
    addAndMakeVisible(*depthSlider);
    depthSlider->setSliderStyle(juce::Slider::LinearHorizontal);
    depthSlider->setRange(-1.0, 1.0, 0.01);
    depthSlider->setValue(0.0);
    depthSlider->setTextBoxStyle(juce::Slider::TextBoxRight, false, 60, 20);
    depthSlider->setNumDecimalPlacesToDisplay(2);
    
    depthSlider->onValueChange = [this]()
    {
        if (selectedSlot >= 0 && selectedSlot < 16)
        {
            modulationSlots[selectedSlot].depth = static_cast<float>(depthSlider->getValue());
            repaint();
        }
    };
    
    // Depth label
    depthLabel = std::make_unique<juce::Label>();
    addAndMakeVisible(*depthLabel);
    depthLabel->setText("Depth:", juce::dontSendNotification);
    depthLabel->setJustificationType(juce::Justification::centredRight);
    
    // Enabled toggle
    enabledToggle = std::make_unique<juce::ToggleButton>();
    addAndMakeVisible(*enabledToggle);
    enabledToggle->setButtonText("Enabled");
    
    enabledToggle->onStateChange = [this]()
    {
        if (selectedSlot >= 0 && selectedSlot < 16)
        {
            modulationSlots[selectedSlot].enabled = enabledToggle->getToggleState();
            repaint();
        }
    };
}

ModulationMatrixUI::~ModulationMatrixUI() = default;

void ModulationMatrixUI::setDSPManager(AdvancedDSPManager* manager)
{
    dspManager = manager;
}

void ModulationMatrixUI::paint(juce::Graphics& g)
{
    auto bounds = getLocalBounds();
    
    // Background
    g.fillAll(juce::Colour(0xff1a1a1f));
    
    // Title
    g.setColour(juce::Colours::white);
    g.setFont(juce::Font(20.0f, juce::Font::bold));
    g.drawText("Modulation Matrix", bounds.removeFromTop(40), juce::Justification::centred);
    
    // Draw grid area background
    if (!gridArea.isEmpty())
    {
        g.setColour(juce::Colour(0xff252530));
        g.fillRect(gridArea);
        
        // Draw grid lines
        g.setColour(juce::Colour(0xff35353f));
        int cellWidth = gridArea.getWidth() / gridCols;
        int cellHeight = gridArea.getHeight() / gridRows;
        
        for (int i = 0; i <= gridCols; ++i)
        {
            int x = gridArea.getX() + i * cellWidth;
            g.drawVerticalLine(x, static_cast<float>(gridArea.getY()), static_cast<float>(gridArea.getBottom()));
        }
        
        for (int i = 0; i <= gridRows; ++i)
        {
            int y = gridArea.getY() + i * cellHeight;
            g.drawHorizontalLine(y, static_cast<float>(gridArea.getX()), static_cast<float>(gridArea.getRight()));
        }
        
        // Draw modulation slots
        for (int i = 0; i < 16; ++i)
        {
            const auto& slot = modulationSlots[i];
            
            if (slot.source != ModulationSlot::Source::None && 
                slot.destination != ModulationSlot::Destination::None)
            {
                auto cellBounds = getBoundsForSlot(i);
                
                // Cell background
                if (i == selectedSlot)
                    g.setColour(slot.color.withAlpha(0.5f));
                else if (slot.enabled)
                    g.setColour(slot.color.withAlpha(0.3f));
                else
                    g.setColour(slot.color.withAlpha(0.1f));
                
                g.fillRect(cellBounds.reduced(2));
                
                // Connection indicator
                if (slot.enabled)
                {
                    g.setColour(slot.color);
                    auto centerBounds = cellBounds.reduced(cellBounds.getWidth() / 4, cellBounds.getHeight() / 4);
                    g.fillEllipse(centerBounds.toFloat());
                    
                    // Modulation depth indicator
                    float depthHeight = std::abs(slot.depth) * cellBounds.getHeight() * 0.5f;
                    auto depthBounds = cellBounds.withSizeKeepingCentre(4, static_cast<int>(depthHeight));
                    g.setColour(slot.color.brighter(0.3f));
                    g.fillRect(depthBounds);
                }
                
                // Slot number
                g.setColour(juce::Colours::white);
                g.setFont(10.0f);
                g.drawText(juce::String(i + 1), cellBounds.reduced(2), juce::Justification::topLeft);
                
                // Depth value
                if (slot.enabled)
                {
                    g.setFont(12.0f);
                    juce::String depthText = juce::String(static_cast<int>(slot.depth * 100)) + "%";
                    g.drawText(depthText, cellBounds.reduced(2), juce::Justification::centred);
                }
            }
        }
        
        // Draw selection outline
        if (selectedSlot >= 0 && selectedSlot < 16)
        {
            auto selectedBounds = getBoundsForSlot(selectedSlot);
            g.setColour(juce::Colour(0xff00d4ff));
            g.drawRect(selectedBounds, 2);
        }
    }
}

void ModulationMatrixUI::resized()
{
    auto bounds = getLocalBounds();
    
    // Reserve space for title
    bounds.removeFromTop(40);
    
    // Control panel at bottom
    auto controlPanel = bounds.removeFromBottom(120);
    controlPanel = controlPanel.reduced(10);
    
    // Source selector row
    auto sourceRow = controlPanel.removeFromTop(30);
    auto sourceLabel = sourceRow.removeFromLeft(80);
    sourceSelector->setBounds(sourceRow.reduced(5));
    
    controlPanel.removeFromTop(5);
    
    // Destination selector row
    auto destRow = controlPanel.removeFromTop(30);
    auto destLabel = destRow.removeFromLeft(80);
    destinationSelector->setBounds(destRow.reduced(5));
    
    controlPanel.removeFromTop(5);
    
    // Depth slider row
    auto depthRow = controlPanel.removeFromTop(30);
    depthLabel->setBounds(depthRow.removeFromLeft(80));
    auto depthSliderBounds = depthRow.removeFromLeft(depthRow.getWidth() - 80);
    depthSlider->setBounds(depthSliderBounds.reduced(5));
    enabledToggle->setBounds(depthRow.reduced(5));
    
    // Grid area (main content)
    gridArea = bounds.reduced(10);
}

void ModulationMatrixUI::mouseDown(const juce::MouseEvent& event)
{
    int slot = getSlotAtPosition(event.x, event.y);
    
    if (slot >= 0 && slot < 16)
    {
        selectedSlot = slot;
        
        // Update UI controls
        const auto& slotData = modulationSlots[slot];
        sourceSelector->setSelectedId(static_cast<int>(slotData.source) + 1, juce::dontSendNotification);
        destinationSelector->setSelectedId(static_cast<int>(slotData.destination) + 1, juce::dontSendNotification);
        depthSlider->setValue(slotData.depth, juce::dontSendNotification);
        enabledToggle->setToggleState(slotData.enabled, juce::dontSendNotification);
        
        repaint();
    }
}

void ModulationMatrixUI::mouseDrag(const juce::MouseEvent& event)
{
    if (selectedSlot >= 0 && selectedSlot < 16)
    {
        // Allow quick depth adjustment by vertical dragging
        float sensitivity = 0.005f;
        float delta = -event.getDistanceFromDragStartY() * sensitivity;
        
        auto& slot = modulationSlots[selectedSlot];
        slot.depth = juce::jlimit(-1.0f, 1.0f, slot.depth + delta);
        
        depthSlider->setValue(slot.depth, juce::dontSendNotification);
        repaint();
    }
}

void ModulationMatrixUI::mouseUp(const juce::MouseEvent&)
{
    // Mouse released - apply modulation
    applyModulation();
}

juce::String ModulationMatrixUI::getSourceName(ModulationSlot::Source source) const
{
    switch (source)
    {
        case ModulationSlot::Source::None: return "None";
        case ModulationSlot::Source::LFO1: return "LFO 1";
        case ModulationSlot::Source::LFO2: return "LFO 2";
        case ModulationSlot::Source::LFO3: return "LFO 3";
        case ModulationSlot::Source::LFO4: return "LFO 4";
        case ModulationSlot::Source::Envelope1: return "Env 1";
        case ModulationSlot::Source::Envelope2: return "Env 2";
        case ModulationSlot::Source::Envelope3: return "Env 3";
        case ModulationSlot::Source::Envelope4: return "Env 4";
        case ModulationSlot::Source::Velocity: return "Velocity";
        case ModulationSlot::Source::Aftertouch: return "Aftertouch";
        case ModulationSlot::Source::ModWheel: return "Mod Wheel";
        case ModulationSlot::Source::HRV: return "HRV";
        case ModulationSlot::Source::Coherence: return "Coherence";
        case ModulationSlot::Source::Stress: return "Stress";
        case ModulationSlot::Source::Random: return "Random";
        default: return "Unknown";
    }
}

juce::String ModulationMatrixUI::getDestinationName(ModulationSlot::Destination destination) const
{
    switch (destination)
    {
        case ModulationSlot::Destination::None: return "None";
        case ModulationSlot::Destination::FilterCutoff: return "Filter Cutoff";
        case ModulationSlot::Destination::FilterResonance: return "Filter Resonance";
        case ModulationSlot::Destination::Pitch: return "Pitch";
        case ModulationSlot::Destination::Amplitude: return "Amplitude";
        case ModulationSlot::Destination::Pan: return "Pan";
        case ModulationSlot::Destination::ReverbMix: return "Reverb Mix";
        case ModulationSlot::Destination::DelayTime: return "Delay Time";
        case ModulationSlot::Destination::DistortionAmount: return "Distortion";
        case ModulationSlot::Destination::MidSideBalance: return "Mid/Side";
        case ModulationSlot::Destination::HumanizerAmount: return "Humanizer";
        case ModulationSlot::Destination::SwarmDensity: return "Swarm Density";
        case ModulationSlot::Destination::PitchCorrectionStrength: return "Pitch Correction";
        default: return "Unknown";
    }
}

juce::Colour ModulationMatrixUI::getColorForSource(ModulationSlot::Source source) const
{
    switch (source)
    {
        case ModulationSlot::Source::LFO1:
        case ModulationSlot::Source::LFO2:
        case ModulationSlot::Source::LFO3:
        case ModulationSlot::Source::LFO4:
            return juce::Colour(0xff00d4ff);  // Cyan for LFOs
            
        case ModulationSlot::Source::Envelope1:
        case ModulationSlot::Source::Envelope2:
        case ModulationSlot::Source::Envelope3:
        case ModulationSlot::Source::Envelope4:
            return juce::Colour(0xff00ff88);  // Green for Envelopes
            
        case ModulationSlot::Source::Velocity:
        case ModulationSlot::Source::Aftertouch:
        case ModulationSlot::Source::ModWheel:
            return juce::Colour(0xffffaa00);  // Orange for MIDI
            
        case ModulationSlot::Source::HRV:
        case ModulationSlot::Source::Coherence:
        case ModulationSlot::Source::Stress:
            return juce::Colour(0xffff00ff);  // Magenta for Bio-reactive
            
        case ModulationSlot::Source::Random:
            return juce::Colour(0xffff4444);  // Red for Random
            
        default:
            return juce::Colour(0xff808080);  // Grey for None
    }
}

void ModulationMatrixUI::updateModulationValues()
{
    if (!dspManager)
        return;
    
    // Update visual values for active modulation slots
    // This would query the DSP manager for current modulation values
    for (auto& slot : modulationSlots)
    {
        if (slot.enabled && slot.source != ModulationSlot::Source::None)
        {
            // In real implementation, get actual modulation value from DSP
            // For now, simulate with a placeholder
            slot.visualValue = slot.depth;
        }
    }
}

void ModulationMatrixUI::applyModulation()
{
    if (!dspManager)
        return;
    
    // Apply modulation routing to DSP manager
    // This would send the modulation matrix configuration to the DSP engine
    
    for (int i = 0; i < 16; ++i)
    {
        const auto& slot = modulationSlots[i];
        
        if (slot.enabled && 
            slot.source != ModulationSlot::Source::None && 
            slot.destination != ModulationSlot::Destination::None)
        {
            // Send modulation routing to DSP
            // Example: dspManager->setModulationRouting(i, source, destination, depth);
        }
    }
}

int ModulationMatrixUI::getSlotAtPosition(int x, int y) const
{
    if (!gridArea.contains(x, y))
        return -1;
    
    int cellWidth = gridArea.getWidth() / gridCols;
    int cellHeight = gridArea.getHeight() / gridRows;
    
    int col = (x - gridArea.getX()) / cellWidth;
    int row = (y - gridArea.getY()) / cellHeight;
    
    if (col < 0 || col >= gridCols || row < 0 || row >= gridRows)
        return -1;
    
    return row * gridCols + col;
}

juce::Rectangle<int> ModulationMatrixUI::getBoundsForSlot(int slotIndex) const
{
    if (slotIndex < 0 || slotIndex >= 16 || gridArea.isEmpty())
        return juce::Rectangle<int>();
    
    int cellWidth = gridArea.getWidth() / gridCols;
    int cellHeight = gridArea.getHeight() / gridRows;
    
    int col = slotIndex % gridCols;
    int row = slotIndex / gridCols;
    
    int x = gridArea.getX() + col * cellWidth;
    int y = gridArea.getY() + row * cellHeight;
    
    return juce::Rectangle<int>(x, y, cellWidth, cellHeight);
}

// GridCell Implementation
ModulationMatrixUI::GridCell::GridCell(ModulationMatrixUI& parent, int index)
    : owner(parent), slotIndex(index)
{
}

void ModulationMatrixUI::GridCell::paint(juce::Graphics& g)
{
    auto bounds = getLocalBounds().toFloat();
    
    const auto& slot = owner.modulationSlots[slotIndex];
    
    // Background
    if (isHovered)
        g.setColour(juce::Colour(0xff35353f));
    else
        g.setColour(juce::Colour(0xff252530));
    
    g.fillRect(bounds);
    
    // Connection indicator
    if (slot.enabled && slot.source != ModulationMatrixUI::ModulationSlot::Source::None)
    {
        g.setColour(slot.color);
        auto centerBounds = bounds.reduced(bounds.getWidth() * 0.25f, bounds.getHeight() * 0.25f);
        g.fillEllipse(centerBounds);
    }
    
    // Border
    g.setColour(juce::Colour(0xff454550));
    g.drawRect(bounds, 1.0f);
}

void ModulationMatrixUI::GridCell::mouseDown(const juce::MouseEvent& event)
{
    owner.selectedSlot = slotIndex;
    owner.repaint();
}

void ModulationMatrixUI::GridCell::mouseDrag(const juce::MouseEvent& event)
{
    // Adjust depth by dragging
    if (owner.selectedSlot == slotIndex)
    {
        float sensitivity = 0.005f;
        float delta = -event.getDistanceFromDragStartY() * sensitivity;
        
        auto& slot = owner.modulationSlots[slotIndex];
        slot.depth = juce::jlimit(-1.0f, 1.0f, slot.depth + delta);
        
        owner.depthSlider->setValue(slot.depth, juce::dontSendNotification);
        owner.repaint();
    }
}
