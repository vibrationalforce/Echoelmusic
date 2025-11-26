#include "SampleEngineDemo.h"

//==============================================================================
// Constructor / Destructor
//==============================================================================

SampleEngineDemo::SampleEngineDemo()
{
    formatManager.registerBasicFormats();

    // Setup UI buttons (for GUI version)
    addAndMakeVisible(loadLibraryButton);
    loadLibraryButton.setButtonText("Load Library");
    loadLibraryButton.onClick = [this]
    {
        juce::FileChooser chooser("Select processed_samples folder");
        if (chooser.browseForDirectory())
        {
            initialize(chooser.getResult());
        }
    };

    addAndMakeVisible(demo1Button);
    demo1Button.setButtonText("Demo 1: Basic Access");
    demo1Button.onClick = [this] { demoBasicSampleAccess(); };

    addAndMakeVisible(demo2Button);
    demo2Button.setButtonText("Demo 2: Velocity Layers");
    demo2Button.onClick = [this] { demoVelocityLayers(); };

    addAndMakeVisible(demo3Button);
    demo3Button.setButtonText("Demo 3: MIDI Triggering");
    demo3Button.onClick = [this] { demoMidiTriggering(); };

    addAndMakeVisible(demo4Button);
    demo4Button.setButtonText("Demo 4: Bio-Reactive");
    demo4Button.onClick = [this] { demoBioReactive(); };

    addAndMakeVisible(demo5Button);
    demo5Button.setButtonText("Demo 5: Jungle Breaks");
    demo5Button.onClick = [this] { demoJungleBreaks(); };

    addAndMakeVisible(demo6Button);
    demo6Button.setButtonText("Demo 6: Context-Aware");
    demo6Button.onClick = [this] { demoContextAware(); };

    addAndMakeVisible(demo7Button);
    demo7Button.setButtonText("Demo 7: Layering");
    demo7Button.onClick = [this] { demoSampleLayering(); };

    addAndMakeVisible(statusLabel);
    statusLabel.setText("Ready - Load sample library to begin", juce::dontSendNotification);

    addAndMakeVisible(outputText);
    outputText.setMultiLine(true);
    outputText.setReadOnly(true);
    outputText.setScrollbarsShown(true);

    setSize(800, 600);
    startTimerHz(30);
}

SampleEngineDemo::~SampleEngineDemo()
{
    stopPlayback();
}

//==============================================================================
// Initialization
//==============================================================================

bool SampleEngineDemo::initialize(const juce::File& libraryPath)
{
    DBG("Initializing SampleEngineDemo with library: " << libraryPath.getFullPathName());

    if (!libraryPath.exists())
    {
        DBG("ERROR: Library path does not exist!");
        statusLabel.setText("Error: Library path not found", juce::dontSendNotification);
        return false;
    }

    // Load library
    bool success = sampleEngine.loadLibrary(libraryPath);

    if (success)
    {
        DBG("✅ Sample library loaded successfully!");
        statusLabel.setText("✅ Library loaded!", juce::dontSendNotification);
        printLibraryStats();
    }
    else
    {
        DBG("❌ Failed to load sample library!");
        statusLabel.setText("❌ Failed to load library", juce::dontSendNotification);
    }

    return success;
}

//==============================================================================
// Interactive Demo
//==============================================================================

void SampleEngineDemo::runInteractiveDemo()
{
    std::cout << "\n";
    std::cout << "========================================\n";
    std::cout << "  ECHOELMUSIC SAMPLE ENGINE DEMO\n";
    std::cout << "========================================\n";
    std::cout << "\n";

    if (!sampleEngine.isLibraryLoaded())
    {
        std::cout << "⚠️  Library not loaded. Please load first.\n";
        return;
    }

    printLibraryStats();

    while (true)
    {
        std::cout << "\n";
        std::cout << "Select a demo:\n";
        std::cout << "  1. Basic Sample Access\n";
        std::cout << "  2. Velocity Layers\n";
        std::cout << "  3. MIDI Triggering\n";
        std::cout << "  4. Bio-Reactive Selection\n";
        std::cout << "  5. Jungle Break Slicing\n";
        std::cout << "  6. Context-Aware Selection\n";
        std::cout << "  7. Sample Layering\n";
        std::cout << "  0. Exit\n";
        std::cout << "\nChoice: ";

        int choice;
        std::cin >> choice;

        switch (choice)
        {
            case 1: demoBasicSampleAccess(); break;
            case 2: demoVelocityLayers(); break;
            case 3: demoMidiTriggering(); break;
            case 4: demoBioReactive(); break;
            case 5: demoJungleBreaks(); break;
            case 6: demoContextAware(); break;
            case 7: demoSampleLayering(); break;
            case 0:
                std::cout << "\n👋 Goodbye!\n";
                return;
            default:
                std::cout << "❌ Invalid choice\n";
        }
    }
}

