/*
  ==============================================================================

    ProductionFeaturesTests.h
    Created: 2026
    Author:  Echoelmusic

    Comprehensive Tests for Production Features:
    - AI Stem Separation
    - Time-Stretch/Audio Warping
    - Comping System
    - Sample Browser
    - Track Freeze/Bounce

  ==============================================================================
*/

#pragma once

#include <JuceHeader.h>
#include "../AI/StemSeparation.h"
#include "../DSP/TimeStretchEngine.h"
#include "../Audio/CompingManager.h"
#include "../Content/SampleBrowser.h"
#include "../Audio/TrackFreezer.h"

namespace Echoelmusic {
namespace Tests {

//==============================================================================
/** Test utilities */
class ProductionTestUtils {
public:
    /** Create test audio buffer with sine wave */
    static juce::AudioBuffer<float> createSineWave(float frequency, double duration,
                                                    double sampleRate = 44100.0) {
        int numSamples = static_cast<int>(duration * sampleRate);
        juce::AudioBuffer<float> buffer(2, numSamples);

        for (int ch = 0; ch < 2; ++ch) {
            float* data = buffer.getWritePointer(ch);
            for (int i = 0; i < numSamples; ++i) {
                double phase = 2.0 * juce::MathConstants<double>::pi * frequency * i / sampleRate;
                data[i] = static_cast<float>(std::sin(phase));
            }
        }

        return buffer;
    }

    /** Create test audio with transients (drum-like) */
    static juce::AudioBuffer<float> createDrumPattern(double duration,
                                                       double sampleRate = 44100.0) {
        int numSamples = static_cast<int>(duration * sampleRate);
        juce::AudioBuffer<float> buffer(2, numSamples);
        buffer.clear();

        juce::Random random;

        // Add transients every quarter note (assuming 120 BPM)
        double beatDuration = 0.5; // seconds
        int beatSamples = static_cast<int>(beatDuration * sampleRate);

        for (int beatStart = 0; beatStart < numSamples; beatStart += beatSamples) {
            // Add transient envelope
            int attackSamples = 10;
            int decaySamples = static_cast<int>(0.1 * sampleRate);

            for (int i = 0; i < decaySamples && beatStart + i < numSamples; ++i) {
                float envelope = (i < attackSamples) ?
                                 static_cast<float>(i) / attackSamples :
                                 std::exp(-5.0f * (i - attackSamples) / decaySamples);

                float noise = random.nextFloat() * 2.0f - 1.0f;

                for (int ch = 0; ch < 2; ++ch) {
                    buffer.addSample(ch, beatStart + i, noise * envelope);
                }
            }
        }

        return buffer;
    }

    /** Create noise buffer */
    static juce::AudioBuffer<float> createNoise(double duration,
                                                 double sampleRate = 44100.0) {
        int numSamples = static_cast<int>(duration * sampleRate);
        juce::AudioBuffer<float> buffer(2, numSamples);

        juce::Random random;
        for (int ch = 0; ch < 2; ++ch) {
            float* data = buffer.getWritePointer(ch);
            for (int i = 0; i < numSamples; ++i) {
                data[i] = random.nextFloat() * 2.0f - 1.0f;
            }
        }

        return buffer;
    }

    /** Calculate RMS level */
    static float calculateRMS(const juce::AudioBuffer<float>& buffer) {
        float sum = 0.0f;
        int totalSamples = 0;

        for (int ch = 0; ch < buffer.getNumChannels(); ++ch) {
            const float* data = buffer.getReadPointer(ch);
            for (int i = 0; i < buffer.getNumSamples(); ++i) {
                sum += data[i] * data[i];
                totalSamples++;
            }
        }

        return std::sqrt(sum / totalSamples);
    }
};

//==============================================================================
/** Stem Separation Tests */
class StemSeparationTests : public juce::UnitTest {
public:
    StemSeparationTests() : juce::UnitTest("Stem Separation Tests") {}

