//
//  GestureControlPanelView.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  Gesture Control Panel - Multi-touch, 3D Touch, visionOS hand tracking
//  Professional gesture recognition and mapping system
//

import SwiftUI

/// Comprehensive Gesture Control Interface
struct GestureControlPanelView: View {
    @StateObject private var gestureRecognizer = GestureRecognizer.shared
    @StateObject private var gestureMapper = GestureToAudioMapper.shared
    @State private var selectedTab: GestureTab = .recognition

    enum GestureTab: String, CaseIterable {
        case recognition = "Recognition"
        case mapping = "Parameter Mapping"
        case macros = "Gesture Macros"
        case calibration = "Calibration"
        case visualization = "Live Visualization"

        var icon: String {
            switch self {
            case .recognition: return "hand.draw"
            case .mapping: return "arrow.triangle.swap"
            case .macros: return "rectangle.stack"
            case .calibration: return "ruler"
            case .visualization: return "sparkles"
            }
        }
    }

    var body: some View {
        NavigationView {
            // Sidebar
            List(GestureTab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .navigationTitle("Gesture Control")
            .frame(minWidth: 200)

            // Detail view
            Group {
                switch selectedTab {
                case .recognition:
                    GestureRecognitionView()
                case .mapping:
                    GestureMappingView()
                case .macros:
                    GestureMacrosView()
                case .calibration:
                    GestureCalibrationView()
                case .visualization:
                    GestureVisualizationView()
                }
            }
            .frame(minWidth: 700)
        }
    }
}

// MARK: - Gesture Recognition

struct GestureRecognitionView: View {
    @State private var enabledGestures: Set<GestureType> = [.tap, .swipe, .pinch, .rotate]
    @State private var sensitivity: Double = 0.7

    enum GestureType: String, CaseIterable, Identifiable {
        case tap = "Tap"
        case doubleTap = "Double Tap"
        case longPress = "Long Press"
        case swipe = "Swipe"
        case pan = "Pan"
        case pinch = "Pinch"
        case rotate = "Rotate"
        case threeFingerSwipe = "3-Finger Swipe"
        case fourFingerSwipe = "4-Finger Swipe"
        case spread = "Spread"
        case twoFingerTap = "2-Finger Tap"
        case force = "3D Touch / Force"

        #if os(visionOS)
        case handPinch = "Hand Pinch (visionOS)"
        case handPoint = "Hand Point (visionOS)"
        case handGrab = "Hand Grab (visionOS)"
        case handSwipe = "Hand Swipe (visionOS)"
        #endif

        var id: String { rawValue }

        var description: String {
            switch self {
            case .tap: return "Single finger tap"
            case .doubleTap: return "Quick double tap"
            case .longPress: return "Press and hold"
            case .swipe: return "Quick directional swipe"
            case .pan: return "Continuous drag movement"
            case .pinch: return "Two-finger pinch in/out"
            case .rotate: return "Two-finger rotation"
            case .threeFingerSwipe: return "Three-finger swipe"
            case .fourFingerSwipe: return "Four-finger swipe"
            case .spread: return "Fingers spreading apart"
            case .twoFingerTap: return "Two-finger tap"
            case .force: return "Pressure-sensitive touch"
            #if os(visionOS)
            case .handPinch: return "Thumb and finger pinch in air"
            case .handPoint: return "Point with index finger"
            case .handGrab: return "Grab with full hand"
            case .handSwipe: return "Hand swipe in air"
            #endif
            }
        }