//==============================================================================
// Demo Implementations
//==============================================================================

void SampleEngineDemo::demoBasicSampleAccess()
{
    std::cout << "\n=== DEMO 1: Basic Sample Access ===\n\n";

    // Get a kick drum
    auto kick = sampleEngine.getSample("ECHOEL_DRUMS", "kicks", 0.7f);
    if (kick)
    {
        std::cout << "✅ Got kick drum:\n";
        printSampleInfo(kick);
        playSample(kick);
    }
    else
    {
        std::cout << "❌ Failed to get kick drum\n";
    }

    juce::Thread::sleep(1000);

    // Get a snare
    auto snare = sampleEngine.getSample("ECHOEL_DRUMS", "snares", 0.8f);
    if (snare)
    {
        std::cout << "\n✅ Got snare:\n";
        printSampleInfo(snare);
        playSample(snare);
    }

    juce::Thread::sleep(1000);

    // Get an 808 bass
    auto bass808 = sampleEngine.getSample("ECHOEL_BASS", "808", 1.0f);
    if (bass808)
    {
        std::cout << "\n✅ Got 808 bass:\n";
        printSampleInfo(bass808);
        playSample(bass808);
    }
}

void SampleEngineDemo::demoVelocityLayers()
{
    std::cout << "\n=== DEMO 2: Velocity Layers ===\n\n";
    std::cout << "Playing kick at different velocities:\n\n";

    // Soft hit
    std::cout << "🔹 Soft hit (velocity 0.2):\n";
    auto softKick = sampleEngine.getSample("ECHOEL_DRUMS", "kicks", 0.2f);
    if (softKick)
    {
        printSampleInfo(softKick);
        playSample(softKick);
        juce::Thread::sleep(800);
    }

    // Medium hit
    std::cout << "\n🔹 Medium hit (velocity 0.5):\n";
    auto medKick = sampleEngine.getSample("ECHOEL_DRUMS", "kicks", 0.5f);
    if (medKick)
    {
        printSampleInfo(medKick);
        playSample(medKick);
        juce::Thread::sleep(800);
    }

    // Hard hit
    std::cout << "\n🔹 Hard hit (velocity 1.0):\n";
    auto hardKick = sampleEngine.getSample("ECHOEL_DRUMS", "kicks", 1.0f);
    if (hardKick)
    {
        printSampleInfo(hardKick);
        playSample(hardKick);
    }
}

void SampleEngineDemo::demoMidiTriggering()
{
    std::cout << "\n=== DEMO 3: MIDI Triggering ===\n\n";

    // Map some MIDI notes
    sampleEngine.mapMidiNote(36, "ECHOEL_DRUMS", "kicks");      // C1
    sampleEngine.mapMidiNote(38, "ECHOEL_DRUMS", "snares");     // D1
    sampleEngine.mapMidiNote(42, "ECHOEL_DRUMS", "hihats");     // F#1

    std::cout << "Playing MIDI sequence (kick-snare-hihat):\n\n";

    // Play sequence
    int notes[] = {36, 42, 38, 42, 36, 42, 38, 42};
    float velocities[] = {0.9f, 0.4f, 0.8f, 0.5f, 1.0f, 0.3f, 0.7f, 0.6f};

    for (int i = 0; i < 8; i++)
    {
        auto sample = sampleEngine.getSampleForMidiNote(notes[i], velocities[i]);
        if (sample)
        {
            std::cout << "MIDI " << notes[i] << " (velocity " << velocities[i] << "): "
                      << sample->name << "\n";
            playSample(sample);
            juce::Thread::sleep(400);
        }
    }
}

void SampleEngineDemo::demoBioReactive()
{
    std::cout << "\n=== DEMO 4: Bio-Reactive Selection ===\n\n";

    // Enable bio-reactive filtering
    sampleEngine.enableBioReactiveFiltering(true);

    std::cout << "Scenario 1: Calm state\n";
    std::cout << "  Heart rate: 60 BPM\n";
    std::cout << "  Stress: Low (0.2)\n";
    std::cout << "  Focus: High (0.8)\n\n";

    sampleEngine.setHeartRate(60);
    sampleEngine.setStressLevel(0.2f);
    sampleEngine.setFocusLevel(0.8f);

    auto calmKick = sampleEngine.getSample("ECHOEL_DRUMS", "kicks", 0.5f);
    if (calmKick)
    {
        std::cout << "Selected: " << calmKick->name << "\n";
        playSample(calmKick);
    }

    juce::Thread::sleep(1500);

    std::cout << "\nScenario 2: Excited state\n";
    std::cout << "  Heart rate: 140 BPM\n";
    std::cout << "  Stress: High (0.9)\n";
    std::cout << "  Focus: Medium (0.5)\n\n";

    sampleEngine.setHeartRate(140);
    sampleEngine.setStressLevel(0.9f);
    sampleEngine.setFocusLevel(0.5f);

    auto excitedKick = sampleEngine.getSample("ECHOEL_DRUMS", "kicks", 0.5f);
    if (excitedKick)
    {
        std::cout << "Selected: " << excitedKick->name << "\n";
        playSample(excitedKick);
    }

    // Disable bio-reactive
    sampleEngine.enableBioReactiveFiltering(false);
}

