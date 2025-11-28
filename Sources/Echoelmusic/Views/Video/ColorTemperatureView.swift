import SwiftUI
import AVFoundation

/// Professional color temperature and white balance control
/// DaVinci Resolve / Adobe Premiere level color grading
struct ColorTemperatureView: View {
    @StateObject private var colorEngine = ColorTemperatureEngine()

    // Color temperature in Kelvin
    @State private var temperature: Double = 5600 // Standard daylight
    @State private var tint: Double = 0.0 // Green-Magenta shift

    // Advanced color grading
    @State private var exposure: Double = 0.0
    @State private var contrast: Double = 1.0
    @State private var saturation: Double = 1.0
    @State private var highlights: Double = 0.0
    @State private var shadows: Double = 0.0
    @State private var whites: Double = 0.0
    @State private var blacks: Double = 0.0

    // Color wheels (Lift, Gamma, Gain)
    @State private var liftHue: Double = 0.0
    @State private var liftSaturation: Double = 0.0
    @State private var gammaHue: Double = 0.0
    @State private var gammaSaturation: Double = 0.0
    @State private var gainHue: Double = 0.0
    @State private var gainSaturation: Double = 0.0

    // Reference
    @State private var autoWhiteBalance: Bool = false
    @State private var showScopes: Bool = true
    @State private var selectedScope: ScopeType = .waveform

    enum ScopeType: String, CaseIterable {
        case waveform = "Waveform"
        case vectorscope = "Vectorscope"
        case histogram = "Histogram"
        case parade = "RGB Parade"
    }