        var icon: String {
            switch self {
            case .tap: return "hand.tap"
            case .doubleTap: return "hand.tap.fill"
            case .longPress: return "hand.point.down"
            case .swipe: return "hand.draw"
            case .pan: return "arrow.up.and.down.and.arrow.left.and.right"
            case .pinch: return "arrow.down.left.and.arrow.up.right"
            case .rotate: return "arrow.triangle.2.circlepath"
            case .threeFingerSwipe: return "hand.raised.fingers.spread"
            case .fourFingerSwipe: return "hand.raised.slash"
            case .spread: return "arrow.up.left.and.arrow.down.right"
            case .twoFingerTap: return "hand.point.up.left"
            case .force: return "hand.thumbsup"
            #if os(visionOS)
            case .handPinch: return "hand.pinch"
            case .handPoint: return "hand.point.left"
            case .handGrab: return "hand.raised"
            case .handSwipe: return "hand.wave"
            #endif
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Gesture Recognition")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Configure which gestures are recognized by the system")
                    .foregroundColor(.secondary)

                // Sensitivity
                GroupBox("Global Sensitivity") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Recognition Sensitivity")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(sensitivity * 100))%")
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $sensitivity, in: 0.1...1.0, step: 0.1)

                        Text("Higher sensitivity = more responsive but may trigger accidentally")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }

                // Gesture list
                GroupBox("Enabled Gestures") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 300))], spacing: 12) {
                        ForEach(GestureType.allCases) { gestureType in
                            GestureToggleRow(
                                gestureType: gestureType,
                                isEnabled: enabledGestures.contains(gestureType),
                                onToggle: { isOn in
                                    if isOn {
                                        enabledGestures.insert(gestureType)
                                    } else {
                                        enabledGestures.remove(gestureType)
                                    }
                                }
                            )
                        }
                    }
                    .padding()
                }

                // Presets
                GroupBox("Presets") {
                    HStack(spacing: 12) {
                        Button("Essential Gestures") {
                            enabledGestures = [.tap, .swipe, .pinch, .rotate]
                        }
                        .buttonStyle(.bordered)

                        Button("All Touch Gestures") {
                            enabledGestures = Set(GestureType.allCases.filter { gesture in
                                #if os(visionOS)
                                return ![.handPinch, .handPoint, .handGrab, .handSwipe].contains(gesture)
                                #else
                                return true
                                #endif
                            })
                        }
                        .buttonStyle(.bordered)

                        #if os(visionOS)
                        Button("visionOS Hand Tracking") {
                            enabledGestures = [.handPinch, .handPoint, .handGrab, .handSwipe]
                        }
                        .buttonStyle(.bordered)
                        #endif

                        Button("Disable All") {
                            enabledGestures = []
                        }
                        .buttonStyle(.bordered)
                    }
                    .padding()
                }
            }
            .padding()
        }
    }
}

struct GestureToggleRow: View {
    let gestureType: GestureRecognitionView.GestureType
    let isEnabled: Bool
    let onToggle: (Bool) -> Void

    var body: some View {
        HStack {
            Image(systemName: gestureType.icon)
                .font(.title2)
                .foregroundColor(isEnabled ? .accentColor : .gray)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(gestureType.rawValue)
                    .font(.headline)
                Text(gestureType.description)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            Toggle("", isOn: Binding(
                get: { isEnabled },
                set: { onToggle($0) }
            ))
            .labelsHidden()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(Color.gray.opacity(isEnabled ? 0.15 : 0.05))
        .cornerRadius(8)
    }
}

// MARK: - Gesture Mapping

struct GestureMappingView: View {
    @State private var mappings: [GestureMapping] = [
        GestureMapping(gesture: "Swipe Up", parameter: "Volume", min: 0, max: 1),
        GestureMapping(gesture: "Swipe Down", parameter: "Volume", min: 0, max: 1),
        GestureMapping(gesture: "Pinch In", parameter: "Filter Cutoff", min: 20, max: 20000),
        GestureMapping(gesture: "Pinch Out", parameter: "Filter Cutoff", min: 20, max: 20000),
        GestureMapping(gesture: "Rotate CW", parameter: "Reverb Mix", min: 0, max: 1),
        GestureMapping(gesture: "Rotate CCW", parameter: "Reverb Mix", min: 0, max: 1),
    ]

