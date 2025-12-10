/**
 * MPEVoiceManager.h
 * Echoelmusic MPE (MIDI Polyphonic Expression) Voice Manager
 *
 * C++ port of MPEZoneManager.swift
 * Features:
 * - 15-channel voice allocation (MPE Lower Zone)
 * - Voice stealing strategies
 * - Per-voice pitch bend, pressure, brightness, timbre tracking
 * - Compatible with Roli Seaboard, Haken Continuum, LinnStrument, Osmose
 *
 * Copyright (c) 2025 Echoelmusic
 */

#pragma once

#include "MIDIEngine.h"
#include <JuceHeader.h>
#include <array>
#include <optional>
#include <functional>

namespace Echoelmusic {

// ============================================================================
// Voice State
// ============================================================================

struct MPEVoice {
    uint8_t channel = 0;
    uint8_t note = 0;
    uint16_t velocity = 0;
    uint32_t pitchBend = 0x80000000;      // Center (32-bit)
    uint32_t pressure = 0;                 // Aftertouch (32-bit)
    uint32_t brightness = 0x80000000;     // CC74 / Timbre Y (32-bit)
    uint32_t timbre = 0x80000000;         // Additional expression
    double startTime = 0;
    bool isActive = false;

    // Calculated values (normalized 0.0 - 1.0)
    float pitchBendSemitones() const {
        // Default MPE pitch bend range: +-48 semitones
        float normalized = static_cast<float>(pitchBend) / static_cast<float>(0xFFFFFFFF);
        return (normalized - 0.5f) * 96.0f;  // +-48 semitones
    }

    float pressureNormalized() const {
        return static_cast<float>(pressure) / static_cast<float>(0xFFFFFFFF);
    }

    float brightnessNormalized() const {
        return static_cast<float>(brightness) / static_cast<float>(0xFFFFFFFF);
    }

    float timbreNormalized() const {
        return static_cast<float>(timbre) / static_cast<float>(0xFFFFFFFF);
    }
};

// ============================================================================
// Voice Stealing Strategy
// ============================================================================

enum class VoiceStealStrategy {
    RoundRobin,     // Steal oldest voice cyclically
    LeastRecent,    // Steal least recently played
    LowestNote,     // Steal lowest pitch note
    HighestNote,    // Steal highest pitch note
    QuietestNote,   // Steal lowest velocity note
    None            // Don't steal, reject new notes
};

// ============================================================================
// MPE Zone Configuration
// ============================================================================

struct MPEZoneConfig {
    uint8_t masterChannel = 0;           // Master channel (0 for lower, 15 for upper)
    uint8_t memberChannelStart = 1;      // First member channel
    uint8_t memberChannelCount = 15;     // Number of member channels
    float pitchBendRange = 48.0f;        // Semitones
    bool isLowerZone = true;             // Lower vs Upper zone
};

// ============================================================================
// Callbacks
// ============================================================================

using VoiceActivatedCallback = std::function<void(const MPEVoice& voice)>;
using VoiceDeactivatedCallback = std::function<void(const MPEVoice& voice)>;
using VoiceUpdatedCallback = std::function<void(const MPEVoice& voice)>;

// ============================================================================
// MPEVoiceManager Class
// ============================================================================

class MPEVoiceManager {
public:
    static constexpr int MAX_VOICES = 15;

    MPEVoiceManager();
    ~MPEVoiceManager() = default;

    // --- Configuration ---
    void configure(const MPEZoneConfig& config);
    const MPEZoneConfig& getConfig() const { return config; }

    void setVoiceStealStrategy(VoiceStealStrategy strategy) { stealStrategy = strategy; }
    VoiceStealStrategy getVoiceStealStrategy() const { return stealStrategy; }

    void setPitchBendRange(float semitones) { config.pitchBendRange = semitones; }
    float getPitchBendRange() const { return config.pitchBendRange; }

    // --- Voice Allocation ---
    std::optional<uint8_t> allocateVoice(uint8_t note, uint16_t velocity);
    void releaseVoice(uint8_t channel, uint8_t note);
    void releaseAllVoices();

    // --- Expression Updates ---
    void updatePitchBend(uint8_t channel, uint32_t value);
    void updatePressure(uint8_t channel, uint32_t value);
    void updateBrightness(uint8_t channel, uint32_t value);
    void updateTimbre(uint8_t channel, uint32_t value);

    // --- Voice Queries ---
    const MPEVoice* getVoice(uint8_t channel) const;
    const MPEVoice* getVoiceByNote(uint8_t note) const;
    const std::array<MPEVoice, MAX_VOICES>& getAllVoices() const { return voices; }
    int getActiveVoiceCount() const;
    bool hasActiveVoices() const;

    // --- Callbacks ---
    void setVoiceActivatedCallback(VoiceActivatedCallback callback) { onVoiceActivated = callback; }
    void setVoiceDeactivatedCallback(VoiceDeactivatedCallback callback) { onVoiceDeactivated = callback; }
    void setVoiceUpdatedCallback(VoiceUpdatedCallback callback) { onVoiceUpdated = callback; }

    // --- MIDIEngine Integration ---
    void connectToMIDIEngine(MIDIEngine& engine);

    // --- Master Channel ---
    void processMasterPitchBend(uint32_t value);
    void processMasterPressure(uint32_t value);
    void processMasterCC(uint8_t cc, uint32_t value);

    uint32_t getMasterPitchBend() const { return masterPitchBend; }
    uint32_t getMasterPressure() const { return masterPressure; }

private:
    // Find channel for new note
    uint8_t findFreeChannel();
    uint8_t stealChannel(uint8_t preferredNote);

    // Voice array (index = member channel offset)
    std::array<MPEVoice, MAX_VOICES> voices;

    // Configuration
    MPEZoneConfig config;
    VoiceStealStrategy stealStrategy = VoiceStealStrategy::LeastRecent;

    // Round-robin index
    int nextChannelIndex = 0;

    // Master channel state
    uint32_t masterPitchBend = 0x80000000;
    uint32_t masterPressure = 0;
    uint32_t masterBrightness = 0x80000000;

    // Callbacks
    VoiceActivatedCallback onVoiceActivated;
    VoiceDeactivatedCallback onVoiceDeactivated;
    VoiceUpdatedCallback onVoiceUpdated;

    // Thread safety
    mutable std::mutex voicesMutex;

    JUCE_DECLARE_NON_COPYABLE_WITH_LEAK_DETECTOR(MPEVoiceManager)
};

} // namespace Echoelmusic
