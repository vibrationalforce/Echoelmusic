// SessionView.swift
// Session/Clip View (Ableton Live Style)
//
// Live performance clip launcher with scenes

import SwiftUI
import AVFoundation

/// Session/Clip View (Live Performance)
struct SessionView: View {

    @ObservedObject var session: LiveSession
    @ObservedObject var playbackEngine: PlaybackEngine

    // Selection
    @State private var selectedSlots: Set<String> = []  // "track_scene" format

    // Clip recording
    @State private var recordingTrackID: UUID?
    @State private var recordingSceneIndex: Int?

    var body: some View {
        VStack(spacing: 0) {
            // Transport controls
            SessionTransportView(session: session)
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Color.black.opacity(0.3))

            // Main session grid
            HStack(spacing: 0) {
                // Scene launch column (left)
                SceneLaunchColumn(session: session)
                    .frame(width: 100)

                // Clip grid
                ScrollView([.horizontal, .vertical]) {
                    VStack(spacing: 2) {
                        // Track headers
                        HStack(spacing: 2) {
                            ForEach(session.tracks) { track in
                                SessionTrackHeaderView(
                                    track: track,
                                    session: session
                                )
                                .frame(width: 150)
                            }
                        }

                        // Clip slots grid
                        ForEach(0..<session.sceneCount, id: \.self) { sceneIndex in
                            HStack(spacing: 2) {
                                ForEach(session.tracks) { track in
                                    ClipSlotView(
                                        slot: session.getSlot(trackID: track.id, sceneIndex: sceneIndex),
                                        session: session,
                                        trackID: track.id,
                                        sceneIndex: sceneIndex,
                                        isSelected: selectedSlots.contains("\(track.id)_\(sceneIndex)"),
                                        onTap: { handleSlotTap(track.id, sceneIndex) },
                                        onRecord: { startRecording(track.id, sceneIndex) }
                                    )
                                    .frame(width: 150, height: 80)
                                }
                            }
                        }
                    }
                }
            }

            // Master controls
            SessionMasterControls(session: session)
                .frame(height: 60)
                .background(Color.black.opacity(0.3))
        }
        .background(Color.black.opacity(0.8))
    }


    // MARK: - Actions

    private func handleSlotTap(_ trackID: UUID, _ sceneIndex: Int) {
        let slotKey = "\(trackID)_\(sceneIndex)"

        if let slot = session.getSlot(trackID: trackID, sceneIndex: sceneIndex) {
            // Launch or stop clip
            if slot.isPlaying {
                session.stopClip(trackID: trackID, sceneIndex: sceneIndex)
            } else {
                session.launchClip(trackID: trackID, sceneIndex: sceneIndex)
            }
        }

        // Toggle selection
        if selectedSlots.contains(slotKey) {
            selectedSlots.remove(slotKey)
        } else {
            selectedSlots.insert(slotKey)
        }
    }

    private func startRecording(_ trackID: UUID, _ sceneIndex: Int) {
        recordingTrackID = trackID
        recordingSceneIndex = sceneIndex
        session.recordClip(trackID: trackID, sceneIndex: sceneIndex)
    }
}


// MARK: - Session Transport

struct SessionTransportView: View {
    @ObservedObject var session: LiveSession

