#pragma once

#include <JuceHeader.h>
#include "../Hardware/MIDI2Manager.h"
#include "../Hardware/MPEVoiceManager.h"
#include "../Hardware/MIDICI.h"
#include <cassert>
#include <iostream>

namespace Echoelmusic {
namespace Tests {

/**
 * MIDI 2.0 / MPE Test Suite
 *
 * Comprehensive tests for:
 * - Universal MIDI Packet creation and parsing
 * - MIDI 1.0 to MIDI 2.0 conversion
 * - MPE voice allocation and management
 * - Per-note controllers
 * - Voice stealing algorithms
 * - MIDI-CI discovery
 */

class MIDI2Tests
{
public:
    //==========================================================================
    // Test Runner
    //==========================================================================

    static bool runAllTests()
    {
        int passed = 0;
        int failed = 0;

        std::cout << "\n========================================\n";
        std::cout << "   MIDI 2.0 / MPE Test Suite\n";
        std::cout << "========================================\n\n";

        // UMP Tests
        runTest("UMP Note On Creation", testUMPNoteOnCreation, passed, failed);
        runTest("UMP Note Off Creation", testUMPNoteOffCreation, passed, failed);
        runTest("UMP Pitch Bend Creation", testUMPPitchBendCreation, passed, failed);
        runTest("UMP Per-Note Pitch Bend", testUMPPerNotePitchBend, passed, failed);
        runTest("UMP Control Change", testUMPControlChange, passed, failed);

        // Scaling Tests
        runTest("7-bit to 32-bit Scaling", testScaling7to32, passed, failed);
        runTest("32-bit to 7-bit Scaling", testScaling32to7, passed, failed);
        runTest("14-bit to 32-bit Scaling", testScaling14to32, passed, failed);
        runTest("Velocity Scaling", testVelocityScaling, passed, failed);

        // MIDI2Manager Tests
        runTest("MIDI2 Note On Processing", testMIDI2NoteOnProcessing, passed, failed);
        runTest("MIDI2 Note Off Processing", testMIDI2NoteOffProcessing, passed, failed);
        runTest("MIDI2 Per-Note State", testMIDI2PerNoteState, passed, failed);
        runTest("MIDI1 to MIDI2 Conversion", testMIDI1toMIDI2Conversion, passed, failed);

        // MPE Tests
        runTest("MPE Zone Configuration Lower", testMPEZoneConfigLower, passed, failed);
        runTest("MPE Zone Configuration Upper", testMPEZoneConfigUpper, passed, failed);
        runTest("MPE Zone Configuration Both", testMPEZoneConfigBoth, passed, failed);
        runTest("MPE Voice Allocation", testMPEVoiceAllocation, passed, failed);
        runTest("MPE Note On/Off", testMPENoteOnOff, passed, failed);
        runTest("MPE Pitch Bend Per Voice", testMPEPitchBend, passed, failed);
        runTest("MPE Pressure", testMPEPressure, passed, failed);
        runTest("MPE Slide (CC74)", testMPESlide, passed, failed);
        runTest("MPE Voice Stealing Oldest", testMPEVoiceStealingOldest, passed, failed);
        runTest("MPE Voice Stealing Quietest", testMPEVoiceStealingQuietest, passed, failed);
        runTest("MPE Glide", testMPEGlide, passed, failed);

        // MIDI-CI Tests
        runTest("MIDI-CI MUID Generation", testMUIDGeneration, passed, failed);
        runTest("MIDI-CI Discovery Message", testDiscoveryMessage, passed, failed);
        runTest("MIDI-CI MPE Profile Request", testMPEProfileRequest, passed, failed);

        // Integration Tests
        runTest("MPE Processor Integration", testMPEProcessorIntegration, passed, failed);
        runTest("Full Voice Lifecycle", testFullVoiceLifecycle, passed, failed);

        // Summary
        std::cout << "\n========================================\n";
        std::cout << "   Results: " << passed << " passed, " << failed << " failed\n";
        std::cout << "========================================\n\n";

        return failed == 0;
    }

private:
    static void runTest(const char* name, bool (*testFunc)(), int& passed, int& failed)
    {
        bool result = false;
        try
        {
            result = testFunc();
        }
        catch (const std::exception& e)
        {
            std::cout << "  [EXCEPTION] " << name << ": " << e.what() << "\n";
            failed++;
            return;
        }

        if (result)
        {
            std::cout << "  [PASS] " << name << "\n";
            passed++;
        }
        else
        {
            std::cout << "  [FAIL] " << name << "\n";
            failed++;
        }
    }

