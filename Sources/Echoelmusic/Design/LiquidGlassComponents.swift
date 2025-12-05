import SwiftUI
import Combine

// MARK: - Liquid Glass Components
// Extended component library for Apple iOS 26 Liquid Glass design system
// Specialized audio/visual production UI elements with bio-reactive adaptation

// MARK: - Glass Icon Button

/// Circular icon button with liquid glass effect
struct LiquidGlassIconButton: View {
    let icon: String
    let size: Size
    let tint: Color
    let action: () -> Void

    @State private var isPressed = false

    enum Size {
        case small, medium, large, extraLarge

        var dimension: CGFloat {
            switch self {
            case .small: return 36
            case .medium: return 44
            case .large: return 56
            case .extraLarge: return 72
            }
        }

        var iconFont: Font {
            switch self {
            case .small: return .body
            case .medium: return .title3
            case .large: return .title2
            case .extraLarge: return .title
            }
        }
    }

    init(
        icon: String,
        size: Size = .medium,
        tint: Color = .white,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.size = size
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(size.iconFont)
                .foregroundStyle(tint)
                .frame(width: size.dimension, height: size.dimension)
                .liquidGlass(.regular, cornerRadius: size.dimension / 2)
        }
        .buttonStyle(.plain)
        .scaleEffect(isPressed ? 0.9 : 1.0)
        .animation(.spring(response: 0.2, dampingFraction: 0.7), value: isPressed)
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}

// MARK: - Glass Segmented Control

struct LiquidGlassSegmentedControl: View {
    @Binding var selection: Int
    let options: [String]
    let tint: Color

    init(selection: Binding<Int>, options: [String], tint: Color = .cyan) {
        self._selection = selection
        self.options = options
        self.tint = tint
    }

    var body: some View {
        HStack(spacing: 4) {
            ForEach(Array(options.enumerated()), id: \.offset) { index, option in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selection = index
                    }
                } label: {
                    Text(option)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(selection == index ? .white : .white.opacity(0.6))
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity)
                        .background(
                            selection == index
                                ? tint.opacity(0.4)
                                : Color.clear
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .liquidGlass(.regular, cornerRadius: 14)
    }
}

// MARK: - Glass Text Field

struct LiquidGlassTextField: View {
    @Binding var text: String
    let placeholder: String
    let icon: String?
    let isSecure: Bool

    @FocusState private var isFocused: Bool

    init(
        text: Binding<String>,
        placeholder: String,
        icon: String? = nil,
        isSecure: Bool = false
    ) {
        self._text = text
        self.placeholder = placeholder
        self.icon = icon
        self.isSecure = isSecure
    }

    var body: some View {
        HStack(spacing: 12) {
            if let icon = icon {
                Image(systemName: icon)
                    .foregroundStyle(.white.opacity(0.6))
            }

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .textFieldStyle(.plain)
            .foregroundStyle(.white)
            .focused($isFocused)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .liquidGlass(
            isFocused ? .tinted : .regular,
            tint: isFocused ? .cyan : nil,
            cornerRadius: 14
        )
        .animation(.easeInOut(duration: 0.2), value: isFocused)
    }
}

// MARK: - Glass Search Bar

struct LiquidGlassSearchBar: View {
    @Binding var text: String
    let placeholder: String
    var onSearch: ((String) -> Void)?

    @FocusState private var isFocused: Bool

    init(
        text: Binding<String>,
        placeholder: String = "Search...",
        onSearch: ((String) -> Void)? = nil
    ) {
        self._text = text
        self.placeholder = placeholder
        self.onSearch = onSearch
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.white.opacity(0.6))

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .foregroundStyle(.white)
                .focused($isFocused)
                .onSubmit {
                    onSearch?(text)
                }

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .liquidGlass(.regular, cornerRadius: 20)
    }
}

// MARK: - Glass Progress Indicator

struct LiquidGlassProgress: View {
    let progress: Double
    let label: String?
    let tint: Color
    let showPercentage: Bool

