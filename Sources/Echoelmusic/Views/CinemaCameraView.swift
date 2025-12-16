import SwiftUI
import AVFoundation

/// Professional Cinema Camera Control Interface
/// Better than Blackmagic with AI-powered intelligence
struct CinemaCameraView: View {
    @StateObject private var camera: CinemaCameraSystem
    @StateObject private var grading = ProfessionalColorGrading()
    @StateObject private var timeline: VideoTimeline?
    @StateObject private var musicTimeline: MusicTimeline?
    @State private var showColorWheels = false
    @State private var showScopes = false
    @State private var showAdvancedSettings = false
    @State private var focusLocation: CGPoint = .zero

    init(timeline: VideoTimeline? = nil, musicTimeline: MusicTimeline? = nil) {
        _camera = StateObject(wrappedValue: CinemaCameraSystem(timeline: timeline, musicTimeline: musicTimeline))
        _timeline = StateObject(wrappedValue: timeline)
        _musicTimeline = StateObject(wrappedValue: musicTimeline)
    }

    var body: some View {
        ZStack {
            // Camera preview
            CameraPreviewView(camera: camera)
                .ignoresSafeArea()
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            focusLocation = value.location
                            camera.setFocus(at: value.location)
                        }
                )

            // Professional overlays
            VStack {
                // Top bar - Recording status
                topBar

                Spacer()

                // AI suggestions (if any)
                if !camera.currentSuggestions.isEmpty {
                    aiSuggestionsPanel
                        .padding()
                }

                Spacer()

                // Bottom controls
                bottomControls
            }

            // Professional monitoring overlays
            if camera.zebraEnabled || camera.peakingEnabled || camera.falseColorEnabled {
                monitoringOverlays
            }

            // Color grading panel
            if showColorWheels {
                colorGradingPanel
                    .transition(.move(edge: .trailing))
            }

            // Professional scopes
            if showScopes {
                scopesPanel
                    .transition(.move(edge: .leading))
            }

