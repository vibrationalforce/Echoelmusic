import Foundation

// MARK: - Open Source Plugin Development Frameworks
// iPlug 2 (WDL License - fully free) and JUCE (GPLv3 - free for open source)

/// Open source audio plugin frameworks comparison
public struct OpenPluginFrameworks {

    // MARK: - iPlug 2

    /// iPlug 2 - Completely Free (WDL License)
    /// https://github.com/iPlug2/iPlug2
    public struct IPlug2 {
        public static let info = FrameworkInfo(
            name: "iPlug 2",
            license: "WDL (completely free, no restrictions)",
            licenseCost: 0,
            commercialUse: true,
            closedSource: true,  // Can be closed source!
            repository: "https://github.com/iPlug2/iPlug2",
            documentation: "https://iplug2.github.io/iPlug2/",

            supportedFormats: [
                .vst2,      // Legacy
                .vst3,      // Modern VST
                .audioUnit, // macOS/iOS
                .aax,       // Pro Tools (requires iLok dev account)
                .app,       // Standalone
                .web        // WebAudioModule (WAM)
            ],

            supportedPlatforms: [
                .macOS,
                .windows,
                .iOS,
                .web
            ],

            features: [
                "Single codebase for all formats",
                "Built-in graphics (NanoVG, Skia, Cairo)",
                "MIDI support",
                "Preset management",
                "Parameter automation",
                "Undo/Redo",
                "Web Audio export",
                "CMake build system",
                "Extensive examples"
            ],

            pros: [
                "100% free for any use (commercial, closed source)",
                "Lighter weight than JUCE",
                "Web Audio (WAM) support",
                "Excellent documentation",
                "Active development",
                "No splash screens or restrictions"
            ],

            cons: [
                "Smaller community than JUCE",
                "Less UI components than JUCE",
                "No Linux support yet"
            ]
        )

        /// Quick start template for iPlug 2 plugin
        public static func generateProject(name: String, format: PluginFormat) -> String {
            """
            // \(name) - iPlug 2 Plugin
            // Generated for Echoelmusic

            #include "IPlug_include_in_plug_hdr.h"

            class \(name) final : public Plugin {
            public:
                \(name)(const InstanceInfo& info)
                : Plugin(info, MakeConfig(kNumParams, kNumPresets)) {
                    // Parameter definitions
                    GetParam(kGain)->InitDouble("Gain", 0., -70., 12., 0.1, "dB");
                }

                void ProcessBlock(sample** inputs, sample** outputs, int nFrames) override {
                    const double gain = DBToAmp(GetParam(kGain)->Value());

                    for (int s = 0; s < nFrames; s++) {
                        outputs[0][s] = inputs[0][s] * gain;
                        outputs[1][s] = inputs[1][s] * gain;
                    }
                }

            private:
                enum EParams { kGain = 0, kNumParams };
                enum { kNumPresets = 1 };
            };

            // Register plugin
            IPLUG2_PLUGIN(\(name))
            """
        }
    }

    // MARK: - JUCE (Open Source Edition)

    /// JUCE - GPLv3 (free for open source projects)
    /// https://github.com/juce-framework/JUCE
    public struct JUCE {
        public static let info = FrameworkInfo(
            name: "JUCE",
            license: "GPLv3 (free) / Commercial ($800-2000/year)",
            licenseCost: 0,  // Free under GPL
            commercialUse: true,  // If open source
            closedSource: false,  // GPL requires open source
            repository: "https://github.com/juce-framework/JUCE",
            documentation: "https://docs.juce.com",

            supportedFormats: [
                .vst2,      // Legacy (deprecated)
                .vst3,      // Modern VST
                .audioUnit, // macOS/iOS
                .aax,       // Pro Tools
                .lv2,       // Linux
                .app,       // Standalone
                .unity      // Unity plugin
            ],

            supportedPlatforms: [
                .macOS,
                .windows,
                .linux,
                .iOS,
                .android
            ],

            features: [
                "Comprehensive UI framework",
                "DSP modules",
                "MIDI support",
                "Audio file I/O",
                "Plugin hosting",
                "OpenGL graphics",
                "Network support",
                "JSON/XML parsing",
                "Unit testing",
                "Projucer IDE"
            ],

            pros: [
                "Huge community",
                "Extensive documentation",
                "Battle-tested in industry",
                "Full-featured UI toolkit",
                "Linux support",
                "Built-in DSP modules"
            ],

            cons: [
                "GPL requires open source (or pay license)",
                "Heavy framework",
                "Steep learning curve",
                "No web export"
            ]
        )