    init(
        progress: Double,
        label: String? = nil,
        tint: Color = .cyan,
        showPercentage: Bool = true
    ) {
        self.progress = max(0, min(1, progress))
        self.label = label
        self.tint = tint
        self.showPercentage = showPercentage
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if label != nil || showPercentage {
                HStack {
                    if let label = label {
                        Text(label)
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.8))
                    }

                    Spacer()

                    if showPercentage {
                        Text("\(Int(progress * 100))%")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(tint)
                    }
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(Color.white.opacity(0.1))

                    // Fill
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.8), tint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * progress)
                        .shadow(color: tint.opacity(0.5), radius: 4)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .liquidGlass(.regular, cornerRadius: 16)
    }
}

// MARK: - Glass Circular Progress

struct LiquidGlassCircularProgress: View {
    let progress: Double
    let size: CGFloat
    let lineWidth: CGFloat
    let tint: Color
    let label: String?

    init(
        progress: Double,
        size: CGFloat = 80,
        lineWidth: CGFloat = 6,
        tint: Color = .cyan,
        label: String? = nil
    ) {
        self.progress = max(0, min(1, progress))
        self.size = size
        self.lineWidth = lineWidth
        self.tint = tint
        self.label = label
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(Color.white.opacity(0.1), lineWidth: lineWidth)

            // Progress ring
            Circle()
                .trim(from: 0, to: progress)
                .stroke(
                    AngularGradient(
                        colors: [tint.opacity(0.3), tint],
                        center: .center,
                        startAngle: .degrees(0),
                        endAngle: .degrees(360 * progress)
                    ),
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
                .shadow(color: tint.opacity(0.5), radius: 4)

            // Center content
            VStack(spacing: 2) {
                Text("\(Int(progress * 100))")
                    .font(.system(size: size * 0.3, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                if let label = label {
                    Text(label)
                        .font(.system(size: size * 0.12))
                        .foregroundStyle(.white.opacity(0.6))
                }
            }
        }
        .frame(width: size, height: size)
        .padding(8)
        .liquidGlass(.regular, cornerRadius: size / 2 + 8)
    }
}

// MARK: - Glass Audio Meter

struct LiquidGlassAudioMeter: View {
    let level: Float // 0.0 to 1.0
    let peak: Float  // Peak hold
    let orientation: Orientation
    let channelCount: Int

    enum Orientation {
        case horizontal, vertical
    }

    init(
        level: Float,
        peak: Float = 0,
        orientation: Orientation = .vertical,
        channelCount: Int = 1
    ) {
        self.level = max(0, min(1, level))
        self.peak = max(0, min(1, peak))
        self.orientation = orientation
        self.channelCount = channelCount
    }

    var body: some View {
        Group {
            if orientation == .vertical {
                VStack(spacing: 4) {
                    ForEach(0..<channelCount, id: \.self) { channel in
                        verticalMeter
                    }
                }
            } else {
                HStack(spacing: 4) {
                    ForEach(0..<channelCount, id: \.self) { channel in
                        horizontalMeter
                    }
                }
            }
        }
        .padding(8)
        .liquidGlass(.regular, cornerRadius: 12)
    }

    private var verticalMeter: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Background segments
                VStack(spacing: 2) {
                    ForEach(0..<20, id: \.self) { i in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(Color.white.opacity(0.1))
                            .frame(height: (geometry.size.height - 38) / 20)
                    }
                }

                // Level fill
                VStack(spacing: 2) {
                    ForEach(0..<20, id: \.self) { i in
                        let segmentLevel = Float(20 - i) / 20.0
                        RoundedRectangle(cornerRadius: 2)
                            .fill(segmentColor(for: segmentLevel))
                            .frame(height: (geometry.size.height - 38) / 20)
                            .opacity(level >= segmentLevel ? 1 : 0)
                    }
                }

                // Peak indicator
                RoundedRectangle(cornerRadius: 2)
                    .fill(Color.red)
                    .frame(height: 3)
                    .offset(y: -geometry.size.height * CGFloat(peak) + 3)
            }
        }
        .frame(width: 24)
    }

    private var horizontalMeter: some View {
        GeometryReader { geometry in
            ZStack(alignment: .leading) {
                // Background
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.white.opacity(0.1))

                // Level fill
                RoundedRectangle(cornerRadius: 4)
                    .fill(
                        LinearGradient(
                            colors: [.green, .yellow, .orange, .red],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                    )
                    .frame(width: geometry.size.width * CGFloat(level))

                // Peak indicator
                Rectangle()
                    .fill(Color.red)
                    .frame(width: 2)
                    .offset(x: geometry.size.width * CGFloat(peak) - 1)
            }
        }
        .frame(height: 12)
    }

    private func segmentColor(for level: Float) -> Color {
        if level > 0.9 {
            return .red
        } else if level > 0.75 {
            return .orange
        } else if level > 0.5 {
            return .yellow
        } else {
            return .green
        }
    }
}

