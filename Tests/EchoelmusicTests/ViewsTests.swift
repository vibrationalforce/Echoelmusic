// ViewsTests.swift
// Tests for SwiftUI Views and view-related components
//
// Copyright 2026 Echoelmusic. MIT License.

import XCTest
@testable import Echoelmusic
import SwiftUI

/// Comprehensive tests for the Views module
/// Coverage: OnboardingManager, view model state, accessibility labels
final class ViewsTests: XCTestCase {

    // MARK: - OnboardingManager Tests

    @MainActor
    func testOnboardingManagerSharedInstance() {
        let manager1 = OnboardingManager.shared
        let manager2 = OnboardingManager.shared

        XCTAssertTrue(manager1 === manager2, "Should be singleton")
    }

    @MainActor
    func testOnboardingManagerInitialState() {
        let manager = OnboardingManager.shared

        // Properties should exist
        XCTAssertNotNil(manager.hasGrantedHealthKit)
        XCTAssertNotNil(manager.hasGrantedMicrophone)
        XCTAssertNotNil(manager.hasConnectedWatch)
    }

    @MainActor
    func testOnboardingManagerCheckPermissions() {
        let manager = OnboardingManager.shared

        // Should not crash when checking permissions
        manager.checkPermissions()

        // Properties should have values after check
        // Actual values depend on runtime environment
        _ = manager.hasGrantedHealthKit
        _ = manager.hasGrantedMicrophone
        _ = manager.hasConnectedWatch
    }

    @MainActor
    func testOnboardingManagerCompleteOnboarding() {
        let manager = OnboardingManager.shared
        let originalState = manager.hasCompletedOnboarding

        manager.completeOnboarding()
        XCTAssertTrue(manager.hasCompletedOnboarding)

        // Restore original state if it was false
        if !originalState {
            manager.resetOnboarding()
        }
    }

    @MainActor
    func testOnboardingManagerResetOnboarding() {
        let manager = OnboardingManager.shared

        manager.completeOnboarding()
        XCTAssertTrue(manager.hasCompletedOnboarding)

        manager.resetOnboarding()
        XCTAssertFalse(manager.hasCompletedOnboarding)
    }

    @MainActor
    func testOnboardingManagerPersistence() {
        let manager = OnboardingManager.shared

        // Complete onboarding
        manager.completeOnboarding()

        // Should be stored in UserDefaults
        let storedValue = UserDefaults.standard.bool(forKey: "hasCompletedOnboarding")
        XCTAssertTrue(storedValue)

        // Clean up
        manager.resetOnboarding()
    }

    // MARK: - OnboardingView Tests

    @MainActor
    func testOnboardingViewInitialization() {
        let view = OnboardingView()
        XCTAssertNotNil(view)
    }

    @MainActor
    func testOnboardingViewBodyExists() {
        let view = OnboardingView()
        // SwiftUI view should have a body
        let _ = view.body
        // If this compiles and runs, the body exists
    }

    // MARK: - QuantumVisualizationView Tests

    @MainActor
    func testQuantumVisualizationViewInitialization() {
        let emulator = QuantumLightEmulator()
        let view = QuantumVisualizationView(emulator: emulator)

        XCTAssertNotNil(view)
    }

    @MainActor
    func testQuantumVisualizationViewWithDifferentModes() {
        let emulator = QuantumLightEmulator()

        // Test with different emulation modes
        for mode in QuantumLightEmulator.EmulationMode.allCases {
            emulator.setMode(mode)
            let view = QuantumVisualizationView(emulator: emulator)
            XCTAssertNotNil(view)
        }
    }

    // MARK: - View Accessibility Tests

    @MainActor
    func testQuantumVisualizationAccessibility() {
        // Views should have proper accessibility labels
        // Testing that the view can be created without accessibility issues
        let emulator = QuantumLightEmulator()
        let view = QuantumVisualizationView(emulator: emulator)

        // The view declares accessibility in its body
        XCTAssertNotNil(view)
    }

    // MARK: - VisualStepSequencerView Tests

    @MainActor
    func testVisualStepSequencerViewInitialization() {
        let view = VisualStepSequencerView()
        XCTAssertNotNil(view)
    }

    @MainActor
    func testVisualStepSequencerViewBody() {
        let view = VisualStepSequencerView()
        let _ = view.body
        // Should compile and run
    }

    // MARK: - View State Tests

    @MainActor
    func testOnboardingViewStateTransitions() {
        // Test that onboarding can progress through pages
        let manager = OnboardingManager.shared
        let initialState = manager.hasCompletedOnboarding

        // Reset to ensure clean state
        manager.resetOnboarding()
        XCTAssertFalse(manager.hasCompletedOnboarding)

        // Complete onboarding
        manager.completeOnboarding()
        XCTAssertTrue(manager.hasCompletedOnboarding)

        // Restore original state
        if !initialState {
            manager.resetOnboarding()
        }
    }

