//
//  MLModelManagerTests.swift
//  EOELTests
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  Unit tests for ML model management system
//

import XCTest
import CoreML
@testable import EOEL

@MainActor
final class MLModelManagerTests: XCTestCase {

    var manager: MLModelManager!

    override func setUp() async throws {
        try await super.setUp()
        manager = MLModelManager.shared
    }

    override func tearDown() async throws {
        manager = nil
        try await super.tearDown()
    }

    // MARK: - Initialization Tests

    func testManagerInitialization() async {
        // Manager should initialize
        XCTAssertNotNil(manager, "ML model manager should initialize")

        // Wait for models to load
        try? await Task.sleep(nanoseconds: 1_000_000_000)  // 1 second

        // Should be ready
        XCTAssertTrue(manager.isReady, "Manager should be ready after initialization")
    }

    func testAvailableModels() async {
        // Wait for discovery
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        // Available models should be array (may be empty if no models bundled)
        XCTAssertNotNil(manager.availableModels, "Available models should not be nil")
        XCTAssertTrue(manager.availableModels is [MLModelInfo], "Available models should be array")
    }

    // MARK: - Model Info Tests

    func testModelInfoCreation() {
        let modelInfo = MLModelInfo(
            id: "TestModel",
            name: "Test Model",
            type: .coreML,
            version: "1.0",
            capabilities: .inference
        )

        XCTAssertEqual(modelInfo.id, "TestModel", "Model ID should match")
        XCTAssertEqual(modelInfo.name, "Test Model", "Model name should match")
        XCTAssertEqual(modelInfo.type, .coreML, "Model type should be CoreML")
        XCTAssertEqual(modelInfo.version, "1.0", "Model version should match")
        XCTAssertTrue(modelInfo.capabilities.contains(.inference), "Model should have inference capability")
        XCTAssertFalse(modelInfo.isDownloaded, "Model should not be marked as downloaded by default")
    }

    func testModelCapabilities() {
        let inference = MLModelInfo.MLModelCapabilities.inference
        let training = MLModelInfo.MLModelCapabilities.training
        let streaming = MLModelInfo.MLModelCapabilities.streaming
        let quantized = MLModelInfo.MLModelCapabilities.quantized

        // Test individual capabilities
        XCTAssertEqual(inference.rawValue, 1 << 0, "Inference capability should have correct raw value")
        XCTAssertEqual(training.rawValue, 1 << 1, "Training capability should have correct raw value")
        XCTAssertEqual(streaming.rawValue, 1 << 2, "Streaming capability should have correct raw value")
        XCTAssertEqual(quantized.rawValue, 1 << 3, "Quantized capability should have correct raw value")

        // Test capability combination
        let combined: MLModelInfo.MLModelCapabilities = [.inference, .streaming]
        XCTAssertTrue(combined.contains(.inference), "Combined should contain inference")
        XCTAssertTrue(combined.contains(.streaming), "Combined should contain streaming")
        XCTAssertFalse(combined.contains(.training), "Combined should not contain training")
    }

    // MARK: - Error Tests

    func testMLErrorDescriptions() {
        let errors: [MLError] = [
            .modelNotFound,
            .loadFailed("Test error"),
            .typeMismatch,
            .notImplemented("Test feature"),
            .downloadFailed("Network error"),
            .inferenceError("Prediction failed")
        ]

        for error in errors {
            XCTAssertNotNil(error.errorDescription, "Error should have description: \(error)")
            XCTAssertFalse(error.errorDescription!.isEmpty, "Error description should not be empty: \(error)")
        }
    }

    func testModelNotFoundError() async {
        // Try to get non-existent model
        do {
            let _: CoreMLModelWrapper = try await manager.getModel("NonExistentModel123")
            XCTFail("Should throw error for non-existent model")
        } catch let error as MLError {
            XCTAssertEqual(error, .modelNotFound, "Should throw modelNotFound error")
        } catch {
            XCTFail("Should throw MLError: \(error)")
        }
    }

    // MARK: - Emotion Classifier Tests

    func testEmotionClassifierCreation() {
        let classifier = EmotionClassifierML()
        XCTAssertNotNil(classifier, "Emotion classifier should be created")
    }

