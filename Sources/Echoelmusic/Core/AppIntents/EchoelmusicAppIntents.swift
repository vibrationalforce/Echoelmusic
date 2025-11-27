//
//  EchoelmusicAppIntents.swift
//  Echoelmusic
//
//  Created: 2025-11-25
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  App Intents for Siri and Shortcuts
//

import Foundation
import AppIntents

// MARK: - Start Recording Intent

struct StartRecordingIntent: AppIntent {
    static var title: LocalizedStringResource = "Start Recording"
    static var description = IntentDescription("Start recording audio in Echoelmusic")

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        // Trigger recording start via notification
        NotificationCenter.default.post(name: .startRecordingFromIntent, object: nil)

        return .result()
    }
}

// MARK: - Apply Effect Intent

struct ApplyEffectIntent: AppIntent {
    static var title: LocalizedStringResource = "Apply Effect"
    static var description = IntentDescription("Apply an audio effect to the current track")

    static var openAppWhenRun: Bool = true

    @Parameter(title: "Effect")
    var effect: EffectType

    @MainActor
    func perform() async throws -> some IntentResult {
        // Apply effect via notification
        NotificationCenter.default.post(
            name: .applyEffectFromIntent,
            object: nil,
            userInfo: ["effect": effect.rawValue]
        )

        return .result(value: "Applied \(effect.rawValue) effect")
    }
}

// MARK: - Effect Type

enum EffectType: String, AppEnum {
    case reverb = "Reverb"
    case delay = "Delay"
    case chorus = "Chorus"
    case distortion = "Distortion"
    case compression = "Compression"
    case eq = "EQ"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Effect")

    static var caseDisplayRepresentations: [EffectType: DisplayRepresentation] = [
        .reverb: "Reverb",
        .delay: "Delay",
        .chorus: "Chorus",
        .distortion: "Distortion",
        .compression: "Compression",
        .eq: "EQ"
    ]
}

// MARK: - Create Project Intent

struct CreateProjectIntent: AppIntent {
    static var title: LocalizedStringResource = "Create Project"
    static var description = IntentDescription("Create a new music project in Echoelmusic")

    static var openAppWhenRun: Bool = true

    @Parameter(title: "Project Name")
    var projectName: String?

    @MainActor
    func perform() async throws -> some IntentResult {
        let name = projectName ?? "New Project"

        NotificationCenter.default.post(
            name: .createProjectFromIntent,
            object: nil,
            userInfo: ["name": name]
        )

        return .result(value: "Created project: \(name)")
    }
}

// MARK: - Open EoelWork Intent

struct OpenEoelWorkIntent: AppIntent {
    static var title: LocalizedStringResource = "Find Music Gigs"
    static var description = IntentDescription("Browse music gigs on EoelWork")

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .openEoelWorkFromIntent, object: nil)

        return .result()
    }
}

// MARK: - Get Project Status Intent

struct GetProjectStatusIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Project Status"
    static var description = IntentDescription("Get information about the current project")

    @MainActor
    func perform() async throws -> some IntentResult & ReturnsValue<ProjectStatusResult> {
        // Load current project from shared container
        guard let sharedDefaults = UserDefaults(suiteName: "group.app.eoel"),
              let data = sharedDefaults.data(forKey: "current_project"),
              let project = try? JSONDecoder().decode(ProjectInfo.self, from: data) else {
            throw IntentError.noActiveProject
        }

        let result = ProjectStatusResult(
            name: project.name,
            trackCount: project.trackCount,
            duration: project.durationFormatted
        )

        return .result(value: result, dialog: "Your project '\(project.name)' has \(project.trackCount) tracks and is \(project.durationFormatted) long")
    }
}

struct ProjectStatusResult: Codable {
    let name: String
    let trackCount: Int
    let duration: String
}

struct ProjectInfo: Codable {
    let name: String
    let lastModified: Date
    let trackCount: Int
    let duration: TimeInterval

    var durationFormatted: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

// MARK: - Enable Face Control Intent

struct EnableFaceControlIntent: AppIntent {
    static var title: LocalizedStringResource = "Enable Face Control"
    static var description = IntentDescription("Enable face control for audio effects")

    static var openAppWhenRun: Bool = true

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: .enableFaceControlFromIntent, object: nil)

        return .result(dialog: "Face Control enabled. Use facial expressions to control effects!")
    }
}

// MARK: - Export Project Intent

struct ExportProjectIntent: AppIntent {
    static var title: LocalizedStringResource = "Export Project"
    static var description = IntentDescription("Export the current project")

    static var openAppWhenRun: Bool = true

    @Parameter(title: "Format")
    var format: ExportFormat

    @MainActor
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(
            name: .exportProjectFromIntent,
            object: nil,
            userInfo: ["format": format.rawValue]
        )

        return .result(value: "Exporting project as \(format.rawValue)")
    }
}

