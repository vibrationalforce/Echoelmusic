//
//  InstrumentBrowserView.swift
//  Echoelmusic
//
//  Created: 2025-11-27
//  Copyright © 2025 Echoelmusic. All rights reserved.
//
//  Professional instrument browser with search, categories, and AI features
//

import SwiftUI

struct InstrumentBrowserView: View {
    @StateObject private var engine = UltraIntelligentInstrumentEngine.shared
    @State private var selectedCategory: UltraIntelligentInstrumentEngine.InstrumentCategory?
    @State private var searchText = ""
    @State private var selectedInstrument: UltraIntelligentInstrumentEngine.InstrumentID?
    @State private var showingInstrumentDetail = false

    var body: some View {
        NavigationSplitView {
            // Sidebar: Categories
            List(selection: $selectedCategory) {
                Section("All Instruments") {
                    Label("All (\(instrumentCount))", systemImage: "music.note.list")
                        .tag(nil as UltraIntelligentInstrumentEngine.InstrumentCategory?)
                }

                Section("Categories") {
                    ForEach(UltraIntelligentInstrumentEngine.InstrumentCategory.allCases, id: \.self) { category in
                        let count = instrumentCount(for: category)
                        Label("\(category.rawValue) (\(count))", systemImage: categoryIcon(category))
                            .tag(category as UltraIntelligentInstrumentEngine.InstrumentCategory?)
                    }
                }

                Section("Quick Access") {
                    Label("Loaded (\(engine.instruments.count))", systemImage: "square.stack.3d.up")
                    Label("Active (\(engine.activeInstruments.count))", systemImage: "waveform")
                }

                Section("Special") {
                    Label("Bio-Reactive", systemImage: "heart.fill")
                    Label("AI Learning", systemImage: "brain")
                    Label("Favorites", systemImage: "star.fill")
                }
            }
            .navigationTitle("Instruments")
            .searchable(text: $searchText, prompt: "Search instruments...")

        } content: {
            // Instrument Grid
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.adaptive(minimum: 150, maximum: 200), spacing: 16)
                ], spacing: 16) {
                    ForEach(filteredInstruments, id: \.self) { instrumentID in
                        InstrumentCard(
                            instrumentID: instrumentID,
                            isLoaded: engine.instruments[instrumentID] != nil,
                            isActive: engine.activeInstruments.contains(instrumentID),
                            onTap: {
                                selectedInstrument = instrumentID
                                showingInstrumentDetail = true
                            },
                            onActivate: {
                                if engine.activeInstruments.contains(instrumentID) {
                                    engine.deactivateInstrument(instrumentID)
                                } else {
                                    engine.activateInstrument(instrumentID)
                                }
                            }
                        )
                    }
                }
                .padding()
            }
            .navigationTitle(selectedCategory?.rawValue ?? "All Instruments")

        } detail: {
            // Instrument Detail
            if let selected = selectedInstrument {
                InstrumentDetailView(instrumentID: selected)
            } else {
                ContentUnavailableView(
                    "Select an Instrument",
                    systemImage: "pianokeys",
                    description: Text("Choose an instrument from the list to see its details")
                )
            }
        }
        .sheet(isPresented: $showingInstrumentDetail) {
            if let selected = selectedInstrument {
                InstrumentDetailSheet(instrumentID: selected)
            }
        }
    }

    // MARK: - Computed Properties

    private var instrumentCount: Int {
        UltraIntelligentInstrumentEngine.InstrumentID.allCases.count
    }

    private func instrumentCount(for category: UltraIntelligentInstrumentEngine.InstrumentCategory) -> Int {
        UltraIntelligentInstrumentEngine.InstrumentID.allCases.filter { $0.category == category }.count
    }

    private var filteredInstruments: [UltraIntelligentInstrumentEngine.InstrumentID] {
        var instruments = UltraIntelligentInstrumentEngine.InstrumentID.allCases

        // Filter by category
        if let category = selectedCategory {
            instruments = instruments.filter { $0.category == category }
        }

        // Filter by search
        if !searchText.isEmpty {
            instruments = instruments.filter { $0.rawValue.localizedCaseInsensitiveContains(searchText) }
        }

        return instruments
    }

    private func categoryIcon(_ category: UltraIntelligentInstrumentEngine.InstrumentCategory) -> String {
        switch category {
        case .keyboards: return "pianokeys"
        case .guitars: return "guitars"
        case .strings: return "music.quarternote.3"
        case .brass: return "horn"
        case .woodwinds: return "wind"
        case .percussion: return "drum"
        case .ethnic: return "globe"
        case .synths: return "waveform.path.ecg"
        case .experimental: return "brain.head.profile"
        }
    }
}

