import Foundation
import AVFoundation
import Combine

#if os(visionOS) || os(iOS)

// MARK: - Immersive Video Capture Manager

/// Records and plays back immersive 360° / spatial video with bio-data overlay
/// Supports Apple Immersive Video format and standard 360° equirectangular
@MainActor
final class ImmersiveVideoCaptureManager: ObservableObject {

    // MARK: - Singleton

    static let shared = ImmersiveVideoCaptureManager()

    // MARK: - State

    /// Current capture state
    @Published var captureState: CaptureState = .idle

    /// Current playback state
    @Published var playbackState: PlaybackState = .stopped

    /// Recording duration
    @Published var recordingDuration: TimeInterval = 0

    /// Current playback time
    @Published var playbackTime: TimeInterval = 0

    /// Total duration of loaded video
    @Published var totalDuration: TimeInterval = 0

    /// Bio-data overlay enabled
    @Published var bioOverlayEnabled: Bool = true

    /// Currently loaded recording
    @Published var currentRecording: ImmersiveRecording?

    /// Available recordings
    @Published var recordings: [ImmersiveRecording] = []

    // MARK: - Private

    private var captureSession: AVCaptureSession?
    private var videoOutput: AVCaptureMovieFileOutput?
    private var player: AVPlayer?
    private var recordingTimer: Timer?
    private var bioDataBuffer: [BioDataPoint] = []
    private var cancellables = Set<AnyCancellable>()
    private var timeObserverToken: Any?  // Store AVPlayer observer to remove later

    // MARK: - Types

    enum CaptureState {
        case idle
        case preparing
        case recording
        case paused
        case finishing
        case error(Error)
    }

    enum PlaybackState {
        case stopped
        case playing
        case paused
        case seeking
    }

    struct BioDataPoint: Codable {
        let timestamp: TimeInterval
        let heartRate: Double
        let hrv: Double
        let coherence: Double
        let breathingRate: Double
    }

    // MARK: - Initialization

    private init() {
        setupBioDataCapture()
        loadRecordings()
    }

    private func setupBioDataCapture() {
        NotificationCenter.default.publisher(for: .bioDataUpdated)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self = self,
                      case .recording = self.captureState,
                      let data = notification.userInfo as? [String: Any] else { return }

                let point = BioDataPoint(
                    timestamp: self.recordingDuration,
                    heartRate: data["heartRate"] as? Double ?? 0,
                    hrv: data["hrv"] as? Double ?? 0,
                    coherence: data["coherence"] as? Double ?? 0,
                    breathingRate: data["breathingRate"] as? Double ?? 0
                )
                self.bioDataBuffer.append(point)
            }
            .store(in: &cancellables)
    }

    // MARK: - Recording

    func startRecording(format: VideoFormat = .immersive) async throws {
        log.video("🎬 Starting immersive video recording in \(format.rawValue) format")

        captureState = .preparing
        bioDataBuffer = []
        recordingDuration = 0

        // Setup capture session
        let session = AVCaptureSession()
        session.sessionPreset = .high

        // Configure video input
        if let camera = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back) {
            let input = try AVCaptureDeviceInput(device: camera)
            if session.canAddInput(input) {
                session.addInput(input)
            }
        }

        // Configure audio input
        if let microphone = AVCaptureDevice.default(for: .audio) {
            let audioInput = try AVCaptureDeviceInput(device: microphone)
            if session.canAddInput(audioInput) {
                session.addInput(audioInput)
            }
        }

        // Configure video output
        let output = AVCaptureMovieFileOutput()
        if session.canAddOutput(output) {
            session.addOutput(output)
        }

        captureSession = session
        videoOutput = output

        // Start session
        session.startRunning()

        // Start recording to file
        let url = generateRecordingURL()
        output.startRecording(to: url, recordingDelegate: self)

        captureState = .recording

        // Start duration timer
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.recordingDuration += 0.1
        }
    }

    func pauseRecording() {
        guard case .recording = captureState else { return }
        log.video("🎬 Pausing recording")

        videoOutput?.pauseRecording()
        recordingTimer?.invalidate()
        captureState = .paused
    }

    func resumeRecording() {
        guard case .paused = captureState else { return }
        log.video("🎬 Resuming recording")

        videoOutput?.resumeRecording()
        recordingTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.recordingDuration += 0.1
        }
        captureState = .recording
    }

    func stopRecording() async throws -> ImmersiveRecording {
        // Allow stopping from either recording or paused state
        switch captureState {
        case .recording, .paused:
            break
        default:
            throw CaptureError.notRecording
        }

        log.video("🎬 Stopping recording")

        captureState = .finishing
        recordingTimer?.invalidate()

        videoOutput?.stopRecording()
        captureSession?.stopRunning()

        // Wait for file to be finalized
        try await Task.sleep(nanoseconds: 500_000_000)

        // Create recording metadata
        let recording = ImmersiveRecording(
            id: UUID(),
            name: "Recording \(Date().formatted())",
            createdAt: Date(),
            duration: recordingDuration,
            format: .immersive,
            videoURL: generateRecordingURL(),
            bioDataPoints: bioDataBuffer,
            thumbnail: nil
        )

        recordings.insert(recording, at: 0)
        saveRecordings()

        captureState = .idle
        return recording
    }

    private func generateRecordingURL() -> URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let fileName = "immersive_\(Date().timeIntervalSince1970).mov"
        return documentsPath.appendingPathComponent(fileName)
    }

    // MARK: - Playback

    func loadRecording(_ recording: ImmersiveRecording) async throws {
        log.video("🎬 Loading recording: \(recording.name)")

        currentRecording = recording

        let playerItem = AVPlayerItem(url: recording.videoURL)
        player = AVPlayer(playerItem: playerItem)

        totalDuration = recording.duration
        playbackTime = 0
        playbackState = .stopped
    }

    func play() {
        guard let player = player else { return }
        log.video("🎬 Playing")

        player.play()
        playbackState = .playing

        // Start time update
        startPlaybackTimeUpdates()
    }

    func pause() {
        guard let player = player else { return }
        log.video("🎬 Pausing")

        player.pause()
        playbackState = .paused
    }

    func seek(to time: TimeInterval) async {
        guard let player = player else { return }
        log.video("🎬 Seeking to \(time)")

        playbackState = .seeking
        await player.seek(to: CMTime(seconds: time, preferredTimescale: 600))
        playbackTime = time
        playbackState = .paused
    }

    func stop() {
        log.video("🎬 Stopping playback")

        // Remove time observer before releasing player to prevent memory leak
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }

        player?.pause()
        player?.seek(to: .zero)
        player = nil
        currentRecording = nil
        playbackTime = 0
        playbackState = .stopped
    }

    private func startPlaybackTimeUpdates() {
        // Remove any existing observer first
        if let token = timeObserverToken {
            player?.removeTimeObserver(token)
            timeObserverToken = nil
        }

        // Store the new observer token so we can remove it later
        timeObserverToken = player?.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 0.1, preferredTimescale: 600),
            queue: .main
        ) { [weak self] time in
            self?.playbackTime = time.seconds
        }
    }

    /// Get bio data for current playback position
    func currentBioData() -> BioDataPoint? {
        guard let recording = currentRecording else { return nil }

        // Find closest bio data point to current time
        return recording.bioDataPoints.min { point1, point2 in
            abs(point1.timestamp - playbackTime) < abs(point2.timestamp - playbackTime)
        }
    }

    // MARK: - Persistence

    private func loadRecordings() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let metadataURL = documentsPath.appendingPathComponent("recordings.json")

        guard FileManager.default.fileExists(atPath: metadataURL.path),
              let data = try? Data(contentsOf: metadataURL),
              let loaded = try? JSONDecoder().decode([ImmersiveRecording].self, from: data) else {
            return
        }

        recordings = loaded
    }

    private func saveRecordings() {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let metadataURL = documentsPath.appendingPathComponent("recordings.json")

        if let data = try? JSONEncoder().encode(recordings) {
            try? data.write(to: metadataURL)
        }
    }

    func deleteRecording(_ recording: ImmersiveRecording) {
        // Remove file
        try? FileManager.default.removeItem(at: recording.videoURL)

        // Remove from list
        recordings.removeAll { $0.id == recording.id }
        saveRecordings()
    }

    // MARK: - Errors

    enum CaptureError: Error, LocalizedError {
        case notRecording
        case cameraUnavailable
        case outputError

        var errorDescription: String? {
            switch self {
            case .notRecording: return "Not currently recording"
            case .cameraUnavailable: return "Camera is unavailable"
            case .outputError: return "Video output error"
            }
        }
    }

    // MARK: - Video Format

    enum VideoFormat: String, Codable, CaseIterable {
        case immersive = "Apple Immersive"
        case spatial = "Spatial Video"
        case equirectangular360 = "360° Equirectangular"
        case standard = "Standard HD"

        var description: String {
            switch self {
            case .immersive: return "For Apple Vision Pro immersive playback"
            case .spatial: return "3D spatial video with depth"
            case .equirectangular360: return "Standard 360° format for all headsets"
            case .standard: return "Regular video for flat screens"
            }
        }
    }
}

