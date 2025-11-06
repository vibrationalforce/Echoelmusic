import XCTest
@testable import Echoelmusic

/// Tests for face tracking system (ARKit + Vision fallback)
final class FaceTrackingTests: XCTestCase {

    // MARK: - HardwareCapability Face Tracking Tests

    func testHardwareCapabilityReportsFaceTrackingMethods() {
        let capability = HardwareCapability.shared

        // Vision should ALWAYS be available on iOS 16+
        XCTAssertTrue(
            capability.canUseVisionFaceDetection,
            "Vision face detection should be available on all iOS 16+ devices"
        )

        // At least one method should be available
        XCTAssertTrue(
            capability.canUseAnyFaceTracking,
            "At least one face tracking method should be available"
        )

        // Recommended method should not be none
        XCTAssertNotEqual(
            capability.recommendedFaceTrackingMethod,
            .none,
            "Should have a recommended face tracking method"
        )
    }

    func testFaceTrackingMethodProperties() {
        // ARKit properties
        XCTAssertEqual(FaceTrackingMethod.arkit.blendShapeCount, 52)
        XCTAssertEqual(FaceTrackingMethod.arkit.accuracy, 0.95, accuracy: 0.01)
        XCTAssertTrue(FaceTrackingMethod.arkit.deviceCoverage.contains("40"))

        // Vision properties
        XCTAssertEqual(FaceTrackingMethod.vision.blendShapeCount, 13)
        XCTAssertEqual(FaceTrackingMethod.vision.accuracy, 0.85, accuracy: 0.01)
        XCTAssertTrue(FaceTrackingMethod.vision.deviceCoverage.contains("90"))

        // None properties
        XCTAssertEqual(FaceTrackingMethod.none.blendShapeCount, 0)
        XCTAssertEqual(FaceTrackingMethod.none.accuracy, 0.0)
    }

    func testRecommendedMethodLogic() {
        let capability = HardwareCapability.shared

        // If ARKit is available, it should be recommended
        if capability.canUseFaceTracking {
            XCTAssertEqual(
                capability.recommendedFaceTrackingMethod,
                .arkit,
                "ARKit should be recommended when available"
            )
        } else {
            // Otherwise Vision should be recommended
            XCTAssertEqual(
                capability.recommendedFaceTrackingMethod,
                .vision,
                "Vision should be recommended when ARKit not available"
            )
        }
    }

    // MARK: - FaceExpression Tests

    func testFaceExpressionInitialization() {
        let expression = FaceExpression()

        // Default values should be 0
        XCTAssertEqual(expression.jawOpen, 0.0)
        XCTAssertEqual(expression.mouthSmileLeft, 0.0)
        XCTAssertEqual(expression.mouthSmileRight, 0.0)
        XCTAssertEqual(expression.browInnerUp, 0.0)
        XCTAssertEqual(expression.eyeBlinkLeft, 0.0)
        XCTAssertEqual(expression.eyeBlinkRight, 0.0)
    }

    func testFaceExpressionComputedProperties() {
        let expression = FaceExpression(
            mouthSmileLeft: 0.8,
            mouthSmileRight: 0.6,
            browInnerUp: 0.5,
            browOuterUpLeft: 0.7,
            browOuterUpRight: 0.3,
            eyeBlinkLeft: 0.9,
            eyeBlinkRight: 0.1,
            eyeWideLeft: 0.4,
            eyeWideRight: 0.6
        )

        // Test smile (average of left and right)
        XCTAssertEqual(expression.smile, 0.7, accuracy: 0.01)

        // Test brow raise (average of three)
        XCTAssertEqual(expression.browRaise, 0.5, accuracy: 0.01)

        // Test eye blink (average of left and right)
        XCTAssertEqual(expression.eyeBlink, 0.5, accuracy: 0.01)

        // Test eye wide (average of left and right)
        XCTAssertEqual(expression.eyeWide, 0.5, accuracy: 0.01)
    }

    func testFaceExpressionEquality() {
        let expression1 = FaceExpression(jawOpen: 0.5, mouthSmileLeft: 0.3)
        let expression2 = FaceExpression(jawOpen: 0.5, mouthSmileLeft: 0.3)
        let expression3 = FaceExpression(jawOpen: 0.6, mouthSmileLeft: 0.3)

        XCTAssertEqual(expression1, expression2)
        XCTAssertNotEqual(expression1, expression3)
    }

    // MARK: - TrackingStatistics Tests