    func testEmotionClassification() async throws {
        let classifier = EmotionClassifierML()

        // Test with calm state (high coherence)
        let calmPrediction = try await classifier.classify(
            heartRate: 65.0,
            hrv: 60.0,
            coherence: 0.8
        )

        XCTAssertEqual(calmPrediction.emotion, .calm, "Should classify as calm with high coherence")
        XCTAssertGreaterThan(calmPrediction.confidence, 0.5, "Confidence should be reasonable")

        // Test with energetic state (high heart rate)
        let energeticPrediction = try await classifier.classify(
            heartRate: 110.0,
            hrv: 40.0,
            coherence: 0.4
        )

        XCTAssertEqual(energeticPrediction.emotion, .energetic, "Should classify as energetic with high heart rate")
        XCTAssertGreaterThan(energeticPrediction.confidence, 0.5, "Confidence should be reasonable")

        // Test with relaxed state (high HRV)
        let relaxedPrediction = try await classifier.classify(
            heartRate: 60.0,
            hrv: 70.0,
            coherence: 0.5
        )

        XCTAssertEqual(relaxedPrediction.emotion, .relaxed, "Should classify as relaxed with high HRV")
        XCTAssertGreaterThan(relaxedPrediction.confidence, 0.5, "Confidence should be reasonable")
    }

    func testEmotionPredictionRuleBasedFallback() {
        // Test high coherence
        let calmPrediction = EmotionPrediction.ruleBasedClassification(
            heartRate: 70.0,
            hrv: 50.0,
            coherence: 0.8
        )
        XCTAssertEqual(calmPrediction.emotion, .calm, "High coherence should predict calm")

        // Test high heart rate
        let energeticPrediction = EmotionPrediction.ruleBasedClassification(
            heartRate: 105.0,
            hrv: 40.0,
            coherence: 0.5
        )
        XCTAssertEqual(energeticPrediction.emotion, .energetic, "High heart rate should predict energetic")

        // Test high HRV
        let relaxedPrediction = EmotionPrediction.ruleBasedClassification(
            heartRate: 65.0,
            hrv: 60.0,
            coherence: 0.4
        )
        XCTAssertEqual(relaxedPrediction.emotion, .relaxed, "High HRV should predict relaxed")

        // Test neutral
        let neutralPrediction = EmotionPrediction.ruleBasedClassification(
            heartRate: 70.0,
            hrv: 40.0,
            coherence: 0.3
        )
        XCTAssertEqual(neutralPrediction.emotion, .neutral, "Normal values should predict neutral")
    }

    // MARK: - Model Discovery Tests

    func testModelDiscovery() async {
        // Wait for discovery to complete
        try? await Task.sleep(nanoseconds: 2_000_000_000)  // 2 seconds

        let models = manager.availableModels

        // Should have discovered models (or empty array if none bundled)
        XCTAssertNotNil(models, "Model list should not be nil")

        // If models exist, verify they have required properties
        for model in models {
            XCTAssertFalse(model.id.isEmpty, "Model ID should not be empty")
            XCTAssertFalse(model.name.isEmpty, "Model name should not be empty")
            XCTAssertFalse(model.version.isEmpty, "Model version should not be empty")
        }
    }

    func testGetModelInfo() async {
        // Wait for discovery
        try? await Task.sleep(nanoseconds: 1_000_000_000)

        // Test with non-existent model
        let nonExistentInfo = manager.getModelInfo("NonExistentModel")
        XCTAssertNil(nonExistentInfo, "Should return nil for non-existent model")

        // If models exist, test with real model
        if let firstModel = manager.availableModels.first {
            let info = manager.getModelInfo(firstModel.id)
            XCTAssertNotNil(info, "Should return info for existing model")
            XCTAssertEqual(info?.id, firstModel.id, "Info should match model ID")
        }
    }

    // MARK: - Inference Tests

    func testInferenceTimeTracking() async {
        let initialTime = manager.currentInferenceTime
        XCTAssertEqual(initialTime, 0.0, "Initial inference time should be 0")

        // Note: Actual inference would update this value
        // Testing the property exists and is accessible
        manager.currentInferenceTime = 0.123
        XCTAssertEqual(manager.currentInferenceTime, 0.123, "Inference time should be updatable")
    }

    // MARK: - Performance Tests

    func testModelInfoCreationPerformance() {
        measure {
            for i in 0..<1000 {
                _ = MLModelInfo(
                    id: "Model\(i)",
                    name: "Test Model \(i)",
                    type: .coreML,
                    version: "1.0",
                    capabilities: .inference
                )
            }
        }
    }

    func testRuleBasedClassificationPerformance() {
        measure {
            for _ in 0..<1000 {
                _ = EmotionPrediction.ruleBasedClassification(
                    heartRate: 75.0,
                    hrv: 50.0,
                    coherence: 0.6
                )
            }
        }
    }

    // MARK: - Thread Safety Tests

    func testConcurrentAccess() async {
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<10 {
                group.addTask { @MainActor in
                    _ = self.manager.availableModels
                    _ = self.manager.isReady
                    _ = self.manager.currentInferenceTime
                }
            }
        }

        // Should not crash with concurrent access
        XCTAssertNotNil(manager, "Manager should still be valid after concurrent access")
    }
}
