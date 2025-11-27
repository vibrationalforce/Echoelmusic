//
//  MPEConfigurationView.swift
//  Echoelmusic
//
//  Created: 2025-11-25
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  MPE (MIDI Polyphonic Expression) Configuration Panel
//  Professional setup for Roli Seaboard, Linnstrument, Haken Continuum, Osmose, etc.
//

import SwiftUI

/// Comprehensive MPE Configuration Interface
struct MPEConfigurationView: View {
    @StateObject private var mpeManager = MPEZoneManager.shared
    @State private var selectedTab: MPETab = .zones

    enum MPETab: String, CaseIterable {
        case zones = "Zone Configuration"
        case mapping = "Dimension Mapping"
        case calibration = "Calibration"
        case devices = "MPE Devices"
        case visualization = "Live Visualization"

        var icon: String {
            switch self {
            case .zones: return "rectangle.3.group"
            case .mapping: return "slider.horizontal.3"
            case .calibration: return "tuningfork"
            case .devices: return "pianokeys"
            case .visualization: return "waveform"
            }
        }
    }

    var body: some View {
        NavigationView {
            // Sidebar
            List(MPETab.allCases, id: \.self, selection: $selectedTab) { tab in
                Label(tab.rawValue, systemImage: tab.icon)
                    .tag(tab)
            }
            .navigationTitle("MPE Configuration")
            .frame(minWidth: 220)

            // Detail view
            Group {
                switch selectedTab {
                case .zones:
                    MPEZoneConfigView()
                case .mapping:
                    MPEDimensionMappingView()
                case .calibration:
                    MPECalibrationView()
                case .devices:
                    MPEDevicesView()
                case .visualization:
                    MPEVisualizationView()
                }
            }
            .frame(minWidth: 700)
        }
    }
}

// MARK: - Zone Configuration

struct MPEZoneConfigView: View {
    @State private var lowerZoneEnabled: Bool = true
    @State private var upperZoneEnabled: Bool = false
    @State private var lowerZoneChannels: Double = 8
    @State private var upperZoneChannels: Double = 0
    @State private var masterChannel: Int = 1

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("MPE Zone Configuration")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Configure MPE zones for polyphonic expression. Lower zone typically uses channels 2-9, upper zone uses channels 11-16.")
                    .foregroundColor(.secondary)

                // Zone Diagram
                MPEZoneDiagramView(
                    lowerChannels: Int(lowerZoneChannels),
                    upperChannels: Int(upperZoneChannels),
                    masterChannel: masterChannel
                )

                // Lower Zone
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Toggle("Enable Lower Zone", isOn: $lowerZoneEnabled)
                            .toggleStyle(.switch)
                            .fontWeight(.semibold)

                        if lowerZoneEnabled {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Member Channels")
                                        .font(.headline)
                                    Spacer()
                                    Text("\(Int(lowerZoneChannels)) channels")
                                        .foregroundColor(.secondary)
                                }

                                Slider(value: $lowerZoneChannels, in: 1...15, step: 1)

                                HStack {
                                    Text("Master Channel:")
                                    Spacer()
                                    Text("Channel 1")
                                        .foregroundColor(.secondary)
                                }

                                HStack {
                                    Text("Member Channels:")
                                    Spacer()
                                    Text("2 - \(Int(lowerZoneChannels) + 1)")
                                        .foregroundColor(.secondary)
                                }

                                HStack {
                                    Text("Polyphony:")
                                    Spacer()
                                    Text("\(Int(lowerZoneChannels)) voices")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding()
                } label: {
                    Label("Lower Zone", systemImage: "arrow.down.to.line")
                        .font(.headline)
                }

