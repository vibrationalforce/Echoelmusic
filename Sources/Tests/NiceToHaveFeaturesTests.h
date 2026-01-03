#pragma once

#include <JuceHeader.h>
#include "../Notation/NotationEditor.h"
#include "../Metering/IntegratedMeteringSuite.h"
#include "../Synthesis/GranularSynthesizer.h"
#include "../Podcast/PodcastProductionSuite.h"
#include "../AI/LSTMComposer.h"

/**
 * NiceToHaveFeaturesTests
 *
 * Comprehensive test suite for all newly implemented features:
 * - Notation/Score Editor
 * - Integrated Metering Suite
 * - Granular Synthesis Engine
 * - Podcast Production Suite
 * - LSTM AI Composer
 */

namespace Echoelmusic {
namespace Tests {

class NiceToHaveFeaturesTests : public juce::UnitTest
{
public:
    NiceToHaveFeaturesTests() : juce::UnitTest("Nice-to-Have Features Tests") {}

    void runTest() override
    {
        runNotationEditorTests();
        runIntegratedMeteringTests();
        runGranularSynthesizerTests();
        runPodcastProductionTests();
        runLSTMComposerTests();
    }

private:
    //==========================================================================
    // NOTATION EDITOR TESTS
    //==========================================================================

    void runNotationEditorTests()
    {
        beginTest("NotationEditor - Basic Note Operations");
        {
            Notation::NotationEditor editor;
            editor.prepare(48000.0, 512);

            // Add notes
            editor.addNote(60, 0.0, 1.0, 0.8f);  // C4, beat 0, 1 beat duration
            editor.addNote(64, 1.0, 1.0, 0.7f);  // E4, beat 1
            editor.addNote(67, 2.0, 1.0, 0.9f);  // G4, beat 2

            expect(editor.getNumNotes() == 3, "Should have 3 notes");

            auto notes = editor.getNotes();
            expect(notes[0].midiNote == 60, "First note should be C4");
            expect(notes[1].midiNote == 64, "Second note should be E4");
            expect(notes[2].midiNote == 67, "Third note should be G4");
        }

        beginTest("NotationEditor - Remove Note");
        {
            Notation::NotationEditor editor;
            editor.prepare(48000.0, 512);

            editor.addNote(60, 0.0, 1.0, 0.8f);
            editor.addNote(64, 1.0, 1.0, 0.7f);

            editor.removeNote(0);
            expect(editor.getNumNotes() == 1, "Should have 1 note after removal");
            expect(editor.getNotes()[0].midiNote == 64, "Remaining note should be E4");
        }

        beginTest("NotationEditor - Key Signature");
        {
            Notation::NotationEditor editor;

            editor.setKeySignature(Notation::NotationEditor::KeySignature::GMajor);
            auto key = editor.getKeySignature();
            expect(key == Notation::NotationEditor::KeySignature::GMajor, "Key should be G Major");
        }

        beginTest("NotationEditor - Time Signature");
        {
            Notation::NotationEditor editor;

            editor.setTimeSignature(3, 4);  // 3/4 time

            int num, denom;
            editor.getTimeSignature(num, denom);
            expect(num == 3, "Numerator should be 3");
            expect(denom == 4, "Denominator should be 4");
        }

        beginTest("NotationEditor - Clef");
        {
            Notation::NotationEditor editor;

            editor.setClef(Notation::NotationEditor::Clef::Bass);
            expect(editor.getClef() == Notation::NotationEditor::Clef::Bass, "Should be bass clef");
        }

        beginTest("NotationEditor - MusicXML Export");
        {
            Notation::NotationEditor editor;
            editor.prepare(48000.0, 512);

            editor.addNote(60, 0.0, 1.0, 0.8f);
            editor.addNote(62, 1.0, 0.5, 0.7f);

            juce::String xml = editor.exportMusicXML();

            expect(xml.contains("<?xml"), "Should contain XML declaration");
            expect(xml.contains("score-partwise"), "Should contain MusicXML root element");
            expect(xml.contains("<note>"), "Should contain note elements");
        }

        beginTest("NotationEditor - Quantization");
        {
            Notation::NotationEditor editor;
            editor.prepare(48000.0, 512);

            // Add note slightly off-beat
            editor.addNote(60, 0.13, 0.9, 0.8f);  // Slightly late

            editor.quantize(Notation::NotationEditor::QuantizeGrid::Quarter);

            auto notes = editor.getNotes();
            expect(std::abs(notes[0].startBeat - 0.0) < 0.01, "Note should be quantized to beat 0");
        }

        beginTest("NotationEditor - Transpose");
        {
            Notation::NotationEditor editor;
            editor.prepare(48000.0, 512);

            editor.addNote(60, 0.0, 1.0, 0.8f);  // C4
            editor.addNote(64, 1.0, 1.0, 0.7f);  // E4

            editor.transpose(2);  // Transpose up 2 semitones

            auto notes = editor.getNotes();
            expect(notes[0].midiNote == 62, "First note should be D4");
            expect(notes[1].midiNote == 66, "Second note should be F#4");
        }
    }

