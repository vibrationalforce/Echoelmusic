#include "AdvancedDSPManager.h"

//==============================================================================
// Constructor
//==============================================================================

AdvancedDSPManager::AdvancedDSPManager()
{
    // Processors are initialized via member initialization
    // Default state: all disabled except bio-reactive (set in header)
}

//==============================================================================
// Lifecycle
//==============================================================================

void AdvancedDSPManager::prepare(double sampleRate, int maxBlockSize)
{
    // Prepare 4 advanced processors
    midSideToneMatching.prepare(sampleRate, maxBlockSize);
    audioHumanizer.prepare(sampleRate, maxBlockSize);
    swarmReverb.prepare(sampleRate, maxBlockSize);
    polyphonicPitchEditor.prepare(sampleRate, maxBlockSize);

    // Prepare bio-reactive processors
    juce::dsp::ProcessSpec spec;
    spec.sampleRate = sampleRate;
    spec.maximumBlockSize = static_cast<uint32_t>(maxBlockSize);
    spec.numChannels = 2;  // Stereo
    bioReactiveDSP.prepare(spec);
    bioReactiveAudioProcessor.prepare(sampleRate, maxBlockSize, 2);
}

void AdvancedDSPManager::reset()
{
    // Reset 4 advanced processors
    midSideToneMatching.reset();
    audioHumanizer.reset();
    swarmReverb.reset();
    polyphonicPitchEditor.reset();

    bioReactiveDSP.reset();
    bioReactiveAudioProcessor.reset();
}

void AdvancedDSPManager::process(juce::AudioBuffer<float>& buffer)
{
    // Process only enabled processors (Selective mode)

    if (midSideMatchingEnabled)
        midSideToneMatching.process(buffer);

    if (humanizerEnabled)
        audioHumanizer.process(buffer);

    if (swarmReverbEnabled)
        swarmReverb.process(buffer);

    if (pitchEditorEnabled)
        polyphonicPitchEditor.process(buffer);
}

//==============================================================================
// Processor Enable/Disable
//==============================================================================

void AdvancedDSPManager::setMidSideMatchingEnabled(bool enable)
{
    midSideMatchingEnabled = enable;
}

void AdvancedDSPManager::setHumanizerEnabled(bool enable)
{
    humanizerEnabled = enable;
}

void AdvancedDSPManager::setSwarmReverbEnabled(bool enable)
{
    swarmReverbEnabled = enable;
}

void AdvancedDSPManager::setPitchEditorEnabled(bool enable)
{
    pitchEditorEnabled = enable;
}

void AdvancedDSPManager::setAllProcessorsEnabled(bool enable)
{
    midSideMatchingEnabled = enable;
    humanizerEnabled = enable;
    swarmReverbEnabled = enable;
    pitchEditorEnabled = enable;
}

//==============================================================================
// Bio-Reactive Integration
//==============================================================================

void AdvancedDSPManager::updateBioData(float hrvNormalized, float coherence, float stressLevel)
{
    currentHRV = juce::jlimit(0.0f, 1.0f, hrvNormalized);
    currentCoherence = juce::jlimit(0.0f, 1.0f, coherence);
    currentStress = juce::jlimit(0.0f, 1.0f, stressLevel);

    // TODO: Update 4 advanced processors once implemented
    // if (bioReactiveEnabled)
    // {
    //     midSideToneMatching.updateBioData(currentHRV, currentCoherence, currentStress);
    //     audioHumanizer.updateBioData(currentHRV, currentCoherence, currentStress);
    //     swarmReverb.updateBioData(currentHRV, currentCoherence, currentStress);
    //     polyphonicPitchEditor.updateBioData(currentHRV, currentCoherence, currentStress);
    // }
}

void AdvancedDSPManager::setBioReactiveEnabled(bool enable)
{
    bioReactiveEnabled = enable;
}

//==============================================================================
// Processing Order (Minimal Implementation)
//==============================================================================

void AdvancedDSPManager::setProcessingOrder(ProcessingOrder order)
{
    processingOrder = order;
}

//==============================================================================
// Preset Management (Minimal Implementation)
//==============================================================================

bool AdvancedDSPManager::loadPreset(const juce::String& presetName)
{
    for (const auto& preset : presets)
    {
        if (preset.name == presetName)
        {
            midSideMatchingEnabled = preset.state.midSideEnabled;
            humanizerEnabled = preset.state.humanizerEnabled;
            swarmReverbEnabled = preset.state.swarmEnabled;
            pitchEditorEnabled = preset.state.pitchEditorEnabled;
            return true;
        }
    }
    return false;
}

bool AdvancedDSPManager::savePreset(const juce::String& presetName, PresetCategory category)
{
    Preset newPreset;
    newPreset.name = presetName;
    newPreset.category = category;
    newPreset.state.midSideEnabled = midSideMatchingEnabled;
    newPreset.state.humanizerEnabled = humanizerEnabled;
    newPreset.state.swarmEnabled = swarmReverbEnabled;
    newPreset.state.pitchEditorEnabled = pitchEditorEnabled;

    presets.push_back(newPreset);
    return true;
}

juce::StringArray AdvancedDSPManager::getPresets(PresetCategory category) const
{
    juce::StringArray result;
    for (const auto& preset : presets)
    {
        if (category == PresetCategory::All || preset.category == category)
            result.add(preset.name);
    }
    return result;
}

std::vector<AdvancedDSPManager::Preset> AdvancedDSPManager::getAllPresets() const
{
    return presets;
}