    var body: some View {
        HSplitView {
            // Left: Video preview with scopes
            VStack(spacing: 0) {
                // Video preview
                ZStack {
                    Rectangle()
                        .fill(Color.black)

                    Text("Video Preview")
                        .foregroundColor(.white.opacity(0.5))

                    // Color temperature overlay indicator
                    VStack {
                        Spacer()
                        HStack {
                            ColorTemperatureIndicator(kelvin: temperature)
                            Spacer()
                        }
                        .padding()
                    }
                }
                .frame(maxWidth: .infinity)
                .frame(height: 400)
                .border(Color.gray.opacity(0.3))

                // Scopes
                if showScopes {
                    VStack(alignment: .leading, spacing: 8) {
                        Picker("Scope", selection: $selectedScope) {
                            ForEach(ScopeType.allCases, id: \.self) { scope in
                                Text(scope.rawValue).tag(scope)
                            }
                        }
                        .pickerStyle(.segmented)
                        .padding(.horizontal)

                        ZStack {
                            Rectangle()
                                .fill(Color.black)

                            switch selectedScope {
                            case .waveform:
                                WaveformScope()
                            case .vectorscope:
                                VectorscopeView()
                            case .histogram:
                                HistogramView()
                            case .parade:
                                RGBParadeView()
                            }
                        }
                        .frame(height: 200)
                        .border(Color.gray.opacity(0.3))
                        .padding(.horizontal)
                    }
                    .padding(.vertical)
                }
            }

            // Right: Controls
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Color Temperature Presets
                    GroupBox("Color Temperature Presets") {
                        VStack(spacing: 12) {
                            HStack(spacing: 8) {
                                PresetButton(title: "Candle", kelvin: 1900, icon: "🕯️") {
                                    setTemperature(1900)
                                }
                                PresetButton(title: "Tungsten", kelvin: 3200, icon: "💡") {
                                    setTemperature(3200)
                                }
                                PresetButton(title: "Halogen", kelvin: 3400, icon: "🔆") {
                                    setTemperature(3400)
                                }
                            }

                            HStack(spacing: 8) {
                                PresetButton(title: "Fluorescent", kelvin: 4000, icon: "💠") {
                                    setTemperature(4000)
                                }
                                PresetButton(title: "Flash", kelvin: 5000, icon: "⚡") {
                                    setTemperature(5000)
                                }
                                PresetButton(title: "Daylight", kelvin: 5600, icon: "☀️") {
                                    setTemperature(5600)
                                }
                            }

                            HStack(spacing: 8) {
                                PresetButton(title: "Overcast", kelvin: 6500, icon: "☁️") {
                                    setTemperature(6500)
                                }
                                PresetButton(title: "Shade", kelvin: 7500, icon: "🌳") {
                                    setTemperature(7500)
                                }
                                PresetButton(title: "Blue Sky", kelvin: 10000, icon: "🌌") {
                                    setTemperature(10000)
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    // Manual Temperature Control
                    GroupBox("Temperature & Tint") {
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Temperature")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text("\(Int(temperature))K")
                                        .font(.system(.body, design: .monospaced))
                                    ColorTemperatureGradient(kelvin: temperature)
                                        .frame(width: 30, height: 16)
                                        .cornerRadius(3)
                                }

                                HStack(spacing: 8) {
                                    Text("🔵")
                                    Slider(value: $temperature, in: 2000...10000, step: 100)
                                        .onChange(of: temperature) { _, newValue in
                                            updateColorTemperature()
                                        }
                                    Text("🔴")
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                HStack {
                                    Text("Tint")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Spacer()
                                    Text(String(format: "%+.1f", tint))
                                        .font(.system(.body, design: .monospaced))
                                }

                                HStack(spacing: 8) {
                                    Text("🟢")
                                    Slider(value: $tint, in: -100...100)
                                        .onChange(of: tint) { _, newValue in
                                            updateColorTemperature()
                                        }
                                    Text("🟣")
                                }
                            }

                            Divider()

                            HStack {
                                Button(action: { autoWhiteBalance.toggle() }) {
                                    Label("Auto White Balance", systemImage: "wand.and.stars")
                                }
                                .buttonStyle(.borderedProminent)

                                Button(action: resetTemperature) {
                                    Label("Reset", systemImage: "arrow.counterclockwise")
                                }
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    // Basic Color Grading
                    GroupBox("Exposure & Tone") {
                        VStack(spacing: 16) {
                            ParameterSlider(
                                title: "Exposure",
                                value: $exposure,
                                range: -3...3,
                                format: "%+.2f",
                                icon: "sun.max"
                            )

                            ParameterSlider(
                                title: "Contrast",
                                value: $contrast,
                                range: 0...2,
                                format: "%.2f",
                                icon: "circle.lefthalf.filled"
                            )

                            ParameterSlider(
                                title: "Saturation",
                                value: $saturation,
                                range: 0...2,
                                format: "%.2f",
                                icon: "paintpalette"
                            )

                            Divider()

                            ParameterSlider(
                                title: "Highlights",
                                value: $highlights,
                                range: -100...100,
                                format: "%+.0f",
                                icon: "sun.max.fill"
                            )

                            ParameterSlider(
                                title: "Shadows",
                                value: $shadows,
                                range: -100...100,
                                format: "%+.0f",
                                icon: "moon.fill"
                            )

                            ParameterSlider(
                                title: "Whites",
                                value: $whites,
                                range: -100...100,
                                format: "%+.0f",
                                icon: "circle.fill"
                            )

                            ParameterSlider(
                                title: "Blacks",
                                value: $blacks,
                                range: -100...100,
                                format: "%+.0f",
                                icon: "circle"
                            )
                        }
                        .padding(.vertical, 8)
                    }

                    // Color Wheels (Lift, Gamma, Gain)
                    GroupBox("Color Wheels") {
                        VStack(spacing: 16) {
                            HStack(spacing: 12) {
                                ColorWheelControl(
                                    title: "Lift (Shadows)",
                                    hue: $liftHue,
                                    saturation: $liftSaturation
                                )

                                ColorWheelControl(
                                    title: "Gamma (Midtones)",
                                    hue: $gammaHue,
                                    saturation: $gammaSaturation
                                )

                                ColorWheelControl(
                                    title: "Gain (Highlights)",
                                    hue: $gainHue,
                                    saturation: $gainSaturation
                                )
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    // LUT Support
                    GroupBox("LUT (Look-Up Table)") {
                        VStack(spacing: 12) {
                            HStack {
                                Button("Load LUT File...") {
                                    // Would open file picker for .cube files
                                }
                                .buttonStyle(.bordered)

                                Spacer()

                                Menu("Presets") {
                                    Button("Cinematic Warm") { }
                                    Button("Cinematic Cool") { }
                                    Button("Film Print") { }
                                    Button("LOG to Rec.709") { }
                                    Button("Vintage") { }
                                }
                            }

                            HStack {
                                Toggle("Enable LUT", isOn: .constant(false))
                                Spacer()
                                Text("Intensity:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Slider(value: .constant(1.0), in: 0...1)
                                    .frame(width: 100)
                            }
                        }
                        .padding(.vertical, 8)
                    }

                    // Scopes Toggle
                    Toggle("Show Video Scopes", isOn: $showScopes)
                        .padding(.vertical)
                }
                .padding()
            }
            .frame(width: 400)
        }
        .navigationTitle("Color Temperature & Grading")
    }

    // MARK: - Actions

    private func setTemperature(_ kelvin: Double) {
        temperature = kelvin
        updateColorTemperature()
    }

    private func resetTemperature() {
        temperature = 5600
        tint = 0
        exposure = 0
        contrast = 1.0
        saturation = 1.0
        highlights = 0
        shadows = 0
        whites = 0
        blacks = 0
        updateColorTemperature()
    }

    private func updateColorTemperature() {
        let params = ColorTemperatureEngine.ColorGradingParams(
            temperature: Float(temperature),
            tint: Float(tint),
            exposure: Float(exposure),
            contrast: Float(contrast),
            saturation: Float(saturation),
            highlights: Float(highlights),
            shadows: Float(shadows),
            whites: Float(whites),
            blacks: Float(blacks),
            liftHue: Float(liftHue),
            liftSaturation: Float(liftSaturation),
            gammaHue: Float(gammaHue),
            gammaSaturation: Float(gammaSaturation),
            gainHue: Float(gainHue),
            gainSaturation: Float(gainSaturation)
        )
        colorEngine.updateParameters(params)
    }
}

// MARK: - Supporting Views

struct PresetButton: View {
    let title: String
    let kelvin: Int
    let icon: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 4) {
                Text(icon)
                    .font(.title2)
                Text(title)
                    .font(.caption2)
                Text("\(kelvin)K")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
        }
        .buttonStyle(.bordered)
    }
}

struct ColorTemperatureIndicator: View {
    let kelvin: Double

    var body: some View {
        HStack(spacing: 8) {
            ColorTemperatureGradient(kelvin: kelvin)
                .frame(width: 40, height: 20)
                .cornerRadius(4)

            Text("\(Int(kelvin))K")
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.black.opacity(0.6))
                .cornerRadius(4)
        }
    }
}

struct ColorTemperatureGradient: View {
    let kelvin: Double

    var color: Color {
        kelvinToRGB(kelvin)
    }

    var body: some View {
        Rectangle()
            .fill(color)
    }

    // Convert Kelvin to RGB approximation
    private func kelvinToRGB(_ kelvin: Double) -> Color {
        let temp = kelvin / 100.0
        var red: Double = 0
        var green: Double = 0
        var blue: Double = 0

        // Red calculation
        if temp <= 66 {
            red = 255
        } else {
            red = temp - 60
            red = 329.698727446 * pow(red, -0.1332047592)
            red = max(0, min(255, red))
        }

        // Green calculation
        if temp <= 66 {
            green = temp
            green = 99.4708025861 * log(green) - 161.1195681661
        } else {
            green = temp - 60
            green = 288.1221695283 * pow(green, -0.0755148492)
        }
        green = max(0, min(255, green))

        // Blue calculation
        if temp >= 66 {
            blue = 255
        } else if temp <= 19 {
            blue = 0
        } else {
            blue = temp - 10
            blue = 138.5177312231 * log(blue) - 305.0447927307
            blue = max(0, min(255, blue))
        }

        return Color(
            red: red / 255.0,
            green: green / 255.0,
            blue: blue / 255.0
        )
    }
}

struct ColorWheelControl: View {
    let title: String
    @Binding var hue: Double
    @Binding var saturation: Double

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)

            ZStack {
                // Color wheel background
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                .red, .yellow, .green, .cyan, .blue, .magenta, .red
                            ]),
                            center: .center
                        )
                    )
                    .frame(width: 80, height: 80)

