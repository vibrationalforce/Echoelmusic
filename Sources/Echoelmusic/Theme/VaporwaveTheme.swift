import SwiftUI

// MARK: - Vaporwave Theme → EchoelBrand Bridge
// All legacy VaporwaveColors/Gradients/Typography now redirect to EchoelBrand.
// This unifies the entire app under the monochrome "E + Wellen" identity
// without touching 23+ individual view files.

/// Legacy color palette — now forwards to EchoelBrand monochrome system
struct VaporwaveColors {

    // MARK: - Primary Colors (monochrome)

    /// Primary accent — light gray (#E0E0E0)
    static let neonPink = EchoelBrand.primary

    /// Secondary accent — light gray (#E0E0E0)
    static let neonCyan = EchoelBrand.primary

    /// Tertiary — dimmed gray
    static let neonPurple = EchoelBrand.textSecondary

    /// Soft lavender → secondary text
    static let lavender = EchoelBrand.textSecondary

    /// Coral — functional color (warnings, recording)
    static let coral = EchoelBrand.coral

    // MARK: - Background Colors (true black)

    /// True black
    static let deepBlack = EchoelBrand.bgDeep

    /// Surface — very subtle gray (#0A0A0A)
    static let midnightBlue = EchoelBrand.bgSurface

    /// Elevated — modals, popovers (#141414)
    static let darkPurple = EchoelBrand.bgElevated

    /// Amber (functional)
    static let sunsetOrange = EchoelBrand.amber

    /// Coral (functional)
    static let sunsetPink = EchoelBrand.coral

    // MARK: - Bio-Reactive Colors (functional — keep distinct)

    /// Low coherence - needs attention
    static let coherenceLow = EchoelBrand.coherenceLow

    /// Medium coherence - transitioning
    static let coherenceMedium = EchoelBrand.coherenceMedium

    /// High coherence - flow state
    static let coherenceHigh = EchoelBrand.coherenceHigh

    // MARK: - Text Colors

    /// Primary text (#E0E0E0)
    static let textPrimary = EchoelBrand.textPrimary

    /// Secondary text (55% opacity)
    static let textSecondary = EchoelBrand.textSecondary

    /// Tertiary text (55% opacity)
    static let textTertiary = EchoelBrand.textTertiary

    // MARK: - Glass Effect Colors

    /// Glass background
    static let glassBg = EchoelBrand.bgGlass

    /// Glass border
    static let glassBorder = EchoelBrand.border

    /// Glass border active
    static let glassBorderActive = EchoelBrand.borderActive

    // MARK: - Functional Colors

    /// Recording active
    static let recordingActive = EchoelBrand.coral

    /// Success/connected
    static let success = EchoelBrand.emerald

    /// Warning
    static let warning = EchoelBrand.amber

    /// Heart rate
    static let heartRate = EchoelBrand.rose

    /// HRV
    static let hrv = EchoelBrand.emerald
}

// MARK: - Gradients (monochrome)

struct VaporwaveGradients {

    /// Main background — true black to surface
    static let background = EchoelGradients.background

    /// Brand gradient (monochrome)
    static let sunset = EchoelGradients.brand

    /// Brand gradient (monochrome)
    static let neon = LinearGradient(
        colors: [
            EchoelBrand.primary.opacity(0.6),
            EchoelBrand.primary,
            Color.white.opacity(0.9)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Coherence gradient (functional — keep colors)
    static let coherence = EchoelGradients.coherence

    /// Card background (glass)
    static let glassCard = EchoelGradients.card

    /// Card accent bar
    static let cardAccent = LinearGradient(
        colors: [
            EchoelBrand.primary.opacity(0.5),
            EchoelBrand.primary,
            EchoelBrand.primary.opacity(0.5)
        ],
        startPoint: .leading,
        endPoint: .trailing
    )

    /// Subtle blob gradient
    static func blobGradient(at position: UnitPoint) -> RadialGradient {
        RadialGradient(
            gradient: Gradient(colors: [
                EchoelBrand.primary.opacity(0.04),
                Color.clear
            ]),
            center: position,
            startRadius: 0,
            endRadius: 300
        )
    }
}

// MARK: - Animated Background (monochrome)

/// Monochrome background with subtle depth
struct VaporwaveAnimatedBackground: View {
    var body: some View {
        ZStack {
            // True black base
            EchoelBrand.bgDeep

            // Subtle depth blob (gray, top-left)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [EchoelBrand.primary.opacity(0.03), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 250
                    )
                )
                .frame(width: 500, height: 500)
                .offset(x: -150, y: -200)
                .blur(radius: 60)

            // Subtle depth blob (gray, bottom-right)
            Circle()
                .fill(
                    RadialGradient(
                        colors: [EchoelBrand.primary.opacity(0.02), .clear],
                        center: .center,
                        startRadius: 0,
                        endRadius: 200
                    )
                )
                .frame(width: 400, height: 400)
                .offset(x: 150, y: 200)
                .blur(radius: 50)
        }
        .ignoresSafeArea()
        .drawingGroup()
    }
}