        /// Free tier usage rules
        public static let gplRules = """
        JUCE GPLv3 License Rules (Free):
        ═══════════════════════════════

        ✅ ALLOWED:
        • Build and distribute plugins for free
        • Use in commercial projects IF open source
        • Modify JUCE code
        • No splash screens required
        • No revenue limits

        ⚠️  REQUIREMENTS:
        • Your code MUST be open source (GPLv3)
        • Include JUCE copyright notices
        • Provide source code to users

        ❌ NOT ALLOWED WITH FREE LICENSE:
        • Closed source / proprietary plugins
        • Selling without providing source

        💡 FOR CLOSED SOURCE:
        • Personal License: $800/year (revenue < $50k)
        • Indie License: $1600/year (revenue < $500k)
        • Pro License: Custom pricing
        """

        /// Quick start template for JUCE plugin
        public static func generateProject(name: String, format: PluginFormat) -> String {
            """
            // \(name) - JUCE Plugin (GPLv3)
            // Source code must be open source under GPL

            #pragma once
            #include <JuceHeader.h>

            class \(name)Processor : public juce::AudioProcessor {
            public:
                \(name)Processor();
                ~\(name)Processor() override;

                void prepareToPlay(double sampleRate, int samplesPerBlock) override;
                void releaseResources() override;
                void processBlock(juce::AudioBuffer<float>&, juce::MidiBuffer&) override;

                juce::AudioProcessorEditor* createEditor() override;
                bool hasEditor() const override { return true; }

                const juce::String getName() const override { return "\(name)"; }
                bool acceptsMidi() const override { return false; }
                bool producesMidi() const override { return false; }
                double getTailLengthSeconds() const override { return 0.0; }

                int getNumPrograms() override { return 1; }
                int getCurrentProgram() override { return 0; }
                void setCurrentProgram(int) override {}
                const juce::String getProgramName(int) override { return {}; }
                void changeProgramName(int, const juce::String&) override {}

                void getStateInformation(juce::MemoryBlock&) override;
                void setStateInformation(const void*, int) override;

            private:
                juce::AudioParameterFloat* gainParameter;
                JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(\(name)Processor)
            };
            """
        }
    }

    // MARK: - Comparison

    public static let comparison = """
    ╔══════════════════════════════════════════════════════════════════╗
    ║          OPEN SOURCE PLUGIN FRAMEWORKS COMPARISON                ║
    ╠══════════════════════════════════════════════════════════════════╣
    ║                      │  iPlug 2           │  JUCE (GPL)          ║
    ╠══════════════════════════════════════════════════════════════════╣
    ║ License              │  WDL (100% free)   │  GPLv3 (free)        ║
    ║ Commercial Use       │  ✅ Yes            │  ✅ If open source   ║
    ║ Closed Source        │  ✅ Yes            │  ❌ No (pay $800+)   ║
    ║ Splash Screen        │  ❌ None           │  ❌ None (GPL)       ║
    ╠══════════════════════════════════════════════════════════════════╣
    ║ VST3                 │  ✅                │  ✅                  ║
    ║ Audio Units          │  ✅                │  ✅                  ║
    ║ AAX (Pro Tools)      │  ✅                │  ✅                  ║
    ║ LV2                  │  ❌                │  ✅                  ║
    ║ CLAP                 │  🔄 In progress    │  ❌ Not official     ║
    ║ Web Audio (WAM)      │  ✅                │  ❌                  ║
    ╠══════════════════════════════════════════════════════════════════╣
    ║ macOS                │  ✅                │  ✅                  ║
    ║ Windows              │  ✅                │  ✅                  ║
    ║ Linux                │  ❌                │  ✅                  ║
    ║ iOS                  │  ✅                │  ✅                  ║
    ║ Android              │  ❌                │  ✅                  ║
    ║ Web                  │  ✅                │  ❌                  ║
    ╠══════════════════════════════════════════════════════════════════╣
    ║ UI Framework         │  Built-in (simple) │  Full-featured       ║
    ║ DSP Library          │  Basic             │  Comprehensive       ║
    ║ Community Size       │  Medium            │  Very Large          ║
    ║ Learning Curve       │  Moderate          │  Steep               ║
    ║ Build System         │  CMake             │  Projucer/CMake      ║
    ╠══════════════════════════════════════════════════════════════════╣
    ║                                                                  ║
    ║  RECOMMENDATION FOR ECHOELMUSIC:                                 ║
    ║                                                                  ║
    ║  → iPlug 2 for MAXIMUM FREEDOM (no GPL restrictions)             ║
    ║  → JUCE if you want open source anyway                           ║
    ║                                                                  ║
    ╚══════════════════════════════════════════════════════════════════╝
    """

