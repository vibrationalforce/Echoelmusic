#pragma once

#include <JuceHeader.h>
#include "ScientificFrequencyLightTransformer.h"
#include <array>
#include <cmath>

//==============================================================================
/**
 * @brief MASTER UNIVERSAL QUANTUM FREQUENCY TRANSFORMER
 *
 * 🌈 ULTIMATE PRECISION MULTI-SOURCE FREQUENCY-TO-VISUAL TRANSFORMER 🔬
 *
 * Combines ALL frequency sources into unified visual output:
 * - Audio (FFT analysis)
 * - BPM (with 3-decimal precision)
 * - Custom tuning references (3-decimal precision: 392.000 - 493.883 Hz)
 * - Heart Rate Variability (HRV)
 * - EEG bands (Delta, Theta, Alpha, Beta, Gamma)
 * - MIDI input
 * - Breathing rate
 *
 * **PRECISION FEATURES:**
 * - Custom concert pitch (A4) with 0.001 Hz precision
 * - BPM with 0.001 precision (0.001 - 999.999)
 * - Microtonal piano mapping with cent deviations
 * - Extended color spaces (RGB, HSV, LAB)
 * - Quantum properties (photon energy, Planck units)
 *
 * **SCIENTIFIC FOUNDATION:**
 * - Extends ScientificFrequencyLightTransformer
 * - Adds multi-source frequency aggregation
 * - Implements precise musical tuning systems
 * - Calculates quantum photon properties
 *
 * @author Echoelmusic Science Team
 * @version 2.0.0
 */
class MasterFrequencyTransformer
{
public:
    //==============================================================================
    // PRECISION CONSTANTS
    //==============================================================================

    struct PrecisionConstants
    {
        // Custom Concert Pitch (A4) - User-definable with 3-decimal precision
        static constexpr double MIN_A4 = 392.000;   // Baroque French
        static constexpr double MAX_A4 = 493.883;   // High pitch
        static constexpr double DEFAULT_A4 = 440.000;

        // Historical & Modern Tuning Standards (3-decimal precision)
        static constexpr double A4_VERDI = 432.000;           // Giuseppe Verdi's preferred
        static constexpr double A4_SCIENTIFIC = 430.539;      // C4 = 256 Hz exactly
        static constexpr double A4_BAROQUE_FRENCH = 392.000;  // French Baroque
        static constexpr double A4_BAROQUE_GERMAN = 415.305;  // German Baroque
        static constexpr double A4_CLASSICAL = 430.000;       // Classical period
        static constexpr double A4_BERLIN_PHIL = 443.000;     // Berlin Philharmonic
        static constexpr double A4_VIENNA_PHIL = 444.000;     // Vienna Philharmonic
        static constexpr double A4_NYC_PHIL = 442.000;        // New York Philharmonic
        static constexpr double A4_MOSCOW = 435.000;          // Moscow standard

        // BPM Precision (3 decimals)
        static constexpr double MIN_BPM = 0.001;
        static constexpr double MAX_BPM = 999.999;

        // Quantum & Planck Scale
        static constexpr double PLANCK_FREQUENCY = 1.855e43;  // Hz
        static constexpr double PLANCK_TIME = 5.391247e-44;   // seconds
        static constexpr double PLANCK_CONSTANT = 6.62607015e-34;  // J⋅s
    };

    //==============================================================================
    // UNIFIED FREQUENCY DATA STRUCTURE
    //==============================================================================

    struct UnifiedFrequencyData
    {
        // ===== INPUT SOURCES =====

        // Audio
        double audioFrequency_Hz = 440.000;

        // BPM (with 3-decimal precision)
        double bpm = 120.000;
        double bpmFrequency_Hz = 2.000;  // BPM / 60

        // MIDI
        double midiNoteFrequency_Hz = 0.0;
        int midiNoteNumber = 69;  // A4

        // Biometric Sources
        double hrvFrequency_Hz = 0.1;  // Heart Rate Variability (0.04-0.4 Hz typical)
        double heartRate_BPM = 60.0;
        double heartRateFrequency_Hz = 1.0;
        double breathingRate_BPM = 15.0;
        double breathingFrequency_Hz = 0.25;

