// DAWOptimizer.h - Host-Specific DAW Optimizations
// Auto-detects and optimizes for Ableton, Logic, Pro Tools, Reaper, Cubase, FL Studio, etc.
#pragma once

#include "../Common/GlobalWarningFixes.h"
#include <JuceHeader.h>

namespace Echoel {

class DAWOptimizer {
public:
    // Detected DAW types
    enum class DAWType {
        Unknown,
        AbletonLive,
        LogicPro,
        ProTools,
        Reaper,
        Cubase,
        StudioOne,
        FLStudio,
        Bitwig,
        SteinbergNuendo,
        AvidMediaComposer,
        AdobeAudition,
        HarrisonMixbus,
        Ardour
    };

    struct OptimizationSettings {
        int preferredBufferSize{512};
        int latencySamples{0};
        bool enableMPE{false};
        bool enableSurroundSound{false};
        bool enableSmartTempo{false};
        bool enableDelayCompensation{true};
        bool enableMultiThreading{true};
        float sampleRate{48000.0f};
        bool useAutomationGestures{true};
        bool highPrecisionMode{false};
        juce::String hostSpecificNotes;
    };

    DAWOptimizer() {
        detectHost();
        applyOptimizations();
    }

    DAWType getDetectedDAW() const noexcept { return currentDAW; }

    const OptimizationSettings& getSettings() const noexcept { return settings; }

    juce::String getDAWName() const {
        switch (currentDAW) {
            case DAWType::AbletonLive:      return "Ableton Live";
            case DAWType::LogicPro:         return "Logic Pro";
            case DAWType::ProTools:         return "Pro Tools";
            case DAWType::Reaper:           return "REAPER";
            case DAWType::Cubase:           return "Cubase";
            case DAWType::StudioOne:        return "Studio One";
            case DAWType::FLStudio:         return "FL Studio";
            case DAWType::Bitwig:           return "Bitwig Studio";
            case DAWType::SteinbergNuendo:  return "Nuendo";
            case DAWType::AvidMediaComposer: return "Media Composer";
            case DAWType::AdobeAudition:    return "Adobe Audition";
            case DAWType::HarrisonMixbus:   return "Harrison Mixbus";
            case DAWType::Ardour:           return "Ardour";
            default:                        return "Unknown Host";
        }
    }

    void applyOptimizations() {
        switch (currentDAW) {
            case DAWType::AbletonLive:
                optimizeForAbleton();
                break;
            case DAWType::LogicPro:
                optimizeForLogic();
                break;
            case DAWType::ProTools:
                optimizeForProTools();
                break;
            case DAWType::Reaper:
                optimizeForReaper();
                break;
            case DAWType::Cubase:
                optimizeForCubase();
                break;
            case DAWType::StudioOne:
                optimizeForStudioOne();
                break;
            case DAWType::FLStudio:
                optimizeForFLStudio();
                break;
            case DAWType::Bitwig:
                optimizeForBitwig();
                break;
            default:
                applyDefaultOptimizations();
                break;
        }

        ECHOEL_TRACE("DAW Optimizer: Detected " << getDAWName() <<
                    " - Buffer: " << settings.preferredBufferSize <<
                    ", Latency: " << settings.latencySamples);
    }

private:
    DAWType currentDAW{DAWType::Unknown};
    OptimizationSettings settings;
    juce::PluginHostType hostType;

    void detectHost() {
        if (hostType.isAbletonLive()) {
            currentDAW = DAWType::AbletonLive;
        } else if (hostType.isLogic()) {
            currentDAW = DAWType::LogicPro;
        } else if (hostType.isProTools()) {
            currentDAW = DAWType::ProTools;
        } else if (hostType.isReaper()) {
            currentDAW = DAWType::Reaper;
        } else if (hostType.isCubase()) {
            currentDAW = DAWType::Cubase;
        } else if (hostType.isStudioOne()) {
            currentDAW = DAWType::StudioOne;
        } else if (hostType.isFruityLoops()) {
            currentDAW = DAWType::FLStudio;
        } else if (hostType.isBitwig()) {
            currentDAW = DAWType::Bitwig;
        } else if (hostType.isSteinberg()) {
            // Could be Cubase or Nuendo
            auto name = hostType.getHostDescription();
            if (name.containsIgnoreCase("nuendo")) {
                currentDAW = DAWType::SteinbergNuendo;
            } else {
                currentDAW = DAWType::Cubase;
            }
        } else if (hostType.isAvidProTools()) {
            currentDAW = DAWType::ProTools;
        } else if (hostType.isWavelab()) {
            currentDAW = DAWType::Cubase; // Steinberg family
        } else {
            // Check host description for other DAWs
            auto name = hostType.getHostDescription();
            if (name.containsIgnoreCase("adobe audition")) {
                currentDAW = DAWType::AdobeAudition;
            } else if (name.containsIgnoreCase("mixbus")) {
                currentDAW = DAWType::HarrisonMixbus;
            } else if (name.containsIgnoreCase("ardour")) {
                currentDAW = DAWType::Ardour;
            } else if (name.containsIgnoreCase("media composer")) {
                currentDAW = DAWType::AvidMediaComposer;
            } else {
                currentDAW = DAWType::Unknown;
            }
        }
    }

