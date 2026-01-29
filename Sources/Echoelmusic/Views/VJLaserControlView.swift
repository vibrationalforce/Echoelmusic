import SwiftUI

// MARK: - VJ Laser Control View
// Resolume Arena inspired visual layer & lighting control
// Full VaporwaveTheme Corporate Identity

struct VJLaserControlView: View {
    @StateObject private var vjEngine = VJEngineViewModel()
    @State private var selectedLayer: Int = 0
    @State private var selectedTab: VJTab = .layers
    @State private var showVisualBrowser = false
    @State private var showPatternEditor = false

    enum VJTab: String, CaseIterable {
        case layers = "Layers"
        case laser = "Laser"
        case dmx = "DMX"
        case mapping = "Mapping"
    }

    var body: some View {
        ZStack {
            VaporwaveGradients.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView

                // Tab Bar
                tabBarView

                // Main Content
                GeometryReader { geo in
                    HStack(spacing: 0) {
                        // Layer Stack / Control Panel
                        controlPanel
                            .frame(width: min(geo.size.width * 0.3, 300))

                        // Preview / Main View
                        mainPreview

                        // Parameter Panel
                        if selectedTab == .layers || selectedTab == .laser {
                            parameterPanel
                                .frame(width: min(geo.size.width * 0.25, 250))
                        }
                    }
                }

                // Transport / Master Controls
                masterControlBar
            }

            // Visual Browser Sheet
            if showVisualBrowser {
                VisualBrowserSheet(isPresented: $showVisualBrowser) { visual in
                    vjEngine.addVisualToLayer(selectedLayer, visual: visual)
                }
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: VaporwaveSpacing.xs) {
                HStack(spacing: VaporwaveSpacing.sm) {
                    Image(systemName: "light.max")
                        .foregroundColor(VaporwaveColors.neonPurple)
                        .neonGlow(color: VaporwaveColors.neonPurple, radius: 8)

                    Text("VJ / LASER CONTROL")
                        .font(VaporwaveTypography.sectionTitle())
                        .foregroundColor(VaporwaveColors.textPrimary)
                }

                Text("Resolume Arena Style • \(vjEngine.layers.count) Layers • \(vjEngine.activeDMXChannels) DMX")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.neonCyan)
            }

            Spacer()

            // Output Resolution
            HStack(spacing: VaporwaveSpacing.sm) {
                Text(vjEngine.outputResolution)
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textSecondary)

                Text("@")
                    .foregroundColor(VaporwaveColors.textTertiary)

