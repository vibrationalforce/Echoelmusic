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
    @StateObject private var audioEngine = EOELAudioEngine.shared
    @StateObject private var eoelWorkManager = EoelWorkManager.shared
    @StateObject private var lightingController = UnifiedLightingController()
    @StateObject private var photonicSystem = PhotonicSystem()

    init() {
        // Configure app appearance
        setupAppearance()

        // Initialize core systems
        Task {
            await initializeCoreSystems()
        }
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
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

    private func initializeCoreSystems() async {
        do {
            // Initialize audio engine
            try await audioEngine.initialize()

            // Initialize EoelWork
            try await eoelWorkManager.initialize()

            // Initialize lighting systems
            try await lightingController.discoverDevices()

            // Initialize photonic systems (LiDAR, laser safety checks)
            try await photonicSystem.initialize()

            print("✅ EOEL Core Systems Initialized")
        } catch {
            print("❌ Initialization Error: \(error)")
        }
    }
}
