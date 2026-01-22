import Foundation

// MARK: - MVP Definition for Echoelmusic v1.0

/// Defines the Minimum Viable Product scope for realistic v1.0 launch
///
/// Philosophy: Ship a focused, polished core experience.
/// Better to launch with 10 great features than 100 half-baked ones.
public enum MVPDefinition {

    // MARK: - Feature Tiers

    /// Feature tier categorization
    public enum Tier: String, CaseIterable {
        case core       // MUST have for v1.0 - Non-negotiable
        case enhanced   // Nice to have for v1.0 - Launch if time permits
        case future     // Post-launch (v1.1, v2.0+)

        var description: String {
            switch self {
            case .core:
                return "Critical for MVP - Cannot launch without these"
            case .enhanced:
                return "Quality-of-life improvements - Launch if stable"
            case .future:
                return "Post-launch features - Don't block v1.0"
            }
        }
    }

    // MARK: - Core Features (MVP v1.0 - MUST HAVE)

    /// Features that MUST be in v1.0 to ship
    public static let coreFeatures: [MVPFeature] = [
        // Bio-Reactive Audio (Core Value Proposition)
        MVPFeature(
            name: "Basic HealthKit Integration",
            tier: .core,
            description: "Read heart rate and HRV from Apple Watch",
            files: [
                "Sources/Echoelmusic/Biofeedback/HealthKitManager.swift",
                "Sources/Echoelmusic/Biofeedback/ProductionHealthKitManager.swift"
            ],
            estimatedDays: 5,
            dependencies: ["HealthKit.framework"],
            acceptanceCriteria: [
                "Reads heart rate every 1-5 seconds",
                "Calculates HRV (SDNN, RMSSD)",
                "Handles permissions gracefully",
                "Works with real Apple Watch data"
            ]
        ),

        MVPFeature(
            name: "Bio-Reactive Audio Engine",
            tier: .core,
            description: "Map HRV coherence to audio parameters (reverb, filter, tempo)",
            files: [
                "Sources/Echoelmusic/Audio/AudioEngine.swift",
                "Sources/Echoelmusic/Audio/BioModulator.swift"
            ],
            estimatedDays: 7,
            dependencies: ["AVFoundation", "Accelerate"],
            acceptanceCriteria: [
                "HRV coherence modulates reverb mix (0-100%)",
                "Heart rate influences tempo (60-120 BPM)",
                "Filter cutoff responds to breathing rate",
                "Audio changes feel smooth, not jarring"
            ]
        ),

        // Visual Feedback (Essential for engagement)
        MVPFeature(
            name: "3 Basic Visualizations",
            tier: .core,
            description: "Waveform, Spectrum, and Coherence Pulse",
            files: [
                "Sources/Echoelmusic/Visual/VisualizationEngine.swift",
                "Sources/Echoelmusic/Views/VisualizationView.swift"
            ],
            estimatedDays: 5,
            dependencies: ["SwiftUI", "Metal"],
            acceptanceCriteria: [
                "Waveform shows audio amplitude",
                "Spectrum shows frequency bands",
                "Coherence Pulse syncs to heart rate",
                "Runs at 60 FPS on iPhone 12+"
            ]
        ),

        // Audio Presets (User Experience)
        MVPFeature(
            name: "5 Curated Audio Presets",
            tier: .core,
            description: "Meditation, Focus, Energize, Calm, Creative",
            files: [
                "Sources/Echoelmusic/Presets/PresetManager.swift",
                "Sources/Echoelmusic/Presets/BioReactivePresets.swift"
            ],
            estimatedDays: 3,
            dependencies: [],
            acceptanceCriteria: [
                "Each preset has distinct sonic character",
                "Presets load in <500ms",
                "Settings persist across sessions",
                "Clear descriptions for each preset"
            ]
        ),

        // Recording (Key Feature)
        MVPFeature(
            name: "Basic Audio Recording",
            tier: .core,
            description: "Record sessions to WAV/M4A",
            files: [
                "Sources/Echoelmusic/Recording/RecordingEngine.swift"
            ],
            estimatedDays: 4,
            dependencies: ["AVFoundation"],
            acceptanceCriteria: [
                "Records to Files app",
                "WAV and M4A formats",
                "Session metadata (date, duration, preset)",
                "Share to other apps"
            ]
        ),

        // Apple Watch Companion
        MVPFeature(
            name: "Apple Watch Companion App",
            tier: .core,
            description: "View coherence, control presets, start/stop sessions",
            files: [
                "Sources/Echoelmusic/WatchOS/WatchOSApp.swift",
                "Sources/Echoelmusic/WatchOS/CoherenceView.swift"
            ],
            estimatedDays: 6,
            dependencies: ["WatchConnectivity"],
            acceptanceCriteria: [
                "Shows real-time coherence gauge",
                "Switch presets from watch",
                "Start/stop sessions",
                "Haptic feedback on coherence changes"
            ]
        ),

        // iOS App UI
        MVPFeature(
            name: "iOS Main App Interface",
            tier: .core,
            description: "SwiftUI app with session view, settings, recording list",
            files: [
                "Sources/Echoelmusic/Views/MainView.swift",
                "Sources/Echoelmusic/Views/SessionView.swift",
                "Sources/Echoelmusic/Views/SettingsView.swift"
            ],
            estimatedDays: 10,
            dependencies: ["SwiftUI"],
            acceptanceCriteria: [
                "Clear navigation structure",
                "Onboarding for first launch",
                "Settings for audio, privacy, notifications",
                "Works on iPhone 12-16"
            ]
        ),

        // Legal & Privacy
        MVPFeature(
            name: "Privacy Policy & Health Disclaimers",
            tier: .core,
            description: "Legal docs, health disclaimers, GDPR compliance",
            files: [
                "Sources/Echoelmusic/Legal/PrivacyPolicy.swift",
                "Sources/Echoelmusic/Legal/HealthDisclaimer.swift"
            ],
            estimatedDays: 2,
            dependencies: [],
            acceptanceCriteria: [
                "Privacy policy covers HealthKit data",
                "Clear 'NOT a medical device' disclaimer",
                "GDPR data export/delete",
                "Terms of service for App Store compliance"
            ]
        ),

        // App Store Basics
        MVPFeature(
            name: "App Store Submission Package",
            tier: .core,
            description: "Screenshots, app icon, description, keywords",
            files: [
                "Sources/Echoelmusic/Production/AppStoreMetadata.swift"
            ],
            estimatedDays: 3,
            dependencies: [],
            acceptanceCriteria: [
                "5 screenshots per device size",
                "1024x1024 app icon",
                "App description (English)",
                "Keywords for discoverability"
            ]
        )
    ]