void SampleEngineDemo::demoJungleBreaks()
{
    std::cout << "\n=== DEMO 5: Jungle Break Slicing ===\n\n";

    // Get Amen break slices
    auto amenSlices = sampleEngine.getJungleBreakSlices("amen", 170);

    if (amenSlices.empty())
    {
        std::cout << "❌ No jungle breaks found\n";
        std::cout << "ℹ️  Make sure ECHOEL_JUNGLE category has amen_slices\n";
        return;
    }

    std::cout << "✅ Loaded " << amenSlices.size() << " Amen break slices at 170 BPM\n\n";

    std::cout << "Playing classic jungle pattern:\n";
    std::cout << "Pattern: 0-4-8-10-0-4-8-12\n\n";

    // Classic jungle pattern
    int pattern[] = {0, 4, 8, 10, 0, 4, 8, 12};

    for (int i = 0; i < 8; i++)
    {
        int sliceIndex = pattern[i];
        if (sliceIndex < (int)amenSlices.size())
        {
            auto slice = amenSlices[sliceIndex];
            std::cout << "Slice " << sliceIndex << ": " << slice->name << "\n";
            playSample(slice);
            juce::Thread::sleep(176);  // 170 BPM = 176ms per 16th note
        }
    }
}

void SampleEngineDemo::demoContextAware()
{
    std::cout << "\n=== DEMO 6: Context-Aware Selection ===\n\n";

    std::cout << "Context: 128 BPM, A minor key, MIDI note 60 (C3)\n\n";

    auto sample = sampleEngine.autoSelectSample(
        "ECHOEL_MELODIC",
        60,         // MIDI note C3
        0.7f,       // velocity
        128.0f,     // tempo
        "Am"        // key
    );

    if (sample)
    {
        std::cout << "✅ Auto-selected sample:\n";
        printSampleInfo(sample);
        playSample(sample);
    }
    else
    {
        std::cout << "❌ No suitable sample found\n";
    }
}

void SampleEngineDemo::demoSampleLayering()
{
    std::cout << "\n=== DEMO 7: Sample Layering ===\n\n";

    // Get base kick
    auto baseKick = sampleEngine.getSample("ECHOEL_DRUMS", "kicks", 0.8f);
    if (!baseKick)
    {
        std::cout << "❌ Failed to get base kick\n";
        return;
    }

    std::cout << "Base kick:\n";
    printSampleInfo(baseKick);

    // Get complementary samples
    auto layers = sampleEngine.getComplementarySamples(baseKick, 3);

    std::cout << "\n✅ Found " << layers.size() << " complementary samples:\n\n";

    for (int i = 0; i < (int)layers.size(); i++)
    {
        std::cout << "Layer " << (i + 1) << ":\n";
        printSampleInfo(layers[i]);
        std::cout << "\n";
    }

    std::cout << "Playing layered kick (base + all layers)...\n";
    playSample(baseKick);
}

//==============================================================================
// Audio Playback
//==============================================================================

void SampleEngineDemo::prepareToPlay(int samplesPerBlockExpected, double sampleRate)
{
    currentSampleRate = sampleRate;
    transportSource.prepareToPlay(samplesPerBlockExpected, sampleRate);
}

void SampleEngineDemo::getNextAudioBlock(const juce::AudioSourceChannelInfo& bufferToFill)
{
    if (isPlaying && currentSamplePlayer != nullptr)
    {
        transportSource.getNextAudioBlock(bufferToFill);

        if (!transportSource.isPlaying())
        {
            isPlaying = false;
        }
    }
    else
    {
        bufferToFill.clearActiveBufferRegion();
    }
}

void SampleEngineDemo::releaseResources()
{
    transportSource.releaseResources();
}

