#pragma once

#include "../Audio/AudioRoutingManager.h"
#include "../Hardware/MIDIRoutingMatrix.h"
#include <JuceHeader.h>
#include <cassert>
#include <cmath>
#include <iostream>
#include <vector>

namespace Echoelmusic {
namespace Tests {

/**
 * RoutingTests - Comprehensive Test Suite for Audio and MIDI Routing
 *
 * Tests:
 * - Audio Bus Management (Send/Return, Group, Master)
 * - Audio Signal Routing
 * - Sidechain Routing
 * - Plugin Delay Compensation
 * - MIDI Route Creation and Management
 * - MIDI Filtering
 * - MIDI Transformation
 * - Virtual MIDI Ports
 * - State Persistence
 */

class RoutingTests
{
public:
    struct TestResult
    {
        juce::String name;
        bool passed = false;
        juce::String message;
        double durationMs = 0;
    };

    //==========================================================================
    // Test Runner
    //==========================================================================

    std::vector<TestResult> runAllTests()
    {
        std::vector<TestResult> results;

        // Audio Routing Tests
        results.push_back(testAudioBusCreation());
        results.push_back(testSendBusRouting());
        results.push_back(testGroupBusRouting());
        results.push_back(testTrackRouting());
        results.push_back(testSidechainRouting());
        results.push_back(testDelayCompensation());
        results.push_back(testAudioSignalFlow());
        results.push_back(testAudioMetering());
        results.push_back(testAudioStatePeristence());

        // MIDI Routing Tests
        results.push_back(testMIDIRouteCreation());
        results.push_back(testMIDIFiltering());
        results.push_back(testMIDIChannelFilter());
        results.push_back(testMIDINoteRangeFilter());
        results.push_back(testMIDITranspose());
        results.push_back(testMIDIVelocityScaling());
        results.push_back(testMIDIChannelRemap());
        results.push_back(testMIDICCRemap());
        results.push_back(testVirtualMIDIPorts());
        results.push_back(testMIDIRouteProcessing());
        results.push_back(testMIDILearn());
        results.push_back(testMIDIStatePeristence());

        // Integration Tests
        results.push_back(testMultiTrackRouting());
        results.push_back(testComplexRoutingScenario());

        return results;
    }

    void printResults(const std::vector<TestResult>& results)
    {
        int passed = 0;
        int failed = 0;

        std::cout << "\n========================================\n";
        std::cout << "   Routing Tests Results\n";
        std::cout << "========================================\n\n";

        for (const auto& result : results)
        {
            if (result.passed)
            {
                std::cout << "[PASS] " << result.name << " (" << result.durationMs << "ms)\n";
                passed++;
            }
            else
            {
                std::cout << "[FAIL] " << result.name << "\n";
                std::cout << "       " << result.message << "\n";
                failed++;
            }
        }

        std::cout << "\n----------------------------------------\n";
        std::cout << "Total: " << (passed + failed) << " | ";
        std::cout << "Passed: " << passed << " | ";
        std::cout << "Failed: " << failed << "\n";
        std::cout << "----------------------------------------\n\n";
    }

private:
    //==========================================================================
    // Audio Routing Tests
    //==========================================================================