                Text("\(vjEngine.outputFPS) FPS")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.neonCyan)
            }
            .padding(.horizontal, VaporwaveSpacing.md)
            .padding(.vertical, VaporwaveSpacing.sm)
            .glassCard()

            // Bio Sync
            Button(action: { vjEngine.bioSyncEnabled.toggle() }) {
                HStack(spacing: VaporwaveSpacing.sm) {
                    Image(systemName: "heart.fill")
                    Text("Bio")
                }
                .font(VaporwaveTypography.caption())
                .foregroundColor(vjEngine.bioSyncEnabled ? VaporwaveColors.neonPink : VaporwaveColors.textTertiary)
            }
            .padding(.horizontal, VaporwaveSpacing.md)
            .padding(.vertical, VaporwaveSpacing.sm)
            .background(vjEngine.bioSyncEnabled ? VaporwaveColors.neonPink.opacity(0.2) : Color.clear)
            .glassCard()

            // Fullscreen Output
            Button(action: { vjEngine.toggleFullscreen() }) {
                Image(systemName: "rectangle.on.rectangle")
                    .foregroundColor(VaporwaveColors.textSecondary)
            }
        }
        .padding(VaporwaveSpacing.md)
    }

    // MARK: - Tab Bar

    private var tabBarView: some View {
        HStack(spacing: VaporwaveSpacing.sm) {
            ForEach(VJTab.allCases, id: \.self) { tab in
                Button(action: {
                    withAnimation(VaporwaveAnimation.smooth) {
                        selectedTab = tab
                    }
                }) {
                    HStack(spacing: VaporwaveSpacing.sm) {
                        Image(systemName: tab.icon)
                        Text(tab.rawValue)
                    }
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(selectedTab == tab ? VaporwaveColors.deepBlack : VaporwaveColors.textSecondary)
                    .padding(.horizontal, VaporwaveSpacing.md)
                    .padding(.vertical, VaporwaveSpacing.sm)
                    .background(
                        Capsule()
                            .fill(selectedTab == tab ? tab.color : Color.clear)
                    )
                    .overlay(
                        Capsule()
                            .stroke(selectedTab == tab ? tab.color : VaporwaveColors.textTertiary.opacity(0.3), lineWidth: 1)
                    )
                }
                .neonGlow(color: selectedTab == tab ? tab.color : .clear, radius: 6)
            }

            Spacer()

            // Tap Tempo
            Button(action: { vjEngine.tapTempo() }) {
                HStack(spacing: VaporwaveSpacing.sm) {
                    Image(systemName: "metronome")
                    Text("\(Int(vjEngine.bpm))")
                }
                .font(VaporwaveTypography.caption())
                .foregroundColor(VaporwaveColors.neonCyan)
            }
            .padding(.horizontal, VaporwaveSpacing.md)
            .padding(.vertical, VaporwaveSpacing.sm)
            .glassCard()
        }
        .padding(.horizontal, VaporwaveSpacing.md)
        .padding(.bottom, VaporwaveSpacing.sm)
    }

    // MARK: - Control Panel

    private var controlPanel: some View {
        VStack(spacing: 0) {
            switch selectedTab {
            case .layers:
                layerStackView
            case .laser:
                laserControlView
            case .dmx:
                dmxControlView
            case .mapping:
                mappingControlView
            }
        }
        .background(VaporwaveColors.deepBlack.opacity(0.5))
    }

    // MARK: - Layer Stack View

    private var layerStackView: some View {
        VStack(spacing: VaporwaveSpacing.sm) {
            // Add Layer Button
            Button(action: { vjEngine.addLayer() }) {
                HStack {
                    Image(systemName: "plus.circle.fill")
                    Text("Add Layer")
                }
                .font(VaporwaveTypography.caption())
                .foregroundColor(VaporwaveColors.neonCyan)
                .frame(maxWidth: .infinity)
                .padding(VaporwaveSpacing.sm)
            }
            .glassCard()

            // Layer Stack
            ScrollView {
                VStack(spacing: 4) {
                    ForEach(vjEngine.layers.indices.reversed(), id: \.self) { index in
                        LayerRowView(
                            layer: vjEngine.layers[index],
                            isSelected: selectedLayer == index,
                            onSelect: { selectedLayer = index },
                            onToggleVisible: { vjEngine.toggleLayerVisible(index) },
                            onToggleSolo: { vjEngine.toggleLayerSolo(index) },
                            onOpacityChange: { vjEngine.setLayerOpacity(index, $0) },
                            onBlendModeChange: { vjEngine.setLayerBlendMode(index, $0) },
                            onAddVisual: {
                                selectedLayer = index
                                showVisualBrowser = true
                            }
                        )
                    }
                }
            }

            // Master Opacity
            VStack(spacing: VaporwaveSpacing.xs) {
                HStack {
                    Text("MASTER")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)

                    Spacer()

                    Text("\(Int(vjEngine.masterOpacity * 100))%")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.neonPink)
                }

                Slider(value: $vjEngine.masterOpacity, in: 0...1)
                    .accentColor(VaporwaveColors.neonPink)
            }
            .padding(VaporwaveSpacing.sm)
            .glassCard()
        }
        .padding(VaporwaveSpacing.sm)
    }

    // MARK: - Laser Control View

    private var laserControlView: some View {
        VStack(spacing: VaporwaveSpacing.sm) {
            // Laser Status
            HStack {
                VaporwaveStatusIndicator(isActive: vjEngine.laserEnabled, activeColor: VaporwaveColors.coherenceHigh)

                Text(vjEngine.laserEnabled ? "LASER ACTIVE" : "LASER OFF")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(vjEngine.laserEnabled ? VaporwaveColors.coherenceHigh : VaporwaveColors.textTertiary)

                Spacer()

                Toggle("", isOn: $vjEngine.laserEnabled)
                    .toggleStyle(SwitchToggleStyle(tint: VaporwaveColors.coherenceHigh))
            }
            .padding(VaporwaveSpacing.sm)
            .glassCard()

            // DAC Selection
            VStack(alignment: .leading, spacing: VaporwaveSpacing.xs) {
                Text("LASER DAC")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)

                Picker("DAC", selection: $vjEngine.selectedDAC) {
                    Text("Ether Dream").tag(LaserDAC.etherDream)
                    Text("LaserCube").tag(LaserDAC.laserCube)
                    Text("Pangolin Beyond").tag(LaserDAC.pangolin)
                    Text("Generic ILDA").tag(LaserDAC.genericILDA)
                }
                .pickerStyle(.menu)
            }
            .padding(VaporwaveSpacing.sm)
            .glassCard()

            // Pattern Selection
            VStack(alignment: .leading, spacing: VaporwaveSpacing.sm) {
                Text("LASER PATTERNS")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                    ForEach(VJLaserPattern.allCases, id: \.self) { pattern in
                        LaserPatternButton(
                            pattern: pattern,
                            isSelected: vjEngine.selectedLaserPattern == pattern,
                            action: { vjEngine.selectedLaserPattern = pattern }
                        )
                    }
                }
            }
            .padding(VaporwaveSpacing.sm)
            .glassCard()

            // Laser Parameters
            ScrollView {
                VStack(spacing: VaporwaveSpacing.sm) {
                    LaserParameterSlider(name: "Intensity", value: $vjEngine.laserIntensity, color: VaporwaveColors.neonPink)
                    LaserParameterSlider(name: "Speed", value: $vjEngine.laserSpeed, color: VaporwaveColors.neonCyan)
                    LaserParameterSlider(name: "Size", value: $vjEngine.laserSize, color: VaporwaveColors.neonPurple)
                    LaserParameterSlider(name: "Rotation", value: $vjEngine.laserRotation, color: VaporwaveColors.coral)

                    // Color Mode
                    HStack {
                        Text("Color")
                            .font(VaporwaveTypography.caption())
                            .foregroundColor(VaporwaveColors.textSecondary)

                        Spacer()

                        Picker("", selection: $vjEngine.laserColorMode) {
                            Text("Bio-Reactive").tag(LaserColorMode.bioReactive)
                            Text("Rainbow").tag(LaserColorMode.rainbow)
                            Text("Single").tag(LaserColorMode.single)
                            Text("Audio").tag(LaserColorMode.audioReactive)
                        }
                        .pickerStyle(.menu)
                    }
                    .padding(VaporwaveSpacing.sm)
                    .glassCard()

                    // Safety Zone
                    VStack(alignment: .leading, spacing: VaporwaveSpacing.xs) {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(VaporwaveColors.coherenceMedium)

                            Text("SAFETY ZONE")
                                .font(VaporwaveTypography.label())
                                .foregroundColor(VaporwaveColors.coherenceMedium)
                        }

                        Slider(value: $vjEngine.laserSafetyZone, in: 0...1)
                            .accentColor(VaporwaveColors.coherenceMedium)

                        Text("Blanking: \(Int(vjEngine.laserSafetyZone * 100))% border")
                            .font(VaporwaveTypography.label())
                            .foregroundColor(VaporwaveColors.textTertiary)
                    }
                    .padding(VaporwaveSpacing.sm)
                    .glassCard()
                }
            }
        }
        .padding(VaporwaveSpacing.sm)
    }

    // MARK: - DMX Control View

    private var dmxControlView: some View {
        VStack(spacing: VaporwaveSpacing.sm) {
            // Art-Net Status
            HStack {
                VaporwaveStatusIndicator(isActive: vjEngine.artNetConnected, activeColor: VaporwaveColors.neonCyan)

                Text(vjEngine.artNetConnected ? "Art-Net Connected" : "Art-Net Offline")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(vjEngine.artNetConnected ? VaporwaveColors.neonCyan : VaporwaveColors.textTertiary)

                Spacer()

                Text(vjEngine.artNetIP)
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)
            }
            .padding(VaporwaveSpacing.sm)
            .glassCard()

            // Universe Selector
            HStack {
                Text("Universe")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textSecondary)

                Spacer()

                Stepper("\(vjEngine.dmxUniverse)", value: $vjEngine.dmxUniverse, in: 0...15)
                    .labelsHidden()
            }
            .padding(VaporwaveSpacing.sm)
            .glassCard()

            // Fixture Presets
            VStack(alignment: .leading, spacing: VaporwaveSpacing.sm) {
                Text("FIXTURE PRESETS")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: VaporwaveSpacing.sm) {
                        ForEach(DMXFixturePreset.allCases, id: \.self) { preset in
                            DMXPresetButton(
                                preset: preset,
                                isActive: vjEngine.activeFixturePreset == preset,
                                action: { vjEngine.activateFixturePreset(preset) }
                            )
                        }
                    }
                }
            }
            .padding(VaporwaveSpacing.sm)
            .glassCard()

            // Light Scenes
            VStack(alignment: .leading, spacing: VaporwaveSpacing.sm) {
                Text("LIGHT SCENES")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)

                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 4) {
                    ForEach(LightScene.allCases, id: \.self) { scene in
                        LightSceneButton(
                            scene: scene,
                            isActive: vjEngine.activeLightScene == scene,
                            action: { vjEngine.activateLightScene(scene) }
                        )
                    }
                }
            }
            .padding(VaporwaveSpacing.sm)
            .glassCard()

            // DMX Channel Faders
            ScrollView {
                VStack(spacing: VaporwaveSpacing.sm) {
                    Text("CHANNELS 1-16")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)

                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 8), spacing: 4) {
                        ForEach(0..<16, id: \.self) { channel in
                            DMXChannelFader(
                                channel: channel + 1,
                                value: Binding(
                                    get: { vjEngine.dmxChannels[channel] },
                                    set: { vjEngine.setDMXChannel(channel, $0) }
                                )
                            )
                        }
                    }
                }
            }
        }
        .padding(VaporwaveSpacing.sm)
    }

    // MARK: - Mapping Control View

    private var mappingControlView: some View {
        VStack(spacing: VaporwaveSpacing.sm) {
            // Output Surfaces
            VStack(alignment: .leading, spacing: VaporwaveSpacing.sm) {
                Text("OUTPUT SURFACES")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)

                ForEach(vjEngine.surfaces.indices, id: \.self) { index in
                    SurfaceRowView(
                        surface: vjEngine.surfaces[index],
                        isSelected: vjEngine.selectedSurface == index,
                        onSelect: { vjEngine.selectedSurface = index },
                        onToggle: { vjEngine.toggleSurface(index) }
                    )
                }

                Button(action: { vjEngine.addSurface() }) {
                    HStack {
                        Image(systemName: "plus")
                        Text("Add Surface")
                    }
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.neonCyan)
                    .frame(maxWidth: .infinity)
                    .padding(VaporwaveSpacing.sm)
                }
                .glassCard()
            }
            .padding(VaporwaveSpacing.sm)
            .glassCard()

            // Keystone Correction
            if let surfaceIndex = vjEngine.selectedSurface {
                VStack(alignment: .leading, spacing: VaporwaveSpacing.sm) {
                    Text("KEYSTONE")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)

                    HStack {
                        VStack {
                            Text("TL")
                                .font(VaporwaveTypography.label())
                                .foregroundColor(VaporwaveColors.textTertiary)

                            KeystoneKnob(
                                x: $vjEngine.surfaces[surfaceIndex].keystoneTL.x,
                                y: $vjEngine.surfaces[surfaceIndex].keystoneTL.y
                            )
                        }

                        Spacer()

                        VStack {
                            Text("TR")
                                .font(VaporwaveTypography.label())
                                .foregroundColor(VaporwaveColors.textTertiary)

                            KeystoneKnob(
                                x: $vjEngine.surfaces[surfaceIndex].keystoneTR.x,
                                y: $vjEngine.surfaces[surfaceIndex].keystoneTR.y
                            )
                        }
                    }

                    HStack {
                        VStack {
                            KeystoneKnob(
                                x: $vjEngine.surfaces[surfaceIndex].keystoneBL.x,
                                y: $vjEngine.surfaces[surfaceIndex].keystoneBL.y
                            )

                            Text("BL")
                                .font(VaporwaveTypography.label())
                                .foregroundColor(VaporwaveColors.textTertiary)
                        }

                        Spacer()

                        VStack {
                            KeystoneKnob(
                                x: $vjEngine.surfaces[surfaceIndex].keystoneBR.x,
                                y: $vjEngine.surfaces[surfaceIndex].keystoneBR.y
                            )

                            Text("BR")
                                .font(VaporwaveTypography.label())
                                .foregroundColor(VaporwaveColors.textTertiary)
                        }
                    }

                    Button(action: { vjEngine.resetKeystone(surfaceIndex) }) {
                        Text("Reset Keystone")
                            .font(VaporwaveTypography.caption())
                            .foregroundColor(VaporwaveColors.neonCyan)
                            .frame(maxWidth: .infinity)
                            .padding(VaporwaveSpacing.sm)
                    }
                    .glassCard()
                }
                .padding(VaporwaveSpacing.sm)
                .glassCard()
            }

            Spacer()
        }
        .padding(VaporwaveSpacing.sm)
    }

    // MARK: - Main Preview

    private var mainPreview: some View {
        ZStack {
            // Preview Background
            RoundedRectangle(cornerRadius: 8)
                .fill(VaporwaveColors.deepBlack)

            // Layer Composition Preview
            VStack {
                Spacer()

                // Visual Preview Placeholder
                ZStack {
                    ForEach(vjEngine.layers.indices, id: \.self) { index in
                        if vjEngine.layers[index].isVisible {
                            LayerPreviewView(layer: vjEngine.layers[index])
                                .opacity(Double(vjEngine.layers[index].opacity))
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)

                Spacer()

                // Preview Info Bar
                HStack {
                    Text("PREVIEW")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)

                    Spacer()

                    if vjEngine.bioSyncEnabled {
                        HStack(spacing: VaporwaveSpacing.sm) {
                            Image(systemName: "heart.fill")
                                .foregroundColor(VaporwaveColors.neonPink)

                            Text("\(Int(vjEngine.coherence * 100))%")
                                .font(VaporwaveTypography.label())
                                .foregroundColor(vjEngine.coherenceColor)
                        }
                    }

                    Text("\(vjEngine.outputFPS) FPS")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.neonCyan)
                }
                .padding(VaporwaveSpacing.sm)
                .background(VaporwaveColors.deepBlack.opacity(0.8))
            }
        }
        .padding(VaporwaveSpacing.sm)
    }

    // MARK: - Parameter Panel

    private var parameterPanel: some View {
        VStack(spacing: 0) {
            Text("PARAMETERS")
                .font(VaporwaveTypography.label())
                .foregroundColor(VaporwaveColors.textTertiary)
                .frame(maxWidth: .infinity)
                .padding(VaporwaveSpacing.sm)
                .background(VaporwaveColors.deepBlack.opacity(0.8))

            ScrollView {
                VStack(spacing: VaporwaveSpacing.sm) {
                    if selectedTab == .layers && selectedLayer < vjEngine.layers.count {
                        // Layer Effects
                        VaporwaveSectionHeader("EFFECTS", icon: "wand.and.stars")

                        ForEach(VisualEffect.allCases, id: \.self) { effect in
                            VisualEffectToggle(
                                effect: effect,
                                isEnabled: vjEngine.layers[selectedLayer].effects.contains(effect),
                                onToggle: { vjEngine.toggleLayerEffect(selectedLayer, effect) }
                            )
                        }

                        // Layer Transform
                        VaporwaveSectionHeader("TRANSFORM", icon: "arrow.up.left.and.arrow.down.right")
                            .padding(.top, VaporwaveSpacing.md)

                        TransformSlider(name: "Scale", value: $vjEngine.layers[selectedLayer].scale, range: 0.1...3.0)
                        TransformSlider(name: "Rotation", value: $vjEngine.layers[selectedLayer].rotation, range: -180...180)
                        TransformSlider(name: "X Offset", value: $vjEngine.layers[selectedLayer].xOffset, range: -1...1)
                        TransformSlider(name: "Y Offset", value: $vjEngine.layers[selectedLayer].yOffset, range: -1...1)

                        // Color Correction
                        VaporwaveSectionHeader("COLOR", icon: "paintpalette")
                            .padding(.top, VaporwaveSpacing.md)

                        TransformSlider(name: "Hue", value: $vjEngine.layers[selectedLayer].hue, range: -180...180)
                        TransformSlider(name: "Saturation", value: $vjEngine.layers[selectedLayer].saturation, range: 0...2)
                        TransformSlider(name: "Brightness", value: $vjEngine.layers[selectedLayer].brightness, range: 0...2)
                        TransformSlider(name: "Contrast", value: $vjEngine.layers[selectedLayer].contrast, range: 0...2)

                    } else if selectedTab == .laser {
                        // Bio Modulation
                        VaporwaveSectionHeader("BIO MODULATION", icon: "heart.fill")

                        BioModulationRow2(target: "Pattern", source: $vjEngine.laserBioPattern)
                        BioModulationRow2(target: "Intensity", source: $vjEngine.laserBioIntensity)
                        BioModulationRow2(target: "Speed", source: $vjEngine.laserBioSpeed)
                        BioModulationRow2(target: "Color", source: $vjEngine.laserBioColor)
                    }
                }
                .padding(VaporwaveSpacing.sm)
            }
        }
        .background(VaporwaveColors.midnightBlue.opacity(0.5))
    }

    // MARK: - Master Control Bar

    private var masterControlBar: some View {
        HStack(spacing: VaporwaveSpacing.lg) {
            // Transport
            HStack(spacing: VaporwaveSpacing.md) {
                Button(action: { vjEngine.stop() }) {
                    Image(systemName: "stop.fill")
                        .foregroundColor(VaporwaveColors.textSecondary)
                }

                Button(action: { vjEngine.togglePlay() }) {
                    Image(systemName: vjEngine.isPlaying ? "pause.fill" : "play.fill")
                        .foregroundColor(vjEngine.isPlaying ? VaporwaveColors.neonCyan : VaporwaveColors.textSecondary)
                }
                .neonGlow(color: vjEngine.isPlaying ? VaporwaveColors.neonCyan : .clear, radius: 8)
            }
            .font(.system(size: 20))

            // Crossfader
            VStack(spacing: 2) {
                Text("A/B")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)

                Slider(value: $vjEngine.crossfader, in: 0...1)
                    .accentColor(VaporwaveColors.neonPurple)
                    .frame(width: 150)
            }

            Spacer()

            // Auto Pilot
            Button(action: { vjEngine.autoPilotEnabled.toggle() }) {
                HStack(spacing: VaporwaveSpacing.sm) {
                    Image(systemName: "airplane")
                    Text("Auto")
                }
                .font(VaporwaveTypography.caption())
                .foregroundColor(vjEngine.autoPilotEnabled ? VaporwaveColors.neonPurple : VaporwaveColors.textTertiary)
            }
            .padding(.horizontal, VaporwaveSpacing.md)
            .padding(.vertical, VaporwaveSpacing.sm)
            .background(vjEngine.autoPilotEnabled ? VaporwaveColors.neonPurple.opacity(0.2) : Color.clear)
            .glassCard()

            // Blackout
            Button(action: { vjEngine.toggleBlackout() }) {
                Text("BLACKOUT")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(vjEngine.blackout ? VaporwaveColors.neonPink : VaporwaveColors.textTertiary)
            }
            .padding(.horizontal, VaporwaveSpacing.md)
            .padding(.vertical, VaporwaveSpacing.sm)
            .background(vjEngine.blackout ? VaporwaveColors.neonPink.opacity(0.3) : Color.clear)
            .glassCard()

            // Flash
            Button(action: { vjEngine.flash() }) {
                Text("FLASH")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textPrimary)
            }
            .padding(.horizontal, VaporwaveSpacing.md)
            .padding(.vertical, VaporwaveSpacing.sm)
            .background(VaporwaveColors.textPrimary.opacity(0.2))
            .glassCard()

            // Master Fader
            VStack(spacing: 2) {
                Text("MASTER")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)

                HStack(spacing: VaporwaveSpacing.sm) {
                    Slider(value: $vjEngine.masterOpacity, in: 0...1)
                        .accentColor(VaporwaveColors.neonPink)
                        .frame(width: 100)

                    Text("\(Int(vjEngine.masterOpacity * 100))%")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.neonPink)
                        .frame(width: 35)
                }
            }
        }
        .padding(VaporwaveSpacing.md)
        .background(VaporwaveColors.deepBlack.opacity(0.8))
    }
}