            // Focus indicator
            if camera.isFocusing {
                FocusIndicatorView(location: focusLocation)
            }
        }
        .preferredColorScheme(.dark)
        .onAppear {
            camera.startSession()
            camera.colorGrading = grading
        }
        .onDisappear {
            camera.stopSession()
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        HStack(spacing: 20) {
            // Recording indicator
            HStack(spacing: 8) {
                if camera.isRecording {
                    Circle()
                        .fill(Color.red)
                        .frame(width: 12, height: 12)
                        .overlay(
                            Circle()
                                .stroke(Color.red.opacity(0.3), lineWidth: 4)
                                .scaleEffect(camera.isRecording ? 1.5 : 1.0)
                                .opacity(camera.isRecording ? 0 : 1)
                                .animation(.easeOut(duration: 1).repeatForever(autoreverses: false), value: camera.isRecording)
                        )

                    Text(camera.recordingDuration)
                        .font(.system(.title3, design: .monospaced))
                        .foregroundColor(.red)
                } else {
                    Image(systemName: "video.fill")
                        .foregroundColor(.white)

                    Text("READY")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.green)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.7))
            )

            Spacer()

            // Current settings display
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(camera.currentCodec.displayName) | \(camera.currentFrameRate.displayName)")
                    .font(.system(.caption, design: .monospaced))

                Text("ISO \(Int(camera.iso)) | f/\(String(format: "%.1f", camera.aperture)) | \(String(format: "%.0f°", camera.shutterAngle))")
                    .font(.system(.caption2, design: .monospaced))

                Text("\(Int(camera.whiteBalanceKelvin))K \(camera.whiteBalanceTint > 0 ? "+" : "")\(Int(camera.whiteBalanceTint))T")
                    .font(.system(.caption2, design: .monospaced))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.black.opacity(0.7))
            )
        }
        .padding()
    }

    // MARK: - AI Suggestions

    private var aiSuggestionsPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "brain.head.profile")
                    .foregroundColor(.cyan)
                Text("AI Suggestions")
                    .font(.caption.bold())
                    .foregroundColor(.white)
            }

            ForEach(camera.currentSuggestions.prefix(3), id: \.self) { suggestion in
                HStack(spacing: 6) {
                    Image(systemName: suggestion.hasPrefix("⚠️") ? "exclamationmark.triangle.fill" : "lightbulb.fill")
                        .font(.caption2)
                        .foregroundColor(suggestion.hasPrefix("⚠️") ? .orange : .yellow)

                    Text(suggestion)
                        .font(.caption2)
                        .foregroundColor(.white)
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.8))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.cyan.opacity(0.3), lineWidth: 1)
                )
        )
        .frame(maxWidth: 400)
    }

    // MARK: - Bottom Controls

    private var bottomControls: some View {
        VStack(spacing: 16) {
            // Manual controls row
            HStack(spacing: 20) {
                // ISO
                ManualControlWheel(
                    icon: "camera.aperture",
                    label: "ISO",
                    value: $camera.iso,
                    range: 100...25600,
                    displayValue: "\(Int(camera.iso))",
                    formatString: "%.0f"
                )

                // Shutter Angle
                ManualControlWheel(
                    icon: "timer",
                    label: "SHUTTER",
                    value: $camera.shutterAngle,
                    range: 45...360,
                    displayValue: "\(String(format: "%.0f", camera.shutterAngle))°",
                    formatString: "%.0f°"
                )

                // Aperture
                ManualControlWheel(
                    icon: "circle.hexagonpath",
                    label: "APERTURE",
                    value: $camera.aperture,
                    range: 1.4...22,
                    displayValue: "f/\(String(format: "%.1f", camera.aperture))",
                    formatString: "f/%.1f"
                )

                // Focus
                ManualControlWheel(
                    icon: "scope",
                    label: "FOCUS",
                    value: $camera.focusDistance,
                    range: 0...1,
                    displayValue: camera.focusDistance < 0.1 ? "∞" : "\(String(format: "%.1f", (1.0 - camera.focusDistance) * 10))m",
                    formatString: "%.2f"
                )
            }

            // Kelvin temperature control
            VStack(spacing: 8) {
                HStack {
                    Text("WHITE BALANCE")
                        .font(.system(.caption2, design: .monospaced))
                        .foregroundColor(.secondary)

                    Spacer()

                    Text("\(Int(camera.whiteBalanceKelvin))K")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.white)

                    Text("\(camera.whiteBalanceTint > 0 ? "+" : "")\(Int(camera.whiteBalanceTint))T")
                        .font(.system(.caption, design: .monospaced))
                        .foregroundColor(.white)
                }

                HStack(spacing: 8) {
                    // Temperature slider with color gradient
                    VStack(spacing: 4) {
                        Text("TEMP")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)

                        Slider(value: $camera.whiteBalanceKelvin, in: 1000...10000)
                            .tint(
                                LinearGradient(
                                    colors: [.blue, .cyan, .white, .orange, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }

                    // Tint slider (green-magenta)
                    VStack(spacing: 4) {
                        Text("TINT")
                            .font(.system(.caption2, design: .monospaced))
                            .foregroundColor(.secondary)

                        Slider(value: $camera.whiteBalanceTint, in: -100...100)
                            .tint(
                                LinearGradient(
                                    colors: [.green, .white, .purple],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                    }
                    .frame(width: 120)
                }

                // Kelvin presets
                HStack(spacing: 8) {
                    KelvinPresetButton(label: "TUNGSTEN", kelvin: 3200, camera: camera)
                    KelvinPresetButton(label: "DAYLIGHT", kelvin: 5600, camera: camera)
                    KelvinPresetButton(label: "CLOUDY", kelvin: 6500, camera: camera)
                    KelvinPresetButton(label: "SHADE", kelvin: 7500, camera: camera)
                }
            }
            .padding()
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(Color.black.opacity(0.7))
            )

            // Main action buttons
            HStack(spacing: 20) {
                // Color wheels toggle
                Button(action: { withAnimation { showColorWheels.toggle() } }) {
                    VStack(spacing: 4) {
                        Image(systemName: "paintpalette.fill")
                            .font(.title2)
                        Text("COLOR")
                            .font(.caption2)
                    }
                    .foregroundColor(showColorWheels ? .cyan : .white)
                    .frame(width: 70, height: 60)
                }
                .buttonStyle(CinemaButtonStyle(isActive: showColorWheels))

                // Scopes toggle
                Button(action: { withAnimation { showScopes.toggle() } }) {
                    VStack(spacing: 4) {
                        Image(systemName: "waveform.path.ecg")
                            .font(.title2)
                        Text("SCOPES")
                            .font(.caption2)
                    }
                    .foregroundColor(showScopes ? .cyan : .white)
                    .frame(width: 70, height: 60)
                }
                .buttonStyle(CinemaButtonStyle(isActive: showScopes))

                // Record button
                Button(action: {
                    if camera.isRecording {
                        camera.stopRecording()
                    } else {
                        camera.startRecording()
                    }
                }) {
                    ZStack {
                        Circle()
                            .strokeBorder(Color.red, lineWidth: 4)
                            .frame(width: 70, height: 70)

                        if camera.isRecording {
                            RoundedRectangle(cornerRadius: 4)
                                .fill(Color.red)
                                .frame(width: 30, height: 30)
                        } else {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 60, height: 60)
                        }
                    }
                }

                // Timeline record toggle
                Button(action: { camera.recordToTimeline.toggle() }) {
                    VStack(spacing: 4) {
                        Image(systemName: camera.recordToTimeline ? "square.stack.3d.down.forward.fill" : "square.stack.3d.down.forward")
                            .font(.title2)
                        Text("TIMELINE")
                            .font(.caption2)
                    }
                    .foregroundColor(camera.recordToTimeline ? .green : .white)
                    .frame(width: 70, height: 60)
                }
                .buttonStyle(CinemaButtonStyle(isActive: camera.recordToTimeline))

                // Beat sync toggle
                Button(action: { camera.beatSyncEnabled.toggle() }) {
                    VStack(spacing: 4) {
                        Image(systemName: "waveform.badge.magnifyingglass")
                            .font(.title2)
                        Text("BEAT SYNC")
                            .font(.caption2)
                    }
                    .foregroundColor(camera.beatSyncEnabled ? .purple : .white)
                    .frame(width: 70, height: 60)
                }
                .buttonStyle(CinemaButtonStyle(isActive: camera.beatSyncEnabled))
            }
        }
        .padding()
    }

    // MARK: - Color Grading Panel

    private var colorGradingPanel: some View {
        HStack {
            Spacer()

            VStack(spacing: 20) {
                // Header
                HStack {
                    Text("COLOR GRADING")
                        .font(.headline)
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: { withAnimation { showColorWheels = false } }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }

                ScrollView {
                    VStack(spacing: 24) {
                        // 3-Way Color Wheels
                        Text("3-WAY COLOR CORRECTION")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        // Lift (Shadows)
                        ColorWheelControl(
                            title: "LIFT (Shadows)",
                            wheel: $grading.shadowsLift,
                            icon: "moon.stars.fill"
                        )

                        // Gamma (Midtones)
                        ColorWheelControl(
                            title: "GAMMA (Midtones)",
                            wheel: $grading.midtonesGamma,
                            icon: "circle.lefthalf.filled"
                        )

                        // Gain (Highlights)
                        ColorWheelControl(
                            title: "GAIN (Highlights)",
                            wheel: $grading.highlightsGain,
                            icon: "sun.max.fill"
                        )

                        Divider()

                        // Global adjustments
                        Text("GLOBAL ADJUSTMENTS")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        VStack(spacing: 12) {
                            GradingSlider(label: "EXPOSURE", value: $grading.exposure, range: -2...2)
                            GradingSlider(label: "CONTRAST", value: $grading.contrast, range: 0...2)
                            GradingSlider(label: "SATURATION", value: $grading.saturation, range: 0...2)
                            GradingSlider(label: "VIBRANCE", value: $grading.vibrance, range: 0...2)
                        }

                        Divider()

                        // Presets
                        Text("PRESETS")
                            .font(.caption.bold())
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                            ForEach(ProfessionalColorGrading.ColorGradingPreset.allCases, id: \.self) { preset in
                                Button(action: {
                                    grading.loadPreset(preset)
                                    camera.applyColorGrading()
                                }) {
                                    VStack(spacing: 4) {
                                        Image(systemName: preset.icon)
                                            .font(.title3)
                                        Text(preset.displayName)
                                            .font(.caption2)
                                    }
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 12)
                                    .background(
                                        RoundedRectangle(cornerRadius: 8)
                                            .fill(Color.white.opacity(0.1))
                                    )
                                }
                            }
                        }

                        // Reset button
                        Button(action: {
                            grading.reset()
                            camera.applyColorGrading()
                        }) {
                            HStack {
                                Image(systemName: "arrow.counterclockwise")
                                Text("Reset All")
                            }
                            .foregroundColor(.red)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.red.opacity(0.1))
                            )
                        }
                    }
                    .padding()
                }
            }
            .frame(width: 400)
            .background(
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color.black.opacity(0.95))
            )
        }
    }

    // MARK: - Scopes Panel

    private var scopesPanel: some View {
        HStack {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Text("SCOPES")
                        .font(.headline)
                        .foregroundColor(.white)

                    Spacer()

                    Button(action: { withAnimation { showScopes = false } }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                }
                .padding()

                // Waveform
                VStack(alignment: .leading, spacing: 4) {
                    Text("WAVEFORM")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    WaveformScopeView()
                        .frame(height: 150)
                }
                .padding(.horizontal)

                // Vectorscope
                VStack(alignment: .leading, spacing: 4) {
                    Text("VECTORSCOPE")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    VectorscopeView()
                        .frame(height: 150)
                }
                .padding(.horizontal)

                // RGB Parade
                VStack(alignment: .leading, spacing: 4) {
                    Text("RGB PARADE")
                        .font(.caption.bold())
                        .foregroundColor(.secondary)

                    RGBParadeView()
                        .frame(height: 150)
                }
                .padding(.horizontal)

                Spacer()
            }
            .frame(width: 300)
            .background(
                RoundedRectangle(cornerRadius: 0)
                    .fill(Color.black.opacity(0.95))
            )

            Spacer()
        }
    }

    // MARK: - Monitoring Overlays

    private var monitoringOverlays: some View {
        ZStack {
            if camera.zebraEnabled {
                ZebraOverlayView(threshold: camera.zebraThreshold)
            }

            if camera.peakingEnabled {
                PeakingOverlayView(color: camera.peakingColor)
            }

            if camera.falseColorEnabled {
                FalseColorOverlayView()
            }
        }
    }
}

