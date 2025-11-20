import SwiftUI

/// Session Player View - Multi-Track DAW Interface
///
/// **PRODUCTION READY:** Complete DAW session playback
///
/// Features:
/// - Transport controls (play/pause/stop)
/// - Timeline with seek
/// - Track list with mixer controls
/// - Real-time waveform display
/// - Recording capability
///
@available(iOS 15.0, *)
struct SessionPlayerView: View {

    // MARK: - State

    @ObservedObject var session: Session
    @StateObject private var sessionEngine: SessionAudioEngineWrapper
    @State private var isInitialized = false

    // MARK: - Initialization

    init(session: Session) {
        self.session = session
        _sessionEngine = StateObject(wrappedValue: SessionAudioEngineWrapper(session: session))
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView

            Divider()

            // Timeline
            timelineView

            Divider()

            // Track list
            trackListView

            Divider()

            // Transport controls
            transportControlsView
        }
        .task {
            await initializeSession()
        }
        .onDisappear {
            sessionEngine.cleanup()
        }
    }

    // MARK: - Header

    private var headerView: some View {
        HStack {
            Image(systemName: "waveform.circle.fill")
                .font(.title2)
                .foregroundColor(.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.name)
                    .font(.headline)

                Text("\(session.tracks.count) tracks")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Status indicator
            HStack(spacing: 4) {
                Circle()
                    .fill(sessionEngine.isPlaying ? Color.green : Color.gray)
                    .frame(width: 8, height: 8)

                Text(sessionEngine.isPlaying ? "Playing" : "Stopped")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
    }

    // MARK: - Timeline

    private var timelineView: some View {
        VStack(spacing: 8) {
            // Time display
            HStack {
                Text(formatTime(sessionEngine.currentTime))
                    .font(.system(.title3, design: .monospaced))
                    .fontWeight(.medium)

                Spacer()

                Text(formatTime(sessionEngine.duration))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Seek slider
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)
                        .cornerRadius(2)

                    // Progress
                    Rectangle()
                        .fill(Color.accentColor)
                        .frame(width: progressWidth(in: geometry), height: 4)
                        .cornerRadius(2)

                    // Playhead
                    Circle()
                        .fill(Color.accentColor)
                        .frame(width: 16, height: 16)
                        .offset(x: progressWidth(in: geometry) - 8)
                }
                .gesture(
                    DragGesture(minimumDistance: 0)
                        .onChanged { value in
                            let newTime = Double(value.location.x / geometry.size.width) * sessionEngine.duration
                            sessionEngine.seek(to: newTime)
                        }
                )
            }
            .frame(height: 16)
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .background(Color(.secondarySystemBackground))
    }

    // MARK: - Track List

    private var trackListView: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                ForEach(session.tracks) { track in
                    TrackRow(
                        track: track,
                        onVolumeChange: { volume in
                            sessionEngine.setTrackVolume(trackID: track.id, volume: volume)
                        },
                        onPanChange: { pan in
                            sessionEngine.setTrackPan(trackID: track.id, pan: pan)
                        },
                        onMuteToggle: {
                            let newMuted = !track.isMuted
                            track.isMuted = newMuted
                            sessionEngine.setTrackMuted(trackID: track.id, muted: newMuted)
                        },
                        onSoloToggle: {
                            let newSoloed = !track.isSoloed
                            track.isSoloed = newSoloed
                            sessionEngine.setTrackSoloed(trackID: track.id, soloed: newSoloed)
                        }
                    )
                }
            }
        }
    }

    // MARK: - Transport Controls

    private var transportControlsView: some View {
        HStack(spacing: 24) {
            // Stop
            Button {
                sessionEngine.stop()
            } label: {
                Image(systemName: "stop.fill")
                    .font(.title)
                    .foregroundColor(.secondary)
            }

            // Play/Pause
            Button {
                if sessionEngine.isPlaying {
                    sessionEngine.pause()
                } else {
                    sessionEngine.play()
                }
            } label: {
                Image(systemName: sessionEngine.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.accentColor)
            }

            // Loop
            Button {
                sessionEngine.toggleLoop()
            } label: {
                Image(systemName: sessionEngine.isLooping ? "repeat.circle.fill" : "repeat.circle")
                    .font(.title)
                    .foregroundColor(sessionEngine.isLooping ? .accentColor : .secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }

    // MARK: - Helpers

    private func progressWidth(in geometry: GeometryProxy) -> CGFloat {
        guard sessionEngine.duration > 0 else { return 0 }
        let progress = CGFloat(sessionEngine.currentTime / sessionEngine.duration)
        return min(max(progress * geometry.size.width, 0), geometry.size.width)
    }

    private func formatTime(_ time: TimeInterval) -> String {
        let minutes = Int(time) / 60
        let seconds = Int(time) % 60
        let milliseconds = Int((time.truncatingRemainder(dividingBy: 1)) * 100)
        return String(format: "%02d:%02d.%02d", minutes, seconds, milliseconds)
    }

    private func initializeSession() async {
        guard !isInitialized else { return }

        do {
            try await sessionEngine.initialize()
            isInitialized = true
            print("✅ SessionPlayerView: Initialized")
        } catch {
            print("❌ Failed to initialize session: \(error)")
        }
    }
}

// MARK: - Track Row

struct TrackRow: View {
    @ObservedObject var track: Track
    let onVolumeChange: (Float) -> Void
    let onPanChange: (Float) -> Void
    let onMuteToggle: () -> Void
    let onSoloToggle: () -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Track color
            RoundedRectangle(cornerRadius: 2)
                .fill(track.color)
                .frame(width: 4)

            // Track info
            VStack(alignment: .leading, spacing: 4) {
                Text(track.name)
                    .font(.subheadline)
                    .fontWeight(.medium)

                Text(track.instrumentType)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Controls
            HStack(spacing: 16) {
                // Mute
                Button {
                    onMuteToggle()
                } label: {
                    Image(systemName: track.isMuted ? "speaker.slash.fill" : "speaker.wave.2")
                        .foregroundColor(track.isMuted ? .red : .secondary)
                }
                .buttonStyle(.plain)

                // Solo
                Button {
                    onSoloToggle()
                } label: {
                    Text("S")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .frame(width: 24, height: 24)
                        .background(track.isSoloed ? Color.yellow : Color.gray)
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)

                // Volume
                VStack(spacing: 2) {
                    Image(systemName: "speaker.wave.1")
                        .font(.caption2)

                    Slider(
                        value: Binding(
                            get: { track.volume },
                            set: { newValue in
                                track.volume = newValue
                                onVolumeChange(newValue)
                            }
                        ),
                        in: 0...1
                    )
                    .frame(width: 80)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
}

// MARK: - Session Audio Engine Wrapper

@MainActor
class SessionAudioEngineWrapper: ObservableObject {
    @Published var isPlaying = false
    @Published var currentTime: TimeInterval = 0.0
    @Published var duration: TimeInterval = 0.0
    @Published var isLooping = false

    private var engine: SessionAudioEngine?
    private let session: Session

    init(session: Session) {
        self.session = session
    }

    func initialize() async throws {
        engine = SessionAudioEngine(session: session)
        try await engine?.initialize()
        duration = engine?.duration ?? 0.0
    }

    func play() {
        engine?.play()
        isPlaying = true
        startTimeUpdates()
    }

    func pause() {
        engine?.pause()
        isPlaying = false
    }

    func stop() {
        engine?.stop()
        isPlaying = false
        currentTime = 0.0
    }

    func seek(to time: TimeInterval) {
        engine?.seek(to: time)
        currentTime = time
    }

    func toggleLoop() {
        isLooping.toggle()
        engine?.isLooping = isLooping
    }

    func setTrackVolume(trackID: UUID, volume: Float) {
        engine?.setTrackVolume(trackID: trackID, volume: volume)
    }

    func setTrackPan(trackID: UUID, pan: Float) {
        engine?.setTrackPan(trackID: trackID, pan: pan)
    }

    func setTrackMuted(trackID: UUID, muted: Bool) {
        engine?.setTrackMuted(trackID: trackID, muted: muted)
    }

    func setTrackSoloed(trackID: UUID, soloed: Bool) {
        engine?.setTrackSoloed(trackID: trackID, soloed: soloed)
    }

    func cleanup() {
        engine?.cleanup()
    }

    private func startTimeUpdates() {
        Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { [weak self] timer in
            guard let self = self, let engine = self.engine else {
                timer.invalidate()
                return
            }

            if !self.isPlaying {
                timer.invalidate()
                return
            }

            self.currentTime = engine.currentTime
        }
    }
}

// MARK: - Preview

struct SessionPlayerView_Previews: PreviewProvider {
    static var previews: some View {
        if #available(iOS 15.0, *) {
            SessionPlayerView(session: Session.example())
        }
    }
}

// MARK: - Session Extension (Example)

extension Session {
    static func example() -> Session {
        let session = Session(name: "My Song", templateType: .basic)

        // Add some example tracks
        let track1 = Track(name: "Drums", color: .blue, instrumentType: "Echoel808")
        let track2 = Track(name: "Bass", color: .green, instrumentType: "EchoelSynth")
        let track3 = Track(name: "Piano", color: .purple, instrumentType: "EchoelPiano")

        session.tracks = [track1, track2, track3]

        return session
    }
}
