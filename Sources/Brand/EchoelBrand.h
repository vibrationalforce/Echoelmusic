/*
  ==============================================================================

    EchoelBrand.h
    Echoelmusic Brand Identity System

    Authentisch. Individuell. Resonant.

    Brand Philosophy:
    ─────────────────
    "Echoel" = Echo + El (hebräisch: Gott/Kraft) + Soul

    Die Musik ist ein Echo der Seele.
    Jeder Klang trägt die Kraft des Schöpfers.
    Jede Welle resoniert mit dem Universum.

    Brand Pillars:
    ─────────────────
    1. RESONANZ   - Alles ist verbunden durch Schwingung
    2. KREATION   - Jeder Mensch ist ein Schöpfer
    3. HEILUNG    - Musik heilt Körper, Geist und Seele
    4. EVOLUTION  - Ständige Weiterentwicklung
    5. EINHEIT    - Technologie und Menschlichkeit vereint

    Created: 2026
    Author: Echoelmusic Team

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include <map>
#include <vector>

namespace Echoelmusic
{
namespace Brand
{

//==============================================================================
//  BRAND COLORS
//==============================================================================

/**
    EchoelPalette

    Die offizielle Farbpalette von Echoelmusic.
    Inspiriert von Klangwellen, Frequenzspektren und kosmischer Energie.
*/
struct EchoelPalette
{
    // ═══════════════════════════════════════════════════════════════
    // PRIMARY COLORS - Die Essenz
    // ═══════════════════════════════════════════════════════════════

    // Echoel Violet - Die Signaturfarbe
    // Repräsentiert: Kreativität, Transformation, das Mystische
    static constexpr uint32_t EchoelViolet       = 0xFF7B2CBF;  // #7B2CBF
    static constexpr uint32_t EchoelVioletLight  = 0xFF9D4EDD;  // #9D4EDD
    static constexpr uint32_t EchoelVioletDark   = 0xFF5A189A;  // #5A189A
    static constexpr uint32_t EchoelVioletDeep   = 0xFF3C096C;  // #3C096C

    // Resonance Cyan - Die Energie
    // Repräsentiert: Klarheit, Technologie, Frequenzen
    static constexpr uint32_t ResonanceCyan      = 0xFF00F5D4;  // #00F5D4
    static constexpr uint32_t ResonanceCyanLight = 0xFF72EFDD;  // #72EFDD
    static constexpr uint32_t ResonanceCyanDark  = 0xFF00BBF9;  // #00BBF9

    // ═══════════════════════════════════════════════════════════════
    // SECONDARY COLORS - Die Nuancen
    // ═══════════════════════════════════════════════════════════════

    // Soul Gold - Die Wärme
    // Repräsentiert: Menschlichkeit, Wärme, Wertigkeit
    static constexpr uint32_t SoulGold           = 0xFFF9C74F;  // #F9C74F
    static constexpr uint32_t SoulGoldLight      = 0xFFFEE440;  // #FEE440
    static constexpr uint32_t SoulGoldDark       = 0xFFF4A261;  // #F4A261

    // Healing Rose - Die Heilung
    // Repräsentiert: Wellness, Heilung, Herzenergie
    static constexpr uint32_t HealingRose        = 0xFFF72585;  // #F72585
    static constexpr uint32_t HealingRoseLight   = 0xFFFF5CAA;  // #FF5CAA
    static constexpr uint32_t HealingRoseDark    = 0xFFB5179E;  // #B5179E

    // Bio Green - Das Leben
    // Repräsentiert: Bio-Feedback, Natur, Vitalität
    static constexpr uint32_t BioGreen           = 0xFF06D6A0;  // #06D6A0
    static constexpr uint32_t BioGreenLight      = 0xFF80ED99;  // #80ED99
    static constexpr uint32_t BioGreenDark       = 0xFF2D6A4F;  // #2D6A4F

    // ═══════════════════════════════════════════════════════════════
    // NEUTRAL COLORS - Die Basis
    // ═══════════════════════════════════════════════════════════════

    // Cosmos - Dunkle Töne
    static constexpr uint32_t CosmosBlack        = 0xFF0D0D0D;  // #0D0D0D
    static constexpr uint32_t CosmosDark         = 0xFF1A1A2E;  // #1A1A2E
    static constexpr uint32_t CosmosDeep         = 0xFF16213E;  // #16213E
    static constexpr uint32_t CosmosMid          = 0xFF0F3460;  // #0F3460