/// Grid overlay (monochrome)
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
                let color = EchoelBrand.primary.opacity(lineOpacity)

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

/// Complete background with gradient and grid
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
                EchoelBrand.bgDeep
            }

            if showGrid {
                VaporwaveGridOverlay()
            }
        }
        .ignoresSafeArea()
    }
}

// MARK: - View Modifiers (monochrome)

struct NeonGlow: ViewModifier {
    let color: Color
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .shadow(color: color.opacity(0.3), radius: radius)
            .shadow(color: color.opacity(0.15), radius: radius * 2)
    }
}

struct GlassCard: ViewModifier {
    let isActive: Bool
    let showAccentBar: Bool
    let cornerRadius: CGFloat

    init(isActive: Bool = false, showAccentBar: Bool = false, cornerRadius: CGFloat = EchoelRadius.lg) {
        self.isActive = isActive
        self.showAccentBar = showAccentBar
        self.cornerRadius = cornerRadius
    }

    func body(content: Content) -> some View {
        content
            .background(
                RoundedRectangle(cornerRadius: cornerRadius)
                    .fill(isActive ? EchoelBrand.bgElevated : EchoelBrand.bgSurface)
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius)
                            .stroke(
                                isActive ? EchoelBrand.borderActive : EchoelBrand.border,
                                lineWidth: 1
                            )
                    )
            )
            .overlay(alignment: .top) {
                if showAccentBar {
                    EchoelBrand.primary.opacity(0.3)
                        .frame(height: 2)
                        .clipShape(RoundedRectangle(cornerRadius: cornerRadius))
                }
            }
    }
}

struct VaporwaveButton: ViewModifier {
    let isActive: Bool
    let activeColor: Color

    func body(content: Content) -> some View {
        content
            .foregroundColor(isActive ? EchoelBrand.bgDeep : EchoelBrand.textPrimary)
            .padding(.horizontal, EchoelSpacing.lg)
            .padding(.vertical, EchoelSpacing.md)
            .background(
                Capsule()
                    .fill(isActive ? EchoelBrand.primary : EchoelBrand.bgElevated)
            )
            .overlay(
                Capsule()
                    .stroke(isActive ? EchoelBrand.primary : EchoelBrand.border, lineWidth: 1)
            )
    }
}

// MARK: - View Extensions

extension View {
    func neonGlow(color: Color = EchoelBrand.primary, radius: CGFloat = 12) -> some View {
        modifier(NeonGlow(color: color, radius: radius))
    }

    func glassCard(isActive: Bool = false, showAccentBar: Bool = false, cornerRadius: CGFloat = EchoelRadius.lg) -> some View {
        modifier(GlassCard(isActive: isActive, showAccentBar: showAccentBar, cornerRadius: cornerRadius))
    }

    func vaporwaveButton(isActive: Bool = false, activeColor: Color = EchoelBrand.primary) -> some View {
        modifier(VaporwaveButton(isActive: isActive, activeColor: activeColor))
    }

    func vaporwaveBackground() -> some View {
        self.background(EchoelBrand.bgDeep.ignoresSafeArea())
    }

    func vaporwaveFullBackground(showGrid: Bool = true, animated: Bool = true) -> some View {
        self.background(VaporwaveFullBackground(showGrid: showGrid, animated: animated))
    }
}

// MARK: - Typography (forwards to EchoelBrandFont)

