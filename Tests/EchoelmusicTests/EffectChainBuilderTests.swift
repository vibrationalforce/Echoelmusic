import XCTest
@testable import Echoelmusic

/// Comprehensive Unit Tests for EffectChainBuilder
/// Tests effect chains, routing, processing, parameter control
@MainActor
final class EffectChainBuilderTests: XCTestCase {

    var effectChainBuilder: EffectChainBuilder!

    override func setUp() async throws {
        await MainActor.run {
            effectChainBuilder = EffectChainBuilder()
        }
    }

    override func tearDown() async throws {
        await MainActor.run {
            effectChainBuilder = nil
        }
    }

    // MARK: - Initialization Tests

    func testEffectChainBuilderInitialization() async throws {
        await MainActor.run {
            XCTAssertEqual(effectChainBuilder.chains.count, 0)
            XCTAssertGreaterThan(effectChainBuilder.effectLibrary.count, 0)
        }
    }

    func testEffectLibrary() async throws {
        await MainActor.run {
            // Should have all 18 effect types
            XCTAssertGreaterThanOrEqual(effectChainBuilder.effectLibrary.count, 18)

            let effectNames = effectChainBuilder.effectLibrary.map { $0.name }
            XCTAssertTrue(effectNames.contains("Reverb"))
            XCTAssertTrue(effectNames.contains("Delay"))
            XCTAssertTrue(effectNames.contains("Chorus"))
            XCTAssertTrue(effectNames.contains("Compressor"))
            XCTAssertTrue(effectNames.contains("Distortion"))
        }
    }

    // MARK: - Chain Creation Tests

    func testCreateChain() async throws {
        await MainActor.run {
            let chain = effectChainBuilder.createChain(name: "Vocal Chain")

            XCTAssertEqual(effectChainBuilder.chains.count, 1)
            XCTAssertEqual(chain.name, "Vocal Chain")
            XCTAssertEqual(chain.effects.count, 0)
            XCTAssertEqual(chain.routing, .series)
            XCTAssertEqual(chain.wetDryMix, 1.0)
        }
    }

    func testDeleteChain() async throws {
        await MainActor.run {
            let chain = effectChainBuilder.createChain(name: "Test Chain")
            XCTAssertEqual(effectChainBuilder.chains.count, 1)

            effectChainBuilder.deleteChain(id: chain.id)

            XCTAssertEqual(effectChainBuilder.chains.count, 0)
        }
    }

    func testDuplicateChain() async throws {
        await MainActor.run {
            let chain = effectChainBuilder.createChain(name: "Original Chain")
            effectChainBuilder.addEffect(
                to: chain.id,
                effect: .reverb(EffectChainBuilder.ReverbParams(
                    roomSize: 0.7,
                    damping: 0.5,
                    wetLevel: 0.3,
                    dryLevel: 0.7,
                    width: 1.0
                ))
            )

            effectChainBuilder.duplicateChain(id: chain.id)

            XCTAssertEqual(effectChainBuilder.chains.count, 2)
            XCTAssertTrue(effectChainBuilder.chains[1].name.contains("Copy"))
            XCTAssertEqual(effectChainBuilder.chains[1].effects.count, effectChainBuilder.chains[0].effects.count)
        }
    }

    // MARK: - Effect Management Tests

    func testAddEffect() async throws {
        await MainActor.run {
            let chain = effectChainBuilder.createChain(name: "Test Chain")

            let reverbParams = EffectChainBuilder.ReverbParams(
                roomSize: 0.8,
                damping: 0.4,
                wetLevel: 0.5,
                dryLevel: 0.5,
                width: 1.0
            )

            effectChainBuilder.addEffect(to: chain.id, effect: .reverb(reverbParams))

            XCTAssertEqual(effectChainBuilder.chains[0].effects.count, 1)
            XCTAssertTrue(effectChainBuilder.chains[0].effects[0].enabled)
        }
    }