    struct GestureMapping: Identifiable {
        let id = UUID()
        let gesture: String
        var parameter: String
        var min: Double
        var max: Double
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                HStack {
                    Text("Parameter Mapping")
                        .font(.largeTitle)
                        .fontWeight(.bold)
                    Spacer()
                    Button {
                        // Add mapping
                    } label: {
                        Label("Add Mapping", systemImage: "plus.circle")
                    }
                    .buttonStyle(.borderedProminent)
                }

                Text("Map gestures to audio/video parameters for hands-on control")
                    .foregroundColor(.secondary)

                // Mappings list
                GroupBox("Active Mappings") {
                    LazyVStack(spacing: 16) {
                        ForEach($mappings) { $mapping in
                            GestureMappingRow(mapping: $mapping)
                        }
                    }
                    .padding()
                }

                // Quick mapping suggestions
                GroupBox("Common Mappings") {
                    VStack(spacing: 8) {
                        QuickMappingButton(gesture: "Two-Finger Tap", parameter: "Play/Pause")
                        QuickMappingButton(gesture: "Three-Finger Swipe Left", parameter: "Previous Track")
                        QuickMappingButton(gesture: "Three-Finger Swipe Right", parameter: "Next Track")
                        QuickMappingButton(gesture: "Long Press", parameter: "Record")
                        QuickMappingButton(gesture: "3D Touch", parameter: "Velocity")
                    }
                    .padding()
                }
            }
            .padding()
        }
    }
}

struct GestureMappingRow: View {
    @Binding var mapping: GestureMappingView.GestureMapping

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading) {
                    Text(mapping.gesture)
                        .font(.headline)
                    Text("Controls: \(mapping.parameter)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                Button {
                    // Edit mapping
                } label: {
                    Image(systemName: "pencil")
                }
                .buttonStyle(.bordered)
            }

            HStack {
                Text("Range:")
                    .font(.caption)
                Spacer()
                Text(String(format: "%.2f - %.2f", mapping.min, mapping.max))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }
}

struct QuickMappingButton: View {
    let gesture: String
    let parameter: String