// MARK: - Supporting Views

struct LayerRowView: View {
    let layer: VJLayer
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggleVisible: () -> Void
    let onToggleSolo: () -> Void
    let onOpacityChange: (Float) -> Void
    let onBlendModeChange: (BlendMode) -> Void
    let onAddVisual: () -> Void

    var body: some View {
        VStack(spacing: VaporwaveSpacing.xs) {
            HStack {
                // Visibility
                Button(action: onToggleVisible) {
                    Image(systemName: layer.isVisible ? "eye.fill" : "eye.slash")
                        .font(.system(size: 12))
                        .foregroundColor(layer.isVisible ? VaporwaveColors.neonCyan : VaporwaveColors.textTertiary)
                }

                // Solo
                Button(action: onToggleSolo) {
                    Text("S")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(layer.isSolo ? VaporwaveColors.deepBlack : VaporwaveColors.textTertiary)
                        .frame(width: 18, height: 18)
                        .background(layer.isSolo ? VaporwaveColors.coherenceMedium : Color.clear)
                        .cornerRadius(3)
                }

                // Layer Name
                Text(layer.name)
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(isSelected ? VaporwaveColors.textPrimary : VaporwaveColors.textSecondary)
                    .lineLimit(1)

                Spacer()

                // Add Visual
                Button(action: onAddVisual) {
                    Image(systemName: "plus.circle")
                        .font(.system(size: 12))
                        .foregroundColor(VaporwaveColors.neonPurple)
                }
            }

            // Opacity Slider
            HStack(spacing: VaporwaveSpacing.xs) {
                Slider(value: Binding(
                    get: { Double(layer.opacity) },
                    set: { onOpacityChange(Float($0)) }
                ), in: 0...1)
                .accentColor(VaporwaveColors.neonCyan)

                Text("\(Int(layer.opacity * 100))")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)
                    .frame(width: 25)
            }

            // Blend Mode
            Picker("", selection: Binding(
                get: { layer.blendMode },
                set: { onBlendModeChange($0) }
            )) {
                ForEach(BlendMode.allCases, id: \.self) { mode in
                    Text(mode.rawValue).tag(mode)
                }
            }
            .pickerStyle(.menu)
            .font(VaporwaveTypography.label())
        }
        .padding(VaporwaveSpacing.sm)
        .background(isSelected ? VaporwaveColors.neonCyan.opacity(0.1) : Color.clear)
        .glassCard()
        .onTapGesture { onSelect() }
    }
}