        // EEG Bands (Hz)
        struct EEGBands
        {
            double delta = 2.0;   // 0.5-4 Hz (deep sleep)
            double theta = 6.0;   // 4-8 Hz (meditation)
            double alpha = 10.0;  // 8-13 Hz (relaxation)
            double beta = 20.0;   // 13-30 Hz (active thinking)
            double gamma = 40.0;  // 30-100 Hz (cognitive processing)
        } eeg;

        // ===== TRANSFORMATION =====

        // Custom tuning reference (3-decimal precision)
        double customA4_Hz = 440.000;

        // Dominant frequency (selected from all sources)
        double dominantFrequency_Hz = 440.000;

        // Octave transformation
        int octavesShifted = 40;
        double visualFrequency_THz = 484.0;
        double wavelength_nm = 620.0;

        // ===== COLOR SCIENCE =====

        // RGB [0.0 - 1.0]
        double r = 1.0, g = 0.5, b = 0.0;

        // HSV [H: 0-360, S/V: 0-1]
        double h = 30.0, s = 1.0, v = 1.0;

        // LAB Color Space [L: 0-100, a/b: -128 to 127]
        double L = 70.0, a_star = 50.0, b_star = 60.0;

        // ===== PRECISE PIANO MAPPING =====

        // Exact piano key with microtonality (1.000 - 88.000)
        double exactPianoKey = 49.000;  // A4 on 88-key piano

        // Note name with cent deviation
        juce::String noteName = "A4";
        double centsDeviation = 0.000;  // -50 to +50 cents

        // ===== QUANTUM PROPERTIES =====

        // Photon energy (eV) for visual frequency
        double photonEnergy_eV = 2.0;

        // Quantum coherence factor (0-1)
        double quantumCoherence = 0.5;

        // Planck units (normalized to Planck frequency)
        double planckUnits = 0.0;

        // ===== SCIENTIFIC VALIDATION =====

        bool isPhysicallyValid = true;
        std::vector<juce::String> references;
    };

    //==============================================================================
    // MAIN TRANSFORMATION (Multi-Source)
    //==============================================================================

    /**
     * @brief Transform all frequency sources into unified visual output
     *
     * @param audioFreq Audio frequency from FFT analysis (Hz)
     * @param bpm Beats per minute (0.001 - 999.999)
     * @param hrv Heart rate variability frequency (Hz)
     * @param eeg EEG band frequencies (Delta, Theta, Alpha, Beta, Gamma)
     * @param customA4 Custom concert pitch for A4 (392.000 - 493.883 Hz)
     * @return Complete unified frequency data with all transformations
     */
    static UnifiedFrequencyData transformAllSources(
        double audioFreq,
        double bpm,
        double hrv,
        const std::array<double, 5>& eegBands,
        double customA4 = PrecisionConstants::DEFAULT_A4)
    {
        UnifiedFrequencyData data;

        // Validate and clamp inputs
        data.customA4_Hz = juce::jlimit(PrecisionConstants::MIN_A4,
                                         PrecisionConstants::MAX_A4,
                                         customA4);

        data.bpm = juce::jlimit(PrecisionConstants::MIN_BPM,
                                PrecisionConstants::MAX_BPM,
                                bpm);

        // ===== PROCESS ALL SOURCES =====

        // Audio
        data.audioFrequency_Hz = audioFreq;

        // BPM → Frequency (precise)
        data.bpmFrequency_Hz = data.bpm / 60.0;

        // HRV
        data.hrvFrequency_Hz = hrv;

        // EEG Bands
        data.eeg.delta = eegBands[0];
        data.eeg.theta = eegBands[1];
        data.eeg.alpha = eegBands[2];
        data.eeg.beta = eegBands[3];
        data.eeg.gamma = eegBands[4];

        // ===== SELECT DOMINANT FREQUENCY =====
        data.dominantFrequency_Hz = selectDominantFrequency(data);

        // ===== OCTAVE TRANSFORMATION =====
        transformToVisualSpectrum(data);

        // ===== PRECISE COLOR CALCULATION =====
        calculatePreciseColor(data);
        calculateHSV(data);
        calculateLAB(data);

        // ===== PRECISE PIANO MAPPING =====
        calculatePrecisePianoMapping(data);

        // ===== QUANTUM PROPERTIES =====
        calculateQuantumProperties(data);

        // ===== REFERENCES =====
        data.references = {
            "Wyszecki & Stiles (2000). Color Science. Wiley.",
            "Hunt (2004). The Reproduction of Colour. Wiley.",
            "CIE 1931 Color Space (ISO 11664-1:2019)",
            "Planck Constant (CODATA 2018)",
            "Musical Tuning Standards (Ellis, 1880)"
        };

        return data;
    }

private:
    //==============================================================================
    // FREQUENCY SELECTION
    //==============================================================================