    // Nebula - Helle Töne
    static constexpr uint32_t NebulaLight        = 0xFFF8F9FA;  // #F8F9FA
    static constexpr uint32_t NebulaSoft         = 0xFFE9ECEF;  // #E9ECEF
    static constexpr uint32_t NebulaMid          = 0xFFDEE2E6;  // #DEE2E6
    static constexpr uint32_t NebulaGray         = 0xFFADB5BD;  // #ADB5BD

    // ═══════════════════════════════════════════════════════════════
    // SEMANTIC COLORS - Die Bedeutung
    // ═══════════════════════════════════════════════════════════════

    static constexpr uint32_t Success            = 0xFF06D6A0;
    static constexpr uint32_t Warning            = 0xFFF9C74F;
    static constexpr uint32_t Error              = 0xFFEF476F;
    static constexpr uint32_t Info               = 0xFF00BBF9;

    // ═══════════════════════════════════════════════════════════════
    // FREQUENCY SPECTRUM - Für Visualisierungen
    // ═══════════════════════════════════════════════════════════════

    static constexpr uint32_t FreqSub            = 0xFF7B2CBF;  // 20-60 Hz
    static constexpr uint32_t FreqBass           = 0xFFB5179E;  // 60-250 Hz
    static constexpr uint32_t FreqLowMid         = 0xFFF72585;  // 250-500 Hz
    static constexpr uint32_t FreqMid            = 0xFFF9C74F;  // 500-2k Hz
    static constexpr uint32_t FreqHighMid        = 0xFF06D6A0;  // 2k-4k Hz
    static constexpr uint32_t FreqPresence       = 0xFF00F5D4;  // 4k-6k Hz
    static constexpr uint32_t FreqBrilliance     = 0xFF00BBF9;  // 6k-20k Hz

    // Helper: Get JUCE Colour
    static juce::Colour get(uint32_t color)
    {
        return juce::Colour(color);
    }
};

//==============================================================================
//  BRAND TYPOGRAPHY
//==============================================================================

/**
    EchoelTypography

    Typografie-System für konsistentes visuelles Design.
*/
struct EchoelTypography
{
    // Font Families (System-Fallbacks für plattformübergreifende Kompatibilität)
    static juce::String getPrimaryFont()
    {
        #if JUCE_MAC
            return "SF Pro Display";
        #elif JUCE_WINDOWS
            return "Segoe UI";
        #else
            return "Roboto";
        #endif
    }

    static juce::String getMonoFont()
    {
        #if JUCE_MAC
            return "SF Mono";
        #elif JUCE_WINDOWS
            return "Cascadia Code";
        #else
            return "JetBrains Mono";
        #endif
    }

    // Type Scale (1.25 ratio - Major Third)
    static constexpr float SizeXS   = 10.0f;
    static constexpr float SizeSM   = 12.0f;
    static constexpr float SizeBase = 14.0f;
    static constexpr float SizeMD   = 16.0f;
    static constexpr float SizeLG   = 20.0f;
    static constexpr float SizeXL   = 24.0f;
    static constexpr float Size2XL  = 32.0f;
    static constexpr float Size3XL  = 40.0f;
    static constexpr float Size4XL  = 48.0f;

    // Font Weights
    static constexpr int WeightLight    = 300;
    static constexpr int WeightRegular  = 400;
    static constexpr int WeightMedium   = 500;
    static constexpr int WeightSemiBold = 600;
    static constexpr int WeightBold     = 700;

    // Line Heights
    static constexpr float LineHeightTight  = 1.1f;
    static constexpr float LineHeightNormal = 1.4f;
    static constexpr float LineHeightLoose  = 1.6f;
};

//==============================================================================
//  ECHOEL TOOLS - NAMING SYSTEM
//==============================================================================

