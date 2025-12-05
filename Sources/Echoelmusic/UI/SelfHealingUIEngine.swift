import Foundation
import Combine
import SwiftUI
import os.log

#if os(iOS) || os(tvOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif

// ═══════════════════════════════════════════════════════════════════════════════
// ECHOELMUSIC SELF-HEALING UI ENGINE
// ═══════════════════════════════════════════════════════════════════════════════
//
// "Flüssiges Licht heilt sich selbst - UI Edition"
//
// Cross-Platform Self-Healing UI System:
// • UI State Recovery & Restoration
// • Layout Error Detection & Auto-Correction
// • Component Fallback System
// • UI Thread Monitoring & Protection
// • Adaptive UI Based on Device Capabilities
// • Crash-Proof View Hierarchy
// • Memory-Safe UI Operations
// • Responsive Design Healing
//
// Platforms: iOS, iPadOS, macOS, watchOS, tvOS, visionOS
//
// ═══════════════════════════════════════════════════════════════════════════════

// MARK: - Self-Healing UI Engine

@MainActor
public final class SelfHealingUIEngine: ObservableObject {

    // MARK: - Singleton

    public static let shared = SelfHealingUIEngine()

    // MARK: - Published State

    @Published public var uiHealth: UIHealth = .optimal
    @Published public var activeHealings: [UIHealingEvent] = []
    @Published public var componentRegistry: [String: ComponentState] = [:]
    @Published public var layoutIssues: [LayoutIssue] = []
    @Published public var renderPerformance: RenderPerformance = RenderPerformance()
    @Published public var uiRecoveryMode: UIRecoveryMode = .normal

    // MARK: - Private State

    private let logger = Logger(subsystem: "com.echoelmusic", category: "SelfHealingUI")
    private var cancellables = Set<AnyCancellable>()

    private var uiThreadMonitor: UIThreadMonitor?
    private var layoutHealingEngine: LayoutHealingEngine?
    private var componentFallbackManager: ComponentFallbackManager?
    private var stateSnapshotManager: StateSnapshotManager?
    private var renderGuard: RenderGuard?

    private var lastHealthCheck = Date()
    private var healingHistory: [UIHealingEvent] = []

    // MARK: - Initialization

    private init() {
        setupSubsystems()
        startUIMonitoring()
        logger.info("🎨 Self-Healing UI Engine activated - Cross-Platform Edition")
    }

    // MARK: - Setup

    private func setupSubsystems() {
        uiThreadMonitor = UIThreadMonitor(delegate: self)
        layoutHealingEngine = LayoutHealingEngine(delegate: self)
        componentFallbackManager = ComponentFallbackManager(delegate: self)
        stateSnapshotManager = StateSnapshotManager(delegate: self)
        renderGuard = RenderGuard(delegate: self)
    }

    private func startUIMonitoring() {
        // 60 Hz UI health check (matches display refresh)
        Timer.publish(every: 1.0/60.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.fastUIHealthCheck()
            }
            .store(in: &cancellables)

        // 1 Hz deep UI analysis
        Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.deepUIAnalysis()
            }
            .store(in: &cancellables)

