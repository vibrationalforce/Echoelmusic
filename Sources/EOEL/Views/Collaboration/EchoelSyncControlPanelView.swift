//
//  EchoelSyncControlPanelView.swift
//  EOEL
//
//  Created: 2025-11-25
//  Copyright © 2025 EOEL. All rights reserved.
//
//  EchoelSync Control Panel - Worldwide Real-Time Collaboration
//  Ableton Link + Steinberg VST Connect + Audiomovers Listento level UI
//  Ultra-professional collaboration interface
//

import SwiftUI

/// Professional control panel for EchoelSync worldwide collaboration
struct EchoelSyncControlPanelView: View {
    @StateObject private var syncEngine = EchoelSyncEngine.shared
    @State private var selectedTab: SyncTab = .session
    @State private var showJoinDialog = false
    @State private var joinAddress = ""
    @State private var sessionPassword = ""
    @State private var chatText = ""
    @State private var showSettings = false

    enum SyncTab: String, CaseIterable {
        case session = "Session"
        case peers = "Peers"
        case transport = "Transport"
        case audio = "Audio"
        case chat = "Chat"
        case sync = "Sync Monitor"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            // Tab Bar
            tabBar

            Divider()

            // Content
            TabView(selection: $selectedTab) {
                sessionView
                    .tag(SyncTab.session)

                peersView
                    .tag(SyncTab.peers)

                transportView
                    .tag(SyncTab.transport)

                audioView
                    .tag(SyncTab.audio)

                chatView
                    .tag(SyncTab.chat)

                syncMonitorView
                    .tag(SyncTab.sync)
            }
            .tabViewStyle(.automatic)
        }
        .frame(minWidth: 900, minHeight: 700)
        .sheet(isPresented: $showJoinDialog) {
            joinSessionDialog
        }
        .sheet(isPresented: $showSettings) {
            settingsView
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            // Logo & Title
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Image(systemName: "network")
                        .font(.title)
                        .foregroundColor(.blue)

                    Text("EchoelSync")
                        .font(.title2)
                        .fontWeight(.bold)
                }

