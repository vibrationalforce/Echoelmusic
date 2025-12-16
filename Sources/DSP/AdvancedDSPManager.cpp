#include "AdvancedDSPManager.h"
#include <algorithm>

//==============================================================================
// Constructor
//==============================================================================

AdvancedDSPManager::AdvancedDSPManager()
{
    // Load factory presets
    loadFactoryPresets();

    DBG("Advanced DSP Manager initialized");
    DBG("  - Mid/Side Tone Matching: Ready");
    DBG("  - Audio Humanizer: Ready");
    DBG("  - Swarm Reverb: Ready");
    DBG("  - Polyphonic Pitch Editor: Ready");
    DBG("  - Bio-Reactive Integration: Active");
}

//==============================================================================
// Lifecycle
//==============================================================================

void AdvancedDSPManager::prepare(double sampleRate, int maxBlockSize)
{
    // Prepare all processors
    midSideToneMatching.prepare(sampleRate, maxBlockSize);
    audioHumanizer.prepare(sampleRate, maxBlockSize);
    swarmReverb.prepare(sampleRate, maxBlockSize);
    polyphonicPitchEditor.prepare(sampleRate, maxBlockSize);

    // Prepare existing bio-reactive processors
    juce::dsp::ProcessSpec spec;
    spec.sampleRate = sampleRate;
    spec.maximumBlockSize = maxBlockSize;
    spec.numChannels = 2;

    bioReactiveDSP.prepare(spec);
    bioReactiveAudioProcessor.prepare(sampleRate, maxBlockSize, 2);

    DBG("Advanced DSP Manager prepared:");
    DBG("  Sample Rate: " + juce::String(sampleRate) + " Hz");
    DBG("  Block Size: " + juce::String(maxBlockSize) + " samples");
}

void AdvancedDSPManager::reset()
{
    midSideToneMatching.reset();
    audioHumanizer.reset();
    swarmReverb.reset();
    polyphonicPitchEditor.reset();

    bioReactiveDSP.reset();

    DBG("Advanced DSP Manager reset");
}

void AdvancedDSPManager::process(juce::AudioBuffer<float>& buffer)
{
    // Start CPU timing
    currentProcessTime = juce::Time::getCurrentTime();

    // Process based on processing order
    switch (processingOrder)
    {
        case ProcessingOrder::Serial:
            // Process one after another
            if (midSideMatchingEnabled)
                midSideToneMatching.process(buffer);

            if (humanizerEnabled)
                audioHumanizer.process(buffer);

            if (swarmReverbEnabled)
                swarmReverb.process(buffer);

            if (pitchEditorEnabled)
                polyphonicPitchEditor.process(buffer);
            break;

        case ProcessingOrder::Parallel:
            // Process all simultaneously (would need parallel buffers in production)
            // For now, serial processing (parallel would require additional buffer management)
            if (midSideMatchingEnabled)
                midSideToneMatching.process(buffer);

            if (humanizerEnabled)
                audioHumanizer.process(buffer);

            if (swarmReverbEnabled)
                swarmReverb.process(buffer);

            if (pitchEditorEnabled)
                polyphonicPitchEditor.process(buffer);
            break;

        case ProcessingOrder::Selective:
            // Only enabled processors (optimal for CPU)
            if (midSideMatchingEnabled)
                midSideToneMatching.process(buffer);

            if (humanizerEnabled)
                audioHumanizer.process(buffer);

            if (swarmReverbEnabled)
                swarmReverb.process(buffer);

            if (pitchEditorEnabled)
                polyphonicPitchEditor.process(buffer);
            break;
    }

    // Also process existing bio-reactive DSP if enabled
    if (bioReactiveEnabled)
    {
        bioReactiveDSP.process(buffer, currentHRV, currentCoherence);
    }

    // Update CPU usage
    updateCPUUsage();

    // Check auto-bypass
    checkAutoBypass();
}

//==============================================================================
// Processor Enable/Disable
//==============================================================================

void AdvancedDSPManager::setMidSideMatchingEnabled(bool enable)
{
    if (midSideMatchingEnabled != enable)
    {
        pushUndoState();
        midSideMatchingEnabled = enable;
        DBG("Mid/Side Tone Matching: " + juce::String(enable ? "Enabled" : "Disabled"));
    }
}

