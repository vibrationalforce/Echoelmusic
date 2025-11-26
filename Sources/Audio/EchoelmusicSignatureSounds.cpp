#include "EchoelmusicSignatureSounds.h"

//==============================================================================
// Construction / Destruction
//==============================================================================

EchoelmusicSignatureSounds::EchoelmusicSignatureSounds()
{
    // Initialize category mappings
    categoryMap["DRUMS"] = {
        ECHOEL_KICK_DEEP, ECHOEL_KICK_PUNCHY, ECHOEL_KICK_SUB,
        ECHOEL_KICK_TIGHT, ECHOEL_KICK_MODERN,
        ECHOEL_SNARE_SHARP, ECHOEL_SNARE_FAT, ECHOEL_SNARE_CRISP,
        ECHOEL_HIHAT_CLOSED, ECHOEL_HIHAT_OPEN, ECHOEL_HIHAT_BRIGHT,
        ECHOEL_CLAP_MODERN, ECHOEL_CLAP_CLASSIC,
        ECHOEL_TOM_LOW, ECHOEL_TOM_MID, ECHOEL_TOM_HIGH,
        ECHOEL_CYMBAL_CRASH, ECHOEL_CYMBAL_RIDE,
        ECHOEL_PERC_SHAKER, ECHOEL_PERC_SNAP
    };

    categoryMap["BASS"] = {
        ECHOEL_808_CLASSIC, ECHOEL_808_MODERN, ECHOEL_808_DISTORTED,
        ECHOEL_808_LONG, ECHOEL_808_SHORT,
        ECHOEL_SUB_PURE, ECHOEL_SUB_TRIANGLE,
        ECHOEL_REESE_CLASSIC, ECHOEL_REESE_WIDE, ECHOEL_REESE_TIGHT,
        ECHOEL_FM_BASS_GROWL, ECHOEL_FM_BASS_SOFT, ECHOEL_FM_BASS_HARSH,
        ECHOEL_BASS_ANALOG, ECHOEL_BASS_DIGITAL
    };

    categoryMap["MELODIC"] = {
        ECHOEL_PAD_WARM, ECHOEL_PAD_BRIGHT, ECHOEL_PAD_DARK,
        ECHOEL_PAD_ETHEREAL, ECHOEL_PAD_THICK,
        ECHOEL_LEAD_HARD, ECHOEL_LEAD_SOFT, ECHOEL_LEAD_RESONANT,
        ECHOEL_PLUCK_BRIGHT, ECHOEL_PLUCK_SOFT,
        ECHOEL_SAW_MODERN, ECHOEL_SAW_CLASSIC,
        ECHOEL_SQUARE_THIN, ECHOEL_SQUARE_FAT,
        ECHOEL_BELL_SOFT
    };

    categoryMap["TEXTURES"] = {
        ECHOEL_ATMOSPHERE_WARM, ECHOEL_ATMOSPHERE_COLD, ECHOEL_ATMOSPHERE_MOVING,
        ECHOEL_NOISE_WHITE, ECHOEL_NOISE_PINK, ECHOEL_NOISE_BROWN,
        ECHOEL_VINYL_LIGHT, ECHOEL_VINYL_HEAVY,
        ECHOEL_TEXTURE_GRANULAR, ECHOEL_TEXTURE_GLITCH
    };

    categoryMap["FX"] = {
        ECHOEL_IMPACT_HEAVY, ECHOEL_IMPACT_LIGHT,
        ECHOEL_RISER_FAST, ECHOEL_RISER_SLOW, ECHOEL_RISER_INTENSE,
        ECHOEL_SWEEP_UP, ECHOEL_SWEEP_DOWN,
        ECHOEL_WHOOSH_FAST, ECHOEL_WHOOSH_SLOW,
        ECHOEL_TRANSITION_SMOOTH
    };
}

EchoelmusicSignatureSounds::~EchoelmusicSignatureSounds()
{
}

//==============================================================================
// Initialization
//==============================================================================

void EchoelmusicSignatureSounds::initialize(double sampleRate)
{
    synthesizer.initialize(sampleRate);
}

//==============================================================================
// Public API
//==============================================================================