// MARK: - Immersive Recording

struct ImmersiveRecording: Identifiable, Codable {
    let id: UUID
    var name: String
    let createdAt: Date
    let duration: TimeInterval
    let format: ImmersiveVideoCaptureManager.VideoFormat
    let videoURL: URL
    let bioDataPoints: [ImmersiveVideoCaptureManager.BioDataPoint]
    var thumbnail: Data?

    // MARK: - Bio Stats

    var averageHeartRate: Double {
        guard !bioDataPoints.isEmpty else { return 0 }
        return bioDataPoints.reduce(0) { $0 + $1.heartRate } / Double(bioDataPoints.count)
    }

    var averageCoherence: Double {
        guard !bioDataPoints.isEmpty else { return 0 }
        return bioDataPoints.reduce(0) { $0 + $1.coherence } / Double(bioDataPoints.count)
    }

    var peakCoherence: Double {
        bioDataPoints.max(by: { $0.coherence < $1.coherence })?.coherence ?? 0
    }

    var hrvRange: ClosedRange<Double> {
        let hrvValues = bioDataPoints.map { $0.hrv }
        let min = hrvValues.min() ?? 0
        let max = hrvValues.max() ?? 0
        return min...max
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension ImmersiveVideoCaptureManager: AVCaptureFileOutputRecordingDelegate {

    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        Task { @MainActor in
            if let error = error {
                log.video("🎬 Recording error: \(error.localizedDescription)", level: .error)
                self.captureState = .error(error)
            } else {
                log.video("🎬 Recording finished: \(outputFileURL.path)")
            }
        }
    }

    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didStartRecordingTo fileURL: URL,
        from connections: [AVCaptureConnection]
    ) {
        Task { @MainActor in
            log.video("🎬 Recording started: \(fileURL.path)")
        }
    }
}

#endif

// MARK: - Cross-Platform Stub

#if !os(visionOS) && !os(iOS)
@MainActor
final class ImmersiveVideoCaptureManager: ObservableObject {
    static let shared = ImmersiveVideoCaptureManager()
    private init() {}
}
#endif
