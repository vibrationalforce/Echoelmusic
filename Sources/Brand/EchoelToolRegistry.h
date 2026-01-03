/*
  ==============================================================================

    EchoelToolRegistry.h
    Echoelmusic Tool Registry & Naming Reference

    Zentrales Register aller Echoelmusic Tools mit:
    - Konsistentes Naming
    - Tool-Metadaten
    - Kategorisierung
    - Display-Namen
    - Beschreibungen

    Created: 2026
    Author: Echoelmusic Team

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include "EchoelBrand.h"
#include <map>
#include <vector>

namespace Echoelmusic
{
namespace Brand
{

//==============================================================================
/** Tool-Kategorie für Organisation */
enum class ToolCategory
{
    // Core
    Core,               // Fundamentale Systeme

    // Creation
    Synthesis,          // Klangerzeugung
    Effects,            // Audioeffekte
    MIDI,               // MIDI-Tools

    // Analysis
    Metering,           // Messung & Analyse
    Visualization,      // Visualisierung

    // Composition
    Composition,        // Kompositionswerkzeuge
    Arrangement,        // Arrangement

    // AI
    Intelligence,       // AI & ML Tools

    // Wellness
    Healing,            // Wellness & Healing

    // Bio
    BioFeedback,        // Bio-Integration

    // System
    Hardware,           // Hardware-Integration
    Network,            // Cloud & Netzwerk
    Development         // Entwicklung
};

//==============================================================================
/** Tool-Typ für Unterscheidung */
enum class ToolType
{
    Instrument,         // Klangerzeuger
    Effect,             // Audioeffekt
    Analyzer,           // Analysetool
    Utility,            // Hilfswerkzeug
    Generator,          // Pattern/Sequenz Generator
    Processor,          // Audio Processor
    System              // Systemtool
};

//==============================================================================
/** Tool-Eintrag mit allen Metadaten */
struct ToolEntry
{
    juce::String id;                    // Interner Identifier
    juce::String brandName;             // Offizieller Name
    juce::String displayName;           // Anzeigename (kann gleich sein)
    juce::String shortName;             // Kurzname für UI
    juce::String description;           // Kurzbeschreibung
    juce::String descriptionDE;         // Deutsche Beschreibung

    ToolCategory category;
    ToolType type;
    juce::String series;                // Forge, Weaver, etc.

    juce::StringArray tags;             // Suchbegriffe
    juce::String iconId;                // Icon-Referenz

    bool isPremium = false;             // Nur in Pro/Infinite
    bool isExperimental = false;        // Beta/Preview
    bool isWellness = true;             // Hat Wellness-Disclaimer
};

//==============================================================================
/**
    EchoelToolRegistry

    Zentrales Register aller Tools mit Naming und Metadaten.
*/
class EchoelToolRegistry
{
public:
    static EchoelToolRegistry& getInstance()
    {
        static EchoelToolRegistry instance;
        return instance;
    }

    //==========================================================================
    // Tool Lookup

    /** Get tool by ID */
    const ToolEntry* getToolById(const juce::String& id) const
    {
        auto it = tools.find(id);
        return it != tools.end() ? &it->second : nullptr;
    }

    /** Get tools by category */
    std::vector<ToolEntry> getToolsByCategory(ToolCategory category) const
    {
        std::vector<ToolEntry> result;
        for (const auto& [id, tool] : tools)
        {
            if (tool.category == category)
                result.push_back(tool);
        }
        return result;
    }

    /** Get tools by series */
    std::vector<ToolEntry> getToolsBySeries(const juce::String& series) const
    {
        std::vector<ToolEntry> result;
        for (const auto& [id, tool] : tools)
        {
            if (tool.series == series)
                result.push_back(tool);
        }
        return result;
    }

    /** Get all tool IDs */
    juce::StringArray getAllToolIds() const
    {
        juce::StringArray ids;
        for (const auto& [id, tool] : tools)
        {
            ids.add(id);
        }
        return ids;
    }

    //==========================================================================
    // Name Resolution

    /** Get display name for a tool ID */
    juce::String getDisplayName(const juce::String& id) const
    {
        auto* tool = getToolById(id);
        return tool ? tool->displayName : id;
    }

    /** Get short name for a tool ID */
    juce::String getShortName(const juce::String& id) const
    {
        auto* tool = getToolById(id);
        return tool ? tool->shortName : id;
    }