                // Upper Zone
                GroupBox {
                    VStack(alignment: .leading, spacing: 16) {
                        Toggle("Enable Upper Zone", isOn: $upperZoneEnabled)
                            .toggleStyle(.switch)
                            .fontWeight(.semibold)

                        if upperZoneEnabled {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack {
                                    Text("Member Channels")
                                        .font(.headline)
                                    Spacer()
                                    Text("\(Int(upperZoneChannels)) channels")
                                        .foregroundColor(.secondary)
                                }

                                Slider(value: $upperZoneChannels, in: 1...15, step: 1)

                                HStack {
                                    Text("Master Channel:")
                                    Spacer()
                                    Text("Channel 16")
                                        .foregroundColor(.secondary)
                                }

                                HStack {
                                    Text("Member Channels:")
                                    Spacer()
                                    Text("\(16 - Int(upperZoneChannels)) - 15")
                                        .foregroundColor(.secondary)
                                }

                                HStack {
                                    Text("Polyphony:")
                                    Spacer()
                                    Text("\(Int(upperZoneChannels)) voices")
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.top, 8)
                        }
                    }
                    .padding()
                } label: {
                    Label("Upper Zone", systemImage: "arrow.up.to.line")
                        .font(.headline)
                }

                // Presets
                GroupBox("Zone Presets") {
                    VStack(spacing: 12) {
                        Button("Roli Seaboard (Lower Zone, 15 channels)") {
                            lowerZoneEnabled = true
                            lowerZoneChannels = 15
                            upperZoneEnabled = false
                        }
                        .buttonStyle(.bordered)

                        Button("Linnstrument (Lower Zone, 8 channels)") {
                            lowerZoneEnabled = true
                            lowerZoneChannels = 8
                            upperZoneEnabled = false
                        }
                        .buttonStyle(.bordered)

                        Button("Haken Continuum (Lower + Upper)") {
                            lowerZoneEnabled = true
                            lowerZoneChannels = 8
                            upperZoneEnabled = true
                            upperZoneChannels = 6
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
            }
            .padding()
        }
    }
}

/// Visual diagram showing MPE zone layout
struct MPEZoneDiagramView: View {
    let lowerChannels: Int
    let upperChannels: Int
    let masterChannel: Int

    var body: some View {
        VStack(spacing: 12) {
            Text("MIDI Channels 1-16")
                .font(.headline)

            HStack(spacing: 4) {
                ForEach(1...16, id: \.self) { channel in
                    let isLowerMaster = channel == 1
                    let isLowerMember = channel >= 2 && channel <= (lowerChannels + 1)
                    let isUpperMaster = channel == 16
                    let isUpperMember = channel >= (16 - upperChannels) && channel <= 15

                    VStack(spacing: 4) {
                        Rectangle()
                            .fill(channelColor(
                                channel: channel,
                                isLowerMaster: isLowerMaster,
                                isLowerMember: isLowerMember,
                                isUpperMaster: isUpperMaster,
                                isUpperMember: isUpperMember
                            ))
                            .frame(height: 60)
                            .overlay(
                                VStack(spacing: 2) {
                                    Text("\(channel)")
                                        .font(.caption)
                                        .fontWeight(.bold)
                                    Text(channelLabel(
                                        channel: channel,
                                        isLowerMaster: isLowerMaster,
                                        isLowerMember: isLowerMember,
                                        isUpperMaster: isUpperMaster,
                                        isUpperMember: isUpperMember
                                    ))
                                    .font(.system(size: 8))
                                }
                                .foregroundColor(.white)
                            )

                        Text(channelType(
                            channel: channel,
                            isLowerMaster: isLowerMaster,
                            isLowerMember: isLowerMember,
                            isUpperMaster: isUpperMaster,
                            isUpperMember: isUpperMember
                        ))
                        .font(.system(size: 9))
                        .foregroundColor(.secondary)
                    }
                }
            }

            // Legend
            HStack(spacing: 20) {
                LegendItem(color: .blue, label: "Lower Master")
                LegendItem(color: .cyan, label: "Lower Member")
                LegendItem(color: .orange, label: "Upper Master")
                LegendItem(color: Color(red: 1.0, green: 0.6, blue: 0.2), label: "Upper Member")
                LegendItem(color: .gray, label: "Unused")
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(12)
    }

    private func channelColor(channel: Int, isLowerMaster: Bool, isLowerMember: Bool, isUpperMaster: Bool, isUpperMember: Bool) -> Color {
        if isLowerMaster { return .blue }
        if isLowerMember { return .cyan }
        if isUpperMaster { return .orange }
        if isUpperMember { return Color(red: 1.0, green: 0.6, blue: 0.2) }
        return .gray.opacity(0.3)
    }

    private func channelLabel(channel: Int, isLowerMaster: Bool, isLowerMember: Bool, isUpperMaster: Bool, isUpperMember: Bool) -> String {
        if isLowerMaster { return "Master" }
        if isLowerMember { return "Member" }
        if isUpperMaster { return "Master" }
        if isUpperMember { return "Member" }
        return ""
    }

    private func channelType(channel: Int, isLowerMaster: Bool, isLowerMember: Bool, isUpperMaster: Bool, isUpperMember: Bool) -> String {
        if isLowerMaster || isLowerMember { return "Lower" }
        if isUpperMaster || isUpperMember { return "Upper" }
        return "—"
    }
}

struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Rectangle()
                .fill(color)
                .frame(width: 16, height: 16)
                .cornerRadius(4)
            Text(label)
                .font(.caption)
        }
    }
}

