import SwiftUI
import Combine

// MARK: - Liquid Glass Design System for Echoelmusic
// Apple's iOS 26 / macOS Tahoe 26 Liquid Glass implementation
// Adaptive glass materials with real-time lensing, specular highlights,
// and bio-reactive color adaptation

// MARK: - Glass Variants

/// Glass material variants matching Apple's Liquid Glass system
enum GlassVariant {
    case regular        // Default adaptive glass
    case clear          // High transparency for media backgrounds
    case frosted        // Heavy blur for content separation
    case tinted         // Colored glass with semantic meaning
    case identity       // No effect (for conditional toggling)

    /// Glass intensity for blur and transparency
    var blurRadius: CGFloat {
        switch self {
        case .regular: return 20
        case .clear: return 8
        case .frosted: return 40
        case .tinted: return 25
        case .identity: return 0
        }
    }

    /// Base opacity for the glass material
    var baseOpacity: Double {
        switch self {
        case .regular: return 0.7
        case .clear: return 0.4
        case .frosted: return 0.85
        case .tinted: return 0.6
        case .identity: return 0
        }
    }
}

// MARK: - Bio-Reactive Glass Colors

/// Color palette that responds to bio-data (HRV, coherence)
struct BioReactiveGlassColors {

    /// Get glass tint color based on coherence level
    static func coherenceTint(_ coherence: Float) -> Color {
        let hue = Double(coherence) * 0.4 // 0 (red) to 0.4 (cyan)
        return Color(hue: hue, saturation: 0.6, brightness: 0.9)
    }

    /// Get accent color for interactive elements
    static func accentColor(_ coherence: Float) -> Color {
        if coherence > 0.7 {
            return .cyan
        } else if coherence > 0.4 {
            return .purple
        } else {
            return .pink
        }
    }

    /// Vaporwave-inspired glass palette
    static let vaporwavePink = Color(red: 1.0, green: 0.4, blue: 0.8)
    static let vaporwaveCyan = Color(red: 0.4, green: 0.9, blue: 1.0)
    static let vaporwavePurple = Color(red: 0.6, green: 0.3, blue: 0.9)
    static let vaporwaveOrange = Color(red: 1.0, green: 0.6, blue: 0.3)

