import SwiftUI

/// Comprehensive tuning browser - more detailed than Omnisphere
/// Browse 50+ tuning systems by category, era, region, or musical style
struct TuningBrowserView: View {

    @StateObject private var tuningDB = TuningDatabase.shared
    @StateObject private var styleDB = MusicalStyleDatabase.shared
    @StateObject private var exporter = TuningPresetExporter()

    @State private var searchText = ""
    @State private var selectedCategory: TuningCategory?
    @State private var selectedEra: HistoricalEra?
    @State private var selectedRegion: GeographicRegion?
    @State private var selectedStyle: String?  // Musical style ID

    @State private var selectedTuning: TuningSystem?
    @State private var showingExportSheet = false
    @State private var exportFormat: TuningPresetExporter.ExportFormat = .scala

    enum BrowseMode: String, CaseIterable {
        case all = "All Tunings"
        case favorites = "Favorites"
        case recent = "Recent"
        case byCategory = "By Category"
        case byEra = "By Era"
        case byRegion = "By Region"
        case byStyle = "By Musical Style"
    }

    @State private var browseMode: BrowseMode = .all


    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Search bar
                searchBar

                // Browse mode picker
                modePicker

                // Filter section (if needed)
                if browseMode == .byCategory || browseMode == .byEra ||
                   browseMode == .byRegion || browseMode == .byStyle {
                    filterSection
                }

                // Tuning list
                tuningList

