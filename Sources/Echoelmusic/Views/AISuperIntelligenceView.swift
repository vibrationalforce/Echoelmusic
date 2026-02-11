import SwiftUI

// MARK: - AI Super Intelligence View
// Unified AI Control Panel for all EchoelTools
// Full VaporwaveTheme Corporate Identity

@MainActor
struct AISuperIntelligenceView: View {
    @StateObject private var aiEngine = AISuperIntelligenceViewModel()
    @State private var selectedCategory: AICategory = .composition
    @State private var promptText: String = ""
    @State private var showHistory = false

    var body: some View {
        ZStack {
            VaporwaveGradients.background.ignoresSafeArea()

            VStack(spacing: 0) {
                // Header
                headerView

                // Category Selector
                categorySelector

                // Main Content
                ScrollView {
                    VStack(spacing: VaporwaveSpacing.lg) {
                        // Active Tool Panel
                        activeToolPanel

                        // Quick Actions
                        quickActionsGrid

                        // AI Tools Grid
                        aiToolsSection

                        // Results/Output
                        if aiEngine.hasOutput {
                            outputSection
                        }
                    }
                    .padding(VaporwaveSpacing.md)
                }

                // Prompt Input Bar
                promptInputBar
            }

            // History Panel
            if showHistory {
                AIHistorySheet(isPresented: $showHistory, history: aiEngine.history)
            }
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            VStack(alignment: .leading, spacing: VaporwaveSpacing.xs) {
                HStack(spacing: VaporwaveSpacing.sm) {
                    Image(systemName: "brain.head.profile")
                        .foregroundColor(VaporwaveColors.neonPurple)
                        .neonGlow(color: VaporwaveColors.neonPurple, radius: 8)

                    Text("ECHOELTOOLS AI")
                        .font(VaporwaveTypography.sectionTitle())
                        .foregroundColor(VaporwaveColors.textPrimary)
                }

                Text("Super Intelligence • \(aiEngine.activeModels) Models Active")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.neonCyan)
            }

            Spacer()

            // Status Indicators
            HStack(spacing: VaporwaveSpacing.md) {
                // Processing Status
                if aiEngine.isProcessing {
                    HStack(spacing: VaporwaveSpacing.sm) {
                        ProgressView()
                            .scaleEffect(0.7)
                            .tint(VaporwaveColors.neonCyan)

                        Text("Processing...")
                            .font(VaporwaveTypography.caption())
                            .foregroundColor(VaporwaveColors.neonCyan)
                    }
                    .padding(.horizontal, VaporwaveSpacing.md)
                    .padding(.vertical, VaporwaveSpacing.sm)
                    .glassCard()
                }

                // Bio Sync
                Button(action: { aiEngine.bioSyncEnabled.toggle() }) {
                    HStack(spacing: VaporwaveSpacing.sm) {
                        Image(systemName: "heart.fill")
                        Text("Bio")
                    }
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(aiEngine.bioSyncEnabled ? VaporwaveColors.neonPink : VaporwaveColors.textTertiary)
                }
                .padding(.horizontal, VaporwaveSpacing.md)
                .padding(.vertical, VaporwaveSpacing.sm)
                .background(aiEngine.bioSyncEnabled ? VaporwaveColors.neonPink.opacity(0.2) : Color.clear)
                .glassCard()

                // History
                Button(action: { showHistory = true }) {
                    Image(systemName: "clock.arrow.circlepath")
                        .foregroundColor(VaporwaveColors.textSecondary)
                }
            }
        }
        .padding(VaporwaveSpacing.md)
    }

    // MARK: - Category Selector

    private var categorySelector: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: VaporwaveSpacing.sm) {
                ForEach(AICategory.allCases, id: \.self) { category in
                    Button(action: {
                        withAnimation(VaporwaveAnimation.smooth) {
                            selectedCategory = category
                        }
                    }) {
                        HStack(spacing: VaporwaveSpacing.sm) {
                            Image(systemName: category.icon)
                            Text(category.name)
                        }
                        .font(VaporwaveTypography.caption())
                        .foregroundColor(selectedCategory == category ? VaporwaveColors.deepBlack : VaporwaveColors.textSecondary)
                        .padding(.horizontal, VaporwaveSpacing.md)
                        .padding(.vertical, VaporwaveSpacing.sm)
                        .background(
                            Capsule()
                                .fill(selectedCategory == category ? category.color : Color.clear)
                        )
                        .overlay(
                            Capsule()
                                .stroke(selectedCategory == category ? category.color : VaporwaveColors.textTertiary.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .neonGlow(color: selectedCategory == category ? category.color : .clear, radius: 6)
                }
            }
            .padding(.horizontal, VaporwaveSpacing.md)
            .padding(.vertical, VaporwaveSpacing.sm)
        }
    }

    // MARK: - Active Tool Panel

    private var activeToolPanel: some View {
        VStack(spacing: VaporwaveSpacing.md) {
            HStack {
                Image(systemName: selectedCategory.icon)
                    .font(.system(size: 24))
                    .foregroundColor(selectedCategory.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(selectedCategory.name)
                        .font(VaporwaveTypography.body())
                        .foregroundColor(VaporwaveColors.textPrimary)

                    Text(selectedCategory.description)
                        .font(VaporwaveTypography.caption())
                        .foregroundColor(VaporwaveColors.textTertiary)
                }

                Spacer()

                // Intelligence Level
                VStack(alignment: .trailing, spacing: 2) {
                    Text("SI Level")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)

                    HStack(spacing: 2) {
                        ForEach(0..<5) { i in
                            Circle()
                                .fill(i < aiEngine.intelligenceLevel ? selectedCategory.color : VaporwaveColors.textTertiary.opacity(0.3))
                                .frame(width: 8, height: 8)
                        }
                    }
                }
            }

            // Category-Specific Controls
            switch selectedCategory {
            case .composition:
                compositionControls
            case .mixing:
                mixingControls
            case .video:
                videoControls
            case .visuals:
                visualsControls
            case .voiceClone:
                voiceCloneControls
            case .soundDesign:
                soundDesignControls
            case .mastering:
                masteringControls
            case .analysis:
                analysisControls
            }
        }
        .padding(VaporwaveSpacing.md)
        .glassCard()
    }

    // MARK: - Category-Specific Controls

    private var compositionControls: some View {
        VStack(spacing: VaporwaveSpacing.md) {
            HStack {
                VStack(alignment: .leading, spacing: VaporwaveSpacing.sm) {
                    Text("Style")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)

                    Picker("Style", selection: $aiEngine.compositionStyle) {
                        Text("Ambient").tag("ambient")
                        Text("Electronic").tag("electronic")
                        Text("Orchestral").tag("orchestral")
                        Text("Jazz").tag("jazz")
                        Text("Bio-Reactive").tag("bio")
                    }
                    .pickerStyle(.menu)
                }

                VStack(alignment: .leading, spacing: VaporwaveSpacing.sm) {
                    Text("Key")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)

                    Picker("Key", selection: $aiEngine.key) {
                        ForEach(["C", "D", "E", "F", "G", "A", "B"], id: \.self) { key in
                            Text(key).tag(key)
                        }
                    }
                    .pickerStyle(.menu)
                }

                VStack(alignment: .leading, spacing: VaporwaveSpacing.sm) {
                    Text("BPM")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)

                    HStack {
                        Text("\(Int(aiEngine.targetBPM))")
                            .font(VaporwaveTypography.dataSmall())
                            .foregroundColor(VaporwaveColors.neonCyan)

                        Slider(value: $aiEngine.targetBPM, in: 60...180)
                            .accentColor(VaporwaveColors.neonCyan)
                    }
                }
            }

            // Generate Button
            Button(action: { aiEngine.generateComposition() }) {
                HStack {
                    Image(systemName: "wand.and.stars")
                    Text("Generate Composition")
                }
                .font(VaporwaveTypography.body())
                .foregroundColor(VaporwaveColors.deepBlack)
                .frame(maxWidth: .infinity)
                .padding(VaporwaveSpacing.md)
                .background(VaporwaveColors.neonCyan)
                .cornerRadius(12)
            }
            .neonGlow(color: VaporwaveColors.neonCyan, radius: 8)
        }
    }

    private var mixingControls: some View {
        VStack(spacing: VaporwaveSpacing.md) {
            // Mix Analysis
            HStack(spacing: VaporwaveSpacing.lg) {
                MixAnalysisBar(label: "Balance", value: aiEngine.mixBalance, color: VaporwaveColors.neonCyan)
                MixAnalysisBar(label: "Width", value: aiEngine.mixWidth, color: VaporwaveColors.neonPink)
                MixAnalysisBar(label: "Depth", value: aiEngine.mixDepth, color: VaporwaveColors.neonPurple)
                MixAnalysisBar(label: "Clarity", value: aiEngine.mixClarity, color: VaporwaveColors.coherenceHigh)
            }

            HStack(spacing: VaporwaveSpacing.md) {
                Button(action: { aiEngine.analyzeMix() }) {
                    HStack {
                        Image(systemName: "waveform.badge.magnifyingglass")
                        Text("Analyze Mix")
                    }
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.neonCyan)
                }
                .padding(.horizontal, VaporwaveSpacing.md)
                .padding(.vertical, VaporwaveSpacing.sm)
                .glassCard()

                Button(action: { aiEngine.autoMix() }) {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text("Auto Mix")
                    }
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.deepBlack)
                    .padding(.horizontal, VaporwaveSpacing.md)
                    .padding(.vertical, VaporwaveSpacing.sm)
                    .background(VaporwaveColors.neonPurple)
                    .cornerRadius(16)
                }
                .neonGlow(color: VaporwaveColors.neonPurple, radius: 6)

                Button(action: { aiEngine.suggestFixes() }) {
                    HStack {
                        Image(systemName: "lightbulb.fill")
                        Text("Suggest Fixes")
                    }
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.coral)
                }
                .padding(.horizontal, VaporwaveSpacing.md)
                .padding(.vertical, VaporwaveSpacing.sm)
                .glassCard()
            }
        }
    }

    private var videoControls: some View {
        VStack(spacing: VaporwaveSpacing.md) {
            // Video AI Features
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: VaporwaveSpacing.sm) {
                VideoAIFeatureButton(icon: "wand.and.stars", title: "Auto Edit", subtitle: "Beat-sync cuts") {
                    aiEngine.autoEditVideo()
                }
                VideoAIFeatureButton(icon: "paintbrush.fill", title: "Style Transfer", subtitle: "Apply AI styles") {
                    aiEngine.styleTransferVideo()
                }
                VideoAIFeatureButton(icon: "arrow.up.left.and.arrow.down.right", title: "Upscale", subtitle: "4K/8K AI") {
                    aiEngine.upscaleVideo()
                }
                VideoAIFeatureButton(icon: "person.crop.rectangle", title: "Face AI", subtitle: "Beauty & relighting") {
                    aiEngine.faceAIVideo()
                }
            }

            // Text to Video
            HStack {
                TextField("Describe your video...", text: $aiEngine.videoPrompt)
                    .textFieldStyle(.plain)
                    .font(VaporwaveTypography.body())
                    .foregroundColor(VaporwaveColors.textPrimary)
                    .padding(VaporwaveSpacing.md)
                    .background(VaporwaveColors.deepBlack.opacity(0.5))
                    .cornerRadius(8)

                Button(action: { aiEngine.generateVideo() }) {
                    Image(systemName: "sparkles")
                        .foregroundColor(VaporwaveColors.deepBlack)
                        .padding(VaporwaveSpacing.md)
                        .background(VaporwaveColors.neonPink)
                        .cornerRadius(8)
                }
                .neonGlow(color: VaporwaveColors.neonPink, radius: 6)
            }
        }
    }

    private var visualsControls: some View {
        VStack(spacing: VaporwaveSpacing.md) {
            // Visual Mode Selector
            HStack {
                Text("Visual Mode")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textTertiary)

                Spacer()

                Picker("Mode", selection: $aiEngine.visualMode) {
                    Text("Sacred Geometry").tag("sacred")
                    Text("Fractals").tag("fractals")
                    Text("Particles").tag("particles")
                    Text("Quantum").tag("quantum")
                    Text("Bio-Reactive").tag("bio")
                }
                .pickerStyle(.menu)
            }

            // Bio Coupling Strength
            HStack {
                Text("Bio Coupling")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textTertiary)

                Slider(value: $aiEngine.bioCoupling, in: 0...1)
                    .accentColor(VaporwaveColors.neonPink)

                Text("\(Int(aiEngine.bioCoupling * 100))%")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.neonPink)
            }

            Button(action: { aiEngine.generateVisuals() }) {
                HStack {
                    Image(systemName: "eye")
                    Text("Generate Visuals")
                }
                .font(VaporwaveTypography.body())
                .foregroundColor(VaporwaveColors.deepBlack)
                .frame(maxWidth: .infinity)
                .padding(VaporwaveSpacing.md)
                .background(VaporwaveColors.lavender)
                .cornerRadius(12)
            }
            .neonGlow(color: VaporwaveColors.lavender, radius: 8)
        }
    }

    private var voiceCloneControls: some View {
        VStack(spacing: VaporwaveSpacing.md) {
            // Voice Models
            VStack(alignment: .leading, spacing: VaporwaveSpacing.sm) {
                Text("Voice Model")
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: VaporwaveSpacing.sm) {
                        ForEach(aiEngine.voiceModels, id: \.self) { model in
                            VoiceModelChip(name: model, isSelected: aiEngine.selectedVoiceModel == model) {
                                aiEngine.selectedVoiceModel = model
                            }
                        }

                        Button(action: { aiEngine.trainVoiceModel() }) {
                            HStack {
                                Image(systemName: "plus")
                                Text("Train New")
                            }
                            .font(VaporwaveTypography.label())
                            .foregroundColor(VaporwaveColors.neonCyan)
                            .padding(.horizontal, VaporwaveSpacing.md)
                            .padding(.vertical, VaporwaveSpacing.sm)
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(VaporwaveColors.neonCyan, style: StrokeStyle(lineWidth: 1, dash: [4]))
                            )
                        }
                    }
                }
            }

            // Clone Controls
            HStack(spacing: VaporwaveSpacing.md) {
                Button(action: { aiEngine.recordVoiceSample() }) {
                    HStack {
                        Image(systemName: "mic.fill")
                        Text("Record Sample")
                    }
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.neonPink)
                }
                .padding(.horizontal, VaporwaveSpacing.md)
                .padding(.vertical, VaporwaveSpacing.sm)
                .glassCard()

                Button(action: { aiEngine.synthesizeVoice() }) {
                    HStack {
                        Image(systemName: "waveform.and.person.filled")
                        Text("Synthesize")
                    }
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.deepBlack)
                    .padding(.horizontal, VaporwaveSpacing.md)
                    .padding(.vertical, VaporwaveSpacing.sm)
                    .background(VaporwaveColors.coral)
                    .cornerRadius(16)
                }
                .neonGlow(color: VaporwaveColors.coral, radius: 6)
            }
        }
    }

    private var soundDesignControls: some View {
        VStack(spacing: VaporwaveSpacing.md) {
            // Sound DNA
            VStack(alignment: .leading, spacing: VaporwaveSpacing.sm) {
                Text("Sound DNA (Genetic Synthesis)")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textTertiary)

                HStack(spacing: VaporwaveSpacing.md) {
                    ForEach(0..<8, id: \.self) { i in
                        VStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(VaporwaveColors.neonCyan)
                                .frame(width: 20, height: CGFloat.random(in: 20...60))

                            Text("H\(i+1)")
                                .font(VaporwaveTypography.label())
                                .foregroundColor(VaporwaveColors.textTertiary)
                        }
                    }
                }
            }
            .padding(VaporwaveSpacing.sm)
            .glassCard()

            HStack(spacing: VaporwaveSpacing.md) {
                Button(action: { aiEngine.plantSeed() }) {
                    HStack {
                        Image(systemName: "leaf.fill")
                        Text("Plant Seed")
                    }
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.coherenceHigh)
                }
                .padding(.horizontal, VaporwaveSpacing.md)
                .padding(.vertical, VaporwaveSpacing.sm)
                .glassCard()

                Button(action: { aiEngine.mutateSound() }) {
                    HStack {
                        Image(systemName: "wand.and.rays")
                        Text("Mutate")
                    }
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.neonPurple)
                }
                .padding(.horizontal, VaporwaveSpacing.md)
                .padding(.vertical, VaporwaveSpacing.sm)
                .glassCard()

                Button(action: { aiEngine.breedSound() }) {
                    HStack {
                        Image(systemName: "arrow.triangle.merge")
                        Text("Breed")
                    }
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.neonPink)
                }
                .padding(.horizontal, VaporwaveSpacing.md)
                .padding(.vertical, VaporwaveSpacing.sm)
                .glassCard()
            }
        }
    }

    private var masteringControls: some View {
        VStack(spacing: VaporwaveSpacing.md) {
            // LUFS Meter
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Integrated LUFS")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)

                    Text(String(format: "%.1f", aiEngine.integratedLUFS))
                        .font(VaporwaveTypography.dataSmall())
                        .foregroundColor(VaporwaveColors.neonCyan)
                }

                Spacer()

                VStack(alignment: .center, spacing: 2) {
                    Text("Target")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)

                    Picker("", selection: $aiEngine.targetLUFS) {
                        Text("-14 (Streaming)").tag(-14.0)
                        Text("-16 (Broadcast)").tag(-16.0)
                        Text("-23 (Film)").tag(-23.0)
                    }
                    .pickerStyle(.menu)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("True Peak")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)

                    Text(String(format: "%.1f dB", aiEngine.truePeak))
                        .font(VaporwaveTypography.dataSmall())
                        .foregroundColor(aiEngine.truePeak > -1 ? VaporwaveColors.coherenceLow : VaporwaveColors.coherenceHigh)
                }
            }
            .padding(VaporwaveSpacing.md)
            .glassCard()

            Button(action: { aiEngine.autoMaster() }) {
                HStack {
                    Image(systemName: "sparkles")
                    Text("AI Auto-Master")
                }
                .font(VaporwaveTypography.body())
                .foregroundColor(VaporwaveColors.deepBlack)
                .frame(maxWidth: .infinity)
                .padding(VaporwaveSpacing.md)
                .background(VaporwaveGradients.neon)
                .cornerRadius(12)
            }
            .neonGlow(color: VaporwaveColors.neonPink, radius: 8)
        }
    }

    private var analysisControls: some View {
        VStack(spacing: VaporwaveSpacing.md) {
            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: VaporwaveSpacing.sm) {
                AnalysisButton(icon: "waveform.badge.magnifyingglass", title: "Spectrum", subtitle: "Frequency analysis") {
                    aiEngine.analyzeSpectrum()
                }
                AnalysisButton(icon: "music.note.list", title: "Key/BPM", subtitle: "Detect key & tempo") {
                    aiEngine.detectKeyBPM()
                }
                AnalysisButton(icon: "heart.text.square", title: "Bio Correlation", subtitle: "Coherence patterns") {
                    aiEngine.analyzeBioCorrelation()
                }
                AnalysisButton(icon: "chart.xyaxis.line", title: "Reference Match", subtitle: "Compare to reference") {
                    aiEngine.referenceMatch()
                }
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActionsGrid: some View {
        VStack(alignment: .leading, spacing: VaporwaveSpacing.sm) {
            VaporwaveSectionHeader("QUICK ACTIONS", icon: "bolt.fill")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: VaporwaveSpacing.sm) {
                    QuickActionCard(icon: "wand.and.stars", title: "One-Tap Mix", color: VaporwaveColors.neonCyan) {
                        aiEngine.oneTapMix()
                    }
                    QuickActionCard(icon: "sparkles", title: "Bio Enhance", color: VaporwaveColors.neonPink) {
                        aiEngine.bioEnhance()
                    }
                    QuickActionCard(icon: "music.note.tv", title: "Video Sync", color: VaporwaveColors.neonPurple) {
                        aiEngine.videoSync()
                    }
                    QuickActionCard(icon: "speaker.wave.3.fill", title: "Loudness Fix", color: VaporwaveColors.coral) {
                        aiEngine.loudnessFix()
                    }
                    QuickActionCard(icon: "paintbrush.pointed.fill", title: "Style Match", color: VaporwaveColors.lavender) {
                        aiEngine.styleMatch()
                    }
                }
            }
        }
    }

    // MARK: - AI Tools Section

    private var aiToolsSection: some View {
        VStack(alignment: .leading, spacing: VaporwaveSpacing.sm) {
            VaporwaveSectionHeader("ECHOELTOOLS", icon: "cpu")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible()), GridItem(.flexible())], spacing: VaporwaveSpacing.sm) {
                ForEach(EchoelTool.allCases, id: \.self) { tool in
                    EchoelToolCard(tool: tool) {
                        aiEngine.activateTool(tool)
                    }
                }
            }
        }
    }

    // MARK: - Output Section

    private var outputSection: some View {
        VStack(alignment: .leading, spacing: VaporwaveSpacing.sm) {
            HStack {
                VaporwaveSectionHeader("AI OUTPUT", icon: "checkmark.circle")

                Spacer()

                Button(action: { aiEngine.clearOutput() }) {
                    Text("Clear")
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)
                }
            }

            VStack(alignment: .leading, spacing: VaporwaveSpacing.sm) {
                Text(aiEngine.outputTitle)
                    .font(VaporwaveTypography.body())
                    .foregroundColor(VaporwaveColors.textPrimary)

                Text(aiEngine.outputDescription)
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textSecondary)

                if !aiEngine.outputActions.isEmpty {
                    HStack(spacing: VaporwaveSpacing.sm) {
                        ForEach(aiEngine.outputActions, id: \.self) { action in
                            Button(action: { aiEngine.performOutputAction(action) }) {
                                Text(action)
                                    .font(VaporwaveTypography.caption())
                                    .foregroundColor(VaporwaveColors.neonCyan)
                            }
                            .padding(.horizontal, VaporwaveSpacing.md)
                            .padding(.vertical, VaporwaveSpacing.sm)
                            .glassCard()
                        }
                    }
                }
            }
            .padding(VaporwaveSpacing.md)
            .glassCard()
        }
    }

    // MARK: - Prompt Input Bar

    private var promptInputBar: some View {
        HStack(spacing: VaporwaveSpacing.sm) {
            TextField("Ask AI anything...", text: $promptText)
                .textFieldStyle(.plain)
                .font(VaporwaveTypography.body())
                .foregroundColor(VaporwaveColors.textPrimary)
                .padding(VaporwaveSpacing.md)
                .background(VaporwaveColors.deepBlack.opacity(0.5))
                .cornerRadius(20)

            Button(action: {
                if !promptText.isEmpty {
                    aiEngine.processPrompt(promptText)
                    promptText = ""
                }
            }) {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(promptText.isEmpty ? VaporwaveColors.textTertiary : VaporwaveColors.neonCyan)
            }
            .disabled(promptText.isEmpty)
            .neonGlow(color: promptText.isEmpty ? .clear : VaporwaveColors.neonCyan, radius: 8)
        }
        .padding(VaporwaveSpacing.md)
        .background(VaporwaveColors.deepBlack.opacity(0.8))
    }
}