    //==========================================================================
    // UMP Creation Tests
    //==========================================================================

    static bool testUMPNoteOnCreation()
    {
        auto ump = UniversalMIDIPacket::createNoteOn(0, 0, 60, 32768);

        if (ump.numWords != 2) return false;
        if (ump.getMessageType() != MIDI2::MessageType::MIDI2ChannelVoice) return false;
        if (ump.getGroup() != 0) return false;
        if (ump.getStatus() != static_cast<uint8_t>(MIDI2::ChannelVoiceStatus::NoteOn)) return false;
        if (ump.getChannel() != 0) return false;
        if (((ump.word0 >> 8) & 0xFF) != 60) return false;  // Note
        if (((ump.word1 >> 16) & 0xFFFF) != 32768) return false;  // Velocity

        return true;
    }

    static bool testUMPNoteOffCreation()
    {
        auto ump = UniversalMIDIPacket::createNoteOff(1, 5, 72, 16384);

        if (ump.numWords != 2) return false;
        if (ump.getGroup() != 1) return false;
        if (ump.getChannel() != 5) return false;
        if (ump.getStatus() != static_cast<uint8_t>(MIDI2::ChannelVoiceStatus::NoteOff)) return false;

        return true;
    }

    static bool testUMPPitchBendCreation()
    {
        auto ump = UniversalMIDIPacket::createPitchBend(0, 0, 0x80000000);

        if (ump.numWords != 2) return false;
        if (ump.getStatus() != static_cast<uint8_t>(MIDI2::ChannelVoiceStatus::PitchBend)) return false;
        if (ump.word1 != 0x80000000) return false;

        return true;
    }

    static bool testUMPPerNotePitchBend()
    {
        auto ump = UniversalMIDIPacket::createPerNotePitchBend(0, 0, 60, 0xC0000000);

        if (ump.numWords != 2) return false;
        if (ump.getStatus() != static_cast<uint8_t>(MIDI2::ChannelVoiceStatus::PerNotePitchBend)) return false;
        if (((ump.word0 >> 8) & 0xFF) != 60) return false;
        if (ump.word1 != 0xC0000000) return false;

        return true;
    }

    static bool testUMPControlChange()
    {
        auto ump = UniversalMIDIPacket::createControlChange(0, 0, 74, 0xFFFFFFFF);

        if (ump.numWords != 2) return false;
        if (ump.getStatus() != static_cast<uint8_t>(MIDI2::ChannelVoiceStatus::ControlChange)) return false;
        if (((ump.word0 >> 8) & 0xFF) != 74) return false;
        if (ump.word1 != 0xFFFFFFFF) return false;

        return true;
    }

    //==========================================================================
    // Scaling Tests
    //==========================================================================

    static bool testScaling7to32()
    {
        // 0 should map to 0
        if (UniversalMIDIPacket::scale7to32(0) != 0) return false;

        // 127 should map to near max
        uint32_t max = UniversalMIDIPacket::scale7to32(127);
        if (max < 0xFE000000) return false;

        // 64 should be roughly middle
        uint32_t mid = UniversalMIDIPacket::scale7to32(64);
        if (mid < 0x70000000 || mid > 0x90000000) return false;

        return true;
    }

    static bool testScaling32to7()
    {
        // Round-trip test
        for (uint8_t val = 0; val < 128; ++val)
        {
            uint32_t scaled = UniversalMIDIPacket::scale7to32(val);
            uint8_t back = UniversalMIDIPacket::scale32to7(scaled);
            if (back != val) return false;
        }

        return true;
    }

    static bool testScaling14to32()
    {
        // 0 should map to 0
        if (UniversalMIDIPacket::scale14to32(0) != 0) return false;

        // 16383 should map to near max
        uint32_t max = UniversalMIDIPacket::scale14to32(16383);
        if (max < 0xFFF00000) return false;

        // 8192 (center) should be roughly middle
        uint32_t mid = UniversalMIDIPacket::scale14to32(8192);
        if (mid < 0x70000000 || mid > 0x90000000) return false;

        return true;
    }

