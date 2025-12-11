import SwiftUI
import Combine

/// Comprehensive Wise Mode Dashboard
/// Displays wisdom level, mode controls, and system integration status
struct WiseModeView: View {
    @StateObject private var wiseMode = WiseModeOrchestrator.shared

    @State private var showModeDetails = false
    @State private var showCircadianInfo = false
    @State private var selectedMode: WiseModeOrchestrator.WiseMode?

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header with Wisdom Level
                wisdomHeader

                // Mode Selector
                modeSelector

                // Current Mode Details
                currentModeCard

                // Transition Progress (if transitioning)
                if wiseMode.isTransitioning {
                    transitionProgress
                }

                // Circadian Info
                circadianCard

                // Group Session (if active)
                if wiseMode.isGroupSessionActive {
                    groupSessionCard
                }

                // Prediction Card
                if wiseMode.predictedNextMode != nil {
                    predictionCard
                }

                // Active Optimizations
                optimizationsCard

                // Suggestions
                if !wiseMode.suggestions.isEmpty {
                    suggestionsCard
                }

                // Quick Actions
                quickActions
            }
            .padding()
        }
        .navigationTitle("Wise Mode")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button(wiseMode.isActive ? "Deactivate" : "Activate") {
                    if wiseMode.isActive {
                        wiseMode.deactivate()
                    } else {
                        wiseMode.activate()
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(wiseMode.isActive ? .red : .green)
            }
        }
    }

    // MARK: - Wisdom Header

    private var wisdomHeader: some View {
        VStack(spacing: 12) {
            // Circular Wisdom Indicator
            ZStack {
                // Background circle
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 12)
                    .frame(width: 120, height: 120)

                // Progress circle
                Circle()
                    .trim(from: 0, to: CGFloat(wiseMode.wisdomLevel))
                    .stroke(
                        AngularGradient(
                            colors: [.blue, .purple, .pink, .orange, .yellow, .green, .blue],
                            center: .center
                        ),
                        style: StrokeStyle(lineWidth: 12, lineCap: .round)
                    )
                    .frame(width: 120, height: 120)
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.5), value: wiseMode.wisdomLevel)

                // Center content
                VStack(spacing: 4) {
                    Text("\(Int(wiseMode.wisdomLevel * 100))")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(wisdomColor)

                    Text("Wisdom")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Status
            HStack(spacing: 8) {
                Circle()
                    .fill(wiseMode.isActive ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)

                Text(wiseMode.isActive ? "Active" : "Inactive")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            // System Health
            HStack {
                Image(systemName: "heart.fill")
                    .foregroundColor(healthColor)

                Text("System Health: \(wiseMode.systemHealth)%")
                    .font(.caption)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 20)
                .fill(Color.gray.opacity(0.05))
        )
    }

    private var wisdomColor: Color {
        if wiseMode.wisdomLevel > 0.8 { return .green }
        if wiseMode.wisdomLevel > 0.5 { return .blue }
        if wiseMode.wisdomLevel > 0.3 { return .orange }
        return .red
    }

    private var healthColor: Color {
        if wiseMode.systemHealth > 80 { return .green }
        if wiseMode.systemHealth > 50 { return .yellow }
        return .red
    }

    // MARK: - Mode Selector

    private var modeSelector: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Mode")
                .font(.headline)

            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 12) {
                ForEach(WiseModeOrchestrator.WiseMode.allCases, id: \.self) { mode in
                    ModeButton(
                        mode: mode,
                        isSelected: wiseMode.currentMode == mode,
                        isRecommended: wiseMode.circadianRecommendedMode == mode
                    ) {
                        wiseMode.setMode(mode, animated: true)
                    }
                }
            }
        }
    }

    // MARK: - Current Mode Card

    private var currentModeCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: modeIcon(wiseMode.currentMode))
                    .font(.title2)
                    .foregroundColor(modeColor(wiseMode.currentMode))

                VStack(alignment: .leading) {
                    Text(wiseMode.currentMode.rawValue)
                        .font(.headline)

                    Text(wiseMode.currentMode.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing) {
                    Text("\(Int(wiseMode.currentMode.updateFrequency)) Hz")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("Target: \(Int(wiseMode.currentMode.targetCoherence * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(modeColor(wiseMode.currentMode).opacity(0.1))
        )
    }

    // MARK: - Transition Progress

    private var transitionProgress: some View {
        VStack(spacing: 8) {
            HStack {
                Text("Transitioning...")
                    .font(.subheadline)

                Spacer()

                Text("\(Int(wiseMode.transitionProgress * 100))%")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            ProgressView(value: Double(wiseMode.transitionProgress))
                .progressViewStyle(.linear)
                .tint(.purple)
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.purple.opacity(0.1))
        )
    }

    // MARK: - Circadian Card

    private var circadianCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: circadianIcon)
                    .font(.title2)
                    .foregroundColor(.orange)

                Text("Circadian Rhythm")
                    .font(.headline)

                Spacer()

                Toggle("", isOn: Binding(
                    get: { wiseMode.activeOptimizations.contains(.circadianAlignment) },
                    set: { enabled in
                        if enabled {
                            wiseMode.enableCircadianAlignment()
                        } else {
                            wiseMode.disableCircadianAlignment()
                        }
                    }
                ))
                .labelsHidden()
            }

            HStack {
                VStack(alignment: .leading) {
                    Text(wiseMode.currentCircadianPhase.rawValue)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text(wiseMode.currentCircadianPhase.description)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                if wiseMode.circadianRecommendedMode != wiseMode.currentMode {
                    Button("Apply") {
                        wiseMode.applyCircadianMode()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.orange.opacity(0.1))
        )
    }

    private var circadianIcon: String {
        switch wiseMode.currentCircadianPhase {
        case .earlyMorning, .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "sunset.fill"
        case .night, .lateNight: return "moon.stars.fill"
        }
    }

    // MARK: - Group Session Card

    private var groupSessionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "person.3.fill")
                    .font(.title2)
                    .foregroundColor(.blue)

                Text("Group Session")
                    .font(.headline)

                Spacer()

                Button("End") {
                    wiseMode.endGroupSession()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            HStack {
                VStack(alignment: .leading) {
                    Text("\(wiseMode.groupParticipantCount) Participants")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("Group Coherence: \(Int(wiseMode.groupCoherenceAverage * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Coherence indicator
                ProgressView(value: Double(wiseMode.groupCoherenceAverage))
                    .progressViewStyle(.circular)
                    .tint(.blue)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.blue.opacity(0.1))
        )
    }

    // MARK: - Prediction Card

    private var predictionCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundColor(.purple)

                Text("Predicted Next Mode")
                    .font(.headline)

                Spacer()

                Toggle("", isOn: Binding(
                    get: { wiseMode.activeOptimizations.contains(.predictiveMode) },
                    set: { enabled in
                        if enabled {
                            wiseMode.enablePredictiveMode()
                        } else {
                            wiseMode.disablePredictiveMode()
                        }
                    }
                ))
                .labelsHidden()
            }

            if let predicted = wiseMode.predictedNextMode {
                HStack {
                    VStack(alignment: .leading) {
                        Text(predicted.rawValue)
                            .font(.subheadline)
                            .fontWeight(.medium)

                        Text("Confidence: \(Int(wiseMode.predictionConfidence * 100))%")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    Button("Apply") {
                        wiseMode.applyPredictedMode()
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.purple.opacity(0.1))
        )
    }

    // MARK: - Optimizations Card

    private var optimizationsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Active Optimizations")
                .font(.headline)

            if wiseMode.activeOptimizations.isEmpty {
                Text("No optimizations active")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 8) {
                    ForEach(Array(wiseMode.activeOptimizations), id: \.self) { optimization in
                        HStack(spacing: 4) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                                .font(.caption)

                            Text(optimization.rawValue)
                                .font(.caption)
                                .lineLimit(1)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(Color.green.opacity(0.1))
                        )
                    }
                }
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.gray.opacity(0.05))
        )
    }

    // MARK: - Suggestions Card

    private var suggestionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Suggestions")
                .font(.headline)

            ForEach(wiseMode.suggestions) { suggestion in
                HStack {
                    Image(systemName: suggestionIcon(suggestion.type))
                        .foregroundColor(suggestionColor(suggestion.priority))

                    Text(suggestion.message)
                        .font(.caption)

                    Spacer()

                    Button(action: {
                        suggestion.action?()
                        wiseMode.dismissSuggestion(suggestion)
                    }) {
                        Image(systemName: "xmark")
                            .font(.caption)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 4)
            }
        }
        .padding()
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color.yellow.opacity(0.1))
        )
    }

    private func suggestionIcon(_ type: WiseModeOrchestrator.WiseSuggestion.SuggestionType) -> String {
        switch type {
        case .modeChange: return "arrow.triangle.2.circlepath"
        case .parameterTweak: return "slider.horizontal.3"
        case .healthAlert: return "exclamationmark.triangle"
        case .performanceTip: return "lightbulb"
        case .creativeSuggestion: return "sparkles"
        }
    }

    private func suggestionColor(_ priority: WiseModeOrchestrator.WiseSuggestion.Priority) -> Color {
        switch priority {
        case .high: return .red
        case .medium: return .orange
        case .low: return .blue
        }
    }

    // MARK: - Quick Actions

    private var quickActions: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Quick Actions")
                .font(.headline)

            HStack(spacing: 12) {
                Button(action: {
                    wiseMode.startGroupSession()
                }) {
                    Label("Start Group", systemImage: "person.3")
                }
                .buttonStyle(.bordered)
                .disabled(wiseMode.isGroupSessionActive)

                Button(action: {
                    wiseMode.enableCircadianAlignment()
                    wiseMode.applyCircadianMode()
                }) {
                    Label("Sync Circadian", systemImage: "clock")
                }
                .buttonStyle(.bordered)

                Button(action: {
                    wiseMode.clearSuggestions()
                }) {
                    Label("Clear", systemImage: "trash")
                }
                .buttonStyle(.bordered)
            }
        }
    }

    // MARK: - Helper Functions

    private func modeIcon(_ mode: WiseModeOrchestrator.WiseMode) -> String {
        switch mode {
        case .performance: return "bolt.fill"
        case .balanced: return "scale.3d"
        case .healing: return "heart.fill"
        case .creative: return "paintbrush.fill"
        case .meditative: return "leaf.fill"
        case .energizing: return "flame.fill"
        }
    }

    private func modeColor(_ mode: WiseModeOrchestrator.WiseMode) -> Color {
        switch mode {
        case .performance: return .yellow
        case .balanced: return .blue
        case .healing: return .green
        case .creative: return .purple
        case .meditative: return .cyan
        case .energizing: return .orange
        }
    }
}

// MARK: - Mode Button

struct ModeButton: View {
    let mode: WiseModeOrchestrator.WiseMode
    let isSelected: Bool
    let isRecommended: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(isSelected ? .white : color)

                Text(mode.rawValue)
                    .font(.caption)
                    .fontWeight(isSelected ? .semibold : .regular)
                    .foregroundColor(isSelected ? .white : .primary)

                if isRecommended && !isSelected {
                    Image(systemName: "star.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? color : color.opacity(0.1))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(isRecommended ? Color.orange : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }

    private var icon: String {
        switch mode {
        case .performance: return "bolt.fill"
        case .balanced: return "scale.3d"
        case .healing: return "heart.fill"
        case .creative: return "paintbrush.fill"
        case .meditative: return "leaf.fill"
        case .energizing: return "flame.fill"
        }
    }

    private var color: Color {
        switch mode {
        case .performance: return .yellow
        case .balanced: return .blue
        case .healing: return .green
        case .creative: return .purple
        case .meditative: return .cyan
        case .energizing: return .orange
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        WiseModeView()
    }
}
