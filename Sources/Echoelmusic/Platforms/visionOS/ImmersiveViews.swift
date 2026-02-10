import SwiftUI
#if canImport(RealityKit)
import RealityKit
#endif

#if os(visionOS)

// MARK: - Immersive Space View

/// Main immersive space for bio-reactive VR experiences
struct EchoelImmersiveSpace: View {

    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace

    @State private var manager = ImmersiveExperienceManager.shared
    @StateObject private var healthKit = HealthKitManager()

    var body: some View {
        RealityView { content in
            // Create bio-reactive environment
            let environment = BioReactiveEnvironment()
            content.add(environment)

            // Setup lighting
            let light = DirectionalLight()
            light.light.intensity = 1000
            light.look(at: .zero, from: SIMD3(0, 5, 5), relativeTo: nil)
            content.add(light)

        } update: { content in
            // Update with bio data
            if let environment = content.entities.first as? BioReactiveEnvironment {
                environment.updateWithBioData(
                    heartRate: manager.heartRate,
                    coherence: manager.coherenceLevel * 100,
                    hrv: manager.bioIntensity * 100
                )
            }
        }
        .gesture(
            TapGesture()
                .targetedToAnyEntity()
                .onEnded { value in
                    handleEntityTap(value.entity)
                }
        )
    }

    private func handleEntityTap(_ entity: Entity) {
        // Handle entity interaction
        ProfessionalLogger.shared.debug("🥽 Tapped entity: \(entity.name)", category: .spatial)
    }
}

// MARK: - Experience Picker View

/// Gallery view for selecting immersive experiences
struct ImmersiveExperiencePicker: View {

    @Environment(\.openImmersiveSpace) var openImmersiveSpace
    @Environment(\.dismissImmersiveSpace) var dismissImmersiveSpace

    @State private var selectedCategory: ImmersiveExperience.ExperienceType = .meditation
    @State private var selectedExperience: ImmersiveExperience?
    @State private var isImmersive = false

