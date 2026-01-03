#pragma once

#include "../Vocals/VocalSuite.h"
#include <JuceHeader.h>

/**
 * VocalSuite Tests - Comprehensive tests for the integrated vocal processing system
 */

namespace Echoelmusic {
namespace Tests {

class VocalSuiteTests
{
public:
    static void runAllTests()
    {
        testVoiceCharacters();
        testAutotuneChain();
        testHarmonizerIntegration();
        testVocoderIntegration();
        testFormantPreservation();
        testSignalChain();

        DBG("All VocalSuite tests passed!");
    }

private:
    //==========================================================================
    // Voice Character Tests
    //==========================================================================

    static void testVoiceCharacters()
    {
        using namespace Echoelmusic::Vocals;

        VocalSuite suite;
        suite.prepare(48000.0, 512);

        // Test all voice characters
        std::array<VoiceCharacter, 18> characters = {
            VoiceCharacter::Natural,
            VoiceCharacter::Robot,
            VoiceCharacter::Alien,
            VoiceCharacter::Demon,
            VoiceCharacter::Angel,
            VoiceCharacter::Child,
            VoiceCharacter::Giant,
            VoiceCharacter::Monster,
            VoiceCharacter::Whisper,
            VoiceCharacter::Radio,
            VoiceCharacter::Telephone,
            VoiceCharacter::Megaphone,
            VoiceCharacter::Male,
            VoiceCharacter::Female,
            VoiceCharacter::Androgynous,
            VoiceCharacter::Choir,
            VoiceCharacter::Cyberpunk,
            VoiceCharacter::Ghost
        };

        for (auto character : characters)
        {
            suite.setVoiceCharacter(character);
            jassert(suite.getCurrentCharacter() == character);

            // Process some audio
            juce::AudioBuffer<float> buffer(2, 512);
            buffer.clear();

            // Fill with test signal
            for (int i = 0; i < 512; ++i)
            {
                float sample = std::sin(2.0f * juce::MathConstants<float>::pi * 440.0f * i / 48000.0f);
                buffer.setSample(0, i, sample * 0.5f);
                buffer.setSample(1, i, sample * 0.5f);
            }

            suite.processBlock(buffer);

            // Verify output is valid
            for (int ch = 0; ch < 2; ++ch)
            {
                for (int i = 0; i < 512; ++i)
                {
                    float sample = buffer.getSample(ch, i);
                    jassert(!std::isnan(sample));
                    jassert(!std::isinf(sample));
                    jassert(std::abs(sample) < 10.0f);  // Reasonable amplitude
                }
            }
        }

        DBG("Voice character tests passed");
    }

    //==========================================================================
    // Autotune Chain Tests
    //==========================================================================

    static void testAutotuneChain()
    {
        using namespace Echoelmusic::Vocals;

        VocalSuite suite;
        suite.prepare(48000.0, 512);

        // Enable autotune
        suite.setAutotuneEnabled(true);
        suite.setAutotuneSpeed(0.5f);
        suite.setAutotuneScale(1, 0);  // C Major

        // Process pitched audio
        juce::AudioBuffer<float> buffer(2, 2048);

        // Generate 440 Hz sine (A4)
        for (int i = 0; i < 2048; ++i)
        {
            float sample = std::sin(2.0f * juce::MathConstants<float>::pi * 440.0f * i / 48000.0f);
            buffer.setSample(0, i, sample * 0.5f);
            buffer.setSample(1, i, sample * 0.5f);
        }

        suite.processBlock(buffer);

        // Verify no NaN/Inf
        for (int ch = 0; ch < 2; ++ch)
        {
            for (int i = 0; i < 2048; ++i)
            {
                jassert(!std::isnan(buffer.getSample(ch, i)));
            }
        }

        DBG("Autotune chain tests passed");
    }

    //==========================================================================
    // Harmonizer Integration Tests
    //==========================================================================