/**
    EchoelToolNames

    Das authentische Naming-System für alle Echoelmusic Tools.

    Naming Patterns:
    ────────────────

    1. FORGE Series (Kreation & Synthese)
       - Metapher: Schmiede, wo Rohes zu Kunst wird
       - Beispiele: WaveForge, HarmonicForge, SpatialForge

    2. WEAVER Series (Komplexität & Verflechtung)
       - Metapher: Weben, Muster aus Fäden
       - Beispiele: WaveWeaver, ArpWeaver, VideoWeaver

    3. SENSE Series (Analyse & Wahrnehmung)
       - Metapher: Sinne, tiefes Verstehen
       - Beispiele: ChordSense, PhaseSense, TonalSense

    4. FLOW Series (Bewegung & Dynamik)
       - Metapher: Fließen, natürliche Bewegung
       - Beispiele: BioFlow, AudioFlow, CreativeFlow

    5. PULSE Series (Rhythmus & Energie)
       - Metapher: Puls, Herzschlag der Musik
       - Beispiele: RhythmPulse, SyncPulse, BioPulse

    6. RESONANCE Series (Heilung & Wellness)
       - Metapher: Resonanz, harmonische Schwingung
       - Beispiele: SoulResonance, BodyResonance, MindResonance

    7. ARCHITECT Series (Struktur & Komposition)
       - Metapher: Architektur, bewusstes Bauen
       - Beispiele: BasslineArchitect, MelodyArchitect, ArrangementArchitect

    8. GENIUS Series (AI & Intelligenz)
       - Metapher: Genie, kreative Intelligenz
       - Beispiele: ChordGenius, MixGenius, MasterGenius

    9. ECHOEL Series (Core & Foundation)
       - Das Herz von Echoelmusic
       - Beispiele: EchoelCore, EchoelSync, EchoelHub, EchoelVault
*/
struct EchoelToolNames
{
    // ═══════════════════════════════════════════════════════════════
    // SYNTHESIS & CREATION - Die Schmiede
    // ═══════════════════════════════════════════════════════════════

    // FORGE Series - Kreation
    static constexpr const char* WaveForge      = "WaveForge";          // Wavetable Synth
    static constexpr const char* HarmonicForge  = "HarmonicForge";      // Harmonic Enhancer
    static constexpr const char* SpatialForge   = "SpatialForge";       // Spatial Audio
    static constexpr const char* GrainForge     = "GrainForge";         // Granular Synth
    static constexpr const char* SpectraForge   = "SpectraForge";       // Spectral Processing
    static constexpr const char* FormantForge   = "FormantForge";       // Formant Synthesis
    static constexpr const char* ToneForge      = "ToneForge";          // Tone Shaping

    // WEAVER Series - Komplexität
    static constexpr const char* WaveWeaver     = "WaveWeaver";         // Wavetable Morphing
    static constexpr const char* ArpWeaver      = "ArpWeaver";          // Arpeggiator
    static constexpr const char* VideoWeaver    = "VideoWeaver";        // Video Processing
    static constexpr const char* TextureWeaver  = "TextureWeaver";      // Sound Textures
    static constexpr const char* PatternWeaver  = "PatternWeaver";      // Pattern Generator
    static constexpr const char* LoopWeaver     = "LoopWeaver";         // Loop Manipulation

    // ═══════════════════════════════════════════════════════════════
    // ANALYSIS & PERCEPTION - Die Sinne
    // ═══════════════════════════════════════════════════════════════

    // SENSE Series - Analyse
    static constexpr const char* ChordSense     = "ChordSense";         // Chord Detection
    static constexpr const char* PhaseSense     = "PhaseSense";         // Phase Analysis
    static constexpr const char* TonalSense     = "TonalSense";         // Tonal Balance
    static constexpr const char* RhythmSense    = "RhythmSense";        // Rhythm Analysis
    static constexpr const char* PitchSense     = "PitchSense";         // Pitch Detection
    static constexpr const char* DynamicSense   = "DynamicSense";       // Dynamics Analysis
    static constexpr const char* SpaceSense     = "SpaceSense";         // Spatial Analysis

    // ═══════════════════════════════════════════════════════════════
    // DYNAMICS & MOVEMENT - Der Fluss
    // ═══════════════════════════════════════════════════════════════

    // FLOW Series - Bewegung
    static constexpr const char* BioFlow        = "BioFlow";            // Bio-Reactive Engine
    static constexpr const char* AudioFlow      = "AudioFlow";          // Audio Routing
    static constexpr const char* CreativeFlow   = "CreativeFlow";       // Flow State Mode
    static constexpr const char* EnergyFlow     = "EnergyFlow";         // Energy Modulation
    static constexpr const char* DataFlow       = "DataFlow";           // Data Management