    /// Recommendation based on use case
    public static func recommend(forUseCase useCase: UseCase) -> String {
        switch useCase {
        case .commercialClosedSource:
            return "iPlug 2 - No licensing costs, no restrictions"

        case .openSourceProject:
            return "JUCE GPL or iPlug 2 - Both free, JUCE has more features"

        case .webAudioPlugin:
            return "iPlug 2 - Only one with WebAudioModule (WAM) support"

        case .linuxSupport:
            return "JUCE - Only one with Linux support"

        case .quickPrototype:
            return "iPlug 2 - Simpler, faster to get started"

        case .complexUI:
            return "JUCE - Better UI toolkit"
        }
    }

    public enum UseCase {
        case commercialClosedSource
        case openSourceProject
        case webAudioPlugin
        case linuxSupport
        case quickPrototype
        case complexUI
    }
}

// MARK: - Supporting Types

public struct FrameworkInfo {
    public let name: String
    public let license: String
    public let licenseCost: Int
    public let commercialUse: Bool
    public let closedSource: Bool
    public let repository: String
    public let documentation: String
    public let supportedFormats: [PluginFormat]
    public let supportedPlatforms: [Platform]
    public let features: [String]
    public let pros: [String]
    public let cons: [String]
}

public enum PluginFormat: String, CaseIterable {
    case vst2 = "VST2"
    case vst3 = "VST3"
    case audioUnit = "Audio Units"
    case aax = "AAX"
    case lv2 = "LV2"
    case clap = "CLAP"
    case app = "Standalone"
    case web = "Web Audio"
    case unity = "Unity"
}

public enum Platform: String, CaseIterable {
    case macOS = "macOS"
    case windows = "Windows"
    case linux = "Linux"
    case iOS = "iOS"
    case android = "Android"
    case web = "Web"
}

// MARK: - Other Free Alternatives

public struct OtherFreeFrameworks {

    /// DPF - Distrho Plugin Framework (ISC License)
    public static let dpf = """
    DPF (Distrho Plugin Framework)
    ═══════════════════════════════
    License: ISC (completely free, like MIT)
    Repo: https://github.com/DISTRHO/DPF

    Formats: VST2, VST3, LV2, CLAP, JACK
    Platforms: macOS, Windows, Linux

    Pros:
    • Truly free (ISC license)
    • CLAP support
    • Linux-first development
    • Small footprint

    Cons:
    • Smaller community
    • Less documentation
    """

    /// Dplug (Boost License)
    public static let dplug = """
    Dplug
    ═════
    License: Boost (completely free)
    Repo: https://github.com/AuburnSounds/Dplug

    Written in D language (compiles to native code)

    Formats: VST2, VST3, AU, AAX, LV2
    Platforms: macOS, Windows, Linux

    Pros:
    • Unique D language (safer than C++)
    • GPU-accelerated UI
    • All formats supported
    • Commercial-friendly license

    Cons:
    • Need to learn D language
    • Smaller community
    """

    /// FAUST (GPLv2)
    public static let faust = """
    FAUST
    ═════
    License: GPLv2
    Repo: https://github.com/grame-cncm/faust

    DSL for audio that compiles to C++, Rust, WebAssembly, etc.

    Pros:
    • Functional programming for DSP
    • Mathematical DSP specification
    • Generates optimized code
    • Web export

    Cons:
    • Different paradigm (learning curve)
    • GPL license
    """

    /// All free frameworks summary
    public static let allFreeOptions = [
        "iPlug 2 (WDL) - RECOMMENDED",
        "JUCE (GPLv3) - if open source",
        "DPF (ISC) - for CLAP/LV2",
        "Dplug (Boost) - if you know D",
        "FAUST (GPL) - for DSP-focused"
    ]
}

// MARK: - Echoelmusic Integration

public extension OpenPluginFrameworks {

    /// Generate Echoelmusic effects as plugins
    static func generateEchoelmusicPlugin(
        effect: EchoelmusicEffect,
        framework: PluginFramework
    ) -> String {

        switch framework {
        case .iplug2:
            return IPlug2.generateProject(name: effect.rawValue, format: .vst3)
        case .juce:
            return JUCE.generateProject(name: effect.rawValue, format: .vst3)
        }
    }

    enum EchoelmusicEffect: String, CaseIterable {
        case bioReactiveReverb = "EchoelBioReverb"
        case hrvModulator = "EchoelHRVMod"
        case coherenceFilter = "EchoelCoherence"
        case breathSync = "EchoelBreathSync"
        case spatialBinaural = "EchoelSpatial"
    }

    enum PluginFramework {
        case iplug2
        case juce
    }
}