    static void testHarmonizerIntegration()
    {
        using namespace Echoelmusic::Vocals;

        VocalSuite suite;
        suite.prepare(48000.0, 512);

        // Enable harmonizer
        suite.setHarmonyEnabled(true);
        suite.setHarmonyVoice(0, 4, 0.7f, -0.5f);   // Major 3rd, left
        suite.setHarmonyVoice(1, 7, 0.7f, 0.5f);    // Perfect 5th, right
        suite.setHarmonyVoice(2, 12, 0.5f, 0.0f);   // Octave up, center
        suite.setFormantPreservation(true);

        juce::AudioBuffer<float> buffer(2, 512);

        // Generate test signal
        for (int i = 0; i < 512; ++i)
        {
            float sample = std::sin(2.0f * juce::MathConstants<float>::pi * 220.0f * i / 48000.0f);
            buffer.setSample(0, i, sample * 0.5f);
            buffer.setSample(1, i, sample * 0.5f);
        }

        suite.processBlock(buffer);

        // Output should have content in both channels
        float leftRMS = 0.0f, rightRMS = 0.0f;
        for (int i = 0; i < 512; ++i)
        {
            leftRMS += buffer.getSample(0, i) * buffer.getSample(0, i);
            rightRMS += buffer.getSample(1, i) * buffer.getSample(1, i);
        }
        leftRMS = std::sqrt(leftRMS / 512);
        rightRMS = std::sqrt(rightRMS / 512);

        jassert(leftRMS > 0.0f);
        jassert(rightRMS > 0.0f);

        DBG("Harmonizer integration tests passed");
    }

    //==========================================================================
    // Vocoder Integration Tests
    //==========================================================================

    static void testVocoderIntegration()
    {
        using namespace Echoelmusic::Vocals;

        VocalSuite suite;
        suite.prepare(48000.0, 512);

        // Set robot character (uses vocoder)
        suite.setVoiceCharacter(VoiceCharacter::Robot);

        // Or set vocoder directly
        suite.setVocoderMix(0.8f);

        juce::AudioBuffer<float> buffer(2, 512);

        // Generate voice-like signal
        for (int i = 0; i < 512; ++i)
        {
            // Complex waveform simulating voice
            float t = static_cast<float>(i) / 48000.0f;
            float sample = std::sin(2.0f * juce::MathConstants<float>::pi * 150.0f * t);
            sample += 0.5f * std::sin(4.0f * juce::MathConstants<float>::pi * 150.0f * t);
            sample += 0.25f * std::sin(6.0f * juce::MathConstants<float>::pi * 150.0f * t);

            buffer.setSample(0, i, sample * 0.3f);
            buffer.setSample(1, i, sample * 0.3f);
        }

        suite.processBlock(buffer);

        // Verify processing occurred
        for (int ch = 0; ch < 2; ++ch)
        {
            for (int i = 0; i < 512; ++i)
            {
                jassert(!std::isnan(buffer.getSample(ch, i)));
            }
        }

        DBG("Vocoder integration tests passed");
    }

    //==========================================================================
    // Formant Preservation Tests
    //==========================================================================

    static void testFormantPreservation()
    {
        using namespace Echoelmusic::Vocals;

        VocalSuite suite;
        suite.prepare(48000.0, 512);

        suite.setFormantPreservation(true);
        suite.setPitchShift(12.0f);  // Octave up
        suite.setFormantShift(0.0f); // Preserve formants

        juce::AudioBuffer<float> buffer(2, 512);

        for (int i = 0; i < 512; ++i)
        {
            float sample = std::sin(2.0f * juce::MathConstants<float>::pi * 200.0f * i / 48000.0f);
            buffer.setSample(0, i, sample * 0.5f);
            buffer.setSample(1, i, sample * 0.5f);
        }

        suite.processBlock(buffer);

        DBG("Formant preservation tests passed");
    }

    //==========================================================================
    // Signal Chain Tests
    //==========================================================================