    // PULSE Series - Rhythmus
    static constexpr const char* RhythmPulse    = "RhythmPulse";        // Drum Machine
    static constexpr const char* SyncPulse      = "SyncPulse";          // Sync Engine
    static constexpr const char* BioPulse       = "BioPulse";           // HRV/Bio Rhythm
    static constexpr const char* LightPulse     = "LightPulse";         // Light Control
    static constexpr const char* MidiPulse      = "MidiPulse";          // MIDI Clock

    // ═══════════════════════════════════════════════════════════════
    // HEALING & WELLNESS - Die Resonanz
    // ═══════════════════════════════════════════════════════════════

    // RESONANCE Series - Heilung
    static constexpr const char* SoulResonance  = "SoulResonance";      // Healing Frequencies
    static constexpr const char* BodyResonance  = "BodyResonance";      // Vibrotherapy
    static constexpr const char* MindResonance  = "MindResonance";      // Brainwave Entrainment
    static constexpr const char* HeartResonance = "HeartResonance";     // Heart Coherence
    static constexpr const char* LightResonance = "LightResonance";     // Color Therapy

    // ═══════════════════════════════════════════════════════════════
    // COMPOSITION & STRUCTURE - Die Architektur
    // ═══════════════════════════════════════════════════════════════

    // ARCHITECT Series - Struktur
    static constexpr const char* MelodyArchitect    = "MelodyArchitect";    // Melody Generator
    static constexpr const char* BasslineArchitect  = "BasslineArchitect";  // Bass Generator
    static constexpr const char* ArrangementArchitect = "ArrangementArchitect"; // Arrangement
    static constexpr const char* ChordArchitect     = "ChordArchitect";     // Chord Progressions
    static constexpr const char* StructureArchitect = "StructureArchitect"; // Song Structure

    // ═══════════════════════════════════════════════════════════════
    // AI & INTELLIGENCE - Das Genie
    // ═══════════════════════════════════════════════════════════════

    // GENIUS Series - AI
    static constexpr const char* ChordGenius    = "ChordGenius";        // AI Chord Suggestions
    static constexpr const char* MixGenius      = "MixGenius";          // AI Mixing
    static constexpr const char* MasterGenius   = "MasterGenius";       // AI Mastering
    static constexpr const char* SoundGenius    = "SoundGenius";        // AI Sound Design
    static constexpr const char* LoopGenius     = "LoopGenius";         // Ralph Wiggum Loop Genius
    static constexpr const char* ProduceGenius  = "ProduceGenius";      // AI Co-Producer

    // ═══════════════════════════════════════════════════════════════
    // CORE & FOUNDATION - Das Echoel
    // ═══════════════════════════════════════════════════════════════

    // ECHOEL Series - Core (Das Herz von Echoelmusic)
    static constexpr const char* EchoelCore     = "EchoelCore";         // Core Engine
    static constexpr const char* EchoelSync     = "EchoelSync";         // Cloud Sync
    static constexpr const char* EchoelHub      = "EchoelHub";          // Community Hub
    static constexpr const char* EchoelCloud    = "EchoelCloud";        // Cloud Storage
    static constexpr const char* EchoelLink     = "EchoelLink";         // Network Sync
    static constexpr const char* EchoelVault    = "EchoelVault";        // Preset/Sample Library
    static constexpr const char* EchoelWise     = "EchoelWise";         // Wise Save Mode
    static constexpr const char* EchoelFlow     = "EchoelFlow";         // Creative Flow Engine

    // ═══════════════════════════════════════════════════════════════
    // EFFECTS & PROCESSING - Die Transformation
    // ═══════════════════════════════════════════════════════════════