// MARK: - Glass Waveform Display

struct LiquidGlassWaveform: View, Equatable {
    let samples: [Float]
    let tint: Color
    let fillGradient: Bool

    init(samples: [Float], tint: Color = .cyan, fillGradient: Bool = true) {
        self.samples = samples
        self.tint = tint
        self.fillGradient = fillGradient
    }

    static func == (lhs: LiquidGlassWaveform, rhs: LiquidGlassWaveform) -> Bool {
        lhs.samples == rhs.samples && lhs.tint == rhs.tint
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                if fillGradient {
                    // Fill gradient
                    Path { path in
                        drawWaveformPath(path: &path, in: geometry.size, closed: true)
                    }
                    .fill(
                        LinearGradient(
                            colors: [tint.opacity(0.4), tint.opacity(0.1), Color.clear],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                }

                // Waveform line
                Path { path in
                    drawWaveformPath(path: &path, in: geometry.size, closed: false)
                }
                .stroke(
                    LinearGradient(
                        colors: [tint.opacity(0.8), tint],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
                .shadow(color: tint.opacity(0.5), radius: 4)
            }
        }
        .padding()
        .liquidGlass(.clear, cornerRadius: 16)
    }

    private func drawWaveformPath(path: inout Path, in size: CGSize, closed: Bool) {
        guard !samples.isEmpty else { return }

        let midY = size.height / 2
        let stepX = size.width / CGFloat(samples.count - 1)

        path.move(to: CGPoint(x: 0, y: midY - CGFloat(samples[0]) * midY))

        for (index, sample) in samples.enumerated() {
            let x = CGFloat(index) * stepX
            let y = midY - CGFloat(sample) * midY * 0.9
            path.addLine(to: CGPoint(x: x, y: y))
        }

        if closed {
            path.addLine(to: CGPoint(x: size.width, y: size.height))
            path.addLine(to: CGPoint(x: 0, y: size.height))
            path.closeSubpath()
        }
    }
}

// MARK: - Glass Spectrum Analyzer

struct LiquidGlassSpectrum: View, Equatable {
    let bands: [Float]
    let tint: Color
    let barSpacing: CGFloat

    init(bands: [Float], tint: Color = .cyan, barSpacing: CGFloat = 4) {
        self.bands = bands
        self.tint = tint
        self.barSpacing = barSpacing
    }

    static func == (lhs: LiquidGlassSpectrum, rhs: LiquidGlassSpectrum) -> Bool {
        lhs.bands == rhs.bands
    }

    var body: some View {
        GeometryReader { geometry in
            HStack(alignment: .bottom, spacing: barSpacing) {
                ForEach(Array(bands.enumerated()), id: \.offset) { index, level in
                    let normalizedLevel = CGFloat(max(0.05, min(1, level)))
                    let barHeight = geometry.size.height * normalizedLevel

                    RoundedRectangle(cornerRadius: 4)
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.6), tint],
                                startPoint: .bottom,
                                endPoint: .top
                            )
                        )
                        .frame(height: barHeight)
                        .shadow(color: tint.opacity(0.3), radius: 4)
                }
            }
            .padding(.horizontal, 4)
        }
        .padding()
        .liquidGlass(.clear, cornerRadius: 16)
    }
}

// MARK: - Glass Knob Control

