import SwiftUI
import AVFoundation
import os.log

/// Professional Vocal Alignment UI
/// Touch-optimized interface for multi-track vocal alignment
struct VocalAlignmentView: View {
    @StateObject private var aligner = AutomaticVocalAligner()
    @State private var showGuideFilePicker = false
    @State private var showDubFilePicker = false
    @State private var selectedTrackId: UUID?
    @State private var showExportSheet = false

    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header with guide track
                guideTrackSection

                Divider()

                // Dub tracks list
                dubTracksSection

                Divider()

                // Alignment controls
                alignmentControlsSection

                Divider()

                // Action buttons
                actionButtonsSection
            }
            .navigationTitle("Vocal Alignment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Menu {
                        Button("Import Guide Track") {
                            showGuideFilePicker = true
                        }
                        Button("Import Dub Track") {
                            showDubFilePicker = true
                        }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title2)
                    }
                }
            }
            .fileImporter(
                isPresented: $showGuideFilePicker,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: false
            ) { result in
                handleGuideImport(result)
            }
            .fileImporter(
                isPresented: $showDubFilePicker,
                allowedContentTypes: [.audio],
                allowsMultipleSelection: true
            ) { result in
                handleDubImport(result)
            }
        }
    }

    // MARK: - Guide Track Section

    private var guideTrackSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "star.fill")
                    .foregroundColor(.yellow)
                Text("GUIDE TRACK")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 12)

            if let guide = aligner.guideTrack {
                GuideTrackRow(track: guide)
            } else {
                Button(action: { showGuideFilePicker = true }) {
                    HStack {
                        Image(systemName: "waveform.badge.plus")
                            .font(.title)
                        VStack(alignment: .leading) {
                            Text("Load Guide Track")
                                .fontWeight(.medium)
                            Text("The reference vocal that dubs will align to")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.horizontal)
            }
        }
        .padding(.bottom, 12)
        .background(Color(.systemBackground))
    }

    // MARK: - Dub Tracks Section

    private var dubTracksSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "person.2.fill")
                    .foregroundColor(.purple)
                Text("DUB TRACKS (\(aligner.dubTracks.count))")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                Spacer()

                Button(action: { showDubFilePicker = true }) {
                    Image(systemName: "plus")
                        .padding(8)
                        .background(Color.purple.opacity(0.2))
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)
            .padding(.top, 12)

            if aligner.dubTracks.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "waveform.path")
                        .font(.largeTitle)
                        .foregroundColor(.secondary)
                    Text("No dub tracks")
                        .foregroundColor(.secondary)
                    Text("Add vocal takes to align")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(aligner.dubTracks) { track in
                            DubTrackRow(
                                track: track,
                                result: aligner.alignmentResults[track.id],
                                isSelected: selectedTrackId == track.id,
                                onSelect: { selectedTrackId = track.id },
                                onPreview: { previewTrack(track.id) },
                                onDelete: { deleteTrack(track.id) }
                            )
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .frame(maxHeight: 300)
    }

    // MARK: - Alignment Controls Section

    private var alignmentControlsSection: some View {
        VStack(spacing: 16) {
            HStack {
                Image(systemName: "slider.horizontal.3")
                    .foregroundColor(.orange)
                Text("ALIGNMENT SETTINGS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundColor(.secondary)
                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 12)

            // Tightness slider
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Tightness")
                        .font(.subheadline)
                    Spacer()
                    Text("\(Int(aligner.tightness * 100))%")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }

                Slider(value: $aligner.tightness, in: 0...1)
                    .accentColor(.orange)

                HStack {
                    Text("Loose")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text("Tight")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .padding(.horizontal)

            // Options
            HStack(spacing: 20) {
                Toggle(isOn: $aligner.preserveFormants) {
                    HStack {
                        Image(systemName: "waveform.circle")
                        Text("Preserve Formants")
                            .font(.subheadline)
                    }
                }
                #if os(tvOS)
                .toggleStyle(.automatic)
                #else
                .toggleStyle(SwitchToggleStyle(tint: .green))
                #endif
            }
            .padding(.horizontal)
            .padding(.bottom, 12)
        }
        #if os(tvOS)
        .background(Color.gray.opacity(0.15))
        #else
        .background(Color(.secondarySystemBackground))
        #endif
    }

    // MARK: - Action Buttons Section

    private var actionButtonsSection: some View {
        VStack(spacing: 12) {
            // Progress bar (if processing)
            if aligner.isProcessing {
                VStack(spacing: 8) {
                    ProgressView(value: aligner.progress)
                        .progressViewStyle(LinearProgressViewStyle(tint: .green))

                    Text("Aligning... \(Int(aligner.progress * 100))%")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal)
                .padding(.top, 12)
            }

            // Main action buttons
            HStack(spacing: 16) {
                // Align All button
                Button(action: alignAllTracks) {
                    HStack {
                        Image(systemName: "wand.and.stars")
                        Text("Align All")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        aligner.guideTrack != nil && !aligner.dubTracks.isEmpty
                            ? Color.green
                            : Color.gray
                    )
                    .cornerRadius(12)
                }
                .disabled(aligner.guideTrack == nil || aligner.dubTracks.isEmpty || aligner.isProcessing)

                // Export button
                Button(action: { showExportSheet = true }) {
                    HStack {
                        Image(systemName: "square.and.arrow.up")
                        Text("Export")
                    }
                    .font(.headline)
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        !aligner.alignmentResults.isEmpty
                            ? Color.blue
                            : Color.gray
                    )
                    .cornerRadius(12)
                }
                .disabled(aligner.alignmentResults.isEmpty)
            }
            .padding(.horizontal)
            .padding(.vertical, 12)
        }
        #if os(tvOS)
        .background(Color.black)
        #else
        .background(Color(.systemBackground))
        #endif
    }

    // MARK: - Actions

    private func handleGuideImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            Task {
                do {
                    _ = url.startAccessingSecurityScopedResource()
                    defer { url.stopAccessingSecurityScopedResource() }
                    try await aligner.loadGuideTrack(from: url)
                } catch {
                    log.audio("❌ Failed to load guide: \(error)", level: .error)
                }
            }
        case .failure(let error):
            log.audio("❌ File picker error: \(error)", level: .error)
        }
    }

    private func handleDubImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            Task {
                for url in urls {
                    do {
                        _ = url.startAccessingSecurityScopedResource()
                        defer { url.stopAccessingSecurityScopedResource() }
                        try await aligner.addDubTrack(from: url)
                    } catch {
                        log.audio("❌ Failed to load dub: \(error)", level: .error)
                    }
                }
            }
        case .failure(let error):
            log.audio("❌ File picker error: \(error)", level: .error)
        }
    }

    private func alignAllTracks() {
        Task {
            do {
                try await aligner.alignAllTracks()
            } catch {
                log.audio("❌ Alignment failed: \(error)", level: .error)
            }
        }
    }

    private func previewTrack(_ id: UUID) {
        Task {
            do {
                try await aligner.previewAlignedTrack(id)
            } catch {
                log.audio("❌ Preview failed: \(error)", level: .error)
            }
        }
    }

    private func deleteTrack(_ id: UUID) {
        aligner.dubTracks.removeAll { $0.id == id }
        aligner.alignmentResults.removeValue(forKey: id)
    }
}