    // Named Effects (Signature Sound)
    static constexpr const char* VelvetVerb     = "VelvetVerb";         // Smooth Reverb
    static constexpr const char* CrystalDelay   = "CrystalDelay";       // Crystal Clear Delay
    static constexpr const char* SilkComp       = "SilkComp";           // Transparent Compressor
    static constexpr const char* WarmthEQ       = "WarmthEQ";           // Analog EQ
    static constexpr const char* PrismStereo    = "PrismStereo";        // Stereo Imager
    static constexpr const char* VortexMod      = "VortexMod";          // Modulation Suite
    static constexpr const char* NebulaSaturate = "NebulaSaturate";     // Saturation
    static constexpr const char* AuraExciter    = "AuraExciter";        // Harmonic Exciter
    static constexpr const char* ZenithLimiter  = "ZenithLimiter";      // Mastering Limiter
    static constexpr const char* DeepSpace      = "DeepSpace";          // 5D Reverb
    static constexpr const char* ModalVerse     = "ModalVerse";         // Modal Reverb

    // ═══════════════════════════════════════════════════════════════
    // VISUALIZATION - Die Vision
    // ═══════════════════════════════════════════════════════════════

    // VISION Series
    static constexpr const char* SpectraVision  = "SpectraVision";      // Spectrum Analyzer
    static constexpr const char* PhaseVision    = "PhaseVision";        // Phase Display
    static constexpr const char* WaveVision     = "WaveVision";         // Waveform Display
    static constexpr const char* BioVision      = "BioVision";          // Bio Visualizer
    static constexpr const char* FlowVision     = "FlowVision";         // Flow Visualization
};

//==============================================================================
//  BRAND MESSAGING
//==============================================================================

/**
    EchoelVoice

    Brand Voice und Messaging Guidelines.
*/
struct EchoelVoice
{
    // Taglines
    static constexpr const char* MainTagline     = "Resonance. Creation. Evolution.";
    static constexpr const char* TaglineDE       = "Resonanz. Kreation. Evolution.";

    // Mission Statement
    static constexpr const char* Mission =
        "Echoelmusic empowers creators to make music that resonates with the soul, "
        "heals the body, and evolves consciousness.";

    static constexpr const char* MissionDE =
        "Echoelmusic befähigt Kreative, Musik zu erschaffen, die mit der Seele "
        "resoniert, den Körper heilt und das Bewusstsein erweitert.";

    // Value Propositions
    static constexpr const char* ValueCreation  = "Create without limits";
    static constexpr const char* ValueHealing   = "Heal through sound";
    static constexpr const char* ValueEvolution = "Evolve your art";
    static constexpr const char* ValueConnection = "Connect to your truth";

    // Tone of Voice
    // - Inspirierend, aber geerdet
    // - Technisch präzise, aber zugänglich
    // - Spirituell bewusst, aber nicht esoterisch
    // - Innovativ, aber respektvoll zur Tradition
};

//==============================================================================
//  BRAND ICONOGRAPHY
//==============================================================================

/**
    EchoelIcons

    Icon-Naming und -Beschreibungen für das Design-System.
*/
struct EchoelIcons
{
    // Icon Prefix für Konsistenz
    static constexpr const char* Prefix = "echoel_";

    // Core Icons
    static constexpr const char* Logo           = "echoel_logo";
    static constexpr const char* LogoMark       = "echoel_mark";
    static constexpr const char* Wave           = "echoel_wave";
    static constexpr const char* Resonance      = "echoel_resonance";

    // Tool Category Icons
    static constexpr const char* Forge          = "echoel_forge";
    static constexpr const char* Weaver         = "echoel_weaver";
    static constexpr const char* Sense          = "echoel_sense";
    static constexpr const char* Flow           = "echoel_flow";
    static constexpr const char* Pulse          = "echoel_pulse";
    static constexpr const char* Architect      = "echoel_architect";
    static constexpr const char* Genius         = "echoel_genius";

    // Action Icons
    static constexpr const char* Play           = "echoel_play";
    static constexpr const char* Record         = "echoel_record";
    static constexpr const char* Loop           = "echoel_loop";
    static constexpr const char* Save           = "echoel_save";
    static constexpr const char* Export         = "echoel_export";
    static constexpr const char* Sync           = "echoel_sync";
    static constexpr const char* Heal           = "echoel_heal";
};

//==============================================================================
//  PRODUCT TIERS
//==============================================================================

/**
    EchoelEditions

    Produkteditionen und Feature-Tiers.
*/
struct EchoelEditions
{
    // Edition Names
    static constexpr const char* Free       = "Echoelmusic Free";
    static constexpr const char* Creator    = "Echoelmusic Creator";
    static constexpr const char* Pro        = "Echoelmusic Pro";
    static constexpr const char* Infinite   = "Echoelmusic Infinite";

