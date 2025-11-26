//
//  MultiMonitorManager.swift
//  EOEL
//
//  Created: 2025-11-26
//  Copyright © 2025 EOEL. All rights reserved.
//
//  MULTI-MONITOR WORKSPACE MANAGEMENT
//  Professional multi-display layouts for complex workflows
//

#if os(macOS)
import Foundation
import AppKit
import Combine

/// Manages multi-monitor workspace layouts for professional workflows
///
/// **Features:**
/// - Auto-detect all displays
/// - Predefined workspace layouts
/// - Custom window arrangements
/// - Layout save/restore
/// - Per-display window management
/// - Full-screen mode per display
///
/// **Professional Use Cases:**
/// - Mixer on main display, effects on secondary
/// - Visualizer on external projector
/// - Bio-data monitoring on dedicated screen
/// - Plugin GUIs on tertiary display
///
@MainActor
class MultiMonitorManager: ObservableObject {

    // MARK: - Published Properties

    /// All available displays
    @Published var availableDisplays: [DisplayInfo] = []

    /// Main display (primary)
    @Published var mainDisplay: DisplayInfo?

    /// Active workspace layout
    @Published var activeWorkspace: WorkspaceLayout?

    /// All windows managed by the system
    @Published var managedWindows: [ManagedWindow] = []

    // MARK: - Private Properties

    private var displayObserver: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Display Info

    struct DisplayInfo: Identifiable, Hashable {
        let id: CGDirectDisplayID
        let name: String
        let frame: CGRect
        let isMain: Bool
        let scaleFactor: CGFloat
        let resolution: CGSize
        let refreshRate: Double

        var description: String {
            "\(name) (\(Int(resolution.width))x\(Int(resolution.height)) @ \(Int(refreshRate))Hz)"
        }

        var isProfessionalGrade: Bool {
            // Consider 4K+ as professional grade
            return resolution.width >= 3840 || resolution.height >= 2160
        }
    }

    // MARK: - Workspace Layout

    struct WorkspaceLayout: Identifiable, Codable {
        let id: UUID
        let name: String
        let windows: [WindowPlacement]
        let createdAt: Date

        enum LayoutType: String, Codable {
            case production = "Music Production"
            case mixing = "Mixing & Mastering"
            case performance = "Live Performance"
            case therapy = "Therapeutic Session"
            case visualization = "Visualization Studio"
            case custom = "Custom"
        }

        let type: LayoutType
    }

    struct WindowPlacement: Codable, Hashable {
        let windowType: WindowType
        let displayID: CGDirectDisplayID
        let frame: CGRect
        let isFullScreen: Bool

        enum WindowType: String, Codable {
            case mixer = "Mixer"
            case effects = "Effects Rack"
            case instruments = "Instruments"
            case piano = "Piano Roll"
            case arrangement = "Arrangement View"
            case bioData = "Bio-Data Monitor"
            case visualizer = "Visualizer"
            case pluginUI = "Plugin UI"
            case browser = "Browser"
            case inspector = "Inspector"
        }
    }

    // MARK: - Managed Window

    struct ManagedWindow: Identifiable {
        let id = UUID()
        let window: NSWindow
        let type: WindowPlacement.WindowType
        var displayID: CGDirectDisplayID
        var isFullScreen: Bool = false
    }

    // MARK: - Predefined Layouts

    static let predefinedLayouts: [WorkspaceLayout.LayoutType: String] = [
        .production: "Mixer (Main) + Effects (Secondary) + Visualizer (Tertiary)",
        .mixing: "Mixer (Main) + Plugin UIs (Secondary)",
        .performance: "Instruments (Main) + Visualizer (External Projector)",
        .therapy: "Bio-Data (Main) + Visualizer (External)",
        .visualization: "Visualizer (All Displays)"
    ]

    // MARK: - Initialization

    init() {
        scanDisplays()
        observeDisplayChanges()
    }

    // MARK: - Display Management

