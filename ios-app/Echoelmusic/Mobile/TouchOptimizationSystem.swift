//
//  TouchOptimizationSystem.swift
//  Echoelmusic
//
//  Advanced touch gesture system optimized for iOS music production
//  with multi-touch, pressure sensitivity, and workflow optimizations.
//

import SwiftUI
import UIKit
import Combine

// MARK: - Touch Optimization System

@MainActor
class TouchOptimizationSystem: ObservableObject {

    // MARK: - Published Properties

    @Published var gestureMode: GestureMode = .standard
    @Published var touchSensitivity: Float = 0.5
    @Published var pressureEnabled: Bool = true
    @Published var hapticsEnabled: Bool = true
    @Published var customGestures: [CustomGesture] = []
    @Published var activeGestures: Set<GestureType> = []

    // MARK: - Gesture Recognition

    private var activeTouches: [UITouch: TouchData] = [:]
    private let hapticGenerator = UIImpactFeedbackGenerator(style: .medium)
    private let selectionGenerator = UISelectionFeedbackGenerator()

    // MARK: - Settings

    var doubleTapThreshold: TimeInterval = 0.3
    var longPressThreshold: TimeInterval = 0.5
    var swipeThreshold: CGFloat = 50
    var pinchThreshold: CGFloat = 10

    // MARK: - Initialization

    init() {
        hapticGenerator.prepare()
        selectionGenerator.prepare()
        setupDefaultGestures()
    }

    // MARK: - Setup

    private func setupDefaultGestures() {
        // Timeline gestures
        customGestures.append(CustomGesture(
            name: "Timeline Scrub",
            type: .pan,
            fingerCount: 1,
            action: .timelineScrub,
            area: .timeline
        ))

        customGestures.append(CustomGesture(
            name: "Zoom Timeline",
            type: .pinch,
            fingerCount: 2,
            action: .zoom,
            area: .timeline
        ))

        // Mixer gestures
        customGestures.append(CustomGesture(
            name: "Adjust Fader",
            type: .pan,
            fingerCount: 1,
            action: .adjustFader,
            area: .mixer
        ))

        customGestures.append(CustomGesture(
            name: "Fine Tune Parameter",
            type: .panWithPressure,
            fingerCount: 1,
            action: .fineTune,
            area: .mixer
        ))

        // Piano roll gestures
        customGestures.append(CustomGesture(
            name: "Draw Notes",
            type: .pan,
            fingerCount: 1,
            action: .drawNotes,
            area: .pianoRoll
        ))

        customGestures.append(CustomGesture(
            name: "Select Multiple Notes",
            type: .pan,
            fingerCount: 2,
            action: .selectMultiple,
            area: .pianoRoll
        ))

        // General gestures
        customGestures.append(CustomGesture(
            name: "Undo",
            type: .swipe,
            fingerCount: 3,
            direction: .left,
            action: .undo,
            area: .global
        ))

        customGestures.append(CustomGesture(
            name: "Redo",
            type: .swipe,
            fingerCount: 3,
            direction: .right,
            action: .redo,
            area: .global
        ))

        customGestures.append(CustomGesture(
            name: "Quick Save",
            type: .doubleTap,
            fingerCount: 2,
            action: .save,
            area: .global
        ))
    }

    // MARK: - Touch Handling

    func handleTouchesBegan(_ touches: Set<UITouch>, in view: UIView) {
        for touch in touches {
            let location = touch.location(in: view)
            let touchData = TouchData(
                touch: touch,
                startLocation: location,
                currentLocation: location,
                startTime: Date(),
                force: touch.force,
                maximumPossibleForce: touch.maximumPossibleForce
            )
            activeTouches[touch] = touchData
        }

        recognizeGesture()
    }

    func handleTouchesMoved(_ touches: Set<UITouch>, in view: UIView) {
        for touch in touches {
            guard var touchData = activeTouches[touch] else { continue }

            touchData.currentLocation = touch.location(in: view)
            touchData.force = touch.force
            activeTouches[touch] = touchData
        }

        recognizeGesture()
    }

