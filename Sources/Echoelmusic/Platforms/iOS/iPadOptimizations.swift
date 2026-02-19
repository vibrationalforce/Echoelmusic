import Foundation
#if canImport(UIKit)
import UIKit
#endif
import SwiftUI
import Combine

#if os(iOS)

/// iPad-spezifische Optimierungen für Echoelmusic
///
/// iPad bietet einzigartige Möglichkeiten:
/// - **Größeres Display**: 11" - 12.9" für bessere Visualisierungen
/// - **Split View**: Musik erstellen während Bio-Daten beobachten
/// - **Stage Manager**: Mehrere Fenster gleichzeitig
/// - **Apple Pencil**: Präzise Steuerung von Parametern
/// - **Keyboard Support**: Shortcuts für professionelle Workflows
/// - **External Display**: Bis zu 6K externe Displays
/// - **ProMotion**: 120Hz für flüssigere Animationen
///
/// Use Cases:
/// - Professional Music Production: Großes Canvas für Arrangement
/// - Therapy Sessions: Therapeut sieht Bio-Daten, Patient sieht Visualisierung
/// - Teaching: Lehrer nutzt iPad als Kontrollzentrum
/// - Presentations: Externe Displays für Publikum
/// - Field Recording: Mobile Studio mit großem Interface
///
@MainActor
class iPadOptimizations: ObservableObject {

    // MARK: - Published Properties

    /// Ist dies ein iPad?
    @Published var isiPad: Bool = UIDevice.current.userInterfaceIdiom == .pad

    /// iPad-Modell
    @Published var iPadModel: iPadModel?

    /// Split View aktiv?
    @Published var isSplitViewActive: Bool = false

    /// Stage Manager aktiv?
    @Published var isStageManagerActive: Bool = false

    /// Apple Pencil verbunden?
    @Published var isApplePencilConnected: Bool = false

    /// Externes Display verbunden?
    @Published var externalDisplayConnected: Bool = false

    /// ProMotion verfügbar?
    @Published var supportsProMotion: Bool = false

    /// Layout-Modus
    @Published var layoutMode: LayoutMode = .standard

    // MARK: - Screen Helper

    /// Future-proof screen bounds accessor — prefers window scene screen over deprecated UIScreen.main
    @MainActor
    static var currentScreenBounds: CGRect {
        if let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first {
            return windowScene.screen.bounds
        }
        return UIScreen.main.bounds
    }

    // MARK: - Private Properties

    private let windowSceneManager: WindowSceneManager
    private let pencilInteractionManager: PencilInteractionManager
    private let keyboardShortcutManager: KeyboardShortcutManager
    private let externalDisplayManager: ExternalDisplayManager

    private var cancellables = Set<AnyCancellable>()

    // MARK: - iPad Model

    enum iPadModel: String {
        case iPadPro12_9_inch = "iPad Pro 12.9\""
        case iPadPro11_inch = "iPad Pro 11\""
        case iPadAir = "iPad Air"
        case iPad = "iPad"
        case iPadMini = "iPad mini"

        var screenSize: CGSize {
            switch self {
            case .iPadPro12_9_inch: return CGSize(width: 2048, height: 2732)
            case .iPadPro11_inch: return CGSize(width: 1668, height: 2388)
            case .iPadAir: return CGSize(width: 1640, height: 2360)
            case .iPad: return CGSize(width: 1620, height: 2160)
            case .iPadMini: return CGSize(width: 1488, height: 2266)
            }
        }

        var supportsProMotion: Bool {
            switch self {
            case .iPadPro12_9_inch, .iPadPro11_inch:
                return true
            default:
                return false
            }
        }

        var supportsApplePencil2: Bool {
            switch self {
            case .iPadPro12_9_inch, .iPadPro11_inch, .iPadAir:
                return true
            default:
                return false
            }
        }
    }

    // MARK: - Layout Mode

    enum LayoutMode: String, CaseIterable {
        case standard = "Standard"
        case splitView = "Split View"
        case stageManager = "Stage Manager"
        case externalDisplay = "Externes Display"
        case fullscreen = "Vollbild"

        var description: String {
            switch self {
            case .standard:
                return "Standard iPad-Layout"
            case .splitView:
                return "Zwei Apps nebeneinander (50/50 oder 70/30)"
            case .stageManager:
                return "Mehrere überlappende Fenster"
            case .externalDisplay:
                return "Erweitertes Display oder Spiegelung"
            case .fullscreen:
                return "Vollbild ohne Ablenkungen"
            }
        }

        var recommendedForTask: [TaskType] {
            switch self {
            case .standard:
                return [.meditation, .breathing, .casualListening]
            case .splitView:
                return [.musicProduction, .therapy, .learning]
            case .stageManager:
                return [.professionalProduction, .djing, .teaching]
            case .externalDisplay:
                return [.performance, .presentation, .therapy]
            case .fullscreen:
                return [.meditation, .deepFocus, .performance]
            }
        }

