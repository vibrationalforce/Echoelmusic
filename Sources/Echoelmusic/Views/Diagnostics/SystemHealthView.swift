//
// SystemHealthView.swift
// Echoelmusic
//
// Real-time system health visualization powered by SelfHealingEngine
// Shows auto-healing events, flow state, and system metrics
//

import SwiftUI

struct SystemHealthView: View {

    // MARK: - Properties

    @EnvironmentObject var selfHealingEngine: SelfHealingEngine
    @Environment(\.dismiss) private var dismiss

    // MARK: - Body

    var body: some View {
        ZStack {
            VaporwaveGradients.background
                .ignoresSafeArea()

            ScrollView {
                VStack(spacing: VaporwaveSpacing.lg) {

                    // System Health Status
                    systemHealthCard

                    // Flow State
                    flowStateCard

                    // Intelligence Level
                    intelligenceCard

                    // Recent Healing Events
                    healingEventsCard

                    // Adaptive Parameters
                    adaptiveParametersCard

                }
                .padding(VaporwaveSpacing.lg)
            }
        }
        .navigationTitle("System Health")
        .navigationBarTitleDisplayMode(.inline)
    }

    // MARK: - System Health Card

    private var systemHealthCard: some View {
        VStack(alignment: .leading, spacing: VaporwaveSpacing.md) {
            // Header
            HStack(spacing: VaporwaveSpacing.sm) {
                Image(systemName: healthIcon)
                    .font(.system(size: 16))
                    .foregroundColor(healthColor)

                Text("SYSTEM HEALTH")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(VaporwaveColors.neonCyan)
                    .tracking(2)

                Spacer()

                // Status Badge
                HStack(spacing: 4) {
                    Circle()
                        .fill(healthColor)
                        .frame(width: 8, height: 8)

                    Text(selfHealingEngine.systemHealth.rawValue.uppercased())
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(healthColor)
                }
            }

            // Health Meter
            VStack(spacing: VaporwaveSpacing.sm) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        // Background
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.05))