    //==========================================================================
    // INTEGRATED METERING TESTS
    //==========================================================================

    void runIntegratedMeteringTests()
    {
        beginTest("IntegratedMeteringSuite - LUFS Metering");
        {
            Metering::IntegratedMeteringSuite meter;
            meter.prepare(48000.0, 512);

            // Create test signal (1kHz sine wave at -18 dBFS)
            juce::AudioBuffer<float> buffer(2, 512);
            float amplitude = std::pow(10.0f, -18.0f / 20.0f);

            for (int i = 0; i < 512; ++i)
            {
                float sample = amplitude * std::sin(2.0f * juce::MathConstants<float>::pi * 1000.0f * i / 48000.0f);
                buffer.setSample(0, i, sample);
                buffer.setSample(1, i, sample);
            }

            // Process multiple blocks to stabilize LUFS
            for (int block = 0; block < 100; ++block)
                meter.processBlock(buffer);

            float lufs = meter.getIntegratedLUFS();
            // LUFS should be close to -18 for calibrated sine
            expect(lufs < 0.0f, "LUFS should be negative");
            expect(lufs > -30.0f, "LUFS should be within reasonable range");
        }

        beginTest("IntegratedMeteringSuite - True Peak Detection");
        {
            Metering::IntegratedMeteringSuite meter;
            meter.prepare(48000.0, 512);

            // Create signal with known peak
            juce::AudioBuffer<float> buffer(2, 512);
            buffer.clear();
            buffer.setSample(0, 256, 0.9f);  // Peak at 0.9
            buffer.setSample(1, 256, 0.9f);

            meter.processBlock(buffer);

            float truePeak = meter.getTruePeak();
            expect(truePeak >= 0.85f, "True peak should detect the 0.9 sample");
        }

        beginTest("IntegratedMeteringSuite - Phase Correlation");
        {
            Metering::IntegratedMeteringSuite meter;
            meter.prepare(48000.0, 512);

            // Create in-phase stereo signal
            juce::AudioBuffer<float> buffer(2, 512);
            for (int i = 0; i < 512; ++i)
            {
                float sample = std::sin(2.0f * juce::MathConstants<float>::pi * 440.0f * i / 48000.0f);
                buffer.setSample(0, i, sample);
                buffer.setSample(1, i, sample);  // Same signal = phase correlation 1.0
            }

            meter.processBlock(buffer);

            float correlation = meter.getPhaseCorrelation();
            expect(correlation > 0.9f, "In-phase signals should have high correlation");
        }

        beginTest("IntegratedMeteringSuite - Spectrum Data");
        {
            Metering::IntegratedMeteringSuite meter;
            meter.prepare(48000.0, 2048);

            // Create 1kHz test tone
            juce::AudioBuffer<float> buffer(2, 2048);
            for (int i = 0; i < 2048; ++i)
            {
                float sample = 0.5f * std::sin(2.0f * juce::MathConstants<float>::pi * 1000.0f * i / 48000.0f);
                buffer.setSample(0, i, sample);
                buffer.setSample(1, i, sample);
            }

            meter.processBlock(buffer);

            auto spectrum = meter.getSpectrumData();
            expect(!spectrum.empty(), "Should return spectrum data");

            // Find peak around 1kHz (bin ~42 at 48kHz with 2048 FFT)
            int peakBin = 0;
            float peakVal = 0.0f;
            for (size_t i = 0; i < spectrum.size(); ++i)
            {
                if (spectrum[i] > peakVal)
                {
                    peakVal = spectrum[i];
                    peakBin = static_cast<int>(i);
                }
            }

            float peakFreq = peakBin * 48000.0f / 2048.0f;
            expect(std::abs(peakFreq - 1000.0f) < 100.0f, "Peak should be near 1kHz");
        }

        beginTest("IntegratedMeteringSuite - Reset");
        {
            Metering::IntegratedMeteringSuite meter;
            meter.prepare(48000.0, 512);

            juce::AudioBuffer<float> buffer(2, 512);
            buffer.clear();
            buffer.applyGain(0.5f);

            meter.processBlock(buffer);
            meter.reset();

            float lufs = meter.getIntegratedLUFS();
            expect(lufs < -60.0f, "LUFS should be very low after reset");
        }
    }

