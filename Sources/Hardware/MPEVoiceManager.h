#pragma once

#include <JuceHeader.h>
#include "MIDI2Manager.h"
#include <algorithm>
#include <array>
#include <atomic>
#include <cmath>
#include <functional>
#include <vector>

namespace Echoelmusic {

/**
 * MPEVoiceManager - MIDI Polyphonic Expression Voice Allocator
 *
 * Implements the MPE specification (MIDI Polyphonic Expression):
 * - 15-voice polyphony (channels 2-16, channel 1 = master)
 * - Per-note Pitch Bend (±48 semitones default)
 * - Per-note Pressure (Aftertouch)
 * - Per-note Slide (CC74 Brightness)
 * - Per-note Timbre (CC71)
 * - Voice stealing with configurable algorithms
 * - Smooth voice transitions (glide, portamento)
 * - Zone configuration (Lower/Upper zones)
 *
 * Compatible with:
 * - ROLI Seaboard, Lightpad
 * - Sensel Morph
 * - Linnstrument
 * - Expressive E Osmose, Touché
 * - Ableton Push 3
 * - Arturia MicroFreak
 * - Any MPE-compatible controller
 */

//==============================================================================
// MPE Zone Configuration
//==============================================================================

enum class MPEZoneLayout
{
    Off,            // No MPE, standard MIDI
    Lower,          // Lower Zone only (Channel 1 = master, 2-16 = notes)
    Upper,          // Upper Zone only (Channel 16 = master, 1-15 = notes)
    Both            // Both zones (Lower: 1-8, Upper: 9-16)
};

struct MPEZone
{
    uint8_t masterChannel = 0;      // Master channel (0 = ch1, 15 = ch16)
    uint8_t firstNoteChannel = 1;   // First member channel
    uint8_t numNoteChannels = 15;   // Number of member channels
    float pitchBendRange = 48.0f;   // Semitones (MPE default: 48)
    bool enabled = true;

    uint8_t getLastNoteChannel() const
    {
        return firstNoteChannel + numNoteChannels - 1;
    }

    bool isNoteChannel(uint8_t channel) const
    {
        return channel >= firstNoteChannel &&
               channel <= getLastNoteChannel();
    }

    bool isMasterChannel(uint8_t channel) const
    {
        return channel == masterChannel;
    }
};

//==============================================================================
// Voice Stealing Algorithm
//==============================================================================

enum class VoiceStealingMode
{
    Oldest,         // Steal oldest playing voice
    Quietest,       // Steal voice with lowest velocity/pressure
    Lowest,         // Steal lowest pitch voice
    Highest,        // Steal highest pitch voice
    SamePitch,      // Steal voice with same pitch if exists
    None            // Don't steal, reject new notes when full
};

//==============================================================================
// MPE Voice State
//==============================================================================

struct MPEVoice
{
    bool active = false;
    uint8_t channel = 0;            // MIDI channel (0-15)
    uint8_t note = 0;               // MIDI note number
    uint16_t velocity = 0;          // 16-bit velocity (MIDI 2.0)
    uint64_t timestamp = 0;         // When note started (for voice stealing)

    // Per-note expression values (all 32-bit for MIDI 2.0 precision)
    uint32_t pitchBend = 0x80000000;    // Center = 0x80000000
    uint32_t pressure = 0;               // Aftertouch
    uint32_t slide = 0x80000000;         // CC74 (Brightness)
    uint32_t timbre = 0x80000000;        // CC71

    // Calculated output values (normalized 0.0 to 1.0 or bipolar -1.0 to 1.0)
    float pitchOffset = 0.0f;       // Semitones offset from note
    float normalizedPressure = 0.0f;
    float normalizedSlide = 0.5f;
    float normalizedTimbre = 0.5f;

    // Voice state
    bool releasing = false;         // In release phase
    float releaseTime = 0.0f;       // Time since release started

    // Glide/Portamento
    float glideSource = 0.0f;       // Source pitch for glide
    float glideProgress = 1.0f;     // 0.0 to 1.0 (1.0 = complete)

    void updateCalculatedValues(float pitchBendRange)
    {
        // Pitch bend: convert 32-bit to semitones
        float pbNormalized = (static_cast<float>(pitchBend) / 0xFFFFFFFF) * 2.0f - 1.0f;
        pitchOffset = pbNormalized * pitchBendRange;

        // Pressure: 0.0 to 1.0
        normalizedPressure = static_cast<float>(pressure) / 0xFFFFFFFF;

        // Slide (CC74): 0.0 to 1.0
        normalizedSlide = static_cast<float>(slide) / 0xFFFFFFFF;

        // Timbre (CC71): 0.0 to 1.0
        normalizedTimbre = static_cast<float>(timbre) / 0xFFFFFFFF;
    }

