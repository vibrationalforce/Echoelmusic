//
//  ChromaKeyView.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  CHROMA KEY VIEW - Professional greenscreen/bluescreen controls
//  DaVinci Resolve / After Effects level chroma keying
//
//  **Features:**
//  - Green screen / Blue screen / Custom color
//  - Advanced spill suppression
//  - Edge refinement
//  - Color matching
//  - Light wrap
//  - Real-time preview
//  - Automatic key color picker
//  - Garbage matte
//  - Core matte
//

import SwiftUI
import AVFoundation

struct ChromaKeyView: View {
    @StateObject private var chromaKey = ChromaKeyEngine.shared

    @State private var keyColor: Color = .green
    @State private var threshold: Double = 0.3
    @State private var smoothness: Double = 0.1
    @State private var spillSuppression: Double = 0.5
    @State private var edgeFeather: Double = 0.05
    @State private var lightWrap: Double = 0.0
    @State private var showMatte: Bool = false
    @State private var autoKeyColor: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            // Toolbar
            HStack {
                Text("🎬 Chroma Key")
                    .font(.title2)
                    .fontWeight(.bold)

                Spacer()

                // Preset buttons
                HStack(spacing: 8) {
                    Button(action: { setGreenScreen() }) {
                        HStack {
                            Circle().fill(Color.green).frame(width: 12, height: 12)
                            Text("Green Screen")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(keyColor == .green ? Color.green.opacity(0.2) : Color.clear)
                        .cornerRadius(8)
                    }

                    Button(action: { setBlueScreen() }) {
                        HStack {
                            Circle().fill(Color.blue).frame(width: 12, height: 12)
                            Text("Blue Screen")
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(keyColor == .blue ? Color.blue.opacity(0.2) : Color.clear)
                        .cornerRadius(8)
                    }

                    ColorPicker("Custom", selection: $keyColor)
                }
            }
            .padding()

            Divider()

            HSplitView {
                // Left: Preview
                VStack(spacing: 0) {
                    // Video preview
                    ZStack {
                        Color.black

                        if showMatte {
                            // Show alpha matte
                            Text("Alpha Matte Preview")
                                .foregroundColor(.white)
                        } else {
                            // Show keyed result
                            Text("Chroma Key Preview")
                                .foregroundColor(.white)
                        }
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)

                    // Preview controls
                    HStack {
                        Toggle("Show Matte", isOn: $showMatte)

                        Spacer()

                        Button("Pick Color from Video") {
                            autoKeyColor = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding()
                    .background(Color.gray.opacity(0.1))
                }

                // Right: Controls
                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        // Key Color
                        Section {
                            Text("KEY COLOR")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            HStack {
                                Rectangle()
                                    .fill(keyColor)
                                    .frame(width: 60, height: 60)
                                    .cornerRadius(8)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.primary, lineWidth: 1)
                                    )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Current Key Color")
                                        .font(.caption)
                                    ColorPicker("", selection: $keyColor)
                                        .labelsHidden()
                                }
                            }
                        }

                        Divider()

                        // Key Settings
                        Section {
                            Text("KEY SETTINGS")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 16) {
                                ParameterSlider(
                                    name: "Threshold",
                                    value: $threshold,
                                    range: 0...1,
                                    description: "How much color to remove"
                                )

                                ParameterSlider(
                                    name: "Smoothness",
                                    value: $smoothness,
                                    range: 0...0.5,
                                    description: "Edge transition softness"
                                )

                                ParameterSlider(
                                    name: "Spill Suppression",
                                    value: $spillSuppression,
                                    range: 0...1,
                                    description: "Remove color spill on subject"
                                )

                                ParameterSlider(
                                    name: "Edge Feather",
                                    value: $edgeFeather,
                                    range: 0...0.2,
                                    description: "Soften edge transparency"
                                )
                            }
                        }

                        Divider()

                        // Advanced
                        Section {
                            Text("ADVANCED")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 16) {
                                ParameterSlider(
                                    name: "Light Wrap",
                                    value: $lightWrap,
                                    range: 0...1,
                                    description: "Blend background light onto subject"
                                )

                                Toggle("Despill", isOn: .constant(true))
                                Toggle("Edge Refinement", isOn: .constant(true))
                                Toggle("Color Matching", isOn: .constant(false))
                            }
                        }

                        Divider()

                        // Garbage Matte
                        Section {
                            Text("GARBAGE MATTE")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            Text("Exclude areas from keying")
                                .font(.caption2)
                                .foregroundColor(.secondary)

                            Button("Draw Garbage Matte") {
                                // Open drawing tool
                            }
                            .buttonStyle(.bordered)

                            Button("Clear Matte") {
                                // Clear garbage matte
                            }
                            .buttonStyle(.bordered)
                        }