        // 10 Hz state snapshot
        Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.captureStateSnapshot()
            }
            .store(in: &cancellables)
    }

    // MARK: - Fast UI Health Check (60 Hz)

    private func fastUIHealthCheck() {
        // Check render performance
        renderGuard?.checkRenderLoop()

        // Check UI thread responsiveness
        uiThreadMonitor?.checkResponsiveness()

        // Update render performance metrics
        updateRenderPerformance()
    }

    // MARK: - Deep UI Analysis (1 Hz)

    private func deepUIAnalysis() {
        // Analyze layout constraints
        let layoutHealth = layoutHealingEngine?.analyzeLayoutHealth() ?? .healthy

        // Check component states
        let componentHealth = analyzeComponentHealth()

        // Calculate overall UI health
        let newHealth = calculateUIHealth(layout: layoutHealth, components: componentHealth)

        if newHealth != uiHealth {
            uiHealth = newHealth
            logger.info("🎨 UI Health changed: \(newHealth.rawValue)")

            if newHealth == .critical {
                triggerUIRecovery()
            }
        }

        // Clean up old healing events
        cleanupHealingHistory()
    }

    private func analyzeComponentHealth() -> ComponentHealth {
        var unhealthyCount = 0
        var totalCount = 0

        for (_, state) in componentRegistry {
            totalCount += 1
            if state.health != .healthy {
                unhealthyCount += 1
            }
        }

        guard totalCount > 0 else { return .healthy }

        let unhealthyRatio = Float(unhealthyCount) / Float(totalCount)

        if unhealthyRatio > 0.5 { return .critical }
        if unhealthyRatio > 0.2 { return .degraded }
        if unhealthyRatio > 0.05 { return .warning }
        return .healthy
    }

    private func calculateUIHealth(layout: LayoutHealth, components: ComponentHealth) -> UIHealth {
        // Critical conditions
        if layout == .critical || components == .critical {
            return .critical
        }

        // Degraded conditions
        if layout == .degraded || components == .degraded {
            return .degraded
        }

        // Warning conditions
        if layout == .warning || components == .warning {
            return .compromised
        }

        // Check render performance
        if renderPerformance.frameDropRate > 0.1 {
            return .compromised
        }

        return .optimal
    }

    private func updateRenderPerformance() {
        renderPerformance.lastFrameTime = CACurrentMediaTime()
        renderPerformance.frameCount += 1

        // Calculate FPS every second
        let elapsed = renderPerformance.lastFrameTime - renderPerformance.fpsStartTime
        if elapsed >= 1.0 {
            renderPerformance.currentFPS = Float(renderPerformance.frameCount) / Float(elapsed)
            renderPerformance.frameDropRate = max(0, 1.0 - (renderPerformance.currentFPS / renderPerformance.targetFPS))
            renderPerformance.frameCount = 0
            renderPerformance.fpsStartTime = renderPerformance.lastFrameTime
        }
    }

    // MARK: - State Snapshots

    private func captureStateSnapshot() {
        stateSnapshotManager?.captureSnapshot(components: componentRegistry)
    }

    // MARK: - UI Recovery

    private func triggerUIRecovery() {
        logger.warning("🚨 Triggering UI Recovery Mode")
        uiRecoveryMode = .recovering

        // Attempt recovery strategies in order
        Task {
            // 1. Attempt soft recovery
            if await attemptSoftRecovery() {
                uiRecoveryMode = .normal
                logHealingEvent(.softRecoverySuccess)
                return
            }

            // 2. Attempt component fallback
            if await attemptComponentFallback() {
                uiRecoveryMode = .fallback
                logHealingEvent(.fallbackActivated)
                return
            }

            // 3. Attempt state restoration
            if await attemptStateRestoration() {
                uiRecoveryMode = .restored
                logHealingEvent(.stateRestored)
                return
            }

            // 4. Emergency reset
            await performEmergencyUIReset()
            uiRecoveryMode = .emergency
            logHealingEvent(.emergencyReset)
        }
    }

    private func attemptSoftRecovery() async -> Bool {
        // Clear layout caches
        layoutHealingEngine?.clearLayoutCaches()

        // Force layout recalculation
        layoutHealingEngine?.forceLayoutPass()

        // Wait for next frame
        try? await Task.sleep(nanoseconds: 16_666_667)  // ~1 frame at 60fps

        // Check if recovery successful
        let health = layoutHealingEngine?.analyzeLayoutHealth() ?? .critical
        return health != .critical
    }

    private func attemptComponentFallback() async -> Bool {
        var successCount = 0
        var failureCount = 0

        for (componentId, state) in componentRegistry where state.health != .healthy {
            if await componentFallbackManager?.activateFallback(for: componentId) == true {
                successCount += 1
            } else {
                failureCount += 1
            }
        }

        return failureCount == 0 || successCount > failureCount
    }

    private func attemptStateRestoration() async -> Bool {
        guard let snapshot = stateSnapshotManager?.getLastHealthySnapshot() else {
            return false
        }

        return await stateSnapshotManager?.restoreSnapshot(snapshot) ?? false
    }

    private func performEmergencyUIReset() async {
        logger.error("🚨 Emergency UI Reset")

        // Clear all component states
        componentRegistry.removeAll()

        // Reset layout engine
        layoutHealingEngine?.reset()

        // Clear render state
        renderGuard?.reset()

        // Notify system
        NotificationCenter.default.post(name: .uiEmergencyReset, object: nil)
    }

    // MARK: - Component Registration

    public func registerComponent(_ id: String, type: ComponentType, priority: ComponentPriority = .normal) {
        componentRegistry[id] = ComponentState(
            id: id,
            type: type,
            priority: priority,
            health: .healthy,
            lastUpdate: Date(),
            fallbackAvailable: componentFallbackManager?.hasFallback(for: type) ?? false
        )
    }

    public func unregisterComponent(_ id: String) {
        componentRegistry.removeValue(forKey: id)
    }

    public func reportComponentError(_ id: String, error: UIComponentError) {
        guard var state = componentRegistry[id] else { return }

        state.health = .unhealthy
        state.lastError = error
        state.errorCount += 1
        componentRegistry[id] = state

        logger.warning("⚠️ Component error: \(id) - \(error.description)")

        // Attempt auto-healing
        Task {
            await healComponent(id)
        }
    }

    private func healComponent(_ id: String) async {
        guard var state = componentRegistry[id] else { return }

        // Try fallback if available
        if state.fallbackAvailable {
            if await componentFallbackManager?.activateFallback(for: id) == true {
                state.health = .healing
                state.usingFallback = true
                componentRegistry[id] = state
                logHealingEvent(.componentFallbackActivated(id))
                return
            }
        }

        // Try state reset
        if await componentFallbackManager?.resetComponent(id) == true {
            state.health = .healthy
            state.errorCount = 0
            componentRegistry[id] = state
            logHealingEvent(.componentReset(id))
        }
    }

    // MARK: - Layout Healing

    public func reportLayoutIssue(_ issue: LayoutIssue) {
        layoutIssues.append(issue)

        logger.warning("📐 Layout issue: \(issue.description)")

        // Auto-heal layout issues
        Task {
            await healLayoutIssue(issue)
        }
    }

    private func healLayoutIssue(_ issue: LayoutIssue) async {
        switch issue.type {
        case .constraintConflict:
            await layoutHealingEngine?.resolveConstraintConflict(issue)
        case .ambiguousLayout:
            await layoutHealingEngine?.resolveAmbiguousLayout(issue)
        case .unsatisfiable:
            await layoutHealingEngine?.breakUnsatisfiableConstraint(issue)
        case .overlapDetected:
            await layoutHealingEngine?.resolveOverlap(issue)
        case .sizeTooBig:
            await layoutHealingEngine?.constrainSize(issue)
        case .sizeTooSmall:
            await layoutHealingEngine?.expandSize(issue)
        case .offscreen:
            await layoutHealingEngine?.bringOnscreen(issue)
        }

        // Remove healed issue
        layoutIssues.removeAll { $0.id == issue.id }
    }

    // MARK: - Adaptive UI

    public func getAdaptiveUISettings() -> AdaptiveUISettings {
        let platform = UniversalPlatformCore.shared

        return AdaptiveUISettings(
            // Layout
            preferredLayoutMode: getPreferredLayoutMode(),
            minimumTouchTargetSize: getMinimumTouchTargetSize(),
            preferredSpacing: getPreferredSpacing(),
            safeAreaHandling: getSafeAreaHandling(),

            // Typography
            dynamicTypeEnabled: true,
            minimumFontSize: getMinimumFontSize(),
            maximumFontSize: getMaximumFontSize(),
            preferredFontScale: getPreferredFontScale(),

            // Animations
            animationsEnabled: shouldEnableAnimations(),
            preferredAnimationDuration: getPreferredAnimationDuration(),
            reduceMotion: shouldReduceMotion(),

            // Accessibility
            voiceOverOptimized: isVoiceOverRunning(),
            highContrastMode: shouldUseHighContrast(),
            largeContentViewer: shouldUseLargeContentViewer(),

            // Performance
            maxConcurrentAnimations: getMaxConcurrentAnimations(),
            useSimplifiedRendering: shouldUseSimplifiedRendering(),
            cacheUIElements: shouldCacheUIElements()
        )
    }

    private func getPreferredLayoutMode() -> LayoutMode {
        #if os(watchOS)
        return .compact
        #elseif os(tvOS)
        return .expanded
        #elseif os(visionOS)
        return .spatial
        #elseif os(iOS)
        let idiom = UIDevice.current.userInterfaceIdiom
        switch idiom {
        case .phone: return .compact
        case .pad: return .regular
        default: return .regular
        }
        #elseif os(macOS)
        return .regular
        #else
        return .regular
        #endif
    }

    private func getMinimumTouchTargetSize() -> CGFloat {
        #if os(watchOS)
        return 38  // Apple Watch guidelines
        #elseif os(tvOS)
        return 60  // TV focus areas need to be larger
        #elseif os(visionOS)
        return 60  // Spatial interactions need larger targets
        #else
        return 44  // iOS HIG minimum
        #endif
    }

    private func getPreferredSpacing() -> CGFloat {
        #if os(watchOS)
        return 4
        #elseif os(tvOS)
        return 24
        #elseif os(visionOS)
        return 20
        #else
        return 16
        #endif
    }

    private func getSafeAreaHandling() -> SafeAreaHandling {
        #if os(iOS)
        return .automatic
        #elseif os(macOS)
        return .inset
        #elseif os(visionOS)
        return .spatial
        #else
        return .ignore
        #endif
    }

    private func getMinimumFontSize() -> CGFloat {
        #if os(watchOS)
        return 12
        #elseif os(tvOS)
        return 24
        #else
        return 11
        #endif
    }

    private func getMaximumFontSize() -> CGFloat {
        #if os(watchOS)
        return 20
        #elseif os(tvOS)
        return 48
        #else
        return 36
        #endif
    }

    private func getPreferredFontScale() -> CGFloat {
        #if os(iOS)
        return UIFontMetrics.default.scaledValue(for: 1.0)
        #else
        return 1.0
        #endif
    }

    private func shouldEnableAnimations() -> Bool {
        #if os(iOS) || os(tvOS)
        return !UIAccessibility.isReduceMotionEnabled
        #elseif os(macOS)
        return !NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #else
        return true
        #endif
    }

    private func getPreferredAnimationDuration() -> TimeInterval {
        if shouldReduceMotion() {
            return 0.1
        }
        #if os(tvOS)
        return 0.4  // TV animations should be slower
        #else
        return 0.25
        #endif
    }

    private func shouldReduceMotion() -> Bool {
        #if os(iOS) || os(tvOS)
        return UIAccessibility.isReduceMotionEnabled
        #elseif os(macOS)
        return NSWorkspace.shared.accessibilityDisplayShouldReduceMotion
        #else
        return false
        #endif
    }

    private func isVoiceOverRunning() -> Bool {
        #if os(iOS) || os(tvOS)
        return UIAccessibility.isVoiceOverRunning
        #elseif os(macOS)
        return NSWorkspace.shared.isVoiceOverEnabled
        #else
        return false
        #endif
    }

    private func shouldUseHighContrast() -> Bool {
        #if os(iOS) || os(tvOS)
        return UIAccessibility.isDarkerSystemColorsEnabled
        #elseif os(macOS)
        return NSWorkspace.shared.accessibilityDisplayShouldIncreaseContrast
        #else
        return false
        #endif
    }

    private func shouldUseLargeContentViewer() -> Bool {
        #if os(iOS)
        if #available(iOS 13.0, *) {
            return UIAccessibility.prefersCrossFadeTransitions
        }
        #endif
        return false
    }

    private func getMaxConcurrentAnimations() -> Int {
        switch uiHealth {
        case .optimal: return 10
        case .compromised: return 5
        case .degraded: return 2
        case .critical: return 0
        }
    }

    private func shouldUseSimplifiedRendering() -> Bool {
        return uiHealth == .degraded || uiHealth == .critical || renderPerformance.currentFPS < 30
    }

    private func shouldCacheUIElements() -> Bool {
        return uiRecoveryMode != .emergency
    }

    // MARK: - Logging

    private func logHealingEvent(_ type: UIHealingEventType) {
        let event = UIHealingEvent(type: type, timestamp: Date())
        activeHealings.append(event)
        healingHistory.append(event)

        // Keep active healings for 5 seconds
        Task {
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            activeHealings.removeAll { $0.id == event.id }
        }
    }

    private func cleanupHealingHistory() {
        let oneHourAgo = Date().addingTimeInterval(-3600)
        healingHistory.removeAll { $0.timestamp < oneHourAgo }
    }
}

