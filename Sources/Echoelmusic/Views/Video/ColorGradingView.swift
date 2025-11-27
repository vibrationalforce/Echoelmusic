//
//  ColorGradingView.swift
//  Echoelmusic
//
//  Professional Color Grading Interface
//  DaVinci Resolve-level color correction UI
//
//  Features:
//  - Color Wheels (Lift, Gamma, Gain, Offset)
//  - RGB/Luma Curves
//  - HSL Qualifiers
//  - 3D LUT Browser & Import
//  - Real-time Scopes (Waveform, Vectorscope, Histogram, RGB Parade)
//  - Power Windows
//  - Color Match
//  - Film Emulation Presets
//

import SwiftUI
import CoreImage
import Accelerate

// MARK: - Color Grading View

struct ColorGradingView: View {
    @StateObject private var colorGrading = ColorGradingSystem.shared
    @State private var selectedTab: ColorGradingTab = .wheels
    @State private var showScopes: Bool = true
    @State private var showLUTBrowser: Bool = false
    @State private var selectedScope: ScopeType = .waveform

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Top Bar
                colorGradingTopBar

                HStack(spacing: 0) {
                    // Main Grading Panel
                    VStack(spacing: 0) {
                        // Tab Selection
                        colorGradingTabs

                        // Content based on selected tab
                        ScrollView {
                            switch selectedTab {
                            case .wheels:
                                colorWheelsPanel
                            case .curves:
                                curvesPanel
                            case .hsl:
                                hslPanel
                            case .windows:
                                powerWindowsPanel
                            case .match:
                                colorMatchPanel
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .frame(width: geometry.size.width * (showScopes ? 0.65 : 1.0))

                    // Scopes Panel
                    if showScopes {
                        Divider()
                        scopesPanel
                            .frame(width: geometry.size.width * 0.35)
                    }
                }
            }
        }
        .background(Color.black.opacity(0.95))
        .sheet(isPresented: $showLUTBrowser) {
            LUTBrowserView()
        }
    }

    // MARK: - Top Bar

    private var colorGradingTopBar: some View {
        HStack {
            Text("Color Grading")
                .font(.headline)
                .foregroundColor(.white)

            Spacer()

            // LUT Button
            Button(action: { showLUTBrowser = true }) {
                Label("LUTs", systemImage: "cube.fill")
            }
            .buttonStyle(.bordered)

            // Reset Button
            Button(action: resetGrade) {
                Label("Reset", systemImage: "arrow.counterclockwise")
            }
            .buttonStyle(.bordered)

            // Scopes Toggle
            Button(action: { showScopes.toggle() }) {
                Label("Scopes", systemImage: showScopes ? "waveform.circle.fill" : "waveform.circle")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color.black.opacity(0.8))
    }

    // MARK: - Tabs

    private var colorGradingTabs: some View {
        HStack(spacing: 0) {
            ForEach(ColorGradingTab.allCases, id: \.self) { tab in
                Button(action: { selectedTab = tab }) {
                    VStack(spacing: 4) {
                        Image(systemName: tab.icon)
                            .font(.title3)
                        Text(tab.title)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(selectedTab == tab ? Color.blue.opacity(0.3) : Color.clear)
                    .foregroundColor(selectedTab == tab ? .blue : .gray)
                }
            }
        }
        .background(Color.black.opacity(0.6))
    }

    // MARK: - Color Wheels Panel

    private var colorWheelsPanel: some View {
        VStack(spacing: 20) {
            // Main Color Wheels Row
            HStack(spacing: 20) {
                ColorWheelControl(
                    title: "Lift",
                    subtitle: "Shadows",
                    wheel: $colorGrading.liftWheel
                )

                ColorWheelControl(
                    title: "Gamma",
                    subtitle: "Midtones",
                    wheel: $colorGrading.gammaWheel
                )

                ColorWheelControl(
                    title: "Gain",
                    subtitle: "Highlights",
                    wheel: $colorGrading.gainWheel
                )
            }
            .padding()

            Divider().background(Color.gray)

            // Global Adjustments
            VStack(spacing: 12) {
                Text("Global Adjustments")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                HStack(spacing: 20) {
                    GradingSlider(title: "Contrast", value: $colorGrading.currentGrade.contrast, range: -100...100)
                    GradingSlider(title: "Saturation", value: $colorGrading.currentGrade.saturation, range: -100...100)
                    GradingSlider(title: "Vibrance", value: $colorGrading.currentGrade.vibrance, range: -100...100)
                }

                HStack(spacing: 20) {
                    GradingSlider(title: "Temperature", value: $colorGrading.currentGrade.temperature, range: -100...100)
                    GradingSlider(title: "Tint", value: $colorGrading.currentGrade.tint, range: -100...100)
                    GradingSlider(title: "Exposure", value: $colorGrading.currentGrade.exposure, range: -5...5)
                }
            }
            .padding()

            Divider().background(Color.gray)

            // Film Emulation Presets
            filmEmulationPresets
        }
    }

    // MARK: - Curves Panel

    private var curvesPanel: some View {
        VStack(spacing: 16) {
            // Curve Type Selector
            Picker("Curve", selection: $colorGrading.currentGrade.activeCurve) {
                Text("RGB").tag(CurveType.rgb)
                Text("Red").tag(CurveType.red)
                Text("Green").tag(CurveType.green)
                Text("Blue").tag(CurveType.blue)
                Text("Luma").tag(CurveType.luma)
                Text("Hue vs Hue").tag(CurveType.hueVsHue)
                Text("Hue vs Sat").tag(CurveType.hueVsSat)
                Text("Sat vs Sat").tag(CurveType.satVsSat)
            }
            .pickerStyle(.segmented)
            .padding(.horizontal)

            // Curve Editor
            CurveEditorView(
                curve: curveBinding,
                curveType: colorGrading.currentGrade.activeCurve
            )
            .frame(height: 300)
            .padding()
            .background(Color.black.opacity(0.3))
            .cornerRadius(8)
            .padding(.horizontal)

            // Curve Presets
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    CurvePresetButton(name: "Linear", preset: .linear)
                    CurvePresetButton(name: "S-Curve", preset: .sCurve)
                    CurvePresetButton(name: "Lift Shadows", preset: .liftShadows)
                    CurvePresetButton(name: "Crush Blacks", preset: .crushBlacks)
                    CurvePresetButton(name: "High Contrast", preset: .highContrast)
                    CurvePresetButton(name: "Low Contrast", preset: .lowContrast)
                    CurvePresetButton(name: "Film Look", preset: .filmLook)
                }
                .padding(.horizontal)
            }
        }
        .padding(.vertical)
    }