// MARK: - Supporting Views

struct ManualControlWheel: View {
    let icon: String
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>
    let displayValue: String
    let formatString: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.white)

            Text(displayValue)
                .font(.system(.caption, design: .monospaced))
                .foregroundColor(.white)
                .frame(width: 70)

            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(.secondary)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.black.opacity(0.7))
        )
        .gesture(
            DragGesture()
                .onChanged { gesture in
                    let delta = Float(gesture.translation.height) * -0.01
                    let newValue = value + (delta * (range.upperBound - range.lowerBound) * 0.1)
                    value = min(max(newValue, range.lowerBound), range.upperBound)
                }
        )
    }
}

struct KelvinPresetButton: View {
    let label: String
    let kelvin: Float
    let camera: CinemaCameraSystem

    var body: some View {
        Button(action: {
            camera.whiteBalanceKelvin = kelvin
        }) {
            Text(label)
                .font(.system(.caption2, design: .monospaced))
                .foregroundColor(abs(camera.whiteBalanceKelvin - kelvin) < 100 ? .cyan : .white)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(abs(camera.whiteBalanceKelvin - kelvin) < 100 ? Color.cyan.opacity(0.2) : Color.white.opacity(0.1))
                )
        }
    }
}

struct ColorWheelControl: View {
    let title: String
    @Binding var wheel: ColorWheel
    let icon: String