    void runTest() override {
        beginTest("SpectralFrame operations");
        {
            AI::SpectralFrame frame;
            frame.resize(1024);

            expect(frame.magnitude.size() == 1024);
            expect(frame.phase.size() == 1024);
            expect(frame.spectrum.size() == 1024);
        }

        beginTest("SpectralMask application");
        {
            AI::SpectralFrame frame;
            frame.resize(256);

            // Fill with test data
            for (size_t i = 0; i < 256; ++i) {
                frame.magnitude[i] = 1.0f;
                frame.phase[i] = 0.0f;
            }
            frame.reconstructFromMagnitudePhase();

            AI::SpectralMask mask;
            mask.resize(256);
            for (size_t i = 0; i < 256; ++i) {
                mask.mask[i] = 0.5f;
            }

            mask.apply(frame);

            // Check magnitudes are halved
            for (size_t i = 0; i < 256; ++i) {
                expectWithinAbsoluteError(frame.magnitude[i], 0.5f, 0.001f);
            }
        }

        beginTest("STFT analysis and synthesis");
        {
            AI::STFTProcessor stft(1024, 256);

            auto input = ProductionTestUtils::createSineWave(440.0f, 0.5);
            auto frames = stft.analyze(input, 0);

            expect(frames.size() > 0);

            auto output = stft.synthesize(frames, 1);
            expect(output.getNumSamples() > 0);
        }

        beginTest("Separator model predict");
        {
            AI::SeparatorModel model(1024, 4);

            AI::SpectralFrame frame;
            frame.resize(513); // 1024/2 + 1

            for (size_t i = 0; i < 513; ++i) {
                frame.magnitude[i] = 0.5f;
                frame.phase[i] = 0.0f;
            }

            auto masks = model.predict(frame);

            expect(masks.size() == 4);

            // Check masks sum to approximately 1.0 at each bin
            for (size_t bin = 0; bin < masks[0].mask.size(); ++bin) {
                float sum = 0.0f;
                for (const auto& mask : masks) {
                    sum += mask.mask[bin];
                }
                expectWithinAbsoluteError(sum, 1.0f, 0.01f);
            }
        }

        beginTest("Full stem separation");
        {
            AI::StemSeparationEngine engine;

            auto testAudio = ProductionTestUtils::createSineWave(440.0f, 1.0);

            auto stems = engine.separate(testAudio,
                {AI::StemType::Vocals, AI::StemType::Drums},
                AI::SeparationQuality::Draft);

            expect(stems.size() == 2);
            expect(stems[0].type == AI::StemType::Vocals);
            expect(stems[1].type == AI::StemType::Drums);
        }

        beginTest("Vocal isolation");
        {
            AI::StemSeparationEngine engine;

            auto testAudio = ProductionTestUtils::createSineWave(440.0f, 0.5);
            auto vocals = engine.isolateVocals(testAudio);

            expect(vocals.getNumSamples() > 0);
        }

        beginTest("Vocal removal (karaoke)");
        {
            AI::StemSeparationEngine engine;

            auto testAudio = ProductionTestUtils::createSineWave(440.0f, 0.5);
            auto karaoke = engine.removeVocals(testAudio);

            expect(karaoke.getNumSamples() > 0);
        }
    }
};

//==============================================================================
/** Time-Stretch Engine Tests */
class TimeStretchTests : public juce::UnitTest {
public:
    TimeStretchTests() : juce::UnitTest("Time-Stretch Tests") {}