// MARK: - Dimension Mapping

struct MPEDimensionMappingView: View {
    @State private var xAxisMapping: MPEDimension = .pitchBend
    @State private var yAxisMapping: MPEDimension = .timbre
    @State private var zAxisMapping: MPEDimension = .pressure

    enum MPEDimension: String, CaseIterable {
        case pitchBend = "Pitch Bend"
        case pressure = "Pressure (Aftertouch)"
        case timbre = "Timbre (CC74)"
        case brightness = "Brightness (CC71)"
        case modWheel = "Mod Wheel (CC1)"
        case volume = "Volume (CC7)"
        case expression = "Expression (CC11)"
        case custom = "Custom CC"

        var description: String {
            switch self {
            case .pitchBend: return "Per-note pitch bend (±48 semitones)"
            case .pressure: return "Per-note pressure/aftertouch"
            case .timbre: return "Timbre control (CC74)"
            case .brightness: return "Brightness/filter (CC71)"
            case .modWheel: return "Modulation wheel (CC1)"
            case .volume: return "Volume level (CC7)"
            case .expression: return "Expression (CC11)"
            case .custom: return "User-defined CC"
            }
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("Dimension Mapping")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Map controller dimensions (X, Y, Z axes) to MIDI parameters for expressive performance")
                    .foregroundColor(.secondary)

                // X Axis (Horizontal)
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Horizontal Movement (Left/Right)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Picker("X Axis", selection: $xAxisMapping) {
                            ForEach(MPEDimension.allCases, id: \.self) { dim in
                                Text(dim.rawValue).tag(dim)
                            }
                        }

                        Text(xAxisMapping.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)

                        // Range configuration
                        HStack {
                            Text("Range:")
                            Spacer()
                            Text("±48 semitones")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                } label: {
                    Label("X Axis Mapping", systemImage: "arrow.left.and.right")
                        .font(.headline)
                }

                // Y Axis (Forward/Back or Up/Down)
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Forward/Backward Movement (Depth)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Picker("Y Axis", selection: $yAxisMapping) {
                            ForEach(MPEDimension.allCases, id: \.self) { dim in
                                Text(dim.rawValue).tag(dim)
                            }
                        }

                        Text(yAxisMapping.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)

                        HStack {
                            Text("Range:")
                            Spacer()
                            Text("0 - 127")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                } label: {
                    Label("Y Axis Mapping", systemImage: "arrow.up.and.down")
                        .font(.headline)
                }

                // Z Axis (Pressure)
                GroupBox {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Vertical Pressure (Downward Force)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)

                        Picker("Z Axis", selection: $zAxisMapping) {
                            ForEach(MPEDimension.allCases, id: \.self) { dim in
                                Text(dim.rawValue).tag(dim)
                            }
                        }

                        Text(zAxisMapping.description)
                            .font(.caption)
                            .foregroundColor(.secondary)
                            .padding(.top, 4)

                        HStack {
                            Text("Range:")
                            Spacer()
                            Text("0 - 127")
                                .foregroundColor(.secondary)
                        }
                    }
                    .padding()
                } label: {
                    Label("Z Axis Mapping", systemImage: "hand.point.down")
                        .font(.headline)
                }