    func testTrackingStatisticsHealthCheck() {
        // Healthy tracking
        let healthyStats = TrackingStatistics(
            isTracking: true,
            trackingQuality: 0.8,
            blendShapeCount: 30,
            hasHeadTransform: true
        )
        XCTAssertTrue(healthyStats.isHealthy)

        // Unhealthy: not tracking
        let notTrackingStats = TrackingStatistics(
            isTracking: false,
            trackingQuality: 0.8,
            blendShapeCount: 30,
            hasHeadTransform: true
        )
        XCTAssertFalse(notTrackingStats.isHealthy)

        // Unhealthy: low quality
        let lowQualityStats = TrackingStatistics(
            isTracking: true,
            trackingQuality: 0.3,
            blendShapeCount: 30,
            hasHeadTransform: true
        )
        XCTAssertFalse(lowQualityStats.isHealthy)

        // Unhealthy: few blend shapes
        let fewShapesStats = TrackingStatistics(
            isTracking: true,
            trackingQuality: 0.8,
            blendShapeCount: 10,
            hasHeadTransform: true
        )
        XCTAssertFalse(fewShapesStats.isHealthy)
    }

    // MARK: - Integration Tests

    func testFaceTrackingCoverageIncrease() {
        // This test documents the improvement in device coverage
        let capability = HardwareCapability.shared

        // OLD: Only TrueDepth devices (~40%)
        let oldCoverage = capability.canUseFaceTracking

        // NEW: TrueDepth OR Vision (~90%)
        let newCoverage = capability.canUseAnyFaceTracking

        // New coverage should be greater than or equal to old coverage
        if oldCoverage {
            XCTAssertTrue(newCoverage, "New method should cover at least what old method covered")
        }

        // Document the improvement
        print("""
        📊 Face Tracking Coverage:
        - ARKit Only: \(oldCoverage ? "Available" : "Not Available") (~40% devices)
        - ARKit + Vision: \(newCoverage ? "Available" : "Not Available") (~90% devices)
        - Improvement: \(newCoverage && !oldCoverage ? "+50% coverage" : "Maintained")
        """)
    }

    func testCompatibilityMatrix() {
        // Test that compatibility matrix matches documentation
        let capability = HardwareCapability.shared

        let deviceTier = capability.performanceTier

        // All devices should have SOME face tracking method
        XCTAssertTrue(
            capability.canUseAnyFaceTracking,
            "All iOS 16+ devices should support at least Vision face tracking"
        )

        // Document which method is available
        if capability.canUseFaceTracking {
            print("✅ This device supports ARKit TrueDepth tracking (52 blend shapes)")
        } else if capability.canUseVisionFaceDetection {
            print("✅ This device supports Vision 2D tracking (13 blend shapes)")
        }

        print("   Performance Tier: \(deviceTier)")
        print("   Recommended Method: \(capability.recommendedFaceTrackingMethod.rawValue)")
    }

    // MARK: - Graceful Degradation Tests

    func testGracefulDegradationStrategy() {
        let capability = HardwareCapability.shared

        // Verify fallback chain works
        var trackingMethod: String

        if capability.canUseFaceTracking {
            trackingMethod = "ARKit TrueDepth (Best)"
        } else if capability.canUseVisionFaceDetection {
            trackingMethod = "Vision 2D (Good)"
        } else {
            trackingMethod = "Manual Controls (Fallback)"
        }

        // Should never reach "Manual Controls" on iOS 16+
        XCTAssertNotEqual(trackingMethod, "Manual Controls (Fallback)")

        print("🎯 Selected Tracking Method: \(trackingMethod)")
    }

    // MARK: - Performance Expectations

    func testPerformanceExpectations() {
        let capability = HardwareCapability.shared

        // Different methods have different performance characteristics
        switch capability.recommendedFaceTrackingMethod {
        case .arkit:
            // ARKit: 60 Hz, 52 blend shapes, 95% accuracy
            print("""
            ARKit Performance Expectations:
            - Frame Rate: 60 Hz
            - Blend Shapes: 52
            - Accuracy: 95%
            - CPU Usage: ~10-15%
            """)

        case .vision:
            // Vision: 30 Hz, ~13 blend shapes, 85% accuracy
            print("""
            Vision Performance Expectations:
            - Frame Rate: 30 Hz
            - Blend Shapes: ~13 (approximate)
            - Accuracy: 85%
            - CPU Usage: ~5-8%
            """)

        case .none:
            XCTFail("Should have a tracking method on iOS 16+")
        }
    }
}