    static bool testVelocityScaling()
    {
        // Test velocity round-trip
        for (uint8_t vel = 1; vel < 128; ++vel)
        {
            uint16_t scaled = UniversalMIDIPacket::scaleVelocity7to16(vel);
            uint8_t back = UniversalMIDIPacket::scaleVelocity16to7(scaled);
            if (back != vel) return false;
        }

        return true;
    }

    //==========================================================================
    // MIDI2Manager Tests
    //==========================================================================

    static bool testMIDI2NoteOnProcessing()
    {
        MIDI2Manager manager;
        bool noteOnReceived = false;
        uint8_t receivedNote = 0;
        uint16_t receivedVelocity = 0;

        manager.onNoteOn = [&](MIDI2::Group g, MIDI2::Channel ch, uint8_t note, uint16_t vel)
        {
            juce::ignoreUnused(g, ch);
            noteOnReceived = true;
            receivedNote = note;
            receivedVelocity = vel;
        };

        auto ump = UniversalMIDIPacket::createNoteOn(0, 0, 60, 32768);
        manager.processPacket(ump);

        if (!noteOnReceived) return false;
        if (receivedNote != 60) return false;
        if (receivedVelocity != 32768) return false;

        return true;
    }

    static bool testMIDI2NoteOffProcessing()
    {
        MIDI2Manager manager;
        bool noteOffReceived = false;

        manager.onNoteOff = [&](MIDI2::Group g, MIDI2::Channel ch, uint8_t note, uint16_t vel)
        {
            juce::ignoreUnused(g, ch, note, vel);
            noteOffReceived = true;
        };

        auto ump = UniversalMIDIPacket::createNoteOff(0, 0, 60, 0);
        manager.processPacket(ump);

        return noteOffReceived;
    }

    static bool testMIDI2PerNoteState()
    {
        MIDI2Manager manager;

        // Note on
        auto noteOn = UniversalMIDIPacket::createNoteOn(0, 0, 60, 32768);
        manager.processPacket(noteOn);

        // Poly pressure
        auto pressure = UniversalMIDIPacket::createPolyPressure(0, 0, 60, 0x80000000);
        manager.processPacket(pressure);

        // Check state
        auto& state = manager.getNoteState(0, 0, 60);
        if (!state.active) return false;
        if (state.note != 60) return false;
        if (state.velocity != 32768) return false;
        if (state.pressure != 0x80000000) return false;

        return true;
    }

    static bool testMIDI1toMIDI2Conversion()
    {
        MIDI2Manager manager;
        bool noteOnReceived = false;
        uint16_t receivedVelocity = 0;

        manager.onNoteOn = [&](MIDI2::Group g, MIDI2::Channel ch, uint8_t note, uint16_t vel)
        {
            juce::ignoreUnused(g, ch, note);
            noteOnReceived = true;
            receivedVelocity = vel;
        };

        // Create MIDI 1.0 note on
        juce::MidiMessage midi1 = juce::MidiMessage::noteOn(1, 60, (uint8_t)100);
        manager.processMIDI1Message(midi1, 0);

        if (!noteOnReceived) return false;
        // Velocity 100 should scale to approximately 51200 (100 << 9)
        if (receivedVelocity != 51200) return false;

        return true;
    }

    //==========================================================================
    // MPE Tests
    //==========================================================================

    static bool testMPEZoneConfigLower()
    {
        MPEVoiceManager manager;
        manager.configureZone(MPEZoneLayout::Lower);

        auto& zone = manager.getLowerZone();
        if (!zone.enabled) return false;
        if (zone.masterChannel != 0) return false;
        if (zone.firstNoteChannel != 1) return false;
        if (zone.numNoteChannels != 15) return false;

        return true;
    }

    static bool testMPEZoneConfigUpper()
    {
        MPEVoiceManager manager;
        manager.configureZone(MPEZoneLayout::Upper);

        auto& zone = manager.getUpperZone();
        if (!zone.enabled) return false;
        if (zone.masterChannel != 15) return false;

        return true;
    }

    static bool testMPEZoneConfigBoth()
    {
        MPEVoiceManager manager;
        manager.configureZone(MPEZoneLayout::Both);

        if (!manager.getLowerZone().enabled) return false;
        if (!manager.getUpperZone().enabled) return false;
        if (manager.getLowerZone().numNoteChannels != 7) return false;
        if (manager.getUpperZone().numNoteChannels != 7) return false;

        return true;
    }

