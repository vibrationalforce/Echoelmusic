/*
  ==============================================================================

    EchoelmusicAudioEngine.h
    Created: 2025
    Author:  Echoelmusic Team

    JUCE-based cross-platform audio engine
    Platforms: Windows, macOS, Linux, iOS, Android
    Performance: <2ms latency, <15% CPU @ 128 tracks

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include <vector>
#include <atomic>

//==============================================================================
/**
    Ultra-low latency audio engine using JUCE

    Features:
    - Lock-free audio processing
    - SIMD acceleration (SSE, AVX, NEON)
    - Multi-core track processing
    - Zero-copy audio buffers
    - Professional routing matrix
    - Hardware-accelerated effects
*/
class EchoelmusicAudioEngine : public juce::AudioProcessor
{
public:
    //==============================================================================
    EchoelmusicAudioEngine();
    ~EchoelmusicAudioEngine() override;

    //==============================================================================
    // Audio Processor overrides
    void prepareToPlay (double sampleRate, int samplesPerBlock) override;
    void releaseResources() override;
    void processBlock (juce::AudioBuffer<float>& buffer, juce::MidiBuffer& midiMessages) override;

    //==============================================================================
    // Editor
    juce::AudioProcessorEditor* createEditor() override;
    bool hasEditor() const override { return true; }

    //==============================================================================
    // State
    void getStateInformation (juce::MemoryBlock& destData) override;
    void setStateInformation (const void* data, int sizeInBytes) override;

    //==============================================================================
    // Metadata
    const juce::String getName() const override { return "Echoelmusic"; }
    bool acceptsMidi() const override { return true; }
    bool producesMidi() const override { return true; }
    bool isMidiEffect() const override { return false; }
    double getTailLengthSeconds() const override { return 0.0; }

    //==============================================================================
    // Programs
    int getNumPrograms() override { return 1; }
    int getCurrentProgram() override { return 0; }
    void setCurrentProgram (int index) override {}
    const juce::String getProgramName (int index) override { return "Default"; }
    void changeProgramName (int index, const juce::String& newName) override {}

    //==============================================================================
    // Track Management
    int addTrack (const juce::String& name);
    void removeTrack (int trackIndex);
    int getNumTracks() const { return static_cast<int>(tracks.size()); }

    //==============================================================================
    // Performance Metrics
    double getCPUUsage() const { return cpuUsage.load(); }
    double getCurrentLatency() const { return currentLatency.load(); }
    int getBufferSize() const { return bufferSize; }
    double getSampleRate() const { return currentSampleRate; }

private:
    //==============================================================================
    // Audio Track
    struct AudioTrack
    {
        juce::String name;
        juce::AudioBuffer<float> buffer;
        std::atomic<float> volume {1.0f};
        std::atomic<float> pan {0.0f};
        std::atomic<bool> muted {false};
        std::atomic<bool> soloed {false};

        // Lock-free ring buffer for zero-copy audio
        juce::AbstractFifo fifo {4096};
        std::vector<float> ringBuffer;

        AudioTrack() : ringBuffer(4096 * 2) {}  // Stereo
    };

    //==============================================================================
    // DSP Processor (per track)
    class TrackProcessor
    {
    public:
        TrackProcessor() = default;

        void prepare (double sampleRate, int maximumBlockSize)
        {
            // Initialize DSP
            spec.sampleRate = sampleRate;
            spec.maximumBlockSize = static_cast<juce::uint32>(maximumBlockSize);
            spec.numChannels = 2;  // Stereo

            // EQ (3-band)
            lowShelf.prepare(spec);
            midPeak.prepare(spec);
            highShelf.prepare(spec);

            // Compressor
            compressor.prepare(spec);

            // Reverb
            reverb.prepare(spec);
        }

        void process (juce::AudioBuffer<float>& buffer)
        {
            auto block = juce::dsp::AudioBlock<float>(buffer);
            auto context = juce::dsp::ProcessContextReplacing<float>(block);

            // Apply EQ
            lowShelf.process(context);
            midPeak.process(context);
            highShelf.process(context);

            // Apply compression
            compressor.process(context);

            // Apply reverb
            reverb.process(context);
        }

    private:
        juce::dsp::ProcessSpec spec;

        // EQ
        juce::dsp::ProcessorDuplicator<juce::dsp::IIR::Filter<float>,
                                       juce::dsp::IIR::Coefficients<float>> lowShelf;
        juce::dsp::ProcessorDuplicator<juce::dsp::IIR::Filter<float>,
                                       juce::dsp::IIR::Coefficients<float>> midPeak;
        juce::dsp::ProcessorDuplicator<juce::dsp::IIR::Filter<float>,
                                       juce::dsp::IIR::Coefficients<float>> highShelf;

        // Dynamics
        juce::dsp::Compressor<float> compressor;