    let columns = [
        GridItem(.adaptive(minimum: 280, maximum: 350), spacing: VaporwaveSpacing.lg)
    ]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: VaporwaveSpacing.xl) {

                    // Category Picker
                    categoryPicker

                    // Experience Grid
                    experienceGrid

                }
                .padding()
            }
            .navigationTitle("Immersive Experiences")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    modeSelector
                }
            }
        }
        .ornament(attachmentAnchor: .scene(.bottom)) {
            bottomOrnament
        }
    }

    // MARK: - Category Picker

    private var categoryPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: VaporwaveSpacing.md) {
                ForEach(ImmersiveExperience.ExperienceType.allCases, id: \.self) { type in
                    Button(action: { selectedCategory = type }) {
                        VStack(spacing: VaporwaveSpacing.xs) {
                            Image(systemName: iconForType(type))
                                .font(.system(size: 24))

                            Text(type.rawValue)
                                .font(VaporwaveTypography.label())
                        }
                        .foregroundColor(selectedCategory == type ? VaporwaveColors.neonCyan : VaporwaveColors.textSecondary)
                        .padding(.horizontal, VaporwaveSpacing.md)
                        .padding(.vertical, VaporwaveSpacing.sm)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(selectedCategory == type ? VaporwaveColors.neonCyan.opacity(0.2) : Color.clear)
                        )
                    }
                    .accessibilityLabel("\(type.rawValue) experiences")
                    .accessibilityHint(selectedCategory == type ? "Currently selected" : "Double tap to filter by \(type.rawValue)")
                }
            }
            .padding(.horizontal)
        }
    }

    private func iconForType(_ type: ImmersiveExperience.ExperienceType) -> String {
        switch type {
        case .meditation: return "brain.head.profile"
        case .focus: return "scope"
        case .creativity: return "paintbrush"
        case .healing: return "heart.circle"
        case .performance: return "music.note"
        case .visualization: return "waveform.path"
        }
    }

    // MARK: - Experience Grid

    private var experienceGrid: some View {
        LazyVGrid(columns: columns, spacing: VaporwaveSpacing.lg) {
            ForEach(filteredExperiences) { experience in
                ExperienceCard(
                    experience: experience,
                    isSelected: selectedExperience?.id == experience.id,
                    onSelect: { selectExperience(experience) },
                    onStart: { startExperience(experience) }
                )
            }
        }
    }

    private var filteredExperiences: [ImmersiveExperience] {
        ImmersiveExperienceLibrary.experiencesByType(selectedCategory)
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        Menu {
            ForEach(ImmersiveMode.allCases, id: \.self) { mode in
                Button(action: {
                    Task {
                        await ImmersiveExperienceManager.shared.setMode(mode)
                    }
                }) {
                    Label(mode.rawValue, systemImage: mode.systemImage)
                }
            }
        } label: {
            Image(systemName: "visionpro")
                .font(.system(size: 20))
        }
    }

    // MARK: - Bottom Ornament

    private var bottomOrnament: some View {
        HStack(spacing: VaporwaveSpacing.xl) {
            // Bio metrics display
            VStack(spacing: VaporwaveSpacing.xs) {
                Image(systemName: "heart.fill")
                    .foregroundColor(VaporwaveColors.heartRate)
                Text("\(Int(ImmersiveExperienceManager.shared.heartRate))")
                    .font(VaporwaveTypography.dataSmall())
                Text("BPM")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Heart rate: \(Int(ImmersiveExperienceManager.shared.heartRate)) beats per minute")

            VStack(spacing: VaporwaveSpacing.xs) {
                Image(systemName: "waveform.path.ecg")
                    .foregroundColor(VaporwaveColors.hrv)
                Text("\(Int(ImmersiveExperienceManager.shared.coherenceLevel * 100))")
                    .font(VaporwaveTypography.dataSmall())
                Text("Coherence")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("Coherence level: \(Int(ImmersiveExperienceManager.shared.coherenceLevel * 100)) percent")

            // Start/Stop button
            if let experience = selectedExperience {
                Button(action: { startExperience(experience) }) {
                    HStack {
                        Image(systemName: isImmersive ? "stop.fill" : "play.fill")
                        Text(isImmersive ? "Exit" : "Enter")
                    }
                    .font(VaporwaveTypography.body())
                    .foregroundColor(VaporwaveColors.deepBlack)
                    .padding(.horizontal, VaporwaveSpacing.lg)
                    .padding(.vertical, VaporwaveSpacing.md)
                    .background(VaporwaveColors.neonCyan)
                    .clipShape(Capsule())
                }
                .accessibilityLabel(isImmersive ? "Exit immersive experience" : "Enter \(experience.name) immersive experience")
                .accessibilityHint(isImmersive ? "Double tap to exit the current immersive experience" : "Double tap to start the selected experience")
            }
        }
        .padding()
        .glassBackground()
    }

    // MARK: - Actions

    private func selectExperience(_ experience: ImmersiveExperience) {
        withAnimation(VaporwaveAnimation.smooth) {
            selectedExperience = experience
        }
    }

    private func startExperience(_ experience: ImmersiveExperience) {
        Task {
            if isImmersive {
                await dismissImmersiveSpace()
                await ImmersiveExperienceManager.shared.stopExperience()
                isImmersive = false
            } else {
                try? await ImmersiveExperienceManager.shared.startExperience(experience)
                await openImmersiveSpace(id: "echoelImmersive")
                isImmersive = true
            }
        }
    }
}

// MARK: - Experience Card

struct ExperienceCard: View {

    let experience: ImmersiveExperience
    let isSelected: Bool
    let onSelect: () -> Void
    let onStart: () -> Void

    @State private var isHovering = false

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: VaporwaveSpacing.md) {
                // Preview Image
                ZStack {
                    RoundedRectangle(cornerRadius: 16)
                        .fill(environmentGradient)
                        .frame(height: 180)

                    // Environment icon
                    Image(systemName: environmentIcon)
                        .font(.system(size: 60))
                        .foregroundColor(.white.opacity(0.5))

                    // Duration badge
                    if let duration = experience.duration {
                        VStack {
                            HStack {
                                Spacer()
                                Text(formatDuration(duration))
                                    .font(VaporwaveTypography.label())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, VaporwaveSpacing.sm)
                                    .padding(.vertical, VaporwaveSpacing.xs)
                                    .background(Color.black.opacity(0.5))
                                    .clipShape(Capsule())
                            }
                            Spacer()
                        }
                        .padding(VaporwaveSpacing.sm)
                    }
                }
                .hoverEffect(.lift)

                // Info
                VStack(alignment: .leading, spacing: VaporwaveSpacing.xs) {
                    Text(experience.name)
                        .font(VaporwaveTypography.body())
                        .foregroundColor(VaporwaveColors.textPrimary)

                    Text(experience.preview.description)
                        .font(VaporwaveTypography.caption())
                        .foregroundColor(VaporwaveColors.textSecondary)
                        .lineLimit(2)

                    // Tags
                    HStack {
                        ForEach(experience.preview.tags.prefix(3), id: \.self) { tag in
                            Text(tag)
                                .font(.system(size: 10))
                                .foregroundColor(VaporwaveColors.neonCyan)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(
                                    Capsule()
                                        .fill(VaporwaveColors.neonCyan.opacity(0.2))
                                )
                        }
                    }
                }
            }
            .padding(VaporwaveSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color.black.opacity(0.3))
                    .overlay(
                        RoundedRectangle(cornerRadius: 20)
                            .stroke(isSelected ? VaporwaveColors.neonCyan : Color.clear, lineWidth: 2)
                    )
            )
            .neonGlow(color: isSelected ? VaporwaveColors.neonCyan : .clear, radius: 10)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("\(experience.name), \(experience.type.rawValue) experience")
        .accessibilityHint(isSelected ? "Selected. Double tap to start" : "Double tap to select")
        .accessibilityValue(experience.duration.map { "Duration: \(formatDuration($0))" } ?? "Unlimited duration")
    }

    private var environmentGradient: LinearGradient {
        let colors: [Color]
        switch experience.environment {
        case .cosmos:
            colors = [Color.purple.opacity(0.8), Color.blue.opacity(0.6)]
        case .nature, .forest:
            colors = [Color.green.opacity(0.8), Color.brown.opacity(0.6)]
        case .ocean:
            colors = [Color.blue.opacity(0.8), Color.cyan.opacity(0.6)]
        case .sacred, .quantum:
            colors = [VaporwaveColors.neonPink.opacity(0.8), VaporwaveColors.neonPurple.opacity(0.6)]
        case .aurora:
            colors = [Color.green.opacity(0.8), Color.purple.opacity(0.6)]
        case .abstract:
            colors = [VaporwaveColors.neonCyan.opacity(0.8), VaporwaveColors.neonPink.opacity(0.6)]
        case .void:
            colors = [Color.black, Color.gray.opacity(0.3)]
        case .mountain:
            colors = [Color.gray.opacity(0.8), Color.white.opacity(0.6)]
        }
        return LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var environmentIcon: String {
        switch experience.environment {
        case .cosmos: return "sparkles"
        case .nature: return "leaf"
        case .forest: return "tree"
        case .ocean: return "water.waves"
        case .sacred: return "seal"
        case .quantum: return "atom"
        case .aurora: return "sparkle"
        case .abstract: return "cube"
        case .void: return "circle"
        case .mountain: return "mountain.2"
        }
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        if minutes >= 60 {
            return "\(minutes / 60)h \(minutes % 60)m"
        }
        return "\(minutes) min"
    }
}