// MARK: - Instrument Card

struct InstrumentCard: View {
    let instrumentID: UltraIntelligentInstrumentEngine.InstrumentID
    let isLoaded: Bool
    let isActive: Bool
    let onTap: () -> Void
    let onActivate: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            // Icon
            ZStack {
                RoundedRectangle(cornerRadius: 12)
                    .fill(instrumentColor.gradient)
                    .frame(height: 100)

                Image(systemName: instrumentIcon)
                    .font(.system(size: 40))
                    .foregroundStyle(.white)

                // Active indicator
                if isActive {
                    VStack {
                        HStack {
                            Spacer()
                            Image(systemName: "waveform.circle.fill")
                                .foregroundStyle(.green)
                                .background(Circle().fill(.white).padding(2))
                        }
                        Spacer()
                    }
                    .padding(8)
                }
            }

            // Name
            Text(instrumentID.rawValue)
                .font(.caption)
                .fontWeight(.medium)
                .lineLimit(2)
                .multilineTextAlignment(.center)

            // Category badge
            Text(instrumentID.category.rawValue)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .background(Capsule().fill(.quaternary))
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 16).fill(.background))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(isActive ? Color.green : Color.clear, lineWidth: 2)
        )
        .shadow(radius: 2)
        .onTapGesture(perform: onTap)
        .contextMenu {
            Button {
                onActivate()
            } label: {
                Label(isActive ? "Deactivate" : "Activate", systemImage: isActive ? "stop.fill" : "play.fill")
            }

            Divider()

            Button {
                // Add to favorites
            } label: {
                Label("Add to Favorites", systemImage: "star")
            }

            Button {
                // Show in track
            } label: {
                Label("Add to Track", systemImage: "plus.rectangle.on.rectangle")
            }
        }
    }

    private var instrumentColor: Color {
        switch instrumentID.category {
        case .keyboards: return .blue
        case .guitars: return .orange
        case .strings: return .purple
        case .brass: return .yellow
        case .woodwinds: return .green
        case .percussion: return .red
        case .ethnic: return .teal
        case .synths: return .pink
        case .experimental: return .indigo
        }
    }

    private var instrumentIcon: String {
        switch instrumentID.category {
        case .keyboards: return "pianokeys"
        case .guitars: return "guitars"
        case .strings: return "music.quarternote.3"
        case .brass: return "horn"
        case .woodwinds: return "wind"
        case .percussion: return "drum"
        case .ethnic: return "globe"
        case .synths: return "waveform"
        case .experimental: return "brain"
        }
    }
}

// MARK: - Instrument Detail View

