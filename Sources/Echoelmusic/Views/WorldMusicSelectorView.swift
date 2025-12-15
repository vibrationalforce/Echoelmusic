//
// WorldMusicSelectorView.swift
// Echoelmusic
//
// UI for selecting from 42 global music styles
// Makes WorldMusicBridge accessible to users
//

import SwiftUI

struct WorldMusicSelectorView: View {

    // MARK: - Properties

    @StateObject private var worldMusicBridge = WorldMusicBridge.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedCategory: WorldMusicBridge.StyleCategory?
    @State private var searchText = ""
    @State private var selectedStyle: WorldMusicBridge.MusicStyle?
    @State private var showingStyleDetail = false

    // MARK: - Body

    var body: some View {
        ZStack {
            VaporwaveGradients.background
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // Search Bar
                searchBar

                // Category Filter
                categoryFilter
                    .padding(.vertical, VaporwaveSpacing.sm)

                // Styles Grid
                ScrollView {
                    LazyVGrid(
                        columns: [
                            GridItem(.flexible(), spacing: 16),
                            GridItem(.flexible(), spacing: 16)
                        ],
                        spacing: 16
                    ) {
                        ForEach(filteredStyles) { style in
                            StyleCard(style: style)
                                .onTapGesture {
                                    selectStyle(style)
                                }
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("World Music Styles")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showingStyleDetail) {
            if let style = selectedStyle {
                StyleDetailView(style: style)
            }
        }
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: VaporwaveSpacing.sm) {
            Image(systemName: "magnifyingglass")
                .foregroundColor(VaporwaveColors.textTertiary)

            TextField("Search styles...", text: $searchText)
                .font(VaporwaveTypography.body())
                .foregroundColor(VaporwaveColors.textPrimary)

            if !searchText.isEmpty {
                Button(action: { searchText = "" }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(VaporwaveColors.textTertiary)
                }
            }
        }
        .padding(VaporwaveSpacing.md)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color.white.opacity(0.05))
        )
        .padding(.horizontal)
        .padding(.top)
    }

    // MARK: - Category Filter