    void runTest() override {
        beginTest("Transient detector");
        {
            DSP::TransientDetector detector(44100);

            auto drums = ProductionTestUtils::createDrumPattern(2.0);
            auto transients = detector.detectTransients(
                drums.getReadPointer(0), drums.getNumSamples());

            expect(transients.size() >= 2); // Should detect at least some transients
        }

        beginTest("Phase vocoder analyze");
        {
            DSP::PhaseVocoder vocoder(2048, 512);

            auto sine = ProductionTestUtils::createSineWave(440.0f, 0.1);
            auto frame = vocoder.analyze(sine.getReadPointer(0));

            expect(frame.magnitude.size() == 1025); // FFT size / 2 + 1
            expect(frame.phase.size() == 1025);
            expect(frame.frequency.size() == 1025);
        }

        beginTest("Time stretch 2x");
        {
            DSP::TimeStretchEngine engine(44100);
            engine.setStretchRatio(2.0);

            auto input = ProductionTestUtils::createSineWave(440.0f, 0.5);
            auto output = engine.process(input);

            // Output should be approximately twice as long
            int expectedSamples = input.getNumSamples() * 2;
            expectWithinAbsoluteError(static_cast<double>(output.getNumSamples()),
                                      static_cast<double>(expectedSamples),
                                      static_cast<double>(4410)); // 10% tolerance
        }

        beginTest("Time stretch 0.5x");
        {
            DSP::TimeStretchEngine engine(44100);
            engine.setStretchRatio(0.5);

            auto input = ProductionTestUtils::createSineWave(440.0f, 1.0);
            auto output = engine.process(input);

            // Output should be approximately half as long
            int expectedSamples = input.getNumSamples() / 2;
            expectWithinAbsoluteError(static_cast<double>(output.getNumSamples()),
                                      static_cast<double>(expectedSamples),
                                      static_cast<double>(4410));
        }

        beginTest("Pitch shift");
        {
            DSP::TimeStretchEngine engine(44100);
            engine.setPitchShift(12.0); // One octave up

            auto input = ProductionTestUtils::createSineWave(440.0f, 0.5);
            auto output = engine.process(input);

            // Length should remain approximately the same
            expectWithinAbsoluteError(static_cast<double>(output.getNumSamples()),
                                      static_cast<double>(input.getNumSamples()),
                                      static_cast<double>(4410));
        }

        beginTest("Formant preservation");
        {
            DSP::FormantShifter shifter(2048);

            std::vector<float> magnitude(1025, 0.5f);
            shifter.analyzeFormants(magnitude);

            float originalSum = 0;
            for (float m : magnitude) originalSum += m;

            shifter.shiftFormants(magnitude, 1.5f);

            // Should still have signal
            expect(!magnitude.empty());
        }

        beginTest("Warp markers");
        {
            DSP::WarpRegion region;
            region.addMarker(0.0, 0.0, true);
            region.addMarker(1.0, 2.0, true);  // Stretch 2x
            region.addMarker(2.0, 3.0, true);  // Compress

            double ratio = region.getStretchRatioAt(0.5);
            expectWithinAbsoluteError(ratio, 2.0, 0.01);

            double targetPos = region.sourceToTarget(0.5);
            expectWithinAbsoluteError(targetPos, 1.0, 0.01);
        }

        beginTest("Tempo matching");
        {
            DSP::TimeStretchEngine engine(44100);

            auto input = ProductionTestUtils::createSineWave(440.0f, 4.0); // 4 seconds
            auto output = engine.tempoMatch(input, 120.0, 60.0); // Half speed

            // Output should be twice as long
            int expectedSamples = input.getNumSamples() * 2;
            expectWithinAbsoluteError(static_cast<double>(output.getNumSamples()),
                                      static_cast<double>(expectedSamples),
                                      static_cast<double>(8820));
        }

        beginTest("Auto quantize");
        {
            DSP::TimeStretchEngine engine(44100);

            auto drums = ProductionTestUtils::createDrumPattern(4.0);
            auto warpRegion = engine.autoQuantize(drums, 120.0, 0.25);

            expect(warpRegion.markers.size() >= 2);
            expect(warpRegion.targetDuration > 0);
        }
    }
};

//==============================================================================
/** Comping System Tests */
class CompingTests : public juce::UnitTest {
public:
    CompingTests() : juce::UnitTest("Comping System Tests") {}

