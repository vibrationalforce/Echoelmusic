#pragma once

#include <JuceHeader.h>
#include <cmath>
#include <array>

//==============================================================================
/**
 * @brief Intelligent Delay & Reverb Calculator
 *
 * Professional delay/reverb calculations based on:
 * - StudioCalculator.de (BPM → ms conversions)
 * - Sengpielaudio.com (acoustic timing, Haas effect)
 * - Music theory (note divisions, rhythmic patterns)
 *
 * **Scientific Foundation**:
 * 1. **BPM to Milliseconds**: T = 60000 / BPM
 * 2. **Note Divisions**: Whole, Half, Quarter, 8th, 16th, 32nd
 * 3. **Dotted Notes**: 1.5× note duration
 * 4. **Triplets**: 2/3 × note duration
 * 5. **Haas Effect**: 1-40 ms delays create stereo width
 * 6. **Pre-delay**: 10-100 ms for reverb clarity
 *
 * References:
 * - https://www.sengpielaudio.com/calculator-bpmtempotime.htm
 * - https://www.sengpielaudio.com/calculator-timedelayphase.htm
 * - Haas, H. (1951): "The Influence of a Single Echo on the Audibility of Speech"
 */
class IntelligentDelayCalculator
{
public:
    //==============================================================================
    // Note Divisions (musical timing)

    enum class NoteDivision
    {
        Whole = 1,          // 1/1 (4 beats)
        Half = 2,           // 1/2 (2 beats)
        Quarter = 4,        // 1/4 (1 beat)
        Eighth = 8,         // 1/8 (0.5 beats)
        Sixteenth = 16,     // 1/16 (0.25 beats)
        ThirtySecond = 32,  // 1/32 (0.125 beats)
        SixtyFourth = 64    // 1/64 (0.0625 beats)
    };

    enum class NoteModifier
    {
        Straight,           // Normal note
        Dotted,             // 1.5× duration (adds half)
        Triplet             // 2/3 × duration
    };

    //==============================================================================
    /**
     * @brief Calculate delay time from BPM and note division
     *
     * Formula: delayMs = (60000 / BPM) × (4 / division)
     *
     * @param bpm Beats per minute (40-300)
     * @param division Note division (1/4, 1/8, etc.)
     * @param modifier Dotted, triplet, or straight
     * @return Delay time in milliseconds
     */
    static float calculateDelayTime(float bpm,
                                   NoteDivision division,
                                   NoteModifier modifier = NoteModifier::Straight)
    {
        // Clamp BPM to reasonable range
        bpm = juce::jlimit(40.0f, 300.0f, bpm);

        // Calculate quarter note duration in ms
        float quarterNoteMs = 60000.0f / bpm;

        // Get division factor
        int divisionValue = static_cast<int>(division);
        float delayMs = quarterNoteMs * (4.0f / static_cast<float>(divisionValue));

        // Apply modifier
        switch (modifier)
        {
            case NoteModifier::Dotted:
                delayMs *= 1.5f;  // Add half the note duration
                break;

            case NoteModifier::Triplet:
                delayMs *= (2.0f / 3.0f);  // 2/3 of the note
                break;

            default:
                break;
        }

        return delayMs;
    }

    /**
     * @brief Calculate BPM from delay time (reverse calculation)
     */
    static float calculateBPMFromDelay(float delayMs, NoteDivision division)
    {
        int divisionValue = static_cast<int>(division);
        float quarterNoteMs = delayMs * (static_cast<float>(divisionValue) / 4.0f);
        return 60000.0f / quarterNoteMs;
    }

    //==============================================================================
    /**
     * @brief Calculate Haas Effect stereo width delay
     *
     * The Haas Effect (precedence effect): Delays of 1-40 ms create stereo
     * width without perceived echo.
     *
     * - 1-5 ms: Tight stereo widening
     * - 5-15 ms: Medium width (most natural)
     * - 15-30 ms: Wide stereo image
     * - 30-40 ms: Very wide (starts to sound like echo)
     * - > 40 ms: Perceived as distinct echo
     *
     * Reference: Haas, H. (1951)
     */
    static float calculateHaasDelay(float widthAmount)
    {
        // widthAmount: 0-1 (0 = tight, 1 = very wide)
        widthAmount = juce::jlimit(0.0f, 1.0f, widthAmount);

        // Map to Haas range (1-40 ms)
        return 1.0f + (widthAmount * 39.0f);
    }