struct VaporwaveTypography {
    static func heroTitle() -> Font { EchoelBrandFont.heroTitle() }
    static func sectionTitle() -> Font { EchoelBrandFont.sectionTitle() }
    static func body() -> Font { EchoelBrandFont.body() }
    static func caption() -> Font { EchoelBrandFont.caption() }
    static func data() -> Font { EchoelBrandFont.data() }
    static func dataSmall() -> Font { EchoelBrandFont.dataSmall() }
    static func label() -> Font { EchoelBrandFont.label() }
}

// MARK: - Spacing (same values as EchoelSpacing)

struct VaporwaveSpacing {
    static let xs: CGFloat = EchoelSpacing.xs
    static let sm: CGFloat = EchoelSpacing.sm
    static let md: CGFloat = EchoelSpacing.md
    static let lg: CGFloat = EchoelSpacing.lg
    static let xl: CGFloat = EchoelSpacing.xl
    static let xxl: CGFloat = EchoelSpacing.xxl
}

// MARK: - Animation

struct VaporwaveAnimation {
    static let smooth = Animation.spring(response: 0.4, dampingFraction: 0.8)
    static let quick = Animation.easeOut(duration: EchoelAnimation.quick)
    static let breathing = Animation.easeInOut(duration: EchoelAnimation.breathing)
    static let pulse = Animation.easeInOut(duration: EchoelAnimation.pulse)
    static let glow = Animation.easeInOut(duration: EchoelAnimation.coherenceGlow)

    static func reduced(_ animation: Animation, reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : animation
    }

    static func smoothReduced(_ reduceMotion: Bool) -> Animation? {
        reduceMotion ? nil : smooth
    }
}

// MARK: - Reusable UI Components (monochrome)

struct VaporwaveDataDisplay: View {
    let value: String
    let label: String
    let color: Color
    let showGlow: Bool

    init(value: String, label: String, color: Color = EchoelBrand.primary, showGlow: Bool = false) {
        self.value = value
        self.label = label
        self.color = color
        self.showGlow = showGlow
    }

    var body: some View {
        VStack(spacing: EchoelSpacing.xs) {
            Text(value)
                .font(EchoelBrandFont.data())
                .foregroundColor(color)
                .neonGlow(color: showGlow ? color : .clear, radius: 6)

            Text(label)
                .font(EchoelBrandFont.label())
                .foregroundColor(EchoelBrand.textTertiary)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(value)")
    }
}

struct VaporwaveStatusIndicator: View {
    let isActive: Bool
    let activeColor: Color
    let inactiveColor: Color

    init(isActive: Bool, activeColor: Color = EchoelBrand.emerald, inactiveColor: Color = EchoelBrand.textTertiary) {
        self.isActive = isActive
        self.activeColor = activeColor
        self.inactiveColor = inactiveColor
    }

    var body: some View {
        Circle()
            .fill(isActive ? activeColor : inactiveColor)
            .frame(width: 10, height: 10)
            .shadow(color: isActive ? activeColor.opacity(0.4) : .clear, radius: 4)
            .accessibilityLabel(isActive ? "Active" : "Inactive")
    }
}

struct VaporwaveProgressRing: View {
    let progress: Double
    let color: Color
    let lineWidth: CGFloat
    let size: CGFloat

    init(progress: Double, color: Color = EchoelBrand.coherenceHigh, lineWidth: CGFloat = 6, size: CGFloat = 60) {
        self.progress = progress
        self.color = color
        self.lineWidth = lineWidth
        self.size = size
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(EchoelBrand.textDisabled, lineWidth: lineWidth)
                .frame(width: size, height: size)

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
        color: Color = EchoelBrand.primary,
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
            VStack(spacing: EchoelSpacing.sm) {
                ZStack {
                    Circle()
                        .fill(isActive ? color.opacity(0.15) : EchoelBrand.bgSurface)
                        .frame(width: size, height: size)
                        .overlay(
                            Circle()
                                .stroke(isActive ? color : EchoelBrand.border, lineWidth: 1)
                        )

                    Image(systemName: icon)
                        .font(.system(size: size * 0.45))
                        .foregroundColor(isActive ? color : EchoelBrand.textSecondary)
                }

                Text(label)
                    .font(EchoelBrandFont.label())
                    .foregroundColor(EchoelBrand.textSecondary)
            }
        }
        .accessibilityLabel("\(label), \(isActive ? "active" : "inactive")")
        .accessibilityHint("Double tap to toggle")
    }
}

