//
//  EOELApp.swift
//  EOEL
//
//  Created: 2025-11-24
//  Copyright © 2025 EOEL. All rights reserved.
//

import SwiftUI

@main
struct EOELApp: App {
    // Unified Feature Integration - Central coordinator for all 164+ features
    @StateObject private var unifiedIntegration = UnifiedFeatureIntegration.shared

    // Direct access to core systems (for convenience)
    private var audioEngine: EOELAudioEngine { unifiedIntegration.audioEngine }
    private var eoelWorkManager: EoelWorkManager { unifiedIntegration.eoelWorkManager }
    private var lightingController: UnifiedLightingController { unifiedIntegration.lightingController }
    private var photonicSystem: PhotonicSystem { unifiedIntegration.photonicSystem }

    init() {
        // Configure app appearance
        setupAppearance()

        // Initialize ALL systems through unified integration
        Task {
            await initializeUnifiedSystem()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                // Inject unified integration (provides access to all systems)
                .environmentObject(unifiedIntegration)
                // Also inject individual systems for direct access
                .environmentObject(audioEngine)
                .environmentObject(eoelWorkManager)
                .environmentObject(lightingController)
                .environmentObject(photonicSystem)
                .preferredColorScheme(.dark)
        }
    }

    // MARK: - Setup

    private func setupAppearance() {
        // EOEL uses dark mode with custom color palette
        // Primary: Deep purple (#6366F1)
        // Secondary: Cyan (#06B6D4)
        // Accent: Pink (#EC4899)
    }

    private func initializeUnifiedSystem() async {
        do {
            // Initialize ALL EOEL systems and features through unified integration
            // This handles:
            // - 4 core systems (Audio, EoelWork, Lighting, Photonics)
            // - 164+ features (47 instruments, 77 effects, 40 video, 21 lighting, etc.)
            // - Cross-system integration (audio→lighting, biometrics→audio, etc.)
            try await unifiedIntegration.initialize()

            print("✅ EOEL Unified System Initialized - \(unifiedIntegration.activeFeatures.count) features active")
        } catch {
            print("❌ Initialization Error: \(error)")
        }
    }
}