    static bool testMPEVoiceAllocation()
    {
        MPEVoiceManager manager;
        manager.configureZone(MPEZoneLayout::Lower);

        // Allocate 15 voices (max for MPE)
        for (int i = 0; i < 15; ++i)
        {
            auto* voice = manager.noteOn(static_cast<uint8_t>(i + 1), 60 + i, (uint8_t)100);
            if (!voice) return false;
            if (!voice->active) return false;
        }

        if (manager.getActiveVoiceCount() != 15) return false;

        return true;
    }

    static bool testMPENoteOnOff()
    {
        MPEVoiceManager manager;

        auto* voice = manager.noteOn(1, 60, (uint8_t)100);
        if (!voice || !voice->active) return false;

        manager.noteOff(1, 60);
        if (!voice->releasing) return false;

        manager.voiceEnded(1, 60);
        if (voice->active) return false;

        return true;
    }

    static bool testMPEPitchBend()
    {
        MPEVoiceManager manager;

        auto* voice = manager.noteOn(1, 60, (uint8_t)100);
        if (!voice) return false;

        // Apply pitch bend
        manager.pitchBend(1, 0xC0000000);  // +25% pitch bend

        // Check pitch offset is calculated
        if (voice->pitchBend != 0xC0000000) return false;
        if (voice->pitchOffset <= 0.0f) return false;

        return true;
    }

    static bool testMPEPressure()
    {
        MPEVoiceManager manager;

        auto* voice = manager.noteOn(1, 60, (uint8_t)100);
        if (!voice) return false;

        manager.pressure(1, 0x80000000);

        if (voice->pressure != 0x80000000) return false;
        if (voice->normalizedPressure < 0.49f || voice->normalizedPressure > 0.51f)
            return false;

        return true;
    }

    static bool testMPESlide()
    {
        MPEVoiceManager manager;

        auto* voice = manager.noteOn(1, 60, (uint8_t)100);
        if (!voice) return false;

        manager.controlChange(1, 74, 0xFFFFFFFF);  // Max slide

        if (voice->slide != 0xFFFFFFFF) return false;
        if (voice->normalizedSlide < 0.99f) return false;

        return true;
    }

    static bool testMPEVoiceStealingOldest()
    {
        MPEVoiceManager manager;
        manager.setVoiceStealingMode(VoiceStealingMode::Oldest);

        // Fill all 15 voices
        for (int i = 0; i < 15; ++i)
        {
            manager.noteOn(static_cast<uint8_t>(i + 1), 60 + i, (uint8_t)100);
        }

        // First note should be on channel 1, note 60
        auto* firstVoice = manager.getVoice(1, 60);
        if (!firstVoice) return false;

        // Trigger voice steal with 16th note
        auto* newVoice = manager.noteOn(1, 80, (uint8_t)100);
        if (!newVoice) return false;
        if (newVoice->note != 80) return false;

        // Original first voice should have been stolen
        if (manager.getActiveVoiceCount() != 15) return false;

        return true;
    }

    static bool testMPEVoiceStealingQuietest()
    {
        MPEVoiceManager manager;
        manager.setVoiceStealingMode(VoiceStealingMode::Quietest);

        // Create voices with different velocities
        manager.noteOn(1, 60, (uint8_t)100);
        manager.noteOn(2, 61, (uint8_t)50);   // Quietest
        manager.noteOn(3, 62, (uint8_t)80);

        // Fill remaining voices
        for (int i = 3; i < 15; ++i)
        {
            manager.noteOn(static_cast<uint8_t>(i + 1), 63 + i, (uint8_t)100);
        }

        // Steal - should steal velocity 50 voice
        auto* newVoice = manager.noteOn(1, 90, (uint8_t)100);
        if (!newVoice) return false;

        // Voice with note 61 (quietest) should be stolen
        auto* quietVoice = manager.getVoice(2, 61);
        // It should either be null or reallocated
        if (quietVoice && quietVoice->note == 61 && quietVoice->velocity == 25600)
            return false;

        return true;
    }

