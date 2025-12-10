/**
 * MPEVoiceManager.cpp
 * Echoelmusic MPE Voice Manager Implementation
 *
 * Copyright (c) 2025 Echoelmusic
 */

#include "MPEVoiceManager.h"

namespace Echoelmusic {

// ============================================================================
// Constructor
// ============================================================================

MPEVoiceManager::MPEVoiceManager() {
    // Initialize default MPE Lower Zone configuration
    config.masterChannel = 0;
    config.memberChannelStart = 1;
    config.memberChannelCount = 15;
    config.pitchBendRange = 48.0f;
    config.isLowerZone = true;

    // Initialize all voices
    for (int i = 0; i < MAX_VOICES; ++i) {
        voices[i].channel = static_cast<uint8_t>(config.memberChannelStart + i);
        voices[i].isActive = false;
    }

    DBG("MPEVoiceManager: Initialized with " << MAX_VOICES << " voices (Lower Zone)");
}

// ============================================================================
// Configuration
// ============================================================================

void MPEVoiceManager::configure(const MPEZoneConfig& newConfig) {
    std::lock_guard<std::mutex> lock(voicesMutex);

    config = newConfig;

    // Reinitialize voice channels
    for (int i = 0; i < MAX_VOICES; ++i) {
        if (i < config.memberChannelCount) {
            voices[i].channel = static_cast<uint8_t>(config.memberChannelStart + i);
        }
        voices[i].isActive = false;
    }

    nextChannelIndex = 0;

    DBG("MPEVoiceManager: Reconfigured - Master: " << static_cast<int>(config.masterChannel)
        << ", Members: " << static_cast<int>(config.memberChannelStart)
        << "-" << static_cast<int>(config.memberChannelStart + config.memberChannelCount - 1));
}

// ============================================================================
// Voice Allocation
// ============================================================================

std::optional<uint8_t> MPEVoiceManager::allocateVoice(uint8_t note, uint16_t velocity) {
    std::lock_guard<std::mutex> lock(voicesMutex);

    // Find free channel
    uint8_t channel = findFreeChannel();

    // If no free channel, try stealing
    if (channel == 0xFF && stealStrategy != VoiceStealStrategy::None) {
        channel = stealChannel(note);
    }

    // Still no channel available
    if (channel == 0xFF) {
        DBG("MPEVoiceManager: No channel available for note " << static_cast<int>(note));
        return std::nullopt;
    }

    // Calculate voice index
    int voiceIndex = channel - config.memberChannelStart;
    if (voiceIndex < 0 || voiceIndex >= MAX_VOICES) {
        return std::nullopt;
    }

    // If stealing an active voice, deactivate it first
    if (voices[voiceIndex].isActive && onVoiceDeactivated) {
        onVoiceDeactivated(voices[voiceIndex]);
    }

    // Initialize voice
    MPEVoice& voice = voices[voiceIndex];
    voice.channel = channel;
    voice.note = note;
    voice.velocity = velocity;
    voice.pitchBend = masterPitchBend;  // Start with master pitch
    voice.pressure = 0;
    voice.brightness = masterBrightness;
    voice.timbre = 0x80000000;
    voice.startTime = juce::Time::getMillisecondCounterHiRes() / 1000.0;
    voice.isActive = true;

    // Fire callback
    if (onVoiceActivated) {
        onVoiceActivated(voice);
    }

    DBG("MPEVoiceManager: Allocated voice - Ch: " << static_cast<int>(channel)
        << ", Note: " << static_cast<int>(note) << ", Vel: " << velocity);

    return channel;
}

void MPEVoiceManager::releaseVoice(uint8_t channel, uint8_t note) {
    std::lock_guard<std::mutex> lock(voicesMutex);

    // Find voice by channel
    int voiceIndex = channel - config.memberChannelStart;
    if (voiceIndex < 0 || voiceIndex >= MAX_VOICES) {
        return;
    }

    MPEVoice& voice = voices[voiceIndex];

    // Verify note matches (in case of reassignment)
    if (voice.note == note && voice.isActive) {
        voice.isActive = false;

        // Fire callback
        if (onVoiceDeactivated) {
            onVoiceDeactivated(voice);
        }

        DBG("MPEVoiceManager: Released voice - Ch: " << static_cast<int>(channel)
            << ", Note: " << static_cast<int>(note));
    }
}

void MPEVoiceManager::releaseAllVoices() {
    std::lock_guard<std::mutex> lock(voicesMutex);

    for (auto& voice : voices) {
        if (voice.isActive) {
            voice.isActive = false;
            if (onVoiceDeactivated) {
                onVoiceDeactivated(voice);
            }
        }
    }

    nextChannelIndex = 0;
    DBG("MPEVoiceManager: Released all voices");
}

// ============================================================================
// Expression Updates
// ============================================================================

void MPEVoiceManager::updatePitchBend(uint8_t channel, uint32_t value) {
    // Check if master channel
    if (channel == config.masterChannel) {
        processMasterPitchBend(value);
        return;
    }

    std::lock_guard<std::mutex> lock(voicesMutex);

    int voiceIndex = channel - config.memberChannelStart;
    if (voiceIndex < 0 || voiceIndex >= MAX_VOICES) return;

    MPEVoice& voice = voices[voiceIndex];
    if (!voice.isActive) return;

    voice.pitchBend = value;

    if (onVoiceUpdated) {
        onVoiceUpdated(voice);
    }
}

void MPEVoiceManager::updatePressure(uint8_t channel, uint32_t value) {
    if (channel == config.masterChannel) {
        processMasterPressure(value);
        return;
    }

    std::lock_guard<std::mutex> lock(voicesMutex);

    int voiceIndex = channel - config.memberChannelStart;
    if (voiceIndex < 0 || voiceIndex >= MAX_VOICES) return;

    MPEVoice& voice = voices[voiceIndex];
    if (!voice.isActive) return;

    voice.pressure = value;

    if (onVoiceUpdated) {
        onVoiceUpdated(voice);
    }
}

void MPEVoiceManager::updateBrightness(uint8_t channel, uint32_t value) {
    if (channel == config.masterChannel) {
        masterBrightness = value;
        return;
    }

    std::lock_guard<std::mutex> lock(voicesMutex);

    int voiceIndex = channel - config.memberChannelStart;
    if (voiceIndex < 0 || voiceIndex >= MAX_VOICES) return;

    MPEVoice& voice = voices[voiceIndex];
    if (!voice.isActive) return;

    voice.brightness = value;

    if (onVoiceUpdated) {
        onVoiceUpdated(voice);
    }
}

void MPEVoiceManager::updateTimbre(uint8_t channel, uint32_t value) {
    std::lock_guard<std::mutex> lock(voicesMutex);

    int voiceIndex = channel - config.memberChannelStart;
    if (voiceIndex < 0 || voiceIndex >= MAX_VOICES) return;

    MPEVoice& voice = voices[voiceIndex];
    if (!voice.isActive) return;

    voice.timbre = value;

    if (onVoiceUpdated) {
        onVoiceUpdated(voice);
    }
}

// ============================================================================
// Voice Queries
// ============================================================================

const MPEVoice* MPEVoiceManager::getVoice(uint8_t channel) const {
    std::lock_guard<std::mutex> lock(voicesMutex);

    int voiceIndex = channel - config.memberChannelStart;
    if (voiceIndex < 0 || voiceIndex >= MAX_VOICES) return nullptr;

    return &voices[voiceIndex];
}

const MPEVoice* MPEVoiceManager::getVoiceByNote(uint8_t note) const {
    std::lock_guard<std::mutex> lock(voicesMutex);

    for (const auto& voice : voices) {
        if (voice.isActive && voice.note == note) {
            return &voice;
        }
    }
    return nullptr;
}

int MPEVoiceManager::getActiveVoiceCount() const {
    std::lock_guard<std::mutex> lock(voicesMutex);

    int count = 0;
    for (const auto& voice : voices) {
        if (voice.isActive) count++;
    }
    return count;
}

bool MPEVoiceManager::hasActiveVoices() const {
    std::lock_guard<std::mutex> lock(voicesMutex);

    for (const auto& voice : voices) {
        if (voice.isActive) return true;
    }
    return false;
}

// ============================================================================
// MIDIEngine Integration
// ============================================================================

void MPEVoiceManager::connectToMIDIEngine(MIDIEngine& engine) {
    // Note On - allocate voice
    engine.setNoteOnCallback([this](uint8_t channel, uint8_t note, uint16_t velocity, uint8_t group) {
        // Check if this is a member channel
        if (channel >= config.memberChannelStart &&
            channel < config.memberChannelStart + config.memberChannelCount) {
            // Direct member channel note (from MPE controller)
            allocateVoice(note, velocity);
        } else if (channel == config.masterChannel) {
            // Master channel note - allocate to next available
            allocateVoice(note, velocity);
        }
    });

    // Note Off - release voice
    engine.setNoteOffCallback([this](uint8_t channel, uint8_t note, uint16_t velocity, uint8_t group) {
        if (channel >= config.memberChannelStart &&
            channel < config.memberChannelStart + config.memberChannelCount) {
            releaseVoice(channel, note);
        } else if (channel == config.masterChannel) {
            // Find voice by note for master channel
            auto* voice = getVoiceByNote(note);
            if (voice) {
                releaseVoice(voice->channel, note);
            }
        }
    });

    // Pitch Bend
    engine.setPitchBendCallback([this](uint8_t channel, uint32_t value, uint8_t group) {
        updatePitchBend(channel, value);
    });

    // Poly Pressure
    engine.setPolyPressureCallback([this](uint8_t channel, uint8_t note, uint32_t pressure, uint8_t group) {
        updatePressure(channel, pressure);
    });

    // CC74 = Brightness (MPE Slide/Y-axis)
    engine.setControlChangeCallback([this](uint8_t channel, uint8_t cc, uint32_t value, uint8_t group) {
        if (cc == 74) {  // Brightness / Timbre Y
            updateBrightness(channel, value);
        } else if (cc == 1) {  // Modulation
            updateTimbre(channel, value);
        }
    });

    DBG("MPEVoiceManager: Connected to MIDIEngine");
}

// ============================================================================
// Master Channel
// ============================================================================

void MPEVoiceManager::processMasterPitchBend(uint32_t value) {
    masterPitchBend = value;

    // Apply to all active voices
    std::lock_guard<std::mutex> lock(voicesMutex);
    for (auto& voice : voices) {
        if (voice.isActive) {
            // Combine master + per-note pitch bend
            // For simplicity, just use master value here
            // A full implementation would blend them
            if (onVoiceUpdated) {
                onVoiceUpdated(voice);
            }
        }
    }
}

void MPEVoiceManager::processMasterPressure(uint32_t value) {
    masterPressure = value;
    // Master pressure typically doesn't affect individual voices in MPE
}

void MPEVoiceManager::processMasterCC(uint8_t cc, uint32_t value) {
    // Handle master channel CCs (e.g., sustain pedal)
    if (cc == 64) {  // Sustain pedal
        // TODO: Implement sustain hold
    }
}

// ============================================================================
// Private: Voice Allocation
// ============================================================================

uint8_t MPEVoiceManager::findFreeChannel() {
    // Start from nextChannelIndex for round-robin fairness
    for (int i = 0; i < static_cast<int>(config.memberChannelCount); ++i) {
        int idx = (nextChannelIndex + i) % config.memberChannelCount;
        if (!voices[idx].isActive) {
            nextChannelIndex = (idx + 1) % config.memberChannelCount;
            return static_cast<uint8_t>(config.memberChannelStart + idx);
        }
    }
    return 0xFF;  // No free channel
}

uint8_t MPEVoiceManager::stealChannel(uint8_t preferredNote) {
    int stealIndex = -1;

    switch (stealStrategy) {
        case VoiceStealStrategy::RoundRobin: {
            // Steal the next voice in sequence
            stealIndex = nextChannelIndex;
            nextChannelIndex = (nextChannelIndex + 1) % config.memberChannelCount;
            break;
        }

        case VoiceStealStrategy::LeastRecent: {
            // Find oldest active voice
            double oldestTime = std::numeric_limits<double>::max();
            for (int i = 0; i < static_cast<int>(config.memberChannelCount); ++i) {
                if (voices[i].isActive && voices[i].startTime < oldestTime) {
                    oldestTime = voices[i].startTime;
                    stealIndex = i;
                }
            }
            break;
        }

        case VoiceStealStrategy::LowestNote: {
            // Find lowest pitch voice
            int lowestNote = 128;
            for (int i = 0; i < static_cast<int>(config.memberChannelCount); ++i) {
                if (voices[i].isActive && voices[i].note < lowestNote) {
                    lowestNote = voices[i].note;
                    stealIndex = i;
                }
            }
            break;
        }

        case VoiceStealStrategy::HighestNote: {
            // Find highest pitch voice
            int highestNote = -1;
            for (int i = 0; i < static_cast<int>(config.memberChannelCount); ++i) {
                if (voices[i].isActive && voices[i].note > highestNote) {
                    highestNote = voices[i].note;
                    stealIndex = i;
                }
            }
            break;
        }

        case VoiceStealStrategy::QuietestNote: {
            // Find lowest velocity voice
            uint16_t lowestVel = 0xFFFF;
            for (int i = 0; i < static_cast<int>(config.memberChannelCount); ++i) {
                if (voices[i].isActive && voices[i].velocity < lowestVel) {
                    lowestVel = voices[i].velocity;
                    stealIndex = i;
                }
            }
            break;
        }

        case VoiceStealStrategy::None:
        default:
            return 0xFF;
    }

    if (stealIndex >= 0 && stealIndex < static_cast<int>(config.memberChannelCount)) {
        return static_cast<uint8_t>(config.memberChannelStart + stealIndex);
    }

    return 0xFF;
}

} // namespace Echoelmusic