struct InstrumentDetailView: View {
    let instrumentID: UltraIntelligentInstrumentEngine.InstrumentID
    @StateObject private var engine = UltraIntelligentInstrumentEngine.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack {
                    Image(systemName: categoryIcon)
                        .font(.largeTitle)
                        .foregroundStyle(.white)
                        .frame(width: 60, height: 60)
                        .background(Circle().fill(categoryColor.gradient))

                    VStack(alignment: .leading) {
                        Text(instrumentID.rawValue)
                            .font(.title)
                            .fontWeight(.bold)

                        Text(instrumentID.category.rawValue)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button {
                        if engine.activeInstruments.contains(instrumentID) {
                            engine.deactivateInstrument(instrumentID)
                        } else {
                            engine.activateInstrument(instrumentID)
                        }
                    } label: {
                        Label(
                            engine.activeInstruments.contains(instrumentID) ? "Active" : "Activate",
                            systemImage: engine.activeInstruments.contains(instrumentID) ? "stop.circle.fill" : "play.circle.fill"
                        )
                        .padding()
                        .background(engine.activeInstruments.contains(instrumentID) ? Color.green : Color.accentColor)
                        .foregroundStyle(.white)
                        .cornerRadius(10)
                    }
                }

                Divider()

                // Parameters
                if let instrument = engine.instruments[instrumentID] {
                    ParametersSection(instrument: instrument)
                    ArticulationsSection(instrument: instrument)
                    BioReactiveSection(instrument: instrument)
                    AILearningSection(instrument: instrument)
                } else {
                    Text("Load instrument to see parameters")
                        .foregroundStyle(.secondary)

                    Button("Load Instrument") {
                        _ = engine.loadInstrument(instrumentID)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
        }
        .navigationTitle(instrumentID.rawValue)
    }

    private var categoryIcon: String {
        switch instrumentID.category {
        case .keyboards: return "pianokeys"
        case .guitars: return "guitars"
        case .strings: return "music.quarternote.3"
        case .brass: return "horn"
        case .woodwinds: return "wind"
        case .percussion: return "drum"
        case .ethnic: return "globe"
        case .synths: return "waveform"
        case .experimental: return "brain"
        }
    }

    private var categoryColor: Color {
        switch instrumentID.category {
        case .keyboards: return .blue
        case .guitars: return .orange
        case .strings: return .purple
        case .brass: return .yellow
        case .woodwinds: return .green
        case .percussion: return .red
        case .ethnic: return .teal
        case .synths: return .pink
        case .experimental: return .indigo
        }
    }
}

// MARK: - Parameters Section

struct ParametersSection: View {
    @ObservedObject var instrument: UltraIntelligentInstrumentEngine.UltraInstrument

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Parameters", systemImage: "slider.horizontal.3")
                .font(.headline)

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach(Array(instrument.parameters.keys.sorted()), id: \.self) { key in
                    ParameterSlider(name: key, value: Binding(
                        get: { instrument.parameters[key] ?? 0.5 },
                        set: { instrument.parameters[key] = $0 }
                    ))
                }
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary))
    }
}

struct ParameterSlider: View {
    let name: String
    @Binding var value: Float

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(name.capitalized)
                    .font(.caption)
                Spacer()
                Text(String(format: "%.2f", value))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Slider(value: $value, in: 0...1)
        }
    }
}

// MARK: - Articulations Section

struct ArticulationsSection: View {
    @ObservedObject var instrument: UltraIntelligentInstrumentEngine.UltraInstrument

    var body: some View {
        if !instrument.articulations.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Label("Articulations", systemImage: "music.note")
                    .font(.headline)

                FlowLayout(spacing: 8) {
                    ForEach(instrument.articulations) { articulation in
                        Button {
                            // Toggle articulation
                        } label: {
                            HStack {
                                Text(articulation.name)
                                Text("(C\(articulation.keyswitch - 24))")
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(articulation.isActive ? Color.accentColor : Color.secondary.opacity(0.2))
                            .foregroundStyle(articulation.isActive ? .white : .primary)
                            .cornerRadius(8)
                        }
                    }
                }
            }
            .padding()
            .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary))
        }
    }
}

// MARK: - Bio-Reactive Section

struct BioReactiveSection: View {
    @ObservedObject var instrument: UltraIntelligentInstrumentEngine.UltraInstrument

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Bio-Reactive Control", systemImage: "heart.fill")
                .font(.headline)

