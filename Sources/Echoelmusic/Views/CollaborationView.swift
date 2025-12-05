import SwiftUI

// MARK: - Collaboration View
// Real-time music collaboration with ultra-low latency

public struct CollaborationView: View {
    @StateObject private var collabEngine = UltraLowLatencyCollabEngine.shared

    @State private var showCreateSession = false
    @State private var showJoinSession = false
    @State private var joinSessionId = ""
    @State private var showInvite = false
    @State private var showSettings = false

    public var body: some View {
        NavigationStack {
            Group {
                if collabEngine.isConnected {
                    sessionView
                } else {
                    welcomeView
                }
            }
            .navigationTitle("Collaboration")
            .toolbar {
                if collabEngine.isConnected {
                    ToolbarItem(placement: .primaryAction) {
                        Menu {
                            Button(action: { showInvite = true }) {
                                Label("Invite", systemImage: "person.badge.plus")
                            }
                            Button(action: { showSettings = true }) {
                                Label("Settings", systemImage: "gear")
                            }
                            Divider()
                            Button(role: .destructive, action: leaveSession) {
                                Label("Leave Session", systemImage: "door.left.hand.open")
                            }
                        } label: {
                            Image(systemName: "ellipsis.circle")
                        }
                    }
                }
            }
            .sheet(isPresented: $showCreateSession) {
                CreateSessionView()
            }
            .sheet(isPresented: $showJoinSession) {
                JoinSessionView()
            }
            .sheet(isPresented: $showInvite) {
                InviteView(sessionId: collabEngine.sessionId ?? "")
            }
            .sheet(isPresented: $showSettings) {
                CollabSettingsView()
            }
        }
    }

    // MARK: - Welcome View

    private var welcomeView: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "person.2.wave.2")
                .font(.system(size: 80))
                .foregroundStyle(.accentColor)

            VStack(spacing: 8) {
                Text("Real-time Collaboration")
                    .font(.title)
                    .fontWeight(.bold)

                Text("Create music together with ultra-low latency")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 16) {
                Button(action: { showCreateSession = true }) {
                    Label("Create Session", systemImage: "plus.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)

                Button(action: { showJoinSession = true }) {
                    Label("Join Session", systemImage: "person.badge.plus")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }
            .padding(.horizontal, 40)

            Spacer()

            // Features
            HStack(spacing: 24) {
                FeatureBadge(icon: "bolt.fill", text: "<50ms")
                FeatureBadge(icon: "waveform", text: "Audio Sync")
                FeatureBadge(icon: "pianokeys", text: "MIDI Sync")
            }
            .padding()
        }
    }

    // MARK: - Session View

    private var sessionView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Session info
                sessionInfoCard

                // Connection quality
                connectionQualityCard

                // Participants
                participantsSection

                // Activity feed
                activitySection

                // Quick actions
                quickActionsSection
            }
            .padding()
        }
    }

    // MARK: - Session Info Card

    private var sessionInfoCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Session")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text(collabEngine.sessionId ?? "—")
                    .font(.title2)
                    .fontWeight(.bold)
                    .fontDesign(.monospaced)
            }

            Spacer()

            Button(action: copySessionId) {
                Image(systemName: "doc.on.doc")
            }
            .buttonStyle(.bordered)
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Connection Quality

    private var connectionQualityCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Connection Quality")
                    .font(.headline)

                Spacer()

                SyncQualityBadge(quality: collabEngine.syncQuality)
            }

            HStack(spacing: 24) {
                MetricView(
                    title: "Latency",
                    value: String(format: "%.0f ms", collabEngine.latencyMs),
                    color: latencyColor(collabEngine.latencyMs)
                )

                MetricView(
                    title: "Jitter",
                    value: String(format: "%.1f ms", collabEngine.jitterMs),
                    color: jitterColor(collabEngine.jitterMs)
                )

                MetricView(
                    title: "Participants",
                    value: "\(collabEngine.participants.count)",
                    color: .blue
                )
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Participants Section

    private var participantsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack {
                Text("Participants")
                    .font(.headline)

                Spacer()

                Button(action: { showInvite = true }) {
                    Image(systemName: "person.badge.plus")
                }
            }

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                ForEach(collabEngine.participants) { participant in
                    ParticipantAvatar(participant: participant)
                }

                // Add placeholder
                Button(action: { showInvite = true }) {
                    VStack {
                        Circle()
                            .strokeBorder(style: StrokeStyle(lineWidth: 2, dash: [5]))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Image(systemName: "plus")
                            )

                        Text("Invite")
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
        }
    }

    // MARK: - Activity Section

    private var activitySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Activity")
                .font(.headline)

            VStack(spacing: 8) {
                ActivityRow(user: "You", action: "joined the session", time: "just now")
                ActivityRow(user: "System", action: "low latency mode enabled", time: "1m ago")
            }
        }
    }

    // MARK: - Quick Actions

    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Quick Actions")
                .font(.headline)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 3), spacing: 12) {
                CollabActionButton(title: "Sync Transport", icon: "play.circle", color: .green) {
                    collabEngine.syncTransport(position: 0, isPlaying: true)
                }

                CollabActionButton(title: "Share Track", icon: "waveform", color: .blue) {
                    // Share track
                }

                CollabActionButton(title: "Chat", icon: "bubble.left", color: .purple) {
                    // Open chat
                }

                CollabActionButton(title: "Send MIDI", icon: "pianokeys", color: .orange) {
                    // Send MIDI
                }

                CollabActionButton(title: "Record", icon: "record.circle", color: .red) {
                    // Record
                }

                CollabActionButton(title: "Metronome", icon: "metronome", color: .cyan) {
                    // Toggle metronome
                }
            }
        }
    }

    // MARK: - Actions

    private func copySessionId() {
        #if os(iOS)
        UIPasteboard.general.string = collabEngine.sessionId
        #endif
    }

    private func leaveSession() {
        Task {
            await collabEngine.leaveSession()
        }
    }

    // MARK: - Helpers

    private func latencyColor(_ latency: Double) -> Color {
        if latency < 30 { return .green }
        if latency < 50 { return .yellow }
        if latency < 100 { return .orange }
        return .red
    }

    private func jitterColor(_ jitter: Double) -> Color {
        if jitter < 5 { return .green }
        if jitter < 10 { return .yellow }
        if jitter < 20 { return .orange }
        return .red
    }
}