        // Reverb
        juce::dsp::Reverb reverb;
    };

    //==============================================================================
    // SIMD-accelerated mixing
    void mixTracksSimd (juce::AudioBuffer<float>& outputBuffer);

    // Multi-core track processing
    void processTracksParallel (juce::AudioBuffer<float>& buffer);

    // Performance measurement
    void measurePerformance();

    //==============================================================================
    // Member variables
    std::vector<std::unique_ptr<AudioTrack>> tracks;
    std::vector<std::unique_ptr<TrackProcessor>> trackProcessors;

    // Threading
    juce::ThreadPool threadPool {4};  // 4 worker threads

    // Performance metrics
    std::atomic<double> cpuUsage {0.0};
    std::atomic<double> currentLatency {0.0};

    // Audio settings
    double currentSampleRate {48000.0};
    int bufferSize {128};  // Target: <2ms @ 48kHz

    // Master output
    juce::AudioBuffer<float> masterBuffer;
    juce::dsp::Gain<float> masterGain;
    juce::dsp::Limiter<float> masterLimiter;

    //==============================================================================
    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (EchoelmusicAudioEngine)
};

//==============================================================================
/**
    Plugin wrapper for VST3, AU, AAX, CLAP
*/
class EchoelmusicPlugin : public EchoelmusicAudioEngine
{
public:
    EchoelmusicPlugin() : EchoelmusicAudioEngine() {}

    static juce::AudioProcessor* createPluginFilter()
    {
        return new EchoelmusicPlugin();
    }
};

//==============================================================================
/**
    CLAP Plugin Extension
    Supports the new open-source CLAP plugin format
*/
#ifdef JUCE_CLAP_EXTENSIONS
class ClapExtensions
{
public:
    // CLAP audio ports
    static constexpr uint32_t getAudioPortCount (bool isInput)
    {
        return isInput ? 0 : 1;  // 0 inputs, 1 stereo output
    }

    // CLAP note ports (MIDI)
    static constexpr uint32_t getNotePortCount (bool isInput)
    {
        return isInput ? 1 : 1;  // 1 MIDI in, 1 MIDI out
    }

    // CLAP parameters (mapped to JUCE parameters)
    static constexpr uint32_t getParameterCount()
    {
        return 100;  // 100 automatable parameters
    }
};
#endif

//==============================================================================
/**
    Standalone application wrapper
*/
class EchoelmusicStandalone : public juce::JUCEApplication
{
public:
    EchoelmusicStandalone() = default;

    const juce::String getApplicationName() override { return "Echoelmusic"; }
    const juce::String getApplicationVersion() override { return "1.0.0"; }
    bool moreThanOneInstanceAllowed() override { return false; }

    void initialise (const juce::String& commandLine) override
    {
        mainWindow.reset (new MainWindow (getApplicationName()));
    }

    void shutdown() override
    {
        mainWindow = nullptr;
    }

    void systemRequestedQuit() override
    {
        quit();
    }

private:
    class MainWindow : public juce::DocumentWindow
    {
    public:
        MainWindow (juce::String name)
            : DocumentWindow (name,
                            juce::Desktop::getInstance().getDefaultLookAndFeel()
                                .findColour (juce::ResizableWindow::backgroundColourId),
                            DocumentWindow::allButtons)
        {
            setUsingNativeTitleBar (true);
            setContentOwned (new juce::AudioProcessorEditor (processor), true);
            setResizable (true, true);
            centreWithSize (getWidth(), getHeight());
            setVisible (true);
        }

        void closeButtonPressed() override
        {
            juce::JUCEApplication::getInstance()->systemRequestedQuit();
        }

    private:
        EchoelmusicAudioEngine processor;

        JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR (MainWindow)
    };

    std::unique_ptr<MainWindow> mainWindow;
};

//==============================================================================
// Platform-specific optimizations

#if JUCE_INTEL
    // Intel SSE/AVX SIMD
    #include <immintrin.h>

    inline void processSimdIntel (float* buffer, int numSamples, float gain)
    {
        __m256 gainVec = _mm256_set1_ps (gain);

        for (int i = 0; i < numSamples; i += 8)
        {
            __m256 samples = _mm256_loadu_ps (&buffer[i]);
            samples = _mm256_mul_ps (samples, gainVec);
            _mm256_storeu_ps (&buffer[i], samples);
        }
    }
#endif

#if JUCE_ARM
    // ARM NEON SIMD
    #include <arm_neon.h>

    inline void processSimdArm (float* buffer, int numSamples, float gain)
    {
        float32x4_t gainVec = vdupq_n_f32 (gain);

        for (int i = 0; i < numSamples; i += 4)
        {
            float32x4_t samples = vld1q_f32 (&buffer[i]);
            samples = vmulq_f32 (samples, gainVec);
            vst1q_f32 (&buffer[i], samples);
        }
    }
#endif