struct LayerPreviewView: View {
    let layer: VJLayer

    var body: some View {
        ZStack {
            if let visualType = layer.visualType {
                switch visualType {
                case .mandala:
                    MandalaPreview()
                case .particles:
                    ParticlePreview()
                case .waveform:
                    WaveformPreviewLarge()
                case .spectrum:
                    SpectrumPreview()
                case .sacred:
                    SacredGeometryPreview()
                default:
                    Rectangle().fill(VaporwaveColors.neonPurple.opacity(0.3))
                }
            } else {
                Text("Empty Layer")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textTertiary)
            }
        }
    }
}

struct MandalaPreview: View {
    @State private var rotation: Double = 0

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 3

            ForEach(0..<12, id: \.self) { i in
                Path { path in
                    let angle = Double(i) * 30 * .pi / 180
                    path.move(to: center)
                    path.addLine(to: CGPoint(
                        x: center.x + CGFloat(cos(angle)) * radius,
                        y: center.y + CGFloat(sin(angle)) * radius
                    ))
                }
                .stroke(VaporwaveColors.neonPurple, lineWidth: 2)
            }

            Circle()
                .stroke(VaporwaveColors.neonCyan, lineWidth: 2)
                .frame(width: radius * 2, height: radius * 2)
                .position(center)
        }
        .rotationEffect(.degrees(rotation))
        .onAppear {
            withAnimation(.linear(duration: 10).repeatForever(autoreverses: false)) {
                rotation = 360
            }
        }
    }
}