    void runTest() override {
        beginTest("Take creation");
        {
            Audio::Take take(1, 0.0, 4.0);

            expect(take.getTakeNumber() == 1);
            expect(take.getStartTime() == 0.0);
            expect(take.getEndTime() == 4.0);
            expect(take.getDuration() == 4.0);
        }

        beginTest("Take rating");
        {
            Audio::Take take(1, 0.0, 4.0);

            take.setRating(Audio::TakeRating::Great);
            expect(take.getRating() == Audio::TakeRating::Great);

            juce::String ratingStr = Audio::takeRatingToString(Audio::TakeRating::Great);
            expect(ratingStr == "Great");
        }

        beginTest("Take audio data");
        {
            Audio::Take take(1, 0.0, 2.0);

            auto audio = ProductionTestUtils::createSineWave(440.0f, 2.0);
            take.setAudioData(audio, 44100.0);

            expect(take.getAudioBuffer().getNumSamples() == audio.getNumSamples());
            expect(take.getSampleRate() == 44100.0);
        }

        beginTest("Comp segment creation");
        {
            Audio::CompSegment segment;
            segment.takeId = "take1";
            segment.startTime = 0.0;
            segment.endTime = 2.0;
            segment.fadeInLength = 0.01;
            segment.fadeOutLength = 0.01;

            expect(segment.getDuration() == 2.0);
            expect(segment.contains(1.0));
            expect(!segment.contains(3.0));
        }

        beginTest("Comp segment overlap");
        {
            Audio::CompSegment seg1;
            seg1.startTime = 0.0;
            seg1.endTime = 2.0;

            Audio::CompSegment seg2;
            seg2.startTime = 1.5;
            seg2.endTime = 3.5;

            expect(seg1.overlaps(seg2));

            Audio::CompSegment seg3;
            seg3.startTime = 3.0;
            seg3.endTime = 5.0;

            expect(!seg1.overlaps(seg3));
        }

        beginTest("Comp building");
        {
            Audio::Comp comp("Test Comp");

            Audio::CompSegment seg1;
            seg1.takeId = "take1";
            seg1.startTime = 0.0;
            seg1.endTime = 2.0;
            comp.addSegment(seg1);

            Audio::CompSegment seg2;
            seg2.takeId = "take2";
            seg2.startTime = 2.0;
            seg2.endTime = 4.0;
            comp.addSegment(seg2);

            expect(comp.getSegments().size() == 2);
            expect(comp.getDuration() == 4.0);

            auto foundSeg = comp.getSegmentAt(1.0);
            expect(foundSeg.has_value());
            expect(foundSeg->takeId == "take1");
        }

        beginTest("Take lane management");
        {
            Audio::TakeLane lane("Vocal Takes");

            auto* take1 = lane.addTake(0.0, 8.0);
            auto* take2 = lane.addTake(0.0, 8.0);
            auto* take3 = lane.addTake(0.0, 8.0);

            expect(lane.getNumTakes() == 3);
            expect(take1->getTakeNumber() == 1);
            expect(take2->getTakeNumber() == 2);
            expect(take3->getTakeNumber() == 3);

            lane.removeTake(1);
            expect(lane.getNumTakes() == 2);
        }

        beginTest("Crossfade calculation");
        {
            // Linear fade in
            float linearFadeIn = Audio::CrossfadeCalculator::calculateGain(
                0.5f, Audio::CrossfadeShape::Linear, true);
            expectWithinAbsoluteError(linearFadeIn, 0.5f, 0.001f);

            // Equal power fade
            float eqPowerFadeIn = Audio::CrossfadeCalculator::calculateGain(
                0.5f, Audio::CrossfadeShape::EqualPower, true);
            expectWithinAbsoluteError(eqPowerFadeIn, 0.707f, 0.01f); // sin(45deg)
        }

        beginTest("Comping manager");
        {
            Audio::CompingManager manager;

            auto* lane = manager.createTakeLane("track1", "Vocal Takes");
            expect(lane != nullptr);

            auto* take1 = lane->addTake(0.0, 8.0);
            take1->setAudioData(ProductionTestUtils::createSineWave(440.0f, 8.0), 44100.0);

            auto* take2 = lane->addTake(0.0, 8.0);
            take2->setAudioData(ProductionTestUtils::createSineWave(550.0f, 8.0), 44100.0);

            manager.swipeComp("track1", take1->getId(), 0.0, 4.0);
            manager.swipeComp("track1", take2->getId(), 4.0, 8.0);

            auto* comp = lane->getActiveComp();
            expect(comp != nullptr);
            expect(comp->getSegments().size() == 2);
        }

        beginTest("Loop recording");
        {
            Audio::CompingManager manager;
            manager.createTakeLane("track1");

            Audio::LoopRecordingSettings settings;
            settings.enabled = true;
            settings.loopStart = 0.0;
            settings.loopEnd = 4.0;
            settings.maxTakes = 10;

            manager.startLoopRecording("track1", settings);
            expect(manager.isLoopRecording());

            // Simulate loop passes
            manager.onLoopBoundary();
            manager.onLoopBoundary();
            manager.onLoopBoundary();

            manager.stopLoopRecording();
            expect(!manager.isLoopRecording());

            auto* lane = manager.getTakeLane("track1");
            expect(lane->getNumTakes() == 3);
        }

        beginTest("Comp flattening");
        {
            Audio::CompingManager manager;
            auto* lane = manager.createTakeLane("track1");

            auto* take1 = lane->addTake(0.0, 2.0);
            auto audio1 = ProductionTestUtils::createSineWave(440.0f, 2.0);
            take1->setAudioData(audio1, 44100.0);

            manager.swipeComp("track1", take1->getId(), 0.0, 2.0);

            auto flattened = manager.flattenComp("track1", 44100.0);
            expect(flattened.getNumSamples() > 0);
        }
    }
};

//==============================================================================
/** Sample Browser Tests */
class SampleBrowserTests : public juce::UnitTest {
public:
    SampleBrowserTests() : juce::UnitTest("Sample Browser Tests") {}