    /**
     * @brief Calculate pre-delay for reverb clarity
     *
     * Pre-delay creates separation between dry signal and reverb:
     * - Short (0-20 ms): Tight, intimate sound
     * - Medium (20-50 ms): Natural room ambience
     * - Long (50-100 ms): Clear separation, spacious
     * - Very long (100-150 ms): Special effects
     */
    static float calculatePreDelay(float bpm, float clarityAmount)
    {
        // clarityAmount: 0-1 (0 = tight, 1 = very clear)
        clarityAmount = juce::jlimit(0.0f, 1.0f, clarityAmount);

        // Calculate based on tempo (faster tempo = shorter pre-delay)
        float quarterNoteMs = 60000.0f / bpm;

        // Map to pre-delay range (5-100 ms)
        float maxPreDelay = juce::jmin(100.0f, quarterNoteMs * 0.5f);
        return 5.0f + (clarityAmount * maxPreDelay);
    }

    //==============================================================================
    /**
     * @brief Generate ping-pong delay pattern
     *
     * Returns array of delay times for ping-pong effect (L-R-L-R...)
     */
    static std::vector<float> generatePingPongPattern(float baseDelayMs,
                                                     int numRepeats = 4)
    {
        std::vector<float> pattern;
        pattern.reserve(numRepeats);

        for (int i = 0; i < numRepeats; ++i)
        {
            pattern.push_back(baseDelayMs * static_cast<float>(i + 1));
        }

        return pattern;
    }

    /**
     * @brief Generate polyrhythmic delay pattern
     *
     * Creates multiple delay lines with different note divisions for
     * complex rhythmic patterns.
     */
    static std::vector<float> generatePolyrhythmicPattern(float bpm,
                                                         const std::vector<NoteDivision>& divisions)
    {
        std::vector<float> pattern;
        pattern.reserve(divisions.size());

        for (auto division : divisions)
        {
            pattern.push_back(calculateDelayTime(bpm, division));
        }

        return pattern;
    }

    //==============================================================================
    /**
     * @brief Get note division name (for display)
     */
    static juce::String getNoteDivisionName(NoteDivision division)
    {
        switch (division)
        {
            case NoteDivision::Whole: return "1/1 (Whole)";
            case NoteDivision::Half: return "1/2 (Half)";
            case NoteDivision::Quarter: return "1/4 (Quarter)";
            case NoteDivision::Eighth: return "1/8 (Eighth)";
            case NoteDivision::Sixteenth: return "1/16 (16th)";
            case NoteDivision::ThirtySecond: return "1/32 (32nd)";
            case NoteDivision::SixtyFourth: return "1/64 (64th)";
            default: return "Unknown";
        }
    }

    static juce::String getNoteModifierSymbol(NoteModifier modifier)
    {
        switch (modifier)
        {
            case NoteModifier::Dotted: return ".";
            case NoteModifier::Triplet: return "T";
            default: return "";
        }
    }
};

//==============================================================================
/**
 * @brief Room Acoustics & Reverb Calculator
 *
 * Professional room acoustics calculations based on:
 * - Sengpielaudio.com (reverberation time, critical distance)
 * - Sabine formula (RT60 calculation)
 * - Wallace Clement Sabine (1900s): Father of architectural acoustics
 *
 * **Scientific Foundation**:
 * 1. **Sabine Formula**: RT60 = 0.161 × V / A
 *    - V: Room volume (m³)
 *    - A: Total absorption (m² sabins)
 *    - RT60: Reverberation time (seconds)
 *
 * 2. **Critical Distance**: Dc = 0.057 × √(V / RT60)
 *    - Distance where direct sound = reverberant sound
 *
 * 3. **Speed of Sound**: c ≈ 343 m/s (20°C, sea level)
 *
 * References:
 * - https://www.sengpielaudio.com/calculator-RT60.htm
 * - https://www.sengpielaudio.com/calculator-kritdist.htm
 * - Sabine, W.C. (1922): "Collected Papers on Acoustics"
 */
class RoomAcousticsCalculator
{
public:
    //==============================================================================
    struct RoomDimensions
    {
        float lengthM = 5.0f;
        float widthM = 4.0f;
        float heightM = 3.0f;

        float getVolume() const
        {
            return lengthM * widthM * heightM;
        }

        float getSurfaceArea() const
        {
            return 2.0f * (lengthM * widthM + lengthM * heightM + widthM * heightM);
        }
    };