// MARK: - Supporting Views

struct FeatureBadge: View {
    let icon: String
    let text: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(.accentColor)
            Text(text)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}

struct SyncQualityBadge: View {
    let quality: SyncQuality

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(qualityColor)
                .frame(width: 8, height: 8)
            Text(quality.rawValue)
                .font(.caption)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 4)
        .background(qualityColor.opacity(0.2))
        .clipShape(Capsule())
    }

    private var qualityColor: Color {
        switch quality {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .yellow
        case .poor: return .red
        }
    }
}

struct MetricView: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.headline)
                .foregroundStyle(color)
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

struct ParticipantAvatar: View {
    let participant: Participant

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .fill(Color(participant.color))
                    .frame(width: 50, height: 50)

                Text(participant.name.prefix(1).uppercased())
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundStyle(.white)

                // Online indicator
                Circle()
                    .fill(Color.green)
                    .frame(width: 12, height: 12)
                    .overlay(
                        Circle().stroke(Color(.systemBackground), lineWidth: 2)
                    )
                    .offset(x: 18, y: 18)
            }

            Text(participant.name)
                .font(.caption)
                .lineLimit(1)

            if participant.latencyMs > 0 {
                Text("\(Int(participant.latencyMs))ms")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
        }
    }
}

struct ActivityRow: View {
    let user: String
    let action: String
    let time: String

    var body: some View {
        HStack {
            Circle()
                .fill(Color.accentColor)
                .frame(width: 8, height: 8)

            Text(user)
                .fontWeight(.medium)

            Text(action)
                .foregroundStyle(.secondary)

            Spacer()

            Text(time)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .font(.subheadline)
    }
}

struct CollabActionButton: View {
    let title: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 8) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundStyle(color)

                Text(title)
                    .font(.caption)
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(color.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

struct CreateSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sessionName = ""
    @State private var isCreating = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Session Name", text: $sessionName)
                } header: {
                    Text("Session Details")
                }

                Section {
                    LabeledContent("Latency Mode", value: "Ultra Low")
                    LabeledContent("Max Participants", value: "8")
                    LabeledContent("Audio Quality", value: "48kHz / 24-bit")
                } header: {
                    Text("Settings")
                }
            }
            .navigationTitle("Create Session")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Create") {
                        createSession()
                    }
                    .disabled(sessionName.isEmpty || isCreating)
                }
            }
        }
    }

    private func createSession() {
        isCreating = true
        Task {
            do {
                _ = try await UltraLowLatencyCollabEngine.shared.createSession(name: sessionName)
                dismiss()
            } catch {
                isCreating = false
            }
        }
    }
}

struct JoinSessionView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var sessionId = ""
    @State private var isJoining = false

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Session ID", text: $sessionId)
                        .textContentType(.oneTimeCode)
                        .autocorrectionDisabled()
                } header: {
                    Text("Enter Session ID")
                } footer: {
                    Text("Get the session ID from the host")
                }
            }
            .navigationTitle("Join Session")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Join") {
                        joinSession()
                    }
                    .disabled(sessionId.isEmpty || isJoining)
                }
            }
        }
    }

    private func joinSession() {
        isJoining = true
        Task {
            do {
                try await UltraLowLatencyCollabEngine.shared.joinSession(sessionId)
                dismiss()
            } catch {
                isJoining = false
            }
        }
    }
}

struct InviteView: View {
    let sessionId: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Image(systemName: "person.badge.plus")
                    .font(.system(size: 60))
                    .foregroundStyle(.accentColor)

                Text("Invite Collaborators")
                    .font(.title2)
                    .fontWeight(.bold)

                VStack(spacing: 8) {
                    Text("Session ID")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Text(sessionId)
                        .font(.title)
                        .fontDesign(.monospaced)
                        .fontWeight(.bold)
                }

                HStack(spacing: 16) {
                    Button(action: copyId) {
                        Label("Copy ID", systemImage: "doc.on.doc")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button(action: shareId) {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding(.horizontal)
            }
            .padding()
            .navigationTitle("Invite")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    private func copyId() {
        #if os(iOS)
        UIPasteboard.general.string = sessionId
        #endif
    }

    private func shareId() {
        // Share sheet
    }
}

struct CollabSettingsView: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Audio") {
                    Picker("Buffer Size", selection: .constant(64)) {
                        Text("32 samples").tag(32)
                        Text("64 samples").tag(64)
                        Text("128 samples").tag(128)
                    }

                    Toggle("Use Opus Codec", isOn: .constant(true))
                    Toggle("Audio Prediction", isOn: .constant(true))
                }

                Section("Network") {
                    Picker("Server Region", selection: .constant("Auto")) {
                        Text("Auto").tag("Auto")
                        Text("US East").tag("US East")
                        Text("Europe").tag("Europe")
                        Text("Asia").tag("Asia")
                    }

                    Toggle("Jitter Compensation", isOn: .constant(true))
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

#Preview {
    CollaborationView()
}