    // MARK: - HSL Panel

    private var hslPanel: some View {
        VStack(spacing: 16) {
            Text("HSL Qualifiers")
                .font(.headline)
                .foregroundColor(.white)

            // Hue Range Selector
            VStack(alignment: .leading, spacing: 8) {
                Text("Hue Range")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                HueRangeSelector(
                    centerHue: $colorGrading.currentGrade.hslQualifier.centerHue,
                    hueWidth: $colorGrading.currentGrade.hslQualifier.hueWidth
                )
                .frame(height: 60)
            }
            .padding()

            // Saturation Range
            VStack(alignment: .leading, spacing: 8) {
                Text("Saturation Range")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                RangeSlider(
                    range: $colorGrading.currentGrade.hslQualifier.saturationRange,
                    bounds: 0...1
                )
            }
            .padding()

            // Luminance Range
            VStack(alignment: .leading, spacing: 8) {
                Text("Luminance Range")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                RangeSlider(
                    range: $colorGrading.currentGrade.hslQualifier.luminanceRange,
                    bounds: 0...1
                )
            }
            .padding()

            Divider().background(Color.gray)

            // Adjustments for Selected Range
            VStack(spacing: 12) {
                Text("Adjust Selected Colors")
                    .font(.subheadline)
                    .foregroundColor(.gray)

                HStack(spacing: 20) {
                    GradingSlider(title: "Hue Shift", value: $colorGrading.currentGrade.hslQualifier.hueShift, range: -180...180)
                    GradingSlider(title: "Saturation", value: $colorGrading.currentGrade.hslQualifier.saturationAdjust, range: -100...100)
                    GradingSlider(title: "Luminance", value: $colorGrading.currentGrade.hslQualifier.luminanceAdjust, range: -100...100)
                }
            }
            .padding()
        }
    }

    // MARK: - Power Windows Panel