struct LiquidGlassKnob: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let label: String
    let tint: Color
    let size: CGFloat

    @State private var isDragging = false
    @State private var lastAngle: Angle = .zero

    init(
        value: Binding<Double>,
        in range: ClosedRange<Double> = 0...1,
        label: String = "",
        tint: Color = .cyan,
        size: CGFloat = 80
    ) {
        self._value = value
        self.range = range
        self.label = label
        self.tint = tint
        self.size = size
    }

    private var normalizedValue: Double {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }

    private var rotationAngle: Angle {
        .degrees(normalizedValue * 270 - 135)
    }

    var body: some View {
        VStack(spacing: 8) {
            ZStack {
                // Track arc
                Circle()
                    .trim(from: 0.125, to: 0.875)
                    .rotation(.degrees(90))
                    .stroke(Color.white.opacity(0.1), lineWidth: 4)

                // Value arc
                Circle()
                    .trim(from: 0.125, to: 0.125 + normalizedValue * 0.75)
                    .rotation(.degrees(90))
                    .stroke(
                        AngularGradient(
                            colors: [tint.opacity(0.5), tint],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .shadow(color: tint.opacity(0.5), radius: 4)

                // Knob body
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.white.opacity(0.3), .white.opacity(0.1)],
                            center: .center,
                            startRadius: 0,
                            endRadius: size * 0.35
                        )
                    )
                    .overlay(
                        Circle()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.4), .white.opacity(0.1)],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 1
                            )
                    )
                    .frame(width: size * 0.7, height: size * 0.7)

                // Indicator line
                VStack {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(tint)
                        .frame(width: 3, height: size * 0.2)
                        .shadow(color: tint, radius: 4)
                    Spacer()
                }
                .frame(height: size * 0.35)
                .rotationEffect(rotationAngle)
            }
            .frame(width: size, height: size)
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        isDragging = true
                        let center = CGPoint(x: size / 2, y: size / 2)
                        let vector = CGVector(
                            dx: gesture.location.x - center.x,
                            dy: gesture.location.y - center.y
                        )
                        let angle = Angle(radians: atan2(vector.dy, vector.dx))

                        // Convert angle to value
                        var degrees = angle.degrees + 135
                        if degrees < 0 { degrees += 360 }
                        let normalized = min(1, max(0, degrees / 270))
                        value = range.lowerBound + (range.upperBound - range.lowerBound) * normalized
                    }
                    .onEnded { _ in
                        isDragging = false
                    }
            )

            if !label.isEmpty {
                VStack(spacing: 2) {
                    Text(label)
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.6))

                    Text(String(format: "%.1f", value))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(tint)
                }
            }
        }
        .padding()
        .liquidGlass(.regular, cornerRadius: 20)
        .scaleEffect(isDragging ? 1.05 : 1.0)
        .animation(.spring(response: 0.2), value: isDragging)
    }
}

// MARK: - Glass Context Menu

struct LiquidGlassContextMenu<Content: View>: View {
    let items: [(icon: String, label: String, action: () -> Void)]
    let content: Content

    @State private var showMenu = false

    init(
        items: [(icon: String, label: String, action: () -> Void)],
        @ViewBuilder content: () -> Content
    ) {
        self.items = items
        self.content = content()
    }

    var body: some View {
        content
            .onLongPressGesture {
                withAnimation(.spring(response: 0.3)) {
                    showMenu = true
                }
            }
            .overlay(alignment: .bottom) {
                if showMenu {
                    VStack(spacing: 4) {
                        ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    showMenu = false
                                }
                                item.action()
                            } label: {
                                HStack(spacing: 12) {
                                    Image(systemName: item.icon)
                                        .frame(width: 24)
                                    Text(item.label)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.vertical, 12)
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.white)
                        }
                    }
                    .liquidGlass(.frosted, cornerRadius: 16)
                    .padding()
                    .transition(.scale(scale: 0.9).combined(with: .opacity))
                }
            }
            .onTapGesture {
                if showMenu {
                    withAnimation(.spring(response: 0.3)) {
                        showMenu = false
                    }
                }
            }
    }
}

// MARK: - Glass Notification Banner

struct LiquidGlassNotification: View {
    let icon: String
    let title: String
    let message: String?
    let style: Style
    var onDismiss: (() -> Void)?

    enum Style {
        case info, success, warning, error

        var tint: Color {
            switch self {
            case .info: return .cyan
            case .success: return .green
            case .warning: return .orange
            case .error: return .red
            }
        }

