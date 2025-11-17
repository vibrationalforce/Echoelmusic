#include <JuceHeader.h>
#include "../Sources/Visualization/MasterFrequencyTransformer.h"

//==============================================================================
/**
 * @brief MASTER FREQUENCY TRANSFORMER VALIDATION TESTS
 *
 * Comprehensive unit tests for precision multi-source transformation.
 *
 * Tests verify:
 * - Custom A4 tuning precision (3 decimals)
 * - BPM precision (3 decimals)
 * - Multi-source frequency aggregation
 * - Precise piano mapping with microtonality
 * - Extended color spaces (RGB, HSV, LAB)
 * - Quantum properties calculation
 */
class MasterFrequencyTransformerTests : public juce::UnitTest
{
public:
    MasterFrequencyTransformerTests()
        : juce::UnitTest("Master Frequency Transformer", "Echoelmusic")
    {
    }

    void runTest() override
    {
        testCustomA4Precision();
        testBPMPrecision();
        testMultiSourceIntegration();
        testPrecisePianoMapping();
        testColorSpaces();
        testQuantumProperties();
        testHistoricalTunings();
        testMicrotonalAccuracy();
    }

private:
    //==============================================================================
    // TEST: Custom A4 Precision (3 Decimals)
    //==============================================================================

    void testCustomA4Precision()
    {
        beginTest("Custom A4 Tuning Precision (3 Decimals)");

        // Test standard tunings
        testA4Tuning(440.000, "Modern Standard");
        testA4Tuning(432.000, "Verdi Tuning");
        testA4Tuning(415.305, "Baroque German");
        testA4Tuning(392.000, "Baroque French");

        // Test extreme precision
        testA4Tuning(440.123, "Custom 1");
        testA4Tuning(441.789, "Custom 2");
        testA4Tuning(439.456, "Custom 3");
    }

    void testA4Tuning(double customA4, const juce::String& description)
    {
        auto result = MasterFrequencyTransformer::transformAllSources(
            customA4,      // Audio = A4
            120.0,         // BPM
            0.1,           // HRV
            {2.0, 6.0, 10.0, 20.0, 40.0},  // EEG
            customA4       // Custom A4
        );

        // Verify custom A4 is preserved
        expectWithinAbsoluteError(result.customA4_Hz, customA4, 0.001,
                                 description + ": Custom A4 preserved");

        // Verify A4 maps to piano key 49 (with possible microtonality)
        expectWithinAbsoluteError(result.exactPianoKey, 49.0, 0.1,
                                 description + ": A4 = Piano Key 49");

        logMessage(description + ": A4 = " + juce::String(customA4, 3) +
                  " Hz → Key " + juce::String(result.exactPianoKey, 3));
    }

    //==============================================================================
    // TEST: BPM Precision (3 Decimals)
    //==============================================================================

    void testBPMPrecision()
    {
        beginTest("BPM Precision (3 Decimals)");

        // Test standard BPMs
        testBPM(120.000, "Standard");
        testBPM(128.000, "Dance");
        testBPM(174.000, "Drum & Bass");

        // Test extreme precision
        testBPM(120.123, "Precise 1");
        testBPM(128.456, "Precise 2");
        testBPM(174.789, "Precise 3");

        // Test extremes
        testBPM(0.001, "Extremely Slow");
        testBPM(999.999, "Extremely Fast");
    }

    void testBPM(double bpm, const juce::String& description)
    {
        auto result = MasterFrequencyTransformer::transformAllSources(
            440.0,
            bpm,
            0.1,
            {2.0, 6.0, 10.0, 20.0, 40.0},
            440.0
        );

        // Verify BPM is preserved
        expectWithinAbsoluteError(result.bpm, bpm, 0.001,
                                 description + ": BPM preserved");

        // Verify BPM → Frequency conversion
        double expectedFreq = bpm / 60.0;
        expectWithinAbsoluteError(result.bpmFrequency_Hz, expectedFreq, 0.001,
                                 description + ": BPM → Frequency");

        logMessage(description + ": BPM " + juce::String(bpm, 3) +
                  " → " + juce::String(result.bpmFrequency_Hz, 3) + " Hz");
    }