void SampleEngineDemo::playSample(const SampleMetadata* sample)
{
    if (!sample || !sample->isLoaded)
    {
        DBG("Cannot play sample - not loaded");
        return;
    }

    stopPlayback();

    currentSample = sample;

    // Create a temporary file for playback (JUCE needs file-based playback)
    // In a real application, you'd use the AudioBuffer directly
    auto tempFile = juce::File::createTempFile(".wav");

    // Write sample to temp file
    juce::WavAudioFormat wavFormat;
    std::unique_ptr<juce::FileOutputStream> outputStream(tempFile.createOutputStream());

    if (outputStream != nullptr)
    {
        std::unique_ptr<juce::AudioFormatWriter> writer(
            wavFormat.createWriterFor(outputStream.get(),
                                     currentSampleRate,
                                     sample->audioData.getNumChannels(),
                                     24,
                                     {},
                                     0));

        if (writer != nullptr)
        {
            outputStream.release();
            writer->writeFromAudioSampleBuffer(sample->audioData, 0, sample->audioData.getNumSamples());
            writer.reset();

            // Play the file
            auto reader = formatManager.createReaderFor(tempFile);
            if (reader != nullptr)
            {
                currentSamplePlayer = std::make_unique<juce::AudioFormatReaderSource>(reader, true);
                transportSource.setSource(currentSamplePlayer.get(), 0, nullptr, currentSampleRate);
                transportSource.setPosition(0);
                transportSource.start();
                isPlaying = true;
            }
        }
    }
}

void SampleEngineDemo::stopPlayback()
{
    transportSource.stop();
    transportSource.setSource(nullptr);
    currentSamplePlayer.reset();
    isPlaying = false;
}

//==============================================================================
// Helper Methods
//==============================================================================

void SampleEngineDemo::printSampleInfo(const SampleMetadata* sample)
{
    if (!sample)
    {
        std::cout << "  (null sample)\n";
        return;
    }

    std::cout << "  Name: " << sample->name << "\n";
    std::cout << "  Category: " << sample->category << " / " << sample->subcategory << "\n";
    std::cout << "  Duration: " << sample->durationMs << " ms\n";

    if (sample->pitchHz > 0)
        std::cout << "  Pitch: " << sample->pitchHz << " Hz\n";

    if (sample->tempoBpm > 0)
        std::cout << "  Tempo: " << sample->tempoBpm << " BPM\n";

    if (sample->key.isNotEmpty())
        std::cout << "  Key: " << sample->key << "\n";

    std::cout << "  Energy: " << sample->energyLevel << "\n";
    std::cout << "  Brightness: " << sample->brightness << "\n";
    std::cout << "  Loaded: " << (sample->isLoaded ? "Yes" : "No") << "\n";
}

void SampleEngineDemo::printLibraryStats()
{
    auto stats = sampleEngine.getLibraryStats();

    std::cout << "\n";
    std::cout << "📊 Library Statistics:\n";
    std::cout << "  Total samples: " << stats.totalSamples << "\n";
    std::cout << "  Loaded samples: " << stats.loadedSamples << "\n";
    std::cout << "  Total size: " << stats.totalSizeMB << " MB\n";
    std::cout << "  Categories: " << stats.categories.size() << "\n";

    for (const auto& category : stats.categories)
    {
        std::cout << "    - " << category << "\n";
    }

    std::cout << "\n";
}

//==============================================================================
// UI
//==============================================================================

void SampleEngineDemo::paint(juce::Graphics& g)
{
    g.fillAll(juce::Colours::darkgrey);

    g.setColour(juce::Colours::white);
    g.setFont(24.0f);
    g.drawText("Echoelmusic Sample Engine Demo",
               getLocalBounds().removeFromTop(60),
               juce::Justification::centred);
}

void SampleEngineDemo::resized()
{
    auto bounds = getLocalBounds().reduced(20);
    bounds.removeFromTop(60);

    auto topSection = bounds.removeFromTop(100);
    loadLibraryButton.setBounds(topSection.removeFromTop(40).reduced(100, 5));
    statusLabel.setBounds(topSection.removeFromTop(30).reduced(50, 5));

    auto buttonSection = bounds.removeFromTop(120);
    auto buttonRow1 = buttonSection.removeFromTop(40);
    auto buttonRow2 = buttonSection.removeFromTop(40);
    auto buttonRow3 = buttonSection.removeFromTop(40);

    int buttonWidth = buttonRow1.getWidth() / 4 - 10;

    demo1Button.setBounds(buttonRow1.removeFromLeft(buttonWidth).reduced(5));
    demo2Button.setBounds(buttonRow1.removeFromLeft(buttonWidth).reduced(5));
    demo3Button.setBounds(buttonRow1.removeFromLeft(buttonWidth).reduced(5));
    demo4Button.setBounds(buttonRow1.removeFromLeft(buttonWidth).reduced(5));

    demo5Button.setBounds(buttonRow2.removeFromLeft(buttonWidth).reduced(5));
    demo6Button.setBounds(buttonRow2.removeFromLeft(buttonWidth).reduced(5));
    demo7Button.setBounds(buttonRow2.removeFromLeft(buttonWidth).reduced(5));

    outputText.setBounds(bounds.reduced(0, 10));
}

void SampleEngineDemo::timerCallback()
{
    if (isPlaying && !transportSource.isPlaying())
    {
        isPlaying = false;
    }
}