    float getCurrentPitch() const
    {
        float basePitch = static_cast<float>(note);
        float glidedPitch = glideSource + (basePitch - glideSource) * glideProgress;
        return glidedPitch + pitchOffset;
    }
};

//==============================================================================
// MPE Voice Manager
//==============================================================================

class MPEVoiceManager
{
public:
    static constexpr int MaxVoices = 15;  // MPE max (channels 2-16)
    static constexpr int MaxChannels = 16;

    //==========================================================================
    // Construction
    //==========================================================================

    MPEVoiceManager()
    {
        // Default: Lower zone with 15 voices
        configureZone(MPEZoneLayout::Lower);
    }

    //==========================================================================
    // Zone Configuration
    //==========================================================================

    void configureZone(MPEZoneLayout layout)
    {
        currentLayout = layout;

        switch (layout)
        {
            case MPEZoneLayout::Off:
                lowerZone.enabled = false;
                upperZone.enabled = false;
                break;

            case MPEZoneLayout::Lower:
                lowerZone.masterChannel = 0;
                lowerZone.firstNoteChannel = 1;
                lowerZone.numNoteChannels = 15;
                lowerZone.enabled = true;
                upperZone.enabled = false;
                break;

            case MPEZoneLayout::Upper:
                upperZone.masterChannel = 15;
                upperZone.firstNoteChannel = 0;
                upperZone.numNoteChannels = 15;
                upperZone.enabled = true;
                lowerZone.enabled = false;
                break;

            case MPEZoneLayout::Both:
                lowerZone.masterChannel = 0;
                lowerZone.firstNoteChannel = 1;
                lowerZone.numNoteChannels = 7;
                lowerZone.enabled = true;

                upperZone.masterChannel = 15;
                upperZone.firstNoteChannel = 8;
                upperZone.numNoteChannels = 7;
                upperZone.enabled = true;
                break;
        }

        // Clear all voices on zone change
        allNotesOff();
    }

    void setPitchBendRange(float semitones, bool lowerZoneOnly = true)
    {
        if (lowerZoneOnly || !upperZone.enabled)
            lowerZone.pitchBendRange = semitones;
        else
            upperZone.pitchBendRange = semitones;
    }

    void setVoiceStealingMode(VoiceStealingMode mode)
    {
        stealingMode = mode;
    }

    void setGlideTime(float seconds)
    {
        glideTime = seconds;
    }

    //==========================================================================
    // Note Processing (MIDI 1.0 compatible)
    //==========================================================================

    /** Process note on (7-bit velocity) */
    MPEVoice* noteOn(uint8_t channel, uint8_t note, uint8_t velocity)
    {
        return noteOn(channel, note,
                     UniversalMIDIPacket::scaleVelocity7to16(velocity));
    }

    /** Process note on (16-bit velocity, MIDI 2.0) */
    MPEVoice* noteOn(uint8_t channel, uint8_t note, uint16_t velocity)
    {
        // Find zone for this channel
        MPEZone* zone = getZoneForChannel(channel);
        if (!zone || !zone->isNoteChannel(channel))
            return nullptr;

        // Find or allocate voice for this channel
        MPEVoice* voice = getVoiceForChannel(channel);

        if (!voice)
        {
            // Need to steal a voice
            voice = stealVoice();
            if (!voice)
                return nullptr;  // No voice available
        }

        // Handle glide from previous note
        float previousPitch = voice->active ? voice->getCurrentPitch() : static_cast<float>(note);

        // Initialize voice
        voice->active = true;
        voice->channel = channel;
        voice->note = note;
        voice->velocity = velocity;
        voice->timestamp = ++currentTimestamp;
        voice->releasing = false;
        voice->releaseTime = 0.0f;

        // Reset expression to center
        voice->pitchBend = 0x80000000;
        voice->pressure = 0;
        voice->slide = 0x80000000;
        voice->timbre = 0x80000000;

        // Setup glide
        if (glideTime > 0.0f && previousPitch != static_cast<float>(note))
        {
            voice->glideSource = previousPitch;
            voice->glideProgress = 0.0f;
        }
        else
        {
            voice->glideSource = static_cast<float>(note);
            voice->glideProgress = 1.0f;
        }

        voice->updateCalculatedValues(zone->pitchBendRange);

        // Notify
        if (onVoiceStarted)
            onVoiceStarted(*voice);

        return voice;
    }

