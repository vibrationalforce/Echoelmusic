#include "PluginProcessor.h"
#include "PluginEditor.h"

//==============================================================================
EchoelmusicAudioProcessor::EchoelmusicAudioProcessor()
#ifndef JucePlugin_PreferredChannelConfigurations
     : AudioProcessor (BusesProperties()
                     #if ! JucePlugin_IsMidiEffect
                      #if ! JucePlugin_IsSynth
                       .withInput  ("Input",  juce::AudioChannelSet::stereo(), true)
                      #endif
                       .withOutput ("Output", juce::AudioChannelSet::stereo(), true)
                     #endif
                       ),
#endif
      parameters (*this, nullptr, juce::Identifier ("EchoelmusicParameters"),
                  createParameterLayout())
{
    // Initialize DSP modules
    //     bioReactiveDSP = std::make_unique<BioReactiveDSP>();
    //     hrvProcessor = std::make_unique<HRVProcessor>();  // TODO: Enable when HRVProcessor is implemented

    // Initialize spectrum data (lock-free FIFO buffers)
    spectrumDataForUI.fill(0.0f);
    for (auto& buffer : spectrumBuffer)
        buffer.fill(0.0f);

    // Add parameter listeners
    parameters.addParameterListener(PARAM_ID_HRV, this);
    parameters.addParameterListener(PARAM_ID_COHERENCE, this);
    parameters.addParameterListener(PARAM_ID_FILTER_CUTOFF, this);
    parameters.addParameterListener(PARAM_ID_RESONANCE, this);
    parameters.addParameterListener(PARAM_ID_REVERB_MIX, this);
}

EchoelmusicAudioProcessor::~EchoelmusicAudioProcessor()
{
    parameters.removeParameterListener(PARAM_ID_HRV, this);
    parameters.removeParameterListener(PARAM_ID_COHERENCE, this);
    parameters.removeParameterListener(PARAM_ID_FILTER_CUTOFF, this);
    parameters.removeParameterListener(PARAM_ID_RESONANCE, this);
    parameters.removeParameterListener(PARAM_ID_REVERB_MIX, this);
}

//==============================================================================
juce::AudioProcessorValueTreeState::ParameterLayout
EchoelmusicAudioProcessor::createParameterLayout()
{
    juce::AudioProcessorValueTreeState::ParameterLayout layout;

    // Bio-Data Parameters (read-only, updated externally)
    layout.add(std::make_unique<juce::AudioParameterFloat>(
        PARAM_ID_HRV,
        "Heart Rate Variability",
        juce::NormalisableRange<float>(0.0f, 1.0f, 0.01f),
        0.5f,
        juce::String(),
        juce::AudioProcessorParameter::genericParameter,
        [](float value, int) { return juce::String(value, 2); }
    ));

    layout.add(std::make_unique<juce::AudioParameterFloat>(
        PARAM_ID_COHERENCE,
        "Coherence",
        juce::NormalisableRange<float>(0.0f, 1.0f, 0.01f),
        0.5f,
        juce::String(),
        juce::AudioProcessorParameter::genericParameter,
        [](float value, int) { return juce::String(value, 2); }
    ));

    // DSP Effect Parameters
    layout.add(std::make_unique<juce::AudioParameterFloat>(
        PARAM_ID_FILTER_CUTOFF,
        "Filter Cutoff",
        juce::NormalisableRange<float>(20.0f, 20000.0f, 1.0f, 0.3f),
        5000.0f,
        "Hz",
        juce::AudioProcessorParameter::genericParameter,
        [](float value, int) { return juce::String(static_cast<int>(value)) + " Hz"; }
    ));

    layout.add(std::make_unique<juce::AudioParameterFloat>(
        PARAM_ID_RESONANCE,
        "Resonance",
        juce::NormalisableRange<float>(0.0f, 1.0f, 0.01f),
        0.5f,
        juce::String(),
        juce::AudioProcessorParameter::genericParameter,
        [](float value, int) { return juce::String(value * 100.0f, 1) + "%"; }
    ));

    layout.add(std::make_unique<juce::AudioParameterFloat>(
        PARAM_ID_REVERB_MIX,
        "Reverb Mix",
        juce::NormalisableRange<float>(0.0f, 1.0f, 0.01f),
        0.3f,
        juce::String(),
        juce::AudioProcessorParameter::genericParameter,
        [](float value, int) { return juce::String(value * 100.0f, 1) + "%"; }
    ));

    layout.add(std::make_unique<juce::AudioParameterFloat>(
        PARAM_ID_DELAY_TIME,
        "Delay Time",
        juce::NormalisableRange<float>(0.0f, 2000.0f, 1.0f),
        500.0f,
        "ms"
    ));

    layout.add(std::make_unique<juce::AudioParameterFloat>(
        PARAM_ID_DISTORTION,
        "Distortion",
        juce::NormalisableRange<float>(0.0f, 1.0f, 0.01f),
        0.0f,
        juce::String(),
        juce::AudioProcessorParameter::genericParameter,
        [](float value, int) { return juce::String(value * 100.0f, 1) + "%"; }
    ));

    layout.add(std::make_unique<juce::AudioParameterFloat>(
        PARAM_ID_COMPRESSION,
        "Compression",
        juce::NormalisableRange<float>(1.0f, 20.0f, 0.1f),
        4.0f,
        ":1"
    ));

    return layout;
}