    /// Scan for all connected displays
    func scanDisplays() {
        var displays: [DisplayInfo] = []

        let maxDisplays: UInt32 = 16
        var displayIDs = [CGDirectDisplayID](repeating: 0, count: Int(maxDisplays))
        var displayCount: UInt32 = 0

        let result = CGGetActiveDisplayList(maxDisplays, &displayIDs, &displayCount)

        guard result == .success else {
            print("❌ Failed to get display list")
            return
        }

        let mainDisplayID = CGMainDisplayID()

        for i in 0..<Int(displayCount) {
            let displayID = displayIDs[i]

            // Get display bounds
            let bounds = CGDisplayBounds(displayID)

            // Get display mode for resolution and refresh rate
            guard let mode = CGDisplayCopyDisplayMode(displayID) else { continue }

            let resolution = CGSize(
                width: CGFloat(mode.width),
                height: CGFloat(mode.height)
            )

            let refreshRate = mode.refreshRate

            // Get display name (simplified - real implementation would query IOKit)
            let name = getDisplayName(displayID: displayID)

            // Get scale factor
            let scaleFactor = CGFloat(mode.pixelWidth) / CGFloat(mode.width)

            let displayInfo = DisplayInfo(
                id: displayID,
                name: name,
                frame: bounds,
                isMain: displayID == mainDisplayID,
                scaleFactor: scaleFactor,
                resolution: resolution,
                refreshRate: refreshRate
            )

            displays.append(displayInfo)
        }

        availableDisplays = displays.sorted { $0.isMain && !$1.isMain }
        mainDisplay = displays.first { $0.isMain }

        print("🖥️ Found \(displays.count) display(s):")
        for display in displays {
            print("   \(display.isMain ? "🌟" : "  ") \(display.description)")
        }
    }

    private func getDisplayName(displayID: CGDirectDisplayID) -> String {
        // Simplified - real implementation would query IOKit for actual display name
        if CGDisplayIsMain(displayID) != 0 {
            return "Main Display"
        } else {
            return "Display \(displayID)"
        }
    }

