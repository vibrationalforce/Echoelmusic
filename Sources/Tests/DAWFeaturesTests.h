/*
  ==============================================================================

    DAWFeaturesTests.h
    Created: 2026
    Author:  Echoelmusic

    Tests for DAW Features:
    - Crossfade Editor
    - VCA Fader System
    - Track Templates
    - Cue List Manager
    - Control Surface Profiles
    - Automation Lanes
    - Clip Editor

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include "../Audio/CrossfadeEditor.h"
#include "../Mixer/VCAFaderSystem.h"
#include "../Project/TrackTemplates.h"
#include "../Arrangement/CueListManager.h"
#include "../Hardware/ControlSurfaceProfiles.h"
#include "../Automation/AutomationLanes.h"
#include "../Editing/ClipEditor.h"

namespace Echoelmusic {
namespace Tests {

//==============================================================================
/** Crossfade Editor Tests */
class CrossfadeEditorTests : public juce::UnitTest {
public:
    CrossfadeEditorTests() : juce::UnitTest("Crossfade Editor Tests") {}

    void runTest() override {
        beginTest("FadeCurve linear");
        {
            Audio::FadeCurve curve(Audio::FadeCurveType::Linear);
            expectWithinAbsoluteError(curve.calculateGain(0.0f, true), 0.0f, 0.01f);
            expectWithinAbsoluteError(curve.calculateGain(0.5f, true), 0.5f, 0.01f);
            expectWithinAbsoluteError(curve.calculateGain(1.0f, true), 1.0f, 0.01f);
        }

        beginTest("FadeCurve equal power");
        {
            Audio::FadeCurve curve(Audio::FadeCurveType::EqualPower);
            float midGain = curve.calculateGain(0.5f, true);
            expectWithinAbsoluteError(midGain, 0.707f, 0.01f);
        }

        beginTest("FadeCurve S-curve");
        {
            Audio::FadeCurve curve(Audio::FadeCurveType::SCurve);
            float startGain = curve.calculateGain(0.0f, true);
            float midGain = curve.calculateGain(0.5f, true);
            float endGain = curve.calculateGain(1.0f, true);

            expectWithinAbsoluteError(startGain, 0.0f, 0.01f);
            expectWithinAbsoluteError(midGain, 0.5f, 0.01f);
            expectWithinAbsoluteError(endGain, 1.0f, 0.01f);
        }

        beginTest("Crossfade creation");
        {
            Audio::Crossfade xfade;
            xfade.crossfadeTime = 5.0;
            xfade.length = 1.0;

            expectWithinAbsoluteError(xfade.getStartTime(), 4.5, 0.001);
            expectWithinAbsoluteError(xfade.getEndTime(), 5.5, 0.001);
        }

        beginTest("Crossfade gain calculation");
        {
            Audio::Crossfade xfade;
            xfade.crossfadeTime = 5.0;
            xfade.length = 2.0;

            float outGainBefore = xfade.getOutgoingGain(3.5);
            float outGainMid = xfade.getOutgoingGain(5.0);
            float outGainAfter = xfade.getOutgoingGain(6.5);

            expectWithinAbsoluteError(outGainBefore, 1.0f, 0.01f);
            expect(outGainMid < 1.0f && outGainMid > 0.0f);
            expectWithinAbsoluteError(outGainAfter, 0.0f, 0.01f);
        }

        beginTest("Crossfade manager");
        {
            Audio::CrossfadeManager manager;

            auto* xfade = manager.createCrossfade("clip1", "clip2", 5.0, 0.5);
            expect(xfade != nullptr);

            auto* found = manager.findCrossfadeBetween("clip1", "clip2");
            expect(found == xfade);

            auto presets = manager.getPresets();
            expect(presets.size() > 0);
        }
    }
};

//==============================================================================
/** VCA Fader System Tests */
class VCAFaderTests : public juce::UnitTest {
public:
    VCAFaderTests() : juce::UnitTest("VCA Fader Tests") {}