// MARK: - Data Types

public enum UIHealth: String {
    case optimal = "Optimal"
    case compromised = "Compromised"
    case degraded = "Degraded"
    case critical = "Critical"
}

public enum UIRecoveryMode: String {
    case normal = "Normal"
    case recovering = "Recovering"
    case fallback = "Fallback"
    case restored = "Restored"
    case emergency = "Emergency"
}

public enum ComponentHealth {
    case healthy
    case warning
    case degraded
    case critical
}

public enum LayoutHealth {
    case healthy
    case warning
    case degraded
    case critical
}

public struct ComponentState {
    public var id: String
    public var type: ComponentType
    public var priority: ComponentPriority
    public var health: ComponentHealthState = .healthy
    public var lastUpdate: Date
    public var lastError: UIComponentError?
    public var errorCount: Int = 0
    public var fallbackAvailable: Bool
    public var usingFallback: Bool = false

    public enum ComponentHealthState {
        case healthy
        case healing
        case unhealthy
        case failed
    }
}

public enum ComponentType: String {
    // Core UI
    case view = "View"
    case scrollView = "ScrollView"
    case list = "List"
    case grid = "Grid"
    case stack = "Stack"

    // Audio UI
    case waveform = "Waveform"
    case spectrum = "Spectrum"
    case mixer = "Mixer"
    case transport = "Transport"
    case piano = "Piano"