        var defaultIcon: String {
            switch self {
            case .info: return "info.circle.fill"
            case .success: return "checkmark.circle.fill"
            case .warning: return "exclamationmark.triangle.fill"
            case .error: return "xmark.circle.fill"
            }
        }
    }

    init(
        icon: String? = nil,
        title: String,
        message: String? = nil,
        style: Style = .info,
        onDismiss: (() -> Void)? = nil
    ) {
        self.icon = icon ?? style.defaultIcon
        self.title = title
        self.message = message
        self.style = style
        self.onDismiss = onDismiss
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(style.tint)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)

                if let message = message {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            Spacer()

            if let onDismiss = onDismiss {
                Button {
                    onDismiss()
                } label: {
                    Image(systemName: "xmark")
                        .foregroundStyle(.white.opacity(0.6))
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .liquidGlass(.tinted, tint: style.tint, cornerRadius: 16)
    }
}

// MARK: - Glass List Row

struct LiquidGlassListRow: View {
    let icon: String?
    let title: String
    let subtitle: String?
    let trailing: String?
    let tint: Color
    var action: (() -> Void)?

    init(
        icon: String? = nil,
        title: String,
        subtitle: String? = nil,
        trailing: String? = nil,
        tint: Color = .white,
        action: (() -> Void)? = nil
    ) {
        self.icon = icon
        self.title = title
        self.subtitle = subtitle
        self.trailing = trailing
        self.tint = tint
        self.action = action
    }

    var body: some View {
        Button {
            action?()
        } label: {
            HStack(spacing: 16) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.title2)
                        .foregroundStyle(tint)
                        .frame(width: 32)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.body)
                        .foregroundStyle(.white)

                    if let subtitle = subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.white.opacity(0.6))
                    }
                }

                Spacer()

                if let trailing = trailing {
                    Text(trailing)
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.6))
                }

                if action != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding()
            .liquidGlass(.regular, cornerRadius: 16, interactive: action != nil)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Glass Stepper

struct LiquidGlassStepper: View {
    @Binding var value: Int
    let range: ClosedRange<Int>
    let label: String
    let tint: Color

    init(
        value: Binding<Int>,
        in range: ClosedRange<Int>,
        label: String = "",
        tint: Color = .cyan
    ) {
        self._value = value
        self.range = range
        self.label = label
        self.tint = tint
    }

    var body: some View {
        HStack {
            if !label.isEmpty {
                Text(label)
                    .foregroundStyle(.white.opacity(0.8))
            }

            Spacer()

            HStack(spacing: 0) {
                Button {
                    if value > range.lowerBound {
                        value -= 1
                    }
                } label: {
                    Image(systemName: "minus")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(value > range.lowerBound ? .white : .white.opacity(0.3))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)

                Text("\(value)")
                    .font(.headline.monospacedDigit())
                    .foregroundStyle(tint)
                    .frame(minWidth: 50)

                Button {
                    if value < range.upperBound {
                        value += 1
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(value < range.upperBound ? .white : .white.opacity(0.3))
                        .frame(width: 44, height: 44)
                }
                .buttonStyle(.plain)
            }
            .liquidGlass(.regular, cornerRadius: 12)
        }
        .padding()
        .liquidGlass(.regular, cornerRadius: 16)
    }
}

// MARK: - Glass Picker

struct LiquidGlassPicker<T: Hashable>: View {
    @Binding var selection: T
    let options: [T]
    let label: String
    let displayName: (T) -> String
    let tint: Color

    @State private var isExpanded = false

    init(
        selection: Binding<T>,
        options: [T],
        label: String = "",
        tint: Color = .cyan,
        displayName: @escaping (T) -> String
    ) {
        self._selection = selection
        self.options = options
        self.label = label
        self.tint = tint
        self.displayName = displayName
    }