    var body: some View {
        HStack(spacing: 20) {
            // Global play/stop
            Button(action: { session.togglePlayback() }) {
                Image(systemName: session.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }

            Button(action: { session.stopAll() }) {
                Image(systemName: "stop.circle.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.white)
            }

            Spacer()

            // Tempo
            VStack(alignment: .trailing) {
                Text("Tempo")
                    .font(.caption)
                    .foregroundColor(.gray)

                HStack {
                    Button(action: { session.tempo = max(20, session.tempo - 1) }) {
                        Image(systemName: "minus")
                    }

                    Text("\(Int(session.tempo)) BPM")
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundColor(.white)
                        .frame(width: 100)

                    Button(action: { session.tempo = min(300, session.tempo + 1) }) {
                        Image(systemName: "plus")
                    }
                }
            }

            // Metronome
            Button(action: { session.metronomeEnabled.toggle() }) {
                Image(systemName: "metronome")
                    .font(.system(size: 24))
                    .foregroundColor(session.metronomeEnabled ? .green : .gray)
            }
        }
        .foregroundColor(.white)
    }
}


// MARK: - Scene Launch Column

struct SceneLaunchColumn: View {
    @ObservedObject var session: LiveSession

    var body: some View {
        VStack(spacing: 2) {
            // Header
            Text("Scenes")
                .font(.headline)
                .foregroundColor(.white)
                .frame(height: 40)
                .frame(maxWidth: .infinity)
                .background(Color.gray.opacity(0.3))

            // Scene buttons
            ForEach(0..<session.sceneCount, id: \.self) { sceneIndex in
                SceneLaunchButton(
                    scene: session.scenes[sceneIndex],
                    sceneIndex: sceneIndex,
                    session: session
                )
                .frame(height: 80)
            }

            Spacer()

            // Add scene button
            Button(action: { session.addScene() }) {
                HStack {
                    Image(systemName: "plus.circle")
                    Text("Add Scene")
                        .font(.caption)
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.3))
                .cornerRadius(4)
            }
            .padding(8)
        }
        .background(Color.black.opacity(0.5))
    }
}


// MARK: - Scene Launch Button

struct SceneLaunchButton: View {
    let scene: Scene
    let sceneIndex: Int
    @ObservedObject var session: LiveSession

    var body: some View {
        Button(action: { session.launchScene(sceneIndex) }) {
            HStack {
                Text(scene.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(.white)
                    .lineLimit(1)

                Spacer()

                Image(systemName: "play.fill")
                    .font(.system(size: 12))
                    .foregroundColor(scene.isPlaying ? .green : .gray)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(scene.isPlaying ? Color.green.opacity(0.3) : Color.gray.opacity(0.2))
            )
        }
        .padding(.horizontal, 8)
    }
}


// MARK: - Track Header

struct SessionTrackHeaderView: View {
    @ObservedObject var track: SessionTrack
    @ObservedObject var session: LiveSession

    var body: some View {
        VStack(spacing: 4) {
            // Track name
            TextField("Track", text: $track.name)
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.white)
                .textFieldStyle(PlainTextFieldStyle())
                .multilineTextAlignment(.center)

            // M/S/R buttons
            HStack(spacing: 4) {
                // Mute
                Button(action: { track.isMuted.toggle() }) {
                    Text("M")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(track.isMuted ? .white : .black)
                        .frame(width: 25, height: 20)
                        .background(track.isMuted ? Color.orange : Color.gray.opacity(0.3))
                        .cornerRadius(3)
                }

                // Solo
                Button(action: { track.isSoloed.toggle() }) {
                    Text("S")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(track.isSoloed ? .white : .black)
                        .frame(width: 25, height: 20)
                        .background(track.isSoloed ? Color.yellow : Color.gray.opacity(0.3))
                        .cornerRadius(3)
                }

                // Record arm
                Button(action: { track.isArmed.toggle() }) {
                    Text("R")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(track.isArmed ? .white : .black)
                        .frame(width: 25, height: 20)
                        .background(track.isArmed ? Color.red : Color.gray.opacity(0.3))
                        .cornerRadius(3)
                }
            }

            // Stop button
            Button(action: { session.stopTrack(trackID: track.id) }) {
                Image(systemName: "stop.fill")
                    .font(.system(size: 12))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 4)
                    .background(Color.red.opacity(0.3))
                    .cornerRadius(4)
            }
        }
        .padding(8)
        .background(Color.gray.opacity(0.3))
    }
}


// MARK: - Clip Slot

struct ClipSlotView: View {
    let slot: ClipSlot?
    @ObservedObject var session: LiveSession
    let trackID: UUID
    let sceneIndex: Int
    let isSelected: Bool
    let onTap: () -> Void
    let onRecord: () -> Void

    var body: some View {
        if let slot = slot, let clip = slot.clip {
            // Filled slot with clip
            Button(action: onTap) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(clipColor(for: clip).opacity(slot.isPlaying ? 1.0 : 0.6))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isSelected ? Color.white : Color.clear, lineWidth: 2)
                        )