// MARK: - Supporting Views

struct MixAnalysisBar: View {
    let label: String
    let value: Float
    let color: Color

    var body: some View {
        VStack(spacing: VaporwaveSpacing.xs) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(VaporwaveColors.deepBlack)
                    .frame(width: 30, height: 60)

                RoundedRectangle(cornerRadius: 4)
                    .fill(color)
                    .frame(width: 30, height: 60 * CGFloat(value))
            }

            Text(label)
                .font(VaporwaveTypography.label())
                .foregroundColor(VaporwaveColors.textTertiary)
        }
    }
}

struct VideoAIFeatureButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 20))
                    .foregroundColor(VaporwaveColors.neonPink)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(VaporwaveTypography.caption())
                        .foregroundColor(VaporwaveColors.textPrimary)

                    Text(subtitle)
                        .font(VaporwaveTypography.label())
                        .foregroundColor(VaporwaveColors.textTertiary)
                }

                Spacer()
            }
            .padding(VaporwaveSpacing.sm)
            .glassCard()
        }
    }
}

struct VoiceModelChip: View {
    let name: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(name)
                .font(VaporwaveTypography.caption())
                .foregroundColor(isSelected ? VaporwaveColors.deepBlack : VaporwaveColors.textSecondary)
                .padding(.horizontal, VaporwaveSpacing.md)
                .padding(.vertical, VaporwaveSpacing.sm)
                .background(isSelected ? VaporwaveColors.coral : Color.clear)
                .cornerRadius(16)
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(isSelected ? VaporwaveColors.coral : VaporwaveColors.textTertiary, lineWidth: 1)
                )
        }
    }
}