juce::AudioBuffer<float> EchoelmusicSignatureSounds::getSound(const juce::String& soundID)
{
    // Determine category
    for (const auto& pair : categoryMap)
    {
        if (pair.second.contains(soundID))
        {
            const juce::String& category = pair.first;

            if (category == "DRUMS")
                return generateDrumSound(soundID);
            else if (category == "BASS")
                return generateBassSound(soundID);
            else if (category == "MELODIC")
                return generateMelodicSound(soundID);
            else if (category == "TEXTURES")
                return generateTextureSound(soundID);
            else if (category == "FX")
                return generateFXSound(soundID);
        }
    }

    // Default: return empty buffer
    return juce::AudioBuffer<float>(2, 1);
}

juce::StringArray EchoelmusicSignatureSounds::getSoundsInCategory(const juce::String& category)
{
    if (categoryMap.count(category))
        return categoryMap[category];

    return juce::StringArray();
}

juce::StringArray EchoelmusicSignatureSounds::getCategories()
{
    juce::StringArray categories;
    for (const auto& pair : categoryMap)
        categories.add(pair.first);

    return categories;
}

size_t EchoelmusicSignatureSounds::getTotalSizeBytes() const
{
    return synthesizer.getTotalSizeBytes();
}

void EchoelmusicSignatureSounds::preloadAll()
{
    for (const auto& pair : categoryMap)
    {
        for (const auto& soundID : pair.second)
        {
            getSound(soundID);  // This caches it
        }
    }
}

void EchoelmusicSignatureSounds::clearCache()
{
    synthesizer.clearCache();
}

//==============================================================================
// Drum Sound Generation
//==============================================================================

juce::AudioBuffer<float> EchoelmusicSignatureSounds::generateDrumSound(const juce::String& soundID)
{
    // KICKS
    if (soundID == ECHOEL_KICK_DEEP)
        return synthesizer.generateKick(55.0f, 0.9f, 0.6f, 0.35f, 0.25f);
    else if (soundID == ECHOEL_KICK_PUNCHY)
        return synthesizer.generateKick(65.0f, 0.95f, 0.45f, 0.5f, 0.3f);
    else if (soundID == ECHOEL_KICK_SUB)
        return synthesizer.generateKick(50.0f, 0.7f, 0.8f, 0.2f, 0.15f);
    else if (soundID == ECHOEL_KICK_TIGHT)
        return synthesizer.generateKick(70.0f, 0.85f, 0.35f, 0.45f, 0.35f);
    else if (soundID == ECHOEL_KICK_MODERN)
        return synthesizer.generateKick(60.0f, 0.88f, 0.5f, 0.4f, 0.28f);

    // SNARES
    else if (soundID == ECHOEL_SNARE_SHARP)
        return synthesizer.generateSnare(220.0f, 0.6f, 0.8f, 0.7f, 0.18f);
    else if (soundID == ECHOEL_SNARE_FAT)
        return synthesizer.generateSnare(180.0f, 0.7f, 0.6f, 0.65f, 0.25f);
    else if (soundID == ECHOEL_SNARE_CRISP)
        return synthesizer.generateSnare(250.0f, 0.5f, 0.85f, 0.75f, 0.16f);

    // HIHATS
    else if (soundID == ECHOEL_HIHAT_CLOSED)
        return synthesizer.generateHihat(0.75f, 0.08f, true, 0.6f);
    else if (soundID == ECHOEL_HIHAT_OPEN)
        return synthesizer.generateHihat(0.7f, 0.3f, false, 0.5f);
    else if (soundID == ECHOEL_HIHAT_BRIGHT)
        return synthesizer.generateHihat(0.9f, 0.1f, true, 0.7f);

    // CLAPS
    else if (soundID == ECHOEL_CLAP_MODERN)
        return synthesizer.generateClap(0.8f, 0.15f, 4);
    else if (soundID == ECHOEL_CLAP_CLASSIC)
        return synthesizer.generateClap(0.6f, 0.18f, 3);

    // TOMS
    else if (soundID == ECHOEL_TOM_LOW)
        return synthesizer.generateTom(80.0f, 0.35f, 0.6f);
    else if (soundID == ECHOEL_TOM_MID)
        return synthesizer.generateTom(120.0f, 0.3f, 0.55f);
    else if (soundID == ECHOEL_TOM_HIGH)
        return synthesizer.generateTom(180.0f, 0.25f, 0.5f);

    // CYMBALS
    else if (soundID == ECHOEL_CYMBAL_CRASH)
        return synthesizer.generateCymbal(0.85f, 1.8f, true);
    else if (soundID == ECHOEL_CYMBAL_RIDE)
        return synthesizer.generateCymbal(0.75f, 1.2f, false);

    // PERCUSSION
    else if (soundID == ECHOEL_PERC_SHAKER)
        return synthesizer.generateHihat(0.6f, 0.12f, true, 0.3f);
    else if (soundID == ECHOEL_PERC_SNAP)
        return synthesizer.generateClap(0.9f, 0.08f, 1);

    return juce::AudioBuffer<float>(2, 1);
}

