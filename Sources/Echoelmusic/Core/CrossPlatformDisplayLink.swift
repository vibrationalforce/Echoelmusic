// CrossPlatformDisplayLink.swift
// Echoelmusic - Unified Display Link for All Platforms
// Phase 10000 Ralph Wiggum Lambda Loop Mode
//
// Provides a unified 60Hz (or display refresh rate) callback across:
// - iOS/tvOS/watchOS/visionOS: CADisplayLink
// - macOS: CVDisplayLink
// - Linux/Windows/Android: High-precision timer
//
// Single shared instance prevents multiple redundant callbacks.
//
// Created 2026-01-16

import Foundation

#if canImport(QuartzCore)
import QuartzCore
#endif

#if canImport(CoreVideo)
import CoreVideo
#endif

// MARK: - Cross-Platform Display Link

/// Unified display-synchronized callback for all platforms
///
/// Features:
/// - Single shared instance (prevents redundant callbacks)
/// - Multiple subscribers supported
/// - Automatic frame rate adaptation
/// - Low-latency callback delivery
///
/// Usage:
/// ```swift
/// let displayLink = CrossPlatformDisplayLink.shared
/// let token = displayLink.subscribe { timestamp, duration in
///     // Called at display refresh rate (60Hz, 120Hz, etc.)
/// }
///
/// // Later:
/// displayLink.unsubscribe(token)
/// ```
@MainActor
public final class CrossPlatformDisplayLink {

    // MARK: - Singleton

    /// Shared instance - use this to prevent multiple display links
    public static let shared = CrossPlatformDisplayLink()

    // MARK: - Types

    /// Callback signature: (timestamp: CFTimeInterval, frameDuration: CFTimeInterval)
    public typealias Callback = (CFTimeInterval, CFTimeInterval) -> Void

    /// Subscription token for unsubscribing
    public struct Token: Hashable {
        fileprivate let id: UUID
    }

    // MARK: - State

    /// Whether the display link is running
    @Published public private(set) var isRunning = false

    /// Current frame rate
    @Published public private(set) var frameRate: Double = 60

    /// Target frame rate (0 = native display rate)
    public var targetFrameRate: Double = 0 {
        didSet { updateFrameRate() }
    }

    /// Frame counter
    public private(set) var frameCount: UInt64 = 0

    /// Last frame timestamp
    public private(set) var lastTimestamp: CFTimeInterval = 0

    /// Frame duration
    public private(set) var frameDuration: CFTimeInterval = 1.0 / 60.0

    // MARK: - Idle Detection (Battery Optimization)

    /// Number of consecutive frames with no `needsDisplay` signal before auto-pausing.
    /// At 60Hz, 120 frames = 2 seconds of idle.
    private let idleFrameThreshold: UInt64 = 120
    /// Frames since last `setNeedsDisplay()` call
    private var framesSinceLastRequest: UInt64 = 0
    /// Whether the display link is idle-paused (separate from manual stop)
    private var isIdlePaused = false

    /// Call this to signal that the visual content has changed and the
    /// display link should keep running. If no subscriber calls this for
    /// ~2 seconds, the display link auto-pauses to save battery.
    public func setNeedsDisplay() {
        framesSinceLastRequest = 0
        if isIdlePaused {
            isIdlePaused = false
            start()
            log.video("CrossPlatformDisplayLink: Resumed from idle")
        }
    }

    // MARK: - Subscribers

    private var subscribers: [UUID: Callback] = [:]
    private var subscriberCount: Int { subscribers.count }

    // MARK: - Platform-Specific Implementation

    #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    private var displayLink: CADisplayLink?
    #elseif os(macOS)
    private var displayLink: CVDisplayLink?
    private var displayLinkOutputHandler: CVDisplayLinkOutputHandler?
    #else
    private var timer: DispatchSourceTimer?
    #endif

    // MARK: - Initialization

    private init() {
        setupDisplayLink()
    }

    deinit {
        // stop() is @MainActor-isolated, cannot call from deinit
        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        displayLink?.invalidate()
        #elseif os(macOS)
        if let link = displayLink { CVDisplayLinkStop(link) }
        #else
        timer?.cancel()
        #endif
    }

    // MARK: - Setup