    private var categoryFilter: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: VaporwaveSpacing.sm) {
                CategoryChip(
                    title: "All",
                    count: worldMusicBridge.availableStyles.count,
                    isSelected: selectedCategory == nil,
                    color: VaporwaveColors.neonCyan,
                    action: {
                        selectedCategory = nil
                    }
                )

                ForEach(WorldMusicBridge.StyleCategory.allCases, id: \.self) { category in
                    let count = worldMusicBridge.availableStyles.filter { $0.category == category }.count
                    if count > 0 {
                        CategoryChip(
                            title: category.rawValue,
                            count: count,
                            isSelected: selectedCategory == category,
                            color: categoryColor(category),
                            action: {
                                selectedCategory = category == selectedCategory ? nil : category
                            }
                        )
                    }
                }
            }
            .padding(.horizontal)
        }
    }

    // MARK: - Style Card

    private struct StyleCard: View {
        let style: WorldMusicBridge.MusicStyle

        var body: some View {
            VStack(alignment: .leading, spacing: VaporwaveSpacing.sm) {
                // Icon & Category
                HStack {
                    Image(systemName: categoryIcon(style.category))
                        .font(.system(size: 24))
                        .foregroundColor(categoryColor(style.category))

                    Spacer()

                    Text(style.category.rawValue)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(categoryColor(style.category))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(
                            Capsule()
                                .fill(categoryColor(style.category).opacity(0.2))
                        )
                }

                // Style Name
                Text(style.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(VaporwaveColors.textPrimary)

                // Tempo Range
                HStack(spacing: 4) {
                    Image(systemName: "metronome")
                        .font(.system(size: 12))
                    Text("\(style.tempoRange.lowerBound)-\(style.tempoRange.upperBound) BPM")
                        .font(.system(size: 12))
                }
                .foregroundColor(VaporwaveColors.textSecondary)

                // Rhythmic Feel
                HStack(spacing: 4) {
                    Image(systemName: "waveform")
                        .font(.system(size: 12))
                    Text(style.rhythmicFeel.rawValue)
                        .font(.system(size: 12))
                }
                .foregroundColor(VaporwaveColors.textSecondary)

                // Complexity Indicator
                HStack(spacing: 4) {
                    ForEach(0..<5) { index in
                        Circle()
                            .fill(Float(index) < style.compositionRules.complexity * 5 ? categoryColor(style.category) : Color.white.opacity(0.2))
                            .frame(width: 6, height: 6)
                    }
                }
                .padding(.top, 4)
            }
            .padding(VaporwaveSpacing.md)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(
                        LinearGradient(
                            gradient: Gradient(colors: [
                                categoryColor(style.category).opacity(0.1),
                                Color.white.opacity(0.02)
                            ]),
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(categoryColor(style.category).opacity(0.3), lineWidth: 1)
            )
        }
    }

    // MARK: - Category Chip

    private struct CategoryChip: View {
        let title: String
        let count: Int
        let isSelected: Bool
        let color: Color
        let action: () -> Void

        var body: some View {
            Button(action: action) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 13, weight: .medium))

                    Text("\(count)")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(
                            Capsule()
                                .fill(isSelected ? color : Color.white.opacity(0.1))
                        )
                }
                .foregroundColor(isSelected ? .white : VaporwaveColors.textSecondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(
                    Capsule()
                        .fill(isSelected ? color.opacity(0.3) : Color.white.opacity(0.05))
                )
                .overlay(
                    Capsule()
                        .stroke(isSelected ? color : Color.clear, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Computed Properties

    private var filteredStyles: [WorldMusicBridge.MusicStyle] {
        var styles = worldMusicBridge.availableStyles

        // Filter by category
        if let category = selectedCategory {
            styles = styles.filter { $0.category == category }
        }

        // Filter by search
        if !searchText.isEmpty {
            styles = styles.filter { style in
                style.name.localizedCaseInsensitiveContains(searchText) ||
                style.category.rawValue.localizedCaseInsensitiveContains(searchText) ||
                style.typicalInstruments.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
            }
        }

        return styles
    }

    // MARK: - Actions

    private func selectStyle(_ style: WorldMusicBridge.MusicStyle) {
        selectedStyle = style
        showingStyleDetail = true

        // Update WorldMusicBridge current style
        worldMusicBridge.currentStyle = style

        // Haptic feedback
        let impact = UIImpactFeedbackGenerator(style: .medium)
        impact.impactOccurred()
    }

    // MARK: - Helpers

    private static func categoryColor(_ category: WorldMusicBridge.StyleCategory) -> Color {
        switch category {
        case .modern: return VaporwaveColors.neonCyan
        case .electronic: return VaporwaveColors.neonPurple
        case .classical: return VaporwaveColors.lavender
        case .jazz: return VaporwaveColors.neonPink
        case .latin: return VaporwaveColors.coral
        case .african: return Color.orange
        case .caribbean: return Color.green
        case .asian: return Color.red
        case .middleEastern: return Color.yellow
        case .europeanFolk: return Color.blue
        case .other: return VaporwaveColors.textSecondary
        }
    }

    private static func categoryIcon(_ category: WorldMusicBridge.StyleCategory) -> String {
        switch category {
        case .modern: return "music.note"
        case .electronic: return "waveform"
        case .classical: return "music.quarternote.3"
        case .jazz: return "music.mic"
        case .latin: return "guitar"
        case .african: return "drum"
        case .caribbean: return "tropicalstorm"
        case .asian: return "wind"
        case .middleEastern: return "star.circle"
        case .europeanFolk: return "mountain.2"
        case .other: return "questionmark.circle"
        }
    }

    private func categoryColor(_ category: WorldMusicBridge.StyleCategory) -> Color {
        Self.categoryColor(category)
    }

    private func categoryIcon(_ category: WorldMusicBridge.StyleCategory) -> String {
        Self.categoryIcon(category)
    }
}

// MARK: - Style Detail View

struct StyleDetailView: View {
    let style: WorldMusicBridge.MusicStyle
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            VaporwaveGradients.background
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: VaporwaveSpacing.lg) {

                    // Header
                    VStack(alignment: .leading, spacing: VaporwaveSpacing.sm) {
                        HStack {
                            Image(systemName: WorldMusicSelectorView.categoryIcon(style.category))
                                .font(.system(size: 48))
                                .foregroundColor(WorldMusicSelectorView.categoryColor(style.category))

                            Spacer()

                            Button(action: { dismiss() }) {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 28))
                                    .foregroundColor(VaporwaveColors.textSecondary)
                            }
                        }

                        Text(style.name)
                            .font(.system(size: 36, weight: .bold))
                            .foregroundColor(VaporwaveColors.textPrimary)

                        Text(style.category.rawValue)
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(WorldMusicSelectorView.categoryColor(style.category))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(WorldMusicSelectorView.categoryColor(style.category).opacity(0.2))
                            )
                    }
                    .padding(VaporwaveSpacing.lg)

                    // Musical Characteristics
                    DetailSection(title: "MUSICAL CHARACTERISTICS", icon: "music.note.list") {
                        CharacteristicRow(label: "Tempo Range", value: "\(style.tempoRange.lowerBound)-\(style.tempoRange.upperBound) BPM")
                        CharacteristicRow(label: "Rhythmic Feel", value: style.rhythmicFeel.rawValue)
                        CharacteristicRow(label: "Melodic Contour", value: style.melodicContour)
                    }

                    // Scales
                    DetailSection(title: "SCALES & MODES", icon: "music.quarternote.3") {
                        ForEach(style.scales, id: \.self) { scale in
                            ScaleChip(scale: scale)
                        }
                    }

                    // Chord Progressions
                    DetailSection(title: "CHORD PROGRESSIONS", icon: "waveform.path") {
                        ForEach(style.chordProgressions, id: \.name) { progression in
                            VStack(alignment: .leading, spacing: 4) {
                                Text(progression.name)
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(VaporwaveColors.textPrimary)

                                Text(progression.numerals.joined(separator: " → "))
                                    .font(.system(size: 14, design: .monospaced))
                                    .foregroundColor(WorldMusicSelectorView.categoryColor(style.category))

                                Text(progression.description)
                                    .font(VaporwaveTypography.caption())
                                    .foregroundColor(VaporwaveColors.textTertiary)
                            }
                            .padding(VaporwaveSpacing.sm)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.white.opacity(0.02))
                            )
                        }
                    }

                    // Typical Instruments
                    DetailSection(title: "TYPICAL INSTRUMENTS", icon: "hifispeaker.2") {
                        ForEach(style.typicalInstruments, id: \.self) { instrument in
                            InstrumentChip(instrument: instrument)
                        }
                    }

                    // Composition Rules
                    DetailSection(title: "COMPOSITION COMPLEXITY", icon: "slider.horizontal.3") {
                        ComplexityBar(label: "Chromaticism", value: style.compositionRules.chromaticism, color: WorldMusicSelectorView.categoryColor(style.category))
                        ComplexityBar(label: "Dissonance", value: style.compositionRules.dissonance, color: WorldMusicSelectorView.categoryColor(style.category))
                        ComplexityBar(label: "Complexity", value: style.compositionRules.complexity, color: WorldMusicSelectorView.categoryColor(style.category))
                        ComplexityBar(label: "Syncopation", value: style.compositionRules.syncopation, color: WorldMusicSelectorView.categoryColor(style.category))
                        ComplexityBar(label: "Improvisation", value: style.compositionRules.improvisation, color: WorldMusicSelectorView.categoryColor(style.category))
                    }

                    // Apply Button
                    Button(action: {
                        WorldMusicBridge.shared.currentStyle = style
                        dismiss()
                    }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 20))

                            Text("Apply \(style.name) Style")
                                .font(.system(size: 17, weight: .semibold))
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(VaporwaveSpacing.md)
                        .background(
                            RoundedRectangle(cornerRadius: 12)
                                .fill(
                                    LinearGradient(
                                        gradient: Gradient(colors: [
                                            WorldMusicSelectorView.categoryColor(style.category),
                                            WorldMusicSelectorView.categoryColor(style.category).opacity(0.8)
                                        ]),
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                        )
                    }
                    .padding(.horizontal, VaporwaveSpacing.lg)
                    .padding(.bottom, VaporwaveSpacing.xl)
                }
            }
        }
    }

    // MARK: - Detail Section

    private struct DetailSection<Content: View>: View {
        let title: String
        let icon: String
        @ViewBuilder let content: () -> Content

        var body: some View {
            VStack(alignment: .leading, spacing: VaporwaveSpacing.md) {
                HStack(spacing: VaporwaveSpacing.sm) {
                    Image(systemName: icon)
                        .font(.system(size: 14))
                        .foregroundColor(VaporwaveColors.neonCyan)

                    Text(title)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(VaporwaveColors.neonCyan)
                        .tracking(2)
                }

                content()
            }
            .padding(VaporwaveSpacing.md)
            .glassCard()
            .padding(.horizontal, VaporwaveSpacing.lg)
        }
    }

    // MARK: - Components

    private struct CharacteristicRow: View {
        let label: String
        let value: String

        var body: some View {
            HStack {
                Text(label)
                    .font(VaporwaveTypography.body())
                    .foregroundColor(VaporwaveColors.textSecondary)

                Spacer()

                Text(value)
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(VaporwaveColors.textPrimary)
            }
        }
    }

    private struct ScaleChip: View {
        let scale: String

        var body: some View {
            Text(scale)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(VaporwaveColors.neonPurple)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(VaporwaveColors.neonPurple.opacity(0.2))
                )
        }
    }

    private struct InstrumentChip: View {
        let instrument: String

        var body: some View {
            Text(instrument)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(VaporwaveColors.neonCyan)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(
                    Capsule()
                        .fill(VaporwaveColors.neonCyan.opacity(0.2))
                )
        }
    }

    private struct ComplexityBar: View {
        let label: String
        let value: Float
        let color: Color

        var body: some View {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(label)
                        .font(.system(size: 13))
                        .foregroundColor(VaporwaveColors.textSecondary)

                    Spacer()

                    Text("\(Int(value * 100))%")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(VaporwaveColors.textPrimary)
                }

                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.white.opacity(0.1))

                        RoundedRectangle(cornerRadius: 4)
                            .fill(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        color.opacity(0.6),
                                        color
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: geometry.size.width * CGFloat(value))
                    }
                }
                .frame(height: 8)
            }
        }
    }
}

// MARK: - Preview

#Preview {
    NavigationView {
        WorldMusicSelectorView()
    }
}