//==============================================================================
const juce::String EchoelmusicAudioProcessor::getName() const
{
    return JucePlugin_Name;
}

bool EchoelmusicAudioProcessor::acceptsMidi() const
{
   #if JucePlugin_WantsMidiInput
    return true;
   #else
    return false;
   #endif
}

bool EchoelmusicAudioProcessor::producesMidi() const
{
   #if JucePlugin_ProducesMidiOutput
    return true;
   #else
    return false;
   #endif
}

bool EchoelmusicAudioProcessor::isMidiEffect() const
{
   #if JucePlugin_IsMidiEffect
    return true;
   #else
    return false;
   #endif
}

double EchoelmusicAudioProcessor::getTailLengthSeconds() const
{
    return 0.0;
}

int EchoelmusicAudioProcessor::getNumPrograms()
{
    return 1;
}

int EchoelmusicAudioProcessor::getCurrentProgram()
{
    return 0;
}

void EchoelmusicAudioProcessor::setCurrentProgram (int index)
{
    juce::ignoreUnused (index);
}

const juce::String EchoelmusicAudioProcessor::getProgramName (int index)
{
    juce::ignoreUnused (index);
    return {};
}

void EchoelmusicAudioProcessor::changeProgramName (int index, const juce::String& newName)
{
    juce::ignoreUnused (index, newName);
}

//==============================================================================
void EchoelmusicAudioProcessor::prepareToPlay (double sampleRate, int samplesPerBlock)
{
    currentSampleRate = sampleRate;

    // Prepare DSP modules
    juce::dsp::ProcessSpec spec;
    spec.sampleRate = sampleRate;
    spec.maximumBlockSize = static_cast<uint32_t>(samplesPerBlock);
    spec.numChannels = 2;

        //     if (bioReactiveDSP)
        //         bioReactiveDSP->prepare(spec);

    // Reset heartbeat timing
    samplesUntilNextBeat = 0;
}

void EchoelmusicAudioProcessor::releaseResources()
{
        //     if (bioReactiveDSP)
        //         bioReactiveDSP->reset();
}

#ifndef JucePlugin_PreferredChannelConfigurations
bool EchoelmusicAudioProcessor::isBusesLayoutSupported (const BusesLayout& layouts) const
{
  #if JucePlugin_IsMidiEffect
    juce::ignoreUnused (layouts);
    return true;
  #else
    // Stereo only
    if (layouts.getMainOutputChannelSet() != juce::AudioChannelSet::stereo())
        return false;

   #if ! JucePlugin_IsSynth
    if (layouts.getMainOutputChannelSet() != layouts.getMainInputChannelSet())
        return false;
   #endif

    return true;
  #endif
}
#endif