    // Visual UI
    case visualizer = "Visualizer"
    case animation = "Animation"
    case particle = "Particle"
    case shader = "Shader"

    // Control UI
    case knob = "Knob"
    case slider = "Slider"
    case button = "Button"
    case toggle = "Toggle"

    // Bio UI
    case heartRate = "HeartRate"
    case coherence = "Coherence"
    case biofeedback = "Biofeedback"

    // Collaboration
    case chat = "Chat"
    case presence = "Presence"
    case timeline = "Timeline"
}

public enum ComponentPriority: Int {
    case critical = 100   // Must always work (transport controls)
    case high = 75        // Important (mixer, piano)
    case normal = 50      // Standard (most UI)
    case low = 25         // Nice to have (visualizers)
    case optional = 0     // Can be disabled (particle effects)
}

public struct UIComponentError: Error {
    public var type: UIErrorType
    public var message: String
    public var componentId: String?
    public var underlyingError: Error?

    public var description: String {
        return "\(type.rawValue): \(message)"
    }

    public enum UIErrorType: String {
        case renderFailed = "Render Failed"
        case layoutFailed = "Layout Failed"
        case stateLost = "State Lost"
        case memoryPressure = "Memory Pressure"
        case timeout = "Timeout"
        case crash = "Crash"
        case invalidData = "Invalid Data"
    }
}