    static double selectDominantFrequency(const UnifiedFrequencyData& data)
    {
        // Priority: Audio > Alpha EEG > BPM > HRV
        // Use audio if present and significant
        if (data.audioFrequency_Hz >= 20.0 && data.audioFrequency_Hz <= 20000.0)
            return data.audioFrequency_Hz;

        // Use Alpha EEG (most stable brain rhythm)
        if (data.eeg.alpha >= 8.0 && data.eeg.alpha <= 13.0)
            return data.eeg.alpha;

        // Use BPM frequency
        if (data.bpmFrequency_Hz > 0.0)
            return data.bpmFrequency_Hz;

        // Fallback to HRV
        return data.hrvFrequency_Hz;
    }

    //==============================================================================
    // VISUAL SPECTRUM TRANSFORMATION
    //==============================================================================

    static void transformToVisualSpectrum(UnifiedFrequencyData& data)
    {
        double freq = data.dominantFrequency_Hz;
        int octaves = 0;

        // Octave shift to visible range (430-770 THz)
        const double MIN_VISIBLE_HZ = 4.3e14;  // 430 THz
        const double MAX_VISIBLE_HZ = 7.7e14;  // 770 THz

        while (freq < MIN_VISIBLE_HZ)
        {
            freq *= 2.0;
            octaves++;
        }

        while (freq > MAX_VISIBLE_HZ)
        {
            freq /= 2.0;
            octaves--;
        }

        data.octavesShifted = octaves;
        data.visualFrequency_THz = freq / 1e12;
        data.wavelength_nm = 299792458.0 / freq * 1e9;

        // Validation
        data.isPhysicallyValid = (data.wavelength_nm >= 380.0 && data.wavelength_nm <= 780.0);
    }

    //==============================================================================
    // PRECISE COLOR CALCULATION (CIE 1931)
    //==============================================================================

    static void calculatePreciseColor(UnifiedFrequencyData& data)
    {
        // Use existing ScientificFrequencyLightTransformer for base color
        auto colorScience = ScientificFrequencyLightTransformer::calculateScientificColor(
            data.wavelength_nm);

        data.r = colorScience.r;
        data.g = colorScience.g;
        data.b = colorScience.b;
    }

    //==============================================================================
    // HSV COLOR SPACE
    //==============================================================================

    static void calculateHSV(UnifiedFrequencyData& data)
    {
        // RGB → HSV conversion (precise)
        double max = std::max({data.r, data.g, data.b});
        double min = std::min({data.r, data.g, data.b});
        double delta = max - min;

        // Value
        data.v = max;

        // Saturation
        data.s = (max == 0.0) ? 0.0 : (delta / max);

        // Hue
        if (delta == 0.0)
        {
            data.h = 0.0;
        }
        else if (max == data.r)
        {
            data.h = 60.0 * std::fmod((data.g - data.b) / delta + 6.0, 6.0);
        }
        else if (max == data.g)
        {
            data.h = 60.0 * ((data.b - data.r) / delta + 2.0);
        }
        else  // max == data.b
        {
            data.h = 60.0 * ((data.r - data.g) / delta + 4.0);
        }
    }

    //==============================================================================
    // LAB COLOR SPACE (CIE L*a*b*)
    //==============================================================================