struct VaporwaveInfoRow: View {
    let icon: String
    let title: String
    let value: String
    let valueColor: Color

    init(icon: String, title: String, value: String, valueColor: Color = EchoelBrand.textSecondary) {
        self.icon = icon
        self.title = title
        self.value = value
        self.valueColor = valueColor
    }

    var body: some View {
        HStack(spacing: EchoelSpacing.md) {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(EchoelBrand.primary)
                .frame(width: 24)

            Text(title)
                .font(EchoelBrandFont.body())
                .foregroundColor(EchoelBrand.textPrimary)

            Spacer()

            Text(value)
                .font(EchoelBrandFont.caption())
                .foregroundColor(valueColor)
        }
        .padding(EchoelSpacing.md)
        .glassCard()
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(value)")
    }
}

struct VaporwaveSectionHeader: View {
    let title: String
    let icon: String?

    init(_ title: String, icon: String? = nil) {
        self.title = title
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: EchoelSpacing.sm) {
            if let icon = icon {
                Image(systemName: icon)
                    .font(.system(size: 14))
                    .foregroundColor(EchoelBrand.primary)
            }

            Text(title.uppercased())
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(EchoelBrand.textTertiary)
                .tracking(2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct VaporwaveToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var isOn: Bool
    let tintColor: Color

    init(title: String, subtitle: String? = nil, isOn: Binding<Bool>, tintColor: Color = EchoelBrand.primary) {
        self.title = title
        self.subtitle = subtitle
        self._isOn = isOn
        self.tintColor = tintColor
    }

    var body: some View {
        Toggle(isOn: $isOn) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(EchoelBrandFont.body())
                    .foregroundColor(EchoelBrand.textPrimary)

                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(EchoelBrandFont.caption())
                        .foregroundColor(EchoelBrand.textTertiary)
                }
            }
        }
        .toggleStyle(SwitchToggleStyle(tint: tintColor))
        .padding(EchoelSpacing.md)
        .glassCard()
    }
}

struct VaporwaveBadge: View {
    let text: String
    let dotColor: Color
    let showPulse: Bool

    init(_ text: String, dotColor: Color = EchoelBrand.coherenceHigh, showPulse: Bool = true) {
        self.text = text
        self.dotColor = dotColor
        self.showPulse = showPulse
    }

    var body: some View {
        HStack(spacing: EchoelSpacing.sm) {
            Circle()
                .fill(dotColor)
                .frame(width: 8, height: 8)

            Text(text)
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(EchoelBrand.textSecondary)
        }
        .padding(.horizontal, EchoelSpacing.md)
        .padding(.vertical, EchoelSpacing.xs)
        .background(EchoelBrand.bgGlass)
        .overlay(
            Capsule()
                .stroke(EchoelBrand.border, lineWidth: 1)
        )
        .clipShape(Capsule())
    }
}

struct VaporwaveTag: View {
    let text: String
    let color: Color

    init(_ text: String, color: Color = EchoelBrand.primary) {
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

struct VaporwaveSectionLabel: View {
    let text: String

    init(_ text: String) {
        self.text = text
    }

    var body: some View {
        Text(text.uppercased())
            .font(.system(size: 12, weight: .semibold))
            .foregroundColor(EchoelBrand.primary)
            .tracking(1)
            .padding(.horizontal, EchoelSpacing.md)
            .padding(.vertical, EchoelSpacing.xs)
            .background(EchoelBrand.primary.opacity(0.08))
            .overlay(
                Capsule()
                    .stroke(EchoelBrand.border, lineWidth: 1)
            )
            .clipShape(Capsule())
    }
}

struct VaporwaveStatCard: View {
    let value: String
    let label: String

    var body: some View {
        VStack(spacing: EchoelSpacing.xs) {
            Text(value)
                .font(.system(size: 36, weight: .heavy))
                .foregroundColor(EchoelBrand.textPrimary)

            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(EchoelBrand.textTertiary)
        }
        .padding(EchoelSpacing.xl)
        .frame(maxWidth: .infinity)
        .glassCard()
    }
}

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
            HStack(spacing: EchoelSpacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .semibold))
                }
                Text(title)
                    .font(.system(size: 16, weight: .bold))
            }
            .foregroundColor(EchoelBrand.bgDeep)
            .padding(.horizontal, EchoelSpacing.xl)
            .padding(.vertical, EchoelSpacing.md)
            .background(
                Capsule()
                    .fill(EchoelBrand.primary)
            )
            .scaleEffect(isHovered ? 1.02 : 1.0)
        }
        .buttonStyle(.plain)
        #if !os(watchOS)
        .onHover { hovering in
            withAnimation(.easeOut(duration: EchoelAnimation.quick)) {
                isHovered = hovering
            }
        }
        #endif
    }
}

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
            HStack(spacing: EchoelSpacing.sm) {
                if let icon = icon {
                    Image(systemName: icon)
                        .font(.system(size: 16, weight: .medium))
                }
                Text(title)
                    .font(.system(size: 16, weight: .semibold))
            }
            .foregroundColor(EchoelBrand.textPrimary)
            .padding(.horizontal, EchoelSpacing.xl)
            .padding(.vertical, EchoelSpacing.md)
            .background(EchoelBrand.bgGlass)
            .overlay(
                Capsule()
                    .stroke(
                        isHovered ? EchoelBrand.borderActive : EchoelBrand.border,
                        lineWidth: 1
                    )
            )
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        #if !os(watchOS)
        .onHover { hovering in
            withAnimation(.easeOut(duration: EchoelAnimation.quick)) {
                isHovered = hovering
            }
        }
        #endif
    }
}