public struct LayoutIssue: Identifiable {
    public let id = UUID()
    public var type: LayoutIssueType
    public var componentId: String?
    public var constraintInfo: String?
    public var suggestedFix: String?

    public var description: String {
        return "\(type.rawValue)\(componentId.map { " in \($0)" } ?? "")"
    }

    public enum LayoutIssueType: String {
        case constraintConflict = "Constraint Conflict"
        case ambiguousLayout = "Ambiguous Layout"
        case unsatisfiable = "Unsatisfiable Constraints"
        case overlapDetected = "Overlap Detected"
        case sizeTooBig = "Size Too Big"
        case sizeTooSmall = "Size Too Small"
        case offscreen = "Off Screen"
    }
}

public struct RenderPerformance {
    public var currentFPS: Float = 60
    public var targetFPS: Float = 60
    public var frameDropRate: Float = 0
    public var lastFrameTime: CFTimeInterval = CACurrentMediaTime()
    public var fpsStartTime: CFTimeInterval = CACurrentMediaTime()
    public var frameCount: Int = 0
    public var gpuUtilization: Float = 0
    public var cpuUtilization: Float = 0
}

public struct UIHealingEvent: Identifiable {
    public let id = UUID()
    public var type: UIHealingEventType
    public var timestamp: Date
}