    var body: some View {
        VStack(spacing: 12) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(.white)
                Text(title)
                    .font(.subheadline.bold())
                    .foregroundColor(.white)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // Color wheel interface
            ZStack {
                // Wheel background
                Circle()
                    .fill(
                        AngularGradient(
                            colors: [.red, .yellow, .green, .cyan, .blue, .purple, .red],
                            center: .center
                        )
                    )
                    .frame(width: 200, height: 200)
                    .overlay(
                        Circle()
                            .fill(
                                RadialGradient(
                                    colors: [.white, .clear],
                                    center: .center,
                                    startRadius: 0,
                                    endRadius: 100
                                )
                            )
                    )

                // Crosshair indicator
                Circle()
                    .fill(Color.white)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle()
                            .stroke(Color.black, lineWidth: 2)
                    )
                    .offset(
                        x: CGFloat(wheel.saturation * cos(wheel.hue * .pi * 2)) * 100,
                        y: CGFloat(wheel.saturation * sin(wheel.hue * .pi * 2)) * 100
                    )
            }
            .frame(width: 220, height: 220)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        let center = CGPoint(x: 110, y: 110)
                        let dx = gesture.location.x - center.x
                        let dy = gesture.location.y - center.y

                        wheel.hue = Float(atan2(dy, dx) / (.pi * 2))
                        wheel.saturation = min(Float(sqrt(dx * dx + dy * dy) / 100.0), 1.0)
                    }
            )

            // Luminance slider
            HStack {
                Text("LUMINANCE")
                    .font(.caption2)
                    .foregroundColor(.secondary)

                Slider(value: $wheel.luminance, in: 0...2)
                    .tint(.white)

                Text(String(format: "%.2f", wheel.luminance))
                    .font(.caption.monospacedDigit())
                    .foregroundColor(.white)
                    .frame(width: 50, alignment: .trailing)
            }
        }
    }
}

struct GradingSlider: View {
    let label: String
    @Binding var value: Float
    let range: ClosedRange<Float>

