#pragma once

#include "ProceduralSampleSynthesizer.h"
#include <map>

/**
 * ECHOELMUSIC SIGNATURE SOUND LIBRARY
 *
 * Die besten prozedural generierten Sounds, optimiert für die Echoelmusic Signature.
 *
 * VORTEILE:
 * - Nur die besten Sounds (handverlesen)
 * - Perfekt optimiert für Echoelmusic
 * - < 10MB total (vs. 1.2GB Downloads!)
 * - Sofort verfügbar (keine Downloads)
 * - Infinite Variationen möglich
 *
 * KATEGORIEN:
 * 1. DRUMS: 20 beste Drum-Sounds
 * 2. BASS: 15 beste Bass-Sounds
 * 3. MELODIC: 15 beste Melodic-Sounds
 * 4. TEXTURES: 10 beste Textures
 * 5. FX: 10 beste FX-Sounds
 *
 * TOTAL: 70 handverlesene Signature-Sounds
 *
 * Usage:
 * ```cpp
 * EchoelmusicSignatureSounds sounds;
 * sounds.initialize(44100.0);
 *
 * // Get signature kick
 * auto kick = sounds.getSound("ECHOEL_KICK_DEEP");
 *
 * // Get 808 bass
 * auto bass = sounds.getSound("ECHOEL_808_CLASSIC");
 *
 * // List all sounds
 * auto categories = sounds.getCategories();
 * ```
 */

class EchoelmusicSignatureSounds
{
public:
    //==============================================================================
    // Sound IDs
    //==============================================================================

    // DRUMS (20)
    static constexpr const char* ECHOEL_KICK_DEEP = "ECHOEL_KICK_DEEP";
    static constexpr const char* ECHOEL_KICK_PUNCHY = "ECHOEL_KICK_PUNCHY";
    static constexpr const char* ECHOEL_KICK_SUB = "ECHOEL_KICK_SUB";
    static constexpr const char* ECHOEL_KICK_TIGHT = "ECHOEL_KICK_TIGHT";
    static constexpr const char* ECHOEL_KICK_MODERN = "ECHOEL_KICK_MODERN";

    static constexpr const char* ECHOEL_SNARE_SHARP = "ECHOEL_SNARE_SHARP";
    static constexpr const char* ECHOEL_SNARE_FAT = "ECHOEL_SNARE_FAT";
    static constexpr const char* ECHOEL_SNARE_CRISP = "ECHOEL_SNARE_CRISP";

    static constexpr const char* ECHOEL_HIHAT_CLOSED = "ECHOEL_HIHAT_CLOSED";
    static constexpr const char* ECHOEL_HIHAT_OPEN = "ECHOEL_HIHAT_OPEN";
    static constexpr const char* ECHOEL_HIHAT_BRIGHT = "ECHOEL_HIHAT_BRIGHT";

    static constexpr const char* ECHOEL_CLAP_MODERN = "ECHOEL_CLAP_MODERN";
    static constexpr const char* ECHOEL_CLAP_CLASSIC = "ECHOEL_CLAP_CLASSIC";

    static constexpr const char* ECHOEL_TOM_LOW = "ECHOEL_TOM_LOW";
    static constexpr const char* ECHOEL_TOM_MID = "ECHOEL_TOM_MID";
    static constexpr const char* ECHOEL_TOM_HIGH = "ECHOEL_TOM_HIGH";

    static constexpr const char* ECHOEL_CYMBAL_CRASH = "ECHOEL_CYMBAL_CRASH";
    static constexpr const char* ECHOEL_CYMBAL_RIDE = "ECHOEL_CYMBAL_RIDE";

    static constexpr const char* ECHOEL_PERC_SHAKER = "ECHOEL_PERC_SHAKER";
    static constexpr const char* ECHOEL_PERC_SNAP = "ECHOEL_PERC_SNAP";

    // BASS (15)
    static constexpr const char* ECHOEL_808_CLASSIC = "ECHOEL_808_CLASSIC";
    static constexpr const char* ECHOEL_808_MODERN = "ECHOEL_808_MODERN";
    static constexpr const char* ECHOEL_808_DISTORTED = "ECHOEL_808_DISTORTED";
    static constexpr const char* ECHOEL_808_LONG = "ECHOEL_808_LONG";
    static constexpr const char* ECHOEL_808_SHORT = "ECHOEL_808_SHORT";

    static constexpr const char* ECHOEL_SUB_PURE = "ECHOEL_SUB_PURE";
    static constexpr const char* ECHOEL_SUB_TRIANGLE = "ECHOEL_SUB_TRIANGLE";

    static constexpr const char* ECHOEL_REESE_CLASSIC = "ECHOEL_REESE_CLASSIC";
    static constexpr const char* ECHOEL_REESE_WIDE = "ECHOEL_REESE_WIDE";
    static constexpr const char* ECHOEL_REESE_TIGHT = "ECHOEL_REESE_TIGHT";

    static constexpr const char* ECHOEL_FM_BASS_GROWL = "ECHOEL_FM_BASS_GROWL";
    static constexpr const char* ECHOEL_FM_BASS_SOFT = "ECHOEL_FM_BASS_SOFT";
    static constexpr const char* ECHOEL_FM_BASS_HARSH = "ECHOEL_FM_BASS_HARSH";

    static constexpr const char* ECHOEL_BASS_ANALOG = "ECHOEL_BASS_ANALOG";
    static constexpr const char* ECHOEL_BASS_DIGITAL = "ECHOEL_BASS_DIGITAL";