        enum TaskType {
            case meditation, breathing, casualListening
            case musicProduction, therapy, learning
            case professionalProduction, djing, teaching
            case performance, presentation, deepFocus
        }
    }

    // MARK: - Split View Configuration

    struct SplitViewConfiguration {
        var primaryPane: PaneContent
        var secondaryPane: PaneContent
        var splitRatio: SplitRatio

        enum PaneContent {
            case bioDataMonitor
            case visualizer
            case mixer
            case effects
            case instruments
            case arrangement
            case piano
            case drumPads
        }

        enum SplitRatio {
            case equal // 50/50
            case primaryLarger // 70/30
            case secondaryLarger // 30/70
        }
    }

    // MARK: - Initialization

    init() {
        self.windowSceneManager = WindowSceneManager()
        self.pencilInteractionManager = PencilInteractionManager()
        self.keyboardShortcutManager = KeyboardShortcutManager()
        self.externalDisplayManager = ExternalDisplayManager()

        detectiPadModel()
        setupObservers()
        setupKeyboardShortcuts()
    }

    private func detectiPadModel() {
        guard isiPad else { return }

        let screenSize = Self.currentScreenBounds.size
        let maxDimension = max(screenSize.width, screenSize.height)

        switch maxDimension {
        case 1366: // 2732 / 2 (scale factor 2)
            iPadModel = .iPadPro12_9_inch
        case 1194: // 2388 / 2
            iPadModel = .iPadPro11_inch
        case 1180: // 2360 / 2
            iPadModel = .iPadAir
        case 1080: // 2160 / 2
            iPadModel = .iPad
        case 1133: // 2266 / 2
            iPadModel = .iPadMini
        default:
            iPadModel = .iPad
        }

        supportsProMotion = iPadModel?.supportsProMotion ?? false

        log.performance("📱 Detected iPad: \(iPadModel?.rawValue ?? "Unknown")")
    }

    private func setupObservers() {
        // Beobachte Split View Changes
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                self?.detectSplitView()
            }
            .store(in: &cancellables)

        // Beobachte External Display
        NotificationCenter.default.publisher(for: UIScreen.didConnectNotification)
            .sink { [weak self] notification in
                self?.handleExternalDisplayConnected(notification)
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UIScreen.didDisconnectNotification)
            .sink { [weak self] _ in
                self?.externalDisplayConnected = false
            }
            .store(in: &cancellables)