    func handleTouchesEnded(_ touches: Set<UITouch>, in view: UIView) {
        for touch in touches {
            activeTouches.removeValue(forKey: touch)
        }

        if activeTouches.isEmpty {
            activeGestures.removeAll()
        }
    }

    // MARK: - Gesture Recognition

    private func recognizeGesture() {
        let touchCount = activeTouches.count

        guard touchCount > 0 else { return }

        // Single finger gestures
        if touchCount == 1, let touchData = activeTouches.values.first {
            recognizeSingleFingerGesture(touchData)
        }
        // Two finger gestures
        else if touchCount == 2 {
            recognizeTwoFingerGesture()
        }
        // Three+ finger gestures
        else if touchCount >= 3 {
            recognizeMultiFingerGesture()
        }
    }

    private func recognizeSingleFingerGesture(_ touchData: TouchData) {
        let distance = touchData.distance
        let duration = Date().timeIntervalSince(touchData.startTime)

        // Long press
        if duration > longPressThreshold && distance < 10 {
            if !activeGestures.contains(.longPress) {
                activeGestures.insert(.longPress)
                triggerHaptic(.medium)
            }
        }
        // Pan/Drag
        else if distance > swipeThreshold {
            if !activeGestures.contains(.pan) {
                activeGestures.insert(.pan)
            }
        }
        // Pressure-based gestures
        else if pressureEnabled && touchData.normalizedForce > 0.7 {
            if !activeGestures.contains(.deepPress) {
                activeGestures.insert(.deepPress)
                triggerHaptic(.heavy)
            }
        }
    }

    private func recognizeTwoFingerGesture() {
        guard activeTouches.count == 2 else { return }

        let touches = Array(activeTouches.values)
        let distance = touches[0].currentLocation.distance(to: touches[1].currentLocation)
        let startDistance = touches[0].startLocation.distance(to: touches[1].startLocation)
        let distanceDelta = abs(distance - startDistance)

        // Pinch
        if distanceDelta > pinchThreshold {
            if !activeGestures.contains(.pinch) {
                activeGestures.insert(.pinch)
                triggerHaptic(.light)
            }
        }

        // Two finger pan
        let avgMovement = (touches[0].distance + touches[1].distance) / 2
        if avgMovement > swipeThreshold {
            if !activeGestures.contains(.twoFingerPan) {
                activeGestures.insert(.twoFingerPan)
            }
        }

        // Rotation
        let startAngle = atan2(
            touches[1].startLocation.y - touches[0].startLocation.y,
            touches[1].startLocation.x - touches[0].startLocation.x
        )
        let currentAngle = atan2(
            touches[1].currentLocation.y - touches[0].currentLocation.y,
            touches[1].currentLocation.x - touches[0].currentLocation.x
        )
        let rotationDelta = abs(currentAngle - startAngle)

        if rotationDelta > 0.1 {
            if !activeGestures.contains(.rotation) {
                activeGestures.insert(.rotation)
                triggerHaptic(.light)
            }
        }
    }

    private func recognizeMultiFingerGesture() {
        let touches = Array(activeTouches.values)

        // Calculate average movement
        let avgDx = touches.map { $0.delta.x }.reduce(0, +) / CGFloat(touches.count)
        let avgDy = touches.map { $0.delta.y }.reduce(0, +) / CGFloat(touches.count)

        // Three finger swipe
        if activeTouches.count == 3 {
            if abs(avgDx) > swipeThreshold {
                let direction: SwipeDirection = avgDx > 0 ? .right : .left

                if !activeGestures.contains(.threeFingerSwipe) {
                    activeGestures.insert(.threeFingerSwipe)
                    handleThreeFingerSwipe(direction: direction)
                }
            }
        }

        // Four finger gestures
        if activeTouches.count == 4 {
            if abs(avgDy) > swipeThreshold {
                let direction: SwipeDirection = avgDy > 0 ? .down : .up

                if !activeGestures.contains(.fourFingerSwipe) {
                    activeGestures.insert(.fourFingerSwipe)
                    handleFourFingerSwipe(direction: direction)
                }
            }
        }
    }