                // Device Presets
                GroupBox("Device Presets") {
                    VStack(spacing: 12) {
                        Button("Roli Seaboard") {
                            xAxisMapping = .pitchBend
                            yAxisMapping = .timbre
                            zAxisMapping = .pressure
                        }
                        .buttonStyle(.bordered)

                        Button("Linnstrument") {
                            xAxisMapping = .pitchBend
                            yAxisMapping = .timbre
                            zAxisMapping = .pressure
                        }
                        .buttonStyle(.bordered)

                        Button("Haken Continuum") {
                            xAxisMapping = .pitchBend
                            yAxisMapping = .brightness
                            zAxisMapping = .pressure
                        }
                        .buttonStyle(.bordered)

                        Button("Sensel Morph") {
                            xAxisMapping = .pitchBend
                            yAxisMapping = .modWheel
                            zAxisMapping = .pressure
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding()
                }
            }
            .padding()
        }
    }
}

// MARK: - Calibration

struct MPECalibrationView: View {
    @State private var pitchBendRange: Double = 48
    @State private var pressureCurve: PressureCurve = .linear
    @State private var timbreSensitivity: Double = 1.0

    enum PressureCurve: String, CaseIterable {
        case linear = "Linear"
        case logarithmic = "Logarithmic"
        case exponential = "Exponential"
        case custom = "Custom"
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                Text("MPE Calibration")
                    .font(.largeTitle)
                    .fontWeight(.bold)

                Text("Fine-tune MPE parameters for optimal performance and response")
                    .foregroundColor(.secondary)

                // Pitch Bend Range
                GroupBox("Pitch Bend Range") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Semitones")
                                .font(.headline)
                            Spacer()
                            Text("±\(Int(pitchBendRange)) semitones")
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $pitchBendRange, in: 1...96, step: 1)

                        Text("Recommended: ±48 semitones (4 octaves) for maximum expression")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }

                // Pressure Response
                GroupBox("Pressure Response Curve") {
                    VStack(alignment: .leading, spacing: 12) {
                        Picker("Curve Type", selection: $pressureCurve) {
                            ForEach(PressureCurve.allCases, id: \.self) { curve in
                                Text(curve.rawValue).tag(curve)
                            }
                        }
                        .pickerStyle(.segmented)

                        // Curve visualization
                        PressureCurveVisualization(curveType: pressureCurve)
                            .frame(height: 150)

                        Text(pressureCurveDescription(pressureCurve))
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }

                // Timbre Sensitivity
                GroupBox("Timbre Sensitivity") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Sensitivity")
                                .font(.headline)
                            Spacer()
                            Text("\(Int(timbreSensitivity * 100))%")
                                .foregroundColor(.secondary)
                        }

                        Slider(value: $timbreSensitivity, in: 0.1...2.0, step: 0.1)

                        Text("Higher sensitivity = more responsive timbre changes")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                }

                // Reset
                Button("Reset to Defaults") {
                    pitchBendRange = 48
                    pressureCurve = .linear
                    timbreSensitivity = 1.0
                }
                .buttonStyle(.bordered)
            }
            .padding()
        }
    }

    private func pressureCurveDescription(_ curve: PressureCurve) -> String {
        switch curve {
        case .linear: return "Linear response: equal pressure increases yield equal output"
        case .logarithmic: return "Logarithmic: more sensitive at light pressure, less at heavy"
        case .exponential: return "Exponential: less sensitive at light pressure, more at heavy"
        case .custom: return "Custom curve defined by control points"
        }
    }
}

struct PressureCurveVisualization: View {
    let curveType: MPECalibrationView.PressureCurve

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height

            ZStack(alignment: .bottomLeading) {
                // Background
                Rectangle()
                    .fill(Color.gray.opacity(0.1))

                // Grid
                Path { path in
                    for i in 0...4 {
                        let y = height * CGFloat(i) / 4
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                    for i in 0...4 {
                        let x = width * CGFloat(i) / 4
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: height))
                    }
                }
                .stroke(Color.gray.opacity(0.2), lineWidth: 1)