enum ExportFormat: String, AppEnum {
    case wav = "WAV"
    case mp3 = "MP3"
    case aac = "AAC"
    case flac = "FLAC"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Format")

    static var caseDisplayRepresentations: [ExportFormat: DisplayRepresentation] = [
        .wav: "WAV (Lossless)",
        .mp3: "MP3 (Compressed)",
        .aac: "AAC (Apple)",
        .flac: "FLAC (Lossless)"
    ]
}

// MARK: - App Shortcuts Provider

struct EchoelmusicShortcutsProvider: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: StartRecordingIntent(),
            phrases: [
                "Start recording in \(.applicationName)",
                "Begin recording with \(.applicationName)",
                "Record audio in \(.applicationName)"
            ],
            shortTitle: "Start Recording",
            systemImageName: "record.circle"
        )

        AppShortcut(
            intent: CreateProjectIntent(),
            phrases: [
                "Create a new project in \(.applicationName)",
                "New music project in \(.applicationName)",
                "Make a new song in \(.applicationName)"
            ],
            shortTitle: "New Project",
            systemImageName: "plus.circle"
        )

        AppShortcut(
            intent: OpenEoelWorkIntent(),
            phrases: [
                "Find music gigs",
                "Show me music jobs",
                "Open EoelWork"
            ],
            shortTitle: "Find Gigs",
            systemImageName: "briefcase"
        )

        AppShortcut(
            intent: GetProjectStatusIntent(),
            phrases: [
                "What's my project status",
                "Tell me about my current project",
                "Project info"
            ],
            shortTitle: "Project Status",
            systemImageName: "info.circle"
        )

        AppShortcut(
            intent: ApplyEffectIntent(),
            phrases: [
                "Apply \(\.$effect) effect",
                "Add \(\.$effect) to track"
            ],
            shortTitle: "Apply Effect",
            systemImageName: "waveform"
        )

        AppShortcut(
            intent: EnableFaceControlIntent(),
            phrases: [
                "Enable face control",
                "Turn on face control",
                "Activate facial control"
            ],
            shortTitle: "Face Control",
            systemImageName: "face.smiling"
        )

        AppShortcut(
            intent: ExportProjectIntent(),
            phrases: [
                "Export my project",
                "Save my song",
                "Export as \(\.$format)"
            ],
            shortTitle: "Export",
            systemImageName: "square.and.arrow.up"
        )
    }
}

// MARK: - Intent Errors

enum IntentError: Error, CustomLocalizedStringResourceConvertible {
    case noActiveProject
    case recordingFailed
    case exportFailed

    var localizedStringResource: LocalizedStringResource {
        switch self {
        case .noActiveProject:
            return "No active project found. Please open or create a project first."
        case .recordingFailed:
            return "Failed to start recording. Please try again."
        case .exportFailed:
            return "Failed to export project. Please try again."
        }
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let startRecordingFromIntent = Notification.Name("startRecordingFromIntent")
    static let applyEffectFromIntent = Notification.Name("applyEffectFromIntent")
    static let createProjectFromIntent = Notification.Name("createProjectFromIntent")
    static let openEoelWorkFromIntent = Notification.Name("openEoelWorkFromIntent")
    static let enableFaceControlFromIntent = Notification.Name("enableFaceControlFromIntent")
    static let exportProjectFromIntent = Notification.Name("exportProjectFromIntent")
}

// MARK: - Usage in App

/*
 In your main app, handle these notifications:

 class AppDelegate: UIResponder, UIApplicationDelegate {
     func application(_ application: UIApplication, didFinishLaunchingWithOptions...) -> Bool {
         // Register for intent notifications
         NotificationCenter.default.addObserver(
             self,
             selector: #selector(handleStartRecording),
             name: .startRecordingFromIntent,
             object: nil
         )

         NotificationCenter.default.addObserver(
             self,
             selector: #selector(handleApplyEffect),
             name: .applyEffectFromIntent,
             object: nil
         )

         // ... add more observers
         return true
     }

     @objc func handleStartRecording() {
         // Navigate to recording screen and start recording
         // mainCoordinator.startRecording()
     }

     @objc func handleApplyEffect(_ notification: Notification) {
         guard let effect = notification.userInfo?["effect"] as? String else { return }
         // Apply the effect
         // audioEngine.applyEffect(effect)
     }
 }

 // Update widget data when project changes:
 func updateCurrentProject(_ project: Project) {
     let projectInfo = ProjectInfo(
         name: project.name,
         lastModified: Date(),
         trackCount: project.tracks.count,
         duration: project.duration
     )

     guard let sharedDefaults = UserDefaults(suiteName: "group.app.eoel"),
           let data = try? JSONEncoder().encode(projectInfo) else {
         return
     }

     sharedDefaults.set(data, forKey: "current_project")

     // Reload widget
     WidgetCenter.shared.reloadTimelines(ofKind: "EchoelmusicWidget")
 }
 */