    // MARK: - Gesture Actions

    private func handleThreeFingerSwipe(direction: SwipeDirection) {
        triggerHaptic(.medium)

        switch direction {
        case .left:
            NotificationCenter.default.post(name: .gestureUndo, object: nil)
        case .right:
            NotificationCenter.default.post(name: .gestureRedo, object: nil)
        default:
            break
        }
    }

    private func handleFourFingerSwipe(direction: SwipeDirection) {
        triggerHaptic(.medium)

        switch direction {
        case .up:
            NotificationCenter.default.post(name: .gestureMixerToggle, object: nil)
        case .down:
            NotificationCenter.default.post(name: .gestureBrowserToggle, object: nil)
        default:
            break
        }
    }

    // MARK: - Haptics

    func triggerHaptic(_ style: UIImpactFeedbackGenerator.FeedbackStyle) {
        guard hapticsEnabled else { return }

        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }

    func triggerSelectionHaptic() {
        guard hapticsEnabled else { return }
        selectionGenerator.selectionChanged()
    }

    // MARK: - Advanced Touch Features

    func getPressureCurve(normalizedForce: CGFloat) -> CGFloat {
        switch gestureMode {
        case .standard:
            return normalizedForce
        case .light:
            return pow(normalizedForce, 0.7)
        case .heavy:
            return pow(normalizedForce, 1.3)
        case .custom(let curve):
            return applyCurve(normalizedForce, curve: curve)
        }
    }

    private func applyCurve(_ value: CGFloat, curve: PressureCurve) -> CGFloat {
        switch curve {
        case .linear:
            return value
        case .exponential(let power):
            return pow(value, power)
        case .logarithmic:
            return log(1 + value * 9) / log(10)
        case .sigmoid:
            return 1 / (1 + exp(-10 * (value - 0.5)))
        }
    }
}

// MARK: - Enhanced Gesture Recognizers

class MusicProductionPanGestureRecognizer: UIPanGestureRecognizer {
    var onPan: ((CGPoint, CGFloat) -> Void)?
    var onPressureChange: ((CGFloat) -> Void)?

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)

        guard let touch = touches.first else { return }

        let location = touch.location(in: view)
        let force = touch.force / touch.maximumPossibleForce

        onPan?(location, force)
        onPressureChange?(force)
    }
}

class DoubleTapGestureRecognizer: UITapGestureRecognizer {
    var onDoubleTap: (() -> Void)?

    override init(target: Any?, action: Selector?) {
        super.init(target: target, action: action)
        numberOfTapsRequired = 2
    }
}

class DrawingGestureRecognizer: UIPanGestureRecognizer {
    var drawnPoints: [CGPoint] = []
    var onDrawingComplete: (([CGPoint]) -> Void)?

    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesBegan(touches, with: event)
        drawnPoints.removeAll()
    }

    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesMoved(touches, with: event)

        if let touch = touches.first {
            let location = touch.location(in: view)
            drawnPoints.append(location)
        }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        super.touchesEnded(touches, with: event)
        onDrawingComplete?(drawnPoints)
    }
}

// MARK: - Touch-Optimized UI Components

struct TouchOptimizedSlider: View {
    @Binding var value: Float
    let range: ClosedRange<Float>
    let label: String