    void runTest() override {
        beginTest("Sample metadata");
        {
            Content::SampleMetadata meta;
            meta.name = "Kick 01";
            meta.duration = 0.5;
            meta.bpm = 120.0;
            meta.key = "C";
            meta.isLoop = false;

            expect(meta.getFormattedDuration() == "0:00.500");

            meta.fileSizeBytes = 1024 * 1024 * 2;
            expect(meta.getFormattedFileSize() == "2.0 MB");
        }

        beginTest("Sample tagging");
        {
            Content::SampleMetadata meta;

            meta.addTag("drums");
            meta.addTag("punchy");
            meta.addTag("808");

            expect(meta.tags.size() == 3);
            expect(meta.hasTag("drums"));
            expect(meta.hasTag("DRUMS")); // Case insensitive

            meta.removeTag("drums");
            expect(!meta.hasTag("drums"));
        }

        beginTest("Sample metadata serialization");
        {
            Content::SampleMetadata meta;
            meta.name = "Test Sample";
            meta.duration = 2.5;
            meta.bpm = 128.0;
            meta.rating = 4;
            meta.addTag("test");

            auto json = meta.toVar();
            auto loaded = Content::SampleMetadata::fromVar(json);

            expect(loaded.name == meta.name);
            expect(loaded.duration == meta.duration);
            expect(loaded.bpm == meta.bpm);
            expect(loaded.rating == meta.rating);
            expect(loaded.hasTag("test"));
        }

        beginTest("Search filter - text");
        {
            Content::SearchFilter filter;
            filter.searchText = "kick";

            Content::SampleMetadata meta1;
            meta1.name = "Kick 01";
            expect(filter.matches(meta1));

            Content::SampleMetadata meta2;
            meta2.name = "Snare 01";
            expect(!filter.matches(meta2));
        }

        beginTest("Search filter - category");
        {
            Content::SearchFilter filter;
            filter.categories.insert(Content::SampleCategory::Drums);

            Content::SampleMetadata meta1;
            meta1.category = Content::SampleCategory::Drums;
            expect(filter.matches(meta1));

            Content::SampleMetadata meta2;
            meta2.category = Content::SampleCategory::Bass;
            expect(!filter.matches(meta2));
        }

        beginTest("Search filter - BPM range");
        {
            Content::SearchFilter filter;
            filter.minBPM = 120.0;
            filter.maxBPM = 130.0;

            Content::SampleMetadata meta1;
            meta1.bpm = 125.0;
            expect(filter.matches(meta1));

            Content::SampleMetadata meta2;
            meta2.bpm = 140.0;
            expect(!filter.matches(meta2));
        }

        beginTest("Search filter - rating");
        {
            Content::SearchFilter filter;
            filter.minRating = 4;

            Content::SampleMetadata meta1;
            meta1.rating = 5;
            expect(filter.matches(meta1));

            Content::SampleMetadata meta2;
            meta2.rating = 2;
            expect(!filter.matches(meta2));
        }

        beginTest("Search filter - favorites");
        {
            Content::SearchFilter filter;
            filter.favoritesOnly = true;

            Content::SampleMetadata meta1;
            meta1.isFavorite = true;
            expect(filter.matches(meta1));

            Content::SampleMetadata meta2;
            meta2.isFavorite = false;
            expect(!filter.matches(meta2));
        }

        beginTest("Smart collection");
        {
            Content::SmartCollection loopsCollection;
            loopsCollection.name = "All Loops";
            loopsCollection.filter.loopsOnly = true;

            Content::SampleMetadata loopMeta;
            loopMeta.isLoop = true;
            expect(loopsCollection.filter.matches(loopMeta));

            Content::SampleMetadata oneShotMeta;
            oneShotMeta.isLoop = false;
            expect(!loopsCollection.filter.matches(oneShotMeta));
        }

        beginTest("Category conversion");
        {
            expect(Content::categoryToString(Content::SampleCategory::Drums) == "Drums");
            expect(Content::categoryToString(Content::SampleCategory::Vocals) == "Vocals");
            expect(Content::categoryToString(Content::SampleCategory::FX) == "FX");
        }

        beginTest("Sample browser initialization");
        {
            Content::SampleBrowser browser;

            expect(browser.getTotalSampleCount() == 0);
            expect(browser.getSmartCollections().size() > 0);
        }
    }
};

//==============================================================================
/** Track Freezer Tests */
class TrackFreezerTests : public juce::UnitTest {
public:
    TrackFreezerTests() : juce::UnitTest("Track Freezer Tests") {}