    /** Process note off */
    void noteOff(uint8_t channel, uint8_t note, uint8_t velocity = 0)
    {
        juce::ignoreUnused(velocity);

        for (auto& voice : voices)
        {
            if (voice.active && voice.channel == channel && voice.note == note)
            {
                voice.releasing = true;
                voice.releaseTime = 0.0f;

                if (onVoiceReleased)
                    onVoiceReleased(voice);

                // Don't deactivate yet - let synth handle release
                break;
            }
        }
    }

    /** Finalize voice release (call when synth envelope is done) */
    void voiceEnded(uint8_t channel, uint8_t note)
    {
        for (auto& voice : voices)
        {
            if (voice.channel == channel && voice.note == note)
            {
                voice.active = false;

                if (onVoiceEnded)
                    onVoiceEnded(voice);

                break;
            }
        }
    }

    //==========================================================================
    // Expression Processing
    //==========================================================================

    /** Process pitch bend (14-bit MIDI 1.0) */
    void pitchBend(uint8_t channel, int value14bit)
    {
        pitchBend(channel, UniversalMIDIPacket::scale14to32(static_cast<uint16_t>(value14bit)));
    }

    /** Process pitch bend (32-bit MIDI 2.0) */
    void pitchBend(uint8_t channel, uint32_t value)
    {
        MPEZone* zone = getZoneForChannel(channel);
        if (!zone)
            return;

        if (zone->isNoteChannel(channel))
        {
            // Per-note pitch bend
            for (auto& voice : voices)
            {
                if (voice.active && voice.channel == channel)
                {
                    voice.pitchBend = value;
                    voice.updateCalculatedValues(zone->pitchBendRange);

                    if (onVoiceUpdated)
                        onVoiceUpdated(voice);
                }
            }
        }
        else if (zone->isMasterChannel(channel))
        {
            // Master pitch bend affects all voices in zone
            for (auto& voice : voices)
            {
                if (voice.active && zone->isNoteChannel(voice.channel))
                {
                    // Apply master bend (combine with per-note bend)
                    // For simplicity, just update calculated values
                    voice.updateCalculatedValues(zone->pitchBendRange);
                }
            }
        }
    }

    /** Process pressure/aftertouch (7-bit MIDI 1.0) */
    void pressure(uint8_t channel, uint8_t value)
    {
        pressure(channel, UniversalMIDIPacket::scale7to32(value));
    }

    /** Process pressure/aftertouch (32-bit MIDI 2.0) */
    void pressure(uint8_t channel, uint32_t value)
    {
        MPEZone* zone = getZoneForChannel(channel);
        if (!zone)
            return;

        for (auto& voice : voices)
        {
            if (voice.active && voice.channel == channel)
            {
                voice.pressure = value;
                voice.updateCalculatedValues(zone->pitchBendRange);

                if (onVoiceUpdated)
                    onVoiceUpdated(voice);
            }
        }
    }

    /** Process poly aftertouch */
    void polyPressure(uint8_t channel, uint8_t note, uint8_t value)
    {
        polyPressure(channel, note, UniversalMIDIPacket::scale7to32(value));
    }

    void polyPressure(uint8_t channel, uint8_t note, uint32_t value)
    {
        for (auto& voice : voices)
        {
            if (voice.active && voice.channel == channel && voice.note == note)
            {
                voice.pressure = value;
                voice.updateCalculatedValues(getZoneForChannel(channel)->pitchBendRange);

                if (onVoiceUpdated)
                    onVoiceUpdated(voice);
            }
        }
    }

    /** Process CC (7-bit MIDI 1.0) */
    void controlChange(uint8_t channel, uint8_t cc, uint8_t value)
    {
        controlChange(channel, cc, UniversalMIDIPacket::scale7to32(value));
    }