struct AnalysisButton: View {
    let icon: String
    let title: String
    let subtitle: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: VaporwaveSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(VaporwaveColors.neonCyan)

                Text(title)
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textPrimary)

                Text(subtitle)
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textTertiary)
            }
            .frame(maxWidth: .infinity)
            .padding(VaporwaveSpacing.md)
            .glassCard()
        }
    }
}

struct QuickActionCard: View {
    let icon: String
    let title: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: VaporwaveSpacing.sm) {
                Image(systemName: icon)
                    .font(.system(size: 24))
                    .foregroundColor(color)

                Text(title)
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textSecondary)
            }
            .frame(width: 80)
            .padding(VaporwaveSpacing.md)
            .glassCard()
        }
        .neonGlow(color: color, radius: 4)
    }
}

struct EchoelToolCard: View {
    let tool: EchoelTool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: VaporwaveSpacing.sm) {
                Image(systemName: tool.icon)
                    .font(.system(size: 20))
                    .foregroundColor(tool.color)

                Text(tool.name)
                    .font(VaporwaveTypography.label())
                    .foregroundColor(VaporwaveColors.textSecondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(VaporwaveSpacing.md)
            .glassCard()
        }
    }
}

struct AIHistorySheet: View {
    @Binding var isPresented: Bool
    let history: [AIHistoryItem]