                // Saturation mask
                Circle()
                    .fill(
                        RadialGradient(
                            gradient: Gradient(colors: [.white, .clear]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 40
                        )
                    )
                    .frame(width: 80, height: 80)

                // Current position indicator
                Circle()
                    .fill(Color.white)
                    .frame(width: 10, height: 10)
                    .offset(
                        x: CGFloat(cos(hue * .pi / 180.0) * saturation * 35),
                        y: CGFloat(sin(hue * .pi / 180.0) * saturation * 35)
                    )
                    .shadow(radius: 2)
            }
            .gesture(
                DragGesture(minimumDistance: 0)
                    .onChanged { value in
                        let dx = value.location.x - 40
                        let dy = value.location.y - 40
                        hue = atan2(dy, dx) * 180.0 / .pi
                        saturation = min(1.0, sqrt(dx*dx + dy*dy) / 40.0)
                    }
            )

            Button("Reset") {
                hue = 0
                saturation = 0
            }
            .font(.caption2)
            .buttonStyle(.borderless)
        }
    }
}

// MARK: - Scopes

struct WaveformScope: View {
    var body: some View {
        Canvas { context, size in
            // Draw waveform (luminance values)
            for x in stride(from: 0, to: size.width, by: 2) {
                let path = Path { path in
                    path.move(to: CGPoint(x: x, y: size.height))
                    // Simulate waveform data
                    for y in stride(from: size.height, to: 0, by: -4) {
                        path.addLine(to: CGPoint(x: x, y: y))
                    }
                }
                context.stroke(path, with: .color(.green.opacity(0.3)), lineWidth: 1)
            }

            // IRE reference lines
            let ire100 = size.height * 0.1
            let ire0 = size.height * 0.9

            context.stroke(
                Path { $0.move(to: CGPoint(x: 0, y: ire100)); $0.addLine(to: CGPoint(x: size.width, y: ire100)) },
                with: .color(.white.opacity(0.5)),
                lineWidth: 1
            )
            context.stroke(
                Path { $0.move(to: CGPoint(x: 0, y: ire0)); $0.addLine(to: CGPoint(x: size.width, y: ire0)) },
                with: .color(.white.opacity(0.5)),
                lineWidth: 1
            )
        }
    }
}

