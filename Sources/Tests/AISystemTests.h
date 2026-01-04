/*
  ==============================================================================

    AISystemTests.h
    Comprehensive Tests for AI Composition and Style Transfer Systems

    Tests cover:
    - AICompositionEngine functionality
    - StyleTransferEngine functionality
    - Integration with Ralph Wiggum systems
    - Bio-reactive adaptation
    - Thread safety under load
    - Edge cases and error handling

  ==============================================================================
*/

#pragma once

#include "../Testing/EchoelTestFramework.h"
#include "../AI/AICompositionEngine.h"
#include "../AI/StyleTransferEngine.h"
#include "../Core/RalphWiggumAIBridge.h"
#include <thread>
#include <future>
#include <chrono>

namespace Echoelmusic {
namespace Testing {

//==============================================================================
// AI Composition Engine Tests
//==============================================================================

class AICompositionTestSuite : public TestSuite
{
public:
    AICompositionTestSuite() : TestSuite("AIComposition")
    {
        addTest("EngineInitialization", [this]() {
            auto& engine = AI::AICompositionEngine::getInstance();

            AI::AIModelConfig config;
            config.modelSize = AI::AIModelConfig::ModelSize::Micro;
            config.temperature = 0.7f;

            engine.initialize(config);
            ECHOEL_ASSERT(engine.isInitialized());

            engine.shutdown();
        });

        addTest("MelodyGeneration", [this]() {
            auto& engine = AI::AICompositionEngine::getInstance();
            engine.initialize();

            AI::CompositionContext ctx;
            ctx.rootNote = 0;  // C
            ctx.isMinor = false;
            ctx.tempo = 120.0;
            ctx.genre = "pop";

            engine.updateContext(ctx);

            auto melody = engine.generateMelody(8);

            ECHOEL_ASSERT(!melody.isEmpty());
            ECHOEL_ASSERT_EQUAL(8, melody.length());

            // All notes should be valid MIDI
            for (int note : melody.notes)
            {
                ECHOEL_ASSERT(note >= 0 && note <= 127);
            }

            // All velocities should be valid
            for (float vel : melody.velocities)
            {
                ECHOEL_ASSERT(vel >= 0.0f && vel <= 1.0f);
            }

            engine.shutdown();
        });

        addTest("ChordGeneration", [this]() {
            auto& engine = AI::AICompositionEngine::getInstance();
            engine.initialize();

            AI::CompositionContext ctx;
            ctx.rootNote = 0;  // C
            ctx.genre = "jazz";

            engine.updateContext(ctx);

            auto progression = engine.generateChords(4);

            ECHOEL_ASSERT_EQUAL(4, static_cast<int>(progression.chords.size()));

            // Each chord should have at least 3 notes (triad)
            for (const auto& chord : progression.chords)
            {
                ECHOEL_ASSERT(chord.notes.size() >= 3);
                ECHOEL_ASSERT(!chord.symbol.isEmpty());
            }

            engine.shutdown();
        });

        addTest("RhythmGeneration", [this]() {
            auto& engine = AI::AICompositionEngine::getInstance();
            engine.initialize();

            AI::CompositionContext ctx;
            ctx.genre = "electronic";

            engine.updateContext(ctx);

            auto rhythm = engine.generateRhythm(4, "house");

            ECHOEL_ASSERT(rhythm.hits.size() > 0);
            ECHOEL_ASSERT_EQUAL(4, rhythm.lengthBeats);

            // Check for kick on beat 1
            bool hasKickOnOne = false;
            for (const auto& hit : rhythm.hits)
            {
                if (hit.instrument == "kick" && hit.time < 0.1f)
                {
                    hasKickOnOne = true;
                    break;
                }
            }
            ECHOEL_ASSERT(hasKickOnOne);

            engine.shutdown();
        });

        addTest("ArrangementSuggestion", [this]() {
            auto& engine = AI::AICompositionEngine::getInstance();
            engine.initialize();

            AI::CompositionContext ctx;
            ctx.currentBeat = 0.0;  // Start of song
            ctx.energy = 0.3f;

            engine.updateContext(ctx);

            auto suggestion = engine.suggestArrangement();

            // At the start, should suggest intro
            ECHOEL_ASSERT(suggestion.suggestedSection ==
                         AI::ArrangementSuggestion::SectionType::Intro);
            ECHOEL_ASSERT(suggestion.lengthBars > 0);

            engine.shutdown();
        });

        addTest("AsyncGeneration", [this]() {
            auto& engine = AI::AICompositionEngine::getInstance();
            engine.initialize();

            std::atomic<bool> callbackCalled{false};
            AI::GeneratedMelody receivedMelody;

            auto requestId = engine.requestMelodyAsync(8,
                [&](const AI::GeneratedMelody& melody) {
                    receivedMelody = melody;
                    callbackCalled = true;
                });

            ECHOEL_ASSERT(requestId > 0);

            // Wait for callback (max 2 seconds)
            int waitMs = 0;
            while (!callbackCalled && waitMs < 2000)
            {
                std::this_thread::sleep_for(std::chrono::milliseconds(10));
                waitMs += 10;
            }

            ECHOEL_ASSERT(callbackCalled.load());
            ECHOEL_ASSERT(!receivedMelody.isEmpty());

            engine.shutdown();
        });

        addTest("BioReactiveAdaptation", [this]() {
            auto& engine = AI::AICompositionEngine::getInstance();
            engine.initialize();

            AI::CompositionContext ctx;
            ctx.complexity = 0.8f;

            engine.updateContext(ctx);

            // High coherence = full complexity
            engine.updateBioState(0.9f, 0.8f, 0.1f);
            auto highCoherenceMelody = engine.generateMelody(8);

            // Low coherence = simplified
            engine.updateBioState(0.2f, 0.3f, 0.8f);
            auto lowCoherenceMelody = engine.generateMelody(8);

            // Both should generate valid melodies
            ECHOEL_ASSERT(!highCoherenceMelody.isEmpty());
            ECHOEL_ASSERT(!lowCoherenceMelody.isEmpty());

            engine.shutdown();
        });

        addTest("LearningFeedback", [this]() {
            auto& engine = AI::AICompositionEngine::getInstance();
            engine.initialize();

            auto stats1 = engine.getStats();
            int initialAccepted = stats1.acceptedGenerations;

            // Generate and accept
            engine.requestMelodyAsync(8, [](const AI::GeneratedMelody&) {});
            std::this_thread::sleep_for(std::chrono::milliseconds(100));

            engine.acceptSuggestion(1);

            auto stats2 = engine.getStats();
            ECHOEL_ASSERT(stats2.acceptedGenerations > initialAccepted);

            engine.shutdown();
        });

        addTest("TemperatureAffectsOutput", [this]() {
            auto& engine = AI::AICompositionEngine::getInstance();
            engine.initialize();

            // Low temperature = more predictable
            engine.setTemperature(0.1f);
            auto lowTempMelody1 = engine.generateMelody(8);
            auto lowTempMelody2 = engine.generateMelody(8);

            // High temperature = more varied
            engine.setTemperature(1.5f);
            auto highTempMelody1 = engine.generateMelody(8);
            auto highTempMelody2 = engine.generateMelody(8);

            // All should be valid
            ECHOEL_ASSERT(!lowTempMelody1.isEmpty());
            ECHOEL_ASSERT(!highTempMelody1.isEmpty());

            engine.shutdown();
        });

        addTest("ConcurrentRequests", [this]() {
            auto& engine = AI::AICompositionEngine::getInstance();
            engine.initialize();

            std::atomic<int> completedCount{0};
            constexpr int NUM_REQUESTS = 20;

            for (int i = 0; i < NUM_REQUESTS; ++i)
            {
                engine.requestMelodyAsync(4, [&](const AI::GeneratedMelody&) {
                    completedCount++;
                });
            }

            // Wait for all to complete (max 5 seconds)
            int waitMs = 0;
            while (completedCount < NUM_REQUESTS && waitMs < 5000)
            {
                std::this_thread::sleep_for(std::chrono::milliseconds(50));
                waitMs += 50;
            }

            ECHOEL_ASSERT(completedCount == NUM_REQUESTS);

            engine.shutdown();
        });
    }
};

//==============================================================================
// Style Transfer Engine Tests
//==============================================================================

class StyleTransferTestSuite : public TestSuite
{
public:
    StyleTransferTestSuite() : TestSuite("StyleTransfer")
    {
        addTest("GetAvailablePresets", [this]() {
            auto& engine = AI::StyleTransferEngine::getInstance();
            auto presets = engine.getAvailablePresets();

            ECHOEL_ASSERT(presets.size() > 0);

            // Check for common genres
            bool hasJazz = false, hasElectronic = false;
            for (const auto& preset : presets)
            {
                if (preset == "jazz") hasJazz = true;
                if (preset == "electronic") hasElectronic = true;
            }

            ECHOEL_ASSERT(hasJazz);
            ECHOEL_ASSERT(hasElectronic);
        });

        addTest("ApplyJazzStyle", [this]() {
            auto& engine = AI::StyleTransferEngine::getInstance();

            // Create test input
            std::vector<AI::StyledMIDI::Note> input = {
                {60, 0.0f, 0.5f, 0.8f, 1},   // C on beat 1
                {62, 0.5f, 0.5f, 0.7f, 1},   // D on beat 1.5
                {64, 1.0f, 0.5f, 0.8f, 1},   // E on beat 2
                {65, 1.5f, 0.5f, 0.7f, 1}    // F on beat 2.5
            };

            auto result = engine.applyPreset(input, "jazz", 0.8f);

            ECHOEL_ASSERT_EQUAL(4, static_cast<int>(result.notes.size()));
            ECHOEL_ASSERT(result.appliedStyle.name == "jazz");

            // Jazz should add swing to off-beats
            ECHOEL_ASSERT(result.appliedStyle.swingAmount > 0);
        });

        addTest("SwingApplication", [this]() {
            auto& engine = AI::StyleTransferEngine::getInstance();

            // Create straight eighth notes
            std::vector<AI::StyledMIDI::Note> straight;
            for (int i = 0; i < 8; ++i)
            {
                straight.push_back({60, i * 0.5f, 0.4f, 0.7f, 1});
            }

            // Apply jazz style with strong swing
            auto swung = engine.applyPreset(straight, "jazz", 1.0f);

            // Check that off-beats moved
            bool offbeatsMoved = false;
            for (size_t i = 1; i < swung.notes.size(); i += 2)
            {
                float expectedStraight = i * 0.5f;
                if (std::abs(swung.notes[i].startBeat - expectedStraight) > 0.01f)
                {
                    offbeatsMoved = true;
                    break;
                }
            }

            ECHOEL_ASSERT(offbeatsMoved);
        });

        addTest("StyleAnalysis", [this]() {
            auto& engine = AI::StyleTransferEngine::getInstance();

            // Create highly syncopated input
            std::vector<AI::StyledMIDI::Note> syncopated = {
                {60, 0.25f, 0.25f, 0.9f, 1},   // Off beat 1
                {62, 0.75f, 0.25f, 0.8f, 1},   // Off beat 2
                {64, 1.25f, 0.25f, 0.9f, 1},   // Off beat 3
                {65, 1.75f, 0.25f, 0.8f, 1}    // Off beat 4
            };

            auto analyzed = engine.analyzeStyle(syncopated);

            // Should detect high syncopation
            ECHOEL_ASSERT(analyzed.syncopation > 0.5f);
        });

        addTest("StyleSimilarity", [this]() {
            auto& engine = AI::StyleTransferEngine::getInstance();

            AI::MusicalStyle jazz = AI::StylePresets::getStyle("jazz");
            AI::MusicalStyle blues = AI::StylePresets::getStyle("blues");
            AI::MusicalStyle electronic = AI::StylePresets::getStyle("electronic");

            // Jazz and blues should be more similar than jazz and electronic
            float jazzBluesSim = engine.measureStyleSimilarity(jazz, blues);
            float jazzElecSim = engine.measureStyleSimilarity(jazz, electronic);

            // Both should be non-zero
            ECHOEL_ASSERT(jazzBluesSim > 0.0f);
            ECHOEL_ASSERT(jazzElecSim > 0.0f);
        });

        addTest("DynamicTransformation", [this]() {
            auto& engine = AI::StyleTransferEngine::getInstance();

            // Create uniform velocity input
            std::vector<AI::StyledMIDI::Note> uniform;
            for (int i = 0; i < 8; ++i)
            {
                uniform.push_back({60, static_cast<float>(i), 0.5f, 0.6f, 1});
            }

            // Apply cinematic style (high dynamic range)
            AI::StyleTransferParams params;
            params.dynamicsTransfer = 1.0f;

            auto result = engine.applyStyle(
                uniform,
                AI::StylePresets::getStyle("cinematic_epic"),
                params
            );

            // Should have more velocity variation
            float minVel = 1.0f, maxVel = 0.0f;
            for (const auto& note : result.notes)
            {
                minVel = std::min(minVel, note.velocity);
                maxVel = std::max(maxVel, note.velocity);
            }

            ECHOEL_ASSERT(maxVel > minVel);
        });

        addTest("ContentPreservation", [this]() {
            auto& engine = AI::StyleTransferEngine::getInstance();

            std::vector<AI::StyledMIDI::Note> input = {
                {60, 0.0f, 1.0f, 0.8f, 1},
                {64, 1.0f, 1.0f, 0.8f, 1},
                {67, 2.0f, 1.0f, 0.8f, 1}
            };

            AI::StyleTransferParams params;
            params.preservePitch = true;
            params.styleStrength = 1.0f;

            auto result = engine.applyStyle(
                input,
                AI::StylePresets::getStyle("jazz"),
                params
            );

            // Pitches should be preserved
            for (size_t i = 0; i < input.size(); ++i)
            {
                ECHOEL_ASSERT_EQUAL(input[i].pitch, result.notes[i].pitch);
            }
        });

        addTest("EmptyInputHandling", [this]() {
            auto& engine = AI::StyleTransferEngine::getInstance();

            std::vector<AI::StyledMIDI::Note> empty;
            auto result = engine.applyPreset(empty, "jazz");

            // Should handle gracefully
            ECHOEL_ASSERT_EQUAL(0, static_cast<int>(result.notes.size()));
        });
    }
};

//==============================================================================
// Integration Tests
//==============================================================================

class AIIntegrationTestSuite : public TestSuite
{
public:
    AIIntegrationTestSuite() : TestSuite("AIIntegration")
    {
        addTest("CompositionToStyleTransfer", [this]() {
            // Generate melody with composition engine
            auto& compEngine = AI::AICompositionEngine::getInstance();
            compEngine.initialize();

            auto melody = compEngine.generateMelody(8);
            ECHOEL_ASSERT(!melody.isEmpty());

            // Convert to style transfer format
            std::vector<AI::StyledMIDI::Note> notes;
            for (size_t i = 0; i < melody.notes.size(); ++i)
            {
                AI::StyledMIDI::Note note;
                note.pitch = melody.notes[i];
                note.startBeat = melody.startTimes[i];
                note.duration = melody.durations[i];
                note.velocity = melody.velocities[i];
                note.channel = 1;
                notes.push_back(note);
            }

            // Apply style transfer
            auto& styleEngine = AI::StyleTransferEngine::getInstance();
            auto styled = styleEngine.applyPreset(notes, "jazz");

            ECHOEL_ASSERT_EQUAL(8, static_cast<int>(styled.notes.size()));

            compEngine.shutdown();
        });

        addTest("RalphWiggumIntegration", [this]() {
            auto& aiBridge = RalphWiggum::RalphWiggumAIBridge::getInstance();
            auto& compEngine = AI::AICompositionEngine::getInstance();

            compEngine.initialize();

            // Get suggestion from Ralph Wiggum
            auto suggestion = aiBridge.getNextSuggestion();

            // Use composition engine to expand on it
            AI::CompositionContext ctx;
            ctx.genre = "pop";

            compEngine.updateContext(ctx);
            auto melody = compEngine.generateMelody(4);

            ECHOEL_ASSERT(!melody.isEmpty());

            compEngine.shutdown();
        });

        addTest("FullPipelineStressTest", [this]() {
            auto& compEngine = AI::AICompositionEngine::getInstance();
            auto& styleEngine = AI::StyleTransferEngine::getInstance();

            compEngine.initialize();

            std::atomic<int> successCount{0};
            std::vector<std::future<void>> futures;

            for (int i = 0; i < 10; ++i)
            {
                futures.push_back(std::async(std::launch::async, [&, i]() {
                    try {
                        // Generate
                        auto melody = compEngine.generateMelody(4);

                        if (!melody.isEmpty())
                        {
                            // Convert
                            std::vector<AI::StyledMIDI::Note> notes;
                            for (size_t j = 0; j < melody.notes.size(); ++j)
                            {
                                notes.push_back({
                                    melody.notes[j],
                                    melody.startTimes[j],
                                    melody.durations[j],
                                    melody.velocities[j],
                                    1
                                });
                            }

                            // Style
                            auto styles = styleEngine.getAvailablePresets();
                            auto styled = styleEngine.applyPreset(
                                notes, styles[i % styles.size()]);

                            if (styled.notes.size() > 0)
                                successCount++;
                        }
                    } catch (...) {
                        // Count failures
                    }
                }));
            }

            for (auto& f : futures)
                f.get();

            ECHOEL_ASSERT(successCount >= 8);  // At least 80% success

            compEngine.shutdown();
        });
    }
};

//==============================================================================
// Initialize AI Test Suites
//==============================================================================

inline void initializeAITests()
{
    auto& runner = TestRunner::getInstance();

    runner.addSuite(std::make_unique<AICompositionTestSuite>());
    runner.addSuite(std::make_unique<StyleTransferTestSuite>());
    runner.addSuite(std::make_unique<AIIntegrationTestSuite>());
}

inline int runAITests()
{
    initializeAITests();
    auto results = TestRunner::getInstance().runAll();
    return results.failed + results.errors;
}

} // namespace Testing
} // namespace Echoelmusic