void AdvancedDSPManager::setHumanizerEnabled(bool enable)
{
    if (humanizerEnabled != enable)
    {
        pushUndoState();
        humanizerEnabled = enable;
        DBG("Audio Humanizer: " + juce::String(enable ? "Enabled" : "Disabled"));
    }
}

void AdvancedDSPManager::setSwarmReverbEnabled(bool enable)
{
    if (swarmReverbEnabled != enable)
    {
        pushUndoState();
        swarmReverbEnabled = enable;
        DBG("Swarm Reverb: " + juce::String(enable ? "Enabled" : "Disabled"));
    }
}

void AdvancedDSPManager::setPitchEditorEnabled(bool enable)
{
    if (pitchEditorEnabled != enable)
    {
        pushUndoState();
        pitchEditorEnabled = enable;
        DBG("Polyphonic Pitch Editor: " + juce::String(enable ? "Enabled" : "Disabled"));
    }
}

void AdvancedDSPManager::setAllProcessorsEnabled(bool enable)
{
    pushUndoState();

    midSideMatchingEnabled = enable;
    humanizerEnabled = enable;
    swarmReverbEnabled = enable;
    pitchEditorEnabled = enable;

    DBG("All Processors: " + juce::String(enable ? "Enabled" : "Disabled"));
}

//==============================================================================
// Bio-Reactive Integration
//==============================================================================

void AdvancedDSPManager::updateBioData(float hrvNormalized, float coherence, float stressLevel)
{
    currentHRV = juce::jlimit(0.0f, 1.0f, hrvNormalized);
    currentCoherence = juce::jlimit(0.0f, 1.0f, coherence);
    currentStress = juce::jlimit(0.0f, 1.0f, stressLevel);

    // Update all processors with bio-data
    if (bioReactiveEnabled)
    {
        midSideToneMatching.updateBioData(currentHRV, currentCoherence, currentStress);
        audioHumanizer.updateBioData(currentHRV, currentCoherence, currentStress);
        swarmReverb.updateBioData(currentHRV, currentCoherence, currentStress);
        polyphonicPitchEditor.updateBioData(currentHRV, currentCoherence, currentStress);
    }
}

void AdvancedDSPManager::setBioReactiveEnabled(bool enable)
{
    bioReactiveEnabled = enable;

    // Propagate to all processors
    midSideToneMatching.setBioReactiveEnabled(enable);
    audioHumanizer.setBioReactiveEnabled(enable);
    swarmReverb.setBioReactiveEnabled(enable);
    polyphonicPitchEditor.setBioReactiveEnabled(enable);

    DBG("Bio-Reactive Mode: " + juce::String(enable ? "Enabled" : "Disabled"));
}

//==============================================================================
// Processing Order
//==============================================================================

void AdvancedDSPManager::setProcessingOrder(ProcessingOrder order)
{
    processingOrder = order;

    juce::String orderName;
    switch (order)
    {
        case ProcessingOrder::Serial: orderName = "Serial"; break;
        case ProcessingOrder::Parallel: orderName = "Parallel"; break;
        case ProcessingOrder::Selective: orderName = "Selective"; break;
    }

    DBG("Processing Order: " + orderName);
}

//==============================================================================
// Preset Management
//==============================================================================

bool AdvancedDSPManager::loadPreset(const juce::String& presetName)
{
    for (const auto& preset : presets)
    {
        if (preset.name == presetName)
        {
            pushUndoState();

            // Load processor states
            midSideMatchingEnabled = preset.state.midSideEnabled;
            humanizerEnabled = preset.state.humanizerEnabled;
            swarmReverbEnabled = preset.state.swarmEnabled;
            pitchEditorEnabled = preset.state.pitchEditorEnabled;

            // Load parameters (would be more detailed in production)
            // This is a simplified version

            DBG("Loaded preset: " + presetName);
            return true;
        }
    }

    DBG("Preset not found: " + presetName);
    return false;
}

bool AdvancedDSPManager::savePreset(const juce::String& presetName, PresetCategory category)
{
    Preset newPreset;
    newPreset.name = presetName;
    newPreset.category = category;

    // Save current processor states
    newPreset.state.midSideEnabled = midSideMatchingEnabled;
    newPreset.state.humanizerEnabled = humanizerEnabled;
    newPreset.state.swarmEnabled = swarmReverbEnabled;
    newPreset.state.pitchEditorEnabled = pitchEditorEnabled;

    // Save parameters (simplified)
    // Production version would save all parameters

    presets.push_back(newPreset);

    DBG("Saved preset: " + presetName);
    return true;
}