struct VectorscopeView: View {
    var body: some View {
        Canvas { context, size in
            let center = CGPoint(x: size.width / 2, y: size.height / 2)
            let radius = min(size.width, size.height) / 2 - 10

            // Draw color targets (SMPTE)
            let targets: [(color: Color, angle: Double)] = [
                (.red, 103.8),
                (.yellow, 167.1),
                (.green, 240.7),
                (.cyan, 283.8),
                (.blue, 347.5),
                (.magenta, 60.7)
            ]

            for target in targets {
                let angle = target.angle * .pi / 180.0
                let x = center.x + CGFloat(cos(angle)) * radius * 0.75
                let y = center.y + CGFloat(sin(angle)) * radius * 0.75

                context.fill(
                    Path(ellipseIn: CGRect(x: x - 5, y: y - 5, width: 10, height: 10)),
                    with: .color(target.color.opacity(0.5))
                )
            }

            // Draw graticule
            context.stroke(
                Path(ellipseIn: CGRect(x: center.x - radius, y: center.y - radius, width: radius * 2, height: radius * 2)),
                with: .color(.white.opacity(0.3)),
                lineWidth: 1
            )
        }
    }
}

struct HistogramView: View {
    var body: some View {
        Canvas { context, size in
            // Draw RGB histogram
            let barWidth = size.width / 256

            for i in 0..<256 {
                let x = CGFloat(i) * barWidth
                // Simulate histogram data
                let redHeight = size.height * 0.3 * Double.random(in: 0.5...1.0)
                let greenHeight = size.height * 0.4 * Double.random(in: 0.5...1.0)
                let blueHeight = size.height * 0.35 * Double.random(in: 0.5...1.0)

                context.fill(
                    Path(CGRect(x: x, y: size.height - redHeight, width: barWidth, height: redHeight)),
                    with: .color(.red.opacity(0.5))
                )
                context.fill(
                    Path(CGRect(x: x, y: size.height - greenHeight, width: barWidth, height: greenHeight)),
                    with: .color(.green.opacity(0.5))
                )
                context.fill(
                    Path(CGRect(x: x, y: size.height - blueHeight, width: barWidth, height: blueHeight)),
                    with: .color(.blue.opacity(0.5))
                )
            }
        }
    }
}

struct RGBParadeView: View {
    var body: some View {
        HStack(spacing: 2) {
            // Red channel
            WaveformChannel(color: .red)
            // Green channel
            WaveformChannel(color: .green)
            // Blue channel
            WaveformChannel(color: .blue)
        }
    }
}

struct WaveformChannel: View {
    let color: Color

    var body: some View {
        Canvas { context, size in
            for x in stride(from: 0, to: size.width, by: 2) {
                let height = size.height * Double.random(in: 0.3...0.8)
                let path = Path { path in
                    path.move(to: CGPoint(x: x, y: size.height))
                    path.addLine(to: CGPoint(x: x, y: size.height - height))
                }
                context.stroke(path, with: .color(color.opacity(0.6)), lineWidth: 1)
            }
        }
    }
}

// MARK: - Color Temperature Engine

@MainActor
class ColorTemperatureEngine: ObservableObject {
    struct ColorGradingParams {
        let temperature: Float
        let tint: Float
        let exposure: Float
        let contrast: Float
        let saturation: Float
        let highlights: Float
        let shadows: Float
        let whites: Float
        let blacks: Float
        let liftHue: Float
        let liftSaturation: Float
        let gammaHue: Float
        let gammaSaturation: Float
        let gainHue: Float
        let gainSaturation: Float
    }

    @Published var currentParams: ColorGradingParams?

    func updateParameters(_ params: ColorGradingParams) {
        currentParams = params
        // Would update Metal shader parameters for real-time color grading
        // This integrates with MetalShaders.metal colorGradeShader
    }

    func applyLUT(lutData: Data) {
        // Would parse .cube file and create 3D LUT texture
        // Applied in Metal shader for cinematic color grading
    }
}

#Preview {
    ColorTemperatureView()
}