    func testRemoveEffect() async throws {
        await MainActor.run {
            let chain = effectChainBuilder.createChain(name: "Test Chain")

            effectChainBuilder.addEffect(
                to: chain.id,
                effect: .delay(EffectChainBuilder.DelayParams(
                    delayTime: 0.5,
                    feedback: 0.3,
                    wetLevel: 0.5,
                    dryLevel: 0.5,
                    syncToTempo: false,
                    tempoMultiplier: .quarter
                ))
            )

            XCTAssertEqual(effectChainBuilder.chains[0].effects.count, 1)

            let effectId = effectChainBuilder.chains[0].effects[0].id
            effectChainBuilder.removeEffect(from: chain.id, effectId: effectId)

            XCTAssertEqual(effectChainBuilder.chains[0].effects.count, 0)
        }
    }

    func testReorderEffects() async throws {
        await MainActor.run {
            let chain = effectChainBuilder.createChain(name: "Test Chain")

            // Add multiple effects
            effectChainBuilder.addEffect(to: chain.id, effect: .compressor(EffectChainBuilder.CompressorParams(threshold: -20, ratio: 4.0, attack: 0.01, release: 0.1, makeupGain: 0)))
            effectChainBuilder.addEffect(to: chain.id, effect: .eq(EffectChainBuilder.EQParams(bands: [])))
            effectChainBuilder.addEffect(to: chain.id, effect: .reverb(EffectChainBuilder.ReverbParams(roomSize: 0.5, damping: 0.5, wetLevel: 0.3, dryLevel: 0.7, width: 1.0)))

            XCTAssertEqual(effectChainBuilder.chains[0].effects.count, 3)

            // Reorder: move first effect to last
            effectChainBuilder.reorderEffects(in: chain.id, from: 0, to: 2)

            // Verify order changed
            if case .reverb = effectChainBuilder.chains[0].effects[2].effect {
                // Effect moved successfully
            } else {
                XCTFail("Effect reordering failed")
            }
        }
    }

    func testToggleEffect() async throws {
        await MainActor.run {
            let chain = effectChainBuilder.createChain(name: "Test Chain")

            effectChainBuilder.addEffect(
                to: chain.id,
                effect: .chorus(EffectChainBuilder.ChorusParams(
                    rate: 1.0,
                    depth: 0.5,
                    feedback: 0.2,
                    wetLevel: 0.5,
                    dryLevel: 0.5
                ))
            )

            XCTAssertTrue(effectChainBuilder.chains[0].effects[0].enabled)

            let effectId = effectChainBuilder.chains[0].effects[0].id
            effectChainBuilder.toggleEffect(chainId: chain.id, effectId: effectId)

            XCTAssertFalse(effectChainBuilder.chains[0].effects[0].enabled)
        }
    }

    // MARK: - Routing Tests

    func testSeriesRouting() async throws {
        await MainActor.run {
            let chain = effectChainBuilder.createChain(name: "Series Chain")

            effectChainBuilder.setRouting(chainId: chain.id, routing: .series)

            XCTAssertEqual(effectChainBuilder.chains[0].routing, .series)
        }
    }

    func testParallelRouting() async throws {
        await MainActor.run {
            let chain = effectChainBuilder.createChain(name: "Parallel Chain")

            effectChainBuilder.setRouting(chainId: chain.id, routing: .parallel)

            XCTAssertEqual(effectChainBuilder.chains[0].routing, .parallel)
        }
    }

    func testSplitterRouting() async throws {
        await MainActor.run {
            let chain = effectChainBuilder.createChain(name: "Splitter Chain")

            effectChainBuilder.setRouting(chainId: chain.id, routing: .splitter(splitFrequency: 1000.0))

            if case .splitter(let frequency) = effectChainBuilder.chains[0].routing {
                XCTAssertEqual(frequency, 1000.0)
            } else {
                XCTFail("Routing should be splitter")
            }
        }
    }

    // MARK: - Wet/Dry Mix Tests

