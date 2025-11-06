import SwiftUI

#if targetEnvironment(macCatalyst)
import UIKit
#endif

/// Keyboard shortcuts for Mac Catalyst
///
/// **Purpose:** Native Mac keyboard experience for Echoelmusic
///
/// **Shortcuts:**
/// - Cmd+N: New session
/// - Cmd+S: Start/Stop recording
/// - Cmd+P: Play/Pause
/// - Cmd+,: Settings
/// - Cmd+1-5: Switch tabs
/// - Space: Quick breathing exercise
/// - Cmd+D: Audio device selection
/// - Cmd+F: Toggle fullscreen
/// - Cmd+M: Minimize window
/// - Cmd+W: Close window
///
/// **Platform:** macOS only (via Catalyst)
///
public struct MacKeyboardShortcuts {

    #if targetEnvironment(macCatalyst)

    /// Setup all keyboard shortcuts for Mac
    public static func setupShortcuts() -> some Commands {
        Group {
            // File Menu
            CommandGroup(after: .newItem) {
                Button("New Session") {
                    NotificationCenter.default.post(name: .macNewSession, object: nil)
                }
                .keyboardShortcut("n", modifiers: .command)

                Button("Start Recording") {
                    NotificationCenter.default.post(name: .macToggleRecording, object: nil)
                }
                .keyboardShortcut("s", modifiers: .command)
            }

            // View Menu
            CommandMenu("View") {
                Button("Dashboard") {
                    NotificationCenter.default.post(name: .macSwitchTab, object: 0)
                }
                .keyboardShortcut("1", modifiers: .command)

                Button("Breathing") {
                    NotificationCenter.default.post(name: .macSwitchTab, object: 1)
                }
                .keyboardShortcut("2", modifiers: .command)

                Button("Spatial Audio") {
                    NotificationCenter.default.post(name: .macSwitchTab, object: 2)
                }
                .keyboardShortcut("3", modifiers: .command)

                Button("Biofeedback") {
                    NotificationCenter.default.post(name: .macSwitchTab, object: 3)
                }
                .keyboardShortcut("4", modifiers: .command)

                Button("Settings") {
                    NotificationCenter.default.post(name: .macSwitchTab, object: 4)
                }
                .keyboardShortcut("5", modifiers: .command)

                Divider()

                Button("Toggle Fullscreen") {
                    NotificationCenter.default.post(name: .macToggleFullscreen, object: nil)
                }
                .keyboardShortcut("f", modifiers: .command)
            }

            // Audio Menu
            CommandMenu("Audio") {
                Button("Select Audio Device...") {
                    NotificationCenter.default.post(name: .macShowAudioDevices, object: nil)
                }
                .keyboardShortcut("d", modifiers: .command)

                Divider()

                Button("Increase Volume") {
                    NotificationCenter.default.post(name: .macVolumeUp, object: nil)
                }
                .keyboardShortcut("+", modifiers: .command)

                Button("Decrease Volume") {
                    NotificationCenter.default.post(name: .macVolumeDown, object: nil)
                }
                .keyboardShortcut("-", modifiers: .command)

                Button("Mute") {
                    NotificationCenter.default.post(name: .macToggleMute, object: nil)
                }
                .keyboardShortcut("m", modifiers: [.command, .shift])
            }

            // Session Menu
            CommandMenu("Session") {
                Button("Play/Pause") {
                    NotificationCenter.default.post(name: .macTogglePlayPause, object: nil)
                }
                .keyboardShortcut(.space, modifiers: [])

                Button("Quick Breathing Exercise") {
                    NotificationCenter.default.post(name: .macQuickBreathing, object: nil)
                }
                .keyboardShortcut("b", modifiers: [.command, .shift])

                Divider()

                Button("Export Session Data") {
                    NotificationCenter.default.post(name: .macExportData, object: nil)
                }
                .keyboardShortcut("e", modifiers: .command)
            }

            // Window Menu
            CommandGroup(after: .windowSize) {
                Button("Minimize") {
                    NotificationCenter.default.post(name: .macMinimizeWindow, object: nil)
                }
                .keyboardShortcut("m", modifiers: .command)

                Button("Zoom") {
                    NotificationCenter.default.post(name: .macZoomWindow, object: nil)
                }
            }

            // Help Menu
            CommandGroup(after: .help) {
                Button("Echoelmusic Help") {
                    NotificationCenter.default.post(name: .macShowHelp, object: nil)
                }
                .keyboardShortcut("?", modifiers: .command)
            }
        }
    }

    #else

    // Non-Mac platforms: empty commands
    public static func setupShortcuts() -> some Commands {
        EmptyCommands()
    }

    #endif
}

// MARK: - Notification Names

public extension Notification.Name {
    // Session
    static let macNewSession = Notification.Name("macNewSession")
    static let macToggleRecording = Notification.Name("macToggleRecording")
    static let macTogglePlayPause = Notification.Name("macTogglePlayPause")
    static let macQuickBreathing = Notification.Name("macQuickBreathing")
    static let macExportData = Notification.Name("macExportData")

    // View
    static let macSwitchTab = Notification.Name("macSwitchTab")
    static let macToggleFullscreen = Notification.Name("macToggleFullscreen")

    // Audio
    static let macShowAudioDevices = Notification.Name("macShowAudioDevices")
    static let macVolumeUp = Notification.Name("macVolumeUp")
    static let macVolumeDown = Notification.Name("macVolumeDown")
    static let macToggleMute = Notification.Name("macToggleMute")

    // Window
    static let macMinimizeWindow = Notification.Name("macMinimizeWindow")
    static let macZoomWindow = Notification.Name("macZoomWindow")

    // Help
    static let macShowHelp = Notification.Name("macShowHelp")
}