                    VStack(spacing: 4) {
                        Text(clip.name)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(.white)
                            .lineLimit(2)

                        if slot.isPlaying {
                            ProgressView(value: slot.playbackProgress)
                                .progressViewStyle(LinearProgressViewStyle(tint: .white))
                                .frame(width: 100)
                        }

                        Text(clip.durationString(sampleRate: 48000))
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.7))
                    }
                    .padding(8)
                }
            }
        } else {
            // Empty slot
            Button(action: onRecord) {
                ZStack {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.gray.opacity(0.1))
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color.gray.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [4]))
                        )

                    Image(systemName: "circle")
                        .font(.system(size: 24))
                        .foregroundColor(.gray.opacity(0.3))
                }
            }
        }
    }

    private func clipColor(for clip: Clip) -> Color {
        switch clip.color {
        case .red: return .red
        case .orange: return .orange
        case .yellow: return .yellow
        case .green: return .green
        case .blue: return .blue
        case .purple: return .purple
        case .pink: return .pink
        case .gray: return .gray
        case .brown: return .brown
        }
    }
}


// MARK: - Session Master Controls

struct SessionMasterControls: View {
    @ObservedObject var session: LiveSession

    var body: some View {
        HStack(spacing: 20) {
            // Master volume
            VStack(alignment: .leading, spacing: 4) {
                Text("Master")
                    .font(.caption)
                    .foregroundColor(.gray)

                HStack {
                    Image(systemName: "speaker.wave.2")
                        .foregroundColor(.white)

                    Slider(value: $session.masterVolume, in: 0...1)
                        .accentColor(.blue)
                        .frame(width: 200)

                    Text("\(Int(session.masterVolume * 100))%")
                        .font(.system(size: 12, design: .monospaced))
                        .foregroundColor(.gray)
                        .frame(width: 50)
                }
            }

            Spacer()

            // Quantization
            HStack {
                Text("Quantize:")
                    .font(.caption)
                    .foregroundColor(.gray)

                Picker("", selection: $session.quantization) {
                    ForEach(Quantization.allCases) { quant in
                        Text(quant.rawValue).tag(quant)
                    }
                }
                .pickerStyle(MenuPickerStyle())
                .frame(width: 100)
            }

            // Global record
            Button(action: { session.globalRecord.toggle() }) {
                Image(systemName: "record.circle.fill")
                    .font(.system(size: 32))
                    .foregroundColor(session.globalRecord ? .red : .gray)
            }
        }
        .padding(.horizontal)
        .foregroundColor(.white)
    }
}


// MARK: - Supporting Models

/// Live session (clip launcher)
class LiveSession: ObservableObject {

    @Published var tracks: [SessionTrack] = []
    @Published var scenes: [Scene] = []
    @Published var tempo: Double = 120.0
    @Published var isPlaying: Bool = false
    @Published var metronomeEnabled: Bool = false
    @Published var masterVolume: Double = 0.8
    @Published var quantization: Quantization = .bar
    @Published var globalRecord: Bool = false

    /// Clip slots grid
    private var clipSlots: [String: ClipSlot] = [:]  // "trackID_sceneIndex" → ClipSlot

    var sceneCount: Int {
        scenes.count
    }

    init() {
        // Create default tracks and scenes
        for i in 1...8 {
            addTrack(name: "Track \(i)")
        }

        for i in 1...16 {
            addScene(name: "Scene \(i)")
        }
    }

    // MARK: - Track Management

    func addTrack(name: String? = nil) {
        let trackNumber = tracks.count + 1
        let track = SessionTrack(name: name ?? "Track \(trackNumber)")
        tracks.append(track)
    }

    func removeTrack(trackID: UUID) {
        tracks.removeAll { $0.id == trackID }
    }

    // MARK: - Scene Management

    func addScene(name: String? = nil) {
        let sceneNumber = scenes.count + 1
        let scene = Scene(name: name ?? "Scene \(sceneNumber)")
        scenes.append(scene)
    }

    func removeScene(sceneIndex: Int) {
        guard sceneIndex < scenes.count else { return }
        scenes.remove(at: sceneIndex)
    }