// MARK: - Glass Background Modifier

struct GlassBackground: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
    }
}

extension View {
    func glassBackground() -> some View {
        modifier(GlassBackground())
    }
}

// MARK: - Spatial Bio Display

/// Floating bio-metrics display for immersive mode
struct SpatialBioDisplay: View {

    @State private var manager = ImmersiveExperienceManager.shared
    @State private var isExpanded = false

    var body: some View {
        VStack(spacing: VaporwaveSpacing.md) {
            // Coherence ring
            ZStack {
                VaporwaveProgressRing(
                    progress: manager.coherenceLevel,
                    color: coherenceColor,
                    lineWidth: 4,
                    size: 80
                )

                VStack {
                    Text("\(Int(manager.coherenceLevel * 100))")
                        .font(VaporwaveTypography.data())
                        .foregroundColor(coherenceColor)

                    Text("FLOW")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)
                }
            }

            if isExpanded {
                VStack(spacing: VaporwaveSpacing.sm) {
                    // Heart rate
                    HStack {
                        Image(systemName: "heart.fill")
                            .foregroundColor(VaporwaveColors.heartRate)
                        Text("\(Int(manager.heartRate)) BPM")
                            .font(VaporwaveTypography.caption())
                    }

                    // Intensity
                    HStack {
                        Image(systemName: "waveform")
                            .foregroundColor(VaporwaveColors.hrv)
                        Text("\(Int(manager.bioIntensity * 100))% intensity")
                            .font(VaporwaveTypography.caption())
                    }
                }
                .transition(.opacity.combined(with: .scale))
            }
        }
        .padding(VaporwaveSpacing.lg)
        .glassBackground()
        .onTapGesture {
            withAnimation(VaporwaveAnimation.smooth) {
                isExpanded.toggle()
            }
        }
        .hoverEffect(.lift)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Bio metrics display. Coherence: \(Int(manager.coherenceLevel * 100)) percent. Heart rate: \(Int(manager.heartRate)) BPM")
        .accessibilityHint(isExpanded ? "Double tap to collapse" : "Double tap to expand details")
        .accessibilityAddTraits(.isButton)
    }

    private var coherenceColor: Color {
        if manager.coherenceLevel < 0.4 {
            return VaporwaveColors.coherenceLow
        } else if manager.coherenceLevel < 0.6 {
            return VaporwaveColors.coherenceMedium
        } else {
            return VaporwaveColors.coherenceHigh
        }
    }
}