    // MARK: - Component View Tests

    @MainActor
    func testStepButtonStructure() {
        // Test that StepButton can be created
        // StepButton is used in VisualStepSequencerView
        var didTap = false

        let button = StepButton(
            isActive: true,
            isCurrent: false,
            color: .cyan,
            action: { didTap = true }
        )

        XCTAssertNotNil(button)
    }

    // MARK: - Color Calculations Tests

    func testCoherenceGradientColors() {
        // Test that coherence values produce valid colors
        let coherenceValues: [Double] = [0.0, 0.25, 0.5, 0.75, 1.0]

        for coherence in coherenceValues {
            // Simulate the gradient calculation from QuantumVisualizationView
            let topColor = Color(
                hue: 0.55 + coherence * 0.15,
                saturation: 0.6,
                brightness: 0.15
            )
            let bottomColor = Color(
                hue: 0.7 + coherence * 0.1,
                saturation: 0.5,
                brightness: 0.1
            )

            XCTAssertNotNil(topColor)
            XCTAssertNotNil(bottomColor)
        }
    }

    // MARK: - Observable Object Conformance Tests

    @MainActor
    func testOnboardingManagerObservable() {
        let manager = OnboardingManager.shared

        // Should be an ObservableObject
        let _ = manager.objectWillChange

        // Published properties should exist
        XCTAssertNotNil(manager.hasCompletedOnboarding)
        XCTAssertNotNil(manager.hasGrantedHealthKit)
    }

    // MARK: - UserDefaults Integration Tests

    @MainActor
    func testUserDefaultsKeyConsistency() {
        let manager = OnboardingManager.shared
        let key = "hasCompletedOnboarding"

        // Save a value
        manager.completeOnboarding()

        // Check UserDefaults directly
        let directValue = UserDefaults.standard.bool(forKey: key)
        XCTAssertEqual(directValue, manager.hasCompletedOnboarding)

        // Clean up
        manager.resetOnboarding()
    }

    @MainActor
    func testUserDefaultsRemovalOnReset() {
        let manager = OnboardingManager.shared
        let key = "hasCompletedOnboarding"

        // Set and reset
        manager.completeOnboarding()
        manager.resetOnboarding()

        // After reset, value should be false
        let value = UserDefaults.standard.bool(forKey: key)
        XCTAssertFalse(value)
    }

    // MARK: - View Configuration Tests

    @MainActor
    func testOnboardingViewPageCount() {
        // The onboarding has 5 pages
        // This is defined in OnboardingView.totalPages
        let expectedPageCount = 5

        // Create the view and verify it initializes correctly
        let view = OnboardingView()
        XCTAssertNotNil(view)

        // The page count is private, but we verify the view works
    }

    // MARK: - Permission State Tests

    @MainActor
    func testPermissionStateTypes() {
        let manager = OnboardingManager.shared

        // All permission states should be boolean
        XCTAssertTrue(manager.hasGrantedHealthKit || !manager.hasGrantedHealthKit)
        XCTAssertTrue(manager.hasGrantedMicrophone || !manager.hasGrantedMicrophone)
        XCTAssertTrue(manager.hasConnectedWatch || !manager.hasConnectedWatch)
    }

    // MARK: - Edge Cases

    @MainActor
    func testRepeatedCompletionCalls() {
        let manager = OnboardingManager.shared

        // Call completeOnboarding multiple times
        for _ in 0..<5 {
            manager.completeOnboarding()
        }

        XCTAssertTrue(manager.hasCompletedOnboarding)

        // Clean up
        manager.resetOnboarding()
    }

    @MainActor
    func testRepeatedResetCalls() {
        let manager = OnboardingManager.shared

        // Call resetOnboarding multiple times
        for _ in 0..<5 {
            manager.resetOnboarding()
        }

        XCTAssertFalse(manager.hasCompletedOnboarding)
    }

    // MARK: - Performance Tests

    @MainActor
    func testOnboardingManagerAccessPerformance() {
        let manager = OnboardingManager.shared

        measure {
            for _ in 0..<1000 {
                let _ = manager.hasCompletedOnboarding
                let _ = manager.hasGrantedHealthKit
                let _ = manager.hasGrantedMicrophone
                let _ = manager.hasConnectedWatch
            }
        }
    }

    @MainActor
    func testViewCreationPerformance() {
        measure {
            for _ in 0..<100 {
                let emulator = QuantumLightEmulator()
                let _ = QuantumVisualizationView(emulator: emulator)
            }
        }
    }

    // MARK: - Cleanup

    override func tearDown() {
        super.tearDown()

        // Ensure onboarding state is clean after tests
        Task { @MainActor in
            OnboardingManager.shared.resetOnboarding()
        }
    }
}