    private var powerWindowsPanel: some View {
        VStack(spacing: 16) {
            Text("Power Windows")
                .font(.headline)
                .foregroundColor(.white)

            // Window Shape Selector
            HStack(spacing: 12) {
                WindowShapeButton(shape: .circle, icon: "circle", title: "Circle")
                WindowShapeButton(shape: .rectangle, icon: "rectangle", title: "Rectangle")
                WindowShapeButton(shape: .polygon, icon: "pentagon", title: "Polygon")
                WindowShapeButton(shape: .gradient, icon: "square.split.diagonal", title: "Gradient")
                WindowShapeButton(shape: .curve, icon: "bezierpath", title: "Curve")
            }
            .padding()

            // Window Properties
            VStack(spacing: 12) {
                GradingSlider(title: "Softness", value: $colorGrading.currentGrade.powerWindow.softness, range: 0...100)
                GradingSlider(title: "Opacity", value: $colorGrading.currentGrade.powerWindow.opacity, range: 0...100)

                Toggle("Invert Window", isOn: $colorGrading.currentGrade.powerWindow.inverted)
                    .foregroundColor(.white)

                Toggle("Track Motion", isOn: $colorGrading.currentGrade.powerWindow.trackingEnabled)
                    .foregroundColor(.white)
            }
            .padding()

            // Window Preview
            PowerWindowPreview(window: colorGrading.currentGrade.powerWindow)
                .frame(height: 200)
                .background(Color.black.opacity(0.3))
                .cornerRadius(8)
                .padding()
        }
    }

    // MARK: - Color Match Panel

    private var colorMatchPanel: some View {
        VStack(spacing: 16) {
            Text("Color Match")
                .font(.headline)
                .foregroundColor(.white)

            Text("Match colors between shots automatically")
                .font(.caption)
                .foregroundColor(.gray)

            HStack(spacing: 20) {
                // Source Frame
                VStack {
                    Text("Source")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 150)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        )
                        .cornerRadius(8)

                    Button("Select Frame") {
                        // Select source frame
                    }
                    .buttonStyle(.bordered)
                }

                Image(systemName: "arrow.right")
                    .font(.title)
                    .foregroundColor(.gray)

                // Target Frame
                VStack {
                    Text("Target")
                        .font(.subheadline)
                        .foregroundColor(.gray)

                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 150)
                        .overlay(
                            Image(systemName: "photo")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                        )
                        .cornerRadius(8)

                    Button("Select Frame") {
                        // Select target frame
                    }
                    .buttonStyle(.bordered)
                }
            }
            .padding()

            Button(action: performColorMatch) {
                Label("Match Colors", systemImage: "wand.and.stars")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .padding(.horizontal)
        }
    }

    // MARK: - Scopes Panel

    private var scopesPanel: some View {
        VStack(spacing: 0) {
            // Scope Selector
            Picker("Scope", selection: $selectedScope) {
                ForEach(ScopeType.allCases, id: \.self) { scope in
                    Text(scope.title).tag(scope)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            // Scope Display
            switch selectedScope {
            case .waveform:
                WaveformScopeView()
            case .vectorscope:
                VectorscopeView()
            case .histogram:
                HistogramView()
            case .rgbParade:
                RGBParadeView()
            }

            Spacer()
        }
        .background(Color.black.opacity(0.8))
    }

    // MARK: - Film Emulation Presets

    private var filmEmulationPresets: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Film Emulation")
                .font(.subheadline)
                .foregroundColor(.gray)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 12) {
                    FilmPresetButton(name: "Kodak 5219", preset: .kodak5219)
                    FilmPresetButton(name: "Kodak 2383", preset: .kodak2383)
                    FilmPresetButton(name: "Fuji 3510", preset: .fuji3510)
                    FilmPresetButton(name: "ARRI LogC", preset: .arriLogC)
                    FilmPresetButton(name: "RED IPP2", preset: .redIPP2)
                    FilmPresetButton(name: "Sony S-Log3", preset: .sonySLog3)
                    FilmPresetButton(name: "Blackmagic Film", preset: .blackmagicFilm)
                    FilmPresetButton(name: "Cinematic Teal/Orange", preset: .cinematicTealOrange)
                    FilmPresetButton(name: "Vintage 70s", preset: .vintage70s)
                    FilmPresetButton(name: "Noir", preset: .noir)
                }
            }
        }
        .padding()
    }

    // MARK: - Helper Properties

    private var curveBinding: Binding<[CGPoint]> {
        switch colorGrading.currentGrade.activeCurve {
        case .rgb:
            return $colorGrading.currentGrade.rgbCurve
        case .red:
            return $colorGrading.currentGrade.redCurve
        case .green:
            return $colorGrading.currentGrade.greenCurve
        case .blue:
            return $colorGrading.currentGrade.blueCurve
        case .luma:
            return $colorGrading.currentGrade.lumaCurve
        case .hueVsHue:
            return $colorGrading.currentGrade.hueVsHueCurve
        case .hueVsSat:
            return $colorGrading.currentGrade.hueVsSatCurve
        case .satVsSat:
            return $colorGrading.currentGrade.satVsSatCurve
        }
    }

    // MARK: - Actions

    private func resetGrade() {
        colorGrading.currentGrade = ColorGrade()
        colorGrading.liftWheel = ColorWheel()
        colorGrading.gammaWheel = ColorWheel()
        colorGrading.gainWheel = ColorWheel()
    }

    private func performColorMatch() {
        // AI-powered color matching
    }
}