    var body: some View {
        Button {
            // Add this mapping
        } label: {
            HStack {
                Text(gesture)
                    .fontWeight(.medium)
                Image(systemName: "arrow.right")
                    .foregroundColor(.secondary)
                Text(parameter)
                Spacer()
                Image(systemName: "plus.circle")
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.05))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Gesture Macros

struct GestureMacrosView: View {
    @State private var macros: [GestureMacro] = [
        GestureMacro(name: "Performance Mode", gesture: "Four-Finger Tap", actions: ["Enable MIDI Echo", "Set Buffer to 64", "Disable Effects"]),
        GestureMacro(name: "Mix Mode", gesture: "Spread", actions: ["Open Mixer", "Show All Channels", "Enable Master Fader"])
    ]

    struct GestureMacro: Identifiable {
        let id = UUID()
        var name: String
        var gesture: String
        var actions: [String]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            HStack {
                Text("Gesture Macros")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                Button {
                    // Create macro
                } label: {
                    Label("New Macro", systemImage: "plus.circle")
                }
                .buttonStyle(.borderedProminent)
            }

            Text("Trigger multiple actions with a single gesture")
                .foregroundColor(.secondary)

            List {
                ForEach($macros) { $macro in
                    DisclosureGroup {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Actions:")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            ForEach(macro.actions.indices, id: \.self) { index in
                                HStack {
                                    Text("\(index + 1).")
                                        .foregroundColor(.secondary)
                                    Text(macro.actions[index])
                                }
                                .font(.caption)
                            }
                        }
                        .padding(.top, 8)
                    } label: {
                        HStack {
                            VStack(alignment: .leading) {
                                Text(macro.name)
                                    .font(.headline)
                                Text("Trigger: \(macro.gesture)")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text("\(macro.actions.count) actions")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                }
            }
        }
        .padding()
    }
}

// MARK: - Gesture Calibration

struct GestureCalibrationView: View {
    @State private var swipeThreshold: Double = 50
    @State private var pinchThreshold: Double = 0.3
    @State private var rotationThreshold: Double = 15
    @State private var longPressLength: Double = 0.5
    @State private var forceThreshold: Double = 0.5

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Gesture Calibration")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Fine-tune gesture recognition thresholds")
                    .foregroundColor(.secondary)

                // Swipe
                GroupBox("Swipe Threshold") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Minimum Distance")
                            Spacer()
                            Text("\(Int(swipeThreshold)) points")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $swipeThreshold, in: 20...200, step: 5)
                        Text("Distance required to register as a swipe")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }

                // Pinch
                GroupBox("Pinch Threshold") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Minimum Scale Change")
                            Spacer()
                            Text(String(format: "%.2f", pinchThreshold))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $pinchThreshold, in: 0.1...1.0, step: 0.05)
                        Text("Scale factor change required to register pinch")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }

                // Rotation
                GroupBox("Rotation Threshold") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Minimum Angle")
                            Spacer()
                            Text("\(Int(rotationThreshold))°")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $rotationThreshold, in: 5...45, step: 5)
                        Text("Rotation angle required to register")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }

                // Long Press
                GroupBox("Long Press Duration") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Minimum Hold Time")
                            Spacer()
                            Text(String(format: "%.1f seconds", longPressLength))
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $longPressLength, in: 0.2...2.0, step: 0.1)
                        Text("How long to hold for long press")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }

                // 3D Touch / Force
                GroupBox("Force Sensitivity") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Force Threshold")
                            Spacer()
                            Text("\(Int(forceThreshold * 100))%")
                                .foregroundColor(.secondary)
                        }
                        Slider(value: $forceThreshold, in: 0.1...1.0, step: 0.05)
                        Text("Pressure required to trigger 3D touch")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }

                Button("Reset to Defaults") {
                    swipeThreshold = 50
                    pinchThreshold = 0.3
                    rotationThreshold = 15
                    longPressLength = 0.5
                    forceThreshold = 0.5
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
    }
}

// MARK: - Gesture Visualization

struct GestureVisualizationView: View {
    @State private var touchPoints: [TouchPoint] = []
    @State private var lastGesture: String = "None"

    struct TouchPoint: Identifiable {
        let id = UUID()
        var position: CGPoint
        var force: Double
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Live Gesture Visualization")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Real-time visualization of touch input and gestures")
                .foregroundColor(.secondary)

            // Touch surface
            GroupBox("Touch Surface") {
                ZStack {
                    Rectangle()
                        .fill(Color.black)

                    if touchPoints.isEmpty {
                        Text("Touch the trackpad or screen")
                            .foregroundColor(.white.opacity(0.3))
                    } else {
                        ForEach(touchPoints) { point in
                            Circle()
                                .fill(Color.blue.opacity(0.6))
                                .frame(width: 40 + CGFloat(point.force * 40),
                                       height: 40 + CGFloat(point.force * 40))
                                .position(point.position)
                        }
                    }
                }
                .frame(height: 500)
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            touchPoints = [TouchPoint(position: value.location, force: 0.5)]
                        }
                        .onEnded { _ in
                            touchPoints = []
                        }
                )
            }

            // Status
            GroupBox("Gesture Status") {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text("Last Gesture:")
                            .fontWeight(.semibold)
                        Spacer()
                        Text(lastGesture)
                            .foregroundColor(.secondary)
                    }

                    HStack {
                        Text("Active Touch Points:")
                        Spacer()
                        Text("\(touchPoints.count)")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
        }
        .padding()
    }
}

#if DEBUG
struct GestureControlPanelView_Previews: PreviewProvider {
    static var previews: some View {
        GestureControlPanelView()
            .frame(width: 1000, height: 700)
    }
}
#endif