    // MARK: - Enhanced Features (v1.0 if time permits, v1.1 otherwise)

    /// Features that improve the experience but aren't critical
    public static let enhancedFeatures: [MVPFeature] = [
        MVPFeature(
            name: "Streaming to YouTube Live",
            tier: .enhanced,
            description: "Single-platform streaming (YouTube only)",
            files: [
                "Sources/Echoelmusic/Stream/StreamEngine.swift"
            ],
            estimatedDays: 8,
            dependencies: ["VideoToolbox"],
            acceptanceCriteria: [
                "Stream to YouTube with RTMP",
                "1080p @ 30fps",
                "Audio + visualization overlay"
            ]
        ),

        MVPFeature(
            name: "10 Visualizations",
            tier: .enhanced,
            description: "Expand from 3 to 10 visual modes",
            files: [
                "Sources/Echoelmusic/Visual/VisualizationEngine.swift"
            ],
            estimatedDays: 5,
            dependencies: ["Metal"],
            acceptanceCriteria: [
                "Sacred geometry, particles, fractals",
                "All maintain 60 FPS"
            ]
        ),

        MVPFeature(
            name: "Basic MIDI Controller Support",
            tier: .enhanced,
            description: "Map MIDI CC to audio parameters",
            files: [
                "Sources/Echoelmusic/MIDI/MIDIManager.swift"
            ],
            estimatedDays: 4,
            dependencies: ["CoreMIDI"],
            acceptanceCriteria: [
                "Detect USB MIDI controllers",
                "Map 8 CCs to parameters"
            ]
        ),

        MVPFeature(
            name: "2-4 Person Collaboration",
            tier: .enhanced,
            description: "Small group sessions via SharePlay",
            files: [
                "Sources/Echoelmusic/SharePlay/QuantumSharePlayManager.swift"
            ],
            estimatedDays: 6,
            dependencies: ["GroupActivities"],
            acceptanceCriteria: [
                "2-4 people sync coherence",
                "Works over FaceTime"
            ]
        ),

        MVPFeature(
            name: "10 Additional Presets",
            tier: .enhanced,
            description: "Expand from 5 to 15 presets",
            files: [
                "Sources/Echoelmusic/Presets/PresetManager.swift"
            ],
            estimatedDays: 3,
            dependencies: [],
            acceptanceCriteria: [
                "Genre diversity (ambient, techno, etc.)",
                "All bio-reactive"
            ]
        ),

        MVPFeature(
            name: "Siri Shortcuts",
            tier: .enhanced,
            description: "3 shortcuts: Start Session, Check Coherence, Set Preset",
            files: [
                "Sources/Echoelmusic/Shortcuts/ShortcutsProvider.swift"
            ],
            estimatedDays: 2,
            dependencies: ["Intents"],
            acceptanceCriteria: [
                "Works with 'Hey Siri'",
                "Appears in Shortcuts app"
            ]
        )
    ]