    void runTest() override {
        beginTest("VCA fader creation");
        {
            Mixer::VCAFader vca("Main VCA");
            expect(vca.getName() == "Main VCA");
            expectWithinAbsoluteError(vca.getLevel(), 1.0f, 0.001f);
        }

        beginTest("VCA level control");
        {
            Mixer::VCAFader vca("Test");
            vca.setLevel(0.5f);
            expectWithinAbsoluteError(vca.getLevel(), 0.5f, 0.001f);

            vca.setLevelDB(-6.0f);
            expectWithinAbsoluteError(vca.getLevelDB(), -6.0f, 0.1f);
        }

        beginTest("VCA slave management");
        {
            Mixer::VCAFader vca("Test");

            vca.addSlave("track1");
            vca.addSlave("track2");
            vca.addSlave("track3");

            expect(vca.hasSlave("track1"));
            expect(vca.hasSlave("track2"));
            expect(vca.getSlaveIds().size() == 3);

            vca.removeSlave("track2");
            expect(!vca.hasSlave("track2"));
            expect(vca.getSlaveIds().size() == 2);
        }

        beginTest("VCA gain calculation - Trim mode");
        {
            Mixer::VCAFader vca("Test");
            vca.setMode(Mixer::VCAMode::Trim);
            vca.addSlave("track1");
            vca.setLevel(0.5f);

            float effectiveGain = vca.calculateSlaveGain("track1", 0.8f);
            expectWithinAbsoluteError(effectiveGain, 0.4f, 0.01f);
        }

        beginTest("VCA mute");
        {
            Mixer::VCAFader vca("Test");
            vca.addSlave("track1");
            vca.setMuted(true);

            float effectiveGain = vca.calculateSlaveGain("track1", 1.0f);
            expectWithinAbsoluteError(effectiveGain, 0.0f, 0.001f);
        }

        beginTest("VCA manager");
        {
            Mixer::VCAFaderManager manager;

            auto* vca1 = manager.createVCA("Drums");
            auto* vca2 = manager.createVCA("Vocals");

            expect(vca1 != nullptr);
            expect(vca2 != nullptr);

            manager.assignTrackToVCA("kick", vca1->getId());
            manager.assignTrackToVCA("snare", vca1->getId());

            expect(manager.getVCAForTrack("kick") == vca1);

            vca1->setLevel(0.7f);
            float effective = manager.getEffectiveTrackLevel("kick", 1.0f);
            expectWithinAbsoluteError(effective, 0.7f, 0.01f);
        }
    }
};

//==============================================================================
/** Track Templates Tests */
class TrackTemplatesTests : public juce::UnitTest {
public:
    TrackTemplatesTests() : juce::UnitTest("Track Templates Tests") {}

    void runTest() override {
        beginTest("Template creation");
        {
            Project::TrackTemplate tmpl("Vocal Track");
            expect(tmpl.getName() == "Vocal Track");
            expect(tmpl.getType() == Project::TrackType::Audio);
        }

        beginTest("Template settings");
        {
            Project::TrackTemplate tmpl("Test");
            tmpl.setType(Project::TrackType::Instrument);
            tmpl.setCategory("Production");
            tmpl.setDefaultVolume(0.8f);
            tmpl.setDefaultPan(-0.5f);
            tmpl.setRecordEnabled(true);

            expect(tmpl.getType() == Project::TrackType::Instrument);
            expect(tmpl.getCategory() == "Production");
            expectWithinAbsoluteError(tmpl.getDefaultVolume(), 0.8f, 0.01f);
            expectWithinAbsoluteError(tmpl.getDefaultPan(), -0.5f, 0.01f);
            expect(tmpl.isRecordEnabled());
        }

        beginTest("Template plugins");
        {
            Project::TrackTemplate tmpl("Test");

            Project::TemplatePluginSlot comp;
            comp.pluginName = "Compressor";
            comp.slotIndex = 0;
            tmpl.addPlugin(comp);

            Project::TemplatePluginSlot eq;
            eq.pluginName = "EQ";
            eq.slotIndex = 1;
            tmpl.addPlugin(eq);

            expect(tmpl.getPlugins().size() == 2);
            expect(tmpl.getPlugins()[0].pluginName == "Compressor");
        }

        beginTest("Template sends");
        {
            Project::TrackTemplate tmpl("Test");

            Project::TemplateSend send;
            send.destinationName = "Reverb";
            send.level = 0.5f;
            send.preFader = false;
            tmpl.addSend(send);

            expect(tmpl.getSends().size() == 1);
            expect(tmpl.getSends()[0].destinationName == "Reverb");
        }

        beginTest("Template serialization");
        {
            Project::TrackTemplate original("Test Template");
            original.setCategory("Recording");
            original.setDefaultVolume(0.75f);

            auto json = original.toVar();
            auto restored = Project::TrackTemplate::fromVar(json);

            expect(restored->getName() == "Test Template");
            expect(restored->getCategory() == "Recording");
            expectWithinAbsoluteError(restored->getDefaultVolume(), 0.75f, 0.01f);
        }

        beginTest("Template manager");
        {
            Project::TrackTemplateManager manager;

            auto templates = manager.getAllTemplates();
            expect(templates.size() > 0);  // Should have built-in templates

            auto* vocal = manager.getTemplateByName("Vocal Recording");
            expect(vocal != nullptr);
        }
    }
};