void EchoelmusicAudioProcessor::processBlock (juce::AudioBuffer<float>& buffer,
                                              juce::MidiBuffer& midiMessages)
{
    juce::ScopedNoDenormals noDenormals;
    auto totalNumInputChannels  = getTotalNumInputChannels();
    auto totalNumOutputChannels = getTotalNumOutputChannels();

    // Clear unused output channels
    for (auto i = totalNumInputChannels; i < totalNumOutputChannels; ++i)
        buffer.clear (i, 0, buffer.getNumSamples());

    // Get current bio-data values
    const float hrv = currentHRV.load();
    const float coherence = currentCoherence.load();

    // Update DSP parameters based on bio-data
        //     if (bioReactiveDSP)
    {
        // HRV modulates filter cutoff
        float filterCutoff = juce::jmap(hrv, 0.0f, 1.0f, 500.0f, 10000.0f);
        parameters.getParameter(PARAM_ID_FILTER_CUTOFF)->setValueNotifyingHost(
            parameters.getParameterRange(PARAM_ID_FILTER_CUTOFF).convertTo0to1(filterCutoff)
        );

        // Coherence modulates reverb mix
        float reverbMix = juce::jmap(coherence, 0.0f, 1.0f, 0.0f, 0.7f);
        parameters.getParameter(PARAM_ID_REVERB_MIX)->setValueNotifyingHost(reverbMix);

        // Process audio with bio-reactive DSP
            //         bioReactiveDSP->process(buffer, hrv, coherence);
    }

    // Generate heartbeat MIDI
    if (producesMidi())
        generateHeartbeatMIDI(midiMessages, buffer.getNumSamples());

    // Update spectrum data for visualization
    updateSpectrumData(buffer);
}

//==============================================================================
void EchoelmusicAudioProcessor::generateHeartbeatMIDI(juce::MidiBuffer& midiMessages,
                                                       int numSamples)
{
    const float heartRate = currentHeartRate.load();
    const int samplesPerBeat = static_cast<int>((60.0 / heartRate) * currentSampleRate);

    for (int sample = 0; sample < numSamples; ++sample)
    {
        if (--samplesUntilNextBeat <= 0)
        {
            // Generate MIDI note for heartbeat (C3)
            midiMessages.addEvent(juce::MidiMessage::noteOn(1, 60, 0.8f), sample);

            // Note off after 50ms
            int noteOffSample = sample + static_cast<int>(0.05 * currentSampleRate);
            if (noteOffSample < numSamples)
                midiMessages.addEvent(juce::MidiMessage::noteOff(1, 60), noteOffSample);

            samplesUntilNextBeat = samplesPerBeat;
        }
    }
}

//==============================================================================
void EchoelmusicAudioProcessor::updateBioData(float hrv, float coherence, float heartRate)
{
    // Thread-safe atomic updates
    currentHRV.store(hrv);
    currentCoherence.store(coherence);
    currentHeartRate.store(heartRate);
    bioDataTimestamp.store(juce::Time::currentTimeMillis());

    // Update parameter display (not the actual parameter value)
    // This allows the host to see the bio-data values
    if (auto* hrvParam = parameters.getParameter(PARAM_ID_HRV))
        hrvParam->setValueNotifyingHost(hrv);

    if (auto* cohParam = parameters.getParameter(PARAM_ID_COHERENCE))
        cohParam->setValueNotifyingHost(coherence);
}

EchoelmusicAudioProcessor::BioData EchoelmusicAudioProcessor::getCurrentBioData() const
{
    BioData data;
    data.hrv = currentHRV.load();
    data.coherence = currentCoherence.load();
    data.heartRate = currentHeartRate.load();
    data.timestamp = bioDataTimestamp.load();
    return data;
}

//==============================================================================
void EchoelmusicAudioProcessor::parameterChanged(const juce::String& parameterID,
                                                  float newValue)
{
    // Handle parameter changes
    // TODO: Re-enable when DSP is ported to JUCE 7
    //     if (bioReactiveDSP)
    //     {
    //         if (parameterID == PARAM_ID_FILTER_CUTOFF)
    //             bioReactiveDSP->setFilterCutoff(newValue);
    //         else if (parameterID == PARAM_ID_RESONANCE)
    //             bioReactiveDSP->setResonance(newValue);
    //         else if (parameterID == PARAM_ID_REVERB_MIX)
    //             bioReactiveDSP->setReverbMix(newValue);
    //     }
}

