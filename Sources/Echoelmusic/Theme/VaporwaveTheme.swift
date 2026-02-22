import SwiftUI

// MARK: - Vaporwave Palace Theme
// "Flüssiges Licht für deine Musik"
// Design synchronized with echoelmusic.com website

/// The Vaporwave Palace color palette
/// Inspired by: 80s/90s aesthetics, neon lights, sunset gradients, liquid light
struct VaporwaveColors {

    // MARK: - Primary Neon Colors (exact website hex values)

    /// Hot pink - primary accent (#FF1494)
    static let neonPink = Color(red: 1.0, green: 0.08, blue: 0.58)

    /// Electric cyan - secondary accent (#00FFFF)
    static let neonCyan = Color(red: 0.0, green: 1.0, blue: 1.0)

    /// Deep purple - tertiary (#9933FF)
    static let neonPurple = Color(red: 0.6, green: 0.2, blue: 1.0)

    /// Soft lavender (#CC99FF)
    static let lavender = Color(red: 0.8, green: 0.6, blue: 1.0)

    /// Warm coral/orange (#FF7F66)
    static let coral = Color(red: 1.0, green: 0.5, blue: 0.4)

    // MARK: - Background Colors

    /// Deep space black (#050510)
    static let deepBlack = Color(red: 0.02, green: 0.02, blue: 0.0625)

    /// Midnight blue (#0D0D26)
    static let midnightBlue = Color(red: 0.05, green: 0.05, blue: 0.15)

    /// Dark purple (#1A0D33)
    static let darkPurple = Color(red: 0.1, green: 0.05, blue: 0.2)

    /// Sunset orange (for gradients) (#FF6633)
    static let sunsetOrange = Color(red: 1.0, green: 0.4, blue: 0.2)

    /// Sunset pink (#FF3380)
    static let sunsetPink = Color(red: 1.0, green: 0.2, blue: 0.5)

    // MARK: - Bio-Reactive Colors (website CSS variables)

    /// Low coherence - stressed (#FF4D4D)
    static let coherenceLow = Color(red: 1.0, green: 0.3, blue: 0.3)

    /// Medium coherence - transitioning (#FFCC33)
    static let coherenceMedium = Color(red: 1.0, green: 0.8, blue: 0.2)

    /// High coherence - flow state (#33FFCC)
    static let coherenceHigh = Color(red: 0.2, green: 1.0, blue: 0.8)

    // MARK: - Text Colors

    /// Primary text - bright white
    static let textPrimary = Color.white

    /// Secondary text - soft white (rgba 255,255,255,0.85)
    static let textSecondary = Color.white.opacity(0.85)

    /// Tertiary/muted text — WCAG AA compliant (4.5:1 on dark bg)
    static let textTertiary = Color.white.opacity(0.65)

    // MARK: - Glass Effect Colors (website CSS)

    /// Glass background (rgba 255,255,255,0.08)
    static let glassBg = Color.white.opacity(0.08)

    /// Glass border (rgba 255,255,255,0.15)
    static let glassBorder = Color.white.opacity(0.15)

    /// Glass border active state (rgba 255,20,148,0.5)
    static let glassBorderActive = neonPink.opacity(0.5)

    // MARK: - Functional Colors

    /// Recording active
    static let recordingActive = neonPink

    /// Success/connected
    static let success = neonCyan

    /// Warning
    static let warning = coral

    /// Heart rate
    static let heartRate = Color(red: 1.0, green: 0.3, blue: 0.4)

    /// HRV
    static let hrv = Color(red: 0.3, green: 1.0, blue: 0.6)
}

// MARK: - Gradients

struct VaporwaveGradients {

