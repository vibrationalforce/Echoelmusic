import XCTest
@testable import Echoelmusic

/// Performance baseline tests for the 2026 expansion engines.
///
/// Validates that core type operations (enum iteration, mapping, serialization)
/// meet performance expectations for the real-time bio-reactive pipeline.
///
/// Key performance targets from CLAUDE.md:
/// - Control Loop: 60 Hz (16.6ms budget)
/// - Audio Latency: <10ms
/// - CPU Usage: <30%
/// - Memory: <200 MB
@MainActor
final class PerformanceBaselineTests: XCTestCase {

    // MARK: - MindTask Performance

    /// MindTask enum has 9 cases — iterating all cases must be fast
    /// since the control loop may inspect tasks each tick.
    func testMindTaskIterationPerformance() {
        measure {
            for _ in 0..<10_000 {
                var count = 0
                for task in MindTask.allCases {
                    _ = task.rawValue
                    count += 1
                }
                XCTAssertEqual(count, 9)
            }
        }
    }

    // MARK: - MindMood Mapping Performance

    /// MindMood.from(coherence:) is called every bio update (~60Hz).
    /// Must be O(1) switch-based mapping with no allocation.
    func testMindMoodFromCoherencePerformance() {
        measure {
            for _ in 0..<100_000 {
                let coherence = Float.random(in: 0...1)
                let mood = MindMood.from(coherence: coherence)
                _ = mood.rawValue
            }
        }
    }

    /// Verify MindMood.from(coherence:) returns correct mappings
    /// across the full coherence range.
    func testMindMoodMappingCorrectness() {
        XCTAssertEqual(MindMood.from(coherence: 0.1), .stressed)
        XCTAssertEqual(MindMood.from(coherence: 0.3), .calm)
        XCTAssertEqual(MindMood.from(coherence: 0.5), .focused)
        XCTAssertEqual(MindMood.from(coherence: 0.7), .creative)
        XCTAssertEqual(MindMood.from(coherence: 0.9), .energetic)
    }

    // MARK: - WorldBiome Selection Performance

    /// WorldBiome.from(coherence:energy:) is called at 1Hz minimum
    /// by EchoelWorldEngine. Must be O(1) switch dispatch.
    func testWorldBiomeSelectionPerformance() {
        measure {
            for _ in 0..<100_000 {
                let coherence = Float.random(in: 0...1)
                let energy = Float.random(in: 0...1)
                let biome = WorldBiome.from(coherence: coherence, energy: energy)
                _ = biome.rawValue
            }
        }
    }

    /// Verify biome selection returns expected biomes for known input ranges.
    func testWorldBiomeSelectionCorrectness() {
        XCTAssertEqual(WorldBiome.from(coherence: 0.9, energy: 0.5), .mountain)
        XCTAssertEqual(WorldBiome.from(coherence: 0.7, energy: 0.6), .crystal)
        XCTAssertEqual(WorldBiome.from(coherence: 0.7, energy: 0.3), .garden)
        XCTAssertEqual(WorldBiome.from(coherence: 0.5, energy: 0.7), .nebula)
        XCTAssertEqual(WorldBiome.from(coherence: 0.5, energy: 0.3), .forest)
        XCTAssertEqual(WorldBiome.from(coherence: 0.2, energy: 0.8), .ocean)
        XCTAssertEqual(WorldBiome.from(coherence: 0.2, energy: 0.2), .desert)
    }

    // MARK: - WorldBiome Color Lookup Performance

    /// Color lookups happen every render frame. Must be pure switch dispatch
    /// with no heap allocation.
    func testWorldBiomeColorLookupPerformance() {
        let biomes = WorldBiome.allCases
        measure {
            for _ in 0..<100_000 {
                for biome in biomes {
                    let color = biome.primaryColor
                    _ = color.r + color.g + color.b
                }
            }
        }
    }

    // MARK: - OSCValue Type Switching Performance