    private func setupDisplayLink() {
        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        // CADisplayLink for Apple mobile/wearable platforms
        displayLink = CADisplayLink(target: self, selector: #selector(displayLinkCallback))
        displayLink?.add(to: .main, forMode: .common)
        displayLink?.isPaused = true

        #elseif os(macOS)
        // CVDisplayLink for macOS
        var link: CVDisplayLink?
        CVDisplayLinkCreateWithActiveCGDisplays(&link)

        if let link = link {
            self.displayLink = link

            // Set output callback
            let callback: CVDisplayLinkOutputCallback = { _, _, _, _, _, userInfo in
                guard let userInfo = userInfo else { return kCVReturnSuccess }
                let displayLinkRef = Unmanaged<CrossPlatformDisplayLink>.fromOpaque(userInfo)
                let displayLink = displayLinkRef.takeUnretainedValue()
                Task { @MainActor in
                    displayLink.tick()
                }
                return kCVReturnSuccess
            }

            CVDisplayLinkSetOutputCallback(link, callback, Unmanaged.passUnretained(self).toOpaque())
        }

        #else
        // Timer fallback for Linux/Windows/Android
        // Will be created on start()
        #endif
    }

    // MARK: - Control

    /// Start the display link
    public func start() {
        guard !isRunning else { return }

        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        displayLink?.isPaused = false

        #elseif os(macOS)
        if let link = displayLink {
            CVDisplayLinkStart(link)
        }

        #else
        // Timer-based fallback at 60Hz
        let interval = targetFrameRate > 0 ? 1.0 / targetFrameRate : 1.0 / 60.0
        let queue = DispatchQueue.main
        timer = DispatchSource.makeTimerSource(queue: queue)
        timer?.schedule(deadline: .now(), repeating: interval)
        timer?.setEventHandler { [weak self] in
            self?.tick()
        }
        timer?.resume()
        #endif

        isRunning = true
        log.video("CrossPlatformDisplayLink: Started")
    }

    /// Stop the display link
    public func stop() {
        guard isRunning else { return }

        #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
        displayLink?.isPaused = true

        #elseif os(macOS)
        if let link = displayLink {
            CVDisplayLinkStop(link)
        }

        #else
        timer?.cancel()
        timer = nil
        #endif

        isRunning = false
        log.video("CrossPlatformDisplayLink: Stopped")
    }

    // MARK: - Subscription

    /// Subscribe to display link callbacks
    ///
    /// - Parameter callback: Called at each frame
    /// - Returns: Token to use for unsubscribing
    public func subscribe(_ callback: @escaping Callback) -> Token {
        let token = Token(id: UUID())
        subscribers[token.id] = callback

        // Auto-start when first subscriber
        if subscriberCount == 1 {
            start()
        }

        log.video("CrossPlatformDisplayLink: Subscriber added (total: \(subscriberCount))")
        return token
    }

    /// Unsubscribe from display link callbacks
    ///
    /// - Parameter token: Token returned from subscribe()
    public func unsubscribe(_ token: Token) {
        subscribers.removeValue(forKey: token.id)

        // Auto-stop when no subscribers
        if subscriberCount == 0 {
            stop()
        }

        log.video("CrossPlatformDisplayLink: Subscriber removed (total: \(subscriberCount))")
    }

    // MARK: - Callback

    #if os(iOS) || os(tvOS) || os(watchOS) || os(visionOS)
    @objc private func displayLinkCallback(_ link: CADisplayLink) {
        // Idle detection: auto-pause when no visual updates requested
        framesSinceLastRequest += 1
        if framesSinceLastRequest >= idleFrameThreshold && !isIdlePaused {
            isIdlePaused = true
            link.isPaused = true
            isRunning = false
            log.video("CrossPlatformDisplayLink: Auto-paused (idle \(idleFrameThreshold) frames)")
            return
        }

        let timestamp = link.timestamp
        let duration = link.targetTimestamp - link.timestamp
        frameDuration = duration
        lastTimestamp = timestamp
        frameCount += 1

        // Update measured frame rate
        if duration > 0 {
            frameRate = 1.0 / duration
        }

        // Notify all subscribers
        for callback in subscribers.values {
            callback(timestamp, duration)
        }
    }
    #endif

    /// Internal tick (macOS CVDisplayLink and timer fallback)
    private func tick() {
        // Idle detection: auto-pause when no visual updates requested
        framesSinceLastRequest += 1
        if framesSinceLastRequest >= idleFrameThreshold && !isIdlePaused {
            isIdlePaused = true
            stop()
            log.video("CrossPlatformDisplayLink: Auto-paused (idle \(idleFrameThreshold) frames)")
            return
        }

        let now = CACurrentMediaTime()
        let duration = lastTimestamp > 0 ? now - lastTimestamp : frameDuration

        lastTimestamp = now
        frameCount += 1
        frameDuration = duration

        // Update measured frame rate
        if duration > 0 {
            frameRate = 1.0 / duration
        }

        // Notify all subscribers
        for callback in subscribers.values {
            callback(now, duration)
        }
    }

    // MARK: - Configuration

    private func updateFrameRate() {
        #if os(iOS) || os(tvOS) || os(visionOS)
        if #available(iOS 15.0, tvOS 15.0, *) {
            if targetFrameRate > 0 {
                displayLink?.preferredFrameRateRange = CAFrameRateRange(
                    minimum: Float(targetFrameRate),
                    maximum: Float(targetFrameRate),
                    preferred: Float(targetFrameRate)
                )
            } else {
                displayLink?.preferredFrameRateRange = .default
            }
        }
        #elseif os(watchOS)
        // watchOS has limited frame rate options
        #elseif os(macOS)
        // CVDisplayLink uses native display rate
        #else
        // Restart timer with new rate
        if isRunning {
            stop()
            start()
        }
        #endif
    }