    // MARK: - Clip Slot Management

    func getSlot(trackID: UUID, sceneIndex: Int) -> ClipSlot? {
        let key = "\(trackID)_\(sceneIndex)"
        return clipSlots[key]
    }

    func setClip(_ clip: Clip, trackID: UUID, sceneIndex: Int) {
        let key = "\(trackID)_\(sceneIndex)"
        let slot = ClipSlot(clip: clip)
        clipSlots[key] = slot
    }

    func removeClip(trackID: UUID, sceneIndex: Int) {
        let key = "\(trackID)_\(sceneIndex)"
        clipSlots.removeValue(forKey: key)
    }

    // MARK: - Playback Control

    func launchClip(trackID: UUID, sceneIndex: Int) {
        let key = "\(trackID)_\(sceneIndex)"
        guard let slot = clipSlots[key] else { return }

        // Stop other clips in this track
        stopTrack(trackID: trackID)

        // Launch this clip
        slot.isPlaying = true
        print("▶️ Launched clip: \(slot.clip?.name ?? "Unknown") (Track: \(trackID), Scene: \(sceneIndex))")
    }

    func stopClip(trackID: UUID, sceneIndex: Int) {
        let key = "\(trackID)_\(sceneIndex)"
        guard let slot = clipSlots[key] else { return }

        slot.isPlaying = false
        print("⏹️ Stopped clip: \(slot.clip?.name ?? "Unknown")")
    }

    func launchScene(_ sceneIndex: Int) {
        guard sceneIndex < scenes.count else { return }

        let scene = scenes[sceneIndex]
        scene.isPlaying = true

        // Launch all clips in this scene
        for track in tracks {
            launchClip(trackID: track.id, sceneIndex: sceneIndex)
        }

        print("▶️ Launched scene: \(scene.name)")
    }

    func stopTrack(trackID: UUID) {
        // Stop all clips in this track
        for (key, slot) in clipSlots {
            if key.starts(with: "\(trackID)_") {
                slot.isPlaying = false
            }
        }
    }

    func stopAll() {
        // Stop all clips
        for (_, slot) in clipSlots {
            slot.isPlaying = false
        }

        // Stop all scenes
        for scene in scenes {
            scene.isPlaying = false
        }

        isPlaying = false
        print("⏹️ Stopped all clips")
    }

    func togglePlayback() {
        isPlaying.toggle()

        if !isPlaying {
            stopAll()
        }
    }

    // MARK: - Recording

    func recordClip(trackID: UUID, sceneIndex: Int) {
        print("⏺️ Recording clip (Track: \(trackID), Scene: \(sceneIndex))")
        // TODO: Implement clip recording
    }
}


/// Session track (for clip launcher)
class SessionTrack: ObservableObject, Identifiable {
    let id: UUID
    @Published var name: String
    @Published var isMuted: Bool = false
    @Published var isSoloed: Bool = false
    @Published var isArmed: Bool = false

    init(name: String) {
        self.id = UUID()
        self.name = name
    }
}


/// Scene
class Scene: ObservableObject, Identifiable {
    let id: UUID
    @Published var name: String
    @Published var isPlaying: Bool = false

    init(name: String) {
        self.id = UUID()
        self.name = name
    }
}


/// Clip slot
class ClipSlot: ObservableObject {
    var clip: Clip?
    @Published var isPlaying: Bool = false
    @Published var playbackProgress: Double = 0.0

    init(clip: Clip? = nil) {
        self.clip = clip
    }
}


/// Quantization
enum Quantization: String, CaseIterable, Identifiable {
    case none = "None"
    case bar = "1 Bar"
    case half = "1/2"
    case quarter = "1/4"
    case eighth = "1/8"
    case sixteenth = "1/16"

    var id: String { rawValue }
}


// MARK: - Preview

struct SessionView_Previews: PreviewProvider {
    static var previews: some View {
        let session = LiveSession()
        let timeline = Timeline()
        let playbackEngine = PlaybackEngine(timeline: timeline)

        return SessionView(session: session, playbackEngine: playbackEngine)
            .preferredColorScheme(.dark)
    }
}