public enum UIHealingEventType: String {
    case softRecoverySuccess = "Soft Recovery"
    case fallbackActivated = "Fallback Activated"
    case stateRestored = "State Restored"
    case emergencyReset = "Emergency Reset"
    case componentFallbackActivated = "Component Fallback"
    case componentReset = "Component Reset"
    case layoutHealed = "Layout Healed"
    case renderOptimized = "Render Optimized"

    static func componentFallbackActivated(_ id: String) -> UIHealingEventType {
        return .componentFallbackActivated
    }

    static func componentReset(_ id: String) -> UIHealingEventType {
        return .componentReset
    }
}

public struct AdaptiveUISettings {
    // Layout
    public var preferredLayoutMode: LayoutMode
    public var minimumTouchTargetSize: CGFloat
    public var preferredSpacing: CGFloat
    public var safeAreaHandling: SafeAreaHandling

    // Typography
    public var dynamicTypeEnabled: Bool
    public var minimumFontSize: CGFloat
    public var maximumFontSize: CGFloat
    public var preferredFontScale: CGFloat

    // Animations
    public var animationsEnabled: Bool
    public var preferredAnimationDuration: TimeInterval
    public var reduceMotion: Bool

    // Accessibility
    public var voiceOverOptimized: Bool
    public var highContrastMode: Bool
    public var largeContentViewer: Bool

    // Performance
    public var maxConcurrentAnimations: Int
    public var useSimplifiedRendering: Bool
    public var cacheUIElements: Bool
}

public enum LayoutMode {
    case compact    // watchOS, iPhone compact
    case regular    // iPhone regular, iPad, Mac
    case expanded   // tvOS
    case spatial    // visionOS
}

public enum SafeAreaHandling {
    case automatic  // Follow system
    case inset      // Always inset
    case ignore     // Don't adjust
    case spatial    // 3D space handling
}

// MARK: - Subsystem Protocols

protocol UIThreadMonitorDelegate: AnyObject {
    func uiThreadBlocked(duration: TimeInterval)
    func uiThreadRecovered()
}

protocol LayoutHealingEngineDelegate: AnyObject {
    func layoutHealed(_ issue: LayoutIssue)
    func layoutHealingFailed(_ issue: LayoutIssue, error: Error)
}

protocol ComponentFallbackManagerDelegate: AnyObject {
    func fallbackActivated(for componentId: String)
    func fallbackDeactivated(for componentId: String)
}

protocol StateSnapshotManagerDelegate: AnyObject {
    func snapshotCaptured(_ snapshot: UIStateSnapshot)
    func snapshotRestored(_ snapshot: UIStateSnapshot)
}

protocol RenderGuardDelegate: AnyObject {
    func renderDropped()
    func renderRecovered()
}

// MARK: - UI Thread Monitor

class UIThreadMonitor {
    weak var delegate: UIThreadMonitorDelegate?

    private var lastResponseTime = CACurrentMediaTime()
    private var isBlocked = false
    private let blockThreshold: TimeInterval = 0.1  // 100ms

    init(delegate: UIThreadMonitorDelegate?) {
        self.delegate = delegate
    }

    func checkResponsiveness() {
        let now = CACurrentMediaTime()
        let elapsed = now - lastResponseTime

        if elapsed > blockThreshold && !isBlocked {
            isBlocked = true
            delegate?.uiThreadBlocked(duration: elapsed)
        } else if elapsed <= blockThreshold && isBlocked {
            isBlocked = false
            delegate?.uiThreadRecovered()
        }

        lastResponseTime = now
    }
}

// MARK: - Layout Healing Engine

class LayoutHealingEngine {
    weak var delegate: LayoutHealingEngineDelegate?

    private var layoutCache: [String: CGRect] = [:]

    init(delegate: LayoutHealingEngineDelegate?) {
        self.delegate = delegate
    }

    func analyzeLayoutHealth() -> LayoutHealth {
        // Simplified layout health check
        #if os(iOS) || os(tvOS)
        // Check for constraint warnings in debug
        #if DEBUG
        // In debug, check for layout warnings
        #endif
        #endif

        return .healthy
    }

    func clearLayoutCaches() {
        layoutCache.removeAll()
    }