struct ParticlePreview: View {
    var body: some View {
        GeometryReader { geo in
            ForEach(0..<30, id: \.self) { _ in
                Circle()
                    .fill(VaporwaveColors.neonPink)
                    .frame(width: CGFloat.random(in: 2...8))
                    .position(
                        x: CGFloat.random(in: 0...geo.size.width),
                        y: CGFloat.random(in: 0...geo.size.height)
                    )
                    .blur(radius: 1)
            }
        }
    }
}

struct WaveformPreviewLarge: View {
    var body: some View {
        GeometryReader { geo in
            Path { path in
                let width = geo.size.width
                let height = geo.size.height
                let midY = height / 2

                path.move(to: CGPoint(x: 0, y: midY))
                for x in stride(from: 0, to: width, by: 4) {
                    let y = midY + sin(x * 0.05) * (height * 0.3)
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
            .stroke(VaporwaveColors.neonCyan, lineWidth: 2)
        }
    }
}

struct SpectrumPreview: View {
    var body: some View {
        GeometryReader { geo in
            HStack(alignment: .bottom, spacing: 2) {
                ForEach(0..<32, id: \.self) { _ in
                    RoundedRectangle(cornerRadius: 2)
                        .fill(VaporwaveColors.neonPurple)
                        .frame(height: CGFloat.random(in: 20...geo.size.height * 0.8))
                }
            }
            .padding()
        }
    }
}

struct SacredGeometryPreview: View {
    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 4

            // Flower of Life pattern
            ForEach(0..<6, id: \.self) { i in
                let angle = Double(i) * 60 * .pi / 180
                Circle()
                    .stroke(VaporwaveColors.neonCyan.opacity(0.5), lineWidth: 1)
                    .frame(width: radius * 2, height: radius * 2)
                    .position(
                        x: center.x + CGFloat(cos(angle)) * radius,
                        y: center.y + CGFloat(sin(angle)) * radius
                    )
            }

            Circle()
                .stroke(VaporwaveColors.neonCyan, lineWidth: 1)
                .frame(width: radius * 2, height: radius * 2)
                .position(center)
        }
    }
}

struct LaserPatternButton: View {
    let pattern: VJLaserPattern
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 2) {
                Image(systemName: pattern.icon)
                    .font(.system(size: 16))
                    .foregroundColor(isSelected ? VaporwaveColors.deepBlack : VaporwaveColors.textSecondary)

                Text(pattern.rawValue)
                    .font(VaporwaveTypography.label())
                    .foregroundColor(isSelected ? VaporwaveColors.deepBlack : VaporwaveColors.textTertiary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(VaporwaveSpacing.xs)
            .background(isSelected ? VaporwaveColors.coherenceHigh : Color.clear)
            .cornerRadius(6)
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .stroke(isSelected ? VaporwaveColors.coherenceHigh : VaporwaveColors.textTertiary.opacity(0.3), lineWidth: 1)
            )
        }
    }
}

struct LaserParameterSlider: View {
    let name: String
    @Binding var value: Float
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: VaporwaveSpacing.xs) {
            HStack {
                Text(name)
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textSecondary)

                Spacer()

                Text("\(Int(value * 100))%")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(color)
            }

            Slider(value: $value, in: 0...1)
                .accentColor(color)
        }
        .padding(VaporwaveSpacing.sm)
        .glassCard()
    }
}