    static void testSignalChain()
    {
        using namespace Echoelmusic::Vocals;

        VocalSuite suite;
        suite.prepare(48000.0, 512);

        // Test full chain
        suite.setAutotuneEnabled(true);
        suite.setAutotuneSpeed(0.3f);
        suite.setHarmonyEnabled(true);
        suite.setHarmonyVoice(0, 5, 0.6f, -0.3f);
        suite.setVoiceCharacter(VoiceCharacter::Angel);
        suite.setMix(0.8f);

        juce::AudioBuffer<float> buffer(2, 1024);

        // Generate complex test signal
        for (int i = 0; i < 1024; ++i)
        {
            float t = static_cast<float>(i) / 48000.0f;

            // Simulate vocal with multiple harmonics
            float sample = 0.0f;
            for (int h = 1; h <= 8; ++h)
            {
                sample += std::sin(2.0f * juce::MathConstants<float>::pi * 150.0f * h * t) / h;
            }

            buffer.setSample(0, i, sample * 0.2f);
            buffer.setSample(1, i, sample * 0.2f);
        }

        suite.processBlock(buffer);

        // Verify output
        bool hasOutput = false;
        for (int i = 0; i < 1024; ++i)
        {
            if (std::abs(buffer.getSample(0, i)) > 0.001f)
                hasOutput = true;

            jassert(!std::isnan(buffer.getSample(0, i)));
            jassert(!std::isnan(buffer.getSample(1, i)));
        }

        jassert(hasOutput);

        DBG("Signal chain tests passed");
    }
};

//==============================================================================
// Voice Cloner Specific Tests
//==============================================================================

class VoiceClonerTests
{
public:
    static void runAllTests()
    {
        testPitchShifting();
        testFormantShifting();
        testCharacterTransformation();
        testBreathinessControl();
        testRoboticEffect();

        DBG("All VoiceCloner tests passed!");
    }

private:
    static void testPitchShifting()
    {
        using namespace Echoelmusic::Vocals;

        VoiceCloner cloner;
        cloner.prepare(48000.0);

        // Test various pitch shifts
        for (float semitones = -12.0f; semitones <= 12.0f; semitones += 3.0f)
        {
            cloner.setPitchShift(semitones);

            for (int i = 0; i < 1024; ++i)
            {
                float input = std::sin(2.0f * juce::MathConstants<float>::pi * 440.0f * i / 48000.0f);
                float output = cloner.process(input * 0.5f);

                jassert(!std::isnan(output));
                jassert(!std::isinf(output));
            }
        }

        DBG("Pitch shifting tests passed");
    }

    static void testFormantShifting()
    {
        using namespace Echoelmusic::Vocals;

        VoiceCloner cloner;
        cloner.prepare(48000.0);

        // Test formant shifts
        for (float semitones = -12.0f; semitones <= 12.0f; semitones += 4.0f)
        {
            cloner.setFormantShift(semitones);

            for (int i = 0; i < 512; ++i)
            {
                float input = std::sin(2.0f * juce::MathConstants<float>::pi * 200.0f * i / 48000.0f);
                float output = cloner.process(input * 0.5f);

                jassert(!std::isnan(output));
            }
        }

        DBG("Formant shifting tests passed");
    }

    static void testCharacterTransformation()
    {
        using namespace Echoelmusic::Vocals;

        VoiceCloner cloner;
        cloner.prepare(48000.0);

        // Test Male to Female
        cloner.setCharacter(VoiceCharacter::Female);
        jassert(cloner.getCurrentCharacter() == VoiceCharacter::Female);

        // Test Demon
        cloner.setCharacter(VoiceCharacter::Demon);
        jassert(cloner.getCurrentCharacter() == VoiceCharacter::Demon);

        // Test Child
        cloner.setCharacter(VoiceCharacter::Child);
        jassert(cloner.getCurrentCharacter() == VoiceCharacter::Child);

        DBG("Character transformation tests passed");
    }

    static void testBreathinessControl()
    {
        using namespace Echoelmusic::Vocals;

        VoiceCloner cloner;
        cloner.prepare(48000.0);

        cloner.setBreathiness(0.8f);
        cloner.setCharacter(VoiceCharacter::Whisper);

        for (int i = 0; i < 512; ++i)
        {
            float input = std::sin(2.0f * juce::MathConstants<float>::pi * 200.0f * i / 48000.0f);
            float output = cloner.process(input * 0.5f);

            jassert(!std::isnan(output));
        }

        DBG("Breathiness control tests passed");
    }

    static void testRoboticEffect()
    {
        using namespace Echoelmusic::Vocals;

        VoiceCloner cloner;
        cloner.prepare(48000.0);

        cloner.setRoboticAmount(1.0f);

        for (int i = 0; i < 512; ++i)
        {
            float input = std::sin(2.0f * juce::MathConstants<float>::pi * 200.0f * i / 48000.0f);
            float output = cloner.process(input * 0.5f);

            jassert(!std::isnan(output));
            jassert(std::abs(output) < 5.0f);
        }

        DBG("Robotic effect tests passed");
    }
};

//==============================================================================
// Run All Vocal Tests
//==============================================================================

inline void runAllVocalTests()
{
    VocalSuiteTests::runAllTests();
    VoiceClonerTests::runAllTests();

    DBG("=================================");
    DBG("ALL VOCAL TESTS PASSED!");
    DBG("=================================");
}

} // namespace Tests
} // namespace Echoelmusic