    var body: some View {
        ZStack {
            VaporwaveGradients.background.ignoresSafeArea()

            VStack {
                HStack {
                    Text("AI HISTORY")
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
                    VStack(spacing: VaporwaveSpacing.sm) {
                        ForEach(history) { item in
                            HStack {
                                Image(systemName: item.icon)
                                    .foregroundColor(VaporwaveColors.neonCyan)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.action)
                                        .font(VaporwaveTypography.caption())
                                        .foregroundColor(VaporwaveColors.textPrimary)

                                    Text(item.timestamp)
                                        .font(VaporwaveTypography.label())
                                        .foregroundColor(VaporwaveColors.textTertiary)
                                }

                                Spacer()
                            }
                            .padding(VaporwaveSpacing.md)
                            .glassCard()
                        }
                    }
                    .padding(VaporwaveSpacing.md)
                }
            }
        }
    }
}

// MARK: - Models

@MainActor
class AISuperIntelligenceViewModel: ObservableObject {
    @Published var isProcessing = false
    @Published var bioSyncEnabled = true
    @Published var activeModels = 8
    @Published var intelligenceLevel = 4
    @Published var history: [AIHistoryItem] = []

    // Composition
    @Published var compositionStyle = "ambient"
    @Published var key = "C"
    @Published var targetBPM: Double = 120