//==============================================================================
bool EchoelmusicAudioProcessor::hasEditor() const
{
    return true;
}

juce::AudioProcessorEditor* EchoelmusicAudioProcessor::createEditor()
{
    return new EchoelmusicAudioProcessorEditor (*this);
}

//==============================================================================
void EchoelmusicAudioProcessor::getStateInformation (juce::MemoryBlock& destData)
{
    // Save parameter state
    auto state = parameters.copyState();
    std::unique_ptr<juce::XmlElement> xml (state.createXml());
    copyXmlToBinary (*xml, destData);
}

void EchoelmusicAudioProcessor::setStateInformation (const void* data, int sizeInBytes)
{
    // Restore parameter state
    std::unique_ptr<juce::XmlElement> xmlState (getXmlFromBinary (data, sizeInBytes));

    if (xmlState.get() != nullptr)
        if (xmlState->hasTagName (parameters.state.getType()))
            parameters.replaceState (juce::ValueTree::fromXml (*xmlState));
}

//==============================================================================
// Spectrum Analysis
//==============================================================================

std::vector<float> EchoelmusicAudioProcessor::getSpectrumData() const
{
    // ✅ LOCK-FREE: Read from FIFO (called from UI thread)
    int start1, size1, start2, size2;
    spectrumFifo.prepareToRead(1, start1, size1, start2, size2);

    if (size1 > 0)
    {
        // Copy latest spectrum data
        const_cast<EchoelmusicAudioProcessor*>(this)->spectrumDataForUI = spectrumBuffer[start1];
        const_cast<juce::AbstractFifo&>(spectrumFifo).finishedRead(size1);
    }

    return std::vector<float>(spectrumDataForUI.begin(), spectrumDataForUI.end());
}

void EchoelmusicAudioProcessor::updateSpectrumData(const juce::AudioBuffer<float>& buffer)
{
    if (buffer.getNumChannels() == 0 || buffer.getNumSamples() == 0)
        return;

    // ✅ LOCK-FREE: Write to FIFO (called from audio thread)
    // NO MUTEX - Real-time safe!

    int start1, size1, start2, size2;
    spectrumFifo.prepareToWrite(1, start1, size1, start2, size2);

    if (size1 > 0)
    {
        auto& targetBuffer = spectrumBuffer[start1];
        const auto* channelData = buffer.getReadPointer(0);
        const int numSamples = buffer.getNumSamples();

        // Simple RMS-based spectrum approximation for visualization
        // Logarithmic frequency bands (20Hz to 20kHz)
        for (int bin = 0; bin < spectrumSize; ++bin)
        {
            // Calculate RMS for this "band" (simplified - just use sequential samples)
            int startSample = (bin * numSamples) / spectrumSize;
            int endSample = ((bin + 1) * numSamples) / spectrumSize;

            float rms = 0.0f;
            for (int i = startSample; i < endSample && i < numSamples; ++i)
            {
                rms += channelData[i] * channelData[i];
            }

            if (endSample > startSample)
                rms = std::sqrt(rms / (endSample - startSample));

            // Convert to dB and normalize
            float db = juce::Decibels::gainToDecibels(rms + 0.0001f);
            float normalized = juce::jmap(db, -60.0f, 0.0f, 0.0f, 1.0f);

            // Smooth with previous value (using UI thread's last read)
            targetBuffer[bin] = spectrumDataForUI[bin] * 0.7f + normalized * 0.3f;
            targetBuffer[bin] = juce::jlimit(0.0f, 1.0f, targetBuffer[bin]);
        }

        spectrumFifo.finishedWrite(size1);
    }
}

//==============================================================================
// This creates new instances of the plugin
juce::AudioProcessor* JUCE_CALLTYPE createPluginFilter()
{
    return new EchoelmusicAudioProcessor();
}