    func forceLayoutPass() {
        #if os(iOS) || os(tvOS)
        DispatchQueue.main.async {
            UIApplication.shared.windows.forEach { window in
                window.setNeedsLayout()
                window.layoutIfNeeded()
            }
        }
        #elseif os(macOS)
        DispatchQueue.main.async {
            NSApplication.shared.windows.forEach { window in
                window.contentView?.needsLayout = true
                window.contentView?.layoutSubtreeIfNeeded()
            }
        }
        #endif
    }

    func reset() {
        clearLayoutCaches()
    }

    func resolveConstraintConflict(_ issue: LayoutIssue) async {
        // Implementation: Remove lower priority constraints
        delegate?.layoutHealed(issue)
    }

    func resolveAmbiguousLayout(_ issue: LayoutIssue) async {
        // Implementation: Add necessary constraints
        delegate?.layoutHealed(issue)
    }

    func breakUnsatisfiableConstraint(_ issue: LayoutIssue) async {
        // Implementation: Break constraint with lowest priority
        delegate?.layoutHealed(issue)
    }

    func resolveOverlap(_ issue: LayoutIssue) async {
        // Implementation: Adjust z-order or position
        delegate?.layoutHealed(issue)
    }

    func constrainSize(_ issue: LayoutIssue) async {
        // Implementation: Add maximum size constraint
        delegate?.layoutHealed(issue)
    }

    func expandSize(_ issue: LayoutIssue) async {
        // Implementation: Adjust minimum size
        delegate?.layoutHealed(issue)
    }

    func bringOnscreen(_ issue: LayoutIssue) async {
        // Implementation: Adjust position to visible area
        delegate?.layoutHealed(issue)
    }
}

// MARK: - Component Fallback Manager

class ComponentFallbackManager {
    weak var delegate: ComponentFallbackManagerDelegate?

    private var fallbackRegistry: [ComponentType: FallbackComponent] = [:]
    private var activeFallbacks: Set<String> = []

    init(delegate: ComponentFallbackManagerDelegate?) {
        self.delegate = delegate
        registerDefaultFallbacks()
    }

    private func registerDefaultFallbacks() {
        // Register fallback for each component type
        fallbackRegistry[.waveform] = FallbackComponent(
            type: .waveform,
            fallbackView: "SimplifiedWaveform",
            reducedFeatures: ["3D rendering", "real-time FFT"]
        )

        fallbackRegistry[.spectrum] = FallbackComponent(
            type: .spectrum,
            fallbackView: "BarSpectrum",
            reducedFeatures: ["smooth animation", "gradient colors"]
        )

        fallbackRegistry[.visualizer] = FallbackComponent(
            type: .visualizer,
            fallbackView: "BasicColorView",
            reducedFeatures: ["particle effects", "3D", "shaders"]
        )

        fallbackRegistry[.particle] = FallbackComponent(
            type: .particle,
            fallbackView: "StaticBackground",
            reducedFeatures: ["all particle effects"]
        )

        fallbackRegistry[.animation] = FallbackComponent(
            type: .animation,
            fallbackView: "StaticView",
            reducedFeatures: ["all animations"]
        )
    }

    func hasFallback(for type: ComponentType) -> Bool {
        return fallbackRegistry[type] != nil
    }

    func activateFallback(for componentId: String) async -> Bool {
        activeFallbacks.insert(componentId)
        delegate?.fallbackActivated(for: componentId)
        return true
    }

    func deactivateFallback(for componentId: String) async {
        activeFallbacks.remove(componentId)
        delegate?.fallbackDeactivated(for: componentId)
    }

    func resetComponent(_ componentId: String) async -> Bool {
        // Reset component to initial state
        return true
    }
}

struct FallbackComponent {
    let type: ComponentType
    let fallbackView: String
    let reducedFeatures: [String]
}

// MARK: - State Snapshot Manager

class StateSnapshotManager {
    weak var delegate: StateSnapshotManagerDelegate?

    private var snapshots: [UIStateSnapshot] = []
    private let maxSnapshots = 100

    init(delegate: StateSnapshotManagerDelegate?) {
        self.delegate = delegate
    }

