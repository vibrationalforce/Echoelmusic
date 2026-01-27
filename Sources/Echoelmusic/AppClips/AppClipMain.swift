// AppClipMain.swift
// Echoelmusic App Clip - Entry Point
//
// This file provides the @main entry point for the App Clip target.
// Only compiled when building the App Clip target specifically.
//
// Created: 2026-01-27

#if os(iOS) && canImport(AppClip)

import SwiftUI

/// App Clip entry point - provides @main for the App Clip target
@main
struct EchoelmusicClipApp: App {
    @StateObject private var appClipManager = AppClipManager.shared

    var body: some Scene {
        WindowGroup {
            AppClipRootView()
                .environmentObject(appClipManager)
                .onContinueUserActivity(NSUserActivityTypeBrowsingWeb) { activity in
                    appClipManager.handleUserActivity(activity)
                }
        }
    }
}

#endif