juce::StringArray AdvancedDSPManager::getPresets(PresetCategory category) const
{
    juce::StringArray result;

    for (const auto& preset : presets)
    {
        if (preset.category == category)
        {
            result.add(preset.name);
        }
    }

    return result;
}

void AdvancedDSPManager::loadFactoryPresets()
{
    // Factory Preset 1: Mastering Chain
    {
        Preset preset;
        preset.name = "Professional Mastering";
        preset.category = PresetCategory::Mastering;
        preset.state.midSideEnabled = true;
        preset.state.humanizerEnabled = false;
        preset.state.swarmEnabled = false;
        preset.state.pitchEditorEnabled = false;
        presets.push_back(preset);
    }

    // Factory Preset 2: Vocal Tuning
    {
        Preset preset;
        preset.name = "Vocal Tuning & Enhancement";
        preset.category = PresetCategory::Vocal;
        preset.state.midSideEnabled = false;
        preset.state.humanizerEnabled = true;
        preset.state.swarmEnabled = false;
        preset.state.pitchEditorEnabled = true;
        presets.push_back(preset);
    }

    // Factory Preset 3: Cinematic Atmosphere
    {
        Preset preset;
        preset.name = "Cinematic Space";
        preset.category = PresetCategory::Ambient;
        preset.state.midSideEnabled = false;
        preset.state.humanizerEnabled = true;
        preset.state.swarmEnabled = true;
        preset.state.pitchEditorEnabled = false;
        presets.push_back(preset);
    }

    // Factory Preset 4: Bio-Reactive Music
    {
        Preset preset;
        preset.name = "Full Bio-Reactive";
        preset.category = PresetCategory::BioReactive;
        preset.state.midSideEnabled = true;
        preset.state.humanizerEnabled = true;
        preset.state.swarmEnabled = true;
        preset.state.pitchEditorEnabled = true;
        presets.push_back(preset);
    }

    DBG("Loaded " + juce::String(presets.size()) + " factory presets");
}

//==============================================================================
// A/B Comparison
//==============================================================================

void AdvancedDSPManager::copyToA()
{
    stateA.midSideEnabled = midSideMatchingEnabled;
    stateA.humanizerEnabled = humanizerEnabled;
    stateA.swarmEnabled = swarmReverbEnabled;
    stateA.pitchEditorEnabled = pitchEditorEnabled;

    DBG("Copied current settings to A");
}

void AdvancedDSPManager::copyToB()
{
    stateB.midSideEnabled = midSideMatchingEnabled;
    stateB.humanizerEnabled = humanizerEnabled;
    stateB.swarmEnabled = swarmReverbEnabled;
    stateB.pitchEditorEnabled = pitchEditorEnabled;

    DBG("Copied current settings to B");
}

void AdvancedDSPManager::recallA()
{
    pushUndoState();

    midSideMatchingEnabled = stateA.midSideEnabled;
    humanizerEnabled = stateA.humanizerEnabled;
    swarmReverbEnabled = stateA.swarmEnabled;
    pitchEditorEnabled = stateA.pitchEditorEnabled;

    currentlyOnA = true;
    DBG("Recalled settings from A");
}

void AdvancedDSPManager::recallB()
{
    pushUndoState();

    midSideMatchingEnabled = stateB.midSideEnabled;
    humanizerEnabled = stateB.humanizerEnabled;
    swarmReverbEnabled = stateB.swarmEnabled;
    pitchEditorEnabled = stateB.pitchEditorEnabled;

    currentlyOnA = false;
    DBG("Recalled settings from B");
}

void AdvancedDSPManager::toggleAB()
{
    if (currentlyOnA)
    {
        recallB();
    }
    else
    {
        recallA();
    }
}

//==============================================================================
// CPU Management
//==============================================================================

void AdvancedDSPManager::setAutoBypassEnabled(bool enable)
{
    autoBypassEnabled = enable;
    DBG("Auto-Bypass: " + juce::String(enable ? "Enabled" : "Disabled"));
}

void AdvancedDSPManager::setAutoBypassThreshold(float threshold)
{
    autoBypassThreshold = juce::jlimit(0.0f, 1.0f, threshold);
    DBG("Auto-Bypass Threshold: " + juce::String(static_cast<int>(threshold * 100)) + "%");
}

//==============================================================================
// Undo/Redo
//==============================================================================