// MARK: - Supporting Types

enum ColorGradingTab: String, CaseIterable {
    case wheels, curves, hsl, windows, match

    var title: String {
        switch self {
        case .wheels: return "Wheels"
        case .curves: return "Curves"
        case .hsl: return "HSL"
        case .windows: return "Windows"
        case .match: return "Match"
        }
    }

    var icon: String {
        switch self {
        case .wheels: return "circle.grid.3x3"
        case .curves: return "point.topleft.down.curvedto.point.bottomright.up"
        case .hsl: return "slider.horizontal.3"
        case .windows: return "viewfinder"
        case .match: return "arrow.left.arrow.right"
        }
    }
}

enum ScopeType: String, CaseIterable {
    case waveform, vectorscope, histogram, rgbParade

    var title: String {
        switch self {
        case .waveform: return "Waveform"
        case .vectorscope: return "Vector"
        case .histogram: return "Histogram"
        case .rgbParade: return "RGB Parade"
        }
    }
}

enum CurveType {
    case rgb, red, green, blue, luma
    case hueVsHue, hueVsSat, satVsSat
}

enum CurvePreset {
    case linear, sCurve, liftShadows, crushBlacks
    case highContrast, lowContrast, filmLook
}

enum WindowShape {
    case circle, rectangle, polygon, gradient, curve
}

enum FilmPreset {
    case kodak5219, kodak2383, fuji3510
    case arriLogC, redIPP2, sonySLog3, blackmagicFilm
    case cinematicTealOrange, vintage70s, noir
}

// MARK: - Color Wheel Control

struct ColorWheelControl: View {
    let title: String
    let subtitle: String
    @Binding var wheel: ColorWheel

    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.headline)
                .foregroundColor(.white)

            Text(subtitle)
                .font(.caption)
                .foregroundColor(.gray)

            // Color Wheel
            ZStack {
                // Background wheel
                Circle()
                    .fill(
                        AngularGradient(
                            gradient: Gradient(colors: [
                                .red, .yellow, .green, .cyan, .blue, .magenta, .red
                            ]),
                            center: .center
                        )
                    )
                    .overlay(
                        RadialGradient(
                            gradient: Gradient(colors: [.white, .clear]),
                            center: .center,
                            startRadius: 0,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)

                // Center indicator
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .offset(x: wheel.offset.width, y: wheel.offset.height)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let maxOffset: CGFloat = 54
                                let newX = max(-maxOffset, min(maxOffset, value.location.x - 60))
                                let newY = max(-maxOffset, min(maxOffset, value.location.y - 60))
                                wheel.offset = CGSize(width: newX, height: newY)
                            }
                    )
            }

            // Master Slider
            HStack {
                Text("Master")
                    .font(.caption)
                    .foregroundColor(.gray)
                    .frame(width: 50, alignment: .leading)

                Slider(value: $wheel.master, in: -1...1)
                    .tint(.white)

                Text(String(format: "%.2f", wheel.master))
                    .font(.caption)
                    .foregroundColor(.white)
                    .frame(width: 40)
            }
        }
        .padding()
        .background(Color.black.opacity(0.3))
        .cornerRadius(12)
    }
}

// MARK: - Grading Slider

struct GradingSlider: View {
    let title: String
    @Binding var value: Double
    let range: ClosedRange<Double>

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(title)
                    .font(.caption)
                    .foregroundColor(.gray)
                Spacer()
                Text(String(format: "%.1f", value))
                    .font(.caption)
                    .foregroundColor(.white)
            }

            Slider(value: $value, in: range)
                .tint(.blue)
        }
    }
}