    func testWetDryMix() async throws {
        await MainActor.run {
            let chain = effectChainBuilder.createChain(name: "Test Chain")

            effectChainBuilder.setWetDryMix(chainId: chain.id, mix: 0.7)

            XCTAssertEqual(effectChainBuilder.chains[0].wetDryMix, 0.7)
        }
    }

    // MARK: - Effect Type Tests

    func testReverbEffect() async throws {
        await MainActor.run {
            let chain = effectChainBuilder.createChain(name: "Reverb Chain")

            let params = EffectChainBuilder.ReverbParams(
                roomSize: 0.9,
                damping: 0.3,
                wetLevel: 0.4,
                dryLevel: 0.6,
                width: 0.8
            )

            effectChainBuilder.addEffect(to: chain.id, effect: .reverb(params))

            if case .reverb(let reverbParams) = effectChainBuilder.chains[0].effects[0].effect {
                XCTAssertEqual(reverbParams.roomSize, 0.9)
                XCTAssertEqual(reverbParams.damping, 0.3)
            } else {
                XCTFail("Effect should be reverb")
            }
        }
    }

    func testDelayEffect() async throws {
        await MainActor.run {
            let chain = effectChainBuilder.createChain(name: "Delay Chain")

            let params = EffectChainBuilder.DelayParams(
                delayTime: 0.375,
                feedback: 0.5,
                wetLevel: 0.5,
                dryLevel: 0.5,
                syncToTempo: true,
                tempoMultiplier: .eighth
            )

            effectChainBuilder.addEffect(to: chain.id, effect: .delay(params))

            if case .delay(let delayParams) = effectChainBuilder.chains[0].effects[0].effect {
                XCTAssertEqual(delayParams.delayTime, 0.375)
                XCTAssertTrue(delayParams.syncToTempo)
            } else {
                XCTFail("Effect should be delay")
            }
        }
    }

    func testCompressorEffect() async throws {
        await MainActor.run {
            let chain = effectChainBuilder.createChain(name: "Compressor Chain")

            let params = EffectChainBuilder.CompressorParams(
                threshold: -24.0,
                ratio: 6.0,
                attack: 0.005,
                release: 0.15,
                makeupGain: 6.0
            )

            effectChainBuilder.addEffect(to: chain.id, effect: .compressor(params))

            if case .compressor(let compParams) = effectChainBuilder.chains[0].effects[0].effect {
                XCTAssertEqual(compParams.threshold, -24.0)
                XCTAssertEqual(compParams.ratio, 6.0)
            } else {
                XCTFail("Effect should be compressor")
            }
        }
    }

    func testDistortionEffect() async throws {
        await MainActor.run {
            let chain = effectChainBuilder.createChain(name: "Distortion Chain")

            let params = EffectChainBuilder.DistortionParams(
                drive: 30.0,
                tone: 0.6,
                wetLevel: 1.0,
                dryLevel: 0.0,
                type: .overdrive
            )

            effectChainBuilder.addEffect(to: chain.id, effect: .distortion(params))

            if case .distortion(let distParams) = effectChainBuilder.chains[0].effects[0].effect {
                XCTAssertEqual(distParams.drive, 30.0)
                XCTAssertEqual(distParams.type, .overdrive)
            } else {
                XCTFail("Effect should be distortion")
            }
        }
    }

    func testEQEffect() async throws {
        await MainActor.run {
            let chain = effectChainBuilder.createChain(name: "EQ Chain")

            let bands = [
                EffectChainBuilder.EQParams.Band(frequency: 100, gain: -3, q: 1.0, type: .highpass),
                EffectChainBuilder.EQParams.Band(frequency: 800, gain: 2, q: 1.5, type: .peak),
                EffectChainBuilder.EQParams.Band(frequency: 5000, gain: 1.5, q: 1.0, type: .highshelf)
            ]

            let params = EffectChainBuilder.EQParams(bands: bands)

            effectChainBuilder.addEffect(to: chain.id, effect: .eq(params))

            if case .eq(let eqParams) = effectChainBuilder.chains[0].effects[0].effect {
                XCTAssertEqual(eqParams.bands.count, 3)
                XCTAssertEqual(eqParams.bands[0].frequency, 100)
            } else {
                XCTFail("Effect should be EQ")
            }
        }
    }