//==============================================================================
/** Cue List Manager Tests */
class CueListTests : public juce::UnitTest {
public:
    CueListTests() : juce::UnitTest("Cue List Tests") {}

    void runTest() override {
        beginTest("Cue point creation");
        {
            Arrangement::CuePoint cue(5.0, "Verse 1");
            expect(cue.getName() == "Verse 1");
            expectWithinAbsoluteError(cue.getTime(), 5.0, 0.001);
        }

        beginTest("Cue point time display");
        {
            Arrangement::CuePoint cue(65.5, "Test");
            cue.setUseBarsBeatsTicks(false);

            juce::String timeStr = cue.getTimeString();
            expect(timeStr.isNotEmpty());
        }

        beginTest("Cue list");
        {
            Arrangement::CueList list("Main");

            auto* cue1 = list.addCue(0.0, "Intro");
            auto* cue2 = list.addCue(8.0, "Verse");
            auto* cue3 = list.addCue(16.0, "Chorus");

            expect(list.getNumCues() == 3);

            auto* found = list.getCueAtOrBefore(10.0);
            expect(found == cue2);

            auto* next = list.getCueAfter(5.0);
            expect(next == cue2);
        }

        beginTest("Cue types");
        {
            Arrangement::CuePoint cue(0.0);
            cue.setType(Arrangement::CueType::LoopStart);
            cue.setEndTime(8.0);

            expect(cue.isRegion());
            expectWithinAbsoluteError(cue.getDuration(), 8.0, 0.001);
        }

        beginTest("Cue list manager");
        {
            Arrangement::CueListManager manager;

            auto* marker = manager.addMarker(10.0, "Drop");
            expect(marker != nullptr);
            expect(marker->getType() == Arrangement::CueType::Marker);

            auto* memory = manager.addMemoryLocation(20.0, "Bridge", 1);
            expect(memory != nullptr);
            expect(memory->getNumber() == 1);

            auto [loopStart, loopEnd] = manager.createLoopRegion(0.0, 8.0, "Main Loop");
            expect(loopStart != nullptr);
            expect(loopEnd != nullptr);
        }

        beginTest("Cue export");
        {
            Arrangement::CueListManager manager;
            manager.addMarker(0.0, "Start");
            manager.addMarker(60.0, "Middle");
            manager.addMarker(120.0, "End");

            juce::String csv = manager.exportToCSV();
            expect(csv.contains("Start"));
            expect(csv.contains("Middle"));
        }
    }
};

//==============================================================================
/** Control Surface Tests */
class ControlSurfaceTests : public juce::UnitTest {
public:
    ControlSurfaceTests() : juce::UnitTest("Control Surface Tests") {}

    void runTest() override {
        beginTest("Control mapping creation");
        {
            Hardware::ControlMapping mapping;
            mapping.setName("Fader 1");
            mapping.setMIDI(1, 7);
            mapping.setControlType(Hardware::ControlType::Fader);
            mapping.setRange(0.0f, 1.0f);

            expect(mapping.getMIDIChannel() == 1);
            expect(mapping.getMIDINumber() == 7);
            expect(mapping.getControlType() == Hardware::ControlType::Fader);
        }

        beginTest("Control value scaling");
        {
            Hardware::ControlMapping mapping;
            mapping.setRange(0.0f, 100.0f);

            float scaledValue = mapping.scaleValue(64);
            expectWithinAbsoluteError(scaledValue, 50.0f, 1.0f);

            int midiValue = mapping.scaleToMIDI(75.0f);
            expect(midiValue >= 90 && midiValue <= 100);
        }

        beginTest("Control surface profile");
        {
            Hardware::ControlSurfaceProfile profile("My Controller");
            profile.setManufacturer("Generic");
            profile.setDeviceName("MIDI Controller");

            auto* mapping = profile.addMapping();
            mapping->setName("Volume");
            mapping->setMIDI(1, 7);

            expect(profile.getAllMappings().size() == 1);

            auto* found = profile.findMapping(1, 7, Hardware::MIDIMessageType::ControlChange);
            expect(found == mapping);
        }

        beginTest("Control surface manager");
        {
            Hardware::ControlSurfaceManager manager;

            auto profiles = manager.getAllProfiles();
            expect(profiles.size() > 0);  // Built-in profiles

            auto* newProfile = manager.createProfile("Test Profile");
            expect(newProfile != nullptr);

            manager.setActiveProfile(newProfile->getId());
            expect(manager.getActiveProfile() == newProfile);
        }

        beginTest("MIDI learn mode");
        {
            Hardware::ControlSurfaceManager manager;
            auto* profile = manager.createProfile("Test");
            auto* mapping = profile->addMapping();

            manager.setActiveProfile(profile->getId());
            manager.startMIDILearn(mapping);

            expect(manager.isLearning());

            manager.stopMIDILearn();
            expect(!manager.isLearning());
        }
    }
};