    void runTest() override {
        beginTest("Render settings");
        {
            Audio::RenderSettings settings;
            settings.quality = Audio::RenderQuality::High;

            expect(settings.getBitDepth() == 32);

            settings.quality = Audio::RenderQuality::Draft;
            expect(settings.getBitDepth() == 16);
        }

        beginTest("Dither processor");
        {
            Audio::DitherProcessor dither(Audio::DitherProcessor::DitherType::Triangular, 16);

            auto buffer = ProductionTestUtils::createSineWave(440.0f, 0.1);
            float rmsBefore = ProductionTestUtils::calculateRMS(buffer);

            dither.process(buffer);

            float rmsAfter = ProductionTestUtils::calculateRMS(buffer);

            // Dither should not significantly change RMS level
            expectWithinAbsoluteError(rmsAfter, rmsBefore, 0.01f);
        }

        beginTest("Normalizer");
        {
            Audio::Normalizer normalizer(-3.0f); // Target -3dB

            auto buffer = ProductionTestUtils::createSineWave(440.0f, 0.1);
            buffer.applyGain(0.5f); // Make it quieter

            normalizer.analyze(buffer);
            normalizer.apply(buffer);

            // Peak should be close to target
            float peak = buffer.getMagnitude(0, 0, buffer.getNumSamples());
            float targetPeak = juce::Decibels::decibelsToGain(-3.0f);
            expectWithinAbsoluteError(peak, targetPeak, 0.01f);
        }

        beginTest("Track render source");
        {
            Audio::TrackRenderSource source("track1");
            source.setLength(4.0);
            source.setNumChannels(2);

            expect(source.getLength() == 4.0);
            expect(source.getNumChannels() == 2);
            expect(source.getName() == "track1");
        }

        beginTest("Freeze state");
        {
            Audio::FreezeState state;
            state.isFrozen = true;
            state.mode = Audio::FreezeMode::PostFX;
            state.startTime = 0.0;
            state.endTime = 10.0;

            expect(state.isFrozen);
            expect(state.mode == Audio::FreezeMode::PostFX);
        }

        beginTest("Batch exporter presets");
        {
            auto mp3Settings = Audio::BatchExporter::getMP3Preset();
            expect(mp3Settings.sampleRate == 44100.0);
            expect(mp3Settings.bitDepth == 16);

            auto masterSettings = Audio::BatchExporter::getWAVMasterPreset();
            expect(masterSettings.sampleRate == 96000.0);
            expect(masterSettings.bitDepth == 24);
            expect(masterSettings.normalize == true);
            expect(masterSettings.addDither == true);

            auto stemSettings = Audio::BatchExporter::getStemPreset();
            expect(stemSettings.sampleRate == 48000.0);
            expect(stemSettings.normalize == false);
        }

        beginTest("Render progress");
        {
            Audio::RenderProgress progress;
            progress.progress = 0.5;
            progress.elapsedTime = 5.0;
            progress.estimatedRemaining = 5.0;
            progress.currentStage = "Rendering...";

            expect(progress.progress == 0.5);
            expect(!progress.isComplete);
            expect(!progress.hasError);
        }
    }
};

//==============================================================================
/** Run all production feature tests */
class ProductionFeaturesTestRunner {
public:
    static void runAllTests() {
        juce::UnitTestRunner runner;
        runner.setAssertOnFailure(false);

        runner.runTests({
            new StemSeparationTests(),
            new TimeStretchTests(),
            new CompingTests(),
            new SampleBrowserTests(),
            new TrackFreezerTests()
        });

        int numTests = runner.getNumResults();
        int numPassed = 0;

        for (int i = 0; i < numTests; ++i) {
            if (runner.getResult(i)->failures == 0) {
                numPassed++;
            }
        }

        DBG("=== Production Features Test Results ===");
        DBG("Tests run: " + juce::String(numTests));
        DBG("Tests passed: " + juce::String(numPassed));
        DBG("Tests failed: " + juce::String(numTests - numPassed));
    }
};

} // namespace Tests
} // namespace Echoelmusic