                Text("Worldwide Real-Time Collaboration")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Status Indicator
            HStack(spacing: 12) {
                // Sync Quality
                HStack(spacing: 6) {
                    Circle()
                        .fill(syncQualityColor)
                        .frame(width: 12, height: 12)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sync Quality")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Text(syncEngine.syncQuality.rawValue)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                }

                Divider()
                    .frame(height: 30)

                // Latency
                VStack(alignment: .leading, spacing: 2) {
                    Text("Latency")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text(String(format: "%.1f ms", syncEngine.latency))
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(latencyColor)
                }

                Divider()
                    .frame(height: 30)

                // Peers
                VStack(alignment: .leading, spacing: 2) {
                    Text("Connected")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("\(syncEngine.connectedPeers.count) Peers")
                        .font(.caption)
                        .fontWeight(.semibold)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.gray.opacity(0.1))
            .cornerRadius(8)

            // Settings
            Button {
                showSettings = true
            } label: {
                Image(systemName: "gearshape")
                    .font(.title3)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }

    private var syncQualityColor: Color {
        switch syncEngine.syncQuality {
        case .excellent: return .green
        case .good: return .blue
        case .fair: return .yellow
        case .poor: return .orange
        case .unusable: return .red
        }
    }

    private var latencyColor: Color {
        if syncEngine.latency < 10 {
            return .green
        } else if syncEngine.latency < 30 {
            return .blue
        } else if syncEngine.latency < 50 {
            return .orange
        } else {
            return .red
        }
    }

    // MARK: - Tab Bar

    private var tabBar: some View {
        HStack(spacing: 0) {
            ForEach(SyncTab.allCases, id: \.self) { tab in
                Button {
                    selectedTab = tab
                } label: {
                    VStack(spacing: 4) {
                        Image(systemName: iconForTab(tab))
                            .font(.title3)
                        Text(tab.rawValue)
                            .font(.caption)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .background(selectedTab == tab ? Color.blue.opacity(0.1) : Color.clear)
                    .foregroundColor(selectedTab == tab ? .blue : .primary)
                }
                .buttonStyle(.plain)
            }
        }
        .background(Color.gray.opacity(0.05))
    }

    private func iconForTab(_ tab: SyncTab) -> String {
        switch tab {
        case .session: return "network"
        case .peers: return "person.3"
        case .transport: return "play.circle"
        case .audio: return "waveform"
        case .chat: return "message"
        case .sync: return "gauge"
        }
    }

    // MARK: - Session View

    private var sessionView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Enable/Disable
                GroupBox {
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("EchoelSync Engine")
                                    .font(.headline)
                                Text(syncEngine.isEnabled ? "Active and listening on port 7400" : "Disabled")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            Toggle("", isOn: Binding(
                                get: { syncEngine.isEnabled },
                                set: { enabled in
                                    if enabled {
                                        try? syncEngine.enable()
                                    } else {
                                        syncEngine.disable()
                                    }
                                }
                            ))
                            .toggleStyle(.switch)
                        }

                        if syncEngine.isEnabled, let localPeer = syncEngine.localPeer {
                            Divider()

                            VStack(spacing: 8) {
                                HStack {
                                    Text("Your Address:")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    Text("\(localPeer.ipAddress):7400")
                                        .font(.caption.monospaced())
                                        .fontWeight(.semibold)

                                    Button {
                                        let address = "\(localPeer.ipAddress):7400"
                                        NSPasteboard.general.clearContents()
                                        NSPasteboard.general.setString(address, forType: .string)
                                    } label: {
                                        Image(systemName: "doc.on.doc")
                                    }
                                    .buttonStyle(.plain)

                                    Spacer()
                                }

                                Text("Share this address with collaborators so they can join your session")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                    .padding()
                }

                if syncEngine.isEnabled {
                    // Session Management
                    GroupBox("Session Management") {
                        VStack(spacing: 16) {
                            if syncEngine.sessionID == nil {
                                // Not in session
                                VStack(spacing: 12) {
                                    Text("You are not currently in a collaboration session")
                                        .font(.caption)
                                        .foregroundColor(.secondary)

                                    HStack(spacing: 12) {
                                        Button {
                                            let sessionID = syncEngine.createSession(name: "My Session")
                                            print("Created session: \(sessionID)")
                                        } label: {
                                            Label("Create Session", systemImage: "plus.circle")
                                                .frame(maxWidth: .infinity)
                                        }
                                        .buttonStyle(.borderedProminent)

                                        Button {
                                            showJoinDialog = true
                                        } label: {
                                            Label("Join Session", systemImage: "person.badge.plus")
                                                .frame(maxWidth: .infinity)
                                        }
                                        .buttonStyle(.bordered)
                                    }
                                }
                                .padding()
                            } else {
                                // In session
                                VStack(spacing: 12) {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Active Session")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                            Text(syncEngine.sessionID ?? "Unknown")
                                                .font(.caption.monospaced())
                                                .fontWeight(.semibold)
                                        }

                                        Spacer()

                                        Button("Leave Session") {
                                            syncEngine.leaveSession()
                                        }
                                        .buttonStyle(.bordered)
                                        .tint(.red)
                                    }

                                    // Session Stats
                                    HStack(spacing: 20) {
                                        statItem(title: "State", value: syncEngine.sessionState.rawValue)
                                        Divider().frame(height: 30)
                                        statItem(title: "Peers", value: "\(syncEngine.connectedPeers.count)")
                                        Divider().frame(height: 30)
                                        statItem(title: "Tempo", value: "\(Int(syncEngine.tempo)) BPM")
                                        Divider().frame(height: 30)
                                        statItem(title: "Time Sig", value: syncEngine.timeSignature.description)
                                    }
                                }
                                .padding()
                            }
                        }
                    }
                }

                // Quick Start Guide
                GroupBox("Quick Start") {
                    VStack(alignment: .leading, spacing: 12) {
                        quickStartStep(number: 1, text: "Enable EchoelSync engine above")
                        quickStartStep(number: 2, text: "Create a new session or join an existing one")
                        quickStartStep(number: 3, text: "Share your IP address with collaborators")
                        quickStartStep(number: 4, text: "Start playing - everything stays in perfect sync!")
                    }
                    .padding()
                }
            }
            .padding()
        }
    }

    private func statItem(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
    }

    private func quickStartStep(number: Int, text: String) -> some View {
        HStack(spacing: 12) {
            Text("\(number)")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 24, height: 24)
                .background(Circle().fill(Color.blue))

            Text(text)
                .font(.caption)
        }
    }

    // MARK: - Peers View

    private var peersView: some View {
        ScrollView {
            VStack(spacing: 16) {
                if syncEngine.connectedPeers.isEmpty {
                    VStack(spacing: 12) {
                        Image(systemName: "person.3.slash")
                            .font(.system(size: 48))
                            .foregroundColor(.secondary)

                        Text("No Connected Peers")
                            .font(.headline)

                        Text("Create or join a session to collaborate with others")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(40)
                } else {
                    ForEach(syncEngine.connectedPeers) { peer in
                        PeerCard(peer: peer, syncEngine: syncEngine)
                    }
                }
            }
            .padding()
        }
    }

    // MARK: - Transport View

    private var transportView: some View {
        VStack(spacing: 24) {
            // Playback Controls
            GroupBox("Transport") {
                VStack(spacing: 20) {
                    // Play/Stop Buttons
                    HStack(spacing: 16) {
                        Button {
                            syncEngine.play()
                        } label: {
                            Label(syncEngine.isPlaying ? "Playing..." : "Play", systemImage: "play.circle.fill")
                                .font(.title2)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                        .disabled(syncEngine.isPlaying)
                        .tint(.green)

                        Button {
                            syncEngine.stop()
                        } label: {
                            Label("Stop", systemImage: "stop.circle.fill")
                                .font(.title2)
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .disabled(!syncEngine.isPlaying)
                        .tint(.red)
                    }

                    // Position Display
                    VStack(spacing: 8) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Bar")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text("\(syncEngine.currentBar)")
                                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                            }

                            Text(":")
                                .font(.system(size: 36, weight: .light))
                                .foregroundColor(.secondary)

                            VStack(alignment: .leading, spacing: 4) {
                                Text("Beat")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                                Text(String(format: "%.2f", syncEngine.currentBeat.truncatingRemainder(dividingBy: Double(syncEngine.timeSignature.numerator))))
                                    .font(.system(size: 36, weight: .bold, design: .monospaced))
                            }

                            Spacer()
                        }

                        // Beat Grid Visualization
                        beatGridView
                    }
                }
                .padding()
            }

            // Tempo Control
            GroupBox("Tempo") {
                VStack(spacing: 16) {
                    HStack {
                        Text("\(Int(syncEngine.tempo))")
                            .font(.system(size: 48, weight: .bold, design: .monospaced))
                        Text("BPM")
                            .font(.headline)
                            .foregroundColor(.secondary)

                        Spacer()
                    }

                    Slider(value: Binding(
                        get: { syncEngine.tempo },
                        set: { syncEngine.setTempo($0) }
                    ), in: 40...240, step: 1)

                    HStack {
                        ForEach([60, 90, 120, 140, 160], id: \.self) { bpm in
                            Button("\(bpm)") {
                                syncEngine.setTempo(Double(bpm))
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
                .padding()
            }

            // Time Signature
            GroupBox("Time Signature") {
                HStack(spacing: 20) {
                    ForEach([
                        (3, 4), (4, 4), (5, 4), (6, 8), (7, 8)
                    ], id: \.0) { numerator, denominator in
                        Button {
                            syncEngine.setTimeSignature(
                                EchoelSyncEngine.TimeSignature(numerator: numerator, denominator: denominator)
                            )
                        } label: {
                            VStack(spacing: 4) {
                                Text("\(numerator)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                Divider()
                                Text("\(denominator)")
                                    .font(.title2)
                                    .fontWeight(.bold)
                            }
                            .frame(width: 60, height: 60)
                            .background(
                                syncEngine.timeSignature.numerator == numerator &&
                                syncEngine.timeSignature.denominator == denominator ?
                                Color.blue.opacity(0.2) : Color.clear
                            )
                            .cornerRadius(8)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }

            // Quantization
            GroupBox("Quantization") {
                HStack(spacing: 12) {
                    ForEach(EchoelSyncEngine.Quantization.allCases, id: \.self) { quant in
                        Button {
                            syncEngine.quantization = quant
                        } label: {
                            Text(quant.rawValue)
                                .font(.caption)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(
                                    syncEngine.quantization == quant ?
                                    Color.blue : Color.gray.opacity(0.2)
                                )
                                .foregroundColor(
                                    syncEngine.quantization == quant ?
                                    .white : .primary
                                )
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding()
            }

            Spacer()
        }
        .padding()
    }

    private var beatGridView: some View {
        HStack(spacing: 4) {
            ForEach(0..<syncEngine.timeSignature.numerator, id: \.self) { beat in
                let currentBeatInt = Int(syncEngine.currentBeat.truncatingRemainder(dividingBy: Double(syncEngine.timeSignature.numerator)))

                Rectangle()
                    .fill(currentBeatInt == beat ? Color.blue : Color.gray.opacity(0.3))
                    .frame(height: 8)
                    .cornerRadius(4)
            }
        }
    }

    // MARK: - Audio View

    private var audioView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Audio Streaming
                GroupBox("Audio Streaming") {
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Status")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                Text(syncEngine.activeAudioStreams.isEmpty ? "Inactive" : "Streaming to \(syncEngine.activeAudioStreams.count) peers")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                            }

                            Spacer()

                            if syncEngine.activeAudioStreams.isEmpty {
                                Button("Start Streaming") {
                                    syncEngine.startAudioStream()
                                }
                                .buttonStyle(.borderedProminent)
                            } else {
                                Button("Stop Streaming") {
                                    syncEngine.stopAudioStream()
                                }
                                .buttonStyle(.bordered)
                                .tint(.red)
                            }
                        }

                        if !syncEngine.activeAudioStreams.isEmpty {
                            Divider()

                            VStack(spacing: 8) {
                                ForEach(syncEngine.activeAudioStreams) { stream in
                                    audioStreamRow(stream: stream)
                                }
                            }
                        }
                    }
                    .padding()
                }

                // Audio Settings
                GroupBox("Audio Settings") {
                    VStack(spacing: 16) {
                        settingRow(title: "Sample Rate", value: "48000 Hz")
                        Divider()
                        settingRow(title: "Channels", value: "Stereo (2)")
                        Divider()
                        settingRow(title: "Codec", value: "Opus (High Quality)")
                        Divider()
                        settingRow(title: "Bitrate", value: "256 kbps")
                        Divider()
                        settingRow(title: "Latency", value: "Ultra-Low (<5ms)")
                    }
                    .padding()
                }
            }
            .padding()
        }
    }

    private func audioStreamRow(stream: EchoelSyncEngine.AudioStream) -> some View {
        HStack {
            Image(systemName: "waveform.circle.fill")
                .foregroundColor(.blue)

            VStack(alignment: .leading, spacing: 2) {
                if let peer = syncEngine.connectedPeers.first(where: { $0.id == stream.peerID }) {
                    Text(peer.name)
                        .font(.caption)
                        .fontWeight(.semibold)
                } else {
                    Text("Unknown Peer")
                        .font(.caption)
                }

                Text("\(stream.codec.rawValue) • \(stream.bitrate) kbps")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Simple level meter
            HStack(spacing: 2) {
                ForEach(0..<10) { i in
                    Rectangle()
                        .fill(i < 7 ? Color.green : Color.gray.opacity(0.3))
                        .frame(width: 3, height: CGFloat(12 + i * 2))
                }
            }
        }
    }

    private func settingRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
    }

    // MARK: - Chat View

    private var chatView: some View {
        VStack(spacing: 0) {
            // Messages
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 12) {
                    ForEach(syncEngine.chatMessages) { message in
                        chatMessageView(message: message)
                    }
                }
                .padding()
            }
            .background(Color.gray.opacity(0.05))

            Divider()

            // Input
            HStack(spacing: 12) {
                TextField("Type a message...", text: $chatText)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit {
                        sendChatMessage()
                    }

                Button {
                    sendChatMessage()
                } label: {
                    Image(systemName: "paperplane.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(chatText.isEmpty)
            }
            .padding()
        }
    }

    private func chatMessageView(message: EchoelSyncEngine.ChatMessage) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: 8) {
                Text(message.userName)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(message.isSystemMessage ? .orange : .blue)

                Text(message.timestamp, style: .time)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }

            Text(message.message)
                .font(.caption)
                .padding(8)
                .background(Color.gray.opacity(0.1))
                .cornerRadius(6)
        }
    }

    private func sendChatMessage() {
        guard !chatText.isEmpty else { return }
        syncEngine.sendChatMessage(chatText)
        chatText = ""
    }

    // MARK: - Sync Monitor View

    private var syncMonitorView: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Overall Sync Quality
                GroupBox("Sync Quality") {
                    VStack(spacing: 16) {
                        // Quality Gauge
                        syncQualityGauge

                        HStack(spacing: 20) {
                            metricCard(title: "Latency", value: String(format: "%.1f ms", syncEngine.latency), color: latencyColor)
                            metricCard(title: "Jitter", value: String(format: "%.1f ms", syncEngine.jitter), color: .orange)
                            metricCard(title: "Packet Loss", value: String(format: "%.2f%%", syncEngine.packetLoss), color: .red)
                        }
                    }
                    .padding()
                }

                // Per-Peer Latency
                if !syncEngine.connectedPeers.isEmpty {
                    GroupBox("Peer Latency") {
                        VStack(spacing: 12) {
                            ForEach(syncEngine.connectedPeers) { peer in
                                peerLatencyRow(peer: peer)
                            }
                        }
                        .padding()
                    }
                }

                // Sync Recommendations
                GroupBox("Recommendations") {
                    VStack(alignment: .leading, spacing: 12) {
                        if syncEngine.latency < 10 {
                            recommendationRow(icon: "checkmark.circle.fill", color: .green, text: "Excellent sync quality - perfect for real-time collaboration")
                        } else if syncEngine.latency < 30 {
                            recommendationRow(icon: "checkmark.circle", color: .blue, text: "Good sync quality - suitable for most collaboration scenarios")
                        } else if syncEngine.latency < 50 {
                            recommendationRow(icon: "exclamationmark.triangle", color: .orange, text: "Fair sync quality - consider reducing buffer size or checking network")
                        } else {
                            recommendationRow(icon: "xmark.circle", color: .red, text: "Poor sync quality - check your network connection")
                        }
                    }
                    .padding()
                }
            }
            .padding()
        }
    }

    private var syncQualityGauge: some View {
        VStack(spacing: 12) {
            Text(syncEngine.syncQuality.rawValue)
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(syncQualityColor)

            // Quality bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.2))
                        .frame(height: 20)
                        .cornerRadius(10)

                    Rectangle()
                        .fill(syncQualityColor)
                        .frame(width: geometry.size.width * qualityPercentage, height: 20)
                        .cornerRadius(10)
                }
            }
            .frame(height: 20)
        }
    }

    private var qualityPercentage: CGFloat {
        switch syncEngine.syncQuality {
        case .excellent: return 1.0
        case .good: return 0.8
        case .fair: return 0.6
        case .poor: return 0.4
        case .unusable: return 0.2
        }
    }

    private func metricCard(title: String, value: String, color: Color) -> some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color.gray.opacity(0.1))
        .cornerRadius(8)
    }

    private func peerLatencyRow(peer: EchoelSyncEngine.Peer) -> some View {
        HStack {
            Circle()
                .fill(peer.status == .online ? Color.green : Color.gray)
                .frame(width: 8, height: 8)

            Text(peer.name)
                .font(.caption)

            Spacer()

            Text(String(format: "%.1f ms", peer.latency))
                .font(.caption.monospaced())
                .foregroundColor(peer.latency < 20 ? .green : (peer.latency < 50 ? .orange : .red))
        }
    }

    private func recommendationRow(icon: String, color: Color, text: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(color)
            Text(text)
                .font(.caption)
        }
    }

    // MARK: - Join Session Dialog

    private var joinSessionDialog: some View {
        VStack(spacing: 20) {
            Text("Join Collaboration Session")
                .font(.headline)

            VStack(alignment: .leading, spacing: 12) {
                Text("Peer Address")
                    .font(.caption)
                    .foregroundColor(.secondary)
                TextField("192.168.1.100:7400", text: $joinAddress)
                    .textFieldStyle(.roundedBorder)

                Text("Session Password (Optional)")
                    .font(.caption)
                    .foregroundColor(.secondary)
                SecureField("Password", text: $sessionPassword)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Button("Cancel") {
                    showJoinDialog = false
                }
                .buttonStyle(.bordered)

                Button("Join") {
                    Task {
                        try? await syncEngine.joinSession(
                            UUID().uuidString,
                            peerAddress: joinAddress,
                            password: sessionPassword.isEmpty ? nil : sessionPassword
                        )
                        showJoinDialog = false
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(joinAddress.isEmpty)
            }
        }
        .padding()
        .frame(width: 400)
    }

    // MARK: - Settings View

    private var settingsView: some View {
        VStack(spacing: 20) {
            Text("EchoelSync Settings")
                .font(.headline)

            Form {
                Section("Network") {
                    Toggle("Auto-discover peers on local network", isOn: .constant(true))
                    Toggle("Allow remote connections", isOn: .constant(true))
                }

                Section("Audio") {
                    Picker("Audio Quality", selection: .constant("high")) {
                        Text("Low (128 kbps)").tag("low")
                        Text("Medium (192 kbps)").tag("medium")
                        Text("High (256 kbps)").tag("high")
                        Text("Ultra (320 kbps)").tag("ultra")
                    }

                    Toggle("Auto-start audio streaming", isOn: .constant(false))
                }

                Section("Sync") {
                    Picker("Sync Mode", selection: .constant("auto")) {
                        Text("Automatic").tag("auto")
                        Text("Manual").tag("manual")
                    }

                    Toggle("Auto-quantize actions", isOn: .constant(true))
                }
            }
            .formStyle(.grouped)

            Button("Done") {
                showSettings = false
            }
            .buttonStyle(.borderedProminent)
        }
        .padding()
        .frame(width: 500, height: 400)
    }
}

// MARK: - Peer Card

struct PeerCard: View {
    let peer: EchoelSyncEngine.Peer
    @ObservedObject var syncEngine: EchoelSyncEngine

    var body: some View {
        GroupBox {
            VStack(spacing: 16) {
                // Header
                HStack {
                    Circle()
                        .fill(statusColor)
                        .frame(width: 12, height: 12)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(peer.name)
                            .font(.headline)
                        Text(peer.ipAddress)
                            .font(.caption.monospaced())
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if peer.isHost {
                        Text("HOST")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Color.blue)
                            .cornerRadius(4)
                    }
                }

                Divider()

                // Stats
                HStack(spacing: 16) {
                    statBox(title: "Latency", value: String(format: "%.1f ms", peer.latency))
                    statBox(title: "Tempo", value: "\(Int(peer.tempo)) BPM")
                    statBox(title: "Beat", value: String(format: "%.1f", peer.currentBeat))
                }

                // Instruments
                if !peer.instruments.isEmpty {
                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        Text("Active Instruments")
                            .font(.caption2)
                            .foregroundColor(.secondary)

                        HStack(spacing: 6) {
                            ForEach(peer.instruments, id: \.self) { instrument in
                                Text(instrument)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.blue.opacity(0.1))
                                    .cornerRadius(4)
                            }
                        }
                    }
                }

                // Audio/Video
                HStack(spacing: 12) {
                    Label(peer.audioEnabled ? "Audio On" : "Audio Off",
                          systemImage: peer.audioEnabled ? "speaker.wave.2.fill" : "speaker.slash.fill")
                        .font(.caption)
                        .foregroundColor(peer.audioEnabled ? .green : .secondary)

                    Label(peer.videoEnabled ? "Video On" : "Video Off",
                          systemImage: peer.videoEnabled ? "video.fill" : "video.slash.fill")
                        .font(.caption)
                        .foregroundColor(peer.videoEnabled ? .green : .secondary)

                    Spacer()
                }
            }
            .padding()
        }
    }

    private var statusColor: Color {
        switch peer.status {
        case .online: return .green
        case .away: return .yellow
        case .busy: return .orange
        case .offline: return .gray
        }
    }

    private func statBox(title: String, value: String) -> some View {
        VStack(spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)
            Text(value)
                .font(.caption)
                .fontWeight(.semibold)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    EchoelSyncControlPanelView()
        .frame(width: 1000, height: 800)
}