    //==============================================================================
    // TEST: Multi-Source Integration
    //==============================================================================

    void testMultiSourceIntegration()
    {
        beginTest("Multi-Source Frequency Integration");

        double audio = 440.0;
        double bpm = 120.123;
        double hrv = 0.1;
        std::array<double, 5> eeg = {2.0, 6.0, 10.0, 20.0, 40.0};

        auto result = MasterFrequencyTransformer::transformAllSources(
            audio, bpm, hrv, eeg, 440.0
        );

        // Verify all sources are captured
        expect(result.audioFrequency_Hz > 0, "Audio frequency captured");
        expect(result.bpmFrequency_Hz > 0, "BPM frequency captured");
        expect(result.hrvFrequency_Hz > 0, "HRV frequency captured");

        expect(result.eeg.delta > 0, "Delta EEG captured");
        expect(result.eeg.theta > 0, "Theta EEG captured");
        expect(result.eeg.alpha > 0, "Alpha EEG captured");
        expect(result.eeg.beta > 0, "Beta EEG captured");
        expect(result.eeg.gamma > 0, "Gamma EEG captured");

        // Verify dominant frequency selection
        expect(result.dominantFrequency_Hz > 0, "Dominant frequency selected");

        logMessage("Multi-source integration successful");
        logMessage("Dominant frequency: " + juce::String(result.dominantFrequency_Hz, 3) + " Hz");
    }

    //==============================================================================
    // TEST: Precise Piano Mapping
    //==============================================================================

    void testPrecisePianoMapping()
    {
        beginTest("Precise Piano Mapping (Microtonality)");

        // Test exact semitones (should have ~0 cents deviation)
        testPianoKey(440.000, 440.0, 49.0, 0.0, "A4 exact");
        testPianoKey(261.626, 440.0, 40.0, 0.0, "C4 exact");

        // Test microtonal deviations
        testPianoKey(440.0 * std::pow(2.0, 0.25 / 12.0), 440.0, 49.25, 25.0, "A4 + 25 cents");
        testPianoKey(440.0 * std::pow(2.0, -0.25 / 12.0), 440.0, 48.75, -25.0, "A4 - 25 cents");

        // Test with custom A4
        testPianoKey(432.000, 432.0, 49.0, 0.0, "A4 in 432 Hz tuning");
    }

    void testPianoKey(double freq, double customA4, double expectedKey,
                      double expectedCents, const juce::String& description)
    {
        auto result = MasterFrequencyTransformer::transformAllSources(
            freq, 120.0, 0.1, {2.0, 6.0, 10.0, 20.0, 40.0}, customA4
        );

        // Verify piano key
        expectWithinAbsoluteError(result.exactPianoKey, expectedKey, 0.1,
                                 description + ": Piano key");

        // Verify cents deviation
        expectWithinAbsoluteError(result.centsDeviation, expectedCents, 5.0,
                                 description + ": Cents deviation");

        logMessage(description + ": Key " + juce::String(result.exactPianoKey, 3) +
                  ", " + juce::String(result.centsDeviation, 3) + " cents");
    }

    //==============================================================================
    // TEST: Color Spaces (RGB, HSV, LAB)
    //==============================================================================

    void testColorSpaces()
    {
        beginTest("Extended Color Spaces (RGB, HSV, LAB)");

        auto result = MasterFrequencyTransformer::transformAllSources(
            440.0, 120.0, 0.1, {2.0, 6.0, 10.0, 20.0, 40.0}, 440.0
        );

        // RGB validation
        expect(result.r >= 0.0 && result.r <= 1.0, "RGB R in range");
        expect(result.g >= 0.0 && result.g <= 1.0, "RGB G in range");
        expect(result.b >= 0.0 && result.b <= 1.0, "RGB B in range");

        // HSV validation
        expect(result.h >= 0.0 && result.h < 360.0, "HSV H in range");
        expect(result.s >= 0.0 && result.s <= 1.0, "HSV S in range");
        expect(result.v >= 0.0 && result.v <= 1.0, "HSV V in range");

        // LAB validation
        expect(result.L >= 0.0 && result.L <= 100.0, "LAB L in range");
        expect(result.a_star >= -128.0 && result.a_star <= 127.0, "LAB a* in range");
        expect(result.b_star >= -128.0 && result.b_star <= 127.0, "LAB b* in range");

        logMessage(juce::String::formatted("RGB: (%.3f, %.3f, %.3f)", result.r, result.g, result.b));
        logMessage(juce::String::formatted("HSV: (%.1f, %.3f, %.3f)", result.h, result.s, result.v));
        logMessage(juce::String::formatted("LAB: (%.1f, %.1f, %.1f)", result.L, result.a_star, result.b_star));
    }

