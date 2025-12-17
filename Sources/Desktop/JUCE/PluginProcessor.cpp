/*
  ==============================================================================

    Echoelmusic Pro - JUCE Plugin Processor Implementation

  ==============================================================================
*/

#include "PluginProcessor.h"
#include "PluginEditor.h"

//==============================================================================
EchoelmusicProProcessor::EchoelmusicProProcessor()
#ifndef JucePlugin_PreferredChannelConfigurations
     : AudioProcessor (BusesProperties()
                     #if ! JucePlugin_IsMidiEffect
                      #if ! JucePlugin_IsSynth
                       .withInput  ("Input",  juce::AudioChannelSet::stereo(), true)
                      #endif
                       .withOutput ("Output", juce::AudioChannelSet::stereo(), true)
                     #endif
                       )
#endif
{
}

EchoelmusicProProcessor::~EchoelmusicProProcessor()
{
}

//==============================================================================
const juce::String EchoelmusicProProcessor::getName() const
{
    return JucePlugin_Name;
}

bool EchoelmusicProProcessor::acceptsMidi() const
{
   #if JucePlugin_WantsMidiInput
    return true;
   #else
    return false;
   #endif
}

bool EchoelmusicProProcessor::producesMidi() const
{
   #if JucePlugin_ProducesMidiOutput
    return true;
   #else
    return false;
   #endif
}

bool EchoelmusicProProcessor::isMidiEffect() const
{
   #if JucePlugin_IsMidiEffect
    return true;
   #else
    return false;
   #endif
}

double EchoelmusicProProcessor::getTailLengthSeconds() const
{
    return 0.0;
}

int EchoelmusicProProcessor::getNumPrograms()
{
    return 1;   // Some hosts don't cope very well if you tell them there are 0 programs
}

int EchoelmusicProProcessor::getCurrentProgram()
{
    return 0;
}

void EchoelmusicProProcessor::setCurrentProgram (int index)
{
}

const juce::String EchoelmusicProProcessor::getProgramName (int index)
{
    return {};
}

void EchoelmusicProProcessor::changeProgramName (int index, const juce::String& newName)
{
}

//==============================================================================
void EchoelmusicProProcessor::prepareToPlay (double sampleRate, int samplesPerBlock)
{
    currentSampleRate = sampleRate;
    currentBlockSize = samplesPerBlock;

    // Initialize DSP
    juce::dsp::ProcessSpec spec;
    spec.sampleRate = sampleRate;
    spec.maximumBlockSize = static_cast<juce::uint32>(samplesPerBlock);
    spec.numChannels = 2;

    lowPassFilter.prepare(spec);
    lowPassFilter.reset();

    // Set filter coefficients (1kHz lowpass for now)
    *lowPassFilter.state = *juce::dsp::IIR::Coefficients<float>::makeLowPass(sampleRate, 1000.0f);
}

void EchoelmusicProProcessor::releaseResources()
{
    // Release any resources
}

#ifndef JucePlugin_PreferredChannelConfigurations
bool EchoelmusicProProcessor::isBusesLayoutSupported (const BusesLayout& layouts) const
{
  #if JucePlugin_IsMidiEffect
    juce::ignoreUnused (layouts);
    return true;
  #else
    // This is the place where you check if the layout is supported
    if (layouts.getMainOutputChannelSet() != juce::AudioChannelSet::mono()
     && layouts.getMainOutputChannelSet() != juce::AudioChannelSet::stereo())
        return false;

    // Check if input layout matches output layout
   #if ! JucePlugin_IsSynth
    if (layouts.getMainOutputChannelSet() != layouts.getMainInputChannelSet())
        return false;
   #endif

    return true;
  #endif
}
#endif

void EchoelmusicProProcessor::processBlock (juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midiMessages)
{
    juce::ScopedNoDenormals noDenormals;
    auto totalNumInputChannels  = getTotalNumInputChannels();
    auto totalNumOutputChannels = getTotalNumOutputChannels();

    // Clear any extra output channels
    for (auto i = totalNumInputChannels; i < totalNumOutputChannels; ++i)
        buffer.clear (i, 0, buffer.getNumSamples());

    // Simple sine wave for testing (will be replaced with actual synthesis)
    for (int channel = 0; channel < totalNumInputChannels; ++channel)
    {
        auto* channelData = buffer.getWritePointer (channel);

        // Generate test sine wave
        for (int sample = 0; sample < buffer.getNumSamples(); ++sample)
        {
            if (voices[0].active)
            {
                channelData[sample] = voices[0].amplitude * std::sin(voices[0].phase);
                voices[0].phase += 2.0f * juce::MathConstants<float>::pi * voices[0].frequency / static_cast<float>(currentSampleRate);

                if (voices[0].phase >= 2.0f * juce::MathConstants<float>::pi)
                    voices[0].phase -= 2.0f * juce::MathConstants<float>::pi;
            }
        }
    }

    // Process MIDI
    for (const auto metadata : midiMessages)
    {
        const auto msg = metadata.getMessage();

        if (msg.isNoteOn())
        {
            voices[0].active = true;
            voices[0].frequency = msg.getMidiNoteInHertz(msg.getNoteNumber());
            voices[0].amplitude = msg.getFloatVelocity();
            voices[0].phase = 0.0f;
        }
        else if (msg.isNoteOff())
        {
            voices[0].active = false;
        }
    }

    // Apply DSP processing
    juce::dsp::AudioBlock<float> block (buffer);
    juce::dsp::ProcessContextReplacing<float> context (block);
    // lowPassFilter.process(context);  // Disabled for now to hear raw synth

    // Copy audio buffer for visualization (thread-safe)
    latestAudioBuffer.makeCopyOf(buffer);
}

//==============================================================================
bool EchoelmusicProProcessor::hasEditor() const
{
    return true;
}

juce::AudioProcessorEditor* EchoelmusicProProcessor::createEditor()
{
    return new EchoelmusicProEditor (*this);
}

//==============================================================================
void EchoelmusicProProcessor::getStateInformation (juce::MemoryBlock& destData)
{
    // Save your plugin's state here
}

void EchoelmusicProProcessor::setStateInformation (const void* data, int sizeInBytes)
{
    // Restore your plugin's state here
}

//==============================================================================
// This creates new instances of the plugin
juce::AudioProcessor* JUCE_CALLTYPE createPluginFilter()
{
    return new EchoelmusicProProcessor();
}
