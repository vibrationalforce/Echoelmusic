//
//  macOSPlatform.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  macOS PLATFORM - macOS-specific implementation
//  Desktop-optimized features
//

#if os(macOS)
import Foundation
import AppKit

@MainActor
class macOSPlatform: ObservableObject {
    static let shared = macOSPlatform()

    @Published var isMenuBarVisible: Bool = true
    @Published var isDarkMode: Bool = false

    private init() {
        print("🖥️ macOS Platform initialized")
        detectDarkMode()
    }

    // MARK: - Window Management

    func createFloatingWindow(title: String, size: NSSize) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = title
        window.center()
        window.isReleasedWhenClosed = false

        return window
    }

    func makeWindowFloat(_ window: NSWindow) {
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
    }

    // MARK: - Menu Bar

    func addMenuBarItem(title: String, action: @escaping () -> Void) -> NSStatusItem {
        let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem.button?.title = title
        statusItem.button?.action = #selector(menuBarItemClicked)

        return statusItem
    }

    @objc private func menuBarItemClicked() {
        print("Menu bar item clicked")
    }

    // MARK: - Keyboard Shortcuts

    func registerGlobalHotkey(key: String, modifiers: NSEvent.ModifierFlags, action: @escaping () -> Void) {
        print("⌨️ Registering global hotkey: \(key)")
        // Would use Carbon or modern EventMonitor API
    }

    // MARK: - Dark Mode

    private func detectDarkMode() {
        if let appearance = NSApp.effectiveAppearance.name.rawValue as String? {
            isDarkMode = appearance.contains("Dark")
        }
    }

    func observeDarkModeChanges(onChange: @escaping (Bool) -> Void) {
        DistributedNotificationCenter.default().addObserver(
            forName: Notification.Name("AppleInterfaceThemeChangedNotification"),
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.detectDarkMode()
            onChange(self?.isDarkMode ?? false)
        }
    }

    // MARK: - File Dialogs

    func showOpenPanel(allowedTypes: [String]) -> URL? {
        let panel = NSOpenPanel()
        panel.allowedContentTypes = allowedTypes.compactMap { UTType(filenameExtension: $0) }
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false

        if panel.runModal() == .OK {
            return panel.url
        }

        return nil
    }

    func showSavePanel(suggestedName: String, allowedTypes: [String]) -> URL? {
        let panel = NSSavePanel()
        panel.nameFieldStringValue = suggestedName
        panel.allowedContentTypes = allowedTypes.compactMap { UTType(filenameExtension: $0) }

        if panel.runModal() == .OK {
            return panel.url
        }

        return nil
    }

    // MARK: - Dock

    func setBadge(_ text: String) {
        NSApp.dockTile.badgeLabel = text
    }

    func clearBadge() {
        NSApp.dockTile.badgeLabel = nil
    }

    func bounceDock() {
        NSApp.requestUserAttention(.criticalRequest)
    }
}

#endif