    /// Main background gradient (deep space)
    static let background = LinearGradient(
        gradient: Gradient(colors: [
            VaporwaveColors.midnightBlue,
            VaporwaveColors.darkPurple
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Sunset gradient (for hero sections)
    static let sunset = LinearGradient(
        gradient: Gradient(colors: [
            VaporwaveColors.neonPurple,
            VaporwaveColors.sunsetPink,
            VaporwaveColors.sunsetOrange
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Neon gradient (pink to cyan)
    static let neon = LinearGradient(
        gradient: Gradient(colors: [
            VaporwaveColors.neonPink,
            VaporwaveColors.neonPurple,
            VaporwaveColors.neonCyan
        ]),
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Coherence gradient (red → yellow → green)
    static let coherence = LinearGradient(
        gradient: Gradient(colors: [
            VaporwaveColors.coherenceLow,
            VaporwaveColors.coherenceMedium,
            VaporwaveColors.coherenceHigh
        ]),
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Card background (glass effect)
    static let glassCard = LinearGradient(
        gradient: Gradient(colors: [
            Color.white.opacity(0.1),
            Color.white.opacity(0.05)
        ]),
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    /// Card accent bar gradient (top border on hover)
    static let cardAccent = LinearGradient(
        gradient: Gradient(colors: [
            VaporwaveColors.neonPink,
            VaporwaveColors.neonPurple,
            VaporwaveColors.neonCyan
        ]),
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Animated blob gradient (for background effects)
    static func blobGradient(at position: UnitPoint) -> RadialGradient {
        RadialGradient(
            gradient: Gradient(colors: [
                VaporwaveColors.neonPurple.opacity(0.15),
                Color.clear
            ]),
            center: position,
            startRadius: 0,
            endRadius: 300
        )
    }
}

// MARK: - Animated Background Components

/// Vaporwave animated gradient background (matches website design)
struct VaporwaveAnimatedBackground: View {
    @State private var animationPhase: CGFloat = 0

    var body: some View {
        ZStack {
            // Base gradient
            LinearGradient(
                colors: [
                    VaporwaveColors.deepBlack,
                    VaporwaveColors.midnightBlue,
                    VaporwaveColors.darkPurple
                ],
                startPoint: .top,
                endPoint: .bottom
            )

            // Animated blob 1 (purple, top-left)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [VaporwaveColors.neonPurple.opacity(0.15), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 250
                    )
                )
                .frame(width: 500, height: 500)
                .offset(x: -150 + sin(animationPhase) * 30, y: -200 + cos(animationPhase) * 20)
                .blur(radius: 60)

            // Animated blob 2 (pink, bottom-right)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [VaporwaveColors.neonPink.opacity(0.12), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: 150 + cos(animationPhase * 0.8) * 25, y: 200 + sin(animationPhase * 0.8) * 30)
                .blur(radius: 50)

            // Animated blob 3 (cyan, center)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [VaporwaveColors.neonCyan.opacity(0.08), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 300
                    )
                )
                .frame(width: 600, height: 600)
                .offset(x: sin(animationPhase * 0.6) * 40, y: cos(animationPhase * 0.6) * 35)
                .blur(radius: 80)
        }
        .ignoresSafeArea()
        .onAppear {
            withAnimation(.easeInOut(duration: 10).repeatForever(autoreverses: true)) {
                animationPhase = .pi * 2
            }
        }
    }
}

/// Grid pattern overlay (matches website design)
struct VaporwaveGridOverlay: View {
    let gridSize: CGFloat
    let lineOpacity: Double

    init(gridSize: CGFloat = 60, lineOpacity: Double = 0.03) {
        self.gridSize = gridSize
        self.lineOpacity = lineOpacity
    }

    var body: some View {
        GeometryReader { geometry in
            Canvas { context, size in
                let color = Color(red: 1.0, green: 0.08, blue: 0.58).opacity(lineOpacity)

                // Vertical lines
                for x in stride(from: 0, through: size.width, by: gridSize) {
                    var path = Path()
                    path.move(to: CGPoint(x: x, y: 0))
                    path.addLine(to: CGPoint(x: x, y: size.height))
                    context.stroke(path, with: .color(color), lineWidth: 1)
                }

                // Horizontal lines
                for y in stride(from: 0, through: size.height, by: gridSize) {
                    var path = Path()
                    path.move(to: CGPoint(x: 0, y: y))
                    path.addLine(to: CGPoint(x: size.width, y: y))
                    context.stroke(path, with: .color(color), lineWidth: 1)
                }
            }
        }
        .opacity(0.5)
        .ignoresSafeArea()
        .allowsHitTesting(false)
    }
}

/// Complete vaporwave background with gradient and grid
struct VaporwaveFullBackground: View {
    let showGrid: Bool
    let animated: Bool

    init(showGrid: Bool = true, animated: Bool = true) {
        self.showGrid = showGrid
        self.animated = animated
    }

    var body: some View {
        ZStack {
            if animated {
                VaporwaveAnimatedBackground()
            } else {
                VaporwaveGradients.background
            }

            if showGrid {
                VaporwaveGridOverlay()
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - View Modifiers

struct NeonGlow: ViewModifier {
    let color: Color
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.8), radius: radius / 2)
            .shadow(color: color.opacity(0.5), radius: radius)
            .shadow(color: color.opacity(0.3), radius: radius * 2)
    }
}

struct GlassCard: ViewModifier {
    let isActive: Bool
    let showAccentBar: Bool
    let cornerRadius: CGFloat

    init(isActive: Bool = false, showAccentBar: Bool = false, cornerRadius: CGFloat = 20) {
        self.isActive = isActive
        self.showAccentBar = showAccentBar
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(VaporwaveColors.glassBg)
                    .background(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .fill(Color.black.opacity(0.3))
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .stroke(
                        isActive ? VaporwaveColors.glassBorderActive : VaporwaveColors.glassBorder,
                        lineWidth: 1
                    )
            )
            .overlay(alignment: .top) {
                if showAccentBar {
                    VaporwaveGradients.cardAccent
                        .frame(height: 3)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                }
            }
            .shadow(
                color: isActive ? VaporwaveColors.neonPink.opacity(0.15) : .clear,
                radius: 20,
                y: 10
            )
    }
}

struct VaporwaveButton: ViewModifier {
    let isActive: Bool
    let activeColor: Color

    func body(content: Content) -> some View {
        content
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(
                Capsule()
                    .fill(isActive ? activeColor : Color.white.opacity(0.1))
            )
            .overlay(
                Capsule()
                    .stroke(isActive ? activeColor : Color.white.opacity(0.3), lineWidth: 1)
            )
            .shadow(color: isActive ? activeColor.opacity(0.5) : .clear, radius: 10)
    }
}

// MARK: - View Extensions

extension View {
    /// Apply neon glow effect
    func neonGlow(color: Color = VaporwaveColors.neonPink, radius: CGFloat = 15) -> some View {
        modifier(NeonGlow(color: color, radius: radius))
    }

    /// Apply glass card background
    func glassCard(isActive: Bool = false, showAccentBar: Bool = false, cornerRadius: CGFloat = 20) -> some View {
        modifier(GlassCard(isActive: isActive, showAccentBar: showAccentBar, cornerRadius: cornerRadius))
    }

    /// Apply vaporwave button style
    func vaporwaveButton(isActive: Bool = false, activeColor: Color = VaporwaveColors.neonPink) -> some View {
        modifier(VaporwaveButton(isActive: isActive, activeColor: activeColor))
    }

    /// Apply simple vaporwave background gradient
    func vaporwaveBackground() -> some View {
        self.background(VaporwaveGradients.background.ignoresSafeArea())
    }

    /// Apply full vaporwave background with animated blobs and grid
    func vaporwaveFullBackground(showGrid: Bool = true, animated: Bool = true) -> some View {
        self.background(VaporwaveFullBackground(showGrid: showGrid, animated: animated))
    }
}

// MARK: - Typography

struct VaporwaveTypography {

    /// Hero title (app name)
    static func heroTitle() -> Font {
        .system(size: 48, weight: .bold, design: .rounded)
    }

    /// Section title
    static func sectionTitle() -> Font {
        .system(size: 24, weight: .semibold, design: .rounded)
    }

    /// Body text
    static func body() -> Font {
        .system(size: 16, weight: .regular, design: .default)
    }

    /// Caption
    static func caption() -> Font {
        .system(size: 12, weight: .light, design: .default)
    }

    /// Monospace for data
    static func data() -> Font {
        .system(size: 36, weight: .light, design: .monospaced)
    }

    /// Small monospace
    static func dataSmall() -> Font {
        .system(size: 24, weight: .light, design: .monospaced)
    }

    /// Label
    static func label() -> Font {
        .system(size: 10, weight: .medium, design: .default)
    }
}

// MARK: - Spacing

struct VaporwaveSpacing {
    static let xs: CGFloat = 4
    static let sm: CGFloat = 8
    static let md: CGFloat = 16
    static let lg: CGFloat = 24
    static let xl: CGFloat = 32
    static let xxl: CGFloat = 48
}

// MARK: - Animation

struct VaporwaveAnimation {
    /// Smooth spring animation
    static let smooth = Animation.spring(response: 0.4, dampingFraction: 0.8)

    /// Quick response
    static let quick = Animation.easeOut(duration: 0.2)

    /// Slow breathing animation
    static let breathing = Animation.easeInOut(duration: 4.0).repeatForever(autoreverses: true)

    /// Pulse animation
    static let pulse = Animation.easeInOut(duration: 1.0).repeatForever(autoreverses: true)

    /// Glow animation
    static let glow = Animation.easeInOut(duration: 2.0).repeatForever(autoreverses: true)

    /// Returns nil animation if reduce motion is enabled, otherwise returns the provided animation
    /// Use this for accessibility compliance
    static func reduced(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }

    /// Smooth animation that respects reduced motion preference
    static func smoothReduced(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : smooth
    }
}

// MARK: - Preview Components

struct VaporwavePreview: View {
    var body: some View {
        ZStack {
            VaporwaveGradients.background
                .ignoresSafeArea()

            VStack(spacing: VaporwaveSpacing.lg) {
                Text("ECHOELMUSIC")
                    .font(VaporwaveTypography.heroTitle())
                    .foregroundColor(VaporwaveColors.textPrimary)
                    .neonGlow(color: VaporwaveColors.neonPink)

                Text("Flüssiges Licht")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textSecondary)
                    .tracking(4)

                HStack(spacing: VaporwaveSpacing.xl) {
                    VStack {
                        Text("72")
                            .font(VaporwaveTypography.data())
                            .foregroundColor(VaporwaveColors.heartRate)
                        Text("BPM")
                            .font(VaporwaveTypography.label())
                            .foregroundColor(VaporwaveColors.textTertiary)
                    }

                    VStack {
                        Text("68")
                            .font(VaporwaveTypography.data())
                            .foregroundColor(VaporwaveColors.hrv)
                        Text("HRV")
                            .font(VaporwaveTypography.label())
                            .foregroundColor(VaporwaveColors.textTertiary)
                    }

                    VStack {
                        Text("85")
                            .font(VaporwaveTypography.data())
                            .foregroundColor(VaporwaveColors.coherenceHigh)
                        Text("FLOW")
                            .font(VaporwaveTypography.label())
                            .foregroundColor(VaporwaveColors.textTertiary)
                    }
                }
                .padding(VaporwaveSpacing.lg)
                .glassCard()

                HStack(spacing: VaporwaveSpacing.md) {
                    Text("Focus")
                        .vaporwaveButton(isActive: true, activeColor: VaporwaveColors.neonCyan)

                    Text("Create")
                        .vaporwaveButton(isActive: false)

                    Text("Heal")
                        .vaporwaveButton(isActive: false)
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    VaporwavePreview()
}
#endif


// MARK: - Reusable UI Components

/// Data display component for showing metrics with label
struct VaporwaveDataDisplay: View {
    let value: String
    let label: String
    let color: Color
    let showGlow: Bool

    init(value: String, label: String, color: Color = VaporwaveColors.neonCyan, showGlow: Bool = true) {
        self.value = value
        self.label = label
        self.color = color
        self.showGlow = showGlow
    }

    var body: some View {
        VStack(spacing: VaporwaveSpacing.xs) {
            Text(value)
                .font(VaporwaveTypography.data())
                .foregroundColor(color)
                .neonGlow(color: showGlow ? color : .clear, radius: 8)

            Text(label)
                .font(VaporwaveTypography.label())
                .foregroundColor(VaporwaveColors.textTertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

/// Status indicator with pulse animation
struct VaporwaveStatusIndicator: View {
    let isActive: Bool
    let activeColor: Color
    let inactiveColor: Color
    @State private var isPulsing = false

    init(isActive: Bool, activeColor: Color = VaporwaveColors.success, inactiveColor: Color = VaporwaveColors.textTertiary) {
        self.isActive = isActive
        self.activeColor = activeColor
        self.inactiveColor = inactiveColor
    }

    var body: some View {
        Circle()
            .fill(isActive ? activeColor : inactiveColor)
            .frame(width: 10, height: 10)
            .scaleEffect(isActive && isPulsing ? 1.3 : 1.0)
            .shadow(color: isActive ? activeColor.opacity(0.5) : .clear, radius: 5)
            .onAppear {
                if isActive {
                    withAnimation(VaporwaveAnimation.pulse) {
                        isPulsing = true
                    }
                }
            }
            .accessibilityLabel(isActive ? "Active" : "Inactive")
    }
}

/// Circular progress indicator for coherence/progress
struct VaporwaveProgressRing: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat
    let size: CGFloat

    init(progress: Double, color: Color = VaporwaveColors.coherenceHigh, lineWidth: CGFloat = 6, size: CGFloat = 60) {
        self.progress = progress
        self.color = color
        self.lineWidth = lineWidth
        self.size = size
    }

    var body: some View {
        ZStack {
            // Background ring
            Circle()
                .stroke(VaporwaveColors.textTertiary.opacity(0.2), lineWidth: lineWidth)
                .frame(width: size, height: size)

            // Progress ring
            Circle()
                .trim(from: 0, to: min(progress, 1.0))
                .stroke(
                    color,
                    style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                )
                .frame(width: size, height: size)
                .rotationEffect(.degrees(-90))
                .animation(.easeInOut(duration: 1.0), value: progress)
        }
        .accessibilityLabel("Progress: \(Int(progress * 100)) percent")
    }
}

/// Unified control button component
struct VaporwaveControlButton: View {
    let icon: String
    let label: String
    let isActive: Bool
    let color: Color
    let size: CGFloat
    let action: () -> Void

    init(
        icon: String,
        label: String,
        isActive: Bool = false,
        color: Color = VaporwaveColors.neonCyan,
        size: CGFloat = 60,
        action: @escaping () -> Void
    ) {
        self.icon = icon
        self.label = label
        self.isActive = isActive
        self.color = color
        self.size = size
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            VStack(spacing: VaporwaveSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(isActive ? color.opacity(0.3) : VaporwaveColors.deepBlack.opacity(0.5))
                        .frame(width: size, height: size)
                        .overlay(
                            Circle()
                                .stroke(isActive ? color : VaporwaveColors.textTertiary, lineWidth: 1)
                        )

                    Image(systemName: icon)
                        .font(.system(size: size * 0.45))
                        .foregroundColor(isActive ? color : VaporwaveColors.textSecondary)
                }
                .neonGlow(color: isActive ? color : .clear, radius: 10)

                Text(label)
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textSecondary)
            }
        }
        .accessibilityLabel("\(label), \(isActive ? "active" : "inactive")")
        .accessibilityHint("Double tap to toggle")
    }
}

/// Info row component for settings/device info
struct VaporwaveInfoRow: View {
    let icon: String
    let title: String
    let value: String
    let valueColor: Color

    init(icon: String, title: String, value: String, valueColor: Color = VaporwaveColors.textSecondary) {
        self.icon = icon
        self.title = title
        self.value = value
        self.valueColor = valueColor
    }

    var body: some View {
        HStack(spacing: VaporwaveSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(VaporwaveColors.neonCyan)
                .frame(width: 24)

            Text(title)
                .font(VaporwaveTypography.body())
                .foregroundColor(VaporwaveColors.textPrimary)

            Spacer()

            Text(value)
                .font(VaporwaveTypography.caption())
                .foregroundColor(valueColor)
        }
        .padding(VaporwaveSpacing.md)
        .glassCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

/// Section header component
struct VaporwaveSectionHeader: View {
    let title: String
    let icon: String?

    init(_ title: String, icon: String? = nil) {
        self.title = title
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: VaporwaveSpacing.sm) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(VaporwaveColors.neonCyan)
            }

            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(VaporwaveColors.textTertiary)
                .tracking(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// Toggle row with vaporwave styling
struct VaporwaveToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    let tintColor: Color

    init(title: String, subtitle: String? = nil, isOn: Binding<Bool>, tintColor: Color = VaporwaveColors.neonCyan) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
        self.tintColor = tintColor
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(VaporwaveTypography.body())
                    .foregroundColor(VaporwaveColors.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(VaporwaveTypography.caption())
                        .foregroundColor(VaporwaveColors.textTertiary)
                }
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: tintColor))
        .padding(VaporwaveSpacing.md)
        .glassCard()
    }
}

/// Status badge with pulsing dot (matches website hero-badge)
struct VaporwaveBadge: View {
    let text: String
    let dotColor: Color
    let showPulse: Bool

    @State private var isPulsing = false

    init(_ text: String, dotColor: Color = VaporwaveColors.coherenceHigh, showPulse: Bool = true) {
        self.text = text
        self.dotColor = dotColor
        self.showPulse = showPulse
    }

    var body: some View {
        HStack(spacing: VaporwaveSpacing.sm) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)
                .scaleEffect(isPulsing ? 1.2 : 1.0)
                .opacity(isPulsing ? 0.7 : 1.0)

            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(VaporwaveColors.textSecondary)
        }
        .padding(.horizontal, VaporwaveSpacing.md)
        .padding(.vertical, VaporwaveSpacing.xs)
        .background(VaporwaveColors.glassBg)
        .overlay(
            Capsule()
                .stroke(VaporwaveColors.glassBorder, lineWidth: 1)
        )
        .clipShape(Capsule())
        .onAppear {
            if showPulse {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    isPulsing = true
                }
            }
        }
    }
}

/// Feature tag component (matches website feature-tag)
struct VaporwaveTag: View {
    let text: String
    let color: Color

    init(_ text: String, color: Color = VaporwaveColors.neonCyan) {
        self.text = text
        self.color = color
    }

    var body: some View {
        Text(text)
            .font(.system(size: 11, weight: .medium))
            .foregroundColor(color)
            .padding(.horizontal, 10)
            .padding(.vertical, 4)
            .background(color.opacity(0.1))
            .overlay(
                Capsule()
                    .stroke(color.opacity(0.2), lineWidth: 1)
            )
            .clipShape(Capsule())
    }
}

/// Section label component (matches website section-label)
struct VaporwaveSectionLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(VaporwaveColors.neonPink)
            .tracking(1)
            .padding(.horizontal, VaporwaveSpacing.md)
            .padding(.vertical, VaporwaveSpacing.xs)
            .background(
                LinearGradient(
                    colors: [
                        VaporwaveColors.neonPink.opacity(0.2),
                        VaporwaveColors.neonPurple.opacity(0.2)
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .overlay(
                Capsule()
                    .stroke(VaporwaveColors.neonPink, lineWidth: 1)
            )
            .clipShape(Capsule())
    }
}

/// Stat card component (matches website stat-card)
struct VaporwaveStatCard: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: VaporwaveSpacing.xs) {
            Text(value)
                .font(.system(size: 36, weight: .heavy))
                .foregroundStyle(VaporwaveGradients.neon)

            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(VaporwaveColors.textTertiary)
        }
        .padding(VaporwaveSpacing.xl)
        .frame(maxWidth: .infinity)
        .glassCard()
    }
}

/// Primary CTA button (matches website btn-primary)
struct VaporwavePrimaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    @State private var isHovered = false

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: VaporwaveSpacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(
                LinearGradient(
                    colors: [VaporwaveColors.neonPink, VaporwaveColors.neonPurple],
                    startPoint: .leading,
                    endPoint: .trailing
                )
            )
            .clipShape(Capsule())
            .shadow(
                color: isHovered ? VaporwaveColors.neonPink.opacity(0.5) : .clear,
                radius: 20
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        #if !os(watchOS)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        #endif
    }
}

/// Secondary button (matches website btn-secondary)
struct VaporwaveSecondaryButton: View {
    let title: String
    let icon: String?
    let action: () -> Void

    @State private var isHovered = false

    init(_ title: String, icon: String? = nil, action: @escaping () -> Void) {
        self.title = title
        self.icon = icon
        self.action = action
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: VaporwaveSpacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(VaporwaveColors.textPrimary)
            .padding(.horizontal, 32)
            .padding(.vertical, 16)
            .background(VaporwaveColors.glassBg)
            .overlay(
                Capsule()
                    .stroke(
                        isHovered ? VaporwaveColors.neonCyan : VaporwaveColors.glassBorder,
                        lineWidth: 1
                    )
            )
            .clipShape(Capsule())
            .shadow(
                color: isHovered ? VaporwaveColors.neonCyan.opacity(0.3) : .clear,
                radius: 15
            )
        }
        .buttonStyle(.plain)
        #if !os(watchOS)
        .onHover { hovering in
            withAnimation(.easeOut(duration: 0.2)) {
                isHovered = hovering
            }
        }
        #endif
    }
}

/// Workspace card (matches website workspace-card)
struct VaporwaveWorkspaceCard: View {
    let icon: String
    let title: String
    let description: String
    let badge: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: VaporwaveSpacing.md) {
                Text(icon)
                    .font(.system(size: 48))

                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(VaporwaveColors.textPrimary)

                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(VaporwaveColors.textSecondary)
                    .multilineTextAlignment(.center)

                Text(badge)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(.white)
                    .padding(.horizontal, VaporwaveSpacing.md)
                    .padding(.vertical, VaporwaveSpacing.xs)
                    .background(VaporwaveGradients.neon)
                    .clipShape(Capsule())
            }
            .padding(VaporwaveSpacing.xl)
            .frame(maxWidth: .infinity)
            .glassCard(isActive: isHovered)
            .scaleEffect(isHovered ? 1.02 : 1.0)
            .offset(y: isHovered ? -4 : 0)
        }
        .buttonStyle(.plain)
        #if !os(watchOS)
        .onHover { hovering in
            withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                isHovered = hovering
            }
        }
        #endif
    }
}