        // Beobachte Apple Pencil
        if #available(iOS 12.1, *) {
            pencilInteractionManager.pencilConnectedPublisher
                .sink { [weak self] connected in
                    self?.isApplePencilConnected = connected
                }
                .store(in: &cancellables)
        }
    }

    // MARK: - Split View Detection

    private func detectSplitView() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let window = windowScene.windows.first else {
            return
        }

        let screenWidth = Self.currentScreenBounds.width
        let windowWidth = window.frame.width

        // Wenn Window schmaler als Screen → Split View
        isSplitViewActive = windowWidth < screenWidth

        // Detect Stage Manager (iPadOS 16+)
        if #available(iOS 16.0, *) {
            // Stage Manager detection
            // Multiple windows visible = Stage Manager
            isStageManagerActive = windowScene.windows.count > 1
        }

        if isSplitViewActive {
            layoutMode = .splitView
        } else if isStageManagerActive {
            layoutMode = .stageManager
        } else {
            layoutMode = .standard
        }
    }

    // MARK: - Split View Configuration

    func configureSplitView(config: SplitViewConfiguration) {
        log.performance("📱 Configuring Split View: \(config.primaryPane) | \(config.secondaryPane)")
        // Konfiguriere UI basierend auf Split View Setup
    }

    func suggestOptimalLayout(for task: LayoutMode.TaskType) -> SplitViewConfiguration {
        switch task {
        case .musicProduction:
            return SplitViewConfiguration(
                primaryPane: .mixer,
                secondaryPane: .effects,
                splitRatio: .primaryLarger
            )

        case .therapy:
            return SplitViewConfiguration(
                primaryPane: .bioDataMonitor,
                secondaryPane: .visualizer,
                splitRatio: .equal
            )

        case .learning:
            return SplitViewConfiguration(
                primaryPane: .piano,
                secondaryPane: .bioDataMonitor,
                splitRatio: .primaryLarger
            )

        default:
            return SplitViewConfiguration(
                primaryPane: .visualizer,
                secondaryPane: .mixer,
                splitRatio: .equal
            )
        }
    }

    // MARK: - Keyboard Shortcuts

    private func setupKeyboardShortcuts() {
        keyboardShortcutManager.registerShortcuts([
            // Playback
            KeyboardShortcut(key: .space, modifiers: [], action: .playPause),
            KeyboardShortcut(key: .r, modifiers: [.command], action: .record),

            // Navigation
            KeyboardShortcut(key: .leftArrow, modifiers: [.command], action: .previousTrack),
            KeyboardShortcut(key: .rightArrow, modifiers: [.command], action: .nextTrack),

            // Mixing
            KeyboardShortcut(key: .m, modifiers: [.command], action: .mute),
            KeyboardShortcut(key: .s, modifiers: [.command], action: .solo),

            // Windows
            KeyboardShortcut(key: .one, modifiers: [.command], action: .showMixer),
            KeyboardShortcut(key: .two, modifiers: [.command], action: .showEffects),
            KeyboardShortcut(key: .three, modifiers: [.command], action: .showBioData),

            // Layout
            KeyboardShortcut(key: .f, modifiers: [.command, .control], action: .toggleFullscreen),
        ])
    }

    struct KeyboardShortcut {
        let key: Key
        let modifiers: [Modifier]
        let action: Action

        enum Key: String {
            case space = " "
            case r, m, s, f
            case one = "1"
            case two = "2"
            case three = "3"
            case leftArrow = "←"
            case rightArrow = "→"
        }

        enum Modifier {
            case command, option, control, shift
        }

        enum Action {
            case playPause, record, stop
            case previousTrack, nextTrack
            case mute, solo
            case showMixer, showEffects, showBioData
            case toggleFullscreen
        }
    }

    // MARK: - Apple Pencil Support

    func enablePencilControl(for parameter: ControlParameter) {
        log.performance("✏️ Apple Pencil control enabled for: \(parameter)")
        pencilInteractionManager.bindParameter(parameter)
    }

    enum ControlParameter {
        case filterCutoff
        case resonance
        case volume
        case pan
        case reverbMix
        case delayTime
        case distortion
    }

    // MARK: - External Display

    private func handleExternalDisplayConnected(_ notification: Notification) {
        guard let screen = notification.object as? UIScreen else { return }

        externalDisplayConnected = true
        layoutMode = .externalDisplay

        log.performance("📺 External display connected: \(screen.bounds.size)")

        externalDisplayManager.setupExternalDisplay(screen: screen)
    }

    func configureExternalDisplay(mode: ExternalDisplayMode) {
        externalDisplayManager.setMode(mode)
    }

    enum ExternalDisplayMode {
        case mirror // Spiegeln des iPad-Bildschirms
        case extended // Erweiterter Desktop
        case visualizerOnly // Nur Visualisierung auf externem Display
        case audienceView // Publikums-Ansicht (für Performances)
        case therapistView // Therapeuten-Ansicht (für Therapy Sessions)
    }

    // MARK: - Performance Optimizations

    func optimizeForProMotion() {
        guard supportsProMotion else { return }

        // Aktiviere 120Hz Updates
        if let displayLink = CADisplayLink(target: self, selector: #selector(updateFor120Hz)) {
            displayLink.preferredFramesPerSecond = 120
            displayLink.add(to: .main, forMode: .default)
            log.performance("⚡ ProMotion 120Hz enabled")
        }
    }

    @objc private func updateFor120Hz() {
        // Update Visualisierungen mit 120fps
    }
}

// MARK: - Window Scene Manager

@MainActor
class WindowSceneManager {
    func createNewWindow(for content: iPadOptimizations.SplitViewConfiguration.PaneContent) {
        log.performance("🪟 Creating new window for: \(content)")
    }
}

// MARK: - Pencil Interaction Manager

@MainActor
class PencilInteractionManager {

    let pencilConnectedPublisher = PassthroughSubject<Bool, Never>()

    init() {
        if #available(iOS 12.1, *) {
            // Setup Apple Pencil interaction
            detectApplePencil()
        }
    }

    private func detectApplePencil() {
        // Detect if Apple Pencil is connected
        // This would typically use UIPencilInteraction
    }

    func bindParameter(_ parameter: iPadOptimizations.ControlParameter) {
        log.performance("✏️ Bound parameter: \(parameter)")
    }
}

// MARK: - Keyboard Shortcut Manager

class KeyboardShortcutManager {

    private var shortcuts: [iPadOptimizations.KeyboardShortcut] = []

    func registerShortcuts(_ shortcuts: [iPadOptimizations.KeyboardShortcut]) {
        self.shortcuts = shortcuts
        log.performance("⌨️ Registered \(shortcuts.count) keyboard shortcuts")
    }

    func handleShortcut(_ shortcut: iPadOptimizations.KeyboardShortcut) {
        log.performance("⌨️ Executing: \(shortcut.action)")
    }
}

// MARK: - External Display Manager

@MainActor
class ExternalDisplayManager {

    private var externalWindow: UIWindow?

    func setupExternalDisplay(screen: UIScreen) {
        let window = UIWindow(frame: screen.bounds)
        window.screen = screen

        // Setup view controller for external display
        // let viewController = ExternalDisplayViewController()
        // window.rootViewController = viewController

        window.isHidden = false
        externalWindow = window

        log.performance("📺 External display setup complete")
    }

    func setMode(_ mode: iPadOptimizations.ExternalDisplayMode) {
        log.performance("📺 External display mode: \(mode)")
    }
}

#endif