// MARK: - Immersive Settings View

struct ImmersiveSettingsView: View {

    @State private var manager = ImmersiveExperienceManager.shared
    @State private var motionComfort: ImmersiveExperienceManager.MotionComfort = .standard
    @State private var bioReactivity: Float = 1.0
    @State private var spatialAudio: Bool = true

    var body: some View {
        NavigationStack {
            Form {
                Section("Comfort") {
                    Picker("Motion Comfort", selection: $motionComfort) {
                        ForEach(ImmersiveExperienceManager.MotionComfort.allCases, id: \.self) { level in
                            Text(level.rawValue).tag(level)
                        }
                    }

                    Text(motionComfort.description)
                        .font(VaporwaveTypography.caption())
                        .foregroundColor(VaporwaveColors.textSecondary)
                }

                Section("Bio-Reactivity") {
                    VStack(alignment: .leading) {
                        HStack {
                            Text("Intensity")
                            Spacer()
                            Text("\(Int(bioReactivity * 100))%")
                                .font(.system(size: 14, design: .monospaced))
                        }
                        Slider(value: $bioReactivity, in: 0.2...1.0)
                            .tint(VaporwaveColors.neonCyan)
                    }
                }

                Section("Audio") {
                    Toggle("Spatial Audio", isOn: $spatialAudio)
                        .tint(VaporwaveColors.neonCyan)
                }

                Section("Current Mode") {
                    ForEach(ImmersiveMode.allCases, id: \.self) { mode in
                        Button(action: {
                            Task {
                                await manager.setMode(mode)
                            }
                        }) {
                            HStack {
                                Image(systemName: mode.systemImage)
                                    .foregroundColor(VaporwaveColors.neonCyan)
                                    .frame(width: 24)

                                VStack(alignment: .leading) {
                                    Text(mode.rawValue)
                                    Text(mode.description)
                                        .font(VaporwaveTypography.caption())
                                        .foregroundColor(VaporwaveColors.textSecondary)
                                }

                                Spacer()

                                if manager.currentMode == mode {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(VaporwaveColors.success)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle("Immersive Settings")
        }
    }
}

#endif
