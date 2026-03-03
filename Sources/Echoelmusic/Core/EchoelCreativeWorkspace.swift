import Foundation
import Combine
import AVFoundation

// MARK: - Creative Workspace

/// Unified workspace bridging Audio + Video engines into one workflow.
/// BPM Grid syncs audio timing with video timeline.
@MainActor
final class EchoelCreativeWorkspace: ObservableObject {

    static let shared = EchoelCreativeWorkspace()

    // MARK: - Published State

    @Published var isPlaying: Bool = false
    @Published var globalBPM: Double = 120.0
    @Published var globalTimeSignature: TimeSignature = .fourFour

    // MARK: - Engines

    let bpmGrid: BPMGridEditEngine
    let videoEditor: VideoEditingEngine
    let proMixer: ProMixEngine
    let proSession: ProSessionEngine
    let proColor: ProColorGrading
    let loopEngine: LoopEngine

    private var cancellables = Set<AnyCancellable>()

    // MARK: - Init

    private init() {
        self.bpmGrid = BPMGridEditEngine(bpm: 120, timeSignature: .fourFour)
        self.videoEditor = VideoEditingEngine()
        self.proMixer = ProMixEngine.defaultSession()
        self.proSession = ProSessionEngine.defaultSession()
        self.proColor = ProColorGrading()
        self.loopEngine = LoopEngine()
        self.loopEngine.setTempo(120.0)

        setupBridges()
        log.info("Creative Workspace initialized (DAW + Video)", category: .system)
    }

    // MARK: - Bridges

    private func setupBridges() {
        // BPM Grid → Video Timeline sync
        bpmGrid.$grid
            .map(\.bpm)
            .removeDuplicates()
            .sink { [weak self] bpm in
                self?.videoEditor.timeline.tempo = bpm
                self?.globalBPM = bpm
            }
            .store(in: &cancellables)

        // BPM Grid → beat-synced video effects
        bpmGrid.onBeat = { [weak self] beat, bar in
            guard let self = self else { return }
            for effect in self.bpmGrid.beatSyncedEffects {
                self.bpmGrid.onBeatEffect?(effect)
            }
        }

        videoEditor.timeline.tempo = bpmGrid.grid.bpm

        // Global BPM → Session Engine
        $globalBPM
            .removeDuplicates()
            .sink { [weak self] bpm in
                self?.proSession.globalBPM = bpm
            }
            .store(in: &cancellables)

        // Session BPM → Global
        proSession.$globalBPM
            .removeDuplicates()
            .sink { [weak self] bpm in
                self?.setGlobalBPM(bpm)
            }
            .store(in: &cancellables)

        // Pro Color → Video Editor
        proColor.$colorWheels
            .removeDuplicates()
            .sink { [weak self] wheels in
                guard let self else { return }
                let grade = ColorGradeEffect(
                    exposure: wheels.exposure,
                    contrast: wheels.contrast,
                    saturation: wheels.saturation,
                    temperature: wheels.temperature,
                    tint: wheels.tint
                )
                self.videoEditor.applyLiveGrade(grade)
            }
            .store(in: &cancellables)

        // BPM → Loop Engine
        $globalBPM
            .removeDuplicates()
            .sink { [weak self] bpm in
                self?.loopEngine.setTempo(bpm)
            }
            .store(in: &cancellables)

        $globalTimeSignature
            .removeDuplicates()
            .sink { [weak self] ts in
                self?.loopEngine.setTimeSignature(beats: ts.numerator, noteValue: ts.denominator)
            }
            .store(in: &cancellables)
    }

    // MARK: - Actions

    func setGlobalBPM(_ bpm: Double) {
        bpmGrid.setBPM(bpm)
        videoEditor.timeline.tempo = bpm
        globalBPM = bpm
    }

    func setGlobalTimeSignature(_ ts: TimeSignature) {
        bpmGrid.setTimeSignature(ts)
        globalTimeSignature = ts
    }

    func detectAndSyncBPM(from audioURL: URL) async {
        let result = await bpmGrid.detectBeats(from: audioURL)
        if result.confidence > 0.5 {
            globalBPM = result.bpm
            videoEditor.timeline.tempo = result.bpm
        }
    }

    func togglePlayback() {
        if isPlaying {
            videoEditor.pause()
            proSession.stop()
            loopEngine.stopPlayback()
        } else {
            Task { await videoEditor.play() }
            proSession.play()
            if !loopEngine.loops.isEmpty {
                loopEngine.startPlayback()
            }
        }
        isPlaying.toggle()
    }

    func updatePlaybackPosition(_ seconds: Double) {
        bpmGrid.updatePosition(seconds)
        videoEditor.seek(to: CMTime(seconds: seconds, preferredTimescale: 600))
    }
}