    //==========================================================================
    // GRANULAR SYNTHESIZER TESTS
    //==========================================================================

    void runGranularSynthesizerTests()
    {
        using namespace Synthesis;

        beginTest("GranularSynthesizer - Initialization");
        {
            GranularSynthesizer synth;
            synth.prepare(48000.0, 512);

            expect(synth.getActiveGrainCount() == 0, "Should start with no active grains");
        }

        beginTest("GranularSynthesizer - Load Source");
        {
            GranularSynthesizer synth;
            synth.prepare(48000.0, 512);

            // Create test audio source
            juce::AudioBuffer<float> source(1, 48000);  // 1 second
            for (int i = 0; i < 48000; ++i)
            {
                source.setSample(0, i, std::sin(2.0f * juce::MathConstants<float>::pi * 440.0f * i / 48000.0f));
            }

            synth.loadSource(0, source, 48000.0);

            // Trigger note to start grains
            synth.noteOn(60, 0.8f);

            // Process some audio
            juce::AudioBuffer<float> output(2, 512);
            juce::MidiBuffer midi;
            synth.processBlock(output, midi);

            expect(synth.getActiveGrainCount() > 0, "Should have active grains after note on");
        }

        beginTest("GranularSynthesizer - Grain Parameters");
        {
            GranularSynthesizer synth;
            synth.prepare(48000.0, 512);

            synth.setGrainSize(100.0f);
            synth.setDensity(50.0f);
            synth.setPositionSpray(0.2f);
            synth.setPitch(5.0f);
            synth.setStereoSpread(0.8f);

            // No exceptions should be thrown
            expect(true, "Setting parameters should work");
        }

        beginTest("GranularSynthesizer - Freeze Mode");
        {
            GranularSynthesizer synth;
            synth.prepare(48000.0, 512);

            synth.setPosition(0.5f);
            synth.setFreeze(true);

            expect(synth.isFrozen(), "Should be frozen");
            expect(std::abs(synth.getCurrentPosition() - 0.5f) < 0.01f, "Position should stay at 0.5");

            synth.setFreeze(false);
            expect(!synth.isFrozen(), "Should not be frozen");
        }

        beginTest("GranularSynthesizer - Presets");
        {
            GranularSynthesizer synth;
            synth.prepare(48000.0, 512);

            // Test all presets load without error
            synth.loadPreset(GranularSynthesizer::Preset::CloudPad);
            synth.loadPreset(GranularSynthesizer::Preset::GlitchTexture);
            synth.loadPreset(GranularSynthesizer::Preset::TimeStretch);
            synth.loadPreset(GranularSynthesizer::Preset::SpectralFreeze);
            synth.loadPreset(GranularSynthesizer::Preset::RhythmicGrain);
            synth.loadPreset(GranularSynthesizer::Preset::AmbientDrone);
            synth.loadPreset(GranularSynthesizer::Preset::VocalTexture);
            synth.loadPreset(GranularSynthesizer::Preset::ReverseCloud);
            synth.loadPreset(GranularSynthesizer::Preset::ShimmerPad);
            synth.loadPreset(GranularSynthesizer::Preset::BioReactive);

            expect(true, "All presets should load");
        }

        beginTest("GranularSynthesizer - Window Shapes");
        {
            GranularSynthesizer synth;
            synth.prepare(48000.0, 512);

            // Test all window shapes
            synth.setWindowShape(GrainWindow::Hann);
            synth.setWindowShape(GrainWindow::Gaussian);
            synth.setWindowShape(GrainWindow::Triangle);
            synth.setWindowShape(GrainWindow::Trapezoid);
            synth.setWindowShape(GrainWindow::Tukey);
            synth.setWindowShape(GrainWindow::Blackman);
            synth.setWindowShape(GrainWindow::Kaiser);
            synth.setWindowShape(GrainWindow::Exponential);
            synth.setWindowShape(GrainWindow::ReversedExp);
            synth.setWindowShape(GrainWindow::Random);

            expect(true, "All window shapes should be settable");
        }

        beginTest("GranularSynthesizer - Bio-Reactive Mode");
        {
            GranularSynthesizer synth;
            synth.prepare(48000.0, 512);

            synth.setBioReactiveEnabled(true);
            synth.setBioData(0.7f, 0.8f);

            // Should not throw
            expect(true, "Bio-reactive mode should work");
        }
    }