struct VaporwaveWorkspaceCard: View {
    let icon: String
    let title: String
    let description: String
    let badge: String
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            VStack(spacing: EchoelSpacing.md) {
                Text(icon)
                    .font(.system(size: 48))

                Text(title)
                    .font(.system(size: 22, weight: .bold))
                    .foregroundColor(EchoelBrand.textPrimary)

                Text(description)
                    .font(.system(size: 14))
                    .foregroundColor(EchoelBrand.textSecondary)
                    .multilineTextAlignment(.center)

                Text(badge)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundColor(EchoelBrand.bgDeep)
                    .padding(.horizontal, EchoelSpacing.md)
                    .padding(.vertical, EchoelSpacing.xs)
                    .background(EchoelBrand.primary)
                    .clipShape(Capsule())
            }
            .padding(EchoelSpacing.xl)
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
        VStack(spacing: EchoelSpacing.lg) {
            ZStack {
                Circle()
                    .fill(EchoelBrand.primary.opacity(0.08))
                    .frame(width: 100, height: 100)

                Image(systemName: icon)
                    .font(.system(size: 40))
                    .foregroundColor(EchoelBrand.primary)
            }

            Text(title)
                .font(EchoelBrandFont.sectionTitle())
                .foregroundColor(EchoelBrand.textPrimary)

            Text(message)
                .font(EchoelBrandFont.body())
                .foregroundColor(EchoelBrand.textSecondary)
                .multilineTextAlignment(.center)

            if let actionTitle = actionTitle, let action = action {
                Button(action: action) {
                    Text(actionTitle)
                        .vaporwaveButton(isActive: true, activeColor: EchoelBrand.primary)
                }
            }
        }
        .padding(EchoelSpacing.xl)
    }
}

// MARK: - Previews

#if DEBUG
#Preview {
    ZStack {
        EchoelBrand.bgDeep
            .ignoresSafeArea()

        VStack(spacing: EchoelSpacing.lg) {
            Text("ECHOELMUSIC")
                .font(EchoelBrandFont.heroTitle())
                .foregroundColor(EchoelBrand.textPrimary)

            Text("Create from Within")
                .font(EchoelBrandFont.caption())
                .foregroundColor(EchoelBrand.textSecondary)
                .tracking(4)

            HStack(spacing: EchoelSpacing.xl) {
                VaporwaveDataDisplay(value: "72", label: "BPM", color: EchoelBrand.rose)
                VaporwaveDataDisplay(value: "68", label: "HRV", color: EchoelBrand.emerald)
                VaporwaveDataDisplay(value: "85", label: "FLOW", color: EchoelBrand.coherenceHigh)
            }
            .padding(EchoelSpacing.lg)
            .glassCard()

            HStack(spacing: EchoelSpacing.md) {
                Text("Focus")
                    .vaporwaveButton(isActive: true)

                Text("Create")
                    .vaporwaveButton(isActive: false)

                Text("Heal")
                    .vaporwaveButton(isActive: false)
            }
        }
    }
}
#endif