    var body: some View {
        HStack {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(width: 100, alignment: .leading)

            Slider(value: $value, in: range)
                .tint(.white)

            Text(String(format: "%.2f", value))
                .font(.caption.monospacedDigit())
                .foregroundColor(.white)
                .frame(width: 50, alignment: .trailing)
        }
    }
}

struct CinemaButtonStyle: ButtonStyle {
    let isActive: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? Color.cyan.opacity(0.2) : Color.black.opacity(0.7))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(isActive ? Color.cyan : Color.clear, lineWidth: 2)
                    )
            )
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
    }
}

struct FocusIndicatorView: View {
    let location: CGPoint

    var body: some View {
        ZStack {
            Circle()
                .strokeBorder(Color.yellow, lineWidth: 2)
                .frame(width: 80, height: 80)

            Rectangle()
                .fill(Color.yellow)
                .frame(width: 20, height: 2)

            Rectangle()
                .fill(Color.yellow)
                .frame(width: 2, height: 20)
        }
        .position(location)
        .transition(.scale.combined(with: .opacity))
        .animation(.easeOut(duration: 0.3), value: location)
    }
}

// MARK: - Scope Views (Placeholders)

struct WaveformScopeView: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.black)

            Text("WAVEFORM")
                .font(.caption)
                .foregroundColor(.green.opacity(0.3))
        }
        .overlay(
            Rectangle()
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

struct VectorscopeView: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.black)

            Circle()
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
                .frame(width: 120, height: 120)

            Text("VECTORSCOPE")
                .font(.caption)
                .foregroundColor(.green.opacity(0.3))
        }
        .overlay(
            Rectangle()
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

struct RGBParadeView: View {
    var body: some View {
        ZStack {
            Rectangle()
                .fill(Color.black)

            HStack(spacing: 2) {
                Rectangle().fill(Color.red.opacity(0.3))
                Rectangle().fill(Color.green.opacity(0.3))
                Rectangle().fill(Color.blue.opacity(0.3))
            }
            .padding(4)

            Text("RGB PARADE")
                .font(.caption)
                .foregroundColor(.white.opacity(0.3))
        }
        .overlay(
            Rectangle()
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
    }
}

struct ZebraOverlayView: View {
    let threshold: Float

    var body: some View {
        // Placeholder - would analyze camera feed and show zebra pattern for overexposed areas
        EmptyView()
    }
}

struct PeakingOverlayView: View {
    let color: PeakingColor

    var body: some View {
        // Placeholder - would highlight in-focus edges
        EmptyView()
    }
}

struct FalseColorOverlayView: View {
    var body: some View {
        // Placeholder - would show exposure as false colors
        EmptyView()
    }
}

struct CameraPreviewView: View {
    @ObservedObject var camera: CinemaCameraSystem

    var body: some View {
        // Placeholder - would show actual camera feed via AVCaptureVideoPreviewLayer
        ZStack {
            Color.black

            if camera.isSessionRunning {
                Text("CAMERA PREVIEW")
                    .font(.title)
                    .foregroundColor(.white.opacity(0.1))
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "video.slash")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("Camera Not Available")
                        .font(.headline)
                        .foregroundColor(.secondary)
                }
            }
        }
    }
}

// MARK: - Extensions

extension ProfessionalColorGrading.ColorGradingPreset {
    var displayName: String {
        switch self {
        case .tungsten3200K: return "Tungsten 3200K"
        case .daylight5600K: return "Daylight 5600K"
        case .goldenHour: return "Golden Hour"
        case .blueHour: return "Blue Hour"
        case .overcast: return "Overcast"
        case .sunny: return "Sunny"
        case .cinematic: return "Cinematic"
        case .kodakVision3: return "Kodak Vision3"
        case .fujiEterna: return "Fuji Eterna"
        case .fujiVelvia: return "Fuji Velvia"
        }
    }

    var icon: String {
        switch self {
        case .tungsten3200K: return "lightbulb.fill"
        case .daylight5600K: return "sun.max.fill"
        case .goldenHour: return "sunrise.fill"
        case .blueHour: return "moon.fill"
        case .overcast: return "cloud.fill"
        case .sunny: return "sun.and.horizon.fill"
        case .cinematic: return "film.fill"
        case .kodakVision3: return "k.square.fill"
        case .fujiEterna: return "f.square.fill"
        case .fujiVelvia: return "v.square.fill"
        }
    }

    static var allCases: [Self] {
        [.tungsten3200K, .daylight5600K, .goldenHour, .blueHour, .overcast, .sunny, .cinematic, .kodakVision3, .fujiEterna, .fujiVelvia]
    }
}

#Preview {
    CinemaCameraView()
}