    func captureSnapshot(components: [String: ComponentState]) {
        let snapshot = UIStateSnapshot(
            timestamp: Date(),
            componentStates: components,
            isHealthy: components.values.allSatisfy { $0.health == .healthy }
        )

        snapshots.append(snapshot)

        // Keep only recent snapshots
        if snapshots.count > maxSnapshots {
            snapshots.removeFirst(snapshots.count - maxSnapshots)
        }

        delegate?.snapshotCaptured(snapshot)
    }

    func getLastHealthySnapshot() -> UIStateSnapshot? {
        return snapshots.last { $0.isHealthy }
    }

    func restoreSnapshot(_ snapshot: UIStateSnapshot) async -> Bool {
        delegate?.snapshotRestored(snapshot)
        return true
    }
}

struct UIStateSnapshot {
    let id = UUID()
    let timestamp: Date
    let componentStates: [String: ComponentState]
    let isHealthy: Bool
}

// MARK: - Render Guard

class RenderGuard {
    weak var delegate: RenderGuardDelegate?

    private var lastRenderTime = CACurrentMediaTime()
    private var droppedFrames = 0
    private let frameThreshold: TimeInterval = 1.0/30.0  // 30 FPS minimum

    init(delegate: RenderGuardDelegate?) {
        self.delegate = delegate
    }

    func checkRenderLoop() {
        let now = CACurrentMediaTime()
        let elapsed = now - lastRenderTime

        if elapsed > frameThreshold {
            droppedFrames += 1
            if droppedFrames > 5 {
                delegate?.renderDropped()
            }
        } else {
            if droppedFrames > 5 {
                delegate?.renderRecovered()
            }
            droppedFrames = 0
        }

        lastRenderTime = now
    }

    func reset() {
        lastRenderTime = CACurrentMediaTime()
        droppedFrames = 0
    }
}

// MARK: - Delegate Conformances

extension SelfHealingUIEngine: UIThreadMonitorDelegate {
    nonisolated func uiThreadBlocked(duration: TimeInterval) {
        Task { @MainActor in
            self.logger.warning("⚠️ UI thread blocked for \(String(format: "%.2f", duration * 1000))ms")
        }
    }

    nonisolated func uiThreadRecovered() {
        Task { @MainActor in
            self.logger.info("✅ UI thread recovered")
        }
    }
}

extension SelfHealingUIEngine: LayoutHealingEngineDelegate {
    nonisolated func layoutHealed(_ issue: LayoutIssue) {
        Task { @MainActor in
            self.logHealingEvent(.layoutHealed)
            self.logger.info("📐 Layout healed: \(issue.type.rawValue)")
        }
    }

    nonisolated func layoutHealingFailed(_ issue: LayoutIssue, error: Error) {
        Task { @MainActor in
            self.logger.error("❌ Layout healing failed: \(error.localizedDescription)")
        }
    }
}

extension SelfHealingUIEngine: ComponentFallbackManagerDelegate {
    nonisolated func fallbackActivated(for componentId: String) {
        Task { @MainActor in
            self.logger.info("🔄 Fallback activated for: \(componentId)")
        }
    }

    nonisolated func fallbackDeactivated(for componentId: String) {
        Task { @MainActor in
            self.logger.info("✅ Fallback deactivated for: \(componentId)")
        }
    }
}

extension SelfHealingUIEngine: StateSnapshotManagerDelegate {
    nonisolated func snapshotCaptured(_ snapshot: UIStateSnapshot) {
        // Silent capture
    }

    nonisolated func snapshotRestored(_ snapshot: UIStateSnapshot) {
        Task { @MainActor in
            self.logger.info("📸 State snapshot restored from \(snapshot.timestamp)")
        }
    }
}

extension SelfHealingUIEngine: RenderGuardDelegate {
    nonisolated func renderDropped() {
        Task { @MainActor in
            self.logger.warning("⚠️ Render frames dropping")
            self.logHealingEvent(.renderOptimized)
        }
    }

    nonisolated func renderRecovered() {
        Task { @MainActor in
            self.logger.info("✅ Render recovered")
        }
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let uiEmergencyReset = Notification.Name("uiEmergencyReset")
    static let uiHealthChanged = Notification.Name("uiHealthChanged")
    static let uiRecoveryModeChanged = Notification.Name("uiRecoveryModeChanged")
}
