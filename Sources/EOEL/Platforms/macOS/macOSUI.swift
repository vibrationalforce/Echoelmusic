//
//  macOSUI.swift
//  EOEL
//
//  Created: 2025-11-26
//  Copyright © 2025 EOEL. All rights reserved.
//
//  macOS NATIVE UI COMPONENTS
//  Menu bar, Touch Bar, native controls, keyboard shortcuts
//

#if os(macOS)
import SwiftUI
import AppKit

// MARK: - macOS Menu Bar Manager

/// Manages macOS menu bar with native shortcuts and commands
@MainActor
class MenuBarManager {

    static let shared = MenuBarManager()

    /// Setup macOS menu bar with EOEL-specific commands
    func setupMenuBar() {
        let mainMenu = NSMenu()

        // EOEL Menu
        let eoelMenu = createEOELMenu()
        let eoelMenuItem = NSMenuItem()
        eoelMenuItem.submenu = eoelMenu
        mainMenu.addItem(eoelMenuItem)

        // File Menu
        let fileMenu = createFileMenu()
        let fileMenuItem = NSMenuItem()
        fileMenuItem.submenu = fileMenu
        mainMenu.addItem(fileMenuItem)

        // Edit Menu
        let editMenu = createEditMenu()
        let editMenuItem = NSMenuItem()
        editMenuItem.submenu = editMenu
        mainMenu.addItem(editMenuItem)

        // Session Menu
        let sessionMenu = createSessionMenu()
        let sessionMenuItem = NSMenuItem()
        sessionMenuItem.submenu = sessionMenu
        mainMenu.addItem(sessionMenuItem)

        // Audio Menu
        let audioMenu = createAudioMenu()
        let audioMenuItem = NSMenuItem()
        audioMenuItem.submenu = audioMenu
        mainMenu.addItem(audioMenuItem)

        // Plugins Menu
        let pluginsMenu = createPluginsMenu()
        let pluginsMenuItem = NSMenuItem()
        pluginsMenuItem.submenu = pluginsMenu
        mainMenu.addItem(pluginsMenuItem)

        // Biofeedback Menu
        let bioMenu = createBiofeedbackMenu()
        let bioMenuItem = NSMenuItem()
        bioMenuItem.submenu = bioMenu
        mainMenu.addItem(bioMenuItem)

        // Window Menu
        let windowMenu = createWindowMenu()
        let windowMenuItem = NSMenuItem()
        windowMenuItem.submenu = windowMenu
        mainMenu.addItem(windowMenuItem)

        NSApp.mainMenu = mainMenu
        print("📋 macOS menu bar configured")
    }