// MARK: - Supporting Views

struct GuideTrackRow: View {
    let track: AutomaticVocalAligner.VocalTrack

    var body: some View {
        HStack(spacing: 12) {
            // Waveform icon
            ZStack {
                Circle()
                    .fill(Color.yellow.opacity(0.2))
                    .frame(width: 50, height: 50)
                Image(systemName: "waveform")
                    .font(.title2)
                    .foregroundColor(.yellow)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(track.name)
                    .fontWeight(.medium)
                Text(track.url.lastPathComponent)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(formatDuration(track.duration))
                .font(.caption)
                .foregroundColor(.secondary)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.secondary.opacity(0.2))
                .cornerRadius(4)
        }
        .padding()
        .background(Color.yellow.opacity(0.1))
        .cornerRadius(12)
        .padding(.horizontal)
    }

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }
}

struct DubTrackRow: View {
    let track: AutomaticVocalAligner.VocalTrack
    let result: AutomaticVocalAligner.AlignmentResult?
    let isSelected: Bool
    let onSelect: () -> Void
    let onPreview: () -> Void
    let onDelete: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Status indicator
            ZStack {
                Circle()
                    .fill(statusColor.opacity(0.2))
                    .frame(width: 44, height: 44)
                Image(systemName: statusIcon)
                    .foregroundColor(statusColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(track.name)
                    .fontWeight(.medium)

                if let result = result {
                    HStack(spacing: 8) {
                        Text("Quality: \(Int(result.qualityScore))%")
                            .font(.caption)
                            .foregroundColor(qualityColor(result.qualityScore))

                        Text("\(String(format: "%.2f", result.processingTime))s")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Text("Not aligned")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            // Preview button
            if result != nil {
                Button(action: onPreview) {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.green)
                }
            }

            // Delete button
            Button(action: onDelete) {
                Image(systemName: "trash.circle.fill")
                    .font(.title2)
                    .foregroundColor(.red.opacity(0.7))
            }
        }
        .padding()
        #if os(tvOS)
        .background(isSelected ? Color.purple.opacity(0.1) : Color.gray.opacity(0.15))
        #else
        .background(isSelected ? Color.purple.opacity(0.1) : Color(.tertiarySystemBackground))
        #endif
        .cornerRadius(12)
        #if !os(tvOS)
        .onTapGesture(perform: onSelect)
        #endif
    }

    private var statusColor: Color {
        if result != nil {
            return .green
        }
        return .purple
    }

    private var statusIcon: String {
        if result != nil {
            return "checkmark"
        }
        return "waveform"
    }

    private func qualityColor(_ quality: Float) -> Color {
        if quality >= 80 { return .green }
        if quality >= 60 { return .yellow }
        return .orange
    }
}

// MARK: - Preview

#Preview {
    VocalAlignmentView()
        .preferredColorScheme(.dark)
}