    // MELODIC (15)
    static constexpr const char* ECHOEL_PAD_WARM = "ECHOEL_PAD_WARM";
    static constexpr const char* ECHOEL_PAD_BRIGHT = "ECHOEL_PAD_BRIGHT";
    static constexpr const char* ECHOEL_PAD_DARK = "ECHOEL_PAD_DARK";
    static constexpr const char* ECHOEL_PAD_ETHEREAL = "ECHOEL_PAD_ETHEREAL";
    static constexpr const char* ECHOEL_PAD_THICK = "ECHOEL_PAD_THICK";

    static constexpr const char* ECHOEL_LEAD_HARD = "ECHOEL_LEAD_HARD";
    static constexpr const char* ECHOEL_LEAD_SOFT = "ECHOEL_LEAD_SOFT";
    static constexpr const char* ECHOEL_LEAD_RESONANT = "ECHOEL_LEAD_RESONANT";

    static constexpr const char* ECHOEL_PLUCK_BRIGHT = "ECHOEL_PLUCK_BRIGHT";
    static constexpr const char* ECHOEL_PLUCK_SOFT = "ECHOEL_PLUCK_SOFT";

    static constexpr const char* ECHOEL_SAW_MODERN = "ECHOEL_SAW_MODERN";
    static constexpr const char* ECHOEL_SAW_CLASSIC = "ECHOEL_SAW_CLASSIC";

    static constexpr const char* ECHOEL_SQUARE_THIN = "ECHOEL_SQUARE_THIN";
    static constexpr const char* ECHOEL_SQUARE_FAT = "ECHOEL_SQUARE_FAT";

    static constexpr const char* ECHOEL_BELL_SOFT = "ECHOEL_BELL_SOFT";

    // TEXTURES (10)
    static constexpr const char* ECHOEL_ATMOSPHERE_WARM = "ECHOEL_ATMOSPHERE_WARM";
    static constexpr const char* ECHOEL_ATMOSPHERE_COLD = "ECHOEL_ATMOSPHERE_COLD";
    static constexpr const char* ECHOEL_ATMOSPHERE_MOVING = "ECHOEL_ATMOSPHERE_MOVING";

    static constexpr const char* ECHOEL_NOISE_WHITE = "ECHOEL_NOISE_WHITE";
    static constexpr const char* ECHOEL_NOISE_PINK = "ECHOEL_NOISE_PINK";
    static constexpr const char* ECHOEL_NOISE_BROWN = "ECHOEL_NOISE_BROWN";

    static constexpr const char* ECHOEL_VINYL_LIGHT = "ECHOEL_VINYL_LIGHT";
    static constexpr const char* ECHOEL_VINYL_HEAVY = "ECHOEL_VINYL_HEAVY";

    static constexpr const char* ECHOEL_TEXTURE_GRANULAR = "ECHOEL_TEXTURE_GRANULAR";
    static constexpr const char* ECHOEL_TEXTURE_GLITCH = "ECHOEL_TEXTURE_GLITCH";

    // FX (10)
    static constexpr const char* ECHOEL_IMPACT_HEAVY = "ECHOEL_IMPACT_HEAVY";
    static constexpr const char* ECHOEL_IMPACT_LIGHT = "ECHOEL_IMPACT_LIGHT";

    static constexpr const char* ECHOEL_RISER_FAST = "ECHOEL_RISER_FAST";
    static constexpr const char* ECHOEL_RISER_SLOW = "ECHOEL_RISER_SLOW";
    static constexpr const char* ECHOEL_RISER_INTENSE = "ECHOEL_RISER_INTENSE";

    static constexpr const char* ECHOEL_SWEEP_UP = "ECHOEL_SWEEP_UP";
    static constexpr const char* ECHOEL_SWEEP_DOWN = "ECHOEL_SWEEP_DOWN";

    static constexpr const char* ECHOEL_WHOOSH_FAST = "ECHOEL_WHOOSH_FAST";
    static constexpr const char* ECHOEL_WHOOSH_SLOW = "ECHOEL_WHOOSH_SLOW";

    static constexpr const char* ECHOEL_TRANSITION_SMOOTH = "ECHOEL_TRANSITION_SMOOTH";

    //==============================================================================
    // Public API
    //==============================================================================

    EchoelmusicSignatureSounds();
    ~EchoelmusicSignatureSounds();

    /** Initialize with sample rate */
    void initialize(double sampleRate);

    /** Get sound by ID */
    juce::AudioBuffer<float> getSound(const juce::String& soundID);

    /** Get all sound IDs in category */
    juce::StringArray getSoundsInCategory(const juce::String& category);

    /** Get all categories */
    juce::StringArray getCategories();

    /** Get total library size in bytes */
    size_t getTotalSizeBytes() const;

    /** Get number of sounds */
    int getNumSounds() const { return 70; }

    /** Preload all sounds (for instant access) */
    void preloadAll();

    /** Clear all cached sounds */
    void clearCache();

private:
    ProceduralSampleSynthesizer synthesizer;

    // Sound generation functions
    juce::AudioBuffer<float> generateDrumSound(const juce::String& soundID);
    juce::AudioBuffer<float> generateBassSound(const juce::String& soundID);
    juce::AudioBuffer<float> generateMelodicSound(const juce::String& soundID);
    juce::AudioBuffer<float> generateTextureSound(const juce::String& soundID);
    juce::AudioBuffer<float> generateFXSound(const juce::String& soundID);

    // Category mapping
    std::map<juce::String, juce::StringArray> categoryMap;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(EchoelmusicSignatureSounds)
};