    // MARK: - Diagnostics

    /// Get current frame statistics
    public var stats: FrameStats {
        FrameStats(
            frameCount: frameCount,
            frameRate: frameRate,
            frameDuration: frameDuration,
            subscriberCount: subscriberCount
        )
    }

    /// Frame statistics
    public struct FrameStats: Sendable {
        public let frameCount: UInt64
        public let frameRate: Double
        public let frameDuration: CFTimeInterval
        public let subscriberCount: Int
    }
}

// MARK: - Display Link Coordinator

/// Coordinates multiple components using the shared display link
///
/// Groups related callbacks to ensure consistent timing.
@MainActor
public final class DisplayLinkCoordinator {

    /// Shared coordinator
    public static let shared = DisplayLinkCoordinator()

    /// Priority levels for callbacks
    public enum Priority: Int, Comparable {
        case input = 0      // Input processing (bio data, MIDI)
        case update = 1     // State updates (control hub)
        case render = 2     // Rendering (video, visual)
        case output = 3     // Output (stream, lights)

        public static func < (lhs: Priority, rhs: Priority) -> Bool {
            lhs.rawValue < rhs.rawValue
        }
    }

    /// Callback with priority
    private struct PrioritizedCallback {
        let priority: Priority
        let callback: CrossPlatformDisplayLink.Callback
    }

    private var callbacks: [UUID: PrioritizedCallback] = [:]
    private var displayLinkToken: CrossPlatformDisplayLink.Token?

    private init() {}

    /// Register a callback with priority
    public func register(
        priority: Priority,
        callback: @escaping CrossPlatformDisplayLink.Callback
    ) -> CrossPlatformDisplayLink.Token {
        let token = CrossPlatformDisplayLink.Token(id: UUID())
        callbacks[token.id] = PrioritizedCallback(priority: priority, callback: callback)

        ensureDisplayLinkRunning()

        return token
    }

    /// Unregister a callback
    public func unregister(_ token: CrossPlatformDisplayLink.Token) {
        callbacks.removeValue(forKey: token.id)

        if callbacks.isEmpty {
            stopDisplayLink()
        }
    }

    private func ensureDisplayLinkRunning() {
        guard displayLinkToken == nil else { return }

        displayLinkToken = CrossPlatformDisplayLink.shared.subscribe { [weak self] timestamp, duration in
            self?.tick(timestamp: timestamp, duration: duration)
        }
    }

    private func stopDisplayLink() {
        if let token = displayLinkToken {
            CrossPlatformDisplayLink.shared.unsubscribe(token)
            displayLinkToken = nil
        }
    }

    private func tick(timestamp: CFTimeInterval, duration: CFTimeInterval) {
        // Sort callbacks by priority and execute
        let sorted = callbacks.values.sorted { $0.priority < $1.priority }

        for item in sorted {
            item.callback(timestamp, duration)
        }
    }
}

// MARK: - Convenience Extensions

public extension CrossPlatformDisplayLink {

    /// Subscribe with automatic unsubscription on deinit
    ///
    /// Returns a cancellable that unsubscribes when deallocated.
    func autoSubscribe(_ callback: @escaping Callback) -> DisplayLinkCancellable {
        let token = subscribe(callback)
        return DisplayLinkCancellable(token: token, displayLink: self)
    }
}

/// Cancellable that automatically unsubscribes on deinit
public final class DisplayLinkCancellable {
    private let token: CrossPlatformDisplayLink.Token
    private weak var displayLink: CrossPlatformDisplayLink?

    fileprivate init(token: CrossPlatformDisplayLink.Token, displayLink: CrossPlatformDisplayLink) {
        self.token = token
        self.displayLink = displayLink
    }

    deinit {
        cancel()
    }

    /// Manually cancel the subscription
    public func cancel() {
        Task { @MainActor in
            displayLink?.unsubscribe(token)
        }
    }
}