    static bool testMPEGlide()
    {
        MPEVoiceManager manager;
        manager.setGlideTime(0.5f);  // 500ms glide

        // First note
        auto* voice = manager.noteOn(1, 60, (uint8_t)100);
        if (!voice) return false;

        // Update to complete glide
        manager.update(0.5f);
        if (voice->glideProgress < 1.0f) return false;

        // Second note on same channel should glide from first
        manager.voiceEnded(1, 60);
        auto* voice2 = manager.noteOn(1, 72, (uint8_t)100);
        if (!voice2) return false;

        // Glide should start from note 60
        if (voice2->glideSource != 60.0f) return false;
        if (voice2->glideProgress >= 1.0f) return false;

        return true;
    }

    //==========================================================================
    // MIDI-CI Tests
    //==========================================================================

    static bool testMUIDGeneration()
    {
        MUID muid1 = MUID::generate();
        MUID muid2 = MUID::generate();

        // Should be unique
        if (muid1 == muid2) return false;

        // Should be valid (not broadcast)
        if (muid1.isBroadcast()) return false;

        // Round-trip bytes
        auto bytes = muid1.toBytes();
        MUID reconstructed = MUID::fromBytes(bytes.data());
        if (reconstructed != muid1) return false;

        return true;
    }

    static bool testDiscoveryMessage()
    {
        MIDICIManager manager;
        auto sysex = manager.createDiscoveryInquiry();

        // Should start with SysEx
        if (sysex.empty()) return false;
        if (sysex[0] != 0xF0) return false;
        if (sysex.back() != 0xF7) return false;

        // Should contain MIDI-CI sub-ID
        if (sysex[3] != 0x0D) return false;

        // Should be Discovery Inquiry
        if (sysex[4] != 0x70) return false;

        return true;
    }

    static bool testMPEProfileRequest()
    {
        MIDICIManager manager;
        MUID targetMUID = MUID::generate();

        auto sysex = manager.createMPEProfileRequest(targetMUID, true);

        if (sysex.empty()) return false;
        if (sysex[0] != 0xF0) return false;

        // Should be Set Profile On
        if (sysex[4] != 0x22) return false;

        return true;
    }

    //==========================================================================
    // Integration Tests
    //==========================================================================

    static bool testMPEProcessorIntegration()
    {
        MPEProcessor processor;
        bool voiceStarted = false;

        processor.getVoiceManager().onVoiceStarted = [&](const MPEVoice& voice)
        {
            juce::ignoreUnused(voice);
            voiceStarted = true;
        };

        // Process MIDI 1.0 note on
        juce::MidiMessage noteOn = juce::MidiMessage::noteOn(2, 60, (uint8_t)100);
        processor.processMidiMessage(noteOn);

        if (!voiceStarted) return false;
        if (processor.getVoiceManager().getActiveVoiceCount() != 1) return false;

        return true;
    }

    static bool testFullVoiceLifecycle()
    {
        MPEProcessor processor;

        int started = 0;
        int updated = 0;
        int released = 0;
        int ended = 0;

        processor.getVoiceManager().onVoiceStarted = [&](const MPEVoice&) { started++; };
        processor.getVoiceManager().onVoiceUpdated = [&](const MPEVoice&) { updated++; };
        processor.getVoiceManager().onVoiceReleased = [&](const MPEVoice&) { released++; };
        processor.getVoiceManager().onVoiceEnded = [&](const MPEVoice&) { ended++; };

        // Note on
        juce::MidiMessage noteOn = juce::MidiMessage::noteOn(2, 60, (uint8_t)100);
        processor.processMidiMessage(noteOn);
        if (started != 1) return false;

        // Pitch bend
        juce::MidiMessage pitchBend = juce::MidiMessage::pitchWheel(2, 12000);
        processor.processMidiMessage(pitchBend);
        if (updated < 1) return false;

        // Pressure
        juce::MidiMessage pressure = juce::MidiMessage::channelPressureChange(2, 100);
        processor.processMidiMessage(pressure);

        // Note off
        juce::MidiMessage noteOff = juce::MidiMessage::noteOff(2, 60);
        processor.processMidiMessage(noteOff);
        if (released != 1) return false;

        // Simulate envelope complete
        processor.getVoiceManager().voiceEnded(1, 60);  // Channel 2 = index 1
        if (ended != 1) return false;

        return true;
    }
};

} // namespace Tests
} // namespace Echoelmusic