    void optimizeForAbleton() {
        settings.preferredBufferSize = 128;
        settings.latencySamples = 0;  // Ableton handles delay compensation
        settings.enableMPE = true;    // Ableton supports MPE
        settings.enableSmartTempo = false;
        settings.enableMultiThreading = true;
        settings.sampleRate = 48000.0f;
        settings.useAutomationGestures = true;
        settings.hostSpecificNotes = "Ableton Link integration available. Use MPE for expressive control.";
    }

    void optimizeForLogic() {
        settings.preferredBufferSize = 256;
        settings.latencySamples = 0;
        settings.enableSurroundSound = true;  // Logic supports surround
        settings.enableSmartTempo = true;     // Logic's Flex Time/Smart Tempo
        settings.sampleRate = 48000.0f;       // Logic's default
        settings.useAutomationGestures = true;
        settings.enableMPE = true;
        settings.hostSpecificNotes = "AU format optimized. Smart Tempo enabled for tempo flexibility.";
    }

    void optimizeForProTools() {
        settings.preferredBufferSize = 64;   // Pro Tools HDX works with smaller buffers
        settings.latencySamples = 0;
        settings.enableDelayCompensation = true;  // Pro Tools has excellent PDC
        settings.highPrecisionMode = true;        // Pro Tools users expect high quality
        settings.sampleRate = 48000.0f;
        settings.enableMultiThreading = false;    // AAX handles threading
        settings.useAutomationGestures = true;
        settings.hostSpecificNotes = "AAX optimized. Delay compensation enabled. Use HDX for lowest latency.";
    }

    void optimizeForReaper() {
        settings.preferredBufferSize = 512;
        settings.latencySamples = 0;
        settings.enableMultiThreading = true;  // REAPER loves multi-threading
        settings.enableDelayCompensation = true;
        settings.sampleRate = 48000.0f;
        settings.useAutomationGestures = true;
        settings.hostSpecificNotes = "REAPER's flexible routing available. Automation compatible with JSFX bridge.";
    }

    void optimizeForCubase() {
        settings.preferredBufferSize = 256;
        settings.latencySamples = 0;
        settings.enableSurroundSound = true;  // Nuendo/Cubase support surround
        settings.enableDelayCompensation = true;
        settings.sampleRate = 48000.0f;
        settings.useAutomationGestures = true;
        settings.enableMPE = true;
        settings.hostSpecificNotes = "VST3 optimized. Expression Map support for MIDI control.";
    }

    void optimizeForStudioOne() {
        settings.preferredBufferSize = 256;
        settings.latencySamples = 0;
        settings.enableDelayCompensation = true;
        settings.sampleRate = 48000.0f;
        settings.useAutomationGestures = true;
        settings.enableMultiThreading = true;
        settings.hostSpecificNotes = "Studio One's drag-and-drop workflow supported. Zero-latency monitoring available.";
    }

    void optimizeForFLStudio() {
        settings.preferredBufferSize = 512;
        settings.latencySamples = 0;
        settings.enableMultiThreading = true;
        settings.sampleRate = 44100.0f;  // FL Studio traditionally uses 44.1k
        settings.useAutomationGestures = true;
        settings.hostSpecificNotes = "FL Studio pattern-based workflow. Automation clips supported.";
    }

    void optimizeForBitwig() {
        settings.preferredBufferSize = 256;
        settings.latencySamples = 0;
        settings.enableMPE = true;  // Bitwig has excellent MPE support
        settings.enableMultiThreading = true;
        settings.sampleRate = 48000.0f;
        settings.useAutomationGestures = true;
        settings.hostSpecificNotes = "Bitwig modulation system compatible. MPE fully supported for expressive control.";
    }

    void applyDefaultOptimizations() {
        settings.preferredBufferSize = 512;
        settings.latencySamples = 0;
        settings.enableMultiThreading = true;
        settings.sampleRate = 48000.0f;
        settings.useAutomationGestures = true;
        settings.hostSpecificNotes = "Generic host settings applied. May need manual optimization.";
    }

public:
    // Get recommended settings as readable text
    juce::String getOptimizationReport() const {
        juce::String report;
        report << "🎛️ DAW Optimization Report\n";
        report << "==========================\n\n";
        report << "Detected Host: " << getDAWName() << "\n";
        report << "Buffer Size: " << settings.preferredBufferSize << " samples\n";
        report << "Sample Rate: " << settings.sampleRate << " Hz\n";
        report << "Latency: " << settings.latencySamples << " samples\n";
        report << "MPE Support: " << (settings.enableMPE ? "✓ Enabled" : "✗ Disabled") << "\n";
        report << "Surround Sound: " << (settings.enableSurroundSound ? "✓ Enabled" : "✗ Disabled") << "\n";
        report << "Smart Tempo: " << (settings.enableSmartTempo ? "✓ Enabled" : "✗ Disabled") << "\n";
        report << "Multi-Threading: " << (settings.enableMultiThreading ? "✓ Enabled" : "✗ Disabled") << "\n";
        report << "Delay Compensation: " << (settings.enableDelayCompensation ? "✓ Enabled" : "✗ Disabled") << "\n\n";
        report << "Notes: " << settings.hostSpecificNotes << "\n";
        return report;
    }
};

} // namespace Echoel