struct DMXPresetButton: View {
    let preset: DMXFixturePreset
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: VaporwaveSpacing.xs) {
                Image(systemName: preset.icon)
                    .font(.system(size: 20))
                    .foregroundColor(isActive ? VaporwaveColors.neonCyan : VaporwaveColors.textSecondary)

                Text(preset.rawValue)
                    .font(VaporwaveTypography.label())
                    .foregroundColor(isActive ? VaporwaveColors.neonCyan : VaporwaveColors.textTertiary)
            }
            .frame(width: 70)
            .padding(VaporwaveSpacing.sm)
            .background(isActive ? VaporwaveColors.neonCyan.opacity(0.2) : Color.clear)
            .glassCard()
        }
    }
}

struct LightSceneButton: View {
    let scene: LightScene
    let isActive: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: scene.icon)
                    .foregroundColor(isActive ? scene.color : VaporwaveColors.textTertiary)

                Text(scene.rawValue)
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(isActive ? VaporwaveColors.textPrimary : VaporwaveColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(VaporwaveSpacing.sm)
            .background(isActive ? scene.color.opacity(0.2) : Color.clear)
            .glassCard()
        }
    }
}

struct DMXChannelFader: View {
    let channel: Int
    @Binding var value: Float

    var body: some View {
        VStack(spacing: 2) {
            Text("\(channel)")
                .font(VaporwaveTypography.label())
                .foregroundColor(VaporwaveColors.textTertiary)

            GeometryReader { geo in
                ZStack(alignment: .bottom) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(VaporwaveColors.deepBlack)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(channelColor)
                        .frame(height: geo.size.height * CGFloat(value))
                }
            }
            .frame(width: 20, height: 50)
            .gesture(
                DragGesture()
                    .onChanged { drag in
                        let newValue = 1 - Float(drag.location.y / 50)
                        value = max(0, min(1, newValue))
                    }
            )

            Text("\(Int(value * 255))")
                .font(VaporwaveTypography.label())
                .foregroundColor(VaporwaveColors.textTertiary)
        }
    }

    var channelColor: Color {
        if channel <= 3 { return VaporwaveColors.neonPink }
        if channel <= 6 { return VaporwaveColors.neonCyan }
        if channel <= 9 { return VaporwaveColors.neonPurple }
        return VaporwaveColors.coral
    }
}

struct SurfaceRowView: View {
    let surface: ProjectionSurface
    let isSelected: Bool
    let onSelect: () -> Void
    let onToggle: () -> Void

    var body: some View {
        HStack {
            Button(action: onToggle) {
                Image(systemName: surface.isEnabled ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(surface.isEnabled ? VaporwaveColors.neonCyan : VaporwaveColors.textTertiary)
            }

            Text(surface.name)
                .font(VaporwaveTypography.caption())
                .foregroundColor(isSelected ? VaporwaveColors.textPrimary : VaporwaveColors.textSecondary)

            Spacer()

            Text("\(surface.width)x\(surface.height)")
                .font(VaporwaveTypography.label())
                .foregroundColor(VaporwaveColors.textTertiary)
        }
        .padding(VaporwaveSpacing.sm)
        .background(isSelected ? VaporwaveColors.neonCyan.opacity(0.1) : Color.clear)
        .glassCard()
        .onTapGesture { onSelect() }
    }
}

struct KeystoneKnob: View {
    @Binding var x: Float
    @Binding var y: Float

    var body: some View {
        ZStack {
            Circle()
                .fill(VaporwaveColors.deepBlack)
                .frame(width: 40, height: 40)

            Circle()
                .stroke(VaporwaveColors.neonCyan, lineWidth: 2)
                .frame(width: 40, height: 40)

            Circle()
                .fill(VaporwaveColors.neonCyan)
                .frame(width: 8, height: 8)
                .offset(x: CGFloat(x) * 15, y: CGFloat(y) * 15)
        }
        .gesture(
            DragGesture()
                .onChanged { drag in
                    x = Float(drag.translation.width / 50).clamped(to: -1...1)
                    y = Float(drag.translation.height / 50).clamped(to: -1...1)
                }
        )
    }
}

struct VisualEffectToggle: View {
    let effect: VisualEffect
    let isEnabled: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: effect.icon)
                    .foregroundColor(isEnabled ? VaporwaveColors.neonPurple : VaporwaveColors.textTertiary)

                Text(effect.rawValue)
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(isEnabled ? VaporwaveColors.textPrimary : VaporwaveColors.textSecondary)

                Spacer()

                Image(systemName: isEnabled ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isEnabled ? VaporwaveColors.neonPurple : VaporwaveColors.textTertiary)
            }
            .padding(VaporwaveSpacing.sm)
            .background(isEnabled ? VaporwaveColors.neonPurple.opacity(0.1) : Color.clear)
            .glassCard()
        }
    }
}

struct TransformSlider: View {
    let name: String
    @Binding var value: Float
    let range: ClosedRange<Float>

    var body: some View {
        VStack(alignment: .leading, spacing: VaporwaveSpacing.xs) {
            HStack {
                Text(name)
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textSecondary)

                Spacer()

                Text(String(format: "%.1f", value))
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.neonCyan)
            }

            Slider(value: Binding(
                get: { Double(value) },
                set: { value = Float($0) }
            ), in: Double(range.lowerBound)...Double(range.upperBound))
            .accentColor(VaporwaveColors.neonCyan)
        }
        .padding(VaporwaveSpacing.sm)
        .glassCard()
    }
}

struct BioModulationRow2: View {
    let target: String
    @Binding var source: BioModSource

    var body: some View {
        HStack {
            Text(target)
                .font(VaporwaveTypography.caption())
                .foregroundColor(VaporwaveColors.textSecondary)

            Spacer()

            Picker("", selection: $source) {
                Text("None").tag(BioModSource.none)
                Text("HR").tag(BioModSource.heartRate)
                Text("HRV").tag(BioModSource.hrv)
                Text("Coherence").tag(BioModSource.coherence)
                Text("Breath").tag(BioModSource.breath)
            }
            .pickerStyle(.menu)
        }
        .padding(VaporwaveSpacing.sm)
        .glassCard()
    }
}

struct VisualBrowserSheet: View {
    @Binding var isPresented: Bool
    let onSelect: (VisualType) -> Void

    let visualCategories: [(String, [VisualType])] = [
        ("Geometric", [.mandala, .sacred, .fractal, .geometric]),
        ("Audio Reactive", [.spectrum, .waveform, .cymatics, .particles]),
        ("Bio Reactive", [.coherenceRing, .heartPulse, .breathWave, .bioField]),
        ("Abstract", [.glitch, .noise, .gradient, .tunnel]),
        ("Nature", [.nebula, .aurora, .water, .fire])
    ]

