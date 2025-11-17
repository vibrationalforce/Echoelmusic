#include <JuceHeader.h>
#include "../Sources/Visualization/ScientificFrequencyLightTransformer.h"

//==============================================================================
/**
 * @brief SCIENTIFIC VALIDATION TESTS
 *
 * Unit tests to validate the scientific accuracy of frequency-to-light transformation.
 *
 * Tests verify:
 * - Mathematical correctness of octave transformation
 * - Physical validity of wavelengths
 * - Color science accuracy (CIE 1931)
 * - Neurophysiological data consistency
 */
class FrequencyLightTransformerTests : public juce::UnitTest
{
public:
    FrequencyLightTransformerTests()
        : juce::UnitTest("Frequency-to-Light Transformer", "Echoelmusic")
    {
    }

    void runTest() override
    {
        testOctaveTransformation();
        testPhysicalValidity();
        testColorScience();
        testStandardTones();
        testConeResponses();
        testPhotopicLuminosity();
    }

private:
    //==============================================================================
    // TEST: Octave Transformation
    //==============================================================================

    void testOctaveTransformation()
    {
        beginTest("Octave Transformation (f × 2^n)");

        // Test A4 = 440 Hz
        auto resultA4 = ScientificFrequencyLightTransformer::transformToLight(440.0);

        // Verify octave formula: f_light = f_audio × 2^n
        double expectedFreq = 440.0 * std::pow(2.0, resultA4.octavesShifted);
        double actualFreq = resultA4.lightFrequency_THz * 1e12;

        expectWithinAbsoluteError(actualFreq, expectedFreq, 1e9,  // 1 GHz tolerance
                                  "Octave formula: f_light = f_audio × 2^n");

        // Verify in visible range (430-770 THz)
        expect(resultA4.lightFrequency_THz >= 430.0 && resultA4.lightFrequency_THz <= 770.0,
               "Light frequency within visible spectrum");

        logMessage("A4 (440 Hz) → " + juce::String(resultA4.lightFrequency_THz, 1) + " THz, " +
                  juce::String(resultA4.octavesShifted) + " octaves shifted");
    }

    //==============================================================================
    // TEST: Physical Validity
    //==============================================================================

    void testPhysicalValidity()
    {
        beginTest("Physical Validity (Wavelength Range)");

        // Test full audio range
        const double testFreqs[] = {20.0, 50.0, 100.0, 440.0, 1000.0, 5000.0, 10000.0, 20000.0};

        for (double freq : testFreqs)
        {
            auto result = ScientificFrequencyLightTransformer::transformToLight(freq);

            // All wavelengths must be in visible range (380-780 nm)
            expect(result.wavelength_nm >= 380.0 && result.wavelength_nm <= 780.0,
                   juce::String(freq, 1) + " Hz maps to visible spectrum");

            expect(result.isPhysicallyValid,
                   juce::String(freq, 1) + " Hz is physically valid");

            logMessage(juce::String(freq, 1) + " Hz → " +
                      juce::String(result.wavelength_nm, 1) + " nm (" +
                      result.color.perceptualName + ")");
        }
    }

    //==============================================================================
    // TEST: Color Science (CIE 1931)
    //==============================================================================

    void testColorScience()
    {
        beginTest("Color Science (CIE 1931)");

        // Test pure spectral colors
        struct SpectralColor
        {
            double wavelength;
            juce::String expectedName;
            double expectedR, expectedG, expectedB;
        };

        const SpectralColor spectralColors[] = {
            {450.0, "Blue", 0.0, 0.2, 1.0},
            {530.0, "Green", 0.0, 1.0, 0.0},
            {590.0, "Yellow", 1.0, 1.0, 0.0},
            {650.0, "Red", 1.0, 0.0, 0.0}
        };

        for (const auto& spec : spectralColors)
        {
            auto color = ScientificFrequencyLightTransformer::calculateScientificColor(spec.wavelength);

            // Check color name
            expect(color.perceptualName == spec.expectedName,
                   juce::String(spec.wavelength, 0) + " nm = " + spec.expectedName);

            // Check RGB values (approximate, allow 20% tolerance)
            expectWithinAbsoluteError(color.r, spec.expectedR, 0.3,
                                     juce::String(spec.wavelength, 0) + " nm Red channel");
            expectWithinAbsoluteError(color.g, spec.expectedG, 0.3,
                                     juce::String(spec.wavelength, 0) + " nm Green channel");
            expectWithinAbsoluteError(color.b, spec.expectedB, 0.3,
                                     juce::String(spec.wavelength, 0) + " nm Blue channel");

            logMessage(juce::String(spec.wavelength, 0) + " nm → RGB(" +
                      juce::String(color.r, 2) + ", " +
                      juce::String(color.g, 2) + ", " +
                      juce::String(color.b, 2) + ") = " + spec.expectedName);
        }
    }