    // Mixing
    @Published var mixBalance: Float = 0.75
    @Published var mixWidth: Float = 0.6
    @Published var mixDepth: Float = 0.8
    @Published var mixClarity: Float = 0.7

    // Video
    @Published var videoPrompt = ""

    // Visuals
    @Published var visualMode = "sacred"
    @Published var bioCoupling: Double = 0.7

    // Voice
    @Published var voiceModels = ["Natural", "Robot", "Clone 1", "Clone 2"]
    @Published var selectedVoiceModel = "Natural"

    // Mastering
    @Published var integratedLUFS: Double = -14.2
    @Published var truePeak: Double = -1.5
    @Published var targetLUFS: Double = -14.0

    // Output
    @Published var hasOutput = false
    @Published var outputTitle = ""
    @Published var outputDescription = ""
    @Published var outputActions: [String] = []

    func generateComposition() { isProcessing = true; addHistory("Generated composition", "music.note"); setOutput("Composition Ready", "8-bar \(compositionStyle) loop in \(key) at \(Int(targetBPM)) BPM", ["Apply", "Export MIDI", "Regenerate"]) }
    func analyzeMix() { addHistory("Analyzed mix", "waveform.badge.magnifyingglass") }
    func autoMix() { isProcessing = true; addHistory("Auto-mixed", "wand.and.stars"); setOutput("Mix Applied", "Balanced levels, added depth and clarity", ["Undo", "Fine-tune"]) }
    func suggestFixes() { addHistory("Suggested fixes", "lightbulb.fill"); setOutput("Suggestions", "1. Reduce bass 2dB\n2. Add high shelf +1.5dB\n3. Widen stereo image", ["Apply All", "Review"]) }
    func autoEditVideo() { isProcessing = true; addHistory("Auto-edited video", "film") }
    func styleTransferVideo() { addHistory("Style transfer", "paintbrush.fill") }
    func upscaleVideo() { addHistory("Upscaled video", "arrow.up.left.and.arrow.down.right") }
    func faceAIVideo() { addHistory("Face AI applied", "person.crop.rectangle") }
    func generateVideo() { isProcessing = true; addHistory("Generated video", "sparkles") }
    func generateVisuals() { isProcessing = true; addHistory("Generated visuals", "eye") }
    func trainVoiceModel() { addHistory("Training voice model", "waveform.and.person.filled") }
    func recordVoiceSample() { addHistory("Recording voice", "mic.fill") }
    func synthesizeVoice() { isProcessing = true; addHistory("Synthesized voice", "waveform.and.person.filled") }
    func plantSeed() { addHistory("Planted seed", "leaf.fill"); setOutput("Sound DNA Created", "New genetic sound seed planted. Evolve with Mutate or Breed.", ["Play", "Mutate", "Save"]) }
    func mutateSound() { addHistory("Mutated sound", "wand.and.rays") }
    func breedSound() { addHistory("Bred sound", "arrow.triangle.merge") }
    func autoMaster() { isProcessing = true; addHistory("Auto-mastered", "sparkles"); setOutput("Master Applied", "LUFS: -14.0, True Peak: -1.0 dB, Optimized for streaming", ["Export", "Compare A/B"]) }
    func analyzeSpectrum() { addHistory("Spectrum analysis", "waveform.badge.magnifyingglass") }
    func detectKeyBPM() { addHistory("Detected key/BPM", "music.note.list"); setOutput("Detection Complete", "Key: A minor\nBPM: 122.3\nTime Signature: 4/4", ["Apply to Project"]) }
    func analyzeBioCorrelation() { addHistory("Bio correlation", "heart.text.square") }
    func referenceMatch() { addHistory("Reference match", "chart.xyaxis.line") }
    func oneTapMix() { isProcessing = true; addHistory("One-tap mix", "bolt.fill") }
    func bioEnhance() { addHistory("Bio enhance", "heart.fill") }
    func videoSync() { addHistory("Video sync", "music.note.tv") }
    func loudnessFix() { addHistory("Loudness fix", "speaker.wave.3.fill") }
    func styleMatch() { addHistory("Style match", "paintbrush.pointed.fill") }
    func activateTool(_ tool: EchoelTool) { addHistory("Activated \(tool.name)", tool.icon) }
    func processPrompt(_ prompt: String) { isProcessing = true; addHistory("Prompt: \(prompt)", "text.bubble"); setOutput("AI Response", "Processing your request: \"\(prompt)\"", ["Apply", "Refine"]) }
    func clearOutput() { hasOutput = false }
    func performOutputAction(_ action: String) { addHistory("Action: \(action)", "hand.tap") }