    var body: some View {
        VStack(spacing: 0) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.8)) {
                    isExpanded.toggle()
                }
            } label: {
                HStack {
                    if !label.isEmpty {
                        Text(label)
                            .foregroundStyle(.white.opacity(0.6))
                    }

                    Spacer()

                    Text(displayName(selection))
                        .foregroundStyle(tint)

                    Image(systemName: "chevron.down")
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.6))
                        .rotationEffect(.degrees(isExpanded ? 180 : 0))
                }
                .padding()
            }
            .buttonStyle(.plain)

            if isExpanded {
                VStack(spacing: 4) {
                    ForEach(options, id: \.self) { option in
                        Button {
                            withAnimation(.spring(response: 0.3)) {
                                selection = option
                                isExpanded = false
                            }
                        } label: {
                            HStack {
                                Text(displayName(option))
                                    .foregroundStyle(selection == option ? tint : .white)

                                Spacer()

                                if selection == option {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(tint)
                                }
                            }
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                            .background(selection == option ? tint.opacity(0.2) : Color.clear)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
            }
        }
        .liquidGlass(.regular, cornerRadius: 16)
    }
}

// MARK: - Glass Bio Indicator

struct LiquidGlassBioIndicator: View {
    let coherence: Float
    let hrv: Float
    let heartRate: Int
    let compact: Bool

    init(coherence: Float, hrv: Float = 50, heartRate: Int = 72, compact: Bool = false) {
        self.coherence = max(0, min(1, coherence))
        self.hrv = hrv
        self.heartRate = heartRate
        self.compact = compact
    }

    var body: some View {
        HStack(spacing: compact ? 12 : 20) {
            // Coherence ring
            ZStack {
                Circle()
                    .stroke(Color.white.opacity(0.1), lineWidth: compact ? 3 : 4)

                Circle()
                    .trim(from: 0, to: CGFloat(coherence))
                    .stroke(
                        BioReactiveGlassColors.coherenceTint(coherence),
                        style: StrokeStyle(lineWidth: compact ? 3 : 4, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))

                VStack(spacing: 0) {
                    Image(systemName: "heart.fill")
                        .font(compact ? .caption2 : .caption)
                        .foregroundStyle(.red)

                    if !compact {
                        Text("\(Int(coherence * 100))%")
                            .font(.caption2.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.8))
                    }
                }
            }
            .frame(width: compact ? 36 : 50, height: compact ? 36 : 50)

            if !compact {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("HRV")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                        Text("\(Int(hrv)) ms")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.cyan)
                    }

                    HStack {
                        Text("BPM")
                            .font(.caption2)
                            .foregroundStyle(.white.opacity(0.6))
                        Text("\(heartRate)")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.pink)
                    }
                }
            }
        }
        .padding(compact ? 8 : 16)
        .bioReactiveGlass(coherence: coherence)
    }
}

// MARK: - Preview

#Preview("Liquid Glass Components") {
    ZStack {
        AnimatedGlassBackground()

        ScrollView {
            VStack(spacing: 24) {
                Text("Liquid Glass Components")
                    .font(.largeTitle.bold())
                    .foregroundStyle(.white)

                // Icon buttons
                HStack(spacing: 16) {
                    LiquidGlassIconButton(icon: "play.fill", tint: .green) {}
                    LiquidGlassIconButton(icon: "pause.fill", size: .large) {}
                    LiquidGlassIconButton(icon: "stop.fill", tint: .red, size: .small) {}
                }

                // Segmented control
                LiquidGlassSegmentedControl(
                    selection: .constant(1),
                    options: ["Edit", "Mix", "Master"]
                )

                // Search bar
                LiquidGlassSearchBar(text: .constant(""))

                // Progress
                LiquidGlassProgress(progress: 0.65, label: "Rendering")

                // Audio meter
                LiquidGlassAudioMeter(level: 0.7, peak: 0.85)
                    .frame(height: 120)

                // Waveform
                LiquidGlassWaveform(
                    samples: (0..<100).map { _ in Float.random(in: -0.8...0.8) }
                )
                .frame(height: 100)

                // Spectrum
                LiquidGlassSpectrum(
                    bands: (0..<16).map { _ in Float.random(in: 0.1...1.0) }
                )
                .frame(height: 100)

                // Knob
                LiquidGlassKnob(value: .constant(0.65), label: "Volume")

                // Bio indicator
                LiquidGlassBioIndicator(coherence: 0.72, hrv: 55, heartRate: 68)

                // Notification
                LiquidGlassNotification(
                    title: "Export Complete",
                    message: "Your project has been exported successfully",
                    style: .success
                )
            }
            .padding()
        }
    }
    .preferredColorScheme(.dark)
}