    @State private var isDragging = false
    @State private var lastPressure: CGFloat = 0
    @EnvironmentObject var touchSystem: TouchOptimizationSystem

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                    .font(.caption)
                Spacer()
                Text(String(format: "%.2f", value))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 44) // iOS-optimized touch target

                    // Fill
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color.accentColor)
                        .frame(width: CGFloat(normalizedValue) * geometry.size.width, height: 44)

                    // Thumb
                    Circle()
                        .fill(Color.white)
                        .frame(width: 32, height: 32)
                        .shadow(radius: 2)
                        .offset(x: CGFloat(normalizedValue) * (geometry.size.width - 32))
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { gesture in
                            if !isDragging {
                                isDragging = true
                                touchSystem.triggerSelectionHaptic()
                            }

                            let normalizedPosition = min(max(0, gesture.location.x / geometry.size.width), 1)
                            value = Float(normalizedPosition) * (range.upperBound - range.lowerBound) + range.lowerBound
                        }
                        .onEnded { _ in
                            isDragging = false
                        }
                )
            }
            .frame(height: 44)
        }
    }

    private var normalizedValue: Float {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }
}

struct TouchOptimizedKnob: View {
    @Binding var value: Float
    let range: ClosedRange<Float>
    let label: String

    @State private var isDragging = false
    @State private var startValue: Float = 0
    @State private var startY: CGFloat = 0
    @EnvironmentObject var touchSystem: TouchOptimizationSystem

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Knob background
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [Color.gray.opacity(0.3), Color.gray.opacity(0.5)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 64, height: 64)

                // Value indicator
                Circle()
                    .trim(from: 0, to: CGFloat(normalizedValue))
                    .stroke(Color.accentColor, lineWidth: 4)
                    .rotationEffect(.degrees(-90))
                    .frame(width: 56, height: 56)

                // Center dot
                Circle()
                    .fill(Color.white)
                    .frame(width: 8, height: 8)

                // Indicator line
                Rectangle()
                    .fill(Color.white)
                    .frame(width: 2, height: 20)
                    .offset(y: -18)
                    .rotationEffect(.degrees(Double(normalizedValue) * 270 - 135))
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { gesture in
                        if !isDragging {
                            isDragging = true
                            startValue = value
                            startY = gesture.startLocation.y
                            touchSystem.triggerSelectionHaptic()
                        }

                        let delta = Float(startY - gesture.location.y) / 100
                        let newValue = startValue + delta * (range.upperBound - range.lowerBound)
                        value = min(max(newValue, range.lowerBound), range.upperBound)
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )

            Text(label)
                .font(.caption)

            Text(String(format: "%.2f", value))
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }

    private var normalizedValue: Float {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }
}

struct TouchOptimizedButton: View {
    let label: String
    let icon: String?
    let action: () -> Void

    @State private var isPressed = false
    @EnvironmentObject var touchSystem: TouchOptimizationSystem

    var body: some View {
        Button(action: {
            touchSystem.triggerHaptic(.medium)
            action()
        }) {
            HStack(spacing: 8) {
                if let icon = icon {
                    Image(systemName: icon)
                }
                Text(label)
            }
            .frame(minWidth: 44, minHeight: 44) // iOS minimum touch target
            .padding(.horizontal, 16)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isPressed ? Color.accentColor.opacity(0.8) : Color.accentColor)
            )
            .foregroundColor(.white)
            .scaleEffect(isPressed ? 0.95 : 1.0)
        }
        .buttonStyle(PlainButtonStyle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in
                    if !isPressed {
                        isPressed = true
                        touchSystem.triggerHaptic(.light)
                    }
                }
                .onEnded { _ in
                    isPressed = false
                }
        )
    }
}

// MARK: - Workflow Optimizations

struct QuickActionMenu: View {
    let actions: [QuickAction]
    @Binding var isPresented: Bool

    @EnvironmentObject var touchSystem: TouchOptimizationSystem