    // MARK: - Audio Processing Tests

    func testProcessAudio() async throws {
        await MainActor.run {
            let chain = effectChainBuilder.createChain(name: "Test Chain")

            // Add simple effect
            effectChainBuilder.addEffect(
                to: chain.id,
                effect: .reverb(EffectChainBuilder.ReverbParams(
                    roomSize: 0.5,
                    damping: 0.5,
                    wetLevel: 0.3,
                    dryLevel: 0.7,
                    width: 1.0
                ))
            )

            // Create test audio buffer (1 second of sine wave at 440Hz)
            let sampleRate = 44100.0
            let frequency = 440.0
            let duration = 1.0
            let frameCount = Int(sampleRate * duration)

            var inputBuffer: [Float] = []
            for i in 0..<frameCount {
                let time = Double(i) / sampleRate
                let sample = sin(2.0 * .pi * frequency * time)
                inputBuffer.append(Float(sample))
            }

            let outputBuffer = effectChainBuilder.chains[0].process(buffer: inputBuffer, sampleRate: sampleRate)

            XCTAssertEqual(outputBuffer.count, inputBuffer.count)

            // Output should be different from input (reverb applied)
            let inputRMS = sqrt(inputBuffer.map { $0 * $0 }.reduce(0, +) / Float(inputBuffer.count))
            let outputRMS = sqrt(outputBuffer.map { $0 * $0 }.reduce(0, +) / Float(outputBuffer.count))

            // RMS should be different due to reverb
            XCTAssertNotEqual(inputRMS, outputRMS, accuracy: 0.01)
        }
    }

    func testBypassedEffectDoesNotProcess() async throws {
        await MainActor.run {
            let chain = effectChainBuilder.createChain(name: "Test Chain")

            effectChainBuilder.addEffect(
                to: chain.id,
                effect: .distortion(EffectChainBuilder.DistortionParams(
                    drive: 50.0,
                    tone: 0.5,
                    wetLevel: 1.0,
                    dryLevel: 0.0,
                    type: .fuzz
                ))
            )

            // Disable effect
            let effectId = effectChainBuilder.chains[0].effects[0].id
            effectChainBuilder.toggleEffect(chainId: chain.id, effectId: effectId)

            // Create test buffer
            let inputBuffer: [Float] = Array(repeating: 0.5, count: 1024)
            let outputBuffer = effectChainBuilder.chains[0].process(buffer: inputBuffer, sampleRate: 44100.0)

            // Output should equal input (bypassed)
            XCTAssertEqual(outputBuffer, inputBuffer)
        }
    }

    func testSeriesProcessing() async throws {
        await MainActor.run {
            let chain = effectChainBuilder.createChain(name: "Series Chain")

            effectChainBuilder.setRouting(chainId: chain.id, routing: .series)

            // Add compressor -> EQ -> reverb (classic series chain)
            effectChainBuilder.addEffect(to: chain.id, effect: .compressor(EffectChainBuilder.CompressorParams(threshold: -20, ratio: 4.0, attack: 0.01, release: 0.1, makeupGain: 0)))
            effectChainBuilder.addEffect(to: chain.id, effect: .eq(EffectChainBuilder.EQParams(bands: [])))
            effectChainBuilder.addEffect(to: chain.id, effect: .reverb(EffectChainBuilder.ReverbParams(roomSize: 0.5, damping: 0.5, wetLevel: 0.3, dryLevel: 0.7, width: 1.0)))

            let inputBuffer: [Float] = Array(repeating: 0.5, count: 512)
            let outputBuffer = effectChainBuilder.chains[0].process(buffer: inputBuffer, sampleRate: 44100.0)

            XCTAssertEqual(outputBuffer.count, inputBuffer.count)
        }
    }

    // MARK: - Preset Tests

