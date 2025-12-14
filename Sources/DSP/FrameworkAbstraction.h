/**
 * ╔══════════════════════════════════════════════════════════════════════════════╗
 * ║              ECHOELMUSIC FRAMEWORK ABSTRACTION LAYER                         ║
 * ║               Supports: JUCE, iPlug2, or Pure C++                            ║
 * ╚══════════════════════════════════════════════════════════════════════════════╝
 *
 * This header provides unified types that work with any audio framework.
 *
 * Build configurations:
 * - ECHOELMUSIC_USE_JUCE    : Use JUCE framework (default for existing code)
 * - ECHOELMUSIC_USE_IPLUG2  : Use iPlug2 framework (plugin builds)
 * - ECHOELMUSIC_PURE_CPP    : Pure C++17, no framework dependency
 *
 * The abstraction automatically selects the correct implementation.
 */

#pragma once

//==============================================================================
// FRAMEWORK DETECTION
//==============================================================================

// Auto-detect framework if not explicitly set
#if !defined(ECHOELMUSIC_USE_JUCE) && !defined(ECHOELMUSIC_USE_IPLUG2) && !defined(ECHOELMUSIC_PURE_CPP)
    #if defined(JUCE_GLOBAL_MODULE_SETTINGS_INCLUDED) || defined(JuceHeader_h)
        #define ECHOELMUSIC_USE_JUCE 1
    #elif defined(IPLUG_DSP) || defined(IPLUG_EDITOR)
        #define ECHOELMUSIC_USE_IPLUG2 1
    #else
        #define ECHOELMUSIC_PURE_CPP 1
    #endif
#endif

//==============================================================================
// FRAMEWORK-SPECIFIC INCLUDES
//==============================================================================

#if ECHOELMUSIC_USE_JUCE
    #include <JuceHeader.h>
#elif ECHOELMUSIC_USE_IPLUG2
    #include "IPlug_include_in_plug_hdr.h"
#endif

// Always include our JUCE-free DSP core
#include "EchoelmusicDSP.h"

namespace echoelmusic {

//==============================================================================
// UNIFIED AUDIO BUFFER
//==============================================================================

#if ECHOELMUSIC_USE_JUCE

// Use JUCE's AudioBuffer directly
template<typename T = float>
using UnifiedAudioBuffer = juce::AudioBuffer<T>;

#else

// Use our framework-free AudioBuffer
template<typename T = float>
using UnifiedAudioBuffer = AudioBuffer<T>;

#endif

//==============================================================================
// UNIFIED STRING TYPE
//==============================================================================

#if ECHOELMUSIC_USE_JUCE
    using String = juce::String;
#else
    using String = std::string;
#endif

//==============================================================================
// UNIFIED FILE TYPE
//==============================================================================

#if ECHOELMUSIC_USE_JUCE
    using File = juce::File;
#else
    // Simple file wrapper for non-JUCE builds
    class File {
    public:
        File() = default;
        explicit File(const std::string& path) : mPath(path) {}

        std::string getFullPathName() const { return mPath; }
        std::string getFileName() const {
            auto pos = mPath.find_last_of("/\\");
            return pos != std::string::npos ? mPath.substr(pos + 1) : mPath;
        }

        bool exists() const {
            std::ifstream f(mPath);
            return f.good();
        }

    private:
        std::string mPath;
    };
#endif

//==============================================================================
// UNIFIED MIDI MESSAGE
//==============================================================================

#if ECHOELMUSIC_USE_JUCE

using MidiMessage = juce::MidiMessage;
using MidiBuffer = juce::MidiBuffer;

#elif ECHOELMUSIC_USE_IPLUG2

// iPlug2 uses IMidiMsg
struct MidiMessage {
    int status = 0;
    int data1 = 0;
    int data2 = 0;
    int sampleOffset = 0;

    bool isNoteOn() const { return (status & 0xF0) == 0x90 && data2 > 0; }
    bool isNoteOff() const { return (status & 0xF0) == 0x80 || ((status & 0xF0) == 0x90 && data2 == 0); }
    bool isController() const { return (status & 0xF0) == 0xB0; }

    int getNoteNumber() const { return data1; }
    float getVelocity() const { return data2 / 127.0f; }
    int getChannel() const { return (status & 0x0F) + 1; }
    int getControllerNumber() const { return data1; }
    int getControllerValue() const { return data2; }
};

class MidiBuffer {
public:
    void addEvent(const MidiMessage& msg, int samplePosition) {
        MidiMessage m = msg;
        m.sampleOffset = samplePosition;
        mMessages.push_back(m);
    }

    void clear() { mMessages.clear(); }
    bool isEmpty() const { return mMessages.empty(); }

    // Iterator support
    auto begin() { return mMessages.begin(); }
    auto end() { return mMessages.end(); }
    auto begin() const { return mMessages.begin(); }
    auto end() const { return mMessages.end(); }

private:
    std::vector<MidiMessage> mMessages;
};

#else

// Pure C++ MIDI
struct MidiMessage {
    uint8_t status = 0;
    uint8_t data1 = 0;
    uint8_t data2 = 0;
    int sampleOffset = 0;

    bool isNoteOn() const { return (status & 0xF0) == 0x90 && data2 > 0; }
    bool isNoteOff() const { return (status & 0xF0) == 0x80 || ((status & 0xF0) == 0x90 && data2 == 0); }
    int getNoteNumber() const { return data1; }
    float getVelocity() const { return data2 / 127.0f; }
};

using MidiBuffer = std::vector<MidiMessage>;

#endif

//==============================================================================
// UNIFIED RANDOM
//==============================================================================

#if ECHOELMUSIC_USE_JUCE
    using Random = juce::Random;
#else
    class Random {
    public:
        float nextFloat() { return static_cast<float>(rand()) / RAND_MAX; }
        int nextInt(int max) { return rand() % max; }
        static Random& getSystemRandom() { static Random r; return r; }
    };
#endif

//==============================================================================
// UNIFIED LOGGER
//==============================================================================

#if ECHOELMUSIC_USE_JUCE
    #define ECHOEL_LOG(msg) DBG(msg)
#elif ECHOELMUSIC_USE_IPLUG2
    #define ECHOEL_LOG(msg) DBGMSG("%s\n", msg)
#else
    #define ECHOEL_LOG(msg) std::cout << msg << std::endl
#endif

//==============================================================================
// FRAMEWORK INFO
//==============================================================================

inline const char* getFrameworkName() {
    #if ECHOELMUSIC_USE_JUCE
        return "JUCE";
    #elif ECHOELMUSIC_USE_IPLUG2
        return "iPlug2";
    #else
        return "Pure C++";
    #endif
}

inline bool isJUCEBuild() {
    #if ECHOELMUSIC_USE_JUCE
        return true;
    #else
        return false;
    #endif
}

inline bool isIPlug2Build() {
    #if ECHOELMUSIC_USE_IPLUG2
        return true;
    #else
        return false;
    #endif
}

} // namespace echoelmusic