    // MARK: - Future Features (v2.0+)

    /// Features to defer to post-launch
    public static let futureFeatures: [MVPFeature] = [
        MVPFeature(
            name: "Quantum Visualization System",
            tier: .future,
            description: "Full quantum light emulator with photonics",
            files: [
                "Sources/Echoelmusic/Quantum/QuantumLightEmulator.swift",
                "Sources/Echoelmusic/Quantum/PhotonicsVisualizationEngine.swift"
            ],
            estimatedDays: 15,
            dependencies: ["Metal"],
            acceptanceCriteria: ["Post-launch feature"]
        ),

        MVPFeature(
            name: "Orchestral Scoring Engine",
            tier: .future,
            description: "Disney-style cinematic scoring",
            files: [
                "Sources/Echoelmusic/Orchestral/CinematicScoringEngine.swift"
            ],
            estimatedDays: 20,
            dependencies: [],
            acceptanceCriteria: ["Post-launch feature"]
        ),

        MVPFeature(
            name: "Multi-Platform Streaming",
            tier: .future,
            description: "Stream to Twitch, Facebook, Instagram, TikTok, custom RTMP",
            files: [
                "Sources/Echoelmusic/Stream/StreamEngine.swift"
            ],
            estimatedDays: 12,
            dependencies: [],
            acceptanceCriteria: ["Post-launch feature"]
        ),

        MVPFeature(
            name: "Worldwide Collaboration (1000+)",
            tier: .future,
            description: "Global sessions with zero-latency sync",
            files: [
                "Sources/Echoelmusic/Collaboration/WorldwideCollaborationHub.swift"
            ],
            estimatedDays: 25,
            dependencies: [],
            acceptanceCriteria: ["Post-launch feature"]
        ),

        MVPFeature(
            name: "DMX/Art-Net Lighting",
            tier: .future,
            description: "Control professional lighting systems",
            files: [
                "Sources/Echoelmusic/LED/MIDIToLightMapper.swift"
            ],
            estimatedDays: 10,
            dependencies: [],
            acceptanceCriteria: ["Post-launch feature"]
        ),

        MVPFeature(
            name: "Plugin SDK",
            tier: .future,
            description: "Developer SDK for custom plugins",
            files: [
                "Sources/Echoelmusic/Developer/PluginManager.swift"
            ],
            estimatedDays: 15,
            dependencies: [],
            acceptanceCriteria: ["Post-launch feature"]
        ),

        MVPFeature(
            name: "visionOS Immersive Space",
            tier: .future,
            description: "360° spatial experience",
            files: [
                "Sources/Echoelmusic/VisionOS/ImmersiveQuantumSpace.swift"
            ],
            estimatedDays: 12,
            dependencies: [],
            acceptanceCriteria: ["Post-launch feature"]
        ),

        MVPFeature(
            name: "16K Video Processing",
            tier: .future,
            description: "Ultra high-resolution video engine",
            files: [
                "Sources/Echoelmusic/Video/VideoProcessingEngine.swift"
            ],
            estimatedDays: 18,
            dependencies: [],
            acceptanceCriteria: ["Post-launch feature"]
        ),

        MVPFeature(
            name: "AI Creative Studio",
            tier: .future,
            description: "AI art and music generation",
            files: [
                "Sources/Echoelmusic/Creative/CreativeStudioEngine.swift"
            ],
            estimatedDays: 20,
            dependencies: [],
            acceptanceCriteria: ["Post-launch feature"]
        ),

        MVPFeature(
            name: "Cross-Platform (Android, Windows, Linux)",
            tier: .future,
            description: "Full platform ports",
            files: [
                "android/",
                "Desktop/"
            ],
            estimatedDays: 60,
            dependencies: [],
            acceptanceCriteria: ["Post-launch feature"]
        )
    ]