/// Empty state placeholder
struct VaporwaveEmptyState: View {
    let icon: String
    let title: String
    let message: String
    let actionTitle: String?
    let action: (() -> Void)?

    init(icon: String, title: String, message: String, actionTitle: String? = nil, action: (() -> Void)? = nil) {
        self.icon = icon
        self.title = title
        self.message = message
        self.actionTitle = actionTitle
        self.action = action
    }

    var body: some View {
        VStack(spacing: VaporwaveSpacing.lg) {
            ZStack {
                Circle()
                    .fill(VaporwaveColors.neonPurple.opacity(0.2))
                    .frame(width: 100, height: 100)

                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(VaporwaveColors.neonPurple)
            }
            .neonGlow(color: VaporwaveColors.neonPurple, radius: 15)

            Text(title)
                .font(VaporwaveTypography.sectionTitle())
                .foregroundColor(VaporwaveColors.textPrimary)

            Text(message)
                .font(VaporwaveTypography.body())
                .foregroundColor(VaporwaveColors.textSecondary)
                .multilineTextAlignment(.center)

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .vaporwaveButton(isActive: true, activeColor: VaporwaveColors.neonCyan)
                }
            }
        }
        .padding(VaporwaveSpacing.xl)
    }
}

// MARK: - Component Previews