                // Curve
                Path { path in
                    path.move(to: CGPoint(x: 0, y: height))

                    for i in 0...100 {
                        let x = width * CGFloat(i) / 100
                        let normalizedInput = CGFloat(i) / 100
                        let output = calculateOutput(normalizedInput)
                        let y = height * (1 - output)
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                .stroke(Color.accentColor, lineWidth: 3)

                // Labels
                VStack {
                    HStack {
                        Spacer()
                        Text("Output")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        Text("Input Pressure →")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding(8)
            }
        }
        .background(Color.white.opacity(0.05))
        .cornerRadius(8)
    }

    private func calculateOutput(_ input: CGFloat) -> CGFloat {
        switch curveType {
        case .linear:
            return input
        case .logarithmic:
            return log(input * 9 + 1) / log(10)
        case .exponential:
            return pow(input, 2)
        case .custom:
            return input  // Placeholder
        }
    }
}

// MARK: - MPE Devices

struct MPEDevicesView: View {
    @State private var detectedDevices: [MPEDevice] = [
        MPEDevice(name: "Roli Seaboard Rise", type: "MPE Controller", connected: true),
        MPEDevice(name: "Linnstrument 128", type: "MPE Grid Controller", connected: false),
    ]

    struct MPEDevice: Identifiable {
        let id = UUID()
        let name: String
        let type: String
        var connected: Bool
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            HStack {
                Text("MPE Devices")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                Button {
                    // Scan for devices
                } label: {
                    Label("Scan", systemImage: "arrow.clockwise")
                }
            }

            List {
                ForEach($detectedDevices) { $device in
                    HStack {
                        Image(systemName: "pianokeys")
                            .font(.title2)
                            .foregroundColor(device.connected ? .green : .gray)

                        VStack(alignment: .leading) {
                            Text(device.name)
                                .font(.headline)
                            Text(device.type)
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }

                        Spacer()

                        if device.connected {
                            Text("Connected")
                                .font(.caption)
                                .foregroundColor(.green)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(Color.green.opacity(0.2))
                                .cornerRadius(4)
                        } else {
                            Button("Connect") {
                                device.connected = true
                            }
                            .buttonStyle(.borderedProminent)
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
        .padding()
    }
}

// MARK: - Live Visualization

struct MPEVisualizationView: View {
    @State private var activeNotes: [MPENote] = []

    struct MPENote: Identifiable {
        let id = UUID()
        let note: Int
        var pitch: Double
        var pressure: Double
        var timbre: Double
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Live MPE Visualization")
                .font(.largeTitle)
                .fontWeight(.bold)

            Text("Real-time visualization of MPE expression data")
                .foregroundColor(.secondary)

            // 3D visualization area
            GroupBox("Expression Surface") {
                ZStack {
                    Rectangle()
                        .fill(Color.black)

                    // Grid
                    Path { path in
                        for i in 0...10 {
                            let y = CGFloat(i) * 40
                            path.move(to: CGPoint(x: 0, y: y))
                            path.addLine(to: CGPoint(x: 600, y: y))
                        }
                        for i in 0...15 {
                            let x = CGFloat(i) * 40
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: 400))
                        }
                    }
                    .stroke(Color.green.opacity(0.2), lineWidth: 1)

                    Text("Touch the MPE controller to see expression data")
                        .foregroundColor(.white.opacity(0.3))
                }
                .frame(height: 400)
            }

            // Expression meters
            HStack(spacing: 20) {
                ExpressionMeter(label: "Pitch", value: 0.5, color: .blue)
                ExpressionMeter(label: "Pressure", value: 0.0, color: .orange)
                ExpressionMeter(label: "Timbre", value: 0.5, color: .purple)
            }
        }
        .padding()
    }
}

struct ExpressionMeter: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)

            GeometryReader { geometry in
                ZStack(alignment: .bottom) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))

                    Rectangle()
                        .fill(color)
                        .frame(height: geometry.size.height * CGFloat(value))
                }
            }
            .frame(width: 40)

            Text("\(Int(value * 127))")
                .font(.caption)
                .monospacedDigit()
        }
        .frame(height: 150)
    }
}

#if DEBUG
struct MPEConfigurationView_Previews: PreviewProvider {
    static var previews: some View {
        MPEConfigurationView()
            .frame(width: 1000, height: 700)
    }
}
#endif