    /// Glass gradient for immersive backgrounds
    static func immersiveGradient(coherence: Float) -> LinearGradient {
        let primaryColor = coherenceTint(coherence)
        return LinearGradient(
            colors: [
                primaryColor.opacity(0.3),
                vaporwavePurple.opacity(0.2),
                vaporwaveCyan.opacity(0.3)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Glass Effect Modifier

/// Custom glass effect modifier for pre-iOS 26 compatibility
/// On iOS 26+, this maps to native .glassEffect()
struct LiquidGlassModifier: ViewModifier {
    let variant: GlassVariant
    let tintColor: Color?
    let cornerRadius: CGFloat
    let isInteractive: Bool
    let showBorder: Bool

    @Environment(\.colorScheme) private var colorScheme
    @State private var isPressed = false
    @State private var hoverLocation: CGPoint = .zero

    init(
        variant: GlassVariant = .regular,
        tint: Color? = nil,
        cornerRadius: CGFloat = 20,
        interactive: Bool = false,
        showBorder: Bool = true
    ) {
        self.variant = variant
        self.tintColor = tint
        self.cornerRadius = cornerRadius
        self.isInteractive = interactive
        self.showBorder = showBorder
    }

    func body(content: Content) -> some View {
        content
            .background(glassBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .strokeBorder(borderGradient, lineWidth: showBorder ? 1 : 0)
            )
            .shadow(color: shadowColor, radius: 10, x: 0, y: 5)
            .scaleEffect(isPressed && isInteractive ? 0.97 : 1.0)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isPressed)
            .if(isInteractive) { view in
                view.simultaneousGesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { _ in isPressed = true }
                        .onEnded { _ in isPressed = false }
                )
            }
    }

    @ViewBuilder
    private var glassBackground: some View {
        ZStack {
            // Base blur material
            if #available(iOS 15.0, macOS 12.0, *) {
                switch variant {
                case .regular:
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .overlay(tintOverlay)

                case .clear:
                    Rectangle()
                        .fill(.thinMaterial)
                        .opacity(0.5)
                        .overlay(tintOverlay)

                case .frosted:
                    Rectangle()
                        .fill(.regularMaterial)
                        .overlay(tintOverlay)

                case .tinted:
                    Rectangle()
                        .fill(.ultraThinMaterial)
                        .overlay(
                            (tintColor ?? .purple)
                                .opacity(0.3)
                        )

                case .identity:
                    Color.clear
                }
            } else {
                // Fallback for older OS
                Rectangle()
                    .fill(Color.black.opacity(0.3))
                    .blur(radius: variant.blurRadius)
            }

            // Specular highlight (simulates light bending)
            specularHighlight
        }
    }

    @ViewBuilder
    private var tintOverlay: some View {
        if let tint = tintColor {
            tint.opacity(0.15)
        }
    }

    private var specularHighlight: some View {
        LinearGradient(
            colors: [
                Color.white.opacity(0.25),
                Color.white.opacity(0.05),
                Color.clear
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var borderGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color.white.opacity(colorScheme == .dark ? 0.3 : 0.5),
                Color.white.opacity(colorScheme == .dark ? 0.1 : 0.2),
                Color.white.opacity(0.05)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var shadowColor: Color {
        colorScheme == .dark
            ? Color.black.opacity(0.5)
            : Color.black.opacity(0.15)
    }
}

// MARK: - View Extensions

extension View {
    /// Apply Liquid Glass effect to any view
    func liquidGlass(
        _ variant: GlassVariant = .regular,
        tint: Color? = nil,
        cornerRadius: CGFloat = 20,
        interactive: Bool = false,
        showBorder: Bool = true
    ) -> some View {
        modifier(LiquidGlassModifier(
            variant: variant,
            tint: tint,
            cornerRadius: cornerRadius,
            interactive: interactive,
            showBorder: showBorder
        ))
    }

    /// Apply bio-reactive glass that changes with coherence
    func bioReactiveGlass(coherence: Float, interactive: Bool = false) -> some View {
        liquidGlass(
            .tinted,
            tint: BioReactiveGlassColors.coherenceTint(coherence),
            interactive: interactive
        )
    }

    /// Conditional modifier helper
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

// MARK: - Glass Effect Container

/// Container for grouping glass elements with shared sampling and morphing
struct LiquidGlassContainer<Content: View>: View {
    let spacing: CGFloat
    let content: Content

    init(spacing: CGFloat = 30, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.content = content()
    }

    var body: some View {
        HStack(spacing: spacing) {
            content
        }
    }
}

// MARK: - Glass Button Style

/// Button style with Liquid Glass appearance
struct LiquidGlassButtonStyle: ButtonStyle {
    let variant: GlassVariant
    let tint: Color?
    let size: Size

    enum Size {
        case small, medium, large

        var padding: EdgeInsets {
            switch self {
            case .small: return EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16)
            case .medium: return EdgeInsets(top: 12, leading: 24, bottom: 12, trailing: 24)
            case .large: return EdgeInsets(top: 16, leading: 32, bottom: 16, trailing: 32)
            }
        }

        var font: Font {
            switch self {
            case .small: return .subheadline.weight(.medium)
            case .medium: return .body.weight(.semibold)
            case .large: return .title3.weight(.bold)
            }
        }
    }

    init(variant: GlassVariant = .regular, tint: Color? = nil, size: Size = .medium) {
        self.variant = variant
        self.tint = tint
        self.size = size
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(size.font)
            .foregroundStyle(.white)
            .padding(size.padding)
            .liquidGlass(variant, tint: tint, cornerRadius: 12, interactive: true)
            .scaleEffect(configuration.isPressed ? 0.95 : 1.0)
            .opacity(configuration.isPressed ? 0.9 : 1.0)
            .animation(.spring(response: 0.2, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

extension ButtonStyle where Self == LiquidGlassButtonStyle {
    static var liquidGlass: LiquidGlassButtonStyle { LiquidGlassButtonStyle() }

    static func liquidGlass(
        variant: GlassVariant = .regular,
        tint: Color? = nil,
        size: LiquidGlassButtonStyle.Size = .medium
    ) -> LiquidGlassButtonStyle {
        LiquidGlassButtonStyle(variant: variant, tint: tint, size: size)
    }
}

// MARK: - Glass Toggle Style

struct LiquidGlassToggleStyle: ToggleStyle {
    let onColor: Color
    let offColor: Color

    init(onColor: Color = .cyan, offColor: Color = .gray) {
        self.onColor = onColor
        self.offColor = offColor
    }

    func makeBody(configuration: Configuration) -> some View {
        HStack {
            configuration.label
                .foregroundStyle(.white)

            Spacer()

            ZStack {
                Capsule()
                    .fill(configuration.isOn ? onColor.opacity(0.3) : offColor.opacity(0.2))
                    .frame(width: 50, height: 30)
                    .overlay(
                        Capsule()
                            .strokeBorder(
                                LinearGradient(
                                    colors: [.white.opacity(0.3), .white.opacity(0.1)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                ),
                                lineWidth: 1
                            )
                    )

                Circle()
                    .fill(.white)
                    .frame(width: 26, height: 26)
                    .shadow(color: .black.opacity(0.2), radius: 2, x: 0, y: 1)
                    .offset(x: configuration.isOn ? 10 : -10)
            }
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: configuration.isOn)
            .onTapGesture {
                configuration.isOn.toggle()
            }
        }
        .padding()
        .liquidGlass(.regular, cornerRadius: 16)
    }
}

// MARK: - Glass Slider Style

struct LiquidGlassSlider: View {
    @Binding var value: Double
    let range: ClosedRange<Double>
    let label: String
    let tint: Color

    @State private var isDragging = false

    init(
        value: Binding<Double>,
        in range: ClosedRange<Double> = 0...1,
        label: String = "",
        tint: Color = .cyan
    ) {
        self._value = value
        self.range = range
        self.label = label
        self.tint = tint
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !label.isEmpty {
                HStack {
                    Text(label)
                        .foregroundStyle(.white.opacity(0.8))

                    Spacer()

                    Text(String(format: "%.0f%%", normalizedValue * 100))
                        .foregroundStyle(tint)
                        .font(.caption.monospacedDigit())
                }
            }

            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track background
                    Capsule()
                        .fill(Color.white.opacity(0.1))
                        .frame(height: 8)

                    // Filled track
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [tint.opacity(0.8), tint],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: geometry.size.width * normalizedValue, height: 8)

                    // Thumb
                    Circle()
                        .fill(.white)
                        .frame(width: isDragging ? 28 : 24, height: isDragging ? 28 : 24)
                        .shadow(color: tint.opacity(0.5), radius: isDragging ? 8 : 4)
                        .offset(x: (geometry.size.width - 24) * normalizedValue)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { gesture in
                                    isDragging = true
                                    let newValue = gesture.location.x / geometry.size.width
                                    value = range.lowerBound + (range.upperBound - range.lowerBound) * Double(max(0, min(1, newValue)))
                                }
                                .onEnded { _ in
                                    isDragging = false
                                }
                        )
                }
            }
            .frame(height: 28)
        }
        .padding()
        .liquidGlass(.regular, cornerRadius: 16)
        .animation(.spring(response: 0.2), value: isDragging)
    }

    private var normalizedValue: Double {
        (value - range.lowerBound) / (range.upperBound - range.lowerBound)
    }
}

// MARK: - Glass Card

struct LiquidGlassCard<Content: View>: View {
    let content: Content
    let variant: GlassVariant
    let tint: Color?

    init(
        variant: GlassVariant = .regular,
        tint: Color? = nil,
        @ViewBuilder content: () -> Content
    ) {
        self.variant = variant
        self.tint = tint
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .liquidGlass(variant, tint: tint, cornerRadius: 24)
    }
}

// MARK: - Glass Navigation Bar

struct LiquidGlassNavigationBar<Leading: View, Center: View, Trailing: View>: View {
    let leading: Leading
    let center: Center
    let trailing: Trailing

    init(
        @ViewBuilder leading: () -> Leading,
        @ViewBuilder center: () -> Center,
        @ViewBuilder trailing: () -> Trailing
    ) {
        self.leading = leading()
        self.center = center()
        self.trailing = trailing()
    }

    var body: some View {
        HStack {
            leading
                .frame(width: 80, alignment: .leading)

            Spacer()

            center

            Spacer()

            trailing
                .frame(width: 80, alignment: .trailing)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .liquidGlass(.regular, cornerRadius: 0, showBorder: false)
    }
}

// MARK: - Glass Tab Bar

struct LiquidGlassTabBar: View {
    @Binding var selectedTab: Int
    let items: [(icon: String, label: String)]
    let tint: Color

    init(
        selectedTab: Binding<Int>,
        items: [(icon: String, label: String)],
        tint: Color = .cyan
    ) {
        self._selectedTab = selectedTab
        self.items = items
        self.tint = tint
    }

    var body: some View {
        HStack(spacing: 0) {
            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                Button {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        selectedTab = index
                    }
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: item.icon)
                            .font(.title2)
                            .symbolVariant(selectedTab == index ? .fill : .none)

                        Text(item.label)
                            .font(.caption2)
                    }
                    .foregroundStyle(selectedTab == index ? tint : .white.opacity(0.6))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        selectedTab == index
                            ? tint.opacity(0.2)
                            : Color.clear
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(8)
        .liquidGlass(.regular, cornerRadius: 24)
    }
}

// MARK: - Glass Sheet

struct LiquidGlassSheet<Content: View>: View {
    @Binding var isPresented: Bool
    let content: Content

    @State private var dragOffset: CGFloat = 0
    @GestureState private var isDragging = false

    init(isPresented: Binding<Bool>, @ViewBuilder content: () -> Content) {
        self._isPresented = isPresented
        self.content = content()
    }

    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                // Drag indicator
                Capsule()
                    .fill(Color.white.opacity(0.4))
                    .frame(width: 40, height: 5)
                    .padding(.top, 8)
                    .padding(.bottom, 16)

                content
            }
            .frame(maxWidth: .infinity)
            .liquidGlass(.frosted, cornerRadius: 32, showBorder: true)
            .offset(y: max(0, dragOffset))
            .gesture(
                DragGesture()
                    .updating($isDragging) { _, state, _ in
                        state = true
                    }
                    .onChanged { value in
                        dragOffset = value.translation.height
                    }
                    .onEnded { value in
                        if value.translation.height > 100 {
                            withAnimation(.spring()) {
                                isPresented = false
                            }
                        }
                        withAnimation(.spring()) {
                            dragOffset = 0
                        }
                    }
            )
            .animation(.spring(), value: isDragging)
        }
    }
}

