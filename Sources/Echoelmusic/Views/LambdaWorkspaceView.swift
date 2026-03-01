import SwiftUI
import Combine

// MARK: - Lambda Workspace View
// Bio-reactive environment dashboard — connects UniversalEnvironmentEngine,
// EnvironmentLoopProcessor, LambdaChain, and LoopEngine into one unified interface.
// Shows real-time environment state, lambda chain outputs, loop status,
// and self-healing transformation log.

struct LambdaWorkspaceView: View {

    @ObservedObject private var envEngine = UniversalEnvironmentEngine.shared
    @ObservedObject private var loopProcessor = EnvironmentLoopProcessor.shared
    @ObservedObject private var selfHealing = SelfHealingCodeTransformation.shared

    @State private var selectedEnvironment: EnvironmentClass = .home
    @State private var showPresets = false
    @State private var showTransformLog = false

    var body: some View {
        ZStack {
            EchoelBrand.bgDeep
                .ignoresSafeArea()

            #if os(iOS)
            ScrollView(.vertical, showsIndicators: false) {
                mainContent
            }
            #else
            mainContent
            #endif
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: EchoelSpacing.lg) {
            headerBar

            HStack(alignment: .top, spacing: EchoelSpacing.lg) {
                VStack(spacing: EchoelSpacing.lg) {
                    environmentPanel
                    lambdaChainPanel
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: EchoelSpacing.lg) {
                    loopStatusPanel
                    comfortPanel
                    selfHealingPanel
                }
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, EchoelSpacing.lg)

            Spacer(minLength: 0)
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack(spacing: EchoelSpacing.md) {
            VStack(alignment: .leading, spacing: 2) {
                Text("LAMBDA MODE")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(EchoelBrand.textPrimary)
                    .tracking(3)

                Text("Bio-Reactive Environment Engine")
                    .font(.system(size: 11))
                    .foregroundColor(EchoelBrand.textTertiary)
            }

            Spacer()

            // Loop Processor Status
            HStack(spacing: EchoelSpacing.sm) {
                Circle()
                    .fill(loopProcessor.loopState == .running ? EchoelBrand.coherenceHigh : EchoelBrand.textTertiary)
                    .frame(width: 8, height: 8)

                Text(loopProcessor.loopState.rawValue.uppercased())
                    .font(.system(size: 10, weight: .semibold, design: .monospaced))
                    .foregroundColor(EchoelBrand.textSecondary)
            }
            .padding(.horizontal, EchoelSpacing.md)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 6)
                    .fill(EchoelBrand.bgElevated)
            )

            // Start/Stop Button
            Button(action: toggleLoopProcessor) {
                Text(loopProcessor.loopState == .running ? "STOP" : "START")
                    .font(.system(size: 11, weight: .bold, design: .monospaced))
                    .foregroundColor(loopProcessor.loopState == .running ? EchoelBrand.coral : EchoelBrand.coherenceHigh)
                    .padding(.horizontal, EchoelSpacing.lg)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(EchoelBrand.bgElevated)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(loopProcessor.loopState == .running ? EchoelBrand.coral.opacity(0.5) : EchoelBrand.coherenceHigh.opacity(0.5), lineWidth: 1)
                            )
                    )
            }
            .buttonStyle(.plain)

            // Hz Display
            VStack(spacing: 0) {
                Text(String(format: "%.0f", loopProcessor.targetHz))
                    .font(.system(size: 14, weight: .medium, design: .monospaced))
                    .foregroundColor(EchoelBrand.textPrimary)
                Text("Hz")
                    .font(.system(size: 8))
                    .foregroundColor(EchoelBrand.textTertiary)
            }
        }
        .padding(.horizontal, EchoelSpacing.lg)
        .padding(.vertical, EchoelSpacing.md)
        .background(
            EchoelBrand.bgSurface
                .overlay(
                    Rectangle()
                        .fill(EchoelBrand.border)
                        .frame(height: 1),
                    alignment: .bottom
                )
        )
    }

    // MARK: - Environment Panel

    private var environmentPanel: some View {
        VStack(alignment: .leading, spacing: EchoelSpacing.md) {
            HStack {
                Text("ENVIRONMENT")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(EchoelBrand.textTertiary)
                    .tracking(2)

                Spacer()

                Button(action: { showPresets.toggle() }) {
                    Text("PRESETS")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundColor(EchoelBrand.primary)
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showPresets) {
                    environmentPresetPicker
                }
            }

            // Current Environment
            HStack(spacing: EchoelSpacing.md) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(envEngine.currentEnvironment.rawValue)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(EchoelBrand.textPrimary)

                    Text(envEngine.currentEnvironment.domain.rawValue)
                        .font(.system(size: 12))
                        .foregroundColor(EchoelBrand.textSecondary)
                }

                Spacer()

                // Domain Color Indicator
                let domainColor = envEngine.currentEnvironment.domain.baseColor
                Circle()
                    .fill(Color(red: Double(domainColor.r), green: Double(domainColor.g), blue: Double(domainColor.b)))
                    .frame(width: 24, height: 24)
                    .overlay(Circle().stroke(EchoelBrand.border, lineWidth: 1))
            }

            // Environment Selector Grid
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], spacing: 6) {
                ForEach(EnvironmentDomain.allCases, id: \.self) { domain in
                    Button(action: {
                        if let first = EnvironmentClass.allCases.first(where: { $0.domain == domain }) {
                            envEngine.setEnvironment(first)
                        }
                    }) {
                        Text(domain.rawValue)
                            .font(.system(size: 9, weight: .medium))
                            .foregroundColor(envEngine.currentEnvironment.domain == domain ? EchoelBrand.textPrimary : EchoelBrand.textTertiary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(envEngine.currentEnvironment.domain == domain ? EchoelBrand.bgElevated : .clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(EchoelSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: EchoelRadius.md)
                .fill(EchoelBrand.bgSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: EchoelRadius.md)
                        .stroke(EchoelBrand.border, lineWidth: 1)
                )
        )
    }

    // MARK: - Lambda Chain Panel

    private var lambdaChainPanel: some View {
        VStack(alignment: .leading, spacing: EchoelSpacing.md) {
            HStack {
                Text("LAMBDA CHAIN")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(EchoelBrand.textTertiary)
                    .tracking(2)

                Spacer()

                Toggle("Auto", isOn: $loopProcessor.autoSelectChain)
                    .font(.system(size: 10))
                    .foregroundColor(EchoelBrand.textSecondary)
                    .toggleStyle(.switch)
                    .controlSize(.mini)
            }

            // Active Operators
            ForEach(Array(loopProcessor.activeLambdaChain.operators.enumerated()), id: \.offset) { index, op in
                HStack(spacing: EchoelSpacing.sm) {
                    Text("\(index + 1)")
                        .font(.system(size: 9, weight: .bold, design: .monospaced))
                        .foregroundColor(EchoelBrand.textTertiary)
                        .frame(width: 16)

                    Text(op.name)
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(EchoelBrand.textPrimary)
                        .lineLimit(1)

                    Spacer()
                }
                .padding(.vertical, 2)
            }

            Divider().background(EchoelBrand.border)

            // Lambda Output Values
            let result = loopProcessor.currentLambdaResult
            HStack(spacing: EchoelSpacing.lg) {
                lambdaMetric("Coherence", value: String(format: "%.2f", result.coherenceModifier))
                lambdaMetric("Freq", value: String(format: "%.1f Hz", result.frequency))
                lambdaMetric("Reverb", value: String(format: "%.0f%%", result.reverbMix * 100))
                lambdaMetric("Spatial", value: String(format: "%.0f%%", result.spatialWidth * 100))
            }
        }
        .padding(EchoelSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: EchoelRadius.md)
                .fill(EchoelBrand.bgSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: EchoelRadius.md)
                        .stroke(EchoelBrand.border, lineWidth: 1)
                )
        )
    }

    private func lambdaMetric(_ label: String, value: String) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(EchoelBrand.textPrimary)
            Text(label)
                .font(.system(size: 8, weight: .medium))
                .foregroundColor(EchoelBrand.textTertiary)
        }
    }

    // MARK: - Loop Status Panel

    private var loopStatusPanel: some View {
        VStack(alignment: .leading, spacing: EchoelSpacing.md) {
            Text("LOOP STATUS")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(EchoelBrand.textTertiary)
                .tracking(2)

            let stats = loopProcessor.stats
            VStack(spacing: EchoelSpacing.sm) {
                loopStat("Total Ticks", value: "\(stats.totalTicks)")
                loopStat("Avg Latency", value: String(format: "%.2f ms", stats.averageLatencyMs))
                loopStat("Max Latency", value: String(format: "%.2f ms", stats.maxLatencyMs))
                loopStat("Dropped Frames", value: "\(stats.droppedFrames)")
                loopStat("Env Changes", value: "\(stats.environmentChanges)")
                loopStat("Uptime", value: String(format: "%.0fs", stats.uptimeSeconds))
            }
        }
        .padding(EchoelSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: EchoelRadius.md)
                .fill(EchoelBrand.bgSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: EchoelRadius.md)
                        .stroke(EchoelBrand.border, lineWidth: 1)
                )
        )
    }

    private func loopStat(_ label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 10))
                .foregroundColor(EchoelBrand.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(EchoelBrand.textPrimary)
        }
    }

    // MARK: - Comfort Panel

    private var comfortPanel: some View {
        VStack(alignment: .leading, spacing: EchoelSpacing.md) {
            Text("COMFORT SCORE")
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(EchoelBrand.textTertiary)
                .tracking(2)

            let comfort = envEngine.comfortScore

            // Comfort Bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(EchoelBrand.bgElevated)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(comfortColor(comfort))
                        .frame(width: geo.size.width * CGFloat(comfort))
                }
            }
            .frame(height: 12)

            HStack {
                Text(String(format: "%.0f%%", comfort * 100))
                    .font(.system(size: 18, weight: .bold, design: .monospaced))
                    .foregroundColor(comfortColor(comfort))

                Spacer()

                Text("Affinity: \(String(format: "%.0f%%", envEngine.currentEnvironment.baseCoherenceAffinity * 100))")
                    .font(.system(size: 10))
                    .foregroundColor(EchoelBrand.textTertiary)
            }
        }
        .padding(EchoelSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: EchoelRadius.md)
                .fill(EchoelBrand.bgSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: EchoelRadius.md)
                        .stroke(EchoelBrand.border, lineWidth: 1)
                )
        )
    }

    private func comfortColor(_ comfort: Double) -> Color {
        if comfort > 0.7 { return EchoelBrand.coherenceHigh }
        else if comfort > 0.4 { return EchoelBrand.coherenceMedium }
        else { return EchoelBrand.coherenceLow }
    }

    // MARK: - Self-Healing Panel

    private var selfHealingPanel: some View {
        VStack(alignment: .leading, spacing: EchoelSpacing.md) {
            HStack {
                Text("SELF-HEALING")
                    .font(.system(size: 10, weight: .bold, design: .monospaced))
                    .foregroundColor(EchoelBrand.textTertiary)
                    .tracking(2)

                Spacer()

                Circle()
                    .fill(selfHealing.isActive ? EchoelBrand.coherenceHigh : EchoelBrand.textTertiary)
                    .frame(width: 6, height: 6)
            }

            HStack(spacing: EchoelSpacing.lg) {
                VStack(spacing: 2) {
                    Text(selfHealing.currentLevel.description)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(EchoelBrand.textPrimary)
                        .lineLimit(1)
                    Text("Level")
                        .font(.system(size: 8))
                        .foregroundColor(EchoelBrand.textTertiary)
                }

                VStack(spacing: 2) {
                    Text(String(format: "%.0f%%", selfHealing.coherenceStability * 100))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(EchoelBrand.textPrimary)
                    Text("Stability")
                        .font(.system(size: 8))
                        .foregroundColor(EchoelBrand.textTertiary)
                }

                VStack(spacing: 2) {
                    Text(String(format: "%.1f", selfHealing.transformationsPerMinute))
                        .font(.system(size: 11, weight: .medium, design: .monospaced))
                        .foregroundColor(EchoelBrand.textPrimary)
                    Text("T/min")
                        .font(.system(size: 8))
                        .foregroundColor(EchoelBrand.textTertiary)
                }
            }

            // Recent transformations
            if !selfHealing.transformationLog.isEmpty {
                Divider().background(EchoelBrand.border)

                ForEach(selfHealing.transformationLog.suffix(3)) { event in
                    HStack(spacing: EchoelSpacing.sm) {
                        Circle()
                            .fill(event.success ? EchoelBrand.coherenceHigh : EchoelBrand.coral)
                            .frame(width: 4, height: 4)

                        Text(event.action)
                            .font(.system(size: 9))
                            .foregroundColor(EchoelBrand.textSecondary)
                            .lineLimit(1)
                    }
                }
            }
        }
        .padding(EchoelSpacing.lg)
        .background(
            RoundedRectangle(cornerRadius: EchoelRadius.md)
                .fill(EchoelBrand.bgSurface)
                .overlay(
                    RoundedRectangle(cornerRadius: EchoelRadius.md)
                        .stroke(EchoelBrand.border, lineWidth: 1)
                )
        )
    }

    // MARK: - Environment Preset Picker

    private var environmentPresetPicker: some View {
        VStack(spacing: 0) {
            Text("Environment Presets")
                .font(.system(size: 12, weight: .semibold))
                .foregroundColor(EchoelBrand.textPrimary)
                .padding(EchoelSpacing.md)

            Divider().background(EchoelBrand.border)

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(EnvironmentPresetRegistry.all, id: \.name) { preset in
                        Button(action: {
                            envEngine.setEnvironment(preset.environmentClass)
                            showPresets = false
                        }) {
                            HStack {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(preset.name)
                                        .font(.system(size: 12, weight: .medium))
                                        .foregroundColor(EchoelBrand.textPrimary)
                                    Text(preset.description)
                                        .font(.system(size: 9))
                                        .foregroundColor(EchoelBrand.textTertiary)
                                        .lineLimit(1)
                                }
                                Spacer()
                            }
                            .padding(.horizontal, EchoelSpacing.md)
                            .padding(.vertical, EchoelSpacing.sm)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        Divider().background(EchoelBrand.border)
                    }
                }
            }
        }
        .frame(width: 300, height: 350)
        .background(EchoelBrand.bgDeep)
        .clipShape(RoundedRectangle(cornerRadius: EchoelRadius.md))
        .overlay(
            RoundedRectangle(cornerRadius: EchoelRadius.md)
                .stroke(EchoelBrand.border, lineWidth: 1)
        )
    }

    // MARK: - Actions

    private func toggleLoopProcessor() {
        if loopProcessor.loopState == .running {
            loopProcessor.stop()
        } else {
            loopProcessor.start()
        }
    }
}