//==============================================================================
/** Automation Lane Tests */
class AutomationLaneTests : public juce::UnitTest {
public:
    AutomationLaneTests() : juce::UnitTest("Automation Lane Tests") {}

    void runTest() override {
        beginTest("Automation point");
        {
            Automation::AutomationPoint point;
            point.time = 1.0;
            point.value = 0.75f;
            point.curveToNext = Automation::CurveShape::Linear;

            expectWithinAbsoluteError(point.time, 1.0, 0.001);
            expectWithinAbsoluteError(point.value, 0.75f, 0.01f);
        }

        beginTest("Automation lane creation");
        {
            Automation::AutomationLane lane("Volume");
            expect(lane.getParameterName() == "Volume");
            expect(lane.getNumPoints() == 0);
        }

        beginTest("Automation interpolation - linear");
        {
            Automation::AutomationLane lane("Test");
            lane.addPoint(0.0, 0.0f, Automation::CurveShape::Linear);
            lane.addPoint(1.0, 1.0f, Automation::CurveShape::Linear);

            float valueAtMid = lane.getValueAt(0.5);
            expectWithinAbsoluteError(valueAtMid, 0.5f, 0.01f);
        }

        beginTest("Automation interpolation - S-curve");
        {
            Automation::AutomationLane lane("Test");
            lane.addPoint(0.0, 0.0f, Automation::CurveShape::SCurve);
            lane.addPoint(1.0, 1.0f, Automation::CurveShape::Linear);

            float valueAtMid = lane.getValueAt(0.5);
            expectWithinAbsoluteError(valueAtMid, 0.5f, 0.01f);
        }

        beginTest("Automation range normalization");
        {
            Automation::AutomationLane lane("Frequency");
            lane.setRange(20.0f, 20000.0f);

            float denorm = lane.denormalize(0.5f);
            expectWithinAbsoluteError(denorm, 10010.0f, 1.0f);

            float norm = lane.normalize(10010.0f);
            expectWithinAbsoluteError(norm, 0.5f, 0.01f);
        }

        beginTest("Automation editing");
        {
            Automation::AutomationLane lane("Test");
            lane.addPoint(0.0, 0.0f);
            lane.addPoint(1.0, 0.5f);
            lane.addPoint(2.0, 1.0f);

            lane.selectPointsInRange(0.5, 1.5);

            // Middle point should be selected
            auto& points = lane.getPoints();
            expect(!points[0].isSelected);
            expect(points[1].isSelected);
            expect(!points[2].isSelected);
        }

        beginTest("Automation copy/paste");
        {
            Automation::AutomationLane lane("Test");
            lane.addPoint(0.0, 0.0f);
            lane.addPoint(1.0, 1.0f);

            auto region = lane.copyRegion(0.0, 1.0);
            expect(region.points.size() == 2);

            lane.pasteRegion(region, 2.0);
            expect(lane.getNumPoints() == 4);
        }

        beginTest("Track automation");
        {
            Automation::TrackAutomation trackAuto("track1");

            auto* volumeLane = trackAuto.addLane("Volume");
            auto* panLane = trackAuto.addLane("Pan");

            expect(trackAuto.getAllLanes().size() == 2);
            expect(trackAuto.getLaneByParameter("Volume") == volumeLane);
        }
    }
};

//==============================================================================
/** Clip Editor Tests */
class ClipEditorTests : public juce::UnitTest {
public:
    ClipEditorTests() : juce::UnitTest("Clip Editor Tests") {}