#if DEBUG
#Preview("Components") {
    ZStack {
        VaporwaveGradients.background
            .ignoresSafeArea()

        ScrollView {
            VStack(spacing: VaporwaveSpacing.xl) {
                VaporwaveSectionHeader("Data Displays", icon: "chart.bar")

                HStack(spacing: VaporwaveSpacing.xl) {
                    VaporwaveDataDisplay(value: "72", label: "BPM", color: VaporwaveColors.heartRate)
                    VaporwaveDataDisplay(value: "68", label: "HRV", color: VaporwaveColors.hrv)
                    VaporwaveDataDisplay(value: "85", label: "FLOW", color: VaporwaveColors.coherenceHigh)
                }
                .padding()
                .glassCard()

                VaporwaveSectionHeader("Progress Rings", icon: "circle.dashed")

                HStack(spacing: VaporwaveSpacing.xl) {
                    VaporwaveProgressRing(progress: 0.3, color: VaporwaveColors.coherenceLow)
                    VaporwaveProgressRing(progress: 0.6, color: VaporwaveColors.coherenceMedium)
                    VaporwaveProgressRing(progress: 0.9, color: VaporwaveColors.coherenceHigh)
                }

                VaporwaveSectionHeader("Control Buttons", icon: "button.horizontal")

                HStack(spacing: VaporwaveSpacing.lg) {
                    VaporwaveControlButton(icon: "mic.fill", label: "Record", isActive: true, color: VaporwaveColors.neonPink) {}
                    VaporwaveControlButton(icon: "waveform", label: "Binaural", color: VaporwaveColors.neonPurple) {}
                    VaporwaveControlButton(icon: "airpodspro", label: "Spatial", color: VaporwaveColors.neonCyan) {}
                }

                VaporwaveSectionHeader("Info Rows", icon: "info.circle")

                VStack(spacing: VaporwaveSpacing.sm) {
                    VaporwaveInfoRow(icon: "applewatch", title: "Apple Watch", value: "Connected", valueColor: VaporwaveColors.success)
                    VaporwaveInfoRow(icon: "antenna.radiowaves.left.and.right", title: "OSC", value: "Ready")
                }
                .padding(.horizontal)

                VaporwaveSectionHeader("Status Indicators", icon: "circle.fill")

                HStack(spacing: VaporwaveSpacing.xl) {
                    VaporwaveStatusIndicator(isActive: true)
                    VaporwaveStatusIndicator(isActive: false)
                    VaporwaveStatusIndicator(isActive: true, activeColor: VaporwaveColors.neonPink)
                }

                Spacer()
            }
            .padding()
        }
    }
}
#endif
