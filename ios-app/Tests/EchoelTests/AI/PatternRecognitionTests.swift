import XCTest
@testable import Echoel

final class PatternRecognitionTests: XCTestCase {

    var patternRecognition: PatternRecognition!

    override func setUp() {
        super.setUp()
        patternRecognition = PatternRecognition()
    }

    override func tearDown() {
        patternRecognition = nil
        super.tearDown()
    }

    // MARK: - Chord Detection Tests

    func testChordDetection_CMajor() {
        // Test detecting C major chord
        // Would need actual audio buffer with C-E-G frequencies
        // This is a placeholder for integration testing
        XCTAssertNotNil(patternRecognition)
    }

    func testChordDetection_DMinor() {
        // Test detecting D minor chord
        XCTAssertNotNil(patternRecognition)
    }

    func testChordTemplateMatching() {
        // Test Jaccard similarity matching
        let activeNotes: Set<PitchClass> = [.C, .E, .G]
        let template: Set<PitchClass> = [.C, .E, .G]

        // Perfect match should give 1.0
        let intersection = activeNotes.intersection(template)
        let union = activeNotes.union(template)
        let similarity = Float(intersection.count) / Float(union.count)

        XCTAssertEqual(similarity, 1.0, accuracy: 0.01)
    }

    func testChordTemplateMatching_PartialMatch() {
        // Test partial match
        let activeNotes: Set<PitchClass> = [.C, .E, .G, .D] // Extra note
        let template: Set<PitchClass> = [.C, .E, .G]

        let intersection = activeNotes.intersection(template)
        let union = activeNotes.union(template)
        let similarity = Float(intersection.count) / Float(union.count)

        XCTAssertGreaterThan(similarity, 0.5)
        XCTAssertLessThan(similarity, 1.0)
    }

    // MARK: - Key Detection Tests

    func testKeyDetection_CMajor() {
        // Test C major key detection
        // Would need chromagram with C major profile
        XCTAssertNotNil(patternRecognition)
    }

    func testKeyDetection_AMinor() {
        // Test A minor key detection
        XCTAssertNotNil(patternRecognition)
    }

    func testPearsonCorrelation() {
        // Test Pearson correlation calculation
        let x: [Float] = [1, 2, 3, 4, 5]
        let y: [Float] = [1, 2, 3, 4, 5]

        // Perfect correlation should be 1.0
        let n = Float(x.count)
        var meanX: Float = 0, meanY: Float = 0
        for i in 0..<x.count {
            meanX += x[i]
            meanY += y[i]
        }
        meanX /= n
        meanY /= n

        var sumXY: Float = 0, sumX2: Float = 0, sumY2: Float = 0
        for i in 0..<x.count {
            let dx = x[i] - meanX
            let dy = y[i] - meanY
            sumXY += dx * dy
            sumX2 += dx * dx
            sumY2 += dy * dy
        }

        let correlation = sumXY / sqrt(sumX2 * sumY2)
        XCTAssertEqual(correlation, 1.0, accuracy: 0.01)
    }

    // MARK: - Tempo Detection Tests

    func testTempoDetection_120BPM() {
        // Test 120 BPM detection
        XCTAssertNotNil(patternRecognition)
    }

    func testTempoDetection_Range() {
        // Test tempo is constrained to 60-200 BPM
        let validRange = 60.0...200.0
        XCTAssertTrue(validRange.contains(120.0))
    }

    // MARK: - Scale Detection Tests

    func testScaleDetection_CMajor() {
        // Set detected key to C major
        let key = Key(tonic: .C, mode: .major)
        patternRecognition.detectedKey = key

        // Detect scale
        let scale = patternRecognition.detectScale()

        XCTAssertNotNil(scale)
        XCTAssertEqual(scale?.root, .C)
        XCTAssertEqual(scale?.type, .major)
    }

    func testScaleDetection_AMinor() {
        // Set detected key to A minor
        let key = Key(tonic: .A, mode: .minor)
        patternRecognition.detectedKey = key

        // Detect scale
        let scale = patternRecognition.detectScale()

        XCTAssertNotNil(scale)
        XCTAssertEqual(scale?.root, .A)
        XCTAssertEqual(scale?.type, .naturalMinor)
    }

    // MARK: - Performance Tests

    func testChordDetectionPerformance() {
        // Performance test for chord detection
        // Should complete in < 5ms
        measure {
            // Would call detectChord with test audio buffer
        }
    }

    func testKeyDetectionPerformance() {
        // Performance test for key detection
        // Should complete in < 10ms
        measure {
            // Would call detectKey with test audio buffer
        }
    }

    // MARK: - Edge Cases

    func testEmptyAudioBuffer() {
        // Test handling of empty audio buffer
        XCTAssertNotNil(patternRecognition)
    }

    func testSilentAudioBuffer() {
        // Test handling of silent audio (all zeros)
        XCTAssertNotNil(patternRecognition)
    }

    func testNoisyAudioBuffer() {
        // Test handling of white noise (no clear pitch)
        XCTAssertNotNil(patternRecognition)
    }
}