            VStack(spacing: 8) {
                BioMappingToggle(title: "HR → Expression", isOn: Binding(
                    get: { instrument.bioReactiveMapping.hrToExpression },
                    set: { instrument.bioReactiveMapping.hrToExpression = $0 }
                ), sensitivity: Binding(
                    get: { instrument.bioReactiveMapping.hrSensitivity },
                    set: { instrument.bioReactiveMapping.hrSensitivity = $0 }
                ))

                BioMappingToggle(title: "HRV → Velocity", isOn: Binding(
                    get: { instrument.bioReactiveMapping.hrvToVelocity },
                    set: { instrument.bioReactiveMapping.hrvToVelocity = $0 }
                ), sensitivity: Binding(
                    get: { instrument.bioReactiveMapping.hrvSensitivity },
                    set: { instrument.bioReactiveMapping.hrvSensitivity = $0 }
                ))

                BioMappingToggle(title: "Coherence → Timbre", isOn: Binding(
                    get: { instrument.bioReactiveMapping.coherenceToTimbre },
                    set: { instrument.bioReactiveMapping.coherenceToTimbre = $0 }
                ), sensitivity: Binding(
                    get: { instrument.bioReactiveMapping.coherenceSensitivity },
                    set: { instrument.bioReactiveMapping.coherenceSensitivity = $0 }
                ))

                BioMappingToggle(title: "Breath → Filter", isOn: Binding(
                    get: { instrument.bioReactiveMapping.breathToFilter },
                    set: { instrument.bioReactiveMapping.breathToFilter = $0 }
                ), sensitivity: Binding(
                    get: { instrument.bioReactiveMapping.breathSensitivity },
                    set: { instrument.bioReactiveMapping.breathSensitivity = $0 }
                ))
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary))
    }
}

struct BioMappingToggle: View {
    let title: String
    @Binding var isOn: Bool
    @Binding var sensitivity: Float

    var body: some View {
        HStack {
            Toggle(title, isOn: $isOn)

            if isOn {
                Slider(value: $sensitivity, in: 0...1)
                    .frame(width: 100)
            }
        }
    }
}

// MARK: - AI Learning Section

struct AILearningSection: View {
    @ObservedObject var instrument: UltraIntelligentInstrumentEngine.UltraInstrument

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("AI Learning Profile", systemImage: "brain")
                .font(.headline)

            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Playing Style")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(instrument.playingProfile.playingStyle.capitalized)
                        .font(.title3)
                        .fontWeight(.medium)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text("Events Learned")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(instrument.styleMemory.count)")
                        .font(.title3)
                        .fontWeight(.medium)
                }
            }

            if !instrument.playingProfile.preferredNotes.isEmpty {
                Text("Top notes: \(topNotesDescription)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack {
                Button("Reset Learning") {
                    instrument.styleMemory.removeAll()
                }
                .buttonStyle(.bordered)

                Button("Export Profile") {
                    // Export
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
        .background(RoundedRectangle(cornerRadius: 12).fill(.quaternary))
    }

    private var topNotesDescription: String {
        let topNotes = instrument.playingProfile.preferredNotes
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { noteToName($0.key) }

        return topNotes.joined(separator: ", ")
    }

    private func noteToName(_ note: Int) -> String {
        let noteNames = ["C", "C#", "D", "D#", "E", "F", "F#", "G", "G#", "A", "A#", "B"]
        let octave = note / 12 - 1
        let noteName = noteNames[note % 12]
        return "\(noteName)\(octave)"
    }
}

// MARK: - Instrument Detail Sheet

struct InstrumentDetailSheet: View {
    let instrumentID: UltraIntelligentInstrumentEngine.InstrumentID
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            InstrumentDetailView(instrumentID: instrumentID)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            dismiss()
                        }
                    }
                }
        }
    }
}

// MARK: - Flow Layout Helper

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var height: CGFloat = 0
        var currentX: CGFloat = 0
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth {
                height += currentRowHeight + spacing
                currentX = 0
                currentRowHeight = 0
            }

            currentX += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }

        height += currentRowHeight

        return CGSize(width: maxWidth, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var currentX: CGFloat = bounds.minX
        var currentY: CGFloat = bounds.minY
        var currentRowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > bounds.maxX {
                currentY += currentRowHeight + spacing
                currentX = bounds.minX
                currentRowHeight = 0
            }

            subview.place(at: CGPoint(x: currentX, y: currentY), proposal: .unspecified)
            currentX += size.width + spacing
            currentRowHeight = max(currentRowHeight, size.height)
        }
    }
}

// MARK: - Preview

#Preview {
    InstrumentBrowserView()
}