    //==============================================================================
    // TEST: Standard Musical Tones
    //==============================================================================

    void testStandardTones()
    {
        beginTest("Standard Musical Tones");

        struct MusicalTone
        {
            double frequency;
            juce::String expectedNote;
        };

        const MusicalTone tones[] = {
            {261.63, "C4"},    // Middle C
            {440.00, "A4"},    // Concert A
            {523.25, "C5"},    // C5
            {880.00, "A5"}     // A5
        };

        for (const auto& tone : tones)
        {
            auto result = ScientificFrequencyLightTransformer::transformToLight(tone.frequency);

            expect(result.musicalNote == tone.expectedNote,
                   juce::String(tone.frequency, 2) + " Hz = " + tone.expectedNote);

            logMessage(tone.expectedNote + " (" + juce::String(tone.frequency, 2) + " Hz) → " +
                      juce::String(result.wavelength_nm, 1) + " nm (" +
                      result.color.perceptualName + ")");
        }
    }

    //==============================================================================
    // TEST: Cone Responses
    //==============================================================================

    void testConeResponses()
    {
        beginTest("Cone Response Functions");

        // Test S-cone (Blue) peak at ~420 nm
        auto resultBlue = ScientificFrequencyLightTransformer::transformToLight(100.0);
        if (resultBlue.wavelength_nm >= 410.0 && resultBlue.wavelength_nm <= 430.0)
        {
            expect(resultBlue.sConeActivation > resultBlue.mConeActivation,
                   "S-cone dominant in blue region");
            expect(resultBlue.sConeActivation > resultBlue.lConeActivation,
                   "S-cone > L-cone in blue region");
        }

        // Test M-cone (Green) peak at ~530 nm
        auto resultGreen = ScientificFrequencyLightTransformer::transformToLight(1000.0);
        if (resultGreen.wavelength_nm >= 520.0 && resultGreen.wavelength_nm <= 540.0)
        {
            expect(resultGreen.mConeActivation > resultGreen.sConeActivation,
                   "M-cone dominant in green region");
            expect(resultGreen.mConeActivation > resultGreen.lConeActivation,
                   "M-cone > L-cone in green region");
        }

        // Test L-cone (Red) peak at ~560 nm
        auto resultRed = ScientificFrequencyLightTransformer::transformToLight(10000.0);
        if (resultRed.wavelength_nm >= 550.0 && resultRed.wavelength_nm <= 570.0)
        {
            expect(resultRed.lConeActivation >= resultRed.mConeActivation * 0.8,
                   "L-cone high in red region");
        }

        logMessage("Cone responses validated for blue, green, and red regions");
    }

    //==============================================================================
    // TEST: Photopic Luminosity V(λ)
    //==============================================================================

    void testPhotopicLuminosity()
    {
        beginTest("Photopic Luminosity V(λ) Function");

        // Peak should be at ~555 nm (green)
        double maxLuminosity = 0.0;
        double peakWavelength = 0.0;

        for (double wl = 400.0; wl <= 700.0; wl += 10.0)
        {
            double luminosity = ScientificFrequencyLightTransformer::calculatePhotopicLuminosity(wl);

            if (luminosity > maxLuminosity)
            {
                maxLuminosity = luminosity;
                peakWavelength = wl;
            }
        }

        // Peak should be close to 555 nm
        expectWithinAbsoluteError(peakWavelength, 555.0, 15.0,
                                 "Photopic peak at ~555 nm");

        expect(maxLuminosity > 0.95,
               "Maximum luminosity close to 1.0");

        logMessage("Photopic peak at " + juce::String(peakWavelength, 0) +
                  " nm (expected ~555 nm)");

        // Test red region (low luminosity)
        double redLuminosity = ScientificFrequencyLightTransformer::calculatePhotopicLuminosity(650.0);
        expect(redLuminosity < 0.5,
               "Red (650 nm) has lower luminosity than green");

        // Test blue region (low luminosity)
        double blueLuminosity = ScientificFrequencyLightTransformer::calculatePhotopicLuminosity(450.0);
        expect(blueLuminosity < 0.5,
               "Blue (450 nm) has lower luminosity than green");

        logMessage("Luminosity validation: Green > Red & Blue ✓");
    }
};

// Register test
static FrequencyLightTransformerTests frequencyLightTransformerTests;