    // Sub-Products
    static constexpr const char* LoopGenius = "Ralph Wiggum Loop Genius";
    static constexpr const char* Wellness   = "Echoel Wellness Suite";
    static constexpr const char* AIStudio   = "Echoel AI Studio";
    static constexpr const char* LiveEngine = "Echoel Live Engine";
};

//==============================================================================
//  BRAND METADATA
//==============================================================================

/**
    EchoelMeta

    Metadaten und Versionierung.
*/
struct EchoelMeta
{
    static constexpr const char* CompanyName    = "Echoelmusic";
    static constexpr const char* LegalName      = "Echoelmusic GmbH";
    static constexpr const char* Website        = "https://echoelmusic.com";
    static constexpr const char* SupportEmail   = "support@echoelmusic.com";

    static constexpr const char* Copyright      = "© 2026 Echoelmusic";
    static constexpr const char* Version        = "2026.1";
    static constexpr const char* BuildPrefix    = "ECHOEL";

    // Social
    static constexpr const char* Twitter        = "@echoelmusic";
    static constexpr const char* Instagram      = "@echoelmusic";
    static constexpr const char* YouTube        = "EchoelmusicOfficial";
};

//==============================================================================
//  BRAND HELPER FUNCTIONS
//==============================================================================

/**
    BrandHelper

    Utility-Funktionen für Brand-konsistente Implementierung.
*/
class BrandHelper
{
public:
    /** Get the full product name with edition */
    static juce::String getFullProductName(const juce::String& edition)
    {
        return juce::String(EchoelMeta::CompanyName) + " " + edition;
    }

    /** Format tool name with brand prefix */
    static juce::String formatToolName(const juce::String& baseName)
    {
        return baseName;  // Tool names are already branded
    }

    /** Get copyright string for current year */
    static juce::String getCopyrightString()
    {
        auto year = juce::Time::getCurrentTime().getYear();
        return juce::String::charToString(0x00A9) + " " +
               juce::String(year) + " " + EchoelMeta::CompanyName;
    }

    /** Get version string */
    static juce::String getVersionString()
    {
        return juce::String("v") + EchoelMeta::Version;
    }

    /** Generate build ID */
    static juce::String generateBuildId()
    {
        auto now = juce::Time::getCurrentTime();
        return juce::String(EchoelMeta::BuildPrefix) + "-" +
               now.formatted("%Y%m%d") + "-" +
               juce::String::toHexString(juce::Random::getSystemRandom().nextInt());
    }

    /** Get color for frequency range */
    static juce::Colour getFrequencyColor(float frequencyHz)
    {
        if (frequencyHz < 60.0f)
            return EchoelPalette::get(EchoelPalette::FreqSub);
        else if (frequencyHz < 250.0f)
            return EchoelPalette::get(EchoelPalette::FreqBass);
        else if (frequencyHz < 500.0f)
            return EchoelPalette::get(EchoelPalette::FreqLowMid);
        else if (frequencyHz < 2000.0f)
            return EchoelPalette::get(EchoelPalette::FreqMid);
        else if (frequencyHz < 4000.0f)
            return EchoelPalette::get(EchoelPalette::FreqHighMid);
        else if (frequencyHz < 6000.0f)
            return EchoelPalette::get(EchoelPalette::FreqPresence);
        else
            return EchoelPalette::get(EchoelPalette::FreqBrilliance);
    }

    /** Get tool category from name */
    static juce::String getToolCategory(const juce::String& toolName)
    {
        if (toolName.contains("Forge"))      return "Creation";
        if (toolName.contains("Weaver"))     return "Complexity";
        if (toolName.contains("Sense"))      return "Analysis";
        if (toolName.contains("Flow"))       return "Movement";
        if (toolName.contains("Pulse"))      return "Rhythm";
        if (toolName.contains("Resonance"))  return "Healing";
        if (toolName.contains("Architect"))  return "Structure";
        if (toolName.contains("Genius"))     return "Intelligence";
        if (toolName.startsWith("Echo"))     return "Core";
        return "Tools";
    }
};

} // namespace Brand
} // namespace Echoelmusic