    var body: some View {
        if isPresented {
            ZStack {
                Color.black.opacity(0.3)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isPresented = false
                    }

                VStack(spacing: 0) {
                    ForEach(actions) { action in
                        Button(action: {
                            touchSystem.triggerHaptic(.medium)
                            action.perform()
                            isPresented = false
                        }) {
                            HStack {
                                Image(systemName: action.icon)
                                    .frame(width: 24)
                                Text(action.title)
                                Spacer()
                            }
                            .padding()
                            .frame(height: 54)
                        }
                        .foregroundColor(.primary)

                        if action != actions.last {
                            Divider()
                        }
                    }
                }
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
                .shadow(radius: 20)
                .padding()
            }
            .transition(.opacity)
        }
    }
}

struct FloatingToolbar: View {
    let tools: [Tool]
    @Binding var selectedTool: Tool?

    @EnvironmentObject var touchSystem: TouchOptimizationSystem

    var body: some View {
        HStack(spacing: 12) {
            ForEach(tools) { tool in
                Button(action: {
                    touchSystem.triggerSelectionHaptic()
                    selectedTool = tool
                }) {
                    VStack(spacing: 4) {
                        Image(systemName: tool.icon)
                            .font(.system(size: 20))
                        Text(tool.name)
                            .font(.caption2)
                    }
                    .frame(width: 60, height: 60)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(selectedTool?.id == tool.id ? Color.accentColor : Color.gray.opacity(0.2))
                    )
                    .foregroundColor(selectedTool?.id == tool.id ? .white : .primary)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(UIColor.systemBackground))
                .shadow(radius: 10)
        )
    }
}

// MARK: - Data Structures

struct TouchData {
    let touch: UITouch
    let startLocation: CGPoint
    var currentLocation: CGPoint
    let startTime: Date
    var force: CGFloat
    let maximumPossibleForce: CGFloat

    var normalizedForce: CGFloat {
        guard maximumPossibleForce > 0 else { return 0 }
        return force / maximumPossibleForce
    }

    var distance: CGFloat {
        startLocation.distance(to: currentLocation)
    }

    var delta: CGPoint {
        CGPoint(
            x: currentLocation.x - startLocation.x,
            y: currentLocation.y - startLocation.y
        )
    }
}

enum GestureType: Hashable {
    case tap
    case doubleTap
    case longPress
    case pan
    case twoFingerPan
    case pinch
    case rotation
    case swipe
    case threeFingerSwipe
    case fourFingerSwipe
    case deepPress
}

enum GestureMode {
    case standard
    case light
    case heavy
    case custom(PressureCurve)
}

enum PressureCurve {
    case linear
    case exponential(power: CGFloat)
    case logarithmic
    case sigmoid
}

enum SwipeDirection {
    case up, down, left, right
}

enum GestureArea {
    case global
    case timeline
    case mixer
    case pianoRoll
    case browser
    case transport
}

enum GestureAction {
    case timelineScrub
    case zoom
    case adjustFader
    case fineTune
    case drawNotes
    case selectMultiple
    case undo
    case redo
    case save
    case delete
    case copy
    case paste
    case duplicate
}

struct CustomGesture: Identifiable {
    let id = UUID()
    var name: String
    var type: GestureType
    var fingerCount: Int
    var direction: SwipeDirection?
    var action: GestureAction
    var area: GestureArea
}

struct QuickAction: Identifiable {
    let id = UUID()
    let title: String
    let icon: String
    let perform: () -> Void
}

struct Tool: Identifiable, Equatable {
    let id = UUID()
    let name: String
    let icon: String

    static func == (lhs: Tool, rhs: Tool) -> Bool {
        lhs.id == rhs.id
    }
}

// MARK: - Extensions

extension CGPoint {
    func distance(to point: CGPoint) -> CGFloat {
        sqrt(pow(x - point.x, 2) + pow(y - point.y, 2))
    }
}

extension Notification.Name {
    static let gestureUndo = Notification.Name("gestureUndo")
    static let gestureRedo = Notification.Name("gestureRedo")
    static let gestureSave = Notification.Name("gestureSave")
    static let gestureMixerToggle = Notification.Name("gestureMixerToggle")
    static let gestureBrowserToggle = Notification.Name("gestureBrowserToggle")
}