    //==============================================================================
    // TEST: Quantum Properties
    //==============================================================================

    void testQuantumProperties()
    {
        beginTest("Quantum Properties Calculation");

        auto result = MasterFrequencyTransformer::transformAllSources(
            440.0, 120.0, 0.1, {2.0, 6.0, 10.0, 20.0, 40.0}, 440.0
        );

        // Photon energy should be positive and reasonable
        expect(result.photonEnergy_eV > 0.0, "Photon energy positive");
        expect(result.photonEnergy_eV < 10.0, "Photon energy reasonable (< 10 eV)");

        // Quantum coherence should be 0-1
        expect(result.quantumCoherence >= 0.0 && result.quantumCoherence <= 1.0,
               "Quantum coherence in range");

        // Planck units should be extremely small
        expect(result.planckUnits > 0.0, "Planck units positive");
        expect(result.planckUnits < 1.0, "Planck units < 1");

        logMessage("Photon Energy: " + juce::String(result.photonEnergy_eV, 3) + " eV");
        logMessage("Quantum Coherence: " + juce::String(result.quantumCoherence, 3));
        logMessage("Planck Units: " + juce::String(result.planckUnits, 2, true));
    }

    //==============================================================================
    // TEST: Historical Tunings
    //==============================================================================

    void testHistoricalTunings()
    {
        beginTest("Historical Tuning Standards");

        struct TuningStandard
        {
            double a4;
            juce::String name;
        };

        const TuningStandard standards[] = {
            {440.000, "Modern Standard"},
            {432.000, "Verdi Tuning"},
            {430.539, "Scientific Pitch"},
            {392.000, "Baroque French"},
            {415.305, "Baroque German"},
            {443.000, "Berlin Philharmonic"},
            {444.000, "Vienna Philharmonic"},
            {442.000, "New York Philharmonic"}
        };

        for (const auto& standard : standards)
        {
            auto result = MasterFrequencyTransformer::transformAllSources(
                standard.a4, 120.0, 0.1, {2.0, 6.0, 10.0, 20.0, 40.0}, standard.a4
            );

            expectWithinAbsoluteError(result.customA4_Hz, standard.a4, 0.001,
                                     standard.name + " A4 preserved");

            logMessage(standard.name + ": A4 = " + juce::String(standard.a4, 3) + " Hz");
        }
    }

    //==============================================================================
    // TEST: Microtonal Accuracy
    //==============================================================================

    void testMicrotonalAccuracy()
    {
        beginTest("Microtonal Accuracy (Sub-Cent Resolution)");

        // Test frequencies between semitones
        for (int cents = -50; cents <= 50; cents += 10)
        {
            double freq = 440.0 * std::pow(2.0, cents / 1200.0);

            auto result = MasterFrequencyTransformer::transformAllSources(
                freq, 120.0, 0.1, {2.0, 6.0, 10.0, 20.0, 40.0}, 440.0
            );

            // Verify cents calculation
            expectWithinAbsoluteError(result.centsDeviation, static_cast<double>(cents), 1.0,
                                     juce::String(cents) + " cents accuracy");

            if (cents % 20 == 0)  // Log every 20 cents
            {
                logMessage(juce::String(cents) + " cents: " +
                          juce::String(freq, 3) + " Hz → " +
                          result.noteName);
            }
        }
    }
};

// Register test
static MasterFrequencyTransformerTests masterFrequencyTransformerTests;