    /// OSC message parsing involves switching on OSCValue variants.
    /// At 30Hz broadcast rate with ~11 values per bundle, this must be fast.
    func testOSCValueTypeSwitchingPerformance() {
        let values: [OSCValue] = [
            .int32(42),
            .float32(0.85),
            .string("test"),
            .blob(Data([0x01, 0x02, 0x03, 0x04])),
            .int64(1234567890),
            .double64(3.14159),
            .bool(true),
            .bool(false),
            .timetag(UInt64(Date().timeIntervalSince1970)),
            .nilValue,
        ]

        measure {
            for _ in 0..<10_000 {
                for value in values {
                    _ = value.floatValue
                    _ = value.stringValue
                    _ = value.intValue
                }
            }
        }
    }

    // MARK: - OSCMessage Serialization Performance

    /// OSC messages are encoded at up to 30Hz broadcast rate.
    /// Encoding must stay well within the 33ms frame budget.
    func testOSCMessageSerializationPerformance() {
        measure {
            for _ in 0..<10_000 {
                let msg = OSCMessage(
                    address: "/echoelmusic/bio/coherence",
                    arguments: [
                        .float32(0.85),
                        .int32(72),
                        .string("focused"),
                        .float32(0.6),
                    ]
                )
                let data = msg.encode()
                XCTAssertGreaterThan(data.count, 0)
            }
        }
    }

    /// OSC message round-trip: encode then decode must preserve data.
    func testOSCMessageRoundTripPerformance() {
        let original = OSCMessage(
            address: "/echoelmusic/bio/coherence",
            arguments: [.float32(0.85), .int32(72), .string("test")]
        )

        measure {
            for _ in 0..<10_000 {
                let encoded = original.encode()
                let decoded = OSCMessage.decode(from: encoded)
                XCTAssertNotNil(decoded)
            }
        }
    }

    // MARK: - AvatarStyle Iteration Performance

    /// AvatarStyle has 7 cases. Style switching is UI-driven but
    /// iteration happens during rendering setup.
    func testAvatarStyleIterationPerformance() {
        measure {
            for _ in 0..<100_000 {
                var count = 0
                for style in AvatarStyle.allCases {
                    _ = style.rawValue
                    _ = style.description
                    count += 1
                }
                XCTAssertEqual(count, 7)
            }
        }
    }

    // MARK: - EchoelLanguage Iteration Performance

    /// EchoelLanguage has 23 cases. Enumerated during language picker
    /// population and translation pair availability checks.
    func testEchoelLanguageIterationPerformance() {
        measure {
            for _ in 0..<10_000 {
                var count = 0
                for lang in EchoelLanguage.allCases {
                    _ = lang.rawValue
                    _ = lang.displayName
                    _ = lang.isRTL
                    count += 1
                }
                XCTAssertEqual(count, 23)
            }
        }
    }

    // MARK: - FacialExpression Default Init Performance

    /// FacialExpression is created at 60fps from ARKit blendshapes.
    /// Default init must have zero heap allocation — pure value type.
    func testFacialExpressionDefaultInitPerformance() {
        measure {
            for _ in 0..<100_000 {
                let expr = FacialExpression()
                XCTAssertFalse(expr.isSmiling)
                XCTAssertFalse(expr.isMouthOpen)
                XCTAssertEqual(expr.emotionalValence, 0.0)
            }
        }
    }

    /// Verify FacialExpression.neutral is equivalent to default init.
    func testFacialExpressionNeutralIsDefault() {
        let neutral = FacialExpression.neutral
        let defaultExpr = FacialExpression()

        XCTAssertEqual(neutral.eyeBlinkLeft, defaultExpr.eyeBlinkLeft)
        XCTAssertEqual(neutral.jawOpen, defaultExpr.jawOpen)
        XCTAssertEqual(neutral.mouthSmileLeft, defaultExpr.mouthSmileLeft)
        XCTAssertEqual(neutral.emotionalValence, defaultExpr.emotionalValence)
        XCTAssertFalse(neutral.isSmiling)
        XCTAssertFalse(neutral.isMouthOpen)
    }
}