    var body: some View {
        ZStack {
            VaporwaveGradients.background.ignoresSafeArea()

            VStack {
                HStack {
                    Text("VISUAL BROWSER")
                        .font(VaporwaveTypography.sectionTitle())
                        .foregroundColor(VaporwaveColors.textPrimary)

                    Spacer()

                    Button(action: { isPresented = false }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(VaporwaveColors.textSecondary)
                    }
                }
                .padding(VaporwaveSpacing.md)

                ScrollView {
                    VStack(spacing: VaporwaveSpacing.lg) {
                        ForEach(visualCategories, id: \.0) { category, visuals in
                            VStack(alignment: .leading, spacing: VaporwaveSpacing.sm) {
                                VaporwaveSectionHeader(category, icon: nil)

                                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: VaporwaveSpacing.sm) {
                                    ForEach(visuals, id: \.self) { visual in
                                        VisualTypeCard(visual: visual) {
                                            onSelect(visual)
                                            isPresented = false
                                        }
                                    }
                                }
                            }
                        }
                    }
                    .padding(VaporwaveSpacing.md)
                }
            }
        }
    }
}

struct VisualTypeCard: View {
    let visual: VisualType
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: VaporwaveSpacing.sm) {
                Image(systemName: visual.icon)
                    .font(.system(size: 24))
                    .foregroundColor(VaporwaveColors.neonPurple)

                Text(visual.rawValue)
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textSecondary)
            }
            .frame(maxWidth: .infinity)
            .padding(VaporwaveSpacing.md)
            .glassCard()
        }
    }
}

// MARK: - Tab Extension

extension VJLaserControlView.VJTab {
    var icon: String {
        switch self {
        case .layers: return "square.3.layers.3d"
        case .laser: return "light.max"
        case .dmx: return "lightbulb.led.fill"
        case .mapping: return "rectangle.split.2x2"
        }
    }

    var color: Color {
        switch self {
        case .layers: return VaporwaveColors.neonPurple
        case .laser: return VaporwaveColors.coherenceHigh
        case .dmx: return VaporwaveColors.neonCyan
        case .mapping: return VaporwaveColors.coral
        }
    }
}

// Note: clamped(to:) extension moved to NumericExtensions.swift

// MARK: - Models

@MainActor
class VJEngineViewModel: ObservableObject {
    @Published var layers: [VJLayer] = []
    @Published var masterOpacity: Double = 1.0
    @Published var crossfader: Double = 0.5
    @Published var isPlaying = true
    @Published var blackout = false
    @Published var autoPilotEnabled = false
    @Published var bioSyncEnabled = true
    @Published var coherence: Float = 0.72
    @Published var bpm: Double = 120
    @Published var outputResolution = "1920x1080"
    @Published var outputFPS = 60

    // Laser
    @Published var laserEnabled = false
    @Published var selectedDAC: LaserDAC = .etherDream
    @Published var selectedLaserPattern: VJLaserPattern = .circle
    @Published var laserIntensity: Float = 0.8
    @Published var laserSpeed: Float = 0.5
    @Published var laserSize: Float = 0.7
    @Published var laserRotation: Float = 0
    @Published var laserColorMode: LaserColorMode = .bioReactive
    @Published var laserSafetyZone: Float = 0.1
    @Published var laserBioPattern: BioModSource = .coherence
    @Published var laserBioIntensity: BioModSource = .heartRate
    @Published var laserBioSpeed: BioModSource = .hrv
    @Published var laserBioColor: BioModSource = .coherence

    // DMX
    @Published var artNetConnected = true
    @Published var artNetIP = "192.168.1.100"
    @Published var dmxUniverse = 0
    @Published var dmxChannels: [Float] = Array(repeating: 0, count: 512)
    @Published var activeDMXChannels = 48
    @Published var activeFixturePreset: DMXFixturePreset?
    @Published var activeLightScene: LightScene = .ambient

    // Mapping
    @Published var surfaces: [ProjectionSurface] = []
    @Published var selectedSurface: Int?

    var coherenceColor: Color {
        if coherence > 0.7 { return VaporwaveColors.coherenceHigh }
        if coherence > 0.4 { return VaporwaveColors.coherenceMedium }
        return VaporwaveColors.coherenceLow
    }

    init() {
        layers = [
            VJLayer(name: "Background", visualType: .gradient, opacity: 1.0),
            VJLayer(name: "Particles", visualType: .particles, opacity: 0.7),
            VJLayer(name: "Mandala", visualType: .mandala, opacity: 0.8),
            VJLayer(name: "Bio Ring", visualType: .coherenceRing, opacity: 0.6)
        ]

        surfaces = [
            ProjectionSurface(name: "Main Output", width: 1920, height: 1080),
            ProjectionSurface(name: "LED Wall", width: 3840, height: 2160)
        ]
    }

    func addLayer() { layers.append(VJLayer(name: "Layer \(layers.count + 1)")) }
    func toggleLayerVisible(_ index: Int) { layers[index].isVisible.toggle() }
    func toggleLayerSolo(_ index: Int) { layers[index].isSolo.toggle() }
    func setLayerOpacity(_ index: Int, _ value: Float) { layers[index].opacity = value }
    func setLayerBlendMode(_ index: Int, _ mode: BlendMode) { layers[index].blendMode = mode }
    func addVisualToLayer(_ index: Int, visual: VisualType) { layers[index].visualType = visual }
    func toggleLayerEffect(_ index: Int, _ effect: VisualEffect) {
        if layers[index].effects.contains(effect) {
            layers[index].effects.remove(effect)
        } else {
            layers[index].effects.insert(effect)
        }
    }

    func togglePlay() { isPlaying.toggle() }
    func stop() { isPlaying = false }
    func toggleBlackout() { blackout.toggle() }
    func flash() { /* Flash all outputs white */ }
    func tapTempo() { /* Calculate BPM from taps */ }
    func toggleFullscreen() { /* Toggle fullscreen output */ }

    func setDMXChannel(_ channel: Int, _ value: Float) { dmxChannels[channel] = value }
    func activateFixturePreset(_ preset: DMXFixturePreset) { activeFixturePreset = preset }
    func activateLightScene(_ scene: LightScene) { activeLightScene = scene }