    private func createEOELMenu() -> NSMenu {
        let menu = NSMenu(title: "EOEL")

        menu.addItem(NSMenuItem(title: "About EOEL", action: #selector(AppDelegate.showAbout), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Preferences...", action: #selector(AppDelegate.showPreferences), keyEquivalent: ","))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Hide EOEL", action: #selector(NSApplication.hide(_:)), keyEquivalent: "h"))
        menu.addItem(NSMenuItem(title: "Hide Others", action: #selector(NSApplication.hideOtherApplications(_:)), keyEquivalent: "h")
            .withModifierMask([.command, .option]))
        menu.addItem(NSMenuItem(title: "Show All", action: #selector(NSApplication.unhideAllApplications(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Quit EOEL", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q"))

        return menu
    }

    private func createFileMenu() -> NSMenu {
        let menu = NSMenu(title: "File")

        menu.addItem(NSMenuItem(title: "New Project", action: #selector(AppDelegate.newProject), keyEquivalent: "n"))
        menu.addItem(NSMenuItem(title: "Open...", action: #selector(AppDelegate.openProject), keyEquivalent: "o"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Save", action: #selector(AppDelegate.saveProject), keyEquivalent: "s"))
        menu.addItem(NSMenuItem(title: "Save As...", action: #selector(AppDelegate.saveProjectAs), keyEquivalent: "S"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Export Audio...", action: #selector(AppDelegate.exportAudio), keyEquivalent: "e"))
        menu.addItem(NSMenuItem(title: "Export Session Data...", action: #selector(AppDelegate.exportSessionData), keyEquivalent: ""))

        return menu
    }

    private func createEditMenu() -> NSMenu {
        let menu = NSMenu(title: "Edit")

        menu.addItem(NSMenuItem(title: "Undo", action: #selector(UndoManager.undo), keyEquivalent: "z"))
        menu.addItem(NSMenuItem(title: "Redo", action: #selector(UndoManager.redo), keyEquivalent: "Z"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x"))
        menu.addItem(NSMenuItem(title: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c"))
        menu.addItem(NSMenuItem(title: "Paste", action: #selector(NSText.paste(_:)), keyEquivalent: "v"))
        menu.addItem(NSMenuItem(title: "Delete", action: #selector(NSText.delete(_:)), keyEquivalent: "\u{8}"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a"))

        return menu
    }

    private func createSessionMenu() -> NSMenu {
        let menu = NSMenu(title: "Session")

        menu.addItem(NSMenuItem(title: "Start Recording", action: #selector(AppDelegate.startRecording), keyEquivalent: "r"))
        menu.addItem(NSMenuItem(title: "Stop Recording", action: #selector(AppDelegate.stopRecording), keyEquivalent: "r")
            .withModifierMask([.command, .shift]))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Start Biofeedback Session", action: #selector(AppDelegate.startBioSession), keyEquivalent: "b"))
        menu.addItem(NSMenuItem(title: "Start Meditation", action: #selector(AppDelegate.startMeditation), keyEquivalent: "m"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Metronome", action: #selector(AppDelegate.toggleMetronome), keyEquivalent: "t"))

        return menu
    }

    private func createAudioMenu() -> NSMenu {
        let menu = NSMenu(title: "Audio")

        menu.addItem(NSMenuItem(title: "Audio Settings...", action: #selector(AppDelegate.showAudioSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "CoreAudio Devices...", action: #selector(AppDelegate.showCoreAudioDevices), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Buffer Size...", action: #selector(AppDelegate.showBufferSettings), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Enable/Disable All Plugins", action: #selector(AppDelegate.toggleAllPlugins), keyEquivalent: ""))

        return menu
    }

    private func createPluginsMenu() -> NSMenu {
        let menu = NSMenu(title: "Plugins")

        menu.addItem(NSMenuItem(title: "Scan for Audio Units", action: #selector(AppDelegate.scanPlugins), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Plugin Manager...", action: #selector(AppDelegate.showPluginManager), keyEquivalent: "p"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Add Effect", action: #selector(AppDelegate.addEffect), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Add Instrument", action: #selector(AppDelegate.addInstrument), keyEquivalent: ""))

        return menu
    }

    private func createBiofeedbackMenu() -> NSMenu {
        let menu = NSMenu(title: "Biofeedback")

        menu.addItem(NSMenuItem(title: "Enable HealthKit Monitoring", action: #selector(AppDelegate.enableHealthKit), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Enable Watch Sync", action: #selector(AppDelegate.enableWatchSync), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Show HRV Monitor", action: #selector(AppDelegate.showHRVMonitor), keyEquivalent: "h"))
        menu.addItem(NSMenuItem(title: "Show Coherence Visualization", action: #selector(AppDelegate.showCoherenceViz), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Export Biofeedback Data...", action: #selector(AppDelegate.exportBioData), keyEquivalent: ""))

        return menu
    }

    private func createWindowMenu() -> NSMenu {
        let menu = NSMenu(title: "Window")

        menu.addItem(NSMenuItem(title: "Minimize", action: #selector(NSWindow.miniaturize(_:)), keyEquivalent: "m"))
        menu.addItem(NSMenuItem(title: "Zoom", action: #selector(NSWindow.zoom(_:)), keyEquivalent: ""))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Show Mixer", action: #selector(AppDelegate.showMixer), keyEquivalent: "1"))
        menu.addItem(NSMenuItem(title: "Show Effects Rack", action: #selector(AppDelegate.showEffects), keyEquivalent: "2"))
        menu.addItem(NSMenuItem(title: "Show Instruments", action: #selector(AppDelegate.showInstruments), keyEquivalent: "3"))
        menu.addItem(NSMenuItem(title: "Show Visualizer", action: #selector(AppDelegate.showVisualizer), keyEquivalent: "4"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Workspace Layouts...", action: #selector(AppDelegate.showWorkspaceLayouts), keyEquivalent: "l"))
        menu.addItem(NSMenuItem.separator())
        menu.addItem(NSMenuItem(title: "Bring All to Front", action: #selector(NSApplication.arrangeInFront(_:)), keyEquivalent: ""))

        return menu
    }
}

extension NSMenuItem {
    func withModifierMask(_ mask: NSEvent.ModifierFlags) -> NSMenuItem {
        self.keyEquivalentModifierMask = mask
        return self
    }
}

// MARK: - AppDelegate Extensions (Selector Stubs)

@objc extension NSObject {
    @objc func showAbout() { print("Show About") }
    @objc func showPreferences() { print("Show Preferences") }
    @objc func newProject() { print("New Project") }
    @objc func openProject() { print("Open Project") }
    @objc func saveProject() { print("Save Project") }
    @objc func saveProjectAs() { print("Save Project As") }
    @objc func exportAudio() { print("Export Audio") }
    @objc func exportSessionData() { print("Export Session Data") }
    @objc func startRecording() { print("Start Recording") }
    @objc func stopRecording() { print("Stop Recording") }
    @objc func startBioSession() { print("Start Bio Session") }
    @objc func startMeditation() { print("Start Meditation") }
    @objc func toggleMetronome() { print("Toggle Metronome") }
    @objc func showAudioSettings() { print("Show Audio Settings") }
    @objc func showCoreAudioDevices() { print("Show CoreAudio Devices") }
    @objc func showBufferSettings() { print("Show Buffer Settings") }
    @objc func toggleAllPlugins() { print("Toggle All Plugins") }
    @objc func scanPlugins() { print("Scan Plugins") }
    @objc func showPluginManager() { print("Show Plugin Manager") }
    @objc func addEffect() { print("Add Effect") }
    @objc func addInstrument() { print("Add Instrument") }
    @objc func enableHealthKit() { print("Enable HealthKit") }
    @objc func enableWatchSync() { print("Enable Watch Sync") }
    @objc func showHRVMonitor() { print("Show HRV Monitor") }
    @objc func showCoherenceViz() { print("Show Coherence Viz") }
    @objc func exportBioData() { print("Export Bio Data") }
    @objc func showMixer() { print("Show Mixer") }
    @objc func showEffects() { print("Show Effects") }
    @objc func showInstruments() { print("Show Instruments") }
    @objc func showVisualizer() { print("Show Visualizer") }
    @objc func showWorkspaceLayouts() { print("Show Workspace Layouts") }
}

// MARK: - Touch Bar Manager

@available(macOS 10.12.2, *)
@MainActor
class TouchBarManager: NSObject, NSTouchBarDelegate {

    static let shared = TouchBarManager()

    private let touchBarIdentifier = NSTouchBar.CustomizationIdentifier("com.eoel.touchbar")

    // Touch Bar Item Identifiers
    private let recordButtonID = NSTouchBarItem.Identifier("com.eoel.record")
    private let playPauseButtonID = NSTouchBarItem.Identifier("com.eoel.playpause")
    private let metronomeButtonID = NSTouchBarItem.Identifier("com.eoel.metronome")
    private let coherenceSliderID = NSTouchBarItem.Identifier("com.eoel.coherence")
    private let volumeSliderID = NSTouchBarItem.Identifier("com.eoel.volume")
    private let hrvDisplayID = NSTouchBarItem.Identifier("com.eoel.hrv")

    func makeTouchBar() -> NSTouchBar {
        let touchBar = NSTouchBar()
        touchBar.delegate = self
        touchBar.customizationIdentifier = touchBarIdentifier
        touchBar.defaultItemIdentifiers = [
            recordButtonID,
            playPauseButtonID,
            .fixedSpaceSmall,
            metronomeButtonID,
            .flexibleSpace,
            hrvDisplayID,
            .fixedSpaceSmall,
            coherenceSliderID,
            .flexibleSpace,
            volumeSliderID
        ]
        touchBar.customizationAllowedItemIdentifiers = [
            recordButtonID,
            playPauseButtonID,
            metronomeButtonID,
            coherenceSliderID,
            volumeSliderID,
            hrvDisplayID
        ]

        return touchBar
    }

    func touchBar(_ touchBar: NSTouchBar, makeItemForIdentifier identifier: NSTouchBarItem.Identifier) -> NSTouchBarItem? {
        switch identifier {
        case recordButtonID:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(image: NSImage(systemSymbolName: "circle.fill", accessibilityDescription: "Record")!, target: self, action: #selector(recordTapped))
            button.bezelColor = .systemRed
            item.view = button
            return item

        case playPauseButtonID:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(image: NSImage(systemSymbolName: "play.fill", accessibilityDescription: "Play")!, target: self, action: #selector(playPauseTapped))
            item.view = button
            return item

        case metronomeButtonID:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let button = NSButton(image: NSImage(systemSymbolName: "metronome", accessibilityDescription: "Metronome")!, target: self, action: #selector(metronomeTapped))
            item.view = button
            return item

        case coherenceSliderID:
            let item = NSSliderTouchBarItem(identifier: identifier)
            item.label = "Coherence"
            item.slider.minValue = 0
            item.slider.maxValue = 100
            item.slider.doubleValue = 50
            item.target = self
            item.action = #selector(coherenceChanged)
            return item

        case volumeSliderID:
            let item = NSSliderTouchBarItem(identifier: identifier)
            item.label = "Volume"
            item.slider.minValue = 0
            item.slider.maxValue = 1
            item.slider.doubleValue = 0.8
            item.target = self
            item.action = #selector(volumeChanged)
            return item

        case hrvDisplayID:
            let item = NSCustomTouchBarItem(identifier: identifier)
            let label = NSTextField(labelWithString: "HRV: --")
            label.font = .monospacedDigitSystemFont(ofSize: 12, weight: .regular)
            item.view = label
            return item

        default:
            return nil
        }
    }

    @objc private func recordTapped() {
        print("🔴 Touch Bar: Record")
    }

    @objc private func playPauseTapped() {
        print("⏯️ Touch Bar: Play/Pause")
    }

    @objc private func metronomeTapped() {
        print("⏱️ Touch Bar: Metronome")
    }

    @objc private func coherenceChanged(_ sender: NSSlider) {
        print("🎚️ Touch Bar: Coherence = \(sender.doubleValue)")
    }

    @objc private func volumeChanged(_ sender: NSSlider) {
        print("🔊 Touch Bar: Volume = \(sender.doubleValue)")
    }

    func updateHRV(_ value: Double) {
        // Update HRV display on Touch Bar
        print("💓 Touch Bar: HRV = \(value)")
    }
}

// MARK: - macOS Native Window Manager

@MainActor
class macOSWindowManager: ObservableObject {

    static let shared = macOSWindowManager()

    @Published var windows: [EOELWindow] = []

    enum WindowType {
        case mixer
        case effects
        case instruments
        case visualizer
        case bioMonitor
        case pluginUI(name: String)
        case settings
    }

    struct EOELWindow: Identifiable {
        let id = UUID()
        let type: WindowType
        let window: NSWindow
        var isVisible: Bool = true
    }

    func createWindow(type: WindowType, title: String, size: CGSize) -> NSWindow {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: size.width, height: size.height),
            styleMask: [.titled, .closable, .miniaturizable, .resizable],
            backing: .buffered,
            defer: false
        )

        window.title = title
        window.center()
        window.setFrameAutosaveName(title)
        window.isReleasedWhenClosed = false

        // Configure window appearance
        window.titlebarAppearsTransparent = true
        window.toolbarStyle = .unified

        let eoelWindow = EOELWindow(type: type, window: window)
        windows.append(eoelWindow)

        print("🪟 Created window: \(title)")
        return window
    }

    func showMixerWindow() -> NSWindow {
        if let existing = windows.first(where: {
            if case .mixer = $0.type { return true }
            return false
        }) {
            existing.window.makeKeyAndOrderFront(nil)
            return existing.window
        }

        let window = createWindow(type: .mixer, title: "Mixer", size: CGSize(width: 800, height: 600))
        window.makeKeyAndOrderFront(nil)
        return window
    }

    func showEffectsRack() -> NSWindow {
        if let existing = windows.first(where: {
            if case .effects = $0.type { return true }
            return false
        }) {
            existing.window.makeKeyAndOrderFront(nil)
            return existing.window
        }

        let window = createWindow(type: .effects, title: "Effects Rack", size: CGSize(width: 400, height: 800))
        window.makeKeyAndOrderFront(nil)
        return window
    }

    func showVisualizerWindow() -> NSWindow {
        if let existing = windows.first(where: {
            if case .visualizer = $0.type { return true }
            return false
        }) {
            existing.window.makeKeyAndOrderFront(nil)
            return existing.window
        }

        let window = createWindow(type: .visualizer, title: "Visualizer", size: CGSize(width: 1024, height: 768))
        window.makeKeyAndOrderFront(nil)
        return window
    }

    func showBioMonitorWindow() -> NSWindow {
        if let existing = windows.first(where: {
            if case .bioMonitor = $0.type { return true }
            return false
        }) {
            existing.window.makeKeyAndOrderFront(nil)
            return existing.window
        }

        let window = createWindow(type: .bioMonitor, title: "Biofeedback Monitor", size: CGSize(width: 600, height: 400))
        window.makeKeyAndOrderFront(nil)
        return window
    }

    func showPluginUI(name: String, viewController: NSViewController) -> NSWindow {
        let window = createWindow(type: .pluginUI(name: name), title: name, size: CGSize(width: 800, height: 600))
        window.contentViewController = viewController
        window.makeKeyAndOrderFront(nil)
        return window
    }
}

// MARK: - Keyboard Shortcuts Manager

@MainActor
class KeyboardShortcutsManager {

    static let shared = KeyboardShortcutsManager()

    func setupGlobalShortcuts() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            return self.handleKeyEvent(event) ?? event
        }

        print("⌨️ macOS keyboard shortcuts configured")
    }

    private func handleKeyEvent(_ event: NSEvent) -> NSEvent? {
        let flags = event.modifierFlags.intersection(.deviceIndependentFlagsMask)

        // Command key shortcuts
        if flags.contains(.command) {
            switch event.charactersIgnoringModifiers {
            case "r":
                if flags.contains(.shift) {
                    print("⏹️ Stop Recording (⌘⇧R)")
                } else {
                    print("🔴 Start Recording (⌘R)")
                }
                return nil

            case " ":
                print("⏯️ Play/Pause (⌘Space)")
                return nil

            case "b":
                print("🫀 Toggle Biofeedback (⌘B)")
                return nil

            case "m":
                if flags.contains(.shift) {
                    print("🔇 Mute All (⌘⇧M)")
                } else {
                    print("⏱️ Toggle Metronome (⌘M)")
                }
                return nil

            default:
                break
            }
        }

        // Option key shortcuts (alternative functions)
        if flags.contains(.option) {
            switch event.charactersIgnoringModifiers {
            case "v":
                print("🎨 Toggle Visualizer (⌥V)")
                return nil

            case "h":
                print("📊 Toggle HRV Display (⌥H)")
                return nil

            default:
                break
            }
        }

        return event
    }
}

#endif
