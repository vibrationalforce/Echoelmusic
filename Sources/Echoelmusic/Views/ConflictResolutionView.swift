import SwiftUI

// MARK: - Conflict Resolution View
// Visual interface for resolving sync conflicts in collaborative sessions

public struct ConflictResolutionView: View {
    @StateObject private var syncEngine = CRDTSyncEngine.shared
    @Environment(\.dismiss) private var dismiss

    @State private var selectedResolutions: [String: ConflictResolution] = [:]
    @State private var showPreview = false
    @State private var previewConflict: SyncConflict?

    public var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if syncEngine.pendingConflicts.isEmpty {
                    noConflictsView
                } else {
                    conflictListView
                }
            }
            .navigationTitle("Resolve Conflicts")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Later") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Apply All") {
                        applyResolutions()
                    }
                    .disabled(selectedResolutions.count != syncEngine.pendingConflicts.count)
                }
            }
            .sheet(isPresented: $showPreview) {
                if let conflict = previewConflict {
                    ConflictPreviewView(conflict: conflict)
                }
            }
        }
    }

    // MARK: - No Conflicts View

    private var noConflictsView: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.green)

            Text("All Synced")
                .font(.title2)
                .fontWeight(.semibold)

            Text("No conflicts to resolve")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Conflict List View

    private var conflictListView: some View {
        List {
            // Summary section
            Section {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("\(syncEngine.pendingConflicts.count) conflicts")
                            .font(.headline)
                        Text("Select resolution for each")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    // Quick actions
                    Menu {
                        Button(action: keepAllLocal) {
                            Label("Keep All Local", systemImage: "iphone")
                        }
                        Button(action: keepAllRemote) {
                            Label("Keep All Remote", systemImage: "cloud")
                        }
                        Button(action: useNewest) {
                            Label("Use Newest", systemImage: "clock")
                        }
                    } label: {
                        Text("Quick Actions")
                            .font(.subheadline)
                    }
                }
            }

            // Individual conflicts
            Section("Conflicts") {
                ForEach(syncEngine.pendingConflicts) { conflict in
                    ConflictRow(
                        conflict: conflict,
                        selectedResolution: selectedResolutions[conflict.id],
                        onSelect: { resolution in
                            selectedResolutions[conflict.id] = resolution
                        },
                        onPreview: {
                            previewConflict = conflict
                            showPreview = true
                        }
                    )
                }
            }
        }
    }

    // MARK: - Actions

    private func keepAllLocal() {
        for conflict in syncEngine.pendingConflicts {
            selectedResolutions[conflict.id] = .keepLocal
        }
    }

    private func keepAllRemote() {
        for conflict in syncEngine.pendingConflicts {
            selectedResolutions[conflict.id] = .keepRemote
        }
    }

    private func useNewest() {
        for conflict in syncEngine.pendingConflicts {
            if conflict.localTimestamp > conflict.remoteTimestamp {
                selectedResolutions[conflict.id] = .keepLocal
            } else {
                selectedResolutions[conflict.id] = .keepRemote
            }
        }
    }

    private func applyResolutions() {
        Task {
            for (conflictId, resolution) in selectedResolutions {
                await syncEngine.resolveConflict(id: conflictId, with: resolution)
            }
            dismiss()
        }
    }
}

// MARK: - Conflict Row

struct ConflictRow: View {
    let conflict: SyncConflict
    let selectedResolution: ConflictResolution?
    let onSelect: (ConflictResolution) -> Void
    let onPreview: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Image(systemName: conflict.type.icon)
                    .foregroundStyle(conflict.type.color)