    func addSurface() { surfaces.append(ProjectionSurface(name: "Surface \(surfaces.count + 1)", width: 1920, height: 1080)) }
    func toggleSurface(_ index: Int) { surfaces[index].isEnabled.toggle() }
    func resetKeystone(_ index: Int) {
        surfaces[index].keystoneTL = .zero
        surfaces[index].keystoneTR = .zero
        surfaces[index].keystoneBL = .zero
        surfaces[index].keystoneBR = .zero
    }
}

struct VJLayer: Identifiable {
    let id = UUID()
    var name: String
    var visualType: VisualType?
    var opacity: Float = 1.0
    var blendMode: BlendMode = .normal
    var isVisible: Bool = true
    var isSolo: Bool = false
    var effects: Set<VisualEffect> = []
    var scale: Float = 1.0
    var rotation: Float = 0
    var xOffset: Float = 0
    var yOffset: Float = 0
    var hue: Float = 0
    var saturation: Float = 1.0
    var brightness: Float = 1.0
    var contrast: Float = 1.0
}

struct ProjectionSurface: Identifiable {
    let id = UUID()
    var name: String
    var width: Int
    var height: Int
    var isEnabled: Bool = true
    var keystoneTL: CGPoint = .zero
    var keystoneTR: CGPoint = .zero
    var keystoneBL: CGPoint = .zero
    var keystoneBR: CGPoint = .zero
}

enum VisualType: String, CaseIterable {
    case mandala = "Mandala"
    case sacred = "Sacred"
    case fractal = "Fractal"
    case geometric = "Geometric"
    case spectrum = "Spectrum"
    case waveform = "Waveform"
    case cymatics = "Cymatics"
    case particles = "Particles"
    case coherenceRing = "Coherence"
    case heartPulse = "Heart Pulse"
    case breathWave = "Breath"
    case bioField = "Bio Field"
    case glitch = "Glitch"
    case noise = "Noise"
    case gradient = "Gradient"
    case tunnel = "Tunnel"
    case nebula = "Nebula"
    case aurora = "Aurora"
    case water = "Water"
    case fire = "Fire"

    var icon: String {
        switch self {
        case .mandala: return "circle.hexagongrid"
        case .sacred: return "seal"
        case .fractal: return "triangle.fill"
        case .geometric: return "cube"
        case .spectrum: return "chart.bar.fill"
        case .waveform: return "waveform"
        case .cymatics: return "circle.grid.cross"
        case .particles: return "sparkles"
        case .coherenceRing: return "circle.circle"
        case .heartPulse: return "heart.fill"
        case .breathWave: return "wind"
        case .bioField: return "person.wave.2"
        case .glitch: return "square.split.diagonal.2x2"
        case .noise: return "tv"
        case .gradient: return "paintbrush.fill"
        case .tunnel: return "arrow.down.circle"
        case .nebula: return "sparkle"
        case .aurora: return "rainbow"
        case .water: return "drop.fill"
        case .fire: return "flame.fill"
        }
    }
}

enum BlendMode: String, CaseIterable {
    case normal = "Normal"
    case add = "Add"
    case multiply = "Multiply"
    case screen = "Screen"
    case overlay = "Overlay"
    case difference = "Difference"
}

enum VisualEffect: String, CaseIterable {
    case blur = "Blur"
    case sharpen = "Sharpen"
    case glow = "Glow"
    case mirror = "Mirror"
    case kaleidoscope = "Kaleidoscope"
    case invert = "Invert"
    case posterize = "Posterize"
    case edge = "Edge Detect"

    var icon: String {
        switch self {
        case .blur: return "circle.dotted"
        case .sharpen: return "diamond.fill"
        case .glow: return "sun.max.fill"
        case .mirror: return "arrow.left.and.right"
        case .kaleidoscope: return "circle.hexagongrid.fill"
        case .invert: return "circle.lefthalf.filled"
        case .posterize: return "square.stack.3d.up"
        case .edge: return "square.dashed"
        }
    }
}

enum LaserDAC: String {
    case etherDream = "Ether Dream"
    case laserCube = "LaserCube"
    case pangolin = "Pangolin"
    case genericILDA = "Generic ILDA"
}

enum VJLaserPattern: String, CaseIterable {
    case circle = "Circle"
    case spiral = "Spiral"
    case lissajous = "Lissajous"
    case star = "Star"
    case flower = "Flower"
    case metatron = "Metatron"
    case heartbeat = "Heartbeat"
    case coherence = "Coherence"
    case waveform = "Waveform"

    var icon: String {
        switch self {
        case .circle: return "circle"
        case .spiral: return "tornado"
        case .lissajous: return "scribble.variable"
        case .star: return "star.fill"
        case .flower: return "leaf.fill"
        case .metatron: return "seal.fill"
        case .heartbeat: return "heart.fill"
        case .coherence: return "circle.circle"
        case .waveform: return "waveform"
        }
    }
}

enum LaserColorMode: String {
    case bioReactive = "Bio"
    case rainbow = "Rainbow"
    case single = "Single"
    case audioReactive = "Audio"
}

enum DMXFixturePreset: String, CaseIterable {
    case rgbPar = "RGB PAR"
    case movingHead = "Moving Head"
    case strobe = "Strobe"
    case ledStrip = "LED Strip"
    case fog = "Fog Machine"

    var icon: String {
        switch self {
        case .rgbPar: return "lightbulb.fill"
        case .movingHead: return "light.max"
        case .strobe: return "bolt.fill"
        case .ledStrip: return "rectangle.stack.fill"
        case .fog: return "cloud.fill"
        }
    }
}

enum LightScene: String, CaseIterable {
    case ambient = "Ambient"
    case performance = "Performance"
    case meditation = "Meditation"
    case energetic = "Energetic"
    case reactive = "Bio Reactive"
    case strobe = "Strobe Sync"

    var icon: String {
        switch self {
        case .ambient: return "sun.min"
        case .performance: return "light.max"
        case .meditation: return "moon.stars"
        case .energetic: return "bolt.fill"
        case .reactive: return "heart.fill"
        case .strobe: return "flashlight.on.fill"
        }
    }

    var color: Color {
        switch self {
        case .ambient: return VaporwaveColors.lavender
        case .performance: return VaporwaveColors.neonCyan
        case .meditation: return VaporwaveColors.neonPurple
        case .energetic: return VaporwaveColors.neonPink
        case .reactive: return VaporwaveColors.coherenceHigh
        case .strobe: return VaporwaveColors.coral
        }
    }
}

enum BioModSource: String {
    case none = "None"
    case heartRate = "HR"
    case hrv = "HRV"
    case coherence = "Coherence"
    case breath = "Breath"
}

#Preview {
    VJLaserControlView()
}