    private func observeDisplayChanges() {
        // Observe display configuration changes
        displayObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.scanDisplays()
            self?.reapplyWorkspace()
        }
    }

    // MARK: - Window Management

    /// Register a window for management
    func registerWindow(_ window: NSWindow, type: WindowPlacement.WindowType) {
        let displayID = getDisplayForWindow(window)

        let managedWindow = ManagedWindow(
            window: window,
            type: type,
            displayID: displayID
        )

        managedWindows.append(managedWindow)
        print("📋 Registered window: \(type.rawValue)")
    }

    /// Move window to specific display
    func moveWindow(_ window: ManagedWindow, to display: DisplayInfo) {
        let displayFrame = display.frame

        // Center window on target display
        let windowSize = window.window.frame.size
        let newOrigin = CGPoint(
            x: displayFrame.midX - windowSize.width / 2,
            y: displayFrame.midY - windowSize.height / 2
        )

        window.window.setFrameOrigin(newOrigin)

        // Update managed window
        if let index = managedWindows.firstIndex(where: { $0.id == window.id }) {
            managedWindows[index].displayID = display.id
        }

        print("🪟 Moved \(window.type.rawValue) to \(display.name)")
    }

    /// Maximize window on its current display
    func maximizeWindow(_ window: ManagedWindow) {
        guard let display = availableDisplays.first(where: { $0.id == window.displayID }) else {
            return
        }

        let displayFrame = display.frame

        // Account for menu bar on main display
        var targetFrame = displayFrame
        if display.isMain {
            targetFrame.size.height -= 25 // Menu bar height
        }

        window.window.setFrame(targetFrame, display: true)
        print("⬜ Maximized \(window.type.rawValue) on \(display.name)")
    }

    /// Toggle full-screen for window
    func toggleFullScreen(_ window: ManagedWindow) {
        window.window.toggleFullScreen(nil)

        if let index = managedWindows.firstIndex(where: { $0.id == window.id }) {
            managedWindows[index].isFullScreen.toggle()
        }

        print("🖼️ Toggled full-screen: \(window.type.rawValue)")
    }

    private func getDisplayForWindow(_ window: NSWindow) -> CGDirectDisplayID {
        guard let screen = window.screen else {
            return CGMainDisplayID()
        }

        // Find display ID for NSScreen
        // This is simplified - real implementation would map NSScreen to CGDirectDisplayID
        for display in availableDisplays {
            if screen.frame == display.frame {
                return display.id
            }
        }

        return CGMainDisplayID()
    }

    // MARK: - Workspace Layouts

    /// Apply a predefined workspace layout
    func applyLayout(_ layout: WorkspaceLayout) {
        print("🎨 Applying workspace layout: \(layout.name)")

        for placement in layout.windows {
            // Find window of this type
            guard let window = managedWindows.first(where: { $0.type == placement.windowType }) else {
                print("   ⚠️ No window for \(placement.windowType.rawValue)")
                continue
            }

            // Find target display
            guard let display = availableDisplays.first(where: { $0.id == placement.displayID }) else {
                print("   ⚠️ Display \(placement.displayID) not found")
                continue
            }

            // Apply placement
            window.window.setFrame(placement.frame, display: true)

            if placement.isFullScreen && !window.isFullScreen {
                toggleFullScreen(window)
            }

            print("   ✅ \(placement.windowType.rawValue) → \(display.name)")
        }

        activeWorkspace = layout
    }

    /// Create a layout from current window positions
    func captureCurrentLayout(name: String, type: WorkspaceLayout.LayoutType) -> WorkspaceLayout {
        var placements: [WindowPlacement] = []

        for window in managedWindows {
            let placement = WindowPlacement(
                windowType: window.type,
                displayID: window.displayID,
                frame: window.window.frame,
                isFullScreen: window.isFullScreen
            )
            placements.append(placement)
        }

        let layout = WorkspaceLayout(
            id: UUID(),
            name: name,
            windows: placements,
            createdAt: Date(),
            type: type
        )

        print("📸 Captured workspace layout: \(name)")
        return layout
    }

    /// Save workspace layout to disk
    func saveLayout(_ layout: WorkspaceLayout) throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        let data = try encoder.encode(layout)

        let url = getLayoutsDirectory().appendingPathComponent("\(layout.id.uuidString).json")
        try data.write(to: url)

        print("💾 Saved workspace layout: \(layout.name)")
    }

    /// Load workspace layout from disk
    func loadLayout(id: UUID) throws -> WorkspaceLayout {
        let url = getLayoutsDirectory().appendingPathComponent("\(id.uuidString).json")
        let data = try Data(contentsOf: url)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        let layout = try decoder.decode(WorkspaceLayout.self, from: data)

        print("📂 Loaded workspace layout: \(layout.name)")
        return layout
    }

    /// Get all saved layouts
    func getSavedLayouts() throws -> [WorkspaceLayout] {
        let layoutsDir = getLayoutsDirectory()

        let files = try FileManager.default.contentsOfDirectory(
            at: layoutsDir,
            includingPropertiesForKeys: nil
        )

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        var layouts: [WorkspaceLayout] = []

        for file in files where file.pathExtension == "json" {
            if let data = try? Data(contentsOf: file),
               let layout = try? decoder.decode(WorkspaceLayout.self, from: data) {
                layouts.append(layout)
            }
        }

        return layouts.sorted { $0.createdAt > $1.createdAt }
    }

    private func getLayoutsDirectory() -> URL {
        let appSupport = FileManager.default.urls(
            for: .applicationSupportDirectory,
            in: .userDomainMask
        ).first!

        let layoutsDir = appSupport
            .appendingPathComponent("EOEL")
            .appendingPathComponent("Workspaces")

        try? FileManager.default.createDirectory(
            at: layoutsDir,
            withIntermediateDirectories: true
        )

        return layoutsDir
    }

    private func reapplyWorkspace() {
        guard let workspace = activeWorkspace else { return }
        applyLayout(workspace)
    }

    // MARK: - Quick Layouts

    /// Create standard production layout
    func createProductionLayout() -> WorkspaceLayout? {
        guard availableDisplays.count >= 2 else {
            print("⚠️ Production layout requires at least 2 displays")
            return nil
        }

        let mainDisplay = availableDisplays[0]
        let secondaryDisplay = availableDisplays[1]

        let placements: [WindowPlacement] = [
            WindowPlacement(
                windowType: .mixer,
                displayID: mainDisplay.id,
                frame: mainDisplay.frame,
                isFullScreen: false
            ),
            WindowPlacement(
                windowType: .effects,
                displayID: secondaryDisplay.id,
                frame: secondaryDisplay.frame,
                isFullScreen: false
            )
        ]

        return WorkspaceLayout(
            id: UUID(),
            name: "Music Production",
            windows: placements,
            createdAt: Date(),
            type: .production
        )
    }

    /// Create visualization layout (all displays show visualizer)
    func createVisualizationLayout() -> WorkspaceLayout {
        var placements: [WindowPlacement] = []

        for display in availableDisplays {
            placements.append(WindowPlacement(
                windowType: .visualizer,
                displayID: display.id,
                frame: display.frame,
                isFullScreen: true
            ))
        }

        return WorkspaceLayout(
            id: UUID(),
            name: "Visualization Studio",
            windows: placements,
            createdAt: Date(),
            type: .visualization
        )
    }

    /// Create therapy layout (bio-data + visualizer on separate displays)
    func createTherapyLayout() -> WorkspaceLayout? {
        guard availableDisplays.count >= 2 else {
            print("⚠️ Therapy layout requires at least 2 displays")
            return nil
        }

        let mainDisplay = availableDisplays[0]
        let secondaryDisplay = availableDisplays[1]

        let placements: [WindowPlacement] = [
            WindowPlacement(
                windowType: .bioData,
                displayID: mainDisplay.id,
                frame: mainDisplay.frame,
                isFullScreen: false
            ),
            WindowPlacement(
                windowType: .visualizer,
                displayID: secondaryDisplay.id,
                frame: secondaryDisplay.frame,
                isFullScreen: true
            )
        ]

        return WorkspaceLayout(
            id: UUID(),
            name: "Therapeutic Session",
            windows: placements,
            createdAt: Date(),
            type: .therapy
        )
    }

    // MARK: - Cleanup

    deinit {
        if let observer = displayObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }
}

#endif