    //==============================================================================
    // Material absorption coefficients (500 Hz typical)
    enum class Material
    {
        Concrete,           // α = 0.02 (very reflective)
        Wood,               // α = 0.10
        Carpet,             // α = 0.30
        Curtains,           // α = 0.50
        AcousticPanel,      // α = 0.80
        OpenWindow          // α = 1.00 (total absorption)
    };

    /**
     * @brief Get absorption coefficient for material
     */
    static float getAbsorptionCoefficient(Material material)
    {
        switch (material)
        {
            case Material::Concrete: return 0.02f;
            case Material::Wood: return 0.10f;
            case Material::Carpet: return 0.30f;
            case Material::Curtains: return 0.50f;
            case Material::AcousticPanel: return 0.80f;
            case Material::OpenWindow: return 1.00f;
            default: return 0.20f;
        }
    }

    //==============================================================================
    /**
     * @brief Calculate RT60 using Sabine formula
     *
     * RT60 = 0.161 × V / A
     * - V: Volume (m³)
     * - A: Total absorption area (m² sabins)
     *
     * Typical RT60 values:
     * - Recording studio: 0.2-0.4 s
     * - Living room: 0.4-0.6 s
     * - Concert hall: 1.5-2.5 s
     * - Cathedral: 5-10 s
     */
    static float calculateRT60(const RoomDimensions& room, float absorptionCoefficient)
    {
        float volume = room.getVolume();
        float surfaceArea = room.getSurfaceArea();
        float totalAbsorption = surfaceArea * absorptionCoefficient;

        // Sabine formula
        float rt60 = 0.161f * volume / totalAbsorption;

        return rt60;
    }

    /**
     * @brief Calculate critical distance
     *
     * Dc = 0.057 × √(V / RT60)
     *
     * Critical distance is where direct sound level equals reverberant sound level.
     * Closer than Dc: Direct sound dominates
     * Further than Dc: Reverberant sound dominates
     */
    static float calculateCriticalDistance(const RoomDimensions& room, float rt60)
    {
        float volume = room.getVolume();
        float criticalDistanceM = 0.057f * std::sqrt(volume / rt60);

        return criticalDistanceM;
    }

    /**
     * @brief Calculate early reflection delay times
     *
     * Returns first reflection delays based on room dimensions.
     * Useful for realistic reverb design.
     */
    static std::vector<float> calculateEarlyReflections(const RoomDimensions& room)
    {
        std::vector<float> reflectionTimesMs;

        const float speedOfSoundMs = 343.0f / 1000.0f;  // 343 m/s → m/ms

        // Calculate first-order reflections (6 surfaces)
        // Floor/ceiling
        reflectionTimesMs.push_back((2.0f * room.heightM / speedOfSoundMs));

        // Left/right walls
        reflectionTimesMs.push_back((2.0f * room.widthM / speedOfSoundMs));

        // Front/back walls
        reflectionTimesMs.push_back((2.0f * room.lengthM / speedOfSoundMs));

        // Sort by time
        std::sort(reflectionTimesMs.begin(), reflectionTimesMs.end());

        return reflectionTimesMs;
    }

    //==============================================================================
    /**
     * @brief Suggest reverb decay time based on room and genre
     */
    static float suggestReverbDecay(const RoomDimensions& room,
                                   float absorptionCoefficient,
                                   const juce::String& genre)
    {
        float naturalRT60 = calculateRT60(room, absorptionCoefficient);

        // Adjust based on genre preferences
        float multiplier = 1.0f;

        if (genre == "Rock" || genre == "Pop")
            multiplier = 0.7f;  // Shorter, tighter
        else if (genre == "Electronic")
            multiplier = 0.5f;  // Very short
        else if (genre == "Classical" || genre == "Ambient")
            multiplier = 1.5f;  // Longer, spacious
        else if (genre == "Jazz")
            multiplier = 1.0f;  // Natural

        return naturalRT60 * multiplier;
    }

    /**
     * @brief Get material name (for display)
     */
    static juce::String getMaterialName(Material material)
    {
        switch (material)
        {
            case Material::Concrete: return "Concrete (α=0.02)";
            case Material::Wood: return "Wood (α=0.10)";
            case Material::Carpet: return "Carpet (α=0.30)";
            case Material::Curtains: return "Curtains (α=0.50)";
            case Material::AcousticPanel: return "Acoustic Panel (α=0.80)";
            case Material::OpenWindow: return "Open Window (α=1.00)";
            default: return "Unknown";
        }
    }
};