    private func addHistory(_ action: String, _ icon: String) {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        history.insert(AIHistoryItem(action: action, icon: icon, timestamp: formatter.string(from: Date())), at: 0)
        DispatchQueue.main.asyncAfter(deadline: .now() + 1) { self.isProcessing = false }
    }

    private func setOutput(_ title: String, _ description: String, _ actions: [String]) {
        outputTitle = title
        outputDescription = description
        outputActions = actions
        hasOutput = true
    }
}

struct AIHistoryItem: Identifiable {
    let id = UUID()
    let action: String
    let icon: String
    let timestamp: String
}

enum AICategory: String, CaseIterable {
    case composition = "Composition"
    case mixing = "Mixing"
    case video = "Video"
    case visuals = "Visuals"
    case voiceClone = "Voice"
    case soundDesign = "Sound Design"
    case mastering = "Mastering"
    case analysis = "Analysis"

    var name: String { rawValue }

    var icon: String {
        switch self {
        case .composition: return "music.note"
        case .mixing: return "slider.horizontal.3"
        case .video: return "film"
        case .visuals: return "eye"
        case .voiceClone: return "waveform.and.person.filled"
        case .soundDesign: return "waveform"
        case .mastering: return "dial.high"
        case .analysis: return "waveform.badge.magnifyingglass"
        }
    }

