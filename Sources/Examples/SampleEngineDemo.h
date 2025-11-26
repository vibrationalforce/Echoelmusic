#pragma once

#include <JuceHeader.h>
#include "../Audio/UniversalSampleEngine.h"

/**
 * SampleEngineDemo - Interactive demonstration of UniversalSampleEngine
 *
 * This example shows:
 * - Loading the processed sample library
 * - Getting samples by category/subcategory/velocity
 * - MIDI note triggering
 * - Bio-reactive sample selection
 * - Jungle break slicing
 * - Integration patterns for instruments
 *
 * Usage:
 * ```cpp
 * SampleEngineDemo demo;
 * demo.initialize("/path/to/processed_samples");
 * demo.runInteractiveDemo();
 * ```
 */

class SampleEngineDemo : public juce::Component,
                         private juce::Timer
{
public:
    SampleEngineDemo();
    ~SampleEngineDemo() override;

    //==============================================================================
    // Initialization
    //==============================================================================

    /** Initialize with sample library path */
    bool initialize(const juce::File& libraryPath);

    /** Run command-line interactive demo */
    void runInteractiveDemo();

    //==============================================================================
    // Demo Functions
    //==============================================================================

    /** Demo 1: Basic sample access */
    void demoBasicSampleAccess();

    /** Demo 2: Velocity layers */
    void demoVelocityLayers();

    /** Demo 3: MIDI triggering */
    void demoMidiTriggering();

    /** Demo 4: Bio-reactive selection */
    void demoBioReactive();

    /** Demo 5: Jungle break slicing */
    void demoJungleBreaks();

    /** Demo 6: Context-aware selection */
    void demoContextAware();

    /** Demo 7: Sample layering */
    void demoSampleLayering();

    //==============================================================================
    // Audio Playback
    //==============================================================================

    void prepareToPlay(int samplesPerBlockExpected, double sampleRate);
    void getNextAudioBlock(const juce::AudioSourceChannelInfo& bufferToFill);
    void releaseResources();

    //==============================================================================
    // UI (optional GUI demo)
    //==============================================================================

    void paint(juce::Graphics& g) override;
    void resized() override;

private:
    //==============================================================================
    // Core Components
    //==============================================================================

    UniversalSampleEngine sampleEngine;

    juce::AudioFormatManager formatManager;
    std::unique_ptr<juce::AudioFormatReaderSource> currentSamplePlayer;
    juce::AudioTransportSource transportSource;

    // Playback state
    const SampleMetadata* currentSample = nullptr;
    bool isPlaying = false;
    double currentSampleRate = 44100.0;

    //==============================================================================
    // Helper Methods
    //==============================================================================

    void playSample(const SampleMetadata* sample);
    void stopPlayback();
    void printSampleInfo(const SampleMetadata* sample);
    void printLibraryStats();

    void timerCallback() override;

    //==============================================================================
    // UI Components (for GUI version)
    //==============================================================================

    juce::TextButton loadLibraryButton;
    juce::TextButton demo1Button, demo2Button, demo3Button;
    juce::TextButton demo4Button, demo5Button, demo6Button, demo7Button;
    juce::Label statusLabel;
    juce::TextEditor outputText;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(SampleEngineDemo)
};