    void runTest() override {
        beginTest("Audio clip creation");
        {
            Editing::AudioClip clip("Test Clip");
            expect(clip.getName() == "Test Clip");
            expectWithinAbsoluteError(clip.getStartTime(), 0.0, 0.001);
        }

        beginTest("Audio clip position");
        {
            Editing::AudioClip clip("Test");
            clip.setStartTime(5.0);
            clip.setDuration(10.0);

            expectWithinAbsoluteError(clip.getStartTime(), 5.0, 0.001);
            expectWithinAbsoluteError(clip.getEndTime(), 15.0, 0.001);
            expectWithinAbsoluteError(clip.getDuration(), 10.0, 0.001);
        }

        beginTest("Audio clip gain");
        {
            Editing::AudioClip clip("Test");
            clip.setGain(0.5f);
            expectWithinAbsoluteError(clip.getGain(), 0.5f, 0.01f);

            clip.setGainDB(-6.0f);
            expectWithinAbsoluteError(clip.getGainDB(), -6.0f, 0.1f);
        }

        beginTest("Audio clip fades");
        {
            Editing::AudioClip clip("Test");
            clip.setDuration(10.0);
            clip.setFadeInLength(1.0);
            clip.setFadeOutLength(2.0);

            expectWithinAbsoluteError(clip.getFadeInLength(), 1.0, 0.001);
            expectWithinAbsoluteError(clip.getFadeOutLength(), 2.0, 0.001);
        }

        beginTest("Clip editor tools");
        {
            Editing::ClipEditor editor;

            editor.setActiveTool(Editing::EditTool::Split);
            expect(editor.getActiveTool() == Editing::EditTool::Split);

            editor.setSnapMode(Editing::SnapMode::Grid);
            editor.setSnapValue(0.5);

            double snapped = editor.snapTime(1.3);
            expectWithinAbsoluteError(snapped, 1.5, 0.001);
        }

        beginTest("Clip editor split");
        {
            Editing::ClipEditor editor;

            auto clip = std::make_unique<Editing::AudioClip>("Original");
            clip->setStartTime(0.0);
            clip->setDuration(10.0);
            juce::String clipId = clip->getId();
            editor.addClip(std::move(clip));

            auto [left, right] = editor.splitClip(clipId, 5.0);

            expect(left != nullptr);
            expect(right != nullptr);
            expectWithinAbsoluteError(left->getDuration(), 5.0, 0.001);
            expectWithinAbsoluteError(right->getStartTime(), 5.0, 0.001);
        }

        beginTest("Clip editor move");
        {
            Editing::ClipEditor editor;
            editor.setSnapMode(Editing::SnapMode::Off);

            auto clip = std::make_unique<Editing::AudioClip>("Test");
            clip->setStartTime(0.0);
            juce::String clipId = clip->getId();
            editor.addClip(std::move(clip));

            editor.moveClip(clipId, 5.0);

            auto* movedClip = editor.getClip(clipId);
            expectWithinAbsoluteError(movedClip->getStartTime(), 5.0, 0.001);
        }

        beginTest("Clip editor selection");
        {
            Editing::ClipEditor editor;

            auto clip1 = std::make_unique<Editing::AudioClip>("Clip 1");
            clip1->setStartTime(0.0);
            clip1->setDuration(5.0);
            juce::String id1 = clip1->getId();
            editor.addClip(std::move(clip1));

            auto clip2 = std::make_unique<Editing::AudioClip>("Clip 2");
            clip2->setStartTime(10.0);
            clip2->setDuration(5.0);
            juce::String id2 = clip2->getId();
            editor.addClip(std::move(clip2));

            editor.selectClipsInRange(0.0, 6.0);
            auto selected = editor.getSelectedClips();
            expect(selected.size() == 1);
            expect(selected[0]->getId() == id1);
        }

        beginTest("Clip editor undo");
        {
            Editing::ClipEditor editor;
            editor.setSnapMode(Editing::SnapMode::Off);

            auto clip = std::make_unique<Editing::AudioClip>("Test");
            clip->setStartTime(0.0);
            juce::String clipId = clip->getId();
            editor.addClip(std::move(clip));

            editor.moveClip(clipId, 5.0);
            expect(editor.canUndo());

            editor.undo();
            auto* restoredClip = editor.getClip(clipId);
            expectWithinAbsoluteError(restoredClip->getStartTime(), 0.0, 0.001);
        }
    }
};

//==============================================================================
/** Run all DAW feature tests */
class DAWFeaturesTestRunner {
public:
    static void runAllTests() {
        juce::UnitTestRunner runner;
        runner.setAssertOnFailure(false);

        runner.runTests({
            new CrossfadeEditorTests(),
            new VCAFaderTests(),
            new TrackTemplatesTests(),
            new CueListTests(),
            new ControlSurfaceTests(),
            new AutomationLaneTests(),
            new ClipEditorTests()
        });

        int numTests = runner.getNumResults();
        int numPassed = 0;

        for (int i = 0; i < numTests; ++i) {
            if (runner.getResult(i)->failures == 0) {
                numPassed++;
            }
        }

        DBG("=== DAW Features Test Results ===");
        DBG("Tests run: " + juce::String(numTests));
        DBG("Tests passed: " + juce::String(numPassed));
        DBG("Tests failed: " + juce::String(numTests - numPassed));
    }
};

} // namespace Tests
} // namespace Echoelmusic