    // MARK: - All Features

    /// All features across all tiers
    public static var allFeatures: [MVPFeature] {
        coreFeatures + enhancedFeatures + futureFeatures
    }

    /// Core features only
    public static var mvpFeatures: [MVPFeature] {
        coreFeatures
    }
}

// MARK: - MVP Feature Model

/// Represents a single feature in the MVP
public struct MVPFeature: Identifiable {
    public let id = UUID()
    public let name: String
    public let tier: MVPDefinition.Tier
    public let description: String
    public let files: [String]
    public let estimatedDays: Int
    public let dependencies: [String]
    public let acceptanceCriteria: [String]

    /// Implementation status (to be tracked manually)
    public var status: ImplementationStatus = .notStarted

    public enum ImplementationStatus: String, CaseIterable {
        case notStarted = "Not Started"
        case inProgress = "In Progress"
        case needsTesting = "Needs Testing"
        case complete = "Complete"
        case blocked = "Blocked"

        var icon: String {
            switch self {
            case .notStarted: return "⚪️"
            case .inProgress: return "🟡"
            case .needsTesting: return "🟠"
            case .complete: return "🟢"
            case .blocked: return "🔴"
            }
        }
    }

    /// Check if all files exist (used for development tracking)
    /// In production builds, always returns true since files are compiled into the app
    public func filesExist() -> Bool {
        #if DEBUG
        // In debug builds, check if source files exist relative to current working directory
        // This is a development-time check only
        return files.allSatisfy { path in
            FileManager.default.fileExists(atPath: path)
        }
        #else
        // In release builds, files are compiled into the app - always return true
        return true
        #endif
    }

    /// Generate markdown checklist item
    public func checklistItem() -> String {
        let statusIcon = status.icon
        let fileStatus = filesExist() ? "✓" : "✗"
        return "\(statusIcon) **\(name)** [\(tier.rawValue)] - \(status.rawValue) - Files: \(fileStatus)"
    }
}

// MARK: - MVP Checklist

/// Tracks MVP progress
public struct MVPChecklist {
    public let features: [MVPFeature]

    public init(features: [MVPFeature] = MVPDefinition.mvpFeatures) {
        self.features = features
    }

    /// Total estimated days for all features
    public var totalEstimatedDays: Int {
        features.reduce(0) { $0 + $1.estimatedDays }
    }

    /// Progress by status
    public func count(status: MVPFeature.ImplementationStatus) -> Int {
        features.filter { $0.status == status }.count
    }

    /// Completion percentage
    public var completionPercentage: Double {
        let completed = Double(count(status: .complete))
        return (completed / Double(features.count)) * 100.0
    }

    /// Features grouped by tier
    public var featuresByTier: [MVPDefinition.Tier: [MVPFeature]] {
        Dictionary(grouping: features, by: { $0.tier })
    }

    /// Generate markdown report
    public func markdownReport() -> String {
        var report = "# Echoelmusic MVP Checklist\n\n"
        report += "**Overall Progress:** \(Int(completionPercentage))% complete\n\n"
        report += "**Total Estimated Days:** \(totalEstimatedDays) days\n\n"

        for tier in MVPDefinition.Tier.allCases {
            if let tierFeatures = featuresByTier[tier], !tierFeatures.isEmpty {
                report += "## \(tier.rawValue.uppercased()) Features\n"
                report += "*\(tier.description)*\n\n"

                for feature in tierFeatures {
                    report += "- \(feature.checklistItem())\n"
                    report += "  - **Estimated:** \(feature.estimatedDays) days\n"
                    report += "  - **Files:** \(feature.files.count) files\n"
                    if !feature.acceptanceCriteria.isEmpty {
                        report += "  - **Criteria:**\n"
                        for criteria in feature.acceptanceCriteria {
                            report += "    - [ ] \(criteria)\n"
                        }
                    }
                    report += "\n"
                }
            }
        }

        return report
    }
}

// MARK: - Launch Readiness Checker

/// Evaluates if MVP is ready for launch
public struct LaunchReadinessChecker {
    public let checklist: MVPChecklist

    public init(checklist: MVPChecklist = MVPChecklist()) {
        self.checklist = checklist
    }