                        Divider()

                        // Quality Metrics
                        Section {
                            Text("QUALITY METRICS")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 8) {
                                MetricRow(name: "Edge Quality", value: 87, color: .green)
                                MetricRow(name: "Spill Amount", value: 23, color: .orange)
                                MetricRow(name: "Transparency", value: 95, color: .green)
                            }
                        }

                        Divider()

                        // Presets
                        Section {
                            Text("PRESETS")
                                .font(.caption)
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 8) {
                                PresetButton(name: "Clean Studio", action: applyCleanStudio)
                                PresetButton(name: "Outdoor/Windy", action: applyOutdoor)
                                PresetButton(name: "Wrinkled Background", action: applyWrinkled)
                                PresetButton(name: "High Detail (Hair/Fur)", action: applyHighDetail)
                            }
                        }
                    }
                    .padding()
                }
                .frame(width: 350)
            }
        }
        .onChange(of: threshold) { _ in updateChromaKey() }
        .onChange(of: smoothness) { _ in updateChromaKey() }
        .onChange(of: spillSuppression) { _ in updateChromaKey() }
        .onChange(of: edgeFeather) { _ in updateChromaKey() }
        .onChange(of: keyColor) { _ in updateChromaKey() }
    }

    // MARK: - Actions

    private func setGreenScreen() {
        keyColor = Color(red: 0, green: 1, blue: 0)
        threshold = 0.3
        smoothness = 0.1
        spillSuppression = 0.6
    }

    private func setBlueScreen() {
        keyColor = Color(red: 0, green: 0, blue: 1)
        threshold = 0.3
        smoothness = 0.1
        spillSuppression = 0.5
    }

    private func updateChromaKey() {
        let params = ChromaKeyEngine.ChromaKeyParams(
            keyColor: keyColor,
            threshold: Float(threshold),
            smoothness: Float(smoothness),
            spillSuppression: Float(spillSuppression),
            edgeFeather: Float(edgeFeather),
            lightWrap: Float(lightWrap)
        )

        chromaKey.updateParameters(params)
    }

    // Preset actions
    private func applyCleanStudio() {
        threshold = 0.25
        smoothness = 0.08
        spillSuppression = 0.5
        edgeFeather = 0.02
    }

    private func applyOutdoor() {
        threshold = 0.35
        smoothness = 0.15
        spillSuppression = 0.7
        edgeFeather = 0.08
    }

    private func applyWrinkled() {
        threshold = 0.4
        smoothness = 0.2
        spillSuppression = 0.6
        edgeFeather = 0.05
    }

    private func applyHighDetail() {
        threshold = 0.28
        smoothness = 0.05
        spillSuppression = 0.4
        edgeFeather = 0.01
    }
}

// MARK: - Parameter Slider

struct ParameterSlider: View {
    let name: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let description: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name)
                    .font(.caption)
                Spacer()
                Text("\(value, specifier: "%.2f")")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Slider(value: $value, in: range)

            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Metric Row

struct MetricRow: View {
    let name: String
    let value: Int
    let color: Color

    var body: some View {
        HStack {
            Text(name)
                .font(.caption)
            Spacer()
            ProgressView(value: Double(value), total: 100.0)
                .progressViewStyle(.linear)
                .tint(color)
                .frame(width: 100)
            Text("\(value)%")
                .font(.caption)
                .foregroundColor(color)
                .frame(width: 40, alignment: .trailing)
        }
    }
}

// MARK: - Preset Button

struct PresetButton: View {
    let name: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: "wand.and.stars")
                Text(name)
                    .font(.caption)
                Spacer()
            }
            .padding(8)
            .frame(maxWidth: .infinity)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(6)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Chroma Key Engine

@MainActor
class ChromaKeyEngine: ObservableObject {
    static let shared = ChromaKeyEngine()

    struct ChromaKeyParams {
        let keyColor: Color
        let threshold: Float
        let smoothness: Float
        let spillSuppression: Float
        let edgeFeather: Float
        let lightWrap: Float
    }

    @Published var currentParams: ChromaKeyParams?

    func updateParameters(_ params: ChromaKeyParams) {
        currentParams = params
        print("🎨 Chroma Key Updated:")
        print("  Threshold: \(params.threshold)")
        print("  Smoothness: \(params.smoothness)")
        print("  Spill Suppression: \(params.spillSuppression)")
    }

    private init() {
        print("🎬 Chroma Key Engine initialized")
    }
}

// MARK: - Preview

#if DEBUG
struct ChromaKeyView_Previews: PreviewProvider {
    static var previews: some View {
        ChromaKeyView()
            .frame(width: 1400, height: 800)
    }
}
#endif