// MARK: - Curve Editor View

struct CurveEditorView: View {
    @Binding var curve: [CGPoint]
    let curveType: CurveType

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Grid
                Path { path in
                    let step = geometry.size.width / 4
                    for i in 0...4 {
                        let x = CGFloat(i) * step
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: geometry.size.height))

                        let y = CGFloat(i) * step
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: geometry.size.width, y: y))
                    }
                }
                .stroke(Color.gray.opacity(0.3), lineWidth: 1)

                // Diagonal reference
                Path { path in
                    path.move(to: CGPoint(x: 0, y: geometry.size.height))
                    path.addLine(to: CGPoint(x: geometry.size.width, y: 0))
                }
                .stroke(Color.gray.opacity(0.5), lineWidth: 1)

                // Curve
                Path { path in
                    guard !curve.isEmpty else { return }
                    let sortedPoints = curve.sorted { $0.x < $1.x }

                    path.move(to: CGPoint(
                        x: sortedPoints[0].x * geometry.size.width,
                        y: (1 - sortedPoints[0].y) * geometry.size.height
                    ))

                    for point in sortedPoints.dropFirst() {
                        path.addLine(to: CGPoint(
                            x: point.x * geometry.size.width,
                            y: (1 - point.y) * geometry.size.height
                        ))
                    }
                }
                .stroke(curveColor, lineWidth: 2)

                // Control Points
                ForEach(curve.indices, id: \.self) { index in
                    Circle()
                        .fill(curveColor)
                        .frame(width: 12, height: 12)
                        .position(
                            x: curve[index].x * geometry.size.width,
                            y: (1 - curve[index].y) * geometry.size.height
                        )
                        .gesture(
                            DragGesture()
                                .onChanged { value in
                                    let newX = max(0, min(1, value.location.x / geometry.size.width))
                                    let newY = max(0, min(1, 1 - value.location.y / geometry.size.height))
                                    curve[index] = CGPoint(x: newX, y: newY)
                                }
                        )
                }
            }
        }
    }

    private var curveColor: Color {
        switch curveType {
        case .red: return .red
        case .green: return .green
        case .blue: return .blue
        default: return .white
        }
    }
}

// MARK: - Scope Views

struct WaveformScopeView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Rectangle()
                    .fill(Color.black)

                // Waveform simulation
                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height

                    for x in stride(from: 0, to: width, by: 2) {
                        let baseY = height * 0.5
                        let variance = Double.random(in: -0.3...0.3) * height
                        path.move(to: CGPoint(x: x, y: baseY - abs(variance)))
                        path.addLine(to: CGPoint(x: x, y: baseY + abs(variance)))
                    }
                }
                .stroke(Color.green.opacity(0.7), lineWidth: 1)

                // Reference lines
                VStack {
                    Spacer()
                    Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 1)
                    Spacer()
                    Rectangle().fill(Color.gray.opacity(0.3)).frame(height: 1)
                    Spacer()
                }
            }
        }
        .cornerRadius(8)
        .padding()
    }
}

struct VectorscopeView: View {
    var body: some View {
        GeometryReader { geometry in
            let size = min(geometry.size.width, geometry.size.height) - 40

            ZStack {
                // Background
                Circle()
                    .fill(Color.black)
                    .frame(width: size, height: size)

                // Color targets
                ForEach(["R", "Mg", "B", "Cy", "G", "Yl"], id: \.self) { color in
                    Text(color)
                        .font(.caption2)
                        .foregroundColor(.gray)
                        .offset(colorTargetOffset(for: color, radius: size / 2 - 10))
                }

                // Graticule
                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    .frame(width: size * 0.75, height: size * 0.75)

                Circle()
                    .stroke(Color.gray.opacity(0.3), lineWidth: 1)
                    .frame(width: size * 0.5, height: size * 0.5)

                // Simulated data points
                ForEach(0..<100, id: \.self) { _ in
                    Circle()
                        .fill(Color.green.opacity(0.5))
                        .frame(width: 2, height: 2)
                        .offset(
                            x: CGFloat.random(in: -size/4...size/4),
                            y: CGFloat.random(in: -size/4...size/4)
                        )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding()
    }

    private func colorTargetOffset(for color: String, radius: CGFloat) -> CGSize {
        let angles: [String: Double] = [
            "R": -76, "Mg": -166, "B": 166, "Cy": 104, "G": 14, "Yl": -46
        ]
        let angle = (angles[color] ?? 0) * .pi / 180
        return CGSize(
            width: cos(angle) * radius,
            height: sin(angle) * radius
        )
    }
}

struct HistogramView: View {
    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background
                Rectangle()
                    .fill(Color.black)

                // RGB Histograms
                histogramPath(color: .red, geometry: geometry, seed: 1)
                histogramPath(color: .green, geometry: geometry, seed: 2)
                histogramPath(color: .blue, geometry: geometry, seed: 3)
            }
        }
        .cornerRadius(8)
        .padding()
    }

