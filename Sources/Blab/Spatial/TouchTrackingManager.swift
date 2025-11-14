import Foundation
import SwiftUI
import Combine

/// Manages multi-touch tracking for iOS screen interactions
/// Tracks up to 10 simultaneous touch points with velocity and pressure
@MainActor
public class TouchTrackingManager: ObservableObject {

    // MARK: - Published Properties

    /// All active touch points
    @Published public private(set) var activeTouches: [TouchPoint] = []

    /// Primary touch point (first touch)
    @Published public private(set) var primaryTouch: TouchPoint?

    /// Whether multi-touch is currently active (2+ fingers)
    @Published public private(set) var isMultiTouch: Bool = false

    /// Touch count
    @Published public private(set) var touchCount: Int = 0

    /// Gesture type detected from multi-touch
    @Published public private(set) var touchGesture: TouchGesture = .none


    // MARK: - Touch Point Data

    public struct TouchPoint: Identifiable {
        public let id: UUID

        /// Normalized position (0-1, 0-1)
        public var position: CGPoint

        /// Previous position (for velocity calculation)
        public var previousPosition: CGPoint

        /// Touch velocity (points per second)
        public var velocity: CGVector

        /// Touch pressure (0-1, if available)
        public var pressure: Float

        /// Touch timestamp
        public var timestamp: Date

        /// Touch phase
        public var phase: TouchPhase

        public enum TouchPhase {
            case began
            case moved
            case ended
            case cancelled
        }
    }


    // MARK: - Touch Gestures

    public enum TouchGesture: String {
        case none = "None"
        case tap = "Tap"
        case doubleTap = "Double Tap"
        case longPress = "Long Press"
        case pan = "Pan"
        case pinch = "Pinch"
        case rotate = "Rotate"
        case swipe = "Swipe"
    }


    // MARK: - Private Properties

    private var touchTracking: [UUID: TouchPoint] = [:]
    private var lastTapTime: Date?
    private let doubleTapThreshold: TimeInterval = 0.3 // 300ms
    private let longPressThreshold: TimeInterval = 0.5 // 500ms

    // Gesture recognition state
    private var gestureStartTime: Date?
    private var initialPinchDistance: CGFloat?
    private var initialRotationAngle: CGFloat?


    // MARK: - Public Methods

    /// Handle touch began event
    public func touchBegan(id: UUID = UUID(), location: CGPoint, pressure: Float = 1.0, in bounds: CGSize) {
        let normalizedLocation = CGPoint(
            x: location.x / bounds.width,
            y: location.y / bounds.height
        )

        let touchPoint = TouchPoint(
            id: id,
            position: normalizedLocation,
            previousPosition: normalizedLocation,
            velocity: .zero,
            pressure: pressure,
            timestamp: Date(),
            phase: .began
        )

        touchTracking[id] = touchPoint
        updatePublishedState()

        // Start gesture detection
        if touchCount == 1 {
            gestureStartTime = Date()
        }

        // Check for double tap
        if let lastTap = lastTapTime, Date().timeIntervalSince(lastTap) < doubleTapThreshold {
            touchGesture = .doubleTap
            lastTapTime = nil
        } else {
            lastTapTime = Date()
        }

        print("👆 Touch began: \(touchCount) touches")
    }

    /// Handle touch moved event
    public func touchMoved(id: UUID, location: CGPoint, pressure: Float = 1.0, in bounds: CGSize) {
        guard var touchPoint = touchTracking[id] else { return }

        let normalizedLocation = CGPoint(
            x: location.x / bounds.width,
            y: location.y / bounds.height
        )

        // Calculate velocity
        let deltaTime = Date().timeIntervalSince(touchPoint.timestamp)
        if deltaTime > 0 {
            let deltaX = (normalizedLocation.x - touchPoint.position.x) * bounds.width
            let deltaY = (normalizedLocation.y - touchPoint.position.y) * bounds.height
            touchPoint.velocity = CGVector(
                dx: deltaX / deltaTime,
                dy: deltaY / deltaTime
            )
        }

        touchPoint.previousPosition = touchPoint.position
        touchPoint.position = normalizedLocation
        touchPoint.pressure = pressure
        touchPoint.timestamp = Date()
        touchPoint.phase = .moved

        touchTracking[id] = touchPoint
        updatePublishedState()

        // Detect gestures based on movement
        detectGestures()
    }