                VStack(alignment: .leading, spacing: 2) {
                    Text(conflict.itemName)
                        .font(.headline)
                    Text(conflict.type.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button(action: onPreview) {
                    Image(systemName: "eye")
                        .padding(8)
                        .background(Color(.systemGray5))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }

            // Comparison
            HStack(spacing: 12) {
                // Local version
                VersionCard(
                    title: "Local",
                    icon: "iphone",
                    timestamp: conflict.localTimestamp,
                    preview: conflict.localPreview,
                    isSelected: selectedResolution == .keepLocal
                ) {
                    onSelect(.keepLocal)
                }

                // VS indicator
                Text("vs")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                // Remote version
                VersionCard(
                    title: "Remote",
                    icon: "cloud",
                    timestamp: conflict.remoteTimestamp,
                    preview: conflict.remotePreview,
                    isSelected: selectedResolution == .keepRemote
                ) {
                    onSelect(.keepRemote)
                }
            }

            // Merge option if available
            if conflict.canMerge {
                Button(action: { onSelect(.merge) }) {
                    HStack {
                        Image(systemName: "arrow.triangle.merge")
                        Text("Smart Merge")
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(10)
                    .background(selectedResolution == .merge ? Color.purple.opacity(0.2) : Color(.systemGray6))
                    .foregroundStyle(selectedResolution == .merge ? .purple : .primary)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Version Card

struct VersionCard: View {
    let title: String
    let icon: String
    let timestamp: Date
    let preview: String
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: icon)
                        .font(.caption)
                    Text(title)
                        .font(.caption)
                        .fontWeight(.medium)

                    Spacer()

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    }
                }

                Text(preview)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)

                Text(timestamp, style: .relative)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.systemGray6))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Conflict Preview View

struct ConflictPreviewView: View {
    let conflict: SyncConflict
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Local version
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "iphone")
                            Text("Local Version")
                                .font(.headline)
                        }

                        Text(conflict.localFullContent)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Divider
                    HStack {
                        Rectangle()
                            .fill(Color(.separator))
                            .frame(height: 1)
                        Text("CHANGES")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Rectangle()
                            .fill(Color(.separator))
                            .frame(height: 1)
                    }

                    // Remote version
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "cloud")
                            Text("Remote Version")
                                .font(.headline)
                        }

                        Text(conflict.remoteFullContent)
                            .font(.system(.body, design: .monospaced))
                            .padding()
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Diff visualization
                    if let diff = conflict.diff {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "arrow.triangle.merge")
                                Text("Differences")
                                    .font(.headline)
                            }

                            DiffView(diff: diff)
                        }
                    }
                }
                .padding()
            }
            .navigationTitle(conflict.itemName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Diff View

struct DiffView: View {
    let diff: ConflictDiff

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(diff.lines, id: \.self) { line in
                HStack(spacing: 8) {
                    Text(line.prefix)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(line.color)
                        .frame(width: 20)

                    Text(line.content)
                        .font(.system(.caption, design: .monospaced))
                        .foregroundStyle(line.color)
                }
                .padding(.vertical, 2)
                .padding(.horizontal, 8)
                .background(line.backgroundColor)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

// MARK: - Supporting Types

public enum ConflictResolution: String, CaseIterable {
    case keepLocal = "Keep Local"
    case keepRemote = "Keep Remote"
    case merge = "Smart Merge"
}

public struct SyncConflict: Identifiable {
    public let id: String
    public let itemName: String
    public let type: ConflictType
    public let localTimestamp: Date
    public let remoteTimestamp: Date
    public let localPreview: String
    public let remotePreview: String
    public let localFullContent: String
    public let remoteFullContent: String
    public let canMerge: Bool
    public let diff: ConflictDiff?

    public init(
        id: String = UUID().uuidString,
        itemName: String,
        type: ConflictType,
        localTimestamp: Date = Date(),
        remoteTimestamp: Date = Date(),
        localPreview: String = "",
        remotePreview: String = "",
        localFullContent: String = "",
        remoteFullContent: String = "",
        canMerge: Bool = false,
        diff: ConflictDiff? = nil
    ) {
        self.id = id
        self.itemName = itemName
        self.type = type
        self.localTimestamp = localTimestamp
        self.remoteTimestamp = remoteTimestamp
        self.localPreview = localPreview
        self.remotePreview = remotePreview
        self.localFullContent = localFullContent
        self.remoteFullContent = remoteFullContent
        self.canMerge = canMerge
        self.diff = diff
    }
}

public enum ConflictType: String, CaseIterable {
    case track = "Track Conflict"
    case parameter = "Parameter Conflict"
    case arrangement = "Arrangement Conflict"
    case automation = "Automation Conflict"
    case plugin = "Plugin Conflict"

    var icon: String {
        switch self {
        case .track: return "waveform"
        case .parameter: return "slider.horizontal.3"
        case .arrangement: return "rectangle.split.3x1"
        case .automation: return "point.3.filled.connected.trianglepath.dotted"
        case .plugin: return "puzzlepiece.extension"
        }
    }

    var color: Color {
        switch self {
        case .track: return .blue
        case .parameter: return .orange
        case .arrangement: return .purple
        case .automation: return .green
        case .plugin: return .pink
        }
    }
}

public struct ConflictDiff {
    public let lines: [DiffLine]

    public init(lines: [DiffLine]) {
        self.lines = lines
    }
}

public struct DiffLine: Hashable {
    public let prefix: String
    public let content: String
    public let type: DiffType

    public var color: Color {
        switch type {
        case .unchanged: return .secondary
        case .added: return .green
        case .removed: return .red
        }
    }

    public var backgroundColor: Color {
        switch type {
        case .unchanged: return .clear
        case .added: return .green.opacity(0.1)
        case .removed: return .red.opacity(0.1)
        }
    }

    public init(prefix: String, content: String, type: DiffType) {
        self.prefix = prefix
        self.content = content
        self.type = type
    }
}

public enum DiffType {
    case unchanged
    case added
    case removed
}

// MARK: - CRDTSyncEngine Extension

extension CRDTSyncEngine {
    @Published public var pendingConflicts: [SyncConflict] {
        get { _pendingConflicts }
        set { _pendingConflicts = newValue }
    }

    @MainActor
    public func resolveConflict(id: String, with resolution: ConflictResolution) async {
        guard let index = pendingConflicts.firstIndex(where: { $0.id == id }) else { return }
        let conflict = pendingConflicts[index]

        switch resolution {
        case .keepLocal:
            // Apply local version
            await applyLocalVersion(for: conflict)
        case .keepRemote:
            // Apply remote version
            await applyRemoteVersion(for: conflict)
        case .merge:
            // Perform smart merge
            await performSmartMerge(for: conflict)
        }

        pendingConflicts.remove(at: index)
    }

    private func applyLocalVersion(for conflict: SyncConflict) async {
        // Implementation would push local state
        print("Applying local version for: \(conflict.itemName)")
    }

    private func applyRemoteVersion(for conflict: SyncConflict) async {
        // Implementation would accept remote state
        print("Applying remote version for: \(conflict.itemName)")
    }

    private func performSmartMerge(for conflict: SyncConflict) async {
        // Implementation would merge changes
        print("Performing smart merge for: \(conflict.itemName)")
    }
}

#Preview {
    ConflictResolutionView()
}