    var color: Color {
        switch self {
        case .composition: return VaporwaveColors.neonCyan
        case .mixing: return VaporwaveColors.neonPurple
        case .video: return VaporwaveColors.neonPink
        case .visuals: return VaporwaveColors.lavender
        case .voiceClone: return VaporwaveColors.coral
        case .soundDesign: return VaporwaveColors.coherenceHigh
        case .mastering: return VaporwaveColors.coherenceMedium
        case .analysis: return VaporwaveColors.hrv
        }
    }

    var description: String {
        switch self {
        case .composition: return "AI-powered music composition and arrangement"
        case .mixing: return "Intelligent mixing, balance, and EQ"
        case .video: return "AI video editing, style transfer, upscaling"
        case .visuals: return "Generate bio-reactive visuals and shaders"
        case .voiceClone: return "Voice synthesis and cloning"
        case .soundDesign: return "Genetic synthesis and sound evolution"
        case .mastering: return "AI mastering and loudness optimization"
        case .analysis: return "Audio analysis and detection"
        }
    }
}

enum EchoelTool: String, CaseIterable {
    case warmth = "Warmth"
    case seed = "Seed"
    case pulse = "Pulse"
    case vibe = "Vibe"
    case console = "Console"
    case punisher = "Punisher"
    case timeMachine = "Time"
    case voiceChanger = "Voice"
    case smartMixer = "Mixer"

    var name: String { rawValue }

    var icon: String {
        switch self {
        case .warmth: return "flame.fill"
        case .seed: return "leaf.fill"
        case .pulse: return "heart.fill"
        case .vibe: return "sparkles"
        case .console: return "dial.high"
        case .punisher: return "bolt.fill"
        case .timeMachine: return "clock.arrow.2.circlepath"
        case .voiceChanger: return "waveform.and.person.filled"
        case .smartMixer: return "slider.vertical.3"
        }
    }

    var color: Color {
        switch self {
        case .warmth: return VaporwaveColors.coral
        case .seed: return VaporwaveColors.coherenceHigh
        case .pulse: return VaporwaveColors.neonPink
        case .vibe: return VaporwaveColors.neonPurple
        case .console: return VaporwaveColors.neonCyan
        case .punisher: return VaporwaveColors.coherenceLow
        case .timeMachine: return VaporwaveColors.lavender
        case .voiceChanger: return VaporwaveColors.coral
        case .smartMixer: return VaporwaveColors.neonCyan
        }
    }
}

#Preview {
    AISuperIntelligenceView()
}