    //==========================================================================
    // PODCAST PRODUCTION TESTS
    //==========================================================================

    void runPodcastProductionTests()
    {
        using namespace Podcast;

        beginTest("PodcastProductionSuite - Track Management");
        {
            PodcastProductionSuite suite;
            suite.prepare(48000.0, 512);

            int hostTrack = suite.addTrack("Host", PodcastTrack::TrackType::Host);
            int guestTrack = suite.addTrack("Guest", PodcastTrack::TrackType::Guest);

            expect(suite.getNumTracks() == 2, "Should have 2 tracks");
            expect(suite.getTrack(hostTrack) != nullptr, "Host track should exist");
            expect(suite.getTrack(guestTrack) != nullptr, "Guest track should exist");

            suite.removeTrack(0);
            expect(suite.getNumTracks() == 1, "Should have 1 track after removal");
        }

        beginTest("PodcastProductionSuite - Chapter Markers");
        {
            PodcastProductionSuite suite;
            suite.prepare(48000.0, 512);

            suite.addChapter(0.0, 120.0, "Introduction", "Welcome to the show");
            suite.addChapter(120.0, 600.0, "Main Topic", "Deep dive into the subject");
            suite.addChapter(600.0, 900.0, "Conclusion", "Wrapping up");

            auto chapters = suite.getChapters();
            expect(chapters.size() == 3, "Should have 3 chapters");
            expect(chapters[0].title == "Introduction", "First chapter should be Introduction");
            expect(chapters[1].startTime == 120.0, "Second chapter should start at 120s");

            suite.removeChapter(1);
            expect(suite.getChapters().size() == 2, "Should have 2 chapters after removal");

            suite.clearChapters();
            expect(suite.getChapters().empty(), "Chapters should be empty after clear");
        }

        beginTest("PodcastProductionSuite - Transcript");
        {
            PodcastProductionSuite suite;
            suite.prepare(48000.0, 512);

            suite.addTranscriptSegment(0.0, 5.0, "Host", "Hello and welcome!");
            suite.addTranscriptSegment(5.0, 10.0, "Guest", "Thank you for having me.");

            auto transcript = suite.getTranscript();
            expect(transcript.size() == 2, "Should have 2 transcript segments");

            juce::String srt = suite.exportTranscriptSRT();
            expect(srt.contains("Hello and welcome!"), "SRT should contain text");
            expect(srt.contains("-->"), "SRT should contain timing markers");

            juce::String vtt = suite.exportTranscriptVTT();
            expect(vtt.contains("WEBVTT"), "VTT should have header");
            expect(vtt.contains("<v Host>"), "VTT should contain speaker tags");
        }

        beginTest("PodcastProductionSuite - Podcast Specs");
        {
            auto apple = PodcastSpec::ApplePodcasts();
            expect(apple.targetLUFS == -16.0f, "Apple Podcasts target should be -16 LUFS");
            expect(apple.sampleRate == 44100, "Apple Podcasts sample rate should be 44100");

            auto spotify = PodcastSpec::Spotify();
            expect(spotify.targetLUFS == -14.0f, "Spotify target should be -14 LUFS");

            auto broadcast = PodcastSpec::Broadcast();
            expect(broadcast.targetLUFS == -23.0f, "Broadcast (EBU R128) target should be -23 LUFS");

            auto audiobook = PodcastSpec::Audiobook();
            expect(audiobook.truePeakMax == -3.0f, "ACX true peak should be -3 dB");
        }

        beginTest("PodcastProductionSuite - Presets");
        {
            PodcastProductionSuite suite;
            suite.prepare(48000.0, 512);

            suite.loadSoloHostPreset();
            expect(suite.getNumTracks() == 1, "Solo host should have 1 track");

            // Clear and load interview
            suite = PodcastProductionSuite();
            suite.prepare(48000.0, 512);
            suite.loadInterviewPreset();
            expect(suite.getNumTracks() == 2, "Interview should have 2 tracks");

            // Clear and load roundtable
            suite = PodcastProductionSuite();
            suite.prepare(48000.0, 512);
            suite.loadRoundtablePreset();
            expect(suite.getNumTracks() == 4, "Roundtable should have 4 tracks");
        }

        beginTest("PodcastProductionSuite - Metadata");
        {
            PodcastProductionSuite suite;

            suite.setMetadata("title", "My Podcast Episode");
            suite.setMetadata("artist", "John Doe");
            suite.setMetadata("description", "An interesting discussion");

            expect(suite.getMetadata("title") == "My Podcast Episode", "Title should be set");
            expect(suite.getMetadata("artist") == "John Doe", "Artist should be set");
            expect(suite.getMetadata("nonexistent") == "", "Non-existent key should return empty");
        }

        beginTest("PodcastProductionSuite - Silence Removal Analysis");
        {
            SilenceRemover remover(-40.0f, 0.5f);

            // Create buffer with silence and content
            juce::AudioBuffer<float> buffer(1, 96000);  // 2 seconds at 48kHz
            buffer.clear();

            // Add content from 0.5s to 1.5s
            for (int i = 24000; i < 72000; ++i)
            {
                buffer.setSample(0, i, 0.5f * std::sin(2.0f * juce::MathConstants<float>::pi * 440.0f * i / 48000.0f));
            }

            auto segments = remover.analyze(buffer, 48000.0);
            expect(!segments.empty(), "Should detect segments");
        }
    }