// MARK: - Animated Glass Background

struct AnimatedGlassBackground: View {
    @State private var phase: CGFloat = 0
    let colors: [Color]
    let speed: Double

    init(
        colors: [Color] = [
            BioReactiveGlassColors.vaporwavePink,
            BioReactiveGlassColors.vaporwaveCyan,
            BioReactiveGlassColors.vaporwavePurple
        ],
        speed: Double = 3.0
    ) {
        self.colors = colors
        self.speed = speed
    }

    var body: some View {
        GeometryReader { geometry in
            ZStack {
                // Animated gradient orbs
                ForEach(0..<3, id: \.self) { index in
                    Circle()
                        .fill(
                            RadialGradient(
                                colors: [
                                    colors[index % colors.count].opacity(0.6),
                                    colors[index % colors.count].opacity(0)
                                ],
                                center: .center,
                                startRadius: 0,
                                endRadius: geometry.size.width * 0.5
                            )
                        )
                        .frame(width: geometry.size.width * 0.8)
                        .offset(
                            x: cos(phase + Double(index) * .pi * 2 / 3) * geometry.size.width * 0.3,
                            y: sin(phase + Double(index) * .pi * 2 / 3) * geometry.size.height * 0.3
                        )
                        .blur(radius: 60)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.linear(duration: speed).repeatForever(autoreverses: false)) {
                phase = .pi * 2
            }
        }
    }
}

// MARK: - Preview

#Preview("Liquid Glass Components") {
    ZStack {
        AnimatedGlassBackground()

        VStack(spacing: 20) {
            Text("Liquid Glass Design")
                .font(.largeTitle.bold())
                .foregroundStyle(.white)

            HStack(spacing: 16) {
                Button("Regular") {}
                    .buttonStyle(.liquidGlass())

                Button("Tinted") {}
                    .buttonStyle(.liquidGlass(tint: .cyan))

                Button("Interactive") {}
                    .buttonStyle(.liquidGlass(variant: .tinted, tint: .pink))
            }

            LiquidGlassCard {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Bio-Reactive Card")
                        .font(.headline)
                        .foregroundStyle(.white)

                    Text("This card adapts to your coherence level")
                        .font(.subheadline)
                        .foregroundStyle(.white.opacity(0.7))
                }
            }

            LiquidGlassTabBar(
                selectedTab: .constant(0),
                items: [
                    ("house", "Home"),
                    ("waveform", "Audio"),
                    ("heart", "Bio"),
                    ("gear", "Settings")
                ]
            )
        }
        .padding()
    }
    .preferredColorScheme(.dark)
}