    /** Get brand name for a tool ID */
    juce::String getBrandName(const juce::String& id) const
    {
        auto* tool = getToolById(id);
        return tool ? tool->brandName : id;
    }

private:
    EchoelToolRegistry()
    {
        registerAllTools();
    }

    void registerAllTools()
    {
        // ═══════════════════════════════════════════════════════════════
        // FORGE SERIES - Synthesis & Creation
        // ═══════════════════════════════════════════════════════════════

        registerTool({
            "waveforge", "WaveForge", "WaveForge", "WForge",
            "Wavetable synthesizer with morphing capabilities",
            "Wavetable-Synthesizer mit Morphing-Funktionen",
            ToolCategory::Synthesis, ToolType::Instrument, "Forge",
            {"wavetable", "synth", "morphing", "oscillator"},
            "echoel_forge", false, false, false
        });

        registerTool({
            "harmonicforge", "HarmonicForge", "HarmonicForge", "HForge",
            "Harmonic enhancement and generation",
            "Harmonische Anreicherung und Erzeugung",
            ToolCategory::Effects, ToolType::Effect, "Forge",
            {"harmonics", "saturation", "enhancement", "exciter"},
            "echoel_forge", false, false, false
        });

        registerTool({
            "spatialforge", "SpatialForge", "SpatialForge", "SForge",
            "Spatial audio processing (Dolby Atmos, Ambisonics)",
            "Räumliche Audioverarbeitung (Dolby Atmos, Ambisonics)",
            ToolCategory::Effects, ToolType::Processor, "Forge",
            {"spatial", "atmos", "ambisonics", "3d", "surround"},
            "echoel_forge", true, false, false
        });

        registerTool({
            "grainforge", "GrainForge", "GrainForge", "GForge",
            "Granular synthesis engine",
            "Granularsynthese-Engine",
            ToolCategory::Synthesis, ToolType::Instrument, "Forge",
            {"granular", "texture", "ambient", "experimental"},
            "echoel_forge", false, false, false
        });

        registerTool({
            "spectraforge", "SpectraForge", "SpectraForge", "SpForge",
            "Spectral processing and resynthesis",
            "Spektrale Verarbeitung und Resynthese",
            ToolCategory::Effects, ToolType::Processor, "Forge",
            {"spectral", "fft", "resynthesis", "creative"},
            "echoel_forge", true, false, false
        });

        registerTool({
            "toneforge", "ToneForge", "ToneForge", "TForge",
            "Tone shaping and character",
            "Klangformung und Charakter",
            ToolCategory::Effects, ToolType::Effect, "Forge",
            {"tone", "shaping", "eq", "character"},
            "echoel_forge", false, false, false
        });

        // ═══════════════════════════════════════════════════════════════
        // WEAVER SERIES - Complex Patterns
        // ═══════════════════════════════════════════════════════════════

        registerTool({
            "waveweaver", "WaveWeaver", "WaveWeaver", "WWeaver",
            "Complex wavetable morphing and modulation",
            "Komplexes Wavetable-Morphing und Modulation",
            ToolCategory::Synthesis, ToolType::Instrument, "Weaver",
            {"wavetable", "modulation", "morphing", "complex"},
            "echoel_weaver", false, false, false
        });

        registerTool({
            "arpweaver", "ArpWeaver", "ArpWeaver", "AWeaver",
            "Advanced arpeggiator with pattern weaving",
            "Erweiterter Arpeggiator mit Pattern-Verflechtung",
            ToolCategory::MIDI, ToolType::Generator, "Weaver",
            {"arp", "arpeggiator", "pattern", "sequence"},
            "echoel_weaver", false, false, false
        });

        registerTool({
            "videoweaver", "VideoWeaver", "VideoWeaver", "VWeaver",
            "Video effects and audio-reactive visuals",
            "Videoeffekte und audioreaktive Visuals",
            ToolCategory::Visualization, ToolType::Processor, "Weaver",
            {"video", "visual", "reactive", "effects"},
            "echoel_weaver", true, false, false
        });

        registerTool({
            "patternweaver", "PatternWeaver", "PatternWeaver", "PWeaver",
            "AI-powered pattern generation",
            "KI-gestützte Pattern-Generierung",
            ToolCategory::MIDI, ToolType::Generator, "Weaver",
            {"pattern", "ai", "generator", "drums", "melody"},
            "echoel_weaver", false, false, false
        });

        registerTool({
            "loopweaver", "LoopWeaver", "LoopWeaver", "LWeaver",
            "Live loop manipulation and transformation",
            "Live-Loop-Manipulation und Transformation",
            ToolCategory::Effects, ToolType::Processor, "Weaver",
            {"loop", "live", "manipulation", "transform"},
            "echoel_weaver", false, false, false
        });

        // ═══════════════════════════════════════════════════════════════
        // SENSE SERIES - Analysis
        // ═══════════════════════════════════════════════════════════════

        registerTool({
            "chordsense", "ChordSense", "ChordSense", "CSense",
            "Real-time chord detection and analysis",
            "Echtzeit-Akkorderkennung und -analyse",
            ToolCategory::Metering, ToolType::Analyzer, "Sense",
            {"chord", "detection", "analysis", "harmony"},
            "echoel_sense", false, false, false
        });

        registerTool({
            "phasesense", "PhaseSense", "PhaseSense", "PSense",
            "Phase correlation and stereo analysis",
            "Phasenkorrelation und Stereoanalyse",
            ToolCategory::Metering, ToolType::Analyzer, "Sense",
            {"phase", "correlation", "stereo", "analysis"},
            "echoel_sense", false, false, false
        });

        registerTool({
            "tonalsense", "TonalSense", "TonalSense", "TSense",
            "Tonal balance and frequency analysis",
            "Tonale Balance und Frequenzanalyse",
            ToolCategory::Metering, ToolType::Analyzer, "Sense",
            {"tonal", "balance", "frequency", "mastering"},
            "echoel_sense", false, false, false
        });

        registerTool({
            "rhythmsense", "RhythmSense", "RhythmSense", "RSense",
            "Rhythm and groove analysis",
            "Rhythmus- und Groove-Analyse",
            ToolCategory::Metering, ToolType::Analyzer, "Sense",
            {"rhythm", "groove", "tempo", "beat"},
            "echoel_sense", false, false, false
        });

        registerTool({
            "spacesense", "SpaceSense", "SpaceSense", "SpSense",
            "Spatial and stereo field analysis",
            "Räumliche und Stereofeld-Analyse",
            ToolCategory::Metering, ToolType::Analyzer, "Sense",
            {"spatial", "stereo", "width", "3d"},
            "echoel_sense", false, false, false
        });

        // ═══════════════════════════════════════════════════════════════
        // GENIUS SERIES - AI Intelligence
        // ═══════════════════════════════════════════════════════════════

        registerTool({
            "chordgenius", "ChordGenius", "ChordGenius", "CGenius",
            "AI-powered chord progression suggestions",
            "KI-gestützte Akkordfolgen-Vorschläge",
            ToolCategory::Intelligence, ToolType::Generator, "Genius",
            {"chord", "ai", "progression", "composition"},
            "echoel_genius", false, false, false
        });

        registerTool({
            "mixgenius", "MixGenius", "MixGenius", "MGenius",
            "AI auto-mixing assistant",
            "KI-Auto-Mixing-Assistent",
            ToolCategory::Intelligence, ToolType::Processor, "Genius",
            {"mix", "ai", "auto", "assistant"},
            "echoel_genius", true, false, false
        });

        registerTool({
            "mastergenius", "MasterGenius", "MasterGenius", "MaGenius",
            "AI mastering with target matching",
            "KI-Mastering mit Zielabgleich",
            ToolCategory::Intelligence, ToolType::Processor, "Genius",
            {"master", "ai", "loudness", "streaming"},
            "echoel_genius", true, false, false
        });

        registerTool({
            "loopgenius", "LoopGenius", "Ralph Wiggum Loop Genius", "RW",
            "The Ralph Wiggum Loop Genius creative looper",
            "Der Ralph Wiggum Loop Genius Creative Looper",
            ToolCategory::Intelligence, ToolType::Processor, "Genius",
            {"loop", "genius", "ralph", "wiggum", "creative"},
            "echoel_genius", false, false, false
        });

        registerTool({
            "producegenius", "ProduceGenius", "AI Co-Producer", "PGenius",
            "AI-powered production assistant",
            "KI-gestützter Produktionsassistent",
            ToolCategory::Intelligence, ToolType::Utility, "Genius",
            {"produce", "ai", "assistant", "llm", "chat"},
            "echoel_genius", true, false, false
        });

        // ═══════════════════════════════════════════════════════════════
        // RESONANCE SERIES - Healing & Wellness
        // ═══════════════════════════════════════════════════════════════

        registerTool({
            "soulresonance", "SoulResonance", "SoulResonance", "SRes",
            "Healing frequency generator (Entertainment)",
            "Heilfrequenz-Generator (Unterhaltung)",
            ToolCategory::Healing, ToolType::Generator, "Resonance",
            {"healing", "frequency", "wellness", "solfeggio"},
            "echoel_resonance", false, false, true
        });

        registerTool({
            "bodyresonance", "BodyResonance", "BodyResonance", "BRes",
            "Vibrotherapy sound system (Entertainment)",
            "Vibrotherapie-Soundsystem (Unterhaltung)",
            ToolCategory::Healing, ToolType::Generator, "Resonance",
            {"vibration", "body", "therapy", "frequency"},
            "echoel_resonance", false, false, true
        });

        registerTool({
            "mindresonance", "MindResonance", "MindResonance", "MRes",
            "Brainwave entrainment audio (Entertainment)",
            "Brainwave-Entrainment-Audio (Unterhaltung)",
            ToolCategory::Healing, ToolType::Generator, "Resonance",
            {"brainwave", "entrainment", "binaural", "isochronic"},
            "echoel_resonance", false, false, true
        });

        registerTool({
            "heartresonance", "HeartResonance", "HeartResonance", "HRes",
            "Heart coherence audio (Entertainment)",
            "Herzkohärenz-Audio (Unterhaltung)",
            ToolCategory::Healing, ToolType::Generator, "Resonance",
            {"heart", "coherence", "hrv", "breathing"},
            "echoel_resonance", false, false, true
        });

        registerTool({
            "lightresonance", "LightResonance", "LightResonance", "LRes",
            "Color therapy lighting (Atmosphere)",
            "Farbtherapie-Beleuchtung (Atmosphäre)",
            ToolCategory::Healing, ToolType::Utility, "Resonance",
            {"light", "color", "therapy", "chromotherapy"},
            "echoel_resonance", false, false, true
        });

        // ═══════════════════════════════════════════════════════════════
        // FLOW SERIES - Bio & Movement
        // ═══════════════════════════════════════════════════════════════

        registerTool({
            "bioflow", "BioFlow", "BioFlow", "BFlow",
            "Bio-reactive audio engine",
            "Bio-reaktive Audio-Engine",
            ToolCategory::BioFeedback, ToolType::Processor, "Flow",
            {"bio", "reactive", "hrv", "wearable"},
            "echoel_flow", false, false, false
        });

        registerTool({
            "creativeflow", "CreativeFlow", "CreativeFlow", "CFlow",
            "Flow state optimization mode",
            "Flow-State-Optimierungsmodus",
            ToolCategory::Intelligence, ToolType::Utility, "Flow",
            {"flow", "creative", "focus", "productivity"},
            "echoel_flow", false, false, false
        });

        registerTool({
            "energyflow", "EnergyFlow", "EnergyFlow", "EFlow",
            "Energy-based modulation routing",
            "Energiebasiertes Modulations-Routing",
            ToolCategory::BioFeedback, ToolType::Processor, "Flow",
            {"energy", "modulation", "routing", "dynamic"},
            "echoel_flow", false, false, false
        });

        // ═══════════════════════════════════════════════════════════════
        // PULSE SERIES - Rhythm & Sync
        // ═══════════════════════════════════════════════════════════════

        registerTool({
            "rhythmpulse", "RhythmPulse", "RhythmPulse", "RPulse",
            "Advanced drum machine and sequencer",
            "Erweiterter Drum Machine und Sequenzer",
            ToolCategory::Synthesis, ToolType::Instrument, "Pulse",
            {"drums", "machine", "sequencer", "808", "909"},
            "echoel_pulse", false, false, false
        });

        registerTool({
            "syncpulse", "SyncPulse", "SyncPulse", "SPulse",
            "Master clock and sync engine",
            "Master-Clock und Sync-Engine",
            ToolCategory::Hardware, ToolType::Utility, "Pulse",
            {"sync", "clock", "midi", "link", "ableton"},
            "echoel_pulse", false, false, false
        });

        registerTool({
            "biopulse", "BioPulse", "BioPulse", "BPulse",
            "Heart rate to tempo synchronization",
            "Herzfrequenz-zu-Tempo-Synchronisation",
            ToolCategory::BioFeedback, ToolType::Processor, "Pulse",
            {"bio", "heart", "tempo", "sync", "hrv"},
            "echoel_pulse", false, false, false
        });

        registerTool({
            "lightpulse", "LightPulse", "LightPulse", "LPulse",
            "DMX and lighting control",
            "DMX- und Lichtsteuerung",
            ToolCategory::Hardware, ToolType::Utility, "Pulse",
            {"light", "dmx", "laser", "control"},
            "echoel_pulse", true, false, false
        });

        // ═══════════════════════════════════════════════════════════════
        // ARCHITECT SERIES - Composition
        // ═══════════════════════════════════════════════════════════════

        registerTool({
            "melodyarchitect", "MelodyArchitect", "MelodyArchitect", "MArch",
            "AI melody generation with scale awareness",
            "KI-Melodie-Generierung mit Tonarterkennung",
            ToolCategory::Composition, ToolType::Generator, "Architect",
            {"melody", "ai", "generator", "composition"},
            "echoel_architect", false, false, false
        });

        registerTool({
            "basslinearchitect", "BasslineArchitect", "BasslineArchitect", "BArch",
            "Intelligent bassline generator",
            "Intelligenter Bassline-Generator",
            ToolCategory::Composition, ToolType::Generator, "Architect",
            {"bass", "bassline", "generator", "pattern"},
            "echoel_architect", false, false, false
        });

        registerTool({
            "chordarchitect", "ChordArchitect", "ChordArchitect", "CArch",
            "Chord progression builder",
            "Akkordfolgen-Builder",
            ToolCategory::Composition, ToolType::Generator, "Architect",
            {"chord", "progression", "builder", "harmony"},
            "echoel_architect", false, false, false
        });

        registerTool({
            "arrangementarchitect", "ArrangementArchitect", "ArrangementArchitect", "AArch",
            "Song structure and arrangement assistant",
            "Song-Struktur- und Arrangement-Assistent",
            ToolCategory::Arrangement, ToolType::Utility, "Architect",
            {"arrangement", "structure", "song", "assistant"},
            "echoel_architect", true, false, false
        });

        // ═══════════════════════════════════════════════════════════════
        // ECHOEL SERIES - Core (Das Herz von Echoelmusic)
        // ═══════════════════════════════════════════════════════════════

        registerTool({
            "echoelcore", "EchoelCore", "EchoelCore", "Core",
            "Central system engine - the heart of Echoelmusic",
            "Zentrale System-Engine - das Herz von Echoelmusic",
            ToolCategory::Core, ToolType::System, "Echoel",
            {"core", "engine", "system", "central", "echoel"},
            "echoel_logo", false, false, false
        });

        registerTool({
            "echoelsync", "EchoelSync", "EchoelSync", "Sync",
            "Cloud synchronization service",
            "Cloud-Synchronisierungsdienst",
            ToolCategory::Network, ToolType::Utility, "Echoel",
            {"cloud", "sync", "backup", "storage"},
            "echoel_sync", false, false, false
        });

        registerTool({
            "echoelhub", "EchoelHub", "EchoelHub", "Hub",
            "Community and collaboration hub",
            "Community- und Kollaborations-Hub",
            ToolCategory::Network, ToolType::Utility, "Echoel",
            {"community", "collaboration", "share", "social"},
            "echoel_hub", false, false, false
        });

        registerTool({
            "echoelvault", "EchoelVault", "EchoelVault", "Vault",
            "Preset and sample library",
            "Preset- und Sample-Bibliothek",
            ToolCategory::Core, ToolType::Utility, "Echoel",
            {"preset", "sample", "library", "content"},
            "echoel_vault", false, false, false
        });

        registerTool({
            "echoelwise", "EchoelWise", "EchoelWise", "Wise",
            "Intelligent session saving with Wise Save Mode",
            "Intelligentes Session-Speichern mit Wise Save Mode",
            ToolCategory::Core, ToolType::Utility, "Echoel",
            {"save", "wise", "session", "snapshot", "recovery"},
            "echoel_save", false, false, false
        });

        registerTool({
            "echoelflow", "EchoelFlow", "EchoelFlow", "Flow",
            "Creative flow state optimization",
            "Kreativer Flow-State-Optimierung",
            ToolCategory::Core, ToolType::Utility, "Echoel",
            {"flow", "creative", "state", "focus"},
            "echoel_flow", false, false, false
        });

        // ═══════════════════════════════════════════════════════════════
        // SIGNATURE EFFECTS - Named Effects
        // ═══════════════════════════════════════════════════════════════

        registerTool({
            "velvetverb", "VelvetVerb", "VelvetVerb", "VVerb",
            "Smooth, lush reverb",
            "Sanfter, üppiger Reverb",
            ToolCategory::Effects, ToolType::Effect, "Signature",
            {"reverb", "smooth", "lush", "ambient"},
            "echoel_effect", false, false, false
        });

        registerTool({
            "crystaldelay", "CrystalDelay", "CrystalDelay", "CDelay",
            "Crystal clear delay with modulation",
            "Kristallklarer Delay mit Modulation",
            ToolCategory::Effects, ToolType::Effect, "Signature",
            {"delay", "crystal", "modulation", "ping-pong"},
            "echoel_effect", false, false, false
        });

        registerTool({
            "silkcomp", "SilkComp", "SilkComp", "SComp",
            "Transparent, silky compression",
            "Transparente, seidige Kompression",
            ToolCategory::Effects, ToolType::Effect, "Signature",
            {"compressor", "transparent", "opto", "smooth"},
            "echoel_effect", false, false, false
        });

        registerTool({
            "warmeq", "WarmthEQ", "WarmthEQ", "WEQ",
            "Analog-style warmth EQ",
            "Analoger Wärme-EQ",
            ToolCategory::Effects, ToolType::Effect, "Signature",
            {"eq", "analog", "warm", "vintage"},
            "echoel_effect", false, false, false
        });

        registerTool({
            "prismstereo", "PrismStereo", "PrismStereo", "Prism",
            "Stereo imaging and width control",
            "Stereo-Imaging und Breitensteuerung",
            ToolCategory::Effects, ToolType::Effect, "Signature",
            {"stereo", "width", "imaging", "spatial"},
            "echoel_effect", false, false, false
        });

        registerTool({
            "deepspace", "DeepSpace", "DeepSpace", "DSpace",
            "5D immersive reverb",
            "5D immersiver Reverb",
            ToolCategory::Effects, ToolType::Effect, "Signature",
            {"reverb", "5d", "immersive", "atmos", "spatial"},
            "echoel_effect", true, false, false
        });

        registerTool({
            "modalverse", "ModalVerse", "ModalVerse", "Modal",
            "Modal reverb with musical tempering",
            "Modaler Reverb mit musikalischer Temperierung",
            ToolCategory::Effects, ToolType::Effect, "Signature",
            {"reverb", "modal", "resonance", "temperament"},
            "echoel_effect", true, false, false
        });

        registerTool({
            "zenithlimiter", "ZenithLimiter", "ZenithLimiter", "Zenith",
            "Mastering limiter with true peak control",
            "Mastering-Limiter mit True-Peak-Kontrolle",
            ToolCategory::Effects, ToolType::Effect, "Signature",
            {"limiter", "mastering", "loudness", "true-peak"},
            "echoel_effect", false, false, false
        });

        // ═══════════════════════════════════════════════════════════════
        // VISION SERIES - Visualization
        // ═══════════════════════════════════════════════════════════════

        registerTool({
            "spectravision", "SpectraVision", "SpectraVision", "SpVision",
            "Advanced spectrum analyzer",
            "Erweiterter Spektrumanalysator",
            ToolCategory::Visualization, ToolType::Analyzer, "Vision",
            {"spectrum", "analyzer", "fft", "frequency"},
            "echoel_vision", false, false, false
        });

        registerTool({
            "biovision", "BioVision", "BioVision", "BVision",
            "Bio-data visualization",
            "Bio-Daten-Visualisierung",
            ToolCategory::Visualization, ToolType::Analyzer, "Vision",
            {"bio", "visualization", "hrv", "wearable"},
            "echoel_vision", false, false, false
        });

        registerTool({
            "flowvision", "FlowVision", "FlowVision", "FVision",
            "Creative flow visualization",
            "Kreative Flow-Visualisierung",
            ToolCategory::Visualization, ToolType::Analyzer, "Vision",
            {"flow", "visualization", "creative", "state"},
            "echoel_vision", false, false, false
        });
    }

    void registerTool(const ToolEntry& entry)
    {
        tools[entry.id] = entry;
    }

    std::map<juce::String, ToolEntry> tools;
};

//==============================================================================
/** Helper für schnellen Tool-Zugriff */
inline juce::String GetToolDisplayName(const juce::String& id)
{
    return EchoelToolRegistry::getInstance().getDisplayName(id);
}

inline juce::String GetToolBrandName(const juce::String& id)
{
    return EchoelToolRegistry::getInstance().getBrandName(id);
}

} // namespace Brand
} // namespace Echoelmusic