    static void calculateLAB(UnifiedFrequencyData& data)
    {
        // RGB → XYZ → LAB conversion

        // First: sRGB → Linear RGB (inverse gamma)
        auto invGamma = [](double c) -> double
        {
            return (c <= 0.04045) ? (c / 12.92) : std::pow((c + 0.055) / 1.055, 2.4);
        };

        double linearR = invGamma(data.r);
        double linearG = invGamma(data.g);
        double linearB = invGamma(data.b);

        // Linear RGB → XYZ (D65)
        double X = linearR * 0.4124564 + linearG * 0.3575761 + linearB * 0.1804375;
        double Y = linearR * 0.2126729 + linearG * 0.7151522 + linearB * 0.0721750;
        double Z = linearR * 0.0193339 + linearG * 0.1191920 + linearB * 0.9503041;

        // Normalize by D65 white point
        X /= 0.95047;
        Y /= 1.00000;
        Z /= 1.08883;

        // XYZ → LAB (CIE 1976)
        auto f = [](double t) -> double
        {
            const double delta = 6.0 / 29.0;
            return (t > delta * delta * delta) ? std::cbrt(t) : (t / (3.0 * delta * delta) + 4.0 / 29.0);
        };

        double fX = f(X);
        double fY = f(Y);
        double fZ = f(Z);

        data.L = 116.0 * fY - 16.0;
        data.a_star = 500.0 * (fX - fY);
        data.b_star = 200.0 * (fY - fZ);
    }

    //==============================================================================
    // PRECISE PIANO MAPPING (with Microtonality)
    //==============================================================================

    static void calculatePrecisePianoMapping(UnifiedFrequencyData& data)
    {
        // MIDI note number with custom A4 tuning
        double midiExact = 69.0 + 12.0 * std::log2(data.dominantFrequency_Hz / data.customA4_Hz);

        // Piano key (1-88) with microtonality
        // A0 = MIDI 21 = Piano Key 1
        data.exactPianoKey = midiExact - 20.0;

        // Clamp to valid piano range
        if (data.exactPianoKey < 1.0) data.exactPianoKey = 1.0;
        if (data.exactPianoKey > 88.0) data.exactPianoKey = 88.0;

        // Round to nearest semitone for note name
        int midiRounded = static_cast<int>(std::round(midiExact));

        // Calculate cent deviation (-50 to +50)
        data.centsDeviation = (midiExact - midiRounded) * 100.0;

        // Note name
        const char* noteNames[] = {"C", "C#", "D", "D#", "E", "F",
                                    "F#", "G", "G#", "A", "A#", "B"};
        int octave = (midiRounded / 12) - 1;
        int noteIndex = midiRounded % 12;

        // Format: "A4+13.686 cents" or "A4-13.686 cents"
        data.noteName = juce::String(noteNames[noteIndex]) + juce::String(octave);

        if (std::abs(data.centsDeviation) > 0.1)  // Only show if significant
        {
            data.noteName += juce::String::formatted(" %+.3f cents", data.centsDeviation);
        }
    }

    //==============================================================================
    // QUANTUM PROPERTIES
    //==============================================================================

    static void calculateQuantumProperties(UnifiedFrequencyData& data)
    {
        // Photon energy: E = h × f
        // h = Planck constant = 6.62607015×10^-34 J⋅s
        // 1 eV = 1.602176634×10^-19 J

        double freqHz = data.visualFrequency_THz * 1e12;
        double energyJoules = PrecisionConstants::PLANCK_CONSTANT * freqHz;
        data.photonEnergy_eV = energyJoules / 1.602176634e-19;

        // Quantum coherence (heuristic based on frequency stability)
        // Higher coherence for frequencies close to reference pitch
        double detuningCents = std::abs(data.centsDeviation);
        data.quantumCoherence = 1.0 - (detuningCents / 50.0);  // 0-1 range
        data.quantumCoherence = juce::jlimit(0.0, 1.0, data.quantumCoherence);

        // Planck units (normalized to Planck frequency)
        data.planckUnits = freqHz / PrecisionConstants::PLANCK_FREQUENCY;
    }

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MasterFrequencyTransformer)
};