    /// Handle touch ended event
    public func touchEnded(id: UUID) {
        guard var touchPoint = touchTracking[id] else { return }

        touchPoint.phase = .ended
        touchTracking[id] = touchPoint

        // Check for tap vs long press
        if let startTime = gestureStartTime,
           Date().timeIntervalSince(startTime) < longPressThreshold,
           touchPoint.velocity.magnitude < 100 {
            if touchGesture != .doubleTap {
                touchGesture = .tap
            }
        }

        // Remove touch after brief delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.touchTracking.removeValue(forKey: id)
            self?.updatePublishedState()

            if self?.touchCount == 0 {
                self?.touchGesture = .none
                self?.gestureStartTime = nil
                self?.initialPinchDistance = nil
                self?.initialRotationAngle = nil
            }
        }

        print("👆 Touch ended: \(touchCount - 1) touches remaining")
    }

    /// Handle touch cancelled event
    public func touchCancelled(id: UUID) {
        touchTracking.removeValue(forKey: id)
        updatePublishedState()

        if touchCount == 0 {
            touchGesture = .none
            gestureStartTime = nil
        }
    }

    /// Clear all touches (e.g., on scene change)
    public func clearAllTouches() {
        touchTracking.removeAll()
        updatePublishedState()
        touchGesture = .none
        gestureStartTime = nil
    }


    // MARK: - Private Methods

    private func updatePublishedState() {
        activeTouches = Array(touchTracking.values).sorted { $0.timestamp < $1.timestamp }
        primaryTouch = activeTouches.first
        touchCount = activeTouches.count
        isMultiTouch = touchCount >= 2
    }

    private func detectGestures() {
        guard touchCount >= 2 else {
            // Single touch gestures
            if let primary = primaryTouch {
                // Check for swipe
                if primary.velocity.magnitude > 500 {
                    touchGesture = .swipe
                }
                // Check for pan
                else if primary.velocity.magnitude > 50 {
                    touchGesture = .pan
                }
                // Check for long press
                else if let startTime = gestureStartTime,
                        Date().timeIntervalSince(startTime) > longPressThreshold {
                    touchGesture = .longPress
                }
            }
            return
        }

        // Multi-touch gestures
        let touches = Array(activeTouches.prefix(2))
        guard touches.count == 2 else { return }

        let touch1 = touches[0]
        let touch2 = touches[1]

        // Calculate distance for pinch detection
        let currentDistance = distance(touch1.position, touch2.position)

        if initialPinchDistance == nil {
            initialPinchDistance = currentDistance
        }

        if let initialDistance = initialPinchDistance {
            let distanceChange = abs(currentDistance - initialDistance)
            if distanceChange > 0.05 { // 5% threshold
                touchGesture = .pinch
            }
        }

        // Calculate angle for rotation detection
        let currentAngle = angle(from: touch1.position, to: touch2.position)

        if initialRotationAngle == nil {
            initialRotationAngle = currentAngle
        }

        if let initialAngle = initialRotationAngle {
            let angleChange = abs(currentAngle - initialAngle)
            if angleChange > 0.1 { // ~6 degrees threshold
                touchGesture = .rotate
            }
        }
    }


    // MARK: - Utility Methods

    private func distance(_ p1: CGPoint, _ p2: CGPoint) -> CGFloat {
        return sqrt(pow(p2.x - p1.x, 2) + pow(p2.y - p1.y, 2))
    }

    private func angle(from p1: CGPoint, to p2: CGPoint) -> CGFloat {
        return atan2(p2.y - p1.y, p2.x - p1.x)
    }


    // MARK: - Debug Description

    public var description: String {
        """
        TouchTrackingManager:
          Active Touches: \(touchCount)
          Multi-Touch: \(isMultiTouch ? "Yes" : "No")
          Gesture: \(touchGesture.rawValue)
          Primary Touch: \(primaryTouch.map { "(\(String(format: "%.2f", $0.position.x)), \(String(format: "%.2f", $0.position.y)))" } ?? "None")
        """
    }
}


// MARK: - CGVector Extension

extension CGVector {
    var magnitude: CGFloat {
        return sqrt(dx * dx + dy * dy)
    }
}