    /** Process CC (32-bit MIDI 2.0) */
    void controlChange(uint8_t channel, uint8_t cc, uint32_t value)
    {
        MPEZone* zone = getZoneForChannel(channel);
        if (!zone)
            return;

        // MPE standard CCs
        switch (cc)
        {
            case 74:  // Brightness / Slide
                for (auto& voice : voices)
                {
                    if (voice.active && voice.channel == channel)
                    {
                        voice.slide = value;
                        voice.updateCalculatedValues(zone->pitchBendRange);

                        if (onVoiceUpdated)
                            onVoiceUpdated(voice);
                    }
                }
                break;

            case 71:  // Timbre / Resonance
                for (auto& voice : voices)
                {
                    if (voice.active && voice.channel == channel)
                    {
                        voice.timbre = value;
                        voice.updateCalculatedValues(zone->pitchBendRange);

                        if (onVoiceUpdated)
                            onVoiceUpdated(voice);
                    }
                }
                break;

            case 1:   // Mod wheel (master channel typically)
                // Handle master mod wheel if needed
                break;

            case 64:  // Sustain
                // Handle sustain pedal
                break;

            default:
                break;
        }
    }

    //==========================================================================
    // Voice Access
    //==========================================================================

    /** Get all voices */
    const std::array<MPEVoice, MaxVoices>& getVoices() const
    {
        return voices;
    }

    /** Get active voice count */
    int getActiveVoiceCount() const
    {
        return static_cast<int>(std::count_if(
            voices.begin(), voices.end(),
            [](const MPEVoice& v) { return v.active; }
        ));
    }

    /** Get voice by channel and note */
    MPEVoice* getVoice(uint8_t channel, uint8_t note)
    {
        for (auto& voice : voices)
        {
            if (voice.active && voice.channel == channel && voice.note == note)
                return &voice;
        }
        return nullptr;
    }

    /** All notes off */
    void allNotesOff()
    {
        for (auto& voice : voices)
        {
            if (voice.active && onVoiceEnded)
                onVoiceEnded(voice);
            voice.active = false;
        }
    }

    //==========================================================================
    // Update (call each audio block)
    //==========================================================================

    void update(float deltaTime)
    {
        for (auto& voice : voices)
        {
            if (!voice.active)
                continue;

            // Update glide
            if (voice.glideProgress < 1.0f && glideTime > 0.0f)
            {
                voice.glideProgress += deltaTime / glideTime;
                voice.glideProgress = std::min(voice.glideProgress, 1.0f);
            }

            // Update release time
            if (voice.releasing)
            {
                voice.releaseTime += deltaTime;
            }
        }
    }

    //==========================================================================
    // Callbacks
    //==========================================================================

    std::function<void(const MPEVoice&)> onVoiceStarted;
    std::function<void(const MPEVoice&)> onVoiceUpdated;
    std::function<void(const MPEVoice&)> onVoiceReleased;
    std::function<void(const MPEVoice&)> onVoiceEnded;

    //==========================================================================
    // Zone Access
    //==========================================================================

    const MPEZone& getLowerZone() const { return lowerZone; }
    const MPEZone& getUpperZone() const { return upperZone; }
    MPEZoneLayout getCurrentLayout() const { return currentLayout; }

private:
    std::array<MPEVoice, MaxVoices> voices;
    MPEZone lowerZone;
    MPEZone upperZone;
    MPEZoneLayout currentLayout = MPEZoneLayout::Lower;
    VoiceStealingMode stealingMode = VoiceStealingMode::Oldest;
    float glideTime = 0.0f;
    uint64_t currentTimestamp = 0;

    //==========================================================================
    // Internal Methods
    //==========================================================================

    MPEZone* getZoneForChannel(uint8_t channel)
    {
        if (lowerZone.enabled &&
            (lowerZone.isMasterChannel(channel) || lowerZone.isNoteChannel(channel)))
            return &lowerZone;

        if (upperZone.enabled &&
            (upperZone.isMasterChannel(channel) || upperZone.isNoteChannel(channel)))
            return &upperZone;

        return nullptr;
    }

    MPEVoice* getVoiceForChannel(uint8_t channel)
    {
        // First, find inactive voice
        for (auto& voice : voices)
        {
            if (!voice.active)
                return &voice;
        }

        // All voices active, return nullptr (caller should steal)
        return nullptr;
    }