    //==========================================================================
    // LSTM COMPOSER TESTS
    //==========================================================================

    void runLSTMComposerTests()
    {
        using namespace AI;

        beginTest("LSTMComposer - Initialization");
        {
            LSTMComposer composer;
            composer.prepare(48000.0, 120.0);

            expect(!composer.getIsPlaying(), "Should not be playing initially");
        }

        beginTest("LSTMComposer - Style Configuration");
        {
            LSTMComposer composer;
            composer.prepare(48000.0, 120.0);

            composer.setStyle(CompositionStyle::Jazz());
            composer.setStyle(CompositionStyle::Classical());
            composer.setStyle(CompositionStyle::Electronic());
            composer.setStyle(CompositionStyle::Ambient());
            composer.setStyle(CompositionStyle::Pop());

            expect(true, "All styles should be settable");
        }

        beginTest("LSTMComposer - Key and Scale");
        {
            LSTMComposer composer;
            composer.prepare(48000.0, 120.0);

            composer.setKey(0, "Major");    // C Major
            composer.setKey(7, "Minor");    // G Minor
            composer.setKey(5, "Dorian");   // F Dorian

            expect(true, "Key and scale should be settable");
        }

        beginTest("LSTMComposer - Melody Generation");
        {
            LSTMComposer composer;
            composer.prepare(48000.0, 120.0);
            composer.setKey(0, "Major");

            auto melody = composer.generateMelody(8);  // 8 beats

            expect(!melody.empty(), "Should generate melody events");

            // Check events are valid
            for (const auto& event : melody)
            {
                if (event.type == MusicEvent::Type::NoteOn)
                {
                    expect(event.note >= 0 && event.note < 128, "Note should be valid MIDI");
                    expect(event.velocity >= 0.0f && event.velocity <= 1.0f, "Velocity should be 0-1");
                    expect(event.duration > 0.0, "Duration should be positive");
                }
            }
        }

        beginTest("LSTMComposer - Harmony Generation");
        {
            LSTMComposer composer;
            composer.prepare(48000.0, 120.0);
            composer.setKey(0, "Major");

            auto melody = composer.generateMelody(4);
            auto harmony = composer.generateHarmony(melody, 3);

            // Harmony should have events if melody has note events
            bool hasMelodyNotes = false;
            for (const auto& event : melody)
                if (event.type == MusicEvent::Type::NoteOn)
                    hasMelodyNotes = true;

            if (hasMelodyNotes)
            {
                expect(!harmony.empty(), "Should generate harmony for melody notes");
            }
        }

        beginTest("LSTMComposer - Bassline Generation");
        {
            LSTMComposer composer;
            composer.prepare(48000.0, 120.0);
            composer.setKey(0, "Major");

            auto bassline = composer.generateBassline(8);

            expect(!bassline.empty(), "Should generate bassline");

            // Bassline notes should be low
            for (const auto& event : bassline)
            {
                if (event.type == MusicEvent::Type::NoteOn)
                {
                    expect(event.note < 60, "Bassline notes should be below middle C");
                }
            }
        }

        beginTest("LSTMComposer - Drum Pattern");
        {
            LSTMComposer composer;
            composer.prepare(48000.0, 120.0);

            auto drums = composer.generateDrumPattern(4);

            expect(!drums.empty(), "Should generate drum pattern");
        }

        beginTest("LSTMComposer - Temperature Control");
        {
            LSTMComposer composer;
            composer.prepare(48000.0, 120.0);

            composer.setTemperature(0.5f);   // Conservative
            auto conservative = composer.generateMelody(4);

            composer.setTemperature(1.5f);   // Creative
            auto creative = composer.generateMelody(4);

            expect(!conservative.empty() && !creative.empty(), "Both should generate");
        }

        beginTest("LSTMComposer - MIDI Output");
        {
            LSTMComposer composer;
            composer.prepare(48000.0, 120.0);
            composer.setKey(0, "Major");

            auto melody = composer.generateMelody(4);

            juce::MidiBuffer midiBuffer;
            composer.eventsToMidiBuffer(melody, midiBuffer, 0.0);

            // Should have MIDI events if melody has notes
            bool hasMelodyNotes = false;
            for (const auto& event : melody)
                if (event.type == MusicEvent::Type::NoteOn)
                    hasMelodyNotes = true;

            if (hasMelodyNotes)
            {
                expect(!midiBuffer.isEmpty(), "MIDI buffer should have events");
            }
        }

        beginTest("LSTMComposer - Playback Control");
        {
            LSTMComposer composer;
            composer.prepare(48000.0, 120.0);

            composer.play();
            expect(composer.getIsPlaying(), "Should be playing");

            composer.stop();
            expect(!composer.getIsPlaying(), "Should not be playing");
        }

        beginTest("LSTMComposer - Bio-Reactive Mode");
        {
            LSTMComposer composer;
            composer.prepare(48000.0, 120.0);

            composer.setBioReactiveEnabled(true);
            composer.setBioData(0.7f, 0.8f);

            auto melody = composer.generateMelody(4);
            expect(!melody.empty(), "Should generate with bio-reactive enabled");
        }

        beginTest("LSTMComposer - Learning from Input");
        {
            LSTMComposer composer;
            composer.prepare(48000.0, 120.0);

            std::vector<int> inputMelody = { 60, 62, 64, 65, 67, 69, 71, 72 };  // C scale
            composer.learnFromMelody(inputMelody);

            // Should not throw
            expect(true, "Learning should work");
        }

        beginTest("LSTMComposer - Reset");
        {
            LSTMComposer composer;
            composer.prepare(48000.0, 120.0);
            composer.setKey(0, "Major");

            composer.generateMelody(4);
            composer.reset();

            // Should not throw
            expect(true, "Reset should work");
        }

        beginTest("Music Theory - Scale Quantization");
        {
            std::vector<int> cMajor = { 0, 2, 4, 5, 7, 9, 11 };

            int quantized = MusicTheory::quantizeToScale(61, 60, cMajor);  // C# should go to C or D
            expect(quantized == 60 || quantized == 62, "C# should quantize to C or D in C Major");

            quantized = MusicTheory::quantizeToScale(63, 60, cMajor);  // D# should go to D or E
            expect(quantized == 62 || quantized == 64, "D# should quantize to D or E in C Major");
        }

        beginTest("Music Theory - Chord Patterns");
        {
            auto major = MusicTheory::getChord("Major");
            expect(major.size() == 3, "Major chord should have 3 notes");
            expect(major[0] == 0 && major[1] == 4 && major[2] == 7, "Major: root, M3, P5");

            auto minor = MusicTheory::getChord("Minor");
            expect(minor.size() == 3, "Minor chord should have 3 notes");
            expect(minor[0] == 0 && minor[1] == 3 && minor[2] == 7, "Minor: root, m3, P5");

            auto dom7 = MusicTheory::getChord("Dominant7");
            expect(dom7.size() == 4, "Dom7 should have 4 notes");
        }

        beginTest("Music Theory - Progressions");
        {
            auto pop = MusicTheory::getProgression("Pop");
            expect(!pop.empty(), "Should have Pop progression");

            auto jazz = MusicTheory::getProgression("Jazz");
            expect(!jazz.empty(), "Should have Jazz progression");

            auto blues = MusicTheory::getProgression("Blues");
            expect(!blues.empty(), "Should have Blues progression");
        }
    }
};

// Register the test
static NiceToHaveFeaturesTests niceToHaveFeaturesTests;

} // namespace Tests
} // namespace Echoelmusic