    TestResult testAudioBusCreation()
    {
        TestResult result { "Audio Bus Creation" };
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            AudioRoutingManager router;
            router.prepare(48000.0, 512);

            // Test send bus creation
            int sendIdx = router.createSendBus("Test Reverb", ChannelFormat::Stereo);
            if (sendIdx < 0)
                throw std::runtime_error("Failed to create send bus");

            auto* sendBus = router.getSendBus(sendIdx);
            if (!sendBus || sendBus->getName() != "Test Reverb")
                throw std::runtime_error("Send bus name mismatch");

            // Test group bus creation
            int groupIdx = router.createGroupBus("Drums", ChannelFormat::Stereo);
            if (groupIdx < 0)
                throw std::runtime_error("Failed to create group bus");

            auto* groupBus = router.getGroupBus(groupIdx);
            if (!groupBus || groupBus->getName() != "Drums")
                throw std::runtime_error("Group bus name mismatch");

            // Test default busses (Reverb, Delay created in constructor)
            if (router.getNumSendBusses() < 3)
                throw std::runtime_error("Default send busses not created");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testSendBusRouting()
    {
        TestResult result { "Send Bus Routing" };
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            AudioRoutingManager router;
            router.prepare(48000.0, 512);

            // Create send bus
            int sendIdx = router.createSendBus("Delay", ChannelFormat::Stereo);

            // Set track send
            router.setTrackSend(0, sendIdx, 0.5f, SendPosition::PostFader);

            auto& trackRouting = router.getTrackRouting(0);
            if (trackRouting.sends.empty())
                throw std::runtime_error("Send not added to track");

            if (std::abs(trackRouting.sends[0].level - 0.5f) > 0.001f)
                throw std::runtime_error("Send level not set correctly");

            if (trackRouting.sends[0].position != SendPosition::PostFader)
                throw std::runtime_error("Send position not set correctly");

            // Test pre-fader send
            router.setTrackSend(0, sendIdx, 0.75f, SendPosition::PreFader);
            if (trackRouting.sends[0].position != SendPosition::PreFader)
                throw std::runtime_error("Pre-fader position not set");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testGroupBusRouting()
    {
        TestResult result { "Group Bus Routing" };
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            AudioRoutingManager router;
            router.prepare(48000.0, 512);

            // Create group bus
            int groupIdx = router.createGroupBus("Synths", ChannelFormat::Stereo);

            // Route track to group
            router.routeTrackToGroup(0, groupIdx);
            router.routeTrackToGroup(1, groupIdx);

            auto* groupBus = router.getGroupBus(groupIdx);
            if (!groupBus)
                throw std::runtime_error("Group bus not found");

            const auto& tracks = groupBus->getTracks();
            if (tracks.size() != 2)
                throw std::runtime_error("Tracks not added to group");

            // Verify track routing
            if (router.getTrackRouting(0).outputBusIndex != groupIdx)
                throw std::runtime_error("Track output not set to group");

            // Test remove from group
            router.routeTrackToMaster(0);
            if (router.getTrackRouting(0).outputBusIndex != -1)
                throw std::runtime_error("Track not removed from group");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testTrackRouting()
    {
        TestResult result { "Track Routing Configuration" };
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            AudioRoutingManager router;
            router.prepare(48000.0, 512);

            auto& routing = router.getTrackRouting(5);

            // Test direct output
            router.setTrackDirectOutput(5, 3);
            if (routing.directOutputChannel != 3)
                throw std::runtime_error("Direct output not set");

            // Test input channel
            routing.inputChannel = 2;
            routing.inputMonitorEnabled = true;

            if (!routing.inputMonitorEnabled)
                throw std::runtime_error("Input monitor not enabled");

            // Test multiple sends
            int send1 = router.createSendBus("FX1");
            int send2 = router.createSendBus("FX2");

            router.setTrackSend(5, send1, 0.3f);
            router.setTrackSend(5, send2, 0.6f);

            if (routing.sends.size() != 2)
                throw std::runtime_error("Multiple sends not added");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testSidechainRouting()
    {
        TestResult result { "Sidechain Routing" };
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            AudioRoutingManager router;
            router.prepare(48000.0, 512);

            // Create sidechain source from track 0 (kick drum)
            router.createSidechainSource(0);

            auto* sidechain = router.getSidechainSource(0);
            if (!sidechain)
                throw std::runtime_error("Sidechain source not created");

            // Verify track has sidechain enabled
            if (!router.getTrackRouting(0).sidechainOutputEnabled)
                throw std::runtime_error("Sidechain output not enabled on track");

            // Test feeding audio to sidechain
            juce::AudioBuffer<float> testBuffer(2, 512);
            for (int ch = 0; ch < 2; ++ch)
            {
                for (int i = 0; i < 512; ++i)
                {
                    testBuffer.setSample(ch, i, 0.5f * std::sin(2.0f * juce::MathConstants<float>::pi * i / 100.0f));
                }
            }

            sidechain->feedBuffer(testBuffer, 512);

            // Check envelope detection
            float envelope = sidechain->getEnvelopeLevel();
            if (envelope <= 0.0f)
                throw std::runtime_error("Envelope not detected");

            float rms = sidechain->getRMSLevel();
            if (rms <= 0.0f)
                throw std::runtime_error("RMS not calculated");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testDelayCompensation()
    {
        TestResult result { "Plugin Delay Compensation" };
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            AudioRoutingManager router;
            router.prepare(48000.0, 512);

            // Set latency on busses
            auto* sendBus = router.getSendBus(0);
            if (sendBus)
                sendBus->setLatencySamples(256);

            int groupIdx = router.createGroupBus("Test Group");
            auto* groupBus = router.getGroupBus(groupIdx);
            if (groupBus)
                groupBus->setLatencySamples(512);

            // Calculate delay compensation
            router.calculateDelayCompensation();

            int totalLatency = router.getTotalLatencySamples();
            if (totalLatency < 512)
                throw std::runtime_error("Total latency not calculated correctly");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testAudioSignalFlow()
    {
        TestResult result { "Audio Signal Flow" };
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            AudioRoutingManager router;
            router.prepare(48000.0, 512);

            const int numSamples = 512;

            // Create test signal
            juce::AudioBuffer<float> trackBuffer(2, numSamples);
            for (int ch = 0; ch < 2; ++ch)
            {
                for (int i = 0; i < numSamples; ++i)
                {
                    trackBuffer.setSample(ch, i, 0.5f);
                }
            }

            // Setup routing
            int sendIdx = router.createSendBus("TestFX");
            router.setTrackSend(0, sendIdx, 0.5f, SendPosition::PostFader);

            // Process
            router.beginBlock(numSamples);
            router.routeTrackAudio(0, trackBuffer, numSamples, 0.8f, 0.0f);
            router.endBlock(numSamples);

            // Check master bus received audio
            const auto& masterBuffer = router.getMasterBus().getBuffer();
            float masterPeak = masterBuffer.getMagnitude(0, numSamples);
            if (masterPeak <= 0.0f)
                throw std::runtime_error("No audio in master bus");

            // Check send bus received audio
            auto* sendBus = router.getSendBus(sendIdx);
            if (sendBus)
            {
                float sendPeak = sendBus->getPeakLevel(0);
                if (sendPeak <= 0.0f)
                    throw std::runtime_error("No audio in send bus");
            }

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testAudioMetering()
    {
        TestResult result { "Audio Metering" };
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            AudioBus bus(BusType::Master, "Test", ChannelFormat::Stereo);
            bus.prepare(48000.0, 512);

            // Create test signal with known peak
            juce::AudioBuffer<float> testBuffer(2, 512);
            testBuffer.clear();
            testBuffer.setSample(0, 100, 0.8f);  // Peak at sample 100
            testBuffer.setSample(1, 200, 0.6f);  // Peak at sample 200

            bus.addToBuffer(testBuffer, 512, 1.0f, 0.0f);
            bus.updateMetering(512);

            float leftPeak = bus.getPeakLevel(0);
            float rightPeak = bus.getPeakLevel(1);

            if (leftPeak < 0.7f || leftPeak > 0.9f)
                throw std::runtime_error("Left peak metering incorrect");

            if (rightPeak < 0.5f || rightPeak > 0.7f)
                throw std::runtime_error("Right peak metering incorrect");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testAudioStatePeristence()
    {
        TestResult result { "Audio State Persistence" };
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            AudioRoutingManager router;
            router.prepare(48000.0, 512);

            // Configure routing
            int sendIdx = router.createSendBus("MyReverb");
            router.getSendBus(sendIdx)->setVolume(0.75f);
            router.getSendBus(sendIdx)->setPan(-0.3f);

            int groupIdx = router.createGroupBus("MyGroup");
            router.getGroupBus(groupIdx)->setVolume(0.9f);

            // Save state
            juce::var state = router.getState();

            // Create new router and restore
            AudioRoutingManager router2;
            router2.prepare(48000.0, 512);
            router2.restoreState(state);

            // Verify restoration
            // Note: indices may differ due to default busses
            bool foundReverb = false;
            for (int i = 0; i < router2.getNumSendBusses(); ++i)
            {
                auto* bus = router2.getSendBus(i);
                if (bus && bus->getName() == "MyReverb")
                {
                    foundReverb = true;
                    if (std::abs(bus->getVolume() - 0.75f) > 0.01f)
                        throw std::runtime_error("Send volume not restored");
                }
            }

            if (!foundReverb)
                throw std::runtime_error("Send bus not restored");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    //==========================================================================
    // MIDI Routing Tests
    //==========================================================================

    TestResult testMIDIRouteCreation()
    {
        TestResult result { "MIDI Route Creation" };
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            MIDIRoutingMatrix router;
            router.prepare(48000.0, 512);

            // Register devices
            router.registerHardwareInput("MIDI Keyboard", "keyboard-1");
            router.registerHardwareOutput("Synth Module", "synth-1");

            // Create route from input to track
            MIDIEndpoint src = router.getHardwareInputs()[0];
            MIDIEndpoint dst = router.getTrackInputEndpoint(0);

            int routeIdx = router.createRoute(src, dst);
            if (routeIdx < 0)
                throw std::runtime_error("Failed to create route");

            auto* route = router.getRoute(routeIdx);
            if (!route)
                throw std::runtime_error("Route not found");

            if (!route->isEnabled())
                throw std::runtime_error("Route not enabled by default");

            // Test duplicate prevention
            int duplicateIdx = router.createRoute(src, dst);
            if (duplicateIdx != routeIdx)
                throw std::runtime_error("Duplicate route created");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testMIDIFiltering()
    {
        TestResult result { "MIDI Message Type Filtering" };
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            MIDIFilter filter;

            // Test note filtering
            filter.setMessageFilter(MIDIMessageFilter::Notes);

            auto noteOn = juce::MidiMessage::noteOn(1, 60, (juce::uint8)100);
            auto noteOff = juce::MidiMessage::noteOff(1, 60);
            auto cc = juce::MidiMessage::controllerEvent(1, 1, 64);

            if (!filter.passes(noteOn))
                throw std::runtime_error("Note on should pass");

            if (!filter.passes(noteOff))
                throw std::runtime_error("Note off should pass");

            if (filter.passes(cc))
                throw std::runtime_error("CC should not pass notes filter");

            // Test CC filtering
            filter.setMessageFilter(MIDIMessageFilter::ControlChange);

            if (filter.passes(noteOn))
                throw std::runtime_error("Note should not pass CC filter");

            if (!filter.passes(cc))
                throw std::runtime_error("CC should pass");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testMIDIChannelFilter()
    {
        TestResult result { "MIDI Channel Filtering" };
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            MIDIFilter filter;

            // Only enable channel 1
            filter.disableAllChannels();
            filter.enableChannel(1, true);

            auto noteCh1 = juce::MidiMessage::noteOn(1, 60, (juce::uint8)100);
            auto noteCh2 = juce::MidiMessage::noteOn(2, 60, (juce::uint8)100);
            auto noteCh10 = juce::MidiMessage::noteOn(10, 60, (juce::uint8)100);

            if (!filter.passes(noteCh1))
                throw std::runtime_error("Channel 1 should pass");

            if (filter.passes(noteCh2))
                throw std::runtime_error("Channel 2 should not pass");

            if (filter.passes(noteCh10))
                throw std::runtime_error("Channel 10 should not pass");

            // Enable channel 10
            filter.enableChannel(10, true);

            if (!filter.passes(noteCh10))
                throw std::runtime_error("Channel 10 should now pass");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testMIDINoteRangeFilter()
    {
        TestResult result { "MIDI Note Range Filtering" };
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            MIDIFilter filter;
            filter.setNoteRange(36, 84);  // C2 to C6

            auto noteInRange = juce::MidiMessage::noteOn(1, 60, (juce::uint8)100);   // C4
            auto noteBelowRange = juce::MidiMessage::noteOn(1, 24, (juce::uint8)100);  // C1
            auto noteAboveRange = juce::MidiMessage::noteOn(1, 96, (juce::uint8)100);  // C7

            if (!filter.passes(noteInRange))
                throw std::runtime_error("Note in range should pass");

            if (filter.passes(noteBelowRange))
                throw std::runtime_error("Note below range should not pass");

            if (filter.passes(noteAboveRange))
                throw std::runtime_error("Note above range should not pass");

            // Test velocity range
            filter.setVelocityRange(20, 100);

            auto softNote = juce::MidiMessage::noteOn(1, 60, (juce::uint8)10);
            auto loudNote = juce::MidiMessage::noteOn(1, 60, (juce::uint8)127);
            auto mediumNote = juce::MidiMessage::noteOn(1, 60, (juce::uint8)80);

            if (filter.passes(softNote))
                throw std::runtime_error("Soft note should not pass");

            if (filter.passes(loudNote))
                throw std::runtime_error("Loud note should not pass");

            if (!filter.passes(mediumNote))
                throw std::runtime_error("Medium velocity note should pass");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testMIDITranspose()
    {
        TestResult result { "MIDI Transpose" };
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            MIDITransform transform;

            // Transpose up an octave
            transform.setTranspose(12);

            auto noteC4 = juce::MidiMessage::noteOn(1, 60, (juce::uint8)100);
            auto transposed = transform.transform(noteC4);

            if (transposed.getNoteNumber() != 72)
                throw std::runtime_error("Transpose up failed");

            // Transpose down
            transform.setTranspose(-12);
            auto transposedDown = transform.transform(noteC4);

            if (transposedDown.getNoteNumber() != 48)
                throw std::runtime_error("Transpose down failed");

            // Test clamping at boundaries
            transform.setTranspose(60);
            auto highNote = juce::MidiMessage::noteOn(1, 100, (juce::uint8)100);
            auto clamped = transform.transform(highNote);

            if (clamped.getNoteNumber() > 127)
                throw std::runtime_error("Note not clamped at max");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testMIDIVelocityScaling()
    {
        TestResult result { "MIDI Velocity Scaling" };
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            MIDITransform transform;

            // Scale velocity to 50%
            transform.setVelocityScale(0.5f);

            auto note = juce::MidiMessage::noteOn(1, 60, (juce::uint8)100);
            auto scaled = transform.transform(note);

            int expectedVel = 50;
            int actualVel = scaled.getVelocity();

            if (std::abs(actualVel - expectedVel) > 5)
                throw std::runtime_error("Velocity scale failed: expected ~" +
                    std::to_string(expectedVel) + ", got " + std::to_string(actualVel));

            // Test velocity offset
            transform.setVelocityScale(1.0f);
            transform.setVelocityOffset(20);

            auto offsetNote = transform.transform(note);
            if (offsetNote.getVelocity() != 120)
                throw std::runtime_error("Velocity offset failed");

            // Test velocity curve
            transform.setVelocityOffset(0);
            transform.setVelocityCurve(2.0f);  // Quadratic curve

            auto softNote = juce::MidiMessage::noteOn(1, 60, (juce::uint8)64);  // Half velocity
            auto curvedNote = transform.transform(softNote);

            // With curve=2.0, half velocity (0.5) should become 0.25 * 127 ≈ 32
            if (curvedNote.getVelocity() > 40)
                throw std::runtime_error("Velocity curve not applied correctly");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testMIDIChannelRemap()
    {
        TestResult result { "MIDI Channel Remapping" };
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            MIDITransform transform;

            // Remap channel 1 to channel 10
            transform.setChannelRemap(1, 10);

            auto noteCh1 = juce::MidiMessage::noteOn(1, 60, (juce::uint8)100);
            auto remapped = transform.transform(noteCh1);

            if (remapped.getChannel() != 10)
                throw std::runtime_error("Channel remap failed");

            // Test all channels to one
            transform.setAllChannelsTo(5);

            auto noteCh3 = juce::MidiMessage::noteOn(3, 60, (juce::uint8)100);
            auto noteCh8 = juce::MidiMessage::noteOn(8, 60, (juce::uint8)100);

            if (transform.transform(noteCh3).getChannel() != 5)
                throw std::runtime_error("All channels to 5 failed for ch3");

            if (transform.transform(noteCh8).getChannel() != 5)
                throw std::runtime_error("All channels to 5 failed for ch8");

            // Reset and verify
            transform.resetChannelMap();
            auto restored = transform.transform(noteCh3);
            if (restored.getChannel() != 3)
                throw std::runtime_error("Channel map reset failed");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testMIDICCRemap()
    {
        TestResult result { "MIDI CC Remapping" };
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            MIDITransform transform;

            // Remap CC1 (mod wheel) to CC11 (expression)
            transform.setCCRemap(1, 11);

            auto modWheel = juce::MidiMessage::controllerEvent(1, 1, 64);
            auto remapped = transform.transform(modWheel);

            if (remapped.getControllerNumber() != 11)
                throw std::runtime_error("CC remap failed");

            // Verify value preserved
            if (remapped.getControllerValue() != 64)
                throw std::runtime_error("CC value not preserved");

            // Reset and verify
            transform.resetCCMap();
            auto restored = transform.transform(modWheel);
            if (restored.getControllerNumber() != 1)
                throw std::runtime_error("CC map reset failed");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testVirtualMIDIPorts()
    {
        TestResult result { "Virtual MIDI Ports" };
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            MIDIRoutingMatrix router;
            router.prepare(48000.0, 512);

            // Default virtual ports should exist
            if (router.getNumVirtualPorts() < 2)
                throw std::runtime_error("Default virtual ports not created");

            // Create additional virtual port
            int portIdx = router.createVirtualPort("Arpeggiator Bus");
            if (portIdx < 0)
                throw std::runtime_error("Failed to create virtual port");

            auto* port = router.getVirtualPort(portIdx);
            if (!port || port->getName() != "Arpeggiator Bus")
                throw std::runtime_error("Virtual port name mismatch");

            // Test port buffering
            port->prepare(512);
            auto testNote = juce::MidiMessage::noteOn(1, 60, (juce::uint8)100);
            port->addEvent(testNote, 0);

            if (port->getBuffer().isEmpty())
                throw std::runtime_error("Virtual port buffer empty");

            port->clear();
            if (!port->getBuffer().isEmpty())
                throw std::runtime_error("Virtual port not cleared");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testMIDIRouteProcessing()
    {
        TestResult result { "MIDI Route Processing" };
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            MIDIRoutingMatrix router;
            router.prepare(48000.0, 512);

            // Register hardware
            router.registerHardwareInput("Test Input", "test-in");

            // Create route to track
            MIDIEndpoint src = router.getHardwareInputs()[0];
            MIDIEndpoint dst = router.getTrackInputEndpoint(0);
            router.createRoute(src, dst);

            // Process MIDI
            juce::MidiBuffer inputBuffer;
            inputBuffer.addEvent(juce::MidiMessage::noteOn(1, 60, (juce::uint8)100), 0);
            inputBuffer.addEvent(juce::MidiMessage::controllerEvent(1, 1, 64), 100);
            inputBuffer.addEvent(juce::MidiMessage::noteOff(1, 60), 200);

            router.beginBlock();
            router.routeFromSource(src, inputBuffer, 512);

            // Check track received messages
            auto& trackInput = router.getTrackInputMessages(0);
            if (trackInput.isEmpty())
                throw std::runtime_error("Track did not receive MIDI");

            int messageCount = 0;
            for (const auto metadata : trackInput)
            {
                (void)metadata;
                messageCount++;
            }

            if (messageCount != 3)
                throw std::runtime_error("Expected 3 messages, got " + std::to_string(messageCount));

            router.endBlock();

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testMIDILearn()
    {
        TestResult result { "MIDI Learn" };
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            MIDIRoutingMatrix router;
            router.prepare(48000.0, 512);

            int learnedChannel = 0;
            int learnedCC = 0;
            int learnedValue = 0;

            // Start learning
            router.getLearnManager().startLearning("Volume", [&](int ch, int cc, int val)
            {
                learnedChannel = ch;
                learnedCC = cc;
                learnedValue = val;
            });

            if (!router.getLearnManager().isLearning())
                throw std::runtime_error("Learn mode not started");

            // Send a CC message
            auto ccMsg = juce::MidiMessage::controllerEvent(3, 7, 100);
            router.getLearnManager().processMessage(ccMsg);

            if (router.getLearnManager().isLearning())
                throw std::runtime_error("Learn mode should have stopped");

            if (learnedChannel != 3 || learnedCC != 7 || learnedValue != 100)
                throw std::runtime_error("Wrong MIDI parameters learned");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testMIDIStatePeristence()
    {
        TestResult result { "MIDI State Persistence" };
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            MIDIRoutingMatrix router;
            router.prepare(48000.0, 512);

            // Configure routing
            router.registerHardwareInput("Keyboard", "kbd-1");
            router.createVirtualPort("Test Port");

            MIDIEndpoint src = router.getHardwareInputs()[0];
            MIDIEndpoint dst = router.getTrackInputEndpoint(0);
            int routeIdx = router.createRoute(src, dst);

            auto* route = router.getRoute(routeIdx);
            route->getTransform().setTranspose(5);
            route->getFilter().setChannelMask(0x000F);  // Channels 1-4

            // Save state
            juce::var state = router.getState();

            // Create new router and restore
            MIDIRoutingMatrix router2;
            router2.prepare(48000.0, 512);
            router2.restoreState(state);

            // Verify
            if (router2.getNumVirtualPorts() < 3)  // 2 default + 1 created
                throw std::runtime_error("Virtual ports not restored");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    //==========================================================================
    // Integration Tests
    //==========================================================================

    TestResult testMultiTrackRouting()
    {
        TestResult result { "Multi-Track Routing" };
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            AudioRoutingManager audioRouter;
            audioRouter.prepare(48000.0, 512);

            MIDIRoutingMatrix midiRouter;
            midiRouter.prepare(48000.0, 512);

            const int numTracks = 8;
            const int numSamples = 512;

            // Create group bus for drums
            int drumsGroup = audioRouter.createGroupBus("Drums");

            // Create reverb send
            int reverbSend = audioRouter.createSendBus("Reverb");

            // Configure tracks
            for (int i = 0; i < numTracks; ++i)
            {
                // Route tracks 0-3 to drums group
                if (i < 4)
                    audioRouter.routeTrackToGroup(i, drumsGroup);

                // Add reverb send to all tracks
                audioRouter.setTrackSend(i, reverbSend, 0.3f);
            }

            // Process audio block
            audioRouter.beginBlock(numSamples);

            for (int i = 0; i < numTracks; ++i)
            {
                juce::AudioBuffer<float> trackBuffer(2, numSamples);
                trackBuffer.clear();
                for (int ch = 0; ch < 2; ++ch)
                    for (int s = 0; s < numSamples; ++s)
                        trackBuffer.setSample(ch, s, 0.1f);

                audioRouter.routeTrackAudio(i, trackBuffer, numSamples, 0.8f, 0.0f);
            }

            audioRouter.endBlock(numSamples);

            // Verify master has audio
            float masterPeak = audioRouter.getMasterBus().getBuffer().getMagnitude(0, numSamples);
            if (masterPeak <= 0.0f)
                throw std::runtime_error("No audio in master after multi-track routing");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }

    TestResult testComplexRoutingScenario()
    {
        TestResult result { "Complex Routing Scenario" };
        auto start = juce::Time::getMillisecondCounterHiRes();

        try
        {
            AudioRoutingManager audioRouter;
            audioRouter.prepare(48000.0, 512);

            // Create hierarchical bus structure:
            // Track 0 → Drums Group → Master
            // Track 1 → Drums Group → Master
            // Track 2 → Synths Group → Master
            // Track 3 → Synths Group → Master
            // All tracks → Reverb Send → Master
            // Track 0 → Sidechain → (available for compression)

            int drumsGroup = audioRouter.createGroupBus("Drums");
            int synthsGroup = audioRouter.createGroupBus("Synths");
            int reverbSend = audioRouter.createSendBus("Plate Reverb");
            int delaySend = audioRouter.createSendBus("Stereo Delay");

            // Route tracks to groups
            audioRouter.routeTrackToGroup(0, drumsGroup);
            audioRouter.routeTrackToGroup(1, drumsGroup);
            audioRouter.routeTrackToGroup(2, synthsGroup);
            audioRouter.routeTrackToGroup(3, synthsGroup);

            // Add sends
            audioRouter.setTrackSend(0, reverbSend, 0.1f);  // Kick: little reverb
            audioRouter.setTrackSend(1, reverbSend, 0.3f);  // Snare: more reverb
            audioRouter.setTrackSend(2, reverbSend, 0.5f);  // Synth: lots of reverb
            audioRouter.setTrackSend(2, delaySend, 0.4f);   // Synth: delay too
            audioRouter.setTrackSend(3, reverbSend, 0.4f);

            // Create sidechain from kick
            audioRouter.createSidechainSource(0);

            // Verify structure
            auto* drums = audioRouter.getGroupBus(drumsGroup);
            if (drums->getTracks().size() != 2)
                throw std::runtime_error("Drums group should have 2 tracks");

            auto* synths = audioRouter.getGroupBus(synthsGroup);
            if (synths->getTracks().size() != 2)
                throw std::runtime_error("Synths group should have 2 tracks");

            auto& track2Routing = audioRouter.getTrackRouting(2);
            if (track2Routing.sends.size() != 2)
                throw std::runtime_error("Track 2 should have 2 sends");

            if (!audioRouter.getSidechainSource(0))
                throw std::runtime_error("Sidechain source not created");

            result.passed = true;
        }
        catch (const std::exception& e)
        {
            result.message = e.what();
        }

        result.durationMs = juce::Time::getMillisecondCounterHiRes() - start;
        return result;
    }
};

//==============================================================================
// Quick Test Entry Point
//==============================================================================

inline bool runRoutingTestsQuick()
{
    RoutingTests tests;
    auto results = tests.runAllTests();
    tests.printResults(results);

    for (const auto& r : results)
    {
        if (!r.passed)
            return false;
    }
    return true;
}

} // namespace Tests
} // namespace Echoelmusic
