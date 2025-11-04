import Foundation
import SwiftUI
import Combine

/// Educational Content & Tutorial System
/// Provides interactive learning experiences for all ages
///
/// Features:
/// - Interactive tutorials
/// - Video lessons
/// - Practice exercises
/// - Progress tracking
/// - Age-appropriate content
/// - Multi-language support
/// - Offline access
/// - Accessibility support

// MARK: - Tutorial

public struct Tutorial: Identifiable, Codable {
    public let id: String
    public let title: String
    public let description: String
    public let category: TutorialCategory
    public let difficulty: Difficulty
    public let estimatedMinutes: Int
    public let steps: [TutorialStep]
    public var isCompleted: Bool
    public var progress: Int // Steps completed

    public var progressPercentage: Double {
        return Double(progress) / Double(steps.count)
    }
}

public struct TutorialStep: Identifiable, Codable {
    public let id: String
    public let title: String
    public let instruction: String
    public let imageURL: String?
    public let videoURL: String?
    public let action: TutorialAction?
    public var isCompleted: Bool
}

public enum TutorialAction: String, Codable {
    case tapButton = "tap_button"
    case changeMode = "change_mode"
    case adjustSlider = "adjust_slider"
    case recordAudio = "record_audio"
    case exportVideo = "export_video"
    case connectDevice = "connect_device"
}

public enum TutorialCategory: String, Codable, CaseIterable {
    case gettingStarted = "Getting Started"
    case visualization = "Visualization"
    case audio = "Audio"
    case biofeedback = "Biofeedback"
    case export = "Export & Share"
    case advanced = "Advanced"
    case wellness = "Wellness"
}

public enum Difficulty: String, Codable {
    case beginner = "Beginner"
    case intermediate = "Intermediate"
    case advanced = "Advanced"
}

// MARK: - Educational Manager

@MainActor
public final class EducationalManager: ObservableObject {

    public static let shared = EducationalManager()

    @Published public var tutorials: [Tutorial]
    @Published public var currentTutorial: Tutorial?
    @Published public var showTutorialOverlay: Bool = false

    private var cancellables = Set<AnyCancellable>()

    private init() {
        tutorials = Self.loadTutorials()
        print("📚 Educational Manager initialized")
        print("   Tutorials available: \(tutorials.count)")
    }

    private static func loadTutorials() -> [Tutorial] {
        return [
            Tutorial(
                id: "intro",
                title: "Welcome to BLAB",
                description: "Learn the basics of BLAB in 5 minutes",
                category: .gettingStarted,
                difficulty: .beginner,
                estimatedMinutes: 5,
                steps: [
                    TutorialStep(
                        id: "intro_1",
                        title: "Welcome!",
                        instruction: "BLAB is an audio-visual synthesis platform that responds to your voice, breath, and biofeedback. Let's explore!",
                        imageURL: nil,
                        videoURL: nil,
                        action: nil,
                        isCompleted: false
                    ),
                    TutorialStep(
                        id: "intro_2",
                        title: "Start Playing",
                        instruction: "Tap the Play button to start your first session.",
                        imageURL: nil,
                        videoURL: nil,
                        action: .tapButton,
                        isCompleted: false
                    ),
                    TutorialStep(
                        id: "intro_3",
                        title: "Visualization Modes",
                        instruction: "Try different visualization modes: Particles, Cymatics, Waveform, Spectral, and Mandala.",
                        imageURL: nil,
                        videoURL: nil,
                        action: .changeMode,
                        isCompleted: false
                    ),
                ],
                isCompleted: false,
                progress: 0
            ),
            // Add more tutorials...
        ]
    }

    public func startTutorial(_ tutorialID: String) {
        guard let tutorial = tutorials.first(where: { $0.id == tutorialID }) else {
            return
        }

        currentTutorial = tutorial
        showTutorialOverlay = true

        print("📖 Started tutorial: \(tutorial.title)")
    }

    public func completeTutorialStep(_ stepID: String) {
        guard var tutorial = currentTutorial,
              let stepIndex = tutorial.steps.firstIndex(where: { $0.id == stepID }) else {
            return
        }

        tutorial.steps[stepIndex].isCompleted = true
        tutorial.progress += 1

        if tutorial.progress == tutorial.steps.count {
            tutorial.isCompleted = true
            GamificationManager.shared.addXP(tutorial.estimatedMinutes * 10)
            print("✅ Tutorial completed: \(tutorial.title)")
        }

        currentTutorial = tutorial
        saveTutorials()
    }

    private func saveTutorials() {
        // Save to UserDefaults
    }
}