void AdvancedDSPManager::loadFactoryPresets()
{
    // Factory presets would be loaded here
}

bool AdvancedDSPManager::savePresetToDisk(const juce::String&)
{
    return false;  // TODO: Implement
}

bool AdvancedDSPManager::loadPresetFromDisk(const juce::String&)
{
    return false;  // TODO: Implement
}

void AdvancedDSPManager::loadUserPresetsFromDisk()
{
    // TODO: Implement
}

juce::File AdvancedDSPManager::getPresetsDirectory() const
{
    return juce::File::getSpecialLocation(juce::File::userApplicationDataDirectory)
        .getChildFile("Echoelmusic")
        .getChildFile("Presets");
}

//==============================================================================
// A/B Comparison (Minimal Implementation)
//==============================================================================

void AdvancedDSPManager::copyToA()
{
    stateA.midSideEnabled = midSideMatchingEnabled;
    stateA.humanizerEnabled = humanizerEnabled;
    stateA.swarmEnabled = swarmReverbEnabled;
    stateA.pitchEditorEnabled = pitchEditorEnabled;
}

void AdvancedDSPManager::copyToB()
{
    stateB.midSideEnabled = midSideMatchingEnabled;
    stateB.humanizerEnabled = humanizerEnabled;
    stateB.swarmEnabled = swarmReverbEnabled;
    stateB.pitchEditorEnabled = pitchEditorEnabled;
}

void AdvancedDSPManager::recallA()
{
    midSideMatchingEnabled = stateA.midSideEnabled;
    humanizerEnabled = stateA.humanizerEnabled;
    swarmReverbEnabled = stateA.swarmEnabled;
    pitchEditorEnabled = stateA.pitchEditorEnabled;
    currentlyOnA = true;
}

void AdvancedDSPManager::recallB()
{
    midSideMatchingEnabled = stateB.midSideEnabled;
    humanizerEnabled = stateB.humanizerEnabled;
    swarmReverbEnabled = stateB.swarmEnabled;
    pitchEditorEnabled = stateB.pitchEditorEnabled;
    currentlyOnA = false;
}

void AdvancedDSPManager::toggleAB()
{
    if (currentlyOnA)
        recallB();
    else
        recallA();
}

//==============================================================================
// CPU Management (Minimal Implementation)
//==============================================================================

void AdvancedDSPManager::setAutoBypassEnabled(bool enable)
{
    autoBypassEnabled = enable;
}

void AdvancedDSPManager::setAutoBypassThreshold(float threshold)
{
    autoBypassThreshold = juce::jlimit(0.0f, 1.0f, threshold);
}

//==============================================================================
// Undo/Redo (Minimal Implementation)
//==============================================================================

bool AdvancedDSPManager::undo()
{
    if (!canUndo())
        return false;

    --undoIndex;
    const auto& state = undoHistory[undoIndex];
    midSideMatchingEnabled = state.midSideEnabled;
    humanizerEnabled = state.humanizerEnabled;
    swarmReverbEnabled = state.swarmEnabled;
    pitchEditorEnabled = state.pitchEditorEnabled;

    return true;
}

bool AdvancedDSPManager::redo()
{
    if (!canRedo())
        return false;

    ++undoIndex;
    const auto& state = undoHistory[undoIndex];
    midSideMatchingEnabled = state.midSideEnabled;
    humanizerEnabled = state.humanizerEnabled;
    swarmReverbEnabled = state.swarmEnabled;
    pitchEditorEnabled = state.pitchEditorEnabled;

    return true;
}

//==============================================================================
// Metering & Analysis (Minimal Implementation)
//==============================================================================

int AdvancedDSPManager::getTotalLatency() const
{
    // These processors are zero-latency (real-time processing)
    return 0;
}

AdvancedDSPManager::MeteringData AdvancedDSPManager::getMeteringData() const
{
    MeteringData data;
    // TODO: Get metering from 4 advanced processors once implemented
    // data.midSideSpectralDiff = midSideToneMatching.getMidSpectralDifference();
    // data.humanizerVariation = audioHumanizer.getCurrentSpectralVariation();
    // data.swarmDensity = swarmReverb.getSwarmDensity();
    // data.pitchDrift = polyphonicPitchEditor.getAveragePitchDrift();
    data.bioReactiveIntensity = (currentHRV + currentCoherence) / 2.0f;

    return data;
}

//==============================================================================
// Internal Helpers
//==============================================================================

void AdvancedDSPManager::updateCPUUsage()
{
    // Simplified CPU monitoring
    cpuUsage = 0.0f;
}

void AdvancedDSPManager::checkAutoBypass()
{
    // Auto-bypass logic would go here
}

void AdvancedDSPManager::pushUndoState()
{
    ProcessorState state;
    state.midSideEnabled = midSideMatchingEnabled;
    state.humanizerEnabled = humanizerEnabled;
    state.swarmEnabled = swarmReverbEnabled;
    state.pitchEditorEnabled = pitchEditorEnabled;

    // Remove any redo states
    if (undoIndex < static_cast<int>(undoHistory.size()) - 1)
    {
        undoHistory.erase(undoHistory.begin() + undoIndex + 1, undoHistory.end());
    }

    undoHistory.push_back(state);

    // Limit history size
    if (undoHistory.size() > MAX_UNDO_STEPS)
    {
        undoHistory.erase(undoHistory.begin());
    }

    undoIndex = static_cast<int>(undoHistory.size()) - 1;
}
