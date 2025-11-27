//
//  OnboardingManager.swift
//  Echoelmusic
//
//  Created: 2025-11-25
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  Onboarding state management
//

import Foundation
import Combine

@MainActor
final class OnboardingManager: ObservableObject {
    static let shared = OnboardingManager()

    // MARK: - Published Properties

    @Published var hasCompletedOnboarding: Bool {
        didSet {
            UserDefaults.standard.set(hasCompletedOnboarding, forKey: Keys.completedOnboarding)
        }
    }

    @Published var currentStep: OnboardingStep = .welcome
    @Published var hasSeenFeature: Set<Feature> = []

    // MARK: - Onboarding Steps

    enum OnboardingStep: Int, CaseIterable {
        case welcome
        case accountCreation
        case permissions
        case quickTutorial
        case firstProject
        case completed

        var title: String {
            switch self {
            case .welcome:
                return "Welcome to Echoelmusic"
            case .accountCreation:
                return "Create Your Account"
            case .permissions:
                return "Enable Features"
            case .quickTutorial:
                return "Quick Tutorial"
            case .firstProject:
                return "Create Your First Project"
            case .completed:
                return "All Set!"
            }
        }

        var description: String {
            switch self {
            case .welcome:
                return "Professional music production & gig platform"
            case .accountCreation:
                return "Sync your projects across all devices"
            case .permissions:
                return "Choose which features to enable"
            case .quickTutorial:
                return "Learn the basics in 2 minutes"
            case .firstProject:
                return "Let's record your first track"
            case .completed:
                return "You're ready to create amazing music!"
            }
        }

        var icon: String {
            switch self {
            case .welcome:
                return "star.circle.fill"
            case .accountCreation:
                return "person.circle.fill"
            case .permissions:
                return "checkmark.shield.fill"
            case .quickTutorial:
                return "play.circle.fill"
            case .firstProject:
                return "music.note"
            case .completed:
                return "checkmark.circle.fill"
            }
        }

        var canSkip: Bool {
            switch self {
            case .welcome, .completed:
                return false
            case .accountCreation, .permissions, .quickTutorial, .firstProject:
                return true
            }
        }
    }

    // MARK: - Features

    enum Feature: String, CaseIterable {
        case recording
        case instruments
        case effects
        case faceControl
        case smartLighting
        case eoelWork
        case cloudSync
        case aiComposer

        var title: String {
            switch self {
            case .recording:
                return "Recording"
            case .instruments:
                return "Instruments"
            case .effects:
                return "Audio Effects"
            case .faceControl:
                return "Face Control"
            case .smartLighting:
                return "Smart Lighting"
            case .eoelWork:
                return "EoelWork Gigs"
            case .cloudSync:
                return "Cloud Sync"
            case .aiComposer:
                return "AI Composer"
            }
        }

        var description: String {
            switch self {
            case .recording:
                return "Record audio with professional quality"
            case .instruments:
                return "Play 47 virtual instruments"
            case .effects:
                return "Apply 77 studio effects"
            case .faceControl:
                return "Control effects with facial expressions"
            case .smartLighting:
                return "Sync lights with your music"
            case .eoelWork:
                return "Find gigs and get hired"
            case .cloudSync:
                return "Access projects anywhere"
            case .aiComposer:
                return "Generate melodies with AI"
            }
        }

        var icon: String {
            switch self {
            case .recording:
                return "mic.fill"
            case .instruments:
                return "pianokeys"
            case .effects:
                return "waveform"
            case .faceControl:
                return "face.smiling"
            case .smartLighting:
                return "lightbulb.fill"
            case .eoelWork:
                return "briefcase.fill"
            case .cloudSync:
                return "icloud.fill"
            case .aiComposer:
                return "sparkles"
            }
        }

        var requiresPermission: Bool {
            switch self {
            case .recording, .faceControl:
                return true
            case .instruments, .effects, .smartLighting, .eoelWork, .cloudSync, .aiComposer:
                return false
            }
        }
    }

    // MARK: - Keys

    private enum Keys {
        static let completedOnboarding = "onboarding_completed"
        static let currentStepKey = "onboarding_current_step"
        static let seenFeaturesKey = "onboarding_seen_features"
    }

    // MARK: - Initialization

    private init() {
        self.hasCompletedOnboarding = UserDefaults.standard.bool(forKey: Keys.completedOnboarding)

        // Load current step
        if let stepRaw = UserDefaults.standard.object(forKey: Keys.currentStepKey) as? Int,
           let step = OnboardingStep(rawValue: stepRaw) {
            self.currentStep = step
        }

        // Load seen features
        if let seenArray = UserDefaults.standard.array(forKey: Keys.seenFeaturesKey) as? [String] {
            self.hasSeenFeature = Set(seenArray.compactMap { Feature(rawValue: $0) })
        }
    }

    // MARK: - Progress Management

    func nextStep() {
        guard let nextStepRaw = currentStep.rawValue + 1,
              let nextStep = OnboardingStep(rawValue: nextStepRaw) else {
            completeOnboarding()
            return
        }

        currentStep = nextStep
        saveProgress()
    }

    func skipStep() {
        guard currentStep.canSkip else { return }
        nextStep()
    }

    func goToStep(_ step: OnboardingStep) {
        currentStep = step
        saveProgress()
    }

    func completeOnboarding() {
        hasCompletedOnboarding = true
        currentStep = .completed
        saveProgress()

        // Track completion
        let signal = TelemetryDeck.Signal("onboarding_completed", parameters: [
            "steps_completed": "\(currentStep.rawValue)",
            "features_seen": "\(hasSeenFeature.count)"
        ])
        TelemetryDeck.send(signal)
    }

    func resetOnboarding() {
        hasCompletedOnboarding = false
        currentStep = .welcome
        hasSeenFeature.removeAll()
        saveProgress()
    }

    // MARK: - Feature Tracking

    func markFeatureAsSeen(_ feature: Feature) {
        hasSeenFeature.insert(feature)
        saveSeen Features()

        // Track feature discovery
        let signal = TelemetryDeck.Signal("feature_discovered", parameters: [
            "feature": feature.rawValue
        ])
        TelemetryDeck.send(signal)
    }

    func hasSeenFeature(_ feature: Feature) -> Bool {
        hasSeenFeature.contains(feature)
    }

    // MARK: - Contextual Tips

    func shouldShowTip(for feature: Feature) -> Bool {
        // Only show tips if onboarding is complete and feature hasn't been seen
        return hasCompletedOnboarding && !hasSeenFeature(feature)
    }

    // MARK: - Persistence

    private func saveProgress() {
        UserDefaults.standard.set(currentStep.rawValue, forKey: Keys.currentStepKey)
    }

    private func saveSeenFeatures() {
        let seenArray = Array(hasSeenFeature).map { $0.rawValue }
        UserDefaults.standard.set(seenArray, forKey: Keys.seenFeaturesKey)
    }

    // MARK: - Progress Metrics

    var progressPercentage: Double {
        let totalSteps = Double(OnboardingStep.allCases.count - 1) // Exclude .completed
        let completedSteps = Double(currentStep.rawValue)
        return min(completedSteps / totalSteps, 1.0)
    }

    var remainingSteps: Int {
        OnboardingStep.allCases.count - currentStep.rawValue - 1
    }
}