//==============================================================================
// Bass Sound Generation
//==============================================================================

juce::AudioBuffer<float> EchoelmusicSignatureSounds::generateBassSound(const juce::String& soundID)
{
    // 808 BASS
    if (soundID == ECHOEL_808_CLASSIC)
        return synthesizer.generate808Bass(55.0f, 0.5f, 2.0f, 0.5f);
    else if (soundID == ECHOEL_808_MODERN)
        return synthesizer.generate808Bass(55.0f, 0.6f, 2.5f, 0.6f);
    else if (soundID == ECHOEL_808_DISTORTED)
        return synthesizer.generate808Bass(55.0f, 0.55f, 3.5f, 0.7f);
    else if (soundID == ECHOEL_808_LONG)
        return synthesizer.generate808Bass(55.0f, 0.8f, 2.0f, 0.5f);
    else if (soundID == ECHOEL_808_SHORT)
        return synthesizer.generate808Bass(55.0f, 0.3f, 2.2f, 0.6f);

    // SUB BASS
    else if (soundID == ECHOEL_SUB_PURE)
        return synthesizer.generateSubBass(55.0f, 0.0f, 1.0f);
    else if (soundID == ECHOEL_SUB_TRIANGLE)
        return synthesizer.generateSubBass(55.0f, 1.0f, 1.0f);

    // REESE BASS
    else if (soundID == ECHOEL_REESE_CLASSIC)
        return synthesizer.generateReeseBass(55.0f, 0.15f, 7, 0.6f, 1.0f);
    else if (soundID == ECHOEL_REESE_WIDE)
        return synthesizer.generateReeseBass(55.0f, 0.25f, 9, 0.8f, 1.0f);
    else if (soundID == ECHOEL_REESE_TIGHT)
        return synthesizer.generateReeseBass(55.0f, 0.08f, 5, 0.4f, 1.0f);

    // FM BASS
    else if (soundID == ECHOEL_FM_BASS_GROWL)
        return synthesizer.generateFMBass(55.0f, 3.0f, 1.8f, 1.0f);
    else if (soundID == ECHOEL_FM_BASS_SOFT)
        return synthesizer.generateFMBass(55.0f, 1.5f, 2.0f, 1.0f);
    else if (soundID == ECHOEL_FM_BASS_HARSH)
        return synthesizer.generateFMBass(55.0f, 4.5f, 1.5f, 1.0f);

    // OTHER BASS
    else if (soundID == ECHOEL_BASS_ANALOG)
        return synthesizer.generateWavetable(55.0f, 0, 0.05f, 3, 1.0f);  // Saw
    else if (soundID == ECHOEL_BASS_DIGITAL)
        return synthesizer.generateWavetable(55.0f, 1, 0.0f, 1, 1.0f);   // Square

    return juce::AudioBuffer<float>(2, 1);
}

//==============================================================================
// Melodic Sound Generation
//==============================================================================

