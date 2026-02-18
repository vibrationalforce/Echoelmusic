// EchoelNavigationStack.swift
// Echoelmusic — Backward-compatible NavigationStack wrapper
//
// Provides NavigationStack on iOS 16+ / macOS 13+ / tvOS 16+ / watchOS 9+
// Falls back to NavigationView on older OS versions.
//
// Usage: Replace `NavigationView { ... }` with `EchoelNavigationStack { ... }`
//
// Copyright © 2026 Echoelmusic. All rights reserved.

import SwiftUI

/// Backward-compatible NavigationStack that falls back to NavigationView on older OS versions.
public struct EchoelNavigationStack<Content: View>: View {
    private let content: Content

    public init(@ViewBuilder content: () -> Content) {
        self.content = content()
    }

    public var body: some View {
        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
            NavigationStack {
                content
            }
        } else {
            NavigationView {
                content
            }
            #if os(iOS)
            .navigationViewStyle(.stack)
            #endif
        }
    }
}