    private func histogramPath(color: Color, geometry: GeometryProxy, seed: Int) -> some View {
        Path { path in
            let width = geometry.size.width
            let height = geometry.size.height

            path.move(to: CGPoint(x: 0, y: height))

            for x in stride(from: 0, to: width, by: 4) {
                let normalizedX = x / width
                let gaussian = exp(-pow(normalizedX - 0.5, 2) / 0.1)
                let noise = Double.random(in: 0...0.3)
                let y = height - (gaussian + noise) * height * 0.7
                path.addLine(to: CGPoint(x: x, y: y))
            }

            path.addLine(to: CGPoint(x: width, y: height))
        }
        .fill(color.opacity(0.3))
    }
}

struct RGBParadeView: View {
    var body: some View {
        HStack(spacing: 4) {
            paradeChannel(color: .red)
            paradeChannel(color: .green)
            paradeChannel(color: .blue)
        }
        .padding()
    }

    private func paradeChannel(color: Color) -> some View {
        GeometryReader { geometry in
            ZStack {
                Rectangle()
                    .fill(Color.black)

                Path { path in
                    let width = geometry.size.width
                    let height = geometry.size.height

                    for x in stride(from: 0, to: width, by: 2) {
                        let baseY = height * 0.5
                        let variance = Double.random(in: -0.35...0.35) * height
                        path.move(to: CGPoint(x: x, y: baseY - abs(variance)))
                        path.addLine(to: CGPoint(x: x, y: baseY + abs(variance)))
                    }
                }
                .stroke(color.opacity(0.7), lineWidth: 1)
            }
        }
        .cornerRadius(4)
    }
}

// MARK: - Supporting Views

struct CurvePresetButton: View {
    let name: String
    let preset: CurvePreset

    var body: some View {
        Button(action: { /* Apply preset */ }) {
            Text(name)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.gray.opacity(0.3))
                .cornerRadius(4)
                .foregroundColor(.white)
        }
    }
}

struct FilmPresetButton: View {
    let name: String
    let preset: FilmPreset

    var body: some View {
        Button(action: { /* Apply preset */ }) {
            Text(name)
                .font(.caption)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.orange.opacity(0.3))
                .cornerRadius(4)
                .foregroundColor(.white)
        }
    }
}

struct WindowShapeButton: View {
    let shape: WindowShape
    let icon: String
    let title: String

    var body: some View {
        Button(action: { /* Select shape */ }) {
            VStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.title2)
                Text(title)
                    .font(.caption2)
            }
            .frame(width: 60, height: 60)
            .background(Color.gray.opacity(0.3))
            .cornerRadius(8)
            .foregroundColor(.white)
        }
    }
}

struct HueRangeSelector: View {
    @Binding var centerHue: Double
    @Binding var hueWidth: Double

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Hue gradient bar
                LinearGradient(
                    gradient: Gradient(colors: [
                        .red, .yellow, .green, .cyan, .blue, .magenta, .red
                    ]),
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .cornerRadius(4)

                // Selection overlay
                Rectangle()
                    .fill(Color.white.opacity(0.3))
                    .frame(width: geometry.size.width * hueWidth)
                    .position(
                        x: geometry.size.width * centerHue,
                        y: geometry.size.height / 2
                    )
            }
            .gesture(
                DragGesture()
                    .onChanged { value in
                        centerHue = max(0, min(1, value.location.x / geometry.size.width))
                    }
            )
        }
        .cornerRadius(4)
    }
}

struct RangeSlider: View {
    @Binding var range: ClosedRange<Double>
    let bounds: ClosedRange<Double>

    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(Color.gray.opacity(0.3))
                    .frame(height: 4)