bool AdvancedDSPManager::undo()
{
    if (!canUndo())
        return false;

    undoIndex--;

    const auto& state = undoHistory[undoIndex];
    midSideMatchingEnabled = state.midSideEnabled;
    humanizerEnabled = state.humanizerEnabled;
    swarmReverbEnabled = state.swarmEnabled;
    pitchEditorEnabled = state.pitchEditorEnabled;

    DBG("Undo: Restored state " + juce::String(undoIndex));
    return true;
}

bool AdvancedDSPManager::redo()
{
    if (!canRedo())
        return false;

    undoIndex++;

    const auto& state = undoHistory[undoIndex];
    midSideMatchingEnabled = state.midSideEnabled;
    humanizerEnabled = state.humanizerEnabled;
    swarmReverbEnabled = state.swarmEnabled;
    pitchEditorEnabled = state.pitchEditorEnabled;

    DBG("Redo: Restored state " + juce::String(undoIndex));
    return true;
}

//==============================================================================
// Metering & Analysis
//==============================================================================

int AdvancedDSPManager::getTotalLatency() const
{
    // Sum of all processor latencies (simplified - would be more precise in production)
    int totalLatency = 0;

    // FFT-based processors typically add 2048 samples latency
    if (midSideMatchingEnabled)
        totalLatency += 2048;

    // Other processors have minimal latency
    if (humanizerEnabled)
        totalLatency += 0;  // Zero latency

    if (swarmReverbEnabled)
        totalLatency += 0;  // Zero latency

    if (pitchEditorEnabled)
        totalLatency += 1024;  // FFT-based pitch detection

    return totalLatency;
}

AdvancedDSPManager::MeteringData AdvancedDSPManager::getMeteringData() const
{
    MeteringData data;

    // Gather metering from all processors
    data.midSideSpectralDiff = midSideToneMatching.getMidSpectralDifference();
    data.humanizerVariation = audioHumanizer.getCurrentSpectralVariation();
    data.swarmDensity = swarmReverb.getSwarmDensity();
    data.pitchDrift = polyphonicPitchEditor.getAveragePitchDrift();

    // Calculate bio-reactive intensity (average of all modulations)
    float bioIntensity = (currentHRV + currentCoherence + (1.0f - currentStress)) / 3.0f;
    data.bioReactiveIntensity = bioIntensity;

    return data;
}

//==============================================================================
// Internal Helpers
//==============================================================================

void AdvancedDSPManager::updateCPUUsage()
{
    // Calculate CPU usage based on process time
    // (Simplified - production would use more accurate measurement)

    auto processDuration = currentProcessTime - lastProcessTime;
    float processTimeMs = processDuration.inMilliseconds();

    // Assume 10ms is 100% CPU for 512 samples @ 48kHz
    cpuUsage = juce::jlimit(0.0f, 1.0f, processTimeMs / 10.0f);

    lastProcessTime = currentProcessTime;
}

void AdvancedDSPManager::checkAutoBypass()
{
    if (!autoBypassEnabled)
        return;

    if (cpuUsage > autoBypassThreshold)
    {
        // Disable least critical processors first
        if (swarmReverbEnabled)
        {
            swarmReverbEnabled = false;
            DBG("Auto-Bypass: Disabled Swarm Reverb (CPU: " + juce::String(static_cast<int>(cpuUsage * 100)) + "%)");
        }
        else if (humanizerEnabled)
        {
            humanizerEnabled = false;
            DBG("Auto-Bypass: Disabled Humanizer (CPU: " + juce::String(static_cast<int>(cpuUsage * 100)) + "%)");
        }
    }
}

void AdvancedDSPManager::pushUndoState()
{
    // Create state snapshot
    ProcessorState state;
    state.midSideEnabled = midSideMatchingEnabled;
    state.humanizerEnabled = humanizerEnabled;
    state.swarmEnabled = swarmReverbEnabled;
    state.pitchEditorEnabled = pitchEditorEnabled;

    // Remove redo history
    if (undoIndex < static_cast<int>(undoHistory.size()) - 1)
    {
        undoHistory.erase(undoHistory.begin() + undoIndex + 1, undoHistory.end());
    }

    // Add to history
    undoHistory.push_back(state);
    undoIndex = static_cast<int>(undoHistory.size()) - 1;

    // Limit history size
    if (undoHistory.size() > MAX_UNDO_STEPS)
    {
        undoHistory.erase(undoHistory.begin());
        undoIndex--;
    }
}