    func testSaveChainAsPreset() async throws {
        await MainActor.run {
            let chain = effectChainBuilder.createChain(name: "Vocal Processing")

            effectChainBuilder.addEffect(to: chain.id, effect: .compressor(EffectChainBuilder.CompressorParams(threshold: -18, ratio: 3.0, attack: 0.01, release: 0.1, makeupGain: 3)))
            effectChainBuilder.addEffect(to: chain.id, effect: .eq(EffectChainBuilder.EQParams(bands: [])))
            effectChainBuilder.addEffect(to: chain.id, effect: .reverb(EffectChainBuilder.ReverbParams(roomSize: 0.3, damping: 0.6, wetLevel: 0.2, dryLevel: 0.8, width: 1.0)))

            let preset = effectChainBuilder.saveChainAsPreset(chainId: chain.id, name: "Vocal Preset")

            XCTAssertNotNil(preset)
            XCTAssertEqual(preset?.name, "Vocal Preset")
        }
    }

    func testLoadPreset() async throws {
        await MainActor.run {
            // Create and save preset
            let chain = effectChainBuilder.createChain(name: "Original")
            effectChainBuilder.addEffect(to: chain.id, effect: .delay(EffectChainBuilder.DelayParams(delayTime: 0.5, feedback: 0.4, wetLevel: 0.5, dryLevel: 0.5, syncToTempo: false, tempoMultiplier: .quarter)))

            let preset = effectChainBuilder.saveChainAsPreset(chainId: chain.id, name: "Delay Preset")

            // Load preset into new chain
            let newChain = effectChainBuilder.createChain(name: "New Chain")
            effectChainBuilder.loadPreset(chainId: newChain.id, preset: preset!)

            XCTAssertEqual(effectChainBuilder.chains[1].effects.count, 1)
        }
    }

    // MARK: - Chain Ownership Tests

    func testChainUserOwnership() async throws {
        await MainActor.run {
            let chain = effectChainBuilder.createChain(name: "User Chain")

            XCTAssertEqual(chain.createdBy, "User")
        }
    }

    // MARK: - Performance Tests

    func testPerformanceSingleEffect() throws {
        measure {
            Task { @MainActor in
                let builder = EffectChainBuilder()
                let chain = builder.createChain(name: "Test")

                builder.addEffect(to: chain.id, effect: .reverb(EffectChainBuilder.ReverbParams(roomSize: 0.5, damping: 0.5, wetLevel: 0.5, dryLevel: 0.5, width: 1.0)))

                let buffer: [Float] = Array(repeating: 0.5, count: 44100) // 1 second
                _ = builder.chains[0].process(buffer: buffer, sampleRate: 44100.0)
            }
        }
    }

    func testPerformanceComplexChain() throws {
        measure {
            Task { @MainActor in
                let builder = EffectChainBuilder()
                let chain = builder.createChain(name: "Complex")

                // Add multiple effects
                builder.addEffect(to: chain.id, effect: .compressor(EffectChainBuilder.CompressorParams(threshold: -20, ratio: 4.0, attack: 0.01, release: 0.1, makeupGain: 0)))
                builder.addEffect(to: chain.id, effect: .eq(EffectChainBuilder.EQParams(bands: [])))
                builder.addEffect(to: chain.id, effect: .distortion(EffectChainBuilder.DistortionParams(drive: 20, tone: 0.5, wetLevel: 0.5, dryLevel: 0.5, type: .overdrive)))
                builder.addEffect(to: chain.id, effect: .chorus(EffectChainBuilder.ChorusParams(rate: 1.0, depth: 0.5, feedback: 0.2, wetLevel: 0.3, dryLevel: 0.7)))
                builder.addEffect(to: chain.id, effect: .reverb(EffectChainBuilder.ReverbParams(roomSize: 0.5, damping: 0.5, wetLevel: 0.3, dryLevel: 0.7, width: 1.0)))

                let buffer: [Float] = Array(repeating: 0.5, count: 44100)
                _ = builder.chains[0].process(buffer: buffer, sampleRate: 44100.0)
            }
        }
    }
}