    MPEVoice* stealVoice()
    {
        if (stealingMode == VoiceStealingMode::None)
            return nullptr;

        MPEVoice* victim = nullptr;

        switch (stealingMode)
        {
            case VoiceStealingMode::Oldest:
            {
                uint64_t oldestTime = UINT64_MAX;
                for (auto& voice : voices)
                {
                    if (voice.active && voice.timestamp < oldestTime)
                    {
                        oldestTime = voice.timestamp;
                        victim = &voice;
                    }
                }
                break;
            }

            case VoiceStealingMode::Quietest:
            {
                uint32_t lowestPressure = UINT32_MAX;
                for (auto& voice : voices)
                {
                    if (voice.active)
                    {
                        // Use pressure, fall back to velocity
                        uint32_t level = voice.pressure > 0 ? voice.pressure :
                                        static_cast<uint32_t>(voice.velocity) << 16;
                        if (level < lowestPressure)
                        {
                            lowestPressure = level;
                            victim = &voice;
                        }
                    }
                }
                break;
            }

            case VoiceStealingMode::Lowest:
            {
                uint8_t lowestNote = 127;
                for (auto& voice : voices)
                {
                    if (voice.active && voice.note < lowestNote)
                    {
                        lowestNote = voice.note;
                        victim = &voice;
                    }
                }
                break;
            }

            case VoiceStealingMode::Highest:
            {
                uint8_t highestNote = 0;
                for (auto& voice : voices)
                {
                    if (voice.active && voice.note > highestNote)
                    {
                        highestNote = voice.note;
                        victim = &voice;
                    }
                }
                break;
            }

            default:
                victim = &voices[0];  // Fallback to first voice
                break;
        }

        if (victim && victim->active && onVoiceEnded)
            onVoiceEnded(*victim);

        return victim;
    }

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MPEVoiceManager)
};

//==============================================================================
// MPE Processor - Combines MIDI2Manager with MPEVoiceManager
//==============================================================================

class MPEProcessor
{
public:
    MPEProcessor()
    {
        // Wire up MIDI2Manager to MPEVoiceManager
        midi2Manager.onNoteOn = [this](MIDI2::Group group, MIDI2::Channel channel,
                                       uint8_t note, uint16_t velocity)
        {
            juce::ignoreUnused(group);
            voiceManager.noteOn(channel, note, velocity);
        };

        midi2Manager.onNoteOff = [this](MIDI2::Group group, MIDI2::Channel channel,
                                        uint8_t note, uint16_t velocity)
        {
            juce::ignoreUnused(group, velocity);
            voiceManager.noteOff(channel, note);
        };

        midi2Manager.onPolyPressure = [this](MIDI2::Group group, MIDI2::Channel channel,
                                             uint8_t note, uint32_t pressure)
        {
            juce::ignoreUnused(group);
            voiceManager.polyPressure(channel, note, pressure);
        };

        midi2Manager.onPitchBend = [this](MIDI2::Group group, MIDI2::Channel channel,
                                          uint32_t pitchBend)
        {
            juce::ignoreUnused(group);
            voiceManager.pitchBend(channel, pitchBend);
        };

        midi2Manager.onControlChange = [this](MIDI2::Group group, MIDI2::Channel channel,
                                              uint8_t cc, uint32_t value)
        {
            juce::ignoreUnused(group);
            voiceManager.controlChange(channel, cc, value);
        };

        midi2Manager.onChannelPressure = [this](MIDI2::Group group, MIDI2::Channel channel,
                                                uint32_t pressure)
        {
            juce::ignoreUnused(group);
            voiceManager.pressure(channel, pressure);
        };

        midi2Manager.onPerNotePitchBend = [this](MIDI2::Group group, MIDI2::Channel channel,
                                                  uint8_t note, uint32_t pitchBend)
        {
            juce::ignoreUnused(group);
            // Find voice and apply per-note pitch bend
            if (auto* voice = voiceManager.getVoice(channel, note))
            {
                voice->pitchBend = pitchBend;
                voice->updateCalculatedValues(voiceManager.getLowerZone().pitchBendRange);
            }
        };
    }

    /** Process MIDI 1.0 message */
    void processMidiMessage(const juce::MidiMessage& msg)
    {
        midi2Manager.processMIDI1Message(msg, 0);
    }

    /** Process MIDI 2.0 UMP */
    void processUMP(const UniversalMIDIPacket& ump)
    {
        midi2Manager.processPacket(ump);
    }

    /** Update per audio block */
    void update(float deltaTime)
    {
        voiceManager.update(deltaTime);
    }

    /** Get voice manager */
    MPEVoiceManager& getVoiceManager() { return voiceManager; }
    const MPEVoiceManager& getVoiceManager() const { return voiceManager; }

    /** Get MIDI 2.0 manager */
    MIDI2Manager& getMIDI2Manager() { return midi2Manager; }
    const MIDI2Manager& getMIDI2Manager() const { return midi2Manager; }

private:
    MIDI2Manager midi2Manager;
    MPEVoiceManager voiceManager;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MPEProcessor)
};

} // namespace Echoelmusic