                        // Fill
                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        healthColor.opacity(0.6),
                                        healthColor
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * CGFloat(healthPercentage))
                    }
                }
                .frame(height: 12)

                Text(healthDescription)
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textTertiary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(VaporwaveSpacing.md)
            .glassCard()
        }
    }

    // MARK: - Flow State Card

    private var flowStateCard: some View {
        VStack(alignment: .leading, spacing: VaporwaveSpacing.md) {
            // Header
            HStack(spacing: VaporwaveSpacing.sm) {
                Image(systemName: "waveform.path.ecg")
                    .font(.system(size: 16))
                    .foregroundColor(flowStateColor)

                Text("FLOW STATE")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(VaporwaveColors.neonPurple)
                    .tracking(2)

                Spacer()

                Text(selfHealingEngine.flowState.rawValue.uppercased())
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(flowStateColor)
            }

            // Flow State Indicator
            HStack(spacing: VaporwaveSpacing.sm) {
                ForEach(FlowState.allCases, id: \.self) { state in
                    VStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(selfHealingEngine.flowState == state ? flowStateColor : Color.white.opacity(0.1))
                            .frame(height: flowStateHeight(for: state))

                        Text(state.icon)
                            .font(.system(size: 10))
                            .foregroundColor(selfHealingEngine.flowState == state ? flowStateColor : VaporwaveColors.textTertiary)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(VaporwaveSpacing.md)
            .glassCard()

            Text(flowStateDescription)
                .font(VaporwaveTypography.caption())
                .foregroundColor(VaporwaveColors.textSecondary)
        }
    }

    // MARK: - Intelligence Card

    private var intelligenceCard: some View {
        VStack(alignment: .leading, spacing: VaporwaveSpacing.md) {
            // Header
            HStack(spacing: VaporwaveSpacing.sm) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 16))
                    .foregroundColor(VaporwaveColors.neonPink)

                Text("ADAPTIVE INTELLIGENCE")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(VaporwaveColors.neonPink)
                    .tracking(2)

                Spacer()

                Text("\(Int(selfHealingEngine.intelligenceLevel * 100))%")
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundColor(VaporwaveColors.neonPink)
            }

            // Intelligence Progress
            VStack(spacing: VaporwaveSpacing.sm) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.white.opacity(0.05))

                        RoundedRectangle(cornerRadius: 8)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        VaporwaveColors.neonPink.opacity(0.6),
                                        VaporwaveColors.neonPurple
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * CGFloat(min(selfHealingEngine.intelligenceLevel / 2.0, 1.0)))
                    }
                }
                .frame(height: 8)

                Text("Intelligence grows through successful auto-healing patterns")
                    .font(VaporwaveTypography.caption())
                    .foregroundColor(VaporwaveColors.textTertiary)
            }
            .padding(VaporwaveSpacing.md)
            .glassCard()
        }
    }

    // MARK: - Healing Events Card

    private var healingEventsCard: some View {
        VStack(alignment: .leading, spacing: VaporwaveSpacing.md) {
            // Header
            HStack(spacing: VaporwaveSpacing.sm) {
                Image(systemName: "sparkles")
                    .font(.system(size: 16))
                    .foregroundColor(VaporwaveColors.neonCyan)

                Text("AUTO-HEALING EVENTS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(VaporwaveColors.neonCyan)
                    .tracking(2)

                Spacer()

                Text("\(selfHealingEngine.healingEvents.count)")
                    .font(.system(size: 12, weight: .bold, design: .monospaced))
                    .foregroundColor(VaporwaveColors.neonCyan)
            }

            // Recent Events
            if selfHealingEngine.healingEvents.isEmpty {
                VStack(spacing: VaporwaveSpacing.sm) {
                    Image(systemName: "checkmark.circle")
                        .font(.system(size: 32))
                        .foregroundColor(VaporwaveColors.success)

                    Text("No Issues Detected")
                        .font(VaporwaveTypography.body())
                        .foregroundColor(VaporwaveColors.textPrimary)

                    Text("System running optimally")
                        .font(VaporwaveTypography.caption())
                        .foregroundColor(VaporwaveColors.textTertiary)
                }
                .frame(maxWidth: .infinity)
                .padding(VaporwaveSpacing.xl)
                .glassCard()
            } else {
                VStack(spacing: VaporwaveSpacing.sm) {
                    ForEach(selfHealingEngine.healingEvents.suffix(5).reversed(), id: \.id) { event in
                        healingEventRow(event)
                    }
                }
                .padding(VaporwaveSpacing.sm)
                .glassCard()
            }
        }
    }

    private func healingEventRow(_ event: HealingEvent) -> some View {
        HStack(spacing: VaporwaveSpacing.sm) {
            // Icon
            Image(systemName: event.wasSuccessful ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                .font(.system(size: 16))
                .foregroundColor(event.wasSuccessful ? VaporwaveColors.success : VaporwaveColors.warning)

            // Info
            VStack(alignment: .leading, spacing: 2) {
                Text(event.type.rawValue)
                    .font(VaporwaveTypography.body())
                    .foregroundColor(VaporwaveColors.textPrimary)

                if let message = event.message {
                    Text(message)
                        .font(VaporwaveTypography.caption())
                        .foregroundColor(VaporwaveColors.textTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Timestamp
            Text(timeAgo(event.timestamp))
                .font(.system(size: 10, design: .monospaced))
                .foregroundColor(VaporwaveColors.textTertiary)
        }
        .padding(VaporwaveSpacing.sm)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color.white.opacity(0.02))
        )
    }

    // MARK: - Adaptive Parameters Card

    private var adaptiveParametersCard: some View {
        VStack(alignment: .leading, spacing: VaporwaveSpacing.md) {
            // Header
            HStack(spacing: VaporwaveSpacing.sm) {
                Image(systemName: "slider.horizontal.3")
                    .font(.system(size: 16))
                    .foregroundColor(VaporwaveColors.lavender)

                Text("ADAPTIVE PARAMETERS")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundColor(VaporwaveColors.lavender)
                    .tracking(2)

                Spacer()
            }

            VStack(spacing: VaporwaveSpacing.sm) {
                parameterRow("Visual Quality", value: selfHealingEngine.adaptiveParameters.visualQuality)
                parameterRow("Audio Processing", value: selfHealingEngine.adaptiveParameters.audioProcessingLevel)
                parameterRow("Global Processing", value: selfHealingEngine.adaptiveParameters.globalProcessingLevel)

                if selfHealingEngine.adaptiveParameters.batterySaverMode {
                    HStack {
                        Image(systemName: "battery.25")
                            .foregroundColor(VaporwaveColors.warning)
                        Text("Battery Saver Mode Active")
                            .font(VaporwaveTypography.caption())
                            .foregroundColor(VaporwaveColors.warning)
                        Spacer()
                    }
                }
            }
            .padding(VaporwaveSpacing.md)
            .glassCard()
        }
    }

    private func parameterRow(_ name: String, value: Float) -> some View {
        HStack {
            Text(name)
                .font(VaporwaveTypography.caption())
                .foregroundColor(VaporwaveColors.textSecondary)

            Spacer()

            Text("\(Int(value * 100))%")
                .font(.system(size: 12, weight: .medium, design: .monospaced))
                .foregroundColor(VaporwaveColors.textPrimary)

            // Mini bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Color.white.opacity(0.1))

                    RoundedRectangle(cornerRadius: 2)
                        .fill(VaporwaveColors.lavender)
                        .frame(width: geometry.size.width * CGFloat(value))
                }
            }
            .frame(width: 60, height: 4)
        }
    }

    // MARK: - Computed Properties

    private var healthIcon: String {
        switch selfHealingEngine.systemHealth {
        case .optimal: return "checkmark.seal.fill"
        case .good: return "checkmark.circle.fill"
        case .degraded: return "exclamationmark.triangle.fill"
        case .critical: return "xmark.octagon.fill"
        case .unknown: return "questionmark.circle.fill"
        }
    }

    private var healthColor: Color {
        switch selfHealingEngine.systemHealth {
        case .optimal: return VaporwaveColors.coherenceHigh
        case .good: return VaporwaveColors.success
        case .degraded: return VaporwaveColors.warning
        case .critical: return VaporwaveColors.coral
        case .unknown: return VaporwaveColors.textTertiary
        }
    }

    private var healthPercentage: Float {
        switch selfHealingEngine.systemHealth {
        case .optimal: return 1.0
        case .good: return 0.75
        case .degraded: return 0.5
        case .critical: return 0.25
        case .unknown: return 0.0
        }
    }

    private var healthDescription: String {
        switch selfHealingEngine.systemHealth {
        case .optimal: return "All systems operating at peak performance"
        case .good: return "System running smoothly with minor optimizations"
        case .degraded: return "Performance reduced, auto-healing active"
        case .critical: return "Critical recovery mode engaged"
        case .unknown: return "System status unknown"
        }
    }

    private var flowStateColor: Color {
        switch selfHealingEngine.flowState {
        case .ultraFlow: return VaporwaveColors.coherenceHigh
        case .flow: return VaporwaveColors.neonCyan
        case .neutral: return VaporwaveColors.lavender
        case .stressed: return VaporwaveColors.warning
        case .recovery: return VaporwaveColors.coral
        case .emergency: return Color.red
        }
    }

    private var flowStateDescription: String {
        switch selfHealingEngine.flowState {
        case .ultraFlow: return "🌊 Maximum flow state - Everything synchronized perfectly"
        case .flow: return "✨ High flow state - Optimal performance achieved"
        case .neutral: return "⚡ Balanced state - Normal operation"
        case .stressed: return "⚠️ Stress detected - Optimizations applied"
        case .recovery: return "🔧 Recovery mode - Restoring optimal state"
        case .emergency: return "🚨 Emergency mode - Survival protocols active"
        }
    }

    private func flowStateHeight(for state: FlowState) -> CGFloat {
        let heights: [FlowState: CGFloat] = [
            .emergency: 20,
            .recovery: 35,
            .stressed: 50,
            .neutral: 65,
            .flow: 80,
            .ultraFlow: 100
        ]
        return heights[state] ?? 50
    }

    // MARK: - Helpers

    private func timeAgo(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)

        if interval < 60 {
            return "\(Int(interval))s"
        } else if interval < 3600 {
            return "\(Int(interval / 60))m"
        } else if interval < 86400 {
            return "\(Int(interval / 3600))h"
        } else {
            return "\(Int(interval / 86400))d"
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        SystemHealthView()
            .environmentObject(SelfHealingEngine.shared)
    }
}