juce::AudioBuffer<float> EchoelmusicSignatureSounds::generateMelodicSound(const juce::String& soundID)
{
    // PADS
    if (soundID == ECHOEL_PAD_WARM)
        return synthesizer.generatePad(440.0f, 0.3f, "warm", 4.0f);
    else if (soundID == ECHOEL_PAD_BRIGHT)
        return synthesizer.generatePad(440.0f, 0.7f, "bright", 4.0f);
    else if (soundID == ECHOEL_PAD_DARK)
        return synthesizer.generatePad(440.0f, 0.2f, "dark", 4.0f);
    else if (soundID == ECHOEL_PAD_ETHEREAL)
        return synthesizer.generatePad(440.0f, 0.4f, "ethereal", 4.0f);
    else if (soundID == ECHOEL_PAD_THICK)
        return synthesizer.generatePad(440.0f, 0.5f, "warm", 5.0f);

    // LEADS
    else if (soundID == ECHOEL_LEAD_HARD)
        return synthesizer.generateLead(440.0f, 0.9f, 0.7f, 1.0f);
    else if (soundID == ECHOEL_LEAD_SOFT)
        return synthesizer.generateLead(440.0f, 0.3f, 0.3f, 1.0f);
    else if (soundID == ECHOEL_LEAD_RESONANT)
        return synthesizer.generateLead(440.0f, 0.6f, 0.85f, 1.0f);

    // PLUCKS (leads with short decay)
    else if (soundID == ECHOEL_PLUCK_BRIGHT)
        return synthesizer.generateLead(440.0f, 0.8f, 0.5f, 0.15f);
    else if (soundID == ECHOEL_PLUCK_SOFT)
        return synthesizer.generateLead(440.0f, 0.3f, 0.2f, 0.2f);

    // SAW WAVES
    else if (soundID == ECHOEL_SAW_MODERN)
        return synthesizer.generateWavetable(440.0f, 0, 0.08f, 5, 1.0f);
    else if (soundID == ECHOEL_SAW_CLASSIC)
        return synthesizer.generateWavetable(440.0f, 0, 0.03f, 3, 1.0f);

    // SQUARE WAVES
    else if (soundID == ECHOEL_SQUARE_THIN)
        return synthesizer.generateWavetable(440.0f, 1, 0.0f, 1, 1.0f);
    else if (soundID == ECHOEL_SQUARE_FAT)
        return synthesizer.generateWavetable(440.0f, 1, 0.1f, 5, 1.0f);

    // BELL
    else if (soundID == ECHOEL_BELL_SOFT)
        return synthesizer.generateFMBass(440.0f, 1.5f, 3.5f, 2.0f);

    return juce::AudioBuffer<float>(2, 1);
}

//==============================================================================
// Texture Sound Generation
//==============================================================================

juce::AudioBuffer<float> EchoelmusicSignatureSounds::generateTextureSound(const juce::String& soundID)
{
    // ATMOSPHERES
    if (soundID == ECHOEL_ATMOSPHERE_WARM)
        return synthesizer.generateAtmosphere(0.3f, 0.2f, 8.0f);
    else if (soundID == ECHOEL_ATMOSPHERE_COLD)
        return synthesizer.generateAtmosphere(0.7f, 0.15f, 8.0f);
    else if (soundID == ECHOEL_ATMOSPHERE_MOVING)
        return synthesizer.generateAtmosphere(0.5f, 0.5f, 8.0f);

    // NOISE
    else if (soundID == ECHOEL_NOISE_WHITE)
        return synthesizer.generateNoise(0.0f, 1.0f);
    else if (soundID == ECHOEL_NOISE_PINK)
        return synthesizer.generateNoise(0.5f, 1.0f);
    else if (soundID == ECHOEL_NOISE_BROWN)
        return synthesizer.generateNoise(1.0f, 1.0f);

    // VINYL
    else if (soundID == ECHOEL_VINYL_LIGHT)
        return synthesizer.generateVinylCrackle(0.2f, 2.0f);
    else if (soundID == ECHOEL_VINYL_HEAVY)
        return synthesizer.generateVinylCrackle(0.5f, 2.0f);

    // OTHER TEXTURES
    else if (soundID == ECHOEL_TEXTURE_GRANULAR)
    {
        // Generate granular-like texture
        auto noise = synthesizer.generateNoise(0.5f, 1.0f);
        // Apply amplitude modulation
        for (int i = 0; i < noise.getNumSamples(); i++)
        {
            float mod = std::abs(std::sin(i * 0.05f));
            noise.setSample(0, i, noise.getSample(0, i) * mod);
            noise.setSample(1, i, noise.getSample(1, i) * mod);
        }
        return noise;
    }
    else if (soundID == ECHOEL_TEXTURE_GLITCH)
    {
        // Generate glitchy texture
        auto noise = synthesizer.generateNoise(0.3f, 0.5f);
        // Random amplitude jumps
        for (int i = 0; i < noise.getNumSamples(); i += 441)  // Every 10ms
        {
            float jump = (rand() % 100) > 80 ? 2.0f : 0.5f;
            for (int j = 0; j < 441 && (i + j) < noise.getNumSamples(); j++)
            {
                noise.setSample(0, i + j, noise.getSample(0, i + j) * jump);
                noise.setSample(1, i + j, noise.getSample(1, i + j) * jump);
            }
        }
        return noise;
    }

    return juce::AudioBuffer<float>(2, 1);
}