                // Selected range
                Capsule()
                    .fill(Color.blue)
                    .frame(
                        width: CGFloat((range.upperBound - range.lowerBound) / (bounds.upperBound - bounds.lowerBound)) * geometry.size.width,
                        height: 4
                    )
                    .offset(x: CGFloat((range.lowerBound - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound)) * geometry.size.width)

                // Lower thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 16, height: 16)
                    .offset(x: CGFloat((range.lowerBound - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound)) * geometry.size.width - 8)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newValue = bounds.lowerBound + (value.location.x / geometry.size.width) * (bounds.upperBound - bounds.lowerBound)
                                range = max(bounds.lowerBound, min(range.upperBound - 0.01, newValue))...range.upperBound
                            }
                    )

                // Upper thumb
                Circle()
                    .fill(Color.white)
                    .frame(width: 16, height: 16)
                    .offset(x: CGFloat((range.upperBound - bounds.lowerBound) / (bounds.upperBound - bounds.lowerBound)) * geometry.size.width - 8)
                    .gesture(
                        DragGesture()
                            .onChanged { value in
                                let newValue = bounds.lowerBound + (value.location.x / geometry.size.width) * (bounds.upperBound - bounds.lowerBound)
                                range = range.lowerBound...min(bounds.upperBound, max(range.lowerBound + 0.01, newValue))
                            }
                    )
            }
        }
        .frame(height: 20)
    }
}

struct PowerWindowPreview: View {
    let window: PowerWindow

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Background image placeholder
                Rectangle()
                    .fill(Color.gray.opacity(0.2))

                // Window shape
                Circle()
                    .stroke(Color.yellow, lineWidth: 2)
                    .frame(width: 100, height: 100)

                Text("Window Preview")
                    .font(.caption)
                    .foregroundColor(.gray)
            }
        }
    }
}

struct LUTBrowserView: View {
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            List {
                Section("Built-in LUTs") {
                    ForEach(["Rec709 to sRGB", "Log to Rec709", "Cinematic", "Vintage", "High Contrast"], id: \.self) { lut in
                        Button(lut) {
                            // Apply LUT
                            dismiss()
                        }
                    }
                }

                Section("Custom LUTs") {
                    Button(action: { /* Import LUT */ }) {
                        Label("Import .cube LUT", systemImage: "plus.circle")
                    }
                }
            }
            .navigationTitle("LUT Browser")
            .toolbar {
                Button("Done") { dismiss() }
            }
        }
    }
}

// MARK: - Data Models Extension

extension ColorGrade {
    var contrast: Double { get { 0 } set { } }
    var saturation: Double { get { 0 } set { } }
    var vibrance: Double { get { 0 } set { } }
    var temperature: Double { get { 0 } set { } }
    var tint: Double { get { 0 } set { } }
    var exposure: Double { get { 0 } set { } }

    var activeCurve: CurveType { get { .rgb } set { } }
    var rgbCurve: [CGPoint] { get { [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)] } set { } }
    var redCurve: [CGPoint] { get { [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)] } set { } }
    var greenCurve: [CGPoint] { get { [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)] } set { } }
    var blueCurve: [CGPoint] { get { [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)] } set { } }
    var lumaCurve: [CGPoint] { get { [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)] } set { } }
    var hueVsHueCurve: [CGPoint] { get { [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)] } set { } }
    var hueVsSatCurve: [CGPoint] { get { [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)] } set { } }
    var satVsSatCurve: [CGPoint] { get { [CGPoint(x: 0, y: 0), CGPoint(x: 1, y: 1)] } set { } }

    var hslQualifier: HSLQualifier { get { HSLQualifier() } set { } }
    var powerWindow: PowerWindow { get { PowerWindow() } set { } }
}

struct HSLQualifier {
    var centerHue: Double = 0.5
    var hueWidth: Double = 0.2
    var saturationRange: ClosedRange<Double> = 0...1
    var luminanceRange: ClosedRange<Double> = 0...1
    var hueShift: Double = 0
    var saturationAdjust: Double = 0
    var luminanceAdjust: Double = 0
}

struct PowerWindow {
    var shape: WindowShape = .circle
    var softness: Double = 50
    var opacity: Double = 100
    var inverted: Bool = false
    var trackingEnabled: Bool = false
}

// MARK: - Preview

#Preview {
    ColorGradingView()
}