                // Selected tuning detail panel
                if selectedTuning != nil {
                    detailPanel
                }
            }
            .navigationTitle("Tuning Library")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingExportSheet = true }) {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .disabled(selectedTuning == nil)
                }
            }
            .sheet(isPresented: $showingExportSheet) {
                if let tuning = selectedTuning {
                    exportSheet(tuning: tuning)
                }
            }
        }
    }


    // MARK: - Subviews

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundColor(.secondary)
            TextField("Search tunings...", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
        }
        .padding()
    }

    private var modePicker: some View {
        Picker("Browse Mode", selection: $browseMode) {
            ForEach(BrowseMode.allCases, id: \.self) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(SegmentedPickerStyle())
        .padding(.horizontal)
    }

    private var filterSection: some View {
        HStack {
            if browseMode == .byCategory {
                categoryPicker
            } else if browseMode == .byEra {
                eraPicker
            } else if browseMode == .byRegion {
                regionPicker
            } else if browseMode == .byStyle {
                stylePicker
            }
        }
        .padding()
    }

    private var categoryPicker: some View {
        Picker("Category", selection: $selectedCategory) {
            Text("All").tag(nil as TuningCategory?)
            ForEach(TuningCategory.allCases, id: \.self) { category in
                Text(category.rawValue).tag(category as TuningCategory?)
            }
        }
        .pickerStyle(MenuPickerStyle())
    }

    private var eraPicker: some View {
        Picker("Era", selection: $selectedEra) {
            Text("All").tag(nil as HistoricalEra?)
            ForEach(HistoricalEra.allCases, id: \.self) { era in
                Text(era.rawValue).tag(era as HistoricalEra?)
            }
        }
        .pickerStyle(MenuPickerStyle())
    }

    private var regionPicker: some View {
        Picker("Region", selection: $selectedRegion) {
            Text("All").tag(nil as GeographicRegion?)
            ForEach(GeographicRegion.allCases, id: \.self) { region in
                Text(region.rawValue).tag(region as GeographicRegion?)
            }
        }
        .pickerStyle(MenuPickerStyle())
    }

    private var stylePicker: some View {
        Picker("Musical Style", selection: $selectedStyle) {
            Text("All").tag(nil as String?)
            ForEach(styleDB.allStyles, id: \.id) { style in
                Text(style.name).tag(style.id as String?)
            }
        }
        .pickerStyle(MenuPickerStyle())
    }

    private var tuningList: some View {
        List(filteredTunings, id: \.id) { tuning in
            TuningRow(tuning: tuning, isSelected: selectedTuning?.id == tuning.id)
                .contentShape(Rectangle())
                .onTapGesture {
                    selectedTuning = tuning
                    tuningDB.markAsRecent(tuning.id)
                }
                .swipeActions(edge: .leading) {
                    Button {
                        tuningDB.toggleFavorite(tuning.id)
                    } label: {
                        Label("Favorite", systemImage: tuningDB.favoriteTunings.contains(tuning.id) ? "star.fill" : "star")
                    }
                    .tint(.yellow)
                }
        }
    }

    private var detailPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let tuning = selectedTuning {
                Text(tuning.name)
                    .font(.headline)

                Text("A4 = \(String(format: "%.2f", tuning.a4Frequency)) Hz")
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text(tuning.description)
                    .font(.caption)

                if let warning = tuning.warningNote {
                    Text("⚠️ \(warning)")
                        .font(.caption)
                        .foregroundColor(.orange)
                }

                Divider()

                Text("Historical Context:")
                    .font(.caption)
                    .bold()

                Text(tuning.historicalContext)
                    .font(.caption)
                    .foregroundColor(.secondary)

                if !tuning.scientificReferences.isEmpty {
                    Divider()
                    Text("References:")
                        .font(.caption)
                        .bold()

                    ForEach(tuning.scientificReferences, id: \.self) { ref in
                        Text("• \(ref)")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                Spacer()

                HStack {
                    Button("Export...") {
                        showingExportSheet = true
                    }
                    .buttonStyle(.bordered)

                    Spacer()

                    Button(tuningDB.favoriteTunings.contains(tuning.id) ? "Remove Favorite" : "Add to Favorites") {
                        tuningDB.toggleFavorite(tuning.id)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .padding()
        .frame(height: 300)
        .background(Color(.systemBackground))
        .border(Color.secondary.opacity(0.3), width: 1)
    }

    private func exportSheet(tuning: TuningSystem) -> some View {
        NavigationView {
            Form {
                Section(header: Text("Export Format")) {
                    Picker("Format", selection: $exportFormat) {
                        ForEach(TuningPresetExporter.ExportFormat.allCases, id: \.self) { format in
                            Text(format.rawValue).tag(format)
                        }
                    }
                    .pickerStyle(MenuPickerStyle())
                }

                Section(header: Text("Preview")) {
                    Text("Tuning: \(tuning.name)")
                    Text("A4 = \(String(format: "%.2f", tuning.a4Frequency)) Hz")
                    Text("Format: \(exportFormat.rawValue)")
                }

                Section {
                    Button("Export") {
                        Task {
                            await exportTuning(tuning)
                        }
                    }
                }
            }
            .navigationTitle("Export Tuning")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Cancel") {
                        showingExportSheet = false
                    }
                }
            }
        }
    }


    // MARK: - Computed Properties

    private var filteredTunings: [TuningSystem] {
        var tunings: [TuningSystem]

        // Filter by browse mode
        switch browseMode {
        case .all:
            tunings = tuningDB.allTunings
        case .favorites:
            tunings = tuningDB.getFavorites()
        case .recent:
            tunings = tuningDB.getRecent()
        case .byCategory:
            if let category = selectedCategory {
                tunings = tuningDB.getTunings(category: category)
            } else {
                tunings = tuningDB.allTunings
            }
        case .byEra:
            if let era = selectedEra {
                tunings = tuningDB.getTunings(era: era)
            } else {
                tunings = tuningDB.allTunings
            }
        case .byRegion:
            if let region = selectedRegion {
                tunings = tuningDB.getTunings(region: region)
            } else {
                tunings = tuningDB.allTunings
            }
        case .byStyle:
            if let styleID = selectedStyle {
                tunings = tuningDB.getRecommendedTunings(for: styleID)
            } else {
                tunings = tuningDB.allTunings
            }
        }

        // Apply search filter
        if !searchText.isEmpty {
            tunings = tunings.filter { tuning in
                tuning.name.localizedCaseInsensitiveContains(searchText) ||
                tuning.description.localizedCaseInsensitiveContains(searchText) ||
                tuning.historicalContext.localizedCaseInsensitiveContains(searchText)
            }
        }

        return tunings
    }


    // MARK: - Methods

    private func exportTuning(_ tuning: TuningSystem) async {
        do {
            let data = try exporter.export(tuning: tuning, format: exportFormat)
            let url = try exporter.save(data: data, filename: tuning.name, format: exportFormat)

            print("✅ Exported tuning to: \(url.path)")
            showingExportSheet = false

            // TODO: Show share sheet
        } catch {
            print("❌ Export failed: \(error)")
        }
    }
}


// MARK: - Tuning Row

struct TuningRow: View {
    let tuning: TuningSystem
    let isSelected: Bool

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(tuning.name)
                    .font(.headline)
                    .foregroundColor(isSelected ? .blue : .primary)

                Text("A4 = \(String(format: "%.1f", tuning.a4Frequency)) Hz")
                    .font(.caption)
                    .foregroundColor(.secondary)

                HStack {
                    Label(tuning.category.rawValue, systemImage: "folder")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    if tuning.requiresMicrotonal {
                        Label("Microtonal", systemImage: "waveform")
                            .font(.caption)
                            .foregroundColor(.orange)
                    }
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(tuning.era.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Text(tuning.region.rawValue)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 4)
    }
}


// MARK: - Preview

struct TuningBrowserView_Previews: PreviewProvider {
    static var previews: some View {
        TuningBrowserView()
    }
}