//==============================================================================
// FX Sound Generation
//==============================================================================

juce::AudioBuffer<float> EchoelmusicSignatureSounds::generateFXSound(const juce::String& soundID)
{
    // IMPACTS
    if (soundID == ECHOEL_IMPACT_HEAVY)
        return synthesizer.generateImpact(1.0f, 0.8f);
    else if (soundID == ECHOEL_IMPACT_LIGHT)
        return synthesizer.generateImpact(0.5f, 0.3f);

    // RISERS
    else if (soundID == ECHOEL_RISER_FAST)
        return synthesizer.generateRiser(100.0f, 2000.0f, 1.0f);
    else if (soundID == ECHOEL_RISER_SLOW)
        return synthesizer.generateRiser(100.0f, 2000.0f, 4.0f);
    else if (soundID == ECHOEL_RISER_INTENSE)
        return synthesizer.generateRiser(50.0f, 4000.0f, 2.0f);

    // SWEEPS
    else if (soundID == ECHOEL_SWEEP_UP)
        return synthesizer.generateSweep(100.0f, 10000.0f, 1.5f);
    else if (soundID == ECHOEL_SWEEP_DOWN)
        return synthesizer.generateSweep(10000.0f, 100.0f, 1.5f);

    // WHOOSHES (wide sweeps with noise)
    else if (soundID == ECHOEL_WHOOSH_FAST)
    {
        auto sweep = synthesizer.generateSweep(200.0f, 5000.0f, 0.5f);
        auto noise = synthesizer.generateNoise(0.5f, 0.5f);
        for (int i = 0; i < sweep.getNumSamples(); i++)
        {
            sweep.addSample(0, i, noise.getSample(0, i) * 0.3f);
            sweep.addSample(1, i, noise.getSample(1, i) * 0.3f);
        }
        return sweep;
    }
    else if (soundID == ECHOEL_WHOOSH_SLOW)
    {
        auto sweep = synthesizer.generateSweep(300.0f, 3000.0f, 1.5f);
        auto noise = synthesizer.generateNoise(0.5f, 1.5f);
        for (int i = 0; i < sweep.getNumSamples(); i++)
        {
            sweep.addSample(0, i, noise.getSample(0, i) * 0.2f);
            sweep.addSample(1, i, noise.getSample(1, i) * 0.2f);
        }
        return sweep;
    }

    // TRANSITION
    else if (soundID == ECHOEL_TRANSITION_SMOOTH)
    {
        auto riser = synthesizer.generateRiser(200.0f, 1000.0f, 0.5f);
        auto impact = synthesizer.generateImpact(0.6f, 0.3f);

        // Combine riser with impact at the end
        int offset = riser.getNumSamples() - impact.getNumSamples();
        for (int i = 0; i < impact.getNumSamples(); i++)
        {
            riser.addSample(0, offset + i, impact.getSample(0, i));
            riser.addSample(1, offset + i, impact.getSample(1, i));
        }
        return riser;
    }

    return juce::AudioBuffer<float>(2, 1);
}
