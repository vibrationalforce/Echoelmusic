//
//  ContentView.swift
//  EOEL
//
//  Created: 2025-11-24
//  Copyright © 2025 EOEL. All rights reserved.
//

import SwiftUI

struct ContentView: View {
    @EnvironmentObject var audioEngine: EOELAudioEngine
    @EnvironmentObject var eoelWorkManager: EoelWorkManager
    @State private var selectedTab: Tab = .daw

    enum Tab {
        case daw
        case video
        case lighting
        case eoelWork
        case settings
    }

    var body: some View {
        TabView(selection: $selectedTab) {
            // DAW - Digital Audio Workstation
            DAWView()
                .tabItem {
                    Label("DAW", systemImage: "waveform")
                }
                .tag(Tab.daw)

            // Video Editor
            VideoEditorView()
                .tabItem {
                    Label("Video", systemImage: "video")
                }
                .tag(Tab.video)

            // Unified Lighting Control
            LightingControlView()
                .tabItem {
                    Label("Lighting", systemImage: "lightbulb.fill")
                }
                .tag(Tab.lighting)

            // EoelWork - Multi-Industry Gig Platform
            EoelWorkView()
                .tabItem {
                    Label("EoelWork", systemImage: "briefcase.fill")
                }
                .tag(Tab.eoelWork)

            // Settings
            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gear")
                }
                .tag(Tab.settings)
        }
        .accentColor(.purple)
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(EOELAudioEngine.shared)
        .environmentObject(EoelWorkManager.shared)
        .environmentObject(UnifiedLightingController())
        .environmentObject(PhotonicSystem())
}