    /// Check if ready to launch v1.0
    public func isReadyToLaunch() -> LaunchReadiness {
        let coreFeatures = checklist.features.filter { $0.tier == .core }
        let coreComplete = coreFeatures.filter { $0.status == .complete }

        let blockers = coreFeatures.filter { $0.status == .blocked }
        let inProgress = coreFeatures.filter { $0.status == .inProgress }
        let needsTesting = coreFeatures.filter { $0.status == .needsTesting }

        // All core features must be complete
        if coreComplete.count == coreFeatures.count {
            return .ready
        }

        // Critical blockers
        if !blockers.isEmpty {
            return .blocked(features: blockers.map { $0.name })
        }

        // In development
        if !inProgress.isEmpty || !needsTesting.isEmpty {
            let remaining = inProgress.count + needsTesting.count
            return .inProgress(remainingFeatures: remaining)
        }

        // Not started
        return .notReady(missingFeatures: coreFeatures.filter { $0.status == .notStarted }.map { $0.name })
    }

    /// Launch readiness state
    public enum LaunchReadiness {
        case ready
        case inProgress(remainingFeatures: Int)
        case blocked(features: [String])
        case notReady(missingFeatures: [String])

        public var canLaunch: Bool {
            if case .ready = self { return true }
            return false
        }

        public var message: String {
            switch self {
            case .ready:
                return "✅ MVP is READY to launch! All core features complete."
            case .inProgress(let remaining):
                return "🟡 MVP in progress. \(remaining) core features remaining."
            case .blocked(let features):
                return "🔴 MVP BLOCKED. Critical issues in: \(features.joined(separator: ", "))"
            case .notReady(let missing):
                return "⚪️ MVP not started. Missing: \(missing.joined(separator: ", "))"
            }
        }
    }

    /// Generate full launch readiness report
    public func generateReport() -> String {
        var report = "# 🚀 Launch Readiness Report\n\n"
        report += "**Date:** \(Date().formatted(date: .long, time: .omitted))\n\n"

        let readiness = isReadyToLaunch()
        report += "## Status\n\n"
        report += "\(readiness.message)\n\n"

        // Core features breakdown
        let coreFeatures = checklist.features.filter { $0.tier == .core }
        report += "## Core Features (\(coreFeatures.count) total)\n\n"

        for status in MVPFeature.ImplementationStatus.allCases {
            let count = coreFeatures.filter { $0.status == status }.count
            if count > 0 {
                report += "- \(status.icon) **\(status.rawValue):** \(count)\n"
            }
        }

        report += "\n"

        // Enhanced features (optional for v1.0)
        let enhancedFeatures = checklist.features.filter { $0.tier == .enhanced }
        let enhancedComplete = enhancedFeatures.filter { $0.status == .complete }.count
        report += "## Enhanced Features (Optional for v1.0)\n\n"
        report += "**Complete:** \(enhancedComplete) / \(enhancedFeatures.count)\n\n"

        // Time estimate
        let remainingDays = coreFeatures
            .filter { $0.status != .complete }
            .reduce(0) { $0 + $1.estimatedDays }

        report += "## Timeline\n\n"
        report += "**Estimated Days Remaining:** \(remainingDays) days\n"
        report += "**Target Launch:** TBD\n\n"

        // Recommendations
        report += "## Recommendations\n\n"

        switch readiness {
        case .ready:
            report += "1. ✅ Begin App Store submission process\n"
            report += "2. ✅ Prepare marketing materials\n"
            report += "3. ✅ Set up customer support\n"
            report += "4. ✅ Plan v1.1 features from Enhanced tier\n"
        case .inProgress:
            report += "1. 🎯 Focus on completing core features\n"
            report += "2. 🎯 Defer all enhanced/future features\n"
            report += "3. 🎯 Daily standup to track blockers\n"
        case .blocked:
            report += "1. 🚨 Address critical blockers IMMEDIATELY\n"
            report += "2. 🚨 Escalate technical issues\n"
            report += "3. 🚨 Re-evaluate timelines\n"
        case .notReady:
            report += "1. 📋 Prioritize core feature development\n"
            report += "2. 📋 Create sprint plan\n"
            report += "3. 📋 Set weekly milestones\n"
        }

        return report
    }
}

// MARK: - Example Usage

/*
 // Update feature status
 var features = MVPDefinition.mvpFeatures
 features[0].status = .complete  // HealthKit integration done
 features[1].status = .inProgress  // Bio-reactive audio in progress

 // Create checklist
 let checklist = MVPChecklist(features: features)
 print(checklist.markdownReport())

 // Check readiness
 let checker = LaunchReadinessChecker(checklist: checklist)
 let readiness = checker.isReadyToLaunch()
 print(readiness.message)

 // Generate full report
 print(checker.generateReport())
 */
